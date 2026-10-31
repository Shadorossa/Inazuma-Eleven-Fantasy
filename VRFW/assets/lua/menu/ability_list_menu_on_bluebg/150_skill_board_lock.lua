-- menu_engine: the skill board's move / aura / mix / passive list (ability_list_menu_on_bluebg, opened by a piece of
-- the retail board) under the skill board lock (VRFW_SkillBoardLock, lua\_all\92_skill_board_lock.lua): while a lock
-- holds, Accept on a row is refused, the rows are greyed and the Accept guide entry shows the lock's text; browsing,
-- tabs, filter, sort and the detail card work as retail. No engine call at load time.
if type(VRFW_SkillBoardLock) == "table" and type(VRFW_SkillBoardLock.GuardList) == "function" then
  VRFW_SkillBoardLock.GuardList({
    list_layer = 3520823522,     -- team08_01_ability_list
    item_layer = 1205526439,     -- team08_02_ability_list_item
    enter_text = 3790324331,     -- the retail Accept guide text of this list
  })
end
