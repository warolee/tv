--[[ MythicMechanicsSuite — Sylvanas entry (required filename).

     Wires modules onto a single runtime table `MMS` returned from
     Config.lua, then registers Sylvanas callbacks:

       core.register_on_update_callback (Tracker + DirgeTracker poll + flush save)
       core.register_on_render_callback (Mechanics world draw + DirgeTracker HUD)
       core.register_on_render_menu_callback (registered from UI.install)

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

--- Optional BigWigs / DBM event bridge. Auto-detects the addons in
--- the WoW global env via `_G.DBM` / `LibStub("AceEvent-3.0")`. When
--- present, subscribes to their bar / message events and routes them
--- through the same Mechanics engine. When absent, silently no-ops.
local BWDBMBridge = require("BWDBMBridge")
BWDBMBridge.install(MMS)

--- UI handles its own register_on_render / on_update / on_render_menu
--- callbacks (Astro window + Sylvanas native menu tree).
UI.install(MMS)

--- Optional Midnight Falls "Death's Dirge" sequence HUD (same folder).
local DirgeTracker = nil
do
  local ok, DT = pcall(require, "DirgeTracker")
  if ok and DT and DT.install then
    DirgeTracker = DT
    DT.install(MMS)
  end
end

--- main.lua's own update tick is for the engine: tracker poll, optional
--- DirgeTracker poll, persistence debounce. The Astro UI registers its
--- own update callback inside UI.install (Sylvanas may chain multiple
--- handlers or replace the slot per build — Dirge intentionally shares
--- this callback to avoid being dropped).
local function on_update()
  Util.try("main.on_update", function()
    Tracker.tick(MMS)
    if DirgeTracker and DirgeTracker.tick then DirgeTracker.tick() end
    Persistence.try_flush(MMS)
  end, { root = MMS })
end

--- Engine render: world-space mechanic warnings, then Dirge HUD. The
--- Astro window is drawn by its own render callback inside UI.install.
local function on_render()
  Util.try("main.on_render", function()
    Mechanics.render(MMS)
    if DirgeTracker and DirgeTracker.render then DirgeTracker.render() end
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
  end
end)

Util.try("main.loaded", function()
  if core and core.log then
    core.log("[MythicMechanicsSuite] Loaded v0.6.0-appearance (Midnight 12.0.5; routing + theme presets)")
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

--- Best-effort: flush settings to scripts_data on unload so a quick
--- `/reload` right after editing does not skip the debounced save.
pcall(function()
  if not core then return end
  local reg = core.register_on_unload_callback
      or core.register_on_plugin_unload_callback
      or core.register_unload_callback
  if type(reg) == "function" then
    reg(function()
      Persistence.flush_now(MMS)
    end)
  end
end)

return MMS
