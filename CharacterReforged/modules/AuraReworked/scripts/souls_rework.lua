-- Souls Rework › totem levels and the skill reel (docs/game/mods/souls-rework-design.md §0 / §4 / §9). Data: every
-- active mod's content\souls\*.toml (lib/data.lua); settings: config.toml; declarations: content\game\souls_rework.toml.
--
-- Once per match frame (`tick`), per player on the pitch whose totem is out:
--   * level points (LP): per second of live play, per focus duel won, per goal, per use of the totem's own move (the
--     LevelRule's amounts × the totem's lp_scale × Level P Plus); a level is kept for the whole match;
--   * with Aura Points' pool running for the totem (config.toml [souls.aura_points] resource): the pool's max = the totem's SP
--     at its level (a level-up adds the difference to the SP left); without it: every summon starts with the extra time
--     of the level reached and a level-up during a summon adds its share (full time × ΔSP / SP[1] × time_scale);
--   * the release button does nothing while a totem is out (native answer on AuraReworked.SoulsPlayer.no_release).
-- The totem's own move rolls the reel: a uniformly random slot of the totem's 6 (seeded per match); the user's rolls are
-- shown by the graft souls_rework_reel (command CMND_AURAREWORKED_SOULS_REEL), the rival's are applied without a reel. The
-- result lands when the reel stops and lasts while the totem is out (timed skills: their seconds; recoveries: at once).
-- Every level-up queues a pop (a speech bubble in the aura type's colours with «+Nv.» over the player's head) for the graft
-- souls_rework_level_pop (command CMND_AURAREWORKED_SOULS_LEVEL_POP; config.toml [souls.level_pop]).

AuraReworked = AuraReworked or {}
AuraReworked.Souls = AuraReworked.Souls or {}
-- the part's switch (Mods options › Souls Rework, applied after a restart): off = nothing of this part runs
if VRFW.option("souls_rework") == 0 then return end
local D = require "lib/data"
local A = require "lib/auras"

local function info(...) VRFW.log("aura_reworked souls:", ...) end
local function warn(...) VRFW.warn("aura_reworked souls:", ...) end

local band = bit32.band
local function hex(v) return string.format("0x%X", v or 0) end

-- config.toml [souls.*]
local CFG_AP = VRFW.files.config("souls.aura_points") or {}
local CFG_STAMINA = VRFW.files.config("souls.stamina") or {}
local CFG_REEL = VRFW.files.config("souls.reel") or {}
local CFG_LEVELS = VRFW.files.config("souls.levels") or {}
local CFG_FX = VRFW.files.config("souls.effects") or {}
local CFG_POP = VRFW.files.config("souls.level_pop") or {}

local SP_RESOURCE = tostring(CFG_AP.resource or "")
local COST_FLAG = tostring(CFG_AP.cost_flag or "")
local START_FLAG = tostring(CFG_AP.start_flag or "")
local STAMINA_RESOURCE = tostring(CFG_STAMINA.resource or "")
local function num(v, d)
  v = tonumber(v)
  if v == nil or v ~= v then return d end
  return v
