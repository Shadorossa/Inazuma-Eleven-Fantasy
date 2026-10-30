-- Character Reforged › the functions of the VR-Framework's save adjust (Options › «Ajustar save»,
-- docs/framework/save-adjust.md). remove_unobtainable_moves / remove_hidden_kits are declared in
-- content\save_adjust\character_reforged.toml; remove_duplicates by New Recruitment and normal_rarity by No More
-- Rarities (their content\save_adjust\, script = "character_reforged:save_tools.lua": the actions exist only while
-- those modules are on). The framework calls the functions below by name.
--
-- Both duplicate actions run the SAME pass as the duplicate-players hook (scripts\duplicate_players.lua: a duplicated save, and
-- every load of a player slot when a rule asks for it) with the POLICY the mods declare in content\duplicate_rules\
-- (New Recruitment: one card per character; No More Rarities: every normal card -> rarity 4), split in two:
--
--   remove_duplicates   one card per character / card (keep_first decides which copy stays; the others are merged
--                       into it and leave the club and every team), the policy's rarity left out. Never released: a
--                       card the bank cannot retire or that did not join by signing (merge_pass.lua: always the one
--                       kept). Offered while a rule declares `one_card_per`.
--   normal_rarity       every normal card to the rarity the rules declare (`normal_card_rarity`; No More Rarities: 4 =
--                       5★ Leyenda), and every special card of the tiers a rule's option removes
--                       (`normalize_special_rarities`) becomes his character's base card at that rarity; when the club
--                       already has that character, his copies are merged into the one keep_first keeps (only those
--                       copies leave). Offered while a rule declares `normal_card_rarity`; the confirmation line is
--                       the option value's `save_adjust_label` when the rule names one.
--
-- Two more actions take out of the save what the active mods' rules make unobtainable:
--
--   remove_unobtainable_moves  every move no player can obtain ([[VRFW.Unobtainable]], lib/unobtainable_moves.lua;
--                              this mod's content\techniques\unobtainable_auras.toml = the awakening and bond
--                              transformation auras) out of every saved character's board and match list, the team
--                              aura entries, the invSkill stacks and the player sets (blob ss_player_sets.json).
--                              Offered while a rule names a move (lib/purge_moves.lua).
--   remove_hidden_kits         every team kit an active mod hides (item [[hide]] of a kit; this mod's
--                              content\items\hidden_away_kits.toml) out of the teams (back to their home kit), the
--                              invFashion stacks and the player sets. Offered while a mod hides a kit
--                              (lib/purge_kits.lua).
--
-- The framework runs every available action at the safe point of the CURRENT slot (its `slot_load` after the menu
-- saved and reloads it), writes the tree once when it changed (the slot service's backup first) and shows the counts;
-- the locked retail save and the reserved slots (a mode's own save, e.g. INAROGUE) never get here. Log: one line per
-- run «save adjust: <action>: …» plus the pass's summary.

local Rules = require "lib/duplicate_players/rules"
local CardFacts = require "lib/duplicate_players/card_facts"
local MergePass = require "lib/duplicate_players/merge_pass"
local Unobtainable = require "lib/unobtainable_moves"
local PurgeMoves = require "lib/purge_moves"
local PurgeKits = require "lib/purge_kits"
local Id = require "VRFW/lib/ids"

local PLAYER_SETS_BLOB = "ss_player_sets.json"

local function log(message) VRFW.log("save adjust: " .. message) end

-- a shallow copy of the merged policy with some keys changed (`false` = the key removed)
local function policy_with(changes)
  local policy = {}
  for key, value in pairs(Rules.load()) do policy[key] = value end
  for key, value in pairs(changes) do
    if value == false then policy[key] = nil else policy[key] = value end
  end
  return policy
end

-- the pass on `tree` with `policy`: the report (the tree patched in place; the framework writes it)
local function run_pass(tree, policy, action)
  local report = MergePass.run(tree, CardFacts.load(policy), policy)
  log(action .. ": " .. Rules.describe(policy) .. "; " .. MergePass.summary(report))
  for _, line in ipairs(report.lines) do log(action .. ": " .. line) end
  return report
end

CharacterReforged = CharacterReforged or {}
local SaveAdjust = {}
CharacterReforged.SaveAdjust = SaveAdjust

function SaveAdjust.can_remove_duplicates()
  local policy = Rules.load()
  return #policy.names > 0 and policy.one_card_per ~= nil
end

function SaveAdjust.remove_duplicates(tree, event)
  local policy = policy_with({ normal_card_rarity = false, normal_special_rarities = false })
  if policy.one_card_per == nil then return { error = "no duplicate rule declares one_card_per" } end
  local report = run_pass(tree, policy, "remove_duplicates (slot " .. event.slot .. ")")
  return { count = report.duplicates_merged, log = report.duplicates_merged .. " duplicates merged, " .. report.hidden_released
    .. " hidden cards released, " .. (report.protected or 0) .. " kept (not retirable / not signed)" }
end

-- available: true, or the text key of the confirmation line the rules name for the option's current value
function SaveAdjust.can_set_normal_rarity()
  local policy = Rules.load()
  if #policy.names == 0 or policy.normal_card_rarity == nil then return false end
  return policy.normal_rarity_label or true
end

function SaveAdjust.normal_rarity(tree, event)
  -- the rarity and the removed special tiers to the base card; only the copies of a converted character leave (no
  -- one_card_per, no hidden-card release)
  local policy = policy_with({ one_card_per = false, hidden_card_sources = {}, convert_special_cards = true })
  if policy.normal_card_rarity == nil then return { error = "no duplicate rule declares normal_card_rarity" } end
  local report = run_pass(tree, policy, "normal_rarity (slot " .. event.slot .. ")")
  return { count = report.to_normal_rarity + report.duplicates_merged, log = report.to_normal_rarity .. " cards -> rarity "
    .. tostring(policy.normal_card_rarity) .. " (" .. report.to_base_card .. " special cards -> their base card), "
    .. report.duplicates_merged .. " copies merged, " .. (report.protected or 0) .. " kept (not retirable / not signed)" }
end

-- ---------------------------------------------------------------------------------------------- unobtainable things

-- the player sets of slot `slot` (blob ss_player_sets.json, scripts\player_sets.lua's layout): every stored value
-- `drop(field, value)` answers true for becomes 0 (fields: "moves", "hiper", "kit"). Returns how many; the blob is
-- written only when something changed.
local function purge_player_sets(slot, drop, action)
  local ok, text = pcall(VRFW.save.get_blob, slot, PLAYER_SETS_BLOB)
  if not ok or type(text) ~= "string" or text == "" then return 0 end
  local decoded, file = pcall(VRFW.json.decode, text)
  if not decoded or type(file) ~= "table" or type(file.players) ~= "table" then
    log(action .. ": " .. PLAYER_SETS_BLOB .. " not readable: left as it is")
    return 0
  end
  local u32 = Id.u32
  local n = 0
  for _, player in pairs(file.players) do
    for _, set in pairs(type(player) == "table" and type(player.sets) == "table" and player.sets or {}) do
      if type(set) == "table" then
        if type(set.moves) == "table" then
          for k, move in pairs(set.moves) do
            if drop("moves", u32(move)) then set.moves[k] = 0; n = n + 1 end
          end
        end
        for _, field in ipairs({ "hiper", "kit" }) do
          if set[field] ~= nil and drop(field, u32(set[field])) then set[field] = 0; n = n + 1 end
        end
      end
    end
  end
  if n > 0 then
    local encoded, out = pcall(VRFW.json.encode, file)
    local written, why = false, out
    if encoded then written, why = pcall(VRFW.save.set_blob, slot, PLAYER_SETS_BLOB, out) end
    if not encoded or not written or why == false then
      error(PLAYER_SETS_BLOB .. " of slot " .. tostring(slot) .. " not written: " .. tostring(why))
    end
    log(action .. ": " .. n .. " player set value(s) emptied in " .. PLAYER_SETS_BLOB)
  end
  return n
end

function SaveAdjust.can_remove_unobtainable_moves()
  local moves = Unobtainable.count()
  return moves > 0
end

function SaveAdjust.remove_unobtainable_moves(tree, event)
  local moves = Unobtainable.set()
  if next(moves) == nil then return { error = "no [[VRFW.Unobtainable]] rule names a move" } end
  local action = "remove_unobtainable_moves (slot " .. event.slot .. ")"
  local report = PurgeMoves.run(tree, moves)
  log(action .. ": " .. PurgeMoves.summary(report))
  for _, line in ipairs(report.lines) do log(action .. ": " .. line) end
  local sets = purge_player_sets(event.slot, function(field, value) return field ~= "kit" and moves[value] == true end, action)
  local count = report.removed + sets
  return { count = count, log = count .. " move(s) removed from the players (" .. PurgeMoves.summary(report) .. "; " .. sets .. " in player sets)" }
end

function SaveAdjust.can_remove_hidden_kits()
  local ok, facts = pcall(PurgeKits.facts)
  return ok and facts.count > 0
end

-- a kit value of a player set: the kit item or its uniform
local function hidden_kit_value(facts, value)
  if facts.by_item[value] then return true end
  for _, kit in pairs(facts.by_item) do
    if kit.uniform ~= 0 and kit.uniform == value then return true end
  end
  return false
end

function SaveAdjust.remove_hidden_kits(tree, event)
  local facts = PurgeKits.facts()
  if facts.count == 0 then return { error = "no active mod hides a kit" } end
  local action = "remove_hidden_kits (slot " .. event.slot .. ")"
  local report = PurgeKits.run(tree, facts)
  log(action .. ": " .. PurgeKits.summary(report))
  for _, line in ipairs(report.lines) do log(action .. ": " .. line) end
  local sets = purge_player_sets(event.slot, function(field, value) return field == "kit" and hidden_kit_value(facts, value) end, action)
  local count = report.removed + sets
  return { count = count, log = count .. " kit(s) removed (" .. PurgeKits.summary(report) .. "; " .. sets .. " in player sets)" }
end
