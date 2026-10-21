-- InaRogue › INAROGUE: loot of a Cofre node and of a won phase boss (docs/game/modes/inarogue.md §20 M4), and the
-- gacha coins' draw (§12.5 V3). Was loot.rs and gacha.rs of the DLL's module rogue; tables content\rogue\loot.toml and
-- content\rogue\gacha.toml (research/scripts/rogue_loot_build.py, rogue_gacha_table.py).
--
-- * Gear (equipment) and moves (solo hissatsu) are real game items the Lua gives with CMND_ADD_ITEM_ONLY; formations
--   are the third kind (formations.lua). A roll is a pure function of (run seed, phase, node, salt).
-- * A gacha coin draws a character of a Players Universe star sign from the game's own rates (no retail lottery call);
--   a coach / manager card is never drawn.

local U = require "lib/rogue/util"
local chara = require "lib/rogue/chara"
local warn = select(2, U.logger("rogue"))

local L = {}

L.KIND = { NONE = 0, GEAR = 1, MOVE = 2, FORMATION = 3 }
L.SALT = { COFRE = 1, BOSS = 2 }
L.FORMATION_PCT = 20

local tables = nil

local function load()
  if tables then return tables end
  tables = { gear = {}, moves = {} }
  local ok, t = pcall(VRFW.files.toml, "content/rogue/loot.toml")
  if not ok or type(t) ~= "table" then
    warn("content/rogue/loot.toml not readable (" .. tostring(t) .. "): no gear / move loot")
    return tables
  end
  for _, k in ipairs({ "gear", "moves" }) do
    for _, r in ipairs(type(t[k]) == "table" and t[k] or {}) do
      tables[k][#tables[k] + 1] = { r.id % U.TWO32, r.tier, r.name }
    end
  end
  return tables
end

function L.roll_seed(seed, phase, node, salt)
  local s = U.xor(U.xor(U.xor(U.xor(U.rotl(seed, 7), U.mul32(phase, 0x9E3779B9)), U.mul32(node, 0x85EBCA6B)),
    U.mul32(salt, 0x27D4EB2F)), 0x1007C0FE)
  if s == 0 then s = 0x1007C0FE end
  return U.xs(s)
end

-- tier window of a phase (a boss roll one tier up)
function L.tiers(phase, boss)
  local hi = math.min(1 + math.floor((math.max(phase, 1) - 1) / 3) + (boss and 1 or 0), 4)
  return math.max(hi - 1, 1), hi
end

-- the category of a roll; st = { s }
function L.category(st)
  st.s = U.xs(st.s)
  local x = st.s % 100
  if x < L.FORMATION_PCT then return L.KIND.FORMATION end
  if x < L.FORMATION_PCT + math.floor((100 - L.FORMATION_PCT) / 2) then return L.KIND.GEAR end
  return L.KIND.MOVE
end

-- a gear / move item of the tier window: the higher tier 2 times in 3; { kind, id, tier, name } or nil
function L.item(k, st, phase, boss)
  local t = load()
  local tbl
  if k == L.KIND.GEAR then tbl = t.gear elseif k == L.KIND.MOVE then tbl = t.moves else return nil end
  local lo, hi = L.tiers(phase, boss)
  local tier = hi
  if lo < hi then
    st.s = U.xs(st.s)
    if st.s % 3 == 0 then tier = lo end
  end
  local p = {}
  for _, r in ipairs(tbl) do
    if r[2] == tier then p[#p + 1] = r end
  end
  if #p == 0 then p = tbl end
  if #p == 0 then return nil end
  st.s = U.xs(st.s)
  local r = p[st.s % #p + 1]
  return { kind = k, id = r[1], tier = r[2], name = r[3] }
end

-- ---------------------------------------------------------------------------------------- gacha coins

local gacha = nil

local function load_gacha()
  if gacha then return gacha end
  gacha = { signs = {}, charas = {} }
  local ok, t = pcall(VRFW.files.toml, "content/rogue/gacha.toml")
  if not ok or type(t) ~= "table" then
    warn("content/rogue/gacha.toml not readable (" .. tostring(t) .. "): no gacha draws")
    return gacha
  end
  for _, s in ipairs(type(t.sign) == "table" and t.sign or {}) do
    gacha.signs[#gacha.signs + 1] = { no = s.no, id = s.id % U.TWO32, buckets = s.buckets }
  end
  local l = type(t.charas) == "table" and t.charas.list or {}
  for i = 1, #l - 2, 3 do gacha.charas[#gacha.charas + 1] = { l[i] % U.TWO32, l[i + 1], l[i + 2] } end
  return gacha
end

local function pick(weights, r)
  local total = 0
  for _, w in ipairs(weights) do total = total + w end
  if total == 0 then return nil end
  local x = r % total
  for i, w in ipairs(weights) do
    if x < w then return i end
    x = x - w
  end
  return nil
end

-- draw from the star sign `sign` (its id crc, or its number 1-30): param, charaRarity, rarityType, index (0-based in the
-- characters table); `rnd()` gives random u32s
function L.gacha_draw(sign, rnd)
  local g = load_gacha()
  local s = nil
  for _, x in ipairs(g.signs) do
    if x.id == sign or x.no == sign then
      s = x
      break
    end
  end
  if not s then return nil end
  local w = {}
  for i, b in ipairs(s.buckets) do w[i] = b[2] end
  local b = pick(w, rnd())
  if not b then return nil end
  local rtype, first, count = s.buckets[b][1], s.buckets[b][3], s.buckets[b][4]
  if first + count > #g.charas then return nil end
  local cw = {}
  for k = 1, count do cw[k] = chara.is_staff(g.charas[first + k][1]) and 0 or g.charas[first + k][3] end
  local i = pick(cw, rnd())
  if not i then return nil end
  local row = g.charas[first + i]
  return row[1], row[2], rtype, first + i - 1
end

return L
