
-- ===== EVT board removal BEGIN (research/scripts/board_entry_build.py) =====
-- RPG-battle team dock (story field): "Tabla de habilidades" opens the Supertécnicas screen (evt_skill_slot_menu,
-- a clone of equip_menu_select) with the parameters retail ExecEquipMenu gives equip_menu (dock type 2 = the field
-- party, L/R through the party); the return path is ExecEquipMenu's.
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
    and CharacterReforged.EntryOpensSkillTable("story dock (team_dock_menu_rpg_battle)")
end
function EVT_OpenSkillSlotsFromRpgDock()
  local ret = funcLuaMenuCommand(2603265800, n23)
  local h = GetMaiMemberStCharaHdl(ret)
  if h == 0 then
    return -1
  end
  n2 = 1
  local function p(key, v, num)
    funcLuaCommand(3363400568, key)
    if num then
      funcLuaCommand(3860611758, key, 0, v, 1)
    else
      funcLuaCommand(3860611758, key, 0, v)
    end
  end
  p(2029825652, true)        -- flag5: member list (L/R)
  p(363718978, true)         -- flag6: field / main-menu mode
  p(4145209998, 0, true)     -- card type
  p(3308763177, true)
  p(2719720834, true)
  p(4081600465, 2, true)     -- dock type 2 = RPG field party
  p(1038144478, h, true)     -- the character
  p(622145442, ret, true)    -- selected index
  funcLuaCommand(3363400568, 239878988)   -- never read-only here
  funcLuaMenuCommand(972795058, false)
  funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], EVT_SKILL_SLOT_MENU)
  funcLuaMenuCommand(1129326309, 1730641026 --[[team_dock_menu]])
  funcLuaMenuCommand(1558704558, 1730641026 --[[team_dock_menu]], false)
  funcLuaCommand(830228314, 2645952753 --[[main_menu]], "ChangeHeaderMode", 12)
  coroutine.yield()
  waitFalse(function()
    return funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], EVT_SKILL_SLOT_MENU)
  end)
  funcLuaMenuCommand(1453710531, 1730641026 --[[team_dock_menu]])
  ReturnCharacterInstant()
  ClosePersonalPlate()
  coroutine.yield()
  SetVisibleNotRequiredLayers(true)
  funcLuaMenuCommand(1558704558, 1730641026 --[[team_dock_menu]], true)
  funcLuaMenuCommand(1558704558, 2645952753 --[[main_menu]], true)
  funcLuaCommand(830228314, 2645952753 --[[main_menu]], "ChangeHeaderMode", 0)
  if funcLuaCommand(2947612279, 622145442) then
    n = funcLuaCommand(3522198769, 622145442)
    funcLuaCommand(3363400568, 622145442)
  end
end
local EVT_RetailExecAbilityBoardMenu = ExecAbilityBoardMenu
function ExecAbilityBoardMenu(a1, a2)
  if not EVT_BOARD_TO_SKILLS or not EVT_EntryOpensSkillTable() then
    return EVT_RetailExecAbilityBoardMenu(a1, a2)
  end
  return EVT_OpenSkillSlotsFromRpgDock()
end
-- ===== EVT board removal END =====
