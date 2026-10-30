-- InaRogue › INAROGUE: the rules of a v2 run (docs/game/mods/inarogue-loop-v2.md §4.1): config.toml [rogue.run]
-- with its defaults, the settings a run plays under (stage board, rival levels, Ascension and challenge modifiers),
-- the run currency and the texts the commands build. Pure: no engine call; the run file fields live in run.lua.

local U = require "lib/rogue/util"
local info, warn = U.logger("rogue rules")

local Rules = {}

-- the board rule of a new v2 run (run.board_rule): 4 = the 10-stage layout of [rogue.run]; 3 = a run started under
-- the first 3-stage layout ([rogue.run.layout_3]), which it keeps until it ends. Both are v2 runs (V2_RULE and up).
Rules.BOARD_RULE, Rules.V2_RULE, Rules.LAYOUT_3 = 4, 3, 3

-- a layout: the stages and their board, rival levels and bosses (the keys a run keeps for its whole life)
local LAYOUT_DEFAULTS = {
  stages = 10,
  map_curve = { { 1, 5, 3 }, { 3, 6, 3 }, { 5, 7, 3 }, { 7, 7, 4 }, { 9, 8, 4 }, { 11, 8, 4 }, { 16, 9, 4 }, { 25, 10, 5 } },
  map_content = { { 1, 1, 18 }, { 2, 1, 16 }, { 3, 1, 20 }, { 4, 1, 10 }, { 5, 3, 8 }, { 6, 2, 14 }, { 7, 4, 8 } },
  content_nodes = { 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5 },
  content_lines = { 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3 },
  rival_levels = { { 1, 6 }, { 2, 13 }, { 3, 20 }, { 4, 27 }, { 5, 35 }, { 6, 43 }, { 7, 51 }, { 8, 60 }, { 9, 69 },
    { 10, 78 }, { 11, 87 }, { 20, 130 }, { 50, 250 }, { 100, 999 } },
  elite_bonus = 3,
  boss_bonus = 4,
  final_boss_bonus = 6,
  big_boss_every = 5,
  big_boss_levels = 3,
  big_boss_coin_mult = 2.0,
  -- endless: the rivals' stats × this (keyframes [phase, multiplier], linear), on top of their level (which stops where
  -- the engine stops: content\growth LevelCap and the rows' ladders)
  endless_scaling = { { 10, 1.0 }, { 15, 1.15 }, { 20, 1.35 }, { 30, 1.8 }, { 50, 3.0 }, { 100, 6.0 } },
  -- a match whose level is above what the game plays (no [VRFW.Level] raise): each missing level = this stat share
  over_cap_stat_per_level = 0.01,
}
-- the first v2 layout (InaRogue 1.25.0-1.34.0): 3 stages
local LAYOUT_3_DEFAULTS = {
  stages = 3,
  map_curve = { { 1, 7, 3 }, { 2, 8, 3 }, { 3, 9, 4 }, { 4, 9, 4 }, { 8, 10, 4 }, { 12, 11, 5 } },
  map_content = { { 1, 1, 18 }, { 2, 1, 16 }, { 3, 1, 20 }, { 4, 1, 10 }, { 5, 2, 8 }, { 6, 1, 14 }, { 7, 2, 8 } },
  content_nodes = { 3, 4, 4, 5 },
  content_lines = { 2, 2, 3, 3 },
  rival_levels = { { 1, 6 }, { 2, 14 }, { 3, 24 }, { 4, 32 }, { 10, 60 }, { 25, 99 } },
  elite_bonus = 3,
  boss_bonus = 4,
  final_boss_bonus = 6,
  big_boss_every = 0,
  big_boss_levels = 0,
  big_boss_coin_mult = 1.0,
  endless_scaling = { { 1, 1.0 } },
  over_cap_stat_per_level = 0.0,
}

