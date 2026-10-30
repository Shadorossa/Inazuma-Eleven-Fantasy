-- Football Reforged › module «goalkeeper_barrier»: the goalkeeper's barrier and the block -> keeper tension discount
-- (docs/game/mechanics/gk-barrier.md). Was Inazuma Fantasy's scripts\gk_barrier.lua until 2026-10-14.
-- Switch: content\modules\goalkeeper_barrier.toml (row «Barrera del portero» of «Opciones de mods», under «Football
-- Reforged»; read live). Settings: config.toml [goalkeeper_barrier]. Declarations: content\game\goalkeeper_barrier.toml
-- (the globals / structs read here, the availability answer of the discounted keeper moves on the cost check, table
-- GoalkeeperBarrier.KeeperTension, and the HUD command). HUD: research/grafts/goalkeeper_barrier_hud (the barrier
-- drawn BRONZE inside each keeper's bar of the scoreboard: the part of the bar still above the barrier line).
--
-- 1. BARRIER. The barrier is the top barrier_percent (25 %) of each team's keeper bar (the scoreboard's keeper bar: the
--    rate the retail UpdateScoreboardKeeperHp reads with funcLuaCommand(3112466283, 3 own / 4 rival); the HUD graft
--    research/grafts/goalkeeper_barrier_hud passes it with every CMND_GOALKEEPERBARRIER_GET, no bar reported = no barrier):
--      barrier = clamp(bar % - (100 - barrier_percent), 0, barrier_percent)
--    A full bar = 25 %, the bar at 75 % or below = 0. While it is > 0 (the bar above 75 %) every shot that reaches that
--    keeper has its power ÷ mitigation (1.4) for his save duel (catch, punch or keeper move: the VR-Framework's rule
--    trigger `keeper_duel`, power_mult = 1 / mitigation); with the bar at 75 % or below the shots keep their full power.
--    One INFO line per whole-percent change of a barrier and per shot on a keeper.
-- 2. BLOCK -> KEEPER TENSION. When a player uses a block move (its tension is paid: trigger `tension_pay:skill`, the
--    move's slot category = block_category), his team's keeper gets a discount: his next keeper move (category
--    keeper_category) costs (1 − tension_discount) × its tension (cost_mult on the pay) and is available from that
--    lower tension on (the cost check answer reads GoalkeeperBarrier.KeeperTension). The discount is used up by that
--    keeper move; several blocks before it do not stack; discount_expire_seconds > 0 also ends it after that many match
--    seconds; a new match clears it. One INFO line when it is armed and one when it is applied.
-- With the module off nothing above happens (the handlers answer nothing, the table is emptied, the HUD hides).

GoalkeeperBarrier = GoalkeeperBarrier or {}
local Barrier = GoalkeeperBarrier
local Modules = { on = function(_) return true end }   -- a module mod runs only while it is on

local MODULE = "goalkeeper_barrier"

require "VRFW/lib/basics"
local info = VRFW.logger("goalkeeper_barrier")

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if low and v < low then v = low end
  if high and v > high then v = high end
  return v
end

local RAW = (VRFW.files and VRFW.files.config and VRFW.files.config("goalkeeper_barrier")) or {}
local SETTINGS = {
  -- the HUD draws the retail gauge (yellow, no bronze sprite) over the whole barrier share: a placement test
  hud_debug = RAW.hud_debug == true,
  -- start_percent: the key's name until 1.0.1
  barrier_percent = number_setting(RAW, "barrier_percent", number_setting(RAW, "start_percent", 25, 0, 100), 0, 100),
  mitigation = number_setting(RAW, "mitigation", 1.4, 1, 100),
  tension_discount = number_setting(RAW, "tension_discount", 0.30, 0, 1),
  discount_expire_seconds = number_setting(RAW, "discount_expire_seconds", 0, 0, 100000),
  block_category = math.floor(number_setting(RAW, "block_category", 3, 0, 255)),
  keeper_category = math.floor(number_setting(RAW, "keeper_category", 4, 0, 255)),
  keeper_position = math.floor(number_setting(RAW, "keeper_position", 0, 0, 255)),
  rescan_ms = math.floor(number_setting(RAW, "rescan_ms", 1000, 100, 60000)),
}
Barrier.settings = SETTINGS

local TENSION_TABLE = "GoalkeeperBarrier.KeeperTension"
-- game layout (docs/game/mechanics/match-stamina.md §6 / §10): the actor table through the framework (VRFW/lib/actors);
-- units, members and the match info block as structs of content\game\goalkeeper_barrier.toml
local Actors = require "VRFW/lib/actors"
local MOVE_SLOTS = 6

local band = bit32.band

local function game_global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function hex(v) return string.format("0x%08X", v or 0) end

-- one field of a [[VRFW.Struct]] of content\game\goalkeeper_barrier.toml at `at`; nil when not readable
local function struct_field(struct, at, name)
  if not at or at < 0x10000 then return nil end
  local ok, s = pcall(VRFW.mem.struct, struct, at)
  if not ok then return nil end
  local ok_value, v = pcall(function() return s[name] end)
  if ok_value then return v end
  return nil
end

local function unit_of(actor)
  local ok, u = pcall(VRFW.call, "Match.ActorUnit", actor)
  if ok and type(u) == "number" and u >= 0x10000 then return VRFW.mem.read_struct("FootballUnit", u) end
  return nil
end

local function actor_of(handle)
  if not handle or handle == 0 then return nil end
  local a = Actors.of(handle)
  if a then return a.address, a end
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
  published = {},     -- "handle:move" -> { key, ok } written to GoalkeeperBarrier.KeeperTension
  scan_ms = -1e18,
  match = nil,
  was_on = nil,
}

