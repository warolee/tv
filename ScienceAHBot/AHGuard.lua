--[[ ScienceAHBot — AH UI detection, manual pause hotkey, search-failure backoff. ]]

local ScienceAHBot = {}

local function guard_cfg(root)
  local cfg = root and root.Config
  if type(cfg) ~= "table" then
    return {}
  end
  return (cfg.behavior and cfg.behavior.ahGuard) or {}
end

function ScienceAHBot.is_auction_ui_open()
  local open = false
  pcall(function()
    local f = rawget(_G, "AuctionHouseFrame")
    if f and f.IsShown and f:IsShown() then
      open = true
    end
  end)
  if open then
    return true
  end
  pcall(function()
    local f = rawget(_G, "AuctionFrame")
    if f and f.IsShown and f:IsShown() then
      open = true
    end
  end)
  return open
end

--- When true, modules skip `SearchForItem` if the AH window is not visible.
function ScienceAHBot.search_guard_enabled(root)
  return guard_cfg(root).requireAuctionFrame ~= false
end

function ScienceAHBot.skip_search_because_ui_closed(root)
  if not ScienceAHBot.search_guard_enabled(root) then
    return false
  end
  return not ScienceAHBot.is_auction_ui_open()
end

function ScienceAHBot.is_manual_paused(root)
  return root and root.ManualPause == true
end

function ScienceAHBot.is_search_backoff(root, tnow)
  local until_t = root and root._searchFailBackoffUntil
  if type(until_t) ~= "number" or type(tnow) ~= "number" then
    return false
  end
  return tnow < until_t
end

--- Count only hard failures (missing API or pcall error), not empty results.
---@param root table
---@param tnow number
---@param status "ok"|"no_method"|"pcall_fail"
function ScienceAHBot.record_search_attempt(root, tnow, status)
  if not root or type(tnow) ~= "number" then
    return
  end
  local g = guard_cfg(root)
  local maxN = g.maxSearchFailStreak or 5
  local backoffSec = g.searchBackoffSeconds or 30
  if status == "ok" then
    root._searchFailStreak = 0
    return
  end
  if status ~= "no_method" and status ~= "pcall_fail" then
    return
  end
  root._searchFailStreak = (root._searchFailStreak or 0) + 1
  if root._searchFailStreak >= maxN then
    root._searchFailStreak = 0
    root._searchFailBackoffUntil = tnow + backoffSec
    pcall(function()
      if core and core.log_warning then
        core.log_warning(
          string.format(
            "[ScienceAHBot] AH search failed %d times; backing off %.0fs (IZI / AH window).",
            maxN,
            backoffSec
          )
        )
      end
    end)
  end
end

--- Edge-detect manual pause key (default F8). Does not change `isActive` or config.
function ScienceAHBot.tick_manual_pause_key(root)
  if not root or type(root.Config) ~= "table" then
    return
  end
  local ui = (root.Config.behavior and root.Config.behavior.ui) or {}
  local vk = ui.manualPauseKey or 0x77
  local down = false
  pcall(function()
    down = core.input.is_key_pressed(vk)
  end)
  local prev = root._manualPauseKeyDown
  root._manualPauseKeyDown = down and true or false
  local edge = down and not prev
  if not edge then
    return
  end
  root.ManualPause = not root.ManualPause
  pcall(function()
    if core and core.log then
      core.log("[ScienceAHBot] Manual pause: " .. (root.ManualPause and "ON (AH ticks skipped)" or "OFF"))
    end
  end)
  if ui.manualPausePlaySound and root.ManualPause then
    pcall(function()
      PlaySound(8959)
    end)
    pcall(function()
      if core and core.play_sound_by_id then
        core.play_sound_by_id(8959)
      end
    end)
  end
  if root.ManualPause then
    root._timerEpoch = (root._timerEpoch or 0) + 1
  end
end

return ScienceAHBot
