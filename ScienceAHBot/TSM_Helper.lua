--[[ ScienceAHBot — TSM price database: cached DBMarket, per-item ratios, max bid threshold. ]]

local ScienceAHBot = {}

local CACHE_TTL = 300
local _cache = {}

local function now_s()
  local ok, izi = pcall(require, "common/izi_sdk")
  if ok and izi and izi.now then
    local o2, t = pcall(izi.now)
    if o2 and type(t) == "number" then
      return t
    end
  end
  if GetTime then
    return GetTime()
  end
  return 0
end

--- Clear all cached TSM values (e.g. after reload).
function ScienceAHBot.ClearTSMCache()
  _cache = {}
end

---@param itemID integer
---@return number|nil
function ScienceAHBot.GetMarketValue(itemID)
  local tnow = now_s()
  local entry = _cache[itemID]
  if entry and type(entry.v) == "number" and (tnow - entry.t) < CACHE_TTL then
    return entry.v
  end

  local itemString = "i:" .. tostring(itemID)
  local value = nil
  pcall(function()
    if not _G.TSM_API or not TSM_API.GetCustomPriceValue then
      return
    end
    local ok, v = pcall(TSM_API.GetCustomPriceValue, "DBMarket", itemString)
    if ok and v ~= nil then
      value = tonumber(v)
    end
  end)

  if type(value) == "number" and value > 0 then
    _cache[itemID] = { v = value, t = tnow }
    return value
  end

  _cache[itemID] = { v = nil, t = tnow }
  return nil
end

--- Ratio for an item: Config.Items[id].ratio, else buyRatio, else thresholds.defaultBuyRatio.
---@param itemID integer
---@param cfg table
---@return number
function ScienceAHBot.GetItemRatio(itemID, cfg)
  cfg = cfg or {}
  local it = cfg.Items and cfg.Items[itemID]
  if it and type(it.ratio) == "number" and it.ratio > 0 then
    return it.ratio
  end
  if type(cfg.buyRatio) == "number" and cfg.buyRatio > 0 then
    return cfg.buyRatio
  end
  local th = cfg.thresholds or {}
  return th.defaultBuyRatio or 0.75
end

--- Maximum price we consider a "deal" (TSM market * ratio).
---@param itemID integer
---@param cfg table
---@return number|nil
function ScienceAHBot.GetThresholdMaxPrice(itemID, cfg)
  local mv = ScienceAHBot.GetMarketValue(itemID)
  if not mv then
    return nil
  end
  return mv * ScienceAHBot.GetItemRatio(itemID, cfg)
end

--- Ordered item IDs: Config.Items keys if present, else Config.watchlist array.
---@param cfg table
---@return integer[]
function ScienceAHBot.GetWatchlistIds(cfg)
  cfg = cfg or {}
  local ids = {}
  if cfg.Items and next(cfg.Items) then
    for id in pairs(cfg.Items) do
      if type(id) == "number" then
        ids[#ids + 1] = id
      end
    end
    table.sort(ids)
    return ids
  end
  local wl = cfg.watchlist or {}
  for i = 1, #wl do
    ids[i] = wl[i]
  end
  return ids
end

function ScienceAHBot.GetCacheStats()
  local n = 0
  for _ in pairs(_cache) do
    n = n + 1
  end
  return n, CACHE_TTL
end

return ScienceAHBot
