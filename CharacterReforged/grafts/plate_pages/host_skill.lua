-- host table of the shared player page (research/grafts/plate_pages): a screen with its own copy of the plate
-- (equip_menu, evt_skill_slot_menu): the header row (slanted position band, archetype box), the white card and the
-- bar chart from the same code; no pages (fixed type 9 = the chart), no description, no model of ours
EVT_PPG_HOST = {name = "skill", plate = 607716004, status = 2917320188, graph = 32151736, radar = 2334590304, pages = false, fixed = 9,
  menu = 1041963128 --[[evt_skill_slot_menu: its close state shuts our added layers]],
  -- 2026-10-06 (Nacho, shot 365): no chart here; the card (band copy body, screen x0, y0, x1, y1) the Plantilla
  -- page's (x 985..1920, bottom 955) grown up to y 625 so the selected technique's plate (team02_02, y ~645..699,
  -- name / AT / TENSIÓN) and «IA activada» (y ~933..960) sit inside it
  -- 2026-10-07: the default only (passive windows, accessory card); the skill table's own Lua (ss2_menus
  -- PL.SetDetailLayout) swaps in a compact rect per focused row (technique / aura / miximax / empty)
  -- 2026-10-07 (Nacho: a translucent white square under the name banner, bottom left): the header plate's empty
  -- portrait base and its mark (soccer11_04 nodes 0xD45A789C / 0xE8053058) moved off screen like its portrait icon
  plate_off = {3562698908, 3892654168},
  chart = false, card = {985, 625, 1920, 955},
  -- 2026-10-14 (owner: the skill table's right page = the player page's): the screen has no PostStep, so the page's
  -- per-frame body (the card, the header row's slant / tag, the retail page body / description / radar off) runs
  -- after its Step
  frame_hook = "Step",
  -- 2026-10-14: the retail radar stays the set preview's / training view's while they show it (ss2_menus
  -- EVT_SkillTableRadarWanted); the rest of the time the page hides it, as it does on the player page
  keep_radar = function()
    return type(EVT_SkillTableRadarWanted) == "function" and EVT_SkillTableRadarWanted() == true
  end}
-- 2026-10-06 (exit hang on these hosts): the block off here until the close is fixed (its menu patches are off too)
-- round 14e: on again (host page object without the player page's attach rows; our layers closed on back)
-- 2026-10-06: OFF on the skill table (its close still hangs; finding out whether without us it still does)
if EVT_PPG_HOST_OFF == nil then
  EVT_PPG_HOST_OFF = false
end
