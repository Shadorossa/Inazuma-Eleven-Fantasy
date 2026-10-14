-- No More Rarities: no spirits to summon (owner requests 2026-10-14). With this mod a player is one card, so a spirit is
-- only the player himself: a spirit drop recruits that player straight into the bank, and the spirit screen
-- («Espíritu»: summon, rarity-up, fusion) and its «!» notices are gone. Only while the rarity removal applies
-- (NoMoreRarities.RarityRemovalApplies, no_more_rarities_card_look.lua: not in a reserved slot, a mode's own save such
-- as INAROGUE's): there everything stays the game's.
--
-- 1. Notices. Every «!» / egg notice of new spirits asks CMND_GET_SPIRIT_INFO (mode 0 new, 1 egg; the team docks'
--    «Espíritu» row, the spirit screen's era tabs, the main menus' «Equipo» entries and their mods' copies), and the
--    character cards' «new spirit» mark asks CMND_HAS_CHARA_SPIRIT: both answer «nothing new» (funcLuaCommand filtered
--    in every menu VM; every other command goes on as given).
-- 2. The «Espíritu» row of the team docks: «Plantilla de equipo» (soccer_team_dock_menu: row kind SPIRIT_DOCK_ROW of its
--    row-kind list, reached as an upvalue through the loader's EVT_DEBUG, removed by value and put back at its place in
--    a reserved slot; filtered when the list layer's first row is set up, as BetterUI's clean_hud_dock_rows does) and
--    the Chronicle team dock (rpg_team_dock_menu_inc: GetSortOflistItems answers a copy without SPIRIT_RPG_DOCK_ROW).
--    The spirit screen (soccer_summon_menu) has no other way in, so its summon / rarity-up rows go with it (the graft
--    rar_menus still greys and refuses rarity-up and fusion there).
-- 3. A spirit drop = the player. The match result screen (soccer_result_menu_item, UpdateItem with a spirit row) lists
--    the spirits the match gives; the engine adds them to the bag only after that screen. Each spirit of a normal card
--    (spirit rarity 0-4, card type below 5) is kept as PENDING (loader UI flags, persistent: count PENDING_COUNT_KEY,
--    entries PENDING_KEY + 3 i .. + 3 i + 2 = card, rarity, slot). The first step of a menu of the loaded save outside the
--    match and the story (RECRUIT_MENUS) recruits each pending player of that slot at the normal card's rarity (4) through the
--    VR-Framework's recruit service (VRFW_Recruit.Sign: the game's CMND_ADD_PARTY, the summon screen's arguments) and
--    takes his spirit back (CMND_ADD_ITEM_SPIRIT -1, only when the bag holds it and nothing else changed the count: -1
--    on an empty stock wraps to 999), then one autosave. A player already in the club or a full bank: the spirit stays
--    as the game gave it (logged). One log line per recruit («NoMoreRarities spirit recruit»). The owned players never
--    drop in the first place (the VR-Framework's [VRFW.DropList.Spirits], content\items\drop_list.toml).
-- Defines functions and wrappers only; engine calls only inside the game's callbacks; every call goes through pcall.
local SPIRIT_DOCK_ROW = 1        -- soccer_team_dock_menu row kind of «Espíritu»
local SPIRIT_RPG_DOCK_ROW = 60   -- rpg_team_dock_menu_inc row kind of «Espíritu» (the Chronicle list)
local RECRUIT_MENUS = {          -- menus of a loaded save where the pending players are recruited (first step)
  "vs_route_town_menu", "chronicle_mode_top_menu", "soccer_top_menu", "soccer_team_dock_menu", "chara_bank_menu",
  "team_dock_menu", "market_menu",
}

NoMoreRarities = type(NoMoreRarities) == "table" and NoMoreRarities or {}
if NoMoreRarities.Spirits == nil then
  local S = {}
  NoMoreRarities.Spirits = S
  local SPIRIT_INFO = 707505551          -- CMND_GET_SPIRIT_INFO (mode, series) -> ok, shown
  local HAS_CHARA_SPIRIT = 3002728759    -- (card) -> a spirit of this player is new
  local LOG = 3661580131                 -- CMND_EVT_LOG
  local CHARA_INFO = 4060384944          -- CMND_GET_CHARA_INFO (card, 8) -> the card type (chara_param col 41)
  local SPIRIT_NUM = 1883729669          -- CMND_GET_SPIRIT_NUM (card, rarity) -> ok, stock
  local ADD_SPIRIT = 2757645277          -- CMND_ADD_ITEM_SPIRIT (card, count, rarity, used)
  local AUTO_SAVE = 3673719958           -- CMND_SYSTEM_AUTO_SAVE
  local FLAG_GET = 100903117             -- CMND_EVT_UI_FLAG_GET (key) -> number
  local FLAG_SET = 489464673             -- CMND_EVT_UI_FLAG_SET (key, value)
  local FLAG_PERSIST = 3323775344        -- CMND_EVT_UI_FLAG_PERSIST (key, value): kept with the save
  local ACTIVE_SLOT = 4245285902         -- CMND_VRFW_SLOT_ACTIVE -> the loaded save's slot (0 = none)
  local IN_STORY = 424926145             -- true while the story's play mode runs (its roster is another bank)
  local DOCK_LIST_LAYER = 3367997069     -- team01_02_list_item (both team docks)
  local LAST_NORMAL_RARITY = 4           -- spirit rarities 0-4: the normal cards
  local FIRST_SPECIAL_CARD_TYPE = 5      -- card types 5-7 Ídolo, 8 Diamante, 9+ season / mods' cards
  local NORMAL_CARD_RARITY = 4           -- the rarity every normal card has with this mod
  local RECRUIT_LEVEL = 1                -- the summon screen's level
  local SCOUTED = 2                      -- CMND_ADD_PARTY source: scouted
  local SPIRIT_STOCK_MAX = 999
  local PENDING_MAX = 64
  local ENTRY_SIZE = 3

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
  local PENDING_COUNT_KEY = Crc("no_more_rarities_spirit_pending_count")
  local PENDING_KEY = Crc("no_more_rarities_spirit_pending")

  local function Log(...)
    pcall(funcLuaCommand, LOG, "NoMoreRarities spirit recruit", ...)
  end

  local function RemovalApplies()
    return type(NoMoreRarities.RarityRemovalApplies) ~= "function" or NoMoreRarities.RarityRemovalApplies()
  end

  -- 1. the notices -------------------------------------------------------------------------------------------------
  local retail_command = funcLuaCommand
  if type(retail_command) == "function" then
    funcLuaCommand = function(id, ...)
      if id == SPIRIT_INFO and RemovalApplies() then
        return true, false
      end
      if id == HAS_CHARA_SPIRIT and RemovalApplies() then
        return false
      end
      return retail_command(id, ...)
    end
  end

  -- 2. the «Espíritu» rows ------------------------------------------------------------------------------------------
  -- the Chronicle team dock: a copy of its list without the row
  local retail_sort = rawget(_ENV, "GetSortOflistItems")
  if type(retail_sort) == "function" then
    function GetSortOflistItems(...)
      local list = retail_sort(...)
      if type(list) ~= "table" or not RemovalApplies() then
        return list
      end
      local shown = {}
      for _, kind in ipairs(list) do
        if kind ~= SPIRIT_RPG_DOCK_ROW then
          shown[#shown + 1] = kind
        end
      end
      return shown
    end
  end

  -- «Plantilla de equipo»: its row-kind list, a chunk local reached as an upvalue (the list functions index it)
  local function FindUpvalue(names, matches)
    local debug_library = rawget(_ENV, "EVT_DEBUG")
    if type(debug_library) ~= "table" then
      return nil
    end
    local seen = {}
    local function Scan(f, depth)
      if type(f) ~= "function" or seen[f] or depth > 4 then
        return nil
      end
      seen[f] = true
      local i = 1
      while true do
        local name, value = debug_library.getupvalue(f, i)
        if name == nil then
          return nil
        end
        if type(value) == "table" and matches(value) then
          return value
        end
        if type(value) == "function" then
          local found = Scan(value, depth + 1)
          if found ~= nil then
            return found
          end
        end
        i = i + 1
      end
    end
    for _, name in ipairs(names) do
      local found = Scan(rawget(_ENV, name), 0)
      if found ~= nil then
        return found
      end
    end
    return nil
  end

  -- the row-kind list: numbers only, 3-16 rows, with the kinds every variant keeps (7, 8, 9: BetterUI's rule) and none
  -- of 3-6 (the chunk's other number lists)
  local function IsDockRowList(v)
    if v[0] ~= nil or #v < 3 or #v > 16 then
      return false
    end
    local seen = {}
    for _, kind in ipairs(v) do
      if type(kind) ~= "number" or (kind >= 3 and kind <= 6) then
        return false
      end
      seen[kind] = true
    end
    return seen[7] == true and seen[8] == true and seen[9] == true
  end

  local dock = {list = nil, removed_at = nil, logged = false}
  local function FilterDockRows()
    if dock.list == nil then
      dock.list = FindUpvalue({"SetupTeamDockListItemText", "OnSetupLayer", "OnDecideFocus"}, IsDockRowList)
    end
    local list = dock.list
    if list == nil then
      return
    end
    if RemovalApplies() then
      for row = #list, 1, -1 do
        if list[row] == SPIRIT_DOCK_ROW then
          table.remove(list, row)
          dock.removed_at = row
        end
      end
    elseif dock.removed_at ~= nil then
      table.insert(list, math.min(dock.removed_at, #list + 1), SPIRIT_DOCK_ROW)
      dock.removed_at = nil
    end
    if not dock.logged then
      dock.logged = true
      Log("team dock: «Espíritu» row " .. (dock.removed_at ~= nil and "removed" or "kept") .. ", " .. #list .. " row(s)")
    end
  end
  if type(rawget(_ENV, "SetupTeamDockListItemText")) == "function" and type(rawget(_ENV, "OnSetupLayer")) == "function" then
    local retail_setup = OnSetupLayer
    function OnSetupLayer(layer, row, ...)
      if layer == DOCK_LIST_LAYER and row == 0 then
        pcall(FilterDockRows)
      end
      return retail_setup(layer, row, ...)
    end
  end

  -- 3. a spirit drop = the player ------------------------------------------------------------------------------------
  local function FlagGet(key)
    local ok, value = pcall(retail_command, FLAG_GET, key)
    return (ok and type(value) == "number") and value or 0
  end

  local function FlagSet(key, value)
    local ok, done = pcall(retail_command, FLAG_PERSIST, key, value)
    if not ok or done == nil then
      pcall(retail_command, FLAG_SET, key, value)
    end
  end

  local function EntryKey(i, field)
    return (PENDING_KEY + ENTRY_SIZE * i + field) % 4294967296
  end

  local function ActiveSlot()
    local ok, slot = pcall(retail_command, ACTIVE_SLOT)
    return (ok and type(slot) == "number") and slot or 0
  end

  local function CardType(card)
    local ok, first, second = pcall(retail_command, CHARA_INFO, card, 8)
    if not ok or first == false then
      return nil
    end
    if type(second) == "number" then
      return second
    end
    return type(first) == "number" and first or nil
  end

  local function SpiritStock(card, rarity)
    local ok, found, stock = pcall(retail_command, SPIRIT_NUM, card, rarity)
    if not ok or found == false or type(stock) ~= "number" then
      return nil
    end
    return stock
  end

  local function ReadPending()
    local entries = {}
    local count = math.min(FlagGet(PENDING_COUNT_KEY), PENDING_MAX)
    for i = 1, count do
      local card = FlagGet(EntryKey(i, 0))
      if card ~= 0 then
        entries[#entries + 1] = {card = card, rarity = FlagGet(EntryKey(i, 1)), slot = FlagGet(EntryKey(i, 2))}
      end
    end
    return entries, count
  end

  local function WritePending(entries, old_count)
    for i = 1, math.max(old_count, #entries) do
      local e = entries[i]
      FlagSet(EntryKey(i, 0), e and e.card or 0)
      FlagSet(EntryKey(i, 1), e and e.rarity or 0)
      FlagSet(EntryKey(i, 2), e and e.slot or 0)
    end
    FlagSet(PENDING_COUNT_KEY, #entries)
  end

  -- a spirit row of the result screen: its player kept as pending (once per card, rarity and slot)
  function S.NotePending(card, rarity)
    if type(card) ~= "number" or card == 0 or type(rarity) ~= "number" or rarity < 0 or rarity > LAST_NORMAL_RARITY then
      return
    end
    if not RemovalApplies() then
      return
    end
    local card_type = CardType(card)
    if card_type == nil or card_type >= FIRST_SPECIAL_CARD_TYPE then
      return
    end
    local slot = ActiveSlot()
    local entries, count = ReadPending()
    for _, e in ipairs(entries) do
      if e.card == card and e.rarity == rarity and e.slot == slot then
        return
      end
    end
    if #entries >= PENDING_MAX then
      Log("pending list full: the spirit of card", card, "stays a spirit")
      return
    end
    entries[#entries + 1] = {card = card, rarity = rarity, slot = slot}
    WritePending(entries, count)
    Log("pending", card, "rarity", rarity, "slot", slot)
  end

  -- every pending player of the loaded slot recruited (the others kept); -> how many were recruited
  function S.RecruitPending(where)
    if not RemovalApplies() or type(VRFW_Recruit) ~= "table" or type(VRFW_Recruit.Sign) ~= "function" then
      return 0
    end
    local entries, count = ReadPending()
    if #entries == 0 then
      return 0
    end
    local ok_story, in_story = pcall(retail_command, IN_STORY)
    if ok_story and in_story == true then
      return 0                           -- the story's roster is not the bank: kept for a menu outside the story
    end
    local slot = ActiveSlot()
    local kept, recruited = {}, 0
    for _, e in ipairs(entries) do
      if e.slot ~= slot then
        kept[#kept + 1] = e
      else
        local before = SpiritStock(e.card, e.rarity)
        if before == nil or before < 1 then
          Log(where, "card", e.card, "rarity", e.rarity, ": no such spirit in the bag (used or not given): nothing done")
        else
          local hdl, why = VRFW_Recruit.Sign(e.card, RECRUIT_LEVEL, NORMAL_CARD_RARITY, SCOUTED)
          if hdl == nil then
            Log(where, "card", e.card, ": not recruited (" .. tostring(why) .. "): the spirit stays")
          else
            recruited = recruited + 1
            local now = SpiritStock(e.card, e.rarity)
            local taken = false
            if now == before and now >= 1 and now < SPIRIT_STOCK_MAX then
              pcall(retail_command, ADD_SPIRIT, e.card, -1, e.rarity, false)
              taken = SpiritStock(e.card, e.rarity) == before - 1
            end
            Log(where, "card", e.card, "recruited into the bank at rarity", NORMAL_CARD_RARITY, "handle", hdl,
              taken and "spirit taken back" or ("spirit NOT taken back (stock " .. tostring(before) .. " -> " .. tostring(now) .. ")"))
          end
        end
      end
    end
    WritePending(kept, count)
    if recruited > 0 then
      pcall(retail_command, AUTO_SAVE)
    end
    return recruited
  end

  -- the result screen: its spirit rows (UpdateItem(layer, row, focused, count, card, ..., rarity, isSpirit, ...))
  if type(rawget(_ENV, "UpdateItem")) == "function" and type(rawget(_ENV, "UpdateSpiritItem")) == "function" then
    local retail_item = UpdateItem
    function UpdateItem(a1, a2, a3, a4, card, a6, rarity, is_spirit, ...)
      if is_spirit == true then
        pcall(S.NotePending, card, rarity)
      end
      return retail_item(a1, a2, a3, a4, card, a6, rarity, is_spirit, ...)
    end
  end

  -- the menus of a loaded save: the pending players on their first step
  local patch = rawget(_ENV, "EVT_PATCH")
  local script = type(patch) == "table" and patch.script or nil
  local stem = type(script) == "string" and script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "") or nil
  local recruits_here = false
  for _, menu in ipairs(RECRUIT_MENUS) do
    recruits_here = recruits_here or menu == stem
  end
  if recruits_here and type(rawget(_ENV, "Step")) == "function" then
    local retail_step = Step
    local done = false
    function Step(...)
      if not done then
        done = true
        local ok, err = pcall(S.RecruitPending, stem)
        if not ok then
          Log(stem, "failed:", tostring(err))
        end
      end
      return retail_step(...)
    end
  end
end
