-- InaRogue › INAROGUE: the seeded route map of a phase (pure; docs/game/modes/inarogue.md §11, §12.3, §12.5).
-- Was run.rs of the DLL's module rogue; every stream and constant is the same, so a saved run's board does not change.
--
-- * The map of a phase is a pure function of (seed, phase) and the size curve ([rogue] map_curve keyframes
--   [from_phase, length, width]). Column 0 is the start; match column i of L has min(width, i + 1, L - i) nodes (the
--   boss last); inner plateau columns (width >= 3) lose one node 1 time in 3. Edges between neighbouring columns are a
--   monotone staircase (no two cross). Rows use 9 vertical slots.
-- * Content (§12.3) replaces match nodes of columns 2 .. boss-1 (Cofre, Evento, Fichaje, Élite) and marks line events
--   on edges (Tienda, Gacha, Tragaperras); coins (§12.5) on the Gacha lines. Separate seeded streams: the shape never
--   changes.
--
-- A map: { cols, nodes = { [k + 1] = { col, slot, kind, pick } }, edges = { [e + 1] = { from, to } }, edge_ev, edge_coin }
-- (node / edge numbers 0-based as the commands use them).

local U = require "lib/rogue/util"

local M = {}

M.KIND = { START = 0, SMALL = 1, FULL = 2, BOSS = 3, CHEST = 4, EVENT = 5, RECRUIT = 6, ELITE = 7, EPIC = 8, GATE = 9 }
local K = M.KIND
M.CONTENT = { COFRE = 1, TIENDA = 2, EVENTO = 3, FICHAJE = 4, GACHA = 5, ELITE = 6, TRAGAPERRAS = 7 }
local CT = M.CONTENT
M.EV = { NONE = 0, TIENDA = 1, GACHA = 2, TRAGAPERRAS = 3 }
local EV = M.EV
M.MAX_LEN, M.MAX_WIDTH, M.ROW_SLOTS = 30, 5, 9

local xs, mul32, xor = U.xs, U.mul32, U.xor

-- (length, width) of `phase`: the last keyframe at or before it
function M.phase_size(curve, phase)
  local p = math.max(phase, 1)
  local best = nil
  for _, r in ipairs(curve) do
    if #r == 3 and r[1] <= p then best = r end
  end
  if not best then return 3, 2 end
  return U.clamp(best[2], 2, M.MAX_LEN), U.clamp(best[3], 1, M.MAX_WIDTH)
end

local function base_width(i, len, width)
  return math.min(width, i + 1, len - i)
end

local SLOTS = { { 4 }, { 3, 5 }, { 2, 4, 6 }, { 1, 3, 5, 7 }, { 0, 2, 4, 6, 8 } }

