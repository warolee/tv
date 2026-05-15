--[[ MythicMechanicsSuite — Tracker: cast + aura detection.

     We don't rely on `COMBAT_LOG_EVENT_UNFILTERED` directly because
     Sylvanas plugins are sandboxed and access to FrameXML events
     varies by build. Instead we poll the object manager at a small
     interval (default 50ms = root.Config.behavior.pollIntervalSec)
     and synthesize the events:

       on_cast_start (unit, spell_id, end_time)
       on_cast_end   (unit, spell_id)        -- includes interrupt/finish
       on_aura_apply (unit, spell_id, kind)  -- kind = "buff" | "debuff"
       on_aura_fade  (unit, spell_id, kind)

     Subscribers register through `tracker.on(event, fn)`. The Mechanics
     module subscribes to all four. ]]

local M = {}

local Util  = require("Util")
local World = require("World")

local CAST_KEY  = "_mms_active_casts"
local AURA_KEY  = "_mms_active_auras"
local NEXT_POLL = "_mms_next_poll_at"
local SUBS_KEY  = "_mms_subs"

local function ensure_state(root)
  root[CAST_KEY] = root[CAST_KEY] or {}
  root[AURA_KEY] = root[AURA_KEY] or {}
  root[SUBS_KEY] = root[SUBS_KEY] or { cast_start = {}, cast_end = {}, aura_apply = {}, aura_fade = {} }
end

local function emit(root, event, a, b, c, d)
  local list = root[SUBS_KEY] and root[SUBS_KEY][event]
  if not list then return end
  for i = 1, #list do
    local fn = list[i]
    Util.try("Tracker.emit." .. event, function() return fn(a, b, c, d) end, { root = root })
  end
end

--- Subscribe to a tracker event. `fn` receives args in this order:
---   cast_start(unit, spell_id, cast_info)
---   cast_end  (unit, spell_id, cast_info)
---   aura_apply(unit, spell_id, kind, aura_info)
---   aura_fade (unit, spell_id, kind, aura_info)
function M.on(root, event, fn)
  ensure_state(root)
  if type(fn) ~= "function" then return end
  root[SUBS_KEY][event] = root[SUBS_KEY][event] or {}
  root[SUBS_KEY][event][#root[SUBS_KEY][event] + 1] = fn
end

--- Returns the list of spellIDs that ANY subscriber currently cares
--- about. Mechanics module fills this; Tracker uses it to skip auras
--- it doesn't have a listener for (cheap and shaves a lot of work in
--- raid where every unit has ~30 buffs).
function M.watched_spell_ids(root)
  return root._mms_watched_spell_ids or {}
end

function M.set_watched_spell_ids(root, ids)
  root._mms_watched_spell_ids = ids or {}
end

