-- Utilities neutral element: item use (item_use_menu) draws a character row's element with GetElementIcon(status element);
-- in this menu the argument is always a CHARACTER element, so element 0 (not only 5, which soccer_common already maps)
-- gets the neutral sprite icon_cmd_type00.
local UTIL_NE_prev_GetElementIcon = GetElementIcon
function GetElementIcon(a1, ...)
  if a1 == 0 or a1 == 5 then
    return @crc:icon_cmd_type00@
  end
  return UTIL_NE_prev_GetElementIcon(a1, ...)
end
