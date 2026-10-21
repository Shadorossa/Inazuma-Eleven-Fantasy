-- InaRogue › «Talento propio»: one passive per player in INAROGUE's save slot (docs/game/modes/inarogue-passive-system.md).
-- Reads content\rogue\talents.toml and fills the framework's signature slot tables (VRFW content\game\archetype.toml,
-- service S6), exported in mod.toml [exports] tables; every key starts with INAROGUE's save slot:
--   Passive.SlotsOff       (slot) -> 0                  the 5 retail passive slots read empty and locked
--   Passive.SignatureSlot  (slot, card) -> passive id   the player's talent in the custom passive slot (board slot 9)
--   Passive.SignatureOpen  (slot, card) -> 1            his custom passive piece counts as open (unlock = "always")
--   Passive.SignatureOnly  (slot) -> 0                  a player with no talent has an empty, closed slot 9
-- Files and the character index only: nothing calls the game.

local U = require "lib/rogue/util"
local info, warn = U.logger("rogue")

local M = {}

local KIND = "InaRogue.talents/1"
local FILE = "content/rogue/talents.toml"
local T_SLOTS_OFF, T_SIGNATURE, T_OPEN, T_ONLY =
  "Passive.SlotsOff", "Passive.SignatureSlot", "Passive.SignatureOpen", "Passive.SignatureOnly"

local BY_CARD = nil     -- [card] = { passive = id, always = bool, name = text }

-- a number, "0x…", decimal text, or a key (its crc32) -> id; nil for nothing usable
local function id_of(v)
  if type(v) == "number" then return math.floor(v) % U.TWO32 end
  if type(v) ~= "string" then return nil end
  local t = v:match("^%s*(.-)%s*$")
  if t == "" then return nil end
  local h = t:match("^0[xX](%x+)$")
  if h then return tonumber(h, 16) % U.TWO32 end
  if t:match("^%d+$") then return tonumber(t) % U.TWO32 end
  return VRFW.crc32(t) % U.TWO32
end

-- the cards of a character key (every card whose base is that character); by_base = [base] = { card, … }
local function cards_of_character(key, by_base)
  local ok, base = pcall(VRFW.character, key)
  base = (ok and type(base) == "number" and base ~= 0) and base % U.TWO32 or id_of(key)
  return base and by_base[base] or {}
end

-- [base] = { card, … } of the framework's character index
local function cards_by_base()
  local by_base = {}
  local ok, cards = pcall(VRFW.chara.cards)
  for _, c in ipairs((ok and type(cards) == "table") and cards or {}) do
    if type(c) == "table" and type(c.base) == "number" and type(c.id) == "number" then
      local b = c.base % U.TWO32
      by_base[b] = by_base[b] or {}
      by_base[b][#by_base[b] + 1] = c.id % U.TWO32
    end
  end
  return by_base
end

-- [card] = talent, from the file; card entries are put after character entries, so they win
local function read()
  local map = {}
  local ok, doc = pcall(VRFW.files.toml, FILE)
  if not ok or type(doc) ~= "table" then
    warn(FILE .. " not readable (" .. tostring(doc) .. "): no talents")
    return map
  end
  if doc.schema ~= KIND then
    warn(FILE .. ": schema is not " .. KIND .. " (no talents)")
    return map
  end
  local by_base = cards_by_base()
  local by_card, by_character = {}, {}
  for k, e in ipairs(type(doc.talent) == "table" and doc.talent or {}) do
    local where = string.format("%s [[talent]] #%d", FILE, k)
    -- one passive, or one per talent level (1 = base, up to 6 with five «Talento +1»; the last one past the end)
    local passives = {}
    for _, p in ipairs(type(e.passive) == "table" and e.passive or { e.passive }) do
      local id = id_of(p)
      if id and id ~= 0 then passives[#passives + 1] = id end
    end
    local passive = passives[1]
    local unlock = e.unlock == nil and "always" or e.unlock
    if unlock ~= "always" and unlock ~= "board" then
      warn(where .. ": unlock must be \"always\" or \"board\" (taken as \"always\")")
      unlock = "always"
    end
    local entry = { passive = passive, passives = passives, always = unlock == "always", name = tostring(e.name or ("#" .. k)) }
    if passive == nil or passive == 0 then
      warn(where .. ": no passive (left out)")
    elseif e.card ~= nil then
      local c = id_of(e.card)
      if c and c ~= 0 then by_card[#by_card + 1] = { c, entry } else warn(where .. ": card not usable (left out)") end
    elseif e.character ~= nil then
      local list = cards_of_character(e.character, by_base)
      if #list == 0 then warn(where .. ": no card of character " .. tostring(e.character) .. " (left out)") end
      for _, c in ipairs(list) do by_character[#by_character + 1] = { c, entry } end
    else
      warn(where .. ": needs `character` or `card` (left out)")
    end
  end
  for _, x in ipairs(by_character) do map[x[1]] = x[2] end
  for _, x in ipairs(by_card) do map[x[1]] = x[2] end
  return map
end

local LEVELS = {}   -- [card] = talent level of the run in progress (none = 1)

-- the passive of a talent at a level
local function passive_at(t, level)
  local list = t.passives or { t.passive }
  return list[math.min(math.max(level or 1, 1), #list)] or t.passive
end

-- fills the four exported tables for INAROGUE's save slot; `levels` = [card] = talent level (nil = keep the last)
function M.fill(levels)
  -- a call without levels (start, slot load) reads the file again; a level change reuses the talents read
  if levels then LEVELS = levels end
  local map = levels and BY_CARD or nil
  if map == nil then
    local ok, m = pcall(read)
    if not ok then
      warn("talents: " .. tostring(m) .. " (no talents)")
      m = {}
    end
    map = m
  end
  local slot = U.ROGUE_SLOT
  local signature, open, n_cards = {}, {}, 0
  for card, t in pairs(map) do
    signature[#signature + 1] = { { slot, card }, passive_at(t, LEVELS[card]) }
    if t.always then open[#open + 1] = { { slot, card }, 1 } end
    n_cards = n_cards + 1
  end
  local okw, e = pcall(function()
    VRFW.native.table_replace(T_SIGNATURE, nil, signature)
    VRFW.native.table_replace(T_OPEN, nil, open)
    VRFW.native.table_replace(T_ONLY, nil, { { { slot }, 0 } })
    VRFW.native.table_replace(T_SLOTS_OFF, nil, { { { slot }, 0 } })
  end)
  if not okw then
    warn("talents: tables not filled: " .. tostring(e))
    return false
  end
  BY_CARD = map
  if not levels then info(string.format("talents: save slot %d keeps only the talent slot; %d card(s) with a talent", slot, n_cards)) end
  return true
end

-- the talent of a card in INAROGUE: passive id at its run level (0 = none), always open, talent name, level
function M.of_card(card)
  card = (tonumber(card) or 0) % U.TWO32
  local t = BY_CARD and BY_CARD[card]
  if not t then return 0, false, "", 0 end
  local level = LEVELS[card] or 1
  return passive_at(t, level), t.always, t.name, level
end

-- the card has a talent
function M.has(card)
  return BY_CARD ~= nil and BY_CARD[(tonumber(card) or 0) % U.TWO32] ~= nil
end

return M
