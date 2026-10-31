-- BattleBayDeluxe bb_tournament, top menu part: the league's career hub.
-- Appended after bbt_top.lua in graft.toml's order: the parts share one chunk and its locals.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

-- ------------------------------------------------------------------------------------------------ the league hub

-- 1.48.0 (owner 2026-10-28): the league's CAREER HUB, shown when the league starts, when it is entered and after every
-- matchday's results. 1.52.0 (owner 2026-10-28, mock-up C): a career dashboard drawn whole by the group stage's menu
-- (CMND_BBD_TOURN_VIEW kind "hub": evt_bbd_tn_groups_menu.lua DrawHub): a blue side menu with the sections «Inicio»
-- (Enter = «Jugar»: the tournament's own next-match request; back here after its results), «Calendario» (every
-- matchday, one a page, the results played and the fixtures to come; L1 / R1), «Competición» (the standings pages and
-- the top scorers; L1 / R1), «Plantilla» (the game's team dock, soccer_team_dock_menu, opened over this menu; back here
-- when it closes); «Nueva liga» (Yes / No, then the team grid; 1.58.0: a side menu row, no X key), Back = «Salir» (the league stays saved). Enter /
-- Back on a section's page = the hub again. 1.61.0: «Plantilla» opens the game's team dock for the league team
-- (BBT_HubTeamEditor); the squad page below stays for the Draft team and when the dock cannot open.
-- 1.53.0 (owner 2026-10-29): «Plantilla» is the league team's squad page in the overlay (the team the
-- player chose for this league, its members as the league plays them: view kind "squad"), not the game's team dock
-- (it showed the player's own dock squad under the Battle Bay menu's texts). The keys are the overlay anchor's rows (content\menus\bb_tournament.toml:
-- Up / Down / L1 / R1 move the side menu, X, a left click), each an event (OnDecideFocus / OnBack / OnFunction) that
-- sets the action the hub's coroutine waits for; the side menu's cursor goes to the drawing menu through the
-- parameter evt_bbd_lg_nav. The mouse / free cursor: the shared pointer helper (BBT_HubPointerStep) on the zones the
-- drawing menu sends after each hub drawing (BBT_HubZones): hover moves the focus, a left click decides.
BattleBayDeluxe.Tournament.HUB = {
  PAGE = 9,                     -- scripts/lib/tourney_view.lua V.HUB
  -- Enter on the side menu's row k; 1.58.0: «Inicio» moves the focus into the dashboard, «Nueva liga» and «Salir» are
  -- rows 4 / 5 (no X key)
  NAV = { "dashboard", "calendar", "competition", "roster", "new", "exit" },
  P_NAV = @crc:evt_bbd_lg_nav@,
  -- 1.58.0: the dashboard's focus (0 = the side menu, k = PANELS[k]) to the drawing menu
  P_FOCUS = @crc:evt_bbd_lg_focus@,
  FN_UP = @crc:evt_bbd_lg_up@,
  FN_DOWN = @crc:evt_bbd_lg_down@,
  FN_LEFT = @crc:evt_bbd_lg_left@,
  FN_RIGHT = @crc:evt_bbd_lg_right@,
  -- 1.58.0 (owner 2026-10-29): the dashboard's panels (evt_bbd_tn_groups_menu.lua DrawHub's order), the action Enter
  -- or a click takes on each, and the panel each direction moves to (their 2D layout; 0 = back to the side menu)
  PANELS = {
    { act = "play", right = 2, down = 3, left = 0 },              -- next match
    { act = "competition", left = 1, down = 5 },                  -- standings
    { act = "scorers", up = 1, right = 4, down = 6, left = 0 },   -- top scorers
    { act = "results", up = 1, left = 3, right = 5, down = 6 },   -- last results
    { act = "roster", up = 2, left = 4, down = 6 },               -- squad
    { act = "calendar", up = 4, left = 0 },                       -- calendar
  },
  SCORERS_PAGE = 19,            -- scripts/lib/tourney_view.lua V.SCORERS
  CALENDAR_PAGE = 100, CAL_HALVES = 2,   -- V.CALENDAR, V.CAL_HALVES
  -- 1.70.0: the calendar section's matchday grid (the view's fixtures_page / fixtures_md / cards / cols / page_count):
  -- the focused matchday to the drawing menu
  P_CAL_MD = @crc:evt_bbd_lg_cal_md@,
  FIXTURES_FIRST = 90,          -- V.FIXTURES: the grid's first page
  -- the anchor's left-click row (content\menus\bb_tournament.toml): taken and ignored, the pointer helper owns clicks
  FN_CLICK = @crc:evt_bbd_lg_click@,
  GUIDE = 1138543975 --[[mainmenu01_06_base_button_guide]],
  SQUAD_PAGE = 8,               -- scripts/lib/tourney_view.lua V.SQUAD
  -- 1.61.0: the league team in the game's team dock (BBT_HubTeamEditor)
  SQUAD_GET = @crc:CMND_BBD_LEAGUE_SQUAD@,
  SQUAD_SET = @crc:CMND_BBD_LEAGUE_SQUAD_SET@,
  TEAM_INFO = 2151743654,       -- (team, 2) -> _, the team's name
}

