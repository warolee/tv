# ScienceAHBot

Auction House automation plugin for **Project Sylvanas** (Lua unlocker). It uses the **IZI SDK** for AH calls, **TradeSkillMaster** (`DBMarket`) for pricing, and a **custom overlay UI** (not the Project Sylvanas core menu). Everything runs on one runtime table named **`ScienceAHBot`** returned from `Config.lua`, so it does not scatter globals.

Official Sylvanas dev docs: [https://docs.project-sylvanas.net/dev/](https://docs.project-sylvanas.net/dev/)

## What it does

### Buy (default on)

- Walks your **Items** list from the overlay (**Items** tab). `Config.lua` ships with an **empty** `Items` table so you are not required to edit files for targets.
- For each item, asks IZI to search the AH and only considers **row 1** of the results (Retail **LIFO** alignment).
- Compares the listing price to a **maximum buy** derived from TSM: `DBMarket` times ratio (per-item ratio from the **Items** tab, or the default from **Setup**).
- If the deal is good enough, waits a **random thinking delay** (about 0.8 to 1.7 seconds), then places a bid via IZI (`ScienceAHBotBridge` in `AHBridge.lua`).

### Snipe (optional)

- Same LIFO row-1 logic, but with **faster scan pacing** and a **tighter** cap: it uses the **smaller** of the item ratio and `behavior.snipe.maxBuyRatio` (editable on **Setup**).

### Sell (optional)

- Uses TSM `DBMarket` with a vendor-style multiplier, optionally nudges price down if competitors are cheaper on row 1, then attempts to post via IZI (method names vary by build; the bridge tries several). Uses the main **Items** list when the sell watchlist is empty.

### Undercut / relist (optional)

- If IZI exposes owned-auction APIs, can cancel and relist when you are undercut. Optional aggressive fallback when those APIs are missing (`behavior.undercut` defaults in `Config.lua`; step size on **Setup** tab in-game).

### Behavioral layer (`Safety.lua` + `Timing.lua`)

- **Gaussian** delays for scan intervals (buy pacing adjustable on **Setup**; defaults in `Config.jitter` and per-module `behavior.*`).
- **Cognitive latency** before bids (800 to 1700 ms).
- **Coordinate jitter** helper for simulated clicks (plus or minus 5 px).
- **Whisper panic**: any incoming whisper **disarms** the bot, plays alarm sound **8959**, and bumps an internal epoch so pending delayed actions do not fire.
- **API throttle**: on auction database errors, enters a cool-down state (about 30 seconds).

### Fatigue (`Core.lua`)

- After a **random** active window (default about 45 to 60 minutes), forces an **idle** break for a **random** duration (default about 8 to 12 minutes), then resumes. Bounds are editable on **Setup**. Logs a short status line when the break starts.

### TSM intelligence (`TSM_Helper.lua`)

- **`GetMarketValue(itemID)`** reads TSM `DBMarket` for `i:<itemID>`, wrapped in `pcall`.
- Results are **cached for 300 seconds** per item id to avoid hammering TSM.
- **`GetThresholdMaxPrice`** combines market value with the effective buy ratio for scans.

### In-game UI (`UI.lua` + `UI_InGame.lua`)

- **Overlay** drawn with `core.graphics` (drag title bar, close button, tabs).
- **Items** tab: add/remove targets by **numeric item ID** (click the bar, type digits, Backspace). Set **ratio** for new adds and per row (minus/plus). **Merge starter** pulls a built-in herb/ore seed list; **Clear all** wipes the list.
- **Setup** tab: module toggles, **gold reserve**, **default buy ratio**, **snipe cap**, **sell stack size**, **buy scan mean and min/max clamp**, **fatigue work and rest windows**, **undercut copper**. All of this edits the live **`ScienceAHBot.Config`** in memory only (see limitations).
- **Dashboard** tab: live state, timers, gold vs reserve, lists, TSM/IZI probe info, scrollable detail.
- **Buy / Sell / Snipe / Undercut** tabs: quick module toggles plus short hints.
- Default **toggle visibility** key is **grave / backtick** (`0xC0`); change `behavior.ui.toggleKey` in `Config.lua` only if you need another key.

## Requirements

- **Project Sylvanas** with plugin loading enabled.
- Plugin folder **`ScienceAHBot`** with **`header.lua`** and **`main.lua`** (Sylvanas convention).
- **TradeSkillMaster** with a working `TSM_API` and `GetCustomPriceValue` (otherwise market values stay nil and the bot will mostly skip buys).
- **IZI SDK** (`common/izi_sdk`) with an AH table (`IZI.AH` or `IZI.ah`). Exact function names differ by build; `AHBridge.lua` tries several aliases.

## How to install

1. Copy the entire **`ScienceAHBot`** directory into your Sylvanas plugins folder.
2. Restart or reload plugins per Sylvanas instructions.
3. Confirm the client log shows something like: `[ScienceAHBot] Loaded (...)`.

## How to use

1. Open the overlay (default: **grave / backtick**). Go to **Items**: add IDs, tune ratios, optionally **Merge starter**.
2. Open **Setup** for reserves, pacing, fatigue, snipe cap, sell stack, undercut copper, and module toggles.
3. Use **Dashboard** to **Arm** / **Disarm** at the AH.
4. **Whisper panic** disarms on any incoming whisper.

**Persistence:** in-game edits apply immediately but are **not saved to disk** (no `SavedVariables` in this plugin). A `/reload` or client restart restores `Config.lua` defaults for `Items` and numeric settings unless you add your own persistence later.

## Important limitations

- This is **automation software**; Blizzard's ToS prohibit unattended / scripted gameplay. Use only in contexts where you accept the risk.
- IZI AH APIs are **not guaranteed** across Sylvanas builds; use the dashboard IZI function list and logs while testing.
- **No warranty**: wrong prices, failed posts, or API changes can lose gold or get you flagged. Test on low-value items first.

## File map

| File | Role |
|------|------|
| `header.lua` | Sylvanas plugin metadata |
| `main.lua` | Entry: wires TSM, Safety helpers, Core, UI, Safety events |
| `Config.lua` | Default `ScienceAHBot.Config` (empty `Items`; UI size; baseline numbers) |
| `Core.lua` | Update tick, fatigue, module orchestration |
| `TSM_Helper.lua` | Cached TSM `DBMarket`, ratios, watchlist ids |
| `AHBridge.lua` | `ScienceAHBotBridge` — pcall'd IZI AH calls with method fallbacks |
| `Timing.lua` | Gaussian scan delays (uses `GetGaussianDelay` on the runtime table) |
| `Safety.lua` | Whisper panic, API cool-down frame, jitter, cognitive delay, `schedule_after` |
| `ModBuy.lua` / `ModSnipe.lua` / `ModSell.lua` / `ModUndercut.lua` | Feature modules |
| `UI.lua` | Overlay shell, tabs, render, input routing |
| `UI_InGame.lua` | Items + Setup tab logic (mutates `ScienceAHBot.Config` in memory) |

## Links

- Project Sylvanas: [https://github.com/bluesilvi/project-sylvanas](https://github.com/bluesilvi/project-sylvanas)
- Dev documentation: [https://docs.project-sylvanas.net/dev/](https://docs.project-sylvanas.net/dev/)
