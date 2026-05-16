--[[ MythicMechanicsSuite — custom_panel renderers for the Astro window.

     `rotation_settings_ui` exposes `t:custom_panel({ render = fn })`
     where `fn(rot, y0)` is handed:
       - `rot.window`   — ImGui-like surface (render_text / render_rect_*)
       - `rot.colors`   — the active theme palette
       - `y0`           — current Y offset inside the tab content area
     and is expected to return the next Y offset.

     Encounter tabs (see `data/encounter_tab_groups.lua`):

       render_encounter_tab_group — one instance: bosses + mechanics +
         per-row enable + palette override chips.

       render_encounters_fallback_all — single "Encounters" list if the
         manifest fails to load (same as the old all/raid/mplus view).

       render_active_panel — live list of active warnings + test &
         clear-all buttons.
]]

local M = {}

local Util       = require("Util")
local Encounters = require("Encounters")
local Mechanics  = require("Mechanics")
local Persistence = require("Persistence")
local Palette     = require("Palette")

local vec2, enums, color
do
  local ok1, v = pcall(require, "common/geometry/vector_2"); vec2 = ok1 and v or nil
  local ok2, e = pcall(require, "common/enums");             enums = ok2 and e or nil
  local ok3, c = pcall(require, "common/color");             color = ok3 and c or nil
end

--- Match `RotationSettingsUI:_body_font_id` so custom panels scale
--- text with Settings → readability when the host exposes font tiers.
local function FONT(rot)
  local fid = enums and enums.window_enums and enums.window_enums.font_id
  if not fid then return 0 end
  local s = (rot and rot.accessibility_scale) or 1.0
  if s >= 1.45 then
    return fid.FONT_MEDIUM or fid.FONT_NORMAL or fid.FONT_SMALL
  end
  if s >= 1.2 then
    return fid.FONT_NORMAL or fid.FONT_MEDIUM or fid.FONT_SMALL
  end
  return fid.FONT_SMALL
end

local function V2(x, y)
  if vec2 and vec2.new then return vec2.new(x, y) end
  return { x = x, y = y }
end

local PAD = 12
local LINE_H = 14
local ROW_ENC_H = 22
--- Per mechanic: label row + one palette chip row (width auto-fit).
local ROW_MECH_BLOCK = 40

--- Palette keys exposed as quick-override chips (subset of Config.colors).
local MECH_PALETTE_KEYS = {
  { k = "danger",  lab = "Dng" },
  { k = "warning", lab = "Wrn" },
  { k = "info",    lab = "Inf" },
  { k = "soak",    lab = "Soak" },
  { k = "dropoff", lab = "Drp" },
  { k = "spread",  lab = "Spr" },
  { k = "stack",   lab = "Stk" },
  { k = "cone",    lab = "Cne" },
  { k = "line",    lab = "Lin" },
}

----------------------------------------------------------------------
-- ENCOUNTERS PANELS
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

local function scroll_get(root, tab_id)
  root._mms_enc_scrolls = root._mms_enc_scrolls or {}
  return root._mms_enc_scrolls[tab_id] or 0
end

local function scroll_set(root, tab_id, v)
  root._mms_enc_scrolls = root._mms_enc_scrolls or {}
  root._mms_enc_scrolls[tab_id] = v
end

--- A simple "button" inside a custom_panel. Returns `true` once on the
--- frame the user clicks it. `active` colours it as selected.
local function button(rot, x, y, w, h, label, active)
  local a, b = V2(x, y), V2(x + w, y + h)
  local bg = active and rot.colors.primary_accent or rot.colors.slider_bg
  rot.window:render_rect_filled(a, b, bg, 3)
  rot.window:render_rect(a, b, rot.colors.border, 1, 1)
  rot.window:render_text(FONT(rot), V2(x + 8, y + 4), rot.colors.text_primary, label)
  if rot.window.is_rect_clicked and rot.window:is_rect_clicked(a, b) then
    return true
  end
  return false
