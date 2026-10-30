-- VRFW menu events: a menu script sends a named event with a payload, and every other menu script subscribed to that
-- name receives it at once (docs/framework/menu-event.md). Menu scripts run in separate Lua states (a menu's layer
-- groups can each have their own script), so one script's globals are not visible to another; the framework calls
-- the receiver's VRFW_MenuEventDeliver directly (CMND_VRFW_MENU_EVENT*).
--   VRFW_MenuEvent.On(name, menu, owner, fn)  -- in OnInit or later: fn(...) runs on every `name` event of another
--                                             -- script while menu `menu` (its name hash) is open; owner = a name
--                                             -- unique to this script (its stem); ends on this script's FinalizeMenu
--   VRFW_MenuEvent.Off(owner)                 -- every subscription of owner ends (FinalizeMenu does it)
--   VRFW_MenuEvent.Emit(name, ...)            -- -> scripts reached; numbers, strings and booleans
-- No engine call at load time.
VRFW_MenuEvent = VRFW_MenuEvent or {handlers = {}, owners = {}}
do
  local E = VRFW_MenuEvent
  E.CMD = {EVENT = VRFW_Cmd.VRFW_MENU_EVENT, ON = VRFW_Cmd.VRFW_MENU_EVENT_ON,
    OFF = VRFW_Cmd.VRFW_MENU_EVENT_OFF}

  function E.On(name, menu, owner, fn)
    E.handlers[name] = fn
    E.owners[owner] = true
    local ok, r = pcall(funcLuaCommand, E.CMD.ON, name, menu, owner)
    if not E.finalize_wrapped then
      E.finalize_wrapped = true
      local game_finalize = FinalizeMenu
      function FinalizeMenu(...)
        for o in pairs(E.owners) do
          pcall(funcLuaCommand, E.CMD.OFF, o)
        end
        E.owners = {}
        if type(game_finalize) == "function" then
          return game_finalize(...)
        end
      end
    end
    return ok and r == true
  end

  function E.Off(owner)
    E.owners[owner] = nil
    pcall(funcLuaCommand, E.CMD.OFF, owner)
  end

  function E.Emit(name, ...)
    local ok, n = pcall(funcLuaCommand, E.CMD.EVENT, name, ...)
    return ok and tonumber(n) or 0
  end
end

-- called by the framework in this script's state for an event it subscribed to
function VRFW_MenuEventDeliver(name, ...)
  local fn = VRFW_MenuEvent.handlers[name]
  if type(fn) == "function" then
    fn(...)
  end
end
