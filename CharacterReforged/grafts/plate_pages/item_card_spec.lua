-- The item card's shared spec (graft plate_pages): what every screen's item card draws the same way, whatever card it
-- sits on (the equipment screen, the inventory, the shop): Better Equipment's commands, the «Efecto» / «Conjunto»
-- pages' sprites, chips and badges, the stat names and icons, the colours. A host's item_card table holds only its own
-- card (layer, rect, pager, places) and overrides a part of the «Efecto» / set layout with effect_at / set_icons_at;
-- plate_pages.lua fills the rest from here. Screen px, y down.
EVT_PPG_ITEM_SPEC = {
  page_command = @crc:CMND_BETTEREQUIPMENT_ITEM_PAGE@,                -- CMND_BETTEREQUIPMENT_ITEM_PAGE (item) -> text, "" = none
  set_command = @crc:CMND_BETTEREQUIPMENT_ITEM_SET@,                 -- CMND_BETTEREQUIPMENT_ITEM_SET (item) -> {name, count, members, tiers, ...}
  -- the set page's icons (layer evt_eq_set_icon, `instances` copies of the item card object): one group per equipment
  -- slot (card px), the slot's icon (the list's sprites icon_equip01..04 of soccer11_08's atlas, green where one of the
  -- set is worn), then the set's pieces of that slot. A piece's slot = its item
  -- category (the retail equipment categories 30 / 40 / 50 / 60, include/menu/equip_menu_inc IsEquipCategory)
  -- the «Efecto» page's position badge (affinity row): the game's position sprites of the item card's badges
  -- (icon_common2 icon_param_position01..04 = FW MF DF GK), `size` px, `gap` around it; `space_px` / `char_px` = the
  -- text widths used when the game gives no measure
  badges = {
    atlas = 2058213660,                    -- #/menu/200_icon/15_icon_common2/<LG>/icon_common2.g4tx
    sprites = {FW = 30648122, MF = 2564486784, DF = 4024288790, GK = 1907970997},
    size = {48, 27}, gap = 6, space_px = 9, char_px = 17,
    dy = -5,                               -- the text line's centre is 5 px above the row centre
  },
  set_icons = {
    -- one row of the set's slot groups (slot icon + its pieces, `gap` apart; `group_gap` between groups), `size` px
    -- pieces, scaled down to fit the card less `margin` each side, centred in the body
    instances = 52, size = 34, gap = 6, group_gap = 20, margin = 40, row_cy = 140,   -- under the title row (96)
    page_instances = 44,                   -- the pages' icons; then 4 delta labels and 4 delta segments (row_mark)
    slot_atlas = 1676671618,               -- #/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx
    slot_swap = 3592622327,                -- win_item_base01 (the icon instance's _win_item_base01 slot)
    -- the slot icons where one of the set is worn: green copies of icon_equip01..04 in the card's own atlas evt_eq_fx
    -- (content/images/menu/item_card.toml, made from the retail sprites)
    worn_atlas = 2049028641,               -- #/menu/102_team/team05/evt_eq_fx/evt_eq_fx.g4tx
    slot_worn_sprites = {2409770440, 154558310, 3261762755, 3748641915},
    slot_size = {40, 44},                  -- as tall as the pieces' icons (one row centre)
    slot_sprites = {2346103015, 316662109, 1708708299, 4223419496},   -- icon_equip01..04 (boots, bracelet, pendant, special)
    slot_of_category = {[30] = 1, [40] = 2, [50] = 3, [60] = 4},
  },
  set_colours = {worn = "[CG]", missing = "[CWG]"},   -- worn pieces / reached tiers; pieces not owned / tiers not reached
  -- the «Efecto» page (plate_pages G.ItemCardEffectItems): card px; rows centred at row1 / row2; sections from `left`
  -- and `split`, chips up to `right`; texts in the name's white style (chips) or the bonus's ink style, scaled
  effect = {
    atlas = 2049028641,                    -- #/menu/102_team/team05/evt_eq_fx/evt_eq_fx.g4tx (this card's own atlas, never a game one)
    row1 = 82, row2 = 134, left = 24, split = 478, right = 911,
    section = 28, sep = {4, 28}, sep_gap = 8, gap = 6, icon = 22, check = 14, badge = {42, 24}, slot = {22, 24},
    chip_h = 30, chip_pad = 10, tier_min = 60, tier_gap = 12, bar_h = 4, bar_gap = 5, bar_pad = 12, text_scale = 0.6,
    plus = "+", off_tag = "[CWG]",
    -- a card without a player (inventory, shop): the stat page's row (`stat_row` from the card body's top; groups
    -- [icon] name value, `stat_gap` apart, texts at `stat_scale`, the row shrunk to fit) and the set page's title row
    stat_row = 40, stat_gap = 34, stat_scale = 0.7, title_y = 30, title_scale = 0.62,
    passive_w = 300, affinity_w = 270,     -- the chips' widths at least (B3v13)
    -- the tier chips: taller, the reward (`tier_scale`) centred `reward_dy` above the row centre, the bars `bar_dy` below
    tier_h = 36, tier_scale = 0.5, tier_scale_min = 0.36, reward_dy = -5, bar_dy = 9,
    -- the game's «<stat> +<VALUE>» texts of stats 0..7 (include/menu/equip_menu_inc): a stat's own name in the chips
    stat_texts = {3905596903, 1084668705, 1047492482, 2352972234, 2604963209, 614355554, 2718198818, 1241387599},
    -- draw order inside the icon layer (CMND_SET_DRAW_PRIORITY per instance): chips under their icons, bars and texts
    prio_under = 552, prio_over = 556,
    styles = {
      white = {node = 456522680, at = {-221, 15}, box_h = 50, char_px = 18, dy = 2},   -- _text_item01 (the name)
      ink = {node = 3138144965, at = {-229, -59}, box_h = 50, char_px = 17},     -- _text_parameter01 (the bonus)
    },
    sprites = {
      bond = "evt_eq_fx_bond", emblem = "evt_eq_fx_emblem", equip = "evt_eq_fx_equip", sep = "evt_eq_fx_sep",
      check = "evt_eq_fx_check", chip_on = "evt_eq_fx_chip_green", chip_blue = "evt_eq_fx_chip_blue",
      chip_off = "evt_eq_fx_chip_off", bar_on = "evt_eq_fx_bar_on", bar_off = "evt_eq_fx_bar_off",
      bar_white = "evt_eq_fx_bar_white", element = "evt_eq_fx_el%02d", element_off = "evt_eq_fx_el%02d_off",
      stat = "evt_eq_fx_stat%s", position = "icon_param2_position%02d", position_off = "evt_eq_fx_pos%02d_off",
    },
    -- the game's icon orders: elements (icon_cmd_type01..04), positions (icon_param2_position01..04 = FW MF DF GK),
    -- stats (icon_btl02_parameter01..07, as the mock-ups)
    elements = {wind = 1, forest = 2, fire = 3, mountain = 4},
    -- the game's element names (common/text/<lang>/menu_text: the player's «Afinidad» names, and «Neutro» for the fifth)
    element_texts = {wind = 450194284, forest = 1565306319, fire = 1660958301, mountain = 191660811, void = 3339176265},
    positions = {FW = 1, MF = 2, DF = 3, GK = 4},
    -- the game's GK badge is dark letters on a near-white plate (bare text on the white card): the card's own badge, the
    -- DF plate in the GK colour (research/scripts/item_card_gk_badge.py)
    position_own = {GK = "evt_eq_fx_pos04_on"},
    stat_icons = {kick = "01", control = "02", technique = "03", pressure = "04", physical = "05",
      intelligence = "06", agility = "07"},
  },

  bonus_gap = "   ",                       -- between two bonuses of the row
  plus_colour = "[CG]",                    -- font colour tags of a raise / a lowering ([C] ends them)
  minus_colour = "[CR]",
  -- the stat keys of the equipment stat indices 0..6 (CMND_GET_EQUIP_PARAM order), for the stat icons
  stat_by_index = {"kick", "control", "technique", "pressure", "physical", "agility", "intelligence"},
}
