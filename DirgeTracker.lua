--[[ DirgeTracker — Midnight Falls "Death's Dirge" memory sequence helper.

     Tracks rune auras, builds a five-slot player queue, and advances
     during the laser phase when spell 479165 hits the expected player.

     Install (from MythicMechanicsSuite `main.lua` or your loader):

       local ok, DT = pcall(require, "DirgeTracker")
       if ok and DT and DT.install then DT.install(MMS) end

     Requires `DirgeTracker.lua` on Lua `package.path` (e.g. scripts root
     next to `MythicMechanicsSuite/`). Uses the same `root` table MMS
     returns from `Config.lua` so `Config.behavior.dataSource` is visible.

     Optional: after install, `MMS.Draw.Circle3D(...)` proxies to
     MythicMechanicsSuite Draw.circle_3d when that module is loadable. ]]

local M = {}

----------------------------------------------------------------------
-- Optional MMS modules (resolve from common Sylvanas layouts)
----------------------------------------------------------------------

local function try_require(...)
  for i = 1, select("#", ...) do
    local path = select(i, ...)
    local ok, mod = pcall(require, path)
    if ok and type(mod) == "table" then return mod end
  end
  return nil
end

local Draw = try_require("Draw", "MythicMechanicsSuite.Draw")
local Geom = try_require("Geometry", "MythicMechanicsSuite.Geometry")
local World = try_require("World", "MythicMechanicsSuite.World")

local function v2(x, y)
  if Geom and Geom.V2 then return Geom.V2(x, y) end
  return { x = x, y = y }
end

local function v3(x, y, z)
  if Geom and Geom.V3 then return Geom.V3(x, y, z) end
  return { x = x, y = y, z = z }
end

local function rgba_f_to_draw(r, g, b, a)
  return {
    r = math.floor(((r or 1) * 255) + 0.5),
    g = math.floor(((g or 1) * 255) + 0.5),
    b = math.floor(((b or 1) * 255) + 0.5),
    a = math.floor(((a or 1) * 255) + 0.5),
  }
end

--- Rune aura spell → label + RGBA (0–1 floats per spec)
local RUNE_AURA_MAP = {
  [479151] = { label = "CROSS (X)",   color = { 1.0, 0.3, 0.3, 1.0 } },
  [479152] = { label = "SQUARE (T)",  color = { 0.3, 0.3, 1.0, 1.0 } },
  [479153] = { label = "CIRCLE",      color = { 1.0, 0.8, 0.0, 1.0 } },
  [479154] = { label = "DIAMOND",     color = { 0.8, 0.3, 1.0, 1.0 } },
  [479155] = { label = "TRIANGLE",    color = { 0.2, 1.0, 0.2, 1.0 } },
}

local SPELL_DIRGE_START = 479150
local SPELL_LASER     = 479160
local SPELL_LASER_HIT = 479165

local HUD_POS = v2(400, 150)
local FLOAT_OFFSET_Y = 3.5

----------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------

local root_ref
local state = {
  phase         = "idle", --- idle | recording | beam | done
  queue         = {},     --- { { name = str, spellId = n, label = str, color = rgba table 0-255 } }
  seen_names    = {},
  active_step   = 1,
  laser_active  = false,
  flash_until   = 0,
  flash_label   = nil,
}

local aura_seen = {}
local last_laser_casting = false

local function reset_sequence()
  state.queue = {}
  state.seen_names = {}
  state.active_step = 1
  state.laser_active = false
  state.phase = "idle"
  state.flash_until = 0
  state.flash_label = nil
  aura_seen = {}
end

local function hooks_allowed()
  if not root_ref or not root_ref.Config or not root_ref.Config.behavior then
    return true
  end
  return root_ref.Config.behavior.dataSource ~= "AddonOnly"
end

