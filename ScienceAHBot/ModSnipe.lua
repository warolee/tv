--[[ ScienceAHBot — Snipe: LIFO row 1, TSM + adaptive ratio, faster scans. ]]

local ScienceAHBot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local Timing = require("ScienceAHBot/Timing")
local Learn = require("ScienceAHBot/Learn")
local ScanLog = require("ScienceAHBot/ScanLog")

local function first_row_price(first)
  if type(first) ~= "table" then
    return nil
  end
  if first.buyoutPrice or first.buyout then
    return first.buyoutPrice or first.buyout
  end
  return first.unitPrice or first.price or first.minPrice
end

function ScienceAHBot.tick(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.snipe then
    return
  end

  local TSM = root.TSM
  if not TSM or not TSM.GetMarketValue then
    return
  end

  local reserves = cfg.behavior.reserves
  if reserves and reserves.minGoldCopper then
    local okg, copper = pcall(function()
      return core.inventory.get_gold()
    end)
    if okg and type(copper) == "number" and copper < reserves.minGoldCopper then
      root.tickSnipeAt = tnow + 2
      return
    end
  end

  root.tickSnipeAt = root.tickSnipeAt or 0
  if tnow < root.tickSnipeAt then
    return
  end

  local s = cfg.behavior.snipe or {}
  local list = s.watchlist
  if not list or #list == 0 then
    list = TSM.GetWatchlistIds(cfg)
  end
  if #list == 0 then
    root.tickSnipeAt = tnow + 3
    return
  end

  root.snipeListIndex = root.snipeListIndex or 1
  if root.snipeListIndex > #list then
    root.snipeListIndex = 1
  end

  local itemID = list[root.snipeListIndex]
  root.snipeListIndex = root.snipeListIndex + 1

  local tsm = nil
  pcall(function()
    tsm = TSM.GetMarketValue(itemID)
  end)
  local cap = s.maxBuyRatio or 0.55
  local itemR = TSM.GetItemRatio(itemID, cfg)
  local baseR = math.min(cap, itemR)

  local results = nil
  pcall(function()
    results = Bridge.search_for_item(itemID)
  end)

  local first = results and results[1] or nil
  local price = first_row_price(first)
  if s.useBuyoutOnly and type(first) == "table" then
    price = first.buyoutPrice or first.buyout or price
  end

  pcall(function()
    if tsm and type(price) == "number" and price > 0 then
      Learn.record_observation(root, itemID, price, tsm)
    end
  end)

  local effR = baseR
  pcall(function()
    effR = Learn.get_effective_ratio(root, itemID, cfg, baseR)
  end)

  local maxBuy = tsm and (tsm * effR) or nil

  local action = "unknown"
  if not tsm or tsm <= 0 then
    action = "no_tsm"
  elseif not results or (type(results) == "table" and #results == 0) then
    action = "no_results"
  elseif not first then
    action = "no_row1"
  elseif type(price) ~= "number" or price <= 0 then
    action = "no_price"
  elseif not maxBuy then
    action = "no_buy_cap"
  elseif price > maxBuy then
    action = "skip_above_cap"
  else
    action = "bid_scheduled"
  end
  pcall(function()
    ScanLog.record(root, {
      module = "snipe",
      itemId = itemID,
      tsm = tsm,
      row1 = price,
      maxBuy = maxBuy,
      baseRatio = baseR,
      effRatio = effR,
      action = action,
    })
  end)

  if results and first and type(price) == "number" and maxBuy and price <= maxBuy then
    local think = 1.0
    pcall(function()
      if root.GetCognitiveLatency then
        local ok, v = pcall(root.GetCognitiveLatency)
        if ok and type(v) == "number" then
          think = v
        end
      end
    end)
    if root.schedule_after then
      pcall(function()
        root.schedule_after(root, think, function()
          pcall(function()
            Bridge.place_bid_lifo(first)
          end)
        end)
      end)
    end
  end

  root.tickSnipeAt = tnow + Timing.next_delay(root, cfg, "snipe_scan")
end

return ScienceAHBot
