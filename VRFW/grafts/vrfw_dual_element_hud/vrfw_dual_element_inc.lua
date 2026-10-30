-- VRFW vrfw_dual_element_hud: the versus HUDs show EVERY element of a dual-element
-- move ([edit.VRFW.DualElement] of the technique type) side by side: icon 1 | icon 2 | …, every icon at the retail
-- size. Wraps the shared include functions every versus HUD calls:
--   SetupVsElementIconLayerMenu(layer, index, type, chara, skill): instance 1 = the move's icon; instances 2-4 = the
--     extra icons the framework's menus\dual_element_hud.toml adds (hung on the same locator). A dual move of n
--     elements: n icons of the retail size, VRFW_DualElementPitch apart (icon width + gap), left to right in the move's
--     element order, same vertical centre. The row grows toward the HUD's centre, the side with nothing on it (the
--     character's element icon and the portrait sit on the outer side): the enemy's row grows to the LEFT from the
--     retail move icon, which stays in place; the own row (left half of the HUD) grows to the right and the retail
--     move icon moves to the row's right end. Either way instance 1 is the rightmost, so its compatibility arrow (hung
--     on it) stays at the row's top-right. Other moves: retail, extra instances hidden;
--   UpdateVsElementIconCompatibilityArrow(layer, index, type, chara, skill, echara, eskill): type 1 = the moves'
--     arrow; when either move is dual the arrow follows the framework's stacked wheel (flag 1 = shown); the extra
--     arrows (instances 2-4) are always hidden.
-- Elements: CMND_VRFW_TECHNIQUE_ELEMENTS(actorHandle, skill) -> n, e1..e4 (n < 2 = no dual element: retail drawing);
-- wheel: CMND_VRFW_ELEMENT_WHEEL(a1..a4, d1..d4) -> flag, steps (VR-Framework technique engine).
-- Sizes in the icon's own units: the retail icon frame _icon_type_base01 of soccer01_06_p1.g4pkm is 44 x 44 around
-- the locator. Globals only; engine calls only from the wrapped functions, every call through pcall.
VRFW_DualElementPitch = 46             -- icon width (44) + gap (2): each icon keeps its own frame (the separator)
VRFW_DualElementMax = 4                -- icons per row (instance 1 + the 3 extra instances)
VRFW_DualElementEnemyLayer = 222949092 --[[soccer01_06_p1_element_icon_enemy]]
VRFW_DualElementCmd = @crc:CMND_VRFW_TECHNIQUE_ELEMENTS@
VRFW_DualElementWheelCmd = @crc:CMND_VRFW_ELEMENT_WHEEL@

