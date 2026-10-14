-- Character Reforged: which screen every «Tabla de habilidades» entry opens (docs/refactor/aura-mods-split.md «Skill
-- table», «Entries»). The option row character_reforged.skill_set_view (options.toml: 0 = «Victory Road», the game's
-- own ability board; 1 = «Fantasy», the skill table evt_skill_slot_menu: 6 special moves + the aura slot + the mix
-- slot) is read each time an entry is used, never at Lua load, so a change in «Opciones de mods» needs no restart.
-- One function for every entry, in every menu VM (this file is in `_all`):
--   * the team dock's player popup «PERSONAJE» (graft ss2_dock, a hook file since 1.7.9): Character Reforged no
--     longer touches the popup (owner 2026-10-14); its retail «Tabla de habilidades» branch opens the board with
--     CMND_OPEN_MENU_OBJECT, and CharacterReforged.InstallBoardOpenRedirect (below) turns that open into the skill
--     table at the target (and the retail wait for the board into a wait for the skill table);
--   * the story field dock team_dock_menu_rpg_battle and the scout screen rpg_select_scout_chara_menu (graft
--     board_entry: their retail open functions ExecAbilityBoardMenu / OpenAbilityLearningBoard);
--   * Utilities' Banco COMANDOS popup (graft cr_bank_skill_table).
-- CharacterReforged.EntryOpensSkillTable(entry_name) logs ONE line per use («option ... = <value read> -> <screen>»)
-- and returns true for the skill table, false for the game's board. CharacterReforged.SkillTableViewOn() is the same
-- read without the log line (the entry's greying: not an entry). Definitions only, no engine call at load.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
CharacterReforged.SKILL_TABLE_OPTION = "character_reforged.skill_set_view"   -- options.toml row (toggle, default 0)
CharacterReforged.OPTION_GET_COMMAND = 4082322029                            -- crc32("CMND_VRFW_OPTION_GET")
CharacterReforged.LOG_COMMAND = 3661580131                                   -- crc32("CMND_EVT_LOG"): the loader log
CharacterReforged.SKILL_TABLE_MENU = 1041963128                              -- evt_skill_slot_menu
CharacterReforged.ABILITY_BOARD_MENU = 1810526795                            -- ability_learning_board_menu

-- (view on, value read): CMND_VRFW_OPTION_GET answers the value, or `false, value` while the row's enabled_if is not met
function CharacterReforged.ReadSkillTableOption()
  local ok, value, held_value = pcall(funcLuaCommand, CharacterReforged.OPTION_GET_COMMAND,
    CharacterReforged.SKILL_TABLE_OPTION)
  if not ok then
    return false, "unreadable (" .. tostring(value) .. ")"
  end
  if value == false and held_value ~= nil then
    return false, tostring(held_value) .. " (row disabled)"
  end
  return value == 1 or value == true, tostring(value)
end

-- true while the option shows the skill table; no log line
function CharacterReforged.SkillTableViewOn()
  local view_on = CharacterReforged.ReadSkillTableOption()
  return view_on
end

-- an entry of «Tabla de habilidades» is used: true = open the skill table, false = the game's board; one log line
function CharacterReforged.EntryOpensSkillTable(entry_name)
  local view_on, value_read = CharacterReforged.ReadSkillTableOption()
  pcall(funcLuaCommand, CharacterReforged.LOG_COMMAND, "Character Reforged skill table entry", tostring(entry_name),
    "option " .. CharacterReforged.SKILL_TABLE_OPTION .. " = " .. value_read,
    view_on and "opens evt_skill_slot_menu (Fantasy)" or "opens ability_learning_board_menu (Victory Road)")
  return view_on
end

-- ---- the open target ------------------------------------------------------------------------------------------------
-- A screen whose retail code opens the ability board itself (funcLuaCommand(CMND_OPEN_MENU_OBJECT,
-- ability_learning_board_menu), then waits while funcLuaMenuCommand(CMND_IS_EXIST_MENU_OBJECT, the board) is true):
-- once per VM (from the screen's own OnInit handler: funcLuaCommand exists only then), the two commands are wrapped so
--   * the open of the board, while the option shows the skill table (one log line per use), runs
--     open_skill_table() (the screen's parameters for evt_skill_slot_menu) and opens the skill table instead;
--   * the retail wait for the board waits for the skill table; when it is gone, after_close() runs once;
--   * «is the board unlocked» (command 347870658 with the board) answers true while the option shows the skill table,
--     so the retail code does not grey the entry out before the board is unlocked.
-- Every other call passes through unchanged (the caller's arguments as they are, docs/framework/lua-hosts.md §3).
CharacterReforged.OPEN_MENU_COMMAND = 433545986        -- CMND_OPEN_MENU_OBJECT (funcLuaCommand)
CharacterReforged.MENU_EXISTS_COMMAND = 2231168902     -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
CharacterReforged.MENU_UNLOCKED_COMMAND = 347870658    -- is a menu unlocked (funcLuaCommand)

function CharacterReforged.InstallBoardOpenRedirect(entry_name, open_skill_table, after_close)
  if CharacterReforged.boardOpenRedirect ~= nil or type(funcLuaCommand) ~= "function"
      or type(funcLuaMenuCommand) ~= "function" then
    return false
  end
  local redirect = {entry = entry_name, waiting = false}
  CharacterReforged.boardOpenRedirect = redirect
  local board = CharacterReforged.ABILITY_BOARD_MENU
  local skill_table = CharacterReforged.SKILL_TABLE_MENU
  local command = funcLuaCommand
  local menu_command = funcLuaMenuCommand
  funcLuaCommand = function(...)
    local id, menu = ...
    if menu == board and select("#", ...) == 2 then
      if id == CharacterReforged.OPEN_MENU_COMMAND and CharacterReforged.EntryOpensSkillTable(entry_name) then
        open_skill_table()
        redirect.waiting = true
        return command(CharacterReforged.OPEN_MENU_COMMAND, skill_table)
      elseif id == CharacterReforged.MENU_UNLOCKED_COMMAND and CharacterReforged.SkillTableViewOn() then
        return true
      end
    end
    return command(...)
  end
  funcLuaMenuCommand = function(...)
    local id, menu = ...
    if redirect.waiting and id == CharacterReforged.MENU_EXISTS_COMMAND and menu == board
        and select("#", ...) == 2 then
      local exists = menu_command(CharacterReforged.MENU_EXISTS_COMMAND, skill_table)
      if not exists then
        redirect.waiting = false
        if after_close ~= nil then
          after_close()
        end
      end
      return exists
    end
    return menu_command(...)
  end
  return true
end
