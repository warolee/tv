--[[ ScienceAHBot — behavioral science: distraction layer, Gaussian delays, cognitive latency,
     coordinate drift, whisper panic, AH transaction locks, deferred actions. ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}

local IZI = (function()
  local ok, mod = pcall(require, "common/izi_sdk")
  return ok and mod or nil
end)()

local Util = require("Util")

local function now_s()
  if IZI and IZI.now then
    local o2, t = pcall(IZI.now)
    if o2 and type(t) == "number" then
      return t
    end
  end
  if GetTime then
    return GetTime()
  end
  return 0
end

--- AH purchase/post in flight — distraction must not interrupt.
function ScienceAHBot.transaction_lock_add(root)
  if not root then
    return
  end
  root._ahTxLock = (root._ahTxLock or 0) + 1
end

function ScienceAHBot.transaction_lock_release(root)
  if not root then
    return
  end
  root._ahTxLock = math.max(0, (root._ahTxLock or 0) - 1)
end

function ScienceAHBot.is_transaction_locked(root)
  return root and (root._ahTxLock or 0) > 0
end

--- Box–Muller Gaussian (bell curve). Optional clamp to [clampLo, clampHi].
function ScienceAHBot.GetGaussianDelay(mean, stdDev, clampLo, clampHi)
  mean = mean or 1.0
  stdDev = stdDev or 0.2
  local u1 = math.max(math.random(), 1e-12)
  local u2 = math.random()
  local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
  local v = mean + z0 * stdDev
  if type(clampLo) == "number" and v < clampLo then
    v = clampLo
  end
  if type(clampHi) == "number" and v > clampHi then
    v = clampHi
  end
  return v
end

--- Human "thinking" pause before buy/post (800–1700 ms).
---@return number seconds
function ScienceAHBot.GetCognitiveLatency()
  local lo, hi = 800, 1700
  local ms
  local ok = pcall(function()
    ms = math.random(lo, hi)
  end)
  if not ok or type(ms) ~= "number" then
    ms = math.floor(lo + math.random() * (hi - lo + 1))
  end
  return ms / 1000.0
end

--- Simulated click coordinate drift (±5 px).
---@param centerX number
---@param centerY number
---@return number, number
function ScienceAHBot.jitter_button_center(centerX, centerY)
  local ox, oy
  pcall(function()
    ox = math.random(-5, 5)
    oy = math.random(-5, 5)
  end)
  if type(ox) ~= "number" then
    ox = math.floor((math.random() * 11) - 5)
  end
  if type(oy) ~= "number" then
    oy = math.floor((math.random() * 11) - 5)
  end
  return centerX + ox, centerY + oy
end

local function bump_timer_epoch(root)
  root._timerEpoch = (root._timerEpoch or 0) + 1
end

local function schedule_after_log_verbose(root, line)
  local cfg = root and root.Config
  local dbg = cfg and cfg.behavior and cfg.behavior.debug
  if type(dbg) ~= "table" or dbg.verbose ~= true then
    return
  end
  pcall(function()
    if core and core.log then
      core.log(line)
    end
  end)
end

--- Optional throttled diagnostics for deferred scheduling (verbose OR scheduleDiag).
local function schedule_after_log_diag(root, line)
  local dbg = root and root.Config and root.Config.behavior and root.Config.behavior.debug
  if type(dbg) ~= "table" then
    return
  end
  if dbg.verbose ~= true and dbg.scheduleDiag ~= true then
    return
  end
  local gap = 1.5
  if type(dbg.scheduleDiagMinIntervalSec) == "number" and dbg.scheduleDiagMinIntervalSec > 0 then
    gap = dbg.scheduleDiagMinIntervalSec
  end
  local t = now_s()
  root._scienceSchedDiagNext = root._scienceSchedDiagNext or 0
  if t < root._scienceSchedDiagNext then
    return
  end
  root._scienceSchedDiagNext = t + gap
  pcall(function()
    if core and core.log then
      core.log(line)
    end
  end)
end

--- When `IZI.after` is unavailable, queue callbacks for a later tick (never synchronous with the caller).
local function queue_deferred_after(root, delay, epoch, kind, run)
  if not root or type(run) ~= "function" then
    return
  end
  root._scienceDeferredIziQueue = root._scienceDeferredIziQueue or {}
  local t = now_s()
  local d = type(delay) == "number" and delay or 0
  if d < 0 then
    d = 0
  end
  --- Minimum slip past the scheduling frame so work is not collapsed into the same stack as the caller.
  local runAt = t + math.max(d, 0.02)
  root._scienceDeferredIziQueue[#root._scienceDeferredIziQueue + 1] = {
    runAt = runAt,
    epoch = epoch,
    kind = kind or "?",
    run = run,
  }
  schedule_after_log_diag(
    root,
    string.format(
      "[ScienceAHBot][deferred_queue] enqueued kind=%s delay=%.3fs epoch=%s runAt=%.3f (no IZI.after)",
      tostring(kind),
      d,
      tostring(epoch),
      runAt
    )
  )
end

--- Drain fallback `IZI.after` queue (call once per engine tick from `Core`).
function ScienceAHBot.flush_deferred_after_queue(root, tnow)
  if not root then
    return
  end
  local q = root._scienceDeferredIziQueue
  if type(q) ~= "table" or #q == 0 then
    return
  end
  local t = type(tnow) == "number" and tnow or now_s()
  local i = 1
  while i <= #q do
    local e = q[i]
    if type(e) == "table" and type(e.runAt) == "number" and t >= e.runAt then
      if (root._timerEpoch or 0) == (e.epoch or 0) then
        schedule_after_log_diag(
          root,
          string.format("[ScienceAHBot][deferred_queue] dispatch kind=%s epoch=%s", tostring(e.kind), tostring(e.epoch))
        )
        Util.safe_call(
          string.format("Safety.deferred_queue.%s", tostring(e.kind)),
          function()
            e.run()
          end,
          { root = root, tnow = t }
        )
      else
        schedule_after_log_diag(
          root,
          string.format(
            "[ScienceAHBot][deferred_queue] dropped kind=%s (epoch wanted %s got %s)",
            tostring(e.kind),
            tostring(e.epoch),
            tostring(root._timerEpoch or 0)
          )
        )
      end
      table.remove(q, i)
    else
      i = i + 1
    end
  end
end

--- Schedule AH work after delay; aborted if panic increments _timerEpoch or bot disarmed.
--- If the deferred callback is skipped (epoch mismatch or bot off), `onAbort` runs so callers can release locks.
---@param onAbort function|nil
function ScienceAHBot.schedule_after(root, delay, fn, onAbort)
  if not root then
    return
  end
  local epoch = root._timerEpoch or 0
  local function skip_or_run()
    if (root._timerEpoch or 0) ~= epoch then
      if onAbort then
        Util.safe_call("Safety.schedule_after.onAbort", onAbort, { root = root, tnow = now_s() })
      end
      schedule_after_log_verbose(
        root,
        string.format(
          "[ScienceAHBot][schedule_after] cancelled: epoch mismatch (expected %s got %s)",
          tostring(epoch),
          tostring(root._timerEpoch or 0)
        )
      )
      return
    end
    if root.ManualPause == true then
      if onAbort then
        Util.safe_call("Safety.schedule_after.onAbort", onAbort, { root = root, tnow = now_s() })
      end
      schedule_after_log_verbose(root, "[ScienceAHBot][schedule_after] cancelled: manual pause")
      return
    end
    if root.isActive == false or root.BotActive == false or root.BotEnabled == false then
      if onAbort then
        Util.safe_call("Safety.schedule_after.onAbort", onAbort, { root = root, tnow = now_s() })
      end
      schedule_after_log_verbose(root, "[ScienceAHBot][schedule_after] cancelled: bot disarmed")
      return
    end
    Util.safe_call("Safety.schedule_after.callback", function()
      fn()
    end, { root = root, tnow = now_s() })
  end
  if IZI and IZI.after then
    schedule_after_log_verbose(
      root,
      string.format("[ScienceAHBot][schedule_after] queued: delay=%ss epoch=%s", tostring(delay), tostring(epoch))
    )
    pcall(IZI.after, delay, skip_or_run)
  else
    schedule_after_log_diag(
      root,
      string.format("[ScienceAHBot][schedule_after] fallback queue (no IZI.after) delay=%ss epoch=%s", tostring(delay), tostring(epoch))
    )
    queue_deferred_after(root, delay, epoch, "schedule_after", skip_or_run)
  end
end

--- IZI.after without BotActive guard (UI-only distraction). Still respects panic epoch.
---@param root table
---@param delay number
---@param fn function
function ScienceAHBot.schedule_ui_after(root, delay, fn)
  if not root then
    return
  end
  local epoch = root._timerEpoch or 0
  local function wrapped()
    if (root._timerEpoch or 0) ~= epoch then
      schedule_after_log_verbose(
        root,
        string.format(
          "[ScienceAHBot][schedule_ui_after] cancelled: epoch mismatch (expected %s got %s)",
          tostring(epoch),
          tostring(root._timerEpoch or 0)
        )
      )
      return
    end
    Util.safe_call("Safety.schedule_ui_after.callback", function()
      fn()
    end, { root = root, tnow = now_s() })
  end
  if IZI and IZI.after then
    pcall(IZI.after, delay, wrapped)
  else
    queue_deferred_after(root, delay, epoch, "schedule_ui_after", wrapped)
  end
end

local function distraction_finish(root)
  root._distractionBusy = false
  root._distractionPauseAHUntil = 0
  root._distractionExtra = nil
  local t = now_s()
  --- Next trigger: 15 min ± 3 min (12–18 minutes).
  root._distractionNextAt = t + (15 * 60) + math.random(-3 * 60, 3 * 60)
end

local function distraction_chain(root, step, epoch, dcfg)
  if not root then
    return
  end
  if (root._timerEpoch or 0) ~= epoch then
    distraction_finish(root)
    return
  end

  if step == 1 then
    root._distractionPauseAHUntil = now_s() + 45
    pcall(function()
      if ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
      end
    end)
    local wait = 2.5 + math.random() * (4.2 - 2.5)
    ScienceAHBot.schedule_ui_after(root, wait, function()
      distraction_chain(root, 2, epoch, dcfg)
    end)
    return
  end

  if step == 2 then
    pcall(function()
      if ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
      end
    end)
    if math.random() < (dcfg.extraOpenChance or 0.30) then
      ScienceAHBot.schedule_ui_after(root, 0.35 + math.random() * 0.45, function()
        distraction_chain(root, 3, epoch, dcfg)
      end)
    else
      distraction_finish(root)
    end
    return
  end

  if step == 3 then
    root._distractionExtra = nil
    pcall(function()
      if math.random() < 0.5 and ToggleBackpack then
        ToggleBackpack()
        root._distractionExtra = "bag"
      else
        local book = rawget(_G, "BOOKTYPE_PROFESSION")
        if ToggleSpellBook and book then
          ToggleSpellBook(book)
          root._distractionExtra = "spell"
        elseif ToggleBackpack then
          ToggleBackpack()
          root._distractionExtra = "bag"
        end
      end
    end)
    local dwell = 1.0 + math.random() * 0.8
    ScienceAHBot.schedule_ui_after(root, dwell, function()
      distraction_chain(root, 4, epoch, dcfg)
    end)
    return
  end

  if step == 4 then
    pcall(function()
      if root._distractionExtra == "bag" and ToggleBackpack then
        ToggleBackpack()
      elseif root._distractionExtra == "spell" and ToggleSpellBook then
        local book = rawget(_G, "BOOKTYPE_PROFESSION")
        if book then
          ToggleSpellBook(book)
        end
      end
    end)
    distraction_finish(root)
  end
end

--- Periodic "junk UI" to break AH-only telemetry. Skips if AH transaction lock is held.
---@param root table
---@param tnow number
function ScienceAHBot.tick_distraction(root, tnow)
  if not root or root.isActive ~= true then
    return
  end
  local cfg = root.Config
  if type(cfg) ~= "table" then
    return
  end
  local d = (cfg.behavior and cfg.behavior.distraction) or {}
  if d.enabled == false then
    return
  end
  if root._distractionBusy then
    return
  end
  if ScienceAHBot.is_transaction_locked(root) then
    root._distractionNextAt = math.max(root._distractionNextAt or tnow, tnow) + 30
    return
  end
  if root._distractionNextAt == nil then
    root._distractionNextAt = tnow + math.random(600, 1200)
  end
  if tnow < (root._distractionNextAt or 0) then
    return
  end

  root._distractionBusy = true
  root._distractionPauseAHUntil = tnow + 50
  local epoch = root._timerEpoch or 0
  pcall(function()
    if core and core.log then
      core.log("[ScienceAHBot] Distraction layer: brief UI break (AH paused).")
    end
  end)
  distraction_chain(root, 1, epoch, d)
end

function ScienceAHBot.install(root)
  root = root or {}
  if root._science_safety_installed then
    return
  end
  root._science_safety_installed = true
  root._timerEpoch = root._timerEpoch or 0
  --[[ Three-flag runtime control:
       isActive: user toggle (UI arm/disarm button)
       BotActive: runtime scanning state (cleared by fatigue,
         cooldown, panic)
       BotEnabled: panic/timer kill switch (cleared by whisper
         panic and epoch invalidation; checked by schedule_after
         before executing deferred callbacks)
       ManualPause: hotkey pause (AHGuard); does not flip isActive; bumps _timerEpoch when pausing on.
       root.state: SCANNING / IDLE (fatigue) / COOLDOWN (AH API errors).
       _timerEpoch: invalidates pending IZI.after + fallback queue rows on panic / manual pause. ]]
  if root.BotActive == nil then
    root.BotActive = root.isActive ~= false
  end
  if root.BotEnabled == nil then
    root.BotEnabled = root.BotActive ~= false
  end
  root._safetyFrames = root._safetyFrames or {}
  root._ahTxLock = root._ahTxLock or 0

  local function trigger_panic(reason)
    root.isActive = false
    root.BotActive = false
    root.BotEnabled = false
    root.state = root.STATE_IDLE
    root._distractionBusy = false
    root._distractionPauseAHUntil = 0
    root._scienceDeferredIziQueue = nil
    bump_timer_epoch(root)
    pcall(function()
      PlaySound(8959)
    end)
    pcall(function()
      if core and core.play_sound_by_id then
        core.play_sound_by_id(8959)
      end
    end)
    pcall(function()
      print("|cffff4444ScienceAHBot|r GM/Player Interaction Detected. Automation stopped. (Whisper panic)")
    end)
    pcall(function()
      if core and core.log_warning then
        core.log_warning("[ScienceAHBot] GM/Player Interaction Detected — " .. tostring(reason))
      end
    end)
  end

  root.on_whisper_received = function()
    trigger_panic("CHAT_MSG_WHISPER")
  end

  root.begin_api_cooldown = function(seconds)
    local dur = seconds or 30
    pcall(function()
      if IZI and IZI.now then
        local ok2, until_t = pcall(IZI.now)
        if ok2 and type(until_t) == "number" then
          root.apiCooldownUntil = until_t + dur
        end
      end
    end)
    if not root.apiCooldownUntil then
      root.apiCooldownUntil = (GetTime and (GetTime() + dur)) or 0
    end
    root.state = root.STATE_COOLDOWN
    pcall(function()
      if core and core.log_warning then
        core.log_warning("[ScienceAHBot] AH API cool-down (" .. tostring(dur) .. "s)")
      end
    end)
  end

  local function on_ui_error(_, message)
    if type(message) ~= "string" then
      return
    end
    local err_const = rawget(_G, "ERR_AUCTION_DATABASE_ERROR")
    if err_const and message == err_const then
      root.begin_api_cooldown(30)
      return
    end
    if message:find("AUCTION_DATABASE", 1, true) or message:find("ERR_AUCTION_DATABASE_ERROR", 1, true) then
      root.begin_api_cooldown(30)
    end
  end

  local function on_whisper()
    trigger_panic("whisper")
  end

  pcall(function()
    local parent = rawget(_G, "UIParent")
    local f = CreateFrame("Frame", "ScienceAHBotSafetyFrame", parent)
    f:RegisterEvent("CHAT_MSG_WHISPER")
    f:RegisterEvent("UI_ERROR_MESSAGE")
    f:SetScript("OnEvent", function(_, event, arg1)
      if event == "CHAT_MSG_WHISPER" then
        on_whisper()
      elseif event == "UI_ERROR_MESSAGE" then
        on_ui_error(event, arg1)
      end
    end)
    table.insert(root._safetyFrames, f)
  end)
end

return ScienceAHBot
