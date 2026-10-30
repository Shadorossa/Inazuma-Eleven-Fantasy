-- Stoppage Time (a module of Football Reforged; docs/game/mods/stoppage-time.md): added time at the end of every
-- half, from what happened in it, and play-on while a team attacks when the time runs out. Settings: config.toml.
-- The mechanisms are the VR-Framework's period service (docs/framework/rules.md §3.2 time_up):
-- * the engine ends a period when int(clock) >= its length + its added time (InPlayState::Update); the added time is
--   VRFW.match.set_added(seconds); VRFW.match.end_period() ends it at the next open-play frame.
-- * time_up:regular fires 2 game s before the regular length, time_up:end 2 game s before length + added time.
-- Everything here runs on events: the half's events add seconds (foul, cutin_start of a technique group, keeper_scene,
-- goal, match:substitution); time_up:regular turns them into whole minutes, sets the added time and shows the «+N»
-- telop (CMND_STOPPAGETIME_TELOP, asked by the match HUD: assets\lua\_all\stoppage_time_telop.lua); time_up:end
-- checks the team with the ball: in its attacking zone, the added time grows by the play-on limit and the half ends
-- with the play (possession to the rival, a goal, a foul, an end state such as OutOfPlay).

StoppageTime = StoppageTime or {}

require "VRFW/lib/basics"
local info = VRFW.logger("stoppage_time")

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if low and v < low then v = low end
  if high and v > high then v = high end
  return v
end

local function list_setting(t, k, default)
  local v = t and t[k]
  if type(v) ~= "table" then return default end
  return v
end

local function config(name)
  local t = VRFW.config(name)
  return type(t) == "table" and t or {}
end

local RAW = config("stoppage_time")
local RAW_PLAY_ON = config("play_on")
local RAW_TELOP = config("telop")
local SECONDS = type(RAW.seconds) == "table" and RAW.seconds or {}
local TECHNIQUE = type(RAW.technique) == "table" and RAW.technique or {}

