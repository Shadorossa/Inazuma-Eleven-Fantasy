-- Player page block (plate_pages.lua): the SUPERTÉCNICAS page and its navigation
  -- ---- SUPERTÉCNICAS: 2 | 2 | 2, icons only, the focused move's plate under the groups ----------------------------
  -- round 9 (Nacho): two columns of slot groups, every move plate visible (name, AT / DF, icons), compact:
  --   1 | move A      2 | move C
  --     | move B        | move D
  --   3 | move E
  --     | move F
  -- group k top-left (screen) GROUP_AT[k]; badge (status base _cmd_slot0k on its node _pos_slot0k) 60 x 80; the two
  -- move rows (soccer11_09, attached at _atc_slot0k_sp01 / 02 = _pos_slot0k + (302, +-31)) at MOVE_K scale, stacked
  -- right of the badge. Retail positions back on every other page.
  -- round 10 (Nacho): ONE row of three groups (badge + its two plates stacked) inside the card; plates at 48 %
  -- (253 x 36: the names get small, the trade-off Nacho accepted to try)
  -- round 16 (Nacho, 2026-10-15: «los de 1 en una fila, los de 2 en la siguiente...»): THREE ROWS, one per slot pair:
  --   [1] move A  move B
  --   [2] move C  move D
  --   [3] move E  move F
  -- badge at the row's left, the pair's two plates side by side (PLATE_DX2 apart) at 68 % (358 x 51); IA tag and AT
  -- number scale with the plate (same row scale)
  G.GROUP_AT = {{995, 732}, {995, 789}, {995, 846}}
  G.MOVE_K = 0.68
  -- round 17 (Nacho: badges 10-15 px low, bracket lines running into the next row, too close to the panel edge): the
  -- badge is 36 x 46 (its bracket lines now end inside the 51 px bar row), its node sits BADGE_CY below the row top
  -- (mesh centre = node, measured: it sat 10 px low at the old y 6 + 29) and its left edge at BADGE_X (8 px before the bars)
  G.BADGE = {36, 46}
  G.BADGE_X, G.BADGE_CY = 1004, 25
  G.PLATE_DX, G.PLATE_DX2 = 52, 385
  G.M_BADGE = {4182803106, 1616499480, 392094606}               -- _cmd_slot01..03
  G.SK_AT_DMY = 365666709                -- _num_at_cmd_dmy01 (the AT number's placeholder quad: the white square)
  G.GRAPH_NUM = 732343773                -- soccer11_06_p1_formation_status_graph_param_num
  function G.Moves()
    if not Exists(G.SKILL) or not Exists(G.STATUS) then
      return
    end
    local mine = On() and G.ptype == 1
    if not mine then
      if G.movesOn then
        G.movesOn = false
        for k = 1, 3 do
          Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 0, G.SLOT_RETAIL[k][1])
          Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 1, G.SLOT_RETAIL[k][2])
          Cmd(C.NODE_SCALE, G.STATUS, 0, G.M_BADGE[k], 64, 84)
          Cmd(C.NODE_POS, G.STATUS, 0, G.M_BADGE[k], 1, 42)
        end
        for i = 0, 5 do
          for _, l in ipairs({G.SKILL, G.SKILL_BLANK}) do
            if Exists(l) and Cmd(C.IS_OPEN, l, i) == true then
              Cmd(C.POS, l, 0, 0, 0, i)
              Cmd(C.SCALE, l, 1, 1, 1, i)
            end
          end
        end
      end
      return
    end
    if not G.movesOn then                  -- round 8 / earlier states undone once
      for i = 0, 5 do
        if Cmd(C.IS_OPEN, G.SKILL, i) == true then
          Cmd(C.NODE_POS, G.SKILL, i, G.SK_HIDE_NODE[1], 0, 0)
          Cmd(C.NODE_POS, G.SKILL, i, G.SK_HIDE_NODE[2], 0, 203)
          Cmd(C.TEXT_VIS, G.SKILL, G.SK_TEXT, true, i)
          Cmd(C.MESH, G.SKILL, G.SK_HIDE_MESH[1], true, i)
        end
      end
    end
    G.movesOn = true
    local s = G.MOVE_K
    for k = 1, 3 do
      local gx, gy = G.GROUP_AT[k][1], G.GROUP_AT[k][2]
      -- badge: node at (X0, Y0) world, the mesh's top-left at node + (0, 40) after its scale (60 x 80)
      local X0, Y0 = G.BADGE_X, -(gy + G.BADGE_CY)
      Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 0, X0 - 1358)
      Cmd(C.NODE_POS, G.STATUS, 0, G.SLOT_NODES[k], 1, Y0 + 540)
      Cmd(C.NODE_SCALE, G.STATUS, 0, G.M_BADGE[k], G.BADGE[1], G.BADGE[2])
      Cmd(C.NODE_POS, G.STATUS, 0, G.M_BADGE[k], 1, G.BADGE[2] / 2)
      for j = 0, 1 do
        local i = (k - 1) * 2 + j
        local Ax, Ay = X0 + 302, Y0 + (j == 0 and 31 or -31)        -- the row's attach locator (world, y up)
        local tx, ty = gx + G.PLATE_DX + G.PLATE_DX2 * j, -(gy + 2)   -- the plate's top-left (world, y up)
        local px, py = tx - Ax - s * (-267), ty - Ay - s * 34
        for _, l in ipairs({G.SKILL, G.SKILL_BLANK}) do
          if Exists(l) and Cmd(C.IS_OPEN, l, i) == true then
            Cmd(C.SCALE, l, s, s, 1, i)
            Cmd(C.POS, l, px, py, 0, i)
          end
        end
        if Cmd(C.IS_OPEN, G.SKILL, i) == true then
          Cmd(C.MESH, G.SKILL, G.SK_AT_DMY, false, i)
        end
      end
    end
    -- the move-detail mode (N) re-shows the radar layers: off again on this page
    if Cmd(C.IS_VIS, G.GRAPH, 0) == true then
      pcall(SetVisibleGraphLayer, false)
      if type(EVT_R9) == "table" and type(EVT_R9.Visible) == "function" then
        pcall(EVT_R9.Visible, false)
      end
    end
    if type(G.BarsVisible) == "function" then
      G.BarsVisible(false)
    end
  end

  -- ---- SUPERTÉCNICAS «Confirmación de supertécnica» navigation (2026-10-15, owner: the D-pad follows the 3-row page) --
  -- The engine's focus links of the move layer follow the retail column (up / down inside a pair, left / right between
  -- pairs). On this page (rows = pairs: instance 2r = left plate, 2r + 1 = right plate) a D-pad / arrow / stick step
  -- goes where the page shows it: LEFT / RIGHT = the other plate of the same row, UP / DOWN = the row above / below in
  -- the same column (the other column when that plate is empty, empty rows skipped). Stops at the edges (no wrap).
  -- Empty plates are never focused by a key (Aceptar / X do nothing on them, retail OnEnterCommon). The engine's own
  -- step is redirected inside OnChangeFocus (before that frame is drawn); a step the engine does not make (an edge of
  -- the old links) is made from the frame hook on the next frame. The pointer is the engine's: its zones follow the
  -- moved plates (instance transform); with the Fantasy rows a zone is on only where the row shows a move.
  -- The engine calls OnChangeFocus(layer, direction token) after a key step (retail soccer_formation_menu_inc
  -- GetFocusDirType: the token is the direction, the new instance is the layer's focused index), so the step's
  -- direction is read from that token; the input state is only a fallback for a call without a known token.
  G.NAV = {CHECK_INPUT = @crc:CMND_CHECK_INPUT_CMD@, MENU_CTRL = 1332654303, MENU_CTRL_ANALOG = 2748927068,
    UP = 1197218715, DOWN = 3259546669, LEFT = 2765147006, RIGHT = 2075023265,
    FOCUS_MARK = 1778826357, FOCUS_SET = 3466097042, PLAY_ANIME = @crc:CMND_PLAY_ANIME_TYPE@, FOCUS_ANIME = 2734777837,
    ANIME_KIND = 973515837, ZONE = 855005857, GET_SKILL = 903078840, SOUND = @crc:CMND_SND_PLAY_SE@, CURSOR_SOUND = 2500047763,
    GHOST_FRAMES = 3, COLUMNS = 2, ROWS = 3,
    -- OnChangeFocus direction tokens (retail GetFocusDirType / rpg_team_dock_menu_inc GetForcusDir: 1 up, 2 down,
    -- 3 left, 4 right; the second token of each pair is the analog stick's)
    DIRECTION_TOKENS = {[3483715641] = "up", [906909014] = "up", [49409691] = "down", [2207386753] = "down",
      [1684642248] = "left", [3842669522] = "left", [1644353666] = "right", [2682339866] = "right"}}
  G.nav = {index = nil, pending = nil, handled = false, busy = false, echo = false, lastDir = nil, ghost = nil,
    expect = nil}

  -- the move layer holds the control focus on SUPERTÉCNICAS of the player page (the confirmation mode)
  function G.NavActive()
    return G.H.pages and On() and G.ptype == 1 and Exists(G.SKILL) and Cmd(G.FOCUS_ACTIVE, G.SKILL) == true
  end

  -- the direction stepped this frame: "up", "down", "left", "right" or nil
  function G.NavDirection()
    local N = G.NAV
    for _, d in ipairs({{"up", N.UP}, {"down", N.DOWN}, {"left", N.LEFT}, {"right", N.RIGHT}}) do
      for _, control in ipairs({N.MENU_CTRL, N.MENU_CTRL_ANALOG}) do
        local ok, on = pcall(funcLuaCommand, N.CHECK_INPUT, control, d[2])
        if ok and on == true then
          return d[1]
        end
      end
    end
    return nil
  end

  -- instance i shows a move (the Fantasy row's own move when the rows were filled from the skill table)
  function G.NavFilled(i)
    if i < 0 or i >= G.NAV.COLUMNS * G.NAV.ROWS or Cmd(C.IS_OPEN, G.SKILL, i) ~= true then
      return false
    end
    local F = EVT_PPG_FANTASY_MOVES
    if type(F) == "table" and type(F.On) == "function" and type(F.shown) == "table" and F.shown[i] ~= nil and F.On() then
      return F.shown[i].move ~= 0
    end
    if type(GetPersonalPlateSelectCharaStHdlAuto) ~= "function" then
      return true
    end
    local okH, hdl = pcall(GetPersonalPlateSelectCharaStHdlAuto)
    if not okH or type(hdl) ~= "number" or hdl == 0 then
      return true
    end
    local okS, move = pcall(funcLuaCommand, G.NAV.GET_SKILL, hdl, i)
    return okS and move ~= nil and move ~= 0
  end

  -- the instance a step `dir` from instance `from` lands on (from itself at an edge)
  -- (grid of NAV.ROWS x NAV.COLUMNS, instance = row * COLUMNS + column: G.Moves' placement). LEFT / RIGHT: the
  -- nearest filled plate of the same row in that direction; UP / DOWN: the nearest row in that direction with a filled
  -- plate, the same column first, else the filled plate of that row closest to the column (the left one on a tie)
  function G.NavTarget(from, dir)
    local columns, rows = G.NAV.COLUMNS, G.NAV.ROWS
    local row, column = math.floor(from / columns), from % columns
    if dir == "left" or dir == "right" then
      local step = dir == "left" and -1 or 1
      local c = column + step
      while c >= 0 and c < columns do
        if G.NavFilled(row * columns + c) then
          return row * columns + c
        end
        c = c + step
      end
      return from
    end
    local step = dir == "up" and -1 or 1
    local r = row + step
    while r >= 0 and r < rows do
      for distance = 0, columns - 1 do
        for _, c in ipairs({column - distance, column + distance}) do
          if c >= 0 and c < columns and G.NavFilled(r * columns + c) then
            return r * columns + c
          end
        end
      end
      r = r + step
    end
    return from
  end

  -- the focus frame off on an instance that no longer holds the focus
  function G.NavUnfocus(i)
    local N = G.NAV
    Cmd(N.PLAY_ANIME, G.SKILL, i, N.FOCUS_ANIME, 2, N.ANIME_KIND)
  end

  -- the focus to instance `to` (left: the instance the engine had put it on): the retail mark, the engine's index,
  -- then the screen's OnChangeFocus (by the engine's echo, else here) for the detail window, cursor and guide
  function G.NavSetFocus(to, left)
    local N, S = G.NAV, G.nav
    S.busy, S.echo = true, false
    Cmd(N.FOCUS_MARK, G.SKILL, to, true)
    if Cmd(G.FOCUS_IDX, G.SKILL) ~= to then
      Cmd(N.FOCUS_SET, G.SKILL, to)
    end
    if not S.echo and type(OnChangeFocus) == "function" then
      pcall(OnChangeFocus, G.SKILL, to)
    end
    S.busy = false
    if left ~= nil and left ~= to then
      G.NavUnfocus(left)
      S.ghost = {left, N.GHOST_FRAMES}
    end
    S.index = to
  end

  -- OnChangeFocus of the move layer: a key step of the engine is redirected to this page's target; true = handled
  function G.NavOnChange(layer, token)
    local S = G.nav
    if S.busy then
      S.echo = true
      return false
    end
    if layer ~= G.SKILL or not G.NavActive() then
      return false
    end
    local index = Cmd(G.FOCUS_IDX, G.SKILL)       -- the instance the engine moved the focus to
    local dir = G.NAV.DIRECTION_TOKENS[token]
    if dir == nil then
      dir = G.NavDirection()
    end
    if dir == nil or S.index == nil or type(index) ~= "number" then
      S.index = type(index) == "number" and index or nil   -- the pointer or the screen moved it
      S.pending, S.expect = nil, nil
      return false
    end
    local target = G.NavTarget(S.index, dir)
    S.pending, S.handled = nil, true
    if target == index then
      S.index, S.expect = index, nil
      return false
    end
    G.NavSetFocus(target, index)
    S.expect = target
    return true
  end

  -- per frame: a step the engine did not make (pending since the last frame) is made here; new steps are noted
  function G.MovesNav()
    local S = G.nav
    if S.ghost ~= nil then
      local g = S.ghost
      g[2] = g[2] - 1
      if g[2] <= 0 then
        S.ghost = nil
      end
      if Cmd(G.FOCUS_IDX, G.SKILL) ~= g[1] then
        G.NavUnfocus(g[1])
      else
        S.ghost = nil
      end
    end
    if not G.NavActive() then
      S.index, S.pending, S.handled, S.lastDir, S.expect = nil, nil, false, nil, nil
      return
    end
    local current = Cmd(G.FOCUS_IDX, G.SKILL)
    if type(current) ~= "number" then
      return
    end
    local dir = G.NavDirection()
    local lastDir = S.lastDir
    S.lastDir = dir
    if S.handled then
      -- a redirected step the engine put back on its own target after OnChangeFocus: set once more
      local expect = S.expect
      S.handled, S.pending, S.expect = false, nil, nil
      if expect ~= nil and current ~= expect then
        G.NavSetFocus(expect, current)
        current = expect
      end
      S.index = current
      return
    end
    local p = S.pending
    S.pending = nil
    if p ~= nil and current == p.from then
      local target = G.NavTarget(p.from, p.dir)
      if target ~= current then
        G.NavSetFocus(target, current)
        pcall(funcLuaCommand, G.NAV.SOUND, G.NAV.CURSOR_SOUND)
        current = target
      end
    end
    S.index = current
    if dir ~= nil and dir ~= lastDir then
      S.pending = {from = current, dir = dir}
    end
  end

  -- the pointer zones of the move plates on the Fantasy rows: on where the row shows a move (the retail code reads
  -- the list position of the same index)
  function G.NavZones()
    local F = EVT_PPG_FANTASY_MOVES
    if not G.H.pages or not On() or G.ptype ~= 1 or not Exists(G.SKILL) or type(F) ~= "table"
        or type(F.On) ~= "function" or type(F.shown) ~= "table" or not F.On() then
      return
    end
    for i = 0, 5 do
      local shown = F.shown[i]
      if shown ~= nil and Cmd(C.IS_OPEN, G.SKILL, i) == true then
        Cmd(G.NAV.ZONE, G.SKILL, i, shown.move ~= 0)
      end
    end
  end
