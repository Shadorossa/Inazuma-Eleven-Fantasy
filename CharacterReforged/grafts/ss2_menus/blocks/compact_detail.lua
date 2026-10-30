-- ===== compact detail layout (2026-10-07) =====
-- PL.ApplyDetailLayout again for PL.LAYOUT_FRAMES frames after each state change: a layer opened after the focus
-- change (L_DETAIL_LV, the aura windows, evt_ss_aura2 of a miximax) or an open animation that reset a node gets the
-- compact positions too; then it stops (nothing runs per frame while the screen closes)
PL.LayoutPrevStep = Step
function Step(...)
  local r = PL.LayoutPrevStep ~= nil and PL.LayoutPrevStep(...) or nil
  pcall(PL.MxPollR3)
  if PL.layout_mode ~= nil and (PL.layout_frames or 0) > 0 then
    PL.layout_frames = PL.layout_frames - 1
    pcall(PL.ApplyDetailLayout)
  end
  return r
end
-- ===== compact detail layout END =====
