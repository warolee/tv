--[[ ScienceAHBot — Undercut / relist with social-delay lazy queue (owned auctions). ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}
local Bridge = require("AHBridge")
local Timing = require("Timing")
local Safety = require("Safety")
local AHGuard = require("AHGuard")
local Util = require("Util")
local ScanLog = require("ScanLog")

local AuctionOutcome = (function()
  local ok, mod = pcall(require, "AuctionOutcome")
  return ok and mod or nil
end)()

--[[ Lazy-repost queue key.
     Prefer a stable handle from the AH API itself: `index` or `slot`.
     When those are missing some IZI builds only return a flat list, in
     which case the *position* in that list (`i`) is unreliable across
     ticks — auctions expire, sell, or get cancelled and shift the rest
     of the list up. Falling back to `i` would let two ticks of the
     same physical auction land on different keys, which leaks queue
     entries (the old key never gets cleaned up) and can re-arm the
     social-delay timer on every tick, effectively never reposting.

     If neither index nor slot is available, fingerprint the row by
     (itemID, posted unit price, quantity). Two of the player's own
     auctions of the same item at the same unit price and stack size
     are functionally identical for repost purposes, so any collision
     between them is benign — we'd repost them the same way. ]]
local function queue_key(itemID, slot, fingerprintPrice, fingerprintQty)
  if slot ~= nil then
    return "s:" .. tostring(itemID) .. "#" .. tostring(slot)
  end
  return string.format(
    "fp:%s#%s#%s",
    tostring(itemID),
    tostring(fingerprintPrice or "?"),
    tostring(fingerprintQty or "?")
  )
end

local function social_delay_sec(u)
  local lo = u.socialRepostDelayMinSec or (5 * 60)
  local hi = u.socialRepostDelayMaxSec or (10 * 60)
  if hi < lo then
    lo, hi = hi, lo
  end
  return lo + math.random() * (hi - lo)
end

--- Process at most one lazy repost whose social timer has expired.
local function process_lazy_queue(root, cfg, tnow, u)
  local dbg = (cfg.behavior and cfg.behavior.debug) or {}
  local q = root._lazyRepostQueue
  if type(q) ~= "table" then
    return
  end
  if Safety.is_transaction_locked(root) then
    return
  end

  for key, ent in pairs(q) do
    if ent and type(ent.when) == "number" and tnow >= ent.when then
      local itemID = ent.itemID
      local newPrice = ent.newPrice
      local qty = ent.qty or 1
      local posted = ent.posted
      local slotHint = ent.slotHint

      local owned = nil
      Util.safe_call("ModUndercut.get_owned_auctions_lazy", function()
        owned = Bridge.get_owned_auctions()
      end, { root = root, tnow = tnow })

      local match = nil
      if type(owned) == "table" then
        for j = 1, #owned do
          local a = owned[j]
          local aid = a and (a.itemId or a.item_id or a.itemID)
          local p = a and (a.buyoutPrice or a.unitPrice or a.postedPrice)
          if aid == itemID and type(p) == "number" and type(posted) == "number" and math.abs(p - posted) < 3 then
            match = a
            break
          end
          if aid == itemID and slotHint and ((a.index == slotHint) or (a.slot == slotHint) or (j == slotHint)) then
            match = a
            break
          end
        end
      end

      q[key] = nil

      if match and type(newPrice) == "number" and newPrice > 0 then
        Util.safe_call("ModUndercut.AuctionOutcome.set_intent_lazy", function()
          if AuctionOutcome and AuctionOutcome.set_last_auction_intent then
            AuctionOutcome.set_last_auction_intent(root, {
              module = "undercut_lazy",
              itemID = itemID,
              price = newPrice,
              t = tnow,
            })
          end
        end, { root = root, tnow = tnow })
        Util.safe_call("ModUndercut.ScanLog.lazy_exec", function()
          ScanLog.record(root, {
            module = "undercut_lazy",
            itemId = itemID,
            tsm = nil,
            row1 = nil,
            maxBuy = newPrice,
            baseRatio = posted,
            effRatio = nil,
            action = dbg.dryRun and "dryrun_undercut_lazy" or "undercut_lazy_executed",
          })
        end, { root = root, tnow = tnow })
        if dbg.dryRun then
          Util.safe_call(
            "ModUndercut.dryrun_log_lazy",
            function()
              if core and core.log then
                core.log(
                  string.format(
                    "[ScienceAHBot][undercut] DRYRUN lazy repost would cancel+post item=%s qty=%s unit=%s",
                    tostring(itemID),
                    tostring(qty),
                    tostring(newPrice)
                  )
                )
              end
            end,
            { root = root, tnow = tnow }
          )
        else
          Safety.transaction_lock_add(root)
          Util.safe_call("ModUndercut.cancel_auction_lazy", function()
            Bridge.cancel_auction(match.index or match.slot or slotHint or 1)
          end, { root = root, tnow = tnow })
          if root.schedule_after then
            local oksched = Util.safe_call(
              "ModUndercut.schedule_repost_lazy",
              function()
                root.schedule_after(root, u.relistDelaySeconds or 0.8, function()
                  Util.safe_call("ModUndercut.post_auction_lazy", function()
                    Bridge.post_auction(itemID, qty, newPrice)
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
            Util.safe_call("ModUndercut.post_auction_lazy_immediate", function()
              Bridge.post_auction(itemID, qty, newPrice)
            end, { root = root, tnow = tnow })
            Safety.transaction_lock_release(root)
          end
        end
      end
      return
    end
  end
end

--- Run only the lazy repost processor (used from `Core` during search backoff).
function ScienceAHBot.tick_lazy_queue_only(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.undercut then
    return
  end
  local u = cfg.behavior.undercut or {}
  root._lazyRepostQueue = root._lazyRepostQueue or {}
  process_lazy_queue(root, cfg, tnow, u)
end

function ScienceAHBot.tick(root, tnow)
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local mods = (cfg.behavior and cfg.behavior.modules) or {}
  if not mods.undercut then
    return
  end

  local TSM = root.TSM
  if not TSM or not TSM.GetMarketValue then
    return
  end

  root.tickUndercutAt = root.tickUndercutAt or 0
  if tnow < root.tickUndercutAt then
    return
  end

  local u = cfg.behavior.undercut or {}
  local copper = u.undercutCopper or 1
  local dbg = (cfg.behavior and cfg.behavior.debug) or {}

  root._lazyRepostQueue = root._lazyRepostQueue or {}

  local owned = nil
  Util.safe_call("ModUndercut.get_owned_auctions", function()
    owned = Bridge.get_owned_auctions()
  end, { root = root, tnow = tnow })

  if type(owned) == "table" and #owned > 0 then
    for i = 1, math.min(#owned, u.maxRelistPerTick or 3) do
      local a = owned[i]
      local itemID = a and (a.itemId or a.item_id or a.itemID)
      local posted = a and (a.buyoutPrice or a.unitPrice or a.postedPrice)
      if type(itemID) == "number" and type(posted) == "number" then
        local results = nil
        if not AHGuard.skip_search_because_ui_closed(root) then
          Util.safe_call("ModUndercut.SearchForItem_slot", function()
            results = Bridge.search_for_item(itemID, root, tnow)
          end, { root = root, tnow = tnow })
        elseif dbg.verbose then
          Util.safe_call(
            "ModUndercut.verbose_skip_search_slot",
            function()
              if core and core.log then
                core.log("[ScienceAHBot][undercut] skip search: AH UI closed (slot scan)")
              end
            end,
            { root = root, tnow = tnow }
          )
        end
        local row1 = results and results[1]
        local lowest = nil
        if type(row1) == "table" then
          lowest = Bridge.first_row_price(row1)
        end
        local tsm = nil
        Util.safe_call("ModUndercut.GetMarketValue_slot", function()
          tsm = TSM.GetMarketValue(itemID)
        end, { root = root, tnow = tnow })
        local qty = a.quantity or a.count or 1
        if type(lowest) == "number" and lowest < posted and tsm then
          local newPrice = math.max(u.minPostPriceCopper or 1, math.floor(math.min(lowest - copper, tsm * (u.tsmCapMult or 0.98))))
          --- Prefer a real handle from the API; fall back to (posted, qty)
          --- fingerprint when the API returns no stable identifier.
          local stableSlot = a.index or a.slot
          local key = queue_key(itemID, stableSlot, posted, qty)
          local ent = root._lazyRepostQueue[key]
          local actionLabel
          if ent and type(ent.when) == "number" and tnow < ent.when then
            ent.newPrice = newPrice
            ent.posted = posted
            ent.qty = qty
            actionLabel = "undercut_lazy_refreshed"
          else
            root._lazyRepostQueue[key] = {
              when = tnow + social_delay_sec(u),
              itemID = itemID,
              newPrice = newPrice,
              qty = qty,
              posted = posted,
              slotHint = stableSlot or i,
            }
            actionLabel = "undercut_lazy_queued"
          end
          Util.safe_call("ModUndercut.ScanLog.queued", function()
            ScanLog.record(root, {
              module = "undercut",
              itemId = itemID,
              tsm = tsm,
              row1 = lowest,
              maxBuy = newPrice,
              baseRatio = posted,
              effRatio = (tsm > 0) and (newPrice / tsm) or nil,
              action = actionLabel,
            })
          end, { root = root, tnow = tnow })
        elseif type(lowest) == "number" and tsm then
          --- Lowest competitor isn't beating us; just record an observation
          --- row so the scan-log shows undercut activity occurred.
          Util.safe_call("ModUndercut.ScanLog.skip_already_lowest", function()
            ScanLog.record(root, {
              module = "undercut",
              itemId = itemID,
              tsm = tsm,
              row1 = lowest,
              maxBuy = nil,
              baseRatio = posted,
              effRatio = nil,
              action = "undercut_skip_already_lowest",
            })
          end, { root = root, tnow = tnow })
        end
      end
    end
  else
    local list = u.repostWatchlist
    if (not list or #list == 0) and u.useMainWatchlist then
      list = TSM.GetWatchlistIds(cfg)
    end
    if list and #list > 0 and u.aggressiveScanRepost then
      root.ucIdx = root.ucIdx or 1
      if root.ucIdx > #list then
        root.ucIdx = 1
      end
      local itemID = list[root.ucIdx]
      root.ucIdx = root.ucIdx + 1
      if AHGuard.skip_search_because_ui_closed(root) then
        if dbg.verbose then
          Util.safe_call(
            "ModUndercut.verbose_skip_aggressive",
            function()
              if core and core.log then
                core.log("[ScienceAHBot][undercut] skip aggressive scan: AH UI closed")
              end
            end,
            { root = root, tnow = tnow }
          )
        end
      else
        local tsm = nil
        Util.safe_call("ModUndercut.GetMarketValue_aggressive", function()
          tsm = TSM.GetMarketValue(itemID)
        end, { root = root, tnow = tnow })
        local results = nil
        Util.safe_call("ModUndercut.SearchForItem_aggressive", function()
          results = Bridge.search_for_item(itemID, root, tnow)
        end, { root = root, tnow = tnow })
        local first = results and results[1]
        local lowest = nil
        if type(first) == "table" then
          lowest = Bridge.first_row_price(first)
        end
        if type(lowest) == "number" and tsm then
          local newPrice = math.max(u.minPostPriceCopper or 1, math.floor(math.min(lowest - copper, tsm * (u.tsmCapMult or 0.98))))
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
          Util.safe_call("ModUndercut.AuctionOutcome.set_intent_aggressive", function()
            if AuctionOutcome and AuctionOutcome.set_last_auction_intent then
              AuctionOutcome.set_last_auction_intent(root, {
                module = "undercut_aggressive",
                itemID = itemID,
                price = newPrice,
                t = tnow,
              })
            end
          end, { root = root, tnow = tnow })
          Util.safe_call("ModUndercut.ScanLog.aggressive", function()
            ScanLog.record(root, {
              module = "undercut_aggressive",
              itemId = itemID,
              tsm = tsm,
              row1 = lowest,
              maxBuy = newPrice,
              baseRatio = nil,
              effRatio = (tsm > 0) and (newPrice / tsm) or nil,
              action = dbg.dryRun and "dryrun_undercut_aggressive" or "undercut_aggressive_scheduled",
            })
          end, { root = root, tnow = tnow })
          if dbg.dryRun then
            Util.safe_call(
              "ModUndercut.dryrun_log_aggressive",
              function()
                if core and core.log then
                  core.log(
                    string.format(
                      "[ScienceAHBot][undercut] DRYRUN aggressive post item=%s unit=%s after %.2fs",
                      tostring(itemID),
                      tostring(newPrice),
                      think
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
                "ModUndercut.schedule_post_aggressive",
                function()
                  root.schedule_after(root, think, function()
                    Util.safe_call("ModUndercut.post_auction_aggressive", function()
                      Bridge.post_auction(itemID, u.postStackSize or 1, newPrice)
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
              Util.safe_call("ModUndercut.post_auction_aggressive_immediate", function()
                Bridge.post_auction(itemID, u.postStackSize or 1, newPrice)
              end, { root = root, tnow = tnow })
              Safety.transaction_lock_release(root)
            end
          end
        end
      end
    end
  end

  root.tickUndercutAt = tnow + Timing.next_delay(root, cfg, "undercut_scan")
end

return ScienceAHBot
