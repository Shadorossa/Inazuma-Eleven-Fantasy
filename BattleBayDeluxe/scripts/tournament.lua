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
-- | CMND_BBD_TOURN_INFO | -> table { active, armed, fmt, size, k, matches, stage, outcome, rules, campaign, defaults } |
-- | CMND_BBD_TOURN_ARM | fmt (0 knockout, 1 groups, -1 default), size (0 default), configured (1 = options confirmed) -> ok, why |
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

local Tn = {}

local floor = math.floor

local BLOB = "bb_tournament.json"
local RUN_VERSION = 1
local S_GAME, S_DIFF, S_PLAYER, S_RIVALS, S_INDEX, S_CLEARS = 0x2CA6E4, 0x2CA6E8, 0x2CA6EC, 0x2CA6F0, 0x2CA70C, 0x208

local function info(...)
  VRFW.log("tournament:", ...)
end
local function warn(...)
  VRFW.warn("tournament:", ...)
end

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
if not T.valid(CFG.fmt, CFG.size) then
  warn(string.format("config [tournament] format %q / teams %d not offered: knockout / 16", CFG.fmt, CFG.size))
  CFG.fmt, CFG.size = "knockout", 16
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
local ARMED = nil        -- { fmt, size, configured }: the next campaign start in the grid is a tournament
local PENDING = nil      -- 1.5.4: the run drawn at the grid's start (the native start refused), waiting for the difficulty
local PENDING_DIFF = nil -- the difficulty the grid's start sent (CMND_BBD_TOURN_START), when it came first
local FAILED = nil       -- 1.5.11: why the last start did not draw a run (TournInfo .failed, read once by the grid)
local POOL = nil         -- 1.5.15: the candidates of the last campaign draw (Tn.note_pool): caps the team counts offered
local PLAYED = nil       -- the tournament match that ended this session { index, rival, gf, ga } (match_end)
local LIVE = nil         -- the match being played { index, rival } (match_start)

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
      info(string.format("run of slot %d: %s / %d teams, %d match(es) played, stage %s", n, doc.fmt, doc.size, doc.k,
        tostring(doc.stage)))
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
    info(string.format("match %d/%d: rival %s (the Campaña's block borrowed)", run.k + 1,
      T.player_matches(run.fmt, run.size), U.hex(run.teams[opp])))
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
function Tn.note_pool(n)
  if type(n) == "number" and n >= 0 then
    POOL = n
  end
end

-- the team counts the options offer per format ({ knockout = {…}, groups = {…} }, smallest first). The minor teams
-- filter (1.5.16) only chooses which candidates play (the story / Chronicle ones first, the strongest of the rest
-- after them), so with it on or off the cap is the same: every candidate the pool has, plus the player
local function offered_sizes()
  local cap = POOL and (POOL + 1) or nil
  return { knockout = T.sizes("knockout", cap), groups = T.sizes("groups", cap) }
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
  -- 1.5.15 (owner: no byes): always a power of two; a pool too small for the chosen count plays the largest valid
  -- power of two it fills (the player + #cands teams)
  cands = excluded(cands)
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
    player_str = strength(player, ratings, med), opponents = opps, seeded = CFG.seeded, mk = mk })
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
  info(string.format("started: %s / %d teams, player %s, difficulty %d, first rival %s, seed %s:%s", run.fmt,
    run.size, U.hex(run.player_team), diff, U.hex(r1), U.hex(run.seed[1]), U.hex(run.seed[2])))
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

function Tn.first_rival(run)
  return run.teams[T.opponent(run)]
end

-- ------------------------------------------------------------------------------------------------ match events

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
    LIVE = { index = b.index, rival = b.rivals[b.index + 1], gf = 0, ga = 0 }
  end
  return nil
end)

-- the match table's score from the user's side: { team 0, team 1 } (an array: scripts.md §3.1, as VRFW's
-- match_score.lua reads it), nil when unknown. 1.5.24 (owner: a 4-0 win recorded 0-0): this file read
-- score.team0 / score.team1, which do not exist, so every match_end read 0-0.
local function user_score(m)
  if type(m) ~= "table" or type(m.score) ~= "table" then
    return nil
  end
  local s0 = tonumber(m.score[1] or m.score.team0)
  local s1 = tonumber(m.score[2] or m.score.team1)
  if s0 == nil or s1 == nil then
    return nil
  end
  if m.user_team == 1 then
    return s1, s0
  end
  return s0, s1
