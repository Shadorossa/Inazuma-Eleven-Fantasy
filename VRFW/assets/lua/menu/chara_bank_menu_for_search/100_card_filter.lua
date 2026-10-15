-- card_filter (VR-Framework base feature): the character bank filter header of this screen.
-- the handlers are VRFW_CardFilter.Attach (lua\_all\20_card_filter.lua) on this
-- script's host (000_host.lua). No engine call at load time.
if VRFW_CardFilter ~= nil then
  VRFW_CardFilter.Attach("chara_bank_menu_for_search")
end
