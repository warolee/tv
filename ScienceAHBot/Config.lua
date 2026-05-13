--[[ ScienceAHBot — configuration (namespace: ScienceAHBot runtime table). ]]

local ScienceAHBot = {}

ScienceAHBot.Config = {
  --- Per-item TSM ratio + label (Retail LIFO scan list source when non-empty).
  Items = {
    [190456] = { ratio = 0.70, name = "Draconic Vial" },
    [192101] = { ratio = 0.80, name = "Tenebrous Ribs" },
    [210805] = { ratio = 0.75, name = "Mycobloom" },
    [210806] = { ratio = 0.75, name = "Luredrop" },
    [210807] = { ratio = 0.75, name = "Orbinid" },
    [210808] = { ratio = 0.75, name = "Blessing Blossom" },
    [210809] = { ratio = 0.75, name = "Arathor's Spear" },
    [210810] = { ratio = 0.75, name = "Roaring Dragonwort" },
    [210930] = { ratio = 0.75, name = "Bismuth" },
    [210931] = { ratio = 0.75, name = "Ironclaw Ore" },
    [210932] = { ratio = 0.75, name = "Aqirite" },
    [210933] = { ratio = 0.75, name = "Null Stone" },
  },

  --- Fallback list if `Items` is empty (otherwise ignored when Items has entries).
  watchlist = {},

  buyRatio = nil,

  thresholds = {
    defaultBuyRatio = 0.75,
  },

  jitter = {
    scanMeanSeconds = 5.0,
    scanStdSeconds = 0.65,
    scanMinDelay = 3.5,
    scanMaxDelay = 7.0,
    cognitiveMeanSeconds = 1.05,
    cognitiveStdSeconds = 0.12,
    cognitiveMinDelay = 0.7,
    cognitiveMaxDelay = 1.4,
  },

  --- Randomized fatigue: work segment length then rest length (seconds).
  fatigueWorkSecondsMin = 45 * 60,
  fatigueWorkSecondsMax = 60 * 60,
  fatigueRestSecondsMin = 8 * 60,
  fatigueRestSecondsMax = 12 * 60,

  behavior = {
    modules = {
      buy = true,
      sell = false,
      snipe = false,
      undercut = false,
    },

    reserves = {
      minGoldCopper = 100000,
    },

    ui = {
      toggleKey = 0xC0,
      defaultOpen = true,
      x = 48,
      y = 48,
      w = 480,
      h = 620,
    },

    snipe = {
      watchlist = {},
      maxBuyRatio = 0.52,
      useBuyoutOnly = true,
      scanMeanSeconds = 2.0,
      scanStdSeconds = 0.35,
      scanMinDelay = 1.0,
      scanMaxDelay = 4.0,
    },

    sell = {
      watchlist = {},
      postStackSize = 20,
      vendorPriceMultiplier = 0.99,
      postFeeBufferCopper = 0,
      minPostPriceCopper = 1,
      scanMeanSeconds = 8.0,
      scanStdSeconds = 1.0,
      scanMinDelay = 5.0,
      scanMaxDelay = 20.0,
    },

    undercut = {
      repostWatchlist = {},
      useMainWatchlist = false,
      undercutCopper = 1,
      minPostPriceCopper = 1,
      tsmCapMult = 0.98,
      maxRelistPerTick = 3,
      relistDelaySeconds = 0.85,
      aggressiveScanRepost = false,
      postStackSize = 1,
      scanMeanSeconds = 10.0,
      scanStdSeconds = 1.2,
      scanMinDelay = 6.0,
      scanMaxDelay = 25.0,
    },
  },
}

return ScienceAHBot
