--[[ MythicMechanicsSuite — custom_panel renderers for the Astro window.

     `rotation_settings_ui` exposes `t:custom_panel({ render = fn })`
     where `fn(rot, y0)` is handed:
       - `rot.window`   — ImGui-like surface (render_text / render_rect_*)
       - `rot.colors`   — the active theme palette
       - `y0`           — current Y offset inside the tab content area
     and is expected to return the next Y offset.

     Two panels live here:

       render_encounters_panel — filter buttons + scrollable
                                 per-encounter / per-mechanic toggle list

       render_active_panel     — live list of active warnings + test &
                                 clear-all buttons.
]]

local M = {}

local Util       = require("Util")
local Encounters = require("Encounters")
local Mechanics  = require("Mechanics")
local Persistence = require("Persistence")

local vec2, enums, color
do
  local ok1, v = pcall(require, "common/geometry/vector_2"); vec2 = ok1 and v or nil
  local ok2, e = pcall(require, "common/enums");             enums = ok2 and e or nil
  local ok3, c = pcall(require, "common/color");             color = ok3 and c or nil
end

local function FONT()
  if enums and enums.window_enums and enums.window_enums.font_id then
    return enums.window_enums.font_id.FONT_SMALL
  end
  return 0
end

local function V2(x, y)
  if vec2 and vec2.new then return vec2.new(x, y) end
  return { x = x, y = y }
end

local PAD = 12
local LINE_H = 14
local ROW_ENC_H = 22
local ROW_MECH_H = 18

----------------------------------------------------------------------
-- ENCOUNTERS PANEL
----------------------------------------------------------------------

local FILTERS = { "all", "raid", "mplus" }

