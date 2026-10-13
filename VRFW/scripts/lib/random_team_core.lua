-- VR-Framework › random team, the pure part (docs/framework/random-team.md): the seeded generator, the card filters
-- and the pick of a roster. No game memory, no engine call: everything here works on plain Lua tables, so the same
-- inputs always give the same team (the determinism the service promises: same rule + seed + node + stage + pool =
-- same roster, same name / emblem / kit).
--
-- Numbers are Lua 5.2 doubles; hashes and seeds are u32 (0 .. 2^32-1). Card positions are chara_param's
-- (1 keeper, 2 forward, 3 midfield, 4 defence); a formation placement is a class of the same numbers.

local C = {}

local band, bor, bxor, rshift = bit32.band, bit32.bor, bit32.bxor, bit32.rshift
local floor = math.floor
local TWO32 = 4294967296

C.POS_GK, C.POS_FW, C.POS_MF, C.POS_DF = 1, 2, 3, 4

function C.u32(v)
  if type(v) ~= "number" or v ~= v then
    return 0
  end
  return floor(v) % TWO32
end

function C.hex(v)
  return string.format("0x%08X", C.u32(v))
end

-- ------------------------------------------------------------------------------------------------ hashing

-- (a * b) mod 2^32 on 16-bit halves (every partial product stays below 2^53)
local function imul(a, b)
  local ah, al = floor(a / 65536), a % 65536
  local bh, bl = floor(b / 65536), b % 65536
  return (((ah * bl + al * bh) % 65536) * 65536 + al * bl) % TWO32
end

-- murmur3's finaliser: a well-spread u32 from a u32
function C.fmix(h)
  h = C.u32(h)
  h = bxor(h, rshift(h, 16))
  h = imul(h, 0x85EBCA6B)
  h = bxor(h, rshift(h, 13))
  h = imul(h, 0xC2B2AE35)
  return bxor(h, rshift(h, 16))
end

-- one u32 from a list of u32 parts (order matters)
function C.mix(parts)
  local h = 0x9747B28C
  for _, p in ipairs(parts) do
    h = C.fmix(bxor(h, C.fmix(C.u32(p))) + 0x9E3779B9)
  end
  return h
end

-- a seed argument (a game Lua number: up to 2^53, possibly negative) as two u32 halves
function C.split(v)
  if type(v) ~= "number" or v ~= v then
    return 0, 0
  end
  v = floor(v) % 9007199254740992
  return C.u32(floor(v / TWO32)), C.u32(v)
end

-- ------------------------------------------------------------------------------------------------ generator

local Rng = {}
Rng.__index = Rng

-- mulberry32: a small generator whose whole state is one u32
function C.rng(seed)
  return setmetatable({ s = C.u32(seed) }, Rng)
end

function Rng:next()
  self.s = (self.s + 0x6D2B79F5) % TWO32
  local t = self.s
  t = imul(bxor(t, rshift(t, 15)), bor(t, 1))
  t = bxor(t, (t + imul(bxor(t, rshift(t, 7)), bor(t, 61))) % TWO32)
  return bxor(t, rshift(t, 14))
end

-- uniform in 0 .. n-1 (n >= 1)
function Rng:below(n)
  n = floor(n)
  if n <= 1 then
    return 0
  end
  return floor(self:next() / TWO32 * n)
end

-- uniform in lo .. hi (whole numbers, lo <= hi)
function Rng:range(lo, hi)
  if hi < lo then
    lo, hi = hi, lo
  end
  return lo + self:below(hi - lo + 1)
end

-- index (1-based) of a weighted draw over `w` (weights >= 0); nil when every weight is 0
function Rng:weighted(w)
  local total = 0
  for _, x in ipairs(w) do
    if x > 0 then
      total = total + x
    end
  end
  if total <= 0 then
    return nil
  end
  local r = self:next() / TWO32 * total
  local acc = 0
  local last
  for i, x in ipairs(w) do
    if x > 0 then
      acc = acc + x
      last = i
      if r < acc then
        return i
      end
    end
  end
  return last
end

-- ------------------------------------------------------------------------------------------------ declaration values

