-- EVT skill_slots_v2 (plain Lua 5.2 source). Base: decompiled retail equip_menu_select_5.00.21.00. Changes marked EVT; see src/evt_skill_slot_menu_block.lua.
INCLUDE("LUA_MENU_DEF")
INCLUDE("LUA_EQUIP_MENU_INC")
INCLUDE("LUA_SOCCER_COMMON")
INCLUDE("LUA_MAIN_MENU_INC")
INCLUDE("LUA_GENERAL_WINDOW_INC")
INCLUDE("LUA_PERSONAL_PLATE_INC")
local n = 0
local n2 = -1
local n3 = 0
local n4 = 0
local n5 = 0
local n6 = 0
local flag = false
local flag2 = false
local flag3 = false
local flag4 = false
local n7 = -1
local n8 = 0
local n9 = 0
local n10 = 0
local flag5 = false
local flag6 = false
local n11 = 0
local n12 = 0
local flag7 = false
local flag8 = false
local flag9 = false
local n13 = 0
local n14 = 0
local t = {}
local t2 = {1307475940 --[[_pos_list01]], 3571920478 --[[_pos_list02]], 2749374152 --[[_pos_list03]]}
local t3 = {
  [0] = {
  enableBoneName = 1307475940 --[[_pos_list01]],
  fontStyle = 1254616204,
  itemTextName = 456522680 --[[_text_item01]],
  categoryIconTextureName = 2346103015 --[[icon_equip01]],
  categoryTextTextureName = 1537316010 --[[gtxt_shoes01]],
  itemIconMeshName = 303536660 --[[_icon_item_dmy01]]
},
  [1] = {
  enableBoneName = 1307475940 --[[_pos_list01]],
  fontStyle = 1254616204,
  itemTextName = 456522680 --[[_text_item01]],
  categoryIconTextureName = 316662109 --[[icon_equip02]],
  categoryTextTextureName = 1570380768 --[[gtxt_misanga01]],
  itemIconMeshName = 303536660 --[[_icon_item_dmy01]]
},
  [2] = {
  enableBoneName = 1307475940 --[[_pos_list01]],
  fontStyle = 1254616204,
  itemTextName = 456522680 --[[_text_item01]],
  categoryIconTextureName = 1708708299 --[[icon_equip03]],
  categoryTextTextureName = 3838541556 --[[gtxt_pendant01]],
  itemIconMeshName = 303536660 --[[_icon_item_dmy01]]
},
  [3] = {
  enableBoneName = 1307475940 --[[_pos_list01]],
  fontStyle = 1254616204,
  itemTextName = 456522680 --[[_text_item01]],
  categoryIconTextureName = 4223419496 --[[icon_equip04]],
  categoryTextTextureName = 2352590947 --[[gtxt_special01]],
  itemIconMeshName = 303536660 --[[_icon_item_dmy01]]
},
  [4] = {
  enableBoneName = 2749374152 --[[_pos_list03]],
  fontStyle = 1281522442,
  itemTextName = 4114324116 --[[_text_item03]],
  categoryIconTextureName = nil,
  categoryTextTextureName = nil,
  itemIconMeshName = 2334051246 --[[_icon_item_dmy02]]
},
  [5] = {
  enableBoneName = 3571920478 --[[_pos_list02]],
  fontStyle = 263147399,
  itemTextName = 2185013762 --[[_text_item02]],
  categoryIconTextureName = nil,
  categoryTextTextureName = nil,
  itemIconMeshName = nil
}
}
local t4 = {}
local t5 = {}
local t6 = {}
local n15 = 0
local n16 = 0
local n17 = 0
local t7 = {
  3322349263 --[[status_chr_plate01_01]],
  1594775413 --[[status_chr_plate01_02]],
  671705059 --[[status_chr_plate01_03]],
  3060658752 --[[status_chr_plate01_04]],
  3244999382 --[[status_chr_plate01_05]],
  1482920812 --[[status_chr_plate01_06]],
  795124730 --[[status_chr_plate01_07]],
  3218849387 --[[status_chr_plate01_08]],
  2820343576 --[[status_chr_plate01_10]]
}
local t8 = {2318497122, 322446552, 1681855566, 4200301037}
local t9 = {
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  19
}
function OnInit()
  MAIN_MENU.SetupCharaSlotExpansion()
  local ret = VRFW_Param.Has(4081600465)
  if ret then
    n17 = VRFW_Param.Get(4081600465)
    VRFW_Param.Clear(4081600465)
  end
  n12 = MENU_DEF.GetParentMenuID()
  if VRFW_Param.Has(2029825652) then
    flag5 = VRFW_Param.Get(2029825652)
    VRFW_Param.Clear(2029825652)
  end
  if VRFW_Param.Has(363718978) then
    flag6 = VRFW_Param.Get(363718978)
    VRFW_Param.Clear(363718978)
  end
  if VRFW_Param.Has(4145209998) then
    n11 = VRFW_Param.Get(4145209998)
    VRFW_Param.Clear(4145209998)
  end
  if VRFW_Param.Has(3308763177) then
    flag7 = VRFW_Param.Get(3308763177)
    VRFW_Param.Clear(3308763177)
  end
  if VRFW_Param.Has(2719720834) then
    flag8 = VRFW_Param.Get(2719720834)
    VRFW_Param.Clear(2719720834)
  end
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, 811496143 --[[soccer_top_menu]]) then
    local text_get = funcLuaCommand(@crc:CMND_TEXT_GET@, 1947742101)
    funcLuaCommand(830228314, 811496143 --[[soccer_top_menu]], "SwapSoccerTopCommonHeaderByHeaderType", 5, text_get)
  end
  if VRFW_Param.Has(3357163798) then
    n3 = VRFW_Param.Get(3357163798)
    VRFW_Param.Clear(3357163798)
  end
  if flag5 then
    if n17 == 2 then
      if funcLuaCommand(347870658, 2337854133) then
        CreateMemverCharaHdlTable(7)
      else
        CreateMemverCharaHdlTable(6)
      end
      n15 = #t4
    else
      CreateMemverCharaHdlTable(20)
      n15 = #t4
    end
  else
    CreateMemverCharaHdlTable(11)
    n15 = 1
  end
  CreateEquipTypeTable()
