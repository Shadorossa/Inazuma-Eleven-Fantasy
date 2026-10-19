-- Keep the game's list, tabs, unlock checks, formation and difficulty selector.
-- Only its presentation and final launch are adapted while hosted by BetterMenu.
do
  local C = BetterMenu.Competition
  local frame, changed, last, sent, laid_out = 0, 0, nil, nil, false
  local SELECTOR = C.Hash("better_menu_competition_selector")
  local CREST = C.Hash("better_menu_competition_crest")
  -- the white line behind the crest strip, fading out toward both ends (content\menus\competition.toml; its picture
  -- research/scripts/better_menu_crest_line_build.py): one quad of the 36 px quad cmn01_10 scaled to the picture's size
  local CREST_LINE = C.Hash("better_menu_competition_crest_line")
  local input_opened = false            -- the input layer is opened once per list open (each opening plays its animation)
  local CREST_LINE_BOX = { QUAD = 36, WIDTH = 960, HEIGHT = 24, CENTRE_X = 1440, CENTRE_Y = 155, PRIORITY = 560 }
  local UI_READY = C.Hash("better_menu_competition_ui_ready")
  local INPUT = C.Hash("better_menu_competition_input")
  local CONFIRM = C.Hash("better_menu_competition_confirm")
  local previous, following = C.Hash("better_menu_competition_team_prev"), C.Hash("better_menu_competition_team_next")
  local season_previous, season_following = C.Hash("better_menu_competition_season_prev"), C.Hash("better_menu_competition_season_next")
  local text_cache = {}
  local PLAYERS_SETTLE_FRAMES = 1    -- frames a team stays focused before its players are asked for (the models swap atomically)
  local formation_key = nil
  local key_ticks = {}
  local last_action, last_action_frame = nil, -10
  local catalogue, catalogue_tab, enumerating, crest_cache = {}, nil, false, {}
  local strip_notified = false
  local crest_hidden = {
    "_cpu_title_base01", "_cpu_icon_class_dmy01", "_icon_class_chronicle_dmy01",
    "_chronicle_gtxt_lv01", "_text_team_name01", "_dmy_team_name01",
    "_chronicle_lv_num_dmy01", "_chronicle_lv_num_dmy02",
  }
  local function host() return VRFW_Host and VRFW_Host.hosts.soccer_vs_cpu_list_menu end
  local function read_catalogue(tab, count)
    if catalogue_tab == tab and #catalogue == count then return true end
    if count < 1 then return false end
    local old = C.M(1727549139, 1107559438)
    if type(old) ~= "number" then return false end
    -- Native list data has no indexed getter. Read it with focus notifications
    -- suppressed, then put the focus back; no preview/formation/save callbacks
    -- are run for the intermediate entries.
    local entries = {}
    enumerating = true
    for i = 0, count - 1 do
      C.M(306610847, 1107559438, i)
      local ok, game = C.M(1666448199, 0)
      if ok and type(game) == "number" and game ~= 0 then entries[i + 1] = game else break end
    end
    C.M(306610847, 1107559438, old)
    enumerating = false
    if #entries ~= count then return false end
    catalogue, catalogue_tab, crest_cache = entries, tab, {}
    return true
  end
  local function crest_line()
    local box = CREST_LINE_BOX
    if not crest_cache.line then
      C.M(629267548, CREST_LINE, 0)
      C.M(3778714801, CREST_LINE, box.WIDTH / box.QUAD, box.HEIGHT / box.QUAD, 1, 0)
      C.M(1389957207, CREST_LINE, box.CENTRE_X, -box.CENTRE_Y, 0, 0)
      C.M(1491630496, CREST_LINE, 0, box.PRIORITY, true)
      crest_cache.line = true
    end
    C.M(711242136, CREST_LINE, 0, true)
  end
  -- each crest slot's place (re-applied at the end of its opening: the opening animation puts the crest back at the
  -- layout's own spot, the left of the screen, owner 2026-10-19), the slots still opening (hidden until then) and the
  -- slots' failed reads (a crest still loading keeps the slot's last crest; MISSING_STEPS failed reads hide it)
  local crest_place, crest_opening, crest_misses = {}, {}, {}
  local MISSING_STEPS = 30
  local function place_crest(i)
    local q = crest_place[i]
    if not q then return end
    C.M(3778714801, CREST, q.scale, q.scale, 1, i)
    C.M(4231609516, CREST, i, 0, q.alpha)
    C.M(1389957207, CREST, q.x, q.y, 0, i)
    C.M(1491630496, CREST, i, 570, true)
  end
  -- the input layer is never shown: hidden and scaled to nothing at each of its openings (start and end); a hidden
  -- layer keeps the control focus
  local function input_hidden(layer)
    if layer ~= INPUT then return end
    C.M(711242136, INPUT, 0, false)
    C.M(3778714801, INPUT, 0, 0, 1, 0)
  end
  local function crest_opened(layer, i)
    if layer ~= CREST or crest_opening[i] == nil then return end
    crest_opening[i] = nil
    place_crest(i)
  end
  local function crests(row, count)
    crest_line()
    local h = host()
    local difficulty = h and h.L.n8 or 6
    for i = 0, 6 do
      local at = (row + i - 3) % count
      -- a season with fewer games than the slots: the outer slots stay empty (no repeated crest)
      local game = (math.abs(i - 3) <= (count - 1) / 2) and catalogue[at + 1] or nil
      if game == nil then
        crest_cache[i], crest_misses[i] = nil, nil
      elseif crest_cache[i] ~= game then
        -- the game's team at the list's class, else at any class it offers (some seasons offer no class 6 team)
        local have, team = C.F(2204933160, game, difficulty)
        if not have then
          for d = 6, 9 do
            have, team = C.F(2204933160, game, d)
            if have then break end
          end
        end
        local ok, emblem = C.F(2151743654, team or 0, 6, 0)
        if not (have and ok and type(emblem) == "number") then
          -- not readable yet (loading after a tab change): the slot keeps its crest a moment; never readable: hidden
          crest_misses[i] = (crest_misses[i] or 0) + 1
          if crest_misses[i] >= MISSING_STEPS then crest_cache[i] = nil end
        else
          crest_misses[i] = nil
          -- a slot is opened once per list open (hidden until its opening ends, then placed); after that a new team
          -- only swaps the crest texture in place: no opening, so no slot ever blinks or jumps to the layout's spot
          if crest_place[i] == nil then
            C.M(629267548, CREST, i)
            crest_opening[i] = frame
            C.M(711242136, CREST, i, false)
            for _, name in ipairs(crest_hidden) do C.M(3405944500, CREST, C.Hash(name), false, i) end
            C.M(2158717427, CREST, C.Hash("_num_chronicle_lv01"), false, i)
            C.M(2158717427, CREST, C.Hash("_num_chronicle_lv02"), false, i)
            C.M(1083631230, CREST, 3778687894, "", i)
          end
          C.M(3190452549, CREST, i, 574244154, 1949581463, emblem)
          local distance = math.abs(i - 3)
          local scale = ({[0] = 1.1, 0.82, 0.68, 0.55})[distance]
          local alpha = ({[0] = 1, 0.78, 0.48, 0.2})[distance]
          local cx, cy = 1440 + (i - 3) * 110, 155
          crest_place[i] = { scale = scale, alpha = alpha, x = cx - 1027 * scale, y = -cy + 173 * scale }
          place_crest(i)
          crest_cache[i] = game
        end
      end
      -- an opening whose end was not reported within 20 steps: placed and shown anyway
      if crest_opening[i] and frame - crest_opening[i] > 20 then crest_opened(CREST, i) end
      C.M(711242136, CREST, i, crest_cache[i] ~= nil and not crest_opening[i])
    end
  end
  -- Mouse, step 1 (content\menus\competition_mouse.toml, config.toml [competition] mouse): one click zone over the
  -- centred crest, the retail team-dock item mainmenu90_31_doc_item at alpha 0. Its zone is that layout's
  -- _touch_list01 (636 x 86 at (12, -13)), scaled to HIT_SIZE and centred on the crest. Opened once per list open; the
  -- zone is on only while the centre crest is drawn and the class window is closed. No layer (switch off): nothing.
  local HIT = C.Hash("better_menu_competition_hit")
  local HIT_ZONE = { W = 636, H = 86, X = 12, Y = -13 }
  local HIT_SIZE = 110
  local HIT_CENTRE = { X = 1440, Y = 155 }
  local hit_state = nil                  -- nil = not opened in this list open, else "on" / "off"
  local function hit_zone(on)
    C.M(855005857, HIT, 0, on)
    C.M(2206938151, HIT, 0, on)
  end
  local function hit_update()
    if C.M(262659071, HIT) ~= true then return end
    if hit_state == nil then
      C.M(629267548, HIT, 0)
      local sx, sy = HIT_SIZE / HIT_ZONE.W, HIT_SIZE / HIT_ZONE.H
      C.M(3778714801, HIT, sx, sy, 1, 0)
      C.M(1389957207, HIT, HIT_CENTRE.X - HIT_ZONE.X * sx, -HIT_CENTRE.Y - HIT_ZONE.Y * sy, 0, 0)
      C.M(4231609516, HIT, 0, 0, 0)
      C.M(3518307824, HIT, true)
      hit_zone(false)
      hit_state = "off"
      C.Log("mouse zone: layer opened", "instances", tostring(C.M(1175615627, HIT)),
        "collision node _touch_list01 of mainmenu90_31 (checked offline)")
    end
    local want = C.M(2231168902, C.CLASS) ~= true and crest_place[3] ~= nil and crest_cache[3] ~= nil and not crest_opening[3]
    local state = want and "on" or "off"
    if state ~= hit_state then
      hit_zone(want)
      hit_state = state
      C.Log("mouse zone", state)
    end
  end
  local function label(i, text, cx, y, scale)
    scale = scale or 1
    local key = text .. "@" .. tostring(y)
    if text_cache[i] ~= key then
      C.M(629267548, SELECTOR, i)
      for _, mesh in ipairs({298211823, 2853207670}) do C.M(3405944500, SELECTOR, mesh, false, i) end
      C.M(2885415772, SELECTOR, i, 378327766, 1600, 76)
      C.M(3778714801, SELECTOR, 1, 1, 1, i)
      C.M(1083631230, SELECTOR, 378327766, text, i)
      local w = C.M(3549540977, SELECTOR, i, 378327766)
      w = type(w) == "number" and w > 0 and w or 16 * #text
      C.M(3778714801, SELECTOR, scale, scale, 1, i)
      C.M(1389957207, SELECTOR, cx - w * scale / 2 + 384 * scale, -y - 144 * scale, 0, i)
      C.M(1491630496, SELECTOR, i, 570, true)
      text_cache[i] = key
    end
    C.M(711242136, SELECTOR, i, true)
  end
  local function selector()
    local h = host()
    local tab = h and h.L.n6 or 0
    label(0, "<CMD_FUNCL1>", 1810, 72)
    label(1, "<CMD_LEFT>", 1000, 155)
    label(2, "<CMD_RIGHT>", 1880, 155)
    local n = h and h.L.n9 or 0
    local row = C.M(1727549139, 1107559438) or 0
    label(3, "<CMD_FUNCR1>", 1870, 72)
    local ready = read_catalogue(tab, n)
    if ready then crests(row, n) end
    -- Keep the list's data and input active; its rows are replaced visually by
    -- the selected team's native full-size heading and the left/right carousel.
    for _, layer in ipairs({1107559438, 1074924810, 4088477286, 2443640880, 3082153440}) do
      local count = C.M(1175615627, layer) or 0
      for i = 0, count - 1 do C.M(711242136, layer, i, false) end
    end
    -- The retail blue strip itself, including each season's highlighted icon.
    C.M(3778714801, 1887158505, 0.76, 0.88, 1, 0)
    C.M(1389957207, 1887158505, 1045.6, 98.72, 0, 0)
    C.M(711242136, 1887158505, 0, true)
    for _, node in ipairs({"_text_list_tab01", "_dmy_list_tab01", "_text_btn_r01", "_text_btn_l01"}) do
      C.M(2158717427, 1887158505, C.Hash(node), false, 0)
      C.M(2735666188, 1887158505, C.Hash(node), false, 0)
      C.M(1083631230, 1887158505, C.Hash(node), "", 0)
    end
    local _, total = C.F(1612837075)
    for i = 0, (tonumber(total) or 9) - 1 do
      C.M(3778714801, 4044286600, 0.76, 0.88, 1, i)
      C.M(711242136, 4044286600, i, true)
    end
    C.M(2171393651, 2296367164, false) -- native list cursor, not part of the carousel
    C.M(711242136, C.Hash("cmn05_01_cursor"), 0, false)
    C.M(711242136, 575058101, 0, false) -- native hub header left over behind the custom selector
    if C.M(2231168902, C.CLASS) ~= true then
      -- opened once: an opening replayed every step showed the layer's object (the B button graphic, a white quad at
      -- the screen's top left) on each step's first frame
      if not input_opened then
        input_opened = true
        C.M(629267548, INPUT, 0)
      end
      C.M(1389957207, INPUT, -6000, 4000, 0, 0)
      C.M(3778714801, INPUT, 0, 0, 1, 0)
      C.M(711242136, INPUT, 0, false)        -- (the B button graphic: a white quad at the top left; a hidden layer keeps the focus)
      C.M(3252599449, INPUT, 1)
      C.M(2171393651, INPUT, true)
      C.M(1558704558, C.LIST, true)
      C.M(3518307824, 1107559438, false)
      C.M(3518307824, 1074924810, false)
      C.M(3518307824, 4044286600, false)
      C.M(3518307824, INPUT, true)
      -- the input layer takes the focus back unless the mouse zone holds it
      if C.M(102308320, HIT) ~= true then C.M(1778826357, INPUT, 0, true) end
    end
    hit_update()
    for _, mesh in ipairs({"_cpu_title_base01", "_cpu_icon_emblem_dmy01", "_cpu_icon_class_dmy01", "_icon_class_chronicle_dmy01"}) do
      C.M(3405944500, 1835074715, C.Hash(mesh), false, 0)
    end
    -- Keep the original heading as the formation's sole attachment parent.
    -- The team name is drawn separately so its position cannot move the pitch.
    C.M(2735666188, 1835074715, 3778687894, false, 0)
    C.M(1233047821, 1835074715, 0, 51927332, false)
    C.M(3405944500, 1835074715, C.Hash("_chronicle_gtxt_lv01"), false, 0)
    -- no class header and no level on the list: the heading's own class and level nodes stay hidden
    C.M(2158717427, 1835074715, C.Hash("_num_chronicle_lv01"), false, 0)
    C.M(2158717427, 1835074715, C.Hash("_num_chronicle_lv02"), false, 0)
    local game_ok, game = C.M(1666448199, 0)
    local difficulty = h and h.L.n8 or 6
    local team_ok, team = C.F(2204933160, game or 0, difficulty)
    if game_ok and team_ok then
      local _, name = C.F(2151743654, team, 2)
      label(4, name or "", C.CREST_X, C.NAME_Y + C.UnderCrestHeight(), 0.7)   -- below the band other mods reserve under the crest
    end
    if ready and laid_out then
      C.Set(UI_READY)
      -- once per list open, when the strip and the list's focus are ready: the listeners may read the focused game
      if not strip_notified then
        strip_notified = true
        C.NotifyStrip()
        C.Probe("soccer_vs_cpu_list_menu", "first strip drawn")
      end
    end
  end
  local function move_team(dir)
    local h = host()
    local n = h and h.L.n9 or 0
    if n <= 0 then return end
    local index = C.M(1727549139, 1107559438) or 0
    C.M(2171393651, 1107559438, true)
    C.M(3518307824, 1107559438, true)
    C.M(306610847, 1107559438, (index + dir) % n)
    OnChangeFocus(1074924810, (index + dir) % n)
    C.Log("carousel move", dir, "row", index, "->", C.M(1727549139, 1107559438))
  end
  -- the series tab the bar shows, kept here: the menu's own index (L.n6) read back 0 between presses, so Z / C only
  -- reached the tabs either side of the first (owner 2026-10-18: «solo me deja moverme por estos 2»)
  local season_tab = nil
  local function move_season(dir)
    local h = host()
    local _, total = C.F(1612837075)
    total = type(total) == "number" and total or 9
    local menu_tab, cursor, byte = h and h.L.n6, C.M(1727549139, 4044286600), C.F(47917410, 3683890655)
    local tab = season_tab or (type(cursor) == "number" and cursor >= 0 and cursor) or menu_tab or byte or 0
    season_tab = (tab + dir) % total
    C.F(667984508, 3683890655, season_tab)
    C.F(667984508, 2574363467, 0)
    if h then h.L.n7 = 0 end
    C.M(2171393651, 4044286600, true)
    C.M(3518307824, 4044286600, true)
    C.M(1778826357, 4044286600, season_tab, true)
    -- A focus mark alone does not dispatch a category change on an inactive bar.
    if not h or h.L.n6 ~= season_tab then OnChangeFocus(4044286600, season_tab) end
    C.M(306610847, 1107559438, 0)
    OnChangeFocus(1074924810, 0)
    C.Log("season move", dir, "tab", tab, "->", season_tab, "of", total, "(menu", tostring(menu_tab), "cursor", tostring(cursor),
      "byte", tostring(byte), "now", h and h.L.n6 or -1, ")")
  end
  function BetterMenuCompetitionNavigate(action)
    if not C.Active() or C.M(2231168902, C.CLASS) == true then return false end
    if action == last_action and frame - last_action_frame <= 1 then return false end
    last_action, last_action_frame = action, frame
    C.Log("navigation received", tostring(action))
    if action == "left" then move_team(-1)
    elseif action == "right" then move_team(1)
    elseif action == "season_left" then move_season(-1)
    elseif action == "season_right" then move_season(1)
    else return false end
    return true
  end
  local function navigation()
    if C.M(2231168902, C.CLASS) == true then key_ticks = {} return end
    local held = C.F(2864033604)
    held = type(held) == "number" and held > 0 and held or 0
    local keys = {
      {"left", 0x80, {0x41, 0x25}}, {"right", 0x20, {0x44, 0x27}},
      {"season_left", 0x400, {0x5A, 0x21}}, {"season_right", 0x800, {0x43, 0x22}},
    }
    local down = {}
    for _, key in ipairs(keys) do
      local on = bit32.band(held, key[2]) ~= 0
      for _, vk in ipairs(key[3]) do if C.F(3182184968, vk) == true then on = true end end
      down[key[1]] = on
    end
    if down.left and down.right then down.left, down.right = false, false end
    if down.season_left and down.season_right then down.season_left, down.season_right = false, false end
    for _, key in ipairs(keys) do
      local name = key[1]
      local ticks = down[name] and ((key_ticks[name] or 0) + 1) or 0
      key_ticks[name] = ticks
      if ticks == 1 or (ticks >= 24 and (ticks - 24) % 8 == 0) then BetterMenuCompetitionNavigate(name) end
    end
  end
  local function arrange()
    if laid_out then return end
    local roots = {
      { 1835074715, 1, 0, -100 }, -- selected name below the five emblems
      { 3321884270, 1, 0, 30 }, -- original game coordinates and size
    }
    for _, p in ipairs(roots) do
      if C.M(2640875187, p[1], 0) ~= true then return end
    end
    for _, p in ipairs(roots) do
      C.M(3778714801, p[1], p[2], p[2], 1, 0)
      -- Formation is attached to the heading's locator. Its world position must
      -- not be fed back as an additional local offset (it doubles the shift).
      C.M(1389957207, p[1], p[3], p[4], 0, 0)
    end
    for _, layer in ipairs({ 1973487846, 3571911991, 1658289671, 2290394976 }) do
      local n = C.M(1175615627, layer) or 0
      for i = 0, n - 1 do C.M(3778714801, layer, 1, 1, 1, i) end
    end
    C.M(3405944500, 1835074715, C.Hash("_cpu_title_base01"), false, 0)
    C.M(3405944500, 1835074715, 574244154, false, 0)
    C.M(3405944500, 1835074715, 126765991, false, 0)
    C.M(3405944500, 1835074715, C.Hash("_icon_class_chronicle_dmy01"), false, 0)
    C.M(711242136, 3078308064, 0, false) -- native full-width help line over the bottom tile row
    laid_out = true
    local h = VRFW_Host and VRFW_Host.hosts.soccer_vs_cpu_list_menu
    if h and h.L and type(UpdateFormation) == "function" then
      UpdateFormation(h.L.n2, h.L.n5, true)
    end
  end
  -- the team the list shows while the class window is open: VRFW's «shown team changed» (the window's focused class,
  -- whose rival may differ from the list's: a mod's per-class rival); nil = none heard since the window opened
  local shown = nil
  VRFW_FM = VRFW_FM or {}
  VRFW_FM.shown_team_listeners = VRFW_FM.shown_team_listeners or {}
  VRFW_FM.shown_team_listeners["BetterMenu.Competition"] = function(game, class, team)
    shown = { game = game, class = class, team = team }
  end
  local function focus()
    local picker = C.M(2231168902, C.CLASS) == true
    if not picker then shown = nil end
    -- with the class window open, the players follow the shown team (VRFW redrew the formation itself)
    if picker and not shown then return end
    local ok, game = true, shown and shown.game
    if not picker then ok, game = C.M(1666448199, 0) end
    if not ok or type(game) ~= "number" or game == 0 then last = nil return end
    local h = VRFW_Host and VRFW_Host.hosts.soccer_vs_cpu_list_menu
    local difficulty = picker and shown.class or (h and h.L and h.L.n8) or 6
    if type(difficulty) ~= "number" then difficulty = 6 end
    local hast, team = C.F(2204933160, game, difficulty)
    if not hast or type(team) ~= "number" or team == 0 then return end
    local current_formation = table.concat({team, game, difficulty}, ":")
    local cached = h and h.L
    if not picker and type(UpdateFormation) == "function" and C.M(2640875187, 1973487846, 0) == true and
        (formation_key ~= current_formation or (cached and (cached.n11 ~= team or cached.n12 ~= game or cached.n13 ~= difficulty))) then
      -- Read the team from the selected match, rather than reusing the native
      -- heading's previous team after a carousel move / stadium reload.
      if cached then cached.n2, cached.n5, cached.n8 = team, game, difficulty end
      UpdateFormation(team, game, true)
      formation_key = current_formation
      C.Log("formation refreshed", team, "game", game, "class", difficulty)
    end
    local hasm, map = C.F(634509816, game, 4)
    local hasu, uniform = C.F(2151743654, team, 4)
    if not hasu then return end
    map = (hasm and type(map) == "number") and map or 0
    -- Team-info field 5 is the formation's coach card. The captain flag is on
    -- each member (field 9); never use the coach as the preview's captain.
    local count_ok, count = C.F(2151743654, team, 8)
    if not count_ok or type(count) ~= "number" then return end
    local players, captain, goalkeeper = {}, nil, nil
    for i = 0, count - 1 do
      local have, card = C.F(34355761, team, i, 0)
      local placed, pos = C.F(34355761, team, i, 7)
      if have and placed and type(card) == "number" and card ~= 0 and type(pos) == "number" and pos >= 0 and pos <= 15 then
        local _, cap = C.F(34355761, team, i, 9)
        local p = {card = card, pos = pos}
        players[#players + 1] = p
        if cap == true then captain = p end
        if pos == 0 then goalkeeper = p end
      end
    end
    table.sort(players, function(a, b) return a.pos > b.pos end)
    if not captain then
      for _, p in ipairs(players) do if p.pos <= 10 then captain = p break end end
    end
    if not captain then return end
    local selected, seen = {}, {}
    local function add(p)
      if not p or seen[p.card] then return end
      local base = C.F(413729894, p.card)
      local motion = type(base) == "number" and C.F(1229214512, base) or nil
      if type(motion) ~= "string" or motion == "" then return end
      seen[p.card] = true
      selected[#selected + 1] = string.format("%s:%.0f:%s", p.pos == 0 and "keeper" or "player", base % 4294967296, motion)
    end
    add(captain)
    add(goalkeeper)
    for _, p in ipairs(players) do
      if #selected >= 3 then break end
      if p.pos >= 1 and p.pos <= 10 then add(p) end
    end
    if #selected == 0 then return end
    local tab = C.F(47917410, 3683890655) or 0
    local row = C.F(47917410, 2574363467) or 0
    local members = table.concat(selected, ",")
    local signature = table.concat({ game, difficulty, tab, row, map, members, uniform }, ":")
    if signature ~= last then last, changed = signature, frame end
    -- A short settle: browsing quickly does not start a model build per team passed over.
    if frame - changed >= PLAYERS_SETTLE_FRAMES and sent ~= signature then
      if C.State("focus", game, difficulty, tab, row, map, members, uniform) == true then
        sent = signature
        if BetterMenu.CompetitionPlayers then BetterMenu.CompetitionPlayers.Want(members, uniform, game) end
        C.Log("focused", game, "class", difficulty, "captain", captain.card, "players", #selected)
      end
    end
  end
  local function tick()
    frame = frame + 1
    local session = C.State()
    local active = type(session) == "table" and session.open == true and not session.launch
    if not active then return end
    if not C.Active() then C.Set(C.OVERLAY) end
    local ok, why = pcall(function()
      arrange()
      navigation()
      focus()
      selector()
    end)
    if frame == 1 then C.Probe("soccer_vs_cpu_list_menu", "list opened") end
    if frame == 60 then   -- once, when the picker is up
      C.Log("picker heartbeat", frame, "overlay", C.Active(), "class", C.M(2231168902, C.CLASS))
    end
    if not ok and frame % 60 == 1 then C.Log("list layout error", tostring(why)) end
  end
  -- the retail heading's crest, class and level nodes hidden again right after the list's own focus change redraws
  -- them (node visibility only; the game's calls run unchanged)
  local HEADING = 1835074715
  local HEADING_NODES = { 574244154, 126765991, 2841109264 }
  local function heading_hidden()
    if not C.Active() then return end
    for _, node in ipairs(HEADING_NODES) do C.M(3405944500, HEADING, node, false, 0) end
  end
  -- the mouse zone stays invisible through its opening
  local function hit_hidden(layer)
    if layer == HIT then C.M(4231609516, HIT, 0, 0, 0) end
  end
  if VRFW_Host then
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", { id = "better_menu.competition.list_init", phase = "after",
      fn = function()
        frame, changed, last, sent, laid_out, text_cache = 0, 0, nil, nil, false, {}
        formation_key = nil
        catalogue, catalogue_tab, enumerating, crest_cache = {}, nil, false, {}
        crest_place, crest_opening, crest_misses = {}, {}, {}
        key_ticks = {}
        season_tab = nil
        last_action, last_action_frame = nil, -10
        C.Clear(UI_READY)
        strip_notified, input_opened = false, false
        hit_state = nil
      end })
    -- a crest slot's opening ended: its place again (event; the opening animation moves it to the layout's spot)
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnOpenEndLayer", { id = "better_menu.competition.crest_placed", phase = "after",
      create = true, fn = function(layer, i) crest_opened(layer, i) input_hidden(layer) hit_hidden(layer) end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnOpenLayer", { id = "better_menu.competition.probe_track", phase = "after",
      create = true, fn = function(layer, i) C.ProbeTrack(layer, i) input_hidden(layer) hit_hidden(layer) end })
    -- the mouse zone: a hover keeps the centred team (it is the focus already); a click decides as Enter does
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", { id = "better_menu.competition.mouse_hover", phase = "before",
      priority = -1100, fn = function(layer)
        if layer ~= HIT then return end
        return VRFW_Host.HALT
      end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnDecideFocus", { id = "better_menu.competition.mouse_click", phase = "before",
      priority = -200, fn = function(layer)
        if layer ~= HIT then return end
        if C.Active() and C.M(2231168902, C.CLASS) ~= true then
          C.Log("mouse click: the centre crest decides")
          if type(OnEnter) ~= "function" or OnEnter(1107559438, 0) ~= 1 then OnDecideFocus(1107559438, 0) end
        end
        return VRFW_Host.HALT
      end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", { id = "better_menu.competition.heading_hidden", phase = "after",
      fn = function() heading_hidden() end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", { id = "better_menu.competition.catalogue", phase = "before", priority = -1000,
      fn = function() if enumerating then return VRFW_Host.HALT end end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "PostStep", { id = "better_menu.competition.list_step", phase = "after", create = true, fn = tick })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnDecideFocus", { id = "better_menu.competition.reserve", phase = "around", priority = -100,
      fn = C.Capture })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnBack", { id = "better_menu.competition.back", phase = "around", fn = function(nxt, ...)
      if not C.Active() then return nxt(...) end
      -- no Back on the Competition list: it is the mode's own view (L2 / R2 leave it; owner 2026-10-19: Back took the
      -- focus down to the bottom row)
      return 1
    end })
    VRFW_Host.on("soccer_vs_cpu_list_menu", "OnFunction", { id = "better_menu.competition.modes", phase = "around", fn = function(nxt, id, ...)
      if C.Active() then
        if id == CONFIRM then
          if type(OnEnter) ~= "function" or OnEnter(1107559438, 0) ~= 1 then OnDecideFocus(1107559438, 0) end
          return
        end
        if id == previous or id == following then BetterMenuCompetitionNavigate(id == previous and "left" or "right") return end
        if id == season_previous or id == season_following then BetterMenuCompetitionNavigate(id == season_previous and "season_left" or "season_right") return end
      end
      if C.Active() and (id == 2155540576 or id == 951543817) then
        C.F(830228314, C.TITLE, "BetterMenuCompetitionMode", id == 2155540576 and -1 or 1)
        return
      end
      return nxt(id, ...)
    end })
  end
end
