--[[ MythicMechanicsSuite — encounter data: Midnight raid tier (12.0.5).

     Season 1 raids in WoW Midnight (Mar 2026 release):
        - The Voidspire           (6 bosses, Voidstorm)
        - The Dreamrift           (1 boss,  Harandar)
        - March on Quel'Danas     (2 bosses, Isle of Quel'Danas)

     Spell IDs in this file are PLACEHOLDERS in the 1200000+ range
     because Midnight content is too new for public spell-id dumps to
     have stabilized. Every `spellID` in this file is paired with
     `_placeholder = true` so the Preflight module can report how many
     mechanics still need real ids. Drop the real id from
     `/script print(UnitCastingInfo("target"))` or Wowhead into each
     entry and `_placeholder` becomes redundant — leave the flag
     false-y or remove it.

     Mechanic NAMES, types, anchors, radii and priorities are derived
     from public Wowhead / Icy-Veins / Method strategy guides for the
     Midnight Season 1 raids and reflect the actual fight mechanics. ]]

local R = {}

-- Placeholder id allocator: every placeholder gets a unique number
-- in the 1200xxx range so they don't collide with each other.
local _PH = 1200000
local function PH() _PH = _PH + 1; return _PH end

----------------------------------------------------------------------
-- The Voidspire — Voidstorm
----------------------------------------------------------------------

