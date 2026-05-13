--[[ ScienceAHBot — Sylvanas entry (required filename). Loads Core, overlay UI, Safety. No core.menu. ]]

local AH_Bot = require("ScienceAHBot/Config")

AH_Bot.isActive = false

local CoreMod = require("ScienceAHBot/Core")
CoreMod.install(AH_Bot)

local UIMod = require("ScienceAHBot/UI")
UIMod.install(AH_Bot)

local SafetyMod = require("ScienceAHBot/Safety")
SafetyMod.install(AH_Bot)

pcall(function()
  core.log("[ScienceAHBot] Loaded (Dashboard tab + overlay UI)")
end)
