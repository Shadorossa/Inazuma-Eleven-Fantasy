-- Recruit service, script side (game Lua side: assets/lua/menu/_all/62_recruit.lua).
--   CMND_VRFW_RECRUIT_CLUB() -> { total, element = { [1..5] = n }, position = { [1..4] = n } }: saved club characters counted by card element
--     (chara_param col 2: 1 wind, 2 forest, 3 fire, 4 mountain, 5 void) and main position (col 3: 1 GK, 2 FW, 3 MF, 4 DF)
--   CMND_VRFW_RECRUIT_HOLDERS(card, ...) -> { {handle, param, level, busy}, ... }: the saved club players of those cards
--   CMND_VRFW_RECRUIT_GAME_STADIUM(game) -> map crc (0 = none): a match row's own stadium (SOCCER_GAME_INFO col 4)
--   career counters (per save slot, read with CMND_VRFW_SAVE_GET), counted from first run:
--     "stats.matches_won"  matches the user's side ends ahead
--     "stats.goals"        goals of the user's side

Recruit = Recruit or {}

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local PARAM = nil   -- card -> { element, position }
local GAME_STADIUM = nil   -- match row id -> its stadium's map crc

-- CMND_VRFW_RECRUIT_GAME_STADIUM(game) -> the stadium a match row is played at in the game data (0 = unknown row)
function Recruit.GameStadium(game)
  if GAME_STADIUM == nil then
    GAME_STADIUM = {}
    local ok, rows = pcall(VRFW.table.rows, "soccer/soccer_game_info")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local id = u32(r.id or r[1])
        if id ~= 0 then GAME_STADIUM[id] = u32(r.stadium_map or r[4]) end
      end
    else
      VRFW.warn("recruit: soccer_game_info is not readable (" .. tostring(rows) .. "): no match row stadium")
    end
  end
  return GAME_STADIUM[u32(game)] or 0
end

-- a card's element and main position, from the framework's character index (VRFW.chara), cached per card
local function params()
  if PARAM then return PARAM end
  PARAM = setmetatable({}, { __index = function(t, card)
    local ok, c = pcall(VRFW.chara.card, card)
    if not ok or type(c) ~= "table" then return nil end
    local v = { tonumber(c.element) or 0, tonumber(c.position) or 0 }
    rawset(t, card, v)
    return v
  end })
  return PARAM
end

function Recruit.Club()
  local out = { total = 0, element = { 0, 0, 0, 0, 0 }, position = { 0, 0, 0, 0 } }
  local ok, saved = pcall(VRFW.chara.saved)
  if not ok or type(saved) ~= "table" then
    VRFW.warn("recruit: the club is not readable (" .. tostring(saved) .. ")")
    return out
  end
  local P = params()
  for _, c in ipairs(saved) do
    local p = P[u32(c.param)]
    out.total = out.total + 1
    if p then
      if p[1] >= 1 and p[1] <= 5 then out.element[p[1]] = out.element[p[1]] + 1 end
      if p[2] >= 1 and p[2] <= 4 then out.position[p[2]] = out.position[p[2]] + 1 end
    end
  end
  return out
end

-- ---- holders: the club players of some cards (a level requirement, a release)

-- a miximax fusion holds the player (as its base or its partner): such a player is never released
local function in_fusion(handle)
  if not (VRFW.miximax and VRFW.miximax.call) then return false end
  for _, op in ipairs({ "fusion_of", "partner_fusion" }) do
    local ok, f = pcall(VRFW.miximax.call, { op = op, hdl = handle })
    if ok and type(f) == "table" and type(f.f) == "table" then return true end
  end
  return false
end

-- CMND_VRFW_RECRUIT_HOLDERS(card, ...) -> { {handle, param, level, busy}, ... }: the saved club players (container 0)
-- of those cards; busy = true while a miximax fusion holds him
function Recruit.Holders(...)
  local want = {}
  for _, c in ipairs({ ... }) do want[u32(c)] = true end
  local out = {}
  local ok, saved = pcall(VRFW.chara.saved)
  for _, k in ipairs(ok and type(saved) == "table" and saved or {}) do
    local h = u32(k.handle)
    if math.floor(h / 4096) % 16 == 0 and want[u32(k.param)] then
      out[#out + 1] = { handle = h, param = u32(k.param), level = tonumber(k.level) or 1, busy = in_fusion(h) }
    end
  end
  return out
end

-- ---- save adjust «clear_season» (content\save_adjust\recruit.toml, docs/framework/save-adjust.md)
-- Signings made before VRFW 2.66 kept the season bit CMND_ADD_PARTY leaves on the record (the bank showed them as
-- «Jugador de temporada»). The action clears it on the records the recruit paths made, and only those: a normal-bank
-- player (attribute 0x400) with the season bit, joined by the recruit service's source (addPartySource 2 scouted, 4
-- signed), whose rarity is not the retail season rarity 9, not a story player (0x80) nor an INAROGUE one (0x10000000).

