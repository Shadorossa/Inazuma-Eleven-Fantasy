-- menu_engine: INLINE CARD ACTIONS of the team dock's lineup screen (team_dock_formation_menu), for
-- VRFW_TeamEditor.Run with spec.inline_card_actions (the dock's part: soccer_team_dock_menu\137_inline_card_actions.lua,
-- docs/framework/team-editor.md). Definitions only; no engine call at load.
--
-- The dock opened this screen for one player card with a card action (VRFW_TeamEditor.CardAction(), read at OnInit):
--   * POPUP: the screen is hidden (the retail full-screen hide of a menu); once the card it was opened on is up, the
--     retail decide on that card runs (its popup «PERSONAJE» and the row picked: every mod's rows, hidden rows and
--     popup layout apply as on the visible screen); then the screen closes (the retail Back) and the dock is back.
--   * PAGE: the screen is hidden, its player plate (the player page) stays; Back closes it. A on a card there runs the
--     same popup.
--   * «Mover» (the retail kind 0 row, which starts the move on this screen's pitch) is handed to the dock instead
--     (VRFW_TeamEditor.RequestCardMove), and the screen closes.
--   * The rows that draw on this screen itself (the 3D model view, the shirt number) show the screen and the plate
--     while they run.
if VRFW_Host ~= nil then
  local STEM = "team_dock_formation_menu"
  local K = {
    CARDS = 1973487846,              -- team00_01_chara_card_for_soccer
    COACH_CARD = 1658289671,         -- team00_01_chara_card_for_leader
    SCREEN = 935586083,              -- team_dock_formation_menu (its layers)
    INPUT_OWNER = 2049316981,        -- soccer_formation_menu (the lineup's menu object)
    PLATE = 1427722143,              -- personal_plate_menu (the player plate the screen opens)
    BACK = 318865860,                -- OnFunction: Back (the retail close of the screen)
    MENU_HIDE = 1670867360,          -- (1, menu): the whole menu not drawn (the retail full-screen movie hide)
    MENU_SHOW = 3257327861,          -- (menu): drawn again
    MENU_EXISTS = VRFW_Cmd.IS_EXIST_MENU_OBJECT,   -- (menu) -> exists
    HAS_FOCUS = 102308320,           -- (layer, index) -> that instance has the focus
    FOCUS_IDX = 2603265800,          -- (layer) -> focused index
    CLOSE_TRIES = 12, CLOSE_EVERY = 10,   -- the retail Back is ignored while the screen still opens: tried again
    LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
  }
  local S = { mode = nil, started = false, co = nil, deciding = false, move = false, shown = false, hidden = 0 }

  local function log(text)
    pcall(funcLuaCommand, K.LOG, "VRFW team editor", "lineup (card action): " .. text)
  end

  local function retail(name, ...)
    local f = rawget(_ENV, name)
    if type(f) == "function" then
      return f(...)
    end
    return nil
  end

  local function editor()
    local E = VRFW_TeamEditor
    return type(E) == "table" and type(E.CardAction) == "function" and E or nil
  end

  -- the popup rows that draw on this screen itself (retail setting types, VRFW_ListRows.PLAYER_COMMAND)
  local function draws_on_screen(kind)
    local kinds = type(VRFW_ListRows) == "table" and VRFW_ListRows.PLAYER_COMMAND or nil
    return kinds ~= nil and (kind == kinds.VIEW_MODEL or kind == kinds.SHIRT_NUMBER)
  end

  local function hide_screen()
    pcall(funcLuaMenuCommand, K.MENU_HIDE, 1, K.SCREEN)
    S.hidden = S.hidden + 1
  end

  local function show_screen()
    for _ = 1, S.hidden do
      pcall(funcLuaMenuCommand, K.MENU_SHOW, K.SCREEN)
    end
    S.hidden = 0
  end

  local function popup_mode()
    local E = editor()
    return E ~= nil and S.mode == E.CARD_ACTION.POPUP
  end

  VRFW_Host.on(STEM, "OnInit", {
    id = "menu_engine.team_editor_card_actions", phase = "after",
    fn = function()
      local E = editor()
      S.mode = E ~= nil and E.CardAction() or nil
      S.started, S.co, S.deciding, S.move, S.shown, S.hidden = false, nil, false, false, false, 0
      if S.mode ~= nil then
        hide_screen()
        log(popup_mode() and "popup: screen hidden" or "player page: screen hidden, plate shown")
      end
    end,
  })

  -- the first layer that opens: hidden again (a layer opened after the hide)
  VRFW_Host.on(STEM, "OnOpenLayer", {
    id = "menu_engine.team_editor_card_actions", phase = "before",
    fn = function()
      if S.mode ~= nil and S.hidden == 1 and not S.shown then
        hide_screen()
      end
    end,
  })

  -- the decide on the card the screen opened on, then the screen closed (the retail Back, again while it is ignored)
  local function run(layer, idx)
    coroutine.yield()
    local ok, focused = pcall(funcLuaMenuCommand, K.HAS_FOCUS, layer, idx)
    if ok and focused == true then
      -- as the engine does for a decide: the retail OnEnter (sound, input off), then OnDecideFocus
      if retail("OnEnter", layer, idx) ~= 1 then
        retail("OnDecideFocus", layer, idx)
      end
    else
      log("the card " .. tostring(idx) .. " has no focus: no popup")
    end
    local E = editor()
    if S.move and E ~= nil then
      E.RequestCardMove()
    end
    for try = 1, K.CLOSE_TRIES do
      local okx, exists = pcall(funcLuaMenuCommand, K.MENU_EXISTS, K.INPUT_OWNER)
      if okx and exists ~= true then
        return
      end
      retail("OnFunction", K.BACK, 0)
      for _ = 1, K.CLOSE_EVERY do
        coroutine.yield()
      end
      if try == K.CLOSE_TRIES then
        log("the screen did not close: Back closes it")
      end
    end
  end

  -- POPUP: the card the dock opened the screen on is up (the retail's own check of that moment)
  VRFW_Host.on(STEM, "OnOpenEndLayer", {
    id = "menu_engine.team_editor_card_actions", phase = "after",
    fn = function(_, layer, idx)
      if not popup_mode() or S.started then
        return
      end
      local card = retail("IsSelectLeaderCard") == true and K.COACH_CARD or K.CARDS
      if layer ~= card then
        return
      end
      local ok, focused = pcall(funcLuaMenuCommand, K.FOCUS_IDX, layer)
      if not ok or focused ~= idx then
        return
      end
      S.started = true
      log("card " .. tostring(idx) .. ": popup")
      S.co = coroutine.create(function() run(layer, idx) end)
    end,
  })

  VRFW_Host.on(STEM, "Step", {
    id = "menu_engine.team_editor_card_actions", phase = "after",
    fn = function()
      if S.co == nil then
        return
      end
      local ok, err = coroutine.resume(S.co)
      if not ok then
        log("error " .. tostring(err))
      end
      if not ok or coroutine.status(S.co) == "dead" then
        S.co = nil
      end
    end,
  })

  -- a card's popup: «Mover» handed to the dock, the rows that draw here shown while they run
  VRFW_Host.on(STEM, "OnDecideFocus", {
    id = "menu_engine.team_editor_card_actions", phase = "around", priority = -900,
    fn = function(nxt, layer, ...)
      if S.mode == nil or (layer ~= K.CARDS and layer ~= K.COACH_CARD) then
        return nxt(layer, ...)
      end
      S.deciding, S.move = true, false
      local r = table.pack(pcall(nxt, layer, ...))
      S.deciding = false
      if S.shown then
        S.shown = false
        hide_screen()
        if popup_mode() then
          pcall(funcLuaMenuCommand, K.MENU_HIDE, 1, K.PLATE)
        end
      end
      if not r[1] then
        log("popup error " .. tostring(r[2]))
        return
      end
      if S.move and not popup_mode() then
        -- the player page: the move goes to the dock too
        local E = editor()
        if E ~= nil then
          E.RequestCardMove()
        end
        retail("OnFunction", K.BACK, 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  -- the retail kind 0 row («Mover») calls OnEnterCommon on the card: not on this hidden pitch
  VRFW_Host.on(STEM, "OnEnterCommon", {
    id = "menu_engine.team_editor_card_actions", phase = "around", priority = -900,
    fn = function(nxt, layer, ...)
      if S.deciding and (layer == K.CARDS or layer == K.COACH_CARD) then
        S.move = true
        log("move handed to the dock")
        return
      end
      return nxt(layer, ...)
    end,
  })

  -- the row picked in the popup: one that draws on this screen gets the screen (and the plate) shown while it runs
  VRFW_Host.on(STEM, "CallbackCloseSelectCharaSetting", {
    id = "menu_engine.team_editor_card_actions", phase = "before",
    fn = function(picked)
      if S.mode == nil or type(picked) ~= "number" or picked < 0 then
        return
      end
      local list = retail("GetSelectSettingTypeOrderList")
      local kind = type(list) == "table" and list[picked + 1] or nil
      if draws_on_screen(kind) then
        S.shown = true
        show_screen()
        if popup_mode() then
          -- the plate hides itself at its OnInit and its first layer open (personal_plate_menuX_inline_card_actions.lua)
          pcall(funcLuaMenuCommand, K.MENU_SHOW, K.PLATE)
          pcall(funcLuaMenuCommand, K.MENU_SHOW, K.PLATE)
        end
        log("row " .. tostring(kind) .. " draws on the screen: shown while it runs")
      end
    end,
  })

  VRFW_Host.on(STEM, "FinalizeMenu", {
    id = "menu_engine.team_editor_card_actions", phase = "before", create = true,
    fn = function()
      S.mode, S.co, S.started, S.deciding, S.move, S.shown, S.hidden = nil, nil, false, false, false, false, 0
    end,
  })
end
