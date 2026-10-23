-- Team bank pages of the Team dock («Plantilla de equipo»), like the team pages of other football games
-- (docs/game/mechanics/team-squads-extended.md §6). The exe keeps its 16 team sets; nothing in it is patched. A page
-- = the 11 user docks (logical sets 2..12). Page 1 is what the save holds; a swap writes a whole page into the live
-- sets in the order of the retail Re-Story swap 0xDA5C60: SetOrganizedFlagBit off for the old members, the 3 TeamInfo
-- copied (the retail operator= copies every field: the words are written as they are), the bit on for the new members,
-- RecountTeamInfo per team.
--
-- Commands (content\game\team_banks.toml; same names, arguments and returns as utilities.dll had):
--   CMND_BETTERQOL_TEAMBANK_INFO -> ok, mounted (0-based), count, name, used mask, slot
--   CMND_BETTERQOL_TEAMBANK_SET(page, online) -> ok, code, players emptied, new page
--   CMND_BETTERQOL_TEAMBANK_RENAME(page, name) -> ok
--   CMND_BETTERQOL_TEAMBANK_DELETE(page) -> ok, code
--   CMND_BETTERQOL_TEAMBANK_MENU(open, online) -> ok (the team-dock menu fence)
--   CMND_BETTERQOL_TEAMBANK_DUMP -> crc32 of the 11 live docks, dock-bit errors, team-0 members
-- game_state: utilities.team_banks.mounted / .count / .active (set here).
--
-- Persistence: blob team_banks.bin of mod utilities per save slot (lib/tb_store.lua format, the same bytes the DLL
-- wrote), staged with VRFW.save.blob_stage after every change of the pages (and again when the dock menu closes or the
-- game mode changes, with a fresh fingerprint): the save engine commits it when the game saves that slot and drops it
-- when the game leaves the slot without saving, like the party block itself. Before a stage the write guard of the DLL
-- runs here: a stage that would lose a stored page nobody deleted is refused; team_banks.best.bin (the richest previous
-- version) is staged with it.
--
-- Which pages the running game uses (the DLL's Session rules): a save load takes the slot's sidecar (a load is told by
-- game_state utilities.team_banks.loads, counted from the party Load post-hook TB_PartyLoad);
-- a return to the title keeps the pages; another slot reads its sidecar; only the slot event new_game starts with
-- page 1 only; a page leaves the sidecar only when the user deleted it or after that new game.
--
-- Settings: config.toml [team_banks] (enabled, pages, new_page, verify, blocked_modes); another mod may ask for more
-- pages / block more modes with a utilities\team_banks.toml in its own folder (min_pages, blocked_modes).

local B = require "lib/tb_bytes"
local S = require "lib/tb_store"

BetterQoL = BetterQoL or {}
BetterQoL.TeamBanks = BetterQoL.TeamBanks or {}

local band, bor, bnot, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift
local C = S.code

local BLOB, BEST = "team_banks.bin", "team_banks.best.bin"
local DECL_FILE = "utilities/team_banks.toml"
local KEY_MOUNTED, KEY_COUNT, KEY_ACTIVE = "utilities.team_banks.mounted", "utilities.team_banks.count", "utilities.team_banks.active"
-- party loads since boot (hook TB_PartyLoad, set below)
local KEY_LOADS = "utilities.team_banks.loads"
local REC_TEAM_FLAG = 0x1EC
local TEXT_BANK = "evt_tb_bank"

local function info(...) VRFW.log("team_banks:", ...) end
local function warn(...) VRFW.warn("team_banks:", ...) end
local function err(...) VRFW.error("team_banks:", ...) end

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

-- a command's number argument as an integer (truncated); `def` when it is not a number
local function int(v, def)
  if type(v) ~= "number" then return def end
  if v >= 0 then return math.floor(v) end
  return math.ceil(v)
end

-- ---------------------------------------------------------------------------------------- settings

local CFG = { pages = S.BANKS, copy_new = false, verify = true, blocked = { "story" }, decl_mods = {} }

do
  local function cfg(path)
    local ok, v = pcall(VRFW.files.config, "team_banks." .. path)
    if ok then return v end
    return nil
  end
  local pages = cfg("pages")
  if type(pages) == "number" then CFG.pages = pages end
  local np = cfg("new_page")
  if type(np) == "string" then CFG.copy_new = np:lower() == "copy" end
  local vf = cfg("verify")
  if type(vf) == "boolean" then CFG.verify = vf end
  local bm = cfg("blocked_modes")
  if type(bm) == "table" then
    CFG.blocked = {}
    for _, m in ipairs(bm) do
      if type(m) == "string" then CFG.blocked[#CFG.blocked + 1] = m end
    end
  end
  local ok, decls = pcall(VRFW.files.declarations, DECL_FILE)
  if ok and type(decls) == "table" then
    for _, e in ipairs(decls) do
      local d = type(e.data) == "table" and e.data or {}
      local mp, modes = d.min_pages, d.blocked_modes
      if (mp ~= nil and type(mp) ~= "number") or (modes ~= nil and type(modes) ~= "table") then
        warn(DECL_FILE .. " of mod " .. tostring(e.mod) .. " ignored: min_pages must be a number, blocked_modes a list")
      else
        if mp and mp > CFG.pages then CFG.pages = mp end
        for _, m in ipairs(modes or {}) do
          local seen = false
          for _, x in ipairs(CFG.blocked) do
            if x == m then seen = true end
          end
          if not seen and type(m) == "string" then CFG.blocked[#CFG.blocked + 1] = m end
        end
        CFG.decl_mods[#CFG.decl_mods + 1] = tostring(e.mod)
      end
    end
  end
  CFG.pages = S.clamp_count(CFG.pages)
end

-- ---------------------------------------------------------------------------------------- game access

local remap -- logical -> physical team set (asked from the game once)

local function table_ok()
  if remap then return remap end
  local t, seen = {}, {}
  for l = 0, 15 do
    local ok, p = pcall(VRFW.call, "Party.LogicalToPhysical", 0, l)
    if not ok or type(p) ~= "number" or p < 0 or p > 15 or seen[p] then
      return nil
    end
    seen[p] = true
    t[l] = p
  end
  remap = t
  return t
end

local function party_ptr()
  if not table_ok() then return nil end
  return global("tb_party")
end

local function active_slot()
  local ok, s = pcall(VRFW.slots.active)
  if ok and type(s) == "number" then return s end
  return 1
end

-- the current game mode is one of the blocked modes; nil = the mode service does not answer
local function blocked_mode()
  local known = false
  for _, m in ipairs(CFG.blocked) do
    local ok, v = pcall(VRFW.state, "mode.is." .. m)
    if ok and type(v) == "number" then
      if v == 1 then return true end
      known = true
    end
  end
  if known or #CFG.blocked == 0 then return false end
  return nil
end

local function usable(slot)
  return slot >= 2 and blocked_mode() == false
end

local function job_pending()
  local gdb = global("tb_game_data_backup")
  if not gdb then return nil end
  local ok, r = pcall(VRFW.call, "TB_IsJobPending", gdb)
  if not ok or type(r) ~= "number" then return nil end
  return band(r, 0xFF) ~= 0
end

local function set_base(party)
  local t = table_ok()
  local data = party and rd("ptr", party + S.PARTY_SET_DATA)
  if not t or not data then return nil end
  return data, t
end

-- the 11 live docks as words (nil when not readable): one VRFW.mem.read_array per dock (one region check and one
-- guarded read of the whole set) instead of one checked read per word (5951 reads)
local function live_docks(party)
  local data, t = set_base(party)
  if not data then return nil end
  local w, n = {}, 0
  for d = 0, S.DOCKS - 1 do
    local ok, a = pcall(VRFW.mem.read_array, "u32", data + t[S.FIRST_DOCK + d] * S.SET_SIZE, S.WPD)
    if not ok or type(a) ~= "table" then return nil end
    for i = 1, S.WPD do
      n = n + 1
      w[n] = a[i]
    end
  end
  return w
end

-- param, get_order of a live character handle (nil when stale)
local function ident(h)
  local ok, r = pcall(VRFW.chara.record, h)
  if ok and type(r) == "table" then return r.param or 0, r.get_order or 0 end
  return nil
end

local function team_flag(h)
  local ok, r = pcall(VRFW.chara.record, h)
  if not ok or type(r) ~= "table" or not r.addr then return nil end
  return rd("u16", r.addr + REC_TEAM_FLAG)
end

local function active_bytes(party)
  local a = {}
  for i = 0, 2 do
    a[i + 1] = rd("u8", party + S.ACTIVE_OFF + i)
    if a[i + 1] == nil then return nil end
  end
  return a
end

-- write the 11 docks from `w` with the Re-Story swap recipe
local function apply_docks(party, w)
  local data, t = set_base(party)
  if not data then return false, "team-set pointer not readable" end
  for d = 0, S.DOCKS - 1 do
    local l = S.FIRST_DOCK + d
    local set = data + t[l] * S.SET_SIZE
    -- the dock bit belongs to the members of teams 0 and 1
    local function bits(on)
      for tm = 0, S.FLAG_TEAMS - 1 do
        for k = 0, S.MEMBERS - 1 do
          local ok, e = pcall(VRFW.call, "Party.SetOrganizedFlagBit", set + S.member_off(tm, k), l, on)
          if not ok then
            return string.format("SetOrganizedFlagBit dock %d team %d: %s", l, tm, tostring(e))
          end
        end
      end
      return nil
    end
    local e = bits(false)
    if e then return false, e end
    local base = d * S.WPD
    local ok, e2 = pcall(function()
      -- the dock's TeamInfo words in one read; only the words that differ are written
      local cur = VRFW.mem.read_array("u32", set, S.TEAM_WORDS)
      if type(cur) ~= "table" then error("TeamInfo not readable") end
      for i = 0, S.TEAM_WORDS - 1 do
        local v = w[base + i + 1]
        if cur[i + 1] ~= v then
          VRFW.mem.write("u32", set + i * 4, v)
        end
      end
    end)
    if not ok then return false, string.format("TeamInfo copy dock %d: %s", l, tostring(e2)) end
    e = bits(true)
    if e then return false, e end
    for tm = 0, S.TEAMS - 1 do
      local ok3, e3 = pcall(VRFW.call, "Party.RecountTeamInfo", set + tm * S.TEAM_SIZE)
      if not ok3 then return false, string.format("RecountTeamInfo dock %d team %d: %s", l, tm, tostring(e3)) end
    end
  end
  return true
end

-- per-dock report (log) -> crc32 of the 11 docks, flag errors, team-0 members
local function verify_docks(party, why)
  local w = live_docks(party)
  if not w then return nil end
  local flag_errors, members, line = 0, 0, {}
  for d = 0, S.DOCKS - 1 do
    local l = S.FIRST_DOCK + d
    local n = S.team0_count(w, d)
    members = members + n
    for _, m in ipairs(S.flag_members(w, d)) do
      local f = team_flag(m[3])
      local bit = f and band(f, lshift(1, l)) ~= 0
      if bit ~= true then
        flag_errors = flag_errors + 1
        warn(string.format("[%s] dock %02d team %d slot %d: handle 0x%s flag bit %d = %s", why, d + 1, m[1], m[2], B.hex32(m[3]), l, tostring(f and bit)))
      end
    end
    line[#line + 1] = string.format(" %02d:%s/%d", d + 1, B.hex32(S.crc32(B.from_words(w, d * S.WPD + 1, (d + 1) * S.WPD))), n)
  end
  local crc = S.crc32(B.from_words(w))
  info(string.format("[%s] docks crc %s, team-0 members %d, flag errors %d |%s", why, B.hex32(crc), members, flag_errors, table.concat(line)))
  return crc, flag_errors, members
end

-- ---------------------------------------------------------------------------------------- store key

-- the 20 bytes the sidecars carry: the running build's save family (VRFW.build.store_key(), 40 hex); nil = unknown
local store_key_bytes
local function store_key()
  if store_key_bytes ~= nil then return store_key_bytes or nil end
  local ok, hex = false, nil
  if type(VRFW.build) == "table" and type(VRFW.build.store_key) == "function" then
    ok, hex = pcall(VRFW.build.store_key)
  end
  store_key_bytes = (ok and type(hex) == "string" and #hex == 40) and B.hex_bytes(hex) or false
  if not store_key_bytes then
    warn("the build's store key is not available (VRFW.build.store_key): sidecars are read whatever build wrote them")
  end
  return store_key_bytes or nil
end

-- ---------------------------------------------------------------------------------------- page session

local SS = {
  state = nil,        -- page state of the running game (lib/tb_store)
  gen = 0,            -- changes of `state` since it was read
  dirty = false,      -- `state` differs from the sidecar on disk
  restage = false,    -- the save engine dropped our staged sidecar while `state` still holds changes
  new_game = {},      -- [slot] = a new_game event not handled yet
  allowed = {},       -- [slot] = pages that may leave the sidecar at its next commit (bit b = page b)
  ev_seen = 0,        -- slot events read
  loads_seen = nil,   -- KEY_LOADS when `state` was resolved
  came_back = false,  -- a switch back into the state's slot (used only without KEY_LOADS)
  committed = nil,    -- { slot, bytes, st (lenient decode or nil), strict } = the sidecar on disk
  best = {},          -- [slot] = stored pages of team_banks.best.bin (-1 = none)
  staged = nil,       -- { slot, bytes, st, allowed, gen, best }
  in_menu = false,
  online = false,
}

do
  local ok, seq = pcall(VRFW.slots.event_seq)
  if ok and type(seq) == "number" then SS.ev_seen = math.max(0, seq - 64) end
end

-- the party Load post-hook (content/game/team_banks.toml TB_PartyLoad): count the loads, publish them
local party_loads = 0
pcall(VRFW.state.set, KEY_LOADS, 0)
VRFW.on("hook:TB_PartyLoad:post", function(ev)
  party_loads = party_loads + 1
  pcall(VRFW.state.set, KEY_LOADS, party_loads)
  return nil
end)

-- A return to the title (GameReset) clears the game in memory: until the next party Load its docks are the reset
-- game's, not the slot's save, and must not be taken as «docks edited» (the boot mode's mode_leave read them and staged
-- their fingerprint, so every later load of the slot warned «written with other docks», 2026-10-14 log: fp 07D9C1C2 =
-- the reset docks, C7D24E2B = the save's). The party_loads count at the last reset; nil = a load came after it.
local reset_loads = nil
VRFW.on("game_reset", function()
  reset_loads = party_loads
  return nil
end)
local function docks_from_reset()
  if reset_loads == nil then return false end
  if party_loads ~= reset_loads then
    reset_loads = nil
    return false
  end
  return true
end

local loads_warned = false
local function loads_now()
  local ok, v = pcall(VRFW.state, KEY_LOADS)
  if ok and type(v) == "number" then return v end
  if not loads_warned then
    loads_warned = true
    warn("game_state " .. KEY_LOADS .. " is not answered (hook TB_PartyLoad off): a switch back into a slot is taken as a load")
  end
  return nil
end

local function changed()
  SS.gen = SS.gen + 1
  SS.dirty = true
end

local function forget_slot(slot)
  if SS.state and SS.state.slot == slot then
    SS.state, SS.dirty, SS.restage = nil, false, false
  end
  if SS.committed and SS.committed.slot == slot then SS.committed = nil end
  if SS.staged and SS.staged.slot == slot then SS.staged = nil end
  SS.best[slot] = nil
end

local function on_saved(slot)
  local s = SS.staged
  if not s or s.slot ~= slot then return end
  SS.committed = { slot = slot, bytes = s.bytes, st = s.st, strict = true }
  if s.best then SS.best[slot] = s.best end
  SS.allowed[slot] = band(SS.allowed[slot] or 0, bnot(s.allowed))
  if SS.state and SS.state.slot == slot and SS.gen == s.gen then SS.dirty = false end
  SS.staged = nil
  info(string.format("sidecar of slot %d committed with the game's save (%d bytes, mounted page %d, stored pages %d)", slot, #s.bytes, s.st.mounted + 1, S.stored_count(s.st)))
end

-- read the slot events not seen yet
local function poll()
  local okq, seq = pcall(VRFW.slots.event_seq)
  if not okq or type(seq) ~= "number" then return end
  while SS.ev_seen < seq do
    SS.ev_seen = SS.ev_seen + 1
    local ok, kind, a, b = pcall(VRFW.slots.event, SS.ev_seen)
    if not ok or not kind then
      warn("slot event #" .. SS.ev_seen .. " is gone (ring full): ignored, pages kept")
    elseif kind == "new_game" then
      info("the slot service reports a new game in slot " .. a .. ": its next use starts with page 1 only")
      forget_slot(a)
      SS.new_game[a] = true
    elseif kind == "saved" then
      on_saved(a)
    elseif kind == "switched" then
      -- the save engine drops what was staged for the slot left
      if SS.staged and SS.staged.slot == b then
        SS.staged = nil
        if SS.state and SS.state.slot == b and SS.dirty then SS.restage = true end
      end
      if SS.state and SS.state.slot == a then SS.came_back = true end
    elseif kind == "deleted" or kind == "reset" then
      forget_slot(a)
    elseif kind == "copied" then
      forget_slot(b)
    end
  end
end

-- the slot's sidecar, checked against the live docks (no sidecar = page 1 only). `unloaded`: no party Load seen yet
-- (boot, title): the docks in memory are not the slot's, a mismatch is expected and the check is made again on load
local function read_sidecar(slot, party, unloaded)
  SS.best[slot] = nil
  if slot < 2 then return S.fresh(slot, CFG.pages) end
  local okb, best = pcall(VRFW.save.blob, BEST, slot)
  local bst = okb and type(best) == "string" and S.decode(best) or nil
  SS.best[slot] = bst and S.stored_count(bst) or -1
  local ok, bytes, why = pcall(VRFW.save.blob, BLOB, slot)
  if not ok then bytes, why = nil, tostring(bytes) end
  if bytes == nil then
    SS.committed = nil
    if why then
      err("cannot read the sidecar of slot " .. slot .. " (" .. tostring(why) .. "): starting with page 1 only; the sidecar is left as it is")
    else
      info(string.format("slot %d has no sidecar yet: page 1 = the save's docks, pages 2-%d unused", slot, CFG.pages))
    end
    return S.fresh(slot, CFG.pages)
  end
  local st, bad = S.decode(bytes, slot, store_key())
  SS.committed = { slot = slot, bytes = bytes, st = st or S.decode(bytes), strict = st ~= nil }
  if not st then
    err("the sidecar of slot " .. slot .. " was rejected: " .. tostring(bad) .. ": starting with page 1 only (the file stays until a page change replaces it)")
    return S.fresh(slot, CFG.pages)
  end
  local before = #st.banks
  local now = S.resize(st, CFG.pages)
  if now ~= before or now ~= CFG.pages then
    warn(string.format("sidecar has %d pages, config %d: now %d (used pages are never dropped)", before, CFG.pages, now))
  end
  local w = party and live_docks(party)
  if not w then
    warn("docks not readable: sidecar used without check")
  else
    local fp = S.fingerprint(w)
    if fp == st.fingerprint then
      info("sidecar of slot " .. slot .. " matches the loaded docks (fp " .. B.hex32(fp) .. ")")
    elseif unloaded then
      info(string.format("sidecar of slot %d: the save is not loaded yet (fp %s, live %s): checked again when it loads", slot, B.hex32(st.fingerprint), B.hex32(fp)))
    else
      warn(string.format("sidecar of slot %d was written with other docks (fp %s, live %s): an older / restored save, or docks changed since the last page change. Its pages are used; the live docks count as page %d", slot, B.hex32(st.fingerprint), B.hex32(fp), st.mounted + 1))
    end
  end
  info(string.format("slot %d: mounted page %d of %d, stored pages %d, used mask 0x%X", slot, st.mounted + 1, #st.banks, S.stored_count(st), S.used_mask(st)))
  return st
end

local function sha1_for(st)
  local k = store_key()
  if k then return k end
  if st.sha1 then return st.sha1 end
  local c = SS.committed
  if c and c.st and c.st.sha1 then return c.st.sha1 end
  return string.rep("\0", 20)
end

-- stage the sidecar of the state (slot = the state's) with the write guard; true when staged
local function stage(why)
  local st = SS.state
  if not st or st.slot < 2 then return false end
  local slot = st.slot
  local party = party_ptr()
  local w = party and live_docks(party)
  if not w then
    err("cannot read the party docks: sidecar not staged (" .. why .. ")")
    return false
  end
  local fp = S.fingerprint(w)
  local allowed = SS.allowed[slot] or 0
  local old = SS.committed
  if old and old.slot ~= slot then old = nil end
  -- the stored pages that the sidecar on disk still holds and the running state lost are put back first
  if old and old.st and old.strict then
    local back = S.heal(st, old.st, allowed)
    if #back > 0 then
      changed()
      local p = {}
      for i, b in ipairs(back) do p[i] = tostring(b + 1) end
      warn("slot " .. slot .. ": the running state had lost page(s) " .. table.concat(p, ", ") .. " that the sidecar on disk still stores: put back")
    end
  end
  local bytes = S.encode(st, sha1_for(st), fp)
  local best
  if old and old.st then
    local lost = S.dropped_mask(old.st, st)
    local dropped = band(lost, bnot(allowed))
    if dropped ~= 0 then
      err(string.format("sidecar of slot %d NOT staged: it would lose stored page(s) %s that nobody deleted; the sidecar on disk keeps its pages (report this log)", slot, S.pages_of(dropped)))
      return false
    end
    if lost ~= 0 then
      info("slot " .. slot .. ": page(s) " .. S.pages_of(lost) .. " leave the sidecar (deleted / new game); the replaced version stays in the save engine's backups")
    end
    local bc = SS.best[slot]
    local oc = S.stored_count(old.st)
    if (bc == nil or oc >= bc) and old.bytes ~= bytes then best = oc end
  elseif old and old.bytes and not old.asided then
    -- an unreadable sidecar on disk: set aside (.archive) before a new one replaces it
    local ok, where = pcall(VRFW.save.blob_aside, BLOB, slot)
    warn("slot " .. slot .. ": unreadable sidecar " .. (ok and tostring(where) or "not set aside"))
    old.asided = true
  end
  local ok, okst, where = pcall(VRFW.save.blob_stage, BLOB, bytes, slot)
  if not ok or not okst then
    err("sidecar of slot " .. slot .. " not staged: " .. tostring(ok and where or okst))
    return false
  end
  if best then
    local okb, okbs, whereb = pcall(VRFW.save.blob_stage, BEST, old.bytes, slot)
    if not okb or not okbs then
      warn("best copy of slot " .. slot .. " not staged: " .. tostring(okb and whereb or okbs))
      best = nil
    end
  end
  st.fingerprint = fp
  SS.staged = { slot = slot, bytes = bytes, st = S.copy(st), allowed = allowed, gen = SS.gen, best = best }
  SS.restage = false
  info(string.format("sidecar of slot %d staged (%s): %d bytes, mounted page %d, stored %d, fp %s; written with the game's next save", slot, why, #bytes, st.mounted + 1, S.stored_count(st), B.hex32(fp)))
  return true
end

-- the page state of the running game for `slot` (the DLL's Session.resolve + loaded rules)
local function resolve(slot, party)
  poll()
  local loads = loads_now()
  if SS.new_game[slot] then
    SS.new_game[slot] = nil
    SS.state = S.fresh(slot, CFG.pages)
    SS.allowed[slot] = S.ALL
    SS.came_back, SS.loads_seen = false, loads
    changed()
    info("slot " .. slot .. ": new game: page 1 only (the save engine moved the old slot data to its trash)")
    return SS.state
  end
  local reread = SS.state == nil or SS.state.slot ~= slot
  if not reread then
    if loads ~= nil then
      reread = SS.loads_seen ~= nil and loads ~= SS.loads_seen
    else
      reread = SS.came_back
    end
    if reread then info("slot " .. slot .. ": the save was loaded: its sidecar is the page state") end
  end
  SS.came_back = false
  SS.loads_seen = loads
  if reread then
    -- our own stage of this slot (unsaved pages) no longer matches the game in memory: it is replaced below
    local stale = SS.staged ~= nil and SS.staged.slot == slot
    SS.staged = nil
    SS.state = read_sidecar(slot, party, loads == 0)
    SS.allowed[slot] = 0
    SS.gen, SS.dirty, SS.restage = SS.gen + 1, false, false
    if stale and slot >= 2 then stage("the loaded save's pages back on the stage") end
  elseif SS.restage and SS.dirty and slot >= 2 then
    info("slot " .. slot .. ": the switch was not completed (the game in memory is unchanged): page changes staged again")
    stage("restage after an aborted switch")
  end
  return SS.state
end

local function publish()
  local function set(k, v) pcall(VRFW.state.set, k, v) end
  if not party_ptr() then
    set(KEY_MOUNTED, -1)
    set(KEY_COUNT, 0)
    set(KEY_ACTIVE, 0)
    return
  end
  local slot = active_slot()
  local use = usable(slot)
  set(KEY_COUNT, CFG.pages)
  set(KEY_ACTIVE, use and 1 or 0)
  local m = 0
  if use and SS.state and SS.state.slot == slot then m = SS.state.mounted end
  set(KEY_MOUNTED, m)
end

-- outside the commands (mode changes): handle the events, stage what a switch dropped, refresh the keys. Never while
-- the game in memory belongs to another slot than the page state (a switch in progress).
local function touch(why)
  if not party_ptr() then return end
  local slot = active_slot()
  if SS.state == nil or SS.state.slot == slot then
    local party = party_ptr()
    local st = resolve(slot, party)
    if SS.dirty and slot >= 2 and (SS.restage or not SS.staged) then
      stage(why)
    elseif slot >= 2 and st and (st.fingerprint or 0) ~= 0 and loads_now() ~= 0 and not docks_from_reset() then
      -- docks edited without a page change (dock closed / mode change): the sidecar takes the live fingerprint, else
      -- every later load of the slot warned «written with other docks» for an ordinary edit (2026-10-13)
      local w = live_docks(party)
      local fp = w and S.fingerprint(w)
      if fp and fp ~= st.fingerprint then stage(why .. ", docks edited") end
    end
  else
    poll()
  end
  publish()
end

local function display_name(st, b)
  local bank = st.banks[b + 1]
  if bank and bank.name ~= "" then return bank.name end
  local ok, word = pcall(VRFW.text, TEXT_BANK)
  if ok and type(word) == "string" and word ~= "" then return word .. " " .. (b + 1) end
  return tostring(b + 1)
end

-- ---------------------------------------------------------------------------------------- the swap

local function swap(target)
  local slot = active_slot()
  local fence = { slot = slot, blocked_mode = blocked_mode(), job_pending = job_pending(), in_menu = SS.in_menu, online = SS.online }
  local refused = S.check_fence(fence)
  if refused then return nil, refused end
  local party = party_ptr()
  if not party then return nil, C.NOT_READY end
  local st = resolve(slot, party)
  local from = st.mounted
  if target >= #st.banks then return nil, C.BAD_ARGS end
  if target == from then return nil, C.SAME end
  local cur = live_docks(party)
  local cur_active = active_bytes(party)
  if not cur or not cur_active then return nil, C.NOT_READY end
  local cur_idents, unresolved = S.idents_of(cur, ident)
  if unresolved > 0 then
    warn(string.format("%d member(s) of page %d have no live record now (they will be emptied when it is mounted again)", unresolved, from + 1))
  end
  local bank = st.banks[target + 1]
  local new_w, dropped, stored_active, was_new
  if bank.content == "stored" then
    new_w = B.words(bank.sets, 0, S.WORDS)
    stored_active = bank.active
    dropped = S.validate(new_w, bank.idents, ident)
  elseif bank.content == "empty" then
    was_new = true
    new_w = CFG.copy_new and S.copy_words(cur) or S.emptied(cur)
    dropped = {}
  else
    err(string.format("state says page %d is mounted but %d is", target + 1, from + 1))
    return nil, C.NOT_READY
  end
  for _, x in ipairs(dropped) do
    warn(string.format("page %d dock %02d team %d slot %d: handle 0x%s is no longer the stored character (param %s, order %d) -> slot emptied", target + 1, x.dock + 1, x.team, x.slot, B.hex32(x.handle), B.hex32(x.param), x.order))
  end
  info(string.format("slot %d: page %d -> %d%s (menu %s, online %s), active sets vs/esports/tournament %d/%d/%d", slot, from + 1, target + 1,
    was_new and (CFG.copy_new and " (new: copy)" or " (new: empty)") or "", tostring(SS.in_menu), tostring(SS.online), cur_active[1], cur_active[2], cur_active[3]))
  local ok, e = apply_docks(party, new_w)
  if not ok then
    err("swap failed: " .. tostring(e) .. "; restoring page " .. (from + 1))
    local ok2, e2 = apply_docks(party, cur)
    if ok2 then
      info("page " .. (from + 1) .. " restored")
    else
      err("RESTORE FAILED too: " .. tostring(e2) .. " (do not save; restart the game)")
    end
    return nil, C.EXCEPTION
  end
  local new_active = stored_active and S.restore_active(cur_active, stored_active) or cur_active
  for i = 1, 3 do
    if new_active[i] ~= cur_active[i] then
      local okw = pcall(VRFW.mem.write, "u8", party + S.ACTIVE_OFF + i - 1, new_active[i])
      if not okw then warn("active set byte " .. (i - 1) .. " not written") end
    end
  end
  for i, n in ipairs({ "vs", "esports", "tournament" }) do
    local v = new_active[i]
    if v >= S.FIRST_DOCK and v <= S.LAST_DOCK and S.team0_count(new_w, v - S.FIRST_DOCK) == 0 then
      warn(string.format("the %s team (dock %02d) of page %d has no players", n, v - S.FIRST_DOCK + 1, target + 1))
    end
  end
  local old = st.banks[from + 1]
  old.content, old.sets, old.idents, old.active = "stored", B.from_words(cur), cur_idents, cur_active
  bank.content, bank.sets, bank.idents, bank.active = "mounted", nil, nil, nil
  st.mounted = target
  changed()
  info(string.format("page %d mounted: %d player slot(s) emptied, active sets %d/%d/%d; saved with the next game save", target + 1, #dropped, new_active[1], new_active[2], new_active[3]))
  if CFG.verify then verify_docks(party, "after swap") end
  stage("page " .. (target + 1) .. " mounted")
  return { from = from, dropped = #dropped, was_new = was_new == true }
end

-- ---------------------------------------------------------------------------------------- commands

function BetterQoL.TeamBanks.Info()
  local party = party_ptr()
  if not party then
    publish()
    return false
  end
  local slot = active_slot()
  local use = usable(slot)
  local st = resolve(slot, party)
  publish()
  return use, st.mounted, #st.banks, display_name(st, st.mounted), S.used_mask(st), slot
end

function BetterQoL.TeamBanks.Set(bank, online)
  bank = int(bank, -1)
  if not party_ptr() then return false, C.NOT_READY end
  SS.online = int(online, 0) ~= 0
  local r, code
  if bank >= 0 and bank < S.MAX_BANKS then
    r, code = swap(bank)
  else
    code = C.BAD_ARGS
  end
  publish()
  if r then return true, C.OK, r.dropped, r.was_new end
  if code ~= C.SAME then warn("SET page " .. (bank + 1) .. " refused, code " .. tostring(code)) end
  return false, code, 0, false
end

function BetterQoL.TeamBanks.Rename(bank, name)
  bank = int(bank, -1)
  name = S.sanitize_name(type(name) == "string" and name or "")
  local party = party_ptr()
  local slot = active_slot()
  if not party or bank < 0 or bank >= S.MAX_BANKS or slot < 2 then return false end
  local st = resolve(slot, party)
  if bank >= #st.banks then return false end
  st.banks[bank + 1].name = name
  changed()
  info(string.format("page %d renamed to %q (saved with the next game save)", bank + 1, name))
  stage("page " .. (bank + 1) .. " renamed")
  return true
end

function BetterQoL.TeamBanks.Delete(bank)
  bank = int(bank, -1)
  local party = party_ptr()
  if not party then return false, C.NOT_READY end
  local slot = active_slot()
  if bank < 0 or bank >= S.MAX_BANKS or slot < 2 then return false, C.BAD_ARGS end
  local st = resolve(slot, party)
  if bank >= #st.banks then return false, C.BAD_ARGS end
  if st.mounted == bank then return false, C.MOUNTED end
  st.banks[bank + 1] = { name = "", content = "empty" }
  SS.allowed[slot] = bor(SS.allowed[slot] or 0, lshift(1, bank))
  changed()
  info("page " .. (bank + 1) .. " deleted (saved with the next game save)")
  stage("page " .. (bank + 1) .. " deleted")
  publish()
  return true, C.OK
end

function BetterQoL.TeamBanks.Menu(open, online)
  open = int(open, 0) ~= 0
  SS.in_menu = open
  SS.online = open and int(online, 0) ~= 0
  local ready = party_ptr() ~= nil
  -- the menu closed: the docks may have been edited: the staged sidecar gets the fresh fingerprint
  if ready and not open then
    local ok, e = pcall(touch, "team dock closed")
    if not ok then warn("menu close: " .. tostring(e)) end
  end
  return ready
end

function BetterQoL.TeamBanks.Dump()
  local party = party_ptr()
  local crc, errs, members
  if party then crc, errs, members = verify_docks(party, "dump") end
  if not crc then return -1, -1, -1 end
  return crc, errs, members
end

-- ---------------------------------------------------------------------------------------- mode changes

for _, trig in ipairs({ "mode_enter", "mode_leave" }) do
  VRFW.on(trig, function()
    local ok, e = pcall(touch, trig)
    if not ok then warn(trig .. ": " .. tostring(e)) end
  end)
end

pcall(VRFW.state.set, KEY_COUNT, CFG.pages)
pcall(VRFW.state.set, KEY_ACTIVE, 0)
pcall(VRFW.state.set, KEY_MOUNTED, 0)

info(string.format("active: %d pages x %d docks (logical %d..%d), new page = %s, blocked modes {%s}%s, sidecar = blob %s per slot (staged with the game's save)",
  CFG.pages, S.DOCKS, S.FIRST_DOCK, S.LAST_DOCK, CFG.copy_new and "copy of the current page" or "empty", table.concat(CFG.blocked, ", "),
  #CFG.decl_mods > 0 and (" (declarations of " .. table.concat(CFG.decl_mods, ", ") .. ")") or "", BLOB))