-- a [min, max] pair from a number or a list (nil = none)
function C.range(v)
  if type(v) == "number" then
    return { floor(v), floor(v) }
  end
  if type(v) == "table" and type(v[1]) == "number" then
    local lo, hi = floor(v[1]), floor(type(v[2]) == "number" and v[2] or v[1])
    if hi < lo then
      lo, hi = hi, lo
    end
    return { lo, hi }
  end
  return nil
end

-- a set { [n] = true } from a number or a list of numbers (nil = none)
function C.num_set(v, conv)
  conv = conv or function(x)
    return type(x) == "number" and floor(x) or nil
  end
  if v == nil then
    return nil
  end
  if type(v) ~= "table" then
    v = { v }
  end
  local s, any = {}, false
  for _, x in ipairs(v) do
    local n = conv(x)
    if n ~= nil then
      s[n] = true
      any = true
    end
  end
  return any and s or nil
end

-- a weight table { ["key"] = w } with number-like keys: { [n] = w } (nil = none)
function C.weights(v)
  if type(v) ~= "table" then
    return nil
  end
  local out, any = {}, false
  for k, w in pairs(v) do
    local n = tonumber(k)
    if n ~= nil and type(w) == "number" and w >= 0 then
      out[floor(n)] = w
      any = true
    end
  end
  return any and out or nil
end

-- ------------------------------------------------------------------------------------------------ card filters

