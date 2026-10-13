-- Battle Bay Deluxe «Torneo»: what the bracket overlay draws, as data (pure: no game access; the graft
-- research/grafts/bb_tournament lays it out on screen, research/scripts/bbd_bracket_preview.py into a picture).
-- docs/game/modes/bb-tournament.md §6.
--
-- A view: { kind = "tree" | "groups" | "results" | "none", page, pages = { page ids in L1 / R1 order },
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
--   results: rows[t] (below); plates (old readers) = false | { team, me, out, won, line1 = { key, n… } or false,
--     line2 = { key, n, m, … } or false }
-- Text keys (text\rows\menu_text.toml): the graft prefixes them with evt_bbd_tn_. A key's numbers fill VALUE /
-- VALUE2 the way the retail texts do.

local T = require "lib/tourney"

local V = {}

local floor = math.floor

-- page ids
V.TREE = 0         -- the knockout tree: one page, every round of it
V.GROUPS = 10      -- the group tables (1.5.54: all groups on this one page; was 10 + p, 4 groups a page)
V.RESULTS = 20     -- the round just played: every match on one page (1.5.24; was 8 a page, 20 + p)
V.RESULTS_MAX = 16 -- matches on the results page (a 32-team knockout's first round)


-- the list of page ids, the round just played first (results), then the groups (while they matter), then the tree
function V.pages(run)
  local p = {}
  if run.last then
    local n = #V.round_matches(run, run.last.stage, run.last.round)
    for i = 0, floor((n - 1) / V.RESULTS_MAX) do
      p[#p + 1] = V.RESULTS + i
    end
  end
  if run.groups then
    p[#p + 1] = V.GROUPS
  end
  if run.ko[1] then
    p[#p + 1] = V.TREE
  end
  return p
end

-- the matches of one round: stage "groups" (round = matchday) or "ko" (round = KO round)
function V.round_matches(run, stage, round)
  local out = {}
  if stage == "groups" then
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
  if stage == "groups" then
    return { key = "md", n = round }
  end
  return { key = "ko_" .. T.round_from_end(run, round), n = 0 }
end

-- the whole knockout tree (1.5.15): every entrant of round 1 as a leaf, every match of every round with its winner
-- side and score; the graft draws the left half of the leaves on the left, the right half mirrored, the final in
-- the middle
local function tree_view(run)
  local v = { kind = "tree", title = { key = "tree", n = 0 } }
  local first = run.ko[1]
  if not first then
    v.title = { key = "tree_wait", n = 0 }
    return v
  end
  local R = T.ko_rounds(run)
  local N = 2 ^ R
  v.rounds, v.leaves, v.matches = R, {}, {}
  for j = 0, N - 1 do
    local m = first[floor(j / 2) + 1]
    local e = m and (j % 2 == 0 and m.a or m.b) or 0
    local pl = plate(run, e)
    if e ~= 0 then
      for r = 1, R do
        local mm = run.ko[r] and run.ko[r][floor(j / 2 ^ r) + 1]
        if mm and mm.done then
          if mm.w == e then
            pl.won = pl.won + 1
          elseif mm.a == e or mm.b == e then
            pl.out = true
          end
        end
      end
    end
    v.leaves[j + 1] = pl
  end
  for r = 1, R do
    local row = {}
    for t = 1, N / 2 ^ r do
      local mm = run.ko[r] and run.ko[r][t]
      local w = 0
      if mm and mm.done and mm.w ~= 0 then
        w = mm.w == mm.a and 1 or 2
      end
      row[t] = { w = w, score = score_of(mm) }
    end
    v.matches[r] = row
  end
  v.champion = run.teams[T.champion(run)] or 0
  return v
end

-- a team's group results in matchday order: "W" won, "D" drawn, "L" lost
local function form_of(run, g, e)
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

-- 1.5.24 (owner: «the results show only part of the round»): every match of the round on one page as scoreboard
-- rows (a 32-team first round = 16 rows), was 8 a page with the other half on a second page. matches[t] =
-- { a = plate, b = plate, ga, gb, pa, pb, et, done, w = 0 | 1 (a won) | 2 (b won) }; a plate's line2 is kept for the
-- old readers.
local function results_view(run, page)
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
function V.build(run, page)
  local pages = V.pages(run)
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
  if page >= V.RESULTS then
    v = results_view(run, page - V.RESULTS)
  elseif page >= V.GROUPS then
    v = groups_view(run)
  else
    v = tree_view(run)
  end
  v.page, v.pages = page, pages
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
  v.k, v.player_matches = run.k, T.player_matches(run.fmt, run.size)
  local opp = T.opponent(run)
  v.next = opp ~= 0 and run.teams[opp] or 0
  local m, st, rd = T.pending(run)
  v.next_title = m and round_title(run, st, rd) or false
  return v
end

return V
