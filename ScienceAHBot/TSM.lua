--[[ ScienceAHBot — TSM DBMarket lookup (itemString i:itemID). ]]

local AH_Bot = {}

---@param itemID integer
---@return number|nil
function AH_Bot.GetMarketPrice(itemID)
  local itemString = "i:" .. tostring(itemID)
  if not _G.TSM_API or not TSM_API.GetCustomPriceValue then
    return nil
  end
  local ok, value = pcall(TSM_API.GetCustomPriceValue, "DBMarket", itemString)
  if not ok or value == nil then
    return nil
  end
  local n = tonumber(value)
  if not n or n <= 0 then
    return nil
  end
  return n
end

return AH_Bot
