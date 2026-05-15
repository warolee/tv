--[[ Build dashboard text lines for ScienceAHBot (shared by legacy UI and Astro window). ]]

-- module-local, returned as the public interface
local M = {}

local IZI_mod = (function()
  local ok, mod = pcall(require, "common/izi_sdk")
  return ok and mod or nil
end)()

local PreflightMod = nil
pcall(function()
  PreflightMod = require("Preflight")
end)
local AHGuardDash = nil
pcall(function()
  AHGuardDash = require("AHGuard")
end)

local AHBridge = nil
pcall(function()
  AHBridge = require("AHBridge")
end)

local PSMenuDash = (function()
  local ok, m = pcall(require, "PSMenu")
  return ok and m or nil
end)()

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

function M.build_lines(root)
  local cfg = root.Config or {}
  local b = cfg.behavior or {}
  local mods = b.modules or {}
  local now = now_s()
  local lines = {}

  lines[#lines + 1] = "ScienceAHBot · live snapshot (Astro UI)"
  lines[#lines + 1] = string.format("Clock: %.2f  (izi.now / GetTime)", now)
  lines[#lines + 1] = "Persists to scripts_data/ScienceAHBot/user_settings.lua"

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
  local psMaster = "—"
  if PSMenuDash and PSMenuDash.is_master_enabled then
    psMaster = PSMenuDash.is_master_enabled(root) and "on (PS menu)" or "OFF (PS menu)"
  end

  push_lines(lines, "Runtime", {
    { "PS menu master automation", psMaster },
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

return M
