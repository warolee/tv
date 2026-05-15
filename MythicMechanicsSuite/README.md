# MythicMechanicsSuite

A **Project Sylvanas** plugin that draws **dangerous mechanic warnings** for Mythic+ dungeons and raid encounters directly in the world: ground circles, frontal cones, beam lines, "drop puddle here" indicators, soak markers, and 3D text labels. Inspired by Deadly Boss Mods / BigWigs, rendered entirely through the Sylvanas `core.graphics` API so it works inside an unlocker without depending on the official addon environment.

Official Sylvanas dev docs: <https://docs.project-sylvanas.net/dev/>

> The plugin **only draws**. It does not move you, click anything, or interact with the game. Drawings are warnings — you still have to do the mechanic.

### BigWigs / DBM bridge (optional, auto-detected)

When **BigWigs** and/or **Deadly Boss Mods** is loaded in the WoW addon environment, the suite subscribes to their event streams and routes the warnings through the same drawing engine. This solves the placeholder-spell-ID problem on day 1 of a new patch and gives you the *pre-cast* timing BW/DBM ships with, instead of waiting for our own polled detection to spot the cast.

How it works:

- On load, `BWDBMBridge.lua` probes `_G.DBM` and `LibStub("AceEvent-3.0")` (the same way `ScienceAHBot` probes `_G.TSM_API`). If either resolves it registers callbacks:
  - DBM — `DBM_TimerStart`, `DBM_Announce`
  - BigWigs — `BigWigs_StartBar`, `BigWigs_Message`
- When an event arrives **with a `spellId`**:
  - If the id is in our encounter registry, we spawn the registered shape (circle / cone / beam / drop puddle) **with the BW/DBM-reported duration**. The data file says *how* to draw it, BW/DBM says *when* and *for how long*.
  - If the id isn't in the registry **and** "Generic fallback (text above me) for unknown spell IDs" is on in the Settings tab, we draw a generic 3D text warning above the local player using the event's message text. Off by default — you only get warnings for mechanics we know how to draw spatially.
- The Tracker's polled detection is **deduped** for `mirror.dedupe_window` seconds (default 8 s) per spell id, so a real cast that lights up both paths only renders once.
- Each bridge-spawned warning is tagged `[BW]` or `[DBM]` in its 3D label and in the **Active** tab list, so you can tell at a glance which path triggered it.

Auto-enable rules: on first install the `Mirror DBM` and `Mirror BigWigs` toggles default to *whatever was detected* (so a fresh install with BigWigs loaded just works). Once you flip a toggle explicitly in the Settings tab the override sticks.

The bridge is purely additive: with no BW/DBM loaded, MMS works exactly as it did before (engine driven by `data/raids_midnight.lua` + `data/mplus_midnight.lua`).

## What it does

### Cast-triggered drawings

