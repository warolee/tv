--[[ MythicMechanicsSuite — encounter data: Midnight Season 1 Mythic+.

     Season 1 rotation (Mar 2026):

       New Midnight (4):
         - Magisters' Terrace      (4 bosses)
         - Maisara Caverns         (3 bosses)
         - Nexus-Point Xenas       (3 bosses)
         - Windrunner Spire        (4 bosses)

       Legacy (4):
         - Algeth'ar Academy       (Dragonflight)
         - Pit of Saron            (Wrath of the Lich King)
         - Seat of the Triumvirate (Legion)
         - Skyreach                (Warlords of Draenor)

     Like the raid file, spell IDs in this file are PLACEHOLDERS in the
     1300000+ range for Midnight content and 1310000+ for legacy
     dungeons. Mechanic NAMES + structure are correct (sourced from
     Wowhead, Icy Veins, Method strategy guides). Replace the
     placeholder ids with real ones from in-game (`/dump
     UnitCastingInfo("target")`) or Wowhead, then drop the
     `_placeholder = true` flag. ]]

local R = {}

local _PH = 1300000
local function PH() _PH = _PH + 1; return _PH end

local function dungeon(id, name, zone)
  return { id = id, name = name, kind = "mplus", zone = zone }
end

----------------------------------------------------------------------
-- Magisters' Terrace — new Midnight, Quel'Thalas
----------------------------------------------------------------------

