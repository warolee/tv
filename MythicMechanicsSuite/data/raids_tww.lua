--[[ MythicMechanicsSuite — encounter data: The War Within raid tier.

     Format documented in Encounters.lua. Spell ids are taken from the
     public Wowhead/WCL data for the The War Within (11.x) raid tier
     and should be sanity-checked when a new patch lands. Anything you
     are unsure about should default to `priority = "low"` so it does
     not pop loud alerts on the off chance the id changed. ]]

local R = {}

----------------------------------------------------------------------
-- Nerub-ar Palace
----------------------------------------------------------------------
R[#R + 1] = {
  id = 2902,
  name = "Ulgrax the Devourer",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 215657 },
  mechanics = {
    { id = "hulking_crash", spellID = 435136, trigger = "cast", type = "circle",
      name = "Hulking Crash", priority = "high", radius = 40, anchor = "caster",
      color = "danger", message = "MOVE — Crash!" },
    { id = "carnivorous_contest", spellID = 434705, trigger = "cast", type = "circle",
      name = "Carnivorous Contest", priority = "medium", radius = 5, anchor = "caster",
      color = "danger" },
    { id = "venomous_lash", spellID = 434803, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Venomous Lash", radius = 6, priority = "medium",
      color = "dropoff", affects_player_only = true, message = "Drop puddle away" },
  },
}

R[#R + 1] = {
  id = 2917,
  name = "The Bloodbound Horror",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 214502 },
  mechanics = {
    { id = "crimson_rain",   spellID = 444363, trigger = "cast", type = "circle",
      name = "Crimson Rain", radius = 8, priority = "high", color = "danger",
      anchor = "caster", message = "Move out of pools" },
    { id = "gruesome_disgorge", spellID = 443274, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Gruesome Disgorge", radius = 8, priority = "high",
      color = "dropoff", affects_player_only = true, message = "Drop puddle far away" },
    { id = "spewing_hemorrhage", spellID = 443274, trigger = "cast", type = "cone",
      name = "Spewing Hemorrhage", length = 35, width = math.pi * 0.45,
      priority = "medium", color = "cone", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 2898,
  name = "Sikran, Captain of the Sureki",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 214503 },
  mechanics = {
    { id = "phase_blades", spellID = 433517, trigger = "cast", type = "cone",
      name = "Phase Blades", length = 40, width = math.pi * 0.35, priority = "high",
      color = "cone", anchor = "caster", message = "Side-step the slash!" },
    { id = "decapitate", spellID = 439459, trigger = "cast", type = "beam",
      name = "Decapitate", length = 45, width = 6, priority = "high",
      color = "line", anchor = "caster", message = "Decapitate beam!" },
  },
}

R[#R + 1] = {
  id = 2918,
  name = "Rasha'nan",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 214507 },
  mechanics = {
    { id = "expel_webs", spellID = 439646, trigger = "cast", type = "beam",
      name = "Expel Webs", length = 60, width = 4, priority = "high",
      color = "line", anchor = "caster" },
    { id = "spinneret_arrows", spellID = 442677, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Spinneret's Arrows", radius = 6, priority = "medium",
      color = "dropoff", affects_player_only = true, message = "Drop arrow away" },
  },
}

R[#R + 1] = {
  id = 2919,
  name = "Broodtwister Ovi'nax",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 214506 },
  mechanics = {
    { id = "ingest_black_blood", spellID = 442526, trigger = "cast", type = "circle",
      name = "Ingest Black Blood", radius = 40, priority = "high",
      color = "danger", anchor = "caster", message = "Get out of pools!" },
    { id = "experimental_dosage", spellID = 446698, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Experimental Dosage", radius = 8, priority = "high",
      color = "spread", affects_player_only = true, message = "Spread!" },
  },
}

R[#R + 1] = {
  id = 2920,
  name = "Nexus-Princess Ky'veza",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 214767 },
  mechanics = {
    { id = "twilight_massacre", spellID = 437343, trigger = "cast", type = "cone",
      name = "Twilight Massacre", length = 40, width = math.pi * 0.4, priority = "high",
      color = "cone", anchor = "caster" },
    { id = "nexus_daggers", spellID = 436870, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Nexus Daggers", radius = 6, priority = "medium",
      color = "dropoff", affects_player_only = true, message = "Drop dagger soak" },
  },
}

