# MidnightFalls — Death's Dirge memory-game tracker

A standalone **Project Sylvanas** plugin that solves the **Death's Dirge** memory
game on the **Midnight Falls** raid encounter (March on Quel'Danas).

When the boss casts **Death's Dirge** (`479150`) it brands five players with
rune symbols. Each branded player must run into the boss **in the order the
runes were applied** during the laser phase. This plugin reads that order off
the fight and helps the whole raid execute it:

1. **Tells you the sequence** — a 2D HUD overlay lists the run-in order, one row
   per player, each with a coloured symbol chip.
2. **Puts the symbol above each player's head** — the assigned glyph
   (cross / square / circle / diamond / triangle) is drawn in the world above
   the player it belongs to, with the running-order number, and flashes + drops
   a ground ring on the player who must run in *right now*.
3. **Calls it out in chat** — announces the full order to the group
   (raid warning / raid / instance / party, auto-selected) and optionally
   **whispers each player their own symbol** so nobody has to read the HUD.
4. *(optional)* **Sets real raid-target markers** on the assigned players via
   `SetRaidTarget`, so the markers also show on standard nameplates/raid frames.

The runes line up 1:1 with WoW raid-target marker colours, so the drawn glyph
and any real marker match:

| Rune aura | Symbol | Colour | Raid marker |
|---|---|---|---|
| `479151` | Cross (X) | red | 7 (Cross) |
| `479152` | Square | blue | 6 (Square) |
| `479153` | Circle | orange | 2 (Circle) |
| `479154` | Diamond | purple | 3 (Diamond) |
| `479155` | Triangle | green | 4 (Triangle) |

## How it detects the sequence

`DirgeTracker.lua` runs a small state machine:

- `SPELL_CAST_START` of **Death's Dirge** (`479150`) → reset + start *recording*.
- `SPELL_AURA_APPLIED` of a rune (`479151`–`479155`) while recording → append
  `{ player, symbol }` to the queue (deduped per player, capped at five).
- `SPELL_CAST_START`/`_SUCCESS` of the **laser** (`479160`) → enter *beam* phase
  and start expecting players in order.
- `SPELL_DAMAGE` of the **laser hit** (`479165`) on the expected player →
  advance to the next slot and flash that player.

Two input paths feed the machine so it works on any Sylvanas build:

- **Combat-log hook** — `core.register_on_combat_log_callback` (and a couple of
  alternate names) if the host exposes one. Handles both positional WoW-style
  varargs and single-table payloads.
- **Object-manager polling** — when no combat-log callback exists, `tick()`
  polls player auras (`get_aura_by_id`) and boss casts (`get_active_spell_id`)
  through `World.lua`.

Callouts, markers and the sound cue fire **exactly once per sequence**, the
moment all five runes are collected (or the laser starts, whichever is first).

## Configuration

All behaviour is plain Lua in `Config.lua` and can also be toggled in-game from
the native Sylvanas menu (`Menu.lua`) under **"Midnight Falls — Death's Dirge"**:

| Group | Field | Default | Meaning |
|---|---|---|---|
| — | `enabled` | `true` | Master on/off. |
| `overlay` | `enabled` / `x` / `y` / `showIcons` | on, 400/150, icons on | 2D HUD list of the order. |
| `headIcons` | `enabled` / `size` / `heightZ` / `showNumber` / `showName` | on | Symbol glyphs above players. |
| `raidMarkers` | `enabled` / `clearOnReset` | **off** / on | Real `SetRaidTarget` markers (needs raid assist). |
| `chat` | `announce` / `announceChannel` / `whisper` / `prefix` | on / `AUTO` / on / `[Dirge]` | Group callout + per-player whisper. |
| `sound` | `enabled` / `fileId` | on / `8959` | Cue when a new sequence is detected. |

`announceChannel = "AUTO"` picks the best channel available: **RAID_WARNING** if
you have assist/lead, otherwise **RAID** / **INSTANCE_CHAT** / **PARTY** / **SAY**.
You can pin it to any of `RAID_WARNING` / `RAID` / `INSTANCE_CHAT` / `PARTY` /
`SAY` / `YELL`. Note Blizzard hardware-gates `SAY` / `YELL`, so those usually
will not fire from a script — the group/whisper channels do.

`behavior.dataSource` mirrors the rest of the suite: keep `"Auto"`; set
`"AddonOnly"` to silence this plugin's own detection when another pipeline owns
the timing.

## File map

| File | Role |
|---|---|
| `header.lua` | Sylvanas plugin metadata. |
| `main.lua` | Entry: installs the tracker + menu, registers update/render callbacks. |
| `Config.lua` | Default runtime config (overlay / head icons / markers / chat / sound). |
| `DirgeTracker.lua` | The state machine, combat parsing, polling, rendering, and callout trigger. |
| `Chat.lua` | Group announce + per-player whisper via `_G.SendChatMessage`. |
| `Markers.lua` | Symbol glyph drawing (2D) + optional real `SetRaidTarget` markers. |
| `Menu.lua` | Native `core.menu` toggles mirrored into `Config`. |
| `Draw.lua` / `Geometry.lua` / `World.lua` / `Util.lua` | Bundled helpers (same as the suite). |

## Requirements

- Project Sylvanas with plugin loading enabled; folder `MidnightFallsDirge`
  under the `scripts/` directory.
- `core.graphics`, `core.object_manager`, and at least one render callback.
- Chat callouts need the FrameXML global `SendChatMessage` (present in the game
  Lua env); raid markers need `SetRaidTarget` **and** raid assist/lead. Both are
  feature-detected and degrade silently when unavailable.

## Safety

The drawing and detection are read-only. The opt-in extras **do** write game
state: `SendChatMessage` posts to chat and `SetRaidTarget` marks players. They
are guarded by config toggles (markers default **off**) and wrapped in `pcall`.
As always, unlockers carry ToS risk — use only where you accept it.
