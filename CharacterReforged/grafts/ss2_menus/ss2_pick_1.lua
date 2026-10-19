
-- ===================================================================================================
-- EVT skill slots v2: "pick mode" for the game's hissatsu list (menu ability_list_menu, group
-- ability_list_menu = the team dock's "Técnicas" list with element/category tabs, filter and sort).
-- Appended by research/scripts/ss2_build.py to the decompiled retail ability_list_menu_5.00.29.00.
-- Pick mode is ON only when the opener set the parameter evt_ss_pick_used (evt_skill_slot_menu does);
-- otherwise every function below falls through to retail behaviour.
-- Handoff (try 7: NUMBERS ONLY - the parameter store keeps a Lua string as a raw char* into the setter's
-- lua_State (handler 0xCA6480: lua_tolstring pointer, type 3), so strings do not survive to another menu):
--   evt_ss_pick_used   = mode: 1 normal rows (category-8 moves refused), 2 special row (only category 8)
--   evt_ss_used_1..6   = move id on normal row 1..6 (0 = none / the row being edited) -> row greyed, swap
--   evt_ss_pick_result = chosen move id, evt_ss_pick_inv = its invSkill handle
--   evt_ss_dbg_init / evt_ss_dbg_enter / evt_ss_dbg_code = debug trail (mode seen at OnInit / last layer that
--   confirmed / 3 rejected, 4 chosen, 9 Lua error)
-- No chunk local of the retail script is read here (2026-10-14): a block that reads one makes the build re-declare
-- the script's locals and REDEFINE every retail function using them (OnInit, OnSetupLayer, OnChangeFocus,
-- UpdateSkillDetailWindow, OnFunction, ...), which threw away the wrappers other mods put on them before this mod's
-- patch ran (Utilities' «RS Previsualizar», graft util_tech_preview). What the block needs is followed through the
-- screen's own global calls instead (EVT_ListState below): the focused move (UpdateSkillDetailWindow), the filter key
-- of the shown tab (LoadFilterData); the button guide is the retail one with «Aceptar» added; the filter is saved by
-- the retail OnBack. Every function below wraps the global it replaces and calls it.
-- ===================================================================================================
local EVT_ListState = {
  focus = 0,                          -- the focused move (0 = none), as the retail chunk keeps it
  RetailOnBack = OnBack,              -- saves the shown tab's filter (retail), called when a pick commits
}
local EVT_KEY_PICK = 790447113
local EVT_KEY_RESULT = 3854106930
local EVT_KEY_INV = 331123112
local EVT_KEY_USED = {621880403, 3155719657, 3407824255, 1434177756, 578609226, 3145052656}
local EVT_KEY_DBG_INIT = 1463482560
local EVT_KEY_DBG_ENTER = 1978530279
local EVT_KEY_DBG_CODE = 3864734764
local EVT_KEY_DBG_BITS = 3833368827   -- try 8: which hooks fired (bitmask, see EVT_BIT)
local EVT_BIT = {FOCUS = 1, DETAIL = 2, STEP = 4, ENTER = 8, CLICK = 16, ONENTER = 32, ONDECIDE = 64, COMMIT = 128}
local evt_bits = 0
local function EVT_PSet(key, v)
  funcLuaCommand(3363400568, key)
  funcLuaCommand(3860611758, key, 0, v, 1)
end
local EVT_LIST = 571205469          -- team05_03_ability_list (native list view)
local EVT_ITEM = 1205526439         -- team08_02_ability_list_item
local evt_pick = false
local evt_used = {}                 -- skill id -> row number it occupies on the slot screen
local evt_mode = "N"
local evt_rows = {}                 -- list item instance -> skill id (from UpdateListItem)
local evt_unlimited_rows = {}       -- list item instance -> item id of a row with unlimited copies (any list mode)
local evt_inv = {}                  -- skill id -> 3rd UpdateListItem arg (try 8: this is the ITEM ID, not a handle)
local evt_free = {}                 -- skill id -> the list shows a free copy (have > equipped), board rule
local evt_sent = 0                  -- last id from SendSkillIdToLua (if the engine calls it for this group)
EVT_CR = {slot = 0, chara = 0, board = -1, seen = {}}   -- Character Reforged slot rules of the open pick (global: no new chunk local)
-- 2026-10-14: the place rules other mods declare as data ([CharacterReforged.PlaceRules.<name>]: their own game Lua
-- command, e.g. True Hissatsu's «one copy per set»), asked after Character Reforged's own rule: { {id, board}, … }
function EVT_CR_Rules()
  if EVT_CR.rules ~= nil then
    return EVT_CR.rules
  end
  local r = {pcall(funcLuaCommand, 884939394 --[[CMND_CHARACTERREFORGED_PLACE_RULES]])}
  local out = {}
  if r[1] == true and type(r[2]) == "number" then
    for i = 1, r[2] do
      if type(r[1 + 2 * i]) == "number" and r[1 + 2 * i] ~= 0 then
        out[#out + 1] = {id = r[1 + 2 * i], board = r[2 + 2 * i] == 1}
      end
    end
  end
  EVT_CR.rules = out
  return out
end
function EVT_CR_Allowed(skill)
  local okc, res = pcall(funcLuaCommand, 6717499 --[[CMND_CHARACTERREFORGED_CAN_PLACE]], EVT_CR.chara, EVT_CR.slot, skill)
  if okc and res == false then
    return false
  end
  for _, r in ipairs(EVT_CR_Rules()) do
    local a = EVT_CR.slot
    if r.board then
      a = EVT_CR.board >= 0 and EVT_CR.board or nil
    end
    if a ~= nil then
      local okr, res2 = pcall(funcLuaCommand, r.id, EVT_CR.chara, a, skill)
      if okr and res2 == false then
        return false
      end
    end
  end
  return true
end
-- 2026-09-25 miximax (docs/game/skill-slots.md "Miximax on the Hiper row"): "Crear miximax" = item wmm_evt_create
-- (first MIXIMAX entry, granted by the loader), the fusion = item wmm_evt; Eliminar (CMD_FUNC3) on the fusion entry
-- hands it back with evt_ss_pick_del set; a Prime base (evt_ss_mx_prime) gets "Crear miximax" greyed
local EVT_MX = {CREATE = 1033481313, FUSION = 2450842569, KEY_DEL = 99760714,
  KEY_PRIME = 2900901523, prime = false, KEY_FUSED = 1894840368, fused = false,
  KEY_BASE = 19616700, chara = 0, param = 0,
  -- 2026-10-06 «Modo Overdrive» (own_passives/form_fx.rs evt_eff_no_miximax): the base may not have any miximax
  -- (CMND_EVT_MX_FORBIDDEN 0xE4A32A5E): «Crear miximax», the fusion and every retail miximax row are greyed
  forbid = false,
  KEY_PCHARA = 1756901414, KEY_M1 = 2755219383, KEY_M2 = 1026563597, pchara = 0, m1 = 0, m2 = 0,
  -- 2026-09-25 (user): a retail miximax (aura type 2 row of aura_skill_config) may only be the Hiper of a COMPATIBLE
  -- player: his chara_base is the row's AURA_CMD_CHARA owner, or his chara_param is in its change_aura whitelist.
  -- skill id -> {owner chara_base ids..., whitelisted chara_param ids...} (injected by ss2_build.py from Inazuma Fantasy's data)
  COMPAT = {[140109032] = {384621588}, [594851627] = {1036095447, 2486534565}, [1416857533] = {1036095447, 2486534565}, [980387434] = {442193342, 3014613964}, [2446286018] = {442193342, 219635752}, [147197304] = {442193342, 618648794}, [1797305416] = {442193342, 1060880241}, [1965953197] = {54551807}, [1815421420] = {2002398386, 3735954112}, [476042595] = {3338449587, 1862843585}, [693197136] = {3338449587, 3518007077}, [2958559466] = {3338449587, 4168627159}, [3552489946] = {3338449587, 3818674300}, [1192784431] = {3544233345}, [1577272174] = {384621588}, [3650838433] = {2957124332}, [3229642464] = {2233078279}, [276873118] = {442193342}, [161189599] = {4189031541}, [582409500] = {1805330513}, [1001253981] = {2957124332}, [1961654938] = {1920997648}, [1844923355] = {2952080371}, [3629725078] = {516331221}, [4019579122] = {1043419128}, [64114193] = {1043419128}, [3271867022] = {441182823}, [319056880] = {3385847671}, [169826993] = {3165669688}, [199045254] = {3544233345, 2058664947}, [2798104233] = {3544233345, 3289153559}, [1070530323] = {3544233345, 3989058789}, [1546143267] = {3544233345, 4129316686}, [2094661648] = {442193342, 3014613964}, [511429068] = {442193342, 219635752}, [2272434294] = {442193342, 618648794}, [3834913094] = {442193342, 1060880241}, [552624965] = {2577514832, 810929954}, [3781678201] = {2577514832, 2397959366}, [2020509123] = {2577514832, 2804236340}, [461913331] = {2577514832, 3166776223}, [1475826643] = {442193342}, [971723268] = {3544233345, 2058664947}, [3691511241] = {3544233345, 3289153559}, [1158589555] = {3544233345, 3989058789}, [652744003] = {3544233345, 4129316686}, [1324114578] = {3338449587, 1862843585}, [1690016428] = {3338449587, 3518007077}, [4256353046] = {3338449587, 4168627159}, [2656334374] = {3338449587, 3818674300}, [1990902979] = {4189031541}, [28177493] = {54551807, 2863950477}, [3600500412] = {54551807, 336351593}, [1334974214] = {54551807, 1036314011}, [745844278] = {54551807, 639667760}, [1873933698] = {4189031541}, [414631188] = {2922856900, 130240438}, [1151116865] = {3338449587, 1862843585}, [350712505] = {3338449587, 3518007077}, [2381193987] = {3338449587, 4168627159}, [3993541171] = {3338449587, 3818674300}, [865834711] = {3313002205, 1821141167}, [2891650524] = {3313002205, 3526644555}, [894583910] = {3313002205, 4227655609}, [1454701910] = {3313002205, 3759705106}, [1569167104] = {2172164646}, [713074582] = {330834515}, [3659500495] = {770863021}, [2904079193] = {2197573192}, [4292792820] = {2545370, 2849167528, 392880972, 1050826686}, [4292792821] = {300250312, 3088153274}, [4292792822] = {3640562935, 1896520325}, [4292792823] = {3282246639, 1784092061}, [4292792824] = {3261166040, 1804959658}, [4292792825] = {3261166040, 4136797770}, [4292792826] = {1600555064, 3757665232}, [4292792827] = {1980589474, 3336723089}, [4292792828] = {1863734499, 2288100961}, [4292792829] = {563456019, 2466136910}, [4292792830] = {990530876, 3147149012}, [4292792831] = {308388006, 1833864661}, [4292792832] = {3300557735, 810893423}, [4292792833] = {2577485341, 1049361807, 2150876779, 2851828377, 2988382514}, [4292792834] = {2541745149, 1973161717, 2018972199, 3626412467}, [4292792835] = {3697803399, 1463144558}, [4292792836] = {2957124332, 431369374, 2802718586, 2395382664, 2502084643}, [4292792837] = {2556668775, 753802357}, [4292792838] = {4274118172, 1694741228}, [4292792839] = {3438787742, 2263340286}, [4292792840] = {2957124332, 4091384015}, [4292792841] = {789830284, 3225761236, 2130513456, 1463139010, 1288819049}, [4292792842] = {1773222822, 4024769189}, [4292792843] = {1175524567, 144173255}, [4292792844] = {2957124332, 2964738598}, [4292792845] = {2707678901, 2757062122}, [4292792846] = {228680600, 4132599687}, [4292792847] = {384621588, 3206074982, 249478621, 27322754, 677928304, 864827099}, [4292792848] = {3165669688, 356796234}}}
-- 2026-10-04 «Modo cambio» tab (docs/game/mechanics/mode-change.md §3): «Crear nuevo cambio» = item wmc_evt_create
-- (neutral row, always choosable); the player's created changes = items wmc_evt0..7 (row k = change k, named «<Modo
-- cambio>: <partner>», rows beyond his changes hidden). The opener hands over the count (evt_mc_n) and each change's
-- partner chara (evt_mc_c0..7).
local EVT_MC = {CREATE = 3567812479, CAR = {754700454, 1543299120, 3270881674, 3052568860, 731255999, 1553015849,
  3315103123, 2996782341}, KEY_N = 1284887561, KEY_C = {954567708, 1340259466, 3605785904, 2716655014, 1065895941,
  1217362067, 3515230505, 2793478591}, n = 0, c = {}}
local function EVT_McIndex(skill)
  for k = 1, #EVT_MC.CAR do
    if EVT_MC.CAR[k] == skill then
      return k
    end
  end
  return nil
end

-- the shared create-entry rules of Character Reforged (its lua\_all\character_reforged_create_card.lua), nil without it
local function EVT_CreateCard()
  local cr = rawget(_G, "CharacterReforged")
  return type(cr) == "table" and type(cr.CreateCard) == "table" and cr.CreateCard or nil
end

local function EVT_MxCompatible(skill)
  -- 2026-10-14 (owner): the VR-Framework's rule of the retail Mix-Max rows (owners / whitelist of the loaded data, and
  -- the players an item serves through its per-card changes: «Zhuge Liang», «Tezcat»). When the framework answers, its
  -- rule is the only one; the built-in list below is the fallback of an older framework.
  local card = EVT_CreateCard()
  if card ~= nil and card.Rule ~= nil and EVT_MX.hdl ~= nil and EVT_MX.hdl ~= 0 then
    local answered, allowed = card.Rule(skill, EVT_MX.hdl)
    if answered then
      return allowed
    end
  elseif card ~= nil and EVT_MX.hdl ~= nil and EVT_MX.hdl ~= 0 and not card.Allowed(skill, EVT_MX.hdl) then
    return false
  end
  local list = EVT_MX.COMPAT[skill]
  if list == nil then
    return true                                 -- not a retail miximax row
  end
  for _, id in ipairs(list) do
    if id == EVT_MX.chara or id == EVT_MX.param then
      return true
    end
  end
  return false
end

-- ids are unsigned 32-bit: exchanged as hex text (Lua 5.2 "%d" overflows above 2^31 on Windows)
--@lib evt_menu_kit.lua#EVT_U32
-- 2026-10-14: this block is the mod Character Reforged's (graft ss2_menus) and Inazuma Fantasy rebuilds it into its
-- own patch of this script (its aura_gates / master_seal blocks read these chunk locals), so ONE VM may run two
-- copies. Only the LAST copy acts: each wrapper of an earlier copy passes straight through to what it wrapped.
EVT_SS2_PICK_GEN = (EVT_SS2_PICK_GEN or 0) + 1
local EVT_PICK_GEN = EVT_SS2_PICK_GEN

local EVT_RetailOnInit = OnInit
function OnInit()
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailOnInit()
  end
  if type(VRFW_Copies) == "table" then
    pcall(VRFW_Copies.Reset)                  -- unlimited copies: asked again per list open
  end
  if funcLuaCommand(2947612279, EVT_KEY_PICK) then
    local m = tonumber(funcLuaCommand(3522198769, EVT_KEY_PICK)) or 1
    evt_pick = true
    EVT_ListState.latched = true                 -- the press that opened the picker never chooses in it
    evt_mode = (m == 3 and "P") or (m == 2 and "S") or "N"   -- try 26: 3 = six sense ("Pasiva personalizada")
    EVT_MX.prime = funcLuaCommand(2947612279, EVT_MX.KEY_PRIME) == true
    EVT_MX.fused = funcLuaCommand(2947612279, EVT_MX.KEY_FUSED) == true
    EVT_MX.chara, EVT_MX.param, EVT_MX.forbid, EVT_MX.hdl = 0, 0, false, 0
    if EVT_CreateCard() ~= nil then
      pcall(EVT_CreateCard().Reset)
    end
    local function pget(k)
      return funcLuaCommand(2947612279, k) and EVT_U32(funcLuaCommand(3522198769, k)) or 0
    end
    EVT_MX.pchara, EVT_MX.m1, EVT_MX.m2 = pget(EVT_MX.KEY_PCHARA), pget(EVT_MX.KEY_M1), pget(EVT_MX.KEY_M2)
    EVT_MX.pface = pget(3808658029)
    EVT_MC.n = pget(EVT_MC.KEY_N)
    for k = 1, #EVT_MC.KEY_C do
      EVT_MC.c[k] = pget(EVT_MC.KEY_C[k])
    end
    if funcLuaCommand(2947612279, EVT_MX.KEY_BASE) then
      local h = funcLuaCommand(3522198769, EVT_MX.KEY_BASE)
      EVT_MX.hdl = type(h) == "number" and h or 0
      EVT_MX.chara = EVT_U32(funcLuaCommand(1131797651, h, 1))
      EVT_MX.param = EVT_U32(funcLuaCommand(1131797651, h, 4))
      local okf, fb = pcall(funcLuaCommand, 3835898462 --[[CMND_EVT_MX_FORBIDDEN]], h)
      EVT_MX.forbid = okf and fb == true
    end
    evt_used = {}
    for k = 1, 6 do
      if funcLuaCommand(2947612279, EVT_KEY_USED[k]) then
        local id = EVT_U32(funcLuaCommand(3522198769, EVT_KEY_USED[k]))
        if id ~= 0 then
          evt_used[id] = k
        end
      end
    end
    EVT_PSet(EVT_KEY_DBG_INIT, m)
    -- the slot being edited and its player (evt_skill_slot_menu's Character Reforged block): its slot rules
    EVT_CR.slot = funcLuaCommand(2947612279, 4199810934 --[[evt_ss_pick_slot]]) and (tonumber(funcLuaCommand(3522198769, 4199810934)) or 0) or 0
    EVT_CR.chara = funcLuaCommand(2947612279, 3798840340 --[[evt_ss_pick_chara]]) and funcLuaCommand(3522198769, 3798840340) or 0
    EVT_CR.board = funcLuaCommand(2947612279, 850416018 --[[evt_ss_pick_board]]) and (tonumber(funcLuaCommand(3522198769, 850416018)) or -1) or -1
    EVT_CR.seen = {}
  end
  EVT_RetailOnInit()
  if evt_pick then
    UpdateButtonGuide()
  end
end

-- copy of ability_list_menu_on_bluebg SetupGrayout (the board picker's "not available" look)
local function EVT_Grayout(a1, a2, a3)
  local function prim(a4, a5, a6, a7)
    local r, g, b = funcLuaMenuCommand(3648327470, a4, a5, a6)
    if r ~= nil then
      funcLuaMenuCommand(855211291 --[[CMND_SET_PRIM_COLOR?]], a4, a5, a6, r * a7, g * a7, b * a7)
    end
  end
  prim(a1, a2, 3974820126, a3)
  prim(a1, a2, 3334923667 --[[num_have01]], a3)
  local l1 = 1 - a3
  funcLuaMenuCommand(2484004035, a1, a2, 931545948 --[[_text_list01_on]], l1)
  funcLuaMenuCommand(2484004035, a1, a2, 3705682548 --[[_text_list01_off]], l1)
  funcLuaMenuCommand(801406373, a1, a2, 643056375 --[[gray_out]], a3, a3, a3)
end

local function EVT_Allowed(skill)
  if evt_mode == "P" then            -- six-sense items: passive skills (not moves)
    local okm = funcLuaCommand(2580586398 --[[CMND_GET_SOCCER_SKILL_INFO?]], skill, 9)
    local p = funcLuaCommand(1448743477 --[[CMND_GET_PASSIVE_SKILL_INFO]], 0, skill)
    return (not okm) and p ~= nil and p ~= false and p ~= 0
  end
  local ok, cat = funcLuaCommand(2580586398 --[[CMND_GET_SOCCER_SKILL_INFO?]], skill, 9)
  local special = ok and cat == 8
  if (evt_mode == "S") ~= (special == true) then
    return false
  end
  -- 2026-10-14: Character Reforged's slot rules (scripts\skill_set.lua: the aura slot keshin / totem, the mix slot
  -- Mix-Max / «Modo cambio», the move rows special moves, + the veto rules of other mods), asked once per move
  if EVT_CR.slot ~= 0 and skill ~= 0 then
    local v = EVT_CR.seen[skill]
    if v == nil then
      v = EVT_CR_Allowed(skill)
      EVT_CR.seen[skill] = v
    end
    if not v then
      return false
    end
  end
  return true
end

local function EVT_CreateRowIcon(L, inst, sprite)
  funcLuaMenuCommand(3405944500, L, 2164615260, true, inst)
  funcLuaMenuCommand(558735651, L, 2320109963, sprite, 566439826, 0, inst)
end

local EVT_RetailUpdateListItem = UpdateListItem
function UpdateListItem(a1, a2, a3, a4, a5, a6, a7)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailUpdateListItem(a1, a2, a3, a4, a5, a6, a7)
  end
  EVT_RetailUpdateListItem(a1, a2, a3, a4, a5, a6, a7)
  -- an item with unlimited copies (VR-Framework VRFW_Copies: a rule a mod declares holds in this save) serves every
  -- player from one copy: its row has no copy counters and its owned copy is always free
  local unlimited = false
  if a1 == EVT_ITEM and type(VRFW_Copies) == "table" then
    local okU, u = pcall(VRFW_Copies.ListRow, a1, a2, EVT_U32(funcLuaCommand(901208644, a3)))
    unlimited = okU and u == true
    evt_unlimited_rows[a2] = unlimited and EVT_U32(funcLuaCommand(901208644, a3)) or nil
  end
  if evt_pick and a1 == EVT_ITEM then
    local skill = EVT_U32(funcLuaCommand(901208644, a3))
    evt_rows[a2] = skill
    if skill ~= 0 then
      evt_inv[skill] = EVT_U32(a3)
      evt_free[skill] = (tonumber(a5) or 0) > (tonumber(a6) or 0) or (unlimited and (tonumber(a5) or 0) >= 1)
    end
    local usable = skill ~= 0 and EVT_Allowed(skill) and (evt_free[skill] or evt_used[skill] ~= nil)
    if skill ~= 0 and skill ~= EVT_MX.FUSION then
      funcLuaMenuCommand(711242136, a1, a2, true)  -- list instances are reused: undo a hidden carrier row
      EVT_ListState.RowZone(a1, a2, true)
    end
    if skill == EVT_MX.CREATE and EVT_CreateCard() ~= nil then
      usable = not EVT_MX.prime
      pcall(EVT_CreateCard().Row, a1, a2, skill)  -- the item's own name, no counts, the Mix-Max icon (one rule)
    elseif skill == EVT_MX.CREATE then
      usable = not EVT_MX.prime
      -- neutral row: not the template's element / category icon, no counts
      for _, m in ipairs({1255155594 --[[_icon_cmd_type_dmy01]], 2172872396 --[[_icon_cmd_type_base01]],
          2164615260 --[[_icon_sp_area_dmy01]], 559600405 --[[_icon_sp_sub_dmy01]]}) do
        funcLuaMenuCommand(3405944500, a1, m, false, a2)
      end
      EVT_CreateRowIcon(a1, a2, 2185069032) -- Miximax
      -- the count / stock boxes completely: frames (locators) AND the numbers (primitives draw on their own)
      funcLuaMenuCommand(2158717427, a1, 442049775 --[[_pos_equip01]], false, a2)
      funcLuaMenuCommand(2158717427, a1, 3426045766 --[[_pos_have01]], false, a2)
      funcLuaMenuCommand(1233047821 --[[number visible]], a1, a2, 3334923667 --[[num_have01]], false)
      funcLuaMenuCommand(1233047821 --[[number visible]], a1, a2, 3974820126 --[[num_equip01]], false)
    elseif skill == EVT_MX.FUSION then
      -- 2026-09-25 (user): the carrier item wmm_evt is never listed (assignment is direct, and a player with a fusion
      -- cannot open this picker): its row is not drawn and cannot be chosen; the item data sorts it last in the tab
      usable = false
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, false)
      EVT_ListState.RowZone(a1, a2, false)
    end
    if skill == EVT_MX.FUSION and not EVT_MX.fused then
      usable = false                            -- no fusion yet: the fusion aura cannot be the Hiper
    end
    local mck = EVT_McIndex(skill)
    if skill == EVT_MC.CREATE or mck ~= nil then
      -- «Modo cambio» rows: no element / category icon, no counts (pseudo-items)
      for _, m in ipairs({1255155594 --[[_icon_cmd_type_dmy01]], 2172872396 --[[_icon_cmd_type_base01]],
          2164615260 --[[_icon_sp_area_dmy01]], 559600405 --[[_icon_sp_sub_dmy01]]}) do
        funcLuaMenuCommand(3405944500, a1, m, false, a2)
      end
      funcLuaMenuCommand(2158717427, a1, 442049775 --[[_pos_equip01]], false, a2)
      funcLuaMenuCommand(2158717427, a1, 3426045766 --[[_pos_have01]], false, a2)
      funcLuaMenuCommand(1233047821 --[[number visible]], a1, a2, 3334923667 --[[num_have01]], false)
      funcLuaMenuCommand(1233047821 --[[number visible]], a1, a2, 3974820126 --[[num_equip01]], false)
      -- 2026-10-07 (Nacho): the mode change's own aura icon (icon_sp_area11, the blue / red one of its rows, the shop
      -- card and the Hiper page), not the tab's grey head glyph
      if skill == EVT_MC.CREATE then EVT_CreateRowIcon(a1, a2, 1917130140 --[[icon_sp_area11]]) end
      usable = true
    end
    if mck ~= nil then
      usable = false -- equipped carriers are internal, never selectable presets
      funcLuaMenuCommand(711242136, a1, a2, false)
      EVT_ListState.RowZone(a1, a2, false)
    end
    if skill ~= 0 and EVT_MX.chara ~= 0 and not EVT_MxCompatible(skill) then
      usable = false                            -- a retail miximax of another player: greyed (normal name, no suffix)
    end
    -- 2026-10-07: an aura with a `compatible` list the base is not in (the retail mode changes, «Modo Serio» …) is
    -- listed greyed and refused (graft aura_compat, the one rule source; the loader no longer hides it)
    if skill ~= 0 and type(EVT_AC) == "table" and EVT_AC.PickAllowed ~= nil and not EVT_AC.PickAllowed(skill) then
      usable = false
    end
    if EVT_MX.forbid and (skill == EVT_MX.CREATE or skill == EVT_MX.FUSION or EVT_MX.COMPAT[skill] ~= nil) then
      usable = false                            -- «Modo Overdrive»: no miximax for this player (greyed)
    end
    -- a move already on another row is shown greyed (it can still be chosen: that swaps the two rows); 2026-09-30
    -- (Nacho): no «(ranura N)» suffix on its name any more, the grey row is enough
    local elsewhere = skill ~= 0 and evt_used[skill] ~= nil
    EVT_Grayout(a1, a2, (skill ~= 0 and (not usable or elsewhere)) and 0.5 or 1)
  end
end

function SendSkillIdToLua(a1)
  evt_sent = a1 or 0
end

local function EVT_FocusedSkill()
  if EVT_ListState.focus ~= 0 then
    return EVT_ListState.focus
  end
  local i = funcLuaMenuCommand(2603265800, EVT_ITEM)
  if i ~= nil and evt_rows[i] ~= nil and evt_rows[i] ~= 0 then
    return evt_rows[i]
  end
  return evt_sent
end

local function EVT_PickCommit(src, a1, a2)
  local skill = EVT_U32(EVT_FocusedSkill())
  if EVT_MX.forbid and (skill == EVT_MX.CREATE or EVT_MX.COMPAT[skill] ~= nil) then
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])  -- «Modo Overdrive»: no miximax for this player
    return
  end
  if skill == EVT_MX.CREATE then
    if EVT_MX.prime then
      funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
      return
    end
    evt_free[skill] = true                      -- never equipped: always choosable
  end
  if skill == EVT_MC.CREATE then
    evt_free[skill] = true                      -- «Crear nuevo cambio»: never equipped, always choosable
  end
  local mck = EVT_McIndex(skill)
  if mck ~= nil then
    funcLuaCommand(1917805374, 2086672038)
    return
  end
  if skill == EVT_MX.FUSION or (EVT_MX.chara ~= 0 and not EVT_MxCompatible(skill))
      or (type(EVT_AC) == "table" and EVT_AC.PickAllowed ~= nil and not EVT_AC.PickAllowed(skill)) then
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
    return
  end
  if skill ~= 0 and EVT_Allowed(skill) and evt_free[skill] == false and evt_used[skill] == nil then
    EVT_PSet(EVT_KEY_DBG_CODE, 5)   -- every copy is already placed on some board (the board refuses these too)
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
    return
  end
  if skill == 0 or not EVT_Allowed(skill) then
    EVT_PSet(EVT_KEY_DBG_CODE, 3)
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
    return
  end
  EVT_PSet(EVT_KEY_RESULT, skill)
  EVT_PSet(EVT_KEY_INV, evt_inv[skill] or 0)
  EVT_PSet(EVT_KEY_DBG_CODE, 4)
  funcLuaCommand(1917805374, 4235359837 --[[sy0010]])
  if EVT_ListState.RetailOnBack ~= nil then
    pcall(EVT_ListState.RetailOnBack)        -- the retail back: saves the shown tab's filter
  end
  evt_pick = false
  funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 2897322950 --[[ability_list_menu]])
