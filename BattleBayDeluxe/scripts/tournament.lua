-- Battle Bay «Torneo» (docs/game/modes/bb-tournament.md), a library of campaign.lua (one VM: the Decide hook asks it
-- for a tournament start). The player's matches are the game's own BB campaign matches (session block S, the same
-- match request, stadium, loading telop, result screen and campaign clear as the Campaña); this file decides who the
-- player meets, records his results, simulates every other match (lib/tourney.lua) and keeps the run in the save blob
-- `bb_tournament.json` of the active slot. Declarations: content\game\tournament.toml; the screens: the graft
-- research/grafts/bb_tournament (the BB top menu's «Torneo» row, the setup, the bracket on the Victory Road
-- tournament art, the campaign end window) and the rulebook content\rules\bbd_knockout.toml (extra time + penalties).
--
-- Session block (estadio-bb.md §3.2): +0x2CA6E4 game, +0x2CA6E8 difficulty, +0x2CA6EC player team, +0x2CA6F0 the
-- 7 rivals, +0x2CA70C the match index. The game asks rivals[index] at every match request; after a WIN it adds 1 to the
-- index (index 6 won = campaign clear: the block is zeroed, the clear counter Session +0x208 grows and the clear
-- event fires); after a loss or a draw it zeroes the block (0x1435xxx).
-- 1.5.5 (owner: the Campaña and the Torneo are independent): the block belongs to the Campaña. The tournament borrows it
-- only for one match: CMND_BBD_TOURN_PREPARE snapshots the Campaña's fields into the save blob
-- `bb_tournament_campaign.json` (the slot's) and writes the tournament's match at index 0 (rivals[0] = its rival; never
-- index 6, so a tournament match never runs the game's campaign clear); after the match the top menu's sync records
-- the result and writes the Campaña's fields back, byte for byte, before the retail menu reads them (also after a
-- restart with the snapshot still there). The champion gets the tournament's own end (the bracket's champion page).
--
-- | Command | Args -> answers |
-- |---|---|
-- | CMND_BBD_TOURN_INFO | -> table { active, armed, fmt, size, double, k, matches, stage, outcome, rules, final (the next match is the final), final_stadium { map, id }, campaign, defaults, rival, next_stage (league / groups / ko), next_round (matchday; ko: rounds to the final) } |
-- | CMND_BBD_TOURN_ARM | fmt (0 knockout, 1 groups, 2 league, -1 default), size (0 default), configured (1 = options confirmed), filter, double (league: 1 = home and away) -> ok, why |
-- | CMND_BBD_TOURN_DISARM | -> true |
-- | CMND_BBD_TOURN_SYNC | phase, rules, gf, ga, pf, pa, winner, et (CMND_VRFW_RULE_ENGINE_STATE) -> table { event, show } |
-- | CMND_BBD_TOURN_VIEW | page -> table: what the bracket overlay draws (§6) |
-- | CMND_BBD_TOURN_CAMPAIGN_INFO | sub, i -> handled, value: CMND_GET_BB_STADIUM_CAMPAIGN_INFO as a tournament shows it; sub 4 = the loading telop's path length (1.5.47) |
-- | CMND_BBD_TOURN_START | difficulty byte -> table { ok, waiting }: the grid's start (1.5.4) |
-- | CMND_BBD_TOURN_PREPARE | -> table { ok, rules }: the Campaña's block kept, the next tournament match written |
-- | CMND_BBD_TOURN_UNLOAD | -> true: the Campaña's block back (the match request failed) |
-- | CMND_BBD_TOURN_STEP | -> table { event }: after an elimination, the next remaining round simulated (one per Enter) |
-- | CMND_BBD_TOURN_ABANDON | -> true: the run ends, the campaign block is zeroed |
-- | CMND_BBD_TOURN_CLOSE | -> true: an ended run (champion / out) shown once, its blob put aside |

local U = require "lib/util"
local T = require "lib/tourney"
local V = require "lib/tourney_view"
local G = require "lib/game"
local PC = require "lib/plate_colors"
local LS = require "league_squad"
local Trophy = require "lib/trophy_celebration"

local Tn = {}

local floor = math.floor

local BLOB = "bb_tournament.json"
local RUN_VERSION = 1
local S_GAME, S_DIFF, S_PLAYER, S_RIVALS, S_INDEX, S_CLEARS = 0x2CA6E4, 0x2CA6E8, 0x2CA6EC, 0x2CA6F0, 0x2CA70C, 0x208

require "VRFW/lib/basics"
local info, warn = VRFW.logger("tournament")

-- ------------------------------------------------------------------------------------------------ config

local function cfg_num(key, def, lo, hi)
  local v = tonumber(U.config("tournament." .. key, def)) or def
  if v < lo or v > hi then
    warn(string.format("config [tournament] %s = %s out of %s..%s: %s used", key, tostring(v), tostring(lo),
      tostring(hi), tostring(def)))
    return def
  end
  return v
end

