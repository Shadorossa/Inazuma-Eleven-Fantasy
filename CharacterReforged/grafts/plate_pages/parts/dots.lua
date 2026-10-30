-- Player page block (plate_pages.lua): the page dots, the view mode and the header tag
  -- ---- 8 dots ---------------------------------------------------------------------------------------------------
  -- G.SlotPages() = {[dot slot] = page index} of the shown pages and G.Slot(type) = the slot of a page type, from the
  -- VR-Framework's player page registry (VRFW_PlayerPages, docs/framework/player-pages.md): slot = the page's place in
  -- the resolved order. A page that is not shown (its Enabled says no: the Hiper page while the option «Tabla de habilidades» is not on the new set) keeps its slot
  -- with the dot hidden and no click; a page that does not exist (Utilities' TRAYECTORIA without Utilities) has no
  -- slot. Slots past the layout's G.DOTS_MAX get no dot.
  function G.SlotPages()
    local P = VRFW_PlayerPages
    return P ~= nil and P.Slots() or {}
  end
  function G.Slot(ptype)
    local P = VRFW_PlayerPages
    return P ~= nil and P.SlotOfType(ptype) or nil
  end
  function G.Dots()
    if not On() or G.ptype == nil or not Exists(G.STATUS) then
      return
    end
    local lit = G.Slot(G.ptype)
    local pages = G.SlotPages()
    for i = 1, 6 do
      local on = pages[i] ~= nil
      Cmd(C.MESH, G.STATUS, G.DOT_OFF[i], on, 0)
      Cmd(C.MESH, G.STATUS, G.DOT_ON[i], on and lit == i, 0)
    end
    -- the row centred on the slots this page has: the layout spaces G.DOTS_MAX slots between the Q / E glyphs; with
    -- fewer (a screen that leaves pages out) the dots move right and both glyphs close in by half the unused width
    local used = 1
    for s in pairs(pages) do
      if type(s) == "number" and s > used then
        used = s
      end
    end
    local shift = (G.DOTS_MAX - math.min(used, G.DOTS_MAX)) * G.DOT_PITCH / 2
    local up = Cmd(C.IS_VIS, G.STATUS, 0) == true
    if not up then
      G.dotShift = nil                     -- a status base shown again starts from its layout
    elseif G.dotShift ~= shift then
      G.dotShift = shift
      for i = 1, 6 do
        local x = G.DOT_X[1] - (7 - i) * G.DOT_PITCH - 1358 + shift
        Cmd(C.NODE_POS, G.STATUS, 0, G.DOT_OFF[i], 0, x)
        Cmd(C.NODE_POS, G.STATUS, 0, G.DOT_ON[i], 0, x)
      end
      Cmd(C.NODE_POS, G.STATUS, 0, G.KEY_NODES[1], 0, G.KEY_X[1] + shift)
      Cmd(C.NODE_POS, G.STATUS, 0, G.KEY_NODES[2], 0, G.KEY_X[2] - shift)
      for k = 0, 1 do
        if Exists(G.DOTS) and G.ready[G.DOTS * 16 + k] and Cmd(C.IS_OPEN, G.DOTS, k) == true then
          Cmd(C.POS, G.DOTS, G.DOT_X[k + 1] + shift - 1362 - 1358, 540 + 34, 0, k)
        end
      end
    end
    if not Exists(G.DOTS) then
      return
    end
    local psub = up and G.ptype == 2 and not G.InOffice()
    for k = 2, 5 do
      if not psub then
        if Cmd(C.IS_OPEN, G.DOTS, k) == true then
          Cmd(C.VIS, G.DOTS, k, false)
        end
      elseif Ready(G.DOTS, k) then
        if not G.ready[G.DOTS * 16 + k] then
          G.ready[G.DOTS * 16 + k] = true
          Cmd(C.TRACE, G.STATUS, 0, G.DOT_TRACE[k], true)
          for _, n in ipairs(G.DOTS_LOCS) do
            Cmd(C.NODE_VIS, G.DOTS, n, false, k)
          end
          for _, m in ipairs(G.DOTS_HIDE) do
            Cmd(C.MESH, G.DOTS, m, false, k)
          end
          Cmd(C.TEXT_VIS, G.DOTS, 355816102, false, k)   -- _text_btn_l01
          local x = k == 5 and G.PSUB_KEY_X or G.PSUB_DOT_X[k]
          Cmd(C.POS, G.DOTS, x - 1362 - 1358, 540 + 34, 0, k)
          Cmd(C.TEXT_VIS, G.DOTS, G.N_BTN_R, false, k)   -- round 14b: the glyph is G.Hint's text node now
        end
        local dot = k ~= 5 and k - 2 < G.PSUB_N
        Cmd(C.MESH, G.DOTS, G.M_DOT_OFF1, dot, k)
        Cmd(C.MESH, G.DOTS, G.M_DOT_ON1, dot and (G.psub or 0) == k - 2, k)
        Cmd(C.VIS, G.DOTS, k, dot)
      end
    end
    for k = 0, 1 do
      if not up then
        if Cmd(C.IS_OPEN, G.DOTS, k) == true then
          Cmd(C.VIS, G.DOTS, k, false)
        end
      elseif Ready(G.DOTS, k) then
        if not G.ready[G.DOTS * 16 + k] then
          G.ready[G.DOTS * 16 + k] = true
          Cmd(C.TRACE, G.STATUS, 0, G.DOT_TRACE[k], true)
          for _, n in ipairs(G.DOTS_LOCS) do
            Cmd(C.NODE_VIS, G.DOTS, n, false, k)
          end
          for _, m in ipairs(G.DOTS_HIDE) do
            Cmd(C.MESH, G.DOTS, m, false, k)
          end
          Cmd(C.TEXT_VIS, G.DOTS, 355816102, false, k)   -- _text_btn_l01
          Cmd(C.TEXT_VIS, G.DOTS, 59628764, false, k)    -- _text_btn_r01
          -- copy's _page01_off at copy-local (1362, -949) from the status base root: onto slot 7 / 8 (y -949)
          Cmd(C.POS, G.DOTS, G.DOT_X[k + 1] + shift - 1362 - 1358, 540 + 34, 0, k)   -- round 12: y 915 (10 px up)
        end
        Cmd(C.MESH, G.DOTS, G.M_DOT_OFF1, true, k)
        Cmd(C.MESH, G.DOTS, G.M_DOT_ON1, lit == k + 7, k)
        Cmd(C.VIS, G.DOTS, k, pages[k + 7] ~= nil)
      end
    end
  end

  -- 2026-10-06 (Nacho: the office's «Ficha» showed only the header over the shop): the office opens THIS screen
  -- for a candidate in universe mode (a temp chara from the row's param / level / rarity, office_look
  -- EVT_OGridPlateOpen), and hides its own layers while it is up: that page is the full player page (pages,
  -- description, model, band). Only another plate over the shop (not universe mode) keeps the shop's look.
  function G.ViewMode()
    local ok, v = pcall(IsUniverseCharaMode)
    return ok and v == true
  end
  function G.InOffice()
    if type(funcLuaCommand) ~= "function" or G.ViewMode() then
      return false
    end
    local ok, v = pcall(funcLuaCommand, @crc:CMND_IS_EXIST_MENU@, G.SHOP_MENU)   -- CMND_IS_EXIST_MENU
    return ok and v == true
  end

  -- the archetype icon's slanted box
  function G.Tag()
    if not Exists(G.TAG) or not Exists(G.PAGE) or type(VRFW_UI) ~= "table" then
      return
    end
    local up = Cmd(C.IS_VIS, G.PAGE, 0) == true and Cmd(C.IS_OPEN, G.PAGE, 0) == true
    if not up then
      if Cmd(C.IS_OPEN, G.TAG, 0) == true then
        Cmd(C.VIS, G.TAG, 0, false)
      end
      return
    end
    if not Ready(G.TAG, 0) then
      return
    end
    if not G.ready[G.TAG * 16] then
      G.ready[G.TAG * 16] = true
      G.tagSt = {}
      Cmd(C.TRACE, G.PAGE, 0, G.TAG, true)
      VRFW_UI.HeaderRow.ArchBoxSetup(G.TAG, {sprite = G.SP_SLANTBOX, atlas = G.TX_OWN})
    end
    -- 2026-10-12 / 13 (owner): the slanted box is the archetype glyph's backdrop: shown exactly while the header's
    -- glyph is shown at home (the shared header row's rule, VRFW_UI.HeaderRow.ArchBoxShown: the glyph visibility the
    -- fills last set, whoever drew it; a staff role glyph moved into the position slot leaves no box). Round 10: a dual
    -- archetype (passive_config draws the second glyph on _icon_lock_status01) gets the wide box.
    VRFW_UI.HeaderRow.ArchBox(G.TAG, G.PLATE, 0, G.hdl, G.tagSt or {}, {sprite = G.SP_SLANTBOX, atlas = G.TX_OWN,
      sprite_dual = G.SP_SLANTBOX2, dual_cmd = type(UTIL_PCI) == "table" and UTIL_PCI.CMD_INFO or nil})
  end