end
function OnSetupLayer(a1, a2)
  if a1 == 2917320188 --[[soccer11_05_equip_status_base]] then
    funcLuaMenuCommand(2158717427, a1, 3407216458 --[[_pos_page01]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 1377611504 --[[_pos_page02]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 622567014 --[[_pos_page03]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 3145665477 --[[_pos_page04]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 3784855471 --[[_page01_off]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 2788701567 --[[_page02_off]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 2606243023 --[[_page03_off]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 695779551 --[[_page04_off]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 1437140403 --[[_pos_arrow01_r]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 2946906320 --[[_pos_arrow01_l]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 1753514051 --[[_pos_page01_rpg]], false, a2)
    funcLuaMenuCommand(2158717427, a1, 790952595 --[[_pos_page02_rpg]], false, a2)
    if flag6 then
      funcLuaMenuCommand(2158717427, a1, 442049775 --[[_pos_equip01]], false, a2)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 162250999, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 2091397827 --[[graph03]], false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 703196151, false)
    else
      funcLuaMenuCommand(2158717427, a1, 1056264686 --[[_pos_equip01_rpg]], false, a2)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 2810680323, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 1707903547, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 1790849101, false)
    end
  elseif a1 == 1774956026 --[[team00_01_chara_card]] or a1 == 508919562 --[[team00_02_chara_card]] then
    if n11 == 0 and a1 == 508919562 --[[team00_02_chara_card]] or n11 == 1 and a1 == 1774956026 --[[team00_01_chara_card]] then
      return
    end
    n16 = a1
    NameSetting_CharaCard(a1, a2)
    local ret = VRFW_Param.Has(1038144478)
    if ret then
      n = VRFW_Param.Get(1038144478)
      VRFW_Param.Clear(1038144478)
    end
    ret = VRFW_Param.Has(622145442)
    if ret then
      n4 = VRFW_Param.Get(622145442)
      VRFW_Param.Clear(622145442)
    end
    ret = VRFW_Param.Has(813466851)
    if ret then
      n6 = VRFW_Param.Get(813466851)
      VRFW_Param.Clear(813466851)
    end
    if n17 ~= 2 then
      n2 = GetCharaPosByCharaStHdl(n)
      n4 = GetMemberIndexByCharaStHdl(n)
      n5 = SearchCharaSortIndexBySelectIndex(n4)
    else
      n5 = n4
    end
    flag3 = IsDirectorInTeamDock(n3, n17, n)
    flag4 = false
    if n2 >= 16 and n2 <= 18 then
      flag4 = true
    end
    UpdateCharaCard()
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
    if n11 == 1 then
      funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, a1, a2, 652, true)
    end
  elseif a1 == 3560167285 --[[team05_01_equip_base]] then
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, a1, a2, 450, true)
    if flag6 then
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 703196151, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 2967517773, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3353840347, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 1501765496, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 780414958, false)
    else
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 1790849101, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 756959901, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 276718381, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 2724118333, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 2671679117, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3634293853, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 482121444, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, 4251697490 --[[soccer11_08_equip_list_item]], GetEquipTypeNum(), false)
    end
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 4168479935 --[[chara02]], false)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, 508919562 --[[team00_02_chara_card]], 0, false)
    funcLuaMenuCommand(3252599449, 4251697490 --[[soccer11_08_equip_list_item]], GetEquipTypeNum())
    if n15 > 1 then
      funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, a1, 1821189452 --[[_arrow01_l01]], true, a2)
      funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, a1, 2050337590 --[[_arrow01_r01]], true, a2)
      local text_get = funcLuaCommand(@crc:CMND_TEXT_GET@, 1406349308)
      funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 3853210161 --[[_text_btn01_l]], text_get, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 3853210161 --[[_text_btn01_l]], 1155652271)
      local text_get2 = funcLuaCommand(@crc:CMND_TEXT_GET@, 1681049711)
      funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 530870098 --[[_text_btn01_r]], text_get2, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 530870098 --[[_text_btn01_r]], 1155652271)
    else
    end
    if flag7 then
      UpdateEquipButtonGuide(n12, true)
      funcLuaMenuCommand(1432240275, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], false)
    end
  elseif a1 == 4251697490 --[[soccer11_08_equip_list_item]] then
    local equip_type = GetEquipType(a2)
    local equip_list_item_info = GetEquipListItemInfo(equip_type)
    for i = 1, #t2 do
      if t2[i] ~= equip_list_item_info.enableBoneName then
        funcLuaMenuCommand(2158717427, 4251697490 --[[soccer11_08_equip_list_item]], t2[i], false, a2)
      end
    end
    if equip_list_item_info.categoryIconTextureName ~= nil then
      funcLuaMenuCommand(558735651, 4251697490 --[[soccer11_08_equip_list_item]], 1676671618 --[[#/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx]], equip_list_item_info.categoryIconTextureName, 2346103015 --[[icon_equip01]], 0, a2)
    end
    if equip_list_item_info.categoryTextTextureName ~= nil then
      funcLuaMenuCommand(558735651, 4251697490 --[[soccer11_08_equip_list_item]], 1676671618 --[[#/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx]], equip_list_item_info.categoryTextTextureName, 1537316010 --[[gtxt_shoes01]], 0, a2)
    end
    funcLuaMenuCommand(2333948100, 4251697490 --[[soccer11_08_equip_list_item]], a2, equip_list_item_info.itemTextName, equip_list_item_info.fontStyle)
    if equip_type == 4 then
      funcLuaMenuCommand(558735651, 4251697490 --[[soccer11_08_equip_list_item]], 1676671618 --[[#/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx]], 3264784393 --[[item_list_base_outfit02]], 1536293299 --[[item_list_base_outfit01]], 0, a2)
      funcLuaMenuCommand(558735651, 4251697490 --[[soccer11_08_equip_list_item]], 1676671618 --[[#/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx]], 1558763435 --[[item_list_focus02]], 3319891473 --[[item_list_focus01]], 0, a2)
    elseif equip_type == 5 then
      funcLuaMenuCommand(3404096044, a1, a2, 688754292 --[[_touch_list01]], false)
      funcLuaMenuCommand(558735651, 4251697490 --[[soccer11_08_equip_list_item]], 1676671618 --[[#/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx]], 2396336836 --[[title_list_base01_02]], 1453818910 --[[title_list_base01]], 0, a2)
      funcLuaMenuCommand(558735651, 4251697490 --[[soccer11_08_equip_list_item]], 1676671618 --[[#/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx]], 1558763435 --[[item_list_focus02]], 3319891473 --[[item_list_focus01]], 0, a2)
    end
    if a2 == 0 then
      funcLuaMenuCommand(2559269762, a1, 3407457192 --[[CMD_FCS_BACK]], false)
    end
  elseif a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    local text_get3 = funcLuaCommand(@crc:CMND_TEXT_GET@, 181831922)
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 950238781 --[[_text_btn01]], text_get3, a2)
    local text_get4 = funcLuaCommand(@crc:CMND_TEXT_GET@, 1696127664)
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 625330766 --[[_text_cmd01]], text_get4, a2)
    if a2 == 0 then
      funcLuaMenuCommand(2559269762, a1, 2734193315 --[[CMD_FCS_NEXT]], false)
    end
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3313461902 --[[cursor]], false)
  elseif a1 == 878737202 --[[team11_01_personal_plate]] then
    if flag6 then
      funcLuaMenuCommand(2158717427, a1, 62066836 --[[_param_plate01]], false, a2)
    else
      funcLuaMenuCommand(2158717427, a1, 2595897646 --[[_param_plate02]], false, a2)
    end
    SwapPersonalPlateTexture(n)
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 1493879504 --[[offset]], 0, 2767879305 --[[param]])
    if flag8 then
      funcLuaMenuCommand(@crc:CMND_OPEN_LAYER_ARRAY@, 3665300474 --[[soccer11_16_rpg_attack_defense_param]])
    end
  elseif a1 == 3029081695 --[[team11_03_seasonal_player_plate]] then
    local chara_is_seasonal = GetCharaIsSeasonal(n)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, chara_is_seasonal)
  end
end
function OnOpenLayer(a1, a2)
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] then
    UpdateEquipListItem(a2)
  elseif a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
  elseif a1 == 607716004 --[[soccer11_04_chara_status]] then
    UpdateCharaStatus()
    SwapPersonalPlateTexture(n)
  elseif _layerName == 3665300474 --[[soccer11_16_rpg_attack_defense_param]] then
    if a2 == 0 then
      MENU_DEF.UpdateRpgAttackDefenseParam(n4, 0, a2)
    elseif a2 == 1 then
    end
  elseif a1 == 3078308064 --[[mainmenu90_05_content_guide_line01]] then
    local text_get = funcLuaCommand(@crc:CMND_TEXT_GET@, 2936044151)
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 378156699 --[[_text_guide01]], text_get, a2)
  elseif a1 == 2917320188 --[[soccer11_05_equip_status_base]] then
    waitTrue(function()
      return funcLuaMenuCommand(2787787510, a1, a2)
    end)
    SetupCharaModel(a1, a2)
  elseif a1 == 858725131 --[[mainmenu01_08_chara_3d_shadow]] then
    SetupChara3dShadow(a1, a2)
  elseif a1 == 295554296 --[[team05_05_equip_visible_check]] then
    if flag6 then
      UpdateEquippedVisibleCheck(n)
    else
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, false)
    end
  end
end
function OnChangeFocus(a1, a2)
  if not funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, a1) then
    return
  end
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] or a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    n14 = a1
    UpdateEquipItemInfo()
  end
end
function OnFocusLayerShift(a1, a2, a3, a4)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3313461902 --[[cursor]], false)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a3, a4, 3313461902 --[[cursor]], true)
end
function OnChangeLayerGroup(a1)
  if a1 == 1041963128 --[[evt_skill_slot_menu EVT]] then
    UpdateEquipButtonGuide(n12, true)
    local check_equipment_model_update = CheckEquipmentModelUpdateNeeded(n9, n10)
    if check_equipment_model_update then
      SetupCharaModel(2917320188 --[[soccer11_05_equip_status_base]], 0)
      if flag6 then
        UpdateCharaCard()
        UpdateCharaStatus()
        MAIN_MENU.SetupMainMenuCharaModelByCharaStHdl(n, false)
      end
    end
    funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, 858725131 --[[mainmenu01_08_chara_3d_shadow]], 0)
  end
end
function OnEnter(a1, a2)
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] then
    VRFW_Param.Set(2029825652, flag5, "plain")
    VRFW_Param.Set(363718978, flag6, "plain")
  end
end
function OnDecideFocus(a1, a2)
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] then
    local n18 = 0
    local l1 = n
    local equip_type = GetEquipType(a2)
    if equip_type == 0 then
      n18 = 2161680939
    elseif equip_type == 1 then
      n18 = 3329547027
    elseif equip_type == 2 then
      n18 = 1758796364
    elseif equip_type == 3 then
      n18 = 2772365803
    elseif equip_type == 4 then
      n18 = 4226440591
    end
    funcLuaMenuCommand(919706220, 2917320188 --[[soccer11_05_equip_status_base]], 0, 0, 2)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, 2296367164 --[[cmn05_01_cursor]], 0, false)
    VRFW_Param.Clear(n18)
    VRFW_Param.Set(n18, l1)
  elseif a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    ConfirmEquipOptimalItem()
  end
end
function OnBack(a1)
  if flag5 then
    VRFW_Param.Clear(622145442)
    VRFW_Param.Set(622145442, n4)
  end
end
function OnMouseMove(a1, a2)
  if a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    if not flag9 then
      flag9 = true
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2500047763 --[[sy0005]])
      funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 2734777837 --[[Focus]], 0, 973515837 --[[button]])
    end
  elseif flag9 then
    flag9 = false
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, 503674375 --[[cmn03_07_cmn_button_equip]], 0, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
  end
