-- InaRogue › INAROGUE: node -> match (docs/game/modes/inarogue.md §14, §31, §33; inarogue-unlocks.md §3b). Was
-- matches.rs of the DLL's module rogue.
--
-- * pool by node kind: pachanga -> the 5v5 rows (own rivals, else the clones), 11v11 / Élite / boss -> the 11v11 rows;
--   the tier window by phase, or (boards of rule 2+) the strength-rank band of the phase (pool.lua);
-- * rival = a seeded draw of (seed, phase, node) (rule 2+: the variety permutation);
-- * difficulty = the ladder rung closest to the phase's target level ([rogue] level_curve, + elite / boss bonus, + the
--   rank spread);
-- * emblematic rivals only on the node kinds of [rogue.rivals] emblematic_on; boss_only / fusion bosses (bosses.lua);
-- * guests ([[rogue.rivals.guest]]): the variant game <row>_g<chara as 8 hex> on a seeded hit.

local U = require "lib/rogue/util"
local map = require "lib/rogue/map"
local pool = require "lib/rogue/pool"
local bosses = require "lib/rogue/bosses"
local growth = require "lib/rogue/growth"
local K = map.KIND

local M = {}

local function kind_key(kind)
  if kind == K.SMALL then return "small" end
  if kind == K.FULL then return "full" end
  if kind == K.ELITE then return "elite" end
  if kind == K.BOSS then return "boss" end
  if kind == K.EPIC then return "epic" end
  if kind == K.GATE then return "gate" end
  return ""
end

-- ---------------------------------------------------------------------------------------- [rogue.rivals]

function M.is_emblematic(rv, row)
  if pool.has_tag(row.id, "emblematic") then return true end
  local rival = U.lower(row.rival)
  for _, e in ipairs(rv.emblematic) do
    local w = U.trim(e)
    if w ~= "" and (U.eq_ascii(w, row.name) or U.lower(w) == rival) then return true end
  end
  return false
end

function M.allows(rv, kind)
  local k = kind_key(kind)
  for _, e in ipairs(rv.emblematic_on) do
    if U.eq_ascii(U.trim(e), k) then return true end
  end
  return false
end

function M.guest_game(row_name, chara)
  return U.crc32(string.format("%s_g%08x", row_name, chara))
end

function M.guest_roll(seed, phase, node)
  local s = U.xor(U.xor(U.xor(seed, U.mul32(math.max(phase, 1), 0x9E3779B9)), U.mul32(node, 0x85EBCA6B)), 0x47554553)
  s = U.xs(math.max(s, 1))
  return s % 10000
end

-- the guest of `row` on node (seed, phase, node): the guests of that rival share one roll
function M.guest_for(rv, row, seed, phase, node)
  local roll = M.guest_roll(seed, phase, node)
  local cum = 0
  for _, g in ipairs(rv.guest) do
    if bosses.names(g.rival, row) then
      cum = cum + U.round(U.clamp(g.chance, 0, 1) * 10000)
      if roll < cum then return g end
    end
  end
  return nil
end

-- the guest's card is in the served chara_param (an absent mod's cards are not: no guest variant game either)
function M.card_served(card)
  local ok, c = pcall(VRFW.chara.card, card)
  return ok and c ~= nil
end

-- the era of a row (the first era one of whose fragments is in the row name); "" = none
function M.era_of(rv, row)
  for _, e in ipairs(rv.eras) do
    for _, f in ipairs(e.frags) do
      if f ~= "" and row.name:find(f, 1, true) then return e.name end
    end
  end
  return ""
end

-- ---------------------------------------------------------------------------------------- levels and tiers

local function curve_at(curve, phase)
  local p = math.max(phase, 1)
  local prev = nil
  for _, r in ipairs(curve) do
    if #r == 2 then
      local x, y = r[1], r[2]
      if x >= p then
        if prev and x > prev[1] then return prev[2] + (y - prev[2]) * (p - prev[1]) / (x - prev[1]) end
        return y
      end
      prev = { x, y }
    end
  end
  return prev and prev[2] or 5.0
end

-- target level of match column `col` (1-based of `cols`) of `phase`: the curve at the phase, rising to the next
-- phase's value for the boss column
function M.target_level(curve, phase, col, cols)
  local a = curve_at(curve, phase)
  local b = math.max(curve_at(curve, phase + 1), a)
  local t
  if cols <= 1 then t = 1.0 else t = U.clamp((math.max(col, 1) - 1) / (cols - 1), 0, 1) end
  return growth.clamp(math.max(U.round(a + (b - a) * t), 1))   -- InaRogue's LevelCap
end

-- tier window (lo, hi) of the pool of `kind` in `phase`
function M.tier_range(kind, phase)
  local p = math.max(phase, 1)
  local hi
  if kind == K.SMALL then
    hi = math.min(1 + math.floor((p - 1) / 2), 4)
  elseif kind == K.BOSS or kind == K.EPIC or kind == K.GATE then
    hi = math.min(1 + math.floor(p / 3), 3)
  else
    hi = math.min(1 + math.floor((p - 1) / 3), 3)
  end
  return math.max(hi - 1, 1), hi
end

function M.pool_kind(kind)
  if kind == K.SMALL then return pool.KIND_SMALL end
  if kind == K.FULL or kind == K.ELITE or kind == K.BOSS or kind == K.EPIC or kind == K.GATE then return pool.KIND_FULL end
  return nil
