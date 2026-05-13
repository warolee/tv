--[[
  ScienceAHBot — anti-detection helpers, whisper panic, AH API throttling.
]]

local AH_Bot = {}

--- Returns click coordinates jittered ±5 px from a UI button center.
---@param centerX number
---@param centerY number
---@return number, number
function AH_Bot.jitter_button_center(centerX, centerY)
  local ox = (math.random() * 10.0) - 5.0
  local oy = (math.random() * 10.0) - 5.0
  return centerX + ox, centerY + oy
end

--- Wire whisper panic + auction database error cool-down into the shared runtime root.
---@param root table
function AH_Bot.install(root)
  root = root or {}
  if root._science_safety_installed then
    return
  end
  root._science_safety_installed = true

  root._safetyFrames = root._safetyFrames or {}

  local function trigger_panic(reason)
    root.isActive = false
    root.state = root.STATE_IDLE
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

return AH_Bot
