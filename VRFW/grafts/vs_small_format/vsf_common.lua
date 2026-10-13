  -- VRFW vs small format: shared helpers (both VS menus run in their own Lua state; definitions only)
  VRFW_VSF = VRFW_VSF or {}
  VRFW_VSF.LOG = 3661580131                 -- CMND_EVT_LOG (loader log; pcall: absent without the Lua bridge)
  VRFW_VSF.SLOTS = 19                       -- card slots: 0-10 field, 11-15 bench, 16-18 support (19 = coach layer)
  VRFW_VSF.COACH = 19
  VRFW_VSF.LEADER_BLANK = 2290394976        -- team00_01_p1_chara_card_blank_for_leader
  function VRFW_VSF.log(...)
    pcall(funcLuaCommand, VRFW_VSF.LOG, "vs small format:", ...)
  end
  local function hide(layer, i)
    if type(layer) == "number" and funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER?]], layer, i) == true then
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, false)
    end
  end
  -- used: {[position] = true} of the drawn team's members (positions as the retail screen draws them). Fewer than 11
  -- field members = a small format: hide every card + blank frame without a member, and the coach card + frame when
  -- the team has no coach. 11 field members (or none read): the retail screen as it is.
  function VRFW_VSF.Apply(used, cards, blanks, leader, leader_blank, where)
    local field = 0
    for p = 0, 10 do
      if used[p] then
        field = field + 1
      end
    end
    if field == 0 or field >= 11 then
      return
    end
    local n = VRFW_VSF.SLOTS
    local made = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], blanks)
    if type(made) == "number" and made > n then
      n = made
    end
    local hidden = 0
    for i = 0, n - 1 do
      if not used[i] then
        hide(cards, i)
        hide(blanks, i)
        hidden = hidden + 1
      end
    end
    local coach = used[VRFW_VSF.COACH] == true
    if not coach then
      hide(leader, 0)
      hide(leader_blank or VRFW_VSF.LEADER_BLANK, 0)
    end
    VRFW_VSF.log(where, "field members", field, "empty slots hidden", hidden, "coach", coach and "shown" or "hidden")
  end
