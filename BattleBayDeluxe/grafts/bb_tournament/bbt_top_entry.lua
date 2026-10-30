-- BattleBayDeluxe bb_tournament, top menu part: the entry: continue / view / new from the Campaña row or the hub.
-- Appended after bbt_top.lua in graft.toml's order: the parts share one chunk and its locals.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

-- ------------------------------------------------------------------------------------------------ the entry

-- the «Torneo» row decided (bbt_row.lua; the «Modos de juego» tile or the top bar step): with a run, continue / new
-- (1.5.17, owner: a new tournament even while one runs, after a Yes / No; an ended run: view / new); else (1.5.4,
-- owner's flow) the tournament is armed with the defaults and the Campaña grid opens
-- (1.5.5: through the 1P row's path with the Campaña variant, whether a Campaña runs or not): the team first (the Draft tile
-- too), then the options panel (bbt_grid.lua: group stage, teams, the knockout rules), then the difficulty window; its
-- start draws the tournament (no match starts), and back here the bracket shows the first round: Enter = match 1.
-- Runs in the decide coroutine.
function BBT_EntryTournament()
  BattleBayDeluxe.TournamentState.entry = true
  local ok, err = pcall(BBT_EntryFlow)
  BattleBayDeluxe.TournamentState.entry = false
  if not ok then
    error(err, 0)
  end
end

-- 1.5.18 (owner): the Torneo panel. A run (or an ended one): the bracket opens and the window comes centred over it,
-- «Continuar el torneo» (the next match, or the next simulated round once out) / «Ver el cuadro» (the bracket stays,
-- its keys) / «Nuevo torneo» (Yes / No while one runs; No = the window again); Back = both closed, the player where he
-- was. No run: a new one at once (the team grid).
function BBT_EntryFlow()
  while true do
    local info = BBT_Info()
    if not (info.active or info.ended) then
      return BBT_NewRun()
    end
    -- 1.48.0: a running league opens its career hub
    if info.active and info.fmt == 2 then
      return BBT_LeagueHub()
    end
    BBT_Open(BBT_EntryPage())
    -- 1.45.0: a league's panel says «liga» (the texts <key>_league)
    local lg = info.fmt == 2
    local cont, view, new = BBT_Id(BBT_RunKey("continue", lg)), BBT_Id(BBT_RunKey("view", lg)),
      BBT_Id(BBT_RunKey("new", lg))
    local ids = { cont, view, new }
    if not info.active then
      ids = { view, new }
    end
    -- 1.5.20: the host menu's input is never switched (1.5.19 did: no effect, and it disturbs the engine's input)
    local c = BBT_Choose(ids, 0)
    local id = ids[c + 1]
    if c < 0 or id == nil then
      if BattleBayDeluxe.TournamentState.open then
        funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
        BBT_Close()
      end
      return
    end
    if id == cont then
      BBT_OnEnter()
      return
    end
    if id == view then
      return -- the bracket stays up: L1 / R1 pages, Enter = the next match, Back closes
    end
    -- «Nuevo torneo»: a running one is dropped only after a Yes (its Campaña block back, as «Abandonar» did); an
    -- ended one is put aside as its last screen would
    -- 1.5.20 (owner, 1.5.18 / 1.5.19 logs): a retail general window (Yes / No) opened over «Modos de juego» never
    -- takes its answer (the BB Campaña's «Partida nueva» question neither); the question is the same centred
    -- window as the panel instead: «Sí, empezar de cero» / «No, volver», cursor on No
    local go = true
    if info.active then
      local a = BBT_Choose({ BBT_Id("new_yes"), BBT_Id("new_no") }, 1)
      go = a == 0
      BBT_Log("new tournament: answer", go and "yes" or "no", a)
    end
    if go then
      if info.active then
        BBT_Call(BattleBayDeluxe.Tournament.ABANDON)
        BBT_Log("new tournament: the running one abandoned")
      else
        BBT_Call(BattleBayDeluxe.Tournament.CLOSE)
        BBT_Log("new tournament: the ended one put aside")
      end
      pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, "")
      if BattleBayDeluxe.TournamentState.open then
        BBT_Close()
      end
      return BBT_NewRun(lg and 2 or -1)
    end
  end
end

