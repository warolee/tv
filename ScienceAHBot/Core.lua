--[[ ScienceAHBot — engine: LIFO index 1, randomized fatigue, module orchestration. ]]

local ScienceAHBot = {}
local AHGuard = require("ScienceAHBot/AHGuard")
local SafetyH = require("ScienceAHBot/Safety")
local TSMH = require("ScienceAHBot/TSM_Helper")
local ModBuy = require("ScienceAHBot/ModBuy")
local ModSell = require("ScienceAHBot/ModSell")
local ModSnipe = require("ScienceAHBot/ModSnipe")
local ModUndercut = require("ScienceAHBot/ModUndercut")

local IZI = (function()
  local ok, mod = pcall(require, "common/izi_sdk")
  return ok and mod or nil
end)()

local function now_s()
  if IZI and IZI.now then
    local ok, t = pcall(IZI.now)
    if ok and type(t) == "number" then
      return t
    end
  end
  if GetTime then
    return GetTime()
  end
  return 0
end

local function rand_between(cfg, loKey, hiKey, fallbackLo, fallbackHi)
  local lo = cfg[loKey] or fallbackLo
  local hi = cfg[hiKey] or fallbackHi
  if hi < lo then
    lo, hi = hi, lo
  end
  return lo + math.random() * (hi - lo)
end

function ScienceAHBot.install(root)
  if root._science_core_installed then
    return
  end
  root._science_core_installed = true

  root.STATE_SCANNING = "STATE_SCANNING"
  root.STATE_IDLE = "STATE_IDLE"
  root.STATE_COOLDOWN = "STATE_COOLDOWN"

  root.isActive = root.isActive or false
  root.BotActive = root.BotActive ~= false and root.isActive
  root.state = root.state or root.STATE_IDLE
  root.apiCooldownUntil = root.apiCooldownUntil or 0
  root.uptimeAnchor = root.uptimeAnchor or nil
  root.fatigueUntil = root.fatigueUntil or 0
  root._workSegmentStart = root._workSegmentStart or nil
  root._workSegmentLimitSec = root._workSegmentLimitSec or nil

  root.tickBuyAt = root.tickBuyAt or 0
  root.tickSellAt = root.tickSellAt or 0
  root.tickSnipeAt = root.tickSnipeAt or 0
  root.tickUndercutAt = root.tickUndercutAt or 0

  root.TSM = root.TSM or TSMH

  root.GetMarketValue = function(itemID)
    return TSMH.GetMarketValue(itemID)
  end

  root.GetMarketPrice = root.GetMarketValue

  local function ensure_uptime_anchor()
    if root.isActive and not root.uptimeAnchor then
      root.uptimeAnchor = now_s()
      root.TimeEnabled = root.uptimeAnchor
    end
    if not root.isActive then
      root.uptimeAnchor = nil
      root.TimeEnabled = nil
      root._workSegmentStart = nil
      root._workSegmentLimitSec = nil
    end
    root.BotActive = root.isActive
    root.BotEnabled = root.BotActive
  end

  local function pick_new_work_limit(cfg)
    root._workSegmentLimitSec = rand_between(cfg, "fatigueWorkSecondsMin", "fatigueWorkSecondsMax", 45 * 60, 60 * 60)
  end

  local function begin_work_segment(cfg)
    local t0 = now_s()
    root._workSegmentStart = t0
    root.SessionStartTime = t0
    pick_new_work_limit(cfg)
  end

  local function check_fatigue(cfg)
    if not root.isActive or root.state ~= root.STATE_SCANNING then
      return
    end
    if not root._workSegmentStart or not root._workSegmentLimitSec then
      begin_work_segment(cfg)
      return
    end
    local tnow = now_s()
    if tnow - root._workSegmentStart < root._workSegmentLimitSec then
      return
    end

    local restSec = rand_between(cfg, "fatigueRestSecondsMin", "fatigueRestSecondsMax", 8 * 60, 12 * 60)
    root.state = root.STATE_IDLE
    root.fatigueUntil = tnow + restSec
    root._workSegmentStart = nil
    root._workSegmentLimitSec = nil
    root.uptimeAnchor = nil
    root.SessionStartTime = nil

    local restMin = string.format("%.1f", restSec / 60.0)
    pcall(function()
      if core and core.log then
        core.log(string.format("[ScienceAHBot] Fatigue break: IDLE for ~%s min (behavioral rest). Resuming scans after.", restMin))
      end
    end)
    pcall(function()
      print(string.format("|cff00ccffScienceAHBot|r Fatigue: entering break (~%s min). Session paused.", restMin))
    end)
  end

  local function on_tick()
    pcall(function()
      local cfg = root.Config
      if type(cfg) ~= "table" then
        return
      end

      local tnow = now_s()

      pcall(function()
        local ScanLog = require("ScienceAHBot/ScanLog")
        ScanLog.tick_flush(root, tnow)
      end)

      ensure_uptime_anchor()

      pcall(function()
        AHGuard.tick_manual_pause_key(root)
      end)

      if not root.isActive then
        return
      end

      if root.state == root.STATE_COOLDOWN then
        if tnow >= (root.apiCooldownUntil or 0) then
          root.state = root.STATE_SCANNING
          begin_work_segment(cfg)
          root.uptimeAnchor = tnow
          root.TimeEnabled = root.uptimeAnchor
        else
          return
        end
      end

      if root.state == root.STATE_IDLE then
        if root.fatigueUntil and tnow < root.fatigueUntil then
          return
        end
        root.fatigueUntil = 0
        root.state = root.STATE_SCANNING
        begin_work_segment(cfg)
        root.uptimeAnchor = tnow
        root.TimeEnabled = root.uptimeAnchor
        pcall(function()
          if core and core.log then
            core.log("[ScienceAHBot] Fatigue break ended; resuming scan activity.")
          end
        end)
        pcall(function()
          print("|cff00ccffScienceAHBot|r Fatigue break ended; resuming scans.")
        end)
      end

      if root.state ~= root.STATE_SCANNING then
        return
      end

      check_fatigue(cfg)

      if root.state ~= root.STATE_SCANNING then
        return
      end

      if tnow < (root.apiCooldownUntil or 0) then
        return
      end

      if AHGuard.is_manual_paused(root) then
        return
      end

      if AHGuard.is_search_backoff(root, tnow) then
        pcall(function()
          ModUndercut.tick_lazy_queue_only(root, tnow)
        end)
        return
      end

      pcall(function()
        SafetyH.tick_distraction(root, tnow)
      end)

      if (root._distractionPauseAHUntil or 0) > tnow then
        return
      end

      pcall(function()
        ModBuy.tick(root, tnow)
      end)
      pcall(function()
        ModSell.tick(root, tnow)
      end)
      pcall(function()
        ModSnipe.tick(root, tnow)
      end)
      pcall(function()
        ModUndercut.tick(root, tnow)
      end)
    end)
  end

  pcall(function()
    core.register_on_update_callback(on_tick)
  end)
end

return ScienceAHBot
