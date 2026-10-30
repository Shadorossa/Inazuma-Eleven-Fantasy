-- Character Reforged: the team dock's «Tabla de habilidades» opens the skill table (evt_skill_slot_menu) while the option
-- «Tabla de habilidades» shows the new set (row character_reforged.skill_set_view = «Fantasy»); «Victory Road» = the
-- game's own board. HOOK file of graft ss2_dock (docs/refactor/aura-mods-split.md «Skill table»; since 1.7.9).
-- Owner 2026-10-14: Character Reforged does not touch the team dock's player popup «PERSONAJE» (its rows, its list,
-- its OnDecideFocus): the popup's rows are the mods' rules on the VR-Framework's list rows (docs/framework/list-rows.md;
-- «Mover» is hidden by BetterUI). The redirect happens at the target: the retail type-5 branch writes the board's
-- parameters and opens ability_learning_board_menu with CMND_OPEN_MENU_OBJECT, then waits while the board exists;
-- CharacterReforged.InstallBoardOpenRedirect (assets\lua\_all\character_reforged_skill_table_entry.lua) turns that open
-- into the skill table with the parameters the «Equipamiento» entry gives equip_menu (below), and the wait into a wait
-- for the skill table; the retail return path then restores the dock as after the board.
-- Installed from a «before OnInit» handler on the VR-Framework's host of this script (funcLuaCommand exists only from
-- the first callback on); no engine call at load.
do
  local STEM = "team_dock_formation_menu"
  local KEY_BOARD_PLAYER = 4161869490      -- the board's player (written by the retail branch)
  local KEY_DOCK_NUMBER = 3357163798       -- the dock number (written by the retail branch, read by both screens)
  local KEY_DOCK_TYPE = 4081600465         -- the dock type (idem)
  local KEY_FORMATION = 813466851          -- the formation id (idem)
  local KEY_PLAYER = 1038144478            -- equip_menu_select's player
  local KEY_PLAYER_INDEX = 622145442       -- the selected index
  local KEY_OPEN_BOARD = 1881233917        -- evt_ss_open_board: a stale «open the original board» request
  local TEXT_SKILL_TABLE_HEADER = 2489792255

  local function set_param(key, value)
    VRFW_Param.Clear(key)
    VRFW_Param.Set(key, value)
  end

  local function read_param(key, default)
    if VRFW_Param.Has(key) then
      return VRFW_Param.Get(key)
    end
    return default
  end

  -- the parameters of the retail «Equipamiento» branch (equip_menu_select's OnInit / OnSetupLayer read them), from
  -- what the retail «Tabla de habilidades» branch wrote for the board
  local function open_skill_table()
    local player = read_param(KEY_BOARD_PLAYER, 0)
    VRFW_Param.Clear(KEY_BOARD_PLAYER)
    if (player == nil or player == 0) and type(GetFormationSelectCharaStHdl) == "function" then
      player = GetFormationSelectCharaStHdl()
    end
    local dock_number = read_param(KEY_DOCK_NUMBER, 0)
    local dock_type = read_param(KEY_DOCK_TYPE, 0)
    local formation = read_param(KEY_FORMATION, 0)
    VRFW_Param.Clear(KEY_OPEN_BOARD)
    VRFW_Param.Clear(KEY_DOCK_TYPE)
    VRFW_Param.Set(KEY_DOCK_TYPE, dock_type, "plain")
    local main_menu = MAIN_MENU.IsEnableUseMainMenu()
    set_param(2029825652, true)            -- team-dock member list (L/R changes player)
    set_param(363718978, main_menu)        -- main-menu mode
    set_param(4145209998, 0)               -- chara card type 0
    set_param(3308763177, false)
    set_param(2719720834, main_menu)       -- rpg attack / defense plate
    set_param(KEY_PLAYER, player)
    set_param(KEY_DOCK_NUMBER, dock_number)
    set_param(KEY_PLAYER_INDEX, GetFormationSelectCharaIdx())
    set_param(KEY_FORMATION, formation)
    SwapHeaderText(TEXT_SKILL_TABLE_HEADER)
    UpdateEquipButtonGuide(g_parentMenuId, true)
  end

  -- after the skill table closed: a stale request to open the original board is only cleared
  local function after_close()
    if VRFW_Param.Has(KEY_OPEN_BOARD) then
      VRFW_Param.Clear(KEY_OPEN_BOARD)
    end
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on(STEM, "OnInit", {id = "character_reforged.team_dock_skill_table", phase = "before", fn = function()
      if CharacterReforged ~= nil and CharacterReforged.InstallBoardOpenRedirect ~= nil then
        CharacterReforged.InstallBoardOpenRedirect("team dock (squad / formation)", open_skill_table, after_close)
      end
    end})
  end
end
