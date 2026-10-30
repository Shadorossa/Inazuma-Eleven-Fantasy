-- host table of the shared player page (research/grafts/plate_pages): a screen with its own copy of the plate
-- (equip_menu, evt_skill_slot_menu): the header row (slanted position band, archetype box), the white card and the
-- bar chart from the same code; no pages (fixed type 9 = the chart), no description, no model of ours
@ITEMSPEC@
EVT_PPG_HOST = {name = "equip", plate = 607716004, status = 2917320188, graph = 32151736, radar = 2334590304, pages = false, fixed = 9,
  menu = 606230082 --[[equip_menu: its close state shuts our added layers]],
  -- the stats panel at the layout's place (rows 740..875); its white card is the one panel of the item card and the
  -- stats: from the item card's top to under the pager row (535..940)
  card = {985, 535, 1920, 940}}
-- The item detail card (team05_02_equip_info_easy, traced by the status base on _atc_equip01) as one card above the
-- stats panel, as wide as it: the name at the start of the green band with the position chips after it, the E / stock
-- chips at the band's end, the item icon on the right, the bonuses in one row under the band; pages turned with L2 / R2
-- (Better Equipment's «Efecto» and «Conjunto»); the stats rows the item raises / lowers outlined green / red. Screen
-- px, y down; nodes = {node, x, y[, w, h]} from the card's top-left (the node's top-left; w / h = its size).
-- plate_pages.lua G.ItemCard applies it around every SetupEquipInfoWindow.
EVT_PPG_HOST.item_card = {
  layer = 3239909435,                      -- team05_02_equip_info_easy
  root = {1222, 734},                      -- the layer's origin on screen (soccer11_05 _atc_equip01)
  base = 1517329426,                       -- _pos_base01 (every node below hangs on it)
  rect = {985, 535, 1920, 705},            -- the card's left, top, right, bottom (on the stats panel's top)
  card_h = 170,                            -- one height on every page: the band and a two-row body (535..705)
  -- the base (_pos_base01) at this card point: the name and bonus texts are drawn at their layout offsets from it
  -- (name -221, 15 / bonus -229, -59, x right y up), never at their own node's place, so the name starts at x 64 in
  -- the green band (after the item icon) and the bonus rows at x 56 under it
  anchor = {285, 15},
  body_mesh = 2511236049,                  -- _win_item01: off (its drop shadow); the body is layer evt_eq_card_body
  -- the green band 46 px (2..48): the icon, the name, the position badges and the E / stock chips centred in it
  nodes = {
    {2511236049, 0, 0, 935, 214, body = true},          -- _win_item01 (hidden; kept at the card's rect)
    {2885220123, -12, -2, 959, 50},                     -- _win_item_base01 (the green name band: 12 px past the panel
                                                        -- on each side, its sprite's own transparent edge included, and
                                                        -- 2 px over its top; bottom at 48 as before)
    {303536660, 6, 4, 42, 42},                          -- _icon_item_dmy01 (in the band, left of the name)
    {2334051246, 6, 4, 42, 42},                         -- _icon_item_dmy02
    {2203859798, 555, 12, 48, 27},                      -- _icon_position_dmy01 (left of the E chip)
    {441805548, 605, 12, 48, 27},                       -- _icon_position_dmy02 (right-aligned against the E chip)
    {442049775, 659, 8, 0.85, 0.85},                    -- _pos_equip01 (E chip 148 x 40 scaled 0.85, band end)
    {3426045766, 793, 8, 0.85, 0.85},                   -- _pos_have01 (stock chip, scaled 0.85)
    {2336812131, 850, 60},                              -- _pos_chr01 (the face of a character's own item)
    {3174025408, 300, 150},                             -- _pos_body_type_atc01 (kit items only)
  },
  -- once to loader.log («EVT_PPG item card node»): the drawn place of these nodes
  dump = {{1517329426, "_pos_base01"}, {2511236049, "_win_item01"}, {456522680, "_text_item01"},
    {1923430404, "_dmy_item01"}, {3138144965, "_text_parameter01"}, {1139770918, "_dmy_parameter01"},
    {303536660, "_icon_item_dmy01"}},
  -- pages after the bonuses (Better Equipment): «Efecto» and «Conjunto», each only when the item has it
  -- the item picker's hovered item: the menu event its script (equip_menu_list) sends to this one (equip_menu_select)
  picker_event = "CharacterReforged.ItemCardHover", picker_owner = "equip_menu_select", menu = 606230082 --[[equip_menu]],
  text_x = 56,                             -- the bonus box's left edge in the card (anchor x - 229; its top anchor y + 59)
  -- the card's one size (every item and page): `max_rows` text rows from `first_row` (centre) every `row_pitch`,
  -- `bottom` px below the last one; from rect's top
  paged = {first_row = 99, row_pitch = 54, bottom = 30, max_rows = 3},   -- 468 + 99 + 2 x 54 + 30 = 705
  -- the pager under the stats panel, centred on the panel: the framework's page row (VRFW_Pager, layer evt_eq_dots)
  pager = {at = {1452, 912}},              -- its centre (screen px): right under the Suerte row (875)
  -- the stats panel's rows the focused item raises / lowers: an outline around the bar (the row's gauge copy's spare
  -- quad given `sprite`, the bar's rect + `margin`) and the number's colour
  row_mark = {
    sprite = {raise = 3112608773 --[[evt_pp_row_raise]], lower = 259671231 --[[evt_pp_row_lower]]},
    atlas = 2049028641,                    -- #/menu/102_team/team05/evt_eq_fx/evt_eq_fx.g4tx (the card's own atlas, loaded by the bars' object)
    margin = 2,                            -- the border's width: the frame = the bar's rect (180 x 28) + 2 px each side
    number_style = 2612831244,             -- the value prim of evt_pp_num_host
    colour = {raise = {0.2, 0.75, 0.3}, lower = {0.9, 0.2, 0.2}},   -- unchanged rows: the number's own colour
    -- Suerte: its number instance's comparison arrows (soccer11_06_p1 _arrow_l/r_u/d01..03) off, its label (the
    -- extra layer's) given the labels' colour
    -- the focused item's change on the bars: a segment on the bar's spare masked-fill quad (_beans_bar01, slot
    -- beans_bar01), sprites in the card's own atlas; a small label over the number (screen px from the column's left /
    -- the row's centre, colour tags)
    -- icon instances first .. first + count - 1; band = the fill's visible rows of the bar (from its top, of its height:
    -- the gauge fill sprite's rows 5..10 of 16)
    delta = {first = 48, count = 4, band = {0.3125, 0.375}, raise = "evt_eq_fx_delta_up", lower = "evt_eq_fx_delta_down"},
    label = {dx = 338, dy = -22, scale = 0.42, plus = "[CG]", minus = "[CR]"},
    luck_number = 7,
    luck_arrows = {1180371782, 3746716412, 2824170090, 1539293697, 3266745275, 3048317741, 2576032421, 8549151,
      2005222281, 2221927394, 493271640, 1784777422},
    -- the label colour group of the chart layers' CMenuChangeMaterialColor (parameter_name_gtxt) and the labels'
    -- colour the retail graph gives it (include/soccer/soccer_common UpdateCharaParameterGraph*: 20, 75, 130)
    label_group = 3659653428, label_colour = {0.0784313725490196, 0.29411764705882354, 0.5098039215686274},
  },
}
-- 2026-10-06 (Nacho, shot 366): only the chart on the Plantilla page's card (no card = the layout's x 985..1920,
-- y 705..955); the big retail page body is hidden by plate_pages.lua (host branch)
-- 2026-10-06 (exit hang on these hosts): the block off here until the close is fixed (its menu patches are off too)
-- round 14e: on again (host page object without the player page's attach rows; our layers closed on back)
-- 2026-10-06: OFF (the close hangs with the block on; being bisected)
if EVT_PPG_HOST_OFF == nil then
  EVT_PPG_HOST_OFF = false
end
