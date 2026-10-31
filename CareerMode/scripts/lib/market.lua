-- Career mode transfer market (docs/game/mods/career-mode-proposal.md §15): money, player values, the player's buys
-- and sales, the AI clubs' deals and bids. Every number is config.toml [market]. A player's value comes from his
-- career level (env.value_of: config [levels.value], his level, the room to his potential, form, recent rise and
-- position); the price his club asks = the value x his role in the club x the club's stature x its need at his
-- position x the career's negotiation option. Values are worked out per card when first needed and kept for the
-- career's day (a round, a month's levels change them). Kept in the career (c.market). The caller
-- (scripts\career.lua) hands the career helpers in `env`.
local M = {}

local floor = math.floor

require "VRFW/lib/basics"
local info = VRFW.logger("market")

local POSITIONS = { 1, 2, 3, 4 }   -- main positions: 1 GK, 2 FW, 3 MF, 4 DF

-- a piecewise-linear curve { { x, y } … } at x
local function curve(points, x)
  if type(points) ~= "table" or #points == 0 then return 1 end
  if x <= points[1][1] then return points[1][2] end
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if x <= b[1] then
      local t = (b[1] == a[1]) and 1 or (x - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t
    end
  end
  return points[#points][2]
end

local function points_of(v, default)
  local out = {}
  for _, p in ipairs(type(v) == "table" and v or {}) do
    if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) then out[#out + 1] = { tonumber(p[1]), tonumber(p[2]) } end
  end
  return #out > 0 and out or default
end

-- config [market] with its defaults; c = the career: its options (config [setup] presets picked at the start, env.options)
-- set the player's prices and bids, the AI's activity and the backing added to the club's first budget
function M.config(env, c)
  local num, int = env.num, env.int
  local need = env.config("market.need_by_position", nil)
  local need_by = { [1] = 2, [2] = 4, [3] = 5, [4] = 5 }
  if type(need) == "table" then
    for i, pos in ipairs(POSITIONS) do need_by[pos] = tonumber(need[i]) or need_by[pos] end
  end
  local cfg = {
    unit = num("market.unit", 1000000),
    value_curve = points_of(env.config("market.value_curve", nil), { { 0, 0.1 }, { 0.5, 0.4 }, { 0.9, 1.2 }, { 1, 2.5 } }),
    budget_curve = points_of(env.config("market.start_budget_by_rank", nil), { { 0, 3 }, { 0.5, 1.5 }, { 1, 0.6 } }),
    ask_star = num("market.ask_star", 1.6),
    ask_starter = num("market.ask_starter", 1.35),
    ask_reserve = num("market.ask_reserve", 1.0),
    star_count = int("market.star_count", 3),
    starters = int("market.starters", 11),
    stature_curve = points_of(env.config("market.stature_by_rank", nil), { { 0, 1.2 }, { 0.5, 1 }, { 1, 0.85 } }),
    need_ask = num("market.need_ask", 1.25),
    free_fee = num("market.free_agent_fee", 0.25),
    price_round = points_of(env.config("market.price_round", nil), { { 0, 1000 } }),
    price_batch = int("market.price_batch", 1200),
    work_ms = num("market.work_ms", 8),
    max_squad = int("squads.max_players", 21),
    income_per_round = num("market.income_per_round", 0.05),
    ai_deals_per_round = int("market.ai_deals_per_round", 6),
    ai_spend_share = num("market.ai_spend_share", 0.5),
    ai_sample = int("market.ai_sample", 40),
    bid_chance = num("market.bid_chance", 0.35),
    bid_range = points_of(env.config("market.bid_range", nil), { { 0, 0.85 }, { 1, 1.15 } }),
    -- the bids for the player's men on no list, and the loans (config [market] unlisted_* / loan_*)
    unlisted_bid_chance = num("market.unlisted_bid_chance", 0.04),
    unlisted_bid_range = points_of(env.config("market.unlisted_bid_range", nil), { { 0, 1.1 }, { 1, 1.4 } }),
    loan_offer_chance = num("market.loan_offer_chance", 0.35),
    loan_fee_range = points_of(env.config("market.loan_fee_range", nil), { { 0, 0.05 }, { 1, 0.15 } }),
    loan_lengths = {},
    need_by = need_by,
    log_size = int("market.log_size", 30),
    -- the transfer talks (config [market] talk_*)
    talk_patience = num("market.talk_patience", 1.0),
    talk_patience_cost = points_of(env.config("market.talk_patience_cost", nil),
      { { 0, 0.06 }, { 0.1, 0.15 }, { 0.25, 0.35 }, { 0.5, 0.65 }, { 1, 1.3 } }),
    talk_demand_noise = num("market.talk_demand_noise", 0.15),
    talk_accept_patience = num("market.talk_accept_patience", 0.35),
    talk_low_share = num("market.talk_low_share", 0.8),
    talk_give = num("market.talk_give", 0.4),
    talk_accept_gap = num("market.talk_accept_gap", 0.04),
    talk_floor = { star = num("market.talk_floor_star", 0.95), starter = num("market.talk_floor_starter", 0.85),
      reserve = num("market.talk_floor_reserve", 0.75) },
    talk_poor_units = num("market.talk_poor_units", 1.0),
    talk_poor_floor = num("market.talk_poor_floor", 0.9),
    talk_first_offer = num("market.talk_first_offer", 0.85),
    talk_step_share = num("market.talk_step_share", 0.02),
    talk_big_steps = int("market.talk_big_steps", 10),
    talk_bid_max = num("market.talk_bid_max", 1.2),
    talk_reply_days = { 1, 3 },
    talk_sell_give = points_of(env.config("market.talk_sell_give", nil), { { 0, 0.6 }, { 0.5, 0.45 }, { 1, 0.25 } }),
    talk_sell_jitter = num("market.talk_sell_jitter", 0.15),
  }
  local days = env.config("market.talk_reply_days", nil)
  if type(days) == "table" and tonumber(days[1]) and tonumber(days[2]) then
    cfg.talk_reply_days = { math.max(1, floor(tonumber(days[1]))), math.max(1, floor(tonumber(days[2]))) }
    if cfg.talk_reply_days[2] < cfg.talk_reply_days[1] then cfg.talk_reply_days[2] = cfg.talk_reply_days[1] end
  end
  local lengths = env.config("market.loan_lengths", nil)
  for _, v in ipairs(type(lengths) == "table" and lengths or {}) do
    if v == "window" or v == "season" then cfg.loan_lengths[#cfg.loan_lengths + 1] = v end
  end
  if #cfg.loan_lengths == 0 then cfg.loan_lengths = { "window", "season" } end
  local o = c ~= nil and env.options ~= nil and env.options(c) or nil
  cfg.player_ask, cfg.player_bid, cfg.backing = 1, 1, 0
  if o then
    local neg, act = o.negotiation or {}, o.activity or {}
    cfg.player_ask = tonumber(neg.ask) or 1
    cfg.player_bid = tonumber(neg.bid) or 1
    local more = (tonumber(neg.bid_chance) or 1) * (tonumber(act.bid_chance) or 1)
    cfg.bid_chance = cfg.bid_chance * more
    cfg.unlisted_bid_chance = cfg.unlisted_bid_chance * more
    cfg.loan_offer_chance = cfg.loan_offer_chance * more
    cfg.ai_deals_per_round = tonumber(act.deals) and floor(tonumber(act.deals)) or cfg.ai_deals_per_round
    cfg.backing = tonumber(o.backing) or 0
  end
  return cfg
end

-- a call's time budget (config [market] work_ms): a function -> true while time is left; the clock is read every
-- CLOCK_EVERY calls, and once the time is up it stays up
local CLOCK_EVERY = 16
local function time_left(env, ms)
  if env.now_ms == nil then return function() return true end end
  local stop, n, over = env.now_ms() + ms, 0, false
  return function()
    if over then return false end
    n = n + 1
    if n % CLOCK_EVERY == 0 and env.now_ms() >= stop then over = true end
    return not over
  end
end
M.time_left = time_left

-- the career's market data, made once: money of every club (by its rank among the clubs by rating), the players
-- listed for sale (listed) and for loan (loan_listed), the blocked ones, the offers received, the loans running
-- ({ card, from, to, back, length, fee, day }), the deals done
function M.state(env, c, cfg)
  if type(c.market) == "table" and type(c.market.money) == "table" then
    local m = c.market
    m.loan_listed, m.blocked, m.loans = m.loan_listed or {}, m.blocked or {}, m.loans or {}
    return m
  end
  local ratings = {}
  for i, t in ipairs(c.clubs) do ratings[#ratings + 1] = { t = t, r = tonumber(c.ratings[i]) or 0 } end
  table.sort(ratings, function(a, b) return a.r > b.r end)
  local money = {}
  for k, x in ipairs(ratings) do
    local rank = #ratings > 1 and (k - 1) / (#ratings - 1) or 0
    money[tostring(x.t)] = floor(cfg.unit * curve(cfg.budget_curve, rank))
  end
  -- the career's financial backing, on top of the club's first budget
  local mine = tostring(c.team)
  if money[mine] ~= nil and (cfg.backing or 0) > 0 then money[mine] = money[mine] + floor(cfg.backing) end
  c.market = { money = money, listed = {}, loan_listed = {}, blocked = {}, offers = {}, loans = {}, log = {}, rev = 0 }
  info(string.format("market opened: %d clubs' budgets", #ratings))
  return c.market
end

local function key(t) return tostring(t) end

function M.money(m, club) return m.money[key(club)] or 0 end

-- the cards out on loan: card -> its loan
local function on_loan(m)
  local out = {}
  for _, l in ipairs(m.loans or {}) do out[l.card] = l end
  return out
end

-- the club's players out on loan
local function loans_out(m, club)
  local n = 0
  for _, l in ipairs(m.loans or {}) do
    if l.from == club then n = n + 1 end
  end
  return n
end

-- a player's status in his club: "transfer" (listed for sale), "loan" (listed for loan), "blocked" or "none"
function M.status_of(m, card)
  local k = key(card)
  if m.blocked and m.blocked[k] then return "blocked" end
  if m.listed[k] then return "transfer" end
  if m.loan_listed and m.loan_listed[k] then return "loan" end
  return "none"
end

-- an amount rounded the way prices are shown (config price_round: { from, step } rows, the last row at or under it)
local function nice(cfg, n)
  n = math.max(0, n)
  local step = 1000
  for _, r in ipairs(cfg.price_round) do
    if n >= r[1] then step = r[2] end
  end
  return floor(n / step + 0.5) * step
end

-- the players' values of one day of the career: card -> { level, effective, value }; a new day, season or month of
-- levels starts them again
local VALUES = { stamp = nil, info = {} }
local function values_for(env, c)
  local stamp = string.format("%s:%s:%s:%s", tostring(c.seed), tostring(c.season), tostring(env.today_of(c)),
    tostring(type(c.levels) == "table" and c.levels.months or 0))
  if VALUES.stamp ~= stamp then VALUES = { stamp = stamp, info = {} } end
  return VALUES
end

-- a card's value info, worked out when first needed (a career without levels: the strength share of the card)
local function info_of(env, c, cfg, x)
  local hit = VALUES.info[x.card]
  if hit then return hit end
  local p = env.level_of and env.level_of(c, x.card) or nil
  if p then
    hit = { level = p.level, effective = p.effective, potential = p.potential, form = p.form, trend = p.trend,
      value = cfg.unit * (env.value_of(c, x.card, p) or 0) }
  else
    hit = { level = 0, effective = x.strength or 0, potential = 0, form = 0, trend = 0,
      value = cfg.unit * curve(cfg.value_curve, x.share or 0.5) }
  end
  VALUES.info[x.card] = hit
  return hit
end

-- the player's role in his club: "star" (its best star_count by level + form), "starter" (its best `starters`),
-- "reserve"; "free" without a club. Ranked per club when first needed, again on a new day
local function role_of(env, c, cfg, P, x)
  if x.club == 0 then return "free" end
  if P.roles_stamp ~= VALUES.stamp then P.roles, P.roles_stamp = {}, VALUES.stamp end
  local roles = P.roles[x.club]
  if roles == nil then
    roles = {}
    local list = {}
    local sq = env.squad_of(c, x.club)
    for _, p in ipairs(sq and sq.players or {}) do
      local y = P.cards[env.u32(p.card)]
      if y then list[#list + 1] = { card = y.card, e = info_of(env, c, cfg, y).effective } end
    end
    table.sort(list, function(a, b)
      if a.e ~= b.e then return a.e > b.e end
      return a.card < b.card
    end)
    for k, it in ipairs(list) do
      roles[it.card] = k <= cfg.star_count and "star" or (k <= cfg.starters and "starter" or "reserve")
    end
    P.roles[x.club] = roles
  end
  return roles[x.card] or "reserve"
end

-- the price a club asks the player (the negotiation option's multiplier over the asking price)
local function player_price(env, c, cfg, P, x)
  local value, price = M.price_of(env, c, cfg, P, x)
  return value, nice(cfg, price * (cfg.player_ask or 1))
end

-- every career club's players: card -> club, and the club's squad size
local function owners(env, c)
  local by, size = {}, {}
  for i, t in ipairs(c.clubs) do
    local sq = c.squads[i]
    size[t] = #(sq and sq.players or {})
    for _, p in ipairs(sq and sq.players or {}) do by[env.u32(p.card)] = t end
  end
  return by, size
end

-- the values of a market revision: card -> { strength, position, share } for the career's players and the free ones
local CACHE = { rev = nil, seed = nil }
local function pool(env, c, m)
  if CACHE.rev == m.rev and CACHE.seed == c.seed and CACHE.cards then return CACHE end
  local by, size = owners(env, c)
  local cards, all = {}, {}
  for card in pairs(by) do
    local k = env.card_info(card)
    cards[card] = { card = card, club = by[card], strength = k.strength, position = k.position, series = k.series }
    all[#all + 1] = k.strength
  end
  local free = env.free_pool(by)
  for _, f in ipairs(free) do
    if not cards[f.card] then
      cards[f.card] = { card = f.card, club = 0, strength = f.strength, position = f.position,
        series = env.card_info(f.card).series }
      all[#all + 1] = f.strength
    end
  end
  table.sort(all)
  local rank = {}
  for i, s in ipairs(all) do rank[s] = i end      -- the last index of each strength
  for _, x in pairs(cards) do x.share = #all > 1 and (rank[x.strength] - 1) / (#all - 1) or 0.5 end
  -- each club's stature (config stature_by_rank, by its rank among the clubs by rating) and players by position
  local cfg = M.config(env, c)
  local order = {}
  for i, t in ipairs(c.clubs) do order[i] = { t = t, r = tonumber(c.ratings[i]) or 0 } end
  table.sort(order, function(a, b)
    if a.r ~= b.r then return a.r > b.r end
    return a.t < b.t
  end)
  local stature, count = {}, {}
  for k, o in ipairs(order) do
    stature[o.t] = curve(cfg.stature_curve, #order > 1 and (k - 1) / (#order - 1) or 0)
  end
  for _, x in pairs(cards) do
    if x.club ~= 0 then
      count[x.club] = count[x.club] or {}
      count[x.club][x.position] = (count[x.club][x.position] or 0) + 1
    end
  end
  local order = {}
  for card in pairs(cards) do order[#order + 1] = card end
  table.sort(order)
  CACHE = { rev = m.rev, seed = c.seed, cards = cards, size = size, stature = stature, count = count, roles = {},
    order = order }
  return CACHE
end

-- a card's market value and the price its club asks: value x his role x the club's stature x its need at his
-- position (no more players there than need_by_position); a free player: his signing fee (free_agent_fee x value)
function M.price_of(env, c, cfg, P, x)
  local value = info_of(env, c, cfg, x).value
  local role = role_of(env, c, cfg, P, x)
  local ask
  if role == "free" then
    ask = cfg.free_fee
  else
    ask = (role == "star" and cfg.ask_star or (role == "starter" and cfg.ask_starter or cfg.ask_reserve))
      * (P.stature[x.club] or 1)
    local have = P.count[x.club] and P.count[x.club][x.position] or 0
    if have <= (cfg.need_by[x.position] or 0) then ask = ask * cfg.need_ask end
  end
  return nice(cfg, value), nice(cfg, value * ask)
end

-- a player moves from club `from` (0 = free) to club `to`: the seller's roster row (if any) goes to one of its bench
-- players of the same position (else any bench player, else the row is dropped), the buyer gets him on the bench
local function move(env, c, card, from, to)
  local function drop(t)
    local sq = env.squad_of(c, t)
    if not sq then return end
    local slot
    for i, p in ipairs(sq.players) do
      if env.u32(p.card) == card then
        slot = p.slot
        table.remove(sq.players, i)
        break
      end
    end
    if slot == nil or slot < 0 then return end
    local pos = env.card_info(card).position
    local pick
    for _, p in ipairs(sq.players) do
      if (p.slot or -1) < 0 and env.card_info(p.card).position == pos then pick = p break end
    end
    if not pick then
      for _, p in ipairs(sq.players) do
        if (p.slot or -1) < 0 then pick = p break end
      end
    end
    local rows = sq.rows or {}
    for i = 1, #rows - 1, 2 do
      if env.u32(rows[i + 1]) == card then
        if pick then
          rows[i + 1], pick.slot = pick.card, slot
        else
          table.remove(rows, i + 1)
          table.remove(rows, i)
        end
        break
      end
    end
  end
  if from ~= 0 then drop(from) end
  local sq = env.squad_of(c, to)
  local used = {}
  for _, p in ipairs(sq.players) do used[tonumber(p.number) or 0] = true end
  local number = 1
  while used[number] do number = number + 1 end
  sq.players[#sq.players + 1] = { card = card, number = number, slot = -1, signed = true }
end

local function deal(env, c, m, cfg, card, from, to, fee)
  move(env, c, card, from, to)
  m.money[key(to)] = M.money(m, to) - fee
  if from ~= 0 then m.money[key(from)] = M.money(m, from) + fee end
  m.listed[key(card)], m.loan_listed[key(card)], m.blocked[key(card)] = nil, nil, nil
  if type(m.talks) == "table" then m.talks[key(card)] = nil end
  for i = #m.offers, 1, -1 do
    if m.offers[i].card == card then table.remove(m.offers, i) end
  end
  m.rev = (m.rev or 0) + 1
  table.insert(m.log, 1, { card = card, from = from, to = to, fee = fee, day = env.today_of(c) })
  while #m.log > cfg.log_size do table.remove(m.log) end
  info(string.format("deal: card %08X from %08X to %08X for %d", card, from, to, fee))
  if env.news then env.news(c, "transfer", m.log[1]) end
end

-- a loan offer accepted: the player plays for the borrower until the loan's day back, the borrower pays the fee
local function lend(env, c, m, o)
  local k = key(o.card)
  move(env, c, o.card, c.team, o.club)
  m.money[key(o.club)] = M.money(m, o.club) - o.amount
  m.money[key(c.team)] = M.money(m, c.team) + o.amount
  m.listed[k], m.loan_listed[k] = nil, nil
  for i = #m.offers, 1, -1 do
    if m.offers[i].card == o.card then table.remove(m.offers, i) end
  end
  m.loans[#m.loans + 1] = { card = o.card, from = c.team, to = o.club, back = o.back, length = o.length,
    fee = o.amount, day = env.today_of(c) }
  m.rev = (m.rev or 0) + 1
  info(string.format("loan: card %08X to %08X for %d until day %s", o.card, o.club, o.amount, tostring(o.back)))
  if env.news then env.news(c, "loan", m.loans[#m.loans]) end
end

-- the loans due back (all = every loan, a new season) return to their clubs -> how many came back
function M.loans_back(env, c, all)
  if type(c.market) ~= "table" or type(c.market.loans) ~= "table" or #c.market.loans == 0 then return 0 end
  local m = c.market
  local today, back = env.today_of(c), 0
  for i = #m.loans, 1, -1 do
    local l = m.loans[i]
    if all or (tonumber(l.back) or 0) <= today then
      table.remove(m.loans, i)
      local sq = env.squad_of(c, l.to)
      local there = false
      for _, p in ipairs(sq and sq.players or {}) do
        if env.u32(p.card) == l.card then there = true break end
      end
      if there and env.squad_of(c, l.from) then move(env, c, l.card, l.to, l.from) end
      back = back + 1
      info(string.format("loan over: card %08X back from %08X", l.card, l.to))
      if env.news then env.news(c, "loan_back", l) end
    end
  end
  if back > 0 then m.rev = (m.rev or 0) + 1 end
  return back
end

-- the «buy» lists already sorted, per (buyer, position, source, club, sort), for one pool (a market revision) and day:
-- a scroll step or a filter change reads them instead of pricing and sorting every player again (the call runs on the
-- game thread)
local BUY_LISTS = { pool = nil }

-- the «buy» list's orders: the row field sorted on (highest first), then the price, then the card
local SORTS = { level = "level", price = "price", value = "value", potential = "potential", form = "form" }

-- every player of the market (the career's clubs and the free ones): card list, for the search's names
function M.cards(env, c)
  local cfg = M.config(env, c)
  local P = pool(env, c, M.state(env, c, cfg))
  local out = {}
  for card in pairs(P.cards) do out[#out + 1] = card end
  table.sort(out)
  return out
end

-- a «buy» row kept by the search (filter: name = function(card) -> true when his name matches, level = { min, max },
-- potential = min, price = max, series = source series type, affordable = the club's money buys him; nil = no limit)
local function searched(f, x, r, money)
  if f == nil then return true end
  if f.affordable and (r.price or 0) > money then return false end
  if f.name and not f.name(x.card) then return false end
  if f.level_min and (r.level or 0) < f.level_min then return false end
  if f.level_max and (r.level or 0) > f.level_max then return false end
  if f.price_max and (r.price or 0) > f.price_max then return false end
  if f.series and x.series ~= f.series then return false end
  return true
end

-- ---- the talks' patience (both sides: the buy talks and «Negociar» on a bid) ----------------------------------------

-- a club's demand in the talks: its stature (stature_by_rank, by its rating rank) x 1 +- talk_demand_noise, drawn per
-- save and club
function M.demand(env, c, cfg, P, club)
  local rng = VRFW.rng("CareerMode.market.demand", { env.u32(c.seed), env.u32(club) })
  return (P.stature[club] or 1) * (1 + cfg.talk_demand_noise * (2 * rng:float() - 1))
end

-- the patience an ask or an offer costs the club (talk_patience_cost x its demand); gap = how far it is from what the
-- club accepts, as a share (0 = at it). The screen draws the same curve (cost_view) to show the cost before it is sent
function M.patience_cost(cfg, gap, demand)
  return curve(cfg.talk_patience_cost, math.max(0, gap)) * (demand or 1)
end

-- the patience curve for the screen: the costs as shares of the starting patience
function M.cost_view(cfg)
  local out = {}
  for i, p in ipairs(cfg.talk_patience_cost) do out[i] = { p[1], p[2] / math.max(0.001, cfg.talk_patience) } end
  return out
end

-- the most a bidder pays for the player of offer o: talk_bid_max x the larger of its first bid and his value, at most
-- its money
local function bid_most(env, c, cfg, m, P, o)
  local x = P.cards[o.card]
  local value = x and M.price_of(env, c, cfg, P, x) or 0
  return math.min(M.money(m, o.club), nice(cfg, math.max(o.first or o.amount, value) * cfg.talk_bid_max))
end

-- an offer received as the screen shows it (pending: the bidder's answer to the player's ask is due; agreed: the
-- bid was raised to the ask; patience 0..1, limit = the most the bidder pays, demand: for the cost preview)
local function offer_view(env, c, cfg, m, P, i, o)
  local loan = o.kind == "loan"
  return { offer = i, bidder = o.club, amount = o.amount, kind = o.kind or "buy", back = o.back, day = o.day,
    length = o.length, spontaneous = o.spontaneous == true, tries = o.tries or 0, ask = o.ask,
    pending = o.reply_day ~= nil, agreed = o.agreed == true, first = o.first or o.amount,
    patience = (o.patience or cfg.talk_patience) / math.max(0.001, cfg.talk_patience),
    limit = not loan and bid_most(env, c, cfg, m, P, o) or nil,
    demand = not loan and (o.demand or M.demand(env, c, cfg, P, o.club)) or nil,
    step = M.talk_step(cfg, o.first or o.amount), big = M.talk_step(cfg, o.first or o.amount) * cfg.talk_big_steps }
end

-- the market list: (view = "buy" / "offers" / "listed", position 0 = any, source "all" / "clubs" / "free" /
-- "affordable" (the club's money buys him) / "club" (the players of club `club`), first row, rows (0 = all), sort = a SORTS key,
-- filter = the search (see searched; filter.key = its text, part of the cached list's key))
-- -> { rows (from `first`, `count` of them), total, first, money, squad, max_squad, offers, listed[, pricing] }
function M.view(env, c, view, position, source, first, count, sort, club, filter)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local P = pool(env, c, m)
  values_for(env, c)
  local rows = {}
  local function row(x, extra)
    local value, price = player_price(env, c, cfg, P, x)
    local i = info_of(env, c, cfg, x)
    local r = { card = x.card, club = x.club, position = x.position, value = value, price = price, level = i.level,
      potential = i.potential, form = i.form, role = role_of(env, c, cfg, P, x) }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end
  if view == "offers" then
    for i, o in ipairs(m.offers) do
      local x = P.cards[o.card]
      if x then
        rows[#rows + 1] = row(x, offer_view(env, c, cfg, m, P, i, o))
      end
    end
  elseif view == "listed" then
    -- the club's players (status, the offers for each) and its men out on loan (status "loaned")
    local by_card = {}
    for i, o in ipairs(m.offers) do
      local list = by_card[o.card] or {}
      list[#list + 1] = offer_view(env, c, cfg, m, P, i, o)
      by_card[o.card] = list
    end
    for _, p in ipairs(env.squad_of(c, c.team).players) do
      local x = P.cards[env.u32(p.card)]
      if x then
        rows[#rows + 1] = row(x, { listed = m.listed[key(x.card)] == true, status = M.status_of(m, x.card),
          offers = by_card[x.card] or {} })
      end
    end
    for _, l in ipairs(m.loans) do
      local x = P.cards[l.card]
      if x and l.from == c.team then
        rows[#rows + 1] = row(x, { status = "loaned", borrower = l.to, back = l.back, length = l.length, fee = l.fee,
          offers = {} })
      end
    end
    table.sort(rows, function(a, b)
      if a.value ~= b.value then return a.value > b.value end
      return a.card < b.card
    end)
  else
    if BUY_LISTS.pool ~= P or BUY_LISTS.stamp ~= VALUES.stamp then BUY_LISTS = { pool = P, stamp = VALUES.stamp } end
    sort = SORTS[sort] or "price"
    club = tonumber(club) or 0
    local money = M.money(m, c.team)
    local list_key = string.format("%s:%s:%s:%s:%s:%s", tostring(c.team), tostring(position), source,
      source == "club" and tostring(club) or (source == "affordable" and tostring(money) or ""), sort,
      filter and (tostring(filter.key) .. (filter.affordable and (":" .. tostring(money)) or "")) or "")
    rows = BUY_LISTS[list_key]
    if rows == nil then
      local loaned = on_loan(m)
      -- worked out over several calls, each within work_ms (the screen asks again meanwhile, showing the progress):
      -- the day's values (price_batch at most), then the list's rows, then its order in a call of its own
      local order, left = P.order, time_left(env, cfg.work_ms)
      local n = #order
      local b = BUY_LISTS.building
      if b == nil or b.key ~= list_key then
        b = { key = list_key, priced = 0, at = 0, rows = {}, sorted = false }
        BUY_LISTS.building = b
      end
      local function progress()
        return { rows = {}, total = 0, first = 1, money = M.money(m, c.team), squad = P.size[c.team] or 0,
          max_squad = cfg.max_squad, offers = #m.offers, listed = 0,
          pricing = { done = b.priced + b.at + (b.sorted and 1 or 0), total = 2 * n + 1 } }
      end
      local made = 0
      while b.priced < n do
        local x = P.cards[order[b.priced + 1]]
        if not VALUES.info[x.card] then
          if made >= cfg.price_batch or not left() then return progress() end
          info_of(env, c, cfg, x)
          made = made + 1
        end
        b.priced = b.priced + 1
      end
      if made > 0 then return progress() end
      while b.at < n do
        if not left() then return progress() end
        b.at = b.at + 1
        local x = P.cards[order[b.at]]
        local take = x.club ~= c.team and not loaned[x.card] and (position == 0 or x.position == position)
        if take then
          if source == "free" then take = x.club == 0
          elseif source == "clubs" then take = x.club ~= 0
          elseif source == "club" then take = x.club == club end
        end
        if take then
          local r = row(x)
          if (source ~= "affordable" or r.price <= money) and searched(filter, x, r, money) then b.rows[#b.rows + 1] = r end
        end
      end
      if not b.sorted then
        b.sorted = true
        if n > 0 and #b.rows > 0 then return progress() end
      end
      rows = b.rows
      table.sort(rows, function(a, z)
        local ka, kz = a[sort] or 0, z[sort] or 0
        if ka ~= kz then return ka > kz end
        if a.price ~= z.price then return a.price > z.price end
        return a.card < z.card
      end)
      BUY_LISTS[list_key], BUY_LISTS.building = rows, nil
    end
  end
  local total = #rows
  count = count == 0 and math.max(1, total) or math.max(1, count or 9)
  first = math.max(1, math.min(math.max(1, total - count + 1), first or 1))
  local out = {}
  for i = first, math.min(total, first + count - 1) do out[#out + 1] = rows[i] end
  local listed, loan_listed, blocked, offers = 0, 0, 0, #m.offers
  for _ in pairs(m.listed) do listed = listed + 1 end
  for _ in pairs(m.loan_listed) do loan_listed = loan_listed + 1 end
  for _ in pairs(m.blocked) do blocked = blocked + 1 end
  return { rows = out, total = total, first = first, money = M.money(m, c.team),
    squad = P.size[c.team] or 0, max_squad = cfg.max_squad, offers = offers, listed = listed,
    loan_listed = loan_listed, blocked = blocked, loaned = loans_out(m, c.team) }
end

-- a buy at the asking price: the seller's rule (CanSell), the buyer's money and squad cap -> ok, why, text key
-- a club at config [squads] max_players players (the market's pool count): it signs nobody until it sells
local function squad_full(env, c, cfg, m, club)
  return (pool(env, c, m).size[club] or 0) >= cfg.max_squad
end

function M.buy(env, c, card)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local P = pool(env, c, m)
  local x = P.cards[card]
  if not x or x.club == c.team then return false, "not a player on the market" end
  if on_loan(m)[card] then return false, "the player is out on loan", "MarketOnLoan" end
  values_for(env, c)
  local _, price = player_price(env, c, cfg, P, x)
  local t = type(m.talks) == "table" and m.talks[key(card)] or nil
  if t and t.club == x.club then
    if t.reply == "walked" then return false, "the club broke off the talks", "TalkWalked" end
    price = t.ask
  end
  if (P.size[c.team] or 0) + loans_out(m, c.team) >= cfg.max_squad then return false, "the squad is full", "MarketSquadFull" end
  if M.money(m, c.team) < price then return false, "not enough money", "MarketNoMoney" end
  if x.club ~= 0 then
    local sell = env.can_sell(x.club)
    if not sell.ok then return false, sell.why, sell.text or "TransferRefusedShortSquad" end
  end
  deal(env, c, m, cfg, card, x.club, c.team, price)
  return true
end

-- an offer's step in the talks: talk_step_share of the amount, rounded as prices are
function M.talk_step(cfg, amount)
  return math.max(1000, nice(cfg, (amount or 0) * cfg.talk_step_share))
end

-- one side of a talk gives ground: from `from` towards `to` by `give` of the gap, rounded as prices are, never past
-- `limit` (the buy talks: the club's ask down to its floor; the bids: the bidder's offer up to its most)
function M.concede(cfg, from, to, give, limit)
  local v = nice(cfg, from + give * (to - from))
  if to < from then return math.max(limit, v) end
  return math.min(limit, v)
end

-- a talk as the screen shows it
local function talk_view(cfg, m, c, t, extra)
  local v = { club = t.club, start = t.start, ask = t.ask, last = t.last or 0, round = t.round, limit = t.floor,
    demand = t.demand, cost = M.cost_view(cfg),
    patience = math.max(0, t.patience) / math.max(0.001, cfg.talk_patience), reply = t.reply,
    offer = t.last or nice(cfg, t.start * cfg.talk_first_offer), step = M.talk_step(cfg, t.start),
    big = M.talk_step(cfg, t.start) * cfg.talk_big_steps, money = M.money(m, c.team) }
  for k, x in pairs(extra or {}) do v[k] = x end
  return v
end

-- the talks for a club's player (offer 0 = only the talk's state, started when new): the club's lowest price (its
-- floor) = its asking price x talk_floor_<role>, x talk_poor_floor when the club has less than talk_poor_units x unit.
-- Each offer costs the club patience (M.patience_cost, the gap = floor / offer - 1, x the club's demand). An offer at
-- its ask, or at the floor within talk_accept_gap of its ask or with the club's patience under talk_accept_patience,
-- buys him. Else, patience left, it counters: its ask comes down talk_give of the gap, not under the floor (an offer
-- under talk_low_share x the floor: «too low»); no patience left: it breaks off the talks until the window closes.
-- -> ok, why / the talk's view, text key
function M.talk(env, c, card, offer)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local P = pool(env, c, m)
  local x = P.cards[card]
  if not x or x.club == c.team or x.club == 0 then return false, "not a club's player on the market" end
  if on_loan(m)[card] then return false, "the player is out on loan", "MarketOnLoan" end
  values_for(env, c)
  if type(m.talks) ~= "table" then m.talks = {} end
  local t = m.talks[key(card)]
  if t == nil or t.club ~= x.club then
    local _, price = player_price(env, c, cfg, P, x)
    local share = cfg.talk_floor[role_of(env, c, cfg, P, x)] or 1
    if M.money(m, x.club) < cfg.unit * cfg.talk_poor_units then share = share * cfg.talk_poor_floor end
    t = { club = x.club, start = price, ask = price, floor = nice(cfg, price * share), round = 0,
      patience = cfg.talk_patience, demand = M.demand(env, c, cfg, P, x.club), reply = "open" }
    m.talks[key(card)] = t
  end
  offer = floor(tonumber(offer) or 0)
  if offer <= 0 then return true, talk_view(cfg, m, c, t) end
  if t.reply == "walked" then return false, "the club broke off the talks", "TalkWalked" end
  if (P.size[c.team] or 0) + loans_out(m, c.team) >= cfg.max_squad then return false, "the squad is full", "MarketSquadFull" end
  if M.money(m, c.team) < offer then return false, "not enough money", "MarketNoMoney" end
  local sell = env.can_sell(x.club)
  if not sell.ok then return false, sell.why, sell.text or "TransferRefusedShortSquad" end
  t.round, t.last = t.round + 1, offer
  t.demand = t.demand or M.demand(env, c, cfg, P, x.club)
  t.patience = t.patience - M.patience_cost(cfg, t.floor / math.max(1, offer) - 1, t.demand)
  local tired = t.patience < cfg.talk_accept_patience * cfg.talk_patience
  if offer >= t.ask or (offer >= t.floor and (tired or t.ask - offer <= t.ask * cfg.talk_accept_gap)) then
    local view = talk_view(cfg, m, c, t, { reply = "accepted", fee = offer })
    deal(env, c, m, cfg, card, x.club, c.team, offer)
    view.money = M.money(m, c.team)
    return true, view
  end
  local low = offer < t.floor * cfg.talk_low_share
  if t.patience <= 0 then
    t.reply = "walked"
    info(string.format("talks: card %08X, club %08X broke off after %d rounds", card, x.club, t.round))
  else
    t.ask = M.concede(cfg, t.ask, offer, cfg.talk_give, t.floor)
    t.reply = low and "low" or "counter"
  end
  return true, talk_view(cfg, m, c, t)
end

-- «Negociar»: the player's asking price for a transfer offer received. An ask over the most the bidder pays costs its
-- patience (M.patience_cost, the gap = ask / most - 1, x its demand). The bidder answers after a few days
-- (talk_reply_days, drawn per save, offer and ask; see bid_replies) -> ok, why / { reply = "pending", day, tries,
-- patience }, text key. An ask at or under the bid takes the offer as it is.
function M.negotiate(env, c, index, amount)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local o = m.offers[index]
  if not o then return false, "no such offer" end
  if o.kind == "loan" then return false, "a loan fee is not negotiated", "MarketLoanNoTalk" end
  if o.reply_day then return false, "the bidder has not answered yet", "MarketTalkPending" end
  if o.agreed then return false, "the bidder already pays the asked price", "MarketTalkAgreed" end
  amount = floor(tonumber(amount) or 0)
  if amount <= o.amount then return M.answer(env, c, index, true) end
  o.first = o.first or o.amount
  o.ask = nice(cfg, amount)
  o.tries = (o.tries or 0) + 1
  local P = pool(env, c, m)
  values_for(env, c)
  local most = bid_most(env, c, cfg, m, P, o)
  o.demand = o.demand or M.demand(env, c, cfg, P, o.club)
  o.patience = o.patience or cfg.talk_patience
  if o.ask > most then o.patience = o.patience - M.patience_cost(cfg, o.ask / math.max(1, most) - 1, o.demand) end
  local today = env.today_of(c)
  local rng = VRFW.rng("CareerMode.market.reply", { env.u32(c.seed), env.u32(o.card), o.club, o.tries, today })
  o.reply_day = today + rng:int(cfg.talk_reply_days[1], cfg.talk_reply_days[2])
  info(string.format("negotiate: card %08X, ask %d to club %08X, reply on day %d", o.card, o.ask, o.club, o.reply_day))
  return true, { reply = "pending", day = o.reply_day, tries = o.tries,
    patience = math.max(0, o.patience) / math.max(0.001, cfg.talk_patience) }
end

-- the bidders' answers due by today to the player's asks (M.negotiate). An ask within the most it pays (bid_most):
-- the bid raised to it ("agreed", the player still accepts it). Its patience used up: the bidder walks away (the
-- offer goes). Else it bids again, closer: talk_sell_give (by the gap's share of the bid, +-talk_sell_jitter) of the
-- way to the ask, not over its most. Each answer is a news item and counts in m.replies (the day walk stops on it).
local function bid_replies(env, c, cfg, m, P, rng)
  local today = env.today_of(c)
  for i = #m.offers, 1, -1 do
    local o = m.offers[i]
    if o.reply_day and o.reply_day <= today then
      o.reply_day = nil
      local most = bid_most(env, c, cfg, m, P, o)
      local reply
      if o.ask <= most then
        o.amount, o.agreed, reply = o.ask, true, "agreed"
      elseif (o.patience or cfg.talk_patience) <= 0 then
        table.remove(m.offers, i)
        reply = "walked"
      else
        local gap = (o.ask - o.amount) / math.max(1, o.amount)
        local give = curve(cfg.talk_sell_give, math.min(1, gap)) * (1 + cfg.talk_sell_jitter * (2 * rng:float() - 1))
        o.amount = math.max(o.amount, M.concede(cfg, o.amount, o.ask, give, most))
        reply = "counter"
      end
      m.replies = (m.replies or 0) + 1
      info(string.format("negotiate: club %08X answers %s for card %08X (bid %d, ask %d)", o.club, reply, o.card,
        o.amount, o.ask))
      if env.news then env.news(c, "bid_reply", { card = o.card, club = o.club, amount = o.amount, ask = o.ask,
        reply = reply }) end
    end
  end
end

-- one of the club's players set to a status ("transfer" / "loan" / "blocked" / "none"); one status at a time, the
-- status he has already sets him back to "none". A blocked player is unblocked before he goes on a list. The offers
-- that no longer fit his status go (all on "none" or "blocked", the bids on "loan", the loan offers on "transfer")
function M.set_status(env, c, card, status)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local P = pool(env, c, m)
  local x = P.cards[card]
  if not x or x.club ~= c.team then return false, "not a player of the club" end
  if status ~= "transfer" and status ~= "loan" and status ~= "blocked" then status = "none" end
  local now = M.status_of(m, card)
  if status == now then status = "none" end
  if now == "blocked" and status ~= "none" then return false, "the player is blocked", "MarketUnblockFirst" end
  local k = key(card)
  m.listed[k], m.loan_listed[k], m.blocked[k] = nil, nil, nil
  if status == "transfer" then m.listed[k] = true
  elseif status == "loan" then m.loan_listed[k] = true
  elseif status == "blocked" then m.blocked[k] = true end
  for i = #m.offers, 1, -1 do
    local o = m.offers[i]
    if o.card == card then
      local loan = o.kind == "loan"
      if status == "none" or status == "blocked" or (status == "loan") ~= loan then table.remove(m.offers, i) end
    end
  end
  info(string.format("status: card %08X %s -> %s", card, now, status))
  return true
end

-- the player's own player listed / no longer listed for sale
function M.toggle_listed(env, c, card)
  return M.set_status(env, c, card, "transfer")
end

-- an offer received: accepted (the player goes) or refused
function M.answer(env, c, index, accept)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local o = m.offers[index]
  if not o then return false, "no such offer" end
  if not accept then
    table.remove(m.offers, index)
    return true
  end
  if o.kind == "loan" and (tonumber(o.back) or 0) <= env.today_of(c) then
    table.remove(m.offers, index)
    return false, "the loan would be over already", "MarketLoanLate"
  end
  local sell = env.can_sell(c.team)
  if not sell.ok then return false, sell.why, sell.text or "TransferRefusedShortSquad" end
  if squad_full(env, c, cfg, m, o.club) then
    table.remove(m.offers, index)
    return false, "the bidder's squad is full", "MarketBidderFull"
  end
  if M.money(m, o.club) < o.amount then
    table.remove(m.offers, index)
    return false, "the bidder has no money left", "MarketBidderNoMoney"
  end
  if o.kind == "loan" then lend(env, c, m, o) else deal(env, c, m, cfg, o.card, c.team, o.club, o.amount) end
  return true
end

-- after a round: every club's income; inside a transfer window the AI clubs' deals and their bids for the player's
-- listed men; outside one the offers lapse
-- part (optional) = { share, k, n }: day k of n of the round (CareerMode.Day): that share of the income and the bid
-- chance, and the AI deals of the round spread over the n days
function M.after_round(env, c, open, rng, part)
  local cfg = M.config(env, c)
  local m = M.state(env, c, cfg)
  local share = part and part.share or 1
  local deals = cfg.ai_deals_per_round
  if part then
    deals = floor(cfg.ai_deals_per_round * part.k / part.n) - floor(cfg.ai_deals_per_round * (part.k - 1) / part.n)
  end
  for _, t in ipairs(c.clubs) do
    m.money[key(t)] = M.money(m, t) + floor(cfg.unit * cfg.income_per_round * share)
  end
  -- the loans due back return, inside a window or not
  M.loans_back(env, c, false)
  if not open then
    m.offers = {}
    m.talks = {}
    return
  end
  local P = pool(env, c, m)
  values_for(env, c)
  bid_replies(env, c, cfg, m, P, rng)
  -- the AI clubs' deals: a club short at a position signs the best player (level + form) it can afford there
  local buyers = {}
  for _, t in ipairs(c.clubs) do
    if t ~= c.team and (P.size[t] or 0) < cfg.max_squad then buyers[#buyers + 1] = t end
  end
  rng:shuffle(buyers)
  local candidates = {}
  local loaned = on_loan(m)
  for _, x in pairs(P.cards) do
    if x.club ~= c.team and not loaned[x.card] then candidates[#candidates + 1] = x end
  end
  table.sort(candidates, function(a, b) return a.card < b.card end)
  local done = 0
  for _, t in ipairs(buyers) do
    if done >= deals or #candidates == 0 then break end
    local count = {}
    for _, p in ipairs(env.squad_of(c, t).players) do
      local pos = env.card_info(p.card).position
      count[pos] = (count[pos] or 0) + 1
    end
    local need, gap = nil, 0
    for _, pos in ipairs(POSITIONS) do
      local g = (cfg.need_by[pos] or 0) - (count[pos] or 0)
      if g > gap then need, gap = pos, g end
    end
    -- a buyer filled earlier this round signs no more
    if need and (P.size[t] or 0) < cfg.max_squad then
      local budget = M.money(m, t) * cfg.ai_spend_share
      local best, best_price, best_level
      for _ = 1, cfg.ai_sample do
        local x = candidates[rng:int(1, #candidates)]
        if x.position == need and x.club ~= t then
          local _, price = M.price_of(env, c, cfg, P, x)
          local level = info_of(env, c, cfg, x).effective
          local sellable = x.club == 0 or env.can_sell(x.club).ok
          if price <= budget and sellable and (not best or level > best_level) then
            best, best_price, best_level = x, price, level
          end
        end
      end
      if best then
        local from = best.club
        deal(env, c, m, cfg, best.card, from, t, best_price)
        -- the values stay as they are this round: the pool follows the deal in place
        best.club = t
        if from ~= 0 then
          P.size[from] = (P.size[from] or 1) - 1
          P.count[from][best.position] = (P.count[from][best.position] or 1) - 1
          P.roles[from] = nil
        end
        P.size[t] = (P.size[t] or 0) + 1
        P.count[t] = P.count[t] or {}
        P.count[t][best.position] = (P.count[t][best.position] or 0) + 1
        P.roles[t] = nil
        CACHE.rev = m.rev
        done = done + 1
      end
    end
  end
  -- the AI clubs' offers for the player's men: bids for the listed ones, loan offers for the ones listed for loan,
  -- now and then a bid for one on no list (none for a blocked one, nor for one with an offer waiting)
  local function bidder_for(amount)
    if #buyers == 0 then return nil end
    local t = buyers[rng:int(1, #buyers)]
    if M.money(m, t) >= amount and (P.size[t] or 0) < cfg.max_squad then return t end
    return nil
  end
  local function offer(o, kind)
    m.offers[#m.offers + 1] = o
    if env.news then env.news(c, kind, o) end
  end
  local waiting = {}
  for _, o in ipairs(m.offers) do waiting[o.card] = true end
  for _, p in ipairs(env.squad_of(c, c.team).players) do
    local x = P.cards[env.u32(p.card)]
    local status = x and x.club == c.team and M.status_of(m, x.card) or "blocked"
    if status == "transfer" then
      if rng:float() < cfg.bid_chance * share then
        local value = M.price_of(env, c, cfg, P, x)
        local amount = nice(cfg, value * curve(cfg.bid_range, rng:float()) * (cfg.player_bid or 1))
        local bidder = bidder_for(amount)
        if bidder then offer({ card = x.card, club = bidder, amount = amount, day = env.today_of(c) }, "offer") end
      end
    elseif status == "loan" then
      if rng:float() < cfg.loan_offer_chance * share then
        local value = M.price_of(env, c, cfg, P, x)
        local amount = nice(cfg, value * curve(cfg.loan_fee_range, rng:float()))
        local length = cfg.loan_lengths[rng:int(1, #cfg.loan_lengths)]
        local back = env.loan_back and env.loan_back(c, length) or nil
        local bidder = bidder_for(amount)
        if bidder and back and back > env.today_of(c) then
          offer({ kind = "loan", card = x.card, club = bidder, amount = amount, length = length, back = back,
            day = env.today_of(c) }, "loan_offer")
        end
      end
    elseif status == "none" and not waiting[x.card] then
      if rng:float() < cfg.unlisted_bid_chance * share then
        local value = M.price_of(env, c, cfg, P, x)
        local amount = nice(cfg, value * curve(cfg.unlisted_bid_range, rng:float()) * (cfg.player_bid or 1))
        local bidder = bidder_for(amount)
        if bidder then
          offer({ card = x.card, club = bidder, amount = amount, day = env.today_of(c), spontaneous = true }, "offer")
        end
      end
    end
  end
  if done > 0 then info(string.format("AI deals this round: %d", done)) end
end

return M
