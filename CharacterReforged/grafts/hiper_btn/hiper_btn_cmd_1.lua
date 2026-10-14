
-- EVT ------------------------------------------------------------------------------------------
-- Character Reforged since 2026-10-14 (the RB+A / RB+B plates of the new skill set are the base's; docs/refactor/
-- aura-mods-split.md «The 6 + 2 set over the retail data»): a NEUTRAL plate (move name, icon, glyph, state, cooldown);
-- Inazuma Fantasy adds its look (the portrait column: EVT_HC of its graft hiper_btn_face, layer evt_hiper_chr_icon).
-- Two plates (layer soccer08_10_cmd_act_hiper_slot, a copy of the move-row widget soccer08_10, 2 instances), mounted
-- on the move selector by attach entries of soccer08_07_cmd_act_btn_cmd_base: right of the ">" arrow (pos 0,
-- instance 0 level with the lower move row, instance 1 with the upper one) or above it (pos 1; loader config
-- hiper_slot.button_pos). Two slots per player (2026-10-12, docs/game/hiper/hiper-two-slots.md), selected-slot
-- controls: instance 0 (RB+A / H) = the SPECIAL MOVE (the running aura's or mix's move; the selected slot's when both
-- grant one), instance 1 (RB+B / J) = the TRANSFORMATION of the selected slot (keshin / totem summon, then the armour
-- "Armadura" from the running keshin; Mix-Max / «Modo cambio»); RB + D-pad (K) selects the slot: with both slots
-- filled each plate ends with the slot's tag («Aura» / «Mix», values 22-25 below). The loader answers CMND_EVT_HIPER_BTN with
-- (state, actor, move, ring, pos, device, glyph, state2, move2, glyph2, armour): state 0 hidden / 1 usable / 2 greyed;
-- glyph = the game's button icon tags (<CMD_FUNCR1><CMD_DECIDE_CMD_R_DOWN> = RB + A) drawn left of the name, or
-- "[H]" on a keyboard. Nothing is drawn without the loader.
local EVT_HL = 444446249 --[[soccer08_10_cmd_act_hiper_slot]]
local EVT_BASE = 1927855329 --[[soccer08_07_cmd_act_btn_cmd_base]]
local EVT_ATC = {{2563617955, 2592803578}, {111747328, 82812761}} --[[evt_hiper01_r/02_r, evt_hiper01_u/02_u]]
local EVT_CMD_BTN = 930255798 --[[CMND_VRFW_XSLOT_PLATES: the plates slot running the match (2026-10-14; was IF's CMND_EVT_HIPER_BTN, the same answer)]]
local EVT_SKILL_INFO = 2580586398 --[[CMND_GET_SOCCER_SKILL_INFO: 4 name id, 7 element, 13 aura type]]
local EVT_CUBES = {931753331, 2927639753, 3649506399, 1206098428, 820291946} --[[_cmd_tp_cube01..05]]
local EVT_last = {}
local EVT_pos = -1
local evt_ho_open = false   -- move list open (retail flag3, see EVT_HiperOpenPlace)
local evt_ho_set = {}       -- LOCAL_POS applied to each plate instance ("dx,dy")
local evt_ho_slide = {}     -- slide-in start frame (EVT_tick) of each plate instance, nil = none running
local evt_ho_want = false   -- last corner placement (the list-open transition starts the slide)
-- the «modo cambio» cooldown bar of the RB+A plate (EVT_CdBar). tex: 0 not asked, 1 loading, 2 ready, -1 failed;
-- shown / geo / swapped: what instance 0 has now (nil = unknown, after a draw); total: cooldown length in seconds
-- for the fallback
-- inst: the plate instance the bar is drawn on (the «modo cambio» is the mix slot's: instance 1 since 2026-10-12)
local evt_cd = {tex = 0, t = 0, swapped = false, shown = nil, geo = nil, total = 0, logs = 0, inst = 1}
-- the slot tags of the selected-slot controls (menu_text evt_hs_tag_aura / evt_hs_tag_mix, 9 languages), read once
local evt_sel = {tags = nil}
local function EVT_SelTag(slot)
  if evt_sel.tags == nil then
    evt_sel.tags = {}
    for k, id in pairs({[0] = 2257771510 --[[evt_hs_tag_aura]], [1] = 1104879536 --[[evt_hs_tag_mix]]}) do
      local ok, t = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], id)
      evt_sel.tags[k] = (ok and type(t) == "string" and t ~= "") and t or nil
    end
  end
  local t = evt_sel.tags[slot]
  if t == nil then
    return ""
  end
  return "  · " .. t
end

local function EVT_Reset()
  EVT_last = {{st = -1, skill = 0, ring = false, glyph = ""}, {st = -1, skill = 0, ring = false, glyph = ""}}
  EVT_pos = -1
  evt_ho_set = {}
  evt_ho_slide = {}
end
EVT_Reset()

function EVT_HiperInit()
  EVT_Reset()
  evt_ho_open = false
  evt_ho_want = false
end

function EVT_HiperSetupLayer(a1, a2)
  if a1 == EVT_HL then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_HL, a2, false)
    if EVT_last[a2 + 1] ~= nil then
      EVT_last[a2 + 1].st = -1
      EVT_last[a2 + 1].shown = false
    end
    evt_ho_set[a2 + 1] = nil
    if a2 == evt_cd.inst then
      evt_cd.swapped, evt_cd.shown, evt_cd.geo = false, nil, nil   -- a set-up layer has its retail sprite back
    end
  elseif a1 == 1154761048 --[[evt_hiper_chr_icon: the plate portrait, shown by EVT_PlateFace]]
    or a1 == 3071105076 --[[evt_hiper_input: the input column, shown by EVT_InputDraw]] then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, false)
  elseif a1 == EVT_BASE then
    EVT_pos = -1
  end
