-- BetterQoL › «Álbum de jugadores» (docs/game/ui/album.md): the row of «Caseta del club» (play_guide_top_menu; graft
-- util_album_row) opens the page util_album_menu (content\menus\album.toml, script assets\lua\screens\util_album_menu.lua)
-- the way this menu opens its «Archivo de escenas» (UpdateSceneArchiveCoroutine), as «Estadísticas del club» does:
-- input off, the Caseta's picture closed and its list hidden, its background hidden while the page's player plate is up
-- (the page then shows its own background, drawn before the 3D pass, so the plate's 3D model shows; the page asks), the header titled «Álbum de jugadores»
-- (header type 9: the «Galería» icon), the page opened; the Caseta's button guide shows the page's page key (left / right; the type,
-- group and plate keys work without a guide entry; first A and its label when another mod offers an
-- action on the selected player: BetterQoL.AlbumActions). When the page is gone (B / Esc / right click) the player plate it
-- opened is closed too (asked again until it is gone), the plate's parameter cleared and the menu camera's offset put
-- back; then the Caseta comes back with its cursor on the row and its own «Aceptar». Runs as a coroutine resumed from
-- Step. Engine calls only from the menu callbacks.
BetterQoL = type(BetterQoL) == "table" and BetterQoL or {}

if UTIL_ALB == nil then
  UTIL_ALB = {
    C = {
      LOG = VRFW_Cmd.EVT_LOG, TEXT_GET = VRFW_Cmd.TEXT_GET,
      MENU_INPUT = 1558704558 --[[CMND_SET_INPUT_ENABLE_MENU_OBJECT]], ANIME = VRFW_Cmd.PLAY_ANIME_TYPE,
      HIDE_MENU = 369172623, SHOW_MENU = 66378409, OPEN_MENU = VRFW_Cmd.OPEN_MENU_OBJECT,
      CLOSE_MENU = VRFW_Cmd.CLOSE_MENU_OBJECT,
      IS_MENU = VRFW_Cmd.IS_EXIST_MENU_OBJECT, CTRL_FOCUS = VRFW_Cmd.SET_ENABLE_CTRL_FOCUS, FOCUS_SET = 3466097042,
      GET_FOCUS = 2603265800,
      GUIDE_SET = 2209673388, GUIDE_CMD = 452337289,
      CAM_GET = 1877348924, CAM_SET = 284729675,
      LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,
    },
    MENU = 1281873114,                    -- play_guide_top_menu
    PAGE = 2755094502,                    -- util_album_menu
    PLATE = 1427722143,                   -- personal_plate_menu (opened by the page)
    PLATE_FLAG = 2398708549,                -- BetterQoL.album_plate (the page's parameter while it shows the plate)
    PLATE_CARD = 2716223290,                -- VRFW.plate_card (the plate's card: its 3D model in his own team's kit)
    CAM = 1752770328,                     -- MenuCamera (the plate's 3D model)
    LIST = 530619243,                     -- mainmenu90_12_list_item_small
    PICTURE = 243035880,                  -- playguide01_00_p1_background
    -- the Caseta's background (normal pass): hidden while the page is up, whose own background (util_alb_backdrop) is
    -- drawn before the 3D pass, so the player plate's 3D model shows over it (the transfer office's way)
    BACKGROUND = 367379312,               -- mainmenu90_00_background
    GUIDE = 1138543975,                   -- mainmenu01_06_base_button_guide
    OPEN_ANIME = 71445658,                -- «Open»
    HEADER = { PAGE_TYPE = 9, TYPE = 14, ICON = 3275740866 --[[mode_base05]], TITLE = 882201751 },
    -- the Caseta's own guide (retail OnSetupLayer): «Aceptar» on A; the page's: its keys (text rows of
    -- text\rows\album.toml: the labels, and the keys as the game's button tags)
    GUIDE_OWN = { texts = {1847312674}, icons = {2750714971 --[[<CMD_ENTER>]]}, cmds = {1981080283 --[[CMD_ENTER]]} },
    GUIDE_PAGE = {
      texts = { 365833060 --[[BetterQoL.Album.GuidePage]] },
      icons = { 2684607496 --[[BetterQoL.Album.KeysPage]] },
      cmds = { 2075023265 --[[CMD_RIGHT]] },
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

-- the page's guide: first the A entry of each action another mod offers now (BetterQoL.AlbumActions, its text id
-- `guide`; docs/game/ui/album.md §5), then the page's own keys
local function PageGuide()
  local g = { texts = {}, icons = {}, cmds = {} }
  local acts = type(BetterQoL.AlbumActions) == "table" and BetterQoL.AlbumActions or {}
  for _, a in ipairs(acts) do
    if type(a) == "table" and type(a.guide) == "number" and type(a.On) == "function" then
      local ok, on = pcall(a.On)
      if ok and on == true then
        g.texts[#g.texts + 1] = a.guide
        g.icons[#g.icons + 1] = AL.GUIDE_OWN.icons[1]
        g.cmds[#g.cmds + 1] = AL.GUIDE_OWN.cmds[1]
        break
      end
    end
  end
  for k = 1, #AL.GUIDE_PAGE.texts do
    g.texts[#g.texts + 1] = AL.GUIDE_PAGE.texts[k]
    g.icons[#g.icons + 1] = AL.GUIDE_PAGE.icons[k]
    g.cmds[#g.cmds + 1] = AL.GUIDE_PAGE.cmds[k]
  end
  return g
end

-- the Caseta's background shown / hidden (logged once per change)
local function Background(on)
  if AL.background_on == on then return end
  AL.background_on = on
  M(AL.C.LAYER_VISIBLE, AL.BACKGROUND, 0, on)
  Log("caseta background " .. (on and "shown" or "hidden (the page's own background is drawn under the 3D model)"))
end

-- called by the album page (cross-menu call) when its plate is up (false) and when it closes (true), in the same step as
-- it shows / hides its own background
function BetterQoL_AlbumCasetaBackground(on)
  Background(on == true)
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
  Guide(PageGuide())
  pcall(funcLuaCommand, AL.C.OPEN_MENU, AL.PAGE)
  Log("page open asked (row " .. tostring(row) .. ")")
  coroutine.yield()
  while M(AL.C.IS_MENU, AL.PAGE) == true do coroutine.yield() end
  Background(true)
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
  if VRFW_Param.Has(AL.PLATE_FLAG) then VRFW_Param.Clear(AL.PLATE_FLAG) end
  if VRFW_Param.Has(AL.PLATE_CARD) then VRFW_Param.Clear(AL.PLATE_CARD) end
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
      AL.co, AL.background_on = nil, nil
      return init(...)
    end
  end
  local step = Step
  Step = function(...)
    if AL.co ~= nil then
      local ok, err = coroutine.resume(AL.co)
      if not ok then
        Log("visit error", tostring(err))
        Background(true)
      end
      if not ok or coroutine.status(AL.co) == "dead" then AL.co = nil end
    end
    if type(step) == "function" then return step(...) end
  end
end
