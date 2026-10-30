-- ===================================================================================================
-- v5 (2026-09-24, user): the custom-passive picker has the look of the board's own list picker (what a move row /
-- the board's six-sense piece opens): the retail list frame (team05_03, layer evt_ss_list, no native list view) with
-- 7 retail list rows (team08_02_ability_list_item: six-sense icon, name, equipped / owned counts, check mark on the
-- equipped one) over the left column; the focused item is shown on the right in the integrated panel. Up/down
-- (scrolls), Aceptar = equip (CMND_CHARACTERREFORGED_SIX_SENSE after a free-copy check), back = close. Last row "Quitar".
-- ===================================================================================================
PL.L_SSLIST = 535021373
PL.L_SSROW = 1205526439                         -- team08_02_ability_list_item
PL.SSROWS = 9                                   -- v8: 9 rows as the retail list (mViewNum 9)
-- v7 (2026-09-24, user: rows without a proper base, blue / washed-out names, tiny grey icons): drawn as the retail list
-- view draws a team08_02 row: focused row = the blue base (_list_base_xs01_on) with the "on" text style, the others =
-- the white base (_off) with the "off" text style; only ONE of the two text nodes is visible (both were drawn over
-- each other). Icons as the retail UpdateListItem draws a six-sense piece: the six-sense hexagon icon_abilear_sixth01
-- (icon_common, 50 px) on _icon_sp_area_dmy01 and the passive's own board icon (GetAbilearBoardTeamPassiveIconTexture,
-- icon_abilearboard, 38 px) on _icon_sixth_dmy01. Layout: our narrowed clone of the row (ss2_build, 40 .. 944).
PL.SSROW_BASE_ON = 2334302522                   -- _list_base_xs01_on (blue: focused)
PL.SSROW_BASE_OFF = 2022529787                  -- _list_base_xs01_off (white)
PL.SSROW_TEXT_ON = 931545948                    -- _text_list01_on
PL.SSROW_TEXT_OFF = 3705682548                  -- _text_list01_off
PL.SSROW_HIDE = {1697431574 --[[_list_base_xs01_ol]], 4215821749 --[[_list_base_xs01_ok]], 2172872396 --[[_icon_cmd_type_base01]],
  1255155594 --[[_icon_cmd_type_dmy01]]}

function PL.SSRowIcons(L, k, id)
  local isitem = id ~= 0
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260 --[[_icon_sp_area_dmy01]], isitem, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2384755812 --[[_icon_sixth_dmy01]], isitem, k)
  if not isitem then
    return
  end
  funcLuaMenuCommand(C.SPRITE, L, 502529699 --[[icon_common <LG>]], 487860482 --[[icon_abilear_sixth01]],
    566439826 --[[icon_sp_area_dmy01]], 0, k)
  local tex, spr = nil, nil
  if GetAbilearBoardTeamPassiveIconTexture ~= nil then
    local info = funcLuaCommand(@crc:CMND_GET_PASSIVE_SKILL_INFO@, 0, id)
    local ok, s = pcall(GetAbilearBoardTeamPassiveIconTexture, info, true)
    if ok and s ~= nil and s ~= 0 then
      tex, spr = 3315424508 --[[icon_abilearboard <LG>]], s
    end
  end
  if tex == nil then
    tex, spr = EVT_SS_Icon(id)
  end
  funcLuaMenuCommand(C.SPRITE, L, tex, spr, 669321680 --[[icon_sixth_dmy01]], 0, k)
end

