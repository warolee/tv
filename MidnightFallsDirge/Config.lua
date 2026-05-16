--[[ MidnightFallsDirge — minimal runtime root returned from `require("Config")`.

     DirgeTracker reads `root.Config.behavior.dataSource`; when set to the
     string `"AddonOnly"` it disables combat-log and poll-driven bookkeeping
     so hardcoded timing cannot race another addon-driven pipeline.

     Keep `"Auto"` unless you know you need `"AddonOnly"`. ]]

local ROOT = {}

ROOT.Config = {
  enabled = true,
  behavior = {
    dataSource = "Auto",
  },
}

return ROOT