end

-- every goal of the match keeps the latest score (the match table may be reset by the time match_end fires)
VRFW.on("goal", function(ev)
  if LIVE then
    local f, a = user_score(ev.match)
    if f ~= nil then
      LIVE.gf, LIVE.ga = f, a
    end
  end
  return nil
end)

VRFW.on("match_end", function(ev)
  if not LIVE then
    return nil
  end
  local f, a = user_score(ev.match)
  local gf, ga = LIVE.gf, LIVE.ga
  if f ~= nil and f + a >= gf + ga then
    gf, ga = f, a
  end
  PLAYED = { index = LIVE.index, rival = LIVE.rival, gf = gf, ga = ga }
  info(string.format("match over: %d-%d (match end %s-%s, goals seen %d-%d)", gf, ga, tostring(f), tostring(a),
    LIVE.gf, LIVE.ga))
  LIVE = nil
  return nil
end)

-- ------------------------------------------------------------------------------------------------ the commands

local function rules_of(run)
  local m, stage = T.pending(run)
  if m and stage == "ko" then
    return CFG.rules
  end
  return ""
end

function BattleBayDeluxe.TournInfo()
  local run = load()
  local b = block_state(session())
  local t = {
    active = run ~= nil and not run.outcome, ended = run ~= nil and run.outcome ~= false, armed = ARMED ~= nil,
    configured = ARMED ~= nil and ARMED.configured == true, pending = PENDING ~= nil, failed = FAILED,
    campaign = false, -- 1.5.5: the Campaña and the Torneo are independent (true = see below)
    defaults = { fmt = CFG.fmt == "groups" and 1 or 0, size = CFG.size, filter = CFG.filter and 1 or 0 },
    sizes = offered_sizes(),
  }
  FAILED = nil
  if run then
    t.fmt, t.size, t.k, t.stage = run.fmt == "groups" and 1 or 0, run.size, run.k, run.stage
    t.matches = T.player_matches(run.fmt, run.size)
    t.outcome = run.outcome or ""
    t.rules = rules_of(run)
    local opp = T.opponent(run)
    t.rival = opp ~= 0 and run.teams[opp] or 0
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
    t.fmt, t.size = ARMED.fmt == "groups" and 1 or 0, ARMED.size
    t.filter = ARMED.filter and 1 or 0
  end
  -- what CMND_GET_BB_STADIUM_CAMPAIGN_INFO 1 / 3 answer during this run: the grafts keep it and use it when a
  -- later call finds the scripts busy
  if run and not run.outcome then
    t.loaded = run.loaded == true
    t.path = Tn.path_len(run)
    t.ci1 = run.k + (PLAYED and 1 or 0)
    t.ci3 = {}
    for k = 1, T.MAX_PLAYER_MATCHES do
      t.ci3[k] = Tn.rival_of(run, k)
    end
  end
  return t
end

-- fmt (0 knockout, 1 groups; -1 = the default), size (0 = the default), configured (1 = the options panel confirmed:
-- the grid's start is the tournament's), filter (1.5.16: 1 = filter minor teams, 0 = no, -1 / nil = the default)
function BattleBayDeluxe.TournArm(fmt, size, configured, filter)
  local f = U.int(fmt, -1)
  fmt = f == 1 and "groups" or (f == 0 and "knockout" or CFG.fmt)
  size = U.int(size, 0)
  if size == 0 then
    size = CFG.size
  end
  if not T.valid(fmt, size) then
    return false, "format not offered"
  end
  if load() and not RUN.outcome then
    return false, "a tournament is running"
  end
  local fl = U.int(filter, -1)
  ARMED = { fmt = fmt, size = size, configured = U.int(configured, 0) == 1, filter = fl == 1 or (fl == -1 and CFG.filter) }
  PENDING, PENDING_DIFF = nil, nil
  -- the Campaña's fields kept before the grid's start (if the game's own start ran anyway, the next sync puts the
  -- Campaña back): only when no tournament match holds the block
  if ARMED.configured and not (RUN and RUN.loaded) then
    local b = block_state(session())
    if b and camp_snapshot_take(b) then
      ARMED.snap = true
    end
  end
  info(string.format("armed: %s / %d teams%s%s", fmt, size, ARMED.filter and ", minor teams filtered" or "",
    ARMED.configured and " (options confirmed)" or ""))
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

