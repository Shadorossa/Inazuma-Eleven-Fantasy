-- match_challenge (VR-Framework service): the Chronicle board's command menu (vs_route_town_command_select_menu, a
-- VRFW_Host host of the framework's route_board graft) shows the match challenge of the focused row.
-- While a match row (difficultyType > 0) of a piece whose game has a [[VRFW.MatchChallenge]] for that row (the route
-- node's `Challenge`, or the challenge's `Games` + `Difficulties`) is focused, the blue list panel grows by one band
-- under its last row (band "match_challenge" of VRFW_RBC_PanelBand, the first one: the mod that sizes the panel
-- re-sizes it; the band's place is reserved on every row of such a piece, VRFW_RBC_PanelBandReserve, so the panel
-- keeps one height) and the band shows the
-- challenge's condition centred in the panel (its `Short` text, else its title: VRFW_MC.Status label) in the board
-- rows' own text style at their size, in a box of the panel's inner width (a longer line shrinks to the box),
-- light blue when the active dock meets it and light red when not (the same check the VS screen gates the kick-off
-- with). On any other row the band is gone. The line follows the panel's layer when it moves (Step).
-- Accept opens the VS screen as retail; the kick-off is refused there while the dock does not meet the challenge
-- (vs_route_town_vs_team_menu/110_match_challenge.lua).
-- The line is the layer vrfw_mc_text (1 instance, the match panel's text object), added to the menu by
-- content\menus\match_challenge_banner.toml and opened here on the first draw.
-- The piece's game is VRFW_RBC.L.n4, its save slot VRFW_RBC.L.n2, the rows VRFW_RBC.L.t3, the panel VRFW_RBC.panel
-- (route_board's rbc_common.lua). Required starters with their own text (`[[VRFW.MatchChallenge.Required]]` Text)
-- stay as entries of the button guide while they apply (a `UntilFirstClear` one until the row is won:
-- CMND_GET_CHRONICLE_CLEAR_STATUS).
-- No engine call at load time.
if VRFW_Host ~= nil then
  local ROWS = 284009563   -- vsroute01_16_sub_list
  local CLEAR_GET = VRFW_Cmd.GET_CHRONICLE_CLEAR_STATUS   -- (slot, difficulty)
  local FOCUS_GET = 2603265800   -- (layer) -> the focused row index (0-based)

  local LABEL = {
    LAYER = 375144984,           -- vrfw_mc_text (object vrfw_mc_label: a copy of the board's row vsroute01_16_sub_list)
    INSTANCE = 0,
    -- the row's centred text (the retail rows' style and size), its box (layout x -240..240, y 27..-27: centred on the
    -- layer's origin), the row's other text, plates and groups hidden
    TEXT_NODE = 3180095505,      -- _text_list_base01_off
    HIDE_TEXTS = {808187266 --[[_text_list_base01_on]]},
    HIDE_MESHES = {688754292 --[[_touch_list01]], 1525181930 --[[_list_base01_on]], 4270801635 --[[_list_base01_off]],
      3034975430 --[[_list_base01_ol]], 713202021 --[[_list_base01_ok]], 1409068817 --[[_list_base01_gray]],
      1928480906 --[[_icon_list01_on]], 3004512670 --[[_icon_list01_off]]},
    HIDE_NODES = {1849899120 --[[_pos_class01]], 44923504 --[[_pos_lv01]], 3597743423 --[[_pos_team_lv01]],
      2442161064 --[[_pos_list_left01]]},
    C = {
      OPEN = VRFW_Cmd.OPEN_LAYER, VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE, SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE, POS = VRFW_Cmd.SET_LAYER_LOCAL_POS, GET_POS = VRFW_Cmd.GET_LAYER_LOCAL_POS,
      MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE, TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING, LAYER_NUM = VRFW_Cmd.GET_CREATE_LAYER_NUM,
      DRAW_PRIORITY = VRFW_Cmd.SET_DRAW_PRIORITY,   -- CMND_SET_DRAW_PRIORITY (layer, instance, priority, children)
      NODE_SCALE = 2885415772,      -- (layer, instance, node, width, height): the text node's box
      NODE_POS = 2575768773,        -- (layer, instance, node, axis 0 x / 1 y, value)
      NODE_VISIBLE = 2158717427,    -- (layer, node, bool, instance)
      TEXT_VISIBLE = VRFW_Cmd.SET_MENU_TEXT_VISIBLE,    -- (layer, text node, bool, instance)
    },
    -- screen px (1920 x 1080, y down) of the battle-kind list of a normal piece as placed: the first row's centre
    -- line, the rows' spacing (vsroute01_15c `_atc_listNN`, 70 px apart), half a row's height, the gap between two
    -- rows, the panel's centre line (x)
    FIRST_ROW_MID_Y = 442, ROW_STEP = 70, ROW_HALF_HEIGHT = 30, ROW_GAP = 11, PANEL_MID_X = 436,
    -- the band under the last row: its height (the panel grows by ROW_GAP + BAND_HEIGHT); the text's box = the
    -- panel's inner width (700 px panel, 40 px margin each side), the row's text height. The rows' size (layer scale
    -- 1) when the line fits the box; a longer line shrinks the layer to the box (the game does not squeeze it, and its
    -- text measure answers the box): its width is estimated at GLYPH_WIDTH px a Latin character at scale 1 (a CJK
    -- character or a button tag counts as two), never below MIN_SCALE
    BAND_HEIGHT = 44, TEXT_BOX_WIDTH = 620, TEXT_BOX_HEIGHT = 54, GLYPH_WIDTH = 18, MIN_SCALE = 0.3,
    -- font_color markup (common/font/font_color.cfg.bin): AIMARK01 light blue, R light red, then the reset
    COLOUR_MET = "[CAIMARK01]", COLOUR_UNMET = "[CR]", COLOUR_RESET = "[C]",
    opened = false, shown = false, x = 0, y = 0,
  }

  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  -- the line's width at scale 1, estimated (colour markup [C…] left out, furigana as its base; a CJK character or a
  -- button tag <…> = 2)
  local function line_width(s)
    s = string.gsub(s, "%[C[^%]]*%]", "")
    s = string.gsub(s, "%[([^%]/]*)/[^%]]*%]", "%1")   -- furigana [base/reading]: the base only
    local units, i, n = 0, 1, string.len(s)
    while i <= n do
      local b = string.byte(s, i)
      local close = b == 60 and string.find(s, ">", i, true) or nil
      if close ~= nil then
        units, i = units + 2, close + 1
      else
        local len = b >= 0xF0 and 4 or (b >= 0xE0 and 3 or (b >= 0xC0 and 2 or 1))
        units, i = units + (len >= 3 and 2 or 1), i + len
      end
    end
    return units * LABEL.GLYPH_WIDTH
  end

  -- the layer scale that fits the line into the box (1 = it fits at the rows' size)
  local function fit_scale(s)
    local w = line_width(s)
    if w <= LABEL.TEXT_BOX_WIDTH then
      return 1
    end
    return math.max(LABEL.MIN_SCALE, LABEL.TEXT_BOX_WIDTH / w)
  end

  local function instance_count()
    local n = M(LABEL.C.LAYER_NUM, LABEL.LAYER)
    return type(n) == "number" and n or 0
  end

  -- was this difficulty row of the open piece won before (false when unknown)
  local function row_cleared(diff)
    local ok, slot = pcall(function()
      return VRFW_RBC.L.n2
    end)
    if not ok or type(slot) ~= "number" then
      return false
    end
    local okC, won = pcall(funcLuaCommand, CLEAR_GET, slot, diff)
    return okC and won == true
  end

  local function piece_game()
    local ok, game = pcall(function()
      return VRFW_RBC.L.n4
    end)
    if ok and type(game) == "number" then
      return game
    end
    return nil
  end

  -- the panel's band: asked once per change (the mod that sizes the panel re-sizes it); BAND_ORDER = the first band
  local BAND_ID, BAND_ORDER, LABEL_PRIORITY = "match_challenge", 10, 856   -- over the panel (845) and its rows (847)
  local function panel_band(extra)
    local p = VRFW_RBC ~= nil and VRFW_RBC.panel or nil
    if p == nil or p.layer == nil then
      return
    end
    if VRFW_RBC_PanelBand ~= nil then
      pcall(VRFW_RBC_PanelBand, BAND_ID, extra, BAND_ORDER)
    elseif p.extra ~= extra and VRFW_RBC_PanelExtra ~= nil then
      pcall(VRFW_RBC_PanelExtra, p.layer, p.kind, p.rows, extra)
    end
  end

  -- how far the panel's layer moved since it was placed (px, the layer position's own axes)
  local function panel_shift()
    local p = VRFW_RBC ~= nil and VRFW_RBC.panel or nil
    if p == nil or p.layer == nil or p.x == nil or p.y == nil then
      return 0, 0
    end
    local x, y = M(LABEL.C.GET_POS, p.layer, 0)
    if type(x) ~= "number" or type(y) ~= "number" then
      return 0, 0
    end
    return x - p.x, y - p.y
  end

  local function place()
    local dx, dy = panel_shift()
    M(LABEL.C.POS, LABEL.LAYER, LABEL.x + dx, LABEL.y + dy, 0, LABEL.INSTANCE)
  end

  -- closing = the menu is closing: the text goes, the panel keeps its size while it leaves
  local function hide(closing)
    if not closing then
      panel_band(0)
    end
    if not LABEL.shown then
      return
    end
    LABEL.shown = false
    M(LABEL.C.VISIBLE, LABEL.LAYER, LABEL.INSTANCE, false)
  end

  -- the band under the list's last row, the label centred in it
  local function show(status, row_count)
    if instance_count() < 1 or type(status.label) ~= "string" or status.label == "" then
      return hide()   -- the menu has no label layer (menu patch not installed) or nothing to say
    end
    local k = LABEL.INSTANCE
    if not LABEL.opened then
      LABEL.opened = true
      M(LABEL.C.OPEN, LABEL.LAYER, k)
    end
    panel_band(LABEL.ROW_GAP + LABEL.BAND_HEIGHT)
    LABEL.shown = true
    local colour = status.ok and LABEL.COLOUR_MET or LABEL.COLOUR_UNMET
    -- only the row's centred text: its plates, icon, level and class groups and its other text hidden
    for _, mesh in ipairs(LABEL.HIDE_MESHES) do
      M(LABEL.C.MESH_VISIBLE, LABEL.LAYER, mesh, false, k)
    end
    for _, node in ipairs(LABEL.HIDE_NODES) do
      M(LABEL.C.NODE_VISIBLE, LABEL.LAYER, node, false, k)
    end
    for _, node in ipairs(LABEL.HIDE_TEXTS) do
      M(LABEL.C.TEXT_VISIBLE, LABEL.LAYER, node, false, k)
    end
    -- the box at the panel's inner width, centred on the layer's origin; a line longer than the box shrinks the layer
    -- around that origin (centre kept) so the line spans at most the box
    local scale = fit_scale(status.label)
    local box_width = LABEL.TEXT_BOX_WIDTH / scale
    M(LABEL.C.NODE_SCALE, LABEL.LAYER, k, LABEL.TEXT_NODE, box_width, LABEL.TEXT_BOX_HEIGHT)
    M(LABEL.C.NODE_POS, LABEL.LAYER, k, LABEL.TEXT_NODE, 0, -box_width / 2)
    M(LABEL.C.NODE_POS, LABEL.LAYER, k, LABEL.TEXT_NODE, 1, LABEL.TEXT_BOX_HEIGHT / 2)
    M(LABEL.C.SCALE, LABEL.LAYER, scale, scale, 1, k)
    M(LABEL.C.TEXT_VISIBLE, LABEL.LAYER, LABEL.TEXT_NODE, true, k)
    M(LABEL.C.TEXT, LABEL.LAYER, LABEL.TEXT_NODE, colour .. status.label .. LABEL.COLOUR_RESET, k)
    local last_row_mid = LABEL.FIRST_ROW_MID_Y + LABEL.ROW_STEP * (math.max(row_count, 1) - 1)
    local y = last_row_mid + LABEL.ROW_HALF_HEIGHT + LABEL.ROW_GAP + LABEL.BAND_HEIGHT / 2
    if VRFW_RBC_PanelBandTop ~= nil then
      local ok, top = pcall(VRFW_RBC_PanelBandTop, BAND_ID)
      if ok and type(top) == "number" then
        y = top + LABEL.ROW_GAP + LABEL.BAND_HEIGHT / 2
      end
    end
    LABEL.x, LABEL.y = LABEL.PANEL_MID_X, -y
    place()
    M(LABEL.C.DRAW_PRIORITY, LABEL.LAYER, k, LABEL_PRIORITY, true)
    M(LABEL.C.VISIBLE, LABEL.LAYER, k, true)
  end

  -- the label of the focused row (no band on a row without a challenge)
  local function update()
    if VRFW_MC == nil or VRFW_RBC == nil then
      return hide()
    end
    local ok, rows = pcall(function()
      return VRFW_RBC.L.t3
    end)
    if not ok or type(rows) ~= "table" then
      return hide()
    end
    local idx = M(FOCUS_GET, ROWS)
    local row = type(idx) == "number" and rows[idx + 1] or nil
    local game = piece_game()
    local diff = row ~= nil and row.difficultyType or 0
    local status = nil
    if diff > 0 and game ~= nil then
      status = VRFW_MC.Status(game, 0, diff, row_cleared(diff))
    end
    if status == nil then
      return hide()
    end
    show(status, #rows)
  end

  -- a new menu object: its label layer is not open yet
  VRFW_Host.on("vs_route_town_command_select_menu", "OnInit", {
    id = "menu_engine.match_challenge", phase = "before",
    fn = function()
      LABEL.opened, LABEL.shown = false, false
    end,
  })

  VRFW_Host.on("vs_route_town_command_select_menu", "OnChangeFocus", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function(r, a1)
      if a1 == ROWS then
        update()
      end
    end,
  })

  -- the panel is placed: a piece with a challenge on any row keeps the band's place on every row (one panel height,
  -- nothing below moves when the focus changes; the band is empty on a row without one)
  VRFW_Host.on("vs_route_town_command_select_menu", "VRFW_RBC_ListLayer", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function()
      if VRFW_MC == nil or VRFW_RBC_PanelBandReserve == nil then
        return
      end
      local game = piece_game()
      local ok, rows = pcall(function()
        return VRFW_RBC.L.t3
      end)
      if game == nil or not ok or type(rows) ~= "table" then
        return
      end
      for _, row in ipairs(rows) do
        local diff = row.difficultyType or 0
        if diff > 0 and VRFW_MC.Of(game, diff) ~= nil then
          pcall(VRFW_RBC_PanelBandReserve, BAND_ID, LABEL.ROW_GAP + LABEL.BAND_HEIGHT, BAND_ORDER)
          return
        end
      end
    end,
  })

  -- the list's first open (its focus is set there)
  VRFW_Host.on("vs_route_town_command_select_menu", "OnOpenLayer", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function(r, a1, a2)
      if a1 == ROWS and a2 == 0 then
        update()
      end
    end,
  })

  -- the line follows the panel while it moves (its open / close slide)
  VRFW_Host.on("vs_route_town_command_select_menu", "Step", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function()
      if LABEL.shown then
        place()
      end
    end,
  })

  -- the menu closes (a row decided, Back)
  VRFW_Host.on("vs_route_town_command_select_menu", "OnDecideFocus", {
    id = "menu_engine.match_challenge", phase = "before",
    fn = function()
      hide(true)
    end,
  })

  VRFW_Host.on("vs_route_town_command_select_menu", "OnBack", {
    id = "menu_engine.match_challenge", phase = "before",
    fn = function()
      hide(true)
    end,
  })

  -- the required starters that still apply: their own texts in the button guide (no icon, no command)
  VRFW_Host.on("vs_route_town_command_select_menu", "VRFW_RBC_Guide", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function(r, item, icons, texts, cmds)
      if VRFW_MC == nil or VRFW_RBC == nil or type(item) ~= "table" or (item.difficultyType or 0) <= 0
        or type(texts) ~= "table" then
        return
      end
      local game = piece_game()
      local i = game ~= nil and VRFW_MC.Of(game, item.difficultyType) or nil
      local c = i ~= nil and VRFW_MC.Info(i) or nil
      if c ~= nil and #(c.required or {}) > 0 then
        for _, t in ipairs(VRFW_MC.RequiredTexts(i, row_cleared(item.difficultyType))) do
          icons[#icons + 1] = 0
          texts[#texts + 1] = t
          cmds[#cmds + 1] = 0
        end
      end
    end,
  })
end
