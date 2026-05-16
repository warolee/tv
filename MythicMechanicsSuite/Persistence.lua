--[[ MythicMechanicsSuite — save/load to scripts_data/MythicMechanicsSuite/.

     Same model as ScienceAHBot: Sylvanas sandboxes plugin file I/O to
     the loader's `scripts_data/` tree. We never load arbitrary code:
     `load(text, name, "t", {})` enforces a *text-only* chunk with an
     empty environment, so even a tampered settings file can't call
     globals or affect the running plugin. ]]

local M = {}

local DATA_FOLDER = "MythicMechanicsSuite"
local DATA_FILE = "MythicMechanicsSuite/user_settings.lua"
local SAVE_DEBOUNCE = 0.85

local CURRENT_VERSION = 1
local MIGRATIONS = {}

local function migrate(data)
  if type(data) ~= "table" then return false end
  local v = data.version
  if v == nil then
    v = 1; data.version = 1
  end
  if type(v) ~= "number" then return false end
  while v < CURRENT_VERSION do
    local step = MIGRATIONS[v]
    if type(step) ~= "function" then return false end
    local nextV = step(data)
    if type(nextV) ~= "number" or nextV <= v then return false end
    v = nextV; data.version = v
  end
  return v <= CURRENT_VERSION
end

local function fmt_num(n)
  if type(n) ~= "number" then return "0" end
  if n ~= n or n == math.huge or n == -math.huge then return "0" end
  if n == math.floor(n) and math.abs(n) < 1e14 then
    return string.format("%d", math.floor(n))
  end
  local short = string.format("%.14g", n)
  if tonumber(short) == n then return short end
  return string.format("%.17g", n)
end

local function is_array(t)
  if type(t) ~= "table" then return false end
  local n = #t
  if n == 0 then return false end
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
      return false
    end
  end
  return true
end

local function serialize(v, depth)
  depth = depth or 0
  if depth > 24 then return "{}" end
  local tv = type(v)
  if tv == "nil" then return "nil" end
  if tv == "boolean" then return v and "true" or "false" end
  if tv == "number" then return fmt_num(v) end
  if tv == "string" then return string.format("%q", v) end
  if tv ~= "table" then return "nil" end
  if is_array(v) then
    local p = {}
    for i = 1, #v do p[i] = serialize(v[i], depth + 1) end
    return "{" .. table.concat(p, ",") .. "}"
  end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for i = 1, #keys do
    local k = keys[i]
    local val = v[k]
    local ks
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      ks = k .. "="
    else
      ks = "[" .. serialize(k, depth + 1) .. "]="
    end
    parts[#parts + 1] = ks .. serialize(val, depth + 1)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function deep_copy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, val in pairs(v) do r[k] = deep_copy(val) end
  return r
end

local function deep_merge(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then return end
  for k, val in pairs(src) do
    if type(val) == "table" and type(dst[k]) == "table" and not is_array(val) and not is_array(dst[k]) then
      deep_merge(dst[k], val)
    else
      dst[k] = deep_copy(val)
    end
  end
end

local function snapshot(cfg)
  return {
    version  = CURRENT_VERSION,
    enabled  = cfg.enabled,
    instanceOnly = cfg.instanceOnly,
    draw     = deep_copy(cfg.draw or {}),
    colors   = deep_copy(cfg.colors or {}),
    sound    = deep_copy(cfg.sound or {}),
    ui       = deep_copy(cfg.ui or {}),
    toggles  = deep_copy(cfg.toggles or {}),
    mechanicPalettes = deep_copy(cfg.mechanicPalettes or {}),
    debug    = deep_copy(cfg.debug or {}),
    behavior = deep_copy(cfg.behavior or {}),
  }
end

local function apply(cfg, data)
  if type(data) ~= "table" then return end
  if type(data.enabled) == "boolean" then cfg.enabled = data.enabled end
  if type(data.instanceOnly) == "boolean" then cfg.instanceOnly = data.instanceOnly end
  for _, k in ipairs({ "draw", "colors", "sound", "ui", "toggles", "mechanicPalettes", "debug", "behavior" }) do
    if type(data[k]) == "table" then
      cfg[k] = cfg[k] or {}
      deep_merge(cfg[k], data[k])
    end
  end
end

function M.load_into(root)
  local cfg = root and root.Config
  if type(cfg) ~= "table" then return end
  local text
  pcall(function() text = core.read_data_file(DATA_FILE) end)
  if type(text) ~= "string" or #text == 0 then return end
  local fn, err
  pcall(function()
    if type(load) == "function" then
      local chunk, e = load(text, "MMS_settings", "t", {})
      if type(chunk) == "function" then fn = chunk; return end
      err = e
    end
    if not fn and type(loadstring) == "function" then
      local chunk, e = loadstring(text, "MMS_settings")
      if type(chunk) == "function" and type(setfenv) == "function" then
        setfenv(chunk, {}); fn = chunk; return
      end
      err = err or e
    end
  end)
  if not fn then
    pcall(function() core.log_warning("[MythicMechanicsSuite] settings load: " .. tostring(err)) end)
    return
  end
  local ok, data = pcall(fn)
  if not ok or type(data) ~= "table" then return end
  if not migrate(data) then return end
  apply(cfg, data)
  pcall(function() core.log("[MythicMechanicsSuite] Loaded settings from scripts_data/" .. DATA_FILE) end)
end

function M.save(root)
  local cfg = root and root.Config
  if type(cfg) ~= "table" then return end
  local body = "return " .. serialize(snapshot(cfg)) .. "\n"
  pcall(function()
    core.create_data_folder(DATA_FOLDER)
    core.create_data_file(DATA_FILE)
    core.write_data_file(DATA_FILE, body)
  end)
end

function M.mark_dirty(root)
  if not root then return end
  root._mms_dirty = true
  local t = 0
  pcall(function() if core and core.time then t = core.time() end end)
  if t == 0 and type(GetTime) == "function" then t = GetTime() end
  root._mms_flush_at = (t or 0) + SAVE_DEBOUNCE
end

function M.try_flush(root)
  if not root or not root._mms_dirty then return end
  local t = 0
  pcall(function() if core and core.time then t = core.time() end end)
  if t == 0 and type(GetTime) == "function" then t = GetTime() end
  if (t or 0) < (root._mms_flush_at or 0) then return end
  root._mms_dirty = false
  pcall(function() M.save(root) end)
end

return M
