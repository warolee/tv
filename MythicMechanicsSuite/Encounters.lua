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

local function load_table(modpath)
  local ok, mod = pcall(require, modpath)
  if not ok or type(mod) ~= "table" then
    return {}
  end
  if type(mod.encounters) == "table" then
    return mod.encounters
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
