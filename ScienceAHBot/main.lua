--[[ ScienceAHBot — Sylvanas entry (required filename). Wires TSM_Helper + Safety onto runtime table, then Core, UI, Safety hooks. ]]

local ScienceAHBot = require("ScienceAHBot/Config")

local Persistence = require("ScienceAHBot/Persistence")
Persistence.load_into(ScienceAHBot)

ScienceAHBot.isActive = false
ScienceAHBot.BotActive = false

ScienceAHBot.TSM = require("ScienceAHBot/TSM_Helper")

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

pcall(function()
  core.log("[ScienceAHBot] Loaded (settings + patterns: user_settings.lua; optional scan_log.csv)")
end)
