-- Character Reforged › the aura mods' «Crear …» rows in the «Fantasy» skill table (evt_skill_slot_menu; graft
-- character_reforged_board, docs/refactor/aura-mods-split.md «The base game's create entry»). HOOK file (graft
-- [[hooks]], shipped as is: command ids written as numbers, their names in the comments): it wraps the screen's globals
-- EVT_PickCoroutine and EVT_Equip and calls them; no retail or Character Reforged function is replaced.
--   * the aura / mix row's picker is about to open (EVT_PickCoroutine, row 0): a free copy of every declared system's
--     «create» item is owned (the game's list only shows owned items; the screen's own code sets the UI flag
--     evt_mx_list_create that lists them), as on the retail board (board_create_entry_hooks.lua);
--   * a «create» item picked on that row (EVT_Equip, row 0): the partner (a system with partner moves: also his
--     moves, bank_create_moves_hooks.lua) from the retail bank picker, the system's
--     store command keeps the pair, a copy of the system's carrier goes to the player's mix slot (Character Reforged's
--     CMND_CHARACTERREFORGED_MIX_SET); a refusal plays the retail error sound (the reason goes to loader.log).
-- Inazuma Fantasy keeps its own flow (its commands answer CMND_EVT_MX_ITEMS): then both wraps pass straight through.
-- One row per system the active mods declare (All Miximaxed «Crear miximax», All Changed «Crear nuevo cambio»): ids,
-- store commands and carriers come from Character Reforged's script (CMND_CHARACTERREFORGED_CREATE_*), never written
-- here. The shown player = the chunk's local `n`, read through the skill table's extension point
-- (CharacterReforged.SkillTable.get, graft skill_table_host). Definitions and wraps only at chunk load (no engine call);
-- the screen's active / input state is never touched (the screen's pick coroutine keeps it inactive meanwhile).
do
  CharacterReforged_TableCreate = CharacterReforged_TableCreate or {}
  local Create = CharacterReforged_TableCreate
  Create.INAZUMA_FANTASY_ITEMS = 464382964           -- CMND_EVT_MX_ITEMS: answered only by Inazuma Fantasy (its own flow)
  Create.ITEMS = 2820944175                          -- CMND_CHARACTERREFORGED_CREATE_ITEMS () -> n, create item 1 .. n
  Create.ROW = 2827747337                            -- CMND_CHARACTERREFORGED_CREATE_ROW (item) -> row (0 none), store command id, scene
  Create.FADE = 609722083                            -- screen fade (1 out / 0 in, seconds)
  Create.MENU_HIDE = 1670867360                      -- (1, menu) the whole menu hidden (the retail full-screen movie hide)
  Create.MENU_SHOW = 3257327861                      -- (menu) shown again
  Create.MENU_CALL = 830228314                       -- (menu, function name, ...) a function of another menu (retail)
  Create.scene_row = false                           -- the picked system plays the creation scene after storing
  Create.CARRIER = 907079567                         -- CMND_CHARACTERREFORGED_CREATE_CARRIER (row, k) -> carrier item id
  Create.REFUSAL = 3947752921                        -- CMND_CHARACTERREFORGED_CREATE_REFUSAL (row, code) -> labelId, reasonId, labelText, reasonText
  Create.LOG = 2743311895                            -- CMND_CHARACTERREFORGED_CREATE_LOG (step, values…)
  Create.MIX_SET = 242652959                         -- CMND_CHARACTERREFORGED_MIX_SET (card, move) -> ok, code
  Create.ITEM_NUM = 2011560392                       -- CMND_GET_ITEM_NUM (item) -> copies owned
  Create.ADD_ITEM = 1897915498                       -- CMND_ADD_ITEM_ONLY (item, count, flag) -> inventory handle
  Create.DEL_ITEM = 425598937                        -- CMND_DELETE_ITEM (item, count)
  Create.EQUIPPED_NUM = 556568075                    -- (inventory handle) -> copies equipped
  Create.OPEN_MENU = 433545986                       -- CMND_OPEN_MENU_OBJECT
  Create.EXIST_MENU = 2231168902                     -- CMND_IS_EXIST_MENU_OBJECT
  Create.MENU_SUSPEND = 1129326309                   -- (menu) hidden while a child menu is open
  Create.MENU_RESUME = 1453710531                    -- (menu)
  Create.SCREEN = 1041963128                         -- evt_skill_slot_menu
  Create.BANK_MENU = 1981996040                      -- chara_bank_menu_for_search (the retail card picker)
  -- the bank's pick: retail temp int 2524660062 (OnInit sets 0, OnDecideFocus sets the card's handle then CloseMenu)
  -- the partner's moves (1.7.22): the bank picker reads the base and the row (bank_create_moves_hooks.lua: Aceptar on a
  -- card -> his special moves on the plate -> the system's confirmation) and writes the picked moves back
  Create.PARAM_DELETE = 3363400568                     -- parameter store: delete (key)
  Create.PARAM_SET = 3860611758                        -- parameter store: set (key, 0, value, 1)
  Create.KEY_BASE = 2918576166                         -- character_reforged_create_base: the base (the bank reads and clears it)
  Create.KEY_EARLY = 1743709088                       -- character_reforged_create_bank_early: the picker already opened the bank
  Create.KEY_ROW = 416963278                           -- character_reforged_create_row: the system's row
  Create.KEY_MOVES = {892911027, 2888952841}           -- character_reforged_create_move1 / _move2: the picked moves (0 = none)
  Create.PARAM_HAS = 2947612279                     -- parameter store: has (key)
  Create.PARAM_GET = 3522198769                     -- parameter store: get (key)
  Create.TEMP_GET = 3185911119
  Create.TEMP_SET = 2565779025
  Create.BANK_RESULT = 2524660062
  Create.TEXT_GET = 4074371074                       -- CMND_TEXT_GET (text id) -> the text in the game's language
  Create.SOUND = 1917805374                          -- play a system sound
  Create.SOUND_DECIDE = 4235359837
  Create.SOUND_REFUSED = 2086672038
  Create.OPEN_WAIT = 90                              -- frames the bank may take to open

  function Create.Log(step, ...)
    pcall(funcLuaCommand, Create.LOG, "table " .. tostring(step), ...)
  end

  -- Inazuma Fantasy's own create flow is on (its commands answer): this file stays out of the way
  function Create.InazumaFantasyFlow()
    local ok, item = pcall(funcLuaCommand, Create.INAZUMA_FANTASY_ITEMS)
    return ok and type(item) == "number" and item ~= 0
  end

  -- the shown player (the screen's chunk local `n`, served by the skill table's extension point)
  function Create.Player()
    local table_api = type(CharacterReforged) == "table" and CharacterReforged.SkillTable or nil
    local get = type(table_api) == "table" and table_api.get or nil
    local hdl = type(get) == "table" and type(get.n) == "function" and get.n() or nil
    if type(hdl) == "number" and hdl ~= 0 then
      return hdl
    end
    return nil
  end

  function Create.Wait(frames)
    for _ = 1, frames do
      coroutine.yield()
    end
  end

  -- before the aura / mix row's picker opens: a free copy of every system's «create» item owned
  function Create.BeforePicker()
    funcLuaCommand(Create.PARAM_DELETE, Create.KEY_EARLY)   -- a flag left by an earlier picker is never this one's
    if Create.InazumaFantasyFlow() then
      return
    end
    local answer = table.pack(funcLuaCommand(Create.ITEMS))
    local count = answer[1]
    if type(count) ~= "number" or count <= 0 then
      return                                         -- no system declared, or Character Reforged's script is not running
    end
    for i = 1, count do
      local create = answer[i + 1]
      if type(create) == "number" and create ~= 0 then
        local owned = funcLuaCommand(Create.ITEM_NUM, create)
        local granted = false
        if type(owned) ~= "number" or owned <= 0 then
          funcLuaCommand(Create.ADD_ITEM, create, 1, false)
          granted = true
        else
          local handle = funcLuaCommand(Create.ADD_ITEM, create, 1, false)
          funcLuaCommand(Create.DEL_ITEM, create, 1)
          local used = (type(handle) == "number" and handle ~= 0) and funcLuaCommand(Create.EQUIPPED_NUM, handle) or 0
          if type(used) == "number" and used >= owned then
            funcLuaCommand(Create.ADD_ITEM, create, 1, false)
            granted = true
          end
        end
        Create.Log("1 list", "row", i, "item", create, "owned", owned, "free copy granted", granted)
      end
    end
  end

  -- before the bank opens: the base and the row for its move step (a system without `moves` leaves the bank retail)
  function Create.BankKeys(hdl, row)
    for _, key in ipairs(Create.KEY_MOVES) do
      funcLuaCommand(Create.PARAM_DELETE, key)
    end
    funcLuaCommand(Create.PARAM_DELETE, Create.KEY_BASE)
    funcLuaCommand(Create.PARAM_SET, Create.KEY_BASE, 0, hdl, 1)
    funcLuaCommand(Create.PARAM_DELETE, Create.KEY_ROW)
    funcLuaCommand(Create.PARAM_SET, Create.KEY_ROW, 0, row, 1)
  end

  -- after the bank closed: the picked moves (0 = none); every key of this flow cleared
  function Create.BankMoves()
    local moves = {}
    for i, key in ipairs(Create.KEY_MOVES) do
      local move = 0
      if funcLuaCommand(Create.PARAM_HAS, key) == true then
        move = funcLuaCommand(Create.PARAM_GET, key)
      end
      moves[i] = type(move) == "number" and move or 0
      funcLuaCommand(Create.PARAM_DELETE, key)
    end
    funcLuaCommand(Create.PARAM_DELETE, Create.KEY_BASE)
    funcLuaCommand(Create.PARAM_DELETE, Create.KEY_ROW)
    return moves[1], moves[2]
  end

  -- the system's store: (base, partner), or (base, partner, move1, move2) when moves were picked
  function Create.Store(store, hdl, partner, move1, move2)
    if move1 ~= 0 then
      return funcLuaCommand(store, hdl, partner, move1, move2)
    end
    return funcLuaCommand(store, hdl, partner)
  end

  -- a refusal: the retail error sound only, no blocking window (owner 2026-10-14); the reason goes to loader.log
  function Create.Refusal(row, code)
    local _, reason_id, label_s, reason_s = funcLuaCommand(Create.REFUSAL, row, code)
    local reason = type(reason_s) == "string" and reason_s or ""
    if reason == "" and type(reason_id) == "number" and reason_id ~= 0 then
      local ok, v = pcall(funcLuaCommand, Create.TEXT_GET, reason_id)
      if ok and type(v) == "string" then
        reason = v
      end
    end
    funcLuaCommand(Create.SOUND, Create.SOUND_REFUSED)
    Create.Log("7 refusal", "row", row, "code", code, "label", type(label_s) == "string" and label_s or "", "reason", reason)
  end

  -- the partner from the retail bank picker (the screen hidden meanwhile): his handle, 0 = cancelled
  function Create.BankPick(row)
    -- the picker opened the bank itself (CharacterReforged.CreateCard.OpenBankEarly, the screen already hidden): only
    -- wait for it
    local early = funcLuaCommand(Create.PARAM_HAS, Create.KEY_EARLY) == true
    funcLuaCommand(Create.PARAM_DELETE, Create.KEY_EARLY)
    -- the screen hidden and suspended under the bank: closing the picker resumed it, so it is suspended again here
    funcLuaMenuCommand(Create.MENU_HIDE, 1, Create.SCREEN)
    funcLuaMenuCommand(Create.MENU_SUSPEND, Create.SCREEN)
    if not early then
      Create.BankKeys(Create.Player() or 0, row)
      funcLuaCommand(Create.TEMP_SET, Create.BANK_RESULT, 0)
      funcLuaCommand(Create.OPEN_MENU, Create.BANK_MENU)
    end
    coroutine.yield()
    local frames = 0
    while not funcLuaMenuCommand(Create.EXIST_MENU, Create.BANK_MENU) and frames < Create.OPEN_WAIT do
      frames = frames + 1
      coroutine.yield()
    end
    local seen = funcLuaMenuCommand(Create.EXIST_MENU, Create.BANK_MENU) == true
    Create.Log("3 bank open", "exists", seen, "after frames", frames, "opened by the picker", early)
    if seen and early then
      -- the resumed screen rewrote the shared button guide: the bank's own guide again
      pcall(funcLuaCommand, Create.MENU_CALL, Create.BANK_MENU, "UpdateButtonGuide")
    end
    while seen and funcLuaMenuCommand(Create.EXIST_MENU, Create.BANK_MENU) do
      coroutine.yield()
    end
    local picked = funcLuaCommand(Create.TEMP_GET, Create.BANK_RESULT)
    if Create.scene_row and type(picked) == "number" and picked ~= 0 then
      funcLuaCommand(Create.FADE, 1, 0)              -- the scene follows: the screen stays black under it
    end
    funcLuaMenuCommand(Create.MENU_SHOW, Create.SCREEN)
    funcLuaMenuCommand(Create.MENU_RESUME, Create.SCREEN)
    coroutine.yield()
    local partner = funcLuaCommand(Create.TEMP_GET, Create.BANK_RESULT)
    funcLuaCommand(Create.TEMP_SET, Create.BANK_RESULT, 0)
    local move1, move2 = Create.BankMoves()
    Create.Log("4 bank closed", "temp int 2524660062 =", partner, "moves", move1, move2)
    if type(partner) ~= "number" then
      return 0, 0, 0
    end
    return partner, move1, move2
  end

  -- the creation scene of the stored pair (owner 2026-10-14: the Chrono Stone MIXIMAX scene as in Inazuma Fantasy):
  -- the skill table's own player PL.MxScenePlay (graft ss2_menus), with its Inazuma Fantasy detection forced off for
  -- this call (the scene's commands answer from the declaring mod); the screen is given back faded in
  function Create.PlayScene(hdl)
    local table_api = type(CharacterReforged) == "table" and CharacterReforged.SkillTable or nil
    local get = type(table_api) == "table" and table_api.get or nil
    local screen = type(get) == "table" and type(get.PL) == "function" and get.PL() or nil
    local played = false
    if type(screen) == "table" and type(screen.MxScenePlay) == "function" then
      local stub = screen.MX_STUB
      screen.MX_STUB = false
      local ok, r = pcall(screen.MxScenePlay)
      screen.MX_STUB = stub
      played = ok and r == true
      Create.Log("8 scene", "player", hdl, "played", played, ok and "" or tostring(r))
    else
      Create.Log("8 scene", "player", hdl, "no scene player on this screen")
    end
    if not played then
      funcLuaCommand(Create.FADE, 0, 0.2)
    end
  end

  -- a «create» item picked on the aura / mix row: true = handled here (the screen's own equip does not run)
  function Create.Picked(row, skill)
    if row ~= 0 or type(skill) ~= "number" or skill == 0 or Create.InazumaFantasyFlow() then
      return false
    end
    local system, store, scene = funcLuaCommand(Create.ROW, skill)
    Create.scene_row = scene == true
    if type(system) ~= "number" or system <= 0 or type(store) ~= "number" or store == 0 then
      return false                                   -- not a create item: the screen's normal equip
    end
    local hdl = Create.Player()
    if hdl == nil then
      Create.Log("2 picked", "row", system, "no shown player: not created")
      funcLuaCommand(Create.SOUND, Create.SOUND_REFUSED)
      return true
    end
    Create.Log("2 picked", "row", system, "player", hdl, "store", store)
    local partner, move1, move2 = Create.BankPick(system)
    if partner == 0 then
      Create.Log("7 cancelled", "row", system)
      funcLuaCommand(Create.FADE, 0, 0.2)
      return true
    end
    local stored, k = Create.Store(store, hdl, partner, move1, move2)
    local code = type(stored) == "number" and stored or -3   -- -3: the store command did not answer a code
    Create.Log("5 store", "base", hdl, "partner", partner, "moves", move1, move2, "code", code, "k", k)
    if code == 0 then
      local carrier = funcLuaCommand(Create.CARRIER, system, k)
      local inv = 0
      if type(carrier) == "number" and carrier ~= 0 then
        inv = funcLuaCommand(Create.ADD_ITEM, carrier, 1, false) or 0
      end
      local ok, done = false, false
      if type(inv) == "number" and inv ~= 0 then
        ok, done = pcall(funcLuaCommand, Create.MIX_SET, hdl, carrier)
      end
      local placed = ok and done == true
      Create.Log("6 carrier", "item", carrier, "inv", inv, "mix slot", placed)
      if placed then
        funcLuaCommand(Create.SOUND, Create.SOUND_DECIDE)
        if Create.scene_row then
          Create.PlayScene(hdl)
        end
        return true
      end
      if type(inv) == "number" and inv ~= 0 then
        funcLuaCommand(Create.DEL_ITEM, carrier, 1)
      end
      code = -2                                      -- stored, the carrier not in the mix slot
    end
    if Create.scene_row then
      funcLuaCommand(Create.FADE, 0, 0.2)
    end
    Create.Refusal(system, code)
    return true
  end

  -- ---- the wraps (once per VM; each calls what it wrapped) -----------------------------------------------------
  -- (a script run again in the same VM defines its globals anew: they are wrapped again; never our own wrapper twice)
  function Create.WrapGlobal(name, make)
    Create.wrappers = Create.wrappers or {}
    local current = _ENV[name]
    if current == nil or Create.wrappers[name] == current then
      return
    end
    local wrapper = make(current)
    Create.wrappers[name] = wrapper
    _ENV[name] = wrapper
  end

  Create.WrapGlobal("EVT_PickCoroutine", function(previous)
    return function(row, ...)
      if row == 0 then
        local ok, err = pcall(Create.BeforePicker)
        if not ok then
          Create.Log("1 list", "error", tostring(err))
        end
      end
      return previous(row, ...)
    end
  end)

  Create.WrapGlobal("EVT_Equip", function(previous)
    return function(row, skill, ...)
      local ok, handled = pcall(Create.Picked, row, skill)
      if not ok then
        Create.Log("2 picked", "error", tostring(handled))
        return false
      end
      if handled then
        return true
      end
      return previous(row, skill, ...)
    end
  end)
end
