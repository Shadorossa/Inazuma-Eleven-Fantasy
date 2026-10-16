-- New Recruitment: the Chronicle route board's shortcut to the gacha «Universo del jugador» is covered (owner request
-- 2026-10-16). The board's bottom-left buttons are the instances of layer 1423637364: instance 0 («Tab», the
-- constellation icon) runs OpenUniverse (a click: OnEnter; the key and the pad button: OnFunction 2567875605), which
-- sends the board to the Chronicle top menu, and that menu opens players_universe_menu; instance 1 («Alt») is the other
-- button and stays. While NewRecruitment.Applies() holds (not in a mode's reserved slot):
--   * OpenUniverse does nothing (every way to it goes through that global);
--   * instance 0 of the layer is hidden after its setup and every open of the layer.
-- Handlers of the framework's board host (VRFW_Host); nothing runs at load but their registration.
if VRFW_Host ~= nil and type(NewRecruitment) == "table" then
  local STEM = "vs_route_town_menu"
  local BUTTONS_LAYER = 1423637364        -- the bottom-left Tab / Alt buttons
  local UNIVERSE_BUTTON = 0
  local SET_LAYER_VISIBLE = 711242136     -- CMND_SET_LAYER_VISIBLE (layer, instance, visible)

  local function covered()
    local ok, yes = pcall(NewRecruitment.Applies)
    return ok and yes == true
  end

  VRFW_Host.on(STEM, "OpenUniverse", {
    id = "new_recruitment.universe_key", phase = "around",
    fn = function(nxt, ...)
      if covered() then
        return
      end
      return nxt(...)
    end,
  })

  for _, point in ipairs({"OnSetupLayer", "OnOpenLayer"}) do
    VRFW_Host.on(STEM, point, {
      id = "new_recruitment.universe_button_" .. point, phase = "after",
      fn = function(_, layer, instance)
        if layer == BUTTONS_LAYER and instance == UNIVERSE_BUTTON and covered() then
          pcall(funcLuaMenuCommand, SET_LAYER_VISIBLE, layer, instance, false)
        end
      end,
    })
  end
end
