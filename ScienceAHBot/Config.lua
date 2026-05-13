--[[ ScienceAHBot — configuration (namespace: ScienceAHBot runtime table). ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}

ScienceAHBot.Config = {
  --- Populated in-game via the Items tab (file defaults stay empty).
  --- Example (comment only; use Items tab in-game):
  --- [190456] = { ratio = 0.70, name = "Draconic Vial" },
  --- [192101] = { ratio = 0.82, name = "Tenebrous Ribs" },
  Items = {},

  --- Used only if `Items` is empty (otherwise ignored).
  watchlist = {},

  --- Fallback max-pay ratio when an item has no `Items[id].ratio` (see `IsDeal`, `GetItemRatio`).
  DefaultRatio = 0.75,

  buyRatio = nil,

  thresholds = {
    defaultBuyRatio = 0.75,
  },

  jitter = {
    --- Spec: bell-curve scan pacing mean 4.5s, std dev 1.2s (clamped below).
    scanMeanSeconds = 4.5,
    scanStdSeconds = 1.2,
    scanMinDelay = 2.5,
    scanMaxDelay = 8.0,
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
      --- F8 — edge toggle `ManualPause` (does not edit Items; does not whisper-panic).
      manualPauseKey = 0x77,
      manualPausePlaySound = false,
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
      --- Lazy repost after undercut (social delay) — seconds.
      socialRepostDelayMinSec = 5 * 60,
      socialRepostDelayMaxSec = 10 * 60,
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

    --- Non-AH UI breaks (character sheet, bag/spellbook) to dilute interaction signature.
    distraction = {
      enabled = true,
      extraOpenChance = 0.30,
    },

    --- When `requireAuctionFrame` is true, `SearchForItem` runs only if AH UI appears open (retail/classic frames).
    ahGuard = {
      requireAuctionFrame = true,
      maxSearchFailStreak = 5,
      searchBackoffSeconds = 30,
    },

    --- Verbose tick logs, dry-run (no IZI bid/post/cancel), optional auction chat hints.
    debug = {
      verbose = false,
      dryRun = false,
      logAuctionChat = true,
      --- Throttled `core.log` lines for deferred IZI fallback queue (low volume; avoids tick spam).
      scheduleDiag = false,
      scheduleDiagMinIntervalSec = 1.5,
      --- Minimum seconds between identical `Util.safe_call` labels on the same `root` (error log flood control).
      errorLogThrottleSec = 2.0,
    },
  },
}

--- Per-item learned stats (AH listing / TSM); persisted to user_settings.lua.
ScienceAHBot.Config.patterns = ScienceAHBot.Config.patterns or {}

return ScienceAHBot
