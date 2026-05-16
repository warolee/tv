--[[ MythicMechanicsSuite — BigWigs / Deadly Boss Mods event bridge.

     Optional, additive layer that subscribes to BigWigs and DBM
     warnings (as emitted in the WoW addon environment) and translates
     them into MMS active warnings. It helps when:

       1. A dungeon/raid build skews spell ids vs the shipped data
          tables — BW/DBM often tracks the live client ids.
       2. BW/DBM timing is pre-cast (e.g. "Crimson Rain in 4s"), which
          can be more useful than polled "boss is casting right now"
          detection alone.

     This module does NOT replace the data-driven engine. It runs in
     parallel: if a spell id from a bridge event matches an entry in
     the encounter registry, we spawn the registered shape (circle,
     cone, beam, ...) with BW/DBM's reported duration. If it doesn't
     match and `mirror.generic_fallback` is true, we spawn a generic
     3D text warning above the local player using the event's
     message text. The Tracker is suppressed for that spell id for a
     short window (`mirror.dedupe_window`) so a real cast that lights
     up both paths only renders once.

     Build-skew guard: every `_G` access is wrapped in `pcall` because
     Sylvanas builds vary in how they expose the WoW addon environment
     (some plugins see `_G.DBM` as a direct global, some need
     `core.game_ui.get_global_env()`, some don't expose it at all).
     If anything fails, we silently no-op — the engine keeps working
     from the data files. ]]

local M = {}

local Util       = require("Util")
local Encounters = require("Encounters")
local Mechanics  = require("Mechanics")
local World      = require("World")

----------------------------------------------------------------------
-- Global env access
----------------------------------------------------------------------

--- Try several ways to reach the WoW addon-side globals. Falls back
--- to plain `_G` (which is correct on the builds where the Sylvanas
--- plugin VM and WoW's FrameXML share an env).
local function global_env()
  local env = _G
  pcall(function()
    if core and core.game_ui and core.game_ui.get_global_env then
      local g = core.game_ui.get_global_env()
      if type(g) == "table" then env = g end
    end
  end)
  return env or {}
end

local function g_get(name)
  local g = global_env()
  local ok, v = pcall(function() return g[name] end)
  return ok and v or nil
end

----------------------------------------------------------------------
-- Detection
----------------------------------------------------------------------

function M.has_dbm()
  local d = g_get("DBM")
  return type(d) == "table" and type(d.RegisterCallback) == "function"
end

function M.has_bigwigs()
  --- BigWigsLoader is the canonical message bus. Some forks/versions
  --- only expose `BigWigs` (without Loader); we accept either if it
  --- still goes through AceEvent-3.0.
  local libstub = g_get("LibStub")
  if type(libstub) == "function" then
    local ok, ace = pcall(libstub, "AceEvent-3.0", true)
    if ok and type(ace) == "table" then return true end
  end
  local bw = g_get("BigWigsLoader") or g_get("BigWigs")
  return type(bw) == "table"
end

function M.dbm_version()
  local d = g_get("DBM")
  if type(d) ~= "table" then return nil end
  local v = d.DisplayVersion or d.Version or d.version
  if type(v) == "string" or type(v) == "number" then return tostring(v) end
  return "?"
end

function M.bw_version()
  local libstub = g_get("LibStub")
  if type(libstub) == "function" then
    local ok, _, v = pcall(libstub, "BigWigs-3.0", true)
    if ok and v then return tostring(v) end
  end
  return g_get("BigWigsLoader") and "?" or nil
end

----------------------------------------------------------------------
-- Spawn helper — used by both DBM and BW translation paths.
----------------------------------------------------------------------

local function color_for(root, kind, fallback)
  local c = root.Config and root.Config.colors and root.Config.colors[kind]
  return c or fallback or { r = 235, g = 60, b = 60, a = 235 }
end

local function suppress(root, spell_id, until_at)
  if not spell_id then return end
  root._mms_bridge_suppress = root._mms_bridge_suppress or {}
  root._mms_bridge_suppress[spell_id] = math.max(until_at or 0, root._mms_bridge_suppress[spell_id] or 0)
end

--- Returns true if `(spell_id, unit)` already has an active entry
--- spawned within the last second, so we don't double up when the
--- Tracker catches the same cast a tick later.
local function already_active(root, spell_id, source_label)
  if not spell_id then return false end
  local now = Util.now_seconds()
  for _, e in ipairs(Mechanics.active(root) or {}) do
    if e.mech and e.mech.spellID == spell_id then
      if (now - (e.spawned_at or 0)) < 1.0 then
        return true
      end
    end
    if e.source == source_label and e.mech and e.mech._bridge_spell_id == spell_id then
      return true
    end
  end
  return false
end

local function spawn_for_spell(root, spell_id, duration, source_label, message_text)
  local cfg = root.Config or {}

  --- Data-source routing: when the user has chosen "HardcodedOnly"
  --- the bridge is a pass-through observer — we acknowledge BW/DBM
  --- events for detection purposes but never spawn warnings from
  --- them. The local Tracker is the sole source of truth.
  local mode = cfg.behavior and cfg.behavior.dataSource or "Auto"
  if mode == "HardcodedOnly" then return end

  local lp = World.local_player()
  local now = Util.now_seconds()
  local dur = tonumber(duration)
  if not dur or dur <= 0 then
    dur = (cfg.mirror and cfg.mirror.fallback_duration) or 3.0
  end

  if already_active(root, spell_id, source_label) then
    return
  end

  --- 1) Spell id matches our registry → spawn the registered shape(s).
  if spell_id then
    local matches = Encounters.lookup_by_cast(spell_id) or Encounters.lookup_by_aura(spell_id)
    if matches and #matches > 0 then
      for _, pair in ipairs(matches) do
        local enc, mech = pair.enc, pair.mech
        if Encounters.is_enabled(cfg, enc, mech) then
          local entry = {
            enc        = enc,
            mech       = mech,
            unit       = lp,
            spawned_at = now,
            expires_at = now + dur,
            color      = color_for(root, mech.color or "danger"),
            radius     = mech.radius or (cfg.draw and cfg.draw.defaultRadius) or 6.0,
            length     = mech.length or 30.0,
            width      = mech.width or (mech.type == "cone" and (math.pi * 0.5)) or 4.0,
            kind       = "bridge",
            source     = source_label,
          }
          table.insert(Mechanics.active(root), entry)
        end
      end
      local dedupe = (cfg.mirror and cfg.mirror.dedupe_window) or 8.0
      suppress(root, spell_id, now + dedupe)
      if cfg.debug and cfg.debug.logEvents and core and core.log then
        core.log(string.format(
          "[MythicMechanicsSuite][%s] spawn via registry: spell=%d dur=%.1fs",
          source_label, spell_id, dur
        ))
      end
      return
    end
  end

  --- 2) No registry match → generic fallback text warning, if enabled.
  if not (cfg.mirror and cfg.mirror.generic_fallback) then
    return
  end
  local fake_enc  = { id = "bridge_" .. source_label, name = source_label }
  local fake_mech = {
    id        = "bridge_spell_" .. tostring(spell_id or "anon"),
    spellID   = spell_id,
    _bridge_spell_id = spell_id,
    type      = "text",
    priority  = "medium",
    name      = message_text or (source_label .. " warning"),
    color     = "danger",
    duration  = dur,
  }
  table.insert(Mechanics.active(root), {
    enc        = fake_enc,
    mech       = fake_mech,
    unit       = lp,
    spawned_at = now,
    expires_at = now + dur,
    color      = color_for(root, "danger"),
    radius     = 4.0,
    length     = 30.0,
    width      = 4.0,
    kind       = "bridge_generic",
    source     = source_label,
  })
  if spell_id then
    local dedupe = (cfg.mirror and cfg.mirror.dedupe_window) or 8.0
    suppress(root, spell_id, now + dedupe)
  end
