-- ===== Board close guard =====
-- Once Back starts this screen's close (skill_slots OnBack sets PL.board_closing), the detail panels are not redrawn:
-- a redraw during the close (Left / Right or the pointer on the Hiper row, a focus event of a closing layer, the focus
-- resync) opened the Hiper panel and its move row again, the menu waited for those layers to close and the previous
-- screen never came back. Cleared when the screen opens (OnInit).
PL.board_closing = false

PL.CgPrevInit = OnInit
function OnInit(...)
  PL.board_closing = false
  return PL.CgPrevInit(...)
end

PL.CgPrevChangeFocus = OnChangeFocus
function OnChangeFocus(...)
  if PL.board_closing then
    return
  end
  return PL.CgPrevChangeFocus(...)
end

PL.CgPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo(...)
  if PL.board_closing then
    return
  end
  return PL.CgPrevItemInfo(...)
end

PL.CgPrevOpen = PL.Open
function PL.Open(...)
  if PL.board_closing then
    return
  end
  return PL.CgPrevOpen(...)
end

PL.CgPrevHsPollR3 = PL.HsPollR3
function PL.HsPollR3(...)
  if PL.board_closing or PL.CgPrevHsPollR3 == nil then
    return
  end
  return PL.CgPrevHsPollR3(...)
end

PL.CgPrevFocusResync = PL.FocusResync
function PL.FocusResync(...)
  if PL.board_closing or PL.CgPrevFocusResync == nil then
    return
  end
  return PL.CgPrevFocusResync(...)
end
-- ===== Board close guard END =====
