-- No More Rarities: the player-spirit rows of the drop-rate list («Tasa de aparición» / «Detalles de espíritus y
-- objetos», menu vs_route_town_drop_rate_list_menu) in the player's POSITION colour, the colour scheme of the player
-- page's header band (no_more_rarities_header.lua): POR gold, DF blue, MC green, DL red. Owner request 2026-10-14:
-- with this mod every normal player has the same rarity, so the rarity-coloured band (the orange 5★ pattern on every
-- row) says nothing; the position does.
--
-- The retail row (UpdateListItem_DropChara(layer, instance, dirty, focused, chara, ..., rarity)) paints its band with
-- the rarity's sprite of win05_38 (list_drop_chr_rarity01..08) on the texture slot list_drop_chr_rarity01. After it, a
-- row of a removed rarity (NoMoreRarities.RarityRemoved: 0-4 always, the Ídolo variants 5-7 by the option) gets the band of his
-- position look, from the mod's one shared helper NoMoreRarities.PositionColour (no_more_rarities_card_look.lua: the
-- card's own position, the VR-Framework's rule; nil = the retail look: a reserved slot such as INAROGUE's, a special
-- card, staff, an unknown position), the card being the spirit's (CMND_GET_SPIRIT_CHARA_PARAM_ID(chara, rarity), what
-- the retail detail plate shows). The band of each look (DROP_BAND_OF_LOOK, by the look's key):
--   goalkeeper  list_drop_chr_rarity04 (the game's gold band)   defender  list_drop_chr_rarity02 (blue)
--   midfielder  list_drop_chr_rarity01 (green)                  forward   DROP_BAND_FORWARD_SPRITE (red: the game's
--                                                                         green band with its hue turned, made by
--                                                                         no_more_rarities_build.py)
-- Owned players' spirits leave the list and the drop itself through the VR-Framework when the module New Recruitment
-- is on ([VRFW.DropList.Spirits] of its content\items\drop_list.toml, docs/framework/drops.md §5b): nothing of that here.
-- Defines functions only; engine calls only when a row is drawn; every call goes through pcall.
local DROP_BAND_FORWARD_SPRITE = "no_more_rarities_drop_band_forward"

NoMoreRarities = type(NoMoreRarities) == "table" and NoMoreRarities or {}
if type(rawget(_ENV, "UpdateListItem_DropChara")) == "function" and NoMoreRarities.DropList == nil then
  local D = {}
  NoMoreRarities.DropList = D
  local ROW_TEXTURE = 2268931645         -- #/menu/10_win/win05/win05_38/<LG>/win05_38.g4tx
  local BAND_SLOT = 94010567             -- list_drop_chr_rarity01: the band mesh's texture slot
  local SWAP_SPRITE = 558735651          -- (layer, texture, sprite, slot, 0, instance)
  local SPIRIT_CARD = VRFW_Cmd.GET_SPIRIT_CHARA_PARAM_ID         -- (chara, rarity) -> the spirit's card
  -- the row band of each position look (NoMoreRarities.POSITION_LOOKS key); the forward's crc made on first use
  local DROP_BAND_OF_LOOK = {
    goalkeeper = 1978697800,             -- list_drop_chr_rarity04 (gold)
    defender = 2626891133,               -- list_drop_chr_rarity02 (blue)
    midfielder = 94010567,               -- list_drop_chr_rarity01 (green)
    forward = DROP_BAND_FORWARD_SPRITE,
  }

  local function Crc(text)
    local crc = 0xFFFFFFFF
    for i = 1, #text do
      crc = bit32.bxor(crc, string.byte(text, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then
          crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
        else
          crc = bit32.rshift(crc, 1)
        end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end

  local function BandOf(look)
    local band = type(look) == "table" and DROP_BAND_OF_LOOK[look.key] or nil
    if type(band) == "string" then
      band = Crc(band)
      DROP_BAND_OF_LOOK[look.key] = band
    end
    return band
  end

  -- the band of one drawn row: true when it was swapped
  function D.Paint(layer, instance, chara, rarity)
    if type(chara) ~= "number" or chara == 0 or type(NoMoreRarities.RarityRemoved) ~= "function"
        or not NoMoreRarities.RarityRemoved(rarity) then
      return false
    end
    if type(NoMoreRarities.PositionColour) ~= "function" then
      return false
    end
    local ok, card = pcall(funcLuaCommand, SPIRIT_CARD, chara, rarity)
    if not ok or type(card) ~= "number" or card == 0 then
      return false
    end
    local okLook, look = pcall(NoMoreRarities.PositionColour, {charaParamId = card, rarity = rarity})
    local band = okLook and BandOf(look) or nil
    if band == nil then
      return false
    end
    local command = type(NoMoreRarities.RawMenuCommand) == "function" and NoMoreRarities.RawMenuCommand() or funcLuaMenuCommand
    return (pcall(command, SWAP_SPRITE, layer, ROW_TEXTURE, band, BAND_SLOT, 0, instance))
  end

  local retail_row = UpdateListItem_DropChara
  function UpdateListItem_DropChara(layer, instance, dirty, focused, chara, a6, a7, rarity, ...)
    -- the retail row repaints its band when dirty, or (its flag4) on the focused row after a tab change, which the
    -- VR-Framework's drop list graft mirrors as VRFW_DropList.forced
    local redrawn = dirty or (focused and type(VRFW_DropList) == "table" and VRFW_DropList.forced == true)
    local results = table.pack(retail_row(layer, instance, dirty, focused, chara, a6, a7, rarity, ...))
    if redrawn then
      pcall(D.Paint, layer, instance, chara, rarity)
    end
    return table.unpack(results, 1, results.n)
  end
end
