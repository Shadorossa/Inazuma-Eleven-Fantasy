-- InaRogue › the INAROGUE save on the VR-Framework's slot service (docs/game/modes/
-- inarogue.md §13): its slot commands, the locked slot's story / Chronicle progress copied read-only into it (§13.11,
-- the one exception to rule #1) and its three filters on retail commands. The declarations (and the reserved slots) are
-- content\game\save_slot.toml. Was the plugin's saveslots::ifslots until 2026-10-11 (IF final round,
-- docs/framework/new-core/if-final-misc.md); same commands and answers:
--
--   CMND_EVT_SLOT_ROGUE()            -> rogueSlot, active, returnSlot, rogueHasGame
--   CMND_EVT_SLOT_ROGUE_RESET()      -> ok, code (the slot file backed up and removed, the slot's mod data to the trash)
--   CMND_EVT_SLOT_ROGUE_RETURN(n)    -> ok («back» from the INAROGUE save goes to slot n = 2..3, 0 = the slot screen)
--   CMND_EVT_S1P_LOAD()              -> ok, chapter, subPhase (the locked slot's progress; only inside the INAROGUE save)
--   CMND_EVT_S1P_FLAG(bank, i)       -> value (bank 0 global bit flag, 1 global byte flag, 9 soccer-game clear bit)
--   CMND_EVT_S1P_CHRON(kind, i)      -> byte (kind 0 clear / 1 lock / 2 new; -1 past the end)
--   CMND_EVT_S1P_PHASE([ch, sub])    -> old, new (the INAROGUE save's story phase raised, never lowered; saved and live)

local U = require "lib/rogue/util"

InaRogue.Slot = InaRogue.Slot or {}

local function info(...) VRFW.log("save_slots:", ...) end
local function warn(...) VRFW.warn("save_slots:", ...) end
local function err(...) VRFW.error("save_slots:", ...) end

local ROGUE_SLOT = math.floor(U.ROGUE_SLOT)
local NORMAL_SLOTS = 3
local ON = true   -- the slot service is the framework's: always there

-- the story phase status: +0x08 the saved record, +0x14058 the live one; +4 / +8 of each = next / checked-free phase
local PHASE_SAVED, PHASE_LIVE, PHASE_NEXT_FREE = 0x08, 0x14058, { 4, 8 }

-- title request ids / flags of the filters
local TITLE_REQUEST_OPTIONS, TITLE_REQUEST_MY_TEAM = 1518731440, 1438851263
local FLAG_AVATAR_DONE, FLAG_TITLE_TUTORIAL_SEEN = 2113473044, 3351186562

local s1p = nil   -- the locked slot's progress read by S1P_LOAD

local function rd(t, a)
  local ok, v = pcall(VRFW.mem.read, t, a)
  if ok then return v end
  return nil
end

local function wr(t, a, v) return (pcall(VRFW.mem.write, t, a, v)) end

local function int(v)
  if type(v) ~= "number" then return nil end
  return v >= 0 and math.floor(v) or math.ceil(v)
end

local function ready()
  local ok, r = pcall(VRFW.slots.ready)
  return ok and r == true
end

-- the storage slot of an open overlay session (the INAROGUE save loaded over the player's slot), nil = none
local function overlay_slot()
  local ok, s = pcall(VRFW.session.state)
  if ok and type(s) == "table" and s.open == true and type(s.storage) == "number" and s.storage > 0 then
    return math.floor(s.storage)
  end
  return nil
end

-- the loaded game's slot: the overlay session's storage slot first (the slot service is not ready while a menu scene
-- changes), else the slot service's active slot
local function active()
  local o = overlay_slot()
  if o then return o end
  if not ready() then return 1 end
  local ok, s = pcall(VRFW.slots.active)
  return ok and tonumber(s) or 1
end

local function in_rogue() return active() == ROGUE_SLOT end

local function bit_of(str, i)
  if type(str) ~= "string" or i < 0 then return 0 end
  local b = string.byte(str, math.floor(i / 8) + 1)
  if not b then return 0 end
  return math.floor(b / 2 ^ (i % 8)) % 2
end

-- ------------------------------------------------------------------------------------------------ slot commands

function InaRogue.Slot.Info()
  if not ON then return nil end
  local r = ready()
  local ret = r and (select(2, pcall(VRFW.slots.return_slot)) or 0) or 0
  local okh, has = pcall(VRFW.slots.used, ROGUE_SLOT)
  return ROGUE_SLOT, active(), tonumber(ret) or 0, r and okh and has == true
end

function InaRogue.Slot.Return(n)
  if not ON then return nil end
  n = int(n) or 0
  local v = (n >= 2 and n <= NORMAL_SLOTS) and n or 0
  local ok, done = pcall(VRFW.slots.set_return_slot, v)
  info("INAROGUE return target = " .. (v == 0 and "the slot screen" or ("slot " .. v)))
  return ok and done == true
end

function InaRogue.Slot.Reset()
  if not ON then return nil end
  local ok, done, cd, note = pcall(VRFW.slots.reset_reserved, ROGUE_SLOT, "rogue_reset")
  if not ok then return false, -1 end
  if done then
    info(string.format("ROGUE_RESET: slot %d is empty again (save kept in %s)", ROGUE_SLOT, tostring(note)))
  else
    warn(string.format("ROGUE_RESET refused (code %s): %s", tostring(cd), tostring(note)))
  end
  return done == true, cd
end

-- ------------------------------------------------------------------------------------------------ slot 1 progress

function InaRogue.Slot.S1pLoad()
  if not ON then return nil end
  local why
  if not in_rogue() then
    why = "only inside the INAROGUE save"
  else
    local okl, locked = pcall(VRFW.slots.locked)
    local src = (okl and tonumber(locked)) or 1
    local ok, p, e = pcall(VRFW.slots.progress, src)
    if ok and type(p) == "table" then
      s1p = p
      info(string.format("slot 1 progress read (read-only): phase %d (chapter %d sub %d), story clear b0:1 %s, future route b0:822 %s",
        p.chapter * 10000 + p.sub_phase, p.chapter, p.sub_phase, tostring(bit_of(p.bits, 1) == 1), tostring(bit_of(p.bits, 822) == 1)))
      return true, p.chapter, p.sub_phase
    end
    why = ok and tostring(e) or tostring(p)
  end
  warn("slot 1 progress not read: " .. why)
  return false, 0, 0
end

function InaRogue.Slot.S1pFlag(bank, i)
  if not ON then return nil end
  bank, i = int(bank) or -1, math.max(int(i) or -1, 0)
  if not s1p then return 0 end
  if bank == 0 then return bit_of(s1p.bits, i) end
  if bank == 1 then return string.byte(s1p.bytes or "", i + 1) or 0 end
  if bank == 9 then return bit_of(s1p.soccer, i) end
  return 0
end

function InaRogue.Slot.S1pChron(kind, i)
  if not ON then return nil end
  kind, i = int(kind) or -1, int(i) or -1
  local arr = s1p and ({ [0] = s1p.clear, [1] = s1p.lock, [2] = s1p.new })[kind]
  if type(arr) ~= "string" or i < 0 then return -1 end
  return string.byte(arr, i + 1) or -1
end

function InaRogue.Slot.S1pPhase(ch_arg, sub_arg)
  if not ON then return nil end
  local ch, sub = int(ch_arg), int(sub_arg)
  local explicit = ch and sub and ch >= 1 and ch <= 30 and sub >= 0 and sub < 10000
  local want_ch, want_sub
  if explicit then
    want_ch, want_sub = ch, sub
  elseif s1p then
    want_ch, want_sub = s1p.chapter, s1p.sub_phase
  end
  local function run()
    if not in_rogue() or not want_ch then return nil end
    local ok, st = pcall(VRFW.game.inarogue_phase_status)
    if not ok or type(st) ~= "number" or st < 0x10000 then return nil end
    local new = want_ch * 10000 + want_sub
    local from = explicit and "story completed, §25" or "from slot 1, read-only"
    local result
    for _, rec in ipairs({ PHASE_SAVED, PHASE_LIVE }) do
      local a = st + rec
      local och, osub = rd("u16", a), rd("u16", a + 2)
      if not och or not osub then return nil end
      if och > 30 then
        err(string.format("phase write refused: unexpected chapter %d at 0x%X", och, a))
        return nil
      end
      local old = och * 10000 + osub
      if explicit then
        for _, off in ipairs(PHASE_NEXT_FREE) do
          local p = a + off
          local pch, psub = rd("u16", p), rd("u16", p + 2)
          if not pch or not psub then return nil end
          if pch <= 30 and pch * 10000 + psub < new and not (wr("u16", p, want_ch) and wr("u16", p + 2, want_sub)) then return nil end
        end
      end
      local name = rec == PHASE_SAVED and "saved" or "live"
      local r
      if new > old then
        if not (wr("u16", a, want_ch) and wr("u16", a + 2, want_sub)) then return nil end
        info(string.format("INAROGUE save story phase (%s record) %d -> %d (%s)", name, old, new, from))
        r = { old, new }
      else
        r = { old, old }
      end
      result = result or r
    end
    return result
  end
  local r = run() or { 0, 0 }
  return r[1], r[2]
end

-- ------------------------------------------------------------------------------------------------ filters

-- «avatar created» / «title tutorial seen» read as set in the INAROGUE save
function InaRogue.Slot.AvatarFlag(id)
  if not ON or not in_rogue() then return false end
  id = int(id)
  if id ~= FLAG_AVATAR_DONE and id ~= FLAG_TITLE_TUTORIAL_SEEN then return false end
  return true, true
end

-- the first-run team step is done in the INAROGUE save
function InaRogue.Slot.FirstRun(k)
  if not ON or not in_rogue() or int(k) ~= 1 then return false end
  return true, false
end

-- only INAROGUE, its squad screen («Mi equipo») and the options run in the INAROGUE save
function InaRogue.Slot.TitleRequest(id)
  if not ON or not in_rogue() then return false end
  id = int(id) or 0
  if id == TITLE_REQUEST_OPTIONS or id == 0 then return false end
  if id == TITLE_REQUEST_MY_TEAM then
    info(string.format("INAROGUE save: title request %d (Plantilla de equipo, the INAROGUE squad) allowed", id))
    return false
  end
  warn(string.format("INAROGUE save: title request %d refused (only INAROGUE, its squad screen and the options run in slot %d)", id, ROGUE_SLOT))
  return true, false
end

if ON then
  info(string.format("Inazuma Fantasy on the VR-Framework slot service: INAROGUE slot %d (the save rules: scripts\\save_slots.lua)", ROGUE_SLOT))
end