end

-- keyboard/pad confirm arrives as OnEnter(list layer); a mouse click on a row can arrive as OnDecideFocus(item/list)
-- instead -> both paths commit; every call is logged (layer id), any Lua error is reported (code 9).
local function EVT_Mark(bit)
  if evt_pick and evt_bits % (bit * 2) < bit then
    evt_bits = evt_bits + bit
    EVT_PSet(EVT_KEY_DBG_BITS, evt_bits)
  end
end

local function EVT_PickEntry(src, a1, a2)
  if evt_pick then
    EVT_PSet(EVT_KEY_DBG_ENTER, EVT_U32(a1))
    EVT_Mark(src == "OnEnter" and EVT_BIT.ONENTER or src == "OnDecideFocus" and EVT_BIT.ONDECIDE or EVT_BIT.COMMIT)
  end
  if not evt_pick or (a1 ~= EVT_LIST and a1 ~= EVT_ITEM) then
    return
  end
  -- a popup of the picker is open (or its closing press is still down), or a confirm already ran this frame
  if EVT_ListState.Quiet() or EVT_ListState.decided_frame == EVT_ListState.frame then
    return
  end
  EVT_ListState.decided_frame = EVT_ListState.frame
  if src == "OnDecideFocus" and a1 == EVT_ITEM then
    EVT_ListState.FocusRowSkill(a2)              -- the clicked row, even before the detail card followed it
  end
  local ok, err = pcall(EVT_PickCommit, src, a1, a2)
  if not ok then
    PRINT("ability_list_menu EVT pick: " .. tostring(err))
    EVT_PSet(EVT_KEY_DBG_CODE, 9)
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
  end
