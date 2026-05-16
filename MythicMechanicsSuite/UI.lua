--[[ MythicMechanicsSuite — UI: integrate astro_custom_ui/rotation_settings_ui.

     Replaces the previous hand-rolled `core.graphics.*` overlay with
     the Astro custom window (same library ScienceAHBot uses). The
     window is built from:

       1. Settings   — checkbox_grid + slider_list (ghost elements)
       2. Appearance — presets, global alpha, per-palette RGB sliders
       3. One tab per dungeon / raid wing — bosses, mechanics, toggles,
                       palette override chips (`data/encounter_tab_groups.lua`)
       4. Active     — live HUD + test / clear (AstroPanels)

     Sylvanas-native menu: one `core.menu.tree_node` titled with the
     suite name, containing a master checkbox (world drawings) and a
     UI checkbox (settings window), mirroring ScienceAHBot's PSMenu shape.

     `astro_custom_ui/` is shipped inside this plugin folder so
     `require("astro_custom_ui/rotation_settings_ui")` resolves without
     extra copies. If the library still fails to load, UI.lua logs a
     warning and the mechanic engine keeps running. ]]

local M = {}

local Util       = require("Util")
local AstroMenu  = require("AstroMenu")
local AstroPanels = require("AstroPanels")
local Persistence = require("Persistence")
local Mechanics  = require("Mechanics")
local Encounters = require("Encounters")

----------------------------------------------------------------------
-- Resolve the rotation_settings_ui library
----------------------------------------------------------------------
local RotationUI = nil
do
  local paths = {
    "astro_custom_ui/rotation_settings_ui",
    "shared/rotation_settings_ui",          -- some forks put it here
  }
  for _, p in ipairs(paths) do
    local ok, mod = pcall(require, p)
    if ok and mod and mod.new then
      RotationUI = mod
      break
    end
  end
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function toggle_key_edge(root)
  local ui = root.Config and root.Config.ui or {}
  local vk = ui.toggleKey or 0x78 -- F9
  local down = false
  pcall(function()
    if core and core.input and core.input.is_key_pressed then
      down = core.input.is_key_pressed(vk)
    end
  end)
  local prev = root._mms_toggle_prev
  root._mms_toggle_prev = down
  return down and not prev
end

local function window_local_mouse(rsu)
  if not rsu or not rsu.window then return nil, nil end
  local okm, mp = pcall(function() return rsu.window:get_mouse_pos() end)
  local okp, wp = pcall(function() return rsu.window:get_position() end)
  if not okm or not okp or not mp or not wp then return nil, nil end
  return mp.x - wp.x, mp.y - wp.y
end

local function set_window_enable(ui, on)
  if not (ui and ui.menu and ui.menu.enable) then return end
  pcall(function()
    if ui.menu.enable.set_state then
      ui.menu.enable:set_state(on and true or false)
    elseif ui.menu.enable.set then
      ui.menu.enable:set(on and true or false)
    end
  end)
end

local function get_window_enable(ui)
  if not (ui and ui.menu and ui.menu.enable) then return false end
  local ok, v = pcall(function()
    if ui.menu.enable.get_state then return ui.menu.enable:get_state() == true end
    if ui.menu.enable.get       then return ui.menu.enable:get() == true end
    return false
  end)
  return ok and v or false
end

----------------------------------------------------------------------
-- Sylvanas native menu (suite name → Master toggle + UI toggle)
----------------------------------------------------------------------
local function install_native_menu(root)
  if root._mms_native_menu_installed then return end
  if not (core and core.menu and core.menu.tree_node and core.menu.checkbox
          and core.register_on_render_menu_callback) then
    return
  end
  root._mms_native_menu_installed = true

  pcall(function()
    root._mms_ps_tree = core.menu.tree_node()
    root._mms_master = core.menu.checkbox(root.Config.enabled ~= false, "mms_master_enable_v2")
  end)

  pcall(function()
    core.register_on_render_menu_callback(function()
      Util.try("UI.native_menu", function()
        if not (root._mms_ps_tree and root._mms_master) then return end
        root._mms_ps_tree:render("Mythic Mechanics Suite", function()
          root._mms_master:render("Master toggle")
          local ui = root._mms_astro
          if ui and ui.menu and ui.menu.enable then
            ui.menu.enable:render("UI toggle")
          end
        end)
        --- Mirror native master ↔ Config.enabled. The Astro window's
        --- Settings tab also has a "Master enable" checkbox bound to
        --- the same Config field, so both knobs stay in sync via
        --- AstroMenu.sync_menu_to_config.
        local on
        pcall(function()
          if root._mms_master.get_state then on = root._mms_master:get_state() == true end
        end)
        if on ~= nil and on ~= root.Config.enabled then
          root.Config.enabled = on
          if root._mms_ghosts and root._mms_ghosts.cb_enabled then
            pcall(function() root._mms_ghosts.cb_enabled:set_state(on) end)
          end
          Persistence.mark_dirty(root)
        end
      end, { root = root })
    end)
  end)