local CFG = {
  fmt = tostring(U.config("tournament.format", T.DEFAULTS.fmt)),
  size = cfg_num("teams", T.DEFAULTS.size, T.MIN_SIZE, T.MAX_SIZE),
  seeded = U.config("tournament.seeded", T.DEFAULTS.seeded) ~= false,
  goals = cfg_num("goals", T.DEFAULTS.goals, 0.2, 5),
  weight = cfg_num("strength_weight", T.DEFAULTS.weight, 0, 1),
  pen_kick = cfg_num("penalty_score", T.DEFAULTS.pen_kick, 0.05, 0.99),
  pen_kicks = cfg_num("penalty_kicks", T.DEFAULTS.pen_kicks, 1, 11),
  seed = tonumber(U.config("tournament.seed", 0)) or 0,
  rules = tostring(U.config("tournament.knockout_rules", "bbd_knockout")),
  -- the final's rulebook (the knockout's plus the tournament-final end: the champions' celebration) and the
  -- stadiums one of which is drawn for the final (config.toml [tournament] final_rules / final_stadiums)
  final_rules = tostring(U.config("tournament.final_rules", "bbd_final")),
  final_stadiums = {},
  -- 1.5.16: «Filtrar equipos poco importantes» (the options' cursor start) and the story matches' game key patterns
  filter = U.config("tournament.filter_minor", false) == true,
  story_games = {},
}
do
  local g = U.config("tournament.filter_story_games", {})
  if type(g) == "string" then
    g = { g }
  end
  if type(g) == "table" then
    for _, x in ipairs(g) do
      CFG.story_games[#CFG.story_games + 1] = tostring(x)
    end
  end
end
do
  local list = U.config("tournament.final_stadiums", {})
  if type(list) == "string" then
    list = { list }
  end
  if type(list) == "table" then
    for _, x in ipairs(list) do
      if type(x) == "string" and x ~= "" then
        CFG.final_stadiums[#CFG.final_stadiums + 1] = x
      end
    end
  end
end
if CFG.fmt == "league" or not T.valid(CFG.fmt, CFG.size) then
  warn(string.format("config [tournament] format %q / teams %d not offered: knockout / 16", CFG.fmt, CFG.size))
  CFG.fmt, CFG.size = "knockout", 16
end
-- the «Liga» (config.toml [league]): where the options' cursor starts (teams, home and away) and the standings rows
-- a page shows
CFG.league_size = tonumber(U.config("league.teams", 12)) or 12
if not T.valid("league", CFG.league_size) then
  warn(string.format("config [league] teams = %s not offered (an even count, %d .. %d): 12 used",
    tostring(CFG.league_size), T.LEAGUE.MIN, T.LEAGUE.MAX))
  CFG.league_size = 12
end
CFG.league_double = U.config("league.double", false) == true
CFG.league_no_national = U.config("league.no_national", false) == true
-- the top scorers of the simulated matches: a starter's share of his team's goals = his kick stat x the weight of his
-- position (chara_param main_position: 2 FW, 3 MF; every other position 0)
CFG.scorer_weight = {
  [2] = tonumber(U.config("league.scorer_weight_forward", 1.0)) or 1.0,
  [3] = tonumber(U.config("league.scorer_weight_midfielder", 0.45)) or 0.45,
}
CFG.name_language = U.trim(tostring(U.config("league.name_language", "es")))
V.LEAGUE_ROWS = floor(tonumber(U.config("league.rows_per_page", V.LEAGUE_ROWS)) or V.LEAGUE_ROWS)
if V.LEAGUE_ROWS < 4 or V.LEAGUE_ROWS > V.LEAGUE_ROWS_MAX then
  warn(string.format("config [league] rows_per_page = %d out of 4..%d: 12 used", V.LEAGUE_ROWS, V.LEAGUE_ROWS_MAX))
  V.LEAGUE_ROWS = 12
end

-- the format's number in the commands (0 knockout, 1 groups, 2 league) and back (-1 / unknown = nil)
local function fmt_id(fmt)
  return T.FORMAT_IDS[fmt] or 0
end
local function fmt_name(n)
  return T.FORMAT_OF[U.int(n, -1)]
end
info(string.format("defaults %s / %d teams, seeded %s, seed %s, knockout rulebook %q", CFG.fmt, CFG.size,
  tostring(CFG.seeded), tostring(CFG.seed), CFG.rules))

local function mk(h, l)
  return U.rng(h, l)
end

-- ------------------------------------------------------------------------------------------------ strength

local LEVELS = nil

-- the team table's rows: VRFW.table.rows builds a fresh Lua table of every row per call, and levels, name_text,
-- story_set and exclusion_set each read it once; the script-load warm-up (end of this file) reads it once for all four
-- (TEAM_ROWS set only while it runs)
local TEAM_ROWS = nil
local function team_rows()
  if TEAM_ROWS then
    return true, TEAM_ROWS
  end
  return pcall(VRFW.table.rows, "team/team")
end

-- team -> level (team_config col 8 «level» as the game loads it, the mods' teams included)
local function levels()
  if LEVELS then
    return LEVELS
  end
  LEVELS = {}
  local ok, rows = team_rows()
  if ok and type(rows) == "table" then
    for _, r in ipairs(rows) do
      local id, lv = r.id or r[1], r.level or r[9]
      if type(id) == "number" and type(lv) == "number" then
        LEVELS[U.u32(id)] = lv
      end
    end
  else
    warn("team table not readable: team levels left out of the strength")
  end
  return LEVELS
end

-- strength of a team = its rating (the Campaña's rating table; unknown = the median of the known ones) + its level
local function strength(team, ratings, med)
  return (ratings[team] or med or 0) + (levels()[team] or 0)
end

local function median(ratings)
  local v = {}
  for _, r in pairs(ratings) do
    v[#v + 1] = r
  end
  if #v == 0 then
    return 0
  end
  table.sort(v)
  return v[floor(#v / 2) + 1]
end

-- ------------------------------------------------------------------------------------------------ minor teams filter

-- 1.5.16 (owner): «Filtrar equipos poco importantes». The teams of the story / Chronicle mode of every game, derived
-- from the game's own data as the game loads it (mods included), never from a list:
--   * the Chronicle board's matches: every soccer game of a board piece event (vsroute/vs_route_piece_event
--     paramCrc1; IE1-3, GO, Chrono Stone, Galaxy, Ares, Orion, Victory Road routes), plus the piece's forced player
--     team (paramCrc2);
--   * the story matches: every soccer game whose key matches config.toml [tournament] filter_story_games (the
--     game's own key convention for its story matches, e.g. «fbtl_st_*»);
--   * of those games, every opponent (soccer_game_config SOCCER_GAME_DIFFICULTY opponent_team, every difficulty) and
--     forced player team (own_team_override).
-- A Battle Bay candidate is «important» when its team is one of them, or has the same name text (team_config
-- name_text: the Battle Bay copies and the mod's Chronicle teams keep the name of the game team they copy).
local STORY = nil

local function glob_match(pat, s)
  local lp = "^" .. tostring(pat):gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*") .. "$"
  return tostring(s):match(lp) ~= nil
end

local function story_set()
  if STORY then
    return STORY
  end
  STORY = { teams = {}, names = {}, games = 0, n = 0 }
  local ok, err = pcall(function()
    local games = {}
    local function team(t, set)
      t = U.u32(t or 0)
      if t ~= 0 then
        STORY.teams[t] = true
      end
    end
    for _, r in ipairs(VRFW.table.rows("vsroute/vs_route_piece_event")) do
      local g = U.u32(r.paramCrc1 or r[1] or 0)
      if g ~= 0 then
        games[g] = true
      end
      team(r.paramCrc2 or r[2])
    end
    local globs = CFG.story_games
    if #globs > 0 then
      for _, r in ipairs(VRFW.table.rows("soccer/soccer_game_info")) do
        local name = r.name or r[2]
        for _, gl in ipairs(globs) do
          if type(name) == "string" and glob_match(gl, name) then
            games[U.u32(r.id or r[1])] = true
          end
        end
      end
    end
    -- the games' difficulty rows (the file's order: each SOCCER_GAME_INFO, then its (start, count) slice row)
    local key = VRFW.table.source("soccer/soccer_game_info")
    local cur, slice, diffs = nil, {}, {}
    for _, e in ipairs(VRFW.table.entries(key, { "SOCCER_GAME_INFO", "SOCCER_GAME_INFO_REF_DIFFICULTY",
      "SOCCER_GAME_DIFFICULTY" }, true)) do
      if e.name == "SOCCER_GAME_INFO" then
        cur = U.u32(e[1] or 0)
      elseif e.name == "SOCCER_GAME_INFO_REF_DIFFICULTY" then
        if cur then
          slice[cur] = { e[1] or 0, e[2] or 0 }
        end
      elseif e.name == "SOCCER_GAME_DIFFICULTY" then
        diffs[#diffs + 1] = { e[2], e[6] }
      end
    end
    for g in pairs(games) do
      local sl = slice[g]
      if sl then
        STORY.games = STORY.games + 1
        for k = sl[1] + 1, sl[1] + sl[2] do
          local d = diffs[k]
          if d then
            team(d[1])
            team(d[2])
          end
        end
      end
    end
    -- the name texts of those teams
    local okT, trows = team_rows()
    if not okT then
      error(trows, 0)
    end
    for _, r in ipairs(trows) do
      local id = U.u32(r.id or r[1] or 0)
      if STORY.teams[id] then
        local nt = U.u32(r.name_text or r[4] or 0)
        if nt ~= 0 then
          STORY.names[nt] = true
        end
      end
    end
    for _ in pairs(STORY.teams) do
      STORY.n = STORY.n + 1
    end
  end)
  if not ok then
    warn("minor teams filter: the story / Chronicle teams not readable (" .. tostring(err) .. "): no team counts as one")
  else
    info(string.format("minor teams filter: %d story / Chronicle teams from %d games", STORY.n, STORY.games))
  end
  return STORY
end

local NAME_TEXT = nil
local function name_text(t)
  if not NAME_TEXT then
    NAME_TEXT = {}
    local ok, rows = team_rows()
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        NAME_TEXT[U.u32(r.id or r[1] or 0)] = U.u32(r.name_text or r[4] or 0)
      end
    end
  end
  return NAME_TEXT[t] or 0
end
-- the Campaña's draw leaves the player's team out in every version (same name text)
Tn.name_text = name_text

-- a candidate of the story / Chronicle mode (by team, or by its name text)
local function is_story(t)
  local S = story_set()
  if S.teams[t] then
    return true
  end
  local nt = name_text(t)
  return nt ~= 0 and S.names[nt] == true
end
Tn.is_story = is_story

-- the n opponents of a filtered draw (in random order): first the story / Chronicle candidates (a random n of them
-- when there are more), then the strongest of the rest (strength = rating + level; ties in the shuffle's order)
local function filtered_opponents(v, n, ratings, med)
  local story, rest = {}, {}
  for _, t in ipairs(v) do
    if is_story(t) then
      story[#story + 1] = t
    else
      rest[#rest + 1] = { t = t, s = strength(t, ratings, med), k = #rest }
    end
  end
  local out = {}
  for i = 1, math.min(n, #story) do
    out[#out + 1] = story[i]
  end
  if #out < n then
    table.sort(rest, function(a, b)
      if a.s ~= b.s then
        return a.s > b.s
      end
      return a.k < b.k
    end)
    for i = 1, n - #out do
      if rest[i] then
        out[#out + 1] = rest[i].t
      end
    end
  end
  info(string.format("minor teams filter: %d of %d story / Chronicle candidates, %d strongest of the rest", math.min(n,
    #story), #story, math.max(0, n - #story)))
  return out
end

-- ------------------------------------------------------------------------------------------------ save blob

local RUN, RUN_SLOT = nil, nil
local ARMED = nil        -- { fmt, size, configured, filter, double }: the next campaign start in the grid is a tournament
local PENDING = nil      -- 1.5.4: the run drawn at the grid's start (the native start refused), waiting for the difficulty
local PENDING_DIFF = nil -- the difficulty the grid's start sent (CMND_BBD_TOURN_START), when it came first
local FAILED = nil       -- 1.5.11: why the last start did not draw a run (TournInfo .failed, read once by the grid)
local POOL = nil         -- 1.5.15: the candidates of the last campaign draw (Tn.note_pool): caps the team counts offered
local POOL_LEAGUE = nil  -- 1.48.0: of that pool, the league's clubs { all, without the national sides }
local PLAYED = nil       -- the tournament match that ended this session { index, rival, sc, native, gf, ga, outcome }:
                        -- the score only from the game's own result (vrfw.match_result)
local LIVE = nil         -- the match being played { index, rival } (match_start)
local final_request     -- the final stadium request (defined below; match_end calls it)

local function current_slot()
  local ok, n = pcall(VRFW.slots.active)
  if ok and type(n) == "number" and n ~= 0 then
    return floor(n)
  end
  return 1
end

local function save()
  if not RUN then
    return
  end
  local n = current_slot()
  local ok, done, why = pcall(VRFW.save.blob_write, BLOB, VRFW.json.encode(RUN), n)
  if not (ok and done) then
    warn(BLOB .. " (slot " .. n .. ") not written: " .. tostring(ok and why or done))
  end
end

local function load()
  local n = current_slot()
  if RUN_SLOT == n then
    return RUN
  end
  RUN, RUN_SLOT = nil, n
  local ok, b = pcall(VRFW.save.blob, BLOB, n)
  if ok and type(b) == "string" then
    local doc, jerr = VRFW.json.decode(b)
    if type(doc) == "table" and doc.v == RUN_VERSION then
      RUN = doc
      info(string.format("run of slot %d: %s / %d teams%s, %d match(es) played, stage %s", n, doc.fmt, doc.size,
        doc.double and " (home and away)" or "", doc.k, tostring(doc.stage)))
    else
      warn(BLOB .. " (slot " .. n .. ") unreadable (" .. tostring(jerr or "version") .. "): no tournament")
    end
  end
  return RUN
end

local function drop(why)
  local n = current_slot()
  local ok, b = pcall(VRFW.save.blob, BLOB, n)
  if ok and type(b) == "string" then
    local ok2, where = pcall(VRFW.save.blob_aside, BLOB, n)
    info(BLOB .. " (slot " .. n .. ") put aside (" .. why .. "): " .. tostring(ok2 and where or "failed"))
  end
  RUN = nil
end

-- ------------------------------------------------------------------------------------------------ the session block

local function session()
  return U.global("session")
end

local function block_state(s)
  if not s then
    return nil
  end
  local r = {
    game = U.rd("u32", s + S_GAME), diff = U.rd("u8", s + S_DIFF), player = U.rd("u32", s + S_PLAYER),
    index = U.rd("u8", s + S_INDEX), clears = U.rd("u32", s + S_CLEARS), rivals = {},
  }
  for i = 0, 6 do
    r.rivals[i + 1] = U.rd("u32", s + S_RIVALS + 4 * i) or 0
  end
  return r
end

-- the block holds this run (player team and first rival)
local function block_is_run(b, run)
  return b and run.sess and b.player == run.sess.player and b.rivals[1] == run.sess.r1 and b.rivals[1] ~= 0
end

-- write the block for the player's next match: index 0, rivals[0] = its rival (the run's mark with the player);
-- false when not writable
local function write_block(run)
  local s = session()
  if not s or not run.sess then
    return false
  end
  local opp = T.opponent(run)
  if opp == 0 then
    return false
  end
  run.sess.r1 = run.teams[opp]
  local ok = U.wr("u32", s + S_GAME, run.sess.game) and U.wr("u8", s + S_DIFF, run.sess.diff)
    and U.wr("u32", s + S_PLAYER, run.sess.player)
  for i = 0, 6 do
    ok = ok and U.wr("u32", s + S_RIVALS + 4 * i, i == 0 and run.teams[opp] or 0)
  end
  ok = ok and U.wr("u8", s + S_INDEX, 0)
  if ok then
    info(string.format("match %d/%d: rival %s (the Campaña's block borrowed)", run.k + 1, T.run_matches(run),
      U.hex(run.teams[opp])))
  else
    warn("campaign block not written")
  end
  return ok
end

-- ---- the Campaña's fields while a tournament match borrows the block (save blob, per slot)

local CAMP_BLOB = "bb_tournament_campaign.json"

local function camp_snapshot_get()
  local ok, b = pcall(VRFW.save.blob, CAMP_BLOB, current_slot())
  if ok and type(b) == "string" then
    local doc = VRFW.json.decode(b)
    if type(doc) == "table" and type(doc.rivals) == "table" then
      return doc
    end
  end
  return nil
end

-- the Campaña's fields now (game, difficulty, player, rivals[7], index) into the blob; false when not written
local function camp_snapshot_take(b)
  local doc = { v = 1, game = b.game or 0, diff = b.diff or 0, player = b.player or 0, index = b.index or 0,
    clears = b.clears or 0, rivals = {} }
  for i = 1, 7 do
    doc.rivals[i] = b.rivals[i] or 0
  end
  local ok, done, why = pcall(VRFW.save.blob_write, CAMP_BLOB, VRFW.json.encode(doc), current_slot())
  if not (ok and done) then
    warn(CAMP_BLOB .. " not written (" .. tostring(ok and why or done) .. "): the Campaña's block is not borrowed")
    return false
  end
  info(string.format("Campaña block kept (player %s, rival 1 %s, index %d)", U.hex(doc.player), U.hex(doc.rivals[1]),
    doc.index))
  return true
end

-- the Campaña's fields back (byte for byte) and the blob put aside; true when there was one
local function camp_restore()
  local doc = camp_snapshot_get()
  if not doc then
    return false
  end
  local s = session()
  if not s then
    return false
  end
  local ok = U.wr("u32", s + S_GAME, U.u32(doc.game)) and U.wr("u8", s + S_DIFF, doc.diff)
    and U.wr("u32", s + S_PLAYER, U.u32(doc.player)) and U.wr("u8", s + S_INDEX, doc.index)
  for i = 0, 6 do
    ok = ok and U.wr("u32", s + S_RIVALS + 4 * i, U.u32(doc.rivals[i + 1]))
  end
  local b = block_state(s)
  if b and doc.clears and b.clears ~= doc.clears then
    warn(string.format("the campaign clear counter changed during a tournament match (%d -> %d)", doc.clears, b.clears))
  end
  if not ok then
    warn("the Campaña's block was not written back (kept in " .. CAMP_BLOB .. ")")
    return false
  end
  pcall(VRFW.save.blob_aside, CAMP_BLOB, current_slot())
  info(string.format("Campaña block back (player %s, rival 1 %s, index %d)", U.hex(U.u32(doc.player)),
    U.hex(U.u32(doc.rivals[1])), doc.index))
  return true
end
Tn.camp_restore = camp_restore

-- ------------------------------------------------------------------------------------------------ the start (Decide)

function Tn.armed()
  return ARMED ~= nil
end

-- the campaign draw's candidate count (campaign.lua): the next options panel offers only the counts it fills
function Tn.note_pool(n, list, player)
  if type(n) == "number" and n >= 0 then
    POOL = n
  end
  -- the league's counts of that pool (one team per club; without the national sides)
  if type(list) == "table" then
    local ok, a, b = pcall(function()
      local x = Tn.excluded(list)
      return #Tn.league_pool(x, player or 0, false), #Tn.league_pool(x, player or 0, true)
    end)
    if ok then
      POOL_LEAGUE = { a, b }
    end
  end
end

-- the team counts the options offer per format ({ knockout = {…}, groups = {…}, league = {…} }, smallest first). The minor teams
-- filter (1.5.16) only chooses which candidates play (the story / Chronicle ones first, the strongest of the rest
-- after them), so with it on or off the cap is the same: every candidate the pool has, plus the player
local function offered_sizes()
  local cap = POOL and (POOL + 1) or nil
  local lg = POOL_LEAGUE or {}
  return { knockout = T.sizes("knockout", cap), groups = T.sizes("groups", cap),
    league = T.sizes("league", lg[1] and (lg[1] + 1) or cap),
    league_no_national = T.sizes("league", lg[2] and (lg[2] + 1) or cap) }
end

-- 1.5.27 (owner): teams never drawn for the Torneo, declared in config.toml [tournament] (no list in code):
--   exclude_same_kit_as = team keys: every team in the same kit (team_config uniform) is left out (the Victory Road
--     school clubs all wear their school's kit: «tm_prc_050200» Club de culturismo names them all);
--   exclude_same_emblem_as = team keys: every team with the same emblem (the owner's «4 teams with the logo of
--     Llamarada volcánica»: the game's two, the Battle Bay copies of the mods);
--   exclude_teams = team keys left out themselves.
-- Read from the team table as the game loads it (mods included); the first 20 left-out teams are logged, then a count.
local EXCL = nil
local function exclusion_set()
  if EXCL then
    return EXCL
  end
  EXCL = {}
  local function keys(name)
    local v = U.config("tournament." .. name, {})
    return type(v) == "table" and v or {}
  end
  local by_kit, by_emblem, by_key = {}, {}, {}
  for _, k in ipairs(keys("exclude_teams")) do
    by_key[tostring(k)] = true
  end
  local ok, rows = team_rows()
  if not ok or type(rows) ~= "table" then
    warn("exclusions: the team table is not readable: none applied")
    return EXCL
  end
  local function kit_of(r)
    return U.u32(r.uniform or r.kit or r[6] or 0)
  end
  local function emblem_of(r)
    return U.u32(r.emblem or r[7] or 0)
  end
  local want_kit, want_emblem = {}, {}
  for _, k in ipairs(keys("exclude_same_kit_as")) do
    want_kit[tostring(k)] = true
  end
  for _, k in ipairs(keys("exclude_same_emblem_as")) do
    want_emblem[tostring(k)] = true
  end
  for _, r in ipairs(rows) do
    local key = tostring(r.key or r[2] or "")
    if want_kit[key] and kit_of(r) ~= 0 then
      by_kit[kit_of(r)] = key
    end
    if want_emblem[key] and emblem_of(r) ~= 0 then
      by_emblem[emblem_of(r)] = key
    end
  end
  local n = 0
  for _, r in ipairs(rows) do
    local key = tostring(r.key or r[2] or "")
    local why = (by_key[key] and "listed") or (by_kit[kit_of(r)] and ("kit of " .. by_kit[kit_of(r)]))
      or (by_emblem[emblem_of(r)] and ("emblem of " .. by_emblem[emblem_of(r)]))
    if why then
      EXCL[U.u32(r.id or r[1] or 0)] = why
      n = n + 1
      -- the first ones named, the rest counted (2026-10-13: one log line per left-out team, 1300+, in the draw's frame)
      if n <= 20 then
        info(string.format("exclusions: %s (0x%08X, name text 0x%08X): %s", key, U.u32(r.id or r[1] or 0),
          U.u32(r.name_text or r[4] or 0), why))
      end
    end
  end
  info(string.format("exclusions: %d team(s) never drawn for the Torneo", n))
  return EXCL
end

-- the candidates without the excluded teams
local function excluded(cands)
  local X = exclusion_set()
  local out, dropped = {}, 0
  for _, t in ipairs(cands) do
    if X[U.u32(t)] then
      dropped = dropped + 1
    else
      out[#out + 1] = t
    end
  end
  if dropped > 0 then
    info(string.format("exclusions: %d of %d candidates left out", dropped, #cands))
  end
  return out
end
Tn.excluded = excluded

-- ------------------------------------------------------------------------------------------------ the league's pool

-- 1.48.0 (owner 2026-10-28): a league never holds two variants of one club (A / B and other lettered versions:
-- «Alius A» / «Alius B», «Selección nacional A» / «B»), and «Sin selecciones nacionales» leaves the national sides out.
-- Club families from the team table as the game loads it (no list): two teams are one club when their keys differ only
-- by a final variant letter after the number (tm_st_game_0101a / _0101b), or their names (team_text, config.toml
-- [league] name_language) differ only by a final capital letter («… A» / «… B»); the team data has no base-team
-- column, so the name is the fallback that covers the Chronicle copies. National sides: config.toml [league]
-- national_teams (team keys, declared data): every team with one of those keys or the same name text (the Battle Bay
-- copies keep the name of the team they copy).
local CLUB, NATIONAL = nil, nil

local function team_name_strings()
  local out = {}
  local ok, rows = pcall(VRFW.table.raw, U.table_key("data/common/text/" .. CFG.name_language .. "/team_text"),
    "NOUN_INFO", { 1, 2, 6 })
  if ok and type(rows) == "table" then
    for _, r in ipairs(rows) do
      if type(r[1]) == "number" and r[2] == 0 and type(r[6]) == "string" then
        out[U.u32(r[1])] = U.trim(r[6])
      end
    end
  else
    warn("league: team names not readable (" .. tostring(rows) .. "): club variants by key only")
  end
  return out
end

local function league_sets()
  if CLUB then
    return CLUB, NATIONAL
  end
  CLUB, NATIONAL = {}, {}
  local ok, rows = team_rows()
  if not ok or type(rows) ~= "table" then
    warn("league: the team table is not readable: no club variants, no national sides")
    return CLUB, NATIONAL
  end
  local names = team_name_strings()
  local fam, root = {}, {}
  local function find(t)
    while root[t] and root[t] ~= t do
      t = root[t]
    end
    return t
  end
  local nat_keys, nat_names = {}, {}
  local list = U.config("league.national_teams", {})
  for _, k in ipairs(type(list) == "table" and list or {}) do
    nat_keys[tostring(k)] = true
  end
  for _, r in ipairs(rows) do
    local id = U.u32(r.id or r[1] or 0)
    local key = tostring(r.key or r[2] or "")
    local nt = U.u32(r.name_text or r[4] or 0)
    root[id] = id
    if nat_keys[key] and nt ~= 0 then
      nat_names[nt] = true
    end
    local fams = {}
    local kb = key:match("^(.-%d)[a-z]$")
    if kb then
      fams[#fams + 1] = "k:" .. kb
    end
    local name = names[nt]
    if name then
      local nb = name:match("^(.-)%s+[A-Z]$")
      fams[#fams + 1] = "n:" .. (nb or name)
    end
    for _, f in ipairs(fams) do
      if fam[f] then
        local a, b = find(fam[f]), find(id)
        if a ~= b then
          root[b] = a
        end
      else
        fam[f] = id
      end
    end
  end
  local n_nat = 0
  for _, r in ipairs(rows) do
    local id = U.u32(r.id or r[1] or 0)
    CLUB[id] = find(id)
    local key = tostring(r.key or r[2] or "")
    if nat_keys[key] or nat_names[U.u32(r.name_text or r[4] or 0)] then
      NATIONAL[id] = true
      n_nat = n_nat + 1
    end
  end
  info(string.format("league: club families of %d teams, %d national side(s) from %d declared key(s)", #rows, n_nat,
    #list))
  return CLUB, NATIONAL
end

-- the league's candidates: national sides left out (no_national), then one team per club in the order of `rng`'s
-- shuffle, never the player's club
function Tn.league_pool(cands, player, no_national, rng)
  local club, nat = league_sets()
  local v = {}
  for _, t in ipairs(cands) do
    if not (no_national and nat[U.u32(t)]) then
      v[#v + 1] = t
    end
  end
  if rng then
    rng:shuffle(v)
  end
  local seen = { [club[U.u32(player)] or U.u32(player)] = true }
  local out = {}
  for _, t in ipairs(v) do
    local c = club[U.u32(t)] or U.u32(t)
    if not seen[c] then
      seen[c] = true
      out[#out + 1] = t
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ teams picked by hand

-- 1.49.0 (owner 2026-10-28): «Equipos: Personalizado». The picks per mode (the Torneo's, the Liga's) in the save blob
-- bb_picks.json of the slot ({ v, tournament = { team … }, league = { team … } }, never the player's team: it is always
-- in), remembered for the next run. CMND_BBD_TOURN_PICK(op, fmt, team, player): 0 begin (the saved picks, a copy kept
-- for a cancel) -> { teams, n, max }; 1 toggle team -> { ok, on, n, why = "player" | "club" | "max" }; 2 keep (saved)
-- and 3 cancel (the copy back) -> { n }; 4 count -> { n }. n counts the player's team. Two versions of one club (the
-- league's club families, Tn.league_pool) are refused.
local PICKS_BLOB = "bb_picks.json"
local PICK = nil   -- { mode, player, teams, snap }

local function picks_doc()
  local ok, b = pcall(VRFW.save.blob, PICKS_BLOB, current_slot())
  if ok and type(b) == "string" then
    local doc = VRFW.json.decode(b)
    if type(doc) == "table" then
      return doc
    end
  end
  return { v = 1 }
end

local function pick_mode(fmt)
  return T.FORMAT_OF[U.int(fmt, 0)] == "league" and "league" or "tournament"
end

-- the saved picks of a format's mode, without the player's team nor another version of his club or of each other
function Tn.picks_of(fmt, player)
  local mode = type(fmt) == "string" and (fmt == "league" and "league" or "tournament") or pick_mode(fmt)
  local list = picks_doc()[mode]
  local club = league_sets()
  local seen = { [club[U.u32(player)] or U.u32(player)] = true }
  local out = {}
  for _, t in ipairs(type(list) == "table" and list or {}) do
    t = U.u32(t)
    local c = club[t] or t
    if t ~= 0 and t ~= U.u32(player) and not seen[c] then
      seen[c] = true
      out[#out + 1] = t
    end
  end
  return out
end

function BattleBayDeluxe.TournPick(op, fmt, team, player)
  op, team, player = U.int(op, -1), U.u32(team or 0), U.u32(player or 0)
  local mode = pick_mode(fmt)
  local max = mode == "league" and T.LEAGUE.MAX or T.MAX_SIZE
  if op == 0 or PICK == nil or PICK.mode ~= mode then
    local teams = Tn.picks_of(mode, player)
    local snap = {}
    for i, t in ipairs(teams) do
      snap[i] = t
    end
    PICK = { mode = mode, player = player, teams = teams, snap = snap }
  end
  local P = PICK
  if op == 4 or op == 0 then
    return { teams = P.teams, n = #P.teams + 1, max = max }
  end
  if op == 1 then
    if team == P.player then
      return { ok = false, why = "player", n = #P.teams + 1 }
    end
    for i, t in ipairs(P.teams) do
      if t == team then
        table.remove(P.teams, i)
        return { ok = true, on = false, n = #P.teams + 1 }
      end
    end
    local club = league_sets()
    local c = club[team] or team
    if c == (club[P.player] or P.player) then
      return { ok = false, why = "club", n = #P.teams + 1 }
    end
    for _, t in ipairs(P.teams) do
      if (club[t] or t) == c then
        return { ok = false, why = "club", n = #P.teams + 1 }
      end
    end
    if #P.teams + 1 >= max then
      return { ok = false, why = "max", n = #P.teams + 1 }
    end
    P.teams[#P.teams + 1] = team
    return { ok = true, on = true, n = #P.teams + 1 }
  end
  if op == 2 then
    local doc = picks_doc()
    doc.v = 1
    doc[mode] = P.teams
    local ok, done, why = pcall(VRFW.save.blob_write, PICKS_BLOB, VRFW.json.encode(doc), current_slot())
    if not (ok and done) then
      warn(PICKS_BLOB .. " not written: " .. tostring(ok and why or done))
    end
    P.snap = {}
    for i, t in ipairs(P.teams) do
      P.snap[i] = t
    end
    info(string.format("teams picked by hand (%s): %d + the player's", mode, #P.teams))
    return { n = #P.teams + 1 }
  end
  if op == 3 then
    P.teams = {}
    for i, t in ipairs(P.snap) do
      P.teams[i] = t
    end
    return { n = #P.teams + 1 }
  end
  return { n = #P.teams + 1 }
end

-- 1.5.4: the grid's start is the tournament's (the options panel was confirmed)
function Tn.configured()
  return ARMED ~= nil and ARMED.configured == true
end

-- the run of a tournament started in the grid: `cands` = the campaign's candidates (unlocked rows, never the player's
-- team nor the Draft team), `ratings` = the rating table (team -> rating), (h, l) = the draw's seed. Returns the run
-- (not saved yet: Tn.pend keeps it until the difficulty arrives) or nil, why.
function Tn.begin(cands, player, ratings, h, l)
  local a = ARMED
  if not a then
    return nil, "not armed"
  end
  if CFG.seed ~= 0 then
    h, l = U.split64(CFG.seed)
    l = bit32.bxor(l, player)
  end
  -- 1.5.15 (owner: no byes): always a valid count of the format (a power of two; a league: an even count); a pool
  -- too small for the chosen count plays the largest valid count it fills (the player + #cands teams)
  -- 1.49.0: «Personalizado»: exactly the teams picked by hand (their count + the player's = the size)
  if a.custom then
    local picks = Tn.picks_of(a.fmt, player)
    local size = #picks + 1
    if not T.valid(a.fmt, size) then
      return nil, string.format("%d teams picked by hand: not a %s count", size, a.fmt)
    end
    local rng = U.rng(h, l)
    rng:shuffle(picks)
    local med = median(ratings)
    local opps = {}
    for i, t in ipairs(picks) do
      opps[i] = { team = t, str = strength(t, ratings, med) }
    end
    local run, why = T.new({ fmt = a.fmt, size = size, seed = { h, l }, player = player,
      player_str = strength(player, ratings, med), opponents = opps, seeded = CFG.seeded, double = a.double, mk = mk })
    if not run then
      return nil, why
    end
    run.v = RUN_VERSION
    run.player_team = player
    info(string.format("teams picked by hand: %d + the player's", #picks))
    return run
  end
  cands = excluded(cands)
  if a.fmt == "league" then
    -- 1.48.0: one team per club, the national sides out when asked (the draw's own seed: the variant kept is random)
    cands = Tn.league_pool(cands, player, a.no_national, U.rng((h + 0x4C454147) % 4294967296, l))
  end
  POOL = #cands
  local size = a.size
  if #cands < size - 1 then
    local fit = T.sizes(a.fmt, #cands + 1)
    size = fit[#fit]
    if not size then
      return nil, string.format("%d candidate teams: not enough for any %s tournament", #cands, a.fmt)
    end
    warn(string.format("only %d candidate teams: %d teams instead of %d", #cands, size, a.size))
  end
  local rng = U.rng(h, l)
  local v = {}
  for i, t in ipairs(cands) do
    v[i] = t
  end
  rng:shuffle(v)
  local med = median(ratings)
  -- 1.5.16: the minor teams filter picks WHO plays, never how many (the count stays the power of two above)
  if a.filter then
    v = filtered_opponents(v, size - 1, ratings, med)
    rng:shuffle(v)
  end
  local opps = {}
  for i = 1, size - 1 do
    opps[i] = { team = v[i], str = strength(v[i], ratings, med) }
  end
  local run, why = T.new({ fmt = a.fmt, size = size, seed = { h, l }, player = player,
    player_str = strength(player, ratings, med), opponents = opps, seeded = CFG.seeded, double = a.double, mk = mk })
  if not run then
    return nil, why
  end
  run.v = RUN_VERSION
  run.player_team = player
  return run
end

-- 1.5.4 start: the Decide pre-phase drew the run and refused the game's own start; the grid's Lua sends the
-- difficulty (CMND_BBD_TOURN_START): with both, the campaign block is written by this file (game 0 = the game's
-- Battle Bay campaign row, its own default; the difficulty byte = GetSelectDifficultyIdx() + 1 as the native getter
-- 0x10643D0 answers; the player; rival 1; index 0), the run saved, and the player sees the bracket first; the top
-- menu's «next match» = the game's campaign «continue» request.
local function start_now()
  local run, diff = PENDING, PENDING_DIFF
  if not run or not diff then
    return false
  end
  PENDING, PENDING_DIFF = nil, nil
  local r1 = run.teams[T.opponent(run)]
  run.sess = { game = 0, diff = diff, player = run.player_team, r1 = r1 }
  run.loaded = false
  ARMED = nil
  RUN, RUN_SLOT = run, current_slot()
  save()
  -- the game's own start did not run: the Campaña's block is as it was; the copy kept at the options' confirmation
  -- goes (a later PREPARE takes the Campaña's fields of that moment)
  pcall(VRFW.save.blob_aside, CAMP_BLOB, current_slot())
  if Tn.on_started then
    pcall(Tn.on_started, run)
  end
  info(string.format("started: %s / %d teams%s, player %s, difficulty %d, first rival %s, seed %s:%s", run.fmt,
    run.size, run.double and " (home and away)" or "", U.hex(run.player_team), diff, U.hex(r1), U.hex(run.seed[1]),
    U.hex(run.seed[2])))
  return true
end

-- the pre-phase's run (Decide refused): kept until the difficulty arrives
function Tn.pend(run)
  PENDING = run
  FAILED = nil
  info("drawn at the grid's start (the game's own start refused); waiting for the difficulty")
  return start_now()
end

function BattleBayDeluxe.TournStart(diff)
  diff = U.int(diff, 0)
  if diff < 1 or diff > 16 then
    return { ok = false, why = "difficulty" }
  end
  PENDING_DIFF = diff
  local ok = start_now()
  return { ok = ok or (RUN ~= nil and RUN.k == 0 and not RUN.outcome), waiting = PENDING_DIFF ~= nil }
end

-- the start pressed but no run drawn (scripts\campaign.lua): the grid shows a message (TournInfo .failed, read once)
function Tn.fail(why)
  FAILED = tostring(why or "?")
  warn("start failed: " .. FAILED)
end

-- the first rival of a run (team hash)
-- the player's team of the running (not ended) run of this slot, 0 = none (the Draft keeps its drafted squad for it)
function Tn.player_team()
  local run = load()
  if not run or run.outcome then
    return 0
  end
  return run.player_team or 0
end

-- called before every match of the player is written (TournPrepare): the Draft's squad on the rows (campaign.lua)
Tn.before_match = nil

-- ------------------------------------------------------------------------------------------------ match events

local function copy_table(t)
  if type(t) ~= "table" then
    return t
  end
  local out = {}
  for k, v in pairs(t) do
    out[k] = copy_table(v)
  end
  return out
end

-- the player's result recorded on a copy of the run (the real record stays the top menu's sync): the copy after it,
-- nil when nothing was pending
local function trial_record(run, gf, ga, outcome)
  local trial = copy_table(run)
  local cfg = { goals = CFG.goals, weight = CFG.weight, pen_kick = CFG.pen_kick, pen_kicks = CFG.pen_kicks }
  if not T.record(trial, cfg, mk, gf, ga, 0, 0, false, outcome) then
    return nil
  end
  return trial
end

-- the save's loading screen reads the slot's run (blob + JSON decode), as the first command would: the first
-- CMND_BBD_TOURN_INFO of a session took 43.6 ms on the game thread (owner's loader.log 2026-10-13, install83)
VRFW.on("slot_load", function()
  local ok, e = pcall(load)
  if not ok then
    warn("slot_load: run not read: " .. tostring(e))
  end
  return nil
end)

VRFW.on("match_start", function(ev)
  LIVE, PLAYED = nil, nil
  local run = load()
  if not run or run.outcome then
    return nil
  end
  local b = block_state(session())
  if b and block_is_run(b, run) and b.index then
    LIVE = { index = b.index, rival = b.rivals[b.index + 1], sc = {} }
  end
  return nil
end)

-- every goal of the match: its scorer (the league's top scorers; the score is the game's own result)
VRFW.on("goal", function(ev)
  if LIVE then
    local actor = ev.actor
    if type(actor) == "table" and (actor.side == "user" or actor.side == "rival") and (tonumber(actor.card) or 0) ~= 0 then
      LIVE.sc[#LIVE.sc + 1] = { side = actor.side, card = U.u32(actor.card) }
    end
  end
  return nil
end)

-- the game's own result of the finished match (VRFW MatchResult.last, published at the game's result builder, before
-- the result screen and before a game over): the score and the outcome the result screen shows
VRFW.on("signal:vrfw.match_result", function()
  local MR = rawget(_G, "MatchResult")
  local last = MR and MR.last
  local okr, run = pcall(load)
  if type(last) ~= "table" or not okr or not run or run.outcome or not run.loaded then
    return nil
  end
  local gf, ga = U.int(last.score_for, 0), U.int(last.score_against, 0)
  PLAYED = { index = LIVE and LIVE.index, rival = LIVE and LIVE.rival, gf = gf, ga = ga, outcome = last.outcome,
    native = true, sc = LIVE and LIVE.sc or {} }
  info(string.format("match result (game's own): %s %d-%d", tostring(last.outcome), gf, ga))
  -- the match that makes the player champion (the knockout's final, the league's last matchday with first place):
  -- the champions' celebration after its full time. Decided on a copy of the run with the game's own result; the
  -- shoot-out of a knockout match is in that result (the rulebook's «winner + 1» goal, or its outcome).
  if LIVE and last.outcome == "win" then
    local trial = trial_record(run, gf, ga, last.outcome)
    if trial and trial.outcome == "champion" then
      Trophy.play(run.fmt == "league" and "league" or "tournament", last)
    end
  end
  return nil
end)

VRFW.on("match_end", function(ev)
  if not LIVE then
    return nil
  end
  if PLAYED and PLAYED.native then
    -- the game's own result is already kept: only the live record ends
    PLAYED.index, PLAYED.rival, PLAYED.sc = LIVE.index, LIVE.rival, LIVE.sc
    final_request(nil)
    LIVE = nil
    return nil
  end
  -- no game's own result yet: the match is kept without a score (the rule engine's STATE gives it, else none)
  PLAYED = { index = LIVE.index, rival = LIVE.rival, sc = LIVE.sc }
  final_request(nil)
  info("match over: no game's own result seen")
  LIVE = nil
  return nil
end)

-- ------------------------------------------------------------------------------------------------ top scorers

-- 1.48.0 (owner 2026-10-28): the league's top scorers, kept in the run (run.scorers = { { e, c, g } … }: entrant, card,
-- goals). The player's matches: the scorers the match's goal events named (ev.actor); every other goal (the simulated
-- matches, a goal no event named) goes to a starter of its team drawn by CFG.scorer_weight x his kick stat, from the
-- run's seed (a reload never changes them). Assists are not tracked.
Tn.roster = nil   -- campaign.lua: Draft.roster (a team's member rows in memory: { { slot, param, loadout } … })
local STATS = nil
local SQUADS = {}

local function card_stats()
  if STATS then
    return STATS
  end
  STATS = {}
  local ok, cards = pcall(VRFW.chara.cards, { columns = { "stat_kick" } })
  if ok and type(cards) == "table" then
    for _, c in ipairs(cards) do
      STATS[U.u32(c.id)] = { pos = U.int(c.position, 0), kick = tonumber(c.cols and c.cols.stat_kick) or 0 }
    end
  else
    warn("top scorers: chara_param not readable (" .. tostring(cards) .. ")")
  end
  return STATS
end

-- a team's possible scorers: its starters (member slots 0..10) with a weight
local function scorer_pool(team)
  if SQUADS[team] then
    return SQUADS[team]
  end
  local list = {}
  local rows = nil
  if Tn.roster then
    local ok, r = pcall(Tn.roster, team)
    rows = ok and r or nil
  end
  local st = card_stats()
  for _, m in ipairs(type(rows) == "table" and rows or {}) do
    local slot, card = U.int(m[1], 99), U.u32(m[2] or 0)
    local x = st[card]
    local w = x and (CFG.scorer_weight[x.pos] or 0) * math.max(1, x.kick) or 0
    if slot < 11 and card ~= 0 and w > 0 then
      list[#list + 1] = { card = card, w = w }
    end
  end
  SQUADS[team] = list
  return list
end

local function add_goal(run, e, card)
  run.scorers = run.scorers or {}
  for _, x in ipairs(run.scorers) do
    if x.e == e and x.c == card then
      x.g = x.g + 1
      return
    end
  end
  run.scorers[#run.scorers + 1] = { e = e, c = card, g = 1 }
end

local function drawn_goals(run, e, n, r)
  local pool = scorer_pool(run.teams[e] or 0)
  local total = 0
  for _, x in ipairs(pool) do
    total = total + x.w
  end
  if total <= 0 then
    return
  end
  for _ = 1, n do
    local pick = r:below(1000000) / 1000000 * total
    for _, x in ipairs(pool) do
      pick = pick - x.w
      if pick < 0 then
        add_goal(run, e, x.card)
        break
      end
    end
  end
end

-- the scorers of matchday md (just recorded); live = the player's match's goal events { { side, card } … }
function Tn.league_scorers(run, md, live)
  local p = run.player
  for i, m in ipairs(run.gm[1]) do
    if m.md == md and m.done then
      local mine = m.a == p or m.b == p
      for side = 1, 2 do
        local e = side == 1 and m.a or m.b
        local goals = side == 1 and m.ga or m.gb
        local given = 0
        if mine then
          local want = e == p and "user" or "rival"
          for _, x in ipairs(live or {}) do
            if x.side == want and given < goals then
              add_goal(run, e, x.card)
              given = given + 1
            end
          end
        end
        if goals > given then
          local r = U.rng((run.seed[1] + 0x53434F52 + md * 977) % 4294967296, (run.seed[2] + i * 7919 + side) % 4294967296)
          r:next()
          drawn_goals(run, e, goals - given, r)
        end
      end
    end
  end
end

-- ------------------------------------------------------------------------------------------------ the commands

-- the player's next match is the tournament's final
local function final_next(run)
  local m, stage, round = T.pending(run)
  return m ~= nil and stage == "ko" and T.round_from_end(run, round) == 1
end

local function rules_of(run)
  local m, stage = T.pending(run)
  if m and stage == "ko" then
    if final_next(run) and CFG.final_rules ~= "" then
      return CFG.final_rules
    end
    return CFG.rules
  end
  return ""
end

-- the final's stadium: drawn once from the run's seed among config [tournament] final_stadiums and kept in the run
-- (a reload never changes it); "" = no list (the final keeps the Battle Bay's stadium)
local FINAL_STADIUM_TAG = 0x46494E41
local function final_stadium(run)
  if type(run.final_stadium) == "string" then
    return run.final_stadium
  end
  local n = #CFG.final_stadiums
  local pick = ""
  if n > 0 then
    local r = U.rng((run.seed[1] + FINAL_STADIUM_TAG) % 4294967296, run.seed[2])
    r:next()
    pick = CFG.final_stadiums[r:below(n) + 1]
  end
  run.final_stadium = pick
  save()
  info(string.format("final stadium: %s (drawn among %d)", pick ~= "" and pick or "none", n))
  return pick
end

-- 1.59.0 (owner 2026-10-29): a league match is played at the home side's stadium. The schedule
-- (lib/tourney.lua league_schedule, from the run's seeded draw) makes every pairing home (a) / away (b), evened out,
-- the return legs of «ida y vuelta» swapped; the Battle Bay request plays at the rival's stadium (its enjoy row), so
-- only a player's HOME match needs a request. 1.60.0 (owner 2026-10-29): the stadium of the team he plays the league
-- with (its own home: its enjoy row's stadium, the team data's), never the active dock's Home Stadium choice. A team
-- without one: no request (the Battle Bay request's own stadium, the rival's), logged. nil = none.
local function home_venue(run)
  local m, stage = T.pending(run)
  if not m or stage ~= "league" or m.a ~= run.player then
    return nil
  end
  local team = run.teams[run.player] or 0
  local row = G.enjoy_row(team)
  local map = row and U.get(U.struct("EnjoyRow", row), "stadium") or 0
  if map ~= 0 then
    return U.u32(map), "the league team's own stadium"
  end
  warn(string.format("league home match: team %s has no stadium of its own (enjoy row %s): the request's own stadium",
    U.hex(team), row and "without one" or "missing"))
  return nil
end

-- the StartMatchRequest answer (content\game\active_team.toml) writes this table's stadium into a Battle Bay
-- request: set while the player's next match is the final (its drawn stadium) or a league match at home (his home
-- stadium, 1.59.0), removed otherwise
local FINAL_TABLE = "BattleBayDeluxe.FinalStadium"
final_request = function(run)
  local map = run and not run.outcome and final_next(run) and final_stadium(run) or ""
  local id = map ~= "" and U.crc32(map) or nil
  local why = "final stadium " .. map
  if not id and run and not run.outcome then
    local hv, src = home_venue(run)
    if hv then
      id, why = hv, "league home match, " .. src
    end
  end
  local ok, e = pcall(VRFW.native.table_set, FINAL_TABLE, 0, id)
  if not ok then
    warn("venue request not set: " .. tostring(e))
  elseif id then
    info(string.format("venue request: 0x%08X (%s) for the next Battle Bay match", id, why))
  end
end

function BattleBayDeluxe.TournInfo()
  local run = load()
  local b = block_state(session())
  local t = {
    active = run ~= nil and not run.outcome, ended = run ~= nil and run.outcome ~= false, armed = ARMED ~= nil,
    configured = ARMED ~= nil and ARMED.configured == true, pending = PENDING ~= nil, failed = FAILED,
    campaign = false, -- 1.5.5: the Campaña and the Torneo are independent (true = see below)
    defaults = { fmt = fmt_id(CFG.fmt), size = CFG.size, filter = CFG.filter and 1 or 0,
      league_size = CFG.league_size, double = CFG.league_double and 1 or 0,
      no_national = CFG.league_no_national and 1 or 0 },
    sizes = offered_sizes(),
  }
  FAILED = nil
  if run then
    t.fmt, t.size, t.k, t.stage = fmt_id(run.fmt), run.size, run.k, run.stage
    t.double = run.double and 1 or 0
    t.matches = T.run_matches(run)
    t.outcome = run.outcome or ""
    t.rules = rules_of(run)
    t.final = final_next(run)
    local map = final_stadium(run)
    if map ~= "" then
      t.final_stadium = { map = map, id = U.crc32(map) }
    end
    local opp = T.opponent(run)
    t.rival = opp ~= 0 and run.teams[opp] or 0
    -- the player's next match for the top menu's «SIGUIENTE» badge: the stage (league / groups / ko) and its matchday,
    -- or for a knockout round its distance to the final (1 = the final)
    local m, stage, round = T.pending(run)
    if m then
      t.next_stage = stage
      t.next_round = T.round_robin(stage) and round or T.round_from_end(run, round)
    end
  end
  -- the grid's start ran the game's own campaign start (the Decide hook did not run): the block differs from the
  -- Campaña's fields kept at the options' confirmation
  if ARMED and ARMED.configured and b then
    local snap = camp_snapshot_get()
    if snap and (U.u32(snap.player) ~= b.player or U.u32(snap.rivals[1]) ~= b.rivals[1]) then
      t.campaign = true
    end
  end
  if ARMED then
    t.rules = ARMED.fmt == "knockout" and CFG.rules or ""
    t.fmt, t.size = fmt_id(ARMED.fmt), ARMED.size
    t.filter = ARMED.custom and 2 or (ARMED.filter and 1 or 0)
    t.double = ARMED.double and 1 or 0
    t.no_national = ARMED.no_national and 1 or 0
  end
  -- what CMND_GET_BB_STADIUM_CAMPAIGN_INFO 1 / 3 answer during this run: the grafts keep it and use it when a
  -- later call finds the scripts busy
  if run and not run.outcome then
    t.loaded = run.loaded == true
    local first, len = Tn.path_window(run)
    t.path = Tn.path_len(run)
    t.ci1 = run.k - first + (PLAYED and 1 or 0)
    t.ci3 = {}
    for k = 1, math.max(len, T.MAX_PLAYER_MATCHES) do
      t.ci3[k] = Tn.rival_of(run, first + k)
    end
  end
  return t
end

-- fmt (0 knockout, 1 groups, 2 league; -1 = the default), size (0 = the default), configured (1 = the options panel
-- confirmed: the grid's start is the tournament's), filter (1.5.16: 1 = filter minor teams, 0 = no, -1 / nil = the
-- default), double (the league: 1 = home and away, 0 = once, -1 / nil = the default)
function BattleBayDeluxe.TournArm(fmt, size, configured, filter, double, no_national)
  fmt = fmt_name(fmt) or CFG.fmt
  size = U.int(size, 0)
  if size == 0 then
    size = fmt == "league" and CFG.league_size or CFG.size
  end
  if not T.valid(fmt, size) then
    return false, "format not offered"
  end
  if load() and not RUN.outcome then
    return false, "a tournament is running"
  end
  -- the start is taken by scripts\campaign.lua's Decide hook; without it the grid's start would run the game's own
  -- campaign start under the tournament's grid (a late second decide while the match loads)
  if not VRFW.is_on("Decide") then
    warn("not armed: the Decide hook is off on this build (content/game/campaign.toml)")
    return false, "the Decide hook is off"
  end
  -- filter: 1.49.0 «Equipos»: 0 all, 1 the minor teams filter, 2 the teams picked by hand (Tn picks)
  local fl = U.int(filter, -1)
  local dbl = U.int(double, -1)
  ARMED = { fmt = fmt, size = size, configured = U.int(configured, 0) == 1, filter = fl == 1 or (fl == -1 and CFG.filter),
    double = fmt == "league" and (dbl == 1 or (dbl == -1 and CFG.league_double)) }
  ARMED.custom = fl == 2
  local nn = U.int(no_national, -1)
  ARMED.no_national = fmt == "league" and (nn == 1 or (nn == -1 and CFG.league_no_national))
  PENDING, PENDING_DIFF = nil, nil
  -- the Campaña's fields kept before the grid's start (if the game's own start ran anyway, the next sync puts the
  -- Campaña back): only when no tournament match holds the block
  if ARMED.configured and not (RUN and RUN.loaded) then
    local b = block_state(session())
    if b and camp_snapshot_take(b) then
      ARMED.snap = true
    end
  end
  info(string.format("armed: %s / %d teams%s%s%s", fmt, size, ARMED.custom and ", teams picked by hand"
    or (ARMED.filter and ", minor teams filtered" or ""),
    ARMED.double and ", home and away" or "", ARMED.configured and " (options confirmed)" or ""))
  return true
end

function BattleBayDeluxe.TournDisarm()
  if ARMED or PENDING then
    info("disarmed")
  end
  if ARMED and ARMED.snap then
    pcall(VRFW.save.blob_aside, CAMP_BLOB, current_slot())
  end
  ARMED, PENDING, PENDING_DIFF = nil, nil, nil
  return true
end

-- the result of the player's match that borrowed the block: the game's own result (VRFW MatchResult, the score and
-- outcome of the result screen; the shoot-out and extra time from the rule engine's STATE), else the rule engine's
-- STATE (the knockout rulebook's «winner + 1» goal after a shoot-out taken back); nil = not played (index 0
-- intact); false = no score seen (nothing is recorded: the match stays pending)
local function result_of(run, b, st)
  local function fix(r)
    if r.pf + r.pa > 0 and math.abs(r.gf - r.ga) == 1 then
      if r.gf > r.ga then
        r.gf = r.gf - 1
      else
        r.ga = r.ga - 1
      end
    end
    return r
  end
  local mine = b and block_is_run(b, run)
  local touched = b and (((b.rivals[1] or 0) == 0) or (mine and b.index ~= 0))
  if not touched then
    return nil
  end
  if PLAYED and PLAYED.native then
    local r = { gf = PLAYED.gf, ga = PLAYED.ga, pf = 0, pa = 0, et = false, outcome = PLAYED.outcome }
    if st.ok then
      r.pf, r.pa, r.et = st.pf, st.pa, st.et
    end
    return fix(r)
  end
  if st.ok then
    return fix({ gf = st.gf, ga = st.ga, pf = st.pf, pa = st.pa, et = st.et })
  end
  return false
end

function BattleBayDeluxe.TournSync(phase, rules, gf, ga, pf, pa, winner, et)
  local run = load()
  -- the grid's start ran the game's own campaign start (the Decide hook did not run): the Campaña's fields kept at the
  -- options' confirmation go back
  if ARMED and ARMED.snap and not (run and run.loaded) then
    warn("the game's own campaign start ran for a tournament start: the Campaña's block put back")
    camp_restore()
    ARMED = nil
  end
  if not run then
    PLAYED = nil
    return { event = "none" }
  end
  if run.outcome then
    return { event = "ended", show = true }
  end
  local b = block_state(session())
  local st = { ok = type(phase) == "string" and phase ~= "" and type(gf) == "number",
    gf = U.int(gf, 0), ga = U.int(ga, 0), pf = U.int(pf, 0), pa = U.int(pa, 0), et = et == true or et == 1 }
  if not run.loaded then
    -- no tournament match borrowed the block: it is the Campaña's own
    PLAYED = nil
    return { event = "none", show = false }
  end
  local res = result_of(run, b, st)
  local live_sc = PLAYED and PLAYED.sc
  PLAYED = nil
  run.loaded = false
  camp_restore()
  if res == false then
    save()
    warn("the match ended but no result was seen (no vrfw.match_result or rule engine STATE): " ..
      "nothing recorded, the match stays pending")
    return { event = "none", show = false }
  end
  if not res then
    save()
    info("the borrowed block was not played (a cancelled load or a restart): the Campaña's block is back")
    return { event = "none", show = false }
  end
  local m, stage = T.pending(run)
  if stage == "ko" and res.gf == res.ga and res.pf == res.pa then
    warn(string.format("knockout match ended %d-%d without a shoot-out winner (rulebook %q not applied?): a defeat",
      res.gf, res.ga, CFG.rules))
  end
  local cfg = { goals = CFG.goals, weight = CFG.weight, pen_kick = CFG.pen_kick, pen_kicks = CFG.pen_kicks }
  local done, why = T.record(run, cfg, mk, res.gf, res.ga, res.pf, res.pa, res.et, res.outcome)
  if not done then
    warn("result not recorded: " .. tostring(why))
    return { event = "none", show = false }
  end
  if run.fmt == "league" then
    local oks, es = pcall(Tn.league_scorers, run, done.round, live_sc)
    if not oks then
      warn("top scorers of matchday " .. tostring(done.round) .. " not recorded: " .. tostring(es))
    end
  end
  info(string.format("match %d: %d-%d%s%s; %s round %d complete", run.k, res.gf, res.ga,
    (res.pf + res.pa > 0) and string.format(" (pen. %d-%d)", res.pf, res.pa) or "",
    res.outcome and (" " .. res.outcome) or "", done.stage, done.round))
  local event = "result"
  if run.outcome == "out" then
    -- the rest of the tournament is simulated round by round while the player watches (CMND_BBD_TOURN_STEP)
    event = "out"
    info(string.format("eliminated (%s round %d, place %d): the remaining rounds one at a time", run.place.stage,
      run.place.round, run.place.pos))
  elseif run.outcome == "champion" then
    event = "champion"
    info("CHAMPION (the tournament's own end; the Campaña's clear is not touched)")
  end
  save()
  return { event = event, show = true, rules = rules_of(run) }
end

-- after an elimination: the next round of the rest of the tournament, simulated and saved -> table { event =
-- "step" | "over" | "none" }
function BattleBayDeluxe.TournStep()
  local run = load()
  if not run or run.outcome ~= "out" then
    return { event = "none" }
  end
  local cfg = { goals = CFG.goals, weight = CFG.weight, pen_kick = CFG.pen_kick, pen_kicks = CFG.pen_kicks }
  local done = T.sim_step(run, cfg, mk)
  save()
  if not done then
    return { event = "over" }
  end
  info(string.format("simulated %s round %d%s", done.stage, done.round,
    run.stage == "over" and string.format(": champion %s", U.hex(run.teams[T.champion(run)] or 0)) or ""))
  return { event = "step" }
end

-- Enter on the bracket: the Campaña's fields kept, the tournament's match written (index 0) -> table { ok, rules }
function BattleBayDeluxe.TournPrepare()
  local run = load()
  if not run or run.outcome or T.opponent(run) == 0 then
    return { ok = false }
  end
  local s = session()
  local b = block_state(s)
  if not b then
    return { ok = false }
  end
  if Tn.before_match then
    local okb, e = pcall(Tn.before_match, run)
    if not okb then
      warn("before the match: " .. tostring(e))
    end
  end
  -- 1.61.0: the league team plays the order the player left in the team dock (league_squad.lua)
  local okl, el = pcall(LS.ensure, run.fmt == "league" and run.lineup or nil)
  if not okl then
    warn("league lineup: " .. tostring(el))
  end
  if not run.loaded then
    -- the Campaña's fields of this moment (a copy left from before is replaced)
    if not camp_snapshot_take(b) then
      return { ok = false }
    end
  end
  if not write_block(run) then
    camp_restore()
    return { ok = false }
  end
  run.loaded = true
  save()
  final_request(run)
  return { ok = true, rules = rules_of(run) }
end

-- the request did not start the match: the Campaña's fields back at once
function BattleBayDeluxe.TournUnload()
  local run = load()
  final_request(nil)
  if run then
    run.loaded = false
    save()
  end
  camp_restore()
  return true
end

function BattleBayDeluxe.TournAbandon()
  load()
  if RUN then
    RUN.loaded = false
    camp_restore()
    drop("abandoned")
  end
  ARMED = nil
  return true
end

function BattleBayDeluxe.TournClose()
  local run = load()
  if run and run.outcome then
    drop(run.outcome)
  end
  return true
end

-- the game-over telop after a lost / drawn tournament match (graft bbt_over.lua): true = the player is still in the run
-- (a group-stage match that does not knock him out; every league match: a league has no elimination), so the telop is
-- skipped; false = the defeat ends the run or the match is not a tournament match. The result is recorded on a copy of the run (the real record stays the top
-- menu's sync); the score is the game's own result (VRFW MatchResult; none seen: the telop stays).
function BattleBayDeluxe.TournStillIn()
  local run = load()
  if not run or not run.loaded or run.outcome then
    return false
  end
  local _, stage = T.pending(run)
  if stage == "league" then
    info("game over after a league match: a draw or a defeat is a league result, the telop is closed unseen")
    return true
  end
  if stage ~= "groups" then
    return false
  end
  if not (PLAYED and PLAYED.native) then
    info("game over after a group match with no result seen: the telop stays")
    return false
  end
  local gf, ga = PLAYED.gf, PLAYED.ga
  local trial = trial_record(run, gf, ga, PLAYED.outcome)
  local still_in = trial ~= nil and trial.outcome ~= "out"
  info(string.format("game over after a group match %d-%d: %s", gf, ga,
    still_in and "still in the run, the telop is skipped" or "eliminated, the telop stays"))
  return still_in
end

-- CMND_GET_BB_STADIUM_CAMPAIGN_INFO as a tournament shows it (the graft asks first): sub 1 = the matches played
-- (+1 between the end of a match and the sync, as the game answers on the result screens), sub 3, i = the rival of
-- the player's match i + 1 (0 = not known yet: the loading telop hides that emblem)
-- 1.5.47: sub 4 = the nodes of the loading telop's path (graft bbt_encount.lua), always answered: a tournament match
-- (the run holds the block) = the champion's match count of its format and size; any other campaign match = the
-- Campaña block's rival count
function Tn.path_len(run)
  if run and not run.outcome and run.loaded then
    local _, len = Tn.path_window(run)
    return len
  end
  return G.RIVALS
end

-- the part of the player's path the loading telop shows: (first match index - 1, node count). A knockout / group
-- tournament: the whole path. A league (up to 70 matches): a window of the Campaña's node count (G.RIVALS) around the
-- next match, so the beaten rivals before it and the rivals after it show as in the Campaña
function Tn.path_window(run)
  local total = T.run_matches(run)
  if run.fmt ~= "league" or total <= G.RIVALS then
    return 0, total
  end
  local len = G.RIVALS
  local first = math.max(0, math.min(run.k - floor(len / 2), total - len))
  return first, len
end

function BattleBayDeluxe.TournCampaignInfo(sub, i)
  local run = RUN_SLOT == current_slot() and RUN or load()
  if U.int(sub, -1) == 4 then
    return true, Tn.path_len(run)
  end
  if not run or run.outcome then
    return false
  end
  -- only while a tournament match borrows the block (else the block is the Campaña's: its own numbers)
  if not run.loaded then
    return false
  end
  sub = U.int(sub, -1)
  local first = Tn.path_window(run)
  if sub == 1 then
    return true, run.k - first + (PLAYED and 1 or 0)
  elseif sub == 3 then
    i = U.int(i, 0)
    return true, Tn.rival_of(run, first + i + 1)
  end
  return false
end

-- the rival of the player's match k (team hash, 0 = not known yet)
function Tn.rival_of(run, k)
  local n = 0
  local p = run.player
  local function walk(m)
    if m.a == p or m.b == p then
      n = n + 1
      if n == k then
        local o = m.a == p and m.b or m.a
        return o ~= 0 and run.teams[o] or 0
      end
    end
    return nil
  end
  if run.gm then
    for md = 1, run.mds or 3 do
      for _, gm in ipairs(run.gm) do
        for _, m in ipairs(gm) do
          if m.md == md then
            local r = walk(m)
            if r then
              return r
            end
          end
        end
      end
    end
  end
  for _, rd in ipairs(run.ko) do
    for _, m in ipairs(rd) do
      local r = walk(m)
      if r then
        return r
      end
    end
  end
  return 0
end

-- ------------------------------------------------------------------------------------------------ the bracket view

-- 1.8.0 (owner 2026-10-21: the bracket in the Victory Road look): each plate's team strip = the strip of its team's
-- emblem (team_config «emblem», the mods' teams included; lib/plate_colors.lua: generated from the game's emblem
-- pictures by research/scripts/bbd_bracket_art.py --plates); an emblem missing there (a newer game, another mod's):
-- a strip from its id
local EMBLEMS = nil
local function emblems()
  if EMBLEMS then
    return EMBLEMS
  end
  EMBLEMS = {}
  local ok, rows = team_rows()
  if ok and type(rows) == "table" then
    for _, r in ipairs(rows) do
      local id, em = r.id or r[1], r.emblem or r[7]
      if type(id) == "number" and type(em) == "number" then
        EMBLEMS[U.u32(id)] = U.u32(em)
      end
    end
  else
    warn("team table not readable: the bracket's plates keep the list plate")
  end
  return EMBLEMS
end

local function strip_of(team)
  local em = emblems()[U.u32(team or 0)]
  if not em or em == 0 then
    return nil
  end
  return PC.by_emblem[em] or (em % #PC.names) + 1
end

-- every team plate of a view (tree leaves, results rows, the old plates list) gets .strip
local function add_strips(v)
  local function one(p)
    if type(p) == "table" and (p.team or 0) ~= 0 then
      p.strip = strip_of(p.team)
    end
  end
  for _, list in ipairs({ v.leaves, v.plates }) do
    if type(list) == "table" then
      for _, p in pairs(list) do
        one(p)
      end
    end
  end
  if type(v.rows) == "table" then
    for _, r in pairs(v.rows) do
      if type(r) == "table" then
        one(r.a)
        one(r.b)
        one(r)   -- 1.48.0: a top scorers row (its team)
      end
    end
  end
  -- 1.48.0: the hub's next fixture
  if type(v.fixture) == "table" then
    one(v.fixture.home)
    one(v.fixture.away)
  end
  -- 1.52.0: the hub's dashboard rows (standings, top scorers, results, fixtures)
  for _, list in ipairs({ v.top, v.scorers, v.results, v.fixtures }) do
    if type(list) == "table" then
      for _, r in pairs(list) do
        one(r)
      end
    end
  end
  -- the league's standings rows (their plates are the bracket's team strips)
  if type(v.standings) == "table" then
    for _, r in pairs(v.standings) do
      one(r)
    end
  end
  return v
end

-- What the overlay draws (the graft resolves names / emblems from the team hashes and texts from text keys).
--   page 0 = the knockout tree, every round in one view (1.5.15; lib/tourney_view.lua), page 10 = the group tables
--   (1.5.54: every group on one page; a league: 10 + p = its standings, V.LEAGUE_ROWS teams a page), page 20 + p = the
--   results of the round just played.
function BattleBayDeluxe.TournView(page)
  local run = load()
  if not run then
    return { kind = "none" }
  end
  local v = V.build(run, U.int(page, -1))
  if type(v) == "table" then
    pcall(add_strips, v)
    -- 1.83.0: the tree page's final stadium (the bracket screen, VRFW_Bracket, draws it from the view)
    if v.kind == "tree" then
      local okf, map = pcall(final_stadium, run)
      if okf and type(map) == "string" and map ~= "" then
        v.final_stadium = { map = map, id = U.crc32(map) }
      end
    end
    -- 1.53.0: the squad page: the league team's members (slot, card, position) in slot order
    if v.kind == "squad" and (v.team or 0) ~= 0 and Tn.roster then
      pcall(LS.ensure, run.fmt == "league" and run.lineup or nil)
      local ok, rows = pcall(Tn.roster, v.team)
      local st = card_stats()
      for _, m in ipairs(ok and type(rows) == "table" and rows or {}) do
        local slot, card = U.int(m[1], 99), U.u32(m[2] or 0)
        if card ~= 0 then
          v.rows[#v.rows + 1] = { slot = slot, card = card, pos = st[card] and st[card].pos or 0 }
        end
      end
      table.sort(v.rows, function(a, b)
        return a.slot < b.slot
      end)
    end
    -- 1.52.0: the hub's squad panel: the player's team level (team_config «level», as the strength uses it)
    if (v.kind == "hub" or v.kind == "squad") and (v.team or 0) ~= 0 then
      local ok, lv = pcall(function()
        return levels()[U.u32(v.team)]
      end)
      v.level = ok and lv or false
    end
  end
  return v
end

-- 1.67.0: team -> its special tactics ({ id, … }, the team dock's «TÁCTICAS» slots: team_config SOCCER_TEAM_TACTICS
-- through SOCCER_TEAM_INFO_REF_TACTICS, the mods' teams included), read once
local TACTICS = nil
local function team_tactics(team)
  if TACTICS == nil then
    TACTICS = {}
    local ok, err = pcall(function()
      local key = VRFW.table.source("team/team")
      local info = VRFW.table.raw(key, "SOCCER_TEAM_INFO", { 1 })
      local refs = VRFW.table.raw(key, "SOCCER_TEAM_INFO_REF_TACTICS", { 1, 2 })
      local list = VRFW.table.raw(key, "SOCCER_TEAM_TACTICS", { 1 })
      if type(info) ~= "table" or type(refs) ~= "table" or type(list) ~= "table" or #refs ~= #info then
        error("team rows and tactics refs do not match")
      end
      local function scalar(v)
        if type(v) == "table" then
          return v[1]
        end
        return v
      end
      for i, t in ipairs(info) do
        local id = U.u32(tonumber(scalar(t[1])) or 0)
        local first, count = tonumber(scalar(refs[i][1])), tonumber(scalar(refs[i][2]))
        if id ~= 0 and TACTICS[id] == nil and first and count then
          local ids = {}
          for k = first + 1, first + count do
            local v = list[k] and tonumber(scalar(list[k][1]))
            if v and v ~= 0 then
              ids[#ids + 1] = U.u32(v)
            end
          end
          TACTICS[id] = ids
        end
      end
    end)
    if not ok then
      warn("team tactics not readable (" .. tostring(err) .. "): the league team's dock shows none")
    end
  end
  return TACTICS[U.u32(team or 0)] or {}
end

-- 1.61.0 (owner 2026-10-29): the hub's «Plantilla» opens the game's team dock for the league team (graft bb_tournament
-- BBT_HubTeamEditor over the VR-Framework's VRFW_TeamEditor). -> table { ok, why, kind, team, formation, level,
-- emblem, members = { { slot, param } … } }. kind: "copy" (a team kept as data: a temporary copy in the dock),
-- "own" (the Active team tile: the player's own dock), "draft" (the Draft team keeps its drafted order: no dock)
-- 1.67.0 (owner 2026-10-29: the dock showed the player's own coach, tactics, kit, emblem and stadium): the team's whole
-- record too: coach, kit, tactics, synergies (a team_config team has none) and its own stadium (its enjoy row's)
function BattleBayDeluxe.LeagueSquad()
  local run = load()
  if not run or run.outcome or run.fmt ~= "league" then
    return { ok = false, why = "no running league" }
  end
  local team = U.u32(run.player_team or 0)
  if team == 0 then
    return { ok = false, why = "the league has no player team" }
  end
  local kind = "copy"
  local okd, Draft = pcall(require, "draft")
  local oka, Active = pcall(require, "active_team")
  if okd and type(Draft) == "table" and Draft.team() == team then
    kind = "draft"
  elseif oka and type(Active) == "table" and Active.team() == team then
    kind = "own"
  end
  pcall(LS.ensure, run.lineup)
  local members, why = LS.members(team)
  if not members then
    return { ok = false, why = tostring(why) }
  end
  local okl, lv = pcall(function()
    return levels()[team]
  end)
  local okr, rec = pcall(LS.record, team)
  rec = okr and type(rec) == "table" and rec or {}
  local row = G.enjoy_row(team)
  local stadium = row and U.u32(U.get(U.struct("EnjoyRow", row), "stadium") or 0) or 0
  local emblem = (rec.emblem or 0) ~= 0 and rec.emblem or emblems()[team] or 0
  info(string.format("league squad of %s: coach %s, kit %s, emblem %s, %d tactic(s), stadium %s", U.hex(team),
    U.hex(rec.coach or 0), U.hex(rec.kit or 0), U.hex(emblem), #team_tactics(team), U.hex(stadium)))
  return { ok = true, kind = kind, team = team, formation = LS.formation(team), level = okl and lv or 1,
    emblem = emblem, kit = rec.kit or 0, coach = rec.coach or 0, tactics = team_tactics(team), synergies = {},
    stadium = stadium, members = members }
end

-- 1.61.0: the order the player left in the team dock: formation, "position:param,…" (dock positions 0-18 of the
-- team's players) -> table { ok, why, changed }. Kept in the run (run.lineup) and written over the team at once.
function BattleBayDeluxe.LeagueSquadSet(formation, placed)
  local run = load()
  if not run or run.outcome or run.fmt ~= "league" then
    return { ok = false, why = "no running league" }
  end
  local team = U.u32(run.player_team or 0)
  local list = {}
  for position, param in string.gmatch(tostring(placed or ""), "(%d+):(%d+)") do
    list[#list + 1] = { tonumber(position), tonumber(param) }
  end
  local slots = {}
  for _, m in ipairs(LS.members(team) or {}) do
    slots[#slots + 1] = m[1] .. ":" .. m[2]
  end
  info(string.format("league lineup from the dock for %s: formation %s, dock positions %s; the team's slots %s",
    U.hex(team), U.hex(formation or 0), tostring(placed), table.concat(slots, ",")))
  local order, why = LS.from_dock(team, list)
  if not order then
    warn("league lineup refused: " .. tostring(why))
    return { ok = false, why = tostring(why) }
  end
  local f = U.u32(formation or 0)
  if f == 0 then
    f = LS.formation(team)
  end
  local n, why2 = LS.apply(team, order, f)
  if n == nil then
    warn("league lineup not written: " .. tostring(why2))
    return { ok = false, why = tostring(why2) }
  end
  run.lineup = { team = team, formation = f, order = LS.encode(order) }
  save()
  info(string.format("league lineup of %s kept: %d rows changed, formation %s (%s)", U.hex(team), n, U.hex(f),
    run.lineup.order))
  return { ok = true, changed = n }
end

-- The team table's derived sets at script load (the boot thread), not in the first draw's frame (2026-10-13
-- loader.log: the Torneo's start, hook:Decide, took 270 ms on the game thread, ~190 ms of it the exclusions' read of
-- the team table). Only when the table is readable now; else each set is built by its first use, as before.
do
  local t0 = VRFW.now()
  local ok, rows = pcall(VRFW.table.rows, "team/team")
  if ok and type(rows) == "table" and #rows > 0 then
    TEAM_ROWS = rows
    pcall(levels)
    pcall(name_text, 0)
    pcall(exclusion_set)
    pcall(story_set)
    pcall(emblems)
    TEAM_ROWS = nil
    info(string.format("team sets (levels, names, exclusions, story teams, emblems) read at load in %d ms", VRFW.now() - t0))
  end
end

return Tn
