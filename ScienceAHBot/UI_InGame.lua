--[[ ScienceAHBot — in-game edits to root.Config; changes debounce-save via Persistence.lua. ]]

local M = {}

local Persistence = require("ScienceAHBot/Persistence")

M.STARTER_ITEMS = {
  [190456] = { ratio = 0.70, name = "Draconic Vial" },
  [192101] = { ratio = 0.80, name = "Tenebrous Ribs" },
  [210805] = { ratio = 0.75, name = "Mycobloom" },
  [210806] = { ratio = 0.75, name = "Luredrop" },
  [210807] = { ratio = 0.75, name = "Orbinid" },
  [210808] = { ratio = 0.75, name = "Blessing Blossom" },
  [210809] = { ratio = 0.75, name = "Arathor's Spear" },
  [210810] = { ratio = 0.75, name = "Roaring Dragonwort" },
  [210930] = { ratio = 0.75, name = "Bismuth" },
  [210931] = { ratio = 0.75, name = "Ironclaw Ore" },
  [210932] = { ratio = 0.75, name = "Aqirite" },
  [210933] = { ratio = 0.75, name = "Null Stone" },
}

local VK_BACK = 0x08
local VK_D0 = 0x30
local VK_D9 = 0x39

local ITEM_ROW_H = 50
local LIST_TOP_OFFSET = 118