-- 1.61.0 (owner 2026-10-29): «Plantilla» opens the game's own team dock for the team the player uses in this league
-- (VRFW_TeamEditor: a temporary copy of the team in the dock inside a save session that is undone when it closes, so
-- the player's own teams and save never change). The order and formation left there go to the run
-- (CMND_BBD_LEAGUE_SQUAD_SET, scripts\league_squad.lua) and are played from the next league match on. The Active team
-- tile opens the player's own dock as it is (that team is the one it plays). false = no dock (the Draft team, the
-- framework's editor missing or refused): the caller shows the read-only squad page.
function BBT_HubTeamEditor()
  local H = BattleBayDeluxe.Tournament.HUB
  if type(VRFW_TeamEditor) ~= "table" then
    BBT_Log("hub: no VRFW_TeamEditor (VRFW < 2.226.0): the squad page")
    return false
  end
  local sq = BBT_Call(H.SQUAD_GET)
  if type(sq) ~= "table" or not sq.ok then
    BBT_Log("hub: league squad not read:", type(sq) == "table" and tostring(sq.why) or "no answer")
    return false
  end
  if sq.kind == "draft" then
    BBT_Log("hub: the Draft team keeps its drafted order: the squad page")
    return false
  end
  if sq.kind ~= "own" then
    local can, why = VRFW_TeamEditor.CanOpen()
    if not can then
      BBT_Log("hub: team editor refused:", why)
      return false
    end
  end
  local okn, _, name = pcall(funcLuaCommand, H.TEAM_INFO, sq.team, 2)
  BBT_Close()
  -- 1.63.0 (owner in game 2026-10-29: «Campaña», «SIGUIENTE», «Ayuda», the BB logo drawn over the dock): the top menu's
  -- own layers stay closed / hidden while the dock is up, exactly as under the overlay (BBT_Open); the button guide
  -- layer stays (the dock writes its guide there). BBT_Open puts them right again afterwards.
  BBT_SwitchLayers(BattleBayDeluxe.TournamentHost.close, false)
  BBT_ShowLayers(BattleBayDeluxe.TournamentHost.hide, false)
  BBT_BgLogo(false)
  for _, l in ipairs(BattleBayDeluxe.TournamentHost.lists or {}) do
    funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, l, false)
  end
  -- 1.92.0 (owner 2026-10-31: a plain grey screen under the dock): no hub band under the dock; the framework's editor
  -- gives the dock the retail team screen background on this menu (BBT_Open places the band again for the hub)
  -- 1.67.0 (owner 2026-10-29): a league team is not one of the player's: the editor's foreign team mode (its own
  -- coach, kit, emblem, tactics, synergies and stadium; no bank, no team switching, no active team; no coach = an
  -- empty coach place)
  local own = sq.kind == "own"
  local res, why = VRFW_TeamEditor.Run({
    owner = "BattleBayDeluxe", host = BattleBayDeluxe.TournamentHost.menu, own = own, foreign = not own, members = sq.members,
    formation = sq.formation, level = sq.level, emblem = sq.emblem, name = okn and type(name) == "string" and name or nil,
    coach = sq.coach, kit = sq.kit, tactics = sq.tactics, synergies = sq.synergies, stadium = sq.stadium,
    -- 1.69.0 (owner 2026-10-29): the list offers the lineup, «Vínculo de Afinidad» and «Comandos de hipertécnicas»
    rows = (VRFW_TeamEditor.ROW ~= nil) and { VRFW_TeamEditor.ROW.LINEUP, VRFW_TeamEditor.ROW.BONDS,
      VRFW_TeamEditor.ROW.HYPER_COMMANDS } or nil,
  })
  -- 1.67.0 (owner 2026-10-29: «Al regresar se queda así», an empty screen under the dock's guide): the card ids are
  -- unsigned 32-bit, past the range of this Lua's "%d" (loader.log: «bad argument #3 to 'format' (not a number in
  -- proper range)»), so the hub was never opened again after the dock closed. The ids go out as "%.0f", and whatever
  -- the order's write does, the hub opens again as soon as the editor returns.
  local okw, saved = pcall(function()
    if res and not res.own then
      local parts = {}
      for _, m in ipairs(res.members or {}) do
        parts[#parts + 1] = string.format("%.0f:%.0f", m[1], m[2])
      end
      local r = BBT_Call(H.SQUAD_SET, res.formation or 0, table.concat(parts, ","))
      local kept = type(r) == "table" and r.ok == true
      BBT_Log("hub: league lineup from the dock:", #parts, "players,", res.foreign or 0, "club players, kept",
        tostring(kept), type(r) == "table" and tostring(r.why or "") or "no answer")
      return kept
    elseif not res then
      -- nothing to keep (the dock did not open, the session was refused): the log says why, no message
      BBT_Log("hub: team editor:", tostring(why))
    end
    return true
  end)
  if not okw then
    BBT_Log("hub: league lineup not kept:", tostring(saved))
    saved = false
  end
  for _, l in ipairs(BattleBayDeluxe.TournamentHost.lists or {}) do
    funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, l, true)
  end
  BBT_Open(H.PAGE)
  if not saved and BattleBayDeluxe.TournamentState.open then
    BBT_Window(BBT_Id("squad_not_saved"), 1)
  end
  return true
