-- Utilities › «Segundos por minuto de partido» (options.toml row utilities.match_clock): how many REAL seconds one
-- minute of the match clock lasts. Value 0 = «Original»: nothing is written, the game's own rate stays.
--
-- The match clock (CSceneSoccer +0x2208, game seconds of the half) advances by rate × dt, rate = the match info's
-- +0x10 (game seconds per real second; set by the game from game_param soccerElapsedTimeRate_Normal / _Slow, 14.1 /
-- 12 on v7.1.2, i.e. 4.26 / 5.0 real s per game minute). At each match start and each kick-off (InPlay entered)
-- this script sets that rate so a game minute lasts the chosen seconds at the game's normal speed:
--   rate = current rate × (60 / chosen) / game_rate        (config.toml [match_clock] game_rate = the normal rate)
-- so the normal speed gives exactly 60 / chosen and any other rate the game or a mode set (the slow speed, a
-- mode's own clock) keeps its proportion. The half length in game seconds is untouched; everything that converts
-- with the match info's rate (the elapsed real time, VRFW's match resources per_match) follows it. A rate already
-- written for this match is never scaled twice. One log line per change.

local OPTION = "match_clock"
local RATE_AT = 0x10

local function info(...) VRFW.log("match_clock:", ...) end

local function config_rate()
  local ok, v = pcall(VRFW.files.config, "match_clock.game_rate")
  if ok and type(v) == "number" and v > 0 then
    return v
  end
  return 14.1
end
local GAME_RATE = config_rate()

-- the chosen seconds per game minute (0 = «Original»)
local function chosen()
  local ok, values = pcall(VRFW.options.values)
  local v = ok and type(values) == "table" and tonumber(values[OPTION]) or 0
  return (v and v > 0) and v or 0
end

local last = nil   -- { info = match info address, written = the rate this script wrote (as read back) }

local function apply(why)
  local s = chosen()
  if s <= 0 then
    return
  end
  local okm, mi = pcall(VRFW.game.util_match_info)
  if not okm or type(mi) ~= "number" or mi < 0x10000 then
    return
  end
  local okr, cur = pcall(VRFW.mem.read, "f32", mi + RATE_AT)
  if not okr or type(cur) ~= "number" or cur <= 0 then
    return
  end
  if last ~= nil and last.info == mi and math.abs(cur - last.written) < 1e-4 then
    return   -- ours already
  end
  local want = cur * (60 / s) / GAME_RATE
  if not pcall(VRFW.mem.write, "f32", mi + RATE_AT, want) then
    return
  end
  local okb, back = pcall(VRFW.mem.read, "f32", mi + RATE_AT)
  last = { info = mi, written = (okb and type(back) == "number") and back or want }
  info(string.format("%s: clock rate %.4f -> %.4f game s per real s (%.1f real s per game minute at the normal speed; game rate %.2f)",
    why, cur, last.written, s, GAME_RATE))
end

VRFW.on("match_start", function()
  last = nil
  pcall(apply, "match start")
end)

-- each kick-off (the game may set the rate again for a half or a restart)
VRFW.on("state_enter:9", function()
  pcall(apply, "kick-off")
end)

info(string.format("loaded: %s (game rate %.2f)", chosen() > 0 and string.format("%.1f real s per game minute", chosen()) or "Original (the game's rate)", GAME_RATE))
