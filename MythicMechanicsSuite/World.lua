--[[ MythicMechanicsSuite — World: object_manager + unit helpers (real Sylvanas API).

     Verified against the Project Sylvanas API stubs
     (github.com/bluesilvi/project-sylvanas, legacy/_api):

       core.object_manager.get_local_player() / get_all_objects() / get_visible_objects()
       game_object:is_player() / is_unit() / is_dead() / can_attack(o) / is_enemy_with(o)
       game_object:get_name() / get_position() / get_rotation()
       game_object:get_auras() / get_buffs() / get_debuffs()   (buff[] with .buff_id)
       game_object:is_casting_spell() / get_active_spell_id() / get_active_channel_spell_id()
       core.get_instance_id() / get_instance_type() / get_instance_name()

     The platform has NO get_all_players / get_all_enemies / get_aura_by_id and
     NO core.game_ui.get_instance_info — the previous version called those, so
     enemy/player iteration came back empty and aura detection always returned
     nil, which is why the suite "barely worked". Fixed here.

     All accessors are pcall-wrapped: Sylvanas APIs occasionally return nil on a
     transient frame (loading screens, summoning). Treat nil as "skip". ]]

local M = {}

local Util = require("Util")
local Geom = require("Geometry")

local function safe(label, fn)
  local ok, v = pcall(fn)
  if ok then return v end
  return nil
end

function M.local_player()
  return safe("local_player", function()
    return core and core.object_manager and core.object_manager.get_local_player
       and core.object_manager.get_local_player()
  end)
end

function M.all_objects()
  return safe("all_objects", function()
    if core and core.object_manager and core.object_manager.get_all_objects then
      return core.object_manager.get_all_objects()
    end
    return nil
  end) or {}
end

function M.all_units()
  local out = {}
  for _, u in ipairs(M.all_objects()) do
    local ok, v = pcall(function() return u.is_unit and u:is_unit() end)
    if ok and v == true then out[#out + 1] = u end
  end
  return out
end

--- All hostile units. The platform has no get_all_enemies(); filter
--- get_all_objects() by can_attack(localplayer).
function M.all_enemies()
  local lp = M.local_player()
  local out = {}
  for _, u in ipairs(M.all_objects()) do
    local ok_unit, is_u = pcall(function() return u.is_unit and u:is_unit() end)
    if ok_unit and is_u then
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

--- All player game_objects. The platform has no get_all_players(); filter
--- get_all_objects() by is_player().
function M.all_players()
  local out = {}
  for _, u in ipairs(M.all_objects()) do
    local ok, v = pcall(function() return u.is_player and u:is_player() end)
    if ok and v == true then out[#out + 1] = u end
  end
  return out
end

--- Robust position read. Returns nil if unit despawned mid-frame.
function M.position(unit)
  if not unit then return nil end
  return safe("unit.position", function()
    if unit.get_position then return unit:get_position() end
    return nil
  end)
end

function M.rotation(unit)
  if not unit then return nil end
  return safe("unit.rotation", function()
    if unit.get_rotation then return unit:get_rotation() end
    return nil
  end)
end

function M.npc_id(unit)
  if not unit then return nil end
  return safe("unit.npc_id", function()
    if unit.get_npc_id then return unit:get_npc_id() end
    return nil
  end)
end

function M.name(unit)
  if not unit then return nil end
  return safe("unit.name", function()
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

local function spell_name(id)
  local ok, n = pcall(function()
    if core and core.spell_book and core.spell_book.get_spell_name then
      return core.spell_book.get_spell_name(id)
    end
    return nil
  end)
  if ok and type(n) == "string" and n ~= "" then return n end
  return nil
end

--- Active cast/channel info { spell_id, name, start_at, end_at } or nil.
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
      id = unit:get_active_spell_id()
    end
    if not id or id == 0 then return nil end
    local start_at, end_at
    if casting then
      if unit.get_active_spell_cast_start_time then start_at = unit:get_active_spell_cast_start_time() end
      if unit.get_active_spell_cast_end_time then end_at = unit:get_active_spell_cast_end_time() end
    else
      if unit.get_active_channel_cast_start_time then start_at = unit:get_active_channel_cast_start_time() end
      if unit.get_active_channel_cast_end_time then end_at = unit:get_active_channel_cast_end_time() end
    end
    return { spell_id = id, name = spell_name(id), start_at = start_at, end_at = end_at, channel = channelling == true }
  end)
  return ok and info or nil
end

--- Iterate every aura on a unit and call fn(buff_id, buff). Walks the matching
--- list for `kind` ("buff"/"debuff") and falls back to get_auras().
function M.for_each_aura(unit, kind, fn)
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
  if kind == "debuff" then
    walk("get_debuffs")
  elseif kind == "buff" then
    walk("get_buffs")
  else
    walk("get_debuffs")
    walk("get_buffs")
  end
  walk("get_auras")
end

--- Return the buff table for spell `id` on `unit`, or nil. Replaces the old
--- (nonexistent) get_aura_by_id / get_buff_data_by_id path.
function M.aura_by_id(unit, id, kind)
  if not unit or not id then return nil end
  local found
  M.for_each_aura(unit, kind, function(bid, b)
    if not found and bid == id then found = b end
  end)
  return found
end

--- Stable per-session key for a unit. No get_guid on the platform; the userdata
--- identity (tostring) is stable for a unit's lifetime, with name as a backup.
function M.guid(unit)
  if not unit then return nil end
  local nm = M.name(unit)
  if nm and nm ~= "" then return nm .. ":" .. tostring(unit) end
  return tostring(unit)
end

--- Are we in an instance? Uses core.get_instance_type / get_instance_id.
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
  return safe("instance_id", function()
    if core and core.get_instance_id then return core.get_instance_id() end
    return nil
  end)
end

--- Distance helpers for callers that don't want to require Geometry.
function M.dist_xy(a_or_unit, b_or_unit)
  local ap = a_or_unit and (a_or_unit.get_position and a_or_unit:get_position() or a_or_unit) or nil
  local bp = b_or_unit and (b_or_unit.get_position and b_or_unit:get_position() or b_or_unit) or nil
  if not ap or not bp then return math.huge end
  return Geom.dist_xy(ap, bp)
end

return M
