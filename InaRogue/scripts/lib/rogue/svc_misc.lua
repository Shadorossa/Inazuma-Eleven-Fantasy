-- InaRogue › INAROGUE: the INAROGUE save's owned-player lists, the retail achievements switched off in it and the
-- debug probes (was party_rt.rs, achieve.rs and probe_rt.rs of the DLL's module rogue).
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_EVT_RL_PARTY_COUNT | bank (0 charaBank, 1 rpgCharaBank) | n (non-zero handles; -1 not resolved / not the INAROGUE save) |
-- | CMND_EVT_RL_PARTY_HDL | bank, i | hdl (0 = none) |
-- | CMND_EVT_RL_PROBE_INFO | – | slot, replaced, source, n0, n1, n2 |
-- | CMND_EVT_RL_PROBE_COUNT | set (logical 0-15) | code, n0, n1, n2 |
-- | CMND_EVT_RL_PROBE_SET13 / _RESTORE13 | source set / – | code, n0, n1 |
-- | CMND_EVT_RL_PROBE_KV | op (0 get, 1 set, 2 delete, 3 clear), key, value | ok, value |
--
-- Both party commands refuse to answer outside the INAROGUE save (rule #1: no normal save is read). Layout
-- (roguelite-mode.md §3.1): party = [[g_gameRoot] + 0x69A8]; charaBank at party + 0x9F70 = u32 num + 5302 handles,
-- rpgCharaBank at party + 0xF24C = u32 + 700. The probes run only with [rogue] debug_tools and never on save slot 1;
-- their state is blob rogue_probe.json of the slot (the DLL's JSON). The «Sin rol» commands (CMND_EVT_RL_NO_ROLE,
-- _NO_ROLE_ALL, _ROLE_CARRY) stay in the plugin: they use the board module's role setter.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local Core = require "lib/rogue/core"
local info, warn, err = U.logger("rogue")

local S = {}

local band, rshift = bit32.band, bit32.rshift

-- ---------------------------------------------------------------------------------------- the owned-player lists

local BANKS = { [0] = { 0x9F70, 5302 }, [1] = { 0xF24C, 700 } }

local function handles(bank)
  local b = BANKS[bank]
  local party = U.global("rl_party")
  if not b or not party then return nil end
  local base = party + b[1] + 4
  local out = {}
  -- u32 reads (a u64 read comes back as a Lua number: exact only up to 2^53)
  for k = 0, b[2] - 1 do
    local h = U.rd("u32", base + k * 4)
    if h == nil then return nil end
    if h ~= 0 and band(h, 0x800) ~= 0 and rshift(h, 16) < 6000 then out[#out + 1] = h end
  end
  return out
end

function S.PartyCount(bank_arg)
  if not U.rogue_active() then
    warn("party: CMND_EVT_RL_PARTY_COUNT refused outside the INAROGUE save")
    return -1
  end
  local bank = U.int(bank_arg, 0)
  local v = handles(bank)
  if not v then return -1 end
  info(string.format("party: bank %d: %d owned handles", bank, #v))
  return #v
end

function S.PartyHdl(bank_arg, i_arg)
  if not U.rogue_active() then return 0 end
  local v = handles(U.int(bank_arg, 0))
  local i = U.int(i_arg, -1)
  if not v or i < 0 then return 0 end
  return v[i + 1] or 0
end

-- ---------------------------------------------------------------------------------------- «Sin rol»
-- [rogue] grant_without_role: every player INAROGUE grants arrives with no coach / manager role. CMND_ADD_PARTY gives
-- some characters a creation-time staff role (attribute bits 0x30 + an auto-equipped badge): NO_ROLE removes exactly
-- that (SET_ROLE 0 without the match requirement, scripts\board_role.lua). A role the user chose (SET_ROLE 1/2 clears
-- the creation bits) is never touched. Only records tagged 0x10000000 (attribute rec8+0x20), only in the INAROGUE save.
-- Role carry (rebirth at run start): the old character's user-chosen role is given to the new one. Was the plugin's
-- rogue::party_rt until 2026-10-11.
--
--   CMND_EVT_RL_NO_ROLE(hdl)              -> 1 cleared, 0 nothing to clear, -1 rule off / not slot 4 / not an INAROGUE
--                                            player, < -1 SET_ROLE's error
--   CMND_EVT_RL_NO_ROLE_ALL()             -> players cleared (-1 rule off / not slot 4)
--   CMND_EVT_RL_ROLE_CARRY(oldHdl, newHdl) -> the role the new character has now (-1 not slot 4 / not INAROGUE players)

local ATTR_ROGUE_TAG = 0x10000000

local function role_api()
  local F = rawget(_G, "Fantasy")
  local R = F and rawget(F, "BoardRole")
  if R and R.state_of and R.set_role_free then return R end
  return nil
end

local function no_role_rule() return U.cfg("rogue.grant_without_role", false) == true end

-- the creation-time staff role of an INAROGUE record is cleared (not a badge the user chose)
function S.clears_creation_role(attr, staff)
  return band(attr, ATTR_ROGUE_TAG) ~= 0 and band(attr, staff) ~= 0
end

-- the role a rebirth carries: the old character's user-chosen role (1 coach / 2 manager), nil for a creation role
function S.carried_role(old_role, old_attr, staff)
  if old_role >= 1 and old_role <= 2 and band(old_attr, staff) == 0 then return old_role end
  return nil
end

local function clear_one(R, hdl)
  local cur, attr = R.state_of(hdl)
  if cur == nil then return R.ST_NO_RECORD end
  if band(attr, ATTR_ROGUE_TAG) == 0 then return -1 end
  if not S.clears_creation_role(attr, R.ATTR_NATIVE_STAFF) then return 0 end
  local st, after = R.set_role_free(hdl, 0)
  if st == R.ST_OK then
    info(string.format("party: 0x%08X granted «Sin rol» (creation role %d, attribute 0x%X)", hdl, cur, attr))
    return 1
  end
  warn(string.format("party: 0x%08X «Sin rol» failed: status %d, role now %d", hdl, st, after))
  if st < -1 then return st end
  return -2
end

function S.NoRole(hdl_arg)
  local R = role_api()
  if not R or not no_role_rule() or not U.rogue_active() then return -1 end
  return clear_one(R, U.u32(hdl_arg, 0))
end

function S.NoRoleAll()
  local R = role_api()
  if not R or not no_role_rule() or not U.rogue_active() then return -1 end
  local seen, cleared = 0, 0
  for bank = 0, 1 do
    for _, h in ipairs(handles(bank) or {}) do
      local r = clear_one(R, h)
      if r == 1 then
        cleared = cleared + 1
        seen = seen + 1
      elseif r == 0 then
        seen = seen + 1
      end
    end
  end
  info(string.format("party: NO_ROLE_ALL: %d of %d INAROGUE players had a creation role, now «Sin rol»", cleared, seen))
  return cleared
end

function S.RoleCarry(old_arg, new_arg)
  local R = role_api()
  if not R or not U.rogue_active() then return -1 end
  local old, new = U.u32(old_arg, 0), U.u32(new_arg, 0)
  local old_role, old_attr = R.state_of(old)
  local new_role, new_attr = R.state_of(new)
  if old_role == nil or new_role == nil then return -1 end
  if band(old_attr, ATTR_ROGUE_TAG) == 0 or band(new_attr, ATTR_ROGUE_TAG) == 0 then return -1 end
  if no_role_rule() then clear_one(R, new) end
  local r = S.carried_role(old_role, old_attr, R.ATTR_NATIVE_STAFF)
  if r then
    local st, after = R.set_role_free(new, r)
    info(string.format("party: role %d carried 0x%08X -> 0x%08X: status %d, role now %d", r, old, new, st, after))
  end
  local now = R.state_of(new)
  return now or -1
end

-- ---------------------------------------------------------------------------------------- retail achievements

-- SetTrophyTier(const u32* trophyId, u32 tier, bool notify): nothing is set, shown or sent while the INAROGUE save is the
-- loaded game (docs/game/modes/inarogue.md §21)
local dropped = 0
function S.on_trophy(ev)
  if not U.rogue_active() then return nil end
  dropped = dropped + 1
  if dropped <= 20 then
    local a = ev.args or {}
    local id = U.rd("u32", a[1]) or 0
    info(string.format("retail achievement %s tier %d (notify %d) DROPPED in the INAROGUE save (%d so far)", U.hex(id),
      U.int(a[2], 0), U.int(a[3], 0), dropped))
  end
  return { skip = true }
end

-- ---------------------------------------------------------------------------------------- probes (§10)

local P = { OK = 0, BAD_ARGS = 1, SLOT1 = 2, NOT_READY = 3, EXCEPTION = 4, ALREADY = 5, NOTHING = 6, WRITE_FAILED = 7, DISABLED = 8 }
local BLOB, VERSION = "rogue_probe.json", 1
local TEAM_SIZE, TEAMS, MEMBERS, MEMBER_LIST, MEMBER_STRIDE, ROGUE_SET = 0x2D0, 3, 29, 0x80, 0x10, 13

local function debug_on() return Core.cfg().debug_tools end

local function load_state()
  local slot = U.slot()
  local text, why = U.blob_read(BLOB, slot)
  if text == false then return nil, why end
  local s = { slot = slot, backup = nil, source = nil, kv = {} }
  if not text then return s end
  local j, e = U.json(text)
  if not j then return nil, e end
  if j.version ~= VERSION then return nil, "unknown version " .. tostring(j.version) end
  s.backup = type(U.val(j.set13_backup)) == "string" and j.set13_backup or nil
  s.source = type(U.val(j.set13_source)) == "number" and j.set13_source or nil
  if type(U.val(j.kv)) == "table" then
    for k, v in pairs(j.kv) do
      if type(v) == "number" then s.kv[tostring(k)] = v end
    end
  end
  return s
end

local function save_state(s)
  if s.backup == nil and next(s.kv) == nil then
    local note = U.blob_aside(BLOB, s.slot)
    return not (type(note) == "string" and note:find("^could not"))
  end
  local kv = {}
  for _, k in ipairs(J.sorted_keys(s.kv)) do kv[#kv + 1] = { k, s.kv[k] } end
  local text = J.pretty(J.obj({ { "version", VERSION }, { "slot", s.slot }, { "set13_backup", s.backup },
    { "set13_source", s.source }, { "kv", J.obj(kv) } }))
  return (U.blob_write(BLOB, text, s.slot))
end

local function team_ptr(set, team)
  local party = U.global("rl_party")
  if not party then return nil end
  local ok, t = pcall(VRFW.call, "RL_GetTeamInfo", party, set, team)
  if ok and type(t) == "number" and t >= 0x10000 then return t end
  return nil
end

local function read_team(t)
  local words = {}
  for k = 0, TEAM_SIZE / 4 - 1 do
    local v = U.rd("u32", t + k * 4)
    if v == nil then return nil end
    words[#words + 1] = v
  end
  return words
end

local function words_hex(words)
  local o = {}
  for _, w in ipairs(words) do
    for b = 0, 3 do o[#o + 1] = string.format("%02x", band(rshift(w, b * 8), 0xFF)) end
  end
  return table.concat(o)
end

local function members(t)
  local n = 0
  for k = 0, MEMBERS - 1 do
    local h = U.rd("u32", t + MEMBER_LIST + k * MEMBER_STRIDE)
    if h and h ~= 0 then n = n + 1 end
  end
  return n
end

local function counts(set)
  local n = {}
  for t = 0, TEAMS - 1 do
    local p = team_ptr(set, t)
    if not p then return nil end
    n[t + 1] = members(p)
  end
  return n
end

local function set_bits(team0, on)
  for k = 0, MEMBERS - 1 do
    local ok = pcall(VRFW.call, "RL_SetOrganizedFlagBit", team0 + MEMBER_LIST + k * MEMBER_STRIDE, ROGUE_SET, on)
    if not ok then return false end
  end
  return true
end

local function api_ready()
  return VRFW.is_on("RL_GetTeamInfo") and VRFW.is_on("RL_SetOrganizedFlagBit") and VRFW.is_on("RL_TeamInfoAssign")
    and U.global("rl_party") ~= nil
end

function S.ProbeInfo()
  if not debug_on() then return P.DISABLED end
  local st = load_state() or { backup = nil, source = nil }
  local n = (api_ready() and counts(ROGUE_SET)) or { 0, 0, 0 }
  return U.slot(), st.backup ~= nil, st.source or -1, n[1], n[2], n[3]
end

function S.ProbeCount(set_arg)
  if not debug_on() then return P.DISABLED end
  local set = U.int(set_arg, -1)
  if not api_ready() then return P.NOT_READY end
  if set < 0 or set >= 16 then return P.BAD_ARGS end
  local n = counts(set)
  if not n then return P.NOT_READY end
  info(string.format("probe: set %d members [%d, %d, %d]", set, n[1], n[2], n[3]))
  return P.OK, n[1], n[2], n[3]
end

function S.ProbeSet13(src_arg)
  if not debug_on() then return P.DISABLED, 0, 0 end
  if U.slot() < 2 then
    warn("probe: refused on save slot 1 (vanilla save)")
    return P.SLOT1, 0, 0
  end
  local src = U.int(src_arg, -1)
  if not api_ready() then return P.NOT_READY end
  if src < 2 or src > 12 then return P.BAD_ARGS end
  local st, why = load_state()
  if not st then
    err("probe: " .. tostring(why))
    return P.WRITE_FAILED
  end
  if st.backup then
    warn("probe: set 13 is already replaced (restore it first)")
    return P.ALREADY
  end
  local dst, srcp = {}, {}
  for t = 0, TEAMS - 1 do
    dst[t + 1] = team_ptr(ROGUE_SET, t)
    srcp[t + 1] = team_ptr(src, t)
    if not dst[t + 1] or not srcp[t + 1] then return P.NOT_READY, 0, 0 end
  end
  if dst[1] == srcp[1] then return P.BAD_ARGS, 0, 0 end
  local hex = {}
  for t = 1, TEAMS do
    local w = read_team(dst[t])
    if not w then return P.NOT_READY, 0, 0 end
    hex[t] = words_hex(w)
  end
  -- persist the original first: a crash after this point can always be undone
  st.backup = table.concat(hex)
  st.source = src
  if not save_state(st) then
    err("probe: cannot write the set-13 backup")
    return P.WRITE_FAILED, 0, 0
  end
  if not set_bits(dst[1], false) then return P.EXCEPTION, 0, 0 end
  for t = 1, TEAMS do
    if not pcall(VRFW.call, "RL_TeamInfoAssign", dst[t], srcp[t]) then
      err("probe: exception in TeamInfo copy " .. (t - 1))
      return P.EXCEPTION, 0, 0
    end
  end
  if not set_bits(dst[1], true) then return P.EXCEPTION, 0, 0 end
  local n = counts(ROGUE_SET)
  if not n then return P.NOT_READY, 0, 0 end
  info(string.format("probe: SET13 from set %d: set 13 now has members [%d, %d, %d]", src, n[1], n[2], n[3]))
  return P.OK, n[1], n[2]
end

function S.ProbeRestore13()
  if not debug_on() then return P.DISABLED, 0, 0 end
  if U.slot() < 2 then
    warn("probe: refused on save slot 1 (vanilla save)")
    return P.SLOT1, 0, 0
  end
  if not api_ready() then return P.NOT_READY end
  local st, why = load_state()
  if not st then
    err("probe: " .. tostring(why))
    return P.WRITE_FAILED
  end
  local hex = st.backup
  if not hex or #hex ~= TEAMS * TEAM_SIZE * 2 or hex:find("[^0-9a-fA-F]") then
    info("probe: RESTORE13: nothing to restore")
    return P.NOTHING, 0, 0
  end
  local okb, buf = pcall(VRFW.mem.buffer, "InaRogue.Mode.ProbeTeam", TEAM_SIZE)
  if not okb or type(buf) ~= "number" then return P.NOT_READY, 0, 0 end
  local dst = {}
  for t = 0, TEAMS - 1 do
    dst[t + 1] = team_ptr(ROGUE_SET, t)
    if not dst[t + 1] then return P.NOT_READY, 0, 0 end
  end
  if not set_bits(dst[1], false) then return P.EXCEPTION, 0, 0 end
  for t = 0, TEAMS - 1 do
    for b = 0, TEAM_SIZE - 1 do
      local at = (t * TEAM_SIZE + b) * 2 + 1
      U.wr("u8", buf + b, tonumber(hex:sub(at, at + 1), 16))
    end
    if not pcall(VRFW.call, "RL_TeamInfoAssign", dst[t + 1], buf) then
      err("probe: exception restoring team " .. t)
      return P.EXCEPTION, 0, 0
    end
  end
  if not set_bits(dst[1], true) then return P.EXCEPTION, 0, 0 end
  local n = counts(ROGUE_SET)
  if not n then return P.NOT_READY, 0, 0 end
  st.backup, st.source = nil, nil
  local saved = save_state(st)
  info(string.format("probe: RESTORE13 done: set 13 members [%d, %d, %d] (backup file %s)", n[1], n[2], n[3],
    saved and "cleared" or "NOT cleared"))
  return P.OK, n[1], n[2]
end

function S.ProbeKv(op_arg, key_arg, v_arg)
  if not debug_on() then return false, 0 end
  local op = U.int(op_arg, -1)
  local key = type(key_arg) == "string" and key_arg or ""
  local st, why = load_state()
  if not st then
    err("probe: " .. tostring(why))
    return false, 0
  end
  if op == 0 then
    local v = st.kv[key]
    if v == nil then return false, 0 end
    return true, v
  end
  if op < 1 or op > 3 then return false, 0 end
  if U.slot() < 2 then
    warn("probe: KV write refused on save slot 1")
    return false, 0
  end
  local v = U.int(v_arg, 0)
  if op == 1 then st.kv[key] = v elseif op == 2 then st.kv[key] = nil else st.kv = {} end
  local ok = save_state(st)
  info(string.format("probe: kv %s %q = %.0f -> %s", ({ "set", "delete", "clear" })[op], key, v, ok and "saved" or "WRITE FAILED"))
  return ok, v
end

return S
