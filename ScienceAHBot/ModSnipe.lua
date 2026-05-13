--[[ ScienceAHBot — Snipe: faster scans, tighter max buy ratio vs DBMarket. ]]

local AH_Bot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local TSM = require("ScienceAHBot/TSM")
local Timing = require("ScienceAHBot/Timing")

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
  if first.buyoutPrice or first.buyout then
    return first.buyoutPrice or first.buyout
  end
  return first.unitPrice or first.price or first.minPrice
end

function AH_Bot.tick(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.snipe then
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
    list = cfg.watchlist or {}
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

  local tsm = TSM.GetMarketPrice(itemID)
  local ratio = s.maxBuyRatio or 0.55
  local maxBuy = tsm and (tsm * ratio) or nil

  local results = nil
  pcall(function()
    results = Bridge.search_for_item(itemID)
  end)

  local first = results and results[1] or nil
  local price = first_row_price(first)
  if s.useBuyoutOnly and type(first) == "table" then
    price = first.buyoutPrice or first.buyout or price
  end

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

  root.tickSnipeAt = tnow + Timing.next_delay(cfg, "snipe_scan")
end

return AH_Bot
