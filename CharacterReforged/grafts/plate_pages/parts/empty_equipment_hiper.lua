-- Player page block (plate_pages.lua): the empty slot, the Equipamiento page and the Hiper page's L3
  -- ---- no player focused (empty slot): nothing of the page, back when a player is focused ---------------------
  function G.Empty()
    if not On() then
      return
    end
    local h = 0
    if type(GetPersonalPlateSelectCharaStHdlAuto) == "function" then
      local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
      h = ok and type(v) == "number" and v or 0
    end
    local empty = h == 0
    if not empty and type(IsInvalidSoccerCharaHdl) == "function" then
      local ok, bad = pcall(IsInvalidSoccerCharaHdl, h)
      empty = ok and bad == true
    end
    if empty and not G.emptyHidden then
      G.emptyHidden = true
      for _, l in ipairs({G.PAGE, G.PLATE, G.STATUS, G.BAND, G.SLANT, G.TAG}) do
        if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
          Cmd(C.VIS, l, 0, false)
        end
      end
      if type(G.BarsVisible) == "function" then
        G.BarsVisible(false)
      end
      for i = 0, 4 do
        G.Tile(i, false)
      end
      if type(G.PassiveRowsHide) == "function" then
        pcall(G.PassiveRowsHide)
      end
      if type(EVT_PH_Hide) == "function" then
        pcall(EVT_PH_Hide)
      end
      if type(UTIL_CS) == "table" and type(UTIL_CS.Hide) == "function" then
        pcall(UTIL_CS.Hide)
      end
      if type(SetVisiblePersonalPlateLayerAll) == "function" then
        pcall(SetVisiblePersonalPlateLayerAll, false)
      end
    elseif empty then
      -- 2026-10-07 (Nacho: «Sin hipertécnica» on an empty bench slot): while no player is focused the Hiper panel
      -- stays hidden every frame (a pending redraw or a later UpdatePageInfo must not bring it back; cheap: the hide
      -- only acts on a visible layer)
      if type(EVT_PHI) == "table" and type(EVT_PHI.HideLayer) == "function" then
        EVT_PH_PENDING = nil
        pcall(EVT_PHI.HideLayer)
      end
    elseif not empty and G.emptyHidden then
      G.emptyHidden = false
      G.csFor = nil
      for _, l in ipairs({G.PAGE, G.PLATE, G.STATUS}) do
        if Exists(l) and Cmd(C.IS_OPEN, l, 0) == true then
          Cmd(C.VIS, l, 0, true)
        end
      end
      if type(UpdatePersonalPlatePage) == "function" then
        pcall(UpdatePersonalPlatePage)
      end
    end
  end

  -- ---- Equipamiento: 2 x 2, no title row ------------------------------------------------------------------------
  function G.Equip()
    if not Exists(G.EQUIP) then
      return
    end
    local mine = On() and G.ptype == 0
    for k = 0, 4 do
      if Cmd(C.IS_OPEN, G.EQUIP, k) == true then
        if k <= 3 then
          local sc = mine and G.EQUIP_SCALE or 1
          Cmd(C.SCALE, G.EQUIP, sc, sc, 1, k)
        elseif mine then
          Cmd(C.VIS, G.EQUIP, k, false)
        end
      end
    end
  end

  -- ---- Hiper page: L3 = the keshin a miximax gives, and back ------------------------------------------------------
  function G.HiperL3()
    G.frame = G.frame + 1
    if not On() or EVT_PH_PAGE == nil or GetNowPageIdx == nil or GetNowPageIdx() ~= EVT_PH_PAGE
        or type(EVT_PH_MxAura) ~= "function" or type(EVT_PH_Show) ~= "function" or type(funcLuaCommand) ~= "function" then
      return
    end
    local L = G.L3
    local okp, p1 = pcall(funcLuaCommand, L.CHECK, L.CTRL, L.CMD)
    local okq, p2 = pcall(funcLuaCommand, L.CHECK, L.CTRL_AN, L.CMD)
    if not ((okp and p1 == true) or (okq and p2 == true)) or G.frame - G.l3last < 8 then
      return
    end
    G.l3last = G.frame
    local chara = 0
    if type(GetPersonalPlateSelectCharaStHdlAuto) == "function" then
      local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
      chara = ok and type(v) == "number" and v or 0
    end
    if chara == 0 then
      return
    end
    if type(EVT_PH_CanSwitch) == "function" then
      -- 2026-10-12 (two Hiper slots, docs/game/hiper/hiper-two-slots.md): L3 switches the aura slot / the mix slot
      local okc, can = pcall(EVT_PH_CanSwitch, chara)
      if not okc or can ~= true then
        return
      end
    else
      if type(EVT_PH_Skill) == "function" and EVT_PH_Skill(chara) ~= EVT_PH_MX_CARRIER then
        return
      end
      local oka, aura = pcall(EVT_PH_MxAura, chara)
      if not oka or aura == nil then
        return
      end
    end
    EVT_PH_MX_VIEW = not EVT_PH_MX_VIEW
    pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, 2500047763)      -- the plate's cursor sound
    pcall(EVT_PH_Show, chara)
  end
