--[[ MythicMechanicsSuite — Preflight: collect warnings about the
     loaded Sylvanas build so the user knows up-front if a key API is
     missing. We never refuse to load — every draw call already
     degrades gracefully through `pcall`. This module just surfaces
     "you won't see <thing> because <reason>" in chat. ]]

local M = {}

local function has(path)
  local cur = _G
  for part in string.gmatch(path, "[^%.]+") do
    if type(cur) ~= "table" then return false end
    cur = cur[part]
    if cur == nil then return false end
  end
  return true
end

function M.collect_warnings(root)
  local warns = {}

  if not has("core.graphics.circle_3d") and not has("core.graphics.line_3d") then
    warns[#warns + 1] = "core.graphics has no 3D drawing primitives — ground circles/beams/cones will be invisible."
  end
  if not has("core.graphics.text_2d") then
    warns[#warns + 1] = "core.graphics.text_2d missing — overlay HUD will be invisible."
  end
  if not has("core.object_manager.get_local_player") then
    warns[#warns + 1] = "core.object_manager.get_local_player missing — plugin will idle until APIs return."
  end
  if not has("core.register_on_render_callback") and not has("core.register_on_update_callback") then
    warns[#warns + 1] = "neither register_on_render_callback nor register_on_update_callback is exposed — no ticks will fire."
  end
  if not has("core.read_data_file") or not has("core.write_data_file") then
    warns[#warns + 1] = "core.read/write_data_file missing — settings will not persist between sessions."
  end
  if not has("core.play_sound") and not has("core.audio.play_sound") then
    warns[#warns + 1] = "no sound API detected — alert sounds will be silent."
  end

  --- Sanity-check Encounters
  local Encounters = require("Encounters")
  local enc_count = 0
  local mech_count = 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    enc_count = enc_count + 1
    mech_count = mech_count + #(e.mechanics or {})
  end
  if enc_count == 0 then
    warns[#warns + 1] = "no encounter data loaded — check data/raids_tww.lua and data/mplus_tww.lua."
  else
    warns[#warns + 1] = string.format("Loaded %d encounters / %d mechanics.", enc_count, mech_count)
  end

  return warns
end

return M
