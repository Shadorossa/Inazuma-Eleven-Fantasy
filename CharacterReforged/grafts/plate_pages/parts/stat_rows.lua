-- Player page block (plate_pages.lua): the ATRIBUTOS stat rows (gauges)
  -- ---- the stat rows ------------------------------------------------------------------------------------------
  -- 2026-10-12 (owner): ATRIBUTOS = TWO COLUMNS x 4 ROWS, each row  NAME | gauge | VALUE | position pills (the 8 vertical
  -- 3D bars and the line chart retired). The gauge is the retail per-player training gauge (team13_16_beans_gauge, the
  -- «Entrenar» screen's bar: grey track + fill by its rate gauge01), cloned as layer evt_pp_stat_bar (Character
  -- Reforged content/menus/player_page_layout.toml), one instance per row, attached to the graph base; its icon and
  -- «value / max» numbers hidden. The bar is drawn by the gauge's plain textured quads, no rate: the retail fill
  -- _beans_bar01 is a masked material moved by the rate gauge01, which does not advance while a match is paused (an
  -- empty bar in the match pause's Formación). Meshes draw in their order (navy plate, slash, track, fill):
  --   navy plate _beans_param_base01 = the track (sprite beans_bar_base01, the track's rect);
  --   slash _beans_bar_slash01      = the miximax gain (evt_pp_gfill_gain), from the fill's left to value + gain;
  --   track _beans_bar_base01       = the fill (evt_pp_gfill_<tags>, btl06_13 atlas), the fill's rect cut to the value.
  -- Mesh node translation = the quad's top-left, node scale = its size (gauge units).
  -- Fill = the shown value / the stat's max for this player (a training mod's «value / max» max: base + max of the
  -- page slot character_reforged.page_stat_max, CharacterReforged.Page.StatTop); without an answer, one common scale (the training screen's: the largest value
  -- + 15 %, rounded up to 50, at least 100). Names, values and pills are the graph base's own nodes, placed by the layout
  -- (research/scripts/if_plate_row_build.py ROWS_X0 / ROWS_Y / ROW_GAUGE: keep G.ROW_X0 / G.ROW_Y / G.GAUGE equal).
  -- Graph units: origin = the chart locator (screen 1435, 746), y up.
  G.ROW_X0 = {[0] = 993 - 1435, 1445 - 1435}                       -- column left edges
  G.ROW_Y = {[0] = 746 - 740, 746 - 785, 746 - 830, 746 - 875}     -- row centres
  G.GAUGE = {X = 124, W = 180, H = 28}                             -- track: x from the column's left, width, height
  -- team13_16 layout: _pos_bar01 holds the track _beans_bar_base01 (176 x 16 at -64, -13) and the fill _beans_bar01
  -- (166 x 16 at -59, -13)
  G.GG = {NODE = 3407907417 --[[_pos_bar01]], TRACK_X = -64, TRACK_Y = -13, TRACK_W = 176, TRACK_H = 16,
    FILL_X = -59, FILL_W = 166,
    HIDE = {3653430537 --[[_icon_parameter_dmy01]], 156590433 --[[_num_param_dmy01]], 2421960923 --[[_num_param_dmy02]],
      501779097 --[[_beans_bar01: the masked fill]]},
    PRIMS = {3484572139, 1455097937, 1533119290},                  -- its number prims: value, next, max
    TRACK_QUAD = 3904782638 --[[_beans_param_base01]], GAIN_QUAD = 3341153111 --[[_beans_bar_slash01]],
    FILL_QUAD = 720708095 --[[_beans_bar_base01]],
    -- sprite slots of those three meshes and the retail track sprite (team13_16 atlas)
    SLOT_TRACK_QUAD = 1215825632 --[[beans_param_base01]], SLOT_GAIN_QUAD = 192955831 --[[beans_bar_slash01]],
    SLOT_FILL_QUAD = 2201244747 --[[beans_bar_base01]], SP_TRACK = 2201244747 --[[beans_bar_base01]],
    TX_GAUGE = 995892987 --[[#/menu/102_team/team13/team13_16/team13_16.g4tx]],
    MIN_W = 0.5,                                                   -- narrower quads are hidden (gauge units)
    PRIM_VIS = 1233047821}

  local function BarsVisible(on)
    if not Exists(G.BAR) then
      return
    end
    for k = 0, 7 do
      if Cmd(C.IS_OPEN, G.BAR, k) == true then
        Cmd(C.VIS, G.BAR, k, on)
      end
    end
  end
  G.BarsVisible = BarsVisible

  -- 2026-10-13: the miximax gain of group g's stat while the Miximax view is on (G.gains: CMND_EVT_MX_GAINS order,
  -- stat i at i + 1), else 0
  G.SP_GAIN = @crc:evt_pp_gfill_gain@
  -- row k's outline (a host's G.rowFrame[g] = "raise" / "lower": the focused equipment item raises / lowers that stat,
  -- host table item_card.row_mark): the gain quad (unused there) drawn as a frame around the whole row
  function G.RowMark(k)
    local R = type(G.H.item_card) == "table" and G.H.item_card.row_mark or nil
    if R == nil or G.rowFrame == nil then
      return nil, R
    end
    for g = 1, 8 do
      if G.GROUP_ROW[g] == k and G.rowFrame[g] ~= nil then
        return G.rowFrame[g], R
      end
    end
    return nil, R
  end
  -- the gain quad's sprite and its atlas: the row outline (the host's own atlas, R.atlas) or the gain fill (btl06_13)
  function G.GainSprite(k)
    local mark, R = G.RowMark(k)
    if mark ~= nil then
      return R.sprite[mark], R.atlas or G.TX_OWN
    end
    return G.SP_GAIN, G.TX_OWN
  end
  -- a stats panel that shows an equipment item's change (a host with an item card and its rows: Equipamiento and its
  -- picker) draws each bar in its one colour: no Miximax gain past the fill (EVT_R9.mx may still be on from the player
  -- page), so the item's delta segment is the only other colour on the bar
  function G.Gain(g)
    local t = G.gains
    local IC = G.H.item_card
    if type(IC) == "table" and IC.rows ~= false then
      return 0
    end
    return t ~= nil and (tonumber(t[G.STAT[g] + 1]) or 0) or 0
  end

  -- the max of each group's stat for chara status handle hdl (G.tops[g]), from a training mod's answer (the page slot
  -- character_reforged.page_stat_max); nil = none
  function G.Tops(hdl)
    G.tops = nil
    local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
    if type(hdl) ~= "number" or type(page) ~= "table" or type(page.StatTop) ~= "function" then
      return
    end
    local t = {}
    for g = 1, 8 do
      local top = page.StatTop(hdl, G.STAT[g])
      if top == nil then
        return
      end
      t[g] = top
    end
    G.tops = t
  end

  -- instance k's three quads (see «the stat rows»): the track over the whole track rect (the layer's origin = its
  -- top-left), the gain from the fill's left to r2, the fill from the fill's left to r (r, r2 = 0..1). Set every frame:
  -- the gauge's open animation may move them.
  function G.BarQuads(k, r, r2, sx, sy)
    local GG = G.GG
    for _, m in ipairs(GG.HIDE) do
      Cmd(C.MESH, G.BAR, m, false, k)
    end
    Cmd(C.NODE_POS, G.BAR, k, GG.TRACK_QUAD, 0, 0)
    Cmd(C.NODE_POS, G.BAR, k, GG.TRACK_QUAD, 1, 0)
    Cmd(C.NODE_SCALE, G.BAR, k, GG.TRACK_QUAD, GG.TRACK_W * sx, GG.TRACK_H * sy)
    Cmd(C.MESH, G.BAR, GG.TRACK_QUAD, true, k)
    -- the gain quad lies in the layer's space (as the track quad), the fill quad inside _pos_bar01 (as the retail fill)
    local gain_w = GG.FILL_W * r2 * sx
    Cmd(C.NODE_POS, G.BAR, k, GG.GAIN_QUAD, 0, (GG.FILL_X - GG.TRACK_X) * sx)
    Cmd(C.NODE_POS, G.BAR, k, GG.GAIN_QUAD, 1, 0)
    Cmd(C.NODE_SCALE, G.BAR, k, GG.GAIN_QUAD, math.max(gain_w, GG.MIN_W), GG.TRACK_H * sy)
    Cmd(C.MESH, G.BAR, GG.GAIN_QUAD, r2 > r and gain_w >= GG.MIN_W, k)
    local mark, R = G.RowMark(k)
    if mark ~= nil then
      -- the bar's own rect (the track: the layer's origin, G.GAUGE W x H, y up) grown by the border's width on every
      -- side: a border that touches the bar
      local m, Q = R.margin or 0, G.GAUGE
      Cmd(C.NODE_POS, G.BAR, k, GG.GAIN_QUAD, 0, -m)
      Cmd(C.NODE_POS, G.BAR, k, GG.GAIN_QUAD, 1, m)
      Cmd(C.NODE_SCALE, G.BAR, k, GG.GAIN_QUAD, Q.W + 2 * m, Q.H + 2 * m)
      Cmd(C.MESH, G.BAR, GG.GAIN_QUAD, true, k)
    end
    local fill_w = GG.FILL_W * r
    Cmd(C.NODE_POS, G.BAR, k, GG.FILL_QUAD, 0, GG.FILL_X)
    Cmd(C.NODE_POS, G.BAR, k, GG.FILL_QUAD, 1, GG.TRACK_Y)
    Cmd(C.NODE_SCALE, G.BAR, k, GG.FILL_QUAD, math.max(fill_w, GG.MIN_W), GG.TRACK_H)
    Cmd(C.MESH, G.BAR, GG.FILL_QUAD, fill_w * sx >= GG.MIN_W, k)
  end

  function G.Bars()
    if not On() or not Exists(G.BAR) or not Exists(G.GRAPH) then
      return
    end
    local up = G.vals ~= nil and G.ptype == EVT_PPG_STATS_TYPE and Cmd(C.IS_VIS, G.GRAPH, 0) == true
    if not up then
      BarsVisible(false)
      if G.DeltaSegment ~= nil then
        pcall(G.DeltaSegment, nil)
      end
      return
    end
    local all = true
    for k = 0, 7 do
      if not Ready(G.BAR, k) then
        all = false
      end
    end
    if not all then
      return
    end
    -- no training data: one scale for the 8 rows (the training screen's)
    local scale = 0
    for g = 1, 8 do
      scale = math.max(scale, (G.vals[g] or 0) + G.Gain(g))
    end
    scale = math.max(100, math.ceil(scale * 1.15 / 50) * 50)
    local GG, Q = G.GG, G.GAUGE
    local sx, sy = Q.W / GG.TRACK_W, Q.H / GG.TRACK_H
    local segs = nil
    for g = 1, 8 do
      local k = G.GROUP_ROW[g]
      if not G.ready[G.BAR * 16 + k] then
        G.ready[G.BAR * 16 + k] = true
        Cmd(C.TRACE, G.GRAPH, 0, G.TRACE[k], true)
        for _, m in ipairs(GG.HIDE) do
          Cmd(C.MESH, G.BAR, m, false, k)
        end
        for _, p in ipairs(GG.PRIMS) do
          Cmd(GG.PRIM_VIS, G.BAR, k, p, false)
        end
        Cmd(C.SPRITE, G.BAR, GG.TX_GAUGE, GG.SP_TRACK, GG.SLOT_TRACK_QUAD, 0, k)
        Cmd(C.SPRITE, G.BAR, G.TX_OWN, CALC_CRC("evt_pp_gfill_" .. G.STAT_FILL[g]), GG.SLOT_FILL_QUAD, 0, k)
        local gs, ga = G.GainSprite(k)
        Cmd(C.SPRITE, G.BAR, ga, gs, GG.SLOT_GAIN_QUAD, 0, k)
        Cmd(C.SCALE, G.BAR, 1, 1, 1, k)
        -- the bar node scaled to the row's track size, the track's top-left on the layer's origin
        Cmd(C.NODE_POS, G.BAR, k, GG.NODE, 0, -GG.TRACK_X * sx)
        Cmd(C.NODE_POS, G.BAR, k, GG.NODE, 1, -GG.TRACK_Y * sy)
        Cmd(C.NODE_SCALE, G.BAR, k, GG.NODE, sx, sy)
      end
      local col, row = math.floor(k / 4), k % 4
      Cmd(C.POS, G.BAR, G.ROW_X0[col] + Q.X, G.ROW_Y[row] + Q.H / 2, 0, k)
      -- 2026-10-13: in the Miximax view (G.gains) the max grows by the gain and the gain is drawn past the fill in the
      -- gain colour
      local gain = G.Gain(g)
      local top = (G.tops ~= nil and G.tops[g] or scale) + gain
      local v = G.vals[g] or 0
      local r = math.max(0, math.min(1, v / top))
      local r2 = math.max(0, math.min(1, (v + gain) / top))
      G.BarQuads(k, r, r2, sx, sy)
      Cmd(C.VIS, G.BAR, k, true)
      -- a host's delta segment (G.rowDelta[g], the focused equipment item's change): the part of the fill a raise adds
      -- or the part after it a lowering removes, as a screen rect over the bar (the fill's visible band)
      local d = G.rowDelta ~= nil and G.rowDelta[g] or nil
      if d ~= nil and d ~= 0 and G.DeltaSegment ~= nil then
        local rd = d / top
        local lo, hi = rd > 0 and math.max(0, r - rd) or r, rd > 0 and r or math.min(1, r - rd)
        -- the bars hang on the chart's base, placed at G.CHART_AT: the fill's left edge on screen
        local fx = G.CHART_AT[1] + G.ROW_X0[col] + Q.X + (GG.FILL_X - GG.TRACK_X) * sx
        local ty = G.CHART_AT[2] - (G.ROW_Y[row] + Q.H / 2)
        segs = segs or {}
        segs[#segs + 1] = {fx + GG.FILL_W * sx * lo, ty, GG.FILL_W * sx * (hi - lo), Q.H, rd > 0}
      end
    end
    if G.DeltaSegment ~= nil then
      pcall(G.DeltaSegment, segs)
    end
  end

  G.TRACE = {}
  for k = 0, 7 do
    G.TRACE[k] = nil
  end
  G.TRACE[0], G.TRACE[1], G.TRACE[2], G.TRACE[3] = @crc:evt_pp_stat_bar0@, @crc:evt_pp_stat_bar1@,
    @crc:evt_pp_stat_bar2@, @crc:evt_pp_stat_bar3@
  G.TRACE[4], G.TRACE[5], G.TRACE[6], G.TRACE[7] = @crc:evt_pp_stat_bar4@, @crc:evt_pp_stat_bar5@,
    @crc:evt_pp_stat_bar6@, @crc:evt_pp_stat_bar7@

  -- the 8 values of chara status handle hdl (the radar's: 7 retail stats + Suerte)
  function G.Values(hdl, l5)
    if type(EVT_R9) == "table" and type(EVT_R9.Values) == "function" then
      local ok, v = pcall(EVT_R9.Values, hdl, l5)
      if ok and type(v) == "table" then
        return v
      end
    end
    local v = {}
    for g = 1, 8 do
      local si = G.STAT[g]
      local val = 0
      if si <= 6 and type(funcLuaCommand) == "function" then
        local ok, x = pcall(funcLuaCommand, C.CHARA, hdl, 14 + si, true, l5)
        val = ok and type(x) == "number" and x or 0
      end
      v[g] = val
    end
    local page = type(CharacterReforged) == "table" and CharacterReforged.Page or nil
    if type(page) == "table" and type(page.Stat) == "function" then
      v[8] = page.Stat(hdl, 8) or 0     -- Suerte: the page slot character_reforged.page_stat, else Character Reforged's
    end
    return v
  end
