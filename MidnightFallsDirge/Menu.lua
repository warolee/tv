--[[ MidnightFallsDirge — Menu: native Sylvanas toggles for the memory game.

     A single `core.menu.tree_node` ("Midnight Falls — Death's Dirge") holding
     checkboxes that mirror into `root.Config` every menu-render frame. Mirrors
     the pattern used by `ScienceAHBot/PSMenu.lua` and MMS `UI.lua`:
       * `core.menu.checkbox(default_bool, "stable_id")`
       * `checkbox:render("label")` inside `tree_node:render(title, fn)`
       * `checkbox:get_state()` to read.

     Everything is pcall-guarded and fails open (no menu API → Config keeps its
     file defaults). The announce channel itself stays Config-driven
     (`Config.chat.announceChannel`, default "AUTO") to avoid depending on the
     less-portable native combobox render signature. ]]

local M = {}

local function cb(default_bool, id)
  if not (core and core.menu and core.menu.checkbox) then return nil end
  local ok, el = pcall(core.menu.checkbox, default_bool and true or false, id)
  if ok then return el end
  return nil
end

local function get(el, fallback)
  if not el then return fallback end
  local ok, v = pcall(function()
    if el.get_state then return el:get_state() == true end
    if el.get then return el:get() == true end
    return fallback
  end)
  if ok then return v end
  return fallback
end

local function ensure_path(t, ...)
  for i = 1, select("#", ...) do
    local k = select(i, ...)
    t[k] = t[k] or {}
    t = t[k]
  end
  return t
end

local installed

function M.install(root)
  if installed then return end
  if not (core and core.menu and core.menu.tree_node and core.menu.checkbox
          and core.register_on_render_menu_callback) then
    return
  end
  installed = true

  local C = root.Config or {}
  root.Config = C

  local ok_tree, tree = pcall(core.menu.tree_node)
  local els = {
    tree     = ok_tree and tree or nil,
    enabled  = cb(C.enabled ~= false, "mfd_enabled_v1"),
    overlay  = cb((C.overlay or {}).enabled ~= false, "mfd_overlay_v1"),
    head     = cb((C.headIcons or {}).enabled ~= false, "mfd_head_icons_v1"),
    markers  = cb((C.raidMarkers or {}).enabled == true, "mfd_raid_markers_v1"),
    announce = cb((C.chat or {}).announce ~= false, "mfd_chat_announce_v1"),
    whisper  = cb((C.chat or {}).whisper ~= false, "mfd_chat_whisper_v1"),
    sound    = cb((C.sound or {}).enabled ~= false, "mfd_sound_v1"),
  }
  root._mfd_menu = els

  local function sync()
    C.enabled = get(els.enabled, C.enabled ~= false)
    ensure_path(C, "overlay").enabled     = get(els.overlay, true)
    ensure_path(C, "headIcons").enabled   = get(els.head, true)
    ensure_path(C, "raidMarkers").enabled = get(els.markers, false)
    local chat = ensure_path(C, "chat")
    chat.announce = get(els.announce, true)
    chat.whisper  = get(els.whisper, true)
    ensure_path(C, "sound").enabled = get(els.sound, true)
  end

  pcall(function()
    core.register_on_render_menu_callback(function()
      pcall(function()
        if not els.tree then return end
        els.tree:render("Midnight Falls — Death's Dirge", function()
          if els.enabled then els.enabled:render("Enable tracker (master)") end
          if els.overlay then els.overlay:render("Show sequence overlay (HUD)") end
          if els.head then els.head:render("Show symbol icons above players") end
          if els.markers then els.markers:render("Set real raid-target markers (needs assist)") end
          if els.announce then els.announce:render("Announce order in chat") end
          if els.whisper then els.whisper:render("Whisper each player their symbol") end
          if els.sound then els.sound:render("Play sound on new sequence") end
        end)
        sync()
      end)
    end)
  end)
end

return M
