--[[ MidnightFallsDirge — Markers: head icons + optional raid-target markers.

     Two independent jobs:

       1. draw_glyph(...) renders a small symbol (circle / square / diamond /
          triangle / cross) in screen space. DirgeTracker calls this above each
          assigned player's head so you can see, at a glance, who runs in for
          which rune. These are pure `core.graphics` draws — no game state is
          touched, works for everyone running the plugin.

       2. set_raid_marker(...) sets a real in-game raid-target marker on the
          assigned player via the FrameXML global `SetRaidTarget`. This is
          opt-in (`Config.raidMarkers.enabled`) and best-effort: it needs raid
          assist/lead and a resolvable unit token, so it can silently no-op.

     The Death's Dirge runes line up 1:1 with WoW raid-target colours, so the
     drawn glyph colour and the real marker match:
       CROSS (X) → 7 (red),   SQUARE → 6 (blue),  CIRCLE → 2 (orange),
       DIAMOND   → 3 (purple), TRIANGLE → 4 (green). ]]

local M = {}

local Geom = require("Geometry")

local function v2(x, y)
  if Geom and Geom.V2 then return Geom.V2(x, y) end
  return { x = x, y = y }
end

local ok_color, color_lib = pcall(require, "common/color")

local function color(r, g, b, a)
  r = r or 255; g = g or 255; b = b or 255; a = a or 255
  if ok_color and color_lib then
    local ok, made = pcall(function()
      if color_lib.new then return color_lib.new(r, g, b, a) end
      return color_lib(r, g, b, a)
    end)
    if ok and made then return made end
  end
  return { r = r, g = g, b = b, a = a }
end

local function color_of(c, alpha)
  if type(c) ~= "table" then return color(255, 255, 255, alpha or 255) end
  return color(c.r or c[1], c.g or c[2], c.b or c[3], alpha or c.a or 255)
end

local function gfx()
  return core and core.graphics or nil
end

local function safe(fn)
  pcall(fn)
end

----------------------------------------------------------------------
-- Symbol glyph rendering (2D screen space)
----------------------------------------------------------------------

--- Draw a symbol glyph centred at screen `center` (vec2) sized `size` px,
--- tinted `col` ({r,g,b,a} 0-255). `shape` is one of the rune shapes.
function M.draw_glyph(shape, center, size, col, opts)
  local g = gfx()
  if not g or not center then return end
  opts = opts or {}
  size = size or 24
  local cx = center.x or center[1] or 0
  local cy = center.y or center[2] or 0
  local r = size * 0.5
  local fill = color_of(col, opts.alpha or 255)
  local backdrop = color(0, 0, 0, math.floor((opts.alpha or 255) * 0.55))
  local outline = color(255, 255, 255, opts.alpha or 255)

  --- Dark disc behind the symbol for contrast on bright tilesets.
  if g.circle_2d_filled then
    safe(function() g.circle_2d_filled(v2(cx, cy), r + 2, backdrop) end)
  end

  if shape == "circle" then
    if g.circle_2d_filled then safe(function() g.circle_2d_filled(v2(cx, cy), r, fill) end) end
    if g.circle_2d then safe(function() g.circle_2d(v2(cx, cy), r, outline, 2) end) end

  elseif shape == "square" then
    if g.rect_2d_filled then safe(function() g.rect_2d_filled(v2(cx - r, cy - r), size, size, fill, 2) end) end
    if g.rect_2d then safe(function() g.rect_2d(v2(cx - r, cy - r), size, size, outline, 2, 2) end) end

  elseif shape == "diamond" then
    local top, right, bottom, left = v2(cx, cy - r), v2(cx + r, cy), v2(cx, cy + r), v2(cx - r, cy)
    if g.triangle_2d_filled then
      safe(function() g.triangle_2d_filled(top, right, bottom, fill) end)
      safe(function() g.triangle_2d_filled(top, left, bottom, fill) end)
    end
    if g.line_2d then
      safe(function() g.line_2d(top, right, outline, 2) end)
      safe(function() g.line_2d(right, bottom, outline, 2) end)
      safe(function() g.line_2d(bottom, left, outline, 2) end)
      safe(function() g.line_2d(left, top, outline, 2) end)
    end

  elseif shape == "triangle" then
    local top, bl, br = v2(cx, cy - r), v2(cx - r, cy + r), v2(cx + r, cy + r)
    if g.triangle_2d_filled then safe(function() g.triangle_2d_filled(top, bl, br, fill) end) end
    if g.line_2d then
      safe(function() g.line_2d(top, bl, outline, 2) end)
      safe(function() g.line_2d(bl, br, outline, 2) end)
      safe(function() g.line_2d(br, top, outline, 2) end)
    end

  elseif shape == "cross" then
    --- Thick X. Drawn with the fill colour so it reads as the red cross.
    local th = math.max(3, size * 0.18)
    if g.line_2d then
      safe(function() g.line_2d(v2(cx - r, cy - r), v2(cx + r, cy + r), fill, th) end)
      safe(function() g.line_2d(v2(cx - r, cy + r), v2(cx + r, cy - r), fill, th) end)
    end

  else
    --- Unknown shape: fall back to a filled disc so something still shows.
    if g.circle_2d_filled then safe(function() g.circle_2d_filled(v2(cx, cy), r, fill) end) end
  end

  --- Order number badge.
  if opts.number and g.text_2d then
    local label = tostring(opts.number)
    safe(function()
      g.text_2d(label, v2(cx - 3, cy - r - 16), 14, color(255, 255, 0, opts.alpha or 255))
    end)
  end

  --- Player name under the glyph.
  if opts.name and g.text_2d then
    safe(function()
      g.text_2d(tostring(opts.name), v2(cx - r, cy + r + 2), 12, color(230, 230, 230, opts.alpha or 220))
    end)
  end
