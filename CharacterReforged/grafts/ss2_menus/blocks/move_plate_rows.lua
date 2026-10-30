-- ===== Move plate rows + own list layers BEGIN =====
-- 2026-10-13 (owner): the 6 move rows of the list (1-6) in the MOVE PLATE format of the detail panel: the element
-- plate (retail cmd_base_sp0N of soccer11_09: fire red, wood green, wind blue, mountain orange), the category icon in
-- the circle at the LEFT, the name white with outline (graded font of the move's own evolution, PL.SkillItem), the AT /
-- DF label + value at the RIGHT. Empty slot: the retail neutral grey plate (cmd_base_sp06) with «---». A level-locked
-- row: the grey plate with the move it will learn (dimmed) and the retail move-row lock (_pos_lock01) carrying the
-- unlock level; a fixed row (Prime / Idol learnset): the move's plate with the lock instead of the AT. Drawn on layer
-- evt_ss_row_plate (7 instances; object evt_ss_row_plate = evt_ph_move_row's recipe on a layout copy with the plate
-- 9 px right, centred in the row's frame): instance r rides on list row r (object evt_ss_equip_row:
-- NullLayerIndexName on _pos_base01), so the row's cyan focus frame, touch quad and animations stay the row's own.
-- Instance 0 (the split Hiper row) stays hidden. A plate is shown only while its row is (PL.RowPlateSync, every Step).
PL.RP = {
  ON = true,
  L = 2650954806 --[[evt_ss_row_plate]],
  PRIO = 553,                                      -- the list row is 552 (soccer11_08 m_drawPriority)
  ROW_BASE = 970690259 --[[_item_list_base01]],    -- the row's white / navy base, hidden under the plate
  -- the plate's own parts / sprites / states: VRFW_UI.MovePlate (66_ui_plates.lua)
  IS_OPEN = @crc:CMND_IS_OPEN_LAYER@, IS_VISIBLE = @crc:CMND_IS_LAYER_VISIBLE@,
  want = {},
}

function PL.RowPlate(r, skill, locked, need, fixed, inactive)
  local P = PL.RP
  local L = P.L
  P.want[r] = false
  if not P.ON or r < 1 or r >= EVT_ROW_NUM or SetupCharaSkillItem == nil or type(VRFW_UI) ~= "table"
      or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) then
    return false
  end
  skill = skill or 0
  -- the shared move plate's list row (VRFW_UI.MovePlate.Row): the neutral plate first, the retail fill on L with the
  -- move's own grade (no blank / AI-mark layers), back to this screen's own setting; empty «---», level-locked (grey,
  -- dimmed name, the lock with the level), fixed (the lock instead of the AT), inactive (on the board, not in the
  -- match list: the name greyed with the lock rows' colour; the plate's `suffix` slot writes it, nothing appended)
  local ok, err = VRFW_UI.MovePlate.Row(L, r, n, skill, {page = L_ROW, open = PL.Open, restore = {nil, L_DETAIL, 0, nil, nil},
    locked = locked, need = need, fixed = fixed, lock_color = PL.LOCK_COLOR,
    name = skill ~= 0 and (inactive and (PL.LOCK_COLOR .. EVT_Name(skill) .. "[C]") or EVT_Name(skill)) or nil,
    suffix = inactive and "" or nil, empty_text = "", log = true})   -- inactive: the name greyed (no text appended); log: «move plate fill»
  if not ok then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "row plate failed", r, string.format("%08X", EVT_U32(skill)), tostring(err))
    return false
  end
  P.want[r] = true
  pcall(PL.RowPlateSync)
  return true
end

