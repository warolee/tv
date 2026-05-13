--[[ ScienceAHBot — TSM price database: ValueCache (300s), GetItemValue, IsDeal, watchlist helpers. ]]

local ScienceAHBot = {}

local CACHE_TTL = 300
--- In-memory TSM DBMarket values keyed by item id (spec: ValueCache).
local ValueCache = {}

ScienceAHBot.ValueCache = ValueCache

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

function ScienceAHBot.ClearTSMCache()
  for k in pairs(ValueCache) do
    ValueCache[k] = nil
  end
end

--- TSM `DBMarket` for `i:<itemID>`, cached 300s in ValueCache.
---@param itemID integer
---@return number|nil
function ScienceAHBot.GetItemValue(itemID)
  if type(itemID) ~= "number" then
    return nil
  end
  local tnow = now_s()
  local entry = ValueCache[itemID]
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
    ValueCache[itemID] = { v = value, t = tnow }
    return value
  end

  ValueCache[itemID] = { v = nil, t = tnow }
  return nil
end

--- Alias for older modules; same as GetItemValue.
function ScienceAHBot.GetMarketValue(itemID)
  return ScienceAHBot.GetItemValue(itemID)
end

--- Ratio for caps: per-item `Config.Items`, then `Config.DefaultRatio`, `buyRatio`, `thresholds.defaultBuyRatio`.
---@param itemID integer
---@param cfg table
---@return number
function ScienceAHBot.GetItemRatio(itemID, cfg)
  cfg = cfg or {}
  local it = cfg.Items and cfg.Items[itemID]
  if it and type(it.ratio) == "number" and it.ratio > 0 then
    return it.ratio
  end
  if type(cfg.DefaultRatio) == "number" and cfg.DefaultRatio > 0 then
    return cfg.DefaultRatio
  end
  if type(cfg.buyRatio) == "number" and cfg.buyRatio > 0 then
    return cfg.buyRatio
  end
  local th = cfg.thresholds or {}
  return th.defaultBuyRatio or 0.75
end

--- Spec profit check: `currentPrice <= TSM * ratio` with ratio from `Config.Items[id].ratio` or `Config.DefaultRatio` or `thresholds.defaultBuyRatio`.
--- Two-arg `ScienceAHBot.IsDeal(itemID, currentPrice)` is also set on the runtime table in `main.lua`.
---@param itemID integer
---@param currentPrice number
---@param cfg table|nil
---@return boolean
function ScienceAHBot.IsDeal(itemID, currentPrice, cfg)
  cfg = cfg or {}
  if type(currentPrice) ~= "number" or currentPrice <= 0 then
    return false
  end
  local tsm = ScienceAHBot.GetItemValue(itemID)
  if not tsm or tsm <= 0 then
    return false
  end
  local r = nil
  local it = cfg.Items and cfg.Items[itemID]
  if it and type(it.ratio) == "number" and it.ratio > 0 then
    r = it.ratio
  elseif type(cfg.DefaultRatio) == "number" and cfg.DefaultRatio > 0 then
    r = cfg.DefaultRatio
  else
    local th = cfg.thresholds or {}
    r = th.defaultBuyRatio or 0.75
  end
  return currentPrice <= tsm * r
end

--- Maximum bid cap (TSM * GetItemRatio); learning layers apply in modules.
---@param itemID integer
---@param cfg table
---@return number|nil
function ScienceAHBot.GetThresholdMaxPrice(itemID, cfg)
  local mv = ScienceAHBot.GetItemValue(itemID)
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
  for _ in pairs(ValueCache) do
    n = n + 1
  end
  return n, CACHE_TTL
end

return ScienceAHBot