local function filter_encounters(filter)
  local list = Encounters.all_encounters() or {}
  if filter == "all" then return list end
  local out = {}
  for _, e in ipairs(list) do
    if e.kind == filter then out[#out + 1] = e end
  end
  return out
end

--- A simple "button" inside a custom_panel. Returns `true` once on the
--- frame the user clicks it. `active` colours it as selected.
local function button(rot, x, y, w, h, label, active)
  local a, b = V2(x, y), V2(x + w, y + h)
  local bg = active and rot.colors.primary_accent or rot.colors.slider_bg
  rot.window:render_rect_filled(a, b, bg, 3)
  rot.window:render_rect(a, b, rot.colors.border, 1, 1)
  rot.window:render_text(FONT(), V2(x + 8, y + 4), rot.colors.text_primary, label)
  if rot.window.is_rect_clicked and rot.window:is_rect_clicked(a, b) then
    return true
  end
  return false
end

local function checkbox(rot, x, y, on)
  local sz = 14
  local a, b = V2(x, y), V2(x + sz, y + sz)
  local col = on and rot.colors.checkbox_active or rot.colors.checkbox_inactive
  rot.window:render_rect_filled(a, b, col, 2)
  rot.window:render_rect(a, b, rot.colors.checkbox_border, 1, 1)
  if rot.window.is_rect_clicked and rot.window:is_rect_clicked(a, b) then
    return true
  end
  return false
end

function M.render_encounters_panel(rot, y0, root)
  local w = rot.window
  if not w then return y0 end
  local sz = w:get_size()
  local colors = rot.colors
  local cfg = root.Config
  cfg.toggles = cfg.toggles or {}

  root._mms_enc_filter = root._mms_enc_filter or "all"
  root._mms_enc_scroll = root._mms_enc_scroll or 0

  local x0 = PAD
  local y = y0 + 6

  --- Filter buttons
  for i, f in ipairs(FILTERS) do
    if button(rot, x0 + (i - 1) * 88, y, 84, 24, f, root._mms_enc_filter == f) then
      root._mms_enc_filter = f
      root._mms_enc_scroll = 0
    end
  end
  y = y + 32

  --- Placeholder status pill (re-rendered each frame so the user can
  --- watch the counter drop as they edit the data file mid-session).
  local total, ph = 0, 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    for _, m in ipairs(e.mechanics or {}) do
      total = total + 1
      if m._placeholder then ph = ph + 1 end
    end
  end
  local status
  if ph > 0 then
    status = string.format("Spell IDs: %d / %d are PLACEHOLDERS — edit data/*.lua", ph, total)
    w:render_text(FONT(), V2(x0, y), colors.secondary_accent, status)
  else
    status = string.format("Spell IDs: all %d verified.", total)
    w:render_text(FONT(), V2(x0, y), colors.text_secondary, status)
  end
  y = y + LINE_H + 4

  --- Scroll viewport
  local listTop = y
  local listH = math.max(140, sz.y - listTop - PAD - 4)
  local list_a, list_b = V2(x0, listTop), V2(x0 + sz.x - 2 * PAD, listTop + listH)
  w:render_rect_filled(list_a, list_b, colors.section_bg, 4)
  w:render_rect(list_a, list_b, colors.section_border, 4, 1)

  --- Hit-test rectangle used by `encounters_wheel` to capture mouse-wheel.
  root._mms_enc_list_hit = { x = x0, y = listTop, w = sz.x - 2 * PAD, h = listH }

  local encs = filter_encounters(root._mms_enc_filter)

  --- Compute total content height to clamp scroll
  local content_h = 0
  for _, enc in ipairs(encs) do
    content_h = content_h + ROW_ENC_H + #(enc.mechanics or {}) * ROW_MECH_H + 6
  end
  local maxScroll = math.max(0, content_h - listH + 20)
  if root._mms_enc_scroll > maxScroll then root._mms_enc_scroll = maxScroll end
  if root._mms_enc_scroll < 0 then root._mms_enc_scroll = 0 end

  local cur_y = listTop + 6 - root._mms_enc_scroll
  for _, enc in ipairs(encs) do
    --- Encounter header row
    if cur_y + ROW_ENC_H >= listTop and cur_y <= listTop + listH then
      local enc_key = tostring(enc.id)
      local enc_on = cfg.toggles[enc_key] ~= false
      if checkbox(rot, x0 + 8, cur_y + 2, enc_on) then
        cfg.toggles[enc_key] = not enc_on and true or false
        Persistence.mark_dirty(root)
      end
      w:render_text(FONT(), V2(x0 + 28, cur_y + 1), colors.text_primary,
        string.format("%s  [%s]", tostring(enc.name or enc.id), tostring(enc.kind or "?")))
    end
    cur_y = cur_y + ROW_ENC_H

    --- Mechanic rows
    for _, mech in ipairs(enc.mechanics or {}) do
      if cur_y + ROW_MECH_H >= listTop and cur_y <= listTop + listH then
        local key = Encounters.toggle_key(enc, mech)
        local on = cfg.toggles[key] ~= false
        if checkbox(rot, x0 + 32, cur_y + 2, on) then
          cfg.toggles[key] = not on and true or false
          Persistence.mark_dirty(root)
          Mechanics.refresh_watch(root)
        end
        local row_col = colors.text_secondary
        if mech._placeholder then row_col = colors.secondary_accent end
        local label = string.format("%s (%s, %s, %s%s)",
          tostring(mech.name or mech.id),
          tostring(mech.type or "?"),
          tostring(mech.priority or "?"),
          tostring(mech.spellID or "-"),
          mech._placeholder and "*" or "")
        w:render_text(FONT(), V2(x0 + 52, cur_y + 1), row_col, label)
      end
      cur_y = cur_y + ROW_MECH_H
    end
    cur_y = cur_y + 6
  end

  --- Scroll indicator
  if maxScroll > 0 then
    w:render_text(FONT(),
      V2(x0 + 4, listTop + listH - 14),
      colors.text_disabled,
      string.format("scroll %.0f / %.0f", root._mms_enc_scroll, maxScroll))
  end

  return y0 + 32 + LINE_H + 4 + listH + 8
end

--- Mouse-wheel scroll for the encounters list. Wired from UI.lua's
--- on_update callback the same way ScienceAHBot's AstroPanels.items_wheel
--- is wired.
function M.encounters_wheel(root, mouse_x, mouse_y)
  local r = root._mms_enc_list_hit
  if not r then return end
  if mouse_x < r.x or mouse_x > r.x + r.w then return end
  if mouse_y < r.y or mouse_y > r.y + r.h then return end
  local wd = 0
  pcall(function()
    if core and core.get_mouse_wheel_delta then
      wd = core.get_mouse_wheel_delta()
    end
  end)
  if wd ~= 0 then
    root._mms_enc_scroll = math.max(0, (root._mms_enc_scroll or 0) - wd * 32)
  end
end

----------------------------------------------------------------------
-- ACTIVE PANEL
----------------------------------------------------------------------

function M.render_active_panel(rot, y0, root)
  local w = rot.window
  if not w then return y0 end
  local sz = w:get_size()
  local colors = rot.colors
  local cfg = root.Config

  local x0 = PAD
  local y = y0 + 6

  --- Test + Clear buttons
  if button(rot, x0, y, 180, 26, "Test: draw at me", false) then
    Util.try("AstroPanels.test_self", function()
      local World = require("World")
      local lp = World.local_player()
      if lp then
        local now = Util.now_seconds()
        table.insert(Mechanics.active(root), {
          enc  = { id = "test", name = "Self-test" },
          mech = { id = "test_circle", type = "circle", radius = 8,
                   duration = 4, color = "danger", message = "Test ring" },
          unit = lp,
          spawned_at = now,
          expires_at = now + 4,
          color  = cfg.colors and cfg.colors.danger or { r=235,g=60,b=60,a=235 },
          radius = 8, length = 10, width = 4, kind = "test",
        })
      end
    end, { root = root })
  end
  if button(rot, x0 + 190, y, 120, 26, "Clear all", false) then
    Mechanics.clear(root)
  end
  y = y + 36

  --- Counter line
  local active = Mechanics.active(root) or {}
  w:render_text(FONT(), V2(x0, y), colors.text_secondary,
    string.format("Active warnings: %d   (max %d)",
      #active, (cfg.behavior and cfg.behavior.maxActiveMechanics) or 24))
  y = y + LINE_H + 4

  --- BW/DBM bridge status pill — re-rendered each frame so the user
  --- can watch it flip when they install/load BW or DBM mid-session.
  local ok_br, Bridge = pcall(require, "BWDBMBridge")
  if ok_br and Bridge and Bridge.status then
    local s = Bridge.status(root)
    local function pill(name, loaded, subscribed, mirror_on, version)
      if not loaded then
        return string.format("%s: not loaded", name)
      end
      if not subscribed then
        return string.format("%s: detected v%s · subscribe failed", name, tostring(version or "?"))
      end
      if mirror_on then
        return string.format("%s: subscribed v%s · mirror ON", name, tostring(version or "?"))
      end
      return string.format("%s: subscribed v%s · mirror off", name, tostring(version or "?"))
    end
    local dbm_col = (s.dbm_loaded and s.mirror_dbm) and colors.primary_accent or colors.text_disabled
    local bw_col  = (s.bw_loaded  and s.mirror_bw)  and colors.primary_accent or colors.text_disabled
    w:render_text(FONT(), V2(x0, y), dbm_col, pill("DBM",      s.dbm_loaded, s.dbm_subscribed, s.mirror_dbm, s.dbm_version))
    y = y + LINE_H
    w:render_text(FONT(), V2(x0, y), bw_col,  pill("BigWigs",  s.bw_loaded,  s.bw_subscribed,  s.mirror_bw,  s.bw_version))
    y = y + LINE_H + 4
  end

  --- Header
  w:render_text(FONT(), V2(x0, y), colors.text_disabled,
    string.format("%-28s %-28s %-8s %-6s", "Encounter", "Mechanic", "Type", "Time"))
  y = y + LINE_H

  --- List
  local now = Util.now_seconds()
  local row_h = LINE_H
  local viewH = math.max(80, sz.y - y - PAD - 4)
  local list_a, list_b = V2(x0, y), V2(x0 + sz.x - 2 * PAD, y + viewH)
  w:render_rect_filled(list_a, list_b, colors.section_bg, 3)
  w:render_rect(list_a, list_b, colors.section_border, 3, 1)

  for i, e in ipairs(active) do
    local ry = y + 4 + (i - 1) * row_h
    if ry + row_h > y + viewH then break end
    local remaining = math.max(0, (e.expires_at or now) - now)
    local col = colors.text_primary
    if e.mech and e.mech.priority == "high" then col = colors.primary_accent end
    if e.source then col = colors.secondary_accent end
    local src = e.source and ("[" .. e.source .. "] ") or ""
    w:render_text(FONT(), V2(x0 + 6, ry), col,
      string.format("%s%-26s %-26s %-8s %4.1fs", src,
        tostring((e.enc and e.enc.name) or "?"):sub(1, 26),
        tostring((e.mech and e.mech.name) or (e.mech and e.mech.id) or "?"):sub(1, 26),
        tostring((e.mech and e.mech.type) or "-"),
        remaining))
  end

  if #active == 0 then
    w:render_text(FONT(), V2(x0 + 8, y + 10), colors.text_disabled,
      "No active mechanics. Engage a boss to see warnings.")
  end

  return y + viewH + 8
end

return M
