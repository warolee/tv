--[[
  ScienceAHBot — user configuration (watchlist, thresholds, jitter).
  All settings live under AH_Bot.Config to keep a single local namespace.
]]

local AH_Bot = {}

---@class ScienceAHBotConfig
AH_Bot.Config = {
  --- Optional shortcut used by Core (`nil` uses thresholds.defaultBuyRatio).
  buyRatio = nil,

  --- Item IDs to monitor (The War Within examples — adjust to your realm).
  watchlist = {
    -- Herbs
    210805, -- Mycobloom
    210806, -- Luredrop
    210807, -- Orbinid
    210808, -- Blessing Blossom
    210809, -- Arathor's Spear
    210810, -- Roaring Dragonwort
    -- Ore / stone
    210930, -- Bismuth
    210931, -- Ironclaw Ore
    210932, -- Aqirite
    210933, -- Null Stone
  },

  thresholds = {
    --- Buy when listed price is at or below this fraction of TSM DBMarket (0.75 = 75%).
    defaultBuyRatio = 0.75,
  },

  --- Gaussian scan pacing + cognitive delay bounds (seconds).
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

  --- After this many seconds of active bot time, force a rest (see Core fatigue).
  fatigueUptimeSeconds = 60 * 60,
  fatigueRestSeconds = 10 * 60,
}

return AH_Bot
