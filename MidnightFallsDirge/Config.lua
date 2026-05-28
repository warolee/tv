--[[ MidnightFallsDirge — runtime root returned from `require("Config")`.

     This plugin is the Midnight Falls "Death's Dirge" memory-game tracker.
     It reads the boss runes, builds the five-slot player→symbol sequence,
     and helps the raid execute it three ways:

       1. HUD overlay      — the full sequence on screen.
       2. Head icons       — the assigned symbol drawn above each player
                             (and, optionally, real WoW raid-target markers
                             set on those players via SetRaidTarget).
       3. Chat callouts    — announce the order to the group and/or whisper
                             each player their personal symbol.

     Detection uses the real Sylvanas `core.register_on_spell_cast_callback`
     plus aura polling (`game_object:get_auras()`); see DirgeTracker.lua.

     `DirgeTracker` reads `root.Config.behavior.dataSource`; when set to the
     string `"AddonOnly"` it disables poll-driven bookkeeping. Keep `"Auto"`.

     Every field below is a plain Lua value so it can be flipped at runtime
     (e.g. from the native menu in `Menu.lua`) without rebuilding the table. ]]

local ROOT = {}

ROOT.Config = {
  enabled = true,

  behavior = {
    dataSource = "Auto",
  },

  --- On-screen sequence panel (2D HUD).
  overlay = {
    enabled  = true,
    x        = 400,
    y        = 150,
    showIcons = true, --- draw little symbol glyphs next to each HUD row
  },

  --- Symbol drawn above each assigned player's head in the 3D world.
  headIcons = {
    enabled    = true,
    size       = 26,    --- glyph size in pixels at the player's screen pos
    heightZ    = 3.5,   --- yards above the unit origin to float the glyph
    showNumber = true,  --- draw the running-order number on the glyph
    showName   = false, --- draw the player name under the glyph
  },

  --- Real in-game raid-target markers (skull / cross / square / ...).
  --- Requires raid assist/lead. Purely optional; off by default because it
  --- writes group state that everyone sees. Turn on if you are marking.
  raidMarkers = {
    enabled        = false,
    clearOnReset   = true, --- wipe the markers we set when the sequence ends
  },

  --- Chat callouts. SAY / YELL are hardware-event restricted by Blizzard and
  --- usually will not fire from a script; RAID / RAID_WARNING / INSTANCE_CHAT
  --- / PARTY / WHISPER work inside instances. Default channel "AUTO" picks the
  --- best available group channel automatically.
  chat = {
    announce       = true,   --- post the full order to the group once per cast
    announceChannel = "AUTO", --- AUTO | RAID_WARNING | RAID | INSTANCE_CHAT | PARTY | SAY | YELL
    whisper        = true,   --- whisper each player their personal symbol
    prefix         = "[Dirge]",
  },

  --- Optional sound cue when a fresh sequence is detected.
  sound = {
    enabled = true,
    fileId  = 8959,
  },

  --- Spell-ID overrides. Leave nil to use the built-in defaults
  --- (dirgeStart 479150, laser 479160, laserHit 479165). If the tracker never
  --- triggers, turn on debug.logEvents below, watch the console when the memory
  --- game starts, then put the real IDs here.
  spells = {
    dirgeStart = nil,
    laser      = nil,
    laserHit   = nil,
  },

  --- Optional rune-aura override map. Leave nil to use the built-in five runes.
  --- Same shape as the defaults in DirgeTracker.lua:
  ---   runes = {
  ---     [<spellId>] = { label = "CROSS (X)", color = { 1, 0.3, 0.3, 1 }, marker = 7, shape = "cross" },
  ---     ...
  ---   }
  runes = nil,

  --- Discovery / debugging. logEvents logs every spell cast (id + name +
  --- caster/target); dumpAuras logs every new aura seen on players. Turn both
  --- on in-game when the memory game begins to confirm the real spell IDs.
  debug = {
    logEvents = false,
    dumpAuras = false,
    errorLogThrottleSec = 2.0,
  },
}

return ROOT