end

----------------------------------------------------------------------
-- Real raid-target markers (opt-in, best-effort)
----------------------------------------------------------------------

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
  if res[1] then return res[2] end
  return nil
end

--- True when the SetRaidTarget global exists at all.
function M.markers_available()
  return g_fn("SetRaidTarget") ~= nil
end

--- Resolve a unit token ("raidN" / "partyN" / "player") for a player name so
--- SetRaidTarget can address them. Returns nil when no token matches.
local function token_for_name(name)
  if not name or name == "" then return nil end
  local UnitName = g_fn("UnitName")
  if not UnitName then return nil end

  local me = g_call("UnitName", "player")
  if me == name then return "player" end

  if g_call("IsInRaid") then
    for i = 1, 40 do
      local tok = "raid" .. i
      local ok, n = pcall(UnitName, tok)
      if ok and n == name then return tok end
    end
  else
    for i = 1, 4 do
      local tok = "party" .. i
      local ok, n = pcall(UnitName, tok)
      if ok and n == name then return tok end
    end
  end
  return nil
end

--- Set raid-target `index` (1-8, 0 clears) on the player named `name`.
function M.set_raid_marker(name, index)
  local fn = g_fn("SetRaidTarget")
  if not fn then return false end
  local tok = token_for_name(name)
  if not tok then return false end
  local ok = pcall(fn, tok, index or 0)
  return ok and true or false
end

--- Apply every slot's `marker` index to its assigned player. Returns count.
function M.apply(cfg, queue)
  if not cfg or not cfg.raidMarkers or not cfg.raidMarkers.enabled then return 0 end
  if not queue then return 0 end
  local n = 0
  for i = 1, #queue do
    local s = queue[i]
    if s.name and s.marker and M.set_raid_marker(s.name, s.marker) then
      n = n + 1
    end
  end
  return n
end

--- Clear the markers we set (index 0) on every assigned player.
function M.clear(cfg, queue)
  if not cfg or not cfg.raidMarkers or not cfg.raidMarkers.enabled then return end
  if not cfg.raidMarkers.clearOnReset then return end
  if not queue then return end
  for i = 1, #queue do
    local s = queue[i]
    if s.name then M.set_raid_marker(s.name, 0) end
  end
end

return M
