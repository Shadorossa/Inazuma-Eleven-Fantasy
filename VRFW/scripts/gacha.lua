-- Gacha service, script side (game Lua side: assets\lua\menu\_all\74_gacha.lua; docs/framework/gacha.md).
-- Declarations: every active mod's content\gacha\*.toml (`VRFW.gacha/1`, keys content\types\gacha.toml): [[VRFW.GachaPool]]
-- (a pool, its cost, its level, the Chronicle board node that opens it) and [[VRFW.GachaAdd]] (cards
-- another mod adds to an extensible pool). A card is a chara_param id (0x…) or a mod's character <mod>.<name> (its card:
-- the id space's number of <mod>.<name>#card).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_GACHA_OF_PIECE | pieceId | the pool index (1-based) of the board node with that piece, 0 = none |
-- | CMND_VRFW_GACHA_POOL | index | key, cost item, cost count, level, card count |
-- | CMND_VRFW_GACHA_CARDS | index | the pool's cards (chara_param ids) |
-- | CMND_VRFW_GACHA_CANDIDATES | index | the cards a draw picks from now: those whose character has no player in the club
--   (VRFW.chara.owned_of_character, the drop-rate list's owned-player rule: the window and the draw list the same) |
-- | CMND_VRFW_GACHA_OF_GAME | game id | the pool index of the board node whose game that is (its drop-rate list), 0 = none |
-- | CMND_VRFW_GACHA_TEXTS | index | command text id, banner image id (0 = none), no-cost text id, count text id (0 = none) |

Gacha = Gacha or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("gacha")

local POOLS = nil        -- { { key, mod, cost_item, cost_count, level, cards = { id … }, piece } … }
local BY_PIECE = {}      -- pieceId -> pool index
local BY_GAME = {}       -- the node's game id -> pool index

local Id = require "lib/ids"
local u32 = Id.u32

local crc = VRFW.crc32

-- a card: 0x… / decimal = that chara_param id; <mod>.<name> = that mod character's card (its id space number)
local function card_of(text)
  if type(text) ~= "string" then return nil end
  if text:match("^%s*0[xX]%x+%s*$") or text:match("^%s*%d+%s*$") then return D.id_of(text) end
  if text:match("^[%w_]+%.[%w_]+$") then
    local ok, n = pcall(VRFW.ids.resolve, "chara", text .. "#card")
    if ok and type(n) == "number" then return u32(n) end
    return nil
  end
  return nil
end

local function add_cards(pool, list, where)
  local seen = pool.seen
  local added, missing = 0, {}
  for _, c in ipairs(list or {}) do
    local id = card_of(c)
    if not id or id == 0 then
      missing[#missing + 1] = tostring(c)
    elseif not seen[id] then
      seen[id] = true
      pool.cards[#pool.cards + 1] = id
      added = added + 1
    end
  end
  if #missing > 0 then
    warn(string.format("%s: %d card(s) not found (left out): %s", where, #missing, table.concat(missing, ", ")))
  end
  return added
end

local function load_pools()
  if POOLS ~= nil then return POOLS end
  POOLS = {}
  local schema, why = D.schema("gacha")
  if not schema then
    warn(why .. ": no gacha pool")
    return POOLS
  end
  local by_key, adds = {}, {}
  for _, d in ipairs(D.load(schema, warn)) do
    local v = d.v
    local where = string.format("mods/%s/%s", tostring(d.mod), tostring(d.file))
    if d.entry == "GachaPool" then
      local pool = by_key[d.key]
      if pool == nil then
        pool = { key = d.key, mod = d.mod, cards = {}, seen = {} }
        POOLS[#POOLS + 1] = pool
        by_key[d.key] = pool
      end
      pool.cost_item = (v.cost_item ~= "" and D.id_of(v.cost_item)) or 0
      pool.cost_count = pool.cost_item ~= 0 and v.cost_count or 0
      pool.level = v.level
      pool.extensible = v.extensible
      pool.node = v.node
      pool.command = D.id_of(v.command) or 0
      pool.banner = (v.banner ~= "" and D.id_of(v.banner)) or 0
      pool.no_cost_text = D.id_of(v.no_cost_text) or 0
      pool.count_text = (v.count_text ~= "" and D.id_of(v.count_text)) or 0
      add_cards(pool, v.cards, where .. ": pool " .. d.key)
    elseif d.entry == "GachaAdd" then
      adds[#adds + 1] = { d = d, where = where }
    end
  end
  for _, a in ipairs(adds) do
    local key = a.d.v.pool
    local pool = by_key[key]
    if pool == nil then
      info(a.where .. ": pool " .. key .. " is not declared (its mod is off): nothing added")
    elseif not pool.extensible then
      warn(a.where .. ": pool " .. key .. " is not extensible: nothing added")
    else
      local n = add_cards(pool, a.d.v.cards, a.where .. ": pool " .. key)
      info(string.format("%s adds %d card(s) to %s", tostring(a.d.mod), n, key))
    end
  end
  for i, pool in ipairs(POOLS) do
    pool.seen = nil
    if pool.node and pool.node ~= "" then
      pool.piece = crc("evt_rn_piece_" .. pool.node)
      BY_PIECE[pool.piece] = i
      BY_GAME[crc("evt_rn_" .. pool.node)] = i
    end
    info(string.format("pool %s: %d card(s), node %s, level %d, cost %d", pool.key, #pool.cards,
      tostring(pool.node or "-"), pool.level, pool.cost_count))
  end
  return POOLS
end

-- CMND_VRFW_GACHA_OF_PIECE(pieceId) -> pool index, 0 = none
function Gacha.OfPiece(piece)
  load_pools()
  return BY_PIECE[u32(piece)] or 0
end

-- CMND_VRFW_GACHA_POOL(index) -> key, cost item, cost count, level, card count
function Gacha.Pool(i)
  local p = load_pools()[math.floor(tonumber(i) or 0)]
  if not p then return nil end
  return p.key, p.cost_item, p.cost_count, p.level, #p.cards
end

-- CMND_VRFW_GACHA_CARDS(index) -> card, card, …
function Gacha.Cards(i)
  local p = load_pools()[math.floor(tonumber(i) or 0)]
  if not p then return nil end
  return table.unpack(p.cards)
end

-- CMND_VRFW_GACHA_CANDIDATES(index) -> the cards whose character has no player in the club
function Gacha.Candidates(i)
  local p = load_pools()[math.floor(tonumber(i) or 0)]
  if not p then return nil end
  local out = {}
  for _, c in ipairs(p.cards) do
    local ok, n = pcall(VRFW.chara.owned_of_character, c)
    if not ok or (tonumber(n) or 0) == 0 then out[#out + 1] = c end
  end
  return table.unpack(out)
end

-- CMND_VRFW_GACHA_OF_GAME(game id) -> the pool index of the node playing that game (0 = none)
function Gacha.OfGame(game)
  load_pools()
  return BY_GAME[u32(game)] or 0
end

-- CMND_VRFW_GACHA_TEXTS(index) -> command text id, banner image id, no-cost text id, count text id
function Gacha.Texts(i)
  local p = load_pools()[math.floor(tonumber(i) or 0)]
  if not p then return nil end
  return p.command, p.banner, p.no_cost_text, p.count_text
end

pcall(load_pools)
