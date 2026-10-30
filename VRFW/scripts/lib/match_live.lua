-- Live match helpers for mod scripts: which soccer states are open play, live time steps, period timers and the
-- match's minute / score / half / state changes.
--   local Live = require "VRFW/lib/match_live"
-- The state groups come from content\defaults\match_states.toml (the last loaded mod's file wins).
--   Live.is_live(m[, set])     -> m.soccer_state is open play (m = ev.match; set = a { [state] = true } of the caller)
--   Live.in_play(m)            -> m.soccer_state is plain open play (no duel, no zone)
--   Live.is_duel(m)            -> m.soccer_state is a duel
--   Live.live_dt(m[, set])     -> the frame's time step while the ball is live (0 < dt < 1), else 0
--   Live.states()              -> { live = { [state] = true }, duel = { [state] = true }, in_play, goal, restart }
--   Live.state_set(list, default) -> a { [state] = true } of a list of states (default: the live states)
--   Live.timer(seconds)        -> a period timer: t:step(dt) = whole periods completed by dt; t:reset()
--   Live.watch()               -> a change watcher: w:step(m) = { any, half, minute, score, state } flags of what
--                                 changed (all true on the first step and after w:reset())
--   Live.score(m)              -> user, rival goals (nil, nil when the user side or the score is unknown)
--   Live.minute(m)             -> the match clock's whole minute, nil when unknown
--   Live.on(kind, fn)          -> fn(m, ev) when kind ("minute", "score", "half", "state") changes; top level only
--   Live.every(seconds, fn[, opts]) -> fn(m, ev) every `seconds` of match time (opts.live = only live time,
--                                 the default); top level only

local Live = {}

local DEFAULTS = { live = { 9, 14, 15, 16 }, duel = { 14, 15 }, in_play = 9, goal = 13, restart = 10 }
local STATES_FILE = "content/defaults/match_states.toml"

local states = nil

local function set_of(list)
  local s = {}
  for _, v in ipairs(type(list) == "table" and list or {}) do
    local n = tonumber(v)
    if n then s[math.floor(n)] = true end
  end
  return s
end

local function load_states()
  local raw = {}
  local ok, files = pcall(VRFW.files.declarations, STATES_FILE)
  if ok and type(files) == "table" then
    for _, f in ipairs(files) do
      if type(f.data) == "table" then raw = f.data end
    end
  end
  local function one(k) return math.floor(tonumber(raw[k]) or DEFAULTS[k]) end
  return {
    live = set_of(type(raw.live) == "table" and raw.live or DEFAULTS.live),
    duel = set_of(type(raw.duel) == "table" and raw.duel or DEFAULTS.duel),
    in_play = one("in_play"),
    goal = one("goal"),
    restart = one("restart"),
  }
end

function Live.states()
  if not states then states = load_states() end
  return states
end

function Live.state_set(list, default)
  if type(list) == "table" then return set_of(list) end
  return default or Live.states().live
end

local function state_of(m)
  return type(m) == "table" and tonumber(m.soccer_state) or nil
end

function Live.is_live(m, set)
  local st = state_of(m)
  return st ~= nil and (set or Live.states().live)[st] == true
end

function Live.in_play(m)
  local st = state_of(m)
  return st ~= nil and st == Live.states().in_play
end

function Live.is_duel(m)
  local st = state_of(m)
  return st ~= nil and Live.states().duel[st] == true
end

function Live.live_dt(m, set)
  local dt = type(m) == "table" and tonumber(m.dt) or 0
  if dt > 0 and dt < 1 and Live.is_live(m, set) then return dt end
  return 0
end

function Live.minute(m)
  local c = type(m) == "table" and tonumber(m.clock) or nil
  return c and math.floor(c / 60) or nil
end

function Live.score(m)
  if type(m) ~= "table" or type(m.score) ~= "table" then return nil, nil end
  local us = m.user_team
  if us ~= 0 and us ~= 1 then return nil, nil end
  return tonumber(m.score[us + 1]), tonumber(m.score[2 - us])
end

-- ------------------------------------------------------------------------------------------------ timers

local Timer = {}
Timer.__index = Timer

function Timer:step(dt)
  if not (dt and dt > 0) or self.seconds <= 0 then return 0 end
  self.acc = self.acc + dt
  local n = 0
  while self.acc >= self.seconds do
    self.acc = self.acc - self.seconds
    n = n + 1
  end
  return n
end

function Timer:reset()
  self.acc = 0
end

function Live.timer(seconds)
  return setmetatable({ seconds = tonumber(seconds) or 0, acc = 0 }, Timer)
end

-- ------------------------------------------------------------------------------------------------ change watcher

local Watch = {}
Watch.__index = Watch

local FIELDS = { "half", "minute", "score_user", "score_rival", "state" }

-- the flags table is reused by the next step
function Watch:step(m)
  local now, last, changed = self.now, self.last, self.changed
  now.half = type(m) == "table" and m.half or nil
  now.minute = Live.minute(m)
  now.score_user, now.score_rival = Live.score(m)
  now.state = state_of(m)
  changed.any, changed.half, changed.minute, changed.score, changed.state = false, false, false, false, false
  for _, k in ipairs(FIELDS) do
    if last[k] ~= now[k] or not self.seen then
      last[k] = now[k]
      changed.any = true
      if k == "score_user" or k == "score_rival" then changed.score = true else changed[k] = true end
    end
  end
  self.seen = true
  return changed
end

function Watch:reset()
  self.last, self.seen = {}, false
end

function Live.watch()
  return setmetatable({ last = {}, now = {}, changed = {}, seen = false }, Watch)
end

-- ------------------------------------------------------------------------------------------------ handlers

local listeners = nil   -- { kind = { fn, ... } }
local timers = nil      -- { { timer, fn, live }, ... }
local watcher = nil

local function on_tick(ev)
  local m = ev.match or {}
  if listeners then
    local changed = watcher:step(m)
    if changed.any then
      for kind, fns in pairs(listeners) do
        if changed[kind] then
          for _, fn in ipairs(fns) do fn(m, ev) end
        end
      end
    end
  end
  if timers then
    local dt = tonumber(m.dt) or 0
    for _, t in ipairs(timers) do
      local step = t.live and Live.live_dt(m) or ((dt > 0 and dt < 1) and dt or 0)
      for _ = 1, t.timer:step(step) do t.fn(m, ev) end
    end
  end
  return nil
end

local function ensure_tick()
  if listeners or timers then return end
  VRFW.on("tick", on_tick)
  VRFW.on("match_start", function()
    if watcher then watcher:reset() end
    for _, t in ipairs(timers or {}) do t.timer:reset() end
    return nil
  end)
end

local KINDS = { minute = true, score = true, half = true, state = true }

function Live.on(kind, fn)
  assert(KINDS[kind], "Live.on: kind must be minute, score, half or state")
  ensure_tick()
  listeners = listeners or {}
  watcher = watcher or Live.watch()
  listeners[kind] = listeners[kind] or {}
  table.insert(listeners[kind], fn)
end

function Live.every(seconds, fn, opts)
  ensure_tick()
  timers = timers or {}
  table.insert(timers, { timer = Live.timer(seconds), fn = fn, live = not (opts and opts.live == false) })
end

return Live
