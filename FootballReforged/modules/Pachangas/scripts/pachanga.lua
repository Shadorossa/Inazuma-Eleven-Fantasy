-- Pachangas (module of Football Reforged) › «Pachanga» (5v5) templates of the team dock (docs/game/ui/pachanga-templates.md).
-- Declarations: content\game\pachanga.toml (commands CMND_PACHANGAS_*, aliases CMND_FANTASY_PACHANGA_* /
-- CMND_EVT_PACHANGA_*). Inazuma Fantasy's module pachanga until 2026-10-15; the game Lua is the grafts pachanga_dock,
-- pachanga_bank, pachanga_equip, pachanga_formation and pachanga_plate (mod = "pachangas").
--
-- * The templates are native: every user dock (logical team set 2..12) holds a 5v5 team in teamInfo[1] next to its
--   11v11 team (teamInfo[0]); Utilities' team bank pages swap them with the docks. The active «Partido» team is the
--   retail vsUseTeamSet; the active «Pachanga» team is always its pair, the 5v5 team of the same dock (since 1.13.0;
--   no own pointer). Blob pachanga.json of the slot (owner pachangas; Inazuma Fantasy's copy is imported once:
--   content\game\save_import.toml): {"version": 1, "slot": 2, "vs_restore": 4, "mirrored": {"1": [3, 4]}}, per team
--   bank page (the page mounted by Utilities, game_state utilities.team_banks.mounted). The "active" map and the
--   "split" marks of older files are ignored on load and dropped at the next write (the 5v5 teams live in the save).
-- * vs_restore: the vsUseTeamSet to put back after a «Desafío de fichaje» (kept on disk: a crash or a title return can
--   still restore it). mirrored: per page, the docks whose 5v5 team was brought to the mirror rule once (the old-save
--   migration of CMND_PACHANGAS_MIRROR).
-- * Mirror rule (1.14.0): the 5v5 team of dock N holds exactly the players of its 11v11 team (positions 0..15); its
--   five starters are filled from them by the 5v5 formation's positions and can be rearranged among them only.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_EVT_PACHANGA_INFO | – | ok, active dock (-1 none), 5v5 members of it, bank (1-based), slot |
-- | CMND_EVT_PACHANGA_SET | dock (2..12) | ok, code (only the active match dock is accepted: the pair is fixed) |
-- | CMND_EVT_PACHANGA_TEAM | – | ok, dock, formation dword, team name, n, handle x n (the active 5v5 team) |
-- | CMND_EVT_PACHANGA_VS | op (1 remember, 0 take, 2 peek), vs set | ok, vs set (-1 none) |
-- | CMND_EVT_PACHANGA_FLAGS | – | fixed (dock bits put back on 11v11 / 5v5 members; -1 = not ready) |
-- | CMND_PACHANGAS_MIRROR | dock, 5v5 formation id | changes (-1 = n/a), players removed, players added (the mirror rule) |
-- | CMND_EVT_PACHANGA_TEAMSWAP | dock, on (1 / 0) | ok, swapped dock (-1 none): 11v11 <-> 5v5 members for the team bonuses screen |
--
-- Team-set layout (v7.1.2): a set is 0x874 bytes = 3 teams of 0x2D0 (name 0x80, member k at 0x80 + k * 0x10: handle,
-- +4 dword, +0xE position class; team fields 0x250..0x2C8 = formation, captain…; counters at 0x2C8); the live sets are
-- [party + 0x17B8] + LogicalToPhysical(set) * 0x874. The story / INAROGUE saves keep the retail link.

Pachangas = Pachangas or {}

local band, lshift = bit32.band, bit32.lshift
local ENABLED = true

local BLOB, VERSION = "pachanga.json", 1
local KEY_MOUNTED = "utilities.team_banks.mounted"

