--[[ ScienceAHBot — Sell module (TSM via root.TSM). Cognitive delay before post. ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local Timing = require("ScienceAHBot/Timing")
local Safety = require("ScienceAHBot/Safety")
local AHGuard = require("ScienceAHBot/AHGuard")
local Util = require("ScienceAHBot/Util")

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
  if not mods.sell then
    return
  end

  local TSM = root.TSM
  if not TSM or not TSM.GetMarketValue then
    return
  end

  --[[ Note: there is intentionally NO gold-reserve gate here.
       reserves.minGoldCopper means "don't spend below this floor", which
       applies to Buy and Snipe. Selling earns gold — gating it on
       `gold < minGoldCopper` would refuse to post exactly when the player
       most needs the income. Auction-deposit shortfalls are rejected by
       the AH API itself, so let the bridge surface that error instead. ]]

  root.tickSellAt = root.tickSellAt or 0
  if tnow < root.tickSellAt then
    return
  end

  local b = cfg.behavior.sell or {}
  local list = b.watchlist
  if not list or #list == 0 then
    list = TSM.GetWatchlistIds(cfg)
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

  local dbg = (cfg.behavior and cfg.behavior.debug) or {}

  local tsm = nil
  Util.safe_call("ModSell.GetMarketValue", function()
    tsm = TSM.GetMarketValue(itemID)
  end, { root = root, tnow = tnow })
  if not tsm then
    root.tickSellAt = tnow + Timing.next_delay(root, cfg, "sell_scan")
    return
  end

  if AHGuard.skip_search_because_ui_closed(root) then
    if dbg.verbose then
      Util.safe_call(
        "ModSell.verbose_skip_search",
        function()
          if core and core.log then
            core.log("[ScienceAHBot][sell] skip: AH UI closed (search guard); no post this tick.")
          end
        end,
        { root = root, tnow = tnow }
      )
    end
    root.tickSellAt = tnow + Timing.next_delay(root, cfg, "sell_scan")
    return
  end

  local mult = b.vendorPriceMultiplier or 0.99
  local target = math.floor(tsm * mult)
  local buffer = b.postFeeBufferCopper or 0
  target = math.max(b.minPostPriceCopper or 1, target - buffer)

  local results = nil
  Util.safe_call("ModSell.SearchForItem", function()
    results = Bridge.search_for_item(itemID, root, tnow)
  end, { root = root, tnow = tnow })
  local row1 = results and results[1]
  if type(row1) == "table" then
    local row = Bridge.first_row_price(row1)
    if type(row) == "number" and row > 0 then
      local uc = (cfg.behavior.undercut and cfg.behavior.undercut.undercutCopper) or 1
      target = math.max(b.minPostPriceCopper or 1, math.min(target, math.floor(row - uc)))
    end
  end

  local stack = b.postStackSize or 1
  local think = 0.85
  local gotCognitive = false
  if root.GetCognitiveLatency then
    local okc, vc = pcall(root.GetCognitiveLatency)
    if okc and type(vc) == "number" then
      think = vc
      gotCognitive = true
    end
  end
  if not gotCognitive then
    local ok2, v2 = pcall(Safety.GetCognitiveLatency)
    if ok2 and type(v2) == "number" then
      think = v2
    end
  end

  if dbg.verbose then
    Util.safe_call(
      "ModSell.verbose_tick",
      function()
        if core and core.log then
          core.log(
            string.format(
              "[ScienceAHBot][sell] item=%s target=%s stack=%s (AH row1 used if present)",
              tostring(itemID),
              tostring(target),
              tostring(stack)
            )
          )
        end
      end,
      { root = root, tnow = tnow }
    )
  end

  Util.safe_call("ModSell.AuctionOutcome.set_intent", function()
    if AuctionOutcome and AuctionOutcome.set_last_auction_intent then
      AuctionOutcome.set_last_auction_intent(root, {
        module = "sell",
        itemID = itemID,
        price = target,
        t = tnow,
      })
    end
  end, { root = root, tnow = tnow })

  if dbg.dryRun then
    Util.safe_call(
      "ModSell.dryrun_log",
      function()
        if core and core.log then
          core.log(
            string.format(
              "[ScienceAHBot][sell] DRYRUN would PostAuction after %.2fs (item=%s stack=%s unit=%s)",
              think,
              tostring(itemID),
              tostring(stack),
              tostring(target)
            )
          )
        end
      end,
      { root = root, tnow = tnow }
    )
  else
    Safety.transaction_lock_add(root)
    if root.schedule_after then
      local oksched = Util.safe_call(
        "ModSell.schedule_post",
        function()
          root.schedule_after(root, think, function()
            Util.safe_call("ModSell.PostAuction", function()
              Bridge.post_auction(itemID, stack, target)
            end, { root = root, tnow = tnow })
            Safety.transaction_lock_release(root)
          end, function()
            Safety.transaction_lock_release(root)
          end)
        end,
        { root = root, tnow = tnow }
      )
      if not oksched then
        Safety.transaction_lock_release(root)
      end
    else
      Util.safe_call("ModSell.PostAuctionImmediate", function()
        Bridge.post_auction(itemID, stack, target)
      end, { root = root, tnow = tnow })
      Safety.transaction_lock_release(root)
    end
  end

  root.tickSellAt = tnow + Timing.next_delay(root, cfg, "sell_scan")
end

return ScienceAHBot
