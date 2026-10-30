-- Player page block (plate_pages.lua): the page decoration, the form hints and the form badge row
  -- ---- page content -------------------------------------------------------------------------------------------
  local function HidePoly()
    if not Exists(G.RADAR) then
      return
    end
    for k = 0, 1 do
      for _, m in ipairs(G.M_POLY) do
        Cmd(C.MESH, G.RADAR, m, false, k)
      end
    end
  end

  -- no page titles; the move-slot badges only on SUPERTÉCNICAS
  local function Decor(ptype)
    for _, m in ipairs(G.M_TITLES) do
      Cmd(C.MESH, G.STATUS, m, false, 0)
    end
    for _, m in ipairs(G.M_ARROWS) do
      Cmd(C.MESH, G.STATUS, m, false, 0)
    end
    for i, m in ipairs(G.M_SLOTS) do
      Cmd(C.MESH, G.STATUS, m, ptype == 1 and i <= 3, 0)   -- round 8: never the rpg copies (they stacked mid-page)
    end
  end

  -- round 8: the PERFIL hint «R3 Cambiar forma» (header plate's grade text node, placed by the layout) while the
  -- player has more than one form (plate_model's EVT_PPM.forms)
  G.N_GRADE = 1006587362
  -- round 15 (2026-10-07, Nacho: «la N debería estar a la derecha de los 3 puntos»; loader.log showed the node at
  -- the wanted place while the glyph stayed at the old layout box): a text node is placed by the text system at
  -- setup only, runtime node moves (rounds 14b-14g) never move the text. The LAYOUT now puts the box where the
  -- Pasivas R3 glyph belongs (if_plate_row_build.py: box 1713..2123 x 908..938, left-aligned: the glyph centred at
  -- (1730, 923), right of the 3 sub-page dots on the Q / E glyph row); PERFIL's «R3 Cambiar forma» starts there too.
  -- This function only sets the text and its visibility.
  -- 2026-10-09 (Nacho: «RS Formas»): the hint reads «<CMD_FUNC6> Formas» (text Fantasy.PlayerFormsPrompt, IF
  -- text\rows\player_forms.toml, 9 languages; <CMD_FUNC6> = R3 on a pad, its bound key on a keyboard) and shows only
  -- while the forms plate_model loaded are the shown player's (EVT_PPM.fhdl == EVT_PPM.want: no stale prompt of the
  -- previous player while the next one builds). 2026-10-12 (owner): the forms hint left the dots row: the RS key sits
  -- on the form badge (G.FormBadge below); the dots row keeps «Ver apariencia» and the Pasivas R3.
  -- the forms of the shown player (plate_model's list, once it is his): their count, else 0
  function G.FormCount()
    local M = EVT_PPM
    if type(M) ~= "table" or type(M.forms) ~= "table" or M.fhdl == nil or M.fhdl ~= M.want then
      return 0
    end
    return #M.forms
  end
  -- 2026-10-07: where a menu offers the retail «Ver apariencia» for this page (plate_model EVT_PPM.appearance, rule
  -- view_in_menus: Formación) the same hint reads «<CMD_FUNC6> Ver apariencia» (retail menu_text 1638840503, every
  -- language) and R3 / a click opens that view (plate_model M.OpenView -> research/grafts/form_appearance)
  G.VIEW_TEXT = 1638840503
  -- 2026-10-14 (owner: the RS button of the character view is Utilities' now; docs/game/mechanics/form-viewer.md §8):
  -- the form key of PERFIL (plate_model), ATRIBUTOS (G.MxToggle) and the Hiper page (G.HiperToggle) is Utilities'
  -- action «Cambiar forma» (CMD_UTIL_VIEW_FORMS, default RS, rebindable) where this menu is declared for it (Character
  -- Reforged content\menus\player_page_view_forms.toml, only with Utilities); its glyph follows the binding. Without that declaration: R3 (CMD_FUNC6) as before.
  function G.FormKeyDecl()
    local V = type(BetterQoL) == "table" and BetterQoL.ViewForms or nil
    return type(V) == "table" and type(V.Declared) == "function" and V.Declared("personal_plate_menu") == true and V or nil
  end
  function G.FormKeyDown()
    local V = G.FormKeyDecl()
    if V ~= nil then
      return V.Pressed() == true
    end
    local ok1, a = pcall(funcLuaCommand, @crc:CMND_CHECK_INPUT_CMD@, 1332654303, 3147328756)   -- CMD_FUNC6 (R3)
    local ok2, b = pcall(funcLuaCommand, @crc:CMND_CHECK_INPUT_CMD@, 2748927068, 3147328756)
    return (ok1 and a == true) or (ok2 and b == true)
  end
  function G.FormGlyph()
    local V = G.FormKeyDecl()
    return V ~= nil and type(V.GLYPH) == "string" and V.GLYPH or "<CMD_FUNC6>"
  end
  function G.ViewOffered()
    return type(EVT_PPM) == "table" and EVT_PPM.appearance ~= nil and type(EVT_PPM.OpenView) == "function"
  end
  function G.ViewHint()
    if G.viewHint == nil then
      local ok, t = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@, G.VIEW_TEXT)
      if ok and type(t) == "string" and t ~= "" then
        G.viewHint = G.FormGlyph() .. " " .. t
      else
        return G.FormGlyph()
      end
    end
    return G.viewHint
  end
  function G.Hint()
    local view = On() and G.ptype == EVT_PPG_DESC_TYPE and G.ViewOffered() and not G.InOffice()
    local on = false
    local psub = On() and G.ptype == 2 and not G.InOffice()
    if view then
      Cmd(C.SET_TEXT, G.PLATE, G.N_GRADE, G.ViewHint(), 0)
      on = true
    elseif psub then
      Cmd(C.SET_TEXT, G.PLATE, G.N_GRADE, "<CMD_FUNC6>", 0)
      on = true
    end
    Cmd(C.TEXT_VIS, G.PLATE, G.N_GRADE, on, 0)
  end

  -- 2026-10-13 (owner): ATRIBUTOS toggles Normal / Miximax with the form key (R3 / the RS key, a click on the badge),
  -- only for a player with a miximax (the page slot character_reforged.page_stat_gain answers: a mod's gains of his
  -- mix slot's form, e.g. the miximax confirmation's). The view is plate_hiper's EVT_R9.mx (its
  -- L3 still toggles it too): the numbers are the totals in the retail «goes up» style (EVT_R9.Draw), the gauges
  -- show the gain past the fill in the gain colour (G.Bars, G.gains), the form badge shows the Normal / Mix-Max glyph,
  -- and the 3D model follows: the form viewer's Miximax form (1; 3, its armour form, only when 1 is not listed),
  -- Normal (0) otherwise (plate_model M.ShowForm). Armour forms are never picked here. Entering ATRIBUTOS starts
  -- Normal (since 2026-10-14 a page change resets the model's form: G.Apply); another player starts Normal.
  G.MX_FORMS = {1, 3}
  G.MX_SOUND = 2629173176                -- sy0009, the form viewer's switch sound (as R3 on PERFIL)
  function G.MxHdl()
    local a = type(EVT_R9) == "table" and EVT_R9.args or nil
    return type(a) == "table" and a[3] or nil
  end
  function G.MxAvail()
    local h = G.MxHdl()
    if h == nil or type(EVT_R9.Gains) ~= "function" then
      return false
    end
    if G.mxAvailFor ~= h then
      G.mxAvailFor = h
      local ok, g = pcall(EVT_R9.Gains, h)
      G.mxAvail = ok and type(g) == "table"
      pcall(funcLuaCommand, C.LOG, "EVT_PPG mx avail", tostring(h), tostring(G.mxAvail))
    end
    return G.mxAvail == true
  end
  -- the miximax form among the shown player's forms (plate_model's list, once it is his); nil = none
  -- the first form of `list` the shown player has (plate_model's list, once it is his); nil = none
  function G.FirstForm(list)
    local M = EVT_PPM
    if type(list) ~= "table" or type(M) ~= "table" or type(M.forms) ~= "table" or M.fhdl == nil or M.fhdl ~= M.want then
      return nil
    end
    for _, f in ipairs(list) do
      for _, x in ipairs(M.forms) do
        if x == f then
          return f
        end
      end
    end
    return nil
  end
  function G.MxForm()
    return G.FirstForm(G.MX_FORMS)
  end
  function G.CurForm()
    local M = EVT_PPM
    if type(M) ~= "table" or type(M.forms) ~= "table" then
      return 0
    end
    return M.forms[M.fidx or 1] or 0
  end
  -- the gains of the Miximax view (with every graph refresh, after G.vals)
  function G.MxGains(hdl)
    G.gains = nil
    if type(EVT_R9) == "table" and EVT_R9.mx == true and type(EVT_R9.Gains) == "function" then
      local ok, g = pcall(EVT_R9.Gains, hdl)
      if ok and type(g) == "table" then
        G.gains = g
      end
    end
  end
  -- the radar's last call again (numbers, values, gains), as plate_hiper's L3 does
  function G.MxRedraw()
    local a = type(EVT_R9) == "table" and EVT_R9.args or nil
    if type(a) == "table" and type(UpdateCharaParameterGraphByCharaStHdl) == "function" then
      pcall(UpdateCharaParameterGraphByCharaStHdl, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
    end
  end
  function G.MxSet(on, why)
    if (EVT_R9.mx == true) == on then
      return
    end
    EVT_R9.mx = on
    pcall(funcLuaCommand, C.LOG, "EVT_PPG mx view", tostring(why), tostring(on))
    G.MxRedraw()
  end
  function G.MxToggle(why)
    if not On() or G.ptype ~= EVT_PPG_STATS_TYPE or not G.MxAvail() then
      return
    end
    G.mlast = G.mtick or 0
    pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, G.MX_SOUND)
    G.MxSet(EVT_R9.mx ~= true, why)
  end
  function G.MxStep()
    if not On() or not G.H.pages or type(EVT_R9) ~= "table" then
      return
    end
    local h = G.MxHdl()
    if h ~= G.mxHdl then                   -- another player: Normal
      G.mxHdl, G.mxAvailFor = h, nil
      G.MxSet(false, "player")
    end
    local stats = G.ptype == EVT_PPG_STATS_TYPE and not G.InOffice()
    if stats ~= G.mxOnPage then
      G.mxOnPage = stats
      if stats then                        -- entering ATRIBUTOS: the view follows the model's form
        local mf = G.MxForm()
        G.MxSet(G.MxAvail() and mf ~= nil and G.CurForm() == mf, "page")
      end
    end
    if not stats then
      return
    end
    G.mtick = (G.mtick or 0) + 1
    if G.mtick - (G.mlast or -100) >= 8 then
      if G.FormKeyDown() then                -- the form key (Utilities' «Cambiar forma», else R3)
        G.MxToggle("R3")
      end
    end
    -- the 3D model follows the view (plate_model rebuilds it with that form; not where the retail view is offered)
    local M = EVT_PPM
    if type(M) == "table" and type(M.ShowForm) == "function" and M.appearance == nil then
      local f = (EVT_R9.mx == true and G.MxForm()) or 0
      if G.CurForm() ~= f then
        pcall(M.ShowForm, f)
      end
    end
  end


  -- 2026-10-13 (owner: «Adapta lo del RS para ver las formas, no sale para las auras del slot de mix»): the Hiper page
  -- offers the same RS toggle (R3 / the RS key / a click on the badge) between Normal and the form of the aura it
  -- shows, by one rule per slot (G.SLOT_FORMS): the MIX slot's move (plate_hiper EVT_PH_Skill = EVT_PH_MixOf: shown when
  -- the aura slot is empty or in the L3 view) -> the form viewer's miximax forms (G.MX_FORMS), the AURA slot's -> its
  -- armour (2). A slot whose aura has no such form for him («Modo cambio», a totem / keshin without armour) = no badge,
  -- no toggle. The form list already reads the mix slot first (VR-Framework form viewer, transform_engine
  -- form/viewer.rs: `[miximax] mix_table`, then the aura board slot), as CMND_EVT_MX_GAINS does. Entering the page,
  -- another player or the other slot (L3) takes the model's current form; the 3D model follows (plate_model M.ShowForm).
  G.HIPER_TYPE = 5                        -- the Hiper page's type (plate_hiper, page index 4)
  G.SLOT_FORMS = {mix = G.MX_FORMS, aura = {2}}
  function G.HiperChara()
    if type(GetPersonalPlateSelectCharaStHdlAuto) ~= "function" then
      return 0
    end
    local ok, v = pcall(GetPersonalPlateSelectCharaStHdlAuto)
    return ok and type(v) == "number" and v or 0
  end
  -- the form of the aura the page shows (nil = none) and its slot
  function G.HiperTarget(c)
    if c == 0 or type(EVT_PH_Skill) ~= "function" or type(EVT_PH_MixOf) ~= "function" then
      return nil
    end
    local okS, sk = pcall(EVT_PH_Skill, c)
    if not okS or type(sk) ~= "number" or sk == 0 then
      return nil
    end
    local okM, mix = pcall(EVT_PH_MixOf, c)
    local slot = (okM and mix == sk) and "mix" or "aura"
    return G.FirstForm(G.SLOT_FORMS[slot]), slot
  end
  -- 2026-10-13 (owner: a DOUBLE hyper = a MIX slot move AND an AURA slot move, plate_hiper EVT_PH_CanSwitch): RS (R3 /
  -- the RS key / a click on the badge) ALTERNATES the Hiper section between the two slots (EVT_PH_MX_VIEW, the switch
  -- L3 also does: title strip, portrait, move row, AT, tension redrawn by EVT_PH_Show) and the 3D model goes to the
  -- matching form with the same press (mix view -> the slot's G.SLOT_FORMS.mix form, aura view -> .aura; Normal when
  -- the player has no such form). One press, one meaning: on this page RS is the slot switch and the model follows it;
  -- the Normal <-> form toggle stays for a player with only ONE of the two. RS left / right still turns the model
  -- (plate_model M.StickTurn). Entering the page (another player, the forms loaded) with the model already in the mix
  -- slot's form opens the mix view. The badge shows both slots' glyphs, the shown one lit (G.FormBadge).
  function G.HiperDoubleSet(view, c, why)
    if (EVT_PH_MX_VIEW == true) ~= view then
      EVT_PH_MX_VIEW = view
      if type(EVT_PH_Show) == "function" and c ~= 0 then
        pcall(EVT_PH_Show, c)
      end
    end
    G.hiperTgt, G.hiperSlot = G.HiperTarget(c)
    pcall(funcLuaCommand, C.LOG, "EVT_PPG hiper view", tostring(why), view and "mix" or "aura", tostring(G.hiperTgt))
  end
  function G.HiperToggle(why)
    if not On() or G.ptype ~= G.HIPER_TYPE then
      return
    end
    if G.hiperDouble == true then
      G.mlast = G.mtick or 0
      pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, G.MX_SOUND)
      G.HiperDoubleSet(EVT_PH_MX_VIEW ~= true, G.HiperChara(), why)
      return
    end
    if G.hiperTgt == nil then
      return
    end
    G.mlast = G.mtick or 0
    G.hiperOn = not G.hiperOn
    pcall(funcLuaCommand, @crc:CMND_SND_PLAY_SE@, G.MX_SOUND)
    pcall(funcLuaCommand, C.LOG, "EVT_PPG hiper form", tostring(why), tostring(G.hiperSlot), tostring(G.hiperTgt),
      tostring(G.hiperOn))
  end
  function G.HiperFormStep()
    if not On() or not G.H.pages or G.ptype ~= G.HIPER_TYPE or G.InOffice() then
      G.hiperKey, G.hiperTgt, G.hiperDouble, G.hiperBase = nil, nil, nil, nil
      return
    end
    local M = EVT_PPM
    local c = G.HiperChara()
    local n = type(M) == "table" and type(M.forms) == "table" and #M.forms or 0
    local base = string.format("%s:%s:%d", tostring(c), tostring(type(M) == "table" and M.fhdl), n)
    local key = base .. ":" .. tostring(EVT_PH_MX_VIEW)
    if key ~= G.hiperKey then                -- entering, another player, the other slot, the forms loaded
      G.hiperKey = key
      local okc, can = false, false
      if type(EVT_PH_CanSwitch) == "function" and c ~= 0 then
        okc, can = pcall(EVT_PH_CanSwitch, c)
      end
      G.hiperDouble = okc and can == true
      G.hiperTgt, G.hiperSlot = G.HiperTarget(c)
      G.hiperOn = G.hiperTgt ~= nil and G.CurForm() == G.hiperTgt
      pcall(funcLuaCommand, C.LOG, "EVT_PPG hiper form", "slot", tostring(G.hiperSlot), tostring(G.hiperTgt),
        tostring(G.hiperOn), G.hiperDouble and "double" or "single")
      if G.hiperDouble and base ~= G.hiperBase and EVT_PH_MX_VIEW ~= true then
        local mf = G.FirstForm(G.SLOT_FORMS.mix)
        if mf ~= nil and mf ~= 0 and G.CurForm() == mf then   -- the model already in the mix slot's form
          G.HiperDoubleSet(true, c, "page")
        end
      end
      G.hiperBase = base
    end
    if G.hiperTgt == nil and G.hiperDouble ~= true then
      return
    end
    G.mtick = (G.mtick or 0) + 1
    if G.mtick - (G.mlast or -100) >= 8 then
      if G.FormKeyDown() then                -- the form key (Utilities' «Cambiar forma», else R3)
        G.HiperToggle("R3")
      end
    end
    if type(M) == "table" and type(M.ShowForm) == "function" and M.appearance == nil then
      local f
      if G.hiperDouble == true then
        f = G.hiperTgt or 0                  -- the shown slot's form, Normal without one
      else
        f = G.hiperOn and G.hiperTgt or 0
      end
      if G.CurForm() ~= f then
        pcall(M.ShowForm, f)
      end
    end
  end

  -- the badge glyph of a Hiper slot's move by its aura type (EVT_HC.AuraType: 0 keshin, 1 armour, 2 miximax, 3 totem,
  -- 6 mode change; any other = the keshin glyph); the _dim sprite = the slot not shown (Character Reforged
  -- content/images/menu/plate_form_badges.toml)
  G.SLOT_GLYPH = {[0] = {@crc:evt_pp_fb_keshin@, @crc:evt_pp_fb_keshin_dim@},
    [1] = {@crc:evt_pp_fb_armour@, @crc:evt_pp_fb_armour_dim@},
    [2] = {@crc:evt_pp_fb_miximax@, @crc:evt_pp_fb_miximax_dim@},
    [3] = {@crc:evt_pp_fb_totem@, @crc:evt_pp_fb_totem_dim@},
    [6] = {@crc:evt_pp_fb_mode@, @crc:evt_pp_fb_mode_dim@}}
  function G.SlotGlyph(skill, lit)
    local t = nil
    if type(EVT_HC) == "table" and type(EVT_HC.AuraType) == "function" and type(skill) == "number" and skill ~= 0 then
      local ok, v = pcall(EVT_HC.AuraType, skill)
      t = ok and v or nil
    end
    local g = (t ~= nil and G.SLOT_GLYPH[t]) or G.SLOT_GLYPH[0]
    return g[lit and 1 or 2], t
  end
  -- a double hyper's badge: {mix slot glyph, aura slot glyph} (the shown one lit) and its layout key
  function G.HiperDoubleGlyphs()
    local c = G.HiperChara()
    if c == 0 or type(EVT_PH_MixOf) ~= "function" or type(EVT_PH_AuraOf) ~= "function" then
      return nil
    end
    local okM, mix = pcall(EVT_PH_MixOf, c)
    local okA, aura = pcall(EVT_PH_AuraOf, c)
    if not (okM and okA) then
      return nil
    end
    local mv = EVT_PH_MX_VIEW == true
    local gm, tm = G.SlotGlyph(mix, mv)
    local ga, ta = G.SlotGlyph(aura, not mv)
    return {gm, ga}, string.format("d%s:%s:%s", mv and "m" or "a", tostring(tm), tostring(ta))
  end

  -- 2026-10-12 (owner: «the form as its black-and-white icon, not the Normal pill»): while the shown player has more
  -- than one form (PERFIL, no retail view offered, not over the office) the form the 3D model shows is a BADGE centred
  -- where the name pill was (G.FB_AT, over the model's top, under the level): the form's glyph tiles (G.FORM_GLYPHS:
  -- form ids of the VR-Framework's form viewer, 0 Normal = the player bust, 1 Miximax = the Mix-Max tab glyph,
  -- 2 Armour = the armour tab glyph, 3 Armour + Miximax = both side by side) then the RS key (<CMD_FUNC6>: R3 on a pad,
  -- its bound key on a keyboard; pressing it cycles the forms, plate_model) on a square plate of the same height.
  -- Tiles and plate = gauge copies (layer evt_pp_fbadge, instances 0 / 1 the tiles, 2 the key's plate:
  -- player_page_layout.toml) showing the sprites of content/images/menu/plate_form_badges.toml (the game's own
  -- monochrome tab glyphs on a near-black square, the key's plate light, made at boot); the key glyph = the text of the evt_pp_flabel pill
  -- (its pill mesh hidden; text box 330 x 40 left-aligned from x -165, scaled by G.FB_KEY_K). It changes on the press,
  -- before the new model is built; the layout is redone only when the shown form changes.
  G.FBADGE = @crc:evt_pp_fbadge@
  G.FB_TRACE = {[0] = @crc:evt_pp_fbadge0@, @crc:evt_pp_fbadge1@, @crc:evt_pp_fbadge2@}
  G.FB_KEY = 2                               -- the RS key's plate instance
  G.FB_PLATE = @crc:evt_pp_fb_key@          -- the key's light plate
  -- 2026-10-12 (two Hiper slots): 3 = the armour the miximax grants (its own glyph: the armour with a small Mix-Max
  -- mark) + the Mix-Max, 4 = the aura slot's armour + the Mix-Max
  G.FORM_GLYPHS = {[0] = {@crc:evt_pp_fb_player@}, {@crc:evt_pp_fb_miximax@}, {@crc:evt_pp_fb_armour@},
    {@crc:evt_pp_fb_mxarmour@, @crc:evt_pp_fb_miximax@}, {@crc:evt_pp_fb_armour@, @crc:evt_pp_fb_miximax@}}
  G.FB_AT = {1700, 262}                      -- the badge row's centre (screen px; the old pill's centre)
  G.FB_S, G.FB_GAP = 40, 6                   -- tile / key plate size, gap between them (screen px)
  G.FB_KEY_K = 0.8                           -- the key text's scale (the old pill text's)
  -- the key glyph's offset in its plate (screen px; DY < 0 = up). The gaiji's drawing is centred in its cell
  -- (gaiji_xinput gaiji_bt12: 48 x 48 cell, drawn box x 4..44, y 8..40), so the remaining offset is where the text box
  -- puts the cell: owner 2026-10-12 (1.29.61 in game) saw the RS glyph low and to the right with DX 7 / no DY
  G.FB_KEY_DX, G.FB_KEY_DY = 3, -4
  G.FLABEL = @crc:evt_pp_flabel@
  G.N_AREA_TEXT = 1899787537                 -- _text_area01 (the pill's text)
  G.N_AREA_BASE = 3516146179                 -- _area_base01 (the pill)
  function G.FbHide()
    G.fbKey, G.fbBox = nil, nil
    for i = 0, 2 do
      if Exists(G.FBADGE) and Cmd(C.IS_OPEN, G.FBADGE, i) == true then
        Cmd(C.VIS, G.FBADGE, i, false)
      end
    end
    if Exists(G.FLABEL) and Cmd(C.IS_OPEN, G.FLABEL, 0) == true then
      Cmd(C.VIS, G.FLABEL, 0, false)
    end
  end
  -- one gauge copy as a tile: its frame quad (476 x 44 at (94, -816) in its units) = left, top, size s (screen px)
  function G.FbPlace(i, sprite, left, top, s)
    local L = G.FBADGE
    if not G.ready[L * 16 + i] then
      G.ready[L * 16 + i] = true
      Cmd(C.TRACE, G.PAGE, 0, G.FB_TRACE[i], true)
      for _, m in ipairs({G.N_TOP, G.N_SIDE, 2043683848}) do
        Cmd(C.MESH, L, m, false, i)
      end
    end
    local sx, sy = s / 476, s / 44
    Cmd(C.SPRITE, L, G.TX_OWN, sprite, G.SP_FRAME, 0, i)
    Cmd(C.SCALE, L, sx, sy, 1, i)
    Cmd(C.POS, L, left - 94 * sx, -top + 816 * sy, 0, i)
  end
  function G.FormBadge()
    local glyphs, f = nil, nil
    if On() and G.ptype == EVT_PPG_DESC_TYPE and G.FormCount() > 1 and not G.ViewOffered() and not G.InOffice() then
      local M = EVT_PPM
      f = M.forms[M.fidx or 1] or 0
      glyphs = G.FORM_GLYPHS[f]
    elseif On() and G.ptype == G.HIPER_TYPE and not G.InOffice() and G.hiperDouble == true then
      glyphs, f = G.HiperDoubleGlyphs()      -- 2026-10-13: a double hyper, both slots (the shown one lit)
    elseif On() and G.ptype == G.HIPER_TYPE and not G.InOffice() and G.hiperTgt ~= nil then
      f = G.hiperOn and G.hiperTgt or 0      -- 2026-10-13: the Hiper page, Normal / the shown aura's form
      glyphs = G.FORM_GLYPHS[f]
    elseif On() and G.ptype == EVT_PPG_STATS_TYPE and not G.InOffice() and G.MxAvail() then
      f = EVT_R9.mx == true and 1 or 0       -- 2026-10-13: ATRIBUTOS, Normal / Miximax (G.MxStep)
      glyphs = G.FORM_GLYPHS[f]
    end
    local L, T = G.FBADGE, G.FLABEL
    if glyphs == nil or not Exists(L) or not Exists(T) then
      -- 2026-10-14 (owner: a whole «ENERGÍA» gauge over Plantilla / Formación): hidden even before the badge was ever
      -- placed (G.fbKey nil): an instance Ready() opened for a badge that never finished stays the raw gauge
      G.FbHide()
      return
    end
    local n = #glyphs
    for i = 0, n - 1 do
      if not Ready(L, i) then
        return
      end
    end
    if not Ready(L, G.FB_KEY) or not Ready(T, 0) then
      return
    end
    if not G.ready[T * 16] then
      G.ready[T * 16] = true
      G.fbKey = nil
      Cmd(C.TRACE, G.PAGE, 0, T, true)
      Cmd(C.MESH, T, G.N_AREA_BASE, false, 0)
      Cmd(C.SCALE, T, G.FB_KEY_K, G.FB_KEY_K, 1, 0)
      Cmd(C.SET_TEXT, T, G.N_AREA_TEXT, G.FormGlyph(), 0)
      Cmd(2735666188 --[[text visible]], T, G.N_AREA_TEXT, true, 0)
    end
    for i = 0, n - 1 do
      if not G.ready[L * 16 + i] then
        G.fbKey = nil                          -- an instance (re)opened: place it again
      end
    end
    if not G.ready[L * 16 + G.FB_KEY] then
      G.fbKey = nil
    end
    local key = tostring(f) .. "/" .. n
    if G.fbKey ~= key then
      G.fbKey = key
      local s, gap = G.FB_S, G.FB_GAP
      local w = (n + 1) * s + n * gap
      local left, top = G.FB_AT[1] - w / 2, G.FB_AT[2] - s / 2
      for i = 0, n - 1 do
        G.FbPlace(i, glyphs[i + 1], left + i * (s + gap), top, s)
      end
      for i = n, G.FB_KEY - 1 do               -- a tile the form does not use
        if Cmd(C.IS_OPEN, L, i) == true then
          Cmd(C.VIS, L, i, false)
        end
      end
      local kx = left + n * (s + gap)
      G.FbPlace(G.FB_KEY, G.FB_PLATE, kx, top, s)
      Cmd(C.POS, T, kx + G.FB_KEY_DX + 165 * G.FB_KEY_K, -(G.FB_AT[2] + G.FB_KEY_DY), 0, 0)
      G.fbBox = {left, top, w, s}              -- the pointer zone (click = next form)
      pcall(funcLuaCommand, C.LOG, "EVT_PPG form badge", tostring(f), n, string.format("%.0f", left))
    end
    for i = 0, n - 1 do
      Cmd(C.VIS, L, i, true)
    end
    Cmd(C.VIS, L, G.FB_KEY, true)
    Cmd(C.VIS, T, 0, true)
  end
