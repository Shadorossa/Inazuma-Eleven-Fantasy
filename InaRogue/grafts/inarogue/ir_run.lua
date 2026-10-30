-- v2: the options of the new run, asked before it starts: this week's run (the framework's week, the same run for
-- everyone; not asked once won that week), else the highest Ascension open and the challenges (both only after the
-- first won run opened Ascension 1). Questions and texts come from the script.
local function StartOptions()
  Call(RL_OPTIONS, 6)
  local week = nil
  if VRFW_Daily ~= nil and VRFW_Daily.Period ~= nil then
    week = VRFW_Daily.Period("week")
  end
  if type(week) == "number" and week > 0 then
    local ok, q = Call(RL_OPTIONS, 4, week)
    if ok == true and type(q) == "string" and Ask(q) then
      Call(RL_OPTIONS, 5, week)
      Log("options: weekly run of week", week)
      return
    end
  end
  local open, _, n, ask_challenges = Call(RL_OPTIONS, 0)
  open, n = Int(open), Int(n)
  if open <= 0 then
    return
  end
  -- every open Ascension level as a card of the framework's pick screen (level 0 .. open); without it, one question
  local level = nil
  if VRFW_PickCards ~= nil and Call(RL_OPTIONS, 7) == true then
    local pick = VRFW_PickCards.Show()
    if pick ~= nil and pick > 0 then
      level = pick - 1
    end
  end
  if level ~= nil then
    Call(RL_OPTIONS, 1, level)
  else
    local ok, q = Call(RL_OPTIONS, 1, open)
    if not (ok == true and type(q) == "string" and Ask(q)) then
      Call(RL_OPTIONS, 1, 0)
    end
  end
  if n > 0 and type(ask_challenges) == "string" and ask_challenges ~= "" and Ask(ask_challenges) then
    for i = 1, n do
      local okc, qc = Call(RL_OPTIONS, 2, i)
      if okc == true and type(qc) == "string" and Ask(qc) then
        Call(RL_OPTIONS, 3, i)
      end
    end
  end
  Log("options: ascension up to", open, "challenges", n)
end

-- A new run (§28: no window here; the caller already asked when a run in progress is abandoned): the first-run gift,
-- then the persistent team of «Plantilla de equipo» as it is (DK.QuickStart: the dock only when it cannot play), then
-- the map.
local function NewRun()
  StartOptions()
  IRM_SpiritSpend()
  local budget, _, gift, _, size, pick_on = Call(RL_STARTER)
  if pick_on == true then
    -- PokeRogue run start (docs/game/inarogue.md §12): first-run gift, then the starter picker (the bank)
    if gift == true then
      local n = Int(Call(RL_GIFT))
      Log("first-run gift", n)
      if n > 0 then
        Message(T(TXT.GIFT, n))
      end
    end
    -- §21: the INAROGUE team persists in the INAROGUE save («Plantilla de equipo» row): the run uses it as it is when
    -- it is valid; otherwise the reason and the retail team dock (§16), where the run starts when the title reopens
    -- INAROGUE with a valid team (DK.Finish)
    if not DK.QuickStart() then
      return
    end
  else
    local code, seed = Call(RL_RUN_START, 0)
    Log("new run code", Int(code), "seed", tostring(seed))
    if Int(code) ~= 0 then
      Message(T(TXT.RUN_ERROR, Int(code)))
      return
    end
  end
  -- slot 4: the run's players as real characters of the INAROGUE save (§14 stages 2-3; no-op when they exist)
  if not DK.Materialise() then
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  IRM_OpenMap()
end

-- the summary of the run that just ended (script text), when there is one
local function ShowSummary()
  local text = Call(RL_SUMMARY)
  if type(text) == "string" and text ~= "" then
    Message(text)
  end
end

-- a won v2 run (the final boss beaten): the victory, then endless mode (the next board) or the end of the run and its
-- summary. Returns false when no run is waiting for its end.
function IRM_RunOutro()
  local pending, title, ask = Call(RL_OUTRO, 0)
  if pending ~= true then
    return false
  end
  funcLuaCommand(C.SE, SE_OK)
  if type(title) == "string" and title ~= "" then
    Message(title)
  end
  if type(ask) == "string" and ask ~= "" and Ask(ask) then
    local code, phase = Call(RL_OUTRO, 1)
    Log("outro: endless -> code", Int(code), "phase", Int(phase))
    if Int(code) == 0 then
      run = ReadRun()
      if DK.Materialise() then
        IRM_OpenMap()
      end
      return true
    end
  end
  local code, text = Call(RL_OUTRO, 2)
  Log("outro: run ends -> code", Int(code))
  if type(text) == "string" and text ~= "" then
    Message(text)
  end
  Call(MT.SET_BYTE, MT.F_STATE, 0)
  run = ReadRun()
  RefreshItems()
  return true
