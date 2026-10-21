-- Utilities › pre-match «hold X = straight to the kick-off» (graft research/grafts/util_prematch_skip,
-- docs/game/ui/prematch-skip.md): the answers of its game Lua commands (content\game\prematch_skip.toml).
-- Utilities' (better_ui.lua) until Utilities 1.17.0. Functions only: nothing runs at load but the handler
-- registrations (game_reset, hook:PrematchSecondEntrance).

-- The longest hold the pre-match X skip accepts (s); the default when config.toml has no usable value.
local SKIP_HOLD_MAX = 10.0
local SKIP_HOLD_DEFAULT = 1.0

-- CMND_UTIL_XSKIP_HOLD() -> the seconds X must be held in a pre-match event to go straight to the kick-off (graft
-- util_prematch_skip asks it when a pre-match event starts). config.toml [prematch_skip] `hold`: 0 or less = 0 (the
-- X prompt is off), more than 10 = 10, not a number = 1.
function Utilities.SkipHold()
  local v = VRFW.files.config("prematch_skip.hold")
  if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
    return SKIP_HOLD_DEFAULT
  end
  if v <= 0 then
    return 0
  end
  return math.min(v, SKIP_HOLD_MAX)
end

-- CMND_UTIL_XSKIP_COVER(on) -> 1 when done, 0 when the native hold is not available (content\game\prematch_skip.toml).
-- on = 1: the pre-match X skip's black cover (bright-fade layer 1) is held by the hook BrightFadeLayer until the kick-off
-- is ready (the table Utilities.XSkipCover gets the bright-fade object); any other value: released (the table cleared).
-- The graft util_prematch_skip asks for the hold once its own fade to black is over and releases it right before
-- its one fade in; a 0 answer keeps its Lua-only cover.
local COVER_TABLE = "Utilities.XSkipCover"
function Utilities.XSkipCover(on)
  VRFW.native.table_clear(COVER_TABLE)
  if on ~= 1 then
    return 1
  end
  if not VRFW.is_on("BrightFadeLayer") then
    return 0
  end
  local obj = VRFW.game.BrightFade()
  if type(obj) ~= "number" or obj == 0 then
    return 0
  end
  VRFW.native.table_set(COVER_TABLE, obj, 1)
  -- the bright fade is a 64-bit object address: never "%X" on it (Lua 5.2 formats through a 32-bit `long` on Windows;
  -- «not a non-negative number in proper range» switched the script off), the high and low halves go apart
  local hi = math.floor(obj / 2 ^ 32)
  VRFW.log(string.format("pre-match X skip: black cover held (bright fade 0x%X%08X, layer 1)", hi, obj - hi * 2 ^ 32))
  return 1
end


-- CMND_UTIL_XSKIP_JUMP(on) -> 1 when done, 0 when not possible (content\game\prematch_skip.toml, 1.21.7).
-- on = 1: the pre-match X skip's direct jump. The running event of the event manager (current slot) is ended in this
-- frame without the retail skip's fades: its sounds stopped (StopEventSounds, 0 s, the kept ones too, as the retail
-- skip does) and its timeline run to the end (EventSeek(slot, -1); TimelineSeek(tl, -1, 1) when the event has no cut
-- table). From then on the hook PrematchSecondEntrance keeps BattleSettingFlow from starting the second entrance event
-- (state 12 -> 13). Any other value: the jump is over (flag cleared). Every step is logged.
local EVM_CURRENT = 0x9154        -- event manager: current slot index (u32)
local EVM_SLOTS = 20
local EVM_STRIDE = 0x7E0
local SLOT_STATE = 0x508          -- u8: 1 load ... 8 playing, 10 finished
local SLOT_TIMELINE = 0x4E8       -- ptr: the event's timeline
local SLOT_CUTS = 0x5B0           -- ptr / u32 (+0x5B8): the cut table EventSeek needs
local SLOT_CUT_COUNT = 0x5B8
local SLOT_FREE_SEEK = 0x7C0      -- u8: seek allowed without a cut table
local SLOT_SKIP_TO = 0x7BC        -- f32: the retail skip's target (-1 = none)
local SLOT_NAME = 0x79C           -- char[32]
local TL_CLOCK = 0x40             -- f32: the timeline's clock (s)
local TL_STATE = 0x4B             -- u8: 1 loaded, 2 playing, 4 ended
local jump_on = false
local jumps = 0

local function hex64(v)            -- a 64-bit address as hex without "%X" on it (see XSkipCover)
  local hi = math.floor(v / 2 ^ 32)
  return string.format("0x%X%08X", hi, v - hi * 2 ^ 32)