-- a plate shows while it is wanted and its list row is visible (the lists covering the column hide the rows)
function PL.RowPlateSync(step)
  local P = PL.RP
  if type(VRFW_UI) == "table" then
    VRFW_UI.MovePlate.Pump(step)                   -- the plates filled before their instance was ready, again
  end
  if not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, P.L) then
    return
  end
  for r = 0, EVT_ROW_NUM - 1 do
    if funcLuaMenuCommand(P.IS_OPEN, P.L, r) then
      local v = P.want[r] == true and funcLuaMenuCommand(P.IS_VISIBLE, L_ROW, r) == true
      if (funcLuaMenuCommand(P.IS_VISIBLE, P.L, r) == true) ~= v then
        funcLuaMenuCommand(C.LAYER_VISIBLE, P.L, r, v)
      end
    end
  end
end

-- 2026-10-13 (owner: the combo partner rows smaller, less gap): the partner picker's OWN list frame and rows (layers
-- evt_cpk_list / evt_cpk_row: 8 rows 84 high, step 76), passed to PL.PopList as mode.list_layer / row_layer (graft
-- combo_partners); the shared evt_ss_list / team08_02 rows of the passive / role / set selectors are untouched.
PL.L_CPK_LIST = 2148145526 --[[evt_cpk_list]]
PL.L_CPK_ROW = 664477730 --[[evt_cpk_row]]
PL.CPK_ROWS = 9
PL.PTR_CPK = {-98, 970, 60}                        -- the row's visible plate (75 high sprite, ~56 opaque; step 68)
-- 2026-10-13 (owner): scroll arrows of that list. Layer evt_cpk_arrow = the retail item list frame (item01_01) cut to its
-- two arrows (_arrow_list_u01 / _d01, 56 x 32) moved to the right margin of the rows; PL.ListArrows shows the up one
-- when rows lie above the visible window and the down one when rows lie below (the retail lists' scroll indicators).
PL.L_CPK_ARROW = 1928945792 --[[evt_cpk_arrow]]
PL.CPK_ARROW_UP = 1288675512 --[[_pos_arrow_u01]]
PL.CPK_ARROW_DOWN = 1361799679 --[[_pos_arrow_d01]]

function PL.ListArrows(show, first, nr, total, list_layer)
  local L = PL.L_CPK_ARROW
  if list_layer ~= PL.L_CPK_LIST or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) then
    return
  end
  local up = show and first > 0
  local down = show and first + nr < total
  if up or down then
    PL.Open(L)
    funcLuaMenuCommand(EVT_POS_VISIBLE, L, PL.CPK_ARROW_UP, up, 0)
    funcLuaMenuCommand(EVT_POS_VISIBLE, L, PL.CPK_ARROW_DOWN, down, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, up or down)
end

PL.RpPrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == PL.RP.L then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, PL.RP.PRIO, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_CPK_LIST then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 450, true)
    for _, pos in ipairs({1839509013 --[[_pos_scr_base01]], 1060758565 --[[_pos_scr_obj01]]}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3660005257 --[[_text_list_empty01]], false, a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_CPK_ROW then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 451, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == PL.L_CPK_ARROW then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 452, true)
    for _, pos in ipairs({1839509013 --[[_pos_scr_base01]], 1060758565 --[[_pos_scr_obj01]]}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 970690259 --[[_item_list_base01]], false, a2)
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3037571460 --[[_text_list01]], false, a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  return PL.RpPrevSetupLayer(a1, a2)
end

PL.RpPrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == PL.RP.L then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)   -- PL.RowPlateSync shows it (next Step)
    return
  elseif a1 == PL.L_CPK_LIST or a1 == PL.L_CPK_ROW or a1 == PL.L_CPK_ARROW then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  return PL.RpPrevOpenLayer(a1, a2)
end

PL.RpPrevStep = Step
function Step(...)
  local r = PL.RpPrevStep ~= nil and PL.RpPrevStep(...) or nil
  pcall(PL.RowPlateSync, true)
  if VRFW_FaceIcon ~= nil and VRFW_FaceIcon.Pending() then
    VRFW_FaceIcon.Settle()                         -- minifaces of the partner list and the miximax panel shown once loaded
  end
  return r
end
-- ===== Move plate rows + own list layers END =====
