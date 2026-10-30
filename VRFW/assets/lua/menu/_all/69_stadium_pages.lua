-- menu_engine: STADIUM LIST PAGES, VRFW_StadiumPages. Definitions and one wrapper only (this file runs in every menu
-- VM, lua\_all); the engine calls are made from the menu's own callbacks, never at load.
--
-- The game's stadium pickers (free match, Battle Bay / VS rooms, ranked match settings) open one sub window of view
-- type 15 with every stadium of the list (soccer_game_option SOCCER_OPTION_FIELD_INFO, mods' [[stadium]] rows
-- included). The engine copies at most 90 rows into a sub window (CMND_SUB_WINDOW_OPEN, nie.exe v7.1.2 0xC395E0) and
-- drops the rest. A longer list is shown in pages of 88 rows with a «Previous page» row first and a «Next page» row
-- last (menu_text rows vrfw_stadium_list_previous / vrfw_stadium_list_next); picking one closes the window and opens
-- it again on that page. The menu's own script keeps its row numbers: the calls that address the window by row (row
-- names, list focus, check mark, focused row) and the window's two callbacks are translated between the whole list
-- and the page. A list of 90 rows or fewer, or a menu without a Step function, is never touched.
if VRFW_StadiumPages == nil then
  local P = {
    KIND = 15,                        -- sub-window view type of the stadium lists
    LIMIT = 90,                       -- rows the engine copies into one sub window
    PER_PAGE = 88,                    -- list rows per page (two rows left for the page rows)
    TIMEOUT = 300,                    -- frames a page turn may take before it gives up
    SUB_WINDOW = 968210065,           -- sub_window (the sub window's menu object)
    CMD_ROW_NAME = 2315959435,        -- (row, text): the name shown on a row
    CMD_WINDOW_POSITION = 63483614,   -- (x, y): the window's position
    CMD_LIST_FOCUS = 3647847018,      -- (row, list locator): the focused row
    CMD_LIST_READY = 3444627471,      -- (list locator) -> the list can take a focus
    CMD_CLOSE_OBJECT = VRFW_Cmd.CLOSE_MENU_OBJECT,     -- CMND_CLOSE_MENU_OBJECT
    CMD_IS_CLOSING_OBJECT = VRFW_Cmd.IS_CLOSING_MENU_OBJECT, -- CMND_IS_CLOSING_MENU_OBJECT
    MENU_IS_OPEN_LAYER = VRFW_Cmd.IS_OPEN_LAYER,  -- CMND_IS_OPEN_LAYER (layer, index, menu object)
    MENU_FOCUSED_ROW = 1727549139,    -- (list locator, sub_window) -> the focused row
    MENU_CHECK_ROW = 3497892782,      -- (list locator, row, sub_window): the check mark
    MENU_DRAW_PRIORITY = VRFW_Cmd.SET_DRAW_PRIORITY,  -- CMND_SET_DRAW_PRIORITY (layer, index, priority, flag, menu object)
    LOG = VRFW_Cmd.EVT_LOG,                 -- CMND_EVT_LOG
    TEXT_GET = VRFW_Cmd.TEXT_GET,            -- CMND_TEXT_GET
    TEXT_PREVIOUS = "vrfw_stadium_list_previous",
    TEXT_NEXT = "vrfw_stadium_list_next",
    CALLBACK = "VRFW_StadiumPages_Pick",
    FOCUS = "VRFW_StadiumPages_Focus",
    -- argument positions of MENU_DEF.OpenSubWindow after its two callbacks
    COUNT_ARGUMENT = 1, ROWS_ARGUMENT = 2, FOCUS_ARGUMENT = 6, KIND_ARGUMENT = 9, CHECKED_ARGUMENT = 12,
    PER_ROW_ARGUMENTS = {5, 11, 13, 14, 16},
    open = nil,                       -- the paged window while it is up
    hooked = false,
  }
  VRFW_StadiumPages = P

  function P.Log(...)
    if P.raw_command ~= nil then
      pcall(P.raw_command, P.LOG, "vrfw.StadiumPages", ...)
    end
  end

  local function page_count(rows)
    return math.floor((rows + P.PER_PAGE - 1) / P.PER_PAGE)
  end

  -- the page a list row is on (rows count from 0, as the menu's script numbers them)
  local function page_of(row)
    return math.floor(row / P.PER_PAGE) + 1
  end

  -- first and last list row of a page
  local function page_rows(o, page)
    local first = (page - 1) * P.PER_PAGE
    return first, math.min(first + P.PER_PAGE, o.rows) - 1
  end

  -- the window row of a list row on the current page, or nil
  function P.SlotOf(o, row)
    if type(row) ~= "number" or page_of(row) ~= o.page then
      return nil
    end
    local first = page_rows(o, o.page)
    return row - first + (o.page > 1 and 1 or 0)
  end

  -- the list row of a window row: a number, or "previous" / "next" for the page rows
  function P.RowOf(o, slot)
    local first, last = page_rows(o, o.page)
    local offset = 0
    if o.page > 1 then
      if slot == 0 then
        return "previous"
      end
      offset = 1
    end
    local row = first + slot - offset
    if row > last then
      return o.page < o.pages and "next" or nil
    end
    return row
  end

  -- the arguments of MENU_DEF.OpenSubWindow for the current page
  function P.PageArguments(o)
    local source = o.arguments
    local out = {n = source.n}
    for k = 1, source.n do
      out[k] = source[k]
    end
    local first, last = page_rows(o, o.page)
    local previous, nxt = o.page > 1, o.page < o.pages
    local function slice(list, fill)
      local rebuilt = {}
      if previous then
        rebuilt[#rebuilt + 1] = fill
      end
      for row = first, last do
        rebuilt[#rebuilt + 1] = list[row + 1]
      end
      if nxt then
        rebuilt[#rebuilt + 1] = fill
      end
      return rebuilt
    end
    local ids = slice(source[P.ROWS_ARGUMENT], 0)
    if previous then
      ids[1] = o.text_previous
    end
    if nxt then
      ids[#ids] = o.text_next
    end
    out[P.ROWS_ARGUMENT] = ids
    out[P.COUNT_ARGUMENT] = #ids
    for _, k in ipairs(P.PER_ROW_ARGUMENTS) do
      if type(source[k]) == "table" and #source[k] > 0 then
        out[k] = slice(source[k], k == 5 and 1 or 0)
      end
    end
    out[P.FOCUS_ARGUMENT] = P.SlotOf(o, o.focus_row) or (previous and 1 or 0)
    if type(source[P.CHECKED_ARGUMENT]) == "number" then
      out[P.CHECKED_ARGUMENT] = P.SlotOf(o, o.checked_row) or -1
    end
    return out
  end

  -- the window opens paged: the state, then the first page's arguments
  function P.Begin(callback, focus_callback, arguments)
    local rows = arguments[P.ROWS_ARGUMENT]
    local count = arguments[P.COUNT_ARGUMENT]
    if type(CRC32) ~= "function" or type(rows) ~= "table" or #rows ~= count then
      return nil
    end
    local focus = arguments[P.FOCUS_ARGUMENT]
    focus = type(focus) == "number" and focus >= 0 and focus < count and focus or 0
    local checked = arguments[P.CHECKED_ARGUMENT]
    local o = {
      arguments = arguments, rows = count, pages = page_count(count), page = page_of(focus),
      callback = callback, focus_callback = focus_callback, focus_row = focus,
      checked_row = type(checked) == "number" and checked or nil,
      names = {}, priorities = {}, text_previous = CRC32(P.TEXT_PREVIOUS), text_next = CRC32(P.TEXT_NEXT),
    }
    P.open = o
    P.Log("list of", count, "rows in", o.pages, "pages")
    return P.PageArguments(o)
  end

  -- page rows: close the window, the page turn ends in Step
  function P.Turn(o, delta)
    o.page = math.max(1, math.min(o.pages, o.page + delta))
    local first, last = page_rows(o, o.page)
    o.focus_row = delta > 0 and first or last
    o.step, o.frames = "closing", 0
    P.raw_command(P.CMD_CLOSE_OBJECT, P.SUB_WINDOW)
  end

  -- the names of the page rows (their text rows; the sub window would also show them from their ids)
  function P.NamePageRows(o)
    local first, last = page_rows(o, o.page)
    local function name(slot, text_id)
      local text = P.raw_command(P.TEXT_GET, text_id)
      if type(text) == "string" and text ~= "" then
        P.raw_command(P.CMD_ROW_NAME, slot, text)
      end
    end
    if o.page > 1 then
      name(0, o.text_previous)
    end
    if o.page < o.pages then
      name(last - first + 1 + (o.page > 1 and 1 or 0), o.text_next)
    end
  end

  -- a page turn that cannot finish: the menu's own cancel restores its screen
  function P.Cancel(o)
    P.open = nil
    local callback = _ENV[o.callback]
    if type(callback) == "function" then
      pcall(callback, -1)
    end
  end

  -- open the window on the current page with the names the menu gave its rows
  function P.OpenPage(o)
    local out = P.PageArguments(o)
    local focus_name = (type(o.focus_callback) == "string" and o.focus_callback ~= "") and P.FOCUS or o.focus_callback
    P.inner(P.CALLBACK, focus_name, table.unpack(out, 1, out.n))
    P.NamePageRows(o)
    local first, last = page_rows(o, o.page)
    for row = first, last do
      local name = o.names[row]
      if name ~= nil then
        P.raw_command(P.CMD_ROW_NAME, P.SlotOf(o, row), name)
      end
    end
  end

  -- one frame of a page turn (closing -> opening -> ready)
  function P.Tick()
    local o = P.open
    if o == nil or o.step == nil then
      return
    end
    o.frames = o.frames + 1
    if o.frames > P.TIMEOUT then
      P.Log("page turn timed out at", o.step)
      P.Cancel(o)
      return
    end
    if o.step == "closing" then
      local closing = P.raw_command(P.CMD_IS_CLOSING_OBJECT, P.SUB_WINDOW)
      local still_open = o.locator ~= nil and P.raw_menu(P.MENU_IS_OPEN_LAYER, o.locator, 0, P.SUB_WINDOW) == true
      if closing ~= true and not still_open then
        P.OpenPage(o)
        o.step = "opening"
      end
    elseif o.step == "opening" then
      if o.locator == nil or P.raw_menu(P.MENU_IS_OPEN_LAYER, o.locator, 0, P.SUB_WINDOW) == true then
        if o.position ~= nil then
          P.raw_command(P.CMD_WINDOW_POSITION, table.unpack(o.position, 1, o.position.n))
        end
        o.step = "ready"
      end
    elseif o.step == "ready" then
      if o.locator == nil or P.raw_command(P.CMD_LIST_READY, o.locator) == true then
        o.step = nil
        for _, call in ipairs(o.priorities) do
          P.raw_menu(table.unpack(call, 1, call.n))
        end
        if o.locator ~= nil then
          P.raw_command(P.CMD_LIST_FOCUS, P.SlotOf(o, o.focus_row) or 0, o.locator)
        end
      end
    end
  end

  -- the window's pick: a page row turns the page, a list row goes to the menu's callback as its own row number
  function P.Pick(slot, ...)
    local o = P.open
    if o == nil then
      return nil
    end
    local callback = _ENV[o.callback]
    if type(slot) ~= "number" or slot < 0 then
      P.open = nil
      if type(callback) == "function" then
        return callback(slot, ...)
      end
      return nil
    end
    if o.step ~= nil then
      return nil
    end
    local row = P.RowOf(o, slot)
    if row == "previous" then
      return P.Turn(o, -1)
    elseif row == "next" then
      return P.Turn(o, 1)
    elseif row == nil then
      return nil
    end
    o.focus_row = row
    if type(callback) == "function" then
      return callback(row, ...)
    end
    return nil
  end

  -- the window's focus: a list row goes to the menu's callback as its own row number; page rows are not reported
  function P.Focus(slot, ...)
    local o = P.open
    local callback = o and _ENV[o.focus_callback]
    if type(callback) ~= "function" or o.step ~= nil then
      return nil
    end
    if type(slot) == "number" and slot >= 0 then
      local row = P.RowOf(o, slot)
      if type(row) ~= "number" then
        return nil
      end
      o.focus_row = row
      return callback(row, ...)
    end
    return callback(slot, ...)
  end

  -- funcLuaCommand while a paged window is up: row names, focus and position addressed by the menu's row numbers
  function P.Command(nxt, ...)
    local o = P.open
    if o ~= nil then
      local command, a1, a2 = ...
      if command == P.CMD_ROW_NAME and type(a1) == "number" then
        o.names[a1] = a2
        local slot = P.SlotOf(o, a1)
        if slot == nil then
          return true
        end
        return nxt(command, slot, select(3, ...))
      elseif command == P.CMD_LIST_FOCUS and type(a1) == "number" then
        o.locator = a2
        return nxt(command, P.SlotOf(o, a1) or 0, select(3, ...))
      elseif command == P.CMD_WINDOW_POSITION then
        o.position = table.pack(select(2, ...))
      elseif command == P.CMD_CLOSE_OBJECT and a1 == P.SUB_WINDOW and o.step == nil then
        P.open = nil
      end
    end
    return nxt(...)
  end

  -- funcLuaMenuCommand while a paged window is up: the focused row, the check mark and the rows' draw priorities
  function P.MenuCommand(nxt, ...)
    local o = P.open
    if o ~= nil and o.step == nil then
      local command, a1, a2, a3 = ...
      if command == P.MENU_FOCUSED_ROW and a2 == P.SUB_WINDOW then
        local slot = nxt(...)
        local row = type(slot) == "number" and P.RowOf(o, slot) or nil
        return type(row) == "number" and row or 0
      elseif command == P.MENU_CHECK_ROW and a3 == P.SUB_WINDOW and type(a2) == "number" then
        o.checked_row = a2
        local slot = P.SlotOf(o, a2)
        if slot == nil then
          return -1
        end
        return nxt(command, a1, slot, select(4, ...))
      elseif command == P.MENU_IS_OPEN_LAYER and a3 == P.SUB_WINDOW then
        o.locator = o.locator or a1
      elseif command == P.MENU_DRAW_PRIORITY and select(6, ...) == P.SUB_WINDOW then
        o.priorities[#o.priorities + 1] = table.pack(...)
      end
    end
    return nxt(...)
  end

  -- the wrappers of this VM, made the first time a long list opens (the engine registers funcLuaCommand after the
  -- chunk); false when the menu has no Step to finish a page turn in
  function P.Hook()
    if P.hooked then
      return true
    end
    if type(funcLuaCommand) ~= "function" or type(funcLuaMenuCommand) ~= "function" or type(Step) ~= "function" then
      return false
    end
    P.hooked = true
    -- the window's own calls go past every command handler (VRFW_Host)
    P.raw_command, P.raw_menu = VRFW_Host.RealCommand, VRFW_Host.RealMenuCommand
    VRFW_Host.HookCommand({P.CMD_ROW_NAME, P.CMD_LIST_FOCUS, P.CMD_WINDOW_POSITION, P.CMD_CLOSE_OBJECT}, P.Command,
      "VRFW.stadium_pages")
    VRFW_Host.HookCommand({P.MENU_FOCUSED_ROW, P.MENU_CHECK_ROW, P.MENU_IS_OPEN_LAYER, P.MENU_DRAW_PRIORITY},
      P.MenuCommand, "VRFW.stadium_pages", {menu = true})
    local step = Step
    Step = function(...)
      local ok, problem = pcall(P.Tick)
      if not ok then
        P.Log("page turn failed", tostring(problem))
        P.open = nil
      end
      return step(...)
    end
    _ENV[P.CALLBACK] = P.Pick
    _ENV[P.FOCUS] = P.Focus
    return true
  end

  -- MENU_DEF.OpenSubWindow of this VM (wrapped once the chunk's includes are loaded)
  function P.Wrap()
    if MENU_DEF == nil or type(MENU_DEF.OpenSubWindow) ~= "function" or P.inner ~= nil then
      return
    end
    P.inner = MENU_DEF.OpenSubWindow
    MENU_DEF.OpenSubWindow = function(callback, focus_callback, ...)
      local count, kind = (select(P.COUNT_ARGUMENT, ...)), (select(P.KIND_ARGUMENT, ...))
      P.open = nil
      if kind == P.KIND and type(count) == "number" and count > P.LIMIT and type(callback) == "string" and P.Hook() then
        local ok, out = pcall(P.Begin, callback, focus_callback, table.pack(...))
        if ok and out ~= nil then
          local focus_name = (type(focus_callback) == "string" and focus_callback ~= "") and P.FOCUS or focus_callback
          local result = table.pack(P.inner(P.CALLBACK, focus_name, table.unpack(out, 1, out.n)))
          pcall(P.NamePageRows, P.open)
          return table.unpack(result, 1, result.n)
        end
        P.open = nil
        if not ok then
          P.Log("paging failed", tostring(out))
        end
      end
      return P.inner(callback, focus_callback, ...)
    end
  end

  P.Wrap()
end
