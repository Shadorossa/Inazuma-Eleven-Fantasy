-- BetterMenu (mod better_menu, prefix BetterMenu): the mode header of the main menu over the clubhouse
-- (title_menu_2; docs/game/mods/better-menu.md §29). While the menu scene is up, the top-left corner shows the game's
-- area-name banner of the Chronicle map (vsroute00_03_area_name_plate, copied as better_menu_mode_header by
-- content\menus\title_mode_header.toml): its translucent blue band with the hexagon pattern carries the focused mode's
-- name (white, the banner's own text node; the band stretches with the name as on the map), and over the band's top
-- edge the scene's name in yellow (text key better_menu.scene_caption). The banner's baked area title is hidden. The
-- caption and the L2 / R2 glyphs of the active device (left of the name and after it) are texts of the layer
-- better_menu_mode_texts (the framework's text object vrfw_mp_label). The header follows the mode row's focus (also
-- when it moves by L2 / R2), keeps the last mode while the lower row has the focus, and replays the banner's opening
-- on each mode change. The scene declares mode_label = false, so the framework draws no name of its own. On the
-- scene's home entry (game param vrfw_menu_scene_home, docs/game/mods/better-menu.md §39) the whole header is hidden;
-- it opens again on the first mode shown. No engine call at load time.
-- Driven by events, as the game's own headers (no per-frame checks): the mode row's focus change (OnChangeFocus) draws
-- the focused mode; the scene's home entry (VRFW_MenuScene.On "home_changed"), and the menus that cover the title
-- (BetterMenu.ModeHeader.Cover(owner, on): the Competition list, the team drawer) hide it while any covers it and show
-- it again, with the banner's opening, when the last one leaves. Step only runs the texts' slide-in after an opening.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
if BetterMenu.ModeHeader == nil then
  local function Crc(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
      crc = bit32.bxor(crc, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then
          crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
        else
          crc = bit32.rshift(crc, 1)
        end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end

  local Header = {
    ID = "better_menu.mode_header",
    LOG = Crc("CMND_EVT_LOG"),
    -- the banner (instance 0)
    BANNER = Crc("better_menu_mode_header"),
    NAME_NODE = Crc("_text_area_name01"),          -- the white line: left edge x 88, centre line y 100 in the layout
    TITLE_MESH = Crc("_area_name_title01"),        -- the baked area title of the Chronicle map: hidden
    BAND_SET = Crc("area"),                        -- the banner's animation set and its band stretch ("size")
    BAND_ANIM = Crc("size"),
    BAND_MIN_TEXT = 363,                           -- the banner's text plate range (its CMenuTextPlateUpdateProperty)
    BAND_MAX_TEXT = 540,
    -- the texts: 0 = the scene's caption, 1 = the L2 glyph, 2 = the R2 glyph
    TEXTS = Crc("better_menu_mode_texts"),
    TEXT_NODE = Crc("_text_cmd_back01"),           -- vrfw_mp_label's text node (the corner button's)
    TEXT_PLATES = { Crc("_cmd_back_base01"), Crc("_cmd_back_base01_add") },
    TEXT_LEFT = -384,                              -- the text node's left edge in its object (px)
    TEXT_MID_Y = 144,                              -- its centre line
    CAPTION_STYLE = Crc("fs2_48_y_lc_2d3_001_sclw"), -- yellow (255, 226, 63) with a 4 px blue outline (0, 22, 148)
    CAPTION_KEY = "better_menu.scene_caption",
    CAPTION_FALLBACK = "",
    PREV_GLYPH = "<CMD_FUNCL2>",
    NEXT_GLYPH = "<CMD_FUNCR2>",
    -- placement (screen px, origin top left, y down); the banner layout is drawn at its own origin plus TOP
    TOP = 12,                                      -- the whole banner this much lower than on the Chronicle map
    NAME_LEFT = 88,
    NAME_MID_Y = 100,
    CAPTION_LEFT = 40,                             -- where the map's baked title starts
    CAPTION_MID_Y = 50,                            -- its centre line, over the band's top edge (y 54)
    CAPTION_SCALE = 0.62,                          -- the 50 px style down to about 31 px (the map title's height)
    GLYPH_SCALE = 0.8,                             -- the 38 px label down to about 30 px
    GLYPH_GAP = 12,                                -- px between a glyph and the name
    ENTER_FRAMES = 10,                             -- the texts' slide-in with the banner's opening
    ENTER_DISTANCE = 120,
    -- engine
    MODE_ROW = Crc("title00_07_item_button_upper"),
    DRAWER_UP = Crc("better_menu_team_over_scene"), -- game param: the roster is open over the room
    PARAM_HAS = 2947612279,                         -- (key) -> set
    TEXT_GET = 4074371074,                          -- CMND_TEXT_GET (id) -> text
    TEXT_GET_KEY = 459261927,                       -- CMND_VRFW_TEXT_GET (key) -> text
    OPEN_LAYER = 629267548,                         -- (layer, instance): plays the layer's opening
    VISIBLE = 711242136,                            -- (layer, instance, on)
    TEXT = 1083631230,                              -- CMND_SET_MENU_TEXT_STRING (layer, node, text, instance)
    TEXT_STYLE = 2333948100,                        -- (layer, instance, node, style)
    TEXT_ALPHA = 1126837159,                        -- CMND_SET_MENU_TEXT_ALPHA (layer, instance, node, alpha)
    TEXT_SIZE = 3549540977,                         -- CMND_GET_MENU_TEXT_RECT_SIZE (layer, instance, node) -> width, height
    NODE_SCALE = 2885415772,                        -- (layer, instance, node, width, height): a text node's box
    MESH_VISIBLE = 3405944500,                      -- (layer, mesh, on, instance)
    ANIM_SET_FRAMES = 112302847,                    -- (layer, instance, set) -> frames (the map's UpdateRouteNameText)
    ANIM_PLAY = 541357333,                          -- (layer, animation, frames, instance)
    ANIM_RATE = 1595998683,                         -- (layer, animation, instance, rate, 0, true, set)
    POS = 1389957207,                               -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, instance): y up
    SCALE = 3778714801,                             -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, instance)
    LAYER_NUM = 1175615627,                         -- (layer) -> instances
  }
  local state = {
    shown = nil, opened = false, mode = nil, has_banner = nil, text_count = nil, texts_open = {},
    name_width = 0, glyph_width = { 0, 0 }, enter = nil, home = false, focus_mode = nil,
  }

  local function Log(...)
    pcall(funcLuaCommand, Header.LOG, "better_menu", "mode_header", ...)
  end

  local function M(...)
    local r = table.pack(pcall(funcLuaMenuCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function F(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if not r[1] then return nil end
    return table.unpack(r, 2, r.n)
  end

  local function HasBanner()
    if state.has_banner == nil then
      local n = M(Header.LAYER_NUM, Header.BANNER)
      state.has_banner = type(n) == "number" and n > 0
      local t = M(Header.LAYER_NUM, Header.TEXTS)
      state.text_count = type(t) == "number" and t or 0
      if not state.has_banner then Log("no layer better_menu_mode_header in this menu: no mode header") end
      if state.text_count < 3 then
        Log("better_menu_mode_texts has", state.text_count, "instance(s) (3 wanted): caption / glyphs left out")
      end
    end
    return state.has_banner
  end

  -- the mode's plain name (no icons): the title's name text id, else its display name without markup
  local function ModeName(idx)
    if type(GetTextNameItemName) == "function" then
      local ok, id = pcall(GetTextNameItemName, idx, true)
      if ok and type(id) == "number" then
        local t = F(Header.TEXT_GET, id)
        if type(t) == "string" and t ~= "" then return t end
      elseif ok and type(id) == "string" and id ~= "" then
        return id
      end
    end
    if type(GetTextItemName) == "function" then
      local ok, t = pcall(GetTextItemName, idx, true)
      if ok and type(t) == "string" then
        t = string.gsub(t, "%[[^%]]*%]", "")
        t = string.gsub(t, "<[^>]*>", "")
        return (string.gsub(t, "^%s*(.-)%s*$", "%1"))
      end
    end
    return ""
  end

  local function Caption()
    local t = F(Header.TEXT_GET, Crc(Header.CAPTION_KEY))
    if type(t) ~= "string" or t == "" then t = F(Header.TEXT_GET_KEY, Header.CAPTION_KEY) end
    if type(t) ~= "string" then t = Header.CAPTION_FALLBACK end
    return t
  end

  local function TextWidth(layer, k, node)
    local w = M(Header.TEXT_SIZE, layer, k, node)
    if type(w) ~= "number" or w < 0 then return 0 end
    return w
  end

  -- a text of better_menu_mode_texts: its left edge x, centre line y (screen px), scale, alpha
  local function PlaceText(k, x, y, scale, alpha)
    if k >= (state.text_count or 0) or not state.texts_open[k] then return end
    M(Header.SCALE, Header.TEXTS, scale, scale, 1, k)
    M(Header.POS, Header.TEXTS, x - Header.TEXT_LEFT * scale, -y - Header.TEXT_MID_Y * scale, 0, k)
    M(Header.TEXT_ALPHA, Header.TEXTS, k, Header.TEXT_NODE, alpha)
  end

  local function OpenText(k, text, style)
    if k >= (state.text_count or 0) then return end
    if not state.texts_open[k] then
      state.texts_open[k] = true
      M(Header.OPEN_LAYER, Header.TEXTS, k)
      M(Header.NODE_SCALE, Header.TEXTS, k, Header.TEXT_NODE, 1600, 76)   -- wider than any line: never squeezed
      if style then M(Header.TEXT_STYLE, Header.TEXTS, k, Header.TEXT_NODE, style) end
    end
    for _, m in ipairs(Header.TEXT_PLATES) do M(Header.MESH_VISIBLE, Header.TEXTS, m, false, k) end
    M(Header.TEXT, Header.TEXTS, Header.TEXT_NODE, text, k)
    M(Header.VISIBLE, Header.TEXTS, k, true)
  end

  -- the texts at the banner: slid left and faded while the banner opens
  local function PlaceTexts()
    local t = 1
    if state.enter ~= nil then
      t = math.min(1, state.enter / Header.ENTER_FRAMES)
    end
    local dx = -(1 - t) * (1 - t) * Header.ENTER_DISTANCE
    local top = Header.TOP
    PlaceText(0, Header.CAPTION_LEFT + dx, Header.CAPTION_MID_Y + top, Header.CAPTION_SCALE, t)
    local prev = state.glyph_width[1] * Header.GLYPH_SCALE
    PlaceText(1, Header.NAME_LEFT - Header.GLYPH_GAP - prev + dx, Header.NAME_MID_Y + top, Header.GLYPH_SCALE, t)
    PlaceText(2, Header.NAME_LEFT + state.name_width + Header.GLYPH_GAP + dx, Header.NAME_MID_Y + top,
      Header.GLYPH_SCALE, t)
  end

  local function Hide()
    if state.shown then
      if state.opened then M(Header.VISIBLE, Header.BANNER, 0, false) end
      for k = 0, 2 do
        if state.texts_open[k] then M(Header.VISIBLE, Header.TEXTS, k, false) end
      end
    end
    state.shown, state.enter = false, nil
  end

  -- the band's length for the name and the R2 glyph after it, as the map's UpdateRouteNameText does for its names
  local function StretchBand()
    local room = state.name_width + Header.GLYPH_GAP + state.glyph_width[2] * Header.GLYPH_SCALE
    local rate = (room - Header.BAND_MIN_TEXT) / (Header.BAND_MAX_TEXT - Header.BAND_MIN_TEXT)
    rate = math.max(0, math.min(1, rate))
    local frames = M(Header.ANIM_SET_FRAMES, Header.BANNER, 0, Header.BAND_SET)
    M(Header.ANIM_PLAY, Header.BANNER, Header.BAND_ANIM, frames, 0)
    M(Header.ANIM_RATE, Header.BANNER, Header.BAND_ANIM, 0, 1 - rate, 0, true, Header.BAND_SET)
    return rate
  end

  local function Draw(idx)
    local name = ModeName(idx)
    local first = not state.opened
    -- (re)open: the banner slides in from the left (its Open animation) on the first show and on each mode change
    state.opened = true
    M(Header.OPEN_LAYER, Header.BANNER, 0)
    M(Header.MESH_VISIBLE, Header.BANNER, Header.TITLE_MESH, false, 0)
    M(Header.POS, Header.BANNER, 0, -Header.TOP, 0, 0)
    M(Header.TEXT, Header.BANNER, Header.NAME_NODE, name, 0)
    M(Header.VISIBLE, Header.BANNER, 0, true)
    state.name_width = TextWidth(Header.BANNER, 0, Header.NAME_NODE)
    if state.name_width <= 0 then state.name_width = 20 * #name end
    if first or not state.shown then
      OpenText(0, Caption(), Header.CAPTION_STYLE)
      OpenText(1, Header.PREV_GLYPH, nil)
      OpenText(2, Header.NEXT_GLYPH, nil)
      for k = 1, 2 do
        if state.texts_open[k] then
          local w = TextWidth(Header.TEXTS, k, Header.TEXT_NODE)
          state.glyph_width[k] = w > 0 and w or 38
        end
      end
    end
    local rate = StretchBand()
    state.enter = 0
    PlaceTexts()
    state.shown, state.mode = true, idx
    Log("mode", idx, name, "width", state.name_width, "band rate", rate, first and "(open)" or "(replay)")
  end

  -- the header's one state: covered by these owners (any = hidden), the home entry, the focused mode
  local covers = {}
  local function Covered()
    return next(covers) ~= nil or state.home == true
  end

  -- the title's OnChangeFocus: the mode row's focused mode (a focus on another row keeps the last mode)
  local function ReadFocus()
    if type(GetSelectItemLayerName) == "function" and type(GetSelectItemIdx) == "function" then
      local okl, layer = pcall(GetSelectItemLayerName)
      local oki, i = pcall(GetSelectItemIdx)
      if okl and oki and layer == Header.MODE_ROW and type(i) == "number" then state.focus_mode = i end
    end
  end

  -- show the focused mode now (with the banner's opening) unless something covers the header
  local function Refresh(why)
    if not (type(VRFW_MenuSceneIsUp) == "function" and VRFW_MenuSceneIsUp()) or not HasBanner() then return end
    if Covered() then
      if state.shown then
        Hide()
        Log("header hidden:", why)
      end
      return
    end
    local idx = state.focus_mode
    if idx == nil then return end
    if idx ~= state.mode or not state.shown then
      Draw(idx)
      Log("header shown:", why)
    end
  end

  -- a menu over the title covers the header (on) or leaves (off); owner = who asks (a name of its own)
  local function Cover(owner, on)
    owner = tostring(owner)
    if (covers[owner] == true) == (on == true) then return end
    covers[owner] = on and true or nil
    Refresh((on and "covered by " or "uncovered by ") .. owner)
  end

  -- the texts' slide-in after an opening (the only per-frame work, and only while it runs)
  local function Step()
    if state.enter == nil then return end
    state.enter = state.enter + 1
    PlaceTexts()
    if state.enter >= Header.ENTER_FRAMES then state.enter = nil end
  end

  BetterMenu.ModeHeader = { Step = Step, Cover = Cover }

  -- the framework's scene events (VRFW_MenuScene.On, lua/menu/title_menu_2/150_menu_scene.lua): the home entry, and
  -- the mode row's focus moved by the framework (mode keys, a restore; index -1 = the home entry)
  if VRFW_MenuScene and VRFW_MenuScene.On then
    VRFW_MenuScene.On("home_changed", Header.ID .. ".home", function(on)
      state.home = on == true
      if on then Refresh("home entry") end
    end)
    VRFW_MenuScene.On("mode_focused", Header.ID .. ".mode", function(index)
      if type(index) == "number" and index >= 0 then
        state.focus_mode = index
        Refresh("mode focus")
      end
    end)
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", {
      id = Header.ID .. ".init",
      phase = "before",
      fn = function()
        state.shown, state.opened, state.mode, state.has_banner, state.text_count = nil, false, nil, nil, nil
        state.texts_open, state.enter, state.name_width, state.glyph_width = {}, nil, 0, { 0, 0 }
        state.home = type(VRFW_MenuSceneIsHome) == "function" and VRFW_MenuSceneIsHome() or false
        state.focus_mode = nil
        covers = {}
      end,
    })
    -- the mode row's focus moved (by the player, by L2 / R2 or by the framework): the header follows
    VRFW_Host.on("title_menu_2", "OnChangeFocus", {
      id = Header.ID .. ".focus",
      phase = "after",
      fn = function()
        local ok, err = pcall(function() ReadFocus() Refresh("focus") end)
        if not ok then Log("error", tostring(err)) end
      end,
    })
    VRFW_Host.on("title_menu_2", "Step", {
      id = Header.ID .. ".step",
      phase = "after",
      priority = 10,
      fn = function()
        local ok, err = pcall(Step)
        if not ok then Log("error", tostring(err)) end
      end,
    })
  end
end
