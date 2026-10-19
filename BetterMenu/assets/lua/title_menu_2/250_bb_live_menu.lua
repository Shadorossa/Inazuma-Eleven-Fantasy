-- BetterMenu (mod better_menu, prefix BetterMenu): the copy of the Battle Bay top menu on the clubhouse's projector screen
-- (docs/game/mods/better-menu.md §57, [experiment] bb_live_menu). The retail objects are layers of title_menu_2
-- (content\menus\title_bb_live.toml); the scene's screen battle_bay_menu fits the locator, art, logo, badge and note into
-- the screen's rectangle (instance 0 of each). This script opens the buttons (the locator's attached list items), gives
-- them the top menu's own texts and textures (its item table, bb_stadium_top_menu 1.03.98.00), hides Ayuda, shows the
-- hotspot the player has selected (the framework's hotspots bb_live_*, draw = false) as the button's «on» look, follows
-- the screen's fade, and after A (the push-in) fades the copy out so the screen is plain white before the title's white
-- fade. Each layer's place on screen is logged once per showing (GPOS of a node of it): the first in-game test tells
-- whether the attached buttons follow the fitted locator. No engine call at load time.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
if BetterMenu.BBLiveMenu == nil then
  local function Crc(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
      crc = bit32.bxor(crc, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320) else crc = bit32.rshift(crc, 1) end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end

  local Live = {
    ID = "better_menu.bb_live_menu",
    LOG = Crc("CMND_EVT_LOG"),
    SCREEN = "battle_bay_menu",
    SHOT = "table",
    SCREENS = Crc("CMND_VRFW_MENU_SCENE_SCREENS"),
    SCENE_FOR = Crc("CMND_VRFW_MENU_SCENE_FOR"),
    PARAM_HAS = 2947612279,
    PICK_LAYER = Crc("vrfw_menu_scene_pick_layer"),   -- set by the framework on A over a menu_pick hotspot
    MIDDLE = Crc("mainmenu90_11_list_item_middle"),  -- 716364754: the three modes
    SMALL = Crc("mainmenu90_12_list_item_small"),    -- 530619243: Ayuda, Opciones, Guardar
    LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, IS_OPEN = 2640875187,
    VISIBLE = 711242136, LAYER_ALPHA = 4231609516, MESH_VISIBLE = 3405944500,
    TEXT_SET = 1083631230, TEXT_GET = 4074371074, SPRITE = 558735651, GPOS = 499270986,
    TEXT_NODES = { 931545948, 3705682548 },          -- the list item's two text nodes (SetListItemText)
    TEXT_ON, TEXT_OFF = 931545948, 3705682548,      -- _text_list01_on (white, the selected look) / _text_list01_off (blue)
    TEXT_VISIBLE = 2158717427,                      -- (layer, text node, on, instance)
    -- bb_stadium_top_menu's button textures per button type (its table L7_1): atlas, dummy on / ok / off sprites
    TYPES = {
      [0] = { atlas = 2791184640, on = 2456717267, ok = 3791942492, off = 2705476609 },
      [1] = { atlas = 2405639780, on = 2880627768, ok = 3688370359, off = 2527308690 },
    },
    -- its items in list order (L5_1 = {5, 0, 1, 2, 3, 4}): layer instance -> text, on / off texture, button type
    ITEMS = {
      { layer = "MIDDLE", inst = 0, text = 943773677, on = 1030325493, off = 1944112895, type = 0, hotspot = "bb_live_campaign" },
      { layer = "MIDDLE", inst = 1, text = 909487812, on = 226453549, off = 4225270517, type = 0, hotspot = "bb_live_single_player" },
      { layer = "MIDDLE", inst = 2, text = 3808874428, on = 1427929211, off = 2038961444, type = 0, hotspot = "bb_live_multiplayer" },
      { layer = "SMALL", inst = 0, hidden = true },                                                     -- Ayuda
      { layer = "SMALL", inst = 1, text = 355747446, on = 235617948, off = 1203598777, type = 1, hotspot = "bb_live_options" },
      { layer = "SMALL", inst = 2, text = 1008104139, on = 2171185611, off = 2990396281, type = 1, hotspot = "bb_live_save" },
    },
    -- the list item layouts' «on» / «off» meshes (mainmenu90_11 / _12)
    ON_MESHES = { MIDDLE = { "_list_base_m01_on", "_list_icon_dmy_m01_on", "_text_list01_on", "_text_list02_on" },
                  SMALL = { "_list_base_s01_on", "_list_icon_dmy_s01_on", "_text_list01_on" } },
    OFF_MESHES = { MIDDLE = { "_list_base_m01_off", "_list_icon_dmy_m01_off", "_text_list01_off", "_text_list02_off" },
                   SMALL = { "_list_base_m01_off", "_list_icon_dmy_s01_off", "_text_list01_off" } },
    -- a node of each fitted layer whose screen place is logged
    PROBES = {
      { "better_menu_bb_live_background", "_bg01" },
      { "vs01_00_p2_background_bb_stadium", "_bg_stadium01" }, { "mainmenu90_25_list_item_locator", "_list01" },
      { "vs01_47_bb_stadium_header_logo", "_header_logo_bb01" }, { "vs11_01_next_stage_guide", "_btn_next_base01" },
      { "mainmenu90_35_cross_play_guide", "_crossplay_base01" },
      { "mainmenu90_11_list_item_middle", "_list_base_m01_on" }, { "mainmenu90_12_list_item_small", "_list_base_s01_on" },
    },
    -- the campaign's continue / new choice (hotspots of group bb_campaign): the copy shows two buttons with these texts
    CHOICE = {
      { hotspot = "bb_live_campaign_continue", text = 2856747853 },
      { hotspot = "bb_live_campaign_new", text = 1851993283 },
    },
    PUSH_FRAMES = 42,           -- the push-in (0.7 s) before the copy fades out
    FADE_FRAMES = 18,           -- its fade to the screen's white (0.3 s)
  }
  local st = { set = false, opened = false, alpha = 0, picked = nil, logged = false, sel = nil, key = nil }

  local function Log(...) pcall(funcLuaCommand, Live.LOG, "better_menu", "bb_live_menu", ...) end
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
  local function LayerOf(item) return Live[item.layer] end

  local function Present()
    local n = M(Live.LAYER_NUM, Live.MIDDLE)
    return type(n) == "number" and n >= 3
  end

  local function Screen()
    if st.key == nil then
      local k = F(Live.SCENE_FOR, "title_menu_2")
      st.key = type(k) == "string" and k or ""
    end
    if st.key == "" then return nil end
    local r = F(Live.SCREENS, st.key)
    if type(r) ~= "table" then return nil end
    for i = 1, tonumber(r.n) or 0 do
      if type(r[i]) == "table" and r[i].name == Live.SCREEN then return r[i] end
    end
    return nil
  end

  local function OpenItems()
    for _, item in ipairs(Live.ITEMS) do
      local layer = LayerOf(item)
      if M(Live.IS_OPEN, layer, item.inst) ~= true then M(Live.OPEN_LAYER, layer, item.inst) end
    end
    st.opened = true
  end

  local function SetItems()
    for _, item in ipairs(Live.ITEMS) do
      local layer = LayerOf(item)
      if item.hidden then
        M(Live.VISIBLE, layer, item.inst, false)
      else
        local text = F(Live.TEXT_GET, item.text)
        for _, node in ipairs(Live.TEXT_NODES) do M(Live.TEXT_SET, layer, node, type(text) == "string" and text or "", item.inst) end
        local t = Live.TYPES[item.type]
        M(Live.SPRITE, layer, t.atlas, item.on, t.on, 0, item.inst)
        M(Live.SPRITE, layer, t.atlas, item.on, t.ok, 0, item.inst)
        M(Live.SPRITE, layer, t.atlas, item.off, t.off, 0, item.inst)
      end
    end
    st.set = true
    Log("buttons set: 3 modes, Opciones, Guardar (Ayuda hidden)")
  end

  local function Select(name)
    for _, item in ipairs(Live.ITEMS) do
      if not item.hidden then
        local on = item.hotspot == name
        local layer = LayerOf(item)
        for _, mesh in ipairs(Live.ON_MESHES[item.layer]) do M(Live.MESH_VISIBLE, layer, Crc(mesh), on, item.inst) end
        for _, mesh in ipairs(Live.OFF_MESHES[item.layer]) do M(Live.MESH_VISIBLE, layer, Crc(mesh), not on, item.inst) end
        -- the label: the white «on» text on the selected (blue) button, the blue «off» text on the others
        M(Live.TEXT_VISIBLE, layer, Live.TEXT_ON, on, item.inst)
        M(Live.TEXT_VISIBLE, layer, Live.TEXT_OFF, not on, item.inst)
      end
    end
  end

  -- the buttons as the menu (choice = false) or as the campaign's choice (the first two mode buttons, the rest hidden)
  local function SetChoice(choice)
    if st.choice == choice then return end
    st.choice = choice
    for k, item in ipairs(Live.ITEMS) do
      local layer = LayerOf(item)
      if not item.hidden then
        local c = choice and item.layer == "MIDDLE" and Live.CHOICE[item.inst + 1] or nil
        local text = F(Live.TEXT_GET, c and c.text or item.text)
        for _, node in ipairs(Live.TEXT_NODES) do M(Live.TEXT_SET, layer, node, type(text) == "string" and text or "", item.inst) end
      end
    end
    Log(choice and "campaign choice shown: continue / new" or "the menu's buttons again")
  end

  local function ShowItems(alpha)
    for _, item in ipairs(Live.ITEMS) do
      local layer = LayerOf(item)
      local shown = alpha > 0 and not item.hidden
      if st.choice then shown = shown and item.layer == "MIDDLE" and Live.CHOICE[item.inst + 1] ~= nil end
      M(Live.VISIBLE, layer, item.inst, shown)
      M(Live.LAYER_ALPHA, layer, item.inst, 0, alpha)
    end
  end

  local function LogPlaces(e)
    Log(string.format("screen rectangle x %.0f .. %.0f, y %.0f .. %.0f", e.x0 or 0, e.x1 or 0, e.y0 or 0, e.y1 or 0))
    for _, p in ipairs(Live.PROBES) do
      local ok, x, y = M(Live.GPOS, Crc(p[1]), 0, Crc(p[2]))
      Log(string.format("%s node %s at %s, %s (%s)", p[1], p[2], tostring(x), tostring(y), tostring(ok)))
    end
  end

  local function Step()
    if not Present() then return end
    local e = Screen()
    local on = type(e) == "table" and e.seen == 1 and e.on == 1
    -- the copy's fade: in with the screen, out with it, and out after A (the push-in first)
    if F(Live.PARAM_HAS, Live.PICK_LAYER) == true then
      st.picked = (st.picked or 0) + 1
    elseif st.picked and not on then
      st.picked = nil
    end
    local target = on and 1 or 0
    if st.picked and st.picked > Live.PUSH_FRAMES then target = 0 end
    local step = st.picked and (1 / Live.FADE_FRAMES) or (1 / 18)
    if st.alpha < target then st.alpha = math.min(target, st.alpha + step) elseif st.alpha > target then st.alpha = math.max(target, st.alpha - step) end
    if st.alpha > 0 then
      if not st.opened then OpenItems() end
      if not st.set then SetItems() end
      local shot, sel, name = "", 0, ""
      if type(VRFW_MenuSceneHotspot) == "function" then shot, sel, name = VRFW_MenuSceneHotspot() end
      local want = (shot == Live.SHOT and sel > 0) and name or ""
      -- the campaign's choice: its hotspots stand for the first two buttons
      local choice_row = nil
      for k, c in ipairs(Live.CHOICE) do
        if c.hotspot == want then choice_row = k end
      end
      SetChoice(choice_row ~= nil)
      if choice_row then want = Live.ITEMS[choice_row].hotspot end
      if want ~= st.sel then
        st.sel = want
        Select(want)
      end
      ShowItems(st.alpha)
      -- the fitted layers follow the alpha too after A (the framework keeps them at its own fade)
      if st.picked then
        for _, p in ipairs(Live.PROBES) do M(Live.LAYER_ALPHA, Crc(p[1]), 0, 0, st.alpha) end
      end
      if not st.logged and st.alpha >= 1 then
        st.logged = true
        LogPlaces(e)
      end
    elseif st.opened then
      SetChoice(false)
      ShowItems(0)
      st.logged, st.sel = false, nil
    end
  end

  BetterMenu.BBLiveMenu = { Step = Step }
  if VRFW_Host ~= nil then
    VRFW_Host.on("title_menu_2", "OnInit", { id = Live.ID .. ".init", phase = "after", fn = function()
      st.set, st.opened, st.alpha, st.picked, st.logged, st.sel, st.key = false, false, 0, nil, false, nil, nil
      st.choice = nil
    end })
    VRFW_Host.on("title_menu_2", "Step", { id = Live.ID .. ".step", phase = "after", fn = function()
      local ok, err = pcall(Step)
      if not ok then Log("error", tostring(err)) end
    end })
  end
end
