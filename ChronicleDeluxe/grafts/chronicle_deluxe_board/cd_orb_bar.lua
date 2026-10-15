-- Chronicle Deluxe, the difficulty orb bar of a Chronicle piece (docs/game/mods/chronicle-deluxe.md §8.9): the pill under
-- a piece's crest on the board (vs_route_town_menu) and on each row of the team list (vs_route_town_list_menu), both
-- the layer vsroute01_06c_town_map_piece_clear_icon. Retail draws one pill with a socket per retail difficulty (6 on
-- normal pieces, 3 on gate pieces) and lights the cleared ones. Here the bar has one socket per difficulty the piece
-- offers (VRFW_MatchDifficulty, this mod's content\defaults\match_difficulty.toml), centred under the crest:
--   * the orbs of the difficulties that exist move to the centred slots (18 px apart, the retail spacing), the others
--     are hidden
--   * the pill = a picture with that many sockets (sprites chronicle_deluxe_orb_bar_<context>_<count> of the atlas
--     vsroute01_06c, made at build from the retail pill: content\images\menu\30_vsroute\vsroute01\vsroute01_06c.toml),
--     its quad cut to that width (retail width - 18 per missing socket), centred
-- Without a declared set nothing changes. Included by cd_board_hooks.lua and cd_list_menu.lua (one copy per script VM).
-- Definitions only: nothing calls the engine at load.
ChronicleDeluxe = ChronicleDeluxe or {}
ChronicleDeluxe.OrbBar = ChronicleDeluxe.OrbBar or {}
local O = ChronicleDeluxe.OrbBar
O.CMD = {
  NODE_TRANSLATION = 1856671416,  -- (layer, instance, node, x, y, z)
  NODE_SCALE = 2885415772,        -- (layer, instance, node, width, height): a quad's size in px
  LOCATOR_VISIBLE = 2158717427,   -- (layer, locator, visible, instance)
  SET_SPRITE = 558735651,         -- (layer, atlas, sprite, texture slot, 0, instance)
}
O.ATLAS = "#/menu/30_vsroute/vsroute01/vsroute01_06c/vsroute01_06c.g4tx"
O.SPRITE_PREFIX = "chronicle_deluxe_orb_bar_"
O.SPACING = 18                    -- px between two sockets (retail layout)
-- per eventType of the piece (0 normal, 5 gate): the retail layout vsroute01_06c (v7.1.2) of its pill
O.LAYOUT = {
  [0] = {context = "route", base = 1003654013 --[[_clear_base01]], sprite = "clear_base01_02", width = 124, height = 32,
         base_y = -17, dot_y = -33, slots = 6},
  [5] = {context = "gate", base = 2732317383 --[[_clear_base02]], sprite = "clear_base02_2", width = 68, height = 32,
         base_y = -40, dot_y = -56, slots = 3},
}

-- fit the bar of one instance of the clear-icon layer: kind = the piece's eventType, difficulties[i] / locators[i] =
-- the retail difficulty of slot i and its orb locator (the script's own tables)
function O.Fit(layer, instance, kind, difficulties, locators)
  local lay = O.LAYOUT[kind]
  if lay == nil or difficulties == nil or locators == nil or VRFW_MatchDifficulty == nil then
    return
  end
  local shown = VRFW_MatchDifficulty.Set(lay.context)
  if shown == nil then
    return -- nothing declared: the retail bar
  end
  local kept = {}
  for i = 1, #difficulties do
    if locators[i] ~= nil then
      if shown[difficulties[i]] then
        kept[#kept + 1] = locators[i]
      else
        funcLuaMenuCommand(O.CMD.LOCATOR_VISIBLE, layer, locators[i], false, instance)
      end
    end
  end
  local count = #kept
  if count == 0 or count > lay.slots then
    return
  end
  local first = -(count - 1) * O.SPACING / 2
  for k = 1, count do
    funcLuaMenuCommand(O.CMD.NODE_TRANSLATION, layer, instance, kept[k], first + (k - 1) * O.SPACING, lay.dot_y, 0)
  end
  local sprite = count == lay.slots and lay.sprite or (O.SPRITE_PREFIX .. lay.context .. "_" .. count)
  local width = lay.width - O.SPACING * (lay.slots - count)
  funcLuaMenuCommand(O.CMD.SET_SPRITE, layer, CRC32(O.ATLAS), CRC32(sprite), CRC32(lay.sprite), 0, instance)
  funcLuaMenuCommand(O.CMD.NODE_SCALE, layer, instance, lay.base, width, lay.height)
  funcLuaMenuCommand(O.CMD.NODE_TRANSLATION, layer, instance, lay.base, -width / 2, lay.base_y, 0)
end
