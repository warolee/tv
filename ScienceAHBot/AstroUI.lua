--[[ ScienceAHBot in-game UI via astro_custom_ui (core.menu.window + tabs). ]]

-- module-local, returned as the public interface
local M = {}

local Persistence = require("Persistence")
local Util = require("Util")
local AstroMenu = require("AstroMenu")
local AstroPanels = require("AstroPanels")
local UIInGame = require("UI_InGame")

local LearnMod = nil
pcall(function()
  LearnMod = require("Learn")
end)

local ScanLogMod = (function()
  local ok, mod = pcall(require, "ScanLog")
  return ok and mod or nil
end)()

local RotationUI = nil
do
  local paths = {
    "astro_custom_ui/rotation_settings_ui",
  }
  for _, p in ipairs(paths) do
    local ok, mod = pcall(require, p)
    if ok and mod and mod.new then
      RotationUI = mod
      break
    end
  end
end

local function cfg_ui_xywh(root)
  local u = (root.Config and root.Config.behavior and root.Config.behavior.ui) or {}
  return u.x or 80, u.y or 90, u.w or 540, u.h or 700
end

local function toggle_key_edge(root)
  local ui = (root.Config and root.Config.behavior and root.Config.behavior.ui) or {}
  local vk = ui.toggleKey or 0xC0
  local down = false
  pcall(function()
    down = core.input.is_key_pressed(vk)
  end)
  local prev = root._astro_toggle_prev
  root._astro_toggle_prev = down
  return down and not prev
end

local function window_local_mouse(rsu)
  if not rsu or not rsu.window then
    return nil, nil
  end
  local okm, mp = pcall(function()
    return rsu.window:get_mouse_pos()
  end)
  local okp, wp = pcall(function()
    return rsu.window:get_position()
  end)
  if not okm or not okp or not mp or not wp then
    return nil, nil
  end
  return mp.x - wp.x, mp.y - wp.y
end

