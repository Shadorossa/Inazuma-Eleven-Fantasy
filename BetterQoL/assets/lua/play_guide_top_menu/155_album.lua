-- BetterQoL › «Álbum de jugadores» (docs/game/ui/album.md): the row of «Caseta del club» (play_guide_top_menu; graft
-- util_album_row) opens the page util_album_menu (content\menus\album.toml, script assets\lua\screens\util_album_menu.lua)
-- the way this menu opens its «Archivo de escenas» (UpdateSceneArchiveCoroutine), as «Estadísticas del club» does:
-- input off, the Caseta's picture closed and its list hidden, the header titled «Álbum de jugadores» (header type 9:
-- the «Galería» icon), the page opened; the Caseta's button guide shows the page's keys (L2 / R2 type, LB / RB group,
-- left / right page, X / Y the player plate's pages). When the page is gone (B / Esc / right click) the player plate it
-- opened is closed too (asked again until it is gone), the plate's parameter cleared and the menu camera's offset put
-- back; then the Caseta comes back with its cursor on the row and its own «Aceptar». Runs as a coroutine resumed from
-- Step. Engine calls only from the menu callbacks.
Utilities = type(Utilities) == "table" and Utilities or {}

if UTIL_ALB == nil then
  UTIL_ALB = {
    C = {
      LOG = 3661580131, TEXT_GET = 4074371074,
      MENU_INPUT = 1558704558 --[[CMND_SET_INPUT_ENABLE_MENU_OBJECT]], ANIME = 3781155141 --[[CMND_PLAY_ANIME_TYPE]],
      HIDE_MENU = 369172623, SHOW_MENU = 66378409, OPEN_MENU = 433545986 --[[CMND_OPEN_MENU_OBJECT]],
      CLOSE_MENU = 320421347 --[[CMND_CLOSE_MENU_OBJECT]],
      IS_MENU = 2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], CTRL_FOCUS = 3518307824, FOCUS_SET = 3466097042,
      GET_FOCUS = 2603265800,
      GUIDE_SET = 2209673388, GUIDE_CMD = 452337289,
      PARAM_EXISTS = 2947612279, PARAM_DELETE = 3363400568,
      CAM_GET = 1877348924, CAM_SET = 284729675,
    },
    MENU = 1281873114,                    -- play_guide_top_menu
    PAGE = 2755094502,                    -- util_album_menu
    PLATE = 1427722143,                   -- personal_plate_menu (opened by the page)
    PLATE_FLAG = 2398708549,                -- BetterQoL.album_plate (the page's parameter while it shows the plate)
    CAM = 1752770328,                     -- MenuCamera (the plate's 3D model)
    LIST = 530619243,                     -- mainmenu90_12_list_item_small
    PICTURE = 243035880,                  -- playguide01_00_p1_background
    GUIDE = 1138543975,                   -- mainmenu01_06_base_button_guide
    OPEN_ANIME = 71445658,                -- «Open»
    HEADER = { PAGE_TYPE = 9, TYPE = 14, ICON = 3275740866 --[[mode_base05]], TITLE = 882201751 },
    -- the Caseta's own guide (retail OnSetupLayer): «Aceptar» on A; the page's: its keys (text rows of
    -- text\rows\album.toml: the labels, and the keys as the game's button tags)
    GUIDE_OWN = { texts = {1847312674}, icons = {2750714971 --[[<CMD_ENTER>]]}, cmds = {1981080283 --[[CMD_ENTER]]} },
    GUIDE_PAGE = {
      texts = { 2367343213 --[[BetterQoL.Album.GuideType]], 477103569 --[[BetterQoL.Album.GuideGroup]],
                365833060 --[[BetterQoL.Album.GuidePage]], 3053135 --[[BetterQoL.Album.GuidePlate]] },
      icons = { 953629953 --[[BetterQoL.Album.KeysType]], 1489102165 --[[BetterQoL.Album.KeysGroup]],
                2684607496 --[[BetterQoL.Album.KeysPage]], 1151301323 --[[BetterQoL.Album.KeysPlate]] },
      cmds = { 2704260807 --[[CMD_FUNCR2]], 942075773 --[[CMD_FUNCR1]], 2075023265 --[[CMD_RIGHT]],
               3421673595 --[[CMD_FUNC3]] },
    },
    TITLE = 4006794419,                   -- BetterQoL.Album.Row
    CLOSE_AGAIN = 30, CLOSE_MAX = 600,    -- frames between the plate's close requests; frames before giving up
    CAM_AGAIN = {30, 90},                 -- the camera offset put back again (the plate's model is released late)
    co = nil,
  }
end

local AL = UTIL_ALB

local function Log(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, AL.C.LOG, "betterqol album " .. table.concat(p, " "))
end

local function M(cmd, ...)
  local ok, a = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a end
  return nil
end

local function Header(kind, text)
  if type(SwapSoccerTopCommonHeaderByHeaderType) ~= "function" then return end
  if type(text) == "number" then
    local ok, t = pcall(funcLuaCommand, AL.C.TEXT_GET, text)
    text = ok and t or nil
  end
  if type(text) == "string" then pcall(SwapSoccerTopCommonHeaderByHeaderType, kind, text, AL.HEADER.ICON) end
end

local function Guide(g)
  M(AL.C.GUIDE_SET, AL.MENU, AL.GUIDE, g.texts, g.icons, {})
  M(AL.C.GUIDE_CMD, AL.MENU, AL.GUIDE, g.cmds)
end

local function Camera()
  local ok, has, x, y, z = pcall(funcLuaCommand, AL.C.CAM_GET, AL.CAM)
  return (ok and has == true and type(x) == "number") and {x, y or 0, z or 0} or nil
end

local function CameraBack(cam)
  if cam ~= nil then pcall(funcLuaCommand, AL.C.CAM_SET, AL.CAM, cam[1], cam[2], cam[3]) end
end

-- the page's whole visit (UpdateSceneArchiveCoroutine of the retail script, with this page and its plate)
local function Visit()
  local row = M(AL.C.GET_FOCUS, AL.LIST) or 0
  local cam = Camera()
  M(AL.C.MENU_INPUT, AL.MENU, false)
  M(AL.C.ANIME, AL.PICTURE, 0, AL.OPEN_ANIME, 2)
  M(AL.C.HIDE_MENU, AL.MENU)
  Header(AL.HEADER.PAGE_TYPE, AL.TITLE)
  Guide(AL.GUIDE_PAGE)
  pcall(funcLuaCommand, AL.C.OPEN_MENU, AL.PAGE)
  Log("page open asked (row " .. tostring(row) .. ")")
  coroutine.yield()
  while M(AL.C.IS_MENU, AL.PAGE) == true do coroutine.yield() end
  -- the page is gone: its plate too (asked again until it is gone; one still opening is waited for)
  local frames, asked = 0, nil
  while M(AL.C.IS_MENU, AL.PLATE) == true and frames < AL.CLOSE_MAX do
    if asked == nil or frames - asked >= AL.CLOSE_AGAIN then
      pcall(funcLuaCommand, AL.C.CLOSE_MENU, AL.PLATE)
      asked = frames
    end
    frames = frames + 1
    coroutine.yield()
  end
  local okf, has = pcall(funcLuaCommand, AL.C.PARAM_EXISTS, AL.PLATE_FLAG)
  if okf and has == true then pcall(funcLuaCommand, AL.C.PARAM_DELETE, AL.PLATE_FLAG) end
  CameraBack(cam)
  M(AL.C.SHOW_MENU, AL.MENU)
  M(AL.C.ANIME, AL.PICTURE, 0, AL.OPEN_ANIME, 0)
  Guide(AL.GUIDE_OWN)
  M(AL.C.CTRL_FOCUS, AL.LIST, true)
  M(AL.C.FOCUS_SET, AL.LIST, row)
  -- the Caseta's own focus code puts its cursor and help line back on the row
  if type(OnChangeFocus) == "function" then pcall(OnChangeFocus, AL.LIST, row) end
  Header(AL.HEADER.TYPE, AL.HEADER.TITLE)
  M(AL.C.MENU_INPUT, AL.MENU, true)
  Log("back from the page" .. (frames >= AL.CLOSE_MAX and " (the plate was still there)" or ""))
  -- the plate's model is released late: the camera offset again after a while
  local waited = 0
  for _, due in ipairs(AL.CAM_AGAIN) do
    while waited < due do
      waited = waited + 1
      coroutine.yield()
    end
    CameraBack(cam)
  end
end

local function Open()
  if AL.co ~= nil then return end
  AL.co = coroutine.create(Visit)
  local ok, err = coroutine.resume(AL.co)
  if not ok then
    Log("open failed", tostring(err))
    AL.co = nil
  end
end

BetterQoL.Album = BetterQoL.Album or {}
BetterQoL.Album.Open = Open

if UTIL_ALB_HOOKED == nil then
  UTIL_ALB_HOOKED = true
  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      AL.co = nil
      return init(...)
    end
  end
  local step = Step
  Step = function(...)
    if AL.co ~= nil then
      local ok, err = coroutine.resume(AL.co)
      if not ok then Log("visit error", tostring(err)) end
      if not ok or coroutine.status(AL.co) == "dead" then AL.co = nil end
    end
    if type(step) == "function" then return step(...) end
  end
end
