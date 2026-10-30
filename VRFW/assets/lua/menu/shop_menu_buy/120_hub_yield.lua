-- VR-Framework › a shop over a hub other than the Mercado. Handlers of the framework's shop_menu_buy host (VRFW_Host, 000_host.lua); no engine call at load time.
--
-- A shop opened from the Mercado draws no header of its own (retail OnSetupLayer hides shop_menu's header when the
-- Mercado's background exists) and the Mercado hides itself. Opened from any other hub (the Chronicle hub's «Tienda
-- general», «Modos de juego», a top bar shortcut...), the shop shows its own header and button guide and the hub stays
-- drawn under it: with a compact header the hub's big mode title, its header and its prompts
-- showed through. The hub now yields its chrome (VRFW_HubYield, lua\menu\_all\63_hub_yield.lua, run in the hub's own
-- VM) while the shop is up, and gets exactly that back when the shop's background closes or the menu ends. The Mercado
-- (839500579) is left alone: the shop uses its header.
if VRFW_Host ~= nil then
  local SHOP = 3170360552            -- shop_menu (this script: shop_menu_buy)
  local MARKET = 839500579           -- market_menu
  local BG = 717014739               -- shop01_00_background: its close = the shop is going
  local HY = {hub = nil, on = false}
  VRFW_ShopHubYield = HY

  local function Log(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    pcall(funcLuaCommand, VRFW_Cmd.EVT_LOG, "vrfw.ShopHubYield " .. table.concat(t, " "))
  end

  local function Yield(on)
    if on == HY.on then
      return
    end
    if on then
      local ok, parent = pcall(function() return MENU_DEF.GetParentMenuID(SHOP) end)
      if not ok or type(parent) ~= "number" or parent == 0 or parent == MARKET then
        Log("hub", tostring(parent), "not yielded (none or the Mercado)")
        return
      end
      -- the retail rule of the shop's own header: hidden while the Mercado's background is open (the office and its
      -- team pages open over the Mercado and use its header): nothing to yield then
      local okm, market = pcall(funcLuaCommand, VRFW_Cmd.IS_OPEN_MENU_OBJECT, MARKET, 717014739)
      if okm and market then
        Log("hub", parent, "not yielded (over the Mercado)")
        return
      end
      HY.hub = parent
    end
    HY.on = on
    if HY.hub == nil then
      return
    end
    local ok, n = pcall(funcLuaCommand, 830228314 --[[run a function in another menu's VM]], HY.hub, "VRFW_HubYield", on, SHOP)
    Log(on and "yield" or "give back", "hub", HY.hub, tostring(ok), tostring(n))
    if not on then
      HY.hub = nil
    end
  end

  VRFW_Host.on("shop_menu_buy", "OnInit", {id = "vr_framework.shop_hub_yield_init", phase = "after", fn = function(r, ...)
    HY.hub, HY.on = nil, false
    pcall(Yield, true)
  end})
  VRFW_Host.on("shop_menu_buy", "OnCloseLayer", {id = "vr_framework.shop_hub_yield_close", phase = "before",
    create = true, fn = function(a1, ...)
      if a1 == BG then
        pcall(Yield, false)
      end
    end})
  VRFW_Host.on("shop_menu_buy", "FinalizeMenu", {id = "vr_framework.shop_hub_yield_end", phase = "before",
    create = true, fn = function(...)
      pcall(Yield, false)
    end})
end
