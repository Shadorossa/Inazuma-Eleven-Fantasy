-- Career stats: the per-slot store (blob career.json of mod utilities, the same JSON utilities.dll wrote) and the
-- per-match rules (assists, man of the match, mode groups, exclusions). Pure: no game access. Used by career.lua.

local S = {}

S.BLOB = "career.json"
-- 2: per-mode «Jugador del partido» and saves, the first MVP date, the best match (goals / saves); a version 1 file
-- is migrated on read (S.decode): what can be derived from its numbers, unknown dates -1 (the page leaves them out)
S.FILE_VERSION = 2
S.UNKNOWN_DAY = -1
S.MATCH_TYPE_TRAINING = 3
S.CHAIN_LEN = 8
-- mode groups of the per-mode split (the table of the plate page TRAYECTORIA); group 10 + i of CMND_UTIL_CAREER_EX.
-- "battle_bay" = a free match (play mode 1) while the framework's mode context battle_bay holds (career.lua).
S.MODES = { "story", "chronicle", "free", "vroad", "kizuna", "battle_bay" }
S.MODE_FREE = 3 -- 1-based index of "free"
S.MODE_BATTLE_BAY = 6

-- Mode group (1-based index into S.MODES) of the engine's play-mode byte ([[g_gameRoot]+0x69C8]+0x2CAC6F:
-- 1 VS / other, 2 story, 3 Kizuna town, 4 Chronicle, 5 Victory Road, 6 story).
function S.mode_index(play_mode)
  if play_mode == 2 or play_mode == 6 then return 1 end
  if play_mode == 4 then return 2 end
  if play_mode == 5 then return 4 end
  if play_mode == 3 then return 5 end
  return S.MODE_FREE
end

-- Why a match is not counted (nil = counted).
function S.exclusion(match_type, half_len, user_team, reserved_slot)
  if reserved_slot then return "reserved slot of a mod's own mode (that mode keeps its own counters)" end
  if user_team > 1 then return "no user team (spectator / CPU vs CPU)" end
  if match_type == S.MATCH_TYPE_TRAINING then return "training drill (engine match type 3)" end
  if half_len == 0 then return "no match clock (drill)" end
  return nil
end

-- Signing source shown on the plate from the save's addPartySource (record +0x0E): 0 unknown, 1 Fichaje,
-- 2 Historia, 3 Avatar, 4 INAROGUE.
function S.source_kind(src)
  if src == 4 then return 1 end
  if src == 2 or src == 6 then return 2 end
  if src == 5 then return 3 end
  if src == 10 then return 4 end
  return 0
end

-- 1 GK, 2 FW, 3 MF, 4 DF: a player who kept goal in at least half of his matches counts as a keeper; else
-- chara_param col 3 (unknown: FW).
function S.role(main_position, matches, gk_matches)
  if matches > 0 and gk_matches * 2 >= matches then return 1 end
  if main_position and main_position >= 1 and main_position <= 4 then return main_position end
  return 2
end

-- The engine's on-pitch test of a team member (0xEB2900).
function S.member_on_pitch(position, on_pitch_count, flags)
  return bit32.band(flags, 0x800) == 0 and bit32.band(flags, 0x8) == 0 and position < on_pitch_count
end

-- ------------------------------------------------------------------------------------------- ball owner chain

-- The last ball owners of the current attack ({actor, team}), oldest first; a new owner is pushed only when it
-- differs from the last one; 0 (loose ball) is ignored.
function S.chain_new() return {} end

