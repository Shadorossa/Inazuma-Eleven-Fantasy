-- Field battle returns to the menus instead of the field map. Declarations: content\game\field_return.toml.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_BATTLE_RETURN (alias CMND_EVT_TRIAL_RETURN) | op: 1 arm (menu route + straight to the title, in-memory game kept), 3 arm (same, title rereads the save), 2 arm (menu route only), 0 disarm, -1 query | live, armed, taken |
-- While armed, the next pass at the «loaded field map?» test (hook FieldReturnSite) takes the VS / BB menu path and disarms.
-- Ops 1 / 3 also go straight to the title (no press-start screen, retail GameReset). A return to the title disarms.

FieldReturn = FieldReturn or {}

-- Byte offsets come from the game profile (structs.toml): Save.LoadedGuard = «save loaded» guard, Route.RpgNoPressStart = skip press-start.
-- A field that does not resolve, or a byte holding no flag, is not written.
local GUARD_FIELD, NO_PRESS_START_FIELD = "Save.LoadedGuard", "Route.RpgNoPressStart"
local GUARD_MAX, NO_PRESS_START_MAX = 5, 1   -- max values the game stores there (guard states 0..5, a bool)

local armed, to_title, keep_game, taken, titles = false, false, true, 0, 0

require "VRFW/lib/basics"
local info = VRFW.logger("field_return")

local function int(v, def)
  if type(v) == "boolean" then return v and 1 or 0 end
  if type(v) ~= "number" then return def end
  if v >= 0 then return math.floor(v) end
  return math.ceil(v)
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function live() return VRFW.is_on("FieldReturnSite") end
local function can_title() return VRFW.is_on("FieldReturnReset") end

-- Profile field offset (nil = not on this build).
local function field(name)
  local ok, off = pcall(VRFW.game.field, name)
  if ok and type(off) == "number" and off > 0 then return off end
  VRFW.warn(string.format("field_return: game profile field %s does not resolve (%s): not written", name,
    tostring(ok and VRFW.game.status(name) or off)))
  return nil
end

-- Writes base + field offset only when the byte there holds a value the game stores in it (<= max).
local function wr8(base, name, max, v)
  local off = base and field(name)
  if not off then return false end
  local at = base + off
  local ok, cur = pcall(VRFW.mem.read, "u8", at)
  if not ok or type(cur) ~= "number" or cur > max then
    VRFW.warn(string.format("field_return: %s holds %s (expected 0..%d): not written", name, tostring(cur), max))
    return false
  end
  return (pcall(VRFW.mem.write, "u8", at, v))
end

-- Inside SoccerState::Update after the match scene ended, before the RPG field state resumes. Same effect as the game's own back-to-title path (CMND_GAME_RESET).
-- Sets the guard and no-press-start, then GameReset; GameReset only queues scene requests, so no field frame runs.
local function go_title()
  local blk = global("field_return_play_data")
  local guard = wr8(blk, GUARD_FIELD, GUARD_MAX, keep_game and 1 or 0) and keep_game
  local rpg = global("field_return_rpg")
  local nps = wr8(rpg, NO_PRESS_START_FIELD, NO_PRESS_START_MAX, 1)
  titles = titles + 1
  info(string.format("match over -> straight to the title (GameReset #%d; in-memory game kept %s, no press-start %s): no field frame",
    titles, tostring(guard), tostring(nps)))
  local ok, err = pcall(VRFW.call, "FieldReturnReset")
  if not ok then VRFW.warn("field_return: GameReset failed: " .. tostring(err)) end
end

function FieldReturn.Command(op)
  op = int(op, -1)
  local was = armed
  if op >= 0 and op <= 3 then
    armed = op ~= 0
    to_title = (op == 1 or op == 3) and can_title()
    keep_game = op ~= 3
  end
  local on = live()
  info(string.format("CMND_VRFW_BATTLE_RETURN(%d) live %s armed %s -> %s (straight to the title %s, in-memory game kept %s) taken %d",
    op, tostring(on), tostring(was and on), tostring(armed and on), tostring(to_title), tostring(keep_game), taken))
  return on, armed and on, taken
end

-- The «loaded field map?» test of SoccerState::Update: armed = take the VS / BB menu path (skip to continue_at).
VRFW.on("hook:FieldReturnSite", function(ev)
  if not armed then return nil end
  armed = false
  taken = taken + 1
  if to_title then go_title() end
  return { skip = true }
end)

-- Any title return: nothing may stay armed.
VRFW.on("game_reset", function(ev)
  if armed then
    armed = false
    info("game reset: disarmed")
  end
end)
