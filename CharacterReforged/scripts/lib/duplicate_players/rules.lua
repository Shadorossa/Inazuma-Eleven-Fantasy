-- Character Reforged › duplicate players: the rules other mods declare as data (docs/refactor/aura-mods-split.md
-- «Duplicate players hook»). Every active mod's content\duplicate_rules\*.toml (schema
-- CharacterReforged.duplicate_rules/1) may hold [CharacterReforged.DuplicateRules.<name>] tables; they are merged in
-- load order (inside one mod, by rule name), a later rule wins key by key. No rule = the hook does nothing.
--
-- Keys of a rule (all optional):
--   one_card_per = "character" | "card"     the copy keeps one card per character ("character": a normal card, chara_param
--                                           col 41 = 0, by its chara_base; a special card by its card) or per card
--                                           (chara_param); absent = no copy leaves for being a duplicate
--   keep_first = [...]                      which copy stays: the first key that tells two copies apart decides, in
--                                           order; KEEP_ORDER_KEYS below (default: the list KEEP_ORDER_DEFAULT)
--   normal_card_rarity = 0..15              the saved rarity every normal card gets (absent = rarities unchanged)
--   element_spirits_per_released_card = n   element spirits (the story's «fichas» of his element) per copy that leaves
--   release_cards_hidden_in = "<file>"      a file of the declaring mod whose [[hide]] rows / [[remove]] rows with
--                                           mode = "hide" name cards that leave the club (each declaring mod its own)
--   apply_on_load = true | false            the same pass also runs on a player slot when the save engine loads it
--                                           (scripts\duplicate_players.lua «slot_load»; a durable backup of the slot
--                                           first, once per save); absent / false = only a duplicated save

local DuplicateRules = {}

DuplicateRules.FOLDER = "content/duplicate_rules"

-- the keys keep_first accepts (a duplicated save has no fusion store nor move-use store of its own: those two keys
-- tell copies apart only in a pass that is given them, e.g. Inazuma Fantasy's load repair)
DuplicateRules.KEEP_ORDER_KEYS = {
  in_a_fusion = true, highest_level = true, most_experience = true, most_special_move_uses = true, in_a_team = true,
  oldest = true, lowest_handle = true,
}
DuplicateRules.KEEP_ORDER_DEFAULT = { "highest_level", "most_experience", "in_a_team", "oldest", "lowest_handle" }

local ONE_CARD_PER = { character = true, card = true }
local HIGHEST_RARITY = 15

local function warn(message) VRFW.warn("duplicate_players: " .. message) end

local function sorted_names(table_of_rules)
  local names = {}
  for name in pairs(table_of_rules) do
    if type(name) == "string" then names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

-- one rule's keys over the policy so far (bad values are left out with a warning)
local function merge_rule(policy, mod_id, rule_name, rule)
  local label = mod_id .. "/" .. rule_name
  for key, value in pairs(rule) do
    if key == "one_card_per" then
      if ONE_CARD_PER[value] then policy.one_card_per = value else warn(label .. ": one_card_per must be \"character\" or \"card\"") end
    elseif key == "keep_first" then
      local list, ok = {}, type(value) == "table"
      for _, name in ipairs(ok and value or {}) do
        if DuplicateRules.KEEP_ORDER_KEYS[name] then list[#list + 1] = name else ok = false end
      end
      if ok and #list > 0 then policy.keep_first = list else warn(label .. ": keep_first holds an unknown key: left out") end
    elseif key == "normal_card_rarity" then
      if type(value) == "number" and value >= 0 and value <= HIGHEST_RARITY and value % 1 == 0 then
        policy.normal_card_rarity = value
      else
        warn(label .. ": normal_card_rarity must be a whole number 0.." .. HIGHEST_RARITY)
      end
    elseif key == "element_spirits_per_released_card" then
      if type(value) == "number" and value >= 0 and value % 1 == 0 then
        policy.element_spirits_per_released_card = value
      else
        warn(label .. ": element_spirits_per_released_card must be a whole number >= 0")
      end
    elseif key == "apply_on_load" then
      if type(value) == "boolean" then
        policy.apply_on_load = policy.apply_on_load or value
      else
        warn(label .. ": apply_on_load must be true or false")
      end
    elseif key == "release_cards_hidden_in" then
      if type(value) == "string" and value:match("^[%w_%-/%.]+%.toml$") then
        policy.hidden_card_sources[#policy.hidden_card_sources + 1] = { mod = mod_id, file = value }
      else
        warn(label .. ": release_cards_hidden_in must be a mod-relative .toml path")
      end
    else
      warn(label .. ": unknown key " .. tostring(key) .. " (left out)")
    end
  end
  policy.names[#policy.names + 1] = label
end

-- The merged policy of every active mod's rules: { names = { "<mod>/<rule>" }, one_card_per, keep_first,
-- normal_card_rarity, element_spirits_per_released_card, hidden_card_sources = { { mod, file } }, apply_on_load (true
-- when any rule asks for it) }; `names` empty = no mod declares a rule.
function DuplicateRules.load()
  local policy = {
    names = {}, keep_first = DuplicateRules.KEEP_ORDER_DEFAULT, element_spirits_per_released_card = 0,
    hidden_card_sources = {}, apply_on_load = false,
  }
  local ok, declarations = pcall(VRFW.files.declarations, DuplicateRules.FOLDER)
  if not ok then
    warn("the duplicate rules could not be read (" .. tostring(declarations) .. "): no rule applies")
    return policy
  end
  for _, file in ipairs(type(declarations) == "table" and declarations or {}) do
    local data = type(file) == "table" and file.data or nil
    local root = type(data) == "table" and type(data.CharacterReforged) == "table" and data.CharacterReforged.DuplicateRules or nil
    if type(root) == "table" then
      for _, rule_name in ipairs(sorted_names(root)) do
        if type(root[rule_name]) == "table" then merge_rule(policy, tostring(file.mod), rule_name, root[rule_name]) end
      end
    end
  end
  return policy
end

-- the policy in one line, for the log and the report
function DuplicateRules.describe(policy)
  if #policy.names == 0 then return "no duplicate rule declared" end
  local hidden = {}
  for _, source in ipairs(policy.hidden_card_sources) do hidden[#hidden + 1] = source.mod .. ":" .. source.file end
  return string.format("rules %s; one card per %s; keep first %s; normal cards -> rarity %s; %d element spirits per released copy; hidden cards released: %s; on load: %s",
    table.concat(policy.names, ", "), policy.one_card_per or "(none: duplicates stay)", table.concat(policy.keep_first, " > "),
    policy.normal_card_rarity ~= nil and tostring(policy.normal_card_rarity) or "(unchanged)",
    policy.element_spirits_per_released_card, #hidden > 0 and table.concat(hidden, ", ") or "none",
    policy.apply_on_load and "yes" or "no")
end

return DuplicateRules
