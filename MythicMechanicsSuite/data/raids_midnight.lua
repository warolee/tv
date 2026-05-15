--[[ MythicMechanicsSuite — Midnight Season 1 raid mechanic dataset.

     Schema (flat dictionary array):

       {
         encounter = string,   -- boss name (used by Encounters.lua to
                                  group entries into encounter records)
         id        = string,   -- stable mechanic id for cfg.toggles
         spellID   = number,   -- live Midnight raid spell id (Wowhead)
         trigger   = "cast" | "aura_apply",
         type      = "circle" | "cone" | "beam" |
                     "drop_circle" | "soak_circle" | "spread_circle" |
                     "stack_circle",
         radius    = number,   -- yards (for circles) or arc/length
                                  (for cones/beams)
         priority  = "high" | "medium",
         color     = "danger" | "warning" | "info",
         anchor    = "caster" | "target" | "player",
         message   = string,   -- screen text warning
       }

     Spell ids were cross-checked against Wowhead spell pages (titles
     match the encounter ability names from Method.gg raid guides for
     Midnight Season 1). ]]

local M = {}

------------------------------------------------------------------
-- The Voidspire
------------------------------------------------------------------

-- Imperator Averzian

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "dark_upheaval",
  spellID   = 1249251,
  trigger   = "cast",
  type      = "circle",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Move from Dark Upheaval",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "umbral_collapse",
  spellID   = 1249262,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Umbral Collapse",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "shadows_advance",
  spellID   = 1251361,
  trigger   = "cast",
  type      = "beam",
  radius    = 5,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Shadow's Advance — Sidestep",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "void_fall",
  spellID   = 1258883,
  trigger   = "cast",
  type      = "circle",
  radius    = 8,
  priority  = "medium",
  color     = "warning",
  anchor    = "target",
  message   = "Void Fall",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "oblivions_wrath",
  spellID   = 1260712,
  trigger   = "cast",
  type      = "circle",
  radius    = 18,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Oblivion's Wrath",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "blackening_wounds",
  spellID   = 1265540,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 5,
  priority  = "high",
  color     = "danger",
  anchor    = "player",
  message   = "Spread Blackening Wounds",
}

-- Vorasius

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "shadowclaw_slam",
  spellID   = 1241692,
  trigger   = "cast",
  type      = "cone",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Shadowclaw Frontal",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "parasite_expulsion",
  spellID   = 1254199,
  trigger   = "aura_apply",
  type      = "drop_circle",
  radius    = 10,
  priority  = "high",
  color     = "warning",
  anchor    = "target",
  message   = "Drop Parasite Outside",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "void_breath",
  spellID   = 1256855,
  trigger   = "cast",
  type      = "cone",
  radius    = 14,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Void Breath Cone",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "blisterburst",
  spellID   = 1259186,
  trigger   = "cast",
  type      = "circle",
  radius    = 8,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Blisterburst Pools",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "aftershock",
  spellID   = 1273067,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Aftershock",
}

-- Fallen-King Salhadaar

M[#M + 1] = {
  encounter = "Fallen-King Salhadaar",
  id        = "void_convergence",
  spellID   = 1247738,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Void Convergence / Orbs",
}

M[#M + 1] = {
  encounter = "Fallen-King Salhadaar",
  id        = "entropic_unraveling",
  spellID   = 1246175,
  trigger   = "cast",
  type      = "circle",
  radius    = 16,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Entropic Unraveling",
}

M[#M + 1] = {
  encounter = "Fallen-King Salhadaar",
  id        = "despotic_command",
  spellID   = 1248697,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 6,
  priority  = "medium",
  color     = "warning",
  anchor    = "player",
  message   = "Spread Despotic Command",
}

M[#M + 1] = {
  encounter = "Fallen-King Salhadaar",
  id        = "shattering_twilight",
  spellID   = 1253032,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 8,
  priority  = "high",
  color     = "danger",
  anchor    = "player",
  message   = "Shattering Twilight — Spread",
}

