-- VRFW_ChildMenu: the open / redraw / close handshake of a draw-only child menu (registry priority 0: it never takes
-- the pad) opened over a host menu that keeps the keys. Definitions only: no engine call at load. Event-driven: the
-- host's FinalizeMenu closes its children, the child tells its host when it opened and when it closed.
--
-- Host side (in the host menu's VM; every call from a callback):
--   local child = VRFW_ChildMenu.Host(menu_name, { prefix = "<params prefix>", log = function(...) end,
--                                                  label = "<name in the log>", send = function(page) end })
--   child.Show(page, host, ...)  the child opened, or drawn again when it is up (page and host written to the
--                                parameters <prefix>page and <prefix>host_hi / _lo, send(page) writes the child's own
--                                ones; ... goes to the child's on_redraw)
--   child.Hide(why)              the child closed (another page, the host leaving)
--   child.Step()                 every Step of the host: opens the child after an earlier one closed
--   child.Call(fn, ...)          a cross-menu call of a function of the open child
--   child.Open()                 true while the child is open
--   child.Wanted()               true while the child is wanted on screen
--   VRFW_ChildMenu.Close(menu_name, why) -> true when it was open: a child menu closed from a menu not its host
-- Child side (in the child menu's VM):
--   local child = VRFW_ChildMenu.Child(menu_name, { prefix = "<params prefix>", log = function(...) end,
--                                                   label = "<name in the log>",
--                                                   on_redraw = function(page, ...) end,  -- draw the page again
--                                                   on_close = function(why) end })       -- hide every piece now
--   child.Init()      in OnInit: reads the page and the host -> page, host
--   child.Step()      in Step -> true while closing (draw nothing); the first Step tells the host it opened
--   child.Finalize()  in FinalizeMenu: tells the host it closed
--   child.Host(), child.Page(), child.Closing()
if VRFW_ChildMenu == nil then
  local ChildMenu = {}

  local CROSS_CALL = 830228314    -- (menu, function name, ...): a function of another menu's Lua
  local REVIVE_STEPS = 30         -- a child still closing this many host Steps after it is wanted again is shown again
  local CLOSE_RETRY_STEPS = 30    -- a closing child asks the engine again every this many of its Steps
  local CLOSE_RETRIES = 10        -- at most this many close requests of a closing child

  local function crc(s)
    return type(s) == "number" and s or VRFW_Crc32(s)
  end

  local function exists(menu)
    return funcLuaMenuCommand(VRFW_Cmd.IS_EXIST_MENU_OBJECT, menu) == true
  end

  local function logger_of(spec, label)
    if type(spec.log) == "function" then
      return spec.log
    end
    local log
    return function(...)
      log = log or VRFW_Log.New("VRFW.child_menu")
      log(label, ...)
    end
  end

  -- ---- host side ------------------------------------------------------------------------------------------------------
  local hosted = {}               -- menu crc -> host object of this VM
  local finalize_hooked = false

  -- the host menu destroyed: every child of it closes (it no longer tells this host anything)
  local function hook_finalize()
    if finalize_hooked then
      return
    end
    finalize_hooked = true
    local previous = _ENV.FinalizeMenu
    _ENV.FinalizeMenu = function(...)
      for _, h in pairs(hosted) do
        pcall(h.Gone)
      end
      if type(previous) == "function" then
        return previous(...)
      end
    end
  end

  -- the child's own reports (cross-menu calls of the child)
  function VRFW_ChildMenu_Opened(menu)
    local h = hosted[menu]
    if h then
      h.Event("opened")
    end
  end

  function VRFW_ChildMenu_Closed(menu)
    local h = hosted[menu]
    if h then
      h.Event("closed")
    end
  end

  function ChildMenu.Host(menu_name, spec)
    spec = type(spec) == "table" and spec or {}
    local menu = crc(menu_name)
    local prefix = spec.prefix or (tostring(menu_name) .. "_")
    local label = spec.label or tostring(menu_name)
    local log = logger_of(spec, label)
    -- state: "closed" | "open" | "closing" (asked to close, its closed report not in yet)
    local S = { state = "closed", want = nil, host = 0, args = {}, wait = 0, unwanted = false }
    local h = {}

    local function send()
      VRFW_Param.Replace(crc(prefix .. "page"), S.want or -1)
      VRFW_Param.SetU32(prefix .. "host", S.host or 0)
      if type(spec.send) == "function" then
        spec.send(S.want)
      end
    end

    local function redraw()
      send()
      pcall(funcLuaCommand, CROSS_CALL, menu, "VRFW_ChildMenu_Redraw", S.want, S.host,
        table.unpack(S.args, 1, S.args.n or #S.args))
    end

    local function open()
      send()
      funcLuaCommand(VRFW_Cmd.OPEN_MENU_OBJECT, menu)
      S.state, S.wait = "open", 0
      log("opened (page " .. tostring(S.want) .. ")")
    end

    local function request_close(why, gone)
      pcall(funcLuaCommand, CROSS_CALL, menu, "VRFW_ChildMenu_Close", why, gone == true)
      pcall(funcLuaCommand, VRFW_Cmd.CLOSE_MENU_OBJECT, menu)
      S.state, S.wait = "closing", 0
    end

    function h.Show(page, host, ...)
      hook_finalize()
      S.want = page or -1
      S.host = host or 0
      S.args = table.pack(...)
      if S.state == "open" then
        redraw()
      elseif S.state == "closed" then
        if exists(menu) then
          -- one of an earlier opening still there: it reports its close, or it is shown again (Step)
          S.state, S.wait = "closing", 0
        else
          open()
        end
      end
    end

    function h.Hide(why)
      local was = S.want ~= nil
      S.want = nil
      local there = S.state == "closed" and exists(menu)
      if S.state == "open" or there then
        request_close(why or "the host left it")
        log("closed (" .. tostring(why) .. ", wanted " .. tostring(was) .. ", existed " .. tostring(there) .. ")")
      end
    end

    -- the host menu destroyed
    function h.Gone()
      S.want = nil
      if S.state ~= "closed" or exists(menu) then
        request_close("host closed", true)
        log("closed (its host closed)")
      end
    end

    function h.Event(what)
      if what == "closed" then
        local was = S.state
        S.state, S.wait = "closed", 0
        if S.want ~= nil and was == "open" then
          log("gone while it is wanted; opened again")
        end
      elseif what == "opened" and S.want == nil and S.state == "closing" then
        S.unwanted = true   -- opened after its close was asked: asked again on the next Step
      end
    end

    function h.Step()
      if S.unwanted then
        S.unwanted = false
        if S.want == nil then
          request_close("opened while not wanted")
          log("opened while not wanted; asked to close again")
        end
      end
      if S.want == nil then
        return
      end
      if S.state == "closed" then
        open()
      elseif S.state == "closing" then
        S.wait = S.wait + 1
        if S.wait >= REVIVE_STEPS then
          if exists(menu) then
            redraw()
            S.state, S.wait = "open", 0
            log("the earlier one still existed; shown again")
          else
            open()
          end
        end
      end
    end

    function h.Call(fn, ...)
      if S.state == "open" then
        return pcall(funcLuaCommand, CROSS_CALL, menu, fn, ...)
      end
      return false
    end

    function h.Open()
      return S.state == "open"
    end

    function h.Wanted()
      return S.want ~= nil
    end

    hosted[menu] = h
    return h
  end

  -- a child menu closed from any menu (not its host) -> true when it was open
  function ChildMenu.Close(menu_name, why)
    local menu = crc(menu_name)
    if not exists(menu) then
      return false
    end
    pcall(funcLuaCommand, CROSS_CALL, menu, "VRFW_ChildMenu_Close", why)
    pcall(funcLuaCommand, VRFW_Cmd.CLOSE_MENU_OBJECT, menu)
    return true
  end

  -- ---- child side -----------------------------------------------------------------------------------------------------
  function ChildMenu.Child(menu_name, spec)
    spec = type(spec) == "table" and spec or {}
    local menu = crc(menu_name)
    local prefix = spec.prefix or (tostring(menu_name) .. "_")
    local label = spec.label or tostring(menu_name)
    local log = logger_of(spec, label)
    local S = { page = -1, host = nil, closing = false, tries = 0, frame = 0, told = false }
    local c = {}

    local function read()
      local page = tonumber(VRFW_Param.Get(crc(prefix .. "page")))
      local host = VRFW_Param.GetU32(prefix .. "host")
      if page ~= nil then
        S.page = page
      end
      if host ~= nil and host ~= 0 then
        S.host = host
      end
    end

    local function tell_host(fn)
      if S.host ~= nil and exists(S.host) then
        pcall(funcLuaCommand, CROSS_CALL, S.host, fn, menu)
      end
    end

    local function close_now()
      S.tries = S.tries + 1
      pcall(funcLuaCommand, VRFW_Cmd.CLOSE_MENU_OBJECT, menu)
    end

    local function begin_close(why)
      if not S.closing then
        log("closing (" .. tostring(why) .. ")")
      end
      S.closing, S.frame = true, 0
      if type(spec.on_close) == "function" then
        pcall(spec.on_close, why)
      end
      close_now()
    end

    -- the host's calls (cross-menu call)
    function VRFW_ChildMenu_Redraw(page, host, ...)
      read()
      if page ~= nil then
        S.page = page
      end
      if host ~= nil and host ~= 0 then
        S.host = host
      end
      if S.closing then
        log("shown again before it closed (tries " .. S.tries .. ")")
        S.closing, S.tries = false, 0
      end
      if type(spec.on_redraw) == "function" then
        spec.on_redraw(S.page, ...)
      end
    end

    function VRFW_ChildMenu_Close(why, host_gone)
      if host_gone then
        S.host = nil
      end
      begin_close(why or "the host left it")
    end

    function c.Init()
      S.page, S.host, S.closing, S.tries, S.frame, S.told = -1, nil, false, 0, 0, false
      read()
      return S.page, S.host
    end

    function c.Step()
      if not S.told then
        S.told = true
        tell_host("VRFW_ChildMenu_Opened")
      end
      if not S.closing then
        return false
      end
      S.frame = S.frame + 1
      if S.tries < CLOSE_RETRIES and S.frame % CLOSE_RETRY_STEPS == 0 then
        close_now()
        if S.tries == CLOSE_RETRIES then
          log("still open after " .. S.tries .. " close requests (hidden meanwhile)")
        end
      end
      return true
    end

    function c.Finalize()
      tell_host("VRFW_ChildMenu_Closed")
    end

    function c.Host()
      return S.host
    end

    function c.Page()
      return S.page
    end

    function c.Closing()
      return S.closing
    end

    return c
  end

  VRFW_ChildMenu = ChildMenu
end
