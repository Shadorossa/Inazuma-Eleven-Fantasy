-- BetterUI «Ajustes de la IA» (graft clean_hud_team_ai; docs/game/ui/team-commands.md §10), team dock part. Ported
-- from Inazuma Fantasy's team commands (graft team_cmd_dock: the «IA» cell of its COMANDOS grid) on 2026-10-14. HOOK file
-- (docs/framework/lua-hosts.md §7):
--   * the formation's team COMANDOS window (Alt / «Equipar todo») gets the row «Ajustes de la IA» (text
--     clean_hud_team_ai_cmd, BetterUI text\rows\team_ai.toml): an Add rule of the VR-Framework's list rows
--     (docs/framework/list-rows.md), after BetterUI's «Ajustes de dorsales» (or at the end);
--   * the row arms the AI-role mode and runs the retail «Ajustes de celebración de gol» (COMANDOS row 4): the retail
--     code opens the goal celebration list (soccer_performance_change_menu) through WaitExecPerfromanceChangeMenu,
--     whose handler here writes the param store keys clean_hud_team_ai = 1 and clean_hud_team_ai_type = the dock's
--     team type; the graft's bytecode child of that menu (team_ai_menu.lua) reads them: every player's AI role for the
--     whole team, Enter = the retail role chooser;
--   * the per-player «Configurar rol de la IA» is hidden from the player popup by BetterUI (graft clean_hud_chara_menu).
-- The dock's team type: retail OnInit consumes it from the param store, so a «before OnInit» handler reads it first
-- (nothing consumed). Handlers on the VR-Framework's host of this script; no engine call at load.
do
  local STEM = "team_dock_formation_menu"
  local TEAM_AI_KEY = 3639925978          -- crc32("clean_hud_team_ai"): 1 = the celebration list in AI-role mode
  local TEAM_AI_KEY_TYPE = 2232472304     -- crc32("clean_hud_team_ai_type"): the dock's team type
  local TEAM_AI_TEXT = 1469443788         -- crc32("clean_hud_team_ai_cmd"): menu_text «Ajustes de la IA»
  local TEAM_AI_ROW = 101                 -- the row id of «Ajustes de la IA» in the COMANDOS window
  local SHIRT_NUMBERS_ROW = 100           -- BetterUI's «Ajustes de dorsales» (graft clean_hud_shirt_number)
  local PARAM_TEAM_TYPE = 4081600465      -- retail OnInit reads (and consumes) the dock's team type here

  BetterUI_TeamAIDock = BetterUI_TeamAIDock or {}
  local D = BetterUI_TeamAIDock
  D.teamType = D.teamType or 0
  D.armed = false

  local function set_param(key, value)
    VRFW_Param.Clear(key)
    VRFW_Param.Set(key, value)
  end

  if VRFW_ListRows ~= nil then
    local Rows = VRFW_ListRows
    Rows.Add(Rows.TEAM_COMMANDS, {id = "clean_hud.team_ai", row = TEAM_AI_ROW, text = TEAM_AI_TEXT,
      after = SHIRT_NUMBERS_ROW,
      run = function(context)
        D.armed = true
        if PRINT ~= nil then
          pcall(PRINT, "BetterUI team_ai", "open AI settings, team type", D.teamType)
        end
        return context.retail(Rows.TEAM_COMMAND.GOAL_CELEBRATION)
      end})
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on(STEM, "OnInit", {id = "clean_hud.team_ai_team_type", phase = "before", fn = function()
      D.teamType = 0
      if VRFW_Param.Has(PARAM_TEAM_TYPE) then
        D.teamType = VRFW_Param.Get(PARAM_TEAM_TYPE) or 0
      end
    end})
    -- the retail case 4 runs coroutine.create(WaitExecPerfromanceChangeMenu) through the global: the menu's mode
    VRFW_Host.on(STEM, "WaitExecPerfromanceChangeMenu", {id = "clean_hud.team_ai_mode", phase = "around",
      fn = function(next_handler, ...)
        if D.armed then
          set_param(TEAM_AI_KEY, 1)
          set_param(TEAM_AI_KEY_TYPE, D.teamType or 0)
        else
          VRFW_Param.Clear(TEAM_AI_KEY)
        end
        D.armed = false
        return next_handler(...)
      end})
  end
end
