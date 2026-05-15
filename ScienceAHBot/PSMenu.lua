--[[ Project Sylvanas native menu: master automation toggle + Astro window visibility.

     Uses core.menu.tree_node + checkbox render (see astro_custom_ui readme).
     Master checkbox persists via its menu element id. ]]

-- module-local, returned as the public interface
local M = {}

local Util = require("Util")

--- When no menu API / checkbox, automation is allowed (fail-open).
---@param root table
---@return boolean
function M.is_master_enabled(root)
  local cb = root and root._ps_master_enable
  if not cb then
    return true
  end
  local ok, on = pcall(function()
    if cb.get_state then
      return cb:get_state() == true
    end
    if cb.get then
      return cb:get() == true
    end
    return true
  end)
  return ok and on == true
end

--- Renders the Science AH Bot tree in the Sylvanas scripts menu and wires `ui:on_menu_render`.
---@param root table
function M.install(root)
  if root._science_ps_menu_installed then
    return
  end
  if not (core and core.menu and core.menu.tree_node and core.menu.checkbox and core.register_on_render_menu_callback) then
    return
  end

  root._science_ps_menu_installed = true

  local ok_tree, tree = pcall(function()
    return core.menu.tree_node()
  end)
  local ok_master, master = pcall(function()
    return core.menu.checkbox(true, "science_ah_bot_ps_master_v1")
  end)
  if ok_tree and tree then
    root._ps_tree = tree
  end
  if ok_master and master then
    root._ps_master_enable = master
  end

  pcall(function()
    core.register_on_render_menu_callback(function()
      Util.safe_call(
        "PSMenu.on_render_menu",
        function()
          local ui = root._astro_ui
          if ui and ui.on_menu_render then
            ui:on_menu_render()
          end
          if root._ps_tree and root._ps_master_enable then
            root._ps_tree:render("Science AH Bot", function()
              root._ps_master_enable:render("Enable bot automation (master)")
              if ui and ui.menu and ui.menu.enable then
                ui.menu.enable:render("Show settings window")
              end
            end)
          end
        end,
        { root = root }
      )
    end)
  end)
end

return M
