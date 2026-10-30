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
PL.MX_STUB = nil                                 -- nil = auto (stub while the loader does not answer), true / false = force
PL.MX_CMD = {SET = @crc:CMND_EVT_MX_SET@, GET = @crc:CMND_EVT_MX_GET@, CLEAR = 520287167,
  CAN_BASE = 2189230194, PARTNER_OF = 2051756436,
  CANDIDATES = @crc:CMND_EVT_MX_CANDIDATES@,
  PAGE_FUSION = @crc:CMND_CHARACTERREFORGED_PAGE_FUSION@,
  PAGE_FUSION_CLEAR = @crc:CMND_CHARACTERREFORGED_PAGE_FUSION_CLEAR@}
-- SET codes (miximax-chrono-stone.md §12.4): 0 ok, 1 module off, 2 Prime, 3 base not found, 4 partner not owned,
-- 5 same card, 6 rule, 7 write error
-- (text ids; 10 = a «no miximax» passive)
PL.MX_SET_ERR = {[1] = 1193744461 --[[skill_table_mx_off]], [2] = 3430873949 --[[skill_table_mx_prime]],
  [3] = 4276049693 --[[skill_table_base_card_missing]], [4] = 3802133517 --[[skill_table_mx_not_owned]],
  [5] = 2627702561 --[[skill_table_mx_self]], [6] = 2699616346 --[[skill_table_mx_in_use]],
  [7] = 4225651066 --[[skill_table_mx_save_failed]], [10] = 3206737278 --[[skill_table_mx_overdrive]]}
PL.MX_TX = {PRIME_OR_PARTNER = 282558928 --[[skill_table_mx_prime_or_partner]],
  PARTNER_REFUSED = 4195072636 --[[skill_table_mx_partner_refused]], NO_CANDIDATES = 1999381056 --[[skill_table_mx_no_candidates]],
  PARTNER_GUIDE = 1838322589 --[[skill_table_mx_partner_guide]], MOVE_KNOWN = 1850261395 --[[skill_table_mx_move_known]],
  PARTNER_NO_MOVES = 2742209765 --[[skill_table_mx_partner_no_moves]], MOVE_GUIDE = 3725616804 --[[skill_table_mx_move_guide]],
  MOVE_REFUSED = 962101975 --[[skill_table_mx_move_refused]], ASK_FUSE = 584763947 --[[skill_table_mx_ask_fuse]],
  ASSIGNED = 544123214 --[[skill_table_mx_assigned]], SAVED_NOT_SET = 119523110 --[[skill_table_mx_saved_not_set]],
  ASK_REMOVE = 1297342256 --[[skill_table_mx_ask_remove]], ERROR_CODE = 4007592817 --[[skill_table_error_code]]}
PL.MX_ITEMS_CMD = @crc:CMND_EVT_MX_ITEMS@
PL.MX_POS = {[1] = "PR", [2] = "DL", [3] = "MC", [4] = "DF"}
PL.MX_LAYER = 3679282495                         -- team00_30_aura_mixi_max_detail_info
PL.mx_stub = {}                                  -- stub store: baseParam -> {partner, move, chara, element, name}
PL.mx_elem = {}                                  -- partner param -> element (from the candidate list)

function PL.MxParam(hdl)
  local ok, p = pcall(funcLuaCommand, 1131797651, hdl, 4)
  return ok and type(p) == "number" and EVT_U32(p) or 0
end

function PL.MxCharaName(chara)
  local ok, a, b = pcall(funcLuaCommand, @crc:CMND_GET_CHARA_INFO@, chara, 10)
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
    local okh, phdl = pcall(funcLuaCommand, @crc:CMND_EVT_MIXIMAX_GET@, h)
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
        local ok, _, pos = pcall(funcLuaCommand, @crc:CMND_GET_CHARA_INFO@, p, 11)
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
    local idx = funcLuaMenuCommand(@crc:CMND_SEARCH_PRIM_INDEX@, L, k, 3334923667)
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
  -- miniface on the row's icon quad (as the retail aura windows draw a character icon): the shared face function,
  -- drawn again on every row draw (PL.MxRowBase hides the quad), shown once loaded
  if e.chara ~= nil and e.chara ~= 0 then
    VRFW_FaceIcon.Forget(L, k)
    VRFW_FaceIcon.Face(L, k, e.chara, 2164615260 --[[_icon_sp_area_dmy01]], 566439826 --[[icon_sp_area_dmy01]])
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
PL.MX_CMD.BANK_MODE = @crc:CMND_EVT_MX_BANK_MODE@
PL.MX_CMD.PARTNER_OK = @crc:CMND_EVT_MX_PARTNER_OK@                  -- (hdl): the bank mode's grey rule for one card