local function VRFW_DualElementMenu(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return false
  end
  local r = table.pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then
    return false
  end
  return table.unpack(r, 2, r.n)
end

-- the move's elements for this executor (a list of 2-4), nil = no dual element (retail)
function VRFW_DualElementList(chara, skill)
  if type(funcLuaCommand) ~= "function" or chara == nil or skill == nil or skill == 0 then
    return nil
  end
  local ok, n, e1, e2, e3, e4 = pcall(funcLuaCommand, VRFW_DualElementCmd, chara, skill)
  if not ok or type(n) ~= "number" or n < 2 then
    return nil
  end
  local l = {}
  for _, e in ipairs({e1, e2, e3, e4}) do
    if #l < n and #l < VRFW_DualElementMax and type(e) == "number" and e > 0 then
      l[#l + 1] = e
    end
  end
  if #l < 2 then
    return nil
  end
  return l
end

-- the move's table element (retail CMND_GET_SOCCER_SKILL_INFO, field 7) as a one-element list
local function VRFW_DualElementTable(skill)
  if skill == nil or skill == 0 or type(funcLuaCommand) ~= "function" then
    return {}
  end
  local ok, _, e = pcall(funcLuaCommand, @crc:CMND_GET_SOCCER_SKILL_INFO@, skill, 7)
  if ok and type(e) == "number" and e > 0 then
    return {e}
  end
  return {}
end

local function VRFW_DualElementSetIcon(layer, index, e)
  local icon = 0
  if type(GetElementIcon) == "function" then
    local ok, v = pcall(GetElementIcon, e)
    if ok and v ~= nil then
      icon = v
    end
  end
  if icon == 0 then
    return
  end
  VRFW_DualElementMenu(558735651, layer, 502529699 --[[#/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx]], icon, 3530469477 --[[icon_type_dmy02]], 0, index)
end

-- place one instance at row position k (0-based, left to right) of n, retail size, same y: relative to the retail
-- move icon's place, the enemy's row ends there (grows left), the own row starts there (grows right)
local function VRFW_DualElementPlace(layer, index, k, n)
  local x = (k - (n - 1)) * VRFW_DualElementPitch
  if layer ~= VRFW_DualElementEnemyLayer then
    x = k * VRFW_DualElementPitch
  end
  VRFW_DualElementMenu(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, x, 0, 0, index)
end

local function VRFW_DualElementReset(layer, index)
  VRFW_DualElementMenu(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, 0, 0, 0, index)
end

local VRFW_DualElementPrevIcon = SetupVsElementIconLayerMenu
function SetupVsElementIconLayerMenu(a1, a2, a3, a4, a5, ...)
  local extra = type(a2) == "number" and a2 >= 2
  local l
  if extra or a3 == 1 then
    local ok, v = pcall(VRFW_DualElementList, a4, a5)
    if ok then
      l = v
    end
  end
  local r = {n = 0}
  if type(VRFW_DualElementPrevIcon) == "function" then
    if extra and l ~= nil and a2 <= #l then
      -- an extra icon of a dual move: drawn as the move's icon (type 1), then given its element below
      r = table.pack(VRFW_DualElementPrevIcon(a1, a2, 1, a4, a5, ...))
    else
      r = table.pack(VRFW_DualElementPrevIcon(a1, a2, a3, a4, a5, ...))
    end
  end
  pcall(function()
    if extra then
      if l == nil or a2 > #l then
        VRFW_DualElementMenu(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, false)
        return
      end
      -- instances 2..n = row positions 0..n-2 (elements 1..n-1)
      VRFW_DualElementSetIcon(a1, a2, l[a2 - 1])
      VRFW_DualElementPlace(a1, a2, a2 - 2, #l)
      return
    end
    if a3 ~= 1 then
      return -- type 0 = the character's element icon
    end
    if l == nil then
      VRFW_DualElementReset(a1, a2)
      return
    end
    -- instance 1 = the rightmost: the last element
    VRFW_DualElementSetIcon(a1, a2, l[#l])
    VRFW_DualElementPlace(a1, a2, #l - 1, #l)
  end)
  return table.unpack(r, 1, r.n)
end

local VRFW_DualElementPrevArrow = UpdateVsElementIconCompatibilityArrow
function UpdateVsElementIconCompatibilityArrow(a1, a2, a3, a4, a5, a6, a7, ...)
  local r = {n = 0}
  if type(VRFW_DualElementPrevArrow) == "function" then
    r = table.pack(VRFW_DualElementPrevArrow(a1, a2, a3, a4, a5, a6, a7, ...))
  end
  pcall(function()
    if type(a2) == "number" and a2 >= 2 then
      VRFW_DualElementMenu(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, false)
      return -- the extra icons' arrows: never shown
    end
    if a3 ~= 1 then
      return -- the characters' arrow: retail
    end
    local mine = VRFW_DualElementList(a4, a5)
    local theirs = VRFW_DualElementList(a6, a7)
    if mine == nil and theirs == nil then
      return
    end
    mine = mine or VRFW_DualElementTable(a5)
    theirs = theirs or VRFW_DualElementTable(a7)
    local ok, flag = pcall(funcLuaCommand, VRFW_DualElementWheelCmd, mine[1] or 0, mine[2] or 0, mine[3] or 0, mine[4] or 0, theirs[1] or 0, theirs[2] or 0, theirs[3] or 0, theirs[4] or 0)
    if ok and type(flag) == "number" then
      VRFW_DualElementMenu(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2, flag == 1)
    end
  end)
  return table.unpack(r, 1, r.n)
end
