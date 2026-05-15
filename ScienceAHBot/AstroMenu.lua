--[[ core.menu widgets for Astro custom window; bidirectional sync with root.Config + Persistence. ]]

-- module-local, returned as the public interface
local M = {}

local Persistence = require("Persistence")

local function id(s)
  return "science_ah_bot_" .. s
end

local function menu_slider(a, b, c, d)
  if core and core.menu and core.menu.slider_int then
    return core.menu.slider_int(a, b, c, d)
  end
  return nil
end

local function menu_cb(def, i)
  if core and core.menu and core.menu.checkbox then
    return core.menu.checkbox(def, i)
  end
  return nil
end

--- Create ghost menu controls (may be nil if core.menu is unavailable).
function M.create(root)
  if not (core and core.menu) then
    return nil
  end
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return nil
  end
  local b = cfg.behavior
  b = type(b) == "table" and b or {}
  local th = cfg.thresholds or {}
  local j = cfg.jitter or {}
  local sn = b.snipe or {}
  local sl = b.sell or {}
  local uc = b.undercut or {}
  local L = b.learn or {}
  local ah = b.ahGuard or {}
  local dbg = b.debug or {}
  local slog = b.scanLog or {}
  local mods = b.modules or {}
  local ui = b.ui or {}

  local gold_k = math.floor(((b.reserves and b.reserves.minGoldCopper) or 0) / 10000)
  gold_k = math.max(0, math.min(99999, gold_k))

  return {
    mod_buy = menu_cb(mods.buy ~= false, id("mod_buy")),
    mod_sell = menu_cb(mods.sell == true, id("mod_sell")),
    mod_snipe = menu_cb(mods.snipe == true, id("mod_snipe")),
    mod_undercut = menu_cb(mods.undercut == true, id("mod_undercut")),
    arm = menu_cb(root.isActive == true, id("arm")),

    gold_k = menu_slider(0, 99999, gold_k, id("gold_k")),
    default_buy_pct = menu_slider(5, 99, math.floor((th.defaultBuyRatio or 0.75) * 100 + 0.5), id("def_buy_pct")),
    snipe_max_pct = menu_slider(5, 99, math.floor((sn.maxBuyRatio or 0.52) * 100 + 0.5), id("snipe_max_pct")),
    post_stack = menu_slider(1, 200, sl.postStackSize or 20, id("post_stack")),
    scan_mean_10 = menu_slider(10, 120, math.floor(((j.scanMeanSeconds or 5) * 10) + 0.5), id("scan_mean_10")),
    scan_min_10 = menu_slider(5, 6000, math.floor(((j.scanMinDelay or 3.5) * 10) + 0.5), id("scan_min_10")),
    scan_max_10 = menu_slider(10, 6000, math.floor(((j.scanMaxDelay or 7) * 10) + 0.5), id("scan_max_10")),

    fatigue_work_min_m = menu_slider(5, 120, math.floor((cfg.fatigueWorkSecondsMin or 2700) / 60 + 0.5), id("fw_min_m")),
    fatigue_work_max_m = menu_slider(10, 180, math.floor((cfg.fatigueWorkSecondsMax or 3600) / 60 + 0.5), id("fw_max_m")),
    fatigue_rest_min_m = menu_slider(3, 45, math.floor((cfg.fatigueRestSecondsMin or 480) / 60 + 0.5), id("fr_min_m")),
    fatigue_rest_max_m = menu_slider(5, 60, math.floor((cfg.fatigueRestSecondsMax or 720) / 60 + 0.5), id("fr_max_m")),

    undercut_cu = menu_slider(1, 999999, math.min(999999, uc.undercutCopper or 1), id("undercut_cu")),
    learn_en = menu_cb(L.enabled ~= false, id("learn_en")),
    blend_pct = menu_slider(0, 100, math.floor((L.blend or 0.35) * 100 + 0.5), id("blend_pct")),
    min_samples = menu_slider(2, 80, L.minSamples or 5, id("min_samples")),
    slack_1000 = menu_slider(0, 150, math.floor((L.slack or 0.025) * 1000 + 0.5), id("slack_1000")),
    ewma_pct = menu_slider(4, 50, math.floor((L.ewmaAlpha or 0.15) * 100 + 0.5), id("ewma_pct")),

    ah_req = menu_cb(ah.requireAuctionFrame ~= false, id("ah_req")),
    dbg_verbose = menu_cb(dbg.verbose == true, id("dbg_v")),
    dbg_dry = menu_cb(dbg.dryRun == true, id("dbg_dry")),
    dbg_chat = menu_cb(dbg.logAuctionChat ~= false, id("dbg_chat")),

    search_streak = menu_slider(2, 20, ah.maxSearchFailStreak or 5, id("search_streak")),
    backoff_s = menu_slider(5, 300, ah.searchBackoffSeconds or 30, id("backoff_s")),
    scanlog_en = menu_cb(slog.enabled == true, id("scanlog_en")),
    ui_scale_pct = menu_slider(75, 200, math.floor(((ui.scale or 1.25) * 100) + 0.5), id("ui_scale_pct")),
  }
