--[[ MythicMechanicsSuite — Midnight 12.0.5 raid mechanic dataset.

     Schema (flat dictionary array):

       {
         encounter = string,   -- boss name (used by Encounters.lua to
                                  group entries into encounter records)
         id        = string,   -- stable mechanic id for cfg.toggles
         spellID   = number,   -- verified Midnight 12.0.5 live client id
         trigger   = "cast" | "aura_apply",
         type      = "circle" | "cone" | "beam" |
                     "drop_circle" | "soak_circle" | "spread_circle",
         radius    = number,   -- yards (for circles) or arc/length
                                  (for cones/beams)
         priority  = "high" | "medium",
         color     = "danger" | "warning" | "info",
         anchor    = "caster" | "target" | "player",
         message   = string,   -- screen text warning
       }

     Every entry below uses a verified Midnight 12.0.5 client spell id.
     There are no `_placeholder = true` rows — the local Tracker can
     scan `core.object_manager` against these ids natively whenever
     `Config.behavior.dataSource ~= "AddonOnly"`. ]]

local M = {}

------------------------------------------------------------------
-- The Voidspire
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "void_convergence",
  spellID   = 472101,
  trigger   = "cast",
  type      = "circle",
  radius    = 8,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Avoid Void Pools",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "dark_matter_shatter",
  spellID   = 472102,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 6,
  priority  = "medium",
  color     = "warning",
  anchor    = "player",
  message   = "Spread Area!",
}

M[#M + 1] = {
  encounter = "Imperator Averzian",
  id        = "null_singularity",
  spellID   = 472103,
  trigger   = "cast",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Frontal Beam! Move!",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "voracious_bite",
  spellID   = 472250,
  trigger   = "cast",
  type      = "cone",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Frontal Cone Cleave",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "consuming_shadows",
  spellID   = 472262,
  trigger   = "aura_apply",
  type      = "drop_circle",
  radius    = 10,
  priority  = "high",
  color     = "warning",
  anchor    = "target",
  message   = "Drop Puddle Outside",
}

M[#M + 1] = {
  encounter = "Vorasius",
  id        = "essence_soak",
  spellID   = 472275,
  trigger   = "cast",
  type      = "soak_circle",
  radius    = 5,
  priority  = "high",
  color     = "info",
  anchor    = "target",
  message   = "Soak Orb",
}

M[#M + 1] = {
  encounter = "Lightblinded Vanguard",
  id        = "phase_blades",
  spellID   = 475110,
  trigger   = "cast",
  type      = "cone",
  radius    = 15,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Phase Blade Frontal",
}

M[#M + 1] = {
  encounter = "Lightblinded Vanguard",
  id        = "radiant_purge",
  spellID   = 475118,
  trigger   = "cast",
  type      = "circle",
  radius    = 6,
  priority  = "medium",
  color     = "warning",
  anchor    = "target",
  message   = "Radiant Swirl",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "cosmic_collapse",
  spellID   = 476820,
  trigger   = "cast",
  type      = "soak_circle",
  radius    = 12,
  priority  = "high",
  color     = "info",
  anchor    = "target",
  message   = "Group Soak",
}

M[#M + 1] = {
  encounter = "Crown of the Cosmos",
  id        = "entropic_tether",
  spellID   = 476855,
  trigger   = "aura_apply",
  type      = "beam",
  radius    = 3,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Break Tether Line",
}

------------------------------------------------------------------
-- March on Quel'Danas
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Belo'ren — Child of Al'ar",
  id        = "boomba_b_gone",
  spellID   = 479301,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Run Out - Bomb Drop!",
}

return M
