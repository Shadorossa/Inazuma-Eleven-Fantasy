-- Combo partners of the mod Utilities (feature combo_partners; docs/game/mechanics/combo-partners.md §6.3) on
-- Character Reforged's «Fantasy» skill table (evt_skill_slot_menu; its extension point: docs/framework/
-- skill-table-host.md). SOURCE of the hook file util_cp_skill_table.lua (gen_hooks.py fills the @crc placeholders and
-- the shared picker util_cp_core.src.lua, the same one the retail board's hook file carries; edit the sources, run the
-- script).
-- The screen is Character Reforged's; Utilities declares an X ACTION on it as data (content\menus\102_team\
-- skill_table_partners.toml: [[entry]] host = "character_reforged.skill_table.x_action", id = "partners",
-- action = { lua = "Utilities.SkillTablePartners" }) and the screen's host calls Utilities.SkillTablePartners(phase,
-- ctx) on the focused row:
--   "available" -> the row's move needs partners (CMND_UTIL_COMBO_INFO: 2+ performers, the retail board's test); false
--                  while Inazuma Fantasy's own picker is in this screen (global EVT_CPK: its X stays alone);
--   "guide"     -> the guide entry «X Compañeros» (the entry's text utilities.cp_btn);
--   "press"     -> the picker (the screen's action coroutine): Utilities' list window (layers util_pc_list /
--                  util_pc_row added to this screen by the same menus file; the screen's own list cover hides the
--                  bottom buttons and the card under it, and the move rows, the aura / mix halves and the cursor are
--                  hidden meanwhile as for the screen's own lists), rows «Aleatorio (en el partido)» then the screen's squad
--                  (its team list t4 / formation slots t5 / formation n6) in field order, then the confirm popup and
--                  CMND_UTIL_COMBO_SET.
-- The screen's input is not switched off: while a page is up its focus changes are dropped (OnChangeFocus wrapped)
-- and the focus is put back on the move row, so the rows under the list stay as they were.
-- Without Character Reforged's host nothing calls the function (no X, no guide entry). Definitions only at chunk load.
do
@CORE@

  UTIL_CP.SKILL_TABLE_PRIO = {BG = 449, LIST = 450, ITEM = 451} -- the screen's own list popups (evt_ss_list) use these
  UTIL_CP.FOCUS_INDEX = 2603265800 -- (layer) -> focused instance
  UTIL_CP.FOCUS_SET = 1778826357 -- (layer, instance, true): the focus on that instance

  function UTIL_CP.SkillTableHost()
    local host = type(CharacterReforged) == "table" and CharacterReforged.SkillTable or nil
    if type(host) ~= "table" or type(host.L) ~= "table" then
      return nil
    end
    return host
  end

  -- the screen's squad: its team list t4[1..n15] (the registered squad), formation slots t5[i], formation n6
  function UTIL_CP.SkillTableMembers(locals)
    local team, count = locals.t4, locals.n15
    if type(team) ~= "table" or type(count) ~= "number" then
      return nil
    end
    local slots = locals.t5
    local out = {formation = locals.n6}
    for i = 1, count do
      local h = team[i]
      if type(h) == "number" and h ~= 0 then
        out[#out + 1] = {hdl = h, slot = type(slots) == "table" and slots[i] or nil, index = i}
      end
    end
    return out
  end

  UTIL_CP.LAYER_VISIBLE = 711242136 -- CMND_SET_LAYER_VISIBLE (layer, instance, bool)
  UTIL_CP.HELP_LINE = 3078308064 -- mainmenu90_05_content_guide_line01 (the screen's help line)
  UTIL_CP.HELP_TEXT = 378156699 -- _text_guide01

  -- 2026-10-14 (owner, Jade Beor: the move rows, the aura / mix halves and their focus frame drew over the picker's
  -- rows): the left column's own pieces go away while the picker is up and come back when it closes, as the screen's
  -- own lists do (PL.SSListShow: every row instance of the move list - instance 0 is the split aura / mix row - and
  -- the arrow cursor; the move plates follow their row's visibility each Step, PL.RowPlateSync). The rows draw at the
  -- picker's priority (450), so hiding them is what keeps the two lists apart.
  function UTIL_CP.SkillTableColumn(locals, show)
    local rows, count, cursor = locals.L_ROW, locals.EVT_ROW_NUM, locals.L_CURSOR
    if type(rows) == "number" and type(count) == "number" then
      for r = 0, count - 1 do
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, rows, r, show)
      end
    end
    if type(cursor) == "number" then
      pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, cursor, 0, show)
    end
  end

  -- the SCREEN table of util_cp_core for this screen (host = CharacterReforged.SkillTable, ctx of the press)
  function UTIL_CP.SkillTable(host, ctx)
    local locals = host.L
    local state = {row = ctx.row}
    local function cover(show)
      local screen_helpers = locals.PL
      if type(screen_helpers) == "table" and type(screen_helpers.ListCover) == "function" then
        pcall(screen_helpers.ListCover, show)
      end
    end
    local function refocus()
      local rows = locals.L_ROW
      if rows == nil or state.row == nil then
        return
      end
      local ok, at = pcall(funcLuaMenuCommand, UTIL_CP.FOCUS_INDEX, rows)
      if not ok or at ~= state.row then
        pcall(funcLuaMenuCommand, UTIL_CP.FOCUS_SET, rows, state.row, true)
      end
    end
    local function help(text)
      pcall(funcLuaMenuCommand, 1083631230 --[[CMND_SET_MENU_TEXT_STRING]], UTIL_CP.HELP_LINE, UTIL_CP.HELP_TEXT, text, 0)
    end
    return {
      player = UTIL_CP.U32(ctx.chara),
      backdrop = false, -- the screen's list cover draws the blue backdrop
      Members = function()
        return UTIL_CP.SkillTableMembers(locals)
      end,
      Begin = function()
        cover(true)
        UTIL_CP.SkillTableColumn(locals, false)
        refocus()
      end,
      Frame = refocus,
      Help = help,
      Finish = function()
        cover(false)
        UTIL_CP.SkillTableColumn(locals, true)
        refocus()
        if type(locals.EVT_GUIDE_TEXT) == "string" then
          help(locals.EVT_GUIDE_TEXT) -- the screen's own help line back
        end
        if type(UpdateEquipItemInfo) == "function" then
          pcall(UpdateEquipItemInfo) -- the row's own guide and panel back
        end
      end,
      GuideMenu = function()
        return locals.n12
      end,
      Message = host.Message,
    }
  end

  -- ---- the move card's performers (owner 2026-10-14: right of «IA activada» and the unlock level, as in Inazuma
  -- Fantasy) ----------------------------------------------------------------------------------------------------------
  -- On the move card of this screen (EVT_DetailShow in the move view), for a move with 2+ performers: one miniface per
  -- performer in cast order (the player, the move's fixed partners, the chosen partners; a free slot without a choice
  -- = «?», the match's random pick), right of the «Nv.» unlock-level badge, or right of «IA activada» when the move
  -- has no badge (it unlocks at level 1). Inazuma Fantasy's layout (its graft combo_partners, «Move panel
  -- minifaces»): SIZE px faces in a dark frame, SPACE apart, GAP right of the badge's right end. Drawn with the layer
  -- util_cp_face (content/menus/102_team/skill_table_partners.toml), priority 690 over the card (656 / 657). Hidden
  -- while Inazuma Fantasy's own block is in the screen (it draws the same faces), while the picker is up, and with
  -- the card (any other view: aura, miximax, passive, Hiper, training).
  UTIL_CP.CARD_FACES = {
    LAYER = @crc:util_cp_face@, COUNT = 4,
    SIZE = 60, SPACE = 8, GAP = 12,
    FACE_WIDTH = 96, FACE_CENTRE_Y = 40, -- the layout's face: 96 px, centre 40 px above the layer origin
    BADGE_LOCATOR = 2, -- PL.LAYOUT_LOCS index of the «Nv.» badge locator (its right end and vertical centre)
    DEFAULT_X = 1279, DEFAULT_Y = -796, -- that locator in the move view, when the screen does not answer
    BADGE_SPAN = 115, -- the badge's width plus its gap to «IA activada»: the start without a badge
    PRIORITY = 690,
    PLATE_TEXTURE = 4021797290, -- soccer11_20.g4tx
    PLATE_SPRITE = 2597149412, -- teambuff_base01 (the plate row's dark rounded square)
    PLATE_SLOT = 1011017977, -- icon_cmd_type_base01 (texture slot)
    PLATE_MESH = 2172872396, -- _icon_cmd_type_base01
    PLATE_FRAME = {-54, 94, 108, 108}, -- 6 px around the face (top-left corner + size, y up)
    ROW_MESHES = {2334302522, 2022529787, 1697431574, 4215821749, 2309656400, 2037408502, 1255155594, 2384755812},
    ROW_LOCATORS = {442049775 --[[_pos_equip01]], 3426045766 --[[_pos_have01]]},
    ROW_NUMBERS = {3974820126 --[[num_equip01]], 3334923667 --[[num_have01]]},
    ROW_TEXTS = {931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]]},
    OPEN_RETRY = 30, -- Step frames before an instance that did not open is asked again
    want = nil, -- the performers to draw (nil = none)
    want_key = nil,
    want_gen = 0, -- bumped per new set: every instance is filled again
    drawn_gen = {}, -- [instance] = the set it was filled for
    open_requests = {}, -- [instance] = frames since it was asked to open
    shown = false,
    logged = nil,
  }

  function UTIL_CP.CardFacesLayerExists()
    local ok, exists = pcall(funcLuaMenuCommand, 262659071 --[[CMND_IS_EXIST_LAYER]], UTIL_CP.CARD_FACES.LAYER)
    return ok and exists == true
  end

  function UTIL_CP.CardFaceIsOpen(i)
    local ok, open = pcall(funcLuaMenuCommand, 2640875187 --[[CMND_IS_OPEN_LAYER]], UTIL_CP.CARD_FACES.LAYER, i)
    return ok and open == true
  end

  -- the screen is closing or closed: nothing may be opened any more
  function UTIL_CP.SkillTableGone(host)
    local menu = host ~= nil and host.L.EVT_MENU or nil
    if menu == nil then
      return false
    end
    local ok1, closing = pcall(funcLuaCommand, 1193349555 --[[CMND_IS_CLOSING_MENU_OBJECT]], menu)
    local ok2, closed = pcall(funcLuaCommand, 1521844538 --[[CMND_IS_CLOSE_MENU_OBJECT]], menu)
    return (ok1 and closing == true) or (ok2 and closed == true)
  end

  -- hide the faces (the wanted set stays: they come back with the card)
  function UTIL_CP.CardFacesHide()
    local F = UTIL_CP.CARD_FACES
    if F.shown and UTIL_CP.CardFacesLayerExists() then
      for i = 0, F.COUNT - 1 do
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, F.LAYER, i, false)
      end
    end
    F.shown = false
  end

  -- no faces wanted any more
  function UTIL_CP.CardFacesClear()
    local F = UTIL_CP.CARD_FACES
    F.want, F.want_key = nil, nil
    F.open_requests = {}
    UTIL_CP.CardFacesHide()
  end

  -- the screen is going: every open instance closed, nothing wanted
  function UTIL_CP.CardFacesShut()
    local F = UTIL_CP.CARD_FACES
    F.want, F.want_key = nil, nil
    F.open_requests, F.drawn_gen = {}, {}
    if UTIL_CP.CardFacesLayerExists() then
      for i = 0, F.COUNT - 1 do
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, F.LAYER, i, false)
        if UTIL_CP.CardFaceIsOpen(i) then
          pcall(funcLuaMenuCommand, 1273612389 --[[CMND_CLOSE_LAYER]], F.LAYER, i)
        end
      end
    end
    F.shown = false
  end

  -- the move card of the move view is up (and nothing else owns the faces)
  function UTIL_CP.CardFacesWanted(host)
    if type(EVT_CPK) == "table" or UTIL_CP.picking then
      return false
    end
    local screen_helpers = host.L.PL
    if type(screen_helpers) ~= "table" or screen_helpers.layout_mode ~= "move" then
      return false
    end
    local ok, visible = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], host.L.L_DETAIL, 0)
    return ok and visible == true
  end

  -- the move card was just drawn for `skill` (0 = no move card): the performers wanted on it
  function UTIL_CP.CardFacesFor(skill)
    local F = UTIL_CP.CARD_FACES
    local host = UTIL_CP.SkillTableHost()
    skill = UTIL_CP.U32(skill)
    if host == nil or skill == 0 or not UTIL_CP.CardFacesLayerExists() or not UTIL_CP.CardFacesWanted(host) then
      UTIL_CP.CardFacesClear()
      return
    end
    local info = UTIL_CP.ComboInfo(skill)
    local player = UTIL_CP.U32(host.L.n)
    if info == nil or player == 0 then
      UTIL_CP.CardFacesClear()
      return
    end
    local squad = {}
    for _, m in ipairs(UTIL_CP.SkillTableMembers(host.L) or {}) do
      local h = UTIL_CP.U32(m.hdl)
      local ok, chara = pcall(funcLuaCommand, 1131797651, h, 1)
      squad[#squad + 1] = {hdl = h, chara = ok and UTIL_CP.U32(chara) or 0}
    end
    local performers = UTIL_CP.Performers(player, squad, UTIL_CP.Get(player, skill), info)
    local parts = {string.format("%08X", skill)}
    for _, e in ipairs(performers) do
      parts[#parts + 1] = string.format("%08X", UTIL_CP.U32(e.chara or 0))
    end
    local key = table.concat(parts, " ")
    if F.want ~= nil and F.want_key == key then
      return
    end
    F.want, F.want_key = performers, key
    F.want_gen = F.want_gen + 1
  end

  -- instance i as a bare miniface in its frame (everything else of the row object hidden); true = the face drew
  function UTIL_CP.CardFaceFill(i, e)
    local F, R = UTIL_CP.CARD_FACES, UTIL_CP.R
    local L = F.LAYER
    for _, m in ipairs(F.ROW_MESHES) do
      pcall(funcLuaMenuCommand, 3405944500 --[[CMND_SET_MESH_VISIBLE]], L, m, false, i)
    end
    for _, q in ipairs(F.ROW_LOCATORS) do
      pcall(funcLuaMenuCommand, 2158717427 --[[locator visible]], L, q, false, i)
    end
    for _, num in ipairs(F.ROW_NUMBERS) do
      pcall(funcLuaMenuCommand, 1233047821 --[[number visible]], L, i, num, false)
    end
    for _, t in ipairs(F.ROW_TEXTS) do
      pcall(funcLuaMenuCommand, 2735666188 --[[text visible]], L, t, false, i)
    end
    pcall(funcLuaMenuCommand, R.RESET_FACE, L, i, R.FACE_SLOT)
    local face = false
    if e.chara ~= nil and e.chara ~= 0 then
      pcall(SetDisableForceCharaInvalidUseTarget)
      local ok, drawn = pcall(funcLuaMenuCommand, 552280324, L, i, false, R.FACE, R.FACE_SLOT, 0, 0, e.chara)
      pcall(SetEnableForceCharaInvalidUseTarget)
      face = ok and drawn ~= false
    end
    if not face then
      pcall(funcLuaMenuCommand, 558735651, L, UTIL_CP.ICON_TEX, UTIL_CP.UNKNOWN_SPR, R.FACE_SLOT, 0, i)
    end
    pcall(funcLuaMenuCommand, 3405944500, L, R.FACE, true, i)
    UTIL_CP.Place(L, i, F.PLATE_MESH, F.PLATE_FRAME)
    pcall(funcLuaMenuCommand, 558735651, L, F.PLATE_TEXTURE, F.PLATE_SPRITE, F.PLATE_SLOT, 0, i)
    pcall(funcLuaMenuCommand, 3405944500, L, F.PLATE_MESH, true, i)
    return face
  end

  -- where the first face starts: the «Nv.» badge's right end, or «IA activada»'s when the badge is hidden
  function UTIL_CP.CardFacesOrigin(host)
    local F = UTIL_CP.CARD_FACES
    local x, y = F.DEFAULT_X, F.DEFAULT_Y
    local screen_helpers = host.L.PL
    if type(screen_helpers) == "table" and type(screen_helpers.LayoutLoc) == "function" then
      local ok, lx, ly = pcall(screen_helpers.LayoutLoc, F.BADGE_LOCATOR)
      if ok and type(lx) == "number" and type(ly) == "number" then
        x, y = lx, ly
      end
    end
    local okb, visible = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], host.L.L_DETAIL_LV, 0)
    local has_badge = okb and visible == true
    if not has_badge then
      x = x - F.BADGE_SPAN
    end
    return x, y, has_badge
  end

  -- once per frame while faces are wanted (Step: outside any engine callback, so opening is safe here). An instance
  -- is opened once (asked again after OPEN_RETRY frames), filled once per wanted set when it is open and the layer is
  -- not loading, placed and scaled every frame, and shown only once filled.
  function UTIL_CP.CardFacesDraw(host)
    local F = UTIL_CP.CARD_FACES
    local performers = F.want
    if performers == nil or not UTIL_CP.CardFacesLayerExists() then
      return
    end
    local count = math.min(#performers, F.COUNT)
    local okl, loading = pcall(funcLuaMenuCommand, 3057768039 --[[CMND_IS_LOADING]], F.LAYER)
    local ready = not (okl and loading == true)
    local x0, y0, has_badge = UTIL_CP.CardFacesOrigin(host)
    local scale = F.SIZE / F.FACE_WIDTH
    local drawn = {}
    for i = 0, F.COUNT - 1 do
      local e = i < count and performers[i + 1] or nil
      local open = UTIL_CP.CardFaceIsOpen(i)
      if e ~= nil and not open then
        local asked = F.open_requests[i]
        if asked == nil or asked >= F.OPEN_RETRY then
          F.open_requests[i] = 0
          F.drawn_gen[i] = nil
          pcall(funcLuaMenuCommand, 629267548 --[[CMND_OPEN_LAYER]], F.LAYER, i)
          pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, F.LAYER, i, false)
        else
          F.open_requests[i] = asked + 1
        end
        drawn[#drawn + 1] = "opening"
      elseif e ~= nil and ready then
        F.open_requests[i] = nil
        local cx = x0 + F.GAP + F.SIZE / 2 + i * (F.SIZE + F.SPACE)
        local okp = pcall(funcLuaMenuCommand, 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], F.LAYER, cx,
          y0 - F.FACE_CENTRE_Y * scale, 0, i)
        pcall(funcLuaMenuCommand, 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], F.LAYER, scale, scale, 1, i)
        if F.drawn_gen[i] ~= F.want_gen then
          local okf, face = pcall(UTIL_CP.CardFaceFill, i, e)
          F.drawn_gen[i] = okf and F.want_gen or nil
          e.face_drawn = okf and face
        end
        local up = okp and F.drawn_gen[i] == F.want_gen
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, F.LAYER, i, up)
        drawn[#drawn + 1] = up and string.format("%08X%s", UTIL_CP.U32(e.hdl or 0), e.face_drawn and "" or "?")
          or "setup"
      elseif open then
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, F.LAYER, i, false)
      end
    end
    F.shown = true
    local key = table.concat(drawn, " ")
    if key ~= F.logged then
      F.logged = key
      UTIL_CP.Log("card faces", key, "at", x0, y0, has_badge and "after the level badge" or "after IA activada")
    end
  end

  function UTIL_CP.CardFacesStep()
    local F = UTIL_CP.CARD_FACES
    local host = UTIL_CP.SkillTableHost()
    if host == nil then
      return
    end
    if UTIL_CP.SkillTableGone(host) then
      UTIL_CP.CardFacesShut()
    elseif F.want ~= nil and UTIL_CP.CardFacesWanted(host) then
      UTIL_CP.CardFacesDraw(host)
    else
      UTIL_CP.CardFacesHide()
    end
  end

  Utilities = type(Utilities) == "table" and Utilities or {}

  -- the x_action entry of Character Reforged's skill table host (see the top of this file)
  function Utilities.SkillTablePartners(phase, ctx)
    local host = UTIL_CP.SkillTableHost()
    if host == nil or type(ctx) ~= "table" then
      return nil
    end
    if phase == "available" then
      if type(EVT_CPK) == "table" then
        return false -- Inazuma Fantasy's picker owns X on this screen
      end
      return type(ctx.row) == "number" and (ctx.move or 0) ~= 0 and UTIL_CP.ComboInfo(ctx.move) ~= nil
    elseif phase == "guide" then
      return true
    elseif phase ~= "press" then
      return nil
    end
    local skill = UTIL_CP.U32(ctx.move)
    local info = UTIL_CP.ComboInfo(skill)
    if info == nil then
      host.Sound("refused")
      return
    end
    UTIL_CP.Open(UTIL_CP.SkillTable(host, ctx), skill, info)
  end

  -- ---- the picker's layers and the focus while it runs (globals wrapped once per VM) -----------------------------
  function UTIL_CP.WrapSkillTableGlobal(name, make)
    UTIL_CP.skill_table_wrapped = UTIL_CP.skill_table_wrapped or {}
    if UTIL_CP.skill_table_wrapped[name] then
      return
    end
    local current = _ENV[name]
    if current == nil then
      return
    end
    _ENV[name] = make(current)
    UTIL_CP.skill_table_wrapped[name] = true
  end

  UTIL_CP.WrapSkillTableGlobal("OnSetupLayer", function(previous)
    return function(a1, a2, ...)
      if UTIL_CP.Ours(a1) then
        UTIL_CP.SetupLayer(a1, a2, UTIL_CP.SKILL_TABLE_PRIO)
        return
      end
      if a1 == UTIL_CP.CARD_FACES.LAYER then
        -- the move card's performer faces: over the card, hidden until the Step draw has set them up
        local r = table.pack(previous(a1, a2, ...))
        pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, UTIL_CP.CARD_FACES.PRIORITY, true)
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, a1, a2, false)
        return table.unpack(r, 1, r.n)
      end
      return previous(a1, a2, ...)
    end
  end)

  UTIL_CP.WrapSkillTableGlobal("OnOpenLayer", function(previous)
    return function(a1, a2, ...)
      if UTIL_CP.Ours(a1) then
        if not UTIL_CP.picking then
          pcall(funcLuaMenuCommand, 711242136, a1, a2, false)
        end
        return
      end
      if a1 == UTIL_CP.CARD_FACES.LAYER then
        -- the engine runs this inside CMND_OPEN_LAYER: never draw or open from here; the instance stays hidden until
        -- the Step draw has filled and placed it
        local r = table.pack(previous(a1, a2, ...))
        pcall(funcLuaMenuCommand, UTIL_CP.LAYER_VISIBLE, a1, a2, false)
        if type(a2) == "number" then
          UTIL_CP.CARD_FACES.drawn_gen[a2] = nil
        end
        return table.unpack(r, 1, r.n)
      end
      return previous(a1, a2, ...)
    end
  end)

  -- a page is up: the D-pad / stick move the screen's focus too (its input stays on); the move is dropped here and
  -- the page's Frame puts the focus back on the move row
  UTIL_CP.WrapSkillTableGlobal("OnChangeFocus", function(previous)
    return function(a1, a2, ...)
      if UTIL_CP.picking then
        return
      end
      return previous(a1, a2, ...)
    end
  end)

  -- the move card's performers: set after the screen's own card fill, drawn each frame, shut with the screen
  UTIL_CP.WrapSkillTableGlobal("EVT_DetailShow", function(previous)
    return function(skill, row, ...)
      local r = table.pack(previous(skill, row, ...))
      local ok, err = pcall(UTIL_CP.CardFacesFor, r[1] == true and skill or 0)
      if not ok then
        UTIL_CP.Log("card faces failed", tostring(err))
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  UTIL_CP.WrapSkillTableGlobal("Step", function(previous)
    return function(...)
      local r = table.pack(previous(...))
      local F = UTIL_CP.CARD_FACES
      if F.want ~= nil or F.shown then
        local ok, err = pcall(UTIL_CP.CardFacesStep)
        if not ok then
          UTIL_CP.Log("card faces step failed", tostring(err))
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  UTIL_CP.WrapSkillTableGlobal("OnBack", function(previous)
    return function(...)
      local r = table.pack(previous(...))
      if UTIL_CP.SkillTableGone(UTIL_CP.SkillTableHost()) then
        pcall(UTIL_CP.CardFacesShut)
      end
      return table.unpack(r, 1, r.n)
    end
  end)
end
