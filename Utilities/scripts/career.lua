-- Career stats of Utilities (docs/game/mechanics/player-career-stats.md): per player and save slot, the signing date,
-- matches, wins / draws / losses, goals, assists, «Jugador del partido», shots, balls won, saves, clean sheets, the
-- last match, the first goal / first MVP dates, the best match and a per-mode split, shown on the player plate's page
-- «TRAYECTORIA» (graft util_career_page).
--
-- Fed by the match HUD (graft util_career_match): CMND_UTIL_CAREER_MATCH 1 kick-off (soccer_menu OnInit), 0 every
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

Utilities = Utilities or {}
Utilities.Career = Utilities.Career or {}

-- ---------------------------------------------------------------------------------------- data layout (v7.1.2)

local MI_TYPE, MI_HALF_LEN, MI_TEAMS, TEAM_STRIDE, MI_SCORE, MI_USER_TEAM = 0x16, 0x1C, 0x60, 0x1130, 0x2C26, 0x2C29
-- goal list of a team: mi + 0x2368 + team * 0x2D4 + 4 + i * 12 = {u32 scorer actor, ...}; 60 entries
local MI_GOALS, GOALS_TEAM_STRIDE, GOAL_FIRST, GOAL_ENTRY, GOALS_MAX = 0x2368, 0x2D4, 4, 12, 60
-- team record member slot k (0..0x1C) at + (k + 1) * 0x80
local TEAM_MEMBER_STRIDE, MEMBER_SLOTS, TEAM_ON_PITCH = 0x80, 0x1D, 0x1050
local MEM_CHARA, MEM_POSITION, MEM_FLAGS = 0x50, 0x71, 0x7A
-- soccer actors
local ACTOR_STRIDE, ACTOR_MAX, ACTOR_HDL, ACTOR_TEAM = 0x570, 0x3A, 0x94, 0xD0
local UNIT_CHARA = 0x370
-- per-actor match record mi + 0x2928 + actor * 12: +4 shots, +6 balls won, +7 keeper blocks, +0xA hissatsu uses
local MI_ACTOR_RECORDS, ACTOR_RECORD = 0x2928, 12
local RECORD_FIELDS = { 4, 6, 7, 0xA }
local BALL_OWNER, BALL_OWNER_TEAM = 0x1494, 0x1498
local PLAY_MODE = 0x2CAC6F
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

local function hex(h) return string.format("0x%08X", h or 0) end

local function info(...) VRFW.log("career:", ...) end
local function warn(...) VRFW.warn("career:", ...) end

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

local function actor_at(idx)
  if idx >= ACTOR_MAX then return nil end
  local base = global("soccer_actors")
  if not base or base < 0x10000 then return nil end
  return base + idx * ACTOR_STRIDE
end

local function actor_of_handle(hdl)
  if not hdl or hdl == 0 then return nil end
  local a = actor_at(bit32.band(hdl, 0xFF))
  if a and rd("u32", a + ACTOR_HDL) == hdl then return a end
  return nil
end

local function actor_unit(a)
  local ok, u = pcall(VRFW.call, "ActorUnit", a)
  if ok and u and u >= 0x10000 then return u end
  return nil
end

-- (character handle, team) an actor plays
local function actor_chara(hdl)
  local a = actor_of_handle(hdl)
  if not a then return nil end
  local team = rd("u8", a + ACTOR_TEAM)
  local unit = actor_unit(a)
  if not team or not unit then return nil end
  local c = rd("u32", unit + UNIT_CHARA)
  if not c or c == 0 then return nil end
  return c, team
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

local store = nil -- the active slot's file
local last_scan = nil -- VRFW.now() of the last signing-date scan of this store
local event_seen = nil -- VRFW.slots.event_seq() last seen

-- The slot events since the last call: a load / copy / delete / new game / reset of the store's slot drops the
-- numbers the game never saved (the blob, with its staged version, is read again at the next use).
local function check_events()
  local seq = VRFW.slots.event_seq()
  if event_seen == nil then event_seen = seq return end
  if seq == event_seen then return end
  local from = math.max(event_seen + 1, seq - 63)
  for n = from, seq do
    local kind, a, b = VRFW.slots.event(n)
    if store and kind then
      local slot = nil
      if kind == "switched" or kind == "deleted" or kind == "new_game" or kind == "reset" then slot = a end
      if kind == "copied" then slot = b end
      if slot == store.slot then
        info("slot " .. slot .. ": store will be read again (" .. kind .. ")")
        store = nil
      end
    end
  end
  event_seen = seq
end

local function load_store(slot)
  local text, err = VRFW.save.blob(S.BLOB, slot)
  if err then
    local kept = VRFW.save.blob_aside(S.BLOB, slot)
    VRFW.error("career: " .. err .. "; " .. kept .. "; starting empty")
    return S.new_file(slot)
  end
  local f, why = S.decode(text, slot)
  if not f then
    local kept = VRFW.save.blob_aside(S.BLOB, slot)
    VRFW.error("career: slot " .. slot .. " " .. S.BLOB .. ": " .. tostring(why) .. "; " .. kept .. "; starting empty")
    return S.new_file(slot)
  end
  local n = 0
  for _ in pairs(f.players) do n = n + 1 end
  local wm = "not set yet"
  if f.watermark then wm = "get_order " .. f.watermark .. " (since " .. f.since .. ")" end
  info("slot " .. slot .. ": " .. n .. " players, " .. f.recorded .. " matches recorded, watermark " .. wm)
  if f.migrated_from then
    info("slot " .. slot .. ": " .. S.BLOB .. " version " .. f.migrated_from .. " read as version " .. S.FILE_VERSION
      .. " (first goal / first MVP dates and best matches derived where the numbers allow; written with the next change)")
  end
  return f
