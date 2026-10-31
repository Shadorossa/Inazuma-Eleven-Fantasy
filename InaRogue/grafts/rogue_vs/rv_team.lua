-- ===== EVT rogue vs BEGIN =====
-- vs_route_town_vs_team_menu in INAROGUE mode (docs/game/modes/inarogue.md §28; rv_common): the VS banner and the
-- player's formation. Left: the run's team (the VS dock of the INAROGUE save; its 5v5 team for a pachanga) with its
-- name, emblem and level; right: the node's rival (the game row's team, name and level from the run); the title plate
-- «INAROGUE · Fase N · <kind>»; «Empezar partido» closes both menus with evt_ir_vs_result = 1 and INAROGUE launches
-- the match (no retail «¿Empezar partido?» second window); Back = 0 (the map again). The retail chunk's locals (n..n8,
-- flag, flag2) are the Chronicle town event's; here they are set from the run (the assembler promotes them).
do
@COMMON@
  local evt_rv_init = OnInit
  function OnInit(...)
    if not EVT_RV.check() then
      return evt_rv_init(...)
    end
    n, n8 = 0, 0                          -- no town event (vs_route_town_menu is not open)
    n2 = EVT_RV.game
    n6 = EVT_RV.diff
    n7 = 5                                -- «gate battle»: IsChronicleBattle() is false = the player's own team (VS dock)
    local okT, team = funcLuaCommand(2204933160, n2, n6)   -- the game row's rival team at that difficulty
    n3 = (okT and type(team) == "number") and team or 0
    n4 = 0
    n5 = funcLuaCommand(@crc:CMND_GET_VS_USE_TEAM_SET@)
    local okF, form = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n5, EVT_RV.team, 4)
    if okF then
      OnInitFormationCommon(form, nil, n5, nil, false)
    end
    flag = false
    flag2 = false                         -- never 4138944672 (the Chronicle's «team for this game»): the run's team as it is
    EVT_RV.log("INAROGUE node", EVT_RV.node, "game", n2, "diff", n6, "kind", EVT_RV.kind, "rival team", n3,
               "rival", EVT_RV.rival, "level", EVT_RV.level, "vs set", n5, "team", EVT_RV.team)
  end

  local evt_rv_open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    local r = table.pack(evt_rv_open(a1, a2, ...))
    if EVT_RV.on then
      if a1 == 3443434246 --[[vsroute02_04_vs]] then
        funcLuaMenuCommand(558735651, a1, EVT_RV.CLASS_TEX, EVT_RV.CLASS[EVT_RV.kind] or EVT_RV.CLASS_DEFAULT,
                           EVT_RV.CLASS_NODE, 0, 0)
        if EVT_RV.rival ~= "" then
          funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 4019622434 --[[_text_team02]], EVT_RV.rival)
        end
        if n3 == 0 and EVT_RV.emblem ~= 0 then   -- no team row: the rival's emblem from the run
          funcLuaMenuCommand(3190452549, a1, 0, 799706978 --[[_icon_em_e_dmy01]], 1383164046 --[[icon_em_e_dmy01]], EVT_RV.emblem)
          funcLuaMenuCommand(3190452549, a1, 0, 3064192728 --[[_icon_em_e_dmy02]], 3413653812 --[[icon_em_e_dmy02]], EVT_RV.emblem)
        end
        if EVT_RV.level > 0 then                 -- the level the run gives the rival (the engine sets it at kick-off)
          for _, prim in ipairs({3038215778, 3097958688}) do
            local p = funcLuaMenuCommand(@crc:CMND_SEARCH_PRIM_INDEX@, a1, 0, prim)
            if p then
              funcLuaMenuCommand(3609943765, a1, 0, p, EVT_RV.level)
            end
          end
        end
      elseif a1 == 139522149 --[[vsroute02_03_gametitle]] then
        funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 3644612793 --[[_text_ch_title01]],
                           EVT_RV.tx(EVT_RV.T.TITLE, EVT_RV.phase, EVT_RV.kindText()))
      end
    end
    return table.unpack(r, 1, r.n)
  end

  -- a pachanga: the 5v5 team (team 1) of the VS dock; the retail function always draws team 0 (the 11v11)
  local evt_rv_formation = SetTeamDockFormation
  function SetTeamDockFormation(a1, a2, a3, a4)
    if not EVT_RV.on or EVT_RV.team == 0 then
      return evt_rv_formation(a1, a2, a3, a4)
    end
    local tm = EVT_RV.team
    local okF, form = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n5, tm, 4)
    if not okF then
      form = 0
    end
    SetAlwaysCardSizeSmallMode(false)
    local okK, kit = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n5, tm, 7)
    if not okK then
      kit = 0
    end
    local cc, lu, ru, ld, rd = 2654143900, 3984567298, 960402397, 2278526192, 1401860911   -- _pos_formation01_*
    local count = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, a2)
    local leader = false
    -- every card AND every blank slot (a3, team00_01_p1_chara_card_blank) starts hidden: retail never hides the blanks
    -- (11v11 fills every slot), so on the 5v5 the unused ones stayed on screen (Nacho 07/10: an empty frame under the
    -- MC, the 5 substitute frames at _pos_sub_atc01..05 and the support frames at _pos_support_atc01..03); only the
    -- slots of a drawn player are shown again below
    local blanks = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, a3)
    if type(blanks) ~= "number" or blanks < count then
      blanks = count
    end
    for i = 0, blanks - 1 do
      if i < count then
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a2, i, false)
      end
      if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, a3, i) == true then
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a3, i, false)
      end
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, a3, 0.85, 0.85, 1, i)
    end
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, a4, 0.85, 0.85, 1, 0)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, 2290394976 --[[team00_01_p1_chara_card_blank_for_leader]], 0.85, 0.85, 1, 0)
    for i = 0, 28 do
      local okH, hdl = funcLuaCommand(1720957768, n5, tm, i, 0)
      if okH then
        local okP, pos = funcLuaCommand(1720957768, n5, tm, i, 1)
        -- 5v5: positions 5..15 are the five's bench (the 5v5 field has 5 slots; drawn on it they piled up behind the
        -- MC, 2026-10-06): only the five, the managers and the coach are shown
        local bench5 = type(pos) == "number" and pos >= 5 and pos <= 15
        if okP and not (pos > 19) and not IsSoccerPosNo_Reserve(pos) and not bench5 then
          local okC, captain = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n5, tm, 8, hdl)
          if not okC then
            captain = false
          end
          local lv = funcLuaCommand(1131797651, hdl, 0)
          if pos == 19 then
            UpdateLeaderCharaByCharaStHdl(hdl, 1658289671 --[[team00_01_chara_card_for_leader]], 0, lv)
            leader = true
          else
            local okS, sub = funcLuaCommand(@crc:CMND_GET_SOCCER_FORMATION_INFO@, 6, form, pos)
            if not okS then
              sub = 0
            end
            funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a2, pos, true)
            funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a3, pos, true)
            local x, y = CalcFormationIconPosition(pos, form, 2, a1, cc, lu, ru, ld, rd, 60, 90, true, 0.85)
            x, y = x + -378, y + 533
            local okG, gk = funcLuaCommand(@crc:CMND_GET_SOCCER_FORMATION_INFO@, 5, form, pos)
            if okG and gk == 0 then
              y = y + 20
            end
            if pos >= 11 then
              SetAlwaysCardSizeSmallMode(true)
              UpdateMemberCharaIconInfoByChrStHdl(hdl, pos, form, 0, lv, false, a2, pos, nil, false, false, kit)
              x, y = 0, -15
              SetAlwaysCardSizeSmallMode(false)
            else
              UpdateMemberCharaIconInfoByChrStHdl(hdl, pos, form, 0, lv, captain, a2, pos, nil, true, true, kit)
            end
            funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, a2, x, y, 0, pos)
            funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, a3, x, y, 0, pos)
            for _, mesh in ipairs({2635558741, 69091055, 814224422, 2843821468}) do   -- _icon_card01/02, _icon_lock01/02
              funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, a2, mesh, false, pos)
            end
            funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, a2, 0.85, 0.85, 1, pos)
            funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, a3, 0.85, 0.85, 1, pos)
          end
        end
      end
    end
    if not leader then
      UpdateLeaderCharaByCharaStHdl(0, a4, 0, level)
    end
  end

  -- «Empezar partido»: the result for INAROGUE and both menus close (the match itself starts from the dock, §28)
  local evt_rv_decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if not EVT_RV.on then
      return evt_rv_decide(a1, a2, ...)
    end
    VRFW_Param.Replace(EVT_RV.KEY_RESULT, 1)
    funcLuaMenuCommand(1558704558, 831645521 --[[vs_route_town_vs_team_menu]], false)
    funcLuaMenuCommand(2171393651, 2296367164 --[[cmn05_01_cursor]], false)
    flag = true
    EVT_RV.log("Empezar partido: node", EVT_RV.node)
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, 747772244 --[[vs_route_town_vs_enemy_formation_menu]])
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, 831645521 --[[vs_route_town_vs_team_menu]])
  end

  -- the retail «restore the team» call when the screen closes without a decision pairs with 4138944672, which the
  -- INAROGUE mode never makes: skipped
  local evt_rv_close = OnCloseLayer
  function OnCloseLayer(a1, a2, ...)
    if EVT_RV.on and a1 == 3917524943 --[[vsroute02_05_my_formation_base]] then
      return
    end
    return evt_rv_close(a1, a2, ...)
  end

  local evt_rv_back = OnBack
  function OnBack(a1, ...)
    if EVT_RV.on then
      VRFW_Param.Replace(EVT_RV.KEY_RESULT, 0)
      EVT_RV.log("back: node", EVT_RV.node)
    end
    return evt_rv_back(a1, ...)
  end
end
-- ===== EVT rogue vs END =====