end

local function EVT_SetPos(pos)
  for p = 1, #EVT_ATC do
    for i = 1, #EVT_ATC[p] do
      pcall(funcLuaMenuCommand, 1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], EVT_BASE, 0, EVT_ATC[p][i], pos == p - 1)
    end
  end
end

local function EVT_Info(skill, what)
  local ok, v = funcLuaCommand(EVT_SKILL_INFO, skill, what)
  if ok and type(v) == "number" then
    return v
  end
  return nil
end

local EVT_CMD_MXP = 3173975339 --[[CMND_CHARACTERREFORGED_FUSION_PARTNER (was CMND_EVT_MX_BUFF_PARTNER, the same answer)]]
local EVT_CMD_LOG = 3661580131 --[[CMND_EVT_LOG]]
local EVT_CMD_APPEARANCE = 3148141229 --[[CMND_EVT_APPEARANCE]]
local EVT_SUB_MESH = 559600405 --[[_icon_sp_sub_dmy01]]
local EVT_SUB_TEX = 3992937973 --[[icon_sp_sub_dmy01]]
-- The widget's placeholder meshes at the plate's right end, white boxes when left visible: the sub-type slot
-- _icon_sp_sub_dmy01 (x +107..+141; kept when it holds a miximax partner's face) and the power number's box
-- _num_at_cmd_dmy01 / _gtxt_cmd_at01 (the plates show no power).
local function EVT_HideDummies(L, inst, face)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, EVT_SUB_MESH, false, inst)   -- face: own layer
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 365666709 --[[_num_at_cmd_dmy01]], false, inst)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 563708378 --[[_gtxt_cmd_at01]], false, inst)
end
-- The card's portrait at the band's right end, inside the band (2026-10-06, Nacho: as the player page's Hiper card).
-- Round 1 used the retail aura-row face object (soccer08_10_p5): "drawn true" in loader.log but nothing on screen.
-- Now layer evt_hiper_chr_icon = IF's object evt_ph_face, the player page's own card layer (the retail team00_30 aura
-- window: portrait quads _icon_fs_dmy01 / _icon_chr_dmy01 with the retail masked materials, white only on the band
-- rect, rounded right end; draw priority 570), its band / type icon / name hidden here (the plate draws those), 2
-- instances attached to the plates' _atc_chr01_r (attach row evt_hiper_chr01_r, placed on the plate band's top-right
-- corner, hiper_btn_build.py FACE_*). Scaled around that corner so the card's band (x -473..457, top 160, 88.15 high)
-- lands on the plate's band (EVT_HIPER_FACE_H high, right end on the corner). What it shows = the player page's rule,
-- shared: EVT_HC.Portrait (research/grafts/plate_hiper_plate/evt_hiper_card.lua, appended to this script by the graft):
--   * a miximax plate (aura type 2) or a fused player's plain-move plate (RB+X): the partner (CMND_EVT_MX_BUFF_PARTNER
--     -> face key 347353059), miximax face type 12 if it has one, else his plain chara icon;
--   * a «modo cambio» plate: the other form (loader value 16);
--   * keshin / armed / soul: the aura's own character (SKILL_INFO 17) on its retail slot and type (8 / 14);
--   * anything else: no portrait.
-- Nothing resolved -> the layer stays hidden (never a blank card).
local EVT_CHR = 1154761048 --[[evt_hiper_chr_icon]]
local EVT_CHR_ATC = 3457799775 --[[evt_hiper_chr01_r: its attach row on the plate]]
local EVT_CHR_HIDE = {734954092 --[[_fs_base01]], 1605611365 --[[_icon_fs_area_dmy01]]}
local EVT_CHR_TEXT = 2915321899 --[[_text_fs01]]
EVT_HIPER_FACE_H = 52                -- plate band height (plate layer units, before its 0.72): the card's band scaled to it
EVT_HIPER_FACE_DX, EVT_HIPER_FACE_DY = 0, 0   -- extra shift of the card's band corner (plate layer units)
local EVT_CHR_BAND_R, EVT_CHR_BAND_TOP, EVT_CHR_BAND_H = 457, 160, 88.15
local evt_chr_logs = 0

function EVT_PlateFaceHide(inst)
  pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_CHR, inst, false)
end

-- place / clean instance `inst` of the card layer (engine calls: from EVT_HiperStep only)
local function EVT_PlateFacePlace(inst)
  pcall(funcLuaMenuCommand, 1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], EVT_HL, inst, EVT_CHR_ATC, true)
  local k = EVT_HIPER_FACE_H / EVT_CHR_BAND_H
  funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], EVT_CHR, k, k, 1, inst)
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], EVT_CHR, EVT_HIPER_FACE_DX - EVT_CHR_BAND_R * k,
    EVT_HIPER_FACE_DY - EVT_CHR_BAND_TOP * k, 0, inst)
  for i = 1, #EVT_CHR_HIDE do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], EVT_CHR, EVT_CHR_HIDE[i], false, inst)
  end
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], EVT_CHR, EVT_CHR_TEXT, "", inst)
  funcLuaMenuCommand(2735666188 --[[CMND_SET_MENU_TEXT_VISIBLE]], EVT_CHR, EVT_CHR_TEXT, false, inst)
end

