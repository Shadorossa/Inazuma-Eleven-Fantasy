-- Player page block (plate_pages.lua): the Pasivas page, its sub-pages and the custom-passive panel
  -- ---- Pasivas (round 9): a row of 5 icon tiles (layout: icons at x 1172..1732, y 880); each strip collapsed to its
  -- icon on its own plate (orange special / blue, passive_config's tint) squashed into a slanted tile; R3 = cursor
  -- mode (left / right, R3 or B leaves): the focused passive opens as its whole strip ABOVE the row (y 770)
  G.PR = 811691761                       -- soccer11_20_formation_team_passive
  G.PR_PLATE, G.PR_OL = 3143733656, {2061463723, 3822461201}   -- _passive_base01, _ol01 / _ol02
  G.PR_TEXT = 1868134834                 -- _text_passive01
  G.PR_NODES = {3453619769, 2497436533}            -- _pos_type01, _pos_position01 (round 10: _pos_build01 never:
  -- its two retail build icons are the white boxes)
  G.PR_BUILD, G.PR_ICONBASE = 3448691050, 3877027080                -- _pos_build01, _teambuff_base01
  G.PT = @crc:evt_pp_ptile@
  G.PT_TRACE = {[0] = @crc:evt_pp_ptile0@, @crc:evt_pp_ptile1@, @crc:evt_pp_ptile2@, @crc:evt_pp_ptile3@, @crc:evt_pp_ptile4@}
  G.PT_SPRITE = {[0] = @crc:evt_pp_tile_orange@, @crc:evt_pp_tile_grey@, @crc:evt_pp_tile_grey@, @crc:evt_pp_tile_blue@,
    @crc:evt_pp_tile_blue@}                  -- special orange, general grey, archetype blue
  G.PT_W, G.PT_H = 90, 54               -- round 12: small tiles (if_plate_row_build.py TILE_TOP 48 + slant 42, 54 high)
  G.PT_SPRITE_HL = {[0] = @crc:evt_pp_tile_orange_hl@, @crc:evt_pp_tile_grey_hl@, @crc:evt_pp_tile_grey_hl@,
    @crc:evt_pp_tile_blue_hl@, @crc:evt_pp_tile_blue_hl@}    -- the focused passive's tile (white rim)
  G.ptHl = {}
  G.PR_EF = @crc:_build_ef01@                 -- _build_ef01 (a build effect quad over the icon)
  G.PR_INHERIT = 27565530
  G.PR_TILE = {-371, 40, 96, 80}         -- collapsed plate node (x, y top, w, h; layer units, icon centre -323, 0)
  G.PR_FULL = {-414, 46, 828, 92}
  G.PR_TEXT_BOX = {622, 72}              -- the text node's retail box (width, height; left edge -243)
  G.PR_TAB_Y = 770
  G.pcur = G.pcur or nil                 -- focused passive (cursor mode) or nil
  G.pexit = 0
  G.PARENTS = {935586083, 2049316981, 937147172}   -- team_dock_formation_menu, soccer_formation_menu, soccer_team_dock
  function G.ParentCursor(on)
    for _, m in ipairs(G.PARENTS) do
      pcall(funcLuaCommand, 830228314, m, "EVT_PPG_SetCursor", on)
    end
  end

  -- the slanted tile behind passive i's icon (screen: centred on the icon at (1172 + 140 i, 880))
  function G.Tile(i, on, hl)
    if not Exists(G.PT) then
      return
    end
    if not on then
      if Cmd(C.IS_OPEN, G.PT, i) == true then
        Cmd(C.VIS, G.PT, i, false)
      end
      return
    end
    if not Ready(G.PT, i) then
      return
    end
    if not G.ready[G.PT * 16 + i] then
      G.ready[G.PT * 16 + i] = true
      Cmd(C.TRACE, G.PAGE, 0, G.PT_TRACE[i], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, G.PT, m, false, i)
      end
      G.ptHl[i] = false
      Cmd(C.SPRITE, G.PT, G.TX_OWN, G.PT_SPRITE[i], G.SP_FRAME, 0, i)
      local sx, sy = G.PT_W / 476, G.PT_H / 44
      local x, y = 1172 + 140 * i - G.PT_W / 2, 880 - G.PT_H / 2
      Cmd(C.SCALE, G.PT, sx, sy, 1, i)
      Cmd(C.POS, G.PT, x - 94 * sx, -y + 816 * sy, 0, i)
    end
    if G.ptHl[i] ~= (hl == true) then
      G.ptHl[i] = hl == true
      Cmd(C.SPRITE, G.PT, G.TX_OWN, hl and G.PT_SPRITE_HL[i] or G.PT_SPRITE[i], G.SP_FRAME, 0, i)
    end
    Cmd(C.VIS, G.PT, i, true)
  end

  -- ---- Pasivas in 2 sub-pages, R3 (CMD_FUNC6) = next sub-page (1 -> 2 -> 1):
  --   1 = the first three passives (slots 0, 1, 2), 2 = the two archetype ones (slots 3, 4).
  -- Each sub-page shows its passives as WHOLE strips (icon, name, description = the detail) centred in the card, one
  -- under the other; the other strips hidden. Three strips are drawn smaller (G.PSUB_SCALE, around each strip's
  -- centre) so they fit the card. Kept: the passive's own icon always, no white boxes (_pos_type01 /
  -- _pos_position01 / _pos_build01 / _build_ef01 hidden).
  G.PSUB = {[0] = {0, 1, 2}, {3, 4}}
  G.PSUB_N = 2                                       -- sub-page count (dots, R3 / click cycle)
  G.PSUB_Y = {[1] = {815}, [2] = {770, 862}, [3] = {742, 808, 874}}   -- strip centre rows (screen y) per strip count
  G.PSUB_SCALE = {[3] = 0.7}                         -- strip scale per strip count (default 1)
  G.PSUB_WIDE = {[3] = 790}                          -- strip screen width per strip count (default: the plate's own
                                                     -- width x scale): three strips are wide so each text fits one line
  G.PSUB_X = 1452                                    -- strip centre (screen x)
  G.PSUB_KEYS = {[0] = @crc:evt_pp_psub_2@, @crc:evt_pp_psub_3@}
  G.SP_TILE_EMPTY = @crc:evt_pp_tile_empty@
  G.EMPTY_BOX = {600, 66}                            -- the empty special's box (screen px)
  G.psub = G.psub or 0
  if G.psub >= G.PSUB_N then
    G.psub = 0
  end
  G.noSpecial = false
  -- round 13 (Nacho): the special passive's title («Limitador activo», CMND_BETTERQOL_PC_SPECIAL's text key) on a pill
  -- (layer evt_pp_ptitle, object evt_ph_peg_pill) centred over the special's strip on sub-page 1, tinted the special
  -- orange; no special (the empty box) = no title. Page frame: local (x, -y) = screen (x, y) (pill centred on origin).
  G.PTITLE = @crc:evt_pp_ptitle@
  -- round 14 (Nacho: a title with a line under it, not a pill): the pill mesh hidden, the text in the special's
  -- dark orange, its box's left edge on the strip's left edge (G.PTITLE_X), a thin orange rule (gauge copy
  -- evt_pp_ptrule) the strip's width under it; the text from menu_text evt_pp_<title key> (per language: the loader's
  -- own text command answered English), the loader's text as the fallback
  G.PTITLE_K, G.PTITLE_DY = 0.8, 66          -- text scale; its centre this far above the strip's centre
  G.PTITLE_X = 1038                          -- the strip's left edge (screen x); the text box (330 x 0.8) starts here
  G.PTITLE_BOX = 330 * 0.8
  G.PTITLE_RGB = {0.80, 0.30, 0.04}
  G.PTRULE, G.SP_PTRULE = @crc:evt_pp_ptrule@, @crc:evt_pp_ptrule@
  G.PTRULE_R = {1038, 772, 1866, 775}        -- the rule's screen rect (3 px, over the strip's top)
  G.CMD_SPECIAL, G.CMD_TEXT = @crc:CMND_BETTERQOL_PC_SPECIAL@, @crc:CMND_VRFW_TEXT_GET@

  -- how far the slot-0 strip's top sits below a lone strip's top on sub-page 1 (title and rule move with it)
  function G.PTitleDy()
    local n = #G.PSUB[0]
    local k = G.PSUB_SCALE[n] or 1
    return (G.PSUB_Y[n][1] - 46 * k) - (G.PSUB_Y[1][1] - 46)
  end

  function G.PTitle(on)
    local T = G.PTITLE
    if not Exists(T) then
      return
    end
    local text = ""
    if on and G.hdl ~= nil then
      local ok, yes, key = pcall(funcLuaCommand, G.CMD_SPECIAL, G.hdl)
      if ok and yes == true and type(key) == "string" and key ~= "" then
        local id = "evt_pp_" .. string.gsub(key, "^inazuma_fantasy%.", "")
        local okm, tm = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@, CALC_CRC(id))
        if okm and type(tm) == "string" and tm ~= "" then
          text = tm
        else
          local okt, t = pcall(funcLuaCommand, G.CMD_TEXT, key)
          text = (okt and type(t) == "string") and t or ""
        end
      end
    end
    if text == "" then
      if Cmd(C.IS_OPEN, T, 0) == true then
        Cmd(C.VIS, T, 0, false)
      end
      if Exists(G.PTRULE) and Cmd(C.IS_OPEN, G.PTRULE, 0) == true then
        Cmd(C.VIS, G.PTRULE, 0, false)
      end
      G.ptitleText = nil
      return
    end
    if Exists(G.PTRULE) and Ready(G.PTRULE, 0) then
      local l = G.PTRULE
      if not G.ready[l * 16] then
        G.ready[l * 16] = true
        Cmd(C.TRACE, G.PAGE, 0, l, true)
        for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
          Cmd(C.MESH, l, m, false, 0)
        end
        Cmd(C.SPRITE, l, G.TX_OWN, G.SP_PTRULE, G.SP_FRAME, 0, 0)
      end
      local r, dy = G.PTRULE_R, G.PTitleDy()
      local sx, sy = (r[3] - r[1]) / 476, (r[4] - r[2]) / 44
      Cmd(C.SCALE, l, sx, sy, 1, 0)
      Cmd(C.POS, l, r[1] - 94 * sx, -(r[2] + dy) + 816 * sy, 0, 0)
      Cmd(C.VIS, l, 0, true)
    end
    if not Ready(T, 0) then
      return
    end
    if not G.ready[T * 16] then
      G.ready[T * 16] = true
      Cmd(C.TRACE, G.PAGE, 0, T, true)
      Cmd(C.SCALE, T, G.PTITLE_K, G.PTITLE_K, 1, 0)
      Cmd(C.MESH, T, 3516146179 --[[_area_base01: the pill]], false, 0)
      pcall(funcLuaMenuCommand, @crc:CMND_SET_PRIM_COLOR@, T, 0, 1899787537 --[[_text_area01]],
        G.PTITLE_RGB[1], G.PTITLE_RGB[2], G.PTITLE_RGB[3])
    end
    Cmd(C.POS, T, G.PTITLE_X + G.PTITLE_BOX / 2, -(G.PSUB_Y[1][1] + G.PTitleDy() - G.PTITLE_DY), 0, 0)
    if G.ptitleText ~= text then
      G.ptitleText = text
      -- round 14g (in game: white on the card): red through the game's own text markup [CR] … [C]
      -- (font_color.cfg.bin colour «R»: the colour of the descriptions' negative values)
      Cmd(C.SET_TEXT, T, 1899787537 --[[_text_area01]], "[CR]" .. text .. "[C]", 0)
      Cmd(2735666188 --[[text visible]], T, 1899787537, true, 0)
    end
    Cmd(C.VIS, T, 0, true)
  end

  -- the empty special passive's box (tile layer instance 0, light orange), centred where its strip would be
  function G.EmptyBox(on)
    if not Exists(G.PT) then
      return
    end
    if not on then
      if G.emptyOn then
        G.emptyOn = false
        if Cmd(C.IS_OPEN, G.PT, 0) == true then
          Cmd(C.VIS, G.PT, 0, false)
        end
      end
      return
    end
    if not Ready(G.PT, 0) then
      return
    end
    if not G.emptyOn then
      G.emptyOn = true
      Cmd(C.TRACE, G.PAGE, 0, G.PT_TRACE[0], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, G.PT, m, false, 0)
      end
      Cmd(C.SPRITE, G.PT, G.TX_OWN, G.SP_TILE_EMPTY, G.SP_FRAME, 0, 0)
      local w, h = G.EMPTY_BOX[1], G.EMPTY_BOX[2]
      local sx, sy = w / 476, h / 44
      local x, y = G.PSUB_X - w / 2, G.PSUB_Y[1][1] - h / 2
      Cmd(C.SCALE, G.PT, sx, sy, 1, 0)
      Cmd(C.POS, G.PT, x - 94 * sx, -y + 816 * sy, 0, 0)
    end
    Cmd(C.VIS, G.PT, 0, true)
  end

  -- the strips' slanted plate (_passive_base01) pre-coloured by kind: the archetype passives (slots 3 / 4) light blue,
  -- every other one the retail white.
  -- CMND_SET_PRIM_COLOR never tints this quad, so the colour is in the pixels: sprite evt_pp_card_blue of the
  -- retail atlas soccer11_20, made at boot from the retail passive_base01 (content/images/menu/00_soccer/soccer11/
  -- evt_passive_plates.toml, no Level-5 pixel ships), swapped into the plate's texture slot (the sprite the retail row
  -- drawer put there) of each open instance every frame the page shows the rows; the retail sprite back when it leaves.
  G.CARD_TEX, G.CARD_SLOT = 4021797290 --[[soccer11_20.g4tx]], 1729678359 --[[passive_base01]]
  G.CARD_SPR = {[3] = @crc:evt_pp_card_blue@, [4] = @crc:evt_pp_card_blue@}
  G.cardOn = G.cardOn or {}
  function G.CardTint(L, i, on)
    local spr = on and G.CARD_SPR[i] or nil
    if spr ~= nil then
      G.cardOn[i] = true
      pcall(funcLuaMenuCommand, C.SPRITE, L, G.CARD_TEX, spr, G.CARD_SLOT, 0, i)
    elseif G.cardOn[i] then
      G.cardOn[i] = nil
      pcall(funcLuaMenuCommand, C.SPRITE, L, G.CARD_TEX, G.CARD_SLOT, G.CARD_SLOT, 0, i)
    end
  end

  -- no player focused (empty slot, G.Empty): the 5 passive rows, the special's title and rule hidden with the rest of
  -- the page; the layout and the sub-page are kept, so the rows come back on the same sub-page when a player is focused
  function G.PassiveRowsHide()
    local L = G.PR
    if Exists(L) then
      for i = 0, 4 do
        if Cmd(C.IS_OPEN, L, i) == true then
          Cmd(C.VIS, L, i, false)
        end
      end
    end
    G.EmptyBox(false)
    pcall(G.PTitle, false)
  end

  function G.PassiveRows()
    local L = G.PR
    if not Exists(L) then
      return
    end
    if G.emptyHidden then
      return                               -- no player focused: hidden by G.Empty until one is
    end
    local mine = On() and G.ptype == 2 and not G.InOffice()
    if not mine then
      if G.pcur ~= nil then
        G.pcur = nil
        G.ParentCursor(false)
      end
      G.EmptyBox(false)
      pcall(G.PTitle, false)
      if G.prOn then
        G.prOn = false
        for i = 0, 4 do
          if Cmd(C.IS_OPEN, L, i) == true then
            G.CardTint(L, i, false)
            local f = G.PR_FULL
            Cmd(C.NODE_POS, L, i, G.PR_PLATE, 0, f[1])
            Cmd(C.NODE_POS, L, i, G.PR_PLATE, 1, f[2])
            Cmd(C.NODE_SCALE, L, i, G.PR_PLATE, f[3], f[4])
            Cmd(C.NODE_SCALE, L, i, G.PR_TEXT, G.PR_TEXT_BOX[1], G.PR_TEXT_BOX[2])
            Cmd(C.MESH, L, G.PR_PLATE, true, i)
            Cmd(C.SCALE, L, 1, 1, 1, i)
            Cmd(C.POS, L, 0, 0, 0, i)
            Cmd(C.NODE_VIS, L, G.PR_TEXT, true, i)
            Cmd(C.TEXT_VIS, L, G.PR_TEXT, true, i)
            for _, n in ipairs(G.PR_NODES) do
              Cmd(C.NODE_VIS, L, n, true, i)
            end
          end
        end
      end
      return
    end
    G.prOn = true
    -- 2026-10-12 (owner, Utilities' passive configurator on this page: no blue frame on the selected passive, and the
    -- selected one could be on a hidden sub-page): while its session runs (UTIL_PPC.co, the focused row UTIL_PPC.slot)
    -- the sub-page is the one holding the focused row (the session's up / down walk all 5 rows; the sub-page follows,
    -- R3 does not change it), and the row's focus frame (_passive_base01_ol01, drawn by UTIL_PPC.Mark) is never hidden
    -- here: it is shown on that row every frame. Outside a session nothing changes.
    local sess = nil
    if type(UTIL_PPC) == "table" and UTIL_PPC.co ~= nil and type(UTIL_PPC.slot) == "number" and UTIL_PPC.slot >= 0 then
      sess = UTIL_PPC.slot
      local want = sess <= 2 and 0 or 1
      if G.psub ~= want then
        G.psub = want
      end
    end
    local shown = {}
    for _, i in ipairs(G.PSUB[G.psub]) do
      shown[#shown + 1] = i
    end
    local rows = G.PSUB_Y[math.max(1, #shown)]
    local scale = G.PSUB_SCALE[#shown] or 1
    local row = {}
    for n, i in ipairs(shown) do
      row[i] = rows[n]
    end
    for i = 0, 4 do
      if Cmd(C.IS_OPEN, L, i) == true then
        G.CardTint(L, i, true)
        local y = row[i]
        if y == nil then
          Cmd(C.VIS, L, i, false)
          if i == 0 then                   -- round 14: nothing of the special's strip under the empty box (a thin
            Cmd(C.MESH, L, G.PR_PLATE, false, i)   -- grey line showed at its bottom-left)
            Cmd(C.MESH, L, G.PR_ICONBASE, false, i)
            Cmd(C.MESH, L, G.PR_INHERIT, false, i)
            for _, m in ipairs(G.PR_OL) do
              Cmd(C.MESH, L, m, false, i)
            end
          end
        else
          local f = G.PR_FULL
          Cmd(C.NODE_POS, L, i, G.PR_PLATE, 0, f[1])
          Cmd(C.NODE_POS, L, i, G.PR_PLATE, 1, f[2])
          local wide = G.PSUB_WIDE[#shown]                -- widened strip: the plate and the text box grow to the
          local plateW = wide and wide / scale or f[3]    -- right of the icon (layout units), the layer shifts to re-centre
          Cmd(C.NODE_SCALE, L, i, G.PR_PLATE, plateW, f[4])
          Cmd(C.NODE_SCALE, L, i, G.PR_TEXT, G.PR_TEXT_BOX[1] + plateW - f[3], G.PR_TEXT_BOX[2])
          Cmd(C.MESH, L, G.PR_PLATE, true, i)
          Cmd(C.MESH, L, G.PR_ICONBASE, true, i)      -- round 12: the icon always
          Cmd(C.MESH, L, G.PR_EF, false, i)
          Cmd(C.NODE_VIS, L, G.PR_BUILD, false, i)
          for _, m in ipairs(G.PR_OL) do
            Cmd(C.MESH, L, m, i == sess and m == G.PR_OL[1], i)
          end
          Cmd(C.MESH, L, G.PR_INHERIT, false, i)
          Cmd(C.NODE_VIS, L, G.PR_TEXT, true, i)
          Cmd(C.TEXT_VIS, L, G.PR_TEXT, true, i)
          for _, n in ipairs(G.PR_NODES) do
            Cmd(C.NODE_VIS, L, n, false, i)              -- round 12: the white boxes
          end
          local ax = 1172 + 140 * i + 323                -- the strip's attach x (layout PASSIVE_X)
          Cmd(C.SCALE, L, scale, scale, 1, i)            -- around the attach point = the strip's centre
          local shiftX = (plateW - f[3]) / 2 * scale     -- the strip grows to the right: move it back to the centre
          Cmd(C.POS, L, G.PSUB_X - ax - shiftX, 880 - y, 0, i)
          Cmd(C.VIS, L, i, true)
        end
      end
    end
    G.EmptyBox(false)
    if G.noSpecial and Cmd(C.IS_OPEN, L, 0) == true then        -- the unfilled slot: no text on it
      Cmd(C.TEXT_VIS, L, G.PR_TEXT, false, 0)
    end
    pcall(G.PTitle, G.psub == 0 and not G.noSpecial)
    -- R3: the next sub-page
    local key = function(cmd)
      local ok1, a = pcall(funcLuaCommand, @crc:CMND_CHECK_INPUT_CMD@, 1332654303, cmd)
      local ok2, b = pcall(funcLuaCommand, @crc:CMND_CHECK_INPUT_CMD@, 2748927068, cmd)
      return (ok1 and a == true) or (ok2 and b == true)
    end
    G.ptick = (G.ptick or 0) + 1
    if G.ptick - (G.plast or -100) < 6 then
      return
    end
    if sess == nil and key(3147328756) then   -- CMD_FUNC6 (R3); in a session the selection picks the sub-page
      G.psub = (G.psub + 1) % G.PSUB_N
      G.plast = G.ptick
      pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, 2500047763)
    end
  end

  -- ---- the custom-passive page (six-sense panel, type 3) inside the white card --------------------------------
  -- round 12: the panel's own frame / focus / blank meshes hidden. Round 13 (Nacho: title white on white, the bar not
  -- drawn, the retail hexagon art over the card, the 2nd line into the dots): the status base's _sixth_base01 (the
  -- 700 x 464 decoration) hidden; the panel lifted SX_DY so icon + title sit on a slanted blue band and the
  -- description on a light slanted plate, both attached to the page (gauge copies evt_pp_sxbar / evt_pp_sxplate,
  -- page frame: local = (screen x, -screen y)) at the screen rects of if_plate_row_build.py SX_BAND / SX_PLATE
  G.SX = 3764752959                      -- team00_28_six_sense_detail_info
  G.SX_HIDE = {@crc:_sixth_win_base01@, @crc:_sixth_win_focus01@, @crc:_sixth_win_blank01@}
  G.SX_DECO = @crc:_sixth_base01@        -- status base: the six-sense page's decoration
  G.SXBAR, G.SP_SXBAR = @crc:evt_pp_sxbar@, @crc:evt_pp_sxbar@
  G.SXPLATE, G.SP_SXPLATE = @crc:evt_pp_sxplate@, @crc:evt_pp_sxplate@
  G.SX_DY = 70                           -- the panel this much higher (its title 718..782, text 806..876 on screen)
  G.SX_BAND = {1000, 718, 1860, 780}
  G.SX_PLATE = {1030, 790, 1890, 896}
  G.SX_PRIO = 322                        -- the panel over the band (321) and the plate (320)

  local function SxPiece(l, sp, r, prio)
    if not Exists(l) or not Ready(l, 0) then
      return
    end
    if not G.ready[l * 16] then
      G.ready[l * 16] = true
      Cmd(C.TRACE, G.PAGE, 0, l, true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, l, m, false, 0)
      end
      Cmd(C.SPRITE, l, G.TX_OWN, sp, G.SP_FRAME, 0, 0)
      local sx, sy = (r[3] - r[1]) / 476, (r[4] - r[2]) / 44
      Cmd(C.SCALE, l, sx, sy, 1, 0)
      Cmd(C.POS, l, r[1] - 94 * sx, -r[2] + 816 * sy, 0, 0)
      pcall(funcLuaMenuCommand, @crc:CMND_SET_DRAW_PRIORITY@, l, 0, prio, true)
    end
    Cmd(C.VIS, l, 0, true)
  end

  function G.Sixth()
    local mine = On() and G.ptype == 3 and not G.InOffice() and Exists(G.SX) and Cmd(C.IS_OPEN, G.SX, 0) == true
      and Cmd(C.IS_VIS, G.SX, 0) == true
    if not mine then
      if G.sxOn then
        G.sxOn = false
        G.sxLogged = false
        if Exists(G.SX) and Cmd(C.IS_OPEN, G.SX, 0) == true then
          for _, m in ipairs(G.SX_HIDE) do
            Cmd(C.MESH, G.SX, m, true, 0)
          end
          Cmd(C.POS, G.SX, 0, 0, 0, 0)
        end
      end
      for _, l in ipairs({G.SXBAR, G.SXPLATE}) do
        if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
          Cmd(C.VIS, l, 0, false)
        end
      end
      return
    end
    if not G.sxOn then
      G.sxOn = true
      pcall(funcLuaMenuCommand, @crc:CMND_SET_DRAW_PRIORITY@, G.SX, 0, G.SX_PRIO, true)
      pcall(funcLuaCommand, C.LOG, "EVT_PPG sixth panel on")
    end
    for _, m in ipairs(G.SX_HIDE) do
      Cmd(C.MESH, G.SX, m, false, 0)
    end
    Cmd(C.MESH, G.STATUS, G.SX_DECO, false, 0)
    Cmd(C.POS, G.SX, 0, G.SX_DY, 0, 0)
    SxPiece(G.SXPLATE, G.SP_SXPLATE, G.SX_PLATE, G.SX_PRIO - 2)
    SxPiece(G.SXBAR, G.SP_SXBAR, G.SX_BAND, G.SX_PRIO - 1)
    -- 2026-10-06 (shot 357: the page empty): the state of every piece once per visit, «EVT_PPG sixth state»
    if not G.sxLogged then
      G.sxLogged = true
      local function St(l)
        return string.format("%s/%s/%s", tostring(Exists(l)), tostring(Cmd(C.IS_OPEN, l, 0)), tostring(Cmd(C.IS_VIS, l, 0)))
      end
      pcall(funcLuaCommand, C.LOG, "EVT_PPG sixth state", "panel " .. St(G.SX), "bar " .. St(G.SXBAR),
        "plate " .. St(G.SXPLATE), "band " .. St(G.BAND), "page " .. St(G.PAGE))
    end
  end

  -- ---- Pasivas: the special slot's strip (orange, empty) hidden when the player has no special passive ------------
  function G.Passives()
    local L = 811691761                    -- soccer11_20_formation_team_passive
    if not On() or G.ptype ~= 2 or G.hdl == nil or not Exists(L) or Cmd(C.IS_OPEN, L, 0) ~= true then
      return
    end
    local ok, has, pid = pcall(funcLuaCommand, @crc:CMND_GET_CHARA_TEAM_PASSIVE_INFO@, G.hdl, 0, 0, false, false)   -- team passive info (slot 0)
    -- round 14 (Nacho): no special = the retail empty special strip itself (an unfilled slot: its plate, the empty
    -- icon square, no text), shown by PassiveRows like a filled one; no light-orange box
    G.noSpecial = ok and (has ~= true or type(pid) ~= "number" or pid == 0)
  end
