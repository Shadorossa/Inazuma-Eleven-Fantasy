-- Aura Points › the PEG / SP pools of the warrior spirits (docs/game/mechanics/aura-costs.md §12 / §14 / §18;
-- docs/refactor/aura-mods-split.md «Aura Points»). Declarations: content\game\aura_points.toml; settings: [points] of
-- config.toml; pools: content\match_resources\peg.toml / sp.toml (the VR-Framework's per-aura match resources
-- aura_points.peg / aura_points.sp). Split out of Inazuma Fantasy's scripts\stamina.lua on 2026-10-14.
--
-- Without this mod keshin, keshin armours and totems run on their time (retail). With it, once per match frame
-- (`tick`), per player on the pitch:
--   * a keshin / armour runs on its keshin's PEG pool, a totem on its SP bar: free start, no time limit (its time left
--     follows the pool, 0 at an empty pool in open play = the engine ends it); the armour's PEG per second of play
--     (Chrono Stone model: (KP + ATK) x k x scale, the first armour of a pool refills part of it; "if" model: boost,
--     then a flat drain); an empty pool refuses that aura for the rest of the match;
--   * the running spirit's own move (the keshin's special technique, its armour forms', the totem's) pays its PEG / SP
--     cost instead of tension (TensionPay pre); a fusion keshin's participants share the cost (the framework's aura
--     rules);
--   * the tables the native answers of AuraCostCheck read (content\game\aura_points.toml), exported for other mods:
--     AuraPoints.Aura (aura -> pool), AuraPoints.Player, AuraPoints.Pair, AuraPoints.Team;
--   * the HUD commands CMND_AURAPOINTS_PEG / _PEG_INFO (graft aura_points_hud; aliases CMND_EVT_PEG / _PEG_INFO for
--     the screens of other mods that ask them).
--
-- Inputs other mods give through rule flags (no `requires` needed; docs/refactor/aura-mods-split.md):
--   aura_points.free_peg / aura_points.free_sp  (non-zero) the user's pools of that resource never go down
--   aura_points.cost_pct.<hdl>                  (1..) percent of that player's PEG / SP costs and armour drain
--                                               (0 / unset = 100 %)
--   aura_points.exempt.<hdl>                    (non-zero) another mod owns that player's aura time: no pool for him
--   aura_points.armour_free.<hdl>               (non-zero) his armour neither drains nor ends

AuraPoints = AuraPoints or {}
local C = require "lib/cfg"
local A = require "lib/auras"
local ROUTE = require "lib/route"

local function info(...) VRFW.log("aura_points:", ...) end
local function warn(...) VRFW.warn("aura_points:", ...) end

local RAW = VRFW.files.config("points") or {}
local P = C.points(RAW)
local PEG, SP = "aura_points.peg", "aura_points.sp"

-- game layout (docs/game/mechanics/match-stamina.md §6 / §10, aura-costs.md)
local ACTOR_MAX, ACTOR_STRIDE = 0x3A, 0x570
local PEND_FLAG_NO_COST, PEND_FLAG_HYPER_GAUGE = 0x08, 0x10
local TENSION_PAY_KIND_SKILL = 8
local IN_PLAY = 9
local EMPTY_EPS = 1e-3
local MIN_LEFT_S = 0.5
local AURA_SLOT_CATEGORY = 8

-- the soccer states of live play (the armour drains only there): [points] live_states
local LIVE = {}
for _, s in ipairs(type(RAW.live_states) == "table" and RAW.live_states or { 9, 14, 15, 16 }) do LIVE[s] = true end

local band = bit32.band

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if not at or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function hex(v) return string.format("0x%X", v or 0) end
local function key_of(id) return A.key(id) end

local function flag(name) return VRFW.flag(name) or 0 end

-- ---------------------------------------------------------------------------------------------- per-match state

local seen = { in_match = false, ended = false, half = 0, clock = 0, end_half = 0 }
local match_no = 0
local frame = { state = 0, half = 0, clock = 0, user = 0xFF, dt = 0 }
local players = {}      -- hdl -> player record (this match)

local function new_player(hdl)
  return {
    hdl = hdl, team = 0xFF,
    tr = { keshin = false, armour = false, soul = false, cut_keshin = false, cut_soul = false, cut_armour = false,
      keshin_skill = 0, meta_skill = 0, armour_starts = {} },
    ctx = nil, last_pool = nil, slot_pool = nil,
  }
end

-- ---------------------------------------------------------------------------------------------- tables (diffs)