-- true when it drew a portrait. retry = a re-issue a few frames after the draw (the texture may still be loading)
function EVT_PlateFace(L, inst, hdl, retry, pover, skill)
  if type(EVT_HC) ~= "table" or type(EVT_HC.Portrait) ~= "function" then
    EVT_PlateFaceHide(inst)
    return false
  end
  local t = nil
  if skill ~= nil and skill ~= 0 then
    t = EVT_HC.AuraType(skill)
  end
  local fusion, mc = nil, nil
  local function key(param)
    local okk, k = pcall(funcLuaCommand, 347353059, param)
    if okk and type(k) == "number" and k ~= 0 then
      return k
    end
    return param
  end
  if pover ~= nil and pover ~= 0 then
    mc = {face = key(pover)}             -- «modo cambio» plate: the face of the other form (loader value 16)
  elseif t == 2 or t == nil or t == 255 then
    local okf, partner = pcall(funcLuaCommand, EVT_CMD_MXP, hdl)
    if okf and type(partner) == "number" and partner ~= 0 then
      fusion = {face = key(partner)}
    end
  end
  if fusion == nil and mc == nil and (t == nil or EVT_HC.FACE_BY_TYPE[t] == nil) then
    EVT_PlateFaceHide(inst)
    return false
  end
  EVT_PlateFacePlace(inst)
  local okp, shown = pcall(EVT_HC.Portrait, EVT_CHR, skill or 0, fusion, mc, "hiper_plates", inst)
  local ok = okp and shown ~= nil and shown ~= 0
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_CHR, inst, ok)
  if not retry or evt_chr_logs < 12 then
    evt_chr_logs = evt_chr_logs + 1
    local what = "own"
    if fusion ~= nil then
      what = "partner"
    elseif mc ~= nil then
      what = "mode change"
    end
    pcall(funcLuaCommand, EVT_CMD_LOG, "hiper_btn", "plate portrait", tostring(inst), tostring(hdl),
      string.format("%08X", skill or 0), "type " .. tostring(t), what,
      okp and tostring(shown) or ("error " .. tostring(shown)), retry and "retry" or "")
  end
  return ok
end

-- The name text of a miximax / soul aura as retail UpdateSkillCmdSkillName builds it: the partner's name (skill
-- info 17 -> chara info 10 for a miximax, 0 for a soul) put into the name's tag 2508554842 (CMND_TEXT_CONVERT).
-- Other auras: the name unchanged.
function EVT_AuraName(skill, name, auraType)
  local mixi = IsAuraSkillMixiMax(auraType)
  local soul = IsAuraSkillSoul(auraType)
  if not (mixi or soul) then
    return name
  end
  local s = ""
  local _, chara = funcLuaCommand(EVT_SKILL_INFO, skill, 17)
  if type(chara) == "number" and chara ~= 0 then
    local _, n = funcLuaCommand(4060384944 --[[CMND_GET_CHARA_INFO]], chara, mixi and 10 or 0)
    if type(n) == "string" then
      s = n
    end
  end
  local conv = funcLuaCommand(820766113 --[[CMND_TEXT_CONVERT?]], name, 0, 2508554842, s)
  if type(conv) == "string" then
    return conv
  end
  return name
end

-- the input column (2026-10-06 round 4): layer evt_hiper_input (IF object evt_hiper_input = the retail «RB + LB» guide
-- soccer08_19b with only its two RETAIL button texts on screen, _text_btn01 over _text_btn02; hiper_btn_build.py
-- INPUT_*), 2 instances hung on the plates' _atc_evt_input01 (left of the name, right of the type icon). Rounds 1-3
-- wrote into text nodes appended to the plate layout: only the first appended node ever drew (the tiny «RB» badge),
-- the A / X never did.
local EVT_IN = 3071105076 --[[evt_hiper_input]]
local EVT_IN_ATC = 299612426 --[[evt_hiper_input01: its attach row on the plate]]
local EVT_IN_TOP = 950238781 --[[_text_btn01]]
local EVT_IN_BOTTOM = 2712285063 --[[_text_btn02]]
EVT_INPUT_K = 0.8                  -- column scale (the retail 36-px button texts; x the plate's 0.72 on screen)
EVT_INPUT_DX, EVT_INPUT_DY = 0, 0  -- extra shift of the column (plate layer units)
local evt_glyph_logs, evt_glyph_last = 0, {}
-- the loader's face-button tags are the move cross's commands (<CMD_DECIDE_CMD_R_DOWN> ...); mapped to the menu
-- commands that always show those buttons
EVT_INPUT_TAGS = {["<CMD_DECIDE_CMD_R_DOWN>"] = "<CMD_ENTER>", ["<CMD_DECIDE_CMD_R_RIGHT>"] = "<CMD_BACK>",
  ["<CMD_DECIDE_CMD_R_LEFT>"] = "<CMD_FUNC4>", ["<CMD_DECIDE_CMD_R_UP>"] = "<CMD_FUNC3>"}

function EVT_InputHide(inst)
  pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_IN, inst, false)
end

-- the column of plate `inst`: attach entry on, scale / shift, the two texts, shown (engine calls: EVT_HiperStep only)
function EVT_InputDraw(inst, top, bottom)
  pcall(funcLuaMenuCommand, 1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], EVT_HL, inst, EVT_IN_ATC, true)
  local k = EVT_INPUT_K
  funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], EVT_IN, k, k, 1, inst)
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], EVT_IN, EVT_INPUT_DX, EVT_INPUT_DY, 0, inst)
  local r1 = funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], EVT_IN, EVT_IN_TOP, top, inst)
  local r2 = funcLuaMenuCommand(1083631230, EVT_IN, EVT_IN_BOTTOM, bottom, inst)
  funcLuaMenuCommand(2735666188 --[[CMND_SET_MENU_TEXT_VISIBLE]], EVT_IN, EVT_IN_TOP, top ~= "", inst)
  funcLuaMenuCommand(2735666188, EVT_IN, EVT_IN_BOTTOM, bottom ~= "", inst)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_IN, inst, top ~= "" or bottom ~= "")
  return r1, r2