end
function OnFunction(a1, a2)
  if a1 == 1933761232 then
    if n15 > 1 then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3791946501 --[[sy0004]])
      funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, 3560167285 --[[team05_01_equip_base]], 0, 1203080170, 0, 3627544126)
      while true do
        n5 = n5 - 1
        if n5 < 0 then
          n5 = n15 - 1
        end
        n4 = GetCharaIndexBySortIndex(n5)
        if t4[n4 + 1] ~= 0 then
          break
        end
      end
      ChangeChara(n4)
    end
  elseif a1 == 721364740 then
    if n15 > 1 then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3791946501 --[[sy0004]])
      funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, 3560167285 --[[team05_01_equip_base]], 0, 3183130249, 0, 3627544126)
      while true do
        n5 = n5 + 1
        if n5 >= n15 then
          n5 = 0
        end
        n4 = GetCharaIndexBySortIndex(n5)
        if t4[n4 + 1] ~= 0 then
          break
        end
      end
      ChangeChara(n4)
    end
  elseif a1 == 1141890006 then
    if flag6 then
      local l1 = not funcLuaCommand(29506568, n, 2048)
      funcLuaCommand(1525180681, n, 2048, l1)
      local n18 = 4235359837 --[[sy0010]]
      if l1 then
        n18 = 2339718859 --[[sy0011]]
      end
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, n18)
      SetupCharaModel(2917320188 --[[soccer11_05_equip_status_base]], 0)
      UpdateEquippedVisibleCheck(n)
      MAIN_MENU.SetupMainMenuCharaModelByCharaStHdl(n, false)
    end
  elseif a1 == 3918588344 then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    ConfirmEquipOptimalItem()
  elseif a1 == 4109882573 then
    local ret = funcLuaMenuCommand(2603265800, 4251697490 --[[soccer11_08_equip_list_item]])
    local equip_itemid = GetEquipItemid(n, ret)
    if equip_itemid ~= 0 then
      local l2
      if ret == 0 then
        l2 = equip_itemid
      end
      local l3
      if ret == 4 then
        l3 = equip_itemid
      end
      funcLuaCommand(@crc:CMND_REMOVE_EQUIP@, n, ret)
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2339718859 --[[sy0011]])
      UpdateEquipCondition(l2, l3)
    else
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    end
  end