-- a new tournament: armed with the defaults, the team grid (the host's way: this menu's 1P path with the Campaña
-- variant, or «Modos de juego»'s own grid), back from it the bracket of the first round (or disarmed)
-- fmt: the format armed (-1 / nil = the tournament's default, 2 = the league: «Nueva liga»)
function BBT_NewRun(fmt)
  local armed, why = BBT_Call(BattleBayDeluxe.Tournament.ARM, fmt or -1, 0, 0)
  if armed ~= true then
    BBT_Log("not armed", tostring(armed), tostring(why))
    return
  end
  -- 1.5.5: the grid opens through the 1P row's own path (no «Campaña in progress» window: the Torneo is independent
  -- of the Campaña), its menu variant swapped to the Campaña's (BBT_OpenGridAsCampaign, 1.5.7: at run time);
  -- 1.5.18: the host's way (BattleBayDeluxe.TournamentHost.open_grid)
  BBT_Log("new tournament: armed, team grid opens on", BattleBayDeluxe.TournamentHost.name)
  BattleBayDeluxe.TournamentState.newrun = true
  local okg, errg = pcall(BattleBayDeluxe.TournamentHost.open_grid)
  BattleBayDeluxe.TournamentState.newrun = false
  if not okg then
    error(errg, 0)
  end
  -- 1.33.2: the grid not opened (the menu never settled): the armed run goes, the top menu stays usable
  if errg == false then
    BBT_Call(BattleBayDeluxe.Tournament.DISARM)
    BBT_Log("new tournament: the team grid did not open, the run is disarmed")
    return
  end
  BBT_Log("new tournament: team grid closed")
  -- back from the grid: a started tournament shows its bracket (the first round); else the armed one goes
  local i3 = BBT_Info()
  if i3.active and i3.fmt == 2 then
    return BBT_LeagueHub()
  elseif i3.active then
    BBT_Open(BBT_EntryPage())
  elseif i3.armed then
    BBT_Call(BattleBayDeluxe.Tournament.DISARM)
  end
end

-- the «Campaña» row of the list: (layer, index, rows), nil when not listed
function BBT_CampaignRow()
  for _, l in ipairs({ BattleBayDeluxe.Tournament.LIST_MID, BattleBayDeluxe.Tournament.LIST_SMALL }) do
    local n = GetNumUsedButtons(l) or 0
    for i = 0, n - 1 do
      local info = GetLitItemInfo(l, i)
      if info ~= nil and info.menuObjectName == BattleBayDeluxe.Tournament.ROW_CAMPAIGN then
        return l, i, n
      end
    end
  end
  return nil
end

-- the menu's focus on the «Campaña» row, handed over as the retail menu hands it between its two lists (OnChangeFocus,
-- WaitExecOtherMenu): only the row's list takes the control focus (with both lists enabled the other one takes the
-- keys at its own stale index), the row focused and lit, the cursor on it, the retail SelectListItem / content guide
-- told (the help text is the row's own)
function BBT_FocusCampaignRow()
  local l, i, n = BBT_CampaignRow()
  if l == nil then
    l, i, n = BattleBayDeluxe.Tournament.LIST_MID, 0, GetNumUsedButtons(BattleBayDeluxe.Tournament.LIST_MID) or 1
  end
  for _, other in ipairs({ BattleBayDeluxe.Tournament.LIST_MID, BattleBayDeluxe.Tournament.LIST_SMALL }) do
    if other ~= l then
      funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, other, false)
    end
  end
  funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, l, true)
  funcLuaMenuCommand(1778826357 --[[set focus index]], l, i, true)
  funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@ --[[button anime]], l, i, 1286797620, 0 --[[lit]], 973515837)
  funcLuaMenuCommand(@crc:CMND_SET_CURSOR_LOCATOR@, l, 3313461902 --[[cursor]], i, n)
  pcall(SelectListItem, l)
  pcall(UpdateContentGuide, i)
  return l, i
end

-- the «SIGUIENTE» badge under the «Campaña» row (vs11_01_next_stage_guide): the retail text and crest are the Campaña
-- record's; while a Torneo / Liga runs (the run the «Campaña» row opens) they are its next match: the matchday or the
-- round and the rival with his crest (CMND_BBD_TOURN_INFO next_stage / next_round / rival). No run: the retail badge.
BattleBayDeluxe.Tournament.BADGE = 2575749231 --[[vs11_01_next_stage_guide]]
BattleBayDeluxe.Tournament.BADGE_TEXT = 2060256098
BattleBayDeluxe.Tournament.BADGE_KEYS = { league = "badge_league", groups = "badge_groups", ko = "badge_ko" }
function BBT_NextBadge(info, inst)
  if BattleBayDeluxe.TournamentHost.name ~= "bb_stadium_top_menu" or type(info) ~= "table" or not info.active then
    return false
  end
  local key = BattleBayDeluxe.Tournament.BADGE_KEYS[info.next_stage or ""]
  if key == nil then
    return false
  end
  inst = inst or 0
  local rival = info.rival or 0
  local name = rival ~= 0 and VRFW_Team.Name(rival) or ""
  if name == "" then
    name = BBT_Text("sched_rival_tbd")
  end
  local round = info.next_stage == "ko" and BBT_Text("round_" .. tostring(info.next_round or 1)) or ""
  local s = BBT_TextValue(key, info.next_round or 0)
  s = s:gsub("<ROUND>", function() return round end):gsub("<NAME>", function() return name end)
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, BattleBayDeluxe.Tournament.BADGE, BattleBayDeluxe.Tournament.BADGE_TEXT, s, inst, 0, true)
  funcLuaMenuCommand(@crc:CMND_UPDATE_TEXT_PLATE@ --[[fit the text]], BattleBayDeluxe.Tournament.BADGE, inst, BattleBayDeluxe.Tournament.BADGE_TEXT)
  if rival ~= 0 then
    local ok, _, tex = pcall(funcLuaCommand, 2151743654 --[[team info]], rival, 6 --[[crest]], 0)
    if ok and tex ~= nil then
      funcLuaMenuCommand(3190452549, BattleBayDeluxe.Tournament.BADGE, inst, 2487102008, 1212643255, tex, 0, true, true)
    end
  end
  return true
end

-- decide the «Campaña» row in a coroutine (as the hub's own decide runs): mode "tournament" (the top bar's Torneo,
-- the header selector's Torneo after the grid) or "campaign" (the header selector's Campaña over the Torneo)
function BBT_DecideCampaignRow(mode)
  local l, i, n = BBT_CampaignRow()
  if l == nil then
    BBT_Log("no Campaña row in the list:", mode)
    return false
  end
  BattleBayDeluxe.TournamentState.row_mode = mode
  BBT_FocusCampaignRow()
  BattleBayDeluxe.TournamentState.co = coroutine.create(function()
    OnDecideFocus(l, i)
  end)
  BBT_Log("Campaña row decided in mode", mode)
  return true
end

-- the top bar step (Battle Bay › Torneo): the Campaña row in Torneo mode
function BBT_DecideRow()
  BBT_DecideCampaignRow("tournament")
end