end

function EVT_HiperDraw(inst, st, hdl, skill, ring, appear, glyph, armour, suffix, pover)
  local L = EVT_HL
  if st == 0 or skill == 0 then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], L, inst, false)
    EVT_PlateFaceHide(inst)
    EVT_InputHide(inst)
    return
  end
  local usable = st == 1
  local element = EVT_Info(skill, 7) or 1
  local nameId = EVT_Info(skill, 4) or 0
  local auraType = EVT_Info(skill, 13)
  local isAura = auraType ~= nil and auraType ~= 255
  local category = isAura and 8 or (EVT_Info(skill, 9) or 1)
  local armed = isAura and IsAuraSkillKeshinArmed(auraType) or false
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], L, inst, true)
  -- plate, name (same calls as a move row of SetupSkillCmdInfo)
  local tex = GetSkillElementBaseTextureName(inst, hdl, skill, element, category)
  if tex ~= 0 then
    SwapTextureSkillCmd(L, inst, tex)
  end
  UpdateSkillCmdSkillName(L, inst, hdl, skill, nameId, category)
  -- the category icon slot at the plate's left end (retail sets it for every move row; left alone it shows the
  -- widget's placeholder: a white chevron / square)
  if not pcall(SetupCommandActionSkillInfoCategoryIcon, L, inst, skill) then
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 2164615260 --[[_icon_sp_area_dmy01]], false, inst)
  end
  -- the button icons left of the name (game glyph tags; the text renderer follows the active device). 2026-09-30
  -- (Nacho): every plate shows its input, the miximax / soul aura plates («Miximax Trans») too: their name goes
  -- through the retail conversion of UpdateSkillCmdSkillName first (EVT_AuraName), then the glyphs are put before it.
  if glyph ~= "" and nameId ~= 0 then
    local name = funcLuaCommand(720417636, nameId)
    if isAura and type(name) == "string" then
      local okn, conv = pcall(EVT_AuraName, skill, name, auraType)
      if okn and type(conv) == "string" then
        name = conv
      end
    end
    if armour then
      -- the armour plate: the button glyphs, then the retail armed-form logo (_gtxt_cmd_armed01) instead of a text
      name = ""
    end
    if type(name) == "string" and suffix ~= nil and suffix ~= "" then
      name = name .. suffix
    end
    if type(name) == "string" then
      funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], L, 1123081621 --[[_text_cmd_sp01]], name, inst)
    end
  end
  -- 2026-10-06 (Nacho): the input as a column at the plate's left end, «RB» over «A» (RB+A plate) / «X» (RB+X
  -- plate), on layer evt_hiper_input (see EVT_IN). Pad: one game glyph tag per text (the text renderer draws the
  -- active device's icon), the face buttons mapped by EVT_INPUT_TAGS (A <CMD_ENTER>, B <CMD_BACK>, X <CMD_FUNC4>,
  -- Y <CMD_FUNC3>); keyboard ("[H]"): the key alone in the lower text.
  local buttons = {}
  for tag in string.gmatch(glyph or "", "<[^>]+>") do buttons[#buttons + 1] = EVT_INPUT_TAGS[tag] or tag end
  local top, bottom = buttons[1] or "", buttons[2] or ""
  if #buttons <= 1 then
    top, bottom = "", buttons[1] or glyph or ""
  end
  local okg, r1, r2 = pcall(EVT_InputDraw, inst, top, bottom)
  local gkey = top .. "|" .. bottom
  if evt_glyph_last[inst + 1] ~= gkey and evt_glyph_logs < 40 then
    evt_glyph_last[inst + 1] = gkey
    evt_glyph_logs = evt_glyph_logs + 1
    pcall(funcLuaCommand, EVT_CMD_LOG, "hiper_btn glyph", "inst=" .. tostring(inst), "top=" .. top, "bottom=" .. bottom,
      "raw=" .. tostring(glyph), okg and ("set " .. tostring(r1) .. "/" .. tostring(r2)) or ("error " .. tostring(r1)))
  end
  funcLuaMenuCommand(1284929827, L, inst, usable)
  SetVisibleCmdButton(L, inst, true)
  SetVisibleSkillCmdName(L, inst, true)
  -- the placeholder boxes at the plate's right end (2026-09-28, capture 71: a white square right of "Sirena").
  -- SetVisibleCmdButton turns node _pos_base01 on, which shows its child meshes again: the hides used to run before
  -- it and were undone. They now run after it (retail SetupAuraSlotInfo also sets the sub icon after
  -- SetVisibleCmdButton), at the end of the draw and every frame from EVT_HiperStep.
  -- A fused player (module miximax) / a «modo cambio» plate: the partner's face at the band's right end (own layer,
  -- EVT_PlateFace), with the plate page's rule: the miximax face icon of key 347353059(partner) if one exists, else the
  -- plain chara icon.
  local okf, face = pcall(EVT_PlateFace, L, inst, hdl, false, pover, skill)
  face = okf and face == true
  EVT_HideDummies(L, inst, face)
  for i = 1, #EVT_CUBES do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, EVT_CUBES[i], false, inst)
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 1621112166 --[[_cmd_pw_cube01]], false, inst)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 1206374040 --[[_gtxt_cmd_armed01]], armed or armour == true, inst)
  funcLuaMenuCommand(2158717427, L, 4081284803 --[[_pos_at01]], false, inst)
  funcLuaMenuCommand(1233047821, L, inst, 2467766246, false)
  funcLuaMenuCommand(1233047821, L, inst, 875648615, false)
  -- lit / greyed (as SetSkillCmdGrayout)
  local gray = 2300007848 --[[cmd_base_sp_grayout01]]
  local ringTex = 97673312 --[[sp_ring02]]
  if isAura then
    gray = armed and 1729705092 --[[cmd_base_sp_grayout03]] or 270402578 --[[cmd_base_sp_grayout02]]
    ringTex = armed and 3183539200 --[[sp_ring02_03]] or 3402089622 --[[sp_ring02_02]]
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 3742978053 --[[_cmd_base_sp_grayout01]], not usable, inst)
  funcLuaMenuCommand(558735651, L, 2804251149 --[[soccer08_10.g4tx]], gray, 2300007848 --[[cmd_base_sp_grayout01]], 0, inst)
  -- RB held: the selection ring + the "Active" pulse ("press the button now")
  funcLuaMenuCommand(558735651, L, 2804251149 --[[soccer08_10.g4tx]], ringTex, 97673312 --[[sp_ring02]], 0, inst)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], L, 1213120893 --[[_sp_ring02]], ring, inst)
  local dark = usable and 0 or 0.5
  local col = usable and 1 or 0.5
  funcLuaMenuCommand(2484004035, L, inst, 1123081621 --[[_text_cmd_sp01]], dark)
  funcLuaMenuCommand(2771105252, L, inst, 1123081621 --[[_text_cmd_sp01]], col, col, col)
  funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], L, inst, 1633223871, usable and 2 or 0)
  funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], L, inst, 846750395, 2)
  if ring and usable then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], L, inst, 1286797620 --[[Active]], 0, 4054903817)
  else
    funcLuaMenuCommand(1380315136, L, inst, 1286797620 --[[Active]], 2, 4054903817)
  end
  if appear then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], L, inst, 71445658 --[[Open]], 0, 2181236453)
  end
  EVT_HideDummies(L, inst, face)
  return face
