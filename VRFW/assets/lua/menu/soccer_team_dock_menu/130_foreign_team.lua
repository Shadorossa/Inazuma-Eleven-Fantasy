-- menu_engine: the FOREIGN TEAM mode of the team dock (soccer_team_dock_menu), for VRFW_TeamEditor.Run with
-- spec.foreign (lua\_all\81_team_editor.lua, docs/framework/team-editor.md). Definitions only; no engine call at load.
--
-- The dock shows a team that is not one of the player's (a league team, a tournament team). Nothing that reads or
-- writes the player's own team docks is offered while it is up:
--   * the list keeps the rows the caller offers (spec.rows, VRFW_TeamEditor.ROW: the lineup, bonds, hyper commands;
--     they open on the dock's team, the bonds and hyper commands screens view only); the others (bank, abilities,
--     the 11v11 / 5v5 rows, other mods' rows) are left out for this open and come back when the dock closes;
--   * L1 / R1 (team switching), «Establecer como equipo activo», the tournament team, the player's name plate and
--     moving the dock are refused, and their entries leave the button guide;
--   * the team's identity is view only: only the list, the player cards and the formation box take a decide (the
--     coach card, tactics, kit, emblem (the team name bar), synergies, the team name and other mods' panel buttons are
--     refused: their pickers list the player's own cards and items);
--   * a card swap on the pitch only among the team's own players (VRFW_TeamEditor.GuardSwap);
--   * the dock number, the active team mark, the active dock background and the header's dock line are hidden;
--   * Utilities' team bank pages are off (UTIL_TEAM_BANKS = false, its switch for a mode's own squad screen) and the
--     dock counts as owned by another mode (EVT_DOCK_OWNERS: Pachangas' format rows and active teams line stay off);
--     the help line is the retail description of the focused row.
-- The mode is read once per open at OnInit (VRFW_TeamEditor.Foreign(): cross-menu parameters the editor writes
-- before it opens the dock and removes after) and ends when the dock closes.
if VRFW_Host ~= nil then
  local STEM = "soccer_team_dock_menu"
  local K = {
    LIST = 3367997069,               -- team01_02_list_item
    CARDS = 1973487846,              -- team00_01_chara_card_for_soccer (the team's players)
    FORMATION_BOX = 3286546665,      -- team00_12_formation_style
    ATTACH_FORMATION = 2141963976,   -- team01_03_attach_formation
    DOCK = 937147172,                -- soccer_team_dock_menu
    DOCK_NUMBER = 1308042914,        -- team01_05_team_dock_no
    ACTIVE_MARK = 8591637,           -- team01_06_team_dock_active_team_mark
    -- list row kinds kept (retail kinds: 0 the lineup screen; the rest open screens of the player's club)
    KEEP_ROWS = { [0] = true },      -- when the caller offers none
    -- OnFunction commands of the player's own docks: L1 / R1 team switch, set as active team, tournament team, the
    -- player's name plate
    BLOCKED_FUNCTIONS = { [2294853123] = true, [4219711668] = true, [3620553157] = true, [2237843578] = true },
    -- their button guide inputs: CMD_FUNCL1, CMD_FUNCR1, CMD_FUNC3, and CMD_FUNC6 (R3: the club's team bank pages)
    BLOCKED_INPUTS = { [3966226594] = true, [942075773] = true, [3421673595] = true, [3147328756] = true },
    MENU_INPUT = 1558704558,         -- (menu, on)
    CONTROL_FOCUS = VRFW_Cmd.SET_ENABLE_CTRL_FOCUS,      -- (layer, on)
    VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,             -- CMND_SET_LAYER_VISIBLE (layer, index, on)
    SOUND = VRFW_Cmd.SND_PLAY_SE, SE_NO = 2086672038,   -- sy0003
    LOG = VRFW_Cmd.EVT_LOG,                -- CMND_EVT_LOG
  }
  local DECIDE_LAYERS = { [K.LIST] = true, [K.CARDS] = true, [K.FORMATION_BOX] = true, [K.ATTACH_FORMATION] = true }
  local S = { on = false, rows = nil, banks = nil, keep = K.KEEP_ROWS }

  local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(i, ...)))
    end
    pcall(funcLuaCommand, K.LOG, "VRFW team editor", "dock: " .. table.concat(parts, " "))
  end

  local function locals()
    local host = VRFW_Host.hosts ~= nil and VRFW_Host.hosts[STEM] or nil
    return host ~= nil and host.L or nil
  end

  local function local_table(name)
    local L = locals()
    if L == nil then
      return nil
    end
    local ok, v = pcall(function()
      return L[name]
    end)
    return ok and type(v) == "table" and v or nil
  end

  -- a list's contents replaced in place (the retail functions hold the table itself)
  local function refill(list, values)
    for i = #list, 1, -1 do
      list[i] = nil
    end
    for i, v in ipairs(values) do
      list[i] = v
    end
  end

  -- the list rows of this open back as they were
  local function restore_rows()
    if S.rows == nil then
      return
    end
    local kinds = local_table("t")
    if kinds then
      refill(kinds, S.rows)
    end
    S.rows = nil
  end

  local function leave(why)
    if not S.on then
      return
    end
    S.on = false
    restore_rows()
    UTIL_TEAM_BANKS = S.banks
    S.banks = nil
    log("foreign team mode off (" .. why .. ")")
  end

  local function refuse()
    pcall(funcLuaCommand, K.SOUND, K.SE_NO)
  end

  local function hide_dock_marks()
    pcall(funcLuaMenuCommand, K.VISIBLE, K.DOCK_NUMBER, 0, false)
    pcall(funcLuaMenuCommand, K.VISIBLE, K.ACTIVE_MARK, 0, false)
  end

  -- a decide the mode allows: the list's kept rows, the team's player cards, the formation box
  local function allowed(layer, row)
    if not DECIDE_LAYERS[layer] then
      return false
    end
    if layer == K.LIST then
      local kinds = local_table("t")
      return kinds ~= nil and type(row) == "number" and S.keep[kinds[row + 1]] == true
    end
    return true
  end

  VRFW_Host.on(STEM, "OnInit", {
    id = "menu_engine.team_editor_foreign", phase = "before", priority = -1000,
    fn = function()
      leave("a new open")
      local foreign = type(VRFW_TeamEditor) == "table" and VRFW_TeamEditor.Foreign and VRFW_TeamEditor.Foreign()
      if foreign == nil then
        return
      end
      S.on = true
      S.keep = type(foreign.rows) == "table" and next(foreign.rows) ~= nil and foreign.rows or K.KEEP_ROWS
      S.banks = UTIL_TEAM_BANKS
      UTIL_TEAM_BANKS = false
      log(string.format("foreign team mode on (stadium 0x%08X)", foreign.stadium or 0))
    end,
  })

  -- the kept rows, after every other mod added or removed its own (lowest in the order: runs last)
  VRFW_Host.on(STEM, "OnSetupLayer", {
    id = "menu_engine.team_editor_foreign", phase = "before", priority = 1000,
    fn = function(layer, row)
      if not S.on or layer ~= K.LIST or row ~= 0 then
        return
      end
      local kinds = local_table("t")
      if kinds == nil then
        log("the list's row table was not found (no EVT_DEBUG?): rows kept")
        return
      end
      local all, keep = {}, {}
      for i, kind in ipairs(kinds) do
        all[i] = kind
        if S.keep[kind] then
          keep[#keep + 1] = kind
        end
      end
      if S.rows == nil then
        S.rows = all
      end
      refill(kinds, keep)
      log("list:", #keep, "of", #all, "row(s) kept")
    end,
  })

  VRFW_Host.on(STEM, "OnFunction", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, a1, ...)
      if S.on and K.BLOCKED_FUNCTIONS[a1] then
        refuse()
        return
      end
      return nxt(a1, ...)
    end,
  })

  VRFW_Host.on(STEM, "OnEnter", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, layer, row, ...)
      if S.on and not allowed(layer, row) then
        refuse()
        return 1
      end
      return nxt(layer, row, ...)
    end,
  })

  -- a decide that reaches the dock without OnEnter (a click): refused the same way, the dock's control back
  VRFW_Host.on(STEM, "OnDecideFocus", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, layer, row, ...)
      if S.on and not allowed(layer, row) then
        refuse()
        pcall(funcLuaMenuCommand, K.MENU_INPUT, K.DOCK, true)
        pcall(funcLuaMenuCommand, K.CONTROL_FOCUS, layer, true)
        return
      end
      return nxt(layer, row, ...)
    end,
  })

  -- a card swap on the dock's own pitch: only among the team's players (VRFW_TeamEditor.GuardSwap)
  VRFW_Host.on(STEM, "SwapChara", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, ...)
      if S.on and type(VRFW_TeamEditor) == "table" and VRFW_TeamEditor.GuardSwap then
        return VRFW_TeamEditor.GuardSwap(nxt, ...)
      end
      return nxt(...)
    end,
  })

  VRFW_Host.on(STEM, "StartMoveTeamDock", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, ...)
      if S.on then
        return
      end
      return nxt(...)
    end,
  })

  -- the guide without the inputs of the player's own docks (the entries table is put back right after)
  VRFW_Host.on(STEM, "SetupButtonGuideText", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = 1000,
    fn = function(nxt, ...)
      local entries = S.on and local_table("t4") or nil
      if entries == nil then
        return nxt(...)
      end
      local all, keep = {}, {}
      for i, e in ipairs(entries) do
        all[i] = e
        if not (type(e) == "table" and K.BLOCKED_INPUTS[e.inputCmd]) then
          keep[#keep + 1] = e
        end
      end
      refill(entries, keep)
      local r = table.pack(pcall(nxt, ...))
      refill(entries, all)
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  -- the header's dock line (dock number of the player's docks) stays hidden
  VRFW_Host.on(STEM, "SetVisibleHeaderTeamDoc", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, visible, ...)
      if S.on then
        return nxt(false, ...)
      end
      return nxt(visible, ...)
    end,
  })

  -- the active dock's background (the shown set is the player's active dock while the copy is in it) stays off
  VRFW_Host.on(STEM, "SetActiveDockBackground", {
    id = "menu_engine.team_editor_foreign", phase = "around", priority = -1000,
    fn = function(nxt, on, ...)
      if S.on then
        return nxt(false, ...)
      end
      return nxt(on, ...)
    end,
  })

  -- the dock's other modes (EVT_DOCK_OWNERS: a function per mode, true while that mode owns the dock) stay off
  EVT_DOCK_OWNERS = type(EVT_DOCK_OWNERS) == "table" and EVT_DOCK_OWNERS or {}
  EVT_DOCK_OWNERS.vrfw_team_editor = function()
    return S.on
  end

  VRFW_Host.on(STEM, "UpdateViewTeamDockNo", {
    id = "menu_engine.team_editor_foreign", phase = "after",
    fn = function()
      if S.on then
        hide_dock_marks()
      end
    end,
  })

  VRFW_Host.on(STEM, "OnOpenLayer", {
    id = "menu_engine.team_editor_foreign", phase = "after",
    fn = function(_, layer)
      if S.on and (layer == K.DOCK_NUMBER or layer == K.ACTIVE_MARK) then
        hide_dock_marks()
      end
    end,
  })

  VRFW_Host.on(STEM, "FuncOnBack", {
    id = "menu_engine.team_editor_foreign", phase = "after",
    fn = function()
      leave("dock closed")
    end,
  })

  VRFW_Host.on(STEM, "FinalizeMenu", {
    id = "menu_engine.team_editor_foreign", phase = "before", create = true,
    fn = function()
      leave("dock finalized")
    end,
  })
end
