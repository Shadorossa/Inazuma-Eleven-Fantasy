-- menu_engine: the SECOND BENCH COLUMN of the team screens (docs/framework/team-editor.md «Two bench columns»).
-- Definitions only: this file runs in every menu VM (lua\_all); no engine call at load time.
--
-- A team holds 29 dock positions: 0-10 starters, 11-15 bench, 16-18 managers, 19 the coach, 20-28 reserves. The
-- retail team screens draw 0-18 and the coach. With spec.bench_columns = 2 (VRFW_TeamEditor, foreign team docks)
-- the reserve positions 20-24 are a second bench column right of the bench:
--   * the cards: instances 20-24 of team00_01_chara_card_for_soccer and its empty slots (content\menus\
--     bench_columns.toml: 25 instances, the frame's attach rows for 20-24); the retail draw stops at 18, so the
--     column is drawn here (Draw) after every retail draw of the cards and after every focus change;
--   * the focus: right from a bench card goes to the card beside it, left from the column back to the bench, up / down
--     inside the column (Nav); the pointer reaches the column through its pointer zones (the retail focus path);
--   * the swaps run through the retail ones (the dock's place pair takes the reserve positions);
--   * the cursor: on the cards' cursor locator of the retail focus change (UpdateChangeFocusLayer: the card frame
--     locator, its small-card twin in the small card mode), set for the card the focus went to, never from the
--     selection index (the retail focus change runs before the selection index is updated). The list rows' «cursor»
--     locator is no card node: a cursor put there drew a second, larger frame off the card;
--   * the layout (the dock only): the pitch frame field_dx px to the side (the frame layer's root: the cards, their
--     pointer zones, focus frames and cursor locators ride on it). The bench cards stay on their joints: an instance
--     moved with CMND_SET_LAYER_LOCAL_POS keeps its pointer zone and focus at the joint, so the bench_dx move of
--     2.385 left column 1's focus on column 2 (spec.bench_dx is no longer applied)
--     (screen px). The lineup screen opened from the dock keeps the retail layout.
-- A screen without the option hides the instances 19-24 (Tidy).
--
--   VRFW_BenchColumns.Begin(screen)     -> on: the mode of this open (call at the screen's OnInit);
--                                          screen = { layout = <field_dx / bench_dx apply> }
--   VRFW_BenchColumns.Focused(layer, i) -> after a retail focus change to card i: the column drawn, the cursor on i
--   VRFW_BenchColumns.Active()          -> on
--   VRFW_BenchColumns.Draw()            -> the column drawn (or the extra instances hidden when off)
--   VRFW_BenchColumns.DrawAt(index)     -> one instance (setup / open of an instance 19-24)
--   VRFW_BenchColumns.Opened(layer, i)  -> after a layer instance opened: the frame shift, the focus range
--   VRFW_BenchColumns.Nav(layer, input) -> true when the move was the column's (the retail move is skipped)
if VRFW_BenchColumns == nil then
  local B = {
    CARDS = 1973487846,              -- team00_01_chara_card_for_soccer
    BLANKS = 3571911991,             -- team00_01_p1_chara_card_blank (the empty slots)
    FRAME = 3321884270,              -- soccer11_02_formation_frame (the pitch, the bench, the managers, the coach)
    BENCH_FIRST = 11, BENCH_LAST = 15,   -- the bench (dock positions = card instances)
    SPARE = 19,                      -- a card instance no position uses (the coach has a layer of its own)
    SECOND_FIRST = 20, SECOND_LAST = 24, -- the second column: the team's reserve positions 20-24
    COUNT = 25,                      -- card instances with the second column
    VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,   -- (layer, index, on)
    ZONE = 855005857,                -- (layer, index, on): an instance's pointer zone
    CREATED = 1175615627,            -- (layer) -> instances created
    FOCUS_RANGE = 3252599449,        -- (layer, count): the instances the focus may reach (retail: 19)
    CURSOR = 381797568,              -- (layer, cursor node, index, count): the cursor on an instance
    CURSOR_NODE = 945715707,         -- the cards' cursor locator (the card frame), as the retail focus change uses it
    SMALL_CURSOR_NODE = 1967169874,  -- the same in the small card mode (IsAlwaysCardSizeSmallMode)
    FOCUS_SET = 1778826357,          -- (layer, index, on): the instance focused
    GET_POS = VRFW_Cmd.GET_LAYER_LOCAL_POS, -- (layer, index) -> x, y, z
    SET_POS = VRFW_Cmd.SET_LAYER_LOCAL_POS, -- (layer, x, y, z, index)
    SOUND = VRFW_Cmd.SND_PLAY_SE, SE_MOVE = 2500047763, SE_NO = 2086672038,   -- sy0005 / sy0003
    LOG = VRFW_Cmd.EVT_LOG,
    -- the card layer's focus inputs (CMD_FCS_CHANGE arguments of CMD_UP / CMD_DOWN / CMD_LEFT / CMD_RIGHT)
    DIRECTION = { [3483715641] = "up", [49409691] = "down", [1684642248] = "left", [1644353666] = "right" },
  }
  local S = { on = false, field_dx = 0, bench_dx = 0, frame_x = nil, logged = {} }

  local function log(text)
    pcall(funcLuaCommand, B.LOG, "VRFW bench columns", text)
  end

  local function call(name, ...)
    local fn = rawget(_ENV, name)
    if type(fn) ~= "function" then
      return false
    end
    return pcall(fn, ...)
  end

  local function created(layer)
    local ok, n = pcall(funcLuaMenuCommand, B.CREATED, layer)
    return ok and type(n) == "number" and n or 0
  end

  local function hide(layer, index)
    pcall(funcLuaMenuCommand, B.VISIBLE, layer, index, false)
    pcall(funcLuaMenuCommand, B.ZONE, layer, index, false)
  end

  local function selected()
    local ok, index = call("GetFormationSelectCharaIdx")
    return ok and type(index) == "number" and index or -1
  end
  local function in_column(index)
    return index >= B.SECOND_FIRST and index <= B.SECOND_LAST
  end

  VRFW_BenchColumns = {}

  function VRFW_BenchColumns.Begin(screen)
    screen = type(screen) == "table" and screen or {}
    local editor = VRFW_TeamEditor
    local foreign = type(editor) == "table" and type(editor.Foreign) == "function" and editor.Foreign() or nil
    S.on = foreign ~= nil and foreign.bench_columns == 2
    local layout = S.on and screen.layout == true
    S.field_dx = layout and (foreign.field_dx or 0) or 0
    S.bench_dx = 0
    S.frame_x, S.logged = nil, {}
    if S.on then
      log(string.format("second bench column on (pitch %d px)", S.field_dx))
    end
    return S.on
  end

  -- the cursor on card `index`: the locator the retail focus change takes for a card (UpdateChangeFocusLayer)
  local function cursor(index)
    local _, small = call("IsAlwaysCardSizeSmallMode")
    local node = small == true and B.SMALL_CURSOR_NODE or B.CURSOR_NODE
    pcall(funcLuaMenuCommand, B.CURSOR, B.CARDS, node, index, B.COUNT)
  end

  function VRFW_BenchColumns.Active()
    return S.on
  end

  -- one instance 19-24: off = hidden; 19 = hidden; 20-24 = the player at that reserve position (a small bench card),
  -- or the empty slot
  function VRFW_BenchColumns.DrawAt(index)
    if index < B.SPARE or index > B.SECOND_LAST then
      return
    end
    if not S.on or index == B.SPARE then
      if created(B.CARDS) > index then hide(B.CARDS, index) end
      if created(B.BLANKS) > index then hide(B.BLANKS, index) end
      return
    end
    if created(B.CARDS) <= index then
      if not S.logged.count then
        S.logged.count = true
        log("the card layer has " .. created(B.CARDS) .. " instances: no second column (menu patch missing)")
      end
      return
    end
    local _, handle = call("GetCharaStHdl", index)
    handle = type(handle) == "number" and handle or 0
    if handle ~= 0 then
      local _, formation = call("GetApplyFormationId")
      local _, face = call("GetCharaFaceType")
      -- drawn as a bench position (the retail draw takes positions under 19), on instance `index`
      call("UpdateMemberCharaIconInfoByChrStHdl", handle, B.BENCH_FIRST, formation, face, 0, false, B.CARDS, index)
      pcall(funcLuaMenuCommand, B.VISIBLE, B.CARDS, index, true)
    else
      pcall(funcLuaMenuCommand, B.VISIBLE, B.CARDS, index, false)
    end
    pcall(funcLuaMenuCommand, B.ZONE, B.CARDS, index, true)
    if created(B.BLANKS) > index then
      pcall(funcLuaMenuCommand, B.VISIBLE, B.BLANKS, index, true)
    end
  end

  function VRFW_BenchColumns.Draw()
    for index = B.SPARE, B.SECOND_LAST do
      VRFW_BenchColumns.DrawAt(index)
    end
  end

  -- after a retail focus change (UpdateChangeFocusLayer(layer, from, to)): the column drawn, and the cursor on a
  -- column card the focus went to (the pointer; the retail cursor count stops at 19 on the lineup screen)
  function VRFW_BenchColumns.Focused(layer, index)
    if not S.on then
      return
    end
    VRFW_BenchColumns.Draw()
    if layer == B.CARDS and type(index) == "number" and in_column(index) then
      cursor(index)
    end
  end

  -- after a layer instance opened: the pitch frame moved field_dx px (once per position the retail open gives it), the
  -- card focus range up to the column
  function VRFW_BenchColumns.Opened(layer, index)
    if not S.on then
      if (layer == B.CARDS or layer == B.BLANKS) and index >= B.SPARE then
        VRFW_BenchColumns.DrawAt(index)
      end
      return
    end
    if layer == B.FRAME and S.field_dx ~= 0 then
      local ok, x, y, z = pcall(funcLuaMenuCommand, B.GET_POS, layer, 0)
      if ok and type(x) == "number" and (S.frame_x == nil or math.abs(x - S.frame_x) >= 0.5) then
        pcall(funcLuaMenuCommand, B.SET_POS, layer, x + S.field_dx, y or 0, z or 0, 0)
        S.frame_x = x + S.field_dx
        log(string.format("pitch frame moved %d px (x %.0f -> %.0f)", S.field_dx, x, S.frame_x))
      end
    elseif layer == B.CARDS and index == 0 then
      pcall(funcLuaMenuCommand, B.FOCUS_RANGE, B.CARDS, B.COUNT)
    end
    if (layer == B.CARDS or layer == B.BLANKS) and index >= B.SPARE then
      VRFW_BenchColumns.DrawAt(index)
    end
  end

  -- the focus to `target` on the card layer: the retail focus change, or (while a card is held) the focus and the
  -- cursor only (the retail held-card path reads tables kept for the instances 0-18)
  local function move(from, target)
    local _, holding = call("IsChangeMemberMode")
    pcall(funcLuaCommand, B.SOUND, B.SE_MOVE)
    if holding == true then
      pcall(funcLuaMenuCommand, B.FOCUS_SET, B.CARDS, from, false)
      pcall(funcLuaMenuCommand, B.FOCUS_SET, B.CARDS, target, true)
    else
      call("UpdateChangeFocusLayer", B.CARDS, from, target)
    end
    call("SetSelectCharaIdx", target)
    call("UpdateSelectCharaInfo")
    VRFW_BenchColumns.Draw()
    cursor(target)
  end

  function VRFW_BenchColumns.Nav(layer, input)
    if not S.on or layer ~= B.CARDS then
      return false
    end
    local direction = B.DIRECTION[input]
    if direction == nil then
      return false
    end
    local from = selected()
    local target
    if in_column(from) then
      if direction == "left" then
        target = from - (B.SECOND_FIRST - B.BENCH_FIRST)
      elseif direction == "up" and from > B.SECOND_FIRST then
        target = from - 1
      elseif direction == "down" and from < B.SECOND_LAST then
        target = from + 1
      end
      if target == nil then
        pcall(funcLuaCommand, B.SOUND, B.SE_NO)
        return true
      end
    elseif from >= B.BENCH_FIRST and from <= B.BENCH_LAST and direction == "right" then
      target = from + (B.SECOND_FIRST - B.BENCH_FIRST)
    else
      return false
    end
    move(from, target)
    return true
  end
end
