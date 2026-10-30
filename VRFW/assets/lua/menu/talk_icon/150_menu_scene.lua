-- menu_scene (VR-Framework, docs/framework/menu-scene.md): while a menu scene's map loads and is up under the main menu
-- (game param vrfw_menu_scene_hud_off, set by setting_top_menu's 150_menu_scene.lua, cleared at the leave and by any
-- title without the scene) this field HUD menu keeps every layer it sets up / opens hidden: the field HUD draws above the
-- black cover of the settling field and would show over the map. Wraps the menu's own global functions (no host);
-- nothing runs at load time.
do
  local KEY = 3499142076 --[[crc32 vrfw_menu_scene_hud_off]]
  local VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE
  local MINIMAP = 1868910795 --[[0x6F6550CB: the field minimap shown / hidden]]
  local seen, logged = {}, false
  local function off()
    return VRFW_Param.Has(KEY)
  end
  local function hide(a1, a2)
    if a1 == nil or not off() then
      return
    end
    seen[a1 .. ":" .. tostring(a2 or 0)] = { a1, a2 or 0 }
    pcall(funcLuaMenuCommand, VISIBLE, a1, a2 or 0, false)
    if not logged then
      logged = true
      pcall(funcLuaCommand, MINIMAP, false)
      pcall(funcLuaCommand, VRFW_Cmd.EVT_LOG, "menu_scene", "talk_icon", "field HUD hidden under the menu scene (first layer", a1, ")")
    end
  end
  for _, name in ipairs({ "OnSetupLayer", "OnOpenLayer", "OnOpenEndLayer" }) do
    local f = _G[name]
    if type(f) == "function" then
      _G[name] = function(a1, a2, ...)
        local r = table.pack(f(a1, a2, ...))
        hide(a1, a2)
        return table.unpack(r, 1, r.n)
      end
    end
  end
  for _, name in ipairs({ "PostStep", "Step" }) do
    local f = _G[name]
    if type(f) == "function" then
      _G[name] = function(...)
        local r = table.pack(f(...))
        if next(seen) ~= nil and off() then
          for _, l in pairs(seen) do
            pcall(funcLuaMenuCommand, VISIBLE, l[1], l[2], false)
          end
        end
        return table.unpack(r, 1, r.n)
      end
      break
    end
  end
end
