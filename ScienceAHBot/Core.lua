--[[ ScienceAHBot — engine: state machine, fatigue, API cool-down, module tick orchestration. ]]

local AH_Bot = {}
local TSM = require("ScienceAHBot/TSM")
local ModBuy = require("ScienceAHBot/ModBuy")
local ModSell = require("ScienceAHBot/ModSell")
local ModSnipe = require("ScienceAHBot/ModSnipe")
local ModUndercut = require("ScienceAHBot/ModUndercut")

local function require_izi()
  local ok, mod = pcall(require, "common/izi_sdk")
  if ok then
    return mod
  end
  return nil
end

local function now_s()
  local izi = require_izi()
  if izi and izi.now then
    local ok, t = pcall(izi.now)
    if ok and type(t) == "number" then
      return t
    end
  end
  if GetTime then
    return GetTime()
  end
  return 0
end

function AH_Bot.install(root)
  if root._science_core_installed then
    return
  end
  root._science_core_installed = true

  root.STATE_SCANNING = "STATE_SCANNING"
  root.STATE_IDLE = "STATE_IDLE"
  root.STATE_COOLDOWN = "STATE_COOLDOWN"

  root.isActive = root.isActive or false
  root.state = root.state or root.STATE_IDLE
  root.apiCooldownUntil = root.apiCooldownUntil or 0
  root.uptimeAnchor = root.uptimeAnchor or nil
  root.fatigueUntil = root.fatigueUntil or 0

  root.tickBuyAt = root.tickBuyAt or 0
  root.tickSellAt = root.tickSellAt or 0
  root.tickSnipeAt = root.tickSnipeAt or 0
  root.tickUndercutAt = root.tickUndercutAt or 0

  root.GetMarketPrice = function(itemID)
    return TSM.GetMarketPrice(itemID)
  end

  local function ensure_uptime_anchor()
    if root.isActive and not root.uptimeAnchor then
      root.uptimeAnchor = now_s()
      root.TimeEnabled = root.uptimeAnchor
    end
    if not root.isActive then
      root.uptimeAnchor = nil
      root.TimeEnabled = nil
    end
  end

  local function check_fatigue(cfg)
    local limit = cfg.fatigueUptimeSeconds or (60 * 60)
    if not root.isActive or root.state ~= root.STATE_SCANNING then
      return
    end
    if not root.uptimeAnchor then
      return
    end
    if now_s() - root.uptimeAnchor >= limit then
      root.state = root.STATE_IDLE
      root.fatigueUntil = now_s() + (cfg.fatigueRestSeconds or (10 * 60))
      root.uptimeAnchor = nil
      pcall(function()
        if core and core.log then
          core.log("[ScienceAHBot] Fatigue: resting for " .. tostring(cfg.fatigueRestSeconds or 600) .. "s")
        end
      end)
    end
  end

  local function on_tick()
    pcall(function()
      local cfg = root.Config
      if type(cfg) ~= "table" then
        return
      end

      ensure_uptime_anchor()

      if not root.isActive then
        return
      end

      local tnow = now_s()

      if root.state == root.STATE_COOLDOWN then
        if tnow >= (root.apiCooldownUntil or 0) then
          root.state = root.STATE_SCANNING
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
        root.uptimeAnchor = tnow
        root.TimeEnabled = root.uptimeAnchor
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

return AH_Bot
