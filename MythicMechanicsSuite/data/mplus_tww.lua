--[[ MythicMechanicsSuite — encounter data: Mythic+ dungeons in TWW.

     One encounter entry per *boss* (and one synthetic entry per
     dungeon for trash-only mechanics). Spell ids should be reviewed
     each season; everything below defaults to medium priority so a
     stale id mostly costs you a missed warning, not a false alarm. ]]

local R = {}

local function dungeon(id, name)
  return { id = id, name = name, kind = "mplus", zone = name }
end

----------------------------------------------------------------------
-- Ara-Kara, City of Echoes
----------------------------------------------------------------------
do
  local e = dungeon(2902, "Avanoxx (Ara-Kara)")
  e.mechanics = {
    { id = "alerting_shrill", spellID = 434252, trigger = "cast", type = "circle",
      name = "Alerting Shrill", radius = 35, priority = "high",
      color = "danger", anchor = "caster", message = "Hide behind pillar!" },
    { id = "voracious_bite", spellID = 433843, trigger = "cast", type = "cone",
      name = "Voracious Bite", length = 25, width = math.pi * 0.4,
      priority = "medium", color = "cone", anchor = "caster" },
    { id = "gossamer_onslaught", spellID = 434655, trigger = "cast", type = "beam",
      name = "Gossamer Onslaught", length = 45, width = 6, priority = "medium",
      color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2903, "Anub'zekt (Ara-Kara)")
  e.mechanics = {
    { id = "infestation", spellID = 434066, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Infestation", radius = 8, priority = "high",
      color = "dropoff", affects_player_only = true, message = "Drop puddle out!" },
    { id = "burrow_charge", spellID = 434089, trigger = "cast", type = "beam",
      name = "Burrow Charge", length = 50, width = 5, priority = "high",
      color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2904, "Ki'katal the Harvester (Ara-Kara)")
  e.mechanics = {
    { id = "cosmic_singularity", spellID = 432031, trigger = "cast", type = "circle",
      name = "Cosmic Singularity", radius = 5, priority = "high",
      color = "danger", anchor = "caster", message = "Spread + dodge orbs" },
    { id = "poison_nova", spellID = 433740, trigger = "cast", type = "circle",
      name = "Poison Nova", radius = 12, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- City of Threads
----------------------------------------------------------------------
do
  local e = dungeon(2905, "Orator Krix'vizk (City of Threads)")
  e.mechanics = {
    { id = "grand_speech", spellID = 442526, trigger = "cast", type = "cone",
      name = "Grand Speech", length = 35, width = math.pi * 0.5,
      priority = "medium", color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2906, "Fangs of the Queen (City of Threads)")
  e.mechanics = {
    { id = "twist_thoughts", spellID = 443427, trigger = "cast", type = "beam",
      name = "Twist Thoughts", length = 40, width = 4, priority = "medium",
      color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2907, "The Coaglamation (City of Threads)")
  e.mechanics = {
    { id = "unleashed_horror", spellID = 443531, trigger = "cast", type = "circle",
      name = "Unleashed Horror", radius = 30, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2908, "Izo, the Grand Splicer (City of Threads)")
  e.mechanics = {
    { id = "splice", spellID = 443531, trigger = "cast", type = "cone",
      name = "Splice", length = 30, width = math.pi * 0.45, priority = "medium",
      color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- The Dawnbreaker
----------------------------------------------------------------------
do
  local e = dungeon(2909, "Speaker Shadowcrown (The Dawnbreaker)")
  e.mechanics = {
    { id = "umbral_barrier", spellID = 449734, trigger = "cast", type = "circle",
      name = "Umbral Barrier", radius = 8, priority = "medium",
      color = "danger", anchor = "caster" },
    { id = "burning_shadows", spellID = 451026, trigger = "cast", type = "circle",
      name = "Burning Shadows", radius = 6, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2910, "Anub'ikkaj (The Dawnbreaker)")
  e.mechanics = {
    { id = "terrifying_slam", spellID = 426734, trigger = "cast", type = "cone",
      name = "Terrifying Slam", length = 25, width = math.pi * 0.5, priority = "high",
      color = "cone", anchor = "caster" },
    { id = "shadowy_decay", spellID = 432031, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Shadowy Decay", radius = 6, priority = "medium",
      color = "dropoff", affects_player_only = true, message = "Drop puddle" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2911, "Rasha'nan (The Dawnbreaker)")
  e.mechanics = {
    { id = "rolling_acid_aerial", spellID = 439811, trigger = "cast", type = "beam",
      name = "Rolling Acid", length = 60, width = 5, priority = "high",
      color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- The Stonevault
----------------------------------------------------------------------
do
  local e = dungeon(2912, "E.D.N.A. (The Stonevault)")
  e.mechanics = {
    { id = "thunder_punch", spellID = 426737, trigger = "cast", type = "beam",
      name = "Thunder Punch", length = 40, width = 6, priority = "high",
      color = "line", anchor = "caster" },
    { id = "earthen_ire", spellID = 429109, trigger = "cast", type = "circle",
      name = "Earthen Ire", radius = 12, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2913, "Skarmorak (The Stonevault)")
  e.mechanics = {
    { id = "stonebound_artillery", spellID = 432031, trigger = "cast", type = "circle",
      name = "Stonebound Artillery", radius = 5, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2914, "Master Machinists (The Stonevault)")
  e.mechanics = {
    { id = "molten_metal", spellID = 426734, trigger = "cast", type = "circle",
      name = "Molten Metal", radius = 6, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2915, "Void Speaker Eirich (The Stonevault)")
  e.mechanics = {
    { id = "void_empowerment", spellID = 449734, trigger = "cast", type = "circle",
      name = "Void Empowerment", radius = 35, priority = "high",
      color = "danger", anchor = "caster", message = "Soak — Void Empowerment!" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Mists of Tirna Scithe (legacy in S1 TWW rotation)
----------------------------------------------------------------------
do
  local e = dungeon(2080, "Ingra Maloch (Mists of Tirna Scithe)")
  e.mechanics = {
    { id = "spirit_bolt", spellID = 322557, trigger = "cast", type = "circle",
      name = "Spirit Bolt", radius = 6, priority = "low",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2081, "Tred'ova (Mists of Tirna Scithe)")
  e.mechanics = {
    { id = "consumption", spellID = 326450, trigger = "cast", type = "cone",
      name = "Consumption", length = 25, width = math.pi * 0.4, priority = "medium",
      color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- The Necrotic Wake (legacy)
----------------------------------------------------------------------
do
  local e = dungeon(2082, "Nalthor the Rimebinder (The Necrotic Wake)")
  e.mechanics = {
    { id = "frozen_binds", spellID = 321821, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Frozen Binds", radius = 6, priority = "medium",
      color = "dropoff", affects_player_only = true },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Siege of Boralus (legacy)
----------------------------------------------------------------------
do
  local e = dungeon(2083, "Chopper Redhook (Siege of Boralus)")
  e.mechanics = {
    { id = "cannon_barrage", spellID = 257582, trigger = "cast", type = "circle",
      name = "Cannon Barrage", radius = 4, priority = "high",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

return { encounters = R }
