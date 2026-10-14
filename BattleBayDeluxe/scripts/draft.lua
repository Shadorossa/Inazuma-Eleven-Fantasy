-- Battle Bay «Draft» (docs/game/modes/estadio-bb.md §14), a library of campaign.lua (one VM: the Decide hook asks
-- it for the Draft team, the leader sync and the campaign start). Since 1.3.0 it replaces bb_chronicle_teams.dll's
-- draft.rs, pool.rs and draft_rt.rs with the same behaviour. Declarations: content\game\draft.toml.
--
-- The first tile of «Equipos principales» is the team `evt_bbd_draft` (content\teams\50_draft.toml, found by
-- config.toml [draft] team): in the Campaña the player picks 1 of 5 candidates for each of its 16 roster places (the
-- 11 positions of its formation and 5 bench places of any position, in any order) and plays the retail campaign with
-- that team. The drafted players are written over the team's member rows IN MEMORY (MemberRow param / uid of its
-- team_config rows, under a layout guard); the match builder creates them at the team level (40) and never stores
-- them; the placeholders go back when the campaign ends or the draft is abandoned. The roster of a running draft
-- campaign is the save blob `bb_draft.json` of the active slot (VRFW.save.blob); the DLL's
-- `<loader data dir>\bb_draft_slot<N>.json` is imported once per slot (VRFW.data.import_once; the old file is never
-- deleted or written again).
--
-- Pool (its game tables read at script load, the squads at the save load, else derived by the first command): every
-- member (slots 0-18) of every other Battle Bay team as the game holds it in memory (enjoy rows, FindTeamConfig),
-- whose chara_param row exists, has a position (1 GK, 2 FW, 3 MF, 4 DF) and is no special card ([draft]
-- special_rarities, chara_param col 41) nor in [draft] exclude; one card per character (same name in [draft]
-- name_language, else the same chara_base): the variant in most squads, then the first in table order. A new draft
-- leaves out the squads of the teams the VR-Framework's «win it to unlock it» rule still locks (when the rest still
-- fills the 16 places).
--
-- | Command | Args -> answers |
-- |---|---|
-- | CMND_BBCR_DRAFT_INFO | -> ok, team, phase (0 none, 1 picking, 2 complete, 3 campaign), filled, total |
-- | CMND_BBCR_DRAFT_BEGIN | -> ok, total: a new draft (placeholders written back first) |
-- | CMND_BBCR_DRAFT_SLOTS | -> ok, n: the number of places |
-- | CMND_BBCR_DRAFT_SLOT | k -> ok, slot, pos, x, y, param or 0, placeholder (one place per call: the engine caps the answers) |
-- | CMND_BBCR_DRAFT_CANDS | k -> ok, k, slot, pos, n, (param, pos) x n: the offer of place k (stable until picked) |
-- | CMND_BBCR_DRAFT_PICK | k, i -> ok, done, slot, param, filled: candidate i of place k taken, the rows written |
-- | CMND_BBCR_DRAFT_ABANDON | -> true: placeholders back, no draft (a running draft campaign is kept) |
-- | CMND_BBD_DRAFT_PACK | -> ok, 12 numbers, 4 sound hashes: the candidates' «pack opening» look ([draft.pack]) |
-- | CMND_BBCR_DRAFT_SYNC | active (1/0), playerTeam (the BB top menu's campaign info) -> phase |

local U = require "lib/util"
local G = require "lib/game"

local D = {}

local floor = math.floor

local CANDIDATES = 5
local POS_ANY, POS_GK, POS_DF = 0, 1, 4
local STAFF_SLOT, STARTERS = 19, 11
local NONE, PICKING, COMPLETE, CAMPAIGN = 0, 1, 2, 3
local PHASE_NAME = { [0] = "None", "Picking", "Complete", "Campaign" }

local ROSTER_VERSION = 1
local BLOB = "bb_draft.json"               -- the roster of a running draft campaign, per save slot
local IMPORTS = "bb_draft_imports.json"    -- global: the slots whose old loader-data file was dealt with
local MEMBER_STRIDE = 0x54
local OBJ_SIZE = 0x8A0                     -- the grid object image of the BB pages service (record pass)

local KEY_TEAM = "BattleBayDeluxe.draft.team"
local KEY_PHASE = "BattleBayDeluxe.draft.phase"

local FORMATION_STEM = "data/common/gamedata/formation/formation_config"
local TEXT_ROOT = "data/common/text"

local function info(...)
  VRFW.log("draft:", ...)
end
local function warn(...)
  VRFW.warn("draft:", ...)
end
local function err(...)
  VRFW.error("draft:", ...)
end

local function fail(msg)
  error(msg, 0)
end

-- ------------------------------------------------------------------------------------------------ config

local function num_set(list)
  local s = {}
  if type(list) == "table" then
    for _, v in ipairs(list) do
      if type(v) == "number" then
        s[floor(v)] = true
      end
    end
  end
  return s
end

local function num_set_u32(list)
  local s = {}
  if type(list) == "table" then
    for _, v in ipairs(list) do
      if type(v) == "number" then
        s[U.u32(v)] = true
      end
    end
  end
  return s
end

local CFG = {
  team = tostring(U.config("draft.team", "draft")),
  special = num_set(U.config("draft.special_rarities", { 5, 6, 7, 8, 10 })),
  lang = U.trim(tostring(U.config("draft.name_language", "es"))),
  exclude = num_set_u32(U.config("draft.exclude", {})),
  seed = tonumber(U.config("campaign.seed", 0)) or 0,
}

-- ------------------------------------------------------------------------------------------------ the declaration

local function toml_u32(v)
  if type(v) == "number" then
    return U.u32(v)
  elseif type(v) == "string" then
    return U.crc32(U.trim(v))
  end
  return nil
end

-- the [[team]] named `name` of one team declaration file (nil = not in it; nil, why = broken)
local function draft_decl(data, name)
  local teams = type(data) == "table" and data.team
  if type(teams) ~= "table" then
    return nil
  end
  for _, t in ipairs(teams) do
    if type(t) == "table" and t.name == name then
      if type(t.key) ~= "string" then
        return nil, "the team has no key"
      end
      local formation = toml_u32(t.formation)
      if not formation then
        return nil, "the team has no formation"
      end
      if type(t.member) ~= "table" then
        return nil, "the team has no member list"
      end
      local members = {}
      for _, m in ipairs(t.member) do
        if type(m) ~= "table" or type(m.slot) ~= "number" then
          return nil, "a member without slot"
        end
        local card = toml_u32(m.card)
        if not card then
          return nil, "a member without card"
        end
        members[#members + 1] = { slot = floor(m.slot) % 256, card = card }
      end
      local level = type(t.level) == "number" and math.max(0, floor(t.level)) or 0
      return { key = t.key, formation = formation, level = level, members = members }
    end
  end
  return nil
end

-- the Draft team's declaration in the mod's own team files (content\teams, the old teams\ when that is the install)
local function find_decl(name)
  for _, rel in ipairs({ "content/teams", "teams" }) do
    local ok, list = pcall(VRFW.files.declarations, rel)
    local mine = false
    if ok and type(list) == "table" then
      for _, e in ipairs(list) do
        if e.mod == VRFW.mod then
          mine = true
          local d, why = draft_decl(e.data, name)
          if why then
            return nil, tostring(e.file) .. ": " .. why
          end
          if d then
            return d
          end
        end
      end
    end
    if mine then
      return nil, 'no [[team]] name = "' .. name .. '" in ' .. rel
    end
  end
  return nil, 'no [[team]] name = "' .. name .. '" in content\\teams'
end

local DECL, DECL_ERR = find_decl(CFG.team)
local TEAM = DECL and U.crc32(DECL.key) or 0

if DECL then
  info(string.format("team %s = %s (%s), %d members, formation %s, level %d", CFG.team, DECL.key, U.hex(TEAM),
    #DECL.members, U.hex(DECL.formation), DECL.level))
else
  warn("off (" .. tostring(DECL_ERR) .. "): the Draft tile of the Campaña does nothing")
end
pcall(VRFW.state.set, KEY_TEAM, TEAM)
pcall(VRFW.state.set, KEY_PHASE, NONE)

-- The Draft team hash (0 = the Draft is off: no declaration, or its commands are off).
function D.team()
  if TEAM == 0 or not VRFW.is_on("CMND_BBCR_DRAFT_INFO") then
    return 0
  end
  return TEAM
end

-- ------------------------------------------------------------------------------------------------ the pool rule

-- chara_param: { [id] = { base, element, pos, card } } (card = its special_rarity), from the framework's ONE character
-- index (VRFW.chara.cards: chara_param read once natively, by column name, for every script; VRFW 2.3)
local function parse_params()
  local out, n = {}, 0
  for _, c in ipairs(VRFW.chara.cards()) do
    out[U.u32(c.id)] = {
      base = U.u32(c.base),
      element = U.u32(c.element) % 256,
      pos = U.u32(c.position) % 256,
      card = floor(c.rarity),
    }
    n = n + 1
  end
  if n == 0 then
    fail("chara_param: no CHARA_PARAM_INFO row")
  end
  return out
end

-- { [chara_base id] = name } from chara_base (col 3 = its name text) and one language's chara_text (NOUN_INFO form 0)
local function parse_names(lang)
  local txt = {}
  for _, r in ipairs(VRFW.table.raw(U.table_key(TEXT_ROOT .. "/" .. lang .. "/chara_text"), "NOUN_INFO", { 1, 2, 6 })) do
    if type(r[1]) == "number" and r[2] == 0 and type(r[6]) == "string" then
      txt[U.u32(r[1])] = U.trim(r[6])
    end
  end
  -- the characters' name texts: the framework's character index (VRFW.chara.characters)
  local out = {}
  for _, c in ipairs(VRFW.chara.characters()) do
    local n = txt[U.u32(c.name_text)]
    if n and n ~= "" then
      out[U.u32(c.id)] = n
    end
  end
  return out
end

-- a formation placement's positionId as a position class: 1 keeper, 2-3 defence, 4-7 midfield, else forward
local function position_class(id)
  if id == 1 then
    return 1
  elseif id == 2 or id == 3 then
    return 4
  elseif id >= 4 and id <= 7 then
    return 3
  end
  return 2
end

-- the placements of formation `id` by positionNo: { [no] = { pos, x, y } } (startPos x 1000: x lateral, y 0 = the
-- rival goal … 1000 = own goal)
local function formation_places(id)
  local key = U.table_key(FORMATION_STEM)
  local forms = VRFW.table.raw(key, "m_SoccerFormationInfoList")
  local places = VRFW.table.raw(key, "m_SoccerFormPlacementInfoList")
  local row
  for _, r in ipairs(forms) do
    if type(r.formId) == "number" and U.u32(r.formId) == id then
      row = r
      break
    end
  end
  if not row then
    fail("formation " .. U.hex(id) .. " not in formation_config")
  end
  local s = row.placementInfo
  if type(s) ~= "table" or type(s.start) ~= "number" or type(s.count) ~= "number" then
    fail("formation " .. U.hex(id) .. ": no placement slice")
  end
  local out = {}
  for k = s.start + 1, s.start + s.count do
    local p = places[k]
    if not p then
      break
    end
    if type(p.positionNo) ~= "number" then
      fail("placement without positionNo")
    end
    local class = position_class(type(p.positionId) == "number" and p.positionId or 0)
    local x, y = 0, 0
    if type(p.startPos) == "table" and type(p.startPos[1]) == "number" and type(p.startPos[2]) == "number" then
      x, y = U.round(p.startPos[1] * 1000), U.round(p.startPos[2] * 1000)
    end
    out[floor(p.positionNo) % 256] = { pos = class, x = x, y = y }
  end
  return out
end

-- the Draft's places (slot order): starters get their formation placement, the bench any position
local function slot_specs(decl, places)
  local members = {}
  for i, m in ipairs(decl.members) do
    members[i] = m
  end
  U.stable_sort(members, function(m)
    return m.slot
  end)
  local out = {}
  for _, m in ipairs(members) do
    if m.slot < STARTERS then
      local p = places[m.slot]
      if not p then
        fail("slot " .. m.slot .. ": no placement in the formation")
      end
      out[#out + 1] = { slot = m.slot, pos = p.pos, placeholder = m.card, x = p.x, y = p.y }
    else
      out[#out + 1] = { slot = m.slot, pos = POS_ANY, placeholder = m.card, x = 0, y = 0 }
    end
  end
  return out
end

-- the character of a chara_param row: CRC-32 of "name:" + its name, without a name its chara_base (else the row id)
local function character_key(param, inf, names)
  local n = names[inf.base]
  if n and n ~= "" then
    return U.crc32("name:" .. n)
  elseif inf.base ~= 0 then
    return inf.base
  end
  return param
end

-- the draftable members of one squad ({ { slot, param } … }, table order): { { param, k } … } (k = the member's place
-- in the squad, the «first in table order» tie-break); `st` counts the members left out. Done once per squad when
-- the pool is derived: a new draft's smaller pool (open_pool) only counts these lists again.
local function eligible(squad, params, rule, st)
  local out = {}
  for k, m in ipairs(squad) do
    st.members = st.members + 1
    local slot, p = m[1], m[2]
    local inf = params[p]
    if slot >= STAFF_SLOT then
      st.staff = st.staff + 1
    elseif not inf then
      st.unknown = st.unknown + 1
    elseif rule.exclude[p] then
      st.excluded = st.excluded + 1
    elseif inf.card ~= nil and rule.special[inf.card] then
      st.special = st.special + 1
    elseif inf.pos < POS_GK or inf.pos > POS_DF then
      st.no_position = st.no_position + 1
    else
      out[#out + 1] = { p, k }
    end
  end
  return out
end

-- the draftable players of the eligible lists (one per squad, squad order), sorted by (position, id): per character
-- (`keys`: chara_param id -> character key) the most frequent variant, then the first in table order. -> players,
-- variants merged
local function pool_from(lists, params, keys)
  local count, first, order = {}, {}, {}
  for t, list in ipairs(lists) do
    for _, e in ipairs(list) do
      local p = e[1]
      count[p] = (count[p] or 0) + 1
      if not first[p] then
        first[p] = { t, e[2] }
        order[#order + 1] = p
      end
    end
  end
  local best, nbest = {}, 0
  for _, p in ipairs(order) do
    local n, f = count[p], first[p]
    local ch = keys[p] or p
    local b = best[ch]
    local better = not b or n > b.n or (n == b.n and (f[1] < b.t or (f[1] == b.t and f[2] < b.k)))
    if better then
      if not b then
        nbest = nbest + 1
      end
      best[ch] = { n = n, t = f[1], k = f[2], p = p }
    end
  end
  local out = {}
  for ch, b in pairs(best) do
    local inf = params[b.p]
    out[#out + 1] = { param = b.p, pos = inf.pos, chara = ch, element = inf.element }
  end
  table.sort(out, function(a, b)
    if a.pos ~= b.pos then
      return a.pos < b.pos
    end
    return a.param < b.param
  end)
  return out, #order - nbest
end

-- The game's tables of the pool (formation, chara_param, chara_base + chara_text names): read once, at script load
-- (the boot thread) when they are readable then, else by the first build. 2026-10-13 loader.log: the first
-- CMND_BBCR_DRAFT_INFO took 831 ms on the game thread, «pool build: tables 695 ms, squads 70 ms, pool 59 ms».
-- { slots, params, keys = { [chara_param id] = character key } }
local STATIC = nil
local function static_tables()
  if STATIC then
    return STATIC
  end
  local places = formation_places(DECL.formation)
  local slots = slot_specs(DECL, places)
  local params = parse_params()
  local nok, names = pcall(parse_names, CFG.lang)
  if not nok then
    warn("character names not read (" .. tostring(names) .. "): variants of one character count by chara_base")
    names = {}
  end
  local keys = {}
  for p, inf in pairs(params) do
    keys[p] = character_key(p, inf, names)
  end
  STATIC = { slots = slots, params = params, keys = keys }
  return STATIC
end

local function index_players(pool)
  local by = {}
  for _, p in ipairs(pool.players) do
    by[p.param] = p
  end
  pool.by = by
end

-- structural checks: places unique with a placeholder, starters 0-10 with a position, players unique by id and by
-- character, and enough players for every pick (5 per pick, picks never repeat a player)
local function validate(pool)
  if pool.team == 0 then
    return "no team"
  end
  if #pool.slots == 0 then
    return "no slots"
  end
  local seen = {}
  for _, s in ipairs(pool.slots) do
    if seen[s.slot] then
      return "slot " .. s.slot .. " twice"
    end
    seen[s.slot] = s
    if s.placeholder == 0 then
      return "slot " .. s.slot .. " without placeholder"
    end
    if s.pos > POS_DF then
      return "slot " .. s.slot .. " position " .. s.pos
    end
  end
  for k = 0, 10 do
    local s = seen[k]
    if not s then
      return "starter slot " .. k .. " missing"
    elseif s.pos == POS_ANY then
      return "starter slot " .. k .. " without a position"
    end
  end
  local ids, charas = {}, {}
  for _, p in ipairs(pool.players) do
    if p.param == 0 or ids[p.param] then
      return "player " .. U.hex(p.param) .. " twice or zero"
    end
    ids[p.param] = true
    if p.chara ~= 0 then
      if charas[p.chara] then
        return "character " .. U.hex(p.chara) .. " twice (player " .. U.hex(p.param) .. ")"
      end
      charas[p.chara] = true
    end
    if p.pos < POS_GK or p.pos > POS_DF then
      return "player " .. U.hex(p.param) .. " position " .. p.pos
    end
  end
  for pos = POS_GK, POS_DF do
    local need, have = 0, 0
    for _, s in ipairs(pool.slots) do
      if s.pos == pos then
        need = need + 1
      end
    end
    for _, p in ipairs(pool.players) do
      if p.pos == pos then
        have = have + 1
      end
    end
    if need > 0 and have < need - 1 + CANDIDATES then
      return "position " .. pos .. ": " .. have .. " players for " .. need .. " picks"
    end
  end
  if #pool.players < #pool.slots - 1 + CANDIDATES then
    return #pool.players .. " players for " .. #pool.slots .. " picks"
  end
  return nil
end

-- ------------------------------------------------------------------------------------------------ roster rows in memory

-- the member rows of `team` in game memory (team_config, found by hash with the game's own FindTeamConfig):
-- { { slot, param, uid, addr } … }; nil, why
local function read_rows(team)
  if not VRFW.is_on("FindTeamConfig") then
    return nil, "FindTeamConfig not resolved"
  end
  local okb, recb = pcall(VRFW.mem.buffer, "bbd_team_rec", 8)
  local okc, contb = pcall(VRFW.mem.buffer, "bbd_team_cont", 8)
  local okh, hashb = pcall(VRFW.mem.buffer, "bbd_team_hash", 4)
  if not (okb and okc and okh) then
    return nil, "no native buffer"
  end
  U.wr("u64", recb, 0)
  U.wr("u64", contb, 0)
  U.wr("u32", hashb, team)
  local ok, e = U.call("FindTeamConfig", recb, contb, hashb)
  if not ok then
    return nil, "FindTeamConfig faulted (" .. tostring(e) .. ")"
  end
  local rec, cont = U.rd("ptr", recb) or 0, U.rd("ptr", contb) or 0
  if rec < 0x10000 or cont < 0x10000 then
    return nil, "team " .. U.hex(team) .. " not in team_config (data not installed?)"
  end
  local r, c = U.struct("TeamRecord", rec), U.struct("TeamConfig", cont)
  local first, count = U.get(r, "first"), U.get(r, "count")
  local base, n = U.get(c, "members"), U.get(c, "member_count")
  if first == nil or count == nil then
    return nil, "record unreadable"
  end
  if not base or base < 0x10000 then
    return nil, "member rows unreadable"
  end
  if n == nil then
    return nil, "member count unreadable"
  end
  if first < 0 or count == 0 or count > 64 or first + count > n then
    return nil, "member slice " .. first .. "+" .. count .. " of " .. n .. " rows"
  end
  local out = {}
  for k = 0, count - 1 do
    local a = base + (first + k) * MEMBER_STRIDE
    -- the whole row in one guarded read (the pool build reads ~9000 rows of 600 squads)
    local okm, m = pcall(VRFW.mem.read_struct, "MemberRow", a)
    if not okm then
      m = nil
    end
    local slot, param, uid = m and m.slot, m and m.param, m and m.uid
    if slot == nil or param == nil or uid == nil then
      return nil, "row unreadable"
    end
    out[#out + 1] = { slot = slot, param = param, uid = uid, addr = a }
  end
  return out
end

-- any team's member rows as the match builder reads them: { { slot, param } … }; nil, why (the campaign's match check)
function D.roster(team)
  local rows, why = read_rows(team)
  if not rows then
    return nil, why
  end
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = { r.slot, r.param }
  end
  return out
end

local function write_row(row, id)
  local m = U.struct("MemberRow", row.addr)
  if not m then
    return false
  end
  local a = pcall(function()
    m.param = id
  end)
  local b = pcall(function()
    m.uid = id
  end)
  return a and b
end

local function placeholder_of(pool, slot)
  for _, s in ipairs(pool.slots) do
    if s.slot == slot then
      return s.placeholder
    end
  end
  return nil
end

-- the writes that make the rows hold `want` (slot -> id; other places their placeholder): { { row, id } … }.
-- Layout guard: refused (nil, why) unless the rows are exactly the pool's places, each once, and every row holds
-- param == uid equal to its placeholder or to what was written last (`written`).
local function plan_writes(rows, pool, written, want)
  if #rows ~= #pool.slots then
    return nil, #rows .. " member rows, the pool has " .. #pool.slots .. " slots"
  end
  local seen, out = {}, {}
  for i, r in ipairs(rows) do
    local ph = placeholder_of(pool, r.slot)
    if not ph then
      return nil, "row " .. (i - 1) .. ": slot " .. r.slot .. " is not a draft slot"
    end
    if seen[r.slot] then
      return nil, "row " .. (i - 1) .. ": slot " .. r.slot .. " twice"
    end
    seen[r.slot] = true
    local last = written[r.slot] or ph
    if r.param ~= r.uid or (r.param ~= ph and r.param ~= last) then
      return nil, string.format("row %d (slot %d): holds %08X/%08X, expected %08X or %08X", i - 1, r.slot, r.param,
        r.uid, ph, last)
    end
    local to = want[r.slot] or ph
    if to == 0 then
      return nil, "slot " .. r.slot .. ": id 0"
    end
    if to ~= r.param then
      out[#out + 1] = { row = r, id = to }
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ one draft

local function new_draft(rng, n)
  return { rng = rng, picks = {}, n = n, offers = {}, shown = {} }
end

local function draft_from_picks(picks)
  local d = new_draft(U.rng(0, 0), #picks)
  for k, id in ipairs(picks) do
    d.picks[k] = id
  end
  return d
end

local function filled(d)
  local n = 0
  for k = 1, d.n do
    if d.picks[k] then
      n = n + 1
    end
  end
  return n
end

local function done(d)
  return filled(d) == d.n
end

-- the candidates of place k (1-based, pool order): up to 5 distinct players of its position (any on the bench), never
-- one already picked, preferring players not offered before in this draft; drawn on the first call, the same until
-- the place is picked (a player another place took meanwhile is replaced). Empty when picked / no such place.
local function candidates(d, pool, k)
  local spec = pool.slots[k]
  if not spec or d.picks[k] then
    return {}
  end
  local picked = {}
  for kk = 1, d.n do
    if d.picks[kk] then
      picked[d.picks[kk]] = true
    end
  end
  local offer, in_offer = {}, {}
  for _, id in ipairs(d.offers[k] or {}) do
    if not picked[id] then
      offer[#offer + 1] = id
      in_offer[id] = true
    end
  end
  if #offer < CANDIDATES then
    local function fits(p)
      return (spec.pos == POS_ANY or p.pos == spec.pos) and not picked[p.param]
    end
    local fresh = {}
    for _, p in ipairs(pool.players) do
      if fits(p) and not d.shown[p.param] and not in_offer[p.param] then
        fresh[#fresh + 1] = p.param
      end
    end
    d.rng:shuffle(fresh)
    local need = CANDIDATES - #offer
    for i = #fresh, need + 1, -1 do
      fresh[i] = nil
    end
    if #fresh < need then
      -- not enough unseen players: complete with players offered before (never picked ones)
      local seen = {}
      for _, p in ipairs(pool.players) do
        if fits(p) and d.shown[p.param] and not in_offer[p.param] then
          seen[#seen + 1] = p.param
        end
      end
      d.rng:shuffle(seen)
      local more = need - #fresh
      for i = 1, math.min(more, #seen) do
        fresh[#fresh + 1] = seen[i]
      end
    end
    for _, id in ipairs(fresh) do
      d.shown[id] = true
      offer[#offer + 1] = id
    end
  end
  local copy = {}
  for i, id in ipairs(offer) do
    copy[i] = id
  end
  d.offers[k] = copy
  local out = {}
  for _, id in ipairs(offer) do
    local p = pool.by[id]
    if p then
      out[#out + 1] = p
    end
  end
  return out
end

-- take candidate i (0-based) of place k (1-based): spec, id; nil, why
local function draft_pick(d, pool, k, i)
  local spec = pool.slots[k]
  if not spec then
    return nil, "no slot " .. (k - 1)
  end
  if d.picks[k] then
    return nil, "slot " .. spec.slot .. " is already picked"
  end
  local offer = candidates(d, pool, k)
  local p = offer[i + 1]
  if not p then
    return nil, "candidate " .. i .. " of " .. #offer
  end
  d.picks[k] = p.param
  d.offers[k] = nil
  return spec, p.param
end

-- slot -> id of every place picked
local function draft_roster(d, pool)
  local out = {}
  for k, s in ipairs(pool.slots) do
    if d.picks[k] then
      out[s.slot] = d.picks[k]
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------------ the roster blob

local function roster_doc(pool, d)
  local roster = {}
  for k, s in ipairs(pool.slots) do
    if d.picks[k] then
      roster[#roster + 1] = { s.slot, d.picks[k] }
    end
  end
  return { version = ROSTER_VERSION, team = pool.team, roster = roster }
end

-- the picks in pool order when the stored roster fits the pool (same team, every place once, ids in the pool)
local function roster_picks(doc, pool)
  if type(doc) ~= "table" or doc.version ~= ROSTER_VERSION or U.u32(doc.team) ~= pool.team then
    return nil, string.format("version %s / team %s (pool team %s)", tostring(type(doc) == "table" and doc.version),
      U.hex(type(doc) == "table" and doc.team or 0), U.hex(pool.team))
  end
  local by, n, entries = {}, 0, 0
  for _, e in ipairs(type(doc.roster) == "table" and doc.roster or {}) do
    entries = entries + 1
    if type(e) == "table" and type(e[1]) == "number" and type(e[2]) == "number" then
      if by[e[1]] == nil then
        n = n + 1
      end
      by[e[1]] = U.u32(e[2])
    end
  end
  if n ~= entries or n ~= #pool.slots then
    return nil, entries .. " roster entries for " .. #pool.slots .. " slots"
  end
  local picks = {}
  for _, s in ipairs(pool.slots) do
    local id = by[s.slot]
    if id == nil then
      return nil, "slot " .. s.slot .. " missing"
    elseif not pool.by[id] then
      return nil, string.format("slot %d: %08X not in the pool", s.slot, id)
    end
    picks[#picks + 1] = id
  end
  return picks
end

-- the active save slot (1 while the slot service is not ready)
local function current_slot()
  local ok, n = pcall(VRFW.slots.active)
  if ok and type(n) == "number" and n ~= 0 then
    return floor(n)
  end
  return 1
end

local function blob_desc(n)
  return BLOB .. " (slot " .. n .. ")"
end

local function imported_slots()
  local ok, b = pcall(VRFW.save.blob, IMPORTS, "global")
  if ok and type(b) == "string" then
    local t = VRFW.json.decode(b)
    if type(t) == "table" then
      return t
    end
  end
  return {}
end

-- slot n's old loader-data file must never come back (the blob is the truth from now on)
local function mark_imported(n)
  local t = imported_slots()
  if t[tostring(n)] then
    return
  end
  t[tostring(n)] = true
  local ok, written, why = pcall(VRFW.save.blob_write, IMPORTS, VRFW.json.encode(t), "global")
  if not (ok and written) then
    warn("import marker not written (" .. tostring(ok and why or written) .. ")")
  end
end

-- the DLL's `<loader data dir>\bb_draft_slot<N>.json` into the blob, once per slot (the file is kept as it is)
local function import_old(n)
  if imported_slots()[tostring(n)] then
    return
  end
  local file = "bb_draft_slot" .. n .. ".json"
  local ok, done_, why = pcall(VRFW.data.import_once, file, BLOB, n)
  if not ok then
    warn(file .. " not imported (" .. tostring(done_) .. ")")
    return
  end
  why = tostring(why or "")
  if done_ then
    info(file .. " imported into " .. blob_desc(n) .. " (the old file is kept)")
  elseif not (string.find(why, "no such file", 1, true) or string.find(why, "exists already", 1, true)) then
    warn(file .. " not imported (" .. why .. "): tried again next time")
    return
  end
  mark_imported(n)
end

local function save_roster(r)
  if not r.draft then
    return
  end
  local n = current_slot()
  mark_imported(n)
  local ok, done_, why = pcall(VRFW.save.blob_write, BLOB, VRFW.json.encode(roster_doc(r.pool, r.draft), true), n)
  if ok and done_ then
    info("roster kept in " .. tostring(why) .. " (campaign running)")
  else
    warn(blob_desc(n) .. " not written (" .. tostring(ok and why or done_) .. "): after a restart the campaign plays the placeholders")
  end
end

-- the stored roster of the active slot: doc; nil, why
local function load_roster(slot)
  local n = slot or current_slot()
  import_old(n)
  local ok, b, why = pcall(VRFW.save.blob, BLOB, n)
  if not ok then
    return nil, blob_desc(n) .. ": " .. tostring(b)
  end
  if type(b) ~= "string" then
    return nil, blob_desc(n) .. ": " .. tostring(why or "none")
  end
  local doc, jerr = VRFW.json.decode(b)
  if doc == nil then
    return nil, blob_desc(n) .. ": " .. tostring(jerr)
  end
  return doc
end

local function drop_roster()
  local n = current_slot()
  mark_imported(n)
  local ok, b = pcall(VRFW.save.blob, BLOB, n)
  if ok and type(b) == "string" then
    local ok2, where = pcall(VRFW.save.blob_aside, BLOB, n)
    if ok2 then
      info(blob_desc(n) .. " removed (campaign over): " .. tostring(where))
    else
      warn(blob_desc(n) .. " not removed (" .. tostring(where) .. ")")
    end
  end
end

-- ------------------------------------------------------------------------------------------------ the session

local RT = nil       -- { pool, draft, phase, written, src }
local FAILED = false -- the pool could not be derived (logged once): no Draft this session
local BEGUN = 0

local function set_phase(r, p)
  r.phase = p
  pcall(VRFW.state.set, KEY_PHASE, p)
end

-- every Battle Bay squad but the Draft's, as the game holds it: { { team, { { slot, param } … } } … }, the unlock
-- conditions of every team's enjoy rows ({ [team] = { cond … } }, static game data: a new draft evaluates only those
-- of the teams it may leave out) and the number of teams whose member rows were not readable
local function bb_squads(draft)
  local rows, why = G.enjoy_rows()
  if not rows then
    fail(why)
  end
  local seen, out, conds, unread = {}, {}, {}, 0
  for _, row in ipairs(rows) do
    local t = row.team
    if t ~= 0 then
      local c = conds[t]
      if not c then
        c = {}
        conds[t] = c
      end
      c[#c + 1] = row.cond
    end
    if t ~= 0 and t ~= draft and not seen[t] then
      seen[t] = true
      local r = D.roster(t)
      if r then
        out[#out + 1] = { team = t, members = r }
      else
        unread = unread + 1
      end
    end
  end
  return out, conds, unread
end

-- the pool and a fresh session (phase NONE). `quiet` (a preparation: "script load" / "save load", its label): a
-- failure only defers the build to the first Draft command (logged as info), it does not turn the Draft off. The
-- script-load preparation runs before the commands are bound (VRFW.is_on not answered yet): it checks the team only.
local function build(quiet)
  if not DECL or (quiet == "script load" and TEAM or D.team()) == 0 then
    return nil
  end
  local t0 = VRFW.now()
  local ok, res = pcall(function()
    local sx = static_tables()
    local slots, params = sx.slots, sx.params
    local t1 = VRFW.now()
    local squads, conds, unread = bb_squads(TEAM)
    local t2 = VRFW.now()
    local rule = { special = CFG.special, exclude = CFG.exclude }
    local st = { squads = #squads, members = 0, staff = 0, unknown = 0, special = 0, no_position = 0, excluded = 0 }
    local lists = {}
    for i, sq in ipairs(squads) do
      lists[i] = eligible(sq.members, params, rule, st)
      sq.elig = lists[i]
    end
    local players, merged = pool_from(lists, params, sx.keys)
    info(string.format("pool derived: %d players from %d Battle Bay squads (%d members; left out: staff %d, not in "
      .. "chara_param %d, special cards %d, no position %d, excluded %d; variants of one character merged %d), %d slots, "
      .. "formation %s", #players, st.squads, st.members, st.staff, st.unknown, st.special, st.no_position, st.excluded,
      merged, #slots, U.hex(DECL.formation)))
    info(string.format("pool build%s: tables %d ms, squads %d ms (%d team(s) without readable member rows), pool %d ms",
      quiet and (" (" .. quiet .. ")") or "", t1 - t0, t2 - t1, unread, VRFW.now() - t2))
    local pool = { team = TEAM, formation = DECL.formation, level = DECL.level, slots = slots, players = players }
    index_players(pool)
    local bad = validate(pool)
    if bad then
      fail(bad)
    end
    local written = {}
    for _, sl in ipairs(slots) do
      written[sl.slot] = sl.placeholder
    end
    return { pool = pool, draft = nil, phase = NONE, written = written,
      src = { squads = squads, conds = conds, params = params, keys = sx.keys, all = players, open = nil } }
  end)
  if ok then
    return res
  end
  if quiet then
    info("pool not prepared at the " .. quiet .. " (" .. tostring(res) .. "): derived by the first Draft command")
    return nil
  end
  err("the pool cannot be derived (" .. tostring(res) .. "): the Draft tile does nothing this session")
  FAILED = true
  return nil
end

local function with()
  if RT == nil and not FAILED then
    RT = build()
  end
  return RT
end

-- The game's tables now (script load, the boot thread): the first Draft command only reads the squads.
if DECL then
  local t0 = VRFW.now()
  local ok, e = pcall(static_tables)
  if ok then
    info(string.format("pool tables read at load in %d ms (%d slots)", VRFW.now() - t0, #e.slots))
  else
    info("pool tables not read at load (" .. tostring(e) .. "): read by the first build")
  end
  -- the squads and the pool too (the boot thread): the save engine's slot_load below only runs on a slot switch,
  -- never for the boot's own load (2026-10-13 loader.log: the first CMND_BBCR_DRAFT_INFO still took 60 ms, «pool
  -- build: tables 0 ms, squads 30 ms, pool 27 ms»)
  if ok and RT == nil and not FAILED then
    RT = build("script load")
  end
end

-- The squads and the pool at the save load (the loading screen, off the game thread), so opening the Draft costs no
-- pool build; anything not ready yet leaves it to the first Draft command (quiet build).
VRFW.on("slot_load", function(ev)
  if RT == nil and not FAILED and D.team() ~= 0 then
    local r = build("save load")
    if r and RT == nil then
      RT = r
    end
  end
  -- 1.5.42: the running draft run's roster of the loaded slot back on the rows (D.slot_roster, below)
  local ok, e = pcall(D.slot_roster, type(ev) == "table" and ev.slot or nil)
  if not ok then
    err("slot_load: roster not restored: " .. tostring(e))
  end
end)

-- make the rows hold `want` (slot -> id; other places their placeholder); nothing written when the layout guard
-- refuses: rows written; nil, why
local function apply(r, want)
  local now, why = read_rows(r.pool.team)
  if not now then
    return nil, why
  end
  local plan, perr = plan_writes(now, r.pool, r.written, want)
  if not plan then
    return nil, perr
  end
  for _, w in ipairs(plan) do
    if not write_row(w.row, w.id) then
      return nil, "write of row at " .. U.hex(w.row.addr) .. " failed"
    end
  end
  for _, s in ipairs(r.pool.slots) do
    r.written[s.slot] = want[s.slot] or s.placeholder
  end
  return #plan
end

-- placeholders back, no draft
local function restore(r)
  r.draft = nil
  set_phase(r, NONE)
  return apply(r, {})
end

local function session_slots(r)
  local out = {}
  for k, s in ipairs(r.pool.slots) do
    out[k] = { spec = s, pick = r.draft and r.draft.picks[k] or nil }
  end
  return out
end

local function campaign_started(r)
  if r.phase == COMPLETE then
    set_phase(r, CAMPAIGN)
    return true
  end
  return false
end

-- ------------------------------------------------------------------------------------------------ enjoy row leader

-- the leader the Draft row must name: the member in slot 0 (the captain row), else the first row
local function leader_of(rows)
  local pick = rows[1]
  for _, r in ipairs(rows) do
    if r.slot == 0 then
      pick = r
      break
    end
  end
  if pick and pick.param ~= 0 then
    return pick.param
  end
  return nil
end

-- Keeps the Draft row's leader (EnjoyRow.leader) on a member of the team (estadio-bb.md §14.14): the campaign scene
-- setup (0xF1A8E0) looks the player team's leader up among its member rows; a leader that is no member any more
-- never finished loading the first campaign match (2026-10-06). After every roster write and before the campaign.
local function sync_leader(why)
  local team = D.team()
  if team == 0 then
    return nil
  end
  local rows, rerr = read_rows(team)
  if not rows then
    warn("leader not checked (" .. why .. "): roster rows of " .. U.hex(team) .. ": " .. tostring(rerr))
    return nil
  end
  local lead = leader_of(rows)
  if not lead then
    return nil
  end
  local row = G.enjoy_row(team)
  local er = row and U.struct("EnjoyRow", row)
  if not er then
    warn("leader not checked (" .. why .. "): no enjoy row of " .. U.hex(team) .. " in memory")
    return nil
  end
  local old = U.get(er, "leader") or 0
  if old == lead then
    return lead
  end
  if pcall(function()
    er.leader = lead
  end) then
    info(string.format("Draft row leader %s -> %s (slot 0 member, %s)", U.hex(old), U.hex(lead), why))
    return lead
  end
  err(string.format("Draft row leader NOT written (%s): %s stays, not a member", why, U.hex(old)))
  return nil
end

-- ------------------------------------------------------------------------------------------------ runs that play the Draft
-- 1.5.42 (owner: a Torneo / Campaña played with the Draft team came back as Raimon after «Continuar», and could crash
-- at the match start). The drafted squad only lives on the team's rows in memory; after a restart only the top menu's
-- sync put it back, and that sync was grafted on bb_stadium_top_menu, which the Battle Bay no longer opens (Inazuma
-- Fantasy's «Modos de juego» hosts it on soccer_top_menu), and it knew only the Campaña (a Torneo with the Draft was
-- «another team»: its roster discarded). Now: a run owns the drafted squad when the Campaña's block or the Torneo's
-- run (D.tournament_team, set by campaign.lua) plays the Draft team; the squad comes back at the save load (from the
-- slot's blob), at every top-menu sync (both menus) and before every Torneo match, and every restore is checked (each
-- row a placeholder or a pool player, the row's leader a member) with the placeholders as the safe fallback.

-- the Draft team hash of the running Torneo's player (0 = none); campaign.lua sets it
D.tournament_team = nil

local function tournament_owns(team)
  if type(D.tournament_team) ~= "function" then
    return false
  end
  local ok, t = pcall(D.tournament_team)
  return ok and type(t) == "number" and t ~= 0 and U.u32(t) == team
end

-- the rows of the Draft team as the match builder will read them, checked: every row a placeholder or a pool player
-- (chara_param), the enjoy row's leader one of them. true; false, why
local function rows_sane(r)
  local rows, why = read_rows(r.pool.team)
  if not rows then
    return false, why
  end
  local ph, ids = {}, {}
  for _, s in ipairs(r.pool.slots) do
    ph[s.placeholder] = true
  end
  for _, row in ipairs(rows) do
    local known = ph[row.param] or r.pool.by[row.param] or (r.src and r.src.params and r.src.params[row.param])
    if row.param == 0 or row.param ~= row.uid or not known then
      return false, string.format("slot %d holds %08X/%08X", row.slot, row.param, row.uid)
    end
    ids[row.param] = true
  end
  local er = G.enjoy_row(r.pool.team)
  local lead = er and U.get(U.struct("EnjoyRow", er), "leader") or nil
  if lead ~= nil and not ids[lead] then
    return false, "enjoy row leader " .. U.hex(lead) .. " is no member"
  end
  return true
end

-- the stored roster of a run back on the rows (phase CAMPAIGN); a failure leaves the placeholders (never a half
-- written or unknown squad: the match would build it). rows written; nil, why
local function restore_run(r, why, slot)
  local n, e
  if r.phase == CAMPAIGN and r.draft then
    n, e = apply(r, draft_roster(r.draft, r.pool))
  else
    local doc, picks
    doc, e = load_roster(slot)
    if doc then
      picks, e = roster_picks(doc, r.pool)
    end
    if picks then
      local d = draft_from_picks(picks)
      n, e = apply(r, draft_roster(d, r.pool))
      if n then
        r.draft = d
        set_phase(r, CAMPAIGN)
      end
    end
  end
  sync_leader(why)
  local sane, serr = true, nil
  if n then
    sane, serr = rows_sane(r)
  end
  if n and sane then
    info(string.format("%s: the run's drafted squad on the rows (%d rows written)", why, n))
    return n
  end
  e = n and ("check failed: " .. tostring(serr)) or e
  local back = restore(r)
  sync_leader(why .. ", fallback")
  err(string.format("%s: the run's drafted squad NOT restored (%s): %s", why, tostring(e),
    back and "placeholders on the rows" or "placeholders not written either"))
  return nil, e
end

local SLOT_DONE = nil -- the save slot whose stored run roster was dealt with (D.slot_roster)

-- the save load: the loaded slot's running draft run (its blob) on the rows; a draft of another slot / session off
function D.slot_roster(slot)
  if D.team() == 0 or FAILED then
    return
  end
  local has = false
  local n = slot or current_slot()
  SLOT_DONE = n
  local ok, b = pcall(VRFW.save.blob, BLOB, n)
  has = ok and type(b) == "string"
  if not has and RT == nil then
    return -- nothing written this session, nothing stored: the placeholders stand
  end
  local r = with()
  if not r then
    return
  end
  if has then
    -- the roster of THIS slot (its blob), never what the last slot / session left in memory
    r.draft = nil
    set_phase(r, NONE)
    restore_run(r, "save load (slot " .. n .. ")", n)
  elseif r.phase ~= NONE then
    local back = restore(r)
    sync_leader("save load")
    info("save load (slot " .. n .. "): no draft run stored, placeholders back (" .. tostring(back) .. " rows)")
  end
end

-- The save engine's slot_load never runs for the boot's own load (only on a slot switch): the first Draft command /
-- top-menu sync / Torneo match of a slot does what it would have done (once per slot).
local function ensure_slot()
  local ok, n = pcall(VRFW.slots.active)
  if not ok or type(n) ~= "number" or n == 0 then
    return
  end
  n = floor(n)
  if SLOT_DONE ~= n then
    local ok2, e = pcall(D.slot_roster, n)
    if not ok2 then
      err("first use of slot " .. n .. ": roster not restored: " .. tostring(e))
      SLOT_DONE = n
    end
  end
end

-- before a Torneo match with the Draft team (TournPrepare): the drafted squad on the rows, checked. true when the
-- rows are safe to build (the drafted squad, or the placeholders as the fallback)
function D.before_run_match(why)
  local team = D.team()
  if team == 0 then
    return true
  end
  ensure_slot()
  local r = with()
  if not r then
    return true
  end
  if r.phase == CAMPAIGN and r.draft then
    local ok = rows_sane(r)
    if ok then
      sync_leader(why)
      return true
    end
  end
  restore_run(r, why)
  return true
end

-- ------------------------------------------------------------------------------------------------ for the Decide hook

-- a complete draft is on the rows (the campaign may start with it)
function D.ready_to_play()
  local r = with()
  return r ~= nil and (r.phase == COMPLETE or r.phase == CAMPAIGN)
end

-- the Campaña is about to start with the Draft team (Decide pre-phase): leader synced, the roster in the log
function D.before_campaign()
  local team = D.team()
  if team == 0 then
    return
  end
  local lead = sync_leader("campaign start")
  local rows, why = read_rows(team)
  if not rows then
    err("campaign start: roster rows of " .. U.hex(team) .. " unreadable: " .. tostring(why))
    return
  end
  local list, member = {}, false
  for _, r in ipairs(rows) do
    list[#list + 1] = string.format("%d:%08X", r.slot, r.param)
    if lead and r.param == lead then
      member = true
    end
  end
  local row = G.enjoy_row(team)
  local leader = row and U.get(U.struct("EnjoyRow", row), "leader") or 0
  info(string.format("campaign start with %s: %d rows [%s], enjoy leader %s (member: %s)", U.hex(team), #rows,
    table.concat(list, " "), U.hex(leader), tostring(member)))
end

-- the campaign really started with the Draft team (the Decide post-phase saw the session block filled)
function D.campaign_started()
  local r = with()
  if r and campaign_started(r) then
    save_roster(r)
    info("campaign started with the drafted team")
  end
end

-- ------------------------------------------------------------------------------------------------ the commands

function BattleBayDeluxe.DraftInfo()
  ensure_slot()
  local r = with()
  if not r then
    return false
  end
  local n = r.draft and filled(r.draft) or 0
  return true, r.pool.team, r.phase, n, #r.pool.slots
end

-- the pool of a new draft: every squad but those of the teams the «win it to unlock it» rule still locks in this
-- save slot (a rule team whose chain tile is won, or whose row condition holds, is in). Without the rule / the
-- evaluator, or when the smaller pool cannot fill the places: every player (logged).
-- the teams of `pending` whose unlock condition is not met right now (any of their enjoy rows); nil = the evaluator is
-- not available. Same answer as G.locked_teams() for these teams, without evaluating every other row.
local function locked_of(src, pending)
  if not VRFW.is_on("EvalCondition") then
    return nil
  end
  local out = {}
  for _, t in ipairs(pending) do
    for _, c in ipairs(src.conds and src.conds[t] or {}) do
      if c ~= 0 and G.eval(c) ~= true then
        out[t] = true
        break
      end
    end
  end
  return out
end

local function open_pool(r)
  local src = r.src
  if not src then
    return
  end
  local pending = {}
  for _, sq in ipairs(src.squads) do
    if (G.unlock_rule(sq.team) or -1) == 0 then
      pending[#pending + 1] = sq.team
    end
  end
  local players = src.all
  if #pending > 0 then
    local locked = locked_of(src, pending)
    if locked then
      local shut, nshut, sig = {}, 0, {}
      for _, t in ipairs(pending) do
        if locked[t] then
          shut[t] = true
          nshut = nshut + 1
          sig[#sig + 1] = t
        end
      end
      local key = table.concat(sig, ",")
      local o = src.open
      if not o or o.key ~= key then
        -- the pool of these squads (none left out = the derived pool), kept until the locked set changes
        local lists = {}
        for _, sq in ipairs(src.squads) do
          if not shut[sq.team] then
            lists[#lists + 1] = sq.elig
          end
        end
        local pl = nshut == 0 and src.all or pool_from(lists, src.params, src.keys)
        o = { key = key, players = pl, squads = #lists, shut = nshut,
          bad = validate({ team = r.pool.team, slots = r.pool.slots, players = pl }) }
        src.open = o
      end
      if not o.bad then
        info(string.format("pool of this draft: %d players from %d squads (%d squad(s) of teams still locked left out)",
          #o.players, o.squads, o.shut))
        players = o.players
      else
        warn(string.format("without the %d locked squad(s) the pool cannot fill the draft (%s): every squad is used",
          o.shut, o.bad))
      end
    else
      warn("the unlock conditions cannot be evaluated: every squad is used")
    end
  end
  if r.pool.players ~= players then
    r.pool.players = players
    index_players(r.pool)
  end
end

function BattleBayDeluxe.DraftBegin()
  local r = with()
  local total = nil
  if r then
    open_pool(r)
    if r.phase == CAMPAIGN then
      -- a new campaign replaces the running one (the game's «Nueva campaña»): its roster goes
      drop_roster()
    end
    local n = BEGUN
    BEGUN = BEGUN + 1
    local h, l
    if CFG.seed ~= 0 then
      h, l = U.split64(CFG.seed)
      l = bit32.bxor(l, 0xD4AF7000, n % U.TWO32)
    else
      h, l = U.entropy(U.global("enjoy") or 0, n)
    end
    local ok, why = restore(r)
    if ok then
      r.draft = new_draft(U.rng(h, l), #r.pool.slots)
      set_phase(r, PICKING)
      total = #r.pool.slots
      info(string.format("begin (seed %s:%s, %d picks, %d players)", U.hex(h), U.hex(l), total, #r.pool.players))
    else
      err("cannot begin, roster rows of " .. U.hex(r.pool.team) .. ": " .. tostring(why))
    end
  end
  if total then
    sync_leader("begin")
  end
  return total ~= nil, total or 0
end

function BattleBayDeluxe.DraftSlots()
  local r = with()
  if not r then
    return false
  end
  return true, #r.pool.slots
end

function BattleBayDeluxe.DraftSlot(k)
  k = U.int(k, -1)
  local r = with()
  local e = r and k >= 0 and session_slots(r)[k + 1]
  if not e then
    return false
  end
  local s = e.spec
  return true, s.slot, s.pos, s.x, s.y, e.pick or 0, s.placeholder
end

function BattleBayDeluxe.DraftCands(k)
  k = U.int(k, -1)
  local r = with()
  if not r or r.phase ~= PICKING or k < 0 or not r.draft then
    return false
  end
  local spec = r.pool.slots[k + 1]
  if not spec then
    return false
  end
  local list = candidates(r.draft, r.pool, k + 1)
  if #list == 0 then
    return false
  end
  local out = { true, k, spec.slot, spec.pos, #list }
  for _, p in ipairs(list) do
    out[#out + 1] = p.param
    out[#out + 1] = p.pos
  end
  return table.unpack(out)
end

function BattleBayDeluxe.DraftPick(k, i)
  k, i = U.int(k, -1), U.int(i, -1)
  local r = with()
  local got
  if r then
    local why
    if r.phase ~= PICKING or k < 0 or i < 0 or not r.draft then
      why = string.format("pick %d/%d refused (phase %s)", k, i, PHASE_NAME[r.phase] or tostring(r.phase))
    else
      local spec, id = draft_pick(r.draft, r.pool, k + 1, i)
      if not spec then
        why = id
      else
        local want = draft_roster(r.draft, r.pool)
        local fin, n = done(r.draft), filled(r.draft)
        local ok, aerr = apply(r, want)
        if not ok then
          restore(r)
          why = aerr
        else
          if fin then
            set_phase(r, COMPLETE)
          end
          got = { done = fin, slot = spec.slot, id = id, filled = n }
        end
      end
    end
    if got then
      info(string.format("pick %d/%d: slot %d = %s", got.filled, #r.pool.slots, got.slot, U.hex(got.id)))
      if got.done then
        info(string.format("complete (%d players on the rows of %s)", #r.pool.slots, U.hex(r.pool.team)))
      end
    else
      warn(tostring(why))
    end
  end
  if got then
    sync_leader("pick")
    return true, got.done, got.slot, got.id, got.filled
  end
  return false
end

function BattleBayDeluxe.DraftAbandon()
  -- only a Draft of this session can be in progress (a freshly derived pool starts at NONE): no pool is derived just
  -- to abandon nothing (2026-10-13: «Partida nueva» spent 3 s deriving the 9000-member pool here)
  local r = RT
  if r and (r.phase == PICKING or r.phase == COMPLETE) then
    local ok, why = restore(r)
    if ok then
      info("abandoned: placeholders back")
    else
      err("abandoned, placeholders NOT written back (" .. tostring(why) .. ")")
    end
  end
  sync_leader("abandon")
  return true
end

-- The «pack opening» look of the candidates (config.toml [draft.pack], read once): the graft bb_draft asks it when
-- the Draft screen opens. Answers, in this order: ok, intro, deal, deal_stagger, flip, settle, flash, gap, suspense,
-- outro (seconds), dim (0..1), scale, spacing (px), and the crc32 of the 4 sound names (open, deal, reveal, best).
local PACK = nil
local PACK_KEYS = {
  { "intro", 0.25 }, { "deal", 0.22 }, { "deal_stagger", 0.07 }, { "flip", 0.22 }, { "settle", 0.12 },
  { "flash", 0.30 }, { "gap", 0.45 }, { "suspense", 0.40 }, { "outro", 0.28 }, { "dim", 0.72 }, { "scale", 1.6 },
  { "spacing", 330 },
}
local PACK_SE = { { "se_open", "sy0000" }, { "se_deal", "sy0009" }, { "se_reveal", "sy0010" }, { "se_best", "sy0080" } }

local function pack_look()
  if PACK then
    return PACK
  end
  local t = U.config("draft.pack", nil)
  if type(t) ~= "table" then
    t = {}
  end
  local function get(k, d)
    local v = t[k]
    if v == nil then
      v = U.config("draft.pack." .. k, d)
    end
    return v
  end
  local out = {}
  for _, kv in ipairs(PACK_KEYS) do
    local v = tonumber(get(kv[1], kv[2]))
    if v == nil or v < 0 then
      warn("[draft.pack] " .. kv[1] .. ": not a number >= 0, " .. tostring(kv[2]) .. " used")
      v = kv[2]
    end
    out[#out + 1] = v
  end
  for _, kv in ipairs(PACK_SE) do
    local v = get(kv[1], kv[2])
    if type(v) ~= "string" or U.trim(v) == "" then
      v = kv[2]
    end
    out[#out + 1] = U.crc32(U.trim(v))
  end
  PACK = out
  info("pack opening look: " .. #out .. " values from [draft.pack]")
  return PACK
end

function BattleBayDeluxe.DraftPack()
  local ok, p = pcall(pack_look)
  if not ok then
    err("[draft.pack] unreadable: " .. tostring(p))
    return false
  end
  return true, table.unpack(p)
end

function BattleBayDeluxe.DraftSync(active, player)
  ensure_slot()
  active = U.int(active, 0) ~= 0
  -- a team hash (negative numbers wrap like the engine's (u32) cast)
  player = U.u32(U.int(player, 0))
  local team0 = D.team()
  local owned = (active and player ~= 0 and player == team0) or (team0 ~= 0 and tournament_owns(team0))
  if RT == nil and not FAILED and not owned then
    -- no pool yet and no campaign with the Draft team: nothing was written this session (the rows hold the
    -- placeholders), so only a stale stored roster goes; the pool (every Battle Bay squad, chara_param, names) is
    -- derived when the Draft is used (2026-10-13: deriving it here cost 5.8 s on entering the Estadio BB)
    if D.team() == 0 then
      return -1
    end
    drop_roster()
    sync_leader("sync")
    return NONE
  end
  local r = with()
  local phase = -1
  if r then
    local was = r.phase
    local team = r.pool.team
    -- the Campaña's block or the Torneo's run plays the Draft team (1.5.42: the Torneo too)
    local ours = team ~= 0 and ((active and player == team) or tournament_owns(team))
    if ours and (was == COMPLETE or was == CAMPAIGN) then
      -- keep (and write the roster again: the rows may have been reloaded)
      local want = r.draft and draft_roster(r.draft, r.pool) or {}
      campaign_started(r)
      local ok, why = apply(r, want)
      if ok then
        if was == COMPLETE then
          save_roster(r)
        end
      else
        err("campaign running but the roster was not written again: " .. tostring(why))
      end
    elseif ours then
      -- restart during a draft run (or the rows reloaded): the stored roster, checked (placeholders as the fallback)
      restore_run(r, "top menu sync")
    else
      -- campaign won / lost, another team, no campaign; with no draft a stale roster still goes
      local ok, why = true, nil
      local n = 0
      if was ~= NONE then
        n, why = restore(r)
        ok = n ~= nil
      end
      if ok then
        if was ~= NONE then
          info("discarded (campaign over or another team): placeholders back (" .. n .. " rows)")
        end
      else
        err("discarded, placeholders NOT written back (" .. tostring(why) .. ")")
      end
      drop_roster()
    end
    phase = r.phase
  end
  sync_leader("sync")
  return phase
end

-- ------------------------------------------------------------------------------------------------ the Draft tile model
-- The team panel shows the hovered slot's leader as its 3D model. The Draft team's leader is a placeholder: the
-- grid records of the Draft tile get the player's own avatar instead (estadio-bb.md §14.10), on every grid page the
-- VR-Framework's BB pages service builds. Only the grid image changes, never the table row.

local AVATAR_LOGGED = nil

-- the status object (FindCharaRecord result; persistent data at +8) of a character handle
local function record_object(hdl)
  if not VRFW.is_on("FindCharaRecord") or hdl == 0 or hdl % 65536 >= 0xD000 then
    return nil
  end
  local kind = floor(hdl / 4096) % 16
  local conts = U.global("chara_containers")
  local cont = conts and U.rdp(conts + 8 + kind * 8)
  if not cont then
    return nil
  end
  local okb, hb = pcall(VRFW.mem.buffer, "bbd_avatar_hdl", 4)
  if not okb or not U.wr("u32", hb, hdl) then
    return nil
  end
  local ok, rec = U.call("FindCharaRecord", cont, hb)
  if ok and type(rec) == "number" and rec >= 0x10000 then
    return rec
  end
  return nil
end

-- the player's avatar as a chara_param id: the Kizuna town avatar (a chara handle, index 0 only) through its save
-- record; nil when the save has no usable avatar
local function avatar_param()
  local kz = U.struct("Kizuna", U.global("kizuna"))
  local hdl, idx = U.get(kz, "avatar"), U.get(kz, "avatar_index")
  if not hdl or idx ~= 0 or hdl == 0 or hdl % 65536 >= 0xD000 then
    return nil
  end
  local obj = record_object(hdl)
  local rec8 = obj and U.rdp(obj + 8)
  if not rec8 or U.rd("u32", rec8) ~= hdl then
    return nil
  end
  local p = U.rd("u32", rec8 + 4)
  if p and p ~= 0 then
    return p
  end
  return nil
end

VRFW.on("hook:VRFW.BbRecord", function(ev)
  local img, len = ev.args[1], ev.args[2]
  if type(img) ~= "number" or img < 0x10000 or type(len) ~= "number" or len < OBJ_SIZE then
    return nil
  end
  local team = D.team()
  if team == 0 then
    return nil
  end
  local avatar = avatar_param()
  local key = avatar or 0
  if AVATAR_LOGGED ~= key then
    AVATAR_LOGGED = key
    if avatar then
      info("the Draft tile's panel model = the player's avatar " .. U.hex(avatar))
    else
      warn("no usable Kizuna avatar in this save: the Draft tile keeps its placeholder model")
    end
  end
  if not avatar then
    return nil
  end
  for i = 0, G.SLOTS - 1 do
    local rec = img + G.SLOT_BASE + i * G.SLOT_STRIDE
    if U.rd("u32", rec + 0x4) == team and U.rd("u32", rec + 0x8) ~= avatar then
      U.wr("u32", rec + 0x8, avatar)
    end
  end
  return nil
end)

return D
