-- No More Rarities › the «Rareza» tab (graft no_more_rarities_filter). Every normal card is rarity 4 and the tab has
-- no box for it (it lists from rarity 5 on), so a specific rarity set always lets rarity 4 through; the removed
-- rarities 0-3 that older saved sets still hold are dropped. The special cards the option removes
-- (NoMoreRarities.RarityRemoved: Ídolo 5-7 / Diamante 8) look like normal cards, so a specific set lets them through
-- too (their boxes stay listed: the tab's list start is the config's first_listed_rarity). «Todos» passes everything
-- as in the game.
local NORMAL_CARD_RARITY = 4
local FILTER_KIND_RARITY = 5          -- listItemType of a rarity box
local FILTER_KIND_ALL = 9             -- listItemType of a «Todos» box (its value = the tab's kind)
local RARITY_OPTION = 0
-- only while the rarity removal applies (NoMoreRarities.RarityRemovalApplies, the mod's lua\_all): never in a reserved
-- slot, a mode's own save such as INAROGUE's, where the filter works as in the game
local function rarity_removal_applies()
  local rules = rawget(_ENV, "NoMoreRarities")
  return type(rules) ~= "table" or type(rules.RarityRemovalApplies) ~= "function" or rules.RarityRemovalApplies()
end
local function holds_rarity(params, rarity)
  if params ~= nil then
    for i = 1, #params do
      local p = params[i]
      if p.listItemType == FILTER_KIND_RARITY and p.option == RARITY_OPTION and p.value == rarity then
        return true
      end
    end
  end
  return false
end
-- the rarities a specific set always lets through: the normal card's and every special one the option removes
local function always_passing()
  local out = {NORMAL_CARD_RARITY}
  local rules = rawget(_ENV, "NoMoreRarities")
  if type(rules) == "table" and type(rules.RarityRemoved) == "function" and type(rules.LAST_REMOVABLE_RARITY) == "number" then
    for rarity = NORMAL_CARD_RARITY + 1, rules.LAST_REMOVABLE_RARITY do
      if rules.RarityRemoved(rarity) then
        out[#out + 1] = rarity
      end
    end
  end
  return out
end
local function is_specific_rarity_set(params)
  local specific, everything = false, false
  if params ~= nil then
    for i = 1, #params do
      local p = params[i]
      if p.listItemType == FILTER_KIND_ALL and p.value == FILTER_KIND_RARITY then
        everything = true
      elseif p.listItemType == FILTER_KIND_RARITY and p.option == RARITY_OPTION then
        specific = true
      end
    end
  end
  return specific and not everything
end
local previous_add_filter_param = @MENU@.AddFilterParam
function @MENU@.AddFilterParam(kind, value, option)
  if kind == FILTER_KIND_RARITY and option == RARITY_OPTION and type(value) == "number" and value < NORMAL_CARD_RARITY
      and rarity_removal_applies() then
    return
  end
  return previous_add_filter_param(kind, value, option)
end
local previous_create_send_filter_param_array = @MENU@.CreateSendFilterParamArray
function @MENU@.CreateSendFilterParamArray(params)
  local result = previous_create_send_filter_param_array(params)
  if is_specific_rarity_set(params) and rarity_removal_applies() then
    for _, rarity in ipairs(always_passing()) do
      if not holds_rarity(params, rarity) then
        table.insert(result, FILTER_KIND_RARITY)
        table.insert(result, rarity)
        table.insert(result, RARITY_OPTION)
      end
    end
  end
  return result
end
