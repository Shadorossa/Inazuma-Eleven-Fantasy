-- ===== Fantasy slot fallbacks (2026-10-15) =====
-- With Character Reforged's projection (the option on Fantasy) the aura half shows board slot 8, else the first
-- keshin / totem / armour of the technique list; the mix half the stored mix, else the first Mix-Max / «Modo cambio» of
-- the list, else of the board. Owner 2026-10-15: those list / board entries are not a layer under the slot. An equip,
-- a reset or a removal on a half also takes that half's list / board entries off the board (board slot = list
-- position; the item goes back to stock, as a retail unequip), so the slot never falls back to them. Only the shown
-- player's own board; slot 8 (the aura slot itself) and the mix store are never touched here. Victory Road (no
-- projection answer): nothing changes. PL fields only (no main-chunk locals).
PL.FB_LIST_BOARD_SLOTS = 8                    -- board slots 0..7 (8 is the aura slot)
function PL.FbWanted(half, id)
  if id == nil or id == 0 then
    return false
  end
  local kind = PL.HsKind(id)
  if half == "mix" then
    return kind == 1
  end
  return kind == 0 or kind == 2
end

-- the board slots holding a fallback of `half`: the list positions with such a move, and (mix half) any board slot
function PL.FbSources(half)
  local out, seen = {}, {}
  for p = 0, EVT_NORMAL_NUM - 1 do
    local id = EVT_ListSkill(p)
    if PL.FbWanted(half, id) then
      out[#out + 1] = {slot = p, id = id}
      seen[p] = true
    end
  end
  if half == "mix" then
    for b = 0, PL.FB_LIST_BOARD_SLOTS - 1 do
      local id = EVT_BoardSkill(b)
      if not seen[b] and PL.FbWanted(half, id) then
        out[#out + 1] = {slot = b, id = id}
      end
    end
  end
  return out
end

-- clear one board slot (Character Reforged's board command; keepOpen mode 1: the placed item off; 3: the native item off
-- too) -> status
function PL.FbBoardClear(slot, mode)
  return EVT_Call(C.EVT_CLEAR, n, slot, mode)
end

-- the technique a list position takes when its aura leaves: its board cell's technique, else the learnset move of that
-- slot (learned by level); never an aura, never a move already in the list. None: the position is emptied.
function PL.FbRefill(pos)
  local function usable(m)
    if m == nil or m == 0 or PL.IsSpecialCached(m) then
      return false
    end
    local at = funcLuaCommand(C.SKILL_POS, n, m)
    return not (at ~= nil and at >= 0 and at < EVT_NORMAL_NUM)
  end
  local m = PL.BoardTechniqueAt(pos)
  if not usable(m) then
    local ls = PL.Learnset()
    m = ls.skill[pos + 1] or 0
    local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
    if (ls.lv[pos + 1] or 0) > lv then
      m = 0
    end
  end
  if usable(m) then
    funcLuaCommand(C.SET_SKILL, n, m, pos)
    if EVT_ListSkill(pos) == EVT_U32(m) then
      return m
    end
  end
  funcLuaCommand(C.REMOVE_SKILL, n, pos)
  return 0
end

-- take the fallbacks of `half` off the board -> how many slots were cleared. A keshin, totem or armour of the list
-- goes entirely (owner 2026-10-15: armours too): the placed item, then the native one, then its list position.
function PL.FbClear(half, why)
  if PL.readonly or n == nil or n == 0 or EVT_IsPrime() then
    return 0
  end
  local okp, proj = pcall(PL.CrProjection)
  if not okp or proj == nil then
    return 0
  end
  local cleared = 0
  for _, s in ipairs(PL.FbSources(half)) do
    local st = PL.FbBoardClear(s.slot, 1)
    if EVT_BoardSkill(s.slot) == s.id then
      st = PL.FbBoardClear(s.slot, 3)          -- a native move: taken off too
    end
    local left = EVT_BoardSkill(s.slot)
    local listed = EVT_ListSkill(s.slot) == s.id
    if listed then
      PL.FbRefill(s.slot)
      listed = EVT_ListSkill(s.slot) == s.id
    end
    local gone = left ~= s.id and not listed
    if gone then
      cleared = cleared + 1
    end
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "fantasy fallback", why, half, string.format("%08X", EVT_U32(n)),
      "board slot", s.slot, EVT_Name(s.id), "clear status", tostring(st),
      gone and "removed" or "still there")
  end
  return cleared
end

PL.FbPrevEquip = EVT_Equip
function EVT_Equip(row, skill, inv_hint, cur)
  local r = PL.FbPrevEquip(row, skill, inv_hint, cur)   -- not inside a pcall: it may yield (messages)
  if row == 0 and skill ~= nil and skill ~= 0 and r ~= false then
    local okk, kind = pcall(PL.HsKind, skill)
    local half = (okk and kind == 1) and "mix" or ((okk and (kind == 0 or kind == 2)) and "aura" or nil)
    local placed = half == "mix" and PL.HsMix() == EVT_U32(skill) or (half == "aura" and EVT_Skill(0) == EVT_U32(skill))
    if placed then
      local ok, cleared = pcall(PL.FbClear, half, "equip")
      if ok and cleared > 0 then
        pcall(EVT_AfterChange)
      end
    end
  end
  return r
end

PL.FbPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if row ~= 0 then
    return PL.FbPrevRestore(row)
  end
  local mix = PL.HsMix()
  local aura_half = PL.hs_half == 0 or mix == 0
  local okp, proj = pcall(PL.CrProjection)
  -- the aura half shows a list fallback and its own slot is empty: the removal is the fallback's
  if aura_half and okp and proj ~= nil and EVT_Skill(0) == 0 and #PL.FbSources("aura") > 0 then
    local ok, cleared = pcall(PL.FbClear, "aura", "remove")
    funcLuaCommand(C.SE, (ok and cleared > 0) and SE_REMOVE or SE_NG)
    pcall(EVT_AfterChange)
    EVT_FocusRow(0)
    return
  end
  local r = PL.FbPrevRestore(row)
  local ok, cleared = pcall(PL.FbClear, aura_half and "aura" or "mix", "reset / remove")
  if ok and cleared > 0 then
    pcall(EVT_AfterChange)
  end
  return r
end
-- the Hiper row can be emptied by Eliminar (hold) when a half shows something, its own slot or a fallback
function PL.RowRemovable(row)
  if row ~= 0 then
    return false
  end
  local okS, aura, mix = pcall(PL.CrShownSlots)
  return okS and ((aura or 0) ~= 0 or (mix or 0) ~= 0)
end

-- Restablecer (tap) on the aura half with its own slot empty: a shown list fallback goes as with Eliminar; nothing to
-- restore and nothing shown: the error sound, no board write
PL.FbPrevReset = PL.BaseResetCoroutine
function PL.FallbackResetCoroutine(row)
  if row ~= 0 or EVT_Skill(0) ~= 0 or (PL.hs_half == 1 and PL.HsMix() ~= 0) then
    return PL.FbPrevReset(row)
  end
  local okp, proj = pcall(PL.CrProjection)
  if okp and proj ~= nil and #PL.FbSources("aura") > 0 then
    return EVT_RestoreCoroutine(0)
  end
  local okk, kit = pcall(PL.ResetKit, 0)
  if okk and (kit or 0) == 0 then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  return PL.FbPrevReset(row)
end
-- ===== Fantasy slot fallbacks END =====
