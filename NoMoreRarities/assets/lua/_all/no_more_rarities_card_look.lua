-- No More Rarities: the normal cards coloured by the player's POSITION, chosen at run time (docs/refactor/aura-mods-split.md
-- «Save pass on load and card look», docs/game/characters/rarity-removal.md §4.6, docs/game/characters/position-cards.md).
-- Owner rule 2026-10-14: the position colours belong to No More Rarities (taken out of Inazuma Fantasy's position_cards):
-- with this mod on, every normal card (rarity 0-4) shows its player's position, the same scheme as the player header
-- (no_more_rarities_header.lua): POR gold, DF blue, MC green, DL red. Without this mod: the retail look. A mode's own
-- save (a reserved slot: INAROGUE) keeps its players' rarities and their look exactly as in the game. Héroe / Ídolo /
-- Diamante / season cards (rarity 5+) keep theirs. The game's own rarity sprites are never repainted.
--
--   NoMoreRarities.POSITION_LOOKS[type]     the position look by position icon type (0 GK, 1 DF, 2 MF, 3 FW; the
--     VR-Framework's one rule VRFW_UI.HeaderRow.NaturalType / ParamType): key, card_frame (the card frame the engine
--     draws), status_plate / personal_plate (sprite names), rgb (the plate's colour, for callers that colour a row).
--   NoMoreRarities.PositionColour(card)     THE shared helper (card look, header band, drop lists): the position look of
--     a card, or nil = keep the retail look (the removal does not apply: a reserved slot; a special card; staff; an
--     unknown position). card = a status handle (number), or a table with charaStHdl / charaParamId (the game's card
--     table keys; hdl / param work too), optional rarity (the card's rarity when the caller knows it; 0 = the saved one)
--     and overwritePosType (scPosType bits of a formation slot: the slot's colour instead of the player's own).
--   NoMoreRarities.PositionLookOfType(type) the look of a position icon type, nil when unknown.
--   NoMoreRarities.CardPositionType(card)   the card's position icon type (the slot's, else the player's own), nil for
--     staff / unknown. NoMoreRarities.IsNormalCard(card): its rarity is 0-4.
--   NoMoreRarities.RarityRemovalApplies()   true unless the loaded save is a RESERVED slot (a mode's own save: INAROGUE's,
--     or any mode that reserves one through the VR-Framework's slot service: CMND_VRFW_SLOT_ACTIVE ->
--     CMND_VRFW_SLOT_RESERVED(n) -> reserved). The same rule as the save pass on load. No framework answer = it applies.
--
-- While it applies, in every menu VM that draws cards (soccer_common / MENU_DEF.SetupCharaRarityIcon), the menu
-- commands are filtered once, from the VM's first OnInit (never at load):
-- * the character cards (3837561292 by status handle, 2339877830 by chara param id, 2329292196 by table): a card of
--   rarity 0-4 is drawn with the rarity card_frame - 1 of its position (argument 11 / t.rarity), so the engine draws the
--   sprites icon_chr_base01_{l,s}NN / icon_chr_color01_{l,s}NN of that frame: NEW sprites derived from the game's own by
--   research/scripts/no_more_rarities_build.py (content\images\; GK <- the gold *_04, DF <- the blue *_02, MF <- the
--   plain green *_01, FW <- the element-fire red card *_type_*03 of team00_02 / team00_03 with the plain card's shape).
--   On the formation layers (the pitch, the leader, the drag card; and Better UI's compact cards when it answers) a card
--   takes the colour of the position badge it shows (argument 6 / t.overwritePosType, the slot's scPosType); everywhere
--   else the player's own position. Staff or an unknown position: the MF frame (the plain green card).
-- * the status plate (soccer11_04, slot status_chr_base01_s01) and the personal plate (team11_01, slot
--   status_chr_plate01_01): the rarity 0-4 sprites *_01..*_05 are swapped for the position's plate (game sprites; the
--   FW personal plate status_chr_plate01_19 is NEW: the plain plate's shape in the game's red status plate colour). The
--   position comes from the plate being filled (UpdateCharaStatusPlateInfoByCharaStHdl / ...ByCharaParamId, argument 3)
--   or the last player whose rarity a plate asked for (GetCharaStatusRarity / GetCharaParamRarity: the personal plate).
--   No position known: the plain *_01.
-- * the rarity titles of 0-4 (gtxt_rarity01_01..05 and the element variants of _01 on icon_rarity: lists, plates,
--   results) are swapped for NO_TITLE_SPRITE, a transparent sprite the generator adds to icon_rarity. The status plate
--   header's own title (_player_rarity01) is Character Reforged's host character_reforged.header_rarity
--   (NoMoreRarities.HeaderShowsRarity, no_more_rarities_header.lua).
-- Everything else goes on exactly as the caller gave it (`...`). In a reserved slot nothing changes: the retail look.
-- Inazuma Fantasy's own position_cards (when both run): this filter wraps the menu command after it (OnInit), so the
-- cards reach IF's wrapper with this mod's frame (16-19, which it leaves alone) and the plates with this mod's sprite of
-- the same position: this mod's look wins, in the same colours.
-- The generator reads POSITION_LOOKS (one line per position) and NO_TITLE_SPRITE from this file (keep those lines as
-- they are: `[type] = {key = "...", card_frame = N, status_plate = "...", personal_plate = "...", rgb = {r, g, b}},`).
local NO_TITLE_SPRITE = "no_more_rarities_no_title"
local POSITION_LOOKS = {
  [0] = {key = "goalkeeper", card_frame = 16, status_plate = "status_chr_base01_s04", personal_plate = "status_chr_plate01_04", rgb = {231, 185, 1}},
  [1] = {key = "defender", card_frame = 17, status_plate = "status_chr_base01_s02", personal_plate = "status_chr_plate01_02", rgb = {34, 119, 238}},
  [2] = {key = "midfielder", card_frame = 18, status_plate = "status_chr_base01_s01", personal_plate = "status_chr_plate01_01", rgb = {38, 158, 30}},
  [3] = {key = "forward", card_frame = 19, status_plate = "status_chr_base01_s01_type03", personal_plate = "status_chr_plate01_19", rgb = {192, 52, 33}},
}
local PLAIN_POSITION = 2               -- staff / an unknown position: the MF look (the game's plain green card)

NoMoreRarities = type(NoMoreRarities) == "table" and NoMoreRarities or {}
NoMoreRarities.POSITION_LOOKS = NoMoreRarities.POSITION_LOOKS or POSITION_LOOKS
local draws_cards = type(rawget(_ENV, "UpdateCharaStatusPlateInfoByCharaStHdl")) == "function"
  or (type(rawget(_ENV, "MENU_DEF")) == "table" and type(MENU_DEF.SetupCharaRarityIcon) == "function")

if NoMoreRarities.RarityRemovalApplies == nil then
  local SLOT_ACTIVE = 4245285902       -- CMND_VRFW_SLOT_ACTIVE -> the loaded save's slot (0 = none)
  local SLOT_RESERVED = 1380583127     -- CMND_VRFW_SLOT_RESERVED (slot) -> reserved, owner mod, enterable

  -- whether the rarity removal applies to the loaded save: every save but a reserved slot (a mode's own save)
  function NoMoreRarities.RarityRemovalApplies()
    if type(funcLuaCommand) ~= "function" then
      return true
    end
    local okActive, active = pcall(funcLuaCommand, SLOT_ACTIVE)
    if not okActive or type(active) ~= "number" or active <= 0 then
      return true
    end
    local okReserved, reserved = pcall(funcLuaCommand, SLOT_RESERVED, active)
    return not (okReserved and reserved == true)
  end
end

if NoMoreRarities.PositionColour == nil then
  local CHARA = 1131797651             -- CMND_GET_CHARA (hdl, 12) = the status' rarity
  local CHARA_INFO = 4060384944        -- CMND_GET_CHARA_INFO (param, 8) = the card's rarity (chara_param col 41)
  local LAST_NORMAL_RARITY = 4         -- 5-7 Héroe / Ídolo, 8 Diamante, 9+ season and mods' cards keep their look
  -- scPosType bits (retail ConvertPosTypeToScPosType) -> position icon type; the game VM has no bit32: tested with %
  local SLOT_POSITION_BITS = {{16, 0}, {32, 1}, {64, 2}, {128, 3}}

  local function StatusRarity(hdl)
    local ok, rarity = pcall(funcLuaCommand, CHARA, hdl, 12)
    return ok and type(rarity) == "number" and rarity or nil
  end

  local function ParamRarity(param)
    local ok, first, second = pcall(funcLuaCommand, CHARA_INFO, param, 8)
    if not ok or first == false then
      return nil
    end
    if type(second) == "number" then
      return second
    end
    return type(first) == "number" and first or nil
  end

  local function IsId(value)
    return type(value) == "number" and value ~= 0
  end

  -- the card's identity from the caller's argument: status handle, param id, given rarity, slot bits
  local function CardFields(card)
    if type(card) == "number" then
      return card, nil, nil, nil
    end
    if type(card) ~= "table" then
      return nil, nil, nil, nil
    end
    local hdl = card.charaStHdl or card.hdl
    if not IsId(hdl) then
      hdl = nil
    end
    local param = card.charaParamId or card.param
    if not IsId(param) then
      param = nil
    end
    return hdl, param, card.rarity, card.overwritePosType
  end

  local function TypeOfSlotBits(bits)
    if type(bits) ~= "number" or bits <= 0 then
      return nil
    end
    for _, pair in ipairs(SLOT_POSITION_BITS) do
      local bit = pair[1]
      if bits % (bit + bit) >= bit then
        return pair[2]
      end
    end
    return nil
  end

  -- the player's OWN position icon type (the VR-Framework's one rule), nil for staff or unknown
  local function OwnType(hdl, param)
    local rows = type(VRFW_UI) == "table" and VRFW_UI.HeaderRow or nil
    if type(rows) ~= "table" then
      return nil
    end
    if hdl ~= nil then
      local ok, positionType = pcall(rows.NaturalType, hdl)
      return ok and positionType or nil
    end
    local ok, positionType = pcall(rows.ParamType, param)
    return ok and positionType or nil
  end

  function NoMoreRarities.PositionLookOfType(positionType)
    return NoMoreRarities.POSITION_LOOKS[positionType or -1]
  end

  -- the card's rarity (the given one, else the status' saved one, else the card's) is a normal one (0-4)
  function NoMoreRarities.IsNormalCard(card)
    local hdl, param, rarity = CardFields(card)
    if hdl == nil and param == nil then
      return false
    end
    if type(rarity) ~= "number" or rarity == 0 then
      if hdl ~= nil then
        rarity = StatusRarity(hdl)
      else
        rarity = ParamRarity(param)
      end
    end
    return type(rarity) == "number" and rarity >= 0 and rarity <= LAST_NORMAL_RARITY
  end

  function NoMoreRarities.CardPositionType(card)
    local hdl, param, _, slotBits = CardFields(card)
    if hdl == nil and param == nil then
      return nil
    end
    local slotType = TypeOfSlotBits(slotBits)
    if slotType ~= nil then
      return slotType
    end
    return OwnType(hdl, param)
  end

  function NoMoreRarities.PositionColour(card)
    if not NoMoreRarities.IsNormalCard(card) or not NoMoreRarities.RarityRemovalApplies() then
      return nil
    end
    return NoMoreRarities.PositionLookOfType(NoMoreRarities.CardPositionType(card))
  end
end

-- the menu command under this file's filter (the header's own band swap goes there: it must not be filtered)
function NoMoreRarities.RawMenuCommand()
  local look = NoMoreRarities.CardLook
  return look ~= nil and look.raw or funcLuaMenuCommand
end

if draws_cards and NoMoreRarities.CardLook == nil then
  local L = {installed = false, raw = nil, plate_position = nil, last_position = nil}
  NoMoreRarities.CardLook = L

  local CARD_BY_STATUS = 3837561292    -- (layer, idx, status handle, big, ..., [6] slot scPosType, ..., [11] rarity)
  local CARD_BY_PARAM = 2339877830     -- (layer, idx, chara param id, ...), the same arguments
  local CARD_BY_TABLE = 2329292196     -- ({layerName, layerIdx, charaStHdl, charaParamId, rarity, overwritePosType, ...})
  local SWAP_SPRITE = 558735651        -- (layer, texture, sprite, slot, 0, idx)
  -- the native card's defaults of the arguments 4-10 when a caller gave fewer (game/characters/position-cards.md §2)
  local CARD_DEFAULTS = {nil, nil, nil, true, false, 0, 0, 0, false, false}
  local LAST_DEFAULTED_ARGUMENT = 10
  local CARD_SLOT_ARGUMENT = 6
  local CARD_RARITY_ARGUMENT = 11
  local LAST_NORMAL_FRAME = 5          -- the plate sprites *_01..*_05 of the rarities 0-4
  -- the formation card layers (a card shows the position badge of its slot there; position-cards.md §4c)
  local FORMATION_LAYER_NAMES = {"team00_01_chara_card_for_soccer", "team00_01_chara_card_for_leader",
    "team00_01_chara_card_for_move"}

  local function Pack(...)
    return {n = select("#", ...), ...}
  end

  -- a formation card: one of the formation layers, or Better UI's compact (formation-layout) card when it answers
  local function IsFormationCard(layer, idx)
    if L.FORMATION_LAYERS[layer] then
      return true
    end
    local compact = rawget(_ENV, "CLEAN_HUD_PC_IsCompact")
    if type(compact) ~= "function" then
      return false
    end
    local ok, answer = pcall(compact, L.raw, layer, idx)
    return ok and answer == true
  end

  -- the rarity the engine gets for this card (its position's frame - 1), nil = draw it as the caller gave it
  local function PositionCardRarity(card, layer, idx)
    if not NoMoreRarities.IsNormalCard(card) or not NoMoreRarities.RarityRemovalApplies() then
      return nil
    end
    if not IsFormationCard(layer, idx) then
      card.overwritePosType = nil
    end
    local look = NoMoreRarities.PositionLookOfType(NoMoreRarities.CardPositionType(card))
      or NoMoreRarities.POSITION_LOOKS[PLAIN_POSITION]
    return look.card_frame - 1
  end

  local function CardCommand(raw, id, ...)
    local args = Pack(...)
    local card = {rarity = args[CARD_RARITY_ARGUMENT], overwritePosType = args[CARD_SLOT_ARGUMENT]}
    if id == CARD_BY_STATUS then
      card.charaStHdl = args[3]
    else
      card.charaParamId = args[3]
    end
    local rarity = PositionCardRarity(card, args[1], args[2])
    if rarity == nil then
      return raw(id, ...)
    end
    local count = args.n
    for i = count + 1, LAST_DEFAULTED_ARGUMENT do
      args[i] = CARD_DEFAULTS[i]
    end
    args[CARD_RARITY_ARGUMENT] = rarity
    if count < CARD_RARITY_ARGUMENT then
      count = CARD_RARITY_ARGUMENT
    end
    return raw(id, table.unpack(args, 1, count))
  end

  local function TableCardCommand(raw, id, ...)
    local given = ...
    if type(given) ~= "table" then
      return raw(id, ...)
    end
    local card = {charaStHdl = given.charaStHdl, charaParamId = given.charaParamId, rarity = given.rarity,
      overwritePosType = given.overwritePosType}
    local rarity = PositionCardRarity(card, given.layerName, given.layerIdx)
    if rarity == nil then
      return raw(id, ...)
    end
    local givenRarity = given.rarity
    given.rarity = rarity
    local result = Pack(pcall(raw, id, ...))
    given.rarity = givenRarity         -- the caller's table as it gave it
    if not result[1] then
      error(result[2], 0)
    end
    return table.unpack(result, 2, result.n)
  end

  -- the position of the plate being drawn: the plate fill's own (false = known to have none), else the last player
  -- whose rarity a plate asked for
  local function PlatePosition()
    if L.plate_position ~= nil then
      return L.plate_position or nil
    end
    return L.last_position
  end

  local function SwapCommand(raw, id, ...)
    local args = Pack(...)
    local texture, sprite, slot = args[2], args[3], args[4]
    local target, field = nil, nil
    if texture == L.STATUS_TEXTURE and slot == L.STATUS_SLOT and L.STATUS_RARITY_PLATES[sprite] then
      target, field = L.PLAIN_STATUS_PLATE, "status_plate_id"
    elseif texture == L.PERSONAL_TEXTURE and slot == L.PERSONAL_SLOT and L.PERSONAL_RARITY_PLATES[sprite] then
      target, field = L.PLAIN_PERSONAL_PLATE, "personal_plate_id"
    elseif texture == L.TITLE_TEXTURE and L.NORMAL_TITLES[sprite] then
      target = L.NO_TITLE
    end
    if target == nil or not NoMoreRarities.RarityRemovalApplies() then
      return raw(id, ...)
    end
    if field ~= nil then
      local look = NoMoreRarities.PositionLookOfType(PlatePosition())
      if look ~= nil then
        target = look[field]
      end
    end
    args[3] = target
    return raw(id, table.unpack(args, 1, args.n))
  end

  -- the sprite / texture ids (CRC32 of the names), at install
  local function Names(crc)
    L.STATUS_TEXTURE = crc("#/menu/00_soccer/soccer11/soccer11_04/<LG>/soccer11_04.g4tx")
    L.STATUS_SLOT = crc("status_chr_base01_s01")
    L.PERSONAL_TEXTURE = crc("#/menu/102_team/team11/team11_01/team11_01.g4tx")
    L.PERSONAL_SLOT = crc("status_chr_plate01_01")
    L.TITLE_TEXTURE = crc("#/menu/200_icon/05_icon_rarity/<LG>/icon_rarity.g4tx")
    L.NO_TITLE = crc(NO_TITLE_SPRITE)
    L.PLAIN_STATUS_PLATE, L.PLAIN_PERSONAL_PLATE = crc("status_chr_base01_s01"), crc("status_chr_plate01_01")
    for _, look in pairs(NoMoreRarities.POSITION_LOOKS) do
      look.status_plate_id = crc(look.status_plate)
      look.personal_plate_id = crc(look.personal_plate)
    end
    L.STATUS_RARITY_PLATES, L.PERSONAL_RARITY_PLATES, L.NORMAL_TITLES = {}, {}, {}
    for frame = 1, LAST_NORMAL_FRAME do
      L.STATUS_RARITY_PLATES[crc(string.format("status_chr_base01_s%02d", frame))] = true
      L.PERSONAL_RARITY_PLATES[crc(string.format("status_chr_plate01_%02d", frame))] = true
      L.NORMAL_TITLES[crc(string.format("gtxt_rarity01_%02d", frame))] = true
    end
    for element = 1, 5 do
      L.NORMAL_TITLES[crc(string.format("gtxt_rarity01_01_type%02d", element))] = true
    end
    L.FORMATION_LAYERS = {}
    for _, name in ipairs(FORMATION_LAYER_NAMES) do
      L.FORMATION_LAYERS[crc(name)] = true
    end
    L.HANDLERS = {[CARD_BY_STATUS] = CardCommand, [CARD_BY_PARAM] = CardCommand,
      [CARD_BY_TABLE] = TableCardCommand, [SWAP_SPRITE] = SwapCommand}
  end

  local function StatusType(hdl)
    return NoMoreRarities.CardPositionType({charaStHdl = hdl})
  end

  local function ParamType(param)
    return NoMoreRarities.CardPositionType({charaParamId = param})
  end

  -- a plate fill (argument 3 = the handle / param id): its position is the plate's while it runs
  local function PlateFill(ownType)
    return function(original)
      return function(...)
        local previous = L.plate_position
        local ok, positionType = pcall(ownType, (select(3, ...)))
        L.plate_position = (ok and positionType ~= nil) and positionType or false
        local result = Pack(pcall(original, ...))
        L.plate_position = previous
        if not result[1] then
          error(result[2], 0)
        end
        return table.unpack(result, 2, result.n)
      end
    end
  end

  -- a plate's rarity query (the personal plate asks right before its swap): remember whose plate it is
  local function RarityQuery(ownType)
    return function(original)
      return function(key, ...)
        local ok, positionType = pcall(ownType, key)
        L.last_position = ok and positionType or nil
        return original(key, ...)
      end
    end
  end

  local function WrapGlobal(name, make)
    local original = rawget(_ENV, name)
    if type(original) == "function" then
      rawset(_ENV, name, make(original))
    end
  end

  function L.Install()
    local crc = rawget(_ENV, "CRC32")
    if L.installed or type(funcLuaMenuCommand) ~= "function" or type(crc) ~= "function" then
      return
    end
    L.installed = true
    Names(crc)
    WrapGlobal("UpdateCharaStatusPlateInfoByCharaStHdl", PlateFill(StatusType))
    WrapGlobal("UpdateCharaStatusPlateInfoByCharaParamId", PlateFill(ParamType))
    WrapGlobal("GetCharaStatusRarity", RarityQuery(StatusType))
    WrapGlobal("GetCharaParamRarity", RarityQuery(ParamType))
    local raw = funcLuaMenuCommand
    L.raw = raw
    funcLuaMenuCommand = function(...)
      local handler = L.HANDLERS[(...)]
      if handler ~= nil then
        return handler(raw, ...)
      end
      return raw(...)
    end
  end

  -- installed from the VM's first OnInit: the retail OnInit wrapped here, and the same entry as a VR-Framework host
  -- handler (a lua_early merged file that redefines OnInit after lua\_all drops the wrapper above)
  local init = rawget(_ENV, "OnInit")
  if type(init) == "function" then
    OnInit = function(...)
      pcall(L.Install)
      return init(...)
    end
  end
  local host = rawget(_ENV, "VRFW_Host")
  local patch = rawget(_ENV, "EVT_PATCH")
  local script = type(patch) == "table" and patch.script or nil
  local stem = type(script) == "string" and script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "") or nil
  if type(stem) == "string" and type(host) == "table" and type(host.on) == "function" then
    pcall(host.on, stem, "OnInit", {id = "no_more_rarities.card_look", phase = "before", fn = function()
      pcall(L.Install)
    end})
  end
end
