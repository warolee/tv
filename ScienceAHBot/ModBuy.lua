--[[ ScienceAHBot — Buy: LIFO row 1 only, TSM threshold, cognitive latency before PlaceBid. ]]

local ScienceAHBot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local Timing = require("ScienceAHBot/Timing")

local function first_row_price(first)
  if type(first) ~= "table" then
    return nil
  end
  return first.buyoutPrice or first.buyout or first.unitPrice or first.price or first.minPrice
end

function ScienceAHBot.tick(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.buy then
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
      root.tickBuyAt = tnow + 3
      return
    end
  end

  root.tickBuyAt = root.tickBuyAt or 0
  if tnow < root.tickBuyAt then
    return
  end

  local list = TSM.GetWatchlistIds(cfg)
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

  local maxBuy = nil
  pcall(function()
    maxBuy = TSM.GetThresholdMaxPrice(itemID, cfg)
  end)

  local results = nil
  pcall(function()
    results = Bridge.search_for_item(itemID)
  end)

  --- Retail LIFO: only evaluate index 1.
  local first = results and results[1] or nil
  local price = first_row_price(first)

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

  root.tickBuyAt = tnow + Timing.next_delay(root, cfg, "scan")
end

return ScienceAHBot