R[#R + 1] = {
  id = 3101,
  name = "Imperator Averzian",
  kind = "raid",
  zone = "The Voidspire",
  mechanics = {
    { id = "void_call",      spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Void Call", radius = 8, priority = "medium",
      color = "danger", anchor = "caster", message = "Soak the void orb" },
    { id = "imperial_decree", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Imperial Decree", length = 50, width = 4,
      priority = "high", color = "line", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3102,
  name = "Vorasius",
  kind = "raid",
  zone = "The Voidspire",
  mechanics = {
    { id = "consuming_dark", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Consuming Dark", radius = 30, priority = "high",
      color = "danger", anchor = "caster", message = "Spread for soak" },
    { id = "void_lance",     spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Void Lance", length = 50, width = 5,
      priority = "medium", color = "line", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3103,
  name = "Fallen-King Salhadaar",
  kind = "raid",
  zone = "The Voidspire",
  mechanics = {
    --- Spawns Concentrated Void orbs from portals; if they reach the
    --- boss it wipes. We render the boss + orb portals as danger.
    { id = "void_convergence",   spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Void Convergence", radius = 6, priority = "high",
      color = "danger", anchor = "caster", message = "Kill the orbs!" },

    --- Spawns adds whose cast creates ground pools.
    { id = "fractured_projection", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Fractured Projection", radius = 6,
      priority = "medium", color = "dropoff", anchor = "caster",
      message = "CC / interrupt the projection" },

    --- Star pattern around the tank; spikes detonate across the room.
    { id = "shattering_twilight", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Shattering Twilight", radius = 6,
      priority = "high", color = "spread", message = "Spread — Twilight!" },

    --- Pulsing circles on players; should run to the edge.
    { id = "despotic_command", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Despotic Command", radius = 8,
      priority = "high", color = "dropoff", message = "Run to the edge!" },

    --- Tank-swap stacking debuff (~8 stacks).
    { id = "destabilizing_strikes", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff",
      type = "text", name = "Destabilizing Strikes (taunt)",
      priority = "medium", color = "danger" },

    --- 100-energy intermission: stand still, take 20s of damage; rotating beams.
    { id = "entropic_unraveling", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Entropic Unraveling", radius = 35,
      priority = "high", color = "danger", anchor = "caster",
      message = "Burst the boss / dodge beams" },
  },
}

R[#R + 1] = {
  id = 3104,
  name = "Vaelgor & Ezzorak",
  kind = "raid",
  zone = "The Voidspire",
  mechanics = {
    --- Targeted cone applying fear; step aside + dispel.
    { id = "dread_breath",   spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Dread Breath", length = 35, width = math.pi * 0.4,
      priority = "high", color = "cone", anchor = "caster", message = "Sidestep + dispel" },

    --- Tail Lash: don't stand behind either boss.
    { id = "tail_lash",      spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Tail Lash (behind)", length = 20, width = math.pi * 0.6,
      priority = "medium", color = "cone", anchor = "caster", message = "Don't stand behind!" },

    --- Tethers pulling players inward; snap by running out.
    { id = "nullbeam",       spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Nullbeam", radius = 10,
      priority = "high", color = "dropoff", message = "Run out to snap tether" },

    --- Orb travels to room edge → pool. 4-5 players soak it.
    { id = "gloom",          spellID = PH(), _placeholder = true, trigger = "cast",
      type = "soak_circle", name = "Gloom (soak)", radius = 8,
      priority = "high", color = "soak", anchor = "caster", message = "Soak the orb" },

    --- Void Howl: spawns Void Orb adds, can be CCed/mass-gripped.
    { id = "void_howl",      spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Void Howl (adds)", radius = 35,
      priority = "medium", color = "danger", anchor = "caster", message = "CC the orbs!" },

    --- Twilight Bond: keep bosses 15+ yards apart.
    { id = "twilight_bond",  spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "buff",
      type = "text", name = "Twilight Bond (separate bosses!)",
      priority = "high", color = "danger" },
  },
}

R[#R + 1] = {
  id = 3105,
  name = "Lightblinded Vanguard",
  kind = "raid",
  zone = "The Voidspire",
  mechanics = {
    { id = "blinding_charge", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Blinding Charge", length = 45, width = 6,
      priority = "high", color = "line", anchor = "caster" },
    { id = "scorching_light", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Scorching Light", radius = 8,
      priority = "medium", color = "dropoff", message = "Drop light away" },
  },
}

R[#R + 1] = {
  id = 3106,
  name = "Crown of the Cosmos",
  kind = "raid",
  zone = "The Voidspire",
  mechanics = {
    --- Arrow circles spawned under targeted players; aim away.
    { id = "grasp_of_emptiness", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Grasp of Emptiness", radius = 6,
      priority = "high", color = "dropoff", message = "Point arrow away from raid!" },

    --- Pools spawning at player locations that detonate.
    { id = "void_expulsion", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Void Expulsion", radius = 6,
      priority = "high", color = "spread", message = "Drop puddle on edge" },

    --- Small adds: killing them applies Corrupting Essence (30% dmg taken).
    { id = "void_droplets", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Void Droplets (don't cleave!)", radius = 5,
      priority = "medium", color = "danger", anchor = "caster" },

    --- Large heal absorb debuffs on 2 players.
    { id = "null_corona", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "text", name = "Null Corona (heal absorb)",
      priority = "medium", color = "danger" },

    --- Alleria's Silverstrike Arrow removes void from targets.
    { id = "silverstrike_arrow", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Silverstrike Arrow (helpful!)", length = 50, width = 3,
      priority = "low", color = "safe", anchor = "caster" },
  },
}

----------------------------------------------------------------------
-- The Dreamrift — Harandar
----------------------------------------------------------------------

R[#R + 1] = {
  id = 3107,
  name = "Chimaerus, the Undreamt God",
  kind = "raid",
  zone = "The Dreamrift",
  mechanics = {
    --- Tank-swap nature damage; splits among soakers.
    { id = "alndust_upheaval", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Alndust Upheaval", radius = 12, priority = "high",
      color = "soak", anchor = "caster", message = "Soak with tank" },

    --- Stacking debuff that amplifies Alndust Upheaval by 600%.
    { id = "rift_vulnerability", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "text", name = "Rift Vulnerability (stacks!)",
      priority = "high", color = "danger" },

    --- Manifestation adds, shielded by Alnshroud in Aln realm.
    { id = "manifestation_adds", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Manifestation Adds", radius = 30,
      priority = "medium", color = "danger", anchor = "caster", message = "Switch realm to kill" },

    --- Rift Emergence: raid-wide nature damage.
    { id = "rift_emergence", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Rift Emergence", radius = 40,
      priority = "high", color = "danger", anchor = "caster", message = "Heal raid up!" },

    --- Dissonance: damage to opposing-realm allies.
    { id = "dissonance", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Dissonance", radius = 8,
      priority = "medium", color = "spread", message = "Move from opposing realm!" },

    --- Phase 2: To the Skies (aerial intermission).
    { id = "to_the_skies", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "text", name = "To the Skies (aerial phase)",
      priority = "medium", color = "danger" },
  },
}

----------------------------------------------------------------------
-- March on Quel'Danas — Isle of Quel'Danas
----------------------------------------------------------------------

R[#R + 1] = {
  id = 3108,
  name = "Belo'ren, Child of Al'ar",
  kind = "raid",
  zone = "March on Quel'Danas",
  mechanics = {
    --- Light or Void feathers at start. Color-matched interrupts.
    { id = "color_assignment", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "buff",
      type = "text", name = "Color Assignment (Light/Void)",
      priority = "high", color = "stack" },

    --- Raid-wide cast only interruptible by matching-color players.
    { id = "colored_interrupt", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Colored Interrupt", radius = 40,
      priority = "high", color = "danger", anchor = "caster", message = "Matching colour interrupts!" },

    --- Eggs that resurrect adds — kill before they hatch.
    { id = "ember_egg", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Ember Egg", radius = 5,
      priority = "medium", color = "danger", anchor = "caster", message = "Smash the egg!" },

    --- Radiant Echoes orbs cross arena; pop with matching color.
    { id = "radiant_echoes", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Radiant Echoes", length = 60, width = 4,
      priority = "medium", color = "line", anchor = "caster", message = "Pop with matching colour" },

    --- Guardian's Edict: tank frontal soak; missing twice → 30% dmg buff.
    { id = "guardians_edict", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Guardian's Edict", length = 30, width = math.pi * 0.4,
      priority = "high", color = "cone", anchor = "caster", message = "Tank: soak with matching colour" },

    --- Phase 2: egg form, 30s vulnerable window.
    { id = "egg_phase", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "text", name = "Egg Phase (burn 30s)",
      priority = "high", color = "danger" },
  },
}

R[#R + 1] = {
  id = 3109,
  name = "Midnight Falls",
  kind = "raid",
  zone = "March on Quel'Danas",
  mechanics = {
    --- Spell mechanics not yet documented in public guides; ship a
    --- minimal placeholder set so the encounter shows up in the
    --- Encounters tab and the user can refine on the fly.
    { id = "starfall",         spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Starfall (room-wide)", radius = 40,
      priority = "high", color = "danger", anchor = "caster" },
    { id = "twilight_descent", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Twilight Descent", length = 50, width = 5,
      priority = "medium", color = "line", anchor = "caster" },
    { id = "void_imprint",     spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Void Imprint", radius = 6,
      priority = "high", color = "dropoff", message = "Drop imprint at edge" },
  },
}

return { encounters = R }
