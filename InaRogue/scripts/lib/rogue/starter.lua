-- InaRogue › INAROGUE: the run start, PokeRogue style (pure; docs/game/modes/inarogue.md §12). Was starter.rs.
--
-- * Starter cost by rarity ([rogue] starter_cost), lowered by the player's fragments: each [rogue] frag_steps threshold
--   reached = -1, down to max(1, ceil(base / 2)).
-- * Starter budget ([rogue] starter_budget) + 1 per budget_step_phases of the best phase ever reached, capped.
-- * The team screen (§12.1b): 20 slots (0-10 starters, 11-15 bench, 16-18 managers, 19 coach); bench / staff at half
--   price only with bench_half / staff_half.
-- * The first-run gift: 11 random 1★-3★ players with a playable spread of positions, total cost ≤ gift_cost_cap.

local U = require "lib/rogue/util"

local S = {}

S.TEAM_SLOTS, S.STARTERS, S.BENCH_END, S.MANAGERS_END, S.COACH = 20, 11, 16, 19, 19
S.GIFT_POSITIONS = { 1, 4, 4, 4, 4, 3, 3, 3, 2, 2, 2 }

function S.base_cost(c, tier)
  local t = U.clamp(tier, 1, 5)
  local v = c.starter_cost[t] or c.starter_cost[#c.starter_cost] or t
  return math.max(v, 1)
end

function S.frag_level(c, frags)
  local n = 0
  for _, st in ipairs(c.frag_steps) do
    if st > 0 and frags >= st then n = n + 1 end
  end
  return n
end

-- the next fragment threshold (nil = every step reached)
function S.next_step(c, frags)
  local best = nil
  for _, st in ipairs(c.frag_steps) do
    if st > frags and (best == nil or st < best) then best = st end
  end
  return best
end

function S.min_cost(c, tier)
  return math.max(math.floor((S.base_cost(c, tier) + 1) / 2), 1)
end

-- the starter cost: the base by rarity lowered by the fragments (down to min_cost), then by the spirit levels bought
-- (lib/rogue/spirits.lua, down to [rogue.spirits] floor)
function S.cost(c, tier, frags, spirit_level)
  local cost = math.max(S.base_cost(c, tier) - S.frag_level(c, frags), S.min_cost(c, tier))
  if (spirit_level or 0) > 0 then cost = require("lib/rogue/spirits").apply(cost, spirit_level) end
  return cost
end

function S.budget(c, best_phase)
  local step = math.max(c.budget_step_phases, 1)
  local b = c.starter_budget + math.floor(best_phase / step)
  return math.min(b, math.max(c.budget_max, c.starter_budget))
end

-- ---------------------------------------------------------------------------------------- the squad being picked

function S.new_pick() return { uids = {}, spent = 0 } end

-- toggle `uid` (cost `cost`): picked -> removed; else added when the squad and the budget allow it.
-- code (0 ok, 1 full, 2 over budget), picked now
function S.pick_toggle(p, uid, cost, budget, size)
  local i = U.index_of(p.uids, uid)
  if i then
    table.remove(p.uids, i)
    p.spent = p.spent - cost
    return 0, false
  end
  if #p.uids >= size then return 1, false end
  if p.spent + cost > budget then return 2, false end
  p.uids[#p.uids + 1] = uid
  p.spent = p.spent + cost
  return 0, true
end

-- ---------------------------------------------------------------------------------------- the team screen

function S.new_team()
  local t = { slots = {}, formation = 0 }
  for i = 1, S.TEAM_SLOTS do t.slots[i] = 0 end
  return t
end

function S.team_copy(t)
  local o = { slots = {}, formation = t.formation }
  for i = 1, S.TEAM_SLOTS do o.slots[i] = t.slots[i] end
  return o
end

-- cost of a player in `slot` (0-based; `base` = his starter cost)
function S.slot_cost(c, base, slot)
  local half = (slot >= S.STARTERS and slot < S.BENCH_END and c.bench_half) or (slot >= S.BENCH_END and c.staff_half)
  if half then return math.max(math.floor((base + 1) / 2), 1) end
  return base
end

function S.team_find(t, uid)
  if uid == 0 then return nil end
  for i = 1, S.TEAM_SLOTS do
    if t.slots[i] == uid then return i - 1 end
  end
  return nil
end

-- points used; base(uid) = the starter cost (nil = unknown uid, counted 0)
function S.team_spent(c, t, base)
  local sum = 0
  for i = 1, S.TEAM_SLOTS do
    local u = t.slots[i]
    if u ~= 0 then
      local b = base(u)
      if b then sum = sum + S.slot_cost(c, b, i - 1) end
    end
  end
  return sum
end

-- (starters, bench, managers, coach) filled
function S.team_counts(t)
  local function n(a, b)
    local k = 0
    for i = a, b - 1 do
      if t.slots[i + 1] ~= 0 then k = k + 1 end
    end
    return k
  end
  return n(0, S.STARTERS), n(S.STARTERS, S.BENCH_END), n(S.BENCH_END, S.MANAGERS_END), n(S.COACH, S.TEAM_SLOTS)
end

-- the team after putting `uid` in `slot`: a player already in the team moves (the occupant takes his old place)
function S.team_with(t, slot, uid)
  local o = S.team_copy(t)
  local old = S.team_find(o, uid)
  if old then o.slots[old + 1] = o.slots[slot + 1] end
  o.slots[slot + 1] = uid
  return o
end

-- code: 0 ok, 1 bad slot, 2 over budget, 3 unknown uid
function S.team_set(c, t, slot, uid, base, budget)
  if slot < 0 or slot >= S.TEAM_SLOTS then return 1, t end
  if base(uid) == nil then return 3, t end
  local o = S.team_with(t, slot, uid)
  if S.team_spent(c, o, base) > budget then return 2, t end
  return 0, o
end

function S.team_ready(c, t, base, budget)
  local st = S.team_counts(t)
  return st == S.STARTERS and S.team_spent(c, t, base) <= budget
end

-- ---------------------------------------------------------------------------------------- the first-run gift

-- 11 players (one per GIFT_POSITIONS entry), rarity 1/2/3 by `weights`, from `pool` ({ param, info }), never a param in
-- `owned` (a set) and no duplicate, total cost (= stars) never above `cap`. `rng` = a guarded xorshift state holder
-- { s = … }. Returns the params.
function S.draw_gift(pool, owned, weights, cap, rng)
  local function nextr()
    rng.s = U.xs_guard(rng.s)
    return rng.s
  end
  local out, taken = {}, {}
  local left = cap
  local n = #S.GIFT_POSITIONS
  for k, pos in ipairs(S.GIFT_POSITIONS) do
    local after = n - k -- players still to draw after this one, at least 1 point each
    local lim = left
    local function allowed(t) return t + after <= lim end
    local w = {}
    local total = 0
    for t = 1, 3 do
      w[t] = allowed(t) and (weights[t] or 0) or 0
      total = total + w[t]
    end
    local tier
    if total == 0 then
      tier = 1
    else
      local r = nextr() % total
      if r < w[1] then tier = 1 elseif r < w[1] + w[2] then tier = 2 else tier = 3 end
    end
    local tries = {
      function(i) return i.tier == tier and i.position == pos end,
      function(i) return i.tier == tier end,
      function(i) return i.tier >= 1 and i.tier <= 3 and allowed(i.tier) end,
    }
    for _, f in ipairs(tries) do
      local cands = {}
      for _, pi in ipairs(pool) do
        local p, i = pi[1], pi[2]
        if not owned[p] and not taken[p] and f(i) then cands[#cands + 1] = pi end
      end
      if #cands > 0 then
        local pick = cands[nextr() % #cands + 1]
        out[#out + 1] = pick[1]
        taken[pick[1]] = true
        left = left - pick[2].tier
        break
      end
    end
  end
  return out
end

return S
