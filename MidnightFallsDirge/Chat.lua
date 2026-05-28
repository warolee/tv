--[[ MidnightFallsDirge — Chat: group callouts for the Death's Dirge order.

     Sends the recorded sequence to the group and/or whispers each player
     their personal symbol. All chat goes through the WoW FrameXML global
     `SendChatMessage(msg, chatType, language, target)` reached via `_G`,
     the same way `ScienceAHBot` reaches `_G.TSM_API` and `MythicMechanics
     Suite` reaches `_G.DBM` — Sylvanas shares the game's Lua global table.

     Restriction notes (Blizzard side):
       * SAY / YELL / CHANNEL are hardware-event gated and will silently fail
         from a script in most cases.
       * RAID / RAID_WARNING / INSTANCE_CHAT / PARTY / WHISPER are fine inside
         an instance, which is where this boss lives.

     Everything is wrapped in pcall: a missing global or a protected call must
     never take down the render/update thread. ]]

local M = {}

--- Reach the WoW global env defensively (some builds expose globals directly,
--- some only through `_G`). Mirrors MMS/BWDBMBridge's `_G` probing.
local function G()
  local ok, env = pcall(function() return _G end)
  if ok and type(env) == "table" then return env end
  return nil
end

local function g_fn(name)
  local env = G()
  if not env then return nil end
  local ok, fn = pcall(function() return env[name] end)
  if ok and type(fn) == "function" then return fn end
  return nil
end

local function g_call(name, ...)
  local fn = g_fn(name)
  if not fn then return nil end
  local res = { pcall(fn, ...) }
  if res[1] then
    return res[2], res[3], res[4]
  end
  return nil
end

--- Pick a real, currently-valid group channel for "AUTO".
--- RAID_WARNING only works for lead/assist, so we feature-detect it.
local function resolve_channel(requested)
  requested = requested or "AUTO"
  if requested ~= "AUTO" then return requested end

  local in_instance_group = g_call("IsInGroup", 2) --- LE_PARTY_CATEGORY_INSTANCE
  local in_raid = g_call("IsInRaid")
  local in_group = g_call("IsInGroup")

  --- Prefer an audible raid warning if we are allowed to send one.
  local can_rw = g_call("IsRaidLeader") or g_call("IsRaidOfficer")
  if can_rw == nil then
    --- Newer API: UnitIsGroupLeader / UnitIsGroupAssistant("player")
    can_rw = g_call("UnitIsGroupLeader", "player") or g_call("UnitIsGroupAssistant", "player")
  end

  if in_raid then
    if can_rw then return "RAID_WARNING" end
    return "RAID"
  end
  if in_instance_group then return "INSTANCE_CHAT" end
  if in_group then return "PARTY" end
  return "SAY"
end

--- Is any chat global available at all? Used by the menu to grey out options.
function M.available()
  return g_fn("SendChatMessage") ~= nil
end

local function send(msg, channel, target)
  local fn = g_fn("SendChatMessage")
  if not fn or not msg or msg == "" then return false end
  local ok = pcall(fn, tostring(msg), channel, nil, target)
  return ok and true or false
end

local function prefix_of(cfg)
  local p = cfg and cfg.chat and cfg.chat.prefix
  if type(p) == "string" and p ~= "" then return p .. " " end
  return ""
end

--- Build the "1: Name [SYMBOL] -> 2: ..." order string from the queue.
function M.format_order(queue)
  local parts = {}
  for i = 1, #queue do
    local s = queue[i]
    parts[#parts + 1] = string.format("%d:%s [%s]", i, s.name or "?", s.label or "?")
  end
  return table.concat(parts, "  ->  ")
end

--- Announce the full order once. Returns true if a message was sent.
function M.announce(cfg, queue)
  if not cfg or not cfg.chat or not cfg.chat.announce then return false end
  if not queue or #queue == 0 then return false end

  local channel = resolve_channel(cfg.chat.announceChannel)
  local header = prefix_of(cfg) .. "Death's Dirge order — run in when your symbol fires:"
  local body = M.format_order(queue)

  local sent = send(header, channel)
  --- RAID_WARNING truncates hard; keep the order on a second normal line so
  --- it is fully readable in the chat log.
  local body_channel = channel
  if channel == "RAID_WARNING" then
    body_channel = (g_call("IsInRaid") and "RAID") or "PARTY"
  end
  local sent2 = send(prefix_of(cfg) .. body, body_channel)
  return sent or sent2
end

--- Whisper every assigned player their own symbol + slot. Returns count sent.
function M.whisper_assignments(cfg, queue)
  if not cfg or not cfg.chat or not cfg.chat.whisper then return 0 end
  if not queue or #queue == 0 then return 0 end

  --- Don't whisper ourselves; the HUD already shows it.
  local me = g_call("UnitName", "player")

  local count = 0
  for i = 1, #queue do
    local s = queue[i]
    if s.name and s.name ~= "" and s.name ~= me then
      local msg = string.format(
        "%sYour Death's Dirge symbol is %s (run in at #%d in the order).",
        prefix_of(cfg), s.label or "?", i
      )
      if send(msg, "WHISPER", s.name) then
        count = count + 1
      end
    end
  end
  return count
end

return M