end

-- {name} of a script text = the player's name (the game's own name of chara_param `param`)
local function WithName(text, param)
  if type(text) ~= "string" then
    return ""
  end
  if type(param) ~= "number" or param == 0 then
    return text
  end
  local _, name = Call(RL_CHARA_NAME, param, 0)
  name = type(name) == "string" and name or "?"
  return (text:gsub("{name}", function() return name end))
end

-- the framework's pick screen (VRFW_PickCards, cards set by the script: op 5): picks until a card ends the offer, the
-- player skips, or the screen cannot open (false: the windows below take over). A recruit is created later.
local function OfferPicks(exclusive)
  if VRFW_PickCards == nil then
    return false
  end
  local shown = false
  for _ = 1, 12 do
    if Call(RL_OFFER, 5) ~= true then
      return shown
    end
    local pick = VRFW_PickCards.Show()
    if pick == nil then
      return shown
    end
    shown = true
    if pick <= 0 then
      return true
    end
    local code, text, _, p2 = Call(RL_OFFER, 2, pick)
    Log("offer pick", pick, "code", Int(code))
    if Int(code) == 0 then
      funcLuaCommand(C.SE, SE_OK)
    end
    if type(text) == "string" and text ~= "" then
      Message(WithName(text, p2))
    end
    if exclusive == true and Int(code) == 0 then
      return true
    end
  end
  return shown
end

-- the offers of the board waiting in the run (the players of the beaten rival, relics, talents): the pick screen, else
-- an intro window and one question per choice; a player who joins is created in the save by DK.Materialise before the
-- board opens
function IRM_Offers()
  for _ = 1, 8 do
    local ok, kind, intro, n, exclusive = Call(RL_OFFER, 0)
    if ok ~= true then
      return
    end
    Log("offer", tostring(kind), "choices", Int(n))
    if Int(n) == 0 or not OfferPicks(exclusive) then
      if type(intro) == "string" and intro ~= "" then
        Message(intro)
      end
      for i = 1, Int(n) do
        local can, q, param = Call(RL_OFFER, 1, i)
        if can == true and Ask(WithName(q, param)) then
          local code, text, _, p2 = Call(RL_OFFER, 2, i)
          Log("offer choice", i, "code", Int(code))
          if Int(code) == 0 then
            funcLuaCommand(C.SE, SE_OK)
          end
          if type(text) == "string" and text ~= "" then
            Message(WithName(text, p2))
          end
          if exclusive == true and Int(code) == 0 then
            break
          end
        end
      end
    end
    local _, closing = Call(RL_OFFER, 3)
    if type(closing) == "string" and closing ~= "" then
      Message(closing)
    end
  end
end

-- «Espíritus» before the starter line-up: the collection players whose spirits buy a lower starter cost, as cards of
-- the framework's pick screen (CMND_INAROGUE_RL_SPIRITS: 0 = set the cards, 1 = spend on card i); one level a pick,
-- again until the player skips or nobody can buy more. Nothing shows while nobody can.
local RL_SPIRITS = @crc:CMND_INAROGUE_RL_SPIRITS@
function IRM_SpiritSpend()
  if VRFW_PickCards == nil then
    return
  end
  for _ = 1, 30 do
    if Call(RL_SPIRITS, 0) ~= true then
      return
    end
    local pick = VRFW_PickCards.Show()
    if pick == nil or pick <= 0 then
      return
    end
    local code, text, param = Call(RL_SPIRITS, 1, pick)
    Log("spirits spent on card", pick, "code", Int(code))
    if Int(code) == 0 then
      funcLuaCommand(C.SE, SE_OK)
      if type(text) == "string" and text ~= "" then
        Message(WithName(text, param))
      end
    end
  end
end

-- «Continuar» (§28): the run in progress, straight to its map (no «¿Continuarla?»); with no run the big row reads
-- «Empezar» and starts one at once
local function StartOrContinue()
  if not HasRogueLoader() then
    Message(T(TXT.NO_LOADER_RUN))
    return
  end
  if Call(RL_RUN_INFO) ~= true then
    Log("start: no run in progress, a new one")
    NewRun()
    return
  end
  if IRM_RunOutro() then
    return
  end
  if not DK.Materialise() then
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  IRM_OpenMap()
end