--- The actual per-tick poll. Called from Main.lua's update callback.
local function poll(root)
  ensure_state(root)
  local now = Util.now_seconds()

  --- Data-source routing: when the user has chosen "AddonOnly" the
  --- engine relies entirely on the BW/DBM bridge to spawn warnings,
  --- so polling object_manager is pure overhead. Bail out before
  --- any unit iteration. (We still bump NEXT_POLL so the moment the
  --- user flips back to Auto / HardcodedOnly we don't burst-fire.)
  local mode = (root.Config and root.Config.behavior and root.Config.behavior.dataSource) or "Auto"
  if mode == "AddonOnly" then
    --- Drop any in-flight state so we don't replay synthesized
    --- cast_end / aura_fade events for a unit we stopped watching.
    if next(root[CAST_KEY]) or next(root[AURA_KEY]) then
      root[CAST_KEY], root[AURA_KEY] = {}, {}
    end
    root[NEXT_POLL] = now + ((root.Config and root.Config.behavior and root.Config.behavior.pollIntervalSec) or 0.05)
    return
  end

  local interval = (root.Config and root.Config.behavior and root.Config.behavior.pollIntervalSec) or 0.05
  if (root[NEXT_POLL] or 0) > now then return end
  root[NEXT_POLL] = now + interval

  local lp = World.local_player()
  if not lp then
    --- Wipe everything: we're at login/loading. Mechanics that survived
    --- a zone change would otherwise re-fire on the new unit list.
    if next(root[CAST_KEY]) or next(root[AURA_KEY]) then
      root[CAST_KEY], root[AURA_KEY] = {}, {}
    end
    return
  end

  --- Build a set of units to inspect. We always include the local
  --- player (for self-debuffs) plus every enemy currently in
  --- object_manager. Friendly players get inspected when their GUID
  --- is on the watched-debuff list (filled by Mechanics).
  local enemies = World.all_enemies() or {}
  local players = World.all_players() or {}

  ----------------------------------------------------------------------
  -- CASTS
  ----------------------------------------------------------------------
  local seen_casts = {}
  for i = 1, #enemies do
    local u = enemies[i]
    local guid = World.guid(u)
    if guid then
      local info = World.active_cast(u)
      if info and info.spell_id then
        seen_casts[guid] = true
        local prev = root[CAST_KEY][guid]
        if not prev or prev.spell_id ~= info.spell_id then
          if prev then
            emit(root, "cast_end", u, prev.spell_id, prev)
          end
          root[CAST_KEY][guid] = {
            spell_id = info.spell_id,
            name     = info.name,
            start_at = info.start_at or now,
            end_at   = info.end_at,
            unit     = u,
          }
          emit(root, "cast_start", u, info.spell_id, root[CAST_KEY][guid])
        else
          --- Update the end time only (channel duration changes).
          prev.end_at = info.end_at or prev.end_at
          prev.unit = u
        end
      end
    end
  end
  --- Anyone we tracked but no longer reports a cast → cast_end.
  for guid, prev in pairs(root[CAST_KEY]) do
    if not seen_casts[guid] then
      root[CAST_KEY][guid] = nil
      emit(root, "cast_end", prev.unit, prev.spell_id, prev)
    end
  end

  ----------------------------------------------------------------------
  -- AURAS — only spellIDs Mechanics asked to watch.
  ----------------------------------------------------------------------
  local watched = root._mms_watched_spell_ids
  if type(watched) == "table" and next(watched) then
    local seen_auras = {}
    --- A unit list that covers both buffs on the local player /
    --- friendly players (raid-wide debuffs) and on enemies (buffs we
    --- want to dispel/peel).
    local pool = { lp }
    for i = 1, #players do pool[#pool + 1] = players[i] end
    for i = 1, #enemies do pool[#pool + 1] = enemies[i] end

    for i = 1, #pool do
      local u = pool[i]
      local uguid = World.guid(u)
      if uguid then
        for spell_id, kind in pairs(watched) do
          local aura = World.aura_by_id(u, spell_id, kind)
          if aura then
            local key = uguid .. ":" .. tostring(spell_id) .. ":" .. tostring(kind)
            seen_auras[key] = true
            local prev = root[AURA_KEY][key]
            if not prev then
              root[AURA_KEY][key] = { unit = u, spell_id = spell_id, kind = kind, aura = aura, applied_at = now }
              emit(root, "aura_apply", u, spell_id, kind, root[AURA_KEY][key])
            else
              prev.aura = aura
              prev.unit = u
            end
          end
        end
      end
    end
    for key, prev in pairs(root[AURA_KEY]) do
      if not seen_auras[key] then
        root[AURA_KEY][key] = nil
        emit(root, "aura_fade", prev.unit, prev.spell_id, prev.kind, prev)
      end
    end
  end
end

function M.install(root)
  ensure_state(root)
  root._mms_tracker_poll = function()
    Util.try("Tracker.poll", function() poll(root) end, { root = root })
  end
end

function M.tick(root)
  if root._mms_tracker_poll then root._mms_tracker_poll() end
end

return M
