-- Football Reforged › module «goalkeeper_barrier»: the goalkeeper's barrier and the block -> keeper tension discount
-- (docs/game/mechanics/gk-barrier.md). Was Inazuma Fantasy's scripts\gk_barrier.lua until 2026-10-14.
-- Switch: content\modules\goalkeeper_barrier.toml (row «Barrera del portero» of «Opciones de mods», under «Football
-- Reforged»; read live). Settings: config.toml [goalkeeper_barrier]. Declarations: content\game\football_reforged.toml
-- (the globals / structs read here, the availability answer of the discounted keeper moves on the cost check, table
-- FootballReforged.KeeperTension, and the HUD command). HUD: research/grafts/football_reforged_barrier_hud (the barrier
-- drawn ORANGE inside each keeper's fatigue bar of the scoreboard, at its goal side).
--
-- 1. BARRIER. Every team's goalkeeper (formation position keeper_position on the pitch) has a barrier, a 0-100 % gauge:
--      barrier = start_percent × clamp(1 − fatigue_rate × (1 − stamina / stamina max), 0, 1)
--    stamina = the match resource `fatigue_resource` (default stamina_points.pe: the PE of the mod Stamina Points, an
--    optional link: without that mod / resource the barrier stays at start_percent). With fatigue_rate 1 every point of
--    stamina he loses takes start_percent / stamina max off the barrier (a fresh keeper 25 %, at half stamina 12.5 %,
--    empty 0 %).
--    While his barrier is > 0, every shot that reaches him has its power ÷ mitigation (1.75) for his save duel (catch,
--    punch or keeper move: the VR-Framework's rule trigger `keeper_duel`, power_mult = 1 / mitigation). At 0 he saves
--    with the shot's full power. One INFO line per whole-percent change of a barrier and per mitigated shot.
-- 2. BLOCK -> KEEPER TENSION. When a player uses a block move (its tension is paid: trigger `tension_pay:skill`, the
--    move's slot category = block_category), his team's keeper gets a discount: his next keeper move (category
--    keeper_category) costs (1 − tension_discount) × its tension (cost_mult on the pay) and is available from that
--    lower tension on (the cost check answer reads FootballReforged.KeeperTension). The discount is used up by that
--    keeper move; several blocks before it do not stack; discount_expire_seconds > 0 also ends it after that many match
--    seconds; a new match clears it. One INFO line when it is armed and one when it is applied.
-- With the module off nothing above happens (the handlers answer nothing, the table is emptied, the HUD hides).

FootballReforged = FootballReforged or {}
FootballReforged.GoalkeeperBarrier = FootballReforged.GoalkeeperBarrier or {}
local Barrier = FootballReforged.GoalkeeperBarrier
local Modules = require "lib/modules"

local MODULE = "goalkeeper_barrier"

local function info(...) VRFW.log("goalkeeper_barrier:", ...) end

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if low and v < low then v = low end
  if high and v > high then v = high end
  return v
end

local RAW = (VRFW.files and VRFW.files.config and VRFW.files.config("goalkeeper_barrier")) or {}
local SETTINGS = {
  start_percent = number_setting(RAW, "start_percent", 25, 0, 100),
  mitigation = number_setting(RAW, "mitigation", 1.75, 1, 100),
  fatigue_rate = number_setting(RAW, "fatigue_rate", 1.0, 0, 100),
  fatigue_resource = type(RAW.fatigue_resource) == "string" and RAW.fatigue_resource or "stamina_points.pe",
  tension_discount = number_setting(RAW, "tension_discount", 0.30, 0, 1),
  discount_expire_seconds = number_setting(RAW, "discount_expire_seconds", 0, 0, 100000),
  block_category = math.floor(number_setting(RAW, "block_category", 3, 0, 255)),
  keeper_category = math.floor(number_setting(RAW, "keeper_category", 4, 0, 255)),
  keeper_position = math.floor(number_setting(RAW, "keeper_position", 0, 0, 255)),
  rescan_ms = math.floor(number_setting(RAW, "rescan_ms", 1000, 100, 60000)),
}
Barrier.settings = SETTINGS

local TENSION_TABLE = "FootballReforged.KeeperTension"
-- game layout (docs/game/mechanics/match-stamina.md §6 / §10): actors, units, members, the team gauge block
local ACTOR_COUNT, ACTOR_STRIDE = 0x3A, 0x570
local MATCH_TEAMS, TEAM_STRIDE, TEAM_TENSION, MATCH_USER_TEAM = 0x60, 0x1130, 0x1058, 0x2C29
local MEMBER_POSITION = 0x71
local MOVE_SLOTS = 6

local band = bit32.band

local function read(kind, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, kind, at)
  if ok then return v end
  return nil
end

local function game_global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function hex(v) return string.format("0x%08X", v or 0) end

local function unit_of(actor)
  local ok, u = pcall(VRFW.call, "FootballActorUnit", actor)
  if ok and type(u) == "number" and u >= 0x10000 then return VRFW.mem.read_struct("FootballUnit", u) end
  return nil
end

local function actor_of(handle)
  local base = game_global("football_actors")
  if not base or not handle or handle == 0 then return nil end
  local actor = base + band(handle, 0xFF) * ACTOR_STRIDE
  local a = VRFW.mem.read_struct("FootballActor", actor)
  if a and a.handle == handle then return actor, a end
  return nil
end

-- the move's slot category in the player's unit (nil = not one of his six slots)
local function category_of(unit, move)
  if not unit or not move or move == 0 then return nil end
  for i = 0, MOVE_SLOTS - 1 do
    if unit["move" .. i] == move then return unit["category" .. i], i end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------------- match state

local State = {
  scene = 0,
  keeper = {},        -- team -> keeper handle
  percent = {},       -- team -> barrier % now
  logged = {},        -- team -> last whole percent logged
  discount = {},      -- team -> { since = match clock ms, by = blocker handle, move = block move }
  published = {},     -- "handle:move" -> { key, ok } written to FootballReforged.KeeperTension
  scan_ms = -1e18,
  match = nil,
  was_on = nil,
}

local function reset(why)
  State.keeper, State.percent, State.logged, State.discount = {}, {}, {}, {}
  State.published = {}
  State.scan_ms = -1e18
  pcall(VRFW.native.table_clear, TENSION_TABLE)
  if why then info(why) end
end

-- the barrier of a keeper now (% 0..100) and his stamina (current, max; nil without a stamina value)
function Barrier.barrier_of(handle)
  local start = SETTINGS.start_percent
  local ok, v = pcall(VRFW.resource.get, SETTINGS.fatigue_resource, handle)
  if not ok or type(v) ~= "table" or type(v.cur) ~= "number" or type(v.max) ~= "number" or v.max <= 0 then
    return start, nil, nil
  end
  local lost = 1 - math.max(0, math.min(1, v.cur / v.max))
  local k = math.max(0, math.min(1, 1 - SETTINGS.fatigue_rate * lost))
  return start * k, v.cur, v.max
end

local function scan_keepers(now)
  if now - State.scan_ms < SETTINGS.rescan_ms then return end
  State.scan_ms = now
  local base = game_global("football_actors")
  if not base then return end
  local found = {}
  for i = 0, ACTOR_COUNT - 1 do
    local actor = base + i * ACTOR_STRIDE
    local a = VRFW.mem.read_struct("FootballActor", actor)
    if a and a.handle ~= 0 and band(a.handle, 0xFF) == i and a.team <= 1 then
      local u = unit_of(actor)
      local member = u and u.member
      local position = (member and member >= 0x10000) and read("u8", member + MEMBER_POSITION) or nil
      if position == SETTINGS.keeper_position then
        local f = found[a.team]
        -- prefer the one in play (a bench keeper may share the position)
        if not f or (f.in_play == 0 and a.in_play ~= 0) then found[a.team] = { handle = a.handle, in_play = a.in_play } end
      end
    end
  end
  for team = 0, 1 do
    local f = found[team]
    local h = f and f.handle or nil
    if h ~= State.keeper[team] then
      State.keeper[team] = h
      if h then
        local percent = Barrier.barrier_of(h)
        info(string.format("T%d keeper %s: barrier %.1f %% (start %.0f %%, shots ÷ %.2f while > 0)", team, hex(h), percent,
          SETTINGS.start_percent, SETTINGS.mitigation))
      end
    end
  end
end

local function update_barriers()
  for team = 0, 1 do
    local h = State.keeper[team]
    if h then
      local percent, current, max = Barrier.barrier_of(h)
      State.percent[team] = percent
      local whole = percent > 0 and math.ceil(percent - 1e-6) or 0
      if State.logged[team] ~= whole then
        if State.logged[team] ~= nil then
          info(string.format("T%d keeper %s: barrier %d %% -> %d %%%s (stamina %s)", team, hex(h), State.logged[team], whole,
            whole == 0 and ": BROKEN, he saves at the shot's full power" or "",
            current and string.format("%.1f/%.0f", current, max) or "n/a"))
        end
        State.logged[team] = whole
      end
    else
      State.percent[team] = nil
    end
  end
end

-- FootballReforged.KeeperTension (handle, move) -> { ok = 0/1 }: the keeper's keeper moves while his team's discount is
-- armed (the cost check answer of content\game\football_reforged.toml): available when the team's tension covers the
-- discounted cost
local function publish_tension(match)
  local want = {}
  for team = 0, 1 do
    local h = State.keeper[team]
    if h and State.discount[team] then
      local actor = actor_of(h)
      local u = actor and unit_of(actor)
      local t = read("i32", match + MATCH_TEAMS + team * TEAM_STRIDE + TEAM_TENSION)
      if u and t then
        local units = t >= 0 and math.floor(t / 10000) or -math.floor(-t / 10000)
        for i = 0, MOVE_SLOTS - 1 do
          local move, category, cost = u["move" .. i], u["category" .. i], u["cost" .. i]
          if move and move ~= 0 and category == SETTINGS.keeper_category and type(cost) == "number" then
            local need = math.floor(cost * (1 - SETTINGS.tension_discount) + 1e-9)
            want[h .. ":" .. move] = { key = { h, move }, ok = units >= need and 1 or 0 }
          end
        end
      end
    end
  end
  for k, r in pairs(State.published) do
    if not want[k] then
      pcall(VRFW.native.table_set, TENSION_TABLE, r.key, nil)
      State.published[k] = nil
    end
  end
  for k, r in pairs(want) do
    local old = State.published[k]
    if not old or old.ok ~= r.ok then
      pcall(VRFW.native.table_set, TENSION_TABLE, r.key, { ok = r.ok })
      State.published[k] = r
    end
  end
end

VRFW.on("tick", function(ev)
  local on = Modules.on(MODULE)
  if on ~= State.was_on then
    if State.was_on ~= nil then
      info(on and "module switched on" or "module switched off: no barrier, no keeper discount")
    end
    State.was_on = on
    if not on then
      State.scene = 0
      reset(nil)
    end
  end
  if not on then return nil end
  local scene = game_global("football_scene") or 0
  local match = game_global("football_match")
  if scene == 0 or not match then
    if State.scene ~= 0 then
      State.scene = 0
      reset(nil)
    end
    return nil
  end
  if scene ~= State.scene then
    State.scene = scene
    reset("new match: barriers back to the start, no keeper discount")
  end
  State.match = match
  local now = VRFW.match.clock()
  scan_keepers(now)
  update_barriers()
  for team = 0, 1 do
    local d = State.discount[team]
    if d and SETTINGS.discount_expire_seconds > 0 and (now - d.since) >= SETTINGS.discount_expire_seconds * 1000 then
      State.discount[team] = nil
      info(string.format("T%d: keeper tension discount expired (%.0f s without a keeper move)", team, SETTINGS.discount_expire_seconds))
    end
  end
  publish_tension(match)
  return nil
end)

-- 1. the save duel: the shot's power ÷ mitigation while the keeper's barrier is > 0
VRFW.on("keeper_duel", function(ev)
  if not Modules.on(MODULE) then return nil end
  local a = ev.actor
  if not a or not a.handle then return nil end
  local percent = Barrier.barrier_of(a.handle)
  if percent <= 0 then
    info(string.format("keeper duel: T%s keeper %s (%s): barrier 0 %%: the shot keeps its full power", tostring(a.team), hex(a.handle), ev.arg))
    return nil
  end
  info(string.format("keeper duel: T%s keeper %s (%s, move %s): barrier %.1f %%: shot power ÷ %.2f", tostring(a.team), hex(a.handle), ev.arg,
    hex(ev.skill), percent, SETTINGS.mitigation))
  return { power_mult = 1 / SETTINGS.mitigation }
end)

-- 2. a block move arms its team's keeper discount; the keeper's next keeper move uses it
VRFW.on("tension_pay:skill", function(ev)
  if not Modules.on(MODULE) then return nil end
  local a = ev.actor
  if not a or not a.handle or not ev.skill or a.team == nil or a.team > 1 then return nil end
  local actor = actor_of(a.handle)
  local category = category_of(actor and unit_of(actor), ev.skill)
  local team = a.team
  if category == SETTINGS.block_category and SETTINGS.tension_discount > 0 then
    if not State.discount[team] then
      info(string.format("T%d: block move %s by %s: the keeper's next keeper move needs %.0f %% less tension", team, hex(ev.skill), hex(a.handle),
        SETTINGS.tension_discount * 100))
    end
    State.discount[team] = { since = VRFW.match.clock(), by = a.handle, move = ev.skill }
    return nil
  end
  if category == SETTINGS.keeper_category and State.discount[team] then
    local d = State.discount[team]
    State.discount[team] = nil
    info(string.format("T%d: keeper %s move %s: tension x%.2f (discount of block move %s by %s)", team, hex(a.handle), hex(ev.skill),
      1 - SETTINGS.tension_discount, hex(d.move), hex(d.by)))
    return { cost_mult = 1 - SETTINGS.tension_discount }
  end
  return nil
end)

-- ---------------------------------------------------------------------------------------------- HUD command

-- CMND_FOOTBALLREFORGED_GOALKEEPER_BARRIER(side) -> ok, percent (0..100), discount (0/1), team, user (0/1).
-- side: 0 / 1 = that team, -1 (or none) = the user's team, -2 = the rival's (graft football_reforged_barrier_hud: the
-- orange segment of that keeper's fatigue bar is `percent` % of the bar long). false = nothing to show (module off, no
-- match, no keeper).
function Barrier.Get(side)
  if not Modules.on(MODULE) or State.scene == 0 or not State.match then return false end
  local user = read("u8", State.match + MATCH_USER_TEAM) or 0
  if user > 1 then user = 0 end
  side = tonumber(side) or -1
  local team = side
  if side == -1 then team = user elseif side == -2 then team = 1 - user end
  if team ~= 0 and team ~= 1 then return false end
  local percent = State.percent[team]
  if percent == nil then return false end
  return true, percent, State.discount[team] and 1 or 0, team, team == user and 1 or 0
end

info(string.format("loaded (on / off: module %s, read live): start %.0f %%, shots ÷ %.2f while > 0, fatigue rate %.2f on %s; block -> keeper tension x%.2f%s; categories block %d / keeper %d",
  MODULE, SETTINGS.start_percent, SETTINGS.mitigation, SETTINGS.fatigue_rate, SETTINGS.fatigue_resource,
  1 - SETTINGS.tension_discount,
  SETTINGS.discount_expire_seconds > 0 and string.format(" (expires after %.0f s)", SETTINGS.discount_expire_seconds) or " (until his next keeper move)",
  SETTINGS.block_category, SETTINGS.keeper_category))
