-- Competition is the native opponent list over the clubhouse scene: the mode's shot is the island's pitch outside the
-- lodge (content\menu_scenes\clubhouse.toml), the list's three players stand on it as menu 3D models
-- (assets\lua\soccer_vs_cpu_list_menu\275_competition_players.lua). No scene travel and no reset: a team change only
-- swaps the models; B does nothing there (the list is the mode's view), L2 / R2 close it and go to the adjacent mode's shot.
-- The list opens by itself once the Competition mode has had the focus for AUTO_OPEN_FRAMES (owner 2026-10-18: no A
-- needed); closed while the mode keeps the focus, it stays closed until the focus leaves the mode (A opens it again).
-- The title's parts are hidden from the first frame the mode has the focus (owner 2026-10-19: the header, the bottom
-- bar, the copyright, the logos and the version showed over the pitch until the list opened).
do
  local C = BetterMenu.Competition
  local frame, opened, wait, restored, launch_sent, open_at = 0, false, 0, false, false, 0
  local restoring = false
  local probe_strip = false           -- the top-left probe after the list's first strip draw (once per list open)
  local AUTO_OPEN_FRAMES = 12         -- the cut to the pitch, then the list
  local focus_frames, dismissed, auto_open = 0, false, false
  local shown_before = nil            -- layer crc -> { instance -> visible } before the list hid the title
  local UI_READY = C.Hash("better_menu_competition_ui_ready")
  local TOP_BAR_HIDDEN = C.Hash("vrfw_top_bar_hidden")
  local anchor, lower = C.Hash("better_menu_team_anchor"), C.Hash("title00_07_item_button_lower")
  local covered = {
    "title00_07_item_button_lower", "title02_02_item_atc_locator_2", "title02_03_item_name_2",
    "title02_20_dlc_buy_btn_atc_locator", "title02_22_dlc_logo", "title02_23_dlc_logo_simple",
    "title02_24_dlc_logo_simple_balloon", "better_menu_tile_plate", "better_menu_mode_header",
    "better_menu_mode_texts", "vrfw_ms_label", "vrfw_ms_frame",
    "better_menu_live_painting", "better_menu_bb_projection",
    "cmn05_01_coursor",
    -- the version (top right) and the copyright (bottom left): not on the Competition view (owner 2026-10-18)
    "title02_04_version", "title02_04_version_ps", "evt_vrfw_title_word", "title00_08_copyright",
  }
  local function remember_title()
    shown_before = {}
    for _, name in ipairs(covered) do
      local layer = C.Hash(name)
      local count = C.M(1175615627, layer) or 0
      local seen = {}
      for i = 0, count - 1 do seen[i] = C.M(1262717583, layer, i) == true end
      shown_before[layer] = seen
    end
  end
  local function hide_title()
    for _, name in ipairs(covered) do
      local layer = C.Hash(name)
      local count = C.M(1175615627, layer) or 0
      for i = 0, count - 1 do C.M(711242136, layer, i, false) end
    end
  end
  local function show_title()
    for layer, seen in pairs(shown_before or {}) do
      for i, on in pairs(seen) do if on then C.M(711242136, layer, i, true) end end
    end
    shown_before = nil
  end
  local function state() local s = C.State() return type(s) == "table" and s or nil end
  local function exists(menu) return C.M(2231168902, menu) == true end
  -- the mode row's focus is on Competition (not the home entry)
  local function competition_focused()
    if type(VRFW_MenuSceneIsHome) == "function" and VRFW_MenuSceneIsHome() then return false end
    local idx = type(GetSelectItemIdx) == "function" and GetSelectItemIdx() or -1
    local layer = type(GetSelectItemLayerName) == "function" and GetSelectItemLayerName() or nil
    if layer ~= C.ROW or idx < 0 or type(GetTitleMenuItemId) ~= "function" then return false end
    return GetTitleMenuItemId(idx, true) % 4294967296 == C.MODE
  end
  local function enter_competition()
    if opened or launch_sent then return false end
    local phase, scene = C.F(2588710643)
    if phase ~= "up" or scene ~= "better_menu.clubhouse" then return false end
    if type(VRFW_MenuSceneIsHome) == "function" and VRFW_MenuSceneIsHome() then return false end
    local idx = type(GetSelectItemIdx) == "function" and GetSelectItemIdx() or -1
    local layer = type(GetSelectItemLayerName) == "function" and GetSelectItemLayerName() or nil
    if layer ~= C.ROW or idx < 0 or type(GetTitleMenuItemId) ~= "function" then return false end
    if GetTitleMenuItemId(idx, true) % 4294967296 ~= C.MODE then return false end
    C.State("open", idx, true)
    C.Log("competition entered by confirm", idx)
    return true
  end
  -- the list closed: the title's own parts and input back, the shot on mode `to` (the pitch when it is Competition)
  local function close_list(to)
    if exists(C.LIST) then C.F(320421347, C.LIST, true) end   -- now: no last frame of the list over the next shot
    C.F(C.FOLLOW_CAMERA, C.MENU_CAMERA, false)
    C.Clear(C.OVERLAY)
    C.Clear(TOP_BAR_HIDDEN)
    C.Clear(UI_READY)
    C.M(1778826357, anchor, 0, false)  -- the anchor's focus mark too: the mode header reads the anchor's focus as the
    C.M(3518307824, anchor, false)     -- team drawer's and stayed on «Modo Competición» after L2 / R2 (owner 2026-10-18)
    C.M(3518307824, C.ROW, true)
    C.M(3518307824, lower, true)
    show_title()
    opened, wait = false, 0
    -- closed on the mode itself (no opponent, or the list failed to open): not again until the focus leaves the mode
    dismissed, auto_open = true, false
    local focused = type(VRFW_MenuSceneFocusMode) == "function" and VRFW_MenuSceneFocusMode(to)
    C.Log("list closed, mode", to, "focused", tostring(focused))
    -- the Competition players' contre-jour off with the list (the clubhouse's people in the scene's light)
    C.Contraluz(false)
    -- the header back on the mode now focused (one opening, after the focus moved)
    if BetterMenu.ModeHeader and BetterMenu.ModeHeader.Cover then BetterMenu.ModeHeader.Cover("competition", false) end
  end
  function BetterMenuCompetitionMode(dir)
    local s = state()
    if not s or not s.open or launch_sent or exists(C.CLASS) then return end
    local n = type(GetItemButtonNum) == "function" and GetItemButtonNum(true) or 0
    local to = (dir == 0 or n <= 0) and s.mode or ((s.mode + dir) % n)
    C.State("close", to)
    C.State("resumed")
    close_list(to)
  end
  local function open_list(s)
    C.Clear(UI_READY)
    C.F(667984508, 3683890655, s.tab)
    C.F(667984508, 2574363467, s.row)
    C.Set(C.OVERLAY)
    C.Set(TOP_BAR_HIDDEN)
    if not shown_before then remember_title() end
    C.M(3518307824, C.ROW, false)
    C.M(3518307824, lower, false)
    C.M(629267548, anchor, 0)
    C.M(1389957207, anchor, -6000, 4000, 0, 0)
    C.M(3778714801, anchor, 0, 0, 1, 0)   -- the anchor only holds the input: no quad of it on screen
    C.M(711242136, anchor, 0, false)      -- (a hidden layer keeps the control focus, as the scene's hidden mode row)
    C.M(3518307824, anchor, true)
    C.M(1778826357, anchor, 0, true)
    hide_title()
    -- the team drawer button is not part of the opponent picker
    C.M(711242136, C.Hash("better_menu_team_icon"), 0, false)
    C.M(711242136, C.Hash("better_menu_team_text"), 0, false)
    C.F(433545986, C.LIST)
    if BetterMenu.ModeHeader and BetterMenu.ModeHeader.Cover then BetterMenu.ModeHeader.Cover("competition", true) end
    opened, wait = true, 0
    open_at = frame
    C.Log("drawer opened", s.tab, s.row)
  end
  -- the mode row's focus moved: onto Competition the title's parts go (no frame of them over the pitch) and the
  -- list's count starts; off it they come back
  local function on_focus()
    if opened or launch_sent then return end
    local st, key = C.F(2588710643)
    if st ~= "up" or key ~= "better_menu.clubhouse" then return end
    if competition_focused() then
      if dismissed or auto_open then return end
      if not shown_before then remember_title() end
      hide_title()
      focus_frames, auto_open = 0, true
    else
      dismissed, auto_open = false, false
      if shown_before then show_title() end
    end
  end
  local function tick()
    frame = frame + 1
    local st, key = C.F(2588710643)
    if st ~= "up" or key ~= "better_menu.clubhouse" then return end
    local s = state()
    if not s then return end
    if not restored then
      restored = true
      if s.resume then
        restoring = true
        local focused = type(VRFW_MenuSceneFocusMode) == "function" and VRFW_MenuSceneFocusMode(s.mode)
        restoring = false
        if focused then C.State("resumed") else restored = false end
      end
      return -- the mode header observes the restored row before the list takes focus
    end
    if s.launch then
      if not launch_sent then
        launch_sent = true
        C.Clear(C.OVERLAY)
        C.Set(C.LAUNCH)
        C.M(3518307824, anchor, false)
        C.Log("native competition hand-off requested")
      end
      return
    end
    -- the list by itself AUTO_OPEN_FRAMES after the focus came to the Competition mode (on_focus starts the count)
    if auto_open and not s.open then
      focus_frames = focus_frames + 1
      if focus_frames >= AUTO_OPEN_FRAMES and enter_competition() then
        auto_open = false
        C.Log("list opened by the focus on the mode", type(GetSelectItemIdx) == "function" and GetSelectItemIdx() or -1)
      end
    end
    if s.open then
      if not opened then
        open_list(s)
        probe_strip = true
        C.Probe("title_menu_2", "list opened")
      end
      if probe_strip and C.F(2947612279, UI_READY) == true then
        probe_strip = false
        C.Probe("title_menu_2", "first strip drawn")
      end
      if s.game == 0 and frame - open_at > 300 then
        C.Log("no readable opponent after 300 frames; back to the mode")
        BetterMenuCompetitionMode(0)
        return
      end
      if not exists(C.LIST) then
        wait = wait + 1
        if wait > 180 then C.Log("list failed to open") BetterMenuCompetitionMode(0) end
      else wait = 0 end
    end
  end
  if VRFW_Host then
    for _, point in ipairs({"OnEnter", "OnDecideFocus"}) do
      VRFW_Host.on("title_menu_2", point, { id = "better_menu.competition.confirm_entry." .. point,
        phase = "around", priority = -300, fn = function(nxt, ...)
          if enter_competition() then return 1 end
          return nxt(...)
        end })
    end
    VRFW_Host.on("title_menu_2", "OnInit", { id = "better_menu.competition.init", phase = "after", fn = function()
      frame, opened, wait, restored, launch_sent = 0, false, 0, false, false
      focus_frames, dismissed, auto_open = 0, false, false
      restoring, shown_before = false, nil
      C.Clear(UI_READY)
      C.Clear(C.OVERLAY) C.Clear(C.LAUNCH)
    end })
    -- the input anchor never shows: its object is the B button graphic, drawn as a white quad at the screen's top left
    -- by every opening animation (the Competition list's open, its Z / C tab change, the team drawer; owner 2026-10-19).
    -- Its layer is kept hidden at each of its openings (start and end): a hidden layer still holds the control focus.
    for _, point in ipairs({ "OnOpenLayer", "OnOpenEndLayer" }) do
      VRFW_Host.on("title_menu_2", point, { id = "better_menu.competition.anchor_hidden." .. point, phase = "after",
        create = true, fn = function(layer, idx)
          if point == "OnOpenLayer" then C.ProbeTrack(layer, idx) end
          if layer ~= anchor then return end
          C.M(711242136, anchor, 0, false)
          C.M(3778714801, anchor, 0, 0, 1, 0)
        end })
    end
    VRFW_Host.on("title_menu_2", "OnChangeFocus", { id = "better_menu.competition.focus", phase = "after",
      fn = function() local ok, why = pcall(on_focus) if not ok then C.Log("focus error", why) end end })
    if VRFW_MenuScene and VRFW_MenuScene.On then
      VRFW_MenuScene.On("mode_focused", "better_menu.competition.mode", function()
        local ok, why = pcall(on_focus)
        if not ok then C.Log("focus error", why) end
      end)
    end
    VRFW_Host.on("title_menu_2", "Step", { id = "better_menu.competition.step", phase = "after", priority = 200,
      fn = function() local ok, why = pcall(tick) if not ok then C.Log("title error", why) end end })
    for _, name in ipairs({ "OnEnter", "OnBack", "OnFunction", "OnChangeFocus" }) do
      VRFW_Host.on("title_menu_2", name, { id = "better_menu.competition.input." .. name, phase = "around", priority = -200,
        fn = function(nxt, ...)
          if not restoring and (opened or launch_sent) then return name == "OnBack" and 1 or nil end
          return nxt(...)
        end })
    end
  end
end
