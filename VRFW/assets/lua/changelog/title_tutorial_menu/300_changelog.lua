-- changelog (VR-Framework): «Novedades de mods» on the retail update-notes sheet (menu title_tutorial_menu,
-- docs/game/ui/update-notes.md). Own code: `around` handlers of the framework's title_tutorial_menu host (VRFW_Host,
-- docs/framework/lua-hosts.md) on the retail callbacks of this menu.
--
-- While the changelog part has a sheet open (CMND_VRFW_CHANGELOG_SESSION, opened by the title or the «Mods» screen
-- right before they open this menu), the callbacks do what the retail ones do for the update notes with the welcome
-- flag already on (UpdateToUpdateFeatureDisplay, SetupUpdateFeatureListItemText, the paging of OnDecideFocus), but
-- with the part's pages (8 rows: icon + text) instead of update_notice_config. Otherwise the retail callbacks run
-- untouched (nxt: the welcome pages and the game's own update notes). The retail tables of this script are locals of
-- its chunk (the host serves them as VRFW_Host.hosts.title_tutorial_menu.L; this file keeps its own copies). No engine
-- call at load time.

local function CL_Crc(s)
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

local CMD = {
  SESSION = CL_Crc("CMND_VRFW_CHANGELOG_SESSION"),   -- () -> open, pages
  PAGE = CL_Crc("CMND_VRFW_CHANGELOG_PAGE"),         -- (page) -> title, rows
  LINE = CL_Crc("CMND_VRFW_CHANGELOG_LINE"),         -- (page, row) -> text, icon texture (0 = none)
}
local MENU = 3492314538                              -- title_tutorial_menu
local L_FIRST = 3998288799                           -- title11_03_title_first_explanation (focus + CMD_ENTER)
local L_SHEET = 3239012785                           -- win04_37_update_feature_list_locator
local L_ITEM = 972319352                             -- win04_33_reverse_lookup_list_item (8 instances)
local N_TITLE, N_EXPLAIN, N_ICON = 1768688116, 499981750, 3086438359   -- _text_title01, _text_explain01, icon_mode_dmy01
-- the icon's MESH (g4pkm name `_icon_mode_dmy01`, with the underscore): the texture command takes the material name
-- (icon_mode_dmy01), the mesh visibility the mesh name. A row without a texture draws it as a white square.
local M_ICON = 3391924283
local N_OFF1, N_OFF2, N_TEXT = 902337421, 2898379319, 999008199       -- offset01, offset02, text
local G4TX = 2310203263                              -- #/menu/10_win/win04/win04_33/win04_33.g4tx
local A_OPEN = 71445658                              -- Open
local C = {
  TEXT = 1083631230,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string[, idx])
  LAYER_VISIBLE = 711242136,  -- (layer, idx, bool)
  MESH_VISIBLE = 3405944500,  -- (layer, mesh, bool, idx)
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = 320421347,     -- CMND_CLOSE_MENU_OBJECT
  CLOSE_LAYER = 1273612389, CLOSE_ARRAY = 2323943931, OPEN_LAYER = 629267548, OPEN_ARRAY = 2152386330,
  IS_OPEN = 2640875187, IS_CLOSING = 1907056693, IS_LOADING = 3057768039, LAYER_NUM = 1175615627,
  ANIME = 3781155141, ANIME_END = 3133389476, TEXTURE = 558735651,
  TITLE_STYLE = 2333948100, ITEM_SETUP = 2628464193, GROUP_INDEX = 112302847, GROUP_OFFSET = 541357333,
  FIT = 2301937025, FIT_APPLY = 1595998683,
}

local cl = {on = false, page = 0, pages = 0, title = "", n = 0, lines = {}, icons = {}, fit = 1, co = nil, state = 0}

local function CL_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function CL_Wait(f)
  while not f() do
    coroutine.yield()
  end
end

local function CL_Load(p)
  cl.page, cl.n, cl.lines, cl.icons, cl.head = p, 0, {}, {}, {}
  local title, rows = CL_Call(CMD.PAGE, p)
  cl.title = type(title) == "string" and title or ""
  rows = type(rows) == "number" and rows or 0
  for i = 0, math.min(rows, 8) - 1 do
    local s, icon = CL_Call(CMD.LINE, p, i)
    cl.lines[i + 1] = type(s) == "string" and s or ""
    cl.icons[i + 1] = type(icon) == "number" and icon or 0
    -- icon of the header this row belongs to (a page always starts with a header)
    if cl.icons[i + 1] ~= 0 or i == 0 then
      cl.head[i + 1] = cl.icons[i + 1]
    else
      cl.head[i + 1] = cl.head[i]
    end
    cl.n = i + 1
  end
end

-- the rows' texts (retail SetupUpdateFeatureListItemText)
local function CL_Texts()
  cl.fit = 1
  local num = funcLuaMenuCommand(C.LAYER_NUM, L_ITEM) or 0
  for i = 0, num - 1 do
    if cl.n <= i then
      break
    end
    funcLuaMenuCommand(C.TEXT, L_ITEM, N_EXPLAIN, cl.lines[i + 1], i)
    local f = funcLuaMenuCommand(C.FIT, L_ITEM, i, N_EXPLAIN, N_OFF1, 108, 1476)
    if type(f) == "number" then
      cl.fit = math.min(cl.fit, f)
    end
  end
end

