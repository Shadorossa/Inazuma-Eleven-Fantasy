  -- ===== the shared partner picker (util_cp_core.src.lua, built into both hook files by gen_hooks.py) =====
  -- One picker for every screen that offers it (the retail board, Character Reforged's skill table): the list window
  -- of Utilities (layers util_pc_listbg / util_pc_list / util_pc_row: the passive configurator's objects, added to each
  -- screen by Utilities' menus), one page per partner slot (the move's named partners are the pre-selected defaults
  -- of the first slots, never a limit), the confirm popup (general_window type 191 with the
  -- performers' cards of util_cp_gw.lua) and CMND_UTIL_COMBO_SET. What differs per screen is a SCREEN table given to
  -- UTIL_CP.Open:
  --   player                      the shown player's charaStHdl
  --   Members()                   -> {formation = id or nil, {hdl, slot (formation slot 0-10 or nil), index}, ...}
  --                                  (the squad the picker lists), nil = no squad (the screen was opened without one)
  --   Begin() / Finish()          before the first page / after the picker (input, cursor, covers, the screen's guide)
  --   Frame()                     optional, once per frame while a page is up
  --   GuideMenu()                 the menu whose bottom guide shows Aceptar / Atrás
  --   GuideCall                   optional: the funcLuaMenuCommand to draw that guide with
  --   backdrop                    true = the list's own blue backdrop (layer util_pc_listbg) is shown
  --   Message(text)               optional: a message window (default UTIL_CP.Message)
  --   Help(text)                  optional: puts text on the screen's help line (Finish puts the screen's own back)
  -- Definitions only: no engine call at chunk load.
  UTIL_CP = UTIL_CP or {}
  UTIL_CP.CMD_INFO = @crc:CMND_UTIL_COMBO_INFO@
  UTIL_CP.CMD_GET = @crc:CMND_UTIL_COMBO_GET@
  UTIL_CP.CMD_SET = @crc:CMND_UTIL_COMBO_SET@
  UTIL_CP.TX_BTN = @crc:utilities.cp_btn@ -- «Compañeros»
  UTIL_CP.TX_SLOT = @crc:utilities.cp_slot@ -- «Compañero»
  UTIL_CP.TX_RANDOM = @crc:utilities.cp_random@ -- «Aleatorio (en el partido)»
  UTIL_CP.TX_ASK = @crc:utilities.cp_ask_move@ -- «¿Elegir estos compañeros para realizar <VALUE>?»
  UTIL_CP.TX_NOTEAM = @crc:utilities.cp_no_team@ -- «Abre la tabla desde la plantilla...»
  UTIL_CP.TX_HELP_PICK = @crc:utilities.cp_help_pick@ -- help line of a picker page
  UTIL_CP.TX_HELP_CONFIRM = @crc:utilities.cp_help_confirm@ -- help line of the confirm popup
  UTIL_CP.TX_ACCEPT = 1847312674 -- retail «Aceptar»
  UTIL_CP.TX_BACK = 430212020 -- retail «Atrás»
  UTIL_CP.GL_ENTER = 2750714971 -- <CMD_ENTER>
  UTIL_CP.GL_BACK = 1582778933 -- <CMD_BACK>
  UTIL_CP.GL_FUNC4 = 2085238077 -- <CMD_FUNC4>
  UTIL_CP.K_ENTER = 1981080283
  UTIL_CP.K_CLICK = 1651523701
  UTIL_CP.K_BACK = 3011112225
  UTIL_CP.K_UP = 1197218715
  UTIL_CP.K_DOWN = 3259546669
  UTIL_CP.K_FUNC4 = 1435897304
  UTIL_CP.CTRL = 1332654303 -- MENU_CTRL
  UTIL_CP.CTRL2 = 2748927068 -- MENU_CTRL_WITH_ANALOG_MOVE_FOCUS
  UTIL_CP.GUIDE = 1138543975 -- mainmenu01_06_base_button_guide
  UTIL_CP.GUIDE_TEXTS = 2209673388 -- (menu, guide, texts, glyphs, offsets)
  UTIL_CP.GUIDE_KEYS = 452337289 -- (menu, guide, commands)
  UTIL_CP.RETURN_GUIDE = 2005383485 -- mainmenu01_10_return_arrow_button_guide (the screen's bottom-left «Esc»)
  UTIL_CP.SE_MOVE = 2500047763
  UTIL_CP.SE_OK = 3848881948
  UTIL_CP.SE_DECIDE = 4235359837
  UTIL_CP.SE_NG = 2086672038
  UTIL_CP.SE_BACK = 202039849
  UTIL_CP.LOG = 3661580131 -- CMND_EVT_LOG -> loader.log
  -- Utilities' list window (the passive configurator's layers, added to each screen by Utilities' menus)
  UTIL_CP.BG = @crc:util_pc_listbg@
  UTIL_CP.LIST = @crc:util_pc_list@
  UTIL_CP.ITEM = @crc:util_pc_row@
  UTIL_CP.TITLE = 3660005257 -- _text_list_empty01 of the frame: the slot title «Compañero k / N»
  UTIL_CP.TITLE_STYLE = 3920063359 -- fs_28_w_cc_2d0_001_sclw (white, centred)
  UTIL_CP.VIEW = 6
  -- row nodes (team08_02 on the util_pc_row layout)
  UTIL_CP.R = {
    ON = 2334302522, OFF = 2022529787, HIDE = {1697431574, 4215821749, 2172872396, 2037408502},
    TEXT_ON = 931545948, TEXT_OFF = 3705682548, CHECK = 2309656400,
    FACE = 2164615260, FACE_SLOT = 566439826, ELEM = 1255155594, ELEM_SLOT = 917245562,
    POS = 2384755812, POS_SLOT = 669321680,
    NODE_POS = 2575768773, NODE_SCALE = 2885415772, RESET_FACE = 4176779611,
    -- row-local geometry (top-left corner + size, y up): miniface | element | position badge, the name after them
    FACE_AT = {8, 32, 64, 64}, ELEM_AT = {80, 22, 44, 44}, POS_AT = {130, 24, 66, 48},
    NAME_PAD = "\227\128\128\227\128\128", -- two full-width spaces: the text box starts at x 158, the badge ends at 196
  }
  -- outlined element / position icons and the «?» face (images\menu\200_icon\combo_partner_icons.toml of Utilities)
  UTIL_CP.ICON_TEX = 2320109963 -- #/menu/200_icon/15_icon_common/icon_common.g4tx
  UTIL_CP.ICON_TEX_LG = 502529699 -- #/menu/200_icon/15_icon_common/<LG>/icon_common.g4tx (retail element icons)
  UTIL_CP.POS_TEX = 2058213660 -- #/menu/200_icon/15_icon_common2/<LG>/icon_common2.g4tx
  UTIL_CP.ELEM_SPR = {@crc:util_cp_elem01@, @crc:util_cp_elem02@, @crc:util_cp_elem03@, @crc:util_cp_elem04@}
  UTIL_CP.POS_SPR = {[0] = @crc:util_cp_pos04@, [1] = @crc:util_cp_pos03@, [2] = @crc:util_cp_pos02@, [3] = @crc:util_cp_pos01@}
  UTIL_CP.UNKNOWN_SPR = @crc:util_cp_unknown@
  -- the general_window cards of the confirm popup (util_cp_gw.lua reads the same keys)
  UTIL_CP.GW = {
    N = @crc:util_cp_gw_n@,
    H = {@crc:util_cp_gw_h1@, @crc:util_cp_gw_h2@, @crc:util_cp_gw_h3@, @crc:util_cp_gw_h4@},
    I = {@crc:util_cp_gw_i1@, @crc:util_cp_gw_i2@, @crc:util_cp_gw_i3@, @crc:util_cp_gw_i4@},
    WINDOW = 191,
  }
  UTIL_CP.MAX_TEAM = 16
  UTIL_CP.NAT_ICON = {[1] = 0, [4] = 1, [3] = 2, [2] = 3} -- CHARA_INFO 11 natural position (PR, DL, MC, DF) -> icon type
  UTIL_CP.FORMATION_INFO = 2649030357 -- CMND_GET_SOCCER_FORMATION_INFO
  UTIL_CP.picking = false -- a picker page is up (the screens' focus guards read it)

  function UTIL_CP.Log(...)
    pcall(funcLuaCommand, UTIL_CP.LOG, "utilities combo_partners", ...)
  end

  function UTIL_CP.U32(v)
    if type(v) ~= "number" then
      return 0
    end
    if v < 0 then
      v = v + 4294967296
    end
    return v
  end

  function UTIL_CP.Text(id, value)
    local ok, s = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], id)
    if not ok or type(s) ~= "string" then
      return ""
    end
    if value ~= nil then
      local v = tostring(value)
      s = string.gsub(s, "<VALUE>", function()
        return v
      end)
    end
    return s
  end

  function UTIL_CP.SE(id)
    pcall(funcLuaCommand, 1917805374, id)
  end

  function UTIL_CP.Key(k)
    local okm, v = pcall(funcLuaCommand, 4265778440, UTIL_CP.CTRL, k)
    if okm and v == true then
      return true
    end
    local okn, w = pcall(funcLuaCommand, 4265778440, UTIL_CP.CTRL2, k)
    return okn and w == true
  end

  function UTIL_CP.WaitWindow()
    while funcLuaCommand(898725220) do
      coroutine.yield()
    end
    while not funcLuaCommand(682363669) do
      coroutine.yield()
    end
  end

  function UTIL_CP.Message(s)
    if s == nil or s == "" then
      return
    end
    funcLuaCommand(2289627655, s, 0, 0, 0, 0, 0, false)
    coroutine.yield()
    UTIL_CP.WaitWindow()
  end

  -- {performers, slots (partner slots), named = {chara ids: the defaults of slots 1..#named}} of a move; nil = no plugin
  -- / unknown move
  function UTIL_CP.Info(skill)
    if skill == nil or skill == 0 then
      return nil
    end
    local r = {pcall(funcLuaCommand, UTIL_CP.CMD_INFO, skill)}
    if not r[1] or type(r[2]) ~= "number" or r[2] <= 0 then
      return nil
    end
    local named = {}
    for k = 4, 6 do
      if type(r[k]) == "number" and r[k] ~= 0 then
        named[#named + 1] = UTIL_CP.U32(r[k])
      end
    end
    return {performers = r[2], slots = math.min(math.max(r[2] - 1, 0), 3), named = named}
  end

  -- the move's partner info when it needs partners (2+ performers), else nil
  function UTIL_CP.ComboInfo(skill)
    local info = UTIL_CP.Info(UTIL_CP.U32(skill))
    if info == nil or info.performers < 2 then
      return nil
    end
    return info
  end

  -- ---- the picker's layers --------------------------------------------------------------------------------------
  function UTIL_CP.Ours(L)
    return L == UTIL_CP.BG or L == UTIL_CP.LIST or L == UTIL_CP.ITEM
  end

  -- OnSetupLayer of one of the picker's layers: its draw priority (prio = {BG, LIST, ITEM}), hidden
  function UTIL_CP.SetupLayer(L, k, prio)
    local p = (L == UTIL_CP.BG and prio.BG) or (L == UTIL_CP.LIST and prio.LIST) or prio.ITEM
    pcall(funcLuaMenuCommand, 1491630496, L, k, p, true)
    if L == UTIL_CP.LIST then
      pcall(funcLuaMenuCommand, 2158717427, L, 1839509013, false, k)
      pcall(funcLuaMenuCommand, 2158717427, L, 1060758565, false, k)
    end
    pcall(funcLuaMenuCommand, 711242136, L, k, false)
  end

  function UTIL_CP.OpenLayer(L, k)
    k = k or 0
    if funcLuaMenuCommand(262659071, L) and not funcLuaMenuCommand(2640875187, L, k) then
      funcLuaMenuCommand(629267548, L, k)
    end
  end

  function UTIL_CP.Place(L, k, node, g)
    local R = UTIL_CP.R
    pcall(funcLuaMenuCommand, R.NODE_POS, L, k, node, 0, g[1])
    pcall(funcLuaMenuCommand, R.NODE_POS, L, k, node, 1, g[2])
    pcall(funcLuaMenuCommand, R.NODE_SCALE, L, k, node, g[3], g[4])
  end

  -- one row: miniface (or «?»), element, position badge, name; check on the current pick; grey when taken
  function UTIL_CP.Row(k, e, focused, current)
    local L, R = UTIL_CP.ITEM, UTIL_CP.R
    for _, m in ipairs(R.HIDE) do
      funcLuaMenuCommand(3405944500, L, m, false, k)
    end
    funcLuaMenuCommand(3405944500, L, R.ON, focused, k)
    funcLuaMenuCommand(3405944500, L, R.OFF, not focused, k)
    local name = R.NAME_PAD .. (e.name or "")
    if e.taken then
      name = "[CGRAYOUT04]" .. name .. "[C]"
    end
    funcLuaMenuCommand(1083631230, L, R.TEXT_ON, name, k)
    funcLuaMenuCommand(1083631230, L, R.TEXT_OFF, name, k)
    funcLuaMenuCommand(2735666188, L, R.TEXT_ON, focused, k)
    funcLuaMenuCommand(2735666188, L, R.TEXT_OFF, not focused, k)
    funcLuaMenuCommand(3405944500, L, R.CHECK, current == true, k)
    funcLuaMenuCommand(2158717427, L, 442049775, false, k)
    funcLuaMenuCommand(2158717427, L, 3426045766, false, k)
    funcLuaMenuCommand(1233047821, L, k, 3334923667, false)
    funcLuaMenuCommand(1233047821, L, k, 3974820126, false)
    UTIL_CP.Place(L, k, R.FACE, R.FACE_AT)
    UTIL_CP.Place(L, k, R.ELEM, R.ELEM_AT)
    UTIL_CP.Place(L, k, R.POS, R.POS_AT)
    -- face: a bound face outlives sprite swaps, so it is released first
    pcall(funcLuaMenuCommand, R.RESET_FACE, L, k, R.FACE_SLOT)
    local face = false
    if e.chara ~= nil and e.chara ~= 0 then
      pcall(SetDisableForceCharaInvalidUseTarget)
      local okf, fr = pcall(funcLuaMenuCommand, 552280324, L, k, false, R.FACE, R.FACE_SLOT, 0, 0, e.chara)
      pcall(SetEnableForceCharaInvalidUseTarget)
      face = okf and fr ~= false
    end
    if not face then
      pcall(funcLuaMenuCommand, 558735651, L, UTIL_CP.ICON_TEX, UTIL_CP.UNKNOWN_SPR, R.FACE_SLOT, 0, k)
    end
    funcLuaMenuCommand(3405944500, L, R.FACE, true, k)
    local elem = false
    if e.chara ~= nil and e.chara ~= 0 and type(e.element) == "number" then
      local own = UTIL_CP.ELEM_SPR[e.element]
      if own ~= nil then
        pcall(funcLuaMenuCommand, 558735651, L, UTIL_CP.ICON_TEX, own, R.ELEM_SLOT, 0, k)
        elem = true
      else
        local okg, spr = pcall(GetElementIcon, e.element)
        if okg and spr ~= nil and spr ~= 0 then
          pcall(funcLuaMenuCommand, 558735651, L, UTIL_CP.ICON_TEX_LG, spr, R.ELEM_SLOT, 0, k)
          elem = true
        end
      end
    end
    funcLuaMenuCommand(3405944500, L, R.ELEM, elem, k)
    local ps = e.pos ~= nil and UTIL_CP.POS_SPR[e.pos] or nil
    if ps ~= nil then
      pcall(funcLuaMenuCommand, 558735651, L, UTIL_CP.POS_TEX, ps, R.POS_SLOT, 0, k)
    end
    funcLuaMenuCommand(3405944500, L, R.POS, ps ~= nil, k)
  end

  function UTIL_CP.ListShow(screen, show, list, first, sel, cur, title)
    if screen.backdrop then
      funcLuaMenuCommand(711242136, UTIL_CP.BG, 0, show)
      if show then
        pcall(funcLuaMenuCommand, 558735651, UTIL_CP.BG, 2311471971, 515167937, 3512665951, 0, 0)
      end
    end
    UTIL_CP.OpenLayer(UTIL_CP.LIST)
    funcLuaMenuCommand(711242136, UTIL_CP.LIST, 0, show)
    if show then
      pcall(funcLuaMenuCommand, 2333948100, UTIL_CP.LIST, 0, UTIL_CP.TITLE, UTIL_CP.TITLE_STYLE)
      pcall(funcLuaMenuCommand, 1083631230, UTIL_CP.LIST, UTIL_CP.TITLE, title or "", 0)
    end
    pcall(funcLuaMenuCommand, 3405944500, UTIL_CP.LIST, UTIL_CP.TITLE, show, 0)
    for k = 0, UTIL_CP.VIEW - 1 do
      local e = show and list[first + k + 1] or nil
      UTIL_CP.OpenLayer(UTIL_CP.ITEM, k)
      if e ~= nil then
        pcall(UTIL_CP.Row, k, e, first + k == sel, e.hdl == cur)
      end
      funcLuaMenuCommand(711242136, UTIL_CP.ITEM, k, e ~= nil)
    end
  end

  -- the screen's return-arrow guide is hidden while the picker's guide carries its own «Atrás» entry (one Esc prompt)
  function UTIL_CP.ReturnGuide(show)
    local L = UTIL_CP.RETURN_GUIDE
    if show then
      if UTIL_CP.return_hidden then
        UTIL_CP.return_hidden = false
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, 0, true)
      end
      return
    end
    if UTIL_CP.return_hidden then
      return
    end
    local oke, exists = pcall(funcLuaMenuCommand, 262659071 --[[CMND_IS_EXIST_LAYER]], L)
    if not (oke and exists == true) then
      return
    end
    local okv, visible = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], L, 0)
    if okv and visible == true then
      UTIL_CP.return_hidden = true
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, 0, false)
    end
  end

  function UTIL_CP.Help(screen, id)
    if screen.Help ~= nil then
      pcall(screen.Help, UTIL_CP.Text(id))
    end
  end

  function UTIL_CP.Guide(screen, entries)
    local t, g, o, c = {}, {}, {}, {}
    for k, e in ipairs(entries) do
      t[k], g[k], c[k] = e[1], e[2], e[3]
      o[k] = k == 1 and 0 or 18
      if e[3] == UTIL_CP.K_BACK then
        UTIL_CP.ReturnGuide(false)
      end
    end
    local menu = screen.GuideMenu()
    local f = screen.GuideCall or funcLuaMenuCommand
    pcall(f, UTIL_CP.GUIDE_TEXTS, menu, UTIL_CP.GUIDE, t, g, o)
    pcall(f, UTIL_CP.GUIDE_KEYS, menu, UTIL_CP.GUIDE, c)
  end

  -- ---- candidates ------------------------------------------------------------------------------------------------
  function UTIL_CP.CharaName(chara)
    local ok, a, b = pcall(funcLuaCommand, 4060384944 --[[CMND_GET_CHARA_INFO]], chara, 10)
    if ok and type(b) == "string" then
      return b
    elseif ok and type(a) == "string" then
      return a
    end
    return string.format("%08X", UTIL_CP.U32(chara))
  end

  -- 2026-10-12 (Nacho): a coach or a manager is never a partner. Staff = the card's role badge (the game's own test,
  -- retail CheckEnableSetDirector / CheckEnableSetManager: ability abl_000002 coach, abl_000003 manager); the save
  -- and the match refuse them too (scripts/combo_partners.lua).
  UTIL_CP.HAS_ABILITY = 2361903722 --[[(hdl, ability) -> ok, bool]]
  UTIL_CP.STAFF_ABL = {@crc:abl_000002@, @crc:abl_000003@}

  function UTIL_CP.IsStaff(h)
    for _, abl in ipairs(UTIL_CP.STAFF_ABL) do
      local ok, got, v = pcall(funcLuaCommand, UTIL_CP.HAS_ABILITY, h, abl)
      if ok and got ~= false and v == true then
        return true
      end
    end
    return false
  end

  function UTIL_CP.Entry(h)
    local okc, chara = pcall(funcLuaCommand, 1131797651, h, 1)
    chara = okc and UTIL_CP.U32(chara) or 0
    local okp, param = pcall(funcLuaCommand, 1131797651, h, 4)
    local oki, _, nat = pcall(funcLuaCommand, 4060384944, okp and param or 0, 11)
    local oke, element = pcall(funcLuaCommand, 1131797651, h, 8)
    return {hdl = h, chara = chara, name = UTIL_CP.CharaName(chara), element = oke and element or 0,
      pos = oki and UTIL_CP.NAT_ICON[nat] or nil}
  end

  -- the screen's squad (screen.Members), field order: starters by line (POR, DF, MC, DC) and left to right, then the
  -- others by natural position; without the player and the staff (the move's named partners included); row 1 = random
  function UTIL_CP.Candidates(screen, info)
    local members = screen.Members()
    if members == nil then
      return nil
    end
    local out, seen = {}, {}
    local formation = members.formation
    for _, m in ipairs(members) do
      local h = UTIL_CP.U32(m.hdl)
      if h ~= 0 and h ~= screen.player and not seen[h] and #out < UTIL_CP.MAX_TEAM and not UTIL_CP.IsStaff(h) then
        seen[h] = true
        local e = UTIL_CP.Entry(h)
        e.idx, e.field, e.x = m.index or #out, false, 0
        local slot = m.slot
        if type(slot) == "number" and slot >= 0 and slot <= 10 and type(formation) == "number" then
          local okf, gf, icon = pcall(funcLuaCommand, UTIL_CP.FORMATION_INFO, 5, formation, slot)
          if okf and gf and type(icon) == "number" and icon >= 0 and icon <= 3 then
            local okq, gq, x = pcall(funcLuaCommand, UTIL_CP.FORMATION_INFO, 4, formation, slot, 2)
            e.pos, e.field = icon, true
            e.x = (okq and gq and type(x) == "number") and x or slot
          end
        end
        out[#out + 1] = e
      end
    end
    table.sort(out, function(a, b)
      if a.field ~= b.field then
        return a.field
      end
      local pa, pb = a.pos or 9, b.pos or 9
      if pa ~= pb then
        return pa < pb
      end
      if a.field and a.x ~= b.x then
        return a.x < b.x
      end
      return a.idx < b.idx
    end)
    table.insert(out, 1, {hdl = 0, chara = 0, name = UTIL_CP.Text(UTIL_CP.TX_RANDOM)})
    return out
  end

  function UTIL_CP.Get(h, skill)
    local r = {pcall(funcLuaCommand, UTIL_CP.CMD_GET, h, skill)}
    local out = {}
    if r[1] and r[2] == true then
      for k = 3, 5 do
        out[#out + 1] = type(r[k]) == "number" and UTIL_CP.U32(r[k]) or 0
      end
    end
    return out
  end

  function UTIL_CP.MoveName(skill)
    local ok, got, nameId = pcall(funcLuaCommand, 2580586398, skill, 4)
    if ok and got and nameId then
      local okn, s = pcall(funcLuaCommand, 720417636, nameId)
      if okn and type(s) == "string" and s ~= "" then
        return s
      end
    end
    return string.format("%08X", skill)
  end

  -- ---- confirm popup: the retail card window with the performers' cards (util_cp_gw.lua in general_window) --------
  function UTIL_CP.GwClear()
    local G = UTIL_CP.GW
    pcall(funcLuaCommand, 3363400568, G.N)
    for i = 1, 4 do
      pcall(funcLuaCommand, 3363400568, G.H[i])
      pcall(funcLuaCommand, 3363400568, G.I[i])
    end
  end

  -- the squad handle of slot k's named partner (the engine's own pick for that slot), 0 = none or not in the squad
  function UTIL_CP.NamedDefault(list, info, k)
    local c = info.named[k]
    if c ~= nil then
      for _, e in ipairs(list) do
        if e.hdl ~= 0 and e.chara == c then
          return e.hdl
        end
      end
    end
    return 0
  end

  -- the performers in cast order: the player, then one entry per partner slot (the pick, else the slot's named partner,
  -- else «?»)
  function UTIL_CP.Performers(player, list, picks, info)
    local function entry(h)
      for _, e in ipairs(list) do
        if h ~= 0 and e.hdl == h then
          return e
        end
      end
      if h ~= 0 then
        return UTIL_CP.Entry(h)
      end
      return {hdl = 0}
    end
    local out = {entry(player)}
    for k = 1, info.slots do
      local h = picks[k] or 0
      if h == 0 then
        h = UTIL_CP.NamedDefault(list, info, k)
      end
      out[#out + 1] = entry(h)
    end
    return out
  end

  function UTIL_CP.Confirm(screen, player, list, picks, info, mname)
    local s = UTIL_CP.Text(UTIL_CP.TX_ASK, mname)
    local perf = UTIL_CP.Performers(player, list, picks, info)
    local G = UTIL_CP.GW
    UTIL_CP.GwClear()
    local m = math.min(#perf, 4)
    local names = {}
    for i = 1, m do
      local e = perf[i]
      local el = (e.chara ~= nil and e.chara ~= 0 and type(e.element) == "number" and UTIL_CP.ELEM_SPR[e.element] ~= nil) and e.element or 0
      local ps = (type(e.pos) == "number" and e.pos >= 0 and e.pos <= 3) and e.pos + 1 or 0
      funcLuaCommand(3860611758, G.H[i], 0, e.hdl or 0, 1)
      funcLuaCommand(3860611758, G.I[i], 0, el * 10 + ps, 1)
      names[#names + 1] = string.format("%08X", UTIL_CP.U32(e.hdl or 0))
    end
    funcLuaCommand(3860611758, G.N, 0, m, 1)
    UTIL_CP.Log("confirm", m, "cards", table.concat(names, " "))
    UTIL_CP.Help(screen, UTIL_CP.TX_HELP_CONFIRM)
    UTIL_CP.Guide(screen, {{UTIL_CP.TX_ACCEPT, UTIL_CP.GL_ENTER, UTIL_CP.K_ENTER}, {UTIL_CP.TX_BACK, UTIL_CP.GL_BACK, UTIL_CP.K_BACK}})
    -- the player's card is the window's own card (hidden by util_cp_gw.lua, which measures the window from it)
    funcLuaCommand(2289627655, s, G.WINDOW, 0, UTIL_CP.U32(perf[1].hdl or 0), 0, 0, false)
    funcLuaCommand(2351835063, 2, 0)
    coroutine.yield()
    local r = -1
    while r == nil or r < 0 do
      r = funcLuaCommand(1523741473)
      coroutine.yield()
    end
    while not funcLuaCommand(682363669) do
      coroutine.yield()
    end
    local okh, left = pcall(funcLuaCommand, 2947612279, G.N)
    if okh and left == true then
      UTIL_CP.Log("confirm: general_window did not take the cards (Utilities' util_cp_gw hook missing)")
    end
    UTIL_CP.GwClear()
    return r == 0
  end

  -- ---- the picker -------------------------------------------------------------------------------------------------
  -- one page: the pick for partner slot `slot`; returns the list index (0-based) or nil (back)
  function UTIL_CP.Page(screen, list, picks, slot, info)
    for _, e in ipairs(list) do
      e.taken = false
      if e.hdl ~= 0 then
        for k = 1, info.slots do
          if k ~= slot and picks[k] == e.hdl then
            e.taken = true
          end
        end
      end
    end
    local cur = picks[slot] or 0
    local sel = 0
    for i, e in ipairs(list) do
      if e.hdl == cur then
        sel = i - 1
      end
    end
    local first = math.max(0, math.min(sel, #list - UTIL_CP.VIEW))
    local title = string.format("%s %d / %d", UTIL_CP.Text(UTIL_CP.TX_SLOT), slot, info.slots)
    UTIL_CP.ListShow(screen, true, list, first, sel, cur, title)
    UTIL_CP.Help(screen, UTIL_CP.TX_HELP_PICK)
    UTIL_CP.Guide(screen, {{UTIL_CP.TX_ACCEPT, UTIL_CP.GL_ENTER, UTIL_CP.K_ENTER}, {UTIL_CP.TX_BACK, UTIL_CP.GL_BACK, UTIL_CP.K_BACK}})
    coroutine.yield()
    while true do
      coroutine.yield()
      if screen.Frame ~= nil then
        pcall(screen.Frame)
      end
      local moved = false
      if UTIL_CP.Key(UTIL_CP.K_BACK) then
        UTIL_CP.SE(UTIL_CP.SE_BACK)
        return nil
      elseif UTIL_CP.Key(UTIL_CP.K_ENTER) or UTIL_CP.Key(UTIL_CP.K_CLICK) then
        if list[sel + 1].taken then
          UTIL_CP.SE(UTIL_CP.SE_NG)
        else
          UTIL_CP.SE(UTIL_CP.SE_DECIDE)
          return sel
        end
      elseif UTIL_CP.Key(UTIL_CP.K_DOWN) and sel < #list - 1 then
        sel = sel + 1
        if sel >= first + UTIL_CP.VIEW then
          first = first + 1
        end
        moved = true
      elseif UTIL_CP.Key(UTIL_CP.K_UP) and sel > 0 then
        sel = sel - 1
        if sel < first then
          first = first - 1
        end
        moved = true
      end
      if moved then
        UTIL_CP.SE(UTIL_CP.SE_MOVE)
        UTIL_CP.ListShow(screen, true, list, first, sel, cur, title)
      end
    end
  end

  -- the picker for `skill` (info = UTIL_CP.ComboInfo(skill)) on `screen` (see the top of this part); a coroutine body
  function UTIL_CP.Open(screen, skill, info)
    local message = screen.Message or UTIL_CP.Message
    local mname = UTIL_CP.MoveName(skill)
    local player = screen.player
    if player == nil or player == 0 then
      UTIL_CP.SE(UTIL_CP.SE_NG)
      UTIL_CP.Log("open refused: no player known", string.format("skill %08X", skill))
      return
    end
    if info.slots <= 0 then
      UTIL_CP.SE(UTIL_CP.SE_NG)
      return
    end
    local list = UTIL_CP.Candidates(screen, info)
    if list == nil then
      -- opened without a squad (story field, a scout): no one to choose from
      UTIL_CP.SE(UTIL_CP.SE_NG)
      message(UTIL_CP.Text(UTIL_CP.TX_NOTEAM))
      return
    end
    UTIL_CP.SE(UTIL_CP.SE_DECIDE)
    screen.Begin()
    UTIL_CP.picking = true
    local done, err = pcall(function()
      local saved = UTIL_CP.Get(player, skill)
      local picks = {}
      for k = 1, info.slots do
        -- no saved pick on a named slot: its named partner is pre-selected (the engine's own pick)
        picks[k] = saved[k] or 0
        if picks[k] == 0 then
          picks[k] = UTIL_CP.NamedDefault(list, info, k)
        end
      end
      local initial = {}
      for k = 1, info.slots do
        initial[k] = picks[k]
      end
      UTIL_CP.Log("open", string.format("player %08X skill %08X performers %d slots %d named %d team %d", player, skill,
        info.performers, info.slots, #info.named, #list - 1))
      local slot = 1
      while slot >= 1 and slot <= info.slots do
        local i = UTIL_CP.Page(screen, list, picks, slot, info)
        if i == nil then
          slot = slot - 1
        else
          picks[slot] = list[i + 1].hdl
          slot = slot + 1
        end
      end
      pcall(UTIL_CP.ListShow, screen, false, {}, 0, 0, 0)
      if slot > info.slots then
        local same = true
        for k = 1, info.slots do
          if (picks[k] or 0) ~= (initial[k] or 0) then
            same = false
          end
        end
        if same then
          UTIL_CP.Log("unchanged", string.format("skill %08X", skill))
        elseif UTIL_CP.Confirm(screen, player, list, picks, info, mname) then
          local ok, r = pcall(funcLuaCommand, UTIL_CP.CMD_SET, player, skill, picks[1] or 0, picks[2] or 0, picks[3] or 0)
          UTIL_CP.SE((ok and r == true) and UTIL_CP.SE_OK or UTIL_CP.SE_NG)
          UTIL_CP.Log("saved", string.format("player %08X skill %08X -> %08X %08X %08X (%s)", player, skill,
            picks[1] or 0, picks[2] or 0, picks[3] or 0, tostring(r)))
        else
          UTIL_CP.Log("cancelled at confirm", string.format("skill %08X", skill))
        end
      else
        UTIL_CP.Log("cancelled", string.format("skill %08X", skill))
      end
    end)
    UTIL_CP.picking = false
    pcall(UTIL_CP.ListShow, screen, false, {}, 0, 0, 0)
    pcall(UTIL_CP.ReturnGuide, true)
    screen.Finish()
    if not done then
      UTIL_CP.Log("picker error", tostring(err))
    end
  end
  -- ===== end of the shared partner picker =====
