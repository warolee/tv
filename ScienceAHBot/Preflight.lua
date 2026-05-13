--[[ ScienceAHBot — load-time / dashboard preflight messages (no side effects). ]]

local ScienceAHBot = {}

---@param root table
---@return string[]
function ScienceAHBot.collect_warnings(root)
  local lines = {}
  local cfg = root and root.Config
  if type(cfg) ~= "table" then
    lines[#lines + 1] = "Config missing"
    return lines
  end

  local b = cfg.behavior or {}
  local m = b.modules or {}
  local TSM = root.TSM
  local nMain = 0
  if TSM and TSM.GetWatchlistIds then
    local ids = TSM.GetWatchlistIds(cfg)
    if type(ids) == "table" then
      nMain = #ids
    end
  end

  if not _G.TSM_API then
    lines[#lines + 1] = "TSM_API missing — TSM prices will be nil."
  end

  local oki, izi = pcall(require, "common/izi_sdk")
  if not oki or type(izi) ~= "table" then
    lines[#lines + 1] = "common/izi_sdk not loadable."
  elseif not (izi.AH or izi.ah) then
    lines[#lines + 1] = "IZI has no AH table."
  end

  if m.buy and nMain == 0 then
    lines[#lines + 1] = "Buy enabled but Items/watchlist empty."
  end
  if m.snipe then
    local sw = (b.snipe and b.snipe.watchlist) or {}
    if #sw == 0 and nMain == 0 then
      lines[#lines + 1] = "Snipe enabled but snipe + main lists empty."
    end
  end
  if m.sell then
    local swl = (b.sell and b.sell.watchlist) or {}
    if #swl == 0 and nMain == 0 then
      lines[#lines + 1] = "Sell enabled but sell + main lists empty."
    end
  end
  if m.undercut then
    local u = b.undercut or {}
    local rw = u.repostWatchlist or {}
    if not u.useMainWatchlist and #rw == 0 then
      lines[#lines + 1] = "Undercut: repostWatchlist empty and useMainWatchlist off."
    end
  end

  if #lines == 0 then
    lines[#lines + 1] = "No issues detected (still verify TSM + AH in-game)."
  end
  return lines
end

return ScienceAHBot
