-- BetterUI (mod clean_hud): the answers of its game Lua commands (content\game\commands.toml). Until 1.16.0
-- clean_hud.dll registered them. Functions only: nothing runs at load. (The pre-match X skip's answers moved to
-- Utilities' scripts\prematch_skip.lua in BetterUI 1.26.0.)

-- CMND_EVT_CHD_TACTIC_SLICES() -> true: the three tactic row slices chd_tactic_row_l / _m / _r are in icon_tactics.g4tx
-- (content\images\menu\200_icon\13_icon_tactics\icon_tactics.toml, made by recipes from the player's files); the
-- graft ui_clean_dock_panel then swaps each tactic box's plate to its slice.
function BetterUI.TacticSlices()
  return true
end

-- The position types of the game's cards (No More Rarities' POSITION_LOOKS keys) by config.toml name.
local POSITION_NAMES = {[0] = "goalkeeper", "defender", "midfielder", "forward"}

-- CMND_BETTERUI_POSITION_LOOK(positionType) -> the position type whose card look `positionType` takes: the one
-- config.toml [position_card_looks] names for it; the same type when the name is missing or unknown.
function BetterUI.PositionLook(positionType)
  local name = POSITION_NAMES[positionType]
  if name == nil then
    return positionType
  end
  local want = VRFW.files.config("position_card_looks." .. name)
  for t, n in pairs(POSITION_NAMES) do
    if n == want then
      return t
    end
  end
  return positionType
end
