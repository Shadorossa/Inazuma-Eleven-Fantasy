-- ===== Board-only move guide (2026-10-14) =====
-- A move row greyed by the projection holds a move that sits on the board slot but not in the match list (its list
-- position is empty): the match does not use it. While such a row has the focus, the bottom guide line says so (text
-- evt_ss_board_only); leaving it puts the screen's own guide back. Nothing is written to the save.
PL.TX_BOARD_ONLY = 1501903055                 -- crc32("evt_ss_board_only")
PL.board_guide = false
PL.BgPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo(...)
  local r = PL.BgPrevItemInfo(...)
  local ok, err = pcall(PL.BoardOnlyGuide)
  if not ok then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "board-only guide failed", tostring(err))
  end
  return r
end

function PL.BoardOnlyGuide()
  local board_only = false
  if n14 ~= L_BTN and n ~= nil and n ~= 0 and not EVT_IsPrime() then
    local row = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    if type(row) == "number" and row >= 1 and row < EVT_ROW_NUM and not EVT_IsLocked(row) then
      local skill = PL.RowMove(row)
      board_only = skill ~= 0 and not EVT_Active(skill)
    end
  end
  if board_only then
    local t = PL.Txt(PL.TX_BOARD_ONLY)
    if t ~= "" then
      PL.Guide(t)
      PL.board_guide = true
    end
  elseif PL.board_guide then
    PL.board_guide = false
    if not PL.IdolFixed(funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)) then
      PL.Guide(PL.Txt(EVT_GUIDE_TEXT))
    end
  end
end
-- ===== Board-only move guide END =====
