--[[ MidnightFallsDirge — World: object_manager + unit helpers (real Sylvanas API).

     Verified against the Project Sylvanas API stubs
     (github.com/bluesilvi/project-sylvanas, legacy/_api):

       core.object_manager.get_local_player()      -> game_object
       core.object_manager.get_all_objects()       -> game_object[]
       core.object_manager.get_visible_objects()   -> game_object[]
       game_object:is_player() / is_unit() / is_dead() / can_attack(o)
       game_object:get_name() / get_position() / get_rotation()
       game_object:get_auras() / get_buffs() / get_debuffs()   (buff[])
       game_object:is_casting_spell() / get_active_spell_id()
       game_object:get_target_marker_index()

     There is NO get_all_players / get_all_enemies / get_aura_by_id on the
     real platform — the previous version called those (and a combat-log
     callback) which silently returned nothing, so detection never fired.

     Every accessor is pcall-wrapped: Sylvanas APIs occasionally return nil on
     a transient frame (loading screens, summoning). Treat nil as "skip". ]]

local M = {}

local Geom = require("Geometry")

local function safe(fn)
  local ok, v = pcall(fn)
  if ok then return v end
  return nil
end

function M.local_player()
  return safe(function()
    return core and core.object_manager and core.object_manager.get_local_player
       and core.object_manager.get_local_player()
  end)
end

function M.all_objects()
  return safe(function()
    if core and core.object_manager and core.object_manager.get_all_objects then
      return core.object_manager.get_all_objects()
    end
    return nil
  end) or {}
end

function M.visible_objects()
  return safe(function()
    if core and core.object_manager and core.object_manager.get_visible_objects then
      return core.object_manager.get_visible_objects()
    end
    return nil
  end) or M.all_objects()
end

local function is_player(u)
  local ok, v = pcall(function() return u.is_player and u:is_player() end)
  return ok and v == true
end

local function is_unit(u)
  local ok, v = pcall(function() return u.is_unit and u:is_unit() end)
  return ok and v == true
end

