-- Battle Bay Deluxe «Reto diario» (docs/game/modes/bb-daily-challenge.md): a run of matches that is the same for every
-- player on a given UTC day, with no server. A library of campaign.lua (one VM). Declarations: content\game\
-- daily_challenge.toml (the commands), config.toml [daily_challenge] (the rules of the draw: the team pool, the match
-- count, the difficulty of each match, the seed's salt and version); the screens: graft research/grafts/
-- bb_daily_challenge (the «Campaña» row's menu, the campaign end window).
--
-- The draw: the menu gives the UTC date (VRFW_Daily.Period("day"), the framework's clock) as YYYYMMDD; the seed is the
-- framework's one seeded generator VRFW.rng(salt, { date, version }) (fnv1a64 + SplitMix64 + PCG32, integer only). The
-- pool = the team table rows whose level and key match [daily_challenge.pool], that the Battle Bay lists (enjoy rows),
-- one per team name, sorted by team key; then distinct picks with integer draws (rng:below): the player's loaned team
-- first, then one rival per match. Same mod version + same date = the same run on every PC.
-- The matches are the game's own Battle Bay campaign matches on the lent campaign block (lib/campaign_block.lua): the
-- player team, the run's rivals in order, the index = the next match. The result: the game's own (VRFW MatchResult,
-- signal vrfw.match_result). A loss keeps the run on that match (unlimited retries); the run is complete when every
-- match is won. The save blob bb_daily_challenge.json of the slot keeps today's run and, per day, done + the best run
-- (matches won, then goals for, then fewer goals against).
--
-- | Command | Args -> answers |
-- |---|---|
-- | CMND_BBD_DAILY_INFO | date (YYYYMMDD) -> table { ok, why, date, team, rivals, matches, k, results, done, best, loaded, last } |
-- | CMND_BBD_DAILY_PREPARE | date -> table { ok, why, k }: the Campaña's block kept, the run's next match written |
-- | CMND_BBD_DAILY_UNLOAD | -> true: the match request failed, the Campaña's block back |
-- | CMND_BBD_DAILY_SYNC | -> table { event = "none" | "won" | "lost" | "completed", gf, ga, k }: after a run match |
-- | CMND_BBD_DAILY_LOADED | -> true while a run match holds the block |

local U = require "lib/util"
local Block = require "lib/campaign_block"
local G = require "lib/game"
local Trophy = require "lib/trophy_celebration"

local D = {}

local BLOB = "bb_daily_challenge.json"
local CAMP_BLOB = "bb_daily_campaign.json"
local DOC_VERSION = 1

require "VRFW/lib/basics"
local info, warn = VRFW.logger("daily challenge")

-- ------------------------------------------------------------------------------------------------ config

local function cfg(key, default)
  return U.config("daily_challenge." .. key, default)
end

local function cfg_int(key, default, lo, hi)
  local v = U.int(tonumber(cfg(key, default)), default)
  if v < lo or v > hi then
    warn(string.format("config [daily_challenge] %s = %d out of %d..%d: %d used", key, v, lo, hi, default))
    return default
  end
  return v
end

local function cfg_list(key)
  local v = cfg(key, {})
  return type(v) == "table" and v or {}
end

local function settings()
  local pool_cfg = cfg("pool", {})
  pool_cfg = type(pool_cfg) == "table" and pool_cfg or {}
  local s = {
    salt = tostring(cfg("salt", "BattleBayDeluxe.DailyChallenge")),
    version = cfg_int("version", 1, 1, 1000000),
    -- 1-3 matches (config.toml [daily_challenge] matches)
    matches = cfg_int("matches", 3, 1, 3),
    keep_days = cfg_int("keep_days", 60, 1, 3650),
    level = U.int(tonumber(pool_cfg.level), 40),
    keys = type(pool_cfg.team_keys) == "table" and pool_cfg.team_keys or {},
    difficulty = {},
  }
  local d = cfg_list("difficulty")
  for i = 1, s.matches do
    local v = U.int(d[i] or d[#d], 2)
    if v < 1 or v > 4 then
      v = 2
    end
    s.difficulty[i] = v
  end
  return s
end

-- ------------------------------------------------------------------------------------------------ the pool

-- a glob of a team key (`*` any run of characters, `?` one character) as a Lua pattern
local function glob_pattern(g)
  local p = tostring(g):gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".")
  return "^" .. p .. "$"
end

local function key_matches(key, patterns)
  if #patterns == 0 then
    return true
  end
  for _, p in ipairs(patterns) do
    if key:match(p) then
      return true
    end
  end
  return false
end

-- the candidates { { team, key } } sorted by key: team table rows of the pool's level and keys, listed by the Battle Bay
-- (an enjoy row), one per team name text (the first key of a name); nil, why
local function pool(s)
  local okr, rows = pcall(VRFW.table.rows, "team/team")
  if not okr or type(rows) ~= "table" then
    return nil, "team table not readable"
  end
  local enjoy, why = G.enjoy_rows()
  if not enjoy then
    return nil, why
  end
  local listed = {}
  for _, r in ipairs(enjoy) do
    listed[U.u32(r.team)] = true
  end
  local patterns = {}
  for _, k in ipairs(s.keys) do
    patterns[#patterns + 1] = glob_pattern(k)
  end
  local out = {}
  for _, r in ipairs(rows) do
    local id = U.u32(r.id or r[1] or 0)
    local key = tostring(r.key or r[2] or "")
    local level = r.level or r[9]
    if id ~= 0 and key ~= "" and listed[id] and level == s.level and key_matches(key, patterns) then
      out[#out + 1] = { team = id, key = key, name = U.u32(r.name_text or r[4] or 0) }
    end
  end
  table.sort(out, function(a, b)
    if a.key ~= b.key then
      return a.key < b.key
    end
    return a.team < b.team
  end)
  local seen, uniq = {}, {}
  for _, c in ipairs(out) do
    local name = c.name ~= 0 and c.name or c.team
    if not seen[name] then
      seen[name] = true
      uniq[#uniq + 1] = c
    end
  end
  return uniq
end

-- ------------------------------------------------------------------------------------------------ the draw

-- n distinct candidates in draw order: a forward partial Fisher-Yates with the generator's unbiased integer draws
local function draw_distinct(rng, cands, n)
  local idx = {}
  for i = 1, #cands do
    idx[i] = i
  end
  local out = {}
  for i = 1, n do
    local j = i + rng:below(#idx - i + 1)
    idx[i], idx[j] = idx[j], idx[i]
    out[i] = cands[idx[i]]
  end
  return out
end

-- the run of `date` (YYYYMMDD): { date, team, rivals = { … }, difficulty = { … }, seed }; nil, why
local PLANS = {}
function D.plan(date)
  date = U.int(date, 0)
  if date < 19700101 or date > 99991231 then
    return nil, "date"
  end
  if PLANS[date] then
    return PLANS[date]
  end
  local s = settings()
  local cands, why = pool(s)
  if not cands then
    return nil, why
  end
  if #cands < s.matches + 1 then
    return nil, string.format("pool of %d team(s), %d needed", #cands, s.matches + 1)
  end
  local rng = VRFW.rng(s.salt, { date, s.version })
  local picks = draw_distinct(rng, cands, s.matches + 1)
  local p = { date = date, team = picks[1].team, rivals = {}, difficulty = s.difficulty, matches = s.matches }
  local names = { picks[1].key }
  for i = 2, #picks do
    p.rivals[#p.rivals + 1] = picks[i].team
    names[#names + 1] = picks[i].key
  end
  PLANS[date] = p
  info(string.format("%d: pool %d teams (level %d), salt %q version %d: team %s, rivals %s", date, #cands, s.level,
    s.salt, s.version, names[1], table.concat(names, ", ", 2)))
  return p
end

-- ------------------------------------------------------------------------------------------------ the save

local DOC, DOC_SLOT = nil, nil

local function load()
  local n = Block.slot()
  if DOC and DOC_SLOT == n then
    return DOC
  end
  DOC, DOC_SLOT = { v = DOC_VERSION, days = {} }, n
  local ok, b = pcall(VRFW.save.blob, BLOB, n)
  if ok and type(b) == "string" then
    local doc = VRFW.json.decode(b)
    if type(doc) == "table" and doc.v == DOC_VERSION then
      DOC = doc
      DOC.days = type(DOC.days) == "table" and DOC.days or {}
    else
      warn(BLOB .. " (slot " .. n .. ") unreadable: a new record")
    end
  end
  return DOC
end

-- the days kept: the newest keep_days (keys sorted, never the table's iteration order)
local function prune(doc, keep)
  local keys = {}
  for k in pairs(doc.days) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  for i = 1, #keys - keep do
    doc.days[keys[i]] = nil
  end
end

local function save()
  local doc = load()
  prune(doc, settings().keep_days)
  local ok, done, why = pcall(VRFW.save.blob_write, BLOB, VRFW.json.encode(doc), Block.slot())
  if not (ok and done) then
    warn(BLOB .. " not written: " .. tostring(ok and why or done))
  end
end

local function day_of(doc, date)
  local key = tostring(date)
  local d = doc.days[key]
  if type(d) ~= "table" then
    d = { done = false, best = { won = 0, gf = 0, ga = 0 }, attempts = 0 }
    doc.days[key] = d
  end
  return d
end

-- the run of `date` (a new one when the kept run is of another day)
local function run_of(doc, p)
  local r = doc.run
  if type(r) ~= "table" or r.date ~= p.date or r.team ~= p.team then
    r = { date = p.date, team = p.team, k = 0, results = {}, loaded = false }
    doc.run = r
  end
  return r
end

local function totals(results)
  local gf, ga = 0, 0
  for _, m in ipairs(results) do
    gf, ga = gf + (m.gf or 0), ga + (m.ga or 0)
  end
  return gf, ga
end

-- a better run: more matches won, then more goals for, then fewer goals against
local function better(won, gf, ga, best)
  if won ~= best.won then
    return won > best.won
  end
  if gf ~= best.gf then
    return gf > best.gf
  end
  return ga < best.ga
end

-- ------------------------------------------------------------------------------------------------ match events

-- one finished run match recorded: res = { gf, ga, outcome } (the game's outcome: "win", "draw", "loss"); a win moves
-- the run on and may raise the day's best run; a draw or a loss keeps the run on that match. Returns the event.
local function record(doc, r, res)
  local p = D.plan(r.date)
  local matches = p and p.matches or (#r.results + 1)
  local d = day_of(doc, r.date)
  local event
  if res.outcome == "win" then
    r.results[#r.results + 1] = { gf = res.gf, ga = res.ga }
    r.k = r.k + 1
    local gf, ga = totals(r.results)
    if better(r.k, gf, ga, d.best) then
      d.best = { won = r.k, gf = gf, ga = ga }
    end
    if r.k >= matches then
      d.done = true
      event = "completed"
    else
      event = "won"
    end
  else
    event = "lost"
  end
  r.last = { event = event, gf = res.gf, ga = res.ga, k = r.k }
  save()
  info(string.format("%d: %s %d-%d; run %d/%d, best %d won (%d-%d)%s", r.date, tostring(res.outcome), res.gf, res.ga,
    r.k, matches, d.best.won, d.best.gf, d.best.ga, d.done and ", day done" or ""))
  return event
end

local LIVE = false   -- the match being played is the run's next match (match_start saw the lent block)

VRFW.on("match_start", function()
  LIVE = false
  local r = load().run
  if type(r) == "table" and r.loaded then
    local b = Block.read()
    LIVE = b ~= nil and b.player == r.team and b.index == r.k
  end
  return nil
end)

-- the game's own result (VRFW MatchResult.last, published at the game's result builder, before the result screen and
-- before a game over): recorded at once, so the run is right whatever screen comes next
VRFW.on("signal:vrfw.match_result", function()
  if not LIVE then
    return nil
  end
  LIVE = false
  local MR = rawget(_G, "MatchResult")
  local last = MR and MR.last
  local doc = load()
  local r = doc.run
  if type(last) ~= "table" or type(r) ~= "table" or not r.loaded then
    return nil
  end
  r.seen = true
  local event = record(doc, r, { gf = U.int(last.score_for, 0), ga = U.int(last.score_against, 0),
    outcome = last.outcome })
  -- the run's last match won: the day's challenge is complete, the champions' celebration after its full time
  if event == "completed" then
    Trophy.play("daily_challenge", last)
  end
  return nil
end)

VRFW.on("slot_load", function()
  DOC, DOC_SLOT, LIVE = nil, nil, false
  return nil
end)

-- ------------------------------------------------------------------------------------------------ commands

function BattleBayDeluxe.DailyInfo(date)
  local p, why = D.plan(date)
  if not p then
    return { ok = false, why = tostring(why) }
  end
  local doc = load()
  local r = run_of(doc, p)
  local d = day_of(doc, p.date)
  return {
    ok = true, date = p.date, team = p.team, rivals = p.rivals, matches = p.matches, k = r.k, results = r.results,
    loaded = r.loaded == true, done = d.done == true, best = d.best, attempts = d.attempts or 0, last = r.last,
  }
end

function BattleBayDeluxe.DailyLoaded()
  local r = load().run
  return type(r) == "table" and r.loaded == true
end

function BattleBayDeluxe.DailyPrepare(date)
  local p, why = D.plan(date)
  if not p then
    return { ok = false, why = tostring(why) }
  end
  local doc = load()
  local r = run_of(doc, p)
  -- a completed run starts again from the first match (unlimited retries; the day keeps its best run)
  if r.k >= p.matches then
    r.k, r.results = 0, {}
    info(string.format("%d: the run starts again", p.date))
  end
  if not r.loaded and not Block.snapshot(CAMP_BLOB) then
    return { ok = false, why = "snapshot" }
  end
  local diff = p.difficulty[r.k + 1] or 2
  if not Block.write(0, diff, p.team, p.rivals, r.k) then
    Block.restore(CAMP_BLOB)
    return { ok = false, why = "block" }
  end
  r.loaded, r.seen, r.last = true, nil, nil
  local d = day_of(doc, p.date)
  d.attempts = (d.attempts or 0) + 1
  save()
  info(string.format("%d: match %d/%d, team %s vs %s, difficulty %d (the Campaña's block lent)", p.date, r.k + 1,
    p.matches, U.hex(p.team), U.hex(p.rivals[r.k + 1]), diff))
  return { ok = true, k = r.k }
end

function BattleBayDeluxe.DailyUnload()
  local doc = load()
  if type(doc.run) == "table" then
    doc.run.loaded = false
    save()
  end
  Block.restore(CAMP_BLOB)
  return true
end

function BattleBayDeluxe.DailySync()
  local doc = load()
  local r = doc.run
  if type(r) ~= "table" or not r.loaded then
    -- a kept Campaña block without a lent run (a crash between the two writes): back to the Campaña
    if Block.has_snapshot(CAMP_BLOB) then
      Block.restore(CAMP_BLOB)
    end
    return { event = "none" }
  end
  local b = Block.read()
  local seen = r.seen == true
  r.loaded, r.seen = false, nil
  Block.restore(CAMP_BLOB)
  if seen and type(r.last) == "table" then
    save()
    return { event = r.last.event, gf = r.last.gf, ga = r.last.ga, k = r.k }
  end
  -- no game result seen: the block tells a win (the index moved on) from a loss (zeroed); untouched = not played
  local touched = b ~= nil and (b.player ~= r.team or b.index ~= r.k or (b.rivals[1] or 0) == 0)
  if not touched then
    save()
    info("the lent block was not played (a cancelled load or a restart): nothing recorded")
    return { event = "none" }
  end
  local won = b.player == r.team and b.index == r.k + 1
  warn("no vrfw.match_result seen: the outcome taken from the campaign block (" .. (won and "win" or "loss") .. ")")
  local event = record(doc, r, { gf = 0, ga = 0, outcome = won and "win" or "loss" })
  return { event = event, gf = 0, ga = 0, k = r.k }
end

return D