end

local function EVT_Num(v)
  if type(v) == "number" then
    return v
  end
  return 0
end

local function EVT_Str(v)
  if type(v) == "string" then
    return v
  end
  return ""
end

local EVT_tick = 0   -- EVT_HiperStep calls (frames)

-- 2026-10-06 (Nacho): the «modo cambio» cooldown of the RB+A plate is a thin bar along the plate's bottom that fills up
-- from left to right until the swap is usable again (no «19s» text after the name; the plate stays greyed while it
-- cools down). Drawn on the plate's spare quad _cmd_pw_cube01 (the move row's power cube, always hidden on these
-- plates; under _pos_base01, drawn after the grey-out) of instance 0, with the retail sprite gauge_recast_aura01 of
-- soccer00_54 (the aura recast gauge, 4 x 12, orange, opaque rows 2..8; the clean_hud time line's sprite) loaded here
-- (CMND_LOAD_MENU_RES_TEXTURE) and swapped into the quad's slot; node scale = quad size, node translation = top-left.
-- Fill = loader value 17 (cooldown recovered, per mille); a loader without it: from the seconds (value 15), the first
-- value of a cooldown taken as its length. Engine calls only from EVT_HiperStep (PostStep).
EVT_HIPER_CD_BAR = true
EVT_HIPER_CD_BAR_L = -226           -- plate layer units (before the plate's 0.72): left end, right of the round cap
EVT_HIPER_CD_BAR_R = 166            -- right end (the plate's visible right edge is ~172)
EVT_HIPER_CD_BAR_BOTTOM = -21       -- bottom of the line (the plate's visible bottom is -27)
EVT_HIPER_CD_BAR_H = 6              -- thickness (x 0.72: ~4 px)
local EVT_CD_MESH = 1621112166 --[[_cmd_pw_cube01]]
local EVT_CD_SLOT = 3488642376 --[[its sprite slot (40 x 40 power cube)]]
local EVT_CD_TEX_PATH = "#/menu/00_soccer/soccer00/soccer00_54/soccer00_54.g4tx"
local EVT_CD_TEX = 3000726149 --[[crc32 of EVT_CD_TEX_PATH]]
local EVT_CD_SPRITE = 4200959402 --[[gauge_recast_aura01]]
local EVT_CD_ROWS, EVT_CD_OPAQUE = 12, 7

local function EVT_CdLog(...)
  if evt_cd.logs < 8 then
    evt_cd.logs = evt_cd.logs + 1
    pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "hiper_btn", "cooldown bar", ...)
  end
end

local function EVT_CdTexReady()
  if evt_cd.tex == 2 then
    return true
  elseif evt_cd.tex == -1 then
    return false
  elseif evt_cd.tex == 0 then
    local ok = pcall(funcLuaMenuCommand, 839427544 --[[CMND_LOAD_MENU_RES_TEXTURE]], EVT_CD_TEX_PATH)
    evt_cd.tex, evt_cd.t = ok and 1 or -1, 0
    if not ok then
      EVT_CdLog("texture load FAILED (no bar)")
    end
    return false
  end
  evt_cd.t = evt_cd.t + 1
  local ok, busy = pcall(funcLuaCommand, 1506186496 --[[texture still loading]], EVT_CD_TEX)
  if not ok or evt_cd.t > 600 then
    evt_cd.tex = -1
    EVT_CdLog("texture never loaded (no bar)")
    return false
  end
  if busy ~= true and evt_cd.t >= 10 then
    evt_cd.tex = 2
    EVT_CdLog("texture in after", tostring(evt_cd.t), "frames")
    return true
  end
  return false
end

local function EVT_CdShow(on)
  if evt_cd.shown ~= on then
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], EVT_HL, EVT_CD_MESH, on, evt_cd.inst)
    evt_cd.shown = on
  end
end

-- frac: part of the cooldown recovered (0..1), nil = no bar
local function EVT_CdBar(frac)
  if frac == nil or not EVT_HIPER_CD_BAR or frac >= 1 then
    EVT_CdShow(false)
    return
  end
  if not EVT_CdTexReady() then
    EVT_CdShow(false)
    return
  end
  if not evt_cd.swapped then
    funcLuaMenuCommand(558735651 --[[swap texture]], EVT_HL, EVT_CD_TEX, EVT_CD_SPRITE, EVT_CD_SLOT, 0, evt_cd.inst)
    evt_cd.swapped, evt_cd.geo = true, nil
  end
  local w = (EVT_HIPER_CD_BAR_R - EVT_HIPER_CD_BAR_L) * math.max(0, frac)
  if w < 1 then
    EVT_CdShow(false)
    return
  end
  local h = EVT_HIPER_CD_BAR_H
  local quad_h = h * EVT_CD_ROWS / EVT_CD_OPAQUE
  local top = EVT_HIPER_CD_BAR_BOTTOM + h * 9 / EVT_CD_OPAQUE   -- opaque rows 2..8 of the quad end on the bottom
  local g = evt_cd.geo
  if g == nil or math.abs(g[1] - w) > 0.05 or g[2] ~= top or g[3] ~= quad_h then
    funcLuaMenuCommand(2885415772 --[[node size]], EVT_HL, evt_cd.inst, EVT_CD_MESH, w, quad_h)
    funcLuaMenuCommand(2575768773 --[[node translation]], EVT_HL, evt_cd.inst, EVT_CD_MESH, 0, EVT_HIPER_CD_BAR_L)
    funcLuaMenuCommand(2575768773 --[[node translation]], EVT_HL, evt_cd.inst, EVT_CD_MESH, 1, top)
    evt_cd.geo = {w, top, quad_h}
  end
  EVT_CdShow(true)
end

local function EVT_Update(inst, st, hdl, skill, ring, glyph, armour, suffix, pover)
  local last = EVT_last[inst + 1]
  suffix = suffix or ""
  pover = pover or 0
  if st == last.st and skill == last.skill and ring == last.ring and glyph == last.glyph and hdl == last.hdl and armour == last.armour
    and suffix == (last.suffix or "") and pover == (last.pover or 0) then
    return
  end
  local appear = last.st ~= 1 and last.st ~= 2
  last.st = st
  last.skill = skill
  last.ring = ring
  last.glyph = glyph
  last.hdl = hdl
  last.armour = armour
  last.suffix = suffix
  last.pover = pover
  local ok, face = pcall(EVT_HiperDraw, inst, st, hdl, skill, ring, appear, glyph, armour, suffix, pover)
  last.face = ok and face == true
  if inst == evt_cd.inst then
    evt_cd.shown = nil   -- the draw hid the bar's quad (_cmd_pw_cube01): EVT_CdBar sets it again
  end
  last.drawTick = EVT_tick
  last.hasFace = false
  if ok and st ~= 0 and skill ~= 0 then
    local okp, partner = pcall(funcLuaCommand, EVT_CMD_MXP, hdl)
    last.hasFace = (okp and type(partner) == "number" and partner ~= 0) or pover ~= 0
  end
  last.shown = ok and st ~= 0 and skill ~= 0
  if appear and last.shown then
    evt_ho_slide[inst + 1] = EVT_tick   -- the plate comes in from the right screen edge (EVT_HiperOpenPlace)
  end
  if not ok then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_HL, inst, false)
    EVT_PlateFaceHide(inst)
    EVT_InputHide(inst)
  end
