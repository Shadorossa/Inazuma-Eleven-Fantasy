-- Football Reforged › module «pressing»: the PRESS button (docs/game/mods/pressing.md). Settings: config.toml
-- [pressing]. The mechanisms are the VR-Framework's (docs/framework/ai-move.md): VRFW.ai.move / release (a player of
-- the game's AI runs to a target, at a sprint, for a moment), VRFW.ai.focus_field_gate (a team's focus field off
-- while it does not hold the ball), VRFW.input.on (the user's input commands).
--
-- * Without the ball neither team opens its focus field (the gate); with the ball the focus field is the game's.
-- * Your team without the ball: while L2 is held (hold_commands), 2 to 4 of your AI teammates nearest to the ball
--   carrier (the ones within band_m, at least min_players, at most max_players, nobody beyond range_m; never the
--   keeper, never the player you control, never a winded one) sprint at him. Release L2 or win the ball back: they are
--   the game's AI again.
-- * The CPU without the ball presses with the same rules when one of its [[pressing.cpu_rule]] holds (carrier near
--   its goal, in its half with a player close, several players close), for press_ms, then rests rest_ms.
-- * The sprint bar of Aura Points (aura_points.sprint): a winded player does not press; the pressers' sprint is the
--   game's dash, so it drains their bar like any dash. Without Aura Points nobody is winded.
-- * The HUD (docs/framework/ai-move.md §5, §6): while the rival holds the ball in open play, the L2 «¡Subid!» guide shows
--   «¡Presión!» (VRFW.hud.go_ahead_guide, the sprite hud_sprite of content\images\hud); when a press starts, each
--   of your pressers shows the game's «¡Subid!» arrows pointing at the carrier (VRFW.ai.arrow), for the game's
--   «¡Subid!» time or until his press ends.

Pressing = Pressing or {}
local P = Pressing

local function info(...) VRFW.log("pressing:", ...) end

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if low and v < low then v = low end
  if high and v > high then v = high end
  return v
end

local function text_setting(t, k, default)
  local v = t and t[k]
  if type(v) == "string" and v ~= "" then return v end
  return default
end

local function list_setting(t, k, default)
  local v = t and t[k]
  if type(v) ~= "table" then return default end
  local out = {}
  for _, x in ipairs(v) do
    if type(x) == "string" and x ~= "" then out[#out + 1] = x end
  end
  if #out == 0 then return default end
  return out
end

local RAW = (VRFW.files and VRFW.files.config and VRFW.files.config("pressing")) or {}
local SETTINGS = {
  min_players = math.floor(number_setting(RAW, "min_players", 2, 1, 10)),
  max_players = math.floor(number_setting(RAW, "max_players", 4, 1, 10)),
  band_m = number_setting(RAW, "band_m", 14, 0, 200),
  range_m = number_setting(RAW, "range_m", 32, 1, 200),
  sprint = RAW.sprint ~= false,
  order_ms = math.floor(number_setting(RAW, "order_ms", 300, 50, 5000)),
  chase = RAW.chase ~= false,
  sprint_resource = text_setting(RAW, "sprint_resource", "aura_points.sprint"),
  winded_state = text_setting(RAW, "winded_state", "winded"),
  min_sprint = number_setting(RAW, "min_sprint", 0, 0, 1),
  focus_field_gate = text_setting(RAW, "focus_field_gate", "off_ball"),
  hold_commands = list_setting(RAW, "hold_commands", { "CMD_GO_AHEAD_HOLD", "CMD_GO_AHEAD", "CMD_CATCH_BOMB" }),
  cpu = RAW.cpu ~= false,
  decide_ms = math.floor(number_setting(RAW, "decide_ms", 500, 50, 10000)),
  press_ms = math.floor(number_setting(RAW, "press_ms", 2500, 100, 30000)),
  rest_ms = math.floor(number_setting(RAW, "rest_ms", 1500, 0, 60000)),
  hud_sprite = text_setting(RAW, "hud_sprite", ""),
  arrows = text_setting(RAW, "arrows", "user"),
  cpu_rules = {},
}
if SETTINGS.max_players < SETTINGS.min_players then SETTINGS.max_players = SETTINGS.min_players end
if SETTINGS.arrows ~= "both" and SETTINGS.arrows ~= "off" then SETTINGS.arrows = "user" end
if SETTINGS.focus_field_gate ~= "off_ball" and SETTINGS.focus_field_gate ~= "always" then SETTINGS.focus_field_gate = "off" end
if type(RAW.cpu_rule) == "table" then
  for _, r in ipairs(RAW.cpu_rule) do
    if type(r) == "table" then
      SETTINGS.cpu_rules[#SETTINGS.cpu_rules + 1] = {
        carrier_to_own_goal_max_m = tonumber(r.carrier_to_own_goal_max_m),
        carrier_in_own_half = r.carrier_in_own_half == true,
        nearest_within_m = tonumber(r.nearest_within_m),
        ready_within_m = tonumber(r.ready_within_m),
        ready_count = math.floor(number_setting(r, "ready_count", 1, 1, 10)),
        chance = number_setting(r, "chance", 1, 0, 1),
      }
    end
  end
end
P.settings = SETTINGS

-- the soccer state of open play (the press runs only there)
local STATE_IN_PLAY = 9

-- per team: the handles pressing now (handle -> the carrier his arrows point at, or true); the CPU's press until /
-- rest until / next decision. owner: the team with the ball (nil = loose); last_owner: the last team that had it
-- (kept through passes and loose balls: the press guide on the HUD); hud: the press guide is shown.
local State = {
  team = {
    [0] = { pressers = {}, count = 0, cpu_until = 0, cpu_rest = 0, cpu_next = 0 },
    [1] = { pressers = {}, count = 0, cpu_until = 0, cpu_rest = 0, cpu_next = 0 },
  },
  gate_set = false,   -- the focus field gate is set for this match (the framework forgets it at a new match)
  owner = nil,
  last_owner = nil,
  hud = false,
}

local function hex(v) return string.format("0x%08X", v or 0) end

local function dist(ax, az, bx, bz)
  local dx, dz = ax - bx, az - bz
  return math.sqrt(dx * dx + dz * dz)
end

-- the sprint bar: winded (or below min_sprint) = no press; no such resource (Aura Points off) = never winded
local function winded(hdl)
  local key = SETTINGS.sprint_resource
  if not key or not VRFW.resource then return false end
  local ok, v = pcall(VRFW.resource.get, key, hdl)
  if not ok or type(v) ~= "table" then return false end
  local okw, w = pcall(VRFW.resource.state, key, hdl, SETTINGS.winded_state)
  if okw and w == true then return true end
  return SETTINGS.min_sprint > 0 and (tonumber(v.ratio) or 1) < SETTINGS.min_sprint
end

-- the team's players who may press, nearest to the carrier first: { hdl, d }
local function candidates(team, cx, cz)
  local ok, players = pcall(VRFW.ai.players, team)
  if not ok or type(players) ~= "table" then return {} end
  local list = {}
  for _, p in ipairs(players) do
    if not p.keeper and not p.controlled and not p.ball then
      local d = dist(p.x, p.z, cx, cz)
      if d <= SETTINGS.range_m and not winded(p.handle) then list[#list + 1] = { hdl = p.handle, d = d } end
    end
  end
  table.sort(list, function(a, b) return a.d < b.d end)
  return list
end

-- the pressers: the candidates within band_m, at least min_players, at most max_players
local function pick(list)
  local out = {}
  for _, c in ipairs(list) do
    if #out >= SETTINGS.max_players then break end
    if c.d <= SETTINGS.band_m or #out < SETTINGS.min_players then out[#out + 1] = c end
  end
  return out
end

-- the game's «¡Subid!» arrows on the pressers of `team` (arrows = "user": only your team's)
local function arrows_for(team, user)
  return SETTINGS.arrows == "both" or (SETTINGS.arrows == "user" and team == user)
end

-- a presser's arrows end with his press (mark = the carrier they point at; true = none)
local function arrows_off(hdl, mark)
  if mark ~= true then pcall(VRFW.ai.arrow_off, hdl) end
end

-- the press guide on the L2 plate: shown while the rival had the ball last in open play
local function set_hud(on)
  if SETTINGS.hud_sprite == "" or on == State.hud or not VRFW.hud then return end
  local ok = pcall(VRFW.hud.go_ahead_guide, on and SETTINGS.hud_sprite or nil)
  if ok then
    State.hud = on
    info(on and "the L2 guide shows the press" or "the L2 guide is the game's")
  end
end

local function stop(team, why)
  local t = State.team[team]
  if t.count == 0 then return end
  for hdl, mark in pairs(t.pressers) do
    pcall(VRFW.ai.release, hdl)
    arrows_off(hdl, mark)
  end
  t.pressers, t.count = {}, 0
  info(string.format("T%d stops pressing (%s)", team, why))
end

local function press(team, carrier, cx, cz, who, user)
  local t = State.team[team]
  local chosen = pick(candidates(team, cx, cz))
  local now_set, n, names = {}, 0, {}
  local target = SETTINGS.chase and { chase = carrier } or { x = cx, z = cz }
  local arrows = arrows_for(team, user)
  for _, c in ipairs(chosen) do
    local ok, done = pcall(VRFW.ai.move, c.hdl, target, { sprint = SETTINGS.sprint, ms = SETTINGS.order_ms })
    if ok and done then
      -- his arrows when he starts pressing, and a new target for them when the carrier changes
      local mark = t.pressers[c.hdl]
      if arrows and mark ~= nil and mark ~= true and mark ~= carrier then
        pcall(VRFW.ai.arrow, c.hdl, { chase = carrier })
        mark = carrier
      elseif arrows and mark == nil then
        local oka, shown = pcall(VRFW.ai.arrow, c.hdl, { chase = carrier })
        mark = (oka and shown) and carrier or true
      elseif mark == nil then
        mark = true
      end
      now_set[c.hdl] = mark
      n = n + 1
      names[#names + 1] = string.format("%s (%.1f m)", hex(c.hdl), c.d)
    end
  end
  local changed = n ~= t.count
  for hdl, mark in pairs(t.pressers) do
    if not now_set[hdl] then
      pcall(VRFW.ai.release, hdl)
      arrows_off(hdl, mark)
      changed = true
    end
  end
  for hdl in pairs(now_set) do
    if not t.pressers[hdl] then changed = true end
  end
  t.pressers, t.count = now_set, n
  if changed then
    if n > 0 then
      info(string.format("T%d presses the carrier %s (%s): %s", team, hex(carrier), who, table.concat(names, ", ")))
    else
      info(string.format("T%d: nobody can press the carrier %s (%s: none in range / all winded)", team, hex(carrier), who))
    end
  end
end

-- the user's press button: one of hold_commands is on
local function user_holds()
  if not VRFW.input or not VRFW.input.on then return false end
  for _, c in ipairs(SETTINGS.hold_commands) do
    local ok, on = pcall(VRFW.input.on, c)
    if ok and on == true then return true end
  end
  return false
end

-- one CPU rule holds now
local function rule_holds(r, team, cx, cz, list)
  if r.carrier_to_own_goal_max_m or r.carrier_in_own_half then
    local ok, gx, gz = pcall(VRFW.ai.own_goal, team)
    if not ok or not gx then return false end
    local own = dist(cx, cz, gx, gz)
    if r.carrier_to_own_goal_max_m and own > r.carrier_to_own_goal_max_m then return false end
    if r.carrier_in_own_half then
      local ok2, ox, oz = pcall(VRFW.ai.own_goal, 1 - team)
      if not ok2 or not ox or own >= dist(cx, cz, ox, oz) then return false end
    end
  end
  if r.nearest_within_m and not (list[1] and list[1].d <= r.nearest_within_m) then return false end
  if r.ready_within_m then
    local n = 0
    for _, c in ipairs(list) do
      if c.d <= r.ready_within_m then n = n + 1 end
    end
    if n < r.ready_count then return false end
  end
  return math.random() < r.chance
end

-- the CPU of `team` wants to press now
local function cpu_wants(team, cx, cz, now)
  local t = State.team[team]
  if now < t.cpu_until then return true end
  if t.cpu_until ~= 0 then
    t.cpu_until = 0
    stop(team, "the CPU's press time is over")
  end
  if now < t.cpu_rest or now < t.cpu_next then return false end
  t.cpu_next = now + SETTINGS.decide_ms
  local list = candidates(team, cx, cz)
  if #list == 0 then return false end
  for i, r in ipairs(SETTINGS.cpu_rules) do
    if rule_holds(r, team, cx, cz, list) then
      t.cpu_until = now + SETTINGS.press_ms
      t.cpu_rest = t.cpu_until + SETTINGS.rest_ms
      info(string.format("T%d (CPU) starts a press: rule %d, %d ms", team, i, SETTINGS.press_ms))
      return true
    end
  end
  return false
end

local function stop_all(why)
  stop(0, why)
  stop(1, why)
end

-- the focus field gate, once per match at its first frame (a refusal, e.g. not an offline match: logged once, the
-- match keeps the game's focus field)
local function set_gate()
  if State.gate_set or SETTINGS.focus_field_gate == "off" then return end
  State.gate_set = true
  for team = 0, 1 do
    local ok, done, why = pcall(VRFW.ai.focus_field_gate, team, SETTINGS.focus_field_gate)
    if not (ok and done) and not State.gate_warned then
      State.gate_warned = true
      info("focus field gate not set: " .. tostring(ok and why or done))
    end
  end
end

VRFW.on("match_start", function() State.gate_set = false return nil end)
VRFW.on("match_end", function() State.gate_set = false return nil end)

VRFW.on("tick", function(ev)
  local m = ev.match or VRFW.match()
  local now = VRFW.now()
  set_gate()
  if not m or m.soccer_state ~= STATE_IN_PLAY then
    stop_all("play stopped")
    State.owner, State.last_owner = nil, nil
    set_hud(false)
    return nil
  end
  local user = m.user_team
  local ok, carrier, cteam, cx, cz = pcall(VRFW.ai.ball)
  if not ok or not carrier or (cteam ~= 0 and cteam ~= 1) then
    stop_all("loose ball")
    State.owner = nil
    return nil
  end
  if State.owner ~= cteam then
    -- possession changed: the CPU decides again from now; the press guide follows the ball
    State.owner, State.last_owner = cteam, cteam
    set_hud((user == 0 or user == 1) and cteam ~= user)
    for team = 0, 1 do
      local t = State.team[team]
      t.cpu_until, t.cpu_next = 0, 0
    end
  end
  stop(cteam, "his team has the ball")
  local team = 1 - cteam
  local want, who
  if user == team then
    want, who = user_holds(), "your press button"
  else
    want, who = SETTINGS.cpu and cpu_wants(team, cx, cz, now), "CPU"
  end
  if want then
    press(team, carrier, cx, cz, who, user)
  else
    stop(team, user == team and "press button released" or "the CPU does not press")
  end
  return nil
end)

info(string.format("active: %d-%d pressers within %.0f m (range %.0f m), sprint %s, focus field %s, your button %s, CPU %s (%d rules)",
  SETTINGS.min_players, SETTINGS.max_players, SETTINGS.band_m, SETTINGS.range_m, tostring(SETTINGS.sprint),
  SETTINGS.focus_field_gate, table.concat(SETTINGS.hold_commands, " / "), tostring(SETTINGS.cpu), #SETTINGS.cpu_rules))
info(string.format("HUD: L2 press guide %s, arrows %s", SETTINGS.hud_sprite ~= "" and SETTINGS.hud_sprite or "off",
  SETTINGS.arrows))
