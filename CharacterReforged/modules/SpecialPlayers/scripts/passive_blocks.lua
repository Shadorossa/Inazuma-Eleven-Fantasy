-- Special Players › the passives at run time: one generic interpreter of the blocks (scripts\lib\special_passives.lua
-- reads them; the block types are content\types\passive_block.toml). Every player on the pitch carries the passives of
-- his character / card ([[SpecialPlayers.Character]]) and of the game passives he carries (carried_by).
--   * The events the passives name (behaviour-rule triggers, docs/framework/rules.md §3): a passive whose Trigger
--     matches (`by` = whose event, seen from the carrier) and whose conditions hold gains a stack (at most its Stack
--     block's max, 1 without one) and applies its at-once effects (Tension, Refuse); a Reset puts its stacks to 0.
--   * Its lasting effects work while it has stacks (a passive without a trigger: always), × its stacks: technique
--     power on move_power, tension cost on tension_pay, move speed on move_speed, recast on recast (the
--     triggers its effect types name: `hooks`), stat parameters through the framework's set_stat (every 0.5 s on
--     `tick`, summed per player and stat over every passive).
-- One function per condition type and per kind of effect; nothing here names a character, a passive or a value.
-- Nothing calls the game at load: the subscriptions come from the files.

local L = require "lib/special_passives"

local function info(...) VRFW.log("passive_blocks:", ...) end
local function warn(...) VRFW.warn("passive_blocks:", ...) end

local u32 = L.u32
local N_SLOTS = 5
local ACTOR_STRIDE, ACTOR_MAX, ACTOR_HANDLE, UNIT_CHARA = 0x570, 0x3A, 0x94, 0x370
-- how long the on-pitch player list and a player's carried passives are kept (ms)
local PLAYERS_TTL_MS, CARRIED_TTL_MS, STAT_EVERY_MS = 1000, 5000, 500

local DATA = L.data(warn)

local function read(kind, at)
  local ok, v = pcall(VRFW.mem.read, kind, at)
  if ok then return v end
  return nil
end

local function has(list, x)
  for _, y in ipairs(list or {}) do
    if y == x then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------- carried passives

local BUF_ID, BUF_VERSION, BUF_OUT
local OWN_SLOTS = nil

local function own_slot_of(card)
  if OWN_SLOTS == nil then
    local ok, map = pcall(L.own_slots, function() end)
    OWN_SLOTS = (ok and type(map) == "table") and map or {}
  end
  local e = OWN_SLOTS[u32(card)]
  return e and e.passive or 0
end

-- the game passives character `chara` (a character handle) carries: the 5 team slots, read as the match builder
-- 0x1604E90 reads them (unlocked slot, slot reader, rarity version), and his own passive slot; a set of ids
local function carried_of_chara(chara)
  if not chara or chara == 0 then return {} end
  local ok_rec, rec = pcall(VRFW.chara.record, chara)
  if not ok_rec or not rec then return {} end
  if not BUF_ID then
    BUF_ID = VRFW.mem.buffer("special_players_passive_id", 4)
    BUF_VERSION = VRFW.mem.buffer("special_players_passive_version", 4)
    BUF_OUT = VRFW.mem.buffer("special_players_passive_out", 8)
  end
  local rarity = rec.rarity or 0
  local out = {}
  for k = 0, N_SLOTS - 1 do
    local ok, unlocked = pcall(VRFW.call, "SpecialPlayers.TeamPassiveUnlocked", chara, k, 1)
    if ok and unlocked ~= 0 then
      VRFW.mem.write("u32", BUF_ID, 0)
      if pcall(VRFW.call, "SpecialPlayers.TeamPassiveId", BUF_ID, chara, k, 1) then
        local id = read("u32", BUF_ID) or 0
        if id ~= 0 then
          local v = id
          VRFW.mem.write("u32", BUF_VERSION, id)
          VRFW.mem.write("ptr", BUF_OUT, 0)
          if pcall(VRFW.call, "SpecialPlayers.PassiveRarityVersion", BUF_OUT, BUF_VERSION, rarity) then
            local p = read("ptr", BUF_OUT) or 0
            if p >= 0x10000 then
              local x = read("u32", p) or 0
              if x ~= 0 then v = x end
            end
          end
          out[v] = true
        end
      end
    end
  end
  if type(rec.param) == "number" then
    local own = own_slot_of(rec.param)
    if own ~= 0 then out[own] = true end
  end
  return out
