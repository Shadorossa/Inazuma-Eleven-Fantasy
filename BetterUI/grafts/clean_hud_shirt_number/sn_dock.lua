-- ===== EVT ui_clean shirt_number BEGIN =====
-- research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11
do
local EVT_UI_Block = function()
-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), shirt_number_dock (menu tag for the log).
local EVT_UI_MARK = "EVT_UI_CLEAN_GRAFT"

-- Kill switch. EVT_UI_PRESET = "off" makes every ui_clean wrapper pass everything through unchanged.
-- Each feature can also be switched off on its own in EVT_UI_FLAGS (set by the build, see --preset / --no-*).
if EVT_UI_PRESET == nil then
  EVT_UI_PRESET = "limpio"
end
EVT_UI_FLAGS = EVT_UI_FLAGS or {}
for k, v in pairs({ bank_sort_guide = true, buff_icons = true, buff_panel = false, corner_buttons = true, duel_telop = true, enemy_meters = true, esc_guide = true, exec_offset = true, header_short = true, nickname_pill = true, shirt_number = true, team_param_guide = true, zone_exec = false, zone_hud = true }) do
  if EVT_UI_FLAGS[k] == nil then
    EVT_UI_FLAGS[k] = v
  end
end

@UI_WRAP@

EVT_UI_FLAGS.shirt_number = true
-- EVT ui_clean, Clean HUD «shirt numbers» (flag shirt_number; graft research/grafts/clean_hud_shirt_number,
-- docs/game/ui/team-commands.md §9, docs/game/ui/ui-redesign.md). Team dock «Formación» (team_dock_formation_menu):
--   * the per-player command window no longer lists «Cambiar número de dorsal» (setting type 6): a Hide rule of the
--     VR-Framework's list rows (docs/framework/list-rows.md, BetterUI 1.21.26; this block wrapped
--     GetSelectSettingTypeOrderList itself until then);
--   * the team COMANDOS window (Alt, OpenSelectTeamMemberControlSubWindowCore -> sub-window type 22) gets the row
--     «Ajustes de dorsales» (text clean_hud_shirt_number_cmd) after the retail rows: an Add rule of the same list rows
--     (until 1.21.26 this block wrapped MENU_DEF.OpenSubWindow and the opener and answered the window with its own
--     callback); the framework maps the window's positions back to the retail rows (the bean checkbox, the focus) and
--     sizes the window by its rows (the win05_11 list shows at most 6, more rows scroll);
--   * that row opens the goal celebration screen (soccer_performance_change_menu) in shirt-number mode: the param
--     store key clean_hud_shirt_number = 1 (+ clean_hud_shirt_number_type = the dock's team type), written by the
--     WaitExecPerfromanceChangeMenu wrapper, is read by the graft's bytecode child of that menu.
-- Flag off -> every wrapper passes through: retail per-player list and retail 6-row COMANDOS.
-- Exports (another mod's graft calls them at run time, never at load; Inazuma Fantasy's COMANDOS grid uses them for
-- its «Dorsal» cell):
--   CLEAN_HUD_SHIRT_NUMBER.On()    the feature is on in this build
--   CLEAN_HUD_SHIRT_NUMBER.Arm()   the next WaitExecPerfromanceChangeMenu opens the screen in shirt-number mode
-- No engine call at load: only wrappers (the patch runs before the engine registers the menu commands).
local SN_KEY = 427961193            -- param store: 1 = open the celebration screen in shirt-number mode
local SN_KEY_TYPE = 1264286919  -- param store: team type of this dock
local SN_TEXT_CMD = 2111784635   -- menu_text «Ajustes de dorsales» (Clean HUD text/rows)
local SN_ROW = 100              -- the row id of «Ajustes de dorsales» in the COMANDOS window (above the retail 0..5)
local SN_PARAM_TEAM_TYPE = 4081600465 -- retail OnInit reads (and consumes) the dock's team type here

CLEAN_HUD_SHIRT_NUMBER = CLEAN_HUD_SHIRT_NUMBER or {}
local S = CLEAN_HUD_SHIRT_NUMBER
S.teamType = S.teamType or 0
S.armed = false

function S.On()
  return UiOn("shirt_number")
end

function S.Arm()
  S.armed = true
end

local function SnSetParam(key, v)
  VRFW_Param.Clear(key)
  VRFW_Param.Set(key, v)
end

-- the dock's team type: retail OnInit consumes the param, so it is read just before (nothing is consumed here)
local function SnReadTeamType()
  S.teamType = 0
  if VRFW_Param.Has(SN_PARAM_TEAM_TYPE) then
    S.teamType = VRFW_Param.Get(SN_PARAM_TEAM_TYPE) or 0
  end
end

-- the menu's mode for the celebration screen, just before retail case 4 opens it
local function SnArmCelebrationMenu()
  if S.armed and S.On() then
    SnSetParam(SN_KEY, 1)
    SnSetParam(SN_KEY_TYPE, S.teamType or 0)
  else
    VRFW_Param.Clear(SN_KEY)
  end
  S.armed = false
end

-- The team dock is a VR-Framework host (VRFW_Host, its 000_host patch): OnInit and WaitExecPerfromanceChangeMenu are
-- hook points there, so the two steps are host handlers, never a reassignment of the globals (BetterUI 1.21.27: the
-- old `OnInit = function ... return S.origInit(...)` sat over the host's dispatcher and called it through a table
-- field; the next registration on OnInit hooked the host again over it and the two called each other: Lua stack
-- overflow when opening the team dock, 2026-10-14). Without the host: the wrappers, once per VM (S.wrapped).
local SN_STEM = "team_dock_formation_menu"
if type(VRFW_Host) == "table" and type(VRFW_Host.on) == "function" then
  VRFW_Host.on(SN_STEM, "OnInit", {id = "clean_hud.shirt_number_team_type", phase = "before", fn = SnReadTeamType})
  -- retail case 4 runs coroutine.create(WaitExecPerfromanceChangeMenu) through the global: tell the menu its mode
  VRFW_Host.on(SN_STEM, "WaitExecPerfromanceChangeMenu", {id = "clean_hud.shirt_number_mode", phase = "before",
    fn = SnArmCelebrationMenu})
elseif not S.wrapped then
  S.wrapped = true
  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      SnReadTeamType()
      return init(...)
    end
  end
  local perf = WaitExecPerfromanceChangeMenu
  if type(perf) == "function" then
    WaitExecPerfromanceChangeMenu = function(...)
      SnArmCelebrationMenu()
      return perf(...)
    end
  end
end

-- the per-player popup without «Cambiar número de dorsal»; the COMANDOS row «Ajustes de dorsales» = the retail
-- «Ajustes de celebración de gol» (case 4) with the shirt-number mode armed
if VRFW_ListRows ~= nil then
  local Rows = VRFW_ListRows
  Rows.Hide(Rows.PLAYER_COMMANDS, {id = "clean_hud.hide_shirt_number", row = Rows.PLAYER_COMMAND.SHIRT_NUMBER,
    when = function() return S.On() end})
  Rows.Add(Rows.TEAM_COMMANDS, {id = "clean_hud.shirt_numbers", row = SN_ROW, text = SN_TEXT_CMD,
    when = function() return S.On() end,
    run = function(context)
      S.armed = true
      UiLog("open shirt numbers")
      return context.retail(Rows.TEAM_COMMAND.GOAL_CELEBRATION)
    end})
end


end
EVT_UI_Block()
end
-- ===== EVT ui_clean shirt_number END =====