end

--- Compact chip for palette picker rows.
local function chip(rot, x, y, w, h, label, active)
  local a, b = V2(x, y), V2(x + w, y + h)
  local bg = active and rot.colors.primary_accent or rot.colors.slider_bg
  rot.window:render_rect_filled(a, b, bg, 2)
  rot.window:render_rect(a, b, rot.colors.border, 1, 1)
  rot.window:render_text(FONT(rot), V2(x + 3, y + 3), rot.colors.text_primary, label)
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

local function palette_chip_active(cfg, mech, tkey, pk)
  local ov = cfg.mechanicPalettes and cfg.mechanicPalettes[tkey]
  if type(ov) == "string" and ov ~= "" then return ov == pk end
  if type(mech.color) == "string" and mech.color ~= "" then return mech.color == pk end
  return false
end

--- One row of palette override chips + Def (uses window width).
local function render_mech_palette_chips(rot, root, cfg, mech, tkey, cur_y, x0, sz)
  local chip_y = cur_y + 18
  local bx = x0 + 52
  local n = #MECH_PALETTE_KEYS + 1
  local chip_w = math.max(30, math.floor((sz.x - 2 * PAD - bx - 4) / n))
  for _, pk in ipairs(MECH_PALETTE_KEYS) do
    local active = palette_chip_active(cfg, mech, tkey, pk.k)
    if chip(rot, bx, chip_y, chip_w, 18, pk.lab, active) then
      cfg.mechanicPalettes[tkey] = pk.k
      Persistence.mark_dirty(root)
    end
    bx = bx + chip_w + 2
  end
  if chip(rot, bx, chip_y, chip_w, 18, "Def", cfg.mechanicPalettes[tkey] == nil) then
    cfg.mechanicPalettes[tkey] = nil
    Persistence.mark_dirty(root)
  end
end

--- One Astro tab: single raid wing / M+ dungeon (see encounter_tab_groups).
function M.render_encounter_tab_group(rot, y0, root, group)
  local w = rot.window
  if not w or not group then return y0 end
  local sz = w:get_size()
  local colors = rot.colors
  local cfg = root.Config
  cfg.toggles = cfg.toggles or {}
  cfg.mechanicPalettes = cfg.mechanicPalettes or {}

  local tab_id = group.tab_id or "mms_enc_unknown"
  local x0 = PAD
  local y = y0 + 6

  w:render_text(FONT(rot), V2(x0, y), colors.text_secondary,
    "Toggle bosses/mechanics. Palette chips override draw colors (saved per mechanic).")
  y = y + LINE_H + 6

  local listTop = y
  local listH = math.max(160, sz.y - listTop - PAD - 4)
  local list_a, list_b = V2(x0, listTop), V2(x0 + sz.x - 2 * PAD, listTop + listH)
  w:render_rect_filled(list_a, list_b, colors.section_bg, 4)
  w:render_rect(list_a, list_b, colors.section_border, 4, 1)

  root._mms_enc_list_hit = { x = x0, y = listTop, w = sz.x - 2 * PAD, h = listH, tab_id = tab_id }

  local content_h = 0
  for _, eid in ipairs(group.encounter_ids or {}) do
    local enc = Encounters.encounter_by_id(eid)
    if enc then
      content_h = content_h + ROW_ENC_H + #(enc.mechanics or {}) * ROW_MECH_BLOCK + 6
    end
  end

  local scroll = scroll_get(root, tab_id)
  local maxScroll = math.max(0, content_h - listH + 20)
  if scroll > maxScroll then scroll = maxScroll end
  if scroll < 0 then scroll = 0 end
  scroll_set(root, tab_id, scroll)

  local cur_y = listTop + 6 - scroll
  for _, eid in ipairs(group.encounter_ids or {}) do
    local enc = Encounters.encounter_by_id(eid)
    if enc then
      if cur_y + ROW_ENC_H >= listTop and cur_y <= listTop + listH then
        local enc_key = tostring(enc.id)
        local enc_on = cfg.toggles[enc_key] ~= false
        if checkbox(rot, x0 + 8, cur_y + 2, enc_on) then
          cfg.toggles[enc_key] = not enc_on and true or false
          Persistence.mark_dirty(root)
        end
        w:render_text(FONT(rot), V2(x0 + 28, cur_y + 1), colors.text_primary,
          string.format("%s  [%s]", tostring(enc.name or enc.id), tostring(enc.kind or "?")))
      end
      cur_y = cur_y + ROW_ENC_H

      for _, mech in ipairs(enc.mechanics or {}) do
        if cur_y + ROW_MECH_BLOCK >= listTop and cur_y <= listTop + listH then
          local tkey = Encounters.toggle_key(enc, mech)
          local on = cfg.toggles[tkey] ~= false
          if checkbox(rot, x0 + 32, cur_y + 2, on) then
            cfg.toggles[tkey] = not on and true or false
            Persistence.mark_dirty(root)
            Mechanics.refresh_watch(root)
          end
          local label = string.format("%s  |  %s  |  %s  |  id %s",
            tostring(mech.message or mech.name or mech.id),
            tostring(mech.type or "?"),
            tostring(mech.trigger or "?"),
            tostring(mech.spellID or "-"))
          w:render_text(FONT(rot), V2(x0 + 52, cur_y + 1), colors.text_secondary, label)

          render_mech_palette_chips(rot, root, cfg, mech, tkey, cur_y, x0, sz)
        end
        cur_y = cur_y + ROW_MECH_BLOCK
      end
      cur_y = cur_y + 6
    end
  end

  if maxScroll > 0 then
    w:render_text(FONT(rot),
      V2(x0 + 4, listTop + listH - 14),
      colors.text_disabled,
      string.format("scroll %.0f / %.0f", scroll, maxScroll))
  end

  return y0 + 6 + LINE_H + 6 + listH + 8
