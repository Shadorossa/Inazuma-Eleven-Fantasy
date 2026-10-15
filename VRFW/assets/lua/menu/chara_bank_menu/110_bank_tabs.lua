-- bank_tabs (VR-Framework base feature): the extra series tabs the mods declare ([[bank_tab]] of card_filters\)
-- on this screen's tab bar.; the handlers are VRFW_BankTabs.Attach
-- (lua\_all\21_bank_tabs.lua) on this script's host (000_host.lua). No engine call at load time.
if VRFW_BankTabs ~= nil then
  VRFW_BankTabs.Attach("chara_bank_menu")
end
