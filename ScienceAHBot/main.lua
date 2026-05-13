--[[ ScienceAHBot — Sylvanas entry (required filename). Loads Config, Core, and Safety. ]]

local AH_Bot = require("ScienceAHBot/Config")

AH_Bot.isActive = false

local CoreMod = require("ScienceAHBot/Core")
CoreMod.install(AH_Bot)

local SafetyMod = require("ScienceAHBot/Safety")
SafetyMod.install(AH_Bot)

local TAG = "science_ah_bot_"
local menu_elements = {
  root = core.menu.tree_node(),
  enabled = core.menu.checkbox(false, TAG .. "enabled"),
}

local function sync_enable_from_menu()
  local ok, want = pcall(function()
    return menu_elements.enabled:get_state()
  end)
  if not ok then
    return
  end
  if want and not AH_Bot.isActive then
    AH_Bot.isActive = true
    AH_Bot.state = AH_Bot.STATE_SCANNING
    AH_Bot.nextScanAt = 0
    AH_Bot.uptimeAnchor = nil
    AH_Bot.fatigueUntil = 0
  elseif (not want) and AH_Bot.isActive then
    AH_Bot.isActive = false
    AH_Bot.state = AH_Bot.STATE_IDLE
    AH_Bot.uptimeAnchor = nil
    AH_Bot.TimeEnabled = nil
  end
end

pcall(function()
  core.register_on_render_menu_callback(function()
    menu_elements.root:render("Science AH Bot", function()
      pcall(function()
        menu_elements.enabled:render("Enable bot")
      end)
    end)
  end)
end)

pcall(function()
  core.register_on_update_callback(sync_enable_from_menu)
end)

pcall(function()
  core.log("[ScienceAHBot] Loaded")
end)
