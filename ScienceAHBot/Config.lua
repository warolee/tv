--[[
  ScienceAHBot — configuration: watchlist, thresholds, jitter, behavior (BC), UI defaults.
]]

local AH_Bot = {}

AH_Bot.Config = {
  buyRatio = nil,

  watchlist = {
    210805,
    210806,
    210807,
    210808,
    210809,
    210810,
    210930,
    210931,
    210932,
    210933,
  },

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

  fatigueUptimeSeconds = 60 * 60,
  fatigueRestSeconds = 10 * 60,

  --- Behavior control (BC): which subsystems run and how aggressive they are.
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
      y = 72,
      w = 460,
      h = 560,
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

return AH_Bot
