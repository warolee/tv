--[[ MythicMechanicsSuite — Mechanics: runtime engine.

     Subscribes to Tracker events, instantiates "active warnings" for
     every matching encounter mechanic, and runs the per-frame render
     pass through Draw.lua.

     An active warning is a plain Lua table:

       {
         enc        = encounter table
         mech       = mechanic spec from encounter data
         unit       = the unit that triggered it (boss / player)
         spawned_at = seconds
         expires_at = seconds
         color      = resolved RGBA from the palette
         radius     = resolved radius (yards)
         length     = resolved length (yards)
         width      = resolved width (yards or radians for cones)
       }

     The engine keeps a single flat list at root._mms_active.
]]

local M = {}

local Util       = require("Util")
local World      = require("World")
local Geom       = require("Geometry")
local Draw       = require("Draw")
local Tracker    = require("Tracker")
local Encounters = require("Encounters")
local Sound      = require("Sound")

--- BWDBMBridge is loaded lazily here so the bridge can be added/
--- removed without forcing a circular import. The require is
--- pcall-wrapped because a misconfigured plugin install might be
--- missing the file entirely; the engine should still run.
local _bridge
local function bridge()
  if _bridge ~= nil then
    return _bridge or nil
  end
  local ok, mod = pcall(require, "BWDBMBridge")
  _bridge = ok and mod or false
  return _bridge or nil
end

local ACTIVE_KEY = "_mms_active"
local LAST_SOUND_KEY = "_mms_last_sound_per_mech"

local function palette(root, key)
  local c = root.Config and root.Config.colors and root.Config.colors[key]
  return c or { r = 255, g = 255, b = 255, a = 255 }
end

--- Returns a *new* RGBA table with `globalAlphaMult` applied to the
--- alpha channel. We must not mutate the palette entry directly —
--- that's the canonical user-edited color and getting alpha-scaled
--- every frame would compound.
local function with_alpha_mult(root, c)
  local mult = (root.Config and root.Config.appearance and root.Config.appearance.globalAlphaMult) or 1.0
  if mult ~= mult then mult = 1.0 end -- NaN guard
  if mult < 0 then mult = 0 end
  if mult > 4 then mult = 4 end       -- defensive cap so a tampered file can't crash render
  if mult == 1.0 then return c end
  local a = math.floor(((c.a or 255) * mult) + 0.5)
  if a < 0 then a = 0 end
  if a > 255 then a = 255 end
  return { r = c.r or 255, g = c.g or 255, b = c.b or 255, a = a }
end

local function resolve_color(root, enc, mech)
  local cfg = root.Config or {}
  local key = enc and mech and Encounters.toggle_key(enc, mech) or nil
  local po = key and cfg.mechanicPalettes and cfg.mechanicPalettes[key]
  local base
  if type(po) == "string" and po ~= "" then
    base = palette(root, po)
  else
    local c = mech.color
    if type(c) == "table" then
      base = c
    elseif type(c) == "string" then
      base = palette(root, c)
    elseif mech.type == "drop_circle" then base = palette(root, "dropoff")
    elseif mech.type == "soak_circle" then base = palette(root, "soak")
    elseif mech.type == "spread_circle" then base = palette(root, "spread")
    elseif mech.type == "stack_circle" then base = palette(root, "stack")
    elseif mech.type == "cone" then base = palette(root, "cone")
    elseif mech.type == "beam" then base = palette(root, "line")
    else base = palette(root, "danger")
    end
  end
  return with_alpha_mult(root, base)
end

--- Used by BWDBMBridge so addon-spawned rows respect `mechanicPalettes`.
function M.color_for_mech(root, enc, mech)
  return resolve_color(root, enc, mech)
end

local function maybe_sound(root, enc, mech)
  if mech.sound == false then return end
  local s = root.Config and root.Config.sound
  if not s or not s.enabled then return end
  local fdid
  if type(mech.sound) == "number" then
    fdid = mech.sound
  else
    fdid = s.alert
  end
  if not fdid then return end
  root[LAST_SOUND_KEY] = root[LAST_SOUND_KEY] or {}
  local key = Encounters.toggle_key(enc, mech)
  local now = Util.now_seconds()
  local last = root[LAST_SOUND_KEY][key] or 0
  if now - last < (s.perMechanic or 4.0) then return end
  root[LAST_SOUND_KEY][key] = now
  Sound.play(fdid)
end

local function infer_duration(cast_info, mech)
  if mech.duration then return mech.duration end
  if cast_info and cast_info.end_at and cast_info.start_at then
    local d = cast_info.end_at - cast_info.start_at
    if d > 0 then return d end
  end
  return 5.0
end

