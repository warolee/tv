--[[ MythicMechanicsSuite — UI integration.

     Two surfaces:

       1. Project Sylvanas native menu (core.menu + the
          `register_on_render_menu_callback` hook). A tree node
          "Mythic Mechanics Suite" with a master enable checkbox,
          instance-only toggle, sound toggle and a "show overlay"
          checkbox.

       2. An in-game overlay panel (drawn each frame through
          `core.graphics.*`) with tabs for Settings, Encounters
          (toggle per encounter / per mechanic), and Active Warnings
          (live HUD).

     The overlay is intentionally simple (mouse hit-tests + key input,
     no slider widgets) so it stays compact and easy to audit. ]]

local M = {}

local Util       = require("Util")
local Geom       = require("Geometry")
local Draw       = require("Draw")
local Encounters = require("Encounters")
local Mechanics  = require("Mechanics")
local Persistence = require("Persistence")

local TABS = { "Settings", "Encounters", "Active" }

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function inside(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

local function cursor_pos()
  local x, y = 0, 0
  pcall(function()
    if core and core.game_ui and core.game_ui.get_wow_cursor_position then
      local v = core.game_ui.get_wow_cursor_position()
      if v then x, y = v.x or 0, v.y or 0 end
    end
  end)
  return x, y
end

local function is_lmb_pressed()
  local ok, v = pcall(function()
    if core and core.input and core.input.is_mouse_button_pressed then
      return core.input.is_mouse_button_pressed(1) -- 1 = LMB
    end
    return false
  end)
  return ok and v or false
end

local function key_down(vk)
  local ok, v = pcall(function()
    if core and core.input and core.input.is_key_pressed then
      return core.input.is_key_pressed(vk)
    end
    return false
  end)
  return ok and v or false
end

local function key_edge(root, vk)
  local prev = root._mms_key_prev or {}
  root._mms_key_prev = prev
  local k = tostring(vk)
  local d = key_down(vk)
  local e = d and not prev[k]
  prev[k] = d and true or false
  return e
end

local function mouse_edge(root)
  local d = is_lmb_pressed()
  local prev = root._mms_lmb_prev
  root._mms_lmb_prev = d
  return d and not prev
end

----------------------------------------------------------------------
-- Sylvanas native menu (tree + checkboxes)
----------------------------------------------------------------------
function M.install_native_menu(root)
  if root._mms_native_menu_installed then return end
  if not (core and core.menu and core.menu.tree_node and core.menu.checkbox and core.register_on_render_menu_callback) then
    return
  end
  root._mms_native_menu_installed = true

  pcall(function()
    root._mms_tree = core.menu.tree_node()
    root._mms_cb_enable        = core.menu.checkbox(root.Config.enabled ~= false, "mms_enable_v1")
    root._mms_cb_instance_only = core.menu.checkbox(root.Config.instanceOnly ~= false, "mms_instance_only_v1")
    root._mms_cb_sound         = core.menu.checkbox((root.Config.sound and root.Config.sound.enabled) ~= false, "mms_sound_v1")
    root._mms_cb_show_overlay  = core.menu.checkbox(root.Config.ui.defaultOpen ~= false, "mms_show_overlay_v1")
    root._mms_cb_debug_hud     = core.menu.checkbox(root.Config.debug.showHUD == true, "mms_debug_hud_v1")
  end)

  pcall(function()
    core.register_on_render_menu_callback(function()
      Util.try("UI.native_menu.render", function()
        if not (root._mms_tree and root._mms_cb_enable) then return end
        root._mms_tree:render("Mythic Mechanics Suite", function()
          root._mms_cb_enable:render("Master enable (drawings on/off)")
          root._mms_cb_instance_only:render("Only draw inside instances")
          root._mms_cb_sound:render("Play alert sounds")
          root._mms_cb_show_overlay:render("Show settings overlay")
          root._mms_cb_debug_hud:render("Debug HUD (top-left)")
        end)

        --- Mirror checkbox state → root.Config (debounce-save).
        local function read(cb, fallback)
          local ok, v = pcall(function() return cb:get_state() == true end)
          return ok and v or fallback
        end
        local prev_enabled = root.Config.enabled
        root.Config.enabled = read(root._mms_cb_enable, root.Config.enabled)
        root.Config.instanceOnly = read(root._mms_cb_instance_only, root.Config.instanceOnly)
        root.Config.sound = root.Config.sound or {}
        root.Config.sound.enabled = read(root._mms_cb_sound, root.Config.sound.enabled)
        root.Config.ui.defaultOpen = read(root._mms_cb_show_overlay, root.Config.ui.defaultOpen)
        root.Config.debug.showHUD = read(root._mms_cb_debug_hud, root.Config.debug.showHUD)
        if prev_enabled ~= root.Config.enabled then
          Persistence.mark_dirty(root)
        end
      end, { root = root })
    end)
  end)
end

----------------------------------------------------------------------
-- Custom overlay panel
----------------------------------------------------------------------
local function ensure_overlay_state(root)
  root._mms_overlay = root._mms_overlay or {
    visible = root.Config.ui.defaultOpen ~= false,
    tab = 1,
    enc_filter = "all", -- "all" | "raid" | "mplus"
    scroll = 0,
    drag = nil,
  }
end

local function header_button(root, x, y, w, h, label, active)
  local cfg = root.Config
  local bg = active and { r = 60, g = 100, b = 160, a = 235 } or { r = 30, g = 36, b = 50, a = 235 }
  Draw.rect_2d_filled(Geom.V2(x, y), w, h, bg, 4)
  Draw.rect_2d(Geom.V2(x, y), w, h, { r = 90, g = 100, b = 130, a = 200 }, 1, 4)
  Draw.text_2d(label, Geom.V2(x + 8, y + 5), 14, cfg.colors and cfg.colors.text or { r = 240, g = 240, b = 240, a = 255 })
  local mx, my = cursor_pos()
  if inside(mx, my, x, y, w, h) and mouse_edge(root) then
    return true
  end
  return false
end

local function render_settings_tab(root, x, y, w, h)
  local cfg = root.Config
  local text_col = cfg.colors and cfg.colors.text or { r = 230, g = 230, b = 230, a = 255 }
  local mx, my = cursor_pos()
  local row_h = 26
  local rows = {
    { key = "enabled",      label = "Master enable",  get = function() return cfg.enabled end,
      set = function(v) cfg.enabled = v end },
    { key = "instanceOnly", label = "Only inside instances", get = function() return cfg.instanceOnly end,
      set = function(v) cfg.instanceOnly = v end },
    { key = "sound",        label = "Sound alerts",
      get = function() return cfg.sound and cfg.sound.enabled end,
      set = function(v) cfg.sound = cfg.sound or {}; cfg.sound.enabled = v end },
    { key = "fillCircles",  label = "Fill danger circles",
      get = function() return cfg.draw and cfg.draw.fillCircles end,
      set = function(v) cfg.draw = cfg.draw or {}; cfg.draw.fillCircles = v end },
    { key = "showHUD",      label = "Debug HUD",
      get = function() return cfg.debug and cfg.debug.showHUD end,
      set = function(v) cfg.debug = cfg.debug or {}; cfg.debug.showHUD = v end },
    { key = "logEvents",    label = "Log every trigger to chat",
      get = function() return cfg.debug and cfg.debug.logEvents end,
      set = function(v) cfg.debug = cfg.debug or {}; cfg.debug.logEvents = v end },
  }

  for i, row in ipairs(rows) do
    local ry = y + (i - 1) * (row_h + 4)
    local cx = x + 8
    local box_w = 18
    local on = row.get() and true or false
    Draw.rect_2d_filled(Geom.V2(cx, ry + 4), box_w, box_w,
      on and { r = 90, g = 200, b = 120, a = 235 } or { r = 60, g = 60, b = 70, a = 235 }, 3)
    Draw.rect_2d(Geom.V2(cx, ry + 4), box_w, box_w, { r = 120, g = 130, b = 150, a = 220 }, 1, 3)
    if on then
      Draw.text_2d("X", Geom.V2(cx + 4, ry + 2), 16, { r = 20, g = 30, b = 20, a = 255 })
    end
    Draw.text_2d(row.label, Geom.V2(cx + box_w + 10, ry + 4), 14, text_col)
    if inside(mx, my, cx, ry, w - 16, row_h) and mouse_edge(root) then
      row.set(not on)
      Persistence.mark_dirty(root)
    end
  end

  local footer_y = y + #rows * (row_h + 4) + 12
  Draw.text_2d("Tip: F9 toggles this overlay. Encounters tab lets you turn off individual mechanics.",
    Geom.V2(x + 8, footer_y), 12, { r = 180, g = 190, b = 210, a = 255 })
end

local function filter_encounters(filter)
  local list = Encounters.all_encounters()
  if filter == "all" then return list end
  local out = {}
  for _, e in ipairs(list) do
    if e.kind == filter then out[#out + 1] = e end
  end
  return out
end

local function render_encounters_tab(root, x, y, w, h)
  local cfg = root.Config
  local text_col = cfg.colors and cfg.colors.text or { r = 230, g = 230, b = 230, a = 255 }
  local mx, my = cursor_pos()

  --- Filter buttons
  local fx = x + 8
  local fy = y
  for _, f in ipairs({ "all", "raid", "mplus" }) do
    local clicked = header_button(root, fx, fy, 64, 24, f, root._mms_overlay.enc_filter == f)
    if clicked then root._mms_overlay.enc_filter = f end
    fx = fx + 70
  end

  local list_y = y + 32
  local list_h = h - 40

  --- Scroll
  if inside(mx, my, x, list_y, w, list_h) then
    local ok, dy = pcall(function()
      if core and core.input and core.input.mouse_wheel_delta then return core.input.mouse_wheel_delta() end
      return 0
    end)
    if ok and type(dy) == "number" and dy ~= 0 then
      root._mms_overlay.scroll = math.max(0, (root._mms_overlay.scroll or 0) - dy * 24)
    end
  end

  Draw.rect_2d_filled(Geom.V2(x + 4, list_y), w - 8, list_h, { r = 14, g = 18, b = 28, a = 220 }, 4)
  Draw.rect_2d(Geom.V2(x + 4, list_y), w - 8, list_h, { r = 60, g = 70, b = 90, a = 220 }, 1, 4)

  pcall(function() if core.graphics.scissor_push then core.graphics.scissor_push(x + 4, list_y, w - 8, list_h) end end)

  local row_y = list_y - (root._mms_overlay.scroll or 0) + 6
  local encs = filter_encounters(root._mms_overlay.enc_filter)
  for _, enc in ipairs(encs) do
    if row_y > list_y - 30 and row_y < list_y + list_h + 30 then
      --- Encounter header row (whole-encounter toggle)
      local enc_key = tostring(enc.id)
      local enc_on = cfg.toggles[enc_key] ~= false
      local cx = x + 14
      Draw.rect_2d_filled(Geom.V2(cx, row_y + 2), 16, 16,
        enc_on and { r = 90, g = 200, b = 120, a = 235 } or { r = 90, g = 60, b = 60, a = 235 }, 3)
      Draw.text_2d(string.format("%s  [%s]", tostring(enc.name or enc.id), tostring(enc.kind or "?")),
        Geom.V2(cx + 22, row_y + 2), 14, text_col)
      if inside(mx, my, cx, row_y, 18, 18) and mouse_edge(root) then
        cfg.toggles[enc_key] = not enc_on and true or false
        Persistence.mark_dirty(root)
      end
    end
    row_y = row_y + 22

    for _, mech in ipairs(enc.mechanics or {}) do
      if row_y > list_y - 30 and row_y < list_y + list_h + 30 then
        local key = Encounters.toggle_key(enc, mech)
        local on = cfg.toggles[key] ~= false
        local cx = x + 38
        Draw.rect_2d_filled(Geom.V2(cx, row_y + 2), 14, 14,
          on and { r = 80, g = 170, b = 100, a = 235 } or { r = 60, g = 60, b = 70, a = 235 }, 2)
        local label = string.format("%s (%s, %s, %s)",
          tostring(mech.name or mech.id), tostring(mech.type),
          tostring(mech.priority or "?"), tostring(mech.spellID or "-"))
        Draw.text_2d(label, Geom.V2(cx + 22, row_y + 2), 12, text_col)
        if inside(mx, my, cx, row_y, 18, 16) and mouse_edge(root) then
          cfg.toggles[key] = not on and true or false
          Persistence.mark_dirty(root)
          Mechanics.refresh_watch(root)
        end
      end
      row_y = row_y + 18
    end
    row_y = row_y + 6
  end

  pcall(function() if core.graphics.scissor_pop then core.graphics.scissor_pop() end end)
end

local function render_active_tab(root, x, y, w, h)
  local cfg = root.Config
  local text_col = cfg.colors and cfg.colors.text or { r = 230, g = 230, b = 230, a = 255 }
  local active = Mechanics.active(root)

  Draw.text_2d(string.format("Active warnings: %d", #active),
    Geom.V2(x + 8, y), 14, text_col)

  local now = Util.now_seconds()
  for i, e in ipairs(active) do
    local ry = y + 24 + (i - 1) * 18
    if ry > y + h then break end
    local remaining = math.max(0, (e.expires_at or now) - now)
    Draw.text_2d(string.format("%-22s  %-22s  %4.1fs",
      tostring(e.enc.name or e.enc.id):sub(1, 22),
      tostring(e.mech.name or e.mech.id):sub(1, 22),
      remaining), Geom.V2(x + 8, ry), 13, text_col)
  end

  if #active == 0 then
    Draw.text_2d("No active mechanics. Engage a boss to see warnings.",
      Geom.V2(x + 8, y + 30), 13, { r = 180, g = 190, b = 210, a = 255 })
  end

  --- Manual fire-test button (for verifying drawing pipeline).
  local mx, my = cursor_pos()
  local bx, by, bw, bh = x + 8, y + h - 36, 160, 26
  Draw.rect_2d_filled(Geom.V2(bx, by), bw, bh, { r = 70, g = 100, b = 160, a = 235 }, 4)
  Draw.text_2d("Test: draw at me", Geom.V2(bx + 8, by + 5), 13, text_col)
  if inside(mx, my, bx, by, bw, bh) and mouse_edge(root) then
    local lp = require("World").local_player()
    if lp then
      local fake_enc = { id = "test", name = "Self-test" }
      local fake_mech = {
        id = "test_circle", type = "circle", radius = 8,
        duration = 4, color = "danger", message = "Test ring",
      }
      local now = Util.now_seconds()
      table.insert(Mechanics.active(root), {
        enc = fake_enc, mech = fake_mech, unit = lp,
        spawned_at = now, expires_at = now + 4,
        color = cfg.colors.danger, radius = 8, length = 10, width = 4,
        kind = "test",
      })
    end
  end

  local cx, cy = bx + bw + 12, by
  Draw.rect_2d_filled(Geom.V2(cx, cy), 120, bh, { r = 130, g = 70, b = 70, a = 235 }, 4)
  Draw.text_2d("Clear all", Geom.V2(cx + 8, cy + 5), 13, text_col)
  if inside(mx, my, cx, cy, 120, bh) and mouse_edge(root) then
    Mechanics.clear(root)
  end
end

local function render_overlay(root)
  ensure_overlay_state(root)
  if not root._mms_overlay.visible then return end

  local cfg = root.Config
  local ui = cfg.ui or {}
  local x, y, w, h = ui.x or 48, ui.y or 48, ui.w or 520, ui.h or 720

  --- Background
  Draw.rect_2d_filled(Geom.V2(x, y), w, h, { r = 18, g = 22, b = 32, a = 232 }, 6)
  Draw.rect_2d(Geom.V2(x, y), w, h, { r = 90, g = 100, b = 130, a = 235 }, 1, 6)

  --- Title bar (draggable)
  local title_h = 28
  Draw.rect_2d_filled(Geom.V2(x, y), w, title_h, { r = 30, g = 38, b = 60, a = 245 }, 6)
  Draw.text_2d("Mythic Mechanics Suite", Geom.V2(x + 10, y + 6), 14,
    cfg.colors and cfg.colors.text or { r = 240, g = 240, b = 240, a = 255 })

  local mx, my = cursor_pos()
  local lmb = is_lmb_pressed()
  if inside(mx, my, x, y, w - 28, title_h) and lmb and not root._mms_overlay.drag then
    root._mms_overlay.drag = { ox = mx - x, oy = my - y }
  end
  if not lmb then root._mms_overlay.drag = nil end
  if root._mms_overlay.drag and lmb then
    ui.x = mx - root._mms_overlay.drag.ox
    ui.y = my - root._mms_overlay.drag.oy
    Persistence.mark_dirty(root)
  end

  --- Sylvanas spellbook trick: disable mouselook whenever cursor is over panel.
  if inside(mx, my, x, y, w, h) then
    pcall(function() if MouselookStop then MouselookStop() end end)
  end

  --- Close X
  local closeW = 22
  Draw.rect_2d_filled(Geom.V2(x + w - closeW - 4, y + 4), closeW, 20, { r = 130, g = 60, b = 60, a = 235 }, 3)
  Draw.text_2d("X", Geom.V2(x + w - closeW + 4, y + 4), 14, { r = 240, g = 240, b = 240, a = 255 })
  if inside(mx, my, x + w - closeW - 4, y + 4, closeW, 20) and mouse_edge(root) then
    root._mms_overlay.visible = false
    if root._mms_cb_show_overlay and root._mms_cb_show_overlay.set then
      pcall(function() root._mms_cb_show_overlay:set(false) end)
    end
    cfg.ui.defaultOpen = false
    Persistence.mark_dirty(root)
  end

  --- Tab bar
  local tab_y = y + title_h + 4
  local tab_w = math.floor((w - 16) / #TABS)
  for i, t in ipairs(TABS) do
    local tx = x + 8 + (i - 1) * tab_w
    local clicked = header_button(root, tx, tab_y, tab_w - 4, 24, t, root._mms_overlay.tab == i)
    if clicked then root._mms_overlay.tab = i end
  end

  --- Tab content area
  local cx, cy = x + 8, tab_y + 32
  local cw, ch = w - 16, h - (cy - y) - 12
  if root._mms_overlay.tab == 1 then render_settings_tab(root, cx, cy, cw, ch)
  elseif root._mms_overlay.tab == 2 then render_encounters_tab(root, cx, cy, cw, ch)
  else render_active_tab(root, cx, cy, cw, ch) end
end

function M.install_overlay(root)
  ensure_overlay_state(root)
  root._mms_overlay_render = function()
    Util.try("UI.overlay", function()
      --- Toggle visibility on key edge.
      local toggle = (root.Config.ui and root.Config.ui.toggleKey) or 0x78
      if key_edge(root, toggle) then
        root._mms_overlay.visible = not root._mms_overlay.visible
        root.Config.ui.defaultOpen = root._mms_overlay.visible
        Persistence.mark_dirty(root)
      end
      render_overlay(root)
    end, { root = root })
  end
end

function M.tick(root)
  if root._mms_overlay_render then root._mms_overlay_render() end
end

return M
