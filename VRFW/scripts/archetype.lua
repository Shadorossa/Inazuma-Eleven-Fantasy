-- VR-Framework › archetypes declared by mods (docs/framework/archetype.md). Declarations: every active mod's
-- content\archetypes\*.toml (`VRFW.archetype/1`); native side: content\game\archetype.toml (team build pick hooks,
-- battle getter answers, exec conditions 910 / 911 on the shared exec condition detour of service S6 (VRFW 2.3),
-- CMND_VRFW_ARCHETYPE_*, state keys); menus / HUD: the Lua patches of assets\lua\archetype\.
--
--   * Pick: when the engine picks a team's build (TeamBuildType 0xD9E2D0) a declared archetype gets one point per
--     carrier of one of its passives (the engine's own passive list: starters + staff, entries of definitions with a
--     team cap). It wins with strictly more points than each of the game's six builds and every other declared one
--     (at least 1); then the six counts are zeroed and the engine answers 6 (no game build effect, no build AI
--     personality). A tie at the top stays «Libertad», as the game does.
--   * Charge (match): per side, from match events: `shot_on_target` (a shot of the side reaches the rival keeper),
--     `goal`, `conceded`, `shot` (a shot of the side starts), `no_shot` (every `every_s` live seconds without a shot of
--     the side). Rank = how many `rank_charges` thresholds the charge reaches (0-5); the charge stays 0..the last.
--   * Effects (passive effect rows with the loader event 951, target as declared; never run by the engine):
--       vrfw_eff_focus_per_team_event   the carrier's focus AT / DF + value % per event of his side this match
--                                       (EFFECT_DATA p1: 1 shot_on_target, 2 goal, 3 shot)
--       vrfw_eff_team_shot_at_per_rank  his side's players on the pitch: shot AT + value % × rank, while the side's
--                                       archetype is the passive's (its archetype's `passives`; else p1 = the number)
--       vrfw_eff_resource_drain_per_rank  the carrier's match resource drain × (1 − value % × rank), same condition
--                                       (p1 = crc32 of the resource key, e.g. inazuma_fantasy.pe)
--     applied through the battle getters' native answers (tables Archetype.ShotAt / Archetype.Focus, keyed by the
--     actor handle) and VRFW.resource.set_mult (source "archetype"). A definition's team cap (GRAND_TOTAL_INFO column
--     2, the effect's unit; 0 = none) is the most one player gets from it, however many carriers.

Archetype = Archetype or {}

local function info(...) VRFW.log("archetype:", ...) end
local function warn(...) VRFW.warn("archetype:", ...) end

local INVALID = 0xC4DC849A
local LOADER_EVENT = 951
local ACTOR_STRIDE, ACTOR_MAX, ACTOR_HDL, ACTOR_TEAM, UNIT_CHARA = 0x570, 0x3A, 0x94, 0xD0, 0x370
local N_SLOTS = 5
local N_GAME = 6                     -- the game's builds 0-5; 6 = «Libertad»
local FREEDOM = 6
local MAX_NUMBER = 63
local LIVE = { [9] = true, [14] = true, [15] = true, [16] = true }
local EVENTS = { shot_on_target = true, goal = true, conceded = true, shot = true, no_shot = true }
local EVENT_CODE = { [1] = "shot_on_target", [2] = "goal", [3] = "shot" }
local REFRESH_S = 3.0
local SOURCE = "archetype"

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  v = math.floor(v)
  return v % 4294967296
end

local function crc(s) return u32(VRFW.ui.crc32(s)) end

