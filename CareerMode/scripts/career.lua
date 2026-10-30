-- Career mode («Modo carrera», docs/game/mods/career-mode-proposal.md): one career per save slot, kept in the slot's save
-- blob career.json. The clubs and their squads (lib/squads.lua: every player once per career), the season (lib/
-- season.lua: SuperLiga, pots, leagues, Fútbol Frontier), the matches the player plays (the game's own result, signal
-- vrfw.match_result), the season's days (lib/calendar.lua: a date for every fixture, the transfer windows, the World
-- Cup), the World Cup after the club season (lib/worldcup.lua: the national sides, the squad the player picks) and the
-- views the hub screen (evt_career_menu) draws. Commands: content\game\commands.toml.
local Teams = require "lib/teams"
local Squads = require "lib/squads"
local Season = require "lib/season"
local Competition = require "VRFW/lib/competition"
local GameText = require "VRFW/lib/game_text"
local Calendar = require "lib/calendar"
local Worldcup = require "lib/worldcup"

CareerMode = type(CareerMode) == "table" and CareerMode or {}

local floor = math.floor
local u32, config = Teams.u32, Teams.config

local BLOB = "career.json"
local VERSION = 2

require "VRFW/lib/basics"
local info, warn = VRFW.logger("career")

local function num(path, default)
  return tonumber(config(path, default)) or default
end

local function int(path, default)
  return floor(num(path, default))
end