-- 2026-09-30: true when the Hiper picker just closed on «Crear miximax» and the bank can take it straight away (the
-- screen then stays suspended until the bank closes: EVT_PickCoroutine, PL.MxBankPick, PL.MxResumeDirect)
function PL.MxDirectPick(row)
  if row ~= 0 or not PL.MX_BANK or n == nil or n == 0 or PL.MxStub() then
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
    why = (not allowed) and PL.MX_TX.PARTNER_REFUSED or nil}
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
    why = PL.MX_TX.PARTNER_REFUSED}
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
      EVT_Message(PL.Txt(tonumber(why) == 10 and PL.MX_SET_ERR[10] or PL.MX_TX.PRIME_OR_PARTNER))
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
      EVT_Message(PL.Txt(PL.MX_TX.NO_CANDIDATES))
      return
    end
    for _, e in ipairs(cands) do
      e.grey = not e.allowed
    end
    local pick = PL.MxList(cands, 0, {row = PL.MxRowChara, guide = PL.Txt(PL.MX_TX.PARTNER_GUIDE)})
    if pick < 0 then
      return
    end
    partner = cands[pick + 1]
  end
  if not partner.allowed then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(partner.why or PL.MX_SET_ERR[6]))   -- in use: already a base or a partner
    return
  end
  -- the partner's 6 moves; the base learns ONE of them (2026-09-25 rule, was 2): no auras / Hiper moves, no keeper
  -- moves for a non-keeper base, not a move the base already has
  local okp, _, mypos = pcall(funcLuaCommand, @crc:CMND_GET_CHARA_INFO@, base, 11)
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
      local name = mine[sk] and PL.Txt(PL.MX_TX.MOVE_KNOWN, EVT_Name(sk)) or EVT_Name(sk)
      moves[#moves + 1] = {id = sk, name = name, grey = bad, num = type(pw) == "number" and pw or nil}
    end
  end
  if #moves == 0 then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.MX_TX.PARTNER_NO_MOVES))
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
    local mpick = PL.MxList(moves, 0, {row = PL.MxRowMove, guide = PL.Txt(PL.MX_TX.MOVE_GUIDE)})
    if mpick < 0 then
      return
    end
    mv = moves[mpick + 1]
  end
  if mv.grey then
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.MX_TX.MOVE_REFUSED))
    return
  end
  local pname = PL.MxCharaName(partner.chara)
  if (PL.mx_bank_move or 0) == 0 and not PL.MxAsk(PL.Txt(PL.MX_TX.ASK_FUSE, {NAME = pname, MOVE = mv.name})) then
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
    EVT_Message(PL.MX_SET_ERR[st] ~= nil and PL.Txt(PL.MX_SET_ERR[st]) or PL.Txt(PL.MX_TX.ERROR_CODE, st))
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
  if row == 0 and del and skill == PL.MX_FUSION then
    PL.MxClear()
    if EVT_Skill(0) == PL.MX_FUSION then
      EVT_RestoreCoroutine(0)
    end
    return
  end
  if row == 0 and skill == PL.MX_CREATE then
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
          EVT_Message(PL.Txt(PL.MX_TX.ASSIGNED, PL.mx_done_name or ""))
        end
        PL.mx_scene_msg_shown = false
      else
        funcLuaCommand(C.SE, SE_NG)
        EVT_Message(PL.Txt(PL.MX_TX.SAVED_NOT_SET))
      end
    end
    return
  end
  return PL.MxPrevEquip(row, skill, inv_hint, cur)
end
