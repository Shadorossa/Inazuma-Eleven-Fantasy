-- InaRogue › INAROGUE: the match pool's rows (docs/game/modes/inarogue.md §14, §15; inarogue-pachangas.md §4-5).
-- Was match_data.rs, teams.rs, ranks.rs and variety.rs of the DLL's module rogue.
--
-- * The Chronicle / pachanga clones `evt_rl_*` (content\rogue\match_rows.toml, research/scripts/rogue_match_build.py).
-- * INAROGUE's own rivals: data/common/gamedata/roguelite/roguelite_team.cfg.bin, the rows of the pool lists
--   (content\teams\lists.toml): since 2026-10-14 only the random-team slot teams (tag `random`; the ~1 460
--   pre-generated rival teams are gone, decisions 10-11 of docs/refactor/roguelite-split-map.md): checked like the DLL did (game id = crc32 of its evt_rl_t_* name, tier 1-4, a
--   ladder, 5 / 11 distinct players with the goalkeeper in slot 0); columns `tags`, `format`, `rank`.
-- * Strength ranks and phase bands (content\rogue\rival_ranks.toml, [rogue.rivals] ranks).
-- * Variety: the rival of a node comes from a per-run permutation of its pool; squads met in the last 6 other runs are
--   skipped while the pool has others (global blob rogue_rivals_seen.json, the DLL's JSON).
--
-- A row: { id, name, kind (1 5v5, 2 11v11), tier, stadium, rival, emblem, ladder = { { difficulty, level }, … } }.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local info, warn = U.logger("rogue")

local P = {}

P.KIND_SMALL, P.KIND_FULL = 1, 2

-- ---------------------------------------------------------------------------------------- the clones

local clones = nil

function P.clones()
  if clones then return clones end
  clones = {}
  local ok, t = pcall(VRFW.files.toml, "content/rogue/match_rows.toml")
  if not ok or type(t) ~= "table" or type(t.row) ~= "table" then
    warn("content/rogue/match_rows.toml not readable (" .. tostring(t) .. "): no match pool")
    return clones
  end
  for _, r in ipairs(t.row) do
    local lad = {}
    for _, l in ipairs(r.ladder or {}) do lad[#lad + 1] = { l[1], l[2] } end
    clones[#clones + 1] = { id = r.id % U.TWO32, name = r.name, kind = r.kind, tier = r.tier, stadium = r.stadium % U.TWO32,
      rival = r.rival, emblem = r.emblem % U.TWO32, ladder = lad }
  end
  return clones
end

-- ---------------------------------------------------------------------------------------- the own rivals (§15)

local own = nil       -- rows
local own_tags = {}   -- game id -> tags text
local own_ranks = {}  -- game id -> rank 0-1000

local KEY = "data/common/gamedata/roguelite/roguelite_team.cfg.bin"
local NAMES = { "ROGUE_TEAM_HEADER", "ROGUE_TEAM_INFO", "ROGUE_TEAM_MEMBER", "ROGUE_TEAM_DIFFICULTY" }
local GAME_PREFIX, POS_GK, VERSION = "evt_rl_t_", 1, 1

local function iv(e, i)
  local v = e[i + 1]
  if type(v) ~= "number" then return nil end
  return v
end
local function hv(e, i)
  local v = iv(e, i)
  return v and v % U.TWO32 or nil
end
local function tv(e, i)
  local v = e[i + 1]
  if type(v) == "string" then return v end
  return ""
end

local function check(t, m, lad)
  if not U.starts(t.game, GAME_PREFIX) or U.crc32(t.game) ~= t.game_id then
    return string.format("game id 0x%08X is not crc32 of an %s* name", t.game_id, GAME_PREFIX)
  end
  if t.tier < 1 or t.tier > 4 then return "tier " .. t.tier end
  if t.team_id == 0 or t.name == "" then return "no team id / name" end
  if #lad == 0 then return "no difficulty rows" end
  local ds = {}
  for _, l in ipairs(lad) do
    if l[1] < 1 or l[1] > 255 or l[2] < 1 or l[2] > 999 or ds[l[1]] then
      return string.format("bad ladder row (difficulty %d, level %d)", l[1], l[2])
    end
    ds[l[1]] = true
  end
  local need = t.full and 11 or 5
  if #m ~= need then return string.format("%d players (needs %d)", #m, need) end
  local slots, params = {}, {}
  local ns, np = 0, 0
  for _, x in ipairs(m) do
    if not slots[x.slot] then slots[x.slot] = true; ns = ns + 1 end
    if not params[x.param] then params[x.param] = true; np = np + 1 end
  end
  if ns ~= need or np ~= need or params[0] then return "duplicate slot / player" end
  local gks = 0
  for _, x in ipairs(m) do
    if x.pos == POS_GK then gks = gks + 1 end
  end
  if m[1].slot ~= 0 or m[1].pos ~= POS_GK or gks ~= 1 then return "needs exactly one goalkeeper, in slot 0" end
  return nil
end

local function load_own()
  own = {}
  local ok, ents = pcall(VRFW.table.entries, KEY, NAMES, true)
  if not ok or type(ents) ~= "table" then
    info("rogue teams: no " .. KEY .. " (research/scripts/rogue_teams_build.py): pachangas use the evt_rl_s_* clones (§14)")
    return
  end
  local teams, members, ladders = {}, {}, {}
  for _, e in ipairs(ents) do
    if e.name == "ROGUE_TEAM_HEADER" then
      local ver = iv(e, 0) or 0
      if ver < 1 or ver > VERSION then
        warn(string.format("rogue teams: %s: file version %d (this loader reads 1..=%d): pachangas use the clones", KEY, ver, VERSION))
        return
      end
    elseif e.name == "ROGUE_TEAM_INFO" then
      local rank = iv(e, 16)
      teams[#teams + 1] = { no = (iv(e, 0) or -1) % U.TWO32, team_id = hv(e, 1) or 0, name = tv(e, 3), game_id = hv(e, 4) or 0,
        game = tv(e, 5), tier = U.clamp(iv(e, 6) or 0, 0, 255), stadium = hv(e, 7) or 0, emblem = hv(e, 8) or 0,
        tags = U.lower(tv(e, 14)), full = iv(e, 15) == 11, rank = (rank and rank >= 0 and rank <= 1000) and rank or nil }
    elseif e.name == "ROGUE_TEAM_MEMBER" then
      local no = (iv(e, 0) or -1) % U.TWO32
      members[no] = members[no] or {}
      local l = members[no]
      l[#l + 1] = { slot = U.clamp(iv(e, 1) or 255, 0, 255), param = hv(e, 2) or 0, pos = U.clamp(iv(e, 3) or 0, 0, 255) }
    elseif e.name == "ROGUE_TEAM_DIFFICULTY" then
      local no = (iv(e, 0) or -1) % U.TWO32
      ladders[no] = ladders[no] or {}
      local l = ladders[no]
      l[#l + 1] = { iv(e, 1) or 0, iv(e, 2) or 0 }
    end
  end
  if #teams == 0 then
    warn("rogue teams: " .. KEY .. " unreadable (no ROGUE_TEAM_INFO row): pachangas use the evt_rl_s_* clones")
    return
  end
  local nos, games, problems, kept = {}, {}, {}, {}
  for _, t in ipairs(teams) do
    local m = members[t.no] or {}
    table.sort(m, function(a, b) return a.slot < b.slot end)
    local lad = ladders[t.no] or {}
    local why = check(t, m, lad)
    if not why and nos[t.no] then why = "duplicate team number" end
    if not why then nos[t.no] = true end
    if not why and games[t.game_id] then why = "duplicate game id" end
    if not why then games[t.game_id] = true end
    if why then
      problems[#problems + 1] = string.format("team %d %q (%s): %s", t.no, t.name, t.game, why)
    else
      table.sort(lad, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
      t.ladder = lad
      kept[#kept + 1] = t
    end
  end
  table.sort(kept, function(a, b) return a.no < b.no end)
  for k, w in ipairs(problems) do
    if k > 8 then
      warn(string.format("rogue teams: ... %d more dropped", #problems - 8))
      break
    end
    warn("rogue teams: dropped " .. w)
  end
  if #kept == 0 then
    warn("rogue teams: " .. KEY .. " has no valid team: pachangas use the evt_rl_s_* clones")
    return
  end
  local tiers, full, retired = { 0, 0, 0, 0 }, 0, 0
  for _, t in ipairs(kept) do
    if t.tags ~= "" then own_tags[t.game_id] = t.tags end
    if t.rank then own_ranks[t.game_id] = t.rank end
    own[#own + 1] = { id = t.game_id, name = t.game, kind = t.full and P.KIND_FULL or P.KIND_SMALL, tier = t.tier,
      stadium = t.stadium, rival = t.name, emblem = t.emblem, ladder = t.ladder }
    if t.full then full = full + 1 elseif tiers[t.tier] then tiers[t.tier] = tiers[t.tier] + 1 end
    if P.has_tag(t.game_id, "retired") then retired = retired + 1 end
  end
  info(string.format("rogue teams: %d own rivals from %s (5v5 tiers 1-4 = [%d, %d, %d, %d], 11v11 %d, retired %d, %d dropped)",
    #own, KEY, tiers[1], tiers[2], tiers[3], tiers[4], full, retired, #problems))
end

-- a row of the pool table that is a random-team slot (tag `random`, content\teams\random_slots.toml): its rival is built
-- by the VR-Framework's random team service right before the match (docs/framework/random-team.md)
function P.is_random(row)
  return row ~= nil and row.id ~= nil and P.has_tag(row.id, "random")
end

-- the random-team rule of a slot row (by its format): [rogue.rivals] random_small / random_full
function P.random_rule(rv, row)
  return row.kind == P.KIND_FULL and rv.random_full or rv.random_small
end

-- the own rivals (empty = the §14 clones are the pachanga pool)
function P.own()
  if not own then load_own() end
  return own
end

function P.tags_of(id)
  P.own()
  return own_tags[id] or ""
end

function P.has_tag(id, tag)
  for t in string.gmatch(P.tags_of(id), "[^,]+") do
    if U.eq_ascii(U.trim(t), tag) then return true end
  end
  return false
end

function P.own_rank(id)
  P.own()
  return own_ranks[id]
end

-- every row of pool kind `pk`: the own 5v5 rows (else the clones) for pachangas; the clones + the own 11v11 rows for
-- 11v11 / Élite / boss. Rows tagged `retired` are never drawn.
function P.source(pk)
  local o = {}
  local mine = P.own()
  if pk == P.KIND_SMALL then
    for _, r in ipairs(mine) do
      if r.kind == pk and not P.has_tag(r.id, "retired") then o[#o + 1] = r end
    end
    if #o > 0 then return o end
    for _, r in ipairs(P.clones()) do
      if r.kind == pk then o[#o + 1] = r end
    end
    return o
  end
  for _, r in ipairs(P.clones()) do
    if r.kind == pk then o[#o + 1] = r end
  end
  for _, r in ipairs(mine) do
    if r.kind == pk and not P.has_tag(r.id, "retired") then o[#o + 1] = r end
  end
  return o
end

-- ---------------------------------------------------------------------------------------- ranks (inarogue-pachangas.md §4)

local ranks = nil -- false = none

local RANK_SCHEMA = "inazuma_fantasy.rogue_ranks/1"

local function load_ranks(rel)
  if rel == nil or rel == "" then return false end
  local ok, t = pcall(VRFW.files.toml, rel)
  if not ok or type(t) ~= "table" then
    warn("rogue ranks: " .. rel .. ": " .. tostring(t) .. "; the tier windows stay")
    return false
  end
  if t.schema ~= nil and t.schema ~= "" and t.schema ~= RANK_SCHEMA then
    warn("rogue ranks: " .. rel .. ": schema `" .. tostring(t.schema) .. "` (expected `" .. RANK_SCHEMA .. "`); the tier windows stay")
    return false
  end
  local b = type(t.band) == "table" and t.band or {}
  local band = {
    curve = { { 1, 50 }, { 5, 250 }, { 10, 450 }, { 20, 650 }, { 35, 800 }, { 50, 900 }, { 70, 970 } },
    width = 70, elite = 60, boss = 90, epic = 40, gate = 160, spread = 3, min_rows = 6,
  }
  if type(b.curve) == "table" then
    band.curve = {}
    for _, k in ipairs(b.curve) do band.curve[#band.curve + 1] = { k[1], k[2] } end
  end
  for _, k in ipairs({ "width", "elite", "boss", "epic", "gate", "spread", "min_rows" }) do
    if type(b[k]) == "number" then band[k] = b[k] end
  end
  if #band.curve == 0 or band.width <= 0 then
    warn("rogue ranks: " .. rel .. ": [band] needs a curve and a width > 0; the tier windows stay")
    return false
  end
  local rows, n = {}, 0
  if type(t.rows) == "table" then
    for k, v in pairs(t.rows) do
      if type(v) == "number" then
        rows[k] = v
        n = n + 1
      end
    end
  end
  info(string.format("rogue ranks: %s (%d row ranks, band width %s, %d curve keys)", rel, n, tostring(band.width), #band.curve))
  return { band = band, rows = rows }
end

function P.ranks(rel)
  if ranks == nil then ranks = load_ranks(rel) end
  return ranks or nil
end

local function centre(f, phase)
  local p = math.max(phase, 1)
  local prev = nil
  for _, k in ipairs(f.band.curve) do
    if k[1] >= p then
      if prev and k[1] > prev[1] then return prev[2] + (k[2] - prev[2]) * (p - prev[1]) / (k[1] - prev[1]) end
      return k[2]
    end
    prev = k
  end
  return prev and prev[2] or 500
end

local KIND = { ELITE = 7, BOSS = 3, EPIC = 8, GATE = 9 }

function P.band(f, kind, phase)
  local c = centre(f, phase)
  local b = f.band
  if kind == KIND.ELITE then return c, c + b.width + b.elite end
  if kind == KIND.BOSS then return c + b.width / 2, c + b.width + b.boss end
  if kind == KIND.EPIC then return c, c + b.width + b.epic end
  if kind == KIND.GATE then return c + b.width + b.boss / 2, c + b.width + b.gate end
  return c - b.width, c + b.width
end

function P.rank_of(f, row)
  return P.own_rank(row.id) or f.rows[row.name]
end

-- the rows inside the band of `kind` / `phase` (widened while too few); nil = no row has a rank
function P.rank_filter(f, rows, kind, phase)
  local ranked = {}
  for _, r in ipairs(rows) do
    local k = P.rank_of(f, r)
    if k then ranked[#ranked + 1] = { r, k } end
  end
  if #ranked == 0 then return nil end
  local lo, hi = P.band(f, kind, phase)
  local need = math.min(math.max(f.band.min_rows, 1), #ranked)
  for step = 0, 6 do
    local pad = step * f.band.width
    local v = {}
    for _, x in ipairs(ranked) do
      if x[2] >= lo - pad and x[2] <= hi + pad then v[#v + 1] = x[1] end
    end
    if #v >= need then return v end
  end
  local all = {}
  for i, x in ipairs(ranked) do all[i] = x[1] end
  return all
end

-- level shift of `row` on a node of `kind` in `phase`: its place in the band, -spread ..= +spread
function P.level_shift(f, row, kind, phase)
  local k = P.rank_of(f, row)
  if not k then return 0 end
  local lo, hi = P.band(f, kind, phase)
  local mid = (lo + hi) / 2
  local half = math.max((hi - lo) / 2, 1)
  return U.round(U.clamp((k - mid) / half, -1, 1) * f.band.spread)
end

-- ---------------------------------------------------------------------------------------- variety (§5)

P.SEEN_BLOB, P.KEEP_RUNS, P.PHASE_STRIDE = "rogue_rivals_seen.json", 6, 64

local seen = nil -- { runs = { { seed, { ids } }, … } }

local function xs1(s)
  return U.xs(math.max(s, 1))
end

local function load_seen()
  if seen then return true end
  local text = U.blob_read(P.SEEN_BLOB, "global")
  if text == false then return false end -- store not running yet: nothing remembered, tried again next time
  seen = { runs = {} }
  if text then
    local j = U.json(text)
    if type(j) == "table" and type(j.runs) == "table" then
      for _, r in ipairs(j.runs) do
        if type(r) == "table" and type(r[1]) == "number" and type(r[2]) == "table" then
          seen.runs[#seen.runs + 1] = { r[1], U.nums(r[2]) }
        end
      end
    end
  end
  info(string.format("rogue variety: %d recent run(s) remembered (%s)", #seen.runs, P.SEEN_BLOB))
  return true
end

local function recent_except(seed)
  local o = {}
  if not seen then return o end
  for _, r in ipairs(seen.runs) do
    if r[1] ~= seed then
      for _, id in ipairs(r[2]) do o[id] = true end
    end
  end
  return o
end

-- index (1-based) in `rows` of the rival of node `node` in `phase` of run `seed`, skipping recent squads while it can
function P.variety_index(rows, seed, phase, node)
  load_seen()
  local recent = recent_except(seed)
  local n = #rows
  if n <= 1 then return 1 end
  local ids = {}
  for i, r in ipairs(rows) do ids[i] = { r.id, i } end
  table.sort(ids, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
  local key = 0x811C9DC5
  for _, x in ipairs(ids) do key = U.mul32(U.xor(key, x[1]), 0x01000193) end
  local s = U.xor(U.xor(seed, key), 0x56415249)
  for k = n - 1, 1, -1 do
    s = xs1(s)
    local j = s % (k + 1)
    ids[k + 1], ids[j + 1] = ids[j + 1], ids[k + 1]
  end
  local ord = (math.max(phase, 1) - 1) * P.PHASE_STRIDE + node
  for k = 0, n - 1 do
    local i = ids[(ord + k) % n + 1][2]
    if not recent[rows[i].id] then return i end
  end
  return ids[ord % n + 1][2]
end

-- a match of run `seed` against game `id` was reserved: remember it (saved at once)
function P.variety_record(seed, id)
  if not load_seen() then return end
  for _, r in ipairs(seen.runs) do
    if r[1] == seed then
      if U.contains(r[2], id) then return end
      r[2][#r[2] + 1] = id
      P.save_seen()
      return
    end
  end
  seen.runs[#seen.runs + 1] = { seed, { id } }
  while #seen.runs > P.KEEP_RUNS do table.remove(seen.runs, 1) end
  P.save_seen()
end

function P.save_seen()
  local runs = {}
  for i, r in ipairs(seen.runs) do runs[i] = J.arr({ r[1], J.arr(r[2]) }) end
  local ok, why = U.blob_write(P.SEEN_BLOB, J.compact(J.obj({ { "runs", J.arr(runs) } })), "global")
  if not ok then warn("rogue variety: " .. tostring(why)) end
end

return P
