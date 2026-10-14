-- Character Reforged › the per-character stats and their level curve (docs/game/mechanics/stats-system.md §9,
-- docs/refactor/aura-mods-split.md «Per-character data»). Moved from Inazuma Fantasy on 2026-10-14 (its
-- lib\stats_curve.lua; same rows, clamps and rounding), with the curve above Lv 99 following any level cap.
--
-- Data: the chara_param columns 43-54 of the file the game reads (the cards' `stats` / `growth` of any mod's
-- content\characters\**, Character Reforged's own: the retail cards' values): 43 layout (2 = Lv200 values, 1 = Lv99 values,
-- 0 / missing = a retail row), 44 growth (0 slow, 2 fast, else normal), 45-53 the 9 values in engine order (52 retired
-- ex Rapidez: read as 0; 53 Suerte optional: 0 / missing = the mean of the 7 gameplay values, M.derived_luck), 54
-- Libertad (optional); 3 main position, 41 rarity, 5 build type.
--
-- The curve (config.toml [stats], [stats.past_cap], [level]; cap = the level cap in effect, the framework's
-- level.max when it raised the game's cap, else no level above 99):
--   Lv 1..99        lv1 + (v99 - lv1) * t^p,   t = (L - 1) / 98,   lv1 = round(v99 * lv1_ratio),   p = curve_<growth>
--   stored rows     v99 = round(v200 / lv200_factor_<growth>); above 99:
--                   top = v99 + (v200 - v99) * S,   value(L) = v99 + (top - v99) * ((L - 99) / (cap - 99))^curve_post99
--   other rows      (Lv99-value rows and every card without stored values) above 99:
--                   top = round(v99 * (1 + gain_<growth> * S)),   value(L) = v99 + (top - v99) * (1 - (1 - u)^shape),
--                   u = (L - 99) / (cap - 99)
--   S = ((cap - 99) / 101)^cap_scale: 1 at cap 200 (the stored values ARE the Lv 200 values), less below, more above;
--   every value is continuous at 99, rises up to the cap and is clamped to 0..9999. Card multiplier
--   [stats.rarity_mult] last (by chara_param col 41; none = 1).

local M = {}

M.N = 9
M.LUCK = 8
M.RAPIDEZ = 7
M.AGILIDAD = 6
M.FREEDOM = 9
M.MAX_VALUE = 9999
local MAX_VALUE = M.MAX_VALUE
-- the level the stored values are the values of (the data's reference; research/scripts/pe_per_player_build.py reads
-- this line and the cfg_num defaults below)
local TOP_LEVEL = 200
local REF_LEVEL = TOP_LEVEL
local LAYOUT_V1, LAYOUT_V2 = 1, 2
local COL_VERSION, COL_GROWTH, COL_STATS, COL_LIBERTAD = 43, 44, 45, 54

-- the native tables of content\game\stats.toml (exported: other mods' answers read them as
-- "character_reforged/<name>")
M.T_ROW, M.T_VAL, M.T_CONST = "CharacterReforged.StatRow", "CharacterReforged.StatVal", "CharacterReforged.StatConst"

local TWO32 = 4294967296

function M.u32(v)
  if type(v) ~= "number" then return 0 end
  local n = v >= 0 and math.floor(v) or math.ceil(v)
  return n % TWO32
end

local function round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- a value of this mod's merged config.toml (dotted path), `default` when missing or of another type
function M.cfg(path, default)
  local ok, v = pcall(VRFW.files.config, path)
  if not ok or v == nil then return default end
  if default ~= nil and type(v) ~= type(default) then return default end
  return v
end

local function cfg_num(path, default, lo, hi)
  local v = M.cfg(path, default)
  if type(v) ~= "number" or v ~= v or v < lo or v > hi then
    if v ~= default then VRFW.warn(string.format("stats: config %s = %s out of range %s..%s, using %s", path, tostring(v), tostring(lo), tostring(hi), tostring(default))) end
    return default
  end
  return v
end

-- the level cap in effect: the framework's raised cap (level.raised / level.max: [VRFW.Level] of content\characters\level.toml,
-- whose Max follows [level] cap), else 99 (the game's)
function M.cap()
  local okr, raised = pcall(VRFW.state.get, "level.raised")
  local okm, max = pcall(VRFW.state.get, "level.max")
  if okr and okm and raised == 1 and type(max) == "number" and max > 99 then
    return clamp(math.floor(max), 100, 999)
  end
  return 99
end

-- the curve's constants (config.toml, sanitized)
function M.curve()
  local cap = M.cap()
  local c = {
    cap = cap,
    lv1_ratio = cfg_num("stats.lv1_ratio", 0.10, 0, 1),
    p = { [0] = cfg_num("stats.curve_slow", 1.6, 0.05, 20), [1] = cfg_num("stats.curve_normal", 1.0, 0.05, 20), [2] = cfg_num("stats.curve_fast", 0.6, 0.05, 20) },
    f = { [0] = cfg_num("stats.lv200_factor_slow", 1.50, 1, 10), [1] = cfg_num("stats.lv200_factor_normal", 1.35, 1, 10), [2] = cfg_num("stats.lv200_factor_fast", 1.25, 1, 10) },
    q = cfg_num("stats.curve_post99", 0.7, 0.05, 20),
    gain = { [0] = cfg_num("stats.past_cap.gain_slow", 0.50, 0, 10), [1] = cfg_num("stats.past_cap.gain_normal", 0.35, 0, 10), [2] = cfg_num("stats.past_cap.gain_fast", 0.25, 0, 10) },
    shape = cfg_num("stats.past_cap.shape", 2.0, 0.1, 10),
    mult = {},
  }
  local cs = cfg_num("stats.cap_scale", 0.5, 0, 4)
  c.s = cap > 99 and ((cap - 99) / (REF_LEVEL - 99)) ^ cs or 1
  local rm = M.cfg("stats.rarity_mult", {})
  if type(rm) == "table" then
    for k, v in pairs(rm) do
      local r = tonumber(k)
      if r and type(v) == "number" and v >= 0.1 and v <= 10 then c.mult[math.floor(r)] = v
      else VRFW.warn("stats: [stats.rarity_mult] " .. tostring(k) .. " = " .. tostring(v) .. " ignored (a rarity number = 0.1..10)") end
    end
  end
  return c
end

local function growth_of(v)
  if v == 0 then return 0 end
  if v == 2 then return 2 end
  return 1
end

-- Suerte of a card that declares none (owner 2026-10-14: Character Reforged's cards carry no luck value; the game has
-- no Suerte stat of its own): the mean of the card's 7 gameplay values (Disparo .. Agilidad, same level reference),
-- the rule of the original baked roster (docs/game/mechanics/stats-system.md §9.3), so the curve, the training and
-- the radar never show a Suerte of 0
function M.derived_luck(vals)
  local sum = 0
  for k = 0, M.AGILIDAD do sum = sum + (vals[k] or 0) end
  return clamp(round(sum / (M.AGILIDAD + 1)), 0, MAX_VALUE)
end

-- the cards with per-character data: [u32 param id] = { growth, v2, vals[0..8], libertad (nil = no column), pos,
-- rarity, build, agi }; the first row of an id wins
function M.load()
  local cols = { 0, 3, 5, 41, COL_VERSION, COL_GROWTH }
  for k = 0, 9 do cols[#cols + 1] = COL_STATS + k end
  local pos = {}
  for i, c in ipairs(cols) do pos[i] = c + 1 end
  local rows = VRFW.table.raw("data/common/gamedata/character/chara_param_*.cfg.bin", "CHARA_PARAM_INFO", pos) or {}
  local players, n = {}, 0
  for _, r in ipairs(rows) do
    local id, ver = r[1], r[COL_VERSION + 1]
    -- a row needs the version column and the 7 gameplay stat columns (cols 45..51) to be a v1 / v2 row; Suerte
    -- (col 53) is optional: missing or 0 = the derived value (M.derived_luck)
    if type(id) == "number" and (ver == LAYOUT_V1 or ver == LAYOUT_V2) and r[COL_STATS + M.AGILIDAD + 1] ~= nil then
      local key = M.u32(id)
      if not players[key] then
        local vals = {}
        for k = 0, 8 do
          local raw = r[COL_STATS + k + 1]
          raw = type(raw) == "number" and raw or 0
          vals[k] = (k == M.RAPIDEZ) and 0 or clamp(raw, 0, MAX_VALUE)
        end
        if vals[M.LUCK] == 0 then vals[M.LUCK] = M.derived_luck(vals) end
        local lib = r[COL_LIBERTAD + 1]
        if lib ~= nil then lib = clamp(type(lib) == "number" and lib or 0, 0, MAX_VALUE) end
        local function int(c, d) local v = r[c + 1] if type(v) == "number" then return v end return d end
        players[key] = {
          growth = growth_of(int(COL_GROWTH, 1)), v2 = (ver == LAYOUT_V2), vals = vals, libertad = lib,
          pos = int(3, 0), rarity = int(41, 0), build = int(5, 0), sid = id, agi = 500,
        }
        n = n + 1
      end
    end
  end
  M.rank_agility(players)
  return players, n
end

-- Agilidad percentile of every card inside its main position (mid-rank, ties share it), 0..1000; Lv99 rows (layout v1)
-- through x1.35 (the Normal Lv200 factor)
function M.rank_agility(players)
  local by_pos = {}
  for key, p in pairs(players) do
    local a = p.vals[M.AGILIDAD]
    if not p.v2 then a = math.floor((a * 135 + 50) / 100) end
    local list = by_pos[p.pos]
    if not list then list = {} by_pos[p.pos] = list end
    list[#list + 1] = { a, p.sid or key, key }
  end
  for _, v in pairs(by_pos) do
    table.sort(v, function(x, y)
      if x[1] ~= y[1] then return x[1] < y[1] end
      return x[2] < y[2]
    end)
    local n = #v
    local i = 1
    while i <= n do
      local j = i
      while j + 1 <= n and v[j + 1][1] == v[i][1] do j = j + 1 end
      local pm = math.floor(((i - 1 + j - 1 + 1) * 1000 + n) / (2 * n))
      pm = clamp(pm, 0, 1000)
      for k = i, j do players[v[k][3]].agi = pm end
      i = j + 1
    end
  end
end

function M.card_mult(c, p)
  return c.mult[p.rarity] or 1.0
end

-- Lv 1..99 toward v99 (levels < 1 as 1, > 99 as 99)
local function base(c, v99, g, level)
  local t = clamp((math.max(level, 1) - 1) / 98, 0, 1)
  local lv1 = round(v99 * c.lv1_ratio)
  return round(lv1 + (v99 - lv1) * t ^ c.p[g])
end

-- above Lv 99 of a value that is v99 at Lv 99 without a stored top (growth gain g)
function M.past_cap(c, v99, g, level)
  if level <= 99 or v99 <= 0 or c.cap <= 99 then return v99 end
  local u = (math.min(level, c.cap) - 99) / (c.cap - 99)
  local top = round(v99 * (1 + c.gain[g] * c.s))
  return clamp(round(v99 + (top - v99) * (1 - (1 - u) ^ c.shape)), 0, MAX_VALUE)
end

local function anchored(c, v, p, level)
  if not p.v2 then
    if level > 99 then return M.past_cap(c, v, p.growth, level) end
    return base(c, v, p.growth, level)
  end
  local v99 = clamp(round(v / c.f[p.growth]), 0, MAX_VALUE)
  if level <= 99 then return base(c, v99, p.growth, level) end
  if c.cap <= 99 then return v99 end
  local top = v99 + (v - v99) * c.s
  local u = (math.min(level, c.cap) - 99) / (c.cap - 99)
  return clamp(round(v99 + (top - v99) * u ^ c.q), 0, MAX_VALUE)
end

-- the factor of a card's Lv 99 value at `level` for a card with stored Lv 200 values of growth `g` (0 slow, 1 normal,
-- 2 fast), the cap in effect included: the same curve as M.stat without its integer rounding (other mods scale their
-- own per-level values with it, e.g. Stamina Points' max PE: CharacterReforged.LevelFactor)
function M.factor(c, g, level)
  g = (g == 0 or g == 2) and g or 1
  if level <= 99 then
    local t = clamp((math.max(level, 1) - 1) / 98, 0, 1)
    return c.lv1_ratio + (1 - c.lv1_ratio) * t ^ c.p[g]
  end
  if c.cap <= 99 then return 1 end
  local top = 1 + (c.f[g] - 1) * c.s
  local u = (math.min(level, c.cap) - 99) / (c.cap - 99)
  return 1 + (top - 1) * u ^ c.q
end

-- stat `idx` (0..8) of a card at `level`
function M.stat(c, p, idx, level)
  local v = anchored(c, p.vals[idx], p, level)
  local m = M.card_mult(c, p)
  if m == 1.0 then return v end
  return clamp(round(v * m), 0, MAX_VALUE)
end

-- Libertad (the training's ceiling, chara_param col 54) at `level` (0 without the column)
function M.libertad(c, p, level)
  return anchored(c, p.libertad or 0, p, level)
end

-- the native tables of content\game\stats.toml's curve answers. Returns the rows published.
function M.publish(c, players)
  local rows, vals, n = {}, {}, 0
  for key, p in pairs(players) do
    rows[#rows + 1] = { key, {
      v2 = p.v2 and 1 or 0, p = c.p[p.growth], f = c.f[p.growth], q = c.q, ratio = c.lv1_ratio,
      m = M.card_mult(c, p), gain = c.gain[p.growth], agi = p.agi or 500,
    } }
    for i = 0, 7 do vals[#vals + 1] = { { key, i }, p.vals[i] } end
    n = n + 1
  end
  VRFW.native.table_replace(M.T_VAL, nil, vals)
  VRFW.native.table_replace(M.T_ROW, nil, rows)
  VRFW.native.table_replace(M.T_CONST, nil, { { 1, {
    post = c.cap > 99 and 1 or 0, max = math.max(c.cap, 100), shape = c.shape, gain = c.gain[1], s = c.s,
  } } })
  return n
end

return M
