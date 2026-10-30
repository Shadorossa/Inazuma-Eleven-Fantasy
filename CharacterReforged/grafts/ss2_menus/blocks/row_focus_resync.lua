-- ===================================================================================================
-- Row focus resync (2026-10-13, owner: entering any player's page the cursor is on the Hiper row but the detail panel
-- stays empty and Left / Right cannot reach the mix slot until Down + Up; after the miximax scene the same with the
-- cursor on the mix slot). n14 (the screen's «focused layer») had been set to the bottom button by a button layer's
-- OnChangeFocus (the «Pasiva personalizada» / role buttons' wrappers take every focus event, unlike the retail one
-- that drops events of a layer without the control focus) while the control focus was on the row list: the panel then
-- drew nothing (UpdateEquipItemInfo's button path) and PL.HsPollR3 ignored Left / Right. Now (1) a button's focus event
-- is dropped while the row list holds the control focus and that button does not (CMND_IS_CTRL_FOCUS_ACTIVE, the retail
-- filter), and (2) for PL.FS_WINDOW frames after the screen opens and after EVT_FocusRow, a Step with the row list in
-- control and n14 elsewhere sets n14 back to the list and redraws the panel (UpdateEquipItemInfo).
-- ===================================================================================================
PL.FS_WINDOW = 120
PL.fs_wait = 0
PL.FS_CTRL = @crc:CMND_IS_CTRL_FOCUS_ACTIVE@                  -- (layer)

function PL.CtrlFocus(L)
  if L == nil then
    return false
  end
  local ok, on = pcall(funcLuaMenuCommand, PL.FS_CTRL, L)
  return ok and on == true
end

-- the row list has the control focus and none of the bottom buttons does
function PL.RowHasFocus()
  if not PL.CtrlFocus(L_ROW) then
    return false
  end
  for _, b in ipairs({L_BTN, L_BTN_SS, PL.L_BTN_ROLE}) do
    if PL.CtrlFocus(b) then
      return false
    end
  end
  return true
end

function PL.FocusResync(why)
  n14 = L_ROW
  local ok, err = pcall(UpdateEquipItemInfo)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "focus resync", why, "row", funcLuaMenuCommand(C.FOCUS_IDX, L_ROW),
    ok and "" or tostring(err))
end

PL.FsPrevChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  if (a1 == L_BTN or a1 == L_BTN_SS or a1 == PL.L_BTN_ROLE) and not PL.CtrlFocus(a1) and PL.RowHasFocus() then
    if n14 ~= L_ROW then
      PL.FocusResync("button focus event dropped")
    end
    return
  end
  return PL.FsPrevChangeFocus(a1, a2)
end

PL.FsPrevInit = OnInit
function OnInit(...)
  PL.fs_wait = PL.FS_WINDOW
  return PL.FsPrevInit(...)
end

PL.FsPrevStep = Step
function Step(...)
  local r = PL.FsPrevStep ~= nil and PL.FsPrevStep(...) or nil
  if PL.fs_wait > 0 then
    PL.fs_wait = PL.fs_wait - 1
    if not PL.mx_scene_busy and evt_co == nil and n14 ~= L_ROW and PL.RowHasFocus() then
      PL.FocusResync("step")
    end
  end
  return r
end
-- ===== Row focus resync END =====
