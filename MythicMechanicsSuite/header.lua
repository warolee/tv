--[[ MythicMechanicsSuite — Sylvanas plugin header (required filename).

     Always load. The plugin is purely a warning/overlay system: it does
     not move or click anything for you. It registers render and update
     callbacks at startup and only activates mechanic drawings while
     `core.object_manager.get_local_player()` reports a real player AND
     the master enable checkbox is on. Gating on `get_local_player()`
     here would refuse to load on the login/character-select screen with
     no path to retry short of `/reload`. ]]

local plugin = {}
plugin.name = "Mythic Mechanics Suite"
plugin.version = "0.6.0-appearance"
plugin.author = "warolee"
plugin.load = true

return plugin
