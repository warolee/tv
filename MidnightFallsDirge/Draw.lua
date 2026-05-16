--[[ MidnightFallsDirge — Draw: thin wrapper over `core.graphics` (bundled copy).

     Every primitive is wrapped in `Util.try` so a single bad draw call
     (e.g. a vec3 that turned into nil because an enemy unit despawned
     mid-frame) cannot kill the render thread for the whole plugin.

     The wrappers prefer the native 3D primitives when the running
     Sylvanas build exposes them (`circle_3d_filled`, `line_3d`,
     `text_3d`) and fall back to projecting world points to screen via
     `core.graphics.w2s` + the 2D primitives when they don't. ]]

local M = {}

local Util = require("Util")
local Geom = require("Geometry")

local ok_color, color_lib = pcall(require, "common/color")

--- Build a color object compatible with `core.graphics.*`. We accept
--- both `{ r, g, b, a }` tables and `{ r=..., g=..., b=..., a=...}`.
function M.color(c)
  if type(c) ~= "table" then
    c = { r = 255, g = 255, b = 255, a = 255 }
  end
  local r = c.r or c[1] or 255
  local g = c.g or c[2] or 255
  local b = c.b or c[3] or 255
  local a = c.a or c[4] or 255
  if ok_color and color_lib then
    local ok, made = pcall(function()
      if color_lib.new then return color_lib.new(r, g, b, a) end
      if color_lib.rgba then return color_lib.rgba(r, g, b, a) end
      return color_lib(r, g, b, a)
    end)
    if ok and made then return made end
  end
  return { r = r, g = g, b = b, a = a }
end

local function get_graphics()
  return core and core.graphics or nil
end

--- 3D danger / safe circle on the ground.
function M.circle_3d(center, radius, color_in, thickness, segments, filled, fill_alpha)
  local g = get_graphics()
  if not g then return end
  local col = M.color(color_in)
  Util.try("Draw.circle_3d", function()
    local segs = math.max(8, math.floor(segments or 36))
    if filled and g.circle_3d_filled then
      local fill = M.color({
        r = (color_in and color_in.r) or 255,
        g = (color_in and color_in.g) or 255,
        b = (color_in and color_in.b) or 255,
        a = fill_alpha or 50,
      })
      g.circle_3d_filled(center, radius, fill, segs)
    end
    if g.circle_3d then
      g.circle_3d(center, radius, col, thickness or 2.5, segs)
      return
    end
    --- Fallback: line strip
    if g.line_3d then
      local pts = Geom.circle_points(center, radius, segs)
      for i = 1, #pts - 1 do
        g.line_3d(pts[i], pts[i + 1], col, thickness or 2.5)
      end
    end
  end)
end

--- 3D ground line between two world points (used for laser beams).
function M.line_3d(a, b, color_in, thickness)
  local g = get_graphics()
  if not g or not g.line_3d then return end
  local col = M.color(color_in)
  Util.try("Draw.line_3d", function()
    g.line_3d(a, b, col, thickness or 2.5)
  end)
end

--- Filled "beam" rectangle on the ground from origin yards forward in
--- heading `yaw`, with `length` and `width`. Drawn as two parallel
--- lines + the central axis so it reads clearly even when partly
--- obscured by terrain.
function M.beam_3d(origin, yaw, length, width, color_in, thickness)
  local g = get_graphics()
  if not g then return end
  local col = M.color(color_in)
  Util.try("Draw.beam_3d", function()
    local left_yaw = (yaw or 0) + math.pi * 0.5
    local right_yaw = (yaw or 0) - math.pi * 0.5
    local half = (width or 4) * 0.5
    local o_l = Geom.advance(origin, left_yaw, half)
    local o_r = Geom.advance(origin, right_yaw, half)
    local f_l = Geom.advance(o_l, yaw or 0, length or 30)
    local f_r = Geom.advance(o_r, yaw or 0, length or 30)
    local center_f = Geom.advance(origin, yaw or 0, length or 30)
    if g.line_3d then
      g.line_3d(o_l, f_l, col, thickness or 2.5)
      g.line_3d(o_r, f_r, col, thickness or 2.5)
      g.line_3d(o_l, o_r, col, thickness or 2.0)
      g.line_3d(f_l, f_r, col, thickness or 2.0)
      g.line_3d(origin, center_f, col, (thickness or 2.5) * 0.6)
    end
  end)
end

--- 3D cone fan (frontal cleave / breath). Falls back to two edge lines
--- + an arc of points when the build has no triangle-fan primitive.
function M.cone_3d(tip, yaw, length, width_rad, color_in, thickness, segments, filled)
  local g = get_graphics()
  if not g then return end
  local col = M.color(color_in)
  Util.try("Draw.cone_3d", function()
    local pts = Geom.cone_points(tip, yaw or 0, length or 20, width_rad or math.pi * 0.5, segments or 18)
    if not g.line_3d then return end
    g.line_3d(pts[1], pts[2], col, thickness or 2.5)
    g.line_3d(pts[1], pts[#pts], col, thickness or 2.5)
    for i = 2, #pts - 1 do
      g.line_3d(pts[i], pts[i + 1], col, thickness or 2.0)
    end
    if filled and g.triangle_3d_filled then
      local fill = M.color({ r = col.r, g = col.g, b = col.b, a = 60 })
      for i = 2, #pts - 1 do
        g.triangle_3d_filled(pts[1], pts[i], pts[i + 1], fill)
      end
    end
  end)
end

--- 3D text floating above a world position.
function M.text_3d(text, pos, size, color_in, centered)
  local g = get_graphics()
  if not g then return end
  local col = M.color(color_in)
  Util.try("Draw.text_3d", function()
    if g.text_3d then
      g.text_3d(tostring(text), pos, size or 16, col, centered ~= false)
      return
    end
    --- Fallback: project then write 2D
    if not g.w2s or not g.text_2d then return end
    local p2 = g.w2s(pos)
    if not p2 then return end
    g.text_2d(tostring(text), p2, size or 16, col)
  end)
end

--- 2D HUD text (always-on-top alert at a fixed screen position).
function M.text_2d(text, pos, size, color_in)
  local g = get_graphics()
  if not g or not g.text_2d then return end
  local col = M.color(color_in)
  Util.try("Draw.text_2d", function()
    g.text_2d(tostring(text), pos, size or 16, col)
  end)
end

function M.rect_2d_filled(pos, w, h, color_in, rounding)
  local g = get_graphics()
  if not g or not g.rect_2d_filled then return end
  Util.try("Draw.rect_2d_filled", function()
    g.rect_2d_filled(pos, w, h, M.color(color_in), rounding or 0)
  end)
end

function M.rect_2d(pos, w, h, color_in, thickness, rounding)
  local g = get_graphics()
  if not g or not g.rect_2d then return end
  Util.try("Draw.rect_2d", function()
    g.rect_2d(pos, w, h, M.color(color_in), thickness or 1, rounding or 0)
  end)
end

return M