end
function OnEquipOptimalItemConfirm(a1)
  if a1 == 0 then
    funcLuaCommand(218753920)
    while not funcLuaCommand(682363669) do
      coroutine.yield()
    end
    RegistPropValueLastEquippedItemIds(n)
    n13 = GetEquipShoesID(n)
    funcLuaCommand(@crc:CMND_EQUIP_OPTIMAL_ITEM@, n)
    flag2 = true
    local text_get = funcLuaCommand(@crc:CMND_TEXT_GET@, 513387635)
    GENERAL_WINDOW.ReserveGeneralWindow("OnEquipOptimalItemDone", "", "", text_get, 94, 0, n)
    funcLuaCommand(2351835063, 0, 0)
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 4235359837 --[[sy0010]])
  elseif a1 == 1 then
    WaitCloseGeneralWindow()
  end
end
function CheckEquipmentModelUpdateNeeded(a1, a2)
  local flag10 = false
  local equip_shoes_id = GetEquipShoesID(n)
  if flag6 then
    local ret = funcLuaCommand(29506568, n, 2048)
    if not ret and a1 ~= equip_shoes_id then
      flag10 = true
    end
    if a2 ~= GetEquipCostumeID(n) then
      flag10 = true
    end
  elseif a1 ~= equip_shoes_id then
    flag10 = true
  end
  return flag10
end
function UpdateEquipCondition(a1, a2)
  for i = 0, GetEquipTypeNum() - 1 do
    UpdateEquipListItem(i)
  end
  local l1 = a1 ~= nil and a1 or GetEquipShoesID(n)
  local l2 = a2 ~= nil and a2 or GetEquipCostumeID(n)
  local check_equipment_model_update = CheckEquipmentModelUpdateNeeded(l1, l2)
  if check_equipment_model_update then
    SetupCharaModel(2917320188 --[[soccer11_05_equip_status_base]], 0)
    if flag6 then
      UpdateCharaCard()
      MAIN_MENU.SetupMainMenuCharaModelByCharaStHdl(n, false)
    end
  end
  if flag6 then
    UpdateEquippedVisibleCheck(n)
  end
  UpdateCharaStatus()
  UpdateEquipItemInfo()
end
function OnEquipOptimalItemDone(a1)
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  if flag2 then
    flag2 = false
    UpdateEquipCondition(n13, nil)
  end
  WaitCloseGeneralWindow()
end
function WaitCloseGeneralWindow()
  funcLuaCommand(218753920)
  while not funcLuaCommand(682363669) do
    coroutine.yield()
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, 2296367164 --[[cmn05_01_cursor]], 0, true)
  funcLuaMenuCommand(1558704558, 1041963128 --[[evt_skill_slot_menu EVT]], true)
end
function UpdateCharaCard()
  local l1 = flag3
  local n18 = 0
  local n19 = 0
  local l2 = l1
  local ret, ret2 = funcLuaCommand(2361903722, n, 2607368153 --[[abl_000002]])
  if ret and ret2 then
    l2 = true
  else
    l2 = false
  end
  local l3 = flag4
  local ret3, ret4 = funcLuaCommand(2361903722, n, 3966662479 --[[abl_000003]])
  if ret3 and ret4 then
    l3 = true
  else
    l3 = false
  end
  local l4 = not l2 and not l3
  flag = false
  if n17 ~= 2 then
    if n17 == 1 then
      flag = n2 <= 4
    else
      flag = n2 <= 10
    end
  end
  if l2 then
    n7 = 19
  elseif flag then
    n18, n19 = funcLuaCommand(@crc:CMND_GET_SOCCER_FORMATION_INFO@, 6, n6, n2)
    if n18 then
      n7 = n19
    end
  else
    local soccer_chara_calc_param_best = GetSoccerCharaCalcParamBestPositionTypeByStHdl(n)
    n19 = ConvertPosTypeToScPosType(soccer_chara_calc_param_best)
    n7 = n19
  end
  local flag10 = false
  if n11 == 1 then
    flag10 = true
  end
  local flag11 = false
  if n11 == 0 then
    flag11 = IsCaptain(n3, n17, n)
    if not flag11 then
      local ret5 = funcLuaCommand(1131797651, n, 4)
      flag11 = funcLuaCommand(562046683, ret5)
    end
  end
  local chara_title_attr = GetCharaTitleAttr(n3, n17, n)
  local n20 = 1
  local flag12 = false
  funcLuaMenuCommand(3837561292, n16, 0, n, true, l2, n7, 0, 0, flag11, flag10, 0, 0, false, flag, chara_title_attr, false, false, l3, false, false, n20, flag12, l4, n3)
  funcLuaMenuCommand(2158717427, n16, 1387831794 --[[_pos_leader01]], l1, 0)
  funcLuaMenuCommand(2158717427, n16, 3417436232 --[[_pos_leader02]], l1, 0)
  if n17 == 2 then
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, n16, 1721769611 --[[_icon_chr_position_dmy_l01]], false, 0)
  end
  if n11 == 0 then
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, n16, 2635558741 --[[_icon_card01]], false, 0)
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, n16, 69091055 --[[_icon_card02]], false, 0)
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, n16, 814224422 --[[_icon_lock01]], false, 0)
  elseif n11 == 1 then
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, n16, 1400751930 --[[_icon_personality_s_dmy01]], false, 0)
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, n16, 2942116298 --[[_icon_chr_grayout01]], false, 0)
    local ret6 = funcLuaCommand(1131797651, n, 0)
    local flag13 = false
    if ret6 >= funcLuaCommand(@crc:CMND_GET_LV_MAX@) then
      flag13 = true
    end
    funcLuaMenuCommand(2158717427, n16, 4071435007 --[[_icon_lock_lv01]], flag13)
  end
