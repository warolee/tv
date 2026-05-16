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

  --- Sanity-check Encounters: did the data files load and does every
  --- mechanic row expose { spellID, trigger, type, anchor }? Raid/M+
  --- datasets mix Season 1 baseline ids with expanded Midnight rows
  --- (see file headers); rows still must be structurally valid.
  local Encounters = require("Encounters")
  local enc_count, mech_count = 0, 0
  local missing_field_rows = 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    enc_count = enc_count + 1
    for _, m in ipairs(e.mechanics or {}) do
      mech_count = mech_count + 1
      if not (m.spellID and m.trigger and m.type and m.anchor) then
        missing_field_rows = missing_field_rows + 1
      end
    end
  end
  if enc_count == 0 then
    warns[#warns + 1] = "no encounter data loaded — check data/raids_midnight.lua and data/mplus_midnight.lua."
  else
    warns[#warns + 1] = string.format(
      "Loaded %d encounters / %d mechanics (Midnight 12.0.5 data files).",
      enc_count, mech_count
    )
  end
  if missing_field_rows > 0 then
    warns[#warns + 1] = string.format(
      "%d data rows are missing one of {spellID, trigger, type, anchor} — those will be skipped at runtime.",
      missing_field_rows
    )
  end

  --- Routing mode advisory.
  local cfg = root and root.Config
  local mode = cfg and cfg.behavior and cfg.behavior.dataSource or "Auto"
  warns[#warns + 1] = string.format(
    "Data source routing: %s (Config.behavior.dataSource)", tostring(mode)
  )

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

  return warns
end

--- Compatibility shim — Old UI code (and external consumers) called
--- this for the placeholder pill. The current datasets do not tag
--- `_placeholder`; we still report `placeholders = 0` for any callers
--- that expect this shape.
function M.placeholder_stats()
  local Encounters = require("Encounters")
  local total, encounters = 0, 0
  for _, e in ipairs(Encounters.all_encounters() or {}) do
    encounters = encounters + 1
    total = total + #(e.mechanics or {})
  end
  return { total = total, placeholders = 0, encounters = encounters }
end

return M
