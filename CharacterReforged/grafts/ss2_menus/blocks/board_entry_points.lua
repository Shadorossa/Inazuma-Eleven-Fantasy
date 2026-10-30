-- ===================================================================================================
-- ===================================================================================================
-- 2026-09-24: every former board entry point opens THIS screen (docs/game/skill-board-original.md §8.5): team dock
-- (type 5), RPG-battle team dock (story field), scout screen. The scout screen shows candidates that may not be
-- owned players, so its opener sets param evt_ss_readonly: the screen then only shows (moves, move panel, plate) and
-- refuses every change (buzzer + guide line); no board / list / role / six-sense / preset write happens.
-- ===================================================================================================
PL.KEY_READONLY = 239878988
PL.readonly = false
PL.RO_GUIDE = 651715743 --[[skill_table_readonly_guide]]

PL.PrevInit = OnInit
function OnInit()
  if funcLuaCommand(C.P_HAS, PL.KEY_READONLY) then
    local v = funcLuaCommand(C.P_GET, PL.KEY_READONLY)
    PL.readonly = v == true or v == 1
    funcLuaCommand(C.P_CLEAR, PL.KEY_READONLY)
  end
  PL.PrevInit()
end

function PL.Refuse()
  funcLuaCommand(C.SE, SE_NG)
  funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.Txt(PL.RO_GUIDE), 0)
end

PL.RoPrevDecide = OnDecideFocus
function OnDecideFocus(a1, a2)
  if PL.readonly then
    PL.Refuse()
    return
  end
  PL.RoPrevDecide(a1, a2)
end

PL.RoPrevFunction = OnFunction
function OnFunction(a1, a2)
  if PL.readonly and (a1 == 4109882573 --[[CMD_FUNC3 Eliminar]] or a1 == 1141890006 --[[CMD_FUNC4 Restablecer]]) then
    PL.Refuse()
    return
  end
  PL.RoPrevFunction(a1, a2)
end

PL.RoPrevItemInfo = UpdateEquipItemInfo
function UpdateEquipItemInfo()
  PL.RoPrevItemInfo()
  if PL.readonly then
    funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {}, {}, {})
    funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {})
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.Txt(PL.RO_GUIDE), 0)
  end
end