end
function UpdateEquipListItem(a1)
  local equip_type = GetEquipType(a1)
  local equip_list_item_info = GetEquipListItemInfo(equip_type)
  local n18 = 0
  if equip_type == 5 then
    n18 = GetEquipTitleID()
  else
    n18 = GetEquipItemIdByLayerIdx(a1)
  end
  if a1 == 0 then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, 2296367164 --[[cmn05_01_cursor]], 0, true)
  end
  if n18 ~= 0 then
    local item_param = funcLuaCommand(@crc:CMND_GET_ITEM_PARAM@, n18, 0)
    if item_param then
      funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemTextName, item_param, a1)
    end
    if equip_list_item_info.itemIconMeshName ~= nil then
      funcLuaMenuCommand(3508889864, 4251697490 --[[soccer11_08_equip_list_item]], a1, equip_list_item_info.itemIconMeshName, 1875672568 --[[icon_item_dmy01]], n18)
      funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemIconMeshName, true, a1)
    end
  else
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemTextName, "", a1)
    if equip_list_item_info.itemIconMeshName ~= nil then
      funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemIconMeshName, false, a1)
    end
  end
  if equip_type == 5 then
    funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, 4251697490 --[[soccer11_08_equip_list_item]], 4025646555 --[[_icon_title01]], false, a1)
  end
end
function UpdateCharaStatus()
  local flag10 = false
  local n18 = 0
  if n18 == 0 then
    local n19 = 0
    if n7 ~= -1 then
      if flag then
        local soccer_formation_info, soccer_formation_info2 = funcLuaCommand(@crc:CMND_GET_SOCCER_FORMATION_INFO@, 5, n6, n2)
        if soccer_formation_info then
          n19 = GetSoccerCharaPositionIconByPosIconType(soccer_formation_info2)
        end
      else
        local soccer_chara_calc_param_best = GetSoccerCharaCalcParamBestPositionTypeByStHdl(n)
        n19 = GetSoccerCharaBestPositionIconByPosType(soccer_chara_calc_param_best)
      end
    end
    local n20 = 0
    local team_set_info, team_set_info2 = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n3, n17, 7)
    if team_set_info then
      n20 = funcLuaMenuCommand(1187793486, team_set_info2)
    end
    local n21 = 0
    if n17 == 2 then
      n21 = -1
    else
      team_set_info, n21 = funcLuaCommand(1720957768, n3, n17, n4, 2)
      n21 = team_set_info and n21 or 0
    end
    local flag11 = false
    if n11 == 0 then
      flag11 = IsCaptain(n3, n17, n)
      if not flag11 then
        local ret = funcLuaCommand(1131797651, n, 4)
        flag11 = funcLuaCommand(562046683, ret)
      end
    end
    local chara_title_attr = GetCharaTitleAttr(n3, n17, n)
    local n22 = 0
    if n17 == 2 then
      n22 = 3
    end
    local l1, l2
    l1, l2 = funcLuaCommand(2361903722, n, 2607368153 --[[abl_000002]])
    local l3 = l1 == true and l2 or false
    l1, l2 = funcLuaCommand(2361903722, n, 3966662479 --[[abl_000003]])
    local l4 = l1 == true and l2 or false
    UpdateCharaStatusPlateInfoByCharaStHdl(607716004 --[[soccer11_04_chara_status]], 0, n, n20, n21, n22, n19, flag10, nil, nil, nil, nil, nil, l3, nil, nil, nil, nil, l4, nil, nil, nil, nil, nil, nil, nil, flag11, chara_title_attr, n3)
  elseif n11 == 1 then
    local n23 = -1
    local l5, l6
    l5, l6 = funcLuaCommand(2361903722, n, 2607368153 --[[abl_000002]])
    local l7 = l5 == true and l6 or false
    l5, l6 = funcLuaCommand(2361903722, n, 3966662479 --[[abl_000003]])
    local l8 = l5 == true and l6 or false
    UpdateCharaStatusPlateInfoByCharaStHdlUseAttributeBg(607716004 --[[soccer11_04_chara_status]], 0, n, 0, n23, 3, nil, nil, nil, true, flag10, nil, l7, nil, nil, nil, nil, l8)
  end
end
function UpdateEquipItemInfo()
  if n14 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    n8 = 0
  else
    local ret = funcLuaMenuCommand(2603265800, 4251697490 --[[soccer11_08_equip_list_item]])
    funcLuaMenuCommand(@crc:CMND_SET_CURSOR_LOCATOR@, 4251697490 --[[soccer11_08_equip_list_item]], 3313461902 --[[cursor]], ret, 6)
    n8 = GetEquipItemIdByLayerIdx(ret)
  end
  if n8 ~= 0 then
    SetVisibleEquipInfoWindow(true)
    SetupEquipInfoWindow(n8)
    UpdateEquipButtonGuide(n12, true)
  else
    SetVisibleEquipInfoWindow(false)
    UpdateEquipButtonGuide(n12, false)
  end
  UpdateCharaParameterGraphByCharaStHdl(2334590304 --[[soccer11_07_status_graph]], 732343773 --[[soccer11_06_p1_formation_status_graph_param_num]], n, 32151736 --[[soccer11_06_status_graph_base]])
  MENU_DEF.UpdateRpgAttackDefenseParam(n4, 0)
end
function ChangeChara(a1)
  n = t4[a1 + 1]
  n2 = GetCharaPosNoBySelectCharaIdx(a1)
  flag3 = IsDirectorInTeamDock(n3, n17, n)
  flag4 = false
  if n2 >= 16 and n2 <= 18 then
    flag4 = true
  end
  for i = 0, GetEquipTypeNum() - 1 do
    UpdateEquipListItem(i)
  end
  UpdateCharaCard()
  UpdateCharaStatus()
  UpdateEquipItemInfo()
  if flag6 then
    UpdateEquippedVisibleCheck(n)
  end
  SetupCharaModel(2917320188 --[[soccer11_05_equip_status_base]], 0)
  SwapPersonalPlateTexture(n)
