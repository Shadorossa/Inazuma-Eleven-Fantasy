-- BetterUI (mod clean_hud, prefix BetterUI): the Chronicle VS screen's two views of the player cards, shared by its two
-- menus (vs_route_town_vs_team_menu = your half, vs_route_town_vs_enemy_formation_menu = the rival's half; their hooks
-- are assets\lua\<menu>\140_vs_basic_data.lua, the layers and card objects content\menus\vs_basic_data.toml).
--   «Preview»     BetterUI's compact card: face, element, position (no name, no level).
--   «Basic data»  the card's level («Nv.» and its number, drawn by the game for the level the screen gives the card)
--                 and the player's name on the card's bottom row instead of the element and position; the coach card
--                 shows the name only.
-- X (the retail nickname key) switches the view; the game's full name / nickname switch is not used on this screen
-- (the name follows the game's current name setting). The view is the parameter BetterUI.vs_basic_data of the game's
-- parameter store (present = «Basic data»), so both menus draw the same view; each opening of the screen starts in
-- «Preview». The name is a text layer per card hung on the card's origin by the card object's attach rows; this file
-- only fills, sizes and shows it, after each retail draw of a half (SetFormation).
-- Defines functions only; no engine call at load time.
BetterUI = type(BetterUI) == "table" and BetterUI or {}
if BetterUI.VsBasicData == nil then
  local V = {
    VIEW_PARAM = 2979464676,            -- crc32("BetterUI.vs_basic_data")
    NAME_LAYER = 98463589,              -- better_ui_card_name: instance k on card k of the pitch / bench layer
    COACH_NAME_LAYER = 770171539,       -- better_ui_card_name_leader: on the coach card
    NAME_NODE = 931545948,              -- _text_list01_on
    SPARE_NODE = 3705682548,            -- _text_list01_off (unused, kept empty)
    NAME_STYLE = 3839036294,            -- fs_28_w_cc_2d2_001_nr_sclw: white, outlined, centred, squeezed to its box
    NAME_PLATES = {3025401186, 486732393, 1516082254, 3292070381, 376662541, 3232607807, 1712955010},
    CARD_NAME = 170976702,              -- _text_chr01: the card's own name line (its box is the retail card's width)
    -- element and position of the compact card (large card, then small card): hidden under the name
    BADGES = {3895971012, 32585899, 1721769611, 4283246729, 378264806, 1910176454},
    -- the name's place from the card's origin (screen px, y up) and the name layer's scale (box 146 x 34 at scale 1):
    -- large card (pitch, coach) = its name row y -22 .. -56 at the screen's card scale 0.85; small card (bench,
    -- managers) = its element / position row y -8 .. -42, the box as wide as the small card
    LARGE = {x = -1.5, y = -33, scale = 0.85},
    SMALL = {x = -1.5, y = -21, scale = 0.58},
    FIRST_SMALL_SLOT = 11,              -- formation slots 11 .. 18 are small cards
    COACH_SLOT = 19,
    NAME_KEYS = {preview = "clean_hud.vs_preview", basic = "clean_hud.vs_basic_data"},
    NAME_KEY_CRCS = {preview = 1307210685, basic = 3674954174},
    PILL = {LAYER = 209828247, TEXT = 1704438437, SIZE = 4156564586, SCALE_GROUP = 2736921100},
    C = {
      TEXT_ID = VRFW_Cmd.VRFW_TEXT_ID,             -- CMND_VRFW_TEXT_ID
      TEXT_GET = VRFW_Cmd.TEXT_GET,            -- CMND_TEXT_GET
      FULL_NAMES = 1332416299,          -- the game's name setting: true = full names
      CHARA_INFO = VRFW_Cmd.GET_CHARA_INFO,          -- CMND_GET_CHARA_INFO (param, 0 = full name / 10 = short name)
      TEAM_INFO = 2151743654,           -- (team, 8) -> ok, member count
      OPEN = VRFW_Cmd.OPEN_LAYER, IS_OPEN = VRFW_Cmd.IS_OPEN_LAYER, LAYER_COUNT = VRFW_Cmd.GET_CREATE_LAYER_NUM, VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,
      POS = VRFW_Cmd.SET_LAYER_LOCAL_POS, SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE,
      TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING, TEXT_VISIBLE = VRFW_Cmd.SET_MENU_TEXT_VISIBLE, TEXT_STYLE = 2333948100,
      MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE, IS_MESH_VISIBLE = VRFW_Cmd.IS_MESH_VISIBLE, NODE_VISIBLE = 2158717427,
      GROUP_INDEX = VRFW_Cmd.GET_GROUP_INDEX, GROUP_RESET = 541357333, GROUP_RATE = 1595998683,
    },
  }
  BetterUI.VsBasicData = V

  local function Menu(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if r[1] then
      return table.unpack(r, 2, r.n)
    end
    return nil
  end

  local function Game(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if r[1] then
      return table.unpack(r, 2, r.n)
    end
    return nil
  end

  -- ---- the view ----------------------------------------------------------------------------------------------------
  function V.IsBasic()
    return VRFW_Param.Has(V.VIEW_PARAM)
  end

  -- the parameter store keeps an existing key: it is cleared before it is set
  function V.SetBasic(on)
    VRFW_Param.Clear(V.VIEW_PARAM)
    if on then
      VRFW_Param.Set(V.VIEW_PARAM, 1)
    end
  end

  function V.Text(which)
    local id = Game(V.C.TEXT_ID, V.NAME_KEYS[which])
    if type(id) ~= "number" or id == 0 then
      id = V.NAME_KEY_CRCS[which]
    end
    local s = Game(V.C.TEXT_GET, id)
    return type(s) == "string" and s or ""
  end

  -- the player's name as the game shows it (its full name / short name setting)
  function V.PlayerName(chara)
    local field = Game(V.C.FULL_NAMES) == false and 10 or 0
    local a, b = Game(V.C.CHARA_INFO, chara, field)
    local s = type(a) == "string" and a or b
    return type(s) == "string" and s or ""
  end

  -- ---- the pill under the pitch («X <view>») -------------------------------------------------------------------------
  -- it names the view X switches to, as the retail pill named the other name form; sized as the retail
  -- UpdateNicknameButtonText sizes it
  function V.UpdatePill()
    local P = V.PILL
    local s = V.Text(V.IsBasic() and "preview" or "basic")
    Menu(V.C.TEXT, P.LAYER, P.TEXT, s)
    local group = Menu(V.C.GROUP_INDEX, P.LAYER, 0, P.SCALE_GROUP)
    if type(group) == "number" then
      Menu(V.C.GROUP_RESET, P.LAYER, P.SIZE, group, 0)
    end
    if type(MENU_DEF) == "table" and type(MENU_DEF.GetMenuTextRectSizeRate) == "function" then
      local ok, rate = pcall(MENU_DEF.GetMenuTextRectSizeRate, P.LAYER, P.TEXT, s, 64, 400)
      if ok and type(rate) == "number" then
        Menu(V.C.GROUP_RATE, P.LAYER, P.SIZE, 0, rate, 0, true, P.SCALE_GROUP)
      end
    end
  end

  -- ---- the cards -----------------------------------------------------------------------------------------------------
  local function Key(layer, idx)
    return tostring(layer) .. ":" .. tostring(idx or 0)
  end

  -- element / position meshes this file hid, per card: shown again in «Preview»
  V.hidden = V.hidden or {}

  local function HideBadges(layer, idx)
    local list = {}
    for _, mesh in ipairs(V.BADGES) do
      if Menu(V.C.IS_MESH_VISIBLE, layer, mesh, idx) ~= false then
        Menu(V.C.MESH_VISIBLE, layer, mesh, false, idx)
        list[#list + 1] = mesh
      end
    end
    V.hidden[Key(layer, idx)] = {layer = layer, idx = idx, meshes = list}
  end

  local function ShowBadges()
    for key, e in pairs(V.hidden) do
      for _, mesh in ipairs(e.meshes) do
        Menu(V.C.MESH_VISIBLE, e.layer, mesh, true, e.idx)
      end
      V.hidden[key] = nil
    end
  end

  -- the card's own name line off, its level left as the game drew it (BetterUI's compact-card graft keeps a name off
  -- and no longer hides the level of this card on a later animation); the coach card's level off
  local function DressCard(layer, idx, coach)
    if type(CLEAN_HUD_PC_HideName) == "function" then
      CLEAN_HUD_PC_HideName(funcLuaMenuCommand, layer, idx)
    else
      Menu(V.C.TEXT_VISIBLE, layer, V.CARD_NAME, false, idx)
      Menu(V.C.NODE_VISIBLE, layer, V.CARD_NAME, false, idx)
    end
    if coach then
      if type(CLEAN_HUD_PC_HideLevel) == "function" then
        CLEAN_HUD_PC_HideLevel(layer, idx)
      end
    elseif type(CLEAN_HUD_PC) == "table" and type(CLEAN_HUD_PC.hide) == "table" then
      CLEAN_HUD_PC.hide[Key(layer, idx)] = nil
    end
    HideBadges(layer, idx)
  end

  local function HideNames(layer)
    local count = Menu(V.C.LAYER_COUNT, layer)
    for k = 0, (type(count) == "number" and count or 0) - 1 do
      if Menu(V.C.IS_OPEN, layer, k) == true then
        Menu(V.C.VISIBLE, layer, k, false)
      end
    end
  end

  local function ShowName(layer, idx, name, place)
    if Menu(V.C.IS_OPEN, layer, idx) ~= true then
      Menu(V.C.OPEN, layer, idx)
      for _, mesh in ipairs(V.NAME_PLATES) do
        Menu(V.C.MESH_VISIBLE, layer, mesh, false, idx)
      end
      Menu(V.C.TEXT_STYLE, layer, idx, V.NAME_NODE, V.NAME_STYLE)
      Menu(V.C.TEXT, layer, V.SPARE_NODE, "", idx)
      Menu(V.C.TEXT_VISIBLE, layer, V.SPARE_NODE, false, idx)
    end
    Menu(V.C.SCALE, layer, place.scale, place.scale, 1, idx)
    Menu(V.C.POS, layer, place.x, place.y, 0, idx)
    Menu(V.C.TEXT, layer, V.NAME_NODE, name, idx)
    Menu(V.C.TEXT_VISIBLE, layer, V.NAME_NODE, true, idx)
    Menu(V.C.VISIBLE, layer, idx, true)
  end

  -- «Basic data» on the cards the retail SetFormation(team, a2, a3, base, cards, blanks, coachCard, ...) just drew
  function V.ApplyBasic(a)
    local team, a2, a3, cards, coachCard = a[1], a[2], a[3], a[5], a[7]
    HideNames(V.NAME_LAYER)
    HideNames(V.COACH_NAME_LAYER)
    if type(team) ~= "number" or team == 0 or type(GetTeamMemberInfo) ~= "function" then
      return
    end
    local ok, count = Game(V.C.TEAM_INFO, team, 8)
    if not ok or type(count) ~= "number" then
      return
    end
    for k = 0, count - 1 do
      -- your half's GetTeamMemberInfo takes a 5th argument (true, as the retail SetFormation passes); the rival's
      -- ignores it
      local got, chara, slot = GetTeamMemberInfo(team, k, a2, a3, true)
      if got and type(chara) == "number" and chara ~= 0 and type(slot) == "number" then
        local name = V.PlayerName(chara)
        if slot == V.COACH_SLOT and type(coachCard) == "number" then
          DressCard(coachCard, 0, true)
          if name ~= "" then
            ShowName(V.COACH_NAME_LAYER, 0, name, V.LARGE)
          end
        elseif slot >= 0 and slot < V.COACH_SLOT and type(cards) == "number" then
          DressCard(cards, slot, false)
          if name ~= "" then
            ShowName(V.NAME_LAYER, slot, name, slot >= V.FIRST_SMALL_SLOT and V.SMALL or V.LARGE)
          end
        end
      end
    end
  end

  -- «Preview»: the names off, the element / position this file hid shown again (the compact-card graft hid the name
  -- line and the level again during the draw)
  function V.ApplyPreview()
    HideNames(V.NAME_LAYER)
    HideNames(V.COACH_NAME_LAYER)
    ShowBadges()
  end

  -- an around handler of SetFormation: the retail draw in the current view. In «Basic data» the compact-card graft
  -- lets the draw through (its flag off for the draw: the game draws the level and the name line), then the cards are
  -- dressed. The arguments are kept: X draws the same team again.
  function V.Draw(nxt, ...)
    V.last = table.pack(...)
    if not V.IsBasic() then
      local r = table.pack(nxt(...))
      pcall(V.ApplyPreview)
      return table.unpack(r, 1, r.n)
    end
    local flags = type(EVT_UI_FLAGS) == "table" and EVT_UI_FLAGS or nil
    local was = flags and flags.compact_cards
    if flags then
      flags.compact_cards = false
    end
    local r = table.pack(pcall(nxt, ...))
    if flags then
      flags.compact_cards = was
    end
    if not r[1] then
      error(r[2], 0)
    end
    pcall(V.ApplyBasic, V.last)
    return table.unpack(r, 2, r.n)
  end

  -- the same half drawn again (after X)
  function V.Redraw()
    local a = V.last
    if a ~= nil and type(SetFormation) == "function" then
      SetFormation(table.unpack(a, 1, a.n))
    end
  end
end
