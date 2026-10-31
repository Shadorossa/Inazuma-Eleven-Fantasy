-- Career mode («Modo carrera», docs/game/mods/career-mode-proposal.md): up to config [careers] slots careers per save
-- slot, kept in the slot's save blobs career.json (career 1) and career_<k>.json. The clubs and their squads
-- (lib/squads.lua: every player once per career), the season (lib/
-- season.lua: SuperLiga, pots, leagues, Fútbol Frontier), the matches the player plays (the game's own result, signal
-- vrfw.match_result), the season's days (lib/calendar.lua: a date for every fixture, the transfer windows, the World
-- Cup), the World Cup after the club season (lib/worldcup.lua: the national sides, the squad the player picks) and the
-- views the hub screen (evt_career_menu) draws. Commands: content\game\commands.toml; among them, for «Torneos»:
--   CMND_CAREERMODE_COMPETITIONS () -> { ok, why, items = { { index, kind, key, league } }, default }
--   CMND_CAREERMODE_STATS (competition index, sort, first, count, language) -> { ok, why, index, kind, key, sort,
--     total, first, rows = { { rank, card, name, team, position, matches, goals, saves, clean_sheets, rating, mvp } } }
local Teams = require "lib/teams"
local Squads = require "lib/squads"
local Season = require "lib/season"
local Competition = require "VRFW/lib/competition"
local GameText = require "VRFW/lib/game_text"
local Calendar = require "lib/calendar"
local Worldcup = require "lib/worldcup"
local Market = require "lib/market"
local News = require "lib/news"
local Levels = require "lib/levels"
local Board = require "lib/board"

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
    order_file = tostring(config("squads.order_file", "content/career/club_order.toml")),
    min_players = int("squads.min_players", 11),
    fill_to = int("squads.fill_to", 16),
    strength_column = tostring(config("squads.strength_column", "rank")),
    strength_reach = int("squads.strength_reach", 5),
    same_game_first = config("squads.same_game_first", true) ~= false,
    free_need_team = config("squads.free_need_team", true) ~= false,
    max_players = int("squads.max_players", 21),
    exclude_no_face = config("squads.exclude_no_face", true) ~= false,
    exclude_aura_types = list_of(config("squads.exclude_aura_types", nil), { 2 }),
    exclude_staff = config("squads.exclude_staff", true) ~= false,
    home_own_game_first = config("squads.home_own_game_first", true) ~= false,
    -- the players of the teams of no career (config [teams] career_exclude; set when the clubs are read)
    exclude_cards = OUT_CARDS or {},
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
    entrants = int("frontier.entrants", 0),
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

