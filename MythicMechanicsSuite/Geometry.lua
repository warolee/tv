--[[ MythicMechanicsSuite — Geometry helpers.

     Project Sylvanas exposes the standard `common/geometry/vector_2`
     and `common/geometry/vector_3` modules. We try them first and fall
     back to plain `{ x, y, z }` tables so unit tests / static analysis
     can run outside Sylvanas. Every helper here is pure and stateless. ]]

local M = {}

local ok_vec2, vec2 = pcall(require, "common/geometry/vector_2")
local ok_vec3, vec3 = pcall(require, "common/geometry/vector_3")

local HAVE_VEC2 = ok_vec2 and type(vec2) == "table" and (vec2.new ~= nil or getmetatable(vec2) ~= nil)
local HAVE_VEC3 = ok_vec3 and type(vec3) == "table" and (vec3.new ~= nil or getmetatable(vec3) ~= nil)

--- Construct a 2D vector in the API the loaded build expects.
function M.V2(x, y)
  if HAVE_VEC2 then
    local ok, v = pcall(function()
      if vec2.new then return vec2.new(x, y) end
      return vec2(x, y)
    end)
    if ok and v then return v end
  end
  return { x = x or 0, y = y or 0 }
end

--- Construct a 3D vector. Sylvanas world positions are in game yards.
function M.V3(x, y, z)
  if HAVE_VEC3 then
    local ok, v = pcall(function()
      if vec3.new then return vec3.new(x, y, z) end
      return vec3(x, y, z)
    end)
    if ok and v then return v end
  end
  return { x = x or 0, y = y or 0, z = z or 0 }
end

--- Read x/y/z off either a vec3 userdata or a plain Lua table.
function M.xyz(v)
  if type(v) ~= "table" and type(v) ~= "userdata" then
    return 0, 0, 0
  end
  local x = v.x or v[1] or 0
  local y = v.y or v[2] or 0
  local z = v.z or v[3] or 0
  return x, y, z
end

function M.dist2(a, b)
  local ax, ay, az = M.xyz(a)
  local bx, by, bz = M.xyz(b)
  local dx, dy, dz = ax - bx, ay - by, az - bz
  return dx * dx + dy * dy + dz * dz
end

function M.dist(a, b)
  return math.sqrt(M.dist2(a, b))
end

--- Horizontal (XY plane) distance, ignoring Z. Most WoW mechanic radii
--- are evaluated horizontally regardless of small Z deltas (ramps,
--- platforms), so this matches what the boss script actually does.
function M.dist_xy(a, b)
  local ax, ay = M.xyz(a)
  local bx, by = M.xyz(b)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

--- Add `dist` yards in heading `yaw` (radians) from origin `o`. Returns
--- a new vec3 in the same flavor as `M.V3`.
function M.advance(o, yaw, dist)
  local ox, oy, oz = M.xyz(o)
  local x = ox + math.cos(yaw) * dist
  local y = oy + math.sin(yaw) * dist
  return M.V3(x, y, oz)
end

--- Build a circle of N evenly spaced vec3 samples around `center` at
--- the given horizontal `radius`. Used by Draw.lua to render fallback
--- circles when `core.graphics.circle_3d` is unavailable.
function M.circle_points(center, radius, segments)
  local n = math.max(8, math.floor(segments or 36))
  local pts = {}
  local cx, cy, cz = M.xyz(center)
  local two_pi = math.pi * 2
  for i = 0, n - 1 do
    local a = (i / n) * two_pi
    pts[#pts + 1] = M.V3(cx + math.cos(a) * radius, cy + math.sin(a) * radius, cz)
  end
  pts[#pts + 1] = pts[1]
  return pts
end

--- Cone "fan" mesh: returns a list of vec3 points in order
--- { tip, edgeL, arc1, arc2, ..., edgeR } so the renderer can fill it
--- as a triangle fan rooted at `tip`. `width_rad` is the full angular
--- width (e.g. 90deg → math.pi/2).
function M.cone_points(tip, yaw, length, width_rad, segments)
  local n = math.max(4, math.floor(segments or 18))
  local half = (width_rad or math.pi * 0.5) * 0.5
  local pts = { tip }
  for i = 0, n do
    local a = yaw - half + (i / n) * (half * 2)
    pts[#pts + 1] = M.advance(tip, a, length)
  end
  return pts
end

--- True when `pt` is inside the circle of horizontal `radius` around
--- `center`. Used by mechanics that just want to know whether the
--- local player is in/out of a danger zone (to colour the warning or
--- play a sound).
function M.in_circle(pt, center, radius)
  return M.dist_xy(pt, center) <= (radius or 0)
end

--- True when `pt` is inside the cone defined by `tip`, heading `yaw`,
--- length `len`, full angle `width_rad`.
function M.in_cone(pt, tip, yaw, len, width_rad)
  local dx = (pt.x or 0) - (tip.x or 0)
  local dy = (pt.y or 0) - (tip.y or 0)
  local d2 = dx * dx + dy * dy
  if d2 > (len or 0) * (len or 0) then
    return false
  end
  local pa = math.atan2 and math.atan2(dy, dx) or math.atan(dy / (dx == 0 and 1e-9 or dx))
  local diff = pa - (yaw or 0)
  while diff > math.pi do diff = diff - 2 * math.pi end
  while diff < -math.pi do diff = diff + 2 * math.pi end
  return math.abs(diff) <= (width_rad or 0) * 0.5
end

return M
