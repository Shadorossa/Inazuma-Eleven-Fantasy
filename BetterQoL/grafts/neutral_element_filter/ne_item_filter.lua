-- Utilities neutral element: item filter window, element tab (list item type 4). Retail draws the fifth entry
-- («Neutro», value 5) as a plain name on the text row; the name gets the neutral text icon in front of it, as the
-- four element rows show their element icon. The label is the retail text of that entry.
local UTIL_NE_prev_FilterUpdateItem = UpdateItem
local UTIL_NE_FILTER_NEUTRAL_TEXT = 3339176265
function UpdateItem(a1, a2, a3, a4, a5)
  local r = table.pack(UTIL_NE_prev_FilterUpdateItem(a1, a2, a3, a4, a5))
  if a3 == 4 and a4 == 5 then
    local label = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], UTIL_NE_FILTER_NEUTRAL_TEXT)
    if type(label) ~= "string" then
      label = ""
    end
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], a1, 1704438437 --[[_text_name01]], "[$gaiji_cmd_type00] " .. label, a2)
  end
  return table.unpack(r, 1, r.n)
end
