--[[ ScienceAHBot — Sylvanas entry (required filename). Wires TSM_Helper + Safety onto runtime table, then Core, UI, Safety hooks. ]]

local ScienceAHBot = require("ScienceAHBot/Config")

local Persistence = require("ScienceAHBot/Persistence")
Persistence.load_into(ScienceAHBot)

ScienceAHBot.isActive = false
ScienceAHBot.BotActive = false
ScienceAHBot.BotEnabled = false
ScienceAHBot.ManualPause = false

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

local AuctionOutcome = require("ScienceAHBot/AuctionOutcome")
AuctionOutcome.install(ScienceAHBot)

pcall(function()
  core.log("[ScienceAHBot] Loaded (settings + patterns: user_settings.lua; optional scan_log.csv)")
end)

local Preflight = require("ScienceAHBot/Preflight")
pcall(function()
  local warns = Preflight.collect_warnings(ScienceAHBot)
  if not warns or #warns == 0 then
    return
  end
  if #warns == 1 and type(warns[1]) == "string" and warns[1]:find("No issues", 1, true) and core and core.log then
    core.log("[ScienceAHBot] Preflight: " .. warns[1])
    return
  end
  for i = 1, #warns do
    if core and core.log_warning then
      core.log_warning("[ScienceAHBot] Preflight: " .. tostring(warns[i]))
    end
  end
end)
