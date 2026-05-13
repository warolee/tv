--[[ ScienceAHBot — IZI AH wrapper: single place for hardware-level AH calls (pcall + name fallbacks). ]]

local AH_Bot = {}

local function require_izi()
  local ok, mod = pcall(require, "common/izi_sdk")
  if ok then
    return mod
  end
  return nil
end

local function get_ah_table()
  local IZI = require_izi()
  if not IZI then
    return nil
  end
  if IZI.AH then
    return IZI.AH
  end
  if IZI.ah then
    return IZI.ah
  end
  return nil
end

---@param method string
---@return boolean, ...
function AH_Bot.call(method, ...)
  local AH = get_ah_table()
  if not AH or not AH[method] then
    return false, nil
  end
  return pcall(AH[method], ...)
end

--- Try several method names until one exists and pcall succeeds.
---@param methods string[]
---@return boolean, ...
function AH_Bot.call_first(methods, ...)
  local AH = get_ah_table()
  if not AH then
    return false, nil
  end
  for i = 1, #methods do
    local name = methods[i]
    local fn = AH[name]
    if type(fn) == "function" then
      local ok, a, b, c, d, e = pcall(fn, ...)
      if ok then
        return true, a, b, c, d, e
      end
    end
  end
  return false, nil
end

function AH_Bot.search_for_item(itemID)
  local ok, res = AH_Bot.call("SearchForItem", itemID)
  if not ok then
    return nil
  end
  return res
end

function AH_Bot.place_bid_lifo(first)
  local ok = select(1, AH_Bot.call("PlaceBid", 1))
  if ok then
    return true
  end
  if type(first) == "table" then
    return select(1, AH_Bot.call("PlaceBid", first))
  end
  return false
end

--- Post from bags / list on AH — IZI names vary by build; extend this list after testing.
function AH_Bot.post_auction(itemID, quantity, unitPriceCopper)
  return AH_Bot.call_first({
    "PostAuction",
    "CreateAuction",
    "ListAuction",
    "PlaceAuction",
    "SellItem",
  }, itemID, quantity, unitPriceCopper)
end

function AH_Bot.cancel_auction(slotOrHandle)
  return AH_Bot.call_first({
    "CancelAuction",
    "CancelOwnedAuction",
  }, slotOrHandle)
end

function AH_Bot.get_owned_auctions()
  local ok, res = AH_Bot.call_first({
    "GetOwnedAuctions",
    "GetMyAuctions",
    "GetPlayerAuctions",
  })
  if not ok then
    return nil
  end
  return res
end

return AH_Bot