local function push_slot(dest_name, spell_id)
  if not dest_name or dest_name == "" then return end
  if state.seen_names[dest_name] then return end
  if #state.queue >= 5 then return end
  local meta = RUNE_AURA_MAP[spell_id]
  if not meta then return end
  state.seen_names[dest_name] = true
  local c = rgba_f_to_draw(meta.color[1], meta.color[2], meta.color[3], meta.color[4])
  state.queue[#state.queue + 1] = {
    name    = dest_name,
    spellId = spell_id,
    label   = meta.label,
    color   = c,
  }
end

local function current_expected()
  return state.queue[state.active_step]
end

local function advance_step()
  state.active_step = state.active_step + 1
  if state.active_step > #state.queue then
    state.phase = "done"
    state.laser_active = false
  end
end

----------------------------------------------------------------------
-- Combat log parsing (WoW-style vararg; spellId scan fallback)
----------------------------------------------------------------------

local function cleu_unpack(...)
  local n = select("#", ...)
  local t = {}
  for i = 1, n do t[i] = select(i, ...) end
  return t, n
end

--- Typical retail layout: [2]=subevent, [5]=sourceName, [9]=destName, [12]=spellId for SPELL_* lines.
local function parse_spell_event(t)
  local sub = t[2]
  if type(sub) ~= "string" then return nil end
  if not sub:find("^SPELL_", 1) then return nil end
  return {
    subevent    = sub,
    source_name = t[5],
    dest_name   = t[9],
    spell_id    = tonumber(t[12]),
  }
end

local function scan_spell_id(t, n)
  for i = 1, n do
    local v = t[i]
    if type(v) == "number" then
      if v == SPELL_DIRGE_START or v == SPELL_LASER or v == SPELL_LASER_HIT or RUNE_AURA_MAP[v] then
        return v, i
      end
    end
  end
  return nil, nil
end

local unpack_fn = table.unpack or unpack

