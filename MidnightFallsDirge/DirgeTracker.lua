--[[ DirgeTracker — Midnight Falls "Death's Dirge" memory-game tracker.

     Standalone Sylvanas plugin (`MidnightFallsDirge/`). Tracks rune auras,
     builds a five-slot player→symbol queue, and advances during the laser
     phase when spell 479165 hits the expected player.

     On top of the queue it drives three helpers (all toggleable in Config):
       * a 2D HUD overlay listing the run-in order with symbol chips,
       * symbol icons drawn above each assigned player's head (and optional
         real WoW raid-target markers via `Markers`),
       * chat callouts that announce the order and whisper each player their
         personal symbol (via `Chat`).

     `main.lua` calls `DirgeTracker.install(ROOT)` with the runtime table from
     `Config.lua`.

     Optional: after install, `ROOT.Draw.Circle3D(...)` proxies to local
     `Draw.circle_3d` when available. ]]

local M = {}

----------------------------------------------------------------------
-- Bundled Draw / World / Geometry / Chat / Markers (this plugin folder)
----------------------------------------------------------------------

local function try_require(...)
  for i = 1, select("#", ...) do
    local path = select(i, ...)
    local ok, mod = pcall(require, path)
    if ok and type(mod) == "table" then return mod end
  end
  return nil
end

local Draw = try_require("Draw")
local Geom = try_require("Geometry")
local World = try_require("World")
local Chat = try_require("Chat")
local Markers = try_require("Markers")

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

--- Rune aura spell → label + RGBA (0–1 floats per spec) + raid-target marker
--- index (1-8) + glyph shape. The runes line up with WoW raid markers, so the
--- drawn glyph colour and any real SetRaidTarget marker match.
local RUNE_AURA_MAP = {
  [479151] = { label = "CROSS (X)",   color = { 1.0, 0.3, 0.3, 1.0 }, marker = 7, shape = "cross" },
  [479152] = { label = "SQUARE (T)",  color = { 0.3, 0.3, 1.0, 1.0 }, marker = 6, shape = "square" },
  [479153] = { label = "CIRCLE",      color = { 1.0, 0.8, 0.0, 1.0 }, marker = 2, shape = "circle" },
  [479154] = { label = "DIAMOND",     color = { 0.8, 0.3, 1.0, 1.0 }, marker = 3, shape = "diamond" },
  [479155] = { label = "TRIANGLE",    color = { 0.2, 1.0, 0.2, 1.0 }, marker = 4, shape = "triangle" },
}

local SPELL_DIRGE_START = 479150
local SPELL_LASER     = 479160
local SPELL_LASER_HIT = 479165

local FLOAT_OFFSET_Y = 3.5

----------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------

local root_ref
local state = {
  phase           = "idle", --- idle | recording | beam | done
  queue           = {},     --- { { name, spellId, label, color (rgba 0-255), shape, marker } }
  seen_names      = {},
  active_step     = 1,
  laser_active    = false,
  flash_until     = 0,
  flash_label     = nil,
  announced       = false,  --- chat callout sent for this sequence
  markers_applied = false,  --- SetRaidTarget applied for this sequence
}

local aura_seen = {}
local last_laser_casting = false

local function cfg()
  return root_ref and root_ref.Config or nil
end

local function clear_markers_for(queue)
  if Markers and Markers.clear and root_ref and root_ref.Config then
    pcall(Markers.clear, root_ref.Config, queue)
  end
end

local function reset_sequence()
  --- Wipe any real raid markers we placed before dropping the queue.
  if state.markers_applied then
    clear_markers_for(state.queue)
  end
  state.queue = {}
  state.seen_names = {}
  state.active_step = 1
  state.laser_active = false
  state.phase = "idle"
  state.flash_until = 0
  state.flash_label = nil
  state.announced = false
  state.markers_applied = false
  aura_seen = {}
end

local function hooks_allowed()
  if not root_ref or not root_ref.Config then
    return true
  end
  if root_ref.Config.enabled == false then
    return false
  end
  local beh = root_ref.Config.behavior
  if not beh then return true end
  return beh.dataSource ~= "AddonOnly"
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
    shape   = meta.shape,
    marker  = meta.marker,
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

local function play_alert_sound()
  local c = cfg()
  if not c or not c.sound or not c.sound.enabled then return end
  local fid = c.sound.fileId
  pcall(function()
    if core and core.play_sound then core.play_sound(fid); return end
    if core and core.audio and core.audio.play_sound then core.audio.play_sound(fid); return end
    if type(PlaySound) == "function" then PlaySound(fid) end
  end)
end

--- Fire chat callouts, raid markers, and the sound cue exactly once per
--- detected sequence. Safe to call repeatedly; guarded by `state.announced`.
local function fire_callouts_once()
  local c = cfg()
  if not c then return end
  if state.announced then return end
  if #state.queue == 0 then return end

  state.announced = true
  play_alert_sound()

  if Chat then
    pcall(function() Chat.announce(c, state.queue) end)
    pcall(function() Chat.whisper_assignments(c, state.queue) end)
  end

  if Markers and c.raidMarkers and c.raidMarkers.enabled and not state.markers_applied then
    local ok, n = pcall(Markers.apply, c, state.queue)
    if ok and n and n > 0 then
      state.markers_applied = true
    end
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
    --- Full five-symbol sequence collected: announce + mark immediately.
    if #state.queue >= 5 then
      fire_callouts_once()
    end
    return
  end

  if (subevent == "SPELL_CAST_START" or subevent == "SPELL_CAST_SUCCESS") and spell_id == SPELL_LASER then
    state.laser_active = true
    state.phase = "beam"
    state.active_step = 1
    --- Beam started; make sure callouts went out even if < 5 runes seen.
    fire_callouts_once()
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
-- Player lookup + 3D / 2D draw helpers
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