end

function M.pool_in(kind, phase)
  local pk = M.pool_kind(kind)
  if not pk then return {} end
  local src = pool.source(pk)
  local lo, hi = M.tier_range(kind, phase)
  local v = {}
  for _, r in ipairs(src) do
    if r.tier >= lo and r.tier <= hi then v[#v + 1] = r end
  end
  if #v == 0 then return src end
  return v
end

local function filter(list, f)
  local o = {}
  for _, r in ipairs(list) do
    if f(r) then o[#o + 1] = r end
  end
  return o
end

-- the pool of a node under the board's rule (ctx: cfg, cat = the boss catalogue or nil, beaten set)
function M.pool_ruled(kind, phase, rule, ctx)
  local rv = ctx.cfg.rivals
  local v = M.pool_in(kind, phase)
  if rule >= 2 then
    local f = pool.ranks(rv.ranks)
    local pk = M.pool_kind(kind)
    if f and pk then
      local b = pool.rank_filter(f, pool.source(pk), kind, phase)
      if b then v = b end
    end
  end
  local c = ctx.cat
  if c and rule >= bosses.RULE and (kind == K.BOSS or kind == K.GATE) then
    if bosses.has_requires(c) then
      local keep = filter(v, function(r) return not bosses.locked_in(c, r, ctx.beaten) end)
      if #keep > 0 then v = keep end
    end
  elseif c and rule >= bosses.RULE then
    local req = bosses.has_requires(c)
    local keep = filter(v, function(r)
      return not bosses.tagged(c, r, bosses.BOSS_ONLY, pool) and not (req and bosses.locked_in(c, r, ctx.beaten))
    end)
    if #keep > 0 then v = keep end
  end
  if rule == 0 or #rv.emblematic == 0 or M.allows(rv, kind) then return v end
  local keep = filter(v, function(r) return not M.is_emblematic(rv, r) end)
  if #keep > 0 then return keep end
  local pk = M.pool_kind(kind)
  local all = pk and filter(pool.source(pk), function(r) return not M.is_emblematic(rv, r) end) or {}
  if #all == 0 then return v end
  return all
end

-- the ladder rung of `row` closest to `target` (ties: the lower level)
function M.closest_diff(row, target)
  local best, bd, bl = nil, nil, nil
  for _, l in ipairs(row.ladder) do
    local d = math.abs(l[2] - target)
    if best == nil or d < bd or (d == bd and l[2] < bl) then
      best, bd, bl = l, d, l[2]
    end
  end
  if not best then return nil end
  return best[1], best[2]
end

-- the phase boss level (the curve at the boss column + boss_bonus)
function M.boss_level(c, phase, cols)
  local n = math.max(cols, 1)
  return growth.clamp(M.target_level(c.level_curve, phase, n, n) + c.boss_bonus)
end

-- the match of node `node` ({ kind }, match column `col` 1-based of `cols`) in `phase` of run `seed` under `rule`;
-- ctx = { cfg, cat, beaten }
function M.pick(seed, phase, node, kind, col, cols, rule, ctx)
  local c = ctx.cfg
  if ctx.cat and c.bosses.enabled then
    local p = bosses.pick(ctx.cat, seed, phase, node, kind, cols, rule, {
      cfg = c, pool = pool, matches = M, beaten = ctx.beaten,
      boss_level = function(p2, n) return M.boss_level(c, p2, n) end,
    })
    if p then return p end
  end
  local rows = M.pool_ruled(kind, phase, rule, ctx)
  if #rows == 0 then return nil end
  local s = math.max(U.xor(U.xor(U.xor(seed, U.mul32(math.max(phase, 1), 0x2545F491)), U.mul32(node, 0x9E3779B9)), 0x004D4154), 1)
  s = U.xs(s)
  local idx
  if rule >= 2 then idx = pool.variety_index(rows, seed, phase, node) else idx = s % #rows + 1 end
  local row = rows[idx]
  local target = M.target_level(c.level_curve, phase, col, cols)
  if kind == K.ELITE then target = target + c.elite_bonus elseif kind == K.BOSS then target = target + c.boss_bonus end
  target = growth.clamp(target)
  if rule >= 2 then
    local f = pool.ranks(c.rivals.ranks)
    if f then target = growth.clamp(target + pool.level_shift(f, row, kind, phase)) end
  end
  local diff, level = M.closest_diff(row, target)
  if not diff then return nil end
  local g = M.guest_for(c.rivals, row, seed, phase, node)
  if g and not M.card_served(g.chara) then g = nil end
  local guest = g and g.chara or 0
  local game = guest ~= 0 and M.guest_game(row.name, guest) or row.id
  return { row = row, diff = diff, level = level, target = target, game = game, guest = guest }
end

-- the row of a game id (own rows first, then the clones, then the special bosses), also a guest variant's row
function M.row_of(id, rv)
  for _, r in ipairs(pool.own()) do
    if r.id == id then return r end
  end
  for _, r in ipairs(pool.clones()) do
    if r.id == id then return r end
  end
  for _, r in ipairs(bosses.rows()) do
    if r.id == id then return r end
  end
  if rv then
    for _, r in ipairs(pool.clones()) do
      for _, g in ipairs(rv.guest) do
        if bosses.names(g.rival, r) and M.guest_game(r.name, g.chara) == id then return r end
      end
    end
  end
  return nil
end

return M
