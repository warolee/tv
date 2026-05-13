--[[ ScienceAHBot — Sylvanas entry (required filename). Wires TSM_Helper + Safety onto runtime table, then Core, UI, Safety hooks. ]]

local ScienceAHBot = require("ScienceAHBot/Config")

local Persistence = require("ScienceAHBot/Persistence")
Persistence.load_into(ScienceAHBot)

ScienceAHBot.isActive = false
ScienceAHBot.BotActive = false
ScienceAHBot.BotEnabled = false

ScienceAHBot.TSM = require("ScienceAHBot/TSM_Helper")

--- Spec-friendly two-arg profit check (uses live `ScienceAHBot.Config`).
local TSMH = ScienceAHBot.TSM
function ScienceAHBot.IsDeal(itemID, currentPrice)
  return TSMH.IsDeal(itemID, currentPrice, ScienceAHBot.Config)
end

local SafetyLib = require("ScienceAHBot/Safety")
ScienceAHBot.GetGaussianDelay = SafetyLib.GetGaussianDelay
ScienceAHBot.GetCognitiveLatency = SafetyLib.GetCognitiveLatency
ScienceAHBot.jitter_button_center = SafetyLib.jitter_button_center
ScienceAHBot.schedule_after = SafetyLib.schedule_after

local CoreMod = require("ScienceAHBot/Core")
CoreMod.install(ScienceAHBot)

SafetyLib.install(ScienceAHBot)

local UIMod = require("ScienceAHBot/UI")
UIMod.install(ScienceAHBot)

--- One-shot checks so the first in-game session surfaces misconfiguration in the client log.
local function preflight_log()
  if not core or not core.log_warning then
    return
  end
  local cfg = ScienceAHBot.Config
  if type(cfg) ~= "table" then
    return
  end
  local b = cfg.behavior or {}
  local m = b.modules or {}
  local TSM = ScienceAHBot.TSM
  local nMain = 0
  if TSM and TSM.GetWatchlistIds then
    local ids = TSM.GetWatchlistIds(cfg)
    if type(ids) == "table" then
      nMain = #ids
    end
  end
  if not _G.TSM_API then
    core.log_warning("[ScienceAHBot] Preflight: TSM_API missing — install/enable TSM or prices stay nil.")
  end
  local oki, izi = pcall(require, "common/izi_sdk")
  if not oki or type(izi) ~= "table" then
    core.log_warning("[ScienceAHBot] Preflight: common/izi_sdk not loadable — AH calls will fail.")
  elseif not (izi.AH or izi.ah) then
    core.log_warning("[ScienceAHBot] Preflight: IZI has no AH table — update IZI / check SDK docs.")
  end
  if m.buy and nMain == 0 then
    core.log_warning("[ScienceAHBot] Preflight: Buy enabled but Items/watchlist empty — add items in the UI.")
  end
  if m.snipe then
    local sw = (b.snipe and b.snipe.watchlist) or {}
    if #sw == 0 and nMain == 0 then
      core.log_warning("[ScienceAHBot] Preflight: Snipe enabled but snipe watchlist and main list are empty.")
    end
  end
  if m.sell then
    local swl = (b.sell and b.sell.watchlist) or {}
    if #swl == 0 and nMain == 0 then
      core.log_warning("[ScienceAHBot] Preflight: Sell enabled but sell watchlist and main list are empty.")
    end
  end
  if m.undercut then
    local u = b.undercut or {}
    local rw = u.repostWatchlist or {}
    if not u.useMainWatchlist and #rw == 0 then
      core.log_warning("[ScienceAHBot] Preflight: Undercut enabled with empty repostWatchlist and useMainWatchlist off — nothing to scan for relist.")
    end
  end
end

pcall(function()
  core.log("[ScienceAHBot] Loaded (settings + patterns: user_settings.lua; optional scan_log.csv)")
end)
pcall(preflight_log)
