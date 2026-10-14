-- ===== EVT training team dock BEGIN =====
-- EVT training_v1: "Entrenamiento" in the team dock's team-command list (Plantilla de equipo -> the list with
-- "Equipar todo", "Quitar todo", ... = soccer_team_dock_menu item type 10). Appended by research/scripts/tr_build.py
-- to the CURRENT soccer_team_dock_menu text (an earlier copy of this block is removed first; other agents'
-- changes are kept). Opens evt_training_menu for the first member of the selected dock; L1/R1 switch players.
-- Docs: docs/game/training-classic.md §7.1. Only globals here: the chunk's locals (n5 dock no, l6/l7 coroutines,
-- n12 last row) are upvalues of this appended code; no new chunk-level locals are declared.
EVT_TRD_ENABLED = true                 -- false: no "Entrenamiento" row (the bean rows stay hidden)
EVT_TRD_ROW = 6                        -- row index of "Entrenamiento" (after the 6 retail rows 0..5)
EVT_TRD_TEXT = @crc:evt_tr_title0@     -- menu_text «Entrenamiento» (9 languages, Player Training's text/rows/training.toml)
EVT_TRD_MENU = @crc:evt_training_menu@
EVT_TRD_LOADER_VERSION = @crc:CMND_EVT_LOADER_VERSION@
EVT_TRD_KEY_HDL = 4161869490           -- evt_training_menu: first character (0 = first dock member)
EVT_TRD_KEY_DOCK_OK = @crc:evt_tr_dock_ok@
EVT_TRD_KEY_DOCK_NO = @crc:evt_tr_dock_no@
EVT_TRD_KEY_DOCK_TYPE = @crc:evt_tr_dock_type@
-- retail soccer_formation_menu_inc t13: Equipar todo, Quitar todo, (judías) x2, cambio de rendimiento, casilla
EVT_TRD_IDS = {3845375161, 150149707, 4260689898, 22372728, 2344649719, 3924033091}
-- Player Training replaces the beans (as Inazuma Fantasy did): the list shows only these retail rows (0-based retail
-- indices: Autoequipar equipo, Eliminar equipamiento, Ajustes de celebracion de gol), then "Entrenamiento". The bean
-- rows 2 / 3 and the [x] auto-beans checkbox 5 are gone. Visible rows are mapped back to the retail indices before
-- the retail callback runs, and the retail last-row index (n12) is mapped to a visible row when the list reopens.
EVT_TRD_SHOW = {0, 1, 4}
EVT_TRD_SIZE_BY_ROWS = {[1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 6, [6] = 3}

-- visible row (0-based) -> retail row; the row after the shown retail ones is "Entrenamiento" (EVT_TRD_ROW)
function EVT_TRD_Retail(v)
  if type(v) ~= "number" or v < 0 then
    return v
  end
  if v < #EVT_TRD_SHOW then
    return EVT_TRD_SHOW[v + 1]
  end
  return EVT_TRD_ROW
end

-- retail row -> visible row (0 when the retail row is hidden)
function EVT_TRD_Visible(r)
  if r == EVT_TRD_ROW then
    return #EVT_TRD_SHOW
  end
  for i = 1, #EVT_TRD_SHOW do
    if EVT_TRD_SHOW[i] == r then
      return i - 1
    end
  end
  return 0
end

function EVT_TRD_Available()
  local ok, api, mods = pcall(funcLuaCommand, EVT_TRD_LOADER_VERSION)
  if not ok or type(api) ~= "number" or type(mods) ~= "number" then
    return false
  end
  return math.floor(mods / 16) % 2 == 1          -- module bit 16 = training
end

function EVT_TRD_Param(key, v)
  funcLuaCommand(3363400568, key)
  funcLuaCommand(3860611758, key, 0, v, 1)
end

-- copy of soccer_formation_menu_inc OpenSelectTeamMemberControlSubWindowCore (its t13/t14/n5 are locals of the
-- include) with a 7th row; n5 here is the team dock menu's selected dock
function EVT_TRD_OpenCore(a1, a2)
  local focus = a2 or 0
  local ok, count = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], n5, 0, 0)
  local on = (ok ~= false and count ~= 0) and 1 or 0
  local enable = {on, on, on, on, on, on}
  local ret2 = funcLuaCommand(589837020, 1)
  ok, count = funcLuaCommand(1033065575 --[[CMND_GET_TEAM_SET_INFO?]], n5, 0, 0, false, false, false, true)
  if ok == false or count == 0 or ret2 <= 0 then
    enable[5] = 0
  end
  local ids, shown, check = {}, {}, {}
  for i = 1, #EVT_TRD_SHOW do
    ids[i] = EVT_TRD_IDS[EVT_TRD_SHOW[i] + 1]
    shown[i] = enable[EVT_TRD_SHOW[i] + 1]
    check[i] = 0
  end
  local extra = EVT_TRD_ENABLED and EVT_TRD_Available()
  if extra then
    ids[#ids + 1] = EVT_TRD_TEXT
    shown[#shown + 1] = on
    check[#check + 1] = 0
  end
  focus = EVT_TRD_Visible(focus)
  if focus >= #ids then
    focus = 0
  end
  -- beans are out of the design: keep the hidden "Autoequipar judias" setting off
  funcLuaCommand(2040257363, false)
  MENU_DEF.OpenSubWindow(a1, "", #ids, ids, EVT_TRD_SIZE_BY_ROWS[#ids] or 3, 3934778541 --[[gtxt_command01]], shown, focus, false, false, 22, 0, {}, -1, {}, {}, 0, check)
  waitFalse(function()
    return funcLuaCommand(667479479, 968210065 --[[sub_window]])
  end)
  funcLuaCommand(63483614, 960, -267)
  -- (retail: 628044124(5, auto-beans flag) ticked the checkbox of row 5; that row is gone)
  waitTrue(function()
    return funcLuaCommand(3444627471, 118161610 --[[win05_11_sub_list_locator_15]])
  end)
  funcLuaCommand(3647847018, focus, 118161610 --[[win05_11_sub_list_locator_15]])
end

-- replaces the menu's own OpenSelectTeamMemberControlSubWindowSoccerTeamDock (same body, our core)
function OpenSelectTeamMemberControlSubWindowSoccerTeamDock(a1, a2)
  funcLuaMenuCommand(1558704558, 937147172 --[[soccer_team_dock_menu]], false)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, false, 937147172 --[[soccer_team_dock_menu]])
  EVT_TRD_OpenCore(a1, a2)
  waitTrue(function()
    return funcLuaCommand(1521844538 --[[CMND_IS_CLOSE_MENU_OBJECT]], 968210065 --[[sub_window]])
  end)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, true, 937147172 --[[soccer_team_dock_menu]])
  funcLuaMenuCommand(1558704558, 937147172 --[[soccer_team_dock_menu]], true)
  l6 = nil
end

-- runs as l7 (resumed by Step) after the list closed: open the training menu, wait, reopen the list on our row
function EVT_TRD_TrainingCoroutine()
  funcLuaMenuCommand(1558704558, 937147172 --[[soccer_team_dock_menu]], false)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, false, 937147172 --[[soccer_team_dock_menu]])
  EVT_TRD_Param(EVT_TRD_KEY_HDL, 0)
  EVT_TRD_Param(EVT_TRD_KEY_DOCK_OK, 1)
  EVT_TRD_Param(EVT_TRD_KEY_DOCK_NO, n5)
  EVT_TRD_Param(EVT_TRD_KEY_DOCK_TYPE, 0)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "EVT training: team dock -> evt_training_menu", "dock", n5)
  funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], EVT_TRD_MENU)
  local n = 0
  while not funcLuaCommand(264888438 --[[CMND_IS_EXIST_MENU?]], EVT_TRD_MENU) and n < 180 do
    coroutine.yield()
    n = n + 1
  end
  waitFalse(function()
    return funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], EVT_TRD_MENU)
  end)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, true, 937147172 --[[soccer_team_dock_menu]])
  funcLuaMenuCommand(1558704558, 937147172 --[[soccer_team_dock_menu]], true)
  UpdateFormationInfo()
  l7 = nil
  n12 = EVT_TRD_ROW
  l6 = coroutine.create(OpenSelectTeamMemberControlSubWindowSoccerTeamDock)
end

-- the retail definition earlier in this same chunk run (fresh upvalues every time the menu script runs)
EVT_TRD_ORIG_CALLBACK = CallbackCloseCondTeamCommandSubWinSoccerTeamDock
function CallbackCloseCondTeamCommandSubWinSoccerTeamDock(a1)
  a1 = EVT_TRD_Retail(a1)
  if a1 == EVT_TRD_ROW and EVT_TRD_ENABLED then
    l6 = nil
    n12 = EVT_TRD_ROW
    l7 = coroutine.create(EVT_TRD_TrainingCoroutine)
    funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 968210065 --[[sub_window]])
    return
  end
  return EVT_TRD_ORIG_CALLBACK(a1)
end
-- ===== EVT training team dock END =====
