-- EVT rogue_coaches (docs/game/modes/inarogue.md «Entrenadores»): the coach selector before a NEW run, and the run
-- coach's start items. Appended at the END of evt_inarogue_menu (graft rogue_coaches), so the menu's top-level locals
-- (NewRun, OpenChild, Call, Int, Log, Message, C) are in scope: NewRun is a local function the menu's
-- «Empezar» / «Nueva partida» call through its upvalue, so assigning it here wraps both. Nothing here calls the engine
-- at load time.
do
  local CO = {
    MENU = 3869270721,           -- evt_rogue_coach_menu (research/grafts/rogue_coaches/evt_rogue_coach_menu.lua)
    KEY = 123230196,             -- parameter: 1 picked, 0 back (9 = the screen never opened)
    LIST = @crc:CMND_EVT_RL_COACH_LIST@,           -- CMND_EVT_RL_COACH_LIST (-1) -> count, runIndex, pickIndex, enabled
    ITEMS = @crc:CMND_EVT_RL_COACH_ITEMS@,          -- CMND_EVT_RL_COACH_ITEMS () -> n, key1, id1, count1, ...
    REG_FIND = @crc:CMND_VRFW_REG_FIND@,       -- CMND_VRFW_REG_FIND ("item", key) -> id
    ADD_ITEM = @crc:CMND_ADD_ITEM_ONLY@,       -- CMND_ADD_ITEM_ONLY (item, n, window)
    MISSING = {2821920169 --[[InaRogue.coach.missing]]},   -- the screen evt_rogue_coach_menu is not installed
  }

  -- the run coach's start items (once per run; the loader marks them given)
  function EVT_CO_GiveStartItems()
    local r = table.pack(pcall(funcLuaCommand, CO.ITEMS))
    if not r[1] or type(r[2]) ~= "number" or r[2] <= 0 then
      return 0
    end
    local given = 0
    for k = 0, r[2] - 1 do
      local key, id, n = r[3 + k * 3], r[4 + k * 3], r[5 + k * 3]
      if type(key) == "string" and key ~= "" then
        local got = Call(CO.REG_FIND, "item", key)
        if type(got) == "number" and got > 0 then
          id = got
        end
      end
      if type(id) == "number" and id > 0 then
        Call(CO.ADD_ITEM, id, Int(n), false)
        given = given + 1
      end
      Log("coach start item", tostring(key), tostring(id), "x", Int(n))
    end
    return given
  end

  if type(NewRun) == "function" then
    local prev = NewRun
    NewRun = function(...)
      local n, _, _, enabled = Call(CO.LIST, -1)
      if enabled == true and Int(n) > 0 then
        VRFW_Param.Clear(CO.KEY)
        VRFW_Param.Set(CO.KEY, 9)
        OpenChild(CO.MENU, T(CO.MISSING))
        local r = Int(VRFW_Param.Get(CO.KEY))
        VRFW_Param.Clear(CO.KEY)
        Log("coach selector result", r)
        if r == 0 then
          return                     -- Atrás: no new run
        end
      end
      return prev(...)
    end
  end

  -- the start items reach the bag before the route map opens (also a run started later from the team dock)
  if type(IRM_OpenMap) == "function" then
    local prev = IRM_OpenMap
    function IRM_OpenMap(...)
      EVT_CO_GiveStartItems()
      return prev(...)
    end
  end
end
