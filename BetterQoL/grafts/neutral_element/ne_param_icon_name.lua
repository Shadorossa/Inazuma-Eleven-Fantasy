-- Utilities neutral element: GetElementIconTextureName(chara param) answers 0 for element 0 / 5 in retail; the neutral
-- sprite icon_cmd_type00 instead (research/scripts/neutral_element_build.py).
local UTIL_NE_prev_GetElementIconTextureName = GetElementIconTextureName
function GetElementIconTextureName(a1, ...)
  local r = UTIL_NE_prev_GetElementIconTextureName(a1, ...)
  if r == 0 and a1 ~= nil and a1 ~= 0 then
    local ok, el = funcLuaCommand(4060384944 --[[CMND_GET_CHARA_INFO]], a1, 13)
    if ok and (el == 0 or el == 5) then
      return @crc:icon_cmd_type00@
    end
  end
  return r
end