end

--- Fallback single tab: all encounters with raid/mplus filters (legacy).
function M.render_encounters_fallback_all(rot, y0, root)
  local w = rot.window
  if not w then return y0 end
  local sz = w:get_size()
  local colors = rot.colors
  local cfg = root.Config
  cfg.toggles = cfg.toggles or {}
  cfg.mechanicPalettes = cfg.mechanicPalettes or {}

  local tab_id = "mms_enc_fallback"
  root._mms_enc_filter = root._mms_enc_filter or "all"

  local x0 = PAD
  local y = y0 + 6

  for i, f in ipairs(FILTERS) do
    if button(rot, x0 + (i - 1) * 88, y, 84, 24, f, root._mms_enc_filter == f) then
      root._mms_enc_filter = f
      scroll_set(root, tab_id, 0)
    end
  end
  y = y + 32

  local total = 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    total = total + #(e.mechanics or {})
  end
  w:render_text(FONT(rot), V2(x0, y), colors.text_secondary,
    string.format("%d mechanics loaded (Midnight data). Use instance tabs when available.", total))
  y = y + LINE_H + 4

  local listTop = y
  local listH = math.max(140, sz.y - listTop - PAD - 4)
  local list_a, list_b = V2(x0, listTop), V2(x0 + sz.x - 2 * PAD, listTop + listH)
  w:render_rect_filled(list_a, list_b, colors.section_bg, 4)
  w:render_rect(list_a, list_b, colors.section_border, 4, 1)

  root._mms_enc_list_hit = { x = x0, y = listTop, w = sz.x - 2 * PAD, h = listH, tab_id = tab_id }

  local encs = filter_encounters(root._mms_enc_filter)
  local content_h = 0
  for _, enc in ipairs(encs) do
    content_h = content_h + ROW_ENC_H + #(enc.mechanics or {}) * ROW_MECH_BLOCK + 6
  end

  local scroll = scroll_get(root, tab_id)
  local maxScroll = math.max(0, content_h - listH + 20)
  if scroll > maxScroll then scroll = maxScroll end
  if scroll < 0 then scroll = 0 end
  scroll_set(root, tab_id, scroll)

  local cur_y = listTop + 6 - scroll
  for _, enc in ipairs(encs) do
    if cur_y + ROW_ENC_H >= listTop and cur_y <= listTop + listH then
      local enc_key = tostring(enc.id)
      local enc_on = cfg.toggles[enc_key] ~= false
      if checkbox(rot, x0 + 8, cur_y + 2, enc_on) then
        cfg.toggles[enc_key] = not enc_on and true or false
        Persistence.mark_dirty(root)
      end
      w:render_text(FONT(rot), V2(x0 + 28, cur_y + 1), colors.text_primary,
        string.format("%s  [%s]", tostring(enc.name or enc.id), tostring(enc.kind or "?")))
    end
    cur_y = cur_y + ROW_ENC_H

    for _, mech in ipairs(enc.mechanics or {}) do
      if cur_y + ROW_MECH_BLOCK >= listTop and cur_y <= listTop + listH then
        local tkey = Encounters.toggle_key(enc, mech)
        local on = cfg.toggles[tkey] ~= false
        if checkbox(rot, x0 + 32, cur_y + 2, on) then
          cfg.toggles[tkey] = not on and true or false
          Persistence.mark_dirty(root)
          Mechanics.refresh_watch(root)
        end
        local label = string.format("%s  |  %s  |  %s  |  id %s",
          tostring(mech.message or mech.name or mech.id),
          tostring(mech.type or "?"),
          tostring(mech.trigger or "?"),
          tostring(mech.spellID or "-"))
        w:render_text(FONT(rot), V2(x0 + 52, cur_y + 1), colors.text_secondary, label)

        render_mech_palette_chips(rot, root, cfg, mech, tkey, cur_y, x0, sz)
      end
      cur_y = cur_y + ROW_MECH_BLOCK
    end
    cur_y = cur_y + 6
  end

  if maxScroll > 0 then
    w:render_text(FONT(rot),
      V2(x0 + 4, listTop + listH - 14),
      colors.text_disabled,
      string.format("scroll %.0f / %.0f", scroll, maxScroll))
  end

  return y0 + 32 + LINE_H + 4 + listH + 8
