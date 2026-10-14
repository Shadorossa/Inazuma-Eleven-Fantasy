-- menu_engine: LIST ROWS, the adapter of the team dock's player popup «PERSONAJE» (menu "team_dock.player_commands",
-- docs/framework/list-rows.md; the library is lua\_all\67_list_rows.lua). Definitions only (this file runs in every
-- menu VM, lua\_all): the team dock script calls VRFW_ListRows.AttachPlayerCommands() from its handler file
-- (lua\team_dock_formation_menu\130_list_rows.lua), which registers the handlers on the VRFW_Host host of the script.
--
-- Row ids = the retail setting types (VRFW_ListRows.PLAYER_COMMAND). The retail script builds the popup from
-- GetSelectSettingTypeOrderList() (one of its tables t6..t15) and every consumer indexes that same list: the window
-- (OpenSubWinSelectCharaSetting: text of type t = t5[t + 1], grey list t16 by type), the focus popup
-- (CallbackFocusSelectCharaSetting), the close callback (CallbackCloseSelectCharaSetting: n2 = picked index) and the
-- dispatch (OnDecideFocus: l2 = list[n2 + 1], `l2 == type` branches). So:
--   * Hide / Add / Order: an `after` handler of GetSelectSettingTypeOrderList returns the list with the rules applied (a copy:
--     the retail tables are shared); an added row's text goes into t5 once (an `@edit` handler on the host's locals).
--   * Handle / an added row picked: CallbackCloseSelectCharaSetting runs as retail for the pick (the window closes),
--     then once more with -1 (the retail cancel: n2 = -1), so OnDecideFocus takes its «nothing chosen» path and
--     restores the dock as after any setting; between the two, in OnDecideFocus' own coroutine, right after the popup
--     closed (WaitCloseSubWindow), the rule's run(context) runs (it may wait / yield like the retail branches).
-- context = {menu, row, handle = the player (GetFormationSelectCharaStHdl)}. No engine call at load.
if VRFW_ListRows ~= nil and VRFW_ListRows.AttachPlayerCommands == nil then
  local R = VRFW_ListRows
  local STEM = "team_dock_formation_menu"
  local MENU = R.PLAYER_COMMANDS
  local ID = "menu_engine.list_rows."

  local function player()
    if type(GetFormationSelectCharaStHdl) ~= "function" then
      return 0
    end
    local ok, handle = pcall(GetFormationSelectCharaStHdl)
    return ok and handle or 0
  end

  function R.AttachPlayerCommands()
    if VRFW_Host == nil or R.playerCommandsAttached then
      return
    end
    R.playerCommandsAttached = true

    -- the rows: hidden ones out, added ones in
    VRFW_Host.on(STEM, "GetSelectSettingTypeOrderList", {id = ID .. "rows", phase = "after", fn = function(results)
      local list = results[1]
      local rules = R.rules[MENU]
      if type(list) ~= "table" or rules == nil or (#rules.hide == 0 and #rules.add == 0 and #rules.order == 0) then
        return
      end
      results[1] = R.Apply(MENU, list, {menu = MENU, handle = player()})
    end})

    -- the text of each added row: t5[row + 1] (the retail table of the setting types' texts)
    VRFW_Host.on(STEM, "@edit", {id = ID .. "texts", fn = function(L)
      local rules = R.rules[MENU]
      if rules == nil or #rules.add == 0 then
        return
      end
      local texts = L.t5
      if type(texts) ~= "table" then
        R.Log(MENU, "the setting texts (t5) are not readable: added rows have no text")
        return
      end
      for _, spec in ipairs(rules.add) do
        if texts[spec.row + 1] == nil then
          texts[spec.row + 1] = spec.text
        end
      end
    end})

    -- a pick of a row some rule takes over: the retail close, then the retail cancel; the rule runs after the popup
    VRFW_Host.on(STEM, "CallbackCloseSelectCharaSetting", {id = ID .. "pick", phase = "around",
      fn = function(next_handler, position, ...)
        R.pendingPlayerCommand = nil
        if type(position) ~= "number" or position < 0 or type(GetSelectSettingTypeOrderList) ~= "function" then
          return next_handler(position, ...)
        end
        local list = GetSelectSettingTypeOrderList()
        local row = type(list) == "table" and list[position + 1] or nil
        if row == nil then
          return next_handler(position, ...)
        end
        local context = {menu = MENU, row = row, handle = player()}
        local taker = R.Taker(MENU, row, context)
        if taker == nil then
          return next_handler(position, ...)
        end
        local result = table.pack(next_handler(position, ...))
        next_handler(-1)
        R.pendingPlayerCommand = {spec = taker, context = context}
        R.Log(MENU, "row", row, "->", taker.id)
        return table.unpack(result, 1, result.n)
      end})

    -- right after the popup closed, in OnDecideFocus' coroutine: the rule's run (called directly: it may yield)
    VRFW_Host.on(STEM, "WaitCloseSubWindow", {id = ID .. "run", phase = "around", fn = function(next_handler, ...)
      local result = table.pack(next_handler(...))
      local pending = R.pendingPlayerCommand
      R.pendingPlayerCommand = nil
      if pending ~= nil then
        pending.spec.run(pending.context)
      end
      return table.unpack(result, 1, result.n)
    end})
  end
end
