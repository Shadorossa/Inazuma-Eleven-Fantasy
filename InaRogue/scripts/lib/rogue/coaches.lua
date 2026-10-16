-- InaRogue › INAROGUE coaches (docs/game/modes/inarogue.md «Entrenadores»). Was coaches.rs / coaches_rt.rs of
-- the DLL's module rogue. The coach picked at the start of a NEW run is the run's «class»: typed effects declared in
-- content\rogue\coaches.toml ([rogue.coaches] file); unlock rules are counters of the global unlock store (unlocks.lua).
--
-- Effects: stat_mult (the match copy of the run's players: applied by the plugin's stats hook, which reads the
-- multipliers this script publishes, see publish_stats), node_weight (map content weights), reward_mult (fragments /
-- Rogue points), start_points, start_item; technique_cost and match_rule are declared kinds without an engine hook yet.

local U = require "lib/rogue/util"
local unlocks = require "lib/rogue/unlocks"
local info, warn = U.logger("rogue coaches")

local Co = {}

Co.SCHEMA = "inazuma_fantasy.rogue_coaches/1"
Co.STATS = { "kick", "control", "technique", "pressure", "physical", "intelligence", "agility" }

local POSITION = { gk = 1, por = 1, portero = 1, fw = 2, del = 2, delantero = 2, mf = 3, cen = 3, centrocampista = 3,
  df = 4, def = 4, defensa = 4 }
local ELEMENT = { viento = 1, wind = 1, bosque = 2, forest = 2, wood = 2, fuego = 3, fire = 3, ["montaña"] = 4,
  montana = 4, mountain = 4, earth = 4 }
local CONTENT = { cofre = 1, chest = 1, tienda = 2, shop = 2, evento = 3, event = 3, fichaje = 4, recruit = 4, gacha = 5,
  elite = 6, ["élite"] = 6, tragaperras = 7, slots = 7 }

local function num(t, k)
  local v = t[k]
  if type(v) == "number" then return v end
  return nil
end

-- one effect table -> its effect, or nil + why
function Co.parse_effect(t)
  local kind = t.kind
  if type(kind) ~= "string" then return nil, "effect without `kind`" end
  local function value(k)
    local v = num(t, k)
    if not v or v ~= v or v < 0 or v == math.huge then return nil, kind .. ": `" .. k .. "` must be a number >= 0" end
    return v
  end
  if kind == "stat_mult" then
    local target = t.target or "team"
    local tg = { kind = "team" }
    if target == "position" then
      local p = POSITION[string.lower(tostring(t.position or ""))]
      if not p then return nil, "stat_mult: position = GK / DF / MF / FW" end
      tg = { kind = "position", v = p }
    elseif target == "element" then
      local e = ELEMENT[U.lower(tostring(t.element or ""))]
      if not e then return nil, "stat_mult: element = viento / bosque / fuego / montaña" end
      tg = { kind = "element", v = e }
    elseif target ~= "team" then
      return nil, "stat_mult: target `" .. tostring(target) .. "` (team / position / element)"
    end
    local stat = nil
    local w = t.stat or "all"
    if w ~= "all" then
      stat = U.index_of(Co.STATS, w)
      if not stat then return nil, "stat_mult: stat `" .. tostring(w) .. "` (all / " .. table.concat(Co.STATS, " / ") .. ")" end
    end
    local v, why = value("value")
    if not v then return nil, why end
    return { kind = "stat_mult", target = tg, stat = stat, value = v }
  elseif kind == "node_weight" then
    local node = tostring(t.node or "")
    local c = CONTENT[U.lower(node)]
    if not c then return nil, "node_weight: node `" .. node .. "` (cofre / tienda / evento / fichaje / gacha / elite / tragaperras)" end
    local v, why = value("mult")
    if not v then return nil, why end
    return { kind = "node_weight", content = c, mult = v }
  elseif kind == "reward_mult" then
    local r = t.reward or "all"
    if r ~= "frags" and r ~= "points" and r ~= "all" then return nil, "reward_mult: reward `" .. tostring(r) .. "` (frags / points / all)" end
    local v, why = value("value")
    if not v then return nil, why end
    return { kind = "reward_mult", reward = r, value = v }
  elseif kind == "start_points" then
    local v = num(t, "value")
    if not v or v < 0 then return nil, "start_points: `value` (integer)" end
    return { kind = "start_points", value = U.int(v, 0) }
  elseif kind == "start_item" then
    local item = type(t.item) == "string" and t.item or ""
    local id = num(t, "id") or 0
    if item == "" and id == 0 then return nil, "start_item: `item` (registry key) or `id`" end
    return { kind = "start_item", item = item, id = id, count = math.max(U.int(t.count, 1), 1) }
  elseif kind == "technique_cost" then
    local v, why = value("mult")
    if not v then return nil, why end
    return { kind = "technique_cost", mult = v, pending = true }
  elseif kind == "match_rule" then
    return { kind = "match_rule", rule = tostring(t.rule or ""), pending = true }
  end
  return { kind = kind, unknown = true }
