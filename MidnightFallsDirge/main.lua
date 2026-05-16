--[[ MidnightFallsDirge — Sylvanas entry (required filename).

     Registers update + render callbacks for Death's Dirge HUD only. ]]

local ROOT = require("Config")
local Util = require("Util")
local DirgeTracker = require("DirgeTracker")

DirgeTracker.install(ROOT)

local function on_update()
  Util.try("MidnightFallsDirge.on_update", function()
    if DirgeTracker and DirgeTracker.tick then
      DirgeTracker.tick()
    end
  end, { root = ROOT })
end

local function on_render()
  Util.try("MidnightFallsDirge.on_render", function()
    if DirgeTracker and DirgeTracker.render then
      DirgeTracker.render()
    end
  end, { root = ROOT })
end

pcall(function()
  if core and core.register_on_update_callback then
    core.register_on_update_callback(on_update)
  end
end)

pcall(function()
  if core and core.register_on_render_callback then
    core.register_on_render_callback(on_render)
  end
end)

pcall(function()
  if core and core.log then
    core.log("[MidnightFallsDirge] Loaded — Death's Dirge memory helper (standalone)")
  end
end)

return ROOT