local function inside(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

local function key_down(vk)
  local ok, d = pcall(function()
    return core.input.is_key_pressed(vk)
  end)
  return ok and d
end

local function key_edge(root, vk)
  local t = root._uiKeyPrev or {}
  root._uiKeyPrev = t
  local k = tostring(vk)
  local d = key_down(vk)
  local e = d and not t[k]
  t[k] = d and true or false
  return e
end

local function clamp(x, lo, hi)
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

local function fmt_gold(copper)
  if type(copper) ~= "number" then
    return "—"
  end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  return string.format("%dg %ds %dc", g, s, c)
end

local function fmt_min(sec)
  if type(sec) ~= "number" then
    return "—"
  end
  return string.format("%.0f min", sec / 60)
end

function M.sorted_item_ids(cfg)
  cfg.Items = cfg.Items or {}
  local ids = {}
  for id in pairs(cfg.Items) do
    if type(id) == "number" then
      ids[#ids + 1] = id
    end
  end
  table.sort(ids)
  return ids
end

function M.merge_starter_items(cfg)
  cfg.Items = cfg.Items or {}
  for id, row in pairs(M.STARTER_ITEMS) do
    if not cfg.Items[id] then
      cfg.Items[id] = { ratio = row.ratio, name = row.name }
    end
  end
end

function M.clear_all_items(cfg)
  cfg.Items = {}
end

function M.consume_digit_input(root)
  if root.uiFocus ~= "addId" then
    return
  end
  local buf = root._uiAddItemBuf or ""
  if key_edge(root, VK_BACK) and #buf > 0 then
    buf = buf:sub(1, #buf - 1)
  end
  for vk = VK_D0, VK_D9 do
    if key_edge(root, vk) and #buf < 10 then
      buf = buf .. string.char(vk)
    end
  end
  root._uiAddItemBuf = buf
end

local function ensure_fatigue_pair(cfg)
  local wa = cfg.fatigueWorkSecondsMin or 45 * 60
  local wb = cfg.fatigueWorkSecondsMax or 60 * 60
  if wa > wb then
    cfg.fatigueWorkSecondsMin, cfg.fatigueWorkSecondsMax = wb, wa
  end
  local ra = cfg.fatigueRestSecondsMin or 8 * 60
  local rb = cfg.fatigueRestSecondsMax or 12 * 60
  if ra > rb then
    cfg.fatigueRestSecondsMin, cfg.fatigueRestSecondsMax = rb, ra
  end
end

function M.update_items_tab(root, bx, by, bw, bottomY, click, cx, cy)
  local cfg = root.Config
  cfg.Items = cfg.Items or {}
  root._uiAddItemBuf = root._uiAddItemBuf or ""
  root._uiNewItemRatio = root._uiNewItemRatio or (cfg.thresholds and cfg.thresholds.defaultBuyRatio) or 0.75

  local listTop = by + LIST_TOP_OFFSET
  local listH = math.max(80, bottomY - listTop - 8)
  local ids = M.sorted_item_ids(cfg)

  if click and inside(cx, cy, bx, by + 36, bw, 22) then
    root.uiFocus = "addId"
    root._uiKeyPrev = {}
  end

  if inside(cx, cy, bx, listTop, bw, listH) then
    local wd = 0
    pcall(function()
      wd = core.get_mouse_wheel_delta()
    end)
    if wd ~= 0 then
      local total = #ids * ITEM_ROW_H
      local maxScroll = math.max(0, total - listH)
      root.itemsScroll = math.max(0, math.min(maxScroll, (root.itemsScroll or 0) - wd * 20))
    end
  end

  if not click then
    return
  end

  if inside(cx, cy, bx, by + 62, 132, 28) then
    M.merge_starter_items(cfg)
  end
  if inside(cx, cy, bx + 140, by + 62, 88, 28) then
    M.clear_all_items(cfg)
  end

  if inside(cx, cy, bx + bw - 160, by + 62, 36, 28) then
    root._uiNewItemRatio = clamp((root._uiNewItemRatio or 0.75) - 0.05, 0.05, 0.99)
  end
  if inside(cx, cy, bx + bw - 118, by + 62, 36, 28) then
    root._uiNewItemRatio = clamp((root._uiNewItemRatio or 0.75) + 0.05, 0.05, 0.99)
  end

  if inside(cx, cy, bx + bw - 200, by + 94, 200, 30) then
    local id = tonumber(root._uiAddItemBuf)
    if id and id > 0 then
      cfg.Items[id] = cfg.Items[id] or { ratio = root._uiNewItemRatio, name = "Item " .. tostring(id) }
      cfg.Items[id].ratio = root._uiNewItemRatio
      root._uiAddItemBuf = ""
      root.uiFocus = nil
    end
  end

  local total = #ids * ITEM_ROW_H
  local maxScroll = math.max(0, total - listH)
  root.itemsScroll = math.min(root.itemsScroll or 0, maxScroll)
  local scroll = root.itemsScroll or 0

  for i = 1, #ids do
    local id = ids[i]
    local ry = listTop + (i - 1) * ITEM_ROW_H - scroll
    if ry + ITEM_ROW_H >= listTop and ry <= listTop + listH then
      if inside(cx, cy, bx + bw - 40, ry + 10, 32, 26) then
        cfg.Items[id] = nil
      end
      if inside(cx, cy, bx + 188, ry + 10, 36, 26) then
        local row = cfg.Items[id]
        if row then
          row.ratio = clamp((row.ratio or 0.75) - 0.05, 0.05, 0.99)
        end
      end
      if inside(cx, cy, bx + 230, ry + 10, 36, 26) then
        local row = cfg.Items[id]
        if row then
          row.ratio = clamp((row.ratio or 0.75) + 0.05, 0.05, 0.99)
        end
      end
    end
  end

  Persistence.mark_dirty(root)
end

function M.update_setup_tab(root, bx, by, bw, click, cx, cy)
  if not click then
    return
  end
  local cfg = root.Config
  local th = cfg.thresholds or {}
  cfg.thresholds = th
  local j = cfg.jitter or {}
  cfg.jitter = j
  local b = cfg.behavior or {}
  cfg.behavior = b
  b.reserves = b.reserves or {}
  b.snipe = b.snipe or {}
  b.sell = b.sell or {}
  b.undercut = b.undercut or {}
  b.modules = b.modules or {}
  b.learn = b.learn or {}

  local yy = by
  local function hit(xx, wy, ww, hh)
    return inside(cx, cy, bx + xx, wy, ww, hh)
  end

  if hit(0, yy, bw, 28) then
    b.modules.buy = not b.modules.buy
  end
  yy = yy + 32
  if hit(0, yy, bw, 28) then
    b.modules.sell = not b.modules.sell
  end
  yy = yy + 32
  if hit(0, yy, bw, 28) then
    b.modules.snipe = not b.modules.snipe
  end
  yy = yy + 32
  if hit(0, yy, bw, 28) then
    b.modules.undercut = not b.modules.undercut
  end
  yy = yy + 40

  if hit(0, yy + 18, 44, 26) then
    b.reserves.minGoldCopper = math.max(0, (b.reserves.minGoldCopper or 0) - 100000)
  end
  if hit(52, yy + 18, 44, 26) then
    b.reserves.minGoldCopper = math.min(999999999, (b.reserves.minGoldCopper or 0) + 100000)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    th.defaultBuyRatio = clamp((th.defaultBuyRatio or 0.75) - 0.05, 0.05, 0.99)
  end
  if hit(52, yy + 18, 44, 26) then
    th.defaultBuyRatio = clamp((th.defaultBuyRatio or 0.75) + 0.05, 0.05, 0.99)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    b.snipe.maxBuyRatio = clamp((b.snipe.maxBuyRatio or 0.52) - 0.03, 0.05, 0.99)
  end
  if hit(52, yy + 18, 44, 26) then
    b.snipe.maxBuyRatio = clamp((b.snipe.maxBuyRatio or 0.52) + 0.03, 0.05, 0.99)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    b.sell.postStackSize = math.max(1, (b.sell.postStackSize or 20) - 1)
  end
  if hit(52, yy + 18, 44, 26) then
    b.sell.postStackSize = math.min(200, (b.sell.postStackSize or 20) + 1)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    j.scanMeanSeconds = math.max(1.0, (j.scanMeanSeconds or 5) - 0.5)
  end
  if hit(52, yy + 18, 44, 26) then
    j.scanMeanSeconds = math.min(120, (j.scanMeanSeconds or 5) + 0.5)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    j.scanMinDelay = math.max(0.5, (j.scanMinDelay or 3.5) - 0.5)
  end
  if hit(52, yy + 18, 44, 26) then
    j.scanMinDelay = math.min(600, (j.scanMinDelay or 3.5) + 0.5)
  end
  if hit(104, yy + 18, 44, 26) then
    j.scanMaxDelay = math.max(1.0, (j.scanMaxDelay or 7) - 0.5)
  end
  if hit(156, yy + 18, 44, 26) then
    j.scanMaxDelay = math.min(600, (j.scanMaxDelay or 7) + 0.5)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    cfg.fatigueWorkSecondsMin = math.max(60, (cfg.fatigueWorkSecondsMin or 2700) - 300)
  end
  if hit(52, yy + 18, 44, 26) then
    cfg.fatigueWorkSecondsMin = math.min(cfg.fatigueWorkSecondsMax or 3600, (cfg.fatigueWorkSecondsMin or 2700) + 300)
  end
  if hit(104, yy + 18, 44, 26) then
    cfg.fatigueWorkSecondsMax = math.max(cfg.fatigueWorkSecondsMin or 2700, (cfg.fatigueWorkSecondsMax or 3600) - 300)
  end
  if hit(156, yy + 18, 44, 26) then
    cfg.fatigueWorkSecondsMax = math.min(7200, (cfg.fatigueWorkSecondsMax or 3600) + 300)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    cfg.fatigueRestSecondsMin = math.max(60, (cfg.fatigueRestSecondsMin or 480) - 60)
  end
  if hit(52, yy + 18, 44, 26) then
    cfg.fatigueRestSecondsMin = math.min(cfg.fatigueRestSecondsMax or 720, (cfg.fatigueRestSecondsMin or 480) + 60)
  end
  if hit(104, yy + 18, 44, 26) then
    cfg.fatigueRestSecondsMax = math.max(cfg.fatigueRestSecondsMin or 480, (cfg.fatigueRestSecondsMax or 720) - 60)
  end
  if hit(156, yy + 18, 44, 26) then
    cfg.fatigueRestSecondsMax = math.min(3600, (cfg.fatigueRestSecondsMax or 720) + 60)
  end
  yy = yy + 52

  if hit(0, yy + 18, 44, 26) then
    b.undercut.undercutCopper = math.max(1, (b.undercut.undercutCopper or 1) - 1)
  end
  if hit(52, yy + 18, 44, 26) then
    b.undercut.undercutCopper = math.min(999999, (b.undercut.undercutCopper or 1) + 1)
  end
  yy = yy + 52

  local L = b.learn
  if hit(0, yy, bw, 28) then
    local cur = L.enabled ~= false
    L.enabled = not cur
  end
  yy = yy + 34
  if hit(0, yy + 18, 44, 26) then
    L.blend = clamp((L.blend or 0.35) - 0.05, 0, 1)
  end
  if hit(52, yy + 18, 44, 26) then
    L.blend = clamp((L.blend or 0.35) + 0.05, 0, 1)
  end
  yy = yy + 52
  if hit(0, yy + 18, 44, 26) then
    L.minSamples = math.max(2, (L.minSamples or 5) - 1)
  end
  if hit(52, yy + 18, 44, 26) then
    L.minSamples = math.min(80, (L.minSamples or 5) + 1)
  end
  if hit(104, yy + 18, 44, 26) then
    L.slack = clamp((L.slack or 0.025) - 0.005, 0, 0.15)
  end
  if hit(156, yy + 18, 44, 26) then
    L.slack = clamp((L.slack or 0.025) + 0.005, 0, 0.15)
  end
  yy = yy + 52
  if hit(0, yy + 18, 44, 26) then
    L.ewmaAlpha = clamp((L.ewmaAlpha or 0.15) - 0.02, 0.04, 0.5)
  end
  if hit(52, yy + 18, 44, 26) then
    L.ewmaAlpha = clamp((L.ewmaAlpha or 0.15) + 0.02, 0.04, 0.5)
  end
  yy = yy + 52
  if hit(0, yy + 18, 160, 28) then
    local Learn = require("ScienceAHBot/Learn")
    Learn.clear_patterns(root)
  end

  if j.scanMinDelay > j.scanMaxDelay then
    j.scanMaxDelay = j.scanMinDelay
  end
  ensure_fatigue_pair(cfg)

  Persistence.mark_dirty(root)
end

function M.render_items_tab(root, bx, by, bw, bottomY, C, V, draw_button)
  local cfg = root.Config
  cfg.Items = cfg.Items or {}
  local buf = root._uiAddItemBuf or ""
  local ratio = root._uiNewItemRatio or 0.75
  local listTop = by + LIST_TOP_OFFSET
  local listH = math.max(80, bottomY - listTop - 8)
  local ids = M.sorted_item_ids(cfg)
  local scroll = root.itemsScroll or 0

  pcall(function()
    core.graphics.text_2d("Changes save to loader scripts_data/ScienceAHBot/user_settings.lua (~1s after edits).", V(bx, by), 12, C(160, 170, 195, 255))
    core.graphics.text_2d("Click bar, type digits 0-9, Backspace. Add sets ratio for new or existing ID.", V(bx, by + 16), 11, C(130, 140, 165, 255))

    local entry = (#buf > 0) and buf or "(click to type item ID)"
    local ecol = root.uiFocus == "addId" and C(255, 240, 200, 255) or C(200, 205, 220, 255)
    core.graphics.rect_2d_filled(V(bx, by + 34), bw, 24, C(28, 30, 40, 240), 3)
    core.graphics.text_2d(entry, V(bx + 6, by + 38), 14, ecol)

    draw_button(bx, by + 62, 132, 28, "Merge starter")
    draw_button(bx + 140, by + 62, 88, 28, "Clear all")
    core.graphics.text_2d(string.format("New ratio: %.2f", ratio), V(bx + 240, by + 68), 12, C(200, 210, 230, 255))
    draw_button(bx + bw - 160, by + 62, 36, 28, "-")
    draw_button(bx + bw - 118, by + 62, 36, 28, "+")
    draw_button(bx + bw - 200, by + 94, 200, 30, "Add / update item")

    core.graphics.rect_2d_filled(V(bx, listTop), bw, listH, C(14, 15, 22, 220), 4)
    core.graphics.rect_2d(V(bx, listTop), bw, listH, C(60, 65, 85, 200), 1, 4)
  end)

  pcall(function()
    core.graphics.scissor_push(bx, listTop, bw, listH)
  end)
  for i = 1, #ids do
    local id = ids[i]
    local row = cfg.Items[id]
    local ry = listTop + (i - 1) * ITEM_ROW_H - scroll + 6
    if ry + ITEM_ROW_H >= listTop and ry <= listTop + listH then
      pcall(function()
        local nm = (row and row.name) or "?"
        local r = (row and row.ratio) or 0.75
        core.graphics.text_2d(string.format("%d  %s", id, nm), V(bx + 6, ry), 13, C(210, 215, 230, 255))
        core.graphics.text_2d(string.format("%.2f", r), V(bx + 188, ry), 13, C(180, 220, 255, 255))
        draw_button(bx + 188, ry - 4, 36, 26, "-")
        draw_button(bx + 230, ry - 4, 36, 26, "+")
        draw_button(bx + bw - 40, ry - 4, 32, 26, "X")
      end)
    end
  end
  pcall(function()
    core.graphics.scissor_pop()
  end)

  if #ids == 0 then
    pcall(function()
      core.graphics.text_2d("No items — merge starter or add an ID.", V(bx + 8, listTop + 12), 12, C(150, 155, 175, 255))
    end)
  end
end

function M.render_setup_tab(root, bx, by, bw, C, V, draw_toggle, draw_button)
  local cfg = root.Config
  local th = cfg.thresholds or {}
  local j = cfg.jitter or {}
  local b = cfg.behavior or {}
  b.reserves = b.reserves or {}
  b.snipe = b.snipe or {}
  b.sell = b.sell or {}
  b.undercut = b.undercut or {}
  b.modules = b.modules or {}
  b.learn = b.learn or {}

  local yy = by
  pcall(function()
    core.graphics.text_2d("Setup (persists with Items to scripts_data/ScienceAHBot/)", V(bx, yy - 2), 12, C(180, 200, 255, 255))
  end)
  yy = yy + 16

  draw_toggle(bx, yy, bw, 28, "Module: Buy", b.modules.buy)
  yy = yy + 32
  draw_toggle(bx, yy, bw, 28, "Module: Sell", b.modules.sell)
  yy = yy + 32
  draw_toggle(bx, yy, bw, 28, "Module: Snipe", b.modules.snipe)
  yy = yy + 32
  draw_toggle(bx, yy, bw, 28, "Module: Undercut", b.modules.undercut)
  yy = yy + 40

  pcall(function()
    core.graphics.text_2d("Min gold reserve: " .. fmt_gold(b.reserves.minGoldCopper), V(bx, yy), 13, C(210, 215, 230, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d(string.format("Default buy ratio (Items w/o ratio): %.2f", th.defaultBuyRatio or 0.75), V(bx, yy), 13, C(210, 215, 230, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d(string.format("Snipe max vs DBMarket: %.2f", b.snipe.maxBuyRatio or 0.52), V(bx, yy), 13, C(210, 215, 230, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d("Sell post stack size: " .. tostring(b.sell.postStackSize or 20), V(bx, yy), 13, C(210, 215, 230, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d(string.format("Buy scan mean: %.1f s", j.scanMeanSeconds or 5), V(bx, yy), 13, C(210, 215, 230, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d(
      string.format("Buy scan clamp: %.1f - %.1f s", j.scanMinDelay or 3.5, j.scanMaxDelay or 7),
      V(bx, yy),
      13,
      C(210, 215, 230, 255)
    )
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  draw_button(bx + 104, yy + 18, 44, 26, "-")
  draw_button(bx + 156, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d(
      string.format(
        "Fatigue work window: %s - %s",
        fmt_min(cfg.fatigueWorkSecondsMin or 2700),
        fmt_min(cfg.fatigueWorkSecondsMax or 3600)
      ),
      V(bx, yy),
      12,
      C(210, 215, 230, 255)
    )
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  draw_button(bx + 104, yy + 18, 44, 26, "-")
  draw_button(bx + 156, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d(
      string.format(
        "Fatigue rest window: %s - %s",
        fmt_min(cfg.fatigueRestSecondsMin or 480),
        fmt_min(cfg.fatigueRestSecondsMax or 720)
      ),
      V(bx, yy),
      12,
      C(210, 215, 230, 255)
    )
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  draw_button(bx + 104, yy + 18, 44, 26, "-")
  draw_button(bx + 156, yy + 18, 44, 26, "+")
  yy = yy + 52

  pcall(function()
    core.graphics.text_2d("Undercut (copper): " .. tostring(b.undercut.undercutCopper or 1), V(bx, yy), 13, C(210, 215, 230, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52

  local L = b.learn
  draw_toggle(bx, yy, bw, 28, "Learn: AH row1 vs TSM (saved)", L.enabled ~= false)
  yy = yy + 34
  pcall(function()
    core.graphics.text_2d(string.format("Learn blend: %.2f", L.blend or 0.35), V(bx, yy), 12, C(200, 215, 235, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52
  pcall(function()
    core.graphics.text_2d(
      string.format("Learn min samples: %d   slack: %.3f", L.minSamples or 5, L.slack or 0.025),
      V(bx, yy),
      12,
      C(200, 215, 235, 255)
    )
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  draw_button(bx + 104, yy + 18, 44, 26, "-")
  draw_button(bx + 156, yy + 18, 44, 26, "+")
  yy = yy + 52
  pcall(function()
    core.graphics.text_2d(string.format("EWMA alpha (react speed): %.2f", L.ewmaAlpha or 0.15), V(bx, yy), 12, C(200, 215, 235, 255))
  end)
  draw_button(bx, yy + 18, 44, 26, "-")
  draw_button(bx + 52, yy + 18, 44, 26, "+")
  yy = yy + 52
  draw_button(bx, yy + 18, 160, 28, "Reset learned patterns")
end

return M
