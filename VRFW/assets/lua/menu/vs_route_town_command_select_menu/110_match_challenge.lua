-- match_challenge (VR-Framework service): the Chronicle board's command menu (vs_route_town_command_select_menu, a
-- VRFW_Host host of the framework's route_board graft) shows the match challenge of the focused row.
-- While a match row (difficultyType > 0) of a piece whose game has a [[VRFW.MatchChallenge]] for that row (the route
-- node's `Challenge`, or the challenge's `Games` + `Difficulties`) is focused, the blue list panel grows by one band
-- under its last row (band "match_challenge" of VRFW_RBC_PanelBand, the first one: the mod that sizes the panel
-- re-sizes it; the band's place is reserved on every row of such a piece, VRFW_RBC_PanelBandReserve, so the panel
-- keeps one height) and the band shows the
-- challenge's condition centred (its `Short` text, else its title: VRFW_MC.Status label), shrunk to the panel's width,
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
  local CLEAR_GET = 4034518619   -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)
  local FOCUS_GET = 2603265800   -- (layer) -> the focused row index (0-based)

  local LABEL = {
    LAYER = 375144984,           -- vrfw_mc_text
    INSTANCE = 0,
    TEXT_NODE = 378327766,       -- _text_cmd_back01
    TEXT_MESHES = {298211823 --[[_cmd_back_base01]], 2853207670 --[[_cmd_back_base01_add]]},
    TEXT_LEFT = -384, TEXT_MID_Y = 144,   -- the corner button's text node in its object (px)
    C = {
      OPEN = 629267548, VISIBLE = 711242136, SCALE = 3778714801, POS = 1389957207, GET_POS = 2834507455,
      MESH_VISIBLE = 3405944500, TEXT = 1083631230, LAYER_NUM = 1175615627,
      DRAW_PRIORITY = 1491630496,   -- CMND_SET_DRAW_PRIORITY (layer, instance, priority, children)
    },
    -- screen px (1920 x 1080, y down) of the battle-kind list of a normal piece as placed: the first row's centre
    -- line, the rows' spacing (vsroute01_15c `_atc_listNN`, 70 px apart), half a row's height, the gap between two
    -- rows, the panel's centre line (x)
    FIRST_ROW_MID_Y = 442, ROW_STEP = 70, ROW_HALF_HEIGHT = 30, ROW_GAP = 11, PANEL_MID_X = 436,
    -- the band under the last row: its height (the panel grows by ROW_GAP + BAND_HEIGHT), the text's widest box
    BAND_HEIGHT = 44, TEXT_MAX_WIDTH = 540,
    -- text scale: the largest, the smallest; the width of one Latin character at scale 1 (a CJK one counts twice)
    MAX_SCALE = 0.8, MIN_SCALE = 0.45, CHAR_WIDTH = 12.5,
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

  local function instance_count()
    local n = M(LABEL.C.LAYER_NUM, LABEL.LAYER)
    return type(n) == "number" and n or 0
  end

  -- width units of a text (a byte sequence of 3+ bytes = a CJK glyph, 2 units)
  local function text_units(s)
    local units, i, n = 0, 1, string.len(s)
    while i <= n do
      local b = string.byte(s, i)
      local len = b >= 0xF0 and 4 or (b >= 0xE0 and 3 or (b >= 0xC0 and 2 or 1))
      units = units + (len >= 3 and 2 or 1)
      i = i + len
    end
    return units
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
    local width_at_one = math.max(text_units(status.label), 1) * LABEL.CHAR_WIDTH
    local scale = math.max(LABEL.MIN_SCALE, math.min(LABEL.MAX_SCALE, LABEL.TEXT_MAX_WIDTH / width_at_one))
    local left = LABEL.PANEL_MID_X - width_at_one * scale / 2
    local last_row_mid = LABEL.FIRST_ROW_MID_Y + LABEL.ROW_STEP * (math.max(row_count, 1) - 1)
    local y = last_row_mid + LABEL.ROW_HALF_HEIGHT + LABEL.ROW_GAP + LABEL.BAND_HEIGHT / 2
    if VRFW_RBC_PanelBandTop ~= nil then
      local ok, top = pcall(VRFW_RBC_PanelBandTop, BAND_ID)
      if ok and type(top) == "number" then
        y = top + LABEL.ROW_GAP + LABEL.BAND_HEIGHT / 2
      end
    end
    local colour = status.ok and LABEL.COLOUR_MET or LABEL.COLOUR_UNMET
    for _, mesh in ipairs(LABEL.TEXT_MESHES) do
      M(LABEL.C.MESH_VISIBLE, LABEL.LAYER, mesh, false, k)
    end
    M(LABEL.C.TEXT, LABEL.LAYER, LABEL.TEXT_NODE, colour .. status.label .. LABEL.COLOUR_RESET, k)
    M(LABEL.C.SCALE, LABEL.LAYER, scale, scale, 1, k)
    LABEL.x, LABEL.y = left - LABEL.TEXT_LEFT * scale, -y - LABEL.TEXT_MID_Y * scale
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
