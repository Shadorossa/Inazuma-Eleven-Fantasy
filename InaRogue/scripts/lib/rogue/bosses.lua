-- InaRogue › INAROGUE: boss tiers and special bosses (docs/game/modes/inarogue.md §33). Was bosses.rs of the
-- DLL's module rogue. Mechanism only; the mod declares everything in content\rogue\bosses.toml ([rogue.bosses] file):
--
-- * phase boss: with [boss] special_chance a [[special]] of role "boss" takes the node (+ special_level_bonus);
-- * «Jefe épico» (Kind EPIC): an optional side node in a middle column, easier than the boss ([epic] level_offset);
-- * «Jefe de puerta» (Kind GATE): an optional node right before the boss, harder ([gate] level_offset).
-- A special boss plays its own game evt_rl_b_<id> (research/scripts/rogue_bosses_build.py). Every draw is a pure
-- function of (seed, phase, node); boards saved before the tiers (rivals_rule < 2) keep their old draw.

local U = require "lib/rogue/util"
local map = require "lib/rogue/map"
local K = map.KIND
local info, warn = U.logger("rogue bosses")

local B = {}

B.SCHEMA, B.GAME_PREFIX, B.RULE, B.BOSS_ONLY = "inazuma_fantasy.rogue_bosses/1", "evt_rl_b_", 2, "boss_only"
B.DEFAULT_LEVELS = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 120, 150, 200 }

local cat = nil -- false = none (off / unreadable)

local function num(v, d)
  if type(v) == "number" then return v end
  return d
end

