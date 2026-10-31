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
-- | CMND_VRFW_TEAM_ROSTER | team id, slot, card, slot, card… | true, rows written: those slots play those cards; false, why |
-- | CMND_VRFW_TEAM_ROSTER_RESTORE | team id (0 = every team written) | true, rows: the data's cards back |
-- | CMND_VRFW_TEAM_STAND_IN | slot team id, source team id, card… | true, players: the slot team plays as the source with these cards |
-- | CMND_VRFW_TEAM_STAND_IN_RESTORE | slot team id (0 = every one) | true, teams: the slot team's data back |
-- | CMND_VRFW_TEAM_STAND_IN_FORMATION | slot team id, formation id | true: the standing-in slot team plays that formation |
-- | CMND_VRFW_TEAM_STAND_IN_LOOK | slot team id, kit, emblem, coach card | true: the standing-in slot team wears / has them |
-- | CMND_VRFW_TEAM_LOOK | team id | true, level, formation, kit, emblem, coach card (0 = none); false, why |
-- | CMND_VRFW_TEAM_MEMBER_LEVELS | team id, base (0 = the record's level), level… | true, rows: roster slots 0.. play at those levels |

TeamLineup = TeamLineup or {}

require "VRFW/lib/basics"
local info = VRFW.logger("team_lineup")

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

-- ------------------------------------------------------------------------------------------------ roster

-- member row address -> { team, card, uid, skill } as the data had it (kept from the first write until restored)
local ROSTER_DATA = {}

-- the team's player rows (slot < 19) by roster slot: { [slot] = row address }; nil, why
local function player_rows(team)
  local rec, cont = find_team(team)
  if not rec then return nil, cont end
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local mbase = okc and type(cv) == "table" and cv.Members or nil
  local first = okr and type(rv) == "table" and rv.First or nil
  local count = okr and type(rv) == "table" and rv.Count or nil
  if not mbase or mbase < 0x10000 or not first or not count or count == 0 or count > MAX_ROWS then
    return nil, "member slice unreadable"
  end
  first = first % 65536
  local rows = {}
  for k = 0, count - 1 do
    local a = mbase + (first + k) * MEMBER_STRIDE
    local slot = rd("u8", a + MEMBER_SLOT)
    if slot == nil then return nil, "member row " .. k .. " unreadable" end
    if slot < 19 then rows[slot] = a end
  end
  return rows
end

-- one member row plays `card` (its card, uid and loadout 0: the card's own learn list)
local function write_member(a, card, uid, skill)
  local ms = VRFW.mem.struct("RandomTeamMember", a)
  local ok = pcall(function()
    ms.Param = card
    ms.Uid = uid
    ms.Skill = skill
  end)
  return ok and rd("u32", a + MEMBER_CARD) == card
end

-- CMND_VRFW_TEAM_ROSTER(team, slot, card, slot, card…): the member row in each roster slot plays that card for the
-- team's next matches (in memory, never saved; the row's level offset, AI step and slot stay). A slot the team has no
-- player row in is skipped. The data's cards come back with CMND_VRFW_TEAM_ROSTER_RESTORE.
function TeamLineup.Roster(team, ...)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local args = { ... }
  local rows, why = player_rows(team)
  if not rows then return false, why end
  local wrote, skipped = 0, 0
  for i = 1, #args - 1, 2 do
    local slot = math.floor(tonumber(args[i]) or -1)
    local card = math.floor(tonumber(args[i + 1]) or 0) % 4294967296
    local a = rows[slot]
    if a == nil or card == 0 then
      skipped = skipped + 1
    else
      if ROSTER_DATA[a] == nil then
        local okm, m = pcall(VRFW.mem.read_struct, "RandomTeamMember", a)
        if not okm or type(m) ~= "table" or m.Param == nil or m.Uid == nil or m.Skill == nil then
          return false, "member row of slot " .. slot .. " unreadable"
        end
        ROSTER_DATA[a] = { team = team, card = m.Param, uid = m.Uid, skill = m.Skill }
      end
      if rd("u32", a + MEMBER_CARD) ~= card then
        if not write_member(a, card, card, 0) then return false, "write failed (slot " .. slot .. ")" end
        wrote = wrote + 1
      end
    end
  end
  info(string.format("team 0x%08X: roster of %d slot(s), %d row(s) written, %d skipped", team, math.floor(#args / 2),
    wrote, skipped))
  return true, wrote
end

-- CMND_VRFW_TEAM_ROSTER_RESTORE(team): the data's cards back in the rows CMND_VRFW_TEAM_ROSTER wrote (0 = every team)
function TeamLineup.RosterRestore(team)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local n = 0
  for a, d in pairs(ROSTER_DATA) do
    if team == 0 or d.team == team then
      if d.card and d.uid and d.skill and write_member(a, d.card, d.uid, d.skill) then n = n + 1 end
      ROSTER_DATA[a] = nil
    end
  end
  info(string.format("roster restore %s: %d row(s)", team == 0 and "every team" or string.format("team 0x%08X", team), n))
  return true, n
end

-- ------------------------------------------------------------------------------------------------ stand-in team

local ROW_WORDS = math.floor(MEMBER_STRIDE / 4)    -- a member row as u32 words (copied whole)
local RECORD_STRIDE = 0x50              -- team_config record array stride
local REC_FIRST, REC_COUNT = 0x28, 0x2C -- the record's member slice
local STAFF_SLOT = 19                   -- roster slots 19 / 20: coach and manager
local LOOK_FIELDS = { "Level", "NameText", "Formation", "Uniform", "Emblem" }
local STAND_IN = {}                     -- slot team id -> its data as first read (record, slice, rows), until restored

local function hex(n) return string.format("0x%08X", math.floor(tonumber(n) or 0) % 4294967296) end

-- the team's record, container and member slice: { rec, cont, base, first, count, rows = { { addr, slot, card, words } } }
local function read_slice(team)
  local rec, cont = find_team(team)
  if not rec then return nil, cont end
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local base = okc and type(cv) == "table" and cv.Members or nil
  local first = okr and type(rv) == "table" and rv.First or nil
  local count = okr and type(rv) == "table" and rv.Count or nil
  if not base or base < 0x10000 or not first or not count or count == 0 or count > MAX_ROWS then
    return nil, "member slice unreadable"
  end
  first = first % 65536
  local rows = {}
  for k = 0, count - 1 do
    local a = base + (first + k) * MEMBER_STRIDE
    local okw, words = pcall(VRFW.mem.read_array, "u32", a, ROW_WORDS)
    local slot = rd("u8", a + MEMBER_SLOT)
    if not okw or type(words) ~= "table" or #words ~= ROW_WORDS or slot == nil then
      return nil, "member row " .. k .. " unreadable"
    end
    rows[#rows + 1] = { addr = a, slot = slot, words = words, card = words[math.floor(MEMBER_CARD / 4) + 1] }
  end
  return { rec = rec, cont = cv, base = base, first = first, count = count, rows = rows }
end

-- true when no other team_config record uses rows of this slice (a stand-in write must touch one team only)
local function own_rows(team, sl)
  local recs, nrec = sl.cont.Records, sl.cont.RecordCount
  if not recs or recs < 0x10000 or not nrec or nrec <= 0 then return false, "record table unreadable" end
  local done = 0
  while done < nrec do
    local take = math.min(4096, nrec - done)
    local at = recs + done * RECORD_STRIDE
    local ok1, ids = pcall(VRFW.mem.read_array, "u32", at, take, RECORD_STRIDE)
    local ok2, fs = pcall(VRFW.mem.read_array, "u32", at + REC_FIRST, take, RECORD_STRIDE)
    local ok3, cs = pcall(VRFW.mem.read_array, "u32", at + REC_COUNT, take, RECORD_STRIDE)
    if not (ok1 and ok2 and ok3) or type(ids) ~= "table" or type(fs) ~= "table" or type(cs) ~= "table" then
      return false, "record table unreadable"
    end
    for k = 1, take do
      if recs + (done + k - 1) * RECORD_STRIDE ~= sl.rec and ids[k] ~= team then
        local f2, c2 = fs[k] % 65536, cs[k]
        if c2 > 0 and f2 < sl.first + sl.count and sl.first < f2 + c2 then
          return false, "member rows shared with team " .. hex(ids[k])
        end
      end
    end
    done = done + take
  end
  return true
end

-- the slot team's data as first read (kept until restored; read again when the table was reloaded)
local function stand_in_data(team)
  local s = STAND_IN[team]
  local sl, why = read_slice(team)
  if not sl then return nil, why end
  if s and s.rec == sl.rec and s.first == sl.first then return s end
  local ok, why2 = own_rows(team, sl)
  if not ok then return nil, why2 end
  local r = VRFW.mem.struct("RandomTeamRecord", sl.rec)
  local look = {}
  for _, f in ipairs(LOOK_FIELDS) do look[f] = r[f] end
  local players, staff = {}, {}
  for _, x in ipairs(sl.rows) do
    if x.slot < STAFF_SLOT then players[#players + 1] = x else staff[#staff + 1] = x end
  end
  table.sort(players, function(a, b) return a.slot < b.slot end)
  s = { rec = sl.rec, base = sl.base, first = sl.first, count = sl.count, rows = sl.rows, players = players,
    staff = staff, look = look }
  STAND_IN[team] = s
  return s
end

local function put_row(a, words)
  return (pcall(VRFW.mem.write_array, "u32", a, words))
end

-- CMND_VRFW_TEAM_STAND_IN(slot team, source team, card…): the slot team (a team declared with player rows of its own)
-- plays as the source team in its next matches: the source's level, name, formation, kit and emblem, and the cards in
-- roster slots 0.. in order (at most the slot team's player rows). A card that has a row in the source team takes a
-- copy of that row (number, captain, boots, moves, level offset); another card takes the source's row of its slot when
-- that row's card is not listed, else the slot team's own row, with the card's own learn list. The member slice
-- shrinks to these rows and the staff rows, so no placeholder plays. In memory only;
-- CMND_VRFW_TEAM_STAND_IN_RESTORE puts the data back.
function TeamLineup.StandIn(team, source, ...)
  team = math.floor(tonumber(team) or 0) % 4294967296
  source = math.floor(tonumber(source) or 0) % 4294967296
  local s, why = stand_in_data(team)
  if not s then return false, "slot team " .. hex(team) .. ": " .. tostring(why) end
  local src, why2 = read_slice(source)
  if not src then return false, "source team " .. hex(source) .. ": " .. tostring(why2) end
  local cards = {}
  for _, c in ipairs({ ... }) do
    c = math.floor(tonumber(c) or 0) % 4294967296
    if c ~= 0 and #cards < #s.players then cards[#cards + 1] = c end
  end
  if #cards == 0 then return false, "no card" end
  local listed, by_card, by_slot = {}, {}, {}
  for _, c in ipairs(cards) do listed[c] = true end
  for _, x in ipairs(src.rows) do
    if x.slot < STAFF_SLOT then
      if by_card[x.card] == nil then by_card[x.card] = x end
      by_slot[x.slot] = x
    end
  end
  local copied, other = 0, 0
  for k, c in ipairs(cards) do
    local slot = k - 1
    local own = by_card[c]
    local vacated = by_slot[slot]
    if vacated and listed[vacated.card] then vacated = nil end
    local tpl = own or vacated or s.players[k]
    local words = {}
    for i = 1, ROW_WORDS do words[i] = tpl.words[i] end
    local a = s.base + (s.first + slot) * MEMBER_STRIDE
    if not put_row(a, words) or not wr("u8", a + MEMBER_SLOT, slot) then
      return false, "write failed (slot " .. slot .. ")"
    end
    if own then
      copied = copied + 1
    else
      local ms = VRFW.mem.struct("RandomTeamMember", a)
      local ok = pcall(function()
        ms.Param = c
        ms.Uid = c
        ms.Skill = 0
        ms.LevelOffset = 0
      end)
      if not ok or rd("u32", a + MEMBER_CARD) ~= c then return false, "write failed (slot " .. slot .. ")" end
      other = other + 1
    end
  end
  for i, x in ipairs(s.staff) do
    if not put_row(s.base + (s.first + #cards + i - 1) * MEMBER_STRIDE, x.words) then
      return false, "staff row write failed"
    end
  end
  if not wr("u32", s.rec + REC_COUNT, #cards + #s.staff) then return false, "slice count write failed" end
  s.placed = #cards
  local r = VRFW.mem.struct("RandomTeamRecord", s.rec)
  local sr = VRFW.mem.struct("RandomTeamRecord", src.rec)
  local okl = pcall(function()
    for _, f in ipairs(LOOK_FIELDS) do r[f] = sr[f] end
  end)
  if not okl then VRFW.warn("team_lineup: team " .. hex(team) .. ": record look not written") end
  info(string.format("team %s stands in for %s: %d player(s) (%d copied rows, %d other cards), %d staff row(s)",
    hex(team), hex(source), #cards, copied, other, #s.staff))
  return true, #cards
end

-- CMND_VRFW_TEAM_STAND_IN_FORMATION(slot team, formation): the slot team, standing in for a team, plays this formation
-- instead of its source's. In memory only; CMND_VRFW_TEAM_STAND_IN_RESTORE puts the slot team's own back.
function TeamLineup.StandInFormation(team, formation)
  team = math.floor(tonumber(team) or 0) % 4294967296
  formation = math.floor(tonumber(formation) or 0) % 4294967296
  local s = STAND_IN[team]
  if not s then return false, "slot team " .. hex(team) .. " stands in for no team" end
  if formation == 0 then return false, "no formation" end
  local r = VRFW.mem.struct("RandomTeamRecord", s.rec)
  if not pcall(function() r.Formation = formation end) then return false, "formation write failed" end
  info(string.format("team %s plays formation %s", hex(team), hex(formation)))
  return true
end

-- CMND_VRFW_TEAM_STAND_IN_LOOK(slot team, kit, emblem, coach): the slot team, standing in for a team, wears this kit
-- (uniform id), shows this crest (emblem item id) and has this coach (a card on its coach row, roster slot 19); 0 =
-- the source's. In memory only; CMND_VRFW_TEAM_STAND_IN_RESTORE puts the slot team's own back.
function TeamLineup.StandInLook(team, kit, emblem, coach)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local s = STAND_IN[team]
  if not s or not s.placed then return false, "slot team " .. hex(team) .. " stands in for no team" end
  kit = math.floor(tonumber(kit) or 0) % 4294967296
  emblem = math.floor(tonumber(emblem) or 0) % 4294967296
  coach = math.floor(tonumber(coach) or 0) % 4294967296
  local r = VRFW.mem.struct("RandomTeamRecord", s.rec)
  if kit ~= 0 and not pcall(function() r.Uniform = kit end) then return false, "kit write failed" end
  if emblem ~= 0 and not pcall(function() r.Emblem = emblem end) then return false, "emblem write failed" end
  local coached = false
  if coach ~= 0 then
    for i, x in ipairs(s.staff) do
      if x.slot == STAFF_SLOT and not coached then
        local a = s.base + (s.first + s.placed + i - 1) * MEMBER_STRIDE
        local ms = VRFW.mem.struct("RandomTeamMember", a)
        local ok = pcall(function()
          ms.Param = coach
          ms.Uid = coach
          ms.Skill = 0
        end)
        if not ok or rd("u32", a + MEMBER_CARD) ~= coach then return false, "coach write failed" end
        coached = true
      end
    end
    if not coached then return false, "slot team " .. hex(team) .. " has no coach row" end
  end
  info(string.format("team %s look: kit %s, emblem %s, coach %s", hex(team), hex(kit), hex(emblem), hex(coach)))
  return true
end

-- CMND_VRFW_TEAM_LOOK(team): the team's record as the game has it in memory: level, formation, kit, emblem and the
-- card of its coach row (roster slot 19; 0 = none)
function TeamLineup.Look(team)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local sl, why = read_slice(team)
  if not sl then return false, "team " .. hex(team) .. ": " .. tostring(why) end
  local ok, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", sl.rec)
  if not ok or type(rv) ~= "table" then return false, "team " .. hex(team) .. ": record unreadable" end
  local coach = 0
  for _, x in ipairs(sl.rows) do
    if x.slot == STAFF_SLOT and coach == 0 then coach = x.card or 0 end
  end
  return true, math.floor(tonumber(rv.Level) or 0), math.floor(tonumber(rv.Formation) or 0) % 4294967296,
    math.floor(tonumber(rv.Uniform) or 0) % 4294967296, math.floor(tonumber(rv.Emblem) or 0) % 4294967296, coach
end

-- CMND_VRFW_TEAM_MEMBER_LEVELS(team, base, level…): the member rows in roster slots 0.. play at these levels in the
-- team's next matches: each row's level offset (team_config +0x44) becomes level - base (base 0 = the team record's
-- level, the one a stand-in copies); a level 0 puts the row's own offset back; no level puts every row's back. In
-- memory only; the first write of a row keeps its offset (read again when another card took the row, as a stand-in
-- does), and CMND_VRFW_TEAM_STAND_IN_RESTORE puts a slot team's whole rows back anyway.
local MEMBER_LEVEL = {}   -- member row address -> { card, offset } as first written over

function TeamLineup.MemberLevels(team, base, ...)
  team = math.floor(tonumber(team) or 0) % 4294967296
  base = math.floor(tonumber(base) or 0)
  local sl, why = read_slice(team)
  if not sl then return false, "team " .. hex(team) .. ": " .. tostring(why) end
  local ok, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", sl.rec)
  local record = ok and type(rv) == "table" and math.floor(tonumber(rv.Level) or 0) or 0
  if base <= 0 then base = record end
  if base <= 0 then return false, "team " .. hex(team) .. ": no level to count from" end
  local by_slot = {}
  for _, x in ipairs(sl.rows) do
    if x.slot < STAFF_SLOT and by_slot[x.slot] == nil then by_slot[x.slot] = x end
  end
  local levels = { ... }
  local function own(x)
    local m = MEMBER_LEVEL[x.addr]
    if m == nil or m.card ~= x.card then
      m = { card = x.card, offset = rd("i16", x.addr + 0x44) or 0 }
      MEMBER_LEVEL[x.addr] = m
    end
    return m
  end
  local n, lo, hi = 0, nil, nil
  local function put(x, v)
    local ms = VRFW.mem.struct("RandomTeamMember", x.addr)
    if pcall(function() ms.LevelOffset = math.max(-998, math.min(998, v)) end) then n = n + 1 end
  end
  if #levels == 0 then
    for _, x in pairs(by_slot) do
      local m = MEMBER_LEVEL[x.addr]
      if m and m.card == x.card then put(x, m.offset) end
    end
    info(string.format("team %s: member levels back: %d row(s)", hex(team), n))
    return true, n
  end
  for k, v in ipairs(levels) do
    local x = by_slot[k - 1]
    v = math.floor(tonumber(v) or 0)
    if x then
      local m = own(x)
      if v > 0 then
        put(x, v - base)
        lo, hi = lo and math.min(lo, v) or v, hi and math.max(hi, v) or v
      else
        put(x, m.offset)
      end
    end
  end
  info(string.format("team %s: member levels %s..%s from base %d (record level %d): %d row(s)", hex(team),
    tostring(lo or "-"), tostring(hi or "-"), base, record, n))
  return true, n
end

-- CMND_VRFW_TEAM_STAND_IN_RESTORE(slot team, 0 = every one): the slot team's rows, slice and record back
function TeamLineup.StandInRestore(team)
  team = math.floor(tonumber(team) or 0) % 4294967296
  local n = 0
  for id, s in pairs(STAND_IN) do
    if team == 0 or id == team then
      for _, x in ipairs(s.rows) do put_row(x.addr, x.words) end
      wr("u32", s.rec + REC_COUNT, s.count)
      local r = VRFW.mem.struct("RandomTeamRecord", s.rec)
      pcall(function()
        for _, f in ipairs(LOOK_FIELDS) do r[f] = s.look[f] end
      end)
      STAND_IN[id] = nil
      n = n + 1
    end
  end
  info(string.format("stand-in restore %s: %d team(s)", team == 0 and "every team" or hex(team), n))
  return true, n
end
