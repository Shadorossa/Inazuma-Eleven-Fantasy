@PH_COMMON@

-- ===== EVT plate_hiper plate BEGIN =====
-- personal_plate_menu part (grafted after the retail chunk, so every retail global already exists).
-- Page type 5 = the player's Hipertécnica: the retail aura window of its type (team00_30_aura_*_detail_info: name,
-- keshin/totem portrait, header art of the type, the aura's own move with power and category, effect text, tension
-- gauge) or, for a special without aura data, the retail move window team02_02_skill_detail_info (name, power,
-- tension cost, description); "Sin hipertécnica" in team02_02 when the player has none.
-- Source of the Hiper (no vr-loader needed, retail commands only): board slot 8 (the new skill set's aura slot), else a special
-- in the 6 match moves, else a special on board slots 5-7. A special = move category 8.
-- Placement: the windows are normally attached to _atc_sp_win01 (the popup above the plate). The builder adds one
-- attach label per window to our clone evt_soccer11_05_formation_status_base.objbin (used by the personal_plate_menu
-- settings only) on the existing locator _atc_sixth01 (page centre, where the six-sense window sits; child of
-- _pos_page04). While the Hiper page shows, the retail labels are switched off and ours on; EVT_PH_Decor shows
-- _pos_page04 and sets the dots / titles.

-- Integrated panel (2026-09-24, user: "integrada a la página de atrás"): with EVT_PH_INTEGRATED the page no longer shows
-- a retail window (a card with its own frame and shadow). The move is drawn straight on the page in the style of the
-- Supertécnicas move panel: layer evt_ph_skill_detail_info (a re-laid-out clone of team02_02) with a header band full
-- bleed from the page's left edge, name, "type · cost" line, portrait, the spirit's move row, TENSIÓN and description.
-- The band is the GAME'S OWN background of the aura type (user: "usa lo que existe en el juego"): the header sprite of
-- the retail aura detail windows in team00_30.g4tx, chosen exactly as retail UpdateKeshinDetailInfo & co. do (aura type
-- SKILL_INFO 13 -> family, element SKILL_INFO 7 -> 01..05); docs/game/skill-slots.md "Aura type backgrounds".
-- The empty page uses the retail empty band sp_base_blank02 of team02_02 (retail's choice for aura category 8).
-- It is filled by the retail SetupPersonalPlateSkillDetailInfo with the skill-detail layer pointed at it
-- (SetSkillItemLayerName, whose last arguments are recorded so they can be put back).
EVT_PH_INTEGRATED = true
EVT_PHI = {L = 3095103815, TEX = 2815298114 --[[team00_30.g4tx]], TEX_T02 = 3964676290 --[[team02_02.g4tx]],
  BAND_EMPTY = 2575257044 --[[sp_base_blank02]], ROW = 1127933049, FACE = 113683591}
@HIPER_CARD@
EVT_PH_BANDS = EVT_HC.BANDS        -- shared card component (evt_hiper_card.lua)

EVT_PH_DEBUG = false                -- lines in evt_loader\loader.log (CMND_EVT_LOG; nothing without the loader)
EVT_PH_ON_PAGE = true               -- false: leave the windows at their retail popup position (no label switching)
EVT_PH_TYPE_IN_NAME = true          -- "Lancelot (Keshin)"
-- the empty page's texts are menu_text rows in the 9 languages (research/scripts/plate_hiper_text_build.py):
-- crc32("evt_ph_empty_name") «Sin hipertécnica» (the hint row evt_ph_empty_text was retired on 2026-10-07: banner only)
-- Without the rows (text files not installed yet) the page shows no text rather than a literal of one language.
EVT_PH_EMPTY_NAME_ID = 2275178128     -- crc32("evt_ph_empty_name")
function EVT_PH_Text(id)
  local ok, s = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return ""
end
EVT_PH_TYPE_NAME = {[0] = "Espíritu guerrero", "Armadura", "Miximax", "Tótem", "Vínculo", "Poder de despertar", "Cambio de modo",
  "Despertar"}

local L_STATUS = 730911947          -- soccer11_05_formation_status_base (holds the attach labels)
local L_DETAIL = 2628045944         -- team02_02_skill_detail_info
local L_GUIDE = 1921826160          -- team00_40_change_page_guide (aura window page guide)
local AURA_WIN = {[0] = 2651268807, 395833588, 3679282495, 576015315, 3635526425, 1305553269, 3131422953}
local AURA_LIST = {3305013191, 469529772, 2518547969}   -- armed / miximax chara list items of the aura windows
-- {window layer, retail label (normal), retail label (rpg), our label, retail switches it at setup}
local EVT_PH_ATTACH = {
  {2628045944, 3582151293, 469331039, 3794660660, true},   -- team02_02_skill_detail_info
  {2651268807, 100208928, 292829657, 2066005134, false},   -- team00_30_aura_keshin_detail_info
  {395833588, 3614520464, 2835829491, 203656216, false},   -- team00_30_aura_keshin_armed_detail_info
  {3679282495, 156154064, 3817422277, 2454133179, false},   -- team00_30_aura_mixi_max_detail_info
  {576015315, 2010198621, 1367082907, 3846187309, false},   -- team00_30_aura_soul_detail_info
  {3635526425, 1317134987, 980681138, 2085189783, false},   -- team00_30_aura_kizuna_trans_detail_info
  {1305553269, 2809849850, 3248645642, 189679617, false},   -- team00_30_aura_awakening_power_detail_info
  {3131422953, 3719784747, 2053488477, 2616284560, false},   -- team00_30_aura_mode_change_detail_info
}

local C = {
  LAYER_VISIBLE = 711242136, IS_LAYER_VISIBLE = 1262717583, EXIST_LAYER = 262659071,
  IS_OPEN_LAYER = 2640875187, OPEN_LAYER = 629267548, TRACE = 1774843228, LOC_VISIBLE = 2158717427,
  MESH_VISIBLE = 3405944500, TEXT = 1083631230, TEXT_VISIBLE = 1505208242, TEXT_PLATE = 1172899594,
  SPRITE = 558735651, LIST_VISIBLE = 2171393651, PRIM_VISIBLE = 1233047821,
  SKILL_INFO = 2580586398, NAME_TEXT = 720417636, BOARD_INV = 632801955, INV_ITEM = 2662166687,
  GET_SKILL = 903078840, TENSION_SCALE = 3413028567, EVT_LOG = 3661580131,
}
local TX_TEAM02_02 = 3964676290     -- #/menu/102_team/team02/team02_02/<LG>/team02_02.g4tx

local evt_ph_on = false             -- our window is shown / labels switched
local evt_ph_plate_type = 0         -- SetPersonalPlateType (2 = rpg locator set)
local evt_ph_detail_dirty = false   -- team02_02 was drawn as "empty" (nodes hidden that the retail fill never restores)

local function EVT_PH_Log(...)
  if EVT_PH_DEBUG then
    pcall(funcLuaCommand, C.EVT_LOG, "plate_hiper", ...)
  end
end

local function EVT_PH_U32(v)
  v = tonumber(v) or 0
  if v < 0 then
    v = v + 4294967296
  end
  return v
end

local function EVT_PH_IsSpecial(skill)
  if skill == nil or skill == 0 then
    return false
  end
  local ok, cat = funcLuaCommand(C.SKILL_INFO, skill, 9)
  return ok and cat == 8
end

-- move on a board skill slot (0x25B7CAA3 kind 1 = placed item, kind 0 = native item), as the skill slot screen
local function EVT_PH_Board(chara, bslot)
  local inv = funcLuaCommand(C.BOARD_INV, chara, bslot, 1)
  if inv == nil or inv == 0 then
    inv = funcLuaCommand(C.BOARD_INV, chara, bslot, 0)
  end
  if inv == nil or inv == 0 then
    return 0
  end
  return EVT_PH_U32(funcLuaCommand(C.INV_ITEM, inv, 0))
end

-- 2026-10-12 (owner redesign, docs/game/hiper/hiper-two-slots.md): two slots per player. The page shows the AURA slot
-- (board slot 8: keshin / totem); L3 (graft plate_pages, EVT_PH_CanSwitch) switches to the MIX slot (a Mix-Max / a
-- «Modo cambio»: Character Reforged's mix-slot store since 2026-10-14, CMND_CHARACTERREFORGED_MIX_GET of the saved
-- card through CharacterReforged.Page.MixOf; it was Inazuma Fantasy's CMND_FANTASY_HIPER_MIX_GET, whose blob the store
-- imported) and back; a player with only a mix slot shows it directly. No chain: a Mix-Max no longer brings the
-- partner's keshin onto this page. A copy of a card (a mod's fusion copy) asks its owner card through
-- CMND_EVT_CHARA_OWNER when a mod declares it (no answer = no owner).
-- 2026-10-14 (owner: Jade Beor's table showed Magister in the aura half, her page tagged Metis' «Armadura»): while the
-- option «Tabla de habilidades» shows the new set, the page's aura / mix = THE projection (CharacterReforged.Page.
-- Projection: the skill table's and the match's rule; an armour or aura left on a board branch or in the technique
-- list is never the page's); a copy of a card asks its owner card. nil = the option on Victory Road / no answer.
function EVT_PH_Projection(chara)
  local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
  if chara == nil or chara == 0 or type(page) ~= "table" or type(page.Projection) ~= "function" then
    return nil
  end
  local p = page.Projection(chara)
  if p == nil then
    local oko, owner = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_CHARA_OWNER"), chara)
    if oko and type(owner) == "number" and owner ~= 0 and owner ~= chara then
      p = page.Projection(owner)
    end
  end
  return p
end

function EVT_PH_MixOf(chara)
  if chara == nil or chara == 0 then
    return 0
  end
  local proj = EVT_PH_Projection(chara)
  if proj ~= nil then
    return EVT_PH_U32(proj.mix)
  end
  local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
  if type(page) ~= "table" or type(page.MixOf) ~= "function" then
    return 0
  end
  local id = page.MixOf(chara)
  if id == 0 then
    local oko, owner = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_CHARA_OWNER"), chara)
    if oko and type(owner) == "number" and owner ~= 0 and owner ~= chara then
      id = page.MixOf(owner)
    end
  end
  return EVT_PH_U32(id)
end

-- L3 on the Hiper page: both slots filled (graft plate_pages asks it)
function EVT_PH_CanSwitch(chara)
  return EVT_PH_MixOf(chara) ~= 0 and EVT_PH_AuraOf(chara) ~= 0
end

-- the page's move: the aura slot, the mix slot in the L3 view (or when the aura slot is empty)
function EVT_PH_Skill(chara)
  if chara == nil or chara == 0 then
    return 0
  end
  local aura = EVT_PH_AuraOf(chara)
  local mix = EVT_PH_MixOf(chara)
  if mix ~= 0 and (aura == 0 or EVT_PH_MX_VIEW) then
    return mix
  end
  return aura
end

function EVT_PH_AuraOf(chara)
  if chara == nil or chara == 0 then
    return 0
  end
  local proj = EVT_PH_Projection(chara)
  if proj ~= nil then
    return EVT_PH_U32(proj.aura)
  end
  local s = EVT_PH_Board(chara, 8)
  if EVT_PH_IsSpecial(s) then
    return s
  end
  for pos = 0, 5 do
    s = EVT_PH_U32(funcLuaCommand(C.GET_SKILL, chara, pos))
    if EVT_PH_IsSpecial(s) then
      return s
    end
  end
  for _, b in ipairs({5, 6, 7}) do
    s = EVT_PH_Board(chara, b)
    if EVT_PH_IsSpecial(s) then
      return s
    end
  end
  return 0
end

-- 2026-09-25 (Plantilla freeze, 13:54-14:14): the wrapper called the retail function through the GLOBAL
-- EVT_PHI.origSkl. EVT_PHI is created anew by every copy of this block, so a second copy set origSkl to the first
-- copy's wrapper, and that wrapper then called itself by tail call forever (a hang without any error) as soon as the
-- plate listed a move. The retail function is now captured in the wrapper's own closure (EVT_PH_Wrap: never wrapped
-- twice) and kept in EVT_PH_SKL_RETAIL for the direct calls below.
-- The retail function is taken at load: before the script's host runs, VRFW_Host.wrap builds the wrapper only at the
-- function's first call, so the direct calls cannot wait for make(orig). The first copy in this VM keeps it.
if EVT_PH_SKL_RETAIL == nil and type(SetSkillItemLayerName) == "function" then
  EVT_PH_SKL_RETAIL = SetSkillItemLayerName
end
EVT_PH_Wrap("SetSkillItemLayerName", function(orig)
  EVT_PH_SKL_RETAIL = EVT_PH_SKL_RETAIL or orig
  return function(...)
    EVT_PHI.skl = {...}
    return orig(...)
  end
end)
EVT_PHI.origSkl = EVT_PH_SKL_RETAIL

local function EVT_PH_Exists(layer)
  return funcLuaMenuCommand(C.EXIST_LAYER, layer) == true
end

