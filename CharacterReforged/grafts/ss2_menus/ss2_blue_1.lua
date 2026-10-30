
-- ===================================================================================================
-- EVT skill slots, try 27: "Pasiva personalizada" picker. Appended by research/scripts/ss2_build.py to the decompiled
-- retail ability_list_menu_on_bluebg_5.00.29.00 (the board's own picker group: the retail "Elige una pasiva
-- personalizada que equiparte" screen with the six-sense items, owned/equipped counters).
-- evt_skill_slot_menu opens this group with the board's parameters (4161869490 = character, 1498333934 = 200 = six
-- sense) plus our evt_ss_pick_used = 3. The retail commit is native and writes into the OPEN BOARD MENU (looked up
-- by id; with no board menu open the lookup is null-checked and nothing happens), so here the confirmed item and its
-- invSkill handle are handed back through the parameter store (numbers only) and the slot screen equips it with
-- CMND_EVT_SIXSENSE. Without our parameter the group behaves as retail.
-- ===================================================================================================
local EVT_KEY_PICK = 790447113
-- 2026-10-14: this block is the mod Character Reforged's (graft ss2_menus) and Inazuma Fantasy rebuilds it into its
-- own patch of this script (its aura_gates / master_seal blocks read these chunk locals), so ONE VM may run two
-- copies. Only the LAST copy acts: each wrapper of an earlier copy passes straight through to what it wrapped.
EVT_SS2_BLUE_GEN = (EVT_SS2_BLUE_GEN or 0) + 1
local EVT_BLUE_GEN = EVT_SS2_BLUE_GEN
local EVT_KEY_RESULT = 3854106930
local EVT_KEY_INV = 331123112
local EVT_LIST = 3520823522                 -- team08_01_ability_list
local evt_pick = false
local evt_inv = {}                          -- item id -> invSkill handle (rows seen)
local evt_focus = 0                         -- focused item id (SendSkillIdToLua)

--@lib evt_menu_kit.lua#EVT_U32

local function EVT_PSet(key, v)
  VRFW_Param.Clear(key)
  VRFW_Param.Set(key, v)
end

local EVT_RetailOnInit = OnInit
function OnInit()
  if EVT_SS2_BLUE_GEN ~= EVT_BLUE_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailOnInit()
  end
  evt_pick = VRFW_Param.Has(EVT_KEY_PICK) and (tonumber(VRFW_Param.Get(EVT_KEY_PICK)) == 3)
  EVT_RetailOnInit()
end

local EVT_RetailUpdateListItem = UpdateListItem
function UpdateListItem(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
  if EVT_SS2_BLUE_GEN ~= EVT_BLUE_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailUpdateListItem(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
  end
  EVT_RetailUpdateListItem(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
  if evt_pick and a3 ~= nil and a3 ~= 0 then
    local item = EVT_U32(funcLuaCommand(901208644, a3))
    if item ~= 0 then
      evt_inv[item] = EVT_U32(a3)
    end
  end
end

local EVT_RetailSendSkillIdToLua = SendSkillIdToLua
function SendSkillIdToLua(a1)
  if EVT_SS2_BLUE_GEN ~= EVT_BLUE_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailSendSkillIdToLua(a1)
  end
  evt_focus = EVT_U32(a1)
  EVT_RetailSendSkillIdToLua(a1)
end

local EVT_RetailOnEnter = OnEnter
function OnEnter(a1, a2)
  if EVT_SS2_BLUE_GEN ~= EVT_BLUE_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailOnEnter(a1, a2)
  end
  if evt_pick and a1 == EVT_LIST and evt_focus ~= 0 then
    EVT_PSet(EVT_KEY_RESULT, evt_focus)
    EVT_PSet(EVT_KEY_INV, evt_inv[evt_focus] or 0)
  end
  EVT_RetailOnEnter(a1, a2)
end
