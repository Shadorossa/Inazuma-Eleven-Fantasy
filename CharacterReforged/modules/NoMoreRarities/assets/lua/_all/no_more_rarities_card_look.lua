-- No More Rarities: the normal cards coloured by the player's POSITION, chosen at run time (docs/refactor/aura-mods-split.md
-- «Save pass on load and card look», docs/game/characters/rarity-removal.md §4.6, docs/game/characters/position-cards.md).
-- Owner rule 2026-10-14: the position colours belong to No More Rarities (taken out of Inazuma Fantasy's position_cards):
-- with this mod on, every card of a removed rarity shows its player's position, the same scheme as the player header
-- (no_more_rarities_header.lua): POR gold, DF green, MC blue, DL red. Without this mod: the retail look. A mode's own
-- save (a reserved slot: INAROGUE) keeps its players' rarities and their look exactly as in the game. Which rarities
-- are removed is the option no_more_rarities.removed_rarities (options.toml): the normal cards 0-4 always, the Ídolo
-- cards 5-7 and the Diamante cards 8 by the choice; a kept rarity and the season cards (9+) keep their look exactly as
-- in the game. The game's own rarity sprites are never repainted.
--
--   NoMoreRarities.RarityRemoved(rarity)    THE rule of the option (every reader goes through it): this rarity loses
--     its rarity look. NoMoreRarities.FrameOfRarity(rarity): the card / plate / title frame number of a rarity.
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
--     staff / unknown. NoMoreRarities.IsNormalCard(card): its rarity is a removed one (RarityRemoved).
--   NoMoreRarities.RarityRemovalApplies()   true unless the loaded save is a RESERVED slot (a mode's own save: INAROGUE's,
--     or any mode that reserves one through the VR-Framework's slot service: CMND_VRFW_SLOT_ACTIVE ->
--     CMND_VRFW_SLOT_RESERVED(n) -> reserved). The same rule as the save pass on load. No framework answer = it applies.
--   NoMoreRarities.NormalCardRarity()       the rarity every normal card has (4, the 5★ card) while the removal applies,
--     nil otherwise (New Recruitment recruits a spirit drop's player at it).
--
--   NoMoreRarities.STAFF_LOOKS[role]        the staff look ("coach" white, "manager" pink; Inazuma Fantasy's staff
--     colours, owner rule 2026-10-14): card_frame (the card frame the engine draws). NoMoreRarities.StaffLookOf(role).
--
-- When the filter goes on (1.0.11, owner 2026-10-14: «Plantilla de equipo» showed the rarity cards and still listed
-- «Espíritu»): the engine registers funcLuaCommand / funcLuaMenuCommand AFTER every patch of the script ran
-- (docs/game/engine/lua-patches.md §7), and until 1.0.10 the filter went on from the VM's first OnInit, through a
-- wrapper of OnInit and a VR-Framework host handler. In soccer_team_dock_menu a later merge-path patch (Player
-- Training's player_training_dock, promoted locals, not lua_early) redefines OnInit and the other callbacks after both,
-- so neither ran there: the overview's pitch, coach and bench cards kept the rarity look. Now the filter is a
-- VR-Framework command hook registered at load (VRFW_Host.HookCommand): in place when the engine stores the command,
-- right over it, before the VM's first callback and first card draw, whatever the callbacks become. The OnInit wrapper
-- and the host handler register it again as fallbacks (a VM whose globals cannot take a metatable). The plate fills and rarity queries are wrapped
-- at load and again at the VM's first menu command (a later patch may redefine them).
--
-- While it applies, in every menu VM that draws cards (soccer_common / MENU_DEF.SetupCharaRarityIcon), the menu
-- commands are filtered:
-- * the character cards (3837561292 by status handle, 2339877830 by chara param id, 2329292196 by table): a card of
--   rarity 0-4 is drawn with the rarity card_frame - 1 of its position (argument 11 / t.rarity), so the engine draws the
--   sprites icon_chr_base01_{l,s}NN / icon_chr_color01_{l,s}NN of that frame: NEW sprites derived from the game's own by
--   research/scripts/no_more_rarities_build.py (content\images\; GK <- the gold *_04, DF <- the blue *_02, MF <- the
--   plain green *_01, FW <- the element-fire red card *_type_*03 of team00_02 / team00_03 with the plain card's shape).
--   On the formation layers (the pitch, the leader, the drag card; and Better UI's compact cards when it answers) a card
--   takes the colour of the position badge it shows (argument 6 / t.overwritePosType, the slot's scPosType); everywhere
--   else the player's own position. An unknown position: the MF frame (the plain green card).
--   Staff (1.0.11, Inazuma Fantasy's staff colours): the coach card (argument 5 / t.isForceLeader, or a player with the
--   director ability abl_000002) is drawn with the coach frame (white), a manager (argument 18 / t.isManager, or the
--   manager ability abl_000003) with the manager frame (pink): NEW sprites derived by no_more_rarities_build.py from
--   the game's blue card (its shading kept) and side gradient (STAFF_LOOKS). The leader card commands (1000031904 by
--   soccer handle, 3550249130 the team's leader: the coach card of the formation screens, argument 5 always true) take
--   no rarity, so right after the engine drew one its base and side gradient are swapped to the coach frame's sprites
--   (in the same command, before the frame is shown); a normal card drawn later on that card gets back the sprites of
--   the frame it was drawn with. 213411469 (the VS route enemy formation's coach) is left as the game draws it.
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
-- Inazuma Fantasy's own position_cards (when both run): this filter wraps the menu command over it (IF's __newindex of
-- soccer_common stores its wrapper first, this one goes over what it stored), so the
-- cards reach IF's wrapper with this mod's frame (16-19, which it leaves alone) and the plates with this mod's sprite of
-- the same position: this mod's look wins, in the same colours.
-- The generator reads POSITION_LOOKS (one line per position) and NO_TITLE_SPRITE from this file (keep those lines as
-- they are: `[type] = {key = "...", card_frame = N, status_plate = "...", personal_plate = "...", rgb = {r, g, b}},`).
local NO_TITLE_SPRITE = "no_more_rarities_no_title"
local POSITION_LOOKS = {
  [0] = {key = "goalkeeper", card_frame = 16, status_plate = "status_chr_base01_s04", personal_plate = "status_chr_plate01_04", rgb = {231, 185, 1}},
  [1] = {key = "defender", card_frame = 18, status_plate = "status_chr_base01_s01", personal_plate = "status_chr_plate01_01", rgb = {38, 158, 30}},
  [2] = {key = "midfielder", card_frame = 17, status_plate = "status_chr_base01_s02", personal_plate = "status_chr_plate01_02", rgb = {34, 119, 238}},
  [3] = {key = "forward", card_frame = 19, status_plate = "status_chr_base01_s01_type03", personal_plate = "status_chr_plate01_19", rgb = {192, 52, 33}},
}
-- The staff looks (Inazuma Fantasy's staff colours; the generator reads these lines too, keep them as they are:
-- `  role = {key = "...", card_frame = N},`). Their colours are the generator's (STAFF_COLOURS).
local STAFF_LOOKS = {
  coach = {key = "coach", card_frame = 20},
  manager = {key = "manager", card_frame = 21},
}
local PLAIN_POSITION = 2               -- an unknown position: the MF look (the game's plain green card)

NoMoreRarities = type(NoMoreRarities) == "table" and NoMoreRarities or {}
NoMoreRarities.POSITION_LOOKS = NoMoreRarities.POSITION_LOOKS or POSITION_LOOKS
NoMoreRarities.STAFF_LOOKS = NoMoreRarities.STAFF_LOOKS or STAFF_LOOKS

function NoMoreRarities.StaffLookOf(role)
  return NoMoreRarities.STAFF_LOOKS[role or ""]
end

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

if NoMoreRarities.RarityRemoved == nil then
  local OPTION_GET = 4082322029        -- CMND_VRFW_OPTION_GET (row key) -> the value the game started with (restart row)
  local OPTION_KEY = "no_more_rarities.removed_rarities"
  local OPTION_DEFAULT = 0             -- options.toml default: basic only
  -- the game's rarity tiers (docs/game/characters/rarity-removal.md §0): the normal cards 0-4, Ídolo 5-7, Diamante 8
  local LAST_BASIC_RARITY, LAST_IDOL_RARITY, DIAMOND_RARITY = 4, 7, 8
  local DIAMOND_FRAME = 10             -- the card / plate / title frame is rarity + 1, Diamante's is 10
  -- options.toml values: 0 basic only, 1 basic + Ídolo, 2 basic + Diamante, 3 all
  local TIERS_OF_CHOICE = {[0] = {}, {idol = true}, {diamond = true}, {idol = true, diamond = true}}
  local tiers = nil

  -- the removed special tiers of the option, read once per script (the row applies after a restart)
  local function RemovedTiers()
    if tiers == nil then
      local ok, value = false, nil
      if type(funcLuaCommand) == "function" then
        ok, value = pcall(funcLuaCommand, OPTION_GET, OPTION_KEY)
      end
      tiers = TIERS_OF_CHOICE[ok and type(value) == "number" and value or OPTION_DEFAULT] or TIERS_OF_CHOICE[OPTION_DEFAULT]
    end
    return tiers
  end

  function NoMoreRarities.RarityRemoved(rarity)
    if type(rarity) ~= "number" or rarity < 0 then
      return false
    end
    if rarity <= LAST_BASIC_RARITY then
      return true
    end
    if rarity <= LAST_IDOL_RARITY then
      return RemovedTiers().idol == true
    end
    if rarity == DIAMOND_RARITY then
      return RemovedTiers().diamond == true
    end
    return false
  end

  function NoMoreRarities.FrameOfRarity(rarity)
    return rarity == DIAMOND_RARITY and DIAMOND_FRAME or rarity + 1
  end

  -- the rarities the rule can remove (the plate and title sprites of the removed ones are swapped)
  NoMoreRarities.LAST_REMOVABLE_RARITY = DIAMOND_RARITY
end

if NoMoreRarities.NormalCardRarity == nil then
  local NORMAL_CARD_RARITY = 4         -- the 5★ «Leyenda» card (content\duplicate_rules\no_more_rarities.toml)

  function NoMoreRarities.NormalCardRarity()
    if NoMoreRarities.RarityRemovalApplies() then
      return NORMAL_CARD_RARITY
    end
    return nil
  end
end

if NoMoreRarities.PositionColour == nil then
  local CHARA = 1131797651             -- CMND_GET_CHARA (hdl, 12) = the status' rarity
  local CHARA_INFO = 4060384944        -- CMND_GET_CHARA_INFO (param, 8) = the card's rarity (chara_param col 41)
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

  -- the card's rarity (the given one, else the status' saved one, else the card's) is a removed one
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
    return NoMoreRarities.RarityRemoved(rarity)
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
  return look ~= nil and look.raw or funcLuaMenuCommand  -- look.raw: VRFW_Host.RealMenuCommand
end

if draws_cards and NoMoreRarities.CardLook == nil then
  local L = {installed = false, raw = nil, plate_position = nil, last_position = nil, named = false,
    late_done = false, staff_swapped = {}, own_wrappers = {}}
  NoMoreRarities.CardLook = L

  local CARD_BY_STATUS = 3837561292    -- (layer, idx, status handle, big, [5] coach, [6] slot scPosType, ..., [11] rarity,
                                       --  ..., [18] manager)
  local CARD_BY_PARAM = 2339877830     -- (layer, idx, chara param id, ...), the same arguments
  local CARD_BY_TABLE = 2329292196     -- ({layerName, layerIdx, charaStHdl, charaParamId, rarity, overwritePosType,
                                       --   isForceLeader, isManager, ...})
  local LEADER_BY_SOCCER_HANDLE = 1000031904  -- (layer, idx, soccer chara handle, big, true, ...): the coach card
  local LEADER_OF_TEAM = 3550249130    -- (layer, idx, team, big, true, ...): the team's coach card
  local SWAP_SPRITE = 558735651        -- (layer, texture, sprite, slot, 0, idx)
  local HAS_ABILITY = 2361903722       -- (status handle, ability) -> ok, has it (retail CheckEnableSetDirector / ...Manager)
  local CHARA = 1131797651             -- CMND_GET_CHARA (hdl, 12) = the status' rarity
  local CHARA_INFO = 4060384944        -- CMND_GET_CHARA_INFO (param, 8) = the card's rarity
  -- the native card's defaults of the arguments 4-10 when a caller gave fewer (game/characters/position-cards.md §2)
  local CARD_DEFAULTS = {nil, nil, nil, true, false, 0, 0, 0, false, false}
  local LAST_DEFAULTED_ARGUMENT = 10
  local CARD_COACH_ARGUMENT = 5
  local CARD_SLOT_ARGUMENT = 6
  local CARD_RARITY_ARGUMENT = 11
  local CARD_MANAGER_ARGUMENT = 18
  -- the formation card layers (a card shows the position badge of its slot there; position-cards.md §4c)
  local FORMATION_LAYER_NAMES = {"team00_01_chara_card_for_soccer", "team00_01_chara_card_for_leader",
    "team00_01_chara_card_for_move"}
  -- the card's meshes by their default sprite (base and side gradient, large and small) and the frame sprite formats
  local CARD_MESHES = {{"icon_chr_base01_l01", "icon_chr_base01_l%02d"}, {"icon_chr_base01_s01", "icon_chr_base01_s%02d"},
    {"icon_chr_color01_l01", "icon_chr_color01_l%02d"}, {"icon_chr_color01_s01", "icon_chr_color01_s%02d"}}
  local DIRECTOR_ABILITY, MANAGER_ABILITY = "abl_000002", "abl_000003"

  local function Pack(...)
    return {n = select("#", ...), ...}
  end

  -- the sprite / texture ids (CRC32 of the names), at the first filtered command (CRC32 is a game function: never at
  -- load); false = no CRC32 in this VM (everything goes on as given)
  local function Ready()
    if L.named then
      return L.crc ~= nil
    end
    L.named = true
    local crc = rawget(_ENV, "CRC32")
    if type(crc) ~= "function" then
      return false
    end
    L.crc = crc
    L.STATUS_TEXTURE = crc("#/menu/00_soccer/soccer11/soccer11_04/<LG>/soccer11_04.g4tx")
    L.STATUS_SLOT = crc("status_chr_base01_s01")
    L.PERSONAL_TEXTURE = crc("#/menu/102_team/team11/team11_01/team11_01.g4tx")
    L.PERSONAL_SLOT = crc("status_chr_plate01_01")
    L.TITLE_TEXTURE = crc("#/menu/200_icon/05_icon_rarity/<LG>/icon_rarity.g4tx")
    L.CARD_TEXTURE = crc("#/menu/102_team/team00/team00_01/<LG>/team00_01.g4tx")
    L.NO_TITLE = crc(NO_TITLE_SPRITE)
    L.PLAIN_STATUS_PLATE, L.PLAIN_PERSONAL_PLATE = crc("status_chr_base01_s01"), crc("status_chr_plate01_01")
    for _, look in pairs(NoMoreRarities.POSITION_LOOKS) do
      look.status_plate_id = crc(look.status_plate)
      look.personal_plate_id = crc(look.personal_plate)
    end
    L.STATUS_RARITY_PLATES, L.PERSONAL_RARITY_PLATES, L.NORMAL_TITLES = {}, {}, {}
    -- the plate and title sprites of the removed rarities (*_01..*_05 the normal cards; *_06..*_08 Ídolo and *_10
    -- Diamante when the option removes them)
    for rarity = 0, NoMoreRarities.LAST_REMOVABLE_RARITY do
      if NoMoreRarities.RarityRemoved(rarity) then
        local frame = NoMoreRarities.FrameOfRarity(rarity)
        L.STATUS_RARITY_PLATES[crc(string.format("status_chr_base01_s%02d", frame))] = true
        L.PERSONAL_RARITY_PLATES[crc(string.format("status_chr_plate01_%02d", frame))] = true
        L.NORMAL_TITLES[crc(string.format("gtxt_rarity01_%02d", frame))] = true
      end
    end
    for element = 1, 5 do
      L.NORMAL_TITLES[crc(string.format("gtxt_rarity01_01_type%02d", element))] = true
    end
    L.FORMATION_LAYERS = {}
    for _, name in ipairs(FORMATION_LAYER_NAMES) do
      L.FORMATION_LAYERS[crc(name)] = true
    end
    L.DIRECTOR_ABILITY, L.MANAGER_ABILITY = crc(DIRECTOR_ABILITY), crc(MANAGER_ABILITY)
    L.frame_sprites = {}
    return true
  end

  -- the sprites of a card frame on the card's meshes: {{mesh, sprite}, ...}
  local function FrameSprites(frame)
    local sprites = L.frame_sprites[frame]
    if sprites == nil then
      sprites = {}
      for _, mesh in ipairs(CARD_MESHES) do
        sprites[#sprites + 1] = {L.crc(mesh[1]), L.crc(string.format(mesh[2], frame))}
      end
      L.frame_sprites[frame] = sprites
    end
    return sprites
  end

  local function CardKey(layer, idx)
    return tostring(layer) .. ":" .. tostring(idx or 0)
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

  local function HasAbility(hdl, ability)
    if type(hdl) ~= "number" or hdl == 0 or type(funcLuaCommand) ~= "function" then
      return false
    end
    local ok, found, has = pcall(funcLuaCommand, HAS_ABILITY, hdl, ability)
    return ok and found ~= false and has == true
  end

  -- the staff role of a card: the caller's coach / manager flags, else the abilities of the status handle
  local function StaffRole(coach, manager, hdl)
    if coach == true then
      return "coach"
    elseif manager == true then
      return "manager"
    elseif HasAbility(hdl, L.DIRECTOR_ABILITY) then
      return "coach"
    elseif HasAbility(hdl, L.MANAGER_ABILITY) then
      return "manager"
    end
    return nil
  end

  -- the rarity the engine gets for this card (its staff or position frame - 1), nil = draw it as the caller gave it;
  -- the staff role from the caller's coach / manager flags, else the status handle's abilities
  local function LookCardRarity(card, layer, idx, coach, manager, hdl)
    if not NoMoreRarities.IsNormalCard(card) or not NoMoreRarities.RarityRemovalApplies() then
      return nil
    end
    local staff = NoMoreRarities.StaffLookOf(StaffRole(coach, manager, hdl))
    if staff ~= nil then
      return staff.card_frame - 1
    end
    if not IsFormationCard(layer, idx) then
      card.overwritePosType = nil
    end
    local look = NoMoreRarities.PositionLookOfType(NoMoreRarities.CardPositionType(card))
      or NoMoreRarities.POSITION_LOOKS[PLAIN_POSITION]
    return look.card_frame - 1
  end

  -- the card frame the engine drew a card with: the rarity sent (this filter's, else the caller's, else the saved one)
  local function DrawnFrame(card, sentRarity)
    local rarity = sentRarity
    if type(rarity) ~= "number" or rarity == 0 then
      rarity = card.rarity
    end
    if type(rarity) ~= "number" or rarity == 0 then
      local saved = nil
      if card.charaStHdl ~= nil then
        local ok, value = pcall(funcLuaCommand, CHARA, card.charaStHdl, 12)
        saved = ok and value or nil
      elseif card.charaParamId ~= nil then
        local ok, first, second = pcall(funcLuaCommand, CHARA_INFO, card.charaParamId, 8)
        if ok and first ~= false then
          saved = type(second) == "number" and second or first
        end
      end
      if type(saved) == "number" then
        rarity = saved
      end
    end
    if type(rarity) ~= "number" or rarity < 0 then
      return nil
    end
    return NoMoreRarities.FrameOfRarity(rarity)
  end

  -- a card the coach frame was swapped onto (a leader command) and now drawn as another card: its frame's sprites back
  local function UndoStaffSwap(raw, layer, idx, card, sentRarity)
    local key = CardKey(layer, idx)
    if not L.staff_swapped[key] then
      return
    end
    L.staff_swapped[key] = nil
    local frame = DrawnFrame(card, sentRarity)
    if frame == nil then
      return
    end
    for _, pair in ipairs(FrameSprites(frame)) do
      pcall(raw, SWAP_SPRITE, layer, L.CARD_TEXTURE, pair[2], pair[1], 0, idx or 0)
    end
  end

  local function Finish(result)
    if not result[1] then
      error(result[2], 0)
    end
    return table.unpack(result, 2, result.n)
  end

  local function CardCommand(raw, id, ...)
    local args = Pack(...)
    local card = {rarity = args[CARD_RARITY_ARGUMENT], overwritePosType = args[CARD_SLOT_ARGUMENT]}
    local hdl = nil
    if id == CARD_BY_STATUS then
      card.charaStHdl = args[3]
      hdl = args[3]
    else
      card.charaParamId = args[3]
    end
    local rarity = LookCardRarity(card, args[1], args[2], args[CARD_COACH_ARGUMENT], args[CARD_MANAGER_ARGUMENT], hdl)
    local result
    if rarity == nil then
      result = Pack(pcall(raw, id, ...))
    else
      local count = args.n
      for i = count + 1, LAST_DEFAULTED_ARGUMENT do
        args[i] = CARD_DEFAULTS[i]
      end
      args[CARD_RARITY_ARGUMENT] = rarity
      if count < CARD_RARITY_ARGUMENT then
        count = CARD_RARITY_ARGUMENT
      end
      result = Pack(pcall(raw, id, table.unpack(args, 1, count)))
    end
    if result[1] then
      UndoStaffSwap(raw, args[1], args[2], card, rarity)
    end
    return Finish(result)
  end

  local function TableCardCommand(raw, id, ...)
    local given = ...
    if type(given) ~= "table" then
      return raw(id, ...)
    end
    local card = {charaStHdl = given.charaStHdl, charaParamId = given.charaParamId, rarity = given.rarity,
      overwritePosType = given.overwritePosType}
    local rarity = LookCardRarity(card, given.layerName, given.layerIdx, given.isForceLeader, given.isManager,
      given.charaStHdl)
    local givenRarity = given.rarity
    if rarity ~= nil then
      given.rarity = rarity
    end
    local result = Pack(pcall(raw, id, ...))
    given.rarity = givenRarity         -- the caller's table as it gave it
    if result[1] then
      UndoStaffSwap(raw, given.layerName, given.layerIdx, card, rarity)
    end
    return Finish(result)
  end

  -- a leader (coach) card: drawn by the engine, then its base and side gradient swapped to the coach frame
  local function LeaderCommand(raw, id, ...)
    local result = Pack(pcall(raw, id, ...))
    if result[1] and NoMoreRarities.RarityRemovalApplies() then
      local layer, idx = ...
      local coach = NoMoreRarities.StaffLookOf("coach")
      for _, pair in ipairs(FrameSprites(coach.card_frame)) do
        pcall(raw, SWAP_SPRITE, layer, L.CARD_TEXTURE, pair[2], pair[1], 0, idx or 0)
      end
      L.staff_swapped[CardKey(layer, idx)] = true
    end
    return Finish(result)
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

  local HANDLERS = {[CARD_BY_STATUS] = CardCommand, [CARD_BY_PARAM] = CardCommand,
    [CARD_BY_TABLE] = TableCardCommand, [LEADER_BY_SOCCER_HANDLE] = LeaderCommand, [LEADER_OF_TEAM] = LeaderCommand,
    [SWAP_SPRITE] = SwapCommand}

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
        return Finish(result)
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

  -- wrapped once per function object: again when a later patch redefined the global (its new function)
  local function WrapGlobal(name, make)
    local original = rawget(_ENV, name)
    if type(original) == "function" and not L.own_wrappers[original] then
      local wrapper = make(original)
      L.own_wrappers[wrapper] = true
      rawset(_ENV, name, wrapper)
    end
  end

  local function WrapPlateFunctions()
    WrapGlobal("UpdateCharaStatusPlateInfoByCharaStHdl", PlateFill(StatusType))
    WrapGlobal("UpdateCharaStatusPlateInfoByCharaParamId", PlateFill(ParamType))
    WrapGlobal("GetCharaStatusRarity", RarityQuery(StatusType))
    WrapGlobal("GetCharaParamRarity", RarityQuery(ParamType))
  end

  -- the command a handler calls: the handled command goes on through the hook chain (nxt), any other one (the coach
  -- frame's sprite swaps) straight to the engine, past this filter
  local function CommandUnder(nxt, handled)
    return function(id, ...)
      if id == handled then
        return nxt(id, ...)
      end
      return VRFW_Host.RealMenuCommand(id, ...)
    end
  end

  -- the filter over the card commands, right over the engine's menu command
  local function MenuFilter(nxt, ...)
    L.installed = true
    local id = ...
    local handler = HANDLERS[id]
    if handler ~= nil and Ready() then
      return handler(CommandUnder(nxt, id), ...)
    end
    return nxt(...)
  end

  -- the VM's first menu command: every patch of the script ran
  local LATE_OWNER = "NoMoreRarities.card_look_late"
  local function FirstMenuCommand(nxt, ...)
    if not L.late_done then
      L.late_done = true
      VRFW_Host.UnhookCommand(LATE_OWNER, {menu = true})
      pcall(WrapPlateFunctions)
    end
    return nxt(...)
  end

  local function RegisterHooks()
    local ids = {}
    for id in pairs(HANDLERS) do
      ids[#ids + 1] = id
    end
    local innermost = {menu = true, priority = VRFW_Host.INNERMOST}
    L.raw = VRFW_Host.RealMenuCommand
    local installed = VRFW_Host.HookCommand(ids, MenuFilter, "NoMoreRarities.card_look", innermost)
    if not L.late_done then
      VRFW_Host.HookCommand("*", FirstMenuCommand, LATE_OWNER, innermost)
    end
    return installed
  end

  -- fallback (no metatable on the globals): registered again from the VM's first OnInit
  function L.Install()
    if L.installed or type(funcLuaMenuCommand) ~= "function" then
      return
    end
    L.installed = RegisterHooks()
  end

  pcall(WrapPlateFunctions)
  RegisterHooks()

  -- the fallbacks: the retail OnInit wrapped here, and the same entry as a VR-Framework host handler
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
