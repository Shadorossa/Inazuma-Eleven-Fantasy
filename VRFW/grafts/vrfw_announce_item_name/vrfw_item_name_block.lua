-- ===== VRFW vrfw_announce_item_name BEGIN =====
-- Convert mode for the <ITEM_NAME> placeholder of an item (CMND_TEXT_LOCALIZE_CONVERT): category-160 items
-- (ITEM_SPECIAL_SKILL_INFO: moves, passives, keshin, armed...) carry no name text of their own (cols 2/3 = 0; their
-- name is the linked skill's, col 16), so the item modes 0/1 leave <ITEM_NAME> empty. The retail shop
-- (shop_menu_buy PurchaseConfirmationTextToken) uses mode 155 for category 160 except sub-category 177 (six sense,
-- own name text). Same rule here, so a move manual dropped after a match reads "¡Has obtenido <move>!".
-- VR-Framework (always on, generic: any mod's category-160 items); was Inazuma Fantasy's EVT_ItemNameConvertMode
-- until 2.0.9 (no other code read it, so no alias). Called only from the toast's functions, never at chunk load.
function VRFW_ItemNameConvertMode(itemId, defaultMode)
  local cat = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM?]], itemId, 2)
  local sub = funcLuaCommand(1883585771 --[[CMND_GET_ITEM_PARAM?]], itemId, 3)
  if cat == 160 and sub ~= 177 then
    return 155
  end
  return defaultMode
end
-- ===== VRFW vrfw_announce_item_name END =====
