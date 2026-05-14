--[[ ScienceAHBot — IZI AH wrapper: single place for hardware-level AH calls (pcall + name fallbacks). ]]

local ScienceAHBotBridge = {}

local IZI = (function()
  local ok, mod = pcall(require, "common/izi_sdk")
  return ok and mod or nil
end)()

local AHGuardMod = (function()
  local ok, mod = pcall(require, "AHGuard")
  return ok and mod or nil
end)()

local function get_ah_table()
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
function ScienceAHBotBridge.call(method, ...)
  local AH = get_ah_table()
  if not AH or not AH[method] then
    return false, nil
  end
  return pcall(AH[method], ...)
end

--- Try several method names until one exists and pcall succeeds.
---@param methods string[]
---@return boolean, ...
function ScienceAHBotBridge.call_first(methods, ...)
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

function ScienceAHBotBridge.search_for_item(itemID, root, tnow)
  local AH = get_ah_table()
  if not AH or type(AH.SearchForItem) ~= "function" then
    if AHGuardMod and root and type(tnow) == "number" then
      AHGuardMod.record_search_attempt(root, tnow, "no_method")
    end
    return nil
  end
  local ok, res = pcall(AH.SearchForItem, itemID)
  if AHGuardMod and root and type(tnow) == "number" then
    if not ok then
      AHGuardMod.record_search_attempt(root, tnow, "pcall_fail")
    else
      AHGuardMod.record_search_attempt(root, tnow, "ok")
    end
  end
  if not ok then
    return nil
  end
  return res
end

--- LIFO row-1 copper selection for IZI result tables (shared by buy/snipe).
function ScienceAHBotBridge.first_row_price(first)
  if type(first) ~= "table" then
    return nil
  end
  return first.buyoutPrice
    or first.buyout
    or first.unitPrice
    or first.price
    or first.minPrice
end

function ScienceAHBotBridge.place_bid_lifo(first)
  if type(first) == "table" then
    local ok = select(1, ScienceAHBotBridge.call_first({
      "PlaceBid",
      "Buyout",
      "SubmitBid",
    }, first))
    if ok then
      return true
    end
  end
  --- Fallback: some IZI builds take only the LIFO row index (1).
  return select(1, ScienceAHBotBridge.call("PlaceBid", 1))
end

--- Post from bags / list on AH — IZI names vary by build; extend this list after testing.
function ScienceAHBotBridge.post_auction(itemID, quantity, unitPriceCopper)
  return ScienceAHBotBridge.call_first({
    "PostAuction",
    "CreateAuction",
    "ListAuction",
    "PlaceAuction",
    "SellItem",
  }, itemID, quantity, unitPriceCopper)
end

function ScienceAHBotBridge.cancel_auction(slotOrHandle)
  return ScienceAHBotBridge.call_first({
    "CancelAuction",
    "CancelOwnedAuction",
  }, slotOrHandle)
end

function ScienceAHBotBridge.get_owned_auctions()
  local ok, res = ScienceAHBotBridge.call_first({
    "GetOwnedAuctions",
    "GetMyAuctions",
    "GetPlayerAuctions",
  })
  if not ok then
    return nil
  end
  return res
end

--- Sorted function names on the current IZI AH table (for dashboard / debugging).
---@param maxN integer|nil
---@return string[], integer extra_count
function ScienceAHBotBridge.get_ah_function_keys(maxN)
  maxN = maxN or 48
  local AH = get_ah_table()
  if not AH then
    return {}, 0
  end
  local keys = {}
  for k, v in pairs(AH) do
    if type(v) == "function" then
      keys[#keys + 1] = tostring(k)
    end
  end
  table.sort(keys)
  local extra = math.max(0, #keys - maxN)
  if #keys > maxN then
    local trimmed = {}
    for i = 1, maxN do
      trimmed[i] = keys[i]
    end
    keys = trimmed
  end
  return keys, extra
end

return ScienceAHBotBridge