end

-- the side menu's cursor and the dashboard's focus to the drawing menu
function BBT_HubNavParam()
  VRFW_Param.Clear(BattleBayDeluxe.Tournament.HUB.P_NAV)
  VRFW_Param.Set(BattleBayDeluxe.Tournament.HUB.P_NAV, BattleBayDeluxe.TournamentState.hub_nav or 0)
  VRFW_Param.Clear(BattleBayDeluxe.Tournament.HUB.P_FOCUS)
  VRFW_Param.Set(BattleBayDeluxe.Tournament.HUB.P_FOCUS, BattleBayDeluxe.TournamentState.hub_focus or 0)
end

-- the dashboard's focus to panel k (0 = back to the side menu), the dashboard drawn again; silent = no move sound
function BBT_HubFocus(k, silent)
  BattleBayDeluxe.TournamentState.hub_focus = (k or 0) > 0 and k or nil
  BBT_HubNavParam()
  if not silent then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2456713098 --[[sy0001]])
  end
  BBT_GroupsShow(BattleBayDeluxe.Tournament.HUB.PAGE)
end

-- the side menu's cursor moved by d (wraps), the dashboard drawn again; silent = no move sound
function BBT_HubMove(d, silent)
  local n = #BattleBayDeluxe.Tournament.HUB.NAV
  BattleBayDeluxe.TournamentState.hub_nav = ((BattleBayDeluxe.TournamentState.hub_nav or 0) + d) % n
  BBT_HubNavParam()
  if not silent then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2456713098 --[[sy0001]])
  end
  BBT_GroupsShow(BattleBayDeluxe.Tournament.HUB.PAGE)
end

-- ---- mouse / free cursor (evt_menu_kit.lua#Pointer, docs/game/ui/mouse-support.md §5)
--@lib evt_menu_kit.lua#Pointer

-- the hub's pointer zones, sent by the drawing menu after each hub drawing (evt_bbd_tn_groups_menu.lua DrawHub, a
-- cross-menu call): "n,<side menu row>,x0,y0,x1,y1;p,<panel>,x0,y0,x1,y1;..." in screen px (y down), from the quads it
-- drew ("c,<matchday>,…": a card of the calendar grid, DrawFixtures); the last one wins where they overlap
function BBT_HubZones(s)
  local zones = {}
  for kind, n, x0, y0, x1, y1 in tostring(s or ""):gmatch("(%a),(%d+),([%d.-]+),([%d.-]+),([%d.-]+),([%d.-]+)") do
    zones[#zones + 1] = { tonumber(x0), tonumber(y0), tonumber(x1), tonumber(y1),
      nav = kind == "n" and tonumber(n) or nil, panel = kind == "p" and tonumber(n) or nil,
      md = kind == "c" and tonumber(n) or nil }
  end
  BattleBayDeluxe.TournamentState.hub_zones = zones