local function set_of(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

local SETTINGS = {
  halves = set_of(list_setting(RAW, "halves", { 1, 2, 3, 4 })),
  round_up = RAW.rounding == "up",
  min_minutes = number_setting(RAW, "min_minutes", 1, 0, 60),
  max_minutes = number_setting(RAW, "max_minutes", 5, 0, 60),
  blocked_modes = list_setting(RAW, "blocked_modes", { "story" }),
  blocked_states = list_setting(RAW, "blocked_states", { "match.challenge.active", "match.training" }),
  log = RAW.log ~= false,
  seconds = {
    foul = number_setting(SECONDS, "foul", 15, 0, 600),
    technique = number_setting(SECONDS, "technique", 5, 0, 600),
    keeper_scene = number_setting(SECONDS, "keeper_scene", 5, 0, 600),
    goal = number_setting(SECONDS, "goal", 30, 0, 600),
    substitution = number_setting(SECONDS, "substitution", 20, 0, 600),
  },
  technique_groups = set_of(list_setting(TECHNIQUE, "groups", { "shot", "dribble", "defense" })),
  play_on = RAW_PLAY_ON.enabled ~= false,
  play_on_max = number_setting(RAW_PLAY_ON, "max_seconds", 30, 0, 600),
  play_on_real = RAW_PLAY_ON.max_seconds_unit ~= "game",
  zone_from = number_setting(RAW_PLAY_ON, "attack_zone_from", 0.5, 0, 1),
  end_states = list_setting(RAW_PLAY_ON, "end_states", { 12, 17 }),
  telop = RAW_TELOP.enabled ~= false,
  telop_ms = number_setting(RAW_TELOP, "hold_seconds", 3, 0.5, 30) * 1000,
  telop_x = number_setting(RAW_TELOP, "offset_x", 0, -5000, 5000),
  telop_y = number_setting(RAW_TELOP, "offset_y", 0, -5000, 5000),
}
SETTINGS.min_minutes, SETTINGS.max_minutes = math.floor(SETTINGS.min_minutes), math.floor(SETTINGS.max_minutes)
if SETTINGS.max_minutes < SETTINGS.min_minutes then SETTINGS.max_minutes = SETTINGS.min_minutes end

local function log(...)
  if SETTINGS.log then info(...) end
end

-- the half being counted
local S = {
  half = nil,          -- its number (1-4), nil = none yet
  counting = false,    -- its events add seconds (from its kick-off to the regular end)
  total = 0,           -- game seconds its events added
  counts = {},         -- events by kind
  announced = nil,     -- the minutes set at the regular end
  play_on = nil,       -- { team, since } while the play goes on past the added time
  play_on_done = false,
  last_owner = nil,    -- { team, handle } of the last ball owner (a loose ball's attacking team)
  telop_until = nil,   -- VRFW.now() when the telop goes, nil = none
  telop_text = "",
}

local function period()
  local ok, p = pcall(VRFW.match.period)
  return (ok and type(p) == "table") and p or nil
end

local function blocked()
  for _, k in ipairs(SETTINGS.blocked_modes) do
    local ok, on = pcall(VRFW.mode_is, k)
    if ok and on then return "mode " .. k end
  end
  for _, k in ipairs(SETTINGS.blocked_states) do
    local ok, v = pcall(VRFW.state, k)
    if ok and v ~= nil and v ~= false and v ~= 0 then return "state " .. k end
  end
  return nil
end

-- a new half: its count starts (only in a period that gets added time)
local function start_half(p)
  S.half, S.total, S.counts = p.half, 0, {}
  S.announced, S.play_on, S.play_on_done = nil, nil, false
  S.last_owner = nil
  local why = nil
  if not SETTINGS.halves[p.half] then
    why = "half not in halves"
  else
    why = blocked()
  end
  S.counting = why == nil
  if why then
    log(string.format("half %d: no added time (%s)", p.half, why))
  end
end

-- the period now, the half being counted (a half not seen at its kick-off starts its count here)
local function current()
  local p = period()
  if p == nil then return nil end
  if S.half ~= p.half then start_half(p) end
  return p
end

local function add(kind)
  if not S.counting then return end
  local p = period()
  if p == nil or p.half ~= S.half or p.clock >= p.length then return end
  S.total = S.total + SETTINGS.seconds[kind]
  S.counts[kind] = (S.counts[kind] or 0) + 1
end

local function minutes_of(total)
  local m = total / 60
  m = SETTINGS.round_up and math.ceil(m - 1e-9) or math.floor(m + 0.5)
  if m < SETTINGS.min_minutes then m = SETTINGS.min_minutes end
  if m > SETTINGS.max_minutes then m = SETTINGS.max_minutes end
  return m
end

local function summary()
  local parts = {}
  for _, k in ipairs({ "foul", "technique", "keeper_scene", "goal", "substitution" }) do
    if S.counts[k] then parts[#parts + 1] = string.format("%s %d", k, S.counts[k]) end
  end
  return #parts > 0 and table.concat(parts, ", ") or "no events"
end

local function telop_text(minutes)
  local ok, t = pcall(VRFW.text, VRFW.mod .. ".telop_added_time")
  if not ok or type(t) ~= "string" or t == "" then t = "+{minutes}" end
  return (t:gsub("{minutes}", tostring(minutes)))
end

-- the pitch fraction (0 own goal .. 1 the goal it attacks) of x, z for `team`, nil = no pitch data
local function attack_fraction(team, x, z)
  local ok_own, ox, oz = pcall(VRFW.ai.own_goal, team)
  local ok_rival, rx, rz = pcall(VRFW.ai.own_goal, 1 - team)
  if not (ok_own and ox and ok_rival and rx) then return nil end
  local ax, az = rx - ox, rz - oz
  local len2 = ax * ax + az * az
  if len2 <= 0 then return nil end
  return ((x - ox) * ax + (z - oz) * az) / len2
end

-- the attacking side now: team, x, z of the ball's owner, or of the last owner while the ball is loose (a pass, a shot)
local function attacker()
  local ok, hdl, team, x, z = pcall(VRFW.ai.ball)
  if ok and hdl and team and x and z then return team, x, z, "carrier" end
  local last = S.last_owner
  if last == nil then return nil end
  local okp, players = pcall(VRFW.ai.players, last.team)
  if not okp or type(players) ~= "table" then return nil end
  for _, pl in ipairs(players) do
    if pl.handle == last.handle then return last.team, pl.x, pl.z, "last owner" end
  end
  return nil
end

local function finish(why)
  if S.play_on == nil then return end
  local ok, done = pcall(VRFW.match.end_period)
  log(string.format("half %s: play-on over (%s): end of the half %s", tostring(S.half), why,
    (ok and done) and "asked" or "NOT asked"))
  S.play_on = nil
end

-- ---------------------------------------------------------------- events

VRFW.on("match_start", function()
  S.half, S.counting, S.play_on, S.telop_until = nil, false, nil, nil
  return nil
end)
VRFW.on("match_end", function()
  S.half, S.counting, S.play_on, S.telop_until = nil, false, nil, nil
  return nil
end)

-- each kick-off: a new half starts its count
VRFW.on("state_enter:9", function()
  current()
  return nil
end)

-- the half-time break: nothing counts until the next kick-off
VRFW.on("state_enter:11", function()
  S.counting = false
  S.play_on = nil
  return nil
end)

VRFW.on("foul", function()
  add("foul")
  finish("foul")
  return nil
end)

VRFW.on("goal", function()
  add("goal")
  finish("goal")
  return nil
end)

VRFW.on("cutin_start", function(ev)
  if SETTINGS.technique_groups[ev.arg] then add("technique") end
  return nil
end)

VRFW.on("keeper_scene", function()
  add("keeper_scene")
  return nil
end)

VRFW.on("match:substitution:post", function()
  add("substitution")
  return nil
end)

VRFW.on("possession", function(ev)
  local a = ev.actor
  if a == nil or a.team == nil then return nil end
  S.last_owner = { team = a.team, handle = a.handle }
  if S.play_on ~= nil and a.team ~= S.play_on.team then finish("the rival won the ball") end
  return nil
end)

for _, st in ipairs(SETTINGS.end_states) do
  local n = tonumber(st)
  if n then
    VRFW.on("state_enter:" .. math.floor(n), function()
      finish("state " .. math.floor(n))
      return nil
    end)
  end
end

-- the regular time ends: the added time and its telop
VRFW.on("time_up:regular", function()
  local p = current()
  if p == nil or not S.counting or S.announced then return nil end
  S.counting = false
  local minutes = minutes_of(S.total)
  local want = minutes * 60
  local wrote = true
  if want > p.added then
    local ok, done = pcall(VRFW.match.set_added, want)
    wrote = ok and done == true
  end
  S.announced = minutes
  if SETTINGS.telop and minutes > 0 then
    S.telop_text = telop_text(minutes)
    S.telop_until = VRFW.now() + SETTINGS.telop_ms
  end
  log(string.format("half %d: +%d min (%.0f s of events: %s; added time %d -> %d game s, write %s)", p.half, minutes,
    S.total, summary(), p.added, math.max(want, p.added), tostring(wrote)))
  return nil
end)

-- the added time runs out: play-on while the team with the ball attacks
VRFW.on("time_up:end", function()
  local p = current()
  if p == nil or S.announced == nil or not SETTINGS.play_on or S.play_on_done then return nil end
  -- only at the end itself (length + added time, the trigger's 2 s lead)
  if p.clock < p.length + p.added - 3 then return nil end
  if S.play_on ~= nil then
    log(string.format("half %d: play-on limit reached", p.half))
    S.play_on, S.play_on_done = nil, true
    return nil
  end
  S.play_on_done = true
  local team, x, z, whose = attacker()
  if team == nil then
    log(string.format("half %d: time up, nobody attacking (loose ball, no owner seen)", p.half))
    return nil
  end
  local f = attack_fraction(team, x, z)
  if f == nil or f < SETTINGS.zone_from then
    log(string.format("half %d: time up, team %d not in its attacking zone (%s at %s of the pitch, zone from %.2f)",
      p.half, team, whose, f and string.format("%.2f", f) or "?", SETTINGS.zone_from))
    return nil
  end
  local extra = SETTINGS.play_on_max * ((SETTINGS.play_on_real and p.rate and p.rate > 0) and p.rate or 1)
  extra = math.ceil(extra)
  local ok, done = pcall(VRFW.match.set_added, p.added + extra)
  if ok and done then
    S.play_on = { team = team }
    S.play_on_done = false
  end
  log(string.format("half %d: time up while team %d attacks (%s at %.2f of the pitch): play-on, at most %d game s more (write %s)",
    p.half, team, whose, f, extra, tostring(ok and done)))
  return nil
end)

-- ---------------------------------------------------------------- the telop (asked every frame by the match HUD)

-- CMND_STOPPAGETIME_TELOP() -> shown, text, offset_x, offset_y
function StoppageTime.Telop()
  local untl = S.telop_until
  if untl == nil then return false, "", 0, 0 end
  if VRFW.now() >= untl then
    S.telop_until = nil
    return false, "", 0, 0
  end
  return true, S.telop_text, SETTINGS.telop_x, SETTINGS.telop_y
end

info(string.format("loaded: %s, %g-%g min, play-on %s (zone from %.2f, at most %g %s s), telop %s",
  table.concat((function()
    local t = {}
    for _, k in ipairs({ "foul", "technique", "keeper_scene", "goal", "substitution" }) do
      t[#t + 1] = string.format("%s %gs", k, SETTINGS.seconds[k])
    end
    return t
  end)(), ", "), SETTINGS.min_minutes, SETTINGS.max_minutes, tostring(SETTINGS.play_on), SETTINGS.zone_from,
  SETTINGS.play_on_max, SETTINGS.play_on_real and "real" or "game", tostring(SETTINGS.telop)))