do
  local e = dungeon(3201, "Arcanotron Custos (Magisters' Terrace)", "Magisters' Terrace")
  e.mechanics = {
    --- Tank-targeted magic debuff; needs magic dispel / root break.
    { id = "ethereal_shackles", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "text", name = "Ethereal Shackles (dispel!)",
      priority = "high", color = "danger" },

    --- Arcane beam channels into random players, leaving puddles.
    { id = "arcane_beam", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Arcane Beam", length = 40, width = 4,
      priority = "high", color = "line", anchor = "caster",
      message = "Drop puddle outside group" },

    --- AoE knockback; dangerous near Arcane Residue.
    { id = "arcane_expulsion", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Arcane Expulsion (knockback)", radius = 40,
      priority = "high", color = "danger", anchor = "caster" },

    --- Soak energy orbs (stacking debuff); boss takes 20% extra dmg.
    { id = "refueling_protocol", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "soak_circle", name = "Refueling Protocol", radius = 35,
      priority = "high", color = "soak", anchor = "caster",
      message = "Soak orbs (rotate stacks)" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3202, "Seranel Sunlash (Magisters' Terrace)", "Magisters' Terrace")
  e.mechanics = {
    --- Debuff cleared by standing in the Suppression Zone.
    { id = "runic_mark", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "stack_circle", name = "Runic Mark (suppression zone)",
      radius = 6, priority = "high", color = "stack",
      message = "Move into Suppression Zone" },

    --- Must be inside Suppression Zone before cast finishes.
    { id = "wave_of_silence", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Wave of Silence", radius = 40,
      priority = "high", color = "danger", anchor = "caster",
      message = "Get into Suppression Zone!" },

    --- Tank haste buff — dispel.
    { id = "hastening_ward", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "buff",
      type = "text", name = "Hastening Ward (dispel)",
      priority = "medium", color = "danger" },

    --- Ground arcane barrages.
    { id = "arcane_barrage", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Arcane Barrage", radius = 5,
      priority = "medium", color = "dropoff", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3203, "Gemellus (Magisters' Terrace)", "Magisters' Terrace")
  e.mechanics = {
    --- Triplicate at fight start and 50% HP; copies share HP.
    { id = "triplicate", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Triplicate (shared HP)", radius = 8,
      priority = "high", color = "danger", anchor = "caster" },

    --- Neural Link cleared by standing near correct copy.
    { id = "neural_link", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "stack_circle", name = "Neural Link (correct copy)",
      radius = 8, priority = "high", color = "stack" },

    --- Continuous movement to avoid Cosmic Radiation.
    { id = "astral_grasp", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Astral Grasp (keep moving)", radius = 6,
      priority = "medium", color = "dropoff" },

    --- Cosmic Sting + Void Secretions punish slow reposition.
    { id = "cosmic_sting", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Cosmic Sting → Void Secretions", radius = 6,
      priority = "high", color = "dropoff", anchor = "caster",
      message = "Move now — puddle incoming" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3204, "Degentrius (Magisters' Terrace)", "Magisters' Terrace")
  e.mechanics = {
    --- Final boss; mechanics not yet fully documented publicly.
    { id = "void_burst",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Void Burst", radius = 30, priority = "high",
      color = "danger", anchor = "caster", message = "Spread / dodge" },
    { id = "decay_pool",  spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Decay Pool", radius = 6,
      priority = "high", color = "dropoff", message = "Drop puddle on edge" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Maisara Caverns — new Midnight, Zul'Aman (Vilebranch trolls)
----------------------------------------------------------------------

do
  local e = dungeon(3205, "Muro'jin and Nekraxx (Maisara Caverns)", "Maisara Caverns")
  e.mechanics = {
    { id = "necrotic_lash",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Necrotic Lash", length = 25, width = math.pi * 0.4,
      priority = "high", color = "cone", anchor = "caster" },
    { id = "voodoo_curse",   spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Voodoo Curse", radius = 8,
      priority = "medium", color = "dropoff", message = "Dispel / drop curse" },
    { id = "ritual_shadow",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Ritual of Shadow", radius = 12,
      priority = "medium", color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3206, "Vordaza (Maisara Caverns)", "Maisara Caverns")
  e.mechanics = {
    { id = "blood_pact",   spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Blood Pact", radius = 6, priority = "medium",
      color = "danger", anchor = "caster" },
    { id = "shadow_bolt",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Shadow Bolt (interrupt)", length = 30, width = 3,
      priority = "high", color = "line", anchor = "caster", message = "Interrupt!" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3207, "Rak'tul, Vessel of Souls (Maisara Caverns)", "Maisara Caverns")
  e.mechanics = {
    { id = "soul_drain",   spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "stack_circle", name = "Soul Drain (stack heal)", radius = 8,
      priority = "high", color = "stack" },
    { id = "vessel_burst", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Vessel Burst", radius = 30,
      priority = "high", color = "danger", anchor = "caster",
      message = "Run out — burst!" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Nexus-Point Xenas — new Midnight, Voidstorm
----------------------------------------------------------------------

do
  local e = dungeon(3208, "Chief Corewright Kasreth (Nexus-Point Xenas)", "Nexus-Point Xenas")
  e.mechanics = {
    { id = "arcane_overload", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Arcane Overload", radius = 30, priority = "high",
      color = "danger", anchor = "caster", message = "Soak / spread" },
    { id = "void_conduit",    spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Void Conduit", length = 45, width = 5,
      priority = "medium", color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3209, "Corewarden Nysarra (Nexus-Point Xenas)", "Nexus-Point Xenas")
  e.mechanics = {
    { id = "warding_field",   spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Warding Field (don't touch)", radius = 8,
      priority = "high", color = "danger", anchor = "caster" },
    { id = "core_lance",      spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Core Lance", length = 30, width = math.pi * 0.35,
      priority = "high", color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3210, "Lothraxion (Nexus-Point Xenas)", "Nexus-Point Xenas")
  e.mechanics = {
    --- Legion lieutenant in voidstorm context — frontal sweep.
    { id = "judgement",       spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Judgement", length = 35, width = math.pi * 0.45,
      priority = "high", color = "cone", anchor = "caster", message = "Side-step Judgement" },
    { id = "infernal_strike", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Infernal Strike", radius = 6,
      priority = "medium", color = "dropoff", anchor = "caster" },
    { id = "ruinous_meteor",  spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Ruinous Meteor", radius = 8,
      priority = "high", color = "dropoff", message = "Drop meteor away" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Windrunner Spire — new Midnight, Eternal Spring Forest
----------------------------------------------------------------------

do
  local e = dungeon(3211, "Emberdawn (Windrunner Spire)", "Windrunner Spire")
  e.mechanics = {
    --- Mark → fiery zone with knockback after 6s.
    { id = "flaming_updraft", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Flaming Updraft", radius = 8,
      priority = "high", color = "dropoff", message = "Drop fire away from group" },

    --- Tank bleed + heavy physical.
    { id = "searing_beak",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Searing Beak (tank)", length = 15, width = math.pi * 0.3,
      priority = "medium", color = "cone", anchor = "caster" },

    --- 16s wind push; Flaming Twisters spawn during this.
    { id = "burning_gale",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Burning Gale (16s)", radius = 40,
      priority = "high", color = "danger", anchor = "caster",
      message = "Position vs wind; dodge twisters" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3212, "Derelict Duo: Kalis & Latch (Windrunner Spire)", "Windrunner Spire")
  e.mechanics = {
    --- Marks player → bile zone after expiry.
    { id = "gunk_splatter", spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Gunk Splatter", radius = 6,
      priority = "high", color = "dropoff", message = "Drop bile at edge" },

    --- Interruptible 2.5s cast on a random player.
    { id = "shadow_bolt",   spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Shadow Bolt (interrupt)", length = 30, width = 3,
      priority = "high", color = "line", anchor = "caster", message = "Interrupt!" },

    --- Hook Sweep at 100 energy; marked player positions hook.
    { id = "hook_sweep",    spellID = PH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Hook Sweep", length = 40, width = 5,
      priority = "high", color = "line", anchor = "caster",
      message = "Position hook between bosses" },

    --- Debilitating Screech: only interrupted by Hook Sweep landing.
    { id = "debilitating_screech", spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Debilitating Screech (kill with Hook)", radius = 40,
      priority = "high", color = "danger", anchor = "caster" },

    --- 3s of big tank hits.
    { id = "bone_chop",     spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Bone Chop (tank)", length = 15, width = math.pi * 0.3,
      priority = "medium", color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3213, "Commander Kroluk (Windrunner Spire)", "Windrunner Spire")
  e.mechanics = {
    { id = "battle_cry",      spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Battle Cry (interrupt)", radius = 40,
      priority = "high", color = "danger", anchor = "caster", message = "Interrupt!" },
    { id = "cleaving_sweep",  spellID = PH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Cleaving Sweep", length = 25, width = math.pi * 0.55,
      priority = "high", color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(3214, "The Restless Heart (Windrunner Spire)", "Windrunner Spire")
  e.mechanics = {
    { id = "heartbeat",       spellID = PH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Heartbeat (pulse)", radius = 15,
      priority = "high", color = "danger", anchor = "caster", message = "Spread for pulse" },
    { id = "haunting_echo",   spellID = PH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Haunting Echo", radius = 8,
      priority = "medium", color = "dropoff" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Legacy: Algeth'ar Academy (Dragonflight)
----------------------------------------------------------------------

local _LEG = 1310000
local function LPH() _LEG = _LEG + 1; return _LEG end

do
  local e = dungeon(2516, "Vexamus (Algeth'ar Academy)", "Algeth'ar Academy")
  e.mechanics = {
    { id = "mana_void",        spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Mana Void", radius = 6, priority = "high",
      color = "danger", anchor = "caster" },
    { id = "arcane_expulsion", spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Arcane Expulsion", length = 40, width = 4,
      priority = "medium", color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2517, "Crawth (Algeth'ar Academy)", "Algeth'ar Academy")
  e.mechanics = {
    { id = "wild_peck",        spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Wild Peck", length = 25, width = math.pi * 0.4,
      priority = "medium", color = "cone", anchor = "caster" },
    { id = "feathered_dance",  spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Feathered Dance", radius = 25,
      priority = "high", color = "danger", anchor = "caster",
      message = "Catch the ball / dodge feathers" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2518, "Echo of Doragosa (Algeth'ar Academy)", "Algeth'ar Academy")
  e.mechanics = {
    { id = "astral_vortex",    spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Astral Vortex", radius = 8, priority = "high",
      color = "dropoff", anchor = "caster", message = "Drop puddle on edge" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(2519, "Overgrown Ancient (Algeth'ar Academy)", "Algeth'ar Academy")
  e.mechanics = {
    { id = "blastering_bash",  spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Blastering Bash", length = 35, width = 5,
      priority = "high", color = "line", anchor = "caster" },
    { id = "germinate",        spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Germinate", radius = 6, priority = "medium",
      color = "dropoff", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Legacy: Pit of Saron (WotLK)
----------------------------------------------------------------------

do
  local e = dungeon(658, "Forgemaster Garfrost (Pit of Saron)", "Pit of Saron")
  e.mechanics = {
    { id = "saronite_rock",    spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "drop_circle", name = "Saronite Rock", radius = 5, priority = "high",
      color = "dropoff", anchor = "caster", message = "Use rock as wall" },
    { id = "permafrost",       spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Permafrost", radius = 8, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(659, "Ick & Krick (Pit of Saron)", "Pit of Saron")
  e.mechanics = {
    { id = "poison_nova",      spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Poison Nova", radius = 14, priority = "high",
      color = "danger", anchor = "caster", message = "Run out!" },
    { id = "pursuit",          spellID = LPH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Pursuit (kite)", radius = 5,
      priority = "high", color = "dropoff", message = "Kite away!" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(660, "Scourgelord Tyrannus (Pit of Saron)", "Pit of Saron")
  e.mechanics = {
    { id = "mark_of_rimefang", spellID = LPH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Mark of Rimefang", radius = 5,
      priority = "high", color = "dropoff" },
    { id = "hoarfrost",        spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Hoarfrost", radius = 6, priority = "medium",
      color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Legacy: Seat of the Triumvirate (Legion)
----------------------------------------------------------------------

do
  local e = dungeon(1900, "Zuraal the Ascended (Seat of the Triumvirate)", "Seat of the Triumvirate")
  e.mechanics = {
    { id = "void_tear",        spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Void Tear", radius = 6, priority = "high",
      color = "danger", anchor = "caster" },
    { id = "embrace_of_void",  spellID = LPH(), _placeholder = true, trigger = "aura_apply",
      aura_kind = "debuff", affects_player_only = true,
      type = "drop_circle", name = "Embrace of the Void", radius = 8,
      priority = "high", color = "dropoff" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(1901, "Saprish (Seat of the Triumvirate)", "Seat of the Triumvirate")
  e.mechanics = {
    { id = "shadow_blades",    spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Shadow Blades", length = 35, width = 4,
      priority = "high", color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(1902, "Viceroy Nezhar (Seat of the Triumvirate)", "Seat of the Triumvirate")
  e.mechanics = {
    { id = "shadow_blast",     spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Shadow Blast", radius = 30, priority = "high",
      color = "danger", anchor = "caster", message = "Spread" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(1903, "L'ura (Seat of the Triumvirate)", "Seat of the Triumvirate")
  e.mechanics = {
    { id = "darkening_shroud", spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Darkening Shroud (room-wide)", radius = 50,
      priority = "high", color = "danger", anchor = "caster" },
    { id = "umbral_scythe",    spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Umbral Scythe", length = 45, width = 5,
      priority = "high", color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

----------------------------------------------------------------------
-- Legacy: Skyreach (Warlords of Draenor)
----------------------------------------------------------------------

do
  local e = dungeon(1209, "Ranjit (Skyreach)", "Skyreach")
  e.mechanics = {
    { id = "windwall",         spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Windwall", length = 30, width = 4,
      priority = "medium", color = "line", anchor = "caster" },
    { id = "four_winds",       spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Four Winds", radius = 30,
      priority = "high", color = "danger", anchor = "caster",
      message = "Hide behind statue" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(1210, "Araknath (Skyreach)", "Skyreach")
  e.mechanics = {
    { id = "solar_energy",     spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Solar Energy (knockback)", radius = 40,
      priority = "high", color = "danger", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(1211, "Rukhran (Skyreach)", "Skyreach")
  e.mechanics = {
    { id = "pierce",           spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Pierce", length = 40, width = 4,
      priority = "high", color = "line", anchor = "caster" },
    { id = "screech",          spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "cone", name = "Screech", length = 30, width = math.pi * 0.5,
      priority = "medium", color = "cone", anchor = "caster" },
  }
  R[#R + 1] = e
end

do
  local e = dungeon(1212, "High Sage Viryx (Skyreach)", "Skyreach")
  e.mechanics = {
    { id = "solar_storm",      spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "circle", name = "Solar Storm", radius = 8, priority = "high",
      color = "danger", anchor = "caster", message = "Hide in shadow" },
    { id = "empowered_lightning", spellID = LPH(), _placeholder = true, trigger = "cast",
      type = "beam", name = "Empowered Lightning", length = 45, width = 4,
      priority = "high", color = "line", anchor = "caster" },
  }
  R[#R + 1] = e
end

return { encounters = R }
