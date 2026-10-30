-- Battle Bay Deluxe: the Torneo's rules, pure (no game access): the draw, the group stage, the knockout tree, the
-- simulated matches and the player's progress (docs/game/modes/bb-tournament.md §4). scripts\tournament.lua owns the
-- run (save blob, the campaign session block, the commands); this file only turns numbers into numbers. The round
-- robin, the standings, the goal draws and the seed order are the framework's (VRFW/lib/competition); the rules
-- (3 / 1 / 0 points, the tie-breaks, the match model) are this file's.
--
-- A run is one plain table (JSON in the save blob, arrays dense, no nil holes):
--   v, fmt ("knockout" | "groups" | "league"), size (a power of two, T.sizes; a league: an even count), seed { hi, lo },
--   player (the player's entrant id), double (league: every pairing twice, home and away),
--   teams[e] (team hash of entrant e), str[e] (strength), lot[e] (tie-break lot),
--   groups[g] = { e1, e2, e3, e4 } (groups only), gm[g] = { match × 6 } (groups only),
--   ko[r] = { match … } (round r of the knockout tree; built when its entrants are known),
--   stage ("groups" | "league" | "ko" | "over"), md (matchday 1..mds), mds (the round robin's matchdays: 3 in a group,
--   size - 1 in a league, twice that with double), kr (knockout round), k (player matches played),
--   outcome (false | "champion" | "out"), place { stage, round, pos }, last { stage, round } (the round just played).
-- A match: { a, b, ga, gb, pa, pb, et, w, done, md } (a / b entrant ids or 0 = not known yet; pa / pb the shoot-out;
-- et = extra time played; w = the winner's entrant id, 0 = draw / not played).

local Competition = require "VRFW/lib/competition"

local T = {}

-- the round-robin stages: their matches live in run.gm[g] by matchday (a league is ONE group of every entrant)
local function round_robin(stage)
  return stage == "groups" or stage == "league"
end
T.round_robin = round_robin

local floor, exp, min, max = math.floor, math.exp, math.min, math.max

T.FORMATS = { knockout = true, groups = true, league = true }
-- the format numbers of the commands (CMND_BBD_TOURN_ARM / INFO): 0 knockout, 1 groups, 2 league
T.FORMAT_IDS = { knockout = 0, groups = 1, league = 2 }
T.FORMAT_OF = { [0] = "knockout", [1] = "groups", [2] = "league" }
-- the league: an even number of teams (every matchday pairs them all), MIN .. MAX in steps of STEP
T.LEAGUE = { MIN = 4, MAX = 36, STEP = 2 }
-- 1.5.15 (owner: no byes, ever): the number of teams is always a power of two, from MIN_SIZE to MAX_SIZE (the
-- bracket screen shows every team at once: 64 = 32 rows per side, 1.5.44: 4 .. 64); a group stage needs at least 2
-- groups of 4. 1.5.47 (owner 2026-10-13): no cap from the campaign block's 7 rivals any more (a tournament match is
-- always written at the block's index 0 since 1.5.5, its path is the run's own: the loading telop's nodes come from
-- CMND_BBD_TOURN_CAMPAIGN_INFO), so a group stage of 64 (3 + 5 = 8 player matches) is offered too.
T.MIN_SIZE, T.MAX_SIZE, T.MIN_GROUPS_SIZE = 4, 64, 8

-- the defaults of config.toml [tournament] (the in-game setup step overrides fmt / size)
T.DEFAULTS = {
  fmt = "knockout",
  size = 16,
  seeded = true,        -- seeds kept apart in the knockout tree / one per group (pots)
  goals = 1.3,          -- mean goals of a side between equal teams
  weight = 0.035,       -- goal-rate tilt per strength point (strength = rating + level)
  pen_kick = 0.75,      -- a penalty's chance to score
  pen_kicks = 5,
}

-- n is a power of two in MIN_SIZE .. MAX_SIZE
local function isize(n)
  if type(n) ~= "number" or n < T.MIN_SIZE or n > T.MAX_SIZE or n ~= floor(n) then
    return false
  end
  return Competition.is_power_of_two(n)
end
T.is_size = isize

-- player matches of a format / size (the champion's path); a league: every other team once (twice with double)
function T.player_matches(fmt, size, double)
  if fmt == "league" then
    return (size - 1) * (double and 2 or 1)
  end
  local ko = size
  local n = 0
  if fmt == "groups" then
    n = 3
    ko = size / 2
  end
  while ko > 1 do
    n = n + 1
    ko = ko / 2
  end
  return n
end

-- the player matches of a run
function T.run_matches(run)
  return T.player_matches(run.fmt, run.size, run.double)
end

-- the most matches a player can play in any knockout / group tournament this file builds (a league's path is shown
-- through a window of it: scripts/tournament.lua Tn.path_window)
T.MAX_PLAYER_MATCHES = math.max(T.player_matches("knockout", T.MAX_SIZE), T.player_matches("groups", T.MAX_SIZE))

local function league_size(n)
  local L = T.LEAGUE
  return type(n) == "number" and n == floor(n) and n >= L.MIN and n <= L.MAX and (n - L.MIN) % L.STEP == 0
    and n % 2 == 0
end

function T.valid(fmt, size)
  if fmt == "league" then
    return league_size(size)
  end
  return T.FORMATS[fmt] == true and isize(size) and (fmt ~= "groups" or size >= T.MIN_GROUPS_SIZE)
    and T.player_matches(fmt, size) <= T.MAX_PLAYER_MATCHES
end

-- the team counts offered for a format, smallest first: every valid power of two, none above `cap` (the teams the
-- pool can field, the player's included; nil = no cap)
function T.sizes(fmt, cap)
  local out = {}
  if fmt == "league" then
    for n = T.LEAGUE.MIN, T.LEAGUE.MAX, T.LEAGUE.STEP do
      if T.valid(fmt, n) and (cap == nil or n <= cap) then
        out[#out + 1] = n
      end
    end
    return out
  end
  local n = T.MIN_SIZE
  while n <= T.MAX_SIZE do
    if T.valid(fmt, n) and (cap == nil or n <= cap) then
      out[#out + 1] = n
    end
    n = n * 2
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ random numbers

-- a generator for one tag of the run (a pure function of the run's seed and the tag: reloading the save never
-- changes a simulated result). `mk(hi, lo)` builds a generator (lib/util U.rng).
local function tag_rng(run, mk, a, b, c)
  local h = (run.seed[1] + a * 2654435761) % 4294967296
  local l = (run.seed[2] + b * 2246822519 + c * 3266489917) % 4294967296
  local r = mk(h, l)
  r:next()
  return r
end

-- uniform [0, 1)
local function unit(r)
  return r:below(2147483648) / 2147483648
end

-- a goal count of mean lambda (at most 13 draws)
local function poisson(r, lambda)
  return Competition.poisson(function()
    return unit(r)
  end, lambda, 12)
end

-- ------------------------------------------------------------------------------------------------ the draw

-- standard knockout seed order of n leaves (1 = best seed): 1 n/2+1 … so seeds 1 and 2 meet only in the final
local seed_order = Competition.seed_order
T.seed_order = seed_order

-- entrants sorted strongest first (ties: lot)
local function by_strength(run, ids)
  local v = {}
  for i, e in ipairs(ids) do
    v[i] = e
  end
  table.sort(v, function(x, y)
    if run.str[x] ~= run.str[y] then
      return run.str[x] > run.str[y]
    end
    return run.lot[x] < run.lot[y]
  end)
  return v
end

-- the league's schedule (circle method): entrant order `ids` (n even), the first fixed and the others turning one
-- place a matchday; n - 1 matchdays, each team once per matchday; the fixed team's side alternates by matchday and
-- every other pair by its place, so home and away even out. double: the same matchdays again with the sides swapped.
local function league_schedule(ids, double)
  local out = {}
  for md, day in ipairs(Competition.round_robin(ids, { double = double, rotate = "left" })) do
    for _, m in ipairs(day) do
      out[#out + 1] = { a = m[1], b = m[2], md = md }
    end
  end
  return out
end
T.league_schedule = league_schedule

-- a new run. opts: fmt, size, seed { hi, lo }, player (team hash), player_str, opponents { { team, str } … } (at
-- least size - 1, already drawn in random order by the caller), seeded, double (league), mk (generator factory).
-- nil, why on bad input.
function T.new(opts)
  local fmt, size = opts.fmt, opts.size
  if not T.valid(fmt, size) then
    return nil, "format " .. tostring(fmt) .. " / " .. tostring(size) .. " teams is not offered"
  end
  if #opts.opponents < size - 1 then
    return nil, string.format("%d opponents for %d teams", #opts.opponents, size)
  end
  local run = {
    v = 1, fmt = fmt, size = size, seed = { opts.seed[1], opts.seed[2] }, player = 1,
    teams = { opts.player }, str = { opts.player_str or 0 }, lot = {},
    stage = fmt == "knockout" and "ko" or fmt, md = 1, mds = 3, kr = 1, k = 0, outcome = false,
    place = false, last = false, ko = {}, seeded = opts.seeded ~= false, double = fmt == "league" and opts.double == true,
  }
  for i = 1, size - 1 do
    run.teams[i + 1] = opts.opponents[i].team
    run.str[i + 1] = opts.opponents[i].str or 0
  end
  local r = tag_rng(run, opts.mk, 1, 0, 0)
  local ids = {}
  for e = 1, size do
    ids[e] = e
  end
  r:shuffle(ids)
  for i, e in ipairs(ids) do
    run.lot[e] = i
  end
  if fmt == "league" then
    -- one group of every entrant (the lot's order: the player's place in the schedule is random)
    local order = {}
    for i, e in ipairs(ids) do
      order[i] = e
    end
    run.groups, run.gm = { order }, { {} }
    for i, m in ipairs(league_schedule(order, run.double)) do
      run.gm[1][i] = { a = m.a, b = m.b, md = m.md, ga = 0, gb = 0, pa = 0, pb = 0, et = false, w = 0, done = false }
    end
    run.mds = (size - 1) * (run.double and 2 or 1)
  elseif fmt == "groups" then
    local G = size / 4
    run.groups, run.gm = {}, {}
    local order
    if run.seeded then
      -- pots: the G strongest are pot 1 (one per group), the next G pot 2 …; each pot spread at random
      order = by_strength(run, ids)
      for p = 0, 3 do
        local pot = {}
        for g = 1, G do
          pot[g] = order[p * G + g]
        end
        r:shuffle(pot)
        for g = 1, G do
          order[p * G + g] = pot[g]
        end
      end
    else
      order = ids
    end
    for g = 1, G do
      run.groups[g] = { order[g], order[G + g], order[2 * G + g], order[3 * G + g] }
      -- the group's slots in random order (the seed is not always «team 1» of the schedule)
      r:shuffle(run.groups[g])
      local s = run.groups[g]
      local pairs_ = { { 1, 2, 1 }, { 3, 4, 1 }, { 1, 3, 2 }, { 2, 4, 2 }, { 1, 4, 3 }, { 2, 3, 3 } }
      run.gm[g] = {}
      for i, p in ipairs(pairs_) do
        run.gm[g][i] = { a = s[p[1]], b = s[p[2]], md = p[3], ga = 0, gb = 0, pa = 0, pb = 0, et = false, w = 0,
          done = false }
      end
    end
  else
    local leaves
    if run.seeded then
      local order = by_strength(run, ids)
      local so = seed_order(size)
      leaves = {}
      for i = 1, size do
        leaves[i] = order[so[i]]
      end
    else
      leaves = ids
    end
    run.ko[1] = {}
    for i = 1, size / 2 do
      run.ko[1][i] = T.match(leaves[2 * i - 1], leaves[2 * i])
    end
  end
  return run
end

function T.match(a, b)
  return { a = a or 0, b = b or 0, ga = 0, gb = 0, pa = 0, pb = 0, et = false, w = 0, done = false, md = 0 }
end

-- ------------------------------------------------------------------------------------------------ simulation

-- one simulated match: ga, gb, pa, pb, et, w (w = a, b, or 0 for a draw when ko is false)
function T.simulate(run, cfg, r, a, b, ko)
  local d = ((run.str[a] or 0) - (run.str[b] or 0)) * cfg.weight
  local la = min(5, max(0.15, cfg.goals * exp(d / 2)))
  local lb = min(5, max(0.15, cfg.goals * exp(-d / 2)))
  local ga, gb = poisson(r, la), poisson(r, lb)
  local pa, pb, et = 0, 0, false
  if ko and ga == gb then
    et = true
    ga = ga + poisson(r, la / 3)
    gb = gb + poisson(r, lb / 3)
    if ga == gb then
      local tilt = min(0.1, max(-0.1, d / 20))
      local qa, qb = cfg.pen_kick + tilt, cfg.pen_kick - tilt
      for i = 1, 30 do
        if unit(r) < qa then
          pa = pa + 1
        end
        if unit(r) < qb then
          pb = pb + 1
        end
        if i >= cfg.pen_kicks and pa ~= pb then
          break
        end
      end
      if pa == pb then
        pa = pa + 1
      end
    end
  end
  local w = 0
  if ga > gb or (ga == gb and pa > pb) then
    w = a
  elseif gb > ga or (ga == gb and pb > pa) then
    w = b
  end
  return ga, gb, pa, pb, et, w
end

local function set(m, ga, gb, pa, pb, et, w)
  m.ga, m.gb, m.pa, m.pb, m.et, m.w, m.done = ga, gb, pa, pb, et, w, true
end

-- ------------------------------------------------------------------------------------------------ group tables

-- the table of group g, best first: { { e, pl, w, d, l, gf, ga, gd, pts } … }; 3 points a win, 1 a draw; level teams by
-- goal difference, goals, head to head (the points of their matches, then their goal difference; a league with double
-- plays two), then the lot
local TABLE_TIEBREAKS = { "points", "goal_diff", "goals_for", "head_to_head", "lot" }

function T.table(run, g)
  local results = {}
  for _, m in ipairs(run.gm[g]) do
    if m.done then
      results[#results + 1] = { m.a, m.b, m.ga, m.gb }
    end
  end
  local rows = {}
  for i, x in ipairs(Competition.standings(run.groups[g], results, { tiebreaks = TABLE_TIEBREAKS, lot = run.lot })) do
    rows[i] = { e = x.team, pl = x.played, w = x.won, d = x.drawn, l = x.lost, gf = x.goals_for, ga = x.goals_against,
      gd = x.goal_diff, pts = x.points }
  end
  return rows
end

-- the knockout's first round from the group tables: W1-R2, W3-R4 … (top half), W2-R1, W4-R3 … (bottom half), so two
-- teams of one group can only meet again in the final
local function ko_from_groups(run)
  local G = #run.groups
  local W, R = {}, {}
  for g = 1, G do
    local t = T.table(run, g)
    W[g], R[g] = t[1].e, t[2].e
  end
  local r1 = {}
  for g = 1, G, 2 do
    r1[#r1 + 1] = T.match(W[g], R[g + 1])
  end
  for g = 1, G, 2 do
    r1[#r1 + 1] = T.match(W[g + 1], R[g])
  end
  run.ko[1] = r1
end

-- ------------------------------------------------------------------------------------------------ the player's matches

-- the player's next match: match, stage, round (nil when the run is over)
function T.pending(run)
  if run.outcome then
    return nil
  end
  local p = run.player
  if round_robin(run.stage) then
    for g, gm in ipairs(run.gm) do
      for _, m in ipairs(gm) do
        if m.md == run.md and not m.done and (m.a == p or m.b == p) then
          return m, run.stage, run.md, g
        end
      end
    end
    return nil
  end
  local rd = run.ko[run.kr]
  if not rd then
    return nil
  end
  for _, m in ipairs(rd) do
    if not m.done and (m.a == p or m.b == p) then
      return m, "ko", run.kr
    end
  end
  return nil
end

-- the opponent of the player's next match (entrant id), 0 = none
function T.opponent(run)
  local m = T.pending(run)
  if not m then
    return 0
  end
  return m.a == run.player and m.b or m.a
end

-- a knockout match of the tree by round / index needs a winner of the previous round
local function next_round(run)
  local rd = run.ko[run.kr]
  if #rd == 1 then
    return false
  end
  local nx = {}
  for i = 1, #rd, 2 do
    nx[#nx + 1] = T.match(rd[i].w, rd[i + 1].w)
  end
  run.kr = run.kr + 1
  run.ko[run.kr] = nx
  return true
end

-- simulate every match of the current round that is still open (the player's own excluded unless `all`)
local function sim_round(run, cfg, mk, all)
  if round_robin(run.stage) then
    for g, gm in ipairs(run.gm) do
      for i, m in ipairs(gm) do
        if m.md == run.md and not m.done and (all or (m.a ~= run.player and m.b ~= run.player)) then
          set(m, T.simulate(run, cfg, tag_rng(run, mk, 2, run.md * 64 + g, i), m.a, m.b, false))
        end
      end
    end
  else
    for i, m in ipairs(run.ko[run.kr]) do
      if not m.done and (all or (m.a ~= run.player and m.b ~= run.player)) then
        set(m, T.simulate(run, cfg, tag_rng(run, mk, 3, run.kr, i), m.a, m.b, true))
      end
    end
  end
end

-- the place reached when the run ends: { stage, round, pos } (groups: the group position)
local function finish(run, outcome, stage, round, pos)
  run.outcome = outcome
  run.place = { stage = stage, round = round, pos = pos or 0 }
end

-- after the current round is complete: next matchday / the knockout / the next knockout round; sets the outcome
local function advance(run)
  local p = run.player
  if run.stage == "league" then
    if run.md < run.mds then
      run.md = run.md + 1
      return
    end
    -- the last matchday played: the first of the table is the champion, the player's place is his result
    local pos = 0
    for i, x in ipairs(T.table(run, 1)) do
      if x.e == p then
        pos = i
      end
    end
    run.stage = "over"
    finish(run, pos == 1 and "champion" or "out", "league", run.md, pos)
    return
  end
  if run.stage == "groups" then
    if run.md < (run.mds or 3) then
      run.md = run.md + 1
      return
    end
    -- the group stage is over
    local pos = 0
    for g = 1, #run.groups do
      for i, x in ipairs(T.table(run, g)) do
        if x.e == p then
          pos = i
        end
      end
    end
    ko_from_groups(run)
    run.stage, run.kr = "ko", 1
    if pos > 2 then
      finish(run, "out", "groups", 3, pos)
    end
    return
  end
  local rd = run.ko[run.kr]
  local mine
  for _, m in ipairs(rd) do
    if m.a == p or m.b == p then
      mine = m
    end
  end
  if mine and mine.w ~= p and not run.outcome then
    finish(run, "out", "ko", run.kr, 0)
  end
  if not next_round(run) then
    run.stage = "over"
    if mine and mine.w == p then
      finish(run, "champion", "ko", run.kr, 1)
    end
  end
end

-- the player's result of the pending match (goals for / against; shoot-out; extra time): records it, simulates the
-- rest of the round and moves on. A knockout draw without a shoot-out winner is a defeat (it cannot happen with the
-- tournament's rulebook; logged by the caller). outcome = the game's own result ("win" / "loss" / "draw", optional): it
-- names the winner of a level score the shoot-out goals do not. Returns the round just completed { stage, round } or
-- nil, why.
function T.record(run, cfg, mk, gf, ga, pf, pa, et, outcome)
  local m, stage, round = T.pending(run)
  if not m then
    return nil, "no pending match"
  end
  local mine_a = m.a == run.player
  local ka, kb = mine_a and gf or ga, mine_a and ga or gf
  local qa, qb = mine_a and pf or pa, mine_a and pa or pf
  local w = 0
  if ka > kb or (ka == kb and qa > qb) then
    w = m.a
  elseif kb > ka or (ka == kb and qb > qa) then
    w = m.b
  elseif outcome == "win" or outcome == "loss" then
    w = ((outcome == "win") == mine_a) and m.a or m.b
  end
  if stage == "ko" and w == 0 then
    w = mine_a and m.b or m.a
  end
  set(m, ka, kb, qa, qb, et == true, w)
  run.k = run.k + 1
  sim_round(run, cfg, mk, false)
  run.last = { stage = stage, round = round }
  advance(run)
  return run.last
end

-- after an elimination, one round at a time (the player watches each): simulates the next open round (a group
-- matchday or a knockout round) and moves on. Returns the round just simulated { stage, round }, nil when the
-- tournament is over.
function T.sim_step(run, cfg, mk)
  if run.stage == "over" then
    return nil
  end
  local st = run.stage
  local rd = round_robin(st) and run.md or run.kr
  sim_round(run, cfg, mk, true)
  run.last = { stage = st, round = rd }
  if round_robin(st) then
    advance(run)
  elseif not next_round(run) then
    run.stage = "over"
  end
  return run.last
end

-- the champion's entrant id (0 = not decided): a league's first place once every matchday is played
function T.champion(run)
  if run.fmt == "league" then
    if run.stage ~= "over" then
      return 0
    end
    local t = T.table(run, 1)
    return t[1] and t[1].e or 0
  end
  local last = run.ko[#run.ko]
  if last and #last == 1 and last[1].done then
    return last[1].w
  end
  return 0
end

-- ------------------------------------------------------------------------------------------------ rounds

-- (1.5.47: T.session_index removed: unused since 1.5.5, every tournament match is written at the block's index 0)

-- the knockout round names: rounds from the end (1 = final, 2 = semi-final, 3 = quarter-final, 4 = last 16,
-- 5 = last 32): the text key suffix of a round
function T.ko_rounds(run)
  local n = run.fmt == "groups" and run.size / 2 or run.size
  local r = 0
  while n > 1 do
    r = r + 1
    n = n / 2
  end
  return r
end

function T.round_from_end(run, r)
  return T.ko_rounds(run) - r + 1
end

return T
