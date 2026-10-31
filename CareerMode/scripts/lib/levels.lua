-- Career mode player levels (docs/game/mods/career-mode-levels.md): every player of a career has his own career level
-- («media», 1-99), a potential, a form (-3..+3) from his last matches and a monthly progression, kept in the career
-- (never in the game's save). The starting level is a share of a quality score among the career's players (growth rank,
-- the clubs the person plays for, his position's stats at level 99 from the game's growth table) put on the curve
-- config [levels] start_curve. The level + form is the level the engine plays him at. Nothing here names a player.
local M = {}

local floor, max, min = math.floor, math.max, math.min

local function u32(n)
  n = floor(tonumber(n) or 0) % 4294967296
  if n < 0 then n = n + 4294967296 end
  return n
end

local function hex(card) return string.format("%08X", u32(card)) end

require "VRFW/lib/basics"
local info, warn = VRFW.logger("levels")

-- ------------------------------------------------------------------------------------------------ config

local function curve(points, x)
  if #points == 0 then return 0 end
  if x <= points[1][1] then return points[1][2] end
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if x <= b[1] then
      if b[1] == a[1] then return b[2] end
      return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
    end
  end
  return points[#points][2]
end

local function points_of(v, default)
  local out = {}
  for _, p in ipairs(type(v) == "table" and v or {}) do
    if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) then
      out[#out + 1] = { tonumber(p[1]), tonumber(p[2]), tonumber(p[3]) }
    end
  end
  return #out > 0 and out or default
end

local function numbers_of(v, default)
  local out = {}
  for _, x in ipairs(type(v) == "table" and v or {}) do
    if tonumber(x) then out[#out + 1] = tonumber(x) end
  end
  return #out > 0 and out or default
end

-- config [levels] (env.config = VRFW.config of the mod) -> the rules, read once per env
function M.config(env)
  if env.levels_rules then return env.levels_rules end
  env.levels_rules = M.read_config(env)
  return env.levels_rules
end

function M.read_config(env)
  local c = function(k, d) return env.config("levels." .. k, d) end
  local n = function(k, d) return tonumber(c(k, d)) or d end
  local w = c("quality_weights", nil)
  w = type(w) == "table" and w or {}
  local f = function(k, d) return tonumber(env.config("levels.form." .. k, d)) or d end
  local v = function(k, d) return tonumber(env.config("levels.value." .. k, d)) or d end
  local stats = c("position_stats", nil)
  local mods = c("stat_mod_columns", nil)
  return {
    weight_rank = tonumber(w.rank) or 0.55, weight_fame = tonumber(w.fame) or 0.2, weight_stats = tonumber(w.stats) or 0.25,
    rank_column = tostring(env.config("squads.strength_column", "rank")),
    rank_max = n("rank_max", 5), fame_cap = max(1, n("fame_cap", 4)),
    start_curve = points_of(c("start_curve", nil), { { 0, 60 }, { 0.5, 67 }, { 0.8, 74 }, { 0.93, 81 }, { 0.98, 87 },
      { 0.995, 91 }, { 1, 94 } }),
    potential_margin = points_of(c("potential_margin", nil), { { 0, 3, 12 }, { 0.8, 3, 9 }, { 0.98, 2, 6 } }),
    max_level = n("max_level", 99), min_level = n("min_level", 1),
    squad_level = tostring(c("squad_level", "level")),
    exp_bar_neutral = max(0, min(0.99, n("exp_bar.neutral", 0.5))),
    exp_bar_with_month = c("exp_bar.with_month", true) ~= false,
    growth_table = tostring(c("growth_table", "data/common/gamedata/character/growth_table_config_*.cfg.bin")),
    growth_list = tostring(c("growth_list", "m_growthTableMainList")),
    stat_anchors = type(c("stat_anchors", nil)) == "table" and c("stat_anchors", nil)
      or { { 1, "m_growthTableLv1List" }, { 30, "m_growthTableLv30List" }, { 50, "m_growthTableMainList" },
        { 99, "m_growthTableMainList" } },
    stat_order = type(c("stat_order", nil)) == "table" and c("stat_order", nil) or { "Kc", "Cr", "Tc", "Pr", "Ps", "Ag", "It" },
    initial_file = tostring(c("initial_file", "content/career/initial_levels.toml")),
    position_stats = type(stats) == "table" and stats or { { "Ag", "Ps" }, { "Kc", "Cr" }, { "Tc", "Cr" }, { "Pr", "Ps" } },
    stat_mod_columns = type(mods) == "table" and mods or { Kc = 29, Cr = 30, Tc = 31, Pr = 32, Ps = 33, It = 34, Ag = 35 },
    position_column = n("position_column", 3), pattern_column = n("pattern_column", 7), growth_rank_column = n("growth_rank_column", 9),
    rarity_step = n("rarity_step", 4), rarity_bonus = n("rarity_bonus", 0.1), mod_stage = n("mod_stage", 20),
    form_matches = max(1, floor(n("form_matches", 5))),
    form_weights = numbers_of(c("form_weights", nil), { 1, 1, 2, 2, 3 }),
    form_scale = n("form_scale", 1.0), form_min_played = n("form_min_played", 2),
    growth_per_month = n("growth_per_month", 0.6), growth_gap = max(1, n("growth_gap", 5)),
    form_bonus = numbers_of(c("form_bonus", nil), { -0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3 }),
    bench_share = n("bench_share", 0.15), bench_decline = n("bench_decline", 0.4),
    bad_form_decline = n("bad_form_decline", 0.4),
    free_decline = n("free_decline", 0.15), free_drift = n("free_drift", 0.35),
    history_months = max(2, floor(n("history_months", 6))),
    news_min_level = n("news_min_level", 80), news_min_change = n("news_min_change", 2), news_keep = n("news_keep", 30),
    form = {
      win = f("win", 0.5), draw = f("draw", 0), loss = f("loss", -0.5), goal = f("goal", 0.6), save = f("save", 0.25),
      technique = f("technique", 0.05), technique_cap = f("technique_cap", 0.3), duel = f("duel", 0.03),
      duel_cap = f("duel_cap", 0.3), conceded = f("conceded", -0.15), red = f("red", -0.6),
      score_cap = f("score_cap", 1.5),
      sim_goal_weights = numbers_of(env.config("levels.form.sim_goal_weights", nil), { 0, 5, 3, 1 }),
      sim_noise = numbers_of(env.config("levels.form.sim_noise_by_position", nil), { 0.2, 0.4, 0.4, 0.3 }),
      sim_bench_subs = f("sim_bench_subs", 3), sub_minutes = f("sub_minutes", 30), starters = f("starters", 11),
    },
    value = {
      curve = points_of(env.config("levels.value.value_curve", nil), { { 60, 0.15 }, { 65, 0.3 }, { 70, 0.5 },
        { 75, 0.8 }, { 80, 1.3 }, { 85, 2.0 }, { 90, 3.2 }, { 94, 4.5 }, { 99, 7.0 } }),
      pot_weight = v("pot_weight", 0.03), pot_cap = v("pot_cap", 1.3), form_weight = v("form_weight", 0.04),
      trend_weight = v("trend_weight", 0.03), trend_min = v("trend_min", 0.85), trend_max = v("trend_max", 1.25),
      trend_months = v("trend_months", 3),
      -- by main position (1 GK, 2 FW, 3 MF, 4 DF)
      position = numbers_of(env.config("levels.value.position", nil), { 1, 1, 1, 1 }),
    },
  }
end

-- ------------------------------------------------------------------------------------------------ initial levels

-- the initial levels file (config [levels] initial_file, generated by research/scripts/career_levels_build.py): by
-- card { level, share }, the qualities in file order (ascending) with their shares, the stats' scale; read once
local INITIAL = nil
local function initial(cfg)
  if INITIAL then return INITIAL end
  INITIAL = { by = {}, q = {}, s = {}, low = 0, high = 0, n = 0, cards = 0 }
  local ok, doc = pcall(VRFW.files.toml, cfg.initial_file)
  local own = ok and type(doc) == "table" and doc.CareerMode or nil
  if type(own) ~= "table" then
    warn("initial levels " .. cfg.initial_file .. " not readable (" .. tostring(ok and "no [CareerMode]" or doc) ..
      "): every level computed")
    return INITIAL
  end
  for _, e in ipairs(type(own.LevelScale) == "table" and own.LevelScale or {}) do
    if type(e) == "table" then
      INITIAL.low, INITIAL.high = tonumber(e.stats_low) or 0, tonumber(e.stats_high) or 0
    end
  end
  local by, qs, ss = INITIAL.by, INITIAL.q, INITIAL.s
  local n = 0
  for _, e in ipairs(type(own.InitialLevel) == "table" and own.InitialLevel or {}) do
    local card, lvl, share = tonumber(e.card), tonumber(e.level), tonumber(e.share)
    if card and lvl and share then
      by[card % 4294967296] = { lvl, share }
      n = n + 1
      local q = tonumber(e.quality)
      if q and (#qs == 0 or q >= qs[#qs]) then qs[#qs + 1], ss[#ss + 1] = q, share end
    end
  end
  INITIAL.n, INITIAL.cards = #qs, n
  info(string.format("initial levels: %d cards from %s", n, cfg.initial_file))
  return INITIAL
end

-- ------------------------------------------------------------------------------------------------ cards

-- the game's growth table rows by "<position>:<pattern>:<rank>" (the level-99 anchors), read once
local GROWTH = nil
local function growth_rows(cfg)
  if GROWTH then return GROWTH end
  GROWTH = {}
  local ok, rows = pcall(VRFW.table.raw, cfg.growth_table, cfg.growth_list)
  if not ok or type(rows) ~= "table" then
    warn("growth table " .. cfg.growth_table .. " not readable (" .. tostring(rows) .. "): no stats in the quality")
    return GROWTH
  end
  for _, r in ipairs(rows) do
    if type(r) == "table" and tonumber(r.mainPosition) then
      local k = floor(r.mainPosition) .. ":" .. floor(tonumber(r.growthPattern) or 0) .. ":" .. floor(tonumber(r.charaRank) or 0)
      if GROWTH[k] == nil then GROWTH[k] = r end
    end
  end
  return GROWTH
end

-- every card of the game as the character index answers it ({ [card] = card table with cols }), read once (only for a
-- card missing from the initial levels file); a card's quality is worked out when it is asked for (card_of)
local RAW = nil
local function raw_cards(cfg)
  if RAW then return RAW end
  RAW = {}
  local cols = { cfg.rank_column, cfg.position_column, cfg.pattern_column, cfg.growth_rank_column }
  for _, col in pairs(cfg.stat_mod_columns) do cols[#cols + 1] = col end
  local ok, list = pcall(VRFW.chara.cards, { columns = cols, character = true })
  if not ok or type(list) ~= "table" then
    warn("character index not readable (" .. tostring(list) .. "): no levels for cards missing from the table")
    return RAW
  end
  for _, k in ipairs(list) do RAW[k.id % 4294967296] = k end
  return RAW
end

-- character -> person (the name text, else the character), read once
local PERSON = nil
local function person_of(base)
  if PERSON == nil then
    PERSON = {}
    local ok, chars = pcall(VRFW.chara.characters)
    for _, ch in ipairs(ok and type(chars) == "table" and chars or {}) do
      local nt = u32(ch.name_text)
      PERSON[u32(ch.id)] = nt ~= 0 and nt or u32(ch.id)
    end
  end
  return PERSON[u32(base)]
end

-- a card -> { rank, position, person, stats (the position's stats at level 99) }, worked out once per card
local CARDS = {}
local function card_of(cfg, card)
  card = u32(card)
  local hit = CARDS[card]
  if hit then return hit end
  local k = raw_cards(cfg)[card]
  if not k then
    hit = { rank = 0, position = 0, person = card, stats = 0 }
    CARDS[card] = hit
    return hit
  end
  local cv = type(k.cols) == "table" and k.cols or {}
  local pos = floor(tonumber(k.position) or tonumber(cv[cfg.position_column]) or 0)
  local stats = 0
  local g = growth_rows(cfg)[floor(tonumber(cv[cfg.position_column]) or pos) .. ":" .. floor(tonumber(cv[cfg.pattern_column]) or 0)
    .. ":" .. floor(tonumber(cv[cfg.growth_rank_column]) or 0)]
  local keys = cfg.position_stats[pos]
  if g and type(keys) == "table" then
    local n = 0
    for _, s in ipairs(keys) do
      local base = tonumber(g[s .. "_99"]) or 0
      local mod = tonumber(cv[cfg.stat_mod_columns[s]]) or 0
      stats = stats + base + floor(base * cfg.rarity_step * cfg.rarity_bonus) + cfg.mod_stage * mod
      n = n + 1
    end
    stats = n > 0 and stats / n or 0
  end
  hit = { rank = tonumber(cv[cfg.rank_column]) or 0, position = pos, person = person_of(k.base) or card, stats = stats }
  CARDS[card] = hit
  return hit
end

-- the position of a card (1 GK, 2 FW, 3 MF, 4 DF), asked once per card
local POSITION = {}
function M.position(env, card)
  card = u32(card)
  local p = POSITION[card]
  if p == nil then
    local ok, k = pcall(VRFW.chara.card, card)
    p = ok and type(k) == "table" and floor(tonumber(k.position) or 0) or 0
    POSITION[card] = p
  end
  return p
end

-- how many source teams (env.teams(): the teams the career reads) hold a person, read once
local FAME = nil
local function fame_of(env, cfg, person)
  if FAME == nil then
    FAME = {}
    local raw = raw_cards(cfg)
    local ok, teams = pcall(env.teams)
    for _, t in ipairs(ok and type(teams) == "table" and teams or {}) do
      local seen = {}
      for _, p in ipairs(t.players or {}) do
        local card = u32(p.card)
        local k = raw[card]
        local who = k and person_of(k.base) or card
        if not seen[who] then
          seen[who] = true
          FAME[who] = (FAME[who] or 0) + 1
        end
      end
    end
  end
  return FAME[person] or 1
end

-- the starting level and share of a card missing from the initial levels file: the generator's rule for this card alone
-- (its quality, then the share of the last file quality at or below it)
local function computed_start(env, cfg, card)
  local init = initial(cfg)
  local k = card_of(cfg, card)
  local f = min(max(fame_of(env, cfg, k.person) - 1, 0), cfg.fame_cap) / cfg.fame_cap
  local span = init.high > init.low and (init.high - init.low) or nil
  local s = span and k.stats > 0 and max(0, min(1, (k.stats - init.low) / span)) or 0
  local wr, wf, ws = cfg.weight_rank, cfg.weight_fame, span and cfg.weight_stats or 0
  local q = (wr * min(k.rank, cfg.rank_max) / cfg.rank_max + wf * f + ws * s) / max(1e-9, wr + wf + ws)
  local share = 0.5
  local qs, n = init.q, init.n
  if n > 0 then
    if q < qs[1] then
      share = 0
    elseif q >= qs[n] then
      share = init.s[n]
    else
      local lo, hi = 1, n
      while lo < hi do
        local mid = floor((lo + hi + 1) / 2)
        if qs[mid] <= q then lo = mid else hi = mid - 1 end
      end
      share = init.s[lo]
    end
  end
  return floor(curve(cfg.start_curve, share) + 0.5), share
end

-- the potential of a starting level at a share: + a draw (seeded per career and card) in the potential_margin row
local function potential_of(cfg, seed, card, lvl, share)
  local m = cfg.potential_margin[1]
  for _, p in ipairs(cfg.potential_margin) do
    if share >= p[1] then m = p end
  end
  local a, b = floor(m[2]), floor(m[3] or m[2])
  local pot = lvl + a
  if b > a then pot = lvl + VRFW.rng("CareerMode.levels.potential", { u32(seed), u32(card) }):int(a, b) end
  return max(lvl, min(cfg.max_level, pot))
end

-- a card's starting level and potential in career c: the career's own start table (careers started before the initial
-- levels file), else the file, else computed for this card alone; nil for a card of no player
local START = setmetatable({}, { __mode = "k" })   -- career -> { [card] = { level, potential } } (never saved)
local function start_of(env, cfg, c, card)
  card = u32(card)
  local own = type(c.levels) == "table" and type(c.levels.start) == "table" and c.levels.start[hex(card)]
  if own then return own[1], own[2] end
  local cache = START[c]
  if cache == nil then
    cache = {}
    START[c] = cache
  end
  local hit = cache[card]
  if hit then return hit[1], hit[2] end
  local lvl, share
  local e = initial(cfg).by[card]
  if e then
    lvl, share = e[1], e[2]
  else
    local k = card_of(cfg, card)
    if k.position < 1 or k.position > 4 then return nil end
    lvl, share = computed_start(env, cfg, card)
  end
  local pot = potential_of(cfg, c.seed, card, lvl, share)
  cache[card] = { lvl, pot }
  return lvl, pot
end

-- ------------------------------------------------------------------------------------------------ the career's record

-- c.levels = { v, p = { [hex] = { l, p, x, s = { scores ×10 }, m, a, h = { month-end levels } } } (the players a club
-- ever had), months, month, news, seq } (+ start = { [hex] = { l, p } } in careers started before the initial levels
-- file)
function M.ready(c) return type(c.levels) == "table" and c.levels.v == 1 end

-- the levels of a new career (or of a career started before levels): squads = { [i or team] = { players } }; only the
-- clubs' players get a record (a free player's level is worked out when he is asked for)
function M.build(env, c, squads)
  local cfg = M.config(env)
  local doc = { v = 1, p = {}, months = 0, month = 0, news = {}, seq = 0 }
  c.levels = doc
  local hist, from_file = {}, 0
  local by = initial(cfg).by
  for _, sq in pairs(squads) do
    for _, p in ipairs(sq.players or {}) do
      local key = hex(p.card)
      if doc.p[key] == nil then
        local lvl, pot = start_of(env, cfg, c, p.card)
        if lvl then
          doc.p[key] = { l = lvl, p = pot, x = 0, s = {}, m = 0, a = 0, h = { lvl } }
          hist[#hist + 1] = lvl
          if by[u32(p.card)] then from_file = from_file + 1 end
        end
      end
    end
  end
  table.sort(hist)
  info(string.format("career levels: %d players in clubs (%d from the initial levels, %d computed), level p10 %d, " ..
    "p50 %d, p90 %d, max %d", #hist, from_file, #hist - from_file, hist[floor(#hist * 0.1) + 1] or 0,
    hist[floor(#hist * 0.5) + 1] or 0, hist[floor(#hist * 0.9) + 1] or 0, hist[#hist] or 0))
  return doc
end

-- a free player never in a club: his starting level with the free months' drift (seeded per career, card and month)
local FREE = setmetatable({}, { __mode = "k" })   -- career -> { months, [card] = { level, potential } } (never saved)
local function free_level(env, cfg, c, card)
  local cache = FREE[c]
  if cache == nil or cache.months ~= (c.levels.months or 0) then
    cache = { months = c.levels.months or 0 }
    FREE[c] = cache
  end
  local hit = cache[u32(card)]
  if hit then return hit[1], hit[2] end
  local lvl, pot = start_of(env, cfg, c, card)
  if not lvl then return nil end
  local x = 0
  for m = 1, c.levels.months or 0 do
    local rng = VRFW.rng("CareerMode.levels.free", { u32(c.seed), u32(card), m })
    x = x - cfg.free_decline + (rng:float() * 2 - 1) * cfg.free_drift
  end
  lvl = max(cfg.min_level, min(pot, lvl + floor(x + 0.5)))
  cache[u32(card)] = { lvl, pot }
  return lvl, pot
end

-- the record of a card, made when he joins a club (or first plays); nil for an unknown card
local function record(env, cfg, c, card, make)
  local r = c.levels.p[hex(card)]
  if r or not make then return r end
  local lvl, pot = free_level(env, cfg, c, card)
  if not lvl then return nil end
  r = { l = lvl, p = pot, x = 0, s = {}, m = 0, a = 0, h = { lvl } }
  c.levels.p[hex(card)] = r
  return r
end

-- the form of a record: the weighted mean of its last scores, on -3..+3 (0 with too few matches played)
local function form_of(cfg, r)
  local s = r and r.s or {}
  if #s < cfg.form_min_played then return 0 end
  local sum, wsum = 0, 0
  local first = max(1, #s - cfg.form_matches + 1)
  local w = cfg.form_weights
  for i = first, #s do
    local k = w[#w - (#s - i)] or 1
    sum, wsum = sum + k * s[i] / 10, wsum + k
  end
  if wsum == 0 then return 0 end
  return max(-3, min(3, floor(3 * sum / wsum / cfg.form_scale + 0.5)))
end

-- a player of the career -> { level, potential, form, effective, trend, history, scores }; nil when the career has no
-- levels or the card is no player of it
function M.player(env, c, card)
  if not M.ready(c) then return nil end
  local cfg = M.config(env)
  local r = record(env, cfg, c, card, false)
  local lvl, pot, form, hist, scores
  if r then
    lvl, pot, form, hist, scores = r.l, r.p, form_of(cfg, r), r.h or {}, r.s or {}
  else
    lvl, pot = free_level(env, cfg, c, card)
    if not lvl then return nil end
    form, hist, scores = 0, {}, {}
  end
  local back = hist[max(1, #hist - floor(cfg.value.trend_months))] or lvl
  return { level = lvl, potential = pot, form = form, effective = max(cfg.min_level, min(cfg.max_level, lvl + form)),
    trend = lvl - back, history = hist, scores = scores }
end

-- the effective levels of cards (nil = 0)
function M.effective(env, c, cards)
  local out = {}
  for i, card in ipairs(cards) do
    local p = M.player(env, c, card)
    out[i] = p and p.effective or 0
  end
  return out
end

-- the game levels of cards outside a match (the clubs' member rows, the team screen; config [levels] squad_level:
-- "level" = the career level, "match" = level + form), within min_level..max_level; a career without levels yet (the
-- club pick: c = { seed }) gives each card his starting level; nil = 0 (the card keeps the team's level)
function M.squad_levels(env, c, cards)
  local cfg = M.config(env)
  local out = {}
  for i, card in ipairs(cards) do
    local lvl
    if M.ready(c) then
      local p = M.player(env, c, card)
      lvl = p and (cfg.squad_level == "match" and p.effective or p.level) or nil
    else
      lvl = start_of(env, cfg, c, card)
    end
    out[i] = lvl and max(cfg.min_level, min(cfg.max_level, floor(lvl))) or 0
  end
  return out
end

-- a player's market value in value points (config [levels.value]): value_curve(level) x the room to his potential x
-- form x the last months' rise x his position; p = his M.player answer when the caller has it
function M.value(env, c, card, p)
  p = p or M.player(env, c, card)
  if not p then return 0 end
  local v = M.config(env).value
  local k = curve(v.curve, p.level) * min(v.pot_cap, 1 + v.pot_weight * max(0, p.potential - p.level))
    * (1 + v.form_weight * p.form) * max(v.trend_min, min(v.trend_max, 1 + v.trend_weight * p.trend))
    * (v.position[M.position(env, card)] or 1)
  return max(0, k)
end

-- ------------------------------------------------------------------------------------------------ club rating

-- a club's rating: the mean effective level of its best `count` players (its best goalkeeper among them when it has one)
function M.club_rating(env, c, cards, count)
  count = count or 11
  local keepers, field = {}, {}
  for _, card in ipairs(cards) do
    local p = M.player(env, c, card)
    if p then
      local list = M.position(env, card) == 1 and keepers or field
      list[#list + 1] = p.effective
    end
  end
  table.sort(keepers, function(a, b) return a > b end)
  table.sort(field, function(a, b) return a > b end)
  local take = {}
  if keepers[1] then take[1] = table.remove(keepers, 1) end
  for _, e in ipairs(field) do
    if #take >= count then break end
    take[#take + 1] = e
  end
  for _, e in ipairs(keepers) do
    if #take >= count then break end
    take[#take + 1] = e
  end
  if #take == 0 then return nil end
  local sum = 0
  for _, e in ipairs(take) do sum = sum + e end
  return sum / #take
end

-- ------------------------------------------------------------------------------------------------ matches

-- one match of a club: `cards` its squad, `gf` / `ga` goals for / against, `played` = { [card] = { minutes, goals,
-- saves, techniques, duels, red } } from the match (nil = simulated with `rng`) -> { [card] = minutes } and the
-- scores added to the records
local function result_term(cfg, gf, ga)
  if gf > ga then return cfg.form.win elseif gf < ga then return cfg.form.loss end
  return cfg.form.draw
end

local function score_of(cfg, pos, minutes, gf, ga, st)
  local f = cfg.form
  local s = result_term(cfg, gf, ga) * min(1, minutes / 90)
  s = s + f.goal * (st.goals or 0) + f.save * (st.saves or 0)
    + min(f.technique_cap, f.technique * (st.techniques or 0)) + min(f.duel_cap, f.duel * (st.duels or 0))
    + f.red * (st.red or 0) + (st.noise or 0)
  if pos == 1 or pos == 4 then s = s + f.conceded * ga * min(1, minutes / 90) end
  return max(-f.score_cap, min(f.score_cap, s))
end

local function add_score(cfg, r, s, minutes)
  r.s = r.s or {}
  r.s[#r.s + 1] = floor(s * 10 + (s >= 0 and 0.5 or -0.5))
  while #r.s > cfg.form_matches do table.remove(r.s, 1) end
  r.m = (r.m or 0) + minutes
end

-- the simulated side: the best `starters` by effective level play (a goalkeeper first), `sim_bench_subs` of the bench
-- come on for sub_minutes; the goals go to the players on the pitch by position weight x level
local function simulate_side(cfg, env, c, cards, gf, rng)
  local f = cfg.form
  local list = {}
  for _, card in ipairs(cards) do
    local p = M.player(env, c, card)
    list[#list + 1] = { card = card, e = p and p.effective or 0, pos = M.position(env, card) }
  end
  table.sort(list, function(a, b) if a.e ~= b.e then return a.e > b.e end return a.card < b.card end)
  local on, n, gk = {}, 0, false
  for _, x in ipairs(list) do
    if x.pos == 1 and not gk then on[#on + 1], n, gk = x, n + 1, true x.minutes = 90 end
  end
  for _, x in ipairs(list) do
    if n >= f.starters then break end
    if x.minutes == nil and x.pos ~= 1 then on[#on + 1], n = x, n + 1 x.minutes = 90 end
  end
  local bench = {}
  for _, x in ipairs(list) do if x.minutes == nil and x.pos ~= 1 then bench[#bench + 1] = x end end
  for _ = 1, min(floor(f.sim_bench_subs), #bench) do
    local k = rng:int(1, #bench)
    local x = table.remove(bench, k)
    x.minutes = f.sub_minutes
    on[#on + 1] = x
  end
  local total = 0
  for _, x in ipairs(on) do total = total + (f.sim_goal_weights[x.pos] or 0) * max(1, x.e) * x.minutes / 90 end
  local st = {}
  for _, x in ipairs(on) do st[x.card] = { minutes = x.minutes, goals = 0, pos = x.pos,
    noise = (rng:float() * 2 - 1) * (f.sim_noise[x.pos] or 0.3) } end
  for _ = 1, gf do
    if total <= 0 then break end
    local pick, acc = rng:float() * total, 0
    for _, x in ipairs(on) do
      acc = acc + (f.sim_goal_weights[x.pos] or 0) * max(1, x.e) * x.minutes / 90
      if pick <= acc then st[x.card].goals = st[x.card].goals + 1 break end
    end
  end
  return st
end

-- a round's matches: results = { { home, away, home goals, away goals, … } }, squads(team) -> cards, played =
-- { [team] = { [card] = facts } } for the clubs of the match the player played (nil = every club simulated)
-- -> the players who played: { { match (index in results), team, card, pos, minutes, goals, saves, conceded, score } }
function M.after_round(env, c, results, squads, played, rng)
  if not M.ready(c) then return {} end
  local cfg = M.config(env)
  local out = {}
  for i, r in ipairs(results or {}) do
    for side = 1, 2 do
      local team = r[side]
      local gf, ga = tonumber(r[side + 2]) or 0, tonumber(r[5 - side]) or 0
      local cards = squads(team) or {}
      if #cards > 0 then
        local st = played and played[team]
        if st == nil then st = simulate_side(cfg, env, c, cards, gf, rng) end
        for _, card in ipairs(cards) do
          local rec = record(env, cfg, c, card, true)
          if rec then
            rec.a = (rec.a or 0) + 90
            local x = st[card]
            if x and (x.minutes or 0) > 0 then
              local pos = x.pos or M.position(env, card)
              local s = score_of(cfg, pos, x.minutes, gf, ga, x)
              add_score(cfg, rec, s, x.minutes)
              out[#out + 1] = { match = i, team = team, card = card, pos = pos, minutes = x.minutes, goals = x.goals or 0,
                saves = x.saves or 0, conceded = ga, score = s }
            end
          end
        end
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ progression

local function note_change(cfg, c, card, team, from, to, day)
  local mine = team ~= 0 and team == c.team
  if not mine and to < cfg.news_min_level and math.abs(to - from) < cfg.news_min_change then return end
  c.levels.seq = (c.levels.seq or 0) + 1
  local list = c.levels.news
  list[#list + 1] = { id = c.levels.seq, card = card, team = team, from = from, to = to, day = day,
    kind = to > from and "up" or "down" }
  while #list > cfg.news_keep do table.remove(list, 1) end
end

-- a month of the calendar is over: every recorded player grows or falls; club_of(card) -> his club (0 = free); `day`
-- the day the change is dated; returns how many levels changed
-- a club player's change of this month so far (gain - loss), with form f: his share of the month's minutes x the room
-- to his potential, the form bonus, the bench and bad form declines
local function month_change(cfg, r, f)
  local share = (r.a or 0) > 0 and (r.m or 0) / r.a or 0
  local gain = cfg.growth_per_month * min(1, share) * max(0, min(1, (r.p - r.l) / cfg.growth_gap))
    + (cfg.form_bonus[f + 4] or 0) * (share > 0 and 1 or 0)
  local loss = 0
  if share < cfg.bench_share then loss = loss + cfg.bench_decline end
  if f <= -2 and (r.bad or 0) >= 1 then loss = loss + cfg.bad_form_decline end
  return gain - loss
end

-- a club player's way to his next level change, -1..+1: the points kept from the past months (+1 = one level up, -1 =
-- one down at the month's end), + this month's change so far once his club has played in it (config [levels.exp_bar]
-- with_month); 0 up at his potential / max_level, 0 down at min_level; nil for no player of the career
function M.progress(env, c, card)
  if not M.ready(c) then return nil end
  local cfg = M.config(env)
  local r = record(env, cfg, c, card, false)
  if not r then return nil end
  local x = r.x or 0
  if cfg.exp_bar_with_month and (r.a or 0) > 0 then x = x + month_change(cfg, r, form_of(cfg, r)) end
  if x > 0 and (r.l >= r.p or r.l >= cfg.max_level) then x = 0 end
  if x < 0 and r.l <= cfg.min_level then x = 0 end
  return max(-1, min(1, x))
end

-- the EXP bar fills of cards (config [levels.exp_bar]): neutral (half by default) = no change on the way, full = a level
-- up near, empty = a level down near (fill = neutral + progress x the room to that side); nil = no progress known
function M.exp_bars(env, c, cards)
  local n = M.config(env).exp_bar_neutral
  local out = {}
  for i, card in ipairs(cards) do
    local x = M.progress(env, c, card)
    if x == nil then out[i] = false
    elseif x >= 0 then out[i] = n + x * (0.99 - n)
    else out[i] = n + x * n end
  end
  return out
end

function M.month_end(env, c, club_of, day)
  if not M.ready(c) then return 0 end
  local cfg = M.config(env)
  local changed = 0
  c.levels.months = (c.levels.months or 0) + 1
  for key, r in pairs(c.levels.p) do
    local card = tonumber(key, 16) or 0
    local team = club_of(card) or 0
    local before = r.l
    if team == 0 then
      local rng = VRFW.rng("CareerMode.levels.free", { u32(c.seed), card, c.levels.months })
      r.x = (r.x or 0) - cfg.free_decline + (rng:float() * 2 - 1) * cfg.free_drift
    else
      local f = form_of(cfg, r)
      local change = month_change(cfg, r, f)
      r.bad = f <= -2 and (r.bad or 0) + 1 or 0
      r.x = (r.x or 0) + change
    end
    while r.x >= 1 and r.l < r.p and r.l < cfg.max_level do r.l, r.x = r.l + 1, r.x - 1 end
    if r.l >= r.p and r.x > 0 then r.x = 0 end
    while r.x <= -1 and r.l > cfg.min_level do r.l, r.x = r.l - 1, r.x + 1 end
    r.m, r.a = 0, 0
    r.h = r.h or {}
    r.h[#r.h + 1] = r.l
    while #r.h > cfg.history_months do table.remove(r.h, 1) end
    if r.l ~= before then
      changed = changed + 1
      note_change(cfg, c, card, team, before, r.l, day)
    end
  end
  info(string.format("month %d over: %d level change(s)", c.levels.months, changed))
  return changed
end

-- the level changes since news id `since` (career_news): { { id, card, team, from, to, day, kind } }
-- the growth table's anchor levels ({ level, rows by "<position>:<pattern>:<rank>" and by "<position>" }), read once
local ANCHORS = nil
local function anchors(cfg)
  if ANCHORS then return ANCHORS end
  ANCHORS = {}
  for _, a in ipairs(cfg.stat_anchors) do
    local by = {}
    local ok, rows = pcall(VRFW.table.raw, cfg.growth_table, tostring(a[2]))
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        if type(r) == "table" and tonumber(r.mainPosition) then
          local pos = floor(r.mainPosition)
          local full = pos .. ":" .. floor(tonumber(r.growthPattern) or -1) .. ":" .. floor(tonumber(r.charaRank) or -1)
          if by[full] == nil then by[full] = r end
          if by[tostring(pos)] == nil then by[tostring(pos)] = r end
        end
      end
    else
      warn("growth list " .. tostring(a[2]) .. " not readable (" .. tostring(rows) .. ")")
    end
    ANCHORS[#ANCHORS + 1] = { level = tonumber(a[1]) or 1, by = by }
  end
  table.sort(ANCHORS, function(x, y) return x.level < y.level end)
  return ANCHORS
end

-- a card's stats at a level (config stat_order: { { stat, value }, … }), nil when the card is unknown: the game's
-- growth table rows of his position, growth pattern and rank at the anchor levels (stat_anchors; a list without
-- pattern / rank columns: his position's row), joined by straight lines, with his card's stat modifiers and the
-- rarity bonus as the quality score counts them
function M.stats(env, card, level)
  local cfg = M.config(env)
  local k = raw_cards(cfg)[u32(card)]
  if not k then return nil end
  local cv = type(k.cols) == "table" and k.cols or {}
  local pos = floor(tonumber(cv[cfg.position_column]) or tonumber(k.position) or 0)
  local full = pos .. ":" .. floor(tonumber(cv[cfg.pattern_column]) or 0) .. ":" .. floor(tonumber(cv[cfg.growth_rank_column]) or 0)
  local rows = {}
  for _, a in ipairs(anchors(cfg)) do
    local r = a.by[full] or a.by[tostring(pos)]
    if r then rows[#rows + 1] = { a.level, r } end
  end
  if #rows == 0 then return nil end
  local out = {}
  for _, s in ipairs(cfg.stat_order) do
    local points = {}
    for _, p in ipairs(rows) do
      local v = tonumber(p[2][s .. "_" .. p[1]])
      if v then points[#points + 1] = { p[1], v } end
    end
    local base = curve(points, level)
    local mod = tonumber(cv[cfg.stat_mod_columns[s]]) or 0
    out[#out + 1] = { s, floor(base + floor(base * cfg.rarity_step * cfg.rarity_bonus) + cfg.mod_stage * mod + 0.5) }
  end
  return out
end

function M.news(c, since)
  local out = {}
  for _, n in ipairs(M.ready(c) and c.levels.news or {}) do
    if n.id > (since or 0) then out[#out + 1] = n end
  end
  return out
end

return M
