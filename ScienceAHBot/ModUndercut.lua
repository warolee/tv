--[[ ScienceAHBot — Undercut / relist with social-delay lazy queue (owned auctions). ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}
local Bridge = require("AHBridge")
local Timing = require("Timing")
local Safety = require("Safety")
local AHGuard = require("AHGuard")

local AuctionOutcome = (function()
  local ok, mod = pcall(require, "AuctionOutcome")
  return ok and mod or nil
end)()

local function queue_key(itemID, slot)
  return tostring(itemID) .. "#" .. tostring(slot or "?")
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
      pcall(function()
        owned = Bridge.get_owned_auctions()
      end)

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
        pcall(function()
          if AuctionOutcome and AuctionOutcome.set_last_auction_intent then
            AuctionOutcome.set_last_auction_intent(root, {
              module = "undercut_lazy",
              itemID = itemID,
              price = newPrice,
              t = tnow,
            })
          end
        end)
        if dbg.dryRun then
          pcall(function()
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
          end)
        else
          Safety.transaction_lock_add(root)
          pcall(function()
            Bridge.cancel_auction(match.index or match.slot or slotHint or 1)
          end)
          if root.schedule_after then
            local oksched = pcall(function()
              root.schedule_after(root, u.relistDelaySeconds or 0.8, function()
                pcall(function()
                  Bridge.post_auction(itemID, qty, newPrice)
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
              Bridge.post_auction(itemID, qty, newPrice)
            end)
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
  pcall(function()
    owned = Bridge.get_owned_auctions()
  end)

  if type(owned) == "table" and #owned > 0 then
    for i = 1, math.min(#owned, u.maxRelistPerTick or 3) do
      local a = owned[i]
      local itemID = a and (a.itemId or a.item_id or a.itemID)
      local posted = a and (a.buyoutPrice or a.unitPrice or a.postedPrice)
      if type(itemID) == "number" and type(posted) == "number" then
        local results = nil
        if not AHGuard.skip_search_because_ui_closed(root) then
          pcall(function()
            results = Bridge.search_for_item(itemID, root, tnow)
          end)
        elseif dbg.verbose then
          pcall(function()
            if core and core.log then
              core.log("[ScienceAHBot][undercut] skip search: AH UI closed (slot scan)")
            end
          end)
        end
        local row1 = results and results[1]
        local lowest = nil
        if type(row1) == "table" then
          lowest = row1.buyoutPrice or row1.buyout or row1.unitPrice or row1.price
        end
        local tsm = nil
        pcall(function()
          tsm = TSM.GetMarketValue(itemID)
        end)
        if type(lowest) == "number" and lowest < posted and tsm then
          local newPrice = math.max(u.minPostPriceCopper or 1, math.floor(math.min(lowest - copper, tsm * (u.tsmCapMult or 0.98))))
          local key = queue_key(itemID, a.index or a.slot or i)
          local ent = root._lazyRepostQueue[key]
          if ent and type(ent.when) == "number" and tnow < ent.when then
            ent.newPrice = newPrice
            ent.posted = posted
            ent.qty = a.quantity or a.count or 1
          else
            root._lazyRepostQueue[key] = {
              when = tnow + social_delay_sec(u),
              itemID = itemID,
              newPrice = newPrice,
              qty = a.quantity or a.count or 1,
              posted = posted,
              slotHint = a.index or a.slot or i,
            }
          end
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
          pcall(function()
            if core and core.log then
              core.log("[ScienceAHBot][undercut] skip aggressive scan: AH UI closed")
            end
          end)
        end
      else
        local tsm = nil
        pcall(function()
          tsm = TSM.GetMarketValue(itemID)
        end)
        local results = nil
        pcall(function()
          results = Bridge.search_for_item(itemID, root, tnow)
        end)
        local first = results and results[1]
        local lowest = nil
        if type(first) == "table" then
          lowest = first.buyoutPrice or first.buyout or first.unitPrice or first.price
        end
        if type(lowest) == "number" and tsm then
          local newPrice = math.max(u.minPostPriceCopper or 1, math.floor(math.min(lowest - copper, tsm * (u.tsmCapMult or 0.98))))
          local think = 0.85
          local gotCognitive = false
          pcall(function()
            if root.GetCognitiveLatency then
              local ok, v = pcall(root.GetCognitiveLatency)
              if ok and type(v) == "number" then
                think = v
                gotCognitive = true
              end
            end
          end)
          if not gotCognitive then
            pcall(function()
              local ok2, v2 = pcall(Safety.GetCognitiveLatency)
              if ok2 and type(v2) == "number" then
                think = v2
              end
            end)
          end
          pcall(function()
            if AuctionOutcome and AuctionOutcome.set_last_auction_intent then
              AuctionOutcome.set_last_auction_intent(root, {
                module = "undercut_aggressive",
                itemID = itemID,
                price = newPrice,
                t = tnow,
              })
            end
          end)
          if dbg.dryRun then
            pcall(function()
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
            end)
          else
            Safety.transaction_lock_add(root)
            if root.schedule_after then
              local oksched = pcall(function()
                root.schedule_after(root, think, function()
                  pcall(function()
                    Bridge.post_auction(itemID, u.postStackSize or 1, newPrice)
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
                Bridge.post_auction(itemID, u.postStackSize or 1, newPrice)
              end)
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
