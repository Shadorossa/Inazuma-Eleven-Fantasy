-- Character Reforged › duplicate players: the pass over a duplicated save (the mechanism; the policy is the mods'
-- duplicate rules, lib/duplicate_players/rules.lua). Ported from Inazuma Fantasy's «Ajustar save al mod»
-- (scripts/lib/save_slots/adjust.lua, docs/framework/save-adjust.md) on 2026-10-14, without its own rules.
--
--   * rarity (policy normal_card_rarity): every normal card (chara_param col 41 = 0), and every special card whose col 41
--     the policy lists (normal_special_rarities: the tiers a rule's option removes), whose saved rarity differs -> it.
--     With policy convert_special_cards (the save adjust action) such a special card also becomes his character's
--     base card (CardFacts:base_card_of: param_id_crc, a team's captainParamId) and joins that character's copies: when
--     the club already has him, the copies are merged into the one keep_first keeps (as the duplicates below)
--   * hidden cards (policy release_cards_hidden_in): every copy is released, a copy in a team too (team slot,
--     memberNum, captain, team aura entry); their spirit cards (spirit lists) are emptied
--   * duplicates (policy one_card_per): ONE card per character (a normal card by its chara_base, a special card by its
--     card) or per card; the copy that stays is chosen by policy keep_first. A released duplicate is merged into the
--     kept card: his team slots (emptied when the kept card is already there), captain, team aura entry (the kept card
--     with an aura command in his board's aura slot, else emptied), dock bits (organizedTeamFlag), bank lists
--   * a released player: his record becomes an empty slot (copied from the highest unused slot of the save), his
--     equipment and board items go back to their stacks (equipment_num), his handle leaves charaBank / rpgCharaBank /
--     m_Collection, the Kizuna boards (item + its lines) and the Kizuna Town residents; he gives
--     element_spirits_per_released_card element spirits of his element (story spirits, rarity 4 then 3..0, capped)
-- Never touched: story-only, season and released-scout records (attribute bits). Never released: a card the game's
-- bank cannot retire (CanCharaBankRemove of chara_bank_menu: attribute bits 0x80 / 0x1000 / 0x2000 / 0x10000, e.g. the
-- avatars and the original players) and any card that did not join by signing (addPartySource other than 4): in a
-- duplicate group such a card is always the one kept, and a second one of them stays too (logged «not released»).
-- Idempotent.

local T = require "lib/duplicate_players/save_tree"

local MergePass = {}

local band, bor = bit32.band, bit32.bor
local floor, concat, sub, byte, char = math.floor, table.concat, string.sub, string.byte, string.char

-- attribute bits of the records the pass never touches (story-only, season, released scouts)
MergePass.ATTRIBUTES_NEVER_TOUCHED = 0x10000000 + 0x00100000 + 0x80 + 0x40
-- the attribute bits of a card the bank cannot retire (chara_bank_menu CanCharaBankRemove: CMND 29506568(hdl, bit))
MergePass.ATTRIBUTES_NOT_RETIRABLE = 0x80 + 0x1000 + 0x2000 + 0x10000
-- addPartySource of a player who joined by signing (a spirit summon / fichaje); docs/formats/save.md
MergePass.SIGNED_SOURCE = 4
-- an element spirit stock word holds at most this many
MergePass.ELEMENT_SPIRIT_CAP = 999
local ELEMENT_NAMES = { "wind", "forest", "fire", "mountain" }
local ELEMENT_COUNT = #ELEMENT_NAMES
-- elementSpiritInfo.stockNum: per element 6 rarities x 2 variants of u16 words (variant 0 = the story spirits)
local ELEMENT_SPIRIT_WORDS_PER_ELEMENT = 12
local ELEMENT_SPIRIT_MIN_BYTES = 96
local ELEMENT_SPIRIT_RARITIES_BEST_FIRST = { 4, 3, 2, 1, 0 }
-- the board slot whose move a team's aura entry names
local AURA_BOARD_SLOT = "specialSkill_8"
-- the members of m_saveHumanP whose elements hold item handles (equipment, board items)
local ITEM_HOLDERS = { equip_inv_info = true, skillEquipInvInfo = true, skillEquipInvInfoOverWrite = true }
-- the item lists of block 4 (CGDDInventoryStatus, docs/formats/save.md), in record order
local INVENTORY_LISTS = {
  "invConsume", "invShoes", "invMisanga", "invAccessory", "invSpecial", "invCostume", "invFashion", "invTeamItem",
  "invCraftObj", "invAnimal", "invTitle", "invSkill", "invKizunaLink", "invNamePlate", "invUserTitle", "invPerformance",
  "invEquipToken",
}
local SPIRIT_LISTS = { "normalSpiritInfo", "heroSpiritInfo", "basaraSpiritInfo", "seasonalNormalSpiritInfo" }
local BANK_LISTS = { "charaBank", "rpgCharaBank" }
local KIZUNA_BOARDS = { "storyBoardInfo", "chronicleBoardInfo" }
-- the save blocks the pass needs / reads when present
local BLOCK_INVENTORY, BLOCK_CHARACTERS, BLOCK_TEAMS = 4, 5, 7
local BLOCK_KIZUNA_BOARDS, BLOCK_SPIRITS, BLOCK_RESIDENTS = 0x11, 0x12, 0x17

-- ------------------------------------------------------------------------------------------------ the plan

local function eligible(record)
  return record.handle ~= 0 and record.card ~= 0 and band(record.attributes, MergePass.ATTRIBUTES_NEVER_TOUCHED) == 0
end

-- the pass may release this card: the bank could retire it and he joined by signing
local function retirable(record)
  return band(record.attributes, MergePass.ATTRIBUTES_NOT_RETIRABLE) == 0 and record.source == MergePass.SIGNED_SOURCE
end
MergePass.retirable = retirable

-- what "the same card" is: per character, a normal card is its character and a special card (or an unknown row) its
-- card; per card, always the card. Ordered keys: every character key sorts before every card key, then by number.
local function same_card_key(record, one_card_per)
  local normal = record.special_rarity == 0 or record.converts_to ~= nil
  if one_card_per == "character" and normal and record.character ~= 0 then return 0, record.character end
  return 1, record.converts_to or record.card
end

-- the group of a record: per policy one_card_per; without it, only the character copies a conversion merges (a normal
-- card or a converted special card by its character; nil = no group)
local function group_key(record, one_card_per)
  if one_card_per ~= nil then return same_card_key(record, one_card_per) end
  if record.character ~= 0 and (record.special_rarity == 0 or record.converts_to ~= nil) then return 0, record.character end
  return nil
end

-- the comparison of policy keep_first: a is kept before b
local KEEP_TESTS = {
  in_a_fusion = function(a, b) if a.in_a_fusion ~= b.in_a_fusion then return a.in_a_fusion end end,
  highest_level = function(a, b) if a.level ~= b.level then return a.level > b.level end end,
  most_experience = function(a, b) if a.experience ~= b.experience then return a.experience > b.experience end end,
  most_special_move_uses = function(a, b) if a.move_uses ~= b.move_uses then return a.move_uses > b.move_uses end end,
  in_a_team = function(a, b) if a.in_a_team ~= b.in_a_team then return a.in_a_team end end,
  oldest = function(a, b) if a.get_order ~= b.get_order then return a.get_order < b.get_order end end,
  lowest_handle = function(a, b) if a.handle ~= b.handle then return a.handle < b.handle end end,
}

local function keeps_before(keep_first)
  return function(a, b)
    -- a card that cannot be released is always kept first
    local ra, rb = retirable(a), retirable(b)
    if ra ~= rb then return rb end
    for _, key in ipairs(keep_first) do
      local decided = KEEP_TESTS[key](a, b)
      if decided ~= nil then return decided end
    end
    return a.handle < b.handle
  end
end

-- plan.rarity = { {handle, card, rarity, character, converts_to} }, plan.release = { {handle, card, kept} } (kept 0 = a
-- hidden card), plan.protected = { {handle, card, why, kept} } (cards the pass would release but may not). A record's
-- base_card (his character's base card) is read when convert_special_cards asks for it.
function MergePass.plan(records, policy, is_hidden)
  local plan = { rarity = {}, release = {}, protected = {} }
  local special = policy.normal_special_rarities or {}
  local convert = policy.convert_special_cards == true and policy.normal_card_rarity ~= nil
  local groups, keys, converting = {}, {}, {}
  for _, record in ipairs(records) do
    if eligible(record) then
      if is_hidden(record.card) then
        if retirable(record) then
          plan.release[#plan.release + 1] = { record.handle, record.card, 0 }
        else
          plan.protected[#plan.protected + 1] = { record.handle, record.card, "hidden card", 0, record }
        end
      else
        if convert and record.special_rarity ~= nil and record.special_rarity ~= 0 and special[record.special_rarity]
            and record.base_card ~= nil and record.base_card ~= record.card then
          record.converts_to = record.base_card
        end
        if policy.normal_card_rarity ~= nil and (record.special_rarity == 0 or special[record.special_rarity])
            and (record.rarity ~= policy.normal_card_rarity or record.converts_to ~= nil) then
          plan.rarity[#plan.rarity + 1] = { record.handle, record.card, record.rarity, record.character, record.converts_to }
        end
        if policy.one_card_per ~= nil or convert then
          local kind, value = group_key(record, policy.one_card_per)
          if kind ~= nil then
            local key = kind .. ":" .. value
            local group = groups[key]
            if not group then
              group = {}
              groups[key] = group
              keys[#keys + 1] = { kind, value, key }
            end
            group[#group + 1] = record
            if record.converts_to ~= nil then converting[key] = true end
          end
        end
      end
    end
  end
  table.sort(keys, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
  end)
  local before = keeps_before(policy.keep_first)
  for _, key in ipairs(keys) do
    local group = groups[key[3]]
    if #group >= 2 and (policy.one_card_per ~= nil or converting[key[3]]) then
      table.sort(group, before)
      local kept = group[1].handle
      for i = 2, #group do
        if retirable(group[i]) then
          plan.release[#plan.release + 1] = { group[i].handle, group[i].card, kept }
        else
          plan.protected[#plan.protected + 1] = { group[i].handle, group[i].card, "duplicate", kept, group[i] }
        end
      end
    end
  end
  -- a released copy needs no rarity change
  local released = {}
  for _, entry in ipairs(plan.release) do released[entry[1]] = true end
  local rarity = {}
  for _, entry in ipairs(plan.rarity) do
    if not released[entry[1]] then rarity[#rarity + 1] = entry end
  end
  plan.rarity = rarity
  return plan
end

-- ------------------------------------------------------------------------------------------------ save helpers

-- the team paths of block 7 (every team set, every team)
local function teams_of(tree, permanent)
  local out = {}
  local sets, set_count = T.arr(tree, T.kids(tree, permanent, "teamSetList"), "m_buffer")
  for set_index = 0, (set_count or 0) - 1 do
    local team_list, team_count = T.arr(tree, T.at(sets, set_index), "teamInfoList")
    for team_index = 0, (team_count or 0) - 1 do out[#out + 1] = T.at(team_list, team_index) end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ the pass

local function new_report()
  return {
    players = 0, hidden_released = 0, duplicates_merged = 0, protected = 0, to_normal_rarity = 0, to_normal_rarity_from = {},
    to_base_card = 0,
    element_spirits = { 0, 0, 0, 0 }, element_spirits_lost = 0, without_element = 0, spirit_entries_cleared = 0,
    spirit_cards_removed = 0, team_slots_cleared = 0, captains_cleared = 0, team_auras_cleared = 0,
    bank_words_cleared = 0, kizuna_items_cleared = 0, kizuna_lines_cleared = 0, residents_unlinked = 0,
    item_references_released = 0, team_slots_repointed = 0, captains_repointed = 0, team_auras_repointed = 0,
    bank_words_repointed = 0, dock_bits_moved = 0, bytes_patched = 0, lines = {},
  }
end

-- The pass on one tree with the merged policy. Returns the report and { merges = { {duplicate, duplicate_card, kept,
-- kept_card, character} } (by duplicate), released = set of handles }. report.lines: one line per player changed (rarity
-- / released).
function MergePass.run(tree, facts, policy)
  local function is_hidden(card) return facts:is_hidden(card) end
  for _, id in ipairs({ BLOCK_INVENTORY, BLOCK_CHARACTERS, BLOCK_TEAMS }) do
    if not T.has_block(tree, id) then error("block " .. id .. " not found") end
  end
  local has_kizuna_boards, has_spirits, has_residents = T.has_block(tree, BLOCK_KIZUNA_BOARDS), T.has_block(tree, BLOCK_SPIRITS), T.has_block(tree, BLOCK_RESIDENTS)
  local P = T.patches(tree)
  local report = new_report()
  local outcome = { merges = {}, released = {} }

  -- ---- characters (m_saveHumanP, one column per member)
  local humans = T.kids(tree, T.unwrap(tree, "block5", "m_Permanent"), "m_saveHumanP")
  if not humans then error("m_saveHumanP not found") end
  local columns = {}
  local function column(name)
    if columns[name] == nil then
      local bytes = T.leaf(tree, humans, name)
      if not bytes then error("m_saveHumanP." .. name .. " not found") end
      columns[name] = bytes
    end
    return columns[name]
  end
  local handles, cards = T.words(column("handle")), T.words(column("param_id_crc"))
  local experiences, rarities = T.words(column("nowExp")), T.words(column("charaRarity"))
  local attributes, get_orders = T.words(column("attribute")), T.words(column("get_order"))
  local levels = column("nowLv")
  local count = #handles
  local function level_of(i) return T.rd(levels, i * 2, 2) end
  -- how each player joined (u8 per record); a save without the column: unknown (0), so nobody is released
  local sources = T.leaf(tree, humans, "addPartySource")
  if sources and #sources ~= count then sources = nil end
  local function source_of(i) return sources and byte(sources, i + 1) or 0 end
  -- team sets (block 7): the handles in a team
  local team_permanent = T.unwrap(tree, "block7", "m_InfoPermanent")
  local teams = teams_of(tree, team_permanent)
  local in_a_team = {}
  for _, team in ipairs(teams) do
    local members, member_count = T.arr(tree, team, "memberList")
    for k = 0, (member_count or 0) - 1 do
      local handle = T.num(tree, T.at(members, k), "charaStHdl")
      if handle and handle ~= 0 then in_a_team[handle] = true end
    end
  end
  local converting = policy.convert_special_cards == true
  local records, index_of = {}, {}
  for i = 0, count - 1 do
    local handle = handles[i + 1]
    if handle ~= 0 then
      local card = cards[i + 1]
      local special_rarity, character = facts:special_rarity_of(card), facts:character_of(card)
      index_of[handle] = i
      records[#records + 1] = {
        handle = handle, card = card, rarity = rarities[i + 1], attributes = attributes[i + 1], level = level_of(i),
        experience = experiences[i + 1], get_order = get_orders[i + 1], in_a_team = in_a_team[handle] == true,
        in_a_fusion = false, move_uses = 0, special_rarity = special_rarity, character = character,
        source = source_of(i),
        base_card = (converting and special_rarity ~= nil and special_rarity ~= 0 and character ~= 0) and facts:base_card_of(character) or nil,
      }
    end
  end
  report.players = #records
  local plan = MergePass.plan(records, policy, is_hidden)
  report.protected = #plan.protected
  for _, entry in ipairs(plan.protected) do
    local record = entry[5]
    report.lines[#report.lines + 1] = string.format("not released 0x%08X card 0x%08X (%s%s): the bank cannot retire it (attribute 0x%X) or it did not join by signing (source %d)",
      entry[1], entry[2], entry[3], entry[4] ~= 0 and string.format(" of 0x%08X", entry[4]) or "", record.attributes, record.source)
  end

  -- ---- rarity of the normal cards (and the special cards that become their character's base card)
  local rarity_from = {}
  local rarity_path, card_path = humans .. ".charaRarity", humans .. ".param_id_crc"
  -- the card each converted player has after the pass (handle -> base card)
  local final_card = {}
  for _, entry in ipairs(plan.rarity) do
    local i = index_of[entry[1]]
    local wanted = T.le(policy.normal_card_rarity, 4)
    if sub(columns.charaRarity, i * 4 + 1, i * 4 + 4) ~= wanted then P:put(rarity_path, i * 4, wanted, 4, columns.charaRarity) end
    local base = entry[5]
    if base ~= nil then
      P:put(card_path, i * 4, T.le(base, 4), 4, columns.param_id_crc)
      final_card[entry[1]] = base
      report.to_base_card = report.to_base_card + 1
    end
    report.to_normal_rarity = report.to_normal_rarity + 1
    rarity_from[entry[3]] = (rarity_from[entry[3]] or 0) + 1
    report.lines[#report.lines + 1] = string.format("rarity 0x%08X (m_saveHumanP[%d]) card 0x%08X character 0x%08X: %d -> %d%s",
      entry[1], i, entry[2], entry[4] or 0, entry[3], policy.normal_card_rarity,
      base ~= nil and string.format(", card -> base card 0x%08X", base) or "")
  end
  local function card_after(handle)
    return final_card[handle] or cards[index_of[handle] + 1]
  end
  -- a converted captain: his team's captain card follows
  if next(final_card) ~= nil then
    for _, team in ipairs(teams) do
      local captain = T.num(tree, team, "captainStHdl")
      local captain_card = T.num(tree, team, "captainParamId")
      if captain and captain_card and final_card[captain] then
        P:set(team .. ".captainParamId", captain_card, final_card[captain])
      end
    end
  end
  for rarity, n in pairs(rarity_from) do report.to_normal_rarity_from[#report.to_normal_rarity_from + 1] = { rarity, n } end
  table.sort(report.to_normal_rarity_from, function(a, b) return a[1] < b[1] end)

  -- ---- released players
  local released, release_order = {}, {}
  for _, entry in ipairs(plan.release) do
    local handle, card, kept = entry[1], entry[2], entry[3]
    released[handle] = { index = index_of[handle], card = card, kept = kept }
    release_order[#release_order + 1] = handle
    outcome.released[handle] = true
  end
  table.sort(release_order, function(a, b) return released[a].index < released[b].index end)
  local kept_of = {}
  for handle, entry in pairs(released) do
    if entry.kept ~= 0 then kept_of[handle] = entry.kept end
  end
  -- an unused slot of this save = the empty-record template (the highest free index)
  local template
  for i = count - 1, 0, -1 do
    if handles[i + 1] == 0 then template = i; break end
  end
  if #release_order > 0 and not template then error("no free character slot to copy an empty record from") end
  local item_change, item_handles = {}, {}
  local element_spirits_added = { 0, 0, 0, 0 }
  -- dock bits (organizedTeamFlag, one column): the kept card takes the bits of the copies merged into him
  local dock_bits = T.leaf(tree, humans, "organizedTeamFlag")
  if not (dock_bits and count > 0 and #dock_bits > 0 and #dock_bits % count == 0) then dock_bits = nil end
  local merged_bits, merged_bits_order = {}, {}
  -- every member of m_saveHumanP: { name, kind, len }. Listed after every named read of them, so a member the pass
  -- also writes by name (charaRarity, organizedTeamFlag) is listed by that name (one spelling = one patch entry)
  local members = {}
  for name in pairs(ITEM_HOLDERS) do tree:get(humans .. "." .. name) end
  for _, name in ipairs(tree:children(humans)) do
    local node = tree:get(humans .. "." .. name)
    if node then members[#members + 1] = { name = name, kind = node.kind, len = node.len } end
  end
  -- the template's elements of the per-player arrays: { [member] = { { path, bytes } } }
  local template_leaves = {}
  local function element_leaves(array_path, i)
    local leaves = {}
    for _, path in ipairs(T.leaves(tree, T.at(array_path, i))) do leaves[#leaves + 1] = { path, tree:bytes(path) } end
    return leaves
  end
  for _, handle in ipairs(release_order) do
    local entry = released[handle]
    local i, card, kept = entry.index, entry.card, entry.kept
    if dock_bits and kept ~= 0 then
      local width = #dock_bits / count
      local bits = sub(dock_bits, i * width + 1, (i + 1) * width)
      if bits:find("[^\0]") then
        local merged = merged_bits[kept]
        if not merged then
          merged = {}
          for k = 1, width do merged[k] = 0 end
          merged_bits[kept] = merged
          merged_bits_order[#merged_bits_order + 1] = kept
        end
        for k = 1, width do merged[k] = bor(merged[k], byte(bits, k)) end
      end
    end
    for _, member in ipairs(members) do
      local member_path = humans .. "." .. member.name
      if member.kind == "leaf" and member.len % count == 0 and member.len >= count then
        local width = member.len / count
        local bytes = columns[member.name] or column(member.name)
        local empty = sub(bytes, template * width + 1, (template + 1) * width)
        if sub(bytes, i * width + 1, (i + 1) * width) ~= empty then P:put(member_path, i * width, empty, width, bytes) end
      elseif member.kind == "array" and member.len == count then
        local own = element_leaves(member_path, i)
        local empty = template_leaves[member.name]
        if not empty then
          empty = element_leaves(member_path, template)
          template_leaves[member.name] = empty
        end
        if #own ~= #empty then error(string.format("m_saveHumanP member %s: element layouts differ", member.name)) end
        for k = 1, #own do
          if #own[k][2] ~= #empty[k][2] then error(string.format("m_saveHumanP member %s: element layouts differ", member.name)) end
        end
        -- items held: equipment + board skill items go back to their stacks
        if ITEM_HOLDERS[member.name] then
          for _, leaf in ipairs(own) do
            for _, item in ipairs(T.words(leaf[2])) do
              if item ~= 0 then
                if item_change[item] == nil then item_change[item] = 0; item_handles[#item_handles + 1] = item end
                item_change[item] = item_change[item] - 1
                report.item_references_released = report.item_references_released + 1
              end
            end
          end
        end
        for k = 1, #own do
          if own[k][2] ~= empty[k][2] then P:put(own[k][1], 0, empty[k][2], #empty[k][2], own[k][2]) end
        end
      end
    end
    local what
    if kept == 0 then
      report.hidden_released = report.hidden_released + 1
      what = "hidden card"
    else
      report.duplicates_merged = report.duplicates_merged + 1
      local k = index_of[kept]
      outcome.merges[#outcome.merges + 1] = { duplicate = handle, duplicate_card = card, kept = kept, kept_card = card_after(kept), character = facts:character_of(card) }
      what = string.format("duplicate (Lv %d, EXP %d) merged into 0x%08X (m_saveHumanP[%d], card 0x%08X, Lv %d, EXP %d)",
        level_of(i), experiences[i + 1], kept, k, card_after(kept), level_of(k), experiences[k + 1])
    end
    local element = facts:element_of(card)
    if element then
      element_spirits_added[element] = element_spirits_added[element] + policy.element_spirits_per_released_card
    else
      report.without_element = report.without_element + 1
    end
    report.lines[#report.lines + 1] = string.format("released 0x%08X (m_saveHumanP[%d]) card 0x%08X character 0x%08X: %s%s; +%d element spirits %s",
      handle, i, card, facts:character_of(card), what, in_a_team[handle] and ", was in a team" or "",
      element and policy.element_spirits_per_released_card or 0, element and ELEMENT_NAMES[element] or "(no element)")
  end
  table.sort(outcome.merges, function(a, b) return a.duplicate < b.duplicate end)
  if dock_bits then
    local width = #dock_bits / count
    table.sort(merged_bits_order)
    for _, kept in ipairs(merged_bits_order) do
      local k = index_of[kept]
      local current = sub(dock_bits, k * width + 1, (k + 1) * width)
      local bytes = {}
      for x = 1, width do bytes[x] = char(bor(byte(current, x), merged_bits[kept][x])) end
      local merged = concat(bytes)
      if merged ~= current then
        P:put(humans .. ".organizedTeamFlag", k * width, merged, width, dock_bits)
        report.dock_bits_moved = report.dock_bits_moved + 1
      end
    end
  end

  -- ---- references in block 7: teams, captain, team aura, bank lists; Kizuna; residents
  if #release_order > 0 then
    local item_of_handle = {}
    do
      local inventory = T.unwrap(tree, "block4", "m_Permanent")
      local list, list_count = T.arr(tree, inventory, "invSkill")
      for x = 0, (list_count or 0) - 1 do
        local element = T.at(list, x)
        local item_handle, item_id = T.num(tree, element, "handle"), T.num(tree, element, "item_id")
        if item_handle and item_id and item_handle ~= 0 then item_of_handle[item_handle] = item_id end
      end
    end
    local boards, board_count = T.arr(tree, humans, "skillEquipInvInfo")
    local overwrites, overwrite_count = T.arr(tree, humans, "skillEquipInvInfoOverWrite")
    -- the aura command in a card's board aura slot (0 = none)
    local function aura_of(handle)
      local i = index_of[handle]
      if not i then return 0 end
      local function at(array, array_count)
        if not array or i >= array_count then return 0 end
        return T.num(tree, T.at(array, i), AURA_BOARD_SLOT) or 0
      end
      local item_handle = at(boards, board_count)
      if item_handle == 0 then item_handle = at(overwrites, overwrite_count) end
      local move = item_of_handle[item_handle] or 0
      if facts:is_team_aura(move) then return move end
      return 0
    end
    for _, team in ipairs(teams) do
      local member_list, member_count = T.arr(tree, team, "memberList")
      local present = {}
      local slots = {}
      for k = 0, (member_count or 0) - 1 do
        local slot = T.at(member_list, k)
        local handle = T.num(tree, slot, "charaStHdl")
        if handle then
          slots[#slots + 1] = { slot, handle }
          if handle ~= 0 and not released[handle] then present[handle] = true end
        end
      end
      local gone = 0
      for _, entry in ipairs(slots) do
        local slot, handle = entry[1], entry[2]
        if released[handle] then
          local kept = kept_of[handle]
          if kept and not present[kept] then
            present[kept] = true
            P:set(slot .. ".charaStHdl", handle, kept)
            report.team_slots_repointed = report.team_slots_repointed + 1
          else
            P:set(slot .. ".charaStHdl", handle, 0)
            gone = gone + 1
          end
        end
      end
      if gone > 0 then
        report.team_slots_cleared = report.team_slots_cleared + gone
        local member_total = T.num(tree, team, "memberNum")
        if member_total then
          local width = tree:get(team .. ".memberNum").len
          P:put(team .. ".memberNum", 0, char(math.max(member_total - gone, 0) % 256), width)
        end
      end
      local captain = T.num(tree, team, "captainStHdl")
      if captain and released[captain] then
        local captain_card = T.num(tree, team, "captainParamId")
        local kept = kept_of[captain]
        if kept and present[kept] then
          P:set(team .. ".captainStHdl", captain, kept)
          if captain_card then P:set(team .. ".captainParamId", captain_card, card_after(kept)) end
          report.captains_repointed = report.captains_repointed + 1
        else
          P:set(team .. ".captainStHdl", captain, 0)
          if captain_card then P:set(team .. ".captainParamId", captain_card, 0) end
          report.captains_cleared = report.captains_cleared + 1
        end
      end
      local aura_list, aura_count = T.arr(tree, team, "auraSkillSlotInfoList")
      local aura_entries, has_aura = {}, {}
      for k = 0, (aura_count or 0) - 1 do
        local aura_entry = T.at(aura_list, k)
        local holder = T.num(tree, aura_entry, "charaStHdl")
        if holder and holder ~= 0 and not released[holder] then has_aura[holder] = true end
        local move = T.num(tree, aura_entry, "skillId")
        if holder and move then aura_entries[#aura_entries + 1] = { aura_entry, holder, move } end
      end
      for _, entry in ipairs(aura_entries) do
        local aura_entry, holder, move = entry[1], entry[2], entry[3]
        if released[holder] then
          local kept = kept_of[holder]
          if kept and not (present[kept] and not has_aura[kept]) then kept = nil end
          local kept_aura = kept and aura_of(kept) or 0
          if kept and kept_aura ~= 0 then
            has_aura[kept] = true
            P:set(aura_entry .. ".charaStHdl", holder, kept)
            P:set(aura_entry .. ".skillId", move, kept_aura)
            report.team_auras_repointed = report.team_auras_repointed + 1
          else
            P:set(aura_entry .. ".charaStHdl", holder, 0)
            P:set(aura_entry .. ".skillId", move, 0)
            report.team_auras_cleared = report.team_auras_cleared + 1
          end
        end
      end
    end
    -- bank lists: a released word becomes the card that replaces him when that card is not in the list yet, else 0
    local bank_lists = {}
    for _, name in ipairs(BANK_LISTS) do bank_lists[#bank_lists + 1] = { team_permanent, name } end
    bank_lists[#bank_lists + 1] = { "block7", "m_Collection" }
    for _, list in ipairs(bank_lists) do
      local bytes, path = T.leaf(tree, list[1], list[2])
      if bytes then
        local words = T.words(bytes)
        local present = {}
        for _, word in ipairs(words) do
          if word ~= 0 and not released[word] then present[word] = true end
        end
        for k, word in ipairs(words) do
          if word ~= 0 and released[word] then
            local kept = kept_of[word]
            if kept and not present[kept] then
              present[kept] = true
              P:put(path, (k - 1) * 4, T.le(kept, 4), 4, bytes)
              report.bank_words_repointed = report.bank_words_repointed + 1
            else
              P:put(path, (k - 1) * 4, "\0\0\0\0", 4, bytes)
              report.bank_words_cleared = report.bank_words_cleared + 1
            end
          end
        end
      end
    end
    -- Kizuna boards: the player's item and the lines drawn to it
    if has_kizuna_boards then
      local permanent = T.unwrap(tree, "block17", "m_Permanent")
      for _, board_name in ipairs(KIZUNA_BOARDS) do
        local board_list, board_total = T.arr(tree, permanent, board_name)
        for b = 0, (board_total or 0) - 1 do
          local board = T.at(board_list, b)
          local cleared_items = {}
          local item_list, item_total = T.arr(tree, board, "itemArray")
          for k = 0, (item_total or 0) - 1 do
            local item = T.at(item_list, k)
            local status = T.num(tree, item, "statusHdl")
            if status and released[status] then
              local item_handle = T.num(tree, item, "handle")
              if item_handle and item_handle ~= 0 then cleared_items[item_handle] = true end
              P:zero(item)
              report.kizuna_items_cleared = report.kizuna_items_cleared + 1
            end
          end
          local line_list, line_total = T.arr(tree, board, "kizunaLineArray")
          for k = 0, (line_total or 0) - 1 do
            local line = T.at(line_list, k)
            local end_a, end_b = T.num(tree, line, "itemA"), T.num(tree, line, "itemB")
            if (end_a and cleared_items[end_a]) or (end_b and cleared_items[end_b]) then
              P:zero(line)
              report.kizuna_lines_cleared = report.kizuna_lines_cleared + 1
            end
          end
        end
      end
    end
    -- Kizuna Town residents keep their own look data; only the link to the released player goes
    if has_residents then
      local resident_list, resident_total = T.arr(tree, T.unwrap(tree, "block23", "m_permanent"), "craftResidentsStatusPList")
      for k = 0, (resident_total or 0) - 1 do
        local resident = T.at(resident_list, k)
        local handle = T.num(tree, resident, "baseCharaStatusHandle")
        if handle and released[handle] then
          P:set(resident .. ".baseCharaStatusHandle", handle, 0)
          report.residents_unlinked = report.residents_unlinked + 1
        end
      end
    end
  end

  -- ---- spirits (block 0x12): the hidden cards' spirit cards out, the element spirits in
  local any_element_spirits = false
  for element = 1, ELEMENT_COUNT do
    if element_spirits_added[element] > 0 then any_element_spirits = true end
  end
  if has_spirits then
    local permanent = T.unwrap(tree, "block18", "m_Permanent")
    for _, list_name in ipairs(SPIRIT_LISTS) do
      local spirit_list, spirit_total = T.arr(tree, permanent, list_name)
      for k = 0, (spirit_total or 0) - 1 do
        local spirit = T.at(spirit_list, k)
        local card = T.num(tree, spirit, "charaParamId")
        if card and card ~= 0 and is_hidden(card) then
          for _, field in ipairs({ "stockNum", "usedStockNum" }) do
            local stock = T.leaf(tree, spirit, field)
            if stock then
              for x = 0, floor(#stock / 2) - 1 do report.spirit_cards_removed = report.spirit_cards_removed + T.rd(stock, x * 2, 2) end
            end
          end
          P:zero(spirit)
          report.spirit_entries_cleared = report.spirit_entries_cleared + 1
        end
      end
    end
    if any_element_spirits then
      local stock, stock_path = T.leaf(tree, T.kids(tree, permanent, "elementSpiritInfo"), "stockNum")
      if not stock then error("elementSpiritInfo.stockNum not found") end
      if #stock < ELEMENT_SPIRIT_MIN_BYTES then error("elementSpiritInfo.stockNum too short") end
      local words = {}
      for x = 0, floor(#stock / 2) - 1 do words[x] = T.rd(stock, x * 2, 2) end
      for element = 0, ELEMENT_COUNT - 1 do
        local add = element_spirits_added[element + 1]
        local left = add
        for _, rarity in ipairs(ELEMENT_SPIRIT_RARITIES_BEST_FIRST) do
          local w = element * ELEMENT_SPIRIT_WORDS_PER_ELEMENT + rarity * 2 -- variant 0 = the story spirits
          local take = math.min(left, math.max(MergePass.ELEMENT_SPIRIT_CAP - words[w], 0))
          words[w] = words[w] + take
          left = left - take
        end
        report.element_spirits[element + 1] = add - left
        report.element_spirits_lost = report.element_spirits_lost + left
      end
      local parts = {}
      for x = 0, floor(#stock / 2) - 1 do parts[x + 1] = T.le(words[x], 2) end
      P:leaf(stock_path, stock, concat(parts) .. sub(stock, floor(#stock / 2) * 2 + 1))
    end
  elseif any_element_spirits then
    error("CGDDSpiritStatus block not found (element spirits)")
  end

  -- ---- item stacks: equipment_num follows the released references
  if #item_handles > 0 then
    local inventory = T.unwrap(tree, "block4", "m_Permanent")
    -- every list of CGDDInventoryStatus (docs/formats/save.md: one element layout { handle, item_id, …, equipment_num });
    -- the tree does not list a block's own top records, so a block without wrapper names its lists
    local names = tree:children(inventory) or INVENTORY_LISTS
    for _, name in ipairs(names) do
      local list_path = inventory .. "." .. name
      local node = tree:get(list_path)
      if node and node.kind == "array" then
        for k = 0, node.len - 1 do
          local element = T.at(list_path, k)
          local item_handle, equipped = T.num(tree, element, "handle"), T.num(tree, element, "equipment_num")
          if item_handle and equipped and item_change[item_handle] then
            P:set(element .. ".equipment_num", equipped, math.max(equipped + item_change[item_handle], 0))
          end
        end
      end
    end
  end

  report.bytes_patched = P:apply()
  return report, outcome
end

function MergePass.summary(report)
  local from = {}
  for i, entry in ipairs(report.to_normal_rarity_from) do from[i] = "(" .. entry[1] .. ", " .. entry[2] .. ")" end
  return string.format(
    "Duplicate players: %d players; %d hidden cards released, %d duplicates merged into the kept card, %d kept (not retirable), %d normal cards "
      .. "-> the normal rarity [%s] (%d special cards -> their base card); element spirits +%d wind +%d forest +%d fire +%d mountain (%d lost to the cap, %d "
      .. "players without element); %d spirit entries (%d cards) of hidden cards emptied; moved to the kept card: %d "
      .. "team slots, %d captains, %d team auras, %d bank words, %d dock-bit records; cleared: %d team slots, %d "
      .. "captains, %d team auras, %d bank words, %d Kizuna items + %d lines, %d residents, %d item references; %d bytes patched",
    report.players, report.hidden_released, report.duplicates_merged, report.protected or 0, report.to_normal_rarity, concat(from, ", "), report.to_base_card,
    report.element_spirits[1], report.element_spirits[2], report.element_spirits[3], report.element_spirits[4],
    report.element_spirits_lost, report.without_element, report.spirit_entries_cleared, report.spirit_cards_removed,
    report.team_slots_repointed, report.captains_repointed, report.team_auras_repointed, report.bank_words_repointed,
    report.dock_bits_moved, report.team_slots_cleared, report.captains_cleared, report.team_auras_cleared,
    report.bank_words_cleared, report.kizuna_items_cleared, report.kizuna_lines_cleared, report.residents_unlinked,
    report.item_references_released, report.bytes_patched)
end

return MergePass