-- 2026-09-30 (Nacho: «Pasiva personalizada No.1…6» rows with «0 / 801» counters looked like a debug list): the row
-- says what the passive DOES (its effect text, 2 lines; the item name «Pasiva personalizada No.N» is the same for all
-- 37 and stays in the retail detail window on the right), and the two retail counters are gone. They were the stack
-- counts of the retail list: num_equip01 = copies of that item equipped by the team (0), num_have01 = copies owned
-- (801). Only the retail check mark on the one this player wears remains, as the plate PASIVAS rows show.
function PL.SSRow(k, e, selected)
  local L = PL.L_SSROW
  PL.RowFull(L, k)
  for _, m in ipairs(PL.SSROW_HIDE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, k)
  end
  local text = (type(e.text) == "string" and e.text ~= "") and e.text or e.name
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_ON, selected, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_OFF, not selected, k)
  funcLuaMenuCommand(C.TEXT, L, PL.SSROW_TEXT_ON, text, k)
  funcLuaMenuCommand(C.TEXT, L, PL.SSROW_TEXT_OFF, text, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_ON, selected, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_OFF, not selected, k)
  pcall(PL.SSRowIcons, L, k, e.id)
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, 442049775 --[[_pos_equip01]], false, k)
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, 3426045766 --[[_pos_have01]], false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2309656400 --[[_icon_check01]], e.equipped == true, k)
  for _, pr in ipairs({3334923667 --[[num_have01]], 3974820126 --[[num_equip01]]}) do
    funcLuaMenuCommand(1233047821 --[[number visible]], L, k, pr, false)
  end
end

-- the focused custom passive in the integrated panel (the retail six-sense detail window), nothing for «Quitar»
function PL.SSFocus(e)
  if e ~= nil and e.id ~= 0 then
    PL.PassiveDetail(e.name, e.desc or "", e.id)
  else
    pcall(EVT_DetailHide)
  end
end

-- menu_text row, or the Spanish text while the rows are not installed
function PL.TxtOr(id, fallback)
  local s = PL.Txt(id)
  return s ~= "" and s or fallback
end

-- the screen's header title (retail: SwapSoccerTopCommonHeaderByHeaderType of soccer_top_menu, as OnInit sets it),
-- e.g. «Pasiva personalizada» while its list is open; nil = the screen's own title again (text 1947742101)
function PL.HeaderTitle(text)
  if text == nil then
    text = funcLuaCommand(@crc:CMND_TEXT_GET@, 1947742101)
  end
  if type(text) == "string" and text ~= ""
      and funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, 811496143 --[[soccer_top_menu]]) then
    pcall(funcLuaCommand, 830228314, 811496143 --[[soccer_top_menu]], "SwapSoccerTopCommonHeaderByHeaderType", 5, text)
  end
end

PL.L_LISTBG = 2855071599                -- the board picker's blue backdrop, left half (ss2_build)
-- 2026-09-25 (user): the list is above everything on the left: the retail board picker's blue backdrop under the
-- (translucent) retail frame, the player card, the bottom buttons and the left column's base hidden meanwhile
function PL.ListCover(show)
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_LISTBG, 0, show)
  if show then
    funcLuaMenuCommand(C.SPRITE, PL.L_LISTBG, 2311471971 --[[cmn02_01.g4tx]], 515167937 --[[bg_blue01]],
      3512665951 --[[bg_black00]], 0, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, 1774956026 --[[team00_01_chara_card]], 0, not show)
  for _, L in ipairs({L_BTN, L_BTN_SS, PL.L_BTN_ROLE}) do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, not show)
  end
  for _, k in ipairs({EVT_ROW_ICON_SS, PL.ROW_ICON_ROLE}) do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, k, not show)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_BASE, 785322415, not show, 0)
end

