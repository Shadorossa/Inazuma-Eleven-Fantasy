-- VRFW route_nodes BEGIN
-- VR-Framework [[route_node]]: optional side nodes of the Chronicle board (docs/game/modes/chronicle-side-branches.md,
-- docs/framework/route-board.md). Any mod declares them (team type); the framework draws them, with or without
-- Inazuma Fantasy. The engine (team_engine) builds the pieces, games and road sprites; this is the one shared rule that
-- runs them:
--   * a node's save slot (271-299) that no save has used yet (nothing cleared, nothing locked) is locked like a new
--     piece of the retail board (all six difficulties);
--   * a node is OPEN once every prerequisite is won (its route-open clear, difficulty 2, or a shown difficulty of a
--     node prerequisite): its first shown difficulty is unlocked. One prerequisite also has a native unlock link
--     (retail open effect); several are opened here with the same effect (WaitPieceOpenEffect);
--   * a closed node is not drawn (no piece, no lock ring) and its road stays hidden; a node with a
--     `LockedTitle` (lockedGuide ~= 0) is drawn while closed as a retail locked piece (lock ring, its road), its
--     balloon and the Accept message show that text (what opens it; chronicle-side-branches.md §9.20);
--   * its command menu lists only its shown difficulties (VRFW_RN_Rows); a mod's «Ir al campo» reads node.field;
--   * `gates` (a node inserted before retail pieces): a gated piece opens from the node's win (native unlock link on
--     the node, moved there by the build). Saves from before the node: while the node is not won, a gated piece that
--     has nothing cleared is locked again (all six difficulties); a gated piece already played (any clear) is never
--     touched. Once the node is won, a still-locked gated piece gets its difficulty 1 unlocked (the native link does it
--     on a route-open clear; this covers a node won some other way, e.g. its Heroica only).
-- Data: CMND_VRFW_TEAM_ROUTE_NODE_COUNT / _GET, CMND_VRFW_TEAM_ROUTE_ROAD_COUNT / _GET (the team type; the legacy part
-- answers CMND_EVT_ROUTE_*). Loaded lazily, never at Lua load (only from OnInit / Step / layer callbacks).
-- API for mods (any script that has it: vs_route_town_menu, vs_route_town_command_select_menu): VRFW_RN_Load() ->
-- {nodes = {{i, piece, slot, parents, diffs, game, field, linked, idx, gates, hub, lockedGuide, pieceScale}}, bySlot, byIdx, roads}, VRFW_RN_BySlot(slot)
-- (hub = a chain hub's chain indices, 0-based; slot may be an extended slot >= 300, VRFW_RouteSlots of the menu part).
VRFW_RN = nil
VRFW_RN_DIFFS = {1, 2, 3, 4, 10, 11}
VRFW_RN_CMD = {NODE_COUNT = {1208701503, 3004181703}, NODE_GET = {3986876567, 1705651873}, ROAD_COUNT = {2601399945, 1612007537}, ROAD_GET = {2870703344, 588493510}}
VRFW_RN_CMD_CLEAR = 4034518619     -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)
VRFW_RN_CMD_LOCK = 3394595467      -- CMND_GET_CHRONICLE_LOCK_STATUS (slot, difficulty)
VRFW_RN_CMD_SET_LOCK = 1778321182  -- CMND_SET_CHRONICLE_LOCK_STATUS (slot, locked, difficulty)
VRFW_RN_CMD_PIECE_IDX = 1064555639 -- pieceId -> ok, piece index

-- loader.log lines «LUAPRINT … VRFW_RN …» (PRINT exists only under the lua_patch loader)
function VRFW_RN_Log(...)
  if PRINT ~= nil then
    pcall(PRINT, "VRFW_RN", ...)
  end
end

function VRFW_RN_Csv(s)
  local t = {}
  for x in string.gmatch(s or "", "[^,]+") do
    t[#t + 1] = tonumber(x)
  end
  return t
end

-- The team type's command, else the legacy part's: ok + its results.
function VRFW_RN_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd[1], ...))
  if r[1] and r[2] ~= nil then
    return table.unpack(r, 1, r.n)
  end
  return pcall(funcLuaCommand, cmd[2], ...)
