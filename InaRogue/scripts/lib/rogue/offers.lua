-- InaRogue › INAROGUE: the offers of a v2 run (docs/game/mods/inarogue-loop-v2.md §3-§5): every interactive moment of
-- the board is one «offer» kept in the run file (rogue_run.json `offer`): the players of a beaten rival (pick 1 of 3),
-- a Tienda line, an Evento node, a Tragaperras line, a relic choice (Cofre, Élite, boss). The menus show it with one
-- generic loop (an intro window, then a yes / no question per choice); the texts are built here in the game's language.
-- Seeded by the run (seed, phase, node): the same offer after a reload.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_INAROGUE_RL_RUN_OFFER | 0 | ok, kind, intro text, choices, exclusive (one pick closes it), coins |
-- | | 1, i (1-based) | ok, question text ({name} = the player's name, filled by the menu), player param (0 = none) |
-- | | 2, i | code, result text ({name} as above), action (0 none, 1 a player joined: create him), param, team slot |
-- | | 3 | ok, closing text: the offer is closed (the next queued offer of the node opens) |
-- | | 4, what | ok, text: opens the offer of the current node (1 Tienda, 2 Tragaperras, 3 Evento, 4 Cofre); false = not a
-- |   |         | v2 run (the menu keeps its old content), text = why nothing opens (a challenge closed it) |
-- Codes: 0 ok, 1 no offer, 2 bad choice, 3 taken, 4 not enough coins, 5 relics full, 6 write failed, 7 nothing left.

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local cfgm = require "lib/rogue/cfg"
local Rules = require "lib/rogue/run_rules"
local R = require "lib/rogue/run"
local Items = require "lib/rogue/items"
local chara = require "lib/rogue/chara"
local Bk = require "lib/rogue/bank"
local Pool = require "lib/rogue/talent_pool"
local St = require "lib/rogue/starter"
local growth = require "lib/rogue/growth"
local info, warn = U.logger("rogue offers")

local O = {}

O.CODE = { OK = 0, NONE = 1, BAD = 2, TAKEN = 3, NO_COINS = 4, FULL = 5, WRITE_FAILED = 6, EMPTY = 7 }
local C = O.CODE
O.WHAT = { SHOP = 1, SLOT = 2, EVENT = 3, CHEST = 4 }
local ACTION_NONE, ACTION_PLAYER = 0, 1

-- node kinds (lib/rogue/map.lua KIND)
local K_SMALL, K_FULL, K_BOSS, K_ELITE, K_EPIC, K_GATE = 1, 2, 3, 7, 8, 9
local KIND_NAME = { [K_SMALL] = "small", [K_FULL] = "full", [K_BOSS] = "boss", [K_ELITE] = "elite", [K_EPIC] = "epic",
  [K_GATE] = "gate" }

local T = Rules.text

local function run() return Core.run.run_hdls() end
local function edit(why, f) return Core.run.edit_run(why, f) end

-- a seeded stream of the run's node `node` for one use (`salt`)
local function stream(r, node, salt)
  local s = U.xor(U.xor(U.xor(r.seed % U.TWO32, U.mul32(math.max(r.phase, 1), 0x7FEB352D)), U.mul32(node + 1, 0x846CA68B)),
    salt % U.TWO32)
  return U.stream(math.max(s, 1))
end

-- ---------------------------------------------------------------------------------------- players

local function owned_set()
  local o = {}
  for _, p in ipairs(Core.bank.bank_params()) do o[p] = true end
  return o
end

-- a player the run may offer: a pool card (tier 1-5, no staff, no What-if) not offered twice
local function offerable(param, seen)
  if type(param) ~= "number" or param == 0 or seen[param] then return false end
  local i = chara.get(param)
  return i ~= nil and chara.in_pool(i)
end

-- the cards of node `node`'s random-team rival (its drawn roster; {} for any other rival)
local function rival_roster(node)
  local rule, seed, key, stage, slot = Core.run.Rival(node)
  local RT = rawget(_G, "RandomTeam")
  if type(rule) ~= "string" or rule == "" or not RT or not RT.Preview or not RT.Member then return {} end
  local ok, built, _, _, members = pcall(RT.Preview, rule, seed, key, stage, slot)
  if not ok or built ~= 1 then
    warn(string.format("node %d: rival roster preview failed (%s)", node, tostring(built)))
    return {}
  end
  local o = {}
  for k = 1, U.int(members, 0) do
    local okm, card = pcall(RT.Member, k)
    if okm and type(card) == "number" and card ~= 0 then o[#o + 1] = card % U.TWO32 end
  end
  return o
end

-- the highest tier the run offers in its phase (+ `extra`)
local function max_tier(r, extra)
  return U.clamp(cfgm.recruit_max_tier(Core.cfg(), r.phase) + (extra or 0), 1, 5)
end

-- `n` players: the beaten rival's line-up first (not owned before owned), then the pool up to `tier`
local function draw_players(r, st, n, roster, lo, hi)
  local owned, seen, out = owned_set(), {}, {}
  local fresh, known = {}, {}
  for _, p in ipairs(roster or {}) do
    if offerable(p, seen) then
      seen[p] = true
      if owned[p] then known[#known + 1] = p else fresh[#fresh + 1] = p end
    end
  end
  local function take(list)
    while #out < n and #list > 0 do
      local p = table.remove(list, st:next() % #list + 1)
      out[#out + 1] = { param = p, tier = chara.tier_of(p) }
    end
  end
  take(fresh)
  if #out < n then
    local pool = {}
    for _, x in ipairs(Core.bank.recruit_pool(hi)) do
      if x[2] >= lo and not seen[x[1]] then pool[#pool + 1] = x[1] end
    end
    take(pool)
  end
  take(known)
  return out
end

-- player `param` joins: the collection (kept for good), the first free bench slot of the run's team. Returns
-- result text, action, slot (inside an edit of run `r`)
local function join(r, param, why, source)
  local code, uid = Core.bank.bank_add_param(param, why, Bk.SOURCE.RECRUIT)
  if code == Bk.CODE.DUPLICATE then
    -- already in the collection: spirits of that player (lib/rogue/spirits.lua), never a duplicate
    local n = require("lib/rogue/spirits").amount(source or "other")
    local total = Core.bank.spirits_add(uid, n, why .. " (owned: spirits)") or 0
    return T("InaRogue.run_spirits_got", n, total), ACTION_NONE, -1
  end
  if code ~= Bk.CODE.OK then
    warn(string.format("%s: %s not added (code %d)", why, U.hex(param), code))
    return T("InaRogue.run_recruit_failed"), ACTION_NONE, -1
  end
  r.stats.recruits = r.stats.recruits + 1
  local s = R.free_bench_slot(r)
  if s and R.find_uid(r, uid) == nil then
    R.set_slot(r, s, uid)
    R.set_hdl(r, s, 0)
    if not U.contains(r.squad, uid) then r.squad[#r.squad + 1] = uid end
    return T("InaRogue.run_recruit_joined"), ACTION_PLAYER, s
  end
  return T("InaRogue.run_recruit_collection"), ACTION_NONE, -1
end

-- ---------------------------------------------------------------------------------------- relics

-- the relics of `source` the run may get: held items (kind passive) open by the meta progress, not held yet
local function relic_pool(r, source)
  local meta = require "lib/rogue/meta_store"
  local held = {}
  for _, o in ipairs(r.items or {}) do held[o.key] = true end
  local o = {}
  for _, d in ipairs(Items.catalogue().list) do
    if d.kind == "passive" and d.sources[source] and not held[d.key] and meta.item_open(d) then o[#o + 1] = d end
  end
  return o
end

-- `n` different relics of `source` (items.toml sources) by the rarity weights of [rogue.run] item_weights[`weights_of`]
-- (default: the source's own)
local function draw_relics(r, st, source, n, exclude, weights_of)
  local pool = relic_pool(r, source)
  local weights = Rules.get().item_weights[weights_of or source] or { 1, 1, 1, 1 }
  local out = {}
  local used = {}
  for k in pairs(exclude or {}) do used[k] = true end
  while #out < n do
    local by_rarity, total = {}, 0
    for _, d in ipairs(pool) do
      if not used[d.key] then
        local w = weights[d.rarity] or 0
        if w > 0 then
          by_rarity[#by_rarity + 1] = { d, w }
          total = total + w
        end
      end
    end
    if total == 0 then
      -- no relic of the weighted rarities left: any relic of the source
      for _, d in ipairs(pool) do
        if not used[d.key] then
          by_rarity[#by_rarity + 1] = { d, 1 }
          total = total + 1
        end
      end
    end
    if total == 0 then break end
    local x = st:next() % total
    for _, e in ipairs(by_rarity) do
      if x < e[2] then
        out[#out + 1] = e[1]
        used[e[1].key] = true
        break
      end
      x = x - e[2]
    end
  end
  return out
end

local function relic_name(key) return T("InaRogue.rogue_item_" .. key .. "_name") end
local function relic_desc(key) return T("InaRogue.rogue_item_" .. key .. "_desc") end

-- relic `key` into the run (inside an edit): result text
local function give_relic(r, key, added)
  if Rules.modifiers(r).no_items then return T("InaRogue.run_relic_none") end
  local d = Items.by_key(key)
  if not d then return T("InaRogue.run_relic_none") end
  local max = Items.catalogue().max_slots
  if #r.items >= max then return T("InaRogue.run_relic_full", max) end
  r.items[#r.items + 1] = Items.new_owned(d)
  r.stats.items = r.stats.items + 1
  added[#added + 1] = key
  return T("InaRogue.run_relic_got", relic_name(key))
end

-- ---------------------------------------------------------------------------------------- events

local events = nil

local function the_events()
  if events then return events end
  events = {}
  local file, schema = "content/rogue/events.toml", "InaRogue.events/1"
  local ok, t = pcall(VRFW.files.toml, file)
  if not ok or type(t) ~= "table" or t.schema ~= schema then
    warn(file .. ": " .. tostring(ok and (type(t) == "table" and t.schema) or t) .. "; no events")
    return events
  end
  local function gives(list)
    local o = {}
    for _, g in ipairs(type(list) == "table" and list or {}) do
      if type(g) == "table" and type(g.kind) == "string" then o[#o + 1] = g end
    end
    return o
  end
  for k, e in ipairs(type(t.event) == "table" and t.event or {}) do
    if type(e) == "table" and type(e.key) == "string" and e.key:match("^[a-z0-9_]+$") then
      local x = { key = e.key, weight = math.max(U.int(e.weight, 1), 0), from = math.max(U.int(e.from_stage, 1), 1),
        choices = {} }
      for _, c in ipairs(type(e.choice) == "table" and e.choice or {}) do
        local cost = type(c.cost) == "table" and c.cost or {}
        x.choices[#x.choices + 1] = { coins = math.max(U.int(cost.coins, 0), 0), chance = U.clamp(U.int(c.chance, 100), 0, 100),
          give = gives(c.give), fail = gives(c.fail) }
      end
      if #x.choices > 0 then events[#events + 1] = x end
    else
      warn(file .. ": [[event]] #" .. k .. " needs a key of a-z 0-9 _ (left out)")
    end
  end
  info(string.format("%d event(s)", #events))
  return events
end

local function event_by_key(key)
  for _, e in ipairs(the_events()) do
    if e.key == key then return e end
  end
  return nil
end

-- one give of an event choice (inside an edit): result text, action, param, slot
local function apply_give(r, g, st, added)
  local kind = g.kind
  if kind == "coins" then
    local n = U.int(g.value, 0)
    if n > 0 then n = U.round(n * Rules.modifiers(r).coins_mult * Rules.relic_coin_mult(r)) end
    r.coins = math.max(r.coins + n, 0)
    if n >= 0 then
      r.stats.coins_earned = r.stats.coins_earned + n
      return T("InaRogue.run_coins_got", n, r.coins), ACTION_NONE, 0, -1
    end
    return T("InaRogue.run_coins_lost", -n, r.coins), ACTION_NONE, 0, -1
  elseif kind == "recruit" then
    if Rules.modifiers(r).no_recruit then return T("InaRogue.run_recruit_closed"), ACTION_NONE, 0, -1 end
    local tiers = type(g.tier) == "table" and U.nums(g.tier) or { 1, max_tier(r) }
    local lo, hi = U.clamp(tiers[1] or 1, 1, 5), U.clamp(tiers[2] or tiers[1] or 5, 1, 5)
    local p = draw_players(r, st, 1, {}, lo, hi)[1]
    if not p then return T("InaRogue.run_offer_none"), ACTION_NONE, 0, -1 end
    local text, action, slot = join(r, p.param, "event recruit", "event")
    return text, action, p.param, slot
  elseif kind == "item" then
    local d = draw_relics(r, st, type(g.source) == "string" and g.source or "chest", 1, nil, "event")[1]
    if not d then return T("InaRogue.run_relic_none"), ACTION_NONE, 0, -1 end
    return give_relic(r, d.key, added), ACTION_NONE, 0, -1
  elseif kind == "frags" then
    local n = math.max(U.int(g.value, 1), 0)
    local players = Core.bank.bank_frags_to(R.player_uids(r), n, "event fragments")
    return T("InaRogue.run_frags_got", players > 0 and n or 0), ACTION_NONE, 0, -1
  elseif kind == "points" then
    local n = Core.meta.earn_bonus(math.max(U.int(g.value, 0), 0), "event") or 0
    return T("InaRogue.run_points_got", n), ACTION_NONE, 0, -1
  elseif kind == "talent" then
    local t = Pool.draw(r, st, "event", 1)[1]
    if not t then return T("InaRogue.run_talent_none"), ACTION_NONE, 0, -1 end
    local text, _, param = give_talent(r, t.key, t.uid)
    return text, ACTION_NONE, param, -1
  end
  return "", ACTION_NONE, 0, -1
end

-- ---------------------------------------------------------------------------------------- talents

-- talent `key` to run player `uid` (inside an edit): result text, action, param
local function give_talent(r, key, uid)
  if not Pool.by_key(key) then return T("InaRogue.run_talent_none"), ACTION_NONE, 0 end
  r.talent_of = r.talent_of or {}
  if r.talent_of[uid] then return T("InaRogue.run_talent_none"), ACTION_NONE, 0 end
  r.talent_of[uid] = key
  local param = Core.bank.bank_entry(uid) or 0
  return T("InaRogue.run_talent_got", Pool.name(key)), ACTION_NONE, param
end

local function talent_choices(list, priced, r)
  local o = {}
  for _, t in ipairs(list) do
    o[#o + 1] = { what = "talent", id = t.key, price = priced and Pool.price(r, t.key) or 0, tier = t.rarity,
      taken = false, uid = t.uid }
  end
  return o
end

-- ---------------------------------------------------------------------------------------- building offers

local function new_offer(kind, node, key, choices, queue, gain, exclusive)
  return { kind = kind, node = node, key = key or "", choices = choices or {}, queue = queue or {}, gain = gain or 0,
    exclusive = exclusive ~= false }
end

local function player_choices(list, priced, r)
  local o = {}
  for _, p in ipairs(list) do
    local price = 0
    if priced then price = Rules.price(r, Rules.per_stage(Rules.get().recruit_cost, p.tier)) end
    o[#o + 1] = { what = "player", id = p.param, price = price, tier = p.tier, taken = false }
  end
  return o
end

local function relic_choices(list, priced, r)
  local o = {}
  for _, d in ipairs(list) do
    local price = 0
    if priced then price = Rules.price(r, U.round(d.price * Rules.get().item_price_scale)) end
    o[#o + 1] = { what = "relic", id = d.key, price = price, tier = d.rarity, taken = false }
  end
  return o
end

-- the relic choice of `source` at node `node` (salt per source)
local SALT = { recruit = 0x52454352, chest = 0x43484553, elite = 0x454C4954, boss = 0x424F5353, shop = 0x53484F50,
  event = 0x4556454E, slot = 0x534C4F54 }

local function relic_offer(r, node, source, queue)
  local st = stream(r, node, SALT[source] or 1)
  local talents_n = source == "elite" and Rules.get().elite_talents or 0
  local choices = {}
  if not Rules.modifiers(r).no_items then
    choices = relic_choices(draw_relics(r, st, source, math.max(Rules.get().item_offers - talents_n, 1)), false, r)
  end
  if talents_n > 0 then
    for _, c in ipairs(talent_choices(Pool.draw(r, st, "elite", talents_n), false, r)) do choices[#choices + 1] = c end
  end
  if #choices == 0 then return nil end
  return new_offer("relic", node, source, choices, queue, 0, true)
end

-- the next offer of a queue entry ("relic:<source>")
local function from_queue(r, node, queue)
  while #queue > 0 do
    local q = table.remove(queue, 1)
    local source = q:match("^relic:(%a+)$")
    if source then
      local o = relic_offer(r, node, source, queue)
      if o then return o end
    end
  end
  return nil
end

-- after a won match of a v2 run (svc_run Result, the run already saved): the beaten rival's players, then the relic
-- of an Élite / boss win. `coins` = what the win paid (shown in the intro)
function O.after_win(node, kind, coins)
  local roster = nil
  local after = {}
  for _, k in ipairs(Rules.get().recruit_after) do after[k] = true end
  local code = edit("offers after the win", function(r)
    if not Rules.is_v2(r) or r.outro then return C.NONE end
    local queue = {}
    -- an Élite: relics and a talent; a phase boss: the same; a «big boss» (every 5 phases): the boss relic weights
    if kind == K_ELITE then
      queue[#queue + 1] = "relic:elite"
    elseif kind == K_BOSS then
      queue[#queue + 1] = Rules.big_boss(r) and "relic:boss" or "relic:elite"
    end
    local offer = nil
    local m = Rules.modifiers(r)
    local n = math.max(Rules.get().recruit_offers + m.recruit_offers, 1)
    if after[KIND_NAME[kind] or ""] and not m.no_recruit and Rules.get().recruit_offers > 0 then
      roster = roster or rival_roster(node)
      local extra = (kind == K_ELITE or kind == K_BOSS or kind == K_GATE) and 1 or 0
      local list = draw_players(r, stream(r, node, SALT.recruit), n, roster, 1, max_tier(r, extra))
      local source = (kind == K_BOSS and Rules.big_boss(r)) and "big_boss" or (KIND_NAME[kind] or "")
      if #list > 0 then offer = new_offer("recruit", node, source, player_choices(list, false, r), queue, coins, true) end
    end
    offer = offer or from_queue(r, node, queue)
    if not offer and coins > 0 then offer = new_offer("coins", node, "", {}, {}, coins, true) end
    r.offer = offer
    return C.OK
  end)
  info(string.format("after the win at node %d (kind %d): offer code %d", node, kind, code))
end

-- CMND_INAROGUE_RL_RUN_OFFER op 4: the offer of the current node
local function open_here(what)
  local r = run()
  if not r or not Rules.is_v2(r) then return false, "" end
  local node = r.cur
  local m = Rules.modifiers(r)
  local text = ""
  local code = edit("offer opened", function(x)
    if what == O.WHAT.SHOP then
      if m.no_shop then
        text = T("InaRogue.run_shop_closed")
        x.offer = nil
        return C.OK
      end
      local st = stream(x, node, SALT.shop)
      local players = {}
      if not m.no_recruit then players = draw_players(x, st, Rules.get().shop_players, {}, 1, max_tier(x, 1)) end
      local relics = {}
      if not m.no_items then relics = draw_relics(x, st, "shop", Rules.get().shop_items) end
      local choices = player_choices(players, true, x)
      for _, c in ipairs(relic_choices(relics, true, x)) do choices[#choices + 1] = c end
      for _, c in ipairs(talent_choices(Pool.draw(x, st, "shop", Rules.get().shop_talents), true, x)) do
        choices[#choices + 1] = c
      end
      x.offer = new_offer("shop", node, "", choices, {}, 0, false)
    elseif what == O.WHAT.SLOT then
      x.offer = new_offer("slot", node, "", { { what = "bet", id = 0, price = Rules.get().slot_bet, tier = 0, taken = false } },
        {}, 0, true)
    elseif what == O.WHAT.EVENT then
      local list, total = {}, 0
      for _, e in ipairs(the_events()) do
        if e.from <= x.phase and e.weight > 0 then
          list[#list + 1] = e
          total = total + e.weight
        end
      end
      if total == 0 then
        x.offer = nil
        return C.OK
      end
      local pick = stream(x, node, SALT.event):next() % total
      local ev = list[#list]
      for _, e in ipairs(list) do
        if pick < e.weight then
          ev = e
          break
        end
        pick = pick - e.weight
      end
      local choices = {}
      for k, c in ipairs(ev.choices) do
        choices[k] = { what = "choice", id = k, price = Rules.price(x, c.coins), tier = 0, taken = false }
      end
      x.offer = new_offer("event", node, ev.key, choices, {}, 0, true)
      x.stats.events = x.stats.events + 1
    elseif what == O.WHAT.CHEST then
      x.offer = relic_offer(x, node, "chest", {})
      if not x.offer then text = T("InaRogue.run_relic_none") end
    else
      return C.BAD
    end
    return C.OK
  end)
  return code == C.OK, text
end

-- ---------------------------------------------------------------------------------------- the command

local function intro(r, o)
  local gain = o.gain > 0 and (T("InaRogue.run_coins_got", o.gain, r.coins) .. "\n") or ""
  -- endless: the phase and how much stronger its rivals are (the stat multiplier on top of their level)
  local k = Rules.rival_scale(r)
  if k > 1.0 then gain = gain .. T("InaRogue.run_endless_scale", r.phase, U.round((k - 1) * 100)) .. "\n" end
  if o.kind == "recruit" then return gain .. T("InaRogue.run_offer_recruit") end
  if o.kind == "coins" then return T("InaRogue.run_coins_got", o.gain, r.coins) end
  if o.kind == "shop" then return T("InaRogue.run_offer_shop", r.coins) end
  if o.kind == "slot" then return T("InaRogue.run_offer_slot", Rules.get().slot_bet, r.coins) end
  if o.kind == "event" then
    return T("InaRogue.run_event_" .. o.key .. "_title") .. "\n" .. T("InaRogue.run_event_" .. o.key .. "_text")
  end
  if o.kind == "relic" then return gain .. T("InaRogue.run_offer_relic_" .. o.key) end
  return gain
end

local function question(r, o, c, i)
  if o.kind == "recruit" then return T("InaRogue.run_ask_recruit", c.tier), c.id end
  if o.kind == "shop" and c.what == "player" then return T("InaRogue.run_ask_buy_player", c.tier, c.price, r.coins), c.id end
  if o.kind == "shop" then
    return T("InaRogue.run_ask_buy_relic", relic_name(c.id), c.price, r.coins, relic_desc(c.id)), 0
  end
  if c.what == "talent" then
    local param = Core.bank.bank_entry(c.uid) or 0
    if c.price > 0 then
      return T("InaRogue.run_ask_buy_talent", Pool.name(c.id), c.price, r.coins, Pool.desc(c.id)), param
    end
    return T("InaRogue.run_ask_talent", Pool.name(c.id), Pool.desc(c.id)), param
  end
  if o.kind == "relic" then return T("InaRogue.run_ask_relic", relic_name(c.id), relic_desc(c.id)), 0 end
  if o.kind == "slot" then return T("InaRogue.run_ask_slot", c.price, r.coins), 0 end
  if o.kind == "event" then
    local q = T("InaRogue.run_event_" .. o.key .. "_c" .. i)
    if c.price > 0 then q = q .. "\n" .. T("InaRogue.run_cost_coins", c.price, r.coins) end
    return q, 0
  end
  return "", 0
end

-- choice `i` taken (inside an edit of `r`): code, text, action, param, slot
local function take(r, o, c, i, added)
  if c.taken then return C.TAKEN, "", ACTION_NONE, 0, -1 end
  if c.price > r.coins then return C.NO_COINS, T("InaRogue.run_no_coins", r.coins, c.price), ACTION_NONE, 0, -1 end
  if c.what == "relic" and #r.items >= Items.catalogue().max_slots then
    return C.FULL, T("InaRogue.run_relic_full", Items.catalogue().max_slots), ACTION_NONE, 0, -1
  end
  local ev = c.what == "choice" and event_by_key(o.key) or nil
  if c.what == "choice" and not (ev and ev.choices[c.id]) then return C.BAD, "", ACTION_NONE, 0, -1 end
  r.coins = r.coins - c.price
  c.taken = true
  if c.what == "player" then
    local source = o.kind == "shop" and "shop" or (o.key ~= "" and o.key or "other")
    local text, action, slot = join(r, c.id, o.kind == "shop" and "shop" or "rival recruit", source)
    return C.OK, text, action, c.id, slot
  elseif c.what == "relic" then
    return C.OK, give_relic(r, c.id, added), ACTION_NONE, 0, -1
  elseif c.what == "talent" then
    local text, _, param = give_talent(r, c.id, c.uid)
    return C.OK, text, ACTION_NONE, param, -1
  elseif c.what == "bet" then
    local st = stream(r, o.node, SALT.slot)
    local odds = Rules.get().slot_odds
    local x = st:next() % math.max(odds[1] + odds[2] + odds[3] + odds[4], 1)
    if x < odds[1] then return C.OK, T("InaRogue.run_slot_lose", r.coins), ACTION_NONE, 0, -1 end
    x = x - odds[1]
    if x < odds[2] + odds[3] then
      local win = c.price * (x < odds[2] and 2 or 3)
      r.coins = r.coins + win
      r.stats.coins_earned = r.stats.coins_earned + win
      return C.OK, T("InaRogue.run_slot_win", win, r.coins), ACTION_NONE, 0, -1
    end
    local d = draw_relics(r, st, "chest", 1, nil, "event")[1]
    if not d then
      r.coins = r.coins + c.price * 3
      return C.OK, T("InaRogue.run_slot_win", c.price * 3, r.coins), ACTION_NONE, 0, -1
    end
    return C.OK, T("InaRogue.run_slot_jackpot") .. "\n" .. give_relic(r, d.key, added), ACTION_NONE, 0, -1
  elseif c.what == "choice" then
    local ch = ev.choices[c.id]
    local st = stream(r, o.node, SALT.event + c.id)
    local ok = ch.chance >= 100 or (st:next() % 100) < ch.chance
    local lines, action, param, slot = {}, ACTION_NONE, 0, -1
    if not ok then lines[#lines + 1] = T("InaRogue.run_event_fail") end
    for _, g in ipairs(ok and ch.give or ch.fail) do
      local t, a, p, s = apply_give(r, g, st, added)
      if t ~= "" then lines[#lines + 1] = t end
      if a == ACTION_PLAYER then action, param, slot = a, p, s end
    end
    if #lines == 0 then lines[1] = T("InaRogue.run_event_leave") end
    return C.OK, table.concat(lines, "\n"), action, param, slot
  end
  return C.BAD, "", ACTION_NONE, 0, -1
end

-- ---------------------------------------------------------------------------------------- the pick screen

local ICON_ATLAS = "#/menu/200_icon/02_icon_item/icon_item10.g4tx"   -- the item icon sheet of the rogue items

-- the card of a player choice: portrait, stars · position · element, level and starter cost, a badge
local function player_card(r, c)
  local param = c.id
  local i = chara.get(param) or {}
  local tier = math.max(c.tier, 1)
  local owned = owned_set()[param] == true
  local sub = T("InaRogue.run_card_player_sub", string.rep("★", tier), T("InaRogue.run_pos_" .. U.int(i.position, 0)),
    T("InaRogue.run_elem_" .. U.int(i.element, 0)))
  local lines = { T("InaRogue.run_card_level_cost", growth.get().start, St.cost(Core.cfg(), tier, 0)) }
  if owned then
    -- in the collection already: his spirits and the cost they bought; picking him gives more spirits
    local uid = Core.bank.bank_uid_of(param)
    local sp, lv, now = 0, 0, St.cost(Core.cfg(), tier, 0)
    if uid then sp, lv, now = Core.bank.spirits_of(uid) end
    lines[1] = T("InaRogue.run_card_level_cost", growth.get().start, now or 0)
    lines[#lines + 1] = T("InaRogue.run_spirits_count", sp or 0)
    if (lv or 0) > 0 then lines[#lines + 1] = T("InaRogue.run_spirits_level", lv) end
  end
  return { kind = "player", title = "", subtitle = sub, lines = lines, rarity = math.min(tier, 5), card = param }
end

local function relic_card(c)
  local d = Items.by_key(c.id)
  return { kind = "item", title = relic_name(c.id), subtitle = d and T(Items.rarity_text_key(d.rarity_key)) or "",
    desc = relic_desc(c.id), rarity = d and d.rarity or 0, icon_atlas = ICON_ATLAS, icon_sprite = d and d.icon or "" }
end

local function talent_card(c)
  local d = Pool.by_key(c.id)
  return { kind = "player", title = Pool.name(c.id), subtitle = T("InaRogue.run_card_talent_for"),
    lines = { T("InaRogue.run_card_talent_" .. (d and d.rarity_key or "common")) }, desc = Pool.desc(c.id),
    rarity = d and d.rarity or 1, card = Core.bank.bank_entry(c.uid) or 0 }
end

-- the cards of the open offer handed to the framework's pick screen (PickCards.Set): true when set. The intro's first
-- line is the title, the rest the sub title; the shop marks what is bought or too dear; a reward may be skipped.
function O.pick_cards(r)
  local PC = rawget(_G, "PickCards")
  local o = r and r.offer
  if not PC or not PC.Set or not o or #o.choices == 0 or o.kind == "slot" then return false end
  local cards, focus = {}, nil
  for i, c in ipairs(o.choices) do
    local card
    if c.what == "player" then
      card = player_card(r, c)
    elseif c.what == "relic" then
      card = relic_card(c)
    elseif c.what == "talent" then
      card = talent_card(c)
    else
      card = { kind = "text", title = T("InaRogue.run_card_option", i), desc = T("InaRogue.run_event_" .. o.key .. "_c" .. i) }
    end
    if c.taken then
      card.badge, card.disabled = T("InaRogue.run_card_bought"), true
    elseif c.price > 0 then
      card.badge = T("InaRogue.run_card_price", c.price)
      card.disabled = c.price > r.coins
    end
    if not card.disabled and focus == nil then focus = i end
    cards[#cards + 1] = card
  end
  local text = intro(r, o)
  local title, sub = text:match("^([^\n]*)\n(.*)$")
  if not title then title, sub = text, "" end
  if o.kind == "shop" then sub = (sub ~= "" and (sub .. "  ·  ") or "") .. T("InaRogue.run_card_coins", r.coins) end
  return PC.Set({ title = title, subtitle = (sub:gsub("\n", "  ")), skip = true,
    skip_text = T(o.kind == "shop" and "InaRogue.run_card_leave" or "InaRogue.run_card_skip"), focus = focus or 1,
    cards = cards })
end

function O.Offer(op_arg, a_arg)
  local op = U.int(op_arg, 0)
  if op == 4 then return open_here(U.int(a_arg, 0)) end
  if op == 5 then return O.pick_cards(run()) end
  local r = run()
  local o = r and r.offer
  if op == 0 then
    if not o then return false end
    return true, o.kind, intro(r, o), #o.choices, o.exclusive ~= false, r.coins
  elseif op == 1 then
    local i = U.int(a_arg, 0)
    local c = o and o.choices[i]
    if not c or c.taken then return false, "", 0 end
    if o.exclusive ~= false then
      for _, x in ipairs(o.choices) do
        if x.taken then return false, "", 0 end
      end
    end
    local q, param = question(r, o, c, i)
    return true, q, param
  elseif op == 2 then
    local i = U.int(a_arg, 0)
    local res = { C.NONE, "", ACTION_NONE, 0, -1 }
    local added = {}
    local code = edit("offer choice", function(x)
      local ox = x.offer
      local c = ox and ox.choices[i]
      if not c then return C.NONE end
      res = { take(x, ox, c, i, added) }
      return res[1] == C.OK and C.OK or res[1]
    end)
    if code == C.OK then
      for _, key in ipairs(added) do require("lib/rogue/collections").item_got(key, true) end
    elseif res[1] == C.OK then
      res = { C.WRITE_FAILED, "", ACTION_NONE, 0, -1 }
    end
    info(string.format("offer choice %d -> code %d action %d param %s slot %d", i, res[1], res[3], U.hex(res[4]), res[5]))
    return res[1], res[2], res[3], res[4], res[5]
  elseif op == 3 then
    local closing = ""
    edit("offer closed", function(x)
      local ox = x.offer
      if not ox then return C.NONE end
      local took = false
      for _, c in ipairs(ox.choices) do took = took or c.taken end
      if ox.kind == "event" and not took then closing = T("InaRogue.run_event_leave") end
      if ox.kind == "recruit" and not took and #ox.choices > 0 then closing = T("InaRogue.run_recruit_skipped") end
      x.offer = from_queue(x, ox.node, U.copy(ox.queue or {}))
      return C.OK
    end)
    return true, closing
  end
  return false
end

return O
