--[[ ScienceAHBot — batched CSV deal/scan history under scripts_data/ScienceAHBot/scan_log.csv ]]

local ScienceAHBot = {}

local LOG_FILE = "ScienceAHBot/scan_log.csv"
local ARCHIVE_FILE = "ScienceAHBot/scan_log_prev.csv"
local HEADER = "ts,item_id,module,tsm_copper,row1_copper,ratio,max_buy_copper,base_ratio,effective_ratio,action\n"

local function cfg_scan_log(root)
  local cfg = root and root.Config
  local b = cfg and cfg.behavior
  return b and b.scanLog
end

local function now_s()
  local t = 0
  pcall(function()
    if core and core.time then
      t = core.time()
    end
  end)
  if t == 0 and GetTime then
    t = GetTime()
  end
  return t
end

local function icop(n)
  if type(n) ~= "number" or n ~= n then
    return ""
  end
  return tostring(math.floor(n + 0.5))
end

local function frat(n)
  if type(n) ~= "number" or n ~= n then
    return ""
  end
  return string.format("%.6g", n)
end

local function csv_action(s)
  if not s then
    return ""
  end
  s = tostring(s)
  if s:find("[\",\n\r]") then
    return '"' .. s:gsub('"', '""') .. '"'
  end
  return s
end

local function read_existing()
  local text = nil
  pcall(function()
    text = core.read_data_file(LOG_FILE)
  end)
  if type(text) ~= "string" then
    return ""
  end
  return text
end

local function flush_internal(root)
  local sl = cfg_scan_log(root)
  if not sl or sl.enabled ~= true then
    root._scanLogBuf = {}
    return
  end
  local buf = root._scanLogBuf
  if not buf or #buf == 0 then
    return
  end
  local append = table.concat(buf)
  for i = 1, #buf do
    buf[i] = nil
  end

  local old = read_existing()
  if #old > 0 and not old:find("^ts,item_id,module", 1, true) then
    old = HEADER .. old
  end
  if #old == 0 then
    old = HEADER
  elseif old:sub(-1) ~= "\n" then
    old = old .. "\n"
  end

  local combined = old .. append
  local maxB = sl.maxFileBytes
  if type(maxB) == "number" and maxB > 10000 and #combined > maxB then
    pcall(function()
      core.create_data_folder("ScienceAHBot")
      core.create_data_file(ARCHIVE_FILE)
      core.write_data_file(ARCHIVE_FILE, old)
    end)
    combined = HEADER .. append
  end

  pcall(function()
    core.create_data_folder("ScienceAHBot")
    core.create_data_file(LOG_FILE)
    core.write_data_file(LOG_FILE, combined)
  end)
  root._scanLogFlushAt = nil
end

function ScienceAHBot.record(root, e)
  if not root or type(e) ~= "table" then
    return
  end
  local sl = cfg_scan_log(root)
  if not sl or sl.enabled ~= true then
    return
  end

  local ts = e.ts or now_s()
  local itemId = e.itemId or e.itemID or 0
  local module = e.module or "?"
  local tsm = e.tsm
  local row1 = e.row1
  local maxBuy = e.maxBuy
  local baseR = e.baseRatio
  local effR = e.effRatio

  local ratio = ""
  if type(tsm) == "number" and tsm > 0 and type(row1) == "number" and row1 > 0 then
    ratio = frat(row1 / tsm)
  end

  local line = string.format(
    "%.3f,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
    ts,
    tostring(itemId),
    csv_action(module),
    icop(tsm),
    icop(row1),
    ratio,
    icop(maxBuy),
    frat(baseR),
    frat(effR),
    csv_action(e.action or "")
  )

  root._scanLogBuf = root._scanLogBuf or {}
  root._scanLogBuf[#root._scanLogBuf + 1] = line

  local deb = sl.flushDebounceSec or 2.0
  root._scanLogFlushAt = ts + deb

  local every = sl.flushEveryRows or 8
  if every < 1 then
    every = 1
  end
  if #root._scanLogBuf >= every then
    flush_internal(root)
  end
end

function ScienceAHBot.tick_flush(root, tnow)
  if not root or not root._scanLogBuf or #root._scanLogBuf == 0 then
    return
  end
  local sl = cfg_scan_log(root)
  if not sl or sl.enabled ~= true then
    root._scanLogBuf = {}
    return
  end
  local t = tnow or now_s()
  if t < (root._scanLogFlushAt or 0) then
    return
  end
  flush_internal(root)
end

function ScienceAHBot.flush_now(root)
  flush_internal(root)
end

return ScienceAHBot
