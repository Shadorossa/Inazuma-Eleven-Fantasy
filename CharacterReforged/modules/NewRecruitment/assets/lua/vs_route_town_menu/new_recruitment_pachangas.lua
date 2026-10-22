-- New Recruitment › the pachanga zones of the Chronicle board (docs/game/mods/new-recruitment-pachangas.md), game Lua of
-- the board (vs_route_town_menu). A zone node is a [[VRFW.NodeMenu]] node (content\node_menus\pachangas.toml): picking
-- it calls NewRecruitment.PachangaNode, which opens the zone's pachanga list (NewRecruitment.PachangaMenu.Open: the
-- framework's pose row screen, content\pose_rows\pachangas.toml); choosing a pachanga plays it
-- (NewRecruitment.PachangaBoard.Play): a 5v5 friendly of the framework's match start service (friendly
-- new_recruitment_pachanga, the rival team and the zone's stadium given), back on the board afterwards. Every rival
-- player has a mini-challenge, followed by scripts\pachangas.lua from the match events; back on the board the players
-- whose challenge was met and whom the club does not have come up together in ONE join scene
-- (NewRecruitment.PachangaJoinScene): each one asks in turn, Sí / No, and joins on Sí (VRFW_Recruit.Recruit, the shared
-- grant: rarity 4, one copy per character).
-- Handlers of the framework's board host (VRFW_Host) and globals only: nothing runs at load but their registration.
if VRFW_Host ~= nil then
  NewRecruitment = NewRecruitment or {}
  local B = {
    STEM = "vs_route_town_menu",
    SETTLE = "new_recruitment.pachanga_settle",
    ZONE = 250788586,               -- CMND_NEWRECRUITMENT_PACHANGA_ZONE (node) -> zone, title, stadium, count
    GET = 892045752,                -- CMND_NEWRECRUITMENT_PACHANGA_GET (zone, i) -> key, team, name, level, format, challenge, won, n, cards…
    ARM = 1347344732,               -- CMND_NEWRECRUITMENT_PACHANGA_ARM (key)
    RESULT = 3867180771,            -- CMND_NEWRECRUITMENT_PACHANGA_RESULT () -> key, won, for, against
    SET_WON = 3089891437,           -- CMND_NEWRECRUITMENT_PACHANGA_SET_WON (key)
    SET_MET = 2920298299,           -- CMND_NEWRECRUITMENT_PACHANGA_SET_MET (card)
    FRIENDLY = "new_recruitment_pachanga",
    GAME = 2372839589,              -- sbtl_rojiura_01: a retail 5v5 match row (game type 2: the stadiums' 5v5 lines)
    MENU = "new_recruitment.pachangas",   -- the pose row (content\pose_rows\pachangas.toml)
    -- the board's own chrome hidden while the list is up (its footer and the piece's title banner)
    -- the board's chrome and pieces hidden while the list is up (the list is drawn over the board's map: its pieces,
    -- locks, icons and roads would show over the side panel's 3D models)
    HIDE = {1423637364 --[[rpg00_05_menu_button_guide]], 139522149 --[[vsroute02_03_gametitle]],
            4002479583 --[[vsroute00_05_town_map_piece]], 1632548965 --[[vsroute00_07_town_map_piece_atc_chara]],
            1617793781 --[[vsroute01_09_town_map_piece_lock_front]], 3060354640 --[[vsroute01_09b_town_map_piece_lock_back]],
            2638032167 --[[vsroute01_06c_town_map_piece_clear_icon]], 907932950 --[[vsroute01_07c_gate_key_icon]],
            1225175571 --[[vsroute01_07_obtain_gate_key_icon]], 57708379 --[[vsroute01_07b_gate_keyhole_icon]],
            3325939278 --[[vsroute01_08_destination_icon]], 3905678584 --[[vsroute00_03_area_name_plate]],
            3860387247 --[[vsroute_zoom_guide]], 1635409244 --[[vsroute_p1_area_zoom_guide]],
            922325769 --[[vrfw_route_road]], 2296367164 --[[cmn05_01_cursor]]},
    LINEUP = 949268794,             -- CMND_NEWRECRUITMENT_PACHANGA_LINEUP (key) -> the cards who play its next match
    TEAM_LINEUP = 91345181,         -- CMND_VRFW_TEAM_LINEUP (team, card…): those cards take roster slots 0..
    BASE = 1856865420,              -- CMND_NEWRECRUITMENT_PACHANGA_BASE (team level): the levels scale from it
    LEVEL = 2140236644,             -- CMND_NEWRECRUITMENT_PACHANGA_LEVEL (key) -> its level now, the row level
    TEAM_LEVEL = 1113889537,        -- CMND_VRFW_TEAM_LEVEL (team, row level, level): the team plays at that level
    TEAM_DOCK = 937147172,          -- soccer_team_dock_menu (the list's Y «Plantilla de equipo»)
    -- the board's caravan (the background layer's menu model, slot 0) hidden while the list is up
    MODELS = {{1021315501 --[[vsroute00_00_background]], 0}},
    pending = nil,                  -- {key, cards, level, won} of a played pachanga, settled once the board is idle
    co = nil,                       -- the join scene's coroutine (resumed by the settle handler)
  }
  NewRecruitment.PachangaBoard = B

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  function B.Log(...)
    if PRINT ~= nil then pcall(PRINT, "NR_PACHANGA", ...) end
  end

  -- a zone of a node: {index, title, stadium, list = {{key, team, name, level, format, challenge, won, cards}…}}
  function B.Zone(node)
    local zi, title, stadium, n = call(B.ZONE, node)
    if type(zi) ~= "number" then return nil end
    local zone = {index = zi, node = node, title = title or 0, stadium = stadium or 0, list = {}}
    for i = 1, n or 0 do
      local r = table.pack(call(B.GET, zi, i))
      if r[1] ~= nil then
        zone.list[#zone.list + 1] = {key = r[1], team = r[2], name = r[3], level = r[4], format = r[5],
                                     challenge = r[6], won = r[7] == true, cards = {table.unpack(r, 9, 8 + (r[8] or 0))}}
      end
    end
    return zone
  end

  -- start pachanga `p` of `zone` (B.Zone) from the board: true, or false + why
  function B.Play(zone, p)
    if VRFW_MATCH == nil or VRFW_MATCH.start == nil then return false, "no match start service" end
    -- this entry's lineup (the rotation) takes the rival team's first roster slots, then the match is armed (the
    -- rotation turns)
    local lineup = table.pack(call(B.LINEUP, p.key))
    if lineup.n > 0 and lineup[1] ~= nil then
      local ok, why = call(B.TEAM_LINEUP, p.team, table.unpack(lineup, 1, lineup.n))
      B.Log("lineup", p.key, lineup.n, tostring(ok), tostring(why))
    end
    -- its level (the player's team level + the pachanga's offset): the rival's members' offsets over the row level
    local lv, row = call(B.LEVEL, p.key)
    if type(lv) == "number" and type(row) == "number" and row >= 1 then
      local okl, whyl = call(B.TEAM_LEVEL, p.team, row, lv)
      B.Log("level", p.key, lv, "row", row, tostring(okl), tostring(whyl))
    end
    if call(B.ARM, p.key) ~= true then return false, "unknown pachanga" end
    B.Log("play", p.key, "team", p.team, "stadium", zone.stadium)
    return VRFW_MATCH.start{
      friendly = B.FRIENDLY, game = B.GAME, difficulty = 1,
      stadium = (zone.stadium ~= 0) and zone.stadium or nil, rival = p.team,
      overrides = {{"teams.rival.team", p.team}}, play_mode = 1, black = false,
      on_failed = function(why) B.Log("start failed", p.key, tostring(why)) end,
    }
  end

  -- the played pachanga settled once the board is idle: every met challenge saved; the players the club does not have
  -- come up in the join scene (a coroutine resumed here until it ends)
  function B.Settle()
    if B.co ~= nil then
      local ok, err = coroutine.resume(B.co)
      if not ok then
        B.Log("join scene error", tostring(err))
      end
      if not ok or coroutine.status(B.co) == "dead" then
        B.co = nil
        pcall(VRFW_Host.off, B.STEM, "PreStep", B.SETTLE)
      end
      return
    end
    local p = B.pending
    if p == nil then
      pcall(VRFW_Host.off, B.STEM, "PreStep", B.SETTLE)
      return
    end
    local L = VRFW_RB and VRFW_RB.L
    if L ~= nil and L.n21 ~= 0 then return end            -- the board is busy (a result, an event): next frame
    B.pending = nil
    local joiners = {}
    for _, card in ipairs(p.cards) do
      call(B.SET_MET, card)
      if VRFW_Recruit ~= nil and VRFW_Recruit.CanSign(card) == true then
        joiners[#joiners + 1] = card
      end
    end
    if p.won then call(B.SET_WON, p.key) end
    if #joiners == 0 then
      pcall(VRFW_Host.off, B.STEM, "PreStep", B.SETTLE)
      return
    end
    B.co = coroutine.create(function() NewRecruitment.PachangaJoinScene(p, joiners) end)
  end

  -- back on the board: the last armed pachanga's result (read once); settled once the board is idle
  VRFW_Host.on(B.STEM, "OnInit", {
    id = "new_recruitment.pachanga_result", phase = "after",
    fn = function()
      local r = table.pack(call(B.RESULT))
      local key, won = r[1], r[2]
      if key == nil then return end
      B.Log("result", key, won == true and "won" or "not won", r[3], r[4], "challenges met", r[6] or 0)
      B.pending = {key = key, won = won == true, level = r[5] or 1, cards = {table.unpack(r, 7, 6 + (r[6] or 0))}}
      if #B.pending.cards == 0 and not B.pending.won then B.pending = nil return end
      VRFW_Host.on(B.STEM, "PreStep", {id = B.SETTLE, phase = "after", fn = function() B.Settle() end})
    end,
  })
end

NewRecruitment = NewRecruitment or {}

-- the zone's pachanga list (the framework's pose row screen, waited for in the board's coroutine); a pick plays it
NewRecruitment.PachangaMenu = NewRecruitment.PachangaMenu or {}
function NewRecruitment.PachangaMenu.Open(zone)
  local B = NewRecruitment.PachangaBoard
  if VRFW_PoseRow == nil or #zone.list == 0 then
    return false
  end
  -- the levels scale with the player's active team (zone_rules.toml [level])
  if VRFW_Recruit ~= nil and VRFW_Recruit.TeamLevel ~= nil then
    pcall(funcLuaCommand, B.BASE, VRFW_Recruit.TeamLevel())
  end
  local pick
  while true do
    pick = VRFW_PoseRow.Open(B.MENU, zone.index, {hide = B.HIDE, models = B.MODELS})
    if pick == nil then
      return false                   -- never shown: the piece's command menu opens as usual
    end
    if pick ~= -1 then
      break
    end
    -- Y «Plantilla de equipo»: the team dock as the retail command menu opens it, then the list again
    pcall(funcLuaMenuCommand, 879521569 --[[CMND_SET_ENABLE_FREE_CURSOR_FOR_VIRTUAL_MOUSE]], false)
    pcall(funcLuaMenuCommand, 1524491681, 10)
    if OpenKizunaMainMenu == nil then
      break
    end
    OpenKizunaMainMenu(B.TEAM_DOCK)
    coroutine.yield()
    while funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], B.TEAM_DOCK) == true do
      coroutine.yield()
    end
    coroutine.yield()
  end
  local p = zone.list[pick]
  if p ~= nil then
    local ok, why = B.Play(zone, p)
    if ok ~= true then B.Log("play", p.key, "refused", tostring(why)) end
  end
  return true
