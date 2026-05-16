--[[ MidnightFallsDirge — minimal runtime root returned from `require("Config")`.

     DirgeTracker reads `root.Config.behavior.dataSource`; when set to the
     string `"AddonOnly"` it treats hooks like MMS Addon-only routing (no
     combat-log / poll bookkeeping — avoids conflicting hardcoded timing).

     Standalone installs keep `"Auto"`; tweak here only if you know why. ]]

local ROOT = {}

ROOT.Config = {
  enabled = true,
  behavior = {
    dataSource = "Auto",
  },
}

return ROOT
