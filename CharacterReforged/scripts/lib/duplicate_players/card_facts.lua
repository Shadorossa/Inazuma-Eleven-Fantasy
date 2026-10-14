-- Character Reforged › duplicate players: what the pass knows besides the save, read from the tables the game loads
-- and the declaring mods' files (no lists in code).
--
--   cards     chara_param (served): card -> { character = chara_base (col 1), element (col 2), special_rarity (col 41) }
--   hidden    the cards a rule releases (release_cards_hidden_in: that mod's [[hide]] / [[remove]] mode = "hide" rows).
--             A hidden card's chara_param row may be deleted, so its element is its character's (the first normal
--             card of that chara_base in chara_param)
--   auras     aura_skill_config (served): the aura commands a kept card may hold in his board's aura slot (auraType 5 =
--             the generic hyper powers and the test_* rows are not auras a team entry keeps)

local CardFacts = {}

local band = bit32.band

local CHARA_PARAM = "data/common/gamedata/character/chara_param_*.cfg.bin"
local AURA_CONFIG = "data/common/gamedata/skill/aura_skill_config_*.cfg.bin"
-- chara_param columns (1-based: the 0-based column + 1): card id, chara_base, element, special rarity
local COLUMN_CARD, COLUMN_CHARACTER, COLUMN_ELEMENT, COLUMN_SPECIAL_RARITY = 1, 2, 3, 42
-- aura_skill_config columns (1-based): command id, key, aura type
local COLUMN_AURA_ID, COLUMN_AURA_KEY, COLUMN_AURA_TYPE = 1, 2, 11
local AURA_TYPE_GENERIC_POWER = 5
local TEST_AURA_PREFIX = "test_"
local FIRST_ELEMENT, LAST_ELEMENT = 1, 4

local function u32(v)
  if type(v) ~= "number" then return 0 end
  return band(v, 0xFFFFFFFF)
end

local function whole(v)
  if type(v) ~= "number" then return 0 end
  return v
end

local function read_cards()
  local rows = VRFW.table.raw(CHARA_PARAM, "CHARA_PARAM_INFO", { COLUMN_CARD, COLUMN_CHARACTER, COLUMN_ELEMENT, COLUMN_SPECIAL_RARITY })
  local cards = {}
  for order, row in ipairs(rows) do
    if row[COLUMN_CARD] ~= nil then
      local card = u32(row[COLUMN_CARD])
      if cards[card] == nil then
        cards[card] = {
          character = u32(row[COLUMN_CHARACTER]), element = whole(row[COLUMN_ELEMENT]) % 256,
          special_rarity = u32(row[COLUMN_SPECIAL_RARITY]), order = order,
        }
      end
    end
  end
  return cards
end

-- the element of each character's first normal card (chara_param order)
local function first_normal_elements(cards)
  local by_order = {}
  for card, facts in pairs(cards) do by_order[#by_order + 1] = { facts.order, card, facts } end
  table.sort(by_order, function(a, b) return a[1] < b[1] end)
  local elements = {}
  for _, entry in ipairs(by_order) do
    local facts = entry[3]
    if facts.special_rarity == 0 and facts.character ~= 0 and elements[facts.character] == nil then
      elements[facts.character] = facts.element
    end
  end
  return elements
end

-- the hidden cards of every source: card -> { element } (nil element = the character has no normal card)
local function read_hidden(cards, sources)
  local hidden = {}
  if #sources == 0 then return hidden end
  local elements = first_normal_elements(cards)
  local function add(card, character_key)
    card = u32(card)
    if card == 0 then return end
    local character = type(character_key) == "string" and VRFW.character(character_key) or nil
    hidden[card] = { element = character and elements[character] or nil }
  end
  for _, source in ipairs(sources) do
    local ok, declarations = pcall(VRFW.files.declarations, source.file)
    if not ok or type(declarations) ~= "table" then
      VRFW.warn("duplicate_players: " .. source.mod .. ":" .. source.file .. " could not be read (" .. tostring(declarations) .. "): its cards are not released")
    else
      for _, file in ipairs(declarations) do
        if file.mod == source.mod and type(file.data) == "table" then
          for _, row in ipairs(file.data.remove or {}) do
            if row.mode == "hide" then add(row.card, row.character or row.target) end
          end
          for _, row in ipairs(file.data.hide or {}) do
            if type(row.card) == "number" then add(row.card, row.target or row.character) end
            for _, card in ipairs(type(row.cards) == "table" and row.cards or {}) do add(card, row.target or row.character) end
          end
        end
      end
    end
  end
  return hidden
end

local function read_auras()
  local auras = {}
  for _, row in ipairs(VRFW.table.raw(AURA_CONFIG, "AURA_CMD_INFO", { COLUMN_AURA_ID, COLUMN_AURA_KEY, COLUMN_AURA_TYPE })) do
    local id = u32(row[COLUMN_AURA_ID])
    if id ~= 0 and auras[id] == nil then
      local aura_type = row[COLUMN_AURA_TYPE] ~= nil and (whole(row[COLUMN_AURA_TYPE]) % 256) or nil
      local key = type(row[COLUMN_AURA_KEY]) == "string" and row[COLUMN_AURA_KEY] or ""
      auras[id] = aura_type ~= AURA_TYPE_GENERIC_POWER and key:sub(1, #TEST_AURA_PREFIX) ~= TEST_AURA_PREFIX
    end
  end
  return auras
end

-- Everything the pass reads, once per copy.
function CardFacts.load(policy)
  local cards = read_cards()
  if next(cards) == nil then error("chara_param: no CHARA_PARAM_INFO rows") end
  local self = { cards = cards, hidden = read_hidden(cards, policy.hidden_card_sources), auras = read_auras() }
  return setmetatable(self, { __index = CardFacts })
end

-- element (1..4) of a card, nil when unknown
function CardFacts:element_of(card)
  local facts = self.cards[card]
  local element = facts and facts.element or (self.hidden[card] and self.hidden[card].element)
  if element and element >= FIRST_ELEMENT and element <= LAST_ELEMENT then return element end
  return nil
end

-- chara_param col 41 of a card (nil = no row)
function CardFacts:special_rarity_of(card)
  local facts = self.cards[card]
  return facts and facts.special_rarity or nil
end

-- the character (chara_base) of a card, 0 = unknown row
function CardFacts:character_of(card)
  local facts = self.cards[card]
  return facts and facts.character or 0
end

function CardFacts:is_hidden(card)
  return self.hidden[card] ~= nil
end

-- an aura command a team's aura entry may keep
function CardFacts:is_team_aura(move)
  return move ~= 0 and self.auras[move] == true
end

return CardFacts
