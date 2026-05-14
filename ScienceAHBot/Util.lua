local Util = {}

local IZI = (function()
  local ok, mod = pcall(require, "common/izi_sdk")
  return ok and mod or nil
end)()

--- Best-effort monotonic-ish timestamp. Aligns with the rest of the
--- codebase (Safety, Core, TSM_Helper, ScanLog) which all try IZI.now,
--- then `core.time`, then `GetTime`. Without this, `safe_call`'s
--- per-label error throttle silently degrades to a no-op on any
--- runtime that doesn't expose `GetTime` (e.g. very early load).
local function now_ts()
  if IZI and IZI.now then
    local ok, t = pcall(IZI.now)
    if ok and type(t) == "number" and t > 0 then
      return t
    end
  end
  if core and core.time then
    local ok, t = pcall(core.time)
    if ok and type(t) == "number" and t > 0 then
      return t
    end
  end
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
  --- `debug` may be absent in restricted sandboxes; never assume it.
  if type(rawget(_G, "debug")) == "table" and type(debug.traceback) == "function" then
    pcall(function()
      trace = debug.traceback(summary, 2) or ""
    end)
  end
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
