-- ===== Character Reforged projection (2026-10-14) =====
-- Writing a move row whose list position holds a hidden aura (PL.ProjPos): the aura goes to its own slot first when
-- that is free (keshin / totem -> the aura half: board slot 8 + the team aura row; Mix-Max / «Modo cambio» -> the mix
-- half: Character Reforged's store), else it is an overflow aura: the write replaces it (its item goes back to stock,
-- as any retail equip) and loader.log says so. A move already elsewhere in the list swaps (the aura moves, kept).
function PL.FreeListPos(row, skill)
  local pos = EVT_ListPos(row)
  local cur = EVT_ListSkill(pos)
  if cur == 0 or not EVT_IsSpecial(cur) or cur == skill then
    return
  end
  local p = funcLuaCommand(C.SKILL_POS, n, skill)
  if p ~= nil and p >= 0 and p < EVT_NORMAL_NUM then
    return                                       -- CMND_SET_SKILL swaps: the aura moves to the move's old position
  end
  local okk, kind = pcall(funcLuaCommand, PL.HS_CMD.SLOT_OF, cur)
  kind = okk and kind or -1
  local what = "overflow: replaced (item back to stock)"
  if (kind == 0 or kind == 2) and EVT_Skill(0) == 0 then
    local h, added = EVT_HiperHandle(cur)
    local ok = false
    if h ~= nil and h ~= 0 then
      ok = EVT_BoardPut(EVT_HIPER_SLOT, cur, h)
    end
    if added then
      funcLuaCommand(C.DEL_ITEM, cur, 1)
    end
    if ok and EVT_SPECIAL_TEAM_AURA then
      EVT_TeamAuraPut(cur)
    end
    what = ok and "moved to the aura slot" or "aura slot write FAILED: replaced"
  elseif kind == 1 then
    local okg, have = pcall(funcLuaCommand, PL.HS_CMD.MIX_GET, n)
    if okg and (tonumber(have) or 0) == 0 then
      local oks, done = pcall(funcLuaCommand, PL.HS_CMD.MIX_SET, n, cur)
      what = (oks and done == true) and "moved to the mix slot" or "mix slot write FAILED: replaced"
    end
  end
  EVT_Log("projection", "row", row, "list position", pos + 1, "hidden", EVT_Name(cur), what, "for", EVT_Name(skill))
  return cur
end

-- the player still has `aura` (2026-10-19, owner: a hidden aura replaced by a move must never be lost): on his board
-- (slots 0-8), in the list, in the mix store or owned in stock; none = one copy back into stock, logged
function PL.KeepAura(aura, why)
  if aura == nil or aura == 0 then
    return
  end
  for b = 0, 8 do
    if EVT_BoardSkill(b) == aura then
      return
    end
  end
  if EVT_Active(aura) or PL.HsMix() == EVT_U32(aura) then
    return
  end
  local num = funcLuaCommand(PL.ITEM_NUM, aura)
  if type(num) == "number" and num > 0 then
    EVT_Log("projection", "hidden aura", EVT_Name(aura), "kept in stock", num, why)
    return
  end
  local h = funcLuaCommand(PL.ADD_ITEM, aura, 1, false)
  EVT_Log("projection", "hidden aura", EVT_Name(aura), "had no copy left: one copy back into stock", tostring(h), why)
end
-- Character Reforged 1.7.10: the aura / mix halves show THE projection (CharacterReforged.ProjectSkillSet, the same rule
-- the match uses; owner 2026-10-14: no save edits, read only). Aura half = the row's own aura (board slot 8, else the
-- team aura row) when it is a keshin / totem / armour, else the first keshin / totem / armour of the technique list (list
-- order); mix half = the stored mix, else the first Mix-Max / «Modo cambio» of the list, else of the board (a Mix-Max
-- on board slot 8 shows here, not in the aura half). Without Character Reforged's scripts: the row's own data.
PL.CR_PROJECT = @crc:CMND_CHARACTERREFORGED_PROJECT_SKILL_SET@                  -- crc32("CMND_CHARACTERREFORGED_PROJECT_SKILL_SET")
function PL.CrProjection()
  if n == nil or n == 0 or EVT_IsPrime() then
    return nil
  end
  local ok, aura, mix, aura_from, mix_from = pcall(funcLuaCommand, PL.CR_PROJECT, n)
  if not ok or type(aura) ~= "number" then
    return nil
  end
  return {aura = EVT_U32(aura), mix = EVT_U32(mix or 0), aura_from = tonumber(aura_from) or -1, mix_from = tonumber(mix_from) or -1}
end
function PL.CrShownSlots()
  local own, mix = PL.RowMove(0), PL.HsMix()
  local okp, proj = pcall(PL.CrProjection)
  if not okp or proj == nil then
    return own, mix
  end
  local aura = own
  local kind = own ~= 0 and PL.HsKind(own) or nil
  if own == 0 or kind == 1 then
    aura = proj.aura                           -- a list aura (or none); a mix move on the row shows in the mix half
  end
  if mix == 0 then
    mix = proj.mix
  end
  return aura, mix
end

PL.ProjPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  local displaced = nil
  if row ~= nil and row > 0 and skill ~= nil and skill ~= 0 and n ~= nil and n ~= 0 and not EVT_IsPrime() then
    local ok, aura = pcall(PL.FreeListPos, row, skill)
    if not ok then
      EVT_Log("projection", "free list position failed", tostring(aura))
    else
      displaced = aura
    end
  end
  local r = PL.ProjPrevEquip(row, skill, inv_hint, cur)   -- not inside a pcall: it may yield (messages)
  if displaced ~= nil then
    local ok, err = pcall(PL.KeepAura, displaced, string.format("row %d %s", row, EVT_Name(skill)))
    if not ok then
      EVT_Log("projection", "hidden aura check failed", tostring(err))
    end
  end
  return r
end
-- ===== Character Reforged projection END =====