function PL.SSListShow(show, list, first, sel)
  if not show then
    for k in pairs(PL.row_split) do
      pcall(PL.RowFull, PL.L_SSROW, k)
    end
  end
  local file_btn_was = PL.file_btn_shown              -- 2026-10-15: the export / import buttons (PL.VrmRow) redraw below
  PL.file_btn_shown = false
  if show ~= PL.list_covered then
    PL.list_covered = show
    pcall(PL.ListCover, show)
  end
  local LL, RL, NR = PL.ListLayers(PL.list_mode)    -- 2026-10-13: a mode's own frame / rows (combo partners)
  PL.Open(LL)
  funcLuaMenuCommand(C.LAYER_VISIBLE, LL, 0, show)
  for k = 0, NR - 1 do
    local e = show and list[first + k + 1] or nil
    if e ~= nil then
      if PL.list_mode ~= nil then
        PL.list_mode.row(k, e, first + k == sel)
      else
        PL.SSRow(k, e, first + k == sel)
      end
    end
    PL.Open(RL, k)
    funcLuaMenuCommand(C.LAYER_VISIBLE, RL, k, e ~= nil)
  end
  pcall(PL.ListArrows, show, first, NR, #list, LL)   -- 2026-10-13: scroll arrows (the combo partner list)
  for r = 0, EVT_ROW_NUM - 1 do                  -- the list covers the left column: our rows go away meanwhile
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_ROW, r, not show)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, not show)
  if file_btn_was and not PL.file_btn_shown then
    PL.file_btn_shown = true
    pcall(PL.FileBtnHide)
  end
  if show then
    pcall(funcLuaMenuCommand, C.CURSOR_LOC, RL, 3313461902 --[[cursor]], sel - first, NR)
    if PL.file_btn_shown then
      local se = list[sel + 1]
      if se ~= nil and se.kind == "vrm" then
        pcall(PL.FileBtnCursor, RL, NR)
      else
        pcall(funcLuaMenuCommand, C.CURSOR_LOC, PL.FILE_BTN.L, 3313461902 --[[cursor]], 2, 2)
      end
    end
  end
  if show and PL.list_mode ~= nil then
    local e = list[sel + 1]
    if PL.list_mode.focus ~= nil and e ~= nil then
      pcall(PL.list_mode.focus, e)
    else
      pcall(EVT_DetailHide)
    end
    PL.Guide(PL.list_mode.guide or "")
  elseif show then
    local e = list[sel + 1]
    if e ~= nil and e.id ~= 0 then
      pcall(PL.PassiveDetail, e.name, e.desc or "", e.id)
    else
      pcall(EVT_DetailHide)
    end
    PL.Guide(PL.Txt(2241341507 --[[skill_table_passive_list_guide]]))
  end
end

