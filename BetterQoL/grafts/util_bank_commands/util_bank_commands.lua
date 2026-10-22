-- Utilities bank_commands (research/grafts/util_bank_commands, docs/game/ui/bank-commands.md): the «COMANDOS» popup of a
-- player in «Banco» (chara_bank_menu, OpenCharaBankSubWindow), Nacho 2026-09-30, Utilities since 2026-10-09.
--   0 Añadir al equipo            retail index 0
--   1 Tabla de habilidades        the skill table of the formation for this one player (SkillTable below)
--   2 Equipamiento                equip_menu (the formation's parameters, single-player mode)
--   3 Configuración de pasivas    Utilities' passive_config session on the bank's plate (personal_plate_menu)
--   4 Retiro rápido               the retail «Retirar» path (retail index 2: confirmation, retire; Inazuma Fantasy's
--                                 fichajes refund runs inside it) + an auto save, as the office «Dimitir»
--   5 Recuperar equipamiento      retail index 4
--   6 Recuperar auto. en banco    the retail toggle (its check box is row 6 now)
-- Gone: «Añadir a espacio de plantilla vacío» and the retail «Retirar» row (Retiro rápido does it).
-- Hook file: VRFW_Host handlers on the framework's host of chara_bank_menu (no merge, no promoted locals). The rows are
-- swapped where the retail OpenCharaBankSubWindow calls MENU_DEF.OpenSubWindow, so whatever runs under the dispatcher
-- (Inazuma Fantasy's lua_early file: aura_used's popup, fichajes) keeps working. The Kizuna club popup (retail flag2:
-- the opener's param 3997999031 = 1) keeps the retail rows.
--
-- What other mods declare (Lua, from their own patch of this stem, at load or later; read at call time):
--   BetterQoL.BankCommands.SkillTable = {Menu = <menu id>, Params = "equip" | "board", Clear = {<param keys>}}
--       the screen «Tabla de habilidades» opens (a mod whose formation entry opens its own skill screen). Default: the
--       retail ability board (ability_learning_board_menu, the retail type-5 parameters). "equip" = the parameters the
--       formation passes to equip_menu; Clear = extra param keys deleted before and after.
--   BetterQoL.BankCommands.Rules["<Prefix>.<Name>"] = {Retail = function(h) end, Lock = function(h) end}
--       Retail(h) true: the retail popup for that player; Lock(h) true: every row grey and A refused.
-- Always on. Nothing calls funcLuaCommand / funcLuaMenuCommand at chunk load.
Utilities = Utilities or {}
BetterQoL.BankCommands = BetterQoL.BankCommands or {}
BetterQoL.BankCommands.Rules = BetterQoL.BankCommands.Rules or {}
do
  local B = BetterQoL.BankCommands
  B.TX = {3932059529,                -- Añadir al equipo
          2489792255,                -- Tabla de habilidades
          241013657,                 -- Equipamiento
          2906972837,                -- Configuración de pasivas (passive_config's menu_text row)
          964589140,                 -- Retiro rápido
          3836303276,                -- Recuperar equipamiento
          2951363585}                -- Recuperar auto. en banco
  B.EXPL = {0, 0, 0, 0, 636011825, 3363291442, 1955677377}   -- explanation window per row (retail t8 texts)
  B.CHECKS = {0, 0, 0, 0, 0, 0, 1}   -- check box rows
  B.CHECK_ROW = 6                    -- the check box row (retail 5)
  B.RETAIL_CHECK_ROW = 5
  B.WIN_SIZE, B.WIN_Y = 7, -70       -- sub window size type 7 = 7 rows (retail 3 = 6 rows at -130)
  B.SUB_CB = "OnCharaBankSubWindowFunction"
  B.BANK_MENU = 3358148956           -- chara_bank_menu
  B.PLATE_MENU = 1427722143          -- personal_plate_menu
  B.EQUIP_MENU = 606230082           -- equip_menu
  B.BOARD_MENU = 1810526795          -- ability_learning_board_menu
  B.PC_INFO = 3569354349             -- CMND_BETTERQOL_PC_INFO
  B.KEY_REQ = 1800965173             -- util_pc_edit_req
  B.KEY_PARENT = 1737532001          -- util_pc_edit_parent
  B.KEY_DONE = 213739006             -- util_pc_edit_done
  B.LOG = 3661580131                 -- CMND_EVT_LOG (the ModLoader's log command)
  B.GUIDE_KEY = 115099233            -- param: the menu that owns the bank's button guide (retail n19)
  B.KIND_KEY = 3997999031            -- param: bank kind (1 = Kizuna club, retail flag2)
  B.CHECK_BIT = 229430511            -- global bit of «Recuperar auto. en banco»
  -- parameters of the two ways a skill table / equip screen is opened (deleted again when it closes)
  B.EQUIP_PARAMS = {4081600465, 2029825652, 363718978, 4145209998, 3308763177, 2719720834, 1038144478, 3357163798,
                    622145442, 813466851}
  B.BOARD_PARAMS = {4161869490, 813466851, 3357163798, 4081600465}
  B.DEFAULT_SKILL_TABLE = {Menu = B.BOARD_MENU, Params = "board"}
  B.open, B.arm, B.autosave, B.club, B.owner, B.logs = false, false, false, false, 2645952753 --[[main_menu]], 0

  function B.Log(...)
    if B.logs < 40 then
      B.logs = B.logs + 1
      pcall(funcLuaCommand, B.LOG, "utilities bank_commands", ...)
    end
  end

  local function exists(k)
    return funcLuaCommand(2947612279, k) == true
  end

  local function put(k, v, keep)
    funcLuaCommand(3363400568, k)
    if keep then
      funcLuaCommand(3860611758, k, 0, v)
    else
      funcLuaCommand(3860611758, k, 0, v, 1)
    end
  end

  local function menuExists(m)
    return funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], m) == true
  end

  local function ng()
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
  end

  -- a declared rule of another mod (Retail / Lock) answers true for this player
  function B.RuleSays(kind, h)
    for id, r in pairs(B.Rules) do
      local f = type(r) == "table" and r[kind] or nil
      if type(f) == "function" then
        local ok, v = pcall(f, h)
        if ok and v == true then
          return true, id
        elseif not ok then
          B.Log("rule failed", id, kind, tostring(v))
        end
      end
    end
    return false
  end

  function B.PassivesOk(h)
    local ok, got, mode = pcall(funcLuaCommand, B.PC_INFO, h)
    return ok and got == true and type(mode) == "number" and mode > 0
  end

  -- our rows for the normal popup (texts, enables, size, check boxes)
  function B.Rows(h)
    B.open, B.autosave = true, false
    local en = {1, 1, 1, B.PassivesOk(h) and 1 or 0, CanCharaBankRemove(h) and 1 or 0, 1, 1}
    if B.RuleSays("Lock", h) then
      en = {0, 0, 0, 0, 0, 0, 0}
    end
    return B.TX, en, B.WIN_SIZE, B.CHECKS
  end

  -- MENU_DEF.OpenSubWindow of this VM, wrapped once: the armed call of the normal bank popup gets our rows
  function B.WrapSubWindow()
    if type(MENU_DEF) ~= "table" or type(MENU_DEF.OpenSubWindow) ~= "function" then
      return false
    end
    if MENU_DEF.OpenSubWindow == B.subWrap then
      return true
    end
    local prev = MENU_DEF.OpenSubWindow
    B.subWrap = function(cb, fcb, count, texts, size, title, en, focus, b1, b2, kind, x0, t1, n1, t2, t3, n2, checks, ...)
      if B.arm and cb == B.SUB_CB then
        B.arm = false
        local h = GetSelectedCharaStHdlInList()
        texts, en, size, checks = B.Rows(h)
        count = #texts
      end
      return prev(cb, fcb, count, texts, size, title, en, focus, b1, b2, kind, x0, t1, n1, t2, t3, n2, checks, ...)
    end
    MENU_DEF.OpenSubWindow = B.subWrap
    return true
  end

  -- back in the bank: rows redrawn (the cursor stays on the player), plate, input, guide
  function B.Back(h)
    pcall(UpdateList)
    if menuExists(B.PLATE_MENU) then
      pcall(UpdatePersonalPlate, h)
    end
    SetCharaBankInputEnabled(true)
    pcall(UpdateButtonGuide)
  end

  local function clear(keys)
    for _, k in ipairs(keys or {}) do
      funcLuaCommand(3363400568, k)
    end
  end

  -- the parameters the formation passes to equip_menu (equip_menu_select OnInit), single-player mode
  function B.EquipParams(h)
    local main = true
    if type(MAIN_MENU) == "table" and type(MAIN_MENU.IsEnableUseMainMenu) == "function" then
      local ok, r = pcall(MAIN_MENU.IsEnableUseMainMenu)
      main = not ok or r == true
    end
    local dock = funcLuaCommand(3713813716 --[[CMND_GET_VS_USE_TEAM_SET]])
    local okF, got, fid = pcall(funcLuaCommand, 1033065575 --[[CMND_GET_TEAM_SET_INFO]], dock, 0, 4)
    put(4081600465, 0, true)         -- team kind 11v11 (the retail puts it without the flag, as here)
    put(2029825652, false)           -- one character, not the team member list (L / R do not change player)
    put(363718978, main)
    put(4145209998, 0)
    put(3308763177, false)
    put(2719720834, main)
    put(1038144478, h)               -- the character
    put(3357163798, dock)
    put(622145442, 0)
    put(813466851, (okF and got) and fid or 0)
  end

  -- the retail type-5 parameters of the ability board (team_dock_formation_menu), the VS team as context
  function B.BoardParams(h)
    local dock = funcLuaCommand(3713813716 --[[CMND_GET_VS_USE_TEAM_SET]])
    local okF, got, fid = pcall(funcLuaCommand, 1033065575 --[[CMND_GET_TEAM_SET_INFO]], dock, 0, 4)
    put(4161869490, h)               -- the character
    put(813466851, (okF and got) and fid or 0)
    put(3357163798, dock)
    put(4081600465, 0, true)         -- team kind 11v11
  end

  -- one screen for one bank player: the bank (and its plate) hidden while it runs, then back on the same player
  function B.Exec(menu, mode, h, extra)
    clear(extra)
    if mode == "board" then
      B.BoardParams(h)
    else
      B.EquipParams(h)
    end
    SetCharaBankInputEnabled(false)
    waitFalse(function()
      return funcLuaCommand(667479479, B.BANK_MENU)
    end)
    local plate = menuExists(B.PLATE_MENU)
    if plate then
      pcall(funcLuaMenuCommand, 1129326309, B.PLATE_MENU)
    end
    funcLuaMenuCommand(369172623, B.BANK_MENU, 1)
    funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], menu)
    coroutine.yield()
    local seen = false
    for _ = 1, 120 do
      if menuExists(menu) then
        seen = true
        break
      end
      coroutine.yield()
    end
    if seen then
      while menuExists(menu) do
        coroutine.yield()
      end
    else
      B.Log("menu did not open", menu)
      ng()
    end
    coroutine.yield()
    funcLuaMenuCommand(66378409, B.BANK_MENU, 1)
    if plate then
      pcall(funcLuaMenuCommand, 1453710531, B.PLATE_MENU)
    end
    clear(mode == "board" and B.BOARD_PARAMS or B.EQUIP_PARAMS)   -- nothing of this call may reach another screen
    clear(extra)
    B.Log("screen closed", menu, "chara", h, "opened", tostring(seen))
    B.Back(h)
  end

  function B.SkillTableScreen()
    local s = B.SkillTable
    if type(s) ~= "table" or type(s.Menu) ~= "number" then
      s = B.DEFAULT_SKILL_TABLE
    end
    return s.Menu, s.Params == "equip" and "equip" or "board", s.Clear
  end

  -- the bank's personal plate (the panel «Y mostrar estadísticas») is open: the retail local `flag` through the
  -- framework's host (nil when the host cannot read it)
  function B.PlateOpen()
    local ok, v = pcall(function()
      return VRFW_Host.hosts.chara_bank_menu.L.flag
    end)
    if ok and type(v) == "boolean" then
      return v
    end
    return nil
  end

  -- 2026-10-14 (owner screenshot): during the passive session the configurator's list window (personal_plate_menu,
  -- draw priority 449-452) covers the left half, but the bank's focused card (the native list view raises it) drew on
  -- top of its first row, and the bank's tab bar («Inazuma Eleven Cross» + its Z / C glyphs) stood over the
  -- configurator's filter header («Z ‹ Todas › C»). These bank layers are hidden while the session runs and shown
  -- again exactly as they were (only the instances that were visible).
  B.PC_HIDE_ALL = {3310065218 --[[cmn06_04_list_tab_attach_11_only]], 4044286600 --[[cmn06_20_list_tab_item]],
                   3222237174 --[[cmn06_20_list_tab_item_search]], 529927244 --[[cmn06_21_list_tab_search]],
                   8877084 --[[cmn06_11_sort_bar_left]], 1199683335 --[[team14_02_filter_guide]]}
  B.PC_HIDE_FOCUS = {1791816279 --[[team00_01_chara_card_for_list]], 2855422738 --[[team00_01_chara_card_blank_for_list]],
                     30530992 --[[team00_01_p4_check_mark]]}
  B.PC_HIDE_CURSOR = 2296367164      -- cmn05_01_cursor
  function B.HideForPassives()
    local hidden = {}
    local function hide(layer, idx)
      local ok, v = pcall(funcLuaMenuCommand, 1262717583 --[[is layer visible]], layer, idx)
      if ok and v == true then
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, idx, false)
        hidden[#hidden + 1] = {layer, idx}
      end
    end
    for _, layer in ipairs(B.PC_HIDE_ALL) do
      local ok, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], layer)
      if ok and type(n) == "number" then
        for i = 0, math.min(n, 64) - 1 do
          hide(layer, i)
        end
      end
    end
    local okS, sel = pcall(GetSelectedLayerIdxInList)
    if okS and type(sel) == "number" and sel >= 0 then
      for _, layer in ipairs(B.PC_HIDE_FOCUS) do
        hide(layer, sel)
      end
    end
    hide(B.PC_HIDE_CURSOR, 0)
    B.Log("passives: bank layers hidden", #hidden, "focused card", tostring(sel))
    return hidden
  end

  function B.ShowAgain(hidden)
    for _, e in ipairs(hidden or {}) do
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], e[1], e[2], true)
    end
  end

  -- «Configuración de pasivas»: the session of Utilities' configurator on the plate (as the formation's UTIL_PCD.Plate)
  function B.Passives(h)
    if not B.PassivesOk(h) then
      ng()
      B.Back(h)
      return
    end
    SetCharaBankInputEnabled(false)
    -- 2026-10-14: the bank BUILDS the plate menu in its OnSetupLayer and only hides it, so the menu always exists and
    -- the old «not menuExists» test never opened it: without the panel (Y «mostrar estadísticas») nothing took the
    -- session. The open state is the retail local `flag`; OpenPersonalPlate itself returns at once when it is open.
    local wasOpen = B.PlateOpen()
    local closeAfter = false
    if wasOpen ~= true and type(OpenPersonalPlate) == "function" then
      local ok = pcall(OpenPersonalPlate)
      closeAfter = ok and wasOpen == false
      for _ = 1, 20 do
        coroutine.yield()
      end
    end
    B.Log("passives: plate open before", tostring(wasOpen), "close after", tostring(closeAfter))
    local hidden = B.HideForPassives()
    pcall(UpdatePersonalPlate, h)
    coroutine.yield()
    funcLuaCommand(3363400568, B.KEY_DONE)
    put(B.KEY_PARENT, B.owner)
    put(B.KEY_REQ, h)
    local wait = 0
    while true do
      coroutine.yield()
      if exists(B.KEY_DONE) then
        funcLuaCommand(3363400568, B.KEY_DONE)
        break
      end
      if exists(B.KEY_REQ) then
        wait = wait + 1
        if wait > 90 then            -- the plate did not take it (no passive_config plate file)
          funcLuaCommand(3363400568, B.KEY_REQ)
          funcLuaCommand(3363400568, B.KEY_PARENT)
          ng()
          B.Log("passive session not taken", h)
          break
        end
      end
    end
    coroutine.yield()
    B.ShowAgain(hidden)
    if closeAfter and type(ClosePersonalPlate) == "function" then
      pcall(ClosePersonalPlate)          -- the panel was closed before the session: closed again
    end
    B.Back(h)
  end

  -- OnCharaBankSubWindowFunction with our rows: nil = handled here, else the retail index to go on with
  function B.Do(a1, h)
    if type(a1) ~= "number" or a1 < 0 then
      return a1
    end
    if B.RuleSays("Lock", h) then
      ng()
      WaitCloseSubWindow(false)
      B.Back(h)
      return nil
    end
    if a1 == 0 then
      return 0                       -- Añadir al equipo
    elseif a1 == 1 or a1 == 2 then
      WaitCloseSubWindow(false)
      funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
      if a1 == 1 then
        local menu, mode, extra = B.SkillTableScreen()
        B.Exec(menu, mode, h, extra)
      else
        B.Exec(B.EQUIP_MENU, "equip", h)
      end
      return nil
    elseif a1 == 3 then
      WaitCloseSubWindow(false)
      B.Passives(h)
      return nil
    elseif a1 == 4 then
      B.autosave = true              -- Retiro rápido = the retail «Retirar» path + auto save
      return 2
    elseif a1 == 5 then
      return 4                       -- Recuperar equipamiento
    elseif a1 == 6 then
      funcLuaCommand(3258400760 --[[CMND_SET_GLOBAL_BIT_FLAG]], B.CHECK_BIT, not funcLuaCommand(941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], B.CHECK_BIT))
      funcLuaCommand(628044124, B.CHECK_ROW, funcLuaCommand(941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], B.CHECK_BIT))
      return nil
    end
    return a1
  end

  -- wrap the callback `name` through the framework's host (an around handler: nxt = what is under it), else the
  -- global itself (once per definition)
  B.wrapped = B.wrapped or {}
  function B.Wrap(name, make)
    local H = VRFW_Host
    if type(H) == "table" and type(H.on) == "function" then
      H.on("chara_bank_menu", name, {id = "utilities.bank_commands." .. name, phase = "around", fn = function(nxt, ...)
        return make(nxt)(...)
      end})
      return true
    end
    local cur = rawget(_ENV, name)
    if type(cur) ~= "function" or B.wrapped[cur] then
      return false
    end
    local w = make(cur)
    B.wrapped[w] = true
    rawset(_ENV, name, w)
    return true
  end

  -- the bank kind and the menu that owns the bank's button guide (the retail OnInit reads and deletes both params)
  B.Wrap("OnInit", function(orig)
    return function(...)
      B.open, B.arm, B.autosave = false, false, false
      B.owner = 2645952753 --[[main_menu]]
      if exists(B.GUIDE_KEY) then
        B.owner = funcLuaCommand(3522198769, B.GUIDE_KEY)
      end
      B.club = exists(B.KIND_KEY) and funcLuaCommand(3522198769, B.KIND_KEY) == 1
      return orig(...)
    end
  end)

  -- the popup: armed for the normal bank, rows swapped at its OpenSubWindow, then our check box row and position
  B.Wrap("OpenCharaBankSubWindow", function(orig)
    return function(...)
      B.open, B.arm, B.autosave = false, false, false
      if not B.club and B.WrapSubWindow() then
        local h = GetSelectedCharaStHdlInList()
        if not B.RuleSays("Retail", h) then
          B.arm = true
        end
      end
      local r = table.pack(orig(...))
      B.arm = false
      if B.open then
        local on = funcLuaCommand(941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], B.CHECK_BIT)
        funcLuaCommand(628044124, B.RETAIL_CHECK_ROW, false)
        funcLuaCommand(628044124, B.CHECK_ROW, on)
        funcLuaCommand(63483614, 480, B.WIN_Y)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  B.Wrap("OnCharaBankSubWindowFunction", function(orig)
    return function(a1, ...)
      if B.open then
        local m = B.Do(a1, GetSelectedCharaStHdlInList())
        if m == nil then
          return
        end
        a1 = m
      end
      return orig(a1, ...)
    end
  end)

  -- explanation window of our rows (the retail texts of the rows that stay)
  B.Wrap("OnCharaBankSubWindowFocusFunction", function(orig)
    return function(a1, ...)
      if not B.open or type(a1) ~= "number" or a1 < 0 then
        return orig(a1, ...)
      end
      local t = B.EXPL[a1 + 1] or 0
      if t ~= 0 then
        funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], 3134383517 --[[win05_91_explanation_window]])
        local s = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], t)
        funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3134383517 --[[win05_91_explanation_window]], 691026122 --[[_text_flavor01]], s)
        funcLuaMenuCommand(2575768773, 3134383517 --[[win05_91_explanation_window]], 0, 1517329426 --[[_pos_base01]], 0, 480)
        funcLuaMenuCommand(2575768773, 3134383517 --[[win05_91_explanation_window]], 0, 1517329426 --[[_pos_base01]], 1, -689)
      else
        funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], 3134383517 --[[win05_91_explanation_window]])
      end
    end
  end)

  -- Retiro rápido: auto save after the retire, as the office «Dimitir»
  B.Wrap("RemoveCharaFromCharaBank", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      if B.autosave then
        B.autosave = false
        funcLuaCommand(3673719958 --[[CMND_SYSTEM_AUTO_SAVE]])
        B.Log("quick retire: auto save")
      end
      return table.unpack(r, 1, r.n)
    end
  end)
end
