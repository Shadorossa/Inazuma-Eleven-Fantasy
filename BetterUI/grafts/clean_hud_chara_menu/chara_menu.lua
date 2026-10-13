-- ===== EVT clean_hud chara_menu BEGIN ===== (graft research/grafts/clean_hud_chara_menu, docs/game/ui/chara-menu-one-column.md)
-- BetterUI: the team dock's per-player command window «PERSONAJE» (Mover, Configurar rol de la IA, Establecer como
-- capitán, Ver apariencia, Tabla de habilidades, Equipamiento, Mejorar, Configuración de pasivas, ...) as one column.
--   * MENU_DEF.OpenSubWindow: the retail call (callback CallbackCloseSelectCharaSetting, sub-window type 26 = the
--     two-column grid) opens as type 0 (win05_13_sub_list_locator + win05_04_sub_list_item12: one column, the same
--     button objbin as the grid's win05_04_sub_list_item12_two_line, so the same width) with the size code of its row
--     count (sub_window_group getMaxParamNum: rows -> size code). Every other argument is passed unchanged: texts, grey
--     flags, focus, title gtxt_character01 (also in win05_13.g4tx) and the «!» new-icon flags, all indexed like the
--     entries.
--   * GetSelectSettingTypeOrderList: the grid filled its rows left to right (entry 1 | 2, 3 | 4, ...); the list
--     returns the entries in the order the grid showed them down its columns: left column (1, 3, 5, ...), then right
--     (2, 4, 6, ...). Every consumer (open, grey loop, «!» flags, focus popup, close callback, dispatch) indexes this
--     same list and tests setting types, never positions, so each entry keeps its own screen and its own badge.
--   * Up / down move through the list natively; the type-0 item has no left / right input rows, so nothing jumps.
--   * Position: the retail opener places the window at (500, -260) (top-centre of the window), or at y -190 when
--     the grid has 6 rows or more (11+ entries). Same rule on the column's rows: 6 rows or more -> moved to (500, -190)
--     after the retail opener (the window is 804 px tall at 9 rows, 70 px less per row: 8 rows end at 190 + 734 = 924,
--     above the button guides; the retail 9-row grid ends at 994).
-- More rows than the one-column window holds (9): the retail grid and order stay. No engine call at load: only
-- wrappers (the patch runs before the engine registers the menu commands). All state in BetterUI_CharaMenu.
do
  BetterUI_CharaMenu = BetterUI_CharaMenu or {}
  BetterUI_CharaMenu.CB = "CallbackCloseSelectCharaSetting" -- retail callback name of the per-player window
  BetterUI_CharaMenu.GRID_KIND = 26                         -- retail sub-window type: two-column grid
  BetterUI_CharaMenu.LIST_KIND = 0                          -- sub-window type: one-column list (win05_13, 9 slots)
  -- sub_window_group getMaxParamNum / SetupWindowParams: size code -> rows of the type-0 window
  BetterUI_CharaMenu.SIZE_BY_ROWS = {[1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 6, [6] = 3, [7] = 7, [8] = 8, [9] = 4}
  BetterUI_CharaMenu.MAX_ROWS = 9
  BetterUI_CharaMenu.CMND_SUB_WINDOW_POS = 63483614         -- funcLuaCommand(id, x, y): the retail opener's last call
  BetterUI_CharaMenu.RETAIL_X = 500                         -- the retail opener's x (every entry count)
  BetterUI_CharaMenu.TALL_Y = -190                          -- the retail opener's y for its tall grids
  BetterUI_CharaMenu.TALL_ROWS = 6                          -- the retail opener's rule: 6 rows or more -> TALL_Y
  BetterUI_CharaMenu.rows = nil

  function BetterUI_CharaMenu.Log(...)
    if PRINT ~= nil then
      pcall(PRINT, "EVT_UI chara_menu", ...)
    end
  end

  -- the one-column window takes this list
  function BetterUI_CharaMenu.Fits(n)
    return type(n) == "number" and n >= 1 and n <= BetterUI_CharaMenu.MAX_ROWS
  end

  -- left grid column (odd entries), then the right one (even entries)
  function BetterUI_CharaMenu.ColumnOrder(src)
    local out = {}
    for i = 1, #src, 2 do
      out[#out + 1] = src[i]
    end
    for i = 2, #src, 2 do
      out[#out + 1] = src[i]
    end
    return out
  end

  if type(GetSelectSettingTypeOrderList) == "function" and BetterUI_CharaMenu.origList == nil then
    BetterUI_CharaMenu.origList = GetSelectSettingTypeOrderList
    GetSelectSettingTypeOrderList = function(...)
      local src = BetterUI_CharaMenu.origList(...)
      if type(src) ~= "table" or not BetterUI_CharaMenu.Fits(#src) then
        return src
      end
      return BetterUI_CharaMenu.ColumnOrder(src)
    end
  end

  if MENU_DEF ~= nil and type(MENU_DEF.OpenSubWindow) == "function" and BetterUI_CharaMenu.origOpen == nil then
    BetterUI_CharaMenu.origOpen = MENU_DEF.OpenSubWindow
    MENU_DEF.OpenSubWindow = function(cb, fcb, count, texts, size, title, grey, focus, b1, b2, kind, ...)
      if cb == BetterUI_CharaMenu.CB and kind == BetterUI_CharaMenu.GRID_KIND and BetterUI_CharaMenu.Fits(count) then
        BetterUI_CharaMenu.rows = count
        BetterUI_CharaMenu.Log("one column, rows", count, "focus", focus)
        return BetterUI_CharaMenu.origOpen(cb, fcb, count, texts, BetterUI_CharaMenu.SIZE_BY_ROWS[count], title, grey,
          focus, b1, b2, BetterUI_CharaMenu.LIST_KIND, ...)
      end
      return BetterUI_CharaMenu.origOpen(cb, fcb, count, texts, size, title, grey, focus, b1, b2, kind, ...)
    end
  end

  -- the retail opener positions the window last (after waiting for it to open) by the grid's rows; a column of 6 rows
  -- or more goes to the retail tall-grid y. Runs in the opener's coroutine: no pcall around the original (it yields).
  if type(OpenSubWinSelectCharaSetting) == "function" and BetterUI_CharaMenu.origOpener == nil then
    BetterUI_CharaMenu.origOpener = OpenSubWinSelectCharaSetting
    OpenSubWinSelectCharaSetting = function(...)
      BetterUI_CharaMenu.rows = nil
      BetterUI_CharaMenu.origOpener(...)
      local rows = BetterUI_CharaMenu.rows
      BetterUI_CharaMenu.rows = nil
      if rows ~= nil and rows >= BetterUI_CharaMenu.TALL_ROWS then
        funcLuaCommand(BetterUI_CharaMenu.CMND_SUB_WINDOW_POS, BetterUI_CharaMenu.RETAIL_X, BetterUI_CharaMenu.TALL_Y)
      end
    end
  end
end
-- ===== EVT clean_hud chara_menu END =====
