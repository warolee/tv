# MidnightFalls — Death's Dirge memory-game tracker

A standalone **Project Sylvanas** plugin that solves the **Death's Dirge** memory
game on the **Midnight Falls** raid encounter (March on Quel'Danas).

When the boss casts **Death's Dirge** it brands five players with rune symbols.
Each branded player must run into the boss **in the order the runes were applied**
during the laser phase. This plugin reads that order off the fight and helps the
whole raid execute it:

1. **Tells you the sequence** — a 2D HUD overlay lists the run-in order, one row
   per player, each with a coloured symbol chip.
2. **Puts the symbol above each player's head** — the assigned glyph
   (cross / square / circle / diamond / triangle) is drawn in the world above
   the player it belongs to, with the running-order number, and flashes + drops
   a ground ring on the player who must run in *right now*.
3. **Calls it out in chat** — announces the full order to the group
   (raid warning / raid / instance / party, auto-selected) and optionally
   **whispers each player their own symbol**.
4. *(optional)* **Sets real raid-target markers** on the assigned players via
   `SetRaidTarget`.

The runes line up 1:1 with WoW raid-target marker colours:

| Rune | Symbol | Colour | Raid marker |
|---|---|---|---|
| `479151` | Cross (X) | red | 7 (Cross) |
| `479152` | Square | blue | 6 (Square) |
| `479153` | Circle | orange | 2 (Circle) |
| `479154` | Diamond | purple | 3 (Diamond) |
| `479155` | Triangle | green | 4 (Triangle) |

## How it detects the sequence (real Sylvanas API)

Detection is built on the **actual** Project Sylvanas API (verified against
`github.com/bluesilvi/project-sylvanas`, `legacy/_api`). The platform has **no
combat-log callback**, so this plugin uses:

- **`core.register_on_spell_cast_callback(fn)`** — fires for every spell cast
  with `{ spell_id, caster, target }`. Used to catch:
  - the **Death's Dirge** cast (`479150`) → reset + start *recording*;
  - the **laser** (`479160`) → enter *beam* phase + fire callouts;
  - the **laser hit** (`479165`, `target` = the player) → advance the order;
  - per-target rune casts, if the boss brands that way.
- **Aura polling** (`game_object:get_auras()` / `get_debuffs()`, matched by
  `buff_id`) in the `On Update` tick — reads the rune symbols off players and
  **auto-starts recording** if a rune shows up even when the cast was missed.
- **Boss-cast polling** (`get_active_spell_id()`) as a backup trigger.

> The previous version relied on `core.register_on_combat_log_callback`,
> `object_manager.get_all_players()`, and `get_aura_by_id()` — **none of which
> exist** on Project Sylvanas — so it silently never triggered. That is fixed.

## Troubleshooting — "it never triggers"

If the overlay never appears when the memory game starts, the spell IDs in your
build probably differ from the defaults. Find the real ones:

1. In `Config.lua`, set `debug.logEvents = true` (and optionally
   `debug.dumpAuras = true`).
2. Pull the boss to the Death's Dirge cast and watch the Sylvanas console:
   - `[Dirge][cast] id=… (Name) caster=… target=…` shows every cast — find the
     Death's Dirge / laser / laser-hit IDs.
   - `[Dirge][aura] player=… buff_id=… name=…` shows every new aura on players —
     find the five rune `buff_id`s.
3. Put the real IDs into `Config.spells` and/or `Config.runes`:

```lua
spells = { dirgeStart = 479150, laser = 479160, laserHit = 479165 },
runes = {
  [479151] = { label = "CROSS (X)", color = { 1, 0.3, 0.3, 1 }, marker = 7, shape = "cross" },
  -- ... the other four ...
}
```

No code edits needed — just the IDs.

## Configuration

All behaviour is plain Lua in `Config.lua`, also toggleable in-game from the
native Sylvanas menu (`Menu.lua`) under **"Midnight Falls — Death's Dirge"**:

| Group | Field | Default | Meaning |
|---|---|---|---|
| — | `enabled` | `true` | Master on/off. |
| `overlay` | `enabled` / `x` / `y` / `showIcons` | on, 400/150, icons on | 2D HUD list of the order. |
| `headIcons` | `enabled` / `size` / `heightZ` / `showNumber` / `showName` | on | Symbol glyphs above players. |
| `raidMarkers` | `enabled` / `clearOnReset` | **off** / on | Real `SetRaidTarget` markers (needs raid assist; best-effort). |
| `chat` | `announce` / `announceChannel` / `whisper` / `prefix` | on / `AUTO` / on / `[Dirge]` | Group callout + per-player whisper (best-effort). |
| `sound` | `enabled` / `fileId` | on / `8959` | Cue (`core.play_sound_by_id`) when a sequence is detected. |
| `spells` | `dirgeStart` / `laser` / `laserHit` | nil → defaults | Spell-ID overrides. |
| `runes` | map | nil → defaults | Rune-aura override map. |
| `debug` | `logEvents` / `dumpAuras` | off | Discovery logging (see Troubleshooting). |

`announceChannel = "AUTO"` picks the best channel available: **RAID_WARNING** if
you have assist/lead, otherwise **RAID** / **INSTANCE_CHAT** / **PARTY** / **SAY**.
`SAY`/`YELL` are hardware-gated by Blizzard and usually won't fire from a script.

> Chat (`SendChatMessage`) and real markers (`SetRaidTarget`) are WoW FrameXML
> globals reached via `_G`. They work where Sylvanas exposes the game Lua env and
> degrade silently otherwise — the overlay and head icons always work regardless.

## File map

| File | Role |
|---|---|
| `header.lua` | Sylvanas plugin metadata. |
| `main.lua` | Entry: installs the tracker + menu, registers update/render callbacks. |
| `Config.lua` | Default runtime config + spell-ID/rune overrides + debug toggles. |
| `DirgeTracker.lua` | State machine, spell-cast detection, aura polling, rendering, callouts, discovery logging. |
| `Chat.lua` | Group announce + per-player whisper via `_G.SendChatMessage`. |
| `Markers.lua` | Symbol glyph drawing (2D) + optional real `SetRaidTarget` markers. |
| `Menu.lua` | Native `core.menu` toggles mirrored into `Config`. |
| `Draw.lua` / `Geometry.lua` / `World.lua` / `Util.lua` | Bundled helpers (real-API object manager + aura accessors). |

## Requirements

- Project Sylvanas with plugin loading enabled; folder `MidnightFallsDirge`
  under the `scripts/` directory.
- `core.graphics`, `core.object_manager`, `core.register_on_spell_cast_callback`,
  and the update/render callbacks. All feature-detected.
- Chat/markers additionally need the FrameXML globals `SendChatMessage` /
  `SetRaidTarget` (and raid assist for markers).

## Safety

Detection and drawing are read-only. The opt-in extras write game state
(`SendChatMessage` posts chat; `SetRaidTarget` marks players) and are guarded by
config toggles (markers default **off**) and `pcall`. Unlockers carry ToS risk.
