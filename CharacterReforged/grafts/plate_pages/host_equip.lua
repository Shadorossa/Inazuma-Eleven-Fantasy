-- host table of the shared player page (research/grafts/plate_pages): a screen with its own copy of the plate
-- (equip_menu, evt_skill_slot_menu): the header row (slanted position band, archetype box), the white card and the
-- bar chart from the same code; no pages (fixed type 9 = the chart), no description, no model of ours
EVT_PPG_HOST = {name = "equip", plate = 607716004, status = 2917320188, graph = 32151736, radar = 2334590304, pages = false, fixed = 9,
  menu = 606230082 --[[equip_menu: its close state shuts our added layers]]}
-- 2026-10-06 (Nacho, shot 366): only the chart on the Plantilla page's card (no card = the layout's x 985..1920,
-- y 705..955); the big retail page body is hidden by plate_pages.lua (host branch)
-- 2026-10-06 (exit hang on these hosts): the block off here until the close is fixed (its menu patches are off too)
-- round 14e: on again (host page object without the player page's attach rows; our layers closed on back)
-- 2026-10-06: OFF (the close hangs with the block on; being bisected)
if EVT_PPG_HOST_OFF == nil then
  EVT_PPG_HOST_OFF = false
end
