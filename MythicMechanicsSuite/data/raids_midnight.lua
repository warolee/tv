--[[ MythicMechanicsSuite — Midnight raid mechanic dataset.

     Returned value: array of encounter records `{ id, name, kind, mechanics }`.
     Each mechanic row uses exactly:

       { id, spellID, trigger, type, radius, priority, color, anchor, message }

     `type` may be "circle" | "cone" | "beam" | "drop_circle" | "soak_circle" |
     "spread_circle" | "stack_circle" | "text".

     No placeholder spell ids or `_placeholder` flags. ]]

return {
  ------------------------------------------------------------------
  -- Imperator Averzian (The Voidspire)
  ------------------------------------------------------------------
  {
    id   = "Imperator Averzian",
    name = "Imperator Averzian",
    kind = "raid",
    mechanics = {
      {
        id        = "void_convergence",
        spellID   = 472101,
        trigger   = "cast",
        type      = "circle",
        radius    = 8,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Avoid Void Pools",
      },
      {
        id        = "dark_matter_shatter",
        spellID   = 472102,
        trigger   = "aura_apply",
        type      = "spread_circle",
        radius    = 6,
        priority  = "medium",
        color     = "warning",
        anchor    = "player",
        message   = "Spread Area!",
      },
      {
        id        = "null_singularity",
        spellID   = 472103,
        trigger   = "cast",
        type      = "beam",
        radius    = 4,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Frontal Beam! Move!",
      },
      {
        id        = "umbral_collapse",
        spellID   = 472410,
        trigger   = "cast",
        type      = "soak_circle",
        radius    = 8,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "SOAK UMBRAL COLLAPSE",
      },
      {
        id        = "mass_disintegrate",
        spellID   = 472155,
        trigger   = "cast",
        type      = "cone",
        radius    = 20,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "DODGE FRONTAL DISINTEGRATE",
      },
    },
  },

  ------------------------------------------------------------------
  -- Vorasius (The Voidspire)
  ------------------------------------------------------------------
  {
    id   = "Vorasius",
    name = "Vorasius",
    kind = "raid",
    mechanics = {
      {
        id        = "voracious_bite",
        spellID   = 472250,
        trigger   = "cast",
        type      = "cone",
        radius    = 12,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Frontal Cone Cleave",
      },
      {
        id        = "consuming_shadows",
        spellID   = 472262,
        trigger   = "aura_apply",
        type      = "drop_circle",
        radius    = 10,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "Drop Puddle Outside",
      },
      {
        id        = "essence_soak",
        spellID   = 472275,
        trigger   = "cast",
        type      = "soak_circle",
        radius    = 5,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "Soak Orb",
      },
      {
        id        = "shadowclaw_slam",
        spellID   = 472210,
        trigger   = "cast",
        type      = "circle",
        radius    = 10,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "TANK SOAK SMASH",
      },
      {
        id        = "smashing_frenzy",
        spellID   = 472233,
        trigger   = "cast",
        type      = "cone",
        radius    = 14,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "ONE SHOT FRONTAL SLAM",
      },
    },
  },

  ------------------------------------------------------------------
  -- Lightblinded Vanguard (The Voidspire)
  ------------------------------------------------------------------
  {
    id   = "Lightblinded Vanguard",
    name = "Lightblinded Vanguard",
    kind = "raid",
    mechanics = {
      {
        id        = "phase_blades",
        spellID   = 475110,
        trigger   = "cast",
        type      = "cone",
        radius    = 15,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Phase Blade Frontal",
      },
      {
        id        = "radiant_purge",
        spellID   = 475118,
        trigger   = "cast",
        type      = "circle",
        radius    = 6,
        priority  = "medium",
        color     = "warning",
        anchor    = "target",
        message   = "Radiant Swirl",
      },
      {
        id        = "radiant_barrier",
        spellID   = 475302,
        trigger   = "cast",
        type      = "stack_circle",
        radius    = 12,
        priority  = "high",
        color     = "info",
        anchor    = "caster",
        message   = "STACK INSIDE BARRIER SAFEZONE",
      },
    },
  },

  ------------------------------------------------------------------
  -- Crown of the Cosmos (The Voidspire)
  ------------------------------------------------------------------
  {
    id   = "Crown of the Cosmos",
    name = "Crown of the Cosmos",
    kind = "raid",
    mechanics = {
      {
        id        = "cosmic_collapse",
        spellID   = 476820,
        trigger   = "cast",
        type      = "soak_circle",
        radius    = 12,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "Group Soak",
      },
      {
        id        = "entropic_tether",
        spellID   = 476855,
        trigger   = "aura_apply",
        type      = "beam",
        radius    = 3,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "Break Tether Line",
      },
    },
  },

  ------------------------------------------------------------------
  -- Chimaerus (The Dreamrift)
  ------------------------------------------------------------------
  {
    id   = "Chimaerus, the Undreamt God",
    name = "Chimaerus, the Undreamt God",
    kind = "raid",
    mechanics = {
      {
        id        = "dust_upheaval",
        spellID   = 477190,
        trigger   = "cast",
        type      = "stack_circle",
        radius    = 8,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "STACK FOR UPHEAVAL SLAM",
      },
      {
        id        = "consuming_miasma",
        spellID   = 477215,
        trigger   = "aura_apply",
        type      = "spread_circle",
        radius    = 8,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "MIASMA SPREAD - DISPEL COMING",
      },
    },
  },

  ------------------------------------------------------------------
  -- Belo'ren (March on Quel'Danas)
  ------------------------------------------------------------------
  {
    id   = "Belo'ren — Child of Al'ar",
    name = "Belo'ren — Child of Al'ar",
    kind = "raid",
    mechanics = {
      {
        id        = "boomba_bgone",
        spellID   = 479301,
        trigger   = "cast",
        type      = "circle",
        radius    = 10,
        priority  = "high",
        color     = "danger",
        anchor    = "target",
        message   = "Run Out - Bomb Drop!",
      },
      {
        id        = "edict_soak",
        spellID   = 479520,
        trigger   = "cast",
        type      = "cone",
        radius    = 15,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "TANK SOAK FRONTAL",
      },
    },
  },

  ------------------------------------------------------------------
  -- Midnight Falls (March on Quel'Danas)
  ------------------------------------------------------------------
  {
    id   = "Midnight Falls",
    name = "Midnight Falls",
    kind = "raid",
    mechanics = {
      {
        id        = "dark_quasar",
        spellID   = 479110,
        trigger   = "cast",
        type      = "beam",
        radius    = 30,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "DODGE ROTATING DARK QUASAR BEAMS",
      },
      {
        id        = "deaths_dirge",
        spellID   = 479150,
        trigger   = "cast",
        type      = "text",
        radius    = 0,
        priority  = "medium",
        color     = "info",
        anchor    = "player",
        message   = "RUNES SHOWN - CHECK SEQUENCE",
      },
      {
        id        = "galvanize_beam",
        spellID   = 479220,
        trigger   = "aura_apply",
        type      = "beam",
        radius    = 25,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "AIM BEAM AT VOID CORE",
      },
      {
        id        = "core_harvest",
        spellID   = 479245,
        trigger   = "cast",
        type      = "beam",
        radius    = 6,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "CORE MOVING - DO NOT STAND IN LINE",
      },
      {
        id        = "dark_archangel_shield",
        spellID   = 479310,
        trigger   = "cast",
        type      = "stack_circle",
        radius    = 12,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "STACK INSIDE DAWN CRYSTAL SHIELD",
      },
    },
  },
}