function PL.SSList(list, init)
  local sel = math.max(0, math.min(#list - 1, init or 0))
  local first = math.max(0, math.min(sel, #list - PL.SSROWS))
  PL.SSListShow(true, list, first, sel)
  coroutine.yield()
  local function key(k)
    return funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, EVT_MENU_CTRL, k)
      or funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k)
  end
  local result = -1
  local P = PL.PtrStart()
  while true do
    coroutine.yield()
    local pact, pfirst, psel, owns = PL.PtrStep(P, PL.L_SSROW, PL.SSROWS, PL.PTR_SS, first, sel, #list)
    if pact == "pick" then
      first, sel = pfirst, psel                    -- the clicked row is the one decided
    end
    if key(EVT_CMD_BACK) then
      funcLuaCommand(C.SE, SE_BACK)
      break
    elseif pact == "pick" or (not owns and (key(EVT_CMD_ENTER) or key(1651523701 --[[CMD_ENTER_CLICK]]))) then
      if PL.list_mode ~= nil and PL.list_mode.stay ~= nil and PL.list_mode.stay(list[sel + 1]) then
        PL.SSListShow(true, list, first, sel)      -- 2026-09-25: toggled (miximax move choice), the list stays
      else
        result = sel
        break
      end
    elseif key(EVT_CMD_DOWN) and sel < #list - 1 then
      sel = sel + 1
      if sel >= first + PL.SSROWS then
        first = first + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      PL.SSListShow(true, list, first, sel)
    elseif key(EVT_CMD_UP) and sel > 0 then
      sel = sel - 1
      if sel < first then
        first = first - 1
      end
      funcLuaCommand(C.SE, 2500047763)
      PL.SSListShow(true, list, first, sel)
    elseif pact == "moved" then
      first, sel = pfirst, psel
      funcLuaCommand(C.SE, 2500047763)
      PL.SSListShow(true, list, first, sel)
    end
  end
  PL.SSListShow(false, list, first, sel)
  coroutine.yield()                              -- the closing input must not reach our menu
  EVT_RefreshRows()
  return result
end

function EVT_SS_PickCoroutine()
  if PL.Signature() ~= nil then                  -- Signature Passives: read only (the detail shows on focus)
    funcLuaCommand(C.SE, SE_NG)
    pcall(EVT_SS_Info)
    return
  end
  local locked, need, piece = EVT_SS_Lock()
  if locked then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.LOADER))
    return
  end
  if not PL.HasService("six_sense") then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.LOADER))
    return
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  funcLuaCommand(C.SE, SE_DECIDE)
  local _, cur = EVT_SS_Get()
  local list, init = {}, 0
  for _, id in ipairs(PL.SS_ITEMS) do
    local num = funcLuaCommand(PL.ITEM_NUM, id)
    if type(num) == "number" and num > 0 then
      local name = funcLuaCommand(@crc:CMND_GET_ITEM_PARAM@, id, 0)
      local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, id)
      local e = {id = id, equipped = id == cur,
        name = type(name) == "string" and name or string.format("%08X", id),
        desc = eff ~= nil and EVT_PV_TeamText(id, eff, 1) or ""}
      e.text = e.desc                                -- 2026-09-30: the row shows the effect (PL.SSRow)
      if e.equipped then
        init = #list
      end
      list[#list + 1] = e
    end
  end
  if cur ~= 0 then
    list[#list + 1] = {id = 0, name = PL.Txt(PL.TX.SS_QUIT)}
  end
  if #list == 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.SS_NONE))
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  -- 2026-09-30: the retail list window of the role picker (PL.PopList): header title, one-sentence guide line and
  -- the retail button guide (Elegir / Volver) instead of a guide line spelling out the keys
  PL.HeaderTitle(PL.Txt(PL.TX.PASSIVE))
  local pick = PL.PopList(list, init, {
    row = PL.SSRow, focus = PL.SSFocus,
    guide = PL.Txt(PL.TX.SS_GUIDE),
    keys = function()
      return {{text = PL.TX.BTN_SELECT, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "pick"}}
    end,
    act = function()
      return "close"
    end})
  PL.HeaderTitle(nil)
  if pick >= 0 then
    local e = list[pick + 1]
    local st, now
    if e.id == 0 then
      st, now = EVT_Call(@crc:CMND_CHARACTERREFORGED_SIX_SENSE@, n, 1, 0, -1)
      funcLuaCommand(C.SE, st == 1 and SE_REMOVE or SE_NG)
    elseif e.id ~= cur then
      local h, why = PL.FreeHandle(e.id)
      if h == 0 then
        funcLuaCommand(C.SE, SE_NG)                -- 2026-09-28: error sound only
        EVT_Log("sixsense no handle", tostring(why))
      else
        st, now = EVT_Call(@crc:CMND_CHARACTERREFORGED_SIX_SENSE@, n, 1, h, piece or -1)
        funcLuaCommand(C.SE, st == 1 and SE_DECIDE or SE_NG)   -- 2026-09-28: no status popup
      end
    end
    EVT_Call(C.EVT_LOG, "skill_slots", "sixsense set", e.id, "status", st, "now", now)
  end
  EVT_SS_ButtonRefresh()
  pcall(EVT_SS_Info)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

PL.SslPrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == PL.L_LISTBG then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 449, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_SSLIST then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 450, true)
    for _, pos in ipairs({1839509013 --[[_pos_scr_base01]], 1060758565 --[[_pos_scr_obj01]]}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3660005257 --[[_text_list_empty01]], false, a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_SSROW then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 451, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.FILE_BTN.L then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 452, true)   -- the export / import buttons over their list row
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    pcall(funcLuaMenuCommand, C.CURSOR_LOC, a1, 3313461902 --[[cursor]], 2, 2)   -- the list cursor stays off them
    return
  end
  PL.SslPrevSetupLayer(a1, a2)
end

PL.SslPrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == PL.L_SSLIST or a1 == PL.L_SSROW or a1 == PL.L_LISTBG or a1 == PL.FILE_BTN.L then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  PL.SslPrevOpenLayer(a1, a2)
end