end
function NameSetting_CharaCard(a1, a2)
  MENU_DEF.NameSettingBegin(a1, a2)
  MENU_DEF.AddName("text_charaname", "_text_chr01")
  MENU_DEF.AddName("locator_base_pos_L", "_pos_base01")
  MENU_DEF.AddName("locator_base_pos_S", "_pos_base02")
  MENU_DEF.AddName("numprim_level_L", "num_chr_l01")
  MENU_DEF.AddName("numprim_level_S", "num_chr_s01")
  MENU_DEF.AddName("numprim_level_gray_L", "num_chr_l01_gray")
  MENU_DEF.AddName("numprim_level_gray_S", "num_chr_s01_gray")
  MENU_DEF.AddName("numprim_level_basara_L", "num_chr_l01_basara")
  MENU_DEF.AddName("numprim_level_basara_S", "num_chr_s01_basara")
  MENU_DEF.AddName("rate_anim_exp", "exp_gauge01")
  MENU_DEF.AddName("rate_group_exp", "bar")
  MENU_DEF.AddName("locator_gp_gauge_L", "_pos_gauge_gp_l01")
  MENU_DEF.AddName("locator_gp_gauge_S", "_pos_gauge_gp_s01")
  MENU_DEF.AddName("rate_anim_gp", "gp_gauge01")
  MENU_DEF.AddName("rate_group_gp", "bar")
  MENU_DEF.AddName("locator_kp_gauge_L", "_pos_gauge_kp_l01")
  MENU_DEF.AddName("locator_kp_gauge_S", "_pos_gauge_kp_s01")
  MENU_DEF.AddName("rate_anim_kp", "kp_gauge01")
  MENU_DEF.AddName("rate_group_kp", "bar")
  MENU_DEF.AddName("tex_chara_face_L", "icon_chr_dmy_l01")
  MENU_DEF.AddName("tex_chara_face_S", "icon_chr_dmy_s01")
  MENU_DEF.AddName("mesh_chara_face_L", "_icon_chr_dmy_l01")
  MENU_DEF.AddName("mesh_chara_face_S", "_icon_chr_dmy_s01")
  MENU_DEF.AddName("mesh_icon_element_L", "_icon_chr_type_dmy_l01")
  MENU_DEF.AddName("mesh_icon_element_S", "_icon_chr_type_dmy_s01")
  MENU_DEF.AddName("mesh_base_element_L", "_icon_base_l01")
  MENU_DEF.AddName("mesh_base_element_S", "_icon_base_s01")
  MENU_DEF.AddName("tex_element_L", "icon_chr_type_dmy_l01")
  MENU_DEF.AddName("tex_element_S", "icon_chr_type_dmy_s01")
  MENU_DEF.AddName("tex_file_element", "#/menu/200_icon/15_icon_common/icon_common.g4tx")
  MENU_DEF.AddName("tex_base_element_L", "icon_chr_base01_type_l01")
  MENU_DEF.AddName("tex_base_element_S", "icon_chr_base01_type_s01")
  MENU_DEF.AddName("tex_base_file_element", "#/menu/102_team/team00/team00_02/<LG>/team00_02.g4tx")
  MENU_DEF.AddName("tex_face_color_element_L", "icon_chr_color01_type_l01")
  MENU_DEF.AddName("tex_face_color_element_S", "icon_chr_color01_type_s01")
  MENU_DEF.AddName("tex_file_face_color_element", "#/menu/102_team/team00/team00_02/<LG>/team00_02.g4tx")
  MENU_DEF.AddName("mesh_icon_position_L", "_icon_chr_position_dmy_l01")
  MENU_DEF.AddName("mesh_icon_position_S", "_icon_chr_position_dmy_s01")
  MENU_DEF.AddName("tex_position_L", "icon_chr_position_dmy_l01")
  MENU_DEF.AddName("tex_position_S", "icon_chr_position_dmy_s01")
  MENU_DEF.AddName("tex_file_position", "#/menu/200_icon/15_icon_common2/<LG>/icon_common2.g4tx")
  MENU_DEF.AddName("tex_file_rarity", "#/menu/102_team/team00/team00_01/<LG>/team00_01.g4tx")
  MENU_DEF.AddName("mesh_base_rarity_L", "_icon_chr_base_l01")
  MENU_DEF.AddName("mesh_base_rarity_S", "_icon_chr_base_s01")
  MENU_DEF.AddName("tex_base_rarity_L", "icon_chr_base01_l01")
  MENU_DEF.AddName("tex_base_rarity_S", "icon_chr_base01_s01")
  MENU_DEF.AddName("mesh_color_rarity_L", "_icon_chr_dmy_l01")
  MENU_DEF.AddName("mesh_color_rarity_S", "_icon_chr_dmy_s01")
  MENU_DEF.AddName("tex_color_rarity_L", "icon_chr_color01_l01")
  MENU_DEF.AddName("tex_color_rarity_S", "icon_chr_color01_s01")
  MENU_DEF.AddName("tex_gradation_rarity_L", "icon_chr_gradation_l01")
  MENU_DEF.AddName("tex_gradation_rarity_S", "icon_chr_gradation_s01")
  MENU_DEF.AddName("mesh_captain_L", "_icon_captain01")
  MENU_DEF.AddName("mesh_captain_S", "_icon_captain02")
  MENU_DEF.AddName("mesh_seasonal_flame_L", "_seasonal_frame_l01")
  MENU_DEF.AddName("mesh_seasonal_flame_S", "_seasonal_frame_s01")
  MENU_DEF.AddName("mesh_ai_role_setting_icon_L", "_icon_ai_role_dmy01")
  MENU_DEF.AddName("mesh_ai_role_setting_icon_S", "_icon_ai_role_dmy02")
  MENU_DEF.AddName("tex_ai_role_setting_icon_L", "icon_ai_role_dmy01")
  MENU_DEF.AddName("tex_ai_role_setting_icon_S", "icon_ai_role_dmy01")
  MENU_DEF.AddName("tex_file_ai_role", "#/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx")
  MENU_DEF.AddName("pos_leader_L", "_pos_leader01")
  MENU_DEF.AddName("pos_leader_S", "_pos_leader02")
  MENU_DEF.AddName("pos_gauge_exp_L", "_pos_gauge_exp_l01")
  MENU_DEF.AddName("pos_gauge_exp_S", "_pos_gauge_exp_s01")
  MENU_DEF.AddName("hidden_exp_gauge", "true")
  MENU_DEF.AddName("material_rarity_color", "rarity_color")
  MENU_DEF.NameSettingEnd()
end
function GetEquipItemIdByLayerIdx(a1)
  local equip_type = GetEquipType(a1)
  local n18 = 0
  if equip_type == 0 then
    n18 = GetEquipShoesID(n)
  elseif equip_type == 1 then
    n18 = GetEquipMisangaID(n)
  elseif equip_type == 2 then
    n18 = GetEquipPendantID(n)
  elseif equip_type == 3 then
    n18 = GetEquipSpecialID(n)
  elseif equip_type == 4 then
    n18 = GetEquipCostumeID(n)
  end
  return n18
end
function GetEquipTitleID()
  if n == 0 then
    return 0
  end
  return (funcLuaCommand(1131797651, n, 10))
