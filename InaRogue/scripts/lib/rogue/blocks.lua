-- InaRogue › INAROGUE: the composable blocks of the item effects (docs/game/modes/inarogue-archetypes.md «Bloques»).
-- An item effect is one piece (lib/rogue/pieces.lua) or one grant, plus optional blocks in its table:
--   when = { <condition>, … }   conditions when_*: all must hold (the reached player, the run, the match)
--   count = <counter>           counters count_*: the stacks the value is multiplied by (per_stack) or a threshold
--   on = <trigger>              triggers on_*: when a grant fires (a grant needs one, directly or through count.on)
--   chance = <chance>           chance_one_in: the grant / counter step happens 1 time in n
--   per_stack = x               the value grows by x per stack (multipliers start at 1, flat values at 0)
-- A block is a table with `kind` (a trigger may also be written as its bare name). Each block declares its family,
-- its engine source and status (implemented, or pending with what it needs); its texts are the keys
-- InaRogue.rogue_block_<name>_label / _desc (text/rows/rogue_blocks.toml). The match run time is lib/rogue/svc_blocks.lua.

local U = require "lib/rogue/util"

local B = {}

B.ELEMENT = { viento = 1, wind = 1, bosque = 2, forest = 2, wood = 2, fuego = 3, fire = 3, ["montaña"] = 4,
  montana = 4, mountain = 4, earth = 4 }
B.POSITION = { gk = 1, por = 1, portero = 1, fw = 2, del = 2, delantero = 2, mf = 3, cen = 3, centrocampista = 3,
  df = 4, def = 4, defensa = 4 }
-- the route map's node kinds (lib/rogue/map.lua KIND)
B.NODE_KIND = { start = 0, small = 1, full = 2, boss = 3, chest = 4, event = 5, recruit = 6, elite = 7, epic = 8,
  gate = 9 }
-- the move key prefixes of the game (whs shoot, who dribble, whd block, whk catch)
B.MOVE_CATEGORY = { shoot = "whs", dribble = "who", block = "whd", catch = "whk" }
-- skill_effect_bit_flag bits per category (docs/framework/technique.md «badges»), plus `foul` (foul_rate > 0)
B.MOVE_TAGS = {
  long_shot = { category = "shoot", bit = 4 }, chain = { category = "shoot", bit = 8 },
  counter = { category = "shoot", bit = 16 }, shot_block = { category = "block", bit = 16 },
  punch = { category = "catch", bit = 2 }, foul = { foul = true },
  ground = { pending = "no game column marks ground moves" },
}
B.SCOPES = { match = true, phase = true, run = true }
B.STATS = { "kick", "control", "technique", "pressure", "physical", "intelligence", "agility" }

local MODIFIER_KEYS = { when = true, count = true, on = true, chance = true, per_stack = true }
B.MODIFIER_KEYS = MODIFIER_KEYS

function B.text_keys(name)
  return "InaRogue.rogue_block_" .. name .. "_label", "InaRogue.rogue_block_" .. name .. "_desc"
end

-- ---------------------------------------------------------------------------------------- shared parsers

local function list_of(v)
  if v == nil then return {} end
  if type(v) == "table" then return v end
  return { v }
end

local function whole(v, lo)
  return type(v) == "number" and v == math.floor(v) and v >= (lo or 0)
end

-- a belong team id: a number or "0x…" text
local function team_id(v)
  if type(v) == "number" then return v % U.TWO32 end
  if type(v) == "string" then
    local n = tonumber(v) or tonumber(v:match("^0[xX](%x+)$") or "", 16)
    if n then return n % U.TWO32 end
  end
  return nil
end