end

--- Mouse-wheel scroll for encounter lists. `tab_id` must match the
--- active tab's `section.id` (see UI.lua).
function M.encounters_wheel(root, mouse_x, mouse_y, tab_id)
  local r = root._mms_enc_list_hit
  if not r then return end
  if tab_id and r.tab_id and r.tab_id ~= tab_id then return end
  if mouse_x < r.x or mouse_x > r.x + r.w then return end
  if mouse_y < r.y or mouse_y > r.y + r.h then return end
  local wd = 0
  pcall(function()
    if core and core.get_mouse_wheel_delta then
      wd = core.get_mouse_wheel_delta()
    end
  end)
  if wd ~= 0 then
    local tid = tab_id or r.tab_id or "_"
    local cur = scroll_get(root, tid)
    scroll_set(root, tid, math.max(0, cur - wd * 32))
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
  w:render_text(FONT(rot), V2(x0, y), colors.text_secondary,
    string.format("Active warnings: %d   (max %d)",
      #active, (cfg.behavior and cfg.behavior.maxActiveMechanics) or 24))
  y = y + LINE_H + 4

  --- Routing line — surface the active dataSource selection so the
  --- user can see at a glance which signal path is allowed to fire.
  local mode = (cfg.behavior and cfg.behavior.dataSource) or "Auto"
  local mode_help = {
    Auto          = "both (local + BW/DBM, deduped)",
    HardcodedOnly = "local Tracker only — BW/DBM events ignored",
    AddonOnly     = "BW/DBM only — local polling skipped",
  }
  local mode_col = (mode == "Auto") and colors.primary_accent or colors.secondary_accent
  w:render_text(FONT(rot), V2(x0, y), mode_col,
    string.format("Routing: %s  (%s)", mode, mode_help[mode] or "?"))
  y = y + LINE_H + 4

  --- BW/DBM bridge status pill — re-rendered each frame so the user
  --- can watch it flip when they install/load BW or DBM mid-session.
  local ok_br, Bridge = pcall(require, "BWDBMBridge")
  if ok_br and Bridge and Bridge.status then
    local s = Bridge.status(root)
    --- Routing override: when `dataSource = "HardcodedOnly"` the
    --- bridge is intentionally silenced regardless of the per-source
    --- mirror toggles. Reflect that in the pill so the user
    --- understands why their BW alerts aren't lighting up.
    local routing_silences_bridge = (mode == "HardcodedOnly")
    local function pill(name, loaded, subscribed, mirror_on, version)
      if not loaded then
        return string.format("%s: not loaded", name)
      end
      if not subscribed then
        return string.format("%s: detected v%s · subscribe failed", name, tostring(version or "?"))
      end
      if routing_silences_bridge then
        return string.format("%s: subscribed v%s · mirror OFF (forced by routing)",
          name, tostring(version or "?"))
      end
      if mirror_on then
        return string.format("%s: subscribed v%s · mirror ON", name, tostring(version or "?"))
      end
      return string.format("%s: subscribed v%s · mirror off", name, tostring(version or "?"))
    end
    local function dim(col, dim_it) return dim_it and colors.text_disabled or col end
    local dbm_active = s.dbm_loaded and s.mirror_dbm and not routing_silences_bridge
    local bw_active  = s.bw_loaded  and s.mirror_bw  and not routing_silences_bridge
    w:render_text(FONT(rot), V2(x0, y),
      dim(dbm_active and colors.primary_accent or colors.text_disabled, false),
      pill("DBM",     s.dbm_loaded, s.dbm_subscribed, s.mirror_dbm, s.dbm_version))
    y = y + LINE_H
    w:render_text(FONT(rot), V2(x0, y),
      dim(bw_active and colors.primary_accent or colors.text_disabled, false),
      pill("BigWigs", s.bw_loaded,  s.bw_subscribed,  s.mirror_bw,  s.bw_version))
    y = y + LINE_H + 4
  end

  --- Header
  w:render_text(FONT(rot), V2(x0, y), colors.text_disabled,
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
    --- Display label priority: message (user-facing) → name (legacy
    --- field) → id (machine-friendly fallback). The new Midnight
    --- schema uses `message`; the old hierarchical files used `name`.
    local mech_label = (e.mech and (e.mech.message or e.mech.name or e.mech.id)) or "?"
    w:render_text(FONT(rot), V2(x0 + 6, ry), col,
      string.format("%s%-26s %-26s %-8s %4.1fs", src,
        tostring((e.enc and e.enc.name) or "?"):sub(1, 26),
        tostring(mech_label):sub(1, 26),
        tostring((e.mech and e.mech.type) or "-"),
        remaining))
  end

  if #active == 0 then
    w:render_text(FONT(rot), V2(x0 + 8, y + 10), colors.text_disabled,
      "No active mechanics. Engage a boss to see warnings.")
  end

  return y + viewH + 8
end

----------------------------------------------------------------------
-- APPEARANCE PANELS (swatch preview + reset button)
----------------------------------------------------------------------

--- Render a horizontal strip of color swatches, one per editable
--- palette key, each labeled. Reads `cfg.colors` live so the swatches
--- update in real time as the user drags the R/G/B sliders.
function M.render_appearance_swatches(rot, y0, root)
  local w = rot.window
  if not w then return y0 end
  local colors = rot.colors
  local cfg = root.Config or {}
  cfg.colors = cfg.colors or {}

  local x0 = PAD
  local y = y0 + 6

  --- Header
  w:render_text(FONT(rot), V2(x0, y), colors.text_secondary,
    "Live preview — swatches reflect current sliders + globalAlphaMult.")
  y = y + LINE_H + 4

  --- Layout: two rows of swatches so they fit a 540 px-wide window
  --- without horizontal scrolling. 4 per row, 110 px each + 8 gap.
  local swatch_w, swatch_h = 110, 30
  local gap = 8
  local per_row = 4
  local mult = (cfg.appearance and cfg.appearance.globalAlphaMult) or 1.0

  for i, key in ipairs(Palette.EDITABLE_KEYS) do
    local row_i = math.floor((i - 1) / per_row)
    local col_i = (i - 1) % per_row
    local sx = x0 + col_i * (swatch_w + gap)
    local sy = y + row_i * (swatch_h + LINE_H + 10)

    local pc = cfg.colors[key] or { r = 200, g = 200, b = 200, a = 235 }
    --- Mirror Mechanics.with_alpha_mult so the swatch alpha matches
    --- what the engine actually draws. Keep it clamped.
    local a = math.max(0, math.min(255, math.floor(((pc.a or 235) * mult) + 0.5)))
    local fill = { r = pc.r or 0, g = pc.g or 0, b = pc.b or 0, a = a }

    w:render_rect_filled(V2(sx, sy), V2(sx + swatch_w, sy + swatch_h), fill, 4)
    w:render_rect(V2(sx, sy), V2(sx + swatch_w, sy + swatch_h), colors.section_border, 1, 4)
    w:render_text(FONT(rot), V2(sx + 4, sy + swatch_h + 2), colors.text_primary,
      string.format("%s  %d,%d,%d", key, pc.r or 0, pc.g or 0, pc.b or 0))
  end

  local rows = math.ceil(#Palette.EDITABLE_KEYS / per_row)
  y = y + rows * (swatch_h + LINE_H + 10) + 6

  --- Show the resolved preset name so the user knows whether they're
  --- still "on preset" or in "custom" mode.
  local appear = cfg.appearance or {}
  local preset = appear.preset or "default"
  local preset_col = (preset == "custom") and colors.secondary_accent or colors.primary_accent
  w:render_text(FONT(rot), V2(x0, y), preset_col,
    string.format("Active preset: %s  |  global alpha: %.0f%%",
      preset, (mult or 1.0) * 100))
  y = y + LINE_H + 6

  return y
end

--- Reset button — applies the "default" preset and resets the global
--- alpha multiplier to 1.0. Marks Persistence dirty so the change
--- survives reload.
function M.render_appearance_reset(rot, y0, root)
  local w = rot.window
  if not w then return y0 end
  local colors = rot.colors
  local cfg = root.Config

  local x0 = PAD
  local y = y0 + 6

  --- Reset palette button
  local btn_w, btn_h = 220, 28
  local a, b = V2(x0, y), V2(x0 + btn_w, y + btn_h)
  w:render_rect_filled(a, b, colors.primary_accent, 4)
  w:render_rect(a, b, colors.border, 1, 4)
  w:render_text(FONT(rot), V2(x0 + 12, y + 6), colors.text_primary, "Reset palette to default")
  if w.is_rect_clicked and w:is_rect_clicked(a, b) then
    Util.try("AstroPanels.appearance_reset", function()
      Palette.apply_preset(root, "default")
      cfg.appearance = cfg.appearance or {}
      cfg.appearance.globalAlphaMult = 1.0
      Persistence.mark_dirty(root)
      --- Mark the menu signature stale so AstroMenu.sync_config_to_menu
      --- is forced to push the new RGBs into the sliders on the very
      --- next on_update tick.
      root._mms_menu_sig = nil
    end, { root = root })
  end

  --- Hint text
  w:render_text(FONT(rot), V2(x0 + btn_w + 12, y + 6), colors.text_secondary,
    "Restores danger / warning / info / soak / dropoff / spread / stack.")

  return y + btn_h + 8
end

return M
