--[[ ScienceAHBot — save/load user settings via Project Sylvanas File I/O (scripts_data/ only). ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}

local DATA_FOLDER = "ScienceAHBot"
local DATA_FILE = "ScienceAHBot/user_settings.lua"

local SAVE_DEBOUNCE = 0.85

--[[ Current on-disk schema. Bump CURRENT_VERSION whenever the shape changes
     in a way that older code would misinterpret. Add an entry to MIGRATIONS
     keyed on the *source* version that transforms the data table in-place
     and returns the new version. Migrations are applied in ascending order
     until `data.version == CURRENT_VERSION`. The dispatch is intentionally
     additive: nothing here drops fields it doesn't know about, so a future
     downgrade still preserves user input. ]]
local CURRENT_VERSION = 1

--- Migration handlers: keyed by the version of the input data. Each handler
--- must mutate `data` in place and return the new version (>= old). A `nil`
--- return is treated as "no advance" and aborts migration with a warning.
---@type table<integer, fun(data: table): integer|nil>
local MIGRATIONS = {
  -- [1] = function(data) ... ; return 2 end,   -- example: when v2 ships
}

local function migrate_saved(data)
  if type(data) ~= "table" then
    return false
  end
  local v = data.version
  if v == nil then
    v = 1
    data.version = 1
  end
  if type(v) ~= "number" then
    return false
  end
  local guard = 0
  while v < CURRENT_VERSION do
    guard = guard + 1
    if guard > 32 then
      pcall(function()
        core.log_warning("[ScienceAHBot] Settings migration aborted (loop guard tripped at v=" .. tostring(v) .. ")")
      end)
      return false
    end
    local step = MIGRATIONS[v]
    if type(step) ~= "function" then
      pcall(function()
        core.log_warning(
          "[ScienceAHBot] Settings: no migration from v" .. tostring(v) .. " to v" .. tostring(CURRENT_VERSION) .. "; data ignored"
        )
      end)
      return false
    end
    local nextV = step(data)
    if type(nextV) ~= "number" or nextV <= v then
      pcall(function()
        core.log_warning("[ScienceAHBot] Settings migration v" .. tostring(v) .. " did not advance; aborting")
      end)
      return false
    end
    v = nextV
    data.version = v
  end
  if v > CURRENT_VERSION then
    --- Newer-than-known schema: refuse rather than misinterpret unknown fields.
    pcall(function()
      core.log_warning("[ScienceAHBot] Settings written by newer version (v" .. tostring(v) .. "); current is v" .. tostring(CURRENT_VERSION) .. "; data ignored")
    end)
    return false
  end
  return true
end

local function format_number(n)
  if type(n) ~= "number" then
    return "0"
  end
  if n == math.floor(n) and math.abs(n) < 1e14 then
    return string.format("%d", math.floor(n))
  end
  --[[ Use the shortest representation that still round-trips through
       `tonumber()` for any value the user is likely to enter (ratios
       like 0.7, EWMA alphas like 0.15, etc.). `%.17g` is fully
       round-trip safe for arbitrary IEEE 754 doubles but produces ugly
       artefacts like `0.69999999999999996` for `0.7`, which then leak
       into the saved file and back into the UI. `%.14g` is sufficient
       for every config value in this plugin and keeps saves readable;
       fall back to `%.17g` only if `%.14g` would lose information
       (e.g. a learned EWMA that drifted into many fractional digits). ]]
  local short = string.format("%.14g", n)
  local round = tonumber(short)
  if round == n then
    return short
  end
  return string.format("%.17g", n)
end

local function deep_copy(v)
  if type(v) ~= "table" then
    return v
  end
  local r = {}
  for k, val in pairs(v) do
    r[k] = deep_copy(val)
  end
  return r
end

local function is_plain_array(t)
  if type(t) ~= "table" then
    return false
  end
  local n = #t
  if n == 0 then
    return false
  end
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
      return false
    end
  end
  return true
end

local function serialize_value(v, depth)
  depth = depth or 0
  if depth > 24 then
    return "{}"
  end
  local tv = type(v)
  if tv == "nil" then
    return "nil"
  end
  if tv == "boolean" then
    return v and "true" or "false"
  end
  if tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      return "0"
    end
    return format_number(v)
  end
  if tv == "string" then
    return string.format("%q", v)
  end
  if tv ~= "table" then
    return "nil"
  end

  if is_plain_array(v) then
    local p = {}
    for i = 1, #v do
      p[i] = serialize_value(v[i], depth + 1)
    end
    return "{" .. table.concat(p, ",") .. "}"
  end

  local keys = {}
  for k in pairs(v) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)

  local parts = {}
  for i = 1, #keys do
    local k = keys[i]
    local val = v[k]
    local ks
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      ks = k .. "="
    else
      ks = "[" .. serialize_value(k, depth + 1) .. "]="
    end
    parts[#parts + 1] = ks .. serialize_value(val, depth + 1)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function deep_merge(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then
    return
  end
  for k, val in pairs(src) do
    if type(val) == "table" and type(dst[k]) == "table" and not is_plain_array(val) and not is_plain_array(dst[k]) then
      deep_merge(dst[k], val)
    else
      dst[k] = deep_copy(val)
    end
  end
end

local function build_snapshot(cfg)
  return {
    version = CURRENT_VERSION,
    Items = deep_copy(cfg.Items or {}),
    watchlist = deep_copy(cfg.watchlist or {}),
    patterns = deep_copy(cfg.patterns or {}),
    DefaultRatio = cfg.DefaultRatio,
    buyRatio = cfg.buyRatio,
    thresholds = deep_copy(cfg.thresholds or {}),
    jitter = deep_copy(cfg.jitter or {}),
    fatigueWorkSecondsMin = cfg.fatigueWorkSecondsMin,
    fatigueWorkSecondsMax = cfg.fatigueWorkSecondsMax,
    fatigueRestSecondsMin = cfg.fatigueRestSecondsMin,
    fatigueRestSecondsMax = cfg.fatigueRestSecondsMax,
    behavior = deep_copy(cfg.behavior or {}),
  }
end

--[[ Strictly type-check each field before applying. A tampered or
     corrupted user_settings.lua that puts e.g. `Items = "garbage"`
     would otherwise propagate a string into cfg.Items, making any
     later `next(cfg.Items)` or `cfg.Items[id]` crash. Wrong-type
     fields are skipped (defaults from Config.lua remain in effect)
     and the rest of the save still applies. ]]
local function apply_saved(cfg, data)
  if type(data) ~= "table" then
    return
  end
  if type(data.Items) == "table" then
    cfg.Items = deep_copy(data.Items)
  end
  if type(data.watchlist) == "table" then
    cfg.watchlist = deep_copy(data.watchlist)
  end
  if type(data.patterns) == "table" then
    cfg.patterns = deep_copy(data.patterns)
  end
  if type(data.DefaultRatio) == "number" then
    cfg.DefaultRatio = data.DefaultRatio
  end
  --- buyRatio is intentionally allowed to be nil (legacy schema) but
  --- only otherwise accepted as a number.
  if data.buyRatio == nil then
    cfg.buyRatio = nil
  elseif type(data.buyRatio) == "number" then
    cfg.buyRatio = data.buyRatio
  end
  if type(data.thresholds) == "table" then
    cfg.thresholds = cfg.thresholds or {}
    deep_merge(cfg.thresholds, data.thresholds)
  end
  if type(data.jitter) == "table" then
    cfg.jitter = cfg.jitter or {}
    deep_merge(cfg.jitter, data.jitter)
  end
  if type(data.fatigueWorkSecondsMin) == "number" then
    cfg.fatigueWorkSecondsMin = data.fatigueWorkSecondsMin
  end
  if type(data.fatigueWorkSecondsMax) == "number" then
    cfg.fatigueWorkSecondsMax = data.fatigueWorkSecondsMax
  end
  if type(data.fatigueRestSecondsMin) == "number" then
    cfg.fatigueRestSecondsMin = data.fatigueRestSecondsMin
  end
  if type(data.fatigueRestSecondsMax) == "number" then
    cfg.fatigueRestSecondsMax = data.fatigueRestSecondsMax
  end
  if type(data.behavior) == "table" then
    cfg.behavior = cfg.behavior or {}
    deep_merge(cfg.behavior, data.behavior)
  end
end

function ScienceAHBot.load_into(root)
  local cfg = root and root.Config
  if type(cfg) ~= "table" then
    return
  end
  local text = nil
  pcall(function()
    text = core.read_data_file(DATA_FILE)
  end)
  if type(text) ~= "string" or #text == 0 then
    return
  end
  --- Never use bare loadstring(text): a tampered file could execute with full globals.
  --- Prefer load(..., "t", {}). On Lua 5.1, use loadstring + setfenv(chunk, {}) only.
  local f, err = nil, nil
  pcall(function()
    if type(load) == "function" then
      local chunk, e = load(text, "ScienceAHBot_settings", "t", {})
      if type(chunk) == "function" then
        f = chunk
        return
      end
      err = e
    end
    if not f and type(loadstring) == "function" then
      local chunk, e = loadstring(text, "ScienceAHBot_settings")
      if type(chunk) == "function" and type(setfenv) == "function" then
        setfenv(chunk, {})
        f = chunk
        return
      end
      err = err or e or "refused_unsandboxed_settings"
    end
  end)
  if not f then
    pcall(function()
      core.log_warning("[ScienceAHBot] Settings load: " .. tostring(err))
    end)
    return
  end
  local ok, data = pcall(f)
  if not ok or type(data) ~= "table" then
    return
  end
  if not migrate_saved(data) then
    return
  end
  apply_saved(cfg, data)
  pcall(function()
    core.log("[ScienceAHBot] Loaded settings from scripts_data/" .. DATA_FILE)
  end)
end

function ScienceAHBot.save(root)
  local cfg = root and root.Config
  if type(cfg) ~= "table" then
    return
  end
  local snap = build_snapshot(cfg)
  snap.version = CURRENT_VERSION
  local body = "return " .. serialize_value(snap) .. "\n"
  local okw = false
  pcall(function()
    core.create_data_folder(DATA_FOLDER)
    core.create_data_file(DATA_FILE)
    core.write_data_file(DATA_FILE, body)
    okw = true
  end)
  if okw then
    pcall(function()
      core.log("[ScienceAHBot] Saved settings to scripts_data/" .. DATA_FILE)
    end)
  else
    pcall(function()
      core.log_warning("[ScienceAHBot] Settings save failed (check scripts_data permissions)")
    end)
  end
end

function ScienceAHBot.mark_dirty(root)
  if not root then
    return
  end
  root._persistDirty = true
  local t = 0
  pcall(function()
    t = core.time()
  end)
  if t == 0 and GetTime then
    t = GetTime()
  end
  root._persistFlushAt = t + SAVE_DEBOUNCE
end

function ScienceAHBot.try_flush(root)
  if not root or not root._persistDirty then
    return
  end
  local t = 0
  pcall(function()
    t = core.time()
  end)
  if t == 0 and GetTime then
    t = GetTime()
  end
  if t < (root._persistFlushAt or 0) then
    return
  end
  root._persistDirty = false
  pcall(function()
    ScienceAHBot.save(root)
  end)
end

return ScienceAHBot