end

function VRFW_RN_Load()
  if VRFW_RN ~= nil then
    return VRFW_RN
  end
  VRFW_RN = {nodes = {}, bySlot = {}, byIdx = {}, roads = {}}
  if VRFW_RouteSlots ~= nil then
    VRFW_RouteSlots.Install() -- extended slots (route-board.md §5): normally in already, from the script's OnInit
  end
  local ok, n = VRFW_RN_Call(VRFW_RN_CMD.NODE_COUNT)
  if not ok or type(n) ~= "number" then
    return VRFW_RN
  end
  for i = 0, n - 1 do
    local ok2, piece, slot, parents, diffs, game, field, linked, beside, path, gates, hub, lockedGuide, scalePct = VRFW_RN_Call(VRFW_RN_CMD.NODE_GET, i)
    if ok2 and type(slot) == "number" and slot > 0 then
      local node = {i = i, piece = piece, slot = slot, parents = {}, diffs = VRFW_RN_Csv(diffs), game = game, field = field, linked = linked == true, idx = -1, beside = beside, bidx = -1, path = {}, gates = VRFW_RN_Csv(type(gates) == "string" and gates or ""),
                    hub = VRFW_RN_Csv(type(hub) == "string" and hub or ""), lockedGuide = type(lockedGuide) == "number" and lockedGuide or 0,
                    pieceScale = (type(scalePct) == "number" and scalePct > 0) and scalePct / 100 or 1}
      for part in string.gmatch(type(path) == "string" and path or "", "[^;]+") do
        local x, y = string.match(part, "^([^,]+),(.+)$")
        if tonumber(x) ~= nil and tonumber(y) ~= nil then
          node.path[#node.path + 1] = {tonumber(x), tonumber(y)}
        end
      end
      if type(beside) == "number" and beside ~= 0 then
        local okB, bidx = funcLuaCommand(VRFW_RN_CMD_PIECE_IDX, beside)
        if okB and type(bidx) == "number" then
          node.bidx = bidx
        end
      end
      for part in string.gmatch(parents or "", "[^;]+") do
        local s, d = string.match(part, "^(%d+):(.*)$")
        if s ~= nil then
          node.parents[#node.parents + 1] = {slot = tonumber(s), diffs = VRFW_RN_Csv(d)}
        end
      end
      if #node.diffs == 0 then
        node.diffs = {1, 4}
      end
      local okI, idx = funcLuaCommand(VRFW_RN_CMD_PIECE_IDX, piece)
      if okI and type(idx) == "number" then
        node.idx = idx
        VRFW_RN.byIdx[idx] = node
      end
      VRFW_RN.nodes[#VRFW_RN.nodes + 1] = node
      VRFW_RN.bySlot[slot] = node
    end
  end
  local okR, nr = VRFW_RN_Call(VRFW_RN_CMD.ROAD_COUNT)
  if okR and type(nr) == "number" then
    for i = 0, nr - 1 do
      local ok3, node, sprite, x, y, w, h = VRFW_RN_Call(VRFW_RN_CMD.ROAD_GET, i)
      if ok3 and type(node) == "number" and node >= 0 and type(sprite) == "string" and sprite ~= "" and type(w) == "number" and w > 0 then
        VRFW_RN.roads[#VRFW_RN.roads + 1] = {node = node, sprite = sprite, x = x, y = y, w = w, h = h}
      end
    end
  end
  VRFW_RN_Log("load", "nodes", #VRFW_RN.nodes, "roads", #VRFW_RN.roads)
  for i = 1, #VRFW_RN.nodes do
    local nd = VRFW_RN.nodes[i]
    VRFW_RN_Log("node", i - 1, "piece", nd.piece, "idx", nd.idx, "slot", nd.slot, "linked", tostring(nd.linked), "gates", #nd.gates, "scale", nd.pieceScale)
  end
  return VRFW_RN
end

-- `PieceScale` (a small point node): the board piece instance `inst` of the piece layer, now showing piece index
-- `idx`, is drawn at its node's scale (base and crest); any other piece on that instance at 1 (instances are reused
-- while the map scrolls). Called at the top of UpdateTownMapPiece; a scale is only sent when it changes.
VRFW_RN_PIECE_LAYER = 4002479583 --[[vsroute00_05_town_map_piece]]
VRFW_RN_PIECE_SCALES = {}
function VRFW_RN_PieceScale(layer, inst, idx)
  if layer ~= VRFW_RN_PIECE_LAYER or type(inst) ~= "number" then
    return
  end
  local s = 1
  if type(idx) == "number" and idx ~= -1 then
    local node = VRFW_RN_Load().byIdx[idx]
    if node ~= nil and node.pieceScale ~= nil then
      s = node.pieceScale
    end
  end
  if (VRFW_RN_PIECE_SCALES[inst] or 1) == s then
    return
  end
  VRFW_RN_PIECE_SCALES[inst] = s
  pcall(funcLuaMenuCommand, 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE?]], layer, s, s, 1, inst)
  VRFW_RN_Log("piece scale", "inst", inst, "piece", idx, "scale", s)
end

function VRFW_RN_Clear(slot, d)
  return funcLuaCommand(VRFW_RN_CMD_CLEAR, slot, d) == true
end

function VRFW_RN_Locked(slot, d)
  return funcLuaCommand(VRFW_RN_CMD_LOCK, slot, d) == true
end

function VRFW_RN_Ready(node)
  for i = 1, #node.parents do
    local p, won = node.parents[i], false
    for k = 1, #p.diffs do
      if VRFW_RN_Clear(p.slot, p.diffs[k]) then
        won = true
        break
      end
    end
    if not won then
      return false
    end
  end
  return true
end

function VRFW_RN_IsOpen(node)
  for i = 1, #VRFW_RN_DIFFS do
    if not VRFW_RN_Locked(node.slot, VRFW_RN_DIFFS[i]) then
      return true
    end
  end
  return false
end

-- Drawn (piece and road): its prerequisites are won and a difficulty is open (also right on a first board visit,
-- before VRFW_RN_Sync has initialised a never-used slot).
function VRFW_RN_Shown(node)
  return VRFW_RN_IsOpen(node) and VRFW_RN_Ready(node)
end

-- A node piece that must not be drawn yet (closed; a node with a `LockedTitle` is drawn locked). Unknown pieces: false.
function VRFW_RN_Hidden(idx)
  if idx == nil or idx < 0 then
    return false
  end
  local node = VRFW_RN_Load().byIdx[idx]
  return node ~= nil and node.lockedGuide == 0 and not VRFW_RN_Shown(node)
end

-- The board balloon's text id of piece `idx` (UpdatePieceAtcBalloon): a closed node drawn locked shows its
-- `LockedTitle` (what opens it); anything else keeps `id` (the piece's guideTextId).
function VRFW_RN_GuideText(idx, id)
  local node = idx ~= nil and idx >= 0 and VRFW_RN_Load().byIdx[idx] or nil
  if node ~= nil and node.lockedGuide ~= 0 and not VRFW_RN_Shown(node) then
    return node.lockedGuide
  end
  return id
end

-- Accept on a locked piece (retail OnEnter, the lock message `s`): a closed node drawn locked says its `LockedTitle`
-- instead of the retail «beat the previous square's route-unlock battle» (slot = the piece's save slot).
function VRFW_RN_LockedText(slot, s)
  local node = VRFW_RN_BySlot(slot)
  if node ~= nil and node.lockedGuide ~= 0 and not VRFW_RN_Shown(node) then
    local ok, t = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], node.lockedGuide)
    if ok and type(t) == "string" and t ~= "" then
      return t
    end
  end
  return s
end

-- The node of a save slot (command menu: the piece's statusFlagIndex), or nil.
function VRFW_RN_BySlot(slot)
  if slot == nil then
    return nil
  end
  return VRFW_RN_Load().bySlot[slot]
end

-- The board's Accept on a piece (retail OnEnter) refuses a piece whose difficulty 1 (Crónica) is locked with the retail
-- message «Necesitas superar la batalla de desbloqueo de ruta de la casilla anterior…». A shown node may have no
-- Crónica at all (Heroica-only side nodes, chain «C» pieces: their difficulty 1 stays locked), so a shown node is
-- enterable whatever its difficulty 1 says (its command menu / chain board lists what it has). Unknown slots: false.
function VRFW_RN_Enterable(slot)
  local node = VRFW_RN_BySlot(slot)
  return node ~= nil and VRFW_RN_Shown(node)
end

-- A node is WON (for its gated pieces) when its route-open clear (2) or one of its shown difficulties is cleared.
function VRFW_RN_Won(node)
  if VRFW_RN_Clear(node.slot, 2) then
    return true
  end
  for k = 1, #node.diffs do
    if VRFW_RN_Clear(node.slot, node.diffs[k]) then
      return true
    end
  end
  return false
end

-- The pieces a node gates (`gates`): locked while the node is not won and they have nothing cleared; difficulty 1
-- unlocked once it is won (they open from its win, not from their retail predecessor). Returns true when one opened.
function VRFW_RN_SyncGates(node, effect)
  if #node.gates == 0 then
    return false
  end
  local won = VRFW_RN_Won(node)
  local opened = false
  for g = 1, #node.gates do
    local gs = node.gates[g]
    local played, open = false, false
    for k = 1, #VRFW_RN_DIFFS do
      local d = VRFW_RN_DIFFS[k]
      if VRFW_RN_Clear(gs, d) then
        played = true
      end
      if not VRFW_RN_Locked(gs, d) then
        open = true
      end
    end
    if not played then
      if not won and open then
        for k = 1, #VRFW_RN_DIFFS do
          funcLuaCommand(VRFW_RN_CMD_SET_LOCK, gs, true, VRFW_RN_DIFFS[k])
        end
        VRFW_RN_Log("gate", "slot", gs, "locked until node", node.slot, "is won")
      elseif won and not open then
        funcLuaCommand(VRFW_RN_CMD_SET_LOCK, gs, false, 1)
        opened = true
        VRFW_RN_Log("gate", "slot", gs, "opened by node", node.slot, "effect", tostring(effect))
      end
    end
  end
  return opened
end

-- Save state of every node: first use of the slot -> locked; open (prerequisites won) -> its first shown difficulty
-- unlocked; its gated pieces (VRFW_RN_SyncGates). `effect`: nodes without a native link that open now play the retail open effect (inside the clear-effect
-- coroutine only). Returns true when a node opened.
function VRFW_RN_Sync(effect)
  local rn = VRFW_RN_Load()
  local opened = false
  for i = 1, #rn.nodes do
    local node = rn.nodes[i]
    local any_clear, all_open = false, true
    for k = 1, #VRFW_RN_DIFFS do
      local d = VRFW_RN_DIFFS[k]
      if VRFW_RN_Clear(node.slot, d) then
        any_clear = true
      end
      if VRFW_RN_Locked(node.slot, d) then
        all_open = false
      end
    end
    if not any_clear and all_open then
      for k = 1, #VRFW_RN_DIFFS do
        funcLuaCommand(VRFW_RN_CMD_SET_LOCK, node.slot, true, VRFW_RN_DIFFS[k])
      end
    end
    if VRFW_RN_Ready(node) then
      local was_open = VRFW_RN_IsOpen(node)
      if not was_open and effect and node.idx >= 0 and WaitPieceOpenEffect ~= nil then
        WaitPieceOpenEffect({node.idx}, {true})
      end
      local shown = false
      for k = 1, #node.diffs do
        if not VRFW_RN_Locked(node.slot, node.diffs[k]) then
          shown = true
        end
      end
      if not shown then
        funcLuaCommand(VRFW_RN_CMD_SET_LOCK, node.slot, false, node.diffs[1])
      end
      if not was_open then
        opened = true
        VRFW_RN_Log("open", "slot", node.slot, "idx", node.idx, "effect", tostring(effect))
      end
    end
    if VRFW_RN_SyncGates(node, effect) then
      opened = true
    end
  end
  return opened
end

-- The nodes' roads, drawn at RUN TIME above the map tiles (2026-10-12; the per-combination tile copies are gone): each
-- road is one overlay sprite of the emblem atlas (team type: CMND_VRFW_TEAM_ROUTE_ROAD_GET -> node, sprite, centre x / y
-- in the route map layer, w, h) shown on an instance of the layer vrfw_route_road (framework menus\route_roads.toml: a
-- one-quad object attached to the map's _pos_base01 like the pieces, so it pans and zooms with the map; priority 50,
-- above the tiles, under the pieces). An instance is visible while its node is shown (open, or drawn locked); a node
-- that opens while the board is shown gets its road at once (VRFW_RN_Reveal). Main board only. Cost: one quad per road.
VRFW_RN_ROAD_LAYER = 922325769 --[[vrfw_route_road]]
VRFW_RN_ROAD_SHEET = 1895945654 --[[#/menu/200_icon/01_icon_emblem/vsroute/icon_vsroute_emblem/vsroute_emblem.g4tx]]
VRFW_RN_ROAD_NODE = 1909474081 --[[icon_new01: the quad's sprite node]]
VRFW_RN_ROAD_QUAD = 36 -- the quad's size in px (cmn01_10 _icon_new01, centred on the layer's origin)
VRFW_RN_ROAD_SHOWN = {}

function VRFW_RN_MainBoard()
  return n9 == nil or n9 == 0 or n9 == 364708540 --[[vs_route_town_menu]]
end

-- The roads' instances on the board (the layer's created count; nil = the layer is not there).
function VRFW_RN_RoadPool()
  local ok, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], VRFW_RN_ROAD_LAYER)
  if ok and type(n) == "number" and n > 0 then
    return n
  end
  return nil
end

-- Instance `i` (0-based) shows road `road` (nil / not shown: hidden; the quad's own sprite is the retail «new» badge).
function VRFW_RN_RoadSet(i, road, shown)
  if road == nil or not shown then
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], VRFW_RN_ROAD_LAYER, i, false)
    VRFW_RN_ROAD_SHOWN[i] = false
    return
  end
  local q = VRFW_RN_ROAD_QUAD
  pcall(funcLuaMenuCommand, 558735651, VRFW_RN_ROAD_LAYER, VRFW_RN_ROAD_SHEET, CALC_CRC(road.sprite), VRFW_RN_ROAD_NODE, 0, i)
  pcall(funcLuaMenuCommand, 1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], VRFW_RN_ROAD_LAYER, road.x, road.y, 0, i)
  pcall(funcLuaMenuCommand, 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE?]], VRFW_RN_ROAD_LAYER, road.w / q, road.h / q, 1, i)
  pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], VRFW_RN_ROAD_LAYER, i, true)
  if VRFW_RN_ROAD_SHOWN[i] ~= true then
    VRFW_RN_Log("road", i, "node", road.node, road.sprite, "at", road.x, road.y, "size", road.w, road.h)
  end
  VRFW_RN_ROAD_SHOWN[i] = true