-- Record tables of the mod (exported, mod.toml [exports] tables; a missing field = the answers using it do not apply):
--   AuraPoints.Player (hdl): keshin_out_peg, spirit, armour, soul, cost, left;
--   AuraPoints.Pair (hdl, aura or move): empty (a pool empty this match), partner_cover, blocked; (hdl, a move of the
--     running spirit only, lib/route.lua): peg_cover (its pool covers it), own_blocked (CS: refused under the armour);
--   AuraPoints.Team (team): cost (the pools apply to it); key 255: armour_blocks_keshin_move.
-- A record is written when one of its fields changed (once per frame at most).
local recs = {}

local function rec_of(name, key)
  local t = recs[name]
  if not t then
    t = {}
    recs[name] = t
  end
  local k = type(key) == "table" and table.concat(key, ":") or tostring(key)
  local r = t[k]
  if not r then
    r = { key = key, fields = {}, dirty = false }
    t[k] = r
  end
  return r
end

local function rset(name, key, field, value)
  local r = rec_of(name, key)
  if r.fields[field] ~= value then
    r.fields[field] = value
    r.dirty = true
  end
end

local function pset(hdl, field, value) rset("AuraPoints.Player", hdl, field, value) end
local function pairset(hdl, id, field, value) rset("AuraPoints.Pair", { hdl, id }, field, value) end
local function teamset(team, field, value) rset("AuraPoints.Team", team, field, value) end

local function flush_records()
  for name, t in pairs(recs) do
    for _, r in pairs(t) do
      if r.dirty then
        r.dirty = false
        local v = next(r.fields) ~= nil and r.fields or nil
        pcall(VRFW.native.table_set, name, r.key, v)
      end
    end
  end
end

local cost_teams_user = nil

local function clear_match_tables()
  for _, n in ipairs({ "AuraPoints.Player", "AuraPoints.Pair", "AuraPoints.Team" }) do
    recs[n] = {}
    pcall(VRFW.native.table_clear, n)
  end
  cost_teams_user = nil
  rset("AuraPoints.Team", 255, "armour_blocks_keshin_move", P.armour_blocks_keshin_move() and 1 or 0)
  flush_records()
end

local function applies(team) return P.cpu or team == frame.user end

local function cost_teams()
  local u = frame.user
  if cost_teams_user == u then return end
  cost_teams_user = u
  for team = 0, 1 do
    teamset(team, "cost", applies(team) and 1 or nil)
  end
end

-- ---------------------------------------------------------------------------------------------- match boundaries

local function ends_match(s) return s == 2 or s == 3 or s == 6 or s == 7 or s == 8 or s == 22 or s == 24 end
local function restarts_play(s) return s == 9 or s == 10 end

