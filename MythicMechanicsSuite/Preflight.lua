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
  local placeholder_count = 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    enc_count = enc_count + 1
    for _, m in ipairs(e.mechanics or {}) do
      mech_count = mech_count + 1
      if m._placeholder then placeholder_count = placeholder_count + 1 end
    end
  end
  if enc_count == 0 then
    warns[#warns + 1] = "no encounter data loaded — check data/raids_midnight.lua and data/mplus_midnight.lua."
  else
    warns[#warns + 1] = string.format("Loaded %d encounters / %d mechanics (Midnight 12.0.5).", enc_count, mech_count)
  end

  --- BW/DBM bridge status. We probe directly rather than reading
  --- `root._mms_bridge` so Preflight can be run before BWDBMBridge.install.
  local ok_br, Bridge = pcall(require, "BWDBMBridge")
  if ok_br and Bridge then
    local dbm = Bridge.has_dbm()
    local bw  = Bridge.has_bigwigs()
    if dbm or bw then
      warns[#warns + 1] = string.format(
        "BW/DBM bridge: DBM=%s, BigWigs=%s — events will mirror into MMS warnings when their toggles are on.",
        dbm and ("v" .. tostring(Bridge.dbm_version() or "?")) or "off",
        bw  and ("v" .. tostring(Bridge.bw_version()  or "?")) or "off"
      )
    else
      warns[#warns + 1] = "BW/DBM bridge: neither BigWigs nor DBM detected; engine runs from data/*.lua only."
    end
  end

  if placeholder_count > 0 then
    --- The data files ship with PLACEHOLDER spell ids in the
    --- 1200000+ / 1300000+ / 1310000+ ranges because authoritative
    --- ids for Midnight content are still being datamined. Until you
    --- replace them with real ids, those mechanics will never fire
    --- (no real spell will match). Run `/dump UnitCastingInfo("target")`
    --- in-game, then edit data/raids_midnight.lua / data/mplus_midnight.lua
    --- and drop the `_placeholder = true` flag.
    warns[#warns + 1] = string.format(
      "%d / %d mechanics use placeholder spell IDs (Midnight content). Edit data/*.lua to plug in real IDs from in-game.",
      placeholder_count, mech_count
    )
  end

  return warns
end

--- Returns { total, placeholders, encounters } so the UI can render a
--- compact status pill in the overlay.
function M.placeholder_stats()
  local Encounters = require("Encounters")
  local total, placeholders, encounters = 0, 0, 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    encounters = encounters + 1
    for _, m in ipairs(e.mechanics or {}) do
      total = total + 1
      if m._placeholder then placeholders = placeholders + 1 end
    end
  end
  return { total = total, placeholders = placeholders, encounters = encounters }
end

return M