end

----------------------------------------------------------------------
-- Astro window construction
----------------------------------------------------------------------
local function install_astro_window(root)
  if root._mms_astro then return end
  if not RotationUI then
    pcall(function()
      if core and core.log_warning then
        core.log_warning(
          "[MythicMechanicsSuite] astro_custom_ui/rotation_settings_ui missing inside the MythicMechanicsSuite folder; settings window disabled. World mechanics still run if Master toggle is on.")
      end
    end)
    return
  end
  if not (core and core.menu and core.menu.window) then
    pcall(function()
      if core and core.log_warning then
        core.log_warning("[MythicMechanicsSuite] core.menu.window unavailable; Astro UI window disabled.")
      end
    end)
    return
  end

  local cfg = root.Config or {}
  local ui_cfg = cfg.ui or {}

  --- Ghost menu elements (bound into the checkbox_grid / slider_list
  --- builders below). Stored on `root` so on_update can pull them.
  local m = AstroMenu.create(root)
  root._mms_ghosts = m
  if m then AstroMenu.sync_config_to_menu(root, m) end

  local ui = RotationUI.new({
    id        = "mythic_mechanics_suite_v1",
    title     = "Mythic Mechanics Suite",
    default_x = ui_cfg.x or 80,
    default_y = ui_cfg.y or 90,
    default_w = ui_cfg.w or 540,
    default_h = ui_cfg.h or 720,
    theme     = "astro",
    accessibility_scale = ((ui_cfg.accessibilityScalePct or 100) / 100),
  })
  root._mms_astro = ui

  if m then
    ----------------------------------------------------------------
    -- Tab 1: Settings
    ----------------------------------------------------------------
    ui:add_tab({ id = "settings", label = "Settings" }, function(t)
      t:checkbox_grid({
        label   = "Master",
        columns = 2,
        elements = {
          { element = m.cb_enabled,       label = "Master enable" },
          { element = m.cb_instance_only, label = "Only inside instances" },
          { element = m.cb_sound,         label = "Sound alerts" },
          { element = m.cb_drop_on_gone,  label = "Drop warning if anchor dies" },
        },
      })
      t:checkbox_grid({
        label   = "Drawing",
        columns = 2,
        elements = {
          { element = m.cb_fill_circles, label = "Fill danger circles" },
          { element = m.cb_outline,      label = "Outline when filled" },
          { element = m.cb_cone_filled,  label = "Fill cone slices" },
          { element = m.cb_show_hud,     label = "Debug HUD" },
        },
      })
      t:checkbox_grid({
        label   = "Logging",
        columns = 2,
        elements = {
          { element = m.cb_log_events, label = "Log every trigger" },
          { element = m.cb_verbose,    label = "Verbose chat output" },
        },
      })
      t:checkbox_grid({
        label   = "Integration (BigWigs / DBM)",
        columns = 1,
        elements = {
          { element = m.cb_mirror_dbm,     label = "Mirror Deadly Boss Mods warnings" },
          { element = m.cb_mirror_bw,      label = "Mirror BigWigs warnings" },
          { element = m.cb_mirror_generic, label = "Generic fallback (text above me) for unknown spell IDs" },
        },
      })
      t:combo_list({
        label = "Source routing — Config.behavior.dataSource",
        elements = {
          {
            element = m.combo_data_source,
            label   = "Data source stream",
            options = AstroMenu.data_source_options(),
            tooltip = AstroMenu.data_source_tooltip(),
            --- Wide box so the long routing labels stay readable.
            value_box_width = 360,
          },
        },
      })
      t:slider_list({
        label = "Drawing — sizes / segments",
        elements = {
          { element = m.slider_circle_thick_x10, label = "Circle thickness (×0.1)" },
          { element = m.slider_line_thick_x10,   label = "Line thickness   (×0.1)" },
          { element = m.slider_default_radius,   label = "Default radius (yards)" },
          { element = m.slider_circle_segments,  label = "Circle segments" },
          { element = m.slider_text_size,        label = "3D text size (px)" },
          { element = m.slider_fill_alpha,       label = "Fill alpha (0-200)" },
        },
      })
      t:slider_list({
        label = "Sound",
        elements = {
          { element = m.slider_sound_cooldown_x10, label = "Global cooldown (×0.1 s)" },
          { element = m.slider_per_mech_x10,       label = "Per-mechanic cooldown (×0.1 s)" },
          { element = m.slider_alert_fdid,         label = "Alert FileDataID" },
        },
      })
      t:slider_list({
        label = "Tracker / runtime",
        elements = {
          { element = m.slider_poll_ms,     label = "Aura/cast poll (ms)" },
          { element = m.slider_rescan_x100, label = "Rescan interval (×0.01 s)" },
          { element = m.slider_max_active,  label = "Max active warnings" },
        },
      })
      t:slider_list({
        label = "Astro window — readability (low vision)",
        elements = {
          {
            element = m.slider_ui_accessibility_pct,
            label   = "Text & layout scale",
            suffix  = "%",
            tooltip = "Enlarges tabs, spacing, and controls in this window. Default 100%. Try 125–160% if text feels small. Saved with your other settings.",
          },
        },
      })
    end)

    ----------------------------------------------------------------
    -- Tab 2: Appearance
    ----------------------------------------------------------------
    ui:add_tab({ id = "appearance", label = "Appearance" }, function(t)
      t:combo_list({
        label = "Theme presets",
        elements = {
          {
            element = m.combo_appearance_preset,
            label   = "Preset",
            options = AstroMenu.appearance_preset_options(),
            suffix  = "(any slider edit flips to ‘custom’)",
          },
        },
      })

      t:slider_list({
        label = "Global",
        elements = {
          { element = m.slider_global_alpha_pct, label = "Global alpha multiplier", suffix = "%" },
        },
      })

      --- Live color-swatch preview. Reads cfg.colors each frame so
      --- the swatches animate as the user slides the channel knobs.
      t:custom_panel({
        render = function(rot, y0)
          return AstroPanels.render_appearance_swatches(rot, y0, root)
        end,
      })

      --- One slider_list per editable color. Iterating through
      --- AstroMenu.COLOR_SLIDER_MAP keeps the tab declaration in
      --- sync with the underlying ghost-element layout — adding a
      --- new color to Palette.lua + the map populates the tab
      --- automatically without editing UI.lua.
      for _, row in ipairs(AstroMenu.COLOR_SLIDER_MAP) do
        t:slider_list({
          label = "Color: " .. row.label,
          elements = {
            { element = m[row.r], label = "R" },
            { element = m[row.g], label = "G" },
            { element = m[row.b], label = "B" },
          },
        })
      end

      --- Reset button (custom_panel because rotation_settings_ui has
      --- no native "button" widget — we render a rect + label and use
      --- `is_rect_clicked` for the hit-test, the same trick
      --- ScienceAHBot's "Reset learned patterns" button uses).
      t:custom_panel({
        render = function(rot, y0)
          return AstroPanels.render_appearance_reset(rot, y0, root)
        end,
      })
    end)

    ----------------------------------------------------------------
    -- Encounter tabs: one tab per dungeon / raid wing (see
    -- data/encounter_tab_groups.lua). Each lists bosses + mechanics
    -- with toggles and per-mechanic palette override chips.
    ----------------------------------------------------------------
    do
      local groups = Encounters.tab_group_manifest()
      if #groups == 0 then
        ui:add_tab({ id = "mms_enc_fallback", label = "Encounters" }, function(t)
          t:custom_panel({
            render = function(rot, y0)
              return AstroPanels.render_encounters_fallback_all(rot, y0, root)
            end,
          })
        end)
      else
        for _, grp in ipairs(groups) do
          ui:add_tab({ id = grp.tab_id, label = grp.label }, function(t)
            t:custom_panel({
              render = function(rot, y0)
                return AstroPanels.render_encounter_tab_group(rot, y0, root, grp)
              end,
            })
          end)
        end
      end
    end

    ----------------------------------------------------------------
    -- Active tab
    ----------------------------------------------------------------
    ui:add_tab({ id = "active", label = "Active" }, function(t)
      t:custom_panel({
        render = function(rot, y0)
          return AstroPanels.render_active_panel(rot, y0, root)
        end,
      })
    end)
  else
    --- No core.menu — render a single notice tab so the user knows why
    --- the rich settings tab is missing. Engine still runs.
    ui:add_tab({ id = "notice", label = "Notice" }, function(t)
      t:custom_panel({
        render = function(rot, y0)
          local w = rot.window
          if not w then return y0 end
          local v2 = require("common/geometry/vector_2")
          local en = require("common/enums")
          local body = (rot._body_font_id and rot:_body_font_id())
            or en.window_enums.font_id.FONT_SMALL
          w:render_text(
            body,
            v2.new(12, y0 + 8),
            rot.colors.secondary_accent,
            "core.menu checkboxes/sliders are not available on this Sylvanas build."
          )
          w:render_text(
            body,
            v2.new(12, y0 + 28),
            rot.colors.text_secondary,
            "Mechanic drawings still render in the world — settings just can't persist via menu state."
          )
          return y0 + 60
        end,
      })
    end)
  end

  --- Default visibility from Config.ui.defaultOpen
  set_window_enable(ui, cfg.ui and cfg.ui.defaultOpen ~= false)
end

----------------------------------------------------------------------
-- Callback wiring
----------------------------------------------------------------------
local function register_render(root)
  if root._mms_render_registered then return end
  if not (core and core.register_on_render_callback) then return end
  root._mms_render_registered = true
  pcall(function()
    core.register_on_render_callback(function()
      Util.try("UI.on_render", function()
        if root._mms_astro then
          root._mms_astro:on_render()
        end
      end, { root = root })
    end)
  end)
end

local function register_update(root)
  if root._mms_update_registered then return end
  if not (core and core.register_on_update_callback) then return end
  root._mms_update_registered = true
  pcall(function()
    core.register_on_update_callback(function()
      Util.try("UI.on_update", function()
        --- F9 edge toggles window visibility
        if toggle_key_edge(root) and root._mms_astro then
          set_window_enable(root._mms_astro, not get_window_enable(root._mms_astro))
        end

        --- Mirror Astro window enable → Config.ui.defaultOpen so it
        --- persists across reload via Persistence.save.
        if root._mms_astro then
          local on = get_window_enable(root._mms_astro)
          if root.Config.ui and on ~= root.Config.ui.defaultOpen then
            root.Config.ui = root.Config.ui or {}
            root.Config.ui.defaultOpen = on
            Persistence.mark_dirty(root)
          end
        end

        --- Pull ghost-element edits into Config (debounce-save inside).
        local show = root._mms_astro and get_window_enable(root._mms_astro) or false
        if show and root._mms_ghosts then
          AstroMenu.sync_menu_to_config(root, root._mms_ghosts)
        end

        if root._mms_astro and root._mms_astro.set_accessibility_scale then
          local pct = (root.Config.ui and root.Config.ui.accessibilityScalePct) or 100
          root._mms_astro:set_accessibility_scale(pct / 100)
        end

        --- Wheel scroll for encounter lists (any tab whose id starts
        --- with `mms_enc_`).
        if show and root._mms_astro then
          local sections = root._mms_astro.sections
          local ai = root._mms_astro.active_tab_index
          local sec = sections and ai and sections[ai]
          local sid = sec and sec.id
          if type(sid) == "string" and sid:sub(1, 8) == "mms_enc_" then
            local lx, ly = window_local_mouse(root._mms_astro)
            if lx and ly then
              AstroPanels.encounters_wheel(root, lx, ly, sid)
            end
          end
        end
      end, { root = root })
    end)
  end)
end

----------------------------------------------------------------------
-- Public install entry
----------------------------------------------------------------------
function M.install(root)
  --- Astro first so the native menu callback can always bind "UI toggle"
  --- when the window library loaded successfully.
  install_astro_window(root)
  install_native_menu(root)
  register_render(root)
  register_update(root)
end

--- Compatibility shim for main.lua (old layout had two separate
--- install_* entries and a `tick`). Now everything is wired by `M.install`.
function M.install_native_menu(root) install_native_menu(root) end
function M.install_overlay(root)     install_astro_window(root); register_render(root); register_update(root) end
function M.tick(_) end -- no-op; render callback drives the window itself

return M
