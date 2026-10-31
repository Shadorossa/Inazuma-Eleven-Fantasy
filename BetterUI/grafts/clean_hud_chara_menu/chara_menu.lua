-- ===== EVT clean_hud chara_menu BEGIN ===== (graft research/grafts/clean_hud_chara_menu, docs/game/ui/chara-menu-one-column.md)
-- BetterUI: the team dock's per-player command window «PERSONAJE» (Mover, Configurar rol de la IA, Establecer como
-- capitán, Ver apariencia, Tabla de habilidades, Equipamiento, Mejorar, Configuración de pasivas, ...) as one column,
-- without «Mover», «Configurar rol de la IA» and «Cambiar configuración», in the owner's row order.
--   * MENU_DEF.OpenSubWindow: the retail call (callback CallbackCloseSelectCharaSetting, sub-window type 26 = the
--     two-column grid) opens as type 0 (win05_13_sub_list_locator + win05_04_sub_list_item12: one column, the same
--     button objbin as the grid's win05_04_sub_list_item12_two_line, so the same width) with the size code of its row
--     count (sub_window_group getMaxParamNum: rows -> size code). Every other argument is passed unchanged: texts, grey
--     flags, focus, title gtxt_character01 (also in win05_13.g4tx) and the «!» new-icon flags, all indexed like the
--     entries.
--   * Order (1.21.28, owner 2026-10-14): always «Tabla de habilidades» > «Equipamiento» > «Configuración de pasivas» >
--     «Establecer como capitán», then any other row in its retail order: an Order rule of the VR-Framework's list rows
--     (by retail setting type), applied where the retail script builds the list, so every consumer (open, grey loop,
--     «!» flags, focus popup, close callback, dispatch) indexes the same list. (Until 1.21.27 this graft re-sorted the
--     list «down the grid's columns» (odd entries, then even ones): the order then depended on the row count, so a
--     Diamond player, one row more, got another order than a normal one.)
--   * Up / down move through the list natively; the type-0 item has no left / right input rows, so nothing jumps.
--   * Position: the retail opener places the window at (500, -260) (top-centre of the window), or at y -190 when
--     the grid has 6 rows or more (11+ entries). Same rule on the column's rows: 6 rows or more -> moved to (500, -190)
--     after the retail opener (the window is 804 px tall at 9 rows, 70 px less per row: 8 rows end at 190 + 734 = 924,
--     above the button guides; the retail 9-row grid ends at 994).
-- More rows than the one-column window holds (9): the retail grid stays.
--   * Rows (1.21.26, owner 2026-10-14): «Mover» (setting type 0) and «Configurar rol de la IA» (type 7: the team's AI
--     roles are set from the team COMANDOS window, «Ajustes de la IA», graft clean_hud_team_ai) are not offered while
--     BetterUI is on, whatever the view; Hide rules of the VR-Framework's list rows (docs/framework/list-rows.md),
--     applied where the retail script builds the list, so the other mods' rows (Utilities' passives, Character
--     Reforged's skill table entry, No More Rarities) stay as they are.
--   * «Cambiar configuración» (setting type 8, BUILD: a Diamond player's build change, OpenSubWinChangeBuild) is hidden
--     too (1.21.28, owner 2026-10-14), by its retail setting type.
-- No engine call at load: only wrappers and rules (the patch runs before the engine registers the menu commands).
-- All state in BetterUI_CharaMenu.
do
  if VRFW_ListRows ~= nil then
    VRFW_ListRows.Hide(VRFW_ListRows.PLAYER_COMMANDS, {id = "clean_hud.hide_move",
      row = VRFW_ListRows.PLAYER_COMMAND.MOVE})
    VRFW_ListRows.Hide(VRFW_ListRows.PLAYER_COMMANDS, {id = "clean_hud.hide_ai_role",
      row = VRFW_ListRows.PLAYER_COMMAND.AI_ROLE})
    VRFW_ListRows.Hide(VRFW_ListRows.PLAYER_COMMANDS, {id = "clean_hud.hide_build_change",
      row = VRFW_ListRows.PLAYER_COMMAND.BUILD})
    if VRFW_ListRows.Order ~= nil then
      local command = VRFW_ListRows.PLAYER_COMMAND
      VRFW_ListRows.Order(VRFW_ListRows.PLAYER_COMMANDS, {id = "clean_hud.player_commands_order",
        rows = {command.SKILL_TABLE, command.EQUIPMENT, command.INHERITED_PASSIVES, command.CAPTAIN}})
    end
  end
  BetterUI_CharaMenu = BetterUI_CharaMenu or {}
  BetterUI_CharaMenu.CB = "CallbackCloseSelectCharaSetting" -- retail callback name of the per-player window
  BetterUI_CharaMenu.GRID_KIND = 26                         -- retail sub-window type: two-column grid
  BetterUI_CharaMenu.LIST_KIND = 0                          -- sub-window type: one-column list (win05_13, 9 slots)
  -- sub_window_group getMaxParamNum / SetupWindowParams: size code -> rows of the type-0 window (the code also sets
  -- how many buttons open: a larger code leaves empty buttons). The panel's height is the window's win_size animation
  -- of that code (BetterUI assets/lua/sub_window_group/120_window_size.lua plays it again once the window is open)
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