When a boss / dungeon enemy starts casting a known mechanic spell, the suite spawns a 3D drawing around the caster (or the caster's target, depending on the mechanic) for the duration of the cast:

* **`circle`** — danger ring on the ground (e.g. *Boomba B-Gone*, *Ingest Black Blood*).
* **`cone`** — frontal cone (e.g. *Phase Blades*, *Voracious Bite*).
* **`beam`** — directional rectangle (e.g. *Decapitate*, *Burrow Charge*, *Rolling Acid*).
* **`text`** — floating label above the mechanic origin.

### Aura-triggered drawings

When a configured buff/debuff appears on the local player (`affects_player_only = true`) or any friendly player (raid-wide), the suite spawns:

* **`drop_circle`** — yellow puddle-drop indicator (drop the debuff away from the raid).
* **`soak_circle`** — blue "stand here to soak" indicator.
* **`spread_circle`** — purple "minimum spread" indicator.
* **`stack_circle`** — green "stack with raid" indicator.

Drawings disappear when the cast completes / the aura fades, or after the mechanic's configured `duration` if it should outlive the trigger (lingering ground effects).

### In-game UI

The suite uses the **`astro_custom_ui/rotation_settings_ui`** library — the same custom window framework that `ScienceAHBot` ships with. Drop the `astro_custom_ui/` folder next to `MythicMechanicsSuite/` in your Sylvanas `scripts/` directory (this repo already has it at the workspace root). The library renders an `astro`-themed window with built-in tab bar, persistence, sliders, checkboxes, and drag-resize.

* **Sylvanas native menu** — `core.menu.tree_node` under *"Mythic Mechanics Suite"* with a master enable checkbox and a "Show settings window" toggle. Same UX as ScienceAHBot.
* **Astro custom window** (default key `F9`, also openable from the native menu) with three tabs:
  * **Settings** — built from `rotation_settings_ui` builders:
    * `checkbox_grid`: Master enable, Only inside instances, Sound alerts, Drop warning if anchor dies; Fill danger circles, Outline when filled, Fill cone slices, Debug HUD; Log every trigger, Verbose chat.
    * `slider_list`: Circle thickness, Line thickness, Default radius, Circle segments, 3D text size, Fill alpha, Sound cooldowns, Alert FileDataID, Aura/cast poll interval, Rescan interval, Max active warnings.
    All sliders persist via Sylvanas's built-in menu state (so values survive `/reload` even before the debounce-save to `scripts_data/` fires).
  * **Encounters** — `custom_panel` with filter buttons (`all / raid / mplus`), a placeholder-count pill (`Spell IDs: 104 / 104 are PLACEHOLDERS — edit data/*.lua`), and a scrollable list (mouse-wheel) of every encounter and every mechanic with click-to-toggle checkboxes. Mechanics with placeholder spell IDs are tinted in the secondary-accent colour and suffixed with `*`.
  * **Active** — `custom_panel` showing the live list of currently drawn mechanics (encounter, mechanic name, type, remaining time). Includes a **Test: draw at me** button to spawn a ring on the local player to verify the drawing pipeline, and a **Clear all** button.

Window position, size, active tab, and visibility persist through `rotation_settings_ui`'s ghost menu elements; the rest (per-mechanic toggles, palette, draw style) persists via debounced save to `scripts_data/MythicMechanicsSuite/user_settings.lua` ~0.85 s after the last edit.

### Sound alerts

Each mechanic can request a sound via `sound = true` (uses `Config.sound.alert`, default FileDataID `8959`) or an explicit FDID. Sounds are rate-limited per mechanic (`Config.sound.perMechanic`, default 4s) so repeated casts don't spam.

### Encounter coverage (Midnight 12.0.5 — Season 1, March 2026)

Out of the box the suite ships with mechanic data for the **Midnight** raid tier and Season 1 Mythic+ rotation:

* **The Voidspire** (Voidstorm, 6 bosses): Imperator Averzian, Vorasius, Fallen-King Salhadaar, Vaelgor & Ezzorak, Lightblinded Vanguard, Crown of the Cosmos.
* **The Dreamrift** (Harandar, 1 boss): Chimaerus, the Undreamt God.
* **March on Quel'Danas** (Isle of Quel'Danas, 2 bosses): Belo'ren — Child of Al'ar, Midnight Falls.
* **Mythic+ Season 1** — four new Midnight dungeons:
  * **Magisters' Terrace** — Arcanotron Custos, Seranel Sunlash, Gemellus, Degentrius.
  * **Maisara Caverns** — Muro'jin & Nekraxx, Vordaza, Rak'tul Vessel of Souls.
  * **Nexus-Point Xenas** — Chief Corewright Kasreth, Corewarden Nysarra, Lothraxion.
  * **Windrunner Spire** — Emberdawn, Derelict Duo (Kalis & Latch), Commander Kroluk, The Restless Heart.
* **Mythic+ Season 1 legacy rotation** — Algeth'ar Academy (Dragonflight), Pit of Saron (WotLK), Seat of the Triumvirate (Legion), Skyreach (Warlords of Draenor).

Mechanic **names**, **types**, **anchors**, and **priorities** are sourced from Wowhead, Icy Veins, and Method strategy guides for Midnight Season 1.

### Placeholder spell IDs (important)

Because **Midnight 12.0.5 is brand new**, authoritative spell IDs for the new bosses are still being datamined. Every mechanic in the data files therefore ships with a **placeholder** `spellID` in the `1200000+` / `1300000+` / `1310000+` range and an explicit `_placeholder = true` flag.

**What this means in practice:** Until you replace those placeholders with real spell IDs, the engine will never match a live cast or aura to the entry — no warning will fire. The **Settings** tab shows a live counter:

> *Spell IDs: 117 / 117 are PLACEHOLDERS — edit data/\*.lua*

The same counter is also reported in the chat log on plugin load (via `Preflight`).

