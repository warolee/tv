--[[ MythicMechanicsSuite — Palette: preset definitions and helpers.

     Presets are shipped as immutable RGBA tables and applied to
     `root.Config.colors` on demand. Any color the user edits via the
     Appearance tab's per-channel sliders auto-flips the preset name
     to "custom" so the combobox correctly reflects "I'm no longer on
     a stock preset". ]]

local M = {}

--- The 7 colors the Appearance UI exposes for editing. Each preset
--- defines exactly these keys; other palette entries (cone, line,
--- safe, text, textShadow) keep their Config.lua defaults and are
--- not touched by presets.
M.EDITABLE_KEYS = { "danger", "warning", "info", "soak", "dropoff", "spread", "stack" }

M.PRESETS = {
  ----------------------------------------------------------------
  -- default: the original palette shipped in Config.lua.
  ----------------------------------------------------------------
  default = {
    danger  = { r = 235, g =  60, b =  60, a = 235 },
    warning = { r = 255, g = 200, b =  60, a = 235 },
    info    = { r =  80, g = 180, b = 255, a = 235 },
    soak    = { r =  80, g = 180, b = 255, a = 235 },
    dropoff = { r = 255, g = 200, b =  60, a = 235 },
    spread  = { r = 235, g = 130, b = 255, a = 235 },
    stack   = { r =  90, g = 220, b = 120, a = 235 },
  },

  ----------------------------------------------------------------
  -- colorblind: deuteranopia-friendly. Avoids red/green ambiguity
  -- by leaning on blue / orange / yellow, which the most common
  -- forms of color vision deficiency can distinguish reliably.
  ----------------------------------------------------------------
  colorblind = {
    danger  = { r =   0, g =  90, b = 200, a = 235 },  -- deep blue
    warning = { r = 230, g = 130, b =   0, a = 235 },  -- orange
    info    = { r = 240, g = 220, b =  90, a = 235 },  -- pale yellow
    soak    = { r = 240, g = 220, b =  90, a = 235 },
    dropoff = { r = 230, g = 130, b =   0, a = 235 },
    spread  = { r = 200, g = 100, b = 200, a = 235 },
    stack   = { r = 100, g = 200, b = 100, a = 235 },
  },

  ----------------------------------------------------------------
  -- high_contrast: pure-saturation primaries with max alpha. Best
  -- on dark tilesets / nighttime zones where dim palettes wash out.
  ----------------------------------------------------------------
  high_contrast = {
    danger  = { r = 255, g =   0, b =   0, a = 255 },
    warning = { r = 255, g = 255, b =   0, a = 255 },
    info    = { r =   0, g = 255, b = 255, a = 255 },
    soak    = { r =   0, g = 255, b = 255, a = 255 },
    dropoff = { r = 255, g = 255, b =   0, a = 255 },
    spread  = { r = 255, g =   0, b = 255, a = 255 },
    stack   = { r =   0, g = 255, b =   0, a = 255 },
  },

  ----------------------------------------------------------------
  -- neon: vibrant cyberpunk palette — useful for streaming / video
  -- captures where stock red disappears against character glows.
  ----------------------------------------------------------------
  neon = {
    danger  = { r = 255, g =  50, b = 150, a = 235 },  -- hot pink
    warning = { r = 255, g = 220, b =  50, a = 235 },
    info    = { r = 100, g = 220, b = 255, a = 235 },
    soak    = { r =  50, g = 255, b = 255, a = 235 },
    dropoff = { r = 255, g = 180, b =  50, a = 235 },
    spread  = { r = 200, g =  50, b = 255, a = 235 },
    stack   = { r =  50, g = 255, b = 150, a = 235 },
  },
}

--- Ordered list for the combobox. "custom" goes last so the user
--- can never *pick* it (it's an output state, not an input). The UI
--- listens for changes and forces it back to "custom" the moment any
--- per-color slider deviates from the active preset.
M.PRESET_ORDER = { "default", "colorblind", "high_contrast", "neon", "custom" }

function M.preset_index(name)
  for i, n in ipairs(M.PRESET_ORDER) do
    if n == name then return i - 1 end
  end
  return 0 -- default
end

function M.preset_from_index(i)
  if type(i) ~= "number" then return "default" end
  return M.PRESET_ORDER[i + 1] or "default"
end

function M.preset_options()
  --- Friendly labels for the combobox `options` array (in PRESET_ORDER).
  return { "Default", "Colorblind", "High contrast", "Neon", "(custom)" }
end

local function copy_rgba(c)
  return { r = c.r or 255, g = c.g or 255, b = c.b or 255, a = c.a or 255 }
end

--- Overwrite the editable keys of `root.Config.colors` with the
--- preset values. Other palette entries (cone, line, safe, text,
--- textShadow) are NOT touched — they remain at their Config.lua
--- defaults or whatever the user last set them to. Sets
--- `Config.appearance.preset` to `name` on success.
function M.apply_preset(root, name)
  local p = M.PRESETS[name]
  if not p then return false end
  local cfg = root and root.Config
  if type(cfg) ~= "table" then return false end
  cfg.colors = cfg.colors or {}
  for _, key in ipairs(M.EDITABLE_KEYS) do
    if p[key] then
      cfg.colors[key] = copy_rgba(p[key])
    end
  end
  cfg.appearance = cfg.appearance or {}
  cfg.appearance.preset = name
  return true
end

--- Returns `true` when every editable color in `Config.colors`
--- exactly matches the named preset. Used to flip the combobox
--- back to "custom" the moment a slider edits any channel.
function M.matches_preset(root, name)
  local p = M.PRESETS[name]
  local cfg = root and root.Config
  if not p or type(cfg) ~= "table" or type(cfg.colors) ~= "table" then
    return false
  end
  for _, key in ipairs(M.EDITABLE_KEYS) do
    local pc = p[key]
    local cc = cfg.colors[key]
    if type(cc) ~= "table" then return false end
    if (cc.r or 0) ~= (pc.r or 0) then return false end
    if (cc.g or 0) ~= (pc.g or 0) then return false end
    if (cc.b or 0) ~= (pc.b or 0) then return false end
    --- Alpha intentionally NOT compared: globalAlphaMult is the
    --- "I tweaked transparency" knob; preset matching is purely
    --- about RGB identity.
  end
  return true
end

--- Best-effort preset name resolution. Returns the first preset whose
--- RGBs match, or "custom" if none do.
function M.resolve_preset_name(root)
  for _, name in ipairs(M.PRESET_ORDER) do
    if name ~= "custom" and M.matches_preset(root, name) then
      return name
    end
  end
  return "custom"
end

return M
