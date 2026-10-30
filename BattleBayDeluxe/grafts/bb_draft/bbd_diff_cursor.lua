-- BattleBayDeluxe bb_draft, the cursor on the Campaña's difficulty window (enjoy_team_select_menu_campaign).
-- Deciding a team hides the grid and opens the difficulty window (list win05_02_general_sub_list_item + the start
-- button cmn03_05_cmn_button_b_graphic_text «Empezar partido»). The grid's tiles keep their «cursor» attach to
-- cmn05_01_cursor traced while they are hidden, so the arrow stayed on the decided tile (left of the window) when the
-- focus reached the button. When the focus enters the window (OnChangeFocus on the list or the button) the tiles'
-- attach is released and the focused element's own cursor attach is traced and set as the cursor locator (the retail
-- recipe: attach trace + CMND_SET_CURSOR_LOCATOR); when the window closes (OnCloseEndLayer) the tiles' attach is
-- traced again and the cursor locator goes back to the focused tile. Globals only; nothing runs at chunk load.
BBD_DIFF_CURSOR = {
  GRID = 106197494 --[[vs01_43_enjoy_team_select_emblem_icon]],
  WINDOW = 2996147312 --[[win05_11_select_difficulty_win_base]],
  LIST = 1027507646 --[[win05_02_general_sub_list_item]],
  START = 336167129 --[[cmn03_05_cmn_button_b_graphic_text]],
  CURSOR = 3313461902 --[[cursor: the attach of the grid tiles and of the start button]],
  LIST_CURSOR = 21268581 --[[select_cur: the attach of the list rows]],
  ATTACH_TRACE = @crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@ --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE (layer, idx, attach, on)]],
  CURSOR_LOCATOR = @crc:CMND_SET_CURSOR_LOCATOR@ --[[CMND_SET_CURSOR_LOCATOR (layer, attach, idx, count)]],
  LAYER_COUNT = @crc:CMND_GET_CREATE_LAYER_NUM@,
  IS_OPEN = @crc:CMND_IS_OPEN_LAYER@,
  FOCUS_INDEX = 2603265800,
  released = false,
  last = nil,
}

-- the logger (VRFW_Log), made at the first line: the framework's menu files load after the graft blocks
function BBD_DiffCursorLog(...)
  BBD_DIFF_CURSOR.logger = BBD_DIFF_CURSOR.logger or VRFW_Log.New("BattleBayDeluxe.difficulty_cursor")
  BBD_DIFF_CURSOR.logger(...)
end

-- the instance count of a layer (0 when unknown)
function BBD_DiffCursorCount(layer)
  local n = funcLuaMenuCommand(BBD_DIFF_CURSOR.LAYER_COUNT, layer)
  return type(n) == "number" and n or 0
end

-- every grid tile's cursor attach traced or not
function BBD_DiffCursorGrid(on)
  local C = BBD_DIFF_CURSOR
  for i = 0, BBD_DiffCursorCount(C.GRID) - 1 do
    funcLuaMenuCommand(C.ATTACH_TRACE, C.GRID, i, C.CURSOR, on)
  end
end

-- the focus entered the window's list (row idx) or its start button: the cursor on that element only
function BBD_DiffCursorOn(layer, idx)
  local C = BBD_DIFF_CURSOR
  if not C.released then
    BBD_DiffCursorGrid(false)
    C.released = true
  end
  local rows = BBD_DiffCursorCount(C.LIST)
  for i = 0, rows - 1 do
    funcLuaMenuCommand(C.ATTACH_TRACE, C.LIST, i, C.LIST_CURSOR, layer == C.LIST and i == idx)
  end
  funcLuaMenuCommand(C.ATTACH_TRACE, C.START, 0, C.CURSOR, layer == C.START)
  if layer == C.START then
    funcLuaMenuCommand(C.CURSOR_LOCATOR, C.START, C.CURSOR, 0, 1)
  else
    funcLuaMenuCommand(C.CURSOR_LOCATOR, C.LIST, C.LIST_CURSOR, idx, rows)
  end
  local where = layer == C.START and "start button" or ("list row " .. tostring(idx))
  if where ~= C.last then
    C.last = where
    BBD_DiffCursorLog("cursor on the " .. where)
  end
end

-- the window closed: the grid tiles' attach traced again, the cursor locator on the focused tile
function BBD_DiffCursorBack()
  local C = BBD_DIFF_CURSOR
  if not C.released then
    return
  end
  C.released, C.last = false, nil
  funcLuaMenuCommand(C.ATTACH_TRACE, C.START, 0, C.CURSOR, false)
  BBD_DiffCursorGrid(true)
  local cur = funcLuaMenuCommand(C.FOCUS_INDEX, C.GRID)
  if type(cur) == "number" and cur >= 0 then
    funcLuaMenuCommand(C.CURSOR_LOCATOR, C.GRID, C.CURSOR, cur, BBD_DiffCursorCount(C.GRID))
  end
  BBD_DiffCursorLog("cursor back on the grid, tile " .. tostring(cur))
end

do
  local change = OnChangeFocus
  if change ~= nil then
    function OnChangeFocus(a1, a2, ...)
      local r = table.pack(change(a1, a2, ...))
      local C = BBD_DIFF_CURSOR
      if (a1 == C.START or a1 == C.LIST) and funcLuaMenuCommand(C.IS_OPEN, C.WINDOW) == true then
        local ok, err = pcall(BBD_DiffCursorOn, a1, type(a2) == "number" and a2 or 0)
        if not ok then
          BBD_DiffCursorLog("error", tostring(err))
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end

  local closeEnd = OnCloseEndLayer
  if closeEnd ~= nil then
    function OnCloseEndLayer(a1, a2, ...)
      local r = table.pack(closeEnd(a1, a2, ...))
      if a1 == BBD_DIFF_CURSOR.WINDOW then
        local ok, err = pcall(BBD_DiffCursorBack)
        if not ok then
          BBD_DiffCursorLog("error", tostring(err))
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
