-- The board's objectives of a career season (config [board]): set at the season's start from the club's place in the
-- career's rating order, two warnings while the season is played, the verdict when it ends. A missed league objective
-- plus one other missed objective sacks the player when the career's «sacking» option is on.
--   targets: { superliga = place, league = place, frontier = the round to reach ("" = none), band = band index }
--   c.board: { season, rank, clubs, superliga, league, frontier, band, warned = { [stage] = true } }
-- The rounds of the Fútbol Frontier in order (c.reached): a target is met when the club reached it or a later one.

local M = {}

local floor = math.floor

local ROUNDS = { "SuperLiga", "League", "Playoff", "Round32", "Round16", "Quarter", "Semi", "Final", "Champion" }
local ROUND_INDEX = {}
for i, r in ipairs(ROUNDS) do ROUND_INDEX[r] = i end

-- config [board]: the bands from the best clubs down; each { top_share, superliga_share, league, frontier }
function M.config(env)
  local bands = {}
  for _, b in ipairs(type(env.config("board.bands", nil)) == "table" and env.config("board.bands", nil) or {}) do
    if type(b) == "table" and tonumber(b.top_share) then
      bands[#bands + 1] = { top_share = tonumber(b.top_share), superliga_share = tonumber(b.superliga_share) or 1,
        league = floor(tonumber(b.league) or 0), frontier = type(b.frontier) == "string" and b.frontier or "" }
    end
  end
  table.sort(bands, function(a, b) return a.top_share < b.top_share end)
  return { bands = bands, warn_league_after = tonumber(env.config("board.warn_league_after", 0.5)) or 0.5 }
end

-- the objectives of the club ranked `rank` of `clubs` by rating (1 = the best)
function M.targets(env, rank, clubs)
  local cfg = M.config(env)
  clubs = math.max(1, floor(tonumber(clubs) or 1))
  local share = math.max(1, floor(tonumber(rank) or clubs)) / clubs
  local band, k = cfg.bands[#cfg.bands], #cfg.bands
  for i, b in ipairs(cfg.bands) do
    if share <= b.top_share then band, k = b, i break end
  end
  if band == nil then return nil end
  -- the SuperLiga target never past the places that go on to the leagues (env.qualify)
  local last = env.qualify and math.max(1, math.min(clubs, env.qualify(clubs))) or clubs
  return { superliga = math.max(1, math.min(last, math.ceil(band.superliga_share * clubs))), league = band.league,
    frontier = ROUND_INDEX[band.frontier] and band.frontier or "", band = k }
end

-- the season's objectives set (season start): rank among the career's clubs by rating
function M.start(env, c, rank, clubs)
  local t = M.targets(env, rank, clubs)
  if t == nil then
    c.board = nil
    return
  end
  c.board = { season = c.season, rank = rank, clubs = clubs, superliga = t.superliga, league = t.league,
    frontier = t.frontier, band = t.band, warned = {} }
end

-- (place, league place, reached) -> each objective met: { superliga, league, frontier } (true / false)
local function met(b, place, lplace, reached)
  return {
    superliga = place > 0 and place <= b.superliga,
    league = b.league <= 0 or (lplace > 0 and lplace <= b.league),
    frontier = b.frontier == "" or (ROUND_INDEX[reached] or 0) >= (ROUND_INDEX[b.frontier] or 0),
  }
end

-- the objectives as the hub and the setup screen draw them: { { kind, target, state } }, state = "met" / "missed" /
-- "open"; now = { place, lplace, reached, phase }
function M.view(b, now)
  if type(b) ~= "table" then return false end
  now = now or {}
  local phase = now.phase or ""
  local done = { superliga = phase ~= "superliga" and phase ~= "", league = phase == "frontier" or phase == "over"
    or phase == "worldcup" or phase == "sacked" or now.out == true, frontier = phase == "over" or phase == "worldcup"
    or phase == "sacked" or now.out == true }
  local m = met(b, tonumber(now.place) or 0, tonumber(now.lplace) or 0, now.reached or "")
  local function state(kind)
    if not done[kind] then return "open" end
    return m[kind] and "met" or "missed"
  end
  local out = { { kind = "superliga", target = b.superliga, state = state("superliga") },
    { kind = "league", target = b.league, state = state("league") } }
  if b.frontier ~= "" then out[#out + 1] = { kind = "frontier", target = b.frontier, state = state("frontier") } end
  return out
end

-- the warnings while the season is played (after each round): the SuperLiga place missed once the SuperLiga is
-- over, the league place missed past config warn_league_after of the matchdays. -> the warning to give or nil:
-- { stage, target, now }
function M.warning(env, c, place, lplace)
  local b = c.board
  if type(b) ~= "table" or b.season ~= c.season then return nil end
  b.warned = b.warned or {}
  if not b.warned.superliga and c.phase ~= "superliga" and (c.sl and (c.sl.place or 0) > 0) then
    b.warned.superliga = true
    if c.sl.place > b.superliga then return { stage = "superliga", target = b.superliga, now = c.sl.place } end
  end
  if not b.warned.league and c.phase == "league" and not c.out and b.league > 0 and c.lg and (c.lg.matchdays or 0) > 0
      and (c.lg.matchday - 1) >= math.ceil(c.lg.matchdays * M.config(env).warn_league_after) then
    b.warned.league = true
    if lplace == 0 or lplace > b.league then return { stage = "league", target = b.league, now = lplace } end
  end
  return nil
end

-- the season's verdict: { superliga, league, frontier = met, missed = count, sacked }; sacking = the career's option
function M.verdict(c, place, lplace, reached, sacking)
  local b = c.board
  if type(b) ~= "table" or b.season ~= c.season then return nil end
  local m = met(b, place, lplace, reached)
  local missed = 0
  for _, v in pairs(m) do if not v then missed = missed + 1 end end
  m.missed = missed
  m.sacked = sacking == true and not m.league and missed >= 2
  return m
end

return M
