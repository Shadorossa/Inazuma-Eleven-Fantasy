-- Effect build edits of eff_chr_trigger: [[shot_aura]] rules (aura -> ball trigger, run-time rule table) and [[chr_trigger]] (new character-effect triggers).

local U = require "lib/util"

local M = {}

local INFO = "EFFECT_CHR_TRIGGER_DEFINE_DEF_INFO"
local INFO_BEG = INFO .. "_LIST_BEG"
local INFO_END = INFO .. "_LIST_END"
-- INFO row columns: effect (crc32 of its effect_define name), trigger (crc32 of its name)
local COL_EFFECT = 0
local COL_TRIGGER = 8
local TWO32 = 4294967296

-- Hex digits (optional '+'), at most 32 bits; nil otherwise.
local function parse_hex(h)
  local body = h:match("^%+?(%x+)$")
  if not body then return nil end
  body = body:gsub("^0+", "")
  if #body > 8 then return nil end
  if body == "" then return 0 end
  return tonumber(body, 16)
end
M.parse_hex = parse_hex

local function list(x)
  if x == nil then return {} end
  if type(x) == "table" then return x end
  return { x }
end

-- A game id as written: a number (low 32 bits) or a string (`0x…`, a number, a name's crc32).
local function id_of(x)
  return U.id(x)
end

-- Text form of an id.
local function text_of(x)
  if type(x) == "number" then return VRFW.hex(x % TWO32) end
  return x
end

-- Byte pair as text: {1, 2} -> "[1, 2]".
local function pair(r)
  return "[" .. tostring(r[1]) .. ", " .. tostring(r[2]) .. "]"
end

-- ---- the ball's trigger list

-- Ball list of eff_chr_trigger on handle `t`: `trigger_of(effect)`, `add(effect, like)`, `added`.
local function triggers(t, D)
  local shoot = VRFW.crc32(D.shoot_trigger)
  local info = t:rows(INFO)
  local at
  for _, i in ipairs(info) do
    if t:name(i) == INFO and t:uint(i, COL_TRIGGER) == shoot then
      at = i
      break
    end
  end
  if not at then return nil, "eff_chr_trigger: no row of the `" .. D.shoot_trigger .. "` trigger (not the v7.1.2 table?)" end
  local beg
  for i = at - 1, 0, -1 do
    if t:name(i) == INFO_BEG then
      beg = i
      break
    end
  end
  if not beg then return nil, "eff_chr_trigger: the ball list has no LIST_BEG" end
  local fin
  for i = at, t:len() - 1 do
    if t:name(i) == INFO_END then
      fin = i
      break
    end
  end
  if not fin then return nil, "eff_chr_trigger: the ball list has no LIST_END" end
  local by_effect, all, added = {}, {}, {}
  for i = beg + 1, fin - 1 do
    local eff, tr = t:uint(i, COL_EFFECT), t:uint(i, COL_TRIGGER)
    if eff and tr and eff ~= 0 and tr ~= 0 and by_effect[eff] == nil then by_effect[eff] = tr end
  end
  for _, i in ipairs(info) do
    if t:name(i) == INFO then
      local tr = t:uint(i, COL_TRIGGER)
      if tr then all[tr] = true end
    end
  end
  local R = { added = {} }
  function R.trigger_of(effect)
    return by_effect[VRFW.crc32(effect)]
  end
  function R.is_added(tr)
    for _, x in pairs(added) do
      if x == tr then return true end
    end
    return false
  end
  -- new trigger row for `effect`: a copy of `like`'s row with the effect and a new trigger
  function R.add(effect, like)
    if added[effect] then return added[effect] end
    local eff, like_crc = VRFW.crc32(effect), VRFW.crc32(like)
    local tpl
    for i = beg + 1, fin - 1 do
      if t:uint(i, COL_EFFECT) == like_crc and t:width(i) > COL_TRIGGER then
        tpl = i
        break
      end
    end
    if not tpl then return nil, "`like = \"" .. like .. "\"` is not an effect of the ball's trigger list" end
    local base = D.trigger_prefix .. effect
    local trig
    for n = 0, 99 do
      local c = VRFW.crc32(n == 0 and base or (base .. "#" .. n))
      if c ~= 0 and not all[c] then
        trig = c
        break
      end
    end
    if not trig then return nil, "no free trigger id" end
    if t:int(beg, 0) == nil then return nil, "the ball list's LIST_BEG has no count" end
    local row = U.copy_entry(t:entry(tpl))
    row.values[COL_EFFECT + 1] = eff
    row.values[COL_TRIGGER + 1] = trig
    t:splice(fin, fin, { row })
    fin = fin + 1
    t:bump(beg, 1)
    all[trig] = true
    by_effect[eff] = trig
    added[effect] = trig
    return trig
  end
  return R
end

-- ---- [[shot_aura]]

local function element_index(X, w)
  local s = U.trim(w):lower()
  for _, e in ipairs(X.K.elements) do
    if e[1]:lower() == s then return e[2] end
  end
  return nil
end

local function letter(X, i)
  return string.char(string.byte("a") + math.min(i, X.K.neutral))
end

-- `<mod>.<name>` of an active mod (the longest mod id wins), else nil.
local function split_own(X, key)
  local best
  for _, m in ipairs(X.mod_ids) do
    if #key > #m + 1 and key:sub(1, #m) == m and key:sub(#m + 1, #m + 1) == "." and (not best or #m > #best) then best = m end
  end
  return best
end

local function rule_id(X, mod, name)
  if split_own(X, name) then return name end
  return VRFW.ids.own(mod, name)
end

-- chara id -> its chara_param ids (lazy: read only when a rule names a character)
local function chara_map(X)
  if X.chara == nil then
    local key = VRFW.rows.key(X.K.chara_param_prefix)
    if not key then
      X.chara = { err = "chara_param not found in the game files" }
    else
      local t, err = VRFW.rows.open(key)
      if not t then
        X.chara = { err = "chara_param: " .. err }
      else
        local m = {}
        for _, i in ipairs(t:rows("CHARA_PARAM_INFO")) do
          local p, c = t:uint(i, 0), t:uint(i, 1)
          if p and c then
            m[c] = m[c] or {}
            m[c][#m[c] + 1] = p
          end
        end
        X.chara = { map = m }
      end
    end
  end
  return X.chara.map, X.chara.err
end

local function level_sel(v, what)
  if v == nil then return nil end
  if type(v) == "number" then return { v, v } end
  if v[1] <= v[2] then return { v[1], v[2] } end
  return nil, what .. " " .. pair(v) .. ": [min, max] with min <= max"
end

-- Resolved conditions of `w` (empty list / nil = any).
local function cond(X, w, detail)
  local c = { transforms = {}, transform_keys = {}, rarities = {}, elements = {}, cards = {}, techniques = {}, stat_min = {}, stat_max = {} }
  local D = X.D.shot_aura
  if w.form ~= nil then
    local bits, none = 0, false
    for _, x in ipairs(list(w.form)) do
      local o = U.trim(x):lower()
      local form = D.form_words[o]
      if form == "none" then
        none = true
      elseif form and X.K.forms[form] then
        bits = bit32.bor(bits, X.K.forms[form])
      else
        return nil, "form `" .. o .. "`: expected keshin, armour, miximax, aura or none"
      end
    end
    c.forms = { bits, none }
  end
  if w.transform ~= nil then
    for _, r in ipairs(list(w.transform)) do
      if type(r) == "string" and split_own(X, U.trim(r)) then
        c.transform_keys[#c.transform_keys + 1] = U.trim(r)
      else
        c.transforms[#c.transforms + 1] = id_of(r)
      end
    end
  end
  if w.rarity ~= nil then
    for _, x in ipairs(list(w.rarity)) do
      local vals
      if type(x) == "number" then
        vals = { x % 256 }
      else
        local r = X.rarity[x]
        if not r then return nil, "rarity `" .. x .. "`: not resolved" end
        if r.error then return nil, r.error end
        vals = r.values
      end
      for _, v in ipairs(vals) do
        if not U.contains(c.rarities, v) then c.rarities[#c.rarities + 1] = v end
      end
    end
  end
  if w.element ~= nil then
    for _, x in ipairs(list(w.element)) do
      local v
      if U.trim(x):lower() == "none" then
        v = X.K.no_element
      else
        v = element_index(X, x)
        if v == nil then return nil, "element `" .. x .. "`: expected wind, forest, fire, mountain, void or none" end
      end
      c.elements[#c.elements + 1] = v
    end
  end
  if w.character ~= nil then
    local map, err = chara_map(X)
    if not map then return nil, err end
    for _, x in ipairs(list(w.character)) do
      local cards = map[id_of(x)]
      if not cards then return nil, "character `" .. text_of(x) .. "` has no card in chara_param" end
      detail[#detail + 1] = "character " .. text_of(x) .. " = " .. #cards .. " card(s)"
      for _, p in ipairs(cards) do c.cards[#c.cards + 1] = p end
    end
  end
  if w.card ~= nil then
    for _, x in ipairs(list(w.card)) do c.cards[#c.cards + 1] = id_of(x) end
  end
  table.sort(c.cards)
  local dedup = {}
  for _, p in ipairs(c.cards) do
    if dedup[#dedup] ~= p then dedup[#dedup + 1] = p end
  end
  c.cards = dedup
  c.technique = w.technique
  if w.techniques ~= nil then
    for _, x in ipairs(list(w.techniques)) do c.techniques[#c.techniques + 1] = id_of(x) end
  end
  c.chain = w.chain
  c.long = w.long
  local err
  c.ball_level, err = level_sel(w.ball_level, "ball_level")
  if err then return nil, err end
  if c.ball_level and c.ball_level[2] > 4 then return nil, "ball_level: 0-4" end
  c.split_left, err = level_sel(w.split_left, "split_left")
  if err then return nil, err end
  for _, side in ipairs({ "stat_min", "stat_max" }) do
    for _, k in ipairs(U.keys(w[side] or {})) do
      local idx
      for i, s in ipairs(X.K.stats) do
        if s:lower() == k:lower() then
          idx = i - 1
          break
        end
      end
      if not idx then return nil, "stat `" .. k .. "`: expected one of " .. table.concat(X.K.stats, ", ") end
      c[side][#c[side] + 1] = { idx, math.min(w[side][k], 65535) }
    end
  end
  c.side = w.side
  return c
end

-- The aura a rule writes: one trigger per letter (all equal for a single effect).
local function aura(X, tr, mod, d, detail)
  if d.aura == nil then return false end
  local a = U.trim(d.aura)
  if not tr then return nil, "eff_chr_trigger not found in the game files" end
  local function single(label, t, effect, own)
    return { label = label, family = false, triggers = { t, t, t, t, t }, effects = { effect, effect, effect, effect, effect }, own_trigger = own }
  end
  -- 1. an effect the ball already triggers
  local t = tr.trigger_of(a)
  if t then return single(a, t, a, false) end
  -- 2. a family of five (ega0075 -> ega0075a … ega0075e)
  local fam, effs, some, all = {}, {}, false, true
  for i = 0, 4 do
    effs[i + 1] = a .. letter(X, i)
    fam[i + 1] = tr.trigger_of(effs[i + 1])
    if fam[i + 1] then some = true else all = false end
  end
  if all then return { label = a, family = true, triggers = fam, effects = effs, own_trigger = false } end
  if some then return nil, "aura `" .. a .. "`: only some of " .. a .. "a…" .. a .. "e have a ball trigger" end
  -- 3. any pooled effect: its own trigger row
  local g, err = X.effect_name(mod, a)
  if not g then return nil, err end
  t = tr.trigger_of(g)
  if t then return single(a, t, g, tr.is_added(t)) end
  local like = d.like or X.D.shot_aura.default_like
  local nt, e2 = tr.add(g, like)
  if not nt then return nil, e2 end
  detail[#detail + 1] = "new ball trigger " .. X.D.shot_aura.trigger_prefix .. g .. " = " .. VRFW.hex(nt) .. " (row of " .. like .. ")"
  return single(a, nt, g, true)
end

-- One line for the report / log.
local function summary(r)
  local s = {}
  if r.aura then
    if r.aura.family then
      s[#s + 1] = "aura " .. r.aura.label .. " (a-e by element)"
    else
      s[#s + 1] = "aura " .. r.aura.label .. " (trigger " .. VRFW.hex(r.aura.triggers[1]) .. ")"
    end
  end
  if r.trail_level then s[#s + 1] = "trail level " .. r.trail_level end
  if r.cutin_scale then s[#s + 1] = "in defence cut-ins x" .. VRFW.effect.f32(r.cutin_scale) end
  if r.fit then
    local how = r.fit.mode
    if r.fit.sustain then how = how .. " " .. r.fit.sustain[1] .. "-" .. r.fit.sustain[2] end
    s[#s + 1] = "fit to the flight (" .. how .. " of " .. r.fit.replay .. " frames, x" .. VRFW.effect.f32(r.fit.min_rate)
      .. "-x" .. VRFW.effect.f32(r.fit.max_rate) .. ")"
  end
  return table.concat(s, ", ")
end

local function equal(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not equal(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- `fit`: stretches the aura timeline to the real flight at run time. Defaults: `[shot_aura.fit]` of defaults\effect.toml. A `sustain` not given replays without its intro and outro. nil = no fit (`mode = "off"`); false + error on a bad key.
local function fit(X, d)
  local f = d.fit
  if f == nil then return nil end
  local D = (X.D.shot_aura and X.D.shot_aura.fit) or {}
  local mode = f.mode or D.mode or "sustain"
  if mode == "off" then return nil end
  if mode ~= "rate" and mode ~= "sustain" then return false, "fit.mode `" .. tostring(mode) .. "`: rate, sustain or off" end
  if d.aura == nil then return false, "`fit` needs `aura`" end
  local n = f.replay
  if type(n) ~= "number" or n < 1 or n > 100000 or n % 1 ~= 0 then
    return false, "fit.replay: the effect frames (60 fps) from the aura's first frame to its end-of-shot look, a whole number >= 1"
  end
  local lo, hi = f.min_rate or D.min_rate or 0.15, f.max_rate or D.max_rate or 2.0
  if not (lo > 0 and lo <= 1) then return false, "fit.min_rate " .. VRFW.effect.f32(lo) .. ": in (0, 1]" end
  if not (hi >= 1 and hi <= 10) then return false, "fit.max_rate " .. VRFW.effect.f32(hi) .. ": in [1, 10]" end
  local lead = f.lead or D.lead or 0
  if not (lead >= 0 and lead <= 5) then return false, "fit.lead " .. VRFW.effect.f32(lead) .. ": seconds in [0, 5]" end
  local r = { mode = mode, replay = n, min_rate = lo, max_rate = hi, lead = lead }
  if mode == "sustain" then
    local w = f.sustain
    if w == nil then
      local a = math.min(D.intro or 12, math.floor(n / 3))
      local b = n - math.max(D.outro_min or 6, math.floor(n * (D.outro or 0.25)))
      if b <= a then a, b = 0, n end
      w = { a, b }
    end
    if type(w) ~= "table" or #w ~= 2 or not (w[1] >= 0 and w[1] < w[2] and w[2] <= n) or w[1] % 1 ~= 0 or w[2] % 1 ~= 0 then
      return false, "fit.sustain: [a, b] effect frames with 0 <= a < b <= replay (" .. n .. ")"
    end
    r.sustain = { w[1], w[2] }
  elseif f.sustain ~= nil then
    return false, "fit.sustain needs mode = \"sustain\""
  end
  return r
end

local function rule(X, tr, f, id, d, detail)
  if d.aura == nil and d.trail_level == nil then return nil, "nothing to do: give `aura` and / or `trail_level`" end
  if d.trail_level ~= nil and (d.trail_level < 1 or d.trail_level > 4) then return nil, "trail_level: 1-4" end
  if d.like ~= nil and d.aura == nil then return nil, "`like` needs `aura`" end
  if d.cutin_scale ~= nil then
    if d.aura == nil then return nil, "`cutin_scale` needs `aura`" end
    local s = d.cutin_scale
    if not (s > 0 and s <= 10) then return nil, "cutin_scale " .. VRFW.effect.f32(s) .. ": a scale in (0, 10]" end
  end
  local color
  if d.color ~= nil then
    color = element_index(X, d.color)
    if color == nil then return nil, "color `" .. d.color .. "`: expected wind, forest, fire, mountain or void" end
  end
  local ft, fe = fit(X, d)
  if ft == false then return nil, fe end
  local when, err = cond(X, d.when or {}, detail)
  if not when then return nil, err end
  local au, e2 = aura(X, tr, f.mod, d, detail)
  if au == nil then return nil, e2 end
  if au == false then au = nil end
  if color ~= nil and not (au and au.family) then
    detail[#detail + 1] = "WARN color only picks the letter of a family (ega0075, ega0080, ega0085): ignored"
  end
  return { id = id, mod_id = f.mod, file = f.file, when = when, aura = au, color = color, trail_level = d.trail_level, cutin_scale = d.cutin_scale, fit = ft }
end

-- [[shot_aura]]: the rules (load order, later wins) and the new ball trigger rows. Returns the rules.
function M.shot_auras(X)
  local tr
  local key = VRFW.rows.key(X.K.trigger_prefix)
  if key then
    local t = VRFW.rows.open(key)
    if not t then
      VRFW.log.error(key .. ": not readable: no [[shot_aura]] with an aura")
    else
      t:raw()
      local err
      tr, err = triggers(t, X.D.shot_aura)
      if not tr then VRFW.log.error(key .. ": " .. err .. ": no [[shot_aura]] with an aura") end
    end
  else
    VRFW.log.warn("eff_chr_trigger not found in the game files: no [[shot_aura]] with an aura")
  end
  local rules, lines = {}, {}
  local function position(id)
    for i, r in ipairs(rules) do
      if r.id == id then return i end
    end
  end
  for _, f in ipairs(X.files) do
    for _, d in ipairs(f.value.shot_aura or {}) do
      local what = d.name
      local id, err = rule_id(X, f.mod, d.name)
      if not id then
        lines[#lines + 1] = { f, what, nil, err }
      elseif d.remove then
        local i = position(id)
        if i then
          local old = table.remove(rules, i)
          VRFW.log.warn(f.file .. ": [[shot_aura]] " .. id .. " (mod " .. old.mod_id .. ") removed")
          lines[#lines + 1] = { f, what, { "removed " .. id } }
        else
          lines[#lines + 1] = { f, what, nil, "remove: no loaded rule `" .. id .. "`" }
        end
      else
        local detail = {}
        local r, e2 = rule(X, tr, f, id, d, detail)
        if r then
          local i = position(r.id)
          if i then
            local old = table.remove(rules, i)
            VRFW.log.warn(f.file .. ": [[shot_aura]] " .. r.id .. " replaces the rule of mod " .. old.mod_id .. " (" .. old.file .. "): later wins")
            detail[#detail + 1] = "WARN replaces the rule of mod " .. old.mod_id
          end
          for _, o in ipairs(rules) do
            if o.mod_id ~= r.mod_id and equal(o.when, r.when) then
              VRFW.log.warn(f.file .. ": [[shot_aura]] " .. r.id .. " has the same conditions as " .. o.id .. " (mod " .. o.mod_id .. "): " .. r.mod_id .. " wins (later)")
            end
          end
          local line = { summary(r) }
          for _, x in ipairs(detail) do line[#line + 1] = x end
          lines[#lines + 1] = { f, what, line }
          rules[#rules + 1] = r
        else
          lines[#lines + 1] = { f, what, nil, e2 }
        end
      end
    end
  end
  for _, l in ipairs(lines) do
    X.item(l[1], "shot_aura", l[2], l[3], l[4])
  end
  return rules
end

-- ---- [[chr_trigger]]

-- A trigger as written: a number, `0x…`, or a name (crc32).
local function trigger_id(r)
  if type(r) == "number" then
    if r >= 0 and r < TWO32 then return r end
    return nil, "trigger " .. string.format("%.0f", r) .. ": not a u32"
  end
  local t = U.trim(r)
  if t == "" then return nil, "empty trigger" end
  local h = t:match("^0[xX](.*)$")
  if h then
    local n = parse_hex(h)
    if not n then return nil, "trigger `" .. r .. "`: bad hex" end
    return n
  end
  return VRFW.crc32(t)
end

-- Adds the trigger of `d` to `t`: report lines, or nil and why (table unchanged).
local function add_trigger(t, d, effect_name)
  local name = U.trim(d.name)
  if name == "" then return nil, "`name` is empty" end
  local id = VRFW.crc32(name)
  local like, err = trigger_id(d.like)
  if not like then return nil, err end
  local info = {}
  for _, i in ipairs(t:rows(INFO)) do
    if t:name(i) == INFO then info[#info + 1] = i end
  end
  for _, i in ipairs(info) do
    if t:uint(i, COL_TRIGGER) == id then
      return nil, "trigger `" .. name .. "` (" .. VRFW.hex(id) .. ") is already in eff_chr_trigger (a retail trigger or an earlier [[chr_trigger]])"
    end
  end
  -- replacement effects: template effect crc -> (new crc, names)
  local repl = {}
  for _, from in ipairs(U.keys(d.effects or {})) do
    local g, e2 = effect_name(d.effects[from])
    if not g then return nil, e2 end
    repl[#repl + 1] = { VRFW.crc32(U.trim(from)), VRFW.crc32(g), from, g }
  end
  local rows = {}
  for _, i in ipairs(info) do
    if t:uint(i, COL_TRIGGER) == like and t:width(i) > COL_TRIGGER then rows[#rows + 1] = i end
  end
  if #rows == 0 then return nil, "`like` " .. text_of(d.like) .. " (" .. VRFW.hex(like) .. ") has no row in eff_chr_trigger" end
  -- every replacement must hit a row (checked before any change)
  for _, r in ipairs(repl) do
    local hit = false
    for _, i in ipairs(rows) do
      if t:uint(i, COL_EFFECT) == r[1] then hit = true end
    end
    if not hit then return nil, "effects: `" .. r[3] .. "` is not an effect of the rows of " .. VRFW.hex(like) end
  end
  local detail = { "trigger `" .. name .. "` = " .. VRFW.hex(id) .. ", " .. #rows .. " row(s) of " .. VRFW.hex(like) }
  -- from the last row backwards, so an insert never moves a row still to be copied
  for k = #rows, 1, -1 do
    local i = rows[k]
    local row = U.copy_entry(t:entry(i))
    local eff = t:uint(i, COL_EFFECT) or 0
    local what = "effect " .. VRFW.hex(eff) .. " kept"
    for _, r in ipairs(repl) do
      if r[1] == eff then
        row.values[COL_EFFECT + 1] = r[2]
        what = r[3] .. " -> " .. r[4]
        break
      end
    end
    row.values[COL_TRIGGER + 1] = id
    local beg
    for j = i - 1, 0, -1 do
      if t:name(j) == INFO_BEG then
        beg = j
        break
      end
    end
    if not beg then return nil, "the row's list has no LIST_BEG" end
    if t:int(beg, 0) == nil then return nil, "the row's LIST_BEG has no count" end
    t:bump(beg, 1)
    t:splice(i + 1, i + 1, { row })
    detail[#detail + 1] = "row " .. (i + 1) .. ": " .. what
  end
  return detail
end

-- [[chr_trigger]]: new trigger rows of eff_chr_trigger, in load order.
function M.chr_triggers(X)
  local key = VRFW.rows.key(X.K.trigger_prefix)
  if not key then
    VRFW.log.error("eff_chr_trigger not found in the game files: no [[chr_trigger]]")
    return
  end
  local t = VRFW.rows.open(key)
  if not t then
    VRFW.log.error(key .. ": not readable: no [[chr_trigger]]")
    return
  end
  t:raw()
  for _, f in ipairs(X.files) do
    for _, d in ipairs(f.value.chr_trigger or {}) do
      local detail, err = add_trigger(t, d, function(s) return X.effect_name(f.mod, s) end)
      X.item(f, "chr_trigger", d.name, detail, err)
    end
  end
end

return M