end

-- 2026-09-30 (Nacho): move list open. clean_hud keeps the open menu at the closed anchor (the retail slide of the
-- cross, 330 left, is held at rest), so the plates hung right of the ">" arrow would sit off the right edge / on the
-- menu. While the list is open (the retail open state: UpdateAnimeMoveOffsetCmdBase(true), wrapped below; without
-- clean_hud the retail slide still runs) the two plates of pos 0 ("right") go under the menu, right-aligned:
-- CMND_SET_LAYER_LOCAL_POS relative to their locators, x from the measured cross (so it holds with and without the
-- slide or the duel "vs" shift), y a fixed step below the cross. Back to (0, 0) when the list closes. pos 1 ("above")
-- is not moved. Display only.
EVT_HIPER_OPEN_MOVE = true
EVT_HIPER_OPEN_RIGHT = 0            -- plates' right edge while the list is open (layout units from the right edge):
                                    -- 0 = flush against the screen edge, a card out of the right side (Nacho 2026-09-30;
                                    -- was -16)
-- 2026-09-30 (Nacho): the plates slide in from the right screen edge when they appear (Open) and when the list opens
-- and they move to the corner: an added LOCAL_POS x offset from EVT_HIPER_SLIDE_DX to 0 over EVT_HIPER_SLIDE_FRAMES
-- (ease-out). 0 frames = no slide. Display only.
EVT_HIPER_SLIDE_FRAMES = 9
EVT_HIPER_SLIDE_DX = 380            -- start offset: the whole plate (2 x 176 wide) past the right edge
EVT_HIPER_OPEN_Y = {-192, -192}     -- plate centres while open, relative to the cross centre (instance 0 / 1): below the
                                    -- lowest plate of the cross (_cmd01_02 at -76, bottom ~-106) and the page dots (-62);
                                    -- one row (Nacho 2026-09-30: the RB+X plate left of the RB+A plate)
EVT_HIPER_OPEN_GAP = 12             -- gap between the RB+X plate (instance 1, left) and the RB+A plate (instance 0, right)
local EVT_HO_ATC_X = 504            -- x of _atc_hiper01_r / _atc_hiper02_r relative to the cross (hiper_btn_build.py _RX)
local EVT_HO_ATC_Y = {-36, 30}      -- their y (instance 0 / 1)
local EVT_HO_HALF_R = 133           -- plate right half-width (245 x 0.72)
local EVT_HO_CROSS = -342           -- retail cross x from the right edge (closed, no duel shift): fallback of the measure

