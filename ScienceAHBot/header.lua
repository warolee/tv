--[[ ScienceAHBot — Sylvanas plugin header (required filename).

     Always load. Sylvanas may inject the plugin before `core.object_manager`
     reports a valid local player (e.g. at the login/character-select screen
     or during the first frame after entering the world). If we gated on
     `get_local_player()` here, the plugin would refuse to load and there is
     no path that re-evaluates `header.lua` after login short of a manual
     `/reload`. Instead, defer the "is the player actually playable yet"
     decision to runtime: modules already no-op until `root.isActive` is
     toggled, and event-frame registration in `Safety.install` retries until
     it succeeds (see Safety.lua). ]]

local plugin = {}
plugin.name = "Science AH Bot"
plugin.version = "0.9.1"
plugin.author = "ScienceAHBot"
plugin.load = true

return plugin