local function reset(why)
  State.keeper, State.percent, State.logged, State.discount = {}, {}, {}, {}
  State.bar = {}
  State.published = {}
  State.scan_ms = -1e18
  pcall(VRFW.native.table_clear, TENSION_TABLE)
  if why then info(why) end
end

-- team 0 / 1's keeper bar now in % (0..100) as the scoreboard draws it (reported by the HUD graft), or nil
function Barrier.bar_of(team)
  return State.bar and State.bar[team] or nil
end

-- team 0 / 1's barrier now (0..barrier_percent: the part of its keeper bar above 100 - barrier_percent) and the bar %
-- (nil = no bar read, no barrier)
function Barrier.barrier_of(team)
  local bar = Barrier.bar_of(team)
  if bar == nil then return 0, nil end
  local top = SETTINGS.barrier_percent
  return math.max(0, math.min(top, bar - (100 - top))), bar
end

local function scan_keepers(now)
  if now - State.scan_ms < SETTINGS.rescan_ms then return end
  State.scan_ms = now
  if not Actors.base() then return end
  local found = {}
  for _, entry in ipairs(Actors.list()) do
    local actor = entry.address
    local a = VRFW.mem.read_struct("FootballActor", actor)
    if a and a.handle ~= 0 and band(a.handle, 0xFF) == entry.index and a.team <= 1 then
      local u = unit_of(actor)
      local position = struct_field("FootballMember", u and u.member, "position")
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
        local percent, bar = Barrier.barrier_of(team)
        info(string.format("T%d keeper %s: barrier %.1f %% (keeper bar %s, its top %.0f %%; shots ÷ %.2f while > 0)", team,
          hex(h), percent, bar and string.format("%.1f %%", bar) or "n/a", SETTINGS.barrier_percent, SETTINGS.mitigation))
      end
    end
  end
end

local function update_barriers()
  for team = 0, 1 do
    local h = State.keeper[team]
    if h then
      local percent, bar = Barrier.barrier_of(team)
      State.percent[team] = percent
      local whole = percent > 0 and math.ceil(percent - 1e-6) or 0
      if State.logged[team] ~= whole then
        if State.logged[team] ~= nil then
          info(string.format("T%d keeper %s: barrier %d %% -> %d %%%s (keeper bar %s)", team, hex(h), State.logged[team], whole,
            whole == 0 and ": BROKEN, he saves at the shot's full power" or "",
            bar and string.format("%.1f %%", bar) or "n/a"))
        end
        State.logged[team] = whole
      end
    else
      State.percent[team] = nil
    end
  end
