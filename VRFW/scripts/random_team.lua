-- VR-Framework › random team (docs/framework/random-team.md). A mod declares, in content\random_teams\*.toml
-- (`VRFW.random_team/1`), a player pool (card filters), rules (slot teams, formations, strength per stage, element mix)
-- and a presentation pool (name text + emblem + kit per entry). Before a match the mod asks for «the random team of
-- rule R for seed S and node N»: this service draws the roster deterministically and writes it over the member rows of
-- one of the rule's SLOT TEAMS in game memory (an ordinary team the mod declares with placeholder players), plus that
-- team's formation, level, name, emblem and kit. The match then plays the slot team (a game whose rival it is, or the
-- next-match override `teams.rival.team`). Nothing is saved: the same inputs give the same team after a reload.
--
-- Why this works (risk 7b of docs/refactor/roguelite-split-map.md, static RE of v7.1.2, docs §2): every match setup
-- builds the rival from the team_config records the game keeps in memory (TeamBuild 0xE9C190 → FindTeamConfig 0xE6BEE0
-- → BuildRoster 0xE9AC40): member rows `[cfg+0x68]` (0x54 bytes: +0x20 card, +0x24 uid, +0x28 loadout, +0x44 level
-- offset, +0x46 AI step, +0x47 slot) and the record (0x50 bytes: +4 level, +0x14 name text, +0x18 formation, +0x1C kit,
-- +0x20 emblem, +0x28 / +0x2C member slice) are read again at every setup (BuildRoster's 0xE9B760 reads the four
-- record fields), so rows rewritten before the setup are the team the match builds. Battle Bay Deluxe's Draft writes
-- the same member rows the same way.
--
-- Commands (content\game\random_team.toml):
--   CMND_VRFW_RANDOM_TEAM_BUILD(rule, seed, node, stage, slot) -> ok, team, level, members, why
--   CMND_VRFW_RANDOM_TEAM_PREVIEW(rule, seed, node, stage, slot) -> the same, nothing written
--   CMND_VRFW_RANDOM_TEAM_MEMBER(i)  -> card, slot, position class (member i, 1-based, of the last build / preview)
--   CMND_VRFW_RANDOM_TEAM_LOOK()     -> name text, emblem, kit, formation, theme element (the last build / preview)
--   CMND_VRFW_RANDOM_TEAM_INFO(rule) -> ok, version, slot teams, stages
--   CMND_VRFW_RANDOM_TEAM_RESTORE(team) -> ok, rows: the slot team's placeholders back (team 0 = every slot touched)

RandomTeam = RandomTeam or {}

local C = require "lib/random_team_core"

local floor = math.floor
local u32, hex = C.u32, C.hex

local MEMBER_STRIDE = 0x54
local RECORD_STRIDE = 0x50
local REC_FIRST, REC_COUNT = 0x28, 0x2C
local STARTER_SLOTS, BENCH_LAST = 11, 18   -- roster slots 0-10 starters, 11-18 bench, 19 / 20 staff (never written)
local SCHEMA = "VRFW.random_team/1"

local FORMATION_STEM = "data/common/gamedata/formation/formation_config"

local function info(...) VRFW.log("random_team:", ...) end
local function warn(...) VRFW.warn("random_team:", ...) end
local function err(...) VRFW.error("random_team:", ...) end

local function crc(s)
  local ok, v = pcall(VRFW.crc32, s)
  if ok and type(v) == "number" then return u32(v) end
  return u32(VRFW.ui.crc32(s))
end