local function spawn(root, enc, mech, unit, info, kind)
  local cfg = root.Config or {}
  local now = Util.now_seconds()
  local active = root[ACTIVE_KEY]

  local defaultR = (cfg.draw and cfg.draw.defaultRadius) or 6.0
  local radius = mech.radius
  if radius == nil then radius = defaultR end

  --- `length` defaults from `radius` for cones/beams when the data row
  --- only specifies `radius` (Midnight raid schema).
  local length = mech.length
  if length == nil and (mech.type == "beam" or mech.type == "cone") and mech.radius ~= nil then
    length = mech.radius
  end
  if length == nil then length = 30.0 end

  local entry = {
    enc        = enc,
    mech       = mech,
    unit       = unit,
    spawned_at = now,
    expires_at = now + (mech.duration or infer_duration(info, mech)),
    color      = resolve_color(root, enc, mech),
    radius     = radius,
    length     = length,
    width      = mech.width  or (mech.type == "cone" and (math.pi * 0.5)) or 4.0,
    kind       = kind,
  }
  --- Cap active list size — drop oldest to make room.
  local cap = (cfg.behavior and cfg.behavior.maxActiveMechanics) or 24
  while #active >= cap do
    table.remove(active, 1)
  end
  active[#active + 1] = entry

  maybe_sound(root, enc, mech)

  if cfg.debug and cfg.debug.logEvents and core and core.log then
    core.log(string.format(
      "[MythicMechanicsSuite] %s :: %s (%s) on %s",
      tostring(enc.name or enc.id),
      tostring(mech.name or mech.id),
      tostring(kind or mech.trigger),
      tostring(World.name(unit) or "?")
    ))
  end
end

--- Source-routing gate: when `dataSource = "AddonOnly"` the local
--- Tracker is not allowed to spawn warnings — only BW/DBM bridge
--- events render. `"HardcodedOnly"` and `"Auto"` both allow local
--- spawning (the bridge is gated separately in BWDBMBridge).
local function local_spawn_allowed(root)
  local mode = root.Config and root.Config.behavior and root.Config.behavior.dataSource
  return mode ~= "AddonOnly"
end

local function on_cast_start(unit, spell_id, info)
  local matches = Encounters.lookup_by_cast(spell_id)
  if not matches then return end
  local root = M._root
  if not root then return end
  if not local_spawn_allowed(root) then return end
  --- If BW/DBM already handled this spell in the last few seconds,
  --- skip the polled spawn so we don't double-draw.
  local br = bridge()
  if br and br.is_suppressed(root, spell_id) then return end
  for i = 1, #matches do
    local enc, mech = matches[i].enc, matches[i].mech
    if Encounters.is_enabled(root.Config, enc, mech) then
      spawn(root, enc, mech, unit, info, "cast_start")
    end
  end
end

local function on_cast_end(unit, spell_id, info)
  --- Optional: remove cast-bound warnings that should disappear when
  --- the cast finishes/cancels. We keep them around for `duration`
  --- so post-cast effects (debris falling, ground fires) still warn.
  --- If a mechanic explicitly sets `removeOnCastEnd = true`, drop it.
  local root = M._root
  if not root then return end
  local active = root[ACTIVE_KEY]
  for i = #active, 1, -1 do
    local e = active[i]
    if e.mech.spellID == spell_id and e.unit == unit and e.mech.removeOnCastEnd then
      table.remove(active, i)
    end
  end
end

local function on_aura_apply(unit, spell_id, kind, aura_info)
  local matches = Encounters.lookup_by_aura(spell_id)
  if not matches then return end
  local root = M._root
  if not root then return end
  if not local_spawn_allowed(root) then return end
  local br = bridge()
  if br and br.is_suppressed(root, spell_id) then return end
  local lp = World.local_player()
  for i = 1, #matches do
    local enc, mech = matches[i].enc, matches[i].mech
    if mech.trigger == "aura_apply" and Encounters.is_enabled(root.Config, enc, mech) then
      if not mech.affects_player_only or unit == lp then
        spawn(root, enc, mech, unit, aura_info, "aura_apply")
      end
    end
  end
end

local function on_aura_fade(unit, spell_id, kind, aura_info)
  local root = M._root
  if not root then return end
  local active = root[ACTIVE_KEY]
  for i = #active, 1, -1 do
    local e = active[i]
    if e.mech.spellID == spell_id and e.unit == unit and e.mech.trigger == "aura_apply" then
      if e.mech.removeOnAuraFade ~= false then
        table.remove(active, i)
      end
    end
  end

  local matches = Encounters.lookup_by_aura(spell_id)
  if not matches then return end
  for i = 1, #matches do
    local enc, mech = matches[i].enc, matches[i].mech
    if mech.trigger == "aura_fade" and Encounters.is_enabled(root.Config, enc, mech) then
      spawn(root, enc, mech, unit, aura_info, "aura_fade")
    end
  end
end

--- Build the spell-id watch list and hand it to the Tracker so it
--- only inspects auras Mechanics actually care about.
local function compute_watched(root)
  local watched = {}
  for _, enc in ipairs(Encounters.all_encounters()) do
    for _, mech in ipairs(enc.mechanics or {}) do
      if mech.spellID and (mech.trigger == "aura_apply" or mech.trigger == "aura_fade") then
        watched[mech.spellID] = mech.aura_kind or "debuff"
      end
    end
  end
  Tracker.set_watched_spell_ids(root, watched)
end

--- Per-frame: prune expired entries + render survivors.
local function render(root)
  local cfg = root.Config or {}
  if not cfg.enabled then return end
  if cfg.instanceOnly and not World.is_in_instance() then return end

  local active = root[ACTIVE_KEY]
  if not active or #active == 0 then return end

  local lp = World.local_player()
  local now = Util.now_seconds()
  local draw_cfg = cfg.draw or {}

  for i = #active, 1, -1 do
    local e = active[i]
    if e.expires_at and now >= e.expires_at then
      table.remove(active, i)
    elseif cfg.behavior and cfg.behavior.dropOnAnchorGone and World.is_dead(e.unit) then
      table.remove(active, i)
    else
      local anchor_unit = e.unit
      if e.mech.anchor == "player" then anchor_unit = lp end
      if e.mech.anchor == "target" then
        local ok, tgt = pcall(function() return e.unit.get_target and e.unit:get_target() end)
        if ok and tgt then anchor_unit = tgt end
      end

      local pos = World.position(anchor_unit) or World.position(e.unit)
      if pos then
        local t = e.mech.type or "circle"

        if t == "circle" or t == "danger_circle" then
          Draw.circle_3d(pos, e.radius, e.color,
            draw_cfg.circleThickness, draw_cfg.circleSegments,
            draw_cfg.fillCircles, draw_cfg.fillAlpha)
        elseif t == "drop_circle" or t == "soak_circle" or t == "spread_circle" or t == "stack_circle" then
          Draw.circle_3d(pos, e.radius, e.color,
            draw_cfg.circleThickness, draw_cfg.circleSegments,
            draw_cfg.fillCircles, draw_cfg.fillAlpha)
        elseif t == "cone" then
          local yaw = World.rotation(anchor_unit) or 0
          Draw.cone_3d(pos, yaw, e.length, e.width, e.color,
            draw_cfg.lineThickness, draw_cfg.coneSegments, draw_cfg.coneFilled)
        elseif t == "beam" then
          local yaw = World.rotation(anchor_unit) or 0
          Draw.beam_3d(pos, yaw, e.length, e.width, e.color, draw_cfg.lineThickness)
        elseif t == "text" then
          -- text only handled below
        end

        local prefix = ""
        if e.source then
          prefix = "[" .. tostring(e.source) .. "] "
        end
        if e.mech.message then
          Draw.text_3d(prefix .. e.mech.message, pos, draw_cfg.text3dSize or 16,
            (cfg.colors and cfg.colors.text) or e.color, true)
        elseif e.mech.name then
          local remaining = math.max(0, (e.expires_at or now) - now)
          local label = string.format("%s%s  %.1fs", prefix, tostring(e.mech.name), remaining)
          Draw.text_3d(label, pos, draw_cfg.text3dSize or 16,
            (cfg.colors and cfg.colors.text) or e.color, true)
        end
      end
    end
  end

  --- Debug HUD
  if cfg.debug and cfg.debug.showHUD then
    local g = core and core.graphics
    if g and g.text_2d then
      local Geom = require("Geometry")
      local p = Geom.V2(12, 12)
      Draw.text_2d(string.format("[MMS] active=%d", #active), p, 14, (cfg.colors and cfg.colors.text) or { r=255,g=255,b=255,a=255 })
      for i = 1, math.min(#active, 8) do
        local e = active[i]
        local remaining = math.max(0, (e.expires_at or now) - now)
        Draw.text_2d(
          string.format(" - %s :: %s (%.1fs)", tostring(e.enc.name or e.enc.id), tostring(e.mech.name or e.mech.id), remaining),
          Geom.V2(12, 12 + i * 16), 13,
          (cfg.colors and cfg.colors.text) or { r=255,g=255,b=255,a=255 }
        )
      end
    end
  end
end

function M.install(root)
  root[ACTIVE_KEY] = root[ACTIVE_KEY] or {}
  M._root = root
  Encounters.load_all()
  compute_watched(root)

  Tracker.on(root, "cast_start", on_cast_start)
  Tracker.on(root, "cast_end",   on_cast_end)
  Tracker.on(root, "aura_apply", on_aura_apply)
  Tracker.on(root, "aura_fade",  on_aura_fade)
end

function M.render(root)
  Util.try("Mechanics.render", function() render(root) end, { root = root })
end

function M.clear(root)
  if root then root[ACTIVE_KEY] = {} end
end

function M.active(root)
  return (root and root[ACTIVE_KEY]) or {}
end

--- Recompute the Tracker's watch list after the UI toggles things.
function M.refresh_watch(root)
  compute_watched(root)
end

return M
