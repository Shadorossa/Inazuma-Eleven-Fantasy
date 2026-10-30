-- Player page block (plate_pages.lua): the header band copy and the slanted band
  -- ---- the band copy -------------------------------------------------------------------------------------------
  local function BandSetup()
    Cmd(C.MESH, G.BAND, G.M_PAGE, false, 0)  -- round 5: no page body
    Cmd(C.MESH, G.BAND, G.M_PORTRAIT, false, 0)
    for _, m in ipairs(G.M_PARAM) do
      Cmd(C.MESH, G.BAND, m, false, 0)
    end
    Cmd(C.MESH, G.BAND, G.M_BAND, false, 0)  -- the band is evt_pp_slant's
  end

  function G.Band()
    if not Exists(G.BAND) or not Exists(G.PAGE) then
      return
    end
    local up = Cmd(C.IS_VIS, G.PAGE, 0) == true and Cmd(C.IS_OPEN, G.PAGE, 0) == true
    if not up then
      if Cmd(C.IS_OPEN, G.BAND, 0) == true then
        Cmd(C.VIS, G.BAND, 0, false)
      end
      return
    end
    -- 2026-10-06 (Nacho, shots 356 / 358 / 357: a stale white hex card under the description on PERFIL, «the floor»
    -- under the model, and an empty custom-passive page): since the page object moved to IF's layout copy with its
    -- own Texture row (766def893 / 1a711d006) the drawType-1 page draws its body _personal_plate01 (the retail white
    -- card) at the content band's rect on every page. The body is the band copy's alone (round 5: no page body):
    -- the page's own is hidden every frame.
    if EVT_PPG_PAGE_BODY ~= true then
      Cmd(C.MESH, G.PAGE, G.M_PAGE, false, 0)
    end
    if not Ready(G.BAND, 0) then
      return
    end
    if not G.ready[G.BAND * 16] then
      G.ready[G.BAND * 16] = true
      G.bandkey = nil
      Cmd(C.TRACE, G.PAGE, 0, G.BAND, true)
      BandSetup()
    end
    -- a host's own card rect (G.H.card = {x0, y0, x1, y1}, screen, y down): the band copy's body node placed and
    -- sized as the layout does (if_plate_row_build.py BAND_FIXED: pos (x0 - 1435, 560 - y0), scale (w, h));
    -- without it the copy keeps the layout's card (x 985..1920, y 705..955, the Plantilla page's)
    local cr = G.H.card
    if type(cr) == "table" then
      Cmd(C.NODE_POS, G.BAND, 0, G.M_PAGE, 0, cr[1] - 1435)
      Cmd(C.NODE_POS, G.BAND, 0, G.M_PAGE, 1, 560 - cr[2])
      Cmd(C.NODE_SCALE, G.BAND, 0, G.M_PAGE, cr[3] - cr[1], cr[4] - cr[2])
    end
    local desc = On() and G.ptype == EVT_PPG_DESC_TYPE
    -- round 7: the body only as the content band of the page (its own height), on the pages that use it
    local b = On() and G.ptype ~= nil and G.BAND_ON[G.ptype] == true and not G.InOffice()
    if G.bandkey ~= 1 then
      G.bandkey = 1
      Cmd(C.SPRITE, G.BAND, G.TX_T1101, G.SP_BAND, G.SP_BODY, 0, 0)
    end
    Cmd(C.MESH, G.BAND, G.M_PAGE, b, 0)
    Cmd(C.MESH, G.BAND, G.M_FLAVOR, desc or not On(), 0)
    Cmd(C.VIS, G.BAND, 0, true)
    -- 2026-10-12 (owner, «set de habilidades»: a translucent white rounded square under the archetype box): the
    -- retail portrait frame _icon_chr_status_base01 of the page (and of the header plate) is the miniface's backdrop;
    -- the row shows no miniface, so the frame goes too, every frame (the retail fill shows it again)
    Cmd(C.MESH, G.PAGE, G.M_PORTRAIT, false, 0)
    if Exists(G.PLATE) and Cmd(C.IS_OPEN, G.PLATE, 0) == true then
      Cmd(C.MESH, G.PLATE, G.M_PORTRAIT, false, 0)
    end
    -- the page's own band / box (not drawn in the drawType-1 pass anyway) and its radar plates stay off
    Cmd(C.MESH, G.PAGE, G.M_BAND, false, 0)
    Cmd(C.MESH, G.PAGE, G.M_FLAVOR, false, 0)
    for _, m in ipairs(G.M_PARAM) do
      Cmd(C.MESH, G.PAGE, m, false, 0)
    end
  end

  -- ---- the slanted band ---------------------------------------------------------------------------------------
  local function SlantRarityOff(inst)
    inst = inst or 0
    Cmd(C.MESH, G.SLANT, G.SLANT_RARITY, false, inst)
    Cmd(C.NODE_VIS, G.SLANT, G.SLANT_RARITY_NODE, false, inst)
    Cmd(C.NODE_SCALE, G.SLANT, inst, G.SLANT_RARITY, G.HIDDEN_SCALE, G.HIDDEN_SCALE)
  end

  -- an instance of the slant copy (re)opens: banner off and the copy hidden until G.Slant has filled it again
  function G.SlantOpened(inst)
    SlantRarityOff(inst)
    Cmd(C.VIS, G.SLANT, inst or 0, false)
    G.ready[G.SLANT * 16] = nil
  end

  local function SlantHide()
    VRFW_UI.HeaderRow.Band(G.SLANT, 0, {band = true})   -- round 7: its name box off (the slanted box is evt_pp_tag)
    SlantRarityOff()
    -- the header plate's own portrait too (its layout shrinks it to 1 %; the face icon may come back at its size)
    VRFW_UI.HeaderRow.PortraitOff(G.PLATE, 0)
    -- 2026-10-07 (Nacho, skill table: a translucent white square under the name banner): the host's own extra header
    -- nodes off screen too (G.H.plate_off, e.g. the empty portrait base / mark of the header plate)
    for _, nd in ipairs(G.H.plate_off or {}) do
      Cmd(C.NODE_POS, G.PLATE, 0, nd, 0, -5000)
    end
  end

  -- the player of the header plate on the slant copy (its rarity / position colours come with it)
  function G.SlantFill()
    if G.hdl == nil or not Exists(G.SLANT) or Cmd(C.IS_OPEN, G.SLANT, 0) ~= true
        or type(UpdateCharaStatusPlateInfoByCharaStHdl) ~= "function" or type(VRFW_UI) ~= "table" then
      return
    end
    -- round 9: the band's colour (the shared header row's band: fill, colour, strip). 2026-10-14 (owner): the
    -- retail rarity look; the position colour only from a mod that declares it (No More Rarities, host
    -- character_reforged.header_band): Character Reforged's CharacterReforged.Header.BandColour. Never the library's
    -- default colour service (it would paint the position colour without No More Rarities).
    local header = type(CharacterReforged) == "table" and CharacterReforged.Header or nil
    local colour = type(header) == "table" and header.BandColour or function() end
    G.busy = true
    VRFW_UI.HeaderRow.BandFill(G.SLANT, 0, G.hdl, {colour = colour})
    G.busy = false
    SlantHide()
  end

  function G.Slant()
    if not Exists(G.SLANT) or not Exists(G.PAGE) or type(VRFW_UI) ~= "table" then
      return
    end
    local up = Cmd(C.IS_VIS, G.PAGE, 0) == true and Cmd(C.IS_OPEN, G.PAGE, 0) == true
    if not up then
      if Cmd(C.IS_OPEN, G.SLANT, 0) == true then
        Cmd(C.VIS, G.SLANT, 0, false)
      end
      return
    end
    if not Ready(G.SLANT, 0) then
      return
    end
    if not G.ready[G.SLANT * 16] then
      G.ready[G.SLANT * 16] = true
      Cmd(C.TRACE, G.PAGE, 0, G.SLANT, true)
      VRFW_UI.HeaderRow.PlaceBand(G.SLANT, 0)               -- under the row at its layout place (scale 1)
      G.SlantFill()
      SlantHide()
    end
    SlantRarityOff()
    if G.hdl ~= nil then                     -- shown once it holds a player (never its retail default)
      Cmd(C.VIS, G.SLANT, 0, true)
    end
  end
