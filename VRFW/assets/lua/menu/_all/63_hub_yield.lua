-- menu_engine: HUB YIELD. Definitions only: this file
-- runs in every menu VM (lua\_all) after the retail chunk; no engine call at load time.
--
-- A full screen of its own (header, button guide, background) opened over a hub that stays open under it (the
-- Mercado's «Mapa de contactos» opens vrfw_contact_map_menu over market_menu) showed the hub's chrome through and
-- under its own: two titles in the header, two rows of button prompts, the Mercado's COLECCIONABLES panel and its
-- currency counters. Retail child screens of a hub use the hub's header and guide instead of their own; a framework
-- screen has its own, so the hub hides its chrome while the screen is up:
--
--   VRFW_HubYield(on, by)   in the HUB's VM (the screen calls it there: funcLuaCommand(830228314, hub menu,
--                           "VRFW_HubYield", on, its own menu crc)). on = true: every visible instance of the hub's
--                           chrome layers is hidden and remembered; on = false: exactly those are shown again.
--
-- The layers are the retail hub chrome every hub header screen shares (one list, not per hub); a hub without one of
-- them answers 0 instances and is skipped. Callers: vrfw_contact_map_menu (graft contact_map).
if VRFW_HubYield == nil then
  local Y = {
    LAYER_NUM = 1175615627, VISIBLE = 711242136, IS_VISIBLE = 1262717583, LOG = 3661580131,
    LAYERS = {
      575058101,    -- mainmenu90_01_header (title, mode icon, currency counters)
      1138543975,   -- mainmenu01_06_base_button_guide (the prompt row)
      9396745,      -- mainmenu01_07_button_guide
      2005383485,   -- mainmenu01_10_return_arrow_button_guide
      3078308064,   -- mainmenu90_05_content_guide_line01 (the help band)
      3347475721,   -- shop01_03_token_list (the Mercado's COLECCIONABLES panel)
      3286690296,   -- shop01_04d_token_item_5dig (its currency pills)
    },
    hidden = nil,   -- {{layer, idx}, ...} hidden by the last yield
  }
  VRFW_HubYieldState = Y

  function VRFW_HubYield(on, by)
    if on then
      if Y.hidden ~= nil then
        return 0
      end
      Y.hidden = {}
      for _, layer in ipairs(Y.LAYERS) do
        local ok, n = pcall(funcLuaMenuCommand, Y.LAYER_NUM, layer)
        if ok and type(n) == "number" then
          for idx = 0, n - 1 do
            local okv, v = pcall(funcLuaMenuCommand, Y.IS_VISIBLE, layer, idx)
            if okv and v == true then
              pcall(funcLuaMenuCommand, Y.VISIBLE, layer, idx, false)
              Y.hidden[#Y.hidden + 1] = {layer, idx}
            end
          end
        end
      end
      pcall(funcLuaCommand, Y.LOG, "vrfw.HubYield", "hidden", #Y.hidden, "for", tostring(by))
      return #Y.hidden
    end
    local list = Y.hidden or {}
    Y.hidden = nil
    for _, e in ipairs(list) do
      pcall(funcLuaMenuCommand, Y.VISIBLE, e[1], e[2], true)
    end
    pcall(funcLuaCommand, Y.LOG, "vrfw.HubYield", "shown", #list, "for", tostring(by))
    return #list
  end
end