local FIRST_DOCK, LAST_DOCK, DOCKS, MAX_BANKS = 2, 12, 11, 32
local SET_SIZE, TEAM_SIZE, MEMBERS, MEMBER_LIST, MEMBER_STRIDE = 0x874, 0x2D0, 29, 0x80, 0x10
local NAME_LEN, TEAM_FIELDS_FROM, TEAM_FIELDS_TO, COUNTERS, TEAMS = 0x80, 0x250, 0x2C8, 0x2C8, 3
local PARTY_SET_DATA, PLAY_MODE, PLAY_MODE_STORY = 0x17B8, 0x2CAC6F, 2
-- party block: vsUseTeamSet, the active match team set (CMND_GET_VS_USE_TEAM_SET)
local PARTY_VS_SET = 0x9F10
-- character record: organizedTeamFlag (u16, bit = logical team set)
local REC_TEAM_FLAG = 0x1EC
-- team fields: the captain's card and handle (TeamInfo +0x2A0 / +0x2A4)
local CAPTAIN_PARAM, CAPTAIN_HDL = 0x2A0, 0x2A4
local C = { OK = 0, BAD_ARGS = 1, NOT_READY = 2, STORY = 3, PAIRED = 4, EXCEPTION = 7 }
-- member entry: the position byte (0 keeper, 1..4 the other 5v5 starters, 5..15 bench, 16..18 managers, 19 coach)
local MEMBER_POSITION, STARTERS, PLAYER_POSITIONS, MATCH_STARTERS = 0xE, 5, 16, 11
-- the game's formations (placements by positionNo, positionId = the place's role)
local FORMATION_STEM = "data/common/gamedata/formation/formation_config"
-- main positions as chara_param numbers them (the formation's roles are mapped to the same numbers)
local GOALKEEPER, FORWARD, MIDFIELDER, DEFENDER = 1, 2, 3, 4

require "VRFW/lib/basics"
require "VRFW/lib/save_doc"
local info, warn = VRFW.logger("pachanga")

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if not at or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function int(v, def)
  if type(v) == "boolean" then return v and 1 or 0 end
  if type(v) ~= "number" then return def end
  if v >= 0 then return math.floor(v) end
  return math.ceil(v)
end

local function dock_no(set) return set - FIRST_DOCK + 1 end

-- ---------------------------------------------------------------------------------------- game memory

local function ready()
  return ENABLED and VRFW.is_on("Party.LogicalToPhysical") and VRFW.is_on("pt_party")
end

local function slot()
  if VRFW.slots.ready() then return VRFW.slots.active() end
  return 1
end

local function play_mode()
  local pd = global("pt_play_data")
  return pd and rd("u8", pd + PLAY_MODE)
end

local function is_story() return play_mode() == PLAY_MODE_STORY end

-- the INAROGUE save is loaded: its 11v11 and 5v5 teams stay linked (docs/game/modes/inarogue.md §20)
-- the INAROGUE save's slot: the mod InaRogue's export InaRogue.SaveSlot (optional); 4 when InaRogue does not answer
local function rogue_slot()
  local ok, s = pcall(function() return InaRogue.SaveSlot() end)
  s = ok and tonumber(s) or nil
  return s and math.floor(s) or 4
end

local function is_rogue() return VRFW.slots.ready() and VRFW.slots.active() == rogue_slot() end

local function is_dock(set) return set >= FIRST_DOCK and set <= LAST_DOCK end
-- docks 02..11 (logical 3..12): the place / move filters keep each call on its own team; dock 01 (set 2) keeps the retail link
local function is_independent(set) return set > FIRST_DOCK and set <= LAST_DOCK end

-- the live address of logical team set `l`
local function set_addr(l)
  local party = global("pt_party")
  if not party then return nil end
  local data = rd("ptr", party + PARTY_SET_DATA)
  if not data or data < 0x10000 then return nil end
  local ok, p = pcall(VRFW.call, "Party.LogicalToPhysical", 0, l)
  if not ok or not p then return nil end
  return data + p * SET_SIZE
end

local function member_off(t, k) return t * TEAM_SIZE + MEMBER_LIST + k * MEMBER_STRIDE end
local function member_handle(addr, t, k) return rd("u32", addr + member_off(t, k)) or 0 end

-- member handles of team t (non-zero, slot order)
local function team_handles(addr, t)
  local v = {}
  for k = 0, MEMBERS - 1 do
    local h = member_handle(addr, t, k)
    if h ~= 0 then v[#v + 1] = h end
  end
  return v
end

-- the live record's organizedTeamFlag of a handle (nil = no live record)
local function team_flag(h)
  local ok, r = pcall(VRFW.chara.record, h)
  if not ok or type(r) ~= "table" or not r.addr then return nil end
  return rd("u16", r.addr + REC_TEAM_FLAG)
end

-- the counters of the load post-pass 0xDA7FE0 for team t of the set at addr: +0x2C8 members, +0x2C9..0x2CC per
-- position class of member byte +0xE (0x13 -> +0x2CA; 0x10..0x12 -> +0x2CB; 0x14..0x1C -> +0x2CC; else +0x2C9),
-- +0x2CF = team index
local function recount(addr, t)
  local c = addr + t * TEAM_SIZE + COUNTERS
  local n = { [0] = 0, 0, 0, 0, 0 }
  for k = 0, MEMBERS - 1 do
    local m = addr + member_off(t, k)
    if (rd("u32", m) or 0) ~= 0 then
      n[0] = n[0] + 1
      local pos = rd("u8", m + 0xE) or 0
      local s
      if pos == 0x13 then s = 2 elseif pos >= 0x10 and pos <= 0x12 then s = 3 elseif pos >= 0x14 and pos <= 0x1C then s = 4 else s = 1 end
      n[s] = n[s] + 1
    end
  end
  for i = 0, 4 do wr("u8", c + i, band(n[i], 0xFF)) end
  wr("u8", c + 7, t)
end

local function recount_team_info(team_addr)
  local ok, e = pcall(VRFW.call, "Party.RecountTeamInfo", team_addr)
  if not ok then warn("RecountTeamInfo: " .. tostring(e)) end
end

local function set_bit(member_addr, l, on)
  local ok, e = pcall(VRFW.call, "Party.SetOrganizedFlagBit", member_addr, l, on)
  if not ok then warn("SetOrganizedFlagBit dock " .. l .. ": " .. tostring(e)) end
  return ok
end

-- empty member slot k of team t the way SetTeamMember does (handle and the +4 dword; the position fields stay) and
-- the team fields (captain) that still name that character; returns the handle
local function clear_member(addr, t, k)
  local m = addr + member_off(t, k)
  local h = rd("u32", m) or 0
  wr("u32", m, 0)
  wr("u32", m + 4, 0)
  if h ~= 0 then
    local base = addr + t * TEAM_SIZE
    for o = TEAM_FIELDS_FROM, TEAM_FIELDS_TO - 4, 4 do
      if rd("u32", base + o) == h then wr("u32", base + o, 0) end
    end
  end
  return h
end

-- ---------------------------------------------------------------------------------------- pachanga.json

local function fresh(s) return { slot = s, vs_restore = nil, mirrored = {} } end

local function bank_ok(k)
  local b = tonumber(k)
  return b and b == math.floor(b) and b >= 1 and b <= MAX_BANKS
end

-- the file's JSON: wrong slot = nil + why; entries that are not a dock or a bank are dropped
local function decode(j, s)
  if tonumber(j.slot) ~= s then return nil, "written for slot " .. tostring(j.slot) .. ", not slot " .. s end
  local f = fresh(s)
  if type(j.active) == "table" and next(j.active) ~= nil then
    info("slot " .. s .. ": stored active pachanga choice ignored (the active 5-a-side team is the active match team's pair)")
  end
  if type(j.split) == "table" and next(j.split) ~= nil then
    info("slot " .. s .. ": old split marks ignored (the 5-a-side teams follow their match team's players)")
  end
  local v = tonumber(j.vs_restore)
  if v and v >= 0 and v < 16 then f.vs_restore = v end
  if type(j.mirrored) == "table" then
    for k, list in pairs(j.mirrored) do
      if bank_ok(k) and type(list) == "table" then
        local seen, out = {}, {}
        for _, x in pairs(list) do
          x = tonumber(x)
          if x and is_dock(x) and not seen[x] then seen[x] = true out[#out + 1] = x end
        end
        table.sort(out)
        if #out > 0 then f.mirrored[tostring(tonumber(k))] = out end
      end
    end
  end
  return f
end

-- an unusable file is left as it is (the next change writes a new one)
local STORE = VRFW.save.doc(BLOB, {
  version = VERSION,
  decode = decode,
  encode = function(f) return { version = VERSION, slot = f.slot, vs_restore = f.vs_restore, mirrored = f.mirrored } end,
  default = fresh,
  pretty = true,
  aside = false,
  log = "pachanga",
})

local function pt_write(f)
  local ok, where = STORE:put(f, f.slot, true)
  if not ok then VRFW.error("pachanga: cannot write the pachanga pointer: " .. tostring(where)) end
  return ok
end

local function with_pt(s) return (STORE:get(s)) end

-- the team bank page Utilities has mounted (0-based), else 0 (pages off / not ready / slot 1 / story)
local function bank()
  local ok, v = pcall(VRFW.state.get, KEY_MOUNTED)
  if ok and type(v) == "number" and v >= 0 and v < MAX_BANKS then return math.floor(v) end
  return 0
end

local function bank_key(b) return tostring(b + 1) end

-- the active pachanga dock: the dock of the active match team (a pending trial / friendly VS swap counts its saved
-- team), nil when that set is not a user dock
local function active_dock(f)
  local v = f.vs_restore
  if v == nil then
    local party = global("pt_party")
    v = party and rd("u8", party + PARTY_VS_SET)
  end
  if v and is_dock(v) then return v end
  return nil
end

-- ---------------------------------------------------------------------------------------- the mirror rule

-- the formation_config file key (the plain file, else its language / version variants)
local function formation_key()
  local plain = FORMATION_STEM .. ".cfg.bin"
  local ok, k = pcall(VRFW.table.keys, plain)
  if ok and type(k) == "table" and #k > 0 then return plain end
  return FORMATION_STEM .. "_*.cfg.bin"
end

-- a placement's positionId as a main position: 1 keeper, 2-3 defence, 4-7 midfield, else forward
local function role_of(position_id)
  if position_id == 1 then return GOALKEEPER end
  if position_id == 2 or position_id == 3 then return DEFENDER end
  if position_id >= 4 and position_id <= 7 then return MIDFIELDER end
  return FORWARD
end

-- formation id -> { [positionNo] = main position } (nil = not readable); read once per formation
local roles_cache = {}
local function formation_roles(id)
  if roles_cache[id] == nil then
    local ok, out = pcall(function()
      local key = formation_key()
      local places = VRFW.table.raw(key, "m_SoccerFormPlacementInfoList")
      for _, r in ipairs(VRFW.table.raw(key, "m_SoccerFormationInfoList")) do
        if type(r.formId) == "number" and math.floor(r.formId) % 4294967296 == id then
          local s = r.placementInfo
          if type(s) ~= "table" or type(s.start) ~= "number" or type(s.count) ~= "number" then return false end
          local roles = {}
          for k = s.start + 1, s.start + s.count do
            local p = places[k]
            if p and type(p.positionNo) == "number" then
              roles[math.floor(p.positionNo) % 256] = role_of(type(p.positionId) == "number" and p.positionId or 0)
            end
          end
          return roles
        end
      end
      return false
    end)
    if not ok then warn(string.format("formation 0x%08X: roles not read (%s)", id, tostring(out))) end
    roles_cache[id] = ok and out or false
  end
  return roles_cache[id] or nil
end

-- a handle's main position (chara_param), level and card; 0, 0, 0 when unknown
local function player_info(h)
  local ok, r = pcall(VRFW.chara.record, h)
  if not ok or type(r) ~= "table" then return 0, 0, 0 end
  local card = math.floor(tonumber(r.param) or 0) % 4294967296
  local okc, c = pcall(VRFW.chara.card, card)
  local pos = okc and type(c) == "table" and tonumber(c.position) or 0
  return math.floor(pos) % 256, tonumber(r.level) or 0, card
end

-- the member entries of team t: [k] = { k, h, pos, at }
local function entries(addr, t)
  local v = {}
  for k = 0, MEMBERS - 1 do
    local at = addr + member_off(t, k)
    v[k] = { k = k, h = rd("u32", at) or 0, pos = rd("u8", at + MEMBER_POSITION) or 255, at = at }
  end
  return v
end

local function is_mirrored(f, b, l)
  for _, x in ipairs(f.mirrored[bank_key(b)] or {}) do
    if x == l then return true end
  end
  return false
end

local function mark_mirrored(f, b, l)
  if b >= MAX_BANKS or not is_dock(l) or is_mirrored(f, b, l) then return false end
  local v = f.mirrored[bank_key(b)] or {}
  v[#v + 1] = l
  table.sort(v)
  f.mirrored[bank_key(b)] = v
  return true
end

local function cards_text(list)
  local out = {}
  for _, h in ipairs(list) do
    local _, _, card = player_info(h)
    out[#out + 1] = string.format("0x%08X", card)
  end
  return table.concat(out, " ")
end

-- ---------------------------------------------------------------------------------------- commands

-- CMND_EVT_PACHANGA_INFO -> ok, active dock (-1 none), 5v5 members of it, bank (1-based), slot
function Pachangas.Info()
  if not ready() then return false end
  local s, b = slot(), bank()
  local active = active_dock(with_pt(s))
  local members = 0
  local addr = active and set_addr(active)
  if addr then members = #team_handles(addr, 1) end
  return true, active or -1, members, b + 1, s
end

-- CMND_EVT_PACHANGA_SET(dock) -> ok, code: the active pachanga team is the active match team's pair, so only that dock
-- is accepted (nothing is stored); the dock's «Set as active team» sets the match team (retail) instead
function Pachangas.Set(set)
  set = int(set, -1)
  if not ready() then return false, C.NOT_READY end
  if is_story() then return false, C.STORY end
  if not is_dock(set) then
    warn("PACHANGA_SET " .. set .. " refused, code " .. C.BAD_ARGS)
    return false, C.BAD_ARGS
  end
  local active = active_dock(with_pt(slot()))
  if active ~= set then
    warn(string.format("PACHANGA_SET dock %02d refused, code %d: the active pachanga team follows the active match team (%s)",
      dock_no(set), C.PAIRED, active and string.format("dock %02d", dock_no(active)) or "none"))
    return false, C.PAIRED
  end
  return true, C.OK
end

-- CMND_EVT_PACHANGA_TEAM -> ok, dock, formation dword (teamInfo[1]+0x250), team name, n, handles (slot order). ok = a
-- dock is chosen and its 5v5 team has players (the Lua still checks the retail validity)
function Pachangas.Team()
  if not ready() then return false, -1 end
  local set = active_dock(with_pt(slot()))
  if not set then return false, -1 end
  local addr = set_addr(set)
  if not addr then return false, set end
  local hs = team_handles(addr, 1)
  local team = addr + TEAM_SIZE
  local bytes = {}
  for i = 0, NAME_LEN - 1 do
    local c = rd("u8", team + i) or 0
    if c == 0 then break end
    bytes[#bytes + 1] = string.char(c)
  end
  local out = { #hs > 0, set, rd("u32", team + TEAM_FIELDS_FROM) or 0, table.concat(bytes), #hs }
  for _, h in ipairs(hs) do out[#out + 1] = h end
  return table.unpack(out)
end

-- CMND_FANTASY_PACHANGA_CAPTAIN -> ok, captain card, captain handle: the active 5v5 team's captain fields
-- (TeamInfo +0x2A0 captainParamId / +0x2A4 captainStHdl, docs/game/ui/pachanga-templates.md §9.1; 0 = none named).
-- ok = a dock is chosen. The pachanga join scene (docs/game/modes/pachanga-join-scene.md) puts this captain on stage.
function Pachangas.Captain()
  if not ready() then return false, 0, 0 end
  local set = active_dock(with_pt(slot()))
  if not set then return false, 0, 0 end
  local addr = set_addr(set)
  if not addr then return false, 0, 0 end
  local team = addr + TEAM_SIZE
  return true, rd("u32", team + CAPTAIN_PARAM) or 0, rd("u32", team + CAPTAIN_HDL) or 0
end

-- CMND_FANTASY_PACHANGA_NOTE(op, text) -> the note: a short text handed from one menu VM to another (this host is
-- shared by all of them). "set" keeps `text`, anything else only reads it. The pachanga join scene hands the joiner's
-- name to the hosted Sí / No question of setting_top_menu (fwp_rpg.lua -> fwp_setting.lua).
local note = ""
function Pachangas.Note(op, text)
  if op == "set" then note = tostring(text or "") end
  return note
end

-- CMND_EVT_PACHANGA_VS(op, vs): 1 = remember vs (a pending value is kept), 0 = take it (returns it and forgets it),
-- 2 = peek -> ok, vs (-1 none)
function Pachangas.Vs(op, v)
  op, v = int(op, -1), int(v, -1)
  if not ready() then return false, -1 end
  local s = slot()
  local f = with_pt(s)
  local x
  if op == 1 then
    if v < 0 or v >= 16 then
      warn("PACHANGA_VS op " .. op .. " value " .. v .. " refused, code " .. C.BAD_ARGS)
      return false, -1
    end
    if f.vs_restore == nil then
      f.vs_restore = v
      pt_write(f)
      x = v
    else
      x = f.vs_restore
    end
  elseif op == 0 then
    x = f.vs_restore or -1
    if f.vs_restore ~= nil then
      f.vs_restore = nil
      pt_write(f)
    end
  elseif op == 2 then
    x = f.vs_restore or -1
  else
    warn("PACHANGA_VS op " .. op .. " value " .. v .. " refused, code " .. C.BAD_ARGS)
    return false, -1
  end
  if op ~= 2 and x >= 0 then info("slot " .. s .. ": trial VS restore " .. (op == 1 and "remembered" or "taken") .. " " .. x) end
  return op ~= 0 or x >= 0, x
end

-- CMND_EVT_PACHANGA_FLAGS -> dock bits put back on the 11v11 / 5v5 members that lost them (retail SetTeamMember clears
-- the set's bit of the member it replaces in ANY team of the set)
function Pachangas.Flags()
  if not ready() then return -1 end
  -- every missing bit first (as the docks are now), then put back
  local miss = {}
  for l = FIRST_DOCK, LAST_DOCK do
    local addr = set_addr(l)
    if not addr then return -1 end
    for t = 0, 1 do
      for k = 0, MEMBERS - 1 do
        local h = member_handle(addr, t, k)
        if h ~= 0 then
          local f = team_flag(h)
          if f and band(f, lshift(1, l)) == 0 then miss[#miss + 1] = { addr + member_off(t, k), l } end
        end
      end
    end
  end
  local fixed = 0
  for _, m in ipairs(miss) do
    if set_bit(m[1], m[2], true) then fixed = fixed + 1 end
  end
  if fixed > 0 then info(fixed .. " dock bit(s) put back on 11v11 / 5v5 members") end
  return fixed
end

-- CMND_PACHANGAS_MIRROR(dock, 5v5 formation) -> changes, removed, added. The 5v5 team (team 1) of a user dock holds
-- exactly the players of its 11v11 team (team 0, positions 0..15); coach and managers are the dock graft's (PT.link).
-- * a 5v5 player who is not in the 11v11 team leaves it (his dock bit goes when he is in no team of the dock);
-- * an 11v11 player missing from the 5v5 team joins it (his team-0 entry copied, a free position);
-- * an empty starter position (0..4) takes the best fitting player of the pool: the formation's role of that position
--   first (main position), then an 11v11 starter, then the higher level, then the 11v11 position order; the rest of
--   the pool sits on the bench (positions 5..15);
-- * the first time per bank page and dock (old saves, new templates): a five with a player outside the 11v11 team is
--   refilled whole, else kept; one log line per dock changed.
function Pachangas.Mirror(set, formation)
  set = int(set, -1)
  formation = int(formation, 0) % 4294967296
  if not ready() or not is_dock(set) or is_story() or is_rogue() then return -1, 0, 0 end
  local addr = set_addr(set)
  if not addr then return -1, 0, 0 end
  local s, b = slot(), bank()
  local f = with_pt(s)
  local first = not is_mirrored(f, b, set)
  local a, e = entries(addr, 0), entries(addr, 1)
  local pool, in_a, order = {}, {}, {}
  for k = 0, MEMBERS - 1 do
    local x = a[k]
    if x.h ~= 0 then
      in_a[x.h] = true
      if x.pos < PLAYER_POSITIONS and not pool[x.h] then
        pool[x.h] = x
        order[#order + 1] = x
      end
    end
  end
  table.sort(order, function(p, q) return p.pos < q.pos end)
  local refill = false
  if first then
    for k = 0, MEMBERS - 1 do
      local x = e[k]
      if x.h ~= 0 and x.pos < STARTERS and not pool[x.h] then refill = true end
    end
  end
  -- players outside the pool leave (the dock bit first, while the entry still names him)
  local removed, added, moved = {}, {}, 0
  for k = 0, MEMBERS - 1 do
    local x = e[k]
    if x.h ~= 0 and x.pos < PLAYER_POSITIONS and not pool[x.h] then
      if not in_a[x.h] then set_bit(x.at, set, false) end
      removed[#removed + 1] = x.h
      clear_member(addr, 1, k)
      x.h = 0
    end
  end
  local in_b, taken = {}, {}
  for k = 0, MEMBERS - 1 do
    local x = e[k]
    if x.h ~= 0 then
      in_b[x.h] = true
      if x.pos < PLAYER_POSITIONS and taken[x.pos] == nil then taken[x.pos] = x end
    end
  end
  -- the players that need a position: the old five when it is refilled, then the pool players missing
  local need = {}
  if refill then
    for p = 0, STARTERS - 1 do
      if taken[p] then
        need[#need + 1] = { h = taken[p].h, entry = taken[p], src = pool[taken[p].h] }
        taken[p] = nil
      end
    end
  end
  for _, x in ipairs(order) do
    if not in_b[x.h] then need[#need + 1] = { h = x.h, src = x } end
  end
  local free = {}
  for k = 0, MEMBERS - 1 do
    if e[k].h == 0 then free[#free + 1] = e[k] end
  end
  -- candidate c takes position p: an entry of the 5v5 team moves, a missing player gets a free entry
  local function place(c, p)
    if c.entry then
      wr("u8", c.entry.at + MEMBER_POSITION, p)
      c.entry.pos = p
      taken[p] = c.entry
      moved = moved + 1
      return true
    end
    local x = table.remove(free, 1)
    if not x then return false end
    for o = 0, MEMBER_STRIDE - 4, 4 do wr("u32", x.at + o, rd("u32", c.src.at + o) or 0) end
    wr("u8", x.at + MEMBER_POSITION, p)
    x.h, x.pos = c.h, p
    taken[p] = x
    added[#added + 1] = c.h
    return true
  end
  local roles = formation ~= 0 and formation_roles(formation) or nil
  local facts = {}
  local function fact(h)
    if not facts[h] then
      local pos, lv = player_info(h)
      facts[h] = { pos = pos, lv = lv }
    end
    return facts[h]
  end
  -- empty starter positions: candidates = the players needing a position + the bench
  for p = 0, STARTERS - 1 do
    if taken[p] == nil then
      local cands = {}
      for _, c in ipairs(need) do
        if not c.done then cands[#cands + 1] = c end
      end
      for q = STARTERS, PLAYER_POSITIONS - 1 do
        local x = taken[q]
        if x and pool[x.h] then cands[#cands + 1] = { h = x.h, entry = x, src = pool[x.h], bench = q } end
      end
      local want = (roles and roles[p]) or (p == 0 and GOALKEEPER or nil)
      local best, key = nil, nil
      for _, c in ipairs(cands) do
        local i = fact(c.h)
        local k = {
          (want and i.pos == want) and 1 or 0,
          (c.src and c.src.pos < MATCH_STARTERS) and 1 or 0,
          i.lv,
          -(c.src and c.src.pos or PLAYER_POSITIONS),
        }
        local better = best == nil
        if not better then
          for j = 1, #k do
            if k[j] ~= key[j] then
              better = k[j] > key[j]
              break
            end
          end
        end
        if better then best, key = c, k end
      end
      if best then
        if best.bench then taken[best.bench] = nil end
        if place(best, p) then best.done = true end
      end
    end
  end
  -- the rest of the pool on the bench, in 11v11 order
  for _, c in ipairs(need) do
    if not c.done then
      local p = nil
      for q = STARTERS, PLAYER_POSITIONS - 1 do
        if taken[q] == nil then
          p = q
          break
        end
      end
      if p == nil or not place(c, p) then
        warn(string.format("dock %02d: no free 5v5 place for card 0x%08X", dock_no(set), select(3, player_info(c.h))))
      end
      c.done = true
    end
  end
  local changes = #removed + #added + moved
  if changes > 0 then
    recount(addr, 1)
    recount_team_info(addr + TEAM_SIZE)
  end
  if first and mark_mirrored(f, b, set) then pt_write(f) end
  if changes > 0 then
    info(string.format("slot %d bank %d dock %02d: 5v5 team %s: removed %d [%s], added %d [%s], starters placed %d",
      s, b + 1, dock_no(set), first and (refill and "migrated (old five refilled)" or "migrated (five kept)")
        or "follows the 11v11 team", #removed, cards_text(removed), #added, cards_text(added), moved))
  end
  return changes, #removed, #added
end

-- ---------------------------------------------------------------------------------------- team bonuses of a Pachanga team

-- the dock whose 11v11 / 5v5 member lists are swapped while the team bonuses screen is open
local swapped = nil

-- swap the member lists (29 x 0x10 bytes) of team 0 and team 1 of a set, then the counters; the team fields stay
local function swap_apply(l)
  local addr = set_addr(l)
  if not addr then return false end
  local a, b = addr + MEMBER_LIST, addr + TEAM_SIZE + MEMBER_LIST
  local xs, ys = {}, {}
  for o = 0, MEMBERS * MEMBER_STRIDE - 4, 4 do
    xs[o], ys[o] = rd("u32", a + o), rd("u32", b + o)
    if not xs[o] or not ys[o] then
      VRFW.error(string.format("pachanga: pachanga team swap: dock %02d not written", dock_no(l)))
      return false
    end
  end
  for o = 0, MEMBERS * MEMBER_STRIDE - 4, 4 do
    wr("u32", a + o, ys[o])
    wr("u32", b + o, xs[o])
  end
  recount(addr, 0)
  recount(addr, 1)
  recount_team_info(addr)
  recount_team_info(addr + TEAM_SIZE)
  return true
end

-- a swap still pending (screen closed abnormally, a return to the title) is undone
local function swap_restore(why)
  local l = swapped
  swapped = nil
  if not l then return end
  local ok = swap_apply(l)
  info(string.format("pachanga team swap: dock %02d swapped back (%s) ok=%s", dock_no(l), why, tostring(ok)))
end

-- CMND_EVT_PACHANGA_TEAMSWAP(dock, on) -> ok, swapped dock. on = 1: swap the 11v11 and 5v5 member lists of a user dock
-- (the team bonuses screen computes its passive lists from team 0 whatever team kind it is given); on = 0: undo it
function Pachangas.TeamSwap(set, on)
  set, on = int(set, -1), int(on, 0) ~= 0
  if not ready() then return false, -1 end
  swap_restore(on and "new swap" or "screen closed")
  if not on then return true, -1 end
  if not is_dock(set) or is_story() then return false, -1 end
  local ok = swap_apply(set)
  if ok then swapped = set end
  info(string.format("pachanga team swap: dock %02d (logical %d) 5v5 players in team 0 ok=%s", dock_no(set), set, tostring(ok)))
  return ok, ok and set or -1
end

-- retail CMND_GAME_RESET (observed, never answered): the pending swap is undone before the title
function Pachangas.OnGameReset()
  if ready() then swap_restore("game reset") end
  return false
end

-- ---------------------------------------------------------------------------------------- one team per place / move

-- Retail keeps the two teams of a dock linked: the place / move command 193693077(toSet, pos, fromSet, hdl, team)
-- (0xC35A80) removes a player from ALL teams of the set he leaves (0xD9EDF0) and AddMemberToSet 0xD9F1C0 also adds a
-- player added to team 0 to team 1. From dock 02 on (logical sets 3..12) that side effect is undone around every call
-- (filters PachangaSplitPre / PachangaSplitPost): the team the call is NOT about is put back as it was, and the dock
-- graft's CMND_PACHANGAS_MIRROR then brings the 5v5 team to the 11v11 team's players (positions it chooses). Dock 01 (set 2)
-- keeps the retail link (the story's behaviour, same players); only calls about team 0 or 1 (team 2, the RPG party,
-- stays retail); never in the story nor in the INAROGUE save (its teams stay linked, docs/game/modes/inarogue.md §20).

local TEAM_WORDS = TEAM_SIZE / 4
local split_pending = nil

-- { { logical set, other team }… } of the independent docks a call touches (toSet / fromSet; 16 = the bank)
local function split_plan(to_set, from_set, team)
  local v = {}
  if team ~= 0 and team ~= 1 then return v end
  for _, s in ipairs({ to_set, from_set }) do
    local seen = false
    for _, x in ipairs(v) do
      if x[1] == s then seen = true end
    end
    if is_independent(s) and not seen then v[#v + 1] = { s, 1 - team } end
  end
  return v
end

local function read_team(addr)
  local w = {}
  for i = 0, TEAM_WORDS - 1 do
    local x = rd("u32", addr + i * 4)
    if x == nil then return nil end
    w[i + 1] = x
  end
  return w
end

-- before the place / move: the team of each independent dock the call is NOT about (never answers)
function Pachangas.SplitPre(to_set, pos, from_set, hdl, team)
  split_pending = nil
  if not ready() or is_story() or is_rogue() then return false end
  local plan = split_plan(int(to_set, -1), int(from_set, -1), int(team, 0))
  if #plan == 0 then return false end
  local saved = {}
  for _, p in ipairs(plan) do
    local addr = set_addr(p[1])
    local w = addr and read_team(addr + p[2] * TEAM_SIZE)
    if w then saved[#saved + 1] = { set = p[1], team = p[2], words = w } end
  end
  split_pending = saved
  return false
end

-- after it: the saved teams back, recounted, and their members' dock bit put back (retail cleared it when the player
-- left the other team of the dock); the command's results are not changed
function Pachangas.SplitPost(args, results)
  local saved = split_pending
  split_pending = nil
  if not saved or #saved == 0 or not ready() then return nil end
  for _, s in ipairs(saved) do
    local addr = set_addr(s.set)
    local taddr = addr and addr + s.team * TEAM_SIZE
    local now = taddr and read_team(taddr)
    local same = now ~= nil
    if now then
      for i = 1, TEAM_WORDS do
        if now[i] ~= s.words[i] then same = false end
      end
    end
    if now and not same then
      local ok = true
      for i = 1, TEAM_WORDS do
        if now[i] ~= s.words[i] and not wr("u32", taddr + (i - 1) * 4, s.words[i]) then ok = false end
      end
      if not ok then
        warn(string.format("pachanga split: dock %02d team %d not restored", dock_no(s.set), s.team))
      else
        recount_team_info(taddr)
        local bits = 0
        for k = 0, MEMBERS - 1 do
          local h = s.words[(MEMBER_LIST + k * MEMBER_STRIDE) / 4 + 1] or 0
          local f = h ~= 0 and team_flag(h) or nil
          if f ~= nil and band(f, lshift(1, s.set)) == 0 and set_bit(addr + member_off(s.team, k), s.set, true) then
            bits = bits + 1
          end
        end
        info(string.format("pachanga split: dock %02d (logical %d) team %d kept as it was (%d dock bit(s) put back)",
          dock_no(s.set), s.set, s.team, bits))
      end
    end
  end
  return nil
end

if ENABLED then
  info("active (5v5 templates of the team dock; the active pachanga team is the active match team's pair)")
end
