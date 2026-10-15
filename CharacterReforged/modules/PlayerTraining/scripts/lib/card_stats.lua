-- Player Training › the per-card values the training reads (the untrained Suerte base and Libertad, the main position,
-- the growth type), asked to Character Reforged's exports (CharacterReforged.StatsReady / StatCard / StatAt / Libertad;
-- its mod.toml [exports]). Moved from Inazuma Fantasy's lib\stats_curve.lua 2026-10-14 (same answers). The cards that
-- cannot be trained (no Libertad) are the rarities of config.toml [training] locked_rarities (Inazuma Fantasy's rule:
-- Hero / Diamond / Prime).

local M = {}

M.N = 9
M.LUCK = 8

local function u32(v)
  if type(v) ~= "number" then return 0 end
  local n = v >= 0 and math.floor(v) or math.ceil(v)
  return n % 4294967296
end
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

-- Libertad at `level` (0 without the column)
function M.libertad(p, level)
  local ok, v = pcall(function() return CharacterReforged.Libertad(p.key, level) end)
  if ok and type(v) == "number" then return v end
  return 0
end

return M
