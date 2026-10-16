-- InaRogue › INAROGUE: the roguelite view of chara_param (the chara_param the game reads: the mods overlay's
-- served file, else the game's). Read once, on first use.
--
-- * col 57 `evt_rogue_rarity`: the star tier 1-5 (0 / missing = not a roguelite player; 11-15 = a «What if» card
--   with 1-5 stars, docs/game/modes/inarogue-whatif.md);
-- * cols 2 element, 3 position, 9 rank, 41 card type (0 normal, 5-7 Hero, 8 Diamond, 9/10 Prime);
-- * the Lv99-equivalent total of the 7 main stats (cols 45..51; layout col 43: 1 = Lv99 values, 2 = Lv200 values
--   divided by the growth type's (col 44) [stats] lv200_factor_*), 0 = no per-player stats.

local U = require "lib/rogue/util"
local info, warn = U.logger("rogue")

local M = {}

local COL_ID, COL_ELEMENT, COL_POSITION, COL_RANK, COL_SPECIAL = 0, 2, 3, 9, 41
local COL_STATS_VERSION, COL_GROWTH, COL_STAT0, MAIN_STATS, COL_ROGUE_RARITY = 43, 44, 45, 7, 57
M.WHATIF_BASE, M.MAX_TIER = 10, 5

local loaded = nil

local function intv(v)
  if type(v) ~= "number" then return nil end
  return v
end

local function build()
  local t = { map = {}, pool = {}, whatif = {}, rows = 0, with_column = 0, per_tier = { [0] = 0, 0, 0, 0, 0, 0 } }
  local f = {
    U.cfg("stats.lv200_factor_slow", 1.5),
    U.cfg("stats.lv200_factor_normal", 1.35),
    U.cfg("stats.lv200_factor_fast", 1.25),
  }
  local cols = { COL_ID, COL_ELEMENT, COL_POSITION, COL_RANK, COL_SPECIAL, COL_STATS_VERSION, COL_GROWTH }
  for k = 0, MAIN_STATS - 1 do cols[#cols + 1] = COL_STAT0 + k end
  cols[#cols + 1] = COL_ROGUE_RARITY
  local pos = {}
  for i, c in ipairs(cols) do pos[i] = c + 1 end
  local ok, rows = pcall(VRFW.table.raw, "data/common/gamedata/character/chara_param_*.cfg.bin", "CHARA_PARAM_INFO", pos)
  if not ok or type(rows) ~= "table" then
    warn("no chara_param readable (" .. tostring(rows) .. "): every player counts as 1 star")
    return t
  end
  for _, r in ipairs(rows) do
    t.rows = t.rows + 1
    local id = intv(r[COL_ID + 1])
    if id then
      id = id % U.TWO32
      local raw = 0
      if r[COL_ROGUE_RARITY + 1] ~= nil then
        t.with_column = t.with_column + 1
        raw = intv(r[COL_ROGUE_RARITY + 1]) or 0
      end
      local whatif = raw >= M.WHATIF_BASE + 1 and raw <= M.WHATIF_BASE + M.MAX_TIER
      local tier = 0
      if raw >= 1 and raw <= M.MAX_TIER then tier = raw elseif whatif then tier = raw - M.WHATIF_BASE end
      -- the stat total (0 = no per-player stats)
      local total = 0
      local ver = intv(r[COL_STATS_VERSION + 1]) or 0
      if (ver == 1 or ver == 2) and r[COL_STAT0 + MAIN_STATS] ~= nil then
        local sum = 0
        for k = 0, MAIN_STATS - 1 do sum = sum + math.max(intv(r[COL_STAT0 + k + 1]) or 0, 0) end
        if ver == 1 then
          total = sum
        else
          local g = intv(r[COL_GROWTH + 1]) or 1
          local fac = f[(g >= 0 and g <= 2) and g + 1 or 2]
          if fac <= 0 then total = sum else total = U.round(sum / fac) end
        end
      end
      if t.map[id] == nil then
        local function b(v) return U.clamp(intv(v) or 0, 0, 255) end
        local i = {
          tier = tier,
          card = b(r[COL_SPECIAL + 1]),
          element = b(r[COL_ELEMENT + 1]),
          position = b(r[COL_POSITION + 1]),
          rank = b(r[COL_RANK + 1]),
          stat_total99 = total,
          whatif = whatif,
        }
        t.map[id] = i
        t.per_tier[tier] = t.per_tier[tier] + 1
        if tier >= 1 and tier <= M.MAX_TIER and i.card == 0 and not whatif then t.pool[#t.pool + 1] = id end
        if whatif then t.whatif[#t.whatif + 1] = id end
      end
    end
  end
  info(string.format("%d chara_param rows (%d with col 57), tiers 0..5 = [%d, %d, %d, %d, %d, %d], draw pool %d, What-if cards %d",
    t.rows, t.with_column, t.per_tier[0], t.per_tier[1], t.per_tier[2], t.per_tier[3], t.per_tier[4], t.per_tier[5],
    #t.pool, #t.whatif))
  if t.with_column == 0 then
    warn("no chara_param row has col 57 evt_rogue_rarity: every player counts as 1 star")
  end
  return t
end

-- the table (read on first use)
function M.table()
  if not loaded then loaded = build() end
  return loaded
end

function M.get(param)
  return M.table().map[param]
end

-- the tier a card shows: col 57 when set, else 1
function M.shown_tier(i)
  if i and i.tier >= 1 and i.tier <= M.MAX_TIER then return i.tier end
  return 1
end

-- INAROGUE tier 1-5 as its cards show it (What-if cards included); 0 = none
function M.star_tier(param)
  local i = M.get(param)
  if i and i.tier >= 1 and i.tier <= M.MAX_TIER then return i.tier end
  return 0
end

function M.tier_of(param)
  return M.shown_tier(M.get(param))
end

function M.in_pool(i)
  return i.tier >= 1 and i.tier <= M.MAX_TIER and i.card == 0 and not i.whatif
end

function M.is_whatif(param)
  local i = M.get(param)
  return i ~= nil and i.whatif
end

return M