end
function SetupCharaModel(a1, a2)
  local ret = funcLuaCommand(1131797651, n, 4)
  local ret2 = funcLuaCommand(347353059, ret)
  funcLuaMenuCommand(59611540, a1, a2, ret2)
  do
    local flag10 = false
    local n18 = 0
    local n19 = 0
    local flag11 = false
    local l1 = flag3
    local l2 = flag4
    local ret3, ret4 = funcLuaCommand(2361903722, n, 2607368153 --[[abl_000002]])
    if ret3 and ret4 then
      l1 = true
    else
      l1 = false
    end
    local ret5, ret6 = funcLuaCommand(2361903722, n, 3966662479 --[[abl_000003]])
    if ret5 and ret6 then
      l2 = true
    else
      l2 = false
    end
    local flag12 = false
    local flag13 = false
    if n6 ~= 0 then
      flag13 = true
    end
    if not l1 and funcLuaCommand(252985896, n7, 16) == true then
      flag12 = true
    end
    if not flag13 then
      local ret7 = funcLuaCommand(2548972844, n)
      if funcLuaCommand(252985896, ret7, 16) == true then
        flag12 = true
      end
    end
    flag10, flag11 = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n3, n17, 8, n)
    local n20 = 0
    if l1 then
      n20 = 16
    elseif l2 then
      n20 = 32
    elseif flag12 and flag then
      if flag11 then
        n20 = 10
      else
        n20 = 2
      end
    elseif flag11 then
      n20 = 8
    else
      n20 = 0
    end
    if flag13 then
      flag10, n18 = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n3, n17, 7)
      flag10, n19 = funcLuaCommand(1720957768, n3, n17, n4, 2)
      if l1 == true or l2 == true then
        local n21 = 0
        flag10, n21 = funcLuaCommand(2641567432, ret2, n20, n18)
        if flag10 == true and n21 ~= 0 then
          n18 = 0
        end
      end
    end
    local n22 = 0
    n9 = GetEquipShoesID(n)
    if n9 ~= 0 then
      flag10, n22 = funcLuaCommand(845816129, n9)
      if not flag10 then
        n22 = 0
      end
    end
    if flag6 then
      n10 = GetEquipCostumeID(n)
      if n10 ~= 0 then
        local n23 = 0
        flag10, n23 = funcLuaCommand(845816129, n10)
        if flag10 and n23 ~= 0 then
          n18 = n23
        end
      end
    end
    local ret8 = funcLuaCommand(3372444427, n)
    if ret8 then
      n22 = 0
    end
    funcLuaMenuCommand(3290636356, a1, a2, n18, n19, n20, 0, n22)
  end
  funcLuaMenuCommand(3986622543, a1, a2, 0, 3505099195)
  if flag6 then
    funcLuaMenuCommand(@crc:CMND_CHARA_MODEL_CHANGE@, a1, a2, 0, 9, 0, 2917320188 --[[soccer11_05_equip_status_base]])
  else
    funcLuaMenuCommand(@crc:CMND_CHARA_MODEL_CHANGE@, a1, a2)
  end
  funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, 858725131 --[[mainmenu01_08_chara_3d_shadow]], 0)
  funcLuaMenuCommand(@crc:CMND_UPDATE_CHARA_MODEL_POSE@, a1, a2, 1553534011)
  funcLuaMenuCommand(@crc:CMND_SET_CHARA_MODEL_SHADOW@, a1, a2, 858725131 --[[mainmenu01_08_chara_3d_shadow]])
end
function SetupChara3dShadow(a1, a2)
  local ret = funcLuaMenuCommand(3895705890, 2917320188 --[[soccer11_05_equip_status_base]], a2, a2)
  local scn_chara_pos, scn_chara_pos2, scn_chara_pos3, scn_chara_pos4 = funcLuaCommand(@crc:CMND_GET_SCN_CHARA_POS@, ret)
  if not scn_chara_pos then
    return
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, a1, scn_chara_pos2, scn_chara_pos3, scn_chara_pos4, a2)
  local ret2, ret3 = funcLuaMenuCommand(324469031, 0)
  if ret2 then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, a1, ret3, ret3, ret3, a2)
  end
  funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 71445658 --[[Open]], 0, 973515837 --[[button]])
end
function GetEquipType(a1)
  if GetEquipTypeNum() <= a1 then
    return -1
  end
  return t[a1 + 1]
end
function GetEquipTypeNum()
  return #t
