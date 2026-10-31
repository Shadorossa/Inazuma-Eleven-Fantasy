-- VRFW_CharaIcons: a card's position icon and element icon as a texture path and a sprite id, the same sprites the
-- team screen and the player bank show. Definitions only (this file runs in every menu VM, lua\_all); no engine call
-- at load. Answers are kept per card, so a screen may ask on every draw.
--   VRFW_CharaIcons.Position(card) -> { tex, sprite } | nil   the card's main position badge
--       (CMND_GET_CHARA_INFO(card, 11): 1 GK, 2 FW, 3 MF, 4 DF -> icon type 0 GK, 1 DF, 2 MF, 3 FW), sprite from the
--       game's GetSoccerCharaPositionIconByPosIconType, else the atlas sprite icon_position0<type + 1>; the atlas is
--       the language's folder of 15_icon_common2 (CMND_GET_LANGUAGE_CODE)
--   VRFW_CharaIcons.Element(card) -> { tex, sprite } | nil    the card's element icon (CMND_GET_CHARA_INFO(card, 13):
--       1..4, 0 / 5 = the neutral icon), sprite from the game's GetCharaElementIconNameByCharaParamId, else the atlas
--       sprite icon_cmd_type0<element> of 15_icon_common
--   tex is the atlas path (load it as any other menu texture), sprite the sprite's crc32.
-- One log line the first time a game function is missing in this VM and the atlas lookup is used instead.
if VRFW_CharaIcons == nil then
  local I = {
    CHARA_INFO = 4060384944,     -- CMND_GET_CHARA_INFO (card, field) -> ok, value
    LANG = 477234096,            -- CMND_GET_LANGUAGE_CODE -> the game's language table index
    LOG = VRFW_Cmd.EVT_LOG,
    -- the game's language table index -> its folder of the per-language menu atlases
    LANG_DIR = {[0] = "ja", [1] = "en", [2] = "fr", [3] = "es", [4] = "pt", [6] = "de", [7] = "it", [16] = "zh_hant",
      [17] = "zh_hans"},
    POSITION_TEX = "#/menu/200_icon/15_icon_common2/%s/icon_common2.g4tx",
    POSITION_SPRITE = "icon_position0%d",
    ELEMENT_TEX = "#/menu/200_icon/15_icon_common/icon_common.g4tx",
    ELEMENT_SPRITE = "icon_cmd_type0%d",
    ICON_TYPE = {[1] = 0, [2] = 3, [3] = 2, [4] = 1},   -- card position -> position icon type
    positions = {},              -- card -> answer (false = none)
    elements = {},
    lang = nil,
    told = {},                   -- the missing game functions already logged
  }
  VRFW_CharaIcons = I

  local function crc(s)
    if type(CRC32) == "function" then
      return CRC32(s)
    end
    return nil
  end

  local function info(card, field)
    local okc, ok, v = pcall(funcLuaCommand, I.CHARA_INFO, card, field)
    if okc and ok ~= false and type(v) == "number" then
      return v
    end
    return nil
  end

  local function tell(name)
    if I.told[name] then
      return
    end
    I.told[name] = true
    pcall(funcLuaCommand, I.LOG, "VRFW chara_icons " .. name .. " is not in this menu VM: the atlas sprite is used")
  end

  local function lang_dir()
    if I.lang == nil then
      local ok, code = pcall(funcLuaCommand, I.LANG)
      I.lang = ok and I.LANG_DIR[code] or "en"
      pcall(funcLuaCommand, I.LOG, "VRFW chara_icons language folder " .. I.lang)
    end
    return I.lang
  end

  function I.Position(card)
    if type(card) ~= "number" or card == 0 then
      return nil
    end
    local v = I.positions[card]
    if v == nil then
      local t = I.ICON_TYPE[info(card, 11)]
      v = false
      if t ~= nil then
        local sprite
        if type(GetSoccerCharaPositionIconByPosIconType) == "function" then
          local ok, s = pcall(GetSoccerCharaPositionIconByPosIconType, t)
          if ok and type(s) == "number" and s ~= 0 then
            sprite = s
          end
        else
          tell("GetSoccerCharaPositionIconByPosIconType")
        end
        sprite = sprite or crc(string.format(I.POSITION_SPRITE, t + 1))
        if sprite then
          v = {tex = string.format(I.POSITION_TEX, lang_dir()), sprite = sprite}
        end
      end
      I.positions[card] = v
    end
    return v or nil
  end

  function I.Element(card)
    if type(card) ~= "number" or card == 0 then
      return nil
    end
    local v = I.elements[card]
    if v == nil then
      local el = info(card, 13)
      v = false
      if el ~= nil then
        local sprite
        if type(GetCharaElementIconNameByCharaParamId) == "function" then
          local ok, s = pcall(GetCharaElementIconNameByCharaParamId, card)
          if ok and type(s) == "string" and s ~= "" then
            sprite = crc(s)
          elseif ok and type(s) == "number" and s ~= 0 then
            sprite = s
          end
        else
          tell("GetCharaElementIconNameByCharaParamId")
        end
        if sprite == nil then
          sprite = crc(string.format(I.ELEMENT_SPRITE, (el >= 1 and el <= 4) and el or 0))
        end
        if sprite then
          v = {tex = I.ELEMENT_TEX, sprite = sprite}
        end
      end
      I.elements[card] = v
    end
    return v or nil
  end
end
