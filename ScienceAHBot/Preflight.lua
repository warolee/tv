--[[ ScienceAHBot — load-time / dashboard preflight messages (no side effects). ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}

--- Dotted-path probe of the `core` runtime API. Returns true iff every
--- segment exists. Mirrors the assumptions made throughout the plugin
--- so a Sylvanas rename / removal is surfaced immediately rather than
--- swallowed by the per-call pcall wrappers.
local function has_core_path(path)
  local node = rawget(_G, "core")
  if node == nil then
    return false
  end
  for seg in string.gmatch(path, "[^.]+") do
    if type(node) ~= "table" then
      return false
    end
    local nxt = node[seg]
    if nxt == nil then
      return false
    end
    node = nxt
  end
  return true
end

--- Functions and tables on `core.*` that the plugin assumes exist.
--- Each entry: { dotted-path, required (bool), human label }.
local CORE_API_PROBES = {
  { "register_on_update_callback", true, "core.register_on_update_callback (engine tick)" },
  { "register_on_render_callback", true, "core.register_on_render_callback (UI render)" },
  { "log", true, "core.log (info logging)" },
  { "log_warning", false, "core.log_warning (warning logging; soft-fallback)" },
  { "graphics", true, "core.graphics (overlay drawing)" },
  { "graphics.rect_2d", false, "core.graphics.rect_2d (overlay outlines)" },
  { "graphics.rect_2d_filled", false, "core.graphics.rect_2d_filled (overlay fills)" },
  { "graphics.text_2d", false, "core.graphics.text_2d (overlay text)" },
  { "input.is_key_pressed", true, "core.input.is_key_pressed (hotkeys / overlay)" },
  { "get_cursor_position", false, "core.get_cursor_position (overlay hit-tests)" },
  { "get_mouse_wheel_delta", false, "core.get_mouse_wheel_delta (overlay scroll)" },
  { "inventory.get_gold", false, "core.inventory.get_gold (gold reserve gate)" },
  { "read_data_file", false, "core.read_data_file (Persistence + ScanLog read)" },
  { "create_data_folder", false, "core.create_data_folder (Persistence + ScanLog write)" },
  { "create_data_file", false, "core.create_data_file (Persistence + ScanLog write)" },
  { "write_data_file", false, "core.write_data_file (Persistence + ScanLog write)" },
  { "time", false, "core.time (timestamps; falls back to GetTime)" },
}

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

  --- Sylvanas runtime probes. Required-but-missing prints as an error
  --- line ("MISSING"); optional-but-missing prints with "optional".
  local missingRequired = {}
  local missingOptional = {}
  for i = 1, #CORE_API_PROBES do
    local p = CORE_API_PROBES[i]
    local path, required, label = p[1], p[2], p[3]
    if not has_core_path(path) then
      if required then
        missingRequired[#missingRequired + 1] = label
      else
        missingOptional[#missingOptional + 1] = label
      end
    end
  end
  for i = 1, #missingRequired do
    lines[#lines + 1] = "core API MISSING: " .. missingRequired[i]
  end
  for i = 1, #missingOptional do
    lines[#lines + 1] = "core API missing (optional): " .. missingOptional[i]
  end

  if not _G.TSM_API or type(_G.TSM_API.GetCustomPriceValue) ~= "function" then
    lines[#lines + 1] = "TradeSkillMaster (TSM addon) not detected — TSM_API / GetCustomPriceValue missing."
    lines[#lines + 1] =
      "Install and enable TradeSkillMaster in WoW/Sylvanas. Without DBMarket prices, Buy/Snipe mostly skip bids and Sell has no baseline price."
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