-- the club card's rules (config.toml [rating]) the screen applies to the game's stats; `clubs` = { { team, rating } }
-- (the career's club ratings, config [ratings]): the stars rank the clubs by them
local function rating_rules(clubs)
  return {
    clubs = clubs or {},
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
    stars_by_rating = tostring(config("ratings.source", "")) == "levels" and config("rating.stars_by_rating", nil) or nil,
  }
end

-- the hub's tabs of a phase (config.toml [hub] tabs; a tab with `phases` shows only in those): { id, text, icon }
local function hub_tabs(phase, callup, market)
  local out = {}
  local v = config("hub.tabs", nil)
  for _, t in ipairs(type(v) == "table" and v or {}) do
    if type(t) == "table" and type(t.id) == "string" and t.id ~= "" then
      local show = type(t.phases) ~= "table"
      for _, p in ipairs(type(t.phases) == "table" and t.phases or {}) do
        if p == phase then show = true end
      end
      -- a tab for the club's call-up: only while its squad is larger than a match takes
      if t.callup == true and not callup then show = false end
      -- a tab of the transfer market: only in a career with the market on (its setup option)
      if t.market == true and not market then show = false end
      if show then out[#out + 1] = { id = t.id, text = tostring(t.text or ""), icon = tostring(t.icon or "") } end
    end
  end
  if #out == 0 then
    out = { { id = "home", text = "TabHome", icon = "icon_list_tab_town01" } }
  end
  return out
end

-- ------------------------------------------------------------------------- the career's options (config.toml [setup])

-- an option's presets (config [setup] <name>: rows { id, text, ... } in order)
local function setup_list(name)
  local out = {}
  local v = config("setup." .. name, nil)
  for _, r in ipairs(type(v) == "table" and v or {}) do
    if type(r) == "table" and type(r.id) == "string" and r.id ~= "" then out[#out + 1] = r end
  end
  return out
end

-- the preset whose id is `id`, else the list's default (1-based index)
local function setup_pick(list, id, default)
  for _, r in ipairs(list) do
    if r.id == id then return r end
  end
  return list[default] or list[1] or {}
end

-- the financial backing amounts a new career may start with (config [setup] backing_steps, the mode's money)
local function backing_steps()
  local out = {}
  local v = config("setup.backing_steps", nil)
  for _, x in ipairs(type(v) == "table" and v or {}) do
    if tonumber(x) and tonumber(x) >= 0 then out[#out + 1] = math.floor(tonumber(x)) end
  end
  if #out == 0 then out = { 0 } end
  return out
end

-- a career's options resolved: market on / off, the backing, the negotiation and market activity presets, sacking.
-- A career started before the options: the defaults, the market on, sacking off.
local function options_of(c)
  local o = type(c) == "table" and type(c.options) == "table" and c.options or {}
  return {
    market = o.market ~= false,
    backing = tonumber(o.backing) or 0,
    negotiation = setup_pick(setup_list("negotiation"), o.negotiation, int("setup.negotiation_default", 2)),
    activity = setup_pick(setup_list("activity"), o.activity, int("setup.activity_default", 3)),
    sacking = o.sacking == true,
  }
end

-- game_state careermode.skill_board_locked (content\game\commands.toml): 1 while the career's team screen is up; the
-- VR-Framework's skill board lock reads it (content\skill_board_lock\career.toml)
local SKILL_BOARD_LOCK_KEY = "careermode.skill_board_locked"
local skill_board_locked = nil

local function set_skill_board_lock(on, why)
  local v = on and 1 or 0
  if v == skill_board_locked then return end
  local ok, e = pcall(VRFW.state.set, SKILL_BOARD_LOCK_KEY, v)
  if not ok then
    warn(SKILL_BOARD_LOCK_KEY .. ": " .. tostring(e))
    return
  end
  skill_board_locked = v
  info(string.format("%s = %d (%s)", SKILL_BOARD_LOCK_KEY, v, why))
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

-- the careers of a save slot: config [careers] slots of them; career k is the save blob career.json (k = 1, the
-- single career of earlier versions) or career_<k>.json; the active one is the slot's key career_slot, each one's
-- summary for the title menu the key career_summary_<k> (written with the career)
local function career_count()
  return math.max(1, int("careers.slots", 4))
end

local function blob_of(k)
  return k == 1 and BLOB or string.format("career_%d.json", k)
end

local function active_career()
  local ok, k = pcall(VRFW.save.get, "career_slot", 1)
  k = ok and tonumber(k) or 1
  return math.max(1, math.min(career_count(), floor(k)))
end

local function career_key()
  return current_slot() .. ":" .. active_career()
end

local enforce_cap     -- (career): every squad within config [squads] max_players (defined with the squads)
local drop_excluded   -- (career): the cards no career has out of the other clubs' squads (defined with the squads)
local levels_ready    -- (career): the levels of a career started before them (defined with the levels)
local summarize       -- (career): its title menu summary (defined with the hub)
local board_now       -- (career) -> the season's state for the board's objectives (defined with the hub)
local save

-- career k of the slot read from its blob: the career, nil (none, or not of this version)
local function read_career(n, k)
  local ok, b = pcall(VRFW.save.blob, blob_of(k), n)
  if not (ok and type(b) == "string" and b ~= "") then return nil end
  local doc, why = VRFW.json.decode(b)
  if type(doc) == "table" and doc.v == VERSION then return doc end
  warn(blob_of(k) .. " (slot " .. n .. ") is not a career of this version (" .. tostring(why or doc and doc.v) ..
    "): no career")
  return nil
end

local function load()
  local key = career_key()
  if CAREER_SLOT == key then
    return CAREER
  end
  CAREER, CAREER_SLOT = nil, key
  local n, k = current_slot(), active_career()
  local doc = read_career(n, k)
  if doc then
    CAREER = doc
    if enforce_cap then enforce_cap(doc) end
    if drop_excluded then drop_excluded(doc) end
    info(string.format("career %d of slot %d: team %08X, season %d, %s", k, n, doc.team, doc.season, doc.phase))
    if levels_ready then levels_ready(doc) end
  end
  return CAREER
end

-- a career's summary kept under the slot's key career_summary_<k>
local function write_summary(k, c)
  local ok, sum = pcall(summarize, c)
  if not (ok and type(sum) == "table") then
    warn("career " .. k .. ": summary not made: " .. tostring(sum))
    return
  end
  pcall(VRFW.save.set, "career_summary_" .. k, sum)
  pcall(VRFW.save.commit)
end

-- force: written even with the career's autosave off (its «Guardar progreso», its autosave setting)
save = function(force)
  if not CAREER then
    return false
  end
  if not force and CAREER.autosave == false then
    return true
  end
  local n, k = current_slot(), active_career()
  CAREER.saved_at = VRFW.time.stamp()
  local ok, done, why = pcall(VRFW.save.blob_write, blob_of(k), VRFW.json.encode(CAREER), n)
  if not (ok and done) then
    warn(blob_of(k) .. " (slot " .. n .. ") not written: " .. tostring(ok and why or done))
    return false
  end
  write_summary(k, CAREER)
  return true
end

-- ------------------------------------------------------------------------------------------------ clubs

local CLUBS, CLUBS_WHY, FAMILY = nil, nil, nil
local NATIONS = nil      -- the national sides (config.toml [teams] national_*): no club competition, whole rosters
local OUT_CARDS = nil    -- the cards of config [teams] career_exclude teams that no other career team has: set [card]
local TEAMS_BY_ID = nil  -- every career team by id (clubs, national sides, merged versions, dropped teams)
local COUNTRY = nil      -- national team id -> its country (config.toml [[world_cup.countries]]; unlisted: its key)
local COUNTRY_TEAMS = nil   -- country -> its national teams, the first one plays the World Cup (its name, crest, kit)
local COUNTRY_POOL = nil    -- country -> its pool teams (config pool_teams): their players have its nationality
local PENDING = nil      -- the club pick's squads: { seed, built }
local DRAWS = 0

-- the entries of one type of a career data file (kind CareerMode.career/1: [[CareerMode.<type>]]) -> list
local function career_entries(doc, type_name)
  local own = type(doc) == "table" and doc.CareerMode
  local list = type(own) == "table" and own[type_name]
  return type(list) == "table" and list or {}
end

-- the career's clubs file (config [squads] clubs_file, content/career/clubs.toml): its merged clubs get their
-- versions (t.versions, no clubs of their own), its teams of no club are dropped -> the club list
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
  for _, d in ipairs(career_entries(doc, "NoClub")) do
    if type(d) == "table" and d.key ~= nil then gone[tostring(d.key)] = true end
  end
  local merged, apart = 0, 0
  local least = tonumber(config("squads.merge_overlap", 0.3)) or 0.3
  for _, cl in ipairs(career_entries(doc, "Club")) do
    local key = type(cl) == "table" and tostring(cl.key or "") or ""
    local main = by_key[key]
    if main == nil or gone[key] then
      warn("clubs file: club " .. key .. " is no career club here (unknown, national or dropped)")
    else
      main.versions = {}
      for _, k in ipairs(type(cl.versions) == "table" and cl.versions or {}) do
        local v = by_key[tostring(k)]
        local share = v and v ~= main and Squads.overlap(main.players, v.players) or 0
        if v and v ~= main and not gone[v.key] and share < least then
          -- another team of the name (other players: another era): a club of its own
          apart = apart + 1
          info(string.format("clubs file: %s is no version of %s (%.0f%% of the players shared): a club of its own",
            v.key, key, share * 100))
        elseif v and v ~= main and not gone[v.key] then
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
  info(string.format("clubs file: %d merged clubs, %d teams merged or dropped, %d versions apart, %d clubs", merged,
    #list - #out, apart, #out))
  return out
end

-- the clubs file's game teams (content/career/clubs.toml [[CareerMode.GameClub]]) added to `list`: the team of the
-- game's team table with the entry's name text and series
local function game_clubs(list)
  local path = tostring(config("squads.clubs_file", ""))
  local ok, doc = pcall(VRFW.files.toml, path)
  if path == "" or not ok or type(doc) ~= "table" then return end
  local entries, keys, have = career_entries(doc, "GameClub"), {}, {}
  for _, t in ipairs(list) do have[t.key] = true end
  for _, e in ipairs(entries) do
    if type(e) == "table" and e.key ~= nil and not have[tostring(e.key)] then keys[#keys + 1] = tostring(e.key) end
  end
  if #keys == 0 then return end
  local game = Teams.game_teams(keys)
  for _, e in ipairs(entries) do
    local t = type(e) == "table" and game[tostring(e.key or "")] or nil
    if t then
      if tonumber(e.name_text) then t.name_text, t.named = u32(tonumber(e.name_text)), true end
      t.series = tostring(e.series or "")
      list[#list + 1] = t
      info(string.format("clubs file: game team %s is a club (%d players)", t.key, #t.players))
    elseif type(e) == "table" then
      warn("clubs file: game team " .. tostring(e.key) .. " not in the game's team table")
    end
  end
end

local function clubs()
  if CLUBS == nil and CLUBS_WHY == nil then
    local list, why = Teams.load()
    if list then
      game_clubs(list)
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
      -- the teams of no career (config [teams] career_exclude) out, and their players that no other team has
      local out_keys = {}
      for _, k in ipairs(config("teams.career_exclude", {}) or {}) do out_keys[tostring(k)] = true end
      local kept_list, others, gone = {}, {}, {}
      for _, t in ipairs(club_list) do
        if out_keys[t.key] then gone[#gone + 1] = t else kept_list[#kept_list + 1] = t end
      end
      for _, t in ipairs(list) do
        if not out_keys[t.key] then
          for _, p in ipairs(t.players or {}) do others[u32(p.card)] = true end
        end
      end
      OUT_CARDS = {}
      local out_count = 0
      for _, t in ipairs(gone) do
        for _, p in ipairs(t.players or {}) do
          if not others[u32(p.card)] and not OUT_CARDS[u32(p.card)] then
            OUT_CARDS[u32(p.card)], out_count = true, out_count + 1
          end
        end
      end
      club_list = kept_list
      info(string.format("teams of no career: %d left out, %d of their players with them", #gone, out_count))
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

-- the career's clubs whose names another of them has too -> { { team, tag } }: the tag of the club's series (config
-- [teams] series_tags, else the series itself; none for a series without one)
local function club_tags(c)
  clubs()
  local list = {}
  for _, id in ipairs(c.clubs or {}) do
    local t = TEAMS_BY_ID and TEAMS_BY_ID[id]
    if t then list[#list + 1] = t end
  end
  local tags = config("teams.series_tags", {})
  tags = type(tags) == "table" and tags or {}
  local out = {}
  for id, series in pairs(Teams.name_clashes(list)) do
    local tag = tags[series] ~= nil and tostring(tags[series]) or series
    if tag ~= "" then out[#out + 1] = { team = id, tag = tag } end
  end
  table.sort(out, function(a, b) return a.team < b.team end)
  return out
end

-- the career's clubs named by the clubs file (a game club's name_text) -> { { team, name } } in `lang`: the menu shows
-- these names instead of the team table's
local function club_names(c, lang)
  clubs()
  local texts, by = {}, {}
  for _, id in ipairs(c.clubs or {}) do
    local t = TEAMS_BY_ID and TEAMS_BY_ID[id]
    if t and t.named and (t.name_text or 0) ~= 0 then
      by[id] = t.name_text
      texts[#texts + 1] = t.name_text
    end
  end
  if #texts == 0 then return {} end
  local names = GameText.team_names(texts, GameText.language(lang))
  local out = {}
  for id, text in pairs(by) do
    if (names[text] or "") ~= "" then out[#out + 1] = { team = id, name = names[text] } end
  end
  table.sort(out, function(a, b) return a.team < b.team end)
  return out
end

local function new_seed()
  DRAWS = DRAWS + 1
  return u32(floor(VRFW.now()) * 2654435761 + DRAWS * 40503 + current_slot())
end

-- the club order's game of every club (the club pick's groups)
local function games_of(list)
  local ok, doc = pcall(VRFW.files.toml, squads_config().order_file)
  local order = {}
  for _, o in ipairs(ok and career_entries(doc, "ClubOrder") or {}) do
    if type(o) == "table" and o.key ~= nil then order[tostring(o.key)] = o end
  end
  local out = {}
  for _, t in ipairs(list) do
    local o = order[t.key]
    out[t.id] = type(o) == "table" and floor(tonumber(o.game) or 99) or 99
  end
  return out
end

-- the career's clubs grouped by the club order's game: { { game, { team, ... } }, ... } by game, the career's order
-- inside a game (the market's club list); worked out once per career table
local CLUB_GROUPS = setmetatable({}, { __mode = "k" })
local function club_groups(c)
  if CLUB_GROUPS[c] then return CLUB_GROUPS[c] end
  local list = clubs()
  local games = list and games_of(list) or {}
  local by, keys = {}, {}
  for _, t in ipairs(c.clubs) do
    local g = games[t] or 99
    if by[g] == nil then
      by[g] = {}
      keys[#keys + 1] = g
    end
    by[g][#by[g] + 1] = t
  end
  table.sort(keys)
  local out = {}
  for i, g in ipairs(keys) do out[i] = { g, by[g] } end
  CLUB_GROUPS[c] = out
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

-- card -> { strength (config [squads] strength_column), position, series (the character's source series type) }
local CARD_INFO = nil
local function card_info(card)
  if CARD_INFO == nil then
    CARD_INFO = {}
    local col = tostring(config("squads.strength_column", "rank"))
    local ok, list = pcall(VRFW.chara.cards, { columns = { col }, character = true })
    for _, k in ipairs(ok and type(list) == "table" and list or {}) do
      CARD_INFO[u32(k.id)] = { strength = tonumber(type(k.cols) == "table" and k.cols[col]) or 0,
        position = floor(tonumber(k.position) or 0), series = floor(tonumber(k.series) or 0) }
    end
  end
  return CARD_INFO[u32(card)] or { strength = 0, position = 0, series = 0 }
end

-- ------------------------------------------------------------------------------------------------ levels

-- every team the career reads (clubs, national sides, merged versions, dropped teams): the levels' fame
local function source_teams()
  clubs()
  local out = {}
  for _, t in pairs(TEAMS_BY_ID or {}) do out[#out + 1] = t end
  return out
end

-- the levels' helpers from the career (lib/levels.lua)
local LEVELS_ENV = nil
local function levels_env()
  if LEVELS_ENV == nil then
    LEVELS_ENV = { config = config, teams = source_teams }
  end
  return LEVELS_ENV
end

-- config [ratings] source = "levels": the clubs rated by their players' career levels
local function rated_by_levels()
  return tostring(config("ratings.source", "")) == "levels"
end

-- every squad of a career (or of the club pick) by club index -> { players }
local function squads_by_index(list)
  local out = {}
  for i, sq in ipairs(list or {}) do out[i] = sq end
  return out
end

-- every club's squad within config [squads] max_players (owner 2026-10-31: 21 players, 3 managers and 1 coach; the
-- career's clubs sign no staff, they keep their team's own): the players on a roster row stay, then the bench by
-- strength; the others become free players. Checked once per career and cap (careers started before the cap).
enforce_cap = function(c)
  local most = int("squads.max_players", 21)
  if c.squad_cap == most then return end
  local left = 0
  local own = index_of(c)[c.team]
  for i, sq in ipairs(c.squads or {}) do
    -- the player's own club loses nobody: over the cap it only cannot sign until it sells
    if i ~= own then
      local n
      sq.players, n = Squads.trim(sq.players or {}, most, function(card) return card_info(card).strength end)
      left = left + n
    end
  end
  c.squad_cap = most
  if type(c.market) == "table" then c.market.rev = (c.market.rev or 0) + 1 end
  info(string.format("squad cap %d: %d player(s) over it left their clubs", most, left))
  save()
end

-- the cards no career has (Squads.excluded: no face of their own, the excluded aura variants) out of the other clubs'
-- squads of a career started before the rule, once per career and rule set; the player's club keeps them (logged)
drop_excluded = function(c)
  local cfg = squads_config()
  local mark = (cfg.exclude_no_face and "face" or "") .. ":" .. table.concat(cfg.exclude_aura_types, ",")
    .. (cfg.exclude_staff and ":staff" or "")
  if c.excluded_rule == mark then return end
  local excluded = Squads.excluded(cfg)
  local own = index_of(c)[c.team]
  local dropped, kept = 0, 0
  for i, sq in ipairs(c.squads or {}) do
    local players = {}
    for _, p in ipairs(sq.players or {}) do
      local why = excluded[u32(p.card)]
      if why and i ~= own then
        dropped = dropped + 1
      else
        if why then
          kept = kept + 1
          info(string.format("card %08X (%s) stays in the player's club", u32(p.card), why))
        end
        players[#players + 1] = p
      end
    end
    sq.players = players
  end
  c.excluded_rule = mark
  if type(c.market) == "table" then c.market.rev = (c.market.rev or 0) + 1 end
  info(string.format("cards no career has: %d left the other clubs' squads, %d stay in the player's club", dropped,
    kept))
  save()
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

local function match_set(c, team)
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

-- The player's club's lineup (owner 2026-10-30: «Plantilla» is the game's own team screen, as Battle Bay Deluxe's
-- League does): c.lineup = { formation, order = { card by dock position 0.. } } as the player left it in the team dock
-- (positions 0-10 the starters in formation order, then the bench). The match cards keep these positions; a card no
-- longer in the match set leaves a hole, filled by the set's other cards in squad order (a goalkeeper first for
-- position 0).
local STARTERS = 11

local function in_lineup_order(c, cards)
  local order = type(c.lineup) == "table" and type(c.lineup.order) == "table" and c.lineup.order or nil
  if not order then return cards end
  local wanted, used = {}, {}
  for _, card in ipairs(cards) do wanted[u32(card)] = true end
  local out, holes = {}, {}
  for i, card in ipairs(order) do
    card = u32(card)
    if wanted[card] and not used[card] and i <= #cards then
      out[i], used[card] = card, true
    elseif i <= #cards then
      holes[#holes + 1] = i
    end
  end
  for i = #order + 1, #cards do holes[#holes + 1] = i end
  local rest = {}
  for _, card in ipairs(cards) do
    card = u32(card)
    if not used[card] then rest[#rest + 1] = card end
  end
  for _, i in ipairs(holes) do
    local pick = 1
    if i == 1 then
      for k, card in ipairs(rest) do
        if card_info(card).position == 1 then pick = k break end
      end
    end
    out[i] = table.remove(rest, pick)
  end
  local list = {}
  for i = 1, #cards do
    if out[i] then list[#list + 1] = out[i] end
  end
  return list
end

-- the players a club takes to a match; the player's club's in its lineup's order
local function match_cards(c, team)
  local cards = match_set(c, team)
  if team == c.team then return in_lineup_order(c, cards) end
  return cards
end

-- the player's club's match players by dock position: { { card, position } … } (0-10 the starters)
local function lineup_view(c)
  local out = {}
  for i, card in ipairs(match_cards(c, c.team)) do out[i] = { card = card, position = i - 1 } end
  return out
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
  local size = Season.power_below(cfg.direct_places * cfg.leagues + playoff)
  if cfg.entrants > 0 then size = floor(Season.power_below(math.min(cfg.entrants, per * cfg.leagues)) / 2) end
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

-- the days from the last event to the next match (CareerMode.Day walks them one by one): { from, to, done } kept in
-- the career (c.days, made again when the stretch changes); nil when the next event is no match of a season phase or
-- falls on the same day
local DAY_PHASES = { superliga = true, league = true, frontier = true }
local market_day   -- (c, stretch): one market day (defined with play_round)
local function stretch_of(c)
  if not DAY_PHASES[c.phase] then return nil end
  local from, to = today_of(c), next_day_of(c)
  if not to or to <= from then return nil end
  if type(c.days) ~= "table" or c.days.from ~= from or c.days.to ~= to then c.days = { from = from, to = to, done = 0 } end
  return c.days
end

-- the career's day now: the last event's day plus the days walked towards the next match
local function now_of(c)
  local s = stretch_of(c)
  return s and math.min(s.to, s.from + s.done) or today_of(c)
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
local board_news     -- (career, kind, warning or verdict): the board's news item (defined with the news)

-- the club's places now: SuperLiga place, its league (0 = none) and its place there
local function club_places(c)
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
  return place, l or 0, lplace
end

-- the club's place in the career's rating order (1 = the best) and the clubs counted
local function board_rank(c)
  local mine, rank = 0, 1
  for i, t in ipairs(c.clubs) do
    if t == c.team then mine = tonumber(c.ratings[i]) or 0 end
  end
  for i, t in ipairs(c.clubs) do
    if t ~= c.team and (tonumber(c.ratings[i]) or 0) > mine then rank = rank + 1 end
  end
  return rank, #c.clubs
end

local BOARD_ENV = { config = config,
  -- the SuperLiga places that go on to the leagues for `clubs` clubs (a SuperLiga target never lies past them)
  qualify = function(clubs)
    local cfg = season_config()
    return math.min(cfg.qualify, floor(clubs / cfg.leagues) * cfg.leagues)
  end }

-- the season ends: its line in the history, the board's verdict (sacked: the career ends here, no World Cup)
local function season_over(c)
  c.phase = "over"
  local place, l, lplace = club_places(c)
  local verdict = Board.verdict(c, place, lplace, c.reached or "", options_of(c).sacking)
  c.history[#c.history + 1] = { season = c.season, superliga = place, league = l, league_place = lplace,
    reached = c.reached or "", champion = c.champion or 0, board = verdict or nil }
  info(string.format("season %d over: champion %08X, the club's SuperLiga place %d, league %s place %d, reached %s",
    c.season, c.champion or 0, place, tostring(l), lplace, tostring(c.reached)))
  if verdict then
    info(string.format("board: %d objective(s) missed, sacked %s", verdict.missed, tostring(verdict.sacked)))
    if verdict.sacked then
      c.phase = "sacked"
      c.sacked = { season = c.season, superliga = verdict.superliga, league = verdict.league,
        frontier = verdict.frontier }
      pcall(board_news, c, "sacked", verdict)
      return
    end
  end
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
  local tables, rows = {}, {}
  for l = 1, #c.leagues do
    tables[l], rows[l] = {}, league_rows(c, l)
    for i, r in ipairs(rows[l]) do tables[l][i] = r.team end
  end
  local playoff, direct
  if cfg.entrants > 0 then
    playoff, direct = Season.frontier_draw(tables, cfg, rows), {}
  else
    playoff, direct = Season.frontier_entry(tables, cfg, rows)
  end
  local size = #direct + #playoff
  if not Competition.is_power_of_two(size) then
    warn(string.format("Fútbol Frontier: %d direct clubs + %d play-off winners is not a power of two", #direct, #playoff))
  end
  c.ff = { rounds = { {} }, results = {}, round = 1, labels = { cfg.entrants > 0 and frontier_label(#playoff, false) or "Playoff" },
    direct = {}, seed = {}, league = {} }
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
  local last_place = cfg.entrants > 0 and floor(cfg.entrants / math.max(1, #tables)) + 1 or cfg.playoff_places[2]
  for p = 1, last_place do
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
    c.reached = c.ff.labels[1]
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
local LAST_RESULTS = nil   -- the last round's results (the levels read them; never saved)
local function play_round_core(c, result)
  if c.phase == "worldcup" then return worldcup_round(c, result) end
  local list, _, round, knockout = fixtures(c)
  local ratings, median = ratings_of(c)
  local sim = sim_config(median)
  local rng = rng_for(c, c.phase, round)
  local results, mine_result = {}, nil
  LAST_RESULTS = results
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

-- the news' helpers from the career (lib/news.lua)
local NEWS_ENV = nil
local news_env      -- (defined after the market's)
local home_table    -- (defined with the hub views)

-- a side's strongest outfield player (the news picture): the club's squad, the World Cup side's call-up
local function best_card(c, team)
  local cards = squad_cards(c, team)
  local w = worldcup_of(c)
  if #cards == 0 and w and w.side == team then cards = w.squad or {} end
  local best, strength = 0, nil
  local by_level = Levels.ready(c)
  for _, card in ipairs(cards) do
    local x = card_info(card)
    local v = x.strength
    if by_level then
      local p = Levels.player(levels_env(), c, card)
      v = p and p.level or 0
    end
    if x.position ~= 1 and (strength == nil or v > strength) then best, strength = card, v end
  end
  return best ~= 0 and best or (cards[1] or 0)
end

-- the transfer market's helpers from the career (lib/market.lua)
local MARKET_ENV = nil
-- the market's news kinds -> their producers (lib/news.lua; any other kind: a closed deal)
local MARKET_NEWS = { offer = News.offer, loan_offer = News.loan_offer, loan = News.loan, loan_back = News.loan_back,
  bid_reply = News.bid_reply }
local function market_env()
  if MARKET_ENV == nil then
    MARKET_ENV = { config = config, num = num, int = int, u32 = u32, card_info = card_info, squad_of = squad_of,
      today_of = now_of, can_sell = function(t) return CareerMode.CanSell(t) end, options = options_of,
      now_ms = VRFW.time.unix_ms,
      free_pool = function(taken)
        clubs()
        return Squads.free_pool(taken, squads_config())
      end,
      level_of = function(c, card) return Levels.player(levels_env(), c, card) end,
      value_of = function(c, card, p) return Levels.value(levels_env(), c, card, p) end,
      -- the day a loan of that length ("window": the close of the next transfer window, "season": the season's end)
      -- is over
      loan_back = function(c, length)
        local plan = plan_of(c)
        if length == "window" then
          local w = window_state(c, now_of(c))
          local _, to = Calendar.next_window(plan, w.open and w.to or now_of(c))
          if to then return to end
        end
        return plan.finish or plan.last
      end,
      news = function(c, kind, d)
        local producer = MARKET_NEWS[kind] or News.transfer
        local ok, err = pcall(producer, news_env(), c, d)
        if not ok then warn("news (" .. tostring(kind) .. "): " .. tostring(err)) end
      end }
  end
  return MARKET_ENV
end

-- the season's state the news compare round to round (lib/news.lua N.observe)
local function news_watch(c)
  local w = worldcup_of(c)
  local t = (c.phase == "superliga" or c.phase == "league") and home_table(c) or nil
  local place, points = 0, 0
  local rows = t and t.rows or {}
  for k, r in ipairs(rows) do
    if r.team == c.team then place, points = k, r.points or 0 end
  end
  local today = today_of(c)
  local win = window_state(c, today)
  local played = rows[1] and (rows[1].played or 0) > 0
  return { season = c.season, phase = c.phase, table = t and (t.kind .. ":" .. tostring(t.league or 0)) or "",
    place = place, points = points, cut = t and t.cut or 0,
    leader = played and rows[1].team or 0, leader_points = played and rows[1].points or 0,
    out = c.out == true, out_reason = c.out_reason or "", reached = c.reached or "", champion = c.champion or 0,
    window = win.open == true, window_to = win.open and win.to or nil, window_next = (not win.open) and win.from or nil,
    wc_stage = w and w.stage or "", wc_out = w and w.out == true or false, wc_side = w and w.side or 0,
    wc_champion = w and w.champion or 0, wc_round = w and w.ko and w.ko.round or 0 }
end

news_env = function()
  if NEWS_ENV == nil then
    NEWS_ENV = { config = config, int = int, today_of = now_of, best_card = best_card, watch = news_watch,
      me = me_of,
      -- the player's side's match of the round being played: { home, away, day } or nil
      next_match = function(c)
        if c.phase == "over" or c.phase == "pots" or (c.phase == "worldcup" and c.wc and c.wc.stage == "call") then return nil end
        local list = fixtures(c)
        local m = mine(list or {}, me_of(c))
        if not m then return nil end
        return { home = m[1], away = m[2], day = next_day_of(c) }
      end,
      -- the best rated club of the career
      top_club = function(c)
        local best, rating = nil, nil
        for i, t in ipairs(c.clubs or {}) do
          local r = tonumber(c.ratings and c.ratings[i]) or 0
          if rating == nil or r > rating then best, rating = t, r end
        end
        return best
      end,
      date_view = function(day) return day and Calendar.view(day) or nil end,
      card_names = function(cards, lang) return GameText.card_names(cards, GameText.language(lang), true) end,
      team_names = function(ids, lang)
        local by_text, texts = {}, {}
        for _, team in ipairs(ids) do
          local t = team_by_id(team)
          if t and (t.name_text or 0) ~= 0 then by_text[team] = t.name_text texts[#texts + 1] = t.name_text end
        end
        local names = GameText.team_names(texts, GameText.language(lang))
        local out = {}
        for team, id in pairs(by_text) do out[team] = names[id] or "" end
        return out
      end,
      text_column = function(lang) return GameText.language(lang) end }
  end
  return NEWS_ENV
end

-- the board's news: a warning ({ stage, target, now }) or the sacking (the verdict)
board_news = function(c, kind, d)
  local body
  if kind == "warning" then
    body = { d.stage == "superliga" and "NewsTextBoardSuperLiga" or "NewsTextBoardLeague", { { "n", d.target }, { "n", d.now } } }
  else
    body = { "NewsTextSacked", { { "t", c.team } } }
  end
  News.push(news_env(), c, { kind = "club", tag = "NewsTagBoard",
    head = { kind == "warning" and "NewsHeadBoardWarning" or "NewsHeadSacked", { { "t", c.team } } }, body = body,
    card = best_card(c, c.team), team = c.team, from = 0, amount = 0, role = "let_down" })
end

-- the clubs' ratings from their players' career levels (config [ratings] source = "levels")
local function rate_by_levels(c)
  if not (rated_by_levels() and Levels.ready(c)) then return end
  local count = int("ratings.count", 11)
  for i, t in ipairs(c.clubs) do
    local r = Levels.club_rating(levels_env(), c, squad_cards(c, t), count)
    if r then c.ratings[i] = floor(r * 10 + 0.5) / 10 end
  end
end

-- a loaded career: its levels (built once for a career started before them, then saved) and the clubs rated from them
levels_ready = function(c)
  if not Levels.ready(c) then
    local ok, err = pcall(Levels.build, levels_env(), c, squads_by_index(c.squads))
    if not ok then
      warn("career levels not built: " .. tostring(err))
      return
    end
    rate_by_levels(c)
    save()
    return
  end
  rate_by_levels(c)
end

-- the facts of the club's match being played (config [levels.form]): { [team] = { [card] = { minutes, goals, saves,
-- techniques, duels, red, pos } } }, made when the match is armed (the starters 90 minutes), kept until its result
local MATCH = nil

local function match_minute(ev)
  local m = ev and ev.match or {}
  local okp, p = pcall(VRFW.match.period)
  local length = okp and type(p) == "table" and tonumber(p.length) or 0
  local half, clock = tonumber(m.half) or 1, tonumber(m.clock) or 0
  if length <= 0 then return 45 end
  return math.max(0, math.min(90, ((half - 1) * length + clock) / (2 * length) * 90))
end

local function match_fact(ev)
  local a = MATCH and ev and ev.actor
  if not a or not a.card then return nil end
  local team = a.side == "user" and MATCH.user or a.side == "rival" and MATCH.rival or nil
  local side = team and MATCH.facts[team]
  if not side then return nil end
  local card = u32(a.card)
  local x = side[card]
  if x == nil then
    -- a bench player on the pitch: his minutes from now
    x = { minutes = math.max(1, 90 - floor(match_minute(ev))), goals = 0, saves = 0, techniques = 0, duels = 0, red = 0 }
    side[card] = x
  end
  return x
end

VRFW.on("goal", function(ev)
  local x = match_fact(ev)
  if x and ev.actor and ev.arg == ev.actor.side then x.goals = x.goals + 1 end
  return nil
end)
VRFW.on("keeper_save", function(ev)
  local x = match_fact(ev)
  if x then x.saves = x.saves + 1 end
  return nil
end)
VRFW.on("technique_result", function(ev)
  local x = match_fact(ev)
  if x then x.techniques = x.techniques + 1 end
  return nil
end)
VRFW.on("duel_won", function(ev)
  local x = match_fact(ev)
  if x then x.duels = x.duels + 1 end
  return nil
end)
VRFW.on("foul:red", function(ev)
  local x = match_fact(ev)
  if x then x.red = x.red + 1 end
  return nil
end)
VRFW.on("possession", function(ev)
  match_fact(ev)
  return nil
end)

-- the club's match armed: its two sides' players, the first `starters` of each 90 minutes
local function match_armed(user, rival, user_cards, rival_cards)
  local starters = int("levels.form.starters", 11)
  MATCH = { user = user, rival = rival, facts = { [user] = {}, [rival] = {} } }
  for team, cards in pairs({ [user] = user_cards, [rival] = rival_cards }) do
    for i, card in ipairs(cards) do
      if i <= starters then
        MATCH.facts[team][u32(card)] = { minutes = 90, goals = 0, saves = 0, techniques = 0, duels = 0, red = 0 }
      end
    end
  end
end

-- a month of the calendar ends between two days: the players' progression, once per month crossed
local function months_between(a, b)
  if not a or not b then return 0 end
  local y1, m1 = Calendar.civil(a)
  local y2, m2 = Calendar.civil(b)
  return math.max(0, (y2 * 12 + m2) - (y1 * 12 + m1))
end

-- ------------------------------------------------------------------------------------------------ player stats

-- the season's player stats per competition, from the players' match facts of each round (Levels.after_round):
-- c.stats = { season, rev, comp = { [key] = { [card hex] = { team, matches, goals, saves, clean sheets, score x 10
-- summed, mvp } } } }; key = "superliga", "league<l>", "frontier". Saves come from the matches the player plays (the
-- simulated ones give goals and scores); a clean sheet = a goalkeeper on the pitch at least config [stats]
-- clean_sheet_minutes in a match his club conceded none; the match's MVP = its best score
local STAT = { TEAM = 1, MATCHES = 2, GOALS = 3, SAVES = 4, CLEAN = 5, SCORE = 6, MVP = 7 }

local function stats_key(phase, team, leagues)
  if phase == "superliga" then return "superliga" end
  if phase == "frontier" then return "frontier" end
  if phase == "league" then
    local l = leagues[team]
    return l and ("league" .. l) or nil
  end
  return nil
end

local function stats_after_round(c, phase, facts)
  if type(facts) ~= "table" or #facts == 0 then return end
  if type(c.stats) ~= "table" or c.stats.season ~= c.season then c.stats = { season = c.season, rev = 0, comp = {} } end
  local clean_minutes = int("stats.clean_sheet_minutes", 60)
  local leagues = {}
  for l, lg in ipairs(c.leagues or {}) do
    for _, t in ipairs(lg) do leagues[t] = l end
  end
  local best = {}
  for _, f in ipairs(facts) do
    local b = best[f.match]
    if b == nil or f.score > b.score or (f.score == b.score and f.card < b.card) then best[f.match] = f end
  end
  for _, f in ipairs(facts) do
    local key = stats_key(phase, f.team, leagues)
    if key then
      local comp = c.stats.comp[key] or {}
      c.stats.comp[key] = comp
      local id = string.format("%08X", u32(f.card))
      local s = comp[id] or { f.team, 0, 0, 0, 0, 0, 0 }
      comp[id] = s
      s[STAT.TEAM] = f.team
      s[STAT.MATCHES] = s[STAT.MATCHES] + 1
      s[STAT.GOALS] = s[STAT.GOALS] + (f.goals or 0)
      s[STAT.SAVES] = s[STAT.SAVES] + (f.saves or 0)
      if f.pos == 1 and (f.conceded or 0) == 0 and (f.minutes or 0) >= clean_minutes then s[STAT.CLEAN] = s[STAT.CLEAN] + 1 end
      s[STAT.SCORE] = s[STAT.SCORE] + floor((f.score or 0) * 10 + 0.5)
      if best[f.match] == f then s[STAT.MVP] = s[STAT.MVP] + 1 end
    end
  end
  c.stats.rev = (c.stats.rev or 0) + 1
end

-- the stats' sorted lists, kept until the next round (one list per career, revision, competition and order)
local STATS_LISTS = { stamp = nil }
local STATS_SORTS = {
  goals = { STAT.GOALS, STAT.MVP },
  rating = { "rating", STAT.MATCHES },
  saves = { STAT.SAVES, STAT.CLEAN },
  clean = { STAT.CLEAN, STAT.SAVES },
  mvp = { STAT.MVP, "rating" },
}

-- a match score (x 10, summed) as the stats' rating: config [stats] rating_base + mean score x rating_scale, 0..10
local function stats_rating(s)
  if (s[STAT.MATCHES] or 0) == 0 then return 0 end
  local mean = s[STAT.SCORE] / 10 / s[STAT.MATCHES]
  local r = num("stats.rating_base", 6) + mean * num("stats.rating_scale", 2)
  return floor(math.max(0, math.min(10, r)) * 10 + 0.5) / 10
end

local function levels_after_round(c, phase, before, played)
  if phase == "worldcup" or not Levels.ready(c) then return end
  local owner = {}
  for i, t in ipairs(c.clubs) do
    for _, p in ipairs(c.squads[i] and c.squads[i].players or {}) do owner[u32(p.card)] = t end
  end
  local ok, facts = pcall(Levels.after_round, levels_env(), c, LAST_RESULTS,
    function(team) return squad_cards(c, team) end, played, VRFW.rng("CareerMode.levels.round", { c.seed, c.season, before or 0 }))
  if not ok then warn("levels round failed: " .. tostring(facts))
  else
    local oks, errs = pcall(stats_after_round, c, phase, facts)
    if not oks then warn("stats round failed: " .. tostring(errs)) end
  end
  local after = today_of(c)
  for _ = 1, months_between(before, after) do
    local okm, n = pcall(Levels.month_end, levels_env(), c, function(card) return owner[card] or 0 end, after)
    if not okm then warn("levels month failed: " .. tostring(n))
    elseif n > 0 then pcall(VRFW.signal, "CareerMode.LevelChanged") end
  end
  rate_by_levels(c)
end

-- the news' player of the matchday: a side's players' last scores before the round's levels ...
local function news_scores(c, team)
  if not Levels.ready(c) then return nil end
  local out = {}
  for _, card in ipairs(squad_cards(c, team)) do
    local rec = c.levels.p[string.format("%08X", u32(card))]
    out[card] = rec and table.concat(rec.s or {}, ",") or ""
  end
  return out
end

-- ... and after them: the player who played this round with the best score ({ card, score } or nil)
local function news_star(c, team, before)
  if not before then return nil end
  local best
  for card, b in pairs(before) do
    local rec = c.levels.p[string.format("%08X", u32(card))]
    local s = rec and rec.s or {}
    if rec and #s > 0 and table.concat(s, ",") ~= b then   -- a score was added this round: he played
      local score = s[#s]
      if best == nil or score > best.score or (score == best.score and card < best.card) then best = { card = card, score = score } end
    end
  end
  return best
end

-- a round played: the clubs' income, and inside a transfer window the AI clubs' deals and bids (seeded per day)
-- one market day of stretch s (its share of the round: income, AI deals, bids), or a whole round's tick (s = nil)
market_day = function(c, s)
  local z = now_of(c)
  local part = s and { share = 1 / (s.to - s.from), k = s.done, n = s.to - s.from } or nil
  local ok, err = pcall(Market.after_round, market_env(), c, window_state(c, z).open,
    VRFW.rng("CareerMode.market", { c.seed, c.season, z }), part)
  if not ok then warn("market day failed: " .. tostring(err)) end
end

local function play_round(c, result, played)
  local phase = c.phase
  local before = today_of(c)
  if phase ~= "worldcup" and options_of(c).market then
    local s = stretch_of(c)
    if s then
      -- the days not walked yet (at most the stretch's length)
      while s.done < s.to - s.from do
        s.done = s.done + 1
        market_day(c, s)
      end
    else
      market_day(c, nil)
    end
  end
  local r = play_round_core(c, result)
  local side = phase == "worldcup" and c.wc and c.wc.side or c.team
  local minutes = r and news_scores(c, side) or nil
  levels_after_round(c, phase, before, played)
  local okn, errn = pcall(function()
    if r then News.matchday(news_env(), c, r, side, news_star(c, side, minutes)) end
    News.observe(news_env(), c)
    local place, _, lplace = club_places(c)
    local warning = Board.warning(BOARD_ENV, c, place, lplace)
    if warning then board_news(c, "warning", warning) end
  end)
  if not okn then warn("news round failed: " .. tostring(errn)) end
  return r
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
  -- the loans still running end with the season
  if type(c.market) == "table" then
    local ok, err = pcall(Market.loans_back, market_env(), c, true)
    if not ok then warn("loans not returned: " .. tostring(err)) end
  end
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
  local ok, err = pcall(Board.start, BOARD_ENV, c, board_rank(c))
  if not ok then warn("board objectives not set: " .. tostring(err)) end
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
-- then the country of its pool teams (config pool_teams), then the players content\career\nationalities.toml adds or moves (config [world_cup] nationality_file) ->
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
  local path = tostring(config("world_cup.nationality_file", "content/career/nationalities.toml"))
  local ok, doc = pcall(VRFW.files.toml, path)
  local added = 0
  if ok then
    for _, entry in ipairs(career_entries(doc, "Nationality")) do
      local id = type(entry) == "table" and entry.country or nil
      local list = id ~= nil and entry.players or nil
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
  LAST_RESULTS = results
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
  local out = { ok = list ~= nil, why = why or "", clubs = list and #list or 0, nations = NATIONS and #NATIONS or 0,
    career_slot = active_career(), careers = career_count() }
  if c then
    out.career = { team = c.team, season = c.season, phase = c.phase, out = c.out == true, fresh = c.fresh == true }
    if c.fresh then
      c.fresh = nil
      save()
    end
  end
  return out
end

-- emblem id (item_emblem, crc32 of its key) -> { ok, key }: the crest's texture key (em010001: the 512 px file
-- menu/200_icon/01_icon_emblem/<key>.g4tx, texture <key>), from the served emblem table, read once
function CareerMode.EmblemKey(id)
  if CareerMode.emblem_keys == nil then
    local keys, n = {}, 0
    local ok, rows = pcall(VRFW.table.rows, "item/item_emblem")
    for _, r in ipairs(ok and type(rows) == "table" and rows or {}) do
      if type(r.key) == "string" and r.key ~= "" then
        keys[u32(r.id)] = r.key
        n = n + 1
      end
    end
    if not ok then warn("emblem keys not readable: " .. tostring(rows)) end
    info(string.format("emblem keys: %d", n))
    CareerMode.emblem_keys = keys
  end
  if CareerMode.emblem_colours == nil then
    -- each emblem's colour bucket (generated by research/scripts/career_emblem_colours.py from the emblems)
    local ok, doc = pcall(VRFW.files.toml, "content/career/emblem_colours.toml")
    CareerMode.emblem_colours = ok and type(doc) == "table" and type(doc.colours) == "table" and doc.colours or {}
    if not ok then warn("emblem colours not readable: " .. tostring(doc)) end
  end
  local key = CareerMode.emblem_keys[u32(tonumber(id) or 0)]
  return { ok = key ~= nil, key = key or "", colour = key and CareerMode.emblem_colours[key] or "" }
end

-- the club pick: every club that enters a career, grouped by its game -> { ok, why, leagues = { { team ids } },
-- groups = { game }, clubs, rounds, rating }; the clubs of config [teams] pick_exclude (team keys) are left out of
-- the pick only (they play in the career as any other club)
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
    if rated_by_levels() then
      local probe = { seed = seed }
      local ok, err = pcall(Levels.build, levels_env(), probe, built.squads)
      if ok then
        PENDING.levels = probe.levels
        local count = int("ratings.count", 11)
        for _, t in ipairs(list) do
          local sq = built.squads[t.id]
          local cards = {}
          for _, p in ipairs(sq and sq.players or {}) do cards[#cards + 1] = u32(p.card) end
          local r = #cards > 0 and Levels.club_rating(levels_env(), probe, cards, count) or nil
          if r then t.rating = floor(r * 10 + 0.5) / 10 end
        end
      else
        warn("club pick levels not built: " .. tostring(err))
      end
    end
    -- the clubs rated again from their career squads (used when no rating source rates them)
    local cards_of = {}
    for id, sq in pairs(built.squads) do
      local cards = {}
      for _, p in ipairs(sq.players or {}) do cards[#cards + 1] = p.card end
      cards_of[id] = cards
    end
    if not PENDING.levels then Teams.rate(list, cards_of) end
  end
  local by = club_by_id()
  local rated = {}
  for i, t in ipairs(PENDING.built.clubs) do rated[i] = { t, by[t] and by[t].rating or 0 } end
  local games = games_of(list)
  local out_keys, excluded = {}, {}
  for _, k in ipairs(config("teams.pick_exclude", {}) or {}) do out_keys[tostring(k)] = true end
  for _, t in ipairs(list) do
    if out_keys[t.key] then excluded[t.id] = true end
  end
  local by_game, keys = {}, {}
  for _, t in ipairs(PENDING.built.clubs) do
    local g = games[t] or 99
    if not excluded[t] then
      if by_game[g] == nil then
        by_game[g] = {}
        keys[#keys + 1] = g
      end
      by_game[g][#by_game[g] + 1] = t
    end
  end
  table.sort(keys)
  local leagues = {}
  for i, g in ipairs(keys) do leagues[i] = by_game[g] end
  return { ok = true, leagues = leagues, groups = keys, clubs = #PENDING.built.clubs, rounds = season_config().rounds,
    rating = rating_rules(rated) }
end

-- team -> { ok, why }: a new career with that club (the slot's old career put aside first)
-- the setup screen's picks as kept in the career (indexes 1-based; nil = the default)
local function start_options(market, backing, negotiation, activity, sacking)
  local function pick(v, name)
    local d = config("setup." .. name, nil)
    if v == nil then return d end
    return tonumber(v) == 1
  end
  local steps = backing_steps()
  local b = tonumber(backing) and math.floor(tonumber(backing)) or int("setup.backing_default", 1)
  local neg, act = setup_list("negotiation"), setup_list("activity")
  local n = neg[tonumber(negotiation) or int("setup.negotiation_default", 2)] or setup_pick(neg, nil, 2)
  local a = act[tonumber(activity) or int("setup.activity_default", 3)] or setup_pick(act, nil, 3)
  local o = {
    market = pick(market, "market_default") ~= false,
    backing = steps[math.max(1, math.min(#steps, b))] or 0,
    negotiation = n.id, activity = a.id,
    sacking = pick(sacking, "sacking_default") == true,
  }
  if not o.market then o.backing, o.negotiation, o.activity = 0, nil, nil end
  return o
end

-- (club, lang) -> the setup screen of a new career for that club: { ok, team, budget (its first budget before any
-- backing), rank, clubs, market, backing = { steps, default }, negotiation / activity = { presets = { { id, text, ask,
-- bid, deals } }, default }, sacking }
function CareerMode.Setup(team)
  team = u32(team)
  if not PENDING then return { ok = false, why = "no club pick" } end
  local built = PENDING.built
  if built.squads[team] == nil then return { ok = false, why = "the club is not in the career" } end
  local by = club_by_id()
  local probe = { team = team, clubs = {}, ratings = {} }
  local order = {}
  for i, t in ipairs(built.clubs) do
    probe.clubs[i], probe.ratings[i] = t, by[t] and by[t].rating or 0
    order[i] = { t = t, r = probe.ratings[i] }
  end
  table.sort(order, function(a, b) return a.r > b.r end)
  local rank = 0
  for k, x in ipairs(order) do
    if x.t == team then rank = k end
  end
  local env = market_env()
  local ok, m = pcall(Market.state, env, probe, Market.config(env))
  local function presets(name)
    local out = {}
    for i, r in ipairs(setup_list(name)) do
      out[i] = { id = r.id, text = tostring(r.text or ""), ask = tonumber(r.ask) or 1, bid = tonumber(r.bid) or 1,
        deals = tonumber(r.deals) or 0 }
    end
    return out
  end
  return {
    ok = true, team = team, budget = ok and Market.money(m, team) or 0, rank = rank, clubs = #built.clubs,
    market = config("setup.market_default", true) ~= false,
    backing = { steps = backing_steps(), default = int("setup.backing_default", 1), jump = int("setup.backing_jump", 3) },
    negotiation = { presets = presets("negotiation"), default = int("setup.negotiation_default", 2) },
    activity = { presets = presets("activity"), default = int("setup.activity_default", 3) },
    sacking = config("setup.sacking_default", true) == true,
    objectives = Board.view(Board.targets(BOARD_ENV, rank, #built.clubs) or false, {}),
  }
end

-- (club, market 0 / 1, backing step, negotiation, activity (1-based preset indexes), sacking 0 / 1): the career started
-- with the setup screen's options (config [setup]); options missing = the defaults
function CareerMode.Start(team, market, backing, negotiation, activity, sacking)
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
    squad_cap = int("squads.max_players", 21), options = start_options(market, backing, negotiation, activity, sacking),
    nations = nations, double = season_config().double, history = {} }
  if PENDING.levels then
    CAREER.levels = PENDING.levels
  else
    local okl, errl = pcall(Levels.build, levels_env(), CAREER, squads_by_index(squads))
    if not okl then warn("career levels not built: " .. tostring(errl)) end
  end
  rate_by_levels(CAREER)
  season_start(CAREER)
  CAREER_SLOT = career_key()
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
function CareerMode.Abandon(k)
  local n = current_slot()
  k = tonumber(k) or active_career()
  if k < 1 or k > career_count() then return { ok = false, why = "no such career" } end
  local ok, where = pcall(VRFW.save.blob_aside, blob_of(k), n)
  info(blob_of(k) .. " (slot " .. n .. ") put aside: " .. tostring(ok and where or "failed"))
  pcall(VRFW.save.del, "career_summary_" .. k)
  pcall(VRFW.save.commit)
  if k == active_career() then CAREER, CAREER_SLOT = nil, career_key() end
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
    local lv = CAREER and Levels.player(levels_env(), CAREER, p.card)
    if lv then out[i].level, out[i].form, out[i].potential, out[i].effective = lv.level, lv.form, lv.potential, lv.effective end
  end
  return out
end

-- forms = team -> its last results (club_forms), nil = none
local function rows_view(rows, forms)
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = { team = r.team, played = r.played, won = r.won, drawn = r.drawn, lost = r.lost,
      goals_for = r.goals_for, goals_against = r.goals_against, points = r.points, form = forms and forms[r.team] or nil }
  end
  return out
end

-- the pot colours' count (config.toml [pots] colours)
local function pot_colours()
  local v = config("pots.colours", nil)
  return type(v) == "table" and #v or 0
end

-- the SuperLiga rows with the pot each place goes to in the draw (Season.pot_of) and that pot's swatch
local function superliga_pots(out)
  local cfg = season_config()
  local qualified = math.min(cfg.qualify, floor(#out / cfg.leagues) * cfg.leagues)
  local colours = pot_colours()
  for i, r in ipairs(out) do
    r.pot = Season.pot_of(i, cfg.leagues, qualified)
    r.pot_tint = Season.pot_tint(r.pot, colours)
  end
  return out
end

-- every club's last `keep` results ("W" / "D" / "L", oldest first) over `count` rounds of results (round k =
-- results(k): { { home, away, home goals, away goals, shoot-out winner } }); a draw decided on penalties counts for
-- the shoot-out's winner
local function club_forms(count, results, keep)
  local out = {}
  for k = 1, count do
    for _, r in ipairs(results(k) or {}) do
      for side = 1, 2 do
        local team = r[side]
        local gf, ga = r[side + 2], r[5 - side]
        local res
        if gf == ga and (r[5] or 0) ~= 0 then
          res = r[5] == team and "W" or "L"
        else
          res = gf > ga and "W" or (gf < ga and "L" or "D")
        end
        local f = out[team] or {}
        f[#f + 1] = res
        if #f > keep then table.remove(f, 1) end
        out[team] = f
      end
    end
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
    local results = c.lg.results[e.league] or {}
    local forms = club_forms(c.lg.matchdays or 0, function(k) return results[k] end, int("hub.form_matches", 5))
    local cfg = season_config()
    local direct, cut = cfg.direct_places, cfg.playoff_places[2]
    if cfg.entrants > 0 then
      -- places 1..direct go to the Frontier; place cut = direct + 1 goes when it is among the best of that place
      direct = floor(cfg.entrants / math.max(1, #c.leagues))
      cut = direct * #c.leagues < cfg.entrants and direct + 1 or direct
    end
    return { kind = "league", league = e.league, rows = rows_view(league_rows(c, e.league), forms),
      cut = cut, direct = direct, entrants = cfg.entrants }
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
  local forms = club_forms(#c.sl.results, function(k) return c.sl.results[k] end, int("hub.form_matches", 5))
  return { kind = "superliga", title = "SuperLiga", rows = superliga_pots(rows_view(superliga_rows(c), forms)), cut = #c.qualified > 0 and
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
home_table = function(c)
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
-- the stretch to the next match for «Próximo partido»: { from, to, now (dates), match_day, days (every date of it),
-- events = { { day, kind } } }
-- (kind window_open / window_close / draw / offer: the transfer windows' first and last days, the draw, the offers the
-- club received), false when there is none
function CareerMode.StretchView(c)
  local s = stretch_of(c)
  if not s then return false end
  local plan = plan_of(c)
  local events = {}
  local function add(z, kind)
    if z and z > s.from and z <= s.to then events[#events + 1] = { day = Calendar.view(z), kind = kind } end
  end
  for _, r in ipairs(plan.windows or {}) do
    add(r[1], "window_open")
    add(r[2], "window_close")
  end
  add(plan.draw, "draw")
  if options_of(c).market then
    local env = market_env()
    local ok, m = pcall(Market.state, env, c, Market.config(env, c))
    for _, o in ipairs(ok and m.offers or {}) do add(tonumber(o.day), "offer") end
  end
  local days = {}
  for z = s.from, s.to do days[#days + 1] = Calendar.view(z) end
  local now = now_of(c)
  return { from = Calendar.view(s.from), to = Calendar.view(s.to), now = Calendar.view(now), match_day = now >= s.to,
    days = days, events = events }
end

-- the season's phases for «Fechas»' season line, by first day: { key = superliga / league / frontier / worldcup /
-- window, from, to } (the laid-out match days of each phase, the World Cup's days, each transfer window)
local function phase_spans(plan)
  local out = {}
  for _, key in ipairs({ "superliga", "league", "frontier" }) do
    local list = plan[key] or {}
    if #list > 0 then out[#out + 1] = { key = key, a = list[1], b = list[#list] } end
  end
  if plan.world_cup then out[#out + 1] = { key = "worldcup", a = plan.world_cup[1], b = plan.world_cup[2] } end
  for _, r in ipairs(plan.windows or {}) do out[#out + 1] = { key = "window", a = r[1], b = r[2] } end
  table.sort(out, function(p, q) if p.a ~= q.a then return p.a < q.a end return p.key < q.key end)
  for i, p in ipairs(out) do out[i] = { key = p.key, from = Calendar.view(p.a), to = Calendar.view(p.b) } end
  return out
end

local function days_view(c)
  local plan = plan_of(c)
  local today, nxt = now_of(c), next_day_of(c)
  local function spans(list)
    local out = {}
    for i, r in ipairs(list or {}) do out[i] = { from = Calendar.view(r[1]), to = Calendar.view(r[2]) } end
    return out
  end
  local w = window_state(c, today)
  return {
    year = plan.year, today = Calendar.view(today), next = Calendar.view(nxt), draw = Calendar.view(plan.draw),
    start = Calendar.view(plan.start), finish = Calendar.view(plan.finish), months = Calendar.months(plan),
    breaks = spans(plan.breaks), windows = spans(plan.windows), phases = phase_spans(plan),
    world_cup = plan.world_cup and spans({ plan.world_cup })[1] or false,
    world_cup_days = worldcup_of(c) and #worldcup_of(c).dates or 0,
    window = { open = w.open, from = Calendar.view(w.from) or false, to = Calendar.view(w.to) or false },
    stretch = CareerMode.StretchView(c),
    colours = type(config("calendar.competition_colours", nil)) == "table" and config("calendar.competition_colours", nil)
      or {},
  }
end

-- the club's budget on the market (lib/market.lua; the clubs' budgets are set on first use), false when unknown
local function club_money(c)
  local env = market_env()
  if not options_of(c).market then return false end
  local ok, m = pcall(Market.state, env, c, Market.config(env, c))
  if not ok or type(m) ~= "table" then return false end
  return Market.money(m, c.team)
end

-- a career's summary for the title menu: club, season, phase and its round, the place and points in the table of
-- «Inicio», the budget, the career's date
summarize = function(c)
  local _, label, n = fixtures(c)
  local t = home_table(c)
  local place, points = 0, 0
  for k, r in ipairs(t.rows or {}) do
    if r.team == c.team then place, points = k, r.points or 0 end
  end
  local money = club_money(c)
  return { team = c.team, season = c.season, phase = c.phase, label = label or "", n = n or 0, table = t.kind or "",
    league = t.league or 0, place = place, points = points, money = type(money) == "number" and money or false,
    date = Calendar.view(now_of(c)) or false }
end

-- the season's state the board's objectives are read against
function board_now(c)
  local place, _, lplace = club_places(c)
  return { place = place, lplace = lplace, reached = c.reached or "", phase = c.phase, out = c.out == true }
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
  elseif c.phase == "sacked" then
    nxt = { kind = "sacked" }
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
  local rated = {}
  for i, t in ipairs(c.clubs) do rated[#rated + 1] = { t, tonumber(c.ratings[i]) or 0 } end
  for _, p in ipairs(w and w.ratings or {}) do rated[#rated + 1] = p end
  local count = #competitions(c)
  local shown = default_competition(c)
  return {
    ok = true, team = c.team, season = c.season, phase = c.phase, out = c.out == true, out_reason = c.out_reason or "",
    reached = c.reached or "", champion = c.champion or 0, next = nxt, calendar = calendar(c),
    table = home_table(c), competition = table_view(c, shown), table_index = shown, tables = count,
    competition_list = competitions(c),
    league = league_of(c, c.team) or 0, superliga_place = c.sl.place or 0, squad = players_view(sq and sq.players or {}, lang),
    callup = #(sq and sq.players or {}) > match_size(), lineup = lineup_view(c),
    rows_per_page = int("hub.rows_per_page", 10), table_rows = int("hub.table_rows", 18), form = f, form_matches = keep,
    day_step_frames = int("hub.day_step_frames", 24),
    tabs = hub_tabs(c.phase, #(sq and sq.players or {}) > match_size(), options_of(c).market), rating = rating_rules(rated),
    history = c.history, me = me, worldcup = w and { side = w.side, stage = w.stage, champion = w.champion or 0,
      out = w.out == true, group = worldcup_group_of(w, w.side) or 0, groups = #w.groups, advance = w.format.advance,
      sides = #w.entrants, squad = #w.squad, knockout = w.format.knockout,
      qualified = w.format.qualified or (#w.groups * w.format.advance) } or false,
    clubs = #c.clubs, qualify = season_config().qualify, rounds = season_config().rounds, days = days_view(c),
    money = club_money(c),
    board = c.board and c.board.season == c.season and Board.view(c.board, board_now(c)) or false,
    sacked = c.sacked or false,
    currency = { item = tostring(config("market.currency_item", "")), atlas = tostring(config("market.currency_atlas", "")) },
    saved_at = c.saved_at or false, game_slot = current_slot(), career_slot = active_career(),
    club_tags = club_tags(c), club_names = club_names(c, lang),
    autosave = c.autosave ~= false,
  }
end

-- -> { ok, why, at }: the active career written to its file now (its save slot's CareerMode folder)
function CareerMode.Save()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  if not save(true) then return { ok = false, why = "the career file was not written" } end
  info(string.format("career %d of slot %d saved on request", active_career(), current_slot()))
  return { ok = true, at = c.saved_at or "" }
end

-- (on) -> { ok, why, autosave, at }: the active career's autosave on / off (kept in its file, written now); off = the
-- career is written only by CMND_CAREERMODE_SAVE
function CareerMode.AutoSave(on)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  c.autosave = (on == true or on == 1) and nil or false
  if not save(true) then return { ok = false, why = "the career file was not written" } end
  info(string.format("career %d of slot %d: autosave %s", active_career(), current_slot(),
    c.autosave == false and "off" or "on"))
  return { ok = true, autosave = c.autosave ~= false, at = c.saved_at or "" }
end

-- -> { ok, slots = { { career, used, summary } }, active, count, game_slot, currency }: the save slot's careers for
-- the title menu (config [careers] slots); a career without its summary yet (an earlier version's) is read once
function CareerMode.Slots()
  local n, count = current_slot(), career_count()
  local out = {}
  for k = 1, count do
    local ok, sum = pcall(VRFW.save.get, "career_summary_" .. k)
    if not (ok and type(sum) == "table") then
      sum = nil
      local doc = read_career(n, k)
      if doc then
        write_summary(k, doc)
        ok, sum = pcall(VRFW.save.get, "career_summary_" .. k)
        if not (ok and type(sum) == "table") then sum = { team = doc.team, season = doc.season, phase = doc.phase } end
      end
    end
    out[k] = { career = k, used = sum ~= nil, summary = sum or false }
  end
  return { ok = true, slots = out, active = active_career(), count = count, game_slot = n,
    currency = { item = tostring(config("market.currency_item", "")),
      atlas = tostring(config("market.currency_atlas", "")) } }
end

-- (k) -> { ok, why, career }: career k of the save slot becomes the active one (career = it holds a career)
function CareerMode.Use(k)
  k = floor(tonumber(k) or 0)
  if k < 1 or k > career_count() then return { ok = false, why = "no such career" } end
  pcall(VRFW.save.set, "career_slot", k)
  pcall(VRFW.save.commit)
  CAREER, CAREER_SLOT = nil, nil
  return { ok = true, career = load() ~= nil }
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
  local z = tonumber(day) and floor(tonumber(day)) or now_of(c)
  local w = window_state(c, z)
  return { ok = true, day = z, open = w.open, from = w.from, to = w.to }
end

-- ------------------------------------------------------------------------------------------------ the transfer market

local MARKET_SOURCES = { all = true, clubs = true, free = true, affordable = true, club = true }

-- the market search's names: card -> its name in lower case, per language; named a batch per call
-- (config [market] name_batch) while a name is searched, the screen asking again meanwhile
local SEARCH_NAMES = { lang = nil, names = {}, rev = nil, cards = nil, done = 0 }
local function search_names(c, lang)
  local N = SEARCH_NAMES
  if N.lang ~= lang then
    N = { lang = lang, names = {}, rev = nil, cards = nil, done = 0 }
    SEARCH_NAMES = N
  end
  local rev = type(c.market) == "table" and c.market.rev or 0
  if N.cards == nil or N.rev ~= rev then N.cards, N.rev, N.done = Market.cards(market_env(), c), rev, 0 end
  -- batches of name_batch named until the call's work_ms is used
  local limit, stop = int("market.name_batch", 150), VRFW.time.unix_ms() + num("market.work_ms", 8)
  repeat
    local batch = {}
    while N.done < #N.cards and #batch < limit do
      N.done = N.done + 1
      local card = N.cards[N.done]
      if N.names[card] == nil then batch[#batch + 1] = card end
    end
    if #batch > 0 then
      local names = card_names(batch, lang)
      for _, card in ipairs(batch) do N.names[card] = string.lower(tostring(names[card] or "")) end
    end
  until N.done >= #N.cards or VRFW.time.unix_ms() >= stop
  return N.done >= #N.cards, N.done, #N.cards
end

-- the search's text «key=value;…» (name, club, lmin, lmax, pmax, series, free, afford) -> the filter of
-- Market.view (nil = none) and the source / club it asks
local function search_filter(text)
  local f, any = { key = tostring(text or "") }, false
  for k, v in string.gmatch(f.key, "([%a_]+)=([^;]*)") do
    any = true
    if k == "name" and v ~= "" then f.name_text = string.lower(v)
    elseif k == "club" then f.club = u32(tonumber(v) or 0)
    elseif k == "lmin" then f.level_min = tonumber(v)
    elseif k == "lmax" then f.level_max = tonumber(v)
    elseif k == "pmax" then f.price_max = tonumber(v)
    elseif k == "series" then f.series = floor(tonumber(v) or 0)
    elseif k == "free" then f.free = v == "1"
    elseif k == "afford" then f.affordable = v == "1" end
  end
  if not any then return nil end
  if f.series == 0 then f.series = nil end
  if f.club == 0 then f.club = nil end
  return f
end

-- the series the search offers: { { type, name }, … } in the game's order
local function search_series()
  local ok, names = pcall(VRFW.chara.series_names)
  local out = {}
  for t, n in pairs(ok and type(names) == "table" and names or {}) do out[#out + 1] = { floor(tonumber(t) or 0), tostring(n) } end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

-- (lang, view "buy" / "offers" / "listed", position 0-4, source "all" / "clubs" / "free" / "affordable" / "club",
-- first row, sort "level" / "price" / "value" / "potential" / "form", club of the "club" source) -> { ok, why, open,
-- window = { from, to }, money, squad, max_squad, offers, listed, total, first, rows = { { card, name, club, position,
-- value, price, level, potential, form, trend, role, scores, [bidder, amount, offer, listed] } }[, pricing] }:
-- `market.rows_per_page` rows from `first`; each row's last match scores
function CareerMode.Market(lang, view, position, source, first, sort, club, search)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  if c.phase == "worldcup" or c.phase == "over" or c.phase == "sacked" then return { ok = false, why = "no market in this phase" } end
  if not options_of(c).market then return { ok = false, why = "the career has no transfer market" } end
  view = (view == "offers" or view == "listed") and view or "buy"
  source = MARKET_SOURCES[source] and source or "all"
  local w = window_state(c, now_of(c))
  local filter = view == "buy" and search_filter(search) or nil
  if filter then
    if filter.free then source = "free" elseif filter.club then source, club = "club", filter.club end
    if filter.name_text then
      local ready, done, total = search_names(c, lang)
      if not ready then
        return { ok = true, view = view, rows = {}, total = 0, first = 1, pricing = { done = done, total = total },
          open = w.open, window = { from = Calendar.view(w.from) or false, to = Calendar.view(w.to) or false } }
      end
      local names, part = SEARCH_NAMES.names, filter.name_text
      filter.name = function(card) return string.find(names[card] or "", part, 1, true) ~= nil end
    end
  end
  local v = Market.view(market_env(), c, view, floor(tonumber(position) or 0), source, floor(tonumber(first) or 1),
    view == "listed" and 0 or int("market.rows_per_page", 9), tostring(sort or "price"), u32(tonumber(club) or 0), filter)
  local cards = {}
  for i, r in ipairs(v.rows) do
    cards[i] = r.card
    -- his element (the market's player page)
    local okc, card = pcall(VRFW.chara.card, r.card)
    r.element = okc and type(card) == "table" and floor(tonumber(card.element) or 0) or 0
    -- a loan's day back and an offer's day received as dates
    if r.back then r.back = Calendar.view(r.back) or false end
    for _, o in ipairs(r.offers or {}) do
      if o.back then o.back = Calendar.view(o.back) or false end
      if o.day then o.day = Calendar.view(o.day) or false end
    end
  end
  local names = card_names(cards, lang)
  -- a player of no club who plays for a national side (its roster): national = true (the market says «Otro», not
  -- «Libre»)
  local national = {}
  for _, t in ipairs(NATIONS or {}) do
    for _, p in ipairs(t.players or {}) do national[u32(p.card)] = true end
  end
  for _, r in ipairs(v.rows) do
    if (r.club or 0) == 0 and national[u32(r.card)] then r.national = true end
    r.name = names[r.card] or ""
    local lv = Levels.player(levels_env(), c, r.card)
    if lv then
      r.level, r.form, r.potential, r.trend = lv.level, lv.form, lv.potential, lv.trend
      -- the last match scores (-1.5 .. 1.5)
      r.scores = {}
      for _, x in ipairs(lv.scores or {}) do r.scores[#r.scores + 1] = (tonumber(x) or 0) / 10 end
    end
  end
  v.ok, v.view, v.position, v.source, v.sort = true, view, floor(tonumber(position) or 0), source, tostring(sort or "price")
  v.talk_cost = Market.cost_view(Market.config(market_env(), c))
  v.open, v.window = w.open, { from = Calendar.view(w.from) or false, to = Calendar.view(w.to) or false }
  v.team = c.team
  v.series = search_series()
  -- the search's clubs (the career's, in its order; by the club order's game for the filter panel's club list) and its
  -- steps (config [market] search_*)
  v.clubs = c.clubs
  v.club_groups = club_groups(c)
  v.steps = { level = int("market.search_level_step", 1), low = int("market.search_level_low", 40),
    high = int("market.search_level_high", 99),
    prices = list_of(config("market.search_prices", nil), { 500000, 1000000, 2000000, 5000000, 10000000, 20000000 }) }
  return v
end

-- the characters' description texts (chara_base description_text), read once
local DESCRIPTIONS = nil
local function description_text(base)
  if DESCRIPTIONS == nil then
    DESCRIPTIONS = {}
    local ok, err = pcall(function()
      local id = tostring(config("market.chara_base", "character/chara_base"))
      local cols = VRFW.table.columns(id)
      local at = {}
      for i, c in ipairs(cols) do at[c] = i end
      if not (at.id and at.description_text) then error("no id / description_text column") end
      for _, r in ipairs(VRFW.table.raw(VRFW.table.source(id), "CHARA_BASE_INFO", { at.id, at.description_text })) do
        DESCRIPTIONS[u32(r[at.id])] = u32(r[at.description_text])
      end
    end)
    if not ok then warn("character descriptions not readable (" .. tostring(err) .. ")") end
  end
  return DESCRIPTIONS[u32(base)] or 0
end

-- (card, level, language code) -> { ok, description, stats = { { stat, value }, … }, stat_max }: the market's player
-- page: his description and his stats at that level (scripts\lib\levels.lua stats)
function CareerMode.MarketPlayer(card, level, lang)
  card = u32(tonumber(card) or 0)
  local okb, base = pcall(VRFW.chara.base_of, card)
  local text = description_text(okb and base or 0)
  local description = ""
  if text ~= 0 then
    local texts = GameText.texts(tostring(config("market.description_table", "chara_description_text")),
      GameText.language(lang), { text })
    description = GameText.no_furigana(texts[text] or "")
  end
  local stats = Levels.stats(levels_env(), card, floor(tonumber(level) or 1))
  return { ok = true, description = description, stats = stats or {}, stat_max = int("levels.stat_bar_max", 300) }
end

local function market_change(fn, ...)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  if c.phase == "sacked" then return { ok = false, why = "the player was sacked" } end
  if not options_of(c).market then return { ok = false, why = "the career has no transfer market" } end
  if not window_state(c, now_of(c)).open then return { ok = false, why = "the transfer window is closed", text = "MarketClosed" } end
  local ok, done, why, text = pcall(fn, market_env(), c, ...)
  if not ok then
    warn("market: " .. tostring(done))
    return { ok = false, why = tostring(done) }
  end
  if not done then return { ok = false, why = why, text = text } end
  save()
  -- a talk's step answers its state
  if type(why) == "table" then return { ok = true, talk = why } end
  return { ok = true }
end

-- (card) -> { ok, why, text }: the player bought at his asking price (the seller's rule, the money, the squad cap)
function CareerMode.MarketBuy(card)
  return market_change(Market.buy, u32(tonumber(card) or 0))
end

-- (card) -> { ok, why }: one of the club's players listed for sale / taken off the list
function CareerMode.MarketList(card)
  return market_change(Market.toggle_listed, u32(tonumber(card) or 0))
end

-- (card, status "transfer" / "loan" / "blocked"; the status he has already: back to none) -> { ok, why, text }: one of
-- the club's players listed for sale, listed for loan or blocked (any day, the window open or not)
function CareerMode.MarketStatus(card, status)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  if c.phase == "sacked" then return { ok = false, why = "the player was sacked" } end
  if not options_of(c).market then return { ok = false, why = "the career has no transfer market" } end
  local ok, done, why, text = pcall(Market.set_status, market_env(), c, u32(tonumber(card) or 0), tostring(status or ""))
  if not ok then
    warn("market status: " .. tostring(done))
    return { ok = false, why = tostring(done) }
  end
  if not done then return { ok = false, why = why, text = text } end
  save()
  return { ok = true }
end

-- (offer index, accept 1 / 0) -> { ok, why, text }: an offer received accepted (the player goes) or refused
function CareerMode.MarketAnswer(index, accept)
  return market_change(Market.answer, floor(tonumber(index) or 0), tonumber(accept) == 1)
end

-- (card, offer; 0 = the talk's state only) -> { ok, why, text, talk }: an offer in the talks for a club's player
-- (scripts\lib\market.lua M.talk; the talk is kept in the career until the window closes)
function CareerMode.MarketTalk(card, offer)
  return market_change(Market.talk, u32(tonumber(card) or 0), floor(tonumber(offer) or 0))
end

-- (offer index, amount) -> { ok, why, text, talk }: «Negociar», the player's asking price for a transfer offer
-- received; the bidder answers in a few days (M.negotiate)
function CareerMode.MarketNegotiate(index, amount)
  return market_change(Market.negotiate, floor(tonumber(index) or 0), floor(tonumber(amount) or 0))
end

-- (language code[, first, count]) -> { ok, items = { { id, kind, tag, date, head, body, card, team, from, amount, action,
-- role, clips, seen } }, total, unseen, rev, picture }: the career's news, newest first, texts in that language;
-- clips = the pose of the picture (VRFW_ModelCard: "pack:clip|…", config [news.poses] of the item's role)
function CareerMode.News(lang, first, count)
  local c = load()
  if not c then return { ok = false, why = "no career", items = {} } end
  local fresh = c.news == nil or c.news.watch == nil or #(c.news.items or {}) == 0
  if fresh then
    local okb, err = pcall(News.backfill, news_env(), c)
    if not okb then warn("news backfill: " .. tostring(err)) end
  end
  local ok, v = pcall(News.view, news_env(), c, lang, first, count)
  if not ok then
    warn("news view: " .. tostring(v))
    return { ok = false, why = tostring(v), items = {} }
  end
  if fresh then save() end
  return v
end

-- (id) -> { ok }: every item up to that id seen
function CareerMode.NewsSeen(id)
  local c = load()
  if not c then return { ok = false } end
  if News.seen(c, id) then save() end
  return { ok = true }
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

-- () -> { ok, why, items = { { index, kind "superliga" / "league" / "bracket" / "worldcup", key (the stats' key: "superliga",
-- "league<l>", "frontier", "worldcup"), league (its number for a league) } }, default }: the competitions in the
-- order of «Torneos» (CMND_CAREERMODE_STANDINGS' index; L2 / R2 go through them), default = the one shown first
function CareerMode.Competitions()
  local c = load()
  if not c then return { ok = false, why = "no career", items = {} } end
  local items = {}
  for i, e in ipairs(competitions(c)) do
    local key = e.kind == "league" and ("league" .. e.league) or (e.kind == "bracket" and "frontier" or e.kind)
    items[i] = { index = i, kind = e.kind, key = key, league = e.league or 0 }
  end
  return { ok = true, items = items, default = default_competition(c) }
end

-- (competition index (as in CMND_CAREERMODE_COMPETITIONS), sort "goals" / "rating" / "saves" / "clean" / "mvp", first
-- row, rows, language) -> { ok, why, index, kind, key, sort, total, first, rows = { { rank, card, name, team, position,
-- matches, goals, saves, clean_sheets, rating (0..10, one decimal), mvp } }, mine = the club's best rows (config
-- [stats] club_rows, the same fields) }: the season's player stats of that competition, best first (ties: the second field of the order, then fewer matches, then the card). The list is sorted
-- once per round and order; a call names only its page. The World Cup has none (rows empty)
function CareerMode.Stats(index, sort, first, count, lang)
  local c = load()
  if not c then return { ok = false, why = "no career", rows = {} } end
  local list = competitions(c)
  index = math.max(1, math.min(#list, floor(tonumber(index) or 1)))
  local e = list[index]
  local key = e.kind == "league" and ("league" .. e.league) or (e.kind == "bracket" and "frontier" or e.kind)
  sort = STATS_SORTS[tostring(sort)] and tostring(sort) or "goals"
  local st = type(c.stats) == "table" and c.stats.season == c.season and c.stats or { rev = 0, comp = {} }
  local stamp = string.format("%s:%s:%s", tostring(CAREER_SLOT), tostring(c.season), tostring(st.rev))
  if STATS_LISTS.stamp ~= stamp then STATS_LISTS = { stamp = stamp } end
  local rows = STATS_LISTS[key .. ":" .. sort]
  if rows == nil then
    rows = {}
    local min_matches = sort == "rating" and int("stats.rating_min_matches", 3) or 1
    for id, s in pairs(st.comp[key] or {}) do
      local keep = s[STAT.MATCHES] >= min_matches
      if sort == "goals" then keep = keep and s[STAT.GOALS] > 0
      elseif sort == "saves" then keep = keep and s[STAT.SAVES] > 0
      elseif sort == "clean" then keep = keep and s[STAT.CLEAN] > 0
      elseif sort == "mvp" then keep = keep and s[STAT.MVP] > 0 end
      if keep then rows[#rows + 1] = { card = tonumber(id, 16) or 0, s = s, rating = stats_rating(s) } end
    end
    local order = STATS_SORTS[sort]
    local function field(r, f) return f == "rating" and r.rating or (r.s[f] or 0) end
    table.sort(rows, function(a, b)
      for _, f in ipairs(order) do
        local x, y = field(a, f), field(b, f)
        if x ~= y then return x > y end
      end
      if a.s[STAT.MATCHES] ~= b.s[STAT.MATCHES] then return a.s[STAT.MATCHES] < b.s[STAT.MATCHES] end
      return a.card < b.card
    end)
    STATS_LISTS[key .. ":" .. sort] = rows
  end
  count = math.max(1, math.min(int("stats.max_rows", 50), floor(tonumber(count) or 10)))
  first = math.max(1, math.min(math.max(1, #rows - count + 1), floor(tonumber(first) or 1)))
  -- the page's rows and the club's best (its first club_rows in the order)
  local picks, mine = {}, {}
  for i = first, math.min(#rows, first + count - 1) do picks[#picks + 1] = i end
  local most = int("stats.club_rows", 3)
  for i, r in ipairs(rows) do
    if #mine >= most then break end
    if r.s[STAT.TEAM] == c.team then mine[#mine + 1] = i end
  end
  local cards = {}
  for _, i in ipairs(picks) do cards[#cards + 1] = rows[i].card end
  for _, i in ipairs(mine) do cards[#cards + 1] = rows[i].card end
  local names = #cards > 0 and card_names(cards, lang) or {}
  local function view(i)
    local r = rows[i]
    return { rank = i, card = r.card, name = names[r.card] or "", team = r.s[STAT.TEAM],
      position = Levels.position(levels_env(), r.card), matches = r.s[STAT.MATCHES], goals = r.s[STAT.GOALS],
      saves = r.s[STAT.SAVES], clean_sheets = r.s[STAT.CLEAN], rating = r.rating, mvp = r.s[STAT.MVP] }
  end
  local page, best = {}, {}
  for _, i in ipairs(picks) do page[#page + 1] = view(i) end
  for _, i in ipairs(mine) do best[#best + 1] = view(i) end
  return { ok = true, index = index, kind = e.kind, key = key, sort = sort, total = #rows, first = first, rows = page,
    mine = best }
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

-- a club's member row levels (roster slots 0..[teams] player_slot_max, in order): each row's squad player at his
-- squad level (Levels.squad_levels); 0 = nobody of the squad on that row (it keeps the team's level)
local function row_levels(c, players)
  local slots, cards = {}, {}
  for _, p in ipairs(players or {}) do
    if (p.slot or -1) >= 0 then
      slots[#slots + 1] = p.slot
      cards[#cards + 1] = p.card
    end
  end
  local levels = Levels.squad_levels(levels_env(), c, cards)
  local out = {}
  for k = 0, int("teams.player_slot_max", 18) do out[k + 1] = 0 end
  for i, slot in ipairs(slots) do
    if out[slot + 1] ~= nil then out[slot + 1] = levels[i] or 0 end
  end
  return out
end

-- -> { ok, teams = { { team, rows = { slot, card, … }, levels = { level of roster slot 0, 1, … } } } }: every career
-- club, the roster rows the career changes and each row's level (its player's career level, config [levels]
-- squad_level; the club pick: the starting levels)
function CareerMode.Rosters()
  local c = load()
  local out = {}
  if c then
    for i, t in ipairs(c.clubs) do
      local sq = c.squads[i]
      if sq then out[#out + 1] = { team = t, rows = sq.rows or {}, levels = row_levels(c, sq.players) } end
    end
  elseif PENDING then
    for _, t in ipairs(PENDING.built.clubs) do
      local sq = PENDING.built.squads[t]
      if sq then out[#out + 1] = { team = t, rows = sq.rows or {}, levels = row_levels(PENDING, sq.players) } end
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
  if c.phase ~= "worldcup" then match_armed(me, rival, user_cards, rival_cards) else MATCH = nil end
  local user_levels, rival_levels = {}, {}
  if config("levels.apply_in_match", true) ~= false and Levels.ready(c) and c.phase ~= "worldcup" then
    user_levels = Levels.effective(levels_env(), c, user_cards)
    rival_levels = Levels.effective(levels_env(), c, rival_cards)
  end
  return { ok = true, home = m[1], away = m[2], rival = rival, host = m[1], user = me,
    user_levels = user_levels, rival_levels = rival_levels, level_base = int("match.level_base", 0),
    friendly = tostring(config("match.friendly", "career_match")), game = config("match.game", "fbtl_bb_stadium_00"),
    difficulty = int("match.difficulty", 1), user_team = tostring(config("match.user_team", "evt_career_user")),
    rival_team = tostring(config("match.rival_team", "evt_career_rival")), user_cards = user_cards,
    rival_cards = rival_cards,
    user_formation = c.phase ~= "worldcup" and type(c.lineup) == "table" and u32(c.lineup.formation or 0) or 0,
    user_look = c.phase ~= "worldcup" and type(c.look) == "table" and { kit = u32(c.look.kit or 0),
      emblem = u32(c.look.emblem or 0), coach = u32(c.look.coach or 0) } or false }
end

-- -> { ok }: the armed match given up (no match started)
function CareerMode.Disarm()
  local c = load()
  MATCH = nil
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
  if c.phase == "over" or c.phase == "pots" or c.phase == "sacked" or (c.phase == "worldcup" and c.wc.stage == "call") then
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
  local tints = {}
  for k = 1, #c.pots do tints[k] = Season.pot_tint(k, pot_colours()) end
  return { ok = true, pots = c.pots, leagues = c.leagues, team = c.team, pot_tints = tints }
end

-- (mode: 1 = one day, 2 = up to the match day) -> { ok, why, day, match_day, stop }: the career walks towards its
-- next match one day at a time (each day: the market's share of the round); it stops early on what the player must
-- see (stop = "offer": an offer for one of his players or a bidder's answer to his ask, "loan_back": a player back from a loan, "window_open" /
-- "window_close": the transfer window). At most
-- the stretch's days per call
function CareerMode.Day(mode)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local s = stretch_of(c)
  if not s then return { ok = false, why = "no days before the next match" } end
  local env = market_env()
  local function offers()
    if not options_of(c).market then return 0, 0, 0 end
    local ok, m = pcall(Market.state, env, c, Market.config(env, c))
    return ok and #(m.offers or {}) or 0, ok and #(m.loans or {}) or 0, ok and (m.replies or 0) or 0
  end
  local steps = tonumber(mode) == 2 and (s.to - s.from - s.done) or 1
  local stop = ""
  for _ = 1, math.max(0, steps) do
    local open = window_state(c, now_of(c)).open
    local before, loans_before, replies_before = offers()
    s.done = s.done + 1
    if options_of(c).market then market_day(c, s) end
    local now = window_state(c, now_of(c)).open
    local after, loans_after, replies_after = offers()
    if now ~= open then stop = now and "window_open" or "window_close"
    elseif after > before or replies_after > replies_before then stop = "offer"
    elseif loans_after < loans_before then stop = "loan_back" end
    if stop ~= "" then break end
  end
  save()
  return { ok = true, day = Calendar.view(now_of(c)), match_day = now_of(c) >= s.to, stop = stop }
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

-- ------------------------------------------------------------------------------------------------ the team dock

-- -> { ok, why, team, formation, members = { { position, card, level, EXP bar fill 0..1 or nil } … } }: the player's club for the game's team dock
-- (the hub's «Plantilla», VRFW_TeamEditor in its foreign team mode): the players its matches take, in the lineup's
-- positions; formation 0 = the club's own (the screen reads it from the team's record, CMND_VRFW_TEAM_LOOK)
function CareerMode.ClubDock()
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local cards = match_cards(c, c.team)
  if #cards < STARTERS then return { ok = false, why = "the squad has fewer than " .. STARTERS .. " players" } end
  set_skill_board_lock(true, "team screen")
  local members = {}
  -- dock positions: 0-10 starters, 11-15 bench; 16-18 are the manager places and 19 the coach, so the players after
  -- the 16th go to the team's reserve positions (20-28), the second bench column
  local bench_end, reserve_first = 16, 20
  -- each player at his squad level (config [levels] squad_level), so the screen's levels and team level are the career's
  local levels = Levels.squad_levels(levels_env(), c, cards)
  -- the EXP bar under «Nv.»: his way to his next career level change (config [levels.exp_bar])
  local bars = Levels.exp_bars(levels_env(), c, cards)
  for i, card in ipairs(cards) do
    members[i] = { i <= bench_end and i - 1 or reserve_first + i - bench_end - 1, card, levels[i] or 0,
      bars[i] or nil }
  end
  local look = type(c.look) == "table" and c.look or {}
  local tactics = {}
  for i, id in ipairs(type(look.tactics) == "table" and look.tactics or {}) do tactics[i] = u32(id) end
  return { ok = true, team = c.team, members = members,
    formation = type(c.lineup) == "table" and u32(c.lineup.formation or 0) or 0,
    name = type(look.name) == "string" and look.name or "", emblem = u32(look.emblem or 0), kit = u32(look.kit or 0),
    coach = u32(look.coach or 0), tactics = tactics,
    keep = config("squads.keep_team_screen", false) == true,
    card_actions = config("squads.team_screen_card_actions", true) == true }
end

-- (name, emblem, kit, coach, "tactic,tactic,tactic") -> { ok }: the club's record as the player left it in the team
-- page (0 / "" = the club's own); kept as c.look and worn in its next matches
function CareerMode.ClubLookSet(name, emblem, kit, coach, tactics)
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local list = {}
  for id in string.gmatch(tostring(tactics or ""), "%d+") do list[#list + 1] = u32(tonumber(id)) end
  c.look = { name = type(name) == "string" and name or "", emblem = u32(tonumber(emblem) or 0),
    kit = u32(tonumber(kit) or 0), coach = u32(tonumber(coach) or 0), tactics = list }
  save()
  info(string.format("club look kept: kit %08X, emblem %08X, coach %08X, %d tactic(s)", c.look.kit, c.look.emblem,
    c.look.coach, #list))
  return { ok = true }
end

-- (formation, "position:card,…" the dock positions of the club's players as the dock left them) -> { ok, why }: kept as
-- the club's lineup (c.lineup) for its next matches. Every card must be one of the players its matches take and the 11
-- starter positions filled; the bench keeps its order without the empty places.
function CareerMode.ClubDockSet(formation, placed)
  set_skill_board_lock(false, "team screen left")
  local c = load()
  if not c then return { ok = false, why = "no career" } end
  local cards = match_cards(c, c.team)
  local allowed = {}
  for _, card in ipairs(cards) do allowed[card] = true end
  local at, seen = {}, {}
  for position, card in string.gmatch(tostring(placed or ""), "(%d+):(%d+)") do
    position, card = floor(tonumber(position)), u32(tonumber(card))
    if not allowed[card] then return { ok = false, why = string.format("card %08X is not in the club's squad", card) } end
    if seen[card] or at[position] then return { ok = false, why = "a card or a position twice" } end
    seen[card], at[position] = true, card
  end
  local order = {}
  for position = 0, STARTERS - 1 do
    if not at[position] then return { ok = false, why = "starter position " .. position .. " is empty" } end
    order[#order + 1] = at[position]
  end
  local bench = {}
  for position in pairs(at) do
    if position >= STARTERS then bench[#bench + 1] = position end
  end
  table.sort(bench)
  for _, position in ipairs(bench) do order[#order + 1] = at[position] end
  for _, card in ipairs(cards) do
    if not seen[card] then order[#order + 1] = card end
  end
  local f = u32(tonumber(formation) or 0)
  if f == 0 and type(c.lineup) == "table" then f = u32(c.lineup.formation or 0) end
  c.lineup = { formation = f, order = order }
  save()
  info(string.format("club lineup kept: formation %08X, %d players (%d placed in the dock)", f, #order, #bench + STARTERS))
  return { ok = true }
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

-- a player of the active career -> { level, potential, form, effective, trend, history, scores } or nil (lib/market.lua,
-- lib/news.lua and other mods read it)
function CareerMode.PlayerLevel(card)
  local c = load()
  return c and Levels.player(levels_env(), c, u32(card)) or nil
end

-- a player's market value in value points (x config [market] unit; config [levels.value]); 0 = not a player of it
function CareerMode.PlayerValue(card)
  local c = load()
  return c and Levels.value(levels_env(), c, u32(card)) or 0
end

-- the level changes since news id `since` (signal CareerMode.LevelChanged after a month that changed some):
-- { { id, card, team, from, to, day, kind = "up" | "down" } }
function CareerMode.LevelNews(since)
  local c = load()
  return c and Levels.news(c, tonumber(since) or 0) or {}
end

-- the game's own result of the armed match (VRFW MatchResult.last): the round played with it; a won final asks
-- the trophy lift of the mod that answers config [match] trophy_signal
-- the clubs (every team declaration and the game's team tables) and the cards' index read while a save slot loads
-- (its loading screen), not when the career screen first opens
VRFW.on("slot_load", function()
  set_skill_board_lock(false, "slot load")
  local ok, err = pcall(clubs)
  if not ok then warn("clubs not read at the slot's load: " .. tostring(err)) end
  ok, err = pcall(card_info, 0)
  if not ok then warn("cards' index not read at the slot's load: " .. tostring(err)) end
end)

VRFW.on("game_reset", function()
  set_skill_board_lock(false, "title")
end)

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
  local played = MATCH and MATCH.user == me and MATCH.facts or nil
  MATCH = nil
  local mine_result = play_round(c, r, played)
  if final and p.phase ~= "worldcup" and mine_result and Season.winner(mine_result) == c.team and last.outcome == "win" then
    local name = tostring(config("match.trophy_signal", ""))
    if name ~= "" then pcall(VRFW.signal, name) end
  end
  settle(c)
  save()
  return nil
end)

-- a script start (boot, a reload of the mod's scripts) leaves no lock behind
set_skill_board_lock(false, "start")
