-- Home Stadium (module of Football Reforged; docs/game/mods/home-stadium.md): the team dock's entry «Estadio local»
-- («Plantilla de equipo», soccer_team_dock_menu). Deciding it opens the game's stadium picker for the team on screen:
-- the stadium list window (view type 15, «Sin estadio local» first, then the owned stadiums with their names) with
-- the stadium picture frame beside it (win05_40_sub_image_frame, content\menus\home_stadium_picker.toml: the focused
-- stadium's picture, as the free match's picker shows it); the pick is saved for that team (CMND_HOMESTADIUM_SET).
--   * With BetterUI: a box like FORMACIÓN between TÁCTICAS and FORMACIÓN (content\menus\home_stadium_button.toml:
--     a copy of the FORMACIÓN box's object) titled «ESTADIO», with the team's home stadium's name (or «Sin estadio
--     local»). BetterUI's dock panel places it on the panel's centre and moves the cursor (BetterUI.AddDockButton).
--   * Without it: one more row at the end of the dock's list. The list is the retail chunk's row kinds (one per row)
--     and texts (by kind: name, help line), edited where the dock's own functions read them (the upvalues of the live
--     SetupTeamDockListItem / SetupTeamDockListItemText, through the loader's EVT_DEBUG), before the list counts its
--     rows (the list layer's first OnSetupLayer).
-- The selector runs in a coroutine of this file: resumed by the button's step() (BetterUI), else by the dock's Step,
-- only while it is open. The button's text changes on events only (no periodic check).
-- The dock's callbacks are wrapped here directly (each wrapper calls the function it replaced). No engine call at load.
-- one line per VM that loads this file (queued by the framework host until its first callback: no engine call here)
if VRFW_Host ~= nil and type(VRFW_Host.note) == "function" then
  VRFW_Host.note("soccer_team_dock_menu", "home_stadium: dock file loaded (HomeStadium " .. type(HomeStadium)
    .. ", BetterUI.AddDockButton " .. type(type(BetterUI) == "table" and BetterUI.AddDockButton or nil) .. ")")
end
if type(HomeStadium) == "table" and type(HomeStadium.owned) == "function" then
  local H = HomeStadium
  local K = {
    MENU = 937147172,           -- soccer_team_dock_menu
    LIST = 3367997069,          -- team01_02_list_item
    BUTTON = 72691397,          -- home_stadium_dock_button (BetterUI only)
    CURSOR = 2296367164,        -- cmn05_01_cursor
    SUB_WINDOW = 968210065,     -- sub_window
    SUB_LIST = 3620912440,      -- win05_29_sub_list_locator
    SUB_ITEM = 3307470771,      -- win05_30_sub_list_item
    FRAME = 2817282936,         -- win05_40_sub_image_frame (the selector's stadium picture)
    IMG_NODE = 2351399094,      -- _tutorial_img01 (the picture mesh of both frames)
    IMG_SPRITE = 1348394297,    -- tutorial_img01
    KIND = 64,                  -- the row's kind in the list (retail kinds 0..12, Pachangas' format row 13)
    TEXT_ROW = 1315927915,      -- home_stadium.row
    TEXT_HELP = 1624841304,     -- home_stadium.row_help
    TEXT_NONE = 3023826114,     -- home_stadium.none
    -- the button (a copy of the FORMACIÓN box): its title slot gets the retail «ESTADIO», its text the stadium's name
    TITLE_ATLAS = 4231227197,   -- #/menu/107_vs/vs01/vs01_21/<LG>/vs01_21.g4tx (a menu resource of the dock, the button's toml)
    TITLE = 1065353421,         -- gtxt_stadium01
    TITLE_SLOT = 3259336903,    -- gtxt_formation01
    NAME_NODE = 1509045176,     -- _text_formation01
    BOX = 1083262227,           -- _base_formation01 (layout (-403, -24), 410 x 76: BetterUI's scale reference)
    BOX_BLANK = 579557469,      -- _base_formation_blank_stop01 (the flat grey plate the retail hides)
    FORM_BOX = 3286546665,      -- team00_12_formation_style (FORMACIÓN, the box the button copies)
    MAP_NAME = 3763041341,      -- CMND_GET_MAP_NAME (map)
    TEXT_GET = 4074371074,      -- CMND_TEXT_GET (id)
    POS_X = 534, POS_Y = -206,  -- the window's place: the retail stadium picker's (soccer_vs_mydock_option_menu)
    WAIT = 300,                 -- frames a window step may take
    SE_NO = 2086672038,         -- sy0003
    SOUND = 1917805374,
    EXIST_LAYER = 262659071,    -- CMND_IS_EXIST_LAYER (layer)
    IS_OPEN = 2640875187,       -- CMND_IS_OPEN_LAYER (layer[, idx])
    STADIUM_TEXTURE = 1232438844,   -- (2, map) -> ok, the stadium picture (GetStadiumTextureInfo of the pickers)
    FRAME_PICTURE = 952390423,  -- (layer, idx, node, map, picture, sprite): a stadium picture into a frame
    NODE_POS = 2575768773,      -- (layer, idx, node, axis 0 x / 1 y, value)
    NODE_SCALE = 2885415772,    -- (layer, idx, node, sx, sy)
    LOG_ONCE = 3,
  }
  local S = { owned = nil, set = -1, kinds = nil, logged = false, co = nil, from = nil,
    titled = false, shownSet = nil, shown = nil, logs = 0, steps = 0 }

  local function once(...)
    if S.logs < K.LOG_ONCE * 4 then
      S.logs = S.logs + 1
      H.log(...)
    end
  end

  local function wait(test)
    for _ = 1, K.WAIT do
      local ok, done = pcall(test)
      if ok and done then return true end
      coroutine.yield()
    end
    return false
  end

  local function is_open(layer)
    local ok, yes = pcall(funcLuaMenuCommand, K.IS_OPEN, layer, 0)
    return ok and yes == true
  end

  local function has_button()
    local ok, yes = pcall(funcLuaMenuCommand, K.EXIST_LAYER, K.BUTTON)
    return ok and yes == true
  end

  -- the first upvalue of the live global function `name` (or of the functions it wraps, 4 levels) for which pred holds
  local function upvalue(name, pred)
    local D = EVT_DEBUG
    if D == nil then return nil end
    local seen = {}
    local function scan(f, depth)
      if type(f) ~= "function" or seen[f] or depth > 4 then return nil end
      seen[f] = true
      local i = 1
      while true do
        local n, v = D.getupvalue(f, i)
        if n == nil then return nil end
        if pred(v, n) then return v end
        if type(v) == "function" then
          local r = scan(v, depth + 1)
          if r ~= nil then return r end
        end
        i = i + 1
      end
    end
    return scan(rawget(_ENV, name), 0)
  end

  local function is_kinds(v)
    if type(v) ~= "table" or v[0] ~= nil or #v < 1 or #v > 16 then return false end
    for _, k in ipairs(v) do
      if type(k) ~= "number" then return false end
    end
    return true
  end

  local function is_texts(v)
    return type(v) == "table" and type(v[1]) == "table" and v[1].itemExplation ~= nil
  end

  -- the team set on screen: the dock's n5 (the first number the live UpdateTeamDockNo reads; a text-compiled copy
  -- names it), else the framework host's map of the retail locals
  local function shown_set()
    local named = upvalue("UpdateTeamDockNo", function(v, n) return n == "n5" and type(v) == "number" end)
    if type(named) == "number" then return named end
    local first = upvalue("UpdateTeamDockNo", function(v) return type(v) == "number" end)
    if type(first) == "number" then return first end
    local h = VRFW_Host and VRFW_Host.hosts and VRFW_Host.hosts.soccer_team_dock_menu
    local L = h and h.L
    return L and L.n5
  end

  -- a stadium's picture into a frame layer (its _tutorial_img01); false = no picture for that map
  local function picture(layer, map)
    local ok, has, pic = pcall(funcLuaCommand, K.STADIUM_TEXTURE, 2, map)
    if not ok or has ~= true then return false end
    return (pcall(funcLuaMenuCommand, K.FRAME_PICTURE, layer, 0, K.IMG_NODE, map, pic, K.IMG_SPRITE))
  end

  -- the button's look when the dock's focus is not on it, as the retail FORMACIÓN box opens (its «Focus» animation out,
  -- the green cursor not on it): the copied box started with the focused look (owner 2026-10-19). From then on the
  -- dock's own focus moves (OnFocusLayerShift, BetterUI's CHD_Go) play its focus in / out.
  local function idle_look(why)
    local okf, focused = pcall(funcLuaMenuCommand, 102308320 --[[CMND_IS_CTRL_FOCUS_ACTIVE]], K.BUTTON)
    if okf and focused == true then return end
    pcall(funcLuaMenuCommand, 3781155141 --[[CMND_PLAY_ANIME_TYPE]], K.BUTTON, 0, 2734777837 --[[Focus]], 2,
      973515837 --[[button]])
    pcall(funcLuaMenuCommand, 1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE]], K.BUTTON, 0, 3313461902 --[[cursor]],
      false)
    pcall(funcLuaMenuCommand, 1778826357 --[[focus mark]], K.BUTTON, 0, false)
    once("dock button: unfocused look (" .. tostring(why) .. ")")
  end

  -- the button (BetterUI): the «ESTADIO» title once, and the name of the stadium the team plays at home in its text
  -- («Sin estadio local» when none). Run on the events that change it only: the layer's setup / open (dock open,
  -- save loaded), the dock's team switch (UpdateTeamDockNo), a pick; skipped when nothing changed (team, stadium).
  local function dress(why)
    if not is_open(K.BUTTON) then return end
    -- the box itself as the retail SetupFormationStyle shows FORMACIÓN's: its translucent plate on, the flat grey
    -- «blank / stop» plate off (the copied object shows both until the retail code picks one: the grey box of 1.2.2),
    -- drawn at FORMACIÓN's own priority (its text one above, as the retail OnSetupLayer sets them)
    pcall(funcLuaMenuCommand, 3405944500 --[[CMND_SET_MESH_VISIBLE]], K.BUTTON, K.BOX, true, 0)
    pcall(funcLuaMenuCommand, 3405944500 --[[CMND_SET_MESH_VISIBLE]], K.BUTTON, K.BOX_BLANK, false, 0)
    local okp, prio = pcall(funcLuaMenuCommand, 1018283794 --[[CMND_GET_DRAW_PRIORITY]], K.FORM_BOX, 0)
    if okp and type(prio) == "number" then
      pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], K.BUTTON, 0, prio)
      pcall(funcLuaMenuCommand, 1848885328 --[[CMND_SET_MENU_TEXT_PRIORITY]], K.BUTTON, 0, K.NAME_NODE, prio + 1)
    end
    if not S.titled then
      S.titled = true
      local ok = pcall(funcLuaMenuCommand, 558735651 --[[sprite of a material slot]], K.BUTTON, K.TITLE_ATLAS, K.TITLE,
        K.TITLE_SLOT, 0, 0)
      once("dock button: title", ok and "set" or "refused", "(" .. tostring(why) .. ")")
    end
    local set = shown_set()
    if type(set) ~= "number" then return end
    local map = H.get(set)
    if S.shownSet == set and S.shown == map then return end
    S.shownSet, S.shown = set, map
    local name
    if map ~= 0 then
      local ok, n = pcall(funcLuaCommand, K.MAP_NAME, map)
      name = (ok and type(n) == "string") and n or nil
    end
    if name == nil then
      local ok, n = pcall(funcLuaCommand, K.TEXT_GET, K.TEXT_NONE)
      name = (ok and type(n) == "string") and n or ""
    end
    pcall(funcLuaMenuCommand, 1083631230 --[[CMND_SET_MENU_TEXT_STRING]], K.BUTTON, K.NAME_NODE, name, 0)
    once("dock button: team", set, "stadium", string.format("0x%08X", map), "(" .. tostring(why) .. ")")
  end

  -- the row (no BetterUI button): one more kind at the end of the live list, with its name and help line
  local function add_row()
    if has_button() then return end
    local kinds = upvalue("SetupTeamDockListItem", is_kinds) or upvalue("UpdateViewTeamDockListItem", is_kinds)
    local texts = upvalue("SetupTeamDockListItemText", is_texts) or upvalue("OnChangeFocus", is_texts)
    if kinds == nil or texts == nil then
      if not S.logged then
        S.logged = true
        H.log("dock row: the list tables were not found (no EVT_DEBUG?): no «Estadio local» row")
      end
      return
    end
    S.kinds = kinds
    texts[K.KIND + 1] = { itemName = K.TEXT_ROW, itemExplation = K.TEXT_HELP }
    for _, kind in ipairs(kinds) do
      if kind == K.KIND then return end
    end
    table.insert(kinds, K.KIND)
    if not S.logged then
      S.logged = true
      H.log("dock row added", #kinds, "row(s)")
    end
  end

  -- the selector's picture of the focused row (0 = «Sin estadio local»: none)
  local function show_picture(row)
    local st = S.owned and S.owned[row]
    if not is_open(K.FRAME) then return end
    local ok = st ~= nil and picture(K.FRAME, st.map)
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], K.FRAME, 0, ok == true)
  end

  -- the window's callbacks: a row (0 = none) or -1 (back); the focused row
  function HomeStadium_DockClose(row)
    if type(row) == "number" and row >= 0 and S.owned ~= nil then
      local st = S.owned[row]
      local map = st and st.map or 0
      if H.set(S.set, map) then
        H.log("team", S.set, "home stadium", string.format("0x%08X", map))
      else
        pcall(funcLuaCommand, K.SOUND, K.SE_NO)
      end
    end
    pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], K.SUB_WINDOW)
  end

  function HomeStadium_DockFocus(row)
    if type(row) ~= "number" or row < 0 then return end
    local ok, focused = pcall(funcLuaMenuCommand, 1727549139, K.SUB_LIST, K.SUB_WINDOW)
    show_picture((ok and type(focused) == "number") and focused or row)
  end

  local function pick(a1)
    local set = shown_set()
    local function back()
      pcall(funcLuaMenuCommand, 1273612389 --[[CMND_CLOSE_LAYER]], K.FRAME, 0)
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], K.CURSOR, 0, true, K.MENU)
      funcLuaMenuCommand(1558704558, K.MENU, true)
      funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], a1, true)
      pcall(dress, "pick")       -- the button picture follows the pick
    end
    if type(set) ~= "number" or set < 0 then
      H.log("dock: no team on screen")
      pcall(funcLuaCommand, K.SOUND, K.SE_NO)
      back()
      return
    end
    local owned = H.owned()
    local current = H.get(set)
    local rows, focus = { K.TEXT_NONE }, 0
    for i, st in ipairs(owned) do
      rows[#rows + 1] = st.map
      if st.map == current then focus = i end
    end
    S.owned, S.set = owned, set
    H.log("team", set, "selector:", #owned, "owned stadium(s), current", string.format("0x%08X", current))
    funcLuaMenuCommand(1558704558, K.MENU, false)
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], K.CURSOR, 0, false, K.MENU)
    MENU_DEF.OpenSubWindow("HomeStadium_DockClose", "HomeStadium_DockFocus", #rows, rows, 9, 0, {}, focus, false,
      false, 15, 0, {}, focus)
    for i, st in ipairs(owned) do
      funcLuaCommand(2315959435, i, st.name)
    end
    pcall(funcLuaMenuCommand, 629267548 --[[CMND_OPEN_LAYER]], K.FRAME, 0)
    wait(function()
      return funcLuaMenuCommand(K.IS_OPEN, K.SUB_LIST, 0, K.SUB_WINDOW)
    end)
    funcLuaCommand(63483614, K.POS_X, K.POS_Y)
    wait(function() return funcLuaCommand(3444627471, K.SUB_LIST) end)
    funcLuaCommand(3647847018, focus, K.SUB_LIST)
    if type(UpdateVisibleSubWindowListItemCheckMesh) == "function" then
      local okc, shown = pcall(funcLuaMenuCommand, 3497892782, K.SUB_LIST, focus, K.SUB_WINDOW)
      if okc then pcall(UpdateVisibleSubWindowListItemCheckMesh, K.SUB_ITEM, shown) end
    end
    show_picture(focus)
    wait(function() return funcLuaCommand(1521844538 --[[CMND_IS_CLOSE_MENU_OBJECT]], K.SUB_WINDOW) end)
    S.owned = nil
    back()
  end

  -- the selector starts in a coroutine of this file (button decide, OnEnter, OnDecideFocus), one at a time
  local function start(a1, why)
    if S.co ~= nil then return true end
    H.log("dock: selector requested by", why)
    S.from = a1
    S.co = coroutine.create(function() pick(a1) end)
    return true
  end

  local function tick()
    if S.co == nil then return end
    local ok, err = coroutine.resume(S.co)
    if not ok then
      H.log("dock: selector error", tostring(err))
      pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], K.SUB_WINDOW)
      pcall(funcLuaMenuCommand, 1273612389 --[[CMND_CLOSE_LAYER]], K.FRAME, 0)
      pcall(funcLuaMenuCommand, 1558704558, K.MENU, true)
      pcall(funcLuaMenuCommand, 3518307824, S.from, true)
    end
    if not ok or coroutine.status(S.co) == "dead" then
      S.co = nil
    end
  end

  -- the button (BetterUI): its step drives the picture and the selector; its decide starts the selector
  local install                     -- defined below (the button's step() may call it first)
  local button = false
  if type(BetterUI) == "table" and type(BetterUI.AddDockButton) == "function" then
    button = BetterUI.AddDockButton({
      id = "home_stadium.dock", layer = K.BUTTON, help = K.TEXT_HELP, column = "panel",
      mesh = { node = K.BOX, x = -403, y = -24 }, center = { x = -198, y = -46.5 },   -- the box + title's centre
      step = function()             -- drives the selector's coroutine only (nothing to do while it is closed)
        if not S.installed then install("first button step") end
        S.steps = S.steps + 1
        tick()
      end,
    }) == true
  end

  -- the dock's callbacks, wrapped (each wrapper calls what it replaced). Installed LATE, once every patch of the dock
  -- has loaded: a later root (Pachangas' pachanga_dock) redefines the dock's functions from the retail text, which
  -- dropped wrappers made at this file's load (1.1.x: none of them ever ran). install() runs at the framework host's
  -- first callback (@edit) or, with BetterUI, at the button's first step(), whichever comes first.
  local wraps = {}
  local function wrap(name, make)
    wraps[#wraps + 1] = {name, make}
  end
  install = function(why)
    if S.installed then return end
    S.installed = true
    local done = {}
    for _, w in ipairs(wraps) do
      local prev = rawget(_ENV, w[1])
      if type(prev) == "function" then
        rawset(_ENV, w[1], w[2](prev))
        done[#done + 1] = w[1]
      end
    end
    H.log("dock: callbacks wrapped (" .. tostring(why) .. "):", table.concat(done, ", "))
    pcall(idle_look, "install")
    pcall(dress, "install")
    pcall(add_row)
  end

  wrap("OnSetupLayer", function(prev)
    return function(a1, a2, ...)
      if a1 == K.LIST and a2 == 0 then
        pcall(add_row)
      end
      local r = table.pack(prev(a1, a2, ...))
      if button and a1 == K.BUTTON then
        -- as the retail FORMACIÓN box's setup: its draw / text priorities, one item
        pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2 or 0, 453)
        pcall(funcLuaMenuCommand, 1848885328 --[[CMND_SET_MENU_TEXT_PRIORITY]], a1, a2 or 0, K.NAME_NODE, 454)
        pcall(funcLuaMenuCommand, 3252599449, a1, 1)
        pcall(dress, "setup " .. tostring(a1))
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the button on its events: its layer opening (unfocused look, text), the dock's team switch
  wrap("OnOpenLayer", function(prev)
    return function(a1, a2, ...)
      local r = table.pack(prev(a1, a2, ...))
      if a1 == K.BUTTON then
        pcall(idle_look, "open")
        pcall(dress, "open " .. tostring(a1))
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  wrap("UpdateTeamDockNo", function(prev)
    return function(...)
      local r = table.pack(prev(...))
      if button then
        pcall(dress, "team switch")
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- the selector without the button (the list row): resumed by the dock's Step, unless the button's step drives it
  wrap("Step", function(prev)
    return function(...)
      local r = table.pack(prev(...))
      if not (button and S.steps > 0) then
        pcall(tick)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  wrap("OnEnter", function(prev)
    return function(a1, a2, ...)
      if a1 == K.BUTTON then
        start(a1, "OnEnter")
        return 1
      end
      return prev(a1, a2, ...)
    end
  end)

  wrap("OnDecideFocus", function(prev)
    return function(a1, a2, ...)
      if a1 == K.BUTTON then
        start(a1, "OnDecideFocus")
        return
      end
      if a1 == K.LIST and type(a2) == "number" and S.kinds ~= nil and S.kinds[a2 + 1] == K.KIND then
        start(a1, "the list row")
        return
      end
      return prev(a1, a2, ...)
    end
  end)

  if VRFW_Host ~= nil then
    VRFW_Host.on("soccer_team_dock_menu", "@edit", { id = "home_stadium.dock_install", fn = function() install("host") end })
  end
end
