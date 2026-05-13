--[[ ScienceAHBot — canonical runtime projection (mirror of legacy root fields).

     Legacy fields (`isActive`, `BotActive`, `BotEnabled`, `ManualPause`, `state`,
     `_timerEpoch`, cooldown timers, etc.) remain authoritative for all engine logic.
     This table is refreshed once per tick for observability, UI, and debugging so
     there is a single structured view without migrating every caller yet. ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}

function ScienceAHBot.install(root)
  if not root or root._science_runtime_installed then
    return
  end
  root._science_runtime_installed = true
  root.runtime = root.runtime or {}
end

--- Refresh `root.runtime` from legacy flags (read-only aggregation).
---@param root table
---@param tnow number|nil
function ScienceAHBot.sync_from_legacy(root, tnow)
  if not root then
    return
  end
  root.runtime = root.runtime or {}
  local r = root.runtime
  local t = type(tnow) == "number" and tnow or 0
  r.t = t
  r.user_armed = root.isActive == true
  r.bot_active = root.BotActive == true
  r.bot_enabled = root.BotEnabled ~= false
  r.manual_pause = root.ManualPause == true
  r.epoch = root._timerEpoch or 0
  r.state = root.state
  r.api_cooldown_until = root.apiCooldownUntil or 0
  r.fatigue_until = root.fatigueUntil or 0
  r.search_backoff_until = root._searchFailBackoffUntil
  r.distraction_pause_until = root._distractionPauseAHUntil or 0
  r.tx_lock = root._ahTxLock or 0
  --- Composite "automation may scan" (informational; same gates as Core tick body).
  r.scans_allowed = r.user_armed
    and r.bot_active
    and r.bot_enabled
    and not r.manual_pause
    and (root.state == root.STATE_SCANNING)
  r.fatigue_phase = "normal"
  if root.state == root.STATE_COOLDOWN then
    r.fatigue_phase = "api_cooldown"
  elseif root.state == root.STATE_IDLE and t > 0 and (root.fatigueUntil or 0) > t then
    r.fatigue_phase = "fatigue_rest"
  end
end

return ScienceAHBot