end

local EVT_PreviousOnEnter = OnEnter
function OnEnter(a1, a2)
  EVT_PickEntry("OnEnter", a1, a2)
  if EVT_PreviousOnEnter ~= nil then
    return EVT_PreviousOnEnter(a1, a2)
  end
end

local EVT_PreviousOnDecideFocus = OnDecideFocus
function OnDecideFocus(a1, a2)
  EVT_PickEntry("OnDecideFocus", a1, a2)
  if EVT_PreviousOnDecideFocus ~= nil then
    return EVT_PreviousOnDecideFocus(a1, a2)
  end
end

-- The picker's input over its popups and the pointer (owner 2026-10-15: with the pad, Accept / Back inside the filter
-- window chose a move or closed the picker behind it; the mouse chose the focused move on a click anywhere).
-- * Popups: the retail filter window (OpenFilter -> item_filter_menu) and the sort window (OpenSortSubWindow ->
--   sub_window) take every press while they are open: the picker's polled Accept / click / Eliminar and its confirm
--   callbacks do nothing then. After a popup closed (and after the picker opened) they wait for a frame with none of
--   those presses down, so the press that closed the popup never reaches the list.
-- * Pointer: a click chooses a move only when the pointer is inside the focused row's own click zone (_touch_list01
--   of team08_02_ability_list_item, the engine's hit test); a click on a tab, the button guide, the detail card or an
--   empty area never chooses. Rows the picker hides (carrier items) lose their click zone and hover focus, so the
--   pointer never focuses an invisible row.
EVT_ListState.frame = 0                          -- Step count of this list
EVT_ListState.decided_frame = -1                 -- the frame a confirm last ran (one per frame)
EVT_ListState.popup_running = false             -- inside OpenFilter, or while the sort window opens
EVT_ListState.sort_open = false                  -- the sort window opened and not closed yet
EVT_ListState.latched = true                     -- waiting for a frame without a latched press
EVT_ListState.LATCHED_KEYS = {1981080283 --[[CMD_ENTER]], 1651523701 --[[CMD_ENTER_CLICK]],
  218912913 --[[CMD_EVT_MOUSE_LEFT]], 3421673595 --[[CMD_FUNC3]]}