**How to fix it**: in-game, target the boss casting the mechanic and run

```
/dump UnitCastingInfo("target")
```

`UnitCastingInfo` returns the spellID as one of its tuple values; or grab it from Wowhead's spell page URL. Then edit the matching entry in [`data/raids_midnight.lua`](data/raids_midnight.lua) / [`data/mplus_midnight.lua`](data/mplus_midnight.lua):

```lua
{ id = "void_convergence",
  spellID = 1234567,            -- ← real id pasted in
  -- _placeholder = true,       -- remove this line (or set to false)
  trigger = "cast", type = "circle", radius = 6, priority = "high",
  color = "danger", anchor = "caster", message = "Kill the orbs!" },
```

Reload the plugin and that mechanic now fires from real combat data.

The data files are plain Lua tables, easy to edit. The engine itself is unchanged when the data refreshes — all the placeholder mess is contained in `data/`.

## File map

| File | Role |
|------|------|
| `header.lua` | Sylvanas plugin metadata. |
| `main.lua` | Entry: wires modules, registers `core.register_on_update_callback` + `core.register_on_render_callback`. |
| `Config.lua` | Default `MMS.Config` (palette, draw style, sound, UI, behavior). |
| `Util.lua` | `safe_call` fault boundary + throttled error logging. |
| `Geometry.lua` | `vec2` / `vec3` constructors, distance, cone / circle point sampling. |
| `Draw.lua` | Thin wrapper over `core.graphics` (3D circle / line / beam / cone / text + 2D rect / text). |
| `World.lua` | `core.object_manager` helpers (local player, enemies, players, position, rotation, cast / aura). |
| `Tracker.lua` | Per-tick poller that synthesises `cast_start`, `cast_end`, `aura_apply`, `aura_fade` events. |
| `Mechanics.lua` | Runtime: subscribes to Tracker events, spawns active warnings, runs the per-frame render loop. |
| `Encounters.lua` | Registry of all encounter / mechanic data + lookup helpers. |
| `Sound.lua` | Sound playback wrapper (tries `core.play_sound` → `core.audio.play_sound` → `PlaySound`). |
| `Persistence.lua` | Load / save `user_settings.lua` under `scripts_data/MythicMechanicsSuite/`. |
| `Preflight.lua` | Warns about missing Sylvanas APIs on load. |
| `UI.lua` | Native Sylvanas menu integration + astro window installer (Settings / Encounters / Active tabs). |
| `AstroMenu.lua` | Ghost `core.menu` checkbox / slider elements for the Settings tab + bidirectional sync with `root.Config`. |
| `AstroPanels.lua` | `custom_panel` renderers for the Encounters and Active tabs (drawn through `rot.window:render_*`). |
| `BWDBMBridge.lua` | Optional BigWigs / Deadly Boss Mods event bridge — probes `_G.DBM` and `LibStub("AceEvent-3.0")`, subscribes to bar / message events, and routes them through the same Mechanics engine. Tracker dedupe prevents double-firing. |
| `data/raids_midnight.lua` | Raid encounter data — Voidspire, Dreamrift, March on Quel'Danas (Midnight 12.0.5). |
| `data/mplus_midnight.lua` | Mythic+ Season 1 dungeon encounter data — Magisters' Terrace, Maisara Caverns, Nexus-Point Xenas, Windrunner Spire + Algeth'ar Academy, Pit of Saron, Seat of the Triumvirate, Skyreach. |

## Requirements

* **Project Sylvanas** with plugin loading enabled.
* Plugin folder `MythicMechanicsSuite` placed under the Sylvanas `scripts/` directory.
* `astro_custom_ui/` folder placed **next to** `MythicMechanicsSuite/` in the same `scripts/` directory (this repo already ships it at the workspace root). The Astro window will silently disable itself if the library isn't on the path, but the mechanic-drawing engine keeps working.
* `core.graphics`, `core.object_manager`, `core.menu`, `core.menu.window`, and at least one of `core.register_on_render_callback` / `core.register_on_render_menu_callback`. Preflight will warn if any are missing.

No other external addon dependency — unlike `ScienceAHBot`, this plugin does **not** require TradeSkillMaster, IZI SDK, or any other library.

**Optional integrations** that activate automatically when detected:

