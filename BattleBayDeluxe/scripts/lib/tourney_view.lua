-- Battle Bay Deluxe «Torneo»: what the bracket overlay draws, as data (pure: no game access; the graft
-- research/grafts/bb_tournament lays it out on screen, research/scripts/bbd_bracket_preview.py into a picture).
-- docs/game/modes/bb-tournament.md §6.
--
-- A view: { kind = "tree" | "groups" | "league" | "results" | "none", page, pages = { page ids in L1 / R1 order },
--   title = { key = <text key suffix>, n = <number or 0> }, champion = team or 0, place = { stage, round, pos } or
--   false, outcome, … } and per kind:
--   tree (1.5.15: the WHOLE knockout in one view, built from its size: rounds = log2(entrants), no byes):
--     rounds = R, leaves[1 .. 2^R] = { team, me, out, won } in tree order (round 1's match m = leaves 2m-1, 2m; the
--     first half is the left side, the second half the right side), matches[r][m] (r = 1 .. R, m = 1 .. 2^R / 2^r) =
--     { w = 0 | 1 (the upper entrant won) | 2 (the lower), score = false | { ga, gb, pa, pb, et } }
--   groups (1.5.54: EVERY group on one page, the standings tables): groups[g] = { n = g, rows[1..4] = { team, me, out,
--     pos, pj, g, e, p, gf, gc, dg, pts, form = "WDL…" (the group matches played, in matchday order) } }, played =
--     matchdays played (0..3), qualify = the knockout round the top 2 go to (its distance to the final: 2 semi-finals
--     .. 5 round of 32)
--   league: standings[1..V.LEAGUE_ROWS] = { team, me, pos, pj, g, e, p, gf, gc, dg, pts, form } (the table's slice of
--     this page, T.table's order), page_n / page_count, page_rows (V.LEAGUE_ROWS), played / mds (matchdays)
--   results: rows[t] (below); plates (old readers) = false | { team, me, out, won, line1 = { key, n… } or false,
--     line2 = { key, n, m, … } or false }
-- Text keys (text\rows\menu_text.toml): the graft prefixes them with evt_bbd_tn_. A key's numbers fill VALUE /
-- VALUE2 the way the retail texts do.

local T = require "lib/tourney"
local Competition = require "VRFW/lib/competition"

local V = {}

local floor = math.floor

-- page ids
V.TREE = 0         -- the knockout tree: one page, every round of it
V.GROUPS = 10      -- the group tables (1.5.54: all groups on this one page; was 10 + p, 4 groups a page)
V.RESULTS = 20     -- the round just played: every match on one page (1.5.24; was 8 a page, 20 + p)
V.RESULTS_MAX = 16 -- matches on the results page (a 32-team knockout's first round)
V.LEAGUE = 10      -- the league's standings: 10 + p (a league has no group page)
V.LEAGUE_ROWS = 12 -- teams on a standings page (config.toml [league] rows_per_page)
V.LEAGUE_ROWS_MAX = 18
V.FORM = 5         -- the league's form column: its last results
-- the league's career hub (1.48.0): the hub page (the next fixture), the top scorers (a Competición page beside the
-- standings), the calendar (one matchday a page, CAL_HALVES pages a matchday when it has more than RESULTS_MAX
-- matches: 100 + (md - 1) * CAL_HALVES + half)
V.HUB = 9
-- 1.53.0: the league team's squad (the hub's «Plantilla»: the run's team, its members filled by scripts\tournament.lua)
V.SQUAD = 8
V.SCORERS = 19
V.CALENDAR = 100
V.CAL_HALVES = 2
-- 1.70.0: the calendar section's grid of every matchday (one card a matchday: the player's match), FIXTURES + p,
-- FIXTURES_PAGE cards a page in FIXTURES_COLS columns; Accept on a card = that matchday's page above (CALENDAR)
V.FIXTURES = 90
V.FIXTURES_PAGE = 30
V.FIXTURES_COLS = 6