function S.chain_push(c, actor, team)
  if actor == 0 or team > 1 then return false end
  local n = #c
  if n > 0 and c[n][1] == actor then return false end
  if n == S.CHAIN_LEN then table.remove(c, 1) end
  c[#c + 1] = { actor, team }
  return true
end

-- Assist of a goal of `team` scored by `scorer`: the owner right before the scorer's own possession when he is a
-- team-mate (the last owner when the scorer never showed); an owner after the scorer = no assist.
function S.chain_assist(c, scorer, team)
  local n = #c
  local seen = false
  for i = 1, n do if c[i][1] == scorer then seen = true end end
  if seen and c[n][1] ~= scorer then return nil end
  local k = n
  while k > 0 and c[k][1] == scorer do k = k - 1 end
  if k > 0 and c[k][2] == team and c[k][1] ~= scorer then return c[k][1] end
  return nil
end

-- ------------------------------------------------------------------------------------------- per-actor records

-- Record deltas (per actor slot) to per-character numbers: every sample adds the growth since the previous sample
-- to the character the actor had then; a value that went down starts again from 0.
function S.rec_new() return { slots = {}, per = {} } end

local function per_of(r, chara)
  local e = r.per[chara]
  if not e then
    e = { shots = 0, steals = 0, saves = 0, skill_uses = 0, hiper_uses = 0, conceded = 0, keeper = false }
    r.per[chara] = e
  end
  return e
end
S.per_of = per_of

function S.rec_sample(r, actor, chara, vals)
  local prev = r.slots[actor]
  local prev_chara, last = chara, { 0, 0, 0, 0 }
  if prev then prev_chara, last = prev[1], prev[2] end
  local d = {}
  local any = false
  for k = 1, 4 do
    if vals[k] >= last[k] then d[k] = vals[k] - last[k] else d[k] = vals[k] end
    if d[k] > 0 then any = true end
  end
  if prev_chara ~= 0 and any then
    local e = per_of(r, prev_chara)
    e.shots = e.shots + d[1]
    e.steals = e.steals + d[2]
    e.saves = e.saves + d[3]
    e.skill_uses = e.skill_uses + d[4]
  end
  r.slots[actor] = { chara, vals }
end

-- ------------------------------------------------------------------------------------------- match summary

-- (goals, assists) per owned player: { [owner] = {g, a} }.
function S.contributions(goals)
  local m = {}
  for _, g in ipairs(goals) do
    if g.scorer then
      m[g.scorer] = m[g.scorer] or { 0, 0 }
      m[g.scorer][1] = m[g.scorer][1] + 1
    end
    if g.assist and g.assist ~= g.scorer then
      m[g.assist] = m[g.assist] or { 0, 0 }
      m[g.assist][2] = m[g.assist][2] + 1
    end
  end
  return m
end

-- «Jugador del partido»: the owned player with the most points (goal 2, assist 1); a tie gives nobody. The players
-- are visited in ascending handle order (as the Rust's BTreeMap).
function S.man_of_the_match(contrib)
  local keys = {}
  for p in pairs(contrib) do keys[#keys + 1] = p end
  table.sort(keys)
  local best, best_pts, tie = nil, nil, false
  for _, p in ipairs(keys) do
    local pts = 2 * contrib[p][1] + contrib[p][2]
    if pts > 0 then
      if best_pts and pts < best_pts then
        -- lower
      elseif best_pts and pts == best_pts then
        tie = true
      else
        best, best_pts, tie = p, pts, false
      end
    end
  end
  if tie then return nil end
  return best
end

-- ------------------------------------------------------------------------------------------- club totals

-- The user's team over every counted match since the club totals started (`since`, yyyymmdd; 0 = no match yet):
-- results, goals for / against, clean sheets, the biggest win (largest margin, then most goals; its day) and the
-- current / best runs of wins and of matches without a loss. The key `club` of the slot file (a file without it
-- reads as empty: the totals start with the next counted match).
local CLUB_FIELDS = { "since", "matches", "wins", "draws", "losses", "goals_for", "goals_against", "clean_sheets",
  "best_win_for", "best_win_against", "best_win_day", "win_run", "best_win_run", "unbeaten_run", "best_unbeaten_run" }

function S.club_new()
  local c = {}
  for _, k in ipairs(CLUB_FIELDS) do c[k] = 0 end
  return c
end

local function club_read(x)
  local c = S.club_new()
  if type(x) == "table" then
    for _, k in ipairs(CLUB_FIELDS) do c[k] = tonumber(x[k]) or 0 end
  end
  return c
end

-- One counted match of the user's team (outcome "win" / "draw" / "loss", goals for / against, its day).
function S.club_apply(c, outcome, gf, ga, today)
  if c.since == 0 then c.since = today end
  c.matches = c.matches + 1
  c.goals_for = c.goals_for + gf
  c.goals_against = c.goals_against + ga
  if ga == 0 then c.clean_sheets = c.clean_sheets + 1 end
  if outcome == "win" then
    c.wins = c.wins + 1
    c.win_run = c.win_run + 1
    local margin, best = gf - ga, c.best_win_for - c.best_win_against
    if c.best_win_day == 0 or margin > best or (margin == best and gf > c.best_win_for) then
      c.best_win_for, c.best_win_against, c.best_win_day = gf, ga, today
    end
  else
    c.win_run = 0
  end
  if outcome == "draw" then c.draws = c.draws + 1 end
  if outcome == "loss" then
    c.losses = c.losses + 1
    c.unbeaten_run = 0
  else
    c.unbeaten_run = c.unbeaten_run + 1
  end
  if c.win_run > c.best_win_run then c.best_win_run = c.win_run end
  if c.unbeaten_run > c.best_unbeaten_run then c.best_unbeaten_run = c.unbeaten_run end
end

-- ------------------------------------------------------------------------------------------- store

function S.key(hdl) return string.format("%08X", hdl) end

function S.new_file(slot)
  return { version = S.FILE_VERSION, slot = slot, watermark = nil, since = 0, recorded = 0, players = {}, club = S.club_new() }
end

local function fresh_stats(param, order, signed)
  return {
    param = param, order = order, signed = signed,
    matches = 0, wins = 0, draws = 0, losses = 0, goals = 0, assists = 0, mvp = 0,
    shots = 0, steals = 0, saves = 0, conceded = 0, clean_sheets = 0, gk_matches = 0,
    skill_uses = 0, hiper_uses = 0, first_goal = 0, first_mvp = 0,
    best_goals = 0, best_goals_day = 0, best_goals_exact = 1, best_saves = 0, best_saves_day = 0, best_saves_exact = 1,
    last = { day = 0, result = 0, gf = 0, ga = 0, goals = 0, assists = 0 },
    modes = {},
  }
end

local function fresh_mode()
  return { matches = 0, wins = 0, draws = 0, losses = 0, goals = 0, assists = 0, mvp = 0, saves = 0 }
end

local NUM_FIELDS = { "param", "order", "signed", "matches", "wins", "draws", "losses", "goals", "assists", "mvp",
  "shots", "steals", "saves", "conceded", "clean_sheets", "gk_matches", "skill_uses", "hiper_uses", "first_goal" }
local NUM_FIELDS_V2 = { "first_mvp", "best_goals", "best_goals_day", "best_goals_exact", "best_saves", "best_saves_day",
  "best_saves_exact" }

-- Version 1 -> 2 of one record: the first goal / first MVP dates and the best match from what the counters tell.
-- One match only: its numbers are the best and its day is every first. All goals in the last match: that match is
-- the best. Anything else: the best is at least the last match's (shown only once exact), the dates are unknown.
local function migrate_v1(d)
  local one = d.matches == 1 and d.last.day > 0
  if d.goals > 0 and d.first_goal == 0 then d.first_goal = one and d.last.day or S.UNKNOWN_DAY end
  if d.mvp > 0 then d.first_mvp = one and d.last.day or S.UNKNOWN_DAY end
  if d.goals == 0 then
    d.best_goals, d.best_goals_day, d.best_goals_exact = 0, 0, 1
  elseif one or d.goals == d.last.goals then
    d.best_goals, d.best_goals_day, d.best_goals_exact = d.goals, d.last.day, 1
  else
    d.best_goals, d.best_goals_day, d.best_goals_exact = d.last.goals, d.last.day, 0
  end
  if d.saves == 0 then
    d.best_saves, d.best_saves_day, d.best_saves_exact = 0, 0, 1
  elseif one then
    d.best_saves, d.best_saves_day, d.best_saves_exact = d.saves, d.last.day, 1
  else
    d.best_saves, d.best_saves_day, d.best_saves_exact = 0, 0, 0
  end
end

-- A record read from JSON with every field present (a version 1 file: migrate_v1; per-mode MVP / saves of the
-- matches before version 2 are unknown and stay 0: the page's total row has the career numbers).
local function normalize(s, version)
  local d = fresh_stats(0, 0, 0)
  for _, k in ipairs(NUM_FIELDS) do d[k] = tonumber(s[k]) or 0 end
  if type(s.last) == "table" then
    for k in pairs(d.last) do d.last[k] = tonumber(s.last[k]) or 0 end
  end
  if type(s.modes) == "table" then
    for m, x in pairs(s.modes) do
      if type(x) == "table" then
        local e = fresh_mode()
        for k in pairs(e) do e[k] = tonumber(x[k]) or 0 end
        d.modes[m] = e
      end
    end
  end
  if version < 2 then
    migrate_v1(d)
  else
    for _, k in ipairs(NUM_FIELDS_V2) do d[k] = tonumber(s[k]) or d[k] end
  end
  return d
end

-- The slot's file from the blob's JSON text (nil text = empty). Returns file or nil, error.
function S.decode(text, slot)
  if not text then return S.new_file(slot) end
  local j, err = VRFW.json.decode(text)
  if type(j) ~= "table" then return nil, err or "not a JSON object" end
  local f = S.new_file(slot)
  local version = tonumber(j.version) or 1
  f.watermark = tonumber(j.watermark)
  f.since = tonumber(j.since) or 0
  f.recorded = tonumber(j.recorded) or 0
  f.club = club_read(j.club)
  if type(j.players) == "table" then
    for k, s in pairs(j.players) do
      if type(s) == "table" then f.players[k] = normalize(s, version) end
    end
  end
  -- the migrated file is written back with the next change (f.version = the current one)
  f.migrated_from = version < S.FILE_VERSION and version or nil
  return f
end

-- JSON text of the file (the keys utilities.dll wrote; `watermark` null until set).
function S.encode(f)
  local players = {}
  for k, s in pairs(f.players) do players[k] = s end
  local t = { version = f.version, slot = f.slot, since = f.since, recorded = f.recorded, players = players,
    club = f.club or S.club_new() }
  if f.watermark then t.watermark = f.watermark end
  -- an empty Lua table is an object for the encoder; `watermark` absent = null for the reader
  return VRFW.json.encode(t, true)
end

function S.is_old(f, order)
  return f.watermark == nil or order <= f.watermark
end

function S.set_watermark(f, max_order, today)
  if f.watermark ~= nil then return false end
  f.watermark = max_order
  f.since = today
  return true
end

function S.get(f, hdl, param, order)
  local s = f.players[S.key(hdl)]
  if s and s.param == param and s.order == order then return s end
  return nil
end

local function entry(f, hdl, param, order, today)
  local signed = today
  if S.is_old(f, order) then signed = 0 end
  local k = S.key(hdl)
  local e = f.players[k]
  if not e or e.param ~= param or e.order ~= order then
    e = fresh_stats(param, order, signed)
    f.players[k] = e
  end
  return e
end

-- A saved character seen by a scan: a player signed after the watermark gets his date now. True = record made.
function S.observe(f, hdl, param, order, today)
  if hdl == 0 or f.watermark == nil or S.is_old(f, order) or S.get(f, hdl, param, order) then return false end
  entry(f, hdl, param, order, today)
  return true
end

-- Count a finished match. m = { outcome ("win"/"draw"/"loss"), gf, ga, players = {[owner]=true}, goals = {{scorer,
-- assist}}, mode (1-based), per = {[owner] = numbers} }; ident(owner) -> param, order (nil = skipped).
function S.apply_match(f, m, ident, today)
  local contrib = S.contributions(m.goals)
  local mvp = S.man_of_the_match(contrib)
  local credited = {}
  for p in pairs(m.players) do credited[p] = true end
  for _, g in ipairs(m.goals) do
    if g.scorer then credited[g.scorer] = true end
    if g.assist then credited[g.assist] = true end
  end
  local code = ({ win = 1, draw = 2, loss = 3 })[m.outcome]
  local n = 0
  for p in pairs(credited) do
    local param, order = ident(p)
    if param then
      local e = entry(f, p, param, order, today)
      e.matches = e.matches + 1
      if m.outcome == "win" then e.wins = e.wins + 1 elseif m.outcome == "draw" then e.draws = e.draws + 1 else e.losses = e.losses + 1 end
      local c = contrib[p] or { 0, 0 }
      local g, a = c[1], c[2]
      e.goals = e.goals + g
      e.assists = e.assists + a
      if mvp == p then
        e.mvp = e.mvp + 1
        if e.first_mvp == 0 then e.first_mvp = today end
      end
      if g > 0 and e.first_goal == 0 then e.first_goal = today end
      if g > e.best_goals then e.best_goals, e.best_goals_day = g, today end
      local pm = m.per[p]
      if pm then
        e.shots = e.shots + pm.shots
        e.steals = e.steals + pm.steals
        e.saves = e.saves + pm.saves
        e.conceded = e.conceded + pm.conceded
        e.skill_uses = e.skill_uses + pm.skill_uses
        e.hiper_uses = e.hiper_uses + pm.hiper_uses
        if pm.keeper then e.gk_matches = e.gk_matches + 1 end
        if pm.saves > e.best_saves then e.best_saves, e.best_saves_day = pm.saves, today end
      end
      if m.ga == 0 then e.clean_sheets = e.clean_sheets + 1 end
      e.last = { day = today, result = code, gf = m.gf, ga = m.ga, goals = g, assists = a }
      local name = S.MODES[math.min(m.mode, #S.MODES)]
      local ms = e.modes[name]
      if not ms then
        ms = fresh_mode()
        e.modes[name] = ms
      end
      ms.matches = ms.matches + 1
      if m.outcome == "win" then ms.wins = ms.wins + 1 elseif m.outcome == "draw" then ms.draws = ms.draws + 1 else ms.losses = ms.losses + 1 end
      ms.goals = ms.goals + g
      ms.assists = ms.assists + a
      if mvp == p then ms.mvp = ms.mvp + 1 end
      if pm then ms.saves = ms.saves + pm.saves end
      n = n + 1
    end
  end
  f.recorded = f.recorded + 1
  f.club = f.club or S.club_new()
  S.club_apply(f.club, m.outcome, m.gf, m.ga, today)
  return n, mvp, contrib
end

-- What the plate shows: signed, before, matches, wins, draws, losses, goals, assists, mvp.
function S.view(f, hdl, param, order)
  local before = 0
  if S.is_old(f, order) then before = f.since end
  local s = S.get(f, hdl, param, order)
  if not s then return { signed = 0, before = before, matches = 0, wins = 0, draws = 0, losses = 0, goals = 0, assists = 0, mvp = 0 } end
  local b = 0
  if s.signed == 0 then b = f.since end
  return { signed = s.signed, before = b, matches = s.matches, wins = s.wins, draws = s.draws, losses = s.losses,
    goals = s.goals, assists = s.assists, mvp = s.mvp }
end

return S
