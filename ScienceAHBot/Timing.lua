--[[ ScienceAHBot — Gaussian scan pacing (delegates to root.GetGaussianDelay when wired). ]]

local ScienceAHBot = {}

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

---@param root table|nil
---@param cfg table
---@param kind "scan"|"cognitive"|"snipe_scan"|"sell_scan"|"undercut_scan"
---@return number
function ScienceAHBot.next_delay(root, cfg, kind)
  local j = cfg.jitter or {}
  local b = cfg.behavior or {}
  local g = root and root.GetGaussianDelay

  local function sample(mean, std, lo, hi)
    local v
    if type(g) == "function" then
      local ok, x = pcall(g, mean, std, lo, hi)
      if ok and type(x) == "number" then
        v = x
      end
    end
    if v == nil then
      v = gaussian(mean, std)
    end
    return clamp(v, lo, hi)
  end

  if kind == "snipe_scan" then
    local s = b.snipe or {}
    return sample(s.scanMeanSeconds or 2.0, s.scanStdSeconds or 0.35, s.scanMinDelay or 1.0, s.scanMaxDelay or 4.0)
  end
  if kind == "sell_scan" then
    local s = b.sell or {}
    return sample(s.scanMeanSeconds or 8.0, s.scanStdSeconds or 1.0, s.scanMinDelay or 5.0, s.scanMaxDelay or 20.0)
  end
  if kind == "undercut_scan" then
    local s = b.undercut or {}
    return sample(s.scanMeanSeconds or 10.0, s.scanStdSeconds or 1.2, s.scanMinDelay or 6.0, s.scanMaxDelay or 25.0)
  end
  if kind == "scan" then
    return sample(j.scanMeanSeconds or 4.5, j.scanStdSeconds or 1.2, j.scanMinDelay or 2.5, j.scanMaxDelay or 8.0)
  end
  return sample(j.cognitiveMeanSeconds or 1.05, j.cognitiveStdSeconds or 0.12, j.cognitiveMinDelay or 0.7, j.cognitiveMaxDelay or 1.4)
end

return ScienceAHBot
