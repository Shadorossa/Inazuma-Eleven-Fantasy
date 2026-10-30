-- ===== Hiper row: Restablecer / Eliminar act on the focused half (2026-10-16) =====
-- Owner: «Restablecer debe ser a como lo tiene el personaje en su set básico, y Eliminar es para dejar el espacio
-- vacío». On the Hiper row the half under the cursor (PL.hs_half: 0 aura, 1 mix) is the target of both: the mix half's
-- Restablecer puts back the mix of the player's basic set (CMND_CHARACTERREFORGED_DEFAULT_SET; none = the slot ends
-- empty), Eliminar empties that half only. Nothing to change: the error sound.
PL.HALF_CMD_DEFAULT = @crc:CMND_CHARACTERREFORGED_DEFAULT_SET@                  -- crc32("CMND_CHARACTERREFORGED_DEFAULT_SET") (card) -> aura, mix

function PL.HalfDefaultMix()
  if n == nil or n == 0 then
    return 0
  end
  local ok, _, mix = pcall(funcLuaCommand, PL.HALF_CMD_DEFAULT, n)
  return (ok and type(mix) == "number") and EVT_U32(mix) or 0
end

PL.HalfPrevRestore = EVT_RestoreCoroutine
function EVT_RestoreCoroutine(row)
  if row ~= 0 or PL.mx_removing then
    return PL.HalfPrevRestore(row)
  end
  if PL.hs_half == 1 then
    if PL.HsMix() == 0 then
      funcLuaCommand(C.SE, SE_NG)                  -- the mix half is already empty
      return
    end
    return PL.HalfPrevRestore(0)                   -- the mix slot's removal (fusion / change questions)
  end
  if EVT_Skill(0) == 0 then
    local okp, proj = pcall(PL.CrProjection)
    if not (okp and proj ~= nil and #PL.FbSources("aura") > 0) then
      funcLuaCommand(C.SE, SE_NG)                  -- the aura half shows nothing: the mix slot is never touched here
      return
    end
  end
  return PL.HalfPrevRestore(0)
end

PL.HalfPrevReset = PL.FallbackResetCoroutine
function EVT_ResetCoroutine(row)
  if row ~= 0 or PL.hs_half ~= 1 then
    return PL.HalfPrevReset(row)
  end
  if EVT_IsPrime() or PL.readonly then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local cur, want = PL.HsMix(), PL.HalfDefaultMix()
  if cur == want then
    funcLuaCommand(C.SE, SE_NG)                    -- already the basic set's mix
    return
  end
  if cur ~= 0 then
    EVT_RestoreCoroutine(0)                        -- the current mix off first (its own questions)
    if PL.HsMix() ~= 0 then
      return                                       -- the player kept it
    end
  end
  if want ~= 0 then
    if PL.HsMixPut(want) then
      funcLuaCommand(C.SE, SE_DECIDE)
    else
      funcLuaCommand(C.SE, SE_NG)
    end
  end
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "reset mix", string.format("%08X", EVT_U32(cur)),
    string.format("%08X", EVT_U32(want)), string.format("%08X", PL.HsMix()))
  EVT_RefreshRows()
  UpdateEquipItemInfo()
  EVT_FocusRow(0)
end
-- ===== Hiper row: Restablecer / Eliminar END =====