EVT_ListState.FILTER_MENU = 4116121052           -- item_filter_menu
EVT_ListState.SORT_WINDOW = 968210065            -- sub_window
EVT_ListState.TOUCH_NODE = 688754292             -- _touch_list01 (the row's click zone)
EVT_ListState.MENU = 2897322950                  -- ability_list_menu
function EVT_ListState.PopupOpen()
  if EVT_ListState.popup_running then
    return true
  end
  local okf, exists = pcall(funcLuaMenuCommand, 2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], EVT_ListState.FILTER_MENU)
  if okf and exists == true then
    return true
  end
  if EVT_ListState.sort_open then
    local okc, closed = pcall(funcLuaCommand, 1521844538 --[[CMND_IS_CLOSE_MENU_OBJECT]], EVT_ListState.SORT_WINDOW)
    if okc and closed == false then
      return true
    end
    EVT_ListState.sort_open = false
    EVT_ListState.latched = true
  end
  return false
end
function EVT_ListState.LatchedKeyDown()
  for _, key in ipairs(EVT_ListState.LATCHED_KEYS) do
    if funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD]], 1332654303 --[[MENU_CTRL]], key) == true then
      return true
    end
  end
  return false
end
-- once per Step: true while the picker's own input stays quiet (a popup is open, or its closing press is down)
function EVT_ListState.InputBlocked()
  if EVT_ListState.PopupOpen() then
    EVT_ListState.latched = true
    return true
  end
  if EVT_ListState.latched then
    if EVT_ListState.LatchedKeyDown() then
      return true
    end
    EVT_ListState.latched = false
  end
  return false
