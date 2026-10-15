-- menu_engine: LIST ROWS, VRFW.ListRows. One shared
-- extension point for the rows of the game's own list menus: mods HIDE retail rows, ADD rows of their own, TAKE OVER
-- what a retail row does and ORDER the rows, each by registering a rule; no mod redefines the menu's functions or its row list any more,
-- so the rules of every mod apply together whatever the load order.
--
-- Rows are identified by their RETAIL ROW ID, never by their label:
--   * "team_dock.player_commands" (the team dock's player popup «PERSONAJE», team_dock_formation_menu): the retail
--     setting type of the row (GetSelectSettingTypeOrderList; VRFW_ListRows.PLAYER_COMMAND below). Adapter: the
--     framework's handlers on the VRFW_Host host of that script (lua\team_dock_formation_menu\130_list_rows.lua,
--     VRFW_ListRows.AttachPlayerCommands): the list is filtered where the retail script builds it, so every consumer
--     (window, grey list, «!» flags, focus popup, dispatch) indexes the same filtered list.
--   * "formation.team_commands" (the formation's team «COMANDOS» window, retail opener
--     OpenSelectTeamMemberControlSubWindowCore of the include soccer_formation_menu_inc): the retail row index 0..5
--     (VRFW_ListRows.TEAM_COMMAND below). Adapter: the sub-window one (MENU_DEF.OpenSubWindow, wrapped here in every VM
--     that has MENU_DEF): the rows sent to the window are filtered / extended, the window's callback is the framework's,
--     which turns the picked position back into the retail row id.
-- Other sub-window lists can be declared the same way (VRFW_ListRows.DeclareSubWindow).
--
-- API (register while the chunks load, from the mod's own patch file of the script; the rules are asked at run time):
--   VRFW_ListRows.Hide(menu, {id = "<mod>.<name>", row = <retail row id>, when = function(context) return bool end})
--   VRFW_ListRows.Add(menu, {id = "<mod>.<name>", row = <new row id>, text = <text id (crc32 of the text key)>,
--                            after = <row id> | nil (end of the list), when = fn | nil, enabled = fn | nil,
--                            run = function(context) ... end})
--   VRFW_ListRows.Handle(menu, {id = "<mod>.<name>", row = <retail row id>, when = fn | nil, run = function(context) end})
--   VRFW_ListRows.Order(menu, {id = "<mod>.<name>", rows = {<row id>, <row id>, ...}, when = fn | nil})
--     the rows named in `rows` go first, in that order (absent / hidden ones skipped); every other row follows
--     in the order it had (retail order, added rows after their anchors). ONE order applies per menu: the order rule
--     registered LAST (mod load order) whose `when` holds wins; the others are ignored (logged once).
-- `when` (optional): the rule applies only while it returns true (asked each time the menu is built / picked).
-- `enabled` (Add, optional): false = the row is shown greyed. `context`: {menu, row, handle (the player of the player
-- popup), retail = function(row_id, ...) (runs a retail row's own action; sub-window menus)}.
-- A second rule with the same id replaces the first. Several Hide rules may name the same row. Handle rules: the first
-- registered whose `when` holds runs (logged when two claim a row). Order rules: the last registered whose `when` holds.
-- Definitions only (this file runs in every menu VM, lua\_all); no engine call at load.
-- Registering before this file ran (the `_all` of a lua_early mod runs before the framework's `_all`, so
-- VRFW_ListRows is still nil there): queue a function that gets the library and registers its rules,
--   VRFW_LIST_ROWS_Q = VRFW_LIST_ROWS_Q or {}; table.insert(VRFW_LIST_ROWS_Q, function(Rows) Rows.Hide(...) end)
-- drained at the end of this file (an error is logged, the other queued functions still run).
if VRFW_ListRows == nil then
  local R = {
    LOG = 3661580131,                 -- CMND_EVT_LOG
    menus = {},                       -- menu name -> declaration (adapter data)
    rules = {},                       -- menu name -> {hide = {}, add = {}, handle = {}, order = {}} (arrays of specs)
    SUBWINDOW_CALLBACK_PREFIX = "VRFW_ListRows_Pick_",
    SUBWINDOW_FOCUS_PREFIX = "VRFW_ListRows_Focus_",
    -- retail setting types of the team dock player popup (t5 of team_dock_formation_menu: the text of type t is
    -- t5[t + 1]; the dispatch is OnDecideFocus' `l2 == t` branches)
    PLAYER_COMMAND = {
      MOVE = 0,                       -- «Mover» (swap the player on the field)
      EQUIPMENT = 1,                  -- «Equipamiento» (equip_menu)
      RARITY_UP = 2,                  -- «Mejorar» (soccer_spirit_menu: rarity up)
      CAPTAIN = 3,                    -- «Establecer como capitán»
      VIEW_MODEL = 4,                 -- the 3D model view
      SKILL_TABLE = 5,                -- «Tabla de habilidades» (ability_learning_board_menu)
      SHIRT_NUMBER = 6,               -- «Cambiar número de dorsal» (uniform_no_window)
      AI_ROLE = 7,                    -- «Configurar rol de la IA» (OpenSubWinAIRoleSetting)
      BUILD = 8,                      -- build change (OpenSubWinChangeBuild)
      INHERITED_PASSIVES = 9,         -- «Pasivas heredadas» (soccer_passsive_inherit_menu)
      CLEAR_INHERITED_PASSIVE = 10,   -- «Eliminar pasiva heredada» (soccer_passsive_inherit_clear_menu)
      AVATAR_RARITY = 11,             -- avatar rarity change (OpenSubWinChangeAvatarRarity)
    },
    -- retail rows of the formation's team COMANDOS window (CallbackCloseCondTeamCommandSubWin cases)
    TEAM_COMMAND = {
      AUTO_EQUIP = 0,                 -- «Autoequipar equipo»
      REMOVE_EQUIPMENT = 1,           -- «Eliminar equipamiento»
      EQUIP_BEANS = 2,                -- «Equipar judías de entrenamiento»
      REMOVE_BEANS = 3,               -- «Quitar judías de entrenamiento»
      GOAL_CELEBRATION = 4,           -- «Ajustes de celebración de gol» (soccer_performance_change_menu)
      AUTO_EQUIP_BEANS = 5,           -- «[x] Autoequipar judías» (a checkbox: the window stays open)
    },
    PLAYER_COMMANDS = "team_dock.player_commands",
    TEAM_COMMANDS = "formation.team_commands",
  }
  VRFW_ListRows = R

  function R.Log(...)
    pcall(funcLuaCommand, R.LOG, "vrfw.ListRows", ...)
  end

  local function rules_of(menu)
    local r = R.rules[menu]
    if r == nil then
      r = {hide = {}, add = {}, handle = {}, order = {}}
      R.rules[menu] = r
    end
    return r
  end

  local function put(list, spec)
    for i, x in ipairs(list) do
      if x.id == spec.id then
        list[i] = spec
        return spec
      end
    end
    list[#list + 1] = spec
    return spec
  end

  local function check(menu, spec, what, needs_run)
    if what == "Order" then
      if type(menu) ~= "string" or type(spec) ~= "table" or type(spec.id) ~= "string" or type(spec.rows) ~= "table" then
        error("VRFW_ListRows.Order(menu, {id = \"<mod>.<name>\", rows = {<row id>, ...}}) expected", 3)
      end
      return
    end
    if type(menu) ~= "string" or type(spec) ~= "table" or type(spec.id) ~= "string" or type(spec.row) ~= "number" then
      error("VRFW_ListRows." .. what .. "(menu, {id = \"<mod>.<name>\", row = <number>, ...}) expected", 3)
    end
    if needs_run and type(spec.run) ~= "function" then
      error("VRFW_ListRows." .. what .. ": " .. spec.id .. ": run = function(context) expected", 3)
    end
  end

  function R.Hide(menu, spec)
    check(menu, spec, "Hide", false)
    return put(rules_of(menu).hide, spec)
  end

  function R.Add(menu, spec)
    check(menu, spec, "Add", true)
    if type(spec.text) ~= "number" then
      error("VRFW_ListRows.Add: " .. spec.id .. ": text = <text id> expected", 2)
    end
    return put(rules_of(menu).add, spec)
  end

  function R.Handle(menu, spec)
    check(menu, spec, "Handle", true)
    return put(rules_of(menu).handle, spec)
  end

  function R.Order(menu, spec)
    check(menu, spec, "Order", false)
    return put(rules_of(menu).order, spec)
  end

  -- a rule applies now (its `when`; an error counts as "no" and is logged once)
  function R.Applies(spec, context)
    if spec.when == nil then
      return true
    end
    local ok, result = pcall(spec.when, context)
    if not ok then
      if not spec.logged then
        spec.logged = true
        R.Log(spec.id, "when failed", tostring(result))
      end
      return false
    end
    return result == true
  end

  -- the added rule of a row id (nil = a retail row)
  function R.AddedRow(menu, row)
    for _, spec in ipairs(rules_of(menu).add) do
      if spec.row == row then
        return spec
      end
    end
    return nil
  end

  -- the Handle rule (or added row) that takes over `row` now, or nil
  function R.Taker(menu, row, context)
    local added = R.AddedRow(menu, row)
    if added ~= nil then
      return added
    end
    local taker
    for _, spec in ipairs(rules_of(menu).handle) do
      if spec.row == row and R.Applies(spec, context) then
        if taker == nil then
          taker = spec
        elseif not spec.clash_logged then
          spec.clash_logged = true
          R.Log(menu, "row", row, "claimed by", taker.id, "and", spec.id, "(the first registered runs)")
        end
      end
    end
    return taker
  end

  -- the order rule of `menu` that applies now: the last registered whose `when` holds (nil = none)
  function R.OrderRule(menu, context)
    local rules = rules_of(menu)
    local winner
    for i = #rules.order, 1, -1 do
      local spec = rules.order[i]
      if winner == nil then
        if R.Applies(spec, context) then
          winner = spec
        end
      elseif not spec.overridden_logged and R.Applies(spec, context) then
        spec.overridden_logged = true
        R.Log(menu, "order", spec.id, "ignored:", winner.id, "registered later wins")
      end
    end
    return winner
  end

  -- `rows` sorted by an order rule: its rows first (in its order), then the others as they were (stable)
  function R.Sort(rows, order_rule)
    local rank = {}
    for i, row in ipairs(order_rule.rows) do
      if rank[row] == nil then
        rank[row] = i
      end
    end
    local first, rest = {}, {}
    for _, row in ipairs(rows) do
      if rank[row] ~= nil then
        first[#first + 1] = row
      else
        rest[#rest + 1] = row
      end
    end
    table.sort(first, function(a, b) return rank[a] < rank[b] end)
    for _, row in ipairs(rest) do
      first[#first + 1] = row
    end
    return first
  end

  -- The rows of `menu` in order from its retail row ids: hidden rows dropped, added rows placed after their anchor
  -- (or at the end), then the menu's order rule (if any); -> new array (the retail table is never edited)
  function R.Apply(menu, retail_rows, context)
    local rules = rules_of(menu)
    local hidden = {}
    for _, spec in ipairs(rules.hide) do
      if hidden[spec.row] == nil and R.Applies(spec, context) then
        hidden[spec.row] = true
      end
    end
    local out = {}
    for _, row in ipairs(retail_rows) do
      if not hidden[row] then
        out[#out + 1] = row
      end
    end
    for _, spec in ipairs(rules.add) do
      if not hidden[spec.row] and R.Applies(spec, context) then
        local at = #out + 1
        if spec.after ~= nil then
          for i, row in ipairs(out) do
            if row == spec.after then
              at = i + 1
              break
            end
          end
        end
        table.insert(out, at, spec.row)
      end
    end
    local order_rule = R.OrderRule(menu, context)
    if order_rule ~= nil then
      out = R.Sort(out, order_rule)
    end
    return out
  end

  -- an added row is selectable now
  function R.Enabled(spec, context)
    if spec.enabled == nil then
      return true
    end
    local ok, result = pcall(spec.enabled, context)
    return ok and result ~= false
  end

  -- ---- sub-window lists (MENU_DEF.OpenSubWindow) -------------------------------------------------------------------
  -- Declare a retail list opened with MENU_DEF.OpenSubWindow(callback, focus_callback, count, texts, size, title, grey,
  -- focus, b1, b2, kind, x0, icons, n14, t15, t16, n17, checks, ...) whose row id is its retail row index:
  --   {callback = "<retail callback name>", kind = <sub-window type>, rows = <retail row count>,
  --    rows_shown = <rows the window shows before it scrolls>, size_by_rows = {[rows] = size code},
  --    list_locator = <layer crc of the list: the retail opener sets the focus there after opening>,
  --    opener = "<retail opener global>" (wrapped to fix what it addresses by position after the window opened),
  --    checkbox_rows = {[row id] = function() return checked end}}
  function R.DeclareSubWindow(menu, declaration)
    declaration.name = menu
    declaration.sub_window = true
    R.menus[menu] = declaration
    R.byCallback = nil
    R.InstallSubWindowCallbacks(declaration)
    R.WrapSubWindow()
    R.WrapOpener(declaration)
    return declaration
  end

  -- argument positions of MENU_DEF.OpenSubWindow (after the two callbacks) that hold one value per row
  R.PER_ROW_ARGUMENTS = {2, 5, 11, 13, 14, 16}   -- texts, grey, icons, t15, t16, checks (positions in `...`)
  R.COUNT_ARGUMENT, R.SIZE_ARGUMENT, R.FOCUS_ARGUMENT, R.KIND_ARGUMENT = 1, 3, 6, 9

  local function declaration_of_callback(callback, kind)
    if R.byCallback == nil then
      R.byCallback = {}
      for _, d in pairs(R.menus) do
        if d.sub_window and d.callback ~= nil then
          R.byCallback[d.callback] = d
        end
      end
    end
    local d = R.byCallback[callback]
    if d ~= nil and (d.kind == nil or d.kind == kind) then
      return d
    end
    return nil
  end

  local function has_rules(menu)
    local r = R.rules[menu]
    return r ~= nil and (#r.hide > 0 or #r.add > 0 or #r.handle > 0 or #r.order > 0)
  end

  -- the window of a declared menu: rows filtered / added, per-row tables rebuilt, our callbacks. -> the arguments
  local function rebuild_sub_window(d, callback, focus_callback, arguments)
    local count = arguments[R.COUNT_ARGUMENT]
    if type(count) ~= "number" or count < 1 then
      return nil
    end
    local context = {menu = d.name}
    local retail_rows = {}
    for i = 0, count - 1 do
      retail_rows[#retail_rows + 1] = i
    end
    local rows = R.Apply(d.name, retail_rows, context)
    local position_of = {}
    for position, row in ipairs(rows) do
      position_of[row] = position - 1
    end
    local out = {}
    for k = 1, arguments.n do
      out[k] = arguments[k]
    end
    out.n = arguments.n
    for _, k in ipairs(R.PER_ROW_ARGUMENTS) do
      local source = arguments[k]
      if type(source) == "table" and #source > 0 then
        local rebuilt = {}
        for position, row in ipairs(rows) do
          local added = R.AddedRow(d.name, row)
          if added == nil then
            rebuilt[position] = source[row + 1]
          elseif k == 2 then
            rebuilt[position] = added.text
          elseif k == 5 then
            local enabled = R.Enabled(added, {menu = d.name, row = row})
            -- a window whose retail rows are all grey (an empty team) greys the added rows too
            local any_enabled = false
            for i = 1, #source do
              any_enabled = any_enabled or source[i] ~= 0
            end
            if not any_enabled then
              enabled = false
            end
            rebuilt[position] = enabled and 1 or 0
          else
            rebuilt[position] = 0
          end
        end
        out[k] = rebuilt
      end
    end
    out[R.COUNT_ARGUMENT] = #rows
    local shown = math.min(#rows, d.rows_shown or #rows)
    if #rows ~= count and type(d.size_by_rows) == "table" and d.size_by_rows[shown] ~= nil then
      out[R.SIZE_ARGUMENT] = d.size_by_rows[shown]
    end
    -- focus: the retail row id it names, or the added row picked last when the retail focus is the row that added row
    -- forwarded to
    local retail_focus = arguments[R.FOCUS_ARGUMENT]
    local focus_row = retail_focus
    if d.last_added ~= nil and d.forwarded_to == retail_focus and position_of[d.last_added] ~= nil then
      focus_row = d.last_added
    end
    out[R.FOCUS_ARGUMENT] = position_of[focus_row] or 0
    d.open = {rows = rows, position_of = position_of, callback = callback, focus_callback = focus_callback,
      focus_row = focus_row}
    return out
  end

  -- the retail code addressed checkbox rows by their retail position (the opener after the window opened, the
  -- callback after a toggle): each checkbox row's state again at the position it is shown at, and no check mark left
  -- on another row shown at that retail position
  function R.FixCheckboxes(d)
    local open = d.open
    if open == nil or d.checkbox_rows == nil then
      return
    end
    for row, checked in pairs(d.checkbox_rows) do
      local shown_there = open.rows[row + 1]
      if shown_there ~= nil and shown_there ~= row then
        pcall(funcLuaCommand, 628044124 --[[checkbox state]], row, false)
      end
    end
    for row, checked in pairs(d.checkbox_rows) do
      local position = open.position_of[row]
      if position ~= nil and position ~= row then
        local ok, value = pcall(checked)
        pcall(funcLuaCommand, 628044124 --[[checkbox state]], position, ok and value == true)
      end
    end
  end

  -- after the declared opener ran: the list focus (set by retail position) and the checkbox states
  function R.FixSubWindowPositions(d)
    local open = d.open
    if open == nil then
      return
    end
    if d.list_locator ~= nil and open.position_of[open.focus_row] ~= nil then
      pcall(funcLuaCommand, 3647847018 --[[list focus]], open.position_of[open.focus_row], d.list_locator)
    end
    R.FixCheckboxes(d)
  end

  -- the window's pick: the position -> the retail row id; an added row / a taken-over row runs its rule
  function R.PickSubWindow(menu, position, ...)
    local d = R.menus[menu]
    local open = d and d.open
    if open == nil then
      return nil
    end
    local retail_callback = _ENV[open.callback]
    local function retail(row, ...)
      d.forwarded_to = row
      if type(retail_callback) == "function" then
        return retail_callback(row, ...)
      end
    end
    if type(position) ~= "number" or position < 0 then
      return retail(position, ...)
    end
    local row = open.rows[position + 1]
    if row == nil then
      return retail(-1)
    end
    local context = {menu = menu, row = row, retail = retail}
    local taker = R.Taker(menu, row, context)
    local result
    if taker ~= nil then
      d.last_added = R.AddedRow(menu, row) ~= nil and row or nil
      d.forwarded_to = nil
      R.Log(menu, "row", row, "->", taker.id)
      result = table.pack(taker.run(context))
    else
      d.last_added, d.forwarded_to = nil, nil
      result = table.pack(retail(row, ...))
    end
    -- a checkbox row toggled in place (the window stays open): its state again at its position
    if d.checkbox_rows ~= nil and d.checkbox_rows[row] ~= nil and open.position_of[row] ~= row then
      R.FixCheckboxes(d)
    end
    return table.unpack(result, 1, result.n)
  end

  function R.FocusSubWindow(menu, position, ...)
    local d = R.menus[menu]
    local open = d and d.open
    local callback = open and _ENV[open.focus_callback]
    if type(callback) ~= "function" then
      return nil
    end
    local row = position
    if type(position) == "number" and position >= 0 then
      row = open.rows[position + 1] or -1
    end
    if R.AddedRow(menu, row) ~= nil then
      return nil
    end
    return callback(row, ...)
  end

  -- MENU_DEF.OpenSubWindow of this VM: innermost wrapper (it runs when the chunk's includes are loaded, before every
  -- mod's patch), so another mod's own wrapper still sees the retail call it expects
  function R.WrapSubWindow()
    if MENU_DEF == nil or type(MENU_DEF.OpenSubWindow) ~= "function" or R.retailOpenSubWindow ~= nil then
      return
    end
    R.retailOpenSubWindow = MENU_DEF.OpenSubWindow
    MENU_DEF.OpenSubWindow = function(callback, focus_callback, ...)
      local d = declaration_of_callback(callback, (select(R.KIND_ARGUMENT, ...)))
      if d ~= nil and has_rules(d.name) then
        local out = rebuild_sub_window(d, callback, focus_callback, table.pack(...))
        if out ~= nil then
          local our_focus = focus_callback
          if type(focus_callback) == "string" and focus_callback ~= "" then
            our_focus = R.SUBWINDOW_FOCUS_PREFIX .. d.global
          end
          return R.retailOpenSubWindow(R.SUBWINDOW_CALLBACK_PREFIX .. d.global, our_focus,
            table.unpack(out, 1, out.n))
        end
      elseif d ~= nil then
        d.open = nil
      end
      return R.retailOpenSubWindow(callback, focus_callback, ...)
    end
  end

  -- the declared opener: after it ran (the window is open and the retail code addressed it by position), fix that
  function R.WrapOpener(d)
    local name = d.opener
    if type(name) ~= "string" or type(_ENV[name]) ~= "function" or d.wrappedOpener ~= nil then
      return
    end
    d.wrappedOpener = _ENV[name]
    _ENV[name] = function(...)
      d.open = nil
      local result = table.pack(d.wrappedOpener(...))
      if d.open ~= nil and d.open.callback ~= nil and has_rules(d.name) then
        R.FixSubWindowPositions(d)
      end
      return table.unpack(result, 1, result.n)
    end
  end

  -- global callback names of a declared sub-window menu (the window calls its callbacks by name)
  function R.InstallSubWindowCallbacks(d)
    d.global = d.global or (d.name:gsub("[^%w]", "_"))
    _ENV[R.SUBWINDOW_CALLBACK_PREFIX .. d.global] = function(...)
      return R.PickSubWindow(d.name, ...)
    end
    _ENV[R.SUBWINDOW_FOCUS_PREFIX .. d.global] = function(...)
      return R.FocusSubWindow(d.name, ...)
    end
  end

  -- the formation's team COMANDOS window (soccer_formation_menu_inc OpenSelectTeamMemberControlSubWindowCore)
  R.DeclareSubWindow(R.TEAM_COMMANDS, {
    callback = "CallbackCloseCondTeamCommandSubWin",
    kind = 22,                        -- win05_11_sub_list_locator_15 (the list window)
    rows = 6,
    rows_shown = 6,                   -- the win05_11 list shows 6 rows (mViewNum 6 of its objbin), then scrolls
    -- sub_window_group getMaxParamNum: rows -> size code (the retail 6-row window is code 3)
    size_by_rows = {[1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 6, [6] = 3},
    list_locator = 118161610,         -- win05_11_sub_list_locator_15
    opener = "OpenSelectTeamMemberControlSubWindowCore",
    checkbox_rows = {
      [5] = function() return funcLuaCommand(545705220) == true end,   -- «[x] Autoequipar judías» (retail flag48)
    },
  })
end

-- rules queued by patches that ran before this file (VRFW_LIST_ROWS_Q, see the header)
do
  local queue = rawget(_ENV, "VRFW_LIST_ROWS_Q")
  if type(queue) == "table" and VRFW_ListRows ~= nil then
    rawset(_ENV, "VRFW_LIST_ROWS_Q", nil)
    for _, register in ipairs(queue) do
      if type(register) == "function" then
        local ok, problem = pcall(register, VRFW_ListRows)
        if not ok then
          VRFW_ListRows.Log("queued registration failed", tostring(problem))
        end
      end
    end
  end
end
