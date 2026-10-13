-- BetterUI (mod clean_hud, prefix BetterUI): the names other mods' game Lua may use, as one global table `BetterUI`
-- in every menu VM (this file runs in every VM). The old globals stay as they are (aliases, still read by other mods'
-- grafts): CLEAN_HUD_TopBarOn, CLEAN_HUD_SS_CO, CLEAN_HUD_PC_*, CLEAN_HUD_SHIRT_NUMBER. Each name below looks its
-- global up when called (the grafts that define them run in their own menus, in any order), and answers nil / false
-- when that graft is not in this VM. Declared in mod.toml [exports]. Defines functions only; nothing runs at load.
--
--   BetterUI.TopBarOn()                      the gate of the top bar shortcuts (= CLEAN_HUD_TopBarOn, defined by
--                                             Utilities since BetterUI 1.21.0 = Utilities.TopBarOn; nil without it)
--   BetterUI.ShopSwitching()                 true while the shop shortcuts (L2 / R2) are leaving the shop (shop
--                                             menus; = CLEAN_HUD_SS_CO ~= nil)
--   BetterUI.CardIsLayer(layer)              the compact player cards (formation screens, soccer_common VMs):
--   BetterUI.CardIsCompact(call, layer, idx)   = CLEAN_HUD_PC_IsCardLayer / _IsCompact / _HideName / _KeepName
--   BetterUI.CardHideName(call, layer, idx)
--   BetterUI.CardKeepName(layer, idx)
--   BetterUI.ShirtNumberOn()                 the team shirt-number screen is on (= CLEAN_HUD_SHIRT_NUMBER.On())
--   BetterUI.ShirtNumberArm()                arm it before opening the celebration list (= CLEAN_HUD_SHIRT_NUMBER.Arm())

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

BetterUI.ShirtNumberOn = member("CLEAN_HUD_SHIRT_NUMBER", "On")
BetterUI.ShirtNumberArm = member("CLEAN_HUD_SHIRT_NUMBER", "Arm")

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

-- «Clear View» until 1.17.1: the old prefix stays as an alias of the same table (game Lua of other mods / old grafts).
ClearView = BetterUI