- **BigWigs** (via `LibStub("AceEvent-3.0")`) — bar / message events are mirrored into MMS warnings using the BigWigs-reported duration.
- **Deadly Boss Mods** (via `_G.DBM:RegisterCallback`) — `DBM_TimerStart` and `DBM_Announce` are mirrored the same way.

Both can be turned on/off from the Settings tab independently. With neither loaded the engine falls back to its own `core.object_manager` polling against the registry in `data/*.lua`.

## Install

1. Copy the entire `MythicMechanicsSuite` directory into your Sylvanas plugins folder (next to `ScienceAHBot`).
2. Restart or reload plugins.
3. Confirm the client log shows `[MythicMechanicsSuite] Loaded v0.1.0 (...)`.
4. Open the overlay with **F9** (default) and visit the **Encounters** tab to disable any mechanic you don't want warnings for.

If the loader complains about `MythicMechanicsSuite\MythicMechanicsSuite\Config.lua` not being found, that's the same nested-folder pitfall the ScienceAHBot README documents: Sylvanas resolves `require()` from the plugin's own folder, so this repo uses `require("Config")`, `require("Mechanics")`, etc., for modules that live next to `main.lua`.

## How to add or fix an encounter

Each entry in `data/raids_tww.lua` or `data/mplus_tww.lua` looks like:

```lua
{
  id = 2917,                            -- WoW encounter / NPC id (any unique number)
  name = "The Bloodbound Horror",
  kind = "raid",                        -- "raid" or "mplus"
  zone = "Nerub-ar Palace",             -- display only
  npc_ids = { 214502 },
  mechanics = {
    { id        = "crimson_rain",
      spellID   = 444363,
      trigger   = "cast",               -- "cast" | "aura_apply" | "aura_fade"
      type      = "circle",             -- "circle" | "cone" | "beam" | "drop_circle" | ...
      radius    = 8,                    -- yards
      priority  = "high",               -- "low" | "medium" | "high"
      color     = "danger",             -- palette key or { r, g, b, a }
      anchor    = "caster",             -- "caster" | "target" | "player"
      message   = "Move out of pools",
    },
    { id        = "gruesome_disgorge",
      spellID   = 443274,
      trigger   = "aura_apply",
      aura_kind = "debuff",
      type      = "drop_circle",
      radius    = 8,
      priority  = "high",
      affects_player_only = true,
    },
  },
}
```

Just edit the file and reload the plugin. To quickly check whether your changes actually fire, enable **Debug HUD** in the overlay Settings tab — you'll see a top-left readout of every active mechanic in real time.

## Known limitations

* **Placeholder spell IDs.** As described above, Midnight 12.0.5 content ships with placeholder ids because authoritative dumps aren't out yet. The Settings tab shows the live count. Replace them in the data files as you confirm them in-game.
* **Spell IDs drift.** Every WoW patch can renumber spells. The data files err toward `priority = "low"` when an id is uncertain so a stale entry mostly costs you a missed warning, not a false alarm. PRs welcome.
* **No interrupt scheduler.** This is a *drawing* suite, not a rotation helper. It does not pick targets, queue interrupts, or move you.
* **Polled detection.** Casts / auras are polled at `Config.behavior.pollIntervalSec` (default 50 ms). A spell that finishes in < 50 ms can be missed; raise the poll rate if you care.
* **Anchor positions.** Beams and cones use the caster's `get_rotation()` heading. A handful of bosses don't expose rotation (rare). In that case the cone / beam will still draw, but pointed at heading 0 (east in WoW world space).
* **Not a DBM clone.** No timers, no boss bars, no soaks coordination, no raid-wide messages — just on-the-floor drawings. Pair with your DBM/BigWigs as usual.

## Safety

This plugin **does not call into IZI** or any other automation API. It only reads from `core.object_manager` and draws into `core.graphics`. There is no movement, no input simulation, no auction/trade interaction. It's a HUD.

That said: Blizzard's ToS prohibits unlockers in general. Use only in contexts where you accept that risk.

## Git workflow

For changes to this folder, prefer the same flow used by the rest of this repo (see `.cursorrules` / `CONTRIBUTING.md` at the repo root): land on `main` unless the maintainer explicitly requests a feature branch + PR.

## Links

* Project Sylvanas: <https://github.com/bluesilvi/project-sylvanas>
* Sylvanas dev docs: <https://docs.project-sylvanas.net/dev/>
