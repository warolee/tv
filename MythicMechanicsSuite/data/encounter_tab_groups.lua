--[[ MythicMechanicsSuite — encounter tab manifest for the Astro UI.

     Each entry becomes its own window tab: bosses in that instance are
     listed with per-mechanic toggles and optional palette overrides
     (`Config.mechanicPalettes`, see AstroPanels + Mechanics.lua).

     `encounter_ids` must match the top-level `id` field on encounter
     records in `data/mplus_midnight.lua` / `data/raids_midnight.lua`. ]]

return {
  {
    tab_id        = "mms_enc_m_mt",
    label         = "M+ — Magisters' Terrace",
    encounter_ids = {
      "Arcanotron Custos",
      "Seranel Sunlash",
      "Gemellus",
      "Degentrius",
    },
  },
  {
    tab_id        = "mms_enc_m_mc",
    label         = "M+ — Maisara Caverns",
    encounter_ids = {
      "Muro'jin & Nekraxx",
      "Vordaza",
      "Rak'tul Vessel of Souls",
    },
  },
  {
    tab_id        = "mms_enc_m_nx",
    label         = "M+ — Nexus-Point Xenas",
    encounter_ids = {
      "Chief Corewright Kasreth",
      "Corewarden Nysarra",
      "Lothraxion",
    },
  },
  {
    tab_id        = "mms_enc_m_ws",
    label         = "M+ — Windrunner Spire",
    encounter_ids = {
      "Emberdawn",
      "Derelict Duo",
      "Commander Kroluk",
      "The Restless Heart",
    },
  },
  {
    tab_id        = "mms_enc_m_legacy",
    label         = "M+ — Legacy rotation",
    encounter_ids = {
      "Algeth'ar Academy",
      "Seat of the Triumvirate",
      "Skyreach",
      "Pit of Saron",
    },
  },
  {
    tab_id        = "mms_enc_r_voidspire",
    label         = "Raid — The Voidspire",
    encounter_ids = {
      "Imperator Averzian",
      "Vorasius",
      "Fallen-King Salhadaar",
      "Vaelgor & Ezzorak",
      "Lightblinded Vanguard",
      "Crown of the Cosmos",
    },
  },
  {
    tab_id        = "mms_enc_r_dreamrift",
    label         = "Raid — The Dreamrift",
    encounter_ids = {
      "Chimaerus, the Undreamt God",
    },
  },
  {
    tab_id        = "mms_enc_r_queldanas",
    label         = "Raid — March on Quel'Danas",
    encounter_ids = {
      "Belo'ren — Child of Al'ar",
      "Midnight Falls",
    },
  },
}