--- All player game_objects in range. Filters `get_all_objects()` by
--- `is_player()` because the platform has no `get_all_players()`.
function M.all_players()
  local out = {}
  for _, u in ipairs(M.all_objects()) do
    if is_player(u) then out[#out + 1] = u end
  end
  return out
end

--- All hostile units. Filters `get_all_objects()` by `can_attack(localplayer)`.
function M.all_enemies()
  local lp = M.local_player()
  local out = {}
  for _, u in ipairs(M.all_objects()) do
    if is_unit(u) then
      local ok, en = pcall(function()
        if lp and u.can_attack then return u:can_attack(lp) end
        if lp and u.is_enemy_with then return u:is_enemy_with(lp) end
        return false
      end)
      if ok and en then out[#out + 1] = u end
    end
  end
  return out
end

function M.position(unit)
  if not unit then return nil end
  return safe(function()
    if unit.get_position then return unit:get_position() end
    return nil
  end)
end

function M.rotation(unit)
  if not unit then return nil end
  return safe(function()
    if unit.get_rotation then return unit:get_rotation() end
    return nil
  end)
end

function M.npc_id(unit)
  if not unit then return nil end
  return safe(function()
    if unit.get_npc_id then return unit:get_npc_id() end
    return nil
  end)
end

function M.name(unit)
  if not unit then return nil end
  return safe(function()
    if unit.get_name then return unit:get_name() end
    return nil
  end)
end

function M.is_dead(unit)
  if not unit then return true end
  local ok, v = pcall(function()
    if unit.is_dead then return unit:is_dead() end
    if unit.get_health and unit:get_health() <= 0 then return true end
    return false
  end)
  return ok and v or false
end

function M.health_pct(unit)
  if not unit then return 0 end
  local ok, v = pcall(function()
    local h = (unit.get_health and unit:get_health()) or 0
    local m = (unit.get_max_health and unit:get_max_health()) or 0
    if m > 0 then return (h / m) * 100 end
    return 0
  end)
  return (ok and v) or 0
end

function M.is_in_combat(unit)
  if not unit then return false end
  local ok, v = pcall(function()
    if unit.is_in_combat then return unit:is_in_combat() end
    return false
  end)
  return ok and v or false
end

--- The unit's current raid-target marker index (0 = none, 1-8 markers).
function M.marker_index(unit)
  if not unit then return 0 end
  local ok, v = pcall(function()
    if unit.get_target_marker_index then return unit:get_target_marker_index() end
    return 0
  end)
  return (ok and v) or 0
end

--- Active cast/channel info { spell_id, start_at, end_at } or nil.
function M.active_cast(unit)
  if not unit then return nil end
  local ok, info = pcall(function()
    local casting = unit.is_casting_spell and unit:is_casting_spell()
    local channelling = unit.is_channelling_spell and unit:is_channelling_spell()
    local id
    if casting and unit.get_active_spell_id then id = unit:get_active_spell_id() end
    if (not id or id == 0) and channelling and unit.get_active_channel_spell_id then
      id = unit:get_active_channel_spell_id()
    end
    if (not id or id == 0) and unit.get_active_spell_id then
      --- Some builds report the id without the casting flag; try anyway.
      id = unit:get_active_spell_id()
    end
    if not id or id == 0 then return nil end
    local start_at, end_at
    if unit.get_active_spell_cast_start_time then start_at = unit:get_active_spell_cast_start_time() end
    if unit.get_active_spell_cast_end_time then end_at = unit:get_active_spell_cast_end_time() end
    return { spell_id = id, start_at = start_at, end_at = end_at }
  end)
  return ok and info or nil
end

--- Iterate every aura on a unit and invoke `fn(buff_id, buff)` for each.
--- Walks debuffs + buffs (and `get_auras()` as a fallback). Buff entries
--- expose `.buff_id` per the API.
function M.for_each_aura(unit, fn)
  if not unit or type(fn) ~= "function" then return end
  local function walk(getter)
    local ok, list = pcall(function()
      if unit[getter] then return unit[getter](unit) end
      return nil
    end)
    if ok and type(list) == "table" then
      for _, b in pairs(list) do
        if type(b) == "table" then
          local id = b.buff_id or b.id or b.spell_id
          if id then fn(id, b) end
        end
      end
    end
  end
  walk("get_debuffs")
  walk("get_buffs")
  walk("get_auras")
end

--- Return the buff table for spell `id` on `unit`, or nil. Replaces the old
--- (nonexistent) get_aura_by_id path.
function M.aura_by_id(unit, id)
  if not unit or not id then return nil end
  local found
  M.for_each_aura(unit, function(bid, b)
    if not found and bid == id then found = b end
  end)
  return found
end

--- Stable per-session key for a unit (no get_guid on the platform).
function M.guid(unit)
  if not unit then return nil end
  local nm = M.name(unit)
  if nm and nm ~= "" then return nm end
  return tostring(unit)
end

--- Are we in an instance? Uses core.get_instance_id / get_instance_type.
function M.is_in_instance()
  local ok, v = pcall(function()
    if core and core.get_instance_type then
      local t = core.get_instance_type()
      if type(t) == "string" then return t ~= "" and t ~= "none" end
    end
    if core and core.get_instance_id then
      local id = core.get_instance_id()
      return type(id) == "number" and id ~= 0
    end
    return nil
  end)
  if v == nil then return true end
  return v and true or false
end

function M.instance_id()
  return safe(function()
    if core and core.get_instance_id then return core.get_instance_id() end
    return nil
  end)
end

function M.dist_xy(a_or_unit, b_or_unit)
  local ap = a_or_unit and (a_or_unit.get_position and a_or_unit:get_position() or a_or_unit) or nil
  local bp = b_or_unit and (b_or_unit.get_position and b_or_unit:get_position() or b_or_unit) or nil
  if not ap or not bp then return math.huge end
  return Geom.dist_xy(ap, bp)
end

return M