-- A compiled filter row: every key it has must hold (AND). Keys (docs/framework/random-team.md §3.1): element,
-- position, rarity, series (series type numbers), team (belong teams), cards, characters, mod (the card's maker),
-- gender, columns = { [col] = { lo, hi } }. A card: { id, base, element, pos, rarity, gender, series = {[t]=true},
-- teams = {[id]=true}, mod, cols = { [col] = v } }.
function C.match(f, c)
  if f.cards and not f.cards[c.id] then
    return false
  end
  if f.characters and not f.characters[c.base] then
    return false
  end
  if f.element and not f.element[c.element] then
    return false
  end
  if f.position and not f.position[c.pos] then
    return false
  end
  if f.rarity and not f.rarity[c.rarity] then
    return false
  end
  if f.gender and not f.gender[c.gender] then
    return false
  end
  if f.mod and not f.mod[c.mod or "game"] then
    return false
  end
  if f.series then
    local hit = false
    for t in pairs(f.series) do
      if c.series and c.series[t] then
        hit = true
        break
      end
    end
    if not hit then
      return false
    end
  end
  if f.team then
    local hit = false
    for t in pairs(f.team) do
      if c.teams and c.teams[t] then
        hit = true
        break
      end
    end
    if not hit then
      return false
    end
  end
  if f.columns then
    for col, r in pairs(f.columns) do
      local v = c.cols and c.cols[col]
      if type(v) ~= "number" or v < r[1] or v > r[2] then
        return false
      end
    end
  end
  return true
end

-- the pool: the cards (in `cards` order) that pass some include row (or every card when there is none) and no
-- exclude row
function C.pool(cards, include, exclude)
  local out = {}
  for _, c in ipairs(cards) do
    local ok = #include == 0
    for _, f in ipairs(include) do
      if C.match(f, c) then
        ok = true
        break
      end
    end
    if ok then
      for _, f in ipairs(exclude) do
        if C.match(f, c) then
          ok = false
          break
        end
      end
    end
    if ok then
      out[#out + 1] = c
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ the roster

-- The places to fill, in order: { class = POS_* or 0 (any outfield) , row = k } with the keepers first, then the
-- starters by placement order, then the bench (its first place a keeper when `bench_keeper`).
function C.places(starter_classes, bench_rows, bench_keeper)
  local out = {}
  for k, cls in ipairs(starter_classes) do
    if cls == C.POS_GK then
      out[#out + 1] = { class = cls, index = k, bench = false }
    end
  end
  for k, cls in ipairs(starter_classes) do
    if cls ~= C.POS_GK then
      out[#out + 1] = { class = cls, index = k, bench = false }
    end
  end
  for k = 1, bench_rows do
    out[#out + 1] = { class = (k == 1 and bench_keeper) and C.POS_GK or 0, index = k, bench = true }
  end
  return out
end

-- Pick the roster. `opt`:
--   pool          the cards (C.pool), in a fixed order
--   places        C.places(...)
--   unique        "character" (default: one card per chara_base) or "card"
--   rarity_w      { [rarity] = weight } (nil = every rarity weight 1; a rarity missing from the table = 0)
--   tier_col, tier  the column and its { lo, hi } a card must be in (nil = none)
--   element_w     { [element] = weight } (nil = 1 each)
--   max_same      most cards of one element (nil = no cap)
--   theme         { chance (0..1), weight (multiplier) }: with that chance one element is the team's theme
--   rng           C.rng(...)
-- Returns { picks = { [i] = card } (places order), theme = element or nil, fallbacks = n }, or nil, why.
function C.pick(opt)
  local rng = opt.rng
  local base = {}
  for _, c in ipairs(opt.pool) do
    local w = 1
    if opt.rarity_w then
      w = opt.rarity_w[c.rarity] or 0
    end
    if w > 0 and opt.tier_col and opt.tier then
      local v = c.cols and c.cols[opt.tier_col]
      if type(v) ~= "number" or v < opt.tier[1] or v > opt.tier[2] then
        w = 0
      end
    end
    if w > 0 and opt.element_w then
      w = w * (opt.element_w[c.element] or 0)
    end
    if w > 0 then
      base[#base + 1] = { c = c, w = w }
    end
  end
  if #base == 0 then
    return nil, "no card of the pool fits this stage (rarity / tier / element weights)"
  end
  -- the theme element (drawn even when unused, so the draw count never depends on the pool)
  local theme
  local roll = rng:next() / TWO32
  local elements = {}
  local seen = {}
  for _, e in ipairs(base) do
    if not seen[e.c.element] then
      seen[e.c.element] = true
      elements[#elements + 1] = e.c.element
    end
  end
  table.sort(elements)
  local pick_el = elements[rng:below(#elements) + 1]
  if opt.theme and opt.theme.chance > 0 and roll < opt.theme.chance then
    theme = pick_el
  end
  local used_key, per_el, picks = {}, {}, {}
  local fallbacks = 0
  local function key(c)
    if opt.unique == "card" then
      return c.id
    end
    return c.base ~= 0 and c.base or c.id
  end
  local function draw(want, relax)
    local list, w = {}, {}
    for _, e in ipairs(base) do
      local c = e.c
      local fits
      if want == C.POS_GK then
        fits = c.pos == C.POS_GK
      elseif want == 0 or relax then
        fits = c.pos ~= C.POS_GK and c.pos >= 1 and c.pos <= 4
      else
        fits = c.pos == want
      end
      if fits and not used_key[key(c)] and not (opt.max_same and (per_el[c.element] or 0) >= opt.max_same) then
        local x = e.w
        if theme and c.element == theme then
          x = x * opt.theme.weight
        end
        list[#list + 1] = c
        w[#w + 1] = x
      end
    end
    local i = rng:weighted(w)
    return i and list[i] or nil
  end
  for i, p in ipairs(opt.places) do
    local c = draw(p.class, false)
    if not c and p.class ~= C.POS_GK and p.class ~= 0 then
      c = draw(p.class, true)
      if c then
        fallbacks = fallbacks + 1
      end
    end
    if not c and p.class == C.POS_GK and p.bench then
      -- a bench keeper the pool cannot give: any outfield player instead
      c = draw(0, true)
      if c then
        fallbacks = fallbacks + 1
      end
    end
    if not c then
      if p.class == C.POS_GK then
        return nil, "no goalkeeper left in the pool for this stage"
      end
      return nil, string.format("pool too small: place %d of %d has no card left (no duplicates%s)", i, #opt.places,
        opt.max_same and (", at most " .. opt.max_same .. " per element") or "")
    end
    picks[i] = c
    used_key[key(c)] = true
    per_el[c.element] = (per_el[c.element] or 0) + 1
  end
  return { picks = picks, theme = theme, fallbacks = fallbacks }
end

-- a formation placement's positionId as a card position class: 1 keeper, 2-3 defence, 4-7 midfield, else forward
-- (formation_config's positionId groups, the Battle Bay Draft's reading)
function C.placement_class(position_id)
  if position_id == 1 then
    return C.POS_GK
  elseif position_id == 2 or position_id == 3 then
    return C.POS_DF
  elseif position_id >= 4 and position_id <= 7 then
    return C.POS_MF
  end
  return C.POS_FW
end

return C
