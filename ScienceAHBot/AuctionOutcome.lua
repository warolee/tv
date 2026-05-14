--[[ ScienceAHBot — best-effort auction outcome hints from CHAT_MSG_SYSTEM (client-dependent). ]]

-- module-local, returned as the public interface
local ScienceAHBot = {}
local Util = require("ScienceAHBot/Util")

--- Recent bid/post intent for correlating chat lines (set by buy/snipe modules).
---@param root table
---@param info { module: string, itemID: number, price: number, t: number }|nil
function ScienceAHBot.set_last_auction_intent(root, info)
  if not root then
    return
  end
  if type(info) == "table" then
    --- `notify()` uses `GetTime()` for its age check, so prefer that clock for `info.t`.
    --- Fall back to whatever caller supplied (e.g. `tnow` from `core.time`/`izi.now`)
    --- if `GetTime` is unavailable, instead of silently dropping the timestamp.
    local stamped = false
    if GetTime then
      local ok, gt = pcall(GetTime)
      if ok and type(gt) == "number" then
        info.t = gt
        stamped = true
      end
    end
    if not stamped and type(info.t) ~= "number" then
      info.t = 0
    end
  end
  root._lastBidIntent = info
end

local function should_log(root)
  local d = root and root.Config and root.Config.behavior and root.Config.behavior.debug
  if type(d) ~= "table" then
    return true
  end
  if d.logAuctionChat == false then
    return false
  end
  return true
end

local function notify(root, kind, msg)
  if not should_log(root) then
    return
  end
  local intent = root._lastBidIntent
  local extra = ""
  if intent and type(intent.t) == "number" and type(intent.itemID) == "number" then
    local tnow = 0
    if GetTime then
      local ok, gt = pcall(GetTime)
      if ok and type(gt) == "number" then
        tnow = gt
      end
    end
    if tnow > 0 and (tnow - intent.t) < 15 then
      extra = string.format(
        " | intent: %s item=%s price=%s age=%.1fs",
        tostring(intent.module or "?"),
        tostring(intent.itemID),
        tostring(intent.price or "?"),
        tnow - intent.t
      )
    end
  end
  Util.safe_call("AuctionOutcome.notify", function()
    if core and core.log then
      core.log(string.format("[ScienceAHBot] Outcome (%s): %s%s", kind, tostring(msg), extra))
    end
  end, { root = root })
end

local function match_auction_hint(msg)
  if type(msg) ~= "string" then
    return nil
  end
  local low = string.lower(msg)
  if low:find("you won", 1, true) or low:find("auction won", 1, true) or low:find("you have bought", 1, true) then
    return "win"
  end
  if low:find("outbid", 1, true) then
    return "outbid"
  end
  if low:find("auction created", 1, true) or low:find("your auction of", 1, true) then
    return "listed"
  end
  return nil
end

function ScienceAHBot.install(root)
  if not root or root._auction_outcome_installed then
    return
  end
  root._auction_outcome_installed = true

  --[[ Sylvanas may inject before `CreateFrame` / `UIParent` exist
       (login screen, first frame after entering world). If the frame
       registration is only attempted once, the entire CHAT_MSG_SYSTEM
       outcome notifier silently never arms — and the only fix would
       be a manual /reload. Retry every engine tick until the frame
       is actually registered. After success the check is a single
       boolean read. Mirrors the same pattern used in Safety.lua. ]]
  local function try_register_outcome_frame()
    if root._auctionOutcomeFrameReady then
      return true
    end
    if type(rawget(_G, "CreateFrame")) ~= "function" then
      return false
    end
    local ok = pcall(function()
      local parent = rawget(_G, "UIParent")
      local f = CreateFrame("Frame", "ScienceAHBotAuctionOutcome", parent)
      f:RegisterEvent("CHAT_MSG_SYSTEM")
      f:SetScript("OnEvent", function(_, _, msg)
        local hint = match_auction_hint(msg)
        if hint == "win" then
          notify(root, "chat_auction_win", msg)
        elseif hint == "outbid" then
          notify(root, "chat_outbid", msg)
        elseif hint == "listed" then
          notify(root, "chat_listed", msg)
        end
      end)
      root._auctionOutcomeFrameReady = true
    end)
    return ok and root._auctionOutcomeFrameReady == true
  end

  Util.safe_call("AuctionOutcome.CreateFrame", function()
    try_register_outcome_frame()
  end, { root = root })

  if core and core.register_on_update_callback then
    pcall(function()
      core.register_on_update_callback(function()
        if root._auctionOutcomeFrameReady then
          return
        end
        try_register_outcome_frame()
      end)
    end)
  end
end

return ScienceAHBot