local function word_set(v, map, what)
  local out = {}
  for _, w in ipairs(list_of(v)) do
    local n = map[U.lower(tostring(w))]
    if not n then
      local names = {}
      for k in pairs(map) do names[#names + 1] = k end
      table.sort(names)
      return nil, what .. " `" .. tostring(w) .. "` (" .. table.concat(names, " / ") .. ")"
    end
    out[n] = true
  end
  return out
end

-- a player filter: team (belong team ids, chara_base team_1..3), set (a VRFW card set «<mod>.<name>»), element,
-- position, rarity_min / rarity_max (INAROGUE stars 1-5). Every key given must hold.
local FILTER_KEYS = { team = true, set = true, element = true, position = true, rarity_min = true, rarity_max = true }

function B.parse_players(t, where)
  if type(t) ~= "table" then return nil, where .. ": a player filter table" end
  local f = {}
  for k, v in pairs(t) do
    if k ~= "kind" and not FILTER_KEYS[k] then
      return nil, where .. ": unknown key `" .. tostring(k) .. "`"
    end
    if k == "team" then
      f.team = {}
      for _, x in ipairs(list_of(v)) do
        local id = team_id(x)
        if not id then return nil, where .. ": team `" .. tostring(x) .. "` (a belong team id, number or \"0x…\")" end
        f.team[#f.team + 1] = id
      end
    elseif k == "set" then
      f.set = {}
      for _, x in ipairs(list_of(v)) do
        if type(x) ~= "string" or not x:find("%.") then return nil, where .. ": set `" .. tostring(x) .. "` («<mod>.<name>»)" end
        f.set[#f.set + 1] = x
      end
    elseif k == "element" then
      local s, why = word_set(v, B.ELEMENT, where .. ": element")
      if not s then return nil, why end
      f.element = s
    elseif k == "position" then
      local s, why = word_set(v, B.POSITION, where .. ": position")
      if not s then return nil, why end
      f.position = s
    elseif k == "rarity_min" or k == "rarity_max" then
      if not whole(v, 1) then return nil, where .. ": " .. k .. " = 1-5" end
      f[k] = v
    end
  end
  return f
end

-- the belong teams of a card's character (cached): set of team ids
local teams_cache = {}
function B.teams_of(card)
  if not card or card == 0 then return {} end
  local c = teams_cache[card]
  if c then return c end
  c = {}
  local ok, base = pcall(VRFW.chara.base_of, card)
  if ok and base then
    local ok2, ch = pcall(VRFW.chara.character, base)
    if ok2 and type(ch) == "table" and type(ch.teams) == "table" then
      for _, t in pairs(ch.teams) do
        if type(t) == "number" and t ~= 0 then c[t % U.TWO32] = true end
      end
    end
  end
  teams_cache[card] = c
  return c
end

-- the cards of a declared card set (cached): set of card ids
local set_cache = {}
function B.set_cards(name)
  local c = set_cache[name]
  if c then return c end
  c = {}
  local ok, cards = pcall(VRFW.chara.set, name)
  if ok and type(cards) == "table" then
    for _, id in ipairs(cards) do c[id % U.TWO32] = true end
  else
    VRFW.warn("rogue blocks: card set " .. name .. ": " .. tostring(cards))
  end
  set_cache[name] = c
  return c
end

-- does player `p` ({ card, element, position, tier }) pass filter `f`?
function B.player_matches(f, p)
  if not p then return false end
  if f.element and not f.element[p.element or 0] then return false end
  if f.position and not f.position[p.position or 0] then return false end
  if f.rarity_min and (p.tier or 0) < f.rarity_min then return false end
  if f.rarity_max and (p.tier or 0) > f.rarity_max then return false end
  if f.team then
    local teams, hit = B.teams_of(p.card), false
    for _, id in ipairs(f.team) do
      if teams[id] then hit = true break end
    end
    if not hit then return false end
  end
  if f.set then
    local hit = false
    for _, name in ipairs(f.set) do
      if B.set_cards(name)[(p.card or 0) % U.TWO32] then hit = true break end
    end
    if not hit then return false end
  end
  return true
end

-- a move filter: category (shoot / dribble / block / catch), element, moves (internal keys, «<mod>.<name>» or ids),
-- tags (long_shot, chain, counter, shot_block, punch, foul; ground = pending), performers (players who perform it:
-- 1-4, or { min, max })
local MOVE_KEYS = { category = true, element = true, moves = true, tags = true, performers = true }

function B.parse_moves(t, where)
  local f = {}
  for k, v in pairs(t) do
    if MOVE_KEYS[k] then
      if k == "category" then
        f.category = {}
        for _, w in ipairs(list_of(v)) do
          local p = B.MOVE_CATEGORY[w]
          if not p then return nil, where .. ": category `" .. tostring(w) .. "` (shoot / dribble / block / catch)" end
          f.category[p] = true
        end
      elseif k == "element" then
        local s, why = word_set(v, B.ELEMENT, where .. ": element")
        if not s then return nil, why end
        f.element = s
      elseif k == "moves" then
        f.moves = {}
        for _, m in ipairs(list_of(v)) do
          if type(m) ~= "string" and type(m) ~= "number" then return nil, where .. ": moves = keys or ids" end
          f.moves[#f.moves + 1] = m
        end
      elseif k == "tags" then
        f.tags = {}
        for _, w in ipairs(list_of(v)) do
          local d = B.MOVE_TAGS[w]
          if not d then return nil, where .. ": tag `" .. tostring(w) .. "` (long_shot / chain / counter / shot_block / punch / foul / ground)" end
          if d.pending then f.pending = "tag " .. w .. ": " .. d.pending end
          f.tags[#f.tags + 1] = d
        end
      elseif k == "performers" then
        if whole(v, 1) then
          f.players_min, f.players_max = v, v
        elseif type(v) == "table" and whole(v.min or 1, 1) and whole(v.max or 4, 1) then
          f.players_min, f.players_max = v.min or 1, v.max or 4
        else
          return nil, where .. ": performers = 1-4 or { min, max }"
        end
      end
    end
  end
  return f
end

-- the skill table rows the move filters read (cached): id -> { key, element, flags, foul, players }
local skills = nil
function B.move_info(id)
  if not id then return nil end
  if not skills then
    skills = {}
    local ok, rows = pcall(VRFW.table.rows, "skill/skill")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local sid = tonumber(r.skill_id or r[1])
        if sid then
          local partners = tonumber(r.partner_type or r[20]) or 0
          skills[bit32.band(sid, 0xFFFFFFFF)] = {
            key = tostring(r.skill_id_str or r[2] or ""),
            element = tonumber(r.element or r[13]) or 0,
            flags = tonumber(r.skill_effect_bit_flag or r[10]) or 0,
            foul = tonumber(r.foul_rate or r[17]) or 0,
            players = partners >= 2 and partners or 1,
          }
        end
      end
    else
      VRFW.warn("rogue blocks: no skill table: move filters reach no move")
    end
  end
  return skills[bit32.band(id, 0xFFFFFFFF)]
end

-- the move ids a filter's `moves` names (resolved once)
local function resolved_moves(f)
  if f.move_ids then return f.move_ids end
  f.move_ids = {}
  for _, m in ipairs(f.moves or {}) do
    local id = type(m) == "number" and m or nil
    if not id then
      local ok, v = pcall(VRFW.technique, m)
      if ok and type(v) == "number" then id = v end
    end
    if id then f.move_ids[bit32.band(id, 0xFFFFFFFF)] = true end
  end
  return f.move_ids
end

function B.move_matches(f, id)
  if f.pending then return false end
  local m = B.move_info(id)
  if not m then return false end
  if f.moves and not resolved_moves(f)[bit32.band(id, 0xFFFFFFFF)] then return false end
  if f.category and not f.category[m.key:sub(1, 3)] then return false end
  if f.element and not f.element[m.element] then return false end
  if f.players_min and (m.players < f.players_min or m.players > f.players_max) then return false end
  for _, tag in ipairs(f.tags or {}) do
    if tag.foul then
      if m.foul <= 0 then return false end
    elseif m.key:sub(1, 3) ~= B.MOVE_CATEGORY[tag.category] or bit32.band(m.flags, tag.bit) == 0 then
      return false
    end
  end
  return true
end

-- ---------------------------------------------------------------------------------------- conditions (when_*)
-- check(spec, ctx): ctx.player = { card, element, position, tier, slot, captain }, ctx.run = { phase, node_kind,
-- items, archetype_counts, roster = { player, … } }, ctx.match = { half, minute, score_for, score_against } (nil
-- outside a match). needs: what a condition reads (`player`, `run`, `match`).

B.CONDITIONS = {}
local C = B.CONDITIONS

local function filter_condition(key)
  return function(t, where)
    if t[key] == nil then return nil, where .. ": `" .. key .. "`" end
    return B.parse_players({ [key] = t[key] }, where)
  end
end

C.when_in_team = { needs = "player", source = "VRFW.chara (belong teams) / VRFW.chara.set (card sets)",
  parse = function(t, where)
    if t.team == nil and t.set == nil then return nil, where .. ": `team` (belong team ids) or `set` (a card set)" end
    return B.parse_players({ team = t.team, set = t.set }, where)
  end,
  check = function(s, ctx) return B.player_matches(s, ctx.player) end }
C.when_element = { needs = "player", source = "chara_param element", parse = filter_condition("element"),
  check = function(s, ctx) return B.player_matches(s, ctx.player) end }
C.when_position = { needs = "player", source = "chara_param main position", parse = filter_condition("position"),
  check = function(s, ctx) return B.player_matches(s, ctx.player) end }
C.when_rarity = { needs = "player", source = "chara_param col 57 (INAROGUE stars)",
  parse = function(t, where)
    if t.min == nil and t.max == nil then return nil, where .. ": `min` and / or `max` (stars 1-5)" end
    return B.parse_players({ rarity_min = t.min, rarity_max = t.max }, where)
  end,
  check = function(s, ctx) return B.player_matches(s, ctx.player) end }
C.when_on_field = { needs = "player", source = "the run's team slots 0-10",
  parse = function() return {} end,
  check = function(_, ctx) return ctx.player ~= nil and (ctx.player.slot or 99) < 11 end }
C.when_on_bench = { needs = "player", source = "the run's team slots 11-15",
  parse = function() return {} end,
  check = function(_, ctx) local s = ctx.player and ctx.player.slot or 99 return s >= 11 and s < 16 end }
C.when_captain = { needs = "player", status = "pending",
  pending_for = "the captain of the run's team: the run keeps no captain slot and no captain read exists yet",
  parse = function() return {} end,
  check = function(_, ctx) return ctx.player ~= nil and ctx.player.captain == true end }
C.when_facing_boss = { needs = "run", source = "the route map node of the match (boss / gate)",
  parse = function() return {} end,
  check = function(_, ctx)
    local k = ctx.run and ctx.run.node_kind
    return k == B.NODE_KIND.boss or k == B.NODE_KIND.gate
  end }
C.when_node_kind = { needs = "run", source = "the route map node in progress",
  parse = function(t, where)
    local s, why = word_set(t.node, B.NODE_KIND, where .. ": node")
    if not s then return nil, why end
    return { kinds = s }
  end,
  check = function(s, ctx) return ctx.run ~= nil and s.kinds[ctx.run.node_kind or -1] == true end }
C.when_score = { needs = "match", source = "VRFW match score (ev.match.score)",
  parse = function(t, where)
    local ok = { winning = true, losing = true, draw = true }
    if not ok[t.state] then return nil, where .. ": state = winning / losing / draw" end
    return { state = t.state }
  end,
  check = function(s, ctx)
    local m = ctx.match
    if not m or not m.score_for then return false end
    local d = m.score_for - m.score_against
    return (s.state == "winning" and d > 0) or (s.state == "losing" and d < 0) or (s.state == "draw" and d == 0)
  end }
C.when_half = { needs = "match", source = "VRFW match half (1-2, 3-4 extra time)",
  parse = function(t, where)
    if not whole(t.half, 1) then return nil, where .. ": half = 1-4" end
    return { half = t.half }
  end,
  check = function(s, ctx) return ctx.match ~= nil and ctx.match.half == s.half end }
C.when_minute = { needs = "match", source = "VRFW match clock (minutes of the half)",
  parse = function(t, where)
    local from, to = t.from or 0, t.to or 9999
    if type(from) ~= "number" or type(to) ~= "number" or from > to then return nil, where .. ": from <= to (minutes of the half)" end
    return { from = from, to = to }
  end,
  check = function(s, ctx)
    local m = ctx.match and ctx.match.minute
    return m ~= nil and m >= s.from and m < s.to
  end }
C.when_phase = { needs = "run", source = "the run's phase",
  parse = function(t, where)
    if t.min == nil and t.max == nil then return nil, where .. ": `min` and / or `max` (phase numbers)" end
    return { min = t.min or 1, max = t.max or 9999 }
  end,
  check = function(s, ctx) local p = ctx.run and ctx.run.phase or 0 return p >= s.min and p <= s.max end }
C.when_has_item = { needs = "run", source = "the run's inventory",
  parse = function(t, where)
    if type(t.item) ~= "string" or t.item == "" then return nil, where .. ": item = an item key" end
    return { item = t.item }
  end,
  check = function(s, ctx)
    for _, o in ipairs(ctx.run and ctx.run.items or {}) do
      if o.key == s.item then return true end
    end
    return false
  end }
C.when_archetype_rank = { needs = "run", source = "the run's inventory (items per archetype)",
  parse = function(t, where)
    if type(t.archetype) ~= "string" or not whole(t.min, 1) then return nil, where .. ": archetype = key, min = 1-5" end
    return { archetype = t.archetype, min = t.min }
  end,
  check = function(s, ctx)
    local counts = ctx.run and ctx.run.archetype_counts or {}
    return (counts[s.archetype] or 0) >= s.min
  end }
C.when_roster_count = { needs = "run", source = "the run's team (slots 0-15)",
  parse = function(t, where)
    if not whole(t.min, 1) then return nil, where .. ": min = a whole number >= 1" end
    local f, why = B.parse_players(type(t.players) == "table" and t.players or {}, where .. " players")
    if not f then return nil, why end
    return { players = f, min = t.min, where = t.where or "all" }
  end,
  check = function(s, ctx) return B.roster_count(ctx.run, s.players, s.where) >= s.min end }

-- players of the run's team passing `f` (where: all = slots 0-15, field = 0-10, bench = 11-15)
function B.roster_count(run, f, where)
  local n = 0
  for _, p in ipairs(run and run.roster or {}) do
    local s = p.slot or 0
    local in_place
    if where == "field" then in_place = s < 11
    elseif where == "bench" then in_place = s >= 11 and s < 16
    else in_place = s < 16 end
    if in_place and B.player_matches(f, p) then n = n + 1 end
  end
  return n
end

-- ---------------------------------------------------------------------------------------- triggers (on_*)
-- match(spec, ev): ev = { name, actor = player (user side) or nil, move = id, item = key, rank_up = bool }.
-- where: match (a match event) / run (the route map). source: the engine event the run time listens to.

B.TRIGGERS = {}
local T = B.TRIGGERS

local function no_params() return {} end
local function always() return true end
local function actor_filter(t, where)
  if type(t.players) ~= "table" then return {} end
  local f, why = B.parse_players(t.players, where .. " players")
  if not f then return nil, why end
  return { players = f }
end
local function actor_ok(s, ev) return not s.players or B.player_matches(s.players, ev.actor) end

T.on_goal_scored = { where = "match", source = "goal:user (score poll, both builds)", parse = actor_filter, match = actor_ok }
T.on_goal_conceded = { where = "match", source = "goal:rival (score poll, both builds)", parse = no_params, match = always }
T.on_technique_used = { where = "match", source = "match:skill_used:post (Technique.SkillUsed)",
  parse = function(t, where)
    local f, why = B.parse_moves(t, where)
    if not f then return nil, why end
    local a, why2 = actor_filter(t, where)
    if not a then return nil, why2 end
    f.players_filter = a.players
    return f
  end,
  match = function(s, ev)
    if s.players_filter and not B.player_matches(s.players_filter, ev.actor) then return false end
    return B.move_matches(s, ev.move)
  end }
T.on_block_won = { where = "match", source = "block_won (Duel.ExecResult, both builds)", parse = actor_filter, match = actor_ok }
T.on_duel_won = { where = "match", source = "duel_won (Duel.ExecResult, both builds)", parse = actor_filter, match = actor_ok }
T.on_dribble_won = { where = "match", source = "duel_won by the ball holder (possession + Duel.ExecResult)",
  parse = actor_filter, match = actor_ok }
T.on_pass_completed = { where = "match", source = "possession:keep, the user side (ball owner poll)",
  parse = actor_filter, match = actor_ok }
T.on_substitution = { where = "match", source = "match:substitution (Match.SubstitutionEvent, both builds)",
  parse = function(t, where)
    local a, why = actor_filter(t, where)
    if not a then return nil, why end
    if t.higher_rank then
      a.higher_rank = true
      a.pending = "higher_rank: the substitution event names only the incoming player, not the one who leaves"
    end
    return a
  end,
  match = function(s, ev)
    if s.pending then return false end
    return actor_ok(s, ev)
  end }
T.on_match_won = { where = "run", source = "CMND_INAROGUE_RL_RUN_RESULT (won)", parse = no_params, match = always }
T.on_match_lost = { where = "run", source = "CMND_INAROGUE_RL_RUN_RESULT (lost; a lost match ends the run)",
  parse = no_params, match = always }
-- a «ronda» is one match: on_match_end fires after every match whose result the run keeps
T.on_match_end = { where = "run", source = "CMND_INAROGUE_RL_RUN_RESULT (any result kept in the run)",
  parse = no_params, match = always }
T.on_phase_end = { where = "run", source = "CMND_INAROGUE_RL_RUN_NEXT_PHASE", parse = no_params, match = always }
T.on_boss_defeated = { where = "run", source = "CMND_INAROGUE_RL_RUN_RESULT (won on a boss / gate node)",
  parse = no_params, match = always }
T.on_shop_visit = { where = "run", source = "CMND_INAROGUE_RL_RUN_MOVE along a Tienda line",
  parse = no_params, match = always }
T.on_effect_activated = { where = "any", source = "this run time: another item's grant fired or its counter stepped",
  parse = function(t, where)
    if type(t.item) ~= "string" or t.item == "" then return nil, where .. ": item = the partner item's key" end
    return { item = t.item }
  end,
  match = function(s, ev) return ev.item == s.item end }

-- a trigger written as a name or a table -> { name, spec } | nil, why
-- the earlier trigger names -> their current names
B.TRIGGER_ALIASES = { on_round_end = "on_match_end", on_match_played = "on_match_end" }

function B.parse_trigger(v, where)
  local t = type(v) == "string" and { kind = v } or v
  if type(t) ~= "table" or type(t.kind) ~= "string" then return nil, where .. ": a trigger (on_*)" end
  if B.TRIGGER_ALIASES[t.kind] then
    local c = {}
    for k, x in pairs(t) do c[k] = x end
    c.kind = B.TRIGGER_ALIASES[t.kind]
    t = c
  end
  local d = T[t.kind]
  if not d then return nil, where .. ": unknown trigger `" .. tostring(t.kind) .. "`" end
  local s, why = d.parse(t, where .. " " .. t.kind)
  if not s then return nil, why end
  return { name = t.kind, spec = s, where = d.where, pending = s.pending }
end

function B.trigger_matches(tr, name, ev)
  if tr.name ~= name then return false end
  return T[name].match(tr.spec, ev) == true
end

-- ---------------------------------------------------------------------------------------- counters (count_*)
-- count_trigger: +1 each time `on` fires; count_timer: +1 every `seconds` of live match time; count_roster: the
-- run's players passing a filter. stacks = floor(count / every), at most `cap`; mode = "charge": each `every`
-- steps store one charge the effect spends once. reset_on: triggers that put the count back to 0. scope: match
-- (memory), phase (reset at the phase end) or run (rogue_run.json, the item's `counters`).

B.COUNTERS = {}

local function counter_common(t, where, c)
  c.every = t.every or 1
  if not whole(c.every, 1) then return nil, where .. ": every = a whole number >= 1" end
  if t.cap ~= nil and not whole(t.cap, 1) then return nil, where .. ": cap = a whole number >= 1" end
  c.cap = t.cap
  c.mode = t.mode or "stack"
  if c.mode ~= "stack" and c.mode ~= "charge" then return nil, where .. ": mode = stack / charge" end
  if c.mode == "charge" and c.scope ~= "match" then return nil, where .. ": charges count within one match (scope = match)" end
  c.reset_on = {}
  for _, r in ipairs(list_of(t.reset_on)) do
    local tr, why = B.parse_trigger(r, where .. " reset_on")
    if not tr then return nil, why end
    c.reset_on[#c.reset_on + 1] = tr
  end
  return c
end

B.COUNTERS.count_trigger = { source = "the trigger's own source",
  parse = function(t, where)
    if t.on == nil then return nil, where .. ": `on` (the trigger counted)" end
    local tr, why = B.parse_trigger(t.on, where .. " on")
    if not tr then return nil, why end
    local scope = t.scope or "match"
    if not B.SCOPES[scope] then return nil, where .. ": scope = match / phase / run" end
    if tr.where == "run" and scope == "match" then return nil, where .. ": a run trigger needs scope phase / run" end
    return counter_common(t, where, { kind = "count_trigger", on = tr, scope = scope, pending = tr.pending })
  end }
B.COUNTERS.count_timer = { source = "tick (live match time: InPlay, focus, scramble, zone)",
  parse = function(t, where)
    if type(t.seconds) ~= "number" or t.seconds <= 0 then return nil, where .. ": seconds > 0 (game seconds)" end
    if (t.scope or "match") ~= "match" then return nil, where .. ": a timer counts within one match (scope = match)" end
    return counter_common(t, where, { kind = "count_timer", seconds = t.seconds, scope = "match" })
  end }
B.COUNTERS.count_roster = { source = "the run's team (slots 0-15)",
  parse = function(t, where)
    local f, why = B.parse_players(type(t.players) == "table" and t.players or {}, where .. " players")
    if not f then return nil, why end
    return counter_common(t, where, { kind = "count_roster", players = f, where_in = t.where or "all", scope = "run" })
  end }

function B.parse_counter(t, where)
  if type(t) ~= "table" or type(t.kind) ~= "string" then return nil, where .. ": a counter table (count_*)" end
  local d = B.COUNTERS[t.kind]
  if not d then return nil, where .. ": unknown counter `" .. t.kind .. "`" end
  return d.parse(t, where .. " " .. t.kind)
end

-- the stacks of counter `c` with raw count `n` (count_roster: n = the matching players)
function B.stacks(c, n)
  local s = math.floor((n or 0) / c.every)
  if c.cap then s = math.min(s, c.cap) end
  return math.max(s, 0)
end

-- ---------------------------------------------------------------------------------------- chance (chance_*)

B.CHANCES = { chance_one_in = { source = "VRFW.rng (seeded by the run)" } }

function B.parse_chance(v, where)
  local t = type(v) == "number" and { kind = "chance_one_in", n = v } or v
  if type(t) ~= "table" or t.kind ~= "chance_one_in" then return nil, where .. ": chance = n or { kind = \"chance_one_in\", n }" end
  if not whole(t.n, 1) then return nil, where .. ": chance n = a whole number >= 1" end
  return { n = t.n }
end

-- ---------------------------------------------------------------------------------------- grants (grant_*)
-- A grant fires on its trigger (`on`, or its counter's `on` / timer at every `every`), after its chance.

B.GRANTS = {}
local G = B.GRANTS

G.grant_points = { where = "any", source = "the Rogue points (svc_meta earn_bonus)",
  parse = function(t, where)
    if not whole(t.amount, 1) then return nil, where .. ": amount = Rogue points >= 1" end
    return { amount = t.amount }
  end }
G.grant_xp_multiplier = { where = "run", status = "pending",
  pending_for = "a per-mode answer of the match EXP service (MatchExp.Result) that INAROGUE can set for N matches",
  parse = function(t, where)
    if type(t.mult) ~= "number" or t.mult <= 0 or not whole(t.matches or 1, 1) then return nil, where .. ": mult > 0, matches >= 1" end
    return { mult = t.mult, matches = t.matches or 1 }
  end }
G.grant_resource = { where = "match", source = "VRFW.add_tension (tension) / VRFW.resource.add (a match resource)",
  parse = function(t, where)
    local res = t.resource or "tension"
    if type(res) ~= "string" then return nil, where .. ": resource = tension or a match resource key («<mod>.<name>»)" end
    if t.amount == nil and t.percent == nil then return nil, where .. ": amount or percent (of the player's full bar)" end
    if res == "tension" and type(t.amount) ~= "number" then return nil, where .. ": tension takes `amount` (tension units)" end
    local who = t.who or "actor"
    if who ~= "actor" and who ~= "team" then return nil, where .. ": who = actor / team" end
    return { resource = res, amount = t.amount, percent = t.percent, who = who }
  end }
G.grant_item = { where = "run", source = "the run's inventory (svc_items Add)",
  parse = function(t, where)
    if (type(t.item) ~= "string" or t.item == "") and t.rarity_max == nil then
      return nil, where .. ": item = a key, or rarity_max (a random item of the catalogue up to that rarity)"
    end
    return { give = t.item, rarity_max = t.rarity_max }
  end }
G.grant_player = { where = "run", source = "the player bank (svc_bank bank_add_param) from the draw pool",
  parse = function(t, where)
    local f, why = B.parse_players(type(t.players) == "table" and t.players or {}, where .. " players")
    if not f then return nil, why end
    if t.rarity_max ~= nil then f.rarity_max = t.rarity_max end
    return { players = f }
  end }
G.grant_clone = { where = "run", status = "pending",
  pending_for = "duplicate players in one team: the team slots hold one bank uid each and the match build has no " ..
    "copy of a player (roster rule «clones on the field»)",
  parse = function(t, where)
    if not whole(t.matches or 1, 1) then return nil, where .. ": matches >= 1" end
    return { who = t.who or "first_bench", matches = t.matches or 1 }
  end }
G.grant_stat_buff = { where = "run", source = "InaRogue.CoachMult at the next kick-offs (the item's counters)",
  parse = function(t, where)
    local stat = t.stat or "all"
    if stat ~= "all" and not U.index_of(B.STATS, stat) then return nil, where .. ": stat = all / " .. table.concat(B.STATS, " / ") end
    if type(t.value) ~= "number" or t.value <= 0 then return nil, where .. ": value = a multiplier > 0" end
    if not whole(t.matches, 1) then return nil, where .. ": matches = a whole number >= 1" end
    local f, why = B.parse_players(type(t.players) == "table" and t.players or {}, where .. " players")
    if not f then return nil, why end
    return { stat = stat, value = t.value, matches = t.matches, players = f }
  end }

function B.parse_grant(t)
  local d = G[t.kind]
  local where = t.kind
  local s, why = d.parse(t, where)
  if not s then return nil, why end
  s.kind = t.kind
  s.grant = true
  if d.status == "pending" then s.pending = true end
  return s
end

-- ---------------------------------------------------------------------------------------- modifiers of an effect

-- the blocks of effect table `t` attached to its parsed effect `e`: e.when, e.count, e.on, e.chance, e.per_stack,
-- e.live (it changes during a match: a match-state condition, a match-scope counter or a timer); true or nil, why
function B.attach(e, t, where)
  where = where or e.kind
  if t.when ~= nil then
    e.when = {}
    local list = t.when
    if type(list) == "table" and list.kind then list = { list } end
    for k, c in ipairs(type(list) == "table" and list or {}) do
      local ct = type(c) == "string" and { kind = c } or c
      local d = type(ct) == "table" and C[ct.kind]
      if not d then return nil, where .. ": when #" .. k .. ": unknown condition `" .. tostring(type(ct) == "table" and ct.kind or ct) .. "`" end
      local s, why = d.parse(ct, where .. " " .. ct.kind)
      if not s then return nil, why end
      e.when[#e.when + 1] = { name = ct.kind, spec = s, needs = d.needs }
      if d.status == "pending" then e.pending_condition = ct.kind end
      if d.needs == "match" then e.live = true end
    end
  end
  if t.count ~= nil then
    local c, why = B.parse_counter(t.count, where .. " count")
    if not c then return nil, why end
    e.count = c
    if c.scope == "match" then e.live = true end
  end
  if t.on ~= nil then
    local tr, why = B.parse_trigger(t.on, where .. " on")
    if not tr then return nil, why end
    e.on = tr
  end
  if t.chance ~= nil then
    local ch, why = B.parse_chance(t.chance, where)
    if not ch then return nil, why end
    e.chance = ch
  end
  if t.per_stack ~= nil then
    if type(t.per_stack) ~= "number" then return nil, where .. ": per_stack = a number" end
    if not e.count then return nil, where .. ": per_stack needs a `count`" end
    e.per_stack = t.per_stack
  end
  if e.grant and not e.on and not (e.count and (e.count.on or e.count.kind == "count_timer")) then
    return nil, where .. ": a grant needs `on` (a trigger) or a counter with `on` / a timer"
  end
  return true
end

-- every condition of `e` holds in `ctx` (a pending condition never holds)
function B.conditions_hold(e, ctx)
  if e.pending_condition then return false end
  for _, c in ipairs(e.when or {}) do
    if c.needs == "player" and not ctx.player then return false end
    if c.needs == "match" and not ctx.match then return false end
    if not C[c.name].check(c.spec, ctx) then return false end
  end
  return true
end

-- the value of a multiplier / flat effect with `stacks`: per_stack grows from `base`; without per_stack a counter is
-- a threshold (the value from 1 stack on, else `neutral`)
function B.stacked_value(e, base, stacks, neutral)
  if not e.count then return base end
  if e.per_stack then return base + e.per_stack * stacks end
  if stacks >= 1 then return base end
  return neutral
end

-- the status of a block by name (implemented / pending) and why
function B.status(name)
  local d = C[name] or T[name] or B.COUNTERS[name] or G[name] or B.CHANCES[name]
  if not d then return nil end
  return d.status or "implemented", d.pending_for
end

-- every block name per family (docs and the text check)
function B.names()
  local out = { condition = {}, trigger = {}, counter = {}, chance = {}, grant = {} }
  for k in pairs(C) do out.condition[#out.condition + 1] = k end
  for k in pairs(T) do out.trigger[#out.trigger + 1] = k end
  for k in pairs(B.COUNTERS) do out.counter[#out.counter + 1] = k end
  for k in pairs(B.CHANCES) do out.chance[#out.chance + 1] = k end
  for k in pairs(G) do out.grant[#out.grant + 1] = k end
  for _, l in pairs(out) do table.sort(l) end
  return out
end

return B
