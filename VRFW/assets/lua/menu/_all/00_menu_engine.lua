-- menu_engine: the VRFW_Menu helper, defined in every script VM (lua\_all runs after each retail chunk).
-- It only defines a table: no engine call happens here (funcLuaCommand does not exist while a chunk loads).
--
-- The entries the mods declare with [[entry]] / [[hide]] (menu\*.toml, docs/app/menu-engine.md §8), for the Lua of
-- a host (title row, modes hub, Options, dock, bank popup, Sala del club). Inside OnInit / Step / any callback:
--   local list = VRFW_Menu.entries("title_menu_2.lower")   -- { {key, text, icon, kind, value, owner, value_id, menus}, ... }
--   if VRFW_Menu.hidden("title_menu_2.lower", "play_guide") then ... end
--   VRFW_Menu.run(e, open_menu)   -- kind "lua": calls the global function; "command": funcLuaCommand(value_id);
--                               -- "open_menu": open_menu(value) (the host passes how it opens a menu)
-- Without the menu engine (part off, old framework) every call answers "nothing declared".
if VRFW_Menu == nil and type(EvtMenu) == "table" then
  VRFW_Menu = EvtMenu   -- made by a 1.x copy of this file
end
if VRFW_Menu == nil then
  local H = { COUNT = 1063911870, ENTRY = 2768609349, HIDDEN = 3842910571 }

  VRFW_Menu = { H = H }

  function VRFW_Menu.entries(host)
    local out = {}
    local ok, n = pcall(funcLuaCommand, H.COUNT, host)
    if not ok or type(n) ~= "number" then return out end
    for i = 1, n do
      local key, text, icon, kind, value, owner, value_id, menus = funcLuaCommand(H.ENTRY, host, i)
      if key ~= nil then
        out[#out + 1] = { key = key, text = text, icon = icon, kind = kind, value = value, owner = owner, value_id = value_id,
                          menus = menus }
      end
    end
    return out
  end

  function VRFW_Menu.hidden(host, key)
    local ok, h = pcall(funcLuaCommand, H.HIDDEN, host, key)
    return ok and h == true
  end

  function VRFW_Menu.run(e, open_menu)
    if e == nil then return false end
    if e.kind == "lua" then
      local f = _G[e.value]
      if type(f) == "function" then f(e) return true end
    elseif e.kind == "command" then
      funcLuaCommand(e.value_id)
      return true
    elseif e.kind == "open_menu" and type(open_menu) == "function" then
      open_menu(e.value)
      return true
    end
    return false
  end
end
-- 1.x name (docs/framework/naming.md): the same table under the old name, so mods written for 1.x keep working
EvtMenu = VRFW_Menu