local DEFAULTS = {
  endless = true,
  start_coins = 15,
  coins_win = { 8, 12, 20, 30, 20, 25 },
  coins_per_stage = 2,
  recruit_offers = 3,
  recruit_after = { "small", "full", "elite", "boss", "epic", "gate" },
  recruit_cost = { 15, 25, 40, 60, 90 },
  shop_players = 2,
  shop_items = 2,
  item_price_scale = 1.0,
  slot_bet = 10,
  slot_odds = { 50, 35, 12, 3 },
  item_weights = {
    chest = { 60, 30, 9, 1 }, elite = { 30, 45, 20, 5 }, boss = { 0, 20, 50, 30 }, shop = { 50, 30, 15, 5 },
    event = { 55, 30, 12, 3 },
  },
  item_offers = 3,
  rogue_points_won = 30,
  rogue_points_per_ascension = 10,
  weekly_challenges = 2,
  budget_per_win = 2,
  talent_price = { 25, 40, 60 },
  talent_weights = { shop = { 60, 30, 10 }, elite = { 30, 50, 20 }, event = { 60, 30, 10 } },
  shop_talents = 1,
  elite_talents = 1,
}

local function list_of_lists(v, width)
  if type(v) ~= "table" or #v == 0 then return nil end
  local o = {}
  for _, r in ipairs(v) do
    if type(r) ~= "table" or (width and #r ~= width) then return nil end
    o[#o + 1] = U.nums(r)
  end
  return o
end

local function nums(v, d)
  if type(v) ~= "table" or #v == 0 then return d end
  local o = U.nums(v)
  if #o ~= #v then return d end
  return o
end

local function strs(v, d)
  if type(v) ~= "table" then return d end
  local o = {}
  for _, x in ipairs(v) do o[#o + 1] = tostring(x) end
  return o
end

require "VRFW/lib/basics"
local num = VRFW.value.num

-- a layout table of the config (`t`) over its defaults (`D`)
local function parse_layout(t, D)
  t = type(t) == "table" and t or {}
  return {
    stages = U.clamp(U.int(t.stages, D.stages), 1, 99),
    map_curve = list_of_lists(t.map_curve, 3) or D.map_curve,
    map_content = list_of_lists(t.map_content, 3) or D.map_content,
    content_nodes = nums(t.content_nodes, D.content_nodes),
    content_lines = nums(t.content_lines, D.content_lines),
    rival_levels = list_of_lists(t.rival_levels, 2) or D.rival_levels,
    elite_bonus = U.int(t.elite_bonus, D.elite_bonus),
    boss_bonus = U.int(t.boss_bonus, D.boss_bonus),
    final_boss_bonus = U.int(t.final_boss_bonus, D.final_boss_bonus),
    big_boss_every = math.max(U.int(t.big_boss_every, D.big_boss_every), 0),
    big_boss_levels = U.int(t.big_boss_levels, D.big_boss_levels),
    big_boss_coin_mult = math.max(num(t.big_boss_coin_mult, D.big_boss_coin_mult), 0),
    endless_scaling = list_of_lists(t.endless_scaling, 2) or D.endless_scaling,
    over_cap_stat_per_level = math.max(num(t.over_cap_stat_per_level, D.over_cap_stat_per_level), 0),
  }
end

local cache = nil

-- the [rogue.run] settings (read once)
function Rules.get()
  if cache then return cache end
  local t = U.cfg("rogue.run", {})
  if type(t) ~= "table" then t = {} end
  local D = DEFAULTS
  local layout = parse_layout(t, LAYOUT_DEFAULTS)
  local c = {
    layout = layout,
    layout_3 = parse_layout(t.layout_3, LAYOUT_3_DEFAULTS),
    stages = layout.stages,
    endless = (t.endless == nil) and D.endless or (t.endless == true),
    start_coins = math.max(U.int(t.start_coins, D.start_coins), 0),
    coins_win = nums(t.coins_win, D.coins_win),
    coins_per_stage = math.max(U.int(t.coins_per_stage, D.coins_per_stage), 0),
    recruit_offers = U.clamp(U.int(t.recruit_offers, D.recruit_offers), 0, 5),
    recruit_after = strs(t.recruit_after, D.recruit_after),
    recruit_cost = nums(t.recruit_cost, D.recruit_cost),
    shop_players = U.clamp(U.int(t.shop_players, D.shop_players), 0, 5),
    shop_items = U.clamp(U.int(t.shop_items, D.shop_items), 0, 5),
    item_price_scale = math.max(num(t.item_price_scale, D.item_price_scale), 0),
    slot_bet = math.max(U.int(t.slot_bet, D.slot_bet), 1),
    slot_odds = nums(t.slot_odds, D.slot_odds),
    item_offers = U.clamp(U.int(t.item_offers, D.item_offers), 1, 5),
    rogue_points_won = math.max(U.int(t.rogue_points_won, D.rogue_points_won), 0),
    rogue_points_per_ascension = math.max(U.int(t.rogue_points_per_ascension, D.rogue_points_per_ascension), 0),
    item_weights = {},
    weekly_challenges = U.clamp(U.int(t.weekly_challenges, D.weekly_challenges), 0, 5),
    budget_per_win = math.max(U.int(t.budget_per_win, D.budget_per_win), 0),
    talent_price = nums(t.talent_price, D.talent_price),
    talent_weights = {},
    shop_talents = U.clamp(U.int(t.shop_talents, D.shop_talents), 0, 3),
    elite_talents = U.clamp(U.int(t.elite_talents, D.elite_talents), 0, 3),
  }
  local iw = type(t.item_weights) == "table" and t.item_weights or {}
  for src, w in pairs(D.item_weights) do
    local v = nums(iw[src], w)
    c.item_weights[src] = #v == 4 and v or w
  end
  local tw = type(t.talent_weights) == "table" and t.talent_weights or {}
  for src, w in pairs(D.talent_weights) do
    local v = nums(tw[src], w)
    c.talent_weights[src] = #v == 3 and v or w
  end
  if #c.slot_odds ~= 4 then c.slot_odds = D.slot_odds end
  if #c.coins_win ~= 6 then c.coins_win = D.coins_win end
  cache = c
  info(string.format("v2 runs: %d stages (endless %s), start coins %d, %d recruit offers", c.stages, tostring(c.endless),
    c.start_coins, c.recruit_offers))
  return c
end

-- the layout run `r` plays (its board rule's; a run keeps its layout until it ends)
function Rules.layout(r)
  local c = Rules.get()
  if r and (r.board_rule or 0) == Rules.LAYOUT_3 then return c.layout_3 end
  return c.layout
end

-- true when the boss of run `r`'s current phase is a «big boss» (every big_boss_every phases: a stronger boss, more
-- coins, the boss relic weights, more spirits for a duplicate)
function Rules.big_boss(r)
  local L = Rules.layout(r)
  return r ~= nil and L.big_boss_every > 0 and r.phase % L.big_boss_every == 0
end

-- the rivals' stat multiplier of run `r`'s current phase: 1 until the run is won, then the layout's endless_scaling
-- curve (linear between keyframes, the last one past the end)
function Rules.rival_scale(r)
  if not r or not r.endless then return 1.0 end
  local curve = Rules.layout(r).endless_scaling
  local p = r.phase or 1
  local prev = nil
  for _, k in ipairs(curve) do
    if k[1] >= p then
      if prev and k[1] > prev[1] then return prev[2] + (k[2] - prev[2]) * (p - prev[1]) / (k[1] - prev[1]) end
      return k[2]
    end
    prev = k
  end
  return prev and prev[2] or 1.0
end

-- the value of a per-stage list (the last value repeats)
function Rules.per_stage(list, stage)
  if type(list) ~= "table" or #list == 0 then return 0 end
  return list[U.clamp(math.max(stage, 1), 1, #list)]
end

-- ---------------------------------------------------------------------------------------- modifiers

-- the summed modifiers of the run's Ascension and challenges (lib/rogue/ascension.lua fills them; none = zeros)
local modifier_source = nil
function Rules.set_modifier_source(f) modifier_source = f end

function Rules.modifiers(r)
  local m = { rival_levels = 0, boss_levels = 0, elite_weight = 0, coins_mult = 1.0, price_mult = 1.0,
    recruit_offers = 0, start_coins = 0, no_shop = false, no_recruit = false, no_items = false }
  if modifier_source and r then
    local ok, e = pcall(modifier_source, r, m)
    if not ok then warn("modifiers: " .. tostring(e)) end
  end
  return m
end

-- ---------------------------------------------------------------------------------------- the settings of a run

-- `base` (the [rogue] settings) as run `r` plays them: a v2 run takes the stage board, its content and caps, the
-- stage rival levels and the modifiers; an older run gets `base` as it is
function Rules.run_cfg(base, r)
  if not r or (r.board_rule or 0) < Rules.V2_RULE then return base end
  local c = Rules.layout(r)
  local m = Rules.modifiers(r)
  local o = setmetatable({}, { __index = base })
  o.map_curve = c.map_curve
  local content = {}
  for i, row in ipairs(c.map_content) do
    content[i] = { row[1], row[2], row[3] }
    if row[1] == 6 then content[i][3] = U.clamp(row[3] + m.elite_weight, 0, 100) end
    if row[1] == 2 and m.no_shop then content[i][3] = 0 end
  end
  o.map_content = content
  o.content_rule = 3   -- the capped content of the v2 boards (lib/rogue/map.lua)
  o.content_nodes = c.content_nodes
  o.content_lines = c.content_lines
  local curve = {}
  for i, row in ipairs(c.rival_levels) do curve[i] = { row[1], row[2] + m.rival_levels } end
  o.level_curve = curve
  o.elite_bonus = c.elite_bonus
  local boss = c.boss_bonus + m.boss_levels
  if r.phase >= (r.stages or c.stages) and not r.endless then boss = boss + c.final_boss_bonus end
  if Rules.big_boss(r) then boss = boss + c.big_boss_levels end
  o.boss_bonus = boss
  return o
end

-- true when run `r` is a v2 run
function Rules.is_v2(r) return r ~= nil and (r.board_rule or 0) >= Rules.V2_RULE end

-- true when the boss of run `r`'s current phase is the final boss
function Rules.final_stage(r)
  return Rules.is_v2(r) and not r.endless and r.phase >= (r.stages or Rules.layout(r).stages)
end

-- ---------------------------------------------------------------------------------------- coins

local KIND_INDEX = { [1] = 1, [2] = 2, [7] = 3, [3] = 4, [8] = 5, [9] = 6 } -- small, full, elite, boss, epic, gate

-- coins a won node of `kind` pays in `stage` (× the modifiers)
function Rules.coins_for_win(r, kind)
  local c = Rules.get()
  local i = KIND_INDEX[kind]
  if not i then return 0 end
  local n = (c.coins_win[i] or 0) + c.coins_per_stage * (math.max(r.phase, 1) - 1)
  if kind == 3 and Rules.big_boss(r) then n = n * Rules.layout(r).big_boss_coin_mult end
  return math.max(U.round(n * Rules.modifiers(r).coins_mult * Rules.relic_coin_mult(r)), 0)
end

-- the coin multiplier of the run's relics (reward_mult reward = "coins")
function Rules.relic_coin_mult(r)
  local Items = require "lib/rogue/items"
  local E = require "lib/rogue/effects"
  return E.reward_mult(Items.effects(r.items, "outside"), "coins")
end

-- the starter budget points every won run adds (PokeRogue: more starter points as the player progresses; the [rogue]
-- budget_max still caps the total)
function Rules.budget_bonus()
  local ok, s = pcall(function() return require("lib/rogue/meta_store").get() end)
  if not ok or type(s) ~= "table" then return 0 end
  return Rules.get().budget_per_win * (s.runs_won or 0)
end

-- a price × the run's price modifier
-- (× its relics' shop_cost_multiplier)
function Rules.price(r, n)
  local shop = require("lib/rogue/svc_blocks").shop_mult(r)
  return math.max(U.round(n * Rules.modifiers(r).price_mult * shop), 0)
end

-- ---------------------------------------------------------------------------------------- texts

-- a text row in the game's language with {1}.. replaced (the row id itself when the row is missing)
function Rules.text(key, ...)
  local ok, s = pcall(VRFW.text, key)
  if not ok or type(s) ~= "string" or s == "" then s = key end
  local v = table.pack(...)
  return (s:gsub("{(%d)}", function(k)
    local x = v[tonumber(k)]
    return x == nil and "" or tostring(x)
  end))
end

return Rules
