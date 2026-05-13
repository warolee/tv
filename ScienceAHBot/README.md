# ScienceAHBot

Auction House automation plugin for **Project Sylvanas** (Lua unlocker). It uses the **IZI SDK** for AH calls, **TradeSkillMaster** (`DBMarket`) for pricing, and a **custom overlay UI** (not the Project Sylvanas core menu). Everything runs on one runtime table named **`ScienceAHBot`** returned from `Config.lua`, so it does not scatter globals.

Official Sylvanas dev docs: [https://docs.project-sylvanas.net/dev/](https://docs.project-sylvanas.net/dev/)

## What it does

### Buy (default on)

- Walks your configured item list (see **Configuration** below).
- For each item, asks IZI to search the AH and only considers **row 1** of the results (Retail **LIFO** alignment).
- Compares the listing price to a **maximum buy** derived from TSM: `DBMarket × ratio` (per-item ratio from `Config.Items`, or fallbacks).
- If the deal is good enough, waits a **random “thinking” delay** (about 0.8–1.7 seconds), then places a bid via IZI (`ScienceAHBotBridge` in `AHBridge.lua`).

### Snipe (optional)

- Same LIFO row-1 logic, but with **faster scan pacing** and a **tighter** cap: it uses the **smaller** of the item’s configured ratio and `behavior.snipe.maxBuyRatio`.

### Sell (optional)

- Uses TSM `DBMarket` with a vendor-style multiplier, optionally nudges price down if competitors are cheaper on row 1, then attempts to post via IZI (method names vary by build; the bridge tries several).

### Undercut / relist (optional)

- If IZI exposes owned-auction APIs, can cancel and relist when you are undercut. Has an optional aggressive fallback when those APIs are missing (see `behavior.undercut` in `Config.lua`).

### Behavioral layer (`Safety.lua` + `Timing.lua`)

- **Gaussian** delays for scan intervals (mean/std/min/max in `Config.jitter` and per-module `behavior.*` scan settings).
- **Cognitive latency** before bids (800–1700 ms).
- **Coordinate jitter** helper for simulated clicks (±5 px).
- **Whisper panic**: any incoming whisper **disarms** the bot, plays alarm sound **8959**, and bumps an internal epoch so pending delayed actions do not fire.
- **API throttle**: on auction database errors, enters a cool-down state (about 30 seconds).

### Fatigue (`Core.lua`)

- After a **random** active window (default about 45–60 minutes), forces an **idle** break for a **random** duration (default about 8–12 minutes), then resumes. Logs a short status line when the break starts.

### TSM intelligence (`TSM_Helper.lua`)

- **`GetMarketValue(itemID)`** reads TSM `DBMarket` for `i:<itemID>`, wrapped in `pcall`.
- Results are **cached for 300 seconds** per item id to avoid hammering TSM.
- **`GetThresholdMaxPrice`** combines market value with the effective buy ratio for scans.

### In-game UI (`UI.lua`)

- **Overlay** drawn with `core.graphics` (drag title bar, close button, tabs).
- **Dashboard** tab: live state, timers, gold vs reserve, lists, TSM/IZI probe info, scrollable detail.
- Other tabs: toggles for **Buy / Sell / Snipe / Undercut** and high-level **Behavior** settings.
- Default **toggle visibility** key is the **grave / backtick** key (`0xC0`); change `behavior.ui.toggleKey` in `Config.lua` if needed.

## Requirements

- **Project Sylvanas** with plugin loading enabled.
- Plugin layout: this folder **`ScienceAHBot`** with **`header.lua`** and **`main.lua`** (Sylvanas convention).
- **TradeSkillMaster** with a working `TSM_API` and `GetCustomPriceValue` (otherwise market values stay nil and the bot will mostly skip buys).
- **IZI SDK** (`common/izi_sdk`) with an AH table (`IZI.AH` or `IZI.ah`). Exact function names differ by build; `AHBridge.lua` tries several aliases.

## How to install

1. Copy the entire **`ScienceAHBot`** directory into your Sylvanas plugins folder (same place your other `header.lua` / `main.lua` plugins live).
2. Restart or reload plugins per Sylvanas instructions.
3. Confirm the client log shows something like: `[ScienceAHBot] Loaded (...)`.

## How to use

1. **Edit `Config.lua`** (or fork values in a local override if your workflow supports that):
   - Set **`Config.Items`** with the item IDs you care about, each `{ ratio = 0.0–1.0, name = "Label" }`. The scan list is the **set of keys** in `Items` when that table is non-empty.
   - Optionally set global **`buyRatio`** or **`thresholds.defaultBuyRatio`** when you do not want a per-item ratio.
   - Tune **`jitter`** and **`behavior.*`** scan means/clamps for how aggressive pacing feels.
   - Set **`behavior.reserves.minGoldCopper`** so the bot backs off when you are low on gold.
2. **Open the overlay** (default: backtick). Use the **Dashboard** tab to **Arm** the bot when you are at the AH with the window usable.
3. Enable or disable **modules** in the UI tabs (Buy / Sell / Snipe / Undercut) or in **`Config.behavior.modules`** before arming.
4. **Disarm** from the same button, or trigger whisper panic by receiving any whisper (intentional safety stop).
5. Watch the **Dashboard** for TSM availability, IZI AH function names, and timer state while testing.

## Important limitations

- This is **automation software**; Blizzard’s ToS prohibit unattended / scripted gameplay. Use only in contexts where you accept the risk.
- IZI AH APIs are **not guaranteed** across Sylvanas builds; use the dashboard’s IZI function list and in-game logs to see what your build exposes.
- **No warranty**: wrong prices, failed posts, or API changes can lose gold or get you flagged. Test on low-value items first.

## File map

| File | Role |
|------|------|
| `header.lua` | Sylvanas plugin metadata |
| `main.lua` | Entry: wires TSM, Safety helpers, Core, UI, Safety events |
| `Config.lua` | `ScienceAHBot.Config` — items, ratios, jitter, fatigue, behavior, UI defaults |
| `Core.lua` | Update tick, fatigue, module orchestration |
| `TSM_Helper.lua` | Cached TSM `DBMarket`, ratios, watchlist ids |
| `AHBridge.lua` | `ScienceAHBotBridge` — pcall’d IZI AH calls with method fallbacks |
| `Timing.lua` | Gaussian scan delays (uses `GetGaussianDelay` on the runtime table) |
| `Safety.lua` | Whisper panic, API cool-down frame, jitter, cognitive delay, `schedule_after` |
| `ModBuy.lua` / `ModSnipe.lua` / `ModSell.lua` / `ModUndercut.lua` | Feature modules |
| `UI.lua` | Overlay + dashboard |

## Links

- Project Sylvanas: [https://github.com/bluesilvi/project-sylvanas](https://github.com/bluesilvi/project-sylvanas)
- Dev documentation: [https://docs.project-sylvanas.net/dev/](https://docs.project-sylvanas.net/dev/)
