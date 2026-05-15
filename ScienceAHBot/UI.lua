--[[ ScienceAHBot UI shell — delegates to AstroUI (astro_custom_ui / core.menu.window). ]]

local UI = {}

local AstroUI = require("AstroUI")

function UI.install(root)
  AstroUI.install(root)
end

return UI
