-- Utilities › Chronicle route map speed (feature route_map_speed; docs/game/ui/chronicle-route-map-cursor.md).
-- The game: CMouseScrollBaseMenu's update moves the cursor by dir x dt x speed(+0x270, f32) x 50; R2 does nothing on
-- that map in the game (the zoom is the right stick / mouse wheel and stays as it is). While R2 (pad RT, or one of the
-- configured keys while the game window has the keyboard) is held, the speed is multiplied around the game's update
-- (hook RouteMapUpdate, content/game/route_map_speed.toml) and the game's value is put back right after.
-- config.toml [route_map_speed]: factor 1.0..5.0 (default 2.0), keys (default {"E"}), log (default true).

local SPEED_OFF = 0x270
local PAD_RT = 0x200
local FACTOR_MIN, FACTOR_MAX = 1.0, 5.0

local cfg = (VRFW.files and VRFW.files.config and VRFW.files.config("route_map_speed")) or {}

local NAMED = { SHIFT = 0x10, CTRL = 0x11, CONTROL = 0x11, ALT = 0x12, SPACE = 0x20, TAB = 0x09, LSHIFT = 0xA0, RSHIFT = 0xA1, LCTRL = 0xA2, RCTRL = 0xA3 }

-- a key name of the config ("E", "Shift", "0x45"...) -> Windows virtual key
local function vk_of(name)
  if type(name) ~= "string" then
    return nil
  end
  local n = string.upper((string.gsub(name, "^%s*(.-)%s*$", "%1")))
  local hex = string.match(n, "^0X(%x+)$")
  if hex then
    local v = tonumber(hex, 16)
    return (v and v >= 1 and v <= 0xFE) and v or nil
  end
  if #n == 1 and string.match(n, "[A-Z0-9]") then
    return string.byte(n)
  end
  return NAMED[n]
end

local factor = tonumber(cfg.factor) or 2.0
if factor ~= factor then
  factor = 2.0
end
if factor < FACTOR_MIN or factor > FACTOR_MAX then
  local c = math.min(math.max(factor, FACTOR_MIN), FACTOR_MAX)
  VRFW.warn(string.format("config.toml [route_map_speed]: factor %s out of %s..%s: %s", tostring(factor), FACTOR_MIN, FACTOR_MAX, c))
  factor = c
end
local keys = {}
for _, k in ipairs(type(cfg.keys) == "table" and cfg.keys or { "E" }) do
  local vk = vk_of(k)
  if vk then
    keys[#keys + 1] = vk
  else
    VRFW.warn("config.toml [route_map_speed]: key " .. tostring(k) .. " not known: ignored")
  end
end
local log = cfg.log ~= false

-- the hook runs every frame of the route map: its handler stays a pad read (+ one key query when keys are set),
-- with the API functions held as upvalues
local input_pad, input_key, band = VRFW.input.pad, VRFW.input.key, bit32.band
local n_keys = #keys
local key_args = n_keys > 0 and keys or nil

local function r2_held()
  local pad = input_pad()
  if pad and band(pad, PAD_RT) ~= 0 then
    return true
  end
  return key_args ~= nil and input_key(table.unpack(key_args, 1, n_keys))
end

-- the framework resolves its game globals (the pad's too) at the first read: read the pad once now (script load, not
-- the game thread) so the route map's first frame cannot pay for it (a one-off 196 ms call, log 2026-10-13 20:09)
pcall(input_pad)

local held = false
local saved -- { address, the game's speed } between the pre and post handlers

VRFW.on("hook:RouteMapUpdate", function(ev)
  local this = ev.args[1]
  local boost = this ~= 0 and r2_held()
  if not boost then
    if held and log then
      VRFW.log("R2 released: the route map cursor is back to the game's speed")
    end
    held = false
    return nil
  end
  local p = this + SPEED_OFF
  local ok, game = pcall(VRFW.mem.read, "f32", p)
  if not ok or game ~= game or game <= 0 then
    return nil
  end
  if not held and log then
    VRFW.log(string.format("R2 held on the route map: cursor speed %s x %s = %s", tostring(game), tostring(factor), tostring(game * factor)))
  end
  held = true
  if pcall(VRFW.mem.write, "f32", p, game * factor) then
    saved = { p, game }
  end
  return nil
end)

VRFW.on("hook:RouteMapUpdate:post", function()
  if saved then
    -- the game's value back (the base update only reads it)
    pcall(VRFW.mem.write, "f32", saved[1], saved[2])
    saved = nil
  end
  return nil
end)

function Utilities.RouteMapSpeedOn()
  return VRFW.is_on("RouteMapUpdate")
end
