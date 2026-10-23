-- Utilities › «Estadísticas del club» (docs/game/ui/club-stats.md): the row of «Caseta del club» (play_guide_top_menu;
-- graft util_club_stats_row) opens the page util_club_stats_menu (content\menus\club_stats.toml, script
-- assets\lua\screens\util_club_stats_menu.lua) exactly as this menu opens its «Archivo de escenas»
-- (UpdateSceneArchiveCoroutine): input off, the Caseta's picture closed and its list hidden, the header titled
-- «Estadísticas del club» (header type 13: the «Récords» icon; the archive uses 15, its theatre icon), the page opened; when the page is gone (B / Esc / right
-- click) the Caseta comes back with its cursor on the row. The Caseta's button guide shows «Ordenar» on Select while the
-- page is open (the page sorts with it) and gets its own «Aceptar» back. Runs as a coroutine resumed from Step.
-- Engine calls only from the menu callbacks.
BetterQoL = type(BetterQoL) == "table" and BetterQoL or {}

if UTIL_CST == nil then
  UTIL_CST = {
    C = {
      LOG = 3661580131, TEXT_GET = 4074371074,
      MENU_INPUT = 1558704558 --[[CMND_SET_INPUT_ENABLE_MENU_OBJECT]], ANIME = 3781155141 --[[CMND_PLAY_ANIME_TYPE]],
      HIDE_MENU = 369172623, SHOW_MENU = 66378409, OPEN_MENU = 433545986 --[[CMND_OPEN_MENU_OBJECT]],
      IS_MENU = 2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], CTRL_FOCUS = 3518307824, FOCUS_SET = 3466097042,
      GET_FOCUS = 2603265800,
      GUIDE_SET = 2209673388, GUIDE_CMD = 452337289,
    },
    MENU = 1281873114,                    -- play_guide_top_menu
    PAGE = 1740759835,                    -- util_club_stats_menu
    LIST = 530619243,                     -- mainmenu90_12_list_item_small
    PICTURE = 243035880,                  -- playguide01_00_p1_background
    GUIDE = 1138543975,                   -- mainmenu01_06_base_button_guide
    OPEN_ANIME = 71445658,                -- «Open»
    HEADER = { PAGE_TYPE = 13, TYPE = 14, ICON = 3275740866 --[[mode_base05]], TITLE = 882201751 },
    -- the Caseta's own guide (retail OnSetupLayer): «Aceptar» on A; the page's: «Ordenar» on Select
    GUIDE_OWN = { texts = {1847312674}, icons = {2750714971 --[[<CMD_ENTER>]]}, cmds = {1981080283 --[[CMD_ENTER]]} },
    GUIDE_PAGE = { icons = {2387151820 --[[<CMD_FUNC2>]]}, cmds = {3170216173 --[[CMD_FUNC2]]} },
    SORT_TEXT = 2723098887,                -- BetterQoL.ClubStats.Sort
    co = nil,
  }
end

local CS = UTIL_CST

local function Log(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, CS.C.LOG, "utilities club_stats " .. table.concat(p, " "))
end

local function M(cmd, ...)
  local ok, a = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a end
  return nil
end

local function Header(kind, text)
  if type(SwapSoccerTopCommonHeaderByHeaderType) ~= "function" then return end
  if type(text) == "number" then
    local ok, t = pcall(funcLuaCommand, CS.C.TEXT_GET, text)
    text = ok and t or nil
  end
  if type(text) == "string" then pcall(SwapSoccerTopCommonHeaderByHeaderType, kind, text, CS.HEADER.ICON) end
end

local function Guide(g, texts)
  M(CS.C.GUIDE_SET, CS.MENU, CS.GUIDE, texts, g.icons, {})
  M(CS.C.GUIDE_CMD, CS.MENU, CS.GUIDE, g.cmds)
end

-- the page's whole visit (UpdateSceneArchiveCoroutine of the retail script, with this page)
local function Visit()
  local row = M(CS.C.GET_FOCUS, CS.LIST) or 0
  M(CS.C.MENU_INPUT, CS.MENU, false)
  M(CS.C.ANIME, CS.PICTURE, 0, CS.OPEN_ANIME, 2)
  M(CS.C.HIDE_MENU, CS.MENU)
  Header(CS.HEADER.PAGE_TYPE, 1451400137 --[[BetterQoL.ClubStats.Row]])
  Guide(CS.GUIDE_PAGE, {CS.SORT_TEXT})
  pcall(funcLuaCommand, CS.C.OPEN_MENU, CS.PAGE)
  Log("page open asked (row " .. tostring(row) .. ")")
  coroutine.yield()
  while M(CS.C.IS_MENU, CS.PAGE) == true do coroutine.yield() end
  M(CS.C.SHOW_MENU, CS.MENU)
  M(CS.C.ANIME, CS.PICTURE, 0, CS.OPEN_ANIME, 0)
  Guide(CS.GUIDE_OWN, CS.GUIDE_OWN.texts)
  M(CS.C.CTRL_FOCUS, CS.LIST, true)
  M(CS.C.FOCUS_SET, CS.LIST, row)
  -- the Caseta's own focus code puts its cursor and help line back on the row
  if type(OnChangeFocus) == "function" then pcall(OnChangeFocus, CS.LIST, row) end
  Header(CS.HEADER.TYPE, CS.HEADER.TITLE)
  M(CS.C.MENU_INPUT, CS.MENU, true)
  Log("back from the page")
end

local function Open()
  if CS.co ~= nil then return end
  CS.co = coroutine.create(Visit)
  local ok, err = coroutine.resume(CS.co)
  if not ok then
    Log("open failed", tostring(err))
    CS.co = nil
  end
end

BetterQoL.ClubStats = { Open = Open }

if UTIL_CST_HOOKED == nil then
  UTIL_CST_HOOKED = true
  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      CS.co = nil
      return init(...)
    end
  end
  local step = Step
  Step = function(...)
    if CS.co ~= nil then
      local ok, err = coroutine.resume(CS.co)
      if not ok then Log("visit error", tostring(err)) end
      if not ok or coroutine.status(CS.co) == "dead" then CS.co = nil end
    end
    if type(step) == "function" then return step(...) end
  end
end