end

local cat = nil

local FIELDS = { id = true, name = true, tagline = true, param = true, face = true, bust = true, hint = true, unlock = true,
  effects = true }

local function parse(t)
  if t.schema ~= Co.SCHEMA then return nil, "schema `" .. tostring(t.schema) .. "` (expected `" .. Co.SCHEMA .. "`)" end
  local warns, ids, coaches = {}, {}, {}
  for _, c in ipairs(type(t.coach) == "table" and t.coach or {}) do
    for k in pairs(c) do
      if not FIELDS[k] then return nil, "coach `" .. tostring(c.id) .. "`: unknown field `" .. tostring(k) .. "`" end
    end
    local id = type(c.id) == "string" and c.id or ""
    if id == "" or id:find("[^a-z0-9_]") then return nil, "coach id `" .. id .. "`: a-z 0-9 _" end
    if ids[id] then return nil, "coach `" .. id .. "` declared twice" end
    ids[id] = true
    if type(c.name) ~= "string" or type(c.face) ~= "string" then return nil, "coach `" .. id .. "`: name and face are required" end
    local unlock = {}
    for _, u in ipairs(type(c.unlock) == "table" and c.unlock or {}) do
      local r, why = unlocks.parse_cond(u)
      if not r then return nil, "coach `" .. id .. "`: " .. why end
      if unlocks.is_event(r) then
        return nil, "coach `" .. id .. "`: unlock rule " .. r.type .. " is an event rule (only counters: coach_runs_won, coach_boss_phase, coach_wins, wins, bosses, runs, runs_won, phase, album)"
      end
      unlock[#unlock + 1] = r
    end
    local effects = {}
    for k, e in ipairs(type(c.effects) == "table" and c.effects or {}) do
      local x, why = Co.parse_effect(type(e) == "table" and e or {})
      if not x then
        warns[#warns + 1] = string.format("coach `%s` effect %d: %s (ignored)", id, k, why)
      else
        if x.unknown then warns[#warns + 1] = string.format("coach `%s` effect %d: unknown kind `%s` (ignored)", id, k, x.kind) end
        effects[#effects + 1] = x
      end
    end
    coaches[#coaches + 1] = { id = id, name = c.name, tagline = U.trim(c.tagline or ""), param = U.int(c.param, 0) % U.TWO32,
      face = c.face, hint = U.trim(c.hint or ""), unlock = unlock, effects = effects }
  end
  local k = { coaches = coaches }
  for _, c in ipairs(coaches) do
    for _, u in ipairs(c.unlock) do
      if u.coach ~= "" and not Co.index_of(k, u.coach) then
        warns[#warns + 1] = string.format("coach `%s`: unlock rule names an unknown coach `%s`", c.id, u.coach)
      end
    end
  end
  return k, warns
end

function Co.index_of(k, id)
  for i, c in ipairs(k.coaches) do
    if c.id == id then return i - 1 end
  end
  return nil
end

function Co.by_id(k, id)
  for _, c in ipairs(k.coaches) do
    if c.id == id then return c end
  end
  return nil
end

-- the default coach: the first one without unlock rules (else the first one)
function Co.default_coach(k)
  for _, c in ipairs(k.coaches) do
    if #c.unlock == 0 then return c end
  end
  return k.coaches[1]
end

function Co.of_run(k, id)
  return Co.by_id(k, id) or Co.default_coach(k)
end

function Co.catalogue(ccfg)
  if cat then return cat end
  cat = { coaches = {} }
  local ok, t = pcall(VRFW.files.toml, ccfg.file)
  if not ok or type(t) ~= "table" then
    warn(ccfg.file .. ": " .. tostring(t) .. "; no coaches")
  else
    local k, warns = parse(t)
    if not k then
      warn(ccfg.file .. ": " .. warns .. "; no coaches")
    else
      for _, w in ipairs(warns) do warn(ccfg.file .. ": " .. w) end
      cat = k
    end
  end
  for _, c in ipairs(cat.coaches) do
    for _, e in ipairs(c.effects) do
      if e.pending then info("coach " .. c.id .. ": effect " .. e.kind .. " is declared but has no engine hook yet (ignored)") end
    end
  end
  local d = Co.default_coach(cat)
  info(string.format("%d coaches (default %s), enabled %s unlock_all %s", #cat.coaches, d and d.id or "-",
    tostring(ccfg.enabled), tostring(ccfg.unlock_all)))
  return cat
end

-- ---------------------------------------------------------------------------------------- effects

function Co.is_unlocked(c, s)
  for _, u in ipairs(c.unlock) do
    if unlocks.cond_met(s, u) ~= true then return false end
  end
  return true
end

-- multipliers of the 7 engine stats (+ [8] = 1.0) for a player of `position` / `element`
function Co.stat_mults(c, position, element)
  local m = { 1, 1, 1, 1, 1, 1, 1, 1 }
  for _, e in ipairs(c.effects) do
    if e.kind == "stat_mult" then
      local hit = e.target.kind == "team" or (e.target.kind == "position" and e.target.v == position)
        or (e.target.kind == "element" and e.target.v == element)
      if hit then
        if e.stat then
          m[e.stat] = m[e.stat] * e.value
        else
          for i = 1, 7 do m[i] = m[i] * e.value end
        end
      end
    end
  end
  return m
end

function Co.has_stat_mults(c)
  for _, e in ipairs(c.effects) do
    if e.kind == "stat_mult" then return true end
  end
  return false
end

-- weight multiplier per map content type (1..7); nil = the coach changes no weight
function Co.content_mults(c)
  local m, any = {}, false
  for i = 1, 7 do m[i] = 1.0 end
  for _, e in ipairs(c.effects) do
    if e.kind == "node_weight" and m[e.content] then
      m[e.content] = m[e.content] * e.mult
      any = true
    end
  end
  if any then return m end
  return nil
end

function Co.reward_mult(c, r)
  local p = 1.0
  for _, e in ipairs(c.effects) do
    if e.kind == "reward_mult" and (e.reward == r or e.reward == "all") then p = p * e.value end
  end
  return p
end

function Co.start_points(c)
  local n = 0
  for _, e in ipairs(c.effects) do
    if e.kind == "start_points" then n = n + e.value end
  end
  return n
end

function Co.start_items(c)
  local o = {}
  for _, e in ipairs(c.effects) do
    if e.kind == "start_item" then o[#o + 1] = { e.item, e.id, e.count } end
  end
  return o
end

-- n x mult, rounded (1.0 = unchanged exactly)
function Co.scaled(n, mult)
  if math.abs(mult - 1.0) < 1e-7 then return n end
  return U.round(n * math.max(mult, 0))
end

-- a rule in Spanish with the coaches' names
function Co.describe(k, cond)
  return unlocks.describe(cond, function(id)
    local c = Co.by_id(k, id)
    return c and c.name or id
  end)
end

-- the locked coach's hint with the counters' progress
function Co.hint(k, c, s)
  local h
  if c.hint == "" then
    local parts = {}
    for i, u in ipairs(c.unlock) do parts[i] = Co.describe(k, u) end
    h = table.concat(parts, " y ")
  else
    h = c.hint
  end
  local parts = {}
  for _, u in ipairs(c.unlock) do
    local have, need = unlocks.progress(s, u)
    if have ~= nil and have < need then parts[#parts + 1] = string.format("%d/%d", have, need) end
  end
  if #parts > 0 then h = h .. " (" .. table.concat(parts, ", ") .. ")" end
  return h
end

return Co
