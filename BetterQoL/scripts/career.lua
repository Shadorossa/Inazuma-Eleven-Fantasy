-- Career stats of Utilities (docs/game/mechanics/player-career-stats.md): per player and save slot, the signing date,
-- matches, wins / draws / losses, goals, assists, «Jugador del partido», shots, balls won, saves, clean sheets, the
-- last match, the first goal / first MVP dates, the best match and a per-mode split, shown on the player plate's page
-- «TRAYECTORIA» (graft util_career_page).
--
-- Fed by the match HUD (graft util_career_match): CMND_BETTERQOL_CAREER_MATCH 1 kick-off (soccer_menu OnInit), 0 every
-- frame (soccer_menu Step), 2 half time, 3 full-time result. Each call reads the engine's own match data (no hook):
-- the ball owner (assists), the score bytes and the per-team goal list (the scorer's actor), and every 30 frames the
-- user's team record (members on the pitch) and the per-actor match records. A match is recorded once, on the
-- full-time result (3) or when the scene reaches the result states 6 / 7. Match copies are mapped to their saved
-- owner with VRFW.chara.owner (strong identity match). The store (blob career.json per slot) is staged with the
-- game's save (VRFW.save.blob_stage) when the slot service runs, else written at once. A match in a slot a mod
-- reserved for its own mode is not recorded.
--
-- Declarations: content\game\career.toml. Was utilities.dll's career module (removed 2026-10-10); the exports other
-- plugins called (utilities_career_on_match / _moves / _reload) are gone: the move-use groups answer zeros.

local S = require "lib/career_store"
local Actors = require "VRFW/lib/actors"

BetterQoL = BetterQoL or {}
BetterQoL.Career = BetterQoL.Career or {}

-- ---------------------------------------------------------------------------------------- data layout

-- The match data's offsets and record sizes, from the game profile (VRFW game\<build>\structs.toml, globals.toml):
-- match info (team records, goal lists, per-actor records, score, user's team), the team members, the ball owner and
-- the play mode. Read once; a name the running build's profile lacks turns the tracking off.
local PROFILE_NAMES = {
  info_type = "MatchInfo.MatchType", info_half_length = "MatchInfo.HalfLength", info_teams = "MatchInfo.Teams",
  info_goal_lists = "MatchInfo.GoalLists", info_actor_records = "MatchInfo.ActorRecords",
  info_score = "MatchInfo.Score", info_user_team = "MatchInfo.UserTeam",
  team_size = "MatchTeam", team_members = "MatchTeam.Members", team_on_pitch = "MatchTeam.OnPitch",
  member_slots = "Match.TeamMemberSlots", member_size = "MatchTeamMember", member_chara = "MatchTeamMember.Chara",
  member_position = "MatchTeamMember.Position", member_flags = "MatchTeamMember.Flags",
  goal_list_size = "MatchGoalList", goal_list_goals = "MatchGoalList.Goals", goals_max = "Match.GoalListMax",
  goal_size = "MatchGoal", goal_actor = "MatchGoal.Actor",
  record_size = "MatchActorRecord", record_shots = "MatchActorRecord.Shots",
  record_balls_won = "MatchActorRecord.BallsWon", record_keeper_blocks = "MatchActorRecord.KeeperBlocks",
  record_technique_uses = "MatchActorRecord.TechniqueUses",
  ball_owner = "Ball.Owner", ball_owner_team = "Ball.OwnerTeam", play_mode = "Game.PlayMode",
}
local P = nil         -- the resolved numbers
local P_MISSING = nil -- the first name that did not resolve
-- the per-actor record fields the tracker samples, in its order: shots, balls won, keeper blocks, technique uses
local RECORD_FIELDS = nil
local STATE_RESULT_EVENT, STATE_RESULT_MENU = 6, 7
local PITCH_EVERY = 30
local SCAN_EVERY_MS = 60000

-- ---------------------------------------------------------------------------------------- helpers

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local hex = require("VRFW/lib/ids").hex

require "VRFW/lib/basics"
require "VRFW/lib/save_doc"
local info, warn = VRFW.logger("career")

-- the profile's numbers (nil when one is missing: warned once)
local function profile()
  if P ~= nil or P_MISSING ~= nil then return P end
  local out = {}
  for key, name in pairs(PROFILE_NAMES) do
    local ok, v = pcall(VRFW.game.field, name)
    if not ok or type(v) ~= "number" then
      P_MISSING = name
      warn("the game profile has no " .. name .. ": matches are not recorded")
      return nil
    end
    out[key] = v
  end
  P = out
  RECORD_FIELDS = { P.record_shots, P.record_balls_won, P.record_keeper_blocks, P.record_technique_uses }
  return P
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok then return p end
  return nil
end

local function match_info()
  local m = global("match_info")
  if m and m >= 0x10000 then return m end
  return nil
end

local function soccer_state()
  local ok, m = pcall(VRFW.match)
  if ok and m then return m.soccer_state or 0 end
  return 0
end

local function result_state()
  local st = soccer_state()
  return st == STATE_RESULT_EVENT or st == STATE_RESULT_MENU
end

-- scene states of a match under way (in play, restarts, goal, half time, duels, zone, out of play, menu, replay)
local function live_state(st)
  return (st >= 9 and st <= 17) or st == 20 or st == 26
end

-- (character handle, team) an actor plays
local function actor_chara(hdl)
  local a = Actors.of(hdl, { chara = true })
  if not a or a.chara == 0 then return nil end
  return a.chara, a.team
end

local function current_slot() return VRFW.slots.active() end

local function is_reserved(slot) return VRFW.slots.reserved(slot) end

-- the saved character behind a handle (itself, or the owner of a match copy)
local function owner(hdl)
  if not hdl or hdl == 0 then return nil end
  local ok, o = pcall(VRFW.chara.owner, hdl)
  if ok then return o end
  return nil
end

-- param, get_order of a saved character
local function ident(hdl)
  local ok, r = pcall(VRFW.chara.record, hdl)
  if ok and r then return r.param, r.get_order, r end
  return nil
end

-- ---------------------------------------------------------------------------------------- store

-- the career file of a slot: read again after a load, copy, delete, new game or reset of that slot (the slot events,
-- which drop the numbers the game never saved); staged with the game's next save of the slot
local DOC = VRFW.save.doc(S.BLOB, {
  text = true,
  decode = S.decode,
  encode = S.encode,
  default = S.new_file,
  stage = true,
  log = "career",
  loaded = function(f, slot, state)
    if state == "bad" then return end
    local n = 0
    for _ in pairs(f.players) do n = n + 1 end
    local wm = "not set yet"
    if f.watermark then wm = "get_order " .. f.watermark .. " (since " .. f.since .. ")" end
    info("slot " .. slot .. ": " .. n .. " players, " .. f.recorded .. " matches recorded, watermark " .. wm)
    if f.club_reconciled then
      local c = f.club
      info("slot " .. slot .. ": club totals taken from the players' records (" .. c.matches .. " match(es), "
        .. c.wins .. "-" .. c.draws .. "-" .. c.losses .. ", goals " .. c.goals_for .. "-" .. c.goals_against
        .. ", since " .. c.since .. "); written with the next change")
    end
    if f.migrated_from then
      info("slot " .. slot .. ": " .. S.BLOB .. " version " .. f.migrated_from .. " read as version " .. S.FILE_VERSION
        .. " (first goal / first MVP dates and best matches derived where the numbers allow; written with the next change)")
    end
  end,
})

local store = nil -- the active slot's file
local last_scan = nil -- VRFW.now() of the last signing-date scan of this store

-- The store of the active slot (nil in a mod's reserved slot); read again when the slot changed.
local function ensure_store()
  local slot = current_slot()
  if is_reserved(slot) then return nil end
  local f = DOC:get(slot)
  if f ~= store then
    if store and store.dirty and store.slot ~= slot then warn("slot " .. store.slot .. " -> " .. slot .. ": dropping numbers not saved by the game") end
    store = f
    last_scan = nil
  end
  return store
end

-- Stage the store with the game's next save of its slot (written at once without the slot service).
local function commit(why)
  if not store or not store.dirty then return end
  local ok, where = DOC:write(store, store.slot)
  if ok then
    store.dirty = false
  else
    VRFW.error("career: cannot write slot " .. store.slot .. ": " .. tostring(where) .. " (" .. why .. ")")
  end
end

-- Watermark (first time) and signing dates of the players signed since the last scan.
local function scan_and_date(force)
  local now = VRFW.now()
  if not force and last_scan and now - last_scan < SCAN_EVERY_MS then return end
  local st = ensure_store()
  if not st then return end
  local ok, recs = pcall(VRFW.chara.saved)
  if not ok or not recs or #recs == 0 then return end -- no save loaded yet (title screen): later
  last_scan = now
  local day = VRFW.ui.today()
  local max = 0
  for _, r in ipairs(recs) do if r.get_order > max then max = r.get_order end end
  if S.set_watermark(st, max, day) then
    st.dirty = true
    info("slot " .. st.slot .. ": watermark get_order " .. max .. " (" .. #recs .. " saved characters): they show «Fichado antes del " .. day .. "»; players signed later are dated when they are first seen")
  end
  local new = {}
  for _, r in ipairs(recs) do
    if S.observe(st, r.handle, r.param, r.get_order, day) then new[#new + 1] = hex(r.handle) end
  end
  if #new > 0 then
    st.dirty = true
    info("slot " .. st.slot .. ": " .. #new .. " new player(s) dated " .. day .. ": " .. table.concat(new, " "))
  end
  commit("signing dates")
end

-- The main position of a card (chara_param `main_position`), from the framework's shared character index
-- (VRFW.chara.card, docs/framework/chara-index.md): no chara_param read in this VM (it cost ~160 ms on the first
-- plate page). Remembered per card.
local positions = {}
local index_warned = false
local function position_of(param)
  if not param then return nil end
  local p = positions[param]
  if p ~= nil then return p or nil end
  local ok, c = pcall(VRFW.chara.card, param)
  if not ok then
    if not index_warned then
      index_warned = true
      warn("character index not readable (" .. tostring(c) .. "): players show the forward row of the page")
    end
    return nil
  end
  p = c and c.position
  positions[param] = p or false
  return p
end

-- ---------------------------------------------------------------------------------------- match tracking

local t = { phase = "idle", match_no = 0 }

local function new_tracker(match_no)
  return {
    phase = "idle", match_no = match_no, excluded = nil, slot = 0, user = 0xFF, mi = 0, ticks = 0,
    chain = S.chain_new(), last_owner = 0, seen = { 0, 0 }, goals = {}, own_goals_for = 0,
    pitch = {}, logged_pitch = false, mode = S.MODE_FREE, rec = S.rec_new(), keeper_now = 0,
  }
end

local function score(mi, team) return rd("u8", mi + P.info_score + team) or 0 end

local function begin(why)
  local mi = match_info()
  if not mi or not profile() then
    t.phase = "idle"
    return
  end
  if t.phase == "tracking" then info("match #" .. t.match_no .. " dropped: a new match started before its result (retry / quit)") end
  t = new_tracker(t.match_no + 1)
  t.phase = "tracking"
  t.mi = mi
  t.user = rd("u8", mi + P.info_user_team) or 0xFF
  local typ = rd("u8", mi + P.info_type) or 0
  local half = rd("u16", mi + P.info_half_length) or 0
  local slot = current_slot()
  t.slot = slot
  t.excluded = S.exclusion(typ, half, t.user, is_reserved(slot))
  local pd = global("play_data")
  local play_mode = (pd and rd("u8", pd + P.play_mode)) or 0xFF
  t.mode = S.mode_index(play_mode)
  if t.mode == S.MODE_FREE then
    local ok, bb = pcall(VRFW.mode_is, "battle_bay")
    if ok and bb == true then t.mode = S.MODE_BATTLE_BAY end
  end
  -- goals already on the board (scripted starting score) belong to nobody
  t.seen = { score(mi, 0), score(mi, 1) }
  local note = ""
  if t.excluded then note = ": NOT COUNTED (" .. t.excluded .. ")" end
  info("match #" .. t.match_no .. " start (" .. why .. "): slot " .. slot .. ", type " .. typ .. ", play mode " .. play_mode
    .. " (" .. S.MODES[t.mode] .. "), half " .. half .. " s, user team " .. t.user .. ", score " .. t.seen[1] .. "-" .. t.seen[2] .. note)
end

-- on-pitch members of the user's team (the engine's test)
local function sample_pitch()
  if t.user > 1 then return end
  local team = t.mi + P.info_teams + t.user * P.team_size
  local on = rd("u32", team + P.team_on_pitch) or 0
  local added = {}
  local keeper = 0
  for k = 0, P.member_slots - 1 do
    local m = team + P.team_members + k * P.member_size
    local pos = rd("u8", m + P.member_position) or 0xFF
    local flags = rd("u16", m + P.member_flags) or 0x800
    if S.member_on_pitch(pos, on, flags) then
      local c = rd("u32", m + P.member_chara)
      if c and c ~= 0 then
        if pos == 0 then
          keeper = c
          S.per_of(t.rec, c).keeper = true
        end
        if not t.pitch[c] then
          t.pitch[c] = true
          added[#added + 1] = hex(c)
        end
      end
    end
  end
  t.keeper_now = keeper
  if #added > 0 then
    if not t.logged_pitch then
      t.logged_pitch = true
      info("match #" .. t.match_no .. ": on the pitch (" .. on .. " on-pitch slots): " .. table.concat(added, " "))
    else
      info("match #" .. t.match_no .. ": entered the pitch: " .. table.concat(added, " "))
    end
  end
end

-- new entries of the goal lists since the last call
local function check_goals()
  for team = 0, 1 do
    local n = score(t.mi, team)
    if n < t.seen[team + 1] then
      t.seen[team + 1] = n -- the score went down (reset): follow it
    else
      while t.seen[team + 1] < n do
        local i = t.seen[team + 1]
        t.seen[team + 1] = i + 1
        local entry = t.mi + P.info_goal_lists + team * P.goal_list_size + P.goal_list_goals
          + math.min(i, P.goals_max - 1) * P.goal_size
        local actor = rd("u32", entry + P.goal_actor) or 0
        if team ~= t.user then
          if t.keeper_now ~= 0 then
            local e = S.per_of(t.rec, t.keeper_now)
            e.keeper = true
            e.conceded = e.conceded + 1
          end
        else
          local s, own = 0, false
          local c, tm = actor_chara(actor)
          if c then
            if tm == team then s = c else own = true end
          end
          local assist_actor = S.chain_assist(t.chain, actor, team)
          local a = 0
          if assist_actor then
            local ac, at = actor_chara(assist_actor)
            if ac and at == team then a = ac end
          end
          if own then t.own_goals_for = t.own_goals_for + 1 end
          local as = "none"
          if assist_actor then as = "actor " .. string.format("0x%X", assist_actor) .. " -> chara " .. hex(a) end
          local og = ""
          if own then og = ", own goal of the rival" end
          info("match #" .. t.match_no .. ": GOAL " .. t.seen[team + 1] .. " (actor " .. string.format("0x%X", actor) .. " -> chara " .. hex(s) .. og .. "), assist " .. as)
          t.goals[#t.goals + 1] = { s, a }
        end
      end
    end
  end
end

-- the per-actor match records of the user's actors into the tracker
local function sample_records()
  if t.user > 1 then return end
  for _, a in ipairs(Actors.list()) do
    local idx = a.index
    if bit32.band(a.handle, 0xFF) == idx and a.team == t.user then
      local chara = actor_chara(a.handle)
      if chara then
        local r = t.mi + P.info_actor_records + idx * P.record_size
        local vals = {}
        for k, off in ipairs(RECORD_FIELDS) do vals[k] = rd("u8", r + off) or 0 end
        S.rec_sample(t.rec, idx, chara, vals)
      end
    end
  end
end

-- ball owner of this frame into the chain
local function poll_owner()
  local ball = global("ball")
  if not ball or ball < 0x10000 then return end
  local o = rd("u32", ball + P.ball_owner) or 0
  if o == t.last_owner then return end
  t.last_owner = o
  S.chain_push(t.chain, o, rd("u8", ball + P.ball_owner_team) or 0xFF)
end

local function tick()
  if t.phase == "idle" then
    begin("first tick")
  elseif t.phase == "done" and match_info() == t.mi then
    -- a rematch that keeps the HUD (no new OnInit): the score went back down
    if score(t.mi, 0) + score(t.mi, 1) < t.seen[1] + t.seen[2] then begin("score reset (rematch)") end
  end
  if t.phase ~= "tracking" then return false end
  if match_info() ~= t.mi then
    t.phase = "idle"
    return false
  end
  t.ticks = t.ticks + 1
  if t.excluded then return result_state() end
  local b1, b2 = t.seen[1], t.seen[2]
  check_goals()
  if t.seen[1] ~= b1 or t.seen[2] ~= b2 then
    t.chain = S.chain_new()
    t.last_owner = 0
  end
  poll_owner()
  if t.ticks <= 3 or t.ticks % PITCH_EVERY == 0 then
    sample_pitch()
    sample_records()
  end
  return result_state()
end

-- record the match (once)
local function finalize(why)
  if t.phase ~= "tracking" then return end
  if match_info() == t.mi then
    check_goals()
    sample_pitch()
    sample_records()
  end
  t.phase = "done"
  if t.excluded then
    info("match #" .. t.match_no .. " over (" .. why .. "): not counted (" .. t.excluded .. ")")
    return
  end
  local u = t.user
  local gf, ga = t.seen[u + 1], t.seen[2 - u]
  local unresolved = {}
  local function map(h)
    if not h or h == 0 then return nil end
    local o = owner(h)
    if not o then unresolved[#unresolved + 1] = hex(h) end
    return o
  end
  local players = {}
  for c in pairs(t.pitch) do
    local o = map(c)
    if o then players[o] = true end
  end
  local goals = {}
  for _, g in ipairs(t.goals) do goals[#goals + 1] = { scorer = map(g[1]), assist = map(g[2]) } end
  local per = {}
  local numbers = {}
  for c, pm in pairs(t.rec.per) do
    local o = map(c)
    if o then
      local e = per[o]
      if not e then
        e = { shots = 0, steals = 0, saves = 0, skill_uses = 0, hiper_uses = 0, conceded = 0, keeper = false }
        per[o] = e
      end
      e.shots = e.shots + pm.shots
      e.steals = e.steals + pm.steals
      e.saves = e.saves + pm.saves
      e.skill_uses = e.skill_uses + pm.skill_uses
      e.hiper_uses = e.hiper_uses + pm.hiper_uses
      e.conceded = e.conceded + pm.conceded
      e.keeper = e.keeper or pm.keeper
    end
  end
  for o, p in pairs(per) do
    if p.shots + p.steals + p.saves + p.skill_uses + p.hiper_uses + p.conceded > 0 or p.keeper then
      local gk = ""
      if p.keeper then gk = " GK -" .. p.conceded end
      numbers[#numbers + 1] = hex(o) .. " " .. p.shots .. "T " .. p.steals .. "R " .. p.saves .. "P " .. p.skill_uses .. "S " .. p.hiper_uses .. "H" .. gk
    end
  end
  local outcome = "draw"
  if gf > ga then outcome = "win" elseif gf < ga then outcome = "loss" end
  info("match #" .. t.match_no .. " numbers (shots T, balls won R, saves P, hissatsu S, hiper H, keeper -conceded): "
    .. (#numbers > 0 and table.concat(numbers, ", ") or "-"))
  local st = ensure_store()
  if not st then
    info("match #" .. t.match_no .. " over (" .. why .. "): a mod's reserved slot, not counted")
    return
  end
  local day = VRFW.ui.today()
  local n, mvp, contrib = S.apply_match(st, { outcome = outcome, gf = gf, ga = ga, players = players, goals = goals, mode = t.mode, per = per },
    function(o)
      local param, order = ident(o)
      return param, order
    end, day)
  st.dirty = true
  local scorers = {}
  for p, c in pairs(contrib) do scorers[#scorers + 1] = hex(p) .. " " .. c[1] .. "G " .. c[2] .. "A" end
  table.sort(scorers)
  local tail = ""
  if #unresolved > 0 then tail = "; no saved owner (not counted): " .. table.concat(unresolved, " ") end
  info("match #" .. t.match_no .. " RECORDED (" .. why .. ") slot " .. st.slot .. ", " .. S.MODES[t.mode] .. ": " .. outcome .. " " .. gf .. "-" .. ga
    .. ", " .. n .. " player(s) credited, goals [" .. table.concat(scorers, ", ") .. "], own goals of the rival " .. t.own_goals_for
    .. ", jugador del partido " .. (mvp and hex(mvp) or "-") .. tail)
  commit("match")
  -- players signed during the match session get their date now
  scan_and_date(true)
end

-- ---------------------------------------------------------------------------------------- commands

-- CMND_BETTERQOL_CAREER_MATCH(mode) -> state (0 idle, 1 tracking, 2 recorded / done)
function BetterQoL.Career.Match(mode)
  mode = tonumber(mode) or 0
  if mode == 1 then
    -- soccer_menu has a twin (soccer_menu_replay): a replay or a reopened HUD during a live match must not restart it
    local st = soccer_state()
    if t.phase == "tracking" and match_info() == t.mi and live_state(st) then
      -- HUD init in a live scene state: ignored
    else
      begin("kick-off")
    end
  elseif mode == 2 then
    if t.phase == "tracking" and match_info() == t.mi then
      check_goals()
      sample_pitch()
    end
  elseif mode == 3 then
    if t.phase == "tracking" then finalize("result screen") end
  else
    if tick() then finalize("result state") end
  end
  if t.phase == "tracking" then return 1 elseif t.phase == "done" then return 2 end
  return 0
end

-- (owner, param, get_order, record) of the player a plate command names
local function plate_player(hdl)
  hdl = tonumber(hdl) or 0
  if hdl == 0 then return nil end
  local o = owner(hdl)
  if not o then return nil end
  local param, order, rec = ident(o)
  if not param then return nil end
  return o, param, order, rec
end

local function empty(n)
  local r = { false }
  for i = 1, n do r[i + 1] = 0 end
  return table.unpack(r)
end

-- CMND_BETTERQOL_CAREER(charaStHdl) -> ok, signed, before, matches, wins, draws, losses, goals, assists, mvp, topSkill, topUses
function BetterQoL.Career.Get(hdl)
  local o, param, order = plate_player(hdl)
  if not o then return empty(11) end
  scan_and_date(false)
  local st = ensure_store()
  if not st then return empty(11) end
  local day = VRFW.ui.today()
  -- a player signed since the last scan: dated the first time the plate shows him
  if st.watermark and S.observe(st, o, param, order, day) then
    st.dirty = true
    info("slot " .. st.slot .. ": player " .. hex(o) .. " dated " .. day .. " (first seen on the plate)")
    commit("signing date")
  end
  local v = S.view(st, o, param, order)
  -- the most used move: a mod that counts move uses gave it to the old DLL; none now
  return true, v.signed, v.before, v.matches, v.wins, v.draws, v.losses, v.goals, v.assists, v.mvp, 0, 0
end

-- CMND_BETTERQOL_CAREER_EX(charaStHdl, group): ok, then
-- * group 0: signed, before, source, role, matches, wins, draws, losses, goals, assists, mvp, shots, steals, saves,
--   conceded, cleanSheets, gkMatches, skillUses, hiperUses, firstGoal, lastDay, lastResult, lastGf, lastGa;
-- * group 1: skill1, uses1, skill2, uses2, skill3, uses3 (zeros: no move-use counter);
-- * group 2: firstMvp, bestGoals, bestGoalsExact, bestGoalsDay, bestSaves, bestSavesExact, bestSavesDay, today
--   (days as yyyymmdd; 0 = not yet, -1 = unknown: a record from before the store's version 2);
-- * group 10 + m (m = 0 story, 1 Chronicle, 2 free matches, 3 Victory Road, 4 Kizuna town, 5 Battle Bay): matches,
--   wins, draws, losses, goals, assists, mvp, saves (mvp / saves of the matches before version 2 are not split).
-- ok = false (and zeros) in a mod's reserved slot, for players without a saved record.
function BetterQoL.Career.Ex(hdl, group)
  group = tonumber(group) or 0
  local o, param, order, rec = plate_player(hdl)
  if not o then return empty(24) end
  if group == 1 then return true, 0, 0, 0, 0, 0, 0 end
  scan_and_date(false)
  local st = ensure_store()
  if not st then return empty(24) end
  local s = S.get(st, o, param, order)
  if group >= 10 and group < 10 + #S.MODES then
    local m = s and s.modes[S.MODES[group - 9]]
    if not m then return true, 0, 0, 0, 0, 0, 0, 0, 0 end
    return true, m.matches, m.wins, m.draws, m.losses, m.goals, m.assists, m.mvp, m.saves
  end
  if group == 2 then
    local today = VRFW.ui.today()
    if not s then return true, 0, 0, 1, 0, 0, 1, 0, today end
    return true, s.first_mvp, s.best_goals, s.best_goals_exact, s.best_goals_day, s.best_saves, s.best_saves_exact,
      s.best_saves_day, today
  end
  local v = S.view(st, o, param, order)
  local x = s or { signed = 0, matches = 0, wins = 0, draws = 0, losses = 0, goals = 0, assists = 0, mvp = 0, shots = 0,
    steals = 0, saves = 0, conceded = 0, clean_sheets = 0, gk_matches = 0, skill_uses = 0, hiper_uses = 0, first_goal = 0,
    last = { day = 0, result = 0, gf = 0, ga = 0 } }
  local signed = x.signed
  if signed == 0 then signed = v.signed end
  return true, signed, v.before, S.source_kind(rec.add_source or 0), S.role(position_of(param), x.matches, x.gk_matches),
    x.matches, x.wins, x.draws, x.losses, x.goals, x.assists, x.mvp, x.shots, x.steals, x.saves, x.conceded,
    x.clean_sheets, x.gk_matches, x.skill_uses, x.hiper_uses, x.first_goal, x.last.day, x.last.result, x.last.gf, x.last.ga
end

-- Exported (mod.toml [exports], called by other mods as Utilities["Career.Params"](slot)): the chara_param ids of the
-- career records of save slot `slot` (default: the active one), comma-separated ("" = none or unreadable). Inazuma
-- Fantasy's office seeds its «signed once» set with it (every card with a record was in the club at some point).
function BetterQoL.Career.Params(slot)
  slot = math.floor(tonumber(slot) or current_slot())
  local f = store
  if not f or f.slot ~= slot then
    local text, err = VRFW.save.blob(S.BLOB, slot)
    if err or not text then return "" end
    f = S.decode(text, slot)
    if not f then return "" end
  end
  local out = {}
  for _, s in pairs(f.players) do
    local p = type(s) == "table" and tonumber(s.param)
    if p and p ~= 0 then out[#out + 1] = string.format("%.0f", p) end
  end
  return table.concat(out, ",")
end

-- ---------------------------------------------------------------------------------------- club statistics screen

-- «Estadísticas del club» (row of «Caseta del club», graft util_club_stats_row, opening the page util_club_stats_menu
-- from assets/lua/play_guide_top_menu/150_club_stats.lua): the club totals of the store and one row per saved
-- character of the save (any squad, the bank) who played at least one counted match.
local T = require "lib/original_names_tables"

local club_rows = {}
local club_names = { lang = nil, rows = {}, asked = {}, base = {}, text = {} }

local function club_lang(code)
  local c = type(code) == "number" and math.floor(code) or nil
  if c and c >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[c + 1] or nil
    if type(l) == "string" then return l end
  end
  return "en"
end

-- the name rows `ids` of chara_text in `lang` not read yet (only those rows: the table has ~21k)
local function club_load_names(lang, ids)
  if club_names.lang ~= lang then
    club_names = { lang = lang, rows = {}, asked = {}, base = club_names.base, text = club_names.text }
  end
  local missing = {}
  for _, id in ipairs(ids) do
    if not club_names.asked[id] then
      club_names.asked[id] = true
      missing[#missing + 1] = id
    end
  end
  if #missing == 0 then return end
  local ok, rows = pcall(VRFW.files.text_rows, T.text_key(lang, T.CHARA), missing)
  if (not ok or type(rows) ~= "table") and lang ~= "en" then
    ok, rows = pcall(VRFW.files.text_rows, T.text_key("en", T.CHARA), missing)
  end
  for id, r in pairs((ok and type(rows) == "table") and rows or {}) do
    club_names.rows[id] = r
  end
end

-- the character (chara_base) of a card, cached; nil = unknown
local function club_base_of(param)
  local b = club_names.base[param]
  if b == nil then
    local ok, c = pcall(VRFW.chara.base_of, param)
    b = (ok and type(c) == "number") and c or false
    club_names.base[param] = b
  end
  return b or nil
end

-- the name text id of a character, cached; nil = unknown
local function club_name_text_of(base)
  if not base then return nil end
  local id = club_names.text[base]
  if id == nil then
    local ok, c = pcall(VRFW.chara.character, base)
    id = (ok and type(c) == "table" and type(c.name_text) == "number") and c.name_text or false
    club_names.text[base] = id
  end
  return id or nil
end

local function club_name_of(base)
  local id = club_name_text_of(base)
  local r = id and club_names.rows[id]
  local s = r and r[0]
  if type(s) == "string" and s ~= "" then return T.strip_furigana(s) end
  return ""
end

-- CMND_BETTERQOL_CLUB_STATS(langCode) -> ok, players, since, matches, wins, draws, losses, goalsFor, goalsAgainst,
-- cleanSheets, bestWinFor, bestWinAgainst, bestWinDay, bestWinRun, bestUnbeatenRun, storeSince, today. Days as
-- yyyymmdd (0 = none yet); storeSince = the day the career store started (players signed before it have no date).
-- Builds the player list CMND_BETTERQOL_CLUB_STATS_ROW reads. ok = false in a mod's reserved slot or without a save.
function BetterQoL.Career.Club(code)
  club_rows = {}
  local today = VRFW.ui.today()
  scan_and_date(false)
  local st = ensure_store()
  if not st then return false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, today end
  local name_ids = {}
  for k, s in pairs(st.players) do
    local hdl = tonumber(k, 16)
    if hdl and s.matches > 0 then
      local param, order = ident(hdl)
      if param and param == s.param and order == s.order then
        local base = club_base_of(param)
        club_rows[#club_rows + 1] = { base = base or 0, s = s }
        local name_id = club_name_text_of(base)
        if name_id then name_ids[#name_ids + 1] = name_id end
      end
    end
  end
  club_load_names(club_lang(tonumber(code)), name_ids)
  for _, r in ipairs(club_rows) do
    r.name = club_name_of(r.base ~= 0 and r.base or nil)
  end
  table.sort(club_rows, function(a, b)
    if a.s.goals ~= b.s.goals then return a.s.goals > b.s.goals end
    if a.s.matches ~= b.s.matches then return a.s.matches > b.s.matches end
    return a.name < b.name
  end)
  local c = st.club or S.club_new()
  info("club stats: " .. #club_rows .. " player(s), club totals since " .. c.since .. " (" .. c.matches .. " match(es))")
  return true, #club_rows, c.since, c.matches, c.wins, c.draws, c.losses, c.goals_for, c.goals_against, c.clean_sheets,
    c.best_win_for, c.best_win_against, c.best_win_day, c.best_win_run, c.best_unbeaten_run, st.since, today
end

-- CMND_BETTERQOL_CLUB_STATS_ROW(i) (1-based) -> chara_base (portrait key, 0 = none), name, matches, wins, draws, losses,
-- goals, assists, mvp, signed (yyyymmdd; 0 = signed before the career store started). "" past the end.
function BetterQoL.Career.ClubRow(i)
  local r = club_rows[math.floor(tonumber(i) or 0)]
  if not r then return "" end
  local s = r.s
  return r.base, r.name, s.matches, s.wins, s.draws, s.losses, s.goals, s.assists, s.mvp, s.signed
end

info("active; store blob " .. S.BLOB .. " per slot (staged with the game's save); fed by the match HUD (CMND_BETTERQOL_CAREER_MATCH, graft util_career_match); plate page CMND_BETTERQOL_CAREER_EX (graft util_career_page)")
