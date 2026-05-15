--[[ Custom tab content for astro window (dashboard text, items editor). ]]

-- module-local, returned as the public interface
local M = {}

local DashboardLines = require("DashboardLines")
local IG = require("UI_InGame")
local Persistence = require("Persistence")

local vec2 = require("common/geometry/vector_2")
local enums = require("common/enums")
local color = require("common/color")
local FONT = enums.window_enums.font_id.FONT_SMALL

local PAD = 15
local LINE_H = 13
local ITEM_ROW_H = 50
local LIST_TOP_OFF = 118

local function clamp(x, lo, hi)
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

function M.render_dashboard_feed(rot, y0, root)
  local w = rot.window
  if not w then
    return y0
  end
  local sz = w:get_size()
  local colors = rot.colors
  local x0 = PAD
  local y = y0 + 8

  w:render_text(FONT, vec2.new(x0, y), colors.text_secondary, "Scroll with mouse wheel. Toggle window: PS menu or grave/backtick.")
  y = y + LINE_H + 6

  local lines = DashboardLines.build_lines(root)
  local viewH = math.max(80, sz.y - y - PAD - 24)
  local totalH = #lines * LINE_H + 8
  local maxScroll = math.max(0, totalH - viewH)
  root.dashScroll = root.dashScroll or 0
  root.dashScroll = math.min(root.dashScroll, maxScroll)

  local top_clip = y
  local bot_clip = y + viewH
  local sx = x0
  local sy = y + 4 - (root.dashScroll or 0)

  for i = 1, #lines do
    local line = lines[i]
    local ly = sy + (i - 1) * LINE_H
    if ly + LINE_H >= top_clip and ly <= bot_clip and line ~= "" then
      local col = colors.text_secondary
      if #line >= 2 and line:sub(1, 2) == "──" then
        col = colors.primary_accent
      elseif line:find("ScienceAHBot", 1, true) then
        col = colors.text_primary
      end
      w:render_text(FONT, vec2.new(sx, ly), col, line)
    end
  end

  if maxScroll > 0 then
    w:render_text(
      FONT,
      vec2.new(x0, bot_clip - 12),
      colors.text_disabled,
      string.format("scroll %.0f / %.0f px", root.dashScroll or 0, maxScroll)
    )
  end

  root._astro_dash_scroll_hit = {
    x = 0,
    y = top_clip - 4,
    w = sz.x,
    h = viewH + 8,
  }

  return y0 + viewH + PAD + 24
end

function M.dashboard_wheel(root, mouse_x, mouse_y)
  local r = root._astro_dash_scroll_hit
  if not r then
    return
  end
  if mouse_x >= r.x and mouse_x <= r.x + r.w and mouse_y >= r.y and mouse_y <= r.y + r.h then
    local wd = 0
    pcall(function()
      wd = core.get_mouse_wheel_delta()
    end)
    if wd ~= 0 then
      root.dashScroll = math.max(0, (root.dashScroll or 0) - wd * 24)
    end
  end
end