end

-- GoalkeeperBarrier.KeeperTension (handle, move) -> { ok = 0/1 }: the keeper's keeper moves while his team's discount is
-- armed (the cost check answer of content\game\goalkeeper_barrier.toml): available when the team's tension covers the
-- discounted cost
local function publish_tension(match)
  local want = {}
  for team = 0, 1 do
    local h = State.keeper[team]
    if h and State.discount[team] then
      local actor = actor_of(h)
      local u = actor and unit_of(actor)
      local t = struct_field("FootballMatchInfo", match, "tension" .. team)
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

-- 1. the save duel: the shot's power ÷ mitigation while the keeper's barrier is > 0 (his bar above the barrier line)
VRFW.on("keeper_duel", function(ev)
  if not Modules.on(MODULE) then return nil end
  local a = ev.actor
  if not a or not a.handle or (a.team ~= 0 and a.team ~= 1) then return nil end
  local percent, bar = Barrier.barrier_of(a.team)
  local shown = bar and string.format("%.1f %%", bar) or "n/a"
  if percent <= 0 then
    info(string.format("keeper duel: T%s keeper %s (%s): keeper bar %s, barrier 0 %%: the shot keeps its full power",
      tostring(a.team), hex(a.handle), ev.arg, shown))
    return nil
  end
  info(string.format("keeper duel: T%s keeper %s (%s, move %s): keeper bar %s, barrier %.1f %%: shot power ÷ %.2f",
    tostring(a.team), hex(a.handle), ev.arg, hex(ev.skill), shown, percent, SETTINGS.mitigation))
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

-- CMND_GOALKEEPERBARRIER_GET(side, bar_rate) -> ok, percent (0..100), discount (0/1), team, user (0/1), barrier share
-- (% of the bar), hud_debug (0/1).
-- side: 0 / 1 = that team, -1 (or none) = the user's team, -2 = the rival's (graft goalkeeper_barrier_hud: the
-- bronze segment of that keeper's bar is `percent` % of the bar long, from the barrier line). false = nothing to show (module off, no
-- match, no keeper).
-- bar_rate (optional): that keeper bar's fill 0..1 as the scoreboard draws it; it is the barrier's source.
function Barrier.Get(side, bar_rate)
  if not Modules.on(MODULE) or State.scene == 0 or not State.match then return false end
  local user = struct_field("FootballMatchInfo", State.match, "user_team") or 0
  if user > 1 then user = 0 end
  side = tonumber(side) or -1
  local team = side
  if side == -1 then team = user elseif side == -2 then team = 1 - user end
  if team ~= 0 and team ~= 1 then return false end
  bar_rate = tonumber(bar_rate)
  if bar_rate and bar_rate == bar_rate then
    State.bar = State.bar or {}
    local first = State.bar[team] == nil
    State.bar[team] = math.max(0, math.min(100, bar_rate * 100))
    if first then
      info(string.format("T%d: keeper bar %.1f %% (from the scoreboard)", team, State.bar[team]))
    end
  end
  local percent = State.percent[team]
  if percent == nil then return false end
  return true, percent, State.discount[team] and 1 or 0, team, team == user and 1 or 0, SETTINGS.barrier_percent,
    SETTINGS.hud_debug and 1 or 0
end

info(string.format("loaded (on / off: module %s, read live): barrier = the top %.0f %% of the keeper bar, shots ÷ %.2f while the bar is above %.0f %%; block -> keeper tension x%.2f%s; categories block %d / keeper %d",
  MODULE, SETTINGS.barrier_percent, SETTINGS.mitigation, 100 - SETTINGS.barrier_percent,
  1 - SETTINGS.tension_discount,
  SETTINGS.discount_expire_seconds > 0 and string.format(" (expires after %.0f s)", SETTINGS.discount_expire_seconds) or " (until his next keeper move)",
  SETTINGS.block_category, SETTINGS.keeper_category))
