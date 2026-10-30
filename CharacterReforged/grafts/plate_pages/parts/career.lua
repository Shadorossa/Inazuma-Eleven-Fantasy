-- Player page block (plate_pages.lua): the TRAYECTORIA page's rows
  -- ---- Trayectoria (round 13, Nacho): 2 rows, each on a slanted band (gauge copies evt_pp_csband 0 / 1 attached to
  -- the page, the header / archetype box slant):
  --   row 1 = FICHADO | ORIGEN | PARTIDOS          row 2 = V-E-D · % | GOLES | GOLES/PART.
  --   (round 14, Nacho: 3 columns in both rows, goals only: no assists)
  -- Numbers from the career record CMND_BETTERQOL_CAREER_EX(chara, 0) (the mod Utilities') (goals v[9], assists v[10]: already tracked); the
  -- ratio is UTIL_CS.Ratio (decimal comma per language, «-» without matches). The career panel hangs from
  -- _atc_passive01 (screen (1495, 880)); its cell (r, c) default centre = (1204.5 + 195 c, 880 + 84 r): each kept cell
  -- moved (layer local pos, y up) to its centre CS_AT[r][c]; every other cell and the strips hidden.
  -- round 14c (Nacho): the bands 70 px in from each side and 18 px taller (72), the 3 columns centred in them
  G.CS_AT = {[0] = {{1190, 768}, {1450, 768}, {1710, 768}}, [1] = {{1190, 856}, {1450, 856}, {1710, 856}}}
  G.CS_BAND = {[0] = {1060, 732, 1840, 804}, [1] = {1060, 820, 1840, 892}}   -- the bands' screen rects
  G.CSB = @crc:evt_pp_csband@
  G.CSB_TRACE = {[0] = @crc:evt_pp_csband0@, @crc:evt_pp_csband1@}
  G.SP_CSB = @crc:evt_pp_csband@

  local function CsBand(i, on)
    local l = G.CSB
    if not Exists(l) then
      return
    end
    if not on then
      if Cmd(C.IS_OPEN, l, i) == true then
        Cmd(C.VIS, l, i, false)
      end
      return
    end
    if not Ready(l, i) then
      return
    end
    if not G.ready[l * 16 + i] then
      G.ready[l * 16 + i] = true
      Cmd(C.TRACE, G.PAGE, 0, G.CSB_TRACE[i], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, l, m, false, i)
      end
      Cmd(C.SPRITE, l, G.TX_OWN, G.SP_CSB, G.SP_FRAME, 0, i)
      local r = G.CS_BAND[i]
      local sx, sy = (r[3] - r[1]) / 476, (r[4] - r[2]) / 44
      Cmd(C.SCALE, l, sx, sy, 1, i)
      Cmd(C.POS, l, r[1] - 94 * sx, -r[2] + 816 * sy, 0, i)
    end
    Cmd(C.VIS, l, i, true)
  end

  -- Utilities' career page v6 (timeline + card-back table) lays itself out: this plate only gives its geometry (the
  -- status base's _atc_passive01 on screen, the page centre, top and height); the two rows below stay for an older
  -- Utilities
  G.CS_GEO = {origin = {1495, 880}, center = 1450, top = 704, height = 214}

  function G.Career()
    if type(UTIL_CS) ~= "table" or type(UTIL_CS.Cell) ~= "function" then
      return
    end
    local mine = On() and G.ptype == 6
    if type(UTIL_CS.OwnLayout) == "function" then
      CsBand(0, false)
      CsBand(1, false)
      UTIL_CS.OwnLayout(mine, G.CS_GEO)
      return
    end
    if not mine then
      CsBand(0, false)
      CsBand(1, false)
      if G.csOn then
        G.csOn = false
        for r = 0, 1 do
          for c = 0, 3 do
            local L, k = UTIL_CS.Cell(r, c)
            if Exists(L) and Cmd(C.IS_OPEN, L, k) == true then
              Cmd(C.POS, L, 0, 0, 0, k)
            end
          end
        end
      end
      return
    end
    G.csOn = true
    for i = 0, 4 do
      if Exists(811691761) and Cmd(C.IS_OPEN, 811691761, i) == true then
        Cmd(C.VIS, 811691761, i, false)
      end
    end
    CsBand(0, true)
    CsBand(1, true)
    for r = 0, 4 do
      for c = 0, (UTIL_CS.ROW_CELLS[r] or 4) - 1 do
        local L, k = UTIL_CS.Cell(r, c)
        if Exists(L) and Cmd(C.IS_OPEN, L, k) == true then
          local at = G.CS_AT[r] and G.CS_AT[r][c + 1]
          Cmd(C.VIS, L, k, at ~= nil)
          if at ~= nil then
            Cmd(C.POS, L, at[1] - (1204.5 + 195 * c), (880 + 84 * r) - at[2], 0, k)
          end
        end
      end
    end
    if G.csFor ~= G.hdl then
      G.csFor = G.hdl
      pcall(G.CareerFill)
    end
  end

  function G.CareerFill()
    local chara = UTIL_CS.SelectedChara(nil)
    local v = UTIL_CS.Ex(chara, 0)
    local T = UTIL_CS.Text
    for r = 0, 1 do
      for c = 0, 3 do
        UTIL_CS.Set(r, c, "", "")
      end
    end
    if v == nil then
      UTIL_CS.Set(0, 0, T("no_data"), T("none"))
      return
    end
    local signed, before, source = v[1], v[2], v[3]
    local m, w, d, l, g, a = v[5], v[6], v[7], v[8], v[9], v[10]
    local src = type(source) == "number" and source >= 1 and source <= 4 and T("src" .. source) or T("none")
    UTIL_CS.Set(0, 0, T("l_signed"), UTIL_CS.Date(signed) or UTIL_CS.Date(before) or T("none"))
    UTIL_CS.Set(0, 1, T("l_source"), src)
    UTIL_CS.Set(0, 2, T("l_matches"), tostring(m))
    UTIL_CS.Set(1, 0, T("l_record") .. " · %", UTIL_CS.Fmt("v_record", w, d, l) .. " · " .. UTIL_CS.Pct(w, m))
    UTIL_CS.Set(1, 1, T("l_goals"), tostring(g))
    UTIL_CS.Set(1, 2, T("l_gpm"), UTIL_CS.Ratio(g, m, 2))
    local _ = a
  end
