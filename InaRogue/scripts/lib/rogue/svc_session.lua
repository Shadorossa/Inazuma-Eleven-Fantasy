-- InaRogue › INAROGUE as an overlay session (docs/game/engine/save-overlay-session.md): the mechanism is the
-- VR-Framework's generic session (VRFW.session: images, swap, sink, restore / verification, journal, the in-place
-- reload); this keeps INAROGUE's Lua names CMND_EVT_RL_SESSION_* (the grafts call them) and its rules: the storage slot
-- is INAROGUE's reserved slot ([save_slots.mode_slots] inarogue), the journal is IF's global blob rogue_session.json,
-- [rogue] session_entry switches the overlay entry on (off = the old slot-4 switch) and [rogue] session_debug the test
-- session. Was the plugin's rogue::session until 2026-10-11 (IF final round, docs/framework/new-core/if-final-misc.md).
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_EVT_RL_SESSION_BEGIN | kind (0 INAROGUE swap, 1 test session) | ok, code, imageKiB, ms (code 12 = no game yet) |
-- | CMND_EVT_RL_SESSION_END | mode (0..3) | ok, code, dirtyBlocks, ms |
-- | CMND_EVT_RL_SESSION_STATE | – | open, slot, discardedWrites, imageKiB, reloadArmed, enabled, debug, swapped |
-- | CMND_EVT_RL_SESSION_RELOAD | – | ok, code |
-- | CMND_EVT_RL_SESSION_DISK_CHECK | – | ok, same, dirtyBlocks |
-- | CMND_EVT_RL_SESSION_ORPHAN | – | wasOpen, code |
--
-- Nothing is answered (as an unknown command) when the framework refused the registration or [modules] save_slots is
-- off: INAROGUE keeps its own slot then.

local U = require "lib/rogue/util"
local info, warn = U.logger("rogue session")

local S = {}

local JOURNAL = "rogue_session.json"
local READY, ENTRY, DEBUG = false, false, false

local function codes() return VRFW.session.code end
local function kinds() return VRFW.session.kind end

-- start: register INAROGUE's session with the framework (journal recovery happens there)
function S.start()
  local ok, r = pcall(VRFW.session.register, U.ROGUE_SLOT, JOURNAL)
  if not ok or r ~= codes().OK then
    warn("the framework refused the session (code " .. tostring(r) .. "): CMND_EVT_RL_SESSION_* off (INAROGUE keeps its own slot)")
    return false
  end
  ENTRY = U.cfg("rogue.session_entry", true) == true
  DEBUG = U.cfg("rogue.session_debug", false) == true
  READY = true
  info(string.format("ready on the VR-Framework session (INAROGUE entry as a session: %s; debug checklist: %s; storage slot %d; journal %s)",
    ENTRY and "ON" or "off, slot-4 switch", DEBUG and "ON" or "off", U.ROGUE_SLOT, JOURNAL))
  return true
end

function S.Begin(k_arg)
  if not READY then return nil end
  local k = U.int(k_arg, kinds().OVERLAY)
  local refused
  if k == kinds().OVERLAY and not ENTRY then
    warn("BEGIN refused: [rogue] session_entry = false (INAROGUE uses the slot-4 switch)")
    refused = codes().DISABLED
  elseif k == kinds().TEST and not DEBUG then
    warn("BEGIN(test) refused: [rogue] session_debug = false")
    refused = codes().DISABLED
  end
  if refused then return false, refused, 0, 0 end
  local ok, done, cd, kib, ms = pcall(VRFW.session.begin, U.ROGUE_SLOT, k)
  if not ok then return false, codes().NOT_READY, 0, 0 end
  if done then info(string.format("BEGIN(%d) done in %d ms", k, ms or 0)) end
  return done, cd, kib, ms
end

function S.End(m_arg)
  if not READY then return nil end
  local m = U.int(m_arg, VRFW.session.mode.RESTORE)
  local ok, closed, cd, dirty, ms = pcall(VRFW.session.finish, m)
  if not ok then closed, cd, dirty, ms = false, codes().NOT_READY, 0, 0 end
  info(string.format("END(%d) -> closed %s, code %s in %s ms", m, tostring(closed), tostring(cd), tostring(ms)))
  return closed, cd, dirty, ms
end

function S.State()
  if not READY then return nil end
  local ok, s = pcall(VRFW.session.state)
  if not ok or type(s) ~= "table" then s = {} end
  return s.open == true, s.slot or 0, s.discarded or 0, s.image_kib or 0, s.reload_armed == true, ENTRY, DEBUG, s.swapped == true
end

function S.Reload()
  if not READY then return nil end
  local ok, r = pcall(VRFW.session.reload)
  if not ok then r = codes().NOT_READY end
  return r == codes().OK, r
end

function S.DiskCheck()
  if not READY then return nil end
  local ok, done, same, dirty = pcall(VRFW.session.disk_check)
  if not ok or not done then return false, false, 0 end
  return true, same, dirty
end

function S.Orphan()
  if not READY then return nil end
  local ok, was, cd = pcall(VRFW.session.orphan)
  if not ok then return false, codes().OK end
  return was, cd
end

return S