end

----------------------------------------------------------------------
-- DBM subscription
----------------------------------------------------------------------

local function install_dbm(root)
  if not M.has_dbm() then return false, "not loaded" end
  local DBM = g_get("DBM")
  local listener = {}
  root._mms_dbm_listener = listener

  local function bar_start(_event, id, msg, time, icon, type_, spellId)
    if not (root.Config and root.Config.mirror and root.Config.mirror.dbm) then return end
    Util.try("BWDBMBridge.dbm.TimerStart", function()
      spawn_for_spell(root, tonumber(spellId), tonumber(time), "DBM", tostring(msg or ""))
    end, { root = root })
  end

  local function announce(_event, msg, icon, type_, spellId, level)
    if not (root.Config and root.Config.mirror and root.Config.mirror.dbm) then return end
    Util.try("BWDBMBridge.dbm.Announce", function()
      spawn_for_spell(root, tonumber(spellId), nil, "DBM", tostring(msg or ""))
    end, { root = root })
  end

  local ok = true
  ok = ok and pcall(function() DBM:RegisterCallback("DBM_TimerStart", bar_start) end)
  ok = ok and pcall(function() DBM:RegisterCallback("DBM_Announce",   announce) end)
  --- TimerStop / SetStage / Pull / Kill are nice-to-haves but not
  --- required for warning rendering — the entries expire on their
  --- own when `expires_at` passes. Skip them to keep the surface
  --- area minimal.
  return ok, ok and "subscribed" or "register-failed"
end

----------------------------------------------------------------------
-- BigWigs subscription (via AceEvent-3.0)
----------------------------------------------------------------------

