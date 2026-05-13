--[[ ScienceAHBot — in-game overlay (core.graphics + cursor hit-tests). Not core.menu. ]]

local UI = {}

local IG = require("ScienceAHBot/UI_InGame")
local Persistence = require("ScienceAHBot/Persistence")
local Util = require("ScienceAHBot/Util")

local ScanLogMod = (function()
  local ok, mod = pcall(require, "ScienceAHBot/ScanLog")
  return ok and mod or nil
end)()

local IZI_mod = (function()
  local ok, mod = pcall(require, "common/izi_sdk")
  return ok and mod or nil
end)()

local PreflightMod = nil
pcall(function()
  PreflightMod = require("ScienceAHBot/Preflight")
end)
local AHGuardDash = nil
pcall(function()
  AHGuardDash = require("ScienceAHBot/AHGuard")
end)

local VK_LMB = 0x01
local TITLE_H = 30
local TAB_TOP = 34
local TAB_H = 28
local BODY_TOP = 68
local DASH_LINE_H = 13
local DASH_ARM_BLOCK = 118

local TAB = { DASHBOARD = 1, ITEMS = 2, BUY = 3, SELL = 4, SNIPE = 5, UNDERCUT = 6, SETUP = 7 }
local TAB_LABELS = { "Dashboard", "Items", "Buy", "Sell", "Snipe", "Undercut", "Setup" }

local color
local izi
local AHBridge

