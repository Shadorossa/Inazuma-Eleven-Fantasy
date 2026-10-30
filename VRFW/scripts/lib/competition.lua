-- Football competitions for mod scripts: round-robin calendars, standings tables, seeded goal counts, knockout rounds
-- and the knockout tree view drawn by the bracket screen (menu Lua VRFW_Bracket). Mechanism only: the points, the
-- tie-breaks, the match model and the random numbers are the caller's.
--   local Competition = require "VRFW/lib/competition"
--   Competition.round_robin(teams, opts)      -> days: { { { home, away }, ... } per matchday } (circle method)
--   Competition.standings(teams, results, opts) -> rows sorted best first
--   Competition.poisson(uniform, mean, cap)    -> a goal count of mean `mean` (uniform() = a number in [0, 1))
--   Competition.is_power_of_two(n)             -> true for 2, 4, 8, ...
--   Competition.seed_order(n)                  -> the standard seed order of n leaves (seeds 1 and 2 meet in the final)
--   Competition.next_round(winners, seed)      -> the next round's pairs of a list of winners
--   Competition.bracket_view(bracket)          -> a view of kind "tree" for the bracket screen

local Competition = {}

local floor, exp = math.floor, math.exp

-- ------------------------------------------------------------------------------------------------ calendars

-- teams (in draw order), opts { double = every pairing twice with the sides swapped, rotate = "right" (default) or
-- "left": the way the circle turns each matchday } -> days. The first team stays in place, the others turn one place a
-- matchday; an odd count adds a rest (team 0, its pairs left out). Home sides alternate: the first pair by matchday,
-- the others by their place, so home and away even out.
function Competition.round_robin(teams, opts)
  opts = type(opts) == "table" and opts or {}
  local list = {}
  for i, t in ipairs(teams or {}) do
    list[i] = t
  end
  if #list % 2 == 1 then
    list[#list + 1] = 0
  end
  local n = #list
  local turn = opts.rotate == "left" and 1 or -1
  local days = {}
  for r = 1, n - 1 do
    local line = { list[1] }
    for i = 1, n - 1 do
      line[i + 1] = list[(i - 1 + turn * (r - 1)) % (n - 1) + 2]
    end
    local day = {}
    for i = 1, n / 2 do
      local a, b = line[i], line[n + 1 - i]
      if (i == 1 and r % 2 == 0) or (i > 1 and i % 2 == 0) then
        a, b = b, a
      end
      if a ~= 0 and b ~= 0 then
        day[#day + 1] = { a, b }
      end
    end
    days[#days + 1] = day
  end
  if opts.double then
    local first = #days
    for r = 1, first do
      local day = {}
      for _, m in ipairs(days[r]) do
        day[#day + 1] = { m[2], m[1] }
      end
      days[#days + 1] = day
    end
  end
  return days
end

-- ------------------------------------------------------------------------------------------------ standings

local DEFAULT_POINTS = { win = 3, draw = 1, loss = 0 }
local DEFAULT_TIEBREAKS = { "points", "goal_diff", "goals_for", "order" }

-- the head-to-head between two rows: the points of their matches, then their goal difference; nil when level
local function head_to_head(x, y, results, points)
  local px, py, gx, gy = 0, 0, 0, 0
  for _, r in ipairs(results) do
    local fx, fy
    if r[1] == x.team and r[2] == y.team then
      fx, fy = r[3], r[4]
    elseif r[1] == y.team and r[2] == x.team then
      fx, fy = r[4], r[3]
    end
    if fx then
      gx, gy = gx + fx, gy + fy
      if fx > fy then
        px, py = px + points.win, py + points.loss
      elseif fy > fx then
        px, py = px + points.loss, py + points.win
      else
        px, py = px + points.draw, py + points.draw
      end
    end
  end
  if px ~= py then
    return px > py
  end
  if gx ~= gy then
    return gx > gy
  end
  return nil
end

-- teams (in draw order), results { { home, away, home goals, away goals }, ... } (played matches only), opts:
--   points    = { win, draw, loss } (default 3 / 1 / 0)
--   tiebreaks = the sort keys in order (default points, goal_diff, goals_for, order): "points", "goal_diff",
--               "goals_for", "head_to_head" (the points, then the goal difference of the two teams' matches), "lot"
--               (opts.lot[team], lower first), "order" (the place in `teams`), or a function(x, y) -> true / false / nil
-- -> rows { team, played, won, drawn, lost, goals_for, goals_against, goal_diff, points, order }, best first
function Competition.standings(teams, results, opts)
  opts = type(opts) == "table" and opts or {}
  local points = opts.points or DEFAULT_POINTS
  local tiebreaks = opts.tiebreaks or DEFAULT_TIEBREAKS
  local lot = opts.lot or {}
  results = results or {}
  local rows, by = {}, {}
  for i, t in ipairs(teams or {}) do
    rows[i] = { team = t, played = 0, won = 0, drawn = 0, lost = 0, goals_for = 0, goals_against = 0, goal_diff = 0,
      points = 0, order = i }
    by[t] = rows[i]
  end
  for _, r in ipairs(results) do
    local h, a = by[r[1]], by[r[2]]
    local hg, ag = tonumber(r[3]) or 0, tonumber(r[4]) or 0
    if h and a then
      h.played, a.played = h.played + 1, a.played + 1
      h.goals_for, h.goals_against = h.goals_for + hg, h.goals_against + ag
      a.goals_for, a.goals_against = a.goals_for + ag, a.goals_against + hg
      if hg > ag then
        h.won, a.lost = h.won + 1, a.lost + 1
        h.points, a.points = h.points + points.win, a.points + points.loss
      elseif hg < ag then
        a.won, h.lost = a.won + 1, h.lost + 1
        a.points, h.points = a.points + points.win, h.points + points.loss
      else
        h.drawn, a.drawn = h.drawn + 1, a.drawn + 1
        h.points, a.points = h.points + points.draw, a.points + points.draw
      end
    end
  end
  for _, x in ipairs(rows) do
    x.goal_diff = x.goals_for - x.goals_against
  end
  local higher = { points = true, goal_diff = true, goals_for = true }
  table.sort(rows, function(x, y)
    for _, key in ipairs(tiebreaks) do
      if type(key) == "function" then
        local better = key(x, y)
        if better ~= nil then
          return better
        end
      elseif higher[key] then
        if x[key] ~= y[key] then
          return x[key] > y[key]
        end
      elseif key == "head_to_head" then
        local better = head_to_head(x, y, results, points)
        if better ~= nil then
          return better
        end
      elseif key == "lot" then
        local lx, ly = lot[x.team] or 0, lot[y.team] or 0
        if lx ~= ly then
          return lx < ly
        end
      elseif key == "order" then
        if x.order ~= y.order then
          return x.order < y.order
        end
      end
    end
    return false
  end)
  return rows
end

-- ------------------------------------------------------------------------------------------------ matches

-- a goal count drawn from a Poisson law of mean `mean` with the caller's uniform numbers, at most cap + 1 draws
function Competition.poisson(uniform, mean, cap)
  local limit, k, p = exp(-mean), 0, 1
  repeat
    k = k + 1
    p = p * uniform()
  until p <= limit or k > cap
  return k - 1
end

-- ------------------------------------------------------------------------------------------------ knockouts

function Competition.is_power_of_two(n)
  if type(n) ~= "number" or n < 2 or n ~= floor(n) then
    return false
  end
  while n % 2 == 0 do
    n = n / 2
  end
  return n == 1
end

-- the standard seed order of n leaves (n a power of two, 1 = the best seed): 1, n/2 + 1, ... so that seeds 1 and 2
-- meet only in the final
function Competition.seed_order(n)
  local order = { 1 }
  while #order < n do
    local m = #order * 2
    local next_order = {}
    for _, s in ipairs(order) do
      next_order[#next_order + 1] = s
      next_order[#next_order + 1] = m + 1 - s
    end
    order = next_order
  end
  return order
end

-- the next round of a knockout: the winners of matches 1-2, 3-4, ... meet; seed[team] lower = the better team, at home
function Competition.next_round(winners, seed)
  seed = seed or {}
  local out = {}
  for i = 1, #winners - 1, 2 do
    local a, b = winners[i], winners[i + 1]
    if (seed[b] or 999) < (seed[a] or 999) then
      a, b = b, a
    end
    out[#out + 1] = { a, b }
  end
  return out
end

-- The knockout tree as the bracket screen draws it. bracket:
--   rounds  = R (the final is round R)
--   leaves  = the entrants of round 1 in tree order (2^R of them) (match t of round 1 = leaves 2t-1 and 2t; the first half is the
--             left side): a team id (0 = an empty slot) or { team, me }
--   me      = the player's team (a leaf is `me` when its team is this one, unless the leaf says)
--   match(r, t, upper, lower) -> nil (not played) or { w = 0 | 1 (upper won) | 2 (lower won), score = false |
--             { ga, gb, pa, pb, et } } (the upper team's goals first); upper / lower are the teams the tree brings to
--             that match (0 = not known yet)
--   champion = the champion's team (default 0)
--   next_from = a round number: view.next = the player's next rival, looked up from that round on (both teams known,
--             the match not played; 0 = none); nil = no view.next
-- -> { kind = "tree", rounds, leaves[i] = { team, me, out, won }, matches[r][t] = { w, score }, champion[, next] }
function Competition.bracket_view(bracket)
  local R = bracket.rounds
  local next_from = tonumber(bracket.next_from)
  local v = { kind = "tree", rounds = R, leaves = {}, matches = {}, champion = bracket.champion or 0 }
  if next_from then
    v.next = 0
  end
  -- the tree's entrants as leaf indexes (0 = not known yet)
  local at = {}
  for i = 1, #bracket.leaves do
    local leaf = bracket.leaves[i]
    local team, me
    if type(leaf) == "table" then
      team, me = leaf.team or 0, leaf.me
    else
      team = leaf or 0
    end
    if me == nil then
      me = team ~= 0 and team == bracket.me
    end
    v.leaves[i] = { team = team, me = me == true, out = false, won = 0 }
    at[i] = team ~= 0 and i or 0
  end
  local function team_of(i)
    return i ~= 0 and v.leaves[i].team or 0
  end
  for r = 1, R do
    local row, winners = {}, {}
    for t = 1, #at / 2 do
      local a, b = at[2 * t - 1], at[2 * t]
      local ta, tb = team_of(a), team_of(b)
      local m = bracket.match(r, t, ta, tb)
      local w = 0
      if m then
        row[t] = { w = m.w or 0, score = m.score or false }
        w = m.w or 0
      else
        row[t] = { w = 0, score = false }
      end
      local won = w == 1 and a or (w == 2 and b or 0)
      local lost = w == 1 and b or (w == 2 and a or 0)
      if won ~= 0 then
        v.leaves[won].won = v.leaves[won].won + 1
      end
      if lost ~= 0 then
        v.leaves[lost].out = true
      end
      if next_from and r >= next_from and m == nil and ta ~= 0 and tb ~= 0 then
        if v.leaves[a].me then
          v.next = tb
        elseif v.leaves[b].me then
          v.next = ta
        end
      end
      winners[t] = won
    end
    v.matches[r], at = row, winners
  end
  return v
end

return Competition
