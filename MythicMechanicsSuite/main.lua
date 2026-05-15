--[[ MythicMechanicsSuite — Sylvanas entry (required filename).

     Wires modules onto a single runtime table `MMS` returned from
     Config.lua, then registers Sylvanas callbacks:

       core.register_on_update_callback (poll Tracker + flush save)
       core.register_on_render_callback (draw active warnings)
       core.register_on_render_menu_callback (native menu + overlay)

     Every callback body is wrapped through Util.safe_call so a bug
     in one mechanic never crashes the render thread. ]]

local MMS = require("Config")
local Util = require("Util")

local Persistence = require("Persistence")
Persistence.load_into(MMS)

local Tracker    = require("Tracker")
local Mechanics  = require("Mechanics")
local UI         = require("UI")
local Preflight  = require("Preflight")

Tracker.install(MMS)
Mechanics.install(MMS)
UI.install_native_menu(MMS)
UI.install_overlay(MMS)

--- update tick: tracker poll + persistence flush
local function on_update()
  Util.try("main.on_update", function()
    Tracker.tick(MMS)
    Persistence.try_flush(MMS)
  end, { root = MMS })
end

--- render tick: mechanics drawings + overlay UI
local function on_render()
  Util.try("main.on_render", function()
    Mechanics.render(MMS)
    UI.tick(MMS)
  end, { root = MMS })
end

pcall(function()
  if core and core.register_on_update_callback then
    core.register_on_update_callback(on_update)
  end
end)

pcall(function()
  if core and core.register_on_render_callback then
    core.register_on_render_callback(on_render)
  elseif core and core.register_on_render_menu_callback then
    --- Fallback for older builds that drive the world overlay through
    --- the same callback as the menu. Mechanics.render handles a
    --- missing 3D context by silently no-oping.
    core.register_on_render_menu_callback(on_render)
  end
end)

Util.try("main.loaded", function()
  if core and core.log then
    core.log("[MythicMechanicsSuite] Loaded v0.1.0 (raids + mythic+ overlay)")
  end
end, { root = MMS })

Util.try("main.preflight", function()
  local warns = Preflight.collect_warnings(MMS)
  for i = 1, #warns do
    local msg = "[MythicMechanicsSuite] Preflight: " .. tostring(warns[i])
    if core then
      if warns[i]:find("Loaded", 1, true) and core.log then
        core.log(msg)
      elseif core.log_warning then
        core.log_warning(msg)
      end
    end
  end
end, { root = MMS })

return MMS
