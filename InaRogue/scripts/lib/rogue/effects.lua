-- InaRogue › INAROGUE: the run effects shared by the coaches (content/rogue/coaches.toml), the rogue items
-- (content/rogue/items.toml) and the archetype ranks (content/rogue/archetypes.toml): one parser and one set of
-- aggregators; callers differ only by their effect lists. The generic pieces (stat_multiplier, stat_bonus,
-- tension_cost_multiplier, technique_cooldown_multiplier, wall_reduction_multiplier, pass_speed_multiplier,
-- technique_grade_override, technique_power_multiplier, technique_free_until_broken, shop_cost_multiplier) are declared
-- in lib/rogue/pieces.lua, the grants and the blocks (conditions, counters, triggers, chance) in lib/rogue/blocks.lua;
-- the economy kinds below: node_weight (map content weights), reward_mult (fragments / Rogue
-- points), start_points, start_item; technique_cost and match_rule are declared kinds without an engine hook yet.
-- A value may scale with the level (E.at_level): a number, a list (one value per level) or { base, max }.

local U = require "lib/rogue/util"
local P = require "lib/rogue/pieces"
local B = require "lib/rogue/blocks"

local E = {}

E.STATS = P.STATS

local CONTENT = { cofre = 1, chest = 1, tienda = 2, shop = 2, evento = 3, event = 3, fichaje = 4, recruit = 4, gacha = 5,
  elite = 6, ["élite"] = 6, tragaperras = 7, slots = 7 }

local function num(t, k)
  local v = t[k]
  if type(v) == "number" then return v end
  return nil
end

-- one effect table -> its effect, or nil + why
function E.parse_effect(t)
  local kind = t.kind
  if type(kind) ~= "string" then return nil, "effect without `kind`" end
  local function value(k)
    local v = num(t, k)
    if not v or v ~= v or v < 0 or v == math.huge then return nil, kind .. ": `" .. k .. "` must be a number >= 0" end
    return v
  end
  if P.get(kind) or B.GRANTS[kind] then
    local e, why
    if B.GRANTS[kind] then e, why = B.parse_grant(t) else e, why = P.parse(t) end
    if not e then return nil, why end
    local ok, why2 = B.attach(e, t, e.kind)
    if not ok then return nil, why2 end
    return e
  end
  if kind == "node_weight" then
    local node = tostring(t.node or "")
    local c = CONTENT[U.lower(node)]
    if not c then return nil, "node_weight: node `" .. node .. "` (cofre / tienda / evento / fichaje / gacha / elite / tragaperras)" end
    local v, why = value("mult")
    if not v then return nil, why end
    return { kind = "node_weight", content = c, mult = v }
  elseif kind == "reward_mult" then
    local r = t.reward or "all"
    if r ~= "frags" and r ~= "points" and r ~= "coins" and r ~= "all" then
      return nil, "reward_mult: reward `" .. tostring(r) .. "` (frags / points / coins / all)"
    end
    local v, why = value("value")
    if not v then return nil, why end
    return { kind = "reward_mult", reward = r, value = v }
  elseif kind == "start_points" then
    local v = num(t, "value")
    if not v or v < 0 then return nil, "start_points: `value` (integer)" end
    return { kind = "start_points", value = U.int(v, 0) }
  elseif kind == "start_item" then
    local item = type(t.item) == "string" and t.item or ""
    local id = num(t, "id") or 0
    if item == "" and id == 0 then return nil, "start_item: `item` (registry key) or `id`" end
    return { kind = "start_item", item = item, id = id, count = math.max(U.int(t.count, 1), 1) }
  elseif kind == "technique_cost" then
    local v, why = value("mult")
    if not v then return nil, why end
    return { kind = "technique_cost", mult = v, pending = true }
  elseif kind == "match_rule" then
    return { kind = "match_rule", rule = tostring(t.rule or ""), pending = true }
  end
  return { kind = kind, unknown = true }
end

-- the value of `v` at `level` (1-based) of `max_level`: a list gives its level's entry (the last one past the end),
-- { base, max } the linear value between level 1 and max_level, anything else itself
function E.level_value(v, level, max_level)
  level = math.max(level or 1, 1)
  if type(v) ~= "table" then return v end
  if #v > 0 and type(v[1]) == "number" then return v[math.min(level, #v)] end
  if type(v.base) == "number" and type(v.max) == "number" then
    local top = math.max(max_level or 1, 1)
    if top <= 1 then return v.base end
    local f = (math.min(level, top) - 1) / (top - 1)
    return v.base + (v.max - v.base) * f
  end
  return v
end

-- keys whose lists are data, never one value per level (move ids, team ids, the blocks)
local NOT_LEVELLED = { moves = true, tags = true, element = true, position = true, category = true, team = true,
  set = true, players = true, performers = true, when = true, count = true, on = true, chance = true, reset_on = true }

