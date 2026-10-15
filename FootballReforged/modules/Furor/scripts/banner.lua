-- Furor › the timing of the «Fase de furor activa» entry banner (docs/game/mechanics/furor.md §3.4). When a team's furor
-- phase starts (signal furor.gauge.phase, the user's or the CPU's) the banner slides in from the left, stays, then
-- slides out to the right (config.toml enter_from / exit_to); the match HUD graft research/grafts/furor_banner asks CMND_FUROR_BANNER every frame and
-- draws it. Settings: config.toml [furor_banner]. Nothing runs at load but the settings read and the handlers.

Furor = Furor or {}

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if low and v < low then v = low end
  if high and v > high then v = high end
  return v
end

local RAW = (VRFW.files and VRFW.files.config and VRFW.files.config("furor_banner")) or {}
local SETTINGS = {
  in_ms = number_setting(RAW, "in_seconds", 0.35, 0, 10) * 1000,
  hold_ms = number_setting(RAW, "hold_seconds", 2.0, 0, 60) * 1000,
  out_ms = number_setting(RAW, "out_seconds", 0.35, 0, 10) * 1000,
  slide_units = number_setting(RAW, "slide_units", 3000, 0, 20000),
  top_units = number_setting(RAW, "top_units", 40, -2000, 2000),
  height_units = number_setting(RAW, "height_units", 56, 1, 1000),
  -- the side it comes from / goes to: -1 left, 1 right
  enter = (RAW.enter_from == "right") and 1 or -1,
  exit = (RAW.exit_to == "left") and -1 or 1,
}

local started_at = nil      -- VRFW.now() of the last phase start, nil = no banner

-- 0..1 eased (slow at both ends)
local function ease(t)
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  return t * t * (3 - 2 * t)
end

VRFW.on("signal:furor.gauge.phase", function(ev)
  started_at = VRFW.now()
  return nil
end)
VRFW.on("match_start", function(ev) started_at = nil return nil end)
VRFW.on("match_end", function(ev) started_at = nil return nil end)

-- CMND_FUROR_BANNER() -> shown, offset (0 in place, -1 fully off to the left .. 1 fully off to the right), slide_units,
-- top_units, height_units
function Furor.Banner()
  local s = SETTINGS
  if started_at == nil then
    return false, 1, s.slide_units, s.top_units, s.height_units
  end
  local t = VRFW.now() - started_at
  local offset
  if t < s.in_ms then
    offset = s.enter * (1 - ease(t / s.in_ms))
  elseif t < s.in_ms + s.hold_ms then
    offset = 0
  elseif t < s.in_ms + s.hold_ms + s.out_ms then
    offset = s.exit * ease((t - s.in_ms - s.hold_ms) / s.out_ms)
  else
    started_at = nil
    return false, 1, s.slide_units, s.top_units, s.height_units
  end
  return true, offset, s.slide_units, s.top_units, s.height_units
end

-- CMND_FUROR_HUD_DEBUG() -> 1 when config.toml [furor_hud] debug = true (the fire gauge HUD draws plain test bars)
local HUD_RAW = (VRFW.files and VRFW.files.config and VRFW.files.config("furor_hud")) or {}
local HUD_DEBUG = HUD_RAW.debug == true
function Furor.HudDebug()
  return HUD_DEBUG and 1 or 0
end

VRFW.log(string.format("furor banner: in %.2f s from the %s, hold %.2f s, out %.2f s to the %s, slide %d units",
  SETTINGS.in_ms / 1000, SETTINGS.enter < 0 and "left" or "right", SETTINGS.hold_ms / 1000, SETTINGS.out_ms / 1000,
  SETTINGS.exit < 0 and "left" or "right", SETTINGS.slide_units))
