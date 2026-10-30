-- InaRogue › INAROGUE: the run time of the item blocks (lib/rogue/blocks.lua): counters, triggers, chances and grants
-- of the run's rogue items, and the blocks' context the stat and Shop aggregators read (lib/rogue/effects.lua).
--   * kick-off effects (no match-state condition, no match counter): InaRogue.CoachMult / CoachAdd (svc_meta
--     coach_sync) with their conditions per player and the stacks of their run / phase / roster counters;
--   * live effects (score, half, minute, a match counter or a timer): VRFW.set_stat on the user's players, again on
--     every change; technique_power_multiplier / technique_free_until_broken answer move_power / tension_pay through
--     lib/rogue/svc_pieces.lua;
--   * match triggers step the counters in memory; run / phase counts and the grants that need the run (points, items,
--     players, stat buffs) are written when the result is recorded (svc_run Result); route-map triggers (phase end,
--     node cleared, Tienda line) edit the run at once.
-- Saved counts: the owned item's `counters` in rogue_run.json: "<effect>" count, "<effect>b" matches left of a stat
-- buff, "<effect>r" chance rolls (the effect number = its position in the item's list). Charges live in one match.

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local E = require "lib/rogue/effects"
local B = require "lib/rogue/blocks"
local Items = require "lib/rogue/items"
local chara = require "lib/rogue/chara"
local info, warn = U.logger("rogue blocks")

local S = {}

-- the match's live states, period timers and minute / score / half changes (the timers count only in live play)
local Live = require "VRFW/lib/match_live"
-- a move's charge is spent once per player and move within this window (move_power is asked more than once)
local CHARGE_WINDOW_MS = 8000

local M = nil       -- the INAROGUE match in progress (match_start .. match_end)
local carry = nil   -- what the match leaves for the result: { pending = { [item] = { [name] = delta } }, grants = { … } }
local pending_logged = {}

local function name_of(e, suffix) return tostring(e.index or 0) .. (suffix or "") end
local function id_of(e) return (e.item or "?") .. "#" .. tostring(e.index or 0) end

local function owned_of(r, key)
  for _, o in ipairs(r and r.items or {}) do
    if o.key == key then
      o.counters = o.counters or {}
      return o
    end
  end
  return nil
end

local function log_pending(e, what)
  local k = id_of(e) .. what
  if pending_logged[k] then return end
  pending_logged[k] = true
  info(string.format("item %s effect %d: %s is pending an engine hook (no effect yet)", tostring(e.item), e.index or 0, what))
end

-- ---------------------------------------------------------------------------------------- contexts

-- a run player for the blocks: card, element, position, stars, team slot, bank uid
function S.player_of(slot, uid)
  local param = (uid and uid ~= 0) and Core.bank.bank_entry(uid) or nil
  local ci = param and chara.get(param) or nil
  return { card = param or 0, element = ci and ci.element or 0, position = ci and ci.position or 0,
    tier = ci and chara.shown_tier(ci) or 0, slot = slot, uid = uid }
end

local function uid_at(r, k)
  if #r.slots == 0 then return r.squad[k + 1] end
  return r.slots[k + 1]
end

-- the run part of the blocks' context: phase, node kind in progress, inventory, items per archetype, team
function S.run_ctx(r)
  if not r then return nil end
  local roster = {}
  for k = 0, 19 do
    local uid = uid_at(r, k)
    if uid and uid ~= 0 then roster[#roster + 1] = S.player_of(k, uid) end
  end
  local counts = {}
  local _, _, by_number = Items.archetype(r.items)
  for n, key in ipairs(Items.archetype_keys()) do counts[key] = by_number[n] or 0 end
  local node_kind = Core.run and Core.run.node_kind and Core.run.node_kind(r) or nil
  return { phase = r.phase, node_kind = node_kind, items = r.items, archetype_counts = counts, roster = roster, run = r }
end

-- the count of an effect's counter now: saved count + this match's count not yet saved (roster: the players)
local function count_now(e, rc)
  local c = e.count
  if c.kind == "count_roster" then return B.roster_count(rc, c.players, c.where_in) end
  if c.scope == "match" or c.kind == "count_timer" or not e.item then return M and M.counts[id_of(e)] or 0 end
  local o = owned_of(rc and rc.run, e.item)
  local n = o and o.counters[name_of(e)] or 0
  local p = carry and carry.pending[e.item]
  return n + (p and p[name_of(e)] or 0)
end

local function stacks_of(e, rc)
  if not e.count then return 0 end
  return B.stacks(e.count, count_now(e, rc))
end

-- the full context of a player (or of the run alone with p = nil) for the aggregators
function S.ctx(rc, p, match)
  return { player = p, run = rc, match = match, stacks = function(e) return stacks_of(e, rc) end }
end

-- the stat buffs (grant_stat_buff) with matches left, as stat_multiplier effects for the kick-off tables
function S.buff_effects(r)
  local out = {}
  for _, e in ipairs(r and Items.all_effects(r.items) or {}) do
    if e.kind == "grant_stat_buff" then
      local o = owned_of(r, e.item)
      if o and (o.counters[name_of(e, "b")] or 0) > 0 then
        out[#out + 1] = { kind = "stat_multiplier", target = { kind = "team" }, value = e.value,
          stat = e.stat ~= "all" and U.index_of(B.STATS, e.stat) or nil,
          when = { { name = "when_in_team", spec = e.players, needs = "player" } } }
      end
    end
  end
  return out
end

-- the Shop's price multiplier of the run's items (shop_cost_multiplier)
function S.shop_mult(r)
  if not r then return 1.0 end
  return E.shop_cost_mult(Items.effects(r.items, "outside"), S.ctx(S.run_ctx(r), nil, nil))
end

-- ---------------------------------------------------------------------------------------- chance and grants

local function roll(e, o, r)
  if not e.chance then return true end
  local n = 0
  if o then
    n = (o.counters[name_of(e, "r")] or 0) + 1
    o.counters[name_of(e, "r")] = n
  elseif M then
    M.rolls = M.rolls + 1
    n = M.rolls
  end
  local ok, g = pcall(VRFW.rng, "InaRogue.blocks", { r and r.seed or 0, r and r.phase or 0, e.item or "", e.index or 0, n })
  if not ok or not g then return false end
  return g:below(e.chance.n) == 0
end

-- a grant that needs the run: done after the run is saved (points, items, players); buffs go in the run edit
local function run_grant(e)
  if e.kind == "grant_points" then
    local got = Core.meta.earn_bonus(e.amount, "item " .. tostring(e.item))
    info(string.format("item %s: grant_points %d", tostring(e.item), got))
  elseif e.kind == "grant_item" then
    local key = e.item_key
    local Si = require "lib/rogue/svc_items"
    local code = key and Si.Add(key) or -1
    info(string.format("item %s: grant_item %s -> code %s", tostring(e.item), tostring(key), tostring(code)))
  elseif e.kind == "grant_player" then
    local code, uid = -1, 0
    if e.param then code, uid = Core.bank.bank_add_param(e.param, "item " .. tostring(e.item), require("lib/rogue/bank").SOURCE.OTHER) end
    info(string.format("item %s: grant_player %s -> code %s uid %s", tostring(e.item), U.hex(e.param or 0),
      tostring(code), tostring(uid)))
  end
end

-- the concrete grant of `e` now (an item / player drawn with the run's generator), queued in `out`
local function prepare_grant(e, r, out)
  if e.pending then
    log_pending(e, e.kind)
    return
  end
  local g = { kind = e.kind, item = e.item, amount = e.amount }
  if e.kind == "grant_item" then
    if e.give then
      g.item_key = e.give
    else
      local cands = {}
      for _, d in ipairs(Items.catalogue().list) do
        if d.kind == "passive" and d.rarity <= (e.rarity_max or 99) and not owned_of(r, d.key) then cands[#cands + 1] = d.key end
      end
      if #cands == 0 then return end
      local ok, rng = pcall(VRFW.rng, "InaRogue.blocks.item", { r.seed, r.phase, e.item or "", #r.items })
      g.item_key = (ok and rng) and cands[rng:below(#cands) + 1] or cands[1]
    end
  elseif e.kind == "grant_player" then
    local cands = {}
    for _, param in ipairs(chara.table().pool) do
      local ci = chara.get(param)
      local p = { card = param, element = ci.element, position = ci.position, tier = chara.shown_tier(ci) }
      if B.player_matches(e.players, p) then cands[#cands + 1] = param end
    end
    if #cands == 0 then
      info(string.format("item %s: grant_player: no card of the draw pool passes the filter", tostring(e.item)))
      return
    end
    local ok, rng = pcall(VRFW.rng, "InaRogue.blocks.player", { r.seed, r.phase, e.item or "", r.won })
    g.param = (ok and rng) and cands[rng:below(#cands) + 1] or cands[1]
  elseif e.kind == "grant_stat_buff" then
    local o = owned_of(r, e.item)
    if o then o.counters[name_of(e, "b")] = e.matches end
    info(string.format("item %s: grant_stat_buff %s x%.3f for %d match(es)", tostring(e.item), e.stat, e.value, e.matches))
    return
  end
  out[#out + 1] = g
end

-- a grant during a match: resources at once, the rest after the result
local function match_grant(e, ev)
  if e.kind == "grant_resource" then
    local hdls = {}
    if e.who == "team" then
      for h in pairs(M.roster) do hdls[#hdls + 1] = h end
    elseif ev.actor and ev.actor.hdl then
      hdls[1] = ev.actor.hdl
    end
    for _, h in ipairs(hdls) do
      if e.resource == "tension" then
        pcall(VRFW.add_tension, e.amount)
        break
      end
      local amount = e.amount
      if not amount then
        local ok, v = pcall(VRFW.resource.get, e.resource, h)
        amount = (ok and type(v) == "table" and v.max or 0) * (e.percent or 0) / 100
      end
      pcall(VRFW.resource.add, e.resource, h, amount)
    end
    return
  end
  carry.grants[#carry.grants + 1] = e
end

-- ---------------------------------------------------------------------------------------- live stats

local function live_value(e, p)
  if e.pending or e.pending_condition then return nil end
  local ctx = S.ctx(M.rc, p, M.match)
  if not B.conditions_hold(e, ctx) then return nil end
  return B.stacked_value(e, e.value, stacks_of(e, M.rc), nil)
end

-- the live stat effects on the user's players: VRFW.set_stat per player and stat, only on a change
local function refresh_live()
  if not M or not M.has_live_stats then return end
  M.dirty = false
  for h, p in pairs(M.roster) do
    local mult, add = { 1, 1, 1, 1, 1, 1, 1 }, { 0, 0, 0, 0, 0, 0, 0 }
    for _, e in ipairs(M.effects) do
      if e.live and (e.kind == "stat_multiplier" or e.kind == "stat_bonus") then
        local hit = e.target.kind == "team" or (e.target.kind == "position" and e.target.v == p.position)
          or (e.target.kind == "element" and e.target.v == p.element)
        local v = hit and live_value(e, p) or nil
        if v then
          for i = 1, 7 do
            if not e.stat or e.stat == i then
              if e.kind == "stat_multiplier" then mult[i] = mult[i] * v else add[i] = add[i] + v end
            end
          end
        end
      end
    end
    M.applied[h] = M.applied[h] or {}
    for i = 1, 7 do
      local sig = string.format("%.4f/%.2f", mult[i], add[i])
      if M.applied[h][i] ~= sig and not (M.applied[h][i] == nil and mult[i] == 1 and add[i] == 0) then
        M.applied[h][i] = sig
        local set = { stat = B.STATS[i], mult = mult[i], handles = { h } }
        if add[i] ~= 0 then set.add = add[i] end
        local ok, why = pcall(VRFW.set_stat, set)
        if not ok then warn("set_stat: " .. tostring(why)) end
      end
    end
  end
end

-- ---------------------------------------------------------------------------------------- counters

-- the match trigger dispatcher (a table field: step_match and it call each other)
local Fire = {}

-- one step of an effect's counter in a match; a crossed `every` fires its grant / charge and «effect activated»
local function step_match(e, ev, depth)
  local id = id_of(e)
  local before = count_now(e, M.rc)
  if e.count.scope == "match" or e.count.kind == "count_timer" or not e.item then
    M.counts[id] = (M.counts[id] or 0) + 1
  else
    carry.pending[e.item] = carry.pending[e.item] or {}
    local p = carry.pending[e.item]
    p[name_of(e)] = (p[name_of(e)] or 0) + 1
  end
  local now = before + 1
  if e.live then M.dirty = true end
  if math.floor(now / e.count.every) > math.floor(before / e.count.every) then
    if e.count.mode == "charge" then M.charges[id] = math.min((M.charges[id] or 0) + 1, e.count.cap or 99) end
    if e.grant and not e.on then match_grant(e, ev) end
    if depth < 1 and e.item then Fire.match("on_effect_activated", { item = e.item }, depth + 1) end
  end
end

local function reset_match(e)
  local id = id_of(e)
  if (M.counts[id] or 0) ~= 0 then
    M.counts[id] = 0
    M.charges[id] = 0
    if e.live then M.dirty = true end
  end
end

-- a match trigger: counters, resets and grants of every effect listening to it
function Fire.match(name, ev, depth)
  if not M then return end
  depth = depth or 0
  for _, e in ipairs(M.effects) do
    local c = e.count
    if c then
      if c.kind == "count_trigger" and c.on.where ~= "run" and B.trigger_matches(c.on, name, ev) then
        if c.on.pending then log_pending(e, c.on.name) elseif e.grant or roll(e, nil, M.rc.run) then step_match(e, ev, depth) end
      end
      for _, tr in ipairs(c.reset_on) do
        if B.trigger_matches(tr, name, ev) then reset_match(e) end
      end
    end
    if e.grant and e.on and B.trigger_matches(e.on, name, ev) then
      if e.on.pending then
        log_pending(e, e.on.name)
      elseif (not c or stacks_of(e, M.rc) >= 1) and roll(e, nil, M.rc.run) then
        match_grant(e, ev)
        if depth < 1 and e.item then Fire.match("on_effect_activated", { item = e.item }, depth + 1) end
      end
    end
  end
  if M.dirty then refresh_live() end
end

-- ---------------------------------------------------------------------------------------- the run's triggers

local function listens(effects, names)
  for _, e in ipairs(effects) do
    for _, n in ipairs(names) do
      if (e.on and e.on.name == n) or (e.count and e.count.on and e.count.on.name == n) then return true end
      for _, tr in ipairs(e.count and e.count.reset_on or {}) do
        if tr.name == n then return true end
      end
    end
  end
  return false
end

-- run triggers (route map, results) on run `r` in place; the grants to do after the save go in `out`
local function fire_run_in(r, names, ev, out)
  local effects = Items.all_effects(r.items)
  local queue = {}
  for _, n in ipairs(names) do queue[#queue + 1] = { n, ev, 0 } end
  local qi = 1
  while queue[qi] do
    local name, qev, depth = queue[qi][1], queue[qi][2], queue[qi][3]
    qi = qi + 1
    for _, e in ipairs(effects) do
      local o = owned_of(r, e.item)
      local c = e.count
      if c and o and c.kind == "count_trigger" and c.scope ~= "match" and B.trigger_matches(c.on, name, qev) then
        if e.grant or roll(e, o, r) then
          local before = o.counters[name_of(e)] or 0
          o.counters[name_of(e)] = before + 1
          if math.floor((before + 1) / c.every) > math.floor(before / c.every) then
            if e.grant and not e.on then prepare_grant(e, r, out) end
            if depth < 1 then queue[#queue + 1] = { "on_effect_activated", { item = e.item }, depth + 1 } end
          end
        end
      end
      if c and o then
        for _, tr in ipairs(c.reset_on) do
          if B.trigger_matches(tr, name, qev) then
            o.counters[name_of(e)] = 0
          end
        end
      end
      if e.grant and e.on and B.trigger_matches(e.on, name, qev) then
        if (not c or B.stacks(c, o and o.counters[name_of(e)] or 0) >= 1) and roll(e, o, r) then
          prepare_grant(e, r, out)
          if depth < 1 then queue[#queue + 1] = { "on_effect_activated", { item = e.item }, depth + 1 } end
        end
      end
    end
  end
end

-- the phase-scope counters back to 0 (the phase is over)
local function reset_phase(r)
  for _, e in ipairs(Items.all_effects(r.items)) do
    if e.count and e.count.scope == "phase" then
      local o = owned_of(r, e.item)
      if o then
        o.counters[name_of(e)] = 0
      end
    end
  end
end

-- route-map triggers (svc_run calls this after its own change is saved): one run edit, then the grants
function S.fire_run(names, ev, why)
  local r = Core.run.run_hdls()
  if not r then return end
  local effects = Items.all_effects(r.items)
  local phase_end = false
  if U.contains(names, "on_phase_end") then
    for _, e in ipairs(effects) do
      if e.count and e.count.scope == "phase" then phase_end = true end
    end
  end
  if not listens(effects, names) and not phase_end then return end
  local out = {}
  Core.run.edit_run("blocks " .. (why or table.concat(names, ", ")), function(run)
    fire_run_in(run, names, ev or {}, out)
    if phase_end then reset_phase(run) end
    return 0
  end)
  for _, g in ipairs(out) do run_grant(g) end
end

-- the match result is being recorded (inside svc_run Result's edit, before the save): this match's run / phase
-- counts, the stat buffs' match count, the grants the match queued
function S.merge_match(r)
  for _, e in ipairs(Items.all_effects(r.items)) do
    local o = owned_of(r, e.item)
    if o then
      local p = carry and carry.pending[e.item]
      local d = p and p[name_of(e)]
      if d then o.counters[name_of(e)] = (o.counters[name_of(e)] or 0) + d end
      local b = o.counters[name_of(e, "b")]
      if b and b > 0 then o.counters[name_of(e, "b")] = b - 1 end
    end
  end
  local out = {}
  for _, e in ipairs(carry and carry.grants or {}) do prepare_grant(e, r, out) end
  carry = { pending = {}, grants = {}, out = out }
end

-- after the result is saved: the match's grants, then the run triggers of the result
function S.after_result(won, lost, boss)
  local out = carry and carry.out or {}
  carry = nil
  for _, g in ipairs(out) do run_grant(g) end
  if lost then return end
  local names = { "on_match_end" }
  if won then
    names[#names + 1] = "on_match_won"
    if boss then names[#names + 1] = "on_boss_defeated" end
  end
  S.fire_run(names, {}, "result")
end

-- ---------------------------------------------------------------------------------------- match answers

-- move_power: the technique_power_multiplier effects for the user's player `hdl` and move `skill`
function S.power_mult(hdl, skill)
  if not M then return 1.0 end
  local p = M.roster[hdl]
  if not p then return 1.0 end
  local m = 1.0
  for _, e in ipairs(M.effects) do
    if e.kind == "technique_power_multiplier" and not e.pending and B.move_matches(e.moves, skill) then
      if e.count and e.count.mode == "charge" then
        local id, key = id_of(e), tostring(hdl) .. ":" .. tostring(skill)
        local now = VRFW.now()
        local used = M.charge_used[id .. key]
        if used and now - used < CHARGE_WINDOW_MS then
          m = m * e.value
        elseif (M.charges[id] or 0) > 0 and B.conditions_hold(e, S.ctx(M.rc, p, M.match)) then
          M.charges[id] = M.charges[id] - 1
          M.charge_used[id .. key] = now
          info(string.format("item %s: charge spent on move 0x%08X (x%.3f)", tostring(e.item), skill % U.TWO32, e.value))
          m = m * e.value
        end
      else
        local v = live_value(e, p)
        if v then m = m * v end
      end
    end
  end
  return m
end

-- tension_pay:skill: 0 while a technique_free_until_broken move of the user's player has not lost its duel
function S.tension_mult(hdl, skill)
  if not M or not M.roster[hdl] or not skill then return 1.0 end
  for _, e in ipairs(M.effects) do
    if e.kind == "technique_free_until_broken" and not e.pending and not M.broken[skill]
      and B.move_matches(e.moves, skill) and B.conditions_hold(e, S.ctx(M.rc, M.roster[hdl], M.match)) then
      return 0.0
    end
  end
  return 1.0
end

-- ---------------------------------------------------------------------------------------- engine events

local function user_actor(ev)
  local h = ev.actor and ev.actor.handle
  local p = h and M and M.roster[h]
  if not p then return nil end
  p.hdl = h
  return p
end

local function match_state(m)
  if type(m) ~= "table" then return nil end
  local f, a = Live.score(m)
  return { half = m.half, minute = Live.minute(m), score_for = f, score_against = a }
end

local function on_match_start()
  M = nil
  carry = { pending = {}, grants = {} }
  if not U.rogue_active() then return nil end
  local r = Core.run.run_hdls()
  if not r then return nil end
  local effects = Items.all_effects(r.items)
  local any = false
  for _, e in ipairs(effects) do
    if e.count or e.on or e.live or e.kind == "technique_power_multiplier" or e.kind == "technique_free_until_broken" then any = true end
  end
  if not any then return nil end
  local roster = {}
  for k = 0, 19 do
    local h = r.hdls[k + 1] or 0
    local uid = uid_at(r, k)
    if h ~= 0 and uid and uid ~= 0 then roster[h] = S.player_of(k, uid) end
  end
  M = { effects = effects, roster = roster, rc = S.run_ctx(r), counts = {}, charges = {}, timers = {}, applied = {},
    charge_used = {}, broken = {}, rolls = 0, last_owner = nil, match = nil, dirty = true, has_live_stats = false,
    watch = Live.watch() }
  for _, e in ipairs(effects) do
    if e.live and (e.kind == "stat_multiplier" or e.kind == "stat_bonus") then M.has_live_stats = true end
    if e.count and e.count.kind == "count_timer" then M.has_timer = true end
    if e.live then M.has_match_state = true end
  end
  info(string.format("match: %d effect(s) with blocks, %d run player(s) on the sheet", #effects, U.int(#r.hdls, 0)))
  return nil
end

-- the live stats belong to the match copy: nothing to put back
local function on_match_end()
  M = nil
  return nil
end

local function on_tick(ev)
  if not M or not (M.has_timer or M.has_match_state) then return nil end
  local m = ev.match or {}
  if M.has_match_state then
    local changed = M.watch:step(m)
    if changed.half or changed.minute or changed.score then
      M.match = match_state(m)
      M.dirty = true
    end
  end
  local live_dt = M.has_timer and Live.live_dt(m) or 0
  if live_dt > 0 then
    for _, e in ipairs(M.effects) do
      if e.count and e.count.kind == "count_timer" then
        local id = id_of(e)
        local t = M.timers[id]
        if not t then
          t = Live.timer(e.count.seconds)
          M.timers[id] = t
        end
        for _ = 1, t:step(live_dt) do step_match(e, {}, 0) end
      end
    end
  end
  if M.dirty then refresh_live() end
  return nil
end

-- the handlers (top level of the entry script only: inarogue.lua calls this while it loads)
function S.register()
  VRFW.on("match_start", on_match_start)
  VRFW.on("match_end", on_match_end)
  VRFW.on("tick", on_tick)
  VRFW.on("goal:user", function(ev)
    if M then Fire.match("on_goal_scored", { actor = user_actor(ev) }) end
    return nil
  end)
  VRFW.on("goal:rival", function()
    if M then Fire.match("on_goal_conceded", {}) end
    return nil
  end)
  VRFW.on("block_won", function(ev)
    local p = M and user_actor(ev)
    if p then Fire.match("on_block_won", { actor = p }) end
    return nil
  end)
  VRFW.on("duel_won", function(ev)
    local p = M and user_actor(ev)
    if p then
      Fire.match("on_duel_won", { actor = p })
      if M.last_owner == p.hdl then Fire.match("on_dribble_won", { actor = p }) end
    end
    return nil
  end)
  VRFW.on("possession", function(ev)
    if not M then return nil end
    local h = ev.actor and ev.actor.handle
    local p = user_actor(ev)
    if p and ev.arg == "keep" and M.last_owner and M.roster[M.last_owner] then Fire.match("on_pass_completed", { actor = p }) end
    M.last_owner = h
    return nil
  end)
  -- OnHissatsuUsed(actor handle, const u32* move): the handle comes signed, back to u32 before the lookup
  VRFW.on("match:skill_used:post", function(ev)
    if not M then return nil end
    local hdl = (tonumber(ev.args and ev.args[1]) or 0) % U.TWO32
    local skill = U.rd("u32", (tonumber(ev.args and ev.args[2]) or 0) % 18446744073709551616)
    local p = M.roster[hdl]
    if p and skill then
      p.hdl = hdl
      Fire.match("on_technique_used", { actor = p, move = skill })
    end
    return nil
  end)
  -- the substitution's effect event: arg = u32* the incoming player's handle
  VRFW.on("match:substitution", function(ev)
    if not M then return nil end
    local hdl = U.rd("u32", (tonumber(ev.args and ev.args[2]) or 0) % 18446744073709551616)
    local p = hdl and M.roster[hdl]
    if p then
      p.hdl = hdl
      Fire.match("on_substitution", { actor = p })
    end
    return nil
  end)
  -- a move that lost its duel: technique_free_until_broken ends for that move this match
  VRFW.on("technique_result:lost", function(ev)
    local p = M and user_actor(ev)
    local skill = ev.skill or ev.move
    if p and skill and not M.broken[skill] then
      M.broken[skill] = true
      info(string.format("move 0x%08X lost its duel: no longer free this match", skill % U.TWO32))
    end
    return nil
  end)
end

return S
