-- InaRogue › INAROGUE: Ascension levels and challenges of the v2 runs (docs/game/mods/inarogue-loop-v2.md §4.3, §4.4,
-- §6). Catalogues content/rogue/ascension.toml and content/rogue/challenges.toml; the run keeps its level and challenge
-- keys (rogue_run.json ascension / challenges). The summed modifiers feed lib/rogue/run_rules.lua. Also the start
-- options command (Ascension, challenges, the weekly run) the hub asks before a new run.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_INAROGUE_RL_RUN_OPTIONS | 0 | highest open level, levels declared, challenges declared, «add challenges?» text |
-- | | 1, level | ok, question text of that level ("¿Exigencia N? …") — and sets it for the next run |
-- | | 2, i (1-based) | ok, question text of challenge i |
-- | | 3, i | ok: challenge i on for the next run |
-- | | 4, week | ok, question text of the weekly run of `week` (false = none, or already won that week) |
-- | | 5, week | ok: that week's run for the next run (its seed, its challenges, Ascension 0) |
-- | | 6 | ok: the options cleared (a normal run) |
-- | | 7 | ok: the open levels 0..max set as the framework's pick cards (VRFW_PickCards.Show; pick n = level n - 1) |
-- `week` = the framework's ISO week id (VRFW_Daily.Period("week") in the menu, UTC, the same on every PC).

local U = require "lib/rogue/util"
local Rules = require "lib/rogue/run_rules"
local info, warn = U.logger("rogue ascension")

local A = {}

A.ASC_FILE, A.ASC_SCHEMA = "content/rogue/ascension.toml", "InaRogue.ascension/1"
A.CH_FILE, A.CH_SCHEMA = "content/rogue/challenges.toml", "InaRogue.challenges/1"

-- the modifier keys a level or a challenge may set (numbers add, booleans turn on, *_mult multiply)
local NUMBER_KEYS = { rival_levels = true, boss_levels = true, elite_weight = true, recruit_offers = true,
  start_coins = true }
local MULT_KEYS = { coins_mult = true, price_mult = true }
local FLAG_KEYS = { no_shop = true, no_recruit = true, no_items = true }

local function parse_mods(t, where)
  local o = {}
  if type(t) ~= "table" then return o end
  for k, v in pairs(t) do
    if NUMBER_KEYS[k] and type(v) == "number" then
      o[k] = v
    elseif MULT_KEYS[k] and type(v) == "number" and v >= 0 then
      o[k] = v
    elseif FLAG_KEYS[k] and type(v) == "boolean" then
      o[k] = v
    elseif k ~= "elites_needed" then
      warn(where .. ": unknown modifier `" .. tostring(k) .. "` (left out)")
    end
  end
  return o
end

local function load(file, schema)
  local ok, t = pcall(VRFW.files.toml, file)
  if not ok or type(t) ~= "table" then
    warn(file .. ": " .. tostring(t) .. "; none")
    return nil
  end
  if t.schema ~= schema then
    warn(file .. ": schema `" .. tostring(t.schema) .. "` (expected `" .. schema .. "`); none")
    return nil
  end
  return t
end

local levels, challenges = nil, nil