end

local function actor_chara(actor)
  local ok, unit = pcall(VRFW.call, "SpecialPlayers.ActorUnit", actor)
  if not ok or type(unit) ~= "number" or unit < 0x10000 then return 0 end
  return read("u32", unit + UNIT_CHARA) or 0
end

-- ---------------------------------------------------------------------------------------------- players on the pitch

local BY_CHARACTER, BY_CARD = nil, nil

local function index_characters()
  BY_CHARACTER, BY_CARD = {}, {}
  for _, e in ipairs(DATA.characters) do
    if e.card ~= "" then
      local c = L.id_of(e.card)
      if c and c ~= 0 then BY_CARD[c] = e.passives end
    else
      local base = L.character_id(e.character)
      if base and base ~= 0 then BY_CHARACTER[base] = e.passives else warn(e.where .. ": no character " .. tostring(e.character)) end
    end
  end
end

local ANY_CARRIED = false
for _, p in pairs(DATA.passives) do
  if #p.carried_by > 0 then ANY_CARRIED = true end
end

local PLAYERS, PLAYERS_AT, CARRIED = nil, -1e12, {}

-- the passive level of a character handle: the first level of [levels] from_player_level his player level reached
local function passive_level(chara)
  local ok, rec = pcall(VRFW.chara.record, chara)
  local lv = (ok and rec and rec.level) or 1
  local out = 1
  for i, need in ipairs(DATA.levels) do
    if lv >= need then out = i end
  end
  return out
end

