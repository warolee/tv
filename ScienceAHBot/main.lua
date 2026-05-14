--[[ ScienceAHBot — Sylvanas entry (required filename). Wires TSM_Helper + Safety onto runtime table, then Core, UI, Safety hooks. ]]

local ScienceAHBot = require("Config")
local Util = require("Util")

local Persistence = require("Persistence")
Persistence.load_into(ScienceAHBot)

ScienceAHBot.isActive = false
ScienceAHBot.BotActive = false
ScienceAHBot.BotEnabled = false
ScienceAHBot.ManualPause = false

local Runtime = require("Runtime")
Runtime.install(ScienceAHBot)

ScienceAHBot.TSM = require("TSM_Helper")

--- Spec-friendly two-arg profit check (uses live `ScienceAHBot.Config`).
local TSMH = ScienceAHBot.TSM
function ScienceAHBot.IsDeal(itemID, currentPrice)
  return TSMH.IsDeal(itemID, currentPrice, ScienceAHBot.Config)
end

local SafetyLib = require("Safety")
ScienceAHBot.GetGaussianDelay = SafetyLib.GetGaussianDelay
--- Bind the runtime table so `root.GetCognitiveLatency()` (zero-arg
--- style used by all modules) actually pulls `cfg.jitter.cognitive*`
--- from this runtime. Falls back to the legacy 800–1700 ms window
--- when the config keys are absent.
ScienceAHBot.GetCognitiveLatency = function()
  return SafetyLib.GetCognitiveLatency(ScienceAHBot)
end
ScienceAHBot.jitter_button_center = SafetyLib.jitter_button_center
ScienceAHBot.schedule_after = SafetyLib.schedule_after
ScienceAHBot.flush_deferred_after_queue = SafetyLib.flush_deferred_after_queue

local CoreMod = require("Core")
CoreMod.install(ScienceAHBot)

SafetyLib.install(ScienceAHBot)

local UIMod = require("UI")
UIMod.install(ScienceAHBot)

local AuctionOutcome = require("AuctionOutcome")
AuctionOutcome.install(ScienceAHBot)

Util.safe_call("main.loaded", function()
  if core and core.log then
    core.log("[ScienceAHBot] Loaded (settings + patterns: user_settings.lua; optional scan_log.csv)")
  end
end, { root = ScienceAHBot })

local Preflight = require("Preflight")
Util.safe_call("main.Preflight", function()
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
end, { root = ScienceAHBot })