R[#R + 1] = {
  id = 2921,
  name = "The Silken Court",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 217489, 217491 },
  mechanics = {
    { id = "piercing_strike", spellID = 438886, trigger = "cast", type = "cone",
      name = "Piercing Strike", length = 30, width = math.pi * 0.4, priority = "high",
      color = "cone", anchor = "caster" },
    { id = "venomous_rain", spellID = 438243, trigger = "cast", type = "circle",
      name = "Venomous Rain", radius = 40, priority = "medium",
      color = "danger", anchor = "caster", message = "Find a tile to soak" },
  },
}

R[#R + 1] = {
  id = 2922,
  name = "Queen Ansurek",
  kind = "raid",
  zone = "Nerub-ar Palace",
  npc_ids = { 218370 },
  mechanics = {
    { id = "feast", spellID = 439814, trigger = "cast", type = "circle",
      name = "Feast", radius = 45, priority = "high",
      color = "danger", anchor = "caster", message = "Soak — Feast!" },
    { id = "liquefy", spellID = 451277, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Liquefy", radius = 6, priority = "high",
      color = "dropoff", affects_player_only = true, message = "Drop puddle!" },
  },
}

----------------------------------------------------------------------
-- Liberation of Undermine (Season 2 — placeholders kept low priority
-- so a missing spell id doesn't false-alarm).
----------------------------------------------------------------------
R[#R + 1] = {
  id = 3009,
  name = "Vexie Fullthrottle",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 222145 },
  mechanics = {
    { id = "boomba_b_gone", spellID = 460603, trigger = "cast", type = "circle",
      name = "Boomba B-Gone", radius = 10, priority = "medium",
      color = "danger", anchor = "caster" },
    { id = "tank_buster", spellID = 460812, trigger = "cast", type = "beam",
      name = "Tank Spike", length = 30, width = 4, priority = "low",
      color = "line", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3010,
  name = "Cauldron of Carnage",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 229181, 229177 },
  mechanics = {
    { id = "molten_phlegm", spellID = 466178, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Molten Phlegm", radius = 6, priority = "medium",
      color = "dropoff", affects_player_only = true, message = "Drop molten" },
  },
}

R[#R + 1] = {
  id = 3011,
  name = "Rik Reverb",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 229059 },
  mechanics = {
    { id = "sound_cannon", spellID = 462715, trigger = "cast", type = "beam",
      name = "Sound Cannon", length = 50, width = 6, priority = "medium",
      color = "line", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3012,
  name = "Stix Bunkjunker",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 230322 },
  mechanics = {
    { id = "demolish", spellID = 469799, trigger = "cast", type = "cone",
      name = "Demolish", length = 30, width = math.pi * 0.5, priority = "medium",
      color = "cone", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3013,
  name = "Sprocketmonger Lockenstock",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 230583 },
  mechanics = {
    { id = "blastonomicon", spellID = 466178, trigger = "cast", type = "circle",
      name = "Blastonomicon", radius = 15, priority = "medium",
      color = "danger", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3014,
  name = "One-Armed Bandit",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 228463 },
  mechanics = {
    { id = "spew_gold", spellID = 460472, trigger = "cast", type = "circle",
      name = "Spew Gold", radius = 25, priority = "medium",
      color = "danger", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3015,
  name = "Mug'zee, Heads of Security",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 229953 },
  mechanics = {
    { id = "frostshatter_boots", spellID = 466178, trigger = "cast", type = "beam",
      name = "Frostshatter Stomp", length = 35, width = 6, priority = "medium",
      color = "line", anchor = "caster" },
  },
}

R[#R + 1] = {
  id = 3016,
  name = "Chrome King Gallywix",
  kind = "raid",
  zone = "Liberation of Undermine",
  npc_ids = { 230322 },
  mechanics = {
    { id = "giga_blast", spellID = 469799, trigger = "cast", type = "circle",
      name = "Giga Blast", radius = 30, priority = "high",
      color = "danger", anchor = "caster", message = "Spread for Giga Blast" },
    { id = "venting_heat", spellID = 466178, trigger = "aura_apply", aura_kind = "debuff",
      type = "drop_circle", name = "Venting Heat", radius = 8, priority = "high",
      color = "dropoff", affects_player_only = true, message = "Drop venting heat" },
  },
}

return { encounters = R }
