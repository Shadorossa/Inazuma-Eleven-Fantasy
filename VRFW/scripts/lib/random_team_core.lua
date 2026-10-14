-- VR-Framework › random team, the pure part (docs/framework/random-team.md): the seed of a draw and the pick of a
-- roster (the card filters are the framework's card sets, VRFW.chara.select). No game memory, no engine call (the
-- generator is the framework's VRFW.rng): plain Lua tables, so the same inputs always give the same team (the
-- determinism the service promises: same rule + seed + node + stage + pool = same roster, same name / emblem / kit).
--
-- Numbers are Lua 5.2 doubles; hashes and seeds are u32 (0 .. 2^32-1). Card positions are chara_param's
-- (1 keeper, 2 forward, 3 midfield, 4 defence); a formation placement is a class of the same numbers.

local C = {}

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

-- a seed argument (a game Lua number: up to 2^53, possibly negative) as two u32 halves
function C.split(v)
  if type(v) ~= "number" or v ~= v then
    return 0, 0
  end
  v = floor(v) % 9007199254740992
  return C.u32(floor(v / TWO32)), C.u32(v)
end

-- ------------------------------------------------------------------------------------------------ generator
-- The framework's one seeded generator (VRFW.rng: the daily generator, SplitMix64-seeded PCG32; review 2026-10-13
-- §3). `words` = the seed parts (numbers), `stream` = 1 roster / 2 look.
function C.rng(words, stream)
  local w = {}
  for i, x in ipairs(words) do w[i] = x end
  w[#w + 1] = stream
  return VRFW.rng("VRFW.random_team", w)
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
--   pool          the pool's cards (the framework's card set, VRFW.chara.select), in a fixed order
--   places        C.places(...)
--   unique        "character" (default: one card per chara_base) or "card"
--   rarity_w      { [rarity] = weight } (nil = every rarity weight 1; a rarity missing from the table = 0)
--   tier_col, tier  the column and its { lo, hi } a card must be in (nil = none)
--   element_w     { [element] = weight } (nil = 1 each)
--   max_same      most cards of one element (nil = no cap)
--   theme         { chance (0..1), weight (multiplier) }: with that chance one element is the team's theme
--   rng           C.rng(...) (a VRFW.rng generator)
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
  local roll = rng:float()
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
