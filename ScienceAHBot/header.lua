--[[ ScienceAHBot — Sylvanas plugin header (required filename). ]]

local plugin = {}
plugin.name = "Science AH Bot"
plugin.version = "0.9.0"
plugin.author = "ScienceAHBot"
plugin.load = true

local local_player = core.object_manager:get_local_player()
if not local_player or not local_player.is_valid or not local_player:is_valid() then
  plugin.load = false
  return plugin
end

return plugin
