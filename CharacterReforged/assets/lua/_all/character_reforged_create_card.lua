-- Character Reforged: the aura mods' «Crear …» entries in the game's ability lists, ONE rule for the skill board's aura
-- list (ability_list_menu_on_bluebg, graft character_reforged_board) and the «Fantasy» skill table's picker
-- (ability_list_menu, graft ss2_menus); docs/game/mods/all-miximaxed.md §7 (owner 2026-10-14):
--   * a «create» row (every declared system's item, CMND_CHARACTERREFORGED_CREATE_ITEMS) is a neutral row: no counts,
--     the aura type's own icon (Mix-Max icon_sp_area07, «Modo cambio» icon_sp_area11), as Inazuma Fantasy drew it;
--   * its detail card (a miximax window team00_30_aura_mixi_max_detail_info) is the item's own: its name and its
--     description (the item's own texts, 9 languages: All Miximaxed's techniques\carriers.toml), the neutral Mix-Max
--     band, no portrait and no move (the row is a clone of a retail Mix-Max: without this it showed that row's
--     character and move: Arion, «Túnel tornado»);
--   * a retail Mix-Max row the shown player can not take (its AURA_CMD_CHARA owners / change_aura whitelist, the
--     VR-Framework's CMND_VRFW_MIXIMAX_ITEM_ALLOWED) is greyed and refused with the retail error sound.
--   * a «create» row the shown player may not be the base of (the avatar, for a system whose rules say avatar_may_pair
--     = false) is not listed at all (Card.WithholdCreates before the list opens).
-- Definitions only (this file is in `_all`): no engine call at load.
CharacterReforged = type(CharacterReforged) == "table" and CharacterReforged or {}
if CharacterReforged.CreateCard == nil then
  local Card = {}
  CharacterReforged.CreateCard = Card
  Card.ITEMS = 2820944175                  -- CMND_CHARACTERREFORGED_CREATE_ITEMS () -> n, create item 1 .. n
  Card.ITEM_ALLOWED = 3462128076           -- CMND_VRFW_MIXIMAX_ITEM_ALLOWED (aura, charaStHdl) -> restricted, allowed
  Card.SKILL_INFO = 2580586398             -- (skill, field): 4 name id, 5 description id, 13 aura type
  Card.NAME_TEXT = 720417636
  Card.DESC_TEXT = 4113915188
  Card.AURA_MIXIMAX = 2
  Card.AURA_MODE_CHANGE = 6
  Card.ICON_BY_TYPE = {[2] = 2185069032 --[[icon_sp_area07]], [6] = 1917130140 --[[icon_sp_area11]]}
  Card.ICON_ATLAS = 2320109963             -- icon_common
  Card.MIXIMAX_WINDOW = 3679282495         -- team00_30_aura_mixi_max_detail_info
  Card.IS_AVATAR = 2461887648              -- CMND_GET_IS_AVATAR_CHARA (charaStHdl) -> the player's avatar
  Card.ROW_OF = 2827747337                 -- CMND_CHARACTERREFORGED_CREATE_ROW (item) -> row, store, scene, avatarMayPair
  Card.items = nil

  function Card.U32(v)
    v = tonumber(v) or 0
    if v < 0 then
      v = v + 4294967296
    end
    return v
  end

  -- the create items of the declared systems (asked once per list: Card.Reset at the list's OnInit)
  function Card.Reset()
    Card.items = nil
  end

  function Card.IsCreate(skill)
    if type(skill) ~= "number" or skill == 0 then
      return false
    end
    if Card.items == nil then
      Card.items = {}
      local ok, answer = pcall(function() return table.pack(funcLuaCommand(Card.ITEMS)) end)
      if ok and type(answer[1]) == "number" then
        for i = 1, answer[1] do
          if type(answer[i + 1]) == "number" then
            Card.items[Card.U32(answer[i + 1])] = true
          end
        end
      end
    end
    return Card.items[Card.U32(skill)] == true
  end

  -- is `hdl` the player's avatar? the game's own answer (CMND_GET_IS_AVATAR_CHARA)
  function Card.IsAvatar(hdl)
    if type(hdl) ~= "number" or hdl == 0 then
      return false
    end
    local ok, avatar = pcall(funcLuaCommand, Card.IS_AVATAR, hdl)
    return ok and avatar == true
  end

  -- may player `hdl` be the base of create item `skill`? false only for the avatar when the item's system says
  -- avatar_may_pair = false (All Miximaxed); anything that is not a create item: true
  function Card.CreateAllowed(skill, hdl)
    if not Card.IsCreate(skill) or not Card.IsAvatar(hdl) then
      return true
    end
    local ok, row, _, _, avatar_may_pair = pcall(funcLuaCommand, Card.ROW_OF, skill)
    return not (ok and type(row) == "number" and row > 0 and avatar_may_pair == false)
  end

  Card.UI_FLAG_SET = 489464673             -- CMND_EVT_UI_FLAG_SET (key, value)
  Card.UI_FLAG_GET = 100903117             -- CMND_EVT_UI_FLAG_GET (key) -> value (0 = not set)
  Card.LOG = 2743311895                    -- CMND_CHARACTERREFORGED_CREATE_LOG (step, values…)

  -- the «create» rows player `hdl` may not be the base of (Card.CreateAllowed) are left out of the next ability list:
  -- the framework hides a create entry while the UI flag keyed by its item id is 1; hdl = nil gives every row back
  function Card.WithholdCreates(hdl)
    Card.IsCreate(1)                       -- the create items read (once per list)
    for item in pairs(Card.items or {}) do
      local withheld = hdl ~= nil and not Card.CreateAllowed(item, hdl)
      local ok, now = pcall(funcLuaCommand, Card.UI_FLAG_GET, item)
      if not ok or (now == 1) ~= withheld then
        pcall(funcLuaCommand, Card.UI_FLAG_SET, item, withheld and 1 or 0)
        pcall(funcLuaCommand, Card.LOG, "create row withheld", "item", item, "player", hdl or 0, withheld)
      end
    end
  end

  function Card.AuraType(skill)
    local ok, t = funcLuaCommand(Card.SKILL_INFO, skill, 13)
    return ok and t or nil
  end

  -- may player `hdl` take aura `skill`? true for anything that is not a restricted retail Mix-Max row
  function Card.Allowed(skill, hdl)
    local _, allowed = Card.Rule(skill, hdl)
    return allowed
  end

  -- the VR-Framework's rule for player `hdl` and aura `skill` -> answered, allowed (answered = false: no framework
  -- answer, allowed = true)
  function Card.Rule(skill, hdl)
    if type(skill) ~= "number" or skill == 0 or type(hdl) ~= "number" or hdl == 0 then
      return false, true
    end
    local ok, restricted, allowed = pcall(funcLuaCommand, Card.ITEM_ALLOWED, skill, hdl)
    if not ok or type(restricted) ~= "boolean" then
      return false, true
    end
    return true, not (restricted and allowed == false)
  end

  function Card.Name(skill)
    local ok, id = funcLuaCommand(Card.SKILL_INFO, skill, 4)
    if ok and id ~= nil then
      local s = funcLuaCommand(Card.NAME_TEXT, id)
      if type(s) == "string" then
        return s
      end
    end
    return ""
  end

  function Card.Desc(skill)
    local ok, id = funcLuaCommand(Card.SKILL_INFO, skill, 5)
    if ok and id ~= nil then
      local okt, s = pcall(funcLuaCommand, Card.DESC_TEXT, id)
      if okt and type(s) == "string" then
        return s
      end
    end
    return ""
  end

  -- list row `inst` of layer `L` for a create item: its own name, no counts, no element / category, the type's icon
  function Card.Row(L, inst, skill)
    local name = Card.Name(skill)
    if name ~= "" then
      funcLuaMenuCommand(1083631230, L, 931545948 --[[_text_list01_on]], name, inst)
      funcLuaMenuCommand(1083631230, L, 3705682548 --[[_text_list01_off]], name, inst)
    end
    for _, m in ipairs({1255155594 --[[_icon_cmd_type_dmy01]], 2172872396 --[[_icon_cmd_type_base01]],
        559600405 --[[_icon_sp_sub_dmy01]], 1228576956 --[[_base_have01]], 1202991162 --[[_base_equip01]],
        2037408502 --[[_icon_have01]], 1139638886 --[[_gtxt_equip01]]}) do
      funcLuaMenuCommand(3405944500, L, m, false, inst)
    end
    funcLuaMenuCommand(2158717427, L, 442049775 --[[_pos_equip01]], false, inst)
    funcLuaMenuCommand(2158717427, L, 3426045766 --[[_pos_have01]], false, inst)
    funcLuaMenuCommand(1233047821 --[[number visible]], L, inst, 3334923667 --[[num_have01]], false)
    funcLuaMenuCommand(1233047821 --[[number visible]], L, inst, 3974820126 --[[num_equip01]], false)
    local icon = Card.ICON_BY_TYPE[Card.AuraType(skill) or -1]
    if icon ~= nil then
      funcLuaMenuCommand(3405944500, L, 2164615260 --[[_icon_sp_area_dmy01]], true, inst)
      funcLuaMenuCommand(558735651, L, Card.ICON_ATLAS, icon, 566439826 --[[icon_sp_area_dmy01]], 0, inst)
    else
      funcLuaMenuCommand(3405944500, L, 2164615260, false, inst)
    end
  end

  -- the detail card of a Mix-Max create item (after the game filled the window with the template row): the item's name
  -- and description, the neutral band, no portrait, no move page; false = not a Mix-Max create item / no window
  function Card.Detail(skill)
    if not Card.IsCreate(skill) or Card.AuraType(skill) ~= Card.AURA_MIXIMAX then
      return false
    end
    local A = Card.MIXIMAX_WINDOW
    if not funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER]], A) then
      return false
    end
    for _, p in ipairs({3407216458 --[[_pos_page01]], 1377611504 --[[_pos_page02]], 3145665477 --[[_pos_page04]],
        3430431571 --[[_pos_page05]], 1307475940 --[[_pos_list01]], 3571920478 --[[_pos_list02]]}) do
      funcLuaMenuCommand(2158717427, A, p, false, 0)
    end
    funcLuaMenuCommand(711242136, 1921826160 --[[team00_40_change_page_guide]], 0, false)
    -- the template's move page: every part hidden explicitly (a part the fill showed stays drawn under a hidden locator)
    for _, x in ipairs({1179414078 --[[_text_fsp01]], 1899787537 --[[_text_area01]], 3542179801 --[[_text_page_title01]],
        1244139107 --[[_text_page_title02]], 2739645270 --[[_text_page_title04]], 3561790400 --[[_text_page_title05]],
        691026122 --[[_text_flavor01]], 777911507 --[[_text_flavor05]], 325360264 --[[_text_scr_btn01]],
        1757105749}) do
      funcLuaMenuCommand(2735666188, A, x, false, 0)
    end
    for _, m in ipairs({3032210235, 206240291, 563708378 --[[_gtxt_cmd_at01]], 3516146179 --[[_area_base01]],
        811580556 --[[_gtxt_armed01]], 1013569271 --[[_ai_use01]], 2992676399, 2269285990, 2408672862,
        658945009, 905124895, 2370796410, 1956062673, 859266817, 240613041, 380545388, 68880002, 3165086183,
        561011038, 4195885618, 3182975202, 2161668434, 855158082, 4122450641,
        2449339029 --[[_icon_fs_dmy01]], 478320441 --[[_icon_chr_dmy01]]}) do
      funcLuaMenuCommand(3405944500, A, m, false, 0)
    end
    funcLuaMenuCommand(1233047821 --[[number visible]], A, 0, 2223127589 --[[AT power]], false)
    funcLuaMenuCommand(4176779611 --[[clear face icon]], A, 0, 3237726902 --[[icon_chr_dmy01]])
    -- the description page: the item's own name and text
    funcLuaMenuCommand(2158717427, A, 622567014 --[[_pos_page03]], true, 0)
    funcLuaMenuCommand(3405944500, A, 728354709, true, 0)
    funcLuaMenuCommand(1083631230, A, 2915321899 --[[_text_fs01]], Card.Name(skill), 0)
    funcLuaMenuCommand(1083631230, A, 2956552560 --[[_text_flavor02]], Card.Desc(skill), 0)
    funcLuaMenuCommand(2735666188, A, 2956552560, true, 0)
    -- the neutral band: the retail Mix-Max band, element 01
    funcLuaMenuCommand(558735651, A, 2815298114 --[[team00_30 <LG>]], 3558327990 --[[mixi_base01]], 1716659057 --[[fs_base01]], 0, 0)
    funcLuaMenuCommand(3405944500, A, 1605611365, true, 0)
    return true
  end

  -- The partner bank opened straight from the list that picked a «create» row (owner 2026-10-14: «debería ser darle y
  -- pasar directamente al banco»): the list's close and the bank's open run together, so the board / skill table is
  -- never shown in between. The create flow behind the list (board_create_entry_hooks.lua AfterList,
  -- table_create_entry_hooks.lua BankPick) finds the flag and waits for this bank instead of opening its own.
  Card.ROW = 2827747337                    -- CMND_CHARACTERREFORGED_CREATE_ROW (item) -> row (0 none), store command id
  Card.KEY_BASE = 2918576166               -- character_reforged_create_base (read by the bank's move step)
  Card.KEY_ROW = 416963278                 -- character_reforged_create_row
  Card.KEY_MOVES = {892911027, 2888952841} -- character_reforged_create_move1 / _move2
  Card.KEY_EARLY = 1743709088              -- character_reforged_create_bank_early: 1 = the bank is already opening
  Card.PARAM_SET = 3860611758
  Card.PARAM_DELETE = 3363400568
  Card.TEMP_SET = 2565779025
  Card.BANK_RESULT = 2524660062            -- the bank's pick (retail temp int)
  Card.OPEN_MENU = 433545986               -- CMND_OPEN_MENU_OBJECT
  Card.BANK_MENU = 1981996040              -- chara_bank_menu_for_search
  Card.MENU_SUSPEND = 1129326309           -- (menu) suspended while the bank is open
  Card.MENU_HIDE = 1670867360              -- (1, menu) the whole menu hidden (the retail full-screen movie hide)
  Card.LOG = 2743311895                    -- CMND_CHARACTERREFORGED_CREATE_LOG (step, values…)

  -- base = the player, item = the picked «create» item, hide = a menu to hide under the bank (nil = none);
  -- true = the bank is opening
  function Card.OpenBankEarly(base, item, hide)
    if type(base) ~= "number" or base == 0 or not Card.IsCreate(item) or not Card.CreateAllowed(item, base) then
      return false
    end
    local row = funcLuaCommand(Card.ROW, item)
    if type(row) ~= "number" or row <= 0 then
      return false
    end
    for _, key in ipairs(Card.KEY_MOVES) do
      funcLuaCommand(Card.PARAM_DELETE, key)
    end
    funcLuaCommand(Card.PARAM_DELETE, Card.KEY_BASE)
    funcLuaCommand(Card.PARAM_SET, Card.KEY_BASE, 0, base, 1)
    funcLuaCommand(Card.PARAM_DELETE, Card.KEY_ROW)
    funcLuaCommand(Card.PARAM_SET, Card.KEY_ROW, 0, row, 1)
    funcLuaCommand(Card.TEMP_SET, Card.BANK_RESULT, 0)
    funcLuaCommand(Card.PARAM_DELETE, Card.KEY_EARLY)
    funcLuaCommand(Card.PARAM_SET, Card.KEY_EARLY, 0, 1, 1)
    if hide ~= nil then
      -- every layer of that menu hidden, not only suspended: closing the list resumes its parent menu, and a resumed
      -- menu draws through the bank (owner 2026-10-14: the player card, role slot, plates and arrows over the bank)
      funcLuaMenuCommand(Card.MENU_HIDE, 1, hide)
      funcLuaMenuCommand(Card.MENU_SUSPEND, hide)
    end
    funcLuaCommand(Card.OPEN_MENU, Card.BANK_MENU)
    pcall(funcLuaCommand, Card.LOG, "bank opened from the list", "player", base, "row", row, "item", item)
    return true
  end
end