end

-- The store of the active slot (nil in a mod's reserved slot); read again when the slot changed.
local function ensure_store()
  check_events()
  local slot = current_slot()
  if is_reserved(slot) then return nil end
  if not store or store.slot ~= slot then
    if store and store.dirty then warn("slot " .. store.slot .. " -> " .. slot .. ": dropping numbers not saved by the game") end
    store = load_store(slot)
    last_scan = nil
  end
  return store
end

-- Stage the store with the game's next save of its slot (written at once without the slot service).
local function commit(why)
  if not store or not store.dirty then return end
  local text = S.encode(store)
  local ok, where
  if VRFW.slots.ready() then
    ok, where = VRFW.save.blob_stage(S.BLOB, text, store.slot)
  else
    ok, where = VRFW.save.blob_write(S.BLOB, text, store.slot)
  end
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

local function score(mi, team) return rd("u8", mi + MI_SCORE + team) or 0 end

local function begin(why)
  local mi = match_info()
  if not mi then
    t.phase = "idle"
    return
  end
  if t.phase == "tracking" then info("match #" .. t.match_no .. " dropped: a new match started before its result (retry / quit)") end
  t = new_tracker(t.match_no + 1)
  t.phase = "tracking"
  t.mi = mi
  t.user = rd("u8", mi + MI_USER_TEAM) or 0xFF
  local typ = rd("u8", mi + MI_TYPE) or 0
  local half = rd("u16", mi + MI_HALF_LEN) or 0
  local slot = current_slot()
  t.slot = slot
  t.excluded = S.exclusion(typ, half, t.user, is_reserved(slot))
  local pd = global("play_data")
  local play_mode = (pd and rd("u8", pd + PLAY_MODE)) or 0xFF
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
  local team = t.mi + MI_TEAMS + t.user * TEAM_STRIDE
  local on = rd("u32", team + TEAM_ON_PITCH) or 0
  local added = {}
  local keeper = 0
  for k = 0, MEMBER_SLOTS - 1 do
    local m = team + (k + 1) * TEAM_MEMBER_STRIDE
    local pos = rd("u8", m + MEM_POSITION) or 0xFF
    local flags = rd("u16", m + MEM_FLAGS) or 0x800
    if S.member_on_pitch(pos, on, flags) then
      local c = rd("u32", m + MEM_CHARA)
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
        local entry = t.mi + MI_GOALS + team * GOALS_TEAM_STRIDE + GOAL_FIRST + math.min(i, GOALS_MAX - 1) * GOAL_ENTRY
        local actor = rd("u32", entry) or 0
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
  for idx = 0, ACTOR_MAX - 1 do
    local a = actor_at(idx)
    if not a then return end
    local hdl = rd("u32", a + ACTOR_HDL)
    if hdl and hdl ~= 0 and bit32.band(hdl, 0xFF) == idx and rd("u8", a + ACTOR_TEAM) == t.user then
      local chara = actor_chara(hdl)
      if chara then
        local r = t.mi + MI_ACTOR_RECORDS + idx * ACTOR_RECORD
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
  local o = rd("u32", ball + BALL_OWNER) or 0
  if o == t.last_owner then return end
  t.last_owner = o
  S.chain_push(t.chain, o, rd("u8", ball + BALL_OWNER_TEAM) or 0xFF)
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

-- CMND_UTIL_CAREER_MATCH(mode) -> state (0 idle, 1 tracking, 2 recorded / done)
function Utilities.Career.Match(mode)
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

-- CMND_UTIL_CAREER(charaStHdl) -> ok, signed, before, matches, wins, draws, losses, goals, assists, mvp, topSkill, topUses
function Utilities.Career.Get(hdl)
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

-- CMND_UTIL_CAREER_EX(charaStHdl, group): ok, then
-- * group 0: signed, before, source, role, matches, wins, draws, losses, goals, assists, mvp, shots, steals, saves,
--   conceded, cleanSheets, gkMatches, skillUses, hiperUses, firstGoal, lastDay, lastResult, lastGf, lastGa;
-- * group 1: skill1, uses1, skill2, uses2, skill3, uses3 (zeros: no move-use counter);
-- * group 2: firstMvp, bestGoals, bestGoalsExact, bestGoalsDay, bestSaves, bestSavesExact, bestSavesDay, today
--   (days as yyyymmdd; 0 = not yet, -1 = unknown: a record from before the store's version 2);
-- * group 10 + m (m = 0 story, 1 Chronicle, 2 free matches, 3 Victory Road, 4 Kizuna town, 5 Battle Bay): matches,
--   wins, draws, losses, goals, assists, mvp, saves (mvp / saves of the matches before version 2 are not split).
-- ok = false (and zeros) in a mod's reserved slot, for players without a saved record.
function Utilities.Career.Ex(hdl, group)
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
function Utilities.Career.Params(slot)
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

info("active; store blob " .. S.BLOB .. " per slot (staged with the game's save); fed by the match HUD (CMND_UTIL_CAREER_MATCH, graft util_career_match); plate page CMND_UTIL_CAREER_EX (graft util_career_page)")
