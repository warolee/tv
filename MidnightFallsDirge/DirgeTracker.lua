--[[ DirgeTracker — Midnight Falls "Death's Dirge" memory-game tracker.

     Detection is built on the REAL Project Sylvanas API (verified against
     github.com/bluesilvi/project-sylvanas, legacy/_api):

       * core.register_on_spell_cast_callback(fn) — fires for EVERY spell cast
         with data = { spell_id, caster, target, spell_cast_time }. This is how
         we catch the boss casting Death's Dirge (start), the laser (beam), and
         the laser hits (who ran in). There is no combat-log callback on the
         platform, which is why the old combat-log path never fired.
       * game_object:get_auras()/get_buffs()/get_debuffs() — to read the rune
         symbols the boss brands onto players (via World.for_each_aura).
       * core.object_manager.get_all_objects() filtered by is_player() — there
         is no get_all_players(); World.lua handles this.
       * core.play_sound_by_id(id) for the audio cue.

     Discovery mode: set Config.debug.logEvents = true to log every spell cast
     (id + name + caster/target), and Config.debug.dumpAuras = true to log every
     new aura seen on players. Use these in-game when the memory game starts to
     confirm the real spell IDs, then put them in Config.spells / Config.runes
     if the defaults below are wrong for your build.

     `main.lua` calls `DirgeTracker.install(ROOT)` with the table from Config. ]]

local M = {}

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

--- Default rune aura → label + RGBA (0–1 floats) + raid marker index + shape.
--- Override per build via Config.runes (same shape) if these IDs are wrong.
local RUNE_AURA_MAP = {
  [479151] = { label = "CROSS (X)",   color = { 1.0, 0.3, 0.3, 1.0 }, marker = 7, shape = "cross" },
  [479152] = { label = "SQUARE (T)",  color = { 0.3, 0.3, 1.0, 1.0 }, marker = 6, shape = "square" },
  [479153] = { label = "CIRCLE",      color = { 1.0, 0.8, 0.0, 1.0 }, marker = 2, shape = "circle" },
  [479154] = { label = "DIAMOND",     color = { 0.8, 0.3, 1.0, 1.0 }, marker = 3, shape = "diamond" },
  [479155] = { label = "TRIANGLE",    color = { 0.2, 1.0, 0.2, 1.0 }, marker = 4, shape = "triangle" },
}

local DEFAULT_DIRGE_START = 479150
local DEFAULT_LASER       = 479160
local DEFAULT_LASER_HIT   = 479165

local FLOAT_OFFSET_Y = 3.5

----------------------------------------------------------------------
-- State
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
  announced       = false,
  markers_applied = false,
}

local aura_seen = {}
local logged_auras = {}
local logged_casts = {}

local function now_s()
  if core and core.time then
    local ok, t = pcall(core.time)
    if ok and type(t) == "number" then return t end
  end
  return os.clock()
end

local function cfg()
  return root_ref and root_ref.Config or nil
end

----------------------------------------------------------------------
-- Spell-id / rune config (overridable via Config)
----------------------------------------------------------------------

local function spell_ids()
  local c = cfg()
  local s = (c and c.spells) or {}
  return s.dirgeStart or DEFAULT_DIRGE_START,
         s.laser or DEFAULT_LASER,
         s.laserHit or DEFAULT_LASER_HIT
end

local function rune_meta(id)
  local c = cfg()
  if c and type(c.runes) == "table" and c.runes[id] then
    return c.runes[id]
  end
  return RUNE_AURA_MAP[id]
end

local function any_rune_id(id)
  return rune_meta(id) ~= nil
end

----------------------------------------------------------------------
-- Debug discovery logging
----------------------------------------------------------------------

local function log(msg)
  if core and core.log then pcall(core.log, msg) end
end

local function spell_name(id)
  local ok, n = pcall(function()
    if core and core.spell_book and core.spell_book.get_spell_name then
      return core.spell_book.get_spell_name(id)
    end
    return nil
  end)
  if ok and type(n) == "string" and n ~= "" then return n end
  return "?"
end