-- the map of `phase` for `seed` with an explicit curve (no content)
function M.generate_with(seed, phase, curve)
  local s = xor(seed, mul32(math.max(phase, 1), 0x9E3779B9))
  if s == 0 then s = 0x9E3779B9 end
  local len, width = M.phase_size(curve, phase)
  local counts = { 1 }
  for i = 0, len - 1 do
    local w = base_width(i, len, width)
    local plateau = w == width and width >= 3 and i + 1 > width and len - i > width
    if plateau then
      s = xs(s)
      if s % 3 == 0 then w = w - 1 end
    end
    counts[#counts + 1] = w
  end
  local nodes, first = {}, {}
  local ncols = #counts
  for c = 0, ncols - 1 do
    first[c] = #nodes
    for _, slot in ipairs(SLOTS[math.min(counts[c + 1], 5)]) do
      local kind
      if c == 0 then
        kind = K.START
      elseif c == ncols - 1 then
        kind = K.BOSS
      elseif c == 1 then
        kind = K.SMALL -- the opening match of a phase is always a quick 5v5
      else
        s = xs(s)
        if s % 4 == 0 then kind = K.FULL else kind = K.SMALL end
      end
      s = xs(s)
      nodes[#nodes + 1] = { col = c, slot = slot, kind = kind, pick = s }
    end
  end
  local edges = {}
  for c = 0, ncols - 2 do
    local n, m = counts[c + 1], counts[c + 2]
    local a, b = first[c], first[c + 1]
    local i, j = 0, 0
    edges[#edges + 1] = { a + i, b + j }
    while i < n - 1 or j < m - 1 do
      if i == n - 1 then
        j = j + 1
      elseif j == m - 1 then
        i = i + 1
      else
        s = xs(s)
        local r = s % 3
        if r == 0 then
          i = i + 1
        elseif r == 1 then
          j = j + 1
        else
          i = i + 1
          j = j + 1
        end
      end
      edges[#edges + 1] = { a + i, b + j }
    end
  end
  return { cols = ncols, nodes = nodes, edges = edges, edge_ev = {}, edge_coin = {} }
end

function M.node(m, k) return m.nodes[k + 1] end
function M.boss(m) return #m.nodes - 1 end

function M.connected(m, from, to)
  for _, e in ipairs(m.edges) do
    if e[1] == from and e[2] == to then return true end
  end
  return false
end

local function col_width(m, c)
  local n = 0
  for _, nd in ipairs(m.nodes) do
    if nd.col == c then n = n + 1 end
  end
  return n
end

-- a path from the start to the boss avoiding every node `bad(kind)` (edges are listed column by column)
function M.free_path(m, bad)
  local ok = {}
  if #m.nodes == 0 then return true end
  ok[0] = true
  for _, e in ipairs(m.edges) do
    if ok[e[1]] and not bad(m.nodes[e[2] + 1].kind) then ok[e[2]] = true end
  end
  return ok[#m.nodes - 1] == true
end

local function elite_free_path(m)
  return M.free_path(m, function(k) return k == K.ELITE end)
end

local function node_kind_of(t)
  if t == CT.COFRE then return K.CHEST end
  if t == CT.EVENTO then return K.EVENT end
  if t == CT.FICHAJE then return K.RECRUIT end
  if t == CT.ELITE then return K.ELITE end
  return nil
end

local function edge_ev_of(t)
  if t == CT.TIENDA then return EV.TIENDA end
  if t == CT.GACHA then return EV.GACHA end
  if t == CT.TRAGAPERRAS then return EV.TRAGAPERRAS end
  return EV.NONE
end

-- the phase's content on a generated map (its own seeded stream)
function M.add_content(m, seed, phase, tbl)
  phase = math.max(phase, 1)
  local s = math.max(xor(xor(seed, mul32(phase, 0x85EBCA6B)), 0x00C0FFEE), 1)
  m.edge_ev = {}
  for e = 1, #m.edges do m.edge_ev[e] = EV.NONE end
  local unlocked = {}
  for _, r in ipairs(tbl) do
    if #r == 3 and r[3] > 0 and r[2] <= phase then unlocked[#unlocked + 1] = { r[1], r[2], r[3] } end
  end
  if #unlocked == 0 then return end
  local boss_col = m.cols - 1
  -- ---- nodes
  local eligible = {}
  for k = 0, #m.nodes - 1 do
    local c = m.nodes[k + 1].col
    if c >= 2 and c < boss_col then eligible[#eligible + 1] = k end
  end
  for i = #eligible - 1, 1, -1 do
    s = xs(s)
    local j = s % (i + 1)
    eligible[i + 1], eligible[j + 1] = eligible[j + 1], eligible[i + 1]
  end
  local node_cap
  if phase < 6 then
    node_cap = 1
  else
    node_cap = math.min(1 + math.floor(phase / 5), math.max(math.floor(#eligible / 3), 1))
  end
  local placed = 0
  local function can_place(k, kind)
    if kind ~= K.ELITE then return true end
    local c = m.nodes[k + 1].col
    if col_width(m, c) < 2 then return false end
    for _, nd in ipairs(m.nodes) do
      if nd.col == c and nd.kind == K.ELITE then return false end
    end
    return true
  end
  local free = {}
  for i, k in ipairs(eligible) do free[i] = k end
  -- the phase's new node type first
  for _, u in ipairs(unlocked) do
    if u[2] == phase then
      local kind = node_kind_of(u[1])
      if kind then
        for pos, k in ipairs(free) do
          if can_place(k, kind) then
            table.remove(free, pos)
            m.nodes[k + 1].kind = kind
            placed = placed + 1
            break
          end
        end
      end
    end
  end
  local node_types = {}
  for _, u in ipairs(unlocked) do
    local kind = node_kind_of(u[1])
    if kind then node_types[#node_types + 1] = { kind, u[3] } end
  end
  for _, k in ipairs(free) do
    if placed >= node_cap then break end
    s = xs(s)
    local x = s % 100
    local acc = 0
    for _, nt in ipairs(node_types) do
      acc = acc + nt[2]
      if x < acc then
        if can_place(k, nt[1]) then
          m.nodes[k + 1].kind = nt[1]
          placed = placed + 1
        end
        break
      end
    end
  end
  -- never a mandatory Élite
  while not elite_free_path(m) do
    local last = nil
    for k = #m.nodes, 1, -1 do
      if m.nodes[k].kind == K.ELITE then
        last = k
        break
      end
    end
    if not last then break end
    m.nodes[last].kind = K.SMALL
  end
  -- ---- line events
  local edges = {}
  for e = 0, #m.edges - 1 do
    if m.edges[e + 1][1] ~= 0 then edges[#edges + 1] = e end
  end
  for i = #edges - 1, 1, -1 do
    s = xs(s)
    local j = s % (i + 1)
    edges[i + 1], edges[j + 1] = edges[j + 1], edges[i + 1]
  end
  local line_cap
  if phase < 8 then line_cap = 1 else line_cap = 1 + math.floor(#m.edges / 8) end
  local lines = 0
  local free_e = {}
  for i, e in ipairs(edges) do free_e[i] = e end
  for _, u in ipairs(unlocked) do
    local ev = edge_ev_of(u[1])
    if u[2] == phase and ev ~= EV.NONE and #free_e > 0 then
      local e = table.remove(free_e, 1)
      m.edge_ev[e + 1] = ev
      lines = lines + 1
    end
  end
  local line_types = {}
  for _, u in ipairs(unlocked) do
    local ev = edge_ev_of(u[1])
    if ev ~= EV.NONE then line_types[#line_types + 1] = { ev, u[3] } end
  end
  for _, e in ipairs(free_e) do
    if lines >= line_cap then break end
    s = xs(s)
    local x = s % 100
    local acc = 0
    for _, lt in ipairs(line_types) do
      acc = acc + lt[2]
      if x < acc then
        m.edge_ev[e + 1] = lt[1]
        lines = lines + 1
        break
      end
    end
  end
end

-- the coin of every Gacha line: weighted over the rows available in `phase` (its own stream)
function M.add_coins(m, seed, phase, tbl)
  local p = math.max(phase, 1)
  local s = math.max(xor(xor(seed, mul32(p, 0x27D4EB2F)), 0x00C01D00), 1)
  local rows, total = {}, 0
  for _, r in ipairs(tbl) do
    if #r == 3 and r[2] > 0 and r[3] <= p then
      rows[#rows + 1] = { r[1], r[2] }
      total = total + r[2]
    end
  end
  m.edge_coin = {}
  for e = 1, #m.edges do m.edge_coin[e] = 0 end
  if total == 0 then return end
  for e = 1, #m.edges do
    if m.edge_ev[e] == EV.GACHA then
      s = xs(s)
      local x = s % total
      for _, r in ipairs(rows) do
        if x < r[2] then
          m.edge_coin[e] = r[1]
          break
        end
        x = x - r[2]
      end
    end
  end
end

-- the [rogue] map_content rows with each weight x a coach's multiplier (0..100); mults[type] (1.0 = unchanged)
function M.scale_content(rows, mults)
  local o = {}
  for i, r in ipairs(rows) do
    if #r == 3 then
      local mm = mults[r[1]] or 1.0
      o[i] = { r[1], r[2], U.clamp(U.round(r[3] * mm), 0, 100) }
    else
      o[i] = r
    end
  end
  return o
end

local function per_stage(list, phase)
  if type(list) ~= "table" or #list == 0 then return 0 end
  return list[U.clamp(phase, 1, #list)]
end

-- the content of a v2 stage (docs/game/mods/inarogue-loop-v2.md §5.1, its own seeded stream): `nodes` content nodes
-- and `lines` line events, each drawn by weight among the rows open in the stage; an Élite never on every path and at
-- most one per column (as add_content)
function M.add_content_capped(m, seed, phase, tbl, nodes, lines)
  phase = math.max(phase, 1)
  local s = math.max(xor(xor(seed, mul32(phase, 0x6A09E667)), 0x00B0A4D3), 1)
  m.edge_ev = {}
  for e = 1, #m.edges do m.edge_ev[e] = EV.NONE end
  local node_types, line_types, node_total, line_total = {}, {}, 0, 0
  for _, r in ipairs(tbl) do
    if #r == 3 and r[3] > 0 and r[2] <= phase then
      local kind, ev = node_kind_of(r[1]), edge_ev_of(r[1])
      if kind then
        node_types[#node_types + 1] = { kind, r[3] }
        node_total = node_total + r[3]
      elseif ev ~= EV.NONE then
        line_types[#line_types + 1] = { ev, r[3] }
        line_total = line_total + r[3]
      end
    end
  end
  local function draw(types, total)
    s = xs(s)
    local x = s % total
    for _, t in ipairs(types) do
      if x < t[2] then return t[1] end
      x = x - t[2]
    end
    return types[#types][1]
  end
  local boss_col = m.cols - 1
  local eligible = {}
  for k = 0, #m.nodes - 1 do
    local c = m.nodes[k + 1].col
    if c >= 2 and c < boss_col and m.nodes[k + 1].kind ~= K.BOSS then eligible[#eligible + 1] = k end
  end
  for i = #eligible - 1, 1, -1 do
    s = xs(s)
    local j = s % (i + 1)
    eligible[i + 1], eligible[j + 1] = eligible[j + 1], eligible[i + 1]
  end
  local placed = 0
  if node_total > 0 then
    for _, k in ipairs(eligible) do
      if placed >= nodes then break end
      local kind = draw(node_types, node_total)
      local c = m.nodes[k + 1].col
      local ok = true
      if kind == K.ELITE then
        ok = col_width(m, c) >= 2
        for _, nd in ipairs(m.nodes) do
          if nd.col == c and nd.kind == K.ELITE then ok = false end
        end
      end
      if ok then
        m.nodes[k + 1].kind = kind
        placed = placed + 1
      end
    end
  end
  while not elite_free_path(m) do
    local last = nil
    for k = #m.nodes, 1, -1 do
      if m.nodes[k].kind == K.ELITE then
        last = k
        break
      end
    end
    if not last then break end
    m.nodes[last].kind = K.SMALL
  end
  if line_total == 0 then return end
  local edges = {}
  for e = 0, #m.edges - 1 do
    if m.edges[e + 1][1] ~= 0 then edges[#edges + 1] = e end
  end
  for i = #edges - 1, 1, -1 do
    s = xs(s)
    local j = s % (i + 1)
    edges[i + 1], edges[j + 1] = edges[j + 1], edges[i + 1]
  end
  for i = 1, math.min(lines, #edges) do
    m.edge_ev[edges[i] + 1] = draw(line_types, line_total)
  end
end

-- the full map: shape, content (× the coach's multipliers when given), coins. A v2 run's settings (content_rule 3,
-- lib/rogue/run_rules.lua) place their content with the stage caps.
function M.generate(seed, phase, c, mults)
  local m = M.generate_with(seed, phase, c.map_curve)
  local content = c.map_content
  if mults then content = M.scale_content(content, mults) end
  if c.content_rule == 3 then
    M.add_content_capped(m, seed, phase, content, per_stage(c.content_nodes, phase), per_stage(c.content_lines, phase))
  else
    M.add_content(m, seed, phase, content)
  end
  M.add_coins(m, seed, phase, c.gacha_coins)
  return m
end

return M