local evt_ho_prevOffset = rawget(_ENV, "UpdateAnimeMoveOffsetCmdBase")
if type(evt_ho_prevOffset) == "function" then
  rawset(_ENV, "UpdateAnimeMoveOffsetCmdBase", function(a1, ...)
    evt_ho_open = a1 == true
    return evt_ho_prevOffset(a1, ...)
  end)
end

-- 2026-10-07 (Nacho: «quita también en partido el botón de R2 desinvocar para el modo cambio»): with the loader's
-- [hiper_slot] mode_change_dismiss = false the retail aura release button does nothing for a player in his «modo
-- cambio» form (only RB+A swaps him back), so its guide (soccer08_17b «Desactivar») is hidden while the controlled
-- player is in that form (loader value 20 of CMND_EVT_HIPER_BTN). Keshin / armour / miximax keep it. Engine calls only
-- inside the engine's own call of UpdateVisibleAttachButtonGuide and from EVT_HiperStep (PostStep).
local EVT_REL_GUIDE = 3063505148 --[[soccer08_17b_aura_release_button_guide]]
EVT_MC_NO_RELEASE = false
local evt_mc_prevVis = rawget(_ENV, "UpdateVisibleAttachButtonGuide")
if type(evt_mc_prevVis) == "function" then
  rawset(_ENV, "UpdateVisibleAttachButtonGuide", function(a1, a2, ...)
    local r = evt_mc_prevVis(a1, a2, ...)
    if a1 == EVT_REL_GUIDE and EVT_MC_NO_RELEASE then
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, false)
    end
    return r
  end)
end

-- the cross (_pos_gaiji01) from the right screen edge in layout units, as hud_layout measures it: relative to the
-- layer root soccer08_07_output, scale from _cmd01_01 (128 layout units right of the cross)
local function EVT_HO_CrossX()
  local gp = 499270986 --[[CMND_GET_MESH_GLOBAL_POSITION]]
  local ok1, gx = pcall(funcLuaMenuCommand, gp, EVT_BASE, 0, 708999887 --[[_pos_gaiji01]])
  local ok2, ox = pcall(funcLuaMenuCommand, gp, EVT_BASE, 0, 2812881813 --[[soccer08_07_output]])
  local ok3, cx = pcall(funcLuaMenuCommand, gp, EVT_BASE, 0, 1816929598 --[[_cmd01_01]])
  if not ok1 or not ok2 or type(gx) ~= "number" or type(ox) ~= "number" then
    return EVT_HO_CROSS
  end
  local k = 1
  if ok3 and type(cx) == "number" and (cx - gx) / 128 > 0.25 and (cx - gx) / 128 < 4 then
    k = (cx - gx) / 128
  end
  local rel = (gx - ox) / k
  if rel >= 0 or rel <= -1920 then
    return EVT_HO_CROSS
  end
  return rel
end

-- x offset of a running slide-in of plate `inst` (0 when none; ends the slide after its last frame)
local function EVT_SlideDx(inst)
  local start = evt_ho_slide[inst + 1]
  if start == nil then
    return 0
  end
  local n = EVT_HIPER_SLIDE_FRAMES or 0
  local t = n > 0 and (EVT_tick - start) / n or 1
  if t >= 1 or t < 0 then
    evt_ho_slide[inst + 1] = nil
    return 0
  end
  local r = 1 - t
  return math.floor(EVT_HIPER_SLIDE_DX * r * r * r + 0.5)
end

-- 2026-10-02 (Nacho): the RB+X plate (instance 1) LEFT of the RB+A plate (instance 0) on one row, always (it sat
-- above it while the move list was closed). pos 0 ("right"): both plates in the corner under the cross, right-aligned
-- (the open-list placement, now also with the list closed: right of the ">" arrow there is no room for two plates).
-- pos 1 ("above"): the RB+X plate moves left of the RB+A plate, on its row. Display only.
EVT_HIPER_ONE_ROW = true
local EVT_HO_U_Y = {150, 216}        -- y of _atc_hiper01_u / _atc_hiper02_u (hiper_btn_build.py ATC)

function EVT_HiperOpenPlace()
  local want = EVT_HIPER_OPEN_MOVE and (evt_ho_open or EVT_HIPER_ONE_ROW) and EVT_pos == 0
  if want ~= evt_ho_want then
    evt_ho_want = want
    if want then
      for inst = 0, 1 do
        if EVT_last[inst + 1] ~= nil and EVT_last[inst + 1].shown then
          evt_ho_slide[inst + 1] = EVT_tick
        end
      end
    end
  end
  local cross = want and EVT_HO_CrossX() or EVT_HO_CROSS
  local row_dx = 314 + (EVT_HIPER_OPEN_GAP or 0)
  for inst = 0, 1 do
    local dx, dy = 0, 0
    if want then
      dx = math.floor(EVT_HIPER_OPEN_RIGHT - EVT_HO_HALF_R - (cross + EVT_HO_ATC_X) + 0.5)
      if inst == 1 and EVT_HIPER_OPEN_Y[1] == EVT_HIPER_OPEN_Y[2] then
        dx = dx - row_dx
      end
      dy = EVT_HIPER_OPEN_Y[inst + 1] - EVT_HO_ATC_Y[inst + 1]
    elseif EVT_HIPER_ONE_ROW and EVT_pos == 1 and inst == 1 then
      dx = -row_dx
      dy = EVT_HO_U_Y[1] - EVT_HO_U_Y[2]
    end
    dx = dx + EVT_SlideDx(inst)
    local key = dx .. "," .. dy
    if evt_ho_set[inst + 1] ~= key then
      funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], EVT_HL, dx, dy, 0, inst)
      evt_ho_set[inst + 1] = key
    end
  end
