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
PL.MC_CMD = {ON = 1689747210, ITEMS = 2121540544, CANDIDATES = 2117900510, ADD = @crc:CMND_EVT_MC_ADD@, LIST = 2447822974,
  ITEM = 3392474488, EQUIP = 1830357309, DELETE = 2464860440}
-- (text ids)
PL.MC_ERR = {[1] = 1343733470 --[[skill_table_mc_off]], [3] = 4276049693 --[[skill_table_base_card_missing]],
  [4] = 775674631 --[[skill_table_mc_not_usable]], [5] = 4119756153 --[[skill_table_mc_self]],
  [6] = 1857720506 --[[skill_table_mc_full]], [7] = 2819639299 --[[skill_table_mc_save_failed]],
  [21] = 1313234001 --[[skill_table_mc_pick_bank]], [22] = 3877223226 --[[skill_table_mc_no_data]],
  [23] = 4119756153 --[[skill_table_mc_self]], [24] = 2126408687 --[[skill_table_mc_has_aura]],
  [25] = 3105420297 --[[skill_table_mc_reserved]], [26] = 2163278701 --[[skill_table_mc_in_team]]}
PL.MC_TX = {NO_CANDIDATES = 3988397041 --[[skill_table_mc_no_candidates]], PICK_GUIDE = 1723078806 --[[skill_table_mc_pick_guide]],
  ASK_CREATE = 3616500489 --[[skill_table_mc_ask_create]], ASSIGNED = 4280341329 --[[skill_table_mc_assigned]],
  SAVED_NOT_SET = 2643066519 --[[skill_table_mc_saved_not_set]], ASK_DELETE = 2595117433 --[[evt_hs_ask_mc_delete]],
  NAME = 3504749084 --[[skill_table_mc_name]], ERROR_CODE = 4007592817 --[[skill_table_error_code]]}
PL.MC_KEY_N = 1284887561                          -- evt_mc_n: number of changes of the player (pick block)
PL.MC_KEY_C = {954567708, 1340259466, 3605785904, 2716655014, 1065895941, 1217362067, 3515230505, 2793478591}
PL.MC_CREATE = 3567812479                         -- wmc_evt_create «Crear nuevo cambio»
PL.MC_CAR = {754700454, 1543299120, 3270881674, 3052568860, 731255999, 1553015849, 3315103123, 2996782341}

function PL.McLive()
  if PL.mc_live == nil then
    local ok, on = pcall(funcLuaCommand, PL.MC_CMD.ON)
    PL.mc_live = ok and on == true
  end
  return PL.mc_live
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
      EVT_Message(PL.Txt(PL.MC_TX.NO_CANDIDATES))
      return
    end
    local pick = PL.MxList(cands, 0, {row = PL.MxRowChara,
      guide = PL.Txt(PL.MC_TX.PICK_GUIDE)})
    if pick < 0 then
      return
    end
    e = cands[pick + 1]
    pname = PL.MxCharaName(e.chara)
    if not PL.MxAsk(PL.Txt(PL.MC_TX.ASK_CREATE, pname)) then
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
    EVT_Message(PL.MC_ERR[st] ~= nil and PL.Txt(PL.MC_ERR[st]) or PL.Txt(PL.MC_TX.ERROR_CODE, st))
    return
  end
  if PL.McEquip(idx, cur) then
    funcLuaCommand(C.SE, SE_DECIDE)
    EVT_Message(PL.Txt(PL.MC_TX.ASSIGNED, pname))
  else
    funcLuaCommand(C.SE, SE_NG)
    EVT_Message(PL.Txt(PL.MC_TX.SAVED_NOT_SET))
  end
end

-- the picker's result: «Crear nuevo cambio» runs the flow, a change entry equips it (store + carrier)
PL.McPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  if row == 0 and skill == PL.MC_CREATE then
    funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
    PL.McCreate(cur)
    return
  end
  local k = row == 0 and PL.McIndex(skill) or nil
  if k ~= nil then
    pcall(funcLuaCommand, PL.MC_CMD.EQUIP, n, k)
    funcLuaCommand(PL.ADD_ITEM, skill, 1, false)    -- this slot's own copy
  end
  return PL.McPrevEquip(row, skill, inv_hint, cur)
end

PL.McPrevPick = EVT_PickCoroutine
function EVT_PickCoroutine(row)
  if row == 0 then
    pcall(PL.McPrepare)
  end
  return PL.McPrevPick(row)
end

-- Eliminar on the Hiper row holding a change: emptied (native path), then «¿Borrar también el cambio?»
PL.McPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  local k = (row == 0) and PL.McIndex(EVT_U32(EVT_Skill(0))) or nil
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
    if PL.MxAsk(PL.Txt(PL.MC_TX.ASK_DELETE, pname)) then
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
  if a1 ~= 0 then
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
      local base = (okn and nameId) and (funcLuaCommand(720417636, nameId) or PL.Txt(PL.MC_TX.NAME)) or PL.Txt(PL.MC_TX.NAME)
      local text = base .. ": " .. PL.MxCharaName(c.chara)
      if EVT_SPECIAL_LABEL ~= "" then
        text = EVT_SPECIAL_LABEL .. "   " .. text
      end
      funcLuaMenuCommand(C.TEXT, L_ROW, info.itemTextName, text, 0)
    end
  end
end

-- ===== Modo cambio END =====
