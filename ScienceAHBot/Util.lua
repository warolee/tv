local Util = {}

local function now_ts()
  if GetTime then
    local ok, t = pcall(GetTime)
    if ok and type(t) == "number" then
      return t
    end
  end
  return 0
end

local function throttle_interval_sec(root)
  local dbg = root and root.Config and root.Config.behavior and root.Config.behavior.debug
  if type(dbg) == "table" and type(dbg.errorLogThrottleSec) == "number" and dbg.errorLogThrottleSec > 0 then
    return dbg.errorLogThrottleSec
  end
  return 2.0
end

--- Structured fault boundary: logs `[ScienceAHBot][Label] summary` plus traceback on failure.
---@param label string e.g. `ModBuy.ScanCycle`
---@param fn function
---@param opts table|nil `{ root = root, tnow = number }` — enables per-label throttling on `root`
function Util.safe_call(label, fn, opts)
  opts = opts or {}
  local ok, err = pcall(fn)
  if ok then
    return true
  end
  local summary = tostring(err)
  local trace = ""
  pcall(function()
    trace = debug.traceback(summary, 2) or ""
  end)
  local root = opts.root
  local gap = throttle_interval_sec(root)
  if root and type(label) == "string" and gap > 0 then
    root._scienceErrLog = root._scienceErrLog or {}
    local now = now_ts()
    local last = root._scienceErrLog[label] or 0
    --- Only throttle once we have actually logged this label before
    --- (`last > 0`); first occurrence always logs even on small clocks.
    if now > 0 and last > 0 and (now - last) < gap then
      return false
    end
    root._scienceErrLog[label] = now
  end
  local ts = opts.tnow
  if type(ts) ~= "number" or ts <= 0 then
    ts = now_ts()
  end
  local head = string.format("[ScienceAHBot][%s]", tostring(label))
  if ts and ts > 0 then
    head = head .. string.format(" t=%.3f", ts)
  end
  head = head .. " " .. summary
  pcall(function()
    if core and core.log_warning then
      core.log_warning(head)
      if #trace > 0 and trace ~= summary then
        core.log_warning(trace)
      end
    end
  end)
  return false
end

return Util
