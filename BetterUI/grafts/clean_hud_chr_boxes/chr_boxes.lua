-- Clean HUD «Modo Crónica» icon boxes (graft clean_hud_chr_boxes; docs/game/ui/competition-menu.md §2). Moved from
-- Inazuma Fantasy's chronicle_boxes on 2026-10-09 (Nacho: the square boxes under the «Universo del jugador» gacha
-- banner belong to Clean HUD): the same wrappers under Clean HUD's names (layer clean_hud_chr_box, its "!" layer
-- clean_hud_chr_box_notice, atlas clean_hud_chr_box.g4tx; data research/scripts/clean_hud_chr_boxes_build.py and
-- menus/chronicle_boxes.toml).
-- «Cadena de Crónica» and «Universo del jugador» stay rows; «Plantilla de equipo», «Objetos», «Tienda» and «Opciones»
-- become 4 square boxes under them. «Ayuda» and «Guardar» stay created as the 2 small rows but sit off screen with no
-- key reaching them (the boxes have no DOWN row, «Cadena de Crónica» up wraps to box 0), as Inazuma Fantasy had them.
-- Wrappers only: the retail chunk keeps t = {1, 2, 0, 3, 4, 5, 6, 7}. The globals GetLitItemInfo / GetNumUsedButtons /
-- UpdateContentGuide map small item 0 / 1 to the retail «Ayuda» / «Guardar» entries; the boxes read the other four
-- entries (label, help text, icons, menu, autosave) from the same retail table, so the retail WaitExecOtherMenu opens
-- them exactly like the rows did (Tienda: the shop the retail row opens; Inazuma Fantasy's shop_rework swaps it).
-- Keys: «Universo del jugador» down lands on box 0 (setting focus shift), left / right move between the boxes (engine
-- list focus), up -> «Universo del jugador» (CMD_FUNCTION clean_hud_chr_box_up, retail ChangeFocusToNextLayer).
-- Without the data (small list still creates 7 items) every wrapper passes through. The corner buttons «V Guía de
-- controles» / «Alt Tutorial» are hidden by graft clean_hud_menu_cleanup.
local CHR_LAYER = 1676790659 --[[crc32("clean_hud_chr_box")]]
local CHR_NOTICE = 791190873 --[[crc32("clean_hud_chr_box_notice")]]
local CHR_TEX = 335196450 --[[crc32("#/menu/100_mainmenu/mainmenu90/clean_hud_chr_box/clean_hud_chr_box.g4tx")]]
local CHR_FN_UP = 2603296165 --[[crc32("clean_hud_chr_box_up")]]
local CHR_SMALL = 530619243 --[[mainmenu90_12_list_item_small]]
local CHR_MIDDLE = 4042532538 --[[mainmenu90_11_chronicle_top_list_item_middle]]
local CHR_GUIDE = 3078308064 --[[mainmenu90_05_content_guide_line01]]
local CHR_CURSOR = 3313461902 --[[cursor]]
local CHR_NEWICON = 1108398278 --[[attach name of the "!" in the small row objbin]]
local CHR_ACTIVE = 1286797620 --[[Active]]
local CHR_BUTTON = 973515837 --[[button]]
local CHR_N = 4
-- the menus of the 4 boxes, in box order: Plantilla de equipo, Objetos, Tienda, Opciones
local CHR_BOX_OBJ = {
  937147172 --[[soccer_team_dock_menu]],
  3518667992 --[[item_menu_soccer]],
  3170360552 --[[shop_menu]],
  1936716961 --[[setting_top_menu]]
}
-- the retail texts the "!" of a box depends on (buttonTextName of Plantilla de equipo / Objetos / Tienda)
local CHR_TXT_TEAM = 2074787642
local CHR_TXT_ITEMS = 1059912976
local CHR_TXT_SHOP = 2306819683
local CHR_SHOP_RETAIL = 1314944986 -- the retail Crónica shop (WaitExecOtherMenu's shop_menu prop)
local CHR_LABEL_COLOR = "[CY]" -- colour tag of the label in the help line ("" = plain)
-- kill switch: false = retail behaviour (the boxes stay inert). Inazuma Fantasy's own chronicle_boxes yields while this
-- global is set.
CLEAN_HUD_CHR_BOXES = true
local chr_focus = 0
local chr_prev = 0
local chr_map = nil

local CHR_LOG_N = 0
local function ChrLog(...)
  if CHR_LOG_N >= 40 then
    return
  end
  CHR_LOG_N = CHR_LOG_N + 1
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT clean_hud chr_boxes " .. table.concat(parts, " "))
end

local prev_GetLitItemInfo = GetLitItemInfo
local prev_GetNumUsedButtons = GetNumUsedButtons
local prev_UpdateContentGuide = UpdateContentGuide

-- retail small-list order (t) -> box k = index of the entry whose menu is CHR_BOX_OBJ[k]; rows = the others
local function ChrMap()
  if chr_map ~= nil then
    return chr_map
  end
  local box, rows = {}, {}
  local total = prev_GetNumUsedButtons(CHR_SMALL)
  for i = 0, total - 1 do
    local info = prev_GetLitItemInfo(CHR_SMALL, i)
    local k = nil
    for b = 1, CHR_N do
      if info ~= nil and info.menuObjectName == CHR_BOX_OBJ[b] then
        k = b
      end
    end
    if k ~= nil then
      box[k] = i
    else
      rows[#rows + 1] = i
    end
  end
  chr_map = {box = box, rows = rows, nmid = prev_GetNumUsedButtons(CHR_MIDDLE)}
  ChrLog("map rows", #rows, "boxes", box[1], box[2], box[3], box[4])
  return chr_map
end

-- on only with the data (menus/chronicle_boxes.toml): the small list then creates exactly the row items (2)
local function ChrActive()
  if not CLEAN_HUD_CHR_BOXES then
    return false
  end
  local m = ChrMap()
  return funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, CHR_SMALL) == #m.rows
end

local function ChrInfo(k)
  local o = ChrMap().box[k + 1]
  if o == nil then
    return nil
  end
  return prev_GetLitItemInfo(CHR_SMALL, o)
end

function GetLitItemInfo(a1, a2)
  if a1 == CHR_SMALL and ChrActive() then
    local o = ChrMap().rows[a2 + 1]
    if o == nil then
      return nil
    end
    return prev_GetLitItemInfo(a1, o)
  end
  return prev_GetLitItemInfo(a1, a2)
end

function GetNumUsedButtons(a1)
  if a1 == CHR_SMALL and ChrActive() then
    return #ChrMap().rows
  end
  return prev_GetNumUsedButtons(a1)
end

function UpdateContentGuide(a1)
  if ChrActive() then
    local m = ChrMap()
    if a1 >= m.nmid then
      local o = m.rows[a1 - m.nmid + 1]
      if o ~= nil then
        return prev_UpdateContentGuide(m.nmid + o)
      end
    end
  end
  return prev_UpdateContentGuide(a1)
end

local function ChrGuide(k)
  local info = ChrInfo(k)
  if info == nil then
    return
  end
  local label = funcLuaCommand(@crc:CMND_TEXT_GET@, info.buttonTextName) or ""
  local desc = funcLuaCommand(@crc:CMND_TEXT_GET@, info.explanationTextName) or ""
  local text = label .. ": " .. desc
  if CHR_LABEL_COLOR ~= "" then
    text = CHR_LABEL_COLOR .. label .. ":[C] " .. desc
  end
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, CHR_GUIDE, 378156699 --[[_text_guide01]], text, 0)
end

local function ChrSetup(a1, a2)
  if a2 == 0 then
    funcLuaMenuCommand(3252599449, a1, CHR_N)
    ChrLog("setup", CHR_N)
  end
  local info = ChrInfo(a2)
  if CHR_N <= a2 or info == nil then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, false)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, CHR_CURSOR, false)
    return 1
  end
  -- no caption on the box: the label goes to the help line
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 931545948 --[[_text_list01_on]], "", a2)
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, a1, 3705682548 --[[_text_list01_off]], "", a2)
  funcLuaMenuCommand(558735651, a1, CHR_TEX, info.listItemOnTextureName, 2880627768 --[[list_icon_dmy_s01_on]], 0, a2)
  funcLuaMenuCommand(558735651, a1, CHR_TEX, info.listItemOnTextureName, 3688370359 --[[list_icon_dmy_s01_ok]], 0, a2)
  funcLuaMenuCommand(558735651, a1, CHR_TEX, info.listItemOffTextureName, 2527308690 --[[list_icon_dmy_s01_off]], 0, a2)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, CHR_CURSOR, false)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, CHR_NEWICON, true)
