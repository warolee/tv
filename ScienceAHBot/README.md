# ScienceAHBot

Auction House automation plugin for **Project Sylvanas** (Lua unlocker). It uses the **IZI SDK** for AH calls, **TradeSkillMaster** (`DBMarket`) for pricing, and a **custom overlay UI** (not the Project Sylvanas core menu). Everything runs on one runtime table named **`ScienceAHBot`** returned from `Config.lua`, so it does not scatter globals.

Official Sylvanas dev docs: [https://docs.project-sylvanas.net/dev/](https://docs.project-sylvanas.net/dev/)

## What it does

### Buy (default on)

- Walks your **Items** list from the overlay (**Items** tab). `Config.lua` ships with an **empty** `Items` table so you are not required to edit files for targets.
- For each item, asks IZI to search the AH and only considers **row 1** of the results (Retail **LIFO** alignment).
- Compares the listing price to a **maximum buy** derived from TSM: `DBMarket` times ratio (per-item ratio from the **Items** tab, or the default from **Setup**), optionally **blended** with a saved per-item **learned** typical row-1 price versus TSM (see Adaptive learning).
- If the deal is good enough, waits a **random thinking delay** (about 0.8 to 1.7 seconds), then places a bid via IZI (`ScienceAHBotBridge` in `AHBridge.lua`).

### Snipe (optional)

- Same LIFO row-1 logic, but with **faster scan pacing** and a **tighter** cap: it uses the **smaller** of the item ratio and `behavior.snipe.maxBuyRatio` (editable on **Setup**), then the same **adaptive blend** as Buy when learning is enabled.

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

### Persistence (`Persistence.lua`)

- Sylvanas **does not allow** plugins to write next to their own `.lua` files. Writable data must live under the loader’s **`scripts_data/`** tree ([File I/O docs](https://docs.project-sylvanas.net/dev/api/file-io)).
- This plugin saves **`scripts_data/ScienceAHBot/user_settings.lua`** (a Lua `return { ... }` snapshot of Items, watchlist, **learned `patterns`**, thresholds, jitter, fatigue bounds, and `behavior` including UI position). **CSV scan history** is a separate file when enabled (see Scan log).
- Loads that file at startup (after `Config.lua` defaults), then **debounced saves** (~0.85s after edits) when you use Items / Setup, module toggles, or move the overlay.

### Adaptive learning (`Learn.lua`)

- On each Buy or Snipe scan with a valid **TSM `DBMarket`** and a **row-1 price**, records the ratio **listing ÷ TSM** and maintains an **EWMA** per item id in **`Config.patterns`** (cross-referenced with the same TSM value used for the cap).
- After enough samples (**`behavior.learn.minSamples`**, default 5), the effective buy ratio becomes a **blend** of your configured ratio and `min(ratio, ewma + slack)`, so the bot can **tighten** toward what the AH has actually been showing versus TSM.
- **Setup** tab: toggle learning, adjust **blend**, **min samples**, **slack**, **EWMA alpha** (how fast new scans move the average), and **Reset learned patterns** (clears `patterns` only).
- **Dashboard** shows how many pattern slots exist and how many are “ready” (sample count ≥ minN). TSM’s own price cache remains in memory only (unchanged).

### Scan log (`ScanLog.lua`)

- Optional **CSV** append-only log: **`scripts_data/ScienceAHBot/scan_log.csv`** (not mixed into `user_settings.lua`).
- **Buy** and **Snipe** emit one row per scan tick (when armed and a module runs a search): timestamp (`core.time` / `GetTime`), item id, module name, TSM `DBMarket` copper, row-1 copper, **ratio** row1÷TSM, max buy cap, base and effective ratios, **action** (`bid_scheduled`, `skip_above_cap`, `skip_not_deal`, `dryrun_bid`, `no_tsm`, `no_results`, `no_row1`, `no_price`, `no_buy_cap`, `unknown`).
- Batched flush: **`flushEveryRows`** (default 8) or **`flushDebounceSec`** after the last row. Flushes also run from **Core** every frame (so disarming still drains the buffer) and when the **overlay closes**.
- If **`maxFileBytes`** is exceeded, the previous file body is copied to **`scan_log_prev.csv`** (overwrite), then the main file is restarted with a header plus the current batch only.
- **Setup** tab: toggle **Scan log CSV**. Default **off** in `Config.lua` to avoid surprise disk I/O.

### Preflight, AH guard, debug, and outcomes (`Preflight.lua`, `AHGuard.lua`, `AuctionOutcome.lua`)

- **Preflight** runs at load and is mirrored on the **Dashboard** so empty watchlists, missing `TSM_API`, or a missing IZI AH table are obvious before you rely on scans.
- **AH guard** (`behavior.ahGuard`): when **`requireAuctionFrame`** is true (default), **`SearchForItem` is skipped** unless `AuctionHouseFrame` or `AuctionFrame` looks open—this avoids spamming IZI while the AH window is closed. **`maxSearchFailStreak`** consecutive hard failures (missing API or `pcall` error) trigger a **`searchBackoffSeconds`** pause with one warning line. While backoff is active the bot still runs **`tick_lazy_queue_only`** so social-delay relists can complete without new searches.
- **Manual pause**: edge-toggle **`behavior.ui.manualPauseKey`** (default **F8**). Does not clear Items or trigger whisper panic; it skips AH module ticks and bumps the timer epoch so pending delayed bids/posts are dropped. Optional **8959** on pause: **`behavior.ui.manualPausePlaySound`**.
- **Debug** (`behavior.debug`): **`verbose`** adds per-tick **`core.log`** lines from modules; **`dryRun`** evaluates deals but **does not** call IZI bid/post/cancel (lazy undercut and aggressive post log “would” actions instead). **`logAuctionChat`** toggles **`CHAT_MSG_SYSTEM`** parsing for generic win/outbid/list strings (best-effort; locale and patch strings vary).
- **AuctionOutcome** logs hints next to **`_lastBidIntent`** when a bid or post was recently scheduled—useful for sanity checks, not a guaranteed receipt API.

### In-game UI (`UI.lua` + `UI_InGame.lua`)

- **Overlay** drawn with `core.graphics` (drag title bar, close button, tabs).
- **Items** tab: add/remove targets by **numeric item ID** (click the bar, type digits, Backspace). Set **ratio** for new adds and per row (minus/plus). **Merge starter** pulls a built-in herb/ore seed list; **Clear all** wipes the list.
- **Setup** tab: module toggles, **gold reserve**, **default buy ratio**, **snipe cap**, **sell stack size**, **buy scan mean and min/max clamp**, **fatigue work and rest windows**, **undercut copper**, **adaptive learn** controls, **AH search guard / debug toggles / fail streak & backoff**, and **scan log CSV** toggle. Values merge into **`ScienceAHBot.Config`** and are **saved to disk** (see Persistence) after a short debounce.
- **Dashboard** tab: live state, timers, gold vs reserve, lists, TSM/IZI probe info, scrollable detail.
- **Buy / Sell / Snipe / Undercut** tabs: quick module toggles plus short hints.
- Default **toggle visibility** key is **grave / backtick** (`0xC0`); default **manual pause** is **F8** (`0x77`). Change `behavior.ui.toggleKey` / `behavior.ui.manualPauseKey` in `Config.lua` if needed.

## Requirements

- **Project Sylvanas** with plugin loading enabled.
- Plugin folder **`ScienceAHBot`** with **`header.lua`** and **`main.lua`** (Sylvanas convention).
- **TradeSkillMaster** with a working `TSM_API` and `GetCustomPriceValue` (otherwise market values stay nil and the bot will mostly skip buys).
- **IZI SDK** (`common/izi_sdk`) with an AH table (`IZI.AH` or `IZI.ah`). Exact function names differ by build; `AHBridge.lua` tries several aliases.

## How to install

1. Copy the entire **`ScienceAHBot`** directory into your Sylvanas plugins folder.
2. Restart or reload plugins per Sylvanas instructions.
3. Confirm the client log shows something like: `[ScienceAHBot] Loaded (...)`.

### If the loader says `ScienceAHBot\ScienceAHBot\Config.lua` is not found

Sylvanas resolves `require()` for a plugin **from that plugin's folder** (e.g. `scripts/ScienceAHBot/`). Paths like `require("ScienceAHBot/Config")` make the loader look inside a **nested** folder and fail. This repo uses **`require("Config")`**, **`require("Safety")`**, etc., for modules that live **next to** `main.lua`.

## How to use

1. Open the overlay (default: **grave / backtick**). Go to **Items**: add IDs, tune ratios, optionally **Merge starter**.
2. Open **Setup** for reserves, pacing, fatigue, snipe cap, sell stack, undercut copper, **adaptive learn** tuning, and module toggles.
3. Use **Dashboard** to **Arm** / **Disarm** at the AH.
4. **Whisper panic** disarms on any incoming whisper.

**Persistence:** Items, **learned patterns**, Setup, module toggles, and overlay position are written to **`scripts_data/ScienceAHBot/user_settings.lua`** after you stop clicking for about a second, and reloaded on next inject. You cannot save inside the WoW folder or next to plugin sources; that is a Sylvanas sandbox rule. Do not paste untrusted Lua into `user_settings.lua`.

## Important limitations

- This is **automation software**; Blizzard's ToS prohibit unattended / scripted gameplay. Use only in contexts where you accept the risk.
- IZI AH APIs are **not guaranteed** across Sylvanas builds; use the dashboard IZI function list and logs while testing.
- **Undercut cancel-without-repost gap (by design).** When the lazy queue fires it cancels your existing auction *synchronously* and then schedules the repost for `relistDelaySeconds` later (default ~0.85 s). If **whisper panic** fires or you toggle **manual pause** in that window, the epoch bump aborts the deferred repost — your auction is canceled but **not** relisted. The item returns to your mailbox so no gold is lost, but the listing is gone until you re-arm and ModUndercut picks it up again on the next pass. This is the correct safety behavior (don't auto-repost during a GM interaction), but worth knowing.
- **No warranty**: wrong prices, failed posts, or API changes can lose gold or get you flagged. Test on low-value items first.

## File map

| File | Role |
|------|------|
| `header.lua` | Sylvanas plugin metadata |
| `main.lua` | Entry: wires TSM, Safety helpers, Core, UI, chat outcome listener, preflight log |
| `Config.lua` | Default `ScienceAHBot.Config` (empty `Items`; UI size; baseline numbers) |
| `Core.lua` | Update tick, fatigue, manual pause / backoff gates, module orchestration |
| `TSM_Helper.lua` | Cached TSM `DBMarket`, ratios, watchlist ids |
| `AHBridge.lua` | `ScienceAHBotBridge` — pcall'd IZI AH calls; search metrics hook |
| `AHGuard.lua` | AH frame probe, manual pause key edge, search-failure backoff |
| `Preflight.lua` | Collect config warnings for load + dashboard |
| `AuctionOutcome.lua` | `CHAT_MSG_SYSTEM` hints + `_lastBidIntent` correlation |
| `Timing.lua` | Gaussian scan delays (uses `GetGaussianDelay` on the runtime table) |
| `Safety.lua` | Whisper panic, API cool-down frame, jitter, cognitive delay, `schedule_after` |
| `Learn.lua` | Per-item EWMA of AH row1 ÷ TSM; blends into Buy/Snipe caps; reset helper |
| `ScanLog.lua` | Optional CSV `scan_log.csv`: scan rows, batched flush, size rotation |
| `ModBuy.lua` / `ModSnipe.lua` / `ModSell.lua` / `ModUndercut.lua` | Feature modules |
| `UI.lua` | Overlay shell, tabs, render, input routing |
| `UI_InGame.lua` | Items + Setup tab hit-tests and labels |
| `Persistence.lua` | Load/save `user_settings.lua` under `scripts_data/ScienceAHBot/` |
| `Runtime.lua` | Canonical `root.runtime` snapshot (mirrors legacy flags each tick) |
| `Util.lua` | `safe_call` fault boundaries + throttled error logging |

## Git workflow (always merge on GitHub)

For this repo, **land changes on `main` only through a merged pull request** so GitHub keeps a proper merge record, PRs auto-close, and history stays tied to reviewable diffs.

1. Push a feature branch (for example `cursor/<topic>-c8f0`).
2. Open a PR into **`main`**.
3. Merge using GitHub’s **Merge pull request** (prefer **Create a merge commit** if you want a merge node on `main`), or from a machine with the GitHub CLI:

   `gh pr merge <PR_NUMBER> --merge --delete-branch`

4. Avoid **only** pushing fast-forwards to `origin/main` from your laptop without merging the PR, or the PR can stay open while `main` already contains the commits—then you have to close or reconcile manually.

Automation (branch protection, required reviews, auto-merge) is configured in the GitHub repository **Settings**; this section documents the intended human/agent workflow.

## Links

- Project Sylvanas: [https://github.com/bluesilvi/project-sylvanas](https://github.com/bluesilvi/project-sylvanas)
- Dev documentation: [https://docs.project-sylvanas.net/dev/](https://docs.project-sylvanas.net/dev/)