-- 2026-09-28 (first view of the page showed «Sin hipertécnica»): a layer opened here is not usable in the same frame
-- (the fill's own LAYER_VISIBLE does not stick: IS_LAYER_VISIBLE answers false) and our panel layers are opened by the
-- first Hiper show of each plate (their group base does not open them). EVT_PHI.opened records that this draw opened
-- one, so EVT_PH_ShowInner draws the page once more on the next frame (EVT_PH_PENDING, PostStep).
local function EVT_PH_Open(layer, inst)
  inst = inst or 0
  if EVT_PH_Exists(layer) and not funcLuaMenuCommand(C.IS_OPEN_LAYER, layer, inst) then
    funcLuaMenuCommand(C.OPEN_LAYER, layer, inst)
    EVT_PHI.opened = true
    return true
  end
  return false
end

-- tension gauge scale: only a team the engine knows (the retail fills return early, before showing the window,
-- when this lookup fails)
local function EVT_PH_TeamInfo()
  local ok, ti = GetSoccerTeamInfo(0)
  if not ok or ti == nil or ti == 255 then
    return nil
  end
  local ok2 = funcLuaCommand(C.TENSION_SCALE, ti, true)
  if not ok2 then
    return nil
  end
  return ti
end

local function EVT_PH_Name(skill, style)
  local ok, nameId = funcLuaCommand(C.SKILL_INFO, skill, 4)
  if not ok or nameId == nil then
    return nil
  end
  if style ~= nil then
    return funcLuaCommand(C.NAME_TEXT, nameId, style)
  end
  return funcLuaCommand(C.NAME_TEXT, nameId)
end

local function EVT_PH_AuraType(skill)
  local ok, t = funcLuaCommand(C.SKILL_INFO, skill, 13)
  if ok and type(t) == "number" then
    return t
  end
  return nil
end

local function EVT_PH_NameWithType(name, skill)
  local t = EVT_PH_AuraType(skill)
  if EVT_PH_TYPE_IN_NAME and name ~= nil and t ~= nil and EVT_PH_TYPE_NAME[t] ~= nil then
    return string.format("%s (%s)", name, EVT_PH_TYPE_NAME[t])
  end
  return name
end

-- ---- page decoration: 5 dots + title (fix 2026-09-24) ---------------------------------------------------------
-- The plate uses our layout clone evt_soccer11_05 (personal_plate_menu settings only): the 10 dot meshes are re-spaced
-- into 5 centred positions (x -10, 18, 46, 74, 102; retail 4, 32, 60, 88) and _page02_on_rpg draws the "off" dot.
-- CMND_SET_MESH_VISIBLE wins over the visibility of the parent locator (retail lights _page01_on while _pos_page01 is
-- hidden), so every page change sets ALL of these meshes explicitly: the 5 off dots on, the lit dot of the page type,
-- the six-sense title / base only on type 3, and on type 5 the same title mesh with our "HIPERTÉCNICA" sprite.
-- (In the first version a mesh left explicitly visible stayed on every page: "PASIVAS PERSONALIZADAS" over ATRIBUTOS.)
EVT_PH_DOTS = true
local DOT_OFF = {3784855471 --[[_page01_off]], 2788701567 --[[_page02_off]], 2606243023 --[[_page03_off]],
  695779551 --[[_page04_off]], 1007698216 --[[_page02_on_rpg, off material]]}
-- lit dot per page TYPE: Atributos (1) dot 1, Hiper (5) dot 2, equipment (0) dot 3, passives (2) dot 4, six sense (3) 5
local DOT_ON = {[1] = 2540064569 --[[_page01_on]], [5] = 2996782795 --[[_page01_on_rpg]], [0] = 2245255383 --[[_page02_on]],
  [2] = 1030719410 --[[_page03_on]], [3] = 2696462091 --[[_page04_on]]}
local M_SIXTH_TITLE = 1621221814    -- _gtxt_sixthsense01 (title mesh of page 4, also our title on page type 5)
local M_SIXTH_BASE = 2682382918     -- _sixth_base01
local LOC_PAGE04 = 3145665477       -- _pos_page04 (parent of _atc_sixth01, where our windows are attached)
local TX_S1105 = 1156047165         -- #/menu/00_soccer/soccer11/soccer11_05/<LG>/soccer11_05.g4tx
local SP_SIXTH_TITLE = 2885965654   -- gtxt_sixthsense01 (sprite the title mesh is built with = swap node)
local SP_HIPER_TITLE = 1002432688   -- evt_gtxt_hiper01 (added to every soccer11_05.g4tx by the builder)

function EVT_PH_Decor(ptype)
  if not EVT_PH_DOTS or not EVT_PH_Exists(L_STATUS) then
    return
  end
  local L = L_STATUS
  -- the locator first: showing _pos_page04 shows its children again (its _page04_on = the lit dot 5; fix 3)
  local hiper = EVT_PLATE_HIPER and ptype == EVT_PH_TYPE
  if hiper then
    funcLuaMenuCommand(C.LOC_VISIBLE, L, LOC_PAGE04, true, 0)
  end
  for _, m in ipairs(DOT_OFF) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, true, 0)
  end
  for t, m in pairs(DOT_ON) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, t == ptype, 0)
  end
  funcLuaMenuCommand(C.SPRITE, L, TX_S1105, hiper and SP_HIPER_TITLE or SP_SIXTH_TITLE, SP_SIXTH_TITLE, 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, M_SIXTH_TITLE, hiper or ptype == 3, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, M_SIXTH_BASE, ptype == 3, 0)
  EVT_PH_HideArrowKeys()
end

-- the Q/E (LT/RT) key glyphs next to the plate's < > arrows are hidden: the bottom guide shows "Q E Desplazarte"
-- instead (common block). The arrows stay. Retail shows the glyphs again in SetStatusBaseArrowAndTextVisible.
-- 2026-09-25 (user): the retail Q / E key glyphs (_text_btn_l01 / _text_btn_r01, set and shown by the retail
-- SetStatusBaseArrowAndTextVisible with the device's glyphs) now sit by the page dots (our layout clone) and stay
-- visible; they paged out of sight next to the title arrows before
EVT_PH_HIDE_ARROW_KEYS = false
function EVT_PH_HideArrowKeys()
  if not EVT_PH_HIDE_ARROW_KEYS or not EVT_PH_Exists(L_STATUS) then
    return
  end
  funcLuaMenuCommand(2735666188, L_STATUS, 355816102 --[[_text_btn_l01]], false, 0)
  funcLuaMenuCommand(2735666188, L_STATUS, 59628764 --[[_text_btn_r01]], false, 0)
end

local function EVT_PH_Trace(label, on)
  if label ~= nil and label ~= 0 then
    funcLuaMenuCommand(C.TRACE, L_STATUS, 0, label, on)
  end
end

-- our labels on (page) or off with the retail state back
local function EVT_PH_Attach(on)
  if not EVT_PH_ON_PAGE or not EVT_PH_Exists(L_STATUS) then
    return
  end
  local rpg = evt_ph_plate_type == 2
  for _, a in ipairs(EVT_PH_ATTACH) do
    if on then
      EVT_PH_Trace(a[2], false)
      EVT_PH_Trace(a[3], false)
      EVT_PH_Trace(a[4], true)
    else
      EVT_PH_Trace(a[4], false)
      if a[5] then
        EVT_PH_Trace(a[2], not rpg)
        EVT_PH_Trace(a[3], rpg)
      else
        EVT_PH_Trace(a[2], true)
        EVT_PH_Trace(a[3], true)
      end
    end
  end
end

local function EVT_PH_HideWindows()
  for t = 0, 6 do
    if EVT_PH_Exists(AURA_WIN[t]) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, AURA_WIN[t], 0, false)
    end
  end
  for _, l in ipairs(AURA_LIST) do
    if EVT_PH_Exists(l) then
      funcLuaMenuCommand(C.LIST_VISIBLE, l, false)
    end
  end
  if EVT_PH_Exists(L_DETAIL) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, false)
  end
  if EVT_PH_Exists(L_GUIDE) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE, 0, false)
  end
  if EVT_PH_Exists(EVT_PHI.L) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.L, 0, false)
  end
  if EVT_PH_Exists(EVT_PHI.ROW) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.ROW, 0, false)
  end
  if EVT_PH_Exists(EVT_PHI.FACE) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.FACE, 0, false)
  end
end

-- nodes of team02_02 that the "empty" drawing hides and the retail fill does not show again
local function EVT_PH_ResetDetail()
  if not evt_ph_detail_dirty or not EVT_PH_Exists(L_DETAIL) then
    return
  end
  funcLuaMenuCommand(C.LOC_VISIBLE, L_DETAIL, 923022909 --[[_pos_tension01]], true, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L_DETAIL, 4081284803 --[[_pos_at01]], true, 0)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L_DETAIL, 0, 3424269865, true)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L_DETAIL, 0, 2223127589, true)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3516146179 --[[_area_base01]], true, 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_DETAIL, 1899787537 --[[_text_area01]], true, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 2164615260 --[[_icon_sp_area_dmy01]], true, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3543352325 --[[_icon_sp_area01_off]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 656425078 --[[_item_win_line01]], true, 0)
  evt_ph_detail_dirty = false
end