function M.render_items_panel(rot, y0, root)
  local w = rot.window
  if not w then
    return y0
  end
  local sz = w:get_size()
  local colors = rot.colors
  local cfg = root.Config
  cfg.Items = cfg.Items or {}
  root._uiNewItemRatio = root._uiNewItemRatio or (cfg.thresholds and cfg.thresholds.defaultBuyRatio) or 0.75
  root._uiAddItemBuf = root._uiAddItemBuf or ""

  local bx = PAD
  local by = y0 + 8
  local bw = sz.x - 2 * PAD

  w:render_text(FONT, vec2.new(bx, by), colors.text_secondary, "Edits save to scripts_data/ScienceAHBot/user_settings.lua")
  by = by + LINE_H + 2
  w:render_text(FONT, vec2.new(bx, by), colors.text_disabled, "Click ID bar, type digits, Backspace. Add applies new ratio.")
  by = by + LINE_H + 6

  local entry = (#root._uiAddItemBuf > 0) and root._uiAddItemBuf or "(click to type item ID)"
  local ecol = root.uiFocus == "addId" and colors.secondary_accent or colors.text_primary
  local bar_a = vec2.new(bx, by + 28)
  local bar_b = vec2.new(bx + bw, by + 52)
  w:render_rect_filled(bar_a, bar_b, colors.section_bg, 3)
  w:render_rect(bar_a, bar_b, colors.section_border, 3, 1)
  w:render_text(FONT, vec2.new(bx + 6, by + 34), ecol, entry)

  local merge_a = vec2.new(bx, by + 58)
  local merge_b = vec2.new(bx + 132, by + 86)
  w:render_rect_filled(merge_a, merge_b, colors.slider_bg, 3)
  w:render_rect(merge_a, merge_b, colors.border, 2, 1)
  w:render_text(FONT, vec2.new(bx + 10, by + 64), colors.text_primary, "Merge starter")

  local clear_a = vec2.new(bx + 140, by + 58)
  local clear_b = vec2.new(bx + 228, by + 86)
  w:render_rect_filled(clear_a, clear_b, colors.slider_bg, 3)
  w:render_rect(clear_a, clear_b, colors.border, 2, 1)
  w:render_text(FONT, vec2.new(bx + 168, by + 64), colors.text_primary, "Clear all")

  w:render_text(
    FONT,
    vec2.new(bx + 240, by + 64),
    colors.text_secondary,
    string.format("New ratio: %.2f", root._uiNewItemRatio or 0.75)
  )

  local minus_a = vec2.new(bx + bw - 160, by + 58)
  local minus_b = vec2.new(bx + bw - 124, by + 86)
  w:render_rect_filled(minus_a, minus_b, colors.slider_bg, 2)
  w:render_text(FONT, vec2.new(bx + bw - 148, by + 64), colors.text_primary, "-")
  local plus_a = vec2.new(bx + bw - 118, by + 58)
  local plus_b = vec2.new(bx + bw - 82, by + 86)
  w:render_rect_filled(plus_a, plus_b, colors.slider_bg, 2)
  w:render_text(FONT, vec2.new(bx + bw - 104, by + 64), colors.text_primary, "+")

  local add_a = vec2.new(bx + bw - 200, by + 90)
  local add_b = vec2.new(bx + bw, by + 120)
  w:render_rect_filled(add_a, add_b, colors.primary_accent, 3)
  w:render_text(FONT, vec2.new(bx + bw - 188, by + 98), color.white(255), "Add / update item")

  local listTop = by + LIST_TOP_OFF
  local listH = math.max(100, sz.y - listTop - PAD)

  local list_a = vec2.new(bx, listTop)
  local list_b = vec2.new(bx + bw, listTop + listH)
  w:render_rect_filled(list_a, list_b, colors.section_bg, 4)
  w:render_rect(list_a, list_b, colors.section_border, 4, 1)

  local ids = IG.sorted_item_ids(cfg)
  local scroll = root.itemsScroll or 0
  root._astro_items_list_hit = { x = bx, y = listTop, w = bw, h = listH }

  for i = 1, #ids do
    local id = ids[i]
    local row = cfg.Items[id]
    local ry = listTop + (i - 1) * ITEM_ROW_H - scroll + 6
    if ry + ITEM_ROW_H >= listTop and ry < listTop + listH then
      local nm = (row and row.name) or "?"
      local r = (row and row.ratio) or 0.75
      w:render_text(FONT, vec2.new(bx + 6, ry), colors.text_primary, string.format("%d  %s", id, nm))
      w:render_text(FONT, vec2.new(bx + 188, ry), colors.primary_accent, string.format("%.2f", r))

      local rb1 = vec2.new(bx + 188, ry - 4)
      local rb1b = vec2.new(bx + 224, ry + 22)
      w:render_rect_filled(rb1, rb1b, colors.slider_bg, 2)
      w:render_text(FONT, vec2.new(bx + 202, ry - 1), colors.text_primary, "-")

      local rb2 = vec2.new(bx + 230, ry - 4)
      local rb2b = vec2.new(bx + 266, ry + 22)
      w:render_rect_filled(rb2, rb2b, colors.slider_bg, 2)
      w:render_text(FONT, vec2.new(bx + 244, ry - 1), colors.text_primary, "+")

      local xb = vec2.new(bx + bw - 40, ry - 4)
      local xbb = vec2.new(bx + bw - 8, ry + 22)
      w:render_rect_filled(xb, xbb, colors.secondary_accent, 2)
      w:render_text(FONT, vec2.new(bx + bw - 28, ry - 1), color.white(255), "X")
    end
  end

  if #ids == 0 then
    w:render_text(FONT, vec2.new(bx + 8, listTop + 14), colors.text_disabled, "No items — merge starter or add an ID.")
  end

  --- Clicks (same frame as render)
  if w:is_rect_clicked(bar_a, bar_b) then
    root.uiFocus = "addId"
    root._uiKeyPrev = {}
  end
  if w:is_rect_clicked(merge_a, merge_b) then
    IG.merge_starter_items(cfg)
    Persistence.mark_dirty(root)
  end
  if w:is_rect_clicked(clear_a, clear_b) then
    IG.clear_all_items(cfg)
    Persistence.mark_dirty(root)
  end
  if w:is_rect_clicked(minus_a, minus_b) then
    root._uiNewItemRatio = clamp((root._uiNewItemRatio or 0.75) - 0.05, 0.05, 0.99)
    Persistence.mark_dirty(root)
  end
  if w:is_rect_clicked(plus_a, plus_b) then
    root._uiNewItemRatio = clamp((root._uiNewItemRatio or 0.75) + 0.05, 0.05, 0.99)
    Persistence.mark_dirty(root)
  end
  if w:is_rect_clicked(add_a, add_b) then
    local id = tonumber(root._uiAddItemBuf)
    if id and id > 0 then
      cfg.Items[id] = cfg.Items[id] or { ratio = root._uiNewItemRatio, name = "Item " .. tostring(id) }
      cfg.Items[id].ratio = root._uiNewItemRatio
      root._uiAddItemBuf = ""
      root.uiFocus = nil
      Persistence.mark_dirty(root)
    end
  end

  local total = #ids * ITEM_ROW_H
  local maxScroll = math.max(0, total - listH)
  root.itemsScroll = math.min(root.itemsScroll or 0, maxScroll)

  for i = 1, #ids do
    local id = ids[i]
    local ry = listTop + (i - 1) * ITEM_ROW_H - scroll + 6
    if ry + ITEM_ROW_H >= listTop and ry < listTop + listH then
      local rb1 = vec2.new(bx + 188, ry - 4)
      local rb1b = vec2.new(bx + 224, ry + 22)
      local rb2 = vec2.new(bx + 230, ry - 4)
      local rb2b = vec2.new(bx + 266, ry + 22)
      local xb = vec2.new(bx + bw - 40, ry - 4)
      local xbb = vec2.new(bx + bw - 8, ry + 22)
      if w:is_rect_clicked(xb, xbb) then
        cfg.Items[id] = nil
        Persistence.mark_dirty(root)
      end
      if w:is_rect_clicked(rb1, rb1b) then
        local row = cfg.Items[id]
        if row then
          row.ratio = clamp((row.ratio or 0.75) - 0.05, 0.05, 0.99)
        end
        Persistence.mark_dirty(root)
      end
      if w:is_rect_clicked(rb2, rb2b) then
        local row = cfg.Items[id]
        if row then
          row.ratio = clamp((row.ratio or 0.75) + 0.05, 0.05, 0.99)
        end
        Persistence.mark_dirty(root)
      end
    end
  end

  return listTop + listH + PAD
end

function M.items_wheel(root, mouse_x, mouse_y)
  local r = root._astro_items_list_hit
  if not r then
    return
  end
  if mouse_x >= r.x and mouse_x <= r.x + r.w and mouse_y >= r.y and mouse_y <= r.y + r.h then
    local wd = 0
    pcall(function()
      wd = core.get_mouse_wheel_delta()
    end)
    if wd ~= 0 then
      local cfg = root.Config
      local ids = IG.sorted_item_ids(cfg)
      local total = #ids * ITEM_ROW_H
      local listH = r.h
      local maxScroll = math.max(0, total - listH)
      root.itemsScroll = math.max(0, math.min(maxScroll, (root.itemsScroll or 0) - wd * 20))
    end
  end
end

return M
