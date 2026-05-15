--[[ MythicMechanicsSuite — Sound: thin wrapper that survives missing APIs.

     Sylvanas builds variably expose:
        core.play_sound(fdid)            -- newer builds
        core.audio.play_sound(fdid)      -- some forks
        PlaySoundFile(filename, channel) -- FrameXML, only via game side
        PlaySound(soundKitID)            -- FrameXML

     We try them in order and ignore failures silently. Sound is a
     nice-to-have, never gate logic on whether it actually played. ]]

local M = {}

local LAST_AT = {}
local COOLDOWN = 0.4

local function now()
  local t = 0
  pcall(function() if core and core.time then t = core.time() end end)
  if t == 0 and type(GetTime) == "function" then t = GetTime() end
  return t or 0
end

function M.play(fdid)
  if not fdid then return end
  local n = now()
  if (n - (LAST_AT[fdid] or 0)) < COOLDOWN then return end
  LAST_AT[fdid] = n
  pcall(function()
    if core and core.play_sound then
      core.play_sound(fdid); return
    end
    if core and core.audio and core.audio.play_sound then
      core.audio.play_sound(fdid); return
    end
    if type(PlaySound) == "function" then
      PlaySound(fdid); return
    end
  end)
end

return M