local function EVT_PH_ShowAura(skill, chara)
  local t = EVT_PH_AuraType(skill)
  local win = t ~= nil and AURA_WIN[t] or nil
  if win == nil or not EVT_PH_Exists(win) or UpdateAuraSkillDetailInfo == nil then
    return false, "no aura window", t
  end
  EVT_PH_Open(win)
  local ok, err = pcall(UpdateAuraSkillDetailInfo, skill, chara, nil, EVT_PH_TeamInfo(), 0)
  if not ok then
    return false, err, t
  end
  if not funcLuaMenuCommand(C.IS_LAYER_VISIBLE, win, 0) then
    return false, "window not shown", t
  end
  -- page 1 of the window only: no page guide, no page dots
  if EVT_PH_Exists(L_GUIDE) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE, 0, false)
  end
  funcLuaMenuCommand(C.LOC_VISIBLE, win, 1307475940 --[[_pos_list01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, win, 3571920478 --[[_pos_list02]], false, 0)
  local name = EVT_PH_NameWithType(EVT_PH_Name(skill, 11), skill)
  if name ~= nil then
    funcLuaMenuCommand(C.TEXT, win, 2915321899 --[[_text_fs01]], name, 0)
  end
  return true, "aura", t
end

local function EVT_PH_ShowDetail(skill, chara)
  if not EVT_PH_Exists(L_DETAIL) or SetupPersonalPlateSkillDetailInfo == nil then
    return false, "no detail window"
  end
  EVT_PH_ResetDetail()
  EVT_PH_Open(L_DETAIL)
  local ok, err = pcall(SetupPersonalPlateSkillDetailInfo, skill, chara, nil, EVT_PH_TeamInfo(), nil, true)
  if not ok then
    return false, err
  end
  if not funcLuaMenuCommand(C.IS_LAYER_VISIBLE, L_DETAIL, 0) then
    return false, "window not shown"
  end
  local name = EVT_PH_NameWithType(EVT_PH_Name(skill), skill)
  if name ~= nil then
    funcLuaMenuCommand(C.TEXT, L_DETAIL, 1704438437 --[[_text_name01]], name, 0)
  end
  return true, "detail"
end

-- team02_02 as the retail "empty slot" window of a special (SetupPersonalPlateSkillEnptyDetailInfo, category 8),
-- with our texts
local function EVT_PH_ShowEmpty()
  if not EVT_PH_Exists(L_DETAIL) then
    return false
  end
  EVT_PH_Open(L_DETAIL)
  local L = L_DETAIL
  evt_ph_detail_dirty = true
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, false)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3543352325 --[[_icon_sp_area01_off]], true, 0)
  funcLuaMenuCommand(C.SPRITE, L, TX_TEAM02_02, 2255856907 --[[icon_sp_area05_off]], 1945437131 --[[icon_sp_area01_off]], 0, 0)
  funcLuaMenuCommand(C.TEXT, L, 1899787537 --[[_text_area01]], "", 0)
  funcLuaMenuCommand(C.TEXT, L, 1704438437 --[[_text_name01]], EVT_PH_Text(EVT_PH_EMPTY_NAME_ID), 0)
  funcLuaMenuCommand(C.TEXT, L, 691026122 --[[_text_flavor01]], "", 0)   -- 2026-10-07: banner only, no hint text
  funcLuaMenuCommand(C.SPRITE, L, TX_TEAM02_02, 2575257044 --[[sp_base_blank02]], 243934124 --[[sp_base01]], 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260 --[[_icon_sp_area_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1220252763 --[[_gtxt_longshoot01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 559600405 --[[_icon_sp_sub_dmy01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 923022909 --[[_pos_tension01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 4081284803 --[[_pos_at01]], false, 0)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L, 0, 3424269865, false)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L, 0, 2223127589, false)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3516146179 --[[_area_base01]], false, 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, 1899787537 --[[_text_area01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 563708378 --[[_gtxt_cmd_at01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3384915402 --[[_wlv_base01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1013569271 --[[_ai_use01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 656425078 --[[_item_win_line01]], false, 0)   -- no description: no quote bar
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  return true
end

-- ---- integrated panel ---------------------------------------------------------------------------------------------
-- run a retail skill-detail fill with the detail layer pointed at our panel, then put the recorded arguments back
function EVT_PHI.Fill(fn, ...)
  local a = EVT_PHI.skl or {g_useFormationCharaSkillLayer, L_DETAIL, 0, 1803124851, 0, g_useFormationCharaSkillBlankLayer,
    g_useSkillAIUseMarkLayer}
  EVT_PHI.origSkl(a[1], EVT_PHI.L, 0, a[4], a[5], a[6], a[7])
  local ok, err = pcall(fn, ...)
  EVT_PHI.origSkl(a[1], a[2], a[3], a[4], a[5], a[6], a[7])
  return ok, err
end

-- what the page style never shows: the card, the element icons, the graded band, "IA activada", the check marks
function EVT_PHI.Clean(L)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3303013605 --[[_sp_win_base01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260 --[[_icon_sp_area_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3543352325 --[[_icon_sp_area01_off]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3384915402 --[[_wlv_base01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1013569271 --[[_ai_use01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 1417578953 --[[_pos_atc_check01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 3447183475 --[[_pos_atc_check02]], false, 0)
end

-- the aura character's PORTRAIT, drawn exactly as the retail aura windows draw it (user 2026-09-24: inside the band,
-- clipped by it, as the Spirit Market / board aura detail). Layer evt_ph_face is the retail team00_30 window with only
-- its two portrait quads on screen; their retail materials mask the face with icon_fs_msk_01 / icon_chr_win_msk01, so
-- it shows only inside the band's rect, at the band's right end. Mesh and icon type per aura type as retail
-- personal_plate_inc: keshin / armed -> _icon_fs_dmy01 type 8, soul -> _icon_fs_dmy01 type 14, miximax ->
-- _icon_chr_dmy01 type 12; kizuna / power / mode draw no portrait in retail, so none here.
EVT_PH_FACE_BY_TYPE = EVT_HC.FACE_BY_TYPE   -- round 14: one table (research/grafts/plate_hiper_plate/evt_hiper_card.lua)
-- the aura-type icon of the band's left slot (retail Update*DetailInfo: icon_common.g4tx onto icon_fs_area_dmy01):
-- keshin icon_sp_area05 (armour page 06), armed 06, miximax 07, soul 08, kizuna 09, awakening power 10, mode change 11
EVT_PH_TYPE_ICON = EVT_HC.TYPE_ICON
-- 2026-09-25 (in game the portrait did not show: the face layer drew under our panel's opaque band, and the mask keeps
-- the face inside the band rect): the header is now drawn exactly as the retail aura windows draw it, all in the face
-- layer (retail team00_30 meshes in their own draw order): band _fs_base01, type icon _icon_fs_area_dmy01, name
-- _text_fs01, masked portrait. The panel's own band / name stay hidden (they are used for the empty page only).
-- Miximax fusion of a base card (module miximax): nil or {partner = param, move, phdl, face, chara, name, best}
-- Asked: Inazuma Fantasy's CMND_EVT_MX_GET, else the page slot CMND_CHARACTERREFORGED_PAGE_FUSION (All Miximaxed's
-- running fusion of the card, the same answer + the partner's handle; 2026-10-14, owner: without Inazuma Fantasy the
-- card showed the generic carrier «Miximax Trans» and its row's move instead of the partner and his move).
EVT_PH_MX_CARRIER = 2450842569 --[[wmm_evt]]
function EVT_PHI.MxAsk(chara)
  local ok, exists, partner, m1, m2, pchara, best = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_MX_GET"), chara)
  if ok and exists then
    return ok, exists, partner, m1, m2, pchara, best, nil
  end
  local okp, pexists, ppartner, pm1, pm2, ppchara, pbest, phdl = pcall(funcLuaCommand, CALC_CRC("CMND_CHARACTERREFORGED_PAGE_FUSION"), chara)
  if okp and pexists == true then
    return okp, pexists, ppartner, pm1, pm2, ppchara, pbest, phdl
  end
  return ok, exists, partner, m1, m2, pchara, best, nil
end

function EVT_PHI.MxGet(chara)
  if chara == nil or chara == 0 then
    return nil
  end
  local ok, exists, partner, m1, m2, pchara, best, page_phdl = EVT_PHI.MxAsk(chara)
  if not ok or not exists then
    -- in a match the character is a copy: fusions are keyed by the saved card (the loader maps it back)
    local oko, owner = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_CHARA_OWNER"), chara)
    if oko and type(owner) == "number" and owner ~= 0 and owner ~= chara then
      ok, exists, partner, m1, m2, pchara, best, page_phdl = EVT_PHI.MxAsk(owner)
      if ok and exists then
        chara = owner
      end
    end
  end
  if not ok or not exists then
    return nil
  end
  local f = {partner = partner or 0, move = m1 or 0, chara = pchara or 0, best = best == true or best == 1}
  if type(page_phdl) == "number" and page_phdl ~= 0 then
    f.phdl = page_phdl
  else
    local okh, phdl = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_MIXIMAX_GET"), chara)
    f.phdl = okh and type(phdl) == "number" and phdl or 0
  end
  -- the face-icon key retail uses for a miximax partner (the retail miximax window path), not the chara id
  local okk, face = pcall(funcLuaCommand, 347353059, f.partner)
  f.face = (okk and type(face) == "number" and face ~= 0) and face or f.chara
  local okn, a, b = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], f.chara, 10)
  f.name = (okn and type(b) == "string" and b) or (okn and type(a) == "string" and a) or nil
  return f
end

-- «Modo cambio» (2026-10-04, user: the card shows the character, as a miximax): the equipped change of a player
-- whose Hiper is a mode-change carrier (auraType 6). nil or {face, name, chara}; drawn with the miximax portrait quad.
EVT_PH_MC_TYPE = EVT_HC.MC_TYPE
EVT_PHI.McGet = EVT_HC.McGet         -- shared card component (evt_hiper_card.lua)

-- the aura band under the move row (face layer instance 1): the retail aura header of `aura` (band by aura type and
-- element, type icon, name, masked keshin / totem art), exactly as instance 0 draws the Hiper's; nil = hidden
-- the grey quote bar left of the description (_text_flavor01): the retail skill detail's line mesh
EVT_PH_QUOTE_MESH = {656425078 --[[_item_win_line01]]}
function EVT_PHI.QuoteBar(L, on)
  for _, m in ipairs(EVT_PH_QUOTE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, on, 0)
  end
end

-- `inst` = face-layer instance (1 = first band under the Hiper's move row, 2 = second; default 1). nil / 0 aura: that
-- instance hidden. 2026-09-28: the instance is OPENED here (before, only instance 0 was ever opened, so the band of
-- 16.28 never showed in game although "aura band" was logged).
function EVT_PHI.AuraBand(aura, inst)
  local F = EVT_PHI.FACE
  inst = inst or 1
  if not EVT_PH_Exists(F) or inst >= EVT_PHI.Slots().face then
    return
  end
  if aura == nil or aura == 0 then
    if funcLuaMenuCommand(C.IS_OPEN_LAYER, F, inst) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, F, inst, false)
    end
    return
  end
  EVT_PH_Open(F, inst)
  local t = EVT_PH_AuraType(aura)
  local name = EVT_PH_Name(aura)
  -- PEG mode (2026-10-04, user): the spirit's PEG (a totem's SP) on its card
  if not EVT_PH_Exists(EVT_PHI.POOL) then
    name = EVT_HC.PoolName(name, EVT_PHI.PegInfo(aura))
  end
  EVT_HC.Header(F, aura, name, inst)  -- same header component as the main EG card
  funcLuaMenuCommand(C.MESH_VISIBLE, F, 2449339029 --[[_icon_fs_dmy01]], false, inst)
  funcLuaMenuCommand(C.MESH_VISIBLE, F, 478320441 --[[_icon_chr_dmy01]], false, inst)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], F, inst, 1051570875 --[[icon_fs_dmy01]])
  funcLuaMenuCommand(4176779611 --[[clear face icon]], F, inst, 3237726902 --[[icon_chr_dmy01]])
  local okc, cid = funcLuaCommand(C.SKILL_INFO, aura, 17)
  local face = t ~= nil and EVT_PH_FACE_BY_TYPE[t] or nil
  if okc and cid ~= nil and cid ~= 0 and face ~= nil then
    funcLuaMenuCommand(C.MESH_VISIBLE, F, face[1], true, inst)
    funcLuaMenuCommand(346643487 --[[SwapLayerFaceIconTex]], F, inst, face[1], face[2], cid, 0, face[3], true, true, true, 5)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, F, inst, true)
  EVT_PH_Log("aura band", inst, string.format("%08X", aura), tostring(t), tostring(cid),
    tostring(funcLuaMenuCommand(C.IS_LAYER_VISIBLE, F, inst)))
end

-- ---- extra blocks under the Hiper's move row (2026-09-28, user: the keshin / totem a miximax grants, its armour) ----
-- Layout data (plate_hiper_build.py, PH_EXTRA_* / PH_TENS_*): face layer evt_ph_face has 3 instances (0 header, 1 and 2
-- = aura bands), row layer evt_ph_move_row 3 (0 = the Hiper's move, 1 and 2 = the moves of those auras), tension layer
-- evt_ph_tension 2 (the TENSIÓN gauge of extra rows 1 and 2), attached at the joints _atc_evt_face02/03,
-- _atc_evt_move02/03 and _atc_evt_tens02/03 of evt_ph_detail. Older installed data (face 2 instances, row 1, no
-- tension layer) is detected with CMND_GET_MESH_POSE and keeps the single band (no extra rows).
-- A block = band, then (14 px under it, as the header and the Hiper's row) the aura's move row with AT and its TENSIÓN.
-- The blocks are stacked under the Hiper's move row between local y EXTRA_TOP and EXTRA_BOTTOM (the page dots are at
-- about -269); when they do not fit at full size, every extra block is scaled down by the same factor
-- (CMND_SET_LAYER_LOCAL_SCALE / _POS on the attached instances, as retail scales its attached card blanks).
-- A keshin the player can also armour (loader: armed form exists for that keshin AND fits this player's body, the
-- match rule of keshin_armed) gets the retail armed badge _gtxt_cmd_armed01 («Armadura»). 2026-09-28 (user): the tag is
-- CENTRED on the BOTTOM EDGE of that spirit card (half on it, half under it), drawn above the card and above the move
-- row under it (EVT_PHI.ArmourTag, layer evt_ph_armour_tag); before it was the move row's own badge, drawn over the
-- row's AT value. Only without that layer (older installed data) the move row's badge is used, as before.
-- EVT_PH_ARMOUR_BAND = true also draws the armour's own band (off: the tag says it).
EVT_PH_ARMOUR_BAND = false
EVT_PHI.GEO = {
  EXTRA_TOP = -30, EXTRA_BOTTOM = -250,            -- local y (up) of evt_ph_detail's _pos_base01; screen y = 720 - y
  GAP = 10, BAND_ROW_GAP = 14,                      -- between blocks / between a band and its row
  BAND_H = 88, BAND_TOP = 160, BAND_X = -473,     -- face layer: band top / left inside the layer (PH_BAND_TOP, PH_X0)
  ROW_H = 76, ROW_TOP = 34, ROW_L = -267,          -- row layer: quad top / left around its origin
  ROW_X = -453,                                    -- the rows' left edge on the page (PH_X0 + 20)
  TENS_DX = 411, TENS_DY = 6,                      -- tension group origin from the row origin (PH_TENS_X - PH_ROW_X)
  FACE_J = {[1] = {0, -205}, [2] = {0, -410}},     -- _atc_evt_face02 / 03
  ROW_J = {[1] = {-186, -181}, [2] = {-186, -386}}, -- _atc_evt_move02 / 03 (PH_ROW_X, PH_ROW_Y - 205 / - 410)
  TENS_J = {[1] = {225, -175}, [2] = {225, -380}},  -- _atc_evt_tens02 / 03 (PH_TENS_X, PH_ROW_Y + 6 - 205 / - 410)
  -- the «Armadura» tag (EVT_PHI.ArmourTag): band width (PH_BAND_W), tag joint _atc_evt_armour01 (the _pos_base01
  -- origin), tag size factor on the retail 120 x 48 badge (0.8: its lower half, 19 px, stays clear of the "AT" label
  -- of the row under the card, 21 px below the card's edge), draw priority (face layer 570, move rows 302)
  BAND_W = 930, TAG_J = {0, 0}, TAG_K = 0.8, TAG_PRIO = 580,
}
EVT_PHI.TENS = 2195032298           -- crc32("evt_ph_tension")
EVT_PHI.TAG = 557534261             -- crc32("evt_ph_armour_tag")
-- the PEG pool on the header spirit card (2026-10-04, user: «170 PEG» centred ON the card in the TENSIÓN digits,
-- behind the «Armadura» tag): layer evt_ph_peg_pool (Character Reforged content\menus\player_page_layers.toml: one more evt_ph_tension
-- group, hung where the extra rows' first TENSIÓN hangs, joint GEO.TENS_J[1]); scaled POOL_K, the «170 PEG» centre
-- (POOL_CX, POOL_CY in the group's own coordinates: the 24-high number extends down from y=5, centre y=-7);
-- priority between the card (570) and the tag (580). Without the layer (older data) the pool goes into the name.
EVT_PHI.POOL = 1160095859           -- crc32("evt_ph_peg_pool")
EVT_PHI.POOL_K, EVT_PHI.POOL_CX, EVT_PHI.POOL_CY, EVT_PHI.POOL_PRIO = 3.0, 180, -7, 575
EVT_PHI.POOL_DX, EVT_PHI.POOL_DY = 0, 0
EVT_PHI.POOL_LOGS = 0
C.DRAW_PRIORITY = 1491630496        -- CMND_SET_DRAW_PRIORITY (layer, inst, prio, bool)
C.MESH_POSE = 2373227714            -- CMND_GET_MESH_POSE (layer, inst, node) -> x, y, z, found
C.LOCAL_POS = 1389957207            -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, inst)
C.LOCAL_SCALE = 3778714801          -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, inst)

-- instances the installed data has: {face = 2 or 3, row = 1 or 3, tens = 0 or 2}; the new layout is remembered once seen
local function EVT_PH_PoseY(L, node)
  local ok, _, y = pcall(funcLuaMenuCommand, C.MESH_POSE, L, 0, node)
  return ok and type(y) == "number" and y or nil
end
function EVT_PHI.Slots()
  if EVT_PHI.slots ~= nil then
    return EVT_PHI.slots
  end
  local L = EVT_PHI.L
  if EVT_PH_Exists(L) and funcLuaMenuCommand(C.IS_OPEN_LAYER, L, 0) then
    local y1 = EVT_PH_PoseY(L, 147811605 --[[_atc_evt_face01]])
    local y3 = EVT_PH_PoseY(L, 3871411257 --[[_atc_evt_face03]])
    local yt = EVT_PH_PoseY(L, 3231268576 --[[_atc_evt_tens02]])
    if y1 ~= nil and y3 ~= nil and y1 - y3 > 300 then
      local tens = (yt ~= nil and y1 - yt > 100 and EVT_PH_Exists(EVT_PHI.TENS)) and 2 or 0
      EVT_PHI.slots = {face = 3, row = 3, tens = tens}
      EVT_PH_Log("layout", "3 extra slots", "tension", tens, y1, y3, tostring(yt))
      return EVT_PHI.slots
    end
  end
  return {face = 2, row = 1, tens = 0}
end

-- the extra instances (face 1.., row 1.., tension 0..) hidden
function EVT_PHI.HideExtras()
  local n = EVT_PHI.Slots()
  for i = 1, n.face - 1 do
    pcall(EVT_PHI.AuraBand, nil, i)
  end
  for _, lt in ipairs({{EVT_PHI.ROW, 1, n.row - 1}, {EVT_PHI.TENS, 0, n.tens - 1}, {EVT_PHI.TAG, 0, 0},
      {EVT_PHI.POOL, 0, 2}}) do
    if EVT_PH_Exists(lt[1]) then
      for i = lt[2], lt[3] do
        if funcLuaMenuCommand(C.IS_OPEN_LAYER, lt[1], i) then
          funcLuaMenuCommand(C.LAYER_VISIBLE, lt[1], i, false)
        end
      end
    end
  end
end

-- one extra move row (row instance `inst`): the retail SetupCharaSkillItem with the row layer pointed at ours, as
-- EVT_PHI.SpiritMove does for instance 0 (name, element pill, AT power). `armed` = show the retail armed badge.
-- Returns true when drawn.
function EVT_PHI.ExtraRow(inst, move, chara, armed)
  local R = EVT_PHI.ROW
  if move == nil or move == 0 or not EVT_PH_Exists(R) or SetupCharaSkillItem == nil or inst >= EVT_PHI.Slots().row
      or type(VRFW_UI) ~= "table" then
    return false
  end
  -- the shared move plate (VRFW_UI.MovePlate.Fill; 2026-10-13: the move's OWN evolution grade, the rows showed the
  -- grade of skill_list[inst]), pointed through the retail function under this block's recorder and set back to the
  -- recorded arguments; the retail row shows the armed badge for armed aura skills (IsAuraSkillKeshinArmed): forced
  local a = EVT_PHI.skl or {g_useFormationCharaSkillLayer, L_DETAIL, 0, 1803124851, 0, g_useFormationCharaSkillBlankLayer,
    g_useSkillAIUseMarkLayer}
  local okf, err = VRFW_UI.MovePlate.Fill(R, inst, chara, move, {set = EVT_PHI.origSkl, page = a[2], page_inst = a[3],
    point = a, restore = a, open = EVT_PH_Open, armed = armed == true})
  if not okf then
    EVT_PH_Log("extra move row failed", inst, string.format("%08X", move), tostring(err))
    return false
  end
  return true
end

-- the «Armadura» tag: the retail armed badge _gtxt_cmd_armed01 on its own layer evt_ph_armour_tag
-- (plate_hiper_build.py PH_TAG_*: the soccer11_09 move row with only the badge on screen, centred on the layer origin;
-- attached at _atc_evt_armour01; draw priority GEO.TAG_PRIO, over the spirit card and the move row under it).
-- `at` = {x, y} of the tag's centre in evt_ph_detail's _pos_base01 coordinates (the spirit card's bottom edge centre),
-- `s` = the blocks' scale; nil = hidden. Returns false without the layer (older installed data).
function EVT_PHI.ArmourTag(at, s)
  local T = EVT_PHI.TAG
  if not EVT_PH_Exists(T) then
    return false
  end
  if at == nil then
    if funcLuaMenuCommand(C.IS_OPEN_LAYER, T, 0) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, T, 0, false)
    end
    if EVT_PHI.armourAt ~= nil then
      EVT_PHI.armourAt = nil
      pcall(EVT_PHI.PegTagPlace)
    end
    return true
  end
  local G = EVT_PHI.GEO
  EVT_PH_Open(T, 0)
  EVT_PHI.armourAt = at                             -- round 12: the pool plate goes left of the badge
  pcall(EVT_PHI.PegTagPlace)
  local k = (s or 1) * G.TAG_K
  funcLuaMenuCommand(C.MESH_VISIBLE, T, 1206374040 --[[_gtxt_cmd_armed01]], true, 0)
  funcLuaMenuCommand(C.LOCAL_SCALE, T, k, k, 1, 0)
  funcLuaMenuCommand(C.LOCAL_POS, T, at[1] - G.TAG_J[1], at[2] - G.TAG_J[2], 0, 0)
  pcall(funcLuaMenuCommand, C.DRAW_PRIORITY, T, 0, G.TAG_PRIO, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, T, 0, true)
  EVT_PH_Log("armour tag", string.format("%.1f", at[1]), string.format("%.1f", at[2]), string.format("%.2f", k))
  return true
end

-- 2026-09-28 (user): a keshin Hiper that the player can arm on HIS body gets the same «Armadura» tag, centred on the
-- bottom edge of the header spirit card (face instance 0: band top GEO.BAND_TOP, GEO.BAND_H high, not scaled; the
-- Hiper's move row is 14 px under it, as in the extras). Loader CMND_EVT_HIPER_ARMOUR(chara, hiper) -> armour, param:
-- the match rule of keshin_armed (pairing, else an armour part with a mesh for his body group, installed chara_parts);
-- 0 = none. A match character is a copy: the loader maps it to its saved card, and param 0 (handle unknown) is asked
-- again with CMND_EVT_CHARA_OWNER's card. Without the command (older loader) nothing is shown.
function EVT_PHI.HiperArmourTag(skill, chara)
  if EVT_PH_AuraType(skill) ~= 0 or chara == nil or chara == 0 then
    return false
  end
  local cmd = CALC_CRC("CMND_EVT_HIPER_ARMOUR")
  local ok, armour, param = pcall(funcLuaCommand, cmd, chara, skill)
  if ok and (type(param) ~= "number" or param == 0) then
    local oko, owner = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_CHARA_OWNER"), chara)
    if oko and type(owner) == "number" and owner ~= 0 and owner ~= chara then
      ok, armour, param = pcall(funcLuaCommand, cmd, owner, skill)
    end
  end
  local has = ok and type(armour) == "number" and armour ~= 0
  EVT_PH_Log("hiper armour", string.format("%08X", skill), tostring(armour), tostring(param))
  if not has then
    return false
  end
  local G = EVT_PHI.GEO
  return EVT_PHI.ArmourTag({G.BAND_X + G.BAND_W / 2, G.BAND_TOP - G.BAND_H}, 1)
end

-- the TENSIÓN gauge of extra row `k` (tension instance k - 1): the move's own cost, squares by the retail formula
-- (cost / team scale × 10, the scale of the match team, else the menus' global one), as EVT_PHI.SpiritMove does
function EVT_PHI.ExtraTension(k, move, aura)
  local T, inst = EVT_PHI.TENS, k - 1
  if inst < 0 or inst >= EVT_PHI.Slots().tens or not EVT_PH_Exists(T) or type(VRFW_UI) ~= "table" then
    return false
  end
  local okc, cost = funcLuaCommand(C.SKILL_INFO, move, 11)
  -- a keshin / armour / totem move in PEG mode: its PEG (SP) cost in purple, squares = cost / pool × 10
  local peg = EVT_PHI.PegInfo(aura)
  if peg ~= nil then
    okc, cost = true, peg.cost
  end
  if not okc or type(cost) ~= "number" then
    return false
  end
  EVT_PH_Open(T, inst)
  -- the shared TENSIÓN gauge (VRFW_UI.MovePlate.Tension): the match team's scale, else the menus' global one
  local steps, scale = VRFW_UI.MovePlate.Tension(T, inst, cost, {scale = peg ~= nil and peg.pool or nil,
    teams = table.pack(EVT_PH_TeamInfo(), 255), look = function(l, i)
      pcall(EVT_PHI.PegLook, l, i, peg ~= nil, peg and peg.kind)
    end})
  funcLuaMenuCommand(C.LAYER_VISIBLE, T, inst, true)
  EVT_PH_Log("extra tension", k, string.format("%08X", move), cost, tostring(scale), steps)
  return true
end

-- the blocks a fusion adds under the Hiper's move row: {kind = "band" | "row", ...} in page order
-- MX_AURA -> aura, kind (1 partner keshin / totem, 2 base's own armour), armour (loader 2026-09-28: the armed form of
-- the partner keshin this base can wear, 0 = none; nil with an older loader = no badge)
function EVT_PHI.FusionExtras(chara, fusion)
  local out = {}
  local oka, aura, kind, armour = pcall(funcLuaCommand, CALC_CRC("CMND_EVT_MX_AURA"), chara)
  if not oka or type(aura) ~= "number" or aura == 0 then
    return out, oka and aura or nil, kind
  end
  local canArmour = kind == 1 and type(armour) == "number" and armour ~= 0 and armour ~= aura
  -- the partner's keshin / totem is the partner's: its move drawn with the partner's handle (his element colour);
  -- the base's own armour (kind 2) with the base's
  local mover = (kind == 1 and fusion ~= nil and fusion.phdl ~= 0) and fusion.phdl or chara
  -- `armour`: the «Armadura» tag on this spirit card (EVT_PHI.ArmourTag); `armed`: the row's own badge, used only
  -- without the tag layer
  out[#out + 1] = {kind = "band", aura = aura, armour = canArmour}
  local okm, move = EVT_PHI.AuraMove(aura)
  if okm and move ~= 0 then
    out[#out + 1] = {kind = "row", move = move, chara = mover, armed = canArmour, aura = aura}
  end
  if canArmour and EVT_PH_ARMOUR_BAND then
    out[#out + 1] = {kind = "band", aura = armour}
    local oka2, amove = EVT_PHI.AuraMove(armour)
    -- an armour's move is usually its keshin's (loader aura_move): shown once
    if oka2 and amove ~= 0 and amove ~= move then
      out[#out + 1] = {kind = "row", move = amove, chara = chara, aura = armour}
    end
  end
  return out, aura, kind, armour
end

-- draw `blocks` stacked under the Hiper's move row, compacted to fit
function EVT_PHI.ShowExtras(blocks)
  local n = EVT_PHI.Slots()
  local G = EVT_PHI.GEO
  if n.row < 2 then
    -- older data: only the first band, at its joint (no move rows, no scaling)
    for _, b in ipairs(blocks) do
      if b.kind == "band" then
        EVT_PHI.AuraBand(b.aura, 1)
        return 1
      end
    end
    return 0
  end
  -- what fits: at most 2 bands and 2 rows (the instances)
  local list, nb, nr = {}, 0, 0
  for _, b in ipairs(blocks) do
    if b.kind == "band" and nb < n.face - 1 then
      nb = nb + 1
      b.inst = nb
      list[#list + 1] = b
    elseif b.kind == "row" and nr < n.row - 1 then
      nr = nr + 1
      b.inst = nr
      list[#list + 1] = b
    end
  end
  if #list == 0 then
    return 0
  end
  -- gaps (not scaled) and heights (scaled)
  local gaps, hsum = 0, 0
  for i, b in ipairs(list) do
    hsum = hsum + (b.kind == "band" and G.BAND_H or G.ROW_H)
    if i > 1 then
      gaps = gaps + ((b.kind == "row" and list[i - 1].kind == "band") and G.BAND_ROW_GAP or G.GAP)
    end
  end
  local s = math.min(1, (G.EXTRA_TOP - G.EXTRA_BOTTOM - gaps) / hsum)
  local top = G.EXTRA_TOP
  local tagLayer = EVT_PH_Exists(EVT_PHI.TAG)
  local tag = nil                                   -- centre of the «Armadura» tag: the armoured card's bottom edge
  for i, b in ipairs(list) do
    if i > 1 then
      top = top - ((b.kind == "row" and list[i - 1].kind == "band") and G.BAND_ROW_GAP or G.GAP)
    end
    if b.kind == "band" then
      local j = G.FACE_J[b.inst]
      EVT_PHI.AuraBand(b.aura, b.inst)
      funcLuaMenuCommand(C.LOCAL_SCALE, EVT_PHI.FACE, s, s, 1, b.inst)
      funcLuaMenuCommand(C.LOCAL_POS, EVT_PHI.FACE, G.BAND_X * (1 - s), top - j[2] - G.BAND_TOP * s, 0, b.inst)
      EVT_PHI.PoolTag(EVT_PHI.PegInfo(b.aura), b.inst, top, s)
      if b.armour and tagLayer and tag == nil then
        tag = {G.BAND_X + G.BAND_W * s / 2, top - G.BAND_H * s}
      end
      top = top - G.BAND_H * s
    else
      local j = G.ROW_J[b.inst]
      if EVT_PHI.ExtraRow(b.inst, b.move, b.chara, b.armed == true and not tagLayer) then
        local ox, oy = G.ROW_X - G.ROW_L * s, top - G.ROW_TOP * s      -- the row's origin on the page
        funcLuaMenuCommand(C.LOCAL_SCALE, EVT_PHI.ROW, s, s, 1, b.inst)
        funcLuaMenuCommand(C.LOCAL_POS, EVT_PHI.ROW, ox - j[1], oy - j[2], 0, b.inst)
        local tj = G.TENS_J[b.inst]
        if tj ~= nil and EVT_PHI.ExtraTension(b.inst, b.move, b.aura) then
          funcLuaMenuCommand(C.LOCAL_SCALE, EVT_PHI.TENS, s, s, 1, b.inst - 1)
          funcLuaMenuCommand(C.LOCAL_POS, EVT_PHI.TENS, ox + G.TENS_DX * s - tj[1], oy + G.TENS_DY * s - tj[2], 0,
            b.inst - 1)
        end
        top = top - G.ROW_H * s
      end
    end
  end
  pcall(EVT_PHI.ArmourTag, tag, s)
  EVT_PH_Log("extras", #list, string.format("%.2f", s), "armour tag", tostring(tag ~= nil))
  return #list
end

-- the pool tag on the header card; peg nil = hidden. Returns true when the layer exists (the name then has no pool)
-- 2026-10-06 (player page round 10): the «PEG» / «SP» word is a small plate LEFT of the pool number, like the
-- «Armadura» badge, in the game's font: layer evt_ph_peg_tag (object evt_ph_peg_pill: team02_02's «type · cost» pill and
-- its text node; Character Reforged content/menus/player_page_layout.toml), text menu_text evt_ph_peg_label / evt_ph_sp_label (per language);
-- the pool's own unit after the number is hidden. Placed from the number placeholder's pose (as passive_config places
-- its title tag); EVT_PHI.PEG_TAG_DX / DY move it, EVT_PHI.PEG_TAG_K sizes it.
EVT_PHI.PEG_TAG = CALC_CRC("evt_ph_peg_tag")
-- round 12 (Nacho, «Metis 200 PEG Armadura»): no big pool number over the card any more; the pool is ONE small plate
-- «200 PEG» / «250 SP» (the evt_ph_peg_pill pill in the game's font, tinted PEG purple / SP blue) LEFT of the «Armadura»
-- badge under the card, or at the card's right edge (under it) without a badge. Placed in the face layer's frame like
-- the badge (same align / scale); EVT_PHI.PEG_GAP = centre distance from the badge, PEG_RIGHT = from the right edge,
-- PEG_TAG_DX / DY nudge it, PEG_TAG_K sizes it.
EVT_PHI.PEG_TAG_K, EVT_PHI.PEG_TAG_DX, EVT_PHI.PEG_TAG_DY = 0.55, 0, 0
EVT_PHI.PEG_GAP, EVT_PHI.PEG_RIGHT = 170, 110
EVT_PHI.pegState, EVT_PHI.armourAt = nil, nil
function EVT_PHI.PegTagPlace()
  local T, st = EVT_PHI.PEG_TAG, EVT_PHI.pegState
  if st == nil or not EVT_PH_Exists(T) then
    return
  end
  local peg = st.peg
  EVT_PH_Open(T, 0)
  local key = CALC_CRC(peg.kind == 2 and "evt_ph_sp_label" or "evt_ph_peg_label")
  local okt, unit = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], key)
  if not okt or type(unit) ~= "string" or unit == "" then
    unit = peg.kind == 2 and "SP" or "PEG"
  end
  local text = string.format("%d %s", math.floor(peg.pool + 0.5), unit)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], T, 1899787537 --[[_text_area01]], text, 0)
  funcLuaMenuCommand(2735666188, T, 1899787537, true, 0)
  local c = peg.kind == 2 and EVT_HC.SP_RGB or EVT_HC.PEG_RGB
  pcall(funcLuaMenuCommand, 855211291 --[[CMND_SET_PRIM_COLOR]], T, 0, 3516146179 --[[_area_base01]], c[1], c[2], c[3])
  local G, s = EVT_PHI.GEO, st.s or 1
  local x, y
  local a = EVT_PHI.armourAt
  if a ~= nil then
    x, y = a[1] - EVT_PHI.PEG_GAP, a[2]
  else
    x, y = G.BAND_X + G.BAND_W * s - EVT_PHI.PEG_RIGHT, (st.top or G.BAND_TOP) - G.BAND_H * s
  end
  local k = EVT_PHI.PEG_TAG_K
  funcLuaMenuCommand(C.LOCAL_SCALE, T, k, k, 1, 0)
  funcLuaMenuCommand(C.LOCAL_POS, T, x + EVT_PHI.PEG_TAG_DX, y + EVT_PHI.PEG_TAG_DY, 0, 0)
  pcall(funcLuaMenuCommand, C.DRAW_PRIORITY, T, 0, G.TAG_PRIO, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, T, 0, true)
  if (EVT_PHI.PEG_TAG_LOGS or 0) < 6 then
    EVT_PHI.PEG_TAG_LOGS = (EVT_PHI.PEG_TAG_LOGS or 0) + 1
    EVT_PH_Log("peg plate", text, string.format("%.1f", x), string.format("%.1f", y), tostring(a ~= nil))
  end
end

-- peg nil = hidden (only when it is this instance's plate, or no instance given: another band without a pool must
-- not hide the header's plate)
function EVT_PHI.PegTag(peg, inst, cardTop, cardScale)
  local T = EVT_PHI.PEG_TAG
  if peg == nil then
    local st = EVT_PHI.pegState
    if inst ~= nil and st ~= nil and st.inst ~= inst then
      return
    end
    EVT_PHI.pegState = nil
    if EVT_PH_Exists(T) and funcLuaMenuCommand(C.IS_OPEN_LAYER, T, 0) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, T, 0, false)
    end
    return
  end
  EVT_PHI.pegState = {peg = peg, inst = inst or 0, top = cardTop, s = cardScale or 1}
  EVT_PHI.PegTagPlace()
end

-- the pool of a card: the big centred number (the tension group x 3, layer evt_ph_peg_pool) hidden; the plate shows
-- it. Returns true when the pool layer exists (the name then carries no pool)
function EVT_PHI.PoolTag(peg, inst, cardTop, cardScale)
  inst = inst or 0
  local P = EVT_PHI.POOL
  if EVT_PH_Exists(P) and funcLuaMenuCommand(C.IS_OPEN_LAYER, P, inst) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, P, inst, false)
  end
  pcall(EVT_PHI.PegTag, peg, inst, cardTop, cardScale)
  return EVT_PH_Exists(P)
end

function EVT_PHI.Portrait(L, skill, fusion, mc)
  local F = EVT_PHI.FACE
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2164615260 --[[_icon_sp_area_dmy01]], false, 0)
  if not EVT_PH_Exists(F) then
    return false
  end
  EVT_PH_Open(F)
  funcLuaMenuCommand(C.LAYER_VISIBLE, F, 0, false)
  local t = EVT_PH_AuraType(skill)
  -- band, type icon, name: the shared header (EVT_HC.Header); the name «Miximax Trans: X» / «Modo cambio: X» /
  -- name (+ «· PEG n»)
  local name = EVT_HC.Title(EVT_PH_Name(skill), fusion, mc)
  if fusion == nil and mc == nil and not EVT_PH_Exists(EVT_PHI.POOL) then
    name = EVT_HC.PoolName(name, EVT_PHI.PegInfo(skill))          -- older data: the pool in the name
  end
  local icon = EVT_HC.Header(F, skill, name, 0)
  -- the panel's own band / name / type line: hidden (the face layer draws the header)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1125548721 --[[_sp_base01]], false, 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, 1704438437 --[[_text_name01]], false, 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, 1899787537 --[[_text_area01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3516146179 --[[_area_base01]], false, 0)
  -- the portrait (masked quad), for the types retail draws one for
  -- every show starts from a clean face source (2026-09-25: after a fusion's plain-icon fallback the next retail
  -- miximax showed that plain icon); round 14: the shared rule EVT_HC.Portrait (the skill table's aura card uses it
  -- too); a partner on purpose: context "plate_page" of module appearance
  local cid = EVT_HC.Portrait(F, skill, fusion, mc, "plate_page", 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, F, 0, true)
  -- the power ("AT" + number) sits at the band's right end, under the portrait
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 563708378 --[[_gtxt_cmd_at01]], false, 0)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L, 0, 2223127589, false)
  EVT_PH_Log("face", string.format("%08X", skill), tostring(t), tostring(cid), tostring(icon),
    tostring(funcLuaMenuCommand(C.IS_LAYER_VISIBLE, F, 0)))
  return true
end

-- the spirit's own move (keshin -> its supertécnica, retail SKILL_INFO(aura, 16) = the "change skill", as
-- UpdateChangeSkillPage reads it) as an ATRIBUTOS move row: layer evt_ph_move_row (the retail soccer11_09 row objbin)
-- filled by the retail SetupCharaSkillItem with the row layer pointed at ours; the panel's TENSIÓN gauge then shows
-- that move's cost, and the aura's own cost goes into the tag ("Keshin · 1 T")
-- the supertécnica an aura shows (2026-09-25: every aura with a move, not only keshin / totem): the game's change
-- skill (SKILL_INFO 16), else the loader's (armed forms: the change skill of their keshin)
EVT_PHI.AuraMove = EVT_HC.AuraMove     -- shared card component (no move for a mode change)

-- PEG look of a tension group (2026-10-04, user: a keshin card shows its PEG, and its move's cost as «PEG» in purple,
-- not TENSIÓN): the «TENSIÓN» label swapped for evt_gtxt_peg01 (team02_02, research/scripts/plate_peg_build.py), the
-- squares / number / track tinted purple, the «T» hidden. on = false: the retail look back (white tint, retail label).
EVT_PH_PEG_RGB = EVT_HC.PEG_RGB
EVT_PH_TEAM02 = 3964676290 --[[#/menu/102_team/team02/team02_02/<LG>/team02_02.g4tx]]
EVT_PHI.PegInfo = EVT_HC.PegInfo
EVT_PHI.PegLook = EVT_HC.PegLook
-- the keshin's PEG (or the totem's SP) at the band's right end, where retail draws a move's power: label + number
EVT_PHI.PegPool = EVT_HC.PegPool

-- 2026-10-12 (owner: «show the keshin's PEG too, right of the move's PEG, same style»): on a keshin / armour / totem
-- Hiper in PEG mode the move row's gauge («▪▪▪ 150 PEG», the move's cost in the pool) and, right of it, the pool
-- itself as a second gauge of the same look («▪▪▪ 200 PEG», every square lit: the full pool; SP for a totem). The
-- pool is EVT_PHI.PegInfo's (CMND_EVT_PEG_INFO, served by IF's scripts\stamina.lua from the same peg.toml / sp.toml
-- pools the match uses), never a number of ours. Both gauges lose their left label and are scaled POOL_ROW_K so the
-- two fit between the move row's right end and the card's right end (GEO: page x 75..457); the pool gauge is
-- instance 0 of layer evt_ph_peg_pool (a tension group hung at GEO.TENS_J[1]; the big pool number of round <12 is
-- gone, so the instance is free). Without PEG (or without the layer) the move gauge goes back to its retail place.
-- loader.log «hiper pool gauge <pool> <kind> main <x> pool <x> <y> pose <...>». Knobs EVT_PHI.POOL_ROW_K / _GAP /
-- _RIGHT / _DY.
EVT_PHI.POOL_ROW_K, EVT_PHI.POOL_ROW_GAP, EVT_PHI.POOL_ROW_RIGHT, EVT_PHI.POOL_ROW_DY = 0.72, 14, 6, 0
EVT_PHI.POOL_ROW_W = 227                 -- a gauge without its left label: squares 0..132, number + unit to +227
EVT_PHI.TENS_NODE = 923022909            -- _pos_tension01
EVT_PHI.TENS_LABEL = CALC_CRC("_gtxt_tension01")
EVT_PHI.TENS_X0 = 225                    -- plate_hiper_build.py PH_TENS_X: the retail place of the move gauge
EVT_PHI.PoolGaugeOn = false

function EVT_PHI.PoolGauge(L, peg, skill)
  local P, G = EVT_PHI.POOL, EVT_PHI.GEO
  local on = peg ~= nil and EVT_PH_POOL_GAUGE ~= false and EVT_PH_Exists(P) and type(VRFW_UI) == "table"
  if not on then
    if EVT_PH_Exists(P) and funcLuaMenuCommand(C.IS_OPEN_LAYER, P, 0) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, P, 0, false)
    end
    if EVT_PHI.PoolGaugeOn then
      EVT_PHI.PoolGaugeOn = false
      funcLuaMenuCommand(2575768773 --[[NODE_POS]], L, 0, EVT_PHI.TENS_NODE, 0, EVT_PHI.TENS_X0)
      funcLuaMenuCommand(2885415772 --[[NODE_SCALE]], L, 0, EVT_PHI.TENS_NODE, 1, 1)
      funcLuaMenuCommand(C.MESH_VISIBLE, L, EVT_PHI.TENS_LABEL, true, 0)
    end
    return false
  end
  local k, w = EVT_PHI.POOL_ROW_K, EVT_PHI.POOL_ROW_W * EVT_PHI.POOL_ROW_K
  local right = G.ROW_X - 20 + G.BAND_W - EVT_PHI.POOL_ROW_RIGHT      -- the card's right end (page x)
  local xp = right - w                                                -- the pool gauge's origin
  local xm = xp - EVT_PHI.POOL_ROW_GAP - w                            -- the move gauge's origin
  -- the move's gauge (this panel's own group): moved left, scaled, no left label
  EVT_PHI.PoolGaugeOn = true
  funcLuaMenuCommand(2575768773 --[[NODE_POS]], L, 0, EVT_PHI.TENS_NODE, 0, xm)
  funcLuaMenuCommand(2885415772 --[[NODE_SCALE]], L, 0, EVT_PHI.TENS_NODE, k, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, EVT_PHI.TENS_LABEL, false, 0)
  -- the pool's gauge: the same group, every square lit, the pool's number, the same PEG / SP look
  EVT_PH_Open(P, 0)
  local tj = G.TENS_J[1]                                              -- the layer's attach point (page coords)
  local mainY = tj[2] + 205                                           -- the move gauge's line (GEO.TENS_J: -205 / row)
  funcLuaMenuCommand(C.LOCAL_SCALE, P, k, k, 1, 0)
  funcLuaMenuCommand(C.LOCAL_POS, P, xp - tj[1], mainY - tj[2] + EVT_PHI.POOL_ROW_DY, 0, 0)
  -- the pool as a full gauge (the shared TENSIÓN gauge: every square lit, the pool as the number, the PEG look, no label)
  VRFW_UI.MovePlate.Tension(P, 0, peg.pool, {scale = peg.pool, look = function(l, i)
    pcall(EVT_PHI.PegLook, l, i, true, peg.kind)
    funcLuaMenuCommand(C.MESH_VISIBLE, l, EVT_PHI.TENS_LABEL, false, i)
  end})
  funcLuaMenuCommand(C.LAYER_VISIBLE, P, 0, true)
  local okp, px, py = pcall(funcLuaMenuCommand, C.MESH_POSE, P, 0, EVT_PHI.TENS_NODE)
  local okm, mx, my = pcall(funcLuaMenuCommand, C.MESH_POSE, L, 0, EVT_PHI.TENS_NODE)
  EVT_PH_Log("hiper pool gauge", math.floor(peg.pool + 0.5), tostring(peg.kind), "main", string.format("%.0f", xm),
    "pool", string.format("%.0f", xp), string.format("%.0f", mainY), "pose", tostring(px), tostring(py), "main pose",
    tostring(mx), tostring(my))
  return true
end

function EVT_PHI.SpiritMove(L, skill, chara, fusion)
  local R = EVT_PHI.ROW
  EVT_PHI.spiritRow = false               -- set when the move row (and its gauge) is drawn
  -- (a mode change has no move and no TENSIÓN: EVT_HC.AuraMove)
  local ok, move = EVT_PHI.AuraMove(skill)
  if fusion ~= nil then
    -- the fusion's chosen move, drawn with the partner's handle (his element colour, not the "not owned" grey)
    ok, move = fusion.move ~= 0, fusion.move
    if fusion.phdl ~= 0 then
      chara = fusion.phdl
    end
  end
  if not ok or move == nil or move == 0 or not EVT_PH_Exists(R) or SetupCharaSkillItem == nil or type(VRFW_UI) ~= "table" then
    if EVT_PH_Exists(R) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, R, 0, false)
    end
    -- no spirit move row (armours, auras without a change skill): no TENSIÓN part at all (user rule 2026-09-25)
    funcLuaMenuCommand(C.LOC_VISIBLE, L, 923022909 --[[_pos_tension01]], false, 0)
    funcLuaMenuCommand(C.PRIM_VISIBLE, L, 0, 3424269865, false)
    for i = 1, 10 do
      funcLuaMenuCommand(C.MESH_VISIBLE, L, CALC_CRC(string.format("_tension_on%02d", i)), false, 0)
    end
    return
  end
  -- the shared move plate (VRFW_UI.MovePlate.Fill: no blank / AI-mark layers, the move's OWN evolution grade, focus
  -- frame off), pointed through the retail function under this block's recorder, set back to the recorded arguments
  local a = EVT_PHI.skl or {g_useFormationCharaSkillLayer, L_DETAIL, 0, 1803124851, 0, g_useFormationCharaSkillBlankLayer,
    g_useSkillAIUseMarkLayer}
  local okf, err = VRFW_UI.MovePlate.Fill(R, 0, chara, move, {set = EVT_PHI.origSkl, page = a[2], page_inst = a[3],
    point = a, restore = a, open = EVT_PH_Open})
  if not okf then
    EVT_PH_Log("spirit move row failed", string.format("%08X", move), tostring(err))
    return
  end
  EVT_PHI.spiritRow = true
  -- the gauge: the move's own cost (retail formula: cost / team scale * 10 steps)
  -- 2026-09-25 (in game: "1 T" and every square lit): outside a match GetSoccerTeamInfo(0) has no team, and the
  -- retail fill had left the AURA's cost (1) there. Now the number is always the MOVE's cost (SKILL_INFO(move, 11), as
  -- the retail detail's number), and the squares use the retail formula (cost / team scale × 10) when a team scale is
  -- known (match), else the scale of team 0 / 1, else none lit.
  local okc, cost = funcLuaCommand(C.SKILL_INFO, move, 11)
  local steps, scale = 0, nil
  local peg = fusion == nil and EVT_PHI.PegInfo(skill) or nil
  pcall(EVT_PHI.PegPool, L, peg)
  if peg ~= nil then
    -- PEG mode: the move's cost in the keshin's PEG (or the totem's SP); squares = cost / pool × 10
    okc, cost, scale = true, peg.cost, peg.pool
  end
  if okc and type(cost) == "number" then
    -- the shared TENSIÓN gauge (VRFW_UI.MovePlate.Tension): the match team's scale, else (menus) the retail handler's
    -- global scale (team 255 with the flag set); PEG mode: scale = the pool, the PEG look after the locator
    steps, scale = VRFW_UI.MovePlate.Tension(L, 0, cost, {scale = scale, teams = table.pack(EVT_PH_TeamInfo(), 255),
      look = function(l, i)
        pcall(EVT_PHI.PegLook, l, i, peg ~= nil, peg and peg.kind)
      end})
  end
  EVT_PH_Log("spirit move", string.format("%08X", skill), string.format("%08X", move), okc and cost or -1,
    tostring(scale), steps)
end

-- the band sprite of an aura skill: family by aura type (SKILL_INFO 13), 01..05 by element (SKILL_INFO 7); element 5
-- of a common skill (800895612) counts as 6 and, like any other value, falls back to 01 (retail Update*DetailInfo)
EVT_PHI.Band = EVT_HC.Band

-- stat gains of `chara`'s fusion (the page slot character_reforged.page_stat_gain, CharacterReforged.Page.GainsRaw:
-- a mod's command (base) -> ok, favouredMask, 9 gains in stat idx
-- order), as 3 lines of "Stat +N"; favoured stats in [CPASSIVE01]..[C]. Same text as PL.MxGainsText (skill_slots_v2).
EVT_PH_MX_STAT_NAME = {"Disparo", "Control", "Técnica", "Presión", "Físico", "Inteligencia", "Agilidad", "Rapidez", "Suerte"}
function EVT_PH_MxGainsText(chara)
  local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
  local r = (type(page) == "table" and type(page.GainsRaw) == "function") and page.GainsRaw(chara) or {false}
  if not r[1] or not r[2] or type(r[4]) ~= "number" then
    return nil
  end
  local mask = tonumber(r[3]) or 0
  local parts = {}
  for _, i in ipairs({1, 2, 3, 4, 5, 6, 7, 9}) do   -- 8 stats: slot 8 (Rapidez) retired 2026-09-30
    local g = tonumber(r[3 + i]) or 0
    local fav = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
    local s = string.format("%s +%d", EVT_PH_MX_STAT_NAME[i], g)
    parts[#parts + 1] = fav and ("[CPASSIVE01]" .. s .. "[C]") or s
  end
  return table.concat({table.concat(parts, "   ", 1, 3), table.concat(parts, "   ", 4, 6),
    table.concat(parts, "   ", 7, 8)}, "\n")
end

-- 2026-10-06 (Nacho, player page round 5): the Hiper page shows ONE aura. A miximax shows its own card only; L3 on
-- the page (research/grafts/plate_pages) toggles EVT_PH_MX_VIEW = the keshin / totem that miximax gives the player
-- (CMND_EVT_MX_AURA), drawn as the page's card with its move, and back. The extra rows under the miximax are gone.
if EVT_PH_MX_VIEW == nil then
  EVT_PH_MX_VIEW = false
end
EVT_PH_ONE_AURA = true

-- 2026-10-12: no chain any more: a miximax gives no keshin / totem / armour of its partner (each Hiper slot works on
-- its own). Kept as nil for the callers of the old L3 view; L3 now switches the two slots (EVT_PH_CanSwitch).
function EVT_PH_MxAura(chara)
  return nil
end

function EVT_PHI.ShowSkill(skill, chara)
  local L = EVT_PHI.L
  if not EVT_PH_Exists(L) or SetupPersonalPlateSkillDetailInfo == nil or EVT_PHI.origSkl == nil then
    return false, "no integrated panel"
  end
  EVT_PH_Open(L)
  -- the tags / meshes our empty drawing hides
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 923022909 --[[_pos_tension01]], true, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 4081284803 --[[_pos_at01]], true, 0)
  local ok, err = EVT_PHI.Fill(SetupPersonalPlateSkillDetailInfo, skill, chara, nil, EVT_PH_TeamInfo(), nil, true)
  if not ok then
    return false, err
  end
  if not funcLuaMenuCommand(C.IS_LAYER_VISIBLE, L, 0) then
    -- 2026-09-25: a retail miximax row's first fill after the page opens can leave the panel hidden; the next show a
    -- frame later is fine. Forcing the layer visible here (13:54 build) coincided with game hangs on card hover, so
    -- this path only reports it again (no layer writes, no retry)
    return false, "panel not shown"
  end
  -- header (retail band of the aura type and element, type icon, name, masked portrait): the face layer. No type text
  -- line (user 2026-09-25: the type is the icon). Fallback without the face layer: our band and name.
  EVT_PHI.Clean(L)
  local fusion = skill == EVT_PH_MX_CARRIER and EVT_PHI.MxGet(chara) or nil
  local mc = fusion == nil and EVT_PHI.McGet(chara, skill) or nil
  if not EVT_PHI.Portrait(L, skill, fusion, mc) then
    local band = EVT_PHI.Band(skill)
    if band ~= nil then
      funcLuaMenuCommand(C.SPRITE, L, EVT_PHI.TEX, band, 243934124 --[[sp_base01]], 0, 0)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 1125548721 --[[_sp_base01]], true, 0)
    local name = EVT_PH_Name(skill)
    if name ~= nil then
      funcLuaMenuCommand(C.TEXT, L, 1704438437 --[[_text_name01]], name, 0)
    end
    funcLuaMenuCommand(C.TEXT_VISIBLE, L, 1899787537 --[[_text_area01]], false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L, 3516146179 --[[_area_base01]], false, 0)
  end
  EVT_PHI.SpiritMove(L, skill, chara, fusion)
  pcall(EVT_PHI.HideExtras)
  -- the pool on the header card (after HideExtras, which hides it with the extra layers)
  pcall(EVT_PHI.PoolTag, (fusion == nil and mc == nil) and EVT_PHI.PegInfo(skill) or nil)
  -- 2026-10-12: the keshin's pool as a second gauge right of its move's PEG (after PoolTag, which hides instance 0)
  pcall(EVT_PHI.PoolGauge, L, (fusion == nil and mc == nil and EVT_PHI.spiritRow) and EVT_PHI.PegInfo(skill) or nil, skill)
  pcall(EVT_PHI.QuoteBar, L, true)
  if fusion == nil then
    -- a keshin Hiper that arms on this player's body: «Armadura» tag on the header card's bottom edge
    pcall(EVT_PHI.HiperArmourTag, skill, chara)
  end
  if fusion ~= nil then
    local pname = fusion.name or "?"
    -- 2026-09-25 (user): no stat-gains text here any more (the gains are on Atributos, L3); instead the band of the aura
    -- that comes with the miximax (partner keshin / totem, or the base's own armour), or nothing
    funcLuaMenuCommand(C.TEXT, L, 691026122 --[[_text_flavor01]], "", 0)
    -- the description's quote bar has nothing to mark: hidden (2026-09-25)
    pcall(EVT_PHI.QuoteBar, L, false)
    -- 2026-09-28 (user): under the miximax's move row, the keshin / totem it grants (band + its own move row) and that
    -- keshin's armour (band; its move only when it differs), compacted to fit (EVT_PHI.ShowExtras)
    local okx, blocks, aura, kind, armour = pcall(EVT_PHI.FusionExtras, chara, fusion)
    local shownx = 0
    if EVT_PH_ONE_AURA then
      okx, shownx = false, "one aura (L3: keshin view)"
    end
    if okx and type(blocks) == "table" then
      local oks, nx = pcall(EVT_PHI.ShowExtras, blocks)
      shownx = oks and nx or ("error " .. tostring(nx))
    end
    EVT_PH_Log("fusion", string.format("%08X", fusion.partner), tostring(fusion.face), tostring(fusion.phdl),
      string.format("%08X", fusion.move), pname, "aura", string.format("%08X", tonumber(aura) or 0), tostring(kind),
      "armour", string.format("%08X", tonumber(armour) or 0), "extras", tostring(shownx))
  end
  if EVT_PH_NO_DESC ~= false then
    -- 2026-10-06 (Nacho, player page round 6): no description on the Hiper page (the card and its move only)
    funcLuaMenuCommand(C.TEXT, L, 691026122 --[[_text_flavor01]], "", 0)
    pcall(EVT_PHI.QuoteBar, L, false)
  end
  return true, "integrated"
end

function EVT_PHI.ShowEmpty()
  pcall(EVT_PHI.HideExtras)
  local L = EVT_PHI.L
  if not EVT_PH_Exists(L) then
    return false
  end
  EVT_PH_Open(L)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, false)
  if EVT_PH_Exists(EVT_PHI.FACE) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.FACE, 0, false)
  end
  funcLuaMenuCommand(C.SPRITE, L, EVT_PHI.TEX_T02, EVT_PHI.BAND_EMPTY, 243934124 --[[sp_base01]], 0, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1125548721 --[[_sp_base01]], true, 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, 1704438437 --[[_text_name01]], true, 0)
  funcLuaMenuCommand(C.TEXT, L, 1704438437 --[[_text_name01]], EVT_PH_Text(EVT_PH_EMPTY_NAME_ID), 0)
  funcLuaMenuCommand(C.TEXT, L, 691026122 --[[_text_flavor01]], "", 0)   -- 2026-10-07: banner only, no hint text
  funcLuaMenuCommand(C.TEXT, L, 1899787537 --[[_text_area01]], "", 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L, 1899787537 --[[_text_area01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3516146179 --[[_area_base01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 1220252763 --[[_gtxt_longshoot01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 559600405 --[[_icon_sp_sub_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 563708378 --[[_gtxt_cmd_at01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 923022909 --[[_pos_tension01]], false, 0)
  funcLuaMenuCommand(C.LOC_VISIBLE, L, 4081284803 --[[_pos_at01]], false, 0)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L, 0, 3424269865, false)
  funcLuaMenuCommand(C.PRIM_VISIBLE, L, 0, 2223127589, false)
  -- 2026-10-11 (Nacho: a thin vertical grey bar under «Sin hipertécnica», past the panel's bottom edge): the
  -- description's quote bar _item_win_line01 (x 982, y ~758-876) stayed on after the hint text was retired on
  -- 2026-10-07; the empty page has no description, so no bar
  pcall(EVT_PHI.QuoteBar, L, false)
  EVT_PHI.Clean(L)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  return true
end

-- Hiper page of `chara` (charaStHdl; 0 = none). `retry` = the pending record when called again from PostStep.
-- 2026-09-28 (user: the page showed «Sin hipertécnica» the first time it was paged to, the Hiper after paging away and
-- back). Root cause (loader.log 02:31:00): the skill WAS found ("integrated panel failed 62256EE2 panel not shown"),
-- but the panel layer was opened by that same draw (EVT_PH_Open); a layer opened this frame does not keep the fill's
-- LAYER_VISIBLE (IS_LAYER_VISIBLE false), and the fallback then drew the EMPTY page into the same layer, forcing it
-- visible. Now: a player with a Hiper never gets the empty page; while the panel is not ready the page shows nothing
-- and is drawn again on the next frames (EVT_PH_PENDING, run by the PostStep wrapper, up to EVT_PH_RETRY_FRAMES); a
-- draw that had to open a layer is repeated once on the next frame (the instances opened late then get their content).
EVT_PH_IN_SHOW = false
EVT_PH_RETRY_FRAMES = 30
EVT_PH_PENDING = nil                -- {chara, left, settle}: draw the page again next frame
function EVT_PH_Show(chara, retry)
  if not EVT_PLATE_HIPER or not EVT_PH_Exists(L_STATUS) then
    return
  end
  -- never re-entered from a layer callback fired by our own drawing (show -> fill -> callback -> show)
  if EVT_PH_IN_SHOW then
    EVT_PH_Log("show re-entered: ignored", EVT_PH_U32(chara))
    return
  end
  EVT_PH_IN_SHOW = true
  EVT_PH_PENDING = nil
  local okr, err = pcall(EVT_PH_ShowInner, chara, retry)
  EVT_PH_IN_SHOW = false
  if not okr then
    EVT_PH_Log("show failed", tostring(err))
  end
end

-- PostStep: the pending redraw, only while the Hiper page is still the one shown
function EVT_PH_Retry()
  local p = EVT_PH_PENDING
  if p == nil or EVT_PH_IN_SHOW then
    return
  end
  local page = GetNowPageIdx ~= nil and GetNowPageIdx() or -1
  if not (evt_ph_on and EVT_PLATE_HIPER and page == EVT_PH_PAGE) then
    EVT_PH_PENDING = nil
    return
  end
  EVT_PH_Show(p.chara, p)
end

function EVT_PH_ShowInner(chara, retry)
  EVT_PH_HideWindows()
  EVT_PH_Attach(true)
  evt_ph_on = true
  EVT_PHI.opened = false
  local skill = EVT_PH_Skill(chara)
  local shown, how, t = false, "none", nil
  if EVT_PH_INTEGRATED then
    if skill ~= 0 then
      shown, how = EVT_PHI.ShowSkill(skill, chara)
      if not shown then
        EVT_PH_Log("integrated panel failed", string.format("%08X", skill), tostring(how))
        local left = retry ~= nil and retry.left or EVT_PH_RETRY_FRAMES
        if left > 0 then
          -- loading: nothing on the page this frame (never «Sin hipertécnica» for a player who has a Hiper)
          pcall(EVT_PHI.HideLayer)
          EVT_PH_PENDING = {chara = chara, left = left - 1, settle = retry ~= nil and retry.settle or nil}
          EVT_PH_Log("show", EVT_PH_U32(chara), string.format("%08X", skill), "waiting for the panel", left)
          return
        end
        -- still not shown after EVT_PH_RETRY_FRAMES frames: the retail windows below (legacy path), never the empty page
      end
    elseif EVT_PHI.ShowEmpty() then
      shown, how = true, "empty"
    end
    if shown then
      if EVT_PHI.opened and (retry == nil or not retry.settle) then
        EVT_PH_PENDING = {chara = chara, left = EVT_PH_RETRY_FRAMES, settle = true}
        how = how .. " (redraw next frame: layer opened)"
      end
      EVT_PH_Log("show", EVT_PH_U32(chara), string.format("%08X", skill), how, EVT_PH_AuraType(skill) or -1, evt_ph_plate_type)
      return
    end
    pcall(EVT_PHI.HideLayer)
    EVT_PH_HideWindows()
  end
  if skill ~= 0 then
    shown, how, t = EVT_PH_ShowAura(skill, chara)
    if not shown then
      EVT_PH_Log("aura window failed", string.format("%08X", skill), tostring(how))
      EVT_PH_HideWindows()
      shown, how = EVT_PH_ShowDetail(skill, chara)
    end
  end
  if not shown then
    if skill ~= 0 then
      EVT_PH_Log("detail window failed", string.format("%08X", skill), tostring(how))
    end
    EVT_PH_ShowEmpty()
    how = "empty"
  end
  EVT_PH_Log("show", EVT_PH_U32(chara), string.format("%08X", skill), how, t or -1, evt_ph_plate_type)
end

-- our panel is visible only while the Hiper page shows (fix 2026-09-24: the plate opens every layer of the menu, so
-- the panel showed its bind-pose state over ATRIBUTOS on the first open of a plate)
function EVT_PHI.HideLayer()
  pcall(EVT_PHI.HideExtras)
  pcall(EVT_PHI.PegTag, nil)
  if EVT_PH_Exists(EVT_PHI.L) and funcLuaMenuCommand(C.IS_LAYER_VISIBLE, EVT_PHI.L, 0) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.L, 0, false)
  end
  if EVT_PH_Exists(EVT_PHI.ROW) and funcLuaMenuCommand(C.IS_LAYER_VISIBLE, EVT_PHI.ROW, 0) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.ROW, 0, false)
  end
  if EVT_PH_Exists(EVT_PHI.FACE) and funcLuaMenuCommand(C.IS_LAYER_VISIBLE, EVT_PHI.FACE, 0) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, EVT_PHI.FACE, 0, false)
  end
end

-- 2026-09-28: not while a show runs. The page index is set AFTER the page change (retail SetPersonalPlateNextPage /
-- the parent's ChangePageInfo call ChangePersonalPlatePageByCharaHdl first), so a layer callback fired by our own
-- drawing would otherwise see the previous page and hide the panel it is drawing.
function EVT_PHI.Guard()
  if EVT_PH_IN_SHOW then
    return
  end
  local page = GetNowPageIdx ~= nil and GetNowPageIdx() or -1
  if not (evt_ph_on and EVT_PLATE_HIPER and page == EVT_PH_PAGE) then
    EVT_PHI.HideLayer()
  end
end

function EVT_PH_Hide()
  EVT_PH_PENDING = nil
  pcall(EVT_PHI.HideLayer)
  if not evt_ph_on then
    return
  end
  evt_ph_on = false
  EVT_PH_HideWindows()
  EVT_PH_ResetDetail()
  EVT_PH_Attach(false)
end

local function EVT_PH_SelectedChara(fallback)
  local ch = 0
  if GetPersonalPlateSelectCharaStHdlAuto ~= nil then
    local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
    if ok and v ~= nil and v ~= false then
      ch = v
    end
  end
  if (ch == nil or ch == 0) and fallback ~= nil and fallback ~= false then
    ch = fallback
  end
  return ch or 0
end

-- ---- wrappers of personal_plate_inc / personal_plate_menu globals -------------------------------------------------
-- the panel after every engine layer setup / open and every frame: hidden unless the Hiper page shows
for _, fname in ipairs({"OnSetupLayer", "OnOpenLayer", "OnOpenEndLayer", "OnCloseLayer", "PostStep"}) do
  EVT_PH_Wrap(fname, function(orig)
    return function(...)
      local r = orig(...)
      if fname == "OnSetupLayer" and EVT_R9 ~= nil and (...) == EVT_R9.EXTRA then
        pcall(funcLuaMenuCommand, 711242136, EVT_R9.EXTRA, 0, false)
      end
      pcall(EVT_PHI.Guard)
      if fname == "PostStep" and EVT_PH_PENDING ~= nil then
        pcall(EVT_PH_Retry)
      end
      if fname == "PostStep" and EVT_R9 ~= nil then
        pcall(EVT_R9.Step)
      elseif fname == "OnCloseLayer" and EVT_R9 ~= nil and EVT_R9.SetHint ~= nil then
        pcall(EVT_R9.SetHint, 0)
        EVT_R9.fusion = {}
      end
      return r
    end
  end)
end

EVT_PH_Wrap("SetPersonalPlateType", function(orig)
  return function(a1, ...)
    evt_ph_plate_type = a1 or 0
    return orig(a1, ...)
  end
end)

-- our attach labels start switched on (objbin); the status base is set up again each time the plate opens
EVT_PH_Wrap("OnSetupStatusBaseLayer", function(orig)
  return function(a1, a2, ...)
    local r = orig(a1, a2, ...)
    if a1 == L_STATUS and (a2 == nil or a2 == 0) and EVT_R9 ~= nil then
      pcall(EVT_R9.Trace, a1, a2 or 0)
    end
    if a1 == L_STATUS and (a2 == nil or a2 == 0) then
      evt_ph_on = false
      EVT_PH_PENDING = nil
      pcall(EVT_PHI.HideLayer)
      for _, a in ipairs(EVT_PH_ATTACH) do
        pcall(EVT_PH_Trace, a[4], false)
      end
    end
    return r
  end
end)

EVT_PH_Wrap("SetVisibleGraphLayer", function(orig)
  return function(a1, ...)
    local r = orig(a1, ...)
    if EVT_R9 ~= nil and EVT_R9.Visible ~= nil then
      pcall(EVT_R9.Visible, a1 == true)
    end
    return r
  end
end)

EVT_PH_Wrap("SetStatusBaseArrowAndTextVisible", function(orig)
  return function(...)
    local r = orig(...)
    pcall(EVT_PH_HideArrowKeys)
    return r
  end
end)

EVT_PH_Wrap("ChangePersonalPlatePageByCharaHdl", function(orig)
  return function(a1, a2, ...)
    local r = orig(a1, a2, ...)
    pcall(EVT_PH_Decor, a2)
    if EVT_PLATE_HIPER and a2 == EVT_PH_TYPE then
      local ch = EVT_PH_SelectedChara(a1)
      if ch == 0 then
        pcall(EVT_PH_Hide)                  -- no player focused (empty slot): nothing of the page
        return r
      end
      local ok, err = pcall(EVT_PH_Show, ch)
      if not ok then
        EVT_PH_Log("show error", tostring(err))
      end
    else
      pcall(EVT_PH_Hide)
    end
    return r
  end
end)

-- players without a save record (universe / opponent previews): the page shows "Sin hipertécnica"
EVT_PH_Wrap("ChangePersonalPlatePageByCharaParamId", function(orig)
  return function(a1, a2, ...)
    local r = orig(a1, a2, ...)
    pcall(EVT_PH_Decor, a2)
    if EVT_PLATE_HIPER and a2 == EVT_PH_TYPE then
      pcall(EVT_PH_Show, 0)
    else
      pcall(EVT_PH_Hide)
    end
    return r
  end
end)

EVT_PH_Wrap("UpdatePageInfo", function(orig)
  return function(...)
    if EVT_PLATE_HIPER and GetNowPageIdx ~= nil and GetNowPageIdx() == EVT_PH_PAGE then
      -- 2026-10-07 (Nacho: «Sin hipertécnica» stayed on an empty bench slot): the formation / dock menus hide the plate
      -- (SetVisiblePersonalPlateLayerAll(false)) and then call UpdatePageInfo for an empty slot; no player = nothing of
      -- the page (the page index stays, the next focused player redraws it). «Sin hipertécnica» only for a real
      -- player without a Hiper and for the save-less previews (ChangePersonalPlatePageByCharaParamId).
      local ch = EVT_PH_SelectedChara(nil)
      if ch == 0 then
        pcall(EVT_PH_Hide)
        return
      end
      local ok, err = pcall(EVT_PH_Show, ch)
      if not ok then
        EVT_PH_Log("show error", tostring(err))
      end
      return
    end
    local r = orig(...)
    pcall(EVT_PH_Hide)
    return r
  end
end)

-- native next/prev page requests: the VR-Framework's player page registry steps them (VRFW_PlayerPages.Attach,
-- docs/framework/player-pages.md; this block's own EVT_PH_Shift is gone, 2026-10-09)

-- ---- 8-axis Atributos radar + R3 Miximax view (2026-09-25; 8 axes since 2026-09-30; research/scripts/radar9_build.py)
-- The page's radar layers point at page-only 8-axis copies (menu setting; names keep "_9"): radar evt_soccer11_07_9
-- (rates graph01..08, rim k clockwise from the top), base evt_soccer11_06_9 (7 retail label groups on the octagon, CCW
-- from the top) and the extra layer evt_soccer11_06_9x (Suerte label, number instance 7). The retail graph function
-- runs first (position icons, colours); EVT_R9.Draw then writes the 8 numbers and the 8 rates. Values: the retail
-- stat getter for the 7 retail stats, the page slot character_reforged.page_stat for Suerte (CharacterReforged.Page.Stat:
-- a mod's answer, else CMND_CHARACTERREFORGED_CHARA_STAT; Rapidez was retired on 2026-09-30). L3 (pad) / B (keyboard) on the
-- Atributos page toggles the Miximax view when the player has a fusion (the slot page_stat_gain answers): totals with the
-- gains added, the radar with the boosted values, radar instance 1 = the normal values drawn over it.
EVT_R9 = EVT_R9 or {}
EVT_R9.RADAR = 3868632847 --[[soccer11_07_formation_status_graph]]
EVT_R9.EXTRA = 3201974232 --[[evt_soccer11_06_9x_formation_status_graph_extra]]
EVT_R9.N = 8                                       -- axes (9 until 2026-09-30: Rapidez retired)
EVT_R9.STAT = {0, 2, 5, 6, 4, 3, 1, 8}             -- label group g -> stat idx of the page slot (8 = Suerte)
EVT_R9.RATES = {2460373999, 196018773, 2091397827, 3805063008, 2513147894, 214091340, 2076571354, 3950701387}                         -- graph01..graph08
EVT_R9.MENU_CTRL, EVT_R9.MENU_CTRL_AN, EVT_R9.CHECK_INPUT = 1332654303, 2748927068, 4265778440
EVT_R9.CMD_TOGGLE = 579943758                       -- CMD_FUNC5: pad L3 / keyboard B (unbound on the plate,
                                                    -- the dock and the formation menus; R3 = CMD_FUNC6 is the plate's)
EVT_R9.HINT_KEY = 1361529897                        -- UI flag "evt_r9_mx_hint": L3 can toggle (dock / formation guide)
EVT_R9.hint = EVT_R9.hint or 0
EVT_R9.mx = EVT_R9.mx or false
EVT_R9.frame = EVT_R9.frame or 0
EVT_R9.last = EVT_R9.last or -100

-- our attach entries of the status base (extra labels, radar instance 1) follow the retail rule of
-- OnSetupStatusBaseLayer: the _rpg locators for plate type 2, the normal ones otherwise
EVT_R9.TRACE = {{4047450161, 0}, {3860701432, 0}, {3839308931, 0}, {4092961866, 0}, {919387844, 1}, {569257485, 1}, {1942683662, 1}, {1693028551, 1}}                         -- {attach name, 1 = rpg locator}
function EVT_R9.Trace(layer, inst)
  local rpg = evt_ph_plate_type == 2
  for _, t in ipairs(EVT_R9.TRACE) do
    funcLuaMenuCommand(1774843228, layer, inst, t[1], (t[2] == 1) == rpg)
  end
end

function EVT_R9.Log(...)
  pcall(funcLuaCommand, CALC_CRC("CMND_EVT_LOG"), "radar9", ...)
end

function EVT_R9.Gains(chara)
  local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
  local r = (type(page) == "table" and type(page.GainsRaw) == "function") and page.GainsRaw(chara) or {false}
  if not r[1] or not r[2] or type(r[4]) ~= "number" then
    return nil, 0
  end
  local g = {}
  for _, i in ipairs({1, 2, 3, 4, 5, 6, 7, 9}) do   -- 8 stats: slot 8 (Rapidez) retired 2026-09-30
    g[i] = tonumber(r[3 + i]) or 0
  end
  return g, tonumber(r[3]) or 0
end

function EVT_R9.Values(chara, l5)
  local v = {}
  for grp = 1, EVT_R9.N do
    local si = EVT_R9.STAT[grp]
    local val = 0
    if si <= 6 then
      val = funcLuaCommand(1131797651, chara, 14 + si, true, l5)
    else
      local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
      local x = (type(page) == "table" and type(page.Stat) == "function") and page.Stat(chara, si) or nil
      val = type(x) == "number" and x or 0
    end
    v[grp] = type(val) == "number" and val or 0
  end
  return v
end

function EVT_R9.SetRates(l1, inst, vals, top)
  for grp = 1, EVT_R9.N do
    local rate = EVT_R9.RATES[(EVT_R9.N - (grp - 1)) % EVT_R9.N + 1]
    if not funcLuaMenuCommand(1203687233, l1, rate, 0, inst) then
      local gi = funcLuaMenuCommand(112302847, l1, inst, rate)
      funcLuaMenuCommand(541357333, l1, rate, gi, inst)
    end
    funcLuaMenuCommand(1595998683, l1, rate, 0, vals[grp] / top * 0.75, inst)
  end
end

function EVT_R9.Draw(l1, l2, l3, chara, a5, l4, l5)
  if not funcLuaMenuCommand(262659071, EVT_R9.EXTRA) then
    return
  end
  EVT_R9.chara = chara
  local base = EVT_R9.Values(chara, l5)
  local gains, mask = nil, 0
  if EVT_R9.mx then
    gains, mask = EVT_R9.Gains(chara)
    if gains == nil then
      EVT_R9.mx = false
    end
  end
  local shown = {}
  for grp = 1, EVT_R9.N do
    shown[grp] = base[grp] + (gains and gains[EVT_R9.STAT[grp] + 1] or 0)
  end
  -- the 8 numbers (retail number calls, instances 0..7 of soccer11_06_p1)
  -- number styles of soccer11_06_p1 (retail): 2612831244 normal, 45479350 the l4 mode, 563832214 the retail
  -- "stat goes up" number (UpdateCharaParameterGraphNextItemByCharaStHdl); in the Miximax view the stats that gain
  -- use that style, the others stay normal
  local n3 = l4 and 45479350 or 2612831244
  local STYLES = {2612831244, 45479350, 563832214, 1261127012}
  for grp = 1, EVT_R9.N do
    local inst = grp - 1
    local style = n3
    if gains ~= nil and (gains[EVT_R9.STAT[grp] + 1] or 0) > 0 then
      style = 563832214
    end
    funcLuaMenuCommand(2158717427, l2, 1597519943, false, inst)
    funcLuaMenuCommand(2158717427, l2, 1233172029, false, inst)
    for _, st in ipairs(STYLES) do
      if st ~= style then
        funcLuaMenuCommand(1233047821, l2, inst, st, false)
      end
    end
    local prim = funcLuaMenuCommand(1927054058, l2, inst, style)
    funcLuaMenuCommand(3609943765, l2, inst, prim, shown[grp])
    funcLuaMenuCommand(551395392, l2, inst, false)
    funcLuaMenuCommand(1233047821, l2, inst, style, true)
  end
  -- the extra layer: shown exactly when the retail radar is; its names in the retail name colour (the retail
  -- function colours only the base layer); its "ALL" badges come with its own atlas
  local E = EVT_R9.EXTRA
  EVT_R9.Visible(EVT_R9.RadarShown())
  if l4 then
    funcLuaMenuCommand(801406373, E, 0, 3659653428, 1, 1, 1)
  else
    funcLuaMenuCommand(801406373, E, 0, 3659653428, 0.0784313725490196, 0.29411764705882354, 0.5098039215686274)
  end
  -- the rates (scale = the largest shown value, or the caller's)
  local top = a5 or 0
  if top == 0 then
    for grp = 1, EVT_R9.N do
      if shown[grp] > top then
        top = shown[grp]
      end
    end
  end
  if top == 0 then
    top = 200
  end
  EVT_R9.SetRates(l1, 0, shown, top)
  -- Miximax view: instance 1 = the normal values, over the boosted radar
  if funcLuaMenuCommand(1175615627, l1) ~= nil and (tonumber(funcLuaMenuCommand(1175615627, l1)) or 1) > 1 then
    funcLuaMenuCommand(711242136, l1, 1, EVT_R9.mx == true)
    if EVT_R9.mx then
      EVT_R9.SetRates(l1, 1, base, top)
      funcLuaMenuCommand(801406373, l1, 1, 2038497104, 1, 1, 1)
      funcLuaMenuCommand(801406373, l1, 0, 2038497104, 1, 0.78, 0.25)
    end
  end
  EVT_R9.Log("draw", tostring(chara), EVT_R9.mx and "miximax" or "normal", tostring(mask), table.concat(shown, ","),
    "radar", tostring(funcLuaMenuCommand(262659071, l1)), tostring(EVT_R9.RadarShown()),
    tostring(funcLuaMenuCommand(1175615627, l1)), "top", tostring(top))
end

EVT_PH_Wrap("UpdateCharaParameterGraphByCharaStHdl", function(orig)
  return function(a1, a2, a3, a4, a5, a6, a7, a8)
    local r = orig(a1, a2, a3, a4, a5, a6, a7, a8)
    if a1 == EVT_R9.RADAR and not IsInvalidSoccerCharaHdl(a3) then
      EVT_R9.args = {a1, a2, a3, a4, a5, a6, a7, a8}
      local ok, err = pcall(EVT_R9.Draw, a1 or 0, a2 or 0, a4 or 1572892955, a3, a5, a6 or false, a8 or false)
      if not ok then
        EVT_R9.Log("draw error", tostring(err))
      end
    end
    return r
  end
end)

-- the extra layer (Suerte label) and radar instance 1 follow the retail graph layers exactly: shown
-- only when the retail radar is (Atributos page), hidden on every other page, page change, player change and close
function EVT_R9.Visible(on)
  if funcLuaMenuCommand(262659071, EVT_R9.EXTRA) then
    funcLuaMenuCommand(711242136, EVT_R9.EXTRA, 0, on == true)
  end
  if on ~= true or not EVT_R9.mx then
    funcLuaMenuCommand(711242136, EVT_R9.RADAR, 1, false)
  end
end

function EVT_R9.RadarShown()
  return funcLuaMenuCommand(1262717583 --[[IS_LAYER_VISIBLE]], EVT_R9.RADAR, 0) == true
end

-- the guide hint of the parent menu (team dock / formation): a loader UI flag, set while L3 can toggle
function EVT_R9.SetHint(v)
  if v ~= EVT_R9.hint then
    EVT_R9.hint = v
    pcall(funcLuaCommand, CALC_CRC("CMND_EVT_UI_FLAG_SET"), EVT_R9.HINT_KEY, v)
    EVT_R9.Log("hint", tostring(v))
  end
end

EVT_R9.fusion = EVT_R9.fusion or {}
function EVT_R9.HasFusion(chara)
  local f = EVT_R9.fusion[chara]
  if f == nil then
    local skill = EVT_PH_Skill ~= nil and EVT_PH_Skill(chara) or 0
    local kind = skill ~= 0 and EVT_PH_AuraType(skill) or nil
    f = kind == 2 and EVT_R9.Gains(chara) ~= nil
    EVT_R9.fusion[chara] = f
    EVT_R9.Log("fusion?", tostring(chara), string.format("%08X", skill), tostring(kind), f and "yes" or "no")
  end
  return f
end

-- L3 / B on the Atributos page: Miximax view on / off (only with a fusion); redraw through the retail entry
function EVT_R9.Step()
  EVT_R9.frame = EVT_R9.frame + 1
  -- 2026-09-25 (Equipamiento shows the radar too): the labels follow the retail radar's own visibility on every
  -- plate page / screen that shows it; the L3 view and its hint stay on the Atributos page
  local shown = EVT_R9.args ~= nil and EVT_R9.RadarShown()
  EVT_R9.Visible(shown)
  -- the radar's page: ATRIBUTOS (index 7 with research/grafts/plate_pages, else the retail index 0)
  local radarPage = (EVT_PLATE_PAGES == true and EVT_PPG_STATS ~= nil) and EVT_PPG_STATS or 0
  if not shown or GetNowPageIdx == nil or GetNowPageIdx() ~= radarPage then
    EVT_R9.SetHint(0)
    return
  end
  EVT_R9.SetHint(EVT_R9.HasFusion(EVT_R9.args[3]) and 1 or 0)
  local pressed = funcLuaCommand(EVT_R9.CHECK_INPUT, EVT_R9.MENU_CTRL, EVT_R9.CMD_TOGGLE) == true
    or funcLuaCommand(EVT_R9.CHECK_INPUT, EVT_R9.MENU_CTRL_AN, EVT_R9.CMD_TOGGLE) == true
  if not pressed or EVT_R9.frame - EVT_R9.last < 8 then
    return
  end
  EVT_R9.last = EVT_R9.frame
  local chara = EVT_R9.args[3]
  if not EVT_R9.mx and not EVT_R9.HasFusion(chara) then
    EVT_R9.Log("L3", tostring(chara), "no fusion: nothing")
    return
  end
  EVT_R9.mx = not EVT_R9.mx
  EVT_R9.Log("L3", tostring(chara), EVT_R9.mx and "miximax view" or "normal view")
  local a = EVT_R9.args
  UpdateCharaParameterGraphByCharaStHdl(a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
end

-- ===== EVT plate_hiper plate END =====
