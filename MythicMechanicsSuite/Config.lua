--[[ MythicMechanicsSuite — default configuration (namespace: root.Config).

     Everything in here is overwritten by `scripts_data/MythicMechanicsSuite/
     user_settings.lua` once the user toggles things in-game (see
     Persistence.lua). Keep the shape stable: bump
     Persistence.CURRENT_VERSION + add a migration if you change it. ]]

local MMS = {}

MMS.Config = {
  ---------------------------------------------------------------------
  --- Master switches
  ---------------------------------------------------------------------
  enabled = true,
  --- Show drawings only in instances (raid / mythic+ / dungeon). When
  --- false, drawings still render in the open world if a mechanic
  --- happens to match (handy for testing on training dummies).
  instanceOnly = true,

  ---------------------------------------------------------------------
  --- Visual style
  ---------------------------------------------------------------------
  draw = {
    --- 3D danger circle thickness (px) and segment count.
    circleThickness = 2.5,
    circleSegments = 48,
    --- Default circle radius if mechanic doesn't override (game yards).
    defaultRadius = 6.0,
    --- Beam / line thickness.
    lineThickness = 2.5,
    --- Cone draws as two edge lines + N filled triangle slices.
    coneSegments = 18,
    coneFilled = true,
    --- Optional translucent fill under danger circles.
    fillCircles = true,
    fillAlpha = 50,
    --- Text size for 3D labels above mechanic origins.
    text3dSize = 16,
    text2dSize = 18,
    --- Always draw a thin outline even when filled, so it stays
    --- readable on bright tilesets like Brackenhide / Theater.
    outlineWhenFilled = true,
  },

  ---------------------------------------------------------------------
  --- Color palette (RGBA 0..255). All mechanic types pick from here
  --- unless they override per-instance.
  ---------------------------------------------------------------------
  colors = {
    danger     = { r = 235, g = 60,  b = 60,  a = 235 },
    soak       = { r = 80,  g = 180, b = 255, a = 235 },
    dropoff    = { r = 255, g = 200, b = 60,  a = 235 },
    spread     = { r = 235, g = 130, b = 255, a = 235 },
    stack      = { r = 90,  g = 220, b = 120, a = 235 },
    cone       = { r = 235, g = 90,  b = 60,  a = 220 },
    line       = { r = 235, g = 60,  b = 60,  a = 220 },
    safe       = { r = 90,  g = 230, b = 130, a = 230 },
    text       = { r = 240, g = 240, b = 240, a = 255 },
    textShadow = { r = 10,  g = 10,  b = 10,  a = 200 },
  },

  ---------------------------------------------------------------------
  --- Sound / alert helper. Sound files are addressed by Sylvanas
  --- FileDataID; the suite ships with sensible defaults (8959 is the
  --- “whisper panic” FDID that ScienceAHBot already uses, so it is
  --- guaranteed to be present).
  ---------------------------------------------------------------------
  sound = {
    enabled = true,
    --- Per-priority alert sound IDs.
    alert      = 8959,
    --- Cooldown between identical sound triggers (seconds).
    cooldown   = 1.25,
    --- Don't play the same mechanic sound more than once inside this
    --- window even if the cast restarts.
    perMechanic = 4.0,
  },

  ---------------------------------------------------------------------
  --- UI: overlay window + master menu.
  ---------------------------------------------------------------------
  ui = {
    --- VK_F9 — toggles the overlay panel visibility.
    toggleKey = 0x78,
    defaultOpen = true,
    x = 48,
    y = 48,
    w = 520,
    h = 720,
    scale = 1.0,
  },

  ---------------------------------------------------------------------
  --- Per-encounter / per-mechanic toggles. Empty by default — every
  --- mechanic in the data files runs unless its key is set to `false`
  --- here. The Encounters tab writes booleans into this table.
  ---
  --- Keys are constructed as `"<encounterID>:<mechanicID>"` where
  --- mechanicID is the `id` field on the mechanic entry (defaults to
  --- the spellID/debuffID when missing).
  ---------------------------------------------------------------------
  toggles = {},

  ---------------------------------------------------------------------
  --- Debug
  ---------------------------------------------------------------------
  debug = {
    verbose = false,
    --- Log every encounter activation / mechanic trigger to chat.
    logEvents = false,
    --- Throttle (s) for repeated `safe_call` error labels.
    errorLogThrottleSec = 2.0,
    --- Show a small "debug HUD" listing active mechanics each frame.
    showHUD = false,
  },

  ---------------------------------------------------------------------
  --- Behavior knobs (rarely touched).
  ---------------------------------------------------------------------
  behavior = {
    --- How often (seconds) to re-scan object_manager for new
    --- enemy/boss units. Render still happens every frame; this
    --- only paces the more expensive "find new boss" lookups.
    rescanIntervalSec = 0.20,
    --- How often (seconds) to poll for new casts/auras on tracked
    --- units. 0 = every frame.
    pollIntervalSec = 0.05,
    --- Maximum number of active mechanic drawings the renderer will
    --- keep on screen at once. Excess are dropped (oldest first).
    maxActiveMechanics = 24,
    --- If true, mechanics whose anchor unit dies or vanishes are
    --- removed immediately rather than waiting for their natural
    --- expiry timestamp.
    dropOnAnchorGone = true,
    --- A debug field that mirrors `cfg.debug.errorLogThrottleSec`
    --- so `Util.safe_call` can find it on `root.Config.behavior`
    --- the same way ScienceAHBot does.
    debug = {
      errorLogThrottleSec = 2.0,
    },
  },
}

return MMS
