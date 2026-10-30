-- host table of the shared item card (research/grafts/plate_pages) on the screens that show an item without a player:
-- the inventory «Objetos» (item_menu, card team00_20_item_detail_l) and the shops (shop_menu_buy, card
-- team00_21b_item_detail or shop01_05_item_info). Only the item card part of plate_pages runs here (item_only): no
-- player page, no stats panel. The card is the game's own (never moved); its body under the green band shows the
-- item's pages, turned with Y (VRFW_Pager «ycycle»): the stat changes, Better Equipment's «Efecto» and «Conjunto».
-- Without a player the affinity shows its requirement and both rates, the set its slots and tiers (no worn count).
@ITEMSPEC@
EVT_PPG_HOST = {name = "item_detail", pages = false, item_only = true, fixed = 9, frame_hook = "Step",
  menu = @MENU@,                           -- the screen's menu (its close shuts our added layers)
  chart = false}
EVT_PPG_HOST.item_card = {
  -- the game's item cards of these screens (the one the screen fills is the one shown)
  layers = {3627613836 --[[team00_20_item_detail_l]], 1510257498 --[[team00_21b_item_detail]],
    2939475108 --[[shop01_05_item_info]]},
  layer = 3627613836,
  no_player = true,                        -- no wearer: no ✓ / ✗, no worn count, no stat rows
  relayout = false,                        -- the card stays as the game draws it
  rows = false,
  text_on_icons = true,                    -- the pages' texts on the icon layer; the card's own text line off
  stat_page = true,                        -- first page: the stat changes ([icon] name +N / -N)
  prio_above_card = true,                  -- the icon layer's draw priority from the card's own
  base = 1517329426,                       -- _pos_base01 (the icon instances' text anchor)
  -- the card body under the green band (screen px: left, top, right, bottom)
  rect = {984, 739, 1862, 869},
  card_h = 130,
  text_x = 56,
  paged = {first_row = 30, row_pitch = 50, bottom = 20, max_rows = 2},
  -- the page dots centred at the body's bottom; Y turns the page («Y <next page>» pill, VRFW_Pager ycycle)
  pager = {at = {1423, 858}, style = "ycycle"},
  -- the «Efecto» page in this body: rows centred at row1 / row2 from its top
  effect_at = {row1 = 30, row2 = 86, left = 20, split = 440, right = 858, passive_w = 270, affinity_w = 240},
  set_icons_at = {instances = 44, page_instances = 44, row_cy = 82, margin = 30},
}
if EVT_PPG_HOST_OFF == nil then
  EVT_PPG_HOST_OFF = false
end
