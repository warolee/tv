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
  --- Appearance customization. The `colors` palette below holds the
  --- live RGBA values used by the drawing engine. `appearance.preset`
  --- names which preset the palette currently matches (gets set to
  --- "custom" the moment the user nudges any RGB slider).
  ---
  --- `globalAlphaMult` is a 0.2 .. 1.5 multiplier applied to every
  --- palette alpha at draw time, so the user can dim or brighten the
  --- whole HUD without editing each color individually. Implemented
  --- in `Mechanics.resolve_color`.
  ---------------------------------------------------------------------
  appearance = {
    preset = "default",
    globalAlphaMult = 1.0,
  },

  ---------------------------------------------------------------------
  --- Color palette (RGBA 0..255). All mechanic types pick from here
  --- unless they override per-instance. Edit live from the Appearance
  --- tab (per-color R/G/B sliders + preset combobox).
  ---------------------------------------------------------------------
  colors = {
    danger     = { r = 235, g = 60,  b = 60,  a = 235 },
    warning    = { r = 255, g = 200, b = 60,  a = 235 },
    info       = { r = 80,  g = 180, b = 255, a = 235 },
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
  --- Per-mechanic palette override for world drawings. Keys match
  --- `Encounters.toggle_key(enc, mech)` (`"<encID>:<mechID>"`).
  --- Value is a palette name string (`"danger"`, `"info"`, …) from
  --- `Config.colors`. Absent / cleared keys inherit the mechanic row
  --- from `data/*.lua` (`mech.color` string or RGBA table).
  ---------------------------------------------------------------------
  mechanicPalettes = {},

  ---------------------------------------------------------------------
  --- BigWigs / Deadly Boss Mods bridge.
  ---
  --- When BW or DBM is loaded in the WoW addon environment (detected
  --- via `_G.DBM`, `_G.BigWigsLoader`, or `_G.LibStub("AceEvent-3.0")`)
  --- and the corresponding `mirror.*` flag is true, the suite subscribes
  --- to their bar/message events and spawns MMS warnings from them.
  ---
  --- `nil` (the default for `dbm` and `bigwigs`) means "auto-enable if
  --- detected"; once the user explicitly flips the Settings tab toggle
  --- it becomes a hard true/false override and stays that way.
  ---------------------------------------------------------------------
  mirror = {
    --- Subscribe to DBM_TimerStart / DBM_Announce / DBM_TimerStop.
    dbm = nil,
    --- Subscribe to BigWigs_StartBar / BigWigs_Message / BigWigs_StopBar.
    bigwigs = nil,
    --- When an event arrives with a spell id that ISN'T in our
    --- encounter registry, fall back to a generic 3D text warning
    --- above the local player using the event's message text. Off by
    --- default so you only see warnings for mechanics we know how to
    --- draw spatially; turn on for a "DBM-lite" experience.
    generic_fallback = false,
    --- Fallback duration (seconds) for BW/DBM `Message` events that
    --- don't ship a bar duration. Bar events always use the reported
    --- `time` parameter.
    fallback_duration = 3.0,
    --- Suppress the Tracker's own cast/aura detection for a spell id
    --- after the bridge has just fired for it on the local player.
    --- Window in seconds.
    dedupe_window = 8.0,
  },

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
    ---------------------------------------------------------------
    --- Data-source routing.
    ---
    --- Controls which signal path is allowed to spawn warnings:
    ---
    ---   "Auto"           Both paths run. Tracker (local polled
    ---                    object_manager) AND the BW/DBM bridge can
    ---                    fire; the bridge wins per-spell via the
    ---                    dedupe window in `mirror.dedupe_window`.
    ---                    Use this when you want maximum coverage
    ---                    and the engine to gracefully fall back
    ---                    when addons aren't loaded.
    ---
    ---   "HardcodedOnly"  Local Tracker only. BW/DBM events are
    ---                    swallowed silently. Use when you want
    ---                    deterministic behavior driven purely by
    ---                    our data/*.lua spell-id registry.
    ---
    ---   "AddonOnly"      Strict mirror mode. Tracker polling is
    ---                    skipped entirely (saves CPU). Only
    ---                    BW/DBM events render. Use when both
    ---                    addons are loaded and you trust them
    ---                    over our registry.
    ---
    --- Changing this at runtime takes effect on the next frame —
    --- no reload required.
    ---------------------------------------------------------------
    dataSource = "Auto",

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