local function strs(v)
  local o = {}
  if type(v) == "table" then
    for _, x in ipairs(v) do
      if type(x) == "string" then o[#o + 1] = x end
    end
  end
  return o
end

local function parse(t)
  local c = {
    schema = t.schema or "", requires_scope = type(t.requires_scope) == "string" and t.requires_scope or "",
    boss = { special_chance = 0.0, special_level_bonus = 4 },
    epic = { enabled = false, from_phase = 2, chance = 0.0, level_offset = 5, minor_weight = 1.0, special_weight = 1.0 },
    gate = { enabled = false, from_phase = 4, chance = 0.0, level_offset = 8, emblematic_weight = 1.0, special_weight = 1.0 },
    ladder = { levels = B.DEFAULT_LEVELS, stadium = 0 },
    tags = {}, special = {},
  }
  local warns = {}
  if c.schema ~= "" and c.schema ~= B.SCHEMA then warns[#warns + 1] = string.format("schema %q (expected %q)", c.schema, B.SCHEMA) end
  for _, sec in ipairs({ "boss", "epic", "gate" }) do
    if type(t[sec]) == "table" then
      for k, v in pairs(t[sec]) do
        if c[sec][k] ~= nil and type(v) == type(c[sec][k]) then c[sec][k] = v end
      end
    end
  end
  if type(t.ladder) == "table" then
    if type(t.ladder.levels) == "table" then c.ladder.levels = U.nums(t.ladder.levels) end
    c.ladder.stadium = num(t.ladder.stadium, 0) % U.TWO32
  end
  if #c.ladder.levels == 0 then
    warns[#warns + 1] = "[ladder] levels is empty: the default ladder is used"
    c.ladder.levels = B.DEFAULT_LEVELS
  end
  if type(t.tags) == "table" then
    for k, v in pairs(t.tags) do c.tags[k] = strs(v) end
  end
  local seen = {}
  for _, s in ipairs(type(t.special) == "table" and t.special or {}) do
    local id = type(s.id) == "string" and s.id or ""
    local ok_id = id ~= "" and not id:find("[^a-z0-9_]")
    local roles = strs(s.roles)
    local roles_ok = #roles > 0
    for _, r in ipairs(roles) do
      local w = string.lower(U.trim(r))
      if w ~= "boss" and w ~= "gate" and w ~= "epic" then roles_ok = false end
    end
    if not ok_id or seen[id] then
      warns[#warns + 1] = string.format("special %q: id must be a-z 0-9 _ and unique (dropped)", id)
    elseif not roles_ok then
      warns[#warns + 1] = "special " .. id .. ": roles must be boss / gate / epic (dropped)"
    elseif type(s.rival) ~= "string" or s.rival == "" then
      warns[#warns + 1] = "special " .. id .. ": no rival name (dropped)"
    else
      seen[id] = true
      c.special[#c.special + 1] = {
        id = id, rival = s.rival, emblem = num(s.emblem, 0) % U.TWO32,
        stadium = type(s.stadium) == "number" and s.stadium % U.TWO32 or nil, roles = roles, tags = strs(s.tags),
        min_phase = num(s.min_phase, 1), weight = num(s.weight, 1.0), level_bonus = type(s.level_bonus) == "number" and s.level_bonus or nil,
        ladder = U.nums(s.ladder), rules = type(s.rules) == "string" and s.rules or "",
        requires_defeated = strs(s.requires_defeated),
      }
    end
  end
  -- the specials' match rows: game evt_rl_b_<id>, 11v11, tier 3, ladder = difficulty 1..N
  c.rows = {}
  for i, s in ipairs(c.special) do
    local lv = #s.ladder > 0 and s.ladder or c.ladder.levels
    local lad = {}
    for k, l in ipairs(lv) do lad[k] = { math.min(k, 255), l } end
    local game = B.GAME_PREFIX .. s.id
    c.rows[i] = { id = U.crc32(game), name = game, kind = 2, tier = 3, stadium = s.stadium or c.ladder.stadium,
      rival = s.rival, emblem = s.emblem, ladder = lad }
  end
  return c, warns
end

-- the installed catalogue ([rogue.bosses] enabled + a readable file), nil = none
function B.catalogue(cfgb)
  if cat ~= nil then return cat or nil end
  cat = false
  if not cfgb.enabled then
    info("[rogue.bosses] enabled = false (no boss tiers)")
    return nil
  end
  local ok, t = pcall(VRFW.files.toml, cfgb.file)
  if not ok or type(t) ~= "table" then
    warn(cfgb.file .. ": " .. tostring(t) .. "; no boss tiers")
    return nil
  end
  local c, warns = parse(t)
  for _, w in ipairs(warns) do warn(cfgb.file .. ": " .. w) end
  for _, s in ipairs(c.special) do
    if s.rules ~= "" then info("special " .. s.id .. ": rules " .. s.rules .. " declared (no match-rule engine yet: ignored)") end
  end
  info(string.format("%d special bosses; épico from phase %d (%s), puerta from phase %d (%s), special boss chance %s",
    #c.special, c.epic.from_phase, tostring(c.epic.enabled), c.gate.from_phase, tostring(c.gate.enabled),
    tostring(c.boss.special_chance)))
  cat = c
  return c
end

function B.rows()
  return (cat and cat.rows) or {}
end

-- does rule `want` (a team name or an evt_rl_* row name) name `row`?
function B.names(want, row)
  local w = U.trim(want)
  return w ~= "" and (U.eq_ascii(w, row.name) or U.lower(w) == U.lower(row.rival))
end

function B.special_of(c, row)
  if not U.starts(row.name, B.GAME_PREFIX) then return nil end
  local id = row.name:sub(#B.GAME_PREFIX + 1)
  for _, s in ipairs(c.special) do
    if s.id == id then return s end
  end
  return nil
end

-- tag `tag` applies to `row` ([tags], the special's own tags, or the rival pool row's tags column)
function B.tagged(c, row, tag, pool)
  if pool.has_tag(row.id, tag) then return true end
  for _, w in ipairs(c.tags[tag] or {}) do
    if B.names(w, row) then return true end
  end
  local s = B.special_of(c, row)
  if s then
    for _, t in ipairs(s.tags) do
      if U.eq_ascii(t, tag) then return true end
    end
  end
  return false
end

-- `row` held back by a requires_defeated not met yet (`beaten`: a set of lowercase names / rows)
function B.locked_in(c, row, beaten)
  for _, s in ipairs(c.special) do
    if #s.requires_defeated > 0 and (B.names(s.rival, row) or B.GAME_PREFIX .. s.id == row.name) then
      for _, w in ipairs(s.requires_defeated) do
        if not beaten[U.lower(U.trim(w))] then return true end
      end
    end
  end
  return false
end

function B.lifetime(c)
  return U.lower(U.trim(c.requires_scope)) == "lifetime"
end

function B.has_requires(c)
  for _, s in ipairs(c.special) do
    if #s.requires_defeated > 0 then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------------------- the board

local function optional(k) return k == K.ELITE or k == K.EPIC or k == K.GATE end

local function roll(st)
  st.s = U.xs(st.s)
  return (st.s % 10000) / 10000.0
end

local function appears(enabled, from, chance, phase, st)
  local r = roll(st)
  local f = math.max(from, 1)
  return enabled and phase >= f and (phase == f or r < U.clamp(chance, 0, 1))
end

local function put(m, col, kind, st)
  local in_col = {}
  for k = 0, #m.nodes - 1 do
    if m.nodes[k + 1].col == col then in_col[#in_col + 1] = k end
  end
  if #in_col < 2 then return false end
  for _, k in ipairs(in_col) do
    if optional(m.nodes[k + 1].kind) then return false end
  end
  local cand = {}
  for _, k in ipairs(in_col) do
    local kd = m.nodes[k + 1].kind
    if kd == K.SMALL or kd == K.FULL then cand[#cand + 1] = k end
  end
  while #cand > 0 do
    st.s = U.xs(st.s)
    local k = table.remove(cand, st.s % #cand + 1)
    local old = m.nodes[k + 1].kind
    m.nodes[k + 1].kind = kind
    if map.free_path(m, optional) then return true end
    m.nodes[k + 1].kind = old
  end
  return false
end

-- place the phase's «Jefe de puerta» and «Jefe épico» (own seeded stream)
function B.place(m, seed, phase, c)
  phase = math.max(phase, 1)
  local st = { s = math.max(U.xor(U.xor(seed, U.mul32(phase, 0xC2B2AE35)), 0x0B055E55), 1) }
  if m.cols < 3 then return end
  local boss_col = m.cols - 1
  local pre = boss_col - 1
  local gate_col = nil
  if appears(c.gate.enabled, c.gate.from_phase, c.gate.chance, phase, st) and pre >= 2 and put(m, pre, K.GATE, st) then
    gate_col = pre
  end
  if appears(c.epic.enabled, c.epic.from_phase, c.epic.chance, phase, st) then
    local last = gate_col and math.max(pre - 1, 0) or pre
    local cols = {}
    for x = 2, last do cols[#cols + 1] = x end
    local mid = (2 + last) / 2
    -- the most central first (stable: equal distances keep the column order)
    for i = 2, #cols do
      local v = cols[i]
      local j = i - 1
      while j >= 1 and math.abs(cols[j] - mid) > math.abs(v - mid) do
        cols[j + 1] = cols[j]
        j = j - 1
      end
      cols[j + 1] = v
    end
    for _, x in ipairs(cols) do
      if put(m, x, K.EPIC, st) then break end
    end
  end
end

-- ---------------------------------------------------------------------------------------- the draw

local function weighted(cands, st)
  local w, total = {}, 0
  for i, c in ipairs(cands) do
    w[i] = U.round(math.max(c[2], 0) * 1000)
    total = total + w[i]
  end
  if total == 0 then return nil end
  st.s = U.xs(st.s)
  local x = st.s % total
  for i, wk in ipairs(w) do
    if x < wk then return cands[i][1] end
    x = x - wk
  end
  return nil
end

local function sorted_ladder(row)
  local v = {}
  for i, l in ipairs(row.ladder) do v[i] = { l[1], l[2], i } end
  table.sort(v, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[3] < b[3]) end)
  return v
end

-- the ladder row at or above `target` (else the highest) / at or below (else the lowest)
local function at_least(row, target)
  local v = sorted_ladder(row)
  for _, x in ipairs(v) do
    if x[2] >= target then return x[1], x[2] end
  end
  local l = v[#v]
  if l then return l[1], l[2] end
end

local function at_most(row, target)
  local v = sorted_ladder(row)
  for i = #v, 1, -1 do
    if v[i][2] <= target then return v[i][1], v[i][2] end
  end
  local f = v[1]
  if f then return f[1], f[2] end
end

local function pick_row(row, target, up)
  local diff, level
  if up then diff, level = at_least(row, target) else diff, level = at_most(row, target) end
  if not diff then return nil end
  return { row = row, diff = diff, level = level, target = target, game = row.id, guest = 0 }
end

local function has_role(s, r)
  for _, x in ipairs(s.roles) do
    if U.eq_ascii(U.trim(x), r) then return true end
  end
  return false
end

-- the tiered draw of a node: a pick for an épico / puerta node and for a phase boss that rolled a special; nil = the
-- normal draw. `ctx` = { cfg, pool, matches, beaten (set), boss_level }
function B.pick(c, seed, phase, node, kind, cols, rule, ctx)
  if rule < B.RULE or not (kind == K.BOSS or kind == K.EPIC or kind == K.GATE) then return nil end
  local p = math.max(phase, 1)
  local st = { s = math.max(U.xor(U.xor(U.xor(seed, U.mul32(p, 0x27D4EB2F)), U.mul32(node, 0x165667B1)), 0x0B055000), 1) }
  local boss = ctx.boss_level(p, cols)
  local function live(role)
    local o = {}
    for i, s in ipairs(c.special) do
      local r = c.rows[i]
      if has_role(s, role) and s.min_phase <= p and s.weight > 0 and not B.locked_in(c, r, ctx.beaten) then
        o[#o + 1] = { r, s }
      end
    end
    return o
  end
  if kind == K.BOSS then
    local hit = roll(st) < U.clamp(c.boss.special_chance, 0, 1)
    local cands = {}
    for _, x in ipairs(live("boss")) do cands[#cands + 1] = { x[1], x[2].weight } end
    if not hit or #cands == 0 then return nil end
    local row = weighted(cands, st)
    if not row then return nil end
    local sp = B.special_of(c, row)
    if not sp then return nil end
    return pick_row(row, boss + (sp.level_bonus or c.boss.special_level_bonus), true)
  elseif kind == K.EPIC then
    local hi = select(2, ctx.matches.tier_range(K.BOSS, p))
    local cands = {}
    for _, r in ipairs(ctx.pool.source(2)) do
      if r.kind == 2 and r.tier <= hi and not ctx.matches.is_emblematic(ctx.cfg.rivals, r)
        and not B.tagged(c, r, B.BOSS_ONLY, ctx.pool) and not B.locked_in(c, r, ctx.beaten) then
        cands[#cands + 1] = { r, B.tagged(c, r, "minor", ctx.pool) and c.epic.minor_weight or 1.0 }
      end
    end
    for _, x in ipairs(live("epic")) do
      local mm = B.tagged(c, x[1], "minor", ctx.pool) and c.epic.minor_weight or 1.0
      cands[#cands + 1] = { x[1], c.epic.special_weight * x[2].weight * mm }
    end
    local row = weighted(cands, st)
    if not row then return nil end
    local sp = B.special_of(c, row)
    local bonus = (sp and sp.level_bonus) or 0
    return pick_row(row, math.max(boss + bonus - c.epic.level_offset, 1), false)
  else
    local cands = {}
    for _, r in ipairs(ctx.pool.source(2)) do
      if r.kind == 2 and ctx.matches.is_emblematic(ctx.cfg.rivals, r) and not B.locked_in(c, r, ctx.beaten) then
        cands[#cands + 1] = { r, c.gate.emblematic_weight }
      end
    end
    for _, x in ipairs(live("gate")) do cands[#cands + 1] = { x[1], c.gate.special_weight * x[2].weight } end
    local row = weighted(cands, st)
    if not row then return nil end
    local sp = B.special_of(c, row)
    local bonus = (sp and sp.level_bonus) or 0
    return pick_row(row, boss + c.gate.level_offset + bonus, true)
  end
end

return B
