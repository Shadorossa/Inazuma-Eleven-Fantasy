-- Team bank pages: the pure part (no game access). Page state, the sidecar format, team-set word helpers, the swap
-- fence and the «never lose a stored page» rules. Same format and rules as utilities.dll's module (utilities-core
-- team_banks::store, removed 2026-10-10), so the sidecars it wrote load unchanged.
--
-- Team set (0x874 bytes, stride of CGDDPartyStatus.teamSetList): 3 x TeamInfo (0x2D0) + isREStory at 0x870.
-- TeamInfo: teamName[128] @0, memberList[29] @0x80 (0x10 each: +0 character handle, +4 uniformNo / flags, +0xE
-- position class, +0xF synergy flags), team fields @0x250..0x2C8 (formation, kit, emblem, captain, tactics, aura /
-- synergy slots), counters @0x2C8..0x2CF (rebuilt by the load post-pass 0xDA7FE0).
-- The live docks are handled as an array of u32 words: dock d (0-based) word i (0-based) = w[d * WPD + i + 1].
--
-- Sidecar blob team_banks.bin per save slot (little endian):
--   0 magic "EVTTBNK\0" | 8 u32 version 1 | 12 SHA-1 (20 bytes) of the build's save family | 32 u8 slot |
--   33 u8 mounted page | 34 u8 pages (2..32) | 35 u8 docks (11) | 36 u32 set size (0x874) |
--   40 u32 fingerprint of the mounted docks when it was written | 44 u32 0 |
--   48 per page: u8 content (0 empty, 1 stored, 2 mounted), u8 active[3] (vs / esports / tournament logical set, 0xFF =
--   none), name[48] (UTF-8, 0-padded); if stored: 11 x 0x874 set bytes, then 11 x 3 x 29 x (u32 param_id, u32
--   get_order) | end: u32 crc32 of everything before.

local B = require "lib/tb_bytes"

local S = {}

local band, bor, bnot, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift

S.BANKS = 10
S.MIN_BANKS = 2
S.MAX_BANKS = 32
S.DOCKS = 11
S.FIRST_DOCK = 2
S.LAST_DOCK = 12
S.SET_SIZE = 0x874
S.TEAM_SIZE = 0x2D0
S.TEAMS = 3
S.MEMBERS = 29
S.MEMBER_LIST = 0x80
S.MEMBER_STRIDE = 0x10
S.NAME_LEN = 0x80
S.TEAM_FIELDS = { 0x250, 0x2C8 }
S.COUNTERS = 0x2C8
S.ACTIVE_OFF = 0x9F10
S.PARTY_SET_DATA = 0x17B8
S.BANK_NAME_LEN = 48
S.MAGIC = "EVTTBNK\0"
S.VERSION = 1
S.HEADER_LEN = 48
-- teams of a user dock whose members carry the dock's organizedTeamFlag bit (11v11 and 5v5 templates)
S.FLAG_TEAMS = 2
S.IDENTS = S.DOCKS * S.TEAMS * S.MEMBERS
S.IDENTS_LEN = S.IDENTS * 8
S.SETS_LEN = S.DOCKS * S.SET_SIZE
-- words of one team set / of the 3 TeamInfo the swap copies (isREStory at 0x870 stays) / of the 11 docks
S.WPD = S.SET_SIZE / 4
S.TEAM_WORDS = S.TEAMS * S.TEAM_SIZE / 4
S.WORDS = S.DOCKS * S.WPD
S.ALL = 0xFFFFFFFF

-- result codes of CMND_BETTERQOL_TEAMBANK_SET (and the other commands)
S.code = {
  OK = 0, BAD_ARGS = 1, NOT_READY = 2, STORY = 3, BUSY = 4, NOT_IN_MENU = 5, ONLINE = 6, EXCEPTION = 7, SLOT1 = 8,
  SAME = 9, MOUNTED = 10,
}

S.crc32 = function(s) return VRFW.ui.crc32(s) end

-- ------------------------------------------------------------------------------------------------ page state
-- state = { slot, mounted (0-based), banks = { [k + 1] = bank }, fingerprint, sha1 (20 bytes of the file or nil) }
-- bank = { name = "" (default name), content = "empty" | "stored" | "mounted",
--          stored only: sets (SETS_LEN bytes), idents (IDENTS_LEN bytes), active = { vs, esports, tournament } }