local function debug_log_cast(id, caster, target)
  local c = cfg()
  if not c or not c.debug or not c.debug.logEvents then return end
  if logged_casts[id] and (now_s() - logged_casts[id]) < 1.0 then return end
  logged_casts[id] = now_s()
  local cn = caster and World and World.name and World.name(caster) or "?"
  local tn = target and World and World.name and World.name(target) or "?"
  log(string.format("[Dirge][cast] id=%s (%s) caster=%s target=%s",
    tostring(id), spell_name(id), tostring(cn), tostring(tn)))
end

local function debug_dump_player_auras()
  local c = cfg()
  if not c or not c.debug or not c.debug.dumpAuras then return end
  if not World or not World.all_players then return end
  for _, p in ipairs(World.all_players()) do
    local nm = World.name(p) or "?"
    World.for_each_aura(p, function(bid, b)
      local key = tostring(nm) .. ":" .. tostring(bid)
      if not logged_auras[key] then
        logged_auras[key] = true
        log(string.format("[Dirge][aura] player=%s buff_id=%s name=%s",
          nm, tostring(bid), tostring(b.buff_name or "?")))
      end
    end)
  end
end

----------------------------------------------------------------------
-- Sequence bookkeeping
----------------------------------------------------------------------

local function clear_markers_for(queue)
  if Markers and Markers.clear and root_ref and root_ref.Config then
    pcall(Markers.clear, root_ref.Config, queue)
  end
end

local function reset_sequence()
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
  if not root_ref or not root_ref.Config then return true end
  if root_ref.Config.enabled == false then return false end
  local beh = root_ref.Config.behavior
  if not beh then return true end
  return beh.dataSource ~= "AddonOnly"
end

