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
  local ret = funcLuaCommand(2947612279, 4081600465)
  if ret then
    n17 = funcLuaCommand(3522198769, 4081600465)
    funcLuaCommand(3363400568, 4081600465)
  end
  n12 = MENU_DEF.GetParentMenuID()
  if funcLuaCommand(2947612279, 2029825652) then
    flag5 = funcLuaCommand(3522198769, 2029825652)
    funcLuaCommand(3363400568, 2029825652)
  end
  if funcLuaCommand(2947612279, 363718978) then
    flag6 = funcLuaCommand(3522198769, 363718978)
    funcLuaCommand(3363400568, 363718978)
  end
  if funcLuaCommand(2947612279, 4145209998) then
    n11 = funcLuaCommand(3522198769, 4145209998)
    funcLuaCommand(3363400568, 4145209998)
  end
  if funcLuaCommand(2947612279, 3308763177) then
    flag7 = funcLuaCommand(3522198769, 3308763177)
    funcLuaCommand(3363400568, 3308763177)
  end
  if funcLuaCommand(2947612279, 2719720834) then
    flag8 = funcLuaCommand(3522198769, 2719720834)
    funcLuaCommand(3363400568, 2719720834)
  end
  if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], 811496143 --[[soccer_top_menu]]) then
    local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1947742101)
    funcLuaCommand(830228314, 811496143 --[[soccer_top_menu]], "SwapSoccerTopCommonHeaderByHeaderType", 5, text_get)
  end
  if funcLuaCommand(2947612279, 3357163798) then
    n3 = funcLuaCommand(3522198769, 3357163798)
    funcLuaCommand(3363400568, 3357163798)
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
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 162250999, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 2091397827 --[[graph03]], false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 703196151, false)
    else
      funcLuaMenuCommand(2158717427, a1, 1056264686 --[[_pos_equip01_rpg]], false, a2)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 2810680323, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 1707903547, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 1790849101, false)
    end
  elseif a1 == 1774956026 --[[team00_01_chara_card]] or a1 == 508919562 --[[team00_02_chara_card]] then
    if n11 == 0 and a1 == 508919562 --[[team00_02_chara_card]] or n11 == 1 and a1 == 1774956026 --[[team00_01_chara_card]] then
      return
    end
    n16 = a1
    NameSetting_CharaCard(a1, a2)
    local ret = funcLuaCommand(2947612279, 1038144478)
    if ret then
      n = funcLuaCommand(3522198769, 1038144478)
      funcLuaCommand(3363400568, 1038144478)
    end
    ret = funcLuaCommand(2947612279, 622145442)
    if ret then
      n4 = funcLuaCommand(3522198769, 622145442)
      funcLuaCommand(3363400568, 622145442)
    end
    ret = funcLuaCommand(2947612279, 813466851)
    if ret then
      n6 = funcLuaCommand(3522198769, 813466851)
      funcLuaCommand(3363400568, 813466851)
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
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
    if n11 == 1 then
      funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, 652, true)
    end
  elseif a1 == 3560167285 --[[team05_01_equip_base]] then
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, 450, true)
    if flag6 then
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 703196151, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 2967517773, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 3353840347, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 1501765496, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 780414958, false)
    else
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 1790849101, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 756959901, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 276718381, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 2724118333, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 2671679117, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 3634293853, false)
      funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 482121444, false)
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 4251697490 --[[soccer11_08_equip_list_item]], GetEquipTypeNum(), false)
    end
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 4168479935 --[[chara02]], false)
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 508919562 --[[team00_02_chara_card]], 0, false)
    funcLuaMenuCommand(3252599449, 4251697490 --[[soccer11_08_equip_list_item]], GetEquipTypeNum())
    if n15 > 1 then
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], a1, 1821189452 --[[_arrow01_l01]], true, a2)
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], a1, 2050337590 --[[_arrow01_r01]], true, a2)
      local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1406349308)
      funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 3853210161 --[[_text_btn01_l]], text_get, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 3853210161 --[[_text_btn01_l]], 1155652271)
      local text_get2 = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1681049711)
      funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 530870098 --[[_text_btn01_r]], text_get2, a2)
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
    local text_get3 = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 181831922)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 950238781 --[[_text_btn01]], text_get3, a2)
    local text_get4 = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1696127664)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 625330766 --[[_text_cmd01]], text_get4, a2)
    if a2 == 0 then
      funcLuaMenuCommand(2559269762, a1, 2734193315 --[[CMD_FCS_NEXT]], false)
    end
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 3313461902 --[[cursor]], false)
  elseif a1 == 878737202 --[[team11_01_personal_plate]] then
    if flag6 then
      funcLuaMenuCommand(2158717427, a1, 62066836 --[[_param_plate01]], false, a2)
    else
      funcLuaMenuCommand(2158717427, a1, 2595897646 --[[_param_plate02]], false, a2)
    end
    SwapPersonalPlateTexture(n)
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 1493879504 --[[offset]], 0, 2767879305 --[[param]])
    if flag8 then
      funcLuaMenuCommand(2152386330 --[[CMND_OPEN_LAYER_ARRAY]], 3665300474 --[[soccer11_16_rpg_attack_defense_param]])
    end
  elseif a1 == 3029081695 --[[team11_03_seasonal_player_plate]] then
    local chara_is_seasonal = GetCharaIsSeasonal(n)
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, chara_is_seasonal)
  end
end
function OnOpenLayer(a1, a2)
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] then
    UpdateEquipListItem(a2)
  elseif a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
  elseif a1 == 607716004 --[[soccer11_04_chara_status]] then
    UpdateCharaStatus()
    SwapPersonalPlateTexture(n)
  elseif _layerName == 3665300474 --[[soccer11_16_rpg_attack_defense_param]] then
    if a2 == 0 then
      MENU_DEF.UpdateRpgAttackDefenseParam(n4, 0, a2)
    elseif a2 == 1 then
    end
  elseif a1 == 3078308064 --[[mainmenu90_05_content_guide_line01]] then
    local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 2936044151)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 378156699 --[[_text_guide01]], text_get, a2)
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
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, false)
    end
  end
end
function OnChangeFocus(a1, a2)
  if not funcLuaMenuCommand(102308320 --[[CMND_IS_CTRL_FOCUS_ACTIVE?]], a1) then
    return
  end
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] or a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    n14 = a1
    UpdateEquipItemInfo()
  end
end
function OnFocusLayerShift(a1, a2, a3, a4)
  funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 3313461902 --[[cursor]], false)
  funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a3, a4, 3313461902 --[[cursor]], true)
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
    funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], 858725131 --[[mainmenu01_08_chara_3d_shadow]], 0)
  end
end
function OnEnter(a1, a2)
  if a1 == 4251697490 --[[soccer11_08_equip_list_item]] then
    funcLuaCommand(3860611758, 2029825652, 0, flag5)
    funcLuaCommand(3860611758, 363718978, 0, flag6)
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
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, false)
    funcLuaCommand(3363400568, n18)
    funcLuaCommand(3860611758, n18, 0, l1, 1)
  elseif a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    ConfirmEquipOptimalItem()
  end
end
function OnBack(a1)
  if flag5 then
    funcLuaCommand(3363400568, 622145442)
    funcLuaCommand(3860611758, 622145442, 0, n4, 1)
  end
end
function OnMouseMove(a1, a2)
  if a1 == 503674375 --[[cmn03_07_cmn_button_equip]] then
    if not flag9 then
      flag9 = true
      funcLuaCommand(1917805374, 2500047763 --[[sy0005]])
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 2734777837 --[[Focus]], 0, 973515837 --[[button]])
    end
  elseif flag9 then
    flag9 = false
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], 503674375 --[[cmn03_07_cmn_button_equip]], 0, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
  end
end
function OnFunction(a1, a2)
  if a1 == 1933761232 then
    if n15 > 1 then
      funcLuaCommand(1917805374, 3791946501 --[[sy0004]])
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], 3560167285 --[[team05_01_equip_base]], 0, 1203080170, 0, 3627544126)
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
      funcLuaCommand(1917805374, 3791946501 --[[sy0004]])
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], 3560167285 --[[team05_01_equip_base]], 0, 3183130249, 0, 3627544126)
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
      funcLuaCommand(1917805374, n18)
      SetupCharaModel(2917320188 --[[soccer11_05_equip_status_base]], 0)
      UpdateEquippedVisibleCheck(n)
      MAIN_MENU.SetupMainMenuCharaModelByCharaStHdl(n, false)
    end
  elseif a1 == 3918588344 then
    funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
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
      funcLuaCommand(402087824 --[[CMND_REMOVE_EQUIP]], n, ret)
      funcLuaCommand(1917805374, 2339718859 --[[sy0011]])
      UpdateEquipCondition(l2, l3)
    else
      funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
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
    funcLuaCommand(2385215961 --[[CMND_EQUIP_OPTIMAL_ITEM]], n)
    flag2 = true
    local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 513387635)
    GENERAL_WINDOW.ReserveGeneralWindow("OnEquipOptimalItemDone", "", "", text_get, 94, 0, n)
    funcLuaCommand(2351835063, 0, 0)
    funcLuaCommand(1917805374, 4235359837 --[[sy0010]])
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
  funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
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
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, true)
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
    n18, n19 = funcLuaCommand(2649030357 --[[CMND_GET_SOCCER_FORMATION_INFO]], 6, n6, n2)
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
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], n16, 1721769611 --[[_icon_chr_position_dmy_l01]], false, 0)
  end
  if n11 == 0 then
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], n16, 2635558741 --[[_icon_card01]], false, 0)
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], n16, 69091055 --[[_icon_card02]], false, 0)
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], n16, 814224422 --[[_icon_lock01]], false, 0)
  elseif n11 == 1 then
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], n16, 1400751930 --[[_icon_personality_s_dmy01]], false, 0)
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], n16, 2942116298 --[[_icon_chr_grayout01]], false, 0)
    local ret6 = funcLuaCommand(1131797651, n, 0)
    local flag13 = false
    if ret6 >= funcLuaCommand(570148181 --[[CMND_GET_LV_MAX]]) then
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
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, true)
  end
  if n18 ~= 0 then
    local item_param = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM?]], n18, 0)
    if item_param then
      funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemTextName, item_param, a1)
    end
    if equip_list_item_info.itemIconMeshName ~= nil then
      funcLuaMenuCommand(3508889864, 4251697490 --[[soccer11_08_equip_list_item]], a1, equip_list_item_info.itemIconMeshName, 1875672568 --[[icon_item_dmy01]], n18)
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemIconMeshName, true, a1)
    end
  else
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemTextName, "", a1)
    if equip_list_item_info.itemIconMeshName ~= nil then
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], 4251697490 --[[soccer11_08_equip_list_item]], equip_list_item_info.itemIconMeshName, false, a1)
    end
  end
  if equip_type == 5 then
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], 4251697490 --[[soccer11_08_equip_list_item]], 4025646555 --[[_icon_title01]], false, a1)
  end
end
function UpdateCharaStatus()
  local flag10 = false
  local n18 = 0
  if n18 == 0 then
    local n19 = 0
    if n7 ~= -1 then
      if flag then
        local soccer_formation_info, soccer_formation_info2 = funcLuaCommand(2649030357 --[[CMND_GET_SOCCER_FORMATION_INFO]], 5, n6, n2)
        if soccer_formation_info then
          n19 = GetSoccerCharaPositionIconByPosIconType(soccer_formation_info2)
        end
      else
        local soccer_chara_calc_param_best = GetSoccerCharaCalcParamBestPositionTypeByStHdl(n)
        n19 = GetSoccerCharaBestPositionIconByPosType(soccer_chara_calc_param_best)
      end
    end
    local n20 = 0
    local team_set_info, team_set_info2 = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], n3, n17, 7)
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
    funcLuaMenuCommand(381797568 --[[CMND_SET_CURSOR_LOCATOR?]], 4251697490 --[[soccer11_08_equip_list_item]], 3313461902 --[[cursor]], ret, 6)
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
    flag10, flag11 = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], n3, n17, 8, n)
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
      flag10, n18 = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], n3, n17, 7)
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
    funcLuaMenuCommand(2232914067 --[[CMND_CHARA_MODEL_CHANGE]], a1, a2, 0, 9, 0, 2917320188 --[[soccer11_05_equip_status_base]])
  else
    funcLuaMenuCommand(2232914067 --[[CMND_CHARA_MODEL_CHANGE]], a1, a2)
  end
  funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], 858725131 --[[mainmenu01_08_chara_3d_shadow]], 0)
  funcLuaMenuCommand(953552931 --[[CMND_UPDATE_CHARA_MODEL_POSE?]], a1, a2, 1553534011)
  funcLuaMenuCommand(4219344099 --[[CMND_SET_CHARA_MODEL_SHADOW?]], a1, a2, 858725131 --[[mainmenu01_08_chara_3d_shadow]])
end
function SetupChara3dShadow(a1, a2)
  local ret = funcLuaMenuCommand(3895705890, 2917320188 --[[soccer11_05_equip_status_base]], a2, a2)
  local scn_chara_pos, scn_chara_pos2, scn_chara_pos3, scn_chara_pos4 = funcLuaCommand(798245126 --[[CMND_GET_SCN_CHARA_POS?]], ret)
  if not scn_chara_pos then
    return
  end
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], a1, scn_chara_pos2, scn_chara_pos3, scn_chara_pos4, a2)
  local ret2, ret3 = funcLuaMenuCommand(324469031, 0)
  if ret2 then
    funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE?]], a1, ret3, ret3, ret3, a2)
  end
  funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 71445658 --[[Open]], 0, 973515837 --[[button]])
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
  local global_bit_flag = funcLuaCommand(941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], 908681340)
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
    local is_end_anime_type = funcLuaMenuCommand(3133389476 --[[CMND_IS_END_ANIME_TYPE?]], 878737202 --[[team11_01_personal_plate]], 0, 1372483206 --[[hero]], 1)
    local l2 = chara_status_rarity2 >= 5
    if is_end_anime_type == l2 then
      local l3 = l2 and 1 or 2
      funcLuaMenuCommand(1586300804, 878737202 --[[team11_01_personal_plate]], 0, 1372483206 --[[hero]], 1, 0)
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], 878737202 --[[team11_01_personal_plate]], 0, 1372483206 --[[hero]], l3)
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
  local team_set_info, team_set_info2 = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], n3, n17, 7)
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
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, false)
  funcLuaMenuCommand(1558704558, 1041963128 --[[evt_skill_slot_menu EVT]], false)
  local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 2626269278)
  GENERAL_WINDOW.ReserveGeneralWindow("OnEquipOptimalItemConfirm", "", "", text_get, 2)
  funcLuaCommand(2351835063, 2, 0)
  funcLuaCommand(2529383714, 0)
end

-- generated by research/scripts/bd_branch.py (board shape graphs of ability_learning_config)
EVT_BR_SHAPES = {
  ["27:6"] = {[6] = {{8,10,12,14,16,18,20,22,24,26}, {7,9,11,13,15,17,19,21,23,25}}},
  ["28:7"] = {[7] = {{18,19,20,21,22,23,24,25,26,27}, {8,9,10,11,12,13,14,15,16,17}}},
  ["51:49"] = {[49] = {{41,42}, {43,44}}},
  ["53:50"] = {[50] = {{52}, {51}}},
  ["54:50"] = {[50] = {{4,5,9,10,11,12,13,14,18,19,20,21,27,28,29,30,31,35,36,37,39,40,42,43,45,48,49,51,53}, {2,3,6,7,8,15,16,17,22,23,24,25,26,32,33,34,38,41,44,46,47,52}}},
  ["56:54"] = {[54] = {{34,37,38,48}, {33,35,36,47}}},
  ["57:53,54"] = {[53] = {{33,35}, {34,36}}, [54] = {{37,39}, {38,40}}},
  ["57:53,56"] = {[53] = {{4,5,9,10,11,12,13,14,18,19,20,21,22,23,29,30,31,32,35,40,41,43,45,46,48,49,52,54}, {2,3,6,7,8,15,16,17,24,25,26,27,28,33,34,36,37,38,39,42,44,47,50,51,55,56}}, [56] = {{34,38,39,51}, {33,36,37,50}}},
  ["59:53,57,58"] = {[53] = {{4,5,12,13,14,15,16,23,24,25,26,27,31,32,33,38,39,40,41,43,46,49,50,52,55,56,58}, {2,3,6,7,8,9,10,11,17,18,19,20,21,22,28,29,30,34,35,36,37,42,44,45,47,48,51,54,57}}, [57] = {{36}, {37}}, [58] = {{40}, {41}}},
  ["60:58,59"] = {[58] = {{39}, {38}}, [59] = {{42}, {41}}},
  ["63:58"] = {[58] = {{4,5,12,13,14,15,16,17,24,25,26,27,28,29,33,34,35,40,41,42,43,45,48,49,52,53,56,57,60,62}, {2,3,6,7,8,9,10,11,18,19,20,21,22,23,30,31,32,36,37,38,39,44,46,47,50,51,54,55,59,61}}},
  ["67:62,64,65,66"] = {[62] = {{19}, {18}}, [64] = {{42,43,44,45,58,66}, {38,39,40,41,57,65}}, [65] = {{40}, {41}}, [66] = {{44}, {45}}},
  ["75:58"] = {[58] = {{26,27}, {25,53}}},
  ["76:58"] = {[58] = {{26,27}, {25,53}}},
}

-- ===================================================================================================
-- EVT skill slots v2: "Tabla de habilidades" as an equipment-style screen: 1 special row ("Hipertécnica")
-- + 6 normal hissatsu rows. Appended by research/scripts/ss2_build.py to the decompiled retail
-- equip_menu_select_5.00.21.00 (the left-column/right-panel script of the accessories screen). The result is
-- shipped as the script of the NEW menu evt_skill_slot_menu (common/script/lua/menu/evt_skill_slot_menu.lua.bin),
-- so the real equipment screen is untouched. The functions below REDEFINE retail globals of the same chunk
-- (later definition wins); chunk locals of the retail part (n = charaStHdl, n3 = dock no, n17 = dock type,
-- n4 = member index, n12 = parent menu, n14 = focused layer, n15 = member count, flag6/flag7, t3) are upvalues.
-- Docs: docs/game/skill-slots.md §7.1. Plain Lua 5.2.
--
-- Rows (instances of soccer11_08_equip_list_item), try 18 (forced board layout, board writes via the vr-loader):
--   row 0 "Hiper" = board slot 8 (branch 2's 3rd piece, the game's hyperpower/special slot) + this player's team aura
--         slot; never written to the match list.
--   rows 1-6 = match list positions 0-5 (skill_list, what the match uses) = board slots 0-5 (base 0-2 + branch 1).
--   Board slots 6 and 7 are always closed (CMND_EVT_BOARD_LAYOUT), whatever the route switcher of the original board.
--   The match list is the source of truth: a row shows skill_list; the board is mirrored best-effort (EVT_SyncBoard).
-- ===================================================================================================

-- ---- tweakables ------------------------------------------------------------------------------------
-- Normal rows 1-4 unlock when the player reaches the level at which he learns his 1st..4th move (his own
-- learn table, command 0xCF25A8AF). This table is only the FALLBACK when the game returns nothing.
-- Rows 5-6 (0 here) are always unlocked. The special row is always unlocked. Unlocked rows take any move.
local EVT_UNLOCK_LEVEL_FALLBACK = {1, 13, 20, 30, 0, 0}
local EVT_ALWAYS_FREE = {false, false, false, false, true, true}   -- per normal row 1..6
-- Special row ("Hipertécnica": fighting spirit, armed, miximax, soul, hyperpower/awakening "wap", mode change =
-- move category 8). Tries 10-13 mapped it to the active branch's 3rd slot (5 or 8), shared with match position 6.
-- Try 18 (user): always branch 1 for the 6 normal rows (board slots 0-5 = match positions 1-6) and the special on
-- board slot 8 (branch 2's special piece, kept open by CMND_EVT_BOARD_LAYOUT) + the team aura slot.
local EVT_HIPER_SLOT = 8                -- board slot of the Hiper row
local EVT_LAYOUT_OPEN = {3, 4, 5, 8}    -- board slots the forced layout keeps open (0-2 are always open)
local EVT_LAYOUT_CLOSED = {6, 7}        -- board slots the forced layout keeps closed and empty (learnset slots 7-8:
                                        -- never a source of moves, 2026-09-30)
local EVT_SPECIAL_TEAM_AURA = true      -- also put the special into this player's team aura slot
local EVT_SPECIAL_LABEL = ""            -- prefix of the special row (try 13: none, the row is purple instead)
-- try 17: the special row's base is our own purple sprite (EVT_HIPER_TEX below); tints (tries 13-15) had no effect
EVT_SKILL_SLOT_DEBUG = false            -- try 11: normal rows confirmed in game -> quiet (errors are always shown)
EVT_SKILL_SLOT_DEBUG_HIPER = false      -- 2026-09-24: Hiper confirmed; details go to loader.log only (user: no debug popups)
local EVT_GUIDE_TEXT = "Selecciona la supertécnica que deseas cambiar."   -- bottom guide line
local EVT_BUTTON_TEXT = 2135514294   -- bottom button label = menu_text evt_pl_set_btn «Set de jugador» (PL.TX.SET_BTN)
local EVT_DESC_LINE_BYTES = 34      -- info card: description wrapped to 2 lines of at most this many bytes (UTF-8 safe, "…")

-- ---- ids ---------------------------------------------------------------------------------------------
local EVT_ROW_NUM = 7               -- 1 special + 6 normal
local EVT_NORMAL_NUM = 6
local EVT_MENU = 1041963128           -- this menu
local EVT_PICK_MENU = 2897322950        -- the game's hissatsu list with tabs/filters/sort
-- parameter-store handoff with the picker: NUMBERS/BOOLS ONLY (strings are stored as a raw pointer into the
-- setter's lua_State, handler 0xCA6480, and do not survive to the other menu - the try 1-6 string params)
local EVT_KEY_PICK = 790447113          -- param: pick mode 1 normal / 2 special
local EVT_KEY_RESULT = 3854106930      -- param: chosen move id
local EVT_KEY_INV = 331123112            -- param: its invSkill handle
local EVT_KEY_USED = {621880403, 3155719657, 3407824255, 1434177756, 578609226, 3145052656}
local EVT_KEY_DBG_INIT = 1463482560       -- picker debug: mode it saw at OnInit
local EVT_KEY_DBG_ENTER = 1978530279     -- picker debug: layer of the last confirm callback
local EVT_KEY_DBG_CODE = 3864734764       -- picker debug: 3 rejected, 4 chosen, 9 Lua error
local EVT_KEY_DBG_BITS = 3833368827       -- picker debug: hooks seen (1 focus, 2 detail, 4 step, 8 enter, 16 click, 32 OnEnter, 64 OnDecideFocus, 128 other)
local EVT_KEY_OPEN_BOARD = 1881233917   -- param: team dock must open the original board
local L_ROW = 4251697490      -- soccer11_08_equip_list_item (7 instances = 7 rows)
local L_BTN = 503674375       -- cmn03_07_cmn_button_equip ("Mejor equipamiento" -> original board)
local L_BASE = 3560167285     -- team05_01_equip_base (left column; objbin/layout cloned by the builder)
local L_INFO = 3239909435     -- team05_02_equip_info_easy (right info window)
local L_CURSOR = 2296367164   -- cmn05_01_cursor
-- Row base sprite (try 17). The white card of a row is the mesh _item_list_base01, which draws sprite item_list_base01
-- of soccer11_08.g4tx; command 558735651 (layer, textureCrc, spriteCrc, nodeCrc, 0, idx) swaps it, nodeCrc = crc32 of
-- the sprite name the mesh was built with (retail equip_menu_select does the same for the outfit row).
-- Our texture: data/dx11/menu/00_soccer/soccer11/evt_soccer11_08_hiper/evt_item_list_base_hiper01.g4tx, one 568x80
-- BC7 image named like the file (as the save-slot story pictures), a purple recolour of item_list_base01.
local EVT_HIPER_TEX = "#/menu/00_soccer/soccer11/evt_soccer11_08_hiper/evt_item_list_base_hiper01.g4tx"
local EVT_HIPER_TEX_CRC = 2127494112     -- crc32(EVT_HIPER_TEX)
local EVT_HIPER_SPRITE = 3767077459      -- evt_item_list_base_hiper01
local EVT_ROW_TEX = 1676671618           -- #/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx (retail)
local EVT_ROW_BASE = 2417687399          -- item_list_base01 (retail white sprite = node of _item_list_base01)
local C = {
  GET_SKILL = 903078840,      -- 0x35D3E3B8 (charaStHdl, slot0..5) -> skill id (save skill_list)
  SET_SKILL = 2394267160,     -- 0x8EB59E18 CMND_SET_SKILL (charaStHdl, skill, slot): swaps if already in the list
  REMOVE_SKILL = 3149494359,  -- 0xBBB97857 CMND_REMOVE_SKILL (charaStHdl, slot)
  LEARNABLE = 3475351727,     -- 0xCF25A8AF (charaStHdl) -> ok, {skill per slot}, {unlock level per slot}
  CHARA_GET = 1131797651,     -- 0x4375DC93 (charaStHdl, 0 level | 4 chara id)
  SKILL_INFO = 2580586398,    -- CMND_GET_SOCCER_SKILL_INFO (skill, 4 name id | 5 description id | 6 power | 9 category)
  NAME_TEXT = 720417636,      -- 0x2AF0B364 (name id) -> string
  DESC_TEXT = 4113915188,     -- 0xF5355D34 (description id) -> string (as SetupPersonalPlateSkillDetailInfo)
  TEXT = 1083631230,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_ALPHA = 1126837159,    -- CMND_SET_MENU_TEXT_ALPHA (layer, idx, node, alpha)
  MESH_VISIBLE = 3405944500,  -- CMND_SET_MESH_VISIBLE (layer, mesh, bool, idx)
  ITEM_ICON = 3508889864,     -- (layer, idx, mesh, texture, itemId): item icon (moves are items, same id)
  FOCUS_IDX = 2603265800,     -- (layer) -> focused instance
  CURSOR_LOC = 381797568,     -- CMND_SET_CURSOR_LOCATOR (layer, crc32("cursor"), idx, instanceCount): enables the cursor attach of instance idx, disables the others < count
  SE = 1917805374,
  MENU_ACTIVE = 1558704558,   -- (menu, bool) input on/off
  MENU_SUSPEND = 1129326309,  -- (menu) hide while a child menu is open (team dock does this around sub menus)
  MENU_RESUME = 1453710531,   -- (menu)
  LAYER_VISIBLE = 711242136,
  OPEN_MENU = 433545986,      -- CMND_OPEN_MENU_OBJECT (menu, group)
  EXIST_MENU = 2231168902,    -- CMND_IS_EXIST_MENU_OBJECT (menu cmd)
  CLOSING_MENU = 1193349555,  -- CMND_IS_CLOSING_MENU_OBJECT 0x472111B3
  CLOSED_MENU = 1521844538,   -- CMND_IS_CLOSE_MENU_OBJECT 0x5AB5813A
  CLOSE_MENU = 320421347,     -- CMND_CLOSE_MENU_OBJECT
  P_HAS = 2947612279, P_GET = 3522198769, P_CLEAR = 3363400568, P_SET = 3860611758,   -- parameter store
  MSG_OPEN = 2289627655, MSG_BUSY = 898725220, MSG_DONE = 682363669,                  -- general (system) window
  -- ability board (try 3: rows ARE board skill slots)
  BOARD_INV = 632801955,      -- 0x25B7CAA3 (charaStHdl, boardSlot, kind): kind 2 -> overwrite present?; 0/1 -> invSkill handle
  INV_ITEM = 2662166687,      -- 0x9EAD709F (invHdl, 0) -> item (= move) id
  BOARD_PIECES = 1535890305,  -- 0x5B8BD381 (charaId) -> {piece effect index per board skill slot}, {category per slot}
  BOARD_EQUIP = 203046535,    -- 0x0C1A3E87 (charaId, invHdl, pieceEffectIdx): put a move item on that board piece
                              --   (handler 0xC75CD0 -> 0xE7D310 equip + 0xD80B40 piece; prog_common.AddSkillItemAndLearnWithBoard)
  SKILL_POS = 26437624,       -- 0x019367F8 (charaStHdl, skill) -> position in skill_list (>= 6: absent)
  -- team aura slots (retail equip_aura_skill_menu): save teamInfoList.auraSkillSlotInfoList {charaStHdl, skillId} x4
  TEAM_INFO = 1033065575,     -- CMND_GET_TEAM_SET_INFO (dockNo, dockType, 15, slot) -> ok, charaStHdl, skillId
  TEAM_AURA_SET = 1506470613, -- 0x59CAEAD5 (dockNo, dockType, 6, slot, charaStHdl, skillId)
  -- vr-loader commands (try 10; docs/game/skill-slots.md §7.2, docs/game/vr-loader.md): the board's own handle-based path
  -- (docs/game/vr-loader.md §1, API 1, frozen): unknown hash (no loader) -> a single false
  EVT_VERSION = 2217361807, -- () -> api, modules bitmask (bit0 = board)
  EVT_PLACE = 2988165721,   -- (charaStHdl, invHdl, boardSlot) -> status, effectiveInv (1 = done+verified; opens a closed piece)
  EVT_CLEAR = 599222418,   -- (charaStHdl, boardSlot, keepOpen) -> status, effectiveInv (native item back; -6 = would close the piece)
  EVT_LAYOUT = 4142930670, -- (charaStHdl, inv3, inv4, inv5, inv8) -> status, openMaskBefore, openMaskAfter (try 18)
  EVT_LOG = 3661580131,             -- (...) -> writes to evt_loader\loader.log
  EVT_PIECE = 2194444983,   -- (charaStHdl, boardSlot) -> piece (0..254, 255 closed, <0 error), effInv, placedInv, baseInv
  -- invSkill handle for a move that is not on this player's board (try 9): the list only gives item ids
  ADD_ITEM = 1897915498,      -- 0x711FE46A CMND_ADD_ITEM_ONLY (itemId, count, flag) -> invSkill handle (prog_common.AddSkillItemAndLearnWithBoard)
  DEL_ITEM = 425598937,       -- 0x195E1FD9 CMND_DELETE_ITEM (itemId, count): undo the +1 so the stock does not change
  -- menu textures (save-slot menu / kizuna_town_menu_inc): the load is asynchronous
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = 839427544,       -- CMND_LOAD_MENU_RES_TEXTURE (path)
  TEX_LOADING = 1506186496,   -- (textureCrc) -> true while still loading
}
local SE_OK, SE_DECIDE, SE_BACK, SE_NG, SE_REMOVE = 3848881948, 4235359837, 202039849, 2086672038, 2339718859
local EVT_TEAM_AURA_SLOTS = 4

-- ---- 2026-09-24: level-locked rows drawn "off", Prime cards with a fixed moveset --------------------------------------
-- Locked row = our evt_item_list_base_lock01 (research/scripts/ss_lock_row_tex.py: item_list_base01 in the retail
-- "disabled list row" navy, loaded like the Hiper base) + the retail lock icon (soccer11_20 icon_lock_passive01, a menu
-- resource of this screen) on the row's left icon node _icon_equip01 + "Nv. N" in the retail grey-out text colour.
-- Prime (chara_param col 41 = 10): all rows are fixed = his learnset 1-6 by level (vr-loader CMND_EVT_PRIME_MOVES,
-- board.prime_fixed_moves); every row carries the lock icon, nothing can be picked or removed.
-- (fields of ONE table: the main chunk of this script is at Lua 5.2's limit of 200 local variables)
local PL = {
  LOCK_TEX = "#/menu/00_soccer/soccer11/evt_soccer11_08_lock/evt_item_list_base_lock01.g4tx",
  LOCK_TEX_CRC = 435411157,       -- crc32(LOCK_TEX)
  LOCK_SPRITE = 3122807489,       -- evt_item_list_base_lock01
  TEX_S11_20 = 4021797290,        -- #/menu/00_soccer/soccer11/soccer11_20/soccer11_20.g4tx
  ICON_LOCK = 1502905245,         -- icon_lock_passive01 (36 x 40 grey lock)
  ICON_EQUIP_NODE = 2346103015,   -- icon_equip01 (texture slot of the mesh _icon_equip01)
  LOCK_COLOR = "[CGRAYOUT04]",    -- font_color GRAYOUT04 (light grey, readable on the navy base)
  PRIME_RARITY = 10,
  PRIME_CMD = 533163231,   -- (charaStHdl, apply) -> isPrime, level, s1, l1 ... s6, l6
  PRIME_GUIDE = "Carta Prime: sus supertécnicas son fijas y se desbloquean por nivel.",
  -- 2026-09-27: learnset of the shown player (chara_param slots 1-9, slot 9 = Hiper) from the vr-loader
  -- CMND_VRFW_CHARACTER_LEARNSET (VR-Framework learn-level service, 2.0.5; was CMND_EVT_LEARNSET, now its alias); fallback = the retail learn table 0xCF25A8AF (slots 1-6). A locked row shows
  -- the move it will learn (lock + name + icon); a custom Idol (EVT_IDOL_FRAME of soccer_common, moment_idol_build.py)
  -- keeps its learnset rows fixed (learned or still locked), only its empty learnset slots take a pick.
  LEARNSET_CMD = 1491603481,      -- crc32("CMND_VRFW_CHARACTER_LEARNSET") (charaStHdl) -> ok, {9 skills}, {9 levels}
  learnset = {hdl = -1},
  idol = {hdl = -1},
  IDOL_GUIDE = "Carta Ídolo: sus supertécnicas propias son fijas; las ranuras libres admiten cualquier técnica.",
  lock_tex = 0,                   -- 0 not requested, 1 loading, 2 ready
  lock_pending = {},              -- rows waiting for the texture
  prime = {hdl = -1},
  -- move panel polish + clean lock (2026-09-24): research/scripts/ss_parts_tex.py, a MENU_RES of this screen
  PARTS_TEX = 1241611320,   -- crc32("#/menu/102_team/team02/evt_ss_parts/evt_ss_parts.g4tx")
  BAND = {968409197, 2695991767, 3619070273, 1238512866, 1054147700, 2816234958},
  WLV = {[2861188530] = 1188988279, [864228360] = 3755463885, [1149510814] = 2832262235},
  LOCK_LIGHT = 3148165984,   -- on the navy "off" rows and the purple Hiper row
  LOCK_DARK = 4222515565,     -- on white rows (Prime)
  -- ability_list_menu filter / tab parameter keys (bluebg OnInit t3 + 773844157 start tab)
  LIST_KEYS = {1498333934, 3225916244, 3074466754, 690239073, 1579353847, 3341440845, 2552568759, 19679757, 773844157},
}

local evt_co = nil
local evt_back_frames = -1
evt_back_seen = false                     -- (global: no new main-chunk local; the back-key diagnostic of Step)
local evt_hiper_tex = 0          -- purple base texture: 0 not requested, 1 loading, 2 ready
local evt_hiper_pending = false  -- row 0 still waits for it (applied from Step)
local evt_shown = nil               -- try 20: player whose layout/mirror ran last (charaStHdl)
local evt_layout_done = {}       -- try 19: players whose layout the loader checked during this visit

-- Request the purple base texture once; true when it can be used.
local function EVT_HiperTexReady()
  if evt_hiper_tex == 0 then
    funcLuaMenuCommand(C.LOAD_TEX, EVT_HIPER_TEX)
    evt_hiper_tex = 1
  end
  if evt_hiper_tex == 1 and not funcLuaCommand(C.TEX_LOADING, EVT_HIPER_TEX_CRC) then
    evt_hiper_tex = 2
  end
  return evt_hiper_tex == 2
end

function PL.LockTexReady()
  if PL.lock_tex == 0 then
    funcLuaMenuCommand(C.LOAD_TEX, PL.LOCK_TEX)
    PL.lock_tex = 1
  end
  if PL.lock_tex == 1 and not funcLuaCommand(C.TEX_LOADING, PL.LOCK_TEX_CRC) then
    PL.lock_tex = 2
  end
  return PL.lock_tex == 2
end

-- Row base: purple sprite on the special row (0), the retail white one on the others, the navy "off" one on a
-- level-locked row (2026-09-24).
local function EVT_SetRowBase(a1, locked)
  if locked then
    if PL.LockTexReady() then
      funcLuaMenuCommand(C.SPRITE, L_ROW, PL.LOCK_TEX_CRC, PL.LOCK_SPRITE, EVT_ROW_BASE, 0, a1)
      PL.lock_pending[a1] = nil
    else
      PL.lock_pending[a1] = true
    end
    return
  end
  PL.lock_pending[a1] = nil
  if a1 == 0 then
    if EVT_HiperTexReady() then
      funcLuaMenuCommand(C.SPRITE, L_ROW, EVT_HIPER_TEX_CRC, EVT_HIPER_SPRITE, EVT_ROW_BASE, 0, 0)
      evt_hiper_pending = false
    else
      evt_hiper_pending = true
    end
  else
    funcLuaMenuCommand(C.SPRITE, L_ROW, EVT_ROW_TEX, EVT_ROW_BASE, EVT_ROW_BASE, 0, a1)
  end
end

local EVT_RetailOnInit = OnInit
function OnInit()
  EVT_RetailOnInit()
  EVT_HiperTexReady()   -- start loading early; the rows are set up later
  PL.LockTexReady()
end

local function P_Set(key, v)
  funcLuaCommand(C.P_CLEAR, key)
  funcLuaCommand(C.P_SET, key, 0, v, 1)
end

-- ids are unsigned 32-bit; they cross menus as hex text (Lua 5.2 "%d" overflows above 2^31 on Windows)
local function EVT_U32(id)
  id = tonumber(id) or 0
  if id < 0 then
    id = id + 4294967296
  end
  return id
end

local function EVT_IsSpecial(skill)
  if skill == nil or skill == 0 then
    return false
  end
  local ok, cat = funcLuaCommand(C.SKILL_INFO, skill, 9)
  return ok and cat == 8
end

-- ---- vr-loader + row mapping ---------------------------------------------------------------------------------
-- The loader is present when CMND_EVT_LOADER_VERSION answers api >= 1 with the board module bit set.
local function EVT_Call(cmd, ...)
  if PL.CR_BOARD[cmd] ~= nil then
    cmd = PL.BoardCommand(cmd, ...)              -- the aura slot (board slot 8) without IF: Character Reforged's command
  end
  local ok, a, b, c, d = pcall(funcLuaCommand, cmd, ...)
  if not ok then
    return nil
  end
  return a, b, c, d
end

-- 2026-10-14: capability checks of the services an action really uses (the old check asked CMND_EVT_LOADER_VERSION's
-- board bit, which only Inazuma Fantasy lit, and blocked every edit without it). A command nobody declares answers a
-- single false; a declared one answers its status or more than one value, so a call with handle 0 changes nothing.
--   board service (CMND_EVT_BOARD_PIECE / PLACE / CLEAR / LAYOUT, Inazuma Fantasy's board.lua): the board mirror of the
--   rows, board slot 8 of the aura; without it the match list (CMND_SET_SKILL) and the team aura row
--   (TEAM_AURA_SET) are written alone, both retail
--   custom passive (CMND_EVT_SIXSENSE): the slot; player sets (CMND_CHARACTERREFORGED_PLAYER_SET_GET, Character
--   Reforged's scripts\player_sets.lua): the set store
-- One «loader check» log line per missing service and screen visit.
PL.SERVICE_PROBE = {board = {C.EVT_PIECE, 0, 0}, six_sense = {1074115993 --[[CMND_EVT_SIXSENSE]], 0, 0, 0, -1},
  player_sets = {390397015 --[[CMND_CHARACTERREFORGED_PLAYER_SET_GET]], 0, 0}}
PL.service_logged = {}
function PL.HasService(name)
  local probe = PL.SERVICE_PROBE[name]
  local answer, second = nil, nil
  if probe ~= nil then
    answer, second = EVT_Call(table.unpack(probe))
  end
  local present = type(answer) == "number" or second ~= nil   -- PLAYER_SET_GET(0, 0) answers false, ""
  if not present and name == "board" and PL.SERVICE_PROBE.aura_slot ~= nil and PL.HasService("aura_slot") then
    PL.service_logged[name] = true               -- Character Reforged's board commands stand in: nothing to report
  end
  if not present and not PL.service_logged[name] then
    PL.service_logged[name] = true
    EVT_Call(C.EVT_LOG, "skill_slots", "loader check", name, "service missing")
  end
  return present
end
local function EVT_HasBoard()
  return PL.HasService("board")
end
-- 2026-10-14 (owner: pressing the aura half did nothing without Inazuma Fantasy): the AURA SLOT's board writes (board
-- slot 8 only: place, clear, read) go to Character Reforged's own commands (scripts\board_slots.lua, the same
-- arguments and answers) when IF's board service is missing. Every other board write of this screen (the forced
-- layout, the board mirror of the rows) stays IF's: without IF the rows are the projection of the list, untouched.
PL.CR_BOARD = {[C.EVT_PLACE] = 3270716539 --[[CMND_CHARACTERREFORGED_BOARD_PLACE]],
  [C.EVT_CLEAR] = 1398771376 --[[CMND_CHARACTERREFORGED_BOARD_CLEAR]],
  [C.EVT_PIECE] = 4062475413 --[[CMND_CHARACTERREFORGED_BOARD_PIECE]]}
PL.SERVICE_PROBE.aura_slot = {4062475413 --[[CMND_CHARACTERREFORGED_BOARD_PIECE]], 0, 0}
-- the board slot argument of each command: PLACE (hdl, inv, slot), CLEAR / PIECE (hdl, slot, ...)
function PL.BoardCommand(cmd, hdl, a, b)
  local slot = cmd == C.EVT_PLACE and b or a
  if slot ~= EVT_HIPER_SLOT or EVT_HasBoard() or not PL.HasService("aura_slot") then
    return cmd
  end
  return PL.CR_BOARD[cmd]
end
-- the aura slot can be written: IF's board service or Character Reforged's aura slot commands
function PL.AuraSlotWritable()
  return EVT_HasBoard() or PL.HasService("aura_slot")
end

-- first board slot of the normal branch. Try 18: always 3 (branch 1, slots 3-5); tries 10-17 followed the route
-- switcher of the original board (3 or 6), which broke when branch 2 was partly closed (Byron: 19, 255, 255).
function EVT_BranchBase()
  return 3
end

-- 2026-10-14 (Character Reforged: the new set is a PROJECTION over the game's own list, docs/refactor/
-- aura-mods-split.md «The 6 + 2 set over the retail data»): rows 1-6 are the list positions that hold a special move
-- (or nothing), in list order; a position holding an aura (keshin, totem, Mix-Max, «Modo cambio»: the aura / mix
-- slots' moves) is skipped and KEPT, hidden; the rows left over take those positions last and show empty (writing one
-- first moves its aura to its slot when that is free: PL.FreeListPos). Nothing is rewritten to show the set (the old
-- PL.AuraSlotCleanup moved auras off rows 1-6 when a player was shown; it is no longer called). PL fields only.
PL.special_of = {}
function PL.ProjPos(row)
  if n == nil or n == 0 then
    return row - 1
  end
  local free, boarded, empty, aura = {}, {}, {}, {}
  for p = 0, EVT_NORMAL_NUM - 1 do
    local id = funcLuaCommand(C.GET_SKILL, n, p)
    id = (id ~= nil) and EVT_U32(id) or 0
    if id == 0 then
      id = PL.BoardTechniqueAt(p)                -- an empty position shows its board cell's technique
      if id ~= 0 then
        boarded[#boarded + 1] = p
      else
        empty[#empty + 1] = p
      end
    elseif PL.IsSpecialCached(id) then
      aura[#aura + 1] = p
    else
      free[#free + 1] = p
    end
  end
  -- 2026-10-15 (owner): the list's techniques, then the positions filled from their board cell (the order of
  -- CharacterReforged.EffectiveSkillSet), then the empty ones, the hidden aura positions last
  for _, p in ipairs(boarded) do
    free[#free + 1] = p
  end
  for _, p in ipairs(empty) do
    free[#free + 1] = p
  end
  for _, p in ipairs(aura) do
    free[#free + 1] = p
  end
  return free[row] or (row - 1)
end
function PL.IsSpecialCached(id)
  local sp = PL.special_of[id]
  if sp == nil then
    sp = EVT_IsSpecial(id) == true
    PL.special_of[id] = sp
  end
  return sp
end
-- the move on board cell `p` (placed item, else native), 0 for none
function PL.BoardMoveAt(p)
  local inv = funcLuaCommand(C.BOARD_INV, n, p, 1)
  if inv == nil or inv == 0 then
    inv = funcLuaCommand(C.BOARD_INV, n, p, 0)
  end
  if inv == nil or inv == 0 then
    return 0
  end
  return EVT_U32(funcLuaCommand(C.INV_ITEM, inv, 0))
end
-- the technique board cell `p` adds to the rows, 0 for none: never an aura, never a move already in the match list or
-- shown by an earlier empty position (the dedupe of CharacterReforged.EffectiveSkillSet)
function PL.BoardTechniqueAt(p)
  local id = PL.BoardMoveAt(p)
  if id == 0 or PL.IsSpecialCached(id) then
    return 0
  end
  local at = funcLuaCommand(C.SKILL_POS, n, id)
  if at ~= nil and at >= 0 and at < EVT_NORMAL_NUM then
    return 0
  end
  for q = 0, p - 1 do
    local listed = funcLuaCommand(C.GET_SKILL, n, q)
    if (listed == nil or listed == 0) and PL.BoardMoveAt(q) == id then
      return 0
    end
  end
  return id
end

-- row -> board skill slot: Hiper = 8, rows 1-6 = the board slot of their list position (the board mirrors the list)
local function EVT_BoardSlot(row)
  if row == 0 then
    return EVT_HIPER_SLOT
  end
  return PL.ProjPos(row)
end

-- row -> position in the match list skill_list (nil = none: the Hiper row is never in the list)
local function EVT_ListPos(row)
  if row == 0 then
    return nil
  end
  return PL.ProjPos(row)
end

-- Move currently effective on a board skill slot and its invSkill handle.
-- Handler 0xC767E0 of 0x25B7CAA3: kind 1 = +0x94 (skillEquipInvInfo: the item placed by the player),
-- kind 0 = +0xC8 (skillEquipInvInfoOverWrite: the slot's base/native item) if set, else +0x94; kind 2 = bool(+0xC8).
-- Save census (try 5): the match list holds +0x94 when it is set, else +0xC8 -> read kind 1 first, then kind 0.
-- (Tries 3-4 read kind 1 only when +0xC8 was set, which returned 0 = "---" for slots whose +0x94 is empty.)
local function EVT_BoardSkill(bslot)
  if n == nil or n == 0 or bslot == nil then
    return 0, 0
  end
  local inv = funcLuaCommand(C.BOARD_INV, n, bslot, 1)
  if inv == nil or inv == 0 then
    inv = funcLuaCommand(C.BOARD_INV, n, bslot, 0)
  end
  if inv == nil or inv == 0 then
    return 0, 0
  end
  return EVT_U32(funcLuaCommand(C.INV_ITEM, inv, 0)), inv
end

local EVT_TeamAuraOf   -- defined below (team aura slot of this player)

local function EVT_ListSkill(pos)
  local id = funcLuaCommand(C.GET_SKILL, n, pos)
  return (id ~= nil) and EVT_U32(id) or 0
end

-- Prime card of the shown player (cached per player). The loader answers with his learnset and writes the fixed
-- match list (apply = 1); without it the rarity alone marks him (rows then show the match list, nothing editable).
function EVT_PrimeInfo()
  if PL.prime.hdl == n then
    return PL.prime
  end
  PL.prime = {hdl = n, on = false}
  if n == nil or n == 0 then
    return PL.prime
  end
  local r = {pcall(funcLuaCommand, PL.PRIME_CMD, n, PL.readonly and 0 or 1)}   -- read-only: no write
  if r[1] and r[2] == true then
    PL.prime.on, PL.prime.level, PL.prime.skill, PL.prime.lv = true, r[3], {}, {}
    for k = 1, EVT_NORMAL_NUM do
      PL.prime.skill[k] = EVT_U32(r[2 + 2 * k] or 0)
      PL.prime.lv[k] = tonumber(r[3 + 2 * k]) or 0
    end
  elseif funcLuaCommand(C.CHARA_GET, n, 12) == PL.PRIME_RARITY then
    PL.prime.on = true
  end
  if PL.prime.on then
    EVT_Call(C.EVT_LOG, "skill_slots", "prime", n, "loader", PL.prime.skill ~= nil, "level", PL.prime.level)
  end
  return PL.prime
end

function EVT_IsPrime()
  return EVT_PrimeInfo().on
end

-- Hiper row: the special on board slot 8, else the one in this player's team aura slot.
-- Rows 1-6: the match list (what the match uses); an empty list position shows the board slot's move.
-- Prime rows 1-6: his fixed learnset move (also while it is still level-locked).
local function EVT_Skill(row)
  if row == 0 then
    local skill = EVT_BoardSkill(EVT_HIPER_SLOT)
    if EVT_IsSpecial(skill) then
      return skill
    end
    local aura = EVT_TeamAuraOf ~= nil and EVT_TeamAuraOf() or 0
    return EVT_IsSpecial(aura) and aura or 0
  end
  local p = EVT_PrimeInfo()
  if p.on and p.skill ~= nil then
    return p.skill[row] or 0
  end
  local skill = EVT_ListSkill(EVT_ListPos(row))
  if skill ~= 0 then
    if EVT_IsSpecial(skill) then
      return 0                                     -- an aura kept hidden on this position (the projection)
    end
    return skill
  end
  -- the board cell's technique: never an aura (retail board), never a duplicate of a listed move
  return PL.BoardTechniqueAt(EVT_BoardSlot(row))
end

-- 2026-09-27: the shown player's learnset (see PL above). skill[k] / lv[k], k = chara_param slot 1-9.
function PL.Learnset()
  if PL.learnset.hdl == n then
    return PL.learnset
  end
  local ls = {hdl = n, skill = {}, lv = {}, loader = false}
  PL.learnset = ls
  if n == nil or n == 0 then
    return ls
  end
  local ok, ids, lvs = EVT_Call(PL.LEARNSET_CMD, n)
  if ok == true and type(ids) == "table" and type(lvs) == "table" then
    ls.loader = true
    for k = 1, 9 do
      ls.skill[k] = EVT_U32(ids[k] or 0)
      ls.lv[k] = tonumber(lvs[k]) or 0
    end
    return ls
  end
  local okr, rids, rlvs = funcLuaCommand(C.LEARNABLE, n)      -- retail / learn_levels plate table: slots 1-6
  if okr and type(rids) == "table" then
    for k = 1, EVT_NORMAL_NUM do
      ls.skill[k] = EVT_U32(rids[k] or 0)
      ls.lv[k] = (type(rlvs) == "table" and tonumber(rlvs[k])) or 0
    end
  end
  return ls
end

-- custom Idol card (moment_idol_build.py): its chara_param id is a key of EVT_IDOL_FRAME (soccer_common data child)
function PL.IsIdol()
  if PL.idol.hdl == n then
    return PL.idol.on
  end
  local on = false
  if n ~= nil and n ~= 0 and type(EVT_IDOL_FRAME) == "table" then
    local param = funcLuaCommand(C.CHARA_GET, n, 4)
    if type(param) == "number" then
      on = EVT_IDOL_FRAME[EVT_U32(param)] ~= nil or EVT_IDOL_FRAME[param] ~= nil
    end
  end
  PL.idol = {hdl = n, on = on}
  return on
end

-- learnset slot of a row: rows 1-6 = slots 1-6, the Hiper row = slot 9
function PL.RowSlot(row)
  if row == 0 then
    return 9
  end
  return EVT_ListPos(row) + 1
end

-- The move a row shows: what it holds (EVT_Skill), else, while level-locked, the move the slot will learn; the
-- Hiper row of an Idol shows its learnset Hiper (slot 9) before the piece is opened / placed.
function PL.RowMove(row)
  local s = EVT_Skill(row)
  if s ~= 0 then
    return s
  end
  local ls = PL.Learnset()
  local m = ls.skill[PL.RowSlot(row)] or 0
  if row == 0 then
    return (PL.IsIdol() and EVT_IsSpecial(m)) and m or 0
  end
  local locked = EVT_IsLocked(row)
  return locked and m or 0
end

-- Idol rule (2026-09-27, user): a row whose learnset slot holds a move (learned or still locked) cannot be edited;
-- the empty learnset slots stay free. Prime cards keep their own (all fixed) rule.
function PL.IdolFixed(row)
  if row == nil or row < 0 or row >= EVT_ROW_NUM or not PL.IsIdol() then
    return false
  end
  local ls = PL.Learnset()
  local m = ls.skill[PL.RowSlot(row)] or 0
  if row == 0 then
    return EVT_IsSpecial(m)
  end
  return m ~= 0
end

-- true when the move is in the match list (save skill_list)
local function EVT_Active(skill)
  if skill == 0 then
    return false
  end
  local pos = funcLuaCommand(C.SKILL_POS, n, skill)
  return pos ~= nil and pos >= 0 and pos < 6
end

local function EVT_Current()
  local cur = {}
  for r = 0, EVT_ROW_NUM - 1 do
    cur[r] = EVT_Skill(r)
  end
  return cur
end

local function EVT_Name(skill)
  if skill == nil or skill == 0 then
    return "---"
  end
  local ok, nameId = funcLuaCommand(C.SKILL_INFO, skill, 4)
  if ok and nameId then
    local s = funcLuaCommand(C.NAME_TEXT, nameId)
    if s ~= nil and s ~= "" then
      return s
    end
  end
  return string.format("%08X", skill)
end

-- Level at which a row unlocks; 0 = always free.
function EVT_UnlockLevel(row)
  if row == 0 then
    -- 2026-09-27: an Idol's Hiper (learnset slot 9) unlocks at its chara_param level (Victor: Tótem lobo at 70)
    if PL.IsIdol() then
      local ls = PL.Learnset()
      local m = ls.skill[9] or 0
      if m ~= 0 and EVT_IsSpecial(m) and (ls.lv[9] or 0) > 1 then
        return ls.lv[9]
      end
    end
    return 0
  end
  local slot = EVT_ListPos(row)
  local p = EVT_PrimeInfo()
  if p.on and p.lv ~= nil then
    return (p.lv[row] or 0) > 1 and p.lv[row] or 0   -- Prime: every row by its learn level (rows 5-6 too)
  end
  if EVT_ALWAYS_FREE[slot + 1] then
    return 0
  end
  if n ~= nil and n ~= 0 then
    local ok, ids, lvs = funcLuaCommand(C.LEARNABLE, n)
    if ok and type(lvs) == "table" and type(lvs[slot + 1]) == "number" and lvs[slot + 1] > 0 then
      return lvs[slot + 1]
    end
  end
  return EVT_UNLOCK_LEVEL_FALLBACK[slot + 1] or 0
end

function EVT_IsLocked(row)
  local need = EVT_UnlockLevel(row)
  if need <= 1 then
    return false, need
  end
  local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  return lv < need, need
end

-- ---- retail overrides: 7 rows (row 0 uses the retail "outfit" row skin to stand apart) ----------------------
function CreateEquipTypeTable()
  t = {0, 0, 0, 0, 0, 0, 0}
end
function GetEquipTypeNum()
  return EVT_ROW_NUM
end
function GetEquipType(a1)
  if a1 == nil or a1 < 0 or a1 >= EVT_ROW_NUM then
    return -1
  end
  return 0   -- try 11: the Hiper row uses the same white row as the others (only the "Hiper" prefix marks it)
end
function GetEquipListItemInfo(a1)
  return t3[a1] or t3[0]
end
function GetEquipItemIdByLayerIdx(a1)
  return EVT_Skill(a1)
end
function UpdateEquippedVisibleCheck(a1)
end

-- One row: "N   <move>" (normal) / "Hiper   <move>" (special) + the move's item icon; locked rows dimmed.
function UpdateEquipListItem(a1)
  if a1 == nil or a1 < 0 or a1 >= EVT_ROW_NUM then
    return
  end
  if a1 == 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
    -- try 20: UpdateEquipCondition is never called by this menu (try 19 log: no LAYOUT/PIECE call at all), so the
    -- per-player layout + board mirror run here, once per shown player (row 0 is drawn first on open / L-R change)
    if evt_shown ~= n and n ~= nil and n ~= 0 then
      evt_shown = n
      PL.prime = {hdl = -1}             -- re-read the Prime data (and let the loader write his fixed list)
      PL.learnset, PL.idol = {hdl = -1}, {hdl = -1}
      if EVT_EnforceLayout ~= nil then
        EVT_EnforceLayout()
      end
      if EVT_SyncBoard ~= nil then
        EVT_SyncBoard()
      end
      if EVT_IdolHiperPlace ~= nil then
        pcall(EVT_IdolHiperPlace)       -- 2026-09-27: an Idol's unlocked learnset Hiper onto slot 8 when it is empty
      end
    end
  end
  local info = GetEquipListItemInfo(GetEquipType(a1))
  local icon_tex = 1875672568 --[[icon_item_dmy01: retail uses it for every row skin, incl. the outfit one]]
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, 3515732558 --[[_icon_equip01]], false, a1)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, 3830297508 --[[_gtxt_item01]], false, a1)
  local locked, need = EVT_IsLocked(a1)
  local skill = PL.RowMove(a1)          -- 2026-09-27: a locked row shows the move it will learn (name + icon)
  local prime = EVT_IsPrime()
  local text
  if locked then
    -- 2026-09-24: "off" row: navy base, lock icon, "Nv. N" + the move (Prime / learnset) in grey
    text = PL.LOCK_COLOR .. string.format("Nv. %d", need)
    if skill ~= 0 then
      text = text .. "   " .. EVT_Name(skill)
    end
    text = text .. "[C]"
  elseif skill ~= 0 then
    text = EVT_Name(skill)
    if a1 > 0 and not prime and not EVT_Active(skill) then
      -- on the board slot but not in the match list: the name greyed, as the retail lists grey what cannot be used
      -- (2026-10-14, owner: never a word appended to the name)
      text = PL.LOCK_COLOR .. text .. "[C]"
    end
  else
    text = ""                                      -- an empty row: the plate alone (owner 2026-10-14: no «---»)
  end
  if a1 == 0 and EVT_SPECIAL_LABEL ~= "" then
    text = EVT_SPECIAL_LABEL .. "   " .. text
  end
  funcLuaMenuCommand(C.TEXT, L_ROW, info.itemTextName, text, a1)
  funcLuaMenuCommand(C.TEXT_ALPHA, L_ROW, a1, info.itemTextName, 1)
  -- special row: purple base sprite (try 17). Tries 13-15 tinted with 801406373 (mesh names) and 635730757
  -- (item_list_base01_mat_01): no visible effect, so the sprite itself is swapped instead.
  EVT_SetRowBase(a1, locked)
  -- lock icon on the row's left icon node (retail equip-type icon, unused here): level-locked rows, Prime rows and
  -- the fixed learnset rows of an Idol (2026-09-27)
  local lock_icon = locked or prime or PL.IdolFixed(a1)
  if lock_icon then
    -- polish: our clean 48 x 52 lock (the retail icon_lock_passive01 has a white halo and was stretched: "doubled")
    local spr = (locked or a1 == 0) and PL.LOCK_LIGHT or PL.LOCK_DARK
    funcLuaMenuCommand(C.SPRITE, L_ROW, PL.PARTS_TEX, spr, PL.ICON_EQUIP_NODE, 0, a1)
  end
  -- 2026-10-13 (owner): rows 1-6 are MOVE PLATES (PL.RowPlate: layer evt_ss_row_plate on the row, the retail
  -- soccer11_09 plate filled by SetupCharaSkillItem); the row's white base, text, lock icon and right-hand item icon
  -- give way to it. The row keeps its cyan focus frame and touch quad. The old look comes back if the plate fails.
  -- The plate goes FIRST: the row's right-hand move icon (the category ball) is not filled under a plate at all (its
  -- item-icon fill shows the mesh again once the icon has loaded, after any hide: owner, the old icon behind the plate).
  local on = false
  if a1 > 0 and PL.RowPlate ~= nil then
    local inactive = skill ~= 0 and not locked and not prime and not EVT_Active(skill)
    local okp, r = pcall(PL.RowPlate, a1, skill, locked, need, lock_icon and not locked, inactive)
    if not okp then
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "row plate error", a1, tostring(r))
    end
    on = okp and r == true
    funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, PL.RP.ROW_BASE, not on, a1)
    funcLuaMenuCommand(2735666188 --[[text visible]], L_ROW, info.itemTextName, not on, a1)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, 3515732558 --[[_icon_equip01]], lock_icon and not on, a1)
  if skill ~= 0 and not on and not (a1 == 0 and PL.HS_ON and not locked) then
    funcLuaMenuCommand(C.ITEM_ICON, L_ROW, a1, info.itemIconMeshName, icon_tex, skill)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, info.itemIconMeshName, true, a1)
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, info.itemIconMeshName, false, a1)
  end
end

local function EVT_RefreshRows()
  for i = 0, EVT_ROW_NUM - 1 do
    UpdateEquipListItem(i)
  end
end

-- Cut a UTF-8 string to at most n bytes without splitting a character.
local function EVT_Cut(s, n)
  if #s <= n then
    return s
  end
  local k = n
  while k > 0 do
    local b = string.byte(s, k + 1)
    if b == nil or b < 128 or b >= 192 then
      break
    end
    k = k - 1
  end
  return string.sub(s, 1, k) .. "…"
end

-- Word-wrap s into at most `lines` lines of <= n bytes; the last line takes the rest, cut with "…" if needed.
local function EVT_Wrap(s, n, lines)
  local out = {}
  if lines <= 0 then
    return out
  end
  local cur, cur_pos = "", 1
  for pos, w in string.gmatch(s, "()(%S+)") do
    local cand = cur == "" and w or (cur .. " " .. w)
    if #cand <= n or cur == "" then
      if cur == "" then
        cur_pos = pos
      end
      cur = cand
    else
      out[#out + 1] = cur
      cur, cur_pos = w, pos
      if #out == lines - 1 then
        break
      end
    end
  end
  if cur ~= "" then
    if #out == lines - 1 then
      cur = string.gsub(string.sub(s, cur_pos), "%s+", " ")   -- last line: everything left
    end
    out[#out + 1] = EVT_Cut(cur, n)
  end
  return out
end

-- The card's parameter box holds 3 short lines in retail ("Potencia +35 / Control +35", built with the text
-- template 2418446954): line 1 = "<area>   Potencia N", lines 2-3 = the description wrapped.
function EVT_SkillInfoText(skill)
  local okp, power = funcLuaCommand(C.SKILL_INFO, skill, 6)
  if okp and type(power) == "number" and power > 0 then
    return string.format("Potencia %d", power)
  end
  return ""
end

-- Right info window (the accessory "info easy" window): move icon, name, area/power + short description.
local function EVT_SetupSkillInfo(skill)
  funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 303536660 --[[_icon_item_dmy01]], 1875672568 --[[icon_item_dmy01]], skill)
  funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 2334051246 --[[_icon_item_dmy02]], 4140117058 --[[icon_item_dmy02]], skill)
  funcLuaMenuCommand(C.TEXT, L_INFO, 456522680 --[[_text_item01]], EVT_Name(skill), 0)
  funcLuaMenuCommand(C.TEXT, L_INFO, 3138144965 --[[_text_parameter01]], EVT_SkillInfoText(skill), 0)
  SetVisibleEquipmentNum(L_INFO, 0, false)
  SetVisibleStockNum(L_INFO, 0, false)
  funcLuaMenuCommand(1233047821, L_INFO, 0, 3974820126, false)
  funcLuaMenuCommand(1233047821, L_INFO, 0, 3334923667 --[[num_have01]], false)
  -- special moves: the keshin / miximax / soul "character" (SKILL_INFO 17 = tempAuraCharaId, what the aura detail
  -- window shows with SwapLayerFaceIconTex), drawn like retail item cards that belong to a character
  -- (SetupEquipInfoWindow: 0x20EB2104 on _item_chr_dmy01). Other moves: the item icon only.
  local aura_chara = 0
  if EVT_IsSpecial(skill) then
    local ok, cid = funcLuaCommand(C.SKILL_INFO, skill, 17)
    if ok and cid ~= nil then
      aura_chara = cid
    end
  end
  if aura_chara ~= 0 then
    -- keshin / armour / totem characters have no list face icon: their aura art (PL.AuraPortrait)
    pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L_INFO, 0, 2052777044 --[[item_chr_dmy01]])
    local okd, drawn = pcall(PL.AuraPortrait, L_INFO, 0, 2787359195 --[[_item_chr_dmy01]], 2052777044, skill)
    aura_chara = (okd and drawn) and aura_chara or 0
  end
  if aura_chara ~= 0 then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2634282032 --[[_item_chr_base01]], true, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2787359195 --[[_item_chr_dmy01]], true, 0)
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2634282032 --[[_item_chr_base01]], false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2787359195 --[[_item_chr_dmy01]], false, 0)
  end
  ClearItemPositionIcon(L_INFO, 0)
end

-- ---- move detail panel (2026-09-24): the ability board's own window --------------------------------------------------
-- Retail layer team02_02_skill_detail_info (blue header: element icon, name, power; category pill; TENSIÓN gauge + cost;
-- description; "IA activada"), filled exactly as ability_learning_board_menu.UpdateDetailWindow does: the retail
-- personal_plate_inc.SetupPersonalPlateSkillDetailInfo (INCLUDE("LUA_PERSONAL_PLATE_INC") is added by ss2_build.py)
-- with SetSkillItemLayerName(nil, team02_02, 0). Level badge = retail team13_26b_open_level_lock (the board's
-- "Nv. N" tab). Both are attached by the builder to two locators of our left-column layout (right column, lower half).
-- Special (category 8) moves keep the accessory card: the board uses 7 other aura windows for them.
local L_DETAIL = 2628045944      -- team02_02_skill_detail_info
local L_DETAIL_LV = 3654556750   -- team13_26b_open_level_lock
local EVT_DETAIL = true          -- false = back to the accessory card for every move
local EVT_DETAIL_LV_TAB = true   -- show the "Nv. N" badge (row unlock level) on rows that unlock above level 1
local EVT_DETAIL_HIDE_GRAPH = false  -- 2026-09-24: the panel sits left of the radar (ss2_build 8b), the stats stay visible
local EVT_DETAIL_LV_NUMS = {2772869257, 4268123864}   -- team13_26b number settings (MenuNumberSettingName)
local EVT_GRAPH_LAYERS = {{2334590304, 1}, {32151736, 1}, {732343773, 7},   -- soccer11_07 radar, its base, 7 numbers
  {3665300474, 1}}                                 -- soccer11_16 rpg attack / defence param (the dark stat box)
local evt_detail_on = false


-- 2026-10-14 (owner: the right page = Character Reforged's player page, graft plate_pages_skill_host): the page has
-- no stat radar and no hexagon panel, so the retail radar (and the rpg stat box) shows only while a panel of this
-- screen draws on it: the set preview's radar pages (layer evt_psp_base up) and Player Training's training view.
-- The page's per-frame body asks the same function (host_skill.lua keep_radar) before it hides the retail radar.
PL.L_SET_PREVIEW_BASE = 2931540226             -- evt_psp_base (graft pset_preview)
function EVT_SkillTableRadarWanted()
  local training = type(PlayerTraining) == "table" and PlayerTraining.TrainingMode or nil
  if type(training) == "table" and training.on == true then
    return true
  end
  local L = PL.L_SET_PREVIEW_BASE
  return funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) == true
    and funcLuaMenuCommand(1262717583 --[[CMND_IS_LAYER_VISIBLE]], L, 0) == true
end

function EVT_DetailGraphSync()
  -- v9: the Hiper panel spans the page to x 1890 (plate spec), over the stat radar: the radar goes while it shows
  local hide = (EVT_DETAIL_HIDE_GRAPH and evt_detail_on) or PL.hiper_wide == true or not EVT_SkillTableRadarWanted()
  if not EVT_DETAIL_HIDE_GRAPH and PL.graph_hidden ~= true and not hide then
    return
  end
  -- hiding remembers each instance's visibility (CMND_IS_LAYER_VISIBLE) and showing restores it: the stat box
  -- (soccer11_16) is shown by the retail menu only in some modes
  if hide and PL.graph_hidden ~= true then
    PL.graph_prev = {}
    for _, g in ipairs(EVT_GRAPH_LAYERS) do
      for i = 0, g[2] - 1 do
        PL.graph_prev[g[1] * 16 + i] = funcLuaMenuCommand(1262717583 --[[CMND_IS_LAYER_VISIBLE]], g[1], i) ~= false
      end
    end
  end
  for _, g in ipairs(EVT_GRAPH_LAYERS) do
    for i = 0, g[2] - 1 do
      local back = PL.graph_prev == nil or PL.graph_prev[g[1] * 16 + i] ~= false
      funcLuaMenuCommand(C.LAYER_VISIBLE, g[1], i, (not hide) and back)
    end
  end
  -- the big grey rounded panel on the right (343.png) = soccer11_05's page base _sixth_base01 (700 x 464 at x 1212,
  -- y 493): 2026-10-14 never shown (the player page's white card replaces it)
  funcLuaMenuCommand(C.MESH_VISIBLE, 2917320188 --[[soccer11_05_equip_status_base]], 2682382918 --[[_sixth_base01]],
    false, 0)
  PL.sixth_hidden = true
  PL.graph_hidden = hide
end

function EVT_DetailHide()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL_LV, 0, false)
  if PL.DetailHideAll ~= nil then
    pcall(PL.DetailHideAll)                       -- v7: the passive window and the Hiper panel too
  end
  evt_detail_on = false
end

-- "Nv. N" badge: green open lock (_pos_base02) when the player has the level, grey closed lock (_pos_base01) if not.
local function EVT_DetailLevelTab(row)
  if not EVT_DETAIL_LV_TAB or row == nil then
    return false
  end
  local locked, need = EVT_IsLocked(row)
  if need == nil or need <= 1 then
    return false
  end
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL_LV, 1517329426 --[[_pos_base01]], locked, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL_LV, 3279539624 --[[_pos_base02]], not locked, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL_LV, 3335603165 --[[_pos_num01]], true, 0)
  for _, num in ipairs(EVT_DETAIL_LV_NUMS) do
    local idx = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX]], L_DETAIL_LV, 0, num)
    if type(idx) == "number" and idx >= 0 then
      funcLuaMenuCommand(3609943765 --[[set number]], L_DETAIL_LV, 0, idx, need)
      funcLuaMenuCommand(1233047821 --[[number visible]], L_DETAIL_LV, 0, num, true)
    end
  end
  return true
end

-- Fill and show the panel for `skill` on `row`; false = not handled (special move / error): caller shows the card.
-- Polish (2026-09-24): after the retail fill, the same choices it made are redone with our sprites (evt_ss_parts):
-- the element band at the panel's aspect (full bleed, not squeezed), the graded band and no element icon before the
-- name. 2026-10-12 (Nacho): no move-type tag either (the coloured «Tiro» / «Ofensiva» / «Defensa» / «Portero»
-- rectangle above the plate: the retail pill _area_base01, its word _text_area01, locator _pos_area01), hidden after
-- every fill (the retail fill and PL.DetailRestore show it again).
PL.TYPE_TAG_MESH, PL.TYPE_TAG_TEXT, PL.TYPE_TAG_POS = 3516146179 --[[_area_base01]], 1899787537 --[[_text_area01]],
  2313134961 --[[_pos_area01]]
function PL.TypeTagOff()
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, PL.TYPE_TAG_MESH, false, 0)
  funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, PL.TYPE_TAG_TEXT, false, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, PL.TYPE_TAG_POS, false, 0)
end

function PL.DetailPolish(skill, pos)
  local ok, kind = funcLuaCommand(C.SKILL_INFO, skill, 7)
  if ok and kind == 5 then
    local ok2, common = funcLuaCommand(800895612, skill)
    if ok2 and common then
      kind = 6
    end
  end
  if ok and PL.BAND[kind] ~= nil then
    funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.BAND[kind], 243934124 --[[sp_base01]], 0, 0)
  end
  if pos ~= nil then
    local okw, wl = pcall(function()
      return GetPersonalPlateSkillEvoBaseTextureName(GetSkillEvoLevelByCharaStHdl(n, pos))
    end)
    if okw and PL.WLV[wl] ~= nil then
      funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.WLV[wl], 2861188530 --[[wlv_base01]], 0, 0)
    end
  end
  PL.TypeTagOff()
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 2164615260 --[[_icon_sp_area_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3543352325 --[[_icon_sp_area01_off]], false, 0)
  -- round 14 (Nacho): no description on the move detail (the text and the window's divider line); the window
  -- itself (_sp_win_base01) is already off; type / AT / TENSIÓN / AI / level stay
  funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, 691026122 --[[_text_flavor01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, CALC_CRC("_item_win_line01"), false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3303013605 --[[_sp_win_base01]], false, 0)
end

-- 2026-09-24: a passive (custom passive) in the same integrated panel as the moves (v6 fallback, see PL.PassiveDetail):
-- green band, the name on it, the description on the page; the move-only parts are hidden (and shown again by
-- PL.DetailRestore before the next move).
PL.DETAIL_MOVE_POS = {2313134961 --[[_pos_area01]], 923022909 --[[_pos_tension01]], 4081284803 --[[_pos_at01]]}
PL.DETAIL_MOVE_MESH = {563708378 --[[_gtxt_cmd_at01]], 1013569271 --[[_ai_use01]], 3384915402 --[[_wlv_base01]],
  559600405 --[[_icon_sp_sub_dmy01]], 1220252763 --[[_gtxt_longshoot01]], 1252573939 --[[_gtxt_override01]],
  2164615260 --[[_icon_sp_area_dmy01]], 3543352325 --[[_icon_sp_area01_off]], 3303013605 --[[_sp_win_base01]],
  3516146179 --[[_area_base01]]}
PL.DETAIL_MOVE_TEXT = {1899787537 --[[_text_area01]]}
PL.DETAIL_MOVE_PRIM = {2223127589 --[[AT power]], 3424269865 --[[tension cost]]}
function PL.DetailRestore()
  for _, m in ipairs(PL.MOVE_ROW_HIDE_MESH or {}) do      -- round 14: PL.MoveAsRow hid them on the last move
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, m, true, 0)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3303013605 --[[_sp_win_base01: off, as before]], false, 0)
  for _, pos in ipairs(PL.DETAIL_MOVE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, pos, true, 0)
  end
  for _, t in ipairs(PL.DETAIL_MOVE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, t, true, 0)
  end
end

-- v7 (2026-09-24, user): the passive detail is the ORIGINAL board's six-sense piece detail (UpdateDetailWindow
-- category 5 -> personal_plate_inc.UpdateSixSenseDetailInfo on team00_26_passive_slot_detail_info: the six-sense
-- hexagon with the passive's own icon, name, build-type icons, team-buff box, description, build plates), drawn by the
-- retail fill on our clone of its layout (ss2_build 8c: on the page, no card frame, band full bleed). Only the band
-- sprite is ours (the retail band at the panel's aspect, evt_ss_bands.g4tx). No move tag, power or tension.
PL.L_PV_DETAIL = 1593383077                      -- team00_26_passive_slot_detail_info
PL.L_PV_BUILD = 1308983228                       -- team00_25_p1_build_name (2 plates, attached by the window)
PL.L_HIPER = 4153824882           -- the Hiper panel (team02_02 clone, ss2_build 8c)
PL.L_HROW = 1127933049                -- the spirit's move row (shared objbin of the plate Hiper page)
PL.BANDS_TEX = 1432188134                        -- crc32("#/menu/102_team/team02/evt_ss_bands/evt_ss_bands.g4tx")
PL.PV_BAND = {[3317336303 --[[sixth_base01]]] = 3897787648,
  [893157544 --[[sixth_base01_blank]]] = 2975610447}
PL.DETAIL_PRIO = {[1593383077 --[[team00_26 passive window]]] = 656, [1308983228 --[[team00_25 build plates]]] = 657,
  [4153824882] = 657, [1127933049] = 658,
  [2651268807] = 656, [395833588] = 656, [3679282495] = 656, [576015315] = 656, [3635526425] = 656, [1305553269] = 656,
  [3131422953] = 656, [2525671790] = 656}
function PL.Open(L, idx)
  idx = idx or 0
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L)
      and not funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], L, idx) then
    funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], L, idx)
  end
end

function PL.DetailHideAll()
  PL.hiper_wide = false
  PL.mx_aura, PL.mx_view = nil, nil               -- the miximax's attached-aura view (R3) ends with the panel
  if PL.SetDetailLayout ~= nil then
    pcall(PL.SetDetailLayout, nil)                -- back to the layout's own positions (passive windows, card)
  end
  local all = {L_DETAIL, L_DETAIL_LV, PL.L_PV_DETAIL, PL.L_HIPER, PL.L_HROW, 2525671790}
  for _, A in pairs(PL.AURA_LAYER or {}) do
    all[#all + 1] = A
  end
  for _, L in ipairs(all) do
    if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, false)
    end
  end
  for i = 0, 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_PV_BUILD, i, false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HROW, i, false)
  end
  PL.pool_peg = nil                               -- 2026-10-12: the aura pool gauge (PL.PoolGauge)
  if PL.POOL ~= nil and funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], PL.L_HIPER) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HIPER, PL.POOL.INST, false)
  end
  pcall(EVT_DetailGraphSync)
end

-- 2026-10-07 (Nacho, shots 384 / 385: «arreglar el alto del cuadro blanco y bajar la supertécnica»): the white card
-- (plate_pages' band copy, rect EVT_PPG_HOST.card) ran from y 625 to 955 under ONE technique row, «Tiro largo»
-- (L_DETAIL's sub-type art, 165 px above the row since the move band it sat on is hidden) floated at y ~510 and the
-- aura banner at ~535. Now one compact block lower on the right (screen px, y down): every detail layer hangs on the
-- base locator _pos_evt_detail01, moved 67 px down (row centre 671 -> 738); the sub-type art sits right on the card's
-- top edge, «IA activada» + the «Nv.» badge on one line in the card's bottom, the aura banner directly on the card,
-- and the card sized to what the state shows (move: row + IA line; aura / miximax: the row, + the second aura header
-- when evt_ss_aura2 shows). Re-applied every frame while a state is set (a layer opened later takes it too); nil =
-- the layouts' own positions and the host's own card (passive windows, the accessory card fallback).
PL.LAYOUT_ON = true                              -- false = the old positions / tall card
PL.LAYOUT_NODE_POS = 2575768773                  -- CMND set node translation (layer, idx, node, axis, value; y up)
PL.LAYOUT_LOCS = {                               -- L_BASE locators: {node, default x, y, compact x, y[, move x, y]}
  {4039391132 --[[_pos_evt_detail01]], 1235, -735, 1235, -838, 1235, -794},
  {4222036771 --[[_pos_evt_detail_lv01]], 1485, -949, 1279, -840, 1279, -796}}
-- 2026-10-13 (owner): in the move view the move row + TENSIÓN and the «IA activada» / «Nv.» line sit 44 px higher
-- (row centre 774 -> 730, info line 778..814: no empty band above the row without a kind label) and the kind label
-- («Tiro de contraataque» + its icon) on the card's top-left edge (top 648, left 993) instead of mid-slot; the
-- locators' move x / y above (aura, miximax, passive, training keep the compact ones). PL.LayoutLoc(i) = where
-- locator i is now (graft combo_partners places the partner faces from it).
-- 2026-10-07 round 3 (Nacho): the Nv. badge as tall as «IA activada» (36 of its 52 px; the layer scaled about its root,
-- the locator = the badge's right end / vertical centre) and right after it (IA box ~1002..1164, gap 10)
PL.LAYOUT_LV_SCALE = 36 / 52
PL.LAYOUT_MOVE_NODES = {                         -- L_DETAIL (evt_team02_02_detail joints, relative to the locator)
  {559600405 --[[_icon_sp_sub_dmy01]], -261, 230, -242, 146},
  {1220252763 --[[_gtxt_longshoot01]], -211, 229, -192, 145},
  {1252573939 --[[_gtxt_override01]], -78, 240, -59, 156},
  {1013569271 --[[_ai_use01]], -248, -196, -233, 16}}
-- 2026-10-07 round 3 (Nacho, shots 412 / 413: «el cuadro blanco debe ser igual de grande para auras, supertécnicas,
-- etc.»; the aura banner sat above the card): ONE card for every state, 985..1920 x 640..880 (1080p), with the same
-- inside: top slot 650..738 (the aura / miximax banner, 88 px; a move's kind label «Tiro largo» centred in it, 670..718;
-- the custom passive's band), the move row 750..798 (centre 774), the info line 822..858 («IA activada», Nv. badge).
-- Every detail layer hangs on _pos_evt_detail01 at y 838 (= row centre 774 + 64); the aura windows / the custom
-- passive window 12 px down by their _pos_base01 so their band (layout y 200) starts at 650.
PL.CARD_ONE = {985, 640, 1920, 880}
PL.LAYOUT_CARD = {move = PL.CARD_ONE, empty = PL.CARD_ONE, aura = PL.CARD_ONE, training = PL.CARD_ONE}
PL.LAYOUT_AURA_DY = -20       -- 2026-10-12 (Nacho: the banner stuck out of the card's top): 8 px lower, 658..746
-- 2026-10-07 round 3, training view (Nacho: «ajusta esa sección de morada y de libertad y valor base al cuadro blanco;
-- en el cuadro morado pon el texto … y mejora la calidad de los iconos»): PL.PanelPlain's L_DETAIL band as the aura
-- banner (930 x 88 in the card's top slot from its left edge), the stat icon at 64 px on its left (was 170 px, an
-- upscaled icon_common sprite: blurry) and the stat name beside it; the two cells (evt_trn_panel locators
-- _atc_trncell00 / 01, screen units) left-aligned right under the banner. Values: {node, default x, y, sx, sy,
-- training x, y, sx, sy} (layout units from the locator, y up; sx / sy nil = no scale change)
PL.LAYOUT_TRN_NODES = {
  {1125548721 --[[_sp_base01]], -275, 200, 525, 128, -250, 188, 930, 88},
  {3384915402 --[[_wlv_base01]], -275, 200, 525, 128, -250, 188, 930, 88},
  {2164615260 --[[_icon_sp_area_dmy01]], 78, 214, 170, 170, -240, 176, 64, 64},
  {1704438437 --[[_text_name01]], -261, 176, 497, 36, -164, 162, 600, 36}}
PL.LAYOUT_TRN_PANEL = 3504298707               -- evt_trn_panel
PL.LAYOUT_TRN_CELLS = {{1535596773 --[[_atc_trncell00]], 1135, -826, 1080, -795},
  {746612851 --[[_atc_trncell01]], 1355, -826, 1250, -795}}
PL.LAYOUT_CARD_TRAINING = true
-- 2026-10-15 (owner: the role picker's panel showed a huge medal past the band and an empty white card): the plain
-- panel (PL.PanelPlain with opts.banner, mode "plain") uses the training view's banner (band 930 x 88 in the card's top
-- slot, the icon 64 px on its left, the name beside it) and the description right under the band, inside the one card
-- (screen 750..866: three lines). {node, default x, y, sx, sy, plain x, y, sx, sy} (layout units, y up)
PL.LAYOUT_PLAIN_FLAVOR = {691026122 --[[_text_flavor01]], -232, -4, 484, 168, -234, 88, 900, 116}
-- 2026-10-15 round 2 (owner: «arregla cómo se ve abajo a la derecha»): the role panel's own compact card, fully on
-- screen. A text node never moves by node translation (its rect stays at the locator + the retail offset: the name
-- 261 left of it, the description 232 left of it), so the locator _pos_evt_detail01 is placed from the card instead and
-- the band / icon meshes are placed back from it (as the training view does): icon PAD from the card's left edge,
-- the name GAP after it. The description box is the retail 484 px one (its font squeezes any longer line to fit), so it
-- is wrapped to that width by PL.WrapText and the card is as tall as four lines.
PL.CARD_PLAIN = {985, 640, 1650, 956}
PL.LAYOUT_CARD.plain = PL.CARD_PLAIN
PL.PLAIN = {pad = 12, icon = 64, gap = 10, name_x = -261, loc_y = 846, band_y = 196, band_h = 88, icon_y = 184,
  inset = 5, wrap_units = 36, quote_line = CALC_CRC("_item_win_line01")}
-- 2026-10-07 round 2 (Nacho: the banners started ~25 px left of the card): every aura window (and the miximax's
-- second header evt_ss_aura2) moved right by its _pos_base01 so the banner's left edge (layout x -275 from the
-- locator at x 1235 = screen 960) is the card's (985); aura2 sits on the banner line in the miximax's aura view
PL.LAYOUT_AURA_DX = 25
PL.LAYOUT_BASE_NODE = 1517329426                 -- _pos_base01
PL.LAYOUT_AURA2_Y = -205                         -- evt_team00_30_aura2's own _pos_base01 y (under the move row)
-- 2026-10-07 round 2 (Nacho: «ajusta también la pasiva personalizada al sitio»): the custom passive's window
-- (PL.L_PV_DETAIL, evt_team00_26_detail: band 128 px at y 200, effect icon at 52, description box 56 .. -144, the
-- build plates' locators at -150) as the same block: the window right 25 / up 40 so its band sits on the card at
-- 690, the description box 80 px tall (two lines next to the icon, not centred in 200 px), the build plates right
-- under it; the card 690 .. 800 (+ 50 when the build plates show)
-- round 3: inside the one card: band 650..778, icon + two text lines 794..874, the build plates right of the text
PL.LAYOUT_PV = {dx = 25, dy = -12, flavor = 691026122 --[[_text_flavor01]], flavor_w = 402, flavor_h = 200,
  flavor_h_compact = 80, builds = {3683526994 --[[_pos_atc_build01]], 1116174568 --[[_pos_atc_build02]]},
  build_x = {-248, -86}, build_y = -150, build_x_compact = {270, 432}, build_y_compact = 40}
PL.LAYOUT_CARD.passive_custom = PL.CARD_ONE
PL.layout_mode = nil
PL.LAYOUT_FRAMES = 60                            -- frames the Step hook re-applies it after a change (layers still opening)
PL.layout_frames = 0

-- where locator i of PL.LAYOUT_LOCS is for the current mode: x, y (layout units, y up)
function PL.LayoutLoc(i)
  local l = PL.LAYOUT_LOCS[i]
  if l == nil then
    return nil
  end
  local mode = PL.LAYOUT_ON and PL.layout_mode or nil
  if mode == "move" and l[6] ~= nil then
    return l[6], l[7]
  elseif mode ~= nil then
    return l[4], l[5]
  end
  return l[2], l[3]
end

function PL.ApplyDetailLayout()
  local mode = PL.LAYOUT_ON and PL.layout_mode or nil
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_BASE) then
    for i, l in ipairs(PL.LAYOUT_LOCS) do
      local x, y = PL.LayoutLoc(i)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, l[1], 0, x)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, l[1], 1, y)
    end
  end
  local mv = mode == "move"
  local tr = mode == "training"
  local PP = PL.PLAIN
  local plx = PL.CARD_PLAIN[1] + PP.pad + PP.icon + PP.gap - PP.name_x      -- locator x that puts the name right of the icon
  if mode == "plain" and PL.LAYOUT_LOCS[1] ~= nil and funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_BASE) then
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, PL.LAYOUT_LOCS[1][1], 0, plx)
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, PL.LAYOUT_LOCS[1][1], 1, -PP.loc_y)
  end
  local banner = tr or mode == "plain"            -- the band as the card's banner, the icon 64 px on its left
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_DETAIL) then
    for _, j in ipairs(PL.LAYOUT_TRN_NODES) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 0, banner and j[6] or j[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 1, banner and j[7] or j[3])
      funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, j[1], banner and j[8] or j[4], banner and j[9] or j[5])
    end
    local f = PL.LAYOUT_PLAIN_FLAVOR
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, f[1], 0, f[2])         -- the description keeps its retail rect
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, f[1], 1, f[3])
    funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, f[1], f[4], f[5])
    if mode == "plain" then
      local x0, x1 = PL.CARD_PLAIN[1], PL.CARD_PLAIN[3]
      for _, band in ipairs({1125548721 --[[_sp_base01]], 3384915402 --[[_wlv_base01]]}) do
        funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, band, 0, x0 - plx)
        funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, band, 1, PP.band_y)
        funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, band, x1 - x0 - PP.inset, PP.band_h)
      end
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, 2164615260 --[[_icon_sp_area_dmy01]], 0, x0 + PP.pad - plx)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, 2164615260, 1, PP.icon_y)
      funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, 2164615260, PP.icon, PP.icon)
      funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, PP.quote_line, false, 0)    -- the retail grey quote bar
    end
  end
  -- 2026-10-07 (Nacho: «quita los cuadros azules»): no navy list column (L_BASE _list_base01) behind the training
  -- stat rows; back when the training view ends (only then: the custom passive list hides it on its own)
  if tr then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_BASE, 785322415 --[[_list_base01]], false, 0)
    PL.trn_column_off = true
  elseif PL.trn_column_off and mode ~= nil then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_BASE, 785322415, true, 0)
    PL.trn_column_off = false
  end
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], PL.LAYOUT_TRN_PANEL) then
    for _, c in ipairs(PL.LAYOUT_TRN_CELLS) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.LAYOUT_TRN_PANEL, 0, c[1], 0, tr and c[4] or c[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.LAYOUT_TRN_PANEL, 0, c[1], 1, tr and c[5] or c[3])
    end
  end
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_DETAIL_LV) then
    local k = mv and PL.LAYOUT_LV_SCALE or 1
    funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], L_DETAIL_LV, k, k, 1, 0)
  end
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_DETAIL) then
    for _, j in ipairs(PL.LAYOUT_MOVE_NODES) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 0, mv and j[4] or j[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 1, mv and j[5] or j[3])
    end
  end
  local au = mode == "aura" or mode == "mx"
  local wins = {PL.L_AURA2}
  for _, A in pairs(PL.AURA_LAYER or {}) do
    wins[#wins + 1] = A
  end
  for _, A in ipairs(wins) do
    if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], A) then
      local y = 0
      if A == PL.L_AURA2 then
        y = (au and PL.mx_view == "aura") and PL.LAYOUT_AURA_DY or PL.LAYOUT_AURA2_Y
      elseif au then
        y = PL.LAYOUT_AURA_DY
      end
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, A, 0, PL.LAYOUT_BASE_NODE, 0, au and PL.LAYOUT_AURA_DX or 0)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, A, 0, PL.LAYOUT_BASE_NODE, 1, y)
    end
  end
  -- 2026-10-12: an aura with a PEG / SP pool: the move's cost and the pool gauge side by side (PL.PoolGauge)
  if PL.POOL ~= nil and funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], PL.L_HIPER) then
    local P = PL.POOL
    local pool = au and PL.pool_peg ~= nil
    for _, g in ipairs({{0, pool and P.MOVE_X or P.X, pool and P.K or 1}, {P.INST, P.POOL_X, P.K}}) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.L_HIPER, g[1], P.NODE, 0, g[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.L_HIPER, g[1], P.NODE, 1, P.Y)
      funcLuaMenuCommand(2885415772 --[[node scale]], PL.L_HIPER, g[1], P.NODE, g[3], g[3])
    end
  end
  local pv = PL.LAYOUT_PV
  local pc = mode == "passive_custom"
  if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], PL.L_PV_DETAIL) then
    local P = PL.L_PV_DETAIL
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, PL.LAYOUT_BASE_NODE, 0, pc and pv.dx or 0)
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, PL.LAYOUT_BASE_NODE, 1, pc and pv.dy or 0)
    funcLuaMenuCommand(2885415772 --[[node scale]], P, 0, pv.flavor, pv.flavor_w, pc and pv.flavor_h_compact or pv.flavor_h)
    for k, b in ipairs(pv.builds) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, b, 0, pc and pv.build_x_compact[k] or pv.build_x[k])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, b, 1, pc and pv.build_y_compact or pv.build_y)
    end
  end
  local H = EVT_PPG_HOST
  if type(H) == "table" then
    if PL.card_default == nil and type(H.card) == "table" then
      PL.card_default = H.card
    end
    local key = mode == "mx" and "aura" or mode    -- 2026-10-07 round 2: one view at a time (R3), one row
    H.card = key ~= nil and PL.LAYOUT_CARD[key] or PL.card_default
  end
end

-- mode: "move" | "aura" | "mx" | "empty" | nil
function PL.SetDetailLayout(mode)
  PL.layout_mode = mode
  PL.layout_frames = mode ~= nil and PL.LAYOUT_FRAMES or 0
  PL.ApplyDetailLayout()
end

function PL.PassiveBoard(item)
  local L = PL.L_PV_DETAIL
  if item == nil or item == 0 or UpdateSixSenseDetailInfo == nil
      or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) then
    return false
  end
  PL.DetailHideAll()
  PL.Open(L)
  PL.Open(PL.L_PV_BUILD, 0)
  PL.Open(PL.L_PV_BUILD, 1)
  local info = funcLuaCommand(1448743477 --[[CMND_GET_PASSIVE_SKILL_INFO]], 0, item)
  UpdateSixSenseDetailInfo(0, item, info, n)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 738777627, false, 0)   -- the card frame / shadow
  local band = PL.PV_BAND[3317336303]
  funcLuaMenuCommand(C.SPRITE, L, PL.BANDS_TEX, band, 3317336303 --[[sixth_base01]], 0, 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  evt_detail_on = true
  pcall(PL.SetDetailLayout, "passive_custom")    -- 2026-10-07 round 2: the compact block as the moves
  return true
end

function PL.PassiveDetail(name, desc, item)
  local okb, shown = pcall(PL.PassiveBoard, item)
  if okb and shown then
    return
  end
  if not okb then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "passive detail (board window) failed", tostring(shown))
  end
  -- fallback (v6): the move panel with the move-only parts hidden
  if not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_DETAIL) then
    error("no detail layer")
  end
  PL.DetailHideAll()
  for _, pos in ipairs(PL.DETAIL_MOVE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, pos, false, 0)
  end
  for _, mesh in ipairs(PL.DETAIL_MOVE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, mesh, false, 0)
  end
  for _, t in ipairs(PL.DETAIL_MOVE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, t, false, 0)
  end
  for _, pr in ipairs(PL.DETAIL_MOVE_PRIM) do
    funcLuaMenuCommand(1233047821 --[[number visible]], L_DETAIL, 0, pr, false)
  end
  for i = 1, 10 do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, CALC_CRC(string.format("_tension_on%02d", i)), false, 0)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 1125548721 --[[_sp_base01]], true, 0)
  funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.BAND[2], 243934124 --[[sp_base01]], 0, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 1704438437 --[[_text_name01]], name, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 691026122 --[[_text_flavor01]], desc, 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, true)
  evt_detail_on = true
end

-- v8 (2026-09-24, user: "no juegues a inventar, usa lo que existe en el juego"): the Hiper panel. Its aura part is the
-- game's own aura detail window, exactly as the original board shows an aura piece (UpdateDetailWindow ->
-- personal_plate_inc.UpdateAuraSkillDetailInfo -> the team00_30_aura_*_detail_info layer of the aura type): the retail
-- band of that aura type and element, the portrait by the retail rule of the type (keshin / totem face icon on
-- _icon_fs_dmy01, miximax partner on _icon_chr_dmy01), the name and the description (page 3); our clone of its layout
-- only removes the card frame and runs the band from the page edge (ss2_build 8d; band = the same retail sprite cut to
-- the panel's aspect, evt_ss_bands.g4tx). Under the band: the spirit's own move as an ATRIBUTOS row + that move's
-- TENSIÓN (evt_ss_hiper_detail, the plate Hiper page's recipe). Never shown: "IA activada", a move-type icon, power.
-- the card rules shared with the personal plate's Hiper page (mode change partner, no move / TENSIÓN for a mode
-- change, PEG look of keshin / armour / totem): research/grafts/plate_hiper_plate/evt_hiper_card.lua (EVT_HC)
-- Keep the shared component constants in a child chunk so the round-trip decompiler
-- can reconstruct the large techniques menu without exhausting its register fallback.
function EVT_HC_Init()
@HIPER_CARD@
end
EVT_HC_Init()
EVT_HC_Init = nil
PL.HIPER_PANEL = true                            -- false = the accessory card as before
PL.AURA_LAYER = {[0] = 2651268807 --[[keshin]], 395833588 --[[keshin armed]], 3679282495 --[[mixi max]],
  576015315 --[[soul / totem]], 3635526425 --[[kizuna trans]], 1305553269 --[[awakening power]], 3131422953 --[[mode change]]}
-- the retail page that holds the description (_pos_page03 / _text_flavor02) for each aura type
PL.AURA_DESC_PAGE = {[0] = 2, 0, 1, 1, 0, 0, 0}
PL.AURA_HIDE_POS = {3407216458 --[[_pos_page01]], 1377611504 --[[_pos_page02]], 3145665477 --[[_pos_page04]],
  3430431571 --[[_pos_page05]], 1307475940 --[[_pos_list01]], 3571920478 --[[_pos_list02]]}
PL.AURA_HIDE_TEXT = {1179414078 --[[_text_fsp01]], 691026122 --[[_text_flavor01]], 1899787537 --[[_text_area01]],
  3542179801 --[[_text_page_title01]], 1244139107 --[[_text_page_title02]], 2739645270 --[[_text_page_title04]],
  3561790400 --[[_text_page_title05]], 777911507 --[[_text_flavor05]], 325360264 --[[_text_scr_btn01]],
  1757105749}
-- 2026-09-25 (in game: "Hiperenergía" over the name, a red blob, a grey box behind the row): every retail node of the
-- other pages / the power line, hidden one by one (the retail fill sets them visible explicitly)
PL.AURA_HIDE_MESH = {3032210235, 206240291, 563708378 --[[_gtxt_cmd_at01]],
  3516146179 --[[_area_base01]], 811580556 --[[_gtxt_armed01]], 1013569271 --[[_ai_use01]], 4122450641,
  2992676399, 508629071, 4147295610, 2150991340,
  2269285990, 2408672862, 869298536, 4217713136,
  658945009, 905124895, 2370796410, 1956062673, 859266817,
  240613041, 380545388, 68880002, 3165086183, 561011038,
  4195885618, 3182975202, 2161668434, 855158082}
-- both portrait slots of an aura window cleared on every show: no face of an earlier row / player / fallback leaks
function PL.FaceReset(A)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, 0, 1051570875 --[[icon_fs_dmy01]])
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, 0, 3237726902 --[[icon_chr_dmy01]])
end

function PL.AuraClean(A)
  for _, p in ipairs(PL.AURA_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], A, p, false, 0)
  end
  for _, x in ipairs(PL.AURA_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], A, x, false, 0)
  end
  for _, m in ipairs(PL.AURA_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, A, m, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], A, 0, 2223127589, false)
  funcLuaMenuCommand(2158717427, A, 636603611, false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 443104220, false, 0)
end
-- the move-panel clone keeps only the TENSIÓN line and the row's locator
PL.HIPER_HIDE_MESH = {3303013605 --[[_sp_win_base01]], 1125548721 --[[_sp_base01]], 3543352325 --[[_icon_sp_area01_off]],
  3384915402 --[[_wlv_base01]], 1013569271 --[[_ai_use01]], 559600405 --[[_icon_sp_sub_dmy01]],
  1220252763 --[[_gtxt_longshoot01]], 1252573939 --[[_gtxt_override01]], 563708378 --[[_gtxt_cmd_at01]],
  2164615260 --[[_icon_sp_area_dmy01]], 3516146179 --[[_area_base01]], 656425078}
PL.HIPER_HIDE_POS = {4081284803 --[[_pos_at01]], 1417578953, 3447183475}
PL.HIPER_HIDE_TEXT = {1704438437 --[[_text_name01]], 691026122 --[[_text_flavor01]]}
-- the aura type + its own cost, a plain white line on the band (as the plate's Hiper page; retail shows no tag)
PL.AURA_TYPE_TEXT = {[0] = "Espíritu guerrero", "Armadura", "Miximax", "Tótem", "Vínculo", "Poder de despertar",
  "Cambio de modo"}

function PL.HiperMove(L, skill, team_info)
  local R = PL.L_HROW
  -- shared rule (EVT_HC.AuraMove): the change skill, else the loader's (armed forms); a mode change has none
  local ok, move = EVT_HC.AuraMove(skill)
  if not ok or type(move) ~= "number" or move == 0 or SetupCharaSkillItem == nil
      or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], R) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, R, 0, false)
    PL.TensionOff(L)                               -- no move row: no TENSIÓN part at all (as the plate)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper move row", "none", tostring(ok), tostring(move))
    return
  end
  PL.MoveRow(L, move, team_info, 0, false, nil, EVT_HC.PegInfo(skill))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper move row", string.format("%08X", EVT_U32(skill)),
    string.format("%08X", EVT_U32(move)))
end

-- a move as an ATRIBUTOS row (evt_ph_move_row) + its TENSIÓN on L (the Hiper panel clone); also used by the miximax
-- the TENSIÓN part completely off: squares and number too (set visible explicitly, they outlive a hidden locator)
function PL.TensionOff(L)
  VRFW_UI.MovePlate.TensionOff(L, 0)             -- the shared gauge (VRFW_UI.MovePlate, 66_ui_plates.lua)
end

-- peg = EVT_HC.PegInfo of the aura (keshin / armour / totem): the gauge in the PEG look, the move's cost in PEG / SP
-- 2026-10-12 (Nacho: a move-rank book on one move showed +1 on every move plate): the retail SetupCharaSkillItem
-- reads the evolution grade at skill_list[inst] = its row INSTANCE; our rows draw any move at instance 0 / k. The fix
-- is the VR-Framework's shared move plate since 2026-10-13 (VRFW_UI.MovePlate.Graded: the move's OWN grade; every
-- screen with a move plate uses it). Returns pcall's ok, err.
function PL.SkillItem(chara, move, inst)
  return VRFW_UI.MovePlate.Graded(chara, move, inst, SetupCharaSkillItem, chara, move or 0, inst, false)
end

function PL.MoveRow(L, move, team_info, idx, no_tension, owner, peg)
  local R = PL.L_HROW
  idx = idx or 0
  if move == nil or move == 0 or SetupCharaSkillItem == nil or type(VRFW_UI) ~= "table"
      or not funcLuaMenuCommand(262659071, R) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, R, idx, false)
    PL.TensionOff(L)                               -- no spirit-move row (armours): no TENSIÓN part at all
    return
  end
  -- the shared move plate (VRFW_UI.MovePlate.Fill: the move's own grade, no blank / AI-mark layers, focus frame off),
  -- then back to this screen's own setting (as EVT_DetailShow)
  local o = {page = L, open = PL.Open, restore = {nil, L_DETAIL, 0, nil, nil}}
  local chara = (owner ~= nil and owner ~= 0) and owner or n
  local okf, err = VRFW_UI.MovePlate.Fill(R, idx, chara, move, o)
  if not okf and chara ~= n then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "move row with the partner failed", tostring(err), "retry with the base")
    okf, err = VRFW_UI.MovePlate.Fill(R, idx, n, move, o)
  end
  if not okf then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper move row failed", string.format("%08X", EVT_U32(move)), tostring(err))
    return
  end
  if no_tension then
    PL.TensionOff(L)
    return
  end
  -- the TENSIÓN gauge (the shared one, VRFW_UI.MovePlate.Tension): the move's own cost, squares = cost / team scale
  -- x 10 (the given team's scale, else team 255's: outside a match the global scale); PEG mode (shared rule): the
  -- move's cost in the pool, squares = cost / pool x 10, the PEG look after the locator
  local okc, cost = funcLuaCommand(C.SKILL_INFO, move, 11)
  local o = {teams = table.pack(team_info, 255)}
  if peg ~= nil then
    okc, cost, o.scale = true, peg.cost, peg.pool
  end
  o.look = function(l, i)
    pcall(EVT_HC.PegLook, l, i, peg ~= nil, peg and peg.kind)
  end
  VRFW_UI.MovePlate.Tension(L, 0, (okc and type(cost) == "number") and cost or nil, o)
end

-- the aura part: the retail window of the type, filled by the retail function, then only the surface is changed
function PL.HiperAura(skill, team_info)
  local okt, t = funcLuaCommand(C.SKILL_INFO, skill, 13)
  local A = okt and PL.AURA_LAYER[t] or nil
  if A == nil or UpdateAuraSkillDetailInfo == nil or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], A) then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper aura window", "type", tostring(t), "missing")
    return false
  end
  PL.Open(A)
  local page = PL.AURA_DESC_PAGE[t] or 0
  if WarpAuraSkillDetailInfoPageIdx ~= nil then
    local okw, p = pcall(WarpAuraSkillDetailInfoPageIdx, page, t, skill)
    if okw and type(p) == "number" then
      page = p
    end
  end
  pcall(PL.FaceReset, A)
  UpdateAuraSkillDetailInfo(skill, n, nil, team_info, page, true)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 443104220, false, 0)       -- the card frame / shadow
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 1013569271 --[[_ai_use01]], false, 0)   -- "IA activada": not for auras here
  funcLuaMenuCommand(2158717427 --[[locator visible]], A, 636603611, false, 0)   -- the type + cost line is there
  for _, p in ipairs(PL.AURA_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], A, p, false, 0)
  end
  for _, x in ipairs(PL.AURA_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], A, x, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], A, 0, 2223127589, false)
  pcall(PL.AuraClean, A)
  -- round 14 (Nacho): no description page on the aura card (its plate + text)
  funcLuaMenuCommand(2158717427 --[[locator visible]], A, 622567014 --[[_pos_page03]], false, 0)
  funcLuaMenuCommand(2735666188 --[[text visible]], A, 2956552560 --[[_text_flavor02]], false, 0)
  -- v9: the band stays the retail sprite the fill chose (aura type + element), drawn at its own aspect (930 x 88)
  local oke, el = funcLuaCommand(C.SKILL_INFO, skill, 7)
  funcLuaMenuCommand(C.LAYER_VISIBLE, 1921826160 --[[team00_40_change_page_guide]], 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, A, 0, true)
  local okc, cid = funcLuaCommand(C.SKILL_INFO, skill, 17)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper aura window", string.format("%08X", EVT_U32(skill)), "type", t,
    "element", tostring(el), "page", page, "info17", tostring(okc), tostring(cid))
  return true
end

-- the card rules of the shared component (EVT_HC) on the retail aura window, after the retail fill, so this panel
-- draws what the plate's Hiper page draws (2026-10-04, user: «tiene que verse igual»): the shared band of the aura type
-- + element and the type icon, the name («Modo cambio: <partner>»), a mode change's partner in the
-- miximax portrait quad, the skill's description (as the plate's panel).
function PL.HiperCard(skill)
  local t = EVT_HC.AuraType(skill)
  local A = t ~= nil and PL.AURA_LAYER[t] or nil
  if A == nil then
    return
  end
  local mc = EVT_HC.McGet(n, skill)
  local okn, nameId = funcLuaCommand(C.SKILL_INFO, skill, 4)
  local name = okn and nameId ~= nil and funcLuaCommand(C.NAME_TEXT, nameId) or nil
  -- 2026-10-12 (Nacho): the name only (no «·  PEG 170»): the pool is its own gauge, PL.PoolGauge
  local title = EVT_HC.Title(type(name) == "string" and name or nil, nil, mc)
  EVT_HC.Header(A, skill, title, 0)
  -- round 14 (Nacho): the player page's card rule - its portrait (EVT_HC.Portrait: the partner / the aura's character
  -- on the slot its type uses; the white block was the empty slot) - and no description plate here
  local okp, ep = pcall(EVT_HC.Portrait, A, skill, nil, mc, "skill_panel", 0)
  if not okp then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "portrait failed", tostring(ep))
  end
  local d = ""
  funcLuaMenuCommand(2735666188 --[[text visible]], A, 2956552560 --[[_text_flavor02]], false, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], A, 622567014 --[[_pos_page03]], false, 0)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper card", string.format("%08X", EVT_U32(skill)), tostring(t),
    tostring(title), "partner", tostring(mc ~= nil), "desc", #d)
end

-- 2026-10-12 (Nacho, shot 156: «quita "· PEG 170" del banner; el PEG del aura como barra morada + número, como el
-- de la técnica, a la derecha del PEG de la técnica, justo debajo del retrato»): a keshin / armour / totem shows its
-- pool as a second TENSIÓN group in the PEG (SP) look: instance 1 of the Hiper panel clone (evt_ss_hiper_detail,
-- count 2; attached to the same locator as instance 0) with every part but its TENSIÓN group hidden, all 10 squares
-- lit, the pool as the number. On that line both groups are scaled K: the move's cost moves left (x MOVE_X), the pool
-- sits at the right end, under the banner's portrait (x POOL_X; layout units of _pos_tension01, default X / scale 1,
-- research/scripts/ss2_build.py HIPER_JOINTS). PL.pool_peg (the pool shown) drives PL.ApplyDetailLayout; cleared by
-- PL.DetailHideAll.
PL.POOL = {INST = 1, NODE = 923022909 --[[_pos_tension01]], X = 423, Y = 70, K = 0.75, MOVE_X = 289, POOL_X = 478}

function PL.PoolGauge(L, peg)
  local P = PL.POOL
  local i = P.INST
  PL.pool_peg = nil
  if peg == nil or type(peg.pool) ~= "number" or peg.pool <= 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L, i, false)
    return false
  end
  PL.Open(L, i)
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, i)
  end
  for _, q in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L, q, false, i)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L, x, false, i)
  end
  funcLuaMenuCommand(2735666188, L, 1899787537 --[[_text_area01]], false, i)
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], false, i)
  funcLuaMenuCommand(1233047821 --[[number visible]], L, i, 2223127589 --[[AT power]], false)
  -- the pool as a full gauge (the shared TENSIÓN gauge: every square lit, the pool as the number, the PEG look)
  VRFW_UI.MovePlate.Tension(L, i, peg.pool, {scale = peg.pool, look = function(l, k)
    pcall(EVT_HC.PegLook, l, k, true, peg.kind)
  end})
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, i, true)
  PL.pool_peg = peg
  return true
end

function PL.HiperShow(skill, team_info)
  if PL.MX_ON and skill == PL.MX_FUSION and PL.MxDetail ~= nil then
    local okf, f = pcall(PL.MxGet)
    if okf and f ~= nil then
      return PL.MxDetail(f, team_info)
    end
  end
  local L = PL.L_HIPER
  if not PL.HIPER_PANEL or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) then
    return false
  end
  PL.DetailHideAll()
  PL.Open(L)
  if not PL.HiperAura(skill, team_info) then
    return false
  end
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  for _, p in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L, p, false, 0)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L, x, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], L, 0, 2223127589 --[[AT power]], false)
  -- Header v3 (as the plate's Hiper page): no type / cost line; the retail aura-type icon in the band's left slot
  -- (drawn by the retail fill) tells the type
  funcLuaMenuCommand(C.TEXT, L, 1899787537 --[[_text_area01]], "", 0)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, 1899787537, false, 0)
  pcall(PL.HiperCard, skill)
  PL.HiperMove(L, skill, team_info)
  local peg = EVT_HC.PegInfo(skill)
  pcall(EVT_HC.PegPool, L, peg)
  local okg, eg = pcall(PL.PoolGauge, L, peg)          -- 2026-10-12: the spirit's PEG / SP pool as a gauge
  if not okg then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "pool gauge failed", tostring(eg))
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  evt_detail_on = true
  PL.hiper_wide = true
  pcall(EVT_DetailGraphSync)
  pcall(PL.SetDetailLayout, "aura")              -- 2026-10-07: banner on a card sized to the row
  return true
end

-- round 14 (Nacho: the move detail in the SUPERTÉCNICAS style): a move shows as the SAME move row the player page
-- and the aura card use (layer evt_ph_move_row: the soccer11_09 plate pill with name / AT, filled by the retail
-- SetupCharaSkillItem, PL.MoveRow) with its TENSIÓN group in the shared style, on the Hiper panel (PL.L_HIPER, whose
-- band / name / description are hidden as for an aura); the retail window (L_DETAIL) keeps only its info pieces:
-- type, «IA activada»; its band, name, AT, TENSIÓN and move-type tag are hidden. PL.MOVE_AS_ROW = false: as before.
PL.MOVE_AS_ROW = true
PL.MOVE_ROW_HIDE_MESH = {1125548721 --[[_sp_base01]], 3384915402 --[[_wlv_base01]], 563708378 --[[_gtxt_cmd_at01]],
  3303013605 --[[_sp_win_base01]]}
function PL.MoveAsRow(skill, team_info)
  local L = PL.L_HIPER
  if not PL.MOVE_AS_ROW or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) then
    return false
  end
  PL.Open(L)
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  for _, q in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L, q, false, 0)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L, x, false, 0)
  end
  funcLuaMenuCommand(2735666188, L, 1899787537 --[[_text_area01]], false, 0)
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], false, 0)
  funcLuaMenuCommand(1233047821 --[[number visible]], L, 0, 2223127589 --[[AT power]], false)
  PL.MoveRow(L, skill, team_info, 0, false, nil, nil)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  -- the retail window: only its info pieces
  for _, m in ipairs(PL.MOVE_ROW_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, m, false, 0)
  end
  funcLuaMenuCommand(2735666188, L_DETAIL, 1704438437 --[[_text_name01]], false, 0)
  funcLuaMenuCommand(2158717427, L_DETAIL, 923022909 --[[_pos_tension01]], false, 0)
  funcLuaMenuCommand(2158717427, L_DETAIL, 4081284803 --[[_pos_at01]], false, 0)
  funcLuaMenuCommand(1233047821, L_DETAIL, 0, 2223127589, false)
  funcLuaMenuCommand(1233047821, L_DETAIL, 0, 3424269865 --[[tension cost]], false)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "move as row", string.format("%08X", EVT_U32(skill)))
  return true
end

function EVT_DetailShow(skill, row)
  if not EVT_DETAIL or skill == 0 then
    return false
  end
  if not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_DETAIL) then
    return false
  end
  local _, team_info = GetSoccerTeamInfo(0)            -- tension gauge scale (board: GetSoccerTeamInfo(0))
  if EVT_IsSpecial(skill) then                         -- v7: the Hiper has its own panel
    local okh, shown = pcall(PL.HiperShow, skill, team_info)
    if okh and shown then
      return true
    end
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper panel", tostring(okh), tostring(shown))
    return false
  end
  PL.DetailHideAll()
  SetSkillItemLayerName(nil, L_DETAIL, 0, nil, nil)   -- as the board's OnInit
  -- grade: the retail window adds the evolution code / base and the graded power when given the skill_list position
  local pos = funcLuaCommand(C.SKILL_POS, n, skill)
  if type(pos) ~= "number" or pos < 0 or pos >= 6 then
    pos = nil
  end
  pcall(PL.DetailRestore)                         -- a passive may have hidden the move-only parts
  SetupPersonalPlateSkillDetailInfo(skill, n, nil, team_info, pos, true)
  -- 2026-09-24: part of the player panel, not a card on top of it: no window frame / shadow
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3303013605 --[[_sp_win_base01]], false, 0)
  pcall(PL.DetailPolish, skill, pos)
  local okr, er = pcall(PL.MoveAsRow, skill, team_info)   -- round 14: the shared move row + TENSIÓN
  if not okr then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "move as row failed", tostring(er))
  end
  -- the retail fill shows the layer itself at its end (it stays hidden if the move data is missing)
  local lv = EVT_DetailLevelTab(row)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL_LV, 0, lv)
  evt_detail_on = true
  pcall(PL.SetDetailLayout, "move")              -- 2026-10-07: label on the card, row + IA / Nv. line in it
  return true
end

function UpdateEquipItemInfo()
  local skill, removable, row = 0, false, nil
  local fixed = false                     -- 2026-09-24: row cannot be edited (level-locked or Prime)
  if n14 ~= L_BTN then
    local ret = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], ret, EVT_ROW_NUM + 1)
    row = ret
    local locked = EVT_IsLocked(ret)
    local prime = EVT_IsPrime()
    skill = PL.RowMove(ret)                -- a still-locked move is shown too when it is known (Prime / learnset)
    fixed = locked or prime or PL.IdolFixed(ret)
    removable = skill ~= 0 and not fixed
  end
  local okd, shown = false, false
  if skill ~= 0 then
    okd, shown = pcall(EVT_DetailShow, skill, row)
  end
  if okd and shown then
    SetVisibleEquipInfoWindow(false)
  else
    pcall(EVT_DetailHide)
    if skill ~= 0 then
      SetVisibleEquipInfoWindow(true)
      EVT_SetupSkillInfo(skill)
    else
      SetVisibleEquipInfoWindow(false)
      pcall(PL.SetDetailLayout, "empty")         -- 2026-10-07: an empty row keeps the compact card, not a tall blank one
    end
  end
  if fixed then
    funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {}, {}, {})
    funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {})
  elseif n14 ~= L_BTN then
    if EVT_CPK ~= nil then                   -- Aceptar, Y Restablecer, Y (mantener) Eliminar, X Compañeros
      PL.guide_redo = function() EVT_CPK.RowGuide(removable, row, skill) end
    else
      PL.guide_redo = function() PL.RowGuide(removable) end   -- Aceptar, Y Restablecer (+ Y hold Eliminar)
    end
    PL.guide_redo()
  else
    UpdateEquipButtonGuide(n12, removable)   -- bottom buttons: Aceptar
  end
  if n14 ~= L_BTN and EVT_IsPrime() then
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.PRIME_GUIDE, 0)
  elseif n14 ~= L_BTN and PL.IdolFixed(row) then
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.IDOL_GUIDE, 0)
  end
  -- 2026-10-14: no retail radar / rpg stat box refill here (the player page shows neither; the set preview and the
  -- training view draw their own values on the radar)
  pcall(EVT_DetailGraphSync)
end

function UpdateEquipCondition(a1, a2)
  -- try 18: forced layout for the shown player, then the board mirrors the match list (both defined further down)
  if EVT_EnforceLayout ~= nil then
    EVT_EnforceLayout()
  end
  if EVT_SyncBoard ~= nil then
    EVT_SyncBoard()
  end
  EVT_RefreshRows()
  UpdateCharaStatus()
  UpdateEquipItemInfo()
end

-- ---- layer setup -------------------------------------------------------------------------------------------
local EVT_RetailOnSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  local prio = PL.DETAIL_PRIO ~= nil and PL.DETAIL_PRIO[a1] or nil
  if prio ~= nil then
    -- v7 / v8 detail windows: over the player panel (the move panel's 656), hidden until something is focused
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, prio, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  if a1 == L_DETAIL or a1 == L_DETAIL_LV then
    -- move detail panel + level badge: the board's priorities (656 / 657), hidden until a move is focused
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, a1 == L_DETAIL and 656 or 657, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  if a1 == L_BASE then
    -- retail team05_01 branch without the equip01..05 / equipNN_rpg / eye-check trace switches
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, 450, true)
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 4168479935 --[[chara02]], false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, 508919562 --[[team00_02_chara_card]], 0, false)
    funcLuaMenuCommand(3252599449 --[[set list item count]], L_ROW, EVT_ROW_NUM)
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 2728862193 --[[_gtxt_equipment01 "Equipamiento" label]], false, a2)
    if n15 > 1 then
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, 1821189452 --[[_arrow01_l01]], true, a2)
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, 2050337590 --[[_arrow01_r01]], true, a2)
      local text_get = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1406349308)
      funcLuaMenuCommand(C.TEXT, a1, 3853210161 --[[_text_btn01_l]], text_get, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 3853210161 --[[_text_btn01_l]], 1155652271)
      local text_get2 = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1681049711)
      funcLuaMenuCommand(C.TEXT, a1, 530870098 --[[_text_btn01_r]], text_get2, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 530870098 --[[_text_btn01_r]], 1155652271)
    end
    if flag7 then
      UpdateEquipButtonGuide(n12, true)
      funcLuaMenuCommand(1432240275, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], false)
    end
    return
  end
  EVT_RetailOnSetupLayer(a1, a2)
  if a1 == L_BTN then
    -- _text_btn01 is the 50x50 key glyph, _text_cmd01 the 400-px label
    funcLuaMenuCommand(C.TEXT, a1, 625330766 --[[_text_cmd01]], PL.Txt(EVT_BUTTON_TEXT), a2)
  end
end

local EVT_RetailOnOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  EVT_RetailOnOpenLayer(a1, a2)
  if a1 == 3078308064 --[[mainmenu90_05_content_guide_line01]] then
    funcLuaMenuCommand(C.TEXT, a1, 378156699 --[[_text_guide01]], EVT_GUIDE_TEXT, a2)
  end
end

-- ---- input -------------------------------------------------------------------------------------------------
function OnEnter(a1, a2)
  -- retail stored list-group parameters here; this menu has no list group
end

function OnDecideFocus(a1, a2)
  if evt_co ~= nil then
    return
  end
  if a1 == L_ROW then
    local locked = EVT_IsLocked(a2)
    if locked or EVT_IsPrime() or PL.IdolFixed(a2) then     -- 2026-09-24: Prime = fixed moveset; 2026-09-27: Idol rows
      funcLuaCommand(C.SE, SE_NG)
      return
    end
    evt_co = coroutine.create(function()
      EVT_PickCoroutine(a2)
    end)
  elseif a1 == L_BTN then
    EVT_OpenOriginalBoard()
  end
end

local EVT_RetailOnFunction = OnFunction
function OnFunction(a1, a2)
  if evt_co ~= nil then
    return
  end
  if a1 == 3918588344 then          -- CMD_FUNC1 (retail "best equipment") -> original ability board
    EVT_OpenOriginalBoard()
  elseif a1 == 4109882573 or a1 == 1141890006 then
    -- 4109882573 = CMD_FUNC3 (Y): tap = Restablecer, hold 1.5 s = Eliminar (EVT_CPK.YHold, graft combo_partners;
    -- the coroutine ends on release, so back is never blocked)
    -- 1141890006 = CMD_FUNC4 (X): partner picker of a combo move (EVT_CPK.Open; docs/game/mechanics/combo-partners.md)
    local row = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    local ok_row = row ~= nil and row >= 0 and row < EVT_ROW_NUM and n14 ~= L_BTN and not EVT_IsLocked(row)
    if a1 == 1141890006 then
      -- X: Inazuma Fantasy's own partner picker when its block is here; otherwise the key belongs to the declared
      -- X action of graft skill_table_host (Utilities' partner picker), which takes it before this function. Nothing
      -- declared: X does nothing (2026-10-14, owner: no sound, no guide entry)
      local skill = ok_row and PL.RowMove(row) or 0
      if EVT_CPK ~= nil and skill ~= 0 and EVT_CPK.Needs(row, skill) then
        evt_co = coroutine.create(function()
          EVT_CPK.Open(row, skill)
        end)
      end
    elseif ok_row and not EVT_IsPrime() and not PL.IdolFixed(row) then
      local removable = EVT_Skill(row) ~= 0
      if not removable and PL.RowRemovable ~= nil then
        removable = PL.RowRemovable(row) == true   -- the Hiper row showing a list fallback
      end
      evt_co = coroutine.create(function()
        local act = PL.TapOrHold(removable)       -- V / Y: tap = Restablecer, hold = Eliminar
        if act == "remove" then
          EVT_RestoreCoroutine(row)
        else
          EVT_ResetCoroutine(row)
        end
      end)
    else
      funcLuaCommand(C.SE, SE_NG)
    end
  else
    EVT_RetailOnFunction(a1, a2)    -- L/R: previous/next player (ChangeChara uses the overrides above)
  end
end

local EVT_RetailOnBack = OnBack
function OnBack(a1)
  -- 2026-10-06 (in game: back / Esc did nothing in this screen, nothing logged): every back logs what it does
  local st = evt_co ~= nil and coroutine.status(evt_co) or "none"
  if evt_co ~= nil and st == "dead" then
    evt_co = nil                          -- a finished action must never keep the screen from closing
  end
  pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back", tostring(a1), "action", st,
    evt_co ~= nil and "swallowed (an action runs)" or "closing")
  if evt_co ~= nil then
    return
  end
  PL.closeLog = 60                        -- 2026-10-06: the next 60 frames log the close state (Step)
  pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back: retail OnBack", "closing before",
    tostring(funcLuaCommand(C.CLOSING_MENU, EVT_MENU)), "closed before", tostring(funcLuaCommand(C.CLOSED_MENU, EVT_MENU)))
  EVT_RetailOnBack(a1)
  funcLuaCommand(C.SE, SE_BACK)
  evt_back_frames = 2   -- close ourselves in Step() if the engine did not (new menus have no native back)
end

local evt_cursor_idx = -1
local EVT_RetailOnChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  -- retail returns early unless CMND_IS_CTRL_FOCUS_ACTIVE; after the picker that flag can stay off and the cursor
  -- arrow stopped following the focus frame (try 5) -> always update for our two focus layers
  if a1 == L_ROW or a1 == L_BTN then
    n14 = a1
    UpdateEquipItemInfo()
    return
  end
  EVT_RetailOnChangeFocus(a1, a2)
end

function Step()
  if evt_hiper_pending and EVT_HiperTexReady() then   -- purple base finished loading after row 0 was set up
    EVT_SetRowBase(0)
  end
  if next(PL.lock_pending) ~= nil and PL.LockTexReady() then   -- navy "off" base finished loading
    for r in pairs(PL.lock_pending) do
      EVT_SetRowBase(r, true)
    end
  end
  if evt_co == nil and n14 ~= L_BTN then   -- keep the arrow cursor on the focused row
    local i = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    if i ~= nil and i ~= evt_cursor_idx and i >= 0 and i < EVT_ROW_NUM then
      evt_cursor_idx = i
      funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], i, EVT_ROW_NUM + 1)
    end
  end
  if evt_co ~= nil then
    local ok, err = coroutine.resume(evt_co)
    if not ok then
      PRINT("evt_skill_slot_menu: " .. tostring(err))
      evt_co = nil
      local text = "ERROR Lua: " .. tostring(err)
      evt_co = coroutine.create(function()   -- (EVT_Message is a local defined further down: inline it)
        funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
        while funcLuaCommand(C.MSG_BUSY) do
          coroutine.yield()
        end
        while not funcLuaCommand(C.MSG_DONE) do
          coroutine.yield()
        end
        funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
      end)
    elseif coroutine.status(evt_co) == "dead" then
      evt_co = nil
    end
  end
  if evt_back_frames >= 0 then
    evt_back_frames = evt_back_frames - 1
    if evt_back_frames < 0 and not funcLuaCommand(C.CLOSING_MENU, EVT_MENU) and not funcLuaCommand(C.CLOSED_MENU, EVT_MENU) then
      pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back: close requested")
      funcLuaCommand(C.CLOSE_MENU, EVT_MENU)
    end
  end
  -- diagnostic (2026-10-06, the close never finishes): for 60 frames after a back, every 5th frame, the close state,
  -- the action coroutine and which of this screen's own layers are still open / loading
  if (PL.closeLog or 0) > 0 then
    PL.closeLog = PL.closeLog - 1
    if PL.closeLog % 5 == 0 then
      local open = {}
      local watch = {L_ROW, L_BTN, L_BASE, L_INFO, L_DETAIL, L_DETAIL_LV, PL.L_PV_DETAIL, PL.L_HIPER, PL.L_HROW,
          PL.L_BTN_ROLE, PL.L_ROLE_OPT, PL.L_SSLIST, PL.L_LISTBG, 2525671790}
      -- the plate_pages host block's added layers too (band, slant, tag, bars, line, chart, numbers)
      if type(EVT_PPG) == "table" and type(EVT_PPG.HOST_LAYERS) == "table" then
        for _, l in ipairs(EVT_PPG.HOST_LAYERS) do
          watch[#watch + 1] = l
        end
      end
      for _, l in ipairs(watch) do
        if l ~= nil and funcLuaMenuCommand(262659071, l) == true and funcLuaMenuCommand(2640875187, l, 0) == true then
          open[#open + 1] = string.format("%08X%s", l, funcLuaMenuCommand(3057768039, l) == true and "(loading)" or "")
        end
      end
      local okc, cing = pcall(funcLuaCommand, C.CLOSING_MENU, EVT_MENU)
      local okd, cd = pcall(funcLuaCommand, C.CLOSED_MENU, EVT_MENU)
      -- one string (the loader's lua log keeps only the first few values)
      pcall(funcLuaCommand, C.EVT_LOG, string.format("skill_slots close watch %d closing %s closed %s action %s back %s open [%s]",
        PL.closeLog, tostring(cing), tostring(cd), evt_co ~= nil and coroutine.status(evt_co) or "none",
        tostring(evt_back_frames), table.concat(open, " ")))
    end
  end
  -- diagnostic (2026-10-06): the back key seen by this screen while OnBack is not reached (once per press)
  local okk, bk = pcall(PL.Key, PL.K_BACK)
  local down = okk and bk == true
  if down and not evt_back_seen then
    pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back key seen", "action",
      evt_co ~= nil and coroutine.status(evt_co) or "none", "back frames", tostring(evt_back_frames),
      "pv open", tostring(evt_pv_open))
  end
  evt_back_seen = down
end

-- ---- actions -----------------------------------------------------------------------------------------------
function EVT_OpenOriginalBoard()
  funcLuaCommand(C.SE, SE_DECIDE)
  P_Set(EVT_KEY_OPEN_BOARD, true)   -- read by the team dock after this menu is gone
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  funcLuaCommand(C.CLOSE_MENU, EVT_MENU)
end

local function EVT_Message(text)
  if PL.MxUnblack ~= nil then
    PL.MxUnblack()                               -- 2026-10-13: a message never opens under the pre-scene black
  end
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
end

function EVT_AfterChange()
  if EVT_SyncBoard ~= nil then
    EVT_SyncBoard()
  end
  EVT_RefreshRows()
  UpdateCharaStatus()
  UpdateEquipItemInfo()
end

-- ---- board commit (try 10: vr-loader commands, handle based; try 18: forced layout) ---------------------------
-- status 1 = done and verified by the loader; we also re-read the slot. Other codes: 0 refused by 0xE7D310 (no free
-- copy / move already on another active slot), 2 read-back mismatch, -1 bad args, -2 data not ready, -3 slot
-- closed and no definition piece, -4 exception, -5 no record, -6 CLEAR would close the piece (slot without a native
-- move; try 16 closed Byron's pieces 21/23 that way), -7 no 9-piece board (LAYOUT).
local function EVT_BoardPut(bslot, skill, inv)
  if bslot == nil or inv == nil or inv == 0 then
    return false, "sin ranura/objeto"
  end
  local st = EVT_Call(C.EVT_PLACE, n, inv, bslot)
  return st == 1 and EVT_BoardSkill(bslot) == skill, st
end

-- keep_open: a slot without a native move ends open and EMPTY instead of being refused (-6); only used right before
-- a PLACE on the same slot, or for the Hiper slot 8 which must stay open.
local function EVT_BoardClear(bslot, keep_open)
  if bslot == nil then
    return nil
  end
  local st = EVT_Call(C.EVT_CLEAR, n, bslot, keep_open and 1 or 0)
  return st
end

-- make skill_list[slot] == skill (CMND_SET_SKILL swaps with the move's old position when it was in the list)
local function EVT_ListPut(slot, skill)
  if skill == 0 or slot == nil then
    return
  end
  local pos = funcLuaCommand(C.SKILL_POS, n, skill)
  if pos ~= slot then
    funcLuaCommand(C.SET_SKILL, n, skill, slot)
  end
end

local function EVT_Log(...)
  EVT_Call(C.EVT_LOG, "skill_slots", ...)
end

-- Team aura slots of the team dock being edited (save teamInfoList.auraSkillSlotInfoList, 4 x {charaStHdl, skillId}),
-- as the retail aura screen equip_aura_skill_menu reads (CMND_GET_TEAM_SET_INFO(dockNo, dockType, 15, i)) and writes
-- (0x59CAEAD5(dockNo, dockType, 6, i, chara, skill) -> ok, previous index). dockNo/dockType = n3/n17, the values the
-- team dock hands to this screen (params 3357163798 / 4081600465, the same ones it gives equip_menu).
local function EVT_AuraFind()
  local mine, free, mine_skill = -1, -1, 0
  for i = 0, EVT_TEAM_AURA_SLOTS - 1 do
    local ok, ch, sk = funcLuaCommand(C.TEAM_INFO, n3, n17, 15, i)
    if ok then
      if EVT_U32(ch) == EVT_U32(n) and mine < 0 then
        mine, mine_skill = i, EVT_U32(sk)
      elseif (ch == nil or ch == 0) and free < 0 then
        free = i
      end
    end
  end
  return mine, free, mine_skill
end

-- Put `skill` (0 = remove) into this player's team aura slot; returns ok, text (for the Hiper message)
local function EVT_TeamAuraPut(skill)
  if n3 == nil then
    return false, "sin equipo"
  end
  local mine, free = EVT_AuraFind()
  local slot = mine >= 0 and mine or free
  if slot < 0 then
    return skill == 0, "aura de equipo llena (4 de 4)"
  end
  local ok, prev
  if skill == 0 then
    ok, prev = funcLuaCommand(C.TEAM_AURA_SET, n3, n17, 6, slot, 0, 0)
  else
    ok, prev = funcLuaCommand(C.TEAM_AURA_SET, n3, n17, 6, slot, n, skill)
  end
  local _, _, now = EVT_AuraFind()
  local good = (skill == 0 and now == 0) or (skill ~= 0 and now == skill)
  return good, string.format("aura de equipo ranura %d %s (equipo %s/%s, juego %s)", slot + 1, good and "OK" or "NO",
    tostring(n3), tostring(n17), tostring(ok))
end

local function EVT_Report(text, row)
  EVT_Log("report", row, (string.gsub(text, "\n", " / ")))
  if EVT_SKILL_SLOT_DEBUG or (row == 0 and EVT_SKILL_SLOT_DEBUG_HIPER) then
    EVT_Message(text)
  end
end

local function EVT_Snapshot()
  local t = {}
  for b = 0, 8 do
    t[b] = EVT_BoardSkill(b)
  end
  return t
end

-- "cambios: 2 A->B, 5 C->D" for every board slot (1-based) that changed
local function EVT_Diff(before, after)
  local out = {}
  for b = 0, 8 do
    if before[b] ~= after[b] then
      out[#out + 1] = string.format("%d %s->%s", b + 1, EVT_Name(before[b]), EVT_Name(after[b]))
    end
  end
  if #out == 0 then
    return "sin cambios en la tabla"
  end
  return "tabla: " .. table.concat(out, ", ")
end

-- Real invSkill handle for `skill`: a handle in `pool` (items just taken off the board), the handle already on one of
-- this player's board slots (swap, restore), else CMND_ADD_ITEM_ONLY(skill, 1) (the story's way; moves stack, one
-- inventory record per move) - the caller removes the extra copy with CMND_DELETE_ITEM right after. The picker
-- already refuses moves without a free copy (codigo 5).
local function EVT_HandleFor(skill, pool)
  if pool ~= nil and pool[skill] ~= nil and pool[skill] ~= 0 then
    return pool[skill], false
  end
  for b = 0, 8 do
    local id, h = EVT_BoardSkill(b)
    if id == skill and h ~= nil and h ~= 0 then
      return h, false
    end
  end
  local h = funcLuaCommand(C.ADD_ITEM, skill, 1, false)
  if h ~= nil and h ~= 0 then
    return h, true
  end
  return 0, false
end

-- Handle for the Hiper slot 8. A special that also sits on a normal slot 0-5 (the game keeps hyperpowers on slot 5
-- for branch-1 players) has no free copy, so 0xE7D310 would refuse it: one extra copy is added and KEPT (the move is
-- then equipped twice, once per branch, as retail boards with both branches open do). Slots 6/7 are freed by the
-- layout, so their handle is reused.
local function EVT_HiperHandle(skill)
  for b = 0, 8 do
    local id, h = EVT_BoardSkill(b)
    if id == skill and h ~= nil and h ~= 0 then
      if b >= 6 then
        return h, false
      end
      local h2 = funcLuaCommand(C.ADD_ITEM, skill, 1, false)
      if h2 ~= nil and h2 ~= 0 then
        return h2, false
      end
      return h, false
    end
  end
  return EVT_HandleFor(skill)
end

EVT_TeamAuraOf = function() return EVT_TeamAuraGet() end
function EVT_TeamAuraGet()
  if n3 == nil then
    return 0
  end
  local _, _, sk = EVT_AuraFind()
  return sk
end

-- 2026-09-27: an Idol's learnset Hiper (chara_param slot 9) is placed on board slot 8 (+ the team aura slot) once
-- its level is reached and the slot is still empty. The private build boards carried the piece with required_level
-- 0, so the engine opened it at the shape's lock (Lv 43) although the card learns it at 1 (Arion) / 70 (Victor);
-- moment_idol_build.py now writes the level into the piece, and this covers cards signed before that rebuild (the
-- engine only re-walks the pieces on a level-up). Called once per shown player from UpdateEquipListItem(0).
function EVT_IdolHiperPlace()
  if not EVT_HasBoard() or n == nil or n == 0 or EVT_IsPrime() or PL.readonly or not PL.IsIdol() then
    return
  end
  local ls = PL.Learnset()
  local want = ls.skill[9] or 0
  if want == 0 or not EVT_IsSpecial(want) or EVT_IsLocked(0) or EVT_Skill(0) ~= 0 then
    return
  end
  local h, added = EVT_HiperHandle(want)
  local ok, st = false, nil
  if h ~= nil and h ~= 0 then
    ok, st = EVT_BoardPut(EVT_HIPER_SLOT, want, h)
  end
  if added then
    funcLuaCommand(C.DEL_ITEM, want, 1)
  end
  local txt = ""
  if ok and EVT_SPECIAL_TEAM_AURA then
    local _, t = EVT_TeamAuraPut(want)
    txt = tostring(t)
  end
  EVT_Log("idol hiper place", EVT_Name(want), ok and "OK" or "NO", "status", st, txt)
end

-- ---- forced layout (try 18) --------------------------------------------------------------------------------------
-- true when slots 6 and 7 are closed and 3, 4, 5, 8 are open with a move (or when the loader cannot tell)
local function EVT_LayoutOK()
  for _, s in ipairs(EVT_LAYOUT_CLOSED) do
    local p = EVT_Call(C.EVT_PIECE, n, s)
    if type(p) ~= "number" or p < 0 then
      return true           -- loader error: do not touch the board
    end
    if p < 255 then
      return false
    end
  end
  for _, s in ipairs(EVT_LAYOUT_OPEN) do
    local p, eff = EVT_Call(C.EVT_PIECE, n, s)
    if type(p) ~= "number" or p < 0 then
      return true
    end
    if p >= 255 or eff == nil or eff == 0 then
      return false
    end
  end
  return true
end

-- The special the Hiper slot should hold: the team aura's (the player's own pick, try 19: the original board can
-- put a native hyperpower on slot 8), else slot 8's, else one the game left on row 6 (board slot 5; never 6-7).
local function EVT_HiperWanted()
  local s = EVT_TeamAuraGet()
  if EVT_IsSpecial(s) then
    return s
  end
  s = EVT_BoardSkill(EVT_HIPER_SLOT)
  if EVT_IsSpecial(s) then
    return s
  end
  for _, b in ipairs({5}) do
    s = EVT_BoardSkill(b)
    if EVT_IsSpecial(s) and PL.AuraType(s) ~= 5 then   -- 2026-09-28: never a generic hiperpoder (hiper-audit §9)
      return s
    end
  end
  return 0
end

-- CMND_EVT_BOARD_LAYOUT for the shown player: 6 and 7 emptied and closed (their items back to stock), 3, 4, 5 and 8
-- opened with their board-definition pieces, currentRouteType = branch 1 (value 0). Items offered: the match-list
-- moves 4-6 for slots 3-5 and the Hiper special for slot 8 (nothing else is tried). A slot left
-- without a move stays closed; CMND_EVT_BOARD_PLACE opens it when the player picks a move for that row.
-- Try 19: the original board (route logic) can replace the hyperpower on slot 8 with a native one; the team aura
-- keeps the player's pick, so slot 8 is set back to it.
local function EVT_RepairHiper()
  local want = EVT_TeamAuraGet()
  if not EVT_IsSpecial(want) or EVT_BoardSkill(EVT_HIPER_SLOT) == want then
    return
  end
  local h, added = EVT_HiperHandle(want)
  local ok, st = EVT_BoardPut(EVT_HIPER_SLOT, want, h)
  if added then
    funcLuaCommand(C.DEL_ITEM, want, 1)
  end
  EVT_Log("hiper repair", EVT_Name(want), ok and "OK" or "NO", "status", st)
end

-- 2026-09-28 aura slot cleanup at run time (docs/game/mechanics/aura-slot-cleanup.md §7). aura_slot_cleanup_build.py
-- fixed chara_param, but a save keeps what the board learned before: the native items of the board slots and the match
-- list (Flora: her miximax on row 6 as a native item, «Eliminar» brought it back). Once per shown player and visit:
-- every aura / Hiper command on rows 1-6 (match list or board) leaves the row; the Hiper slot takes it when it is
-- empty or holds no miximax (miximax first, the builder's priority); the row gets the player's learnset move (current
-- chara_param: the same slot, then the other slots 1-6 — never 7-8; level reached, not already on another row), else it is
-- emptied. CLEAR mode 2 (loader) also drops an aura NATIVE item, so «Eliminar» cannot bring it back.
PL.aura_clean_done = {}
PL.AURA_CLEAR_NATIVE = 2                    -- CMND_EVT_BOARD_CLEAR keepOpen = 2: placed item off + an aura native off
function PL.AuraType(s)
  local ok, ty = funcLuaCommand(C.SKILL_INFO, s, 13)
  return (ok and type(ty) == "number") and ty or -1
end

function PL.AuraSlotCleanup()
  if n == nil or n == 0 or PL.aura_clean_done[n] then
    return
  end
  PL.aura_clean_done[n] = true
  local found = {}
  for k = 0, EVT_NORMAL_NUM - 1 do
    local l, b = EVT_ListSkill(k), EVT_BoardSkill(k)
    local sl, sb = EVT_IsSpecial(l), EVT_IsSpecial(b)
    if sl or sb then
      found[#found + 1] = {k = k, aura = sl and l or b, list = sl and l or 0, board = sb}
    end
  end
  if #found == 0 then
    return
  end
  -- 1. the Hiper slot: keeps a miximax; else takes a miximax found on a row; else (empty) the first keshin / totem
  local cur = EVT_Skill(0)
  local want = cur
  if PL.AuraType(cur) ~= 2 then
    for _, f in ipairs(found) do
      if PL.AuraType(f.aura) == 2 then
        want = f.aura
        break
      end
    end
  end
  if want == 0 then
    local rank = {[0] = 5, [3] = 5, [6] = 4, [4] = 3, [7] = 2, [1] = 1}
    local best = -1
    for _, f in ipairs(found) do
      local r = rank[PL.AuraType(f.aura)]    -- a generic hiperpoder (type 5) is never the Hiper (hiper-audit §9)
      if r ~= nil and r > best then
        want, best = f.aura, r
      end
    end
  end
  local hiper_txt = "kept"
  if want ~= 0 and want ~= cur and not EVT_IsLocked(0) then
    local h, added = EVT_HiperHandle(want)
    local ok, st = false, nil
    if h ~= nil and h ~= 0 then
      ok, st = EVT_BoardPut(EVT_HIPER_SLOT, want, h)
    end
    if added then
      funcLuaCommand(C.DEL_ITEM, want, 1)
    end
    if ok and EVT_SPECIAL_TEAM_AURA then
      EVT_TeamAuraPut(want)
    end
    hiper_txt = string.format("%s -> %s %s (%s)", EVT_Name(cur), EVT_Name(want), ok and "OK" or "NO", tostring(st))
  end
  -- 2. the rows: aura out, the learnset move in
  local ls = PL.Learnset()
  local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  local on_rows = {}
  for k = 0, EVT_NORMAL_NUM - 1 do
    on_rows[EVT_ListSkill(k)] = true
    on_rows[EVT_BoardSkill(k)] = true
  end
  local log = {}
  for _, f in ipairs(found) do
    local repl = 0
    if not EVT_IsLocked(f.k + 1) then
      local order = {f.k + 1, 1, 2, 3, 4, 5, 6}
      for _, j in ipairs(order) do
        local m = ls.skill[j] or 0
        if m ~= 0 and not on_rows[m] and not EVT_IsSpecial(m) and (ls.lv[j] or 0) <= lv then
          repl = m
          break
        end
      end
    end
    if f.board then
      EVT_Call(C.EVT_CLEAR, n, f.k, PL.AURA_CLEAR_NATIVE)
    end
    if repl ~= 0 then
      on_rows[repl] = true
      EVT_ListPut(f.k, repl)
    elseif f.list ~= 0 then
      local p = funcLuaCommand(C.SKILL_POS, n, f.list)
      if p ~= nil and p >= 0 and p < EVT_NORMAL_NUM then
        funcLuaCommand(C.REMOVE_SKILL, n, p)
      end
    end
    log[#log + 1] = string.format("row %d %s -> %s", f.k + 1, EVT_Name(f.aura), repl ~= 0 and EVT_Name(repl) or "---")
  end
  EVT_Log("aura cleanup", "hiper " .. hiper_txt, table.concat(log, ", "))
end

function EVT_EnforceLayout()
  if not EVT_HasBoard() or n == nil or n == 0 or EVT_IsPrime() or PL.readonly then
    return                                -- Prime: fixed moveset, the board is never written
  end
  if EVT_LayoutOK() then
    -- once per player and screen visit: LAYOUT with no items only fixes the route and the learned-piece flags
    if not evt_layout_done[n] then
      local st = EVT_Call(C.EVT_LAYOUT, n, 0, 0, 0, 0)
      evt_layout_done[n] = true
      EVT_Log("layout check", st)
    end
    EVT_RepairHiper()
    pcall(PL.ProjectionLog)               -- 2026-10-14: auras on list positions stay (hidden), one log line
    return
  end
  evt_layout_done[n] = true
  local hs, added = {0, 0, 0, 0}, {}
  local function offer(i, skill)
    if skill ~= 0 then
      local h, a
      if i == 4 then
        h, a = EVT_HiperHandle(skill)
      else
        h, a = EVT_HandleFor(skill)
      end
      hs[i] = h or 0
      if a then
        added[#added + 1] = skill
      end
    end
  end
  for i = 1, 3 do
    local s = EVT_ListSkill(i + 2)
    if not EVT_IsSpecial(s) then
      offer(i, s)
    end
  end
  offer(4, EVT_HiperWanted())
  local st, mb, ma = EVT_Call(C.EVT_LAYOUT, n, hs[1], hs[2], hs[3], hs[4])
  for _, s in ipairs(added) do
    funcLuaCommand(C.DEL_ITEM, s, 1)     -- undo the extra copies made to obtain handles
  end
  EVT_Log("layout", st, "open mask", mb, "->", ma)
  EVT_RepairHiper()
  pcall(PL.ProjectionLog)                 -- 2026-10-14: auras on list positions stay (hidden), one log line
end

-- The board mirrors the match list: board slot k (0-5) gets skill_list[k] for every unlocked row. Slots to change
-- are cleared first (a move sits on the board only once), then filled (2 passes, so a native move that came back on
-- one slot can be replaced before it is needed on another). A move that cannot be placed stays in the list only (the
-- match reads the list); the slot gets its old move back when possible. Empty list positions take the board move.
function EVT_SyncBoard()
  if not EVT_HasBoard() or n == nil or n == 0 or EVT_IsPrime() or PL.readonly then
    return true
  end
  local want, cur, curh, todo = {}, {}, {}, {}
  for k = 0, EVT_NORMAL_NUM - 1 do
    cur[k], curh[k] = EVT_BoardSkill(k)
    if not EVT_IsLocked(k + 1) then
      local l = EVT_ListSkill(k)
      if l ~= 0 then
        want[k] = l
      end
    end
  end
  for k = 0, EVT_NORMAL_NUM - 1 do
    local need = want[k] ~= nil and want[k] ~= cur[k]
    if not need and want[k] == nil and cur[k] ~= 0 and not EVT_IsLocked(k + 1) then
      for j, s in pairs(want) do   -- this slot holds a move another row wants
        if j ~= k and s == cur[k] then
          need = true
        end
      end
    end
    if need then
      todo[#todo + 1] = k
    end
  end
  local all_ok = true
  if #todo > 0 then
    local pool = {}
    for _, k in ipairs(todo) do
      if cur[k] ~= 0 and curh[k] ~= 0 then
        pool[cur[k]] = curh[k]
      end
      EVT_BoardClear(k, true)
    end
    for pass = 1, 2 do
      for _, k in ipairs(todo) do
        local s = want[k]
        if s ~= nil and EVT_BoardSkill(k) ~= s then
          local h, added = EVT_HandleFor(s, pool)
          local ok, st = EVT_BoardPut(k, s, h)
          if added then
            funcLuaCommand(C.DEL_ITEM, s, 1)
          end
          if pass == 2 then
            EVT_Log("sync slot", k, EVT_Name(s), ok and "OK" or "NO", "status", st)
          end
        end
      end
    end
    for _, k in ipairs(todo) do
      local now = EVT_BoardSkill(k)
      if want[k] ~= nil and now ~= want[k] then
        all_ok = false
        if now == 0 and cur[k] ~= 0 then    -- could not place: old move back if it is not on the board elsewhere
          local h, added = EVT_HandleFor(cur[k], pool)
          EVT_BoardPut(k, cur[k], h)
          if added then
            funcLuaCommand(C.DEL_ITEM, cur[k], 1)
          end
        end
      end
    end
  end
  for k = 0, EVT_NORMAL_NUM - 1 do
    if not EVT_IsLocked(k + 1) and EVT_ListSkill(k) == 0 then
      local b = EVT_BoardSkill(k)
      if b ~= 0 and not EVT_Active(b) and not EVT_IsSpecial(b) then
        EVT_ListPut(k, b)
      end
    end
  end
  return all_ok
end

-- Put `skill` on `row`. Normal rows: the match list first (CMND_SET_SKILL; it swaps when the move is already at
-- another position), then the board mirrors it (EVT_SyncBoard). Hiper row: board slot 8 (the loader opens the piece
-- if needed) + the team aura slot, never the match list.
function EVT_Equip(row, skill, inv_hint, cur)
  local before = EVT_Snapshot()
  local msg
  local ok_all
  if row == 0 then
    local ok_board, st = false, "no board service"
    if PL.AuraSlotWritable() then                    -- board slot 8: IF's board service or Character Reforged's
      local h, added = EVT_HiperHandle(skill)
      local h_item = (h ~= 0) and EVT_U32(funcLuaCommand(C.INV_ITEM, h, 0)) or 0
      if h ~= 0 and h_item == skill then
        ok_board, st = EVT_BoardPut(EVT_HIPER_SLOT, skill, h)
      end
      if added then
        funcLuaCommand(C.DEL_ITEM, skill, 1)        -- undo the extra copy made to obtain the handle
      end
    end
    msg = string.format("%s: tabla %s (ranura %d, handle %X, estado %s)", EVT_Name(skill), ok_board and "OK" or "NO",
      EVT_HIPER_SLOT + 1, EVT_U32(h), tostring(st))
    ok_all = ok_board
    if EVT_SPECIAL_TEAM_AURA then
      local okA, txt = EVT_TeamAuraPut(skill)
      msg = msg .. ", " .. txt
      ok_all = ok_all or okA
    end
  else
    local pos = EVT_ListPos(row)
    EVT_ListPut(pos, skill)                          -- swaps inside the list when the move was at another position
    local ok_list = EVT_ListSkill(pos) == skill
    local ok_board = EVT_SyncBoard()
    msg = string.format("%s: lista posición %d %s, tabla %s", EVT_Name(skill), pos + 1, ok_list and "OK" or "NO",
      ok_board and "OK" or "sin cambiar (la lista manda)")
    ok_all = ok_list
    if not ok_board then
      EVT_Log("equip row", row, EVT_Name(skill), "board not mirrored")
    end
  end
  msg = msg .. ".\n" .. EVT_Diff(before, EVT_Snapshot())
  if not ok_all then
    EVT_Log("equip failed", row, (string.gsub(msg, "\n", " / ")))
    funcLuaCommand(C.SE, SE_NG)                    -- 2026-09-28: error sound only, details in loader.log
  else
    EVT_Report(msg, row)
  end
end

local function EVT_CurrentWithInv()
  local cur = {inv = {}}
  for r = 0, EVT_ROW_NUM - 1 do
    cur[r] = EVT_Skill(r)
    local b, h = EVT_BoardSkill(EVT_BoardSlot(r))
    cur.inv[r] = (b == cur[r]) and h or 0
  end
  return cur
end

-- Opens the game's hissatsu list (ability_list_menu: tabs / filter / sort) in "pick" mode.
-- Mode S = special row (only category-8 moves accepted), N = normal rows (category-8 moves refused).
-- Moves on other normal rows stay selectable (swap) and are tagged "(ranura N)".
-- Put the focus frame and the arrow cursor back on `row` (0xCE987192 = focused instance of an instanced layer,
-- 0x1246829F = focused index of a list layer; try 11b had only the list one: the arrow moved, the frame stayed on row 0).
function EVT_FocusRow(row)
  if row == nil or row < 0 or row >= EVT_ROW_NUM then
    return
  end
  local before = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
  funcLuaMenuCommand(3466097042, L_ROW, row)   -- set the focused instance (focus frame); retail LISTVIEW.SetupInitFocus
  -- try 14 also called 306610847 (list index): the frame then landed on row/2 -> dropped
  EVT_Call(3661580131 --[[CMND_EVT_LOG]], "skill_slots", "focus", row, "before", before, "after",
    funcLuaMenuCommand(C.FOCUS_IDX, L_ROW))
  evt_cursor_idx = row
  funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], row, EVT_ROW_NUM + 1)
  -- 2026-10-13 (owner's video: after the miximax scene the cursor sat on the Hiper row with an empty detail panel and
  -- Left / Right did nothing): the focus is the row list again, whatever focus event (a button's) came in between;
  -- the caller's UpdateEquipItemInfo / EVT_AfterChange then draws the row's panel
  n14 = L_ROW
  if PL.fs_wait ~= nil then
    PL.fs_wait = PL.FS_WINDOW
  end
end

function EVT_PickCoroutine(row)
  if EVT_IsPrime() then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local cur = EVT_CurrentWithInv()
  P_Set(EVT_KEY_PICK, row == 0 and 2 or 1)
  for k = 1, EVT_ROW_NUM - 1 do
    P_Set(EVT_KEY_USED[k], (k ~= row and cur[k] ~= 0) and cur[k] or 0)
  end
  for _, key in ipairs({EVT_KEY_RESULT, EVT_KEY_INV, EVT_KEY_DBG_INIT, EVT_KEY_DBG_ENTER, EVT_KEY_DBG_CODE, EVT_KEY_DBG_BITS}) do
    funcLuaCommand(C.P_CLEAR, key)
  end
  for _, key in ipairs(PL.LIST_KEYS) do            -- no stale six-sense / board filter tabs (2026-09-24)
    funcLuaCommand(C.P_CLEAR, key)
  end
  P_Set(3357163798, n3)                          -- dock number, as the team dock sets it for this list
  -- no SE_OK: the row's own decide sound already plays (it sounded twice)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  -- 3466097042 stores the focus the layer gets when it is (re)opened/resumed, not the current one (log try 15:
  -- set after the resume it only took effect at the NEXT resume = the previous edited row). Store it before suspending.
  funcLuaMenuCommand(3466097042, L_ROW, row)
  funcLuaMenuCommand(C.MENU_SUSPEND, EVT_MENU)
  funcLuaCommand(C.OPEN_MENU, EVT_PICK_MENU, EVT_PICK_MENU)
  coroutine.yield()
  while funcLuaMenuCommand(C.EXIST_MENU, EVT_PICK_MENU) do
    coroutine.yield()
  end
  -- 2026-09-30 (Nacho: «Crear miximax» showed this page again, froze, then the bank): with «Crear miximax» picked the
  -- screen stays suspended and PL.MxBankPick opens the partner bank at once (one transition, as from here to the
  -- Hiper picker); the screen resumes when the bank closes (PL.MxResumeDirect on every other way out)
  if PL.MxDirectPick ~= nil and PL.MxDirectPick(row) then
    PL.mx_direct = true
  else
    funcLuaMenuCommand(C.MENU_RESUME, EVT_MENU)
    coroutine.yield()
    EVT_FocusRow(row)                            -- resume puts the focus back on row 0 (Hiper)
  end
  funcLuaCommand(C.P_CLEAR, EVT_KEY_PICK)
  for k = 1, EVT_ROW_NUM - 1 do
    funcLuaCommand(C.P_CLEAR, EVT_KEY_USED[k])
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
  local function take(key)
    if funcLuaCommand(C.P_HAS, key) then
      local v = funcLuaCommand(C.P_GET, key)
      funcLuaCommand(C.P_CLEAR, key)
      return v
    end
    return nil
  end
  local skill = EVT_U32(take(EVT_KEY_RESULT))
  local inv = EVT_U32(take(EVT_KEY_INV))
  local d_init, d_enter, d_code = take(EVT_KEY_DBG_INIT), take(EVT_KEY_DBG_ENTER), take(EVT_KEY_DBG_CODE)
  local d_bits = take(EVT_KEY_DBG_BITS)
  local raw = string.format("%X", skill)
  local trail = string.format("init %s, confirm capa %s, codigo %s, bits %s", tostring(d_init),
    d_enter and string.format("%X", EVT_U32(d_enter)) or "nil", tostring(d_code), tostring(d_bits))
  if EVT_SKILL_SLOT_DEBUG or (row == 0 and EVT_SKILL_SLOT_DEBUG_HIPER) then
    EVT_Message(string.format("[1] lista cerrada. Fila %d (tabla %d). Lista: %s. Resultado: %s -> id %X inv %X, actual %X",
      row, (EVT_BoardSlot(row) or -1) + 1, trail, raw, skill, inv, cur[row] or 0))
  end
  if skill ~= 0 and skill ~= cur[row] then
    if (row == 0) ~= EVT_IsSpecial(skill) then   -- the picker already refuses these
      funcLuaCommand(C.SE, SE_NG)                  -- 2026-09-28: error sound only
      EVT_Log("pick refused", row, EVT_Name(skill), "special row mismatch")
    else
      -- no SE here: the list already played its decide sound on confirm (it sounded twice)
      local ok, err = pcall(EVT_Equip, row, skill, inv, cur)
      if not ok then
        EVT_Log("equip error", row, tostring(err))   -- 2026-09-28: no text on screen, error sound only
        funcLuaCommand(C.SE, SE_NG)
      end
    end
  end
  if PL.mx_direct then                           -- never leave the screen suspended (error / refused paths)
    PL.MxResumeDirect()
  end
  EVT_FocusRow(row)
  EVT_AfterChange()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- Y «Eliminar» (2026-10-06, user: Y ALWAYS deletes, it never restores; X «Restablecer» = EVT_ResetCoroutine at the end
-- of this file). CMND_EVT_BOARD_CLEAR keepOpen 3 (vr-loader 2026-10-06) takes the placed item AND the slot's native
-- item off, the piece stays open and EMPTY. Hiper row: board slot 8 + the team aura slot emptied. Normal rows: the
-- board slot and the match position emptied (the native move does not come back). Nothing on the row: error sound.
-- (Before 2026-10-06 keepOpen 1 brought the native move back, so «Eliminar» sometimes restored the default.)
-- (literal 3, no PL field: a new main-chunk constant here would shift the RK index of later table constructors)
function EVT_RestoreCoroutine(row)
  if EVT_IsPrime() then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  if row == 0 then
    local before = EVT_Snapshot()
    local old = EVT_Skill(0)
    local r = PL.AuraSlotWritable() and EVT_Call(C.EVT_CLEAR, n, EVT_HIPER_SLOT, 3 --[[keepOpen 3: everything off]]) or nil
    local okA, txt = EVT_TeamAuraPut(0)
    funcLuaCommand(C.SE, old ~= 0 and SE_REMOVE or SE_NG)
    EVT_Report(string.format("Eliminar hiper: %s, ranura %d (estado %s), %s.\n%s", EVT_Name(old), EVT_HIPER_SLOT + 1,
      tostring(r), txt, EVT_Diff(before, EVT_Snapshot())), 0)
  else
    local before = EVT_Snapshot()
    local bslot, pos = EVT_BoardSlot(row), EVT_ListPos(row)
    local old = EVT_Skill(row)
    local r = EVT_HasBoard() and EVT_Call(C.EVT_CLEAR, n, bslot, 3 --[[keepOpen 3: everything off]]) or nil
    if EVT_ListSkill(pos) ~= 0 then
      funcLuaCommand(C.REMOVE_SKILL, n, pos)       -- the match position emptied too
    end
    local now = EVT_Skill(row)
    funcLuaCommand(C.SE, old ~= 0 and SE_REMOVE or SE_NG)
    EVT_Report(string.format("Eliminar ranura %d: %s -> %s (estado %s).\n%s", bslot + 1, EVT_Name(old), EVT_Name(now),
      tostring(r), EVT_Diff(before, EVT_Snapshot())), row)
  end
  EVT_AfterChange()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- try 24: "Pasivas de la rama" (read-only window) -------------------------------------------------------------
-- Lists the passive pieces (team passives) and the stat pieces ("+N" stats) of the base path and of branch 1 of this
-- player's board, with learned yes/no (openedEffectPieceList) and the unlock level (the piece's lock level), plus the
-- totals of the learned stat pieces. Data: CMND_EVT_BOARD_DEF (board slots -> which switcher side is branch 1, with
-- EVT_BR_SHAPES from research/scripts/bd_branch.py) and CMND_EVT_BOARD_PIECE_INFO (type / resolved reward / learned /
-- level of one board effect). Texts: CMND_GET_PASSIVE_SKILL_INFO (3 = stat type, 1 = value), the retail status
-- passive titles ("VALUE" template) and CMND_GET_TEAM_PASSIVE_INFO for team passives.
-- Opened only from the second bottom button "Pasivas de la rama" (try 24b layout); CMD_FUNC4 stays unused.
local EVT_PV = {
  DEF = 1280105679,
  PIECE = 2224538686,
  PASSIVE = 1448743477,        -- CMND_GET_PASSIVE_SKILL_INFO (kind, id[, i])
  TEAM_PASSIVE = 1136033383,   -- CMND_GET_TEAM_PASSIVE_INFO (id, 0) -> ok, text
  TEXT_VALUE = 910683996,      -- (textId or string, "VALUE", value, ...) -> string
}
local EVT_STAT_TITLE = {[0] = 3905596903, 1084668705, 1047492482, 2352972234, 2604963209, 614355554, 2718198818}

local function EVT_PV_Call(cmd, ...)
  local r = {pcall(funcLuaCommand, cmd, ...)}
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2)
end

-- base-path and branch-1 effect indexes of this player's board (sorted), or nil
local function EVT_PV_Pieces()
  local cnt, d0, d1, d2, d3, d4, d5, d6, d7, d8 = EVT_PV_Call(EVT_PV.DEF, n)
  local total = EVT_PV_Call(EVT_PV.PIECE, n, 0)
  if type(cnt) ~= "number" or cnt < 9 or type(total) ~= "number" or total <= 0 or EVT_BR_SHAPES == nil then
    return nil
  end
  local def = {d0, d1, d2, d3, d4, d5, d6, d7, d8}
  local function has(set, v)
    for _, x in ipairs(set) do
      if x == v then
        return true
      end
    end
    return false
  end
  for key, entry in pairs(EVT_BR_SHAPES) do
    if tonumber(string.match(key, "^(%d+):")) == total then
      for sw, sets in pairs(entry) do
        for side = 1, 2 do
          local b1, b2 = sets[side], sets[3 - side]
          if (has(b1, def[4]) or has(b1, def[5])) and not has(b2, def[4]) and not has(b2, def[5]) then   -- branch 1 = the side with learnset slots 4/5, the other side without them (6-7 never read)
            local base, br1 = {}, {}
            for e = 0, total - 1 do
              if e ~= sw and not has(b1, e) and not has(b2, e) then
                base[#base + 1] = e
              end
            end
            for _, e in ipairs(b1) do
              br1[#br1 + 1] = e
            end
            table.sort(br1)
            return base, br1
          end
        end
      end
    end
  end
  local base = {}                                 -- no switcher: the whole board is the base path
  for e = 0, total - 1 do
    base[#base + 1] = e
  end
  return base, {}
end

-- tries 25-26: the window is a read-only PANEL (clone of the retail team-passive list window soccer11_21, one centred
-- column of 9 retail passive rows, a retail full-screen black background behind; research/scripts/ss2_build.py
-- section 7). Only UNLOCKED entries (base path + branch 1). Stat pieces of the same stat are summed into one row, the
-- same passive twice is one row "xN". The unlock level is the row's right-aligned number node (the retail "locked
-- passive level" number, moved to the right edge in our row clone). Up/Down scroll, Back/Enter close.
local L_PV_PANEL = 2524402806
local L_PV_ROW = 811691761
local L_BLACKBG = 3801549073
local L_BTN_ICON = 3196164535      -- the old «Pasivas de la rama» button: removed 2026-10-12, kept hidden (setting layer)
local L_BTN_SS = 605517988          -- "Pasiva personalizada" button
local EVT_PV_ROWS = 9                              -- panel rows = row-layer instances 0..8
local EVT_BG_COUNT = 2                             -- try 28: 2 stacked cmn02_01_blackbg dims (4 were too black)
local EVT_ROW_ICON_SS, EVT_ROW_ICON_PV = 9, 10     -- row-layer instances drawn as the icons of the two square buttons
local EVT_POS_VISIBLE = 2158717427                 -- (layer, node, bool, idx): show / hide a locator subtree
local EVT_PRIORITY = 1491630496                    -- CMND_SET_DRAW_PRIORITY (layer, idx, prio, bool)
local EVT_PRIM_INDEX, EVT_PRIM_NUM, EVT_PRIM_VISIBLE = 1927054058, 3609943765, 1233047821
local EVT_NUM_LEVEL = 2330185550                   -- num_passive_lock01 (number node of the row)
local EVT_MENU_CTRL = 1332654303
local EVT_CMD_BACK, EVT_CMD_ENTER, EVT_CMD_UP, EVT_CMD_DOWN = 3011112225, 1981080283, 1197218715, 3259546669
local EVT_TEX_SOCCER11_20 = 4021797290             -- #/menu/00_soccer/soccer11/soccer11_20/soccer11_20.g4tx
local EVT_TEX_ICON_COMMON = 2320109963             -- #/menu/200_icon/15_icon_common/icon_common.g4tx
local EVT_TEX_TEAMBUFF = 2301895383                -- #/menu/200_icon/08_icon_teambuff/<LG>/icon_teambuff.g4tx
local EVT_SS_PIECE_REWARD = 3638456107           -- board reward of the six-sense piece (generic board, branch 1)
local EVT_SS_CATEGORY = 200                        -- ability list category filter of six-sense items (board picker)
local evt_pv_open = false
local evt_icon_frames = 0                          -- try 28: frames left to re-apply the static button icons

-- ---- entries ----------------------------------------------------------------------------------------------------
local function EVT_PV_TeamText(id, eff, count)
  local okE, textId = EVT_PV_Call(551963711 --[[CMND_GET_PASSIVE_EFFECT_INFO]], eff, 0)
  local t
  if okE == true and textId ~= nil then
    t = EVT_PV_Call(720417636, textId)
    t = EVT_PV_Call(820766113 --[[CMND_TEXT_CONVERT]], t, 0, 1140121255, "[CPASSIVE01]") or t
    t = EVT_PV_Call(820766113 --[[CMND_TEXT_CONVERT]], t, 0, 2769827636, "") or t
    local value = EVT_PV_Call(EVT_PV.PASSIVE, 1, id, 0)
    local okc, digits, disp = pcall(MENU_DEF.CalcPassiveEffectNeedDecimalDigitAndDisplayValue, eff, value)
    if okc and disp ~= nil then
      t = EVT_PV_Call(EVT_PV.TEXT_VALUE, t, "VALUE", disp, 0, 2, false, digits) or t
    end
  end
  if type(t) ~= "string" or t == "" then
    t = string.format("%08X", EVT_U32(id))
  end
  t = string.gsub(t, "%s+", " ")
  return t                                         -- try 28: never cut (long texts wrap to 2 lines)
end

-- ---- rows -----------------------------------------------------------------------------------------------------------
local function EVT_Row_Reset(k)
  local L = L_PV_ROW
  for _, pos in ipairs({1559050359 --[[_pos_icon01]], 397052763, 3320080845 --[[_pos_icon02]], 3448691050 --[[_pos_build01]],
                        3453619769 --[[_pos_type01]], 2497436533 --[[_pos_position01]]}) do
    funcLuaMenuCommand(EVT_POS_VISIBLE, L, pos, false, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2336867556 --[[_build_ef01]], false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 27565530 --[[_icon_inheritance01]], false, k)
end

local EVT_ALB_ICON_ON = {             -- GetAbilearBoardTeamPassiveIconTexture(eff, true): category -> icon_alb01_teambuffNN_on
  [2] = 3528670446, [3] = 3236336384, [4] = 2019226725, [12] = 3851275484, [27] = 1563536313, [22] = 1469018683,
  [16] = 4013102430, [18] = 4253465264, [11] = 1161485781, [10] = 3639469420, [19] = 1615954441, [21] = 1927556583,
  [29] = 3394783874, [30] = 2453363412, [0] = 713506225, [1] = 271517931, [8] = 2828234638, [9] = 3123101792,
  [17] = 43689733, [20] = 2672664508, [23] = 670169305, [24] = 893671223, [25] = 2381852754, [26] = 3583713284,
  [28] = 1831290721, [37] = 760160603, [6] = 2515748414, [13] = 2269571536, [31] = 136609415, [32] = 2962758114,
  [38] = 3908766132
}
local EVT_TEX_ABILEAR = 3315424508                -- #/menu/200_icon/18_icon_abilearboard/<LG>/icon_abilearboard.g4tx
local EVT_ICON_SIXTH = 487860482                   -- icon_abilear_sixth01 (retail board six-sense piece, icon_common)

-- try 27: a row-layer instance used only as a STATIC icon on top of a square button: no Active anime (set up in
-- OnSetupLayer), no row base / overlays / build band, only the icon node with one sprite.
local function EVT_ButtonIcon(k, tex, sprite)
  local L = L_PV_ROW
  EVT_Row_Reset(k)
  for _, mesh in ipairs({3143733656 --[[_passive_base01]], 2061463723 --[[_passive_base01_ol01]],
                         3822461201 --[[_passive_base01_ol02]], 3877027080, 2336867556 --[[_build_ef01]],
                         2299070650 --[[_icon_teambuff_tgt_dmy01]], 27565530 --[[_icon_inheritance01]],
                         22927936, 97947090, 106573771,
                         2673049201, 3895971012, 918292019,
                         2203859798, 3016059238, 744788874}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, false, k)
  end
  funcLuaMenuCommand(C.TEXT, L, 1868134834 --[[_text_passive01]], "", k)
  -- 2026-09-24: showing _pos_icon01 re-shows ALL its children (the white 48 x 32 dummy _icon_teambuff_tgt_dmy01 and the
  -- grey plate _teambuff_base01 = the "white squares" above the button icons): it was shown AFTER they were hidden.
  -- Now: locator first, then its unwanted meshes off again, then the icon on.
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, 1559050359 --[[_pos_icon01]], true, k)
  for _, mesh in ipairs({3877027080, 2336867556 --[[_build_ef01]], 2299070650 --[[_icon_teambuff_tgt_dmy01]]}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, false, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3165767436, true, k)
  funcLuaMenuCommand(C.SPRITE, L, tex, sprite, 3234721532 --[[icon_teambuff_dmy01]], 0, k)
end

-- equipped six-sense item -> its board icon (as the original board draws the piece), else the generic six-sense icon
local function EVT_SS_Icon(item)
  if item ~= 0 then
    local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, item)
    if eff ~= nil then
      local ok, cat = EVT_PV_Call(551963711 --[[CMND_GET_PASSIVE_EFFECT_INFO]], eff, 2, 0)
      local spr = ok and EVT_ALB_ICON_ON[tonumber(cat) or -1] or nil
      if spr ~= nil then
        return EVT_TEX_ABILEAR, spr
      end
    end
  end
  return EVT_TEX_ICON_COMMON, EVT_ICON_SIXTH
end

-- ---- six sense ("Pasiva personalizada") ------------------------------------------------------------------------
-- piece: the board effect of the six-sense slot (reward ss0001) in base path / branch 1 -> effect, level
local function EVT_SS_Piece()
  local base, br1 = EVT_PV_Pieces()
  if base == nil then
    return nil
  end
  for _, part in ipairs({base, br1}) do
    for _, e in ipairs(part) do
      local cnt, ty, id, learned, level = EVT_PV_Call(EVT_PV.PIECE, n, e)
      if EVT_U32(id or 0) == EVT_SS_PIECE_REWARD then
        return e, (type(level) == "number" and level < 99) and level or 50, learned
      end
    end
  end
  return nil
end

-- equipped six sense: invHdl, itemId
local function EVT_SS_Get()
  local st, inv, item = EVT_PV_Call(1074115993, n, 0, 0, -1)
  if st ~= 1 then
    return 0, 0
  end
  return EVT_U32(inv or 0), EVT_U32(item or 0)
end

-- level lock: returns locked, needLevel, pieceIdx
local function EVT_SS_Lock()
  local e, need = EVT_SS_Piece()
  if e == nil then
    return true, 0, nil
  end
  local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  return lv < need, need, e
end

local function EVT_SS_ButtonRefresh()
  local _, item = EVT_SS_Get()
  EVT_ButtonIcon(EVT_ROW_ICON_SS, EVT_SS_Icon(item))
  local locked = EVT_SS_Lock()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, EVT_ROW_ICON_SS, not evt_pv_open)
  funcLuaMenuCommand(C.TEXT, L_BTN_SS, 950238781 --[[_text_btn01]], "", 0)
  funcLuaMenuCommand(C.TEXT, L_BTN_SS, 625330766 --[[_text_cmd01]], "", 0)
  return locked
end

-- info card while the six-sense button has the focus: equipped item (icon, name, description) or the lock level
local function EVT_SS_Info()
  local _, item = EVT_SS_Get()
  local locked, need = EVT_SS_Lock()
  if item ~= 0 and PL.PassiveDetail ~= nil then
    local name = EVT_PV_Call(1883585771 --[[CMND_GET_ITEM_PARAM]], item, 0)
    local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, item)
    local desc = eff ~= nil and EVT_PV_TeamText(item, eff, 1) or ""
    if pcall(PL.PassiveDetail, type(name) == "string" and name or "Pasiva personalizada", desc, item) then
      SetVisibleEquipInfoWindow(false)
      item = -1                                   -- shown in the panel: skip the card below
    end
  end
  if item == -1 then
  elseif item ~= 0 then
    SetVisibleEquipInfoWindow(true)
    funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 303536660 --[[_icon_item_dmy01]], 1875672568 --[[icon_item_dmy01]], item)
    funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 2334051246 --[[_icon_item_dmy02]], 4140117058 --[[icon_item_dmy02]], item)
    local name = EVT_PV_Call(1883585771 --[[CMND_GET_ITEM_PARAM]], item, 0)
    funcLuaMenuCommand(C.TEXT, L_INFO, 456522680 --[[_text_item01]], type(name) == "string" and name or "Pasiva personalizada", 0)
    local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, item)
    local desc = eff ~= nil and EVT_PV_TeamText(item, eff, 1) or ""
    funcLuaMenuCommand(C.TEXT, L_INFO, 3138144965 --[[_text_parameter01]], desc, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2634282032 --[[_item_chr_base01]], false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2787359195 --[[_item_chr_dmy01]], false, 0)
  else
    SetVisibleEquipInfoWindow(false)
  end
  local guide = locked and string.format("Pasiva personalizada: se desbloquea en Nv.%d.", need)
    or (item ~= 0 and "Pasiva personalizada equipada. Aceptar: cambiar; Eliminar: quitar." or "Pasiva personalizada: pulsa para equipar una.")
  funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], guide, 0)
end

-- try 27: picker = the RETAIL "Pasiva personalizada" list the original board opens (OpenAbilityListMenu_Coroutine):
-- menu ability_list_menu, group ability_list_menu_on_bluebg, params 4161869490 = character, 1498333934 = 200 (six-sense
-- category). Its native commit writes into the open board menu only (null-checked, no-op here), so our block in that
-- group's script (src/evt_ability_list_blue_block.lua, active with evt_ss_pick_used = 3) hands back the confirmed item
-- and its invSkill handle; CMND_EVT_SIXSENSE equips it after the menu closes.
function EVT_SS_PickCoroutine()
  local locked, need, piece = EVT_SS_Lock()
  if locked then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(string.format("La pasiva personalizada se desbloquea en el Nv.%d.", need))
    return
  end
  if not PL.HasService("six_sense") then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.LOADER))
    return
  end
  local _, cur = EVT_SS_Get()
  for _, key in ipairs({EVT_KEY_RESULT, EVT_KEY_INV}) do
    funcLuaCommand(C.P_CLEAR, key)
  end
  P_Set(EVT_KEY_PICK, 3)
  -- 2026-09-24 fix (user: the button opened the MOVE list): the list group builds one tab per filter key that is SET
  -- in the parameter store (OnInit, keys t3 = 1498333934, 3225916244, 3074466754, 690239073, 1579353847, 3341440845,
  -- 2552568759, 19679757; 773844157 = start tab). Keys left over from an earlier move list / board sub-window added
  -- move tabs. All of them are cleared first, so only 200 (six sense -> tab 26) remains.
  for _, key in ipairs(PL.LIST_KEYS) do
    funcLuaCommand(C.P_CLEAR, key)
  end
  P_Set(4161869490, n)                             -- character (as the board)
  P_Set(1498333934, EVT_SS_CATEGORY)               -- category 200 = six-sense items (as the board)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, EVT_ROW_ICON_SS, false)
  funcLuaMenuCommand(C.MENU_SUSPEND, EVT_MENU)
  funcLuaCommand(C.OPEN_MENU, EVT_PICK_MENU, 2238902107)
  coroutine.yield()
  while funcLuaMenuCommand(C.EXIST_MENU, EVT_PICK_MENU) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_RESUME, EVT_MENU)
  coroutine.yield()
  for _, key in ipairs({EVT_KEY_PICK, 1498333934, 4161869490}) do
    funcLuaCommand(C.P_CLEAR, key)
  end
  EVT_Call(C.EVT_LOG, "skill_slots", "sixsense picker closed", "item", EVT_U32(funcLuaCommand(C.P_HAS, EVT_KEY_RESULT) and funcLuaCommand(C.P_GET, EVT_KEY_RESULT) or 0))
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
  local function take(key)
    if funcLuaCommand(C.P_HAS, key) then
      local v = funcLuaCommand(C.P_GET, key)
      funcLuaCommand(C.P_CLEAR, key)
      return v
    end
    return nil
  end
  local item = EVT_U32(take(EVT_KEY_RESULT))
  local inv = EVT_U32(take(EVT_KEY_INV))
  if item ~= 0 and item ~= cur then
    local h, added = inv, false
    if h == 0 then
      h, added = EVT_HandleFor(item)
    end
    local st, now = EVT_PV_Call(1074115993, n, 1, h, piece or -1)
    if added then
      funcLuaCommand(C.DEL_ITEM, item, 1)
    end
    EVT_Call(C.EVT_LOG, "skill_slots", "sixsense set", item, "inv", h, "status", st, "now", now)
    if st ~= 1 then
      funcLuaCommand(C.SE, SE_NG)                  -- 2026-09-28: error sound only (status in loader.log)
    end
  end
  EVT_SS_ButtonRefresh()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- pointer (mouse / VR free cursor; docs/game/ui/mouse-support.md §5, EVT_PointerNew) ---------------------------
-- Our polled lists (PL.List: the passive panel rows; PL.PopList / PL.SSList: the board picker's team08_02 rows; the
-- read-only «Pasivas de la rama» panel) get Lua zones each frame from the rows' global positions (4002164178, y up):
-- PL.PTR_PV = the passive row (soccer11_20 plate _passive_base01: x -414 .. +414, 92 high, centred on the origin),
-- PL.PTR_SS = the team08_02 row (ss2_build: x -98 .. +872, 72 high, centred). Only rows that show an entry get a zone,
-- plus a 40 px band above / below while the list scrolls that way. PL.PtrStep -> act ("pick" = the row under the
-- pointer was clicked, "moved" = hover / wheel / band moved the focus), first, sel, owns (P.Owns(): the Accept now
-- pressed is the pointer's, so the loops do not take CMD_ENTER / CMD_ENTER_CLICK as «choose the focused row»).
--@lib evt_menu_kit.lua#Pointer
PL.PTR_PV = {-414, 828, 92}
PL.PTR_SS = {-98, 970, 72}
function PL.PtrStart()
  PL.ptr = PL.ptr or EVT_PointerNew()
  pcall(PL.ptr.Reset)
  return PL.ptr
end
function PL.PtrZones(P, L, nrows, rect, first, total)
  P.Begin()
  local top, bottom = nil, nil
  for k = 0, nrows - 1 do
    if first + k < total then
      local ok, x, y = pcall(funcLuaMenuCommand, 4002164178, L, k)
      local split = type(PL.ptr_split) == "function" and PL.ptr_split(k) or nil
      if ok and type(x) == "number" and type(y) == "number" and split ~= nil then
        -- 2026-10-13: a split row (two halves of one entry): ids k (left) and k + 0.5 (right), PL.PtrStep
        for h, r in ipairs(split) do
          P.Rect(x + r[1], -y - r[3] / 2, r[2], r[3], h == 1 and k or k + 0.5)
        end
        local rx, ry = x + rect[1], -y - rect[3] / 2
        top = top or {rx, ry}
        bottom = {rx, ry + rect[3]}
      elseif ok and type(x) == "number" and type(y) == "number" then
        local rx, ry = x + rect[1], -y - rect[3] / 2
        P.Rect(rx, ry, rect[2], rect[3], k)
        top = top or {rx, ry}
        bottom = {rx, ry + rect[3]}
      end
    end
  end
  if top ~= nil and first > 0 then
    P.Rect(top[1], top[2] - 40, rect[2], 40, "up", -1)
  end
  if bottom ~= nil and first + nrows < total then
    P.Rect(bottom[1], bottom[2], rect[2], 40, "down", 1)
  end
  return P.Poll()
end
function PL.PtrStep(P, L, nrows, rect, first, sel, total)
  local ok, ev = pcall(PL.PtrZones, P, L, nrows, rect, first, total)
  if not ok or type(ev) ~= "table" then
    return nil, first, sel, false
  end
  local okO, owns = pcall(P.Owns)
  owns = okO and owns == true
  -- a split row's halves (PL.PtrZones): the right half's id is k + 0.5; the half goes to PL.vrm_half
  local function half(id)
    if type(id) == "number" and id % 1 ~= 0 then
      return math.floor(id), 1
    end
    if type(id) == "number" and PL.row_split ~= nil and PL.row_split[id] then
      return id, 0
    end
    return id, nil
  end
  local cid, ch = half(ev.click)
  local hid, hh = half(ev.hot)
  ev.click, ev.hot = cid, hid
  if ch ~= nil and ch ~= PL.vrm_half then
    PL.vrm_half = ch
    PL.ptr_resync = true                          -- PL.PopList redraws (keys of the clicked half) before acting
  end
  if hh ~= nil and hh ~= PL.vrm_half and ch == nil then
    PL.vrm_half = hh
    return "moved", first, first + hid, owns
  end
  if type(ev.click) == "number" and first + ev.click < total then
    return "pick", first, first + ev.click, owns
  end
  local d = ev.wheel or ev.edge
  if d ~= nil then
    local f2 = math.max(0, math.min(first + d, total - nrows))
    if f2 ~= first then
      if type(ev.hot) == "number" and f2 + ev.hot < total then
        sel = f2 + ev.hot
      else
        sel = math.max(f2, math.min(sel, f2 + nrows - 1))
      end
      return "moved", f2, sel, owns
    end
  end
  if ev.changed and type(ev.hot) == "number" and first + ev.hot ~= sel and first + ev.hot < total then
    return "moved", first, first + ev.hot, owns
  end
  return nil, first, sel, owns
end

local function EVT_OpenSixSense()
  if evt_co ~= nil then
    return
  end
  evt_co = coroutine.create(function()
    EVT_SS_PickCoroutine()
  end)
end

-- ---- bottom buttons (tries 24c-26) -----------------------------------------------------------------------------------
-- [ long "Tabla de habilidades original" ][ Pasiva personalizada ][ Pasivas de la rama ] inside the rows' column:
-- three layers (retail button layer with a 404 px skin, two 72 px layers; research/scripts/ss2_build.py section 6).
-- Focus: right/left between them (CMD_FCS_NEXT / CMD_FCS_BACK), up to the rows. The retail OnSetupLayer DISABLES
-- CMD_FCS_NEXT on the button layer (2559269762): re-enabled here. The icons are row-layer instances 9/10 on top.
local EVT_ENABLE_CMD = 2559269762
local EVT_CMD_FCS_NEXT = 2734193315

local EVT_PV_PrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == L_BTN_ICON then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)  -- 2026-10-12 (owner): the «Pasivas de la rama» button is gone
    return
  elseif a1 == L_BTN_SS then
    funcLuaMenuCommand(C.TEXT, a1, 625330766 --[[_text_cmd01]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 950238781 --[[_text_btn01]], "", a2)   -- no key glyph (no key is bound)
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, 3313461902 --[[cursor]], false)
    return
  elseif a1 == L_PV_PANEL then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 900, true)
    for _, pos in ipairs({3448691050, 1839509013, 1437140403, 2946906320,
                          2513278738, 214222504}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3926830396, false, a2)
    funcLuaMenuCommand(C.TEXT, a1, 355816102, "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 59628764, "", a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_BLACKBG then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 880, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_PV_ROW then
    if a2 == EVT_ROW_ICON_PV then                    -- the removed passive button's icon: never shown
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    elseif a2 == EVT_ROW_ICON_SS then                -- static icons: no Active anime (it animates the row band)
      funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 560, true)
      EVT_ButtonIcon(a2, EVT_TEX_ICON_COMMON, EVT_ICON_SIXTH)
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, true)       -- EVT_SS_ButtonRefresh sets the equipped icon
    else
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 1286797620 --[[Active]], 0, 753088835 --[[Default]])
      funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 901, true)
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    end
    return
  end
  EVT_PV_PrevSetupLayer(a1, a2)
  if a1 == L_BTN then
    funcLuaMenuCommand(EVT_ENABLE_CMD, a1, EVT_CMD_FCS_NEXT, true)       -- right -> the square buttons
  end
end

local EVT_PV_PrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == L_BTN_ICON then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_BTN_SS then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
    return
  elseif a1 == L_PV_PANEL or a1 == L_BLACKBG then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, evt_pv_open)
    return
  elseif a1 == L_PV_ROW then
    if a2 < EVT_PV_ROWS then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, evt_pv_open)
    elseif a2 == EVT_ROW_ICON_PV then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    else
      evt_icon_frames = 10                         -- try 28: the open resets mesh visibility; re-apply a few frames
    end
    return
  end
  EVT_PV_PrevOpenLayer(a1, a2)
end

local evt_focus_layer = nil
local EVT_PV_PrevChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  evt_focus_layer = a1
  if a1 == L_BTN_SS then
    n14 = L_BTN                       -- the screen treats it like the bottom button (no row info, cursor off rows)
    UpdateEquipItemInfo()
    pcall(EVT_SS_Info)
    return
  end
  EVT_PV_PrevChangeFocus(a1, a2)
  if a1 == L_ROW or a1 == L_BTN then
    local guide = (a1 == L_ROW and EVT_IsPrime()) and PL.PRIME_GUIDE or EVT_GUIDE_TEXT   -- 2026-09-24 Prime
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], guide, 0)
  end
end

local EVT_PV_PrevDecide = OnDecideFocus
function OnDecideFocus(a1, a2)
  EVT_Call(C.EVT_LOG, "skill_slots", "decide", a1, a2, "row layer", L_ROW, "ss button", L_BTN_SS)   -- 2026-09-24 diag
  if a1 == L_BTN_SS then
    EVT_OpenSixSense()
    return
  end
  EVT_PV_PrevDecide(a1, a2)
end

-- "Eliminar" on the six-sense button takes the item off
local EVT_PV_PrevFunction = OnFunction
function OnFunction(a1, a2)
  if a1 == 4109882573 and evt_focus_layer == L_BTN_SS and evt_co == nil then
    local _, item = EVT_SS_Get()
    if item ~= 0 then
      EVT_PV_Call(1074115993, n, 1, 0, -1)
      funcLuaCommand(C.SE, SE_REMOVE)
      EVT_SS_ButtonRefresh()
      pcall(EVT_SS_Info)
    else
      funcLuaCommand(C.SE, SE_NG)
    end
    return
  end
  EVT_PV_PrevFunction(a1, a2)
end

-- the six-sense icon follows the shown player; try 28: after the icon instances open, their meshes are hidden again
-- for a few frames (the layer open restores the bind-pose visibility: grey _teambuff_base01, white dummy quads)
local evt_ss_shown = nil
local EVT_PV_PrevStep = Step
function Step()
  EVT_PV_PrevStep()
  if n ~= nil and n ~= evt_ss_shown and evt_co == nil then
    evt_ss_shown = n
    evt_icon_frames = math.max(evt_icon_frames, 3)
  end
  if evt_icon_frames > 0 and evt_co == nil and not evt_pv_open then
    evt_icon_frames = evt_icon_frames - 1
    if n ~= nil then
      pcall(EVT_SS_ButtonRefresh)
    end
  end
end

-- ===================================================================================================
-- 2026-09-24: the original board screen is gone (docs/game/skill-board-original.md §8). Its button is now "Set de
-- jugador" (per-player builds: moves + Hiper + Equipamiento items + custom passive); Alt (CMD_FUNC1) does nothing.
-- A 4th square button = the ROLE badge; its picker shows the board's three badge slots in a row (none / coach /
-- manager). The custom-passive button opens the retail six-sense equip menu. All state lives in PL fields (main chunk
-- at the 200-locals limit).
-- ===================================================================================================
PL.L_BTN_ROLE = 2356951558
PL.L_ROLE_OPT = 3990407289       -- 3 badge tiles (layer with no focus; input read here)
PL.ROW_ICON_ROLE = 11
PL.ROLE_ITEM = {[1] = 2607368153, [2] = 3966662479}   -- coach / manager badge items
-- 2026-09-28: every string of the role picker and of «Set de jugador» is a menu_text row in the 9 languages
-- (research/scripts/ss2_popup_text_build.py; `--lua` prints this table, a dry run checks it against the graft).
-- Retail rows: BTN_SAVE «Guardar», BTN_BACK «Volver», BTN_SELECT «Elegir», PASSIVE «Pasiva personalizada».
-- (built in a function: 88 more constants in the main chunk pushed the key of PL.SS_ITEMS past RK 255, and the
-- assembler's decompile round trip no longer recognised that table constructor)
function PL.TxTable()
  return {
  ASK_DEL = 23924234, -- evt_pl_ask_del
  ASK_NAME = 2124515251, -- evt_pl_ask_name
  ASK_OVER = 2491308780, -- evt_pl_ask_over
  BTN_BACK = 430212020, -- retail
  BTN_DELETE = 2692191470, -- evt_pl_btn_delete
  BTN_LOAD = 509719926, -- evt_pl_btn_load
  BTN_REMOVE = 3961481199, -- retail
  BTN_RENAME = 1140374567, -- evt_pl_btn_rename
  BTN_RESET = 108624977, -- retail
  BTN_SAVE = 2306442081, -- retail
  BTN_SELECT = 2563379934, -- retail
  EXPORT_DESC = 10942846, -- evt_pl_export_desc
  EXPORT_DONE = 457094529, -- evt_pl_export_done
  EXPORT_EMPTY = 3010979655, -- evt_pl_export_empty
  EXPORT_FAIL = 2369027683, -- evt_pl_export_fail
  IMPORT_BAD = 3066746244, -- evt_pl_import_bad
  IMPORT_DESC = 3409649941, -- evt_pl_import_desc
  IMPORT_DONE = 3500371434, -- evt_pl_import_done
  IMPORT_GUIDE = 3414505662, -- evt_pl_import_guide
  IMPORT_NONE = 3206450574, -- evt_pl_import_none
  IMPORT_OTHER = 3628321451, -- evt_pl_import_other
  IMPORT_SKIP = 955832380, -- evt_pl_import_skip
  IMPORT_SUM = 4233917234, -- evt_pl_import_sum
  KB_FAIL = 510371056, -- evt_pl_kb_fail
  KB_TITLE = 2568175564, -- evt_pl_kb_title
  LOADED_SKIP = 170151676, -- evt_pl_loaded_skip
  LOADER = 2110802885, -- evt_pl_loader
  PASSIVE = 498819128, -- retail
  PV_SLOT = 3386648423, -- evt_pl_pv_slot
  PV_TITLE = 726903404, -- evt_pl_pv_title
  ROLE_0 = 182412289, -- evt_pl_role_0
  ROLE_1 = 2111329431, -- evt_pl_role_1
  ROLE_2 = 3838903597, -- evt_pl_role_2
  ROLE_DESC_0 = 3708853662, -- evt_pl_role_desc_0
  ROLE_DESC_1 = 2853678344, -- evt_pl_role_desc_1
  ROLE_DESC_2 = 857668786, -- evt_pl_role_desc_2
  ROLE_EFF_0 = 2303575434, -- evt_pl_role_eff_0
  ROLE_EFF_1 = 4266325276, -- evt_pl_role_eff_1
  ROLE_EFF_2 = 1732486310, -- evt_pl_role_eff_2
  ROLE_FAIL = 3191266877, -- evt_pl_role_fail
  ROLE_GUIDE = 2647548901, -- evt_pl_role_guide
  ROLE_NOREC = 1332833930, -- evt_pl_role_norec
  ROLE_NOW = 1480268909, -- evt_pl_role_now
  ROLE_STORY = 3154551016, -- evt_pl_role_story
  ROLE_TITLE = 2087115963, -- evt_pl_role_title
  SET_BTN = 2135514294, -- evt_pl_set_btn
  SET_BTN_GUIDE = 3362243025, -- evt_pl_set_btn_guide
  SET_EMPTY = 2056799810, -- evt_pl_set_empty
  SET_EXPORT_ROW = 1908066842, -- evt_pl_set_export_row
  SET_GUIDE = 3636575411, -- evt_pl_set_guide
  SET_HINT_1 = 561136091, -- evt_pl_set_hint_1
  SET_HINT_2 = 3095072865, -- evt_pl_set_hint_2
  SET_IMPORT_ROW = 2379296170, -- evt_pl_set_import_row
  SET_N = 3829380039, -- evt_pl_set_n
  SET_OLD = 358596258, -- evt_pl_set_old
  SKIP_FAIL = 740587531, -- evt_pl_skip_fail
  SKIP_IDOL = 618007856, -- evt_pl_skip_idol
  SKIP_INUSE = 2054247591, -- evt_pl_skip_inuse
  SKIP_LOCKED = 3674165083, -- evt_pl_skip_locked
  SKIP_NOTOWN = 3318853735, -- evt_pl_skip_notown
  SKIP_PRIME = 3425905848, -- evt_pl_skip_prime
  SKIP_ROW = 2368727989, -- evt_pl_skip_row
  SS_GUIDE = 374095222, -- evt_pl_ss_guide
  SS_QUIT = 1197300667, -- evt_pl_ss_quit
  SUM_EQUIP = 1859211264, -- evt_pl_sum_equip
  SUM_HIPER = 1201407754, -- evt_pl_sum_hiper
  SUM_MIX = 294335918, -- evt_pl_sum_mix
  SUM_MOVES = 3650984834, -- evt_pl_sum_moves
  SUM_PASSIVE = 4213968171, -- evt_pl_sum_passive
  }
end
PL.TX = PL.TxTable()
PL.ROLE_TX = {[0] = PL.TX.ROLE_0, [1] = PL.TX.ROLE_1, [2] = PL.TX.ROLE_2}
PL.ROLE_DESC_TX = {[0] = PL.TX.ROLE_DESC_0, [1] = PL.TX.ROLE_DESC_1, [2] = PL.TX.ROLE_DESC_2}
PL.ROLE_EFF_TX = {[0] = PL.TX.ROLE_EFF_0, [1] = PL.TX.ROLE_EFF_1, [2] = PL.TX.ROLE_EFF_2}

-- menu_text row (CMND_TEXT_GET) with <VALUE> replaced; "" when the row is missing (text files not installed)
function PL.Txt(id, value)
  local ok, s = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], id)
  if not ok or type(s) ~= "string" then
    s = ""
  end
  if value ~= nil then
    local v = tostring(value)
    s = string.gsub(s, "<VALUE>", function()
      return v
    end)
  end
  return s
end

function PL.RoleName(r)
  return PL.Txt(PL.ROLE_TX[r] or PL.TX.ROLE_0)
end
PL.TEX_BADGE = 1461205148                       -- #/menu/102_team/team13/team13_05c/team13_05c.g4tx (board badge slot)
PL.BADGE_SPR = {[0] = 1212007845, [1] = 2386695893, [2] = 2633480507}
PL.BTN_SLOTS = {0x68DA0494, 0x060694A0}         -- cmn03_07 base quads (off / on + add): texture-slot hashes
PL.ICON_NODE = 3165767436       -- mesh of the row-layer icon
PL.ICON_TEX = 3234721532                        -- icon_teambuff_dmy01 (texture slot of that mesh)
PL.SUB_WINDOW = 968210065
PL.SUBWIN_TEXT = 2315959435                     -- 0x8A0ABC8B (row 0.., string)
PL.SUBWIN_POS = 63483614
PL.ADD_ITEM = 1897915498                        -- CMND_ADD_ITEM_ONLY (item, count, flag)
PL.DEL_ITEM = 425598937                         -- CMND_DELETE_ITEM (item, count)
PL.ITEM_NUM = 2011560392                        -- CMND_GET_ITEM_NUM (item)
PL.EQUIPPED_NUM = 556568075                     -- (invHdl) -> copies equipped (retail equip list)
PL.REMOVE_EQUIP = 402087824                     -- CMND_REMOVE_EQUIP (chara, type)
PL.EQUIP_ITEM = 179748541                       -- CMND_EQUIP_ITEM (chara, invHdl, type)
PL.SIX_MENU = 3858305496        -- retail "Pasiva personalizada" equip menu (menu registry row)
PL.SETS = 5
PL.role_frames = 0
PL.role_shown = nil
PL.subwin_result = -1
PL.role_open = false

-- CMND_CHARACTERREFORGED_GET_ROLE -> role (0 none, 1 coach, 2 manager, 3 unresolved badge, -5 not a saved player; -1 = no loader),
-- native (creation-time staff bit: 1 coach / 2 manager, e.g. the story protagonist Destin Billows), lock (1 = story copy)
function PL.Role()
  local ok, r, _, _, native, lock = pcall(funcLuaCommand, 1327558109 --[[CMND_CHARACTERREFORGED_GET_ROLE]], n)
  if not ok or type(r) ~= "number" then
    return -1, 0, 0
  end
  return r, type(native) == "number" and native or 0, type(lock) == "number" and lock or 0
end

-- 2026-09-30 (Destin Billows): the picker never refuses silently. Every refusal names its reason: no loader, not a
-- saved player, a story-mode copy (its role belongs to the story), or the loader status of a failed change.
function PL.RoleWhy(r, lock)
  if r == -1 then
    return PL.Txt(PL.TX.LOADER)
  elseif lock == 1 then
    return PL.TxtOr(PL.TX.ROLE_STORY, "Jugador del modo historia: su rol lo decide la historia y no se cambia aquí.")
  elseif r < 0 then
    return PL.TxtOr(PL.TX.ROLE_NOREC, "Este jugador no está en tu plantilla: su rol no se puede cambiar aquí.")
  end
  return nil
end

-- badge icon on the role button: the board's badge slot sprite for the current role
function PL.RoleIcon()
  local k = PL.ROW_ICON_ROLE
  local r = PL.Role()
  -- v3: slot plate on _teambuff_base01 + the badge item's medal on the icon node (as the board's badge piece)
  EVT_ButtonIcon(k, PL.TEX_ITEM01, PL.ROLE_ITEM[r] or PL.ROLE_ITEM[1])
  funcLuaMenuCommand(C.MESH_VISIBLE, L_PV_ROW, 3877027080, true, k)
  funcLuaMenuCommand(C.SPRITE, L_PV_ROW, PL.TEX_BADGE, PL.BADGE_SPR[r] or PL.BADGE_SPR[0], PL.PLATE_SLOT, 0, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_PV_ROW, PL.ICON_NODE, PL.ROLE_ITEM[r] ~= nil, k)
  funcLuaMenuCommand(C.TEXT, PL.L_BTN_ROLE, 950238781 --[[_text_btn01]], "", 0)
  funcLuaMenuCommand(C.TEXT, PL.L_BTN_ROLE, 625330766 --[[_text_cmd01]], "", 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, k, not evt_pv_open and not PL.role_open)
  return r
end

function PL.Guide(t)
  funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], t, 0)
end

function PL.RoleGuide()
  local r, _, lock = PL.Role()
  PL.Guide(PL.RoleWhy(r, lock) or PL.Txt(PL.TX.ROLE_NOW, PL.RoleName(r)))
end

-- retail sub window with Lua strings as rows; returns the chosen row (0-based) or -1 (back).
-- 2026-09-24 fixes: the row texts are set only once the window EXISTS (0x8A0ABC8B called earlier wrote into our own
-- row layer: the move names vanished), the window is placed like the retail board's sub windows (1440, -360; it was
-- clipped off the left edge at 960, -300), and our rows are redrawn afterwards.
function EVT_PL_SubWinClosed(a1)
  PL.subwin_result = a1
  funcLuaCommand(C.CLOSE_MENU, PL.SUB_WINDOW)
end

function PL.Pick(rows, init)
  return PL.List("", rows, init)
end

-- ---- our own list window (v3) ----------------------------------------------------------------------------------------
-- The retail sub window could not be used from this menu: in game it opened clipped off the left edge whatever
-- position was sent, and its row texts landed on our move rows. Our list = the "Pasivas de la rama" panel (own layers
-- evt_passive_panel + the passive row clone, 9 rows, centred, dim background): header = title, rows = strings, the
-- selected row marked "▶" and fully opaque, up/down scroll through longer lists, Aceptar = choose, back = -1.
PL.LIST_ROWS = 9
function PL.ListShow(show, title, rows, first, sel)
  for k = 0, EVT_BG_COUNT - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_BLACKBG, k, show)
    if show then
      funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], L_BLACKBG, k, 3371859161, 0, 753088835 --[[Default]])
    end
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_PANEL, 0, show)
  for k = 0, PL.LIST_ROWS - 1 do
    local i = first + k
    local t = show and rows[i + 1] or nil
    if t ~= nil then
      local L = L_PV_ROW
      EVT_Row_Reset(k)
      funcLuaMenuCommand(C.SPRITE, L, EVT_TEX_SOCCER11_20, 1729678359 --[[passive_base01]], 1729678359, 0, k)
      funcLuaMenuCommand(C.TEXT, L, 1868134834 --[[_text_passive01]], (i == sel and "▶  " or "     ") .. t, k)
      pcall(funcLuaMenuCommand, C.TEXT_ALPHA, L, k, 1868134834, i == sel and 1 or 0.55)
    end
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, k, t ~= nil)
  end
  if show then
    local more = #rows > PL.LIST_ROWS and string.format("   (%d-%d de %d)", first + 1, math.min(#rows, first + PL.LIST_ROWS), #rows) or ""
    funcLuaMenuCommand(C.TEXT, L_PV_PANEL, 760999068 --[[_text_page01]], title .. more, 0)
  end
end

function PL.List(title, rows, init)
  local sel = math.max(0, math.min(#rows - 1, init or 0))
  local first = math.max(0, math.min(sel, #rows - PL.LIST_ROWS))
  evt_pv_open = true
  PL.ListShow(true, title, rows, first, sel)
  coroutine.yield()
  local function key(k)
    return funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], EVT_MENU_CTRL, k)
      or funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k)
  end
  local result = -1
  local P = PL.PtrStart()
  while true do
    coroutine.yield()
    local pact, pfirst, psel, owns = PL.PtrStep(P, L_PV_ROW, PL.LIST_ROWS, PL.PTR_PV, first, sel, #rows)
    if key(EVT_CMD_BACK) then
      funcLuaCommand(C.SE, SE_BACK)
      break
    elseif pact == "pick" or (not owns and (key(EVT_CMD_ENTER) or key(1651523701 --[[CMD_ENTER_CLICK]]))) then
      funcLuaCommand(C.SE, SE_DECIDE)
      result = pact == "pick" and psel or sel
      break
    elseif key(EVT_CMD_DOWN) and sel < #rows - 1 then
      sel = sel + 1
      if sel >= first + PL.LIST_ROWS then
        first = first + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      PL.ListShow(true, title, rows, first, sel)
    elseif key(EVT_CMD_UP) and sel > 0 then
      sel = sel - 1
      if sel < first then
        first = first - 1
      end
      funcLuaCommand(C.SE, 2500047763)
      PL.ListShow(true, title, rows, first, sel)
    elseif pact == "moved" then
      first, sel = pfirst, psel
      funcLuaCommand(C.SE, 2500047763)
      PL.ListShow(true, title, rows, first, sel)
    end
  end
  PL.ListShow(false, title, rows, first, sel)
  evt_pv_open = false
  coroutine.yield()                              -- the closing input must not reach our menu
  EVT_RefreshRows()
  evt_icon_frames = math.max(evt_icon_frames, 3)
  PL.role_frames = math.max(PL.role_frames, 3)
  return result
end

-- ---- role picker (v5, 2026-09-28): the retail list window ---------------------------------------------------------
-- User: the floating badge tiles and the debug-like guide line looked out of place. The picker is now the same retail
-- window as the custom-passive picker (board picker list frame team08_01 = layer evt_ss_list, rows
-- team08_02_ability_list_item, the blue backdrop over the left column): 3 rows «Sin rol / Entrenador / Gerente», each
-- with the board's badge piece (slot plate on _icon_sp_area_dmy01, the badge item's medal on _icon_sixth_dmy01) and the
-- retail check mark on the current role. The focused role is shown in the integrated panel on the right (band, the
-- medal as the big icon, name, one-line description + what the role does: coach / manager slot). Guide line = one
-- sentence; the retail button guide shows <CMD_ENTER> Elegir and <CMD_BACK> Volver. Texts: PL.TX (menu_text, 9
-- languages). The old tile layers (evt_role_badge, evt_cmn03_07_role_opt) stay in the setting, always hidden.
PL.L_BADGE = 3849871607
PL.TEX_ITEM01 = 2868599811                      -- #/menu/200_icon/02_icon_item/icon_item01.g4tx
PL.PLATE_SLOT = 2597149412                      -- teambuff_base01 (texture slot of _teambuff_base01)
PL.SLOT_AREA = 566439826                        -- icon_sp_area_dmy01 (texture slot; list row 50 px, panel 170 px)
PL.SLOT_SIXTH = 669321680                       -- icon_sixth_dmy01 (texture slot; list row 38 px, inside the 50 px one)
PL.MESH_AREA = 2164615260                       -- _icon_sp_area_dmy01
PL.MESH_SIXTH = 2384755812                      -- _icon_sixth_dmy01
PL.BAND_ROLE = {[0] = 6, [1] = 5, [2] = 5}               -- PL.BAND index: grey for none, purple (no element motif) for staff
-- retail button guide (equip_menu_inc UpdateEquipButtonGuide: texts, icons, offsets; then the commands)
-- (one assignment per line: a multiple assignment at main level broke the assembler's decompile round trip)
PL.K_ENTER = 1981080283
PL.K_BACK = 3011112225
PL.K_FUNC1 = 637335895
PL.K_FUNC3 = 3421673595
PL.K_FUNC4 = 1435897304
PL.I_ENTER = 2750714971                         -- <CMD_ENTER>
PL.I_BACK = 1582778933                          -- <CMD_BACK>
PL.I_FUNC1 = 203473330                          -- <CMD_FUNC1>
PL.I_FUNC3 = 3794706590                         -- <CMD_FUNC3>
PL.I_FUNC4 = 2085238077                         -- <CMD_FUNC4>

function PL.GuideKeys(keys)
  local t, i, o, c = {}, {}, {}, {}
  for k, e in ipairs(keys) do
    t[k], i[k], o[k], c[k] = e.text, e.icon, k == 1 and 0 or 18, e.cmd
  end
  funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], t, i, o)
  funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], c)
end

function PL.Key(k)
  return funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], EVT_MENU_CTRL, k)
    or funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k)
end

-- the integrated panel without the move parts (the look of the custom passive's fallback): band, name, description,
-- optionally the big icon (170 px, _icon_sp_area_dmy01) drawn by `icon(L)`. opts.banner: the compact card (mode
-- "plain"): the band as the card's banner with the icon 64 px and the name on it, the description under it.
function PL.PanelPlain(band, name, desc, icon, opts)
  if not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L_DETAIL) then
    return
  end
  PL.DetailHideAll()
  for _, pos in ipairs(PL.DETAIL_MOVE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, pos, false, 0)
  end
  for _, mesh in ipairs(PL.DETAIL_MOVE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, mesh, false, 0)
  end
  for _, t in ipairs(PL.DETAIL_MOVE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, t, false, 0)
  end
  for _, pr in ipairs(PL.DETAIL_MOVE_PRIM) do
    funcLuaMenuCommand(1233047821 --[[number visible]], L_DETAIL, 0, pr, false)
  end
  for i = 1, 10 do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, CALC_CRC(string.format("_tension_on%02d", i)), false, 0)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 1125548721 --[[_sp_base01]], true, 0)
  funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.BAND[band] or PL.BAND[5], 243934124 --[[sp_base01]], 0, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 1704438437 --[[_text_name01]], name, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 691026122 --[[_text_flavor01]], desc, 0)
  if icon ~= nil and pcall(icon, L_DETAIL) then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, PL.MESH_AREA, true, 0)
  end
  if opts ~= nil and opts.banner then
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, 1704438437 --[[_text_name01]], true, 0)
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, 691026122 --[[_text_flavor01]], desc ~= "", 0)
    pcall(PL.SetDetailLayout, "plain")
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, true)
  evt_detail_on = true
end

-- A list in the retail window with guide keys: mode = {row = fn(k, e, sel), focus = fn(e), guide = text,
-- keys = fn(e) -> {{text, icon, cmd, act}, ...}, act = fn(act, e, i) -> "close" | "stay" (may yield: messages),
-- refresh = fn() -> new list (after "stay")}. Returns the index (0-based) and the act that closed it, or -1.
-- 2026-10-13: a mode may bring its own frame / rows (PL.ListLayers): list_layer, row_layer, rows (visible rows),
-- ptr (pointer rect {x, w, h} of a row); default = the shared evt_ss_list / team08_02 rows (PL.SSROWS, PL.PTR_SS).
function PL.ListLayers(mode)
  mode = mode or {}
  return mode.list_layer or PL.L_SSLIST, mode.row_layer or PL.L_SSROW, mode.rows or PL.SSROWS, mode.ptr or PL.PTR_SS
end

-- the row Up / Down goes to (nil = none): mode.vert(list, sel, dir) may answer an index or false (stay), nil = the
-- next / previous row (2026-10-13: two entries drawn side by side on one row, «Exportar set | Importar set»)
function PL.ListVert(mode, list, sel, dir)
  if mode ~= nil and mode.vert ~= nil then
    local to = mode.vert(list, sel, dir)
    if to == false then
      return nil
    elseif type(to) == "number" then
      return to
    end
  end
  local to = sel + dir
  if to < 0 or to > #list - 1 then
    return nil
  end
  return to
end

function PL.PopList(list, init, mode)
  local _, RL, NR, PR = PL.ListLayers(mode)
  local sel = math.max(0, math.min(#list - 1, init or 0))
  local first = math.max(0, math.min(sel, #list - NR))
  local keys = {}
  local function show()
    PL.list_mode = mode
    PL.SSListShow(true, list, first, sel)
    keys = mode.keys(list[sel + 1]) or {}
    pcall(PL.GuideKeys, keys)
  end
  show()
  coroutine.yield()
  local result, act = -1, nil
  local P = PL.PtrStart()
  while true do
    coroutine.yield()
    local pact, pfirst, psel, owns = PL.PtrStep(P, RL, NR, PR, first, sel, #list)
    if pact == "pick" and (psel ~= sel or PL.ptr_resync) then
      PL.ptr_resync = nil
      first, sel = pfirst, psel                    -- the clicked row first (its keys / act)
      show()
    end
    if mode.tick ~= nil then
      pcall(mode.tick)                             -- 2026-10-13: per-frame upkeep (the split set row's geometry)
    end
    local hit = nil
    for _, kk in ipairs(keys) do
      local enter = kk.cmd == PL.K_ENTER
      if kk.act ~= nil and ((enter and pact == "pick")
          or (not (enter and owns) and (PL.Key(kk.cmd) or (enter and PL.Key(1651523701 --[[CMD_ENTER_CLICK]]))))) then
        hit = kk
        break
      end
    end
    local side = nil
    if hit == nil and mode.side ~= nil then
      side = mode.side(list, sel)                  -- 2026-10-13: left / right between two entries of one row
    end
    if PL.Key(EVT_CMD_BACK) then
      funcLuaCommand(C.SE, SE_BACK)
      break
    elseif side ~= nil then
      sel = side
      first = math.max(0, math.min(first, sel))
      if sel >= first + NR then
        first = sel - NR + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      show()
    elseif hit ~= nil then
      local r = mode.act(hit.act, list[sel + 1], sel)
      if r == "close" then
        result, act = sel, hit.act
        break
      end
      if mode.refresh ~= nil then
        list = mode.refresh()
      end
      show()
    elseif mode.step ~= nil and mode.step(list[sel + 1]) then
      -- 2026-09-28: the mode's own keys (graft pset_preview: Q / E page the set preview); it redraws itself
    elseif PL.Key(EVT_CMD_DOWN) and PL.ListVert(mode, list, sel, 1) ~= nil then
      sel = PL.ListVert(mode, list, sel, 1)
      if sel >= first + NR then
        first = sel - NR + 1
      end
      funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
      show()
    elseif PL.Key(EVT_CMD_UP) and PL.ListVert(mode, list, sel, -1) ~= nil then
      sel = PL.ListVert(mode, list, sel, -1)
      if sel < first then
        first = sel
      end
      funcLuaCommand(C.SE, 2500047763)
      show()
    elseif pact == "moved" then
      first, sel = pfirst, psel
      funcLuaCommand(C.SE, 2500047763)
      show()
    end
  end
  PL.SSListShow(false, list, first, sel)
  PL.list_mode = nil
  coroutine.yield()                              -- the closing input must not reach our menu
  EVT_RefreshRows()
  pcall(UpdateEquipItemInfo)                     -- the screen's own button guide and panel again
  evt_icon_frames = math.max(evt_icon_frames, 3)
  PL.role_frames = math.max(PL.role_frames, 3)
  return result, act
end

function PL.RoleRow(k, e, selected)
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, {name = e.name, check = e.current}, selected)
  -- 2026-10-06: the row's slot icon (_icon_sp_area_dmy01): the plain blue slot plate for «Sin rol», the role's
  -- gold / silver medal IN the slot (same quad, same size) for staff; the small quad (_icon_sixth_dmy01) sat off the
  -- plate's bottom-right corner, so it stays hidden in this list
  -- 2026-10-07: release a miniface another list (combo partner picker, miximax lists) bound to this slot first: a
  -- bound face icon outlives the sprite swap (Nacho saw Mercury / Flora faces instead of the medals)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  local medal = PL.ROLE_ITEM[e.role]
  if medal ~= nil then
    funcLuaMenuCommand(C.SPRITE, L, PL.TEX_ITEM01, medal, PL.SLOT_AREA, 0, k)
  else
    funcLuaMenuCommand(C.SPRITE, L, PL.TEX_BADGE, PL.BADGE_SPR[0], PL.SLOT_AREA, 0, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_AREA, true, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_SIXTH, false, k)
end

-- text broken into lines of at most `units` width (a letter 1, a CJK / kana glyph 2) at spaces (or anywhere without any)
function PL.WrapText(text, units)
  local out = {}
  for para in (text .. "\n"):gmatch("(.-)\n") do
    local line, width = "", 0
    local function flush()
      if line ~= "" then
        out[#out + 1] = (line:gsub("%s+$", ""))
      end
      line, width = "", 0
    end
    for word, space in para:gmatch("(%S+)(%s*)") do
      local w = 0
      for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        w = w + (#ch >= 3 and 2 or 1)
      end
      if width > 0 and width + w > units then
        flush()
      end
      line, width = line .. word .. space, width + w + (space ~= "" and 1 or 0)
    end
    flush()
  end
  return table.concat(out, "\n")
end

function PL.RoleFocus(e)
  PL.PanelPlain(PL.BAND_ROLE[e.role], e.name,
    PL.WrapText(PL.Txt(PL.ROLE_DESC_TX[e.role]), PL.PLAIN.wrap_units) .. "\n"
      .. PL.WrapText(PL.Txt(PL.ROLE_EFF_TX[e.role]), PL.PLAIN.wrap_units),
    function(L)
      local medal = PL.ROLE_ITEM[e.role]
      if medal ~= nil then
        funcLuaMenuCommand(C.SPRITE, L, PL.TEX_ITEM01, medal, PL.SLOT_AREA, 0, 0)
      else
        funcLuaMenuCommand(C.SPRITE, L, PL.TEX_BADGE, PL.BADGE_SPR[0], PL.SLOT_AREA, 0, 0)
      end
    end, {banner = true})
end

-- the screen's 3D model and its shadow (retail SetCharaModelVisible: the model of soccer11_05_equip_status_base)
function PL.ModelVisible(visible)
  local h = funcLuaMenuCommand(3895705890 --[[model of a layer]], 2917320188 --[[soccer11_05_equip_status_base]], 0, 0)
  if type(h) == "number" and h ~= 0 then
    funcLuaCommand(1890282463 --[[chara model visible]], h, visible)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, 858725131 --[[mainmenu01_08_chara_3d_shadow]], 0, visible)
end

function PL.RoleCoroutine()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local cur, native, lock = PL.Role()
  local why = PL.RoleWhy(cur, lock)
  if why ~= nil then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(why)
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  local list = {}
  for r = 0, 2 do
    list[#list + 1] = {role = r, name = PL.RoleName(r), current = r == cur}
  end
  PL.role_open = true
  -- 2026-10-15 (owner: «arregla la interfaz en el selector de rol»): only «Elegir» in the guide (the corner return guide
  -- mainmenu01_10 already shows Esc: «Volver» twice before), the 3D model hidden under the list, the header titled
  local keys = {{text = PL.TX.BTN_SELECT, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "pick"}}
  pcall(PL.ModelVisible, false)
  PL.HeaderTitle(PL.Txt(PL.TX.ROLE_TITLE))
  local okp, pick = pcall(PL.PopList, list, math.max(0, math.min(2, cur)), {
    row = PL.RoleRow, focus = PL.RoleFocus, guide = PL.Txt(PL.TX.ROLE_GUIDE),
    keys = function()
      return keys
    end,
    act = function()
      funcLuaCommand(C.SE, SE_DECIDE)
      return "close"
    end})
  PL.role_open = false
  PL.HeaderTitle(nil)
  pcall(PL.ModelVisible, true)
  if not okp then
    error(pick, 0)
  end
  -- «Sin rol» also runs when the badge is already gone but the creation-time staff bit is still on (native ~= 0)
  if pick >= 0 and (pick ~= cur or (pick == 0 and native ~= 0)) then
    if pick ~= 0 then
      funcLuaCommand(PL.ADD_ITEM, PL.ROLE_ITEM[pick], 1, false)   -- a free copy for the equip (retail shares stacks)
    end
    local st, now = EVT_Call(3083981324 --[[CMND_CHARACTERREFORGED_SET_ROLE]], n, pick)
    EVT_Log("role", n, cur, "->", pick, "native", native, "status", st, "now", now)
    if st == 1 then
      funcLuaCommand(C.SE, SE_DECIDE)
    else
      funcLuaCommand(C.SE, SE_NG)
      -- 2026-09-30: never a silent refusal (story copy -9, not a saved player -5, else the status code)
      -- 2026-10-08: -10 = below the matches of the mod Utilities' config.toml [role_medal] (default 0: never; now =
      -- how many are missing); its text is Utilities' row util_role_need_matches; the free copy goes back
      if st == -10 and pick ~= 0 then
        funcLuaCommand(PL.DEL_ITEM, PL.ROLE_ITEM[pick], 1)
      end
      local msg = (st == -9 and PL.RoleWhy(0, 1)) or (st == -5 and PL.RoleWhy(-5, 0))
        or (st == -10 and PL.Txt(3953080041 --[[util_role_need_matches]], now)) or PL.Txt(PL.TX.ROLE_FAIL, st)
      if msg == "" then
        msg = "No se pudo cambiar el rol (código " .. tostring(st) .. ")."
      end
      EVT_Message(msg)
    end
  end
  PL.RoleIcon()
  PL.RoleGuide()
  UpdateCharaStatus()
  coroutine.yield()                              -- the confirming input must not reach our menu
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- custom passive (v3): our own list of the owned "Pasiva personalizada" items -----------------------------------
-- In game the board's list group listed moves (it reads the open board) and the retail equip_six_sense_menu opened
-- blank (its native list is never set up outside the board / formation flow). Our list: the 37 six-sense items
-- (item kind 177 = ss_ps50001 … ss_ps50037, docs/game/passives.md), those the save owns (CMND_GET_ITEM_NUM > 0),
-- with their names, "(equipada)" / "(sin copia libre)", plus "Quitar"; equip with CMND_EVT_SIXSENSE (slot 9).
PL.SS_ITEMS = {3910925277, 1880271463, 118856433, 2574323538, 4000726980, 2004840062,
  7888616, 2428978041, 3888149487, 2265446922, 4026583708, 1762237222, 504277936,
  2154446355, 4151119493, 1852071743, 425947049, 2312925752, 4275782318, 2888477129,
  3677198687, 1109706981, 891549811, 2873585104, 3695205702, 1162415356, 843988074,
  2733711867, 3589673325, 3039926408, 3258361886, 1530919332, 741919026, 2992397457,
  3311102983, 1548893629, 726994219}

function EVT_SS_PickCoroutine()
  local locked, need, piece = EVT_SS_Lock()
  if locked then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(string.format("La pasiva personalizada se desbloquea en el Nv.%d.", need))
    return
  end
  if not PL.HasService("six_sense") then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.LOADER))
    return
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local _, cur = EVT_SS_Get()
  local items, rows = {}, {}
  for _, id in ipairs(PL.SS_ITEMS) do
    local num = funcLuaCommand(PL.ITEM_NUM, id)
    if type(num) == "number" and num > 0 then
      local name = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM]], id, 0)
      local tag = ""
      if id == cur then
        tag = "   (equipada)"
      end
      items[#items + 1] = id
      rows[#rows + 1] = (type(name) == "string" and name or string.format("%08X", id)) .. tag
    end
  end
  if cur ~= 0 then
    items[#items + 1] = 0
    rows[#rows + 1] = "Quitar la pasiva personalizada"
  end
  if #items == 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message("No tienes ninguna pasiva personalizada.")
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  local init = 0
  for i, id in ipairs(items) do
    if id == cur then
      init = i - 1
    end
  end
  local pick = PL.List("Pasiva personalizada", rows, init)
  if pick >= 0 then
    local id = items[pick + 1]
    local st, now
    if id == 0 then
      st, now = EVT_Call(1074115993, n, 1, 0, -1)
      funcLuaCommand(C.SE, st == 1 and SE_REMOVE or SE_NG)
    elseif id ~= cur then
      local h, why = PL.FreeHandle(id)
      if h == 0 then
        funcLuaCommand(C.SE, SE_NG)                -- 2026-09-28: error sound only
        EVT_Log("sixsense no handle", tostring(why))
      else
        st, now = EVT_Call(1074115993, n, 1, h, piece or -1)
        if st ~= 1 then
          funcLuaCommand(C.SE, SE_NG)              -- 2026-09-28: error sound only (status in loader.log)
        end
      end
    end
    EVT_Call(C.EVT_LOG, "skill_slots", "sixsense set", id, "status", st, "now", now)
  end
  EVT_SS_ButtonRefresh()
  pcall(EVT_SS_Info)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- Player sets: per-player builds (Character Reforged's store: scripts\player_sets.lua, blob ss_player_sets.json) --
-- Opened by the save-icon button (the screen's bottom button layer L_BTN, square skin, PL.SAVE_BUTTON). A set also
-- keeps the mix slot (PL.HsMix / PL.HsMixPut): saved, compared, loaded and exported with the rest.
-- v4 (2026-09-28, user: plain white bars on a grey box): the retail list window of the custom-passive picker (as the
-- role picker). Rows = "Set N · <name>" / "Set N · Vacío" (greyed), the first move's category + element icons, the
-- retail check mark on the set equal to the player's current build. The focused set is summed up in the integrated
-- panel (moves, Hipertécnica, equipment count, custom passive; the first move's icon as the big icon). Retail button
-- guide: <CMD_ENTER> Cargar (empty set: Guardar), <CMD_FUNC4> Guardar (overwrite, Sí/No), <CMD_FUNC1> Renombrar (the
-- game keyboard, as the save-slot screen), <CMD_FUNC3> Borrar (Sí/No), <CMD_BACK> Volver. Saving, renaming and deleting
-- keep the window open; loading closes it and lists what could not be applied. Texts: PL.TX (menu_text, 9 languages).
function PL.EquipIds()
  local e = {}
  for t = 0, 4 do
    local ok, id = pcall(GetEquipItemid, n, t)
    e[t + 1] = (ok and type(id) == "number") and EVT_U32(id) or 0
  end
  return e
end

function PL.SetGet(i)
  local r = {pcall(funcLuaCommand, 390397015 --[[CMND_CHARACTERREFORGED_PLAYER_SET_GET]], n, i)}
  if not r[1] or r[2] ~= true then
    return nil
  end
  local p = {name = r[3] or "", moves = {}, hiper = EVT_U32(r[10] or 0), equip = {}, sixsense = EVT_U32(r[16] or 0)}
  for k = 1, 6 do
    p.moves[k] = EVT_U32(r[3 + k] or 0)
  end
  for k = 1, 5 do
    p.equip[k] = EVT_U32(r[10 + k] or 0)
  end
  return p
end

-- the player's current build in the set format (rows that cannot take a move count as empty)
function PL.SetCurrent()
  local cur = {moves = {}, equip = PL.EquipIds()}
  for r = 0, EVT_ROW_NUM - 1 do
    local s = (r == 0 or not EVT_IsLocked(r)) and EVT_Skill(r) or 0
    if r == 0 then
      cur.hiper = EVT_U32(s or 0)
    else
      cur.moves[r] = EVT_U32(s or 0)
    end
  end
  local _, ss = EVT_SS_Get()
  cur.sixsense = EVT_U32(ss or 0)
  -- 2026-10-13: the kit (uniformId) of the team this screen edits, kept with a saved set for its row's miniface
  local okk, has, kit = pcall(funcLuaCommand, 1033065575 --[[CMND_GET_TEAM_SET_INFO]], n3, n17, 7)
  cur.kit = (okk and has and type(kit) == "number") and EVT_U32(kit) or 0
  local okm, mix = pcall(PL.HsMix)                  -- the mix slot (0 = empty or no mix store)
  cur.mix = (okm and type(mix) == "number") and mix or 0
  return cur
end

function PL.SetSame(p, cur)
  if p == nil then
    return false
  end
  for k = 1, 6 do
    if (p.moves[k] or 0) ~= (cur.moves[k] or 0) then
      return false
    end
  end
  for k = 1, 5 do
    if (p.equip[k] or 0) ~= (cur.equip[k] or 0) then
      return false
    end
  end
  if (p.mix or 0) ~= 0 and p.mix ~= (cur.mix or 0) then
    return false
  end
  return p.hiper == cur.hiper and p.sixsense == cur.sixsense
end

function PL.ItemName(id)
  local nm = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM]], id, 0)
  return type(nm) == "string" and nm or string.format("%08X", id)
end

function PL.SetList()
  local cur = PL.SetCurrent()
  local list = {}
  for i = 0, PL.SETS - 1 do
    local p = PL.SetGet(i)
    local e = {i = i, p = p, first = 0, current = PL.SetSame(p, cur)}
    local title = PL.Txt(PL.TX.SET_N, i + 1)
    if p == nil then
      e.name = title .. " · " .. PL.Txt(PL.TX.SET_EMPTY)
    else
      for k = 1, 6 do
        if e.first == 0 and p.moves[k] ~= 0 then
          e.first = p.moves[k]
        end
      end
      e.name = p.name ~= "" and (title .. " · " .. p.name) or title
    end
    list[#list + 1] = e
  end
  -- 2026-10-13 (owner: «mueve el icono de exportar abajo de la ranura 5, y haz uno de importar .vrmod»; «… en una
  -- sola fila»): one row under #5, «Exportar | Importar» (PL.VrmRow: two buttons of the layer evt_pset_file_btn); it
  -- acts on the last set row the cursor was on (PL.set_sel)
  list[#list + 1] = {kind = "vrm", name = PL.Txt(PL.TX.SET_EXPORT_ROW),
    names = {PL.Txt(PL.TX.SET_EXPORT_ROW), PL.Txt(PL.TX.SET_IMPORT_ROW)}}
  return list
end

-- 2026-10-13 (owner: «debería salirte la miniface con la equipación que tenías puesto en el equipo que le guardaste el
-- set al jugador, no el icono de tiro»): the player's face icon as the bank / dock lists draw it (552280324, type 9 =
-- face + kit) with the kit stored with the set (0 = an old set: the kit of his current team, resolved by the game)
function PL.SetFace(L, k, kit)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  local param = funcLuaCommand(C.CHARA_GET, n, 4) or 0
  local key = funcLuaCommand(C.CHARA_GET, n, 1) or 0
  local okk, keeper = pcall(MENU_DEF.IsKeeper, param)
  pcall(SetDisableForceCharaInvalidUseTarget)
  funcLuaMenuCommand(552280324, L, k, false, PL.MESH_AREA, PL.SLOT_AREA, n, 255, key, kit or 0, okk and keeper == true)
  pcall(SetEnableForceCharaInvalidUseTarget)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_AREA, true, k)
end

function PL.SetRowDraw(k, e, selected)
  if e.kind == "vrm" then
    PL.VrmRow(k, e, selected)
    return
  end
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, {name = e.name, grey = e.p == nil, check = e.current}, selected)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  if e.p ~= nil then
    pcall(PL.SetFace, L, k, e.p.kit)
  end
end

function PL.SetSummary(p)
  local mv = {}
  for k = 1, 6 do
    if p.moves[k] ~= 0 then
      mv[#mv + 1] = EVT_Name(p.moves[k])
    end
  end
  local lines = {PL.Txt(PL.TX.SUM_MOVES, #mv > 0 and table.concat(mv, ", ") or "-")}
  if p.hiper ~= 0 then
    lines[#lines + 1] = PL.Txt(PL.TX.SUM_HIPER, EVT_Name(p.hiper))
  end
  if (p.mix or 0) ~= 0 then
    lines[#lines + 1] = PL.Txt(PL.TX.SUM_MIX, EVT_Name(p.mix))
  end
  local eq = 0
  for k = 1, 5 do
    if p.equip[k] ~= 0 then
      eq = eq + 1
    end
  end
  local tail = PL.Txt(PL.TX.SUM_EQUIP, eq)
  if p.sixsense ~= 0 then
    tail = tail .. "  ·  " .. PL.Txt(PL.TX.SUM_PASSIVE, PL.ItemName(p.sixsense))
  end
  lines[#lines + 1] = tail
  return table.concat(lines, "\n")
end

function PL.SetFocus(e)
  if e.kind ~= nil then
    local exp = PL.SetKind(e) == "export"
    PL.PanelPlain(6, e.names[exp and 1 or 2], PL.Txt(exp and PL.TX.EXPORT_DESC or PL.TX.IMPORT_DESC, (PL.set_sel or 0) + 1))
    return
  end
  PL.set_sel = e.i
  if e.p == nil then
    PL.PanelPlain(6, e.name, PL.Txt(PL.TX.SET_BTN_GUIDE))
    return
  end
  PL.PanelPlain(5, e.name, PL.SetSummary(e.p), e.first ~= 0 and function(L)
    SetupCommandActionSkillInfoCategoryIcon(L, 0, e.first)
  end or nil)
end

-- (no «Volver» entry: the screen's corner return guide mainmenu01_10 already shows Esc; 2026-10-15 it showed twice)
function PL.SetKeys(e)
  if e ~= nil and e.kind ~= nil then
    local kind = PL.SetKind(e)
    local tx = kind == "export" and PL.TX.SET_EXPORT_ROW or PL.TX.SET_IMPORT_ROW
    return {{text = tx, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = kind}}
  end
  if e == nil or e.p == nil then
    return {{text = PL.TX.BTN_SAVE, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "save"}}
  end
  return {{text = PL.TX.BTN_LOAD, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "load"},
    {text = PL.TX.BTN_SAVE, icon = PL.I_FUNC4, cmd = PL.K_FUNC4, act = "save"},
    {text = PL.TX.BTN_RENAME, icon = PL.I_FUNC1, cmd = PL.K_FUNC1, act = "rename"},
    {text = PL.TX.BTN_DELETE, icon = PL.I_FUNC3, cmd = PL.K_FUNC3, act = "delete"}}
end

-- write set i: p = nil saves the current build (name = its first move), else p with `name`
function PL.SetWrite(i, p, name)
  if p == nil then
    local cur = PL.SetCurrent()
    local first = 0
    for r = 1, 6 do
      if first == 0 and cur.moves[r] ~= 0 then
        first = cur.moves[r]
      end
    end
    p = cur
    name = name or (first ~= 0 and EVT_Name(first) or PL.Txt(PL.TX.SET_N, i + 1))
  end
  local m, e = p.moves, p.equip
  local ok = EVT_Call(3421032623 --[[CMND_CHARACTERREFORGED_PLAYER_SET_SAVE]], n, i, EVT_Cut(name or "", 26), m[1], m[2],
    m[3], m[4], m[5], m[6], p.hiper,
    e[1], e[2], e[3], e[4], e[5], p.sixsense or 0)
  EVT_Log("player set save", i, name, ok)
  return ok
end

-- the default name of a new set: its first move, else «#N»
function PL.SetDefaultName(i)
  local cur = PL.SetCurrent()
  for r = 1, 6 do
    if cur.moves[r] ~= 0 then
      return EVT_Name(cur.moves[r])
    end
  end
  return PL.Txt(PL.TX.SET_N, i + 1)
end

-- 2026-10-13 (owner: «al guardar un set te tiene que preguntar por el nombre del set»): the game keyboard (PL.AskName,
-- the save-slot rename's arguments) prefilled with the default; cancel / no keyboard = the default
function PL.SetSave(i)
  local name = PL.SetDefaultName(i)
  local nm = PL.AskName(name)
  if type(nm) == "string" and nm ~= "" then
    name = nm
  end
  local ok = PL.SetWrite(i, nil, name)
  funcLuaCommand(C.SE, ok and SE_DECIDE or SE_NG)
end

-- the game keyboard (arguments of GENERAL_WINDOW.WaitAndSwkbWindowCoroutine, as the save-slot screen's rename):
-- string, nil (cancelled / empty) or false (the keyboard did not open)
PL.KB = {OPEN = 962493425, ACTIVE = 422535539, TEXT = 1487869455, CANCELLED = 1447363287, FORCE_END = 3351189333,
  STR_SPACES = 2431241294, MAX = 20}
function PL.AskName(initial)
  if funcLuaCommand(PL.KB.ACTIVE) then
    funcLuaCommand(PL.KB.FORCE_END, "")
    coroutine.yield()
  end
  local opened = false
  for _ = 1, 2 do
    funcLuaCommand(PL.KB.OPEN, 0, initial or "", PL.TX.KB_TITLE, 0, PL.KB.MAX, 0, 0, 0, 0, 0, 0, true, true, 2,
      PL.Txt(PL.TX.KB_TITLE), 0, false, false)
    for _ = 1, 10 do
      if funcLuaCommand(PL.KB.ACTIVE) == true then
        opened = true
        break
      end
      coroutine.yield()
    end
    if opened then
      break
    end
  end
  if not opened then
    return false
  end
  local live = ""
  while funcLuaCommand(PL.KB.ACTIVE) do
    local t = funcLuaCommand(PL.KB.TEXT)        -- live buffer (the final text / cancel flag are not reliable)
    if type(t) == "string" and t ~= "" then
      live = t
    end
    coroutine.yield()
  end
  local text = funcLuaCommand(PL.KB.TEXT)
  local cancelled = funcLuaCommand(PL.KB.CANCELLED) == true
  EVT_Log("player set keyboard", "cancelled", tostring(cancelled), "text", tostring(text), "live", live)
  if (type(text) ~= "string" or text == "") and live ~= "" then
    return PL.MxAsk(PL.Txt(PL.TX.ASK_NAME, live)) and live or nil
  end
  if cancelled or type(text) ~= "string" or text == "" or funcLuaCommand(PL.KB.STR_SPACES, text) == true then
    return nil
  end
  return text
end

function PL.SetAct(act, e, i)
  if act == "export" then
    PL.SetExport(PL.set_sel or 0)
    return "stay"
  elseif act == "import" then
    PL.SetImport(PL.set_sel or 0)
    return "stay"
  elseif act == "load" then
    funcLuaCommand(C.SE, SE_DECIDE)
    return "close"
  elseif act == "save" then
    if e.p ~= nil and not PL.MxAsk(PL.Txt(PL.TX.ASK_OVER, i + 1)) then
      funcLuaCommand(C.SE, SE_BACK)
      return "stay"
    end
    PL.SetSave(i)
  elseif act == "rename" then
    funcLuaCommand(C.SE, SE_DECIDE)
    local nm = PL.AskName(e.p.name)
    if nm == false then
      funcLuaCommand(C.SE, SE_NG)
      EVT_Message(PL.Txt(PL.TX.KB_FAIL))
    elseif nm ~= nil then
      local ok = PL.SetWrite(i, e.p, nm)
      funcLuaCommand(C.SE, ok and SE_DECIDE or SE_NG)
    end
  elseif act == "delete" then
    if PL.MxAsk(PL.Txt(PL.TX.ASK_DEL, i + 1)) then
      local ok = EVT_Call(3791889842 --[[CMND_CHARACTERREFORGED_PLAYER_SET_DELETE]], n, i)
      funcLuaCommand(C.SE, ok and SE_REMOVE or SE_NG)
    else
      funcLuaCommand(C.SE, SE_BACK)
    end
  end
  return "stay"
end

-- invHdl of an owned item with a free copy (moves / equipment / six sense share this): CMND_ADD_ITEM_ONLY returns the
-- item's stack handle (the extra copy is deleted again right away). Third value: the reason as a PL.TX skip row.
function PL.FreeHandle(item)
  local num = funcLuaCommand(PL.ITEM_NUM, item)
  if type(num) ~= "number" or num <= 0 then
    return 0, "no la tiene", PL.TX.SKIP_NOTOWN
  end
  local h = funcLuaCommand(PL.ADD_ITEM, item, 1, false)
  funcLuaCommand(PL.DEL_ITEM, item, 1)
  if h == nil or h == 0 then
    return 0, "sin objeto", PL.TX.SKIP_FAIL
  end
  local used = funcLuaCommand(PL.EQUIPPED_NUM, h)
  if type(used) == "number" and used >= num then
    return 0, "todas las copias en uso", PL.TX.SKIP_INUSE
  end
  return h, nil, nil
end

-- apply set p: everything valid is applied, the rest is listed
function PL.SetLoad(p)
  local skipped = {}
  local prime = EVT_IsPrime()
  local function skip(tx, what)
    skipped[#skipped + 1] = PL.Txt(tx, what)
  end
  local function has(skill)
    if EVT_Active(skill) then
      return true
    end
    for b = 0, 8 do
      if EVT_BoardSkill(b) == skill then
        return true
      end
    end
    local num = funcLuaCommand(PL.ITEM_NUM, skill)
    return type(num) == "number" and num > 0
  end
  if prime then
    skip(PL.TX.SKIP_PRIME)
  else
    for r = 1, 6 do
      local s = p.moves[r]
      if s ~= 0 and EVT_Skill(r) ~= s then
        if EVT_IsLocked(r) then
          skip(PL.TX.SKIP_ROW, EVT_Name(s))
        elseif PL.IdolFixed(r) then
          skip(PL.TX.SKIP_IDOL, EVT_Name(s))
        elseif not has(s) then
          skip(PL.TX.SKIP_NOTOWN, EVT_Name(s))
        else
          local ok = pcall(EVT_Equip, r, s, 0, nil)
          if not ok then
            skip(PL.TX.SKIP_FAIL, EVT_Name(s))
          end
        end
      end
    end
    if p.hiper ~= 0 and EVT_Skill(0) ~= p.hiper then
      if PL.IdolFixed(0) then
        skip(PL.TX.SKIP_IDOL, EVT_Name(p.hiper))
      elseif has(p.hiper) and EVT_IsSpecial(p.hiper) then
        pcall(EVT_Equip, 0, p.hiper, 0, nil)
      else
        skip(PL.TX.SKIP_NOTOWN, EVT_Name(p.hiper))
      end
    end
    -- the mix slot (a stored empty slot leaves the current one as it is, as every other field)
    local mix = p.mix or 0
    local okm, now = pcall(PL.HsMix)
    if mix ~= 0 and okm and now ~= mix then
      if PL.IdolFixed(0) then
        skip(PL.TX.SKIP_IDOL, EVT_Name(mix))
      elseif not has(mix) then
        skip(PL.TX.SKIP_NOTOWN, EVT_Name(mix))
      elseif not PL.HsMixPut(mix) then
        skip(PL.TX.SKIP_FAIL, EVT_Name(mix))
      end
    end
  end
  -- equipment (Equipamiento items), as the retail equip list commits
  local cur = PL.EquipIds()
  for t = 0, 4 do
    local want = p.equip[t + 1]
    if want ~= 0 and want ~= cur[t + 1] then
      local h, _, why = PL.FreeHandle(want)
      local label = PL.ItemName(want)
      if h ~= 0 then
        if cur[t + 1] ~= 0 then
          funcLuaCommand(PL.REMOVE_EQUIP, n, t)
        end
        funcLuaCommand(PL.EQUIP_ITEM, n, h, t)
        if PL.EquipIds()[t + 1] ~= want then
          skip(PL.TX.SKIP_FAIL, label)
        end
      else
        skip(why, label)
      end
    end
  end
  -- custom passive (six-sense slot)
  local _, ss = EVT_SS_Get()
  if p.sixsense ~= 0 and p.sixsense ~= ss then
    local locked = EVT_SS_Lock()
    local h, _, why = PL.FreeHandle(p.sixsense)
    local label = PL.Txt(PL.TX.PASSIVE)
    if locked then
      skip(PL.TX.SKIP_LOCKED, label)
    elseif h == 0 then
      skip(why, label)
    else
      local st = EVT_Call(1074115993, n, 1, h, -1)
      if st ~= 1 then
        skip(PL.TX.SKIP_FAIL, label)
      end
    end
  end
  -- 2026-09-28: role + configured passives of the set (graft pset_preview defines PL.SetLoadExtra)
  if PL.SetLoadExtra ~= nil then
    local okx, errx = pcall(PL.SetLoadExtra, p, skip)
    if not okx then
      EVT_Log("player set load extra", tostring(errx))
    end
  end
  EVT_AfterChange()
  EVT_SS_ButtonRefresh()
  UpdateCharaStatus()
  EVT_Log("player set load", p.name, "skipped", #skipped)
  if #skipped > 0 then
    EVT_Message(PL.Txt(PL.TX.LOADED_SKIP, table.concat(skipped, ", ")))
  else
    funcLuaCommand(C.SE, SE_DECIDE)
  end
end

function PL.SetsCoroutine()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  if not PL.HasService("player_sets") then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.LOADER))
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  local list = PL.SetList()
  local init = 0
  for k, e in ipairs(list) do
    if e.current then
      init = k - 1
    end
  end
  PL.set_sel = init
  PL.vrm_half = 0
  local pick, act = PL.PopList(list, init, {row = PL.SetRowDraw, focus = PL.SetFocus,
    guide = PL.Txt(PL.TX.SET_GUIDE), keys = PL.SetKeys, act = PL.SetAct, refresh = PL.SetList, side = PL.SetSide,
    vert = PL.SetVert})
  if pick >= 0 and act == "load" then
    local p = PL.SetGet(pick)
    if p ~= nil then
      PL.SetLoad(p)
    end
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- «Exportar set» / «Importar set» (2026-10-13): .vrmod files of one set -----------------------------------------
-- Rows 6-7 of the «Set de jugador» list (PL.SetList), acting on the last set row the cursor was on (PL.set_sel).
-- Files: Character Reforged's scripts\player_sets.lua (CMND_CHARACTERREFORGED_PLAYER_SET_EXPORT / _IMPORT_LIST /
-- _IMPORT_ENTRY / _IMPORT_READ), TOML schema utilities.vrmod/1 kind "character" in
-- <game>\modloader_exports\<config [player_sets] export_area>\.
-- docs/game/ui/vrmod-export.md §2.4. No input switch: messages are the general window (EVT_Message / PL.MxAsk).
-- (built in a function, as PL.TxTable: these numbers stay out of the main chunk's constant table)
function PL.VrmDef()
  return {
  -- the retail header clouds (icon_header_sub_upload01 / download01) cut and centred, white for the selected blue row,
  -- navy for the light rows: Character Reforged content/images/menu/200_icon/15_icon_common/player_set_icons.toml
  TEX = 2320109963,           -- #/menu/200_icon/15_icon_common/icon_common.g4tx
  UP = {[true] = 3273312901 --[[evt_vrm_up_white]], [false] = 1886212399 --[[evt_vrm_up_dark]]},
  DOWN = {[true] = 3165484893 --[[evt_vrm_down_white]], [false] = 2916954723 --[[evt_vrm_down_dark]]},
  EXPORT = 2594033569,        -- CMND_CHARACTERREFORGED_PLAYER_SET_EXPORT
  LIST = 4192844953,          -- CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_LIST
  ENTRY = 2320314186,         -- CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_ENTRY
  READ = 628491750,           -- CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_READ
  K_LEFT = 2765147006,        -- CMD_LEFT
  K_RIGHT = 2075023265,       -- CMD_RIGHT
  }
end
PL.VRM = PL.VrmDef()

-- 2026-10-13 (owner: «deberían ser exportar set | importar set en una sola fila»; in game the 7th list row only
-- showed after a scroll): ONE list entry under #5 (kind "vrm"), so the list has 6 rows.
-- 2026-10-15 (owner: «dos placas del mismo estilo lado a lado, cada una con su icono y texto»): the two halves are the
-- two instances of an own layer, evt_pset_file_btn (Character Reforged content/menus/skill_table.toml: object
-- evt_pset_file_btn = the team08_02 row with the half-width layout evt_pset_file_btn.g4pkm, plates 480 x 104 at x -98,
-- icon 46 px at x -49, text at x 22, cursor locator at x -42), attached by evt_pc_list at the row slot of instance 5
-- (_list06, left) and _list06_right (490 right). The list row instance under them is blanked. Why not inside the
-- row instance (CR 1.7.33 .. 1.8.2): the row's own G4RA keeps the _list_base_xs01_ok material hidden (type «OK», loop
-- _sma_hide_mat_01: the plate only flashes on a decide), so the right plate never showed, and a text box does not
-- follow a runtime node move (docs/game/mechanics/combo-partners.md), so both labels stayed at the row's text x.
-- Pointer: the row registers two zones (PL.ptr_split; the right half's id is k + 0.5).
function PL.FileBtnDef()
  return {
  L = 3123481048 --[[evt_pset_file_btn]],
  SLOT = 5,                   -- the list row instance the layer is attached over (evt_pc_list _list06)
  PLATE_X = -98, HALF = 480, GAP = 10,
  }
end
PL.FILE_BTN = PL.FileBtnDef()
PL.row_split = {}
PL.vrm_half = 0
PL.file_btn_shown = false

-- a row instance no longer drawn as the export / import row
function PL.RowFull(L, k)
  if L == PL.L_SSROW then
    PL.row_split[k] = nil
  end
end

-- the two export / import buttons off (the set list closed or another list drawn)
function PL.FileBtnHide()
  if not PL.file_btn_shown then
    return
  end
  PL.file_btn_shown = false
  local F = PL.FILE_BTN
  for h = 0, 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, F.L, h, false)
  end
  pcall(funcLuaMenuCommand, C.CURSOR_LOC, F.L, 3313461902 --[[cursor]], 2, 2)
end

-- one button: instance h of evt_pset_file_btn (0 = export, 1 = import), on = it has the focus
function PL.FileBtnDraw(h, text, on)
  local F = PL.FILE_BTN
  PL.Open(F.L, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, F.L, h, true)
  PL.MxRowBase(F.L, h, {name = text}, on)
  local spr = h == 0 and PL.VRM.UP[on] or PL.VRM.DOWN[on]
  funcLuaMenuCommand(C.SPRITE, F.L, PL.VRM.TEX, spr, PL.SLOT_AREA, 0, h)
  funcLuaMenuCommand(C.MESH_VISIBLE, F.L, PL.MESH_AREA, true, h)
end

-- «Exportar | Importar» for row instance k (selected = the row has the focus; PL.vrm_half = which half)
function PL.VrmRow(k, e, selected)
  local L, F = PL.L_SSROW, PL.FILE_BTN
  if k ~= F.SLOT then
    -- the layer sits over one row slot only; elsewhere (not reached: the list has 6 entries) one plain row
    PL.MxRowBase(L, k, {name = e.names[1] .. "  |  " .. e.names[2]}, selected)
    return
  end
  -- the list row under the buttons stays empty: no plate, text, icon or mark
  PL.MxRowBase(L, k, {name = ""}, false)
  PL.row_split[k] = true
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_ON, false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_OFF, false, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_ON, false, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_OFF, false, k)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  PL.file_btn_shown = true
  PL.FileBtnDraw(0, e.names[1], selected == true and PL.vrm_half == 0)
  PL.FileBtnDraw(1, e.names[2], selected == true and PL.vrm_half == 1)
end

-- the list cursor on the focused button while the export / import row has the focus (PL.SSListShow)
function PL.FileBtnCursor(RL, NR)
  local F = PL.FILE_BTN
  pcall(funcLuaMenuCommand, C.CURSOR_LOC, RL, 3313461902 --[[cursor]], NR, NR)
  pcall(funcLuaMenuCommand, C.CURSOR_LOC, F.L, 3313461902 --[[cursor]], PL.vrm_half == 1 and 1 or 0, 2)
end

-- the pointer zones of the export / import row: {left rect, right rect} ({x, w, h} from the row instance origin)
function PL.SetPtrSplit(k)
  if PL.row_split[k] then
    local F = PL.FILE_BTN
    return {{F.PLATE_X, F.HALF, PL.PTR_SS[3]}, {F.PLATE_X + F.HALF + F.GAP, F.HALF, PL.PTR_SS[3]}}
  end
  return nil
end
PL.ptr_split = PL.SetPtrSplit

-- the entry's action: the selected half of the split row
function PL.SetKind(e)
  if e ~= nil and e.kind == "vrm" then
    return PL.vrm_half == 1 and "import" or "export"
  end
  return e and e.kind
end

-- Up / Down: Down from #5 lands on «Exportar set» (left half); Down on the split row stays; Up from it goes back to
-- the last set row
function PL.SetVert(list, sel, dir)
  local e = list[sel + 1]
  if e == nil then
    return nil
  end
  if e.kind == nil then
    local nx = list[sel + 2]
    if dir > 0 and nx ~= nil and nx.kind == "vrm" then
      PL.vrm_half = 0
    end
    return nil
  end
  if dir > 0 then
    return false
  end
  for k = sel, 1, -1 do
    if list[k] ~= nil and list[k].kind == nil then
      return k - 1
    end
  end
  return false
end

-- Left / Right on the split row: the other half (same entry, redrawn); nil on a set row (its own left / right page
-- the set preview, graft pset_preview)
function PL.SetSide(list, sel)
  local e = list[sel + 1]
  if e == nil or e.kind ~= "vrm" then
    return nil
  end
  if PL.vrm_half == 0 and PL.Key(PL.VRM.K_RIGHT) then
    PL.vrm_half = 1
    return sel
  elseif PL.vrm_half == 1 and PL.Key(PL.VRM.K_LEFT) then
    PL.vrm_half = 0
    return sel
  end
  return nil
end

function PL.SetExport(i)
  local p = PL.SetGet(i)
  if p == nil then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.EXPORT_EMPTY, i + 1))
    return
  end
  local m, e = p.moves, p.equip
  local pv, cf = p.passives or {}, p.pcfg or {}
  local name = PL.MxCharaName(funcLuaCommand(C.CHARA_GET, n, 4))
  local level = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  local r = {pcall(funcLuaCommand, PL.VRM.EXPORT, n, name, level, m[1] or 0, m[2] or 0, m[3] or 0, m[4] or 0,
    m[5] or 0, m[6] or 0, p.hiper or 0, e[1] or 0, e[2] or 0, e[3] or 0, e[4] or 0, e[5] or 0, p.sixsense or 0,
    p.role or -1, p.name or "", pv[1] or 0, pv[2] or 0, pv[3] or 0, pv[4] or 0, pv[5] or 0,
    cf[1] or 0, cf[2] or 0, cf[3] or 0, cf[4] or 0, cf[5] or 0, p.kit or 0, p.mix or 0)}
  EVT_Log("player set export", i, tostring(r[1]), tostring(r[2]), tostring(r[3]), tostring(r[4]))
  if r[1] and r[2] == true and type(r[3]) == "string" then
    funcLuaCommand(C.SE, SE_DECIDE)
    -- forward slashes: a backslash before a letter could read as a text escape in the game's window
    EVT_Message(PL.Txt(PL.TX.EXPORT_DONE, "modloader_exports/" .. tostring(r[4] or "") .. "/" .. r[3]))
  else
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.EXPORT_FAIL))
  end
end

function PL.ImportRow(k, e, selected)
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, {name = e.name}, selected)
  pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L, k, PL.SLOT_AREA)
  funcLuaMenuCommand(C.SPRITE, L, PL.VRM.TEX, PL.VRM.DOWN[selected == true], PL.SLOT_AREA, 0, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.MESH_AREA, true, k)
end

-- a move of the file, checked against this install and this player. Returns the id to keep (0 = dropped) and true
-- when the move is valid. The game's rules: the Hiper row takes only special (category 8) moves, the other rows never;
-- the id must be a move of this install. From another player's file (`other`) the Hiper must also be one this player
-- already has (an active / board skill): auras and miximaxes are bound to their characters.
function PL.ImportMove(id, hiper, other)
  if id == 0 then
    return 0, true
  end
  local ok, nameId = funcLuaCommand(C.SKILL_INFO, id, 4)
  if not ok or nameId == nil then
    return 0, false
  end
  if EVT_IsSpecial(id) ~= hiper then
    return 0, false
  end
  if hiper and other then
    local own = EVT_Active(id)
    for b = 0, 8 do
      own = own or EVT_BoardSkill(b) == id
    end
    if not own then
      return 0, false
    end
  end
  return id, true
end

function PL.ImportItem(id)
  if id == 0 then
    return 0, true
  end
  local nm = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM]], id, 0)
  if type(nm) ~= "string" or nm == "" then
    return 0, false
  end
  return id, true
end

function PL.SetImport(i)
  local okc, count, area = pcall(funcLuaCommand, PL.VRM.LIST)
  if not okc or type(count) ~= "number" or count <= 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_NONE, "modloader_exports/" .. tostring(area or "")))
    return
  end
  local files = {}
  for k = 0, count - 1 do
    local oke, file, label = pcall(funcLuaCommand, PL.VRM.ENTRY, k)
    if oke and type(file) == "string" then
      files[#files + 1] = {idx = k, file = file, name = type(label) == "string" and label or file}
    end
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  local pick = PL.PopList(files, 0, {row = PL.ImportRow, guide = PL.Txt(PL.TX.IMPORT_GUIDE),
    focus = function(f)
      PL.PanelPlain(6, f.name, f.file)
    end,
    keys = function()
      return {{text = PL.TX.SET_IMPORT_ROW, icon = PL.I_ENTER, cmd = PL.K_ENTER, act = "pick"}}
    end,
    act = function()
      return "close"
    end})
  if pick < 0 or files[pick + 1] == nil then
    return
  end
  local r = {pcall(funcLuaCommand, PL.VRM.READ, files[pick + 1].idx, n)}
  EVT_Log("player set import read", files[pick + 1].file, tostring(r[1]), tostring(r[2]), tostring(r[3]))
  if not r[1] or r[2] ~= true then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_BAD))
    return
  end
  -- ok, set name, chara_param of the file, checksum ok, missing ids (text), m1..m6, hiper, e1..e5, six sense, role,
  -- p1..p5, c1..c5 (-1 = no passives stored), kit, mix
  local v = {}
  for k = 7, 37 do
    v[k - 6] = tonumber(r[k]) or 0
  end
  local setname, fparam, sumok, missing = r[3], EVT_U32(tonumber(r[4]) or 0), r[5] == true, r[6]
  if not sumok and not PL.MxAsk(PL.Txt(PL.TX.IMPORT_SUM)) then
    funcLuaCommand(C.SE, SE_BACK)
    return
  end
  local mine = EVT_U32(funcLuaCommand(C.CHARA_GET, n, 4) or 0)
  local other = fparam ~= 0 and fparam ~= mine
  local skipped = {}
  if type(missing) == "string" and missing ~= "" then
    skipped[#skipped + 1] = missing
  end
  local p = {name = type(setname) == "string" and setname or "", moves = {}, equip = {}}
  local bad = false
  for k = 1, 6 do
    local id, ok = PL.ImportMove(EVT_U32(v[k]), false, other)
    p.moves[k] = id
    if not ok then
      bad = true
      skipped[#skipped + 1] = EVT_Name(EVT_U32(v[k]))
    end
  end
  local hid, hok = PL.ImportMove(EVT_U32(v[7]), true, other)
  p.hiper = hid
  if not hok then
    bad = true
    skipped[#skipped + 1] = EVT_Name(EVT_U32(v[7]))
  end
  if other and bad then
    -- another player's set: only when every move is valid for this one
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_OTHER))
    return
  end
  for t = 1, 5 do
    local id, ok = PL.ImportItem(EVT_U32(v[7 + t]))
    p.equip[t] = id
    if not ok then
      skipped[#skipped + 1] = string.format("%08X", EVT_U32(v[7 + t]))
    end
  end
  local six, sok = PL.ImportItem(EVT_U32(v[13]))
  p.sixsense = six
  if not sok then
    skipped[#skipped + 1] = PL.Txt(PL.TX.PASSIVE)
  end
  if v[14] >= 0 and v[14] <= 2 then
    p.role = v[14]
  end
  if v[15] >= 0 then
    p.passives, p.pcfg = {}, {}
    for k = 1, 5 do
      p.passives[k] = EVT_U32(v[14 + k])
      p.pcfg[k] = EVT_U32(v[19 + k])
    end
  end
  p.kit = EVT_U32(v[25])                          -- the kit the set was saved in (0 = none: the current team's)
  local mix, mix_ok = PL.ImportMove(EVT_U32(v[26]), true, other)
  p.mix = mix
  if not mix_ok then
    skipped[#skipped + 1] = EVT_Name(EVT_U32(v[26]))
  end
  if PL.SetGet(i) ~= nil and not PL.MxAsk(PL.Txt(PL.TX.ASK_OVER, i + 1)) then
    funcLuaCommand(C.SE, SE_BACK)
    return
  end
  local name = p.name ~= "" and p.name or PL.Txt(PL.TX.SET_N, i + 1)
  local ok = PL.SetWrite(i, p, name)
  EVT_Log("player set import", i, name, "ok", tostring(ok), "other", tostring(other), "skipped", #skipped)
  if not ok then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.TX.IMPORT_BAD))
  elseif #skipped > 0 then
    funcLuaCommand(C.SE, SE_DECIDE)
    EVT_Message(PL.Txt(PL.TX.IMPORT_SKIP, table.concat(skipped, ", ")))
  else
    funcLuaCommand(C.SE, SE_DECIDE)
    EVT_Message(PL.Txt(PL.TX.IMPORT_DONE, i + 1))
  end
end

-- the former "Tabla de habilidades original" button: player sets (the original board is no longer opened)
function EVT_OpenOriginalBoard()
  if evt_co ~= nil then
    return
  end
  evt_co = coroutine.create(function()
    PL.SetsCoroutine()
  end)
end

-- ---- wrappers ---------------------------------------------------------------------------------------------------
PL.PrevInit2 = OnInit
function OnInit()
  if funcLuaCommand(C.P_HAS, 813466851) then       -- formation id (team dock; kept for the six-sense menu)
    PL.formation = funcLuaCommand(C.P_GET, 813466851)
  end
  PL.PrevInit2()
end

function PL.ClearAltGlyph()
  funcLuaMenuCommand(C.TEXT, L_BTN, 950238781 --[[_text_btn01 key glyph]], "", 0)
  funcLuaMenuCommand(C.TEXT, L_BTN, 625330766 --[[_text_cmd01 label: the button is an icon]], "", 0)
end

-- The player-sets button: the screen's bottom button layer (L_BTN) with the square skin of the other icon buttons and a
-- save icon on top: instance PL.SAVE_BUTTON.ICON of the passive-row layer (the slot of the removed passives button's
-- icon), drawn as the six-sense / role icons are (EVT_ButtonIcon). The icon follows the button's visibility (the list
-- covers and the screen modes hide the button). The hint is the guide line (PL.TX.SET_BTN_GUIDE).
-- (built in a function: these numbers stay out of the main chunk's constant table)
function PL.SaveButtonDef()
  return {
  ICON = EVT_ROW_ICON_PV,     -- row-layer instance attached at the button (_pos_btn_ico02)
  TEX = 2320109963,           -- #/menu/200_icon/15_icon_common/icon_common.g4tx
  SPRITE = 4128237245,        -- character_reforged_player_sets_icon (Character Reforged content\images)
  PRIORITY = 560,             -- as the other button icons
  IS_VISIBLE = 1262717583,    -- CMND_IS_LAYER_VISIBLE (layer, idx)
  CURSOR = 3313461902,        -- the button's cursor attach (off, as on the other square buttons)
  }
end
PL.SAVE_BUTTON = PL.SaveButtonDef()

function PL.SaveIcon()
  local B = PL.SAVE_BUTTON
  EVT_ButtonIcon(B.ICON, B.TEX, B.SPRITE)
  B.shown = nil                                    -- PL.SaveIconFollow sets the visibility on the next frame
end

-- the icon shown exactly while the button is (one check per frame; the layer command only on a change)
function PL.SaveIconFollow()
  local B = PL.SAVE_BUTTON
  local ok, visible = pcall(funcLuaMenuCommand, B.IS_VISIBLE, L_BTN, 0)
  local show = ok and visible ~= false and not evt_pv_open
  if show ~= B.shown then
    B.shown = show
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, B.ICON, show)
  end
end

-- 2026-10-12 (owner): the «Pasivas de la rama» button between «Pasiva personalizada» and «Rol» is gone; «Rol» and its
-- icon move one square button pitch left into its place (the buttons' locators: ss2_build.py BTN_ICON_DX / BTN_ROLE_DX)
PL.ROLE_SHIFT_X = -80
PL.PrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], a1, PL.ROLE_SHIFT_X, 0, 0, a2)
    funcLuaMenuCommand(C.TEXT, a1, 625330766 --[[_text_cmd01]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 950238781 --[[_text_btn01]], "", a2)
    funcLuaMenuCommand(1774843228, a1, a2, 3313461902 --[[cursor]], false)
    return
  elseif a1 == PL.L_BADGE then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 906, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_ROLE_OPT then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 895, true)
    funcLuaMenuCommand(1774843228, a1, a2, 3313461902 --[[cursor]], false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_PV_ROW and a2 == PL.ROW_ICON_ROLE then
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], a1, PL.ROLE_SHIFT_X, 0, 0, a2)
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 560, true)
    pcall(PL.RoleIcon)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, true)
    return
  elseif a1 == L_PV_ROW and a2 == PL.SAVE_BUTTON.ICON then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, PL.SAVE_BUTTON.PRIORITY, true)
    pcall(PL.SaveIcon)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, true)
    return
  end
  PL.PrevSetupLayer(a1, a2)
  if a1 == L_BTN then
    PL.ClearAltGlyph()                               -- no key glyph and no label: the button is an icon
    funcLuaMenuCommand(1774843228, a1, a2, PL.SAVE_BUTTON.CURSOR, false)
  end
end

PL.PrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
    return
  elseif a1 == PL.L_ROLE_OPT then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_BADGE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, PL.role_open)
    return
  elseif a1 == L_PV_ROW and (a2 == PL.ROW_ICON_ROLE or a2 == PL.SAVE_BUTTON.ICON) then
    PL.role_frames = 10                            -- the open restores mesh visibility: re-apply the icons
    return
  end
  PL.PrevOpenLayer(a1, a2)
  if a1 == L_BTN then
    PL.ClearAltGlyph()
  end
end

PL.PrevChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    n14 = L_BTN
    UpdateEquipItemInfo()
    pcall(PL.RoleGuide)
    return
  end
  PL.PrevChangeFocus(a1, a2)
  if a1 == L_BTN then
    PL.Guide(PL.Txt(PL.TX.SET_BTN_GUIDE))
  end
end

PL.PrevDecide = OnDecideFocus
function OnDecideFocus(a1, a2)
  if a1 == PL.L_BTN_ROLE then
    if evt_co == nil then
      evt_co = coroutine.create(function()
        PL.RoleCoroutine()
      end)
    end
    return
  end
  PL.PrevDecide(a1, a2)
end

PL.PrevFunction = OnFunction
function OnFunction(a1, a2)
  if a1 == 3918588344 then                       -- CMD_FUNC1 (Alt): free (it opened the original board)
    return
  end
  PL.PrevFunction(a1, a2)
end

PL.PrevStep = Step
function Step()
  PL.PrevStep()
  if n ~= nil and n ~= PL.role_shown and evt_co == nil then
    PL.role_shown = n
    PL.role_frames = math.max(PL.role_frames, 3)
  end
  if PL.role_frames > 0 and evt_co == nil and not evt_pv_open then
    PL.role_frames = PL.role_frames - 1
    pcall(PL.RoleIcon)
    pcall(PL.SaveIcon)
    pcall(PL.ClearAltGlyph)
  end
  pcall(PL.SaveIconFollow)
end

-- ===================================================================================================
-- ===================================================================================================
-- 2026-09-24: every former board entry point opens THIS screen (docs/game/skill-board-original.md §8.5): team dock
-- (type 5), RPG-battle team dock (story field), scout screen. The scout screen shows candidates that may not be
-- owned players, so its opener sets param evt_ss_readonly: the screen then only shows (moves, move panel, plate) and
-- refuses every change (buzzer + guide line); no board / list / role / six-sense / preset write happens.
-- ===================================================================================================
PL.KEY_READONLY = 239878988
PL.readonly = false
PL.RO_GUIDE = "Solo consulta: desde aquí no se pueden cambiar las supertécnicas."

PL.PrevInit = OnInit
function OnInit()
  if funcLuaCommand(C.P_HAS, PL.KEY_READONLY) then
    local v = funcLuaCommand(C.P_GET, PL.KEY_READONLY)
    PL.readonly = v == true or v == 1
    funcLuaCommand(C.P_CLEAR, PL.KEY_READONLY)
  end
  PL.PrevInit()
end

function PL.Refuse()
  funcLuaCommand(C.SE, SE_NG)
  funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.RO_GUIDE, 0)
end

PL.RoPrevDecide = OnDecideFocus
function OnDecideFocus(a1, a2)
  if PL.readonly then
    PL.Refuse()
    return
  end
  PL.RoPrevDecide(a1, a2)
end

PL.RoPrevFunction = OnFunction
function OnFunction(a1, a2)
  if PL.readonly and (a1 == 4109882573 --[[CMD_FUNC3 Eliminar]] or a1 == 1141890006 --[[CMD_FUNC4 Restablecer]]) then
    PL.Refuse()
    return
  end
  PL.RoPrevFunction(a1, a2)
end

PL.RoPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo()
  PL.RoPrevItemInfo()
  if PL.readonly then
    funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {}, {}, {})
    funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {})
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.RO_GUIDE, 0)
  end
end

-- ===================================================================================================
-- v5 (2026-09-24, user): the custom-passive picker has the look of the board's own list picker (what a move row /
-- the board's six-sense piece opens): the retail list frame (team05_03, layer evt_ss_list, no native list view) with
-- 7 retail list rows (team08_02_ability_list_item: six-sense icon, name, equipped / owned counts, check mark on the
-- equipped one) over the left column; the focused item is shown on the right in the integrated panel. Up/down
-- (scrolls), Aceptar = equip (CMND_EVT_SIXSENSE after a free-copy check), back = close. Last row "Quitar".
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
    local info = funcLuaCommand(1448743477 --[[CMND_GET_PASSIVE_SKILL_INFO]], 0, id)
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
    text = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 1947742101)
  end
  if type(text) == "string" and text ~= ""
      and funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], 811496143 --[[soccer_top_menu]]) then
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
    PL.Guide("Pasiva personalizada: Aceptar = equipar, atrás = volver.")
  end
end

function PL.SSList(list, init)
  local sel = math.max(0, math.min(#list - 1, init or 0))
  local first = math.max(0, math.min(sel, #list - PL.SSROWS))
  PL.SSListShow(true, list, first, sel)
  coroutine.yield()
  local function key(k)
    return funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], EVT_MENU_CTRL, k)
      or funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], k)
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
  local locked, need, piece = EVT_SS_Lock()
  if locked then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(string.format("La pasiva personalizada se desbloquea en el Nv.%d.", need))
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
      local name = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM]], id, 0)
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
    list[#list + 1] = {id = 0, name = PL.TxtOr(PL.TX.SS_QUIT, "Quitar la pasiva personalizada")}
  end
  if #list == 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message("No tienes ninguna pasiva personalizada.")
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
    return
  end
  -- 2026-09-30: the retail list window of the role picker (PL.PopList): header title, one-sentence guide line and
  -- the retail button guide (Elegir / Volver) instead of a guide line spelling out the keys
  PL.HeaderTitle(PL.TxtOr(PL.TX.PASSIVE, "Pasiva personalizada"))
  local pick = PL.PopList(list, init, {
    row = PL.SSRow, focus = PL.SSFocus,
    guide = PL.TxtOr(PL.TX.SS_GUIDE, "Elige la pasiva personalizada de este jugador. La marca indica la que lleva."),
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
      st, now = EVT_Call(1074115993, n, 1, 0, -1)
      funcLuaCommand(C.SE, st == 1 and SE_REMOVE or SE_NG)
    elseif e.id ~= cur then
      local h, why = PL.FreeHandle(e.id)
      if h == 0 then
        funcLuaCommand(C.SE, SE_NG)                -- 2026-09-28: error sound only
        EVT_Log("sixsense no handle", tostring(why))
      else
        st, now = EVT_Call(1074115993, n, 1, h, piece or -1)
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

-- ===================================================================================================
-- Miximax on the Hiper row (2026-09-25; docs/game/miximax-chrono-stone.md §9 / §12, docs/game/skill-slots.md
-- "Miximax on the Hiper row"). User v2: no choice list. Aceptar on the Hiper row opens the normal Hiper picker; its
-- first MIXIMAX entry "Crear miximax" (item wmm_evt_create, granted by the loader) runs the flow below, and the fusion
-- is the aura item wmm_evt (listed like any miximax; Eliminar on the row or on the list entry undoes it). Flow =
-- partner list (owned cards: loader
-- CMND_EVT_MX_CANDIDATES; until it answers, the current team's players, PL.MX_STUB) -> the partner's 6 moves -> yes/no
-- -> CMND_EVT_MX_SET(baseParam, partnerParam, move). When a fusion exists the Hiper row reads "Miximax: <partner>" and
-- the panel is the retail MIXIMAX aura window (mixi_base band, partner icon through the retail mask, the gained move
-- as an ATRIBUTOS row + TENSIÓN). Everything lives in PL (no new main-chunk locals).
-- ===================================================================================================
PL.MX_ON = true                                  -- false = the Hiper row opens the Hiper picker directly (as before)
PL.MX_STUB = nil                                 -- nil = auto (stub while the loader does not answer), true / false = force
PL.MX_CMD = {SET = 3209494861, GET = 2757888737, CLEAR = 520287167,
  CAN_BASE = 2189230194, PARTNER_OF = 2051756436,
  CANDIDATES = 62312748,
  PAGE_FUSION = 2603267224 --[[CMND_CHARACTERREFORGED_PAGE_FUSION]],
  PAGE_FUSION_CLEAR = 2993094043 --[[CMND_CHARACTERREFORGED_PAGE_FUSION_CLEAR]]}
-- SET codes (miximax-chrono-stone.md §12.4): 0 ok, 1 module off, 2 Prime, 3 base not found, 4 partner not owned,
-- 5 same card, 6 rule, 7 write error
PL.MX_SET_ERR = {[1] = "El módulo miximax del vr-loader está desactivado.",
  [2] = "Una carta Prime no puede ser base de un miximax.", [3] = "No se encuentra la carta base.",
  [4] = "No tienes ese jugador.", [5] = "No se puede fusionar una carta consigo misma.",
  [6] = "Ese jugador ya forma parte de otro miximax (o esta carta es compañera de otro).",
  [7] = "No se pudo guardar el miximax.",
  [10] = "Modo Overdrive: este jugador no puede usar miximax."}
PL.MX_ITEMS_CMD = 464382964
PL.MX_POS = {[1] = "PR", [2] = "DL", [3] = "MC", [4] = "DF"}
PL.MX_LAYER = 3679282495                         -- team00_30_aura_mixi_max_detail_info
PL.mx_stub = {}                                  -- stub store: baseParam -> {partner, move, chara, element, name}
PL.mx_elem = {}                                  -- partner param -> element (from the candidate list)

function PL.MxParam(hdl)
  local ok, p = pcall(funcLuaCommand, 1131797651, hdl, 4)
  return ok and type(p) == "number" and EVT_U32(p) or 0
end

function PL.MxCharaName(chara)
  local ok, a, b = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], chara, 10)
  if ok and type(b) == "string" then
    return b
  elseif ok and type(a) == "string" then
    return a
  end
  return string.format("%08X", EVT_U32(chara or 0))
end

function PL.MxStub()
  if PL.MX_STUB ~= nil then
    return PL.MX_STUB
  end
  -- detection without a card argument (a CAN_BASE probe with handle 0 on every row refresh spammed loader.log);
  -- MX_ITEMS takes no argument and is answered once the loader has the module, cached for the menu's life
  if PL.mx_live == nil then
    local ok, r = pcall(funcLuaCommand, PL.MX_ITEMS_CMD)
    PL.mx_live = ok and type(r) == "number" and r ~= 0
  end
  return not PL.mx_live
end

-- fusion of the current player: nil or {partner, move, move2, chara, best}
function PL.MxGet()
  local h = PL.mx_test_hdl or n                    -- (mx_test_hdl: harness only, nil in game)
  if h == nil or h == 0 then
    return nil
  end
  if PL.MxStub() then
    -- without Inazuma Fantasy's commands: the page slot CMND_CHARACTERREFORGED_PAGE_FUSION (All Miximaxed's running
    -- fusion, CMND_EVT_MX_GET's answer + the partner's handle; 2026-10-14: the mix panel showed nothing for its fusion)
    local okp, pexists, ppartner, pm1, pm2, pchara, pbest, phdl = pcall(funcLuaCommand, PL.MX_CMD.PAGE_FUSION, h)
    if okp and pexists == true then
      local f = {partner = EVT_U32(ppartner or 0), move = EVT_U32(pm1 or 0), move2 = EVT_U32(pm2 or 0), chara = pchara or 0,
        best = pbest == true or pbest == 1, phdl = type(phdl) == "number" and phdl or 0}
      local okk, face = pcall(funcLuaCommand, 347353059, f.partner)
      f.face = (okk and type(face) == "number" and face ~= 0) and face or f.chara
      return f
    end
    return PL.mx_stub[PL.MxParam(h)]
  end
  local ok, exists, partner, m1, m2, chara, best = pcall(funcLuaCommand, PL.MX_CMD.GET, h)
  if ok and exists then
    local f = {partner = EVT_U32(partner or 0), move = EVT_U32(m1 or 0), move2 = EVT_U32(m2 or 0), chara = chara or 0,
      best = best == true or best == 1}
    -- the partner's handle (CMND_EVT_MIXIMAX_GET: partnerHdl first) and his face key: the face-icon command takes the
    -- key retail gets from 347353059(param) (the retail miximax window path), not the chara id MX_GET returns
    local okh, phdl = pcall(funcLuaCommand, 3954244033, h)
    f.phdl = okh and type(phdl) == "number" and phdl or 0
    local okk, face = pcall(funcLuaCommand, 347353059, f.partner)
    f.face = (okk and type(face) == "number" and face ~= 0) and face or f.chara
    return f
  end
  return nil
end

-- candidate partners: list of {hdl, param, chara, element, pos, allowed, name}
function PL.MxCandidates(base)
  local out = {}
  if not PL.MxStub() then
    local start = 0
    while true do
      local r = {pcall(funcLuaCommand, PL.MX_CMD.CANDIDATES, n, start)}
      if not r[1] or type(r[2]) ~= "number" or type(r[3]) ~= "number" then
        break
      end
      local total, cnt = r[2], r[3]
      for k = 0, cnt - 1 do
        local o = 4 + k * 6
        out[#out + 1] = {hdl = r[o], param = EVT_U32(r[o + 1] or 0), chara = r[o + 2], element = r[o + 3],
          pos = r[o + 4], allowed = r[o + 5] ~= false and r[o + 5] ~= 0}
      end
      start = start + cnt
      if cnt <= 0 or start >= total then
        break
      end
    end
  else
    -- stub: the current team's players (the screen's L/R list), except the base and his other cards
    local my = funcLuaCommand(1131797651, n, 1)
    for i = 1, n15 or 0 do
      local h = t4[i]
      if h ~= nil and h ~= n and funcLuaCommand(1131797651, h, 1) ~= my then
        local p = PL.MxParam(h)
        local ok, _, pos = pcall(funcLuaCommand, 4060384944, p, 11)
        out[#out + 1] = {hdl = h, param = p, chara = funcLuaCommand(1131797651, h, 1),
          element = funcLuaCommand(1131797651, h, 8), pos = ok and pos or 0, allowed = true}
      end
    end
  end
  for _, e in ipairs(out) do
    e.name = PL.MxCharaName(e.chara)
    local pt = PL.MX_POS[e.pos]
    e.name = pt ~= nil and (e.name .. "  ·  " .. pt) or e.name
    if not e.allowed then
      e.name = e.name .. "  (en uso)"
    end
    PL.mx_elem[e.param] = e.element
  end
  return out
end

-- list rows of the three Miximax lists (the custom-passive list window, generic modes)
function PL.MxRowBase(L, k, e, selected)
  PL.RowFull(L, k)
  for _, m in ipairs(PL.SSROW_HIDE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_ON, selected, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, PL.SSROW_BASE_OFF, not selected, k)
  local name = e.grey and ("[CGRAYOUT04]" .. e.name .. "[C]") or e.name
  funcLuaMenuCommand(C.TEXT, L, PL.SSROW_TEXT_ON, name, k)
  funcLuaMenuCommand(C.TEXT, L, PL.SSROW_TEXT_OFF, name, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_ON, selected, k)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, PL.SSROW_TEXT_OFF, not selected, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260 --[[_icon_sp_area_dmy01]], false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2384755812 --[[_icon_sixth_dmy01]], false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2309656400 --[[_icon_check01]], e.check == true, k)
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, 442049775 --[[_pos_equip01]], false, k)
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, 3426045766 --[[_pos_have01]], e.num ~= nil, k)
  funcLuaMenuCommand(1233047821 --[[number visible]], L, k, 3974820126 --[[num_equip01]], false)
  funcLuaMenuCommand(1233047821 --[[number visible]], L, k, 3334923667 --[[num_have01]], e.num ~= nil)
  if e.num ~= nil then
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 2037408502 --[[_icon_have01]], false, k)
    local idx = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX]], L, k, 3334923667)
    if type(idx) == "number" and idx >= 0 then
      funcLuaMenuCommand(3609943765 --[[set number]], L, k, idx, e.num)
    end
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1255155594 --[[_icon_cmd_type_dmy01]], false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2172872396 --[[_icon_cmd_type_base01]], false, k)
end

function PL.MxRowChara(k, e, selected)
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, e, selected)
  -- miniface on the row's icon quad (as the retail aura windows draw a character icon)
  if e.chara ~= nil and e.chara ~= 0 then
    pcall(SetDisableForceCharaInvalidUseTarget)
    funcLuaMenuCommand(552280324, L, k, false, 2164615260 --[[_icon_sp_area_dmy01]], 566439826 --[[icon_sp_area_dmy01]], 0, 0, e.chara)
    pcall(SetEnableForceCharaInvalidUseTarget)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260, true, k)
  end
  -- element: the retail icon_cmd_type0N on the row's element quad
  local okg, spr = pcall(GetElementIcon, e.element)
  if okg and spr ~= nil and spr ~= 0 then
    funcLuaMenuCommand(C.SPRITE, L, 502529699 --[[icon_common <LG>]], spr, 917245562 --[[icon_cmd_type_dmy01]], 0, k)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 1255155594, true, k)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 2172872396, true, k)
  end
end

function PL.MxRowMove(k, e, selected)
  local L = PL.L_SSROW
  PL.MxRowBase(L, k, e, selected)
  if e.id ~= nil and e.id ~= 0 then
    pcall(SetupCommandActionSkillInfoCategoryIcon, L, k, e.id)     -- category icon (retail list)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260, true, k)
    pcall(SetupSpecialSkillInfoElementIcon, L, k, e.id)            -- element icon (retail list)
  end
end

-- generic list on the custom-passive window: mode = {row = fn(k, e, sel), focus = fn(e) or nil, guide = text}
function PL.MxList(list, init, mode)
  PL.MxUnblack()
  PL.list_mode = mode
  local ok, r = pcall(PL.SSList, list, init)
  PL.list_mode = nil
  if not ok then
    error(r)
  end
  return r
end

function PL.MxAsk(text)
  PL.MxUnblack()
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(2351835063 --[[MSG_KIND]], 2, 0)
  coroutine.yield()
  local r = -1
  while r == nil or r < 0 do
    r = funcLuaCommand(1523741473 --[[MSG_RESULT]])
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  return r == 0
end

function PL.MxSet(base, partner, move, move2, e)
  local st
  if PL.MxStub() then
    PL.mx_stub[base] = {partner = partner, move = move, move2 = move2, chara = e.chara, best = false}
    st = 0
  else
    local ok, done, code = pcall(funcLuaCommand, PL.MX_CMD.SET, n, e.hdl or partner, move, move2)
    st = ok and (done and 0 or (code or 7)) or 7
    if st == 0 then
      pcall(PL.MxGrant, 2, true)                     -- one carrier copy per fusion (each Hiper slot equips one)
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax set", string.format("%08X", base), string.format("%08X", partner),
    string.format("%08X", move), string.format("%08X", move2), "code", st, "stub", tostring(PL.MxStub()))
  return st
end

-- Partner step in the RETAIL BANK (2026-09-25, user: "que se vea y funcione como el banco"; docs/game/ui/
-- miximax-partner-bank.md). The screen opens chara_bank_menu_for_search (the bank the team-dock passive inherit and the
-- Basara shop use: card grid with Nv / element / position, series tabs, Z/C, Filtro, sort, name search) as a child
-- menu, the same way it opens the Hiper picker (suspend -> open -> wait -> resume). The param store key
-- evt_mx_bank_base = the base handle switches the bank's "EVT miximax_bank" graft on: TODO tab first, the personal
-- plate (right panel) opened and following the cursor, non-allowed partners greyed and refused (loader
-- CMND_EVT_MX_PARTNER_OK), and the loader (CMND_EVT_MX_BANK_MODE) keeps the base's own cards out of the list (prime
-- bank-filter detour). The bank writes the chosen handle to the retail result key 2524660062 and closes.
-- v2 (2026-09-25, user): Aceptar on a card does not close the bank: the cursor goes to the candidate's supertécnica
-- rows on the plate (retail "Confirmación de supertécnica" mode), Aceptar on a move shows the confirmation (the base's
-- plate behind it + the result: move, ideal / normal, base + gains per stat from CMND_EVT_MX_PREVIEW); Sí closes the
-- bank with the partner (result key) and the move (param store key evt_mx_bank_move), No goes back to the moves, back
-- on the moves goes back to the grid. The screen then saves the fusion without its own move list / yes-no.
-- Returns the candidate entry, false (back / nothing chosen) or nil (bank not available: the old list is used);
-- PL.mx_bank_move = the move chosen in the bank (0 = none).
PL.MX_BANK = true                                -- false = the old text list
PL.MX_BANK_MENU = 1981996040                     -- chara_bank_menu_for_search
PL.MX_BANK_KEY = 1625452628          -- param store: base handle (read and cleared by the bank graft)
PL.MX_BANK_RESULT = 2524660062                   -- retail temp int: the bank's chosen handle (0 = none)
PL.MX_BANK_MOVE = 1332263245         -- param store: the move chosen in the bank (set on Sí)
PL.MX_PLATE = 1427722143                         -- personal_plate_menu (the team dock's, suspended while we are open)
PL.MX_CMD.BANK_MODE = 998302866
PL.MX_CMD.PARTNER_OK = 83504425                  -- CMND_EVT_MX_PARTNER_OK(hdl): the bank mode's grey rule for one card

-- 2026-09-30: true when the Hiper picker just closed on «Crear miximax» and the bank can take it straight away (the
-- screen then stays suspended until the bank closes: EVT_PickCoroutine, PL.MxBankPick, PL.MxResumeDirect)
function PL.MxDirectPick(row)
  if row ~= 0 or not PL.MX_ON or not PL.MX_BANK or n == nil or n == 0 or PL.MxStub() then
    return false
  end
  if not funcLuaCommand(C.P_HAS, EVT_KEY_RESULT) or funcLuaCommand(C.P_HAS, PL.MX_KEY_DEL) then
    return false
  end
  return EVT_U32(funcLuaCommand(C.P_GET, EVT_KEY_RESULT) or 0) == PL.MX_CREATE
end

-- the screen back after a direct «Crear miximax» that did not reach the bank (refusal, error, old list)
function PL.MxResumeDirect()
  if not PL.mx_direct then
    return
  end
  PL.mx_direct = false
  funcLuaMenuCommand(C.MENU_RESUME, EVT_MENU)
  coroutine.yield()
  EVT_FocusRow(0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
end

-- the bank's pick as a partner entry, without the whole candidate list (2026-09-30: CMND_EVT_MX_CANDIDATES for every
-- owned card + a name per card froze the screen ~0.5-0.7 s before the bank opened). The grey rule is the bank's own:
-- CMND_EVT_MX_BANK_MODE(base) again (one pass over the cards) + CMND_EVT_MX_PARTNER_OK(pick), then the mode off.
-- nil = that loader cannot answer (older one): the caller falls back to the candidate list.
function PL.MxBankPartner(h)
  local okm, hidden = pcall(funcLuaCommand, PL.MX_CMD.BANK_MODE, n)
  if not okm or type(hidden) ~= "number" then
    pcall(funcLuaCommand, PL.MX_CMD.BANK_MODE, 0)
    return nil
  end
  local okp, pok = pcall(funcLuaCommand, PL.MX_CMD.PARTNER_OK, h)
  pcall(funcLuaCommand, PL.MX_CMD.BANK_MODE, 0)
  local param = PL.MxParam(h)
  local chara = funcLuaCommand(1131797651, h, 1)
  local okel, el = pcall(funcLuaCommand, 1131797651, h, 8)
  if okel and type(el) == "number" then
    PL.mx_elem[param] = el
  end
  local allowed = okp and pok ~= nil and pok ~= false and pok ~= 0
  return {hdl = h, param = param, chara = chara, allowed = allowed,
    why = (not allowed) and "Ese jugador no puede ser el compañero de este miximax." or nil}
end

-- 2026-10-13 (owner's video, bug 1: after «Sí» in the partner bank a black flash and, for a moment, this player's
-- skill table with the old Hiper): the bank closed, this screen resumed and drew itself, and only then PL.MxScenePlay
-- faded to black. Now the screen goes black as soon as the bank holds a partner AND a move (the confirmed pick) and
-- the scene will play from here (PL.MxSceneContext), so the resumed screen is never seen before the scene;
-- PL.MxScenePlay's own fade back gives it back. Any message / list / question opened before that (a refusal, an
-- error, no scene) first brings the screen back (PL.MxUnblack).
PL.mx_preblack = false
function PL.MxPreBlack(what, secs)
  if PL.mx_preblack or (what ~= nil and what ~= "miximax bank") or not PL.MX_SCENE_ON or PL.MxStub() then
    return
  end
  local okr, h = pcall(funcLuaCommand, 3185911119, PL.MX_BANK_RESULT)
  if not okr or type(h) ~= "number" or h == 0 or not funcLuaCommand(C.P_HAS, PL.MX_BANK_MOVE) then
    return
  end
  local okc, ctx = pcall(PL.MxSceneContext)
  if not okc or ctx == nil then
    return
  end
  PL.mx_preblack = true
  funcLuaCommand(609722083 --[[fade]], 1, secs)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax pre-scene black", ctx, secs)
end

function PL.MxUnblack()
  if not PL.mx_preblack then
    return
  end
  PL.mx_preblack = false
  funcLuaCommand(609722083 --[[fade]], 0, 0.2)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax pre-scene black", "given back")
end

-- open the retail bank (graft mx_bank) for this player and wait for it: seen (it opened), the chosen handle (0 = none)
function PL.BankRun(what)
  pcall(funcLuaCommand, 2565779025, PL.MX_BANK_RESULT, 0)
  funcLuaCommand(C.P_CLEAR, PL.MX_BANK_MOVE)
  PL.mx_bank_move = 0
  P_Set(PL.MX_BANK_KEY, n)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  if PL.mx_direct then
    PL.mx_direct = false                           -- still suspended since the Hiper picker: no second suspend
  else
    funcLuaMenuCommand(C.MENU_SUSPEND, EVT_MENU)
  end
  funcLuaCommand(C.OPEN_MENU, PL.MX_BANK_MENU)
  coroutine.yield()
  local seen, wait = false, 0
  while wait < 60 do                               -- the bank object appears within a few frames
    if funcLuaMenuCommand(C.EXIST_MENU, PL.MX_BANK_MENU) then
      seen = true
      break
    end
    wait = wait + 1
    coroutine.yield()
  end
  while seen and funcLuaMenuCommand(C.EXIST_MENU, PL.MX_BANK_MENU) do
    PL.MxPreBlack(what, 0.25)                      -- 2026-10-13: Si in the bank -> black while it closes
    coroutine.yield()
  end
  PL.MxPreBlack(what, 0)                           -- picked as it closed: black before this screen resumes
  funcLuaCommand(C.P_CLEAR, PL.MX_BANK_KEY)
  pcall(funcLuaCommand, PL.MX_CMD.BANK_MODE, 0)     -- the bank graft clears it too; never leave the filter on
  if funcLuaCommand(C.P_HAS, PL.MX_BANK_MOVE) then
    PL.mx_bank_move = EVT_U32(funcLuaCommand(C.P_GET, PL.MX_BANK_MOVE) or 0)
    funcLuaCommand(C.P_CLEAR, PL.MX_BANK_MOVE)
  end
  funcLuaMenuCommand(C.MENU_RESUME, EVT_MENU)
  coroutine.yield()
  EVT_FocusRow(0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
  local okr, h = pcall(funcLuaCommand, 3185911119, PL.MX_BANK_RESULT)
  pcall(funcLuaCommand, 2565779025, PL.MX_BANK_RESULT, 0)
  h = (okr and type(h) == "number") and EVT_U32(h) or 0
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", what or "miximax bank", "opened", tostring(seen), "wait", wait, "pick",
    string.format("%08X", h), "move", string.format("%08X", PL.mx_bank_move or 0))
  return seen, h
end

function PL.MxBankPick(cands)
  if not PL.MX_BANK or PL.MxStub() or n == nil or n == 0 then
    return nil
  end
  local seen, h = PL.BankRun("miximax bank")
  if not seen then
    return nil
  end
  if h == 0 then
    return false
  end
  if cands == nil then                             -- 2026-09-30: no candidate list before the bank
    local e = PL.MxBankPartner(h)
    if e ~= nil then
      return e
    end
    cands = PL.MxCandidates(PL.MxParam(n))         -- older loader: the list decides, as before
  end
  for _, e in ipairs(cands) do
    if EVT_U32(e.hdl or 0) == h then
      return e
    end
  end
  -- not in the loader's candidate list (the base's own card or an unknown one): refused below
  return {hdl = h, param = PL.MxParam(h), chara = funcLuaCommand(1131797651, h, 1), allowed = false,
    why = "Ese jugador no puede ser el compañero de este miximax."}
end

function PL.MxFlow()
  PL.mx_done = false
  local base = PL.MxParam(n)
  if not PL.MxStub() then
    local ok, can, why = false, true, nil
    if n ~= nil and n ~= 0 then
      ok, can, why = pcall(funcLuaCommand, PL.MX_CMD.CAN_BASE, n)
    end
    if ok and not can then
      PL.MxResumeDirect()
      funcLuaCommand(C.SE, SE_NG)
      -- reason 10 = a «no miximax» passive (Modo Overdrive, 2026-10-06)
      EVT_Message(tonumber(why) == 10 and PL.MX_SET_ERR[10] or (PL.MX_SET_ERR[2] .. " (o ya es compañero de otro miximax)"))
      return
    end
  end
  -- 2026-09-30: the bank first, with no candidate list (it greys / hides cards itself; the pick is checked alone in
  -- PL.MxBankPartner). The full list (CMND_EVT_MX_CANDIDATES + a name per card) only for the old text list.
  local partner = PL.MxBankPick(nil)               -- the retail bank; nil = not available -> the old list
  if partner == false then
    return
  end
  if partner == nil then
    PL.MxResumeDirect()
    local cands = PL.MxCandidates(base)
    if #cands == 0 then
      funcLuaCommand(C.SE, SE_NG)
      EVT_Message("No hay jugadores disponibles para el miximax.")
      return
    end
    for _, e in ipairs(cands) do
      e.grey = not e.allowed
    end
    local pick = PL.MxList(cands, 0, {row = PL.MxRowChara, guide = "Miximax: elige el compañero. Aceptar = elegir, atrás = volver."})
    if pick < 0 then
      return
    end
    partner = cands[pick + 1]
  end
  if not partner.allowed then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(partner.why or PL.MX_SET_ERR[6])      -- "en uso": already a base or a partner
    return
  end
  -- the partner's 6 moves; the base learns ONE of them (2026-09-25 rule, was 2): no auras / Hiper moves, no keeper
  -- moves for a non-keeper base, not a move the base already has
  local okp, _, mypos = pcall(funcLuaCommand, 4060384944, base, 11)
  local keeper = okp and mypos == 1
  local mine = {}
  for s0 = 0, 5 do
    local sk = EVT_U32(funcLuaCommand(C.GET_SKILL, n, s0) or 0)
    if sk ~= 0 then
      mine[sk] = true
    end
  end
  local moves = {}
  for s0 = 0, 5 do
    local sk = partner.hdl ~= nil and EVT_U32(funcLuaCommand(C.GET_SKILL, partner.hdl, s0) or 0) or 0
    if sk ~= 0 then
      local _, cat = funcLuaCommand(C.SKILL_INFO, sk, 9)
      local _, pw = funcLuaCommand(C.SKILL_INFO, sk, 6)
      local bad = cat == 8 or (cat == 4 and not keeper) or mine[sk] == true
      local name = EVT_Name(sk) .. (mine[sk] and "  (ya la tiene)" or "")
      moves[#moves + 1] = {id = sk, name = name, grey = bad, num = type(pw) == "number" and pw or nil}
    end
  end
  if #moves == 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message("Ese jugador no tiene supertécnicas que aprender.")
    return
  end
  local mv = nil
  if (PL.mx_bank_move or 0) ~= 0 then              -- chosen and confirmed in the bank (same rules checked there)
    for _, m in ipairs(moves) do
      if m.id == PL.mx_bank_move then
        mv = m
      end
    end
    mv = mv or {id = PL.mx_bank_move, name = EVT_Name(PL.mx_bank_move), grey = true}
  else
    local mpick = PL.MxList(moves, 0, {row = PL.MxRowMove, guide = "Miximax: elige la supertécnica que aprenderá."})
    if mpick < 0 then
      return
    end
    mv = moves[mpick + 1]
  end
  if mv.grey then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message("Esa supertécnica no se puede aprender con el miximax.")
    return
  end
  local pname = PL.MxCharaName(partner.chara)
  if (PL.mx_bank_move or 0) == 0 and not PL.MxAsk(string.format("¿Fusionar con %s y aprender %s?", pname, mv.name)) then
    funcLuaCommand(C.SE, SE_BACK)
    return
  end
  local st = PL.MxSet(base, partner.param, mv.id, 0, partner)      -- one move: move2 = 0
  if st ~= 0 then
    PL.MxUnblack()
  end
  if st == 0 then
    funcLuaCommand(C.SE, SE_DECIDE)
    PL.mx_done = true
    PL.mx_done_name = pname
    PL.mx_done_partner = partner.hdl
  else
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.MX_SET_ERR[st] or ("Error " .. tostring(st)))
  end
end

function PL.MxClear()
  local base = PL.MxParam(n)
  if PL.MxStub() then
    PL.mx_stub[base] = nil
    -- All Miximaxed's fusion (page slot CMND_CHARACTERREFORGED_PAGE_FUSION_CLEAR) and its carrier copy
    local okc, cleared = pcall(funcLuaCommand, PL.MX_CMD.PAGE_FUSION_CLEAR, n)
    if okc and cleared == true then
      local have = funcLuaCommand(PL.ITEM_NUM, PL.MX_FUSION)
      if type(have) == "number" and have > 0 then
        funcLuaCommand(PL.DEL_ITEM, PL.MX_FUSION, 1)
      end
    end
  else
    pcall(funcLuaCommand, PL.MX_CMD.CLEAR, n)
    -- the fusion's carrier copy goes with it (one wmm_evt per fusion)
    local have = funcLuaCommand(PL.ITEM_NUM, PL.MX_FUSION)
    if type(have) == "number" and have > 0 then
      funcLuaCommand(PL.DEL_ITEM, PL.MX_FUSION, 1)
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax clear", string.format("%08X", base))
  funcLuaCommand(C.SE, SE_REMOVE)
end

PL.MX_CREATE = 1033481313              -- "Crear miximax" (list entry, never equipped)
PL.MX_FUSION = 2450842569                     -- the fusion aura (the Hiper slot holds it)
PL.MX_KEY_DEL = 99760714            -- pick block: Eliminar on a list entry
PL.MX_KEY_PRIME = 2900901523          -- pick block: "Crear miximax" greyed (Prime base)
PL.MX_KEY_BASE = 19616700            -- pick block: the base player's handle (compatibility)
PL.MX_KEY_PCHARA = 1756901414        -- pick block: partner chara id of the fusion
PL.MX_KEY_M1 = 2755219383
PL.MX_KEY_M2 = 1026563597
PL.MX_KEY_FUSED = 1894840368          -- pick block: the fusion aura "Miximax" is choosable (a fusion exists)

-- the Hiper picker's result: "Crear miximax" runs the flow (then the picker opens again with the new fusion listed),
-- Eliminar on the fusion entry undoes the fusion; everything else is the normal equip
PL.MxPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  local del = funcLuaCommand(C.P_HAS, PL.MX_KEY_DEL)
  funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
  if PL.MX_ON and row == 0 and del and skill == PL.MX_FUSION then
    PL.MxClear()
    if EVT_Skill(0) == PL.MX_FUSION then
      EVT_RestoreCoroutine(0)
    end
    return
  end
  if PL.MX_ON and row == 0 and skill == PL.MX_CREATE then
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
    PL.MxFlow()
    if PL.mx_done == true then
      -- 2026-09-25 (user): no "created" step and no second pick: the fusion aura (wmm_evt, granted by the flow) is
      -- this player's Hiper right away, through the normal equip path (inv hint = the item id, as the picker gives)
      local ok, err = pcall(PL.MxPrevEquip, 0, PL.MX_FUSION, PL.MX_FUSION, cur)
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax assign", string.format("%08X", PL.MX_FUSION), tostring(ok),
        tostring(err), "hiper now", string.format("%08X", EVT_U32(EVT_Skill(0))))
      if ok and EVT_Skill(0) == PL.MX_FUSION then
        funcLuaCommand(C.SE, SE_DECIDE)
        -- 01/10 (Nacho): the Chrono Stone MIXIMAX scene first (the fusion is already saved), played over this screen
        -- (PL.MxScenePlay comes back here); then «Miximax con X asignado.». No scene = the text at once.
        local played = PL.MxScenePlay()
        -- round 4 (Nacho): no text when the scene played; the text only when there was no scene
        if not played and not PL.mx_scene_msg_shown then
          EVT_Message(string.format("Miximax con %s asignado.", PL.mx_done_name or ""))
        end
        PL.mx_scene_msg_shown = false
      else
        funcLuaCommand(C.SE, SE_NG)
        EVT_Message("El miximax se guardó pero no se pudo poner como hipertécnica.")
      end
    end
    return
  end
  return PL.MxPrevEquip(row, skill, inv_hint, cur)
end

-- ===================================================================================================
-- Chrono Stone MIXIMAX scene (docs/game/media/miximax-cutscene-cs.md §8): after «Crear miximax» saved and
-- assigned the fusion, the menu reserves story event ev99_97010 in the Inazuma Caravan map (evtgx_tm_i) with the
-- base and the partner (the loader fills them in: CMND_EVT_MX_SCENE). Pattern of the retail scene archive
-- (scene_archive_menu.PlayEventCoroutine): fade out, BGM stop, CMND_RESERVE_MAP_JUMP, close the menu,
-- CMND_RESERVE_EVENT. Only from the menu-scene team dock (soccer_team_dock_menu open: reached from the title or
-- the main menu; the RPG / Chronicle docks run inside the field scene). A skips the scene (graft mx_scene on
-- event_menu). PL.MX_SCENE_ON = false: no scene (the fusion alone). The loader's «scene pending» state is cleared
-- when the reserve fails, when this menu opens again and after 90 s (CMND_EVT_MX_SCENE_END / loader timeout).
-- ===================================================================================================
PL.MX_SCENE_ON = true
PL.MX_CMD.SCENE = 600501603             -- CMND_EVT_MX_SCENE(base) -> ok, event, map | false, reason
PL.MX_CMD.SCENE_END = 3236642153        -- CMND_EVT_MX_SCENE_END(why)
PL.MX_CMD.SCENE_STATE = 2736813206      -- CMND_EVT_MX_SCENE_STATE() -> pending, base handle, seconds
PL.MX_CMD.SCENE_RUN = 2422319640        -- CMND_EVT_MX_SCENE_RUN() -> true, slot | false, why
PL.MX_CMD.SCENE_TICK = 2768893420       -- CMND_EVT_MX_SCENE_TICK() -> "starting" | "running" | "done" | "idle"
-- 2026-10-12 (Nacho's video: no effect ever showed, the final shot far too close and without the miximax look, the top
-- bar and «A Aceptar» drawn over the scene): the scene plays through the VR-Framework's live player (the one the Mods
-- screen plays moves with over the menus, docs/game/media/visor-en-vivo.md §11): the same push of SceneEvent as IF's
-- own player, plus what that player learnt (the event camera kept current every frame, the menu models' own view
-- cleared while it plays, the sounds / photo button handled). One mechanism for both. Its end hold is switched off
-- (the scene plays to its end). PL.MX_SCENE_LIVE = false: IF's own player (CMND_EVT_MX_SCENE_RUN / _TICK) as before.
PL.MX_SCENE_LIVE = true
PL.MX_CMD.LIVE_RUN = 4161583144         -- CMND_VRFW_ANIM_LIVE_RUN(reservation, event) -> true, slot | false, why
PL.MX_CMD.LIVE_TICK = 2209917010        -- CMND_VRFW_ANIM_LIVE_TICK() -> phase, frame, total, ...
PL.MX_CMD.LIVE_CTL = 318578946          -- CMND_VRFW_ANIM_LIVE_CTL(op, n): "hold" 0 = play into the end
PL.MX_CMD.LIVE_WINDOW = 3960864664      -- CMND_VRFW_ANIM_LIVE_WINDOW(x, y, w, h, muted): w 0 = full screen
PL.MX_CMD.LIVE_VIEW = 1810537232        -- CMND_VRFW_ANIM_LIVE_VIEW(zoom, pan x, pan y): 1, 0, 0 = the event's framing
PL.mx_scene_live = false
PL.mx_scene_busy = false                -- the scene is on: this screen takes no input (our own flag, below)

-- the live player answers (a VR-Framework without it: IF's own player)
function PL.MxSceneLiveOn()
  if not PL.MX_SCENE_LIVE then
    return false
  end
  local ok, ph = pcall(funcLuaCommand, PL.MX_CMD.LIVE_TICK)
  return ok and type(ph) == "string"
end

-- run the reserved event `ev` -> pcall results (ok, true, slot | ok, false, why)
function PL.MxSceneRun(reserved, ev)
  if PL.mx_scene_live then
    pcall(funcLuaCommand, PL.MX_CMD.LIVE_WINDOW, 0, 0, 0, 0, 0)
    pcall(funcLuaCommand, PL.MX_CMD.LIVE_VIEW, 1, 0, 0)
    local ok, run, info = pcall(funcLuaCommand, PL.MX_CMD.LIVE_RUN, reserved, ev)
    if ok and run == true then
      pcall(funcLuaCommand, PL.MX_CMD.LIVE_CTL, "hold", 0)
    end
    return ok, run, info
  end
  return pcall(funcLuaCommand, PL.MX_CMD.SCENE_RUN, reserved)
end

-- one frame of the playing event -> ok, "starting" | "running" | "done" | "idle", seconds since the event start
function PL.MxSceneTick()
  if PL.mx_scene_live then
    local ok, ph, frame, total = pcall(funcLuaCommand, PL.MX_CMD.LIVE_TICK)
    return ok, ph, (type(frame) == "number" and frame / 60 or nil), (type(total) == "number" and total / 60 or nil)
  end
  return pcall(funcLuaCommand, PL.MX_CMD.SCENE_TICK)
end

-- the VR-Framework's top bar (the shortcut row of the hub's header): away while the scene plays (its param
-- vrfw_top_bar_hidden, VRFW_TopBarHide of the framework's lua _all 10_top_bar.lua; set directly when that global is
-- not in this VM)
function PL.MxSceneTopBar(hide)
  if type(VRFW_TopBarHide) == "function" then
    pcall(VRFW_TopBarHide, hide)
  elseif hide then
    pcall(funcLuaCommand, C.P_SET, 1455983968 --[[vrfw_top_bar_hidden]], 0, 1, 1)
  elseif funcLuaCommand(C.P_HAS, 1455983968) == true then
    pcall(funcLuaCommand, C.P_CLEAR, 1455983968)
  end
end
PL.MX_SCENE_DOCK = 937147172            -- soccer_team_dock_menu
PL.MX_SCENE_TOP = 811496143             -- soccer_top_menu (hub; dock opened by graft comp_menu)
PL.MX_SCENE_DOCK_TOP = 91676902         -- team_dock_common_top_menu: the dock opened it = the dock is the scene root
PL.MX_SCENE_CHRONICLE = 3902542018      -- chronicle_mode_top_menu (its dock: no scene)
-- 01/10/2026, 4th version (docs/game/media/miximax-cutscene-cs.md §9.4, static RE of nie.exe): a reserved event only
-- plays in scenes that run the event dispatcher every frame (CSceneRpg / CSceneSoccer) and have an event state that
-- pushes SceneEvent (game::EventState, menuvsroute::EventState: Chronicle / Players Universe). The team dock's
-- CSceneMenu has neither, so closing menus (versions 2-3) only left a black screen. Now the loader plays it the way
-- menuvsroute::EventState does (CMND_EVT_MX_SCENE_RUN / _TICK, transform/miximax/event_play.rs): SceneEvent is pushed
-- on top of the menu scene, NOTHING is closed, and this coroutine waits for it and comes back to this same screen.
-- The menus are suspended while it plays (as soccer_top_menu does while its dock is open).
PL.MX_SCENE_HIDE = {EVT_MENU, 1981996040 --[[chara_bank_menu_for_search]], 968210065 --[[sub_window]],
  1427722143 --[[personal_plate_menu]], 935586083 --[[team_dock_formation_menu]], 2049316981 --[[soccer_formation_menu]],
  937147172 --[[soccer_team_dock_menu]], 91676902 --[[team_dock_common_top_menu]], 811496143 --[[soccer_top_menu]]}
-- 02/10/2026 (Nacho): the header bar («Equipamiento», team plate, rank), the guide line and the button guide were
-- still drawn over the scene (the blue speed-line background stays, as wanted). They are layers of the dock's common
-- top menu / the hub (team_dock_common_top_menu OnSetupLayer: mainmenu90_01_header, mainmenu90_31_doc_item; soccer_top
-- also mainmenu90_03_header_rank) and of the screen's parent (button guide, mainmenu01_06_base_button_guide). Hidden with
-- the retail per-menu layer visibility command 3579981806(menu, layer, 0 | 1) (soccer_top_menu_inc
-- SetButtonGuideVisibleFromTopMenu) and given back with 1 in reverse order.
PL.MX_SCENE_BAR_MENUS = {91676902 --[[team_dock_common_top_menu]], 811496143 --[[soccer_top_menu]],
  937147172 --[[soccer_team_dock_menu]]}
PL.MX_SCENE_BARS = {575058101 --[[mainmenu90_01_header]], 2750436121 --[[mainmenu90_03_header_rank]],
  2279382105 --[[mainmenu90_31_doc_item]], 3078308064 --[[mainmenu90_05_content_guide_line01]],
  1138543975 --[[mainmenu01_06_base_button_guide]]}
PL.MX_CMD.MENU_LAYER_VISIBLE = 3579981806
-- -> list of {menu, layer} hidden
-- 02/10 12:10 (Nacho's video): the button guide went, the header and the guide line stayed (3579981806 does not
-- reach them). Graft mx_scene_bars puts EVT_MxSceneBars(hide) in team_dock_common_top_menu and soccer_top_menu; it is
-- called there with the retail cross-menu call 830228314 (as SwapSoccerTopCommonHeaderByHeaderType).
PL.MX_SCENE_BAR_OWNERS = {91676902 --[[team_dock_common_top_menu]], 811496143 --[[soccer_top_menu]]}
function PL.MxSceneBarOwners(hide)
  for _, m in ipairs(PL.MX_SCENE_BAR_OWNERS) do
    if funcLuaMenuCommand(C.EXIST_MENU, m) == true then
      local ok, r = pcall(funcLuaCommand, 830228314, m, "EVT_MxSceneBars", hide)
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene bars", string.format("%08X", m), tostring(hide),
        tostring(ok), tostring(r))
    end
  end
end
function PL.MxSceneBars(hide, list)
  if not hide then
    PL.MxSceneBarOwners(false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, 3078308064 --[[mainmenu90_05_content_guide_line01]], 0, true)
    for i = #list, 1, -1 do
      pcall(funcLuaMenuCommand, PL.MX_CMD.MENU_LAYER_VISIBLE, list[i][1], list[i][2], 1)
    end
    return list
  end
  PL.MxSceneBarOwners(true)
  -- 02/10 round 2: «Reparte los puntos de Libertad…» is this screen's own guide line (graft training_btn), drawn even
  -- with the menu hidden
  funcLuaMenuCommand(C.LAYER_VISIBLE, 3078308064 --[[mainmenu90_05_content_guide_line01]], 0, false)
  local out, seen = {}, {}
  local menus = {}
  for _, m in ipairs(PL.MX_SCENE_BAR_MENUS) do menus[#menus + 1] = m end
  if n12 ~= nil and n12 ~= 0 then menus[#menus + 1] = n12 end
  for _, m in ipairs(menus) do
    if not seen[m] and funcLuaMenuCommand(C.EXIST_MENU, m) == true then
      seen[m] = true
      for _, L in ipairs(PL.MX_SCENE_BARS) do
        if pcall(funcLuaMenuCommand, PL.MX_CMD.MENU_LAYER_VISIBLE, m, L, 0) then
          out[#out + 1] = {m, L}
        end
      end
    end
  end
  return out
end
PL.MX_SCENE_MAX_FRAMES = 60 * 180      -- give the menus back after 3 min whatever the loader says
-- 02/10 12:10 (Nacho's video): the partner never showed, the base did. A scene played over the menu scene only shows
-- character models already loaded by a menu (the base: this screen's 3D model and the formation frame); the partner is
-- in no team, so nothing has loaded him. Round 2 loaded him in this screen's model (it evicted the base); now he goes to
-- chara_model_only_view_menu (PL.MxScenePreload below). PL.MX_SCENE_PRELOAD = false: off.
PL.MX_SCENE_PRELOAD = true
PL.MX_SCENE_MODEL_LAYER = 2917320188   -- soccer11_05_equip_status_base
PL.MX_SCENE_PRELOAD_MAX = 240          -- coroutine steps waiting for the model
-- «Miximax con X asignado.» INSIDE the scene (Nacho, 02/10): from the end of the animation to the white flash, timed
-- with CMND_EVT_MX_SCENE_TICK's seconds since the event started (recipe research/recipes/mx_scene/mx_scene.toml:
-- animation 0-220, hold_frames 84 -> white at frame 304; 60 fps). Not shown again afterwards.
PL.MX_SCENE_MSG = false               -- round 4 (Nacho): no «Miximax con X asignado.» with the scene
PL.MX_SCENE_MSG_AT = 3.75
PL.MX_SCENE_MSG_END = 5.05
PL.MX_SCENE_MSG_MENU = 449578137       -- general_window

-- this screen's 3D model shows card h (the retail SetupCharaModel reads the screen's card n)
function PL.MxSceneModel(h)
  local keep = n
  n = h
  local ok, err = pcall(SetupCharaModel, PL.MX_SCENE_MODEL_LAYER, 0)
  n = keep
  return ok, err
end

-- 02/10 12:42 (round 2): loading the partner in this screen's model evicted the base (the formation frame did not keep
-- it): only the partner showed. Now the base stays in this screen's model and the partner goes to the retail one-model
-- view menu chara_model_only_view_menu (opened, never shown; graft mx_scene_model): this screen's SetupCharaModel runs
-- for the partner with funcLuaMenuCommand recorded (nothing executed here) and its model commands are replayed on that
-- menu's layer through the retail cross-menu call 830228314. That menu's Step reports «ready» in the parameter store.
PL.MX_SCENE_MV = 275734212             -- chara_model_only_view_menu
PL.MX_SCENE_MV_READY = 2277088171      -- crc32 "evt_mx_scene_model_ready" (graft mx_scene_model)
PL.MX_SCENE_MV_SKIP = {[4219344099] = true --[[shadow]], [629267548] = true --[[open layer]]}
PL.mx_scene_mv_opened = false

-- the model commands this screen's SetupCharaModel sends for card h (recorded, not executed)
function PL.MxSceneModelCmds(h)
  local rec = {}
  local real = funcLuaMenuCommand
  funcLuaMenuCommand = function(...)
    rec[#rec + 1] = table.pack(...)
    return nil
  end
  local keep = n
  n = h
  local ok, err = pcall(SetupCharaModel, PL.MX_SCENE_MODEL_LAYER, 0)
  n = keep
  funcLuaMenuCommand = real
  return ok, err, rec
end

function PL.MxSceneMv(name, ...)
  return pcall(funcLuaCommand, 830228314, PL.MX_SCENE_MV, name, ...)
end

-- -> true when the partner's model is loaded in chara_model_only_view_menu (the base stays in this screen's model)
function PL.MxScenePreload(h)
  if not PL.MX_SCENE_PRELOAD or type(h) ~= "number" or h == 0 then
    return false
  end
  local ok, err, rec = PL.MxSceneModelCmds(h)
  if not ok or #rec == 0 then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene preload", "no model commands", tostring(err))
    return false
  end
  if funcLuaMenuCommand(C.EXIST_MENU, PL.MX_SCENE_MV) ~= true then
    funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], PL.MX_SCENE_MV)
    PL.mx_scene_mv_opened = true
  end
  local steps = 0
  while steps < PL.MX_SCENE_PRELOAD_MAX do
    coroutine.yield()
    steps = steps + 1
    local okl, loading = pcall(funcLuaCommand, 667479479, PL.MX_SCENE_MV)
    if funcLuaMenuCommand(C.EXIST_MENU, PL.MX_SCENE_MV) == true and not (okl and loading == true) then
      break
    end
  end
  coroutine.yield()
  PL.MxSceneMv("EVT_MxSceneModelBegin")
  local sent = 0
  for _, r in ipairs(rec) do
    local cmd = r[1]
    if r[2] == PL.MX_SCENE_MODEL_LAYER and not PL.MX_SCENE_MV_SKIP[cmd] then
      if cmd == 2232914067 --[[CMND_CHARA_MODEL_CHANGE]] then
        PL.MxSceneMv("EVT_MxSceneModelCmd", 180466856 --[[motion]], 2263925137 --[[立ち1L]], 0, 0)
        PL.MxSceneMv("EVT_MxSceneModelCmd", cmd, 0, 9)
      else
        PL.MxSceneMv("EVT_MxSceneModelCmd", cmd, table.unpack(r, 4, r.n))
      end
      sent = sent + 1
    end
  end
  PL.MxSceneMv("EVT_MxSceneModelWatch")
  local ready, wait = nil, 0
  while wait < PL.MX_SCENE_PRELOAD_MAX * 2 do
    coroutine.yield()
    wait = wait + 1
    if funcLuaCommand(C.P_HAS, PL.MX_SCENE_MV_READY) then
      ready = funcLuaCommand(C.P_GET, PL.MX_SCENE_MV_READY)
      funcLuaCommand(C.P_CLEAR, PL.MX_SCENE_MV_READY)
      break
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene preload", string.format("%08X", EVT_U32(h)),
    "model view", tostring(PL.mx_scene_mv_opened), "commands", sent, "ready", tostring(ready), "steps", steps, wait)
  return ready == 1
end

-- Round 4 (Nacho): the base with the miximax look, like the form viewer shows it. The form viewer's pick
-- (CMND_EVT_FORM_MODEL(card, 1) = Miximax: module form_view maps every model request of that character to the look
-- record menu_look(base, partner), pair texture included) is set before this screen's model is rebuilt, so the model
-- the menus keep loaded (and the scene's base actor, created while the pick holds) is the fused one; cleared after the
-- scene. The whole scene shows the fused base (one look per character per load). PL.MX_SCENE_FUSED = false: off.
-- Round 5: only used with PL.MX_SCENE_SWAP = false (the swap below puts the look on at the white flash instead).
PL.MX_SCENE_FUSED = true
PL.MX_CMD.FORM_MODEL = 1114211089      -- CMND_EVT_FORM_MODEL(hdl, form) -> look model id (0 = none)
PL.MX_CMD.FORM_CLEAR = 1884094670      -- CMND_EVT_FORM_CLEAR()
PL.MX_SCENE_SHADOW_LAYER = 858725131   -- mainmenu01_08_chara_3d_shadow

-- wait (coroutine) until this screen's model is built, at most n steps
function PL.MxSceneModelWait(steps_max)
  local steps = 0
  while steps < steps_max do
    coroutine.yield()
    steps = steps + 1
    local okr, r = pcall(funcLuaMenuCommand, 1583438030, PL.MX_SCENE_MODEL_LAYER, 0, 0)
    if okr and r == true and steps >= 4 then
      return true, steps
    end
  end
  return false, steps
end

-- -> look model id when the fused look is on
function PL.MxSceneFusedLook()
  if not PL.MX_SCENE_FUSED then
    return 0
  end
  local ok, id = pcall(funcLuaCommand, PL.MX_CMD.FORM_MODEL, n, 1)
  id = (ok and type(id) == "number") and id or 0
  if id ~= 0 then
    PL.MxSceneModel(n)                   -- rebuilt: the request now maps to the look
    local ready, steps = PL.MxSceneModelWait(PL.MX_SCENE_PRELOAD_MAX)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene fused look", string.format("%08X", EVT_U32(id)),
      "ready", tostring(ready), "steps", steps)
  else
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene fused look", "none", tostring(ok))
  end
  return id
end

-- Round 5 (Nacho, 02/10 13:30): the base wore the miximax look from the first frame. He keeps his own look until the
-- white flash and takes the miximax look under it. The scene's characters are NOT new models: LOAD_ACTOR_CHARA
-- binds each actor to the character object a menu already holds with that chara id (round 4 log: the event made no
-- model request for its two players; round 3: the table's model came back moved by the event). So the base actor IS
-- this screen's model object, and the look is swapped on it mid-scene: at PL.MX_SCENE_SWAP_AT seconds after the
-- event runs (inside the full white the recipe holds: research/recipes/mx_scene/mx_scene.toml white_hold_frames;
-- mx_scene_build.py check reads this value), the form viewer's Miximax pick is set and this screen's model commands
-- for the card are sent again (recorded from SetupCharaModel, without the layer / shadow / pose ones, so the event
-- keeps its placement and motion). The event hides the base at the full white and shows / re-attaches him at the
-- final shot. PL.MX_SCENE_SWAP = false: round 4 (fused look for the whole scene, if PL.MX_SCENE_FUSED).
-- Round 6: off (in Nacho's round-5 test the fused player never showed after the mid-scene swap). PL.MX_SCENE_FINAL
-- replaces it (below).
PL.MX_SCENE_SWAP = false
PL.MX_SCENE_SWAP_AT = 4.75             -- seconds since running (event frame 285; full white 280..320)
PL.MX_SCENE_SWAP_MAX = 30              -- coroutine steps waiting for the fused model (the white still holds 35)
PL.MX_SCENE_SWAP_SKIP = {[4219344099] = true --[[shadow]], [629267548] = true --[[open layer]],
  [953552931] = true --[[pose]]}

-- the swap: Miximax pick + this screen's model commands for the card -> look id (0 = no look), commands sent
function PL.MxSceneSwapBegin()
  local ok, id = pcall(funcLuaCommand, PL.MX_CMD.FORM_MODEL, n, 1)
  id = (ok and type(id) == "number") and id or 0
  if id == 0 then
    return 0, 0
  end
  local okc, _err, rec = PL.MxSceneModelCmds(n)
  local sent = 0
  if okc then
    for _, r in ipairs(rec) do
      if r[2] == PL.MX_SCENE_MODEL_LAYER and not PL.MX_SCENE_SWAP_SKIP[r[1]] then
        pcall(funcLuaMenuCommand, table.unpack(r, 1, r.n))
        sent = sent + 1
      end
    end
  end
  return id, sent
end

-- Round 6 (docs/game/media/miximax-cutscene-cs.md §9.13): the finishing shot is a SECOND event (the loader's
-- CMND_EVT_MX_SCENE gives its name, ev99_97020). An event actor binds, when the event starts, to the character object
-- a menu holds; round 4 showed the fused look when it was on the base's model BEFORE the event, round 5 changed it
-- inside the event and the base never came back. So: the main event ends in its white flash -> the white is held
-- (retail white fade 4011714927) -> this screen (resumed for it, still hidden) puts the Miximax look on its model
-- (round 4's PL.MxSceneFusedLook) and its shadow layer stays hidden -> the final event (the base alone, from white,
-- in the stand) is reserved and played -> the caller restores everything as before. PL.MX_SCENE_FINAL = false: the
-- main event alone (it then ends in white without the base fused).
PL.MX_SCENE_FINAL = true
PL.MX_CMD.WHITE_FADE = 4011714927       -- retail white fade (1 out / 0 in, seconds): the title's SwitchCaseTitleFade
PL.MX_SCENE_END_BLACK = 0.25            -- seconds before the final event's end: the fade to black starts
PL.MX_SCENE_END_FADE = 0.15             -- its length (black before the last frame)

-- -> {look = id (0 none), ready, steps, st = TICK state at the end / why not played}
function PL.MxSceneFinal(ev2)
  local r = {look = 0, ready = false, steps = 0, st = "not run", bars = {}}
  pcall(funcLuaCommand, PL.MX_CMD.WHITE_FADE, 1, 0)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final", ev2, "white held")
  pcall(funcLuaMenuCommand, 66378409 --[[resume]], EVT_MENU)
  local okf, id = pcall(PL.MxSceneFusedLook)
  r.look = (okf and type(id) == "number") and id or 0
  if r.look ~= 0 then
    -- PL.MxSceneFusedLook waited for the model; read the state once more for the log
    local okr, ready = pcall(funcLuaMenuCommand, 1583438030, PL.MX_SCENE_MODEL_LAYER, 0, 0)
    r.ready = okr and ready == true
  end
  pcall(funcLuaMenuCommand, C.LAYER_VISIBLE, PL.MX_SCENE_SHADOW_LAYER, 0, false)
  pcall(funcLuaMenuCommand, 369172623 --[[suspend]], EVT_MENU)
  -- 2026-10-12 (Nacho's video): resumed for the look, the screen drew its button guide again («A Aceptar» behind the
  -- final shot): the bars are hidden once more (given back with the others)
  r.bars = PL.MxSceneBars(true)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final look", string.format("%08X", EVT_U32(r.look)),
    "ready", tostring(r.ready))
  local okr, a, b = pcall(funcLuaCommand, 822852817 --[[CMND_RESERVE_EVENT]], CALC_CRC(ev2))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final reserved", ev2, tostring(okr), tostring(a), tostring(b))
  if not okr then
    r.st = "reserve failed"
    return r
  end
  local okp, run, info = PL.MxSceneRun(a, ev2)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final run", tostring(okp), tostring(run), tostring(info),
    PL.mx_scene_live and "live player" or "IF player")
  if not okp or run ~= true then
    r.st = "run refused"
    return r
  end
  -- 2026-10-13 (owner's video, bug 3: as the fused player came back, for an instant another player stood on his left):
  -- the final event ended on a visible frame and, until this screen restored its models, the menu scene drew its
  -- own models (the partner in the one-model view menu, this screen's model) for a frame. The screen now fades to
  -- black PL.MX_SCENE_END_BLACK seconds before the final event's end (black at once when the end comes first), the
  -- menus are restored under it and PL.MxScenePlay's fade back shows the page.
  local frames, st, black = 0, "starting", false
  while frames < PL.MX_SCENE_MAX_FRAMES do
    coroutine.yield()
    frames = frames + 1
    local okt, s, secs, total = PL.MxSceneTick()
    st = okt and s or "error"
    if st ~= "starting" and st ~= "running" then
      break
    end
    if not black and st == "running" and type(secs) == "number" and type(total) == "number" and total > 0
        and secs >= total - PL.MX_SCENE_END_BLACK then
      black = true
      funcLuaCommand(609722083 --[[fade]], 1, PL.MX_SCENE_END_FADE)
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final", "black before the end", secs, total)
    end
  end
  if not black then
    funcLuaCommand(609722083 --[[fade]], 1, 0)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final", "black at the end", frames)
  end
  r.st = st
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene final back", st, frames)
  return r
end

-- round 4: after the scene the table's model was tiny and far (left at the scene's / model view's placement): the
-- model layer and its shadow are closed and opened again, so the retail OnOpenLayer builds them as when the screen
-- opened (placement, camera, scale, pose), with the pick cleared (his own look)
function PL.MxSceneModelRestore(fused)
  if fused ~= 0 then
    pcall(funcLuaCommand, PL.MX_CMD.FORM_CLEAR)
  end
  pcall(funcLuaMenuCommand, 1273612389 --[[CMND_CLOSE_LAYER]], PL.MX_SCENE_MODEL_LAYER, 0)
  pcall(funcLuaMenuCommand, 1273612389 --[[CMND_CLOSE_LAYER]], PL.MX_SCENE_SHADOW_LAYER, 0)
  coroutine.yield()
  pcall(funcLuaMenuCommand, 629267548 --[[CMND_OPEN_LAYER]], PL.MX_SCENE_MODEL_LAYER, 0)
  pcall(funcLuaMenuCommand, 629267548 --[[CMND_OPEN_LAYER]], PL.MX_SCENE_SHADOW_LAYER, 0)
  local ready, steps = PL.MxSceneModelWait(PL.MX_SCENE_PRELOAD_MAX)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene model restored", "ready", tostring(ready), "steps", steps)
end

-- after the scene: the one-model view menu closed (only when this screen opened it)
function PL.MxScenePreloadEnd()
  if PL.mx_scene_mv_opened then
    pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], PL.MX_SCENE_MV)
    PL.mx_scene_mv_opened = false
  end
end
-- routes that play it (false = only «Miximax con X asignado.»)
PL.MX_SCENE_ROUTES = {root = true, hub = true}
-- "root", "hub" or nil, reason
function PL.MxSceneContext()
  local function has(m)
    return funcLuaMenuCommand(C.EXIST_MENU, m) == true
  end
  if not has(PL.MX_SCENE_DOCK) then
    return nil, "not the menu-scene team dock"
  end
  if has(PL.MX_SCENE_CHRONICLE) then
    return nil, "Chronicle dock"
  end
  local ctx
  if has(PL.MX_SCENE_TOP) then
    ctx = "hub"
  elseif has(PL.MX_SCENE_DOCK_TOP) then
    ctx = "root"
  else
    return nil, "dock neither the scene root nor under soccer_top_menu"
  end
  if PL.MX_SCENE_ROUTES[ctx] ~= true then
    return nil, ctx .. " route off (PL.MX_SCENE_ROUTES)"
  end
  return ctx
end

-- true = the scene played and the screen is back (the caller then shows «Miximax con X asignado.»)
function PL.MxScenePlay()
  if not PL.MX_SCENE_ON or PL.MxStub() or n == nil or n == 0 then
    return false
  end
  local ctx, why = PL.MxSceneContext()
  if ctx == nil then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene", "skipped: " .. why)
    PL.MxUnblack()
    return false
  end
  -- the loader's player must be there BEFORE anything is reserved (an older inazuma_fantasy.dll has no _TICK: a
  -- reservation nobody plays would wait for the next story field)
  PL.mx_scene_live = PL.MxSceneLiveOn()
  local okt0, t0 = PL.MxSceneTick()
  if not okt0 or type(t0) ~= "string" then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene", "skipped: the loader has no scene player")
    PL.MxUnblack()
    return false
  end
  local ok, go, ev, map, phdl, ev2, fxn = pcall(funcLuaCommand, PL.MX_CMD.SCENE, n)
  if not ok or go ~= true or type(ev) ~= "string" then
    PL.MxUnblack()
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene", ctx, tostring(ok), tostring(go), tostring(ev), tostring(map),
    tostring(phdl), "final", tostring(ev2), "effects installed", tostring(fxn))
  -- round 6 (docs §9.13): the finishing shot is a second event the loader prepared (ev2 ~= ""): the base's
  -- miximax look goes on his model between the two events, so the second event's actor binds to the fused model
  local two = PL.MX_SCENE_FINAL and ok and type(ev2) == "string" and ev2 ~= ""
  PL.mx_scene_msg_shown = false
  if not ok or go ~= true or type(ev) ~= "string" then
    return false
  end
  -- 2026-10-12: nothing of this screen reacts while the scene plays (own flag: its callbacks and Step polls return at
  -- once, see the guard at the end of the file; the menu's input state / controller is never touched)
  PL.mx_scene_busy = true
  PL.MxSceneTopBar(true)
  funcLuaCommand(1382940092 --[[CMND_BGM_STOP]], 0.5)
  funcLuaCommand(609722083 --[[fade]], 1, 0.5)
  while funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) do
    coroutine.yield()
  end
  -- under the black: this screen's 3D model loads the partner (see PL.MX_SCENE_PRELOAD)
  if type(phdl) ~= "number" or phdl == 0 then
    phdl = PL.mx_done_partner
  end
  -- round 6: two events = the look goes on between them (PL.MxSceneFinal); round 5: mid-scene (PL.MX_SCENE_SWAP, it
  -- never showed); round 4: before the scene (the base fused from the first frame)
  local fused = (two or PL.MX_SCENE_SWAP) and 0 or PL.MxSceneFusedLook()
  local summary = {main = "not run", final = two and ev2 or "-", look = 0, ready = "-", final_run = "-"}
  local preloaded = PL.MxScenePreload(phdl)
  local okr, a, b = pcall(funcLuaCommand, 822852817 --[[CMND_RESERVE_EVENT]], CALC_CRC(ev))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene reserved", ev, tostring(okr), tostring(a), tostring(b))
  local played = false
  local hidden = {}
  local bars = {}
  if okr then
    -- 01/10 23:30 (Nacho): the scene showed BEHIND the skill table: suspending the layer groups does not stop the
    -- drawing. Hide every menu of the stack the way the retail hides them for a full-screen movie
    -- (scene_archive_menu.PlayMovieCoroutine / soccer_top_menu: 1670867360(1, menu) ... 3257327861(menu)), and put the
    -- menu scene's blue backdrop (craft object bg10000, as soccer_top_menu does after its movie) behind the players.
    for _, m in ipairs(PL.MX_SCENE_HIDE) do
      if funcLuaMenuCommand(C.EXIST_MENU, m) == true then
        funcLuaMenuCommand(369172623 --[[suspend]], m)
        funcLuaMenuCommand(1670867360 --[[hide (movie)]], 1, m)
        hidden[#hidden + 1] = m
      end
    end
    bars = PL.MxSceneBars(true)
    funcLuaCommand(3048355248 --[[CMND_EXEC_CRAFT_OBJ_ID]], 623523592 --[[bg10000]])
    local okp, run, info = PL.MxSceneRun(a, ev)   -- a = the reservation id
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene run", tostring(okp), tostring(run), tostring(info),
      PL.mx_scene_live and "live player" or "IF player")
    if okp and run == true then
      local frames, st = 0, "starting"
      local msg = 0                      -- 0 not yet, 1 open, 2 closed
      local swap, swap_steps = 0, 0      -- 0 not yet, 1 waiting for the fused model, 2 done
      while frames < PL.MX_SCENE_MAX_FRAMES do
        coroutine.yield()
        frames = frames + 1
        local okt, s, secs = PL.MxSceneTick()
        st = okt and s or "error"
        if st ~= "starting" and st ~= "running" then
          break
        end
        -- round 5: the miximax look under the white flash (a DLL without the seconds: no swap, his own look)
        if PL.MX_SCENE_SWAP and swap == 0 and st == "running" and type(secs) == "number" and secs >= PL.MX_SCENE_SWAP_AT then
          local id, sent = PL.MxSceneSwapBegin()
          fused = id
          swap = id ~= 0 and 1 or 2
          pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene swap", string.format("%08X", EVT_U32(id)),
            "commands", sent, "at", secs)
        elseif swap == 1 then
          swap_steps = swap_steps + 1
          local okr, r = pcall(funcLuaMenuCommand, 1583438030, PL.MX_SCENE_MODEL_LAYER, 0, 0)
          if (okr and r == true and swap_steps >= 4) or swap_steps >= PL.MX_SCENE_SWAP_MAX then
            swap = 2
            pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene swap ready", tostring(okr and r == true), "steps",
              swap_steps, "at", secs)
          end
        end
        -- «Miximax con X asignado.» between the end of the animation and the white flash (a DLL without the seconds
        -- returns none: the text comes after the scene as before)
        if PL.MX_SCENE_MSG and st == "running" and type(secs) == "number" then
          if msg == 0 and secs >= PL.MX_SCENE_MSG_AT then
            msg = 1
            PL.mx_scene_msg_shown = true
            pcall(funcLuaCommand, C.MSG_OPEN, string.format("Miximax con %s asignado.", PL.mx_done_name or ""), 0, 0, 0,
              0, 0, false)
            pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene message", "open", secs)
          elseif msg == 1 and secs >= PL.MX_SCENE_MSG_END then
            msg = 2
            pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], PL.MX_SCENE_MSG_MENU)
            pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene message", "closed", secs)
          end
        end
      end
      if msg == 1 then
        pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], PL.MX_SCENE_MSG_MENU)
      end
      played = st == "done"
      summary.main = st
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene back", st, frames)
      if played and two then
        local r = PL.MxSceneFinal(ev2)
        fused = r.look
        summary.look, summary.ready, summary.final_run = r.look, tostring(r.ready), r.st
        for _, b in ipairs(r.bars or {}) do
          bars[#bars + 1] = b
        end
      end
    else
      summary.main = "run refused"
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene summary", "actors base + partner (partner model ready",
    tostring(preloaded) .. ")", "main", summary.main, "final", summary.final, "look", string.format("%08X", EVT_U32(summary.look)),
    "look ready", summary.ready, "final run", summary.final_run, "effects installed", tostring(fxn),
    "(drawn: see mods: trace lines)")
  PL.MxSceneBars(false, bars)
  for i = #hidden, 1, -1 do
    funcLuaMenuCommand(3257327861 --[[show again]], hidden[i])
    funcLuaMenuCommand(66378409 --[[resume]], hidden[i])
  end
  PL.MxScenePreloadEnd()
  PL.MxSceneModelRestore(fused)
  pcall(funcLuaCommand, PL.MX_CMD.SCENE_END, played and "played over the menus" or "not played")
  PL.MxSceneTopBar(false)
  PL.mx_scene_busy = false
  PL.mx_preblack = false                         -- the fade back below gives the screen back
  funcLuaCommand(52227211 --[[CMND_BGM_RESUME]])
  funcLuaCommand(609722083 --[[fade]], 0, 0.3)
  while funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) do
    coroutine.yield()
  end
  return played
end

-- this menu open again (back from the scene, or any later visit): the scene is over. Opened for the card of a scene
-- that was still pending (the dock's way back, graft mx_scene_back): «Miximax con X asignado.» once the screen is up.
PL.MxScenePrevInit = OnInit
function OnInit()
  local okS, on, base = pcall(funcLuaCommand, PL.MX_CMD.SCENE_STATE)
  pcall(funcLuaCommand, PL.MX_CMD.SCENE_END, "skill slot menu opened")
  local r = PL.MxScenePrevInit()
  if okS and on == true and type(base) == "number" and n ~= nil and EVT_U32(base) == EVT_U32(n) then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax scene: back on the card", string.format("%08X", EVT_U32(n)))
    PL.deferred[#PL.deferred + 1] = coroutine.create(PL.MxSceneBackMessage)
  end
  return r
end

function PL.MxSceneBackMessage()
  for _ = 1, 20 do                     -- the screen's open animation / first rows
    coroutine.yield()
  end
  while funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) do
    coroutine.yield()
  end
  local f = PL.MxGet()
  local name = f ~= nil and PL.MxCharaName(f.chara) or ""
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  EVT_Message(string.format("Miximax con %s asignado.", name))
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- yes/no "¿Quitar el miximax con X?": Sí = MX_CLEAR + the Hiper slot emptied; true when removed
function PL.MxAskRemove()
  local f = PL.MxGet()
  if f == nil then
    return false
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local yes = PL.MxAsk(string.format("¿Quitar el miximax con %s?", PL.MxCharaName(f.chara)))
  if yes then
    PL.mx_removing = true
    pcall(PL.MxPrevRestore, 0)                    -- the Hiper slot emptied (native Eliminar path)
    PL.mx_removing = false
    PL.MxClear()
  else
    funcLuaCommand(C.SE, SE_BACK)
  end
  EVT_RefreshRows()
  UpdateEquipItemInfo()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
  return yes
end

PL.MxPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  if row == 0 and PL.MX_ON and EVT_Skill(0) == PL.MX_FUSION and PL.MxGet() ~= nil then
    PL.MxAskRemove()                               -- 2026-09-25 rule: no picker while a fusion is the Hiper
    return
  end
  if row == 0 then
    funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
    funcLuaCommand(C.P_CLEAR, PL.MX_KEY_PRIME)
    funcLuaCommand(C.P_CLEAR, PL.MX_KEY_FUSED)
    for _, k in ipairs({PL.MX_KEY_PCHARA, PL.MX_KEY_M1, PL.MX_KEY_M2, 3808658029}) do
      funcLuaCommand(C.P_CLEAR, k)
    end
    P_Set(PL.MX_KEY_BASE, n)                     -- the picker checks the retail miximaxes against this player
    if PL.MX_ON and EVT_IsPrime() then
      P_Set(PL.MX_KEY_PRIME, 1)
    elseif PL.MX_ON and not PL.MxStub() then
      local okc, can = false, false
      if n ~= nil and n ~= 0 then
        okc, can = pcall(funcLuaCommand, PL.MX_CMD.CAN_BASE, n)
      end
      local okg, gr = false, "not asked"
      if okc and can then
        okg, gr = pcall(PL.MxGrant, 1)             -- "Crear miximax" in the MIXIMAX tab
      end
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax picker", "hdl", tostring(n), "can_base", tostring(okc),
        tostring(can), "grant", tostring(okg), tostring(gr))
      local okf, f = pcall(PL.MxGet)
      if okf and f ~= nil then
        P_Set(PL.MX_KEY_FUSED, 1)                  -- the fusion aura is choosable only with a fusion
        P_Set(PL.MX_KEY_PCHARA, f.chara or 0)      -- the picker draws the fusion as the partner + the 2 moves
        P_Set(3808658029, f.face or f.chara or 0)   -- the partner's face key (portrait)
        P_Set(PL.MX_KEY_M1, f.move or 0)
        P_Set(PL.MX_KEY_M2, f.move2 or 0)
      end
    end
    -- «Crear nuevo cambio» + the player's changes in the «Modo cambio» tab (2026-10-04: it was never called, the tab
    -- stayed empty); Prime cards get no pseudo-items, as «Crear miximax»
    if not EVT_IsPrime() then
      local okc, errc = pcall(PL.McPrepare)
      if not okc then
        pcall(EVT_Call, C.EVT_LOG, "skill_slots", "mode change picker", "error", tostring(errc))
      end
    end
  end
  -- 2026-09-25: the loader drops "Crear miximax" and the fusion carrier from every Habilidades list; the Hiper
  -- picker keeps "Crear miximax" only while this flag is 1 (docs/game/ui/miximax-partner-bank.md §6)
  local flag = row == 0 and PL.MX_ON and not EVT_IsPrime()
  pcall(funcLuaCommand, 489464673, 2656223599, flag and 1 or 0)
  local ok, err = pcall(PL.MxPrevPick, row)
  pcall(funcLuaCommand, 489464673, 2656223599, 0)
  if not ok then
    error(err, 0)
  end
end

-- the two items are not in the save by default (§12.5): "Crear miximax" is granted when the Hiper picker opens for a
-- base that can fuse, the fusion aura when the first fusion is made; never a second copy. which: 1 create, 2 fusion
function PL.MxGrant(which, force)
  local ok, create, fusion = pcall(funcLuaCommand, PL.MX_ITEMS_CMD)
  if not ok or type(create) ~= "number" then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax items", tostring(ok), tostring(create))
    return false
  end
  create, fusion = EVT_U32(create), EVT_U32(fusion or 0)
  PL.MX_CREATE, PL.MX_FUSION = create, fusion
  local id = which == 1 and create or fusion
  if id == 0 then
    return false
  end
  local have = funcLuaCommand(PL.ITEM_NUM, id)
  if type(have) == "number" and have > 0 and not force then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax grant", string.format("%08X", id), "already owned", have)
    return "owned"
  end
  local h = funcLuaCommand(PL.ADD_ITEM, id, 1, false)
  local after = funcLuaCommand(PL.ITEM_NUM, id)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax grant", string.format("%08X", id), "hdl", tostring(h),
    "count", tostring(after))
  return "granted"
end

-- Eliminar on the Hiper row while it holds the fusion: the fusion is undone too
PL.MxPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if PL.MX_ON and row == 0 and EVT_Skill(0) == PL.MX_FUSION and not PL.mx_removing then
    PL.MxAskRemove()                               -- Eliminar on the row: the same confirm
    return
  end
  PL.MxPrevRestore(row)
end

-- the Hiper row with a fusion: "Miximax: <partner>"
PL.MxPrevRow = UpdateEquipListItem
function UpdateEquipListItem(a1)
  PL.MxPrevRow(a1)
  if a1 ~= 0 or not PL.MX_ON then
    return
  end
  local okf, f = pcall(PL.MxGet)
  if okf and f ~= nil and EVT_Skill(0) == PL.MX_FUSION then
    local info = GetEquipListItemInfo(GetEquipType(0))
    local text = EVT_Name(PL.MX_FUSION)             -- 2026-10-12 (owner): the move's name only, never the player's
    if EVT_SPECIAL_LABEL ~= "" then
      text = EVT_SPECIAL_LABEL .. "   " .. text
    end
    funcLuaMenuCommand(C.TEXT, L_ROW, info.itemTextName, text, 0)
  end
end

-- the Hiper panel with a fusion: the retail MIXIMAX aura window drawn by hand (no aura skill exists for it yet)
-- stat gains of the current base's fusion (loader CMND_EVT_MX_GAINS(base) -> ok, favouredMask, 9 gains in the
-- CMND_EVT_CHARA_STAT order; gain = floor(partner stat x multiplier), the hiper_slot formula) as 3 lines of
-- "Stat +N", favoured stats in the game's passive highlight colour. nil when the loader does not answer.
PL.MX_GAINS = 3782039711
PL.MX_STAT_NAME = {"Disparo", "Control", "Técnica", "Presión", "Físico", "Inteligencia", "Agilidad", "Rapidez", "Suerte"}
PL.MX_HIGHLIGHT = "[CPASSIVE01]"                 -- the game's highlight colour tag (passive values), "[C]" = back
function PL.MxGainsText()
  local r = {pcall(funcLuaCommand, PL.MX_GAINS, PL.mx_test_hdl or n)}
  if not r[1] or not r[2] or type(r[4]) ~= "number" then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax gains", "no answer", tostring(r[1]), tostring(r[2]))
    return nil
  end
  local mask = tonumber(r[3]) or 0
  local parts = {}
  for _, i in ipairs({1, 2, 3, 4, 5, 6, 7, 9}) do   -- 8 stats: slot 8 (Rapidez) retired 2026-09-30
    local g = tonumber(r[3 + i]) or 0
    local fav = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
    local s = string.format("%s +%d", PL.MX_STAT_NAME[i], g)
    parts[#parts + 1] = fav and (PL.MX_HIGHLIGHT .. s .. "[C]") or s
  end
  return table.concat({table.concat(parts, "   ", 1, 3), table.concat(parts, "   ", 4, 6),
    table.concat(parts, "   ", 7, 8)}, "\n")
end

-- the aura that comes with the miximax (loader CMND_EVT_MX_AURA(chara) -> auraId, kind: 1 the partner's keshin /
-- totem, 2 the base's own armour; 0, 0 none) as a second full-size retail aura header under the move row, filled as
-- the retail headers are: band by type + element, type icon, name, masked portrait (layer evt_ss_aura2)
PL.L_AURA2 = 2525671790
PL.AURA_FAMILY = {[0] = "fs", "fsa", "mixi", "soul", "kizuna", "power", "mode"}
PL.AURA_BANDS = {
  fs = {1716659057, 4284183243, 2287747677, 372824062, 1631577960},
  fsa = {1742805750, 4276636492, 2314173402, 395046521, 1619844847},
  mixi = {3558327990, 1293850380, 974759834, 2759668281, 3547988655},
  soul = {2619781135, 87024053, 1915277603, 3964421248, 2605413398},
  kizuna = {1514509020, 3276587878, 3024876528, 707749459, 1562924741},
  power = {4250578944, 1683218874, 324325676, 2368750735, 4197938201},
  mode = {3293713115, 1566262113, 710702071, 3023627860, 3275740866}}
PL.AURA_TYPE_ICON = {[0] = 1815339204 --[[icon_sp_area05]], 4114264446 --[[06]], 2185069032 --[[07]], 310549625 --[[08]],
  1703259375 --[[09]], 88220938 --[[10]], 1917130140 --[[11]]}
PL.AURA_FACE_TYPE = {[0] = 8, 8, 12, 14}          -- retail SwapLayerFaceIconTex type per aura type

function PL.MxAura2()
  local A2 = PL.L_AURA2
  local ok, aura, kind = pcall(funcLuaCommand, 1801942341, PL.mx_test_hdl or n)
  if not ok or type(aura) ~= "number" or aura == 0 or not funcLuaMenuCommand(262659071, A2) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, A2, 0, false)
    return
  end
  aura = EVT_U32(aura)
  PL.Open(A2)
  local _, t = funcLuaCommand(C.SKILL_INFO, aura, 13)
  local _, el = funcLuaCommand(C.SKILL_INFO, aura, 7)
  local fam = PL.AURA_BANDS[PL.AURA_FAMILY[t] or "fs"]
  local band = fam[el] or fam[1]
  PL.FaceReset(A2)
  PL.AuraClean(A2)
  funcLuaMenuCommand(C.SPRITE, A2, 2815298114 --[[team00_30 <LG>]], band, 1716659057 --[[fs_base01]], 0, 0)
  funcLuaMenuCommand(C.SPRITE, A2, 2320109963 --[[icon_common]], PL.AURA_TYPE_ICON[t] or PL.AURA_TYPE_ICON[0],
    4285917355 --[[icon_fs_area_dmy01]], 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A2, 1605611365, true, 0)
  local okn, nameId = funcLuaCommand(C.SKILL_INFO, aura, 4)
  funcLuaMenuCommand(C.TEXT, A2, 2915321899 --[[_text_fs01]], okn and (funcLuaCommand(720417636, nameId, 11) or "") or "", 0)
  funcLuaMenuCommand(2735666188, A2, 2915321899, true, 0)
  funcLuaMenuCommand(2158717427, A2, 622567014 --[[_pos_page03]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A2, 728354709, false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A2, 478320441 --[[_icon_chr_dmy01]], false, 0)
  local okc, cid = funcLuaCommand(C.SKILL_INFO, aura, 17)
  if okc and type(cid) == "number" and cid ~= 0 then
    funcLuaMenuCommand(C.MESH_VISIBLE, A2, 2449339029 --[[_icon_fs_dmy01]], true, 0)
    funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], A2, 0, 2449339029, 1051570875 --[[icon_fs_dmy01]], cid, 0,
      PL.AURA_FACE_TYPE[t] or 8, true, true, true, 5)
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, A2, 2449339029, false, 0)
  end
  -- 2026-10-07 round 2 (Nacho): not drawn with the miximax any more; R3 switches to it (PL.MxApplyView)
  PL.mx_aura = aura
  funcLuaMenuCommand(C.LAYER_VISIBLE, A2, 0, PL.mx_view == "aura")
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax aura", string.format("%08X", aura), "kind", tostring(kind),
    "type", tostring(t), "element", tostring(el), "portrait", tostring(cid))
end

function PL.MxDetail(f, team_info)
  local A = PL.MX_LAYER
  if not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], A) then
    return false
  end
  PL.DetailHideAll()
  PL.mx_f, PL.mx_ti, PL.mx_view = f, team_info, "mx"     -- every focus starts on the miximax view
  PL.Open(A)
  PL.Open(PL.L_HIPER)
  local el = PL.mx_elem[f.partner]
  if el == nil or el < 1 or el > 5 then
    local _, me = funcLuaCommand(C.SKILL_INFO, f.move, 7)
    el = (type(me) == "number" and me >= 1 and me <= 5) and me or 1
  end
  local bands = {3558327990, 1293850380, 974759834, 2759668281, 3547988655}   -- mixi_base01..05 (team00_30)
  funcLuaMenuCommand(C.SPRITE, A, 2815298114 --[[team00_30 <LG>]], bands[el], 1716659057 --[[fs_base01]], 0, 0)
  funcLuaMenuCommand(C.SPRITE, A, 2320109963 --[[icon_common]], 2185069032 --[[icon_sp_area07]], 4285917355 --[[icon_fs_area_dmy01]], 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 2449339029 --[[_icon_fs_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 1605611365, true, 0)
  PL.AuraClean(A)                                   -- "Hiperenergía", the red pill, the move-page band, page dots

  local pname = PL.MxCharaName(f.chara)
  -- 2026-10-12 (owner): the card's title is the move's name only («Miximax Trans»), never the player's
  funcLuaMenuCommand(C.TEXT, A, 2915321899 --[[_text_fs01]], EVT_Name(PL.MX_FUSION), 0)
  -- one gained move (rule 2026-09-25): its row + TENSIÓN, then the description (page 3)
  funcLuaMenuCommand(2158717427, A, 622567014 --[[_pos_page03]], true, 0)
  -- 2026-09-25 (user rule, hiper-match-slot.md §16.28 / §16.31): no text under a miximax (the gains live in the
  -- plate's Atributos L3 view) and no empty quote bar; that space holds the second aura header (PL.MxAura2)
  funcLuaMenuCommand(C.TEXT, A, 2956552560 --[[_text_flavor02]], "", 0)
  funcLuaMenuCommand(2735666188, A, 2956552560, false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 728354709, false, 0)
  -- the partner's icon through the retail mask (retail miximax rule: _icon_chr_dmy01, icon type 12)
  local face = f.face or f.chara
  if face ~= nil and face ~= 0 then
    pcall(PL.FaceReset, A)
    funcLuaMenuCommand(C.MESH_VISIBLE, A, 478320441 --[[_icon_chr_dmy01]], true, 0)
    -- retail UpdateMixiMaxDetailInfo: the type-12 face icon when it exists (2208175668), else the chara icon
    -- (552280324, the icon the bank / dock lists draw), both on _icon_chr_dmy01 under the retail band mask
    pcall(funcLuaCommand, 3148141229, "skill_panel", face)   -- the partner on purpose (module appearance)
    local has = funcLuaMenuCommand(2208175668, face)
    local r
    if has then
      r = funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], A, 0, 478320441, 3237726902 --[[icon_chr_dmy01]],
        face, 0, 12, true, true, true, 5)
    else
      pcall(SetDisableForceCharaInvalidUseTarget)
      r = funcLuaMenuCommand(552280324, A, 0, false, 478320441, 3237726902, 0, 0, face)
      pcall(SetEnableForceCharaInvalidUseTarget)
    end
    r = tostring(has) .. "/" .. tostring(r)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax portrait", "chara", tostring(f.chara), "face key", tostring(face),
      "param", string.format("%08X", f.partner or 0), tostring(r))
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, A, 478320441, false, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, A, 0, true)
  -- the gained move as an ATRIBUTOS row + its TENSIÓN, the type line "Miximax"
  local L = PL.L_HIPER
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  for _, p in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427, L, p, false, 0)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188, L, x, false, 0)
  end
  funcLuaMenuCommand(1233047821, L, 0, 2223127589, false)
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], f.best == true, 0)
  funcLuaMenuCommand(C.TEXT, L, 1899787537 --[[_text_area01]], f.best and "Best Match" or "", 0)
  funcLuaMenuCommand(2735666188, L, 1899787537, f.best == true, 0)
  PL.MoveRow(L, f.move, team_info, 0, false, f.phdl)   -- the partner owns the move: coloured, not greyed
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax move row", string.format("%08X", EVT_U32(f.move or 0)),
    "owner", tostring(f.phdl), "shown", tostring(funcLuaMenuCommand(1262717583, PL.L_HROW, 0)))
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HROW, 1, false)
  pcall(PL.MxAura2)
  pcall(PL.MxApplyView)                          -- the miximax view (PL.mx_view = "mx")
  -- (in game: a small red blob under the name) the power cube and the tag pills of both layers, off once more
  for _, m in ipairs({4122450641, 3516146179 --[[_area_base01]]}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, A, m, false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  evt_detail_on = true
  PL.hiper_wide = true
  pcall(EVT_DetailGraphSync)
  pcall(PL.SetDetailLayout, "mx")                -- 2026-10-07: as an aura; R3 shows the attached aura instead
  return true
end

-- 2026-10-07 round 2 (Nacho): the miximax panel shows ONE view: the miximax (its banner + the gained move's row) or,
-- after R3, the aura that comes with it (its banner on the same line + that aura's own move row, PEG look as the
-- Hiper panel). R3 again goes back; a focus change starts on the miximax (PL.MxDetail).
PL.K_R3 = 3147328756                             -- CMD_FUNC6 (R3; keyboard / mouse as mapped by the game)
PL.I_R3 = 2453951505                             -- its guide glyph (retail chara_edit / datafile guides)
PL.TX_VIEW_AURA = 3799245366                     -- menu_text evt_pl_mx_view_aura «Ver aura»
PL.TX_VIEW_MX = 1316386076                       -- menu_text evt_pl_mx_view_mx «Ver Miximax»
function PL.MxApplyView()
  local f, ti, L = PL.mx_f, PL.mx_ti, PL.L_HIPER
  if f == nil then
    return
  end
  local aura = PL.mx_view == "aura" and PL.mx_aura or nil
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.MX_LAYER, 0, aura == nil)
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_AURA2, 0, aura ~= nil)
  local best = aura == nil and f.best == true
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], best, 0)
  funcLuaMenuCommand(2735666188, L, 1899787537 --[[_text_area01]], best, 0)
  if aura == nil then
    PL.MoveRow(L, f.move, ti, 0, false, f.phdl)
  else
    local ok, move = EVT_HC.AuraMove(aura)
    PL.MoveRow(L, ok and move or 0, ti, 0, false, nil, EVT_HC.PegInfo(aura))
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HROW, 1, false)
  for _, m in ipairs({4122450641, 3516146179 --[[_area_base01]]}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  pcall(PL.SetDetailLayout, "mx")
end

-- guide entry «R3 Ver aura / Ver Miximax» while a miximax with an attached aura is focused (both row guides)
function PL.MxGuideAdd(t, i, c, o)
  if PL.layout_mode == "mx" and PL.mx_aura ~= nil then
    local k = #t + 1
    t[k], i[k], c[k], o[k] = PL.mx_view == "aura" and PL.TX_VIEW_MX or PL.TX_VIEW_AURA, PL.I_R3, PL.K_R3, 18
  end
end

function PL.MxPollR3()
  PL.r3_wait = math.max(0, (PL.r3_wait or 0) - 1)
  if PL.layout_mode ~= "mx" or PL.mx_aura == nil or PL.r3_wait > 0 or n14 == L_BTN then
    return
  end
  local hit = funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 1332654303 --[[MENU_CTRL]], PL.K_R3)
    or funcLuaCommand(4265778440, 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], PL.K_R3)
  if hit ~= true then
    return
  end
  PL.r3_wait = 10
  PL.mx_view = PL.mx_view == "aura" and "mx" or "aura"
  funcLuaCommand(C.SE, 1228648509 --[[sy0027, the retail detail page switch]])
  pcall(PL.MxApplyView)
  if PL.guide_redo ~= nil then
    pcall(PL.guide_redo)
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax view", PL.mx_view, string.format("%08X", EVT_U32(PL.mx_aura)))
end

PL.MxPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo()
  PL.MxPrevItemInfo()
  if not PL.MX_ON or n14 == L_BTN then
    return
  end
  local row = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
  if row ~= 0 then
    return
  end
  local okf, f = pcall(PL.MxGet)
  if okf and f ~= nil and EVT_Skill(0) == PL.MX_FUSION then
    local _, team_info = GetSoccerTeamInfo(0)
    local ok, shown = pcall(PL.MxDetail, f, team_info)
    if ok and shown then
      SetVisibleEquipInfoWindow(false)
    else
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "miximax panel", tostring(ok), tostring(shown))
    end
  end
end

-- The retail OnOpenLayer of soccer11_05_equip_status_base waits (waitTrue) for the layer before the 3D model is set.
-- When the screen resumes after the bank the engine calls it outside any coroutine (in-game 2026-09-25: LUAERR
-- "attempt to yield from outside a coroutine", the model not set up). There it now runs in its own coroutine,
-- resumed from Step until it ends; inside a coroutine nothing changes.
PL.deferred = {}
PL.MxPrevOpenLayer2 = OnOpenLayer
function OnOpenLayer(a1, a2)
  local _, main = coroutine.running()
  if a1 == 2917320188 --[[soccer11_05_equip_status_base]] and main then
    local co = coroutine.create(function() PL.MxPrevOpenLayer2(a1, a2) end)
    local ok, err = coroutine.resume(co)
    if not ok then
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "deferred open layer error", tostring(err))
    elseif coroutine.status(co) ~= "dead" then
      PL.deferred[#PL.deferred + 1] = co
    end
    return
  end
  return PL.MxPrevOpenLayer2(a1, a2)
end
PL.MxPrevStep = Step
function Step(...)
  local r = PL.MxPrevStep ~= nil and PL.MxPrevStep(...) or nil
  if PL.hiper_wide then
    -- 2026-10-04 (in game: the grey page base _sixth_base01 showed under a mode change card): kept hidden every frame
    -- while the full-width Hiper panel shows (the retail menu shows it again on its own refreshes)
    funcLuaMenuCommand(C.MESH_VISIBLE, 2917320188 --[[soccer11_05_equip_status_base]], 2682382918 --[[_sixth_base01]],
      false, 0)
  end
  for i = #PL.deferred, 1, -1 do
    local co = PL.deferred[i]
    local ok, err = coroutine.resume(co)
    if not ok then
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "deferred open layer error", tostring(err))
    end
    if not ok or coroutine.status(co) == "dead" then
      table.remove(PL.deferred, i)
    end
  end
  return r
end

-- ===== Miximax END =====

-- ===================================================================================================
-- «Modo cambio» (2026-10-04, Nacho; docs/game/mechanics/mode-change.md §3): a mode change is a HIPER. The Hiper
-- picker has a «Modo cambio» tab (category 106, module skill_tabs; rows drawn by the pick block of ss2_pick_1):
-- «Crear nuevo cambio» (item wmc_evt_create) and the player's created changes (items wmc_evt0..7 = change 1..8,
-- «Modo cambio: <partner>»). «Crear nuevo cambio» = pick ANY character (one owned card per character, the miximax
-- list window), the change is saved (loader CMND_EVT_MC_ADD, per save slot) and its carrier wmc_evt<k> becomes this
-- player's Hiper through the normal equip path; picking an existing change equips its carrier. In a match RB+A swaps
-- him to that character's look (only the look). Eliminar on the Hiper row with a change: the Hiper is emptied and
-- «¿Borrar también el cambio?» deletes it. Everything lives in PL (no new main-chunk locals).
-- ===================================================================================================
PL.MC_ON = true
PL.MC_CMD = {ON = 1689747210, ITEMS = 2121540544, CANDIDATES = 2117900510, ADD = 3010720229, LIST = 2447822974,
  ITEM = 3392474488, EQUIP = 1830357309, DELETE = 2464860440}
PL.MC_ERR = {[1] = "El modo cambio está desactivado (vr-loader).", [3] = "No se encuentra la carta base.",
  [4] = "Ese jugador no se puede usar como cambio.", [5] = "Un jugador no puede cambiar a sí mismo.",
  [6] = "Este jugador ya tiene 8 cambios: quita uno antes (Eliminar en la fila de la hipertécnica).",
  [7] = "No se pudo guardar el cambio.",
  [21] = "Elige un jugador de tu banco.", [22] = "No se encuentran los datos de ese jugador.",
  [23] = "Un jugador no puede cambiar a sí mismo.", [24] = "Ese jugador tiene una aura asignada: quítala antes.",
  [25] = "Ese jugador ya está reservado como aura.", [26] = "Ese jugador está en un equipo: muévelo al banco primero."}
PL.MC_KEY_N = 1284887561                          -- evt_mc_n: number of changes of the player (pick block)
PL.MC_KEY_C = {954567708, 1340259466, 3605785904, 2716655014, 1065895941, 1217362067, 3515230505, 2793478591}
PL.MC_CREATE = 3567812479                         -- wmc_evt_create «Crear nuevo cambio»
PL.MC_CAR = {754700454, 1543299120, 3270881674, 3052568860, 731255999, 1553015849, 3315103123, 2996782341}

function PL.McLive()
  if PL.mc_live == nil then
    local ok, on = pcall(funcLuaCommand, PL.MC_CMD.ON)
    PL.mc_live = ok and on == true
  end
  return PL.MC_ON and PL.mc_live
end

-- index 0..7 of a carrier id, nil = not one
function PL.McIndex(skill)
  for k = 1, #PL.MC_CAR do
    if PL.MC_CAR[k] == skill then
      return k - 1
    end
  end
  return nil
end

-- the player's changes: list of {hdl, param, chara, idx}
function PL.McList()
  local out = {}
  local ok, cnt = pcall(funcLuaCommand, PL.MC_CMD.LIST, n)
  if not ok or type(cnt) ~= "number" then
    return out
  end
  for i = 0, cnt - 1 do
    local ok2, ex, h, p, ch = pcall(funcLuaCommand, PL.MC_CMD.ITEM, n, i)
    if ok2 and ex then
      out[#out + 1] = {hdl = h, param = EVT_U32(p or 0), chara = ch or 0, idx = i}
    end
  end
  return out
end

-- candidates: one owned card per character (never the player's own), {hdl, param, chara, element, pos, name}
function PL.McCandidates()
  local out = {}
  local start = 0
  while true do
    local r = {pcall(funcLuaCommand, PL.MC_CMD.CANDIDATES, n, start, 2)}
    if not r[1] or type(r[2]) ~= "number" or type(r[3]) ~= "number" then
      break
    end
    local total, cnt = r[2], r[3]
    for k = 0, cnt - 1 do
      local o = 4 + k * 6
      out[#out + 1] = {hdl = r[o], param = EVT_U32(r[o + 1] or 0), chara = r[o + 2], element = r[o + 3],
        pos = r[o + 4], allowed = true}
    end
    start = start + cnt
    if cnt <= 0 or start >= total then
      break
    end
  end
  for _, e in ipairs(out) do
    e.name = PL.MxCharaName(e.chara)
    local pt = PL.MX_POS[e.pos]
    e.name = pt ~= nil and (e.name .. "  ·  " .. pt) or e.name
  end
  return out
end

-- before the Hiper picker opens: «Crear nuevo cambio» owned (the native list only lists owned items), one copy of
-- every carrier of this player's changes, and the pick block's data (count + partner chara per change)
function PL.McPrepare()
  funcLuaCommand(C.P_CLEAR, PL.MC_KEY_N)
  for _, k in ipairs(PL.MC_KEY_C) do
    funcLuaCommand(C.P_CLEAR, k)
  end
  if not PL.McLive() or n == nil or n == 0 then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "mode change picker", "off", "live", tostring(PL.McLive()), "hdl",
      tostring(n))
    return
  end
  local have = funcLuaCommand(PL.ITEM_NUM, PL.MC_CREATE)
  if type(have) ~= "number" or have <= 0 then
    funcLuaCommand(PL.ADD_ITEM, PL.MC_CREATE, 1, false)
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "mode change picker", "create owned", tostring(have), "->",
    tostring(funcLuaCommand(PL.ITEM_NUM, PL.MC_CREATE)))
  P_Set(PL.MC_KEY_N, 0) -- direct assignment; carriers never appear as saved presets
end

-- change idx (0-based) becomes this player's Hiper: the store's equipped one + its carrier through the equip path
-- (one more copy first: every Hiper slot holds its own copy)
function PL.McEquip(idx, cur)
  local id = PL.MC_CAR[idx + 1]
  if id == nil then
    return false
  end
  pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, idx)
  funcLuaCommand(PL.ADD_ITEM, id, 1, false)
  local ok, err = pcall(PL.McPrevEquip, 0, id, id, cur)
  local now = EVT_U32(EVT_Skill(0))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "mode change equip", string.format("%08X", EVT_U32(n or 0)), idx,
    tostring(ok), tostring(err), "hiper now", string.format("%08X", now))
  return ok and now == id
end

-- the partner in the retail bank, as «Crear miximax» (graft mx_bank in its «Modo cambio» mode, key evt_mx_bank_mc:
-- no move step, the confirmation there): the entry, false = cancelled, nil = the bank is not available
PL.MC_BANK_KEY = 2585187148                       -- param store evt_mx_bank_mc (read and cleared by the bank graft)
function PL.McBankPick()
  if not PL.MX_BANK or PL.MxStub() or n == nil or n == 0 then
    return nil
  end
  P_Set(PL.MC_BANK_KEY, 1)
  local seen, h = PL.BankRun("mode change bank")
  funcLuaCommand(C.P_CLEAR, PL.MC_BANK_KEY)
  PL.mx_bank_move = 0
  if not seen then
    return nil
  end
  if h == 0 then
    return false
  end
  return {hdl = h, param = PL.MxParam(h), chara = funcLuaCommand(1131797651, h, 1)}
end

function PL.McCreate(cur)
  local e = PL.McBankPick()
  if e == false then
    return
  end
  local pname
  if e ~= nil then
    pname = PL.MxCharaName(e.chara)              -- confirmed in the bank
  else
    local cands = PL.McCandidates()              -- the old list (no bank)
    if #cands == 0 then
      funcLuaCommand(C.SE, SE_NG)
      EVT_Message("No hay jugadores para el modo cambio.")
      return
    end
    local pick = PL.MxList(cands, 0, {row = PL.MxRowChara,
      guide = "Modo cambio: elige el personaje cuyo aspecto tomará. Aceptar = elegir, atrás = volver."})
    if pick < 0 then
      return
    end
    e = cands[pick + 1]
    pname = PL.MxCharaName(e.chara)
    if not PL.MxAsk(string.format("¿Crear el cambio a %s? Solo cambia el aspecto: estadísticas, técnicas y objetos siguen siendo los suyos.", pname)) then
      funcLuaCommand(C.SE, SE_BACK)
      return
    end
  end
  local ok, done, code, idx = pcall(funcLuaCommand, PL.MC_CMD.ADD, n, e.hdl)
  local st = ok and (done and 0 or (code or 7)) or 7
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "mode change add", string.format("%08X", EVT_U32(n or 0)),
    string.format("%08X", EVT_U32(e.hdl or 0)), "code", st, "index", tostring(idx))
  if st ~= 0 or type(idx) ~= "number" or idx < 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.MC_ERR[st] or ("Error " .. tostring(st)))
    return
  end
  if PL.McEquip(idx, cur) then
    funcLuaCommand(C.SE, SE_DECIDE)
    EVT_Message(string.format("Modo cambio a %s asignado como hipertécnica.", pname))
  else
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message("El cambio se guardó pero no se pudo poner como hipertécnica.")
  end
end

-- the picker's result: «Crear nuevo cambio» runs the flow, a change entry equips it (store + carrier)
PL.McPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if PL.MC_ON and row == 0 and skill == PL.MC_CREATE then
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
    PL.McCreate(cur)
    return
  end
  local k = PL.MC_ON and row == 0 and PL.McIndex(skill) or nil
  if k ~= nil then
    pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, k)
    funcLuaCommand(PL.ADD_ITEM, skill, 1, false)    -- this slot's own copy
  end
  return PL.McPrevEquip(row, skill, inv_hint, cur)
end

PL.McPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  if row == 0 and PL.MC_ON then
    pcall(PL.McPrepare)
  end
  return PL.McPrevPick(row)
end

-- Eliminar on the Hiper row holding a change: emptied (native path), then «¿Borrar también el cambio?»
PL.McPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  local k = (PL.MC_ON and row == 0) and PL.McIndex(EVT_U32(EVT_Skill(0))) or nil
  local chara = 0
  if k ~= nil then
    for _, c in ipairs(PL.McList()) do
      if c.idx == k then
        chara = c.chara
      end
    end
  end
  PL.McPrevRestore(row)
  if k ~= nil and chara ~= 0 then
    local pname = PL.MxCharaName(chara)
    if PL.MxAsk(string.format("¿Borrar también el cambio a %s?", pname)) then
      pcall(funcLuaCommand, PL.MC_CMD.DELETE, n, k)
      funcLuaCommand(C.SE, SE_REMOVE)
    else
      pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, -1)
      funcLuaCommand(C.SE, SE_BACK)
    end
    EVT_RefreshRows()
    UpdateEquipItemInfo()
  end
end

-- the Hiper row with a change: «Modo cambio: <partner>»
PL.McPrevRow = UpdateEquipListItem
function UpdateEquipListItem(a1)
  PL.McPrevRow(a1)
  if a1 ~= 0 or not PL.MC_ON then
    return
  end
  local k = PL.McIndex(EVT_U32(EVT_Skill(0)))
  if k == nil then
    return
  end
  for _, c in ipairs(PL.McList()) do
    if c.idx == k then
      local info = GetEquipListItemInfo(GetEquipType(0))
      local okn, nameId = funcLuaCommand(C.SKILL_INFO, PL.MC_CAR[k + 1], 4)
      local base = (okn and nameId) and (funcLuaCommand(720417636, nameId) or "Modo cambio") or "Modo cambio"
      local text = base .. ": " .. PL.MxCharaName(c.chara)
      if EVT_SPECIAL_LABEL ~= "" then
        text = EVT_SPECIAL_LABEL .. "   " .. text
      end
      funcLuaMenuCommand(C.TEXT, L_ROW, info.itemTextName, text, 0)
    end
  end
end

-- ===== Modo cambio END =====

-- ===== X «Restablecer» / Y «Eliminar» (2026-10-06) =====
-- User: Y ALWAYS deletes (EVT_RestoreCoroutine above: the slot ends empty, never the default). X restores the focused
-- row from the player's basic kit: first the slot's own native board move (what the old «Eliminar» brought back:
-- CMND_EVT_BOARD_CLEAR keepOpen 1 takes the placed item off), else his learnset move for that slot (chara_param
-- slots 1-6, the Hiper row slot 9; the source of the native moves, needed after a Y took the native off) once his
-- level reached it; nothing in the kit = the slot ends EMPTY. Button guide on the rows: Aceptar, X «Restablecer»
-- (retail menu_text 108624977, the settings screens' CMD_FUNC4 Reset), Y «Eliminar» (retail 3961481199) when the row
-- has a move. CMD_FUNC4 reaches OnFunction as 1141890006 (the retail eye-check toggle, unused on this screen).

-- learnset move of `row` (Hiper row: a special, rows 1-6: a normal move) when the player's level reached it, else 0
function PL.KitMove(row)
  local ls = PL.Learnset()
  local slot = PL.RowSlot(row)
  local m = ls.skill[slot] or 0
  if m == 0 or EVT_IsSpecial(m) ~= (row == 0) then
    return 0
  end
  local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  if (ls.lv[slot] or 0) > lv then
    return 0
  end
  return m
end

-- the rows' guide: Aceptar, V / Y «Restablecer» (held: Eliminar, the retail long-press ring fills over its glyph,
-- PL.TapOrHold; 2026-10-14, owner: as Inazuma Fantasy had it), then the declared row actions (PL.MxGuideAdd chain:
-- R3, the mix-only Eliminar, graft skill_table_host's row / X actions)
function PL.RowGuide(removable)
  local t = {1847312674 --[[Aceptar]], PL.TX.BTN_RESET}
  local i = {PL.I_ENTER, PL.I_FUNC3}
  local c = {PL.K_ENTER, PL.K_FUNC3}
  local o = {0, 18}
  pcall(PL.MxGuideAdd, t, i, c, o)
  funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], t, i, o)
  funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], c)
end

-- the move of the slot's NATIVE board item (CMND_EVT_BOARD_PIECE -> piece, effectiveInv, overwriteInv, baseInv), 0 = none.
-- Read before anything is cleared: a Y on the Hiper row (miximax / mode change) drops the native item.
function PL.NativeMove(bslot)
  local p, eff, over, base = EVT_Call(C.EVT_PIECE, n, bslot)
  if type(p) ~= "number" or p < 0 or p >= 255 or base == nil or base == 0 then
    return 0
  end
  return EVT_U32(funcLuaCommand(C.INV_ITEM, base, 0) or 0)
end

-- the basic-kit move of `row`: the slot's native board move, else the learnset move (PL.KitMove); never a miximax
-- fusion / mode-change carrier / Crear entry on the Hiper row, never an aura on rows 1-6
function PL.ResetKit(row)
  local m = PL.NativeMove(EVT_BoardSlot(row))
  local special = EVT_IsSpecial(m)
  if row == 0 then
    if not special or m == PL.MX_FUSION or m == PL.MX_CREATE or m == PL.MC_CREATE
      or (PL.McIndex ~= nil and PL.McIndex(m) ~= nil) then
      m = 0
    end
  elseif special then
    m = 0
  end
  if m == 0 then
    m = PL.KitMove(row)
  end
  return m
end

-- Restablecer before the Fantasy slot fallbacks wrap it (EVT_ResetCoroutine below)
function PL.BaseResetCoroutine(row)
  if EVT_IsPrime() then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local before = EVT_Snapshot()
  local old = EVT_Skill(row)
  local bslot = EVT_BoardSlot(row)
  local want = PL.ResetKit(row)
  if row == 0 and old ~= 0 and old ~= want then
    -- a miximax fusion / a mode change (carrier wmc_evt*) on the Hiper row goes first through Y with its own
    -- questions (fusion: «¿Quitar el miximax…?», No = nothing changes; change: the slot is emptied, then
    -- «¿Borrar también el cambio?»); the default Hiper is put back afterwards
    local mx = PL.MX_ON and old == PL.MX_FUSION
    local mc = PL.MC_ON and PL.McIndex ~= nil and PL.McIndex(EVT_U32(old)) ~= nil
    if mx or mc then
      EVT_RestoreCoroutine(0)
      if EVT_Skill(0) ~= 0 then
        return
      end
    end
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  local r
  if row == 0 then
    if want == 0 then
      r = EVT_Call(C.EVT_CLEAR, n, bslot, 3 --[[keepOpen 3: everything off]])
      EVT_TeamAuraPut(0)
    else
      r = EVT_BoardClear(bslot, true)              -- placed item off: the native Hiper (if still there) is back
      if EVT_BoardSkill(bslot) == want then
        EVT_TeamAuraPut(want)
      else
        EVT_Equip(0, want)                         -- board slot 8 + the team aura slot
      end
    end
  else
    r = EVT_BoardClear(bslot, true)                -- placed item off: the native move (if any) is back
    if EVT_IsSpecial(EVT_BoardSkill(bslot)) then   -- an aura native item (old save) never returns to a row
      r = EVT_Call(C.EVT_CLEAR, n, bslot, PL.AURA_CLEAR_NATIVE)
    end
    local pos = EVT_ListPos(row)
    if want ~= 0 then
      EVT_Equip(row, want)                         -- match list (swaps if the move sat on another row) + board
    elseif EVT_ListSkill(pos) ~= 0 then
      funcLuaCommand(C.REMOVE_SKILL, n, pos)       -- empty kit slot: the row ends empty
    end
  end
  local now = EVT_Skill(row)
  funcLuaCommand(C.SE, now ~= old and SE_DECIDE or SE_NG)   -- already the kit move: error sound only
  EVT_Report(string.format("Restablecer fila %d: %s -> %s (kit %s, estado %s).\n%s", row, EVT_Name(old), EVT_Name(now),
    EVT_Name(want), tostring(r), EVT_Diff(before, EVT_Snapshot())), row)
  EVT_AfterChange()
  EVT_FocusRow(row)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end
-- ===== X «Restablecer» / Y «Eliminar» END =====

-- ===== compact detail layout (2026-10-07) =====
-- PL.ApplyDetailLayout again for PL.LAYOUT_FRAMES frames after each state change: a layer opened after the focus
-- change (L_DETAIL_LV, the aura windows, evt_ss_aura2 of a miximax) or an open animation that reset a node gets the
-- compact positions too; then it stops (nothing runs per frame while the screen closes)
PL.LayoutPrevStep = Step
function Step(...)
  local r = PL.LayoutPrevStep ~= nil and PL.LayoutPrevStep(...) or nil
  pcall(PL.MxPollR3)
  if PL.layout_mode ~= nil and (PL.layout_frames or 0) > 0 then
    PL.layout_frames = PL.layout_frames - 1
    pcall(PL.ApplyDetailLayout)
  end
  return r
end
-- ===== compact detail layout END =====

-- ===================================================================================================
-- Two Hiper slots (owner redesign 2026-10-12; docs/game/hiper/hiper-two-slots.md). The Hiper row holds BOTH slots of
-- the player: the AURA slot (a keshin or a totem: board slot 8 + the team aura row, as before) and the MIX slot (a
-- Mix-Max or a «Modo cambio»: Inazuma Fantasy's save blob hiper_slots.json through CMND_FANTASY_HIPER_MIX_*). The row
-- reads «<aura>   /   <mix>»; the Hiper picker files the chosen move into its own slot (CMND_FANTASY_HIPER_SLOT_OF:
-- keshin / totem -> aura, Mix-Max / mode change -> mix, an armour alone is refused: it comes from its keshin in the
-- match). R3 switches the panel between the two slots; Y «Eliminar» asks which slot when both are filled. No chain:
-- a Mix-Max no longer brings the partner's keshin (the panel's «Ver aura» view of it is gone). A single-slot leftover
-- on board slot 8 (a Mix-Max / change carrier, an armour alone) is fixed once per shown player. Everything in PL (no
-- new main-chunk locals, one assignment per line at main level).
-- ===================================================================================================
PL.HS_ON = true
-- 2026-10-14: the mix slot store is Character Reforged's (scripts\mix_slots.lua, imported once from IF's blob)
PL.HS_CMD = {SLOT_OF = 1826049290 --[[CMND_CHARACTERREFORGED_SLOT_OF]], MIX_GET = 358194355 --[[CMND_CHARACTERREFORGED_MIX_GET]],
  MIX_SET = 242652959 --[[CMND_CHARACTERREFORGED_MIX_SET]]}
PL.HS_TX = {ARMOUR = 2889673449 --[[evt_hs_armour_alone]], VIEW_MIX = 2226997538 --[[evt_hs_view_mix]],
  MIX_FAIL = 1970703341 --[[evt_hs_mix_fail]],
  MX_ASSIGNED = 1026818207 --[[evt_hs_mx_assigned]], ASK_MX = 3109185653 --[[evt_hs_ask_mx]],
  ASK_MC_DELETE = 2595117433 --[[evt_hs_ask_mc_delete]]}
PL.hs_view = "aura"
PL.hs_fixed = {}
-- 2026-10-12 (owner): the Hiper row is split in two PLATES side by side, the SAME plate twice (the row's retail plate
-- sprite item_list_base01, same shape, size and style) tinted per half: left = the AURA slot, PURPLE; right = the MIX
-- slot (a Mix-Max OR a «Modo cambio»), ORANGE. Left = the row's own base _item_list_base01, right = the row's spare
-- title base _title_list_base01 given the same sprite; both scaled to half the row, the right one moved right; the tint
-- is the mesh colour (CMND_SET_PRIM_COLOR, a multiply: the retail white plate takes any colour; IF's purple sprite
-- could not turn orange). Round 3: no retail Mix-Max band any more (owner: the same plate, orange). Each half shows its move's name (white,
-- outlined) and icon, or «---». Left / Right on the row select the half (the selected name full white with «»», the
-- other dimmed); the panel, R3 and Y (hold) act on the selected half. Round 2 (in game 15:57: the generated split
-- texture's recipe failed - its source sprite has no name in IF's atlas - the row was transparent): no generated
-- texture any more, two real plates from loaded sprites.
-- Round 5 (in game, shots 167-169): the mesh tint never reached the plates (both halves white), the aura icon sat on
-- the boundary of the halves. The plates are now PRE-TINTED sprites of IF's atlas evt_hs_plates (made at boot by the
-- image type from the retail item_list_base01: content\images\menu\00_soccer\soccer11\evt_hs_plates.toml), loaded
-- once (the retail white plate until it is in), and each half's icon sits at the left end of its own plate, its name
-- after it (a few spaces, as the text node itself does not move). The picker opened from a half shows only that
-- half's tabs (the skill tab registry's window: keshin / totem or Mix-Max / «Modo cambio»), from a move row only the move
-- categories (PL.HsPrevPick wrapper below).
-- Round 6 (in game, shots 227-230): (1) the aura half showed the MIX move's icon and the mix half the retail star: the
-- item-icon command's 4th argument is the texture SLOT of the layer instance, not the mesh, and both halves wrote
-- slot icon_item_dmy01 (the mix one last), while _icon_title01 draws slot icon_title01 (the star sprite); the mix icon
-- now goes to slot icon_title01 (as pset_preview's medal). (2) The halves looked unequal: the mix plate was 76 tall
-- (title base) vs 80, 2 units higher; the aura icon stuck 10 units out of its plate; ONE retail focus frame (572) ran
-- round both plates and the mix plate stuck out of it. Now both plates 282 x 80 on the same line, both icons 5 units
-- inside their plate, and the focus frame is per half: _item_list_focus01 (left) or _item_list_focus02 (right, given
-- the plain frame sprite) at half width, only on the selected half; the retail Focus animation still fades it in/out.
-- (3) No «» » mark, no dimmed name: the frame shows the selected half. (4) The text boxes (node scale = box size; the
-- sclw style squeezes a longer name into it) end inside their plate: «Miximax Trans» no longer runs past the edge.
-- (5) Left / Right: read on the press edge (no 10-frame lock) from MENU_CTRL, the analog controller, the separate
-- cross-key controller and, while the list has the control focus, the pad / arrow keys themselves (CMND_VRFW_INPUT_PAD
-- / _KEY): only the controller the game has selected delivers commands (contact-map doc), so a press could get lost
-- after another screen changed it. The input controller is never switched here. Leaving the row puts the aura half back.
PL.hs_half = 0
PL.HS_ROW = {BASE1 = 970690259 --[[_item_list_base01]], BASE2 = 2583835390 --[[_title_list_base01]],
  POS2 = 3571920478 --[[_pos_list02]], FOCUS2 = 2420990283 --[[_item_list_focus02]],
  TEXT1 = 456522680 --[[_text_item01]], TEXT2 = 2185013762 --[[_text_item02]], ICON1 = 303536660 --[[_icon_item_dmy01]],
  ICON2 = 4025646555 --[[_icon_title01]], TRANSLATE = 2575768773 --[[node translation (layer, idx, node, axis, value)]],
  SCALE = 2885415772 --[[node scale (layer, idx, node, sx, sy)]],
  SLOT2 = 1453818910 --[[title_list_base01 (the mesh's sprite slot)]],
  STYLE = 516729530 --[[fs_32_w_lc_2d2_001_nr_sclw: white, outlined, squeezed to its box]],
  -- round 4 (in game 17:10: both plates gone, the «---» over the aura name): a quad's node scale IS its size in layout
  -- units (unit quads, as the HUD's cooldown bar: hiper_btn), so scale 0.5 made the plates 0.5 units wide; and moving
  -- the title text node did not move its text. Now the plates get their half SIZE, and the whole spare title set is
  -- moved by its locator _pos_list02 (+SHIFT2: base, text and icon together; a locator move works, the training bar),
  -- its icon brought back inside the row. Sizes: the retail sprites item_list_base01 568 x 80, title_list_base01 568 x 76.
  BASE1_SIZE = {568, 80}, BASE2_SIZE = {568, 76}, HALF_W = 282, SHIFT2 = 288,
  -- round 5: the icons at the left end of their half (layout units of the icon nodes; the mix icon's locator is
  -- moved +SHIFT2 with its set), the names after them (PAD1 / PAD2 spaces), cut to fit the half
  -- round 6: both icons 5 units inside their plate (plates -283..-1 and 5..287), both plates 80 tall at y 36, the
  -- text boxes ending 8 units before their plate's right edge, the focus frame per half (retail 572 x 88 at -286)
  -- round 8 (owner 2026-10-13: the icons a bit further left and smaller, centred on the plate, the same on both):
  -- icon nodes are left / top anchored (the layout's x = left edge, y = top edge, y up), size = node scale: 54 units
  -- (84 % of the retail 64) at x = plate left + 2, its top at plate centre (BASE1_Y - 40 = -4) + 27
  AURA_ICON_X = -281, ICON1_X = 203, MIX_ICON_X = -281, BASE1_Y = 36, BASE2_Y = 38,
  ICON_SIZE = 54, ICON_Y = 23, ICON_RETAIL_SIZE = 64, ICON_RETAIL_Y = 28,
  -- the aura half's short name on this menu: menu_text row evt_hs_totem_short = "|"-separated name formats of a
  -- totem in the language (<VALUE> = the totem's own name), e.g. "Totem <VALUE>" / "<VALUE> Totem"
  TOTEM_SHORT = 2237215146 --[[crc32(evt_hs_totem_short)]],
  PAD1 = "", PAD2 = "", CUT = 14,
  -- 2026-10-14 (owner: «no deberían aparecer esos iconos cuadrados, deberían aparecer el portrait del aura o
  -- jugador»): no move icon on the plates any more. Each plate shows a PORTRAIT at its right end, over the darker
  -- slanted corner: the aura's character (keshin / totem, SKILL_INFO 17) on the aura plate, the partner (fusion,
  -- retail Mix-Max) or the other form («Modo cambio») on the mix plate; an empty slot shows none. The portrait is the
  -- character's list face icon (552280324, as the bank / dock lists and the retail item cards draw it) on the
  -- row's own icon quads (_icon_item_dmy01 / _icon_title01), so no layer is added. The names start where the icons
  -- were: a text node does not move by itself (round 4), so each plate set is moved left by its locator
  -- (_pos_list01 / _pos_list02) and its plate, focus frame and portrait moved back right by the same amount.
  POS1 = 1307475940 --[[_pos_list01]], TEXT_SHIFT1 = 57, TEXT_SHIFT2 = 38,
  BASE_X = -283, FOCUS_X = -286,
  -- portrait: inside the painted part of the plate sprite (item_list_base01 568 x 80: opaque rows 9..62, columns
  -- 11..554, i.e. 54 of the plate's 80 units tall, centred, and 7 units in from its right end), so nothing sticks out
  -- above or below. A quad cannot be clipped (no UV command; the menu scissor clips whole layer instances), so the
  -- portrait is sized to the band: 54 units square, top at plate centre + 27, 2 units inside the painted right end
  -- (world -10 aura, 278 mix; the sets are shifted by -TEXT_SHIFT1 / SHIFT2 - TEXT_SHIFT2)
  FACE_SIZE = 54, FACE_Y = 27, AURA_FACE_X = -7, MIX_FACE_X = -26,
  TEXT1_SPLIT_W = 188, TEXT2_SPLIT_W = 188,
  RESET_FACE = 4176779611 --[[ResetFaceIcon (layer, idx, texture slot)]],
  ICON_SLOT1 = 1875672568 --[[icon_item_dmy01]], ICON_SLOT2 = 3047759730 --[[icon_title01 (the slot _icon_title01 draws)]],
  TEXT1_BOX = {410, 54}, TEXT2_BOX = {408, 54}, TEXT1_W = 205, TEXT2_W = 224,
  FOCUS1 = 155463921 --[[_item_list_focus01]], FOCUS_SIZE = {572, 88}, FOCUS_HALF_W = 286,
  FOCUS_SPRITE = 3319891473 --[[item_list_focus01: the plain frame]], FOCUS2_SLOT = 1558763435 --[[item_list_focus02]],
  CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]],
    3526778166 --[[MENU_CTRL_SEPARATE_CROSS_KEY]]},
  PAD = 2864033604 --[[CMND_VRFW_INPUT_PAD]], VKEY = 3182184968 --[[CMND_VRFW_INPUT_KEY]],
  PAD_LEFT = 0x80, PAD_RIGHT = 0x20, VK_LEFT = 0x25, VK_RIGHT = 0x27,
  CTRL_FOCUS = 102308320 --[[CMND_IS_CTRL_FOCUS_ACTIVE (layer)]],
  -- round 7 (owner: the mouse never selected the orange half): the row's native touch quad _touch_list01 (retail
  -- 544 x 54 at (-272, 27), it ended inside the mix plate) covers both plates (570 x 80 at (-283, 36)), and the pointer
  -- over a plate (local x -283..-1 aura, 5..287 mix, y -44..36, y up) selects that half as Left / Right do
  TOUCH = 688754292 --[[_touch_list01]], TOUCH_RETAIL = {544, 54, -272, 27}, TOUCH_SPLIT = {570, 80, -283, 36},
  PTR_POS = 558229292 --[[pointer (screen px, y down)]], PTR_GPOS = 4002164178 --[[instance global position, y up]],
  PTR_MOVED = 3272825600 --[[mouse moved]], PTR_CLICK = {218912913 --[[CMD_EVT_MOUSE_LEFT]],
    1651523701 --[[CMD_ENTER_CLICK]]},
  HIT_X = {{-283, -1}, {5, 287}}, HIT_Y = {-44, 36},
  PLATE_TEX = "#/menu/00_soccer/soccer11/evt_soccer11_08_hs/evt_hs_plates.g4tx",
  PLATE_TEX_CRC = 4050240674 --[[crc32(PLATE_TEX)]], PLATE_AURA = 2408592914 --[[evt_hs_plate_aura]],
  PLATE_MIX = 4118466748 --[[evt_hs_plate_mix]],
  K_LEFT = 2765147006 --[[CMD_LEFT]], K_RIGHT = 2075023265 --[[CMD_RIGHT]]}

-- one row again (a level-locked Hiper row, never split): sizes, positions, the spare set, the focus frame and the text
-- style back
function PL.HsUnsplitRow()
  local R, L = PL.HS_ROW, L_ROW
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE1, R.BASE1_SIZE[1], R.BASE1_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS1, R.FOCUS_SIZE[1], R.FOCUS_SIZE[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.FOCUS1, true, 0)
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT1, R.TEXT1_BOX[1], R.TEXT1_BOX[2])
  funcLuaMenuCommand(C.TEXT_ALPHA, L, 0, R.TEXT1, 1)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS2, 0, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 1, R.BASE2_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE2, R.BASE2_SIZE[1], R.BASE2_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS2, R.FOCUS_SIZE[1], R.FOCUS_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT2, R.TEXT2_BOX[1], R.TEXT2_BOX[2])
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, R.POS2, false, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON1, 0, R.ICON1_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON1, 1, R.ICON_RETAIL_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, R.ICON1, R.ICON_RETAIL_SIZE, R.ICON_RETAIL_SIZE)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS1, 0, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE1, 0, R.BASE_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS1, 0, R.FOCUS_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 0, R.BASE_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS2, 0, R.FOCUS_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON2, 0, R.ICON1_X)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.ICON2, 1, R.ICON_RETAIL_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, R.ICON2, R.ICON_RETAIL_SIZE, R.ICON_RETAIL_SIZE)
  if PL.hs_faces then
    -- the portraits leave the icon slots: the row's own move icon again
    PL.hs_faces = false
    PL.hs_face_key = {}
    funcLuaMenuCommand(R.RESET_FACE, L, 0, R.ICON_SLOT1)
    funcLuaMenuCommand(R.RESET_FACE, L, 0, R.ICON_SLOT2)
    local skill = PL.RowMove(0)
    if skill ~= 0 then
      funcLuaMenuCommand(C.ITEM_ICON, L, 0, R.ICON1, R.ICON_SLOT1, skill)
    end
  end
  PL.HsTouch(R.TOUCH_RETAIL)
  local info = GetEquipListItemInfo(GetEquipType(0))
  if info ~= nil and info.fontStyle ~= nil then
    funcLuaMenuCommand(2333948100 --[[text style]], L, 0, R.TEXT1, info.fontStyle)
  end
end

-- the aura half's name without the totem's wording ("Tótem águila calva" -> "Águila calva"; "Bald Eagle Totem" ->
-- "Bald Eagle"): the menu_text row evt_hs_totem_short lists the language's totem name formats; any other name stays
function PL.HsFirstUpper(t)
  local b1, b2 = string.byte(t, 1, 2)
  if b1 ~= nil and b1 >= 97 and b1 <= 122 then
    return string.char(b1 - 32) .. string.sub(t, 2)
  end
  if b1 == 195 and b2 ~= nil and b2 >= 160 and b2 <= 190 and b2 ~= 183 then
    return string.char(195, b2 - 32) .. string.sub(t, 3)
  end
  return t
end

function PL.HsShortName(name)
  if type(name) ~= "string" or name == "" then
    return name
  end
  local fmts = PL.Txt(PL.HS_ROW.TOTEM_SHORT)
  for fmt in string.gmatch(fmts, "[^|]+") do
    local i, j = string.find(fmt, "<VALUE>", 1, true)
    if i ~= nil then
      local pre, post = string.sub(fmt, 1, i - 1), string.sub(fmt, j + 1)
      local n_name = #name
      if n_name > #pre + #post and string.sub(name, 1, #pre) == pre
          and (#post == 0 or string.sub(name, n_name - #post + 1) == post) then
        return PL.HsFirstUpper(string.sub(name, #pre + 1, n_name - #post))
      end
    end
  end
  return name
end

-- the split Hiper row (instance 0): both plates the same size in every state (focused or not, filled or empty), each
-- half's own icon and name, the focus frame on the selected half only
function PL.HsSplitRow()
  local R, L = PL.HS_ROW, L_ROW
  local aura, mix = PL.CrShownSlots()
  local mix_partner = mix ~= 0 and PL.HsMixPartner(mix) or nil
  local function label(id, half)
    if id == 0 then
      return ""                                    -- an empty slot: the plate alone (owner: no «---»)
    end
    local t = half == 1 and PL.HsMixName(id, mix_partner) or PL.HsShortName(EVT_Name(id))
    return (half == 1 and R.PAD2 or R.PAD1) .. EVT_Cut(t, R.CUT)
  end
  local tinted = PL.HsPlatesReady()
  PL.hs_plates_wait = not tinted
  -- left set (the aura slot): moved left by its locator so the name starts near the plate's left edge; its plate,
  -- focus frame and portrait moved back right
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS1, 0, -R.TEXT_SHIFT1)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE1, 0, R.BASE_X + R.TEXT_SHIFT1)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS1, 0, R.FOCUS_X + R.TEXT_SHIFT1)
  -- left plate: IF's purple plate (the retail white one until it is loaded), half the row
  if tinted then
    funcLuaMenuCommand(C.SPRITE, L, R.PLATE_TEX_CRC, R.PLATE_AURA, EVT_ROW_BASE, 0, 0)
  else
    funcLuaMenuCommand(C.SPRITE, L, EVT_ROW_TEX, EVT_ROW_BASE, EVT_ROW_BASE, 0, 0)
  end
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE1, R.HALF_W, R.BASE1_SIZE[2])
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS1, R.FOCUS_HALF_W, R.FOCUS_SIZE[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.FOCUS1, PL.hs_half == 0, 0)
  funcLuaMenuCommand(2333948100 --[[text style]], L, 0, R.TEXT1, R.STYLE)
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT1, R.TEXT1_SPLIT_W, R.TEXT1_BOX[2])
  funcLuaMenuCommand(C.TEXT, L, R.TEXT1, label(aura, 0), 0)
  funcLuaMenuCommand(C.TEXT_ALPHA, L, 0, R.TEXT1, 1)
  PL.HsFace(R.ICON1, R.ICON_SLOT1, R.AURA_FACE_X, aura ~= 0 and function(L1, m, s)
    return PL.AuraPortrait(L1, 0, m, s, aura)
  end or nil, string.format("%s:%08X", tostring(n), EVT_U32(aura)))
  -- right plate: the spare title set, its base = the same plate in orange (the mix slot: Mix-Max or «Modo cambio»),
  -- half the row, on the right, as tall as the left one and on its line
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, R.POS2, true, 0)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.POS2, 0, R.SHIFT2 - R.TEXT_SHIFT2)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 0, R.BASE_X + R.TEXT_SHIFT2)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.FOCUS2, 0, R.FOCUS_X + R.TEXT_SHIFT2)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.BASE2, true, 0)
  if tinted then
    funcLuaMenuCommand(C.SPRITE, L, R.PLATE_TEX_CRC, R.PLATE_MIX, R.SLOT2, 0, 0)
  else
    funcLuaMenuCommand(C.SPRITE, L, EVT_ROW_TEX, EVT_ROW_BASE, R.SLOT2, 0, 0)
  end
  funcLuaMenuCommand(R.SCALE, L, 0, R.BASE2, R.HALF_W, R.BASE1_SIZE[2])
  funcLuaMenuCommand(R.TRANSLATE, L, 0, R.BASE2, 1, R.BASE1_Y)
  PL.HsTouch(R.TOUCH_SPLIT)
  funcLuaMenuCommand(C.SPRITE, L, EVT_ROW_TEX, R.FOCUS_SPRITE, R.FOCUS2_SLOT, 0, 0)
  funcLuaMenuCommand(R.SCALE, L, 0, R.FOCUS2, R.FOCUS_HALF_W, R.FOCUS_SIZE[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L, R.FOCUS2, PL.hs_half == 1, 0)
  funcLuaMenuCommand(2333948100 --[[text style]], L, 0, R.TEXT2, R.STYLE)
  funcLuaMenuCommand(R.SCALE, L, 0, R.TEXT2, R.TEXT2_SPLIT_W, R.TEXT2_BOX[2])
  funcLuaMenuCommand(C.TEXT, L, R.TEXT2, label(mix, 1), 0)
  funcLuaMenuCommand(C.TEXT_ALPHA, L, 0, R.TEXT2, 1)
  PL.HsFace(R.ICON2, R.ICON_SLOT2, R.MIX_FACE_X, mix ~= 0 and function(L1, m, s)
    if mix_partner == nil then
      return false
    end
    if mix_partner.skill ~= nil then
      return PL.AuraPortrait(L1, 0, m, s, mix_partner.skill)
    end
    return PL.ListFace(L1, 0, m, s, mix_partner.face)
  end or nil, string.format("%s:%08X:%s:%s", tostring(n), EVT_U32(mix), mix_partner and tostring(mix_partner.skill) or "-",
    mix_partner and tostring(mix_partner.face) or "-"))
end

-- a plate's portrait on the row's icon quad `mesh` (texture slot `slot`) at the plate's right end. `draw(L, mesh,
-- slot)` draws it and returns true; when it draws nothing the player's own face is shown instead, so a filled plate
-- never shows the bare quad (a white square). draw nil = hidden. The slot is reset first (a previous portrait or move
-- icon never shows through). `key` names what is drawn (player + move): while it is unchanged the portrait already on
-- the slot is kept, as a redraw reloads the texture and shows the bare quad (a white flash) on every row refresh.
PL.hs_faces = false
PL.hs_face_key = {}                            -- texture slot -> key of the portrait drawn on it
function PL.HsFace(mesh, slot, x, draw, key)
  local R, L = PL.HS_ROW, L_ROW
  funcLuaMenuCommand(R.TRANSLATE, L, 0, mesh, 0, x)
  funcLuaMenuCommand(R.TRANSLATE, L, 0, mesh, 1, R.FACE_Y)
  funcLuaMenuCommand(R.SCALE, L, 0, mesh, R.FACE_SIZE, R.FACE_SIZE)
  if draw ~= nil and key ~= nil and PL.hs_faces and PL.hs_face_key[slot] == key then
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, true, 0)   -- the row refresh hid the icon mesh: the same portrait again
    return
  end
  PL.hs_face_key[slot] = nil
  funcLuaMenuCommand(R.RESET_FACE, L, 0, slot)
  if draw == nil then
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, false, 0)
    return
  end
  PL.hs_faces = true
  local okd, drawn = pcall(draw, L, mesh, slot)
  if not (okd and drawn == true) then
    funcLuaMenuCommand(R.RESET_FACE, L, 0, slot)
    okd, drawn = pcall(PL.OwnerFace, L, 0, mesh, slot)
  end
  local shown = okd and drawn == true
  funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, shown, 0)
  if shown then
    PL.hs_face_key[slot] = key
  end
end

-- a character's list face icon (552280324, as the bank / dock lists draw it) on (mesh, slot); false = not drawn
function PL.ListFace(L, idx, mesh, slot, key)
  if type(key) ~= "number" or key == 0 then
    return false
  end
  pcall(SetDisableForceCharaInvalidUseTarget)
  local ok, r = pcall(funcLuaMenuCommand, 552280324 --[[chara face icon]], L, idx, false, mesh, slot, 0, 0, key)
  pcall(SetEnableForceCharaInvalidUseTarget)
  return ok and r ~= false
end

-- the shown player's own face icon on (mesh, slot): the fallback portrait; false = not drawn
function PL.OwnerFace(L, idx, mesh, slot)
  local key = funcLuaCommand(C.CHARA_GET, n, 1) or 0
  if key == 0 then
    return false
  end
  local param = funcLuaCommand(C.CHARA_GET, n, 4) or 0
  local okk, keeper = pcall(MENU_DEF.IsKeeper, param)
  pcall(SetDisableForceCharaInvalidUseTarget)
  local ok, r = pcall(funcLuaMenuCommand, 552280324 --[[chara face icon]], L, idx, false, mesh, slot, n, 255, key, 0,
    okk and keeper == true)
  pcall(SetEnableForceCharaInvalidUseTarget)
  return ok and r ~= false
end

-- an aura skill's portrait on (mesh, slot) by the retail aura windows' rule: the aura character (SKILL_INFO 17) drawn
-- as aura art of the aura type (SwapLayerFaceIconTex type PL.AURA_FACE_TYPE: keshin / armour 8, totem 14, Mix-Max 12
-- when that art exists). Keshin / armour / totem characters (k* / a* keys) have no list face icon, so 552280324 only
-- draws the other characters (a Mix-Max partner without Mix-Max art). False = not drawn.
function PL.AuraPortrait(L, idx, mesh, slot, skill)
  local ok, cid = funcLuaCommand(C.SKILL_INFO, skill, 17)
  if not ok or type(cid) ~= "number" or cid == 0 then
    return false
  end
  local _, t = funcLuaCommand(C.SKILL_INFO, skill, 13)
  local art = PL.AURA_FACE_TYPE[t]
  if art == 12 and funcLuaMenuCommand(2208175668 --[[has Mix-Max face art]], cid) ~= true then
    art = nil
  end
  if art == nil then
    return PL.ListFace(L, idx, mesh, slot, cid)
  end
  local okr, r = pcall(funcLuaMenuCommand, 346643487 --[[SwapLayerFaceIconTex]], L, idx, mesh, slot, cid, 0, art, true,
    true, true, 5)
  return okr and r ~= false
end

-- the mix slot's other character: {face = face key / chara id, name} or nil. A created fusion: its partner (All
-- Miximaxed / Inazuma Fantasy store, PL.MxGet); a «Modo cambio»: the other form (EVT_HC.McGet, else the change list);
-- a retail Mix-Max: its partner character (SKILL_INFO 17).
function PL.HsMixPartner(mix)
  if PL.MX_ON and mix == PL.MX_FUSION then
    local okf, f = pcall(PL.MxGet)
    if okf and f ~= nil and ((f.face or 0) ~= 0 or (f.chara or 0) ~= 0) then
      local face = (f.face ~= nil and f.face ~= 0) and f.face or f.chara
      return {face = face, name = (f.chara or 0) ~= 0 and PL.MxCharaName(f.chara) or nil}
    end
  end
  if type(EVT_HC) == "table" and type(EVT_HC.McGet) == "function" then
    local okm, m = pcall(EVT_HC.McGet, n, mix)
    if okm and m ~= nil and (m.face or 0) ~= 0 then
      return {face = m.face, name = m.name}
    end
  end
  local k = PL.McIndex ~= nil and PL.McIndex(mix) or nil
  if k ~= nil then
    for _, c in ipairs(PL.McList()) do
      if c.idx == k and (c.chara or 0) ~= 0 then
        return {face = c.chara, name = PL.MxCharaName(c.chara)}
      end
    end
  end
  local ok, cid = funcLuaCommand(C.SKILL_INFO, mix, 17)
  if ok and type(cid) == "number" and cid ~= 0 then
    return {face = cid, name = PL.MxCharaName(cid), skill = mix}
  end
  return nil
end

-- IF's pre-tinted plates (atlas evt_hs_plates): requested once; true when they can be drawn
PL.hs_plates = 0
function PL.HsPlatesReady()
  local R = PL.HS_ROW
  if PL.hs_plates == 0 then
    funcLuaMenuCommand(C.LOAD_TEX, R.PLATE_TEX)
    PL.hs_plates = 1
  end
  if PL.hs_plates == 1 and not funcLuaCommand(C.TEX_LOADING, R.PLATE_TEX_CRC) then
    PL.hs_plates = 2
  end
  return PL.hs_plates == 2
end

-- the picker's tabs follow the slot that opens it (owner 2026-10-12): a move row only the move categories, the Hiper
-- row's aura half keshin / totem, its mix half Mix-Max / «Modo cambio»; the whole
-- table again when the picker closes (also after an error, so the team dock's list is never left narrowed)
-- 2026-10-14 (owner: «en el selector de aura solo Keshin y Tótem, en el de mix solo miximax y modo cambio, en el de
-- supertécnicas solo tiro, regate, defensa y portero»): without Inazuma Fantasy the tab row is the VR-Framework's skill
-- tab registry (docs/framework/card-types.md §3): the picker asks CMND_VRFW_SKILL_TAB_WINDOW(group) for the group of
-- its slot; which categories each group holds is Character Reforged's data (content\skill_tabs\picker_groups.toml;
-- All Changed's «Modo cambio» tab joins «mix»). The other tabs are not built at all (the native list, the Z / C cycle,
-- the icons, the filters and the mouse zones follow the window); the cursor starts on the group's first tab. No
-- registered tab (the registry answers 0): the game's whole tab row.
PL.TAB_GROUP = {[1] = "moves", [2] = "aura", [3] = "mix"}   -- picker kind -> group name (0 / other: the whole list)
PL.VRFW_SKILL_TABS = 2356136113                  -- crc32("CMND_VRFW_SKILL_TABS") () -> n, categories (0 = off)
PL.VRFW_SKILL_TAB_WINDOW = 1059402324            -- crc32("CMND_VRFW_SKILL_TAB_WINDOW") (group) -> start, count
function PL.TabWindow(kind)
  local okt, tabs = pcall(funcLuaCommand, PL.VRFW_SKILL_TABS)
  if okt and type(tabs) == "number" and tabs > 0 then
    local okw, start, count = pcall(funcLuaCommand, PL.VRFW_SKILL_TAB_WINDOW, PL.TAB_GROUP[kind] or "")
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "picker tab window", PL.TAB_GROUP[kind] or "all",
      okw and tostring(start) or "?", okw and tostring(count) or tostring(start))
  end
end

PL.HsPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  if row == 0 and PL.HS_ON then
    pcall(PL.HsPointerPick)                        -- a click on a plate acts on that plate's half
  end
  local kind = 1
  if row == 0 then
    kind = 0
    if PL.HS_ON and not EVT_IsLocked(0) then
      kind = PL.hs_half == 1 and 3 or 2
    end
  end
  PL.TabWindow(kind)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "picker tabs", row, kind)
  local ok, err = pcall(PL.HsPrevPick, row)
  PL.TabWindow(0)
  if not ok then
    error(err, 0)
  end
end

-- the selected half (Left / Right on the Hiper row, R3): the panel follows it
function PL.HsSetHalf(half)
  if half == PL.hs_half then
    return
  end
  PL.hs_half = half
  PL.hs_view = half == 1 and "mix" or "aura"
  funcLuaCommand(C.SE, 2500047763 --[[sy0005 cursor]])
  pcall(PL.HsSplitRow)
  local ok, err = pcall(UpdateEquipItemInfo)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper half", half == 1 and "mix" or "aura", ok and "" or tostring(err))
end

-- the slot of a Hiper move: 0 aura, 1 mix, 2 an armour (its keshin second), -1 none; nil = no answer (module off:
-- the single-slot Hiper as before)
function PL.HsKind(id)
  if not PL.HS_ON or id == nil or id == 0 then
    return nil, 0
  end
  local ok, kind, k = pcall(funcLuaCommand, PL.HS_CMD.SLOT_OF, id)
  if not ok or type(kind) ~= "number" then
    return nil, 0
  end
  return kind, EVT_U32(k or 0)
end

-- the ids of «Crear miximax» and of the fusion carrier (CMND_EVT_MX_ITEMS; PL.MxGrant set them only when the Hiper
-- picker opened, so the panel drew a fusion as the bare carrier: «Miximax Trans» + its template move, no partner face)
function PL.MxIds()
  if PL.MX_FUSION ~= nil and PL.MX_FUSION ~= 0 then
    return
  end
  local ok, create, fusion = pcall(funcLuaCommand, PL.MX_ITEMS_CMD)
  if ok and type(create) == "number" and type(fusion) == "number" then
    PL.MX_CREATE = EVT_U32(create)
    PL.MX_FUSION = EVT_U32(fusion)
  end
end

-- the Hiper panel of the fusion carrier is the miximax panel (partner face, the partner's move)
PL.HsPrevHiperShow = PL.HiperShow
function PL.HiperShow(skill, team_info)
  pcall(PL.MxIds)
  return PL.HsPrevHiperShow(skill, team_info)
end

-- the shown player's mix-slot move (0 = empty)
function PL.HsMix()
  pcall(PL.MxIds)
  if not PL.HS_ON or n == nil or n == 0 then
    return 0
  end
  local ok, id = pcall(funcLuaCommand, PL.HS_CMD.MIX_GET, n)
  return (ok and type(id) == "number") and EVT_U32(id) or 0
end

function PL.HsMixPut(id)
  if PL.readonly or n == nil or n == 0 then
    return false
  end
  local ok, done, code = pcall(funcLuaCommand, PL.HS_CMD.MIX_SET, n, id or 0)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper mix slot", string.format("%08X", EVT_U32(n)),
    string.format("%08X", EVT_U32(id or 0)), tostring(ok), tostring(done), tostring(code))
  return ok and done == true
end

-- a Mix-Max fusion: the move's name only (owner 2026-10-12: never the player's); a created change:
-- «<carrier name>: <partner>»; else the move's own name
function PL.HsMixName(mix, partner)
  if mix == nil or mix == 0 then
    return ""
  end
  if partner == nil then
    partner = PL.HsMixPartner(mix)
  end
  if partner ~= nil and type(partner.name) == "string" and partner.name ~= "" then
    return partner.name
  end
  return EVT_Name(mix)
end

-- the base equip of the Hiper row (under the miximax / mode change wrappers, which call PL.MxPrevEquip): a mix move
-- goes to the mix slot (never board slot 8), an armour alone is refused
PL.HsBaseEquip = PL.MxPrevEquip
function PL.MxPrevEquip(row, skill, inv_hint, cur)
  if row == 0 then
    local kind = PL.HsKind(skill)
    if kind == 1 then
      if not PL.HsMixPut(skill) then
        funcLuaCommand(C.SE, SE_NG)
        EVT_Message(PL.Txt(PL.HS_TX.MIX_FAIL))
      end
      return
    elseif kind == 2 then
      funcLuaCommand(C.SE, SE_NG)
      EVT_Message(PL.Txt(PL.HS_TX.ARMOUR))
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper armour alone refused", string.format("%08X", EVT_U32(skill)))
      return
    end
  end
  return PL.HsBaseEquip(row, skill, inv_hint, cur)
end

-- a created change becomes his mix slot (the store's equipped change + its carrier in the mix slot)
function PL.McEquip(idx, cur)
  local id = PL.MC_CAR[idx + 1]
  if id == nil then
    return false
  end
  pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, idx)
  return PL.HsMixPut(id)
end

-- «Crear miximax» and Eliminar on the fusion entry: the fusion lives in the mix slot
PL.HsPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if PL.HS_ON and PL.MX_ON and row == 0 then
    if skill == PL.MX_FUSION and funcLuaCommand(C.P_HAS, PL.MX_KEY_DEL) then
      funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
      PL.MxClear()
      if PL.HsMix() == PL.MX_FUSION then
        PL.HsMixPut(0)
      end
      return
    end
    if skill == PL.MX_CREATE then
      funcLuaCommand(C.P_CLEAR, PL.MX_KEY_DEL)
      funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
      PL.MxFlow()
      if PL.mx_done == true then
        if PL.HsMixPut(PL.MX_FUSION) then
          funcLuaCommand(C.SE, SE_DECIDE)
          local played = PL.MxScenePlay()
          if not played and not PL.mx_scene_msg_shown then
            EVT_Message(PL.Txt(PL.HS_TX.MX_ASSIGNED, PL.mx_done_name or ""))
          end
          PL.mx_scene_msg_shown = false
        else
          funcLuaCommand(C.SE, SE_NG)
          EVT_Message(PL.Txt(PL.HS_TX.MIX_FAIL))
        end
      end
      return
    end
  end
  return PL.HsPrevEquip(row, skill, inv_hint, cur)
end

-- the mix slot emptied: a fusion asks first and is undone, a created change is emptied and «delete the change too?»
function PL.HsRemoveMix(mix)
  local mk = PL.McIndex ~= nil and PL.McIndex(mix) or nil
  if PL.MX_ON and mix == PL.MX_FUSION then
    local f = PL.MxGet()
    if f ~= nil then
      funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
      if not PL.MxAsk(PL.Txt(PL.HS_TX.ASK_MX, PL.MxCharaName(f.chara))) then
        funcLuaCommand(C.SE, SE_BACK)
        return
      end
      PL.MxClear()
    end
    PL.HsMixPut(0)
    funcLuaCommand(C.SE, SE_REMOVE)
  elseif mk ~= nil then
    local chara = 0
    for _, c in ipairs(PL.McList()) do
      if c.idx == mk then
        chara = c.chara
      end
    end
    PL.HsMixPut(0)
    funcLuaCommand(C.SE, SE_REMOVE)
    if chara ~= 0 then
      funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
      if PL.MxAsk(PL.Txt(PL.HS_TX.ASK_MC_DELETE, PL.MxCharaName(chara))) then
        pcall(funcLuaCommand, PL.MC_CMD.DELETE, n, mk)
        funcLuaCommand(C.SE, SE_REMOVE)
      else
        pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, -1)
        funcLuaCommand(C.SE, SE_BACK)
      end
    end
  else
    PL.HsMixPut(0)
    funcLuaCommand(C.SE, SE_REMOVE)
  end
  PL.hs_view = "aura"
end

-- Y «Eliminar» on the Hiper row: with both slots filled, the retail list window asks which one
PL.HsPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if not PL.HS_ON or row ~= 0 or PL.mx_removing then
    return PL.HsPrevRestore(row)
  end
  local mix = PL.HsMix()
  if mix == 0 then
    return PL.HsPrevRestore(0)
  end
  local aura = EVT_Skill(0)
  if aura ~= 0 and PL.hs_half == 0 then
    return PL.HsPrevRestore(0)                     -- the aura half selected: its slot
  end
  PL.HsRemoveMix(mix)
  EVT_RefreshRows()
  UpdateEquipItemInfo()
  EVT_FocusRow(0)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- X «Restablecer» on the Hiper row restores the aura slot only (a kit Mix-Max / mode change is not an aura)
PL.HsPrevResetKit = PL.ResetKit
function PL.ResetKit(row)
  local m = PL.HsPrevResetKit(row)
  if row == 0 and m ~= 0 then
    local kind = PL.HsKind(m)
    if kind ~= nil and kind ~= 0 then
      return 0
    end
  end
  return m
end

-- once per shown player: a single-slot leftover on board slot 8 (a Mix-Max / change carrier, an armour alone) is
-- filed into its slot (the save's own migration does the same for every card; this covers a page opened first)
function PL.HsFixRow()
  if not PL.HS_ON or n == nil or n == 0 or PL.hs_fixed[n] or PL.readonly or EVT_IsPrime() or not EVT_HasBoard() then
    return
  end
  PL.hs_fixed[n] = true
  local cur = EVT_Skill(0)
  local kind, k = PL.HsKind(cur)
  if kind == 1 then
    local moved = PL.HsMix() == 0 and PL.HsMixPut(cur)
    EVT_Call(C.EVT_CLEAR, n, EVT_HIPER_SLOT, 3 --[[keepOpen 3: everything off]])
    EVT_TeamAuraPut(0)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper fix: mix move off the aura slot", string.format("%08X", EVT_U32(cur)),
      moved and "into the mix slot" or "the mix slot was taken: dropped")
  elseif kind == 2 then
    EVT_Call(C.EVT_CLEAR, n, EVT_HIPER_SLOT, 3)
    EVT_TeamAuraPut(0)
    if k ~= 0 then
      pcall(PL.HsBaseEquip, 0, k)
    end
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper fix: armour alone", string.format("%08X", EVT_U32(cur)), "keshin",
      string.format("%08X", EVT_U32(k)), "now", string.format("%08X", EVT_U32(EVT_Skill(0))))
  end
end

-- the Hiper row: «<aura>   /   <mix>». Character Reforged 1.7.10 (owner 2026-10-14: no save edits by viewing): the
-- single-slot leftover fix (PL.HsFixRow, it rewrote board slot 8 / the mix store when a player was shown) is no longer
-- called; the halves show the projection instead (PL.CrShownSlots).
PL.HsPrevRow = UpdateEquipListItem
function UpdateEquipListItem(a1)
  PL.HsPrevRow(a1)
  if a1 ~= 0 or not PL.HS_ON then
    return
  end
  if EVT_IsLocked(0) then                          -- a level-locked Hiper row: one row as before
    pcall(PL.HsUnsplitRow)
    return
  end
  local ok, err = pcall(PL.HsSplitRow)
  if not ok then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper split row error", tostring(err))
  end
end

-- no chain: the miximax panel has no «aura that comes with it» view any more
function PL.MxAura2()
  PL.mx_aura = nil
  funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_AURA2, 0, false)
end

-- the panel of the Hiper row: the aura slot, R3 = the mix slot (a mix-only row shows the mix slot)
function PL.HsShowMix(mix)
  local _, team_info = GetSoccerTeamInfo(0)
  local ok, shown = false, false
  if PL.MX_ON and mix == PL.MX_FUSION then
    local okf, f = pcall(PL.MxGet)
    if okf and f ~= nil then
      ok, shown = pcall(PL.MxDetail, f, team_info)
    end
  else
    ok, shown = pcall(PL.HiperShow, mix, team_info)
  end
  if ok and shown then
    SetVisibleEquipInfoWindow(false)
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper panel: mix slot", string.format("%08X", EVT_U32(mix)), tostring(ok),
    tostring(shown))
end

PL.HsPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo()
  local row = (PL.HS_ON and n14 ~= L_BTN) and funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) or -1
  local mix = row == 0 and PL.HsMix() or 0
  local aura = mix ~= 0 and PL.RowMove(0) or 0
  PL.hs_both = mix ~= 0 and aura ~= 0              -- before the guide is drawn (PL.MxGuideAdd)
  PL.hs_view = PL.hs_half == 1 and "mix" or "aura"
  if mix == 0 then
    PL.hs_view = "aura"
  end
  PL.HsPrevItemInfo()
  if mix == 0 then
    return
  end
  if aura ~= 0 and PL.hs_view ~= "mix" then
    return                                       -- the aura slot's panel, as drawn
  end
  PL.HsShowMix(mix)
  if PL.guide_redo ~= nil then
    pcall(PL.guide_redo)                         -- a mix-only row is removable (Y)
  end
end

-- guide: «R3 Ver Mix-Max / Ver aura» while both slots are filled; Y «Eliminar» on a mix-only row
PL.HsPrevGuideAdd = PL.MxGuideAdd
function PL.MxGuideAdd(t, i, c, o)
  if PL.HsPrevGuideAdd ~= nil then
    PL.HsPrevGuideAdd(t, i, c, o)
  end
  if not PL.HS_ON or n14 == L_BTN or funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) ~= 0 then
    return
  end
  if PL.hs_both then
    local k = #t + 1
    t[k] = PL.hs_view == "mix" and PL.TX_VIEW_AURA or PL.HS_TX.VIEW_MIX
    i[k] = PL.I_R3
    c[k] = PL.K_R3
    o[k] = 18
  end
  local has_remove = false
  for k, x in ipairs(t) do
    if x == PL.TX.BTN_REMOVE or c[k] == PL.K_FUNC3 then
      has_remove = true                            -- V / Y is already there (Restablecer, held: Eliminar)
    end
  end
  if not has_remove and PL.RowMove(0) == 0 and PL.HsMix() ~= 0 and not EVT_IsPrime() then
    local k = #t + 1
    t[k] = PL.TX.BTN_REMOVE
    i[k] = PL.I_FUNC3
    c[k] = PL.K_FUNC3
    o[k] = 18
  end
end

-- Y on a mix-only Hiper row: Eliminar (the retail path only sees the empty aura slot)
PL.HsPrevFunction = OnFunction
function OnFunction(a1, a2)
  if PL.HS_ON and evt_co == nil and a1 == 4109882573 and n14 ~= L_BTN
      and funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) == 0 and (EVT_Skill(0) == 0 or PL.hs_half == 1) and PL.HsMix() ~= 0
      and not EVT_IsPrime() and not PL.IdolFixed(0) then
    evt_co = coroutine.create(function()
      local act = PL.TapOrHold(true)              -- V / Y: tap = Restablecer, hold = Eliminar
      if act == "remove" then
        EVT_RestoreCoroutine(0)
      else
        EVT_ResetCoroutine(0)
      end
    end)
    return
  end
  return PL.HsPrevFunction(a1, a2)
end

-- Left / Right on the Hiper row select the half (round 6: on the press edge, no lock; every menu controller the game
-- may have selected, then the pad / arrow keys while the list has the control focus; never a controller switch)
function PL.HsLR()
  local R = PL.HS_ROW
  local left, right = false, false
  for _, c in ipairs(R.CTRLS) do
    left = left or funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], c, R.K_LEFT) == true
    right = right or funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], c, R.K_RIGHT) == true
  end
  if not left and not right and funcLuaMenuCommand(R.CTRL_FOCUS, L_ROW) == true then
    local ok, held = pcall(funcLuaCommand, R.PAD)
    if ok and type(held) == "number" and held > 0 then
      left = math.floor(held / R.PAD_LEFT) % 2 == 1
      right = math.floor(held / R.PAD_RIGHT) % 2 == 1
    end
    local okl, kl = pcall(funcLuaCommand, R.VKEY, R.VK_LEFT)
    local okr, kr = pcall(funcLuaCommand, R.VKEY, R.VK_RIGHT)
    left = left or (okl and kl == true)
    right = right or (okr and kr == true)
  end
  if left == right then
    return 0
  end
  return left and -1 or 1
end

-- the row's native touch quad (instance 0): {w, h, x, y}
function PL.HsTouch(b)
  local R = PL.HS_ROW
  funcLuaMenuCommand(R.SCALE, L_ROW, 0, R.TOUCH, b[1], b[2])
  funcLuaMenuCommand(R.TRANSLATE, L_ROW, 0, R.TOUCH, 0, b[3])
  funcLuaMenuCommand(R.TRANSLATE, L_ROW, 0, R.TOUCH, 1, b[4])
end

-- the half under the pointer (0 aura, 1 mix), nil = not over a plate of the Hiper row
function PL.HsPointerHalf()
  local R = PL.HS_ROW
  local x, y = funcLuaMenuCommand(R.PTR_POS)
  local gx, gy = funcLuaMenuCommand(R.PTR_GPOS, L_ROW, 0)
  if type(x) ~= "number" or type(y) ~= "number" or type(gx) ~= "number" or type(gy) ~= "number" then
    return nil
  end
  local lx, ly = x - gx, -y - gy
  if ly < R.HIT_Y[1] or ly > R.HIT_Y[2] then
    return nil
  end
  for h = 0, 1 do
    if lx >= R.HIT_X[h + 1][1] and lx <= R.HIT_X[h + 1][2] then
      return h
    end
  end
  return nil
end

-- hover: the pointer moved over a plate of the focused Hiper row -> that half (a pointer at rest never overrides
-- Left / Right)
function PL.HsPollPointer()
  local R = PL.HS_ROW
  local x, y = funcLuaMenuCommand(R.PTR_POS)
  if type(x) ~= "number" or type(y) ~= "number" then
    return
  end
  local moved = funcLuaMenuCommand(R.PTR_MOVED) == true
  if PL.hs_ptr ~= nil and (math.abs(x - PL.hs_ptr[1]) > 1 or math.abs(y - PL.hs_ptr[2]) > 1) then
    moved = true
  end
  PL.hs_ptr = {x, y}
  if not moved or EVT_IsLocked(0) then
    return
  end
  local h = PL.HsPointerHalf()
  if h ~= nil then
    PL.HsSetHalf(h)
  end
end

-- a click (mouse button / Accept on the pointer) that opens the Hiper picker: the half under the pointer first
function PL.HsPointerPick()
  local R = PL.HS_ROW
  local clicked = false
  for _, k in ipairs(R.PTR_CLICK) do
    clicked = clicked or funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 1332654303 --[[MENU_CTRL]], k) == true
  end
  if not clicked or EVT_IsLocked(0) then
    return
  end
  local h = PL.HsPointerHalf()
  if h ~= nil and h ~= PL.hs_half then
    PL.hs_half = h
    PL.hs_view = h == 1 and "mix" or "aura"
    pcall(PL.HsSplitRow)
  end
end

-- the selected half follows Left / Right; R3 switches it while both slots are filled
function PL.HsPollR3()
  PL.hs_r3_wait = math.max(0, (PL.hs_r3_wait or 0) - 1)
  if evt_co ~= nil then
    PL.hs_lr_prev = 2                              -- a key still held when a coroutine ends is not a new press
    return
  end
  if n14 == L_BTN or funcLuaMenuCommand(C.FOCUS_IDX, L_ROW) ~= 0 then
    PL.hs_lr_prev = 2
    if PL.hs_half ~= 0 then                        -- off the row: the aura half again, quietly
      PL.hs_half = 0
      PL.hs_view = "aura"
      if PL.HS_ON and not EVT_IsLocked(0) then
        pcall(PL.HsSplitRow)
      end
    end
    return
  end
  pcall(PL.HsPollPointer)
  local dir = PL.HsLR()
  local prev = PL.hs_lr_prev
  PL.hs_lr_prev = dir
  if dir ~= 0 and dir ~= prev then
    if prev ~= 2 then
      PL.HsSetHalf(dir > 0 and 1 or 0)
    end
    return
  end
  if PL.hs_r3_wait > 0 or not PL.hs_both then
    return
  end
  if funcLuaCommand(4265778440, 1332654303 --[[MENU_CTRL]], PL.K_R3) == true
      or funcLuaCommand(4265778440, 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]], PL.K_R3) == true then
    PL.hs_r3_wait = 10
    PL.HsSetHalf(1 - PL.hs_half)
  end
end

PL.HsPrevStep = Step
function Step(...)
  local r = PL.HsPrevStep ~= nil and PL.HsPrevStep(...) or nil
  pcall(PL.HsPollR3)
  if PL.hs_plates_wait and PL.HsPlatesReady() then   -- the tinted plates came in: redraw the split row
    PL.hs_plates_wait = false
    if PL.HS_ON and not EVT_IsLocked(0) then
      pcall(PL.HsSplitRow)
    end
  end
  return r
end
-- ===== Two Hiper slots END =====

-- ===================================================================================================
-- Miximax scene input guard (2026-10-12; owner rule: never switch the menu input controller nor MENU_ACTIVE for this,
-- that froze the shop). While PL.mx_scene_busy (PL.MxScenePlay: from the fade out to the fade in) this screen's own
-- callbacks and Step polls return at once: no row, R3 / LEFT / RIGHT half switch, back or function key acts on the
-- hidden screen (it is resumed between the two events for the miximax look). Wraps the final definitions.
-- ===================================================================================================
PL.MxGuardPrev = {OnEnter = OnEnter, OnDecideFocus = OnDecideFocus, OnBack = OnBack, OnFunction = OnFunction}
function OnEnter(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnEnter(...)
end
function OnDecideFocus(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnDecideFocus(...)
end
function OnBack(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnBack(...)
end
function OnFunction(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnFunction(...)
end
PL.MxGuardPrevPollR3 = PL.MxPollR3
function PL.MxPollR3(...)
  -- also while an action runs (evt_co: the move / aura picker or a popup over this screen): its R3 is not this screen's
  if PL.mx_scene_busy or evt_co ~= nil or PL.MxGuardPrevPollR3 == nil then
    return
  end
  return PL.MxGuardPrevPollR3(...)
end
PL.MxGuardPrevHsPollR3 = PL.HsPollR3
function PL.HsPollR3(...)
  if PL.mx_scene_busy or PL.MxGuardPrevHsPollR3 == nil then
    return
  end
  return PL.MxGuardPrevHsPollR3(...)
end
-- ===== Miximax scene input guard END =====

-- ===================================================================================================
-- Row focus resync (2026-10-13, owner: entering any player's page the cursor is on the Hiper row but the detail panel
-- stays empty and Left / Right cannot reach the mix slot until Down + Up; after the miximax scene the same with the
-- cursor on the mix slot). n14 (the screen's «focused layer») had been set to the bottom button by a button layer's
-- OnChangeFocus (the «Pasiva personalizada» / role buttons' wrappers take every focus event, unlike the retail one
-- that drops events of a layer without the control focus) while the control focus was on the row list: the panel then
-- drew nothing (UpdateEquipItemInfo's button path) and PL.HsPollR3 ignored Left / Right. Now (1) a button's focus event
-- is dropped while the row list holds the control focus and that button does not (CMND_IS_CTRL_FOCUS_ACTIVE, the retail
-- filter), and (2) for PL.FS_WINDOW frames after the screen opens and after EVT_FocusRow, a Step with the row list in
-- control and n14 elsewhere sets n14 back to the list and redraws the panel (UpdateEquipItemInfo).
-- ===================================================================================================
PL.FS_WINDOW = 120
PL.fs_wait = 0
PL.FS_CTRL = 102308320                  -- CMND_IS_CTRL_FOCUS_ACTIVE(layer)

function PL.CtrlFocus(L)
  if L == nil then
    return false
  end
  local ok, on = pcall(funcLuaMenuCommand, PL.FS_CTRL, L)
  return ok and on == true
end

-- the row list has the control focus and none of the bottom buttons does
function PL.RowHasFocus()
  if not PL.CtrlFocus(L_ROW) then
    return false
  end
  for _, b in ipairs({L_BTN, L_BTN_SS, PL.L_BTN_ROLE}) do
    if PL.CtrlFocus(b) then
      return false
    end
  end
  return true
end

function PL.FocusResync(why)
  n14 = L_ROW
  local ok, err = pcall(UpdateEquipItemInfo)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "focus resync", why, "row", funcLuaMenuCommand(C.FOCUS_IDX, L_ROW),
    ok and "" or tostring(err))
end

PL.FsPrevChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  if (a1 == L_BTN or a1 == L_BTN_SS or a1 == PL.L_BTN_ROLE) and not PL.CtrlFocus(a1) and PL.RowHasFocus() then
    if n14 ~= L_ROW then
      PL.FocusResync("button focus event dropped")
    end
    return
  end
  return PL.FsPrevChangeFocus(a1, a2)
end

PL.FsPrevInit = OnInit
function OnInit(...)
  PL.fs_wait = PL.FS_WINDOW
  return PL.FsPrevInit(...)
end

PL.FsPrevStep = Step
function Step(...)
  local r = PL.FsPrevStep ~= nil and PL.FsPrevStep(...) or nil
  if PL.fs_wait > 0 then
    PL.fs_wait = PL.fs_wait - 1
    if not PL.mx_scene_busy and evt_co == nil and n14 ~= L_ROW and PL.RowHasFocus() then
      PL.FocusResync("step")
    end
  end
  return r
end
-- ===== Row focus resync END =====

-- ===== Move plate rows + own list layers BEGIN =====
-- 2026-10-13 (owner): the 6 move rows of the list (1-6) in the MOVE PLATE format of the detail panel: the element
-- plate (retail cmd_base_sp0N of soccer11_09: fire red, wood green, wind blue, mountain orange), the category icon in
-- the circle at the LEFT, the name white with outline (graded font of the move's own evolution, PL.SkillItem), the AT /
-- DF label + value at the RIGHT. Empty slot: the retail neutral grey plate (cmd_base_sp06) with «---». A level-locked
-- row: the grey plate with the move it will learn (dimmed) and the retail move-row lock (_pos_lock01) carrying the
-- unlock level; a fixed row (Prime / Idol learnset): the move's plate with the lock instead of the AT. Drawn on layer
-- evt_ss_row_plate (7 instances; object evt_ss_row_plate = evt_ph_move_row's recipe on a layout copy with the plate
-- 9 px right, centred in the row's frame): instance r rides on list row r (object evt_ss_equip_row:
-- NullLayerIndexName on _pos_base01), so the row's cyan focus frame, touch quad and animations stay the row's own.
-- Instance 0 (the split Hiper row) stays hidden. A plate is shown only while its row is (PL.RowPlateSync, every Step).
PL.RP = {
  ON = true,
  L = 2650954806 --[[evt_ss_row_plate]],
  PRIO = 553,                                      -- the list row is 552 (soccer11_08 m_drawPriority)
  ROW_BASE = 970690259 --[[_item_list_base01]],    -- the row's white / navy base, hidden under the plate
  -- the plate's own parts / sprites / states: VRFW_UI.MovePlate (66_ui_plates.lua)
  IS_OPEN = 2640875187, IS_VISIBLE = 1262717583,
  want = {},
}

function PL.RowPlate(r, skill, locked, need, fixed, inactive)
  local P = PL.RP
  local L = P.L
  P.want[r] = false
  if not P.ON or r < 1 or r >= EVT_ROW_NUM or SetupCharaSkillItem == nil or type(VRFW_UI) ~= "table"
      or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) then
    return false
  end
  skill = skill or 0
  -- the shared move plate's list row (VRFW_UI.MovePlate.Row): the neutral plate first, the retail fill on L with the
  -- move's own grade (no blank / AI-mark layers), back to this screen's own setting; empty «---», level-locked (grey,
  -- dimmed name, the lock with the level), fixed (the lock instead of the AT), inactive (on the board, not in the
  -- match list: the name greyed with the lock rows' colour; the plate's `suffix` slot writes it, nothing appended)
  local ok, err = VRFW_UI.MovePlate.Row(L, r, n, skill, {page = L_ROW, open = PL.Open, restore = {nil, L_DETAIL, 0, nil, nil},
    locked = locked, need = need, fixed = fixed, lock_color = PL.LOCK_COLOR,
    name = skill ~= 0 and (inactive and (PL.LOCK_COLOR .. EVT_Name(skill) .. "[C]") or EVT_Name(skill)) or nil,
    suffix = inactive and "" or nil, empty_text = "", log = true})   -- inactive: the name greyed (no text appended); log: «move plate fill»
  if not ok then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "row plate failed", r, string.format("%08X", EVT_U32(skill)), tostring(err))
    return false
  end
  P.want[r] = true
  pcall(PL.RowPlateSync)
  return true
end

-- a plate shows while it is wanted and its list row is visible (the lists covering the column hide the rows)
function PL.RowPlateSync(step)
  local P = PL.RP
  if type(VRFW_UI) == "table" then
    VRFW_UI.MovePlate.Pump(step)                   -- the plates filled before their instance was ready, again
  end
  if not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], P.L) then
    return
  end
  for r = 0, EVT_ROW_NUM - 1 do
    if funcLuaMenuCommand(P.IS_OPEN, P.L, r) then
      local v = P.want[r] == true and funcLuaMenuCommand(P.IS_VISIBLE, L_ROW, r) == true
      if (funcLuaMenuCommand(P.IS_VISIBLE, P.L, r) == true) ~= v then
        funcLuaMenuCommand(C.LAYER_VISIBLE, P.L, r, v)
      end
    end
  end
end

-- 2026-10-13 (owner: the combo partner rows smaller, less gap): the partner picker's OWN list frame and rows (layers
-- evt_cpk_list / evt_cpk_row: 8 rows 84 high, step 76), passed to PL.PopList as mode.list_layer / row_layer (graft
-- combo_partners); the shared evt_ss_list / team08_02 rows of the passive / role / set selectors are untouched.
PL.L_CPK_LIST = 2148145526 --[[evt_cpk_list]]
PL.L_CPK_ROW = 664477730 --[[evt_cpk_row]]
PL.CPK_ROWS = 9
PL.PTR_CPK = {-98, 970, 60}                        -- the row's visible plate (75 high sprite, ~56 opaque; step 68)
-- 2026-10-13 (owner): scroll arrows of that list. Layer evt_cpk_arrow = the retail item list frame (item01_01) cut to its
-- two arrows (_arrow_list_u01 / _d01, 56 x 32) moved to the right margin of the rows; PL.ListArrows shows the up one
-- when rows lie above the visible window and the down one when rows lie below (the retail lists' scroll indicators).
PL.L_CPK_ARROW = 1928945792 --[[evt_cpk_arrow]]
PL.CPK_ARROW_UP = 1288675512 --[[_pos_arrow_u01]]
PL.CPK_ARROW_DOWN = 1361799679 --[[_pos_arrow_d01]]

function PL.ListArrows(show, first, nr, total, list_layer)
  local L = PL.L_CPK_ARROW
  if list_layer ~= PL.L_CPK_LIST or not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L) then
    return
  end
  local up = show and first > 0
  local down = show and first + nr < total
  if up or down then
    PL.Open(L)
    funcLuaMenuCommand(EVT_POS_VISIBLE, L, PL.CPK_ARROW_UP, up, 0)
    funcLuaMenuCommand(EVT_POS_VISIBLE, L, PL.CPK_ARROW_DOWN, down, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, up or down)
end

PL.RpPrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == PL.RP.L then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, PL.RP.PRIO, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_CPK_LIST then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 450, true)
    for _, pos in ipairs({1839509013 --[[_pos_scr_base01]], 1060758565 --[[_pos_scr_obj01]]}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3660005257 --[[_text_list_empty01]], false, a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_CPK_ROW then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 451, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_CPK_ARROW then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 452, true)
    for _, pos in ipairs({1839509013 --[[_pos_scr_base01]], 1060758565 --[[_pos_scr_obj01]]}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 970690259 --[[_item_list_base01]], false, a2)
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3037571460 --[[_text_list01]], false, a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  return PL.RpPrevSetupLayer(a1, a2)
end

PL.RpPrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == PL.RP.L then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)   -- PL.RowPlateSync shows it (next Step)
    return
  elseif a1 == PL.L_CPK_LIST or a1 == PL.L_CPK_ROW or a1 == PL.L_CPK_ARROW then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  return PL.RpPrevOpenLayer(a1, a2)
end

PL.RpPrevStep = Step
function Step(...)
  local r = PL.RpPrevStep ~= nil and PL.RpPrevStep(...) or nil
  pcall(PL.RowPlateSync, true)
  return r
end
-- ===== Move plate rows + own list layers END =====

-- ===== Character Reforged projection (2026-10-14) =====
-- Writing a move row whose list position holds a hidden aura (PL.ProjPos): the aura goes to its own slot first when
-- that is free (keshin / totem -> the aura half: board slot 8 + the team aura row; Mix-Max / «Modo cambio» -> the mix
-- half: Character Reforged's store), else it is an overflow aura: the write replaces it (its item goes back to stock,
-- as any retail equip) and loader.log says so. A move already elsewhere in the list swaps (the aura moves, kept).
function PL.FreeListPos(row, skill)
  local pos = EVT_ListPos(row)
  local cur = EVT_ListSkill(pos)
  if cur == 0 or not EVT_IsSpecial(cur) or cur == skill then
    return
  end
  local p = funcLuaCommand(C.SKILL_POS, n, skill)
  if p ~= nil and p >= 0 and p < EVT_NORMAL_NUM then
    return                                       -- CMND_SET_SKILL swaps: the aura moves to the move's old position
  end
  local okk, kind = pcall(funcLuaCommand, PL.HS_CMD.SLOT_OF, cur)
  kind = okk and kind or -1
  local what = "overflow: replaced (item back to stock)"
  if (kind == 0 or kind == 2) and EVT_Skill(0) == 0 then
    local h, added = EVT_HiperHandle(cur)
    local ok = false
    if h ~= nil and h ~= 0 then
      ok = EVT_BoardPut(EVT_HIPER_SLOT, cur, h)
    end
    if added then
      funcLuaCommand(C.DEL_ITEM, cur, 1)
    end
    if ok and EVT_SPECIAL_TEAM_AURA then
      EVT_TeamAuraPut(cur)
    end
    what = ok and "moved to the aura slot" or "aura slot write FAILED: replaced"
  elseif kind == 1 then
    local okg, have = pcall(funcLuaCommand, PL.HS_CMD.MIX_GET, n)
    if okg and (tonumber(have) or 0) == 0 then
      local oks, done = pcall(funcLuaCommand, PL.HS_CMD.MIX_SET, n, cur)
      what = (oks and done == true) and "moved to the mix slot" or "mix slot write FAILED: replaced"
    end
  end
  EVT_Log("projection", "row", row, "list position", pos + 1, "hidden", EVT_Name(cur), what, "for", EVT_Name(skill))
end
-- Character Reforged 1.7.10: the aura / mix halves show THE projection (CharacterReforged.ProjectSkillSet, the same rule
-- the match uses; owner 2026-10-14: no save edits, read only). Aura half = the row's own aura (board slot 8, else the
-- team aura row) when it is a keshin / totem / armour, else the first keshin / totem / armour of the technique list (list
-- order); mix half = the stored mix, else the first Mix-Max / «Modo cambio» of the list, else of the board (a Mix-Max
-- on board slot 8 shows here, not in the aura half). Without Character Reforged's scripts: the row's own data.
PL.CR_PROJECT = 2177163225                  -- crc32("CMND_CHARACTERREFORGED_PROJECT_SKILL_SET")
function PL.CrProjection()
  if n == nil or n == 0 or EVT_IsPrime() then
    return nil
  end
  local ok, aura, mix, aura_from, mix_from = pcall(funcLuaCommand, PL.CR_PROJECT, n)
  if not ok or type(aura) ~= "number" then
    return nil
  end
  return {aura = EVT_U32(aura), mix = EVT_U32(mix or 0), aura_from = tonumber(aura_from) or -1, mix_from = tonumber(mix_from) or -1}
end
function PL.CrShownSlots()
  local own, mix = PL.RowMove(0), PL.HsMix()
  local okp, proj = pcall(PL.CrProjection)
  if not okp or proj == nil then
    return own, mix
  end
  local aura = own
  local kind = own ~= 0 and PL.HsKind(own) or nil
  if own == 0 or kind == 1 then
    aura = proj.aura                           -- a list aura (or none); a mix move on the row shows in the mix half
  end
  if mix == 0 then
    mix = proj.mix
  end
  return aura, mix
end

-- one loader.log line per shown player whose list holds hidden auras (kept; the 6 rows show the special moves)
PL.proj_logged = {}
function PL.ProjectionLog()
  if n == nil or n == 0 or PL.proj_logged[n] then
    return
  end
  PL.proj_logged[n] = true
  local hidden = {}
  for p = 0, EVT_NORMAL_NUM - 1 do
    local id = EVT_ListSkill(p)
    if id ~= 0 and EVT_IsSpecial(id) then
      hidden[#hidden + 1] = string.format("%d %s", p + 1, EVT_Name(id))
    end
  end
  if #hidden > 0 then
    EVT_Log("projection", "player", string.format("%08X", EVT_U32(n)), "hidden on list positions (kept):", table.concat(hidden, ", "))
  end
end
PL.ProjPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if row ~= nil and row > 0 and skill ~= nil and skill ~= 0 and n ~= nil and n ~= 0 and not EVT_IsPrime() then
    local ok, err = pcall(PL.FreeListPos, row, skill)
    if not ok then
      EVT_Log("projection", "free list position failed", tostring(err))
    end
  end
  return PL.ProjPrevEquip(row, skill, inv_hint, cur)
end
-- ===== Character Reforged projection END =====

-- ===== Board-only move guide (2026-10-14) =====
-- A move row greyed by the projection holds a move that sits on the board slot but not in the match list (its list
-- position is empty): the match does not use it. While such a row has the focus, the bottom guide line says so (text
-- evt_ss_board_only); leaving it puts the screen's own guide back. Nothing is written to the save.
PL.TX_BOARD_ONLY = 1501903055                 -- crc32("evt_ss_board_only")
PL.board_guide = false
PL.BgPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo(...)
  local r = PL.BgPrevItemInfo(...)
  local ok, err = pcall(PL.BoardOnlyGuide)
  if not ok then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "board-only guide failed", tostring(err))
  end
  return r
end

function PL.BoardOnlyGuide()
  local board_only = false
  if n14 ~= L_BTN and n ~= nil and n ~= 0 and not EVT_IsPrime() then
    local row = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    if type(row) == "number" and row >= 1 and row < EVT_ROW_NUM and not EVT_IsLocked(row) then
      local skill = PL.RowMove(row)
      board_only = skill ~= 0 and not EVT_Active(skill)
    end
  end
  if board_only then
    local t = PL.Txt(PL.TX_BOARD_ONLY)
    if t ~= "" then
      PL.Guide(t)
      PL.board_guide = true
    end
  elseif PL.board_guide then
    PL.board_guide = false
    if not PL.IdolFixed(funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)) then
      PL.Guide(EVT_GUIDE_TEXT)
    end
  end
end
-- ===== Board-only move guide END =====

-- ===== Character Reforged slot rules (2026-10-14) =====
-- What each slot accepts is Character Reforged's rule (scripts\skill_set.lua, CMND_CHARACTERREFORGED_CAN_PLACE: the
-- data of content\skill_set\*.toml + the place rules other mods register with CharacterReforged.AddPlaceRule, e.g. a
-- «no duplicate move» plugin). Slots: rows 1-6 = 1..6, the Hiper row's aura half = 7, its mix half = 8. The picker
-- (ss2_pick_1 block of ability_list_menu) greys / refuses through the same command (params evt_ss_pick_slot /
-- evt_ss_pick_chara set here around EVT_PickCoroutine); every equip of this screen (pick, player set, import, reset)
-- asks it in EVT_Equip. No answer (Character Reforged's scripts off) = allowed. PL fields only (no main-chunk locals).
PL.CR_CAN_PLACE = 6717499                    -- crc32("CMND_CHARACTERREFORGED_CAN_PLACE")
PL.CR_KEY_SLOT = 4199810934                  -- crc32("evt_ss_pick_slot")
PL.CR_KEY_CHARA = 3798840340                 -- crc32("evt_ss_pick_chara")
PL.CR_KEY_BOARD = 850416018                  -- crc32("evt_ss_pick_board"): the row's board slot (place rules "board"; -1 none)
function PL.CrSlotOf(row)
  if row == nil then
    return 0
  end
  if row == 0 then
    return PL.hs_half == 1 and 8 or 7
  end
  return row
end
PL.CR_PLACE_RULES = 884939394               -- crc32("CMND_CHARACTERREFORGED_PLACE_RULES")
-- the place rules other mods declare as data ([CharacterReforged.PlaceRules.<name>]): { {id, board}, … }, read once
function PL.CrRules()
  if PL.cr_rules ~= nil then
    return PL.cr_rules
  end
  local r = {pcall(funcLuaCommand, PL.CR_PLACE_RULES)}
  local out = {}
  if r[1] == true and type(r[2]) == "number" then
    for i = 1, r[2] do
      local id, kind = r[1 + 2 * i], r[2 + 2 * i]
      if type(id) == "number" and id ~= 0 then
        out[#out + 1] = {id = id, board = kind == 1}
      end
    end
  end
  PL.cr_rules = out
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "Character Reforged place rules", #out)
  return out
end
function PL.CrCanPlace(slot, skill)
  if skill == nil or skill == 0 or n == nil or n == 0 then
    return true, ""
  end
  local ok, res, why = pcall(funcLuaCommand, PL.CR_CAN_PLACE, n, slot, skill)
  if ok and res == false then
    return false, why or ""
  end
  for _, r in ipairs(PL.CrRules()) do
    local a = slot
    if r.board then
      a = (slot == 7) and EVT_HIPER_SLOT or ((slot >= 1 and slot <= 6) and EVT_ListPos(slot) or nil)
    end
    if a ~= nil then
      local okr, res2 = pcall(funcLuaCommand, r.id, n, a, skill)
      if okr and res2 == false then
        return false, string.format("rule %08X", EVT_U32(r.id))
      end
    end
  end
  return true, ""
end
PL.CrPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  P_Set(PL.CR_KEY_SLOT, PL.CrSlotOf(row))
  P_Set(PL.CR_KEY_CHARA, n or 0)
  local slot = PL.CrSlotOf(row)
  P_Set(PL.CR_KEY_BOARD, slot == 7 and EVT_HIPER_SLOT or ((slot >= 1 and slot <= 6) and EVT_ListPos(slot) or -1))
  local ok, err = pcall(PL.CrPrevPick, row)
  funcLuaCommand(C.P_CLEAR, PL.CR_KEY_SLOT)
  funcLuaCommand(C.P_CLEAR, PL.CR_KEY_CHARA)
  funcLuaCommand(C.P_CLEAR, PL.CR_KEY_BOARD)
  if not ok then
    error(err, 0)
  end
end
PL.CrPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  local slot = PL.CrSlotOf(row)
  if row == 0 and PL.HsKind ~= nil and skill ~= nil and skill ~= 0 then
    local kind = PL.HsKind(skill)                 -- the half the move goes to (IF's two Hiper slots)
    if kind == 1 then
      slot = 8
    elseif kind == 0 or kind == 2 then
      slot = 7
    end
  end
  local allowed, why = PL.CrCanPlace(slot, skill)
  if not allowed then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "equip refused by Character Reforged", row, slot,
      string.format("%08X", EVT_U32(skill or 0)), tostring(why))
    funcLuaCommand(C.SE, 2086672038 --[[sy0003]])
    return false
  end
  return PL.CrPrevEquip(row, skill, inv_hint, cur)
end
-- ===== Character Reforged slot rules END =====

-- ===== V tap / hold (2026-10-14) =====
-- V / Y on a row (CMD_FUNC3; owner 2026-10-14: as Inazuma Fantasy had it): a tap = «Restablecer» (the row's basic
-- kit move back), held PL.HOLD.SECONDS = «Eliminar» (the row emptied). The guide shows «Y Restablecer» only; the hold
-- is the framework's hold prompt (VRFW_FooterPrompts.AddHold / WaitHold, docs/framework/footer-prompts.md §6): no
-- ring while idle, the retail long-press ring (layer cr_skill_table_hold, Character Reforged
-- content\menus\skill_table_hold_ring.toml) over its glyph only while the key is held, filling with the hold. With
-- Inazuma Fantasy's block in this script (EVT_CPK) its own timer and ring answer instead. The pad's hold time comes
-- from Utilities' CMND_UTIL_PAD_HELD when it answers; without it the key counts as held while CMD_FUNC3 repeats.
-- PL fields only (no main-chunk locals).
PL.HOLD = {
  NAME = "CharacterReforged.SkillTableRemove",
  SECONDS = 2,                                     -- owner 2026-10-14: «cuando lo pulsas 2 s»
  PAD_HELD = 1960855917,                           -- crc32("CMND_UTIL_PAD_HELD") (mask) -> seconds held, -1 / false
  PAD_MASK = 4096,                                 -- the pad's Y (CMD_FUNC3)
  RING = 4275388294,                               -- layer cr_skill_table_hold
  GUIDE_ENTRY = 1,                                 -- «Restablecer» (Aceptar 0)
}

-- the hold prompt, declared on first use (the framework's Lua may load after this chunk); false = no framework
function PL.HoldDeclare()
  local F = VRFW_FooterPrompts
  if F == nil or F.AddHold == nil then
    return false
  end
  if F.holds[PL.HOLD.NAME] == nil then
    F.AddHold({
      Name = PL.HOLD.NAME,
      Ring = PL.HOLD.RING,
      Icon = PL.I_FUNC3,
      Entry = PL.HOLD.GUIDE_ENTRY,
      Seconds = PL.HOLD.SECONDS,
      HeldSeconds = function()
        local ok, seconds = pcall(funcLuaCommand, PL.HOLD.PAD_HELD, PL.HOLD.PAD_MASK)
        return (ok and type(seconds) == "number") and seconds or nil
      end,
      Pressed = function()
        return PL.Key(PL.K_FUNC3) == true
      end,
      Menus = function()
        return {n12 or 0, EVT_MENU or 0}
      end,
      OnHeld = function()
        funcLuaCommand(C.SE, SE_DECIDE)
      end,
    })
  end
  return true
end

-- "reset" (a tap) or "remove" (held); a row with nothing to remove answers "reset" at once
function PL.TapOrHold(removable)
  if EVT_CPK ~= nil and EVT_CPK.YHold ~= nil then
    return EVT_CPK.YHold(removable)              -- Inazuma Fantasy's block: its own timer and ring
  end
  if not removable or not PL.HoldDeclare() then
    return "reset"
  end
  local held = VRFW_FooterPrompts.WaitHold(PL.HOLD.NAME)
  local result = held == "held" and "remove" or "reset"
  pcall(UpdateEquipItemInfo)                       -- the guide line again
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "V", result)
  return result
end
-- ===== V tap / hold END =====

-- ===== unlimited copies BEGIN =====
-- Unlimited copies (VR-Framework VRFW_Copies, docs/framework/unlimited-copies.md): while a rule a mod declares holds for
-- an item, one owned copy serves every player. The equip below hands the move a handle the retail way (one copy added,
-- placed, removed again); when every copy was already in use the removal is refused and the owned count grows. The
-- wrapper notes the owned count of the picked item and of every item on this player's board (a swap or a restore can
-- move them) and brings back any unlimited item whose count grew. Without a holding rule nothing changes. No new chunk
-- local (the chunk is close to the 200-locals limit): the state is in PL.
PL.CopiesPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if type(VRFW_Copies) ~= "table" then
    return PL.CopiesPrevEquip(row, skill, inv_hint, cur)
  end
  local okS, before = pcall(function()
    local ids = {EVT_U32(skill)}
    for b = 0, 8 do
      ids[#ids + 1] = (EVT_BoardSkill(b))
    end
    return VRFW_Copies.Snapshot(ids)
  end)
  if not okS or next(before) == nil then
    return PL.CopiesPrevEquip(row, skill, inv_hint, cur)
  end
  PL.CopiesPrevEquip(row, skill, inv_hint, cur)    -- not inside a pcall: it may yield (messages)
  local okR, err = pcall(VRFW_Copies.Restore, before, function(id)
    for b = 0, 8 do
      local s, h = EVT_BoardSkill(b)
      if s == id and h ~= nil and h ~= 0 then
        return h
      end
    end
    return nil
  end)
  if not okR then
    pcall(funcLuaCommand, C.EVT_LOG, "unlimited_copies", "restore error", tostring(err))
  end
end

PL.CopiesPrevOnInit = OnInit
function OnInit(...)
  if type(VRFW_Copies) == "table" then
    pcall(VRFW_Copies.Reset)                       -- a key item won since the last visit counts now
  end
  return PL.CopiesPrevOnInit(...)
end
-- ===== unlimited copies END =====

-- ===== Fantasy slot fallbacks (2026-10-15) =====
-- With Character Reforged's projection (the option on Fantasy) the aura half shows board slot 8, else the first
-- keshin / totem / armour of the technique list; the mix half the stored mix, else the first Mix-Max / «Modo cambio» of
-- the list, else of the board. Owner 2026-10-15: those list / board entries are not a layer under the slot. An equip,
-- a reset or a removal on a half also takes that half's list / board entries off the board (board slot = list
-- position; the item goes back to stock, as a retail unequip), so the slot never falls back to them. Only the shown
-- player's own board; slot 8 (the aura slot itself) and the mix store are never touched here. Victory Road (no
-- projection answer): nothing changes. PL fields only (no main-chunk locals).
PL.FB_LIST_BOARD_SLOTS = 8                    -- board slots 0..7 (8 is the aura slot)
function PL.FbWanted(half, id)
  if id == nil or id == 0 then
    return false
  end
  local kind = PL.HsKind(id)
  if half == "mix" then
    return kind == 1
  end
  return kind == 0 or kind == 2
end

-- the board slots holding a fallback of `half`: the list positions with such a move, and (mix half) any board slot
function PL.FbSources(half)
  local out, seen = {}, {}
  for p = 0, EVT_NORMAL_NUM - 1 do
    local id = EVT_ListSkill(p)
    if PL.FbWanted(half, id) then
      out[#out + 1] = {slot = p, id = id}
      seen[p] = true
    end
  end
  if half == "mix" then
    for b = 0, PL.FB_LIST_BOARD_SLOTS - 1 do
      local id = EVT_BoardSkill(b)
      if not seen[b] and PL.FbWanted(half, id) then
        out[#out + 1] = {slot = b, id = id}
      end
    end
  end
  return out
end

-- the board service of the fallback clear: Inazuma Fantasy's board commands, else Character Reforged's own
-- (scripts\board_slots.lua, any board slot 0..8, the same arguments and answers); one of them, never both
function PL.FbBoardWritable()
  return EVT_HasBoard() or PL.HasService("aura_slot")
end
-- clear one board slot (keepOpen mode 1: the placed item off; 3: the native item off too) -> status
function PL.FbBoardClear(slot, mode)
  if EVT_HasBoard() then
    return EVT_Call(C.EVT_CLEAR, n, slot, mode)
  end
  local ok, st = pcall(funcLuaCommand, PL.CR_BOARD[C.EVT_CLEAR], n, slot, mode)
  return ok and st or nil
end

-- the technique a list position takes when its aura leaves: its board cell's technique, else the learnset move of that
-- slot (learned by level); never an aura, never a move already in the list. None: the position is emptied.
function PL.FbRefill(pos)
  local function usable(m)
    if m == nil or m == 0 or PL.IsSpecialCached(m) then
      return false
    end
    local at = funcLuaCommand(C.SKILL_POS, n, m)
    return not (at ~= nil and at >= 0 and at < EVT_NORMAL_NUM)
  end
  local m = PL.BoardTechniqueAt(pos)
  if not usable(m) then
    local ls = PL.Learnset()
    m = ls.skill[pos + 1] or 0
    local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
    if (ls.lv[pos + 1] or 0) > lv then
      m = 0
    end
  end
  if usable(m) then
    funcLuaCommand(C.SET_SKILL, n, m, pos)
    if EVT_ListSkill(pos) == EVT_U32(m) then
      return m
    end
  end
  funcLuaCommand(C.REMOVE_SKILL, n, pos)
  return 0
end

-- take the fallbacks of `half` off the board -> how many slots were cleared. A keshin, totem or armour of the list
-- goes entirely (owner 2026-10-15: armours too): the placed item, then the native one, then its list position.
function PL.FbClear(half, why)
  if PL.readonly or n == nil or n == 0 or EVT_IsPrime() or not PL.FbBoardWritable() or not PL.HS_ON then
    return 0
  end
  local okp, proj = pcall(PL.CrProjection)
  if not okp or proj == nil then
    return 0
  end
  local cleared = 0
  for _, s in ipairs(PL.FbSources(half)) do
    local st = PL.FbBoardClear(s.slot, 1)
    if EVT_BoardSkill(s.slot) == s.id then
      st = PL.FbBoardClear(s.slot, 3)          -- a native move: taken off too
    end
    local left = EVT_BoardSkill(s.slot)
    local listed = EVT_ListSkill(s.slot) == s.id
    if listed then
      PL.FbRefill(s.slot)
      listed = EVT_ListSkill(s.slot) == s.id
    end
    local gone = left ~= s.id and not listed
    if gone then
      cleared = cleared + 1
    end
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "fantasy fallback", why, half, string.format("%08X", EVT_U32(n)),
      "board slot", s.slot, EVT_Name(s.id), "clear status", tostring(st), EVT_HasBoard() and "IF board" or "CR board",
      gone and "removed" or "still there")
  end
  return cleared
end

PL.FbPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  local r = PL.FbPrevEquip(row, skill, inv_hint, cur)   -- not inside a pcall: it may yield (messages)
  if row == 0 and skill ~= nil and skill ~= 0 and r ~= false then
    local okk, kind = pcall(PL.HsKind, skill)
    local half = (okk and kind == 1) and "mix" or ((okk and (kind == 0 or kind == 2)) and "aura" or nil)
    local placed = half == "mix" and PL.HsMix() == EVT_U32(skill) or (half == "aura" and EVT_Skill(0) == EVT_U32(skill))
    if placed then
      local ok, cleared = pcall(PL.FbClear, half, "equip")
      if ok and cleared > 0 then
        pcall(EVT_AfterChange)
      end
    end
  end
  return r
end

PL.FbPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if row ~= 0 or not PL.HS_ON then
    return PL.FbPrevRestore(row)
  end
  local mix = PL.HsMix()
  local aura_half = PL.hs_half == 0 or mix == 0
  local okp, proj = pcall(PL.CrProjection)
  -- the aura half shows a list fallback and its own slot is empty: the removal is the fallback's
  if aura_half and okp and proj ~= nil and EVT_Skill(0) == 0 and #PL.FbSources("aura") > 0 then
    local ok, cleared = pcall(PL.FbClear, "aura", "remove")
    funcLuaCommand(C.SE, (ok and cleared > 0) and SE_REMOVE or SE_NG)
    pcall(EVT_AfterChange)
    EVT_FocusRow(0)
    return
  end
  local r = PL.FbPrevRestore(row)
  local ok, cleared = pcall(PL.FbClear, aura_half and "aura" or "mix", "reset / remove")
  if ok and cleared > 0 then
    pcall(EVT_AfterChange)
  end
  return r
end
-- the Hiper row can be emptied by Eliminar (hold) when a half shows something, its own slot or a fallback
function PL.RowRemovable(row)
  if row ~= 0 or not PL.HS_ON then
    return false
  end
  local okS, aura, mix = pcall(PL.CrShownSlots)
  return okS and ((aura or 0) ~= 0 or (mix or 0) ~= 0)
end

-- Restablecer (tap) on the aura half with its own slot empty: a shown list fallback goes as with Eliminar; nothing to
-- restore and nothing shown: the error sound, no board write
PL.FbPrevReset = PL.BaseResetCoroutine
function EVT_ResetCoroutine(row)
  if row ~= 0 or not PL.HS_ON or EVT_Skill(0) ~= 0 or (PL.hs_half == 1 and PL.HsMix() ~= 0) then
    return PL.FbPrevReset(row)
  end
  local okp, proj = pcall(PL.CrProjection)
  if okp and proj ~= nil and #PL.FbSources("aura") > 0 then
    return EVT_RestoreCoroutine(0)
  end
  local okk, kit = pcall(PL.ResetKit, 0)
  if okk and (kit or 0) == 0 then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  return PL.FbPrevReset(row)
end
-- ===== Fantasy slot fallbacks END =====
