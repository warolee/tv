--[[ ScienceAHBot — lightweight adaptive layer: observes AH row1 vs TSM DBMarket, persists patterns, blends into buy caps. ]]

local ScienceAHBot = {}
local Persistence = require("ScienceAHBot/Persistence")

local function clamp(x, lo, hi)
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

--- Update EWMA of (listing / TSM) for an item. Call after every scan with row-1 price and fresh TSM.
---@param root table
---@param itemID number
---@param listingCopper number|nil LIFO row 1 unit or buyout copper
---@param tsmCopper number|nil TSM DBMarket (same session; may be cached)
function ScienceAHBot.record_observation(root, itemID, listingCopper, tsmCopper)
  if not root or type(itemID) ~= "number" then
    return
  end
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local L = (cfg.behavior and cfg.behavior.learn) or {}
  if L.enabled == false then
    return
  end
  if type(listingCopper) ~= "number" or listingCopper <= 0 then
    return
  end
  if type(tsmCopper) ~= "number" or tsmCopper <= 0 then
    return
  end

  local ratio = listingCopper / tsmCopper
  ratio = clamp(ratio, 0.02, 2.5)

  cfg.patterns = cfg.patterns or {}
  local p = cfg.patterns[itemID] or {}
  cfg.patterns[itemID] = p

  local alpha = L.ewmaAlpha or 0.15
  alpha = clamp(alpha, 0.02, 0.6)

  if type(p.ewmaAhToTsm) ~= "number" or p.ewmaAhToTsm <= 0 then
    p.ewmaAhToTsm = ratio
  else
    p.ewmaAhToTsm = alpha * ratio + (1 - alpha) * p.ewmaAhToTsm
  end
  p.n = (type(p.n) == "number" and p.n or 0) + 1

  pcall(function()
    if core and core.time then
      p.lastSeen = core.time()
    elseif GetTime then
      p.lastSeen = GetTime()
    end
  end)

  Persistence.mark_dirty(root)
end

--- Blend user/strategy ratio with learned typical listing/TSM ratio (cross-referenced with same TSM snapshot).
---@param root table
---@param itemID number
---@param cfg table
---@param baseRatio number already-combined cap (e.g. GetItemRatio or min(snipeCap, itemR))
---@return number
function ScienceAHBot.get_effective_ratio(root, itemID, cfg, baseRatio)
  if type(baseRatio) ~= "number" or baseRatio <= 0 then
    return baseRatio
  end
  local L = (cfg.behavior and cfg.behavior.learn) or {}
  if L.enabled == false then
    return baseRatio
  end
  local minN = L.minSamples or 5
  local p = (cfg.patterns or {})[itemID]
  if not p or type(p.n) ~= "number" or p.n < minN then
    return baseRatio
  end
  local ewma = p.ewmaAhToTsm
  if type(ewma) ~= "number" or ewma <= 0 then
    return baseRatio
  end

  local slack = L.slack or 0.025
  slack = clamp(slack, 0, 0.2)
  local blend = L.blend or 0.35
  blend = clamp(blend, 0, 1)

  --- Typical AH pressure vs DBMarket: do not bid above min(user cap, observed band + slack).
  local marketBound = math.min(baseRatio, ewma + slack)
  return (1 - blend) * baseRatio + blend * marketBound
end

function ScienceAHBot.clear_patterns(root)
  if root and root.Config then
    root.Config.patterns = {}
    Persistence.mark_dirty(root)
  end
end

return ScienceAHBot
