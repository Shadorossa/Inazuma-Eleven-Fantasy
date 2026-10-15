-- Aura Points › the [points] settings of config.toml (docs/game/mechanics/aura-costs.md §12 / §14 / §18) as the run time
-- uses them. Was the PEG / SP half of Inazuma Fantasy's [aura_cost] (scripts\lib\stamina\cfg.lua) until 2026-10-14.

local M = {}

local function num(v, d)
  v = tonumber(v)
  if v == nil or v ~= v then return d end
  return v
end

local function pos_or(v, d)
  v = tonumber(v)
  if v ~= nil and v == v and v >= 0 and v < math.huge then return v end
  return d
end

local function bool(v, d)
  if v == nil then return d end
  return v == true
end

function M.points(t)
  t = t or {}
  local c = {
    peg_on = bool(t.peg, true),
    sp_on = bool(t.sp, true),
    cpu = bool(t.cpu, true),
    move_tension_free = bool(t.move_tension_free, true),
    cost_model = string.lower(tostring(t.cost_model or "cs")),
    armour_boost = num(t.armour_boost, 1.05),
    armour_drain_per_s_if = num(t.armour_drain_per_s, 1.0),
    cs_armour_drain_k = pos_or(t.cs_armour_drain_k, 0.025),
    cs_armour_gk_zone_mult = pos_or(t.cs_armour_gk_zone_mult, 0.5),
    default_atk = num(t.default_atk, 80),
    cs_armour_first_refill = num(t.cs_armour_first_refill, 0.30),
    cs_armour_moves_free_on = bool(t.cs_armour_moves_free, true),
    cs_keshin_moves_cost = string.lower(tostring(t.cs_keshin_moves_cost or "own")),
    cs_armour_keshin_move = bool(t.cs_armour_keshin_move, false),
  }
  c.cs_on = c.cost_model:match("^%s*cs%s*$") ~= nil
  local scale = pos_or(t.cs_scale == nil and 0.75 or t.cs_scale, 1.0)
  function c.peg() return c.peg_on end
  function c.sp() return c.sp_on end
  function c.any() return c.peg_on or c.sp_on end
  function c.cs() return c.cs_on end
  function c.cs_scale() return scale end
  function c.armour_moves_free() return c.cs() and c.cs_armour_moves_free_on end
  function c.armour_blocks_keshin_move() return c.cs() and not c.cs_armour_keshin_move end
  function c.keshin_moves_all_peg() return c.cs() and c.peg() and c.cs_keshin_moves_cost:match("^%s*peg%s*$") ~= nil end
  -- PEG per live second of an armour on keshin (kp its pool, atk); keeper_home = a keeper inside his own box
  function c.armour_drain_per_s(kp, atk, keeper_home)
    if not c.cs() then return math.max(c.armour_drain_per_s_if, 0) end
    local base = (math.max(kp, 0) + math.max(atk, 0)) * c.cs_armour_drain_k * c.cs_scale()
    if keeper_home then return base * c.cs_armour_gk_zone_mult end
    return base
  end
  -- does an aura of this auraType run on a pool (0 keshin, 1 armour: PEG; 3 totem: SP)
  function c.pool_type(ty)
    if ty == 0 or ty == 1 then return c.peg() end
    if ty == 3 then return c.sp() end
    return false
  end
  return c
end

return M