end
local REEL = {
  show = CFG_REEL.show ~= false,
  open = num(CFG_REEL.open_s, 0.2), spin = num(CFG_REEL.spin_s, 0.8), stop = num(CFG_REEL.stop_s, 0.9),
  result = num(CFG_REEL.result_s, 1.2), close = num(CFG_REEL.close_s, 0.3), rows = num(CFG_REEL.spin_rows_per_s, 12),
  queue = math.max(1, math.floor(num(CFG_REEL.queue, 2))),
}
REEL.land_ms = (REEL.open + REEL.spin + REEL.stop) * 1000
local POP = {
  show = CFG_POP.show ~= false, cpu = CFG_POP.cpu ~= false,
  appear = num(CFG_POP.appear_s, 0.15), hold = num(CFG_POP.hold_s, 1.0), out = num(CFG_POP.out_s, 0.4),
  body = num(CFG_POP.body_height, 28), tail = num(CFG_POP.tail_height, 8), lift = num(CFG_POP.lift, 10),
  rise = num(CFG_POP.rise, 24), text_scale = num(CFG_POP.text_scale, 0.45), pad = num(CFG_POP.pad_x, 8),
  char_width = num(CFG_POP.char_width, 24), text_y = num(CFG_POP.text_offset_y, 0),
  markup = type(CFG_POP.text_markup) == "string" and CFG_POP.text_markup:find("{text}", 1, true) and CFG_POP.text_markup or "{text}",
  widths = {}, bubbles = {}, queue = 8,
}
for _, v in ipairs(type(CFG_POP.bubble_widths) == "table" and CFG_POP.bubble_widths or {}) do
  v = math.floor(num(v, 0))
  if v > 0 then POP.widths[#POP.widths + 1] = v end
end
table.sort(POP.widths)
-- the bubble sprites of an aura type (content/images/menu/02_btl/souls_rework_pop.toml, made by
-- research/scripts/souls_rework_bubble_build.py: souls_rework_bubble_<type>_<width>) as "crc:width;crc:width;…",
-- narrowest first; built once per type
local function bubbles(aura_type)
  -- the retail aura types 0..6 have their bubbles; any other value shows the totem's (3)
  local key = tonumber(aura_type)
  if key == nil or key < 0 or key > 6 then key = 3 end
  if POP.bubbles[key] == nil then
    local list = {}
    for _, w in ipairs(POP.widths) do
      local crc = VRFW.ui.crc32(string.format("souls_rework_bubble_%d_%d", key, w)) % 4294967296
      list[#list + 1] = string.format("%d:%d", crc, w)
    end
    POP.bubbles[key] = table.concat(list, ";")
  end
  return POP.bubbles[key]
end
local SHOT_WINDOW_MS = num(CFG_FX.shot_window_s, 8) * 1000
local KNOCKDOWN_CLIP = tostring(CFG_FX.knockdown_clip or "")
local LIVE = {}
-- the level rule: the amounts of level points and the thresholds (config.toml [souls.levels])
local function amount(v, d)
  v = num(v, d)
  return v < 0 and d or v
end
local RULE = {
  per_second = amount(CFG_LEVELS.per_second, 1.0), per_duel_won = amount(CFG_LEVELS.per_duel_won, 15.0),
  per_goal = amount(CFG_LEVELS.per_goal, 30.0), per_own_move = amount(CFG_LEVELS.per_own_move, 10.0),
  time_scale = amount(CFG_LEVELS.time_scale, 1.0),
  cpu = CFG_LEVELS.cpu ~= false, no_release = CFG_LEVELS.no_release ~= false, thresholds = {},
}
for _, v in ipairs(type(CFG_LEVELS.thresholds) == "table" and CFG_LEVELS.thresholds or { 30, 80, 150, 240 }) do
  if type(v) == "number" and v >= 0 then RULE.thresholds[#RULE.thresholds + 1] = v end
end
for _, s in ipairs(type(CFG_LEVELS.live_states) == "table" and CFG_LEVELS.live_states or { 9, 14, 15, 16 }) do LIVE[s] = true end

-- the part's settings of Mods options (options.toml), read again at every match start:
--   souls_top_level     every totem is at its top level from the start (no level points, no level-up)
--   souls_reel          the reel is shown (off: the rolls apply without it)
--   souls_rival_levels  the rival team's totems level up and roll too
local OPT = { top_level = false }
local function read_options()
  OPT.top_level = VRFW.option("souls_top_level") == 1
  REEL.show = CFG_REEL.show ~= false and VRFW.option("souls_reel") ~= 0
  RULE.cpu = CFG_LEVELS.cpu ~= false and VRFW.option("souls_rival_levels") ~= 0
end
read_options()

-- game layout (docs/game/mechanics/keshin-armed.md §2.2, aura-costs.md §2)
local ACTOR_MAX, ACTOR_STRIDE = 0x3A, 0x570
local SUMMON_FULL, SUMMON_LEFT = 0x360, 0x370
local SUMMON_ACTIVE = 2
local ATTR_KESHIN, ATTR_TOTEM = 1, 8
local IN_PLAY_STATE = 9
local MODE_DECIDE_FRAMES = 3
local SLOTS = 6

local DATA = nil

-- ---------------------------------------------------------------------------------------------- per-match state

local match = { on = false, no = 0, seed = 0, user = 0xFF, state = 0, dt = 0 }
local players = {}       -- hdl -> { hdl, team, actor, active, pairs = { [aura] = { level, lp, max_level } }, fx = {}, rolls }
local pending = {}       -- rolls waiting for the reel to stop: { hdl, aura, slot, at, seq }
local reel_queue = {}    -- shown rolls for the graft: { seq, ... }
local reel_seq = 0
local pop_queue = {}     -- level-up pops for the graft: { seq, hdl, text, bubbles }
local pop_seq = 0
local last_shot = nil    -- { hdl, team, at }: the last shot's player (Numbness +)
local knocked = {}       -- hdl -> { mult, until }: players slowed by a knock-down
local timed_count = 0    -- live timed effects (move_speed answers stay cheap without any)
local records = {}       -- AuraReworked.SoulsPlayer rows written: hdl -> fields

local function now() return VRFW.now() end

local function player(hdl)
  local p = players[hdl]
  if not p then
    p = { hdl = hdl, team = 0xFF, actor = nil, active = nil, pairs = {}, fx = {}, rolls = 0 }
    players[hdl] = p
  end
  return p
end

local function applies(team) return RULE == nil or RULE.cpu or team == match.user end

local function flag(name) return VRFW.flag(name) or 0 end

local function record(hdl, fields)
  local old = records[hdl]
  local same = old ~= nil and fields ~= nil
  if same then
    for k, v in pairs(fields) do if old[k] ~= v then same = false end end
    for k in pairs(old) do if fields[k] == nil then same = false end end
  end
  if same or (old == nil and fields == nil) then return end
  records[hdl] = fields
  pcall(VRFW.native.table_set, "AuraReworked.SoulsPlayer", hdl, fields)
end

local function clear_match()
  for hdl, p in pairs(players) do
    for name in pairs(p.fx) do
      if p.fx[name].flag then pcall(VRFW.clear_flag, p.fx[name].flag) end
    end
  end
  players, pending, reel_queue, knocked, records, pop_queue = {}, {}, {}, {}, {}, {}
  last_shot, timed_count = nil, 0
  pcall(VRFW.native.table_clear, "AuraReworked.SoulsPlayer")
end

-- ---------------------------------------------------------------------------------------------- the data

local function ensure_data()
  if DATA then return DATA end
  A.load()
  DATA = D.load(warn)
  local n_known = 0
  for key in pairs(DATA.totems) do
    if A.id(key) then n_known = n_known + 1 else warn("totem " .. key .. ": no such aura in the served aura table") end
  end
  local n_skills = 0
  for _ in pairs(DATA.skills) do n_skills = n_skills + 1 end
  info(string.format("data: %d totems (%d in the aura table), %d skill families; LP %s/s, %s per duel won, %s per goal, %s per own move, thresholds [%s], time_scale %s, CPU %s, no release %s; Aura Points pool %q",
    DATA.count, n_known, n_skills, tostring(RULE.per_second), tostring(RULE.per_duel_won), tostring(RULE.per_goal),
    tostring(RULE.per_own_move), table.concat(RULE.thresholds or {}, ", "), tostring(RULE.time_scale), tostring(RULE.cpu),
    tostring(RULE.no_release), SP_RESOURCE))
  return DATA
end

local function totem_of(aura) return ensure_data().totems[A.key(aura)] end

local function text(key, level)
  local s = nil
  if type(key) == "string" and key ~= "" then
    local ok, r = pcall(VRFW.text, key)
    if ok and type(r) == "string" and r ~= "" then s = r end
  end
  s = s or tostring(key or "")
  return (s:gsub("{level}", tostring(level or "")))
end

-- ---------------------------------------------------------------------------------------------- Aura Points' pool

local function pool(hdl, aura)
  if SP_RESOURCE == "" then return nil end
  local ok, v = pcall(VRFW.resource.get, SP_RESOURCE, hdl, aura)
  if ok and type(v) == "table" then return v end
  return nil
end

-- the pool's max = SP[level]; a level-up adds the max's difference to the SP left (the first setting keeps the ratio)
local function apply_pool_max(p, aura, st, T)
  local v = pool(p.hdl, aura)
  if not v or not v.touched or not v.max or v.max <= 0 then return false end
  local target = T.sp[math.min(st.level, #T.sp)]
  if math.abs(v.max - target) < 0.01 then
    st.pool_level = st.level
    return true
  end
  local old_cur, old_max = v.cur, v.max
  local ok = pcall(VRFW.resource.scale, SP_RESOURCE, p.hdl, aura, target / old_max)
  local after = pool(p.hdl, aura)
  if not ok or not after then return false end
  if st.pool_level ~= nil then
    local want = math.max(0, math.min(target, old_cur + (target - old_max)))
    if math.abs(want - after.cur) > 0.01 then pcall(VRFW.resource.add, SP_RESOURCE, p.hdl, want - after.cur, false, aura) end
  end
  local final = pool(p.hdl, aura) or after
  info(string.format("actor %s T%d: totem %s Lv%d: SP max %.0f -> %.0f, SP %.0f -> %.0f", hex(p.hdl), p.team, A.key(aura),
    st.level, old_max, final.max, old_cur, final.cur))
  st.pool_level = st.level
  return true
end

-- ---------------------------------------------------------------------------------------------- the timer (no pool)

local function add_time(p, seconds, why)
  if not p.actor or seconds <= 0 then return end
  local okl, left = pcall(VRFW.mem.read, "f32", p.actor + SUMMON_LEFT)
  local okf, full = pcall(VRFW.mem.read, "f32", p.actor + SUMMON_FULL)
  if not okl or not okf or type(left) ~= "number" or type(full) ~= "number" then return end
  pcall(VRFW.mem.write, "f32", p.actor + SUMMON_LEFT, left + seconds)
  pcall(VRFW.mem.write, "f32", p.actor + SUMMON_FULL, full + seconds)
  info(string.format("actor %s T%d: totem time +%.1f s (%s): %.1f / %.1f -> %.1f / %.1f", hex(p.hdl), p.team, seconds, why,
    left, full, left + seconds, full + seconds))
end

-- the extra seconds of levels from -> to for a summon of full time `base`
local function time_bonus(T, base, from, to)
  local sp1 = T.sp[1]
  if not sp1 or sp1 <= 0 or to <= from then return 0 end
  local a, b = T.sp[math.min(from, #T.sp)], T.sp[math.min(to, #T.sp)]
  return base * (b - a) / sp1 * (RULE.time_scale or 1)
end

-- ---------------------------------------------------------------------------------------------- levels

local function lp_mult(p)
  local m = 1
  for _, fx in pairs(p.fx) do
    if fx.effect == "level_points" then m = m * (1 + fx.value / 100) end
  end
  return m
end

-- the pop over the player: a speech bubble in the colours of the aura's type, the text «+Nv.2» (its {level} = the new
-- level) in the configured colour markup
local function queue_pop(p, aura, level)
  if not POP.show or (not POP.cpu and p.team ~= match.user) then return end
  while #pop_queue >= POP.queue do table.remove(pop_queue, 1) end
  pop_seq = pop_seq + 1
  local label = text("aura_reworked.level_pop", level)
  pop_queue[#pop_queue + 1] = { seq = pop_seq, at = now(), hdl = p.hdl,
    text = (POP.markup:gsub("{text}", (label:gsub("%%", "%%%%")))),
    bubbles = bubbles(A.type(aura)) }
end

local function level_up(p, aura, st, T)
  local old = st.level
  st.level = st.level + 1
  info(string.format("actor %s T%d: totem %s Lv%d -> Lv%d (LP %.1f)", hex(p.hdl), p.team, A.key(aura), old, st.level, st.lp))
  queue_pop(p, aura, st.level)
  local act = p.active
  if act and act.aura == aura then
    if act.mode == "points" then
      apply_pool_max(p, aura, st, T)
    elseif act.mode == "timer" then
      add_time(p, time_bonus(T, act.base, old, st.level), string.format("Lv%d", st.level))
    end
  end
end

local function add_lp(p, amount, why)
  local act = p.active
  if OPT.top_level or not act or amount <= 0 then return end
  local T = totem_of(act.aura)
  if not T then return end
  local st = p.pairs[act.aura]
  local gain = amount * (T.lp_scale or 1) * lp_mult(p)
  st.lp = st.lp + gain
  local th = RULE.thresholds or {}
  while st.level < #T.sp and th[st.level] and st.lp >= th[st.level] do level_up(p, act.aura, st, T) end
  if why then info(string.format("actor %s T%d: totem %s +%.1f LP (%s): %.1f, Lv%d", hex(p.hdl), p.team, A.key(act.aura), gain, why, st.lp, st.level)) end
end

-- ---------------------------------------------------------------------------------------------- reel results

local function actor_of(hdl)
  local ok, a = pcall(VRFW.actor, hdl)
  if ok and type(a) == "table" then return a end
  return nil
end

local function team_word(p) return p.team == match.user and "user" or "rival" end

local function skill_value(s, level, list) return (s[list] and s[list][math.min(level, #s[list])]) or 0 end

local function set_fx(p, s, level, fx)
  local old = p.fx[s.name]
  if old and old.flag and old.flag ~= fx.flag then pcall(VRFW.clear_flag, old.flag) end
  if old and old.timed then timed_count = timed_count - 1 end
  fx.name, fx.effect, fx.level = s.name, s.effect, level
  p.fx[s.name] = fx
  if fx.timed then timed_count = timed_count + 1 end
end

local function drop_fx(p, name)
  local fx = p.fx[name]
  if not fx then return end
  if fx.flag then pcall(VRFW.clear_flag, fx.flag) end
  if fx.timed then timed_count = timed_count - 1 end
  p.fx[name] = nil
end

local function team_stamina(p, percent)
  if STAMINA_RESOURCE == "" then return false end
  local done = 0
  for h, q in pairs(players) do
    if q.team == p.team and q.seen == match.frame then
      local ok, v = pcall(VRFW.resource.get, STAMINA_RESOURCE, h)
      if ok and type(v) == "table" and v.max and v.max > 0 then
        pcall(VRFW.resource.add, STAMINA_RESOURCE, h, v.max * percent / 100)
        done = done + 1
      end
    end
  end
  return done > 0
end

local function nearest_opponent(p)
  local me = actor_of(p.hdl)
  if not me or not me.x then return nil end
  local best, best_d = nil, nil
  for h, q in pairs(players) do
    if q.team ~= p.team and q.team <= 1 and q.seen == match.frame then
      local a = actor_of(h)
      if a and a.x then
        local d = (a.x - me.x) ^ 2 + (a.z - me.z) ^ 2
        if not best_d or d < best_d then best, best_d = h, d end
      end
    end
  end
  return best
end

-- one result lands: what the skill family does for player p at skill level `level`
local function apply_result(p, s, level, depth)
  local e, v = s.effect, skill_value(s, level, "values")
  local secs = skill_value(s, level, "seconds")
  local until_ms = (#s.seconds > 0 and secs > 0) and (now() + secs * 1000) or nil
  local act = p.active
  if e == "none" then
    return "miss"
  elseif e == "move_power" or e == "shot_vs_keeper" or e == "keeper_vs_shot" or e == "level_points" then
    set_fx(p, s, level, { value = v, kinds = s.move_kinds, until_ms = until_ms, timed = until_ms ~= nil })
    return string.format("%s %+.0f %%%s", e, v, until_ms and string.format(" for %.0f s", secs) or " while out")
  elseif e == "point_cost" then
    if act and act.mode == "points" and COST_FLAG ~= "" then
      local name = COST_FLAG .. "." .. p.hdl
      pcall(VRFW.set_flag, name, math.max(1, math.floor(100 - v + 0.5)))
      set_fx(p, s, level, { value = v, flag = name, until_ms = until_ms, timed = until_ms ~= nil })
      return string.format("SP costs -%.0f %% (flag %s)", v, name)
    end
    set_fx(p, s, level, { value = v, until_ms = until_ms, timed = until_ms ~= nil })
    return string.format("tension costs -%.0f %%", v)
  elseif e == "team_stamina" then
    if team_stamina(p, v) then return string.format("team stamina +%.0f %%", v) end
    local fb = s.fallback ~= "" and DATA.skills[s.fallback]
    if fb and (depth or 0) < 1 then return "no stamina: " .. apply_result(p, fb, level, (depth or 0) + 1) end
    return "no stamina resource"
  elseif e == "team_tension" or e == "team_stamina_tension" then
    local units = skill_value(s, level, "units")
    local parts = {}
    if e == "team_stamina_tension" and team_stamina(p, v) then parts[#parts + 1] = string.format("stamina +%.0f %%", v) end
    if units > 0 then
      pcall(VRFW.add_tension, units, team_word(p))
      parts[#parts + 1] = string.format("tension +%d", units)
    end
    return "team " .. table.concat(parts, ", ")
  elseif e == "move_speed" or e == "untouchable" then
    set_fx(p, s, level, { value = v, until_ms = until_ms, timed = true })
    return string.format("%s %+.0f %% for %.0f s", e, v, secs)
  elseif e == "knockdown" then
    local h = nearest_opponent(p)
    if not h then return "knock-down: no opponent" end
    if not knocked[h] then timed_count = timed_count + 1 end
    knocked[h] = { mult = math.max(0, 1 + v / 100), until_ms = now() + secs * 1000 }
    if KNOCKDOWN_CLIP ~= "" and VRFW.clip and VRFW.clip.play then pcall(VRFW.clip.play, h, KNOCKDOWN_CLIP) end
    return string.format("knock-down on %s: speed x%.2f for %.0f s", hex(h), knocked[h].mult, secs)
  end
  return "unknown effect " .. tostring(e)
end

-- the «while out» results end with the totem
local function totem_over(p)
  for name, fx in pairs(p.fx) do
    if not fx.until_ms then drop_fx(p, name) end
  end
end

-- ---------------------------------------------------------------------------------------------- the reel

local function roll(p, aura, T)
  p.rolls = p.rolls + 1
  local slot = 1
  local ok, rng = pcall(VRFW.rng, "aura_reworked.souls_reel", { match.seed, p.hdl, aura, p.rolls })
  if ok and rng then slot = rng:below(#T.slots) + 1 end
  local s = T.slots[slot]
  local shown = REEL.show and p.team == match.user
  local item = { hdl = p.hdl, aura = aura, slot = slot, at = now() + REEL.land_ms, shown = shown }
  pending[#pending + 1] = item
  local st = p.pairs[aura]
  if shown then
    while #reel_queue >= REEL.queue do table.remove(reel_queue, 1) end
    reel_seq = reel_seq + 1
    local labels = {}
    local miss = 0
    for i, x in ipairs(T.slots) do
      labels[i] = text(x.skill.text, x.level)
      if x.skill.effect == "none" then miss = miss + 2 ^ (i - 1) end
    end
    reel_queue[#reel_queue + 1] = { seq = reel_seq, title = T.name ~= "" and text(T.name, nil) or A.key(aura), level = text("aura_reworked.reel_level", st and st.level or 1),
      slot = slot, labels = labels, miss = miss }
    item.seq = reel_seq
  end
  info(string.format("actor %s T%d: totem %s rolls slot %d/%d (%s)%s; lands in %.1f s", hex(p.hdl), p.team, A.key(aura), slot, #T.slots,
    s.text, shown and " on the reel" or " (not shown)", REEL.land_ms / 1000))
end

local function land_pending()
  local t = now()
  local keep = {}
  for _, item in ipairs(pending) do
    if t >= item.at then
      local p = players[item.hdl]
      local T = totem_of(item.aura)
      if p and T and p.active and p.active.aura == item.aura then
        local s = T.slots[item.slot]
        info(string.format("actor %s T%d: reel %s: slot %d %s -> %s", hex(p.hdl), p.team, A.key(item.aura), item.slot, s.text, apply_result(p, s.skill, s.level)))
      elseif p then
        info(string.format("actor %s: reel %s landed after the totem ended: no effect", hex(item.hdl), A.key(item.aura)))
      end
    else
      keep[#keep + 1] = item
    end
  end
  pending = keep
end

local function expire_timed()
  if timed_count <= 0 then return end
  local t = now()
  for _, p in pairs(players) do
    for name, fx in pairs(p.fx) do
      if fx.until_ms and t >= fx.until_ms then drop_fx(p, name) end
    end
  end
  for h, k in pairs(knocked) do
    if t >= k.until_ms then
      knocked[h] = nil
      timed_count = timed_count - 1
    end
  end
end

-- CMND_AURAREWORKED_SOULS_REEL(seen) -> seq, title, level, slot, label1..label6, missMask, open, spin, stop, result, close,
-- rowsPerSecond: the oldest shown roll newer than `seen` (nothing when none). The graft keeps the last seq it played.
function AuraReworked.Souls.Reel(seen)
  seen = tonumber(seen) or 0
  -- a HUD that saw more rolls than this session made (the scripts restarted): start over
  if seen > reel_seq then seen = 0 end
  for _, r in ipairs(reel_queue) do
    if r.seq > seen then
      local l = r.labels
      return r.seq, r.title, r.level, r.slot, l[1] or "", l[2] or "", l[3] or "", l[4] or "", l[5] or "", l[6] or "", r.miss,
        REEL.open, REEL.spin, REEL.stop, REEL.result, REEL.close, REEL.rows
    end
  end
  return 0
end

-- a cut-in or a match scene is playing (the framework's match events cutin_start / cutin_end): the pops hide meanwhile
local scene_playing = false
VRFW.on("cutin_start", function(ev)
  scene_playing = true
  return nil
end)
VRFW.on("cutin_end", function(ev)
  scene_playing = false
  return nil
end)

-- CMND_AURAREWORKED_SOULS_LEVEL_POP(seen) -> seq, scene, hdl, text, bubbles, appear, hold, out, body, tail, lift, rise,
-- text_scale, pad, char_width, text_y (bubbles = the aura type's sprites "crc:width;...", narrowest first): the
-- oldest level-up pop newer than `seen` and at most 1 s old (seq 0 and the scene flag alone when none); scene = 1 while a
-- cut-in or a match scene plays. The graft keeps the last seq it took.
function AuraReworked.Souls.LevelPop(seen)
  seen = tonumber(seen) or 0
  if seen > pop_seq then seen = 0 end
  local in_scene = scene_playing and 1 or 0
  for _, q in ipairs(pop_queue) do
    if q.seq > seen and now() - q.at <= 1000 then
      return q.seq, in_scene, q.hdl, q.text, q.bubbles, POP.appear, POP.hold, POP.out, POP.body, POP.tail, POP.lift,
        POP.rise, POP.text_scale, POP.pad, POP.char_width, POP.text_y
    end
  end
  return 0, in_scene
end

-- ---------------------------------------------------------------------------------------------- the tick

local function decide_mode(p, act, st, T)
  local v = pool(p.hdl, act.aura)
  if v and v.touched then
    act.mode = "points"
    apply_pool_max(p, act.aura, st, T)
  else
    act.mode = "timer"
    if st.level > 1 then add_time(p, time_bonus(T, act.base, 1, st.level), string.format("summoned at Lv%d", st.level)) end
  end
  info(string.format("actor %s T%d: totem %s out at Lv%d (LP %.1f): %s", hex(p.hdl), p.team, A.key(act.aura), st.level, st.lp,
    act.mode == "points" and "SP pool of Aura Points" or string.format("its own timer (%.1f s)", act.base)))
end

local function step_player(p, actor, a)
  local unit_attr = 0
  if a.summon_state == SUMMON_ACTIVE then
    local ok, u = pcall(VRFW.call, "Match.ActorUnit", actor)
    if ok and type(u) == "number" and u >= 0x10000 then
      local okr, attr = pcall(VRFW.mem.read, "u8", u + 0x2B4)
      if okr and type(attr) == "number" then unit_attr = attr end
    end
  end
  local totem = a.summon_state == SUMMON_ACTIVE and band(unit_attr, ATTR_TOTEM) ~= 0 and band(unit_attr, ATTR_KESHIN) == 0
  local T = totem and totem_of(a.summon_skill) or nil
  local act = p.active
  if act and (not T or act.aura ~= a.summon_skill) then
    info(string.format("actor %s T%d: totem %s over at Lv%d", hex(p.hdl), p.team, A.key(act.aura), p.pairs[act.aura].level))
    totem_over(p)
    p.active, act = nil, nil
  end
  if T and applies(p.team) then
    local aura = a.summon_skill
    local st = p.pairs[aura]
    if not st then
      st = { level = OPT.top_level and #T.sp or 1, lp = 0 }
      p.pairs[aura] = st
    end
    if not act then
      act = { aura = aura, frames = 0, base = a.summon_full or 30, mode = nil }
      p.active = act
    end
    act.frames = act.frames + 1
    if not act.mode and act.frames >= MODE_DECIDE_FRAMES then decide_mode(p, act, st, T) end
    if act.mode == "points" and st.pool_level ~= st.level then apply_pool_max(p, aura, st, T) end
    if LIVE[match.state] and a.in_play ~= 0 and match.dt > 0 and match.dt < 1 then add_lp(p, (RULE.per_second or 0) * match.dt) end
  end
  local release = p.active ~= nil and RULE.no_release
  record(p.hdl, p.active and { level = p.pairs[p.active.aura].level, totem = p.active.aura, no_release = release and 0 or nil } or nil)
end

local function base_actors()
  local ok, b = pcall(VRFW.game["Match.SoccerActors.ViaSkillUsed"])
  if ok and type(b) == "number" and b >= 0x10000 then return b end
  return nil
end

VRFW.on("tick", function(ev)
  if not match.on then return nil end
  local m = ev.match or {}
  match.state = m.soccer_state or 0
  match.user = m.user_team or 0xFF
  match.dt = m.dt or 0
  match.frame = (match.frame or 0) + 1
  ensure_data()
  local base = base_actors()
  if not base then return nil end
  for i = 0, ACTOR_MAX - 1 do
    local actor = base + i * ACTOR_STRIDE
    local a = VRFW.mem.read_struct("SrActor", actor)
    if a and a.hdl ~= 0 and band(a.hdl, 0xFF) == i and a.team <= 1 then
      local p = player(a.hdl)
      p.team, p.actor, p.seen = a.team, actor, match.frame
      step_player(p, actor, a)
    end
  end
  land_pending()
  expire_timed()
  return nil
end)

-- every totem's SP bar starts at its level 1, or at its top level with souls_top_level (the pool owner reads
-- <start_flag>.<aura id>; flags live for the session)
local function publish_start_max()
  if START_FLAG == "" then return 0 end
  local n = 0
  for key, T in pairs(ensure_data().totems) do
    local id = A.id(key)
    if id and T.sp[1] then
      pcall(VRFW.set_flag, START_FLAG .. "." .. id, OPT.top_level and T.sp[#T.sp] or T.sp[1])
      n = n + 1
    end
  end
  return n
end

-- CMND_AURAREWORKED_SOULS_TOTEM_LEVEL(hdl) -> true, level, «Lv.3» (text key aura_reworked.reel_level), progress, top of the
-- totem the match player has out now; nothing when he has none. progress = his level points toward the next level
-- (0..1: from this level's threshold to the next one, config.toml [souls.levels] thresholds); top = 1 at the totem's
-- last level (progress 1). The handle may come signed or unsigned: both forms are tried.
function AuraReworked.Souls.TotemLevel(hdl)
  local h = tonumber(hdl)
  if not h then return nil end
  local p = players[h] or players[h % 4294967296] or players[h - 4294967296]
  if not p or not p.active then return nil end
  local st = p.pairs[p.active.aura]
  if not st then return nil end
  local T = totem_of(p.active.aura)
  local th = RULE.thresholds or {}
  local to = th[st.level]
  if not T or st.level >= #T.sp or not to then
    return true, st.level, text("aura_reworked.reel_level", st.level), 1, 1
  end
  local from = th[st.level - 1] or 0
  local progress = to > from and math.max(0, math.min(1, (st.lp - from) / (to - from))) or 1
  return true, st.level, text("aura_reworked.reel_level", st.level), progress, 0
end

-- again after a return to the title (a load-time flag write may be refused: then the first one is here)
VRFW.on("game_reset", function(ev)
  publish_start_max()
  return nil
end)

VRFW.on("match_start", function(ev)
  scene_playing = false
  read_options()
  publish_start_max()
  clear_match()
  match.on = true
  match.no = match.no + 1
  match.seed = match.no * 7919 + (now() % 100000)
  match.frame = 0
  info(string.format("match #%d: reel seed %d; top level %s, reel %s, rival levels %s", match.no, match.seed,
    tostring(OPT.top_level), tostring(REEL.show), tostring(RULE.cpu)))
  return nil
end)

VRFW.on("match_end", function(ev)
  for _, p in pairs(players) do
    for key, st in pairs(p.pairs) do
      if st.level > 1 then info(string.format("match #%d end: actor %s T%d totem %s Lv%d (LP %.1f)", match.no, hex(p.hdl), p.team, A.key(key), st.level, st.lp)) end
    end
  end
  clear_match()
  match.on = false
  return nil
end)

-- ---------------------------------------------------------------------------------------------- level points

local function actor_player(ev)
  local h = ev.actor and ev.actor.handle
  return h and players[h] or nil
end

VRFW.on("duel_won", function(ev)
  local p = actor_player(ev)
  if p and p.active then add_lp(p, RULE.per_duel_won or 0, "duel won") end
  return nil
end)

VRFW.on("goal", function(ev)
  local p = actor_player(ev)
  if p and p.active then add_lp(p, RULE.per_goal or 0, "goal") end
  return nil
end)

-- the totem's own move: LP and a roll of the reel
VRFW.on("match:skill_used:post", function(ev)
  if not match.on then return nil end
  -- the hook hands the handle as a signed number (0x8000000D < 0): back to u32 before the player lookup
  local hdl = (tonumber(ev.args and ev.args[1]) or 0) % 4294967296
  local ptr = (tonumber(ev.args and ev.args[2]) or 0) % 18446744073709551616
  if hdl == 0 or ptr < 0x10000 then return nil end
  local ok, skill = pcall(VRFW.mem.read, "u32", ptr)
  local p = players[hdl]
  if not ok or not p or not p.active then return nil end
  skill = (tonumber(skill) or 0) % 4294967296
  local aura = p.active.aura
  local own = A.move(aura)
  local T = totem_of(aura)
  -- one line per move used with a totem out: the ids compared
  info(string.format("actor %s T%d: move %s used with totem %s (%s) out: its own move %s -> %s", hex(hdl), p.team, hex(skill),
    hex(aura), A.key(aura), hex(own), (own ~= 0 and own == skill and T) and "reel" or "not the totem's move"))
  if own == 0 or own ~= skill or not T then return nil end
  add_lp(p, RULE.per_own_move or 0, "own move")
  roll(p, aura, T)
  return nil
end)

-- ---------------------------------------------------------------------------------------------- effect answers

local MOVES = nil   -- skill id -> category
local function category_of(skill)
  if MOVES == nil then
    MOVES = {}
    for _, id in ipairs({ "skill/skill", "skill" }) do
      local ok, rows = pcall(VRFW.table.rows, id)
      if ok and type(rows) == "table" and #rows > 0 then
        for _, r in ipairs(rows) do
          if r.skill_id then
            local sid = tonumber(r.skill_id) or 0
            if sid < 0 then sid = sid + 4294967296 end
            MOVES[sid] = tonumber(r.category) or 0
          end
        end
        break
      end
    end
  end
  return MOVES[skill or 0]
end

local function kind_ok(kinds, cat)
  if type(kinds) ~= "table" or #kinds == 0 then return true end
  for _, k in ipairs(kinds) do
    if DATA.move_kinds[k] == cat then return true end
  end
  return false
end

VRFW.on("move_power", function(ev)
  local p = actor_player(ev)
  if not p or not DATA then return nil end
  local cat = category_of(ev.skill)
  if cat == DATA.move_kinds.shoot then last_shot = { hdl = p.hdl, team = p.team, at = now() } end
  local m = 1
  for _, fx in pairs(p.fx) do
    if fx.effect == "move_power" and kind_ok(fx.kinds, cat) then m = m * (1 + fx.value / 100) end
  end
  if m ~= 1 then return { power_mult = m, log = "aura_reworked souls reel power" } end
  return nil
end)

VRFW.on("keeper_duel", function(ev)
  local keeper = actor_player(ev)
  local m = 1
  if keeper then
    for _, fx in pairs(keeper.fx) do
      if fx.effect == "keeper_vs_shot" then m = m * (1 + fx.value / 100) end
    end
  end
  local s = last_shot
  if s and now() - s.at <= SHOT_WINDOW_MS and (not keeper or s.team ~= keeper.team) and players[s.hdl] then
    for _, fx in pairs(players[s.hdl].fx) do
      if fx.effect == "shot_vs_keeper" then m = m * (1 + fx.value / 100) end
    end
  end
  if m ~= 1 then return { power_mult = m, log = "aura_reworked souls reel keeper duel" } end
  return nil
end)

VRFW.on("tension_pay", function(ev)
  local p = actor_player(ev)
  if not p then return nil end
  local m = 1
  for _, fx in pairs(p.fx) do
    if fx.effect == "point_cost" and not fx.flag then m = m * math.max(0, 1 - fx.value / 100) end
  end
  if m ~= 1 then return { cost_mult = m } end
  return nil
end)

VRFW.on("move_speed", function(ev)
  if timed_count <= 0 then return nil end
  local h = ev.actor and ev.actor.handle
  if not h then return nil end
  local m = 1
  local p = players[h]
  if p then
    for _, fx in pairs(p.fx) do
      if fx.effect == "move_speed" then m = m * (1 + fx.value / 100) end
    end
  end
  if knocked[h] then m = m * knocked[h].mult end
  if m ~= 1 then return { speed_mult = m } end
  return nil
end)

-- Invincible: no block battle against a player of the other side who holds the ball
VRFW.on("block_battle", function(ev)
  if timed_count <= 0 then return nil end
  local blocker = ev.actor
  if not blocker then return nil end
  for h, p in pairs(players) do
    if p.team ~= blocker.team then
      for _, fx in pairs(p.fx) do
        if fx.effect == "untouchable" then
          local a = actor_of(h)
          if a and a.has_ball then return { block = true, log = "aura_reworked souls invincible" } end
        end
      end
    end
  end
  return nil
end)

-- ---------------------------------------------------------------------------------------------- start

ensure_data()
info(string.format("%d totems start at their %s SP (flag %s.<aura>)", publish_start_max(), OPT.top_level and "top level" or "level 1", START_FLAG))
