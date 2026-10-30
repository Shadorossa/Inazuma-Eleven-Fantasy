-- Chronicle Deluxe: the class orb on each free-match class card (docs/game/mods/chronicle-deluxe-free-match.md §17).
-- With [VRFW.FreeMatch] ClearTicks = false (content\teams\90_rules\free_match.toml) the framework hides the card's
-- clear / advantage-win marks and their box. Each card then shows the orb of its class's colour, the colour the
-- Competition list's «team cleared» orbs use (INAZUMA blue, ZONA LETAL purple, BATALLA LEGENDARIA green-cyan): a fixed
-- colour legend, never a cleared state. The orb is drawn as retail draws the advantage-win mark: a sprite of the card's
-- atlas swapped into the tick slot list_icon_state_comp01 and the tick mesh shown (content\images\menu\30_vsroute\
-- vsroute01\vsroute01_21.toml makes the sprites; content\menus\free_match_class_orbs.toml centres the quad on the box).
-- Runs after the framework's class setup of each row (OnSetupLayer); no engine call at load time.
do
  local setup = OnSetupLayer
  local CARD = 1809045795           -- vsroute01_21_sub_list: the class cards
  local CARD_ATLAS = 3795985350     -- #/menu/30_vsroute/vsroute01/vsroute01_21/vsroute01_21.g4tx
  local TICK_SLOT = 2107860330      -- list_icon_state_comp01
  local TICK_MESH = 3583161402      -- _list_icon_state_comp01
  local SET_SPRITE = 558735651      -- (layer, atlas, sprite, slot, 0, item)
  local SET_MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE
  local ORB_BY_CLASS = {
    [6] = 1950977645,               -- chronicle_deluxe_class_orb_inazuma
    [7] = 3816657784,               -- chronicle_deluxe_class_orb_lethal_zone
    [9] = 1137654499,               -- chronicle_deluxe_class_orb_legendary
  }
  local function show_orb(a1, a2)
    local classes = VRFW_FMC and VRFW_FMC.cache   -- the classes the opponent offers, read by this row's setup
    if type(classes) ~= "table" or type(a2) ~= "number" then return end
    local orb = ORB_BY_CLASS[classes[a2 + 1]]
    if orb == nil then return end
    funcLuaMenuCommand(SET_SPRITE, a1, CARD_ATLAS, orb, TICK_SLOT, 0, a2)
    funcLuaMenuCommand(SET_MESH_VISIBLE, a1, TICK_MESH, true, a2)
  end
  if type(setup) == "function" then
    function OnSetupLayer(a1, a2, ...)
      local r = table.pack(setup(a1, a2, ...))
      if a1 == CARD then pcall(show_orb, a1, a2) end
      return table.unpack(r, 1, r.n)
    end
  end
end
