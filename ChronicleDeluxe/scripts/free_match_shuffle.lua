-- Chronicle Deluxe: free-match teams that play with their line-up swapped (docs/game/mods/chronicle-deluxe-free-match.md
-- §16). research/scripts/chronicle_deluxe_shuffle_build.py writes, per config.toml [[free_match_shuffle]], a class team
-- (game key `chronicle_deluxe_fms_<x>`) and four source teams `<key>_as_gk|fw|mf|df`: every starter's row as played in
-- a place of that position (stat rates and special moves adapted). A deal gives every starter another place, as many as
-- possible of another position, exactly one in the goalkeeper's place, and copies into each place the row of its new
-- player from the source team of the place's position (card, number, captaincy and kit travel with the player; the
-- stat rates stay with the place, times the player's adaptation). Written in game memory, nothing saved.
-- When: the free-match list asks at its open and at each row focus
-- (assets/lua/soccer_vs_cpu_list_menu/290_free_match_shuffle.lua); a team is dealt again only after a match ended or the
-- game was reset, so the line-up the list previews is the one the next match plays.
-- Commands (content/game/free_match_shuffle.toml):
--   CMND_ChronicleDeluxe_FreeMatchShuffle() -> teams dealt (0 = every shuffled team still holds its deal)

ChronicleDeluxe = type(ChronicleDeluxe) == "table" and ChronicleDeluxe or {}
ChronicleDeluxe.FreeMatchShuffle = ChronicleDeluxe.FreeMatchShuffle or {}
local FmShuffle = ChronicleDeluxe.FreeMatchShuffle

local POS_GK, POS_FW, POS_MF, POS_DF = 1, 2, 3, 4
local TWO32 = 4294967296

local function u32(v)
  if type(v) ~= "number" or v ~= v then return 0 end
  return math.floor(v) % TWO32
end

local function hex(v)
  return string.format("0x%08X", u32(v))
end

-- formation_config placement positionId -> position class
local function placement_class(position_id)
  if position_id == 1 then return POS_GK end
  if position_id == 2 or position_id == 3 then return POS_DF end
  if position_id >= 4 and position_id <= 7 then return POS_MF end
  return POS_FW
end

local floor = math.floor

local MEMBER_STRIDE = 0x54
local ROW_WORDS = 21      -- MEMBER_STRIDE / 4
local SLOT_AT = 0x47
local RATES = 8           -- stat rates at +0x00 (8 floats)
local STARTER_SLOTS = 11
local PREFIX = "chronicle_deluxe_fms_"
local SOURCES = { [POS_GK] = "_as_gk", [POS_FW] = "_as_fw", [POS_MF] = "_as_mf", [POS_DF] = "_as_df" }
local POS_NAME = { [POS_GK] = "GK", [POS_FW] = "FW", [POS_MF] = "MF", [POS_DF] = "DF" }
local FORMATION_STEM = "data/common/gamedata/formation/formation_config"
local STARTS = 8          -- random starting deals; the best one after the swaps is kept

local TEAMS = nil         -- shuffled teams: { { id, key, formation } }
local FORMS = {}          -- formation id -> { [slot] = position class, n } (false = not readable)
local DIRTY = true        -- a deal is due (no deal yet, a match ended, the game was reset)
local DEALS = 0
local TRIES, MAX_TRIES = 0, 3
local WARNED = {}         -- team key -> the last reason it was not dealt (logged once)

local function info(...) VRFW.log("ChronicleDeluxe free_match_shuffle:", ...) end
local function warn(...) VRFW.warn("ChronicleDeluxe free_match_shuffle:", ...) end

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if type(at) ~= "number" or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

local function table_key(stem)
  local plain = stem .. ".cfg.bin"
  local ok, k = pcall(VRFW.table.keys, plain)
  if ok and type(k) == "table" and #k > 0 then return plain end
  return stem .. "_*.cfg.bin"
end