-- «Nueva partida» (§28): starts a new run at once; the only window is the one that protects a run in progress
local function NewGame()
  if not HasRogueLoader() then
    Message(T(TXT.NO_LOADER_RUN))
    return
  end
  local exists, phase = Call(RL_RUN_INFO)
  if exists == true then
    if not Ask(T(RN.ASK, Int(phase))) then
      return
    end
    Log("run abandoned for a new one, code", Int(Call(RL_RUN_ABANDON)))
    run = ReadRun()
    RefreshItems()                -- §30: main label, grid, status
  end
  NewRun()
end

-- the map, and the match it may reserve (result 3): the launch happens here, one level above the map
function IRM_OpenMap()
  while true do
    funcLuaCommand(C.P_CLEAR, KEY_MAP_RESULT)
    OpenChild(MAP_MENU, T(TXT.NO_MAP), function() return Int(Call(P_GET, KEY_MAP_RESULT)) == 4 end)
    local r = Int(Call(P_GET, KEY_MAP_RESULT))
    funcLuaCommand(C.P_CLEAR, KEY_MAP_RESULT)
    if r == 3 then
      IRM_LaunchMatch()
      return
    elseif r ~= 4 or IRM_VsPreview() ~= "map" then
      return                  -- §28: 4 = a match node: the VS screen, then the match, or ("map") the map again
    end
  end
end

