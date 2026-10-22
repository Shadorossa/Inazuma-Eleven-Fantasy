-- Gacha service, script side (game Lua side: assets\lua\menu\_all\74_gacha.lua; docs/framework/gacha.md).
-- Declarations: every active mod's content\gacha\*.toml (`VRFW.gacha/1`, keys content\types\gacha.toml): [[VRFW.GachaPool]]
-- (a pool, its question, its draw tint, its cost, the Chronicle board node that opens it) and [[VRFW.GachaAdd]] (cards
-- another mod adds to an extensible pool). A card is a chara_param id (0x…) or a mod's character <mod>.<name> (its card:
-- the id space's number of <mod>.<name>#card).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_GACHA_OF_PIECE | pieceId | the pool index (1-based) of the board node with that piece, 0 = none |
-- | CMND_VRFW_GACHA_POOL | index | key, question text id, tint r, g, b (0-255), cost item, cost count, level, card count, draw event id |
-- | CMND_VRFW_GACHA_CARDS | index | the pool's cards (chara_param ids) |
-- | CMND_VRFW_GACHA_CANDIDATES | index | the cards a draw picks from now: those whose character has no player in the club
--   (VRFW.chara.owned_of_character, the drop-rate list's owned-player rule: the window and the draw list the same) |
-- | CMND_VRFW_GACHA_OF_GAME | game id | the pool index of the board node whose game that is (its drop-rate list), 0 = none |
-- | CMND_VRFW_GACHA_TEXTS | index | command text id, banner image id (0 = none) |
-- | CMND_VRFW_GACHA_OBTAINED | card, i | the obtained screen's page (pose row source): i = 0 the header, 1 the drawn player |

Gacha = Gacha or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("gacha:", ...) end
local function warn(...) VRFW.warn("gacha:", ...) end

local POOLS = nil        -- { { key, mod, question, tint = {r, g, b}, cost_item, cost_count, level, cards = { id … }, piece } … }
local BY_PIECE = {}      -- pieceId -> pool index
local BY_GAME = {}       -- the node's game id -> pool index

local function u32(v)
  v = tonumber(v) or 0
  return math.floor(v) % 4294967296
end

local function crc(s)
  local f = VRFW.crc32 or (VRFW.ui and VRFW.ui.crc32)
  return f(s) % 4294967296
end

-- "#rrggbb" -> r, g, b (nil when it is not one)
local function rgb(text)
  local r, g, b = tostring(text or ""):match("^%s*#(%x%x)(%x%x)(%x%x)%s*$")
  if not r then return nil end
  return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

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
      local r, g, b = rgb(v.tint)
      if not r then
        warn(where .. ": pool " .. d.key .. ": tint `" .. tostring(v.tint) .. "` is not #rrggbb: white")
        r, g, b = 255, 255, 255
      end
      local pool = by_key[d.key]
      if pool == nil then
        pool = { key = d.key, mod = d.mod, cards = {}, seen = {} }
        POOLS[#POOLS + 1] = pool
        by_key[d.key] = pool
      end
      pool.question = D.id_of(v.question) or 0
      pool.tint = { r, g, b }
      pool.cost_item = (v.cost_item ~= "" and D.id_of(v.cost_item)) or 0
      pool.cost_count = pool.cost_item ~= 0 and v.cost_count or 0
      pool.level = v.level
      pool.extensible = v.extensible
      pool.node = v.node
      pool.event = (v.event ~= "" and crc(v.event)) or 0
      pool.command = D.id_of(v.command) or 0
      pool.banner = (v.banner ~= "" and D.id_of(v.banner)) or 0
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
    info(string.format("pool %s: %d card(s), node %s, event %s, cost %d", pool.key, #pool.cards,
      tostring(pool.node or "-"), pool.event ~= 0 and string.format("0x%08X", pool.event) or "-", pool.cost_count))
  end
  return POOLS
end

-- CMND_VRFW_GACHA_OF_PIECE(pieceId) -> pool index, 0 = none
function Gacha.OfPiece(piece)
  load_pools()
  return BY_PIECE[u32(piece)] or 0
end

-- CMND_VRFW_GACHA_POOL(index) -> key, question, r, g, b, cost item, cost count, level, card count, draw event id
function Gacha.Pool(i)
  local p = load_pools()[math.floor(tonumber(i) or 0)]
  if not p then return nil end
  return p.key, p.question, p.tint[1], p.tint[2], p.tint[3], p.cost_item, p.cost_count, p.level, #p.cards, p.event
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

-- CMND_VRFW_GACHA_TEXTS(index) -> command text id, banner image id
function Gacha.Texts(i)
  local p = load_pools()[math.floor(tonumber(i) or 0)]
  if not p then return nil end
  return p.command, p.banner
end

-- CMND_VRFW_GACHA_OBTAINED(card, i): the obtained screen's page (content\pose_rows\gacha_obtained.toml, the pose row
-- screen's source): i = 0 the header, i = 1 the drawn player (his name and position come from the screen)
function Gacha.ObtainedPage(card, i)
  card = u32(card)
  i = math.floor(tonumber(i) or 0)
  if card == 0 then return nil end
  if i == 0 then
    return { count = 1, focus = 1 }
  end
  if i ~= 1 then return nil end
  return { label = crc("vrfw_gacha_obtained_tag"), title = crc("vrfw_gacha_obtained_title"),
           info = crc("vrfw_gacha_obtained_info"), models = { { card = card, text = "" } } }
end

pcall(load_pools)
