--[[ MythicMechanicsSuite — ghost core.menu widgets for the Astro window.

     The rotation_settings_ui library (astro_custom_ui/) takes `core.menu.*`
     objects as the canonical state holders for checkboxes / sliders and
     reads / writes them via :get_state() / :get() / :set(). Sylvanas
     persists those values across `/reload` automatically using the
     element id we pass in, so they survive injection cycles even
     before our own scripts_data/ save fires.

     This module:
       - Builds one ghost element per knob we want in the UI.
       - Provides `sync_config_to_menu` (push Config -> ghost elements)
         and `sync_menu_to_config` (pull ghost elements -> Config,
         flagging Persistence.mark_dirty when anything actually changed).

     If `core.menu` isn't available the whole module short-circuits and
     `M.create` returns nil — UI.lua then falls back to a "notice"
     tab so the plugin still loads. ]]

local M = {}

local Persistence = require("Persistence")

local function eid(s) return "mms_" .. s end

local function menu_cb(def, id)
  if core and core.menu and core.menu.checkbox then
    return core.menu.checkbox(def and true or false, id)
  end
  return nil
end

local function menu_slider(lo, hi, def, id)
  if not (core and core.menu) then return nil end
  if core.menu.slider_int then
    return core.menu.slider_int(lo, hi, def, id)
  end
  if core.menu.slider then
    local sl = core.menu.slider(lo, hi, def, id)
    if sl and sl.as_int then return sl:as_int() end
    return sl
  end
  return nil
end

--- Build a combobox. Sylvanas exposes `core.menu.combobox` on most
--- builds; we degrade to a slider_int when it isn't present so the
--- selector still renders (just as a tiny number you type into).
local function menu_combo(default_index, id, n_choices)
  if not (core and core.menu) then return nil end
  if core.menu.combobox then
    return core.menu.combobox(default_index or 0, id)
  end
  if core.menu.slider_int then
    return core.menu.slider_int(0, math.max(0, (n_choices or 1) - 1), default_index or 0, id)
  end
  return nil
end

local function get_cb(el)
  if not el then return false end
  local ok, v = pcall(function()
    if el.get_state then return el:get_state() == true end
    if el.get       then return el:get() == true end
    return false
  end)
  return ok and v or false
end

local function set_cb(el, v)
  if not el then return end
  pcall(function()
    if el.set_state then el:set_state(v and true or false); return end
    if el.set       then el:set(v and true or false) end
  end)
end

local function get_slider(el)
  if not el then return nil end
  local ok, v = pcall(function()
    if el.get then return el:get() end
    return nil
  end)
  if ok and type(v) == "number" then return v end
  return nil
end

local function set_slider(el, v)
  if not el then return end
  pcall(function()
    if el.set then el:set(v) end
  end)
end

--- Combobox accessors mirror the slider ones — Project Sylvanas
--- combobox objects use the same :get() / :set() integer-index API.
local get_combo = get_slider
local set_combo = set_slider

--- Bidirectional mapping for `Config.behavior.dataSource`.
local DATA_SOURCE_OPTIONS = { "Auto", "HardcodedOnly", "AddonOnly" }
local DATA_SOURCE_INDEX   = { Auto = 0, HardcodedOnly = 1, AddonOnly = 2 }

local function data_source_to_index(s)
  return DATA_SOURCE_INDEX[s] or 0
end

local function data_source_from_index(i)
  if type(i) ~= "number" then return "Auto" end
  return DATA_SOURCE_OPTIONS[i + 1] or "Auto"
end

--- Exposed so UI.lua can pass the same label array into the
--- `combo_list` builder's `options` field.
function M.data_source_options()
  return { DATA_SOURCE_OPTIONS[1], DATA_SOURCE_OPTIONS[2], DATA_SOURCE_OPTIONS[3] }
end

