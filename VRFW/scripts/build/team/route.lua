-- `[[VRFW.RouteNode]]`: optional side nodes of the Chronicle board (docs/game/modes/chronicle-side-branches.md; was
-- team_engine route.rs). A node is a new piece of chronicle_vs_route_config (a dead end), a game cloned from a board
-- game against the node's team, and a road: an overlay sprite the board draws above the map tiles while the node is
-- shown (the native part VRFW.team.node_roads: the board's art; no tile is copied), its board icon and the road sprites
-- on the emblem atlas (VRFW.team.node_icons).
local T = require "lib/team_util"
local TC = require "team/tc"
local R = {}

local GAME_DIR = "data/common/gamedata/soccer/game/"
local ICON_ATLAS_GAME = "#/menu/200_icon/01_icon_emblem/vsroute/icon_vsroute_emblem/vsroute_emblem.g4tx"
local PRIZE_PREFIX = "data/common/gamedata/soccer/soccer_prize_config_"
-- a node's difficulties when it declares none: Crónica and Heroica
local ROUTE_NODE_DEFAULT = { 1, 4 }
local BOARD_DIFFS = { [1] = true, [2] = true, [3] = true, [4] = true, [10] = true, [11] = true }

local DIRS = { "LU", "LD", "RU", "RD" }
local DIR_FIELD = { LU = "moveRouteLU", LD = "moveRouteLD", RU = "moveRouteRU", RD = "moveRouteRD" }
local OPPOSITE = { LU = "RD", RD = "LU", LD = "RU", RU = "LD" }
local STEP = { LU = { -1, 1 }, LD = { -1, -1 }, RU = { 1, 1 }, RD = { 1, -1 } }

-- A node's road on the board's iso grid: the retail roads only run along the board's two axes (grid steps (±1, ±1)),
-- so every segment of `pts` (grid points: start, bends, node) whose |dx| and |dy| differ gets ONE bend that splits it
-- into two axis legs (an L; consecutive ones make a stair). The first leg keeps the axis the road arrives on (`dir`,
-- beside's d-pad direction, for the first segment; the previous leg's axis after that), like the retail roads that
-- leave a pad along its move direction and turn once. Returns the new point list and the bends added.
local function iso_route(pts, dir)
  local out, added = { { pts[1][1], pts[1][2] } }, {}
  local ax = STEP[dir] or { 1, 1 }
  local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
  for k = 2, #pts do
    local p, q = out[#out], pts[k]
    local dx, dy = q[1] - p[1], q[2] - p[2]
    if math.abs(math.abs(dx) - math.abs(dy)) > 0.05 then
      local c
      if ax[1] * ax[2] > 0 then
        local s = (dx + dy) / 2 -- along (1, 1): dx = s + t, dy = s - t
        c = { r3(p[1] + s), r3(p[2] + s) }
      else
        local t = (dx - dy) / 2 -- along (1, -1)
        c = { r3(p[1] + t), r3(p[2] - t) }
      end
      out[#out + 1] = c
      added[#added + 1] = c
    end
    out[#out + 1] = { q[1], q[2] }
    local a, b = out[#out][1] - out[#out - 1][1], out[#out][2] - out[#out - 1][2]
    if math.abs(a) > 1e-6 then ax = { a > 0 and 1 or -1, b > 0 and 1 or -1 } end
  end
  return out, added
end
R.iso_route = iso_route

-- the sprite a node's own `icon` PNG is packed as
function R.node_icon_sprite(name)
  return "evt_rn_" .. name .. "_t01"
end

-- field indices of the route lists, or nil, err
function R.fields(r)
  local F = {}
  local function list(k, n)
    local l, e = r:list(n)
    if not l then error({ e }) end
    F[k] = l
  end
  local function field(k, l, n)
    local f, e = r:field(F[l], n)
    if not f then error({ e }) end
    F[k] = f
  end
  local ok, err = pcall(function()
    list("pl", "m_pieceInfoList")
    list("ml", "m_pieceMoveRouteInfoList")
    list("ul", "m_unlockPieceInfoList")
    list("il", "m_pieceIconInfoList")
    list("rl", "m_chronicleVsRouteInfoList")
    list("el", "m_pieceEventInfoList")
    field("p_id", "pl", "pieceId")
    field("p_ev", "pl", "eventType")
    field("p_sfi", "pl", "statusFlagIndex")
    field("p_pos", "pl", "piecePos")
    field("p_icon", "pl", "IconInfoId")
    field("p_icon_idx", "pl", "IconInfoIndex")
    field("p_move", "pl", "moveRouteInfo")
    field("p_unlock", "pl", "unlockPieceInfo")
    field("p_event", "pl", "eventInfoRef")
    field("p_new", "pl", "showNewRouteEffect")
    field("p_gate_key", "pl", "canObtainGateKey")
    field("p_gate_use", "pl", "gateKeyUsePieceId")
    field("p_gate_open", "pl", "gateOpenInfoId")
    field("p_open_event", "pl", "openEvent")
    field("p_need_update", "pl", "needUpdate")
    field("p_upd_lock", "pl", "updateLockPieceId")
    field("p_locked_flag", "pl", "lockedGlobalBitFlagId")
    field("p_guide", "pl", "guideTextId")
    F.p_list_tab = r:field(F.pl, "opponentListTab")   -- optional (nil on older tables)
    F.p_conds = {}
    for _, n in ipairs { "condition", "showCondition", "openCondition" } do
      local f = r:field(F.pl, n)
      if f then F.p_conds[#F.p_conds + 1] = f end
    end
    field("u_id", "ul", "unlockPieceId")
    field("u_ev", "ul", "unlockEvent")
    field("i_id", "il", "id")
    field("i_name", "il", "textureName")
    field("i_path", "il", "texturePath")
    field("r_slice", "rl", "pieceInfo")
    field("r_map", "rl", "routeMapType")
    field("e_game", "el", "paramCrc1")
  end)
  if not ok then
    if type(err) == "table" then return nil, err[1] end
    return nil, tostring(err)
  end
  F.e_list = F.el
  return F
end

-- the `statusFlagIndex` of every piece of chronicle_vs_route_config `r` (a set)
function R.board_slots(r)
  local F, e = R.fields(r)
  if not F then return nil, e end
  local set = {}
  for _, x in ipairs(r:col_u32(F.pl, F.p_sfi)) do
    if x then set[x] = true end
  end
  return set
end

-- `{:?}` of a list of strings
local function dbg_strs(a)
  local p = {}
  for i, s in ipairs(a) do p[i] = T.dbg_str(s) end
  return "[" .. table.concat(p, ", ") .. "]"
end

function R.install(X)
  X.board_slots = R.board_slots

  local function rf()
    local r, e = X.route()
    if not r then return nil, e end
    local F, e2 = R.fields(r)
    if not F then return nil, e2 end
    return r, F
  end

  function X.piece_index(id)
    local r, F = rf()
    if not r then return nil, F end
    return X.piece_row(r, F.pl, F.p_id, id) or false
  end

  -- (route, start, count) of the route slice holding piece position `i`; false = none
  function X.route_of(i)
    local r, F = rf()
    if not r then return nil, F end
    for k = 0, r:len(F.rl) - 1 do
      local s, n = r:tuple(F.rl, k, F.r_slice)
      if s ~= nil and i >= s and i < s + n then return { k, s, n } end
    end
    return false
  end

  -- the board piece (inside a route slice, a match: eventType 0 / 5) whose event slice plays game `gid`; false = none
  function X.piece_of_game(gid)
    local r, F = rf()
    if not r then return nil, F end
    for k = 0, r:len(F.rl) - 1 do
      local s, n = r:tuple(F.rl, k, F.r_slice)
      if s ~= nil then
        for i = s, s + n - 1 do
          local ev = r:u32(F.pl, i, F.p_ev)
          if ev == 0 or ev == 5 then
            local a, b = r:tuple(F.pl, i, F.p_event)
            if a == nil then a, b = 0, 0 end
            for j = a, a + b - 1 do
              if r:u32(F.el, j, F.e_game) == gid then return r:u32(F.pl, i, F.p_id) or false end
            end
          end
        end
      end
    end
    return false
  end

  -- the first game of piece `id`'s event slice; false = none
  function X.game_of_piece(id)
    local i, e = X.piece_index(id)
    if i == nil then return nil, e end
    if i == false then return false end
    local r, F = rf()
    local a, b = r:tuple(F.pl, i, F.p_event)
    if a == nil then a, b = 0, 0 end
    if b > 0 then return r:u32(F.el, a, F.e_game) or false end
    return false
  end

  -- a piece reference: a route node made before, a board game (the piece that plays it), or a piece key / id
  function X.node_piece_ref(s, m, made)
    s = T.trim(s)
    for _, n in ipairs(made) do
      if n.key == s or n.key == m .. "." .. s then return n.piece end
    end
    local gid = VRFW.crc32(s)
    local g, ge = X.games()
    if not g then return nil, ge end
    if X.gcache().by_id[gid] then
      local p, e = X.piece_of_game(gid)
      if p == nil then return nil, e end
      if p == false then return nil, "`" .. s .. "`: no board piece plays that game" end
      return p
    end
    local id = VRFW.ids.parse(s)
    local i, e = X.piece_index(id)
    if i == nil then return nil, e end
    if i ~= false then return id end
    return nil, "`" .. s .. "` is not a route node of this build, a board game or a piece of chronicle_vs_route_config"
  end

  function X.game_name(gid)
    local g, e = X.games()
    if not g then return nil, e end
    local x = X.gcache().by_id[gid]
    return x and x.name or false
  end

  -- game `gid` → { [difficulty] = entry position } and its sorted difficulties
  function X.game_rows(gid)
    local g, e = X.games()
    if not g then return nil, e end
    local x = X.gcache().by_id[gid]
    if not x then return nil, "game " .. T.hex(gid) .. " is not in soccer_game_config" end
    local map = {}
    for _, i in ipairs(X.grows(x)) do
      local d = g:int(i, X.SG.D_DIFF)
      if d then map[d] = i end
    end
    return map, T.keys(map)
  end

  -- the emblem item (id), its key (`em010012` or nil) and the kit of team `tid`
  function X.emblem_and_kit(tid)
    local t = X.tc:find(tid)
    if t == nil then return nil, "team " .. T.hex(tid) .. " is not in team_config" end
    local emblem = TC.uint(X.tc:info(t), X.TI.EMBLEM) or 0
    local kit = TC.uint(X.tc:info(t), X.TI.KIT) or 0
    local item, e = X.item()
    if not item then return nil, e end
    local i = item:find("ITEM_EMBLEM_INFO", X.EM.ID, emblem)
    local key = i and item:str(i, X.EM.KEY) or nil
    return { emblem = emblem, key = key, kit = kit }
  end

  -- the kit item (ITEM_FASHION_INFO, col 18 = uniform) of uniform `kit`; false = none
  function X.kit_item(kit)
    local item, e = X.item()
    if not item then return nil, e end
    if kit == 0 then return false end
    for _, i in ipairs(item:rows("ITEM_FASHION_INFO")) do
      if item:uint(i, X.FASHION_KIT) == kit then return item:uint(i, 0) or false end
    end
    return false
  end

  -- the save slots a new node may use (above the GAME's own board pieces, below the flags' size) and the taken ones
  function X.slot_range()
    local ret = X.retail()
    if not ret.route_slots then return nil, "the game's chronicle_vs_route_config: " .. ret.route_slots_err end
    local r, e = X.route()
    if not r then return nil, e end
    local taken, e2 = R.board_slots(r)
    if not taken then return nil, e2 end
    local lo, hi = VRFW.ids.free_above(ret.route_slots, X.D.route_nodes.slot_limit)
    return { lo = lo, hi = hi, taken = taken }
  end

  -- an EXTENDED slot (docs/framework/route-board.md §5): slot_limit .. ext_slot_limit - 1, kept by the framework's save
  -- service (graft route_nodes' VRFW_RouteSlots); its piece's retail statusFlagIndex is the shared proxy_slot
  function X.ext_slot(slot)
    local D = X.D.route_nodes
    return slot >= D.slot_limit and slot < (D.ext_slot_limit or D.slot_limit)
  end

  -- the statusFlagIndex written into a node's piece row: its own slot, or the proxy for an extended slot
  function X.piece_slot(slot)
    if X.ext_slot(slot) then return X.D.route_nodes.proxy_slot end
    return slot
  end

  -- the save slot of a piece for the board rule: a node made in this build answers its own (an extended slot's piece
  -- row holds the proxy), any other piece its row's statusFlagIndex
  function X.slot_of_piece(p, sfi, made)
    for _, n in ipairs(made) do
      if n.piece == p then return n.slot end
    end
    return sfi
  end

  -- a copy of first-clear table `id` with the `swap` items replaced (an item swapped to 0 is dropped); false = no change
  function X.node_prize(id, swap, name)
    if not X.prize_t then
      local k, e = X.table_key(PRIZE_PREFIX)
      if not k then return nil, e end
      local t, e2 = VRFW.rows.open(k)
      if not t then return nil, e2 end
      X.prize_t = t
    end
    local p = X.prize_t
    local items = p:rows("ITBL_ITEMS")
    local bi = p:find("ITBL_BASE", 0, id)
    if not bi then return false end
    if bi + 1 >= p:len() or p:hash(bi + 1) ~= VRFW.crc32("ITBL_BASE_REF_ITEMS") then return false end
    local refr = p:entry(bi + 1)
    local s, n = TC.int(refr.values, 0) or 0, TC.int(refr.values, 1) or 0
    if s < 0 then s = 0 end
    if n < 0 then n = 0 end
    local changed = false
    local new = {}
    for k = s + 1, math.min(s + n, #items) do
      local e = p:entry(items[k])
      local it = TC.uint(e.values, 0) or 0
      local hit
      for _, sw in ipairs(swap) do
        if sw[1] == it then hit = sw break end
      end
      if hit and hit[2] == 0 then
        changed = true
      elseif hit then
        TC.set_int(e.values, 0, hit[2])
        changed = true
        new[#new + 1] = e
      else
        new[#new + 1] = e
      end
    end
    if not changed then return false end
    local nid = VRFW.crc32(name)
    local start, count = #items, #new
    -- the base row is cloned BEFORE the items are appended (the ITBL_ITEMS list sits before ITBL_BASE)
    local base = p:entry(bi)
    local ok, e = pcall(p.append_rows, p, "ITBL_ITEMS", { "ITBL_ITEMS" }, new, count)
    if not ok then return nil, tostring(e) end
    if base.hash ~= VRFW.crc32("ITBL_BASE") then return nil, "soccer_prize_config: entry " .. bi .. " is not an ITBL_BASE row" end
    TC.set_int(base.values, 0, nid)
    refr.values = { start, count }
    ok, e = pcall(p.append_rows, p, "ITBL_BASE", { "ITBL_BASE", "ITBL_BASE_REF_ITEMS" }, { base, refr }, 1)
    if not ok then return nil, tostring(e) end
    return nid
  end

  -- every `[[VRFW.RouteNode]]` of the files, in load order: the nodes and the tiles with roads
  function X.route_nodes(files)
    local made, roads, icons = {}, {}, {}
    -- the chain keys declared anywhere (a node's `chain` must name one; the chains are built after the nodes)
    local chain_keys = {}
    local any = false
    for _, f in ipairs(files) do
      for _, c in ipairs(f.value.vrfw.Chain or {}) do
        local k = VRFW.ids.own(f.mod, c.name)
        if k then chain_keys[k] = true end
      end
      if #(f.value.vrfw.RouteNode or {}) > 0 then any = true end
    end
    local slots = {}
    local free = { lo = 0, hi = 0, taken = {} }
    if any then
      local fr, e = X.slot_range()
      if not fr then
        VRFW.log.error("route nodes: " .. e .. ": no node is built")
        return made, {}
      end
      free = fr
    end
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.RouteNode or {}) do
        local key, e = VRFW.ids.own(f.mod, d.name)
        if not key then
          VRFW.log.error(f.file .. ": route_node `" .. d.name .. "`: " .. e .. " (skipped)")
        else
          local what = f.file .. ": route_node " .. key
          local skip = false
          local ext = X.ext_slot(d.slot)
          local proxy = X.D.route_nodes.proxy_slot
          local hub = d.kind ~= nil and T.trim(d.kind) == "chain_hub"
          if not ext and not (d.slot >= free.lo and d.slot < free.hi) then
            VRFW.log.error(string.format("%s: slot %d is outside %d-%d (the save bytes no board piece uses) and %d-%d (extended slots) (skipped)", what, d.slot, free.lo, free.hi > 0 and free.hi - 1 or 0, X.D.route_nodes.slot_limit, (X.D.route_nodes.ext_slot_limit or X.D.route_nodes.slot_limit) - 1))
            skip = true
          elseif ext and (proxy == nil or not (proxy >= free.lo and proxy < free.hi) or free.taken[proxy]) then
            VRFW.log.error(string.format("%s: extended slot %d: the proxy slot %s is not a free save byte of the board (defaults\\team.toml [route_nodes] proxy_slot) (skipped)", what, d.slot, tostring(proxy)))
            skip = true
          elseif not ext and d.slot == proxy then
            VRFW.log.error(string.format("%s: slot %d is the extended slots' proxy (defaults\\team.toml [route_nodes] proxy_slot): take another (skipped)", what, d.slot))
            skip = true
          elseif d.kind ~= nil and not hub then
            VRFW.log.error(what .. ": Kind `" .. tostring(d.kind) .. "`: the only kind is \"chain_hub\" (skipped)")
            skip = true
          elseif hub and (d.chain ~= nil or #(d.chains or {}) == 0) then
            VRFW.log.error(what .. ": a chain hub lists its chains in `Chains` (at least one) and has no `Chain` (skipped)")
            skip = true
          elseif not hub and #(d.chains or {}) > 0 then
            VRFW.log.error(what .. ": `Chains` needs Kind = \"chain_hub\" (skipped)")
            skip = true
          elseif free.taken[d.slot] then
            VRFW.log.error(string.format("%s: slot %d is already a piece's of the board (another mod's) (skipped)", what, d.slot))
            skip = true
          elseif slots[d.slot] then
            VRFW.log.error(string.format("%s: slot %d is already route node %s's (skipped)", what, d.slot, slots[d.slot]))
            skip = true
          elseif d.chain ~= nil then
            local c = T.trim(d.chain)
            local ck = c:find(".", 1, true) and c or (f.mod .. "." .. c)
            if not chain_keys[ck] then
              VRFW.log.error(what .. ": chain `" .. c .. "` is declared by no mod (skipped)")
              skip = true
            end
          end
          -- a chain hub: its chains (each declared, once); the node itself behaves as a chain node of the first one
          local hub_keys = {}
          if not skip and hub then
            local seen = {}
            for _, c in ipairs(d.chains) do
              c = T.trim(c)
              local ck = c:find(".", 1, true) and c or (f.mod .. "." .. c)
              if not chain_keys[ck] then
                VRFW.log.error(what .. ": Chains: chain `" .. c .. "` is declared by no mod (skipped)")
                skip = true
              elseif seen[ck] then
                VRFW.log.error(what .. ": Chains: chain `" .. c .. "` is listed twice (skipped)")
                skip = true
              end
              seen[ck] = true
              hub_keys[#hub_keys + 1] = ck
            end
          end
          if not skip then
            local dn = d
            if hub then
              dn = {}
              for k, v in pairs(d) do dn[k] = v end
              dn.chain = hub_keys[1]
            end
            local n, err = X.route_node(f.mod, what, key, dn, made, roads, icons)
            if n and hub then
              n.chains = hub_keys
              VRFW.log.info(string.format("%s: chain hub of %d chain(s): %s", what, #hub_keys, table.concat(hub_keys, ", ")))
            end
            if n and ext then
              VRFW.log.info(string.format("%s: extended slot %d (framework save; piece byte = proxy slot %d)", what, d.slot, X.D.route_nodes.proxy_slot))
            end
            if n then
              slots[d.slot] = key
              local after = type(d.after) == "table" and d.after or { d.after }
              VRFW.log.info(string.format("%s: piece %s slot %d, game %s (%s), after %s", what, T.hex(n.piece), n.slot, n.game_key, T.hex(n.game), dbg_strs(after)))
              made[#made + 1] = n
            else
              VRFW.log.error(what .. ": " .. err .. " (skipped)")
            end
          end
        end
      end
    end
    -- the roads first: their overlay sprites go on the emblem atlas with the icons (one file)
    local road_list = {}
    if #roads > 0 then
      local t, warns = VRFW.team.node_roads(roads, X.D.route_nodes.max_nodes_per_tile)
      for _, w in ipairs(warns or {}) do VRFW.log.warn(w) end
      if t then road_list = t end
    end
    if #icons > 0 or #road_list > 0 then
      local ok, e = VRFW.team.node_icons(icons, X.D.route_nodes.crest_box, X.D.route_nodes.crest_top)
      if not ok then
        VRFW.log.warn("route nodes: board icons / roads not added (" .. e .. "): those nodes show no emblem and no road")
        road_list = {}
      end
    end
    return made, road_list
  end

  -- Rust `u32::from_str_radix(h, 16)`: an optional `+`, hex digits, the value below 2^32
  local function hex32(h)
    h = h:gsub("^%+", "", 1)
    if h == "" or not h:find("^[0-9a-fA-F]+$") then return nil end
    h = h:gsub("^0+", "")
    if h == "" then return 0 end
    if #h > 8 then return nil end
    return tonumber(h, 16)
  end
  R.hex32 = hex32

  local function quest_id(q, f)
    local h = q:match("^0[xX](.*)$")
    if h then
      local v = hex32(h)
      if v == nil then return nil, f .. ": bad id " .. q end
      return v
    end
    return VRFW.crc32(q)
  end

  function X.route_node(m, what, key, d, made, roads, icons)
    local name = T.last_part(key, ".")
    local piece = VRFW.crc32("evt_rn_piece_" .. name)
    local game_key = "evt_rn_" .. name
    local SG
    do
      local pi, e = X.piece_index(piece)
      if pi == nil then return nil, e end
      if pi ~= false then return nil, "piece evt_rn_piece_" .. name .. " already exists" end
    end
    local t, te = X.team_ref(d.team, m)
    if t == nil then return nil, "team: " .. te end
    local tid = X.tc:id_of(t)
    -- prerequisites
    local after = type(d.after) == "table" and d.after or { d.after }
    if #after == 0 then return nil, "`after` names no piece" end
    local parents, parent_pieces = {}, {}
    for _, a in ipairs(after) do
      local p, e = X.node_piece_ref(a, m, made)
      if not p then return nil, "after: " .. e end
      local i, e2 = X.piece_index(p)
      if i == nil then return nil, e2 end
      if i == false then return nil, "after: piece gone" end
      local r, F = rf()
      local sfi = X.slot_of_piece(p, r:u32(F.pl, i, F.p_sfi) or 0, made)
      local won = { 2 }
      for _, n in ipairs(made) do
        if n.piece == p then
          for _, x in ipairs(n.difficulties) do if x ~= 2 then won[#won + 1] = x end end
          break
        end
      end
      parents[#parents + 1] = { sfi, won }
      parent_pieces[#parent_pieces + 1] = p
    end
    -- `gates`: the pieces this node is inserted before (they open from its win, no longer from `after`); checked
    -- before anything is written: some prerequisite must open each one today
    local gates = {}
    local gate_list = d.gates or {}
    if d.mandatory == false and #gate_list > 0 then
      VRFW.log.info(what .. ": Mandatory = false: gates declared (" .. table.concat(gate_list, ", ") .. ") but NOT applied: the gated pieces open from their own prerequisites")
      gate_list = {}
    end
    for _, g in ipairs(gate_list) do
      local p, e = X.node_piece_ref(g, m, made)
      if not p then return nil, "gates: " .. e end
      for _, pp in ipairs(parent_pieces) do
        if pp == p then return nil, "gates: " .. g .. " is also a prerequisite (`after`) of the node" end
      end
      local gi, ge = X.piece_index(p)
      if gi == nil then return nil, ge end
      if gi == false then return nil, "gates: piece gone" end
      local r, F = rf()
      if not r then return nil, F end
      local opened = false
      for _, pp in ipairs(parent_pieces) do
        local pi = X.piece_row(r, F.pl, F.p_id, pp)
        local a, b = nil, nil
        if pi then a, b = r:tuple(F.pl, pi, F.p_unlock) end
        if a ~= nil then
          for u = a, a + b - 1 do
            if r:u32(F.ul, u, F.u_id) == p then opened = true end
          end
        end
      end
      if not opened then return nil, "gates: " .. g .. " is not opened by any piece of `after` (nothing to move)" end
      gates[#gates + 1] = { p, X.slot_of_piece(p, r:u32(F.pl, gi, F.p_sfi) or 0, made) }
    end
    -- `between = [a, b]`: the node replaces the move link a -> b (a = beside)
    local between
    local bt = d.between or {}
    if #bt == 2 then
      local pa, e = X.node_piece_ref(bt[1], m, made)
      if not pa then return nil, "between: " .. e end
      local pb, e2 = X.node_piece_ref(bt[2], m, made)
      if not pb then return nil, "between: " .. e2 end
      between = { pa, pb }
    elseif #bt ~= 0 then
      return nil, "`between` must name exactly two pieces: [\"<a>\", \"<b>\"]"
    end
    local beside
    if d.beside ~= nil then
      local p, e = X.node_piece_ref(d.beside, m, made)
      if not p then return nil, "beside: " .. e end
      if between and p ~= between[1] then return nil, "`beside` and the first piece of `between` differ (leave `beside` out)" end
      beside = p
    elseif between then
      beside = between[1]
    else
      beside = parent_pieces[1]
    end
    local bi, be = X.piece_index(beside)
    if bi == nil then return nil, be end
    if bi == false then return nil, "beside: piece gone" end
    local ro, re = X.route_of(bi)
    if ro == nil then return nil, re end
    if ro == false then return nil, "beside is on no route of the board (a hidden piece)" end
    local route, rs, rn = ro[1], ro[2], ro[3]
    -- template and field
    local tpl_gid
    if d.template_game ~= nil then
      tpl_gid = VRFW.crc32(T.trim(d.template_game))
    else
      local g, e = X.game_of_piece(beside)
      if g == nil then return nil, e end
      if g == false then return nil, "beside has no game: give `template_game`" end
      tpl_gid = g
    end
    local tpl, tpe = X.game_name(tpl_gid)
    if tpl == nil then return nil, tpe end
    if tpl == false then return nil, "template game " .. T.hex(tpl_gid) .. " is not in soccer_game_config" end
    local field_game
    if d.field ~= nil then
      field_game = VRFW.crc32(T.trim(d.field))
    else
      local g, e = X.game_of_piece(beside)
      if g == nil then return nil, e end
      field_game = g or tpl_gid
    end
    -- the difficulties its command menu shows: only the ones that exist with the active mods
    local difficulties = (#(d.difficulties or {}) == 0) and T.acopy(ROUTE_NODE_DEFAULT) or T.acopy(d.difficulties)
    local diffs = X.diffs
    if diffs.declared then
      difficulties = diffs.retain("route", difficulties, what)
      if #difficulties == 0 then return nil, "none of its difficulties exists with the active mods (route: " .. diffs.ids_text("route") .. ")" end
    else
      for _, x in ipairs(difficulties) do
        if not BOARD_DIFFS[x] then return nil, string.format("difficulty %d: the board's difficulties are 1, 2, 3, 4, 10, 11", x) end
      end
    end
    for _, k in ipairs(T.keys(d.first_clear or {})) do
      local x = tonumber(T.trim(k))
      if x and x >= 0 and x == math.floor(x) and T.trim(k):find("^%d+$") then
        if not diffs.exists("route", x) then
          VRFW.log.warn(string.format("%s: FirstClear \"%s\": difficulty %d does not exist with the active mods (route: %s): ignored", what, k, x, diffs.ids_text("route")))
        end
      end
    end
    -- the move graph: beside's direction must be free
    local r, F = rf()
    local bx, by = r:vec2(F.pl, bi, F.p_pos)
    if bx == nil then return nil, "beside has no position" end
    local bmove, bmn = r:tuple(F.pl, bi, F.p_move)
    if bmove == nil or bmn <= 0 then return nil, "beside has no move row" end
    local bev = r:u32(F.pl, bi, F.p_ev) or 0
    if bev ~= 0 and bev ~= 5 and bev ~= 2 and bev ~= 6 then return nil, string.format("beside is not a match / start piece (eventType %d)", bev) end
    -- between: the second piece's position and move row; its way back must lead to the first
    local far
    if between then
      local pa, pb = between[1], between[2]
      local fi, fe = X.piece_index(pb)
      if fi == nil then return nil, fe end
      if fi == false then return nil, "between: piece gone" end
      local fx, fy = r:vec2(F.pl, fi, F.p_pos)
      if fx == nil then return nil, "between: the second piece has no position" end
      local fmove, fmn = r:tuple(F.pl, fi, F.p_move)
      if fmove == nil or fmn <= 0 then return nil, "between: the second piece has no move row" end
      local fd, fde = r:field(F.ml, DIR_FIELD[OPPOSITE[d.dir]])
      if not fd then return nil, fde end
      if r:u32(F.ml, fmove, fd) ~= pa then
        return nil, "between: direction " .. OPPOSITE[d.dir] .. " of the second piece does not lead back to the first (the two are not linked that way)"
      end
      far = { pb = pb, pos = { fx, fy }, move = fmove }
    end
    do
      local fd, fde = r:field(F.ml, DIR_FIELD[d.dir])
      if not fd then return nil, fde end
      local cur = r:u32(F.ml, bmove, fd) or 0
      if far and cur ~= far.pb then
        return nil, "between: direction " .. d.dir .. " of the first piece leads to " .. T.hex(cur) .. ", not to the second piece " .. T.hex(far.pb)
      elseif not far and cur ~= 0 then
        return nil, "direction " .. d.dir .. " of beside is taken (piece " .. T.hex(cur) .. ")"
      end
    end
    local pos
    if d.pos ~= nil then
      pos = { d.pos[1], d.pos[2] }
    elseif far then
      pos = { (bx + far.pos[1]) / 2, (by + far.pos[2]) / 2 }
    else
      local st = STEP[d.dir]
      pos = { bx + 2 * st[1], by + 2 * st[2] }
    end
    -- ---- the game
    local tpl_rows, tre = X.game_rows(tpl_gid)
    if not tpl_rows then return nil, tre end
    SG = X.SG
    local g = X.games_t
    local tpl_team = 0
    do
      local i = tpl_rows[4]
      if i == nil then
        local ks = T.keys(tpl_rows)
        if ks[1] ~= nil then i = tpl_rows[ks[1]] end
      end
      if i ~= nil then tpl_team = g:uint(i, SG.D_TEAM) or 0 end
    end
    local names, ne = X.game_names()
    if not names then return nil, ne end
    if names[game_key] then return nil, "game " .. game_key .. " already exists" end
    local gid, ce = X.clone_game(m, what, t, tpl, game_key, nil, false, true)
    if not gid then return nil, ce end
    local set_levels = {}
    if d.cronica ~= nil and (d.cronica.level ~= nil or d.cronica.own_level ~= nil) then set_levels[1] = true end
    if d.heroica ~= nil and d.heroica.level ~= nil then set_levels[4] = true end
    X.node_clones[#X.node_clones + 1] = { game = gid, template = tpl_gid, set = set_levels }
    local rows, rows_e = X.game_rows(gid)
    if not rows then return nil, rows_e end
    -- `game_type` (1 = 11-a-side, 2 = small 5-a-side match, ...) and `map` (the stadium map): on the game's info row
    if d.game_type ~= nil or (d.map ~= nil and T.trim(d.map) ~= "") then
      local gg = X.gcache().by_id[gid]
      if not gg then return nil, "game gone" end
      if d.game_type ~= nil then
        if d.game_type < 1 or d.game_type > 4 then return nil, "game_type: 1 (11-a-side) .. 4, not " .. tostring(d.game_type) end
        g:set(gg.info, SG.G_TYPE, T.i32(d.game_type))
        VRFW.log.info(what .. ": game_type " .. d.game_type)
      end
      if d.map ~= nil and T.trim(d.map) ~= "" then
        local mp = T.trim(d.map)
        local id
        local h = mp:match("^0[xX](.*)$")
        if h then
          id = hex32(h)
          if id == nil then return nil, "map: bad id " .. mp end
        else
          id = VRFW.crc32(mp)
        end
        g:set(gg.info, SG.G_STADIUM, T.i32(id))
        VRFW.log.info(string.format("%s: stadium map %s (0x%08X)", what, mp, id))
      end
    end
    local drops, drop_keys = nil, nil
    if d.drops_from ~= nil then
      local src, se = X.game_rows(VRFW.crc32(T.trim(d.drops_from)))
      if not src then return nil, "drops_from: " .. se end
      drops = {}
      for dd, i in pairs(src) do drops[dd] = { g:uint(i, SG.D_SPIRIT_DROP) or 0, g:uint(i, SG.D_ITEM_DROP) or 0 } end
      drop_keys = T.keys(drops)
    end
    -- the match setup and per-game scripts: the team's own game, never the template's story events
    local match_src = d.match_from or d.drops_from
    if match_src ~= nil then match_src = T.trim(match_src) end
    local setup, setup_keys = nil, nil
    local setup_cols = { SG.D_CASTER, SG.D_RULES, SG.D_QUEST, SG.D_QUEST_2 }
    if match_src ~= nil then
      local src, se = X.game_rows(VRFW.crc32(match_src))
      if not src then return nil, "match_from: " .. se end
      setup = {}
      for dd, i in pairs(src) do
        local v = {}
        for k, c in ipairs(setup_cols) do v[k] = g:int(i, c) or 0 end
        setup[dd] = v
      end
      setup_keys = T.keys(setup)
    end
    -- per-game scripts: `scripts` (a game / false = the mod's own `trigger` declarations), default match_from's
    local drop_template_scripts, script_src
    if d.scripts == nil or d.scripts == true then
      drop_template_scripts, script_src = match_src ~= nil, match_src
    elseif d.scripts == false then
      drop_template_scripts, script_src = true, nil
    else
      drop_template_scripts, script_src = true, T.trim(d.scripts)
    end
    local mine = GAME_DIR .. game_key .. "_"
    if drop_template_scripts then VRFW.team.files_drop(mine, nil) end
    if d.scripts == false then
      VRFW.log.info(what .. ": scripts = false: no per-game scripts copied; the mod's `trigger` type supplies " .. game_key .. "_trigger / _phase_set")
    end
    if script_src ~= nil then
      local nf, fe = VRFW.team.files_copy(GAME_DIR .. script_src .. "_", mine, script_src, game_key)
      if not nf then return nil, fe end
    end
    -- the Crónica row's own objectives (col 25), replacing match_from's
    local quest
    if d.cronica ~= nil and d.cronica.quest ~= nil then
      local q = T.trim(d.cronica.quest)
      local id, qe = quest_id(q, "cronica.quest")
      if not id then return nil, qe end
      VRFW.log.info(string.format("%s: Crónica objectives = quest %s (0x%08X)", what, q, id))
      quest = id
    end
    -- the Heroica row's objectives: none unless declared (never the template's / match_from's)
    local heroica_quest = 0
    if d.heroica ~= nil and d.heroica.quest ~= nil and T.trim(d.heroica.quest) ~= "" then
      local q = T.trim(d.heroica.quest)
      local id, qe = quest_id(q, "heroica.quest")
      if not id then return nil, qe end
      VRFW.log.info(string.format("%s: Heroica objectives = quest %s (0x%08X)", what, q, id))
      heroica_quest = id
    end
    local own_team
    if d.cronica ~= nil and d.cronica.own_team ~= nil then
      local ot, oe = X.team_ref(d.cronica.own_team, m)
      if ot == nil then return nil, "cronica.own_team: " .. oe end
      own_team = X.tc:id_of(ot)
    end
    -- rewards: the template team's emblem / kit → the node team's
    local swap = {}
    if d.team_rewards ~= false then
      local te = X.emblem_and_kit(tpl_team) or { emblem = 0, kit = 0 }
      local nk_, nke = X.emblem_and_kit(tid)
      if not nk_ then return nil, nke end
      local tki, e1 = X.kit_item(te.kit)
      if tki == nil then return nil, e1 end
      local nki, e2 = X.kit_item(nk_.kit)
      if nki == nil then return nil, e2 end
      if te.emblem ~= 0 and nk_.emblem ~= 0 and te.emblem ~= nk_.emblem then
        local ex, e3 = X.emblem_exists(nk_.emblem)
        if ex == nil then return nil, e3 end
        if ex then swap[#swap + 1] = { te.emblem, nk_.emblem } end
      end
      if tki ~= false then swap[#swap + 1] = { tki, nki or 0 } end
    end
    for _, diff in ipairs(T.keys(rows)) do
      local i = rows[diff]
      local function set(c, v) g:set(i, c, T.i32(v)) end
      if diff == 1 then
        local c = d.cronica
        if c ~= nil then
          if c.level ~= nil then set(SG.D_LEVEL, c.level) end
          if own_team ~= nil then set(SG.D_OWN_TEAM, own_team) end
          if c.own_level ~= nil then set(SG.D_OWN_LEVEL, c.own_level) end
        end
      elseif diff == 4 then
        if d.heroica ~= nil and d.heroica.level ~= nil then set(SG.D_LEVEL, d.heroica.level) end
      end
      if drops then
        local x = drops[diff] or drops[11] or (drop_keys[1] ~= nil and drops[drop_keys[1]]) or nil
        if x then
          -- a table the source does not have (0) keeps the template's
          if x[1] ~= 0 then set(SG.D_SPIRIT_DROP, x[1]) end
          if x[2] ~= 0 then set(SG.D_ITEM_DROP, x[2]) end
        end
      end
      if setup then
        local v = setup[diff] or setup[4] or (setup_keys[1] ~= nil and setup[setup_keys[1]]) or nil
        if v then
          for k, c in ipairs(setup_cols) do set(c, v[k]) end
        end
      end
      if diff == 1 and quest ~= nil then set(SG.D_QUEST, quest) end
      if diff == 4 then
        set(SG.D_QUEST, heroica_quest)
        set(SG.D_QUEST_2, 0)
      end
      local fct = (d.first_clear or {})[T.d(diff)]
      if fct ~= nil and diffs.exists("route", diff) then
        -- a declared first-clear table for this difficulty (e.g. a stadium item): replaces the template's
        local id
        local h = fct:match("^0[xX](.*)$")
        if h then
          id = hex32(h)
          if id == nil then return nil, string.format("first_clear.%d: bad id %s", diff, fct) end
        else
          id = VRFW.crc32(fct)
        end
        set(SG.D_FIRST_CLEAR, id)
      else
        local fc = g:uint(i, SG.D_FIRST_CLEAR) or 0
        if fc ~= 0 and #swap > 0 then
          local new, pe = X.node_prize(fc, swap, game_key .. "_fc" .. diff)
          if new == nil then return nil, pe end
          if new ~= false then set(SG.D_FIRST_CLEAR, new) end
        end
      end
    end
    g:touch()
    if not T.is_empty(d.title) then
      local title = VRFW.crc32(game_key .. "_title")
      local gg = X.gcache().by_id[gid]
      if not gg then return nil, "game gone" end
      g:set(gg.info, SG.G_TITLE, T.i32(title))
      local texts = {}
      for _, k in ipairs(T.keys(d.title)) do
        local n = VRFW.lang.norm_or_all(k)
        if n then texts[n] = d.title[k] end
      end
      X.push_text(m, nil, { table = "soccer_game_title", id = title, variant = 0, texts = texts, add = true, origin = what .. ": title" })
    end
    -- ---- the piece
    local icon_src, icon = nil, 0
    local ic = d.icon and T.trim(d.icon) or ""
    if ic ~= "" then
      local path, exists = VRFW.team.mod_file(m, ic)
      if path == nil then return nil, "icon: mod folder unknown" end
      if not exists then return nil, "icon: " .. path .. " not found" end
      local n = R.node_icon_sprite(name)
      icon_src = { name = n, mod = m, png = ic }
      icon = VRFW.crc32(n)
    else
      local ek, eke = X.emblem_and_kit(tid)
      if not ek then return nil, eke end
      if ek.key ~= nil then
        local n = ek.key .. "_t01"
        icon_src = { name = n, emblem = ek.key }
        icon = VRFW.crc32(n)
      end
    end
    -- the board balloon's label: a chain node shows its own title (its team is never played); other nodes: none
    local is_chain = d.chain ~= nil and T.trim(d.chain) ~= ""
    local guide = 0
    if is_chain and not T.is_empty(d.title) then
      guide = VRFW.crc32(game_key .. "_guide")
      local texts = {}
      for _, k in ipairs(T.keys(d.title)) do
        local n = VRFW.lang.norm_or_all(k)
        if n then texts[n] = d.title[k] end
      end
      X.push_text(m, nil, { table = "menu_text", id = guide, variant = 0, texts = texts, add = true, origin = what .. ": board label" })
    end
    -- a node drawn while closed (`locked_title`): its balloon text until it opens
    local locked_guide = 0
    if not T.is_empty(d.locked_title) then
      locked_guide = VRFW.crc32(game_key .. "_guide_locked")
      local texts = {}
      for _, k in ipairs(T.keys(d.locked_title)) do
        local n = VRFW.lang.norm_or_all(k)
        if n then texts[n] = d.locked_title[k] end
      end
      X.push_text(m, nil, { table = "menu_text", id = locked_guide, variant = 0, texts = texts, add = true, origin = what .. ": locked board label" })
      VRFW.log.info(what .. ": drawn while closed (its balloon: the locked title)")
    end
    local linked = #parent_pieces == 1
    r, F = rf()
    if not r then return nil, F end
    -- icon row
    if icon ~= 0 then
      local found = false
      for _, x in ipairs(r:col_u32(F.il, F.i_id)) do
        if x == icon then found = true break end
      end
      if not found then
        if r:len(F.il) == 0 then return nil, "no icon row to clone" end
        local row = r:copy(F.il, 0)
        r:set_u32(-1, row, F.i_id, icon)
        r:set_u32(-1, row, F.i_name, icon)
        r:set_u32(-1, row, F.i_path, VRFW.crc32(ICON_ATLAS_GAME))
        r:push(F.il, row)
        if icon_src then icons[#icons + 1] = icon_src end
      end
    end
    -- move rows: the node's (back to beside) and beside's (to the node)
    local mv = r:len(F.ml)
    local mrow = r:copy(F.ml, bmove)
    for _, dir in ipairs(DIRS) do
      local fd, fde = r:field(F.ml, DIR_FIELD[dir])
      if not fd then return nil, fde end
      local to = 0
      if dir == OPPOSITE[d.dir] then
        to = beside
      elseif far and dir == d.dir then
        to = far.pb
      end
      r:set_u32(-1, mrow, fd, to)
    end
    r:push(F.ml, mrow)
    do
      local fd = r:field(F.ml, DIR_FIELD[d.dir])
      r:set_u32(F.ml, bmove, fd, piece)
      if far then
        local fo = r:field(F.ml, DIR_FIELD[OPPOSITE[d.dir]])
        r:set_u32(F.ml, far.move, fo, piece)
      end
    end
    -- the piece row: beside's, as a plain match piece
    local row = r:copy(F.pl, bi)
    r:set_u32(-1, row, F.p_id, piece)
    r:set_u32(-1, row, F.p_ev, 0)
    r:set_u32(-1, row, F.p_sfi, X.piece_slot(d.slot))
    r:set_vec2(-1, row, F.p_pos, pos[1], pos[2])
    r:set_u32(-1, row, F.p_icon, icon)
    r:set_u32(-1, row, F.p_icon_idx, 0)
    r:set_u32(-1, row, F.p_guide, guide)
    -- a chain node is no team of the «Cadena de Crónica» list (its game is never played): a tab that list has not
    if is_chain and F.p_list_tab and X.D.route_nodes.chain_list_tab then
      r:set_u32(-1, row, F.p_list_tab, X.D.route_nodes.chain_list_tab)
    end
    r:set_tuple(-1, row, F.p_move, mv, 1)
    r:set_tuple(-1, row, F.p_unlock, 0, 0)
    r:set_tuple(-1, row, F.p_event, 0, 0)
    for _, c in ipairs { F.p_new, F.p_gate_key, F.p_open_event, F.p_need_update } do r:set_u32(-1, row, c, 0) end
    for _, c in ipairs { F.p_gate_use, F.p_gate_open, F.p_upd_lock, F.p_locked_flag } do r:set_u32(-1, row, c, 0) end
    for _, c in ipairs(F.p_conds) do r:set_str(-1, row, c, nil) end
    -- never the route's last piece (its final): right after beside, or right before it when beside is last
    local at = (bi + 1 < rs + rn) and (bi + 1) or bi
    r:insert(F.pl, at, row)
    for k = 0, r:len(F.rl) - 1 do
      local s, n = r:tuple(F.rl, k, F.r_slice)
      if s ~= nil then
        local s2, n2 = s, n
        if k == route then
          n2 = n + 1
        elseif s >= at and n > 0 then
          s2 = s + 1
        end
        if s2 ~= s or n2 ~= n then r:set_tuple(F.rl, k, F.r_slice, s2, n2) end
      end
    end
    -- the native unlock link (one prerequisite): the parent's slice moved to the end + the node
    if linked then
      local pi = X.piece_row(r, F.pl, F.p_id, parent_pieces[1])
      if pi == nil then return nil, "parent gone" end
      local a, b = r:tuple(F.pl, pi, F.p_unlock)
      if a == nil then a, b = 0, 0 end
      local nul = r:len(F.ul)
      local proto
      if a < nul then proto = a elseif nul > 0 then proto = 0 end
      if proto == nil then return nil, "no unlock row to clone" end
      local link = r:copy(F.ul, proto)
      r:set_u32(-1, link, F.u_id, piece)
      r:set_u32(-1, link, F.u_ev, 1)
      local start = r:len(F.ul)
      r:extend_copy(F.ul, a, a + b)
      r:push(F.ul, link)
      r:set_tuple(F.pl, pi, F.p_unlock, start, b + 1)
    end
    -- `gates`: each gated piece leaves its prerequisites' unlock lists (their slices are copied to the end without it)
    -- and joins the node's own unlock list (its moved link row: unlockEvent / dlc kept)
    if #gates > 0 then
      local links, have = {}, {}
      for _, gt in ipairs(gates) do
        for _, pp in ipairs(parent_pieces) do
          local pi = X.piece_row(r, F.pl, F.p_id, pp)
          if pi == nil then return nil, "parent gone" end
          local a, b = r:tuple(F.pl, pi, F.p_unlock)
          if a ~= nil and b > 0 then
            local keep, hit = {}, false
            for u = a, a + b - 1 do
              if r:u32(F.ul, u, F.u_id) == gt[1] then
                hit = true
                if not have[gt[1]] then
                  have[gt[1]] = true
                  links[#links + 1] = r:copy(F.ul, u)
                end
              else
                keep[#keep + 1] = r:copy(F.ul, u)
              end
            end
            if hit then
              local start = r:len(F.ul)
              for _, row in ipairs(keep) do r:push(F.ul, row) end
              r:set_tuple(F.pl, pi, F.p_unlock, #keep == 0 and 0 or start, #keep)
            end
          end
        end
      end
      local ni = X.piece_row(r, F.pl, F.p_id, piece)
      if ni == nil then return nil, "node piece gone" end
      local start = r:len(F.ul)
      for _, row in ipairs(links) do r:push(F.ul, row) end
      r:set_tuple(F.pl, ni, F.p_unlock, start, #links)
      local gs = {}
      for _, gt in ipairs(gates) do gs[#gs + 1] = T.hex(gt[1]) .. " (slot " .. gt[2] .. ")" end
      VRFW.log.info(what .. ": inserted before " .. table.concat(gs, ", ") .. ": they open from this node's win")
    end
    local map_type = r:u32(F.rl, route, F.r_map) or 0
    r:touch()
    X.touched.route = true
    local pa_ok, pae = X.piece_append(piece, { gid })
    if not pa_ok then return nil, pae end
    -- the node's road on the board's iso grid (start, `via` bends, node): a segment off the board's two axes gets
    -- an L bend (iso_route), so the road and the caravan's rail look like the retail roads
    local iso = {}
    if not far then
      local pts = { d.road_from and { d.road_from[1], d.road_from[2] } or { bx, by } }
      for _, p in ipairs(d.via or {}) do pts[#pts + 1] = { p[1], p[2] } end
      pts[#pts + 1] = pos
      local added
      iso, added = iso_route(pts, d.dir)
      for _, c in ipairs(added) do
        VRFW.log.info(string.format("%s: road bent onto the board's iso axes at (%s, %s)", what, T.num_text(c[1]), T.num_text(c[2])))
      end
      for k = 1, #iso - 1 do
        local len = math.abs(iso[k + 1][1] - iso[k][1])
        if #added > 0 and len < 0.5 then
          VRFW.log.warn(string.format("%s: road leg (%s, %s) -> (%s, %s) is %s grid steps long (under 0.5 the pads hide it): move `Pos` onto one of the board's axes from beside, or add a `Via` bend",
            what, T.num_text(iso[k][1]), T.num_text(iso[k][2]), T.num_text(iso[k + 1][1]), T.num_text(iso[k + 1][2]), T.num_text(len)))
        end
      end
    end
    -- a node between two pieces sits on their painted line: no road of its own
    local style
    if far then
      style = "none"
    elseif d.road == nil or d.road == true then
      style = "dotted"
    elseif d.road == false then
      style = "none"
    else
      style = d.road
    end
    if style ~= "none" then
      if map_type == 0 then
        local from = d.road_from and { d.road_from[1], d.road_from[2] } or nil
        local via = {}
        for k = 2, #iso - 1 do via[#via + 1] = iso[k] end
        roads[#roads + 1] = { node = #made, anchor = { bx, by }, from = from or { bx, by }, from_pad = from == nil, via = via, to = pos, style = style, pad_scale = d.pad_scale }
      else
        VRFW.log.warn(string.format("%s: roads are drawn on the main board only (this route is on board type %d): no road", what, map_type))
      end
    end
    local chain = ""
    if is_chain then
      local c = T.trim(d.chain)
      chain = c:find(".", 1, true) and c or (m .. "." .. c)
      VRFW.log.info(what .. ": opens chain board " .. chain .. (far and " (between two pieces, no road)" or ""))
    end
    local gate_slots = {}
    for _, gt in ipairs(gates) do gate_slots[#gate_slots + 1] = gt[2] end
    -- the caravan's rail: along the node's road (fork point and bends), not straight from beside
    local path = {}
    if not far then
      path[1] = { bx, by }
      if d.road_from then path[#path + 1] = { d.road_from[1], d.road_from[2] } end
      for k = 2, #iso do path[#path + 1] = iso[k] end
    end
    return { key = key, mod_id = m, piece = piece, slot = d.slot, parents = parents, difficulties = difficulties, game = gid,
      game_key = game_key, field_game = field_game, linked = linked, chain = chain, chains = {}, beside = beside, path = path,
      gates = gate_slots, locked_guide = locked_guide,
      piece_scale = (d.piece_scale ~= nil and d.piece_scale >= 0.2 and d.piece_scale <= 2) and d.piece_scale or 1 }
  end
end

return R
