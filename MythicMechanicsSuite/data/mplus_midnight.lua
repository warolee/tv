--[[ MythicMechanicsSuite — Midnight Season 1 Mythic+ mechanic dataset.

     Returned value: array of encounter records `{ id, name, kind, mechanics }`.
     Each mechanic row uses exactly:

       { id, spellID, trigger, type, radius, priority, color, anchor, message }

     `kind` is always `"mplus"` for this file. No placeholder flags. ]]

return {
  ------------------------------------------------------------------
  -- Magisters' Terrace
  ------------------------------------------------------------------
  {
    id   = "Arcanotron Custos",
    name = "Arcanotron Custos",
    kind = "mplus",
    mechanics = {
      {
        id        = "arcane_annihilation",
        spellID   = 481120,
        trigger   = "cast",
        type      = "beam",
        radius    = 4,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Line Beam",
      },
    },
  },
  {
    id   = "Seranel Sunlash",
    name = "Seranel Sunlash",
    kind = "mplus",
    mechanics = {
      {
        id        = "ethereal_shackles",
        spellID   = 481020,
        trigger   = "aura_apply",
        type      = "text",
        radius    = 0,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "DISPEL TANK IMMEDIATELY",
      },
    },
  },
  {
    id   = "Degentrius",
    name = "Degentrius",
    kind = "mplus",
    mechanics = {
      {
        id        = "ingest_black_blood",
        spellID   = 481804,
        trigger   = "cast",
        type      = "circle",
        radius    = 10,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Black Blood Nova",
      },
      {
        id        = "foul_spew",
        spellID   = 481815,
        trigger   = "cast",
        type      = "cone",
        radius    = 14,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Frontal Vomit Cleave",
      },
    },
  },

  ------------------------------------------------------------------
  -- Maisara Caverns
  ------------------------------------------------------------------
  {
    id   = "Muro'jin & Nekraxx",
    name = "Muro'jin & Nekraxx",
    kind = "mplus",
    mechanics = {
      {
        id        = "voodoo_tether",
        spellID   = 487140,
        trigger   = "aura_apply",
        type      = "beam",
        radius    = 2,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "Break Voodoo Link",
      },
    },
  },
  {
    id   = "Vordaza",
    name = "Vordaza",
    kind = "mplus",
    mechanics = {
      {
        id        = "fetid_quill_storm",
        spellID   = 487230,
        trigger   = "cast",
        type      = "circle",
        radius    = 25,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "QUILL DIVE - UNDERNEATH IS SAFE",
      },
    },
  },

  ------------------------------------------------------------------
  -- Nexus-Point Xenas
  ------------------------------------------------------------------
  {
    id   = "Chief Corewright Kasreth",
    name = "Chief Corewright Kasreth",
    kind = "mplus",
    mechanics = {
      {
        id        = "nullify",
        spellID   = 485905,
        trigger   = "cast",
        type      = "text",
        radius    = 0,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "INTERRUPT NULLIFY NOW",
      },
    },
  },
  {
    id   = "Corewarden Nysarra",
    name = "Corewarden Nysarra",
    kind = "mplus",
    mechanics = {
      {
        id        = "flux_beam",
        spellID   = 485202,
        trigger   = "cast",
        type      = "beam",
        radius    = 5,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Rotating Flux Beam!",
      },
    },
  },

  ------------------------------------------------------------------
  -- Windrunner Spire
  ------------------------------------------------------------------
  {
    id   = "Emberdawn",
    name = "Emberdawn",
    kind = "mplus",
    mechanics = {
      {
        id        = "burning_cleave",
        spellID   = 483102,
        trigger   = "cast",
        type      = "cone",
        radius    = 10,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Fire Breath Frontal",
      },
      {
        id        = "burning_gale",
        spellID   = 483120,
        trigger   = "cast",
        type      = "circle",
        radius    = 30,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "BURNING GALE - FIGHT THE WIND",
      },
    },
  },
  {
    id   = "Derelict Duo",
    name = "Derelict Duo",
    kind = "mplus",
    mechanics = {
      {
        id        = "splattering_spew",
        spellID   = 483250,
        trigger   = "aura_apply",
        type      = "drop_circle",
        radius    = 8,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "DROP PUDDLE AT EDGES",
      },
      {
        id        = "curse_of_darkness",
        spellID   = 483214,
        trigger   = "aura_apply",
        type      = "spread_circle",
        radius    = 5,
        priority  = "high",
        color     = "warning",
        anchor    = "target",
        message   = "DECURSE / OUTRANGE DARK ENTITY",
      },
    },
  },
  {
    id   = "Commander Kroluk",
    name = "Commander Kroluk",
    kind = "mplus",
    mechanics = {
      {
        id        = "decapitate",
        spellID   = 483510,
        trigger   = "cast",
        type      = "beam",
        radius    = 5,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "Execution Cleave Line",
      },
      {
        id        = "intimidating_shout",
        spellID   = 483562,
        trigger   = "cast",
        type      = "stack_circle",
        radius    = 6,
        priority  = "high",
        color     = "info",
        anchor    = "target",
        message   = "STACK IN PURPLE - AVOID FEAR",
      },
    },
  },
  {
    id   = "The Restless Heart",
    name = "The Restless Heart",
    kind = "mplus",
    mechanics = {
      {
        id        = "charged_arrow",
        spellID   = 483680,
        trigger   = "cast",
        type      = "circle",
        radius    = 12,
        priority  = "high",
        color     = "danger",
        anchor    = "caster",
        message   = "DODGE WIND WAVE - USE ARROW",
      },
      {
        id        = "gale_surge",
        spellID   = 156579,
        trigger   = "aura_apply",
        type      = "spread_circle",
        radius    = 6,
        priority  = "medium",
        color     = "warning",
        anchor    = "target",
        message   = "KNOCKBACK ARROW - RUN OUT",
      },
    },
  },
}