-- open the window with the current page (retail UpdateToUpdateFeatureDisplay, welcome flag on)
local function CL_Display()
  cl.state = 1
  local num = funcLuaMenuCommand(C.LAYER_NUM, L_ITEM) or 0
  CL_Wait(function() return num < 1 or not funcLuaMenuCommand(C.IS_LOADING, L_ITEM, 0) end)
  CL_Wait(function() return not funcLuaMenuCommand(C.IS_CLOSING, L_SHEET) end)
  CL_Wait(function() return num < 1 or funcLuaMenuCommand(C.IS_CLOSING, L_ITEM, 0) ~= true end)
  funcLuaMenuCommand(C.TEXT, L_SHEET, N_TITLE, cl.title)
  funcLuaMenuCommand(C.OPEN_LAYER, L_SHEET)
  funcLuaMenuCommand(C.OPEN_ARRAY, L_ITEM)
  CL_Wait(function() return funcLuaMenuCommand(C.IS_OPEN, L_SHEET) end)
  CL_Wait(function() return num < 1 or funcLuaMenuCommand(C.IS_OPEN, L_ITEM, 0) ~= false end)
  CL_Wait(function() return funcLuaMenuCommand(C.ANIME_END, L_SHEET, 0, A_OPEN, 0) end)
  CL_Wait(function() return num < 1 or funcLuaMenuCommand(C.ANIME_END, L_ITEM, 0, N_TEXT) ~= false end)
  for i = 0, math.min(num, cl.n) - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_ITEM, i, true)
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  cl.state = 2
end

local function CL_OnInit(nxt)
  nxt()
  local open, pages = CL_Call(CMD.SESSION)
  cl.on = open == true and type(pages) == "number" and pages > 0
  cl.co, cl.state = nil, 0
  if cl.on then
    cl.pages = pages
    CL_Load(0)
  end
end

local function CL_OnSetupLayer(nxt, a1, a2)
  if not cl.on then
    return nxt(a1, a2)
  end
  if a1 == L_FIRST then
    return                    -- the welcome pages are the game's; never in a mods sheet
  elseif a1 == L_ITEM then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
  elseif a1 == L_SHEET then
    cl.co = coroutine.create(CL_Display)
    funcLuaMenuCommand(C.TITLE_STYLE, a1, a2, N_TITLE, 1811747504)
    funcLuaMenuCommand(C.TEXT, a1, N_TITLE, cl.title)
  else
    return nxt(a1, a2)                 -- the black background
  end
end

local function CL_OnOpenLayer(nxt, a1, a2)
  if not cl.on then
    return nxt(a1, a2)
  end
  if a1 == L_ITEM then
    if a2 == 0 then
      CL_Texts()
    end
    funcLuaMenuCommand(C.ITEM_SETUP, a1, a2, 883)
    if cl.n - 1 < a2 then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
      return
    end
    local icon = cl.icons[a2 + 1] or 0
    -- a note row: no icon (mesh hidden); it still gets its header's texture so that it could never be a white square
    local tex = icon ~= 0 and icon or (cl.head[a2 + 1] or 0)
    if tex ~= 0 then
      funcLuaMenuCommand(C.TEXTURE, a1, G4TX, tex, N_ICON, 0, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, M_ICON, icon ~= 0, a2)
    local g = funcLuaMenuCommand(C.GROUP_INDEX, a1, a2, N_TEXT)
    funcLuaMenuCommand(C.GROUP_OFFSET, a1, N_OFF1, g, a2)
    funcLuaMenuCommand(C.FIT_APPLY, a1, N_OFF1, 0, cl.fit, a2, true, N_TEXT)
  elseif a1 == L_SHEET then
    if cl.n >= 5 and cl.n < 7 then
      funcLuaMenuCommand(C.ANIME, a1, a2, N_OFF2, 2, 2966043510)
      funcLuaMenuCommand(C.ANIME, a1, a2, N_OFF1, 0, 2966043510)
    elseif cl.n >= 7 then
      funcLuaMenuCommand(C.ANIME, a1, a2, N_OFF1, 2, 2966043510)
      funcLuaMenuCommand(C.ANIME, a1, a2, N_OFF2, 0, 2966043510)
    end
  end
end

local function CL_OnDecideFocus(nxt, a1, a2)
  if not cl.on then
    return nxt(a1, a2)
  end
  if a1 ~= L_FIRST or cl.state ~= 2 then
    return
  end
  if cl.page + 1 >= cl.pages then
    cl.state = 3
    funcLuaCommand(C.CLOSE_MENU, MENU)
  else
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
    funcLuaMenuCommand(C.CLOSE_LAYER, L_SHEET)
    funcLuaMenuCommand(C.CLOSE_ARRAY, L_ITEM)
    CL_Load(cl.page + 1)
    cl.co = coroutine.create(CL_Display)
  end
end

local function CL_Step(nxt)
  if not cl.on then
    return nxt()
  end
  if cl.co ~= nil then
    local ok, err = coroutine.resume(cl.co)
    if not ok then
      cl.co = nil
      pcall(funcLuaCommand, CL_Crc("CMND_EVT_LOG"), "changelog", "error", tostring(err))
      funcLuaCommand(C.CLOSE_MENU, MENU)       -- never leave the player stuck on a broken sheet
    elseif coroutine.status(cl.co) == "dead" then
      cl.co = nil
    end
  end
end

if VRFW_Host ~= nil then
  for point, fn in pairs({OnInit = CL_OnInit, OnSetupLayer = CL_OnSetupLayer, OnOpenLayer = CL_OnOpenLayer,
                          OnDecideFocus = CL_OnDecideFocus, Step = CL_Step}) do
    VRFW_Host.on("title_tutorial_menu", point, {id = "changelog.sheet", phase = "around", fn = fn})
  end
end

-- for the tests
VRFW_CL_SHEET = cl