end

-- the zone z focused as the keys would focus it: a side menu row (the dashboard's focus off), a dashboard panel or a
-- card of the calendar grid; silent = a click (its decide sound follows), not a hover
function BBT_HubPointTo(z, silent)
  if z.md ~= nil then
    BBT_HubCalFocus(z.md, silent)
  elseif z.panel ~= nil then
    if BattleBayDeluxe.TournamentState.hub_focus ~= z.panel then
      BBT_HubFocus(z.panel, silent)
    end
  elseif BattleBayDeluxe.TournamentState.hub_focus ~= nil or (BattleBayDeluxe.TournamentState.hub_nav or 0) ~= z.nav then
    BattleBayDeluxe.TournamentState.hub_focus = nil
    BBT_HubMove(z.nav - (BattleBayDeluxe.TournamentState.hub_nav or 0), silent)
  end
end

-- every Step: while the dashboard or the calendar grid waits for its action, hover by movement focuses the element
-- under the pointer and a click decides it (the same action as Enter on it), the wheel turns the grid's pages; idle
-- otherwise (a press held from a page before is no click)
function BBT_HubPointerStep()
  local S = BattleBayDeluxe.TournamentState
  local grid = S.cal_wait == true and S.cal_act == nil
  if not (S.open and ((S.hub_wait and S.hub_act == nil) or grid)) or S.hub_zones == nil then
    S.hub_ptr_idle = true
    return
  end
  local P = S.hub_ptr
  if P == nil then
    P = EVT_PointerNew()
    S.hub_ptr = P
    S.hub_ptr_idle = true
  end
  if S.hub_ptr_idle then
    S.hub_ptr_idle = false
    P.Reset()
  end
  P.Begin()
  for k, z in ipairs(S.hub_zones) do
    P.Rect(z[1], z[2], z[3] - z[1], z[4] - z[2], k)
  end
  local ev = P.Poll()
  if grid and ev.wheel ~= nil then
    BBT_HubCalTurn(ev.wheel)
    return
  end
  local k = ev.click or ev.hover
  local z = k and S.hub_zones[k]
  if z == nil or (grid and z.md == nil) or (not grid and z.md ~= nil) then
    return
  end
  BBT_HubPointTo(z, ev.click ~= nil)
  if ev.click ~= nil then
    if grid then
      S.cal_act = "open"
    else
      S.hub_act = z.panel ~= nil and BattleBayDeluxe.Tournament.HUB.PANELS[z.panel].act or BattleBayDeluxe.Tournament.HUB.NAV[z.nav + 1]
    end
  end
end

-- the hub's own key events (OnDecideFocus / OnBack / OnFunction while it waits): true = taken
function BBT_HubKey(kind, fn)
  if not BattleBayDeluxe.TournamentState.hub_wait then
    return false
  end
  local H = BattleBayDeluxe.Tournament.HUB
  local P = BattleBayDeluxe.TournamentState.hub_ptr
  -- the mouse: its left-click row and an engine Accept that is a pointer click belong to BBT_HubPointerStep
  if fn == H.FN_CLICK or (kind == "enter" and P ~= nil and P.Owns()) then
    return true
  end
  -- a key moves the focus: the pad owns it until the pointer really moves again
  if P ~= nil and kind == "function" then
    P.KeyStep()
  end
  -- 1.58.0: the focus inside the dashboard: the directions follow the panels' layout, Enter = the panel's action,
  -- Back = the side menu again
  local p = BattleBayDeluxe.TournamentState.hub_focus and H.PANELS[BattleBayDeluxe.TournamentState.hub_focus]
  if p then
    if kind == "enter" then
      BattleBayDeluxe.TournamentState.hub_act = p.act
    elseif kind == "back" then
      BBT_HubFocus(0)
    else
      local dir = (fn == H.FN_UP and "up") or (fn == H.FN_DOWN and "down") or (fn == H.FN_LEFT and "left")
        or (fn == H.FN_RIGHT and "right") or nil
      local to = dir and p[dir]
      if to ~= nil then
        BBT_HubFocus(to)
      end
    end
    return true
  end
  if kind == "enter" then
    BattleBayDeluxe.TournamentState.hub_act = H.NAV[(BattleBayDeluxe.TournamentState.hub_nav or 0) + 1]
  elseif kind == "back" then
    BattleBayDeluxe.TournamentState.hub_act = "exit"
  elseif fn == H.FN_RIGHT and (BattleBayDeluxe.TournamentState.hub_nav or 0) == 0 then
    BBT_HubFocus(1)
  elseif fn == H.FN_UP or fn == BattleBayDeluxe.Tournament.FN_PREV then
    BBT_HubMove(-1)
  elseif fn == H.FN_DOWN or fn == BattleBayDeluxe.Tournament.FN_NEXT then
    BBT_HubMove(1)
  end
  return true
end

-- the footer while the dashboard waits: Accept, «Salir» (Back); a click on an entry is its key (1.58.0: «Nueva liga»
-- is a side menu row, no X entry).
-- Off: the overlay's own footer (Accept only)
function BBT_HubGuide(on)
  if BattleBayDeluxe.TournamentHost.name ~= "bb_stadium_top_menu" then
    return
  end
  if not on then
    pcall(BattleBayDeluxe.TournamentHost.guide, true)
    return
  end
  local G = BattleBayDeluxe.Tournament.HUB.GUIDE
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, G, 0, true)
  funcLuaMenuCommand(2209673388 --[[guide entries]], BattleBayDeluxe.TournamentHost.menu, G,
    { 1847312674 --[[Accept]], BBT_Id("hub_exit") },
    { 2750714971 --[[<CMD_ENTER>]], BBT_Id("key_back") }, { 0, 0 }, { 0, 0 }, { 0, 0 })
  funcLuaMenuCommand(452337289 --[[guide commands]], BattleBayDeluxe.TournamentHost.menu, G, { 1981080283 --[[CMD_ENTER]], @crc:CMD_BACK@ })
