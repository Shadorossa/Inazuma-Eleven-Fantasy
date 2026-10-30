-- Career mode World Cup (docs/game/mods/career-mode-proposal.md §12): after the club season, in the calendar's World Cup
-- days, the national teams (one per country: config.toml [[world_cup.countries]], lib/teams.lua mark_national) play
-- groups and a single-match knockout. The format comes from the number of countries and config.toml [world_cup]
-- (group_size, advance): every country plays, in as few groups of group_size as hold them all (sizes differ by one at
-- most); the knockout is the power of two the first `advance` of each group fill best: the larger one when the next
-- places can complete it (the best of them), else the smaller one (the best of the qualified). Nothing here names a team.
local Competition = require "VRFW/lib/competition"

local M = {}

local floor, ceil = math.floor, math.ceil

-- n countries, cfg = { group_size, advance } -> { groups, per (the largest group), entrants, advance, qualified,
-- knockout (teams), group_days, knockout_rounds } or nil when fewer than four countries
function M.format(n, cfg)
  if n < 4 then return nil end
  local size = math.max(2, cfg.group_size)
  local groups = math.max(2, ceil(n / size))
  local per = ceil(n / groups)
  local advance = math.max(1, math.min(cfg.advance, per - 1))
  local qualified = groups * advance
  local knockout = 2
  while knockout * 2 <= qualified do knockout = knockout * 2 end
  -- the next places (one a group) complete the larger bracket when there are enough of them
  if knockout < qualified and knockout * 2 - qualified <= groups and advance + 1 <= floor(n / groups) then
    knockout = knockout * 2
  end
  local rounds = 0
  while 2 ^ rounds < knockout do rounds = rounds + 1 end
  return { groups = groups, per = per, entrants = n, advance = advance, qualified = qualified, knockout = knockout,
    group_days = per % 2 == 0 and per - 1 or per, knockout_rounds = rounds }
end

-- `count` days spread over the day range from .. to (the first and the last on its ends)
function M.days(from, to, count)
  local out = {}
  for i = 1, count do
    out[i] = count == 1 and from or from + floor((to - from) * (i - 1) / (count - 1) + 0.5)
  end
  return out
end

-- the entrants (team ids) by rating, the best first
function M.seeded(entrants, rating)
  local out = {}
  for i, t in ipairs(entrants) do out[i] = t end
  table.sort(out, function(a, b)
    if (rating[a] or 0) ~= (rating[b] or 0) then return (rating[a] or 0) > (rating[b] or 0) end
    return a < b
  end)
  return out
end

-- the groups drawn from pots of `count` entrants by rating (the last pot may be short: drawn into random groups) ->
-- groups = { { ids } }, matchdays = { per group: { { home, away } } per matchday }
function M.groups(seeded, count, rng)
  local groups = {}
  for g = 1, count do groups[g] = {} end
  for k = 1, #seeded, count do
    local slots = {}
    for g = 1, count do slots[g] = g end
    rng:shuffle(slots)
    for i = k, math.min(#seeded, k + count - 1) do
      local g = slots[i - k + 1]
      groups[g][#groups[g] + 1] = seeded[i]
    end
  end
  local days = {}
  for g, list in ipairs(groups) do days[g] = Competition.round_robin(list) end
  return groups, days
end

-- the bracket order of `size` seeds (1 against size, the top two seeds in opposite halves): { seed per slot }
local function seed_slots(size)
  local list = { 1, 2 }
  while #list < size do
    local nxt = {}
    for _, s in ipairs(list) do
      nxt[#nxt + 1] = s
      nxt[#nxt + 1] = 2 * #list + 1 - s
    end
    list = nxt
  end
  return list
end

-- the group stage over: rows = { per group: standings rows by place ({ team, points, goals_for, goals_against }) },
-- format -> the knockout's first round in bracket order ({ { a, b } }): the teams ranked by place, then points, goal
-- difference, goals scored, the first `knockout` in; seeded so that two teams of one group do not meet when it can be
-- avoided
function M.knockout_start(rows, format)
  local ranked, group_of = {}, {}
  for g, list in ipairs(rows) do
    for p, r in ipairs(list) do
      group_of[r.team] = g
      ranked[#ranked + 1] = { team = r.team, place = p, points = r.points or 0,
        diff = (r.goals_for or 0) - (r.goals_against or 0), goals = r.goals_for or 0, group = g }
    end
  end
  table.sort(ranked, function(a, b)
    if a.place ~= b.place then return a.place < b.place end
    if a.points ~= b.points then return a.points > b.points end
    if a.diff ~= b.diff then return a.diff > b.diff end
    if a.goals ~= b.goals then return a.goals > b.goals end
    return a.group < b.group
  end)
  local slots = seed_slots(format.knockout)
  local at = {}
  for i, s in ipairs(slots) do at[i] = ranked[s] and ranked[s].team or 0 end
  local matches = {}
  for m = 1, #at / 2 do matches[m] = { at[2 * m - 1], at[2 * m] } end
  -- one group's two teams in one match: the lower side swapped with the next match's lower side that fits
  for m, x in ipairs(matches) do
    if group_of[x[1]] == group_of[x[2]] then
      for k = 1, #matches do
        local y = matches[(m + k - 1) % #matches + 1]
        if y ~= x and group_of[y[2]] ~= group_of[x[1]] and group_of[x[2]] ~= group_of[y[1]] then
          x[2], y[2] = y[2], x[2]
          break
        end
      end
    end
  end
  return matches
end

return M