local function empty_bank()
  return { name = "", content = "empty" }
end

local function clamp_count(n)
  n = math.floor(tonumber(n) or S.BANKS)
  if n < S.MIN_BANKS then return S.MIN_BANKS end
  if n > S.MAX_BANKS then return S.MAX_BANKS end
  return n
end
S.clamp_count = clamp_count

-- a save without sidecar: page 1 = the save's docks, the other pages unused
function S.fresh(slot, count)
  local st = { slot = slot, mounted = 0, banks = {}, fingerprint = 0 }
  for i = 1, clamp_count(count) do
    st.banks[i] = empty_bank()
  end
  st.banks[1].content = "mounted"
  return st
end

-- adapt to the configured count: pages are added empty; pages above it are dropped only when empty and unnamed
function S.resize(st, count)
  local want = clamp_count(count)
  while #st.banks < want do
    st.banks[#st.banks + 1] = empty_bank()
  end
  while #st.banks > want do
    local last = st.banks[#st.banks]
    if last.content ~= "empty" or last.name ~= "" then break end
    st.banks[#st.banks] = nil
  end
  return #st.banks
end

-- a copy whose pages can change without touching `st` (the byte strings are shared: Lua strings never change)
function S.copy(st)
  local c = { slot = st.slot, mounted = st.mounted, banks = {}, fingerprint = st.fingerprint, sha1 = st.sha1 }
  for i, b in ipairs(st.banks) do
    local nb = { name = b.name, content = b.content, sets = b.sets, idents = b.idents }
    if b.active then nb.active = { b.active[1], b.active[2], b.active[3] } end
    c.banks[i] = nb
  end
  return c
end

function S.stored_count(st)
  local n = 0
  for _, b in ipairs(st.banks) do
    if b.content == "stored" then n = n + 1 end
  end
  return n
end

local function mask_of(st, f)
  local m = 0
  for i, b in ipairs(st.banks) do
    if f(b) then m = bor(m, lshift(1, i - 1)) end
  end
  return m
end

function S.stored_mask(st)
  return mask_of(st, function(b) return b.content == "stored" end)
end

function S.used_mask(st)
  return mask_of(st, function(b) return b.content ~= "empty" end)
end

-- exactly one page is mounted and it is `mounted`
function S.is_consistent(st)
  local n = #st.banks
  if n < S.MIN_BANKS or n > S.MAX_BANKS or st.mounted >= n then return false end
  for i, b in ipairs(st.banks) do
    if (b.content == "mounted") ~= (i - 1 == st.mounted) then return false end
  end
  return true
end

-- trimmed, no control characters, at most BANK_NAME_LEN - 1 bytes on a character boundary
function S.sanitize_name(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  local out, n = {}, 0
  for ch in s:gmatch("[\0-\127\194-\244][\128-\191]*") do
    local b1, b2 = ch:byte(1, 2)
    local control = (#ch == 1 and (b1 < 0x20 or b1 == 0x7F)) or (b1 == 0xC2 and b2 ~= nil and b2 < 0xA0)
    if not control then
      if n + #ch > S.BANK_NAME_LEN - 1 then break end
      out[#out + 1] = ch
      n = n + #ch
    end
  end
  return table.concat(out)
end

-- ------------------------------------------------------------------------------------------------ team-set words

-- byte offset of member k of team t inside a set
function S.member_off(t, k)
  return t * S.TEAM_SIZE + S.MEMBER_LIST + k * S.MEMBER_STRIDE
end

-- word index (1-based) of byte offset `off` of dock d
local function wi(d, off)
  return d * S.WPD + off / 4 + 1
end
S.wi = wi

function S.member_handle(w, d, t, k)
  return w[wi(d, S.member_off(t, k))]
end

-- empty member slot k the way the engine's SetTeamMember does (handle and the +4 dword cleared; the position fields
-- stay) and clear the team fields (captain) that still name that character; returns the handle
function S.clear_member(w, d, t, k)
  local i = wi(d, S.member_off(t, k))
  local h = w[i]
  w[i] = 0
  w[i + 1] = 0
  if h ~= 0 then
    for off = t * S.TEAM_SIZE + S.TEAM_FIELDS[1], t * S.TEAM_SIZE + S.TEAM_FIELDS[2] - 4, 4 do
      if w[wi(d, off)] == h then w[wi(d, off)] = 0 end
    end
  end
  return h
end

-- the counters of the load post-pass 0xDA7FE0 for the 3 teams of dock d: +0x2C8 members, +0x2C9..0x2CC per position
-- class of member byte +0xE (0x13 -> +0x2CA; 0x10..0x12 -> +0x2CB; 0x14..0x1C -> +0x2CC; else +0x2C9), +0x2CF = team
function S.recount(w, d)
  for t = 0, S.TEAMS - 1 do
    local c = { 0, 0, 0, 0, 0 }
    for k = 0, S.MEMBERS - 1 do
      local i = wi(d, S.member_off(t, k))
      if w[i] ~= 0 then
        c[1] = c[1] + 1
        local pos = B.byte_of(w[i + 3], 2) -- byte +0xE
        local slot
        if pos == 0x13 then
          slot = 2
        elseif band(pos - 0x10, 0xFF) <= 2 then
          slot = 3
        elseif band(pos - 0x14, 0xFF) <= 8 then
          slot = 4
        else
          slot = 1
        end
        c[slot + 1] = c[slot + 1] + 1
      end
    end
    local cw = wi(d, t * S.TEAM_SIZE + S.COUNTERS)
    w[cw] = bor(band(c[1], 0xFF), lshift(band(c[2], 0xFF), 8), lshift(band(c[3], 0xFF), 16), lshift(band(c[4], 0xFF), 24))
    -- byte +4 = c[5]; bytes +5 / +6 stay; byte +7 = team index
    w[cw + 1] = bor(band(w[cw + 1], 0x00FFFF00), band(c[5], 0xFF), lshift(t, 24))
  end
end

-- members of team 0 (the 11v11 team) of dock d
function S.team0_count(w, d)
  local n = 0
  for k = 0, S.MEMBERS - 1 do
    if S.member_handle(w, d, 0, k) ~= 0 then n = n + 1 end
  end
  return n
end

-- {team, slot, handle} of every member of the flag teams of dock d
function S.flag_members(w, d)
  local v = {}
  for t = 0, S.FLAG_TEAMS - 1 do
    for k = 0, S.MEMBERS - 1 do
      local h = S.member_handle(w, d, t, k)
      if h ~= 0 then v[#v + 1] = { t, k, h } end
    end
  end
  return v
end

function S.copy_words(w)
  local c = {}
  for i = 1, #w do c[i] = w[i] end
  return c
end

-- a never-used page: the docks `w` with every member removed (names, formations, kits, emblems, tactics kept)
function S.emptied(w)
  local v = S.copy_words(w)
  for d = 0, S.DOCKS - 1 do
    for t = 0, S.TEAMS - 1 do
      for k = 0, S.MEMBERS - 1 do
        S.clear_member(v, d, t, k)
      end
    end
    S.recount(v, d)
  end
  return v
end

-- crc32 over every team name and member handle of the docks (a consistency hint for the log, never an identity)
function S.fingerprint(w)
  local p, n = {}, 0
  for d = 0, S.DOCKS - 1 do
    for t = 0, S.TEAMS - 1 do
      local base = wi(d, t * S.TEAM_SIZE)
      n = n + 1
      p[n] = B.from_words(w, base, base + S.NAME_LEN / 4 - 1)
      for k = 0, S.MEMBERS - 1 do
        n = n + 1
        p[n] = B.le32(S.member_handle(w, d, t, k))
      end
    end
  end
  return S.crc32(table.concat(p))
end

-- identities of every member of the docks as the sidecar keeps them (IDENTS_LEN bytes); `resolve(handle)` -> param,
-- get_order (nil = no live record). Second value: members with a handle but no identity.
function S.idents_of(w, resolve)
  local p, n, missing, cache = {}, 0, 0, {}
  for d = 0, S.DOCKS - 1 do
    for t = 0, S.TEAMS - 1 do
      for k = 0, S.MEMBERS - 1 do
        local h = S.member_handle(w, d, t, k)
        local par, ord = 0, 0
        if h ~= 0 then
          local c = cache[h]
          if c == nil then
            local a, b = resolve(h)
            c = a and { a, b or 0 } or false
            cache[h] = c
          end
          if c then par, ord = c[1], c[2] else missing = missing + 1 end
        end
        n = n + 1
        p[n] = B.le32(par) .. B.le32(ord)
      end
    end
  end
  return table.concat(p), missing
end

-- validate a stored page before it is mounted: a member whose handle no longer resolves, or resolves to another
-- character (param id / get order differ, or no identity stored), is removed; counters recomputed. Returns the
-- dropped members {dock, team, slot, handle, param, order}.
function S.validate(w, idents, resolve)
  local dropped, cache = {}, {}
  for d = 0, S.DOCKS - 1 do
    for t = 0, S.TEAMS - 1 do
      for k = 0, S.MEMBERS - 1 do
        local h = S.member_handle(w, d, t, k)
        if h ~= 0 then
          local off = ((d * S.TEAMS + t) * S.MEMBERS + k) * 8
          local wp, wo = B.rd32(idents, off) or 0, B.rd32(idents, off + 4) or 0
          local ok = false
          if wp ~= 0 or wo ~= 0 then
            local c = cache[h]
            if c == nil then
              local a, b = resolve(h)
              c = a and { a, b or 0 } or false
              cache[h] = c
            end
            ok = c and c[1] == wp and c[2] == wo or false
          end
          if not ok then
            S.clear_member(w, d, t, k)
            dropped[#dropped + 1] = { dock = d, team = t, slot = k, handle = h, param = wp, order = wo }
          end
        end
      end
    end
    S.recount(w, d)
  end
  return dropped
end

-- active-set bytes after mounting a page: a byte that points into the docks (2..12) takes the page's value; bytes
-- pointing elsewhere (story / Re-Story / none) are never touched
function S.restore_active(cur, stored)
  local function dock(v) return v >= S.FIRST_DOCK and v <= S.LAST_DOCK end
  local out = { cur[1], cur[2], cur[3] }
  for i = 1, 3 do
    if dock(cur[i]) and dock(stored[i]) then out[i] = stored[i] end
  end
  return out
end

-- the swap fence: nil when a swap may run now, else the refusal code
-- f = { slot, blocked_mode (nil = unknown), job_pending (nil = unknown), in_menu, online }
function S.check_fence(f)
  if f.slot < 2 then return S.code.SLOT1 end
  if f.blocked_mode == nil then return S.code.NOT_READY end
  if f.blocked_mode then return S.code.STORY end
  if f.job_pending == nil then return S.code.NOT_READY end
  if f.job_pending then return S.code.BUSY end
  if f.online then return S.code.ONLINE end
  if not f.in_menu then return S.code.NOT_IN_MENU end
  return nil
end

-- ------------------------------------------------------------------------------------------------ sidecar

-- the sidecar bytes of `st` (`sha1` = 20 bytes, `fp` = fingerprint of the mounted docks)
function S.encode(st, sha1, fp)
  local p = {
    S.MAGIC, B.le32(S.VERSION), B.pad(sha1 or "", 20),
    string.char(st.slot, st.mounted, #st.banks, S.DOCKS), B.le32(S.SET_SIZE), B.le32(fp or 0), B.le32(0),
  }
  for _, b in ipairs(st.banks) do
    local tag, a = 0, { 0xFF, 0xFF, 0xFF }
    if b.content == "stored" then
      tag, a = 1, b.active
    elseif b.content == "mounted" then
      tag = 2
    end
    p[#p + 1] = string.char(tag, a[1], a[2], a[3])
    p[#p + 1] = B.pad(S.sanitize_name(b.name), S.BANK_NAME_LEN)
    if tag == 1 then
      p[#p + 1] = b.sets
      p[#p + 1] = b.idents
    end
  end
  local body = table.concat(p)
  return body .. B.le32(S.crc32(body))
end

-- decode a sidecar. `slot` / `sha1` given = it must be that slot's and that save family's (a file sha1 of 20 zero
-- bytes, written while the build key was unknown, passes); nil = any intact sidecar (lenient). -> state or nil, why
function S.decode(data, slot, sha1)
  if type(data) ~= "string" or #data < S.HEADER_LEN + 4 or data:sub(1, 8) ~= S.MAGIC then
    return nil, "not a team-bank file (magic)"
  end
  local body = data:sub(1, #data - 4)
  if S.crc32(body) ~= B.rd32(data, #data - 4) then
    return nil, "crc mismatch (file damaged)"
  end
  local ver = B.rd32(data, 8)
  if ver ~= S.VERSION then
    return nil, "unknown version " .. tostring(ver)
  end
  local fsha = data:sub(13, 32)
  local fslot, mounted, nbanks, ndocks = data:byte(33, 36)
  if sha1 and fsha ~= sha1 and fsha ~= string.rep("\0", 20) then
    return nil, "written for another nie.exe (SHA-1 differs)"
  end
  if slot and fslot ~= slot then
    return nil, string.format("belongs to slot %d, not %d", fslot, slot)
  end
  if nbanks < S.MIN_BANKS or nbanks > S.MAX_BANKS or ndocks ~= S.DOCKS or B.rd32(data, 36) ~= S.SET_SIZE then
    return nil, string.format("layout %d banks x %d docks x 0x%X not supported", nbanks, ndocks, B.rd32(data, 36))
  end
  local st = { slot = fslot, mounted = mounted, banks = {}, fingerprint = B.rd32(data, 40), sha1 = fsha }
  local p = S.HEADER_LEN -- 0-based offset into body
  local blen = #body
  for i = 1, nbanks do
    if p + 4 + S.BANK_NAME_LEN > blen then return nil, "truncated" end
    local tag, a1, a2, a3 = body:byte(p + 1, p + 4)
    local name = B.cstr(body:sub(p + 5, p + 4 + S.BANK_NAME_LEN))
    p = p + 4 + S.BANK_NAME_LEN
    local b = { name = name }
    if tag == 0 then
      b.content = "empty"
    elseif tag == 2 then
      b.content = "mounted"
    elseif tag == 1 then
      if p + S.SETS_LEN + S.IDENTS_LEN > blen then return nil, "truncated" end
      b.content = "stored"
      b.sets = body:sub(p + 1, p + S.SETS_LEN)
      p = p + S.SETS_LEN
      b.idents = body:sub(p + 1, p + S.IDENTS_LEN)
      p = p + S.IDENTS_LEN
      b.active = { a1, a2, a3 }
    else
      return nil, "bad bank tag " .. tostring(tag)
    end
    st.banks[i] = b
  end
  if p ~= blen then return nil, "trailing bytes" end
  if not S.is_consistent(st) then return nil, "inconsistent (mounted bank)" end
  return st
end

-- ------------------------------------------------------------------------------------------------ never lose a page

-- pages whose squads `old` holds and `new` would lose (bit b = page b): a page stored in `old` that is empty in `new`
-- (or past its end); the page mounted in `old` when `new` mounts another one and has that one empty. Names alone never
-- count. The caller removes the pages the user deleted.
function S.dropped_mask(old, new)
  local function empty_in_new(i)
    local n = new.banks[i]
    return n == nil or n.content == "empty"
  end
  local m = 0
  for i, b in ipairs(old.banks) do
    if b.content == "stored" and empty_in_new(i) then m = bor(m, lshift(1, i - 1)) end
  end
  if old.mounted ~= new.mounted and old.mounted < #old.banks and empty_in_new(old.mounted + 1) then
    m = bor(m, lshift(1, old.mounted))
  end
  return m
end

-- put back into `st` the stored pages `disk` (same slot, same mounted page) still holds and `st` lost (empty there),
-- except the pages in `allowed`; the name travels with the squads. Returns the pages restored (0-based).
function S.heal(st, disk, allowed)
  local restored = {}
  if st.slot ~= disk.slot or st.mounted ~= disk.mounted then return restored end
  for i, d in ipairs(disk.banks) do
    local b = i - 1
    if b < S.MAX_BANKS and band(allowed, lshift(1, b)) == 0 and b ~= st.mounted and d.content == "stored" then
      while #st.banks < i do
        st.banks[#st.banks + 1] = empty_bank()
      end
      local cur = st.banks[i]
      if cur.content == "empty" then
        cur.content, cur.sets, cur.idents = "stored", d.sets, d.idents
        cur.active = { d.active[1], d.active[2], d.active[3] }
        if cur.name == "" then cur.name = d.name end
        restored[#restored + 1] = b
      end
    end
  end
  return restored
end

-- bits of a mask as 1-based page numbers ("2, 5")
function S.pages_of(mask)
  local v = {}
  for b = 0, 31 do
    if band(mask, lshift(1, b)) ~= 0 then v[#v + 1] = tostring(b + 1) end
  end
  return table.concat(v, ", ")
end

S.bnot = bnot

return S