-- an effect table with every level-scaled value replaced by its value at `level` of `max_level`
function E.at_level(t, level, max_level)
  local o = {}
  for k, v in pairs(t) do
    if NOT_LEVELLED[k] then o[k] = v else o[k] = E.level_value(v, level, max_level) end
  end
  return o
end

-- a list of effect tables at `level` of `max_level` -> parsed effects, warnings
function E.parse_list(list, level, where, max_level)
  local out, warns = {}, {}
  for k, t in ipairs(type(list) == "table" and list or {}) do
    local x, why = E.parse_effect(E.at_level(type(t) == "table" and t or {}, level, max_level))
    if not x then
      warns[#warns + 1] = string.format("%s effect %d: %s (ignored)", where, k, why)
    else
      if x.unknown then warns[#warns + 1] = string.format("%s effect %d: unknown kind `%s` (ignored)", where, k, x.kind) end
      x.index = k
      out[#out + 1] = x
    end
  end
  return out, warns
end

-- several effect lists as one (a coach's and the items')
function E.concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, e in ipairs(list or {}) do out[#out + 1] = e end
  end
  return out
end

-- does a stat effect reach a player of `position` / `element`?
local function reaches(e, position, element)
  return e.target.kind == "team" or (e.target.kind == "position" and e.target.v == position)
    or (e.target.kind == "element" and e.target.v == element)
end

-- an effect that applies at kick-off: no pending part, no live block (match state, match counter, timer), its
-- conditions hold in `ctx` (an effect with blocks needs a ctx); its value with the ctx's stacks
local function kick_off_value(e, ctx, base)
  if e.pending or e.live then return nil end
  if (e.when or e.count) and not ctx then return nil end
  if e.when and not B.conditions_hold(e, ctx) then return nil end
  if e.count then
    local stacks = ctx.stacks and ctx.stacks(e) or 0
    local v = B.stacked_value(e, base, stacks, nil)
    return v
  end
  return base
end
E.kick_off_value = kick_off_value

-- multipliers of the 7 engine stats (+ [8] = 1.0) for a player of `position` / `element`; ctx (optional) = the
-- blocks' context of that player (lib/rogue/svc_blocks.lua player_ctx)
function E.stat_mults(effects, position, element, ctx)
  local m = { 1, 1, 1, 1, 1, 1, 1, 1 }
  for _, e in ipairs(effects) do
    if e.kind == "stat_multiplier" and reaches(e, position, element) then
      local v = kick_off_value(e, ctx, e.value)
      if v then
        if e.stat then
          m[e.stat] = m[e.stat] * v
        else
          for i = 1, 7 do m[i] = m[i] * v end
        end
      end
    end
  end
  return m
end

-- flat additions to the 7 engine stats (+ [8] = 0) for that player (stat_bonus)
function E.stat_adds(effects, position, element, ctx)
  local a = { 0, 0, 0, 0, 0, 0, 0, 0 }
  for _, e in ipairs(effects) do
    if e.kind == "stat_bonus" and reaches(e, position, element) then
      local v = kick_off_value(e, ctx, e.value)
      if v then
        if e.stat then
          a[e.stat] = a[e.stat] + v
        else
          for i = 1, 7 do a[i] = a[i] + v end
        end
      end
    end
  end
  return a
end

function E.has_stat_mults(effects)
  for _, e in ipairs(effects) do
    if (e.kind == "stat_multiplier" or e.kind == "stat_bonus") and not e.pending and not e.live then return true end
  end
  return false
end

-- the Shop's price multiplier (shop_cost_multiplier; ctx = the run's blocks context for conditions / counters)
function E.shop_cost_mult(effects, ctx)
  local p = 1.0
  for _, e in ipairs(effects) do
    if e.kind == "shop_cost_multiplier" then
      local v = kick_off_value(e, ctx, e.value)
      if v then p = p * v end
    end
  end
  return p
end

-- weight multiplier per map content type (1..7); nil = the coach changes no weight
function E.content_mults(effects)
  local m, any = {}, false
  for i = 1, 7 do m[i] = 1.0 end
  for _, e in ipairs(effects) do
    if e.kind == "node_weight" and m[e.content] then
      m[e.content] = m[e.content] * e.mult
      any = true
    end
  end
  if any then return m end
  return nil
end

function E.reward_mult(effects, r)
  local p = 1.0
  for _, e in ipairs(effects) do
    if e.kind == "reward_mult" and (e.reward == r or e.reward == "all") then p = p * e.value end
  end
  return p
end

function E.start_points(effects)
  local n = 0
  for _, e in ipairs(effects) do
    if e.kind == "start_points" then n = n + e.value end
  end
  return n
end

function E.start_items(effects)
  local o = {}
  for _, e in ipairs(effects) do
    if e.kind == "start_item" then o[#o + 1] = { e.item, e.id, e.count } end
  end
  return o
end

-- n x mult, rounded (1.0 = unchanged exactly)
function E.scaled(n, mult)
  if math.abs(mult - 1.0) < 1e-7 then return n end
  return U.round(n * math.max(mult, 0))
end

return E