end
-- the confirm callbacks (OnEnter / OnDecideFocus): the same rule, without releasing the latch
function EVT_ListState.Quiet()
  return EVT_ListState.latched or EVT_ListState.PopupOpen()
end
-- a list row's click zone and hover focus (on for a shown row, off for a hidden one)
function EVT_ListState.RowZone(layer, instance, on)
  pcall(funcLuaMenuCommand, 855005857 --[[click zone]], layer, instance, on)
  pcall(funcLuaMenuCommand, 2206938151 --[[CMND_SET_ON_CHANGE_FOCUS_MOUSE]], layer, instance, on)
end
-- the move of list row `instance` becomes the focused move (a click decides that row)
function EVT_ListState.FocusRowSkill(instance)
  if type(instance) == "number" and evt_rows[instance] ~= nil and evt_rows[instance] ~= 0 then
    EVT_ListState.focus = evt_rows[instance]
  end
end
-- is the pointer inside the focused row's click zone? true / false, nil = the engine gave no answer
function EVT_ListState.PointerOnFocusedRow()
  local instance = funcLuaMenuCommand(2603265800 --[[focused index]], EVT_ITEM)
  if type(instance) ~= "number" or instance < 0 then
    return false, nil
  end
  local ok, inside = pcall(funcLuaMenuCommand, 2418128616 --[[pointer inside a zone]], EVT_ListState.MENU, EVT_ITEM,
    instance, EVT_ListState.TOUCH_NODE)
  if not ok or type(inside) ~= "boolean" then
    return nil, instance
  end
  return inside, instance
