-- InaRogue › INAROGUE: the bank of the active slot and its commands (was runtime.rs of the DLL's module rogue).
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_EVT_RL_BANK_COUNT | – | count, capacity, slot, budget (the slot's starter budget), rosterLimit (nil = the menu's own) |
-- | CMND_EVT_RL_BANK_GET | i (0-based), sort (0 added, 1 tier, 2 cost, 3 level) | ok, uid, param, level, tier, cost, runs, added, card, starterCost, frags, whatif, spirits, spiritLevel |
-- | CMND_INAROGUE_RL_SPIRITS | op, a | the «Espíritus» (S.Spirits below) |
-- | CMND_EVT_RL_BANK_ADD | param[, level] (always 5) | code (0 ok, 1 bad args, 2 not a roguelite player, 3 owned, 4 full, 5 write failed), uid |
-- | CMND_EVT_RL_CHARA | param | tier, cost, inPool, statTotal99, card, element, position, whatif |
-- | CMND_EVT_RL_BUDGET | phase | budget |
-- | CMND_EVT_RL_BANK_DEBUG_FILL | n | added (-1 without [rogue] debug_tools) |
-- | CMND_EVT_RL_STARTER_INFO | – | budget, bestPhase, giftPending, bankCount, squadSize, pickOn |
-- | CMND_EVT_RL_STARTER_GIFT | – | added (-1 when not pending / off) |
-- | CMND_EVT_RL_PICK_RESET / _TOGGLE / _STATE / _COMMIT | – / uid / uid / seed | budget / code, picked, count, spent, budget / picked, cost, frags, nextStep, minCost, count, spent, budget / code, seed |
-- | CMND_EVT_RL_FRAGS_ADD | uid, n | total (debug_tools only; -1 otherwise) |
-- | CMND_EVT_RL_GACHA_GRANT | param, allowFrags | code, uid, frags, players |
-- | CMND_EVT_RL_TEAM_RESET / _SET / _CLEAR / _SLOT / _INFO / _FORMATION / _FITS / _COMMIT | (runtime.rs) | (unchanged) |
-- | CMND_EVT_RL_GACHA_DRAW | sign | ok, param, charaRarity, rarityType, index, whatif |
-- | CMND_EVT_RL_CARD | – | the INAROGUE save's own data (slot 4) for the slot screen card |
-- | CMND_EVT_RL_RUN_END | result, phase | played |
-- | CMND_EVT_RL_ALBUM_INFO | op, … | (ops 0-10, docs/game/modes/inarogue.md §14) |
--
-- [rogue] debug_all_players: every card of the draw pool not owned joins the loaded bank as an in-memory debug entry
-- (bank.lua): never written to the blob, left out of the album and the first-run gift, still offered by the Fichaje;
-- no unlock counts while it is on (svc_meta.lua).
--
-- A corrupt bank blob is set aside (its .archive\ copy) and the call that found it answers nothing; the next call starts
-- an empty bank (the DLL first tried the previous version of the backup ring: scripts cannot read it yet).

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local cfgm = require "lib/rogue/cfg"
local B = require "lib/rogue/bank"
local St = require "lib/rogue/starter"
local chara = require "lib/rogue/chara"
local album = require "lib/rogue/album"
local loot = require "lib/rogue/loot"
local Run = require "lib/rogue/run"
local info, warn, err = U.logger("rogue")

local S = {}

local inner = nil -- { slot, bank, locked, order = { sort, idx }, pick, team }
local rng = (U.today() ~= 0 and U.today() or 20261010)
rng = U.xor(rng % U.TWO32, 0x5EED1234)

local function next_rng()
  rng = U.xs_guard(rng)
  return rng
end

local function cfg() return Core.cfg() end

-- [rogue] debug_all_players: every draw-pool card the bank does not hold becomes a debug entry of the loaded bank
local function add_debug_players(b)
  if not cfg().debug_all_players then return end
  local added = B.add_debug(b, chara.table().pool)
  info(string.format("debug_all_players on: slot %d bank shows %d owned + %d debug players (nothing saved)", b.slot,
    B.real_len(b), added))
end

local function load_bank(slot)
  local b, why = B.load(slot)
  if b then
    info(string.format("slot %d: bank with %d players", slot, B.len(b)))
    add_debug_players(b)
    return b
  end
  local kept = U.blob_aside(B.BLOB, slot)
  err(string.format("slot %d: %s: %s; %s: the bank of slot %d is locked for this call (restore a good version from its .backup / .archive folder)",
    slot, B.BLOB, tostring(why), tostring(kept), slot))
  return nil
end

-- run `f(inner)` on the active slot's bank (reloaded when the slot changed); nil = locked (corrupt, set aside)
local function with_bank(f)
  local slot = U.slot()
  if not inner or inner.slot ~= slot or inner.locked then
    local b = load_bank(slot)
    inner = { slot = slot, bank = b or B.new(slot), locked = b == nil, order = nil, pick = St.new_pick(), team = St.new_team() }
  end
  if inner.locked then return nil end
  return f(inner)
end

Core.on_forget(function(slot)
  if inner and (slot == nil or inner.slot == slot) then inner = nil end
end)

local function commit(i, why)
  i.order = nil
  local ok, where = B.save(i.bank)
  if ok then
    info(string.format("bank slot %d saved (%d players, %s) -> %s", i.bank.slot, B.len(i.bank), why, tostring(where)))
  else
    err(string.format("cannot write the bank of slot %d: %s", i.bank.slot, tostring(where)))
  end
  return ok
end

-- (tier shown, cost) of a param (unknown params: tier 1, the cost of a 1-star player)
local function tier_cost(param)
  local c = cfg()
  local i = chara.get(param)
  if i then
    local t = chara.shown_tier(i)
    return t, cfgm.cost(c, t, i.stat_total99)
  end
  return 1, cfgm.cost(c, 1, 0)
end
S.tier_cost = tier_cost

local function valid(param)
  local i = chara.get(param)
  return i ~= nil and i.tier >= 1
end

-- the starter budget: the best phase reached (starter.lua) + the v2 runs won (lib/rogue/run_rules.lua budget_bonus),
-- capped by [rogue] budget_max
local function starter_budget(i)
  local c = cfg()
  local b = St.budget(c, i.bank.best_phase) + require("lib/rogue/run_rules").budget_bonus()
  return math.min(b, math.max(c.budget_max, c.starter_budget))
end

-- never while debug_all_players is on (the gift would find every player owned and be spent for nothing)
local function gift_pending(i, c)
  return c.starter_gift and not c.debug_all_players and not i.bank.granted and B.real_len(i.bank) < c.squad_size
end

local function entry_cost(i, uid)
  local e = i.bank.by_uid[uid]
  if not e then return nil end
  local tier = chara.tier_of(e.param)
  return St.cost(cfg(), tier, e.frags, e.spirit_level), e.frags, tier
end

-- ---------------------------------------------------------------------------------------- services for the run

function S.bank_run_stats()
  return with_bank(function(i) return { i.bank.runs.played, i.bank.runs.won, i.bank.best_phase } end)
end

function S.bank_params()
  return with_bank(function(i)
    local o = {}
    for _, e in ipairs(i.bank.entries) do
      if not e.debug then o[#o + 1] = e.param end
    end
    return o
  end) or {}
end

-- param, frags, tier, spirit level of a bank entry
function S.bank_entry(uid)
  local r = with_bank(function(i)
    local e = i.bank.by_uid[uid]
    if not e then return false end
    return { e.param, e.frags, chara.tier_of(e.param), e.spirit_level or 0 }
  end)
  if not r then return nil end
  return r[1], r[2], r[3], r[4]
end

-- ---------------------------------------------------------------------------------------- «Espíritus»

local Sp = require "lib/rogue/spirits"

-- the collection uid of card `param` (nil = not in it)
function S.bank_uid_of(param)
  return with_bank(function(i)
    local e = i.bank.by_param[param]
    return e and not e.debug and e.uid or nil
  end)
end

-- spirits of collection player `uid` added (a duplicate recruit): his total, nil when he is not in the collection
function S.spirits_add(uid, n, why)
  return with_bank(function(i)
    local e = i.bank.by_uid[uid]
    if not e or e.debug or n <= 0 then return e and e.spirits or nil end
    local before = e.spirits or 0
    e.spirits = math.min(before + n, 999999)
    if not commit(i, why) then
      e.spirits = before
      return nil
    end
    return e.spirits
  end)
end

-- spirits, spirit level, cost now, cost after the next level (nil = none), spirits the next level needs (nil = none)
function S.spirits_of(uid)
  local r = with_bank(function(i)
    local e = i.bank.by_uid[uid]
    if not e then return false end
    local tier = chara.tier_of(e.param)
    local c = cfg()
    local lv = e.spirit_level or 0
    local base = St.cost(c, tier, e.frags, 0)
    local now = Sp.apply(base, lv)
    local nxt = Sp.next_cost(lv)
    local after = nxt and Sp.apply(base, lv + 1) or nil
    if after and after >= now then after, nxt = nil, nil end
    return { e.spirits or 0, lv, now, after, nxt }
  end)
  if not r then return nil end
  return r[1], r[2], r[3], r[4], r[5]
end

local spirit_list = {}   -- the uids the last CMND_INAROGUE_RL_SPIRITS (0) listed, in card order

-- CMND_INAROGUE_RL_SPIRITS (op, a):
--   0     -> ok, count: the collection players whose spirits buy their next level, set as the framework's pick cards
--            (most spirits first, at most 12); false = nobody can
--   1, i  -> code (0 ok, 1 nothing, 5 write failed), result text ({name}), param: card i's next level bought
--   2, uid -> spirits, level, cost now, cost after the next level (0 = none), spirits it needs (0 = none)
function S.Spirits(op_arg, a_arg)
  local op = U.int(op_arg, 0)
  local T = require("lib/rogue/run_rules").text
  if op == 2 then
    local sp, lv, now, after, nxt = S.spirits_of(U.int(a_arg, 0))
    if not sp then return 0, 0, 0, 0, 0 end
    return sp, lv, now, after or 0, nxt or 0
  end
  if op == 1 then
    local uid = spirit_list[U.int(a_arg, 0)]
    if not uid then return 1, "", 0 end
    local out = with_bank(function(i)
      local e = i.bank.by_uid[uid]
      if not e then return { 1 } end
      local base = St.cost(cfg(), chara.tier_of(e.param), e.frags, 0)
      local lv = e.spirit_level or 0
      if not Sp.can_level(base, lv, e.spirits or 0) then return { 1 } end
      local price = Sp.next_cost(lv)
      e.spirits = e.spirits - price
      e.spirit_level = lv + 1
      if not commit(i, "spirits spent") then
        e.spirits, e.spirit_level = e.spirits + price, lv
        return { 5 }
      end
      return { 0, Sp.apply(base, lv + 1), e.param, e.spirits }
    end) or { 5 }
    if out[1] ~= 0 then return out[1], "", 0 end
    info(string.format("spirits spent on %s: cost %d, %d spirits left", U.hex(out[3]), out[2], out[4]))
    return 0, T("InaRogue.run_spirits_done", out[2], out[4]), out[3]
  end
  local PC = rawget(_G, "PickCards")
  local list = with_bank(function(i)
    local o = {}
    for _, e in ipairs(i.bank.entries) do
      if not e.debug and (e.spirits or 0) > 0 then
        local base = St.cost(cfg(), chara.tier_of(e.param), e.frags, 0)
        if Sp.can_level(base, e.spirit_level or 0, e.spirits) then o[#o + 1] = e end
      end
    end
    table.sort(o, function(a, b)
      if a.spirits ~= b.spirits then return a.spirits > b.spirits end
      return a.uid < b.uid
    end)
    return o
  end) or {}
  spirit_list = {}
  if not PC or not PC.Set or #list == 0 then return false, 0 end
  local cards = {}
  for k = 1, math.min(#list, 12) do
    local e = list[k]
    local x = chara.get(e.param) or {}
    local tier = chara.tier_of(e.param)
    local base = St.cost(cfg(), tier, e.frags, 0)
    local lv = e.spirit_level or 0
    spirit_list[k] = e.uid
    cards[k] = { kind = "player", card = e.param,
      subtitle = T("InaRogue.run_card_player_sub", string.rep("★", math.max(tier, 1)), T("InaRogue.run_pos_" .. U.int(x.position, 0)),
        T("InaRogue.run_elem_" .. U.int(x.element, 0))),
      lines = { T("InaRogue.run_spirits_count", e.spirits), T("InaRogue.run_spirits_cost", Sp.apply(base, lv), Sp.apply(base, lv + 1)) },
      badge = T("InaRogue.run_spirits_price", Sp.next_cost(lv)), rarity = math.min(math.max(tier, 1), 5) }
  end
  local ok = PC.Set({ title = T("InaRogue.run_spirits_title"), subtitle = T("InaRogue.run_spirits_sub"), skip = true,
    skip_text = T("InaRogue.run_spirits_done_skip"), cards = cards })
  return ok == true, #cards
end

-- add a player (a Fichaje / reward): code, uid (code 3 = already owned, uid = his)
function S.bank_add_param(param, why, src)
  local cap = cfg().bank_capacity
  local ok = valid(param)
  local r = with_bank(function(i)
    local e = i.bank.by_param[param]
    if e then return { B.CODE.DUPLICATE, e.uid } end
    local code, uid = B.add_from(i.bank, param, U.today(), ok, cap, src)
    if code ~= B.CODE.OK then return { code, 0 } end
    if commit(i, why) then return { B.CODE.OK, uid } end
    B.undo_add(i.bank, uid)
    return { B.CODE.WRITE_FAILED, 0 }
  end) or { B.CODE.WRITE_FAILED, 0 }
  info(string.format("%s: add %s -> code %d uid %d", why, U.hex(param), r[1], r[2]))
  return r[1], r[2]
end

-- give `n` fragments to every uid (one write; rolled back when it fails): the players credited
function S.bank_frags_to(uids, n, why)
  if n == 0 or #uids == 0 then return 0 end
  return with_bank(function(i)
    local before = {}
    for _, u in ipairs(uids) do
      local e = i.bank.by_uid[u]
      if e then before[#before + 1] = { u, e.frags } end
    end
    local credited = 0
    for _, u in ipairs(uids) do
      if B.add_frags(i.bank, u, n) then credited = credited + 1 end
    end
    if credited > 0 and not commit(i, why) then
      for _, x in ipairs(before) do B.set_frags(i.bank, x[1], x[2]) end
      return 0
    end
    return credited
  end) or 0
end

-- the Fichaje draw pool: { param, tier } of tier 1..max_tier not in the bank (normal player cards only, no staff)
function S.recruit_pool(max_tier)
  local t = chara.table()
  return with_bank(function(i)
    local o = {}
    for _, p in ipairs(t.pool) do
      local x = t.map[p]
      local e = i.bank.by_param[p]
      if x.tier >= 1 and x.tier <= max_tier and (not e or e.debug) then o[#o + 1] = { p, x.tier } end
    end
    return o
  end) or {}
end

-- the What-if cards not in the bank yet
function S.whatif_pool()
  local t = chara.table()
  return with_bank(function(i)
    local o = {}
    for _, p in ipairs(t.whatif) do
      local x = t.map[p]
      local e = i.bank.by_param[p]
      if x.tier >= 1 and (not e or e.debug) then o[#o + 1] = { p, x.tier } end
    end
    return o
  end) or {}
end

function S.best_phase()
  return with_bank(function(i) return i.bank.best_phase end)
end

-- a new best phase for the slot's bank (raises the starter budget)
function S.record_phase(phase)
  with_bank(function(i)
    if B.record_phase(i.bank, phase) then commit(i, "best phase") end
  end)
end

-- a run ended (result 1 abandoned, 2 lost, 3 won) in `phase`: the bank's counters, the unlocks, the run-end points
-- (returned)
function S.record_run_end(result, phase)
  with_bank(function(i)
    B.record_run_end(i.bank, result, phase)
    commit(i, "run end")
  end)
  if Core.meta then
    Core.meta.unlocks_on_run_end(result, phase)
    return Core.meta.earn_run_end(result, phase) or 0
  end
  return 0
end

-- ---------------------------------------------------------------------------------------- commands

function S.Count()
  local c = cfg()
  local r = with_bank(function(i) return { B.len(i.bank), i.bank.slot, starter_budget(i) } end)
  r = r or { 0, U.slot(), c.starter_budget }
  return r[1], c.bank_capacity, r[2], r[3], c.debug_all_players and U.clamp(c.debug_all_players_limit, 1, 5000) or nil
end

function S.Get(i_arg, sort_arg)
  local idx = U.int(i_arg, -1)
  local sort = U.int(sort_arg, 0)
  if sort ~= 1 and sort ~= 2 and sort ~= 3 then sort = 0 end
  local e = with_bank(function(i)
    if idx < 0 then return nil end
    if not i.order or i.order.sort ~= sort then i.order = { sort = sort, idx = B.order(i.bank, sort, tier_cost) } end
    local k = i.order.idx[idx + 1]
    return k and i.bank.entries[k]
  end)
  if not e then return false end
  local tier, cost = tier_cost(e.param)
  local x = chara.get(e.param)
  return true, e.uid, e.param, e.level, tier, cost, e.runs, e.added, x and x.card or 0,
    St.cost(cfg(), tier, e.frags, e.spirit_level), e.frags, chara.is_whatif(e.param), e.spirits or 0, e.spirit_level or 0
end

function S.Add(param_arg)
  local param = U.u32(param_arg, nil)
  if param == nil then return B.CODE.BAD_ARGS, 0 end
  local ok = valid(param)
  local cap = cfg().bank_capacity
  local r = with_bank(function(i)
    local code, uid = B.add_from(i.bank, param, U.today(), ok, cap, B.SOURCE.OTHER)
    if code ~= B.CODE.OK then return { code, 0 } end
    if commit(i, "add") then return { B.CODE.OK, uid } end
    B.undo_add(i.bank, uid)
    return { B.CODE.WRITE_FAILED, 0 }
  end) or { B.CODE.BAD_ARGS, 0 }
  info(string.format("add %s lv 5 -> code %d uid %d", U.hex(param), r[1], r[2]))
  return r[1], r[2]
end

function S.Chara(param_arg)
  local param = U.u32(param_arg, 0)
  local c = cfg()
  local i = chara.get(param)
  if i then
    return i.tier, cfgm.cost(c, chara.shown_tier(i), i.stat_total99), chara.in_pool(i), i.stat_total99, i.card, i.element,
      i.position, i.whatif
  end
  return 0, cfgm.cost(c, 1, 0), false, 0, 0, 0, 0, false
end

function S.Budget(phase_arg)
  local phase = math.max(U.int(phase_arg, 1), 0)
  return cfgm.budget(cfg(), phase)
end

function S.DebugFill(n_arg)
  local c = cfg()
  if not c.debug_tools then
    warn("CMND_EVT_RL_BANK_DEBUG_FILL refused ([rogue] debug_tools = false)")
    return -1
  end
  local n = U.clamp(U.int(n_arg, 10), 0, 6000)
  local t = chara.table()
  local added = with_bank(function(i)
    local added, tries = 0, 0
    while added < n and tries < n * 50 and #t.pool > 0 do
      tries = tries + 1
      local p = t.pool[next_rng() % #t.pool + 1]
      if B.add_from(i.bank, p, U.today(), true, c.bank_capacity, B.SOURCE.DEBUG) == B.CODE.OK then
        added = added + 1
      elseif B.real_len(i.bank) >= c.bank_capacity then
        break
      end
    end
    if c.whatif_debug_fill then
      for _, p in ipairs(t.whatif) do
        if B.add_from(i.bank, p, U.today(), true, c.bank_capacity, B.SOURCE.DEBUG) == B.CODE.OK then added = added + 1 end
      end
    end
    if added > 0 and not commit(i, "debug fill") then
      local slot = i.bank.slot
      i.bank = load_bank(slot) or B.new(slot)
      i.order = nil
      return 0
    end
    return added
  end) or 0
  info(string.format("debug fill added %d players", added))
  return added
end

function S.StarterInfo()
  local c = cfg()
  local r = with_bank(function(i) return { starter_budget(i), i.bank.best_phase, gift_pending(i, c), B.len(i.bank) } end)
  r = r or { c.starter_budget, 0, false, 0 }
  return r[1], r[2], r[3], r[4], c.squad_size, c.starter_pick
end

-- the first-run gift (11 random 1-3 star players, never a coach / manager card; [rogue] gift_* settings): the params
-- granted, in draw order, or nil when it is not pending / off / not written
local function grant_gift()
  local c = cfg()
  local t = chara.table()
  return with_bank(function(i)
    if not gift_pending(i, c) then return nil end
    local pool = {}
    for _, p in ipairs(t.pool) do
      local x = t.map[p]
      if x.tier <= 3 then pool[#pool + 1] = { p, x } end
    end
    local owned = {}
    for _, e in ipairs(i.bank.entries) do owned[e.param] = true end
    local holder = { s = rng }
    local gift = St.draw_gift(pool, owned, { c.gift_weights[1] or 0, c.gift_weights[2] or 0, c.gift_weights[3] or 0 },
      c.gift_cost_cap, holder)
    rng = holder.s
    local added = {}
    for _, p in ipairs(gift) do
      if B.add_from(i.bank, p, U.today(), true, c.bank_capacity, B.SOURCE.STARTER) == B.CODE.OK then added[#added + 1] = p end
    end
    i.bank.granted = true
    if not commit(i, "first-run gift") then
      local slot = i.bank.slot
      i.bank = load_bank(slot) or B.new(slot)
      return nil
    end
    return added
  end)
end

function S.StarterGift()
  local added = grant_gift()
  local n = added and #added or -1
  info(string.format("first-run gift -> %d players", n))
  return n
end

-- the first-run gift for the welcome gacha (lib\rogue\welcome_gacha.lua): the params granted, or nil
function S.starter_gift_list()
  local added = grant_gift()
  info(string.format("first-run gift (welcome gacha) -> %d players", added and #added or -1))
  return added
end

function S.PickReset()
  local b = with_bank(function(i)
    i.pick = St.new_pick()
    return starter_budget(i)
  end)
  return b or cfg().starter_budget
end

function S.PickToggle(uid_arg)
  local uid = U.u32(uid_arg, 0)
  local size = cfg().squad_size
  local r = with_bank(function(i)
    local budget = starter_budget(i)
    local cost = entry_cost(i, uid)
    if not cost then return { 3, false, #i.pick.uids, i.pick.spent, budget } end
    local code, on = St.pick_toggle(i.pick, uid, cost, budget, size)
    return { code, on, #i.pick.uids, i.pick.spent, budget }
  end) or { 3, false, 0, 0, 0 }
  return r[1], r[2], r[3], r[4], r[5]
end

function S.PickState(uid_arg)
  local uid = U.u32(uid_arg, 0)
  local c = cfg()
  local r = with_bank(function(i)
    local cost, frags, tier = entry_cost(i, uid)
    if not cost then cost, frags, tier = 0, 0, 1 end
    return { U.contains(i.pick.uids, uid), cost, frags, St.next_step(c, frags) or 0, St.min_cost(c, tier), #i.pick.uids,
      i.pick.spent, starter_budget(i) }
  end) or { false, 0, 0, 0, 0, 0, 0, 0 }
  return r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]
end

function S.PickCommit(seed_arg)
  local seed = U.u32(seed_arg, 0)
  local size = cfg().squad_size
  local squad = with_bank(function(i)
    local budget = starter_budget(i)
    local v, spent = {}, 0
    for _, u in ipairs(i.pick.uids) do
      if i.bank.by_uid[u] then
        v[#v + 1] = u
        spent = spent + (entry_cost(i, u) or 0)
      end
    end
    if #v == size and spent <= budget then return v end
    return nil
  end)
  if not squad then return 8, 0 end
  local code, s = Core.run.start_run(seed, squad, {}, 0)
  if code == 0 then with_bank(function(i) i.pick = St.new_pick() end) end
  return code, s
end

function S.FragsAdd(uid_arg, n_arg)
  if not cfg().debug_tools then return -1 end
  local uid = U.u32(uid_arg, 0)
  local n = U.clamp(U.int(n_arg, 0), 0, 10000)
  local total = with_bank(function(i)
    local t = B.add_frags(i.bank, uid, n)
    if not t then return nil end
    commit(i, "fragments (debug)")
    return t
  end)
  return total or -1
end

-- ---- the team screen (§12.1b)

local function base_of(i)
  return function(uid)
    local c = entry_cost(i, uid)
    return c
  end
end

function S.TeamReset()
  local b = with_bank(function(i)
    i.team = St.new_team()
    return starter_budget(i)
  end)
  return b or cfg().starter_budget
end

function S.TeamSet(slot_arg, uid_arg)
  local slot = U.int(slot_arg, -1)
  local uid = U.u32(uid_arg, 0)
  local c = cfg()
  local r = with_bank(function(i)
    local budget = starter_budget(i)
    local code, t = St.team_set(c, i.team, slot, uid, base_of(i), budget)
    if code == 0 then i.team = t end
    return { code, St.team_spent(c, i.team, base_of(i)), budget }
  end) or { 3, 0, 0 }
  info(string.format("team set slot %d uid %d -> code %d, %d/%d", slot, uid, r[1], r[2], r[3]))
  return r[1], r[2], r[3]
end

function S.TeamClear(slot_arg)
  local slot = U.int(slot_arg, -1)
  local c = cfg()
  local r = with_bank(function(i)
    if slot >= 0 and slot < St.TEAM_SLOTS then i.team.slots[slot + 1] = 0 end
    return { St.team_spent(c, i.team, base_of(i)), starter_budget(i) }
  end) or { 0, 0 }
  return r[1], r[2]
end

function S.TeamSlot(slot_arg)
  local slot = U.int(slot_arg, -1)
  local c = cfg()
  local r = with_bank(function(i)
    if slot < 0 or slot >= St.TEAM_SLOTS then return nil end
    local uid = i.team.slots[slot + 1]
    local e = i.bank.by_uid[uid]
    if not e then return nil end
    local cost, _, tier = entry_cost(i, uid)
    return { uid, e.param, St.slot_cost(c, cost, slot), tier }
  end) or { 0, 0, 0, 0 }
  return r[1], r[2], r[3], r[4]
end

function S.TeamInfo()
  local c = cfg()
  local r = with_bank(function(i)
    local base = base_of(i)
    local budget = starter_budget(i)
    local st, be, ma, co = St.team_counts(i.team)
    return { st, be, ma, co, St.team_spent(c, i.team, base), budget, i.team.formation, St.team_ready(c, i.team, base, budget) }
  end) or { 0, 0, 0, 0, 0, 0, 0, false }
  return r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]
end

function S.TeamFormation(f_arg)
  local f = U.u32(f_arg, 0)
  local r = with_bank(function(i)
    i.team.formation = f
    return f
  end)
  return r or 0
end

function S.TeamFits(uid_arg, slot_arg)
  local uid = U.u32(uid_arg, 0)
  local slot = U.int(slot_arg, -1)
  local c = cfg()
  local r = with_bank(function(i)
    local budget = starter_budget(i)
    local base = base_of(i)
    if slot < 0 or slot >= St.TEAM_SLOTS then return nil end
    local b = base(uid)
    if not b then return nil end
    local cost = St.slot_cost(c, b, slot)
    local fits = St.team_spent(c, St.team_with(i.team, slot, uid), base) <= budget
    return { fits, St.team_find(i.team, uid) or -1, cost }
  end) or { false, -1, 0 }
  return r[1], r[2], r[3]
end

function S.TeamCommit(seed_arg)
  local seed = U.u32(seed_arg, 0)
  local c = cfg()
  local team = with_bank(function(i)
    local base = base_of(i)
    local t = St.team_copy(i.team)
    for k = 1, St.TEAM_SLOTS do
      if t.slots[k] ~= 0 and not i.bank.by_uid[t.slots[k]] then t.slots[k] = 0 end
    end
    if St.team_ready(c, t, base, starter_budget(i)) then return t end
    return nil
  end)
  if not team then return 8, 0 end
  local squad = {}
  for _, u in ipairs(team.slots) do
    if u ~= 0 then squad[#squad + 1] = u end
  end
  local slots = {}
  for k, u in ipairs(team.slots) do slots[k] = u end
  local code, s = Core.run.start_run(seed, squad, slots, team.formation)
  if code == 0 then with_bank(function(i) i.team = St.new_team() end) end
  return code, s
end

-- ---- gacha (§12.5)

function S.GachaGrant(param_arg, frags_arg)
  local param = U.u32(param_arg, 0)
  local allow = U.int(frags_arg, 0) ~= 0
  local c = cfg()
  local ok = valid(param)
  local r = with_bank(function(i)
    local e = i.bank.by_param[param]
    if e then
      if not allow then return { B.CODE.DUPLICATE, e.uid, e.frags } end
      local before = e.frags
      local total = B.add_frags(i.bank, e.uid, c.gacha_dupe_frags) or 0
      if commit(i, "gacha fragments") then return { 1, e.uid, total } end
      B.set_frags(i.bank, e.uid, before) -- audit A7: the shown reward is never ahead of the file
      return { B.CODE.WRITE_FAILED, e.uid, before }
    end
    local code, uid = B.add_from(i.bank, param, U.today(), ok, c.bank_capacity, B.SOURCE.GACHA)
    if code ~= B.CODE.OK then return { code, 0, 0 } end
    if commit(i, "gacha") then return { 0, uid, 0 } end
    B.undo_add(i.bank, uid)
    return { B.CODE.WRITE_FAILED, 0, 0 }
  end) or { B.CODE.BAD_ARGS, 0, 0 }
  info(string.format("gacha %s -> code %d uid %d frags %d", U.hex(param), r[1], r[2], r[3]))
  return r[1], r[2], r[3], U.clamp(c.gacha_players, 1, 12)
end

function S.GachaDraw(sign_arg)
  local sign = U.u32(sign_arg, 0)
  local c = cfg()
  -- «What if»: a share of the coin draws gives a What-if card the bank does not hold yet
  local roll = with_bank(function() return next_rng() end) or (U.TWO32 - 1)
  if cfgm.whatif_gacha(c, roll) then
    local pool = S.whatif_pool()
    if #pool > 0 then
      local k = (with_bank(function() return next_rng() end) or 0) % #pool + 1
      local param = pool[k][1]
      info(string.format("gacha coin %d -> What-if %s", sign, U.hex(param)))
      return true, param, 5, 2, -1, true
    end
  end
  local d = with_bank(function()
    local p, rar, rt, idx = loot.gacha_draw(sign, next_rng)
    if not p then return false end
    return { p, rar, rt, idx }
  end)
  if d then return true, d[1], d[2], d[3], d[4], false end
  return false, 0, 0, 0, 0, false
end

-- ---- the INAROGUE card of the slot screen (§13.12): slot 4's own files, read-only

function S.Card()
  local slot = U.ROGUE_SLOT
  local bank = B.load(slot)
  if not bank then return false end
  local run = Run.load(slot)
  if run == false then run = nil end
  local tiers, frags = { 0, 0, 0, 0, 0 }, 0
  for _, e in ipairs(bank.entries) do
    local t = U.clamp(chara.tier_of(e.param), 1, 5)
    tiers[t] = tiers[t] + 1
    frags = frags + e.frags
  end
  local params = {}
  for k, e in ipairs(bank.entries) do params[k] = e.param end
  local owned = album.owned_keys(params)
  return true, bank.best_phase, run ~= nil, run and run.phase or 0, run and #run.path or 0, bank.runs.played, bank.runs.won,
    bank.runs.last, bank.runs.last_phase, B.len(bank), #chara.table().pool, frags, tiers[1], tiers[2], tiers[3], tiers[4],
    tiers[5], album.total_owned(owned), album.total_cards()
end

function S.RunEnd(result_arg, phase_arg)
  local result = U.clamp(U.int(result_arg, 0), 0, 3)
  local phase = U.u32(phase_arg, 0)
  S.record_run_end(result, phase)
  local played = with_bank(function(i) return i.bank.runs.played end) or 0
  info(string.format("run ended (result %d, phase %d): %d runs played", result, phase, played))
  return played
end

-- ---------------------------------------------------------------------------------------- the album (§14)

local view = nil -- { order, len, stamp, owned (key -> { uid, runs, added }), extra (key -> { goals, source }), list, book }

local function cost_of(param)
  local _, c = tier_cost(param)
  return math.max(c, 0)
end

-- the album's owned cards: key -> { uid, runs, added } and key -> { goals, source, real }. Real bank rows first; the
-- debug bank players ([rogue] debug_all_players) and, with [rogue.album] unlock_all, every card count as owned too
-- (real = false: no stats of their own). Display only: the save and the progress counters keep the real rows.
local function album_rows()
  return with_bank(function(i)
    local list = {}
    for _, e in ipairs(i.bank.entries) do
      if not e.debug or cfg().debug_all_players then list[#list + 1] = e end
    end
    return list
  end) or {}
end

local function album_owned_maps(rows)
  rows = rows or album_rows()
  local owned, extra = {}, {}
  for _, e in ipairs(rows) do
    local k = album.char_key(e.param)
    if k and (not owned[k] or (not e.debug and not extra[k][3])) then
      owned[k] = { e.debug and 0 or e.uid, e.runs, e.added }
      extra[k] = { e.goals, e.source, not e.debug }
    end
  end
  if cfg().album.unlock_all then
    for c = 0, album.total_cards() - 1 do
      local _, k = album.card(c)
      if k and not owned[k] then
        owned[k] = { 0, 0, 0 }
        extra[k] = { 0, 0, false }
      end
    end
  end
  return rows, owned, extra
end

local function album_view(order)
  order = U.clamp(order, 0, album.ORDER_LAST)
  local rows = album_rows()
  local stamp = #rows
  for _, e in ipairs(rows) do stamp = (stamp * 31 + e.goals + e.runs) % 1000000007 end
  if view and view.order == order and view.len == #rows and view.stamp == stamp then return view end
  local _, owned, extra = album_owned_maps(rows)
  local list = album.book_order(order, owned, chara.tier_of, cost_of)
  local book = album.book(list, function(c) return album.section_key(order, c, owned, chara.tier_of, cost_of) end)
  local n = 0
  for _ in pairs(owned) do n = n + 1 end
  view = { order = order, len = #rows, stamp = stamp, owned = owned, extra = extra, list = list, book = book, n_owned = n }
  return view
end

local function team_owned_count(t, owned)
  local first, n = album.team_range(t)
  local k = 0
  for m = first, first + n - 1 do
    local _, key = album.card(m)
    if key and owned[key] then k = k + 1 end
  end
  return k
end

function S.AlbumInfo(op_arg, a1, a2, a3)
  local op = U.int(op_arg, 0)
  local function order(a) return U.clamp(U.int(a, 0), 0, album.ORDER_LAST) end
  if op == 3 then
    return #album_view(order(a1)).list
  elseif op == 4 then
    local i, ord = U.int(a1, -1), order(a2)
    local v = album_view(ord)
    if i < 0 or not v.list[i + 1] then return false end
    local card = v.list[i + 1]
    local param, key = album.card(card)
    if not param then return false end
    local t = album.team_of(card)
    local _, name, _, n = album.team(t)
    if not name then return false end
    local t_owned = team_owned_count(t, v.owned)
    local own, ex = v.owned[key], v.extra[key]
    local tier, cost = tier_cost(param)
    local uid, runs, added = 0, 0, 0
    if own then uid, runs, added = own[1], own[2], own[3] end
    local goals, src, real = 0, 0, false
    if ex then goals, src, real = ex[1], ex[2], ex[3] end
    return true, param, own ~= nil, tier, uid, t, t_owned, n, cost, runs, added, name, chara.is_whatif(param), card + 1,
      album.club_emblem(card), goals, src, real
  elseif op == 5 then
    local i, ord, dir = math.max(U.int(a1, 0), 0), order(a2), U.int(a3, 1)
    local v = album_view(ord)
    return album.group_jump(v.list, i, dir, function(m) return album.section_key(ord, m, v.owned, chara.tier_of, cost_of) end)
  elseif op == 6 then
    local param, ord = U.u32(a1, 0), order(a2)
    local key = album.char_key(param)
    if not key then return -1 end
    local v = album_view(ord)
    for idx, m in ipairs(v.list) do
      local _, k = album.card(m)
      if k == key then return idx - 1 end
    end
    return -1
  elseif op == 7 then
    local v = album_view(order(a1))
    return #v.book.pages, #v.book.sections, #v.list, album.total_cards(), v.n_owned
  elseif op == 8 then
    local v = album_view(order(a1))
    local page = U.int(a2, -1)
    local rows = page >= 0 and v.book.pages[page + 1] or nil
    local out = {}
    for k = 1, album.BOOK_ROWS do
      local row = rows and rows[k]
      local kind, sec, first, n = 0, -1, 0, 0
      if row and row.kind == 1 then
        kind, sec = 1, row.section
      elseif row and row.kind == 2 then
        kind, sec, first, n = 2, row.section, row.first, row.n
      end
      out[#out + 1] = kind
      out[#out + 1] = sec
      out[#out + 1] = first
      out[#out + 1] = n
      out[#out + 1] = false
    end
    return table.unpack(out, 1, #out)
  elseif op == 9 then
    local v = album_view(order(a1))
    local s = U.int(a2, -1)
    local sec = s >= 0 and v.book.sections[s + 1] or nil
    if not sec or sec.count == 0 then return false end
    local sec_owned = 0
    for p = sec.first, sec.first + sec.count - 1 do
      local _, k = album.card(v.list[p + 1])
      if k and v.owned[k] then sec_owned = sec_owned + 1 end
    end
    local t = album.team_of(v.list[sec.first + 1])
    local tid, name, emblem, tn = album.team(t)
    if not tid then return false end
    return true, sec.key, sec.count, sec_owned, sec.page, team_owned_count(t, v.owned), tn, tid, emblem, name
  elseif op == 10 then
    local v = album_view(order(a1))
    local i = U.int(a2, -1)
    if i < 0 then return -1, -1, -1 end
    local p, r, c = album.locate(v.book, i)
    if not p then return -1, -1, -1 end
    return p, r, c
  end
  if op == 0 then view = nil end -- the screen (re)opens: fresh ownership
  local _, owned = album_owned_maps()
  if op == 1 then
    local t = U.int(a1, -1)
    local id, name, emblem, n = album.team(t)
    if not id then return false end
    return true, id, emblem, n, album.team_owned(t, owned), name
  elseif op == 2 then
    local t, k = U.int(a1, -1), U.int(a2, -1)
    local param, key = album.member(t, k)
    if not param then return false end
    local uid = with_bank(function(i)
      for _, e in ipairs(i.bank.entries) do
        if not e.debug and album.char_key(e.param) == key then return e.uid end
      end
      return 0
    end) or 0
    return true, param, owned[key] ~= nil, chara.tier_of(param), uid
  end
  return album.teams(), album.total_cards(), album.total_owned(owned)
end

return S