end

EVT_HIPER_HIDE_IN_TACTICS = true     -- 2026-09-29 (Nacho): no Hiper / armour plate («RB A Atenea») while the LB tactics menu is up
EVT_HIPER_FACE_RETRY = {10, 30, 60, 120, 240}   -- frames after a draw when the partner face is issued again

function EVT_HiperStep()
  local r = {pcall(funcLuaCommand, EVT_CMD_BTN)}
  if r[1] ~= true then
    r = {}
  end
  EVT_tick = EVT_tick + 1
  local st, hdl, skill = EVT_Num(r[2]), EVT_Num(r[3]), EVT_Num(r[4])
  local ring = r[5] == true
  local pos = EVT_Num(r[6])
  local glyph = EVT_Str(r[8])
  local st2, skill2, glyph2 = EVT_Num(r[9]), EVT_Num(r[10]), EVT_Str(r[11])
  if EVT_HIPER_HIDE_IN_TACTICS then
    local okt, tac = pcall(funcLuaCommand, 1350751656 --[[CMND_IS_SPECIAL_TACTICS_CMD_MODE]])
    if okt and tac == true then
      st, st2 = 0, 0   -- both plates "nothing to show": hidden now, drawn again (Open) when the menu closes
    end
  end
  if pos ~= EVT_pos then
    EVT_SetPos(pos)
    EVT_pos = pos
  end
  local armour = r[12] == true
  -- value 20 (r[22]): the controlled player is in his «modo cambio» form and its release button is refused: no release guide
  local noRel = r[22] == true
  if noRel then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], EVT_REL_GUIDE, 0, false)
  end
  EVT_MC_NO_RELEASE = noRel
  -- «modo cambio» (docs/game/mechanics/mode-change.md §5.4; loader values 11-17: state, actor, carrier, (unused),
  -- cooldown s, face of the other form, cooldown recovered per mille): the plate that holds it (the mix slot's, RB+B,
  -- since 2026-10-12; RB+A for an older loader) shows the cooldown as a bar along its bottom (EVT_CdBar) and the face
  -- of the form it swaps to
  local st3, skill3 = EVT_Num(r[13]), EVT_Num(r[15])
  local cd3, face3 = EVT_Num(r[17]), EVT_Num(r[18])
  local cdFrac = nil
  -- selected-slot controls (values 22-25): on, selected slot, the move plate's slot (2 = none), both slots filled
  local selOn, selSlot, mvSlot, selBoth = r[23] == true, EVT_Num(r[24]), EVT_Num(r[25]), r[26] == true
  local sfx0, sfx1 = "", ""
  if selOn and selBoth then
    if mvSlot == 0 or mvSlot == 1 then
      sfx0 = EVT_SelTag(mvSlot)
    end
    sfx1 = EVT_SelTag(selSlot)
  end
  local swInst = nil
  if st3 ~= 0 and skill3 ~= 0 and skill3 == skill2 then
    swInst = 1
  elseif st3 ~= 0 and skill3 ~= 0 and skill3 == skill then
    swInst = 0
  end
  if swInst ~= nil and swInst ~= evt_cd.inst then
    pcall(EVT_CdShow, false)                   -- the bar leaves the other plate
    evt_cd.inst = swInst
    evt_cd.swapped, evt_cd.shown, evt_cd.geo = false, nil, nil
  end
  if swInst ~= nil then
    if swInst == 0 then
      EVT_Update(0, st, hdl, skill, ring, glyph, armour and not selOn, sfx0, face3)
    else
      EVT_Update(0, st, hdl, skill, ring, glyph, armour and not selOn, sfx0)
    end
    if type(r[19]) == "number" then
      if r[19] < 1000 then
        cdFrac = math.max(0, r[19]) / 1000
      end
    elseif cd3 > 0 then
      evt_cd.total = math.max(evt_cd.total, cd3)
      cdFrac = 1 - cd3 / evt_cd.total
    end
  else
    EVT_Update(0, st, hdl, skill, ring, glyph, armour and not selOn, sfx0)
  end
  if cd3 <= 0 then
    evt_cd.total = 0
  end
  if swInst == 1 then
    EVT_Update(1, st2, hdl, skill2, ring, glyph2, false, sfx1, face3)
  else
    EVT_Update(1, st2, hdl, skill2, ring, glyph2, armour and selOn, sfx1)
  end
  if not EVT_last[evt_cd.inst + 1].shown then
    cdFrac = nil
  end
  local okc, errc = pcall(EVT_CdBar, cdFrac)
  if not okc then
    EVT_CdLog("error", tostring(errc))
  end
  -- keep the placeholder boxes hidden between two draws (anything that re-shows the plate's meshes); re-issue a
  -- partner face a few times after each draw (its texture may still be loading on the first call)
  for inst = 0, 1 do
    local last = EVT_last[inst + 1]
    if last.shown then
      if last.hasFace and last.drawTick then
        local age = EVT_tick - last.drawTick
        for i = 1, #EVT_HIPER_FACE_RETRY do
          if age == EVT_HIPER_FACE_RETRY[i] then
            local okf, face = pcall(EVT_PlateFace, EVT_HL, inst, last.hdl, true, last.pover, last.skill)
            last.face = okf and face == true
          end
        end
      end
      pcall(EVT_HideDummies, EVT_HL, inst, last.face)
    end
  end
  pcall(EVT_HiperOpenPlace)
end