end

-- the blue "!" of the retail rows (UpdateListItemNewIcon), per box
local function ChrNotice(k)
  local info = ChrInfo(k)
  local on = false
  if info ~= nil then
    local b = info.buttonTextName
    if b == CHR_TXT_TEAM then
      if type(SearchHaveNewItemForTeamdockAbilityList) == "function" then
        on = SearchHaveNewItemForTeamdockAbilityList()
      end
      if not on then
        local _, f = funcLuaCommand(@crc:CMND_GET_SPIRIT_INFO@, 0, 0)
        on = f
      end
    elseif b == CHR_TXT_ITEMS then
      on = funcLuaCommand(917126939, 0, 18)
    elseif b == CHR_TXT_SHOP then
      -- the shop the button opens: a mod's swap (Inazuma Fantasy shop_rework: EVT_SRW_CHRONICLE_SHOP), else retail
      on = funcLuaMenuCommand(1862518458, rawget(_ENV, "EVT_SRW_CHRONICLE_SHOP") or CHR_SHOP_RETAIL)
    end
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, CHR_NOTICE, k, on and true or false)
end

local function ChrFocusVisual(a1, ret)
  funcLuaMenuCommand(1778826357, a1, ret, true)
  if chr_prev ~= ret then
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, chr_prev, CHR_ACTIVE, 2, CHR_BUTTON)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, chr_prev, CHR_CURSOR, false)
  end
  funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, ret, CHR_ACTIVE, 0, CHR_BUTTON)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, ret, CHR_CURSOR, true)
  funcLuaMenuCommand(@crc:CMND_SET_CURSOR_LOCATOR@, a1, CHR_CURSOR, ret, CHR_N)
  chr_prev = ret
  chr_focus = ret
  ChrGuide(ret)