end

-- the dashboard's next action: "play" | "calendar" | "competition" | "roster" | "new" | "exit" (the overlay closed
-- from elsewhere = "exit"); the coroutine sleeps until a key event sets it
function BBT_HubWait()
  BattleBayDeluxe.TournamentState.hub_act = nil
  BattleBayDeluxe.TournamentState.hub_wait = true
  while BattleBayDeluxe.TournamentState.hub_act == nil and BattleBayDeluxe.TournamentState.open do
    coroutine.yield()
  end
  BattleBayDeluxe.TournamentState.hub_wait = nil
  local a = BattleBayDeluxe.TournamentState.hub_act or "exit"
  BattleBayDeluxe.TournamentState.hub_act = nil
  return a
end

-- a section's pages until Enter / Back (BBT_OnEnter / OnBack clear BattleBayDeluxe.TournamentState.section)
function BBT_HubSection(page)
  BBT_Draw(page)
  BattleBayDeluxe.TournamentState.section = true
  while BattleBayDeluxe.TournamentState.section and BattleBayDeluxe.TournamentState.open do
    coroutine.yield()
  end
  BattleBayDeluxe.TournamentState.section = nil
end

-- the calendar page of the last matchday played (the hub's «Últimos resultados»); nil when none was played
function BBT_HubResultsPage(v)
  local played = tonumber(v.played) or 0
  if played < 1 then
    return nil
  end
  return BattleBayDeluxe.Tournament.HUB.CALENDAR_PAGE + (played - 1) * BattleBayDeluxe.Tournament.HUB.CAL_HALVES
end

-- 1.70.0 (owner 2026-10-29: «El calendario tienen que ser todas las jornadas que hay»): the calendar section = the grid of
-- every matchday (view kind "fixtures", drawn by evt_bbd_tn_groups_menu.lua DrawFixtures). The arrows move the focus
-- card by card (Up / Down a row of the view's cols), L1 / R1 turn the grid's pages, Accept (or a click) opens the
-- focused matchday's page (every match of it, the calendar pages: L1 / R1 there turn the matchdays; Enter / Back = the
-- grid again), Back = the hub. Hover by movement focuses a card, the wheel turns the page.

-- the grid drawn again: the focused matchday to the drawing menu, its page drawn (a new page) or redrawn
function BBT_HubCalShow(silent)
  local S = BattleBayDeluxe.TournamentState
  local v = S.view or {}
  local page = BattleBayDeluxe.Tournament.HUB.FIXTURES_FIRST + math.floor((S.cal_md - 1) / math.max(1, S.cal_per))
  VRFW_Param.Clear(BattleBayDeluxe.Tournament.HUB.P_CAL_MD)
  VRFW_Param.Set(BattleBayDeluxe.Tournament.HUB.P_CAL_MD, S.cal_md)
  if not silent then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2456713098 --[[sy0001]])
  end
  if v.kind == "fixtures" and v.page == page then
    BBT_GroupsShow(page)
  else
    BBT_Draw(page)
  end