-- "0x…" / decimal / a number → the number, any other text → crc32 of it
local function id_of(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % 4294967296 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % 4294967296 end
  return crc(v)
end

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local DECL = {}          -- number -> archetype
local LIST = {}          -- archetypes in declaration order
local PASS_ARCH = {}     -- passive id -> archetype number

local CHARGE_KEYS = { on = true, add = true, every_s = true }
local ARCH_KEYS = { name = true, number = true, label = true, description = true, icon = true, icon_large = true,
  gauge_icon = true, passives = true, rank_charges = true, start_charge = true, charge = true }

local function read_decl(mod, file, a, i)
  local where = string.format("mods/%s/%s: [[VRFW.Archetype]] #%d", tostring(mod), tostring(file), i)
  for k in pairs(a) do
    if not ARCH_KEYS[k] then return nil, where .. ": unknown key `" .. tostring(k) .. "`" end
  end
  if type(a.name) ~= "string" or not a.name:match("^[a-z0-9_]+$") then return nil, where .. ": name = \"a-z 0-9 _\" is required" end
  local n = tonumber(a.number)
  if not n or n ~= math.floor(n) or n <= FREEDOM or n > MAX_NUMBER then
    return nil, string.format("%s %s: number = %s: 7..%d (0-5 are the game's builds, 6 «Libertad»)", where, a.name, tostring(a.number), MAX_NUMBER)
  end
  local ranks = {}
  if type(a.rank_charges) ~= "table" or #a.rank_charges == 0 then return nil, where .. " " .. a.name .. ": rank_charges = [ … ] (ascending charges of ranks 1, 2, …) is required" end
  for j, c in ipairs(a.rank_charges) do
    c = tonumber(c)
    if not c or c <= 0 or (j > 1 and c <= ranks[j - 1]) then return nil, where .. " " .. a.name .. ": rank_charges must be positive and ascending" end
    ranks[j] = c
  end
  local x = {
    key = tostring(mod) .. "." .. a.name, mod = mod, number = n,
    label = a.label and id_of(a.label) or 0, description = a.description and id_of(a.description) or 0,
    icon = a.icon and id_of(a.icon) or 0, icon_large = a.icon_large and id_of(a.icon_large) or 0,
    gauge_icon = a.gauge_icon and id_of(a.gauge_icon) or 0,
    passives = {}, ranks = ranks, max_charge = ranks[#ranks], start = math.max(0, tonumber(a.start_charge) or 0), rules = {},
  }
  x.start = math.min(x.start, x.max_charge)
  for _, p in ipairs(type(a.passives) == "table" and a.passives or {}) do
    local id = id_of(p)
    if id then x.passives[#x.passives + 1] = id end
  end
  for j, c in ipairs(type(a.charge) == "table" and a.charge or {}) do
    for k in pairs(c) do
      if not CHARGE_KEYS[k] then return nil, string.format("%s %s: charge #%d: unknown key `%s`", where, a.name, j, tostring(k)) end
    end
    if not EVENTS[c.on] then return nil, string.format("%s %s: charge #%d: on = %q (shot_on_target, goal, conceded, shot, no_shot)", where, a.name, j, tostring(c.on)) end
    local add = tonumber(c.add)
    if not add then return nil, string.format("%s %s: charge #%d: add = <number> is required", where, a.name, j) end
    local every = tonumber(c.every_s)
    if c.on == "no_shot" and not (every and every > 0) then return nil, string.format("%s %s: charge #%d: no_shot needs every_s > 0", where, a.name, j) end
    x.rules[#x.rules + 1] = { on = c.on, add = add, every = every }
  end
  return x
end

local function load_decls()
  local ok, files = pcall(VRFW.files.declarations, "content/archetypes")
  if not ok or type(files) ~= "table" then return end
  for _, f in ipairs(files) do
    local d = f.data or {}
    if d.schema ~= nil and d.schema ~= "VRFW.archetype/1" then
      warn(string.format("mods/%s/%s: schema %q is not VRFW.archetype/1: file left out", tostring(f.mod), tostring(f.file), tostring(d.schema)))
    else
      local arr = (type(d.VRFW) == "table" and d.VRFW.Archetype) or {}
      for i, a in ipairs(arr) do
        local x, why = read_decl(f.mod, f.file, a, i)
        if not x then
          warn(why .. ": left out")
        elseif DECL[x.number] then
          warn(string.format("%s: number %d is %s's already: left out", x.key, x.number, DECL[x.number].key))
        else
          DECL[x.number] = x
          LIST[#LIST + 1] = x
          for _, p in ipairs(x.passives) do PASS_ARCH[p] = x.number end
        end
      end
    end
  end
end

load_decls()

-- ---------------------------------------------------------------------------------------------- passive tables

local EFF_FOCUS = crc("vrfw_eff_focus_per_team_event")
local EFF_TEAM_AT = crc("vrfw_eff_team_shot_at_per_rank")
local EFF_DRAIN = crc("vrfw_eff_resource_drain_per_rank")

local ROWS = {}          -- passive id -> { { def, value } }
local DEFS = {}          -- def id -> { event, target, cap, effects = { { basic, p1 } } }
local BY_DEF = {}        -- def id -> archetype number (a declared passive's first effect row)
local RES_KEY = {}       -- crc32(resource key) -> key
local ANY_FX = false     -- some passive has a row of the framework's archetype effects

local function number(v)
  if type(v) ~= "number" then return nil end
  if v == math.floor(v) and u32(v) == INVALID then return nil end
  return v
end

local function load_tables()
  local pk = "data/common/gamedata/skill/passive_skill_config_*.cfg.bin"
  local ents = VRFW.table.entries(pk, { "PASSIVE_SKILL_EFFECT", "PASSIVE_SKILL_INFO", "PASSIVE_SKILL_INFO_REF_EFFECT" }, true)
  local rows = {}
  for _, e in ipairs(ents) do
    if e.name == "PASSIVE_SKILL_EFFECT" then rows[#rows + 1] = { u32(e[1]), number(e[2]) or 0 } end
  end
  for i, e in ipairs(ents) do
    if e.name == "PASSIVE_SKILL_INFO" and type(e[1]) == "number" then
      for j = i + 1, math.min(i + 2, #ents) do
        local r = ents[j]
        if r.name == "PASSIVE_SKILL_INFO_REF_EFFECT" then
          local off, cnt = tonumber(r[1]) or 0, tonumber(r[2]) or 0
          local v = {}
          for k = 0, cnt - 1 do
            if rows[off + k + 1] then v[#v + 1] = rows[off + k + 1] end
          end
          if #v > 0 then ROWS[u32(e[1])] = v end
          break
        end
      end
    end
  end
  ents, rows = nil, nil
  local ek = "data/common/gamedata/soccer/passive_skill_effect_config_*.cfg.bin"
  local P = "PASSIVE_SKILL_EFFECT_INFO"
  local ee = VRFW.table.entries(ek, { P, P .. "_EXEC_TIMING_DATA", P .. "_TARGET_DATA", P .. "_EFFECT_DATA", P .. "_GRAND_TOTAL_INFO", P .. "_LIST_END" }, true)
  local cur
  for _, e in ipairs(ee) do
    local n = e.name
    if n == P then
      cur = { event = 0, target = 0, cap = 0, effects = {} }
      DEFS[u32(e[1])] = cur
    elseif n == P .. "_LIST_END" then
      cur = nil
    elseif cur then
      if n == P .. "_EXEC_TIMING_DATA" then cur.event = u32(e[1])
      elseif n == P .. "_TARGET_DATA" then cur.target = u32(e[1])
      elseif n == P .. "_EFFECT_DATA" then cur.effects[#cur.effects + 1] = { u32(e[1]), number(e[2]) }
      elseif n == P .. "_GRAND_TOTAL_INFO" then cur.cap = number(e[3]) or 0
      end
    end
  end
  for _, x in ipairs(LIST) do
    local n = 0
    for _, p in ipairs(x.passives) do
      local r = ROWS[p]
      if r and r[1] then
        BY_DEF[r[1][1]] = x.number
        n = n + 1
      else
        warn(string.format("%s: passive 0x%08X is not in the installed passive_skill_config: it scores nothing", x.key, p))
      end
    end
    x.n_passives = n
  end
  for _, v in pairs(ROWS) do
    for _, r in ipairs(v) do
      local d = DEFS[r[1]]
      if d and d.event == LOADER_EVENT then
        for _, ef in ipairs(d.effects) do
          if ef[1] == EFF_FOCUS or ef[1] == EFF_TEAM_AT or ef[1] == EFF_DRAIN then ANY_FX = true end
        end
      end
    end
  end
  local okr, res = pcall(VRFW.files.declarations, "content/match_resources")
  if okr and type(res) == "table" then
    for _, f in ipairs(res) do
      local arr = (type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW.MatchResource) or {}
      for _, r in ipairs(arr) do
        if type(r.name) == "string" then
          local key = tostring(f.mod) .. "." .. r.name
          RES_KEY[crc(key)] = key
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------------------------- team picks

local PENDING = nil      -- the selector of the pick being counted: { key, side }
local PICK = {}          -- selector key -> { build, points }
local LAST_MENU = nil    -- the last menu pick's key
local logs = 0

local function sel_key(addr)
  local b0, b1, b2, b3 = rd("u8", addr), rd("u8", addr + 1), rd("u8", addr + 2), rd("u8", addr + 3)
  if not b0 then return nil end
  if b3 ~= 0 then return { key = "m" .. tostring(b2), side = b2 } end
  return { key = "d" .. b0 .. "_" .. b1 }
end

-- the engine's winner rule over counts c[0..n]: strictly most points, at least 1; else FREEDOM
local function winner(counts)
  local best, who, tie = 0, FREEDOM, false
  for b, c in pairs(counts) do
    if c > best then best, who, tie = c, b, false
    elseif c == best and c > 0 then tie = true end
  end
  if tie or best <= 0 then return FREEDOM, best end
  return who, best
end

-- the match part (below) gets the match sides' picks
local MATCH = {}

if #LIST > 0 then
  VRFW.on("hook:ArchBuildSelector", function(ev)
    local rdi = ev.regs and ev.regs.rdi
    PENDING = rdi and sel_key(rdi) or nil
    return nil
  end)

  VRFW.on("hook:ArchBuildCounts", function(ev)
    local sel = PENDING
    PENDING = nil
    local regs = ev.regs or {}
    local list, rbp = regs.r13, regs.rbp
    if not list or not rbp then return nil end
    local counts, custom = {}, {}
    for b = 0, N_GAME - 1 do counts[b] = rd("u32", rbp + 7 + 4 * b) or 0 end
    local n = rd("u32", list + 8) or 0
    for i = 0, math.min(n, 256) - 1 do
      local e = rd("ptr", list + 0x10 + 8 * i)
      if e and e >= 0x10000 then
        local a = BY_DEF[rd("u32", e) or 0]
        if a then custom[a] = (custom[a] or 0) + (rd("u32", e + 0xC) or 0) end
      end
    end
    local all = {}
    for b = 0, N_GAME - 1 do all[b] = counts[b] end
    for a, c in pairs(custom) do all[a] = c end
    local build = winner(all)
    if build > FREEDOM then
      for b = 0, N_GAME - 1 do pcall(VRFW.mem.write, "u32", rbp + 7 + 4 * b, 0) end
    end
    if sel then
      PICK[sel.key] = { build = build, points = all[build] or 0 }
      if sel.side ~= nil then
        MATCH.set_side(sel.side, build)
      else
        LAST_MENU = sel.key
      end
      if logs < 40 and (build > FREEDOM or next(custom) ~= nil) then
        logs = logs + 1
        local parts = {}
        for b = 0, MAX_NUMBER do
          if all[b] and all[b] > 0 then parts[#parts + 1] = b .. "=" .. all[b] end
        end
        info(string.format("pick %s: points {%s} -> build %d%s", sel.key, table.concat(parts, " "), build, DECL[build] and (" (" .. DECL[build].key .. ")") or ""))
      end
    end
    return nil
  end)
end

-- ---------------------------------------------------------------------------------------------- match state

local SIDE = {}          -- side -> { build, charge, rank, idle, events = { name = n } }
local last_owner_side = nil
local dirty, since = true, 0

local function new_side(build)
  local x = DECL[build]
  return { build = build, charge = x and x.start or 0, rank = 0, idle = 0, events = {} }
end

local function rank_of(x, charge)
  local r = 0
  for _, c in ipairs(x.ranks) do
    if charge >= c then r = r + 1 end
  end
  return r
end

local function publish(side)
  local s = SIDE[side]
  local build = s and s.build or nil
  local rank = s and s.rank or 0
  pcall(VRFW.state.set, "vr_framework.archetype.team" .. side, build)
  pcall(VRFW.state.set, "vr_framework.archetype.rank" .. side, build and rank or nil)
  if build then
    pcall(VRFW.native.table_set, "Archetype.Team", side, build)
    pcall(VRFW.native.table_set, "Archetype.Rank", side, rank)
  else
    pcall(VRFW.native.table_set, "Archetype.Team", side, nil)
    pcall(VRFW.native.table_set, "Archetype.Rank", side, nil)
  end
end

MATCH.set_side = function(side, build)
  if side ~= 0 and side ~= 1 then return end
  local s = SIDE[side]
  if s and s.build == build then return end
  local events = s and s.events or {}
  SIDE[side] = new_side(build)
  SIDE[side].events = events
  local x = DECL[build]
  if x then SIDE[side].rank = rank_of(x, SIDE[side].charge) end
  publish(side)
  dirty = true
end

local function side_of(ev_arg, m)
  if ev_arg == "team0" then return 0 end
  if ev_arg == "team1" then return 1 end
  local u = m and m.user_team
  if u ~= 0 and u ~= 1 then return nil end
  if ev_arg == "user" then return u end
  if ev_arg == "rival" then return 1 - u end
  return nil
end

local function add_charge(side, amount, why)
  local s = SIDE[side]
  local x = s and DECL[s.build]
  if not x then return end
  local c = math.max(0, math.min(x.max_charge, s.charge + amount))
  if c == s.charge then return end
  local r = rank_of(x, c)
  s.charge = c
  if r ~= s.rank then
    info(string.format("side %d %s: %s -> charge %g, rank %d -> %d", side, x.key, why, c, s.rank, r))
    s.rank = r
    publish(side)
    dirty = true
  end
end

local function fire(side, name)
  if side ~= 0 and side ~= 1 then return end
  local s = SIDE[side]
  if not s then
    SIDE[side] = new_side(FREEDOM)
    s = SIDE[side]
  end
  s.events[name] = (s.events[name] or 0) + 1
  if name == "shot" or name == "shot_on_target" then s.idle = 0 end
  dirty = true
  local x = DECL[s.build]
  if not x then return end
  for _, r in ipairs(x.rules) do
    if r.on == name then add_charge(side, r.add, name) end
  end
end

local function reset_match()
  for side = 0, 1 do
    local s = SIDE[side]
    if s then
      local x = DECL[s.build]
      s.charge = x and x.start or 0
      s.rank = x and rank_of(x, s.charge) or 0
      s.idle, s.events = 0, {}
      publish(side)
    end
  end
  last_owner_side = nil
  dirty, since = true, 0
end

-- ---------------------------------------------------------------------------------------------- effects

local ID_CACHE = {}      -- actor handle -> { chara, ids }
local BUF_ID, BUF_VER, BUF_OUT
local applied_mult = {}  -- "key|hdl" -> mult
local had_tables = false

-- the passives a match player carries (5 slots, 0 = none), read as the match builder does
local function slot_ids(chara)
  if not chara or chara == 0 then return nil end
  local rec = VRFW.chara.record(chara)
  if not rec then return nil end
  if not BUF_ID then
    BUF_ID = VRFW.mem.buffer("arch_pid", 4)
    BUF_VER = VRFW.mem.buffer("arch_pver", 4)
    BUF_OUT = VRFW.mem.buffer("arch_pout", 8)
  end
  local out = {}
  for k = 0, N_SLOTS - 1 do
    out[k + 1] = 0
    local ok, unlocked = pcall(VRFW.call, "ArchPassiveUnlocked", chara, k, 1)
    if ok and unlocked ~= 0 then
      VRFW.mem.write("u32", BUF_ID, 0)
      if pcall(VRFW.call, "ArchPassiveId", BUF_ID, chara, k, 1) then
        local id = rd("u32", BUF_ID) or 0
        if id ~= 0 then
          local v = id
          VRFW.mem.write("u32", BUF_VER, id)
          VRFW.mem.write("ptr", BUF_OUT, 0)
          if pcall(VRFW.call, "ArchPassiveRarity", BUF_OUT, BUF_VER, rec.rarity or 0) then
            local p = rd("ptr", BUF_OUT) or 0
            local x = p >= 0x10000 and (rd("u32", p) or 0) or 0
            if x ~= 0 then v = x end
          end
          out[k + 1] = v
        end
      end
    end
  end
  return out
end

-- every actor on the pitch: { hdl, side, ids }
local function lineup()
  local base = VRFW.game.arch_actors()
  if not base or base == 0 then return nil end
  local v = {}
  for i = 0, ACTOR_MAX - 1 do
    local actor = base + i * ACTOR_STRIDE
    local hdl = rd("u32", actor + ACTOR_HDL) or 0
    local side = rd("u8", actor + ACTOR_TEAM) or 0xFF
    if hdl ~= 0 and side <= 1 and VRFW.actor(hdl) ~= nil then
      local ok, unit = pcall(VRFW.call, "ArchActorUnit", actor)
      local chara = (ok and type(unit) == "number" and unit >= 0x10000) and (rd("u32", unit + UNIT_CHARA) or 0) or 0
      local c = ID_CACHE[hdl]
      if not c or c.chara ~= chara then
        c = { chara = chara, ids = slot_ids(chara) or {} }
        ID_CACHE[hdl] = c
      end
      v[#v + 1] = { hdl = hdl, side = side, ids = c.ids }
    end
  end
  return v
end

local function each_effect(ids, f)
  for _, id in ipairs(ids) do
    if id ~= 0 then
      for _, r in ipairs(ROWS[id] or {}) do
        local d = DEFS[r[1]]
        if d and d.event == LOADER_EVENT then
          for _, ef in ipairs(d.effects) do f(id, r[2], ef[1], ef[2], r[1]) end
        end
      end
    end
  end
end

local function rank_for(side, arch)
  local s = SIDE[side]
  if not s or not arch or s.build ~= arch then return 0 end
  return s.rank
end

-- per definition and target: the sum of its carriers' contributions, capped by the definition's team cap
-- (GRAND_TOTAL_INFO column 2, in the effect's unit; 0 = no cap), then summed over the definitions
local function capped(acc, def, target, add)
  local t = acc[target]
  if not t then t = {}; acc[target] = t end
  t[def] = (t[def] or 0) + add
end

local function total(acc, target, mode)
  local v = mode == "mult" and 1 or 0
  for def, x in pairs(acc[target] or {}) do
    local cap = DEFS[def] and DEFS[def].cap or 0
    if cap > 0 and x > cap then x = cap end
    if mode == "mult" then v = v * math.max(0, 1 - x / 100) else v = v + x / 100 end
  end
  return v
end

local function refresh()
  local players = lineup()
  if not players then return end
  local shot, focus, drain = {}, {}, {}
  for _, p in ipairs(players) do
    each_effect(p.ids, function(passive, value, basic, p1, def)
      if basic == EFF_FOCUS then
        local ev = EVENT_CODE[p1 and math.floor(p1) or 1] or "shot_on_target"
        local s = SIDE[p.side]
        local n = s and s.events[ev] or 0
        if n > 0 then capped(focus, def, p.hdl, value * n) end
      elseif basic == EFF_TEAM_AT then
        local r = rank_for(p.side, PASS_ARCH[passive] or (p1 and math.floor(p1)))
        if r > 0 then
          for _, q in ipairs(players) do
            if q.side == p.side then capped(shot, def, q.hdl, value * r) end
          end
        end
      elseif basic == EFF_DRAIN then
        local key = p1 and RES_KEY[u32(p1)]
        local r = rank_for(p.side, PASS_ARCH[passive])
        if key and r > 0 then capped(drain, def, key .. "|" .. p.hdl, value * r) end
      end
    end)
  end
  local e1, e2 = {}, {}
  for h in pairs(shot) do e1[#e1 + 1] = { h, total(shot, h) } end
  for h in pairs(focus) do e2[#e2 + 1] = { h, total(focus, h) } end
  pcall(VRFW.native.table_replace, "Archetype.ShotAt", nil, e1)
  pcall(VRFW.native.table_replace, "Archetype.Focus", nil, e2)
  had_tables = #e1 > 0 or #e2 > 0
  local mult = {}
  for k in pairs(drain) do mult[k] = total(drain, k, "mult") end
  for k in pairs(applied_mult) do
    if mult[k] == nil then
      local key, hdl = k:match("^(.*)|(%d+)$")
      pcall(VRFW.resource.set_mult, key, tonumber(hdl), SOURCE, 1)
      applied_mult[k] = nil
    end
  end
  for k, m in pairs(mult) do
    if applied_mult[k] ~= m then
      local key, hdl = k:match("^(.*)|(%d+)$")
      if pcall(VRFW.resource.set_mult, key, tonumber(hdl), SOURCE, m) then applied_mult[k] = m end
    end
  end
end

local function clear_effects()
  if had_tables then
    pcall(VRFW.native.table_clear, "Archetype.ShotAt")
    pcall(VRFW.native.table_clear, "Archetype.Focus")
    had_tables = false
  end
  applied_mult, ID_CACHE = {}, {}
end

-- ---------------------------------------------------------------------------------------------- match events

local function start()
  if #LIST == 0 then return false end
  local ok, e = pcall(load_tables)
  if not ok then warn("passive tables not readable: " .. tostring(e) .. " (no points, no effects)") end
  local names = {}
  for _, x in ipairs(LIST) do
    names[#names + 1] = string.format("%s = %d (%d passive(s), ranks %s, %d charge rule(s))", x.key, x.number, x.n_passives or 0, table.concat(x.ranks, "/"), #x.rules)
  end
  info(string.format("%d archetype(s): %s; pick hooks %s; effects %s", #LIST, table.concat(names, "; "),
    (VRFW.is_on("ArchBuildSelector") and VRFW.is_on("ArchBuildCounts")) and "on" or "OFF (not installed)",
    ANY_FX and "in use" or "none declared"))
  return true
end

local ON = start()

if ON then
  VRFW.on("match_start", function() reset_match() end)

  VRFW.on("match_end", function()
    clear_effects()
    for side = 0, 1 do
      SIDE[side] = nil
      publish(side)
    end
  end)

  VRFW.on("possession", function(ev)
    if ev.actor and (ev.actor.team == 0 or ev.actor.team == 1) then last_owner_side = ev.actor.team end
  end)

  VRFW.on("shot_start", function() if last_owner_side then fire(last_owner_side, "shot") end end)

  -- every shot that reaches a keeper (saved or beaten): the keeper's rival side shot on target
  VRFW.on("keeper_scene", function(ev)
    local t = ev.actor and ev.actor.team
    if t == 0 or t == 1 then fire(1 - t, "shot_on_target") end
  end)

  VRFW.on("goal", function(ev)
    local side = side_of(ev.arg, ev.match)
    if side then
      fire(side, "goal")
      fire(1 - side, "conceded")
    end
  end)

  VRFW.on("tick", function(ev)
    local m = ev.match or {}
    local dt = tonumber(m.dt) or 0
    if LIVE[m.soccer_state or 0] and dt > 0 and dt < 1 then
      for side = 0, 1 do
        local s = SIDE[side]
        local x = s and DECL[s.build]
        if x then
          s.idle = s.idle + dt
          for _, r in ipairs(x.rules) do
            if r.on == "no_shot" and s.idle >= r.every then
              s.idle = s.idle - r.every
              add_charge(side, r.add, "no_shot")
            end
          end
        end
      end
    end
    if ANY_FX then
      since = since + math.max(dt, 0)
      if dirty or since >= REFRESH_S then
        dirty, since = false, 0
        refresh()
      end
    end
  end)
end

-- ---------------------------------------------------------------------------------------------- S6: shared passive entries
-- VRFW 2.3 service S6 «passives & team builds» (docs/framework/archetype.md §4.1-4.2). VRFW owns one detour on each
-- passive entry (content\game\archetype.toml); what they answer comes from the tables other mods export
-- (mod.toml [exports] tables, read natively as `*/<name>`, the mod that loads last first). The exec condition resolver
-- (Passive.ResolveExecCondition) runs, in today's order: a not yet migrated mod's own detour on the entry (the loader
-- chains it first: installed after VRFW's), then the exported Passive.ExecCondition tables, then VRFW's 910 / 911, then
-- the game's table. The boot log shows that order with each subscriber's ids and warns when one id is answered twice
-- (the first in run order wins). For the slot readers and the rarity version it lists the exporters of their tables and
-- the mods that still keep their own detour.

local E = require "lib/game_entries"

local EXEC_ENTRY = "Passive.ResolveExecCondition"
local EXEC_TABLE = "Passive.ExecCondition"
local PASSIVE_ENTRIES = {
  { "Passive.TeamPassiveId", { "Passive.SlotChoice", "Passive.OwnSlot", "Passive.OwnKept" } },
  { "Passive.TeamPassiveUnlocked", { "Passive.SlotUnlock", "Passive.AllOpen", "Passive.OwnOpen", "Passive.OwnKept" } },
  { "Passive.RarityVersion", { "Passive.RarityTwin", "Passive.RarityTier" } },
}

local function shared_entries()
  local owner, parts = {}, {}
  local function take(label, ids)
    local shown = {}
    for _, id in ipairs(ids) do
      shown[#shown + 1] = tostring(id)
      if owner[id] then
        warn(string.format("exec condition %d: answered by %s and by %s: %s runs first and wins (one subscriber per id)",
          id, owner[id], label, owner[id]))
      else
        owner[id] = label
      end
    end
    return #shown > 0 and table.concat(shown, ", ") or "ids set by its scripts"
  end
  local own = nil
  -- the mods' own detours (not migrated yet) run first, then VRFW's detour
  for _, s in ipairs(E.run_order(E.declarers(EXEC_ENTRY))) do
    if s.mod == VRFW.mod then
      own = s
    else
      parts[#parts + 1] = string.format("%s [%s] (own detour%s)", E.label(s), take(E.label(s), E.answered_values(s.decl, 1)),
        s.decl.game == nil and ", inline signature" or "")
    end
  end
  for _, m in ipairs(E.exporters(EXEC_TABLE)) do
    local label = m .. "/" .. EXEC_TABLE
    parts[#parts + 1] = string.format("%s [%s]", label, take(label, E.table_keys(m, EXEC_TABLE)))
  end
  if own then parts[#parts + 1] = string.format("%s [%s]", E.label(own), take(E.label(own), E.answered_values(own.decl, 1))) end
  info(string.format("exec conditions (%s), run order: %s > game%s", EXEC_ENTRY, table.concat(parts, " > "),
    E.reference() and "" or " (reference profile not readable: inline declarations not matched)"))
  for _, e in ipairs(PASSIVE_ENTRIES) do
    local name, tables = e[1], e[2]
    local others = {}
    for _, s in ipairs(E.run_order(E.declarers(name))) do
      if s.mod ~= VRFW.mod then others[#others + 1] = E.label(s) end
    end
    local data = {}
    for _, t in ipairs(tables) do
      local ex = E.exporters(t)
      if #ex > 0 then data[#data + 1] = t .. " <- " .. table.concat(ex, ", ") end
    end
    info(string.format("passive entry %s: %s%s; exported data: %s", name,
      #others > 0 and (table.concat(others, " > ") .. " (own detour, before VRFW's) > ") or "",
      "vr_framework", #data > 0 and table.concat(data, "; ") or "none (the game's answer)"))
  end
end

do
  local ok, e = pcall(shared_entries)
  if not ok then warn("shared passive entries not reported: " .. tostring(e)) end
end

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_VRFW_ARCHETYPE_TEAM(dock, party) -> build (0-6 the game's, 7+ declared), points; no args = the last menu pick.
-- -1 = not picked yet (the menus ask the game's command first: that pick is the one answered).
function Archetype.CmdTeam(dock, party)
  local key = LAST_MENU
  if dock ~= nil and party ~= nil then key = "d" .. math.floor(tonumber(dock) or 0) .. "_" .. math.floor(tonumber(party) or 0) end
  local p = key and PICK[key]
  if not p then return -1, 0 end
  return p.build, p.points
end

-- CMND_VRFW_ARCHETYPE_MATCH(side) -> build, rank, charge, max charge (-1 = no match / not picked)
function Archetype.CmdMatch(side)
  local s = SIDE[math.floor(tonumber(side) or -1)]
  if not s then return -1, 0, 0, 0 end
  local x = DECL[s.build]
  return s.build, s.rank, s.charge, x and x.max_charge or 0
end

-- CMND_VRFW_ARCHETYPE_INFO(build) -> ok, name text id, description text id, icon, large icon, gauge icon
function Archetype.CmdInfo(build)
  local x = DECL[math.floor(tonumber(build) or -1)]
  if not x then return false, 0, 0, 0, 0, 0 end
  return true, x.label, x.description, x.icon, x.icon_large, x.gauge_icon
end