local function on_combat_payload(...)
  if not hooks_allowed() then return end
  local t, n = cleu_unpack(...)
  if n < 1 then return end

  --- Table-style payload (some hosts pass one table)
  if n == 1 and type(t[1]) == "table" then
    local ev = t[1]
    local fake = {
      ev.timestamp or 0,
      ev.subevent or ev.event,
      ev.hideCaster,
      ev.sourceGUID, ev.sourceName, ev.sourceFlags, ev.sourceRaidFlags,
      ev.destGUID, ev.destName, ev.destFlags, ev.destRaidFlags,
      ev.spellId or ev.spellID, ev.spellName, ev.spellSchool,
    }
    return on_combat_payload(unpack_fn(fake, 1, #fake))
  end

  if n < 4 then return end

  local ev = parse_spell_event(t)
  local spell_id = ev and ev.spell_id
  local dest_name = ev and ev.dest_name
  local subevent = ev and ev.subevent

  if not spell_id then
    spell_id, _ = scan_spell_id(t, n)
    if spell_id and not ev then
      --- Best-effort dest name: last string before spell id index
      local si
      for i = 1, n do
        if t[i] == spell_id then si = i break end
      end
      if si then
        for j = si - 1, 1, -1 do
          if type(t[j]) == "string" and t[j] ~= "" and not t[j]:find("^Player%-") then
            dest_name = t[j]
            break
          end
        end
      end
      subevent = t[2]
    end
  end

  if not spell_id or not subevent then return end

  if subevent == "SPELL_CAST_START" and spell_id == SPELL_DIRGE_START then
    reset_sequence()
    state.phase = "recording"
    return
  end

  if subevent == "SPELL_AURA_APPLIED" and RUNE_AURA_MAP[spell_id] and state.phase == "recording" then
    push_slot(dest_name, spell_id)
    return
  end

  if (subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS") and spell_id == SPELL_LASER then
    state.laser_active = true
    state.phase = "beam"
    state.active_step = 1
    return
  end

  if subevent == "SPELL_DAMAGE" and spell_id == SPELL_LASER_HIT and state.laser_active and state.phase == "beam" then
    local expect = current_expected()
    if expect and dest_name and expect.name == dest_name then
      local now = (core and core.time and core.time()) or os.clock()
      state.flash_until = now + 1.25
      state.flash_label = expect.label
      advance_step()
    end
  end
end

----------------------------------------------------------------------
-- External feed (if host exposes no combat callback)
----------------------------------------------------------------------

function M.feed_combat_event(...)
  on_combat_payload(...)
end

----------------------------------------------------------------------
-- Player lookup + 3D draw
----------------------------------------------------------------------

local function unit_by_name(name)
  if not World or not World.all_players or not name then return nil end
  local list = World.all_players()
  for i = 1, #list do
    local u = list[i]
    local ok, nm = pcall(function()
      if World.name then return World.name(u) end
      if u.get_name then return u:get_name() end
      return nil
    end)
    if ok and nm == name then return u end
  end
  return nil
end

local function world_pos_above_unit(unit, dy)
  if not World or not World.position then return nil end
  local p = World.position(unit)
  if not p then return nil end
  local x = p.x or p[1] or 0
  local y = p.y or p[2] or 0
  local z = (p.z or p[3] or 0) + (dy or FLOAT_OFFSET_Y)
  return v3(x, y, z)
end

local function attach_draw_proxy(r)
  if not r then return end
  r.Draw = r.Draw or {}
  if r.Draw.Circle3D then return end
  r.Draw.Circle3D = function(center, radius, color_in, thickness, segments, filled, fill_alpha)
    if not Draw or not Draw.circle_3d then return end
    Draw.circle_3d(center, radius, color_in, thickness or 2.5, segments or 36, filled, fill_alpha)
  end
end

local function draw_text_2d_screen(text, pos, size_px, color_tbl)
  local g = core and core.graphics
  if not g or not text or not pos then return end
  local c = color_tbl or { r = 255, g = 255, b = 255, a = 255 }
  pcall(function()
    if g.draw_text_2d then
      g.draw_text_2d(tostring(text), pos, size_px or 14, c)
    elseif g.text_2d then
      g.text_2d(tostring(text), pos, size_px or 14, c)
    end
  end)
end

local function dim_color(c, mult)
  mult = mult or 0.3
  return {
    r = c.r or 255,
    g = c.g or 255,
    b = c.b or 255,
    a = math.floor(((c.a or 255) * mult) + 0.5),
  }
end

local function on_render()
  if not hooks_allowed() then return end
  if state.phase == "idle" and #state.queue == 0 then return end

  local now = (core and core.time and core.time()) or os.clock()
  local step = state.active_step
  local y = HUD_POS.y or HUD_POS[2] or 150
  local x = HUD_POS.x or HUD_POS[1] or 400

  draw_text_2d_screen("Death's Dirge — sequence", v2(x, y), 16, { r = 255, g = 255, b = 255, a = 255 })
  y = y + 22

  local chain = {}
  for i = 1, #state.queue do
    local slot = state.queue[i]
    local active = (state.phase == "beam" and state.laser_active and i == step)
    local col = active and slot.color or dim_color(slot.color, 0.3)
    chain[#chain + 1] = string.format("%d:%s [%s]", i, slot.name, slot.label)
    draw_text_2d_screen(
      string.format("%d  %s  —  %s", i, slot.name, slot.label),
      v2(x, y),
      14,
      col
    )
    y = y + 18
  end

  if #chain > 0 then
    draw_text_2d_screen(table.concat(chain, "  ->  "), v2(x, y + 4), 12, { r = 200, g = 200, b = 200, a = 200 })
  end

  --- 3D overlays + ground circle for current step
  for i = 1, #state.queue do
    local slot = state.queue[i]
    local u = unit_by_name(slot.name)
    local pos = world_pos_above_unit(u, FLOAT_OFFSET_Y)
    if pos and Draw and Draw.text_3d then
      local label = string.format("[%d] %s", i, slot.label)
      local col = slot.color
      local active = (state.phase == "beam" and state.laser_active and i == step)
      if active and now < state.flash_until then
        label = string.format("★ RUN IN NOW: %s ★", slot.label)
        col = { r = 255, g = 60, b = 60, a = 255 }
      elseif not active then
        col = dim_color(slot.color, 0.35)
      end
      Draw.text_3d(label, pos, active and 22 or 15, col, true)
    end

    if u and World and World.position then
      local ground = World.position(u)
      local active = (state.phase == "beam" and state.laser_active and i == step)
      if ground and active and now < state.flash_until and root_ref and root_ref.Draw and root_ref.Draw.Circle3D then
        local warn = rgba_f_to_draw(1, 0.15, 0.15, 0.85)
        root_ref.Draw.Circle3D(ground, 4.0, warn, 3.0, 40, true, 90)
      elseif ground and Draw and Draw.circle_3d and active then
        Draw.circle_3d(ground, 4.0, { r = 255, g = 50, b = 50, a = 220 }, 3, 40, true, 85)
      end
    end
  end
end

----------------------------------------------------------------------
-- Polling fallback (auras + boss casts) when no CLEU hook exists
----------------------------------------------------------------------

local function poll_world_fallback()
  if not hooks_allowed() then return end
  if not World or not World.all_players or not World.aura_by_id then return end
  if state.phase ~= "recording" then return end

  for _, p in ipairs(World.all_players()) do
    local guid = World.guid and World.guid(p) or tostring(p)
    for sid, _ in pairs(RUNE_AURA_MAP) do
      local a = World.aura_by_id(p, sid, "debuff") or World.aura_by_id(p, sid, "buff") or World.aura_by_id(p, sid)
      if a then
        local key = tostring(guid) .. ":" .. tostring(sid)
        if not aura_seen[key] then
          aura_seen[key] = true
          local nm = World.name and World.name(p) or nil
          push_slot(nm, sid)
        end
      end
    end
  end

  --- Dirge cast start via boss active cast
  local any_laser = false
  for _, e in ipairs(World.all_enemies and World.all_enemies() or {}) do
    local c = World.active_cast and World.active_cast(e)
    if c and c.spell_id == SPELL_DIRGE_START then
      reset_sequence()
      state.phase = "recording"
    end
    if c and c.spell_id == SPELL_LASER then
      any_laser = true
    end
  end
  if any_laser then
    if not last_laser_casting then
      state.active_step = 1
    end
    last_laser_casting = true
    state.laser_active = true
    state.phase = "beam"
  else
    last_laser_casting = false
  end
end

local function on_update()
  poll_world_fallback()
end

----------------------------------------------------------------------
-- Combat registration (try several host API names)
----------------------------------------------------------------------

local combat_handle

local function register_combat()
  local function wrap(...)
    local ok = pcall(on_combat_payload, ...)
    if not ok then end
  end

  local tries = {
    function(cb) return core and core.register_on_combat_log_callback and core.register_on_combat_log_callback(cb) end,
    function(cb) return core and core.register_on_combat_log_event and core.register_on_combat_log_event(cb) end,
    function(cb) return core and core.events and core.events.register and core.events.register("combat_log", cb) end,
  }

  for i = 1, #tries do
    local ok = pcall(function()
      if tries[i](wrap) then combat_handle = true return true end
    end)
    if ok and combat_handle then return true end
  end
  return false
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

local installed

function M.install(root)
  if installed then return end
  installed = true

  root_ref = root
  attach_draw_proxy(root_ref)
  reset_sequence()

  pcall(register_combat)

  if core and core.register_on_render_callback then
    core.register_on_render_callback(function()
      pcall(on_render)
    end)
  end
  if core and core.register_on_update_callback then
    core.register_on_update_callback(function()
      pcall(on_update)
    end)
  end

  if core and core.log then
    core.log("[DirgeTracker] installed (combat hook=" .. tostring(combat_handle == true) .. ")")
  end
end

function M.state()
  return state
end

--- Wipe all in-memory Dirge state (queue, aura poll keys, laser edge
--- flags). Invoked when `Config.behavior.dataSource` switches to
--- AddonOnly during combat so hardcoded-path bookkeeping cannot race
--- addon-mirrored timing.
function M.wipe_runtime_structures()
  reset_sequence()
  last_laser_casting = false
end

return M
