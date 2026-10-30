-- Aura Reworked › spirit passive icons: a keshin's own command effect names its icon in column 2 either as a game buff
-- icon type (0-38) or as the crc32 of a sprite of icon_teambuff.g4tx (content/images/menu/200_icon/08_icon_teambuff/
-- spirit_passive_icons.toml). The game's GeTeamBuffIconTextureName answers 0 for a sprite crc: it is the sprite name.
-- No engine call at load time; wrapped again when the include runs again.

AuraReworked = AuraReworked or {}
AuraReworked.SpiritIcons = AuraReworked.SpiritIcons or {}
local S = AuraReworked.SpiritIcons

if type(GeTeamBuffIconTextureName) == "function" and GeTeamBuffIconTextureName ~= S.icon_name then
  local orig = GeTeamBuffIconTextureName
  S.icon_name = function(icon_type, ...)
    local sprite = orig(icon_type, ...)
    if (sprite == nil or sprite == 0) and type(icon_type) == "number" and (icon_type < 0 or icon_type > 65535) then
      if icon_type < 0 then return icon_type + 4294967296 end
      return icon_type
    end
    return sprite
  end
  GeTeamBuffIconTextureName = S.icon_name
end
