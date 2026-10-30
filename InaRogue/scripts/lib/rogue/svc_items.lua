-- InaRogue › INAROGUE: the rogue items of the run and the talent levels (docs/game/modes/inarogue-passive-system.md
-- §2.3-2.7). Catalogue lib/rogue/items.lua; the run keeps them (rogue_run.json `items`, `talents`). The run's match
-- effects reach the players through the coach's native table (svc_meta.coach_sync); the outside effects through the
-- reward multipliers. On every run load / save this part publishes the team's archetype (state keys InaRogue.archetype
-- 1..n of content/rogue/archetypes.toml / InaRogue.archetype_rank 1-5, 0 = none) and the talent levels (lib/rogue/talents.lua).
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_INAROGUE_RL_ITEM_INFO | – | count, max slots, archetype (0 none, 1..n), rank, catalogue size |
-- | CMND_INAROGUE_RL_ITEM_GET | i | ok, key, level, max level, rarity (1 common, 2 rare, 3 epic, 4 legendary: the [[rarity]] order), upgrade cost (-1 at the maximum), sell value, first archetype, scope, matches left (a piece lasting N matches) |
-- | CMND_INAROGUE_RL_ITEM_CATALOGUE | i | ok, key, kind, rarity (as ITEM_GET), price, max level, first archetype |
-- | CMND_INAROGUE_RL_ITEM_ADD | key | code, index (0-based) / points given for a duplicate |
-- | CMND_INAROGUE_RL_ITEM_SELL | i | code, points |
-- | CMND_INAROGUE_RL_ITEM_UPGRADE | i, paid | code, level (the menu took `paid` Rogue points from the bag) |
-- | CMND_INAROGUE_RL_TALENT_UP | uid | code, level (a «Talento +1» used on a run player) |
--
-- Prices and upgrade costs are the run items' shop_cost_multiplier × the catalogue's (lib/rogue/svc_blocks.lua shop_mult).

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local R = require "lib/rogue/run"
local Items = require "lib/rogue/items"
local talents = require "lib/rogue/talents"
local E = require "lib/rogue/effects"
local info, warn = U.logger("rogue items")

local S = {}

S.CODE = { OK = 0, NO_RUN = 1, BAD_INDEX = 2, WRITE_FAILED = 5, FULL = 8, DUPLICATE = 9, UNKNOWN = 10,
  MAX_LEVEL = 11, NOT_PAID = 12, NO_TALENT = 13, NOT_IN_RUN = 14 }
local C = S.CODE

local KEY_ARCHETYPE, KEY_RANK = "InaRogue.archetype", "InaRogue.archetype_rank"

local function run() return Core.run.run_hdls() end

-- a Shop price of the run (shop_cost_multiplier of its items)
local function shop_price(r, n)
  if not n or not r then return n end
  return E.scaled(n, require("lib/rogue/svc_blocks").shop_mult(r))
end

local function find(items, key)
  for i, o in ipairs(items or {}) do
    if o.key == key then return i end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------- run listener

local published = nil