--- Build ghost elements. Defaults are seeded from `root.Config` so the
--- UI opens showing the user's saved values on the very first frame.
function M.create(root)
  if not (core and core.menu) then return nil end
  local cfg = root.Config
  if type(cfg) ~= "table" then return nil end
  local draw   = cfg.draw  or {}
  local sound  = cfg.sound or {}
  local debug  = cfg.debug or {}
  local ui     = cfg.ui    or {}
  local behav  = cfg.behavior or {}
  local mirror = cfg.mirror   or {}

  return {
    --- Boolean knobs (Settings tab)
    cb_enabled       = menu_cb(cfg.enabled ~= false, eid("enabled")),
    cb_instance_only = menu_cb(cfg.instanceOnly ~= false, eid("instance_only")),
    cb_sound         = menu_cb(sound.enabled ~= false, eid("sound")),
    cb_fill_circles  = menu_cb(draw.fillCircles ~= false, eid("fill_circles")),
    cb_outline       = menu_cb(draw.outlineWhenFilled ~= false, eid("outline")),
    cb_cone_filled   = menu_cb(draw.coneFilled ~= false, eid("cone_filled")),
    cb_drop_on_gone  = menu_cb(behav.dropOnAnchorGone ~= false, eid("drop_on_gone")),
    cb_show_hud      = menu_cb(debug.showHUD == true, eid("show_hud")),
    cb_log_events    = menu_cb(debug.logEvents == true, eid("log_events")),
    cb_verbose       = menu_cb(debug.verbose == true, eid("verbose")),

    --- BigWigs / DBM bridge toggles
    cb_mirror_dbm     = menu_cb(mirror.dbm == true,     eid("mirror_dbm")),
    cb_mirror_bw      = menu_cb(mirror.bigwigs == true, eid("mirror_bw")),
    cb_mirror_generic = menu_cb(mirror.generic_fallback == true, eid("mirror_generic")),

    --- Data-source routing (combobox: Auto / HardcodedOnly / AddonOnly).
    --- The index is what the menu element stores; we translate to/
    --- from the string at sync time.
    combo_data_source = menu_combo(
      data_source_to_index(behav.dataSource or "Auto"),
      eid("data_source"),
      #DATA_SOURCE_OPTIONS
    ),

    --- Numeric knobs (Settings tab sliders).
    --- We use integer sliders and scale by 10/100/1000 inside
    --- `sync_*_to_*` so the user sees clean integer steps.
    slider_circle_thick_x10  = menu_slider(5, 80, math.floor(((draw.circleThickness or 2.5) * 10) + 0.5), eid("circ_thick_x10")),
    slider_line_thick_x10    = menu_slider(5, 80, math.floor(((draw.lineThickness or 2.5) * 10) + 0.5),  eid("line_thick_x10")),
    slider_default_radius    = menu_slider(2, 60, math.floor((draw.defaultRadius or 6) + 0.5),           eid("default_radius")),
    slider_fill_alpha        = menu_slider(0, 200, math.floor((draw.fillAlpha or 50) + 0.5),             eid("fill_alpha")),
    slider_circle_segments   = menu_slider(12, 96, math.floor((draw.circleSegments or 48) + 0.5),        eid("circ_segments")),
    slider_text_size         = menu_slider(8, 36, math.floor((draw.text3dSize or 16) + 0.5),             eid("text_size")),
    slider_sound_cooldown_x10 = menu_slider(0, 100, math.floor(((sound.cooldown or 1.25) * 10) + 0.5),   eid("sound_cd_x10")),
    slider_per_mech_x10      = menu_slider(0, 200, math.floor(((sound.perMechanic or 4.0) * 10) + 0.5),  eid("per_mech_x10")),
    slider_alert_fdid        = menu_slider(0, 999999, math.floor((sound.alert or 8959) + 0.5),           eid("alert_fdid")),
    slider_poll_ms           = menu_slider(10, 500, math.floor(((behav.pollIntervalSec or 0.05) * 1000) + 0.5), eid("poll_ms")),
    slider_rescan_x100       = menu_slider(5, 200, math.floor(((behav.rescanIntervalSec or 0.20) * 100) + 0.5), eid("rescan_x100")),
    slider_max_active        = menu_slider(4, 96, math.floor((behav.maxActiveMechanics or 24) + 0.5),    eid("max_active")),
  }
end