-- a declared id: a number, "0x…", decimal text, `<mod>.<name>` (the id space of `kind`, else its crc32), any other
-- text = its crc32 (the game's key hash)
local function id_of(kind, v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % 4294967296 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % 4294967296 end
  local s = v:match("^%s*(.-)%s*$")
  if kind and s:find(".", 1, true) and VRFW.ids and VRFW.ids.resolve then
    local ok, n = pcall(VRFW.ids.resolve, kind, s)
    if ok and type(n) == "number" then return u32(n) end
  end
  return crc(s)
end

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

local function set_field(s, field, v)
  return (pcall(function() s[field] = v end))
end

-- the key of a game table as the game loads it (`<stem>.cfg.bin`, else its newest versioned file)
local function table_key(stem)
  local plain = stem .. ".cfg.bin"
  local ok, k = pcall(VRFW.table.keys, plain)
  if ok and type(k) == "table" and #k > 0 then return plain end
  return stem .. "_*.cfg.bin"
end

local function active_mods()
  local out = {}
  local ok, decl = pcall(VRFW.files.declarations, "mod.toml")
  if ok and type(decl) == "table" then
    for _, d in ipairs(decl) do
      if type(d.mod) == "string" then out[d.mod] = true end
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ declarations

local RULES, POOLS, LOOKS = nil, {}, {}
local RULE_LIST = {}
local NEED_COLS = {}      -- chara_param columns the tiers read (name or 0-based number)
local MODS = {}

local POSITION_WORD = { GK = C.POS_GK, FW = C.POS_FW, MF = C.POS_MF, DF = C.POS_DF }
local FILTER_KEYS = { Element = true, Position = true, Rarity = true, Series = true, AppearsIn = true, Set = true, Team = true, Cards = true,
  Characters = true, Mod = true, Gender = true, Columns = true, IfMod = true }
local STAGE_KEYS = { Stage = true, Stages = true, Level = true, LevelSpread = true, Step = true, RarityWeights = true,
  Tier = true, Formations = true, MaxSame = true, ElementWeights = true, Theme = true }
local RULE_KEYS = { Name = true, Pool = true, Look = true, Slots = true, Formations = true, BenchKeeper = true,
  Unique = true, Version = true, TierColumn = true, MaxSame = true, ElementWeights = true, Theme = true, Level = true,
  LevelSpread = true, Step = true, RarityWeights = true, Tier = true, Stage = true }

local function unknown_keys(where, t, known)
  for k in pairs(t) do
    if type(k) == "string" and not known[k] then warn(where .. ": unknown key " .. k .. " (ignored)") end
  end
end

local function full(mod, name)
  if type(name) ~= "string" or name == "" then return nil end
  if name:find(".", 1, true) then return name end
  return mod .. "." .. name
end

local function list_of(v)
  if v == nil then return {} end
  if type(v) ~= "table" then return { v } end
  return v
end

-- the keys of a number set (C.num_set) as a sorted list; nil for none
local function keys_of(set)
  if set == nil then return nil end
  local a = {}
  for k in pairs(set) do a[#a + 1] = k end
  table.sort(a, function(x, y) return tostring(x) < tostring(y) end)
  return a
end

-- a filter row as a card-set rule of the framework (the one selector vocabulary, docs/framework/chara-index.md §4,
-- evaluated natively by VRFW.chara.select); nil when IfMod names a mod that is not active. Series = the character's
-- source series (names or numbers; one meaning framework-wide since 2.3), AppearsIn = his in_* membership flags (what
-- Series meant before 2.3), Set = declared [[VRFW.CardSet]] names.
local function compile_filter(where, f)
  unknown_keys(where, f, FILTER_KEYS)
  if type(f.IfMod) == "string" and f.IfMod ~= "" and not MODS[f.IfMod] then
    info(where .. ": IfMod " .. f.IfMod .. " is not active (row left out)")
    return nil
  end
  local out = {}
  out.element = keys_of(C.num_set(f.Element))
  out.position = keys_of(C.num_set(f.Position, function(x)
    if type(x) == "number" then return floor(x) end
    if type(x) == "string" then return POSITION_WORD[x:upper()] end
    return nil
  end))
  out.rarity = keys_of(C.num_set(f.Rarity))
  out.gender = keys_of(C.num_set(f.Gender))
  if f.Series ~= nil then out.series = list_of(f.Series) end
  if f.AppearsIn ~= nil then out.appears_in = list_of(f.AppearsIn) end
  if f.Set ~= nil then
    local sets = {}
    for _, x in ipairs(list_of(f.Set)) do
      if type(x) == "string" then sets[#sets + 1] = x end
    end
    out.set = sets
  end
  out.team = keys_of(C.num_set(f.Team, function(x) return id_of("team", x) end))
  out.cards = keys_of(C.num_set(f.Cards, function(x) return id_of("chara", x) end))
  out.characters = keys_of(C.num_set(f.Characters, function(x) return id_of("character", x) end))
  if f.Mod ~= nil then
    local m = {}
    for _, x in ipairs(list_of(f.Mod)) do
      if type(x) == "string" then m[#m + 1] = x end
    end
    out.mod = m
  end
  if type(f.Columns) == "table" then
    local cols = {}
    for col, r in pairs(f.Columns) do
      local rr = C.range(r)
      if rr then
        cols[tostring(col)] = rr
      else
        warn(where .. ": Columns." .. tostring(col) .. " needs a number or [min, max] (ignored)")
      end
    end
    if next(cols) ~= nil then out.columns = cols end
  end
  return out
end

local function theme_of(t)
  if type(t) ~= "table" then return nil end
  local chance = tonumber(t.Chance) or 0
  local weight = tonumber(t.Weight) or 4
  if chance <= 0 then return nil end
  return { chance = math.min(1, chance), weight = math.max(0, weight) }
end

-- the strength / mix keys a rule and its stage rows share
local function strength(src, into)
  into = into or {}
  if src.Level ~= nil then into.level = C.range(src.Level) end
  if src.LevelSpread ~= nil then into.spread = math.max(0, floor(tonumber(src.LevelSpread) or 0)) end
  if src.Step ~= nil then into.step = math.max(0, math.min(4, floor(tonumber(src.Step) or 0))) end
  if src.RarityWeights ~= nil then into.rarity_w = C.weights(src.RarityWeights) end
  if src.Tier ~= nil then into.tier = C.range(src.Tier) end
  if src.Formations ~= nil then
    into.formations = {}
    for _, f in ipairs(list_of(src.Formations)) do
      local id = id_of("formation", f)
      if id then into.formations[#into.formations + 1] = id end
    end
  end
  if src.MaxSame ~= nil then into.max_same = math.max(1, floor(tonumber(src.MaxSame) or 1)) end
  if src.ElementWeights ~= nil then into.element_w = C.weights(src.ElementWeights) end
  if src.Theme ~= nil then into.theme = theme_of(src.Theme) end
  return into
end

local function load_decls()
  if RULES then return end
  RULES = {}
  MODS = active_mods()
  local ok, files = pcall(VRFW.files.declarations, "content/random_teams")
  if not ok or type(files) ~= "table" then
    warn("declarations not readable: " .. tostring(files))
    return
  end
  local rules = {}
  for _, f in ipairs(files) do
    local data = type(f.data) == "table" and f.data or {}
    if data.schema ~= SCHEMA then
      warn(string.format("mods/%s/%s: schema %q, expected %q (read anyway)", tostring(f.mod), tostring(f.file),
        tostring(data.schema), SCHEMA))
    end
    local v = type(data.VRFW) == "table" and data.VRFW or {}
    for i, p in ipairs(type(v.RandomTeamPool) == "table" and v.RandomTeamPool or {}) do
      local where = string.format("mods/%s/%s: [[VRFW.RandomTeamPool]] #%d", f.mod, f.file, i)
      local key = full(f.mod, p.Name)
      if not key then
        warn(where .. ": Name missing (left out)")
      else
        local pool = { key = key, include = {}, exclude = {}, where = where }
        for k, row in ipairs(list_of(p.Include)) do
          local c = type(row) == "table" and compile_filter(where .. " Include #" .. k, row)
          if c then pool.include[#pool.include + 1] = c end
        end
        for k, row in ipairs(list_of(p.Exclude)) do
          local c = type(row) == "table" and compile_filter(where .. " Exclude #" .. k, row)
          if c then pool.exclude[#pool.exclude + 1] = c end
        end
        if POOLS[key] then warn(where .. ": " .. key .. " declared again (the later one wins)") end
        POOLS[key] = pool
      end
    end
    for i, l in ipairs(type(v.RandomTeamLook) == "table" and v.RandomTeamLook or {}) do
      local where = string.format("mods/%s/%s: [[VRFW.RandomTeamLook]] #%d", f.mod, f.file, i)
      local key = full(f.mod, l.Name)
      if not key then
        warn(where .. ": Name missing (left out)")
      else
        local look = { key = key, entries = {} }
        for k, e in ipairs(list_of(l.Entry)) do
          if type(e) == "table" then
            if type(e.IfMod) == "string" and e.IfMod ~= "" and not MODS[e.IfMod] then
              -- an entry of a mod that is not active: left out
            else
              look.entries[#look.entries + 1] = { n = k, name = e.Text ~= nil and id_of("text", e.Text) or nil,
                emblem = e.Emblem ~= nil and id_of("emblem", e.Emblem) or nil,
                kit = e.Kit ~= nil and id_of("kit", e.Kit) or nil,
                team = e.Team ~= nil and id_of("team", e.Team) or nil }
            end
          end
        end
        if #look.entries == 0 then warn(where .. ": no entry (the slot teams keep their own name / emblem / kit)") end
        LOOKS[key] = look
      end
    end
    for i, r in ipairs(type(v.RandomTeam) == "table" and v.RandomTeam or {}) do
      local where = string.format("mods/%s/%s: [[VRFW.RandomTeam]] #%d", f.mod, f.file, i)
      unknown_keys(where, r, RULE_KEYS)
      local key = full(f.mod, r.Name)
      if not key then
        warn(where .. ": Name missing (left out)")
      else
        local rule = { key = key, crc = crc(key), mod = f.mod, where = where, pool = full(f.mod, r.Pool),
          look = r.Look ~= nil and full(f.mod, r.Look) or nil, slots = {}, slot_keys = {},
          bench_keeper = r.BenchKeeper == true, unique = r.Unique == "card" and "card" or "character",
          version = floor(tonumber(r.Version) or 1), tier_col = r.TierColumn, stages = {} }
        if rule.tier_col ~= nil then NEED_COLS[rule.tier_col] = true end
        for _, s in ipairs(list_of(r.Slots)) do
          local id = id_of("team", s)
          if id then
            rule.slots[#rule.slots + 1] = id
            rule.slot_keys[#rule.slot_keys + 1] = tostring(s)
          end
        end
        rule.base = strength(r)
        for k, s in ipairs(list_of(r.Stage)) do
          if type(s) == "table" then
            unknown_keys(where .. " Stage #" .. k, s, STAGE_KEYS)
            local st = strength(s)
            st.range = C.range(s.Stages) or C.range(s.Stage) or { k, k }
            rule.stages[#rule.stages + 1] = st
          end
        end
        if not rule.pool then warn(where .. ": Pool missing") end
        if #rule.slots == 0 then warn(where .. ": Slots missing (the rule cannot build)") end
        if rules[key] then warn(where .. ": " .. key .. " declared again (the later one wins)") end
        rules[key] = rule
      end
    end
  end
  for k, r in pairs(rules) do
    RULES[k] = r
    RULES[r.crc] = r
    RULE_LIST[#RULE_LIST + 1] = k
  end
  table.sort(RULE_LIST)
  info(string.format("%d rule(s), %d pool(s), %d look pool(s) declared%s", #RULE_LIST,
    (function() local n = 0 for _ in pairs(POOLS) do n = n + 1 end return n end)(),
    (function() local n = 0 for _ in pairs(LOOKS) do n = n + 1 end return n end)(),
    #RULE_LIST > 0 and (": " .. table.concat(RULE_LIST, ", ")) or ""))
end

-- ------------------------------------------------------------------------------------------------ game data

local CARDS = nil         -- every playable card, by id order
local FORMS = {}          -- formation id -> { [positionNo] = class } (false = not found)
local TEAM_ROWS = nil     -- team id -> { name, formation, kit, emblem, level } (team_config as served)

-- The cards from the framework's ONE character index (VRFW.chara.cards: chara_param / chara_base read once natively,
-- by column name, shared by every script; 2.3, docs/framework/chara-index.md), with the chara_param column the tiers
-- name (`TierColumn`: a schema name or a 0-based number). Playable = a main position 1..4.
local function load_cards()
  if CARDS then return CARDS end
  CARDS = {}
  local t0 = VRFW.now()
  local cols = {}
  for col in pairs(NEED_COLS) do
    local ok, at = pcall(VRFW.chara.param_column, col)
    if ok and at ~= nil then
      cols[#cols + 1] = col
    else
      warn("chara_param has no column " .. tostring(col) .. " (filters on it never match)")
    end
  end
  local ok, list = pcall(VRFW.chara.cards, { columns = cols })
  if not ok or type(list) ~= "table" then
    err("chara_param not readable: " .. tostring(list))
    return CARDS
  end
  for _, c in ipairs(list) do
    local pos = c.position
    if type(pos) == "number" and pos >= 1 and pos <= 4 then
      -- the pool's filters are evaluated natively (VRFW.chara.select): a card row only carries what the pick reads
      CARDS[#CARDS + 1] = { id = u32(c.id), base = u32(c.base), element = floor(c.element) % 256, pos = floor(pos),
        rarity = floor(c.rarity or 0), cols = c.cols or {} }
    end
  end
  table.sort(CARDS, function(a, b) return a.id < b.id end)
  info(string.format("%d playable cards taken in %d ms (the framework's character index)", #CARDS, floor(VRFW.now() - t0)))
  return CARDS
end

local function formation(id)
  local f = FORMS[id]
  if f ~= nil then return f or nil end
  FORMS[id] = false
  local key = table_key(FORMATION_STEM)
  local okf, forms = pcall(VRFW.table.raw, key, "m_SoccerFormationInfoList")
  local okp, places = pcall(VRFW.table.raw, key, "m_SoccerFormPlacementInfoList")
  if not okf or not okp or type(forms) ~= "table" or type(places) ~= "table" then
    warn("formation_config not readable")
    return nil
  end
  for _, r in ipairs(forms) do
    if type(r.formId) == "number" and u32(r.formId) == id then
      local s = r.placementInfo
      if type(s) ~= "table" or type(s.start) ~= "number" or type(s.count) ~= "number" then break end
      local out, n = {}, 0
      for k = s.start + 1, s.start + s.count do
        local p = places[k]
        if p and type(p.positionNo) == "number" then
          out[floor(p.positionNo) % 256] = C.placement_class(type(p.positionId) == "number" and p.positionId or 0)
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

local function team_row(id)
  if not TEAM_ROWS then
    TEAM_ROWS = {}
    local ok, rows = pcall(VRFW.table.rows, "team/team")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local tid = r.id or r[1]
        if type(tid) == "number" then
          TEAM_ROWS[u32(tid)] = { name = u32(r.name_text or r[4]), formation = u32(r.formation or r[5]),
            kit = u32(r.uniform or r[6]), emblem = u32(r.emblem or r[7]), level = floor(tonumber(r.level or r[9]) or 0) }
        end
      end
    else
      warn("team_config not readable (" .. tostring(rows) .. "): no slot team's layout can be confirmed")
    end
  end
  return TEAM_ROWS[id]
end

-- ------------------------------------------------------------------------------------------------ team memory

-- the team_config record and container of team `id` (FindTeamConfig, the game's own lookup): rec, cont; nil, why
local function find_team(id)
  if not VRFW.is_on("RandomTeamFind") then return nil, "FindTeamConfig not resolved" end
  local okb, recb = pcall(VRFW.mem.buffer, "rt_team_rec", 8)
  local okc, contb = pcall(VRFW.mem.buffer, "rt_team_cont", 8)
  local okh, hashb = pcall(VRFW.mem.buffer, "rt_team_hash", 4)
  if not (okb and okc and okh) then return nil, "no native buffer" end
  wr("u64", recb, 0)
  wr("u64", contb, 0)
  wr("u32", hashb, id)
  local ok, e = pcall(VRFW.call, "RandomTeamFind", recb, contb, hashb)
  if not ok then return nil, "FindTeamConfig faulted (" .. tostring(e) .. ")" end
  local rec, cont = rd("ptr", recb) or 0, rd("ptr", contb) or 0
  if rec < 0x10000 or cont < 0x10000 then return nil, "team " .. hex(id) .. " not in team_config (not installed?)" end
  return rec, cont
end

local SLOTS = {}          -- slot team id -> its state this session (rows, placeholders, record, layout check)

-- the slot team's rows and record, checked once per session: { rec, rows = { {addr, slot, placeholder} }, starters,
-- bench, orig, layout_ok }; nil, why
local function slot_state(id)
  local s = SLOTS[id]
  local rec, cont = find_team(id)
  if not rec then return nil, cont end
  local okr, rv = pcall(VRFW.mem.read_struct, "RandomTeamRecord", rec)
  local okc, cv = pcall(VRFW.mem.read_struct, "RandomTeamConfig", cont)
  if not okr or not okc or type(rv) ~= "table" or type(cv) ~= "table" then return nil, "team record unreadable" end
  local first, count = rv.First, rv.Count
  local base, n = cv.Members, cv.MemberCount
  if not first or not count or not base or base < 0x10000 or not n then return nil, "team record unreadable" end
  first = first % 65536
  if count == 0 or count > 64 or first + count > n then
    return nil, string.format("member slice %d+%d of %d rows", first, count, n)
  end
  if s and s.rec == rec and s.first == first and s.count == count then return s end
  -- first touch (or the table was reloaded): read and check the rows
  local rows = {}
  for k = 0, count - 1 do
    local a = base + (first + k) * MEMBER_STRIDE
    local okm, m = pcall(VRFW.mem.read_struct, "RandomTeamMember", a)
    if not okm or type(m) ~= "table" or m.Param == nil or m.Uid == nil or m.Slot == nil then
      return nil, "member row " .. k .. " unreadable"
    end
    rows[#rows + 1] = { addr = a, slot = m.Slot, placeholder = m.Param, uid = m.Uid, skill = m.Skill,
      level_offset = m.LevelOffset, step = m.Step }
  end
  local starters, bench, seen = {}, {}, {}
  for _, r in ipairs(rows) do
    if seen[r.slot] then return nil, "roster slot " .. r.slot .. " twice" end
    seen[r.slot] = true
    if r.slot < STARTER_SLOTS then
      starters[#starters + 1] = r
    elseif r.slot <= BENCH_LAST then
      bench[#bench + 1] = r
    end
  end
  table.sort(starters, function(a, b) return a.slot < b.slot end)
  table.sort(bench, function(a, b) return a.slot < b.slot end)
  for k, r in ipairs(starters) do
    if r.slot ~= k - 1 then return nil, "starter slots are not 0.." .. (#starters - 1) end
  end
  if #starters == 0 then return nil, "no starter row" end
  -- no other team may share these rows (team_config slices can be shared): every record's slice is checked
  local recs, nrec = cv.Records, cv.RecordCount
  if recs and recs >= 0x10000 and nrec and nrec > 0 then
    local done = 0
    while done < nrec do
      local take = math.min(4096, nrec - done)
      local at = recs + done * RECORD_STRIDE
      local ok1, ids = pcall(VRFW.mem.read_array, "u32", at, take, RECORD_STRIDE)
      local ok2, fs = pcall(VRFW.mem.read_array, "u32", at + REC_FIRST, take, RECORD_STRIDE)
      local ok3, cs = pcall(VRFW.mem.read_array, "u32", at + REC_COUNT, take, RECORD_STRIDE)
      if not (ok1 and ok2 and ok3) or type(ids) ~= "table" or type(fs) ~= "table" or type(cs) ~= "table" then
        warn("team " .. hex(id) .. ": the record table is unreadable, row sharing not checked")
        break
      end
      for k = 1, take do
        local a = recs + (done + k - 1) * RECORD_STRIDE
        if a ~= rec and ids[k] ~= id then
          local f2, c2 = fs[k] % 65536, cs[k]
          if c2 > 0 and f2 < first + count and first < f2 + c2 then
            return nil, string.format("its member rows are shared with team %s: declare the slot team with a roster of its own", hex(ids[k]))
          end
        end
      end
      done = done + take
    end
  else
    warn("team " .. hex(id) .. ": the record table is unreadable, row sharing not checked")
  end
  -- the record's fields this service writes, checked against the team's own row (team_config as served)
  local r = VRFW.mem.struct("RandomTeamRecord", rec)
  local orig = { level = r.Level, name = r.NameText, formation = r.Formation, kit = r.Uniform, emblem = r.Emblem }
  local row = team_row(id)
  local layout_ok = row ~= nil and u32(orig.name) == row.name and u32(orig.formation) == row.formation
    and u32(orig.kit) == row.kit and u32(orig.emblem) == row.emblem and orig.level == row.level
  if s and s.written then
    -- the table stayed (same record): what this session wrote last is fine too
    layout_ok = layout_ok or (s.layout_ok and u32(orig.formation) == u32(s.written.formation))
    orig = s.orig
  end
  if not layout_ok then
    warn(string.format("team %s: record fields (level %s, name %s, formation %s, kit %s, emblem %s) differ from its "
      .. "team_config row: the roster is written, level / formation / name / emblem / kit are not", hex(id),
      tostring(orig.level), hex(orig.name), hex(orig.formation), hex(orig.kit), hex(orig.emblem)))
  end
  -- the slot team's own values (its team_config row when readable): the defaults of a build
  local own = row and { level = row.level, name = row.name, formation = row.formation, kit = row.kit, emblem = row.emblem }
    or { level = orig.level or 1, name = u32(orig.name), formation = u32(orig.formation), kit = u32(orig.kit),
      emblem = u32(orig.emblem) }
  s = { id = id, rec = rec, first = first, count = count, rows = rows, starters = starters, bench = bench, orig = orig,
    own = own, layout_ok = layout_ok, written = s and s.written or nil }
  if s.written == nil then
    for _, x in ipairs(rows) do
      if x.placeholder ~= x.uid then
        warn(string.format("team %s slot %d: card %s / uid %s differ (a placeholder should be one card)", hex(id),
          x.slot, hex(x.placeholder), hex(x.uid)))
      end
    end
  end
  SLOTS[id] = s
  info(string.format("slot team %s: %d starter(s), %d bench row(s), formation %s, level %s, layout %s", hex(id),
    #starters, #bench, hex(orig.formation), tostring(orig.level), layout_ok and "confirmed" or "NOT confirmed"))
  return s
end

-- ------------------------------------------------------------------------------------------------ the build

local POOL_CACHE = {}     -- pool key -> cards

local function pool_cards(rule)
  local p = POOLS[rule.pool]
  if not p then return nil, "pool " .. tostring(rule.pool) .. " not declared" end
  local cached = POOL_CACHE[p.key]
  if cached then return cached end
  local cards = load_cards()
  -- the pool's card set (the framework's selector: some Include row, no Exclude row; no Include = every card), kept
  -- to the playable cards in id order
  local ok, ids = pcall(VRFW.chara.select, { include = #p.include > 0 and p.include or nil,
    exclude = #p.exclude > 0 and p.exclude or nil })
  if not ok or type(ids) ~= "table" then return nil, "pool " .. p.key .. ": not evaluated (" .. tostring(ids) .. ")" end
  local in_set = {}
  for _, id in ipairs(ids) do in_set[u32(id)] = true end
  local out = {}
  for _, c in ipairs(cards) do
    if in_set[c.id] then out[#out + 1] = c end
  end
  local gk = 0
  for _, c in ipairs(out) do
    if c.pos == C.POS_GK then gk = gk + 1 end
  end
  info(string.format("pool %s: %d card(s) (%d goalkeeper(s)) of %d", p.key, #out, gk, #cards))
  if gk == 0 then err("pool " .. p.key .. " has no goalkeeper: every rule on it fails (declaration error)") end
  POOL_CACHE[p.key] = out
  return out
end

-- the stage row of `stage` (its range holds it; else the highest row that starts below; else the first), merged over
-- the rule's own keys
local function stage_of(rule, stage)
  local pick
  for _, st in ipairs(rule.stages) do
    if stage >= st.range[1] and stage <= st.range[2] then pick = st break end
  end
  if not pick then
    for _, st in ipairs(rule.stages) do
      if st.range[1] <= stage and (not pick or st.range[1] > pick.range[1]) then pick = st end
    end
  end
  pick = pick or rule.stages[1] or {}
  local out = {}
  for k, v in pairs(rule.base) do out[k] = v end
  for k, v in pairs(pick) do if k ~= "range" then out[k] = v end end
  return out
end

local LAST = nil          -- the last build / preview

local function find_rule(r)
  load_decls()
  if type(r) == "number" then return RULES[u32(r)] end
  if type(r) == "string" then return RULES[r] or RULES[crc(r)] end
  return nil
end

local function node_id(v)
  if type(v) == "number" then return u32(v) end
  if type(v) == "string" then return crc(v) end
  return 0
end

-- build (write = false: preview). Returns ok, team, level, members, why
local function build(rule_arg, seed, node, stage, slot, write)
  local rule = find_rule(rule_arg)
  if not rule then
    err("rule " .. tostring(rule_arg) .. " is not declared")
    return 0, 0, 0, 0, "rule not declared"
  end
  stage = floor(tonumber(stage) or 1)
  local si = slot == nil and 1 or (type(slot) == "number" and floor(slot)) or nil
  local team
  if si and si >= 1 and si <= #rule.slots then
    team = rule.slots[si]
  else
    local want = id_of("team", slot)
    for k, t in ipairs(rule.slots) do
      if t == want then team, si = t, k break end
    end
  end
  if not team then
    err(rule.key .. ": slot " .. tostring(slot) .. " is not one of its " .. #rule.slots .. " slot team(s)")
    return 0, 0, 0, 0, "bad slot"
  end
  local s, why = slot_state(team)
  if not s then
    err(rule.key .. ": slot team " .. rule.slot_keys[si] .. " (" .. hex(team) .. "): " .. tostring(why))
    return 0, team, 0, 0, tostring(why)
  end
  local pool, perr = pool_cards(rule)
  if not pool then
    err(rule.key .. ": " .. perr)
    return 0, team, 0, 0, perr
  end
  local st = stage_of(rule, stage)
  local hi, lo = C.split(seed)
  local nid = node_id(node)
  local words = { hi, lo, nid, rule.crc, rule.version, stage }
  local rng = C.rng(words, 1)
  local look_rng = C.rng(words, 2)
  -- formation: one of the stage's / rule's that fits the slot team's starters, else the slot team's own
  local form_id, classes
  local fits = {}
  -- without a confirmed record layout the formation cannot be written: the team's own one then
  for _, f in ipairs(s.layout_ok and st.formations or {}) do
    local pl = formation(f)
    if pl and pl.n == #s.starters then
      local ok = true
      for k = 0, #s.starters - 1 do
        if not pl[k] then ok = false break end
      end
      if ok then fits[#fits + 1] = f end
    elseif pl then
      warn(string.format("%s: formation %s has %d places, slot team %s %d starters (left out)", rule.key, hex(f), pl.n,
        hex(team), #s.starters))
    else
      warn(rule.key .. ": formation " .. hex(f) .. " not in formation_config (left out)")
    end
  end
  local fpick = rng:below(math.max(1, #fits)) + 1
  form_id = fits[fpick] or s.own.formation
  local pl = formation(form_id)
  if not pl then
    err(rule.key .. ": formation " .. hex(form_id) .. " not readable")
    return 0, team, 0, 0, "formation not readable"
  end
  classes = {}
  for k = 0, #s.starters - 1 do classes[k + 1] = pl[k] or 0 end
  -- level
  local lr = st.level or { s.own.level or 1, s.own.level or 1 }
  local level = math.max(1, rng:range(lr[1], lr[2]))
  -- roster
  local places = C.places(classes, #s.bench, rule.bench_keeper)
  local res, perr2 = C.pick({ pool = pool, places = places, unique = rule.unique, rarity_w = st.rarity_w,
    tier_col = rule.tier_col, tier = st.tier, element_w = st.element_w, max_same = st.max_same, theme = st.theme,
    rng = rng })
  if not res then
    err(string.format("%s stage %d: %s (nothing written)", rule.key, stage, perr2))
    return 0, team, 0, 0, perr2
  end
  local members = {}
  for i, p in ipairs(places) do
    local row = p.bench and s.bench[p.index] or s.starters[p.index]
    local off = 0
    if st.spread and st.spread > 0 then off = rng:range(-st.spread, st.spread) end
    if level + off < 1 then off = 1 - level end
    members[#members + 1] = { row = row, card = res.picks[i], class = p.class, offset = off }
  end
  table.sort(members, function(a, b) return a.row.slot < b.row.slot end)
  -- presentation
  local look = { name = s.own.name, emblem = s.own.emblem, kit = s.own.kit, n = 0 }
  local lp = rule.look and LOOKS[rule.look]
  if rule.look and not lp then warn(rule.key .. ": look pool " .. rule.look .. " not declared") end
  if lp and #lp.entries > 0 then
    local e = lp.entries[look_rng:below(#lp.entries) + 1]
    look.n = e.n
    if e.team then
      local trec = find_team(e.team)
      if trec then
        local t = VRFW.mem.struct("RandomTeamRecord", trec)
        look.name, look.emblem, look.kit = u32(t.NameText), u32(t.Emblem), u32(t.Uniform)
      else
        warn(rule.key .. ": look entry #" .. e.n .. ": team " .. hex(e.team) .. " not found")
      end
    end
    look.name = e.name or look.name
    look.emblem = e.emblem or look.emblem
    look.kit = e.kit or look.kit
  end
  -- write
  local wrote = 0
  if write then
    for _, m in ipairs(members) do
      local ms = VRFW.mem.struct("RandomTeamMember", m.row.addr)
      local ok = set_field(ms, "Param", m.card.id) and set_field(ms, "Uid", m.card.id) and set_field(ms, "Skill", 0)
        and set_field(ms, "LevelOffset", m.offset)
      if ok and st.step ~= nil then ok = set_field(ms, "Step", st.step) end
      if not ok or u32(rd("u32", m.row.addr + 0x20)) ~= m.card.id then
        err(string.format("%s: write of slot team %s row %d failed (the team may be half written)", rule.key, hex(team), m.row.slot))
        return 0, team, 0, 0, "write failed"
      end
      wrote = wrote + 1
    end
    if s.layout_ok then
      local r = VRFW.mem.struct("RandomTeamRecord", s.rec)
      local ok = set_field(r, "Level", level) and set_field(r, "Formation", form_id) and set_field(r, "NameText", look.name)
        and set_field(r, "Uniform", look.kit) and set_field(r, "Emblem", look.emblem)
      if not ok then warn(rule.key .. ": slot team " .. hex(team) .. ": record write failed (level / look not set)") end
    end
    s.written = { formation = form_id, level = level }
  end
  -- the log line: seed, node, slot, look, roster
  local parts = {}
  for _, m in ipairs(members) do
    parts[#parts + 1] = string.format("%d:%s%s", m.row.slot, hex(m.card.id), m.offset ~= 0 and string.format("%+d", m.offset) or "")
  end
  info(string.format("%s %s seed %08X:%08X node %s stage %d -> team %s (%s, slot %d), formation %s, level %d%s, look #%d "
    .. "(name %s, emblem %s, kit %s)%s%s, roster [%s]%s", write and "build" or "preview", rule.key, hi, lo, hex(nid), stage,
    rule.slot_keys[si], hex(team), si, hex(form_id), level, st.step and (", step " .. st.step) or "", look.n,
    hex(look.name), hex(look.emblem), hex(look.kit), res.theme and (", theme element " .. res.theme) or "",
    res.fallbacks > 0 and (", " .. res.fallbacks .. " place(s) off position") or "", table.concat(parts, " "),
    write and (s.layout_ok and "" or " (record fields NOT written: layout not confirmed)") or ""))
  LAST = { team = team, members = members, look = look, formation = form_id, theme = res.theme or 0, level = level }
  return 1, team, level, #members, ""
end

-- ------------------------------------------------------------------------------------------------ commands

-- a build never raises into the command (an uncaught error would switch the whole script off): 0 + the error
local function guarded(rule, seed, node, stage, slot, write)
  local res = { pcall(build, rule, seed, node, stage, slot, write) }
  if res[1] then
    return res[2], res[3], res[4], res[5], res[6]
  end
  err(string.format("%s %s failed: %s", write and "build" or "preview", tostring(rule), tostring(res[2])))
  return 0, 0, 0, 0, tostring(res[2])
end

function RandomTeam.Build(rule, seed, node, stage, slot)
  return guarded(rule, seed, node, stage, slot, true)
end

function RandomTeam.Preview(rule, seed, node, stage, slot)
  return guarded(rule, seed, node, stage, slot, false)
end

function RandomTeam.Member(i)
  local m = LAST and LAST.members[floor(tonumber(i) or 0)]
  if not m then return 0, -1, 0 end
  return m.card.id, m.row.slot, m.card.pos
end

function RandomTeam.Look()
  if not LAST then return 0, 0, 0, 0, 0 end
  return LAST.look.name, LAST.look.emblem, LAST.look.kit, LAST.formation, LAST.theme
end

function RandomTeam.Info(rule)
  local okr, r = pcall(find_rule, rule)
  if not okr then
    err("info: " .. tostring(r))
    return 0, 0, 0, 0
  end
  if not r then return 0, 0, 0, 0 end
  return 1, r.version, #r.slots, #r.stages
end

-- placeholders and the record's own values back
local function restore(team)
  local want = team and team ~= 0 and id_of("team", team) or nil
  local done, rows = true, 0
  for id, s in pairs(SLOTS) do
    if (want == nil or want == id) and s.written then
      local rec = find_team(id)
      if rec == s.rec then
        for _, r in ipairs(s.rows) do
          local ms = VRFW.mem.struct("RandomTeamMember", r.addr)
          local ok = set_field(ms, "Param", r.placeholder) and set_field(ms, "Uid", r.uid)
          if r.skill ~= nil then ok = ok and set_field(ms, "Skill", r.skill) end
          if r.level_offset ~= nil then ok = ok and set_field(ms, "LevelOffset", r.level_offset) end
          if r.step ~= nil then ok = ok and set_field(ms, "Step", r.step) end
          done = done and ok
          rows = rows + 1
        end
        if s.layout_ok then
          local rs = VRFW.mem.struct("RandomTeamRecord", rec)
          set_field(rs, "Level", s.orig.level)
          set_field(rs, "Formation", s.orig.formation)
          set_field(rs, "NameText", s.orig.name)
          set_field(rs, "Uniform", s.orig.kit)
          set_field(rs, "Emblem", s.orig.emblem)
        end
        s.written = nil
        info("slot team " .. hex(id) .. ": placeholders back")
      end
    end
  end
  return done and 1 or 0, rows
end

function RandomTeam.Restore(team)
  local ok, a, b = pcall(restore, team)
  if ok then return a, b end
  err("restore failed: " .. tostring(a))
  return 0, 0
end
