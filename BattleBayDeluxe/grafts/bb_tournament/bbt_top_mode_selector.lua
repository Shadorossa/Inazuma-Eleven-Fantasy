-- BattleBayDeluxe bb_tournament, top menu part: this menu's side of the Campaña / Torneo mode selector.
-- Appended after bbt_top.lua in graft.toml's order: the parts share one chunk and its locals.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

-- ------------------------------------------------------------------------------------------------ the mode selector
-- (bbt_mode.lua draws it; this menu's side: «Torneo» lit while the bracket / its panel is up)

-- the team grid (enjoy_team_select_menu) seen open, then closed: what the grid left for this menu. Only for a grid
-- this file did not open itself (BBT_NewRun shows its own bracket): the header's «Torneo» with a run (parameter
-- evt_bbd_mode_go_tournament) = the Torneo here; a tournament started in it = its bracket; an armed leftover disarmed.
BBT_MODE_P_GO_T = @crc:evt_bbd_mode_go_tournament@
function BBT_ModeAfterGrid()
  local S = BattleBayDeluxe.TournamentState
  local exists = funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, 786045682 --[[enjoy_team_select_menu]]) == true
  if exists then
    if not S.grid_seen then
      S.grid_seen = true
      S.grid_own = S.newrun == true
      S.grid_active = BBT_Info().active == true
    end
    return
  end
  if not S.grid_seen then
    return
  end
  S.grid_seen = false
  if S.grid_own then
    return
  end
  if VRFW_Param.Has(BBT_MODE_P_GO_T) then
    VRFW_Param.Clear(BBT_MODE_P_GO_T)
    S.after_grid, S.frames_after = "tournament", 0
    BBT_Log("grid closed: the Torneo asked from its header")
    return
  end
  local info = BBT_Info()
  if info.active and not S.grid_active then
    S.after_grid, S.frames_after = "bracket", 0
    BBT_Log("grid closed: a tournament started in it, its bracket")
  elseif info.armed then
    BBT_Call(BattleBayDeluxe.Tournament.DISARM)
    pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, "")
  end
end

-- what waits for the menu's focus after a grid / a mode switch
function BBT_ModeAfterStep()
  local S = BattleBayDeluxe.TournamentState
  if S.after_grid == nil or S.co ~= nil or S.open or S.entry then
    return
  end
  S.frames_after = (S.frames_after or 0) + 1
  if S.frames_after > 600 then
    BBT_Log("mode: gave up waiting for the menu:", S.after_grid)
    S.after_grid = nil
    return
  end
  if S.frames_after < 6 or not BattleBayDeluxe.TournamentHost.ready() or funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) == true
    or funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW) == true then
    return
  end
  local what = S.after_grid
  S.after_grid = nil
  if what == "bracket" then
    if BBT_Info().fmt == 2 then
      S.co = coroutine.create(BBT_LeagueHub)
    else
      BBT_Open(BBT_EntryPage())
    end
  elseif what == "tournament" or what == "campaign" then
    BBT_DecideCampaignRow(what)
  end
end

-- bbt_mode.lua's Step hook in this menu: the grid watch, the waiting switch. The selector is never shown here (owner
-- 2026-10-13: only on the team-select grid before a run starts; a Torneo up here is a run in progress): kept hidden
function BBT_ModeTopStep()
  if BattleBayDeluxe.TournamentHost.name ~= "bb_stadium_top_menu" then
    return
  end
  local S = BattleBayDeluxe.TournamentState
  BBT_ModeAfterGrid()
  BBT_ModeAfterStep()
  -- 1.5.57: the selector's layers are no longer in this menu (the grid's own only): nothing drawn here
  BBT_ModePoll(false)   -- keeps the key / click edges current
end

-- 1.5.57 diagnosis (the white Battle Bay top menu of 2026-10-13: the menu past the engine's layer instance limit never
-- finished opening). Once per opening, BBT_SETUP_FRAMES Steps after OnInit: the instances the engine created of each
-- overlay pool (CMND_GET_CREATE_LAYER_NUM) against the menu file's counts, whether the background
-- (mainmenu90_00_background) is open and whether the screen is still covered by a fade (2259183189). A short pool
-- or «covered true» = the menu is still too big.
BBT_SETUP_FRAMES = 180
function BBT_SetupCheck()
  if BattleBayDeluxe.TournamentHost.name ~= "bb_stadium_top_menu" then
    return
  end
  local parts, short = {}, 0
  for k, n in pairs(BattleBayDeluxe.Tournament.N) do
    local got = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, BattleBayDeluxe.Tournament.L[k])
    got = type(got) == "number" and got or -1
    if got < n then
      short = short + 1
    end
    parts[#parts + 1] = string.format("%s %d/%d", k, got, n)
  end
  table.sort(parts)
  local bg = funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, 367379312 --[[mainmenu90_00_background]], 0)
  local covered = funcLuaCommand(2259183189) == true
  BBT_Log(string.format("top menu setup: %s; background open %s, covered %s (%s)", table.concat(parts, ", "),
    tostring(bg), tostring(covered), (short > 0 or covered) and "STUCK? pools short or screen covered" or "ok"))
end