end

-- up from the boxes: the retail helper of the corner buttons (ChangeFocusToNextLayer), then the engine calls
-- OnChangeFocus of the list, which updates its visuals and the help line
local function ChrLeave(target, idx)
  local i = funcLuaMenuCommand(2603265800, CHR_LAYER)
  if type(i) ~= "number" or i < 0 or i >= CHR_N then
    i = chr_focus
  end
  chr_focus = i
  ChangeFocusToNextLayer(CHR_LAYER, i, target, idx)
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2500047763 --[[sy0005]])
  ChrLog("leave box", i, "->", target, idx)
end

-- ENTER on a box: the retail OnDecideFocus path of that entry (WaitExecOtherMenu), then the focus back on the box
local function ChrDecide(a1, a2)
  local info = ChrInfo(a2)
  if info == nil then
    return
  end
  chr_focus = a2
  ChrLog("decide box", a2, "menu", info.menuObjectName)
  funcLuaCommand(2565779025, 207055258, 0)
  funcLuaCommand(@crc:CMND_SET_TEMP_BYTE_FLAG@, 2502072435, 0)
  WaitExecOtherMenu(info.menuObjectName, a1, info.mainMenuType, info.isAutoSaveEnabled)
  -- WaitExecOtherMenu gives the focus back to the item of the last list row (n3): move it to the decided box
  for i = 0, CHR_N - 1 do
    if i ~= a2 then
      funcLuaMenuCommand(1778826357, a1, i, false)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, i, CHR_CURSOR, false)
    end
  end
  chr_prev = a2
  ChrFocusVisual(a1, a2)
end

local prev_OnSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == CHR_LAYER and ChrActive() then
    local r = ChrSetup(a1, a2)
    prev_OnSetupLayer(a1, a2) -- retail: nothing for this layer except the menu-skip hide
    return r
  end
  if a1 == CHR_NOTICE and ChrActive() then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, false)
    return prev_OnSetupLayer(a1, a2)
  end
  return prev_OnSetupLayer(a1, a2)
end

local prev_OnOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == CHR_LAYER and ChrActive() then
    local r = prev_OnOpenLayer(a1, a2)
    if a2 < CHR_N then
      ChrNotice(a2)
    end
    return r
  end
  return prev_OnOpenLayer(a1, a2)
end

local prev_OnChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  if a1 == CHR_LAYER and ChrActive() then
    if not funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, a1) then
      return
    end
    local ret = funcLuaMenuCommand(2603265800, a1)
    if type(ret) ~= "number" or ret < 0 or ret >= CHR_N then
      return
    end
    ChrFocusVisual(a1, ret)
    return
  end
  return prev_OnChangeFocus(a1, a2)
end

local prev_OnDecideFocus = OnDecideFocus
function OnDecideFocus(a1, a2)
  if a1 == CHR_LAYER and ChrActive() then
    return ChrDecide(a1, a2)
  end
  return prev_OnDecideFocus(a1, a2)
end

local prev_OnFunction = OnFunction
function OnFunction(a1, a2)
  if a1 == CHR_FN_UP and ChrActive() then
    return ChrLeave(CHR_MIDDLE, ChrMap().nmid - 1)
  end
  return prev_OnFunction(a1, a2)
end