local function list_of(v, default)
  if type(v) ~= "table" then return default end
  local out = {}
  for _, x in ipairs(v) do
    if type(x) == "number" then out[#out + 1] = floor(x) end
  end
  return #out > 0 and out or default
end

local function squads_config()
  return {
    order_file = tostring(config("squads.order_file", "scripts/data/club_order.toml")),
    min_players = int("squads.min_players", 11),
    fill_to = int("squads.fill_to", 16),
    strength_column = tostring(config("squads.strength_column", "rank")),
    strength_reach = int("squads.strength_reach", 5),
    same_game_first = config("squads.same_game_first", true) ~= false,
    free_need_team = config("squads.free_need_team", true) ~= false,
  }
end

local function season_config()
  local playoff = list_of(config("frontier.playoff_places", nil), { 3, 6 })
  return {
    rounds = int("superliga.rounds", 12),
    qualify = int("superliga.qualify", 56),
    leagues = int("leagues.count", 4),
    double = config("leagues.double", true) ~= false,
    direct_places = int("frontier.direct_places", 2),
    playoff_places = { playoff[1] or 3, playoff[2] or 6 },
  }
end

local function sim_config(ratings_median)
  return {
    goals = num("sim.goals", 1.35),
    power = num("sim.power", 1.2),
    home_advantage = num("sim.home_advantage", 1.15),
    max_goals = int("sim.max_goals", 9),
    penalties_power = num("sim.penalties_power", 0.5),
    penalty_kick = num("sim.penalty_kick", 0.75),
    penalty_kicks = int("sim.penalty_kicks", 5),
    default_rating = ratings_median or 1,
  }
end

local function worldcup_config()
  return {
    enabled = config("world_cup.enabled", true) ~= false,
    group_size = int("world_cup.group_size", 4),
    advance = int("world_cup.advance", 2),
    squad = int("world_cup.squad", 16),
    keepers = int("world_cup.keepers", 2),
  }
end

local function points_config()
  return {
    win = num("standings.win", 3),
    draw = num("standings.draw", 1),
    loss = num("standings.loss", 0),
  }
end

-- the club card's rules (config.toml [rating]) the screen applies to the game's stats
local function rating_rules()
  return {
    stats = list_of(config("rating.stats", nil), { 0, 1, 2, 3, 4, 5, 6 }),
    starter_places = int("rating.starter_places", 11),
    attack = list_of(config("rating.attack", nil), { 2 }),
    midfield = list_of(config("rating.midfield", nil), { 3 }),
    defence = list_of(config("rating.defence", nil), { 4 }),
    goalkeeper = list_of(config("rating.goalkeeper", nil), { 1 }),
    stars_min = num("rating.stars_min", 1),
    stars_max = num("rating.stars_max", 5),
    stars_step = num("rating.stars_step", 0.5),
    best_players = int("rating.best_players", 5),
  }
end

-- the hub's tabs of a phase (config.toml [hub] tabs; a tab with `phases` shows only in those): { id, text, icon }
local function hub_tabs(phase)
  local out = {}
  local v = config("hub.tabs", nil)
  for _, t in ipairs(type(v) == "table" and v or {}) do
    if type(t) == "table" and type(t.id) == "string" and t.id ~= "" then
      local show = type(t.phases) ~= "table"
      for _, p in ipairs(type(t.phases) == "table" and t.phases or {}) do
        if p == phase then show = true end
      end
      if show then out[#out + 1] = { id = t.id, text = tostring(t.text or ""), icon = tostring(t.icon or "") } end
    end
  end
  if #out == 0 then
    out = { { id = "home", text = "TabHome", icon = "icon_list_tab_town01" } }
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ the slot's career

local CAREER, CAREER_SLOT = nil, nil

local function current_slot()
  local ok, n = pcall(VRFW.slots.active)
  if ok and type(n) == "number" and n ~= 0 then
    return floor(n)
  end
  return 1
end

local function load()
  local n = current_slot()
  if CAREER_SLOT == n then
    return CAREER
  end
  CAREER, CAREER_SLOT = nil, n
  local ok, b = pcall(VRFW.save.blob, BLOB, n)
  if ok and type(b) == "string" and b ~= "" then
    local doc, why = VRFW.json.decode(b)
    if type(doc) == "table" and doc.v == VERSION then
      CAREER = doc
      info(string.format("career of slot %d: team %08X, season %d, %s", n, doc.team, doc.season, doc.phase))
    else
      warn(BLOB .. " (slot " .. n .. ") is not a career of this version (" .. tostring(why or doc and doc.v) .. "): no career")
    end
  end
  return CAREER
end

local function save()
  if not CAREER then
    return false
  end
  local n = current_slot()
  local ok, done, why = pcall(VRFW.save.blob_write, BLOB, VRFW.json.encode(CAREER), n)
  if not (ok and done) then
    warn(BLOB .. " (slot " .. n .. ") not written: " .. tostring(ok and why or done))
    return false
  end
  return true
end

-- ------------------------------------------------------------------------------------------------ clubs

local CLUBS, CLUBS_WHY, FAMILY = nil, nil, nil
local NATIONS = nil      -- the national sides (config.toml [teams] national_*): no club competition, whole rosters
local TEAMS_BY_ID = nil  -- every career team by id (clubs, national sides, merged versions, dropped teams)
local COUNTRY = nil      -- national team id -> its country (config.toml [[world_cup.countries]]; unlisted: its key)
local COUNTRY_TEAMS = nil   -- country -> its national teams, the first one plays the World Cup (its name, crest, kit)
local COUNTRY_POOL = nil    -- country -> its pool teams (config pool_teams): their players have its nationality
local PENDING = nil      -- the club pick's squads: { seed, built }
local DRAWS = 0

-- the career's clubs file (config [squads] clubs_file, scripts/data/career_clubs.toml): its merged clubs get their
-- versions (t.versions, no clubs of their own), its dropped teams are no clubs -> the club list
local function merge_clubs(list)
  local path = tostring(config("squads.clubs_file", ""))
  if path == "" then return list end
  local ok, doc = pcall(VRFW.files.toml, path)
  if not ok or type(doc) ~= "table" then
    warn("clubs file " .. path .. " not readable (" .. tostring(doc) .. "): every team is a club")
    return list
  end
  local by_key, gone = {}, {}
  for _, t in ipairs(list) do by_key[t.key] = t end
  for _, k in ipairs(type(doc.drop) == "table" and doc.drop or {}) do gone[tostring(k)] = true end
  local merged = 0
  for _, cl in ipairs(type(doc.club) == "table" and doc.club or {}) do
    local key = type(cl) == "table" and tostring(cl.key or "") or ""
    local main = by_key[key]
    if main == nil or gone[key] then
      warn("clubs file: club " .. key .. " is no career club here (unknown, national or dropped)")
    else
      main.versions = {}
      for _, k in ipairs(type(cl.versions) == "table" and cl.versions or {}) do
        local v = by_key[tostring(k)]
        if v and v ~= main and not gone[v.key] then
          main.versions[#main.versions + 1] = v
          gone[v.key] = true
        else
          warn("clubs file: version " .. tostring(k) .. " of " .. key .. " is no career club here")
        end
      end
      merged = merged + 1
    end
  end
  local out = {}
  for _, t in ipairs(list) do
    if not gone[t.key] then out[#out + 1] = t end
  end
  info(string.format("clubs file: %d merged clubs, %d teams merged or dropped, %d clubs", merged, #list - #out, #out))
  return out
end

local function clubs()
  if CLUBS == nil and CLUBS_WHY == nil then
    local list, why = Teams.load()
    if list then
      Teams.mark_national(list)
      local declared = config("world_cup.countries", nil)
      declared = type(declared) == "table" and declared or {}
      -- a team a country lists plays there as its national team, out of the club competitions (owner 2026-10-30)
      local in_country = {}
      for _, ct in ipairs(declared) do
        for _, k in ipairs(type(ct) == "table" and type(ct.teams) == "table" and ct.teams or {}) do
          in_country[tostring(k)] = true
        end
      end
      TEAMS_BY_ID = {}
      local club_list, nations = {}, {}
      for _, t in ipairs(list) do
        if in_country[t.key] then t.national = true end
        TEAMS_BY_ID[t.id] = t
        if t.national then nations[#nations + 1] = t else club_list[#club_list + 1] = t end
      end
      club_list = merge_clubs(club_list)
      Teams.rate(club_list)
      COUNTRY, COUNTRY_TEAMS, COUNTRY_POOL = {}, {}, {}
      local by_key, declared_key = {}, {}
      for _, t in ipairs(nations) do by_key[t.key] = t end
      for _, t in ipairs(list) do declared_key[t.key] = t end
      -- a country's teams and pool teams no career team is are the game's own teams (story teams)
      local missing = {}
      for _, ct in ipairs(declared) do
        for _, field in ipairs({ "teams", "pool_teams" }) do
          for _, k in ipairs(type(ct) == "table" and type(ct[field]) == "table" and ct[field] or {}) do
            if declared_key[tostring(k)] == nil then missing[#missing + 1] = tostring(k) end
          end
        end
      end
      local game = Teams.game_teams(missing)
      for _, ct in ipairs(declared) do
        local id = type(ct) == "table" and tostring(ct.id or "") or ""
        for _, k in ipairs(id ~= "" and type(ct.teams) == "table" and ct.teams or {}) do
          local key = tostring(k)
          local t = by_key[key]
          if t == nil and game[key] then
            t = game[key]
            t.national, by_key[key] = true, t
            nations[#nations + 1] = t
            TEAMS_BY_ID[t.id] = t
          end
          if t and COUNTRY[t.id] == nil then
            COUNTRY[t.id] = id
            COUNTRY_TEAMS[id] = COUNTRY_TEAMS[id] or {}
            table.insert(COUNTRY_TEAMS[id], t)
          elseif t == nil then
            warn("country " .. id .. ": " .. key .. " is neither a national team nor a game team")
          end
        end
        for _, k in ipairs(id ~= "" and type(ct.pool_teams) == "table" and ct.pool_teams or {}) do
          local t = declared_key[tostring(k)] or game[tostring(k)]
          if t then
            COUNTRY_POOL[id] = COUNTRY_POOL[id] or {}
            table.insert(COUNTRY_POOL[id], t)
          else
            warn("country " .. id .. ": pool team " .. tostring(k) .. " not found")
          end
        end
      end
      if #nations > 0 then Teams.rate(nations) end
      CLUBS, FAMILY, NATIONS = club_list, Teams.families(club_list), nations
      for _, t in ipairs(nations) do
        if COUNTRY[t.id] == nil then
          COUNTRY[t.id] = t.key
          COUNTRY_TEAMS[t.key] = { t }
          warn("national team " .. t.key .. " is in no [[world_cup.countries]]: a country of its own")
        end
      end
    else
      CLUBS_WHY = why
      warn(why)
    end
  end
  return CLUBS, CLUBS_WHY
end

local function club_by_id()
  local by = {}
  for _, t in ipairs(CLUBS or {}) do
    by[t.id] = t
  end
  return by
end

-- a club or a national side by team id (also a merged version or a dropped team: a career started before keeps them)
local function team_by_id(team)
  clubs()
  return TEAMS_BY_ID and TEAMS_BY_ID[team] or nil
end

local function new_seed()
  DRAWS = DRAWS + 1
  return u32(floor(VRFW.now()) * 2654435761 + DRAWS * 40503 + current_slot())
end

-- the club order's game of every club (the club pick's groups)
local function games_of(list)
  local ok, doc = pcall(VRFW.files.toml, squads_config().order_file)
  local order = ok and type(doc) == "table" and type(doc.club) == "table" and doc.club or {}
  local out = {}
  for _, t in ipairs(list) do
    local o = order[t.key]
    out[t.id] = type(o) == "table" and floor(tonumber(o.game) or 99) or 99
  end
  return out
end

-- career lookups: index of a club, its rating, its squad
local INDEX = setmetatable({}, { __mode = "k" })   -- career -> { [team] = index } (never saved)
local function index_of(c)
  if INDEX[c] == nil then
    INDEX[c] = {}
    for i, t in ipairs(c.clubs) do INDEX[c][t] = i end
  end
  return INDEX[c]
end

local function ratings_of(c)
  local out, values = {}, {}
  for i, t in ipairs(c.clubs) do
    out[t] = tonumber(c.ratings[i]) or 0
    values[#values + 1] = out[t]
  end
  table.sort(values)
  return out, values[floor((#values + 1) / 2)] or 1
end

local function squad_of(c, team)
  local i = index_of(c)[team]
  return i and c.squads[i] or nil
end

-- card -> { strength (config [squads] strength_column), position }
local CARD_INFO = nil
local function card_info(card)
  if CARD_INFO == nil then
    CARD_INFO = {}
    local col = tostring(config("squads.strength_column", "rank"))
    local ok, list = pcall(VRFW.chara.cards, { columns = { col } })
    for _, k in ipairs(ok and type(list) == "table" and list or {}) do
      CARD_INFO[u32(k.id)] = { strength = tonumber(type(k.cols) == "table" and k.cols[col]) or 0,
        position = floor(tonumber(k.position) or 0) }
    end
  end
  return CARD_INFO[u32(card)] or { strength = 0, position = 0 }
end

-- cards (squad order), size, keepers -> the best `size` of them by strength with `keepers` goalkeepers at least (when
-- the squad has them), in squad order
local function best_cards(cards, size, keepers)
  if #cards <= size then return cards end
  local order = {}
  for i, card in ipairs(cards) do order[i] = { card = card, i = i, info = card_info(card) } end
  table.sort(order, function(a, b)
    if a.info.strength ~= b.info.strength then return a.info.strength > b.info.strength end
    return a.i < b.i
  end)
  local take, n, gk = {}, 0, 0
  for _, x in ipairs(order) do
    if gk < keepers and x.info.position == 1 then take[x.i], n, gk = true, n + 1, gk + 1 end
  end
  for _, x in ipairs(order) do
    if n >= size then break end
    if not take[x.i] then take[x.i], n = true, n + 1 end
  end
  local out = {}
  for i, card in ipairs(cards) do
    if take[i] then out[#out + 1] = card end
  end
  return out
end

-- a club's whole career squad as cards in roster order (its rows by slot, then the signings beyond them)
local function squad_cards(c, team)
  local sq = squad_of(c, team)
  local out = {}
  for _, p in ipairs(sq and sq.players or {}) do
    if tonumber(p.card) and p.card ~= 0 then out[#out + 1] = u32(p.card) end
  end
  return out
end

-- the players a club takes to a match (config [match] squad_size, the slot teams' rows): the whole squad when it fits;
-- else the player's club its call-up (c.callup, when it is a full one of this squad), any other club its best
local function match_size()
  return int("match.squad_size", 19), int("match.keepers", 2)
end

local function match_cards(c, team)
  local cards = squad_cards(c, team)
  local size, keepers = match_size()
  if #cards <= size then return cards end
  if team == c.team and type(c.callup) == "table" and #c.callup == size then
    local in_squad, ok = {}, true
    for _, card in ipairs(cards) do in_squad[card] = true end
    for _, card in ipairs(c.callup) do ok = ok and in_squad[u32(card)] == true end
    if ok then
      local picked, out = {}, {}
      for _, card in ipairs(c.callup) do picked[u32(card)] = true end
      for _, card in ipairs(cards) do
        if picked[card] then out[#out + 1] = card end
      end
      return out
    end
  end
  return best_cards(cards, size, keepers)
end

-- ------------------------------------------------------------------------------------------------ the season

local PHASE_CODE = { superliga = 1, league = 2, frontier = 3, worldcup = 4 }

-- the team the player leads now: the national side during the World Cup, else his club
local function me_of(c)
  if c.phase == "worldcup" and type(c.wc) == "table" then return c.wc.side end
  return c.team
end

-- the World Cup of the career's current season (nil before it)
local function worldcup_of(c)
  local w = c.wc
  if type(w) == "table" and w.season == c.season then return w end
  return nil
end

-- the World Cup's round index across its days: the group matchday, then group_days + the knockout round
local function worldcup_index(w)
  if w.stage == "groups" then return w.matchday end
  if w.stage == "knockout" then return w.format.group_days + w.ko.round end
  if w.stage == "done" then return #w.dates + 1 end
  return 1
end

-- the rounds of each phase of a season of `clubs` clubs, from the config (the dates are laid out before the draws)
local function season_counts(clubs_count)
  local cfg = season_config()
  local per = floor(math.min(cfg.qualify, floor(clubs_count / cfg.leagues) * cfg.leagues) / cfg.leagues)
  local days = (per % 2 == 0 and per - 1 or per) * (cfg.double and 2 or 1)
  local playoff = floor((cfg.playoff_places[2] - cfg.playoff_places[1] + 1) * cfg.leagues / 2)
  local size = cfg.direct_places * cfg.leagues + playoff
  local rounds = 1
  while 2 ^ rounds < size do rounds = rounds + 1 end
  return { superliga = cfg.rounds, league = math.max(0, days), frontier = 1 + rounds }
end

-- the season's days (lib/calendar.lua), laid out once per season and kept in the career (a config change applies from
-- the next season)
local function plan_of(c)
  if type(c.cal) ~= "table" or c.cal.season ~= c.season then
    local rules = Calendar.rules(config)
    local plan = Calendar.season(rules.first_year + c.season - 1, season_counts(#c.clubs), rules)
    plan.season = c.season
    c.cal = plan
    if plan.late then
      warn(string.format("season %d: the final falls after the season's end even with every phase on both days", c.season))
    end
    info(string.format("season %d days: %d SuperLiga, draw, %d league, %d Frontier, final on day %d (%d phase(s) on both days)",
      c.season, #plan.superliga, #plan.league, #plan.frontier, plan.last, plan.compressed or 0))
  end
  return c.cal
end

-- the day of a phase's round (a round beyond the laid-out ones: a week after the last)
local function day_of(c, phase, round)
  local list = plan_of(c)[phase] or {}
  if list[round] then return list[round] end
  local last = list[#list] or plan_of(c).last or plan_of(c).start
  return last + 7 * math.max(1, round - #list)
end

-- the career's today: the day of the last event played (the season's first day before any)
local function today_of(c)
  local plan = plan_of(c)
  if c.phase == "superliga" then
    return c.sl.round > 1 and day_of(c, "superliga", c.sl.round - 1) or plan.start
  elseif c.phase == "pots" then
    return day_of(c, "superliga", #c.sl.results)
  elseif c.phase == "league" then
    return c.lg.matchday > 1 and day_of(c, "league", c.lg.matchday - 1) or plan.draw
  elseif c.phase == "frontier" then
    return c.ff.round > 1 and day_of(c, "frontier", c.ff.round - 1) or day_of(c, "league", c.lg.matchdays)
  end
  local w = worldcup_of(c)
  if w and worldcup_index(w) > 1 then return w.dates[math.min(#w.dates, worldcup_index(w) - 1)] end
  return c.ff and day_of(c, "frontier", #c.ff.results) or plan.last
end

-- the day of the next event: the round being played, the draw
local function next_day_of(c)
  if c.phase == "superliga" then return day_of(c, "superliga", c.sl.round)
  elseif c.phase == "pots" then return plan_of(c).draw
  elseif c.phase == "league" then return day_of(c, "league", c.lg.matchday)
  elseif c.phase == "frontier" then return day_of(c, "frontier", c.ff.round)
  elseif c.phase == "worldcup" and c.wc then return c.wc.dates[worldcup_index(c.wc)] end
  return nil
end

-- day -> { open, from, to }: the transfer window of the career's season open on that day (else the next one to open:
-- open = false, from / to its days, nil when none is left)
local function window_state(c, z)
  local plan = plan_of(c)
  local i, a, b = Calendar.window_at(plan, z)
  if i then return { open = true, from = a, to = b } end
  a, b = Calendar.next_window(plan, z)
  return { open = false, from = a, to = b }
end

local function rng_for(c, phase, round)
  return VRFW.rng("CareerMode.season", { c.seed, c.season, PHASE_CODE[phase] or 0, round or 0 })
end

local function family_of(c)
  clubs()
  local out = {}
  for _, t in ipairs(c.clubs) do out[t] = FAMILY and FAMILY[t] or t end
  return out
end

-- the SuperLiga's standings rows of the season so far
local function superliga_rows(c)
  local all = {}
  for _, round in ipairs(c.sl.results) do
    for _, r in ipairs(round) do all[#all + 1] = r end
  end
  return Competition.standings(c.sl.order, all, { points = points_config() })
end

local function league_rows(c, l)
  local all = {}
  for _, day in ipairs(c.lg.results[l] or {}) do
    for _, r in ipairs(day) do all[#all + 1] = r end
  end
  return Competition.standings(c.leagues[l] or {}, all, { points = points_config() })
end

local function league_of(c, team)
  for l, lg in ipairs(c.leagues or {}) do
    for _, t in ipairs(lg) do
      if t == team then return l end
    end
  end
  return nil
end

-- the fixtures of the round being played: { { home, away } }, label key, label number, knockout
local function fixtures(c)
  if c.phase == "superliga" then
    return c.sl.rounds[c.sl.round] or {}, "RoundSuperLiga", c.sl.round, false
  elseif c.phase == "league" then
    local out = {}
    for l, lg in ipairs(c.leagues) do
      local days = Season.league_days(lg, c.double)
      for _, m in ipairs(days[c.lg.matchday] or {}) do out[#out + 1] = { m[1], m[2], l } end
    end
    return out, "RoundLeague", c.lg.matchday, false
  elseif c.phase == "frontier" then
    local round = c.ff.rounds[c.ff.round] or {}
    return round, "Frontier" .. tostring(c.ff.labels[c.ff.round] or ""), c.ff.round, true
  elseif c.phase == "worldcup" and c.wc then
    local w = c.wc
    if w.stage == "groups" then
      local out = {}
      for g, days in ipairs(w.days) do
        for _, m in ipairs(days[w.matchday] or {}) do out[#out + 1] = { m[1], m[2], g } end
      end
      return out, "WorldCupGroup", w.matchday, false
    elseif w.stage == "knockout" then
      return w.ko.rounds[w.ko.round] or {}, "WorldCup" .. tostring(w.ko.labels[w.ko.round] or ""), w.ko.round, true
    end
  end
  return {}, "", 0, false
end

local function mine(list, team)
  for i, m in ipairs(list) do
    if m[1] == team or m[2] == team then return m, i end
  end
  return nil
end

local function frontier_label(matches, first)
  if first then return "Playoff" end
  if matches == 1 then return "Final" end
  if matches == 2 then return "Semi" end
  if matches == 4 then return "Quarter" end
  return "Round" .. (matches * 2)
end

local sim_rest
local worldcup_start, worldcup_round

-- the season ends: its line in the history
local function season_over(c)
  c.phase = "over"
  local place = 0
  for i, r in ipairs(superliga_rows(c)) do
    if r.team == c.team then place = i end
  end
  local l = league_of(c, c.team)
  local lplace = 0
  if l then
    for i, r in ipairs(league_rows(c, l)) do
      if r.team == c.team then lplace = i end
    end
  end
  c.history[#c.history + 1] = { season = c.season, superliga = place, league = l or 0, league_place = lplace,
    reached = c.reached or "", champion = c.champion or 0 }
  info(string.format("season %d over: champion %08X, the club's SuperLiga place %d, league %s place %d, reached %s",
    c.season, c.champion or 0, place, tostring(l), lplace, tostring(c.reached)))
  worldcup_start(c)
end

-- the knockout's slots (Season.frontier_slots): the round after the play-off, drawn from the direct clubs and the
-- play-off matches as the Fútbol Frontier starts
local function frontier_slots(c)
  if c.ff.slots then return c.ff.slots end
  local lg = {}
  for _, p in ipairs(c.ff.league) do lg[p[1]] = p[2] end
  local playoff = {}
  for i, m in ipairs(c.ff.rounds[1] or {}) do playoff[i] = { m[1], m[2], lg[m[1]] or 0, lg[m[2]] or 0 } end
  local direct = {}
  for i, d in ipairs(c.ff.direct) do direct[i] = { team = d[1], league = d[2] } end
  local slots, same = Season.frontier_slots(direct, playoff, rng_for(c, "frontier", 100))
  c.ff.slots = slots
  info(string.format("Fútbol Frontier draw: %d slots, %d meeting(s) within one league", #slots, same))
  return slots
end

-- the team standing in a slot after the play-off: the direct club, or the winner of its play-off match (0 = not yet)
local function slot_team(c, slot)
  if slot.kind == "direct" then return slot.team end
  local r = c.ff.results[1] and c.ff.results[1][slot.match]
  return r and Season.winner(r) or 0
end

local function frontier_start(c)
  local cfg = season_config()
  local tables = {}
  for l = 1, #c.leagues do
    tables[l] = {}
    for i, r in ipairs(league_rows(c, l)) do tables[l][i] = r.team end
  end
  local playoff, direct = Season.frontier_entry(tables, cfg)
  local size = #direct + #playoff
  if not Competition.is_power_of_two(size) then
    warn(string.format("Fútbol Frontier: %d direct clubs + %d play-off winners is not a power of two", #direct, #playoff))
  end
  c.ff = { rounds = { {} }, results = {}, round = 1, labels = { "Playoff" }, direct = {}, seed = {}, league = {} }
  for _, p in ipairs(playoff) do
    c.ff.rounds[1][#c.ff.rounds[1] + 1] = { p[1], p[2] }
    c.ff.league[#c.ff.league + 1] = { p[1], p[3] }
    c.ff.league[#c.ff.league + 1] = { p[2], p[4] }
  end
  for i, d in ipairs(direct) do
    c.ff.direct[i] = { d.team, d.league }
  end
  -- the seeds (the better club hosts a later round): direct by place, then the play-off clubs by place
  local rank = 0
  for p = 1, cfg.playoff_places[2] do
    for l = 1, #tables do
      local t = tables[l][p]
      if t then
        rank = rank + 1
        c.ff.seed[#c.ff.seed + 1] = { t, rank }
      end
    end
  end
  c.phase = "frontier"
  frontier_slots(c)
  local in_direct = false
  for _, d in ipairs(direct) do
    if d.team == c.team then in_direct = true end
  end
  if in_direct then
    c.reached = "Round" .. size
  elseif mine(c.ff.rounds[1], c.team) then
    c.reached = "Playoff"
  else
    c.out, c.out_reason = true, "league"
  end
  info(string.format("Fútbol Frontier: %d direct, %d play-off matches%s", #direct, #playoff, c.out and " (the club is out)" or ""))
end

local function cut(c)
  local cfg = season_config()
  local rows = superliga_rows(c)
  local n = math.min(cfg.qualify, floor(#rows / cfg.leagues) * cfg.leagues)
  c.qualified = {}
  local place = 0
  for i, r in ipairs(rows) do
    if i <= n then c.qualified[i] = r.team end
    if r.team == c.team then place = i end
  end
  local pots, leagues = Season.deal(c.qualified, cfg.leagues, family_of(c), rng_for(c, "league", 0))
  c.pots, c.leagues = pots, leagues
  c.lg = { matchday = 1, matchdays = #Season.league_days(leagues[1] or {}, c.double), results = {} }
  for l = 1, #leagues do c.lg.results[l] = {} end
  c.sl.place = place
  if place > n then
    c.out, c.out_reason = true, "superliga"
    c.phase = "league"
    info(string.format("SuperLiga over: the club is %d of %d, out (the first %d go on)", place, #rows, n))
  else
    c.phase, c.reached = "pots", "League"
    info(string.format("SuperLiga over: the club is %d of %d, in the draw of %d pots", place, #rows, #pots))
  end
end

-- the round being played with the player's result (nil = simulated) -> the player's result or nil
local function play_round(c, result)
  if c.phase == "worldcup" then return worldcup_round(c, result) end
  local list, _, round, knockout = fixtures(c)
  local ratings, median = ratings_of(c)
  local sim = sim_config(median)
  local rng = rng_for(c, c.phase, round)
  local results, mine_result = {}, nil
  for _, m in ipairs(list) do
    local r
    if result and ((m[1] == result[1] and m[2] == result[2])) then
      r = result
      if knockout and r[3] == r[4] and (r[5] or 0) == 0 then
        r[5], r[6], r[7] = Season.penalties(r[1], r[2], ratings, sim, rng)
      end
    else
      r = Season.simulate(m[1], m[2], ratings, sim, rng, knockout)
    end
    r[5] = r[5] or 0
    results[#results + 1] = r
    if m[1] == c.team or m[2] == c.team then mine_result = r end
  end
  local cfg = season_config()
  if c.phase == "superliga" then
    c.sl.results[round] = results
    if round < cfg.rounds then
      local rests = {}
      for _, t in ipairs(c.sl.rests) do rests[t] = true end
      local all = {}
      for _, rr in ipairs(c.sl.results) do
        for _, r in ipairs(rr) do all[#all + 1] = r end
      end
      local pairs_, rest, rematches = Season.swiss_round(c.sl.order, all, rests, points_config(), rng_for(c, "superliga", round + 1))
      c.sl.rounds[round + 1] = pairs_
      if rest ~= 0 then c.sl.rests[#c.sl.rests + 1] = rest end
      if rematches > 0 then warn(string.format("SuperLiga round %d: %d rematch(es)", round + 1, rematches)) end
      c.sl.round = round + 1
    else
      cut(c)
    end
  elseif c.phase == "league" then
    for _, r in ipairs(results) do
      local l = league_of(c, r[1])
      if l then
        c.lg.results[l][round] = c.lg.results[l][round] or {}
        local day = c.lg.results[l][round]
        day[#day + 1] = { r[1], r[2], r[3], r[4], r[5] }
      end
    end
    if round < c.lg.matchdays then
      c.lg.matchday = round + 1
    else
      frontier_start(c)
    end
  elseif c.phase == "frontier" then
    c.ff.results[round] = results
    local winners = {}
    for _, r in ipairs(results) do winners[#winners + 1] = Season.winner(r) end
    if mine_result and Season.winner(mine_result) ~= c.team then
      c.out, c.out_reason = true, "frontier"
    end
    if #winners == 1 and #results == 1 then
      c.champion = winners[1]
      if c.champion == c.team then c.reached = "Champion" end
      season_over(c)
    else
      local nxt
      if round == 1 then
        -- the slots drawn at the start, two by two (the first one at home)
        local slots = frontier_slots(c)
        nxt = {}
        for k = 1, #slots - 1, 2 do nxt[#nxt + 1] = { slot_team(c, slots[k]), slot_team(c, slots[k + 1]) } end
      else
        local seed = {}
        for _, s in ipairs(c.ff.seed) do seed[s[1]] = s[2] end
        nxt = Competition.next_round(winners, seed)
      end
      c.ff.rounds[round + 1] = nxt
      c.ff.labels[round + 1] = frontier_label(#nxt, false)
      c.ff.round = round + 1
      if not c.out and mine(nxt, c.team) then c.reached = c.ff.labels[round + 1] end
    end
  end
  return mine_result
end

-- everything left of the season simulated (the player's club is out)
sim_rest = function(c)
  local guard = 0
  while c.phase ~= "over" and c.phase ~= "worldcup" and guard < 400 do
    guard = guard + 1
    if c.phase == "pots" then
      c.phase = "league"
    else
      play_round(c, nil)
    end
  end
end

-- a new season of the career's clubs: the SuperLiga's first round drawn
local function season_start(c)
  c.phase, c.out, c.out_reason, c.champion, c.reached = "superliga", false, "", 0, "SuperLiga"
  c.cal, c.wc = nil, nil
  local order = {}
  for i, t in ipairs(c.clubs) do order[i] = t end
  rng_for(c, "superliga", 0):shuffle(order)
  c.sl = { order = order, rounds = {}, results = {}, rests = {}, round = 1, place = 0 }
  c.pots, c.leagues, c.qualified, c.lg, c.ff, c.pending = {}, {}, {}, { matchday = 0, matchdays = 0, results = {} }, nil, nil
  local first, rest = Season.swiss_round(order, {}, {}, points_config(), rng_for(c, "superliga", 1))
  c.sl.rounds[1] = first
  if rest ~= 0 then c.sl.rests[1] = rest end
  plan_of(c)
end

-- ------------------------------------------------------------------------------------------------ the World Cup

-- national side id -> its rating (config [ratings], among the national sides), the median
local function worldcup_ratings(c)
  local out, values = {}, {}
  for _, p in ipairs(c.wc.ratings or {}) do
    out[p[1]] = tonumber(p[2]) or 0
    values[#values + 1] = out[p[1]]
  end
  table.sort(values)
  return out, values[floor((#values + 1) / 2)] or 1
end

-- ------------------------------------------------------------------------------------------------ nationalities

-- every player's nationality: the country of the national teams whose rosters hold him (a country's first team first),
-- then the country of its pool teams (config pool_teams), then the players scripts\data\nationalities.toml adds or moves (config [world_cup] nationality_file) ->
-- { [person] = { country, card, slot, number, team } }, person = the character (VRFW.chara.base_of)
local NATIONALITY = nil

local function person_of(card)
  local ok, base = pcall(VRFW.chara.base_of, card)
  return ok and type(base) == "number" and base ~= 0 and u32(base) or u32(card)
end

local function nationalities()
  if NATIONALITY then return NATIONALITY end
  clubs()
  NATIONALITY = {}
  local ids = {}
  for id in pairs(COUNTRY_TEAMS or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for _, t in ipairs(COUNTRY_TEAMS[id]) do
      for _, p in ipairs(t.players or {}) do
        local who = person_of(p.card)
        if NATIONALITY[who] == nil then
          NATIONALITY[who] = { country = id, card = p.card, slot = p.slot, number = p.number, team = t.id }
        end
      end
    end
  end
  for _, id in ipairs(ids) do
    for _, t in ipairs(COUNTRY_POOL[id] or {}) do
      for _, p in ipairs(t.players or {}) do
        local who = person_of(p.card)
        if NATIONALITY[who] == nil then
          NATIONALITY[who] = { country = id, card = p.card, slot = p.slot, number = p.number, team = t.id }
        end
      end
    end
  end
  local path = tostring(config("world_cup.nationality_file", "scripts/data/nationalities.toml"))
  local ok, doc = pcall(VRFW.files.toml, path)
  local added = 0
  if ok and type(doc) == "table" and type(doc.country) == "table" then
    for id, list in pairs(doc.country) do
      for _, v in ipairs(type(list) == "table" and list or {}) do
        local card = 0
        if type(v) == "number" then card = u32(v)
        elseif type(v) == "string" then
          local hex = v:match("^0[xX](%x+)$")
          if hex then card = u32(tonumber(hex, 16))
          else
            local okr, n = pcall(VRFW.ids.resolve, "chara", v)
            card = okr and type(n) == "number" and u32(n) or 0
          end
        end
        if card ~= 0 then
          NATIONALITY[person_of(card)] = { country = tostring(id), card = card, slot = -1, number = 0, team = 0 }
          added = added + 1
        end
      end
    end
  end
  info(string.format("nationalities: %d countries, %d players from the file", #ids, added))
  return NATIONALITY
end

-- the players of a country (the call-up pool): its first team's roster in slot order, then the others ->
-- { { card, slot, number, team } }
local function worldcup_pool(country)
  local out = {}
  for _, n in pairs(nationalities()) do
    if n.country == country then out[#out + 1] = n end
  end
  local rank = {}
  for i, t in ipairs(COUNTRY_TEAMS[country] or {}) do rank[t.id] = i end
  local teams = #(COUNTRY_TEAMS[country] or {})
  for i, t in ipairs(COUNTRY_POOL and COUNTRY_POOL[country] or {}) do rank[t.id] = rank[t.id] or teams + i end
  table.sort(out, function(a, b)
    local ra, rb = rank[a.team] or 99, rank[b.team] or 99
    if ra ~= rb then return ra < rb end
    if a.slot ~= b.slot then return a.slot < b.slot end
    return a.card < b.card
  end)
  return out
end

-- ------------------------------------------------------------------------------------------------ the World Cup start

-- the World Cup starts after the club season (config [world_cup]; without countries or World Cup days the season is
-- over): one entrant per country (its first team, rated by its best team), the groups, the days, the country offered to
-- the player (drawn) and its first squad (the pool's first `squad` players)
worldcup_start = function(c)
  clubs()
  local cfg = worldcup_config()
  local plan = plan_of(c)
  local entrants, rating, country_of = {}, {}, {}
  local ids = {}
  for id in pairs(COUNTRY_TEAMS or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local lead = COUNTRY_TEAMS[id][1]
    local best = 0
    for _, t in ipairs(COUNTRY_TEAMS[id]) do best = math.max(best, t.rating or 0) end
    entrants[#entrants + 1] = lead.id
    rating[lead.id], country_of[#entrants] = best, id
  end
  local format = cfg.enabled and plan.world_cup and Worldcup.format(#entrants, cfg) or nil
  if format == nil then
    c.phase = "over"
    return
  end
  local rng = rng_for(c, "worldcup", 0)
  local pick = rng:int(1, #entrants)
  local side, country = entrants[pick], country_of[pick]
  local groups, days = Worldcup.groups(Worldcup.seeded(entrants, rating), format.groups, rng)
  local ratings = {}
  for i, t in ipairs(entrants) do ratings[i] = { t, rating[t] or 0 } end
  local squad = {}
  for _, p in ipairs(worldcup_pool(country)) do
    if #squad < cfg.squad then squad[#squad + 1] = p.card end
  end
  c.wc = { season = c.season, side = side, country = country, stage = "call", format = format, entrants = entrants,
    ratings = ratings, groups = groups, days = days, results = {}, matchday = 1, ko = false, champion = 0, out = false,
    squad = squad, dates = Worldcup.days(plan.world_cup[1], plan.world_cup[2], format.group_days + format.knockout_rounds) }
  c.phase = "worldcup"
  info(string.format("World Cup: %d countries, %d groups (up to %d), knockout of %d; the player is offered %s (%08X)",
    #entrants, format.groups, format.per, format.knockout, country, side))
end

-- a group's standings rows so far
local function worldcup_group_rows(c, g)
  local all = {}
  for _, day in ipairs(c.wc.results) do
    for _, r in ipairs(day) do all[#all + 1] = r end
  end
  return Competition.standings(c.wc.groups[g] or {}, all, { points = points_config() })
end

local function worldcup_group_of(w, team)
  for g, list in ipairs(w.groups) do
    for _, t in ipairs(list) do
      if t == team then return g end
    end
  end
  return nil
end

-- the World Cup's round being played with the player's result (nil = simulated) -> his side's result or nil
worldcup_round = function(c, result)
  local w = c.wc
  local list, _, round, knockout = fixtures(c)
  local ratings, median = worldcup_ratings(c)
  local sim = sim_config(median)
  local rng = rng_for(c, "worldcup", worldcup_index(w))
  local results, mine_result = {}, nil
  for _, m in ipairs(list) do
    local r
    if result and m[1] == result[1] and m[2] == result[2] then
      r = result
      if knockout and r[3] == r[4] and (r[5] or 0) == 0 then
        r[5], r[6], r[7] = Season.penalties(r[1], r[2], ratings, sim, rng)
      end
    else
      r = Season.simulate(m[1], m[2], ratings, sim, rng, knockout)
    end
    r[5] = r[5] or 0
    results[#results + 1] = r
    if m[1] == w.side or m[2] == w.side then mine_result = r end
  end
  if w.stage == "groups" then
    w.results[round] = results
    if round < w.format.group_days then
      w.matchday = round + 1
    else
      local rows = {}
      for g = 1, #w.groups do rows[g] = worldcup_group_rows(c, g) end
      local first = Worldcup.knockout_start(rows, w.format)
      w.stage = "knockout"
      w.ko = { rounds = { first }, results = {}, round = 1, labels = { frontier_label(#first, false) } }
      if not mine(first, w.side) then w.out = true end
    end
  else
    w.ko.results[round] = results
    local winners = {}
    for _, r in ipairs(results) do winners[#winners + 1] = Season.winner(r) end
    if mine_result and Season.winner(mine_result) ~= w.side then w.out = true end
    if #results == 1 then
      w.champion, w.stage = winners[1], "done"
      c.phase = "over"
      info(string.format("World Cup over: champion %08X (the player's side %08X)", w.champion, w.side))
    else
      local nxt = {}
      for i = 1, #winners - 1, 2 do nxt[#nxt + 1] = { winners[i], winners[i + 1] } end
      w.ko.rounds[round + 1] = nxt
      w.ko.labels[round + 1] = frontier_label(#nxt, false)
      w.ko.round = round + 1
    end
  end
  return mine_result
end

-- after a round: the player out of the season's competition -> the rest simulated, the season over; his side out of
-- the World Cup -> the rest of it simulated
local function settle(c)
  if c.out and c.phase ~= "over" and c.phase ~= "worldcup" then sim_rest(c) end
  if c.phase == "worldcup" and c.wc.out and c.wc.stage ~= "call" then
    local guard = 0
    while c.phase == "worldcup" and guard < 64 do
      guard = guard + 1
      play_round(c, nil)
    end
  end
end

-- ------------------------------------------------------------------------------------------------ commands

-- -> { ok, why, clubs, career = { team, season, phase, out, fresh } or nil } (fresh = the first answer after a match of
-- the club: the screen goes straight to the hub)
function CareerMode.State()
  local list, why = clubs()
  local c = load()
  local out = { ok = list ~= nil, why = why or "", clubs = list and #list or 0, nations = NATIONS and #NATIONS or 0 }
  if c then
    out.career = { team = c.team, season = c.season, phase = c.phase, out = c.out == true, fresh = c.fresh == true }
    if c.fresh then
      c.fresh = nil
      save()
    end
  end
  return out
end

-- the club pick: every club that enters a career, grouped by its game -> { ok, why, leagues = { { team ids } },
-- groups = { game }, clubs, rounds, rating }
function CareerMode.Draw()
  local list, why = clubs()
  if not list then
    return { ok = false, why = why }
  end
  if PENDING == nil then
    local seed = new_seed()
    local built = Squads.build(list, seed, squads_config())
    if #built.clubs < 2 then
      return { ok = false, why = "fewer than 2 clubs keep their players" }
    end
    PENDING = { seed = seed, built = built }
  end
  local games = games_of(list)
  local by_game, keys = {}, {}
  for _, t in ipairs(PENDING.built.clubs) do
    local g = games[t] or 99
    if by_game[g] == nil then
      by_game[g] = {}
      keys[#keys + 1] = g
    end
    by_game[g][#by_game[g] + 1] = t
  end
  table.sort(keys)
  local leagues = {}
  for i, g in ipairs(keys) do leagues[i] = by_game[g] end
  return { ok = true, leagues = leagues, groups = keys, clubs = #PENDING.built.clubs, rounds = season_config().rounds,
    rating = rating_rules() }
end

-- team -> { ok, why }: a new career with that club (the slot's old career put aside first)
function CareerMode.Start(team)
  team = u32(team)
  if not PENDING then
    return { ok = false, why = "no club pick" }
  end
  local built = PENDING.built
  if built.squads[team] == nil then
    return { ok = false, why = "the club is not in the career" }
  end
  local by = club_by_id()
  local ids, ratings, squads = {}, {}, {}
  for i, t in ipairs(built.clubs) do
    ids[i] = t
    ratings[i] = by[t] and by[t].rating or 0
    squads[i] = built.squads[t]
  end
  load()
  if CAREER then
    CareerMode.Abandon()
  end
  local nations = {}
  for i, t in ipairs(NATIONS or {}) do nations[i] = t.id end
  CAREER = { v = VERSION, seed = PENDING.seed, team = team, season = 1, clubs = ids, ratings = ratings, squads = squads,
    nations = nations, double = season_config().double, history = {} }
  season_start(CAREER)
  CAREER_SLOT = current_slot()
  if not save() then
    CAREER = nil
    return { ok = false, why = "not saved" }
  end
  PENDING = nil
  info(string.format("new career: team %08X, %d clubs, %d national sides, %d players signed", team, #ids, #nations,
    built.signed))
  return { ok = true }
end

-- -> { ok }: the slot's career put aside (a new career replaces it)
function CareerMode.Abandon()
  local n = current_slot()
  local ok, where = pcall(VRFW.save.blob_aside, BLOB, n)
  info(BLOB .. " (slot " .. n .. ") put aside: " .. tostring(ok and where or "failed"))
  CAREER, CAREER_SLOT = nil, n
  return { ok = ok == true }
end

-- the names of cards in the game's language (lang = CMND_GET_LANGUAGE_CODE), as written: card -> name
local function card_names(cards, lang)
  return GameText.card_names(cards, GameText.language(lang), true)
end

-- a card's main position (1 GK, 2 FW, 3 MF, 4 DF; 0 = unknown)
local function main_position(card)
  local ok, k = pcall(VRFW.chara.card, card)
  return ok and type(k) == "table" and floor(tonumber(k.position) or 0) or 0
end

local function players_view(players, lang)
  local cards = {}
  for i, p in ipairs(players) do cards[i] = p.card end
  local names = card_names(cards, lang)
  local out = {}
  for i, p in ipairs(players) do
    out[i] = { card = p.card, number = p.number, slot = p.slot, position = main_position(p.card), name = names[p.card] or "",
      signed = p.signed == true }
  end
  return out
end

local function rows_view(rows)
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = { team = r.team, played = r.played, won = r.won, drawn = r.drawn, lost = r.lost,
      goals_for = r.goals_for, goals_against = r.goals_against, points = r.points }
  end
  return out
end

-- the competitions of the «Competición» tab in order: the SuperLiga, each league (once dealt), the Fútbol Frontier's
-- bracket (once drawn), the World Cup (once the squad is called up: its groups, then its knockout once drawn)
local function competitions(c)
  local out = { { kind = "superliga" } }
  for l = 1, #(c.leagues or {}) do out[#out + 1] = { kind = "league", league = l } end
  if c.ff then out[#out + 1] = { kind = "bracket", tree = "frontier" } end
  local w = worldcup_of(c)
  if w and w.stage ~= "call" then out[#out + 1] = { kind = "worldcup" } end
  return out
end

-- a World Cup group's table: { kind = "group", group, rows, cut, direct }
local function group_view(c, g)
  return { kind = "group", group = g, rows = rows_view(worldcup_group_rows(c, g)), cut = c.wc.format.advance,
    direct = c.wc.format.advance }
end

-- competition i -> its view: a table ({ kind = "superliga" | "league", rows, cut, direct, … }), the World Cup
-- ({ kind = "worldcup", groups = { { group, rows } }, direct = the places that always go through, cut = the places
-- that may, knockout = its bracket is drawn }) or the Fútbol Frontier's bracket ({ kind = "bracket", tree })
local function table_view(c, i)
  local e = competitions(c)[i] or { kind = "superliga" }
  if e.kind == "league" then
    return { kind = "league", league = e.league, rows = rows_view(league_rows(c, e.league)),
      cut = season_config().playoff_places[2], direct = season_config().direct_places }
  end
  if e.kind == "worldcup" then
    local w = c.wc
    local f, n = w.format, #w.groups
    local groups = {}
    for g = 1, n do groups[g] = { group = g, rows = rows_view(worldcup_group_rows(c, g)) } end
    local direct = math.min(f.advance, floor(f.knockout / n))
    return { kind = "worldcup", groups = groups, direct = direct, cut = math.max(direct, math.ceil(f.knockout / n)),
      knockout = w.ko ~= nil }
  end
  if e.kind == "bracket" then return { kind = "bracket", tree = e.tree } end
  return { kind = "superliga", title = "SuperLiga", rows = rows_view(superliga_rows(c)), cut = #c.qualified > 0 and
    #c.qualified or season_config().qualify, round = c.phase == "superliga" and c.sl.round or season_config().rounds }
end

-- the competition shown first: the World Cup, the Fútbol Frontier, the club's league, the SuperLiga
local function default_competition(c)
  local list = competitions(c)
  local want
  local w = worldcup_of(c)
  if w and w.stage ~= "call" then want = "worldcup"
  elseif c.ff then want = "frontier"
  else want = league_of(c, c.team) end
  for i = #list, 1, -1 do
    local e = list[i]
    if e.tree == want or e.kind == want or (e.league ~= nil and e.league == want) then return i end
  end
  return 1
end

-- the table of «Inicio»: the player's World Cup group, else the club's league, else the SuperLiga
local function home_table(c)
  local w = worldcup_of(c)
  if c.phase == "worldcup" and w and w.stage ~= "call" then return group_view(c, worldcup_group_of(w, w.side) or 1) end
  local l = league_of(c, c.team)
  if c.phase ~= "superliga" and l then return table_view(c, 1 + l) end
  return table_view(c, 1)
end

-- the player's matches of the season: { { label, n, home, away, hg, ag, pens, played } }
local function calendar(c)
  local out = {}
  for r = 1, season_config().rounds do
    local played = c.sl.results[r] and mine(c.sl.results[r], c.team)
    local m = played or (c.sl.rounds[r] and mine(c.sl.rounds[r], c.team))
    if m or r >= c.sl.round then
      out[#out + 1] = { label = "RoundSuperLiga", n = r, home = m and m[1] or 0, away = m and m[2] or 0,
        hg = played and played[3] or -1, ag = played and played[4] or -1, pens = played and played[5] or 0,
        current = c.phase == "superliga" and r == c.sl.round, date = Calendar.view(day_of(c, "superliga", r)) }
    end
  end
  local l = league_of(c, c.team)
  if l and c.lg.matchdays > 0 and not (c.out and c.out_reason == "superliga") then
    local days = Season.league_days(c.leagues[l], c.double)
    for d, day in ipairs(days) do
      local played = c.lg.results[l][d] and mine(c.lg.results[l][d], c.team)
      local m = played or mine(day, c.team)
      out[#out + 1] = { label = "RoundLeague", n = d, home = m and m[1] or 0, away = m and m[2] or 0,
        hg = played and played[3] or -1, ag = played and played[4] or -1, pens = 0,
        current = c.phase == "league" and d == c.lg.matchday, date = Calendar.view(day_of(c, "league", d)) }
    end
  end
  if c.ff then
    for r, round in ipairs(c.ff.rounds) do
      local played = c.ff.results[r] and mine(c.ff.results[r], c.team)
      local m = played or mine(round, c.team)
      if m then
        out[#out + 1] = { label = "Frontier" .. c.ff.labels[r], n = r, home = m[1], away = m[2],
          hg = played and played[3] or -1, ag = played and played[4] or -1, pens = played and played[5] or 0,
          current = c.phase == "frontier" and r == c.ff.round, date = Calendar.view(day_of(c, "frontier", r)) }
      end
    end
  end
  local w = worldcup_of(c)
  if w and w.stage ~= "call" then
    local side = w.side
    for d = 1, w.format.group_days do
      local played = w.results[d] and mine(w.results[d], side)
      local m = played
      if not m then
        for _, days in ipairs(w.days) do m = m or mine(days[d] or {}, side) end
      end
      out[#out + 1] = { label = "WorldCupGroup", n = d, home = m and m[1] or 0, away = m and m[2] or 0,
        hg = played and played[3] or -1, ag = played and played[4] or -1, pens = 0,
        current = w.stage == "groups" and d == w.matchday, date = Calendar.view(w.dates[d]) }
    end
    for r, round in ipairs(w.ko and w.ko.rounds or {}) do
      local played = w.ko.results[r] and mine(w.ko.results[r], side)
      local m = played or mine(round, side)
      if m then
        out[#out + 1] = { label = "WorldCup" .. w.ko.labels[r], n = r, home = m[1], away = m[2],
          hg = played and played[3] or -1, ag = played and played[4] or -1, pens = played and played[5] or 0,
          current = w.stage == "knockout" and r == w.ko.round, date = Calendar.view(w.dates[w.format.group_days + r]) }
      end
    end
  end
  return out
end

-- the player's last results, oldest first: "W" / "D" / "L"
local function form(c)
  local out = {}
  local function add(r)
    if r == nil then return end
    local side = r[1] == c.team and 1 or 2
    local gf, ga = r[side + 2], r[5 - side]
    if gf == ga and (r[5] or 0) ~= 0 then
      out[#out + 1] = r[5] == c.team and "W" or "L"
    else
      out[#out + 1] = gf > ga and "W" or (gf < ga and "L" or "D")
    end
  end
  for _, round in ipairs(c.sl.results) do add(mine(round, c.team)) end
  local l = league_of(c, c.team)
  if l then
    for d = 1, c.lg.matchdays do add(c.lg.results[l][d] and mine(c.lg.results[l][d], c.team)) end
  end
  if c.ff then
    for _, round in ipairs(c.ff.results) do add(mine(round, c.team)) end
  end
  local keep = int("hub.form_matches", 5)
  while #out > keep do table.remove(out, 1) end
  return out, keep
end

-- the season's days for the hub: today, the next event, the months, the draw, the breaks, the transfer windows (the one
-- open today or the next), the World Cup
local function days_view(c)
  local plan = plan_of(c)
  local today, nxt = today_of(c), next_day_of(c)
  local function spans(list)
    local out = {}
    for i, r in ipairs(list or {}) do out[i] = { from = Calendar.view(r[1]), to = Calendar.view(r[2]) } end
    return out
  end
  local w = window_state(c, today)
  return {
    year = plan.year, today = Calendar.view(today), next = Calendar.view(nxt), draw = Calendar.view(plan.draw),
    start = Calendar.view(plan.start), finish = Calendar.view(plan.finish), months = Calendar.months(plan),
    breaks = spans(plan.breaks), windows = spans(plan.windows),
    world_cup = plan.world_cup and spans({ plan.world_cup })[1] or false,
    world_cup_days = worldcup_of(c) and #worldcup_of(c).dates or 0,
    window = { open = w.open, from = Calendar.view(w.from) or false, to = Calendar.view(w.to) or false },
  }
end

-- lang -> the hub of the season's phase
function CareerMode.Hub(lang)
  local c = load()
  if not c then
    return { ok = false, why = "no career" }
  end
  local list, label, n = fixtures(c)
  local me = me_of(c)
  local m = mine(list, me)
  local w = worldcup_of(c)
  local nxt
  if c.phase == "worldcup" and w and w.stage == "call" then
    nxt = { kind = "wc_call", side = w.side, date = Calendar.view(w.dates[1]) }
  elseif c.phase == "over" then
    nxt = { kind = "over" }
  elseif c.phase == "pots" then
    nxt = { kind = "draw", date = Calendar.view(plan_of(c).draw) }
  elseif m then
    nxt = { kind = "match", home = m[1], away = m[2], label = label, n = n, armed = c.pending ~= nil,
      date = Calendar.view(next_day_of(c)) }
  else
    nxt = { kind = "round", label = label, n = n, date = Calendar.view(next_day_of(c)) }
  end
  local sq = squad_of(c, c.team)
  local f, keep = form(c)
  local count = #competitions(c)
  local shown = default_competition(c)
  return {
    ok = true, team = c.team, season = c.season, phase = c.phase, out = c.out == true, out_reason = c.out_reason or "",
    reached = c.reached or "", champion = c.champion or 0, next = nxt, calendar = calendar(c),
    table = home_table(c), competition = table_view(c, shown), table_index = shown, tables = count,
    league = league_of(c, c.team) or 0, superliga_place = c.sl.place or 0, squad = players_view(sq and sq.players or {}, lang),
    callup = #(sq and sq.players or {}) > match_size(),
    rows_per_page = int("hub.rows_per_page", 10), table_rows = int("hub.table_rows", 18), form = f, form_matches = keep,
    tabs = hub_tabs(c.phase), rating = rating_rules(),
    history = c.history, me = me, worldcup = w and { side = w.side, stage = w.stage, champion = w.champion or 0,
      out = w.out == true, group = worldcup_group_of(w, w.side) or 0, groups = #w.groups, advance = w.format.advance,
      sides = #w.entrants, squad = #w.squad, knockout = w.format.knockout,
      qualified = w.format.qualified or (#w.groups * w.format.advance) } or false,
    clubs = #c.clubs, qualify = season_config().qualify, rounds = season_config().rounds, days = days_view(c),
  }
end

-- (club id) -> { ok, why, size, min, text }: whether a club sells one of its players (config [transfers]
-- min_squad_to_sell: a club with fewer career players refuses, a sale would leave it short; text = the refusal's text
-- key, its arguments the club's name and its squad size). The rule every sale between clubs goes through.
function CareerMode.CanSell(club)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local sq = squad_of(c, u32(club))
  if not sq then return { ok = false, why = "not a club of the career" } end
  local size = #(sq.players or {})
  local least = int("transfers.min_squad_to_sell", 12)
  if size < least then
    return { ok = false, why = "squad too short to sell", size = size, min = least, text = "TransferRefusedShortSquad" }
  end
  return { ok = true, size = size, min = least }
end

-- day (a day number of lib/calendar.lua; nil = the career's today) -> { ok, open, from, to }: whether a transfer window
-- of the career's season is open on that day (from / to = its days; when closed, the next window's, nil when none)
function CareerMode.WindowAt(day)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local z = tonumber(day) and floor(tonumber(day)) or today_of(c)
  local w = window_state(c, z)
  return { ok = true, day = z, open = w.open, from = w.from, to = w.to }
end

-- a knockout result oriented to its upper entrant: { w = 1 upper won / 2 lower won, score = { ga, gb, pa, pb } }
local function tree_match(r, upper)
  if not r then return { w = 0, score = false } end
  local winner = Season.winner(r)
  local same = r[1] == upper
  return { w = winner == upper and 1 or 2, score = {
    ga = same and r[3] or r[4], gb = same and r[4] or r[3],
    pa = (same and r[6] or r[7]) or 0, pb = (same and r[7] or r[6]) or 0, et = false } }
end

-- the result of the match between a and b in a round's results (either side at home)
local function result_of(results, a, b)
  for _, r in ipairs(results or {}) do
    if (r[1] == a and r[2] == b) or (r[1] == b and r[2] == a) then return r end
  end
  return nil
end

-- the World Cup's knockout as a tree for the framework's bracket screen (VRFW_Bracket; Competition.bracket_view):
-- single matches, round 1 = its first round, a shoot-out's kicks as pa / pb
local function worldcup_tree(c)
  local w = c.wc
  local first = w.ko.rounds[1] or {}
  local rounds = 0
  while 2 ^ rounds < 2 * #first do rounds = rounds + 1 end
  local leaves = {}
  for _, m in ipairs(first) do
    leaves[#leaves + 1] = { team = m[1], me = m[1] == w.side }
    leaves[#leaves + 1] = { team = m[2], me = m[2] == w.side }
  end
  local v = Competition.bracket_view({
    rounds = rounds, leaves = leaves, champion = w.champion or 0, next_from = 1,
    match = function(r, _, a, b)
      local res = (a ~= 0 and b ~= 0) and result_of(w.ko.results[r], a, b) or nil
      return res and tree_match(res, a) or nil
    end,
  })
  v.page, v.pages, v.outcome = 0, { 0 }, ""
  if (w.champion or 0) ~= 0 then v.outcome = w.champion == w.side and "champion" or "" end
  return v
end

-- page -> the World Cup's knockout as a tree for the bracket screen (kind "none" before it is drawn)
function CareerMode.WorldCupTree(page)
  local c = load()
  local w = c and worldcup_of(c)
  if w and w.ko then return worldcup_tree(c) end
  return { kind = "none" }
end

-- page -> the Fútbol Frontier as a knockout tree for the framework's bracket screen (VRFW_Bracket;
-- Competition.bracket_view): round 1 = the play-off, each slot of the round after it two leaves (a direct club and an
-- empty bye leaf, its match won with no score; or a play-off match's two clubs), then every later round; single
-- matches, a shoot-out's kicks as pa / pb; the next rival from round 2 on
function CareerMode.Tree(page)
  local c = load()
  if not c or not c.ff then return { kind = "none" } end
  local slots = frontier_slots(c)
  if not Competition.is_power_of_two(#slots) then return { kind = "none", why = "the slots are not a power of two" } end
  local rounds = 1
  while 2 ^ rounds < #slots do rounds = rounds + 1 end
  rounds = rounds + 1
  local leaves, first = {}, {}
  for k, slot in ipairs(slots) do
    if slot.kind == "direct" then
      leaves[#leaves + 1] = slot.team
      leaves[#leaves + 1] = 0
      first[k] = { w = 1, score = false }
    else
      local m = c.ff.rounds[1][slot.match] or { 0, 0 }
      local r = c.ff.results[1] and c.ff.results[1][slot.match]
      leaves[#leaves + 1] = m[1]
      leaves[#leaves + 1] = m[2]
      first[k] = r and tree_match(r, m[1]) or nil
    end
  end
  local v = Competition.bracket_view({
    rounds = rounds, leaves = leaves, me = c.team, champion = c.champion or 0, next_from = 2,
    match = function(r, t, a, b)
      if r == 1 then return first[t] end
      local res = (a ~= 0 and b ~= 0) and result_of(c.ff.results[r], a, b) or nil
      return res and tree_match(res, a) or nil
    end,
  })
  v.page, v.pages, v.outcome = 0, { 0 }, ""
  if (c.champion or 0) ~= 0 then v.outcome = c.champion == c.team and "champion" or "" end
  return v
end

-- table index (1 SuperLiga, 1 + l league l) -> { ok, index, tables, table }
function CareerMode.Standings(i)
  local c = load()
  if not c then
    return { ok = false, why = "no career" }
  end
  i = floor(tonumber(i) or default_competition(c))
  local count = #competitions(c)
  if i < 1 or i > count then
    return { ok = false, why = "no competition " .. tostring(i) }
  end
  return { ok = true, index = i, tables = count, table = table_view(c, i) }
end

-- team, lang -> { ok, team, players = { { card, number, slot, position, name, signed } }, rows = { slot, card, … } }:
-- a club's career squad (else its declaration) and the roster rows the career changes
function CareerMode.Club(team, lang)
  team = u32(team)
  local c = load()
  local sq = c and squad_of(c, team) or (PENDING and PENDING.built.squads[team]) or nil
  local players, rows = sq and sq.players, sq and sq.rows or {}
  if players == nil then
    clubs()
    local t = team_by_id(team)
    players = t and t.players or nil
  end
  if players == nil then
    return { ok = false, why = "unknown club" }
  end
  return { ok = true, team = team, players = players_view(players, lang), rows = rows }
end

-- -> { ok, teams = { { team, rows = { slot, card, … } } } }: every career club whose roster rows the career changes
function CareerMode.Rosters()
  local c = load()
  local out = {}
  if c then
    for i, t in ipairs(c.clubs) do
      local sq = c.squads[i]
      if sq and sq.rows and #sq.rows > 0 then out[#out + 1] = { team = t, rows = sq.rows } end
    end
  elseif PENDING then
    for _, t in ipairs(PENDING.built.clubs) do
      local sq = PENDING.built.squads[t]
      if sq and #sq.rows > 0 then out[#out + 1] = { team = t, rows = sq.rows } end
    end
  end
  return { ok = true, teams = out }
end

-- -> { ok, why, home, away, rival, host, friendly, game, difficulty, user_team, rival_team, user_cards, rival_cards }:
-- the player's match armed (its result comes
-- from the game when it ends)
function CareerMode.Play()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local list, _, round = fixtures(c)
  local me = me_of(c)
  local m = mine(list, me)
  if not m then return { ok = false, why = "no match for the club" } end
  c.pending = { phase = c.phase, round = round, home = m[1], away = m[2], me = me,
    final = c.phase == "frontier" and #list == 1 }
  save()
  info(string.format("match armed: %s round %d, %08X - %08X", c.phase, round, m[1], m[2]))
  local rival = m[1] == me and m[2] or m[1]
  local user_cards, rival_cards = match_cards(c, c.team), match_cards(c, rival)
  if c.phase == "worldcup" then
    user_cards, rival_cards = {}, {}
    for i, card in ipairs(c.wc.squad) do user_cards[i] = card end
    clubs()
    local country = COUNTRY and COUNTRY[rival] or nil
    local most = int("teams.player_slot_max", 18) + 1
    for _, p in ipairs(country and worldcup_pool(country) or {}) do
      if #rival_cards < most then rival_cards[#rival_cards + 1] = p.card end
    end
  end
  return { ok = true, home = m[1], away = m[2], rival = rival, host = m[1], user = me,
    friendly = tostring(config("match.friendly", "career_match")), game = config("match.game", "fbtl_bb_stadium_00"),
    difficulty = int("match.difficulty", 1), user_team = tostring(config("match.user_team", "evt_career_user")),
    rival_team = tostring(config("match.rival_team", "evt_career_rival")), user_cards = user_cards,
    rival_cards = rival_cards }
end

-- -> { ok }: the armed match given up (no match started)
function CareerMode.Disarm()
  local c = load()
  if c and c.pending then
    c.pending = nil
    save()
  end
  return { ok = true }
end

-- -> { ok, result }: the round played without the player (his match simulated, or a round he has no match in)
function CareerMode.Sim()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  if c.phase == "over" or c.phase == "pots" or (c.phase == "worldcup" and c.wc.stage == "call") then
    return { ok = false, why = "no round to play" }
  end
  c.pending = nil
  local r = play_round(c, nil)
  settle(c)
  save()
  return { ok = true, result = r }
end

-- -> { ok, pots = { { ids } }, leagues = { { ids } } }: the draw the screen shows ball by ball
function CareerMode.Pots()
  local c = load()
  if not c or #(c.pots or {}) == 0 then return { ok = false, why = "no draw" } end
  return { ok = true, pots = c.pots, leagues = c.leagues, team = c.team }
end

-- -> { ok }: the pots drawn (the leagues start) or the next season (after the season is over)
function CareerMode.Advance()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  if c.phase == "pots" then
    c.phase = "league"
  elseif c.phase == "over" then
    c.season = c.season + 1
    season_start(c)
    info(string.format("season %d starts", c.season))
  else
    return { ok = false, why = "nothing to advance" }
  end
  save()
  return { ok = true }
end

-- the call-up: (lang) -> { ok, why, side, size, keepers, picked, goalkeepers, players = { { card, number, slot,
-- position, name, picked, team } } }: the players the coach may call up, the ones picked
local function worldcup_pool_view(c, lang)
  local w = worldcup_of(c)
  if c.phase ~= "worldcup" or not w or w.stage ~= "call" then return { ok = false, why = "no call-up" } end
  local cfg = worldcup_config()
  local pool = worldcup_pool(w.country)
  local picked = {}
  for _, card in ipairs(w.squad) do picked[card] = true end
  local view = players_view(pool, lang)
  local keepers = 0
  for i, p in ipairs(view) do
    p.picked, p.team = picked[p.card] == true, pool[i].team
    if p.picked and p.position == 1 then keepers = keepers + 1 end
  end
  return { ok = true, side = w.side, size = cfg.squad, keepers = cfg.keepers, picked = #w.squad, goalkeepers = keepers,
    players = view }
end

-- the player's club's call-up: its squad, the players it takes to its matches (c.callup; the default: its best)
local function club_callup_view(c, lang)
  local cards = squad_cards(c, c.team)
  local size, keepers = match_size()
  if #cards <= size then return { ok = false, why = "the whole squad plays" } end
  if type(c.callup) ~= "table" then c.callup = match_cards(c, c.team) end
  local picked, goalkeepers = {}, 0
  for _, card in ipairs(c.callup) do picked[u32(card)] = true end
  local sq = squad_of(c, c.team)
  local view = players_view(sq and sq.players or {}, lang)
  for _, p in ipairs(view) do
    p.picked, p.team = picked[p.card] == true, c.team
    if p.picked and p.position == 1 then goalkeepers = goalkeepers + 1 end
  end
  return { ok = true, kind = "club", side = c.team, size = size, keepers = keepers, picked = #c.callup,
    goalkeepers = goalkeepers, players = view }
end

-- lang -> the club's call-up view { ok, kind = "club", side, size, keepers, picked, goalkeepers, players }
function CareerMode.ClubCallUp(lang)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  return club_callup_view(c, lang)
end

-- (card, lang) -> the club's call-up with that player called up or left out (a full call-up takes nobody more)
function CareerMode.ClubCallUpPick(card, lang)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local v = club_callup_view(c, lang)
  if not v.ok then return v end
  card = u32(card)
  local at
  for i, x in ipairs(c.callup) do
    if u32(x) == card then at = i end
  end
  if at then
    table.remove(c.callup, at)
  elseif #c.callup < v.size then
    for _, p in ipairs(v.players) do
      if p.card == card then c.callup[#c.callup + 1] = card end
    end
  end
  return club_callup_view(c, lang)
end

-- -> { ok, why }: the club's call-up kept (full, with its goalkeepers)
function CareerMode.ClubCallUpConfirm()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local v = club_callup_view(c, 0)
  if not v.ok then return v end
  local squad_keepers = 0
  for _, p in ipairs(v.players) do
    if p.position == 1 then squad_keepers = squad_keepers + 1 end
  end
  if v.picked ~= v.size or v.goalkeepers < math.min(v.keepers, squad_keepers) then
    return { ok = false, why = "the call-up needs " .. v.size .. " players and " .. v.keepers .. " goalkeepers" }
  end
  save()
  info(string.format("club call-up kept: %d players", v.picked))
  return { ok = true }
end

function CareerMode.WorldCupPool(lang)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  return worldcup_pool_view(c, lang)
end

-- (card, lang) -> the call-up view with that player called up or left out (a full squad takes nobody more)
function CareerMode.WorldCupPick(card, lang)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local w = worldcup_of(c)
  if c.phase ~= "worldcup" or not w or w.stage ~= "call" then return { ok = false, why = "no call-up" } end
  card = u32(card)
  local at
  for i, x in ipairs(w.squad) do
    if x == card then at = i end
  end
  if at then
    table.remove(w.squad, at)
  elseif #w.squad < worldcup_config().squad then
    local known = false
    for _, p in ipairs(worldcup_pool(w.country)) do
      if p.card == card then known = true end
    end
    if known then w.squad[#w.squad + 1] = card end
  end
  return worldcup_pool_view(c, lang)
end

-- -> { ok, why }: the squad confirmed (full, with its goalkeepers): the group stage starts
function CareerMode.WorldCupConfirm()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local v = worldcup_pool_view(c, 0)
  if not v.ok then return v end
  local pool_keepers = 0
  for _, p in ipairs(v.players) do
    if p.position == 1 then pool_keepers = pool_keepers + 1 end
  end
  if v.picked ~= v.size or v.goalkeepers < math.min(v.keepers, pool_keepers) then
    return { ok = false, why = "the squad needs " .. v.size .. " players and " .. v.keepers .. " goalkeepers" }
  end
  c.wc.stage = "groups"
  save()
  info(string.format("World Cup squad of %08X confirmed: %d players", c.wc.side, #c.wc.squad))
  return { ok = true }
end

-- the game's own result of the armed match (VRFW MatchResult.last): the round played with it; a won final asks
-- the trophy lift of the mod that answers config [match] trophy_signal
VRFW.on("signal:vrfw.match_result", function()
  local c = load()
  local p = c and c.pending
  if not p or p.phase ~= c.phase then return nil end
  local _, _, round = fixtures(c)
  if p.round ~= round then return nil end
  local results = rawget(_G, "MatchResult")
  local last = type(results) == "table" and results.last or nil
  if type(last) ~= "table" then return nil end
  local f, a = floor(tonumber(last.score_for) or 0), floor(tonumber(last.score_against) or 0)
  local me = p.me or c.team
  local home = p.home == me
  local r = { p.home, p.away, home and f or a, home and a or f, 0 }
  if f == a then
    if last.outcome == "win" then r[5] = me
    elseif last.outcome == "loss" then r[5] = home and p.away or p.home end
  end
  c.pending, c.fresh = nil, true
  info(string.format("the club's match: %s %d-%d (%s)", tostring(last.outcome), f, a, c.phase))
  local final = p.final
  local mine_result = play_round(c, r)
  if final and p.phase ~= "worldcup" and mine_result and Season.winner(mine_result) == c.team and last.outcome == "win" then
    local name = tostring(config("match.trophy_signal", ""))
    if name ~= "" then pcall(VRFW.signal, name) end
  end
  settle(c)
  save()
  return nil
end)