--- Push the live `root.Config` values into the ghost elements. Called
--- on first install + every time the window is opened (so changes the
--- user made via `/reload` come back through).
function M.sync_config_to_menu(root, m)
  if not m then return end
  local cfg = root.Config or {}
  local draw  = cfg.draw  or {}
  local sound = cfg.sound or {}
  local debug = cfg.debug or {}
  local behav = cfg.behavior or {}

  set_cb(m.cb_enabled,       cfg.enabled ~= false)
  set_cb(m.cb_instance_only, cfg.instanceOnly ~= false)
  set_cb(m.cb_sound,         sound.enabled ~= false)
  set_cb(m.cb_fill_circles,  draw.fillCircles ~= false)
  set_cb(m.cb_outline,       draw.outlineWhenFilled ~= false)
  set_cb(m.cb_cone_filled,   draw.coneFilled ~= false)
  set_cb(m.cb_drop_on_gone,  behav.dropOnAnchorGone ~= false)
  set_cb(m.cb_show_hud,      debug.showHUD == true)
  set_cb(m.cb_log_events,    debug.logEvents == true)
  set_cb(m.cb_verbose,       debug.verbose == true)

  local mirror = cfg.mirror or {}
  set_cb(m.cb_mirror_dbm,     mirror.dbm == true)
  set_cb(m.cb_mirror_bw,      mirror.bigwigs == true)
  set_cb(m.cb_mirror_generic, mirror.generic_fallback == true)

  set_combo(m.combo_data_source, data_source_to_index(behav.dataSource or "Auto"))

  set_slider(m.slider_circle_thick_x10,  math.floor(((draw.circleThickness or 2.5) * 10) + 0.5))
  set_slider(m.slider_line_thick_x10,    math.floor(((draw.lineThickness   or 2.5) * 10) + 0.5))
  set_slider(m.slider_default_radius,    math.floor((draw.defaultRadius   or 6) + 0.5))
  set_slider(m.slider_fill_alpha,        math.floor((draw.fillAlpha       or 50) + 0.5))
  set_slider(m.slider_circle_segments,   math.floor((draw.circleSegments  or 48) + 0.5))
  set_slider(m.slider_text_size,         math.floor((draw.text3dSize      or 16) + 0.5))
  set_slider(m.slider_sound_cooldown_x10, math.floor(((sound.cooldown    or 1.25) * 10) + 0.5))
  set_slider(m.slider_per_mech_x10,      math.floor(((sound.perMechanic  or 4.0) * 10) + 0.5))
  set_slider(m.slider_alert_fdid,        math.floor((sound.alert         or 8959) + 0.5))
  set_slider(m.slider_poll_ms,           math.floor(((behav.pollIntervalSec or 0.05) * 1000) + 0.5))
  set_slider(m.slider_rescan_x100,       math.floor(((behav.rescanIntervalSec or 0.20) * 100) + 0.5))
  set_slider(m.slider_max_active,        math.floor((behav.maxActiveMechanics or 24) + 0.5))
end

local function signature(m)
  --- Cheap "did anything actually change" hash. We don't need crypto;
  --- we just want to debounce Persistence.mark_dirty when the user is
  --- merely hovering the cursor over a slider.
  return table.concat({
    get_cb(m.cb_enabled)       and "1" or "0",
    get_cb(m.cb_instance_only) and "1" or "0",
    get_cb(m.cb_sound)         and "1" or "0",
    get_cb(m.cb_fill_circles)  and "1" or "0",
    get_cb(m.cb_outline)       and "1" or "0",
    get_cb(m.cb_cone_filled)   and "1" or "0",
    get_cb(m.cb_drop_on_gone)  and "1" or "0",
    get_cb(m.cb_show_hud)      and "1" or "0",
    get_cb(m.cb_log_events)    and "1" or "0",
    get_cb(m.cb_verbose)       and "1" or "0",
    get_cb(m.cb_mirror_dbm)     and "1" or "0",
    get_cb(m.cb_mirror_bw)      and "1" or "0",
    get_cb(m.cb_mirror_generic) and "1" or "0",
    tostring(get_combo(m.combo_data_source)),
    tostring(get_slider(m.slider_circle_thick_x10)),
    tostring(get_slider(m.slider_line_thick_x10)),
    tostring(get_slider(m.slider_default_radius)),
    tostring(get_slider(m.slider_fill_alpha)),
    tostring(get_slider(m.slider_circle_segments)),
    tostring(get_slider(m.slider_text_size)),
    tostring(get_slider(m.slider_sound_cooldown_x10)),
    tostring(get_slider(m.slider_per_mech_x10)),
    tostring(get_slider(m.slider_alert_fdid)),
    tostring(get_slider(m.slider_poll_ms)),
    tostring(get_slider(m.slider_rescan_x100)),
    tostring(get_slider(m.slider_max_active)),
  }, "|")
