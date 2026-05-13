--[[ ScienceAHBot — behavioral science: Gaussian delays, cognitive latency, coordinate drift, whisper panic, deferred actions. ]]

local ScienceAHBot = {}

--- Box–Muller Gaussian (bell curve). Optional clamp to [clampLo, clampHi].
---@param mean number
---@param stdDev number
---@param clampLo number|nil
---@param clampHi number|nil
---@return number
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

--- Human "thinking" pause before acting (800–1700 ms).
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

--- Invalidate pending IZI.after callbacks tied to AH actions.
local function bump_timer_epoch(root)
  root._timerEpoch = (root._timerEpoch or 0) + 1
end

--- Schedule work after delay; aborted if panic increments _timerEpoch or bot disarmed.
---@param root table
---@param delay number
---@param fn function
function ScienceAHBot.schedule_after(root, delay, fn)
  if not root then
    return
  end
  local epoch = root._timerEpoch or 0
  local ok, izi = pcall(require, "common/izi_sdk")
  if ok and izi and izi.after then
    pcall(izi.after, delay, function()
      if (root._timerEpoch or 0) ~= epoch then
        return
      end
      if root.isActive == false or root.BotActive == false then
        return
      end
      pcall(fn)
    end)
  else
    pcall(fn)
  end
end

---@param root table
function ScienceAHBot.install(root)
  root = root or {}
  if root._science_safety_installed then
    return
  end
  root._science_safety_installed = true
  root._timerEpoch = root._timerEpoch or 0
  if root.BotActive == nil then
    root.BotActive = root.isActive ~= false
  end
  root._safetyFrames = root._safetyFrames or {}

  local function trigger_panic(reason)
    root.isActive = false
    root.BotActive = false
    root.state = root.STATE_IDLE
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
      if core and core.log_warning then
        core.log_warning("[ScienceAHBot] Panic stop: " .. tostring(reason))
      end
    end)
  end

  root.on_whisper_received = function()
    trigger_panic("CHAT_MSG_WHISPER")
  end

  root.begin_api_cooldown = function(seconds)
    local dur = seconds or 30
    pcall(function()
      local ok, IZI = pcall(require, "common/izi_sdk")
      if ok and IZI and IZI.now then
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