M[#M + 1] = {
  encounter = "Fallen-King Salhadaar",
  id        = "twisting_obscurity",
  spellID   = 1250686,
  trigger   = "cast",
  type      = "circle",
  radius    = 8,
  priority  = "medium",
  color     = "warning",
  anchor    = "target",
  message   = "Twisting Obscurity",
}

-- Vaelgor & Ezzorak

M[#M + 1] = {
  encounter = "Vaelgor & Ezzorak",
  id        = "dread_breath",
  spellID   = 1244221,
  trigger   = "cast",
  type      = "cone",
  radius    = 14,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Dread Breath",
}

M[#M + 1] = {
  encounter = "Vaelgor & Ezzorak",
  id        = "nullzone",
  spellID   = 1244672,
  trigger   = "cast",
  type      = "circle",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Nullzone",
}

M[#M + 1] = {
  encounter = "Vaelgor & Ezzorak",
  id        = "nullbeam",
  spellID   = 1262623,
  trigger   = "cast",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Nullbeam",
}

M[#M + 1] = {
  encounter = "Vaelgor & Ezzorak",
  id        = "midnight_flames",
  spellID   = 1249748,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Midnight Flames",
}

M[#M + 1] = {
  encounter = "Vaelgor & Ezzorak",
  id        = "twilight_bond",
  spellID   = 1270189,
  trigger   = "aura_apply",
  type      = "beam",
  radius    = 3,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Twilight Bond — Break Line",
}

M[#M + 1] = {
  encounter = "Vaelgor & Ezzorak",
  id        = "grappling_maw",
  spellID   = 1280458,
  trigger   = "cast",
  type      = "beam",
  radius    = 3,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Grappling Maw",
}

-- Lightblinded Vanguard

M[#M + 1] = {
  encounter = "Lightblinded Vanguard",
  id        = "phase_blades",
  spellID   = 1235246,
  trigger   = "cast",
  type      = "cone",
  radius    = 15,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Phase Blades Frontal",
}

M[#M + 1] = {
  encounter = "Lightblinded Vanguard",
  id        = "searing_radiance",
  spellID   = 1255738,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Searing Radiance",
}

M[#M + 1] = {
  encounter = "Lightblinded Vanguard",
  id        = "blinding_light",
  spellID   = 1258514,
  trigger   = "cast",
  type      = "cone",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Blinding Light Cone",
}

M[#M + 1] = {
  encounter = "Lightblinded Vanguard",
  id        = "light_infused",
  spellID   = 1258659,
  trigger   = "aura_apply",
  type      = "stack_circle",
  radius    = 5,
  priority  = "medium",
  color     = "info",
  anchor    = "player",
  message   = "Stack Light Infused",
}

-- Crown of the Cosmos

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "grasp_of_emptiness",
  spellID   = 1232470,
  trigger   = "cast",
  type      = "soak_circle",
  radius    = 8,
  priority  = "high",
  color     = "info",
  anchor    = "target",
  message   = "Soak Grasp of Emptiness",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "umbral_tether",
  spellID   = 1233470,
  trigger   = "aura_apply",
  type      = "beam",
  radius    = 3,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Umbral Tether",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "null_corona",
  spellID   = 1233865,
  trigger   = "cast",
  type      = "circle",
  radius    = 14,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Null Corona",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "singularity_eruption",
  spellID   = 1235622,
  trigger   = "cast",
  type      = "circle",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Singularity Eruption",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "volatile_fissure",
  spellID   = 1238206,
  trigger   = "aura_apply",
  type      = "drop_circle",
  radius    = 8,
  priority  = "high",
  color     = "warning",
  anchor    = "target",
  message   = "Drop Volatile Fissure",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "void_expulsion",
  spellID   = 1255368,
  trigger   = "cast",
  type      = "cone",
  radius    = 16,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Void Expulsion",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "void_barrage",
  spellID   = 1260000,
  trigger   = "cast",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Void Barrage",
}

------------------------------------------------------------------
-- The Dreamrift
------------------------------------------------------------------

-- Chimaerus, the Undreamt God