-- every player on the pitch: { handle, team, side, element (word), position (number), card, chara, passives }
local function players()
  local now = VRFW.now()
  if PLAYERS and now - PLAYERS_AT < PLAYERS_TTL_MS then return PLAYERS end
  if BY_CHARACTER == nil then index_characters() end
  local out = {}
  local actors = VRFW.game.special_players_actors()
  if actors and actors ~= 0 then
    for i = 0, ACTOR_MAX - 1 do
      local actor = actors + i * ACTOR_STRIDE
      local hdl = read("u32", actor + ACTOR_HANDLE) or 0
      local a = hdl ~= 0 and VRFW.actor(hdl) or nil
      if a and a.team ~= nil then
        local card = a.card and u32(a.card) or 0
        local ci = card ~= 0 and VRFW.chara.card(card) or nil
        local list = {}
        for _, p in ipairs(BY_CARD[card] or BY_CHARACTER[u32(a.chara or 0)] or {}) do list[#list + 1] = p end
        if ANY_CARRIED then
          local c = CARRIED[hdl]
          if not c or now - c.at >= CARRIED_TTL_MS then
            c = { at = now, set = carried_of_chara(actor_chara(actor)) }
            CARRIED[hdl] = c
          end
          for _, p in pairs(DATA.passives) do
            for _, id in ipairs(p.carried_by) do
              if c.set[id] then
                list[#list + 1] = p
                break
              end
            end
          end
        end
        out[#out + 1] = { handle = hdl, team = a.team, side = a.side, element = a.element, position = ci and ci.position or 0,
          card = card, chara = a.chara, passives = list, carried = CARRIED[hdl] and CARRIED[hdl].set or {},
          level = passive_level(actor_chara(actor)) }
      end
    end
  end
  PLAYERS, PLAYERS_AT = out, now
  return out
end

local function player(hdl)
  for _, p in ipairs(players()) do
    if p.handle == hdl then return p end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------------- stacks

local STACKS = {}   -- [carrier handle][passive key] = { n, at, half }
local DIRTY = true

local function current_half(ev)
  local m = (ev and ev.match) or VRFW.match() or {}
  return m.half
end

-- the passive's strength for carrier `h`: its stacks (always 1 without a trigger), 0 = off
local function level(h, p, ev)
  if #p.triggers == 0 then return 1 end
  local s = STACKS[h.handle] and STACKS[h.handle][p.key]
  if not s or s.n <= 0 then return 0 end
  local st = p.stack and p.stack.v
  if st and st.duration_s > 0 and VRFW.now() - s.at > st.duration_s * 1000 then
    s.n, DIRTY = 0, true
    return 0
  end
  if st and st.per_half and s.half ~= nil and current_half(ev) ~= s.half then
    s.n, DIRTY = 0, true
    return 0
  end
  return s.n
end

local function gain(h, p, ev)
  STACKS[h.handle] = STACKS[h.handle] or {}
  local s = STACKS[h.handle][p.key] or { n = 0 }
  level(h, p, ev)
  local max = p.stack and p.stack.v.max or 1
  if max == 0 or s.n < max then s.n = s.n + 1 end
  s.at, s.half = VRFW.now(), current_half(ev)
  STACKS[h.handle][p.key] = s
  DIRTY = true
end

local function reset(h, p)
  local s = STACKS[h.handle] and STACKS[h.handle][p.key]
  if s and s.n > 0 then
    s.n, DIRTY = 0, true
  end
end

-- ---------------------------------------------------------------------------------------------- whose / whom

-- event player `who` (an actor table or nil) seen from carrier `h`
local BY = {
  self = function(h, who) return who ~= nil and u32(who.handle) == h.handle end,
  teammate = function(h, who) return who ~= nil and who.team == h.team and u32(who.handle) ~= h.handle end,
  team = function(h, who) return who ~= nil and who.team == h.team end,
  opponent = function(h, who) return who ~= nil and who.team ~= nil and who.team ~= h.team end,
  anyone = function() return true end,
}

-- player `t` is a target of effect values `v` of carrier `h`
local TARGET = {
  self = function(h, t) return t.handle == h.handle end,
  teammates = function(h, t) return t.team == h.team and t.handle ~= h.handle end,
  team = function(h, t) return t.team == h.team end,
  opponents = function(h, t) return t.team ~= h.team end,
  all = function() return true end,
}

local function is_target(h, v, t)
  local f = TARGET[v.target or "self"]
  if not f or not f(h, t) then return false end
  if v.positions and #v.positions > 0 then
    local ok = false
    for _, w in ipairs(v.positions) do
      if DATA.positions[w] == t.position then ok = true end
    end
    if not ok then return false end
  end
  if v.elements and #v.elements > 0 and not has(v.elements, t.element) then return false end
  return true
end

-- ---------------------------------------------------------------------------------------------- conditions

local MOVES = nil   -- [skill id] = { category, flags }

local function move_info(skill)
  if MOVES == nil then
    MOVES = {}
    for _, id in ipairs({ "skill/skill", "skill" }) do
      local ok, rows = pcall(VRFW.table.rows, id)
      if ok and type(rows) == "table" and #rows > 0 then
        for _, r in ipairs(rows) do
          if r.skill_id then MOVES[u32(r.skill_id)] = { category = r.category or 0, flags = u32(r.skill_effect_bit_flag or 0) } end
        end
        break
      end
    end
  end
  return MOVES[u32(skill)]
end

-- the move `skill` is one of the kinds (empty = any)
local function move_kind_ok(kinds, skill)
  if not kinds or #kinds == 0 then return true end
  local m = skill and move_info(skill)
  if not m then return false end
  for _, k in ipairs(kinds) do
    local d = DATA.move_kinds[k]
    if d and d.category == m.category and (not d.flag or bit32.band(m.flags, d.flag) ~= 0) then return true end
  end
  return false
end

local MOVE_IDS = {}

local function moves_of(b)
  local ids = MOVE_IDS[b.key]
  if ids then return ids end
  ids = {}
  for _, m in ipairs(b.v.moves) do
    local ok, id = pcall(VRFW.technique, m)
    if ok and type(id) == "number" and id ~= 0 then ids[u32(id)] = true else ids[L.id_of(m) or 0] = true end
  end
  MOVE_IDS[b.key] = ids
  return ids
end

local ROLLS = 0

local function score_state(h, ev)
  local m = (ev and ev.match) or VRFW.match() or {}
  local s = m.score
  if type(s) ~= "table" or type(h.team) ~= "number" then return nil end
  local mine, theirs = s[h.team + 1], s[2 - h.team]
  if type(mine) ~= "number" or type(theirs) ~= "number" then return nil end
  if mine > theirs then return "leading" elseif mine < theirs then return "trailing" end
  return "level"
end

-- one function per condition type: (block values, carrier, event, block, counting) -> holds. A move condition holds
-- at a moment without a move (it filters the move where the effect applies).
local CONDITIONS = {
  MoveElement = function(v, _, ev) return ev.move_element == nil or has(v.elements, ev.move_element) end,
  Move = function(_, _, ev, b) return ev.skill == nil or moves_of(b)[u32(ev.skill)] == true end,
  MoveKind = function(v, _, ev) return ev.skill == nil or move_kind_ok(v.kinds, ev.skill) end,
  Outcome = function(v, _, ev)
    if ev.arg == nil or ev.arg == "" then return false end
    return has(DATA.outcomes[v.result], ev.arg)
  end,
  CarrierElement = function(v, h) return has(v.elements, h.element) end,
  CarriesPassive = function(v, h)
    for _, k in ipairs(v.passives) do
      if h.carried[L.id_of(k) or 0] then return true end
    end
    return false
  end,
  Side = function(v, h) return h.side == v.side end,
  HasBall = function(_, h)
    local a = VRFW.actor(h.handle)
    return a ~= nil and a.has_ball == true
  end,
  Score = function(v, h, ev) return has(v.states, score_state(h, ev)) end,
  Half = function(v, _, ev) return has(v.halves, current_half(ev)) end,
  Clock = function(v, _, ev)
    local m = (ev and ev.match) or VRFW.match() or {}
    local c = m.clock
    if type(c) ~= "number" then return false end
    return c >= v.from_minute * 60 and (v.until_minute == 0 or c < v.until_minute * 60)
  end,
  Chance = function(v, h, _, _, counting)
    if not counting then return true end
    ROLLS = ROLLS + 1
    return VRFW.rng("SpecialPlayers.chance", { VRFW.now(), ROLLS, h.handle }):below(100) < v.percent
  end,
}

local function holds(p, h, ev, counting)
  for _, b in ipairs(p.conditions) do
    local f = CONDITIONS[b.type]
    if not f then
      warn(b.where .. ": no rule for condition type " .. tostring(b.type))
      return false
    end
    if not f(b.v, h, ev or {}, b, counting) then return false end
  end
  return true
end

-- ---------------------------------------------------------------------------------------------- effects

-- an effect's amount for carrier `h` (its passive level's value when the block has value_by_level) × `stacks`
local function amount(b, stacks, h)
  local per = b.v.value_by_level
  local v = b.v[b.meta.amount_key] or 0
  if type(per) == "table" and #per > 0 then
    v = per[math.min(math.max(h and h.level or 1, 1), #per)] or v
  end
  return v * stacks
end

-- at once, on the counting event: one function per kind
local AT_ONCE = {
  tension = function(_, b, _, _) VRFW.add_tension(b.v.units, b.v.team) end,
  refuse = function(out, b, h, who) if who and u32(who.handle) == h.handle then out[b.meta.answer] = true end end,
}

-- lasting, answered on a hook for its user `t`: one function per kind
local LASTING = {
  power = function(out, b, lvl, t, ev, h)
    if not is_target(h, b.v, t) or not move_kind_ok(b.v.kinds, ev.skill) then return end
    if b.v.mode == "flat" then
      out.power_add = (out.power_add or 0) + math.floor(amount(b, lvl, h) + 0.5)
    else
      out.power_mult = (out.power_mult or 1) * math.max(0, 1 + amount(b, lvl, h) / 100)
    end
  end,
  rate = function(out, b, lvl, t, _, h)
    if not is_target(h, b.v, t) then return end
    out[b.meta.answer] = (out[b.meta.answer] or 1) * math.max(0, 1 + amount(b, lvl, h) / 100)
  end,
}

-- ---------------------------------------------------------------------------------------------- handlers

local function hooks_of(key)
  return DATA.hooks[key:match("^[^:]+")] or {}
end

-- effect `e` is answered on trigger `key`
local function has_hook(e, key)
  local base = key:match("^[^:]+")
  for x in tostring(e.meta.hooks or ""):gmatch("[%w_]+") do
    if x == base then return true end
  end
  return false
end

local function answer(key, ev)
  local out, any = {}, false
  local who = ev.actor
  local list = DATA.listen[key]
  if list then
    for _, h in ipairs(players()) do
      for _, p in ipairs(h.passives) do
        if has(list, p) then
          for _, b in ipairs(p.resets) do
            local f = BY[b.v.by]
            if L.event_key(b) == key and f and f(h, who) then reset(h, p) end
          end
          for _, b in ipairs(p.triggers) do
            local f = BY[b.v.by]
            if L.event_key(b) == key and f and f(h, who) and holds(p, h, ev, true) then
              gain(h, p, ev)
              for _, e in ipairs(p.effects) do
                local g = AT_ONCE[e.meta.apply]
                if g then
                  g(out, e, h, who)
                  any = true
                end
              end
            end
          end
        end
      end
    end
  end
  -- the lasting effects answered on this trigger, for its player
  local hook = hooks_of(key)
  local t = who and player(u32(who.handle))
  if #hook > 0 and t then
    for _, h in ipairs(players()) do
      for _, p in ipairs(h.passives) do
        if has(hook, p) then
          local lvl = level(h, p, ev)
          if lvl > 0 and holds(p, h, ev, false) then
            for _, e in ipairs(p.effects) do
              local g = LASTING[e.meta.apply]
              if g and has_hook(e, key) then
                g(out, e, lvl, t, ev, h)
                any = true
              end
            end
          end
        end
      end
    end
  end
  if not any or next(out) == nil then return nil end
  return out
end

-- the stat parameters: per player and stat, the sum over every passive's Stat effects; written when it changes
local APPLIED = {}   -- [handle][stat] = "add|pct"
local STAT_AT = -1e12

local function stats_tick()
  local now = VRFW.now()
  if not DIRTY and now - STAT_AT < STAT_EVERY_MS then return end
  STAT_AT, DIRTY = now, false
  local want = {}   -- [handle][stat] = { add, pct }
  local all = players()
  local ev = { match = VRFW.match() }
  for _, h in ipairs(all) do
    for _, p in ipairs(h.passives) do
      local lvl = level(h, p, ev)
      if lvl > 0 then
        local ok = nil
        for _, e in ipairs(p.effects) do
          if e.meta.apply == "stat" then
            if ok == nil then ok = holds(p, h, ev, false) end
            if ok then
              for _, t in ipairs(all) do
                if is_target(h, e.v, t) then
                  want[t.handle] = want[t.handle] or {}
                  for _, s in ipairs(e.v.stats) do
                    local w = want[t.handle][s] or { add = 0, pct = 0 }
                    if e.v.mode == "percent" then w.pct = w.pct + amount(e, lvl, h) else w.add = w.add + amount(e, lvl, h) end
                    want[t.handle][s] = w
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  for _, t in ipairs(all) do
    local before = APPLIED[t.handle] or {}
    local now_t = {}
    local seen = {}
    for s, w in pairs(want[t.handle] or {}) do
      local sig = string.format("%g|%g", w.add, w.pct)
      now_t[s], seen[s] = sig, true
      if before[s] ~= sig then
        local ok, why = pcall(VRFW.set_stat, { stat = s, add = w.add, mult = 1 + w.pct / 100, handles = { t.handle } })
        if not ok then warn("set_stat " .. s .. ": " .. tostring(why)) end
      end
    end
    for s in pairs(before) do
      if not seen[s] then pcall(VRFW.set_stat, { stat = s, restore = true, handles = { t.handle } }) end
    end
    APPLIED[t.handle] = now_t
  end
end

-- ---------------------------------------------------------------------------------------------- start

local keys = {}
for k in pairs(DATA.listen) do keys[k] = true end
for k in pairs(DATA.hooks) do keys[k] = true end
local n = 0
for key in pairs(keys) do
  local k = key
  if k == "tick" then
    -- (stats share the tick handler below)
  else
    VRFW.on(k, function(ev) return answer(k, ev) end)
    n = n + 1
  end
end
VRFW.on("match_start", function()
  STACKS, APPLIED, CARRIED, PLAYERS, DIRTY = {}, {}, {}, nil, true
end)
if DATA.has_stat or keys.tick then
  VRFW.on("tick", function(ev)
    local out = keys.tick and answer("tick", ev) or nil
    if DATA.has_stat then stats_tick() end
    return out
  end)
  n = n + 1
end
local n_passives = 0
for _ in pairs(DATA.passives) do n_passives = n_passives + 1 end
info(string.format("%d passive(s), %d character entr(ies), %d trigger(s) answered", n_passives, #DATA.characters, n))
