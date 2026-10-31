-- menu_engine: INLINE CARD ACTIONS of the team dock (soccer_team_dock_menu), for VRFW_TeamEditor.Run with
-- spec.inline_card_actions (lua\_all\81_team_editor.lua, docs/framework/team-editor.md). Definitions only; no engine
-- call at load.
--
-- The retail dock opens its lineup screen (team_dock_formation_menu) on A on a player card; the card's popup
-- («PERSONAJE») and every row of it live in that screen. With the option:
--   * A on a player card: the retail open runs with the card action POPUP; the lineup screen and its player plate
--     stay hidden (team_dock_formation_menu\150_inline_card_actions.lua, personal_plate_menu\130_inline_card_actions.lua),
--     the screen opens the popup of that card and closes again once its row is done, so the popup and the screens
--     its rows open show over the dock. The dock stays drawn under it (the retail open suspends it).
--   * «Mover»: the lineup screen hands it back (VRFW_TeamEditor.RequestCardMove) and the dock starts the move on its
--     own pitch (the retail OnEnterCommon, as the lineup screen's row does); A on another card swaps, Back drops it.
--   * Y (CMD_FUNC3) on a player card: the same open with the card action PAGE: the lineup screen hidden, its player
--     plate (the player page) shown; Back closes it.
if VRFW_Host ~= nil then
  local STEM = "soccer_team_dock_menu"
  local K = {
    CARDS = 1973487846,              -- team00_01_chara_card_for_soccer
    COACH_CARD = 1658289671,         -- team00_01_chara_card_for_leader
    DOCK = 937147172,                -- soccer_team_dock_menu
    PAGE_FUNCTION = 4219711668,      -- OnFunction of CMD_FUNC3 (Y) on a card (retail: set as active team)
    HAS_FOCUS = 102308320,           -- (layer[, index]) -> the layer (instance) has the focus
    FOCUS_IDX = 2603265800,          -- (layer) -> focused index
    MENU_INPUT = 1558704558,         -- (menu, on)
    MENU_RESUME = 66378409,          -- (menu, 1): the retail ResumeTeamDock
    SOUND = VRFW_Cmd.SND_PLAY_SE, SE_CANCEL = 202039849,   -- sy0001
    LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
  }
  local S = { on = false, opening = nil, next_mode = nil, co = nil }

  local function log(text)
    pcall(funcLuaCommand, K.LOG, "VRFW team editor", "dock: " .. text)
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
    return type(E) == "table" and type(E.SetCardAction) == "function" and E or nil
  end

  local function card_layer(layer)
    return layer == K.CARDS or layer == K.COACH_CARD
  end

  -- the player card layer that has the focus and its index, nil when none
  local function focused_card()
    for _, layer in ipairs({ K.CARDS, K.COACH_CARD }) do
      local ok, has = pcall(funcLuaMenuCommand, K.HAS_FOCUS, layer)
      if ok and has == true then
        local oki, idx = pcall(funcLuaMenuCommand, K.FOCUS_IDX, layer)
        return layer, (oki and type(idx) == "number") and idx or 0
      end
    end
    return nil
  end

  VRFW_Host.on(STEM, "OnInit", {
    id = "menu_engine.team_editor_card_actions", phase = "before",
    fn = function()
      local E = editor()
      local foreign = E ~= nil and E.Foreign() or nil
      S.on = foreign ~= nil and foreign.inline_card_actions == true
      S.opening, S.next_mode, S.co = nil, nil, nil
      if S.on then
        E.SetCardAction(nil)
        E.TakeCardMove()
        log("inline card actions on (A: the card's popup on the dock, Y: the player page)")
      end
    end,
  })

  -- the retail open of the lineup screen (`nxt`, the dock's OnEnter) with a card action; once the screen is gone,
  -- the move «Mover» asked for starts on the dock
  local function open(nxt, mode, layer, row, ...)
    local E = editor()
    S.opening = mode
    E.SetCardAction(mode)
    E.TakeCardMove()
    log(string.format("card %d: lineup screen hidden, %s", row or -1,
      mode == E.CARD_ACTION.PAGE and "player page" or "popup"))
    local r = table.pack(pcall(nxt, layer, row, ...))
    S.opening = nil
    E.SetCardAction(nil)
    if not r[1] then
      log("card action error " .. tostring(r[2]))
      return
    end
    if E.TakeCardMove() then
      log(string.format("card %d: move started on the dock", row or -1))
      retail("OnEnterCommon", layer, row, true)
    end
    return table.unpack(r, 2, r.n)
  end

  -- A on a player card: its popup (or, while a card is held, the swap, as the dock's retail OnEnterCommon does)
  VRFW_Host.on(STEM, "OnEnter", {
    id = "menu_engine.team_editor_card_actions", phase = "around", priority = -900,
    fn = function(nxt, layer, row, ...)
      if not S.on or not card_layer(layer) or editor() == nil then
        return nxt(layer, row, ...)
      end
      if retail("IsChangeMemberMode") == true then
        return retail("OnEnterCommon", layer, row, true)
      end
      local E = editor()
      local mode = S.next_mode or E.CARD_ACTION.POPUP
      S.next_mode = nil
      return open(nxt, mode, layer, row, ...)
    end,
  })

  -- the retail open suspends the dock before its lineup screen: drawn again at once (input stays off), so the popup
  -- shows over the dock
  VRFW_Host.on(STEM, "SetIsTeamDockTop", {
    id = "menu_engine.team_editor_card_actions", phase = "after",
    fn = function(_, top)
      if S.opening ~= nil and top == false then
        pcall(funcLuaMenuCommand, K.MENU_RESUME, K.DOCK, 1)
        pcall(funcLuaMenuCommand, K.MENU_INPUT, K.DOCK, false)
      end
    end,
  })

  -- Back while a card is held: the move dropped, the dock stays
  VRFW_Host.on(STEM, "OnBack", {
    id = "menu_engine.team_editor_card_actions", phase = "around", priority = -900,
    fn = function(nxt, layer, ...)
      if S.on and card_layer(layer) and retail("IsChangeMemberMode") == true then
        pcall(funcLuaCommand, K.SOUND, K.SE_CANCEL)
        retail("TerminateMemberChangeMode", rawget(_ENV, "_teamDockTop"))
        return 1
      end
      return nxt(layer, ...)
    end,
  })

  -- Y on a player card: the player page (the decide's open in a coroutine of its own, resumed by Step); outermost, so
  -- the team page's refusal of the retail «set as active team» on that key does not take it
  VRFW_Host.on(STEM, "OnFunction", {
    id = "menu_engine.team_editor_card_actions", phase = "around", priority = -1100,
    fn = function(nxt, a1, ...)
      if not S.on or a1 ~= K.PAGE_FUNCTION or editor() == nil then
        return nxt(a1, ...)
      end
      local layer, row = focused_card()
      if layer == nil then
        return nxt(a1, ...)
      end
      if S.co ~= nil or S.opening ~= nil or retail("IsChangeMemberMode") == true then
        return
      end
      S.co = coroutine.create(function()
        S.next_mode = editor().CARD_ACTION.PAGE
        local onenter = rawget(_ENV, "OnEnter")
        if type(onenter) == "function" then
          onenter(layer, row)
        end
        S.next_mode = nil
      end)
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
        log("player page error " .. tostring(err))
        S.next_mode = nil
        pcall(funcLuaMenuCommand, K.MENU_INPUT, K.DOCK, true)
      end
      if not ok or coroutine.status(S.co) == "dead" then
        S.co = nil
      end
    end,
  })

  VRFW_Host.on(STEM, "FinalizeMenu", {
    id = "menu_engine.team_editor_card_actions", phase = "before", create = true,
    fn = function()
      if S.on and editor() ~= nil then
        editor().SetCardAction(nil)
        editor().TakeCardMove()
      end
      S.on, S.opening, S.next_mode, S.co = false, nil, nil, nil
    end,
  })
end
