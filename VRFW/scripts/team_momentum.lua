-- Team momentum: a team gauge (a per = "team" match resource) filled by time and by match events, with levels and a phase started at full.
-- Declarations: every active mod's content\team_momentum\*.toml (VRFW.team_momentum/1, content\types\team_momentum.toml); docs/framework/team-momentum.md.
-- Effects are rule responses: rule flags <key>.<side>.full / .phase / .level<N> (side = user / rival) and signals <key>.full / .phase / .phase_end / .level (actor = a player of that team).
-- A player who comes on by substitution during his team's phase gets the signal <key>.phase_join (actor = him): the phase's effects for him alone.
-- A phase ends when the gauge is empty, at half time and at the match end (signal <key>.phase_end each time).
-- A phase starts on the signal <key>.start (its actor's team) or CMND_VRFW_TEAM_MOMENTUM_START(key, side); it drains the gauge to 0 over phase_seconds of live play.

TeamMomentum = TeamMomentum or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("team_momentum:", ...) end
local function warn(...) VRFW.warn("team_momentum:", ...) end

local LIST = {}            -- momentums in load order
local BY_KEY = {}          -- key -> momentum
local GAINS = {}           -- trigger text -> { { momentum, to, amount } }
local HANDLES = {}         -- team -> a soccer actor handle seen this match
local SCORE = nil          -- { team 0, team 1 } at the last tick
local USER = nil           -- the user's team

local OPTION_REREAD_MS = 1000
local EPS = 1e-6

-- ---------------------------------------------------------------------------------------------- declarations

local function load_declarations()
  local schema, why = D.schema("team_momentum")
  if not schema then
    warn(why)
    return
  end
  local decls = D.load(schema, warn)
  for _, d in ipairs(decls) do
    if d.entry == "TeamMomentum" then
      if BY_KEY[d.key] then
        warn(string.format("%s: %s declared twice: the first one is kept", d.where, d.key))
      else
        local live = {}
        for _, s in ipairs(d.v.live_states or {}) do live[s] = true end
        local m = {
          key = d.key, resource = d.v.resource, option = d.v.option, fill = d.v.fill_per_s, behind = d.v.behind_per_s,
          live = live, levels = math.floor(d.v.levels), start_at = d.v.start_at, phase_seconds = d.v.phase_seconds,
          gains_in_phase = d.v.gains_in_phase, gain_count = 0, flags = {}, pending = { [0] = 0, [1] = 0 },
          team = { [0] = { cur = 0, max = 0, phase = false, level = 0, full = false }, [1] = { cur = 0, max = 0, phase = false, level = 0, full = false } },
          option_at = -1e18, option_on = true, was_on = nil,
        }
        LIST[#LIST + 1] = m
        BY_KEY[m.key] = m
      end
    end
  end
  for _, d in ipairs(decls) do
    if d.entry == "MomentumGain" then
      local key = d.v.momentum:find(".", 1, true) and d.v.momentum or (tostring(d.mod) .. "." .. d.v.momentum)
      local m = BY_KEY[key]
      local to = d.v.to
      if not m then
        warn(string.format("%s: momentum %s is not declared: left out", d.where, key))
      elseif to ~= "actor" and to ~= "other" and to ~= "both" then
        warn(string.format("%s: to = %q is not actor, other or both: left out", d.where, tostring(to)))
      else
        GAINS[d.v.on] = GAINS[d.v.on] or {}
        table.insert(GAINS[d.v.on], { momentum = m, to = to, amount = d.v.amount })
        m.gain_count = m.gain_count + 1
      end
    end
  end
end

-- ---------------------------------------------------------------------------------------------- helpers

local function enabled(m)
  if m.option == "" then return true end
  local now = VRFW.now()
  if now - m.option_at < OPTION_REREAD_MS then return m.option_on end
  m.option_at = now
  local ok, v = pcall(VRFW.option, m.option)
  local on = true
  if ok and v ~= nil then
    if type(v) == "boolean" then on = v else on = (tonumber(v) or 1) ~= 0 end
  end
  m.option_on = on
  return on
end

local function side_of(team)
  return team == USER and "user" or "rival"
end

local function remember(ev)
  local a = ev and ev.actor
  if a and a.handle and a.handle ~= 0 and a.team ~= nil and a.team <= 1 then HANDLES[a.team] = a.handle end
end

-- the handle that addresses a team's gauge: 0 = the user's team, else a player of that team seen this match
local function handle_of(team)
  if USER ~= nil and team == USER then return 0 end
  return HANDLES[team]
end

local function gauge_add(m, team, amount)
  local h = handle_of(team)
  if h == nil then return false end
  local ok, done, code = pcall(VRFW.resource.add, m.resource, h, amount)
  if ok and done then return true end
  if ok and code == -3 and h ~= 0 then HANDLES[team] = nil end
  return false
end

local function gauge_get(m, team)
  local h = handle_of(team)
  if h == nil then return nil end
  local ok, v = pcall(VRFW.resource.get, m.resource, h)
  if ok and type(v) == "table" and type(v.cur) == "number" then return v end
  return nil
end

local function set_flag(m, name, on)
  local value = on and 1 or 0
  if m.flags[name] == value then return end
  m.flags[name] = value
  if on then pcall(VRFW.set_flag, name, 1) else pcall(VRFW.clear_flag, name) end
end

local function signal(m, what, team)
  pcall(VRFW.signal, m.key .. "." .. what, HANDLES[team] or 0)
end

local function clear_flags(m)
  for name, value in pairs(m.flags) do
    if value ~= 0 then pcall(VRFW.clear_flag, name) end
  end
  m.flags = {}
end

local function end_phase(m, team, why)
  local t = m.team[team]
  if not t.phase then return end
  t.phase = false
  set_flag(m, m.key .. "." .. side_of(team) .. ".phase", false)
  signal(m, "phase_end", team)
  info(string.format("%s: T%d phase end (%s)", m.key, team, why))
end

local function start_phase(m, team, why)
  local t = m.team[team]
  if m.phase_seconds <= 0 or t.phase or not t.full then return false end
  t.phase, t.full = true, false
  set_flag(m, m.key .. "." .. side_of(team) .. ".full", false)
  set_flag(m, m.key .. "." .. side_of(team) .. ".phase", true)
  signal(m, "phase", team)
  info(string.format("%s: T%d phase start (%s, %.1f/%.0f)", m.key, team, why, t.cur, t.max))
  return true
end

local function reset_match(why)
  for _, m in ipairs(LIST) do
    clear_flags(m)
    m.pending = { [0] = 0, [1] = 0 }
    for team = 0, 1 do
      local t = m.team[team]
      t.cur, t.max, t.phase, t.level, t.full = 0, 0, false, 0, false
    end
  end
  HANDLES, SCORE = {}, nil
  if why and #LIST > 0 then info(why) end
end

local function behind(team)
  if not SCORE then return false end
  local own, other = SCORE[team + 1], SCORE[2 - team]
  return own ~= nil and other ~= nil and own < other
end

-- ---------------------------------------------------------------------------------------------- per frame

local function step(m, match, dt)
  local live = m.live[tonumber(match.soccer_state) or -1] == true and dt > 0 and dt < 1
  for team = 0, 1 do
    local t = m.team[team]
    local add = m.pending[team] or 0
    if live then
      if t.phase then
        add = add - (t.max > 0 and t.max or 0) / m.phase_seconds * dt
        if m.gains_in_phase then add = add + m.fill * dt end
      else
        add = add + m.fill * dt + (behind(team) and m.behind * dt or 0)
      end
    end
    if add ~= 0 then
      if gauge_add(m, team, add) then
        m.pending[team] = 0
      elseif not t.phase then
        m.pending[team] = add
      end
    end
    local v = gauge_get(m, team)
    if v then t.cur, t.max = v.cur, v.max end
    local side = side_of(team)
    if t.phase and t.cur <= EPS then end_phase(m, team, "empty") end
    local full = (not t.phase) and t.max > 0 and t.cur >= m.start_at * t.max - EPS
    if full ~= t.full then
      t.full = full
      set_flag(m, m.key .. "." .. side .. ".full", full)
      if full then signal(m, "full", team) end
    end
    if m.levels > 0 and t.max > 0 then
      local level = math.min(m.levels, math.floor(t.cur / t.max * m.levels + EPS))
      if level ~= t.level then
        for n = 1, m.levels do set_flag(m, m.key .. "." .. side .. ".level" .. n, level >= n) end
        if level > t.level then signal(m, "level", team) end
        info(string.format("%s: T%d level %d -> %d", m.key, team, t.level, level))
        t.level = level
      end
    end
  end
end

VRFW.on("tick", function(ev)
  if #LIST == 0 then return nil end
  local match = ev.match or {}
  if match.user_team ~= nil and match.user_team ~= USER then
    if USER ~= nil then reset_match("user team changed: gauges, flags and phases reset") end
    USER = match.user_team
  end
  if match.score then SCORE = { match.score[1], match.score[2] } end
  local dt = tonumber(match.dt) or 0
  for _, m in ipairs(LIST) do
    local on = enabled(m)
    if on ~= m.was_on then
      if m.was_on ~= nil then info(m.key, on and "switched on" or "switched off: no phase, no flags") end
      if not on then
        for team = 0, 1 do end_phase(m, team, "switched off") end
        clear_flags(m)
        for team = 0, 1 do m.team[team].level, m.team[team].full = 0, false end
      end
      m.was_on = on
    end
    if on then step(m, match, dt) end
  end
  return nil
end)

VRFW.on("match_start", function(ev) reset_match("match start: gauges, flags and phases reset") return nil end)
-- every running phase ends with its <key>.phase_end signal (its rules take the effects off), then the match resets
VRFW.on("match_end", function(ev)
  for _, m in ipairs(LIST) do
    for team = 0, 1 do end_phase(m, team, "match end") end
  end
  reset_match(nil)
  return nil
end)
-- half time (soccer state 11): a running phase ends there
VRFW.on("state_enter", function(ev)
  if tostring(ev.arg) ~= "11" then return nil end
  for _, m in ipairs(LIST) do
    for team = 0, 1 do end_phase(m, team, "half time") end
  end
  return nil
end)
VRFW.on("possession", function(ev) remember(ev) return nil end)
VRFW.on("select", function(ev) remember(ev) return nil end)

-- ---------------------------------------------------------------------------------------------- gains

-- the team an event counts for: the actor's team; a goal: the team whose score rose (an own goal counts for the other side)
local function event_team(ev)
  local team = ev.actor and ev.actor.team
  if ev.trigger == "goal" and ev.match and ev.match.score then
    if SCORE then
      for t = 0, 1 do
        if (ev.match.score[t + 1] or 0) > (SCORE[t + 1] or 0) then team = t end
      end
    end
    SCORE = { ev.match.score[1], ev.match.score[2] }
  end
  if team == nil or team > 1 then return nil end
  return team
end

local function gain_teams(team, to)
  if to == "other" then return { 1 - team } end
  if to == "both" then return { 0, 1 } end
  return { team }
end

local function on_gain(on)
  return function(ev)
    remember(ev)
    local team = event_team(ev)
    if team == nil then return nil end
    for _, g in ipairs(GAINS[on]) do
      local m = g.momentum
      if enabled(m) then
        for _, t in ipairs(gain_teams(team, g.to)) do
          if m.gains_in_phase or not m.team[t].phase then
            if not gauge_add(m, t, g.amount) then m.pending[t] = (m.pending[t] or 0) + g.amount end
          end
        end
      end
    end
    return nil
  end
end

-- ---------------------------------------------------------------------------------------------- substitutions

local SUBSTITUTION_EVENT = 318   -- the effect event of a player coming on (Match.SubstitutionEvent's NotifyEffectEvent)

-- match:substitution post, once per player who comes on: args[1] = the effect event, args[2] = u32* his handle.
-- During his team's phase he joins it: the signal <key>.phase_join with him as the actor.
local function on_substitution(ev)
  local args = ev.args or {}
  if (tonumber(args[1]) or 0) % 4294967296 ~= SUBSTITUTION_EVENT then return nil end
  local ptr = (tonumber(args[2]) or 0) % 18446744073709551616
  if ptr < 0x10000 then return nil end
  local ok, hdl = pcall(VRFW.mem.read, "u32", ptr)
  hdl = ok and (tonumber(hdl) or 0) % 4294967296 or 0
  if hdl == 0 then return nil end
  local found, actor = pcall(VRFW.actor, hdl)
  local team = found and type(actor) == "table" and actor.team or nil
  if team == nil or team > 1 then return nil end
  HANDLES[team] = hdl
  for _, m in ipairs(LIST) do
    if m.team[team].phase and enabled(m) then
      pcall(VRFW.signal, m.key .. ".phase_join", hdl)
      info(string.format("%s: T%d player 0x%08X came on during the phase: joins it", m.key, team, hdl))
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------------- commands

local function team_of_side(side)
  side = tonumber(side) or -1
  if side == 0 or side == 1 then return side end
  if USER == nil then return nil end
  if side == -2 then return 1 - USER end
  return USER
end

-- CMND_VRFW_TEAM_MOMENTUM(key, side) -> ok, ratio (0..1), phase (0/1), level, team, user (0/1), full (0/1); side 0 / 1, -1 the user's team, -2 the rival's
function TeamMomentum.Get(key, side)
  local m = BY_KEY[tostring(key)]
  if not m or not enabled(m) or not VRFW.in_match() then return false end
  local team = team_of_side(side)
  if team == nil then return false end
  local t = m.team[team]
  local ratio = t.max > 0 and math.max(0, math.min(1, t.cur / t.max)) or 0
  return true, ratio, t.phase and 1 or 0, t.level, team, team == USER and 1 or 0, t.full and 1 or 0
end

-- CMND_VRFW_TEAM_MOMENTUM_START(key, side) -> started; the phase of that team when its gauge is full
function TeamMomentum.Start(key, side)
  local m = BY_KEY[tostring(key)]
  if not m or not enabled(m) or not VRFW.in_match() then return false end
  local team = team_of_side(side)
  if team == nil then return false end
  return start_phase(m, team, "command")
end

-- ---------------------------------------------------------------------------------------------- load

load_declarations()
for on in pairs(GAINS) do
  local ok, e = pcall(VRFW.on, on, on_gain(on))
  if not ok then warn(string.format("gain trigger %q: %s: left out", on, tostring(e))) end
end
for _, m in ipairs(LIST) do
  local ok, e = pcall(VRFW.on, "signal:" .. m.key .. ".start", function(ev)
    remember(ev)
    local team = ev.actor and ev.actor.team
    if team ~= nil and team <= 1 and enabled(m) then start_phase(m, team, "signal") end
    return nil
  end)
  if not ok then warn(m.key, "start signal:", tostring(e)) end
  info(string.format("%s: gauge %s, %d gains, %d levels, %s", m.key, m.resource, m.gain_count, m.levels,
    m.phase_seconds > 0 and string.format("phase from %.0f %% for %.0f s", m.start_at * 100, m.phase_seconds) or "no phase"))
end
local has_phase = false
for _, m in ipairs(LIST) do
  if m.phase_seconds > 0 then has_phase = true end
end
if has_phase then
  local ok, e = pcall(VRFW.on, "match:substitution:post", on_substitution)
  if not ok then warn("substitution event:", tostring(e)) end
end
