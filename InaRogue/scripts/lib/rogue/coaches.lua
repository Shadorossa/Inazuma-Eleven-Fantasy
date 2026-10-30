-- InaRogue › INAROGUE coaches (docs/game/modes/inarogue.md «Entrenadores»). Was coaches.rs / coaches_rt.rs of
-- the DLL's module rogue. The coach picked at the start of a NEW run is the run's «class»: typed effects declared in
-- content\rogue\coaches.toml ([rogue.coaches] file); unlock rules are counters of the global unlock store (unlocks.lua).
--
-- Effects: stat_mult (the match copy of the run's players: applied by the plugin's stats hook, which reads the
-- multipliers this script publishes, see publish_stats), node_weight (map content weights), reward_mult (fragments /
-- Rogue points), start_points, start_item; technique_cost and match_rule are declared kinds without an engine hook yet.

local U = require "lib/rogue/util"
local unlocks = require "lib/rogue/unlocks"
local E = require "lib/rogue/effects"
local info, warn = U.logger("rogue coaches")

local Co = {}

Co.SCHEMA = "inazuma_fantasy.rogue_coaches/1"
Co.STATS = E.STATS

-- one effect table -> its effect, or nil + why (the shared parser, lib/rogue/effects.lua)
function Co.parse_effect(t) return E.parse_effect(t) end

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

-- the coach's effects through the shared aggregators (lib/rogue/effects.lua)
function Co.stat_mults(c, position, element) return E.stat_mults(c.effects, position, element) end
function Co.has_stat_mults(c) return E.has_stat_mults(c.effects) end
function Co.content_mults(c) return E.content_mults(c.effects) end
function Co.reward_mult(c, r) return E.reward_mult(c.effects, r) end
function Co.start_points(c) return E.start_points(c.effects) end

function Co.start_items(c) return E.start_items(c.effects) end

-- n x mult, rounded (1.0 = unchanged exactly)
function Co.scaled(n, mult) return E.scaled(n, mult) end

-- a rule in the game's language with the coaches' names
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
    h = unlocks.join(parts)
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
