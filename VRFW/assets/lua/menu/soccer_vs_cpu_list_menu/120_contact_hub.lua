-- contact hub (VR-Framework service): the free-match list («Competir contra bots», soccer_vs_cpu_list_menu) as the team
-- hub of a contact set ([VRFW.ContactSet] Hub = "free_match", docs/framework/contact-map.md §22): its series tabs, the
-- teams you have beaten with their crests and the selected team's lineup on the right, as the game shows them; choosing
-- a team opens the contact map screen on that team's page (vrfw_contact_map_menu, parameter vrfw_contact_game) instead
-- of a match. On only while the opener asked for it (parameter vrfw_contact_hub = the set, written by the shop redirect,
-- 70_shop_redirect.lua); every other open of the list is the game's free match. Handlers of the framework's host of this
-- script (000_host.lua); no engine call at load time.
if VRFW_Host ~= nil then
  local CH = {
    KEY_HUB = 3979190066,       -- crc32("vrfw_contact_hub"): parameter in, the set
    KEY_SET = 1128821923,       -- crc32("vrfw_contact_set")
    KEY_PARENT = 2740862541,    -- crc32("vrfw_contact_parent")
    KEY_GAME = 3811836272,      -- crc32("vrfw_contact_game")
    HUB = 1691394521,           -- CMND_VRFW_CONTACT_HUB (set) -> { menu, title }
    FIND = 93238014,            -- CMND_VRFW_CONTACT_FIND (set, game) -> { map, zone }
    FILTER = 2812667080,        -- CMND_VRFW_CONTACT_HUB_FILTER (set / 0): the list keeps only the teams with a page
    ORB = 4088477286,           -- vsroute01_06b_town_map_piece_clear_icon (a row's difficulty / clear capsule)
    YIELD_CALL = 830228314,     -- (menu, "global function", args...) in another menu's VM
    LIST = 1107559438,          -- team05_03_soccer_cpu_opponent_list
    ITEM = 1074924810,          -- mainmenu90_19_vs_cpu_list_item
    MENU = 1970579282,          -- soccer_vs_cpu_list_menu
    SCREEN = 1355292071,        -- vrfw_contact_map_menu
    CURSOR = 2296367164,        -- cmn05_01_cursor
    HEADER = 575058101, HEADER_TEXT = 1220590795,   -- mainmenu90_01_header, _text_sub_title02
    GUIDE = 3078308064, GUIDE_MESH = 378156699,      -- mainmenu90_05_content_guide_line01, _text_guide01
    HELP = 415711628,           -- vrfw_cm_hub_help «Elige un equipo para ver los jugadores que puedes fichar.»
    EMPTY = 1404656913,         -- vrfw_cm_hub_empty «Este equipo no tiene jugadores que fichar.»
    P_HAS = 2947612279, P_GET = 3522198769, P_SET = 3860611758, P_CLEAR = 3363400568,
    OPEN = 433545986, EXISTS = 2231168902, ACTIVE = 1558704558, VISIBLE = 2171393651, HIDE = 369172623,
    SHOW = 66378409, SET_TEXT = 1083631230, TEXT_GET = 4074371074, FOCUS_DATA = 1666448199, LOG = 3661580131,
    SE = 1917805374, SE_NG = 2086672038, MSG = 2289627655, MSG_WAIT = 2351835063,
    set = nil, title = "",
  }
  VRFW_ContactHub = CH

  local function log(...)
    pcall(funcLuaCommand, CH.LOG, "vrfw.ContactHub", ...)
  end

  local function text(id)
    local ok, s = pcall(funcLuaCommand, CH.TEXT_GET, id)
    return (ok and type(s) == "string") and s or ""
  end

  -- the header and the help line of the office (after every redraw of the list's own)
  function CH.Dress()
    if CH.set == nil then
      return
    end
    if CH.title ~= "" then
      pcall(funcLuaMenuCommand, CH.SET_TEXT, CH.HEADER, CH.HEADER_TEXT, CH.title, 0)
    end
    pcall(funcLuaMenuCommand, CH.SET_TEXT, CH.GUIDE, CH.GUIDE_MESH, text(CH.HELP), 0)
  end

  -- the chosen team's page: the contact map screen over the list (the list hidden while it is up, as a shop over
  -- the Mercado); a team without a page (no player to sign): the error sound and a message
  function CH.Open()
    local ok, okd, game = pcall(funcLuaMenuCommand, CH.FOCUS_DATA, 0)
    if not ok or not okd or type(game) ~= "number" or game == 0 then
      return
    end
    local okf, found = pcall(funcLuaCommand, CH.FIND, CH.set, game)
    if not okf or type(found) ~= "table" then
      log("no team page for game", game)
      funcLuaCommand(CH.SE, CH.SE_NG)
      funcLuaCommand(CH.MSG, text(CH.EMPTY), 0, 0, 0, 0, 0, false)
      funcLuaCommand(CH.MSG_WAIT, 1, 0)        -- a notice: one button
      return
    end
    log("open", game, tostring(found.map), tostring(found.zone))
    for _, k in ipairs({CH.KEY_SET, CH.KEY_PARENT, CH.KEY_GAME}) do
      funcLuaCommand(CH.P_CLEAR, k)
    end
    funcLuaCommand(CH.P_SET, CH.KEY_SET, 0, CH.set, 1)
    funcLuaCommand(CH.P_SET, CH.KEY_PARENT, 0, CH.MENU, 1)
    funcLuaCommand(CH.P_SET, CH.KEY_GAME, 0, game, 1)
    funcLuaMenuCommand(CH.ACTIVE, CH.MENU, false)
    funcLuaMenuCommand(CH.VISIBLE, CH.CURSOR, false)
    -- one title and one button guide on the page: this list's chrome and its opener's (the Mercado) are hidden while
    -- the screen is up (VRFW_HubYield, _all3_hub_yield.lua)
    local okp, parent = pcall(function() return MENU_DEF.GetParentMenuID(CH.MENU) end)
    CH.parent = (okp and type(parent) == "number" and parent ~= 0) and parent or nil
    if VRFW_HubYield ~= nil then
      pcall(VRFW_HubYield, true, CH.SCREEN)
    end
    if CH.parent ~= nil then
      pcall(funcLuaCommand, CH.YIELD_CALL, CH.parent, "VRFW_HubYield", true, CH.SCREEN)
    end
    funcLuaMenuCommand(CH.HIDE, CH.MENU)
    funcLuaCommand(CH.OPEN, CH.SCREEN)
    coroutine.yield()
    while funcLuaMenuCommand(CH.EXISTS, CH.SCREEN) do
      coroutine.yield()
    end
    funcLuaMenuCommand(CH.SHOW, CH.MENU)
    if VRFW_HubYield ~= nil then
      pcall(VRFW_HubYield, false, CH.SCREEN)
    end
    if CH.parent ~= nil then
      pcall(funcLuaCommand, CH.YIELD_CALL, CH.parent, "VRFW_HubYield", false, CH.SCREEN)
    end
    if type(UpdateButtonGuideFromTopMenu) == "function" then
      pcall(UpdateButtonGuideFromTopMenu, 11)
    end
    CH.Dress()
    funcLuaMenuCommand(CH.ACTIVE, CH.MENU, true)
    funcLuaMenuCommand(CH.VISIBLE, CH.CURSOR, true)
  end

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", {
    id = "menu_engine.contact_hub", phase = "before",
    fn = function()
      CH.set, CH.title = nil, ""
      if funcLuaCommand(CH.P_HAS, CH.KEY_HUB) == true then
        CH.set = funcLuaCommand(CH.P_GET, CH.KEY_HUB)
        funcLuaCommand(CH.P_CLEAR, CH.KEY_HUB)
        if type(CH.set) ~= "number" or CH.set == 0 then
          CH.set = nil
        end
      end
      if VRFW_FM ~= nil and VRFW_FM.Bypass ~= nil then   -- the free-match rules stand aside in the hub
        pcall(VRFW_FM.Bypass, "vr_framework.contact_hub", CH.set ~= nil)
      end
      pcall(funcLuaCommand, CH.FILTER, CH.set or 0)   -- before the list builds its rows
      if CH.set ~= nil then
        local ok, hub = pcall(funcLuaCommand, CH.HUB, CH.set)
        if ok and type(hub) == "table" and hub.title then
          CH.title = text(hub.title)
        end
        log("on", CH.set, CH.title)
      end
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", {
    id = "menu_engine.contact_hub.dress", phase = "after",
    fn = function() CH.Dress() end,
  })

  -- the list's own team check (a valid team dock for a match) does not apply: nothing is played here
  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnEnter", {
    id = "menu_engine.contact_hub", phase = "around", priority = -300,
    fn = function(nxt, a1, ...)
      if CH.set ~= nil and a1 == CH.LIST then
        return nil
      end
      return nxt(a1, ...)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnDecideFocus", {
    id = "menu_engine.contact_hub", phase = "around", priority = -300,
    fn = function(nxt, a1, ...)
      if CH.set ~= nil and a1 == CH.LIST then
        CH.Open()
        return nil
      end
      return nxt(a1, ...)
    end,
  })

  -- no difficulty / clear capsule on a row of the hub (nothing is played here)
  VRFW_Host.on("soccer_vs_cpu_list_menu", "UpdateItem", {
    id = "menu_engine.contact_hub", phase = "after", priority = 300,
    fn = function(r, a1, a2)
      if CH.set ~= nil and type(a2) == "number" then
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], CH.ORB, a2, false)
      end
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", {
    id = "menu_engine.contact_hub", phase = "after", priority = 300,
    fn = function(r, a1)
      if CH.set ~= nil and a1 == CH.ITEM then
        CH.Dress()
      end
    end,
  })
end
