-- Utilities neutral element: pre-match formation (soccer_battle_setting_flow_formation_menu): GetCharaElementIconName(chara
-- status handle) answers 0 for element 0 / 5 in retail; the neutral sprite icon_cmd_type00 instead.
local UTIL_NE_prev_GetCharaElementIconName = GetCharaElementIconName
function GetCharaElementIconName(a1, ...)
  local r = UTIL_NE_prev_GetCharaElementIconName(a1, ...)
  if r == 0 and a1 ~= nil and a1 ~= 0 then
    local el = funcLuaCommand(1131797651, a1, 8)
    if el == 0 or el == 5 then
      return @crc:icon_cmd_type00@
    end
  end
  return r
end