-- §28 the VS preview (Nacho's retail «BATALLA HEROICA» screen): the retail Chronicle VS menus opened as children of
-- INAROGUE, like vs_route_town_menu.OpenVsTeamMenu does (enemy formation first, then the VS team menu). The graft
-- rogue_vs switches them to INAROGUE mode while VS.KEY is set: the run's team (the VS dock; its 5v5 for a pachanga)
-- against the node's rival, an INAROGUE / phase title, «Empezar partido» without the retail second question.
-- «Empezar partido» -> the match is reserved in the run file (stage 3) and the dock launches it (request 5);
-- Back -> "map": IRM_OpenMap shows the map again (the node stays in progress: Aceptar on it opens this screen again).
function IRM_VsPreview()
  local stage, node = Call(RL_RESUME)
  node = Int(node)
  if Int(stage) == 0 then
    Log("vs preview: no node in progress")
    return "map"
  end
  for _, k in ipairs({VS.KEY, VS.KEY_RESULT}) do
    funcLuaCommand(C.P_CLEAR, k)
  end
  funcLuaCommand(C.P_SET, VS.KEY, 0, node + 1, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  ShowOwnLayers(false)
  funcLuaCommand(C.OPEN_MENU, VS.ENEMY_MENU)
  funcLuaCommand(C.OPEN_MENU, VS.TEAM_MENU)
  coroutine.yield()
  coroutine.yield()
  local shown = funcLuaMenuCommand(C.EXIST_MENU, VS.TEAM_MENU) == true
  Log("vs preview: node", node, "stage", Int(stage), "open", tostring(shown))
  while funcLuaMenuCommand(C.EXIST_MENU, VS.TEAM_MENU) do
    coroutine.yield()
  end
  if funcLuaMenuCommand(C.EXIST_MENU, VS.ENEMY_MENU) then
    funcLuaCommand(C.CLOSE_MENU, VS.ENEMY_MENU)
  end
  local go = shown and Int(Call(P_GET, VS.KEY_RESULT)) == 1
  for _, k in ipairs({VS.KEY, VS.KEY_RESULT}) do
    funcLuaCommand(C.P_CLEAR, k)
  end
  RestoreOwnLayers()
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  if not shown then
    -- the VS menus did not open (graft or data missing): the match goes the old way, through the pre-match dock
    Log("vs preview missing: the pre-match dock instead")
    local code = Call(RL_RESERVE)
    if Int(code) == 0 then
      IRM_LaunchMatch()
    else
      Message(T(TXT.RUN_ERROR, Int(code)))
    end
    return
  end
  if not go then
    Log("vs preview: back to the map")
    return "map"
  end
  local code, game, diff, stadium, level, rival = Call(RL_RESERVE)
  Log("vs preview: Empezar partido -> reserve code", Int(code), "game", tostring(game), "rival", tostring(rival))
  if Int(code) ~= 0 then
    Message(T(TXT.RUN_ERROR, Int(code)))
    return "map"
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  DK.Open(DK.R_PLAY)          -- the dock opens black and starts the match (rogue_dock); see DK.R_PLAY
end

-- CMND_RESERVE_SOCCER for the match the run file holds (stage 3): the retail VS CPU sequence (roguelite-mode.md
-- §1.2). The result flags are zeroed first; the evt_rl_* trigger writes them during the match. This menu closes with
-- result 8 and the title keeps it closed while the engine starts the match (inarogue_title: EVT_IR_AfterMenu).
-- the rival of a random-team node (InaRogue's pool slot rows): its roster, name, crest and kit are written into the slot
-- team right before the match (VR-Framework random team service, docs/framework/random-team.md §4). Nothing to do for
-- any other rival; never at chunk load.
local RL_RIVAL = @crc:CMND_EVT_RL_RUN_RIVAL@    -- (node) -> rule, seed, nodeKey, stage, slot (nil = not a random team)
local RT_BUILD = @crc:CMND_VRFW_RANDOM_TEAM_BUILD@    -- (rule, seed, node, stage, slot) -> ok, team, level, members, why
function EVT_IR_BuildRival(node)
  local ok, rule, seed, key, stage, slot = pcall(funcLuaCommand, RL_RIVAL, node)
  if not ok or type(rule) ~= "string" or rule == "" then
    return false
  end
  local ok2, built, team, level, members, why = pcall(funcLuaCommand, RT_BUILD, rule, seed, key, stage, slot)
  Log("random rival", rule, "node", tostring(node), "->", tostring(ok2), tostring(built), tostring(team), tostring(members), tostring(why))
  return ok2 and built == 1
end

function IRM_LaunchMatch(from_dock)
  EVT_IR_BuildRival(-1)
  local stage, node, _, _, _, game, diff, stadium, level, rival = Call(RL_RESUME)
  if Int(stage) ~= 3 or type(game) ~= "number" or game == 0 then
    Log("launch refused: no reserved match (stage", Int(stage), ")")
    Message(T(TXT.MATCH_FAIL))
    return
  end
  rival = type(rival) == "string" and rival or "?"
  -- slot 4 (§20 M3): the retail "Plantilla de equipo" is the pre-match screen and launches the match itself (its Back
  -- asks «¿Jugar ya?»): the engine only starts a reserved match when the mode's top menu closes, and the dock is the
  -- top menu the title reserved; this menu is only a child of title_menu_2 (the 28/09 log: "match did not start")
  if SL.rogue then
    Log("match", Int(node), "game", game, "rival", rival, "level", Int(level), "-> the pre-match team dock")
    DK.Open(DK.R_MATCH)
    return
  end
  for _, f in ipairs({MT.F_RESULT, MT.F_GF, MT.F_GA, MT.F_PROBE}) do
    Call(MT.SET_BYTE, f, 0)
  end
  Call(MT.SET_BYTE, MT.F_STATE, 2)
  Log("launch match: node", Int(node), "game", game, "diff", Int(diff), "stadium", tostring(stadium), "level", Int(level), "rival", rival)
  if not SL.rogue then
    Message(T(TXT.MATCH_GO, rival, Int(level)))
  end
  Call(RL_LAUNCH, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  if BrightFadeAllMenu ~= nil then
    pcall(BrightFadeAllMenu, 2721617045 --[[fade_menu_encount]], true)
  end
  Call(MT.PRE_MATCH, game)
  Call(MT.DIFF_HELPER, Int(diff))
  local r = Call(MT.RESERVE, game, Int(stadium), Int(diff))
  Log("RESERVE_SOCCER returned", tostring(r), "- closing INAROGUE (result 8)")
  Close(8)
end

-- §20 M4: a loot roll of the loader -> the INAROGUE save. Gear / moves are game items (retail add + the retail «item
-- get» window, callGetItemDialog); a formation was already granted by the loader (the profile's formation book).
function IRM_GiveLoot(l)
  Log("loot", l.kind, tostring(l.id), l.tier, tostring(l.name))
  if l.kind == 3 then
    Message(T(LT.BOSS))
    Message(T(LT.FORM, tostring(l.name), l.tier, l.owned, l.total))
  elseif (l.kind == 1 or l.kind == 2) and type(l.id) == "number" and l.id ~= 0 then
    Message(T(LT.BOSS))
    if Call(LT.CAN_ADD, l.id, 1) == false then
      Message(T(LT.FULL))
      return
    end
    Call(LT.ADD, l.id, 1)
    RequestSave("boss loot")   -- the item into the INAROGUE save (office save watch, section 19)
    funcLuaCommand(C.SE, SE_OK)
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
    funcLuaCommand(C.MSG_OPEN, LT.ITEM_GET, 11, 0, l.id)
    coroutine.yield()
    while funcLuaCommand(C.MSG_BUSY) do
      coroutine.yield()
    end
    while not funcLuaCommand(C.MSG_DONE) do
      coroutine.yield()
    end
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
    Message(T(l.kind == 1 and LT.USE_GEAR or LT.USE_MOVE))
  end
end

-- back from a match: the hub is not drawn while the node is resolved, so the board is the first screen after the
-- match (a lost run shows the hub again: the run is over)
function IRM_AfterMatchBoard()
  funcLuaMenuCommand(IRW.HIDE_MENU, 1, MENU)
  IRM_AfterMatch()
  funcLuaMenuCommand(IRW.SHOW_MENU, MENU)
end

-- back from a match (the title reopened INAROGUE with the run file at stage 3): the trigger's flags -> the loader
-- resolves the node (win = cleared + fragments; loss = run over; draw / no result = played again), then the map
function IRM_AfterMatch()
  local res, gf, ga, probe = Int(Call(MT.GET_BYTE, MT.F_RESULT)), Int(Call(MT.GET_BYTE, MT.F_GF)),
                             Int(Call(MT.GET_BYTE, MT.F_GA)), Int(Call(MT.GET_BYTE, MT.F_PROBE))
  if res == 0 then   -- no trigger flag: the result the loader recorded at the match's end (run file)
    local rr, rgf, rga = Call(RL_RECORDED)
    if Int(rr) ~= 0 then
      res, gf, ga = Int(rr), Int(rgf), Int(rga)
      Log("after match: recorded result", res)
    end
  end
  Call(RL_LAUNCH, 2)
  Call(MT.SET_BYTE, MT.F_STATE, 1)
  local _, _, _, _, _, game, diff, _, level, rival = Call(RL_RESUME)
  Log("after match: game", tostring(game), "diff", Int(diff), "result flag", res, "self>enemy", gf, "enemy>self", ga, "trigger", probe)
  -- fid .. ftot: the formation this win dropped (§18, loot formations; fid 0 = none, older loaders return nothing)
  local code, outcome, boss, frags, players, fid, fname, frar, fown, ftot = Call(RL_RESULT, res, gf, ga)
  code, outcome, frags = Int(code), Int(outcome), Int(frags)
  Log("result -> code", code, "outcome", outcome, "boss", tostring(boss), "frags", frags, "x", Int(players),
      "formation", tostring(fid), tostring(fname))
  for _, f in ipairs({MT.F_RESULT, MT.F_GF, MT.F_GA, MT.F_PROBE}) do
    Call(MT.SET_BYTE, f, 0)
  end
  if SL.rogue then
    -- §28: the INAROGUE save gets the cleared result bytes / byte 606 at once, so a later reload of slot 4 (a match
    -- clears the engine's «loaded» guard) can never replay this result
    RequestSave("after match")
  end
  if code ~= 0 then
    Message(T(TXT.MATCH_ERROR, code))
    return
  end
  local exists, phase = Call(RL_RUN_INFO)
  if outcome == 4 then
    -- v2: the final boss is beaten (the run waits for its end: endless or the summary)
    IRM_RunOutro()
    return
  end
  if outcome == 1 then
    if boss == true then
      local done = Int(phase)
      -- §20 M4: the boss also gives a random item of the run's loot table (rolled before the phase changes)
      local lk, lid, ltier, lname, lown, ltot = Call(LT.CMD, -1, LT.SALT_BOSS)
      boss_loot = {kind = Int(lk), id = lid, tier = Int(ltier), name = lname, owned = Int(lown), total = Int(ltot)}
      local c3, p2 = Call(RL_NEXT)
      Log("next phase code", Int(c3), "phase", Int(p2))
      Message(T(frags == 1 and TXT.MATCH_WON_BOSS_ONE or TXT.MATCH_WON_BOSS, done, frags))
    else
      Message(T(frags == 1 and TXT.MATCH_WON_ONE or TXT.MATCH_WON, frags))
    end
    if Int(fid) ~= 0 and type(fname) == "string" and fname ~= "" then   -- §18: a loot formation dropped
      Message(T(LT.FORM, fname, Int(frar), Int(fown), Int(ftot)))
    end
    IRM_Offers()                  -- v2: the beaten rival's players, the relic of an Élite / boss
    if boss_loot ~= nil then
      IRM_GiveLoot(boss_loot)
      boss_loot = nil
    end
    if not DK.Materialise(true) then   -- a recruit who joined the team: created in the save before the board
      return
    end
  elseif outcome == 2 then
    Message(T(TXT.MATCH_LOST, Int(phase)))
    ShowSummary()
    Call(MT.SET_BYTE, MT.F_STATE, 0)
    run = ReadRun()
    RefreshItems()                -- §30: main label, grid, status
    return
  else
    Message(T(TXT.MATCH_AGAIN, T(res == 3 and TXT.MATCH_DRAW or TXT.MATCH_NO_RESULT)))
  end
  run = ReadRun()
  IRM_OpenMap()
end
