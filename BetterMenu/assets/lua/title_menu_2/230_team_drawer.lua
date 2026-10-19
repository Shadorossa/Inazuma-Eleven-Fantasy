-- BetterMenu (mod better_menu, prefix BetterMenu): the team drawer of the main menu over the clubhouse (title_menu_2;
-- docs/game/mods/better-menu.md §28, §32). While the menu scene is up:
--   * a small button at the right edge, mid height: the game's team dock icon (icon_header_teamdock01 of the hub header's atlas,
--     on a copy of the 36 px quad cmn01_10) and the Y glyph of the active device (<CMD_FUNC3>);
--   * Y (the title's CMD_FUNC3 = its flavour balloon function 0xE4DDCBC5, taken over while the scene is up) opens the
--     game's own team roster («Plantilla de equipo»: soccer_team_dock_menu under its header menu
--     team_dock_common_top_menu) ON TOP of the clubhouse: the camera moves to the scene's shot `team_overview`, the
--     title's layers hide, the band (the roster's own blue background cut to a shape with slanted top and bottom edges:
--     assets\images\menu\20_cmn\better_menu_team_band\) slides in from the right and the two retail menus open over it
--     with no black fade (assets\lua\soccer_team_dock_menu\230_team_drawer_no_fade.lua drops the roster's own
--     fade-in). The header menu's full-screen background, header strip and team icon and the framework's top bar stay
--     hidden. Everything of the roster is the game's own: team sets (L1 / R1), tactics, formation, kit, coach, bench,
--     swaps, player pages. The roster was opened once under the scene's black settle already
--     (assets\lua\rpg_info_window\230_team_preload.lua);
--   * the roster's own B closes it (it is not the scene's root menu, so its back closes it without the game reset of
--     the title's «Mi equipo»): the header menu is closed, the band slides out, the title's layers come back, the
--     camera goes back to the mode's shot and the focus to the row it came from.
-- Input while open: the off-screen anchor layer better_menu_team_anchor holds the title's control focus and every
-- title callback that would act (keys, A, B, focus) is swallowed, so only the roster reacts.
-- Any step that fails (a menu that does not open in time) closes what opened and gives the title back.
-- Layers: content\menus\title_team_drawer.toml. No engine call at load time.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
if BetterMenu.TeamDrawer == nil then
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

  local Drawer = {
    ID = "better_menu.team_drawer",
    LOG = Crc("CMND_EVT_LOG"),
    -- layers (content\menus\title_team_drawer.toml)
    BAND = Crc("better_menu_team_band"),            -- the band: one quad showing the band's picture
    TEXT = Crc("better_menu_team_text"),            -- vrfw_mp_label: 0 the button's Y glyph
    ICON = Crc("better_menu_team_icon"),
    ANCHOR = Crc("better_menu_team_anchor"),
    TEXT_BUTTON = 0,
    -- the title
    MODE_ROW = Crc("title00_07_item_button_upper"),
    BALLOON_FUNCTION = 3839740869,                  -- 0xE4DDCBC5: the title's Y (CMD_FUNC3) = its flavour balloon toggle
    DRAWER_FUNCTION = Crc("better_menu_team_drawer"), -- the anchor's B / Y rows
    -- param read by the roster's patch: no fade-in of its own
    OVER_SCENE = Crc("better_menu_team_over_scene"),
    -- param of the preload under the settle (a roster left from it is closed at the title's start)
    PRELOAD = Crc("better_menu_team_preload"),
    -- the framework's top bar: hidden while this param is set (docs/framework/top-bar.md §17)
    TOP_BAR_HIDDEN = Crc("vrfw_top_bar_hidden"),
    -- the header menu's layers kept hidden while the roster is open over the room: its full-screen background, its
    -- header strip (title and shortcut bar) and the team icon at the top
    HEADER_LAYERS = { Crc("mainmenu90_00_background"), Crc("mainmenu90_01_header"), Crc("mainmenu90_31_doc_item"),
      Crc("vroad01_51_tournament_team_icon") },
    -- the menu scene (VRFW)
    SCENE_STATE = 2588710643,                       -- CMND_VRFW_MENU_SCENE_STATE () -> state, key, …
    SCENE_SHOT = 2012234360,                        -- CMND_VRFW_MENU_SCENE_SHOT (key, tile id | shot name)
    FOLLOW_CAMERA = Crc("CMND_VRFW_MENU_SCENE_FOLLOW_CAMERA"),   -- (camera name, on)
    MENU_CAMERA = "MenuCamera",                     -- the camera a sub-screen's 3D model makes the 3D view
    OVERVIEW_SHOT = "team_overview",
    -- the game's team roster
    ROSTER_MENU = 937147172,                        -- soccer_team_dock_menu
    HEADER_MENU = 91676902,                         -- team_dock_common_top_menu (header, button guide, background)
    OPEN_MENU = 433545986,                          -- CMND_OPEN_MENU_OBJECT (menu)
    CLOSE_MENU = 320421347,                         -- CMND_CLOSE_MENU_OBJECT (menu)
    MENU_EXISTS = 2231168902,                       -- CMND_IS_EXIST_MENU_OBJECT (menu) (menu command)
    -- commands
    PARAM_HAS = 2947612279, PARAM_SET = 3860611758, PARAM_CLEAR = 3363400568,
    OPEN = 629267548, VISIBLE = 711242136, LAYER_NUM = 1175615627,   -- VISIBLE (layer, instance, on[, menu])
    IS_OPEN_LAYER = 2640875187,                     -- (layer, instance)
    IS_VISIBLE = 1262717583,                        -- CMND_IS_LAYER_VISIBLE (layer, instance)
    POS = 1389957207, SCALE = 3778714801, MESH_VISIBLE = 3405944500,
    TEXT_SET = 1083631230, TEXT_SIZE = 3549540977, NODE_SCALE = 2885415772, TEXT_ALPHA = 1126837159,
    DRAW_PRIORITY = 1491630496,                     -- (layer, instance, priority, children)
    SPRITE = 558735651,                             -- (layer, texture, sprite, old sprite, 0, instance)
    CTRL_FOCUS = 3518307824,                        -- (layer, on)
    FOCUS_MARK = 1778826357,                        -- (layer, instance, true)
    SOUND = 1917805374, SOUND_OPEN = 3848881948 --[[sy0000]], SOUND_CLOSE = 2500047763 --[[sy0005]],
    -- the button's icon
    -- the icon is the layer's own atlas (the team dock icon with its corners restored, 360 x 328: the sheet 360 x 248
    -- with 40 px above and below), read by the layer's layout: no sprite swap
    QUAD = 36,                                      -- the cmn01_10 quad's own size (px)
    ICON_WIDTH = 96, ICON_HEIGHT = 87,              -- on screen (px): the sheet keeps its 96 x 66, the restored corners above and below
    BUTTON_X = 1848, BUTTON_Y = 540,                -- the icon's centre (screen px from the top left): right edge (24 px margin), mid height
    GLYPH_GAP = 12,                                 -- between the Y glyph and the icon
    GLYPH = "<CMD_FUNC3>",
    -- the label object vrfw_mp_label (the corner button cmn03_01): text node, plates, left edge, centre line
    LABEL_NODE = 378327766, LABEL_PLATES = { 298211823, 2853207670 }, LABEL_LEFT = -384, LABEL_MID_Y = 144,
    LABEL_BOX_WIDTH = 1600, LABEL_BOX_HEIGHT = 76,
    GLYPH_SCALE = 0.8, PRIORITY_TEXT = 560, PRIORITY_ICON = 530,
    -- the band's box (screen px, y down): its picture (research/scripts/better_menu_team_band_build.py) is full width,
    -- y 78 .. 1046, the shape (top edge 122 -> 78, bottom edge 1002 -> 1046) in its transparency
    BAND_TOP = 78, BAND_BOTTOM = 1046,
    SLIDE_FRAMES = 8,
    WAIT_FRAMES = 150,                              -- the most frames a step waits (a menu to open / close)
  }

  -- the title's layers hidden while the roster is open (they share the roster's draw priorities 199-205): the game's
  -- own and the ones the framework and this mod add; a name the menu lacks answers 0 instances and is skipped
  local TITLE_LAYERS = {
    "title02_00_title_bg_2", "title02_01_title_logo_2", "title02_02_item_atc_locator_2", "title02_03_item_name_2",
    "title00_07_item_button_upper", "title00_07_item_button_lower", "cmn01_13_new_icon_middle",
    "title02_06_information_banner", "info01_03_banner_list_item", "title02_20_dlc_buy_btn_atc_locator",
    "title02_21_dlc_buy_btn", "title02_21_sw2_upgrade_pass_btn", "title00_08_copyright", "title00_10_inazuma_post",
    "title02_04_version", "title02_04_version_ps", "title02_07_victory_counter", "title02_12_victory_counter_detail",
    "title02_08_explanation_button_guide", "title02_09_flavor_balloon_upper", "title02_09_flavor_balloon_else",
    "cmn05_01_coursor", "title02_10_my_team_banner", "title02_11_avatar_banner", "cmn01_13_banner_new_icon_middle",
    "title00_14_avatar_make", "cmn01_21_my_team_banner_loading_icon", "cmn01_21_avatar_banner_loading_icon",
    "title02_22_dlc_logo", "title02_22_dlc_logo_for_balloon", "title02_23_dlc_logo_simple",
    "title02_24_dlc_logo_simple_balloon", "title00_15_vroad_tournament_info_balloon",
    "vroad01_72_vroad_tournament_notice_button_guide",
    "vrfw_ms_label", "vrfw_ms_frame", "evt_vrfw_title_word",
    "better_menu_mode_header", "better_menu_tile_plate",
  }

  -- phase: closed | sliding_in | opening_header | opening_roster | open | closing_header | sliding_out
  local state = { phase = "closed", frame = 0, opened = {}, base = {}, back_layer = nil, back_index = nil, mode = nil,
    has_layers = nil, button_shown = false, title_layers = nil, shown = {}, band_open = false }

  local function Log(...)
    pcall(funcLuaCommand, Drawer.LOG, "better_menu", "team_drawer", ...)
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

  local function Instances(layer)
    local n = M(Drawer.LAYER_NUM, layer)
    return type(n) == "number" and n or 0
  end

  local function HasLayers()
    if state.has_layers == nil then
      state.has_layers = Instances(Drawer.BAND) >= 1 and Instances(Drawer.TEXT) >= 1
        and Instances(Drawer.ICON) >= 1 and Instances(Drawer.ANCHOR) >= 1
      if not state.has_layers then Log("the drawer's layers are not in this menu: no team drawer") end
    end
    return state.has_layers
  end

  local function SceneUp()
    return (type(VRFW_MenuSceneIsUp) == "function" and VRFW_MenuSceneIsUp())
  end

  local function MenuExists(menu)
    return M(Drawer.MENU_EXISTS, menu) == true
  end

  local function Open(layer, k, priority)
    local key = layer .. ":" .. k
    if not state.opened[key] then
      state.opened[key] = true
      M(Drawer.OPEN, layer, k)
    end
    if priority then M(Drawer.DRAW_PRIORITY, layer, k, priority, true) end
  end

  local function Place(layer, k, dx)
    local b = state.base[layer .. ":" .. k]
    if b then M(Drawer.POS, layer, b[1] + dx, b[2], 0, k) end
  end

  -- a text on the label layer, its left edge at x, its centre line at y (screen px)
  local function TextLine(k, s, scale, x, y)
    Open(Drawer.TEXT, k, Drawer.PRIORITY_TEXT)
    for _, mesh in ipairs(Drawer.LABEL_PLATES) do M(Drawer.MESH_VISIBLE, Drawer.TEXT, mesh, false, k) end
    M(Drawer.NODE_SCALE, Drawer.TEXT, k, Drawer.LABEL_NODE, Drawer.LABEL_BOX_WIDTH, Drawer.LABEL_BOX_HEIGHT)
    M(Drawer.SCALE, Drawer.TEXT, 1, 1, 1, k)
    M(Drawer.TEXT_SET, Drawer.TEXT, Drawer.LABEL_NODE, s, k)
    local width = M(Drawer.TEXT_SIZE, Drawer.TEXT, k, Drawer.LABEL_NODE)
    if type(width) ~= "number" or width <= 0 then width = 14 * #s end
    M(Drawer.SCALE, Drawer.TEXT, scale, scale, 1, k)
    state.base[Drawer.TEXT .. ":" .. k] = { x - Drawer.LABEL_LEFT * scale, -y - Drawer.LABEL_MID_Y * scale }
    M(Drawer.TEXT_ALPHA, Drawer.TEXT, k, Drawer.LABEL_NODE, 1)
    M(Drawer.VISIBLE, Drawer.TEXT, k, s ~= "")
    return width * scale
  end

  -- the bottom-right button: the team icon and the Y glyph, while the scene is up and the drawer closed
  local function DrawButton(on)
    if on == state.button_shown then return end
    state.button_shown = on
    if not on then
      if state.opened[Drawer.ICON .. ":0"] then M(Drawer.VISIBLE, Drawer.ICON, 0, false) end
      if state.opened[Drawer.TEXT .. ":" .. Drawer.TEXT_BUTTON] then M(Drawer.VISIBLE, Drawer.TEXT, Drawer.TEXT_BUTTON, false) end
      return
    end
    Open(Drawer.ICON, 0, Drawer.PRIORITY_ICON)
    M(Drawer.SCALE, Drawer.ICON, Drawer.ICON_WIDTH / Drawer.QUAD, Drawer.ICON_HEIGHT / Drawer.QUAD, 1, 0)
    M(Drawer.POS, Drawer.ICON, Drawer.BUTTON_X, -Drawer.BUTTON_Y, 0, 0)
    M(Drawer.VISIBLE, Drawer.ICON, 0, true)
    -- the glyph: its right edge GLYPH_GAP px left of the icon
    local width = TextLine(Drawer.TEXT_BUTTON, Drawer.GLYPH, Drawer.GLYPH_SCALE, 0, Drawer.BUTTON_Y)
    local left = Drawer.BUTTON_X - Drawer.ICON_WIDTH / 2 - Drawer.GLYPH_GAP - width
    state.base[Drawer.TEXT .. ":" .. Drawer.TEXT_BUTTON] = { left - Drawer.LABEL_LEFT * Drawer.GLYPH_SCALE,
      -Drawer.BUTTON_Y - Drawer.LABEL_MID_Y * Drawer.GLYPH_SCALE }
    Place(Drawer.TEXT, Drawer.TEXT_BUTTON, 0)
    Log("button shown at", Drawer.BUTTON_X, Drawer.BUTTON_Y)
  end

  ---------------------------------------------------------------------------------------------------------------------
  -- the title's layers and the header menu's
  ---------------------------------------------------------------------------------------------------------------------
  local function TitleLayers()
    if state.title_layers == nil then
      state.title_layers = {}
      for _, name in ipairs(TITLE_LAYERS) do
        local layer = Crc(name)
        local n = Instances(layer)
        if n > 0 then table.insert(state.title_layers, { layer = layer, count = n }) end
      end
    end
    return state.title_layers
  end

  -- at the open: remember which instances are shown (to show them again at the close)
  local function RememberTitle()
    state.shown = {}
    for _, e in ipairs(TitleLayers()) do
      for k = 0, e.count - 1 do
        if M(Drawer.IS_OPEN_LAYER, e.layer, k) == true and M(Drawer.IS_VISIBLE, e.layer, k) == true then
          table.insert(state.shown, { e.layer, k })
        end
      end
    end
  end

  -- every frame while open (after the other title scripts' Step): whatever they showed is hidden again; the header
  -- menu's own layers too (its scripts and the roster's show them)
  local function HideTitle()
    for _, e in ipairs(TitleLayers()) do
      for k = 0, e.count - 1 do
        if M(Drawer.IS_OPEN_LAYER, e.layer, k) == true then M(Drawer.VISIBLE, e.layer, k, false) end
      end
    end
    if MenuExists(Drawer.HEADER_MENU) then
      for _, layer in ipairs(Drawer.HEADER_LAYERS) do M(Drawer.VISIBLE, layer, 0, false, Drawer.HEADER_MENU) end
    end
  end

  local function RestoreTitle()
    for _, s in ipairs(state.shown) do M(Drawer.VISIBLE, s[1], s[2], true) end
    Log("title layers shown again:", #state.shown)
    state.shown = {}
  end

  ---------------------------------------------------------------------------------------------------------------------
  -- the band: one quad over its box, the picture carries the shape
  ---------------------------------------------------------------------------------------------------------------------
  local function DrawBand(dx)
    if not state.band_open then
      state.band_open = true
      M(Drawer.OPEN, Drawer.BAND, 0)
    end
    local height = Drawer.BAND_BOTTOM - Drawer.BAND_TOP
    M(Drawer.SCALE, Drawer.BAND, 1920 / Drawer.QUAD, height / Drawer.QUAD, 1, 0)
    M(Drawer.POS, Drawer.BAND, 960 + dx, -(Drawer.BAND_TOP + height / 2), 0, 0)
    M(Drawer.VISIBLE, Drawer.BAND, 0, true)
  end

  local function HideBand()
    if state.band_open then M(Drawer.VISIBLE, Drawer.BAND, 0, false) end
  end

  local function SlideOffset()
    local t = math.min(1, state.frame / Drawer.SLIDE_FRAMES)
    local k = t * t * (3 - 2 * t)
    if state.phase == "sliding_in" then return (1 - k) * 1920 end
    if state.phase == "sliding_out" then return k * 1920 end
    return 0
  end

  ---------------------------------------------------------------------------------------------------------------------
  -- open / close
  ---------------------------------------------------------------------------------------------------------------------
  local function SceneKey()
    local st, key = F(Drawer.SCENE_STATE)
    if st == "up" and type(key) == "string" and key ~= "" then return key end
    return nil
  end

  local function SetPhase(phase, why)
    Log("phase", state.phase, "->", phase, why or "", "after", state.frame, "frame(s)")
    state.phase, state.frame = phase, 0
    if BetterMenu.ModeHeader and BetterMenu.ModeHeader.Cover then BetterMenu.ModeHeader.Cover("team_drawer", phase ~= "closed") end
  end

  local function OpenDrawer()
    local key = SceneKey()
    if key == nil or not HasLayers() then return false end
    if MenuExists(Drawer.ROSTER_MENU) or MenuExists(Drawer.HEADER_MENU) then
      Log("a team roster is already open: not opened")
      return false
    end
    local okl, layer = pcall(GetSelectItemLayerName)
    local oki, idx = pcall(GetSelectItemIdx)
    state.back_layer = okl and layer or Drawer.MODE_ROW
    state.back_index = oki and type(idx) == "number" and idx or 0
    -- the input: the anchor takes the title's control focus
    Open(Drawer.ANCHOR, 0)
    M(Drawer.POS, Drawer.ANCHOR, -4000, 4000, 0, 0)
    M(Drawer.CTRL_FOCUS, state.back_layer, false)
    M(Drawer.CTRL_FOCUS, Drawer.ANCHOR, true)
    M(Drawer.FOCUS_MARK, Drawer.ANCHOR, 0, true)
    RememberTitle()
    DrawButton(false)
    F(Drawer.PARAM_SET, Drawer.OVER_SCENE, 0, 1, 1)
    F(Drawer.PARAM_SET, Drawer.TOP_BAR_HIDDEN, 0, 1, 1)
    F(Drawer.SCENE_SHOT, key, Drawer.OVERVIEW_SHOT)
    -- the roster's sub-screens with a 3D model switch the 3D view to the menu camera: it takes the same pose
    Log("menu camera follows the shot:", tostring(F(Drawer.FOLLOW_CAMERA, Drawer.MENU_CAMERA, true)))
    F(Drawer.SOUND, Drawer.SOUND_OPEN)
    SetPhase("sliding_in", "Y: shot " .. Drawer.OVERVIEW_SHOT .. ", focus was " .. tostring(state.back_layer) .. " " .. state.back_index)
    return true
  end

  -- the title back: band out, layers, focus, camera
  local function GiveTitleBack(why)
    F(Drawer.FOLLOW_CAMERA, Drawer.MENU_CAMERA, false)
    F(Drawer.PARAM_CLEAR, Drawer.OVER_SCENE)
    F(Drawer.PARAM_CLEAR, Drawer.TOP_BAR_HIDDEN)
    F(Drawer.SOUND, Drawer.SOUND_CLOSE)
    M(Drawer.CTRL_FOCUS, Drawer.ANCHOR, false)
    M(Drawer.CTRL_FOCUS, state.back_layer, true)
    M(Drawer.FOCUS_MARK, state.back_layer, state.back_index, true)
    local key = SceneKey()
    if key and state.mode ~= nil and type(GetTitleMenuItemId) == "function" then
      local ok, item = pcall(GetTitleMenuItemId, state.mode, true)
      if ok and type(item) == "number" then
        F(Drawer.SCENE_SHOT, key, string.format("%.0f", item % 4294967296))
      end
    end
    SetPhase("sliding_out", why)
  end

  -- a step failed: close what opened, the title back
  local function Fail(why)
    Log("failed:", why, "- the title gets the focus back")
    if MenuExists(Drawer.ROSTER_MENU) then F(Drawer.CLOSE_MENU, Drawer.ROSTER_MENU) end
    if MenuExists(Drawer.HEADER_MENU) then F(Drawer.CLOSE_MENU, Drawer.HEADER_MENU) end
    GiveTitleBack("failed")
  end

  local function StepOpen()
    local p = state.phase
    if p == "sliding_in" then
      if state.frame >= Drawer.SLIDE_FRAMES then
        local ok = F(Drawer.OPEN_MENU, Drawer.HEADER_MENU)
        SetPhase("opening_header", "open team_dock_common_top_menu (" .. tostring(ok) .. ")")
      end
    elseif p == "opening_header" then
      if MenuExists(Drawer.HEADER_MENU) then
        local ok = F(Drawer.OPEN_MENU, Drawer.ROSTER_MENU)
        SetPhase("opening_roster", "open soccer_team_dock_menu (" .. tostring(ok) .. ")")
      elseif state.frame >= Drawer.WAIT_FRAMES then
        Fail("team_dock_common_top_menu did not open")
      end
    elseif p == "opening_roster" then
      if MenuExists(Drawer.ROSTER_MENU) then
        SetPhase("open", "the roster is up")
      elseif state.frame >= Drawer.WAIT_FRAMES then
        Fail("soccer_team_dock_menu did not open")
      end
    elseif p == "open" then
      if not MenuExists(Drawer.ROSTER_MENU) then
        if MenuExists(Drawer.HEADER_MENU) then F(Drawer.CLOSE_MENU, Drawer.HEADER_MENU) end
        SetPhase("closing_header", "the roster closed")
      end
    elseif p == "closing_header" then
      if not MenuExists(Drawer.HEADER_MENU) or state.frame >= Drawer.WAIT_FRAMES then
        GiveTitleBack("the header menu closed")
      end
    elseif p == "sliding_out" then
      if state.frame >= Drawer.SLIDE_FRAMES then
        HideBand()
        RestoreTitle()
        -- the roster's character models may have taken the people's: the framework asks the field's NPCs again
        if type(VRFW_MenuScenePeopleAgain) == "function" then VRFW_MenuScenePeopleAgain("the team roster closed") end
        SetPhase("closed", "done")
        return
      end
    end
  end

  local function Step()
    if state.phase == "closed" then
      if not SceneUp() then
        DrawButton(false)
        return
      end
      if not HasLayers() then return end
      -- the mode on screen (for the camera on close)
      local okl, layer = pcall(GetSelectItemLayerName)
      local oki, idx = pcall(GetSelectItemIdx)
      if okl and oki and layer == Drawer.MODE_ROW and type(idx) == "number" then state.mode = idx end
      DrawButton(true)
      return
    end
    state.frame = state.frame + 1
    StepOpen()
    if state.phase == "closed" then return end
    HideTitle()
    DrawBand(SlideOffset())
  end

  -- a roster left open by the preload under the settle (it should have closed before the title started)
  local function CloseLeftovers()
    if F(Drawer.PARAM_HAS, Drawer.PRELOAD) ~= true then return end
    F(Drawer.PARAM_CLEAR, Drawer.PRELOAD)
    F(Drawer.PARAM_CLEAR, Drawer.OVER_SCENE)
    F(Drawer.PARAM_CLEAR, Drawer.TOP_BAR_HIDDEN)
    local roster, header = MenuExists(Drawer.ROSTER_MENU), MenuExists(Drawer.HEADER_MENU)
    if roster then F(Drawer.CLOSE_MENU, Drawer.ROSTER_MENU) end
    if header then F(Drawer.CLOSE_MENU, Drawer.HEADER_MENU) end
    Log("preload left over at the title's start: roster", tostring(roster), "header", tostring(header), "closed")
  end

  BetterMenu.TeamDrawer = { Step = Step }

  local function Busy()
    return state.phase ~= "closed"
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", {
      id = Drawer.ID .. ".init",
      phase = "before",
      fn = function()
        pcall(funcLuaCommand, Drawer.PARAM_CLEAR, Drawer.OVER_SCENE)
        pcall(CloseLeftovers)
        state.phase, state.frame, state.opened, state.base, state.band_open = "closed", 0, {}, {}, false
        state.back_layer, state.back_index, state.mode, state.has_layers, state.button_shown = nil, nil, nil, nil, false
        state.title_layers, state.shown = nil, {}
      end,
    })
    VRFW_Host.on("title_menu_2", "Step", {
      id = Drawer.ID .. ".step",
      phase = "after",
      priority = 100,                   -- after the other title scripts (the menu scene, the mode header): hides last
      fn = function()
        local ok, err = pcall(Step)
        if not ok then Log("error", tostring(err)) end
      end,
    })
    -- Y: the roster instead of the flavour balloon while the scene is up; nothing else sees a key while it is open
    VRFW_Host.on("title_menu_2", "OnFunction", {
      id = Drawer.ID .. ".keys",
      phase = "around",
      priority = -20,                   -- outermost
      fn = function(nxt, a1, a2, ...)
        if Busy() then return end
        if a1 == Drawer.DRAWER_FUNCTION then return end
        if a1 == Drawer.BALLOON_FUNCTION and SceneUp() then
          local ok, opened = pcall(OpenDrawer)
          if ok and opened then return end
          if not ok then Log("open error", tostring(opened)) end
        end
        return nxt(a1, a2, ...)
      end,
    })
    VRFW_Host.on("title_menu_2", "OnChangeFocus", {
      id = Drawer.ID .. ".focus",
      phase = "around",
      priority = -20,
      fn = function(nxt, a1, ...)
        if a1 == Drawer.ANCHOR or Busy() then return end
        return nxt(a1, ...)
      end,
    })
    VRFW_Host.on("title_menu_2", "OnEnter", {
      id = Drawer.ID .. ".enter",
      phase = "around",
      priority = -20,
      fn = function(nxt, a1, ...)
        if Busy() or a1 == Drawer.ANCHOR then return end
        return nxt(a1, ...)
      end,
    })
    VRFW_Host.on("title_menu_2", "OnBack", {
      id = Drawer.ID .. ".back",
      phase = "around",
      priority = -20,
      fn = function(nxt, ...)
        if Busy() then return 1 end
        return nxt(...)
      end,
    })
  end
end