local function install_bigwigs(root)
  if not M.has_bigwigs() then return false, "not loaded" end
  local libstub = g_get("LibStub")
  if type(libstub) ~= "function" then return false, "no LibStub" end
  local ok_ace, AceEvent = pcall(libstub, "AceEvent-3.0", true)
  if not ok_ace or type(AceEvent) ~= "table" then return false, "no AceEvent-3.0" end

  local listener = root._mms_bw_listener or {}
  root._mms_bw_listener = listener
  pcall(function() AceEvent:Embed(listener) end)
  if type(listener.RegisterMessage) ~= "function" then
    return false, "embed-failed"
  end

  local function start_bar(_event, mod, key, text, duration, icon, isApprox)
    if not (root.Config and root.Config.mirror and root.Config.mirror.bigwigs) then return end
    Util.try("BWDBMBridge.bw.StartBar", function()
      --- BigWigs `key` is normally the spell id (or its negative, for
      --- engage-only bars). Coerce defensively.
      local spell_id
      if type(key) == "number" then spell_id = math.abs(key)
      elseif type(key) == "string" then spell_id = tonumber(key) end
      spawn_for_spell(root, spell_id, tonumber(duration), "BW", tostring(text or ""))
    end, { root = root })
  end

  local function message(_event, mod, key, text, color, icon)
    if not (root.Config and root.Config.mirror and root.Config.mirror.bigwigs) then return end
    Util.try("BWDBMBridge.bw.Message", function()
      local spell_id
      if type(key) == "number" then spell_id = math.abs(key)
      elseif type(key) == "string" then spell_id = tonumber(key) end
      spawn_for_spell(root, spell_id, nil, "BW", tostring(text or ""))
    end, { root = root })
  end

  local ok = true
  ok = ok and pcall(function() listener:RegisterMessage("BigWigs_StartBar", start_bar) end)
  ok = ok and pcall(function() listener:RegisterMessage("BigWigs_Message",  message) end)
  return ok, ok and "subscribed" or "register-failed"
end

----------------------------------------------------------------------
-- Public install
----------------------------------------------------------------------

function M.install(root)
  if root._mms_bridge_installed then return end
  root._mms_bridge_installed = true
  root.Config.mirror = root.Config.mirror or {}

  local dbm_ok,  dbm_reason  = install_dbm(root)
  local bw_ok,   bw_reason   = install_bigwigs(root)

  root._mms_bridge = {
    dbm_loaded     = M.has_dbm(),
    bw_loaded      = M.has_bigwigs(),
    dbm_subscribed = dbm_ok,
    bw_subscribed  = bw_ok,
    dbm_reason     = dbm_reason,
    bw_reason      = bw_reason,
    dbm_version    = M.dbm_version(),
    bw_version     = M.bw_version(),
  }

  --- Auto-enable mirrors only when their source is actually loaded and
  --- subscribed. nil → auto, true/false → user override.
  if root.Config.mirror.dbm == nil then
    root.Config.mirror.dbm = dbm_ok and true or false
  end
  if root.Config.mirror.bigwigs == nil then
    root.Config.mirror.bigwigs = bw_ok and true or false
  end

  if core and core.log then
    pcall(function()
      core.log(string.format(
        "[MythicMechanicsSuite] BW/DBM bridge: DBM=%s (%s) BW=%s (%s)",
        dbm_ok and "subscribed" or "off", tostring(dbm_reason),
        bw_ok  and "subscribed" or "off", tostring(bw_reason)
      ))
    end)
  end
end

--- Lightweight status snapshot for the UI / Preflight.
function M.status(root)
  local s = root and root._mms_bridge or {}
  return {
    dbm_loaded     = s.dbm_loaded     or false,
    bw_loaded      = s.bw_loaded      or false,
    dbm_subscribed = s.dbm_subscribed or false,
    bw_subscribed  = s.bw_subscribed  or false,
    dbm_reason     = s.dbm_reason     or "uninstalled",
    bw_reason      = s.bw_reason      or "uninstalled",
    dbm_version    = s.dbm_version    or "-",
    bw_version     = s.bw_version     or "-",
    mirror_dbm     = root and root.Config and root.Config.mirror and root.Config.mirror.dbm,
    mirror_bw      = root and root.Config and root.Config.mirror and root.Config.mirror.bigwigs,
  }
end

--- Public API used by Tracker.lua to skip its own cast/aura spawn if
--- the bridge just handled the same spell within `dedupe_window`.
function M.is_suppressed(root, spell_id)
  if not spell_id then return false end
  local t = root and root._mms_bridge_suppress
  if not t then return false end
  local until_at = t[spell_id]
  if not until_at then return false end
  if Util.now_seconds() < until_at then return true end
  t[spell_id] = nil
  return false
end

return M
