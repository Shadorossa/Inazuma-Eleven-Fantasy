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

TeamLineup = TeamLineup or {}

local function info(...) VRFW.log("team_lineup:", ...) end

local MEMBER_STRIDE = 0x54       -- member row size (team_config member table)
local MEMBER_CARD = 0x20         -- the row's chara_param (u32)
local MEMBER_SLOT = 0x47         -- the row's roster slot (u8)
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