local function push_slot(dest_name, spell_id)
  if not dest_name or dest_name == "" then return end
  if state.seen_names[dest_name] then return end
  if #state.queue >= 5 then return end
  local meta = rune_meta(spell_id)
  if not meta then return end
  state.seen_names[dest_name] = true
  local col = meta.color or { 1, 1, 1, 1 }
  local c = rgba_f_to_draw(col[1], col[2], col[3], col[4])
  state.queue[#state.queue + 1] = {
    name    = dest_name,
    spellId = spell_id,
    label   = meta.label or spell_name(spell_id),
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

local function advance_for(name)
  if state.phase ~= "beam" then return end
  local expect = current_expected()
  if expect and name and expect.name == name then
    state.flash_until = now_s() + 1.25
    state.flash_label = expect.label
    advance_step()
  end
end

local function play_alert_sound()
  local c = cfg()
  if not c or not c.sound or not c.sound.enabled then return end
  local fid = c.sound.fileId
  pcall(function()
    if core and core.play_sound_by_id then core.play_sound_by_id(fid); return end
    if core and core.play_sound then core.play_sound(fid); return end
    if type(PlaySound) == "function" then PlaySound(fid) end
  end)
end

--- Fire chat callouts, raid markers, and the sound cue once per sequence.
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
    if ok and n and n > 0 then state.markers_applied = true end
  end
end

----------------------------------------------------------------------
-- Spell-cast callback (the real detection path)
----------------------------------------------------------------------

local function handle_spell_cast(data)
  if not hooks_allowed() then return end
  if type(data) ~= "table" then return end
  local id = data.spell_id or data.spellId or data.id
  if not id then return end

  local caster = data.caster
  local target = data.target
  debug_log_cast(id, caster, target)

  local DIRGE, LASER, HIT = spell_ids()

  if id == DIRGE then
    reset_sequence()
    state.phase = "recording"
    return
  end

  if id == LASER then
    state.laser_active = true
    state.phase = "beam"
    state.active_step = 1
    fire_callouts_once()
    return
  end

  if id == HIT then
    local nm = target and World and World.name and World.name(target) or nil
    advance_for(nm)
    return
  end

  --- Some bosses brand each player with a per-target rune cast. If that's how
  --- this build works, record straight from the cast's target.
  if any_rune_id(id) then
    if state.phase == "idle" then
      reset_sequence()
      state.phase = "recording"
    end
    if state.phase == "recording" then
      local nm = target and World and World.name and World.name(target) or nil
      push_slot(nm, id)
      if #state.queue >= 5 then fire_callouts_once() end
    end
  end
end

--- Public hooks for tests / external feeds.
function M.feed_spell_cast(data) handle_spell_cast(data) end
function M.feed_combat_event() end --- retained no-op (no combat-log API)

----------------------------------------------------------------------
-- Player lookup + draw helpers
----------------------------------------------------------------------

local function unit_by_name(name)
  if not World or not World.all_players or not name then return nil end
  for _, u in ipairs(World.all_players()) do
    if World.name(u) == name then return u end
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
  if not g or not g.text_2d or not text or not pos then return end
  local col = (Draw and Draw.color and Draw.color(color_tbl)) or color_tbl or { r = 255, g = 255, b = 255, a = 255 }
  pcall(function()
    g.text_2d(tostring(text), pos, size_px or 14, col)
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
      v2(x + 24, y), 14, col
    )
    y = y + 22
  end

  if #state.queue == 0 and state.phase == "recording" then
    draw_text_2d_screen("Death's Dirge cast — reading runes...", v2(x, y), 13, { r = 255, g = 220, b = 120, a = 230 })
  end
end

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
        local pos = world_pos_above_unit(u, dz)
        if pos then
          local col = active and slot.color or dim_color(slot.color, 0.4)
          Draw.text_3d(string.format("[%d] %s", i, slot.label), pos, active and 20 or 14, col, true)
        end
      end

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
  local now = now_s()
  render_overlay(now, state.active_step)
  render_head_icons(now, state.active_step)
end

----------------------------------------------------------------------
-- Polling (auras + boss casts) — backup to the spell-cast callback
----------------------------------------------------------------------

local function poll_world()
  if not hooks_allowed() then return end
  if not World or not World.all_players then return end

  debug_dump_player_auras()

  local DIRGE, LASER = spell_ids()

  --- Boss cast detection as a backup to the spell-cast callback.
  if World.all_enemies then
    for _, e in ipairs(World.all_enemies()) do
      local c = World.active_cast and World.active_cast(e)
      if c then
        if c.spell_id == DIRGE and state.phase == "idle" then
          reset_sequence()
          state.phase = "recording"
        elseif c.spell_id == LASER and state.phase ~= "beam" then
          state.laser_active = true
          state.phase = "beam"
          state.active_step = 1
          fire_callouts_once()
        end
      end
    end
  end

  --- Read rune auras off players. Auto-starts recording if a rune shows up
  --- even when we missed the boss cast.
  for _, p in ipairs(World.all_players()) do
    local guid = World.guid and World.guid(p) or tostring(p)
    World.for_each_aura(p, function(bid)
      if not any_rune_id(bid) then return end
      local key = tostring(guid) .. ":" .. tostring(bid)
      if aura_seen[key] then return end
      aura_seen[key] = true
      if state.phase == "idle" then state.phase = "recording" end
      if state.phase == "recording" then
        local nm = World.name and World.name(p) or nil
        push_slot(nm, bid)
        if #state.queue >= 5 then fire_callouts_once() end
      end
    end)
  end
end

----------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------

local spell_cb_installed

local function register_spell_cast()
  if spell_cb_installed then return true end
  local ok = pcall(function()
    if core and core.register_on_spell_cast_callback then
      core.register_on_spell_cast_callback(function(data)
        pcall(handle_spell_cast, data)
      end)
      spell_cb_installed = true
      return true
    end
  end)
  return ok and spell_cb_installed or false
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

  register_spell_cast()

  if core and core.log then
    core.log("[DirgeTracker] installed (spell_cast hook=" .. tostring(spell_cb_installed == true) .. ")")
  end
end

function M.state() return state end

function M.wipe_runtime_structures()
  reset_sequence()
end

--- Called from main.lua's update callback. Runs the polling backup.
function M.tick()
  pcall(poll_world)
end

--- Called from main.lua's render callback.
function M.render()
  pcall(dirge_on_render)
end

return M
