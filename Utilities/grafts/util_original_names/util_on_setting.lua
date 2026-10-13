-- Utilities original_names, settings side (docs/game/ui/original-names.md §3-§5). Two parts, both on the
-- VR-Framework's host of setting_menu (VRFW_Host, docs/framework/lua-hosts.md):
--
-- 1. The PICKER. A on the game's «Nombres de los personajes» row (Utilities gives it Doblaje / Por equipos /
--    Originales) opens two levels:
--    a. TEAM GRID: the series' teams as Battle Bay emblem tiles (the VR-Framework's VRFW_EmblemGrid, lua\_all\
--       58_emblem_grid.lua) on Utilities' layers util_jpn_emblem / util_jpn_label (menus\108_option), [original_names
--       .team_grid] cols x rows a page, the team's name and «k/n» (players chosen / players) under each tile, the check
--       mark when every player is chosen, a neutral plate for a team without an emblem. One page per series: Q / E
--       (CMD_FUNCL2 / R2) change it. Arrows / mouse move, L1 / R1 (wheel) the grid page, A opens the team's player grid,
--       Y switches the whole team (all on, or all off when all are on), B saves the selection
--       (CMND_UTIL_NAMES_PICK_CLOSE: mod_options\utilities.json, the row's draft becomes «Por equipos» when something is
--       chosen) and the retail «¿Aplicar los cambios?» follows as for any change. The guide box shows «‹ series k/n ›
--       · team k/n» and the keys. The settings list is hidden while the grids show.
--    b. PLAYER GRID: the team's players as faces on Utilities' layer util_jpn_face (menus\108_option), [original_names
--       .grid] cols x rows a page: GREY = keeps the dub name, normal colour = shows the original name; the name each
--       one shows now under the face. Keys (polled: the settings menu's input is off while the picker is open):
--       arrows move, A toggles, Y (CMD_FUNC3) the whole team (all on, or all off when all are on), L1 / R1 the grid
--       page, B / right click back to the team grid. Mouse: hover moves, click toggles, the wheel turns the page. The
--       guide box at the bottom shows «team  k/n», the player under the cursor (dub → original) and the keys. The
--       settings list is hidden while the grid shows. No face layer installed (Instalar) = the grid refuses (logged).
--    The data comes from the mod's script (CMND_UTIL_NAMES_PICK_*: the game's series / team / character tables + the
--    mods' card-filter declarations).
-- 2. The RELOAD. The names are text tables (Utilities serves them and redirects the engine's opens of chara_text /
--    team_text), so, like the retail «Originales», a change needs the game's text reload. The retail script does it
--    for «Originales» only (flag3 = SetSelectIsChangeToRomaji(last value) ~= flag2 = the byte at the menu's opening;
--    IsChangedLanguage -> flag4; CloseMenuSetting stores the text-language key 0x5ED32A31, setting_top_menu sees it and
--    goes back to the title, title_main's language-change state reloads the texts). Here, before CloseMenuSetting
--    runs, the script says whether the loaded tables still match the saved choices (CMND_UTIL_NAMES_RELOAD); if not,
--    the same locals are set (flag4 = true; flag3 = not flag2 when the text language did not change, else the retail
--    language change already reloads) and the retail code does the rest. n = 1 / 2 / 4 (another menu opens from the
--    settings) and 3 are left alone: asked again at the real close. Without the host's locals (no EVT_DEBUG) a change
--    applies at the next start (logged once).
-- No engine call at load time. Names: Utilities.OriginalNames (state, functions); the sub window's callbacks are
-- globals named "Utilities.OriginalNames.<Fn>" (and reachable as that path).
Utilities = Utilities or {}
Utilities.OriginalNames = {
  C = {
    RELOAD = 1788063632,       -- CMND_UTIL_NAMES_RELOAD
    ROW = 2591386978,          -- CMND_UTIL_NAMES_ROW
    OPEN = 776756195,          -- CMND_UTIL_NAMES_PICK_OPEN
    GRID = 2753298800,         -- CMND_UTIL_NAMES_PICK_GRID
    TAB = 720562231,           -- CMND_UTIL_NAMES_PICK_TAB
    ITEM = 2502425945,         -- CMND_UTIL_NAMES_PICK_ITEM
    TEAM = 1323073112,         -- CMND_UTIL_NAMES_PICK_TEAM
    TEAM_GRID = 746240482,    -- CMND_UTIL_NAMES_PICK_TEAM_GRID
    PLAYER = 29587223,         -- CMND_UTIL_NAMES_PICK_PLAYER
    TOGGLE = 3157303545,       -- CMND_UTIL_NAMES_PICK_TOGGLE
    CLOSE = 3227339239,        -- CMND_UTIL_NAMES_PICK_CLOSE
    LOG = 3661580131,          -- CMND_EVT_LOG
    TEXT_LANG = 2470508080,    -- the current text language code (the retail script's n6 / n7 default)
    LANG = 477234096,          -- CMND_GET_LANGUAGE_CODE
    TEXT_GET = 4074371074,     -- CMND_TEXT_GET
    SND = 3073642526,          -- CMND_SND_PLAY
    IS_OPEN = 3693934564,      -- CMND_IS_OPEN_MENU_OBJECT
    IS_CLOSE = 1521844538,     -- CMND_IS_CLOSE_MENU_OBJECT
    CLOSE_OBJ = 320421347,     -- CMND_CLOSE_MENU_OBJECT
    SET_STR = 2315959435,      -- the sub window's item string (SetStringBufDirect)
    CALL = 830228314,          -- call a function of another menu's script
    LAYER_VISIBLE = 711242136, -- CMND_SET_LAYER_VISIBLE (layer, instance, on)
    FOCUS_IDX = 1727549139,    -- focused cell of a list
    CHECK_INPUT = 4265778440,  -- CMND_CHECK_INPUT_CMD (control, input)
    LAYER_NUM = 1175615627,    -- CMND_GET_CREATE_LAYER_NUM (layer)
    OPEN_LAYER = 629267548,    -- CMND_OPEN_LAYER (layer, instance)
    LOCAL_POS = 1389957207,    -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, instance)
    LOCAL_SCALE = 3778714801,  -- CMND_SET_LAYER_LOCAL_SCALE (layer, x, y, z, instance)
    MESH_VISIBLE = 3405944500, -- (layer, mesh, on, instance)
    NODE_VISIBLE = 2158717427, -- (layer, node, on, instance)
    TEXT_VISIBLE = 2735666188, -- (layer, text node, on, instance)
    SET_TEXT = 1083631230,     -- (layer, text node, string, instance)
    COLOR = 801406373,         -- material colour (layer, instance, material, r, g, b)
    RESET_FACE = 4176779611,   -- ResetFaceIcon (layer, instance, texture node)
    FACE = 552280324,          -- chara icon (layer, instance, face only, mesh, texture node, 0, 0, key, kit, keeper, use args)
    LOADING = 1277042906,      -- the instance's textures are still loading (layer, instance)
    POINTER = 558229292,       -- the pointer's position (screen px, y down)
    POINTER_MOVED = 3272825600,
  },
  SUB_WINDOW = 968210065,      -- sub_window
  CURSOR = 2296367164,         -- cmn05_01_cursor
  LIST_ATTACH = 2081113831,    -- option01_01_list_attach
  LIST_ITEM = 3344436024,      -- option01_02_list_item (10 instances)
  LIST_ITEMS = 10,
  GUIDE = 2794225234,          -- option01_05_guide_base
  GUIDE_TEXT = 378156699,      -- _text_guide01
  SUB_ITEM = 224873246,        -- win05_02_sub_list_item15 (the items of sub window type 12)
  WINDOW_TYPE = 12,
  TITLE = 1973155428,          -- crc32("utilities.names_picker_title")
  TAB_TEXT = 3639916683,       -- crc32("utilities.names_picker_tab"): «<L2> ‹ %s  %d/%d › <R2>»
  TEAMS_HINT = 4031679028,     -- crc32("utilities.names_teams_hint"): the team grid's keys
  EMBLEM_LAYER = 3134807334,   -- util_jpn_emblem (the framework's vrfw_emblem_tile, menus\108_option)
  LABEL_LAYER = 3923348891,    -- util_jpn_label (the framework's vrfw_tile_label)
  INFO_TEXT = 2630052984,      -- crc32("utilities.names_grid_info"): «%s  %d/%d  ·  %s»
  HINT_TEXT = 1670143612,      -- crc32("utilities.names_grid_hint"): the grid's keys
  SY_MOVE = 2500047763,        -- sy0005
  SY_ERROR = 2086672038,       -- sy0003
  -- the inputs polled while the grid shows (CMND_CHECK_INPUT_CMD on the menu controls; docs/game/engine/save-slots.md)
  CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]},
  KEYS = {up = 1197218715, down = 3259546669, left = 2765147006, right = 2075023265, enter = 1981080283,
          back = 3011112225 --[[CMD_BACK]], all = 3421673595 --[[CMD_FUNC3]], l1 = 3966226594 --[[CMD_FUNCL1]],
          r1 = 942075773 --[[CMD_FUNCR1]], rclick = 3473063670 --[[CMD_MOUSE_RIGHT_CLICK]],
          click = 218912913 --[[CMD_EVT_MOUSE_LEFT]], wup = 1942756954 --[[CMD_EVT_WHEEL_UP]],
          wdown = 1623431741 --[[CMD_EVT_WHEEL_DOWN]]},
  REPEAT_FIRST, REPEAT_EVERY = 18, 5,
  -- the face layer (menus\108_option\setting_menu_jp_names.toml): a copy of the retail character card team00_01;
  -- only its portrait (a 156 px quad whose centre is (59, 11) from the card's origin) and its name text show
  FACE_LAYER = 3286503273,     -- util_jpn_face
  FACE_MESH = 2828003679,      -- _icon_chr_dmy_l01
  FACE_TEX = 21929195,         -- icon_chr_dmy_l01
  FACE_FOCUS = 3345942320,     -- _icon_chr_focus_l01 (the card's own focus frame: the cursor)
  FACE_NAME = 170976702,       -- _text_chr01
  GRAY = 643056375,            -- gray_out (the card's grey-out material)
  FACE_RH, FACE_OX, FACE_OY = 156, 59, 11,
  FOCUS_SCALE = 1.12,
  FACE_WAIT = 120,             -- frames a requested face waits for its textures before it is shown anyway
  BUILD_WAIT = 30,             -- frames an opened instance may take to be built before its face is asked for anyway
  -- every other quad / node of the card, hidden on each tile (names: crc32 at run time)
  HIDE_MESHES = {"_icon_chr_base_l01", "_icon_chr_gradation_l01", "_seasonal_frame_l01", "_avatar_frame_l01",
    "_icon_chr_position_dmy_l01", "_icon_base_l01", "_icon_chr_type_dmy_l01", "_icon_lock01", "_icon_captain01",
    "_icon_ai_role_dmy01", "_gtxt_lv_l01", "_icon_card01", "_icon_chr_def01_l", "_icon_chr_grayout01",
    "_basara_avatar_l01", "_num_chr_dmy_l01", "_num_chr_dmy_l02", "_gauge_exp_base_l01", "_gauge_exp_l01",
    "_icon_synergy_l01", "_icon_synergy_l02", "_leader_base01", "_gtxt_leader01"},
  HIDE_NODES = {"_pos_base02", "_pos_leader01", "_pos_ai_role01", "_num_chr_l01", "_num_chr_l02", "_pos_gauge_exp_l01"},
  noted = false,
  labels = {},                 -- list cell -> the label text it shows (UpdateListItem)
  state = nil,                 -- nil | "opening" | "open" | "switch" | "to_grid" | "grid" | "closing"
  grid = nil,                  -- the open grid (Utilities.OriginalNames.GridOpen)
  built = {},                  -- face instance -> frame of its OnOpenLayer (this menu session)
  opened = {},                 -- face instances opened this menu session
  frame = 0,
}

function Utilities.OriginalNames.Log(...)
  pcall(funcLuaCommand, Utilities.OriginalNames.C.LOG, "utilities original_names", ...)
end

function Utilities.OriginalNames.Text(id, fallback)
  local ok, s = pcall(funcLuaCommand, Utilities.OriginalNames.C.TEXT_GET, id)
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return fallback
end

function Utilities.OriginalNames.Fmt(id, fallback, ...)
  local ok, s = pcall(string.format, Utilities.OriginalNames.Text(id, fallback), ...)
  if ok then
    return s
  end
  return (pcall(string.format, fallback, ...)) and string.format(fallback, ...) or fallback
end

function Utilities.OriginalNames.Sub(fn, ...)   -- a function of the sub window's script
  local N = Utilities.OriginalNames
  return pcall(funcLuaCommand, N.C.CALL, N.SUB_WINDOW, fn, ...)
end

function Utilities.OriginalNames.M(cmd, ...)    -- a menu command, errors swallowed
  local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then
    return a, b
  end
  return nil
end

-- ---- the team emblem grid -----------------------------------------------------------------------------------------

-- the focused cell of the settings list shows the names row (its label text = the row's label, CMND_UTIL_NAMES_ROW)
function Utilities.OriginalNames.IsNamesRow()
  local N = Utilities.OriginalNames
  local okL, label = pcall(funcLuaCommand, N.C.ROW)
  if not okL or type(label) ~= "number" or label == 0 then
    return false
  end
  local okF, cell = pcall(funcLuaMenuCommand, N.C.FOCUS_IDX, N.LIST_ATTACH)
  if not okF or type(cell) ~= "number" or N.labels[cell] == nil then
    return false
  end
  if N.row_text == nil then
    N.row_text = N.Text(label, false)
  end
  return N.row_text ~= false and N.labels[cell] == N.row_text
end

-- the framework's team emblem grid on this menu's layers util_jpn_emblem / util_jpn_label (nil: the framework's piece
-- or the layers are not there)
function Utilities.OriginalNames.TeamsGrid()
  local N = Utilities.OriginalNames
  if N.eg == nil then
    if type(VRFW_EmblemGrid) ~= "table" or type(VRFW_EmblemGrid.New) ~= "function" then
      N.Log("team grid: VRFW_EmblemGrid missing (VR-Framework too old)")
      return nil
    end
    local okG, cols, rows, px, py, cx, cy = pcall(funcLuaCommand, N.C.TEAM_GRID)
    if not okG or type(cols) ~= "number" then
      cols, rows, px, py, cx, cy = 8, 3, 210, 236, 960, 520
    end
    N.eg = VRFW_EmblemGrid.New({tile = N.EMBLEM_LAYER, label = N.LABEL_LAYER, cols = cols, rows = rows, px = px,
                                py = py, cx = cx, cy = cy, log = N.Log})
  end
  if not N.eg.ok then
    N.Log("team grid: layer util_jpn_emblem not in the settings menu: Instalar")
    return nil
  end
  return N.eg
end

-- team row i of the page as a grid item
function Utilities.OriginalNames.TeamItem(i)
  local N = Utilities.OriginalNames
  local ok, tname, on, n, emblem = pcall(funcLuaCommand, N.C.ITEM, i)
  if not ok or type(tname) ~= "string" then
    return {name = "?", count = "", emblem = 0}
  end
  on, n = type(on) == "number" and on or 0, type(n) == "number" and n or 0
  return {name = tname, count = string.format("%d/%d", on, n), emblem = type(emblem) == "number" and emblem or 0,
          full = n > 0 and on == n}
end

-- the guide box under the team grid: «<L2> ‹ series  k/n › <R2>  ·  team  k/n» and the keys
function Utilities.OriginalNames.TeamsGuide()
  local N = Utilities.OriginalNames
  local eg, s = N.eg, N.series or {}
  local head = N.Fmt(N.TAB_TEXT, "‹ %s  %d/%d ›", tostring(s.name or ""), s.on or 0, s.n or 0)
  local it = eg and eg.items[eg:Sel()] or nil
  if it ~= nil then
    head = head .. "   ·   " .. it.name .. "  " .. it.count
  end
  local page, pages = eg:Page()
  if pages > 1 then
    head = head .. string.format("  (%d/%d)", page + 1, pages)
  end
  N.Guide(head .. "\n" .. N.Text(N.TEAMS_HINT, "A / Y / Q E / B"))
end

-- the page `dir` away (0 = the same one), its teams on the grid
function Utilities.OriginalNames.ShowTab(dir)
  local N = Utilities.OriginalNames
  local eg = N.TeamsGrid()
  if eg == nil then
    return N.RowsShow(dir)                -- no emblem layers: the game's check-list window
  end
  local ok, page, name, on, n, rows = pcall(funcLuaCommand, N.C.TAB, dir)
  if not ok or type(page) ~= "number" or type(rows) ~= "number" then
    N.Log("picker: no page")
    funcLuaCommand(N.C.SND, N.SY_ERROR)
    N.Finish()
    return false
  end
  N.series = {name = tostring(name), on = on or 0, n = n or 0}
  local items = {}
  for i = 1, rows do
    items[i] = N.TeamItem(i)
  end
  N.ListVisible(false)
  N.state = "teams"
  eg:Open(items, N.focus or 1)
  N.TeamsGuide()
  return true
end

function Utilities.OriginalNames.Open()
  local N = Utilities.OriginalNames
  local okL, lang = pcall(funcLuaCommand, N.C.LANG)
  local ok, pages = pcall(funcLuaCommand, N.C.OPEN, okL and lang or -1)
  if not ok or type(pages) ~= "number" or pages < 1 then
    return false
  end
  N.focus = 1
  SetInputEnbaleMenuObject(false)
  if not N.ShowTab(0) then
    return false
  end
  N.Log("picker opened: " .. tostring(pages) .. " page(s)")
  return true
end

-- per frame while the team grid shows
function Utilities.OriginalNames.TeamsStep()
  local N = Utilities.OriginalNames
  local eg = N.eg
  local before = eg:Sel()
  local ev = eg:Step()
  if eg:Sel() ~= before then
    N.TeamsGuide()
  end
  if ev == nil then
    return
  end
  if ev.act == "back" then
    funcLuaCommand(N.C.SND, N.SY_MOVE)
    N.Finish()
  elseif ev.act == "series" then
    funcLuaCommand(N.C.SND, N.SY_MOVE)
    N.focus = 1
    N.ShowTab(ev.dir)
  elseif ev.act == "decide" then
    N.team, N.focus = ev.index, ev.index
    eg:Hide()
    if N.FaceLayerOk() and N.GridOpen(ev.index) then
      return
    end
    if not N.PlayersShow(ev.index) then  -- no face layer: the players as check-list rows
      funcLuaCommand(N.C.SND, N.SY_ERROR)
      N.ShowTab(0)
    end
  elseif ev.act == "all" then
    -- Y: the whole team on (or off when all are on), without opening it
    local okT, n = pcall(funcLuaCommand, N.C.TEAM, ev.index)
    local okS, state = pcall(funcLuaCommand, N.C.TOGGLE, 0)
    if not okT or type(n) ~= "number" or not okS or type(state) ~= "boolean" then
      funcLuaCommand(N.C.SND, N.SY_ERROR)
      return
    end
    funcLuaCommand(N.C.SND, N.SY_MOVE)
    local okP, _, _, on, total = pcall(funcLuaCommand, N.C.TAB, 0)
    if okP and type(on) == "number" then
      N.series.on, N.series.n = on, total or N.series.n
    end
    eg:Set(ev.index, N.TeamItem(ev.index))
    N.TeamsGuide()
  end
end

-- B on the teams: close, save, the row's new value
function Utilities.OriginalNames.Finish()
  local N = Utilities.OriginalNames
  if N.eg ~= nil then
    N.eg:Close()
  end
  N.grid, N.list = nil, nil
  N.ListRestore()
  N.Guide("")
  N.ListVisible(true)
  SetInputEnbaleMenuObject(true)
  local ok, changed, idx, text, last = pcall(funcLuaCommand, N.C.CLOSE)
  if ok and changed == true and type(idx) == "number" and idx >= 0 then
    local okC, cell = pcall(funcLuaMenuCommand, N.C.FOCUS_IDX, N.LIST_ATTACH)
    if okC and type(cell) == "number" then
      pcall(UpdateListContentText, cell, N.Text(text, ""), false, false, false, false, false)
    end
    pcall(SetSelectIsChangeToRomaji, last == true)
    N.Log("picker closed: row draft " .. tostring(idx))
  end
  N.state = nil
end

-- ---- fallback: the game's check-list sub window -------------------------------------------------------------------
-- When the grids' layers are not in the settings menu (another plugin served the menu file without them, an older
-- framework, not installed), the picker still works on the game's own check-list sub window (type 12, as Utilities
-- 1.3 - 1.7 did): the team rows of a page («<L2> ‹ series k/n › <R2>», then «team  k/n», ticked when full), and, when
-- the face layer is missing too, a team's players as rows («dub → original», ticked = original name; A switches).

function Utilities.OriginalNames.ListOpen(kind, strs, ticks, focus)
  local N = Utilities.OriginalNames
  N.list = {kind = kind, strs = strs, ticks = ticks, inst = {}}
  local ids, en = {}, {}
  for i, s in ipairs(strs) do
    ids[i] = CRC32(s)
    en[i] = 1
  end
  local size = 4
  if #strs < 9 and type(GetSubWinSizeAnimeType) == "function" then
    local okS, sz = pcall(GetSubWinSizeAnimeType, #strs)
    if okS and type(sz) == "number" then
      size = sz
    end
  end
  focus = (focus or 0) < #strs and (focus or 0) or 0
  N.list.focus = focus
  MENU_DEF.SetSubwindowCallback_UpdateListItem("Utilities.OriginalNames.OnItem")
  MENU_DEF.SetSubwindowCallback_PressZLZREvent("Utilities.OriginalNames.OnTabKey")
  MENU_DEF.OpenSubWindow("Utilities.OriginalNames.OnDone", "", #strs, ids, size, 0, en, focus < 9 and focus or 0, false, false, N.WINDOW_TYPE, N.TITLE, {}, 999999)
  for i, s in ipairs(strs) do
    funcLuaCommand(N.C.SET_STR, i - 1, s)
  end
  N.state = "list_opening"
end

-- close the window; `after` runs once it is closed
function Utilities.OriginalNames.ListClose(after)
  local N = Utilities.OriginalNames
  N.Sub("SetDisableCheckMeshUpdate", false)
  funcLuaCommand(N.C.CLOSE_OBJ, N.SUB_WINDOW)
  N.after = after
  N.state = "list_closing"
end

function Utilities.OriginalNames.ListRestore()
  MENU_DEF.SetSubwindowCallback_UpdateListItem("OnSubWindowUpdateListItem")
  MENU_DEF.SetSubwindowCallback_PressZLZREvent("OnSubWindowPressZLZREvent")
end

-- the team rows of the page `dir` away
function Utilities.OriginalNames.RowsShow(dir)
  local N = Utilities.OriginalNames
  local ok, page, name, on, n, rows = pcall(funcLuaCommand, N.C.TAB, dir)
  if not ok or type(page) ~= "number" or type(rows) ~= "number" then
    N.Log("picker: no page")
    N.Finish()
    return false
  end
  local strs = {N.Fmt(N.TAB_TEXT, "‹ %s  %d/%d ›", tostring(name), on or 0, n or 0)}
  local ticks = {false}
  for i = 1, rows do
    local it = N.TeamItem(i)
    strs[#strs + 1] = it.name .. "  " .. it.count
    ticks[#ticks + 1] = it.full == true
  end
  N.ListVisible(true)
  N.ListOpen("teams", strs, ticks, N.focus or 0)
  return true
end

-- the players of team row i as rows
function Utilities.OriginalNames.PlayersShow(i)
  local N = Utilities.OriginalNames
  local ok, n = pcall(funcLuaCommand, N.C.TEAM, i)
  if not ok or type(n) ~= "number" or n < 1 then
    return false
  end
  local strs, ticks = {}, {}
  for j = 1, n do
    local okP, _, pon, dub, orig = pcall(funcLuaCommand, N.C.PLAYER, j)
    dub, orig = okP and tostring(dub or "") or "?", okP and tostring(orig or "") or ""
    strs[j] = (orig ~= "" and orig ~= dub) and (dub .. "  →  " .. orig) or dub
    ticks[j] = okP and pon == true
  end
  N.ListOpen("players", strs, ticks, 0)
  return true
end

function Utilities.OriginalNames.Refresh()
  local N = Utilities.OriginalNames
  for inst, data in pairs(N.list.inst) do
    N.Sub("UpdateBtnCheck", inst, N.list.ticks[data + 1] == true)
  end
end

-- sub window: an item instance (re)drawn (a1 = data index, a2 = instance)
function Utilities.OriginalNames.OnItem(a1, a2)
  local N = Utilities.OriginalNames
  if N.list == nil or (N.state ~= "list_opening" and N.state ~= "list") then
    return
  end
  if type(a1) == "number" and type(a2) == "number" then
    N.list.inst[a2] = a1
    if N.state == "list" then
      N.Sub("UpdateBtnCheck", a2, N.list.ticks[a1 + 1] == true)
    end
  end
end

-- sub window: L2 / R2 (a2 = 0 previous, else next): another page of team rows
function Utilities.OriginalNames.OnTabKey(a1, a2)
  local N = Utilities.OriginalNames
  if N.state ~= "list" or N.list.kind ~= "teams" then
    return
  end
  funcLuaCommand(N.C.SND, N.SY_MOVE)
  N.focus = 0
  local dir = a2 == 0 and -1 or 1
  N.ListClose(function() N.RowsShow(dir) end)
end

-- sub window: A on item a1 (data index), -1 = B
function Utilities.OriginalNames.OnDone(a1)
  local N = Utilities.OriginalNames
  if N.list == nil or (N.state ~= "list" and N.state ~= "list_opening") then
    return
  end
  local L = N.list
  if L.kind == "teams" then
    if type(a1) ~= "number" or a1 < 0 then
      N.ListClose(function() N.Finish() end)
    elseif a1 == 0 then
      N.focus = 0
      N.ListClose(function() N.RowsShow(1) end)
    else
      N.team, N.focus = a1, a1
      N.ListClose(function()
        if N.FaceLayerOk() and N.GridOpen(a1) then
          return
        end
        if not N.PlayersShow(a1) then
          funcLuaCommand(N.C.SND, N.SY_ERROR)
          N.RowsShow(0)
        end
      end)
    end
  else
    if type(a1) ~= "number" or a1 < 0 then
      N.ListClose(function() N.ShowTab(0) end)
      return
    end
    local ok, state = pcall(funcLuaCommand, N.C.TOGGLE, a1 + 1)
    if not ok or type(state) ~= "boolean" then
      funcLuaCommand(N.C.SND, N.SY_ERROR)
      return
    end
    funcLuaCommand(N.C.SND, N.SY_MOVE)
    L.ticks[a1 + 1] = state
    N.Refresh()
  end
end

rawset(_ENV, "Utilities.OriginalNames.OnDone", function(...) return Utilities.OriginalNames.OnDone(...) end)
rawset(_ENV, "Utilities.OriginalNames.OnItem", function(...) return Utilities.OriginalNames.OnItem(...) end)
rawset(_ENV, "Utilities.OriginalNames.OnTabKey", function(...) return Utilities.OriginalNames.OnTabKey(...) end)

-- the face layer is in the settings menu
function Utilities.OriginalNames.FaceLayerOk()
  local N = Utilities.OriginalNames
  local have = N.M(N.C.LAYER_NUM, N.FACE_LAYER)
  return type(have) == "number" and have >= 1
end

-- ---- the player grid ----------------------------------------------------------------------------------------------

-- the settings list (rows, cursor) shown / hidden under the grid
function Utilities.OriginalNames.ListVisible(on)
  local N = Utilities.OriginalNames
  N.M(N.C.LAYER_VISIBLE, N.LIST_ATTACH, 0, on)
  for k = 0, N.LIST_ITEMS - 1 do
    N.M(N.C.LAYER_VISIBLE, N.LIST_ITEM, k, on)
  end
  N.M(N.C.LAYER_VISIBLE, N.CURSOR, 0, on)
end

function Utilities.OriginalNames.Guide(s)
  local N = Utilities.OriginalNames
  N.M(N.C.SET_TEXT, N.GUIDE, N.GUIDE_TEXT, s, 0)
end

-- the grid of team row `i`: false when the team or the face layer is not there
function Utilities.OriginalNames.GridOpen(i)
  local N = Utilities.OriginalNames
  local have = N.M(N.C.LAYER_NUM, N.FACE_LAYER)
  if type(have) ~= "number" or have < 1 then
    N.Log("grid: face layer util_jpn_face not in the settings menu (" .. tostring(have) .. "): Instalar")
    return false
  end
  local ok, n, on, tname = pcall(funcLuaCommand, N.C.TEAM, i)
  if not ok or type(n) ~= "number" or n < 1 then
    N.Log("grid: team row " .. tostring(i) .. " not there")
    return false
  end
  local okG, cols, rows, px, py, tile, cx, cy, grey, names = pcall(funcLuaCommand, N.C.GRID)
  if not okG or type(cols) ~= "number" then
    cols, rows, px, py, tile, cx, cy, grey, names = 10, 4, 150, 180, 132, 960, 560, 0.38, true
  end
  local per = math.max(1, math.min(cols * rows, have))
  local G = {n = n, on = on or 0, team = tostring(tname), cols = cols, rows = math.ceil(per / cols), per = per,
             px = px, py = py, tile = tile, cx = cx, cy = cy, grey = grey, names = names == true,
             players = {}, sel = 0, page = 0, held = {}, keys_seen = false, key_face = {}, fwait = {}, fdim = {},
             asked = {}, ptr = nil, drawn = false}
  for j = 1, n do
    local okP, key, pon, dub, orig = pcall(funcLuaCommand, N.C.PLAYER, j)
    G.players[j] = {key = okP and key or 0, on = okP and pon == true, dub = okP and tostring(dub or "") or "",
                    orig = okP and tostring(orig or "") or ""}
  end
  N.grid = G
  N.ListVisible(false)
  N.state = "grid"
  N.GridKeysReset()
  N.GridDraw()
  N.Log(string.format("grid opened: %s, %d player(s), %d chosen, %d a page", G.team, n, G.on, per))
  return true
end

function Utilities.OriginalNames.GridClose()
  local N = Utilities.OriginalNames
  local G = N.grid
  if G ~= nil then
    for k = 0, G.per - 1 do
      if N.opened[k] then
        N.M(N.C.LAYER_VISIBLE, N.FACE_LAYER, k, false)
      end
    end
    N.Log(string.format("grid closed: %s %d/%d", G.team, G.on, G.n))
  end
  N.grid = nil
  N.focus = N.team or 1
  N.ShowTab(0)
end

-- the centre of grid cell k of the page (layer space: from the screen's top left, y up); the rows the page uses are
-- centred on the grid's centre (a team of 16 = two rows in the middle)
function Utilities.OriginalNames.Cell(k)
  local G = Utilities.OriginalNames.grid
  local c, r = k % G.cols, math.floor(k / G.cols)
  local used = math.max(1, math.min(G.rows, math.ceil(math.min(G.per, G.n - G.page * G.per) / G.cols)))
  local x = G.cx + (c - (G.cols - 1) / 2) * G.px
  local y = G.cy + (r - (used - 1) / 2) * G.py              -- screen px, y down
  return x, -y
end

-- tile k shows player d (1-based; nil = hidden)
function Utilities.OriginalNames.Tile(k, d)
  local N = Utilities.OriginalNames
  local G, L = N.grid, N.FACE_LAYER
  if d == nil or G.players[d] == nil then
    if N.opened[k] then
      N.M(N.C.LAYER_VISIBLE, L, k, false)
    end
    G.key_face[k], G.fwait[k] = nil, nil
    return
  end
  local p = G.players[d]
  if not N.opened[k] then
    N.M(N.C.OPEN_LAYER, L, k)
    N.opened[k] = N.frame
  end
  local focus = (d - 1) == G.sel
  local size = G.tile * (focus and N.FOCUS_SCALE or 1)
  local s = size / N.FACE_RH
  local x, y = N.Cell(k)
  N.M(N.C.LOCAL_SCALE, L, s, s, 1, k)
  N.M(N.C.LOCAL_POS, L, x - N.FACE_OX * s, y - N.FACE_OY * s, 0, k)
  N.M(N.C.LAYER_VISIBLE, L, k, true)
  for _, m in ipairs(N.HIDE_MESHES) do
    N.M(N.C.MESH_VISIBLE, L, CRC32(m), false, k)
  end
  for _, m in ipairs(N.HIDE_NODES) do
    N.M(N.C.NODE_VISIBLE, L, CRC32(m), false, k)
  end
  N.M(N.C.MESH_VISIBLE, L, N.FACE_FOCUS, focus, k)
  -- grey = keeps the dub name: the card's grey-out material colour
  local v = p.on and 1 or G.grey
  N.M(N.C.COLOR, L, k, N.GRAY, v, v, v)
  if G.names then
    N.M(N.C.TEXT_VISIBLE, L, N.FACE_NAME, true, k)
    N.M(N.C.SET_TEXT, L, N.FACE_NAME, p.on and p.orig or p.dub, k)
  else
    N.M(N.C.TEXT_VISIBLE, L, N.FACE_NAME, false, k)
  end
  if G.key_face[k] ~= p.key then
    G.key_face[k], G.asked[k] = p.key, nil
    N.M(N.C.MESH_VISIBLE, L, N.FACE_MESH, false, k)
  end
  N.FaceAsk(k)
end

-- the face of tile k is asked for once its instance is built (OnOpenLayer) or BUILD_WAIT frames after it was opened;
-- it shows once its textures have loaded (or FACE_WAIT frames later)
function Utilities.OriginalNames.FaceAsk(k)
  local N = Utilities.OriginalNames
  local G = N.grid
  local key = G.key_face[k]
  if key == nil or key == 0 or G.asked[k] then
    return
  end
  if N.built[k] == nil and N.frame - (N.opened[k] or N.frame) < N.BUILD_WAIT then
    return
  end
  local L = N.FACE_LAYER
  N.M(N.C.RESET_FACE, L, k, N.FACE_TEX)
  pcall(SetDisableForceCharaInvalidUseTarget)
  local fr = N.M(N.C.FACE, L, k, false, N.FACE_MESH, N.FACE_TEX, 0, 0, key, 0, false, true)
  pcall(SetEnableForceCharaInvalidUseTarget)
  G.asked[k] = N.frame
  G.fwait[k] = N.FACE_WAIT
  if (N.face_logs or 0) < 20 then
    N.face_logs = (N.face_logs or 0) + 1
    N.Log("face", k, key, tostring(fr), N.built[k] ~= nil and "built" or "timeout")
  end
end

-- per frame: faces asked for, shown when loaded
function Utilities.OriginalNames.FaceStep()
  local N = Utilities.OriginalNames
  local G = N.grid
  for k = 0, G.per - 1 do
    if G.key_face[k] ~= nil and not G.asked[k] then
      N.FaceAsk(k)
    end
  end
  for k, left in pairs(G.fwait) do
    local loading = N.M(N.C.LOADING, N.FACE_LAYER, k) == true
    if not loading or left <= 0 then
      N.M(N.C.MESH_VISIBLE, N.FACE_LAYER, N.FACE_MESH, true, k)
      G.fwait[k] = nil
    else
      G.fwait[k] = left - 1
    end
  end
  -- the layer's open animation can hide a face already shown: again every 10 frames
  if N.frame % 10 == 0 then
    for k = 0, G.per - 1 do
      if G.asked[k] and G.fwait[k] == nil and G.key_face[k] ~= nil then
        N.M(N.C.MESH_VISIBLE, N.FACE_LAYER, N.FACE_MESH, true, k)
      end
    end
  end
end

function Utilities.OriginalNames.GridDraw()
  local N = Utilities.OriginalNames
  local G = N.grid
  G.page = math.floor(G.sel / G.per)
  for k = 0, G.per - 1 do
    local d = G.page * G.per + k + 1
    N.Tile(k, d <= G.n and d or nil)
  end
  local p = G.players[G.sel + 1]
  local who = ""
  if p ~= nil then
    who = (p.orig ~= "" and p.orig ~= p.dub) and (p.dub .. "  →  " .. p.orig) or p.dub
  end
  local pages = math.ceil(G.n / G.per)
  local head = N.Fmt(N.INFO_TEXT, "%s  %d/%d  ·  %s", G.team, G.on, G.n, who)
  if pages > 1 then
    head = head .. string.format("  (%d/%d)", G.page + 1, pages)
  end
  N.Guide(head .. "\n" .. N.Text(N.HINT_TEXT, "A / Y / L1 R1 / B"))
  G.drawn = true
end

-- ---- grid input ---------------------------------------------------------------------------------------------------

function Utilities.OriginalNames.In(input)
  local N = Utilities.OriginalNames
  for _, c in ipairs(N.CTRLS) do
    local ok, r = pcall(funcLuaCommand, N.C.CHECK_INPUT, c, input)
    if ok and r == true then
      return true
    end
  end
  return false
end

-- an input held from before the grid opened is no press
function Utilities.OriginalNames.GridKeysReset()
  local N = Utilities.OriginalNames
  local G = N.grid
  for name, input in pairs(N.KEYS) do
    G.held[name] = N.In(input) and 1000 or 0
  end
  G.ptr_x, G.ptr_y = N.M(N.C.POINTER)
end

-- pressed now (an edge), or repeating while held (arrows)
function Utilities.OriginalNames.Pressed(name, repeats)
  local N = Utilities.OriginalNames
  local G = N.grid
  local now = N.In(N.KEYS[name])
  local h = G.held[name] or 0
  if not now then
    G.held[name] = 0
    return false
  end
  G.held[name] = h + 1
  if not G.keys_seen then
    G.keys_seen = true
    N.Log("grid: input seen (" .. name .. ")")
  end
  if h == 0 then
    return true
  end
  return repeats and h >= N.REPEAT_FIRST and (h - N.REPEAT_FIRST) % N.REPEAT_EVERY == 0
end

function Utilities.OriginalNames.GridMove(to)
  local N = Utilities.OriginalNames
  local G = N.grid
  if to < 0 or to >= G.n or to == G.sel then
    return
  end
  G.sel = to
  funcLuaCommand(N.C.SND, N.SY_MOVE)
  N.GridDraw()
end

function Utilities.OriginalNames.GridToggle(j)
  local N = Utilities.OriginalNames
  local G = N.grid
  local ok, state, on = pcall(funcLuaCommand, N.C.TOGGLE, j)
  if not ok or type(state) ~= "boolean" then
    funcLuaCommand(N.C.SND, N.SY_ERROR)
    return
  end
  if j == 0 then
    for _, p in ipairs(G.players) do
      p.on = state
    end
  elseif G.players[j] ~= nil then
    G.players[j].on = state
  end
  G.on = type(on) == "number" and on or G.on
  funcLuaCommand(N.C.SND, N.SY_MOVE)
  N.GridDraw()
end

-- the tile under the pointer (0-based player index), nil = none
function Utilities.OriginalNames.GridHit(x, y)
  local N = Utilities.OriginalNames
  local G = N.grid
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  local half = G.tile / 2
  for k = 0, G.per - 1 do
    local d = G.page * G.per + k
    if d < G.n then
      local cx, cy = N.Cell(k)
      if math.abs(x - cx) <= half and math.abs(y + cy) <= half then
        return d
      end
    end
  end
  return nil
end

function Utilities.OriginalNames.GridStep()
  local N = Utilities.OriginalNames
  local G = N.grid
  N.FaceStep()
  -- every input is read each frame (the press edges stay right), then one action
  local P = {}
  for _, k in ipairs({"back", "rclick", "click", "enter", "all", "l1", "r1", "wup", "wdown"}) do
    P[k] = N.Pressed(k)
  end
  for _, k in ipairs({"left", "right", "up", "down"}) do
    P[k] = N.Pressed(k, true)
  end
  if P.back or P.rclick then
    funcLuaCommand(N.C.SND, N.SY_MOVE)
    N.GridClose()
    return
  end
  -- the pointer: hover moves the cursor, a click toggles the tile under it (a click is no key Accept)
  local x, y = N.M(N.C.POINTER)
  local moved = N.M(N.C.POINTER_MOVED) == true
  if type(x) == "number" and (moved or x ~= G.ptr_x or y ~= G.ptr_y) then
    G.ptr_x, G.ptr_y = x, y
    local d = N.GridHit(x, y)
    if d ~= nil then
      N.GridMove(d)
    end
  end
  if P.click then
    local d = N.GridHit(x, y)
    if d ~= nil then
      G.sel = d
      N.GridToggle(d + 1)
    end
    return
  end
  local c = G.cols
  local col = G.sel % c
  if P.left then
    N.GridMove(col > 0 and G.sel - 1 or math.min(G.sel + c - 1, G.n - 1))
  elseif P.right then
    N.GridMove((col < c - 1 and G.sel + 1 < G.n) and G.sel + 1 or G.sel - col)
  elseif P.up then
    N.GridMove(G.sel - c >= 0 and G.sel - c or G.sel)
  elseif P.down then
    N.GridMove(math.min(G.sel + c, G.n - 1))
  elseif P.l1 or P.wup then
    N.GridMove(math.max(G.sel - G.per, 0))
  elseif P.r1 or P.wdown then
    N.GridMove(math.min(G.sel + G.per, G.n - 1))
  elseif P.enter then
    N.GridToggle(G.sel + 1)
  elseif P.all then
    N.GridToggle(0)
  end
end

-- per frame: the team grid or the player grid
function Utilities.OriginalNames.Step()
  local N = Utilities.OriginalNames
  N.frame = N.frame + 1
  if N.state == "teams" and N.eg ~= nil then
    N.TeamsStep()
  elseif N.state == "grid" and N.grid ~= nil then
    N.GridStep()
  elseif N.state == "list_opening" then
    local ok, open = pcall(funcLuaCommand, N.C.IS_OPEN, N.SUB_WINDOW, N.CURSOR)
    if ok and open == true then
      N.Sub("SetDisableCheckMeshUpdate", true)
      if (N.list.focus or 0) > 0 then
        N.Sub("SetFocusListItem", N.list.focus)
      end
      N.state = "list"
      N.Refresh()
    end
  elseif N.state == "list_closing" then
    local ok, closed = pcall(funcLuaCommand, N.C.IS_CLOSE, N.SUB_WINDOW)
    if ok and closed == true then
      local after = N.after
      N.after, N.state = nil, "idle"
      if after ~= nil then
        after()
      end
    end
  end
end

-- ---- the reload ---------------------------------------------------------------------------------------------------

-- the settings script's main-chunk locals (VRFW_Host.hosts.setting_menu.L), or nil
function Utilities.OriginalNames.Locals()
  local h = type(VRFW_Host) == "table" and type(VRFW_Host.hosts) == "table" and VRFW_Host.hosts.setting_menu or nil
  return h ~= nil and h.L or nil
end

function Utilities.OriginalNames.Close()
  local N = Utilities.OriginalNames
  local okL, lang = pcall(funcLuaCommand, N.C.LANG)
  local ok, need = pcall(funcLuaCommand, N.C.RELOAD, okL and lang or -1)
  if not ok or need ~= true then
    return
  end
  local L = N.Locals()
  local okl, n, n6, n7, f2 = false, nil, nil, nil, nil
  if L ~= nil then
    okl, n, n6, n7, f2 = pcall(function()
      return L.n, L.n6, L.n7, L.flag2
    end)
  end
  if not okl or type(n) ~= "number" or type(n6) ~= "number" or type(n7) ~= "number" or type(f2) ~= "boolean" then
    if not N.noted then
      N.noted = true
      N.Log("settings locals not reachable (no VRFW_Host setting_menu L / EVT_DEBUG): the names change at the next start")
    end
    return
  end
  if n == 1 or n == 2 or n == 3 or n == 4 then
    return
  end
  local done, err = pcall(function()
    if n6 == -1 or n7 == -1 then
      local tl = funcLuaCommand(N.C.TEXT_LANG)
      if n6 == -1 then
        L.n6 = tl
      end
      if n7 == -1 then
        L.n7 = tl
      end
    end
    L.flag4 = true
    if L.n6 == L.n7 then
      L.flag3 = not f2
    end
  end)
  if done then
    N.Log("names changed: retail «Originales» path (back to the title, texts reloaded)")
  else
    N.Log("settings locals not written (" .. tostring(err) .. "): the names change at the next start")
  end
end

do
  local H = VRFW_Host or EVT_Host
  if type(H) == "table" and type(H.on) == "function" then
    local id = "utilities.original_names"
    H.on("setting_menu", "OnInit", {id = id, phase = "before", fn = function()
      local N = Utilities.OriginalNames
      N.labels, N.row_text, N.state, N.grid, N.built, N.opened, N.frame = {}, nil, nil, nil, {}, {}, 0
      N.eg = nil                        -- a new menu: new layer instances
    end})
    -- a1 = the list cell, a2 = the label text it shows now
    H.on("setting_menu", "UpdateListItem", {id = id, phase = "before", fn = function(a1, a2)
      if type(a1) == "number" then
        Utilities.OriginalNames.labels[a1] = a2
      end
    end})
    -- an instance of the face layer is built: its face may be asked for (Utilities.OriginalNames.FaceAsk)
    H.on("setting_menu", "OnOpenLayer", {id = id, phase = "after", fn = function(a1, a2)
      local N = Utilities.OriginalNames
      if N.eg ~= nil then
        N.eg:Built(a1, a2)
      end
      if a1 == N.FACE_LAYER and type(a2) == "number" then
        N.built[a2] = N.frame
        if N.grid ~= nil and N.grid.asked[a2] then
          N.grid.asked[a2] = nil       -- asked before it was built: again
        end
      end
    end})
    -- A on the names row: the picker (the engine is not told: no value step)
    H.on("setting_menu", "OnEnter", {id = id, phase = "around", fn = function(nxt, a1, a2)
      local N = Utilities.OriginalNames
      if N.state ~= nil then
        return                          -- the grids poll their own keys
      end
      if (a1 == N.LIST_ATTACH or a1 == N.LIST_ITEM) and N.state == nil and N.IsNamesRow() then
        if N.Open() then
          return
        end
        SetInputEnbaleMenuObject(true)
      end
      return nxt(a1, a2)
    end})
    H.on("setting_menu", "Step", {id = id, phase = "after", fn = function()
      if Utilities.OriginalNames.state ~= nil then
        Utilities.OriginalNames.Step()
      end
    end})
    H.on("setting_menu", "CloseMenuSetting", {id = id, phase = "before", fn = function()
      Utilities.OriginalNames.Close()
    end})
  end
end
