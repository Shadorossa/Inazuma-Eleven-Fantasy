-- InaRogue › INAROGUE: the run of the active slot and its CMND_EVT_RL_RUN_* commands (docs/game/modes/inarogue.md
-- §11, §14, §18, §20; was run_rt.rs of the DLL's module rogue). The map is a pure function of (seed, phase); the blob
-- rogue_run.json keeps the seed, the phase, the path, the squad, the node in progress and the players' handles.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_EVT_RL_RUN_INFO | – | exists, phase, cols, nodes, edges, cur, curCol, seed, phasesDone, budget, slot, pendingStage, pendingNode, won, lost, fog, revealBoss |
-- | CMND_EVT_RL_RUN_START | seed (0 = from the clock) | code, seed |
-- | CMND_EVT_RL_RUN_NODE | i | ok, col, slot, kind, pick, state |
-- | CMND_EVT_RL_RUN_EDGE | i | ok, from, to, walked, event, coin |
-- | CMND_EVT_RL_RUN_MOVE / _STAGE | to / stage | code |
-- | CMND_EVT_RL_RUN_RESUME | – | stage, node, kind, event, coin, gameId, diff, stadium, level, rival |
-- | CMND_EVT_RL_RUN_MATCH | node | ok, gameId, diff, stadium, kind, level, rival, emblem |
-- | CMND_EVT_RL_RUN_RESERVE | – | code, gameId, diff, stadium, level, rival |
-- | CMND_EVT_RL_RUN_RESULT | result (1 win, 2 lose, 3 draw, 0 none), gf, ga | code, outcome, isBoss, fragsEach, players, formId, formName, formRarity, formsOwned, formsTotal, points |
-- | CMND_EVT_RL_RUN_CLEAR / _NEXT_PHASE / _ABANDON | – | code, isBoss / code, phase / code |
-- | CMND_EVT_RL_RUN_SQUAD / _SET_HDL / _SET_SLOT | slot / slot, hdl / slot, uid, hdl | ok, uid, param, hdl, tier, cost / code / code |
-- | CMND_EVT_RL_RUN_RECRUIT | op 0 / op 1, param | ok, param, tier, cost, freeSlot, whatif / code, uid, slot |
-- | CMND_EVT_RL_RUN_LAUNCH | op (0 read, 1 set, 2 clear) | pending |
-- | CMND_EVT_RL_RUN_LOOT | node (-1 current), salt (1 Cofre, 2 boss) | kind, id, tier, name, owned, total |

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local cfgm = require "lib/rogue/cfg"
local R = require "lib/rogue/run"
local map = require "lib/rogue/map"
local matches = require "lib/rogue/matches"
local pool = require "lib/rogue/pool"
local bosses = require "lib/rogue/bosses"
local St = require "lib/rogue/starter"
local chara = require "lib/rogue/chara"
local loot = require "lib/rogue/loot"
local Bk = require "lib/rogue/bank"
local info, warn, err = U.logger("rogue run")

local S = {}
local K, C, ST = map.KIND, R.CODE, R.STAGE
S.OUTCOME = { CLEARED = 1, RUN_OVER = 2, REPLAY = 3 }
local OUT = S.OUTCOME

local inner = nil       -- { slot, run, map }
local launching = false
local last_coach = ""   -- the coach of the last run loaded / saved (the run-end rewards still read it)
local lifetime, lifetime_read = {}, false

local function cfg() return Core.cfg() end
local function cat() return bosses.catalogue(cfg().bosses) end

-- the map of the run's current phase: the coach's node weights from coach_since on, the boss tiers on rule 2+ boards
local function run_map(r)
  local mults = nil
  if r.coach_since ~= 0 and r.phase >= r.coach_since then mults = Core.meta.coach_content_mults(r.coach) end
  local m = map.generate(r.seed, r.phase, cfg(), mults)
  local c = cat()
  if r.rivals_rule >= bosses.RULE and c then bosses.place(m, r.seed, r.phase, c) end
  return m
end

local function note_coach(r)
  if r then last_coach = r.coach end
  Core.meta.coach_sync(r)
end

local function load(slot)
  local r, why = R.load(slot)
  if r == false then
    local kept = U.blob_aside(R.BLOB, slot)
    err(string.format("slot %d: %s: %s; %s; no usable previous version: no run", slot, R.BLOB, tostring(why), tostring(kept)))
    r = nil
  end
  if r then
    local id = Core.meta.coach_default_id()
    if R.stamp_coach(r, id) then
      local ok, where = R.save(r)
      if ok then
        info(string.format("slot %d: run from before coaches gets the default coach %s", slot, r.coach))
      else
        err(string.format("slot %d: cannot stamp the default coach: %s", slot, tostring(where)))
      end
    end
  end
  note_coach(r)
  if r then
    info(string.format("slot %d: run seed %.0f phase %d at node %d (%d cleared, stage %d)", slot, r.seed, r.phase, r.cur, #r.cleared, R.stage(r)))
  end
  return { slot = slot, run = r, map = r and run_map(r) or nil }
end

local function with(f)
  local slot = U.slot()
  if not inner or inner.slot ~= slot then inner = load(slot) end
  return f(inner)
end

Core.on_forget(function(slot)
  if inner and (slot == nil or inner.slot == slot) then
    inner = nil
    Core.meta.coach_sync(nil)
  end
  launching = false
end)

local function save(i, why)
  local r = i.run
  if not r then return C.NO_RUN end
  i.map = run_map(r)
  note_coach(r)
  local ok, where = R.save(r)
  if ok then
    local cl = {}
    for k, n in ipairs(r.cleared) do cl[k] = tostring(n) end
    info(string.format("%s: phase %d node %d stage %d cleared [%s] -> %s", why, r.phase, r.cur, R.stage(r), table.concat(cl, ", "), tostring(where)))
    return C.OK
  end
  err(string.format("cannot write %s of slot %d: %s", R.BLOB, i.slot, tostring(where)))
  return C.WRITE_FAILED
end

-- change the run, save it, roll the change back when the write fails
local function edit(why, f)
  return with(function(i)
    local r = i.run
    if not r then return C.NO_RUN end
    local before = R.copy(r)
    local code = f(r, i)
    if code ~= C.OK then return code end
    local c = save(i, why)
    if c ~= C.OK then
      i.run = before
      i.map = run_map(before)
    end
    return c
  end)
end

-- take the run out of use: OK / WRITE_FAILED
local function delete(i)
  local note = R.delete(i.slot)
  if type(note) == "string" and note:find("^could not") then
    err(string.format("cannot delete %s of slot %d: %s", R.BLOB, i.slot, note))
    return false
  end
  return true
end

-- §33: every rival ever beaten (the unlock store's `beaten`), with requires_scope = "lifetime" only
local function sync_lifetime(force)
  local c = cat()
  if not c or not bosses.lifetime(c) or (not force and lifetime_read) then return end
  lifetime = Core.meta.beaten_lifetime()
  lifetime_read = true
end

-- the seeded match of node k of the current phase
local function pick_for(r, m, k)
  local n = map.node(m, k)
  if not n then return nil end
  local beaten = {}
  for _, b in ipairs(r.beaten_phase) do beaten[U.lower(U.trim(b))] = true end
  for _, b in ipairs(lifetime) do beaten[U.lower(U.trim(b))] = true end
  local cols = math.max(m.cols - 1, 1)
  return matches.pick(r.seed, r.phase, k, n.kind, n.col, cols, r.rivals_rule, { cfg = cfg(), cat = cat(), beaten = beaten })
end

-- the coach of the run in progress (nil = no run) / of the last run
function S.current_coach()
  return with(function(i) return i.run and i.run.coach or nil end)
end
function S.run_coach() return last_coach end

-- the run coach's start items are taken (marked given in the run file): the coach id when they were still owed
function S.take_coach_items()
  local id = nil
  local code = edit("coach start items", function(r)
    if r.coach_items_given then return C.ALREADY end
    r.coach_items_given = true
    id = r.coach
    return C.OK
  end)
  if code == C.OK then return id end
  return nil
end

local seed_count = 0
local function clock_seed()
  seed_count = seed_count + 1
  local ok, ms = pcall(VRFW.now)
  ms = (ok and type(ms) == "number") and ms or 0
  local s = U.xor(U.mul32(U.today(), 0x01F3A5B7), math.floor(ms) % U.TWO32)
  s = U.xor(s, U.mul32(seed_count, 0x9E3779B9))
  s = U.xs(math.max(s, 1))
  return math.max(s, 1)
end

-- start a run of the active slot (replaces any run): code, seed. `squad` = bank uids, `slots` = the team screen's slots
-- (empty = the picker), `formation` = formId
function S.start_run(seed, squad, slots, formation)
  if seed == 0 then seed = clock_seed() end
  local coach = Core.meta.coach_take_pick()
  local code = with(function(i)
    local r = R.new(i.slot, seed)
    R.set_coach(r, coach, Core.meta.coach_has_start_items(coach))
    r.squad = squad
    r.slots = slots
    r.formation = formation
    i.run = r
    local c = save(i, "new run")
    if c ~= C.OK then
      i.run = nil
      i.map = nil
    end
    return c
  end)
  info(string.format("start seed %.0f, squad of %d, coach %s -> code %d", seed, #squad, coach, code))
  if code == C.OK then
    Core.bank.record_phase(1)
    Core.meta.coach_on_run_start(coach)
  end
  return code, seed
end

-- ---------------------------------------------------------------------------------------- commands

function S.Info()
  local c = cfg()
  local b = c.board
  local fog, reveal = b.fog and 1 or 0, b.reveal_boss and 1 or 0
  local x = with(function(i)
    if not i.run or not i.map then return nil end
    return { i.run, i.map, i.slot }
  end)
  if x then
    local r, m, slot = x[1], x[2], x[3]
    local n = map.node(m, r.cur)
    return true, r.phase, m.cols, #m.nodes, #m.edges, r.cur, n and n.col or 0, r.seed, r.phases_done, cfgm.budget(c, r.phase),
      slot, R.stage(r), r.pending and r.pending.node or -1, r.won, r.lost, fog, reveal
  end
  return false, 0, 0, 0, 0, 0, 0, 0, 0, cfgm.budget(c, 1), U.slot(), 0, -1, 0, 0, fog, reveal
end

function S.Start(seed_arg)
  return S.start_run(U.u32(seed_arg, 0), {}, {}, 0)
end

local function node_state(r, m, k)
  if k == r.cur then return 3 end
  if R.is_cleared(r, k) then return 2 end
  if U.contains(r.path, k) then return 4 end
  if R.is_cleared(r, r.cur) and map.connected(m, r.cur, k) then return 1 end
  return 0
end

function S.Node(k_arg)
  local k = U.int(k_arg, -1)
  local x = with(function(i)
    local r, m = i.run, i.map
    if not r or not m or k < 0 then return nil end
    local n = map.node(m, k)
    if not n then return nil end
    return { n.col, n.slot, n.kind, n.pick, node_state(r, m, k) }
  end)
  if not x then return false end
  return true, x[1], x[2], x[3], x[4], x[5]
end

function S.Edge(k_arg)
  local k = U.int(k_arg, -1)
  local x = with(function(i)
    local r, m = i.run, i.map
    if not r or not m or k < 0 then return nil end
    local e = m.edges[k + 1]
    if not e then return nil end
    local walked = false
    for p = 1, #r.path - 1 do
      if r.path[p] == e[1] and r.path[p + 1] == e[2] then walked = true end
    end
    return { e[1], e[2], walked, m.edge_ev[k + 1] or 0, m.edge_coin[k + 1] or 0 }
  end)
  if not x then return false end
  return true, x[1], x[2], x[3], x[4], x[5]
end

function S.Move(to_arg)
  local to = U.int(to_arg, -1)
  local code
  if to < 0 or to > 65535 then
    code = C.BAD_NODE
  else
    code = edit("move", function(r, i) return R.move_to(r, i.map, to) end)
  end
  if code ~= C.OK then warn(string.format("move to %d refused (code %d)", to, code)) end
  return code
end

function S.Stage(s_arg)
  local s = U.int(s_arg, -1)
  if s < ST.ARRIVED or s > ST.NODE then return C.BAD_NODE end
  return edit("stage", function(r) return R.set_stage(r, s) end)
end

-- the line event (and coin) of the edge walked to reach `node`
local function edge_into(r, m, node)
  local from = r.path[#r.path - 1]
  if from == nil then return 0, 0 end
  for e, x in ipairs(m.edges) do
    if x[1] == from and x[2] == node then return m.edge_ev[e] or 0, m.edge_coin[e] or 0 end
  end
  return 0, 0
end

local function match_values(p)
  local row = matches.row_of(p.game, cfg().rivals)
  return p.game, p.diff, p.stadium, p.level, row and row.rival or ""
end

function S.Resume()
  local x = with(function(i)
    local r, m = i.run, i.map
    if not r or not m or not r.pending then return nil end
    local p = r.pending
    local n = map.node(m, p.node)
    local ev, coin = edge_into(r, m, p.node)
    return { U.copy(p), n and n.kind or 0, ev, coin }
  end)
  if not x then return ST.NONE, 0, 0, 0, 0, 0, 0, 0, 0, "" end
  local p = x[1]
  if p.game ~= 0 and not matches.row_of(p.game, cfg().rivals) then
    -- a run saved before 2026-10-14 may hold a game of the removed pre-generated rivals: the node's match is drawn
    -- again (a random team of the same node and seed, docs/refactor/roguelite-split-map.md §4.6 (c))
    local q = with(function(i)
      local r, m = i.run, i.map
      if not r or not m or not r.pending then return nil end
      local np = pick_for(r, m, r.pending.node)
      if not np then return nil end
      r.pending.game, r.pending.diff, r.pending.stadium, r.pending.level = np.game, np.diff, np.row.stadium, np.level
      save(i, "pending match of a removed rival redrawn")
      return U.copy(r.pending)
    end)
    if q then
      info(string.format("resume: game %s is no longer a rival game: node %d redrawn -> %s", U.hex(p.game), q.node, U.hex(q.game)))
      p = q
    end
  end
  local g, d, sd, lv, rv = match_values(p)
  return p.stage, p.node, x[2], x[3], x[4], g, d, sd, lv, rv
end

function S.Match(k_arg)
  sync_lifetime(false)
  local k = U.int(k_arg, -1)
  local x = with(function(i)
    local r, m = i.run, i.map
    if not r or not m or k < 0 or k > 65535 then return nil end
    local n = map.node(m, k)
    if not n then return nil end
    local p = pick_for(r, m, k)
    if not p then return nil end
    return { p, n.kind }
  end)
  if not x then return false end
  local p = x[1]
  return true, p.game, p.diff, p.row.stadium, x[2], p.level, p.row.rival, p.row.emblem
end

-- CMND_EVT_RL_RUN_RIVAL (node; -1 = the pending / current node) -> rule, seed, node key, stage, slot: the random-team
-- build of that node's rival (docs/framework/random-team.md §4), nil when its rival is not a random team. The game Lua
-- passes them to CMND_VRFW_RANDOM_TEAM_BUILD right before the match (graft inarogue IRM_LaunchMatch, rogue_dock,
-- rogue_vs). Deterministic: the run seed and the node (phase stride 64) give the same team after a reload.
function S.Rival(k_arg)
  sync_lifetime(false)
  local k = U.int(k_arg, -1)
  local x = with(function(i)
    local r, m = i.run, i.map
    if not r or not m then return nil end
    local node = k
    if node < 0 then node = (r.pending and r.pending.node) or r.cur end
    if node == nil or node < 0 or node > 65535 then return nil end
    local p = pick_for(r, m, node)
    if not p then return nil end
    return { p, node, r.phase, r.seed }
  end)
  if not x then return nil end
  local p, node, phase, seed = x[1], x[2], x[3], x[4]
  if p.guest ~= 0 or not pool.is_random(p.row) then return nil end
  local key = (math.max(phase, 1) - 1) * pool.PHASE_STRIDE + node
  return pool.random_rule(cfg().rivals, p.row), seed % U.TWO32, key, p.row.tier, p.row.tier
end

function S.Reserve()
  sync_lifetime(false)
  local out = nil
  local code = with(function(i)
    local r, m = i.run, i.map
    if not r or not m then return C.NO_RUN end
    if R.is_cleared(r, r.cur) then return C.ALREADY end
    local p = pick_for(r, m, r.cur)
    if not p then return C.BAD_NODE end
    local before = R.copy(r)
    local e = R.set_stage(r, ST.MATCH)
    if e ~= C.OK then return e end
    pool.variety_record(r.seed, p.row.id) -- squads met: the next runs prefer others
    local pend = r.pending
    pend.game, pend.diff, pend.stadium, pend.level = p.game, p.diff, p.row.stadium, p.level
    out = U.copy(pend)
    local c = save(i, "match reserved")
    if c ~= C.OK then
      i.run = before
      i.map = run_map(before)
      out = nil
    end
    return c
  end)
  if out then
    info(string.format("reserve node %d -> game %s diff %d level %d", out.node, U.hex(out.game), out.diff, out.level))
    local g, d, sd, lv, rv = match_values(out)
    return code, g, d, sd, lv, rv
  end
  return code, 0, 0, 0, 0, ""
end

function S.Result(result_arg, gf_arg, ga_arg)
  sync_lifetime(false)
  local result = U.int(result_arg, 0)
  local gf, ga = U.int(gf_arg, 0), U.int(ga_arg, 0)
  local c = cfg()
  local lost = result == 2 or (result == 3 and c.draw_is_loss) or (result == 0 and c.quit_is_loss)
  local won = result == 1
  local boss, uids, phase, outcome = false, {}, 0, OUT.REPLAY
  local seed, node, kind = 0, 0, 0
  local rival, row, guest, era = "", "", 0, ""
  local code = with(function(i)
    local r, m = i.run, i.map
    if not r or not m then return C.NO_RUN end
    if R.stage(r) ~= ST.MATCH then return C.NOT_CLEARED end
    local n = map.node(m, r.cur)
    boss = n ~= nil and n.kind == K.BOSS
    seed, node, kind = r.seed, r.cur, n and n.kind or 0
    local p = pick_for(r, m, r.cur)
    if p then
      rival, row, guest = p.row.rival, p.row.name, p.guest
      era = matches.era_of(c.rivals, p.row)
    end
    phase = r.phase
    uids = R.player_uids(r)
    local before = R.copy(r)
    if won then
      r.won = r.won + 1
      R.note_beaten(r, rival, row) -- §33 fusion bosses
      outcome = OUT.CLEARED
      local e = R.clear_current(r)
      if e ~= C.OK then return e end
      local cc = save(i, "match won")
      if cc ~= C.OK then
        i.run = before
        i.map = run_map(before)
      end
      return cc
    elseif lost then
      outcome = OUT.RUN_OVER
      r.lost = r.lost + 1
      if delete(i) then
        info(string.format("slot %d: match lost, run over (file deleted)", i.slot))
        i.run = nil
        i.map = nil
        Core.meta.coach_sync(nil)
        return C.OK
      end
      i.run = before
      return C.WRITE_FAILED
    end
    outcome = OUT.REPLAY
    R.set_stage(r, ST.NODE)
    local cc = save(i, "match to play again")
    if cc ~= C.OK then
      i.run = before
      i.map = run_map(before)
    end
    return cc
  end)
  local each, players, points = 0, 0, 0
  local fid, fname, frar, fown, ftot = 0, "", 0, 0, 0
  if code == C.OK then
    if outcome == OUT.RUN_OVER then
      Core.bank.record_run_end(Bk.RESULT.LOST, phase)
    elseif outcome == OUT.CLEARED then
      -- a won «Jefe de puerta» (§33) pays the boss fragments too (it does not end the phase)
      local big = boss or kind == K.GATE
      each = big and c.frags_boss or c.frags_win
      each = Core.meta.coach_scaled(each, "frags")
      players = Core.bank.bank_frags_to(uids, each, boss and "boss won" or "match won")
      if players == 0 then each = 0 end
      local a, b2, c3, d4, e5 = Core.meta.formation_grant(seed, phase, node, kind)
      if a then fid, fname, frar, fown, ftot = a, b2, c3, d4, e5 end
      Core.meta.unlocks_on_win(kind, phase, rival, row, uids, guest ~= 0 and { guest } or {}, era)
      points = Core.meta.earn_win(kind, phase)
    end
  end
  info(string.format("result %d (%d-%d) -> code %d outcome %d boss %s frags %d x %d", result, gf, ga, code, outcome,
    tostring(boss), each, players))
  return code, outcome, boss, each, players, fid, fname, frar, fown, ftot, points
end

function S.Clear()
  local boss = with(function(i)
    local r, m = i.run, i.map
    if not r or not m then return false end
    local n = map.node(m, r.cur)
    return n ~= nil and n.kind == K.BOSS
  end)
  local code = edit("clear", function(r) return R.clear_current(r) end)
  return code, boss
end

function S.NextPhase()
  sync_lifetime(true)
  local phase = 0
  local code = edit("next phase", function(r, i)
    local e = R.next_phase(r, i.map)
    if e ~= C.OK then return e end
    phase = r.phase
    return C.OK
  end)
  if code == C.OK then
    Core.bank.record_phase(phase)
  else
    phase = with(function(i) return i.run and i.run.phase or 0 end)
  end
  return code, phase
end

function S.Abandon()
  local ended = nil
  local code = with(function(i)
    if not delete(i) then return C.WRITE_FAILED end
    info(string.format("slot %d: run abandoned (file deleted)", i.slot))
    ended = i.run and i.run.phase or nil
    i.run = nil
    i.map = nil
    Core.meta.coach_sync(nil)
    return C.OK
  end)
  if ended then Core.bank.record_run_end(Bk.RESULT.ABANDONED, ended) end
  return code
end

-- ---- the run's players in the INAROGUE save (§14 stages 2-3)

function S.Squad(slot_arg)
  local slot = U.int(slot_arg, -1)
  local x = with(function(i)
    local r = i.run
    if not r or slot < 0 or slot >= R.TEAM_SLOTS then return nil end
    local uid
    if #r.slots == 0 then uid = r.squad[slot + 1] else uid = r.slots[slot + 1] end
    if not uid or uid == 0 then return nil end
    return { uid, r.hdls[slot + 1] or 0 }
  end)
  if not x then return false end
  local param, frags, tier = Core.bank.bank_entry(x[1])
  if not param then return false end
  return true, x[1], param, x[2], tier, St.cost(cfg(), tier, frags)
end

function S.SetHdl(slot_arg, hdl_arg)
  local slot = U.int(slot_arg, -1)
  local hdl = U.u32(hdl_arg, 0)
  if slot < 0 then return C.BAD_NODE end
  return edit("player handle", function(r) return R.set_hdl(r, slot, hdl) end)
end

-- the retail dock is the squad screen (§16): its positions 0-19 are written back after it closes
function S.SetSlot(slot_arg, uid_arg, hdl_arg)
  local slot = U.int(slot_arg, -1)
  local uid = U.u32(uid_arg, 0)
  local hdl = U.u32(hdl_arg, 0)
  local known = uid == 0 or Core.bank.bank_entry(uid) ~= nil
  if slot < 0 or slot >= R.TEAM_SLOTS or not known then return C.BAD_NODE end
  return edit("dock slot", function(r)
    R.set_slot(r, slot, uid)
    if uid ~= 0 and not U.contains(r.squad, uid) then r.squad[#r.squad + 1] = uid end
    return R.set_hdl(r, slot, uid == 0 and 0 or hdl)
  end)
end

-- ---- Fichaje (§14 step 4)

local function recruit_offer(r)
  local c = cfg()
  local s = math.max(U.xor(U.xor(U.xor(r.seed, U.mul32(r.phase, 0x165667B1)), U.mul32(r.cur, 0x9E3779B9)), 0x00F1C4A5), 1)
  -- «What if»: its own seeded roll, so the normal offer of a node never changes
  local w = math.max(U.xor(s, 0x57171F00), 1)
  w = U.xs(w)
  if cfgm.whatif_recruit(c, r.phase, w) then
    local wp = Core.bank.whatif_pool()
    if #wp > 0 then
      w = U.xs(w)
      return wp[w % #wp + 1]
    end
  end
  local p = Core.bank.recruit_pool(cfgm.recruit_max_tier(c, r.phase))
  if #p == 0 then return nil end
  s = U.xs(s)
  return p[s % #p + 1]
end

function S.Recruit(op_arg, param_arg)
  local op = U.int(op_arg, 0)
  local c = cfg()
  if op == 0 then
    local x = with(function(i)
      local r = i.run
      if not r then return nil end
      local o = recruit_offer(r)
      if not o then return nil end
      return { o[1], o[2], R.free_bench_slot(r) or -1 }
    end)
    if not x then return false end
    return true, x[1], x[2], St.cost(c, x[2], 0), x[3], chara.is_whatif(x[1])
  end
  local param = U.u32(param_arg, 0)
  local code, uid = Core.bank.bank_add_param(param, "fichaje", Bk.SOURCE.RECRUIT)
  local slot = -1
  if uid ~= 0 then
    local e = edit("fichaje joins", function(r)
      local s = R.free_bench_slot(r)
      if s and R.find_uid(r, uid) == nil then
        R.set_slot(r, s, uid)
        slot = s
      end
      return C.OK
    end)
    if e ~= C.OK then slot = -1 end
  end
  info(string.format("fichaje %s -> code %d uid %d slot %d", U.hex(param), code, uid, slot))
  return code, uid, slot
end

function S.Launch(op_arg)
  local op = U.int(op_arg, 0)
  if op == 1 then launching = true elseif op == 2 then launching = false end
  return launching
end

-- §20 M4: the reward of a Cofre node / a won phase boss
function S.Loot(node_arg, salt_arg)
  local node = U.int(node_arg, -1)
  local salt = U.u32(salt_arg, loot.SALT.COFRE)
  local key = with(function(i)
    local r, m = i.run, i.map
    if not r or not m then return nil end
    local k = node < 0 and r.cur or node
    if k > 65535 then return nil end
    local n = map.node(m, k)
    if not n then return nil end
    return { r.seed, r.phase, k, n.kind == K.BOSS }
  end)
  if not key then return loot.KIND.NONE end
  local seed, phase, k, boss = key[1], key[2], key[3], key[4]
  local st = { s = loot.roll_seed(seed, phase, k, salt) }
  local catg = loot.category(st)
  if catg == loot.KIND.FORMATION then
    -- the Cofre rows of [rogue.formations] (a boss reward rolls the Cofre window too)
    local id, name, rarity, owned, total = Core.meta.formation_grant(U.xor(seed, salt), phase, k, 4)
    if id then
      info(string.format("loot node %d phase %d salt %d -> formation %s (%d*)", k, phase, salt, name, rarity))
      return loot.KIND.FORMATION, id, rarity, name, owned, total
    end
    catg = loot.KIND.MOVE -- nothing left / formations off: a move instead
  end
  local it = loot.item(catg, st, phase, boss and salt == loot.SALT.BOSS)
  if not it then return loot.KIND.NONE end
  info(string.format("loot node %d phase %d salt %d -> %s %s tier %d %s", k, phase, salt,
    it.kind == loot.KIND.GEAR and "gear" or "move", U.hex(it.id), it.tier, it.name))
  return it.kind, it.id, it.tier, it.name, 0, 0
end

-- (map.lua needs nothing else; the coach publish reads the run's handles through this)
function S.run_hdls()
  return with(function(i)
    if not i.run then return nil end
    return i.run
  end)
end

return S