local function log_pools()
  for team = 0, 1 do
    local line = {}
    for hdl, p in pairs(players) do
      if p.team == team then
        for k in pairs(p.tr.armour_starts) do
          local ok, v = pcall(VRFW.resource.get, PEG, hdl, k)
          if ok and v then line[#line + 1] = string.format("%s %s %.0f/%.0f armoured", hex(hdl), key_of(k), v.cur, v.max) end
        end
      end
    end
    if #line > 0 then info(string.format("armoured pools of the last match, T%d: %s", team, table.concat(line, "; "))) end
  end
end

local function start_match()
  match_no = match_no + 1
  if next(players) then log_pools() end
  players = {}
  clear_match_tables()
  info(string.format("match #%d start: h%d, user team %d (pools: the framework's %s / %s)", match_no, frame.half, frame.user, PEG, SP))
end

local function frame_update()
  local f = frame
  local b = "same"
  if f.half ~= 0 then
    if not seen.in_match or f.half < seen.half or (f.half == seen.half and f.clock + 60 < seen.clock) then
      b = "new"
    elseif seen.ended and restarts_play(f.state) then
      b = (f.half > seen.end_half) and "resume" or "new"
    end
  end
  if b == "new" then
    seen = { in_match = true, ended = false, half = f.half, clock = f.clock, end_half = 0 }
    start_match()
  elseif b == "resume" then
    seen.ended = false
  end
  if not seen.in_match then return end
  if ends_match(f.state) and not seen.ended then
    seen.ended = true
    seen.end_half = f.half
    for _, p in pairs(players) do
      p.ctx = nil
      p.tr.keshin, p.tr.armour, p.tr.soul = false, false, false
    end
  end
  seen.half = f.half
  seen.clock = f.clock
end

-- ---------------------------------------------------------------------------------------------- pools (PEG / SP)

local function covers(cur, cost) return cur > EMPTY_EPS and cur + EMPTY_EPS >= math.max(cost, 0) end

local function is_soul_pool(k) return A.type(k) == 3 end
local function pool_res(k) return is_soul_pool(k) and SP or PEG end

-- the pool aura of an aura: a keshin itself, an armour's keshin (PEG), a totem itself (SP); nil = not on a pool
local function pool_aura_of(aura)
  local ty = A.type(aura)
  if ty == 0 and P.peg() then return aura end
  if ty == 1 and P.peg() then return A.spirit(aura) end
  if ty == 3 and P.sp() then return aura end
  return nil
end

local function pool_info(k)
  local ok, pi = pcall(VRFW.resource.pool, pool_res(k), k)
  if ok and pi then return pi end
  return { max = 200, move_cost = 60, row = false }
end

local function pool_get(hdl, k)
  local ok, v = pcall(VRFW.resource.get, pool_res(k), hdl, k)
  if ok then return v end
  return nil
end

-- rule flags aura_points.free_peg / free_sp: the user's players' pools of that resource never go down
local FREE_FLAG = { [PEG] = "aura_points.free_peg", [SP] = "aura_points.free_sp" }
local function pool_free(res, hdl)
  if flag(FREE_FLAG[res]) == 0 then return false end
  local ok, a = pcall(VRFW.actor, hdl)
  return ok and a ~= nil and a.side == "user"
end

local function pool_add(hdl, k, amount)
  local res = pool_res(k)
  if amount < 0 and pool_free(res, hdl) then return true end
  local ok, r = pcall(VRFW.resource.add, res, hdl, amount, false, k)
  return ok and r
end

local function move_cost_of(k) return pool_info(k).move_cost or 0 end

local function atk_of(k)
  local ok, v = pcall(VRFW.resource.pool_value, PEG, k, "atk")
  if ok and type(v) == "number" and v > 0 then return v end
  return P.default_atk
end

-- pay `cost` (refused when the pool does not cover it, unless committed: then down to 0). Returns what is left or nil.
local function pool_pay(hdl, k, cost, committed)
  local v = pool_get(hdl, k)
  if not v then return nil end
  if pool_free(pool_res(k), hdl) then return v.cur end
  cost = math.max(cost, 0)
  if not covers(v.cur, cost) then
    if not committed then return nil end
    cost = math.min(cost, v.cur)
  end
  pool_add(hdl, k, -cost)
  local left = v.cur - cost
  if left <= EMPTY_EPS then
    if left > 0 then pool_add(hdl, k, -left) end
    left = 0
  end
  return left
end

-- the framework's aura rules (group keshin); nil = not a group
local function aura_rule(fn, ...)
  if not (VRFW.aura_rule and VRFW.aura_rule[fn]) then return nil end
  local ok, a, b, c = pcall(VRFW.aura_rule[fn], ...)
  if ok then return a, b, c end
  return nil
end

-- the other mods' inputs for one player (rule flags)
local function cost_factor(hdl)
  local v = flag("aura_points.cost_pct." .. hdl)
  if v > 0 then return v / 100 end
  return 1.0
end
local function exempt(hdl) return flag("aura_points.exempt." .. hdl) ~= 0 end
local function armour_free(hdl) return flag("aura_points.armour_free." .. hdl) ~= 0 end

-- (ok, mine, cost) of a pool move of player p now (nil = not a pool move now): the running pool covers its share
local function pool_move_check(p, skill)
  if not A.is_spirit_move(skill) or A.type(skill) ~= nil then return nil end
  local ctx = p.ctx
  if ctx and ctx.armour and not ctx.soul and P.armour_moves_free() then return nil end
  if not ctx then
    -- a partner of a running fusion keshin using its move: every participant's pool covers his share
    local mv, spirit, members = aura_rule("partner_move", p.hdl)
    if not mv or mv ~= skill or type(members) ~= "table" then return nil end
    local k = pool_aura_of(spirit)
    if not k then return nil end
    local share = move_cost_of(k) / math.max(#members, 1)
    local ok, mine = true, nil
    for _, h in ipairs(members) do
      local v = pool_get(h, k)
      local cur = v and v.cur or pool_info(k).max
      if h == p.hdl then mine = cur end
      if not covers(cur, share) then ok = false end
    end
    return ok, mine or pool_info(k).max, share
  end
  if not ROUTE.is_own_move(A, ctx, skill) then return nil end
  local partners = aura_rule("shared_partners", p.hdl, ctx.key) or {}
  local cost = ctx.move_cost / (1 + #partners)
  local v = pool_get(p.hdl, ctx.key)
  local left = v and v.cur or 0
  local ok = covers(left, cost)
  for _, h in ipairs(partners) do
    local pv = pool_get(h, ctx.key)
    if not covers(pv and pv.cur or pool_info(ctx.key).max, cost) then ok = false end
  end
  return ok, left, cost
end

-- ---------------------------------------------------------------------------------------------- the aura step

local function hold_left(full, ratio)
  if not (full == full and full > 0) then full = 60 end
  if ratio ~= ratio then ratio = 1 end
  ratio = math.min(math.max(ratio, 0), 1)
  return math.max(full * ratio, MIN_LEFT_S)
end

-- the first pool aura among his move slots (the bar before he summons: «the pool his keshin would get»)
local function slot_pool_of(unit)
  if not unit then return nil end
  for i = 0, 5 do
    local s, c = unit["s" .. i], unit["c" .. i]
    if c == AURA_SLOT_CATEGORY and s and s ~= 0 then
      local k = pool_aura_of(s)
      if k then return k end
    end
  end
  return nil
end

-- One player's spirits this frame.
local function aura_step(p, actor, a, unit, live, dt)
  local hdl, team = p.hdl, p.team
  local attr = unit and unit.attr or 0
  local ss, ms = a.summon_state, a.meta_state
  local meta_run = ms == 4 or ms == 5
  local keshin = band(attr, 1) ~= 0 and ss == 2 and P.peg()
  local armour = band(attr, 2) ~= 0 and meta_run and P.peg()
  local soul = band(attr, 8) ~= 0 and ss == 2 and band(attr, 1) == 0 and P.sp()
  local in_play = frame.state == IN_PLAY
  local tr = p.tr
  local ctx = nil
  local cut = cost_factor(hdl)
  local free_armour = armour and armour_free(hdl)

  if applies(team) and (keshin or armour or soul) and not exempt(hdl) then
    local aura_id = armour and a.meta_skill or a.summon_skill
    local k = pool_aura_of(aura_id)
    if k then
      local pi = pool_info(k)
      local kp = pi.max
      local mcost = (pi.move_cost or 0) * cut
      local atk = atk_of(k)
      local drain_per_s = P.armour_drain_per_s(kp, atk, false)
      local members = aura_rule("members_of", hdl, k)
      local group = (type(members) == "table" and #members > 1) and members or nil
      local v = pool_get(hdl, k)
      if v and not v.touched then
        pool_add(hdl, k, 0)
        info(string.format("actor %s T%d: %s of %s = %.0f (%s), its move costs %.0f", hex(hdl), team,
          soul and "SP bar" or "PEG pool", key_of(k), kp, pi.row and "table" or "default", mcost))
        v = pool_get(hdl, k)
      elseif v and not tr.keshin and not tr.armour and not tr.soul then
        info(string.format("actor %s T%d: %s out again: %s %.0f/%.0f (the pool of this match)", hex(hdl), team, key_of(aura_id),
          soul and "SP" or "PEG", v.cur, v.max))
      end
      if armour and not tr.armour then
        local starts = tr.armour_starts[k] or 0
        tr.armour_starts[k] = starts + 1
        local b = v
        if P.cs() then
          -- the first armour of this pool in the match restores cs_armour_first_refill of max PEG
          if starts == 0 and P.cs_armour_first_refill > 0 and b then pool_add(hdl, k, P.cs_armour_first_refill * b.max) end
          local aft = pool_get(hdl, k)
          if b and aft then
            info(string.format("actor %s T%d: armour %s on %s: %s PEG %.0f/%.0f -> %.0f/%.0f, then %.2f PEG/s (KP %.0f + ATK %.0f)",
              hex(hdl), team, key_of(aura_id), key_of(k), starts == 0 and string.format("first armour of the match: +%.0f %% of max", P.cs_armour_first_refill * 100) or "not the first armour: no refill",
              b.cur, b.max, aft.cur, aft.max, drain_per_s, kp, atk))
          end
        else
          pcall(VRFW.resource.scale, PEG, hdl, k, P.armour_boost)
          local aft = pool_get(hdl, k)
          if b and aft then
            info(string.format("actor %s T%d: armour %s on %s: PEG x%s %.0f/%.0f -> %.0f/%.0f, then %s PEG/s", hex(hdl), team, key_of(aura_id), key_of(k),
              P.armour_boost, b.cur, b.max, aft.cur, aft.max, drain_per_s))
          end
        end
      end
      if armour and in_play and live and dt > 0 and dt < 1 and not free_armour then
        if not group then
          local cur = pool_get(hdl, k)
          if cur and cur.cur > EMPTY_EPS then
            local d = math.min(drain_per_s * cut * dt, cur.cur)
            pool_add(hdl, k, -d)
            if cur.cur - d <= EMPTY_EPS and cur.cur - d > 0 then pool_add(hdl, k, -(cur.cur - d)) end
          end
        else
          -- split over every participant who still has PEG of it
          local holders = {}
          for _, h in ipairs(group) do
            local gv = pool_get(h, k)
            if gv and not gv.touched then
              pool_add(h, k, 0)
              gv = pool_get(h, k)
            end
            if gv and gv.cur > EMPTY_EPS then holders[#holders + 1] = { h, gv.cur } end
          end
          if #holders > 0 then
            local per = drain_per_s * cut / #holders
            for _, hv in ipairs(holders) do
              pool_add(hv[1], k, -math.min(per * dt, hv[2]))
            end
          end
        end
      end
      ctx = { key = k, aura = aura_id, armour = armour, soul = soul, move_cost = mcost }
      p.last_pool = k
      -- the hold: this pool (a group keshin: the participants' pools together)
      local cur, max = 0, 0
      if group then
        for _, h in ipairs(group) do
          local gv = pool_get(h, k)
          cur = cur + (gv and gv.cur or kp)
          max = max + (gv and gv.max or kp)
        end
      else
        local pv = pool_get(hdl, k)
        cur, max = pv and pv.cur or kp, pv and pv.max or kp
      end
      local empty = cur <= EMPTY_EPS
      if not (empty and in_play) then
        local ratio = empty and 0 or ((max > 0) and math.min(math.max(cur / max, 0), 1) or 0)
        if keshin or soul then wr("f32", actor + 0x370, hold_left(a.summon_full, ratio)) end
        if armour then wr("f32", actor + 0x39C, hold_left(a.meta_full, free_armour and 1 or ratio)) end
      else
        if soul then
          wr("f32", actor + 0x370, 0)
          if not tr.cut_soul then
            tr.cut_soul = true
            info(string.format("actor %s T%d: SP empty: totem %s leaves (time 0; no SP for it until the next match)", hex(hdl), team, key_of(a.summon_skill)))
          end
        end
        if keshin then
          wr("f32", actor + 0x370, 0)
          if not tr.cut_keshin then
            tr.cut_keshin = true
            info(string.format("actor %s T%d: PEG empty: keshin %s dismissed (time 0; no PEG for it until the next match)", hex(hdl), team, key_of(a.summon_skill)))
          end
        end
        if armour and free_armour then
          wr("f32", actor + 0x39C, hold_left(a.meta_full, 1))
        elseif armour then
          wr("f32", actor + 0x39C, 0)
          if not tr.cut_armour then
            tr.cut_armour = true
            info(string.format("actor %s T%d: PEG empty: armour %s ends (time 0; its keshin is done for the match)", hex(hdl), team, key_of(aura_id)))
          end
        end
      end
      -- an empty pool refuses its starts for the match
      local own = pool_get(hdl, k)
      if own and own.touched and own.cur <= EMPTY_EPS then
        pairset(hdl, k, "empty", 1)
        for _, arm in ipairs(A.armours_of(k)) do pairset(hdl, arm, "empty", 1) end
      end
    elseif aura_id ~= 0 and tr.keshin_skill ~= aura_id and tr.meta_skill ~= aura_id then
      warn(string.format("actor %s T%d: aura %s has no keshin for a PEG pool: its own timer runs", hex(hdl), team, key_of(aura_id)))
    end
  end
  p.ctx = ctx

  -- ends
  if tr.keshin and not keshin then
    info(string.format("actor %s T%d: keshin %s over (summon state %d)%s", hex(hdl), team, key_of(tr.keshin_skill), ss, tr.cut_keshin and ": PEG empty" or ""))
  end
  if tr.armour and not armour then
    info(string.format("actor %s T%d: armour %s over (meta state %d)%s", hex(hdl), team, key_of(tr.meta_skill), ms, tr.cut_armour and ": PEG empty" or ""))
  end
  if tr.soul and not soul then
    info(string.format("actor %s T%d: totem over (summon state %d)%s", hex(hdl), team, ss, tr.cut_soul and ": SP empty" or ""))
  end
  if not keshin then tr.cut_keshin = false end
  if not armour then tr.cut_armour = false end
  if not soul then tr.cut_soul = false end
  tr.keshin, tr.armour, tr.soul = keshin, armour, soul
  if keshin then tr.keshin_skill = a.summon_skill end
  if armour then tr.meta_skill = a.meta_skill end
  p.slot_pool = slot_pool_of(unit) or p.slot_pool
end

-- the tables the AuraCostCheck answers read, for one player
local function publish(p)
  local hdl = p.hdl
  local ctx = p.ctx
  local cs_armour_on = ctx and ctx.armour and not ctx.soul
  -- the running spirit's own moves (lib/route.lua): only they are paid from its pool (peg_cover) and, CS, refused under
  -- its armour (own_blocked); his other moves keep the tension
  local own = ROUTE.own_moves(A, ctx)
  local blocked_on = cs_armour_on and P.armour_blocks_keshin_move()
  local cover = nil
  if ctx and not (cs_armour_on and P.armour_moves_free()) then
    local ok = nil
    for m in pairs(own) do
      if ok == nil then ok = select(1, pool_move_check(p, m)) end
    end
    if ok == nil then
      local v = pool_get(hdl, ctx.key)
      ok = v ~= nil and covers(v.cur, ctx.move_cost)
    end
    if P.move_tension_free then cover = ok and 1 or 0 elseif not ok then cover = 0 end
  end
  for m in pairs(p.own_mvs or {}) do
    if not own[m] then
      pairset(hdl, m, "peg_cover", nil)
      pairset(hdl, m, "own_blocked", nil)
    end
  end
  for m in pairs(own) do
    pairset(hdl, m, "peg_cover", cover)
    pairset(hdl, m, "own_blocked", blocked_on and 1 or nil)
  end
  p.own_mvs = own
  -- a partner of a running fusion keshin: its move
  local mv = aura_rule("partner_move", hdl)
  if not ctx and mv and mv ~= 0 then
    local okp = pool_move_check(p, mv)
    if okp ~= nil then
      pairset(hdl, mv, "partner_cover", okp and 1 or 0)
      p.partner_mv = mv
    end
  elseif p.partner_mv then
    pairset(hdl, p.partner_mv, "partner_cover", nil)
    p.partner_mv = nil
  end
  -- CS, group keshin: a participant's armour blocks the keshin's move for the whole group
  if P.armour_blocks_keshin_move() then
    local gm = (ctx and A.aura_move(ctx.key)) or mv
    if gm and gm ~= 0 then
      local blocked = aura_rule("move_blocked_by_armour", hdl, gm)
      pairset(hdl, gm, "blocked", blocked and 1 or nil)
      p.blocked_mv = gm
    elseif p.blocked_mv then
      pairset(hdl, p.blocked_mv, "blocked", nil)
      p.blocked_mv = nil
    end
  end
  -- CS keshin out (no armour, no totem), cs_keshin_moves_cost = "peg" only: every other move costs its tension in PEG
  local kop = nil
  if ctx and not ctx.armour and not ctx.soul and P.keshin_moves_all_peg() then
    local v = pool_get(hdl, ctx.key)
    kop = v and v.cur or 0
  end
  pset(hdl, "keshin_out_peg", kop)
  -- the running pool (other mods' plates)
  if ctx then
    local v = pool_get(hdl, ctx.key)
    pset(hdl, "spirit", ctx.key)
    pset(hdl, "armour", ctx.armour and 1 or 0)
    pset(hdl, "soul", ctx.soul and 1 or 0)
    pset(hdl, "cost", ctx.move_cost)
    pset(hdl, "left", v and math.floor(v.cur * 100 + 0.5) / 100 or 0)
  else
    for _, f in ipairs({ "spirit", "armour", "soul", "cost", "left" }) do pset(hdl, f, nil) end
  end
end

local UNIT_REREAD_MS = 2000

local function step_player(p, actor, a)
  -- his match unit (aura bits, move slots): every frame while a spirit runs or was running, else every UNIT_REREAD_MS
  local now = VRFW.now()
  local running = a.summon_state == 2 or a.meta_state == 4 or a.meta_state == 5
  local tracked = p.tr.keshin or p.tr.armour or p.tr.soul
  local unit = nil
  if running or tracked or now - (p.unit_ms or -UNIT_REREAD_MS) >= UNIT_REREAD_MS then
    local ok, u = pcall(VRFW.call, "ApActorUnit", actor)
    if ok and type(u) == "number" and u >= 0x10000 then
      unit = VRFW.mem.read_struct("ApUnit", u)
      p.unit_ms = now
    end
  end
  local live = LIVE[frame.state] and a.in_play ~= 0 and frame.dt > 0 and frame.dt < 1
  aura_step(p, actor, a, unit, live, frame.dt)
end

VRFW.on("tick", function(ev)
  if not P.any() then return nil end
  local m = ev.match or {}
  frame.state = m.soccer_state or 0
  frame.half = m.half or 0
  frame.clock = m.clock or 0
  frame.user = m.user_team or 0xFF
  frame.dt = m.dt or 0
  if frame.half == 0 then return nil end
  frame_update()
  if not seen.in_match or seen.ended then return nil end
  cost_teams()
  local base = global("ap_actors")
  if not base then return nil end
  for i = 0, ACTOR_MAX - 1 do
    local actor = base + i * ACTOR_STRIDE
    local a = VRFW.mem.read_struct("ApActor", actor)
    if a and a.hdl ~= 0 and band(a.hdl, 0xFF) == i and a.team <= 1 then
      local p = players[a.hdl]
      if not p then
        p = new_player(a.hdl)
        players[a.hdl] = p
      end
      p.team = a.team
      step_player(p, actor, a)
      publish(p)
    end
  end
  flush_records()
  return nil
end)

-- ---------------------------------------------------------------------------------------------- the pays

-- ProcessPending pre (a pending aura start): a keshin / armour / totem on its pool starts without the hyper gauge (flag 8)
VRFW.on("hook:Ap_PendingPay", function(ev)
  if not P.any() then return nil end
  local actor = ev.args[1]
  if type(actor) ~= "number" or actor < 0x10000 then return nil end
  if (rd("u8", actor + 0x1A8) or 0) == 0 then return nil end
  local a = VRFW.mem.read_struct("ApActor", actor)
  if not a then return nil end
  local flags = a.pend_flags
  if band(flags, PEND_FLAG_HYPER_GAUGE) == 0 or band(flags, PEND_FLAG_NO_COST) ~= 0 then return nil end
  if not applies(a.team) then return nil end
  local skill = nil
  for _, id in ipairs({ a.pend_skill, a.pend_skill2 }) do
    if not skill and A.type(id) ~= nil then skill = id end
  end
  if not skill or not pool_aura_of(skill) then return nil end
  if wr("u32", actor + 0x1A0, bit32.bor(flags, PEND_FLAG_NO_COST)) then
    info(string.format("actor %s: %s (0x%08X, auraType %d) starts on its pool, without the hyper gauge", hex(a.hdl), key_of(skill), skill, A.type(skill)))
  end
  return nil
end)

-- TensionPay pre: the pool moves pay here, once (aura-costs.md §12.3)
VRFW.on("hook:Ap_TensionPay", function(ev)
  if not P.any() then return nil end
  local req = ev.args[1]
  if type(req) ~= "number" or req < 0x10000 then return nil end
  if (rd("u8", req + 4) or 0) ~= TENSION_PAY_KIND_SKILL then return nil end
  local hdl = rd("u32", req + 8) or 0
  local cost = rd("i32", req) or 0
  local p = players[hdl]
  if hdl == 0 or not p or not applies(p.team) or exempt(hdl) then return nil end
  local base = global("ap_actors")
  local actor = base and base + band(hdl, 0xFF) * ACTOR_STRIDE
  local a = actor and VRFW.mem.read_struct("ApActor", actor)
  if not a or a.hdl ~= hdl then return nil end
  -- the pending record is still filled while ProcessPending pays (kind 3: the id at +0x18C first)
  local ids = { a.pend_kind == 3 and a.pend_skill2 or a.pend_skill, a.pend_skill, a.pend_skill2 }
  local ctx = p.ctx
  if ctx then
    -- who pays (lib/route.lua): only the running spirit's own move pays its pool; every other move pays the tension
    -- as without a spirit (CS cs_keshin_moves_cost = "peg": in PEG)
    local route, skill = ROUTE.route(A, P, ctx, ids, cost)
    if route == "keshin_out_peg" then
      local left = pool_pay(hdl, ctx.key, cost, true) or 0
      wr("i32", req, 0)
      info(string.format("actor %s T%d: keshin out: move 0x%08X costs its tension %d in PEG (CS), no tension: %.0f PEG left%s", hex(hdl), p.team,
        skill or 0, cost, left, left <= EMPTY_EPS and ": PEG empty, the keshin is dismissed" or ""))
    elseif route == "spirit" then
      -- the running keshin's / armour's / totem's own move: its PEG / SP here, exactly once, and no tension
      local partners = aura_rule("shared_partners", hdl, ctx.key) or {}
      local share = ctx.move_cost / (1 + #partners)
      for _, h in ipairs(partners) do
        local l = pool_pay(h, ctx.key, share, true) or 0
        info(string.format("group keshin %s of %s: partner %s pays his share %.1f PEG: %.0f left", key_of(ctx.key), hex(hdl), hex(h), share, l))
      end
      local left = pool_pay(hdl, ctx.key, share, true)
      if left then
        local v = pool_get(hdl, ctx.key)
        info(string.format("actor %s T%d: %s move 0x%08X costs %.0f %s: %.0f/%.0f left%s", hex(hdl), p.team,
          ctx.soul and "totem" or (ctx.armour and "armour" or "keshin"), skill, share, ctx.soul and "SP" or "PEG", left, v and v.max or 0,
          left <= EMPTY_EPS and (ctx.soul and ": SP empty, the totem leaves" or ": PEG empty, the keshin is dismissed") or ""))
      end
      if P.move_tension_free and cost ~= 0 then wr("i32", req, 0) end
    end
    -- "armour_free" (CS: the armoured player's move pays no PEG) and "tension": the tension rules of the other mods
    return nil
  end
  -- no spirit out: a partner of a running fusion keshin using its move: every participant pays his share
  local skill = nil
  for _, id in ipairs(ids) do
    if not skill and A.is_spirit_move(id) and A.type(id) == nil then skill = id end
  end
  local mv, spirit, members = aura_rule("partner_move", hdl)
  if skill and mv and mv == skill and type(members) == "table" then
    local k = pool_aura_of(spirit)
    if k then
      local share = move_cost_of(k) / math.max(#members, 1)
      local left = {}
      for _, h in ipairs(members) do
        left[#left + 1] = string.format("%s %.0f", hex(h), pool_pay(h, k, share, true) or 0)
      end
      info(string.format("fusion keshin %s: participant %s used its move 0x%08X: %.1f PEG from each of %d (left: %s)", key_of(k), hex(hdl), skill,
        share, #members, table.concat(left, ", ")))
      if P.move_tension_free and cost ~= 0 then wr("i32", req, 0) end
    end
  end
  return nil
end)

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_AURAPOINTS_PEG(hdl) (alias CMND_EVT_PEG) -> ok, cur, max, active, armour, pegMode (1), source (1 running,
-- 2 last, 3 an aura of his move slots), soul. Nothing outside a match / for hdl 0.
function AuraPoints.Peg(hdl)
  hdl = tonumber(hdl) or 0
  local p = players[hdl]
  if not P.any() or hdl == 0 or not p or not seen.in_match or seen.ended then return false, 0, 0, 0, 0, P.any() and 1 or 0, 0, 0 end
  local function answer(k, active, armour, source)
    local v = pool_get(hdl, k)
    if not v then return nil end
    return true, v.cur, v.max, active and 1 or 0, armour and 1 or 0, 1, source, is_soul_pool(k) and 1 or 0
  end
  if p.ctx then
    local r = { answer(p.ctx.key, true, p.ctx.armour, 1) }
    if r[1] then return table.unpack(r) end
  end
  if p.last_pool then
    local r = { answer(p.last_pool, false, false, 2) }
    if r[1] then return table.unpack(r) end
  end
  if p.slot_pool and applies(p.team) and not exempt(hdl) then
    local r = { answer(p.slot_pool, false, false, 3) }
    if r[1] then return table.unpack(r) end
  end
  return false, 0, 0, 0, 0, 1, 0, 0
end

-- CMND_AURAPOINTS_PEG_INFO(aura) (alias CMND_EVT_PEG_INFO) -> ok, kind (1 PEG, 2 SP), pool, moveCost,
-- armourMovesFree: what a card shows (no match)
function AuraPoints.PegInfo(aura)
  aura = tonumber(aura) or 0
  A.load()
  local k = pool_aura_of(aura)
  if not k then return false, 0, 0, 0, 0 end
  local pi = pool_info(k)
  return true, is_soul_pool(k) and 2 or 1, math.floor((pi.max or 0) + 0.5), math.floor((pi.move_cost or 0) + 0.5),
    (A.type(aura) == 1 and P.armour_moves_free()) and 1 or 0
end

-- ---------------------------------------------------------------------------------------------- start

local function start()
  if not P.any() then
    info("[points] peg = false and sp = false: keshin, armours and totems run on their time (retail)")
    return
  end
  A.load()
  local n_pool, n_moves = A.publish(function(id) return pool_aura_of(id) ~= nil end)
  clear_match_tables()
  info(string.format("active: PEG %s, SP %s; %d auras run on a pool, %d spirit moves; cost model %s (scale %s); pool moves %s; CPU %s; hooks: cost check %s, pending pay %s, tension pay %s",
    P.peg() and "on" or "off", P.sp() and "on" or "off", n_pool, n_moves, P.cs() and "CS" or "IF", P.cs_scale(),
    P.keshin_moves_all_peg() and "the spirit's own moves + (keshin out) every move's tension" or "only the running spirit's own moves",
    tostring(P.cpu), tostring(VRFW.is_on("Ap_AuraCostCheck")), tostring(VRFW.is_on("Ap_PendingPay")), tostring(VRFW.is_on("Ap_TensionPay"))))
end

start()
