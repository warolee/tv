--[[ ScienceAHBot — in-game overlay (core.graphics + cursor hit-tests). Not core.menu. ]]

local AH_Bot = {}

local VK_LMB = 0x01
local TITLE_H = 30
local TAB_TOP = 34
local TAB_H = 28
local BODY_TOP = 68

local TAB = { HOME = 1, BUY = 2, SELL = 3, SNIPE = 4, UNDERCUT = 5, BEHAVIOR = 6 }
local TAB_LABELS = { "Home", "Buy", "Sell", "Snipe", "Undercut", "Behavior" }

local color
local izi

local function load_deps()
  pcall(function()
    color = require("common/color")
  end)
  pcall(function()
    izi = require("common/izi_sdk")
  end)
end

local function V(x, y)
  if izi and izi.vec2 then
    return izi.vec2(x, y)
  end
  return { x = x, y = y }
end

local function C(r, g, b, a)
  if color and color.new then
    return color.new(r, g, b, a or 255)
  end
  if color and color.white then
    return color.white(255)
  end
  return nil
end

local function inside(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

local function cursor()
  local ok, p = pcall(core.get_cursor_position)
  if ok and p and type(p.x) == "number" then
    return p.x, p.y
  end
  return 0, 0
end

local function input_lmb()
  local ok, d = pcall(function()
    return core.input.is_key_pressed(VK_LMB)
  end)
  return ok and d
end

local function toggle_key_held(root)
  local ui = (root.Config and root.Config.behavior and root.Config.behavior.ui) or {}
  local vk = ui.toggleKey or 0xC0
  local ok, d = pcall(function()
    return core.input.is_key_pressed(vk)
  end)
  return ok and d
end

local function ensure_behavior(cfg)
  cfg.behavior = cfg.behavior or {}
  cfg.behavior.modules = cfg.behavior.modules or {}
  cfg.behavior.ui = cfg.behavior.ui or {}
  cfg.behavior.snipe = cfg.behavior.snipe or {}
  cfg.behavior.sell = cfg.behavior.sell or {}
  cfg.behavior.undercut = cfg.behavior.undercut or {}
  cfg.behavior.reserves = cfg.behavior.reserves or {}
end

local function init_frame(root)
  local cfg = root.Config
  ensure_behavior(cfg)
  local ui = cfg.behavior.ui
  if root.uiX == nil then
    root.uiX = ui.x or 48
  end
  if root.uiY == nil then
    root.uiY = ui.y or 72
  end
  root.uiW = ui.w or 460
  root.uiH = ui.h or 560
  if root.uiOpen == nil then
    root.uiOpen = ui.defaultOpen ~= false
  end
  root.uiTab = root.uiTab or TAB.HOME
end

local function body_layout(root)
  local x, y, w = root.uiX, root.uiY, root.uiW
  local pad = 12
  local bx = x + pad
  local by = y + BODY_TOP + 8
  local bw = w - pad * 2
  return bx, by, bw
end

local function draw_toggle(x, y, w, h, label, on)
  local bg = on and C(40, 120, 60, 220) or C(55, 55, 65, 220)
  if not bg then
    return
  end
  pcall(function()
    core.graphics.rect_2d_filled(V(x, y), w, h, bg, 4)
    core.graphics.rect_2d(V(x, y), w, h, C(120, 120, 140, 255), 1, 4)
    core.graphics.text_2d(label, V(x + 8, y + 6), 14, C(240, 240, 245, 255))
  end)
end

local function draw_button(x, y, w, h, label)
  pcall(function()
    core.graphics.rect_2d_filled(V(x, y), w, h, C(70, 90, 140, 230), 4)
    core.graphics.rect_2d(V(x, y), w, h, C(160, 170, 200, 255), 1, 4)
    core.graphics.text_2d(label, V(x + 10, y + 7), 15, C(255, 255, 255, 255))
  end)
end

local function on_ui_update(root)
  init_frame(root)
  local cfg = root.Config
  ensure_behavior(cfg)

  local lmb = input_lmb()
  local click = lmb and not root._uiLmbPrev
  local cx, cy = cursor()

  local tk = toggle_key_held(root)
  if tk and not root._uiTogglePrev then
    root.uiOpen = not root.uiOpen
  end
  root._uiTogglePrev = tk

  if not root.uiOpen then
    root._uiLmbPrev = lmb
    root._uiDragging = false
    return
  end

  local x, y, w, h = root.uiX, root.uiY, root.uiW, root.uiH
  local bx, by, bw = body_layout(root)

  if root._uiDragging and lmb then
    root.uiX = cx - (root._uiDragOffX or 0)
    root.uiY = cy - (root._uiDragOffY or 0)
  elseif not lmb then
    root._uiDragging = false
  end

  if click and inside(cx, cy, x + w - 30, y + 4, 26, 22) then
    root.uiOpen = false
  elseif click and inside(cx, cy, x, y, w, TITLE_H) and not inside(cx, cy, x + w - 34, y, 34, TITLE_H) then
    root._uiDragging = true
    root._uiDragOffX = cx - x
    root._uiDragOffY = cy - y
  end

  local tabY = y + TAB_TOP
  local tabW = (w - 16) / #TAB_LABELS
  if click then
    for i = 1, #TAB_LABELS do
      local tx = x + 8 + (i - 1) * tabW
      if inside(cx, cy, tx, tabY, tabW - 2, TAB_H) then
        root.uiTab = i
        break
      end
    end
  end

  if click and root.uiTab == TAB.HOME then
    if inside(cx, cy, bx, by + 74, bw, 36) then
      root.isActive = not root.isActive
      if root.isActive then
        root.state = root.STATE_SCANNING
        root.tickBuyAt = 0
        root.tickSellAt = 0
        root.tickSnipeAt = 0
        root.tickUndercutAt = 0
        root.uptimeAnchor = nil
        root.fatigueUntil = 0
      else
        root.state = root.STATE_IDLE
        root.uptimeAnchor = nil
        root.TimeEnabled = nil
      end
    end
  end

  local function hit_toggle(px, py, tx, ty, tw, th)
    return click and inside(px, py, tx, ty, tw, th)
  end

  local mods = cfg.behavior.modules
  if root.uiTab == TAB.BUY and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.buy = not mods.buy
  elseif root.uiTab == TAB.SELL and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.sell = not mods.sell
  elseif root.uiTab == TAB.SNIPE and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.snipe = not mods.snipe
  elseif root.uiTab == TAB.UNDERCUT and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.undercut = not mods.undercut
  elseif root.uiTab == TAB.BEHAVIOR then
    local yy = by
    if hit_toggle(cx, cy, bx, yy, bw, 28) then
      mods.buy = not mods.buy
    end
    yy = yy + 34
    if hit_toggle(cx, cy, bx, yy, bw, 28) then
      mods.sell = not mods.sell
    end
    yy = yy + 34
    if hit_toggle(cx, cy, bx, yy, bw, 28) then
      mods.snipe = not mods.snipe
    end
    yy = yy + 34
    if hit_toggle(cx, cy, bx, yy, bw, 28) then
      mods.undercut = not mods.undercut
    end
    yy = yy + 42
    local uc = cfg.behavior.undercut.undercutCopper or 1
    if click and inside(cx, cy, bx, yy + 22, 40, 26) then
      cfg.behavior.undercut.undercutCopper = math.max(1, uc - 1)
    end
    if click and inside(cx, cy, bx + 48, yy + 22, 40, 26) then
      cfg.behavior.undercut.undercutCopper = math.min(999999, uc + 1)
    end
  end

  root._uiLmbPrev = lmb
end

local function on_ui_render(root)
  if not root.uiOpen then
    return
  end
  if not color then
    return
  end
  init_frame(root)
  local x, y, w, h = root.uiX, root.uiY, root.uiW, root.uiH
  local bx, by, bw = body_layout(root)

  pcall(function()
    core.graphics.rect_2d_filled(V(x, y), w, h, C(18, 18, 24, 235), 6)
    core.graphics.rect_2d(V(x, y), w, h, C(90, 95, 120, 255), 2, 6)
    core.graphics.text_2d("Science AH Bot", V(x + 12, y + 6), 18, C(220, 225, 255, 255))
    core.graphics.text_2d("[X]", V(x + w - 36, y + 6), 16, C(255, 180, 180, 255))

    local tabY = y + TAB_TOP
    local tabW = (w - 16) / #TAB_LABELS
    for i = 1, #TAB_LABELS do
      local tx = x + 8 + (i - 1) * tabW
      local sel = root.uiTab == i
      core.graphics.rect_2d_filled(V(tx, tabY), tabW - 2, TAB_H, sel and C(55, 75, 120, 240) or C(35, 36, 44, 220), 3)
      core.graphics.text_2d(TAB_LABELS[i], V(tx + 6, tabY + 6), 13, C(230, 232, 240, 255))
    end

    local mods = root.Config.behavior.modules

    if root.uiTab == TAB.HOME then
      local armed = root.isActive and "ARMED" or "DISARMED"
      core.graphics.text_2d("Status: " .. armed, V(bx, by), 15, C(200, 220, 255, 255))
      core.graphics.text_2d("State: " .. tostring(root.state), V(bx, by + 22), 14, C(190, 195, 210, 255))
      core.graphics.text_2d("Toggle panel: key in Config.behavior.ui.toggleKey (default 0xC0)", V(bx, by + 44), 12, C(160, 165, 185, 255))
      draw_button(bx, by + 74, bw, 36, root.isActive and "Disarm bot" or "Arm bot")
    elseif root.uiTab == TAB.BUY then
      draw_toggle(bx, by, bw, 30, "Enable buy scanner", mods.buy)
      core.graphics.text_2d("Watchlist + TSM DBMarket * buy ratio.", V(bx, by + 40), 13, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.SELL then
      draw_toggle(bx, by, bw, 30, "Enable sell / lister", mods.sell)
      core.graphics.text_2d("Lists via IZI AH (see AHBridge for method fallbacks).", V(bx, by + 40), 13, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.SNIPE then
      draw_toggle(bx, by, bw, 30, "Enable snipe", mods.snipe)
      core.graphics.text_2d("Tighter maxBuyRatio + faster scans in Config.", V(bx, by + 40), 13, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.UNDERCUT then
      draw_toggle(bx, by, bw, 30, "Enable undercut / relist", mods.undercut)
      core.graphics.text_2d("Prefers owned-auctions API; optional aggressive scan repost.", V(bx, by + 40), 12, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.BEHAVIOR then
      local yy = by
      draw_toggle(bx, yy, bw, 28, "Module: Buy", mods.buy)
      yy = yy + 34
      draw_toggle(bx, yy, bw, 28, "Module: Sell", mods.sell)
      yy = yy + 34
      draw_toggle(bx, yy, bw, 28, "Module: Snipe", mods.snipe)
      yy = yy + 34
      draw_toggle(bx, yy, bw, 28, "Module: Undercut", mods.undercut)
      yy = yy + 42
      local uc = root.Config.behavior.undercut.undercutCopper or 1
      core.graphics.text_2d("Undercut (copper): " .. tostring(uc), V(bx, yy), 14, C(210, 215, 230, 255))
      draw_button(bx, yy + 22, 40, 26, "-")
      draw_button(bx + 48, yy + 22, 40, 26, "+")
    end
  end)
end

function AH_Bot.install(root)
  if root._science_ui_installed then
    return
  end
  root._science_ui_installed = true
  root._uiLmbPrev = false
  root._uiTogglePrev = false
  load_deps()

  pcall(function()
    core.register_on_update_callback(function()
      pcall(function()
        on_ui_update(root)
      end)
    end)
  end)

  pcall(function()
    core.register_on_render_callback(function()
      pcall(function()
        on_ui_render(root)
      end)
    end)
  end)
end

return AH_Bot
