--[[ ScienceAHBot — configuration (namespace: ScienceAHBot runtime table). ]]

local ScienceAHBot = {}

ScienceAHBot.Config = {
  --- Populated in-game via the Items tab (file defaults stay empty).
  Items = {},

  --- Used only if `Items` is empty (otherwise ignored).
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
      w = 560,
      h = 960,
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

    --- Adaptive buy/snipe: EWMA of (AH row1 / TSM DBMarket), saved in patterns (see Persistence).
    learn = {
      enabled = true,
      blend = 0.35,
      ewmaAlpha = 0.15,
      slack = 0.025,
      minSamples = 5,
    },

    --- CSV scan/deal log (separate file from user_settings). Default off.
    scanLog = {
      enabled = false,
      flushEveryRows = 8,
      flushDebounceSec = 2.0,
      maxFileBytes = 3145728,
    },
  },
}

--- Per-item learned stats (AH listing / TSM); persisted to user_settings.lua.
ScienceAHBot.Config.patterns = ScienceAHBot.Config.patterns or {}

return ScienceAHBot
