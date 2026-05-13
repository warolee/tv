--[[ ScienceAHBot — Buy: LIFO row 1, TSM + adaptive ratio, cognitive latency before PlaceBid. ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local Timing = require("ScienceAHBot/Timing")
local Learn = require("ScienceAHBot/Learn")
local ScanLog = require("ScienceAHBot/ScanLog")
local Safety = require("ScienceAHBot/Safety")
local AHGuard = require("ScienceAHBot/AHGuard")

local AuctionOutcome = (function()
  local ok, mod = pcall(require, "ScienceAHBot/AuctionOutcome")
  return ok and mod or nil
end)()

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

  local dbg = (cfg.behavior and cfg.behavior.debug) or {}

  if AHGuard.skip_search_because_ui_closed(root) then
    if dbg.verbose then
      pcall(function()
        if core and core.log then
          core.log("[ScienceAHBot][buy] skip search: AH UI closed (search guard)")
        end
      end)
    end
    root.tickBuyAt = tnow + Timing.next_delay(root, cfg, "scan")
    return
  end

  local tsm = nil
  pcall(function()
    tsm = TSM.GetMarketValue(itemID)
  end)

  local results = nil
  pcall(function()
    results = Bridge.search_for_item(itemID, root, tnow)
  end)

  local first = results and results[1] or nil
  local price = Bridge.first_row_price(first)

  pcall(function()
    if tsm and type(price) == "number" and price > 0 then
      Learn.record_observation(root, itemID, price, tsm)
    end
  end)

  local baseR = nil
  pcall(function()
    baseR = TSM.GetItemRatio(itemID, cfg)
  end)
  local effR = baseR or 0.75
  pcall(function()
    effR = Learn.get_effective_ratio(root, itemID, cfg, baseR or 0.75)
  end)

  local maxBuy = (tsm and type(effR) == "number") and (tsm * effR) or nil

  local isDeal = true
  if type(price) == "number" and price > 0 then
    pcall(function()
      if TSM.IsDeal then
        local ok, v = pcall(TSM.IsDeal, itemID, price, cfg)
        if ok and type(v) == "boolean" then
          isDeal = v
        end
      end
    end)
  end

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
  elseif not isDeal then
    action = "skip_not_deal"
  else
    action = "bid_scheduled"
  end
  pcall(function()
    ScanLog.record(root, {
      module = "buy",
      itemId = itemID,
      tsm = tsm,
      row1 = price,
      maxBuy = maxBuy,
      baseRatio = baseR,
      effRatio = effR,
      action = action,
    })
  end)

  if dbg.verbose then
    pcall(function()
      if core and core.log then
        core.log(
          string.format(
            "[ScienceAHBot][buy] item=%s action=%s row1=%s maxBuy=%s isDeal=%s",
            tostring(itemID),
            tostring(action),
            tostring(price),
            tostring(maxBuy),
            tostring(isDeal)
          )
        )
      end
    end)
  end

  if results and first and type(price) == "number" and maxBuy and price <= maxBuy and isDeal then
    local think = 1.0
    pcall(function()
      if root.GetCognitiveLatency then
        local ok, v = pcall(root.GetCognitiveLatency)
        if ok and type(v) == "number" then
          think = v
        end
      end
    end)
    pcall(function()
      if AuctionOutcome and AuctionOutcome.set_last_auction_intent then
        AuctionOutcome.set_last_auction_intent(root, {
          module = "buy",
          itemID = itemID,
          price = price,
          t = tnow,
        })
      end
    end)
    if dbg.dryRun then
      pcall(function()
        if core and core.log then
          core.log(
            string.format(
              "[ScienceAHBot][buy] DRYRUN would PlaceBid after %.2fs (item=%s price=%s)",
              think,
              tostring(itemID),
              tostring(price)
            )
          )
        end
      end)
      pcall(function()
        ScanLog.record(root, {
          module = "buy",
          itemId = itemID,
          tsm = tsm,
          row1 = price,
          maxBuy = maxBuy,
          baseRatio = baseR,
          effRatio = effR,
          action = "dryrun_bid",
        })
      end)
    else
      Safety.transaction_lock_add(root)
      if root.schedule_after then
        local oksched = pcall(function()
          root.schedule_after(root, think, function()
            pcall(function()
              Bridge.place_bid_lifo(first)
            end)
            Safety.transaction_lock_release(root)
          end, function()
            Safety.transaction_lock_release(root)
          end)
        end)
        if not oksched then
          Safety.transaction_lock_release(root)
        end
      else
        pcall(function()
          Bridge.place_bid_lifo(first)
        end)
        Safety.transaction_lock_release(root)
      end
    end
  end

  root.tickBuyAt = tnow + Timing.next_delay(root, cfg, "scan")
end

return ScienceAHBot