function M.install(root)
  if root._science_astro_ui_installed then
    return
  end
  if not RotationUI then
    pcall(function()
      if core and core.log_warning then
        core.log_warning(
          "[ScienceAHBot] Could not load astro_custom_ui/rotation_settings_ui. Place astro_custom_ui next to ScienceAHBot in the scripts path."
        )
      end
    end)
    return
  end
  local okmw = false
  pcall(function()
    okmw = core and core.menu and core.menu.window and true or false
  end)
  if not okmw then
    pcall(function()
      if core and core.log_warning then
        core.log_warning("[ScienceAHBot] core.menu.window not available; Astro UI not installed.")
      end
    end)
    return
  end

  root._science_astro_ui_installed = true
  root._science_ui_installed = true
  root._astro_menu_sig = nil
  root._uiScale = root._uiScale or 1
  root.dashScroll = root.dashScroll or 0
  root.itemsScroll = root.itemsScroll or 0

  local x, y, ww, hh = cfg_ui_xywh(root)
  local m = AstroMenu.create(root)
  root._astro_menu = m
  if m then
    AstroMenu.sync_config_to_menu(root, m)
    root._astro_menu_sig = nil
    AstroMenu.sync_menu_to_config(root, m)
  end

  local ui = RotationUI.new({
    id = "science_ah_bot_v1",
    title = "Science AH Bot",
    default_x = x,
    default_y = y,
    default_w = ww,
    default_h = hh,
    theme = "astro",
  })

  if not m then
    pcall(function()
      if core and core.log_warning then
        core.log_warning("[ScienceAHBot] core.menu sliders unavailable; window layout only.")
      end
    end)
  end

  if m then
    ui:add_tab({ id = "dash", label = "Dashboard" }, function(t)
      t:checkbox_grid({
        columns = 1,
        label = "Runtime",
        elements = {
          { element = m.arm, label = "Arm bot (runtime)" },
        },
      })
      t:custom_panel({
        render = function(rot, y0)
          return AstroPanels.render_dashboard_feed(rot, y0, root)
        end,
      })
    end)

    ui:add_tab({ id = "items", label = "Items" }, function(t)
      t:custom_panel({
        render = function(rot, y0)
          return AstroPanels.render_items_panel(rot, y0, root)
        end,
      })
    end)

    local function hint_tab(id, label, mod_el, help)
      ui:add_tab({ id = id, label = label }, function(t)
        t:checkbox_grid({
          columns = 1,
          elements = {
            { element = mod_el, label = "Enable " .. label },
          },
        })
        t:custom_panel({
          render = function(rot, y0)
            local w = rot.window
            if not w then
              return y0
            end
            local vec2 = require("common/geometry/vector_2")
            w:render_text(
              require("common/enums").window_enums.font_id.FONT_SMALL,
              vec2.new(15, y0 + 8),
              rot.colors.text_secondary,
              help
            )
            return y0 + 48
          end,
        })
      end)
    end

    hint_tab("buy", "Buy", m.mod_buy, "Item IDs and ratios: Items tab. Gold, pacing, fatigue: Setup tab.")
    hint_tab("sell", "Sell", m.mod_sell, "Uses main item list when sell watchlist is empty. Stack size in Setup.")
    hint_tab("snipe", "Snipe", m.mod_snipe, "Uses main item list when snipe watchlist is empty. Cap in Setup.")
    hint_tab("undercut", "Undercut", m.mod_undercut, "Prefers owned-auctions API. Undercut step: Setup tab.")

    ui:add_tab({ id = "setup", label = "Setup" }, function(t)
      t:slider_list({
        label = "Economy & ratios",
        elements = {
          { element = m.gold_k, label = "Min gold (×10k copper)" },
          { element = m.default_buy_pct, label = "Default buy ratio", suffix = "%" },
          { element = m.snipe_max_pct, label = "Snipe max vs DBMarket", suffix = "%" },
          { element = m.post_stack, label = "Sell post stack size" },
        },
      })
      t:slider_list({
        label = "Buy scan (Gaussian pacing)",
        elements = {
          { element = m.scan_mean_10, label = "Mean (×0.1 s)", suffix = "" },
          { element = m.scan_min_10, label = "Min delay (×0.1 s)" },
          { element = m.scan_max_10, label = "Max delay (×0.1 s)" },
        },
      })
      t:slider_list({
        label = "Fatigue (minutes)",
        elements = {
          { element = m.fatigue_work_min_m, label = "Work window min" },
          { element = m.fatigue_work_max_m, label = "Work window max" },
          { element = m.fatigue_rest_min_m, label = "Rest min" },
          { element = m.fatigue_rest_max_m, label = "Rest max" },
        },
      })
      t:slider_list({
        label = "Undercut & UI",
        elements = {
          { element = m.undercut_cu, label = "Undercut (copper)" },
          { element = m.ui_scale_pct, label = "UI scale", suffix = "%" },
        },
      })
      t:checkbox_grid({
        label = "Learn (saved patterns)",
        columns = 2,
        elements = {
          { element = m.learn_en, label = "Learn enabled" },
          { element = m.dbg_verbose, label = "Debug verbose" },
          { element = m.dbg_dry, label = "Debug dry-run" },
          { element = m.dbg_chat, label = "Log auction chat" },
        },
      })
      t:slider_list({
        label = "Learn params",
        elements = {
          { element = m.blend_pct, label = "Blend", suffix = "%" },
          { element = m.min_samples, label = "Min samples" },
          { element = m.slack_1000, label = "Slack (×0.001)" },
          { element = m.ewma_pct, label = "EWMA alpha", suffix = "%" },
        },
      })
      t:checkbox_grid({
        label = "Guards",
        columns = 2,
        elements = {
          { element = m.ah_req, label = "Require open AH UI for search" },
          { element = m.scanlog_en, label = "Scan log CSV" },
        },
      })
      t:slider_list({
        label = "Search backoff",
        elements = {
          { element = m.search_streak, label = "Max fail streak" },
          { element = m.backoff_s, label = "Backoff (s)" },
        },
      })
      t:custom_panel({
        render = function(rot, y0)
          local vec2 = require("common/geometry/vector_2")
          local enums = require("common/enums")
          local w = rot.window
          if not w then
            return y0
          end
          local a = vec2.new(15, y0 + 6)
          local b = vec2.new(220, y0 + 34)
          w:render_rect_filled(a, b, rot.colors.primary_accent, 3)
          w:render_rect(a, b, rot.colors.border, 2, 1)
          w:render_text(
            enums.window_enums.font_id.FONT_SMALL,
            vec2.new(28, y0 + 12),
            require("common/color").white(255),
            "Reset learned patterns"
          )
          if w:is_rect_clicked(a, b) then
            Util.safe_call("Learn.clear_patterns", function()
              if LearnMod and LearnMod.clear_patterns then
                LearnMod.clear_patterns(root)
              end
            end, { root = root })
          end
          return y0 + 52
        end,
      })
    end)
  else
    ui:add_tab({ id = "notice", label = "Notice" }, function(t)
      t:custom_panel({
        render = function(rot, y0)
          local w = rot.window
          if not w then
            return y0
          end
          local vec2 = require("common/geometry/vector_2")
          local enums = require("common/enums")
          w:render_text(
            enums.window_enums.font_id.FONT_SMALL,
            vec2.new(15, y0 + 8),
            rot.colors.secondary_accent,
            "core.menu checkboxes/sliders are not available. Sylvanas menu API may be missing or outdated."
          )
          return y0 + 64
        end,
      })
    end)
  end

  root._astro_ui = ui

  pcall(function()
    if ui.menu and ui.menu.enable and root.Config and root.Config.behavior and root.Config.behavior.ui then
      local op = root.Config.behavior.ui.defaultOpen
      if op ~= false and ui.menu.enable.set_state then
        ui.menu.enable:set_state(true)
      elseif ui.menu.enable.set_state then
        ui.menu.enable:set_state(false)
      end
    end
  end)

  pcall(function()
    core.register_on_render_callback(function()
      Util.safe_call("AstroUI.on_render", function()
        if not root._astro_ui then
          return
        end
        root._astro_ui:on_render()
      end, { root = root })
    end)
  end)

  pcall(function()
    core.register_on_update_callback(function()
      Util.safe_call("AstroUI.on_update", function()
        local cfg = root.Config
        if type(cfg) == "table" then
          cfg._behavior_ensured = nil
        end

        if toggle_key_edge(root) and root._astro_ui and root._astro_ui.menu and root._astro_ui.menu.enable then
          local en = root._astro_ui.menu.enable
          pcall(function()
            if en.get_state then
              en:set_state(not en:get_state())
            elseif en.set then
              en:set(not en:get())
            end
          end)
        end

        local show = false
        pcall(function()
          if root._astro_ui and root._astro_ui.menu and root._astro_ui.menu.enable then
            show = root._astro_ui.menu.enable:get_state() == true
          end
        end)

        if show and m then
          AstroMenu.sync_menu_to_config(root, m)
        end

        if show and root._astro_ui then
          if not root._astro_was_shown and m then
            AstroMenu.sync_config_to_menu(root, m)
          end
          root._astro_was_shown = true
        else
          root._astro_was_shown = false
        end

        if show and root._astro_ui then
          local lx, ly = window_local_mouse(root._astro_ui)
          if lx and ly then
            local tab = root._astro_ui.active_tab_index or 1
            if tab == 1 then
              AstroPanels.dashboard_wheel(root, lx, ly)
            elseif tab == 2 then
              UIInGame.consume_digit_input(root)
              AstroPanels.items_wheel(root, lx, ly)
            end
          end
        else
          root.uiFocus = nil
        end

        if not show then
          Persistence.try_flush(root)
          if ScanLogMod and ScanLogMod.flush_now then
            Util.safe_call("ScanLog.flush_now", function()
              ScanLogMod.flush_now(root)
            end, { root = root })
          end
        end
      end, { root = root })
    end)
  end)
end

return M
