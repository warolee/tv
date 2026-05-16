--[[ MidnightFallsDirge — Util: pcall fault boundary + throttled error logging.

     Every callback we hand to `core.register_*` is wrapped through
     `safe_call` so a single mistyped field in encounter data cannot
     blow up the render thread. Errors are throttled by label so a
     mechanic that fails every frame does not flood the chat log.
]]

local M = {}

local LAST_ERROR_AT = {}
local DEFAULT_THROTTLE_SEC = 2.0

local function now_seconds()
  local t = 0
  pcall(function()
    if core and core.time then
      t = core.time()
    end
  end)
  if t == 0 and type(GetTime) == "function" then
    t = GetTime()
  end
  return t or 0
end

local function throttle_for(root)
  local cfg = root and root.Config
  if type(cfg) ~= "table" then
    return DEFAULT_THROTTLE_SEC
  end
  local b = cfg.behavior
  local d = b and b.debug
  if type(d) == "table" and type(d.errorLogThrottleSec) == "number" then
    return d.errorLogThrottleSec
  end
  return DEFAULT_THROTTLE_SEC
end

--- Wrap `fn` so errors are caught and logged at most once per `throttle`
--- seconds per `label`. Returns the function's first return value on
--- success, or `nil` on error.
---@param label string
---@param fn fun(...): any
---@param ctx? table { root = root, throttle = number }
function M.safe_call(label, fn, ctx)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, err = pcall(fn)
  if ok then
    return err
  end
  local throttle = (ctx and ctx.throttle) or throttle_for(ctx and ctx.root) or DEFAULT_THROTTLE_SEC
  local t = now_seconds()
  local last = LAST_ERROR_AT[label] or 0
  if t - last < throttle then
    return nil
  end
  LAST_ERROR_AT[label] = t
  local head = "[MidnightFallsDirge] " .. tostring(label) .. " failed: " .. tostring(err)
  pcall(function()
    if core and core.log_warning then
      core.log_warning(head)
      if type(debug) == "table" and type(debug.traceback) == "function" then
        local trace = debug.traceback("", 2)
        if type(trace) == "string" and #trace > 0 then
          core.log_warning(trace)
        end
      end
    end
  end)
  return nil
end

--- Same as `safe_call` but always returns the boolean `ok` so callers
--- can branch on success. Used by the render/update tick wrappers.
function M.try(label, fn, ctx)
  if type(fn) ~= "function" then
    return false
  end
  local ok, err = pcall(fn)
  if ok then
    return true
  end
  local throttle = (ctx and ctx.throttle) or throttle_for(ctx and ctx.root) or DEFAULT_THROTTLE_SEC
  local t = now_seconds()
  local last = LAST_ERROR_AT[label] or 0
  if t - last >= throttle then
    LAST_ERROR_AT[label] = t
    pcall(function()
      if core and core.log_warning then
        core.log_warning("[MidnightFallsDirge] " .. tostring(label) .. " failed: " .. tostring(err))
      end
    end)
  end
  return false, err
end

function M.now_seconds()
  return now_seconds()
end

function M.clamp(x, lo, hi)
  if x ~= x then
    return lo
  end
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

function M.round(x)
  if type(x) ~= "number" then
    return 0
  end
  return math.floor(x + 0.5)
end

function M.deep_copy(v)
  if type(v) ~= "table" then
    return v
  end
  local r = {}
  for k, val in pairs(v) do
    r[k] = M.deep_copy(val)
  end
  return r
end

return M
