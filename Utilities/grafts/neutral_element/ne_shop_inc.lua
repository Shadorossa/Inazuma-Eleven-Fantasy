-- Utilities neutral element: child of the retail shop_inc bytecode (INCLUDE'd by the shop / office / bank / formation
-- search menus). Retail GetElementIconTexture answers nil for an element outside 1..4, so SetElementIcon skips the
-- sprite swap and a reused list row keeps the previous player's element icon. Characters with element 0 / 5 get the
-- neutral sprite icon_cmd_type00 (research/scripts/neutral_element_build.py). Only wraps a Lua global at load.
UTIL_NEUTRAL_SHOP = UTIL_NEUTRAL_SHOP or {prev = nil}
if UTIL_NEUTRAL_SHOP.prev == nil then
  UTIL_NEUTRAL_SHOP.prev = GetElementIconTexture
end
if UTIL_NEUTRAL_SHOP.prev ~= nil then
  function GetElementIconTexture(a1, ...)
    if a1 == 0 or a1 == 5 then
      return {{icon_cmd_type00}}
    end
    return UTIL_NEUTRAL_SHOP.prev(a1, ...)
  end
end
