-- Career mode season (docs/game/mods/career-mode-proposal.md §8): the SuperLiga (a Swiss system), the pots that deal
-- the leagues, the leagues' calendars, the Fútbol Frontier bracket and the simulated results. Every number comes from
-- config.toml ([superliga], [leagues], [frontier], [sim]); every draw is seeded from the career, so a reload never
-- changes it. A result is { home, away, home goals, away goals, penalties winner (0 = none), home kicks scored, away
-- kicks scored } (the kicks only after a shoot-out; results of older saves have none).
local Competition = require "VRFW/lib/competition"

local M = {}

local floor = math.floor

-- ------------------------------------------------------------------------------------------------ results

-- the standings of `teams` from results (Competition.standings), with the clubs that met (met[a][b] = true) and each
-- club's home and away counts
local function tally(teams, results, points)
  local met, home, away = {}, {}, {}
  for _, t in ipairs(teams) do
    met[t], home[t], away[t] = {}, 0, 0
  end
  for _, r in ipairs(results) do
    local h, a = r[1], r[2]
    if met[h] and met[a] then
      met[h][a], met[a][h] = true, true
      home[h], away[a] = home[h] + 1, away[a] + 1
    end
  end
  return Competition.standings(teams, results, { points = points }), met, home, away
end
M.tally = tally

-- a seeded Poisson draw of mean `mean`
local function poisson(rng, mean, cap)
  return Competition.poisson(function() return rng:float() end, mean, cap)
end

-- a simulated match: home, away, ratings (team -> number), sim config, rng, knockout -> result
function M.simulate(home, away, ratings, sim, rng, knockout)
  local rh, ra = ratings[home] or sim.default_rating, ratings[away] or sim.default_rating
  rh, ra = math.max(1, rh), math.max(1, ra)
  local mh = sim.goals * (rh / ra) ^ sim.power * sim.home_advantage
  local ma = sim.goals * (ra / rh) ^ sim.power
  local hg, ag = poisson(rng, mh, sim.max_goals), poisson(rng, ma, sim.max_goals)
  local pens, kh, ka = 0, 0, 0
  if knockout and hg == ag then
    pens, kh, ka = M.penalties(home, away, ratings, sim, rng)
  end
  return { home, away, hg, ag, pens, kh, ka }
end

-- a simulated penalty shoot-out -> the winner (the stronger club wins more often, by sim.penalties_power), the kicks
-- scored by the home and the away club: both clubs kick alike (sim.penalty_kick scored, sim.penalty_kicks each before
-- sudden death), the winner's count the higher one
function M.penalties(home, away, ratings, sim, rng)
  local rh = math.max(1, ratings[home] or sim.default_rating) ^ sim.penalties_power
  local ra = math.max(1, ratings[away] or sim.default_rating) ^ sim.penalties_power
  local winner = rng:float() < rh / (rh + ra) and home or away
  local a, b = 0, 0
  for i = 1, sim.penalty_kicks * 6 do
    if rng:float() < sim.penalty_kick then a = a + 1 end
    if rng:float() < sim.penalty_kick then b = b + 1 end
    if i >= sim.penalty_kicks and a ~= b then break end
  end
  if a == b then a = a + 1 end
  local hi, lo = math.max(a, b), math.min(a, b)
  if winner == home then return winner, hi, lo end
  return winner, lo, hi
end

-- the winner of a knockout result
function M.winner(r)
  if r[3] > r[4] then return r[1] end
  if r[4] > r[3] then return r[2] end
  return r[5] ~= 0 and r[5] or r[1]
end

-- ------------------------------------------------------------------------------------------------ SuperLiga

