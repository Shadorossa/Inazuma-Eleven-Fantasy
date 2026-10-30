-- Player Training › the per-card values the training reads (the untrained Suerte base and Libertad, the main position,
-- the growth type), asked to Character Reforged's exports (CharacterReforged.StatsReady / StatCard / StatAt / Libertad;
-- its mod.toml [exports]). Moved from Inazuma Fantasy's lib\stats_curve.lua 2026-10-14 (same answers). The cards that
-- cannot be trained (no Libertad) are the rarities of config.toml [training] locked_rarities (Diamond / Prime). A card of
-- derived_freedom_rarities (Hero) that stores no Libertad gets a derived one (M.configure_freedom, M.libertad).

local M = {}

M.N = 9
M.LUCK = 8

local Id = require "VRFW/lib/ids"
local u32 = Id.u32
M.u32 = u32

-- Character Reforged published its per-card tables
function M.ready()
  local ok, r = pcall(function() return CharacterReforged.StatsReady() end)
  return ok and r == true
end

-- one card: { key, growth, vals[0..8], libertad, pos, rarity }, or nil
local function card(key)
  local ok, r = pcall(function() return CharacterReforged.StatCard(key) end)
  if not ok or type(r) ~= "table" then return nil end
  local vals = {}
  for i = 0, 8 do
    local v = type(r.vals) == "table" and r.vals[i] or nil
    vals[i] = type(v) == "number" and v or 0
  end
  return { key = key, growth = r.growth or 1, vals = vals, libertad = r.libertad, pos = r.pos or 0, rarity = r.rarity or 0 }
end

-- the cards with per-character values, looked up per param id (a card asked before Character Reforged published its
-- tables reads as none and is asked again later). Only for lookups by id (no pairs / ipairs over the result).
function M.players()
  local miss = {}
  return setmetatable({}, { __index = function(t, key)
    if type(key) ~= "number" then return nil end
    key = u32(key)
    if miss[key] then return nil end
    if not M.ready() then return nil end
    local p = card(key)
    if p then rawset(t, key, p) else miss[key] = true end
    return p
  end })
end

-- a card that cannot be trained (rarity in `locked`, a set { [rarity] = true })
function M.locked(p, locked)
  return locked[p.rarity] == true
end

-- stat `idx` (0..8) of a card at `level`
function M.stat(p, idx, level)
  local ok, v = pcall(function() return CharacterReforged.StatAt(p.key, idx, level) end)
  if ok and type(v) == "number" then return v end
  return p.vals[idx] or 0
end

-- the derived-Libertad rule: { rarities = set, ceiling, min, max } (config.toml [training] derived_freedom_*, freedom_*)
local FREEDOM = nil
function M.configure_freedom(rule)
  FREEDOM = rule
end

-- the Libertad a card without a stored one gets: clamp(ceiling - sum of its Lv 99 stats, min, max) at Lv 99, grown with
-- the level by the card's own stat curve; nil when the card's rarity has no derived rule
local function derived_libertad(p, level)
  if not FREEDOM or not FREEDOM.rarities[p.rarity] then return nil end
  local okc, curve = pcall(function() return CharacterReforged.StatCurve() end)
  if not okc or type(curve) ~= "table" or type(curve.f) ~= "table" then return nil end
  local growth = p.growth
  local top = (p.v2 and curve.f[growth]) or 1 -- layout-v2 rows store Lv 200 values; v1 rows store Lv 99
  if type(top) ~= "number" or top <= 0 then top = 1 end
  local sum = 0
  for i = 0, M.N - 1 do sum = sum + (p.vals[i] or 0) / top end
  local lib99 = math.max(FREEDOM.min, math.min(FREEDOM.max, FREEDOM.ceiling - math.floor(sum + 0.5)))
  local okf, factor = pcall(function() return CharacterReforged.LevelFactor(level, growth) end)
  if not okf or type(factor) ~= "number" then return nil end
  return math.floor(lib99 * factor + 0.5)
end

-- Libertad at `level` (0 without the column and without a derived rule for the card's rarity)
function M.libertad(p, level)
  local ok, v = pcall(function() return CharacterReforged.Libertad(p.key, level) end)
  if ok and type(v) == "number" and v > 0 then return v end
  return derived_libertad(p, level) or 0
end

return M
