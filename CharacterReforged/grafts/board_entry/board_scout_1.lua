
-- ===== EVT board removal BEGIN (research/scripts/board_entry_build.py) =====
-- Scout screen (personal-plate view key): opens the Supertécnicas screen for that scout. The scout may not be an owned
-- player, so the screen opens READ-ONLY (param evt_ss_readonly): it shows his moves and the move panel, nothing can
-- be changed.
EVT_BOARD_TO_SKILLS = true
EVT_SKILL_SLOT_MENU = 1041963128
-- 2026-10-14: the skill table is the mod Character Reforged's (this graft too since cr_entry), shown only while its
-- option «Tabla de habilidades» is on «Fantasy» (row character_reforged.skill_set_view, read at call time); off = the
-- game's own board. EVT_BoardSkillSetOn: the view, no log line (greying); the entry itself asks
-- CharacterReforged.EntryOpensSkillTable (one log line per use).
function EVT_BoardSkillSetOn()
  return CharacterReforged ~= nil and CharacterReforged.SkillTableViewOn ~= nil and CharacterReforged.SkillTableViewOn()
end
local function EVT_EntryOpensSkillTable()
  return CharacterReforged ~= nil and CharacterReforged.EntryOpensSkillTable ~= nil
    and CharacterReforged.EntryOpensSkillTable("scout screen (rpg_select_scout_chara_menu)")
end
local EVT_RetailOpenAbilityLearningBoard = OpenAbilityLearningBoard
function OpenAbilityLearningBoard()
  if not EVT_BOARD_TO_SKILLS or not EVT_EntryOpensSkillTable() then
    return EVT_RetailOpenAbilityLearningBoard()
  end
  local function p(key, v, num)
    funcLuaCommand(3363400568, key)
    if num then
      funcLuaCommand(3860611758, key, 0, v, 1)
    else
      funcLuaCommand(3860611758, key, 0, v)
    end
  end
  p(2029825652, false)       -- flag5: no member list (single player)
  p(363718978, true)         -- flag6: field mode
  p(4145209998, 0, true)
  p(3308763177, false)
  p(2719720834, true)
  p(1038144478, n5, true)    -- the scout
  p(239878988, true)                -- read-only
  funcLuaMenuCommand(2209673388, 1026683731 --[[rpg_select_scout_chara_menu]], 1138543975 --[[mainmenu01_06_base_button_guide]], {}, {}, {})
  funcLuaMenuCommand(452337289, 1026683731 --[[rpg_select_scout_chara_menu]], 1138543975 --[[mainmenu01_06_base_button_guide]], {})
  SetVisibleLayerAll(false)
  funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], EVT_SKILL_SLOT_MENU)
  funcLuaMenuCommand(1558704558, 1026683731 --[[rpg_select_scout_chara_menu]], false)
  coroutine.yield()
  waitFalse(function()
    return funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], EVT_SKILL_SLOT_MENU)
  end)
  funcLuaCommand(3363400568, 239878988)
  SetVisibleLayerAll(true)
  funcLuaMenuCommand(1558704558, 1026683731 --[[rpg_select_scout_chara_menu]], true)
  UpdateAppealEventCheck()
  ChangeViewMode(2, true)
end
-- ===== EVT board removal END =====