-- the league's sections: "hub", "calendar", "competition" (standings + top scorers), "results" (after a match: the
-- matchday's results, then the competition pages); the pages L1 / R1 turn are the section's own
function V.section(run, page)
  if run.fmt ~= "league" or type(page) ~= "number" then
    return "results"
  end
  if page == V.HUB then
    return "hub"
  elseif page == V.SQUAD then
    return "squad"
  elseif page >= V.FIXTURES and page < V.CALENDAR then
    return "fixtures"
  elseif page >= V.CALENDAR then
    return "calendar"
  elseif page >= V.LEAGUE and page <= V.SCORERS then
    return "competition"
  end
  return "results"
end

-- the calendar's page of matchday md (its first half)
function V.calendar_page(md)
  return V.CALENDAR + (md - 1) * V.CAL_HALVES
end

-- the list of page ids, the round just played first (results), then the groups (while they matter), then the tree;
-- a league: the pages of the section `page` belongs to
function V.pages(run, page)
  local p = {}
  local sec = V.section(run, page)
  if sec == "hub" then
    return { V.HUB }
  elseif sec == "squad" then
    return { V.SQUAD }
  elseif sec == "fixtures" then
    for i = 0, V.fixtures_pages(run) - 1 do
      p[#p + 1] = V.FIXTURES + i
    end
    return p
  elseif sec == "calendar" then
    for md = 1, run.mds do
      local n = 0
      for _, m in ipairs(run.gm[1]) do
        if m.md == md then
          n = n + 1
        end
      end
      for h = 0, math.min(V.CAL_HALVES, math.ceil(n / V.RESULTS_MAX)) - 1 do
        p[#p + 1] = V.calendar_page(md) + h
      end
    end
    return p
  end
  if run.last then
    local n = #V.round_matches(run, run.last.stage, run.last.round)
    for i = 0, floor((n - 1) / V.RESULTS_MAX) do
      p[#p + 1] = V.RESULTS + i
    end
  end
  if run.fmt == "league" then
    if sec == "competition" then
      p = {}
    end
    for i = 0, V.league_pages(run) - 1 do
      p[#p + 1] = V.LEAGUE + i
    end
    p[#p + 1] = V.SCORERS
  elseif run.groups then
    p[#p + 1] = V.GROUPS
  end
  if run.ko[1] then
    p[#p + 1] = V.TREE
  end
  return p
end

-- the pages of the matchday grid
function V.fixtures_pages(run)
  return math.max(1, math.ceil((run.mds or 1) / V.FIXTURES_PAGE))
end

-- the grid page of matchday md
function V.fixtures_page(md)
  return V.FIXTURES + floor((math.max(1, md) - 1) / V.FIXTURES_PAGE)
end

-- the standings pages of a league
function V.league_pages(run)
  return math.max(1, math.ceil(run.size / V.LEAGUE_ROWS))
end

-- the matches of one round: stage "groups" / "league" (round = matchday) or "ko" (round = KO round)
function V.round_matches(run, stage, round)
  local out = {}
  if T.round_robin(stage) then
    for _, gm in ipairs(run.gm or {}) do
      for _, m in ipairs(gm) do
        if m.md == round then
          out[#out + 1] = m
        end
      end
    end
  else
    for _, m in ipairs(run.ko[round] or {}) do
      out[#out + 1] = m
    end
  end
  return out
end

local function plate(run, e, extra)
  if not e or e == 0 then
    return { team = 0, me = false, out = false, won = 0, n = 0, line1 = false, line2 = false }
  end
  local p = { team = run.teams[e], me = e == run.player, out = false, won = 0, n = 0, line1 = false, line2 = false }
  for k, v in pairs(extra or {}) do
    p[k] = v
  end
  return p
end

local function score_of(m, a_first)
  if not m or not m.done then
    return false
  end
  if a_first == false then
    return { ga = m.gb, gb = m.ga, pa = m.pb, pb = m.pa, et = m.et }
  end
  return { ga = m.ga, gb = m.gb, pa = m.pa, pb = m.pb, et = m.et }
end

-- the round's title key: knockout rounds by their distance to the final (ko_1 final, ko_2 semi-finals, ko_3
-- quarter-finals, ko_4 last 16, ko_5 last 32), group matchdays md + number
local function round_title(run, stage, round)
  if T.round_robin(stage) then
    return { key = "md", n = round }
  end
  return { key = "ko_" .. T.round_from_end(run, round), n = 0 }
end

-- the whole knockout tree (1.5.15): every entrant of round 1 as a leaf, every match of every round with its winner
-- side and score (the framework's bracket view, drawn by its bracket screen: the left half of the leaves on the left,
-- the right half mirrored, the final in the middle)
local function tree_view(run)
  local first = run.ko[1]
  if not first then
    return { kind = "tree", title = { key = "tree_wait", n = 0 } }
  end
  local R = T.ko_rounds(run)
  local leaves = {}
  for j = 0, 2 ^ R - 1 do
    local m = first[floor(j / 2) + 1]
    local e = m and (j % 2 == 0 and m.a or m.b) or 0
    leaves[j + 1] = e ~= 0 and { team = run.teams[e], me = e == run.player } or 0
  end
  local v = Competition.bracket_view({
    rounds = R,
    leaves = leaves,
    champion = run.teams[T.champion(run)] or 0,
    match = function(r, t)
      local mm = run.ko[r] and run.ko[r][t]
      if not (mm and mm.done) then
        return nil
      end
      return { w = mm.w ~= 0 and (mm.w == mm.a and 1 or 2) or 0, score = score_of(mm) }
    end,
  })
  v.title = { key = "tree", n = 0 }
  return v
end

-- a team's group results in matchday order: "W" won, "D" drawn, "L" lost (last = only the last that many)
local function form_of(run, g, e, last)
  local ms = {}
  for _, m in ipairs(run.gm[g] or {}) do
    if m.done and (m.a == e or m.b == e) then
      ms[#ms + 1] = m
    end
  end
  table.sort(ms, function(x, y)
    return (x.md or 0) < (y.md or 0)
  end)
  local f = {}
  for _, m in ipairs(ms) do
    local mine, other = m.ga, m.gb
    if m.b == e then
      mine, other = m.gb, m.ga
    end
    f[#f + 1] = mine > other and "W" or (mine < other and "L" or "D")
  end
  if last and #f > last then
    return table.concat(f, "", #f - last + 1, #f)
  end
  return table.concat(f)
end

-- 1.5.54 (owner 2026-10-13, the approved sketch research/scripts/bbd_groups_sketch.py): every group on one page as a
-- standings table (T.table's order: points, goal difference, goals, head to head, lot)
local function groups_view(run)
  local played = run.stage == "groups" and (run.md or 1) - 1 or 3
  played = math.max(0, math.min(3, played))
  local v = { kind = "groups", groups = {}, played = played, qualify = T.ko_rounds(run),
    title = played > 0 and { key = "groups_md", n = played } or { key = "groups_title", n = 0 } }
  for g = 1, #run.groups do
    local rows = {}
    for pos, x in ipairs(T.table(run, g)) do
      rows[pos] = {
        team = run.teams[x.e] or 0, me = x.e == run.player, out = run.stage ~= "groups" and pos > 2, pos = pos,
        pj = x.pl, g = x.w, e = x.d, p = x.l, gf = x.gf, gc = x.ga, dg = x.gd, pts = x.pts,
        form = form_of(run, g, x.e),
      }
    end
    v.groups[g] = { n = g, rows = rows }
  end
  return v
end

-- the league's standings, page p (0-based): T.table's order (points, goal difference, goals, head to head, lot), the
-- slice of V.LEAGUE_ROWS rows of that page
local function league_view(run, p)
  local played = run.stage == "league" and (run.md or 1) - 1 or run.mds
  local count = V.league_pages(run)
  p = math.max(0, math.min(count - 1, p))
  local v = { kind = "league", standings = {}, played = played, mds = run.mds, page_n = p + 1, page_count = count,
    page_rows = V.LEAGUE_ROWS, double = run.double == true,
    title = played > 0 and { key = "league_md", n = played, m = run.mds } or { key = "league_title", n = 0 } }
  local t = T.table(run, 1)
  for pos = p * V.LEAGUE_ROWS + 1, math.min(#t, (p + 1) * V.LEAGUE_ROWS) do
    local x = t[pos]
    v.standings[#v.standings + 1] = {
      team = run.teams[x.e] or 0, me = x.e == run.player, out = false, pos = pos, pj = x.pl, g = x.w, e = x.d, p = x.l,
      gf = x.gf, gc = x.ga, dg = x.gd, pts = x.pts, form = form_of(run, 1, x.e, V.FORM),
    }
  end
  return v
end

-- the top scorers (run.scorers: { e, c = card, g = goals } per player, scripts/tournament.lua), most goals first
-- (ties: the order they first scored), at most V.LEAGUE_ROWS rows
local function scorers_view(run)
  local list = {}
  for i, x in ipairs(run.scorers or {}) do
    if (x.g or 0) > 0 then
      list[#list + 1] = { i = i, x = x }
    end
  end
  table.sort(list, function(a, b)
    if a.x.g ~= b.x.g then
      return a.x.g > b.x.g
    end
    return a.i < b.i
  end)
  local v = { kind = "scorers", rows = {}, page_rows = V.LEAGUE_ROWS, title = { key = "scorers_title", n = 0 } }
  for k = 1, math.min(#list, V.LEAGUE_ROWS) do
    local x = list[k].x
    v.rows[k] = { pos = k, card = x.c, goals = x.g, team = run.teams[x.e] or 0, me = x.e == run.player }
  end
  return v
end

-- the hub (1.52.0, owner 2026-10-28: the career dashboard, mock-up C): the player's next fixture (home / away), his
-- place and points (false fixture once the league is over), and the dashboard's panels, all from the run:
--   top[] = the standings' first V.HUB_TOP rows { team, me, pos, pj, dg, pts } + the player's row when he is lower
--     (gap = true on it: a «…» line before it)
--   scorers[] = the first V.HUB_SCORERS top scorers { pos, card, goals, team, me }
--   results[] = the player's last V.FORM matches, oldest first { md, team (rival), home, gf, ga, r = "W" | "D" | "L" }
--   fixtures[] = the player's next V.HUB_FIXTURES matches from the next one { md, team (rival), home, next }
--   form (his last V.FORM results), played / mds (matchdays), size (teams), team (his team hash), my_scorer (his
--   team's top scorer { card, goals } or false)
V.HUB_TOP = 5
V.HUB_SCORERS = 3
V.HUB_FIXTURES = 5

local function hub_matches(run)
  local mine = {}
  for _, m in ipairs(run.gm[1] or {}) do
    if m.a == run.player or m.b == run.player then
      mine[#mine + 1] = m
    end
  end
  table.sort(mine, function(x, y)
    return (x.md or 0) < (y.md or 0)
  end)
  return mine
end

-- the player's match x as a matchday card: { md, team (rival), home, next (the next match m) }; played: + done, gf, ga,
-- r = "W" | "D" | "L" (the match's recorded score)
local function matchday_card(run, x, m)
  local home = x.a == run.player
  local card = { md = x.md, team = run.teams[home and x.b or x.a] or 0, home = home, next = x == m }
  if x.done then
    local gf, ga = home and x.ga or x.gb, home and x.gb or x.ga
    card.done, card.gf, card.ga = true, gf, ga
    card.r = gf > ga and "W" or (gf < ga and "L" or "D")
  end
  return card
end

-- 1.70.0: a page of the matchday grid: cards[] = the player's match of each matchday of the page (matchday_card),
-- cols (the grid's columns), per (cards a full page), mds, team (his team hash), page_n / page_count
local function fixtures_view(run, page)
  local p = page - V.FIXTURES
  local count = V.fixtures_pages(run)
  local v = { kind = "fixtures", cards = {}, cols = V.FIXTURES_COLS, per = V.FIXTURES_PAGE, mds = run.mds,
    team = run.teams[run.player] or 0,
    page_n = p + 1, page_count = count, title = { key = "hub_calendar", n = 0 } }
  local m = T.pending(run)
  local by_md = {}
  for _, x in ipairs(hub_matches(run)) do
    by_md[x.md] = by_md[x.md] or x
  end
  for md = p * V.FIXTURES_PAGE + 1, math.min(run.mds or 0, (p + 1) * V.FIXTURES_PAGE) do
    local x = by_md[md]
    v.cards[#v.cards + 1] = x and matchday_card(run, x, m) or { md = md, team = 0, none = true }
  end
  return v
end

local function hub_view(run)
  local v = { kind = "hub", fixture = false, title = { key = "hub_title", n = 0 } }
  local m, _, md = T.pending(run)
  local pos, pts = 0, 0
  local t = T.table(run, 1)
  v.top = {}
  for i, x in ipairs(t) do
    local row = { team = run.teams[x.e] or 0, me = x.e == run.player, pos = i, pj = x.pl, dg = x.gd, pts = x.pts }
    if x.e == run.player then
      pos, pts = i, x.pts
      if i > V.HUB_TOP then
        row.gap = i > V.HUB_TOP + 1
        v.top[#v.top + 1] = row
      end
    end
    if i <= V.HUB_TOP then
      v.top[#v.top + 1] = row
    end
  end
  v.pos, v.pts, v.mds, v.size = pos, pts, run.mds, run.size
  v.played = run.stage == "league" and (run.md or 1) - 1 or run.mds
  v.team = run.teams[run.player] or 0
  v.form = form_of(run, 1, run.player, V.FORM)
  if m then
    local place = {}
    for i, x in ipairs(t) do
      place[x.e] = { pos = i, pts = x.pts }
    end
    local function side(e)
      local p = place[e] or {}
      return { team = run.teams[e] or 0, me = e == run.player, pos = p.pos or 0, pts = p.pts or 0 }
    end
    v.fixture = { md = md, home = side(m.a), away = side(m.b) }
    v.title = { key = "league_md_next", n = md, m = run.mds }
  end
  -- the player's last results and next fixtures
  local played, coming = {}, {}
  for _, x in ipairs(hub_matches(run)) do
    local card = matchday_card(run, x, m)
    if x.done then
      played[#played + 1] = card
    elseif not run.outcome then
      coming[#coming + 1] = card
    end
  end
  v.results = {}
  for k = math.max(1, #played - V.FORM + 1), #played do
    v.results[#v.results + 1] = played[k]
  end
  v.fixtures = {}
  for k = 1, math.min(#coming, V.HUB_FIXTURES) do
    v.fixtures[k] = coming[k]
  end
  -- the top scorers, and the player's team's own best one
  local sc = scorers_view(run)
  v.scorers = {}
  v.my_scorer = false
  for k, r in ipairs(sc.rows) do
    if k <= V.HUB_SCORERS then
      v.scorers[k] = r
    end
    if r.me and not v.my_scorer then
      v.my_scorer = { card = r.card, goals = r.goals }
    end
  end
  return v
end

-- a calendar page: the matches of one matchday (played: their score; the next: the player's framed), as a results page
local function calendar_view(run, page)
  local k = page - V.CALENDAR
  local md, half = floor(k / V.CAL_HALVES) + 1, k % V.CAL_HALVES
  local saved = run.last
  run.last = { stage = "league", round = md }
  local v = V.results_page(run, half)
  run.last = saved
  v.calendar, v.md = true, md
  v.title = { key = "calendar_md", n = md, m = run.mds }
  return v
end

-- the standings page that holds the player's team
local function league_home(run)
  for pos, x in ipairs(T.table(run, 1)) do
    if x.e == run.player then
      return V.LEAGUE + math.floor((pos - 1) / V.LEAGUE_ROWS)
    end
  end
  return V.LEAGUE
end

-- 1.5.24 (owner: «the results show only part of the round»): every match of the round on one page as scoreboard
-- rows (a 32-team first round = 16 rows), was 8 a page with the other half on a second page. matches[t] =
-- { a = plate, b = plate, ga, gb, pa, pb, et, done, w = 0 | 1 (a won) | 2 (b won) }; a plate's line2 is kept for the
-- old readers.
function V.results_page(run, page)
  local st, rd = run.last.stage, run.last.round
  local ms = V.round_matches(run, st, rd)
  local v = { kind = "results", plates = {}, rows = {}, title = round_title(run, st, rd) }
  for t = 1, V.RESULTS_MAX do
    local m = ms[page * V.RESULTS_MAX + t]
    if m then
      local row = { done = m.done == true, ga = m.ga or 0, gb = m.gb or 0, pa = m.pa or 0, pb = m.pb or 0,
        et = m.et == true, w = 0 }
      if m.done and m.w ~= 0 then
        row.w = m.w == m.a and 1 or 2
      end
      for side = 0, 1 do
        local e = side == 0 and m.a or m.b
        row[side == 0 and "a" or "b"] = plate(run, e, {
          won = (m.done and m.w == e) and 1 or 0,
          out = m.done and m.w ~= 0 and m.w ~= e,
          line2 = false,
        })
      end
      v.rows[#v.rows + 1] = row
    end
  end
  return v
end

-- the view of page `page` (-1 = the first page of the list)
local results_view = V.results_page

function V.build(run, page)
  local pages = V.pages(run, page)
  if #pages == 0 then
    return { kind = "none", pages = pages }
  end
  local found = false
  for _, p in ipairs(pages) do
    if p == page then
      found = true
    end
  end
  if not found then
    page = pages[1]
  end
  local v
  if run.fmt == "league" and page == V.HUB then
    v = hub_view(run)
  elseif run.fmt == "league" and page == V.SQUAD then
    v = { kind = "squad", team = run.teams[run.player] or 0, rows = {}, title = { key = "squad_title", n = 0 } }
  elseif run.fmt == "league" and page >= V.FIXTURES and page < V.CALENDAR then
    v = fixtures_view(run, page)
  elseif run.fmt == "league" and page >= V.CALENDAR then
    v = calendar_view(run, page)
  elseif run.fmt == "league" and page == V.SCORERS then
    v = scorers_view(run)
  elseif page >= V.RESULTS then
    v = results_view(run, page - V.RESULTS)
  elseif run.fmt == "league" then
    v = league_view(run, page - V.LEAGUE)
  elseif page >= V.GROUPS then
    v = groups_view(run)
  else
    v = tree_view(run)
  end
  v.page, v.pages = page, pages
  v.fmt = run.fmt
  -- the bracket page an entry / Enter opens: a league's standings page with the player's team
  if run.fmt == "league" then
    v.home_page = league_home(run)
    -- the calendar opens on the next matchday (the last one once the league is over)
    v.calendar_page = V.calendar_page(math.min(run.md or 1, run.mds))
    -- 1.70.0: the calendar section's matchday grid, on the page of that matchday (focused)
    v.fixtures_md = math.min(run.md or 1, run.mds)
    v.fixtures_page = V.fixtures_page(v.fixtures_md)
  end
  v.outcome = run.outcome or ""
  -- eliminated with rounds left: Enter simulates the next one (the player watches the rest round by round)
  v.watching = run.outcome == "out" and run.stage ~= "over"
  v.place = run.place or false
  if v.place and v.place.stage == "ko" then
    v.place.from_end = T.round_from_end(run, v.place.round)
  end
  v.champion = v.champion or (run.teams[T.champion(run)] or 0)
  -- 1.5.23: the player's match count is `player_matches`; it was written to `matches`, which overwrote the tree's
  -- per-round table (matches[r][m]) with a number, so the graft's tree draw returned without placing anything
  -- (owner log 18:56: «bracket drawn n=0 … matches:number»)
  v.k, v.player_matches = run.k, T.run_matches(run)
  local opp = T.opponent(run)
  v.next = opp ~= 0 and run.teams[opp] or 0
  local m, st, rd = T.pending(run)
  v.next_title = m and round_title(run, st, rd) or false
  return v
end

return V