end

local function get_cb_state(el)
  if not el then
    return false
  end
  local ok, v = pcall(function()
    if el.get_state then
      return el:get_state()
    end
    if el.get then
      return el:get()
    end
    return false
  end)
  return ok and v == true
end

local function set_cb(el, st)
  if not el then
    return
  end
  pcall(function()
    if el.set_state then
      el:set_state(st)
    elseif el.set then
      el:set(st)
    end
  end)
end

local function menu_signature(m)
  if not m then
    return ""
  end
  local parts = {}
  for k, el in pairs(m) do
    if type(el) == "table" and el.get then
      local ok, g = pcall(function()
        return el:get()
      end)
      parts[#parts + 1] = k .. "=" .. tostring(ok and g or 0)
    elseif type(el) == "table" and el.get_state then
      local ok, g = pcall(function()
        return el:get_state()
      end)
      parts[#parts + 1] = k .. "=" .. tostring(ok and g or false)
    end
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

function M.sync_menu_to_config(root, m)
  if not m or type(root.Config) ~= "table" then
    return
  end
  local cfg = root.Config
  cfg.behavior = cfg.behavior or {}
  local b = cfg.behavior
  b.modules = b.modules or {}
  b.reserves = b.reserves or {}
  cfg.thresholds = cfg.thresholds or {}
  local th = cfg.thresholds
  cfg.jitter = cfg.jitter or {}
  local j = cfg.jitter
  b.snipe = b.snipe or {}
  local sn = b.snipe
  b.sell = b.sell or {}
  local sl = b.sell
  b.undercut = b.undercut or {}
  local uc = b.undercut
  b.learn = b.learn or {}
  local L = b.learn
  b.ahGuard = b.ahGuard or {}
  local ah = b.ahGuard
  b.debug = b.debug or {}
  local dbg = b.debug
  b.scanLog = b.scanLog or {}
  local slog = b.scanLog
  b.ui = b.ui or {}

  b.modules.buy = get_cb_state(m.mod_buy)
  b.modules.sell = get_cb_state(m.mod_sell)
  b.modules.snipe = get_cb_state(m.mod_snipe)
  b.modules.undercut = get_cb_state(m.mod_undercut)

  if m.gold_k and m.gold_k.get then
    local ok, v = pcall(function()
      return m.gold_k:get()
    end)
    if ok and type(v) == "number" then
      b.reserves.minGoldCopper = math.max(0, math.min(999999999, v * 10000))
    end
  end

  local function Sget(slider)
    if not slider or not slider.get then
      return nil
    end
    local ok, v = pcall(function()
      return slider:get()
    end)
    if ok and type(v) == "number" then
      return v
    end
    return nil
  end

  local v
  v = Sget(m.default_buy_pct)
  if v then
    th.defaultBuyRatio = math.max(0.05, math.min(0.99, v / 100))
  end
  v = Sget(m.snipe_max_pct)
  if v then
    sn.maxBuyRatio = math.max(0.05, math.min(0.99, v / 100))
  end
  v = Sget(m.post_stack)
  if v then
    sl.postStackSize = math.max(1, math.min(200, v))
  end
  v = Sget(m.scan_mean_10)
  if v then
    j.scanMeanSeconds = math.max(0.5, math.min(60, v / 10))
  end
  v = Sget(m.scan_min_10)
  if v then
    j.scanMinDelay = math.max(0.5, math.min(600, v / 10))
  end
  v = Sget(m.scan_max_10)
  if v then
    j.scanMaxDelay = math.max(1, math.min(600, v / 10))
  end

  v = Sget(m.fatigue_work_min_m)
  if v then
    cfg.fatigueWorkSecondsMin = math.max(60, math.min(7200, v * 60))
  end
  v = Sget(m.fatigue_work_max_m)
  if v then
    cfg.fatigueWorkSecondsMax = math.max(60, math.min(7200, v * 60))
  end
  v = Sget(m.fatigue_rest_min_m)
  if v then
    cfg.fatigueRestSecondsMin = math.max(60, math.min(3600, v * 60))
  end
  v = Sget(m.fatigue_rest_max_m)
  if v then
    cfg.fatigueRestSecondsMax = math.max(60, math.min(3600, v * 60))
  end

  v = Sget(m.undercut_cu)
  if v then
    uc.undercutCopper = math.max(1, math.min(999999, v))
  end

  L.enabled = get_cb_state(m.learn_en)
  v = Sget(m.blend_pct)
  if v then
    L.blend = math.max(0, math.min(1, v / 100))
  end
  v = Sget(m.min_samples)
  if v then
    L.minSamples = math.max(2, math.min(80, v))
  end
  v = Sget(m.slack_1000)
  if v then
    L.slack = math.max(0, math.min(0.15, v / 1000))
  end
  v = Sget(m.ewma_pct)
  if v then
    L.ewmaAlpha = math.max(0.04, math.min(0.5, v / 100))
  end

  ah.requireAuctionFrame = get_cb_state(m.ah_req)
  dbg.verbose = get_cb_state(m.dbg_verbose)
  dbg.dryRun = get_cb_state(m.dbg_dry)
  dbg.logAuctionChat = get_cb_state(m.dbg_chat)

  v = Sget(m.search_streak)
  if v then
    ah.maxSearchFailStreak = math.max(2, math.min(20, v))
  end
  v = Sget(m.backoff_s)
  if v then
    ah.searchBackoffSeconds = math.max(5, math.min(300, v))
  end
  slog.enabled = get_cb_state(m.scanlog_en)

  v = Sget(m.ui_scale_pct)
  if v then
    b.ui.scale = math.max(0.75, math.min(2, v / 100))
    root._uiScale = b.ui.scale
  end

  --- Arm checkbox drives runtime arm state.
  local armed = get_cb_state(m.arm)
  if armed ~= root.isActive then
    root.isActive = armed
    if armed then
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

  if j.scanMinDelay > j.scanMaxDelay then
    j.scanMaxDelay = j.scanMinDelay
  end
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

  local sig = menu_signature(m)
  if sig ~= root._astro_menu_sig then
    root._astro_menu_sig = sig
    Persistence.mark_dirty(root)
  end
end

--- Push runtime / file config into menu widget state (after load or external changes).
function M.sync_config_to_menu(root, m)
  if not m or type(root.Config) ~= "table" then
    return
  end
  local cfg = root.Config
  local b = cfg.behavior or {}
  local th = cfg.thresholds or {}
  local j = cfg.jitter or {}
  local sn = (b.snipe) or {}
  local sl = (b.sell) or {}
  local uc = (b.undercut) or {}
  local L = (b.learn) or {}
  local ah = (b.ahGuard) or {}
  local dbg = (b.debug) or {}
  local slog = (b.scanLog) or {}
  local mods = (b.modules) or {}
  local ui = (b.ui) or {}

  set_cb(m.mod_buy, mods.buy ~= false)
  set_cb(m.mod_sell, mods.sell == true)
  set_cb(m.mod_snipe, mods.snipe == true)
  set_cb(m.mod_undercut, mods.undercut == true)
  set_cb(m.arm, root.isActive == true)

  local function Sset(sl, val)
    if sl and sl.set and type(val) == "number" then
      pcall(function()
        sl:set(math.floor(val + 0.5))
      end)
    end
  end

  Sset(m.gold_k, math.floor(((b.reserves and b.reserves.minGoldCopper) or 0) / 10000))
  Sset(m.default_buy_pct, math.floor((th.defaultBuyRatio or 0.75) * 100 + 0.5))
  Sset(m.snipe_max_pct, math.floor((sn.maxBuyRatio or 0.52) * 100 + 0.5))
  Sset(m.post_stack, sl.postStackSize or 20)
  Sset(m.scan_mean_10, math.floor(((j.scanMeanSeconds or 5) * 10) + 0.5))
  Sset(m.scan_min_10, math.floor(((j.scanMinDelay or 3.5) * 10) + 0.5))
  Sset(m.scan_max_10, math.floor(((j.scanMaxDelay or 7) * 10) + 0.5))
  Sset(m.fatigue_work_min_m, math.floor((cfg.fatigueWorkSecondsMin or 2700) / 60 + 0.5))
  Sset(m.fatigue_work_max_m, math.floor((cfg.fatigueWorkSecondsMax or 3600) / 60 + 0.5))
  Sset(m.fatigue_rest_min_m, math.floor((cfg.fatigueRestSecondsMin or 480) / 60 + 0.5))
  Sset(m.fatigue_rest_max_m, math.floor((cfg.fatigueRestSecondsMax or 720) / 60 + 0.5))
  Sset(m.undercut_cu, math.min(999999, uc.undercutCopper or 1))
  set_cb(m.learn_en, L.enabled ~= false)
  Sset(m.blend_pct, math.floor((L.blend or 0.35) * 100 + 0.5))
  Sset(m.min_samples, L.minSamples or 5)
  Sset(m.slack_1000, math.floor((L.slack or 0.025) * 1000 + 0.5))
  Sset(m.ewma_pct, math.floor((L.ewmaAlpha or 0.15) * 100 + 0.5))
  set_cb(m.ah_req, ah.requireAuctionFrame ~= false)
  set_cb(m.dbg_verbose, dbg.verbose == true)
  set_cb(m.dbg_dry, dbg.dryRun == true)
  set_cb(m.dbg_chat, dbg.logAuctionChat ~= false)
  Sset(m.search_streak, ah.maxSearchFailStreak or 5)
  Sset(m.backoff_s, ah.searchBackoffSeconds or 30)
  set_cb(m.scanlog_en, slog.enabled == true)
  Sset(m.ui_scale_pct, math.floor(((ui.scale or 1.25) * 100) + 0.5))
end

return M