end

-- the join scene (docs/game/mods/new-recruitment-pachangas.md §9): the joiners (1..5) walk up to your captain
-- together, then each one in turn asks, «¿Te parece bien?» Sí / No (No: «¿Quieres rechazar a X?»), and on Sí he joins.
-- Talks: the module's templates (content\talk_templates\, research/scripts/new_recruitment_join_templates.py) built
-- with this play's characters (CMND_VRFW_TALK_CAST) and played as the board's bust-up talks. A missing piece (no
-- captain, a build error): no talk, the questions and the notice only.
local J = {
  CAST = 2717973849 --[[CMND_VRFW_TALK_CAST]], BASE = 413729894 --[[CMND_VRFW_CHARA_BASE]],
  LIVE_TALK = 171173157 --[[CMND_VRFW_ANIM_LIVE_TALK]], NAMES = 3517017366 --[[CMND_VRFW_POSE_ROW_CARDS]],
  LANG = 477234096 --[[CMND_GET_LANGUAGE_CODE]], TEXT = 4074371074 --[[CMND_TEXT_GET]],
  RESERVE = 822852817 --[[CMND_RESERVE_EVENT]], EVENT = 3555468931 --[[crc32("bustup_talk_vs_route")]],
  NAME = 734285930 --[[(reservation, talk name)]], MODE = 759236289 --[[(reservation, 1 = a plain talk)]],
  RUN = 398423575 --[[CMND_IS_RUN_EVENT]], SKIP = 2872569508 --[[CMND_EVENT_SKIP (menu command)]],
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  K_ASK = 3376716705 --[[new_recruitment_pachangas_join_ask]], K_REJECT = 1090898220 --[[_join_reject]],
  K_DONE = 290976732 --[[_join_done]],
  PREFIX = "new_recruitment.pachanga_",
  ROUNDS = 5,           -- «No» then «No» (do not reject) asks again, at most this many times
  INDEX_WAIT = 600,     -- frames the talk index may take
  START_WAIT = 60,      -- frames for the reserved talk to start
  LINE_MAX = 900,       -- frames per template line before the guard skips the talk (a stuck talk never freezes)
}
NewRecruitment.PachangaJoin = J

