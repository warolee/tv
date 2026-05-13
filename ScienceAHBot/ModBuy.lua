--[[ ScienceAHBot — Buy scanner: watchlist vs TSM, LIFO bid via IZI. ]]

local AH_Bot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local TSM = require("ScienceAHBot/TSM")
local Timing = require("ScienceAHBot/Timing")

local function get_buy_ratio(cfg)
  local direct = cfg.buyRatio
  if type(direct) == "number" and direct > 0 then
    return direct
  end
  local t = cfg.thresholds or {}
  return t.defaultBuyRatio or 0.75
end

local function schedule_after(delay, fn)
  local ok, izi = pcall(require, "common/izi_sdk")
  if ok and izi and izi.after then
    pcall(izi.after, delay, function()
      pcall(fn)
    end)
  else
    pcall(fn)
  end
end

local function first_row_price(first)
  if type(first) ~= "table" then
    return nil
  end
  return first.buyoutPrice or first.buyout or first.unitPrice or first.price or first.minPrice
end

function AH_Bot.tick(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.buy then
    return
  end

  local reserves = cfg.behavior.reserves
  if reserves and reserves.minGoldCopper then
    local okg, copper = pcall(function()
      return core.inventory.get_gold()
    end)
    if okg and type(copper) == "number" and copper < reserves.minGoldCopper then
      root.tickBuyAt = tnow + 3
      return
    end
  end

  root.tickBuyAt = root.tickBuyAt or 0
  if tnow < root.tickBuyAt then
    return
  end

  local list = cfg.watchlist or {}
  if #list == 0 then
    root.tickBuyAt = tnow + 5
    return
  end

  root.buyListIndex = root.buyListIndex or 1
  if root.buyListIndex > #list then
    root.buyListIndex = 1
  end

  local itemID = list[root.buyListIndex]
  root.buyListIndex = root.buyListIndex + 1

  local tsm = TSM.GetMarketPrice(itemID)
  local maxBuy = tsm and (tsm * get_buy_ratio(cfg)) or nil

  local results = nil
  pcall(function()
    results = Bridge.search_for_item(itemID)
  end)

  local first = results and results[1] or nil
  local price = first_row_price(first)

  if results and first and type(price) == "number" and maxBuy and price <= maxBuy then
    local cognitive = Timing.next_delay(cfg, "cognitive")
    pcall(function()
      schedule_after(cognitive, function()
        pcall(function()
          Bridge.place_bid_lifo(first)
        end)
      end)
    end)
  end

  root.tickBuyAt = tnow + Timing.next_delay(cfg, "scan")
end

return AH_Bot
