-- Team lineup: who of a team's players play its next match (docs/framework/team-lineup.md). A team plays its roster
-- slots in order (slot 0 the goalkeeper, then the field players; a 5-a-side match its slots 0-4); this service writes
-- the roster slots of the team's member rows in memory (team_config, read again at every match setup, never saved) so
-- the given cards take slots 0.. in that order and every other player keeps his order after them. Reuses the random
-- team's native declarations (content\game\random_team.toml: FindTeamConfig, the record and member layout).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_TEAM_LINEUP | team id, card… | true, rows written; false, why |
-- | CMND_VRFW_TEAM_KIT | team id | the team's kit (uniform id of its team_config record; 0 = none) |
-- | CMND_VRFW_TEAM_LEVEL | team id, row level, level | true, rows: every member plays at `level` (+ his own data offset) |
-- | CMND_VRFW_TEAM_MEMBER_MOVES | team id, roster slot | true, 6 moves, 6 learn levels of his loadout; false, why |
-- | CMND_VRFW_MATCH_MEMBER | chara handle | true, team id, roster slot of the match player's member row; false, why |

TeamLineup = TeamLineup or {}

local function info(...) VRFW.log("team_lineup:", ...) end

local MEMBER_STRIDE = 0x54       -- member row size (team_config member table)
local MEMBER_CARD = 0x20         -- the row's chara_param (u32)
local MEMBER_SLOT = 0x47         -- the row's roster slot (u8)
local MEMBER_LOADOUT = 0x28      -- the row's TEAM_MEMBER_SKILL_CONFIG loadout (u32; 0 = the card's own learn list)
local MAX_ROWS = 64

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok and type(v) == "number" then return v end
  return nil
end

local function wr(ty, at, v)
  if type(at) ~= "number" or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

