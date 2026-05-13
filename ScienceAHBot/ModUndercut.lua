--[[ ScienceAHBot — Undercut / relist (TSM via root.TSM). ]]

local ScienceAHBot = {}
local Bridge = require("ScienceAHBot/AHBridge")
local Timing = require("ScienceAHBot/Timing")

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
        pcall(function()
          results = Bridge.search_for_item(itemID)
        end)
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
          pcall(function()
            Bridge.cancel_auction(a.index or a.slot or i)
          end)
          if root.schedule_after then
            pcall(function()
              root.schedule_after(root, u.relistDelaySeconds or 0.8, function()
                pcall(function()
                  Bridge.post_auction(itemID, a.quantity or a.count or 1, newPrice)
                end)
              end)
            end)
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
      local tsm = nil
      pcall(function()
        tsm = TSM.GetMarketValue(itemID)
      end)
      local results = nil
      pcall(function()
        results = Bridge.search_for_item(itemID)
      end)
      local first = results and results[1]
      local lowest = nil
      if type(first) == "table" then
        lowest = first.buyoutPrice or first.buyout or first.unitPrice or first.price
      end
      if u.aggressiveScanRepost and type(lowest) == "number" and tsm then
        local newPrice = math.max(u.minPostPriceCopper or 1, math.floor(math.min(lowest - copper, tsm * (u.tsmCapMult or 0.98))))
        pcall(function()
          Bridge.post_auction(itemID, u.postStackSize or 1, newPrice)
        end)
      end
    end
  end

  root.tickUndercutAt = tnow + Timing.next_delay(root, cfg, "undercut_scan")
end

return ScienceAHBot