end
function CreateEquipTypeTable()
  t = {0, 1, 2, 3}
  if flag6 then
    t[#t + 1] = 4
  end
end
function GetEquipListItemInfo(a1)
  local l1 = t3[a1]
  if l1 == nil then
    l1 = t3[0]
  end
  return l1
end
function CreateMemverCharaHdlTable(a1)
  local global_bit_flag = funcLuaCommand(@crc:CMND_GET_GLOBAL_BIT_FLAG@, 908681340)
  local ret = funcLuaCommand(2668676119, 0)
  for i = 0, a1 - 1 do
    local ret2, ret3 = funcLuaCommand(1720957768, n3, n17, i, 0)
    if not ret2 then
      ret3 = 0
    end
    if global_bit_flag and ret3 == ret then
      ret3 = 0
    end
    t4[#t4 + 1] = ret3
    local ret4, ret5 = funcLuaCommand(1720957768, n3, n17, i, 1)
    if not ret4 then
      ret5 = -1
    end
    t5[#t5 + 1] = ret5
  end
  if n17 ~= 2 then
    CreateIndexTableFullMember()
  end
end
function CreateIndexTableFullMember()
  local l1 = #t4
  local l2 = #t9
  for i = 0, l2 - 1 do
    local l3 = t9[i + 1]
    for i2 = 0, l1 - 1 do
      local l4 = t5[i2 + 1]
      if l3 == l4 then
        t6[#t6 + 1] = i2
        break
      end
    end
  end
end
function GetMemberIndexByCharaStHdl(a1)
  local l1 = #t4
  for i = 0, l1 - 1 do
    if t4[i + 1] == a1 then
      return i
    end
  end
  return -1
end
function GetCharaPosByCharaStHdl(a1)
  local l1 = #t4
  for i = 0, l1 - 1 do
    if t4[i + 1] == a1 then
      return t5[i + 1]
    end
  end
  return -1
end
function GetCharaPosNoBySelectCharaIdx(a1)
  if a1 < 0 or #t5 < a1 then
    return -1
  end
  return t5[a1 + 1]
end
function GetCharaIndexBySortIndex(a1)
  if #t6 <= 0 then
    return a1
  end
  return t6[a1 + 1]
end
function SearchCharaSortIndexBySelectIndex(a1)
  local l1 = n15
  if l1 <= 0 then
    return 0
  end
  for i = 0, l1 - 1 do
    if t6[i + 1] == a1 then
      return i
    end
  end
  return 0
end
function SwapPersonalPlateTexture(a1)
  local n18 = 0
  local n19 = 0
  if n19 == 1 then
    local ret = funcLuaCommand(1131797651, a1, 8)
    if ret <= 0 or #t8 < ret then
      return
    end
    n18 = t8[ret]
  else
    local chara_status_rarity = GetCharaStatusRarity(a1)
    if chara_status_rarity == nil then
      return
    end
    if chara_status_rarity < 0 or #t7 <= chara_status_rarity then
      return
    end
    n18 = t7[chara_status_rarity + 1]
  end
  funcLuaMenuCommand(558735651, 878737202 --[[team11_01_personal_plate]], 3044635609, n18, 3322349263 --[[status_chr_plate01_01]], 0, 0)
  if n19 ~= 1 then
    local chara_status_rarity2 = GetCharaStatusRarity(a1)
    if chara_status_rarity2 == nil then
      return
    end
    local rarity_chara_plate_texture_n = GetRarityCharaPlateTextureName(chara_status_rarity2)
    funcLuaMenuCommand(558735651, 878737202 --[[team11_01_personal_plate]], 3044635609, rarity_chara_plate_texture_n, 3724358770 --[[status_chr_plate01_01_02]], 0)
    local rarity_chara_plate_mask_text = GetRarityCharaPlateMaskTextureName(chara_status_rarity2)
    funcLuaMenuCommand(558735651, 878737202 --[[team11_01_personal_plate]], 3044635609, rarity_chara_plate_mask_text, 1001552350 --[[status_chr_plate01_01_msk]], 0)
    local l1 = chara_status_rarity2 == 8 and 3848468598 --[[icon_chr_status_base02]] or 2087430604 --[[icon_chr_status_base01]]
    funcLuaMenuCommand(558735651, 878737202 --[[team11_01_personal_plate]], 3044635609, l1, 2087430604 --[[icon_chr_status_base01]], 0)
    local is_end_anime_type = funcLuaMenuCommand(@crc:CMND_IS_END_ANIME_TYPE@, 878737202 --[[team11_01_personal_plate]], 0, 1372483206 --[[hero]], 1)
    local l2 = chara_status_rarity2 >= 5
    if is_end_anime_type == l2 then
      local l3 = l2 and 1 or 2
      funcLuaMenuCommand(1586300804, 878737202 --[[team11_01_personal_plate]], 0, 1372483206 --[[hero]], 1, 0)
      funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, 878737202 --[[team11_01_personal_plate]], 0, 1372483206 --[[hero]], l3)
    end
  end
end
function UpdateEquippedVisibleCheck(a1)
  local s = ""
  local ret = funcLuaCommand(29506568, a1, 2048)
  if ret then
    s = 2953416216 --[[check_icon_eye_off01]]
  else
    s = 1133105553 --[[check_icon_eye_on01]]
  end
  funcLuaMenuCommand(558735651, 295554296 --[[team05_05_equip_visible_check]], 2162228289, s, 2953416216 --[[check_icon_eye_off01]], 0)
  local ret2 = funcLuaCommand(1131797651, a1, 1)
  local team_set_info, team_set_info2 = funcLuaCommand(@crc:CMND_GET_TEAM_SET_INFO@, n3, n17, 7)
  if not team_set_info then
    team_set_info2 = 0
  end
  local equip_costume_id = GetEquipCostumeID(n)
  if equip_costume_id ~= 0 then
    local n18 = 0
    team_set_info, n18 = funcLuaCommand(845816129, equip_costume_id)
    if team_set_info and n18 ~= 0 then
      team_set_info2 = n18
    end
  end
  local equip_shoes_id = GetEquipShoesID(n)
  local n19 = 0
  if equip_shoes_id ~= 0 then
    team_set_info, n19 = funcLuaCommand(845816129, equip_shoes_id)
    if not team_set_info then
      n19 = 0
    end
  end
  local ret3 = funcLuaCommand(177490050, ret2, team_set_info2, n19)
  if ret3 then
    funcLuaMenuCommand(2158717427, 295554296 --[[team05_05_equip_visible_check]], 3981201027 --[[_pos_disable01]], false)
    funcLuaMenuCommand(2158717427, 295554296 --[[team05_05_equip_visible_check]], 1115585009 --[[_pos_check01]], not ret)
  else
    funcLuaMenuCommand(2158717427, 295554296 --[[team05_05_equip_visible_check]], 3981201027 --[[_pos_disable01]], true)
    funcLuaMenuCommand(2158717427, 295554296 --[[team05_05_equip_visible_check]], 1115585009 --[[_pos_check01]], false)
  end
end
function ConfirmEquipOptimalItem()
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, 2296367164 --[[cmn05_01_cursor]], 0, false)
  funcLuaMenuCommand(1558704558, 1041963128 --[[evt_skill_slot_menu EVT]], false)
  local text_get = funcLuaCommand(@crc:CMND_TEXT_GET@, 2626269278)
  GENERAL_WINDOW.ReserveGeneralWindow("OnEquipOptimalItemConfirm", "", "", text_get, 2)
  funcLuaCommand(2351835063, 2, 0)
  funcLuaCommand(2529383714, 0)
end


@BLOCK_SKILL_SLOTS@

@BLOCK_PLAYER_SET_ROLE@

@BLOCK_BOARD_ENTRY_POINTS@

@BLOCK_CUSTOM_PASSIVE_PICKER@

@BLOCK_HIPER_MIXIMAX@

@BLOCK_MIXIMAX_SCENE@

@BLOCK_MODE_CHANGE@

@BLOCK_RESET_DELETE@

@BLOCK_COMPACT_DETAIL@

@BLOCK_TWO_HIPER_SLOTS@

@BLOCK_MIXIMAX_SCENE_INPUT_GUARD@

@BLOCK_ROW_FOCUS_RESYNC@

@BLOCK_MOVE_PLATE_ROWS@

@BLOCK_REFORGED_PROJECTION@

@BLOCK_BOARD_ONLY_MOVE_GUIDE@

@BLOCK_REFORGED_SLOT_RULES@


@BLOCK_UNLIMITED_COPIES@

@BLOCK_FANTASY_SLOT_FALLBACKS@

@BLOCK_HIPER_ROW_RESET_DELETE@