end
-- the popups: the filter window runs inside the retail OpenFilter (it returns once the window is gone); the sort
-- window is open from OpenSortSubWindow until the engine reports it closed
if type(OpenFilter) == "function" then
  EVT_ListState.RetailOpenFilter = OpenFilter
  function OpenFilter(...)
    if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
      return EVT_ListState.RetailOpenFilter(...)
    end
    EVT_ListState.popup_running = true
    local r = table.pack(pcall(EVT_ListState.RetailOpenFilter, ...))
    EVT_ListState.popup_running = false
    EVT_ListState.latched = true
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end
end
if type(OpenSortSubWindow) == "function" then
  EVT_ListState.RetailOpenSortSubWindow = OpenSortSubWindow
  function OpenSortSubWindow(...)
    if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
      return EVT_ListState.RetailOpenSortSubWindow(...)
    end
    EVT_ListState.popup_running = true          -- the retail call returns once the window is open
    local r = table.pack(pcall(EVT_ListState.RetailOpenSortSubWindow, ...))
    EVT_ListState.popup_running = false
    EVT_ListState.sort_open = r[1] == true
    EVT_ListState.latched = true
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end
end

-- Try 7 showed that no confirm callback reaches Lua in this list (the viewer group handles CMD_ENTER natively).
-- Try 8: poll the input like retail scripts do (CMND_CHECK_INPUT_CMD 0xFE429D08 (MENU_CTRL, CMD_ENTER) and
-- CMD_ENTER_CLICK for the mouse) every frame while pick mode is on, and commit the focused move.
-- Mouse: a click commits the focused row when the pointer is inside its click zone (the hover already focused it);
-- without an answer from the engine's hit test, only a click while the focused move has been stable for >= 2 frames.
local EVT_MENU_CTRL, EVT_CMD_ENTER, EVT_CMD_ENTER_CLICK = 1332654303, 1981080283, 1651523701
local evt_last_focus, evt_stable, evt_frames = 0, 0, 0
local EVT_RetailOnChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailOnChangeFocus(a1, a2)
  end
  EVT_Mark(EVT_BIT.FOCUS)
  EVT_RetailOnChangeFocus(a1, a2)
  -- the focused row of an unlimited item: the focus shows the row's stock boxes again, so they are hidden again
  if a1 == EVT_ITEM and type(VRFW_Copies) == "table" then
    local inst = funcLuaMenuCommand(2603265800 --[[focused index]], EVT_ITEM)
    if type(inst) == "number" and evt_unlimited_rows[inst] ~= nil then
      pcall(VRFW_Copies.HideCounters, EVT_ITEM, inst)
    end
  end
  if a1 == 4044286600 --[[cmn06_20_list_tab_item]] then
    local count = funcLuaMenuCommand(2389020234 --[[list item count]], EVT_LIST)
    if type(count) ~= "number" or count <= 0 then
      EVT_ListState.focus = 0
    end
  end
end

-- a filter received: no focused move until the list focuses one again (retail n2 = 0)
local EVT_PreviousOnAfterReceiveFilterParam = OnAfterReceiveFilterParam
function OnAfterReceiveFilterParam(...)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_PreviousOnAfterReceiveFilterParam(...)
  end
  EVT_ListState.focus = 0
  return EVT_PreviousOnAfterReceiveFilterParam(...)
end
-- 2026-10-13 (Nacho, video: opening the Hiper / Miximax / Keshin picker from the skill table): the move / aura detail
-- card (team02_02 / team00_30_aura_*, its balloon and page guide: «Crear miximax», «AT 140», «Y Habilidad pasiva») sat
-- at the screen's top-left for ~12 frames. The engine fills it (UpdateSkillDetailWindow on the first focus) while the
-- menu opens, but the card only gets its place when the list layer team05_03_ability_list opens (OnOpenLayer): until
-- then it draws at (0, 0). Root fix: every fill before that keeps the card layers hidden (their wanted visibility is
-- remembered after the fill) and the first Step after the list opened shows them at their place. Fallback: shown
-- after EVT_DW.MAX_WAIT frames whatever happens. Mechanism only, every list mode (pick or retail).
local EVT_DW = {
  LAYERS = {2628045944 --[[team02_02_skill_detail_info]], 2651268807 --[[team00_30_aura_keshin_detail_info]],
    395833588 --[[team00_30_aura_keshin_armed_detail_info]], 3679282495 --[[team00_30_aura_mixi_max_detail_info]],
    576015315 --[[team00_30_aura_soul_detail_info]], 3635526425 --[[team00_30_aura_kizuna_trans_detail_info]],
    1305553269 --[[team00_30_aura_awakening_power_detail_info]], 3131422953 --[[team00_30_aura_mode_change_detail_info]],
    26273556 --[[team00_30_p1_balloon]], 1921826160 --[[team00_40_change_page_guide]]},
  MAX_WAIT = 90,
  ready = false, frames = 0, open_at = nil, held = {}, fills = 0}
local function EVT_DW_Log(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "skill_slots", "detail gate", ...)
end
-- after a fill while the list is not open yet: remember what the fill wants shown, keep it all hidden
local function EVT_DW_Hold()
  if EVT_DW.ready then
    return
  end
  EVT_DW.fills = EVT_DW.fills + 1
  EVT_DW.held = {}
  for _, L in ipairs(EVT_DW.LAYERS) do
    if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], L)
        and funcLuaMenuCommand(1262717583 --[[CMND_IS_LAYER_VISIBLE]], L, 0) == true then
      EVT_DW.held[L] = true
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], L, 0, false)
    end
  end