M[#M + 1] = {
  encounter = "Chimaerus, the Undreamt God",
  id        = "alndust_upheaval",
  spellID   = 1262289,
  trigger   = "cast",
  type      = "soak_circle",
  radius    = 12,
  priority  = "high",
  color     = "info",
  anchor    = "target",
  message   = "Soak Alndust Upheaval",
}

M[#M + 1] = {
  encounter = "Chimaerus, the Undreamt God",
  id        = "ravenous_dive",
  spellID   = 1245406,
  trigger   = "cast",
  type      = "beam",
  radius    = 5,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Ravenous Dive",
}

M[#M + 1] = {
  encounter = "Chimaerus, the Undreamt God",
  id        = "corrupted_devastation",
  spellID   = 1245486,
  trigger   = "cast",
  type      = "circle",
  radius    = 22,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Corrupted Devastation",
}

M[#M + 1] = {
  encounter = "Chimaerus, the Undreamt God",
  id        = "dissonance",
  spellID   = 1267201,
  trigger   = "aura_apply",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Dissonance — Watch Partner",
}

M[#M + 1] = {
  encounter = "Chimaerus, the Undreamt God",
  id        = "rift_madness",
  spellID   = 1264756,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 8,
  priority  = "medium",
  color     = "warning",
  anchor    = "player",
  message   = "Spread Rift Madness",
}

M[#M + 1] = {
  encounter = "Chimaerus, the Undreamt God",
  id        = "fearsome_cry",
  spellID   = 1249017,
  trigger   = "cast",
  type      = "cone",
  radius    = 18,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Fearsome Cry",
}

------------------------------------------------------------------
-- March on Quel'Danas
------------------------------------------------------------------

-- Belo'ren — Child of Al'ar

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "light_dive",
  spellID   = 1241292,
  trigger   = "cast",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Light Dive",
}

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "voidlight_convergence",
  spellID   = 1242515,
  trigger   = "cast",
  type      = "soak_circle",
  radius    = 10,
  priority  = "high",
  color     = "info",
  anchor    = "target",
  message   = "Soak Voidlight Convergence",
}

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "light_eruption",
  spellID   = 1243852,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Light Eruption",
}

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "death_drop",
  spellID   = 1246709,
  trigger   = "aura_apply",
  type      = "drop_circle",
  radius    = 12,
  priority  = "high",
  color     = "warning",
  anchor    = "player",
  message   = "Drop Death Drop Away",
}

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "light_blast",
  spellID   = 1264696,
  trigger   = "cast",
  type      = "beam",
  radius    = 5,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Light Blast",
}

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "infused_quills",
  spellID   = 1242260,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 6,
  priority  = "medium",
  color     = "warning",
  anchor    = "player",
  message   = "Spread Infused Quills",
}

-- Midnight Falls

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "deaths_dirge",
  spellID   = 1244412,
  trigger   = "cast",
  type      = "circle",
  radius    = 6,
  priority  = "medium",
  color     = "warning",
  anchor    = "target",
  message   = "Death's Dirge",
}

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "heavens_glaives",
  spellID   = 1253915,
  trigger   = "cast",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Heaven's Glaives",
}

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "into_the_darkwell",
  spellID   = 1282034,
  trigger   = "cast",
  type      = "circle",
  radius    = 8,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Into the Darkwell",
}

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "void_cores",
  spellID   = 1282246,
  trigger   = "cast",
  type      = "soak_circle",
  radius    = 6,
  priority  = "high",
  color     = "info",
  anchor    = "target",
  message   = "Soak Void Cores",
}

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "cosmic_fission",
  spellID   = 1282249,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 7,
  priority  = "high",
  color     = "danger",
  anchor    = "player",
  message   = "Spread Cosmic Fission",
}

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "core_harvest",
  spellID   = 1282412,
  trigger   = "cast",
  type      = "cone",
  radius    = 14,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Core Harvest Frontal",
}

M[#M + 1] = {
  encounter = "Midnight Falls",
  id        = "dark_constellation",
  spellID   = 1266388,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "medium",
  color     = "warning",
  anchor    = "target",
  message   = "Dark Constellation",
}

return M
