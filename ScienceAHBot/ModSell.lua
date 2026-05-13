--[[ ScienceAHBot — Post auctions from bag items (IZI method names vary — tune after one test run). ]]

local AH_Bot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local TSM = require("ScienceAHBot/TSM")
local Timing = require("ScienceAHBot/Timing")

function AH_Bot.tick(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.sell then
    return
  end

  local reserves = cfg.behavior.reserves
  if reserves and reserves.minGoldCopper then
    local okg, copper = pcall(function()
      return core.inventory.get_gold()
    end)
    if okg and type(copper) == "number" and copper < reserves.minGoldCopper then
      root.tickSellAt = tnow + 5
      return
    end
  end

  root.tickSellAt = root.tickSellAt or 0
  if tnow < root.tickSellAt then
    return
  end

  local b = cfg.behavior.sell or {}
  local list = b.watchlist
  if not list or #list == 0 then
    list = cfg.watchlist or {}
  end
  if #list == 0 then
    root.tickSellAt = tnow + 10
    return
  end

  root.sellListIndex = root.sellListIndex or 1
  if root.sellListIndex > #list then
    root.sellListIndex = 1
  end

  local itemID = list[root.sellListIndex]
  root.sellListIndex = root.sellListIndex + 1

  local tsm = TSM.GetMarketPrice(itemID)
  if not tsm then
    root.tickSellAt = tnow + Timing.next_delay(cfg, "sell_scan")
    return
  end

  local mult = b.vendorPriceMultiplier or 0.99
  local target = math.floor(tsm * mult)
  local buffer = b.postFeeBufferCopper or 0
  target = math.max(b.minPostPriceCopper or 1, target - buffer)

  local results = nil
  pcall(function()
    results = Bridge.search_for_item(itemID)
  end)
  local first = results and results[1]
  if type(first) == "table" then
    local row = first.buyoutPrice or first.buyout or first.unitPrice or first.price
    if type(row) == "number" and row > 0 then
      local uc = (cfg.behavior.undercut and cfg.behavior.undercut.undercutCopper) or 1
      target = math.max(b.minPostPriceCopper or 1, math.min(target, math.floor(row - uc)))
    end
  end

  local stack = b.postStackSize or 1
  pcall(function()
    Bridge.post_auction(itemID, stack, target)
  end)

  root.tickSellAt = tnow + Timing.next_delay(cfg, "sell_scan")
end

return AH_Bot