end
local function EVT_DW_Step()
  if EVT_DW.ready then
    return
  end
  EVT_DW.frames = EVT_DW.frames + 1
  if not ((EVT_DW.open_at ~= nil and EVT_DW.frames > EVT_DW.open_at) or EVT_DW.frames >= EVT_DW.MAX_WAIT) then
    return
  end
  EVT_DW.ready = true
  local shown = 0
  for L in pairs(EVT_DW.held) do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], L, 0, true)
    shown = shown + 1
  end
  EVT_DW.held = {}
  EVT_DW_Log("released at frame", EVT_DW.frames, "list opened at", tostring(EVT_DW.open_at), "fills held",
    EVT_DW.fills, "layers shown", shown)
end
local EVT_DW_RetailOnOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_DW_RetailOnOpenLayer(a1, a2)
  end
  if a1 == EVT_LIST and EVT_DW.open_at == nil then
    EVT_DW.open_at = EVT_DW.frames
  end
  return EVT_DW_RetailOnOpenLayer(a1, a2)
end
local EVT_RetailUpdateSkillDetailWindow = UpdateSkillDetailWindow
local function EVT_MxDetail(skill)
  local A = 3679282495                          -- team00_30_aura_mixi_max_detail_info (the picker's miximax window)
  local function skname(id)
    local ok, nameId = funcLuaCommand(2580586398, id, 4)
    return (ok and nameId) and (funcLuaCommand(720417636, nameId) or "") or ""
  end
  for _, p in ipairs({3407216458 --[[_pos_page01]], 1377611504 --[[_pos_page02]], 3145665477 --[[_pos_page04]],
      3430431571 --[[_pos_page05]], 1307475940 --[[_pos_list01]], 3571920478 --[[_pos_list02]]}) do
    funcLuaMenuCommand(2158717427, A, p, false, 0)
  end
  funcLuaMenuCommand(711242136, 1921826160 --[[team00_40_change_page_guide]], 0, false)
  -- the template's move page (page 1): a text / mesh / number set visible by the retail fill stays visible under a
  -- hidden locator, so every part is hidden explicitly
  for _, x in ipairs({1179414078 --[[_text_fsp01]], 1899787537 --[[_text_area01]], 3542179801 --[[_text_page_title01]],
      1244139107 --[[_text_page_title02]], 2739645270 --[[_text_page_title04]], 3561790400 --[[_text_page_title05]],
      691026122 --[[_text_flavor01]], 777911507 --[[_text_flavor05]], 325360264 --[[_text_scr_btn01]]}) do
    funcLuaMenuCommand(2735666188, A, x, false, 0)
  end
  for _, m in ipairs({3032210235, 206240291, 563708378 --[[_gtxt_cmd_at01]],
      3516146179 --[[_area_base01]], 811580556 --[[_gtxt_armed01]], 1013569271 --[[_ai_use01]],
      2992676399, 2269285990, 2408672862}) do
    funcLuaMenuCommand(3405944500, A, m, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], A, 0, 2223127589 --[[AT power]], false)
  -- the page dots (the retail fill lights them explicitly: they showed under a hidden locator) and the power line
  for _, m in ipairs({658945009, 905124895, 2370796410, 1956062673, 859266817, 240613041, 380545388, 68880002, 3165086183, 561011038, 4195885618, 3182975202, 2161668434, 855158082, 4122450641}) do
    funcLuaMenuCommand(3405944500, A, m, false, 0)
  end
  funcLuaMenuCommand(2735666188, A, 1757105749, false, 0)
  funcLuaMenuCommand(2158717427, A, 622567014 --[[_pos_page03]], true, 0)
  funcLuaMenuCommand(3405944500, A, 728354709, true, 0)
  funcLuaMenuCommand(2735666188, A, 2956552560 --[[_text_flavor02]], true, 0)
  funcLuaMenuCommand(3405944500, A, 2449339029 --[[_icon_fs_dmy01]], false, 0)
  if skill == EVT_MX.CREATE then
    funcLuaMenuCommand(1083631230, A, 2915321899 --[[_text_fs01]], "Crear miximax", 0)
    funcLuaMenuCommand(1083631230, A, 2956552560,
      "Fusiona a este jugador con otro de tus jugadores: elige el compañero y una de sus supertécnicas.", 0)
    funcLuaMenuCommand(4176779611 --[[clear face icon]], A, 0, 3237726902 --[[icon_chr_dmy01]])
    funcLuaMenuCommand(3405944500, A, 478320441 --[[_icon_chr_dmy01]], false, 0)
    -- neutral band: the retail miximax band, element 01
    funcLuaMenuCommand(558735651, A, 2815298114 --[[team00_30 <LG>]], 3558327990 --[[mixi_base01]], 1716659057 --[[fs_base01]], 0, 0)
    funcLuaMenuCommand(3405944500, A, 1605611365, true, 0)
  else
    local ok, a, b = pcall(funcLuaCommand, 4060384944, EVT_MX.pchara, 10)
    local pn = (ok and type(b) == "string") and b or ((ok and type(a) == "string") and a or "")
    funcLuaMenuCommand(1083631230, A, 2915321899, "Miximax Trans: " .. pn, 0)
    local learn = skname(EVT_MX.m1)
    if EVT_MX.m2 ~= 0 then
      learn = learn .. " y " .. skname(EVT_MX.m2)
    end
    funcLuaMenuCommand(1083631230, A, 2956552560, string.format("Fusión con %s. Aprende %s.", pn, learn), 0)
    funcLuaMenuCommand(3405944500, A, 478320441, true, 0)
    local key = (EVT_MX.pface ~= nil and EVT_MX.pface ~= 0) and EVT_MX.pface or EVT_MX.pchara
    pcall(funcLuaCommand, 3148141229 --[[CMND_EVT_APPEARANCE]], "skill_panel", key)   -- the partner on purpose
    -- retail miximax window rule (UpdateMixiMaxDetailInfo, as the Supertécnicas panel): the type-12 face icon when
    -- it exists, else the plain chara icon (before: type 12 only, an empty portrait for a partner without one)
    if funcLuaMenuCommand(2208175668 --[[has a miximax face icon]], key) then
      funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], A, 0, 478320441, 3237726902 --[[icon_chr_dmy01]],
        key, 0, 12, true, true, true, 5)
    else
      pcall(SetDisableForceCharaInvalidUseTarget)
      funcLuaMenuCommand(552280324, A, 0, false, 478320441, 3237726902, 0, 0, key)
      pcall(SetEnableForceCharaInvalidUseTarget)
    end
  end