end

-- the focus to matchday md (clamped to the league's matchdays)
function BBT_HubCalFocus(md, silent)
  local S = BattleBayDeluxe.TournamentState
  md = math.max(1, math.min(S.cal_mds, md))
  if md ~= S.cal_md then
    S.cal_md = md
    BBT_HubCalShow(silent)
  end
end

-- the grid's keys while it waits (OnDecideFocus / OnBack / OnFunction): true = taken
function BBT_HubCalKey(kind, fn)
  local S = BattleBayDeluxe.TournamentState
  if not S.cal_wait then
    return false
  end
  local H = BattleBayDeluxe.Tournament.HUB
  local P = S.hub_ptr
  if fn == H.FN_CLICK or (kind == "enter" and P ~= nil and P.Owns()) then
    return true
  end
  if P ~= nil and kind == "function" then
    P.KeyStep()
  end
  if kind == "enter" then
    S.cal_act = "open"
  elseif kind == "back" then
    S.cal_act = "back"
  elseif fn == H.FN_LEFT then
    BBT_HubCalFocus(S.cal_md - 1)
  elseif fn == H.FN_RIGHT then
    BBT_HubCalFocus(S.cal_md + 1)
  elseif fn == H.FN_UP or fn == H.FN_DOWN then
    -- a row up / down; none there (the grid's first / last row): the focus stays
    local to = S.cal_md + (fn == H.FN_UP and -S.cal_cols or S.cal_cols)
    if to >= 1 and to <= S.cal_mds then
      BBT_HubCalFocus(to)
    end
  elseif fn == BattleBayDeluxe.Tournament.FN_PREV or fn == BattleBayDeluxe.Tournament.FN_NEXT then
    BBT_HubCalTurn(fn == BattleBayDeluxe.Tournament.FN_NEXT and 1 or -1)
  end
  return true
end

-- a page of the grid turned by d (wraps): the focus on the same place of the new page (its last card when shorter)
function BBT_HubCalTurn(d)
  local S = BattleBayDeluxe.TournamentState
  local pages = math.max(1, math.ceil(S.cal_mds / S.cal_per))
  if pages < 2 then
    return
  end
  local p = math.floor((S.cal_md - 1) / S.cal_per)
  local slot = (S.cal_md - 1) % S.cal_per
  local np = (p + d) % pages
  S.cal_md = math.min(S.cal_mds, np * S.cal_per + slot + 1)
  BBT_HubCalShow()
end

-- the grid until Back (a coroutine step of BBT_LeagueHub); v = the hub's view (fixtures_page / fixtures_md)
function BBT_HubCalendar(v)
  local S = BattleBayDeluxe.TournamentState
  local H = BattleBayDeluxe.Tournament.HUB
  local first = BBT_Call(BattleBayDeluxe.Tournament.VIEW, v.fixtures_page or H.FIXTURES_FIRST)
  if type(first) ~= "table" or first.kind ~= "fixtures" then
    -- no grid (an older view): the matchday's page as before
    BBT_HubSection(v.calendar_page or H.CALENDAR_PAGE)
    return
  end
  S.cal_mds = math.max(1, tonumber(first.mds) or 1)
  S.cal_cols = math.max(1, tonumber(first.cols) or 1)
  S.cal_per = math.max(1, tonumber(first.per) or S.cal_mds)
  S.cal_md = math.max(1, math.min(S.cal_mds, tonumber(v.fixtures_md) or 1))
  BBT_HubCalShow(true)
  while BattleBayDeluxe.TournamentState.open do
    S.cal_act = nil
    S.cal_wait = true
    while S.cal_act == nil and BattleBayDeluxe.TournamentState.open do
      coroutine.yield()
    end
    S.cal_wait = nil
    local a = S.cal_act
    S.cal_act = nil
    if a ~= "open" then
      break
    end
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    BBT_HubSection(H.CALENDAR_PAGE + (S.cal_md - 1) * H.CAL_HALVES)
    if not BattleBayDeluxe.TournamentState.open then
      break
    end
    -- back on the grid: on the matchday the inner pages were turned to
    local pg = tonumber(BattleBayDeluxe.TournamentState.page) or 0
    if pg >= H.CALENDAR_PAGE then
      S.cal_md = math.max(1, math.min(S.cal_mds, math.floor((pg - H.CALENDAR_PAGE) / H.CAL_HALVES) + 1))
    end
    BattleBayDeluxe.TournamentState.view = nil
    BBT_HubCalShow(true)
  end
  if BattleBayDeluxe.TournamentState.open then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
  end
  S.cal_wait, S.cal_act = nil, nil
end

-- the hub's loop (a coroutine: BattleBayDeluxe.TournamentState.co, or the entry's decide coroutine)
function BBT_LeagueHub()
  BattleBayDeluxe.TournamentState.hub = true
  local H = BattleBayDeluxe.Tournament.HUB
  BattleBayDeluxe.TournamentState.hub_nav = BattleBayDeluxe.TournamentState.hub_nav or 0
  BattleBayDeluxe.TournamentState.hub_focus = nil
  while true do
    local info = BBT_Info()
    if not info.active or info.fmt ~= 2 then
      break
    end
    BBT_HubNavParam()
    if BattleBayDeluxe.TournamentState.open then
      BBT_Draw(H.PAGE)
    else
      BBT_Open(H.PAGE)
    end
    if not BattleBayDeluxe.TournamentState.open then
      break
    end
    BBT_HubGuide(true)
    local what = BBT_HubWait()
    BBT_HubGuide(false)
    BBT_Log("hub:", what, "side menu row", BattleBayDeluxe.TournamentState.hub_nav)
    local v = BattleBayDeluxe.TournamentState.view or {}
    if what == "dashboard" then
      -- 1.58.0: «Inicio»: the focus into the dashboard (its first panel, the next match)
      BBT_HubFocus(1)
    elseif what == "scorers" then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BBT_HubSection(H.SCORERS_PAGE)
      if not BattleBayDeluxe.TournamentState.open then
        break
      end
    elseif what == "results" then
      -- the last matchday played (its results page of the calendar); none yet: the next one
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BBT_HubSection(BBT_HubResultsPage(v) or v.calendar_page or H.CALENDAR_PAGE)
      if not BattleBayDeluxe.TournamentState.open then
        break
      end
    elseif what == "play" then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BattleBayDeluxe.TournamentState.hub = nil
      BBT_PlayNext()
      if not BattleBayDeluxe.TournamentState.open then
        return
      end
      BattleBayDeluxe.TournamentState.hub = true
    elseif what == "calendar" then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BBT_HubCalendar(v)
      if not BattleBayDeluxe.TournamentState.open then
        break
      end
    elseif what == "competition" then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BBT_HubSection(v.home_page or 10)
      if not BattleBayDeluxe.TournamentState.open then
        break
      end
    elseif what == "roster" then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      if not BBT_HubTeamEditor() then
        BBT_HubSection(H.SQUAD_PAGE)
      end
      if not BattleBayDeluxe.TournamentState.open then
        break
      end
    elseif what == "new" then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      local a = BBT_Choose({ BBT_Id("new_yes"), BBT_Id("new_no") }, 1)
      if a == 0 then
        BBT_Call(BattleBayDeluxe.Tournament.ABANDON)
        pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, "")
        if BattleBayDeluxe.TournamentState.open then
          BBT_Close()
        end
        BattleBayDeluxe.TournamentState.hub = nil
        BBT_Log("hub: the running league abandoned, a new one")
        return BBT_NewRun(2)
      end
    else
      if BattleBayDeluxe.TournamentState.open then
        funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
        BBT_Close()
      end
      break
    end
  end
  BattleBayDeluxe.TournamentState.hub, BattleBayDeluxe.TournamentState.hub_wait, BattleBayDeluxe.TournamentState.hub_act, BattleBayDeluxe.TournamentState.hub_focus = nil, nil, nil, nil
end
