--[[
  ScienceAHBot — TSM pricing, scan pacing, IZI AH execution, fatigue.
]]

local AH_Bot = {}

local function require_izi()
  local ok, mod = pcall(require, "common/izi_sdk")
  if ok then
    return mod
  end
  return nil
end

--- Box–Muller Gaussian sample (independent of IZI for predictability).
local function gaussian(mean, std)
  local u1 = math.max(math.random(), 1e-12)
  local u2 = math.random()
  local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
  return mean + z0 * std
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

local function next_gaussian_delay(cfg, fieldPrefix)
  local j = cfg.jitter or {}
  if fieldPrefix == "scan" then
    local mean = j.scanMeanSeconds or 5.0
    local std = j.scanStdSeconds or 0.65
    local v = gaussian(mean, std)
    return clamp(v, j.scanMinDelay or 3.5, j.scanMaxDelay or 7.0)
  end
  local mean = j.cognitiveMeanSeconds or 1.05
  local std = j.cognitiveStdSeconds or 0.12
  local v = gaussian(mean, std)
  return clamp(v, j.cognitiveMinDelay or 0.7, j.cognitiveMaxDelay or 1.4)
end

---@param itemID integer
---@return number|nil
function AH_Bot.GetMarketPrice(itemID)
  local itemString = "i:" .. tostring(itemID)
  if not _G.TSM_API or not TSM_API.GetCustomPriceValue then
    return nil
  end
  local ok, value = pcall(TSM_API.GetCustomPriceValue, "DBMarket", itemString)
  if not ok or value == nil then
    return nil
  end
  local n = tonumber(value)
  if not n or n <= 0 then
    return nil
  end
  return n
end

local function get_buy_ratio(cfg)
  local direct = cfg.buyRatio
  if type(direct) == "number" and direct > 0 then
    return direct
  end
  local t = cfg.thresholds or {}
  return t.defaultBuyRatio or 0.75
end

local function get_izi_ah(IZI)
  if not IZI then
    return nil
  end
  if IZI.AH then
    return IZI.AH
  end
  if IZI.ah then
    return IZI.ah
  end
  return nil
end

local function izi_ah_call(name, ...)
  local IZI = require_izi()
  local AH = get_izi_ah(IZI)
  if not AH or not AH[name] then
    return false, nil
  end
  return pcall(AH[name], ...)
end

local function search_for_item(itemID)
  local ok, res = izi_ah_call("SearchForItem", itemID)
  if not ok then
    return nil
  end
  return res
end

local function place_bid_from_first_result(first)
  local ok = select(1, izi_ah_call("PlaceBid", 1))
  if ok then
    return
  end
  if type(first) == "table" then
    izi_ah_call("PlaceBid", first)
  end
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
  root.nextScanAt = root.nextScanAt or 0
  root.watchlistIndex = root.watchlistIndex or 1
  root.uptimeAnchor = root.uptimeAnchor or nil
  root.fatigueUntil = root.fatigueUntil or 0

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

  local function schedule_after(delay, fn)
    local izi = require_izi()
    if izi and izi.after then
      pcall(izi.after, delay, function()
        pcall(fn)
      end)
    else
      pcall(fn)
    end
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

      if tnow < (root.nextScanAt or 0) then
        return
      end

      local list = cfg.watchlist or {}
      if #list == 0 then
        root.nextScanAt = tnow + 5
        return
      end

      root.watchlistIndex = root.watchlistIndex or 1
      if root.watchlistIndex > #list then
        root.watchlistIndex = 1
      end

      local itemID = list[root.watchlistIndex]
      root.watchlistIndex = root.watchlistIndex + 1

      local tsm = AH_Bot.GetMarketPrice(itemID)
      local maxBuy = tsm and (tsm * get_buy_ratio(cfg)) or nil

      local results = nil
      pcall(function()
        results = search_for_item(itemID)
      end)

      local first = results and results[1] or nil
      local price = nil
      if type(first) == "table" then
        price = first.buyoutPrice or first.buyout or first.unitPrice or first.price or first.minPrice
      end

      if results and first and type(price) == "number" and maxBuy and price <= maxBuy then
        local cognitive = next_gaussian_delay(cfg, "cognitive")
        pcall(function()
          schedule_after(cognitive, function()
            pcall(function()
              place_bid_from_first_result(first)
            end)
          end)
        end)
      end

      root.nextScanAt = tnow + next_gaussian_delay(cfg, "scan")
    end)
  end

  root.GetMarketPrice = function(itemID)
    return AH_Bot.GetMarketPrice(itemID)
  end

  pcall(function()
    core.register_on_update_callback(on_tick)
  end)
end

return AH_Bot