-- the team_config record and container of team `id` (the game's own lookup): rec, cont; nil, why
local function find_team(id)
  if not VRFW.is_on("RandomTeamFind") then return nil, "FindTeamConfig not resolved" end
  local okb, recb = pcall(VRFW.mem.buffer, "tl_team_rec", 8)
  local okc, contb = pcall(VRFW.mem.buffer, "tl_team_cont", 8)
  local okh, hashb = pcall(VRFW.mem.buffer, "tl_team_hash", 4)
  if not (okb and okc and okh) then return nil, "no native buffer" end
  wr("u64", recb, 0)
  wr("u64", contb, 0)
  wr("u32", hashb, id)
  local ok, e = pcall(VRFW.call, "RandomTeamFind", recb, contb, hashb)
  if not ok then return nil, "FindTeamConfig faulted (" .. tostring(e) .. ")" end
  local rec, cont = rd("ptr", recb) or 0, rd("ptr", contb) or 0
  if rec < 0x10000 or cont < 0x10000 then return nil, string.format("team 0x%08X not in team_config", id) end
  return rec, cont
end

-- CMND_VRFW_TEAM_LINEUP(team, card…): the cards take roster slots 0.. in that order, the other rows follow in their
-- own slot order; staff slots (19, 20) are never touched
function TeamLineup.Set(team, ...)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local want = {}
  for _, c in ipairs({ ... }) do
    want[#want + 1] = math.floor(tonumber(c) or 0) % 4294967296
  end
  local rec, cont = find_team(team)
  if not rec then return false, cont end
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  local base = okc and type(cv) == "table" and cv.Members or nil
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local first = okr and type(rv) == "table" and rv.First or nil
  local count = okr and type(rv) == "table" and rv.Count or nil
  if first then first = first % 65536 end
  if not base or base < 0x10000 or not first or not count or count == 0 or count > MAX_ROWS then
    return false, "member slice unreadable"
  end
  local rows = {}
  for k = 0, count - 1 do
    local a = base + (first + k) * MEMBER_STRIDE
    local card, slot = rd("u32", a + MEMBER_CARD), rd("u8", a + MEMBER_SLOT)
    if card == nil or slot == nil then return false, "member row " .. k .. " unreadable" end
    if slot < 19 then rows[#rows + 1] = { addr = a, card = card, slot = slot } end
  end
  table.sort(rows, function(a, b) return a.slot < b.slot end)
  local order, used = {}, {}
  for _, c in ipairs(want) do
    for _, r in ipairs(rows) do
      if r.card == c and not used[r] then
        used[r] = true
        order[#order + 1] = r
        break
      end
    end
  end
  for _, r in ipairs(rows) do
    if not used[r] then order[#order + 1] = r end
  end
  local slots = {}
  for _, r in ipairs(rows) do slots[#slots + 1] = r.slot end
  local wrote = 0
  for k, r in ipairs(order) do
    if r.slot ~= slots[k] then
      if not wr("u8", r.addr + MEMBER_SLOT, slots[k]) then return false, "write failed" end
      wrote = wrote + 1
    end
  end
  info(string.format("team 0x%08X: %d card(s) first, %d row(s) moved", team, #want, wrote))
  return true, wrote
end

-- CMND_VRFW_TEAM_KIT(team) -> the kit of the team's record (team_config +0x1C)
function TeamLineup.Kit(team)
  local rec = find_team(math.floor(tonumber(team) or 0) % 4294967296)
  if not rec then return 0 end
  local ok, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  return ok and type(rv) == "table" and tonumber(rv.Uniform) or 0
end

-- CMND_VRFW_TEAM_LEVEL(team, row level, level): a member plays at the match row's rival level + his row offset
-- (team_config +0x44); every member's offset becomes his data offset + (level - row level), so the team plays at
-- `level` for its next matches (in memory, never saved). The data offsets are read once per row.
local DATA_OFFSET = {}   -- member row address -> its offset as the data had it
function TeamLineup.Level(team, row_level, level)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local base, want = math.floor(tonumber(row_level) or 0), math.floor(tonumber(level) or 0)
  if base < 1 or want < 1 then return false, "no level" end
  local rec, cont = find_team(team)
  if not rec then return false, cont end
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local mbase = okc and type(cv) == "table" and cv.Members or nil
  local first = okr and type(rv) == "table" and rv.First or nil
  local count = okr and type(rv) == "table" and rv.Count or nil
  if not mbase or mbase < 0x10000 or not first or not count or count == 0 or count > MAX_ROWS then
    return false, "member slice unreadable"
  end
  first = first % 65536
  local n = 0
  for k = 0, count - 1 do
    local a = mbase + (first + k) * MEMBER_STRIDE
    if DATA_OFFSET[a] == nil then
      DATA_OFFSET[a] = rd("i16", a + 0x44) or 0
    end
    local ms = VRFW.mem.struct("RandomTeamMember", a)
    local v = math.max(-998, math.min(998, DATA_OFFSET[a] + want - base))
    if pcall(function() ms.LevelOffset = v end) then n = n + 1 end
  end
  info(string.format("team 0x%08X: level %d (row %d): %d row(s)", team, want, base, n))
  return true, n
end

-- CMND_VRFW_TEAM_MEMBER_MOVES(team, slot) -> true, move1..move6, level1..level6 of the member row in that roster slot as
-- the match plays it (its TEAM_MEMBER_SKILL_CONFIG loadout: special moves and auras, 0 = empty); false, why when the
-- row plays its card's own learn list (loadout 0) or is not found. The player page previewing a team member shows it.
-- The loadout is read from the team_config container the game holds (its loadout rows, the ones the match reads:
-- 0xE25750 looks a loadout up there by id), with one array read for the ids (index kept while the table stays).
local LOADOUT_ROWS = 0xA8        -- container: loadout rows (TEAM_MEMBER_SKILL_CONFIG: id, 6 moves, 6 levels; u32 each)
local LOADOUT_COUNT = 0xB0       -- container: their count (i32)
local LOADOUT_STRIDE = 0x34
local ARRAY_MAX = 4096           -- VRFW.mem.read_array's largest read
local EMPTY_MOVE = 0xFB997A80
local INDEX = { base = nil, count = nil, rows = nil }   -- loadout id -> row index of the container's table

local function loadout_row(cont, id)
  local base, count = rd("ptr", cont + LOADOUT_ROWS), rd("i32", cont + LOADOUT_COUNT)
  if not base or base < 0x10000 or not count or count <= 0 then return nil, "loadout table unreadable" end
  if INDEX.base ~= base or INDEX.count ~= count then
    local rows = {}
    for start = 0, count - 1, ARRAY_MAX do
      local n = math.min(ARRAY_MAX, count - start)
      local ok, ids = pcall(VRFW.mem.read_array, "u32", base + start * LOADOUT_STRIDE, n, LOADOUT_STRIDE)
      if not ok or type(ids) ~= "table" then return nil, "loadout ids unreadable" end
      for k = 1, n do rows[ids[k]] = start + k - 1 end
    end
    INDEX.base, INDEX.count, INDEX.rows = base, count, rows
  end
  local i = INDEX.rows[id]
  if not i then return nil, string.format("loadout 0x%08X not in the team table", id) end
  local ok, v = pcall(VRFW.mem.read_array, "u32", base + i * LOADOUT_STRIDE, 13)
  if not ok or type(v) ~= "table" or v[1] ~= id then return nil, "loadout row unreadable" end
  return v
end

function TeamLineup.MemberMoves(team, slot)
  team = math.floor(tonumber(team) or 0) % 4294967296
  slot = math.floor(tonumber(slot) or -1)
  local rec, cont = find_team(team)
  if not rec then return false, cont end
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local mbase = okc and type(cv) == "table" and cv.Members or nil
  local first = okr and type(rv) == "table" and rv.First or nil
  local count = okr and type(rv) == "table" and rv.Count or nil
  if not mbase or mbase < 0x10000 or not first or not count or count == 0 or count > MAX_ROWS then
    return false, "member slice unreadable"
  end
  first = first % 65536
  for k = 0, count - 1 do
    local a = mbase + (first + k) * MEMBER_STRIDE
    if rd("u8", a + MEMBER_SLOT) == slot then
      local lid = rd("u32", a + MEMBER_LOADOUT) or 0
      if lid == 0 then return false, "the card's own learn list" end
      local v, why = loadout_row(cont, lid)
      if not v then return false, why end
      local m = {}
      for i = 2, 7 do m[#m + 1] = v[i] == EMPTY_MOVE and 0 or v[i] end
      return true, m[1], m[2], m[3], m[4], m[5], m[6], v[8], v[9], v[10], v[11], v[12], v[13]
    end
  end
  return false, "no member in slot " .. slot
end

-- CMND_VRFW_MATCH_MEMBER(chara handle) -> true, team, slot of the member row a match player plays from; false, why.
-- The match's teams are the ones its request named (StartMatchRequest +0xA4 the player's team, +0xA8 the rival), written
-- natively by the hook TeamLineup.MatchRequest (content\game\random_team.toml) into a block of this script; they count
-- between match_start and match_end. A player the user owns (VRFW.chara.user_owned) plays his own set: no member.
-- The player page shown in a match (the pause «Formación») names this member, as a line-up viewer names one.
local MATCH_TEAMS_KEY = "vr_framework.team_lineup.match_teams"
local MATCH = { block = nil, on = false }
do
  local ok, block = pcall(VRFW.mem.buffer, "tl_match_teams", 8)
  if ok and type(block) == "number" and pcall(VRFW.state.set, MATCH_TEAMS_KEY, block) then
    MATCH.block = block
    wr("u64", block, 0)
  else
    VRFW.warn("team_lineup: the match teams block is not set up: a match player's page shows his card's set")
  end
end
VRFW.on("match_start", function() MATCH.on = true return nil end)
VRFW.on("match_end", function() MATCH.on = false return nil end)
VRFW.on("game_reset", function() MATCH.on = false return nil end)

-- the roster slot of card `card` in team `team` (staff slots left out); nil when he is not a member
local function member_slot(team, card)
  local rec, cont = find_team(team)
  if not rec then return nil end
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local mbase = okc and type(cv) == "table" and cv.Members or nil
  local first = okr and type(rv) == "table" and rv.First or nil
  local count = okr and type(rv) == "table" and rv.Count or nil
  if not mbase or mbase < 0x10000 or not first or not count or count == 0 or count > MAX_ROWS then return nil end
  first = first % 65536
  for k = 0, count - 1 do
    local a = mbase + (first + k) * MEMBER_STRIDE
    local slot = rd("u8", a + MEMBER_SLOT)
    if slot and slot < 19 and rd("u32", a + MEMBER_CARD) == card then return slot end
  end
  return nil
end

function TeamLineup.MatchMember(hdl)
  hdl = math.floor(tonumber(hdl) or 0) % 4294967296
  if not MATCH.on or not MATCH.block then return false, "no match" end
  if hdl == 0 then return false, "no character" end
  local okw, own = pcall(VRFW.chara.user_owned, hdl)
  if okw and own ~= nil then return false, "the user's own player" end
  local okr, r = pcall(VRFW.chara.record, hdl)
  local card = okr and type(r) == "table" and tonumber(r.param) or nil
  if not card or card == 0 then return false, "not a character" end
  card = card % 4294967296
  for _, at in ipairs({ 0, 4 }) do
    local team = rd("u32", MATCH.block + at)
    if team and team ~= 0 then
      local slot = member_slot(team, card)
      if slot then return true, team, slot end
    end
  end
  return false, string.format("card 0x%08X is in neither team of the match", card)
end
