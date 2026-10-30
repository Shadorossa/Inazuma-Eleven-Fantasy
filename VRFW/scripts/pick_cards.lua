-- Pick cards, script side (game Lua side: the screen vrfw_pick_cards_menu, graft pick_cards, and assets\lua\menu\_all\
-- 83_pick_cards.lua; docs/framework/pick-cards.md). A «pick 1 of N» reward screen: cards side by side (a player, an
-- item or plain text each) and an optional skip. Mechanism only: a mod's script sets the cards, the mod's menu opens
-- the screen with VRFW_PickCards.Show and gets the picked card's number back.
--
--   PickCards.Set(spec)   the cards the next screen shows (replaces any earlier set):
--     spec.title, spec.subtitle   texts (already in the game's language)
--     spec.skip                   true = a «skip» choice (the pick 0); spec.skip_text = its label ("" = the framework's)
--     spec.focus                  the card focused at open (default 1)
--     spec.cards = { card, … }    1..12 cards; each:
--       kind       "player" | "item" | "text"
--       title      its name ("" on a player card = the game's name of `card`)
--       subtitle   one short line under the name
--       lines      up to 3 short lines (stats, position, cost…)
--       desc       a longer text, wrapped on the card
--       badge      a short text at the bottom (a price, «owned»…)
--       rarity     0..5: the card's frame colour (0 plain)
--       card       a chara_param id: the player's portrait (kind "player")
--       icon_atlas, icon_sprite   an icon of the mod's atlas (kind "item")
--       disabled   true = shown greyed; picking it plays the error sound
--   PickCards.Clear()
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_PICK_CARDS | 0 | { title, subtitle, skip, skip_text, focus, count } (nothing = no set) |
-- | | i (1..count) | card i (the fields above) |

PickCards = PickCards or {}

require "VRFW/lib/basics"
local info = VRFW.logger("pick_cards")

local MAX_CARDS, MAX_LINES = 12, 3
local current = nil

local function str(v) return type(v) == "string" and v or "" end

local function clean_card(c)
  if type(c) ~= "table" then return nil end
  local kind = c.kind
  if kind ~= "player" and kind ~= "item" and kind ~= "text" then kind = "text" end
  local lines = {}
  for i, l in ipairs(type(c.lines) == "table" and c.lines or {}) do
    if i > MAX_LINES then break end
    lines[#lines + 1] = str(l)
  end
  local rarity = math.floor(tonumber(c.rarity) or 0)
  if rarity < 0 or rarity > 5 then rarity = 0 end
  return { kind = kind, title = str(c.title), subtitle = str(c.subtitle), lines = lines, desc = str(c.desc),
    badge = str(c.badge), rarity = rarity, card = math.floor(tonumber(c.card) or 0) % 4294967296,
    icon_atlas = str(c.icon_atlas), icon_sprite = str(c.icon_sprite), disabled = c.disabled == true }
end

function PickCards.Set(spec)
  if type(spec) ~= "table" then
    current = nil
    return false
  end
  local cards = {}
  for _, c in ipairs(type(spec.cards) == "table" and spec.cards or {}) do
    if #cards >= MAX_CARDS then break end
    local x = clean_card(c)
    if x then cards[#cards + 1] = x end
  end
  if #cards == 0 then
    current = nil
    return false
  end
  local focus = math.floor(tonumber(spec.focus) or 1)
  if focus < 1 or focus > #cards then focus = 1 end
  current = { title = str(spec.title), subtitle = str(spec.subtitle), skip = spec.skip == true,
    skip_text = str(spec.skip_text), focus = focus, cards = cards }
  info(string.format("set: %d card(s), skip %s", #cards, tostring(current.skip)))
  return true
end

function PickCards.Clear() current = nil end

function PickCards.Get(i)
  if current == nil then return nil end
  i = math.floor(tonumber(i) or 0)
  if i == 0 then
    return { title = current.title, subtitle = current.subtitle, skip = current.skip, skip_text = current.skip_text,
      focus = current.focus, count = #current.cards }
  end
  return current.cards[i]
end
