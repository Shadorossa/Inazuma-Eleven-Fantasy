-- VRFW › team synergies declared by mods: the synergy list's detail panel (team16_02_synergy_item_detail): the game
-- draws it in UpdateItemEquipMenu, then VRFW_Synergy.ApplyPanel (lua\synergy\_all\30_synergy_rows.lua) dresses the
-- rows of a declared synergy; OnOpenLayer tells it an extra layer's instance is built, Step places the extras while
-- they show. No engine call at load time.

local S = VRFW_Synergy
if S == nil or S.ApplyPanel == nil then return end
local CMD_ITEM_OF_INV = 2662166687         -- (inventory handle, 0) -> the item id (the retail script's own call)

local function item_of(inv)
  if type(inv) ~= "number" or inv == 0 then return 0 end
  local ok, it = pcall(funcLuaCommand, CMD_ITEM_OF_INV, inv, 0)
  if ok and type(it) == "number" then return it end
  return 0
end

S.list = S.list or {}
local W = S.list

-- UpdateItemEquipMenu(inv): the focused synergy's detail (the game draws it in the same call)
if type(UpdateItemEquipMenu) == "function" and UpdateItemEquipMenu ~= W.UpdateItemEquipMenu then
  local orig = UpdateItemEquipMenu
  W.UpdateItemEquipMenu = function(a1, ...)
    local r = orig(a1, ...)
    local ok, e = pcall(S.ApplyPanel, item_of(a1))
    if not ok and S.err == nil then S.err = tostring(e) end
    return r
  end
  UpdateItemEquipMenu = W.UpdateItemEquipMenu
end

-- OnOpenLayer: the extra layers' instances (the retail one runs first)
if OnOpenLayer ~= W.OnOpenLayer then
  local orig = OnOpenLayer
  W.OnOpenLayer = function(a1, a2, ...)
    local r
    if type(orig) == "function" then r = orig(a1, a2, ...) end
    pcall(S.Built, a1, a2)
    return r
  end
  OnOpenLayer = W.OnOpenLayer
end

-- Step (looked up by name each frame; the retail script has none of its own, an include's is kept)
if Step ~= W.Step then
  local orig = Step
  W.Step = function(...)
    local r
    if type(orig) == "function" then r = orig(...) end
    pcall(S.Tick)
    return r
  end
  Step = W.Step
end