local function publish(r)
  local lead, rank = 0, 0
  if r then lead, rank = Items.archetype(r.items) end
  local sig = lead .. "/" .. rank
  if sig ~= published then
    pcall(VRFW.state.set, KEY_ARCHETYPE, lead)
    pcall(VRFW.state.set, KEY_RANK, rank)
    published = sig
    info(string.format("archetype %s rank %d (%d item(s))", lead > 0 and Items.archetype_keys()[lead] or "none", rank,
      r and #r.items or 0))
  end
  -- the talent levels of the run's players, by card
  local levels = {}
  for uid, level in pairs(r and r.talents or {}) do
    local param = Core.bank.bank_entry(uid)
    if param then
      local card = param % U.TWO32
      if level > (levels[card] or 0) then levels[card] = level end
    end
  end
  -- the talents the run gave (content/rogue/talent_pool.toml): in the custom slot of their players
  talents.set_run(require("lib/rogue/talent_pool").run_map(r, function(uid) return (Core.bank.bank_entry(uid)) end))
  talents.fill(levels)
end

Core.on_run(publish)

-- ---------------------------------------------------------------------------------------- commands

function S.Info()
  local k = Items.catalogue()
  local r = run()
  local items = r and r.items or {}
  local lead, rank = Items.archetype(items)
  return #items, k.max_slots, lead, rank, #k.list
end

function S.Get(i_arg)
  local r = run()
  local o = r and r.items[U.int(i_arg, -1) + 1]
  if not o then return false end
  local d = Items.by_key(o.key)
  if not d then return true, o.key, o.level, o.level, 0, -1, 0, 0, "" end
  local cost = shop_price(r, Items.upgrade_cost(d, o.level))
  return true, o.key, o.level, d.max_level, d.rarity, cost or -1, Items.sell_value(d, o.level), d.archetypes[1] or 0, d.scope,
    o.matches_left or 0
end

function S.Catalogue(i_arg)
  local d = Items.catalogue().list[U.int(i_arg, -1) + 1]
  if not d then return false end
  return true, d.key, d.kind, d.rarity, shop_price(run(), d.price), d.max_level, d.archetypes[1] or 0
end

-- an item into the inventory: code, index; an owned one is turned into Rogue points (half its price)
function S.Add(key)
  key = type(key) == "string" and key or ""
  local d = Items.by_key(key)
  if not d or d.kind ~= "passive" then return C.UNKNOWN, -1 end
  local r = run()
  if not r then return C.NO_RUN, -1 end
  if find(r.items, key) then
    local points = Core.meta.earn_bonus(math.floor(d.price / 2), "duplicate item " .. key)
    info(string.format("item %s owned already: %d Rogue points", key, points))
    return C.DUPLICATE, points
  end
  if #r.items >= Items.catalogue().max_slots then return C.FULL, -1 end
  local index = -1
  local code = Core.run.edit_run("item " .. key .. " added", function(run_)
    run_.items[#run_.items + 1] = Items.new_owned(d)
    index = #run_.items - 1
    return C.OK
  end)
  if code == C.OK then require("lib/rogue/collections").item_got(key, true) end
  return code, index
end

function S.Sell(i_arg)
  local i = U.int(i_arg, -1) + 1
  local value, key = 0, ""
  local code = Core.run.edit_run("item sold", function(r)
    local o = r.items[i]
    if not o then return C.BAD_INDEX end
    local d = Items.by_key(o.key)
    value = d and Items.sell_value(d, o.level) or 0
    key = o.key
    table.remove(r.items, i)
    return C.OK
  end)
  if code ~= C.OK then return code, 0 end
  local points = Core.meta.earn_bonus(value, "item " .. key .. " sold")
  return code, points
end

-- the Shop's «Mejorar»: the menu took `paid` Rogue points from the bag before calling
function S.Upgrade(i_arg, paid_arg)
  local i = U.int(i_arg, -1) + 1
  local paid = U.int(paid_arg, 0)
  local level = 0
  local code = Core.run.edit_run("item upgraded", function(r)
    local o = r.items[i]
    if not o then return C.BAD_INDEX end
    local d = Items.by_key(o.key)
    if not d then return C.UNKNOWN end
    local cost = shop_price(r, Items.upgrade_cost(d, o.level))
    if not cost then return C.MAX_LEVEL end
    if paid < cost then return C.NOT_PAID end
    o.level = o.level + 1
    level = o.level
    return C.OK
  end)
  info(string.format("item %d upgrade (paid %d) -> code %d, level %d", i - 1, paid, code, level))
  return code, level
end

-- a «Talento +1» used on a run player (bank uid): his talent level + 1 (at most items.TALENT_MAX_LEVEL)
function S.TalentUp(uid_arg)
  local uid = U.int(uid_arg, 0)
  local level = 0
  local code = Core.run.edit_run("talent up", function(r)
    if not U.contains(R.player_uids(r), uid) then return C.NOT_IN_RUN end
    local param = Core.bank.bank_entry(uid)
    if not param or not talents.has(param) then return C.NO_TALENT end
    local now = r.talents[uid] or 1
    if now >= Items.TALENT_MAX_LEVEL then return C.MAX_LEVEL end
    r.talents[uid] = now + 1
    level = now + 1
    return C.OK
  end)
  info(string.format("talent up uid %d -> code %d, level %d", uid, code, level))
  return code, level
end

return S