local ATTRIBUTE_SEASON, ATTRIBUTE_NORMAL_BANK, ATTRIBUTE_STORY, ATTRIBUTE_ROGUE = 0x100000, 0x400, 0x80, 0x10000000
local SEASON_RARITY = 9
local RECRUIT_SOURCES = { [2] = true, [4] = true }

local function has_bit(v, bit) return math.floor(v / bit) % 2 == 1 end

local function word(s, i)
  local a, b, c, d = string.byte(s, i * 4 + 1, i * 4 + 4)
  return a + b * 0x100 + c * 0x10000 + d * 0x1000000
end

local function leaf(t, base, name)
  local g = t:get(base .. "." .. name)
  if g and g.kind == "leaf" then return t:bytes(base .. "." .. name) end
  return nil
end

-- the players table of the save: block5 (m_Permanent).m_saveHumanP, nil when absent
local function humans_of(t)
  local base = "block5"
  local g = t:get(base .. ".m_Permanent")
  if g and g.kind == "struct" then base = base .. ".m_Permanent" end
  local h = base .. ".m_saveHumanP"
  g = t:get(h)
  if g and g.kind == "struct" then return h end
  return nil
end

Recruit.SaveAdjust = Recruit.SaveAdjust or {}

function Recruit.SaveAdjust.can_clear_season() return true end

function Recruit.SaveAdjust.clear_season(t, ev)
  local humans = humans_of(t)
  if not humans then return { error = "m_saveHumanP not found" } end
  local handles, attributes = leaf(t, humans, "handle"), leaf(t, humans, "attribute")
  local rarities, sources = leaf(t, humans, "charaRarity"), leaf(t, humans, "addPartySource")
  if not (handles and attributes and rarities and sources) then
    return { error = "m_saveHumanP handle / attribute / charaRarity / addPartySource not found" }
  end
  local count = math.floor(#handles / 4)
  if #attributes ~= #handles or #rarities ~= #handles or #sources ~= count then
    return { error = "m_saveHumanP columns of different lengths" }
  end
  local cards = leaf(t, humans, "param_id_crc")
  local out, cleared, kept = {}, 0, 0
  for i = 0, count - 1 do
    local handle, attribute = word(handles, i), word(attributes, i)
    if handle ~= 0 and has_bit(attribute, ATTRIBUTE_SEASON) then
      local rarity, source = word(rarities, i), string.byte(sources, i + 1)
      if has_bit(attribute, ATTRIBUTE_NORMAL_BANK) and not has_bit(attribute, ATTRIBUTE_STORY)
          and not has_bit(attribute, ATTRIBUTE_ROGUE) and rarity ~= SEASON_RARITY and RECRUIT_SOURCES[source] then
        out[#out + 1] = { i, attribute - ATTRIBUTE_SEASON }
        VRFW.log(string.format("save adjust: clear_season: 0x%08X card 0x%08X rarity %d source %d attribute 0x%X -> 0x%X",
          handle, cards and word(cards, i) or 0, rarity, source, attribute, attribute - ATTRIBUTE_SEASON))
      else
        kept = kept + 1
      end
    end
  end
  if #out > 0 then
    local parts, last = {}, 0
    for _, e in ipairs(out) do
      parts[#parts + 1] = attributes:sub(last * 4 + 1, e[1] * 4)
      local v = e[2]
      parts[#parts + 1] = string.char(v % 256, math.floor(v / 0x100) % 256, math.floor(v / 0x10000) % 256,
        math.floor(v / 0x1000000) % 256)
      last = e[1] + 1
    end
    parts[#parts + 1] = attributes:sub(last * 4 + 1)
    t:set_bytes(humans .. ".attribute", table.concat(parts))
    cleared = #out
  end
  local log = string.format("clear_season: %d recruited player(s) cleared, %d other season record(s) kept", cleared, kept)
  VRFW.log("save adjust: " .. log)
  return { count = cleared, log = log }
end

-- ---- career counters

local match = nil   -- { user, rival } goals of the match being played

local function bump(key, n)
  local v = tonumber(VRFW.save.get(key, 0)) or 0
  VRFW.save.set(key, v + n)
end

VRFW.on("match_start", function(ev) match = { user = 0, rival = 0 } end)

VRFW.on("goal:user", function(ev)
  if match then match.user = match.user + 1 end
  bump("stats.goals", 1)
end)

VRFW.on("goal:rival", function(ev)
  if match then match.rival = match.rival + 1 end
end)

VRFW.on("match_end", function(ev)
  if match and match.user > match.rival then
    bump("stats.matches_won", 1)
  end
  match = nil
end)
