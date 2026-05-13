--[[ ScienceAHBot — Gaussian delays for scan / cognitive pacing. ]]

local AH_Bot = {}

local function gaussian(mean, std)
  local u1 = math.max(math.random(), 1e-12)
  local u2 = math.random()
  local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
  return mean + z0 * std
end

local function clamp(x, lo, hi)
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

---@param cfg table
---@param kind "scan"|"cognitive"|"snipe_scan"|"sell_scan"|"undercut_scan"
---@return number
function AH_Bot.next_delay(cfg, kind)
  local j = cfg.jitter or {}
  local b = cfg.behavior or {}
  if kind == "snipe_scan" then
    local s = b.snipe or {}
    local mean = s.scanMeanSeconds or 2.0
    local std = s.scanStdSeconds or 0.35
    local v = gaussian(mean, std)
    return clamp(v, s.scanMinDelay or 1.0, s.scanMaxDelay or 4.0)
  end
  if kind == "sell_scan" then
    local s = b.sell or {}
    local mean = s.scanMeanSeconds or 8.0
    local std = s.scanStdSeconds or 1.0
    local v = gaussian(mean, std)
    return clamp(v, s.scanMinDelay or 5.0, s.scanMaxDelay or 20.0)
  end
  if kind == "undercut_scan" then
    local s = b.undercut or {}
    local mean = s.scanMeanSeconds or 10.0
    local std = s.scanStdSeconds or 1.2
    local v = gaussian(mean, std)
    return clamp(v, s.scanMinDelay or 6.0, s.scanMaxDelay or 25.0)
  end
  if kind == "scan" then
    local mean = j.scanMeanSeconds or 5.0
    local std = j.scanStdSeconds or 0.65
    local v = gaussian(mean, std)
    return clamp(v, j.scanMinDelay or 3.5, j.scanMaxDelay or 7.0)
  end
  local mean = j.cognitiveMeanSeconds or 1.05
  local std = j.cognitiveStdSeconds or 0.12
  local v = gaussian(mean, std)
  return clamp(v, j.cognitiveMinDelay or 0.7, j.cognitiveMaxDelay or 1.4)
end

return AH_Bot
