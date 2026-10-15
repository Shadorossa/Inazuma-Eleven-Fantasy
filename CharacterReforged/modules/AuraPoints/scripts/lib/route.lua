-- Aura Points › who pays a special move fired with a warrior spirit out: the running spirit's pool (PEG / SP) or the
-- tension (docs/game/mechanics/aura-costs.md §12.3 / §18). Pure (no engine call): scripts\aura_points.lua (TensionPay
-- pre, the AuraCostCheck tables). Was Inazuma Fantasy's scripts\lib\stamina\route.lua until 2026-10-14.
--
-- Only the moves OF THE RUNNING SPIRIT pay its pool: the running aura's own move («change skill»), its pool keshin's
-- move and the moves of that keshin's armour forms (an armour runs on its keshin's pool). A player's normal slot moves,
-- a miximax's move, another keshin's move and an extra slot's moves pay as without a spirit (tension rules), unless
-- the CS option cs_keshin_moves_cost = "peg" asks every move fired with a keshin out to cost its tension in PEG.
--
--   local R = require "lib/route"
--   R.own_moves(A, ctx) -> { [move] = true }
--   R.route(A, P, ctx, ids, cost) -> kind, move   (kind: "spirit" / "armour_free" / "keshin_out_peg" / "tension")

local M = {}

-- The moves that belong to the running spirit: ctx = { key = pool aura (the keshin / totem), aura = the running aura
-- (keshin, armour or totem; nil = key), armour, soul }. A = lib/auras.
function M.own_moves(A, ctx)
  local set = {}
  if not ctx then return set end
  local function add(id)
    if not id or id == 0 then return end
    local m = A.aura_move(id)
    if m and m ~= 0 and A.is_spirit_move(m) and A.type(m) == nil then set[m] = true end
  end
  add(ctx.aura)
  add(ctx.key)
  if ctx.key and ctx.key ~= 0 and A.armours_of then
    for _, ar in ipairs(A.armours_of(ctx.key)) do add(ar) end
  end
  return set
end

-- Is `move` one of the running spirit's own moves?
function M.is_own_move(A, ctx, move)
  if not ctx or not move or move == 0 then return false end
  return M.own_moves(A, ctx)[move] == true
end

-- The pay route of a move (ids = the pending record's move ids in priority order, cost = the tension the engine is
-- about to pay). P = lib/cfg's settings. Without a running spirit (ctx nil) the caller's fusion-partner rule applies
-- and else the tension: "tension".
--   "spirit"         the running spirit's own move: its pool pays ctx.move_cost (no tension: peg_move_tension_free)
--   "armour_free"    that move under a CS armour (cs_armour_moves_free): no PEG, the armour's tension rule
--   "keshin_out_peg" CS keshin out, cs_keshin_moves_cost = "peg": the tension cost goes to the pool, 0 tension
--   "tension"        everything else: the tension rules, as without a spirit
function M.route(A, P, ctx, ids, cost)
  if not ctx then return "tension", nil end
  local own = M.own_moves(A, ctx)
  for _, id in ipairs(ids or {}) do
    if id and id ~= 0 and own[id] then
      if ctx.armour and not ctx.soul and P.armour_moves_free() then return "armour_free", id end
      return "spirit", id
    end
  end
  if not ctx.armour and not ctx.soul and P.keshin_moves_all_peg() and (cost or 0) > 0 then
    for _, id in ipairs(ids or {}) do
      if id and id ~= 0 then return "keshin_out_peg", id end
    end
    return "keshin_out_peg", 0
  end
  return "tension", nil
end

return M
