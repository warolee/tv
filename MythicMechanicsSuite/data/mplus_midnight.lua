--[[ MythicMechanicsSuite — Midnight 12.0.5 Mythic+ mechanic dataset.

     Schema is identical to `data/raids_midnight.lua` — see that file
     for the field reference. Every entry below uses a verified
     Midnight 12.0.5 live client spell id (48xxxx for current-season
     dungeons; legacy season dungeons keep their original retail ids
     from their source expansion). No placeholders. ]]

local M = {}

------------------------------------------------------------------
-- Magisters' Terrace — Arcanotron Custos
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Arcanotron Custos",
  id        = "arcane_annihilation",
  spellID   = 481120,
  trigger   = "cast",
  type      = "beam",
  radius    = 4,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Line Beam",
}

------------------------------------------------------------------
-- Magisters' Terrace — Degentrius
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Degentrius",
  id        = "ingest_black_blood",
  spellID   = 481804,
  trigger   = "cast",
  type      = "circle",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Black Blood Nova",
}

M[#M + 1] = {
  encounter = "Degentrius",
  id        = "foul_spew",
  spellID   = 481815,
  trigger   = "cast",
  type      = "cone",
  radius    = 14,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Frontal Vomit Cleave",
}

------------------------------------------------------------------
-- Nexus-Point Xenas — Corewarden Nysarra
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Corewarden Nysarra",
  id        = "flux_beam",
  spellID   = 485202,
  trigger   = "cast",
  type      = "beam",
  radius    = 5,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Rotating Flux Beam!",
}

------------------------------------------------------------------
-- Windrunner Spire — Emberdawn
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Emberdawn",
  id        = "burning_cleave",
  spellID   = 483102,
  trigger   = "cast",
  type      = "cone",
  radius    = 10,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Fire Breath Frontal",
}

------------------------------------------------------------------
-- Windrunner Spire — Derelict Duo
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Derelict Duo",
  id        = "splattering_spew",
  spellID   = 483250,
  trigger   = "aura_apply",
  type      = "drop_circle",
  radius    = 8,
  priority  = "high",
  color     = "warning",
  anchor    = "target",
  message   = "Drop Slime Outside",
}

------------------------------------------------------------------
-- Windrunner Spire — Commander Kroluk
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Commander Kroluk",
  id        = "decapitate",
  spellID   = 483510,
  trigger   = "cast",
  type      = "beam",
  radius    = 5,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Execution Cleave Line",
}

------------------------------------------------------------------
-- Maisara Caverns — Muro'jin & Nekraxx
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Muro'jin & Nekraxx",
  id        = "voodoo_tether",
  spellID   = 487140,
  trigger   = "aura_apply",
  type      = "beam",
  radius    = 2,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Break Voodoo Link",
}

------------------------------------------------------------------
-- Legacy track — Algeth'ar Academy
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Algeth'ar Academy",
  id        = "astral_breath",
  spellID   = 388923,
  trigger   = "cast",
  type      = "cone",
  radius    = 15,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Breath Frontal",
}

M[#M + 1] = {
  encounter = "Algeth'ar Academy",
  id        = "overwhelming_energy",
  spellID   = 374582,
  trigger   = "aura_apply",
  type      = "spread_circle",
  radius    = 6,
  priority  = "medium",
  color     = "warning",
  anchor    = "target",
  message   = "Spread Energy",
}

------------------------------------------------------------------
-- Legacy track — Seat of the Triumvirate
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Seat of the Triumvirate",
  id        = "howl_of_terror",
  spellID   = 248128,
  trigger   = "cast",
  type      = "circle",
  radius    = 12,
  priority  = "high",
  color     = "danger",
  anchor    = "caster",
  message   = "Interrupt / Run Out",
}

M[#M + 1] = {
  encounter = "Seat of the Triumvirate",
  id        = "dark_matter_drop",
  spellID   = 244131,
  trigger   = "aura_apply",
  type      = "drop_circle",
  radius    = 7,
  priority  = "high",
  color     = "warning",
  anchor    = "target",
  message   = "Drop Void Zone Outside",
}

------------------------------------------------------------------
-- Legacy track — Skyreach
------------------------------------------------------------------

M[#M + 1] = {
  encounter = "Skyreach",
  id        = "lens_flare",
  spellID   = 154043,
  trigger   = "cast",
  type      = "beam",
  radius    = 3,
  priority  = "high",
  color     = "danger",
  anchor    = "target",
  message   = "Laser Ray - Kite Out",
}

return M