end
function UpdateSkillDetailWindow(a1, a2, a3)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailUpdateSkillDetailWindow(a1, a2, a3)
  end
  EVT_Mark(EVT_BIT.DETAIL)
  EVT_RetailUpdateSkillDetailWindow(a1, a2, a3)
  local okInfo = funcLuaCommand(2580586398 --[[CMND_GET_SOCCER_SKILL_INFO?]], a1, 9)
  EVT_ListState.focus = (okInfo and type(a1) == "number") and a1 or 0
  local skill = EVT_U32(a1)
  if evt_pick and skill == EVT_MX.CREATE then
    -- the item's own card (Character Reforged's shared rule: its name and text, no template portrait / move)
    local card = EVT_CreateCard()
    local okc, done = false, false
    if card ~= nil then
      okc, done = pcall(card.Detail, skill)
    end
    if not (okc and done) then
      pcall(EVT_MxDetail, skill)
    end
  elseif evt_pick and skill == EVT_MX.FUSION then
    funcLuaMenuCommand(711242136, 3679282495 --[[the miximax window]], 0, false)   -- the hidden carrier: no detail
  end
  pcall(EVT_DW_Hold)
end
local EVT_RetailStep = Step
function Step()
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailStep()
  end
  if EVT_RetailStep ~= nil then
    EVT_RetailStep()
  end
  pcall(EVT_DW_Step)
  EVT_ListState.frame = EVT_ListState.frame + 1
  if not evt_pick then
    return
  end
  EVT_Mark(EVT_BIT.STEP)
  evt_frames = evt_frames + 1
  local blocked = EVT_ListState.InputBlocked()   -- a popup is open, or its closing press is still down
  if evt_frames == 2 and evt_mode == "S" then
    -- 2026-09-25: "Crear miximax" (item sort 6800, before the retail 6873...) must be FIRST in the MIXIMAX tab: the
    -- Hiper picker always uses the number order (sort type 8, the list's default t3[1]), whatever sort was saved
    pcall(function()
      funcLuaMenuCommand(2253672176, 1361375778 --[[sort]], 8, EVT_LIST)
      funcLuaMenuCommand(4114514990, EVT_LIST, true)
      funcLuaMenuCommand(306610847, EVT_LIST, 0)
      funcLuaMenuCommand(1778826357, EVT_ITEM, 0, true)
    end)
    pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "skill_slots", "hiper picker sort", 8,
      "create owned", funcLuaCommand(2011560392, EVT_MX.CREATE))
  end
  if evt_frames < 10 then   -- ignore the Enter/click that opened the list on the slot screen
    return
  end
  local focus = EVT_U32(EVT_FocusedSkill())
  if focus == evt_last_focus then
    evt_stable = evt_stable + 1
  else
    evt_last_focus, evt_stable = focus, 0
  end
  if blocked then
    return
  end
  if focus == EVT_MX.FUSION and not funcLuaCommand(4265778440, EVT_MENU_CTRL, EVT_CMD_ENTER)
      and not funcLuaCommand(4265778440, EVT_MENU_CTRL, EVT_CMD_ENTER_CLICK)
      and funcLuaCommand(4265778440, EVT_MENU_CTRL, 3421673595 --[[CMD_FUNC3]]) then
    EVT_PSet(EVT_MX.KEY_DEL, 1)                 -- Eliminar on the fusion entry: undo it (the slot screen does it)
    EVT_PSet(EVT_KEY_RESULT, focus)
    EVT_PSet(EVT_KEY_INV, evt_inv[focus] or 0)
    funcLuaCommand(1917805374, 2339718859 --[[sy0011]])
    evt_pick = false
    funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 2897322950 --[[ability_list_menu]])
    return
  end
  if funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD?]], EVT_MENU_CTRL, EVT_CMD_ENTER) then
    EVT_Mark(EVT_BIT.ENTER)
    EVT_PickEntry("Step-Enter", EVT_LIST, 0)
  elseif funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT_CMD?]], EVT_MENU_CTRL, EVT_CMD_ENTER_CLICK) then
    EVT_Mark(EVT_BIT.CLICK)
    local inside, instance = EVT_ListState.PointerOnFocusedRow()
    if inside == true then
      EVT_ListState.FocusRowSkill(instance)      -- the row under the pointer, even before the detail card followed
      EVT_PickEntry("Step-Click", EVT_LIST, 0)
    elseif inside == nil and evt_stable >= 2 then
      EVT_PickEntry("Step-Click", EVT_LIST, 0)
    end
  end
end

local EVT_RetailOnSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailOnSetupLayer(a1, a2)
  end
  EVT_RetailOnSetupLayer(a1, a2)
  if evt_pick and a1 == 3078308064 --[[mainmenu90_05_content_guide_line01]] then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, true)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 378156699 --[[_text_guide01]],
      (evt_mode == "P" and "Elige una pasiva personalizada.") or
      (evt_mode == "S" and ((EVT_MX.forbid and "Elige la hipertécnica. Modo Overdrive: este jugador no puede usar miximax.")
        or (EVT_MX.prime and "Elige la hipertécnica. Una carta Prime no puede crear un miximax.")
        or "Elige la hipertécnica. Crear miximax: fusiona con otro jugador.")) or
      "Elige la supertécnica para la ranura.", a2)
  end
end

local EVT_RetailUpdateButtonGuide = UpdateButtonGuide
local EVT_GUIDE = 1138543975                 -- mainmenu01_06_base_button_guide
local EVT_GUIDE_TEXTS = 2209673388           -- (menu, guide, texts, glyphs, offsets, …)
local EVT_GUIDE_KEYS = 452337289             -- (menu, guide, commands)
local EVT_FILTER_TEXTS = {[2493238543] = true, [773924788] = true}   -- the retail filter entry (on / off)
function UpdateButtonGuide()
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailUpdateButtonGuide()
  end
  if not evt_pick then
    return EVT_RetailUpdateButtonGuide()
  end
  -- pick mode: the retail guide (filter, detail) with «Aceptar» on CMD_ENTER after the filter entry, as the board
  -- picker shows it; the retail call's own guide tables get the entry while it runs
  local retail_command = funcLuaMenuCommand
  local at = nil
  funcLuaMenuCommand = function(command, menu, layer, a, b, c, d, e, ...)
    if command == EVT_GUIDE_TEXTS and layer == EVT_GUIDE and type(a) == "table" then
      at = (EVT_FILTER_TEXTS[a[1]] and 2) or 1
      local entry = {3790324331, 2750714971, 0, 0, 0}
      for k, list in ipairs({a, b, c, d, e}) do
        if type(list) == "table" then
          table.insert(list, at, entry[k])
        end
      end
    elseif command == EVT_GUIDE_KEYS and layer == EVT_GUIDE and type(a) == "table" and at ~= nil then
      table.insert(a, at, 1981080283 --[[CMD_ENTER]])
    end
    return retail_command(command, menu, layer, a, b, c, d, e, ...)
  end
  local ok, err = pcall(EVT_RetailUpdateButtonGuide)
  funcLuaMenuCommand = retail_command
  if not ok then
    PRINT("ability_list_menu EVT pick guide: " .. tostring(err))
  end
end

local EVT_RetailOnBack = OnBack
function OnBack(a1)
  if EVT_SS2_PICK_GEN ~= EVT_PICK_GEN then -- an earlier copy of this block: pass through (see the top)
    return EVT_RetailOnBack(a1)
  end
  if evt_pick then
    funcLuaCommand(3363400568, EVT_KEY_RESULT)
  end
  EVT_RetailOnBack(a1)
end
