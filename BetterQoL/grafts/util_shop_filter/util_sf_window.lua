-- Utilities shop_filter, window side (docs/game/modes/tienda-general.md §15). The retail item filter window counts the
-- player's own items (native GetItemCount over the inventory). Opened from a shop (the menu that receives the params,
-- param store 2640949932, is shop_menu), its counter shows the rows of the shop tab instead: shown / total from
-- utilities.dll (CMND_BETTERQOL_SHOP_FILTER_COUNT, the engine's own item test over the tab's rows), and the accept button
-- is refused (error sound) while no row would be left, so a shop tab is never emptied. Everything else (tabs, boxes,
-- «all», reset, texts in the 9 languages) is the retail window. Shop side: util_sf_shop.lua. Globals only (no chunk
-- locals).
UTIL_SF_FROM_SHOP = false
UTIL_SF_SHOWN = -1
-- Checkboxes (28/09, Nacho: every box, «all» included, opened UNCHECKED and only turned checked when the cursor
-- passed over it). The shop sends the tab's params right after the window reports open; the list rows were already
-- drawn with the still empty param array, and the retail OnAfterReceiveFilterParam only updates the counter, so each
-- row kept its unchecked sprite until a focus change redrew it. After the params arrive, the list is redrawn (the
-- retail «toggle a box» refresh 4114514990) at once and again a few frames later (the rows can still be building).
UTIL_SF_REDRAW = {}

function UTIL_SF_Redraw()
  funcLuaMenuCommand(4114514990, 758265787 --[[win07_01_item_filter_list]], false)
  UpdateItemCount()
end

do
  local init = OnInit
  function OnInit(...)
    UTIL_SF_FROM_SHOP = false
    UTIL_SF_SHOWN = -1
    if funcLuaCommand(2947612279, 2640949932) and funcLuaCommand(3522198769, 2640949932) == 3170360552 --[[shop_menu]] then
      UTIL_SF_FROM_SHOP = true
    end
    return init(...)
  end
  local count = UpdateItemCount
  function UpdateItemCount(...)
    if not UTIL_SF_FROM_SHOP then
      return count(...)
    end
    local flat = CreateSendFilterParamArray(GetFilterParamArray())
    local ok, shown, total = pcall(funcLuaCommand, 2721607605 --[[CMND_BETTERQOL_SHOP_FILTER_COUNT]], GetInventoryType(), table.unpack(flat))
    if not ok or type(shown) ~= "number" or type(total) ~= "number" then
      UTIL_SF_SHOWN = -1
      return count(...)
    end
    UTIL_SF_SHOWN = shown
    local idx = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX?]], 758265787 --[[win07_01_item_filter_list]], 0, 2872982514)
    funcLuaMenuCommand(3609943765, 758265787 --[[win07_01_item_filter_list]], 0, idx, shown)
    idx = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX?]], 758265787 --[[win07_01_item_filter_list]], 0, 119370028)
    funcLuaMenuCommand(3609943765, 758265787 --[[win07_01_item_filter_list]], 0, idx, total)
  end
  local after = OnAfterReceiveFilterParam
  function OnAfterReceiveFilterParam(...)
    local r = table.pack(after(...))
    if UTIL_SF_FROM_SHOP then
      UTIL_SF_Redraw()
      UTIL_SF_REDRAW = {2, 6, 15}
    end
    return table.unpack(r, 1, r.n)
  end
  -- item_filter_menu has no Step of its own
  local step = Step
  function Step(...)
    local r = step ~= nil and table.pack(step(...)) or {n = 0}
    if #UTIL_SF_REDRAW > 0 then
      for i = 1, #UTIL_SF_REDRAW do
        UTIL_SF_REDRAW[i] = UTIL_SF_REDRAW[i] - 1
      end
      if UTIL_SF_REDRAW[1] <= 0 then
        table.remove(UTIL_SF_REDRAW, 1)
        UTIL_SF_Redraw()
      end
    end
    return table.unpack(r, 1, r.n)
  end
  local fn = OnFunction
  function OnFunction(a1, a2, ...)
    if a1 == 564758500 and UTIL_SF_FROM_SHOP and UTIL_SF_SHOWN == 0 then
      funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
      return
    end
    local r = table.pack(fn(a1, a2, ...))
    -- reset (1319857620) / «all» (1708665184): the retail redraw, plus one a frame later
    if UTIL_SF_FROM_SHOP and (a1 == 1319857620 or a1 == 1708665184) then
      UTIL_SF_REDRAW = {1}
    end
    return table.unpack(r, 1, r.n)
  end
end