-- the next Swiss round of `teams` (ids in the seeded order): clubs paired top down by the standings among the ones
-- they have not met; the club with fewer home matches so far plays at home (ties: the higher place). An odd count
-- leaves the lowest club without a rest out. -> { { home, away } }, rest (0 = none), rematches
function M.swiss_round(teams, results, rests, points, rng)
  local rows, met, home, away = tally(teams, results, points)
  local list = {}
  for i, r in ipairs(rows) do list[i] = r.team end
  local rest = 0
  if #list % 2 == 1 then
    for i = #list, 1, -1 do
      if not rests[list[i]] then
        rest = table.remove(list, i)
        break
      end
    end
    if rest == 0 then rest = table.remove(list) end
  end
  local pairs_, free = {}, {}
  for _, t in ipairs(list) do free[#free + 1] = t end
  local rematches = 0
  while #free > 0 do
    local a = table.remove(free, 1)
    local pick = nil
    for j, b in ipairs(free) do
      if not met[a][b] then
        pick = j
        break
      end
    end
    if pick == nil then
      -- swap with an earlier pair (from the bottom up) so both new pairs are first meetings
      for k = #pairs_, 1, -1 do
        local x, y = pairs_[k][1], pairs_[k][2]
        local b = free[1]
        if b and not met[a][x] and not met[b][y] then
          pairs_[k] = { x, a }
          pairs_[#pairs_ + 1] = { y, table.remove(free, 1) }
          pick = 0
          break
        elseif b and not met[a][y] and not met[b][x] then
          pairs_[k] = { y, a }
          pairs_[#pairs_ + 1] = { x, table.remove(free, 1) }
          pick = 0
          break
        end
      end
      if pick == nil then
        pick = 1
        rematches = rematches + 1
      end
    end
    if pick > 0 then
      pairs_[#pairs_ + 1] = { a, table.remove(free, pick) }
    end
  end
  local out = {}
  for _, p in ipairs(pairs_) do
    local a, b = p[1], p[2]
    local ba, bb = home[a] - away[a], home[b] - away[b]
    if bb < ba or (bb == ba and rng:below(2) == 1) then a, b = b, a end
    out[#out + 1] = { a, b }
  end
  return out, rest, rematches
end

-- ------------------------------------------------------------------------------------------------ pots and leagues

-- the qualified clubs (SuperLiga order) into pots of `count` (pot k = places (k-1)*count+1 .. k*count) and `count`
-- leagues with one club of each pot; two clubs of one family never share a league when a swap inside the pot avoids
-- it. -> pots = { { ids } }, leagues = { { ids } } (league l holds the l-th club of every shuffled pot, pot order)
-- the pot of the qualified place `place` (1-based, SuperLiga order) with `count` leagues and `qualified` clubs going
-- through: places 1..count fill pot 1, the next count pot 2, ...; nil past the qualified places
function M.pot_of(place, count, qualified)
  if count < 1 or place < 1 or place > floor(qualified / count) * count then return nil end
  return floor((place - 1) / count) + 1
end

-- the swatch of pot k among `colours` pot colours (config.toml [pots]: cycled past the last): its TINT name
function M.pot_tint(pot, colours)
  if pot == nil or colours < 1 then return nil end
  return "pot" .. ((pot - 1) % colours + 1)
end

function M.deal(qualified, count, family, rng)
  local pots, leagues = {}, {}
  for l = 1, count do leagues[l] = {} end
  for i, t in ipairs(qualified) do
    local k = M.pot_of(i, count, #qualified)
    if k then
      pots[k] = pots[k] or {}
      pots[k][#pots[k] + 1] = t
    end
  end
  for k = 1, #pots do
    local pot = {}
    for i, t in ipairs(pots[k]) do pot[i] = t end
    rng:shuffle(pot)
    for l = 1, count do
      local fam = family[pot[l]]
      local clash = false
      for _, t in ipairs(leagues[l]) do
        if family[t] == fam then clash = true end
      end
      if clash then
        for j = l + 1, count do
          local ok = true
          for _, t in ipairs(leagues[l]) do
            if family[t] == family[pot[j]] then ok = false end
          end
          for _, t in ipairs(leagues[j]) do
            if family[t] == fam then ok = false end
          end
          if ok then
            pot[l], pot[j] = pot[j], pot[l]
            break
          end
        end
      end
      leagues[l][#leagues[l] + 1] = pot[l]
    end
  end
  return pots, leagues
end

-- the matchdays of a league (Competition.round_robin, the league's pot order)
function M.league_days(teams, double)
  return Competition.round_robin(teams, { double = double })
end

-- ------------------------------------------------------------------------------------------------ Fútbol Frontier

-- the largest power of two not over n (1 for n < 2)
local function power_below(n)
  local p = 1
  while p * 2 <= n do p = p * 2 end
  return p
end
M.power_below = power_below

-- clubs of several leagues ranked against each other: by place, then points per match, goal difference, goals for,
-- league order. list = { { team, league, place } }, rows[l][place] = standing row (Competition.standings)
local function ranked(list, rows)
  local function row(x) return rows and rows[x.league] and rows[x.league][x.place] or {} end
  local function per_match(r) return (r.points or 0) / math.max(1, r.played or 0) end
  table.sort(list, function(a, b)
    if a.place ~= b.place then return a.place < b.place end
    local ra, rb = row(a), row(b)
    if per_match(ra) ~= per_match(rb) then return per_match(ra) > per_match(rb) end
    if (ra.goal_diff or 0) ~= (rb.goal_diff or 0) then return (ra.goal_diff or 0) > (rb.goal_diff or 0) end
    if (ra.goals_for or 0) ~= (rb.goals_for or 0) then return (ra.goals_for or 0) > (rb.goals_for or 0) end
    return a.league < b.league
  end)
  return list
end

-- the play-off round: place p of league l against place (low + high - p) of league l + (p - low + 1) (another league
-- whenever there are two or more); the better place plays at home. standings = { [l] = { team ids by place } }
-- -> { { home, away, league_home, league_away } } (place `low` first, league order), direct = { { team, league, place } }
-- When the direct clubs and the play-off winners are no power of two (a league count with a factor 3), the knockout
-- takes the largest power of two below: the direct clubs, then play-off matches between the best ranked clubs of the
-- play-off places (`ranked`: the best against the worst, another league whenever it can); too many direct clubs: the
-- best ranked of them and no play-off. rows = { [l] = { standing rows by place } } for the ranking
local function frontier_regular(standings, cfg)
  local n = #standings
  local direct, playoff = {}, {}
  for p = 1, cfg.direct_places do
    for l = 1, n do
      local t = standings[l][p]
      if t then direct[#direct + 1] = { team = t, league = l, place = p } end
    end
  end
  local low, high = cfg.playoff_places[1], cfg.playoff_places[2]
  for p = low, floor((low + high) / 2) do
    local q = low + high - p
    for l = 1, n do
      local o = (l - 1 + (p - low + 1)) % n + 1
      local a, b = standings[l][p], standings[o][q]
      if a and b then playoff[#playoff + 1] = { a, b, l, o } end
    end
  end
  return playoff, direct
end

-- the knockout of `cfg.entrants` clubs (round 1 = the round of that many): places 1..k of every league (k = entrants /
-- leagues), then the best ranked clubs of place k + 1 (`ranked`) until the count is full (a power of two, the largest
-- one the leagues fill). Round 1 pairs the best ranked against the worst (league winners first), with another league
-- whenever it can. standings / rows as in frontier_entry -> { { home, away, league_home, league_away } } (seed order)
function M.frontier_draw(standings, cfg, rows)
  local n = #standings
  if n == 0 then return {} end
  local per = floor((cfg.entrants or 0) / n)
  local list, extra = {}, {}
  for l = 1, n do
    for p = 1, per do
      local t = standings[l][p]
      if t then list[#list + 1] = { team = t, league = l, place = p } end
    end
    local t = standings[l][per + 1]
    if t then extra[#extra + 1] = { team = t, league = l, place = per + 1 } end
  end
  ranked(extra, rows)
  local fill = (cfg.entrants or 0) - #list
  for i = 1, math.min(fill, #extra) do list[#list + 1] = extra[i] end
  ranked(list, rows)
  local want = power_below(#list)
  for i = #list, want + 1, -1 do list[i] = nil end
  local high, low = {}, {}
  for i = 1, floor(#list / 2) do high[i], low[i] = list[i], list[#list + 1 - i] end
  for i = 1, #high do
    if low[i].league == high[i].league then
      for j = i + 1, #low do
        if low[j].league ~= high[i].league and low[i].league ~= high[j].league then
          low[i], low[j] = low[j], low[i]
          break
        end
      end
    end
  end
  local out = {}
  for i = 1, #high do out[i] = { high[i].team, low[i].team, high[i].league, low[i].league } end
  return out
end

function M.frontier_entry(standings, cfg, rows)
  local playoff, direct = frontier_regular(standings, cfg)
  local size = #direct + #playoff
  local want = power_below(size)
  if size < 2 or want == size then return playoff, direct end
  direct = ranked(direct, rows)
  if #direct >= want then
    for i = #direct, want + 1, -1 do direct[i] = nil end
    table.sort(direct, function(a, b) if a.place ~= b.place then return a.place < b.place end return a.league < b.league end)
    return {}, direct
  end
  local need = want - #direct
  local pool = {}
  for p = cfg.playoff_places[1], cfg.playoff_places[2] do
    for l = 1, #standings do
      local t = standings[l][p]
      if t then pool[#pool + 1] = { team = t, league = l, place = p } end
    end
  end
  ranked(pool, rows)
  local n = math.min(#pool, 2 * need)
  local high, low = {}, {}
  for i = 1, floor(n / 2) do high[i], low[i] = pool[i], pool[n + 1 - i] end
  -- the worst of the low half against the best of the high half; an away side of the home side's league swapped with
  -- the next low one of another league
  for i = 1, #high do
    if low[i].league == high[i].league then
      for j = i + 1, #low do
        if low[j].league ~= high[i].league and low[i].league ~= high[j].league then
          low[i], low[j] = low[j], low[i]
          break
        end
      end
    end
  end
  playoff = {}
  for i = 1, #high do playoff[i] = { high[i].team, low[i].team, high[i].league, low[i].league } end
  table.sort(direct, function(a, b) if a.place ~= b.place then return a.place < b.place end return a.league < b.league end)
  return playoff, direct
end

-- the knockout's slots, drawn when the Fútbol Frontier starts (the round after the play-off is known from day one):
-- each direct club meets the winner of one play-off match, never a match with a club of its own league when the draw
-- allows it (the fewest such meetings otherwise); direct clubs or play-off matches left over meet each other in order.
-- direct = { { team, league } } (place order), playoff = { { home, away, league_home, league_away } } -> slots in
-- tree order, two by two the matches of the round after the play-off: { kind = "direct", team } | { kind = "playoff",
-- match = play-off match index }; the number of meetings within one league
local SLOT_SEARCH_LIMIT = 100000
function M.frontier_slots(direct, playoff, rng)
  local order = {}
  for i = 1, #playoff do order[i] = i end
  rng:shuffle(order)
  local n = math.min(#direct, #playoff)
  local function cost(d, p)
    local m = playoff[p]
    return (m[3] == d.league and 1 or 0) + (m[4] == d.league and 1 or 0)
  end
  local best, best_cost, used, now = {}, math.huge, {}, {}
  local visits = 0   -- the search's bound: past it the best draw found so far stands
  local function walk(i, total)
    visits = visits + 1
    if total >= best_cost or (visits > SLOT_SEARCH_LIMIT and best_cost < math.huge) then return end
    if i > n then
      best, best_cost = {}, total
      for k, v in ipairs(now) do best[k] = v end
      return
    end
    for _, p in ipairs(order) do
      if not used[p] then
        used[p], now[i] = true, p
        walk(i + 1, total + cost(direct[i], p))
        used[p], now[i] = nil, nil
        if best_cost == 0 then return end
      end
    end
  end
  walk(1, 0)
  local slots, taken = {}, {}
  for i = 1, n do
    slots[#slots + 1] = { kind = "direct", team = direct[i].team }
    slots[#slots + 1] = { kind = "playoff", match = best[i] }
    taken[best[i]] = true
  end
  for i = n + 1, #direct do slots[#slots + 1] = { kind = "direct", team = direct[i].team } end
  for _, p in ipairs(order) do
    if not taken[p] then slots[#slots + 1] = { kind = "playoff", match = p } end
  end
  return slots, n > 0 and best_cost or 0
end

return M