-- the shuffled teams of the served team_config (read once per session)
local function teams()
  if TEAMS then return TEAMS end
  TEAMS = {}
  local ok, rows = pcall(VRFW.table.rows, "team/team")
  if not ok or type(rows) ~= "table" then
    warn("team_config not readable (" .. tostring(rows) .. "): no team is shuffled")
    return TEAMS
  end
  for _, r in ipairs(rows) do
    local key = r.key or r[2]
    local id = r.id or r[1]
    if type(key) == "string" and type(id) == "number" and key:sub(1, #PREFIX) == PREFIX and not key:find("_as_%a%a$") then
      TEAMS[#TEAMS + 1] = { id = u32(id), key = key, formation = u32(r.formation or r[5]) }
    end
  end
  if #TEAMS > 0 then
    local names = {}
    for _, t in ipairs(TEAMS) do names[#names + 1] = t.key end
    info(#TEAMS .. " shuffled team(s): " .. table.concat(names, ", "))
  end
  return TEAMS
end

-- formation `id`: { [slot] = position class (GK / FW / MF / DF), n = places }
local function formation(id)
  local f = FORMS[id]
  if f ~= nil then return f or nil end
  FORMS[id] = false
  local key = table_key(FORMATION_STEM)
  local okf, forms = pcall(VRFW.table.raw, key, "m_SoccerFormationInfoList")
  local okp, places = pcall(VRFW.table.raw, key, "m_SoccerFormPlacementInfoList")
  if not okf or not okp or type(forms) ~= "table" or type(places) ~= "table" then return nil end
  for _, r in ipairs(forms) do
    if type(r.formId) == "number" and u32(r.formId) == id then
      local s = r.placementInfo
      if type(s) ~= "table" or type(s.start) ~= "number" or type(s.count) ~= "number" then return nil end
      local out, n = {}, 0
      for k = s.start + 1, s.start + s.count do
        local p = places[k]
        if p and type(p.positionNo) == "number" then
          out[floor(p.positionNo) % 256] = placement_class(type(p.positionId) == "number" and p.positionId or 0)
          n = n + 1
        end
      end
      out.n = n
      FORMS[id] = out
      return out
    end
  end
  return nil
end

-- the member rows of team `id` in memory: { [slot] = row address }, starters; nil, why
local function rows_of(id)
  if not VRFW.is_on("Team.FindConfig") then return nil, "FindTeamConfig not resolved" end
  local okb, recb = pcall(VRFW.mem.buffer, "cd_fms_team_rec", 8)
  local okc, contb = pcall(VRFW.mem.buffer, "cd_fms_team_cont", 8)
  local okh, hashb = pcall(VRFW.mem.buffer, "cd_fms_team_hash", 4)
  if not (okb and okc and okh) then return nil, "no native buffer" end
  wr("u64", recb, 0)
  wr("u64", contb, 0)
  wr("u32", hashb, id)
  local ok, e = pcall(VRFW.call, "Team.FindConfig", recb, contb, hashb)
  if not ok then return nil, "FindTeamConfig faulted (" .. tostring(e) .. ")" end
  local rec, cont = rd("ptr", recb) or 0, rd("ptr", contb) or 0
  if rec < 0x10000 or cont < 0x10000 then return nil, "team " .. hex(id) .. " not in team_config" end
  local okr, rv = pcall(VRFW.mem.read_struct, "TeamRecord", rec)
  local okc2, cv = pcall(VRFW.mem.read_struct, "TeamConfig", cont)
  if not okr or not okc2 or type(rv) ~= "table" or type(cv) ~= "table" then return nil, "team record unreadable" end
  local first, count, base, n = rv.First, rv.Count, cv.Members, cv.MemberCount
  if not first or not count or not base or base < 0x10000 or not n then return nil, "team record unreadable" end
  first = first % 65536
  if count == 0 or count > 64 or first + count > n then
    return nil, string.format("member slice %d+%d of %d rows", first, count, n)
  end
  local by_slot, starters = {}, 0
  for k = 0, count - 1 do
    local a = base + (first + k) * MEMBER_STRIDE
    local okm, m = pcall(VRFW.mem.read_struct, "MemberRow", a)
    if not okm or type(m) ~= "table" or m.Slot == nil then return nil, "member row " .. k .. " unreadable" end
    if by_slot[m.Slot] then return nil, "roster slot " .. m.Slot .. " twice" end
    by_slot[m.Slot] = a
    if m.Slot < STARTER_SLOTS then starters = starters + 1 end
  end
  for s = 0, starters - 1 do
    if not by_slot[s] then return nil, "starter slots are not 0.." .. (starters - 1) end
  end
  return by_slot, starters
end

-- stat rate k (0-7) of the member row at `a` (a float cell; an integer cell read as its value); nil = unreadable
local function rate_at(a, k)
  local v = rd("f32", a + 4 * k)
  if v and v == v and v > 1e-6 and v < 1e6 then return v end
  local u = rd("u32", a + 4 * k)
  if u and u >= 1 and u <= 1000 then return u end
  return nil
end

local function read_row(a)
  local ok, w = pcall(VRFW.mem.read_array, "u32", a, ROW_WORDS, 4)
  if ok and type(w) == "table" and #w == ROW_WORDS then return w end
  return nil
end

-- score of a deal: every player off his slot first, then as many as possible off their position
local function score(deal, own, cls, n)
  local s = 0
  for i = 0, n - 1 do
    local j = deal[i]
    if j ~= i then s = s + 1000 end
    if cls[j] ~= own[i] then s = s + 10 end
  end
  return s
end

-- a deal of the starters (slot i -> place deal[i]) from `rng`: random starts improved by pair swaps, the best kept
local function draw(rng, own, cls, n)
  local best, best_s
  for _ = 1, STARTS do
    local p = {}
    for k = 1, n do p[k] = k - 1 end
    rng:shuffle(p)
    local deal = {}
    for i = 0, n - 1 do deal[i] = p[i + 1] end
    local s = score(deal, own, cls, n)
    local better = true
    while better do
      better = false
      for a = 0, n - 2 do
        for b = a + 1, n - 1 do
          deal[a], deal[b] = deal[b], deal[a]
          local t = score(deal, own, cls, n)
          if t > s then
            s, better = t, true
          else
            deal[a], deal[b] = deal[b], deal[a]
          end
        end
      end
    end
    if not best_s or s > best_s then
      best, best_s = {}, s
      for i = 0, n - 1 do best[i] = deal[i] end
    end
  end
  return best
end

-- deal team `t`: true, log text; nil, why
local function deal_team(t)
  local rows, starters = rows_of(t.id)
  if not rows then return nil, starters end
  local form = formation(t.formation)
  if not form then return nil, "formation " .. hex(t.formation) .. " not in formation_config" end
  local srcs = {}
  for cls, suffix in pairs(SOURCES) do
    local src, why = rows_of(VRFW.crc32(t.key .. suffix))
    if not src then return nil, "source team " .. t.key .. suffix .. ": " .. tostring(why) end
    srcs[cls] = src
  end
  -- each starter's own position (his card's main position; his first place's when unknown) and each place's
  local own, cls, src_rows = {}, {}, {}
  for s = 0, starters - 1 do
    cls[s] = form[s] or POS_MF
    local card = u32(rd("u32", srcs[POS_GK][s] + 0x20))
    local c = card ~= 0 and VRFW.chara.card(card) or nil
    own[s] = (c and c.position and c.position >= 1 and c.position <= 4) and c.position or cls[s]
  end
  local rng = VRFW.rng("ChronicleDeluxe.free_match_shuffle", { t.id, DEALS, floor(VRFW.now()) })
  local deal = draw(rng, own, cls, starters)
  -- the rows to write, all read before the first write
  for i = 0, starters - 1 do
    local w = read_row(srcs[cls[deal[i]]][i])
    if not w then return nil, "source row of slot " .. i .. " unreadable" end
    src_rows[i] = w
  end
  -- the stat rates belong to the place: place j's own rates times the player's position adaptation (his source rate
  -- over his own rate), so a place's bonus (e.g. the retail keeper's) stays with whoever plays there
  local rates = {}
  for i = 0, starters - 1 do
    local j = deal[i]
    local src, mine, place = srcs[cls[j]][i], srcs[own[i]][i], srcs[own[j]][j]
    local r = {}
    for k = 0, RATES - 1 do
      local sv, mv, pv = rate_at(src, k), rate_at(mine, k), rate_at(place, k)
      if sv and mv and pv and mv > 0 then r[k] = { from = sv, to = pv * sv / mv } end
    end
    rates[i] = r
  end
  local parts, moved = {}, 0
  for i = 0, starters - 1 do
    local j = deal[i]
    local a = rows[j]
    for k = 1, ROW_WORDS do
      if not wr("u32", a + 4 * (k - 1), src_rows[i][k]) then return nil, "write of place " .. j .. " failed (the team may be half written)" end
    end
    for k, x in pairs(rates[i]) do
      if math.abs(x.to - x.from) > 1e-6 and not wr("f32", a + 4 * k, x.to) then
        return nil, "rate write of place " .. j .. " failed (the team may be half written)"
      end
    end
    if not wr("u8", a + SLOT_AT, j) then return nil, "slot write of place " .. j .. " failed" end
    if cls[j] ~= own[i] then moved = moved + 1 end
    parts[j + 1] = string.format("%d<-%d:%s %s->%s", j, i, hex(src_rows[i][9]), POS_NAME[own[i]] or "?", POS_NAME[cls[j]] or "?")
  end
  return true, string.format("%d starter(s) moved, %d of them to another position: [%s]", starters, moved, table.concat(parts, " "))
end

function FmShuffle.Deal()
  if not DIRTY then return 0 end
  local n, failed = 0, false
  for _, t in ipairs(teams()) do
    local ok, res, text = pcall(deal_team, t)
    if ok and res then
      n = n + 1
      DEALS = DEALS + 1
      WARNED[t.key] = nil
      info(t.key .. " dealt: " .. text)
    else
      failed = true
      local why = tostring(ok and text or res)
      if WARNED[t.key] ~= why then
        WARNED[t.key] = why
        warn(t.key .. ": not dealt: " .. why)
      end
    end
  end
  -- a failed deal is tried again at the next call, at most TRIES times until the next match
  TRIES = failed and TRIES + 1 or 0
  DIRTY = failed and TRIES < MAX_TRIES
  return n
end

VRFW.on("match_end", function()
  DIRTY, TRIES = true, 0
  return nil
end)

VRFW.on("game_reset", function()
  DIRTY, TRIES = true, 0
  return nil
end)