-- the Ascension levels in order: { { level, mods } }
local function the_levels()
  if levels then return levels end
  levels = {}
  local t = load(A.ASC_FILE, A.ASC_SCHEMA)
  for k, x in ipairs(t and type(t.level) == "table" and t.level or {}) do
    if type(x) == "table" and U.int(x.level, 0) == k then
      levels[#levels + 1] = { level = k, mods = parse_mods(x.modifiers, A.ASC_FILE .. " level " .. k) }
    else
      warn(A.ASC_FILE .. ": [[level]] #" .. k .. " needs level = " .. k .. "; the list stops there")
      break
    end
  end
  info(string.format("%d Ascension level(s)", #levels))
  return levels
end

-- the challenges: list + by key { key, points, mods, elites_needed }
local function the_challenges()
  if challenges then return challenges end
  challenges = { list = {}, by_key = {} }
  local t = load(A.CH_FILE, A.CH_SCHEMA)
  for k, x in ipairs(t and type(t.challenge) == "table" and t.challenge or {}) do
    local key = type(x) == "table" and x.key
    if type(key) ~= "string" or not key:match("^[a-z0-9_]+$") or challenges.by_key[key] then
      warn(A.CH_FILE .. ": [[challenge]] #" .. k .. " needs a new key of a-z 0-9 _ (left out)")
    else
      local rules = type(x.rules) == "table" and x.rules or {}
      local c = { key = key, points = math.max(U.int(x.points, 0), 0),
        mods = parse_mods(rules, A.CH_FILE .. " " .. key), elites_needed = math.max(U.int(rules.elites_needed, 0), 0),
        weekly = x.weekly ~= false }
      challenges.list[#challenges.list + 1] = c
      challenges.by_key[key] = c
    end
  end
  info(string.format("%d challenge(s)", #challenges.list))
  return challenges
end

function A.levels() return #the_levels() end

local function add_mods(m, mods)
  for k, v in pairs(mods) do
    if NUMBER_KEYS[k] then
      m[k] = (m[k] or 0) + v
    elseif MULT_KEYS[k] then
      m[k] = (m[k] or 1.0) * v
    elseif FLAG_KEYS[k] then
      m[k] = m[k] or v
    end
  end
end

-- the modifiers of run `r` (levels 1..r.ascension, then its challenges) summed into `m` (run_rules.modifiers)
function A.modifiers(r, m)
  local lv = the_levels()
  for i = 1, math.min(r.ascension or 0, #lv) do add_mods(m, lv[i].mods) end
  local ch = the_challenges()
  for _, k in ipairs(r.challenges or {}) do
    local c = ch.by_key[k]
    if c then add_mods(m, c.mods) end
  end
end
Rules.set_modifier_source(A.modifiers)

function A.challenge_name(key) return Rules.text("InaRogue.run_challenge_" .. key .. "_name") end

-- the challenges of run `r` that are completed (the run is won and its own goal, e.g. elites_needed, is met)
function A.completed_challenges(r)
  local o = {}
  local ch = the_challenges()
  for _, k in ipairs(r.challenges or {}) do
    local c = ch.by_key[k]
    if c and (r.stats and r.stats.elites or 0) >= c.elites_needed then o[#o + 1] = k end
  end
  return o
end

-- the bonus Rogue points of the completed challenges of won run `r`
function A.challenge_bonus(r)
  local n = 0
  local ch = the_challenges()
  for _, k in ipairs(A.completed_challenges(r)) do n = n + ch.by_key[k].points end
  return n
end

-- ---------------------------------------------------------------------------------------- the weekly run

-- the weekly run of ISO week `week` (the framework's daily service week id, given by the menu): seed and challenge
-- keys, nil for a bad week. The draw is the framework's daily generator for (key, week): VRFW.rng(key, { 2 = the week
-- kind, week id, version }), so the same week gives the same run on every PC.
A.WEEKLY_KEY, A.WEEKLY_VERSION, A.WEEK_KIND = "InaRogue.weekly", 1, 2

function A.weekly(week)
  week = U.int(week, 0)
  if week <= 0 then return nil end
  local ok, g = pcall(VRFW.rng, A.WEEKLY_KEY, { A.WEEK_KIND, week, A.WEEKLY_VERSION })
  if not ok or not g then
    warn("weekly run: no generator (" .. tostring(g) .. ")")
    return nil
  end
  local seed = math.max(g:u32(), 1)
  local pool = {}
  for _, c in ipairs(the_challenges().list) do
    if c.weekly then pool[#pool + 1] = c.key end
  end
  local picked = {}
  local want = math.min(Rules.get().weekly_challenges or 2, #pool)
  while #picked < want and #pool > 0 do
    picked[#picked + 1] = table.remove(pool, g:below(#pool) + 1)
  end
  return seed, picked
end

-- ---------------------------------------------------------------------------------------- the start options

local function run_svc() return require("lib/rogue/svc_run") end

local function ascension_text(lv)
  local parts = {}
  for i = 1, lv do parts[#parts + 1] = Rules.text("InaRogue.run_ascension_" .. i) end
  return Rules.text("InaRogue.run_ask_ascension", lv, table.concat(parts, "\n"))
end

function A.Options(op_arg, a_arg)
  local op = U.int(op_arg, 0)
  local svc = run_svc()
  local o = svc.start_options()
  if op == 0 then
    local open = require("lib/rogue/meta_store").ascension_open(A.levels())
    return open, A.levels(), #the_challenges().list, Rules.text("InaRogue.run_ask_challenges")
  elseif op == 1 then
    local lv = U.int(a_arg, 0)
    local open = require("lib/rogue/meta_store").ascension_open(A.levels())
    if lv < 0 or lv > open then return false, "" end
    o.ascension = lv
    svc.set_start_options(o)
    return true, lv > 0 and ascension_text(lv) or ""
  elseif op == 2 or op == 3 then
    local c = the_challenges().list[U.int(a_arg, 0)]
    if not c then return false, "" end
    if op == 3 then
      o.challenges = o.challenges or {}
      if not U.contains(o.challenges, c.key) then o.challenges[#o.challenges + 1] = c.key end
      svc.set_start_options(o)
      return true
    end
    return true, Rules.text("InaRogue.run_ask_challenge", A.challenge_name(c.key),
      Rules.text("InaRogue.run_challenge_" .. c.key .. "_desc"), c.points)
  elseif op == 4 or op == 5 then
    local week = U.int(a_arg, 0)
    local seed, picked = A.weekly(week)
    if not seed then return false, "" end
    local best = require("lib/rogue/meta_store").weekly(week)
    if op == 4 and best and best.won then return false, "" end
    if op == 5 then
      svc.set_start_options({ ascension = 0, challenges = picked, weekly = week, seed = seed })
      return true
    end
    local names = {}
    for _, k in ipairs(picked) do names[#names + 1] = A.challenge_name(k) end
    local record = best and Rules.text(best.won and "InaRogue.run_weekly_best_won" or "InaRogue.run_weekly_best",
      best.best_phase) or ""
    return true, Rules.text("InaRogue.run_ask_weekly", table.concat(names, ", "), record)
  elseif op == 6 then
    svc.set_start_options(nil)
    return true
  elseif op == 7 then
    local PC = rawget(_G, "PickCards")
    local open = require("lib/rogue/meta_store").ascension_open(A.levels())
    if not PC or not PC.Set or open <= 0 then return false end
    local cards = {}
    for lv = 0, open do
      local lines = {}
      for i = 1, lv do lines[#lines + 1] = Rules.text("InaRogue.run_ascension_" .. i) end
      cards[#cards + 1] = { kind = "text",
        title = lv == 0 and Rules.text("InaRogue.run_card_ascension_0") or Rules.text("InaRogue.run_card_ascension", lv),
        desc = lv == 0 and Rules.text("InaRogue.run_card_ascension_0_desc") or table.concat(lines, "\n"),
        badge = lv > 0 and Rules.text("InaRogue.run_card_ascension_points", Rules.get().rogue_points_per_ascension * lv) or "",
        rarity = math.min(math.floor(lv / 2) + (lv > 0 and 1 or 0), 5) }
    end
    return PC.Set({ title = Rules.text("InaRogue.run_pick_ascension_title"),
      subtitle = Rules.text("InaRogue.run_pick_ascension_sub", open), skip = false, focus = open + 1, cards = cards })
  end
  return false
end

return A
