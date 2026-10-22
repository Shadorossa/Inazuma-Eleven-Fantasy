-- BetterUI (mod clean_hud, prefix BetterUI): the names other mods' game Lua may use, as one global table `BetterUI`
-- in every menu VM (this file runs in every VM). The old globals stay as they are (aliases, still read by other mods'
-- grafts): CLEAN_HUD_TopBarOn, CLEAN_HUD_SS_CO, CLEAN_HUD_PC_*, CLEAN_HUD_SHIRT_NUMBER. Each name below looks its
-- global up when called (the grafts that define them run in their own menus, in any order), and answers nil / false
-- when that graft is not in this VM. Declared in mod.toml [exports]. Defines functions only; no engine call at load.
--
--   BetterUI.TopBarOn()                      the gate of the top bar shortcuts (= CLEAN_HUD_TopBarOn, defined by
--                                             Utilities since BetterUI 1.21.0 = BetterQoL.TopBarOn; nil without it)
--   BetterUI.ShopSwitching()                 true while the shop shortcuts (L2 / R2) are leaving the shop (shop
--                                             menus; = CLEAN_HUD_SS_CO ~= nil)
--   BetterUI.CardIsLayer(layer)              the compact player cards (formation screens, soccer_common VMs):
--   BetterUI.CardIsCompact(call, layer, idx)   = CLEAN_HUD_PC_IsCardLayer / _IsCompact / _HideName / _KeepName
--   BetterUI.CardHideName(call, layer, idx)
--   BetterUI.CardKeepName(layer, idx)
--   BetterUI.CardHideLevel(layer, idx)       the level («Nv.» and its number) off on a card another mod draws itself,
--                                             kept off until a card is drawn there again (= CLEAN_HUD_PC_HideLevel)
--   BetterUI.ShirtNumberOn()                 the team shirt-number screen is on (= CLEAN_HUD_SHIRT_NUMBER.On())
--   BetterUI.ShirtNumberArm()                arm it before opening the celebration list (= CLEAN_HUD_SHIRT_NUMBER.Arm())
--   BetterUI.AddDockButton(spec)             a picture button of another mod in «Plantilla de equipo»'s panel, between
--                                             TÁCTICAS and FORMACIÓN, of the synergy buttons' kind (graft
--                                             ui_clean_dock_panel places it and moves the cursor to it). spec = { id =
--                                             "<mod>.<name>", layer = crc32 of the button's layer (the mod adds it to
--                                             soccer_team_dock_menu with input rows UP / DOWN / RIGHT = CMD_FUNCTION
--                                             betterui_dock_button_up / _down / _right, and handles its own ENTER),
--                                             help = text id of its help line, mesh = { node, x, y } a mesh node
--                                             and its layout translation (the scale reference; default the synergy
--                                             plate), center = { x, y } the layer point put on the place (default its
--                                             origin), column = "panel" (the panel's centre; default the synergy
--                                             buttons' column), extra = { layer crc32, … } root layers
--                                             kept on the button's place (its picture), step = function() run every
--                                             Step of the dock (e.g. its open window) }; one button is shown, the
--                                             first registered whose layer is open; the same id replaces it

BetterUI = type(BetterUI) == "table" and BetterUI or {}

local function global(name)
  if type(_G) == "table" then
    return rawget(_G, name)
  end
  return nil
end

local function alias(name)
  return function(...)
    local f = global(name)
    if type(f) == "function" then
      return f(...)
    end
    return nil
  end
end

local function member(name, key)
  return function(...)
    local t = global(name)
    if type(t) == "table" and type(t[key]) == "function" then
      return t[key](...)
    end
    return nil
  end
end

BetterUI.TopBarOn = alias("CLEAN_HUD_TopBarOn")

function BetterUI.ShopSwitching()
  return global("CLEAN_HUD_SS_CO") ~= nil
end

BetterUI.CardIsLayer = alias("CLEAN_HUD_PC_IsCardLayer")
BetterUI.CardIsCompact = alias("CLEAN_HUD_PC_IsCompact")
BetterUI.CardHideName = alias("CLEAN_HUD_PC_HideName")
BetterUI.CardKeepName = alias("CLEAN_HUD_PC_KeepName")
BetterUI.CardHideLevel = alias("CLEAN_HUD_PC_HideLevel")

BetterUI.ShirtNumberOn = member("CLEAN_HUD_SHIRT_NUMBER", "On")
BetterUI.ShirtNumberArm = member("CLEAN_HUD_SHIRT_NUMBER", "Arm")

BetterUI.DockButtons = type(BetterUI.DockButtons) == "table" and BetterUI.DockButtons or {}
function BetterUI.AddDockButton(spec)
  if type(spec) ~= "table" or type(spec.id) ~= "string" or type(spec.layer) ~= "number" then
    return false
  end
  for i, e in ipairs(BetterUI.DockButtons) do
    if e.id == spec.id then
      BetterUI.DockButtons[i] = spec
      return true
    end
  end
  table.insert(BetterUI.DockButtons, spec)
  return true
end

-- The top bar's order (VRFW 10_top_bar.lua reads VRFW_TopBarOrder: entry keys, first = leftmost; a key no active mod
-- declares is skipped, an entry not listed goes after the listed ones in its own `order`). One list for both setups:
--   without Inazuma Fantasy: Crónicas > Partido libre (utilities.competition) > Bahía Batalla > Equipo > Mercado
--   with Inazuma Fantasy:    Crónica > Modos de juego (replaces Competición) > Bahía Batalla > Equipo > Mercado
-- «Modo historia»: no top bar entry exists for it yet (nothing to list).
VRFW_TopBarOrder = {
  "utilities.chronicle", "inazuma_fantasy.cronica",
  "inazuma_fantasy.game_modes", "utilities.competition",
  "utilities.battle_bay", "utilities.my_team", "utilities.market",
}

-- The card colour of each player position (config.toml [position_card_looks]): No More Rarities' one position helper
-- answers the look of the position the config names (CMND_BETTERUI_POSITION_LOOK, asked once per VM at the first look
-- asked, never at load). Every card, plate, header band and drop row coloured by position goes through it.
if type(NoMoreRarities) == "table" and type(NoMoreRarities.PositionLookOfType) == "function"
    and NoMoreRarities.BetterUIPositionLooks == nil then
  local ownLook = NoMoreRarities.PositionLookOfType
  local takes = nil
  NoMoreRarities.BetterUIPositionLooks = true
  NoMoreRarities.PositionLookOfType = function(positionType)
    if takes == nil then
      takes = {}
      for t in pairs(NoMoreRarities.POSITION_LOOKS or {}) do
        local ok, other = pcall(funcLuaCommand, 1217665665 --[[CMND_BETTERUI_POSITION_LOOK]], t)
        takes[t] = ok and type(other) == "number" and NoMoreRarities.POSITION_LOOKS[other] ~= nil and other or t
      end
    end
    if positionType ~= nil and takes[positionType] ~= nil then
      positionType = takes[positionType]
    end
    return ownLook(positionType)
  end
end

-- «Clear View» until 1.17.1: the old prefix stays as an alias of the same table (game Lua of other mods / old grafts).
ClearView = BetterUI
