--[[ MythicMechanicsSuite — World: object_manager and unit helpers.

     All accessors are wrapped in pcall: Sylvanas APIs occasionally
     return nil on a transient frame (loading screens, summoning,
     world-server stalls). Callers should treat any nil from here as
     "skip this tick, the world isn't ready". ]]

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
    return core and core.object_manager and core.object_manager.get_local_player and core.object_manager.get_local_player()
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
  local v = safe("all_units", function()
    if core and core.object_manager and core.object_manager.get_all_units then
      return core.object_manager.get_all_units()
    end
    return nil
  end)
  if v then return v end
  return M.all_objects()
end

function M.all_enemies()
  local v = safe("all_enemies", function()
    if core and core.object_manager and core.object_manager.get_all_enemies then
      return core.object_manager.get_all_enemies()
    end
    return nil
  end)
  if v then return v end
  --- Fallback: filter all_objects() by `:is_enemy()` if present.
  local out = {}
  for _, u in ipairs(M.all_units()) do
    local ok, en = pcall(function() return u.is_enemy and u:is_enemy() end)
    if ok and en then out[#out + 1] = u end
  end
  return out
end

function M.all_players()
  local v = safe("all_players", function()
    if core and core.object_manager and core.object_manager.get_all_players then
      return core.object_manager.get_all_players()
    end
    return nil
  end)
  return v or {}
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
    if unit.get_facing then return unit:get_facing() end
    return nil
  end)
end

function M.npc_id(unit)
  if not unit then return nil end
  return safe("unit.npc_id", function()
    if unit.get_npc_id then return unit:get_npc_id() end
    if unit.get_id then return unit:get_id() end
    if unit.npc_id then return unit:npc_id() end
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
    if unit.get_in_combat then return unit:get_in_combat() end
    return false
  end)
  return ok and v or false
end

--- Active cast info. Returns { spell_id, name, start_time, end_time, channel }
--- or nil if the unit isn't casting/channeling.
function M.active_cast(unit)
  if not unit then return nil end
  local ok, info = pcall(function()
    local id
    if unit.get_active_spell_id then id = unit:get_active_spell_id() end
    if (not id or id == 0) and unit.get_active_channel_spell_id then
      id = unit:get_active_channel_spell_id()
    end
    if not id or id == 0 then return nil end
    local name, start_at, end_at
    if unit.get_active_spell_name then name = unit:get_active_spell_name() end
    if unit.get_active_spell_cast_start_time then start_at = unit:get_active_spell_cast_start_time() end
    if unit.get_active_spell_cast_end_time then end_at = unit:get_active_spell_cast_end_time() end
    return { spell_id = id, name = name, start_at = start_at, end_at = end_at }
  end)
  return ok and info or nil
end

--- Look for a buff/debuff on a unit by spellID. Returns the aura data
--- table from the API or nil. Some builds expose:
---   unit:get_buff_data_by_id(id)
---   unit:get_debuff_data_by_id(id)
---   unit:get_aura_by_id(id)
function M.aura_by_id(unit, id, kind)
  if not unit or not id then return nil end
  local ok, v = pcall(function()
    if kind == "debuff" then
      if unit.get_debuff_data_by_id then return unit:get_debuff_data_by_id(id) end
    elseif kind == "buff" then
      if unit.get_buff_data_by_id then return unit:get_buff_data_by_id(id) end
    end
    if unit.get_aura_by_id then return unit:get_aura_by_id(id) end
    return nil
  end)
  return ok and v or nil
end

--- Convenience: GUID/identity used as a key in tracker tables.
function M.guid(unit)
  if not unit then return nil end
  local ok, v = pcall(function()
    if unit.get_guid then return unit:get_guid() end
    if unit.get_id then return unit:get_id() end
    return tostring(unit)
  end)
  return ok and v or tostring(unit)
end

--- Are we in an instance? Sylvanas exposes either
---   `core.game_ui.get_instance_info()` (table) or just a flag
---   on the local player object. Falls back to "yes" so the suite
---   keeps drawing if the API isn't there.
function M.is_in_instance()
  local ok, v = pcall(function()
    if core and core.game_ui and core.game_ui.get_instance_info then
      local info = core.game_ui.get_instance_info()
      if type(info) == "table" then
        return info.is_in_instance
          or (info.instance_type ~= nil and info.instance_type ~= "none")
      end
    end
    local lp = M.local_player()
    if lp and lp.is_in_instance then return lp:is_in_instance() end
    return nil
  end)
  if v == nil then return true end
  return v and true or false
end

function M.instance_id()
  local ok, v = pcall(function()
    if core and core.game_ui and core.game_ui.get_instance_info then
      local info = core.game_ui.get_instance_info()
      if type(info) == "table" then
        return info.instance_id or info.map_id or info.id
      end
    end
    return nil
  end)
  return ok and v or nil
end

--- Distance helpers for callers that don't want to require Geometry.
function M.dist_xy(a_or_unit, b_or_unit)
  local ap = a_or_unit and (a_or_unit.get_position and a_or_unit:get_position() or a_or_unit) or nil
  local bp = b_or_unit and (b_or_unit.get_position and b_or_unit:get_position() or b_or_unit) or nil
  if not ap or not bp then return math.huge end
  return Geom.dist_xy(ap, bp)
end

return M