end

--- Pull ghost-element state into root.Config. Idempotent: no-op when
--- nothing changed. Marks Persistence dirty when it did.
function M.sync_menu_to_config(root, m)
  if not m then return end
  local sig = signature(m)
  if sig == root._mms_menu_sig then return end
  root._mms_menu_sig = sig

  local cfg = root.Config
  if type(cfg) ~= "table" then return end
  cfg.draw     = cfg.draw     or {}
  cfg.sound    = cfg.sound    or {}
  cfg.debug    = cfg.debug    or {}
  cfg.behavior = cfg.behavior or {}
  cfg.mirror   = cfg.mirror   or {}

  cfg.enabled      = get_cb(m.cb_enabled)
  cfg.instanceOnly = get_cb(m.cb_instance_only)
  cfg.sound.enabled        = get_cb(m.cb_sound)
  cfg.draw.fillCircles     = get_cb(m.cb_fill_circles)
  cfg.draw.outlineWhenFilled = get_cb(m.cb_outline)
  cfg.draw.coneFilled      = get_cb(m.cb_cone_filled)
  cfg.behavior.dropOnAnchorGone = get_cb(m.cb_drop_on_gone)
  cfg.debug.showHUD        = get_cb(m.cb_show_hud)
  cfg.debug.logEvents      = get_cb(m.cb_log_events)
  cfg.debug.verbose        = get_cb(m.cb_verbose)

  cfg.mirror.dbm              = get_cb(m.cb_mirror_dbm)
  cfg.mirror.bigwigs          = get_cb(m.cb_mirror_bw)
  cfg.mirror.generic_fallback = get_cb(m.cb_mirror_generic)

  --- Routing selector. Reject unknown indices (the combobox should
  --- never produce one, but a tampered persistence file could).
  local idx = get_combo(m.combo_data_source)
  local new_source = data_source_from_index(idx)
  if new_source ~= cfg.behavior.dataSource then
    cfg.behavior.dataSource = new_source
  end

  local function ns(el, scale, fallback)
    local v = get_slider(el)
    if type(v) ~= "number" then return fallback end
    return v / scale
  end
  cfg.draw.circleThickness = ns(m.slider_circle_thick_x10, 10, cfg.draw.circleThickness or 2.5)
  cfg.draw.lineThickness   = ns(m.slider_line_thick_x10,   10, cfg.draw.lineThickness   or 2.5)
  cfg.draw.defaultRadius   = ns(m.slider_default_radius,   1,  cfg.draw.defaultRadius   or 6.0)
  cfg.draw.fillAlpha       = ns(m.slider_fill_alpha,       1,  cfg.draw.fillAlpha       or 50)
  cfg.draw.circleSegments  = ns(m.slider_circle_segments,  1,  cfg.draw.circleSegments  or 48)
  cfg.draw.text3dSize      = ns(m.slider_text_size,        1,  cfg.draw.text3dSize      or 16)
  cfg.sound.cooldown       = ns(m.slider_sound_cooldown_x10, 10, cfg.sound.cooldown     or 1.25)
  cfg.sound.perMechanic    = ns(m.slider_per_mech_x10,     10, cfg.sound.perMechanic    or 4.0)
  cfg.sound.alert          = ns(m.slider_alert_fdid,       1,  cfg.sound.alert          or 8959)
  cfg.behavior.pollIntervalSec   = ns(m.slider_poll_ms,    1000, cfg.behavior.pollIntervalSec   or 0.05)
  cfg.behavior.rescanIntervalSec = ns(m.slider_rescan_x100, 100, cfg.behavior.rescanIntervalSec or 0.20)
  cfg.behavior.maxActiveMechanics = ns(m.slider_max_active, 1,  cfg.behavior.maxActiveMechanics or 24)

  Persistence.mark_dirty(root)
end

return M
