-- InaRogue › «Espíritus» (PokeRogue candies; docs/game/mods/inarogue-loop-v2.md «Espíritus»): a player recruited again
-- while he is already in the collection gives spirits of THAT player instead of a duplicate. They are kept per
-- collection entry (the bank's card, chara_param: an alternate card of the same character is another entry with its
-- own spirits) in the bank blob, untouched by the end of a run. Spending them buys cost reduction levels: level n costs
-- tiers[n] spirits and lowers his starter cost by 1, never below `floor`. Rules: config.toml [rogue.spirits]. Pure.

local U = require "lib/rogue/util"

local M = {}

local DEFAULTS = {
  tiers = { 5, 10, 20, 35 },
  floor = 1,
  amounts = { small = 2, full = 3, elite = 5, boss = 8, big_boss = 12, epic = 5, gate = 6, shop = 3, event = 3, other = 3 },
}

local cache = nil

function M.get()
  if cache then return cache end
  local t = U.cfg("rogue.spirits", {})
  if type(t) ~= "table" then t = {} end
  local tiers = {}
  for _, v in ipairs(type(t.tiers) == "table" and t.tiers or DEFAULTS.tiers) do
    local n = U.int(v, 0)
    if n > 0 then tiers[#tiers + 1] = n end
  end
  if #tiers == 0 then tiers = DEFAULTS.tiers end
  local amounts = {}
  local a = type(t.amounts) == "table" and t.amounts or {}
  for k, v in pairs(DEFAULTS.amounts) do amounts[k] = math.max(U.int(a[k], v), 0) end
  cache = { tiers = tiers, floor = math.max(U.int(t.floor, DEFAULTS.floor), 1), amounts = amounts }
  return cache
end

-- spirits a duplicate of `source` gives (small / full / elite / boss / epic / gate / shop / event / other)
function M.amount(source)
  local a = M.get().amounts
  return a[source] or a.other
end

-- spirits the next level costs (nil = every level bought)
function M.next_cost(level)
  return M.get().tiers[(level or 0) + 1]
end

-- the cost after the spirit levels: `cost` (fragments already counted) - level, never below the floor
function M.apply(cost, level)
  return math.max(cost - (level or 0), M.get().floor)
end

-- a level can be bought: the spirits reach its price and it still lowers the cost
function M.can_level(cost_before, level, spirits)
  local price = M.next_cost(level)
  return price ~= nil and spirits >= price and M.apply(cost_before, level + 1) < M.apply(cost_before, level)
end

return M