end

local function slot_name(slot)
  local ok, bytes = pcall(VRFW.mem.read_array, "u8", slot + SLOT_NAME, 32)
  if not ok or type(bytes) ~= "table" then
    return "?"
  end
  local out = {}
  for i = 1, #bytes do
    if bytes[i] == 0 then
      break
    end
    out[#out + 1] = string.char(bytes[i])
  end
  return table.concat(out)
end

-- The current event's slot and timeline, or nil + why.
local function current_event()
  local mgr = VRFW.game.EventManager()
  if type(mgr) ~= "number" or mgr == 0 then
    return nil, "no event manager"
  end
  local idx = VRFW.mem.read("u32", mgr + EVM_CURRENT)
  if idx >= EVM_SLOTS then
    return nil, "current slot " .. idx .. " out of range"
  end
  local slot = mgr + idx * EVM_STRIDE
  local tl = VRFW.mem.read("ptr", slot + SLOT_TIMELINE)
  if tl == 0 then
    return nil, "slot " .. idx .. " has no timeline"
  end
  return slot, tl, idx
end

local function xskip_jump(on)
  if on ~= 1 then
    if jump_on then
      VRFW.log("pre-match X jump: over (kick-off reached / disarmed)")
    end
    jump_on = false
    return 1
  end
  local ok, slot, tl, idx = pcall(current_event)
  if not ok or slot == nil then
    VRFW.log("pre-match X jump: not possible (" .. tostring(ok and tl or slot) .. "): the graft uses the cover path")
    return 0
  end
  local state = VRFW.mem.read("u8", slot + SLOT_STATE)
  local tl_state = VRFW.mem.read("u8", tl + TL_STATE)
  local clock = VRFW.mem.read("f32", tl + TL_CLOCK)
  local name = slot_name(slot)
  if tl_state == 4 then
    VRFW.log(string.format("pre-match X jump: event %s (slot %d) already at its end: nothing to end", name, idx))
    jump_on = true
    return 1
  end
  jumps = jumps + 1
  VRFW.log(string.format("pre-match X jump [%d]: event %s (slot %d, state %d, timeline %d at %.2f s, slot %s)", jumps,
    name, idx, state, tl_state, clock, hex64(slot)))
  VRFW.call("StopEventSounds", slot, 0.0, 1)
  VRFW.log("pre-match X jump: event sounds stopped")
  local cuts = VRFW.mem.read("ptr", slot + SLOT_CUTS)
  local cut_count = VRFW.mem.read("u32", slot + SLOT_CUT_COUNT)
  local free = VRFW.mem.read("u8", slot + SLOT_FREE_SEEK)
  if (cuts ~= 0 and cut_count ~= 0) or free ~= 0 then
    VRFW.call("EventSeek", slot, -1.0)
    VRFW.log(string.format("pre-match X jump: EventSeek to the end (%d cut(s), free seek %d)", cut_count, free))
  else
    VRFW.call("TimelineSeek", tl, -1.0, 1)
    VRFW.log("pre-match X jump: no cut table: TimelineSeek to the end")
  end
  VRFW.mem.write("f32", slot + SLOT_SKIP_TO, -1.0)
  jump_on = true
  VRFW.log(string.format("pre-match X jump: event ended in this frame (timeline state %d): the flow goes on to the kick-off",
    VRFW.mem.read("u8", tl + TL_STATE)))
  return 1
end

-- A failing step answers 0 (the graft's cover path) instead of an error, which would switch this script off.
function Utilities.XSkipJump(on)
  local ok, r = pcall(xskip_jump, on)
  if ok then
    return r
  end
  VRFW.log("pre-match X jump: failed (" .. tostring(r) .. "): the graft uses the cover path")
  return 0
end

-- BattleSettingFlow state 12, before its «match info bit 0x80: one more entrance event» test: while the X jump is on,
-- skip = resume at its `mov dword [rsi+20h], 0Dh` (state 13: the lineups / kick-off), no second event.
VRFW.on("hook:PrematchSecondEntrance", function(ev)
  if not jump_on then
    return nil
  end
  local ok, st = pcall(VRFW.mem.read, "u32", ev.regs.rsi + 0x20)
  VRFW.log(string.format("pre-match X jump: second entrance event not started (flow state %s -> 13)",
    ok and tostring(st) or "?"))
  return { skip = true }
end)

-- Back to the title with the cover still held / the jump on (a pre-match left during the X skip): both released, so no
-- menu is held black and no later flow loses its second entrance event.
VRFW.on("game_reset", function()
  VRFW.native.table_clear(COVER_TABLE)
  jump_on = false
end)
