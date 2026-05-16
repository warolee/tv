--[[ MythicMechanicsSuite — Encounters registry.

     The data/*.lua files return tables of the form

       {
         {
           id        = 2902,                 -- WoW encounter or NPC id
           name      = "The Bloodbound Horror",
           kind      = "raid" | "mplus",
           zone      = "Nerub-ar Palace",    -- display only
           mechanics = { ... }                -- see below
         },
         ...
       }

     A `mechanic` entry is a plain Lua table. Required fields:

       id       — stable string id, used in cfg.toggles[<enc>:<id>]
       trigger  — "cast" | "aura_apply" | "aura_fade"
       spellID  — int spell id
       type     — drawing shape: "circle" | "cone" | "beam" | "text"
                  | "drop_circle" | "soak_circle" | "spread_circle"
       priority — "low" | "medium" | "high" (controls sound + colour)

     Optional fields (sane defaults exist):

       name       — display name
       radius     — yards (circle / drop_circle / soak_circle / spread)
       length     — yards (cone / beam)
       width      — yards (beam) OR radians (cone)
       anchor     — "caster" (default) | "target" | "player"
       duration   — seconds the drawing lingers after trigger
                    (defaults to cast time for "cast"; aura duration for "aura_apply")
       color      — palette key from Config.colors, or RGBA table
       message    — short text drawn next to the shape and as 2D HUD alert
       sound      — true (use Config.sound.alert) | false | int FDID
       affects_player_only — if true, only fire for auras on the local player
]]

local M = {}

local Util = require("Util")

local REGISTRY = {
  by_encounter_id   = {},
  by_npc_id         = {},
  by_spell_id       = {},        -- spell -> array of { enc, mech }
  by_debuff_id      = {},
  all_encounters    = {},
}

--- Load a data file. Supports two shapes:
---   (1) Flat array of mechanic objects with an `encounter` field
---       (the new Midnight 12.0.5 schema). We re-group by that field
---       and synthesize encounter records on the fly.
---   (2) Legacy `{ encounters = { { id, name, mechanics = {...} } } }`
---       wrapper, or a bare array of encounter records. Returned
---       as-is. Kept for forward compatibility with hand-written
---       fixtures or test data.
local function load_table(modpath)
  local ok, mod = pcall(require, modpath)
  if not ok or type(mod) ~= "table" then
    return {}
  end
  if type(mod.encounters) == "table" then
    return mod.encounters
  end
  --- Distinguish flat-mechanic array vs encounter-record array by
  --- inspecting the first entry: encounter records carry a
  --- `mechanics` field; mechanic rows carry a `spellID` and `trigger`.
  local first = mod[1]
  if type(first) ~= "table" then
    return {}
  end
  if type(first.mechanics) == "table" then
    return mod
  end
  if first.spellID and first.trigger then
    --- Flat array — re-group by `encounter` field.
    local grouped = {}
    local order = {}
    for _, mech in ipairs(mod) do
      local key = mech.encounter or "Unknown"
      if not grouped[key] then
        grouped[key] = {
          id        = key,
          name      = key,
          kind      = modpath:find("raids", 1, true) and "raid" or "mplus",
          mechanics = {},
        }
        order[#order + 1] = key
      end
      table.insert(grouped[key].mechanics, mech)
    end
    local out = {}
    for _, k in ipairs(order) do out[#out + 1] = grouped[k] end
    return out
  end
  return mod
end

local function index_mechanic(enc, mech)
  mech.id = mech.id or (mech.spellID and ("spell_" .. tostring(mech.spellID))) or "anon"
  mech.priority = mech.priority or "medium"
  mech.type = mech.type or "circle"
  mech.trigger = mech.trigger or "cast"
  mech._encounterID = enc.id
  mech._encounterName = enc.name

  if mech.spellID then
    if mech.trigger == "cast" then
      REGISTRY.by_spell_id[mech.spellID] = REGISTRY.by_spell_id[mech.spellID] or {}
      REGISTRY.by_spell_id[mech.spellID][#REGISTRY.by_spell_id[mech.spellID] + 1] = { enc = enc, mech = mech }
    elseif mech.trigger == "aura_apply" or mech.trigger == "aura_fade" then
      REGISTRY.by_debuff_id[mech.spellID] = REGISTRY.by_debuff_id[mech.spellID] or {}
      REGISTRY.by_debuff_id[mech.spellID][#REGISTRY.by_debuff_id[mech.spellID] + 1] = { enc = enc, mech = mech }
    end
  end
end

local function register_encounter(enc)
  if type(enc) ~= "table" or not enc.id then return end
  enc.mechanics = enc.mechanics or {}
  REGISTRY.by_encounter_id[enc.id] = enc
  REGISTRY.all_encounters[#REGISTRY.all_encounters + 1] = enc
  if enc.npc_ids then
    for _, npc in ipairs(enc.npc_ids) do
      REGISTRY.by_npc_id[npc] = enc
    end
  end
  for _, m in ipairs(enc.mechanics) do
    index_mechanic(enc, m)
  end
end

--- Build/refresh registry from `data/*` modules.
function M.load_all()
  REGISTRY = {
    by_encounter_id = {},
    by_npc_id       = {},
    by_spell_id     = {},
    by_debuff_id    = {},
    all_encounters  = {},
  }
  local files = {
    "data/raids_midnight",
    "data/mplus_midnight",
  }
  for _, path in ipairs(files) do
    local list = load_table(path)
    for _, enc in ipairs(list) do
      register_encounter(enc)
    end
  end
  return REGISTRY
end

function M.registry()
  return REGISTRY
end

--- Lookup helpers used by Mechanics.lua.
function M.lookup_by_cast(spell_id)
  return REGISTRY.by_spell_id[spell_id]
end

function M.lookup_by_aura(spell_id)
  return REGISTRY.by_debuff_id[spell_id]
end

function M.lookup_by_npc(npc_id)
  return REGISTRY.by_npc_id[npc_id]
end

function M.all_encounters()
  return REGISTRY.all_encounters
end

--- Resolve a loaded encounter by its `id` (string or number).
function M.encounter_by_id(id)
  if id == nil then return nil end
  return REGISTRY.by_encounter_id[id]
end

--- Astro UI: one tab per instance (see `data/encounter_tab_groups.lua`).
function M.tab_group_manifest()
  local ok, groups = pcall(require, "data/encounter_tab_groups")
  if ok and type(groups) == "table" then return groups end
  return {}
end

--- Toggle key used in `cfg.toggles`.
function M.toggle_key(enc, mech)
  return tostring(enc.id) .. ":" .. tostring(mech.id)
end

function M.is_enabled(cfg, enc, mech)
  local key = M.toggle_key(enc, mech)
  local t = cfg and cfg.toggles
  if type(t) ~= "table" then return true end
  if t[key] == false then return false end
  --- Encounter-wide toggle: "<encID>" without :mech
  if t[tostring(enc.id)] == false then return false end
  return true
end

return M