--- Screen position (vec2) above a unit's head, applying a yard offset on Z.
local function screen_pos_above_unit(unit, dy)
  local pos = world_pos_above_unit(unit, dy)
  if not pos then return nil end
  local g = core and core.graphics
  if not g or not g.w2s then return nil end
  local ok, p2 = pcall(g.w2s, pos)
  if ok and p2 then return p2 end
  return nil
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

----------------------------------------------------------------------
-- Render
----------------------------------------------------------------------

local function overlay_cfg()
  local c = cfg()
  return (c and c.overlay) or { enabled = true, x = 400, y = 150, showIcons = true }
end

local function head_cfg()
  local c = cfg()
  return (c and c.headIcons)
    or { enabled = true, size = 26, heightZ = FLOAT_OFFSET_Y, showNumber = true, showName = false }
end

--- 2D HUD: the full ordered sequence with little symbol chips.
local function render_overlay(now, step)
  local oc = overlay_cfg()
  if oc.enabled == false then return end

  local x = oc.x or 400
  local y = oc.y or 150

  draw_text_2d_screen("Death's Dirge — run-in order", v2(x, y), 16, { r = 255, g = 255, b = 255, a = 255 })
  y = y + 24

  for i = 1, #state.queue do
    local slot = state.queue[i]
    local active = (state.phase == "beam" and state.laser_active and i == step)
    local col = active and slot.color or dim_color(slot.color, 0.4)

    if oc.showIcons ~= false and Markers and Markers.draw_glyph then
      pcall(Markers.draw_glyph, slot.shape, v2(x + 10, y + 8), 16, slot.color, {
        alpha = active and 255 or 150,
      })
    end

    local prefix = active and "> " or "  "
    draw_text_2d_screen(
      string.format("%s%d  %s  —  %s", prefix, i, slot.name or "?", slot.label or "?"),
      v2(x + 24, y),
      14,
      col
    )
    y = y + 22
  end
end

--- 3D world: symbol icon above each assigned player's head.
local function render_head_icons(now, step)
  local hc = head_cfg()
  if hc.enabled == false then return end
  local size = hc.size or 26
  local dz = hc.heightZ or FLOAT_OFFSET_Y

  for i = 1, #state.queue do
    local slot = state.queue[i]
    local u = unit_by_name(slot.name)
    if u then
      local active = (state.phase == "beam" and state.laser_active and i == step)
      local flashing = active and now < state.flash_until
      local sp = screen_pos_above_unit(u, dz)

      if sp and Markers and Markers.draw_glyph then
        local draw_size = flashing and (size * 1.5) or (active and size * 1.25 or size)
        pcall(Markers.draw_glyph, slot.shape, sp, draw_size, slot.color, {
          alpha  = active and 255 or 170,
          number = (hc.showNumber ~= false) and i or nil,
          name   = (hc.showName == true) and slot.name or nil,
        })
      elseif Draw and Draw.text_3d then
        --- Fallback when w2s is unavailable: 3D text label.
        local pos = world_pos_above_unit(u, dz)
        if pos then
          local col = active and slot.color or dim_color(slot.color, 0.4)
          Draw.text_3d(string.format("[%d] %s", i, slot.label), pos, active and 20 or 14, col, true)
        end
      end

      --- Ground ring under the player who must run in right now.
      if flashing and World and World.position then
        local ground = World.position(u)
        if ground and root_ref and root_ref.Draw and root_ref.Draw.Circle3D then
          root_ref.Draw.Circle3D(ground, 4.0, rgba_f_to_draw(1, 0.15, 0.15, 0.85), 3.0, 40, true, 90)
        elseif ground and Draw and Draw.circle_3d then
          Draw.circle_3d(ground, 4.0, { r = 255, g = 50, b = 50, a = 220 }, 3, 40, true, 85)
        end
      end
    end
  end
end

local function dirge_on_render()
  if not hooks_allowed() then return end
  if state.phase == "idle" and #state.queue == 0 then return end

  local now = (core and core.time and core.time()) or os.clock()
  local step = state.active_step

  render_overlay(now, step)
  render_head_icons(now, step)
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
          if #state.queue >= 5 then
            fire_callouts_once()
          end
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
    fire_callouts_once()
  else
    last_laser_casting = false
  end
end

local function dirge_on_update()
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

  --- Render + poll are invoked from MidnightFallsDirge/main.lua registered
  --- callbacks so we never replace the host's single-handler slot (some
  --- builds only keep the last `register_on_*` registration).

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

--- Called from `MidnightFallsDirge/main.lua`'s `register_on_update_callback`
--- body so Dirge polling does not compete with other modules for a single
--- host slot.
function M.tick()
  pcall(dirge_on_update)
end

--- Called from `MidnightFallsDirge/main.lua`'s `register_on_render_callback`.
function M.render()
  pcall(dirge_on_render)
end

return M