-- the result of the player's match that borrowed the block: the rule engine's STATE (every match keeps its score;
-- the knockout rulebook's «winner + 1» goal after a shoot-out taken back), else this session's match_end score, else
-- the block (a win leaves index 1, a draw / defeat zeroes it: 1-0 / 0-1, logged); nil = not played (index 0 intact)
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
  -- 1.5.27 (owner log 21:22: «match over: 1-0 (… goals seen 1-0)», then «knockout match ended 0-0»): the rule
  -- engine's STATE answered 0-0 for a 1-0 win and won over this session's match_end score. The goals: the source
  -- that saw more of them (the match_end / goal events count real goals; STATE's are taken back by `fix` after a
  -- shoot-out); the shoot-out and extra time: STATE's.
  if st.ok then
    local r = fix({ gf = st.gf, ga = st.ga, pf = st.pf, pa = st.pa, et = st.et })
    if PLAYED and PLAYED.gf + PLAYED.ga > r.gf + r.ga then
      info(string.format("result: STATE %d-%d, the match's own goals %d-%d: the goals taken from the match", r.gf, r.ga,
        PLAYED.gf, PLAYED.ga))
      r.gf, r.ga = PLAYED.gf, PLAYED.ga
    end
    return r
  end
  if PLAYED then
    return { gf = PLAYED.gf, ga = PLAYED.ga, pf = 0, pa = 0, et = false }
  end
  if mine and b.index == 1 then
    warn("no match score (rule engine / match_end): the win recorded 1-0")
    return { gf = 1, ga = 0, pf = 0, pa = 0, et = false }
  end
  warn("no match score (rule engine / match_end): the draw / defeat recorded 0-1")
  return { gf = 0, ga = 1, pf = 0, pa = 0, et = false }
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
  PLAYED = nil
  run.loaded = false
  camp_restore()
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
  local done, why = T.record(run, cfg, mk, res.gf, res.ga, res.pf, res.pa, res.et)
  if not done then
    warn("result not recorded: " .. tostring(why))
    return { event = "none", show = false }
  end
  info(string.format("match %d: %d-%d%s; %s round %d complete", run.k, res.gf, res.ga,
    (res.pf + res.pa > 0) and string.format(" (pen. %d-%d)", res.pf, res.pa) or "", done.stage, done.round))
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
  return { ok = true, rules = rules_of(run) }
end

-- the request did not start the match: the Campaña's fields back at once
function BattleBayDeluxe.TournUnload()
  local run = load()
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

-- CMND_GET_BB_STADIUM_CAMPAIGN_INFO as a tournament shows it (the graft asks first): sub 1 = the matches played
-- (+1 between the end of a match and the sync, as the game answers on the result screens), sub 3, i = the rival of
-- the player's match i + 1 (0 = not known yet: the loading telop hides that emblem)
-- 1.5.47: sub 4 = the nodes of the loading telop's path (graft bbt_encount.lua), always answered: a tournament match
-- (the run holds the block) = the champion's match count of its format and size; any other campaign match = the
-- Campaña block's rival count
function Tn.path_len(run)
  if run and not run.outcome and run.loaded then
    return T.player_matches(run.fmt, run.size)
  end
  return G.RIVALS
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
  if sub == 1 then
    return true, run.k + (PLAYED and 1 or 0)
  elseif sub == 3 then
    i = U.int(i, 0)
    return true, Tn.rival_of(run, i + 1)
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
    for md = 1, 3 do
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

-- What the overlay draws (the graft resolves names / emblems from the team hashes and texts from text keys).
--   page 0 = the knockout tree, every round in one view (1.5.15; lib/tourney_view.lua), page 10 = the group tables
--   (1.5.54: every group on one page), page 20 + p = the results of the round just played (8 matches per page).
function BattleBayDeluxe.TournView(page)
  local run = load()
  if not run then
    return { kind = "none" }
  end
  return V.build(run, U.int(page, -1))
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
    TEAM_ROWS = nil
    info(string.format("team sets (levels, names, exclusions, story teams) read at load in %d ms", VRFW.now() - t0))
  end
end

return Tn