local function jcall(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then return nil end
  return table.unpack(r, 2, r.n)
end

local function hex(v)
  return string.format("0x%08X", v % 4294967296)
end

local function text(id)
  local s = jcall(J.TEXT, id)
  return type(s) == "string" and s or ""
end

-- a Sí / No question (the game's question window); true = «Sí»
local function ask(s)
  jcall(J.MSG_OPEN, s, 0, 0, 0, 0, 0, false)
  jcall(J.MSG_KIND, 2, 0)
  coroutine.yield()
  local r = -1
  while r == nil or r < 0 do
    r = jcall(J.MSG_RESULT)
    coroutine.yield()
  end
  while jcall(J.MSG_DONE) ~= true do
    coroutine.yield()
  end
  return r == 0
end

local function notice(s)
  jcall(J.MSG_OPEN, s, 0, 0, 0, 0, 0, false)
  jcall(J.MSG_KIND, 1, 0)
  coroutine.yield()
  while jcall(J.MSG_BUSY) == true do
    coroutine.yield()
  end
  while jcall(J.MSG_DONE) ~= true do
    coroutine.yield()
  end
end

local function fmt(id, name)
  local ok, s = pcall(string.format, text(id), name)
  return ok and s or name
end

-- a built talk played as the board's bust-up talk (the retail RunBustupTalkEvent sequence); true when it ran
local function play(id, ch, lines)
  local B = NewRecruitment.PachangaBoard
  local t = 0
  while t < J.INDEX_WAIT and jcall(J.LIVE_TALK, "index") ~= true do
    t = t + 1
    coroutine.yield()
  end
  local prepped, why = jcall(J.LIVE_TALK, "prep", ch, id)
  if prepped ~= true then
    B.Log("join talk", id, "prep failed", tostring(why))
    return false
  end
  local h = jcall(J.RESERVE, J.EVENT)
  if type(h) ~= "number" or h <= 0 then
    B.Log("join talk", id, "reserve failed", tostring(h))
    return false
  end
  jcall(J.NAME, h, id)
  jcall(J.MODE, h, 1)
  local ran, skipped, cap = false, false, J.LINE_MAX * math.max(1, lines or 1)
  t = 0
  while t < cap + 600 do
    coroutine.yield()
    t = t + 1
    if jcall(J.RUN, h) == true then
      ran = true
      if t > cap and not skipped then
        skipped = true                           -- the guard: a talk that never ends is skipped, once
        pcall(funcLuaMenuCommand, J.SKIP)
        B.Log("join talk", id, "still running after", t, "frames: skipped")
      end
    elseif ran or t > J.START_WAIT then
      break
    end
  end
  return ran
end

-- one template with the scene's cast; `asker` = the joiner who asks (1..n), nil for the arrival
local function talk(scene, template, asker)
  if scene == nil then
    return false
  end
  local args = {J.PREFIX .. template, "captain", hex(scene.captain)}
  for k, b in ipairs(scene.bases) do
    args[#args + 1], args[#args + 2] = "joiner" .. k, hex(b)
  end
  if asker ~= nil then
    args[#args + 1], args[#args + 2] = "asker", "joiner" .. asker
    local slot = 2
    for k = 1, #scene.bases do
      args[#args + 1] = "slot_joiner" .. k
      if k == asker then
        args[#args + 1] = "1"
      else
        args[#args + 1] = tostring(slot)
        slot = slot + 1
      end
    end
  end
  local ok, id, ch, lines = jcall(J.CAST, table.unpack(args))
  NewRecruitment.PachangaBoard.Log("join talk", template, asker or 0, "built", tostring(ok), tostring(id))
  if ok ~= true or type(id) ~= "string" or type(ch) ~= "number" then
    return false
  end
  return play(id, ch, lines)
end

-- p = the played pachanga {key, level, …}, cards = the joiners (cards the club does not have, 1..5)
function NewRecruitment.PachangaJoinScene(p, cards)
  local B = NewRecruitment.PachangaBoard
  local n = math.min(#cards, 5)
  local names = jcall(J.NAMES, jcall(J.LANG) or 0, table.unpack(cards, 1, n))
  local scene = {bases = {}}
  local cap = VRFW_Team ~= nil and (VRFW_Team.Captain(1) or VRFW_Team.Captain(0)) or nil
  scene.captain = cap and jcall(J.BASE, cap) or nil
  for k = 1, n do
    scene.bases[k] = jcall(J.BASE, cards[k])
    if type(scene.bases[k]) ~= "number" or scene.bases[k] == 0 then
      scene.captain = nil
    end
  end
  if type(scene.captain) ~= "number" or scene.captain == 0 then
    B.Log("join scene: no captain or joiner chara_base: questions only")
    scene = nil
  end
  if n == 1 then
    talk(scene, "join_1")
  else
    talk(scene, "arrive_" .. n)
  end
  local joined = 0
  for k = 1, n do
    local card = cards[k]
    local name = type(names) == "table" and type(names[k]) == "table" and names[k].name or ""
    if n > 1 then
      talk(scene, "ask_" .. n, k)
    end
    local yes = false
    for _ = 1, J.ROUNDS do
      if ask(fmt(J.K_ASK, name)) then
        yes = true
        break
      end
      talk(scene, "wait_" .. n, k)
      if ask(fmt(J.K_REJECT, name)) then
        break
      end
    end
    if yes then
      talk(scene, "yes_" .. n, k)
      local ok, why = VRFW_Recruit.Recruit{param = card, level = p.level}   -- the shared grant (rarity 4)
      B.Log("recruit", p.key, card, ok == true and "joined" or tostring(why))
      if ok == true then
        joined = joined + 1
        notice(fmt(J.K_DONE, name))
      end
    else
      talk(scene, "no_" .. n, k)
      B.Log("recruit refused", p.key, card)
    end
  end
  B.joined = {key = p.key, count = joined}
end

-- [[VRFW.NodeMenu]] handler (content\node_menus\pachangas.toml): a zone node was picked on the board
function NewRecruitment.PachangaNode(idx, node, key)
  local B = NewRecruitment.PachangaBoard
  if B == nil then
    return false
  end
  local zone = B.Zone(node)
  if zone == nil then
    B.Log("node", node, "has no zone")
    return false
  end
  return NewRecruitment.PachangaMenu.Open(zone) == true
end
