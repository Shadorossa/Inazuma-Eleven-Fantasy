-- No More Rarities › the spirit purge of a duplicated save (owner decision 2026-10-14: with No More Rarities on, a
-- save duplicated through the VR-Framework's slot screen loses every player spirit in the NEW copy, because the spirit
-- screens and their entries no longer exist; the source save is never touched). Design and RE:
-- docs/game/characters/rarity-removal.md §9.1.
--
-- Pure: a save tree in (VRFW.savetree, docs/framework/native.md §3.2), the tree patched in place and a report out; no
-- other VRFW call (the entry script scripts\spirit_purge.lua decides when it runs; a Rust test runs this file on a
-- synthetic save: crates/vr-core/src/script/api_savetree.rs).
--
-- Where the spirits live (nie.exe v7.1.2, reflection of CGDDSpiritStatus, docs/formats/save.md §5.3): save block 0x12,
-- record m_Permanent = { normalSpiritInfo[6600], heroSpiritInfo[500], elementSpiritInfo, tokenSpiritInfo,
-- basaraSpiritInfo[250], seasonalNormalSpiritInfo[120], getOrderCount, sortType, isLockTradeItem }. A player spirit
-- entry = { handle, getOrder, reserve, charaParamId, stockNum, usedStockNum, newFlag }; a free entry is all zeros (the
-- game's own reset writes zeros; there is no count field: the game scans the arrays). Their «new» marks per character:
-- block 0x02 (CGDDFlagStatus) m_Permanent.m_globalChrSpirit{Normal,Growing,Advanced,Top,Legendary,Hero,Basara}NewFlag.
--
-- What goes: every entry of the four PLAYER spirit lists (normal, hero = Ídolo, basara = Diamante, seasonal normal)
-- emptied (all its leaves to zero, as Character Reforged / Inazuma Fantasy empty a released card's entry) and the
-- seven spirit «new» bit fields cleared. What stays: the element spirits and the token spirits (shop currencies, not
-- players), getOrderCount (a counter only ever raised), sortType / isLockTradeItem (settings), the spirit «got» bit
-- fields m_globalChrSpirit*GetFlag (the collection history), everything outside these records. Idempotent: a purged
-- save gives no write.

local SpiritPurge = {}

SpiritPurge.BLOCK_SPIRITS = 0x12
SpiritPurge.BLOCK_FLAGS = 0x02
-- the spirit lists whose entries are players
SpiritPurge.PLAYER_SPIRIT_LISTS = { "normalSpiritInfo", "heroSpiritInfo", "basaraSpiritInfo", "seasonalNormalSpiritInfo" }
-- the records of a player spirit entry (SPIRITINFO_NORMAL_P / _HERO_P / _BASARA_P / _SEASONAL_NORMAL_P)
SpiritPurge.SPIRIT_ENTRY_FIELDS = { "handle", "getOrder", "reserve", "charaParamId", "stockNum", "usedStockNum", "newFlag" }
-- the per-character «new spirit» bit fields of block 0x02 (one bit per character)
SpiritPurge.SPIRIT_NEW_FLAG_FIELDS = {
  "m_globalChrSpiritNormalNewFlag", "m_globalChrSpiritGrowingNewFlag", "m_globalChrSpiritAdvancedNewFlag",
  "m_globalChrSpiritTopNewFlag", "m_globalChrSpiritLegendaryNewFlag", "m_globalChrSpiritHeroNewFlag",
  "m_globalChrSpiritBasaraNewFlag",
}
-- the leaves whose u16 words are card counts
local COUNT_FIELDS = { stockNum = true, usedStockNum = true }

local ZERO_BYTE_PATTERN = "[^\0]"

local function has_block(tree, id)
  for _, block in ipairs(tree:blocks()) do
    if block == id then return true end
  end
  return false
end

-- `block<N>.m_Permanent` when it is a struct, else the block itself
local function permanent_of(tree, id)
  local base = "block" .. id
  local wrapper = base .. ".m_Permanent"
  local node = tree:get(wrapper)
  if node and node.kind == "struct" then return wrapper end
  return base
end

-- the sum of the little-endian u16 words of `bytes`
local function word_sum(bytes)
  local total = 0
  for i = 1, #bytes - 1, 2 do
    local low, high = string.byte(bytes, i, i + 1)
    total = total + low + high * 256
  end
  return total
end

-- one player spirit list emptied: entries cleared, cards (stock + used) counted
local function purge_list(tree, list_path, list_report)
  local list = tree:get(list_path)
  if not list or list.kind ~= "array" or list.len == 0 then return end
  -- every element of an array has the same records: the names of the first one (the tree lists a record it was never
  -- asked for as «0x<hash>»: the known names are asked first; an unknown record is still emptied through its hash)
  for _, name in ipairs(SpiritPurge.SPIRIT_ENTRY_FIELDS) do tree:get(list_path .. "[0]." .. name) end
  local leaf_names = tree:children(list_path .. "[0]") or {}
  for index = 0, list.len - 1 do
    local entry = list_path .. "[" .. index .. "]"
    local cleared = false
    for _, name in ipairs(leaf_names) do
      local path = entry .. "." .. name
      local node = tree:get(path)
      if node and node.kind == "leaf" then
        local bytes = tree:bytes(path)
        if bytes:find(ZERO_BYTE_PATTERN) then
          if COUNT_FIELDS[name] then list_report.cards = list_report.cards + word_sum(bytes) end
          tree:set_bytes(path, string.rep("\0", #bytes))
          cleared = true
        end
      elseif node then
        error(entry .. "." .. name .. ": a " .. node.kind .. " inside a spirit entry (an unknown save layout)")
      end
    end
    if cleared then list_report.entries = list_report.entries + 1 end
  end
end

-- Empty the player spirits of `tree`. Returns the report:
--   { lists = { [name] = { entries, cards } }, entries, cards, new_flag_fields, has_spirit_block, has_flag_block }
function SpiritPurge.run(tree)
  local report = { lists = {}, entries = 0, cards = 0, new_flag_fields = 0, has_spirit_block = false, has_flag_block = false }
  if has_block(tree, SpiritPurge.BLOCK_SPIRITS) then
    report.has_spirit_block = true
    local permanent = permanent_of(tree, SpiritPurge.BLOCK_SPIRITS)
    for _, name in ipairs(SpiritPurge.PLAYER_SPIRIT_LISTS) do
      local list_report = { entries = 0, cards = 0 }
      purge_list(tree, permanent .. "." .. name, list_report)
      report.lists[name] = list_report
      report.entries = report.entries + list_report.entries
      report.cards = report.cards + list_report.cards
    end
  end
  if has_block(tree, SpiritPurge.BLOCK_FLAGS) then
    report.has_flag_block = true
    local permanent = permanent_of(tree, SpiritPurge.BLOCK_FLAGS)
    for _, name in ipairs(SpiritPurge.SPIRIT_NEW_FLAG_FIELDS) do
      local path = permanent .. "." .. name
      local node = tree:get(path)
      if node and node.kind == "leaf" then
        local bytes = tree:bytes(path)
        if bytes:find(ZERO_BYTE_PATTERN) then
          tree:set_bytes(path, string.rep("\0", #bytes))
          report.new_flag_fields = report.new_flag_fields + 1
        end
      end
    end
  end
  return report
end

-- one line: «N spirit entries (C cards) removed: normal a (c), hero …; K «new» bit fields cleared»
function SpiritPurge.summary(report)
  local parts = {}
  for _, name in ipairs(SpiritPurge.PLAYER_SPIRIT_LISTS) do
    local list_report = report.lists[name]
    if list_report then
      parts[#parts + 1] = string.format("%s %d (%d cards)", name, list_report.entries, list_report.cards)
    end
  end
  local text = string.format("%d spirit entries (%d cards) removed", report.entries, report.cards)
  if #parts > 0 then text = text .. ": " .. table.concat(parts, ", ") end
  text = text .. string.format("; %d spirit «new» bit fields cleared", report.new_flag_fields)
  if not report.has_spirit_block then text = text .. " (the save has no spirit block 0x12)" end
  return text
end

return SpiritPurge
