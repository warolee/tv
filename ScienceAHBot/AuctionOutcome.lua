--[[ ScienceAHBot — best-effort auction outcome hints from CHAT_MSG_SYSTEM (client-dependent). ]]

local ScienceAHBot = {}

--- Recent bid/post intent for correlating chat lines (set by buy/snipe modules).
---@param root table
---@param info { module: string, itemID: number, price: number, t: number }|nil
function ScienceAHBot.set_last_auction_intent(root, info)
  if not root then
    return
  end
  if type(info) == "table" then
    --- Match `notify()` age check: it uses `GetTime()`, not `izi.now()`.
    pcall(function()
      if GetTime then
        info.t = GetTime()
      end
    end)
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
    pcall(function()
      if GetTime then
        tnow = GetTime()
      end
    end)
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
  pcall(function()
    if core and core.log then
      core.log(string.format("[ScienceAHBot] Outcome (%s): %s%s", kind, tostring(msg), extra))
    end
  end)
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
  pcall(function()
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
  end)
end

return ScienceAHBot