end

-- Whether road `road` is drawn: its node is shown, or drawn locked (LockedTitle), or is `extra` (being revealed).
function VRFW_RN_RoadShown(road, extra)
  local node = VRFW_RN_Load().nodes[road.node + 1]
  return node ~= nil and (node == extra or VRFW_RN_Shown(node) or node.lockedGuide ~= 0)
end

-- Set up instance `i` of the road layer (OnSetupLayer).
function VRFW_RN_RoadSetup(i)
  if not VRFW_RN_MainBoard() then
    return
  end
  local road = VRFW_RN_Load().roads[i + 1]
  VRFW_RN_RoadSet(i, road, road ~= nil and VRFW_RN_RoadShown(road))
end

-- Every road instance again (the map opened; nodes opened in this visit). `extra`: a node counted as shown.
function VRFW_RN_Roads(extra)
  if not VRFW_RN_MainBoard() then
    return
  end
  local rn = VRFW_RN_Load()
  local pool = VRFW_RN_RoadPool()
  if pool == nil then
    if #rn.roads > 0 then
      VRFW_RN_Log("roads: the layer vrfw_route_road is not on this board (menus route_roads.toml not built?)", #rn.roads, "roads not drawn")
    end
    return
  end
  if #rn.roads > pool then
    VRFW_RN_Log("WARN roads:", #rn.roads, "roads, the layer has", pool, "instances: the last", #rn.roads - pool, "are not drawn")
  end
  for i = 0, pool - 1 do
    local road = rn.roads[i + 1]
    VRFW_RN_RoadSet(i, road, road ~= nil and VRFW_RN_RoadShown(road, extra))
  end
end

-- A node opens while the board is shown (its unlock effect): its road shows at once (the instance is made visible).
function VRFW_RN_Reveal(node)
  if not VRFW_RN_MainBoard() then
    return
  end
  local rn = VRFW_RN_Load()
  local pool = VRFW_RN_RoadPool() or 0
  for k = 1, math.min(#rn.roads, pool) do
    local road = rn.roads[k]
    if rn.nodes[road.node + 1] == node then
      VRFW_RN_Log("reveal", "node", road.node, road.sprite)
      VRFW_RN_RoadSet(k - 1, road, true)
    end
  end
end

-- The retail open effect (WaitPieceOpenEffect: native unlock links, and the nodes VRFW_RN_Sync opens): the roads of the
-- route nodes among the pieces it opens show as they appear.
function VRFW_RN_RevealPieces(idxs)
  if idxs == nil then
    return
  end
  local rn = VRFW_RN_Load()
  for i = 1, #idxs do
    local node = rn.byIdx[idxs[i]]
    if node ~= nil and not VRFW_RN_IsOpen(node) then
      VRFW_RN_Reveal(node)
    end
  end
end

-- The caravan's rails (Nacho 2026-10-09: the bus drove straight from Big Waves to C1 across the houses). The game's
-- move path between two pieces (vs_route_town_menu: t9 = funcLuaMenuVSRouteTownCommand(111188339, from, to), a flat
-- list x1, y1, x2, y2, … of the map layer's positions) joins the pieces of the d-pad graph with straight lines, so a
-- node's own road (a fork from the middle of another road, bends) was not followed. VRFW_RN_Path puts every node's
-- rail (the team type's `path`: beside, road_from, via, node, grid units) in place of a straight beside <-> node leg,
-- then drops a piece the bus would pass and come back to (a fork point on the road beside it: trials -> Big Waves ->
-- fork -> C1 becomes trials -> fork -> C1). Grid -> layer: a per-axis linear fit of the nodes' and their beside
-- pieces' positions (GetTownMapResourcePiecePos), made once. Generic: every [[VRFW.RouteNode]] with a fork or bends;
-- a straight road (no road_from / via) keeps the game's path. Kill switch VRFW_RN_RAILS.
VRFW_RN_RAILS = true
VRFW_RN_FIT = nil
VRFW_RN_EPS = 3

function VRFW_RN_LayerPos(idx)
  local ok, x, y = pcall(funcLuaMenuVSRouteTownCommand, 1731060169, idx)
  if ok and type(x) == "number" and type(y) == "number" then
    return x, y
  end
  return nil
end

-- per axis: layer = o + k * grid, least squares over the nodes' and beside pieces' positions (nil: not enough data)
function VRFW_RN_Fit()
  if VRFW_RN_FIT ~= nil then
    return VRFW_RN_FIT or nil
  end
  local pts = {}
  for _, node in ipairs(VRFW_RN_Load().nodes) do
    local p = node.path
    if #p >= 2 then
      local ends = {{node.bidx, p[1]}, {node.idx, p[#p]}}
      for _, e in ipairs(ends) do
        if e[1] >= 0 then
          local lx, ly = VRFW_RN_LayerPos(e[1])
          if lx ~= nil then
            pts[#pts + 1] = {e[2][1], e[2][2], lx, ly}
          end
        end
      end
    end
  end
  local function axis(gi, li)
    local n, sg, sl, sgg, sgl = #pts, 0, 0, 0, 0
    for _, q in ipairs(pts) do
      sg, sl, sgg, sgl = sg + q[gi], sl + q[li], sgg + q[gi] * q[gi], sgl + q[gi] * q[li]
    end
    local den = n * sgg - sg * sg
    if n < 2 or math.abs(den) < 1e-6 then
      return nil
    end
    local k = (n * sgl - sg * sl) / den
    return {(sl - k * sg) / n, k}
  end
  local fx, fy = axis(1, 3), axis(2, 4)
  if fx == nil or fy == nil then
    VRFW_RN_FIT = false
    VRFW_RN_Log("rails: no grid -> layer fit (points", #pts, ")")
    return nil
  end
  VRFW_RN_FIT = {fx, fy}
  VRFW_RN_Log("rails: fit x", fx[1], fx[2], "y", fy[1], fy[2], "points", #pts)
  return VRFW_RN_FIT
end

function VRFW_RN_Near(a, b)
  return math.abs(a[1] - b[1]) <= VRFW_RN_EPS and math.abs(a[2] - b[2]) <= VRFW_RN_EPS
end

-- c on the segment a-b (strictly between, within VRFW_RN_EPS of the line)
function VRFW_RN_On(c, a, b)
  local dx, dy = b[1] - a[1], b[2] - a[2]
  local l2 = dx * dx + dy * dy
  if l2 < 1 then
    return false
  end
  local t = ((c[1] - a[1]) * dx + (c[2] - a[2]) * dy) / l2
  if t <= 0.01 or t >= 0.99 then
    return false
  end
  local px, py = a[1] + t * dx - c[1], a[2] + t * dy - c[2]
  return px * px + py * py <= VRFW_RN_EPS * VRFW_RN_EPS * 4
end

function VRFW_RN_Path(t)
  if not VRFW_RN_RAILS or type(t) ~= "table" or #t < 4 then
    return t
  end
  local ok, out = pcall(function()
    local fit = VRFW_RN_Fit()
    if fit == nil then
      return t
    end
    local P = {}
    for k = 1, #t - 1, 2 do
      P[#P + 1] = {t[k], t[k + 1]}
    end
    local changed = false
    for _, node in ipairs(VRFW_RN_Load().nodes) do
      local p = node.path
      if #p >= 3 and node.idx >= 0 and node.bidx >= 0 then
        local bx, by = VRFW_RN_LayerPos(node.bidx)
        local nx, ny = VRFW_RN_LayerPos(node.idx)
        if bx ~= nil and nx ~= nil then
          local B, N = {bx, by}, {nx, ny}
          local inner = {}
          for k = 2, #p - 1 do
            inner[#inner + 1] = {fit[1][1] + fit[1][2] * p[k][1], fit[2][1] + fit[2][2] * p[k][2]}
          end
          local Q = {}
          for k = 1, #P do
            Q[#Q + 1] = P[k]
            local nxt = P[k + 1]
            if nxt ~= nil and VRFW_RN_Near(P[k], B) and VRFW_RN_Near(nxt, N) then
              for j = 1, #inner do
                Q[#Q + 1] = inner[j]
              end
              changed = true
            elseif nxt ~= nil and VRFW_RN_Near(P[k], N) and VRFW_RN_Near(nxt, B) then
              for j = #inner, 1, -1 do
                Q[#Q + 1] = inner[j]
              end
              changed = true
            end
          end
          P = Q
        end
      end
    end
    if not changed then
      return t
    end
    -- a piece passed and come back from: (a, b, c) with c on a-b or a on b-c -> a, c
    local k = 1
    while k + 2 <= #P do
      if VRFW_RN_On(P[k + 2], P[k], P[k + 1]) or VRFW_RN_On(P[k], P[k + 1], P[k + 2]) then
        table.remove(P, k + 1)
      else
        k = k + 1
      end
    end
    local r = {}
    for _, q in ipairs(P) do
      r[#r + 1] = q[1]
      r[#r + 1] = q[2]
    end
    VRFW_RN_Log("rails: path", #t / 2, "->", #P, "points")
    return r
  end)
  if ok and type(out) == "table" then
    return out
  end
  VRFW_RN_Log("rails: error", tostring(out))
  return t
end

-- The board cursor follows the same rails (Nacho 2026-10-09: the green cursor still slid straight from Big Waves to
-- C1). The cursor stays in the middle of the screen while the map scrolls to the next piece: the game's scroll
-- (UpdateMapScroll -> CMND_SCROLL_MAP) moves the map on the straight line and reports each frame's position through
-- UpdateScrollPos(x, y) (n5 = -x, n6 = -y; a piece P is centred at x = n23 * P, the map's zoom). VRFW_RN_ScrollStart
-- (before the scroll) takes the rail of that leg (VRFW_RN_Path of the two pieces' positions) when it has bends, and
-- VRFW_RN_ScrollRail moves each reported position from the straight line onto the rail at the same fraction of the
-- way (arc length). Off the expected line (a free-cursor scroll, another zoom rule): left alone. Kill switch:
-- VRFW_RN_RAILS.
VRFW_RN_SCROLL = nil

function VRFW_RN_ScrollStart(target)
  VRFW_RN_SCROLL = nil
  if not VRFW_RN_RAILS or n11 == nil or n11 < 0 or target == nil or target < 0 or n11 == target then
    return
  end
  local ok, err = pcall(function()
    local sx, sy = VRFW_RN_LayerPos(n11)
    local tx, ty = VRFW_RN_LayerPos(target)
    if sx == nil or tx == nil then
      return
    end
    local rail = VRFW_RN_Path({sx, sy, tx, ty})
    if type(rail) ~= "table" or #rail <= 4 then
      return
    end
    local z = n23 or 1
    local S = {-n5, -n6}
    local pts, len = {}, {0}
    for k = 1, #rail - 1, 2 do
      pts[#pts + 1] = {S[1] + z * (rail[k] - sx), S[2] + z * (rail[k + 1] - sy)}
    end
    for k = 2, #pts do
      local dx, dy = pts[k][1] - pts[k - 1][1], pts[k][2] - pts[k - 1][2]
      len[k] = len[k - 1] + math.sqrt(dx * dx + dy * dy)
    end
    local T = {S[1] + z * (tx - sx), S[2] + z * (ty - sy)}
    if len[#pts] < 1 then
      return
    end
    VRFW_RN_SCROLL = {S = S, T = T, pts = pts, len = len}
    VRFW_RN_Log("rails: scroll", n11, "->", target, "points", #pts)
  end)
  if not ok then
    VRFW_RN_Log("rails: scroll error", tostring(err))
  end
end

function VRFW_RN_ScrollEnd()
  VRFW_RN_SCROLL = nil
end

function VRFW_RN_ScrollRail(x, y)
  local r = VRFW_RN_SCROLL
  if r == nil or type(x) ~= "number" or type(y) ~= "number" then
    return x, y
  end
  local dx, dy = r.T[1] - r.S[1], r.T[2] - r.S[2]
  local l2 = dx * dx + dy * dy
  if l2 < 1 then
    return x, y
  end
  local t = ((x - r.S[1]) * dx + (y - r.S[2]) * dy) / l2
  local ox, oy = r.S[1] + t * dx - x, r.S[2] + t * dy - y
  if ox * ox + oy * oy > l2 * 0.01 + 16 then
    VRFW_RN_Log("rails: scroll off the line, left alone")
    VRFW_RN_SCROLL = nil
    return x, y
  end
  if t <= 0 then
    return r.pts[1][1], r.pts[1][2]
  end
  if t >= 1 then
    return r.pts[#r.pts][1], r.pts[#r.pts][2]
  end
  local want = t * r.len[#r.pts]
  for k = 2, #r.pts do
    if want <= r.len[k] then
      local seg = r.len[k] - r.len[k - 1]
      local f = seg > 0 and (want - r.len[k - 1]) / seg or 1
      return r.pts[k - 1][1] + f * (r.pts[k][1] - r.pts[k - 1][1]), r.pts[k - 1][2] + f * (r.pts[k][2] - r.pts[k - 1][2])
    end
  end
  return r.pts[#r.pts][1], r.pts[#r.pts][2]
end

-- The command menu's rows of a piece (VRFW_RBC_Rows of graft route_board, after the mods' own filters): a node lists
-- only its shown difficulties (the rows kept when none of them is listed).
function VRFW_RN_Rows(rows, slot)
  local node = VRFW_RN_BySlot(slot)
  if node == nil or rows == nil then
    return rows
  end
  local keep = {}
  for i = 1, #rows do
    for k = 1, #node.diffs do
      if rows[i].difficultyType == node.diffs[k] then
        keep[#keep + 1] = rows[i]
      end
    end
  end
  if #keep > 0 then
    return keep
  end
  return rows
end
-- VRFW route_nodes END
