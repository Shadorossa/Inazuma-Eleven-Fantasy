-- Utilities shop_filter, the banner of the Diamante shop (shop_menu_basara_top: «El atrio de los indomables»,
-- docs/game/modes/tienda-general.md §15.2). The same picture as the other shops' (layer shop01_11_view_staff, the
-- SHOP_INFO header texture put into mesh _shop_cut_chr_dmy01 by OnSetupLayer and shown with _shop_cut_parts01), but
-- this screen is its own script, so util_sf_shop.lua (shop_menu_buy) never reached it: opened over the Mercado (its
-- own header hidden, the Mercado's header and Utilities' top bar stay) the strip was drawn over the top bar icons
-- (owner 2026-10-14). Hidden here exactly as there: at setup, at open and every 20 frames of Step. The screen has no
-- VR-Framework host: its globals are wrapped once each. No engine call at load time.
UTIL_SFB2_LAYER = 4037719016 --[[shop01_11_view_staff]]
UTIL_SFB2_TICK = 0
if UTIL_SFB2_WRAPPED == nil then
  UTIL_SFB2_WRAPPED = {}
end

function UTIL_SFB2_Hide(inst)
  local i = inst or 0
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], UTIL_SFB2_LAYER, 672386185 --[[_shop_cut_chr_dmy01]], false, i)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], UTIL_SFB2_LAYER, 2022610798 --[[_shop_cut_parts01]], false, i)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], UTIL_SFB2_LAYER, i, false)
end

function UTIL_SFB2_Wrap(name, make)
  local cur = _ENV[name]
  if UTIL_SFB2_WRAPPED[cur] then
    return
  end
  local w = make(cur)
  UTIL_SFB2_WRAPPED[w] = true
  _ENV[name] = w
end

local function layer_hook(orig)
  return function(a1, a2, ...)
    local r = table.pack()
    if orig ~= nil then
      r = table.pack(orig(a1, a2, ...))
    end
    if a1 == UTIL_SFB2_LAYER then
      pcall(UTIL_SFB2_Hide, a2)
    end
    return table.unpack(r, 1, r.n)
  end
end

UTIL_SFB2_Wrap("OnSetupLayer", layer_hook)
UTIL_SFB2_Wrap("OnOpenLayer", layer_hook)

UTIL_SFB2_Wrap("Step", function(orig)
  return function(...)
    local r = table.pack()
    if orig ~= nil then
      r = table.pack(orig(...))
    end
    UTIL_SFB2_TICK = UTIL_SFB2_TICK + 1
    if UTIL_SFB2_TICK >= 20 then
      UTIL_SFB2_TICK = 0
      pcall(function()
        if funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER?]], UTIL_SFB2_LAYER) == true
          and funcLuaMenuCommand(1262717583 --[[CMND_IS_LAYER_VISIBLE]], UTIL_SFB2_LAYER, 0) == true then
          UTIL_SFB2_Hide(0)
        end
      end)
    end
    return table.unpack(r, 1, r.n)
  end
end)
