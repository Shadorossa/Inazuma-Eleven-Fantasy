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

local CMD_LIST_COUNT = 2389020234         -- (list layer) -> its entries (the retail OnChangeFocus's own call)
local LIST = 1986515389                    -- team05_03_synergy_list
local TAB = 4044286600                     -- cmn06_20_list_tab_item

-- UpdateItemEquipMenu(inv): the focused synergy's detail. The list calls it every frame; the game draws the detail only
-- when the entry differs from the one it shows (its own guard returns at once otherwise), so the rows are dressed only
-- then: dressing them every frame put each row back to the game's look and hid its parts again (blinking faces)
if type(UpdateItemEquipMenu) == "function" and UpdateItemEquipMenu ~= W.UpdateItemEquipMenu then
  local orig = UpdateItemEquipMenu
  W.UpdateItemEquipMenu = function(a1, ...)
    local drawn = W.shown_inv == nil or a1 ~= W.shown_inv
    W.shown_inv = a1
    local r = orig(a1, ...)
    if drawn then
      local ok, e = pcall(S.ApplyPanel, item_of(a1))
      if not ok and S.err == nil then
        S.err = tostring(e)
        pcall(funcLuaCommand, VRFW_Cmd.EVT_LOG, "VRFW synergy panel: error", S.err)
      end
    end
    return r
  end
  UpdateItemEquipMenu = W.UpdateItemEquipMenu
end

-- OnChangeFocus on the tabs: another tab's list. The game draws the detail of its next focused entry again; an empty
-- list gets an empty detail at once (the rows' extra pieces off)
if type(OnChangeFocus) == "function" and OnChangeFocus ~= W.OnChangeFocus then
  local orig = OnChangeFocus
  W.OnChangeFocus = function(a1, ...)
    local r = table.pack(orig(a1, ...))
    if a1 == TAB then
      W.shown_inv = nil
      local ok, n = pcall(funcLuaMenuCommand, CMD_LIST_COUNT, LIST)
      if ok and n == 0 then
        W.shown_inv = 0
        pcall(S.ApplyPanel, 0)
      end
    end
    return table.unpack(r, 1, r.n)
  end
  OnChangeFocus = W.OnChangeFocus
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