local function load_deps()
  pcall(function()
    color = require("common/color")
  end)
  pcall(function()
    izi = IZI_mod
  end)
  pcall(function()
    AHBridge = require("ScienceAHBot/AHBridge")
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

local function now_s()
  if IZI_mod and IZI_mod.now then
    local o2, t = pcall(IZI_mod.now)
    if o2 and type(t) == "number" then
      return t
    end
  end
  if GetTime then
    return GetTime()
  end
  return 0
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

local function fmt_gold(copper)
  if type(copper) ~= "number" then
    return "—"
  end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  return string.format("%dg %ds %dc", g, s, c)
end

local function fmt_dur(sec)
  if type(sec) ~= "number" or sec ~= sec then
    return "—"
  end
  if sec < 0 then
    sec = 0
  end
  local m = math.floor(sec / 60)
  local s = math.floor(sec % 60)
  return string.format("%dm %02ds", m, s)
end

local function fmt_eta(now, at)
  if type(at) ~= "number" then
    return "—"
  end
  return string.format("%.1fs", math.max(0, at - now))
end

local function list_len(t)
  if type(t) ~= "table" then
    return 0
  end
  return #t
end

local function push_lines(lines, title, pairs_list)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "── " .. title .. " ──"
  for i = 1, #pairs_list do
    local e = pairs_list[i]
    lines[#lines + 1] = string.format("%s: %s", e[1], e[2])
  end
end

local function build_dashboard_lines(root)
  local cfg = root.Config or {}
  local b = cfg.behavior or {}
  local mods = b.modules or {}
  local now = now_s()
  local lines = {}

  lines[#lines + 1] = "ScienceAHBot · live snapshot"
  lines[#lines + 1] = string.format("Clock: %.2f  (izi.now / GetTime)", now)
  lines[#lines + 1] = "Config: Items + Setup tabs; persists to scripts_data/ScienceAHBot/user_settings.lua"

  if PreflightMod and PreflightMod.collect_warnings then
    local warns = PreflightMod.collect_warnings(root)
    local preflightRows = {}
    for i = 1, math.min(#warns, 12) do
      preflightRows[#preflightRows + 1] = { "•", warns[i] }
    end
    if #warns > 12 then
      preflightRows[#preflightRows + 1] = { "•", "(+" .. tostring(#warns - 12) .. " more lines in log)" }
    end
    push_lines(lines, "Preflight (also logged at load)", preflightRows)
  end

  local up = nil
  if root.TimeEnabled and type(root.TimeEnabled) == "number" then
    up = now - root.TimeEnabled
  elseif root.uptimeAnchor and type(root.uptimeAnchor) == "number" then
    up = now - root.uptimeAnchor
  end

  local cdLeft = nil
  if root.apiCooldownUntil and type(root.apiCooldownUntil) == "number" then
    cdLeft = root.apiCooldownUntil - now
  end

  local fatLeft = nil
  if root.state == root.STATE_IDLE and root.fatigueUntil and type(root.fatigueUntil) == "number" then
    fatLeft = root.fatigueUntil - now
  end

  local ahOpen = "—"
  local manPause = root.ManualPause == true and "ON" or "off"
  local backLeft = "—"
  if root._searchFailBackoffUntil and type(root._searchFailBackoffUntil) == "number" then
    local d = root._searchFailBackoffUntil - now
    backLeft = (d > 0) and fmt_dur(d) or "ready"
  end
  if AHGuardDash then
    ahOpen = AHGuardDash.is_auction_ui_open() and "open" or "closed"
  end
  local dbg = b.debug or {}
  push_lines(lines, "Runtime", {
    { "Armed (isActive)", root.isActive and "yes" or "no" },
    { "Manual pause (hotkey)", manPause },
    { "BotActive", (root.BotActive ~= false) and "yes" or "no" },
    { "BotEnabled (panic / timers)", (root.BotEnabled ~= false) and "yes" or "no" },
    { "AH UI (frames)", ahOpen },
    { "Search backoff left", backLeft },
    { "Debug: verbose / dryRun", string.format("%s / %s", (dbg.verbose == true) and "on" or "off", (dbg.dryRun == true) and "on" or "off") },
    { "SessionStartTime (work segment)", root.SessionStartTime and string.format("%.2f", root.SessionStartTime) or "—" },
    { "State", tostring(root.state) },
    { "Session segment", up and fmt_dur(up) or "—" },
    { "API cool-down left", cdLeft and (cdLeft > 0 and fmt_dur(cdLeft) or "ready") or "—" },
    { "Fatigue rest left", fatLeft and (fatLeft > 0 and fmt_dur(fatLeft) or "done") or "n/a" },
    { "Work segment limit (s)", root._workSegmentLimitSec and string.format("%.0f", root._workSegmentLimitSec) or "—" },
    { "Work segment elapsed", (root._workSegmentStart and fmt_dur(now - root._workSegmentStart)) or "—" },
    { "TimeEnabled anchor", root.TimeEnabled and string.format("%.2f", root.TimeEnabled) or "—" },
    { "Uptime anchor", root.uptimeAnchor and string.format("%.2f", root.uptimeAnchor) or "—" },
    { "Timer epoch (panic)", tostring(root._timerEpoch or 0) },
    {
      "Distraction pause (AH)",
      (root._distractionPauseAHUntil and root._distractionPauseAHUntil > now) and string.format("%.0f s left", root._distractionPauseAHUntil - now) or "—",
    },
    { "AH transaction locks", tostring(root._ahTxLock or 0) },
  })

  push_lines(lines, "Module timers (next fire)", {
    { "Buy", string.format("%s  idx=%s", fmt_eta(now, root.tickBuyAt), tostring(root.buyListIndex or 1)) },
    { "Sell", string.format("%s  idx=%s", fmt_eta(now, root.tickSellAt), tostring(root.sellListIndex or 1)) },
    { "Snipe", string.format("%s  idx=%s", fmt_eta(now, root.tickSnipeAt), tostring(root.snipeListIndex or 1)) },
    { "Undercut", string.format("%s  idx=%s", fmt_eta(now, root.tickUndercutAt), tostring(root.ucIdx or 1)) },
  })

  local gold = nil
  pcall(function()
    gold = core.inventory.get_gold()
  end)
  local resC = (b.reserves and b.reserves.minGoldCopper) or nil
  local delta = (type(gold) == "number" and type(resC) == "number") and (gold - resC) or nil

  push_lines(lines, "Economy", {
    { "Player gold", fmt_gold(gold) },
    { "Min reserve (cfg)", fmt_gold(resC) },
    { "Gold − reserve", type(delta) == "number" and fmt_gold(delta) or "—" },
  })

  local sn = b.snipe or {}
  local sl = b.sell or {}
  local uc = b.undercut or {}
  local th = cfg.thresholds or {}
  local j = cfg.jitter or {}

  local itemIds = {}
  pcall(function()
    if root.TSM and root.TSM.GetWatchlistIds then
      itemIds = root.TSM.GetWatchlistIds(cfg)
    end
  end)

  local snList = (sn.watchlist and #sn.watchlist > 0) and sn.watchlist or itemIds
  local slList = (sl.watchlist and #sl.watchlist > 0) and sl.watchlist or itemIds

  push_lines(lines, "Lists & indices", {
    { "Scan IDs (Items / fallback) #", tostring(#itemIds) },
    { "Legacy watchlist #", tostring(list_len(cfg.watchlist)) },
    { "Snipe list #", tostring(list_len(snList)) },
    { "Sell list #", tostring(list_len(slList)) },
    { "Undercut repost list #", tostring(list_len(uc.repostWatchlist)) },
    { "Undercut useMainWL", (uc.useMainWatchlist and "yes" or "no") },
    { "Aggressive scan repost", (uc.aggressiveScanRepost and "yes" or "no") },
  })

  push_lines(lines, "Pricing & pacing (config)", {
    { "DefaultRatio (TSM deal / ratio fallback)", tostring(cfg.DefaultRatio or "—") },
    { "Buy ratio (direct)", tostring(cfg.buyRatio or "nil → thresholds") },
    { "defaultBuyRatio", tostring(th.defaultBuyRatio or "—") },
    { "Snipe maxBuyRatio", tostring(sn.maxBuyRatio or "—") },
    { "Snipe buyout-only", (sn.useBuyoutOnly and "yes" or "no") },
    { "Undercut copper", tostring(uc.undercutCopper or 1) },
    { "Sell stack / mult", string.format("%s / %s", tostring(sl.postStackSize or "—"), tostring(sl.vendorPriceMultiplier or "—")) },
    { "Buy scan mean ± std", string.format("%s ± %s s", tostring(j.scanMeanSeconds), tostring(j.scanStdSeconds)) },
    { "Buy scan clamp", string.format("[%s .. %s] s", tostring(j.scanMinDelay), tostring(j.scanMaxDelay)) },
    {
      "Fatigue work window (s)",
      string.format("%s .. %s", tostring(cfg.fatigueWorkSecondsMin), tostring(cfg.fatigueWorkSecondsMax)),
    },
    {
      "Fatigue rest window (s)",
      string.format("%s .. %s", tostring(cfg.fatigueRestSecondsMin), tostring(cfg.fatigueRestSecondsMax)),
    },
  })

  local Lrn = b.learn or {}
  local pat = cfg.patterns or {}
  local nPat, nReady = 0, 0
  local minN = Lrn.minSamples or 5
  for _, p in pairs(pat) do
    nPat = nPat + 1
    if type(p) == "table" and type(p.n) == "number" and p.n >= minN then
      nReady = nReady + 1
    end
  end
  push_lines(lines, "Adaptive learn", {
    { "Learn enabled", (Lrn.enabled ~= false) and "yes" or "no" },
    {
      "blend / slack / minN / alpha",
      string.format(
        "%.2f / %.3f / %s / %.2f",
        Lrn.blend or 0.35,
        Lrn.slack or 0.025,
        tostring(Lrn.minSamples or 5),
        Lrn.ewmaAlpha or 0.15
      ),
    },
    { "Pattern slots (items)", tostring(nPat) },
    { "Patterns ready (≥ minN)", tostring(nReady) },
  })

  local slog = b.scanLog or {}
  local bufN = (root._scanLogBuf and #root._scanLogBuf) or 0
  push_lines(lines, "Scan log (CSV)", {
    { "Enabled", (slog.enabled == true) and "yes" or "no" },
    { "Rows buffered (not flushed)", tostring(bufN) },
    { "File", "scripts_data/ScienceAHBot/scan_log.csv" },
    {
      "flush rows / debounce s / max bytes",
      string.format(
        "%s / %.1f / %s",
        tostring(slog.flushEveryRows or 8),
        slog.flushDebounceSec or 2,
        tostring(slog.maxFileBytes or 0)
      ),
    },
  })

  local gv, gvx, reg, mapn, mid, ping = "—", "—", "—", "—", "—", "—"
  pcall(function()
    gv = tostring(core.get_game_version())
  end)
  pcall(function()
    gvx = tostring(core.get_exact_game_version())
  end)
  pcall(function()
    reg = tostring(core.get_game_region())
  end)
  pcall(function()
    mapn = tostring(core.get_map_name())
  end)
  pcall(function()
    mid = tostring(core.get_map_id())
  end)
  pcall(function()
    ping = tostring(core.get_ping())
  end)

  push_lines(lines, "Environment", {
    { "Game version", gv },
    { "Exact build", gvx },
    { "Region", reg },
    { "Map", mapn .. "  (id " .. mid .. ")" },
    { "Ping ms", ping },
  })

  local tsmOk = "no"
  pcall(function()
    if _G.TSM_API and TSM_API.GetCustomPriceValue then
      tsmOk = "yes"
    end
  end)
  local cacheN, cacheTtl = 0, 300
  pcall(function()
    if root.TSM and root.TSM.GetCacheStats then
      cacheN, cacheTtl = root.TSM.GetCacheStats()
    end
  end)
  push_lines(lines, "TSM", {
    { "TSM_API + GetCustomPriceValue", tsmOk },
    { "TSM_Helper cache entries / TTL", string.format("%d / %ds", cacheN, cacheTtl or 300) },
  })

  local iziOk = IZI_mod and "yes" or "no"

  local ahKeys = {}
  local ahExtra = 0
  if AHBridge and AHBridge.get_ah_function_keys then
    ahKeys, ahExtra = AHBridge.get_ah_function_keys(36)
  end
  local ahLine = (#ahKeys > 0) and table.concat(ahKeys, ", ") or "(no IZI.AH table)"

  push_lines(lines, "IZI", {
    { "izi_sdk loaded", iziOk },
    { "AH functions (" .. tostring(#ahKeys) .. ", +" .. tostring(ahExtra) .. " more)", ahLine },
  })

  push_lines(lines, "Modules (enabled)", {
    { "Buy", mods.buy and "on" or "off" },
    { "Sell", mods.sell and "on" or "off" },
    { "Snipe", mods.snipe and "on" or "off" },
    { "Undercut", mods.undercut and "on" or "off" },
  })

  local ownedN = "—"
  pcall(function()
    if AHBridge and AHBridge.get_owned_auctions then
      local o = AHBridge.get_owned_auctions()
      if type(o) == "table" then
        ownedN = tostring(#o)
      elseif o == nil then
        ownedN = "nil"
      else
        ownedN = "?"
      end
    end
  end)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "── Owned auctions (probe) ──"
  lines[#lines + 1] = "get_owned_auctions count: " .. ownedN

  return lines
end

local function ensure_behavior(cfg)
  if cfg._behavior_ensured then
    return
  end
  cfg._behavior_ensured = true
  cfg.behavior = cfg.behavior or {}
  cfg.behavior.modules = cfg.behavior.modules or {}
  cfg.behavior.ui = cfg.behavior.ui or {}
  cfg.behavior.snipe = cfg.behavior.snipe or {}
  cfg.behavior.sell = cfg.behavior.sell or {}
  cfg.behavior.undercut = cfg.behavior.undercut or {}
  if cfg.behavior.undercut.socialRepostDelayMinSec == nil then
    cfg.behavior.undercut.socialRepostDelayMinSec = 5 * 60
  end
  if cfg.behavior.undercut.socialRepostDelayMaxSec == nil then
    cfg.behavior.undercut.socialRepostDelayMaxSec = 10 * 60
  end
  cfg.behavior.distraction = cfg.behavior.distraction or {
    enabled = true,
    extraOpenChance = 0.30,
  }
  cfg.behavior.reserves = cfg.behavior.reserves or {}
  cfg.behavior.learn = cfg.behavior.learn or {
    enabled = true,
    blend = 0.35,
    ewmaAlpha = 0.15,
    slack = 0.025,
    minSamples = 5,
  }
  cfg.behavior.scanLog = cfg.behavior.scanLog or {
    enabled = false,
    flushEveryRows = 8,
    flushDebounceSec = 2.0,
    maxFileBytes = 3145728,
  }
  cfg.behavior.ahGuard = cfg.behavior.ahGuard or {
    requireAuctionFrame = true,
    maxSearchFailStreak = 5,
    searchBackoffSeconds = 30,
  }
  cfg.behavior.debug = cfg.behavior.debug or {
    verbose = false,
    dryRun = false,
    logAuctionChat = true,
  }
  if cfg.behavior.debug.scheduleDiag == nil then
    cfg.behavior.debug.scheduleDiag = false
  end
  if cfg.behavior.debug.scheduleDiagMinIntervalSec == nil then
    cfg.behavior.debug.scheduleDiagMinIntervalSec = 1.5
  end
  if cfg.behavior.debug.errorLogThrottleSec == nil then
    cfg.behavior.debug.errorLogThrottleSec = 2.0
  end
  cfg.behavior.ui.manualPauseKey = cfg.behavior.ui.manualPauseKey or 0x77
  if cfg.behavior.ui.manualPausePlaySound == nil then
    cfg.behavior.ui.manualPausePlaySound = false
  end
  cfg.patterns = cfg.patterns or {}
  if cfg.DefaultRatio == nil then
    local th = cfg.thresholds or {}
    cfg.DefaultRatio = th.defaultBuyRatio or 0.75
  end
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
  root.uiTab = root.uiTab or TAB.DASHBOARD
  root.dashScroll = root.dashScroll or 0
end

local function body_layout(root)
  local x, y, w = root.uiX, root.uiY, root.uiW
  local pad = 12
  local bx = x + pad
  local by = y + BODY_TOP + 8
  local bw = w - pad * 2
  return bx, by, bw
end

local function dash_scroll_layout(root, bx, by, bw, h)
  local scrollTop = by + DASH_ARM_BLOCK
  local scrollBottom = root.uiY + h - 10
  local scrollH = math.max(40, scrollBottom - scrollTop)
  return scrollTop, scrollH
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
  local cfg = root.Config
  if type(cfg) == "table" then
    cfg._behavior_ensured = nil
  end
  init_frame(root)
  if type(cfg) ~= "table" then
    return
  end
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
    Persistence.try_flush(root)
    if ScanLogMod and ScanLogMod.flush_now then
      Util.safe_call("ScanLog.flush_now", function()
        ScanLogMod.flush_now(root)
      end, { root = root })
    end
    return
  end

  Persistence.try_flush(root)

  local x, y, w, h = root.uiX, root.uiY, root.uiW, root.uiH
  local bx, by, bw = body_layout(root)

  if root._uiDragging and lmb then
    root.uiX = cx - (root._uiDragOffX or 0)
    root.uiY = cy - (root._uiDragOffY or 0)
  elseif not lmb then
    if root._uiDragging then
      ensure_behavior(root.Config)
      local ui = root.Config.behavior.ui
      ui.x = root.uiX
      ui.y = root.uiY
      ui.w = root.uiW
      ui.h = root.uiH
      Persistence.mark_dirty(root)
    end
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

  if root.uiTab == TAB.DASHBOARD then
    local scrollTop, scrollH = dash_scroll_layout(root, bx, by, bw, h)
    if inside(cx, cy, bx, scrollTop, bw, scrollH) then
      local wd = 0
      pcall(function()
        wd = core.get_mouse_wheel_delta()
      end)
      if wd ~= 0 then
        root.dashScroll = math.max(0, (root.dashScroll or 0) - wd * 24)
      end
    end
  end

  if click and root.uiTab == TAB.DASHBOARD then
    if inside(cx, cy, bx, by + 74, bw, 36) then
      root.isActive = not root.isActive
      if root.isActive then
        root.ManualPause = false
        root.state = root.STATE_SCANNING
        root.BotActive = true
        root.BotEnabled = true
        root.tickBuyAt = 0
        root.tickSellAt = 0
        root.tickSnipeAt = 0
        root.tickUndercutAt = 0
        root.uptimeAnchor = nil
        root.fatigueUntil = 0
      else
        root.state = root.STATE_IDLE
        root.BotActive = false
        root.BotEnabled = false
        root._timerEpoch = (root._timerEpoch or 0) + 1
        root.uptimeAnchor = nil
        root.TimeEnabled = nil
      end
    end
  end

  if root.uiTab ~= TAB.ITEMS then
    root.uiFocus = nil
  else
    IG.consume_digit_input(root)
    IG.update_items_tab(root, bx, by, bw, y + h - 10, click, cx, cy)
  end

  if root.uiTab == TAB.SETUP then
    IG.update_setup_tab(root, bx, by, bw, click, cx, cy)
  end

  local function hit_toggle(px, py, tx, ty, tw, th)
    return click and inside(px, py, tx, ty, tw, th)
  end

  local mods = cfg.behavior.modules
  if root.uiTab == TAB.BUY and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.buy = not mods.buy
    Persistence.mark_dirty(root)
  elseif root.uiTab == TAB.SELL and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.sell = not mods.sell
    Persistence.mark_dirty(root)
  elseif root.uiTab == TAB.SNIPE and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.snipe = not mods.snipe
    Persistence.mark_dirty(root)
  elseif root.uiTab == TAB.UNDERCUT and hit_toggle(cx, cy, bx, by, bw, 30) then
    mods.undercut = not mods.undercut
    Persistence.mark_dirty(root)
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
      core.graphics.text_2d(TAB_LABELS[i], V(tx + 4, tabY + 6), 12, C(230, 232, 240, 255))
    end

    local mods = root.Config.behavior.modules

    if root.uiTab == TAB.DASHBOARD then
      local armed = root.isActive and "ARMED" or "DISARMED"
      core.graphics.text_2d("Quick: " .. armed, V(bx, by), 14, C(200, 220, 255, 255))
      core.graphics.text_2d("Scroll wheel on dashboard feed · UI: grave/backtick · Manual pause: F8 (Setup)", V(bx, by + 18), 11, C(150, 155, 175, 255))
      draw_button(bx, by + 74, bw, 36, root.isActive and "Disarm bot" or "Arm bot")

      local scrollTop, scrollH = dash_scroll_layout(root, bx, by, bw, h)
      core.graphics.rect_2d_filled(V(bx, scrollTop), bw, scrollH, C(12, 12, 18, 200), 4)
      core.graphics.rect_2d(V(bx, scrollTop), bw, scrollH, C(55, 60, 80, 200), 1, 4)

      local lines = build_dashboard_lines(root)
      local totalH = #lines * DASH_LINE_H + 8
      local maxScroll = math.max(0, totalH - scrollH)
      root.dashScroll = math.min(root.dashScroll or 0, maxScroll)

      pcall(function()
        core.graphics.scissor_push(bx, scrollTop, bw, scrollH)
      end)
      local sy = scrollTop + 6 - (root.dashScroll or 0)
      for i = 1, #lines do
        local line = lines[i]
        if sy + DASH_LINE_H >= scrollTop and sy <= scrollTop + scrollH then
          if line ~= "" then
            local col = C(200, 205, 220, 255)
            if #line >= 2 and line:sub(1, 2) == "──" then
              col = C(140, 180, 255, 255)
            end
            core.graphics.text_2d(line, V(bx + 6, sy), 11, col)
          end
        end
        sy = sy + DASH_LINE_H
      end
      pcall(function()
        core.graphics.scissor_pop()
      end)

      if maxScroll > 0 then
        core.graphics.text_2d(string.format("Scroll %.0f / %.0f px", root.dashScroll or 0, maxScroll), V(bx + bw - 120, scrollTop + scrollH - 14), 10, C(120, 125, 145, 255))
      end
    elseif root.uiTab == TAB.BUY then
      draw_toggle(bx, by, bw, 30, "Enable buy scanner", mods.buy)
      core.graphics.text_2d("Item IDs and ratios: Items tab. Gold, pacing, fatigue: Setup tab.", V(bx, by + 36), 12, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.SELL then
      draw_toggle(bx, by, bw, 30, "Enable sell / lister", mods.sell)
      core.graphics.text_2d("Uses main item list when sell watchlist is empty. Stack size in Setup.", V(bx, by + 36), 12, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.SNIPE then
      draw_toggle(bx, by, bw, 30, "Enable snipe", mods.snipe)
      core.graphics.text_2d("Uses main item list when snipe watchlist is empty. Cap in Setup.", V(bx, by + 36), 12, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.UNDERCUT then
      draw_toggle(bx, by, bw, 30, "Enable undercut / relist", mods.undercut)
      core.graphics.text_2d("Prefers owned-auctions API. Undercut step: Setup tab.", V(bx, by + 36), 12, C(170, 175, 195, 255))
    elseif root.uiTab == TAB.ITEMS then
      IG.render_items_tab(root, bx, by, bw, y + h - 10, C, V, draw_button)
    elseif root.uiTab == TAB.SETUP then
      IG.render_setup_tab(root, bx, by, bw, C, V, draw_toggle, draw_button)
    end
  end)
end

function UI.install(root)
  if root._science_ui_installed then
    return
  end
  root._science_ui_installed = true
  root._uiLmbPrev = false
  root._uiTogglePrev = false
  if type(root.Config) == "table" then
    root.Config._behavior_ensured = nil
  end
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

return UI
