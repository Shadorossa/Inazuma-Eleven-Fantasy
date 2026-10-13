-- The run-time rules of the technique build (scripts/build/technique.lua): goal events, ball mini-effects, shot /
-- keeper mini-effects, dual elements, effect-variant event copies, hand-off scenes, keeper-gauge scenes and the row
-- icons. Each rule is a table the technique type's hooks read (crates/plugins/technique_engine: ball, minifx,
-- performers, handoff, keeper, icons); the ranges and vocabularies come from the engine (input.consts, VRFW.technique).
-- Installs its functions on the build context X.

local TWO32 = 4294967296

return function(X)
  local U, P, E, need = X.U, X.P, X.E, X.need
  local consts, vocab = X.consts, X.vocab
  local S, sc = X.S, X.sc
  local hex, int_str, lower = X.hex, X.int_str, X.lower
  local VARIANTS = consts.goal_variants
  local MINI = consts.mini
  local f32 = VRFW.technique.f32

  local function cat_word(c)
    local b = vocab.by_category[(c or 0) + 1]
    return b and b.word or "?"
  end
  local function ends_with(s, suf) return #s >= #suf and s:sub(-#suf) == suf end
  local function variant_key(key)
    for _, s in ipairs(VARIANTS) do
      if ends_with(key, s) then return key:sub(1, #key - #s) end
    end
    return nil
  end
  -- a game move (`wh…`, not a creation, not a variant itself) covers its `_or` / `_mm` ids
  local function covers(self, id, key)
    return not (self.created_by_id[id] or variant_key(key) or key:sub(1, 2) ~= "wh")
  end
  local function in_range(v, r) return v == v and v ~= math.huge and v ~= -math.huge and v >= r[1] and v <= r[2] end
  local function rtext(r) return r[3] .. "-" .. r[4] end
  local function num(v)
    if v == nil then return "None" end
    return tostring(v)
  end

  -- ------------------------------------------------------------------------------------------------- goal events
  local function goal_template()
    local k = X.keys.goal_replace
    if not k.key then return nil, k.err end
    local h, e = VRFW.rdbn.open(k.key)
    if not h then
      if e:sub(-#": not found") == ": not found" then return nil, k.key .. " not found" end
      return nil, e
    end
    local li, le = h:list("m_SkillGoalEventReplaceDataList")
    if li == nil then return nil, le end
    local count, order = {}, {}
    for r = 0, h:len(li) - 1 do
      local ev = h:u32(li, r, 2)
      if ev ~= nil and ev ~= 0 then
        if count[ev] == nil then
          count[ev] = 0
          order[#order + 1] = ev
        end
        count[ev] = count[ev] + 1
      end
    end
    local best = 0
    for _, ev in ipairs(order) do if count[ev] > best then best = count[ev] end end
    if best == 0 then return nil, k.key .. ": m_SkillGoalEventReplaceDataList has no goal event" end
    for _, ev in ipairs(order) do
      if count[ev] == best then return ev end
    end
  end

  -- `goal_event = "<event>" | "none"` of mod `m` on move `id`: nil or an error
  function X:goal_event(m, what, id, name)
    local w = what .. ".goal_event"
    if lower(U.trim(name)) == "none" then
      self:claim("goal", id, 0, m, "none", w)
      self.goals[id] = { m = m }
      return nil
    end
    if self.goal_template == nil then
      local t, e = goal_template()
      self.goal_template = t and { ok = t } or { err = e }
    end
    local tpl = self.goal_template.ok
    local tpl_err = self.goal_template.err and ("the template of a new goal event: " .. self.goal_template.err)
    local ev, e = self:event(m, what, name, tpl, tpl_err)
    if ev == nil then return "goal_event: " .. e end
    if ev:sub(1, 5) ~= "ev71_" then self:warn(m, w .. ": " .. ev .. " is not a goal event (ev71_…): the match plays it after the goal") end
    local cat = self:skill_num(id, sc.category)
    if cat ~= nil and cat ~= 1 then
      self:warn(m, string.format("%s: %s is a %s move: only the move of the shot that scores counts", w, self:label(id), cat_word(cat)))
    end
    self:claim("goal", id, 0, m, ev, w)
    self.goals[id] = { ev = ev, m = m }
    return nil
  end

  function X:goal_rules()
    local out = {}
    for _, id in ipairs(U.keys(self.goals)) do
      local g = self.goals[id]
      if g.ev ~= nil and not self.deleted[id] then
        local key = self:label(id)
        out[#out + 1] = { skill = id, key = key, event = g.ev, event_id = VRFW.crc32(g.ev), mod_id = g.m }
        if covers(self, id, key) then
          for _, suf in ipairs(VARIANTS) do
            local vkey = key .. suf
            local vid = VRFW.crc32(vkey)
            if self.goals[vid] == nil and not self.deleted[vid] then
              out[#out + 1] = { skill = vid, key = vkey, event = g.ev, event_id = VRFW.crc32(g.ev), mod_id = g.m, variant_of = key }
            end
          end
        end
      end
    end
    return X.sort_rules(out)
  end

  -- base moves first, then the variants they cover; by move id (stable)
  function X.sort_rules(list)
    local d = {}
    for i, r in ipairs(list) do d[i] = { r = r, i = i } end
    table.sort(d, function(a, b)
      local va, vb = a.r.variant_of ~= nil, b.r.variant_of ~= nil
      if va ~= vb then return vb end
      if a.r.skill ~= b.r.skill then return a.r.skill < b.r.skill end
      return a.i < b.i
    end)
    local out = {}
    for i, x in ipairs(d) do out[i] = x.r end
    return out
  end

  -- ------------------------------------------------------------------------------------------------- ball effects
  local function amount(a, key, kind, r, unit, presets)
    if a == nil then return nil end
    local v
    if type(a) == "number" then
      v = f32(a)
    else
      v = VRFW.technique.preset(kind, a)
      if v == nil then
        local words = {}
        for _, p in ipairs(presets) do words[#words + 1] = string.format('"%s" (%s%s)', p[1], tostring(p[2]), unit) end
        E(string.format('ball.%s = "%s": one of %s, or a number %s', key, a, table.concat(words, ", "), rtext(r)))
      end
    end
    if not (v >= r[1] and v <= r[2]) then
      E(string.format("ball.%s = %s: out of %s%s", key, type(a) == "number" and tostring(a) or ('"' .. a .. '"'), rtext(r), unit))
    end
    return v
  end

  function X.describe_ball(b)
    local d = b.distance and (tostring(b.distance) .. " m") or "game distance"
    local l = b.launch and (tostring(b.launch) .. "°") or "game angle"
    local t = b.max_travel and (", travel <= " .. tostring(b.max_travel) .. " m") or ""
    return string.format("%s: %s, %s, %s%s (%s)", b.key, d, l, b.direction, t, b.mod_id)
  end

  -- `[edit.ball]` of mod `m` on move `id`: nil or an error
  function X:ball(m, what, id, b)
    local r, e = X.try(function()
      local w = what .. ".ball"
      if b.off then
        if b.clear_distance ~= nil or b.launch ~= nil or b.direction ~= nil or b.max_travel ~= nil then
          E("ball: `off = true` drops the rule: give no other key with it")
        end
        self:claim("ball", id, 0, m, "off", w)
        self.balls[id] = { m = m }
        return true
      end
      local B = consts.ball
      local distance = amount(b.clear_distance, "clear_distance", "distance", B.distance, " m", B.distances)
      local launch = amount(b.launch, "launch", "launch", B.launch, "°", B.launches)
      local max_travel = amount(b.max_travel, "max_travel", "travel", B.travel, " m", B.travels)
      local direction = "keep"
      if b.direction ~= nil then
        direction = VRFW.technique.direction(b.direction)
        if direction == nil then E('ball.direction = "' .. b.direction .. '": "keep" or "forward"') end
      end
      if distance == nil and launch == nil and direction == "keep" and max_travel == nil then
        E('ball: give `clear_distance`, `launch`, `direction = "forward"` and / or `max_travel` (or `off = true`)')
      end
      local cat = self:skill_num(id, sc.category)
      local flags = self:skill_num(id, sc.flags)
      if cat ~= nil and cat ~= 4 then
        self:warn(m, string.format("%s: %s is a %s move: only keeper punch moves have a ball effect today (it never applies)", w, self:label(id), cat_word(cat)))
      elseif flags ~= nil and bit32.band(flags % TWO32, 2) == 0 then
        self:warn(m, string.format("%s: %s is a catch, not a punch (skillEffectBitFlag %s without bit 2): the keeper holds the ball, the rule never applies (effect_flags = 2 makes it a punch)", w, self:label(id), int_str(flags)))
      end
      local ef = { skill = id, key = self:label(id), distance = distance, launch = launch, direction = direction, max_travel = max_travel, mod_id = m }
      self:claim("ball", id, 0, m, string.format("%s/%s/%s/%s", num(distance), num(launch), direction, num(max_travel)), w)
      self.balls[id] = { e = ef, m = m }
      return true
    end)
    if r == nil then return e end
    return nil
  end

  local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
  end

  function X:ball_rules()
    local out = {}
    for _, id in ipairs(U.keys(self.balls)) do
      local b = self.balls[id]
      if b.e ~= nil and not self.deleted[id] then
        local key = self:label(id)
        local r = copy(b.e)
        r.key = key
        out[#out + 1] = r
        if covers(self, id, key) then
          for _, suf in ipairs(VARIANTS) do
            local vkey = key .. suf
            local vid = VRFW.crc32(vkey)
            if self.balls[vid] == nil and not self.deleted[vid] then
              local v = copy(b.e)
              v.skill, v.key, v.variant_of = vid, vkey, key
              out[#out + 1] = v
            end
          end
        end
      end
    end
    return X.sort_rules(out)
  end

  -- ------------------------------------------------------------------------------------------------- mini-effects
  local function mini(self, id)
    local d = self.minis[id]
    if not d then
      d = {}
      self.minis[id] = d
    end
    return d
  end

  -- the mini-effect keys of mod `m` on move `id`: the errors (each key on its own)
  function X:mini_rules(m, what, id, f)
    local errs = {}
    local cat = self:skill_num(id, sc.category)
    local flags = self:skill_num(id, sc.flags)
    local any = f.distance_falloff ~= nil or f.pe_sacrifice ~= nil or f.power_per_participant ~= nil or f.on_win_steal_tension ~= nil
      or f.ground_trail ~= nil or f.split_shot ~= nil or f.trajectory ~= nil
    local dflt = {}
    if any then
      local d = X.input.defaults.mini
      if d.err then
        errs[#errs + 1] = what .. ": the mini-effects' defaults: " .. d.err .. " (its mini-effects are left out)"
        return errs
      end
      dflt = d.ok
    end
    local function run(key, col, body)
      local w = what .. "." .. (key == "steal" and "on_win_steal_tension" or key == "effect" and "VRFW.MoveEffect" or key)
      local r, e = X.try(body, w)
      if r == nil then
        errs[#errs + 1] = e
        return
      end
      -- r = { v = rule or false (dropped), show = claim text }
      self:claim("ball", id, col, m, r.show, w)
      mini(self, id)[key] = { v = r.v, m = m }
    end
    if f.distance_falloff ~= nil then
      run("distance_falloff", 2, function(w)
        local d = f.distance_falloff
        local mode, slope, cap
        if type(d) == "string" then mode = d else mode, slope, cap = d.mode, d.slope, d.cap end
        local md = mode and U.trim(mode)
        local v
        if md == "game" and slope == nil and cap == nil then
          v = false
        elseif md == "game" then
          E(w .. ': "game" drops the rule: give no slope / cap with it')
        elseif md == "inverted" or md == nil then
          slope = slope or dflt.slope
          cap = cap or dflt.cap
          if not in_range(slope, MINI.slope) then
            E(string.format("%s.slope = %s: %s (multiple of the game's falloff per second)", w, tostring(slope), rtext(MINI.slope)))
          elseif not in_range(cap, MINI.cap) then
            E(string.format("%s.cap = %s: %s (most the shot gains, fraction of its power)", w, tostring(cap), rtext(MINI.cap)))
          end
          v = { slope = slope, cap = cap }
        else
          E(string.format('%s = "%s": "inverted" (the power grows with the distance) or "game" (drops the rule)', w, md))
        end
        if v then
          if cat ~= nil and cat ~= 1 then
            self:warn(m, string.format("%s: %s is a %s move: only shots fly as long shots (it never applies)", w, self:label(id), cat_word(cat)))
          elseif flags ~= nil and bit32.band(flags % TWO32, 4) == 0 then
            self:warn(m, string.format("%s: %s has no long-shot flag (skillEffectBitFlag %s without bit 4): the game gives it no falloff, so the rule rarely applies (effect_flags = 4 makes it a long shot)", w, self:label(id), int_str(flags)))
          end
        end
        return { v = v, show = v and string.format("Some(%s/%s)", tostring(v.slope), tostring(v.cap)) or "None" }
      end)
    end
    if f.on_win_lock_opponent_move ~= nil then
      local on = f.on_win_lock_opponent_move
      local w = what .. ".on_win_lock_opponent_move"
      if on and cat ~= nil and cat ~= 4 then
        self:warn(m, string.format("%s: %s is a %s move: today only a keeper's win (the keeper battle) sets the lock (it never applies)", w, self:label(id), cat_word(cat)))
      end
      self:claim("ball", id, 3, m, tostring(on), w)
      mini(self, id).lock = { v = on, m = m }
    end
    if f.pe_sacrifice ~= nil then
      run("pe_sacrifice", 4, function(w)
        local p = f.pe_sacrifice
        local v
        if p.off then
          if p.fraction ~= nil or p.power_mult ~= nil then E(w .. ": `off = true` drops the rule: give no other key with it") end
          v = false
        else
          local fr = p.fraction or dflt.fraction
          local mu = p.power_mult or dflt.power_mult
          if not in_range(fr, MINI.fraction) then
            E(string.format("%s.fraction = %s: %s (share of the user's current PE)", w, tostring(fr), rtext(MINI.fraction)))
          elseif not in_range(mu, MINI.mult) then
            E(string.format("%s.power_mult = %s: %s", w, tostring(mu), rtext(MINI.mult)))
          end
          v = { fraction = fr, power_mult = mu }
        end
        if v and (self:skill_num(id, sc.ev) or 0) == 0 then
          self:warn(m, string.format("%s: %s has no event: the sacrifice is paid when the move's event starts (it never applies)", w, self:label(id)))
        end
        return { v = v, show = v and string.format("Some(%s/%s)", tostring(v.fraction), tostring(v.power_mult)) or "None" }
      end)
    end
    if f.power_per_participant ~= nil then
      run("power_per_participant", 5, function(w)
        local p = f.power_per_participant
        local v
        if p.off then
          if p.element ~= nil or p.pct ~= nil or p.include_executor ~= nil then E(w .. ": `off = true` drops the rule: give no other key with it") end
          v = false
        else
          local pct = p.pct or dflt.participant_pct
          if p.element == nil then E(w .. ": `element` is missing (wind, forest, fire, mountain, void or any)") end
          local el = VRFW.technique.element_id(p.element)
          if el == nil then E(w .. '.element = "' .. p.element .. '": wind, forest, fire, mountain, void or any') end
          if not in_range(pct, MINI.participant_pct) then
            E(string.format("%s.pct = %s: %s (percent of the power per performer)", w, tostring(pct), rtext(MINI.participant_pct)))
          end
          v = { element = (el == consts.any_performer) and MINI.any_element or el, pct = pct, include_executor = p.include_executor or false }
        end
        if v then
          if (self:skill_num(id, sc.ev) or 0) == 0 then
            self:warn(m, string.format("%s: %s has no event: the performers are the cast of the move's event (it never applies)", w, self:label(id)))
          elseif not v.include_executor and self:skill_num(id, sc.ptype) == 0 then
            self:warn(m, string.format("%s: %s is a solo move (partnerType 0): no team mate performs it (it never applies)", w, self:label(id)))
          end
        end
        return { v = v, show = v and string.format("Some(%s/%s/%s)", tostring(v.element), tostring(v.pct), tostring(v.include_executor)) or "None" }
      end)
    end
    if f.on_win_steal_tension ~= nil then
      run("steal", 6, function(w)
        local s = f.on_win_steal_tension
        local v
        if s.off then
          if s.pct ~= nil then E(w .. ": `off = true` drops the rule: give no other key with it") end
          v = false
        else
          local pct = s.pct or dflt.steal_pct
          if not in_range(pct, MINI.steal_pct) then
            E(string.format("%s.pct = %s: %s (percent of the shot's tension cost)", w, tostring(pct), rtext(MINI.steal_pct)))
          end
          v = pct / 100
        end
        if v and cat ~= nil and cat ~= 4 then
          self:warn(m, string.format("%s: %s is a %s move: today only a keeper's win (the keeper battle) steals tension (it never applies)", w, self:label(id), cat_word(cat)))
        end
        return { v = v, show = v and ("Some(" .. tostring(v) .. ")") or "None" }
      end)
    end
    if f.ground_trail ~= nil then
      run("ground_trail", 9, function(w)
        local gt = f.ground_trail
        local v
        if gt.off then
          if gt.effect ~= nil or gt.interval ~= nil or gt.scale ~= nil or gt.scatter ~= nil or gt.orient ~= nil or gt.max_height ~= nil
            or gt.lift ~= nil or gt.life ~= nil or gt.object ~= nil then
            E(w .. ": `off = true` drops the rule: give no other key with it")
          end
          v = false
        else
          local effect = gt.effect and U.trim(gt.effect)
          if effect == nil or effect == "" then E(w .. ": give `effect` (a pooled effect's game name)") end
          local function n(x, d, k, r)
            if x == nil then x = d end
            if in_range(x, r) then return x end
            E(string.format("%s.%s = %s: %s", w, k, tostring(x), rtext(r)))
          end
          v = { effect = effect, effect_crc = VRFW.crc32(effect) }
          v.interval = n(gt.interval, dflt.trail_interval, "interval", MINI.trail_interval)
          v.scale = n(gt.scale, 1.0, "scale", MINI.trail_scale)
          v.scatter = n(gt.scatter, 0.0, "scatter", MINI.trail_scatter)
          if gt.orient == nil then v.orient = true else v.orient = gt.orient end
          v.max_height = n(gt.max_height, MINI.trail_max_height, "max_height", MINI.trail_height)
          v.lift = n(gt.lift, 0.0, "lift", MINI.trail_lift)
          if gt.life ~= nil then v.life = n(gt.life, 0.0, "life", MINI.trail_life) end
          if gt.object ~= nil then
            local o = U.trim(gt.object):gsub("^/+", ""):gsub("\\", "/")
            if lower(o):sub(-7) == ".objbin" then
              if o:sub(1, 7) == "common/" then o = o:sub(8) end
              v.object = o
            else
              E(string.format('%s.object = "%s": the effect\'s objbin path (`effect/…/<x>.objbin`)', w, o))
            end
          end
        end
        if v and cat ~= nil and cat ~= 1 then
          self:warn(m, string.format("%s: %s is a %s move: only shots leave a trail (it never applies)", w, self:label(id), cat_word(cat)))
        end
        return { v = v, show = v and ("Some(" .. v.effect .. "/" .. tostring(v.interval) .. "/" .. tostring(v.scale) .. ")") or "None" }
      end)
    end
    if f.split_shot ~= nil then
      run("split_shot", 8, function(w)
        local sp = f.split_shot
        local v
        if sp.off then
          if sp.parts ~= nil or sp.lose ~= nil or not U.is_empty(sp.lose_by_move) or sp.hide_ball ~= nil then
            E(w .. ": `off = true` drops the rule: give no other key with it")
          end
          v = false
        else
          local function n(x, d, k, r)
            if x == nil then x = d end
            if in_range(x, r) then return math.floor(x) end
            E(string.format("%s.%s = %s: %s", w, k, tostring(x), rtext(r)))
          end
          local parts = n(sp.parts, dflt.split_parts, "parts", MINI.split_parts)
          local lose = sp.lose or {}
          local basic = n(lose.basic, dflt.split_lose_basic, "lose.basic", MINI.split_lose)
          local block_move = n(lose["move"], dflt.split_lose_move, "lose.move", MINI.split_lose)
          local by_move = {}
          for _, k in ipairs(U.keys(sp.lose_by_move or {})) do
            local c = n(sp.lose_by_move[k], 1, "lose_by_move." .. k, MINI.split_lose)
            by_move[#by_move + 1] = { VRFW.crc32(U.trim(k)), c }
          end
          v = { parts = parts, basic = basic, block_move = block_move, by_move = by_move, hide_ball = sp.hide_ball or false }
        end
        if v and cat ~= nil and cat ~= 1 then
          self:warn(m, string.format("%s: %s is a %s move: only shots are blocked in flight (it never applies)", w, self:label(id), cat_word(cat)))
        end
        return { v = v, show = v and string.format("Some(%d/%d/%d/%d/%s)", v.parts, v.basic, v.block_move, #v.by_move, tostring(v.hide_ball)) or "None" }
      end)
    end
    if f.trajectory ~= nil then
      -- the shot's flight as heights over distances (crates/plugins/technique_engine/src/minifx_flight.rs, the run
      -- time's data shape: move_fx[].dive = { height, unblockable, flight = { points, goal_points, smooth, start_height,
      -- start_kick, behind, side, speed, time, alias } }); the old archetypes are deprecated aliases expanded into points
      run("trajectory", 7, function(w)
        local t = f.trajectory
        local FL = MINI.flight
        local R = FL.ball_radius
        local function pt(at, h, r, a) return { at = at, height = h, round = r or -1, after = a or -1 } end
        local function top(fl)
          local m = fl.start_height or 0
          for _, l in ipairs({ fl.points or {}, fl.goal_points or {} }) do
            for _, p in ipairs(l) do if p.height > m then m = p.height end end
          end
          return m
        end
        local function rule(fl, unb) return { height = top(fl), unblockable = unb, flight = fl } end
        local v
        local points_form = type(t) == "table" and (t.points ~= nil or t.goal_points ~= nil)
        if type(t) == "table" and not points_form and (t.curve ~= nil or t.start ~= nil or t.speed ~= nil or t.time ~= nil) then
          E(w .. ": curve / start / speed / time shape a flight of points: give its points (or goal_points)")
        end
        if points_form then
          if t.mode ~= nil or t.height ~= nil or t.angle ~= nil or t.end_height ~= nil or t.bend ~= nil or t.touch ~= nil or t.skim ~= nil then
            E(w .. ": a flight of points takes no mode / height / angle / end_height / bend / touch / skim (those are the deprecated aliases)")
          end
          local function read(list, key)
            local out = {}
            if list == nil then return nil end
            if #list > FL.max_points then E(string.format("%s.%s: %d points (at most %d)", w, key, #list, FL.max_points)) end
            for i, p in ipairs(list) do
              local at = string.format("%s.%s[%d]", w, key, i - 1)
              if type(p) ~= "table" or #p < 2 or #p > 4 then
                E(at .. ": [distance, height], [distance, height, round] or [distance, height, before, after] (metres)")
              end
              if not in_range(p[1], FL.at) then E(string.format("%s: distance %s: %s (metres on the ground)", at, tostring(p[1]), rtext(FL.at))) end
              if not in_range(p[2], FL.height) then
                E(string.format("%s: height %s: %s (metres, the ball centre over the pitch; on the pitch = %s)", at, tostring(p[2]), rtext(FL.height), tostring(R)))
              end
              for k, what in pairs({ [3] = "round", [4] = "after" }) do
                if p[k] ~= nil and not in_range(p[k], FL.round) then
                  E(string.format("%s: %s %s: %s (metres on the ground; 999 = as much as fits)", at, what, tostring(p[k]), rtext(FL.round)))
                end
              end
              for _, q in ipairs(out) do
                if math.abs(q.at - p[1]) < 0.01 then E(string.format("%s: two points at %s m", at, tostring(p[1]))) end
              end
              out[#out + 1] = pt(p[1], p[2], p[3], p[4])
            end
            table.sort(out, function(a, b) return a.at < b.at end)
            if #out == 0 then return nil end
            return out
          end
          local fl = { points = read(t.points, "points"), goal_points = read(t.goal_points, "goal_points"), alias = "points" }
          if fl.points == nil and fl.goal_points == nil then E(w .. ": no point (give points and / or goal_points)") end
          local c = t.curve and U.trim(t.curve)
          if c == nil or c == "linear" then
            fl.smooth = false
          elseif c == "smooth" then
            fl.smooth = true
          else
            E(string.format('%s.curve = "%s": "linear" (straight between the points) or "smooth" (every corner rounded)', w, c))
          end
          local st = t.start
          if st ~= nil then
            for k in pairs(st) do
              if k ~= "behind" and k ~= "side" and k ~= "height" and k ~= "fall" then E(string.format("%s.start.%s: unknown (behind, side, height, fall)", w, tostring(k))) end
            end
            if st.behind ~= nil then
              if not in_range(st.behind, FL.behind) then E(string.format("%s.start.behind = %s: %s (metres back from the kick point along the shot)", w, tostring(st.behind), rtext(FL.behind))) end
              fl.behind = st.behind
            end
            if st.side ~= nil then
              if not in_range(st.side, FL.side) then E(string.format("%s.start.side = %s: %s (metres to the right of the kick point)", w, tostring(st.side), rtext(FL.side))) end
              fl.side = st.side
            end
            if type(st.height) == "string" then
              if U.trim(st.height) ~= "kick" then E(string.format('%s.start.height = "%s": metres or "kick" (the ball stays where the cut-in left it)', w, st.height)) end
              fl.start_kick = true
            elseif st.height ~= nil then
              if not in_range(st.height, FL.height) then E(string.format('%s.start.height = %s: %s (metres) or "kick"', w, tostring(st.height), rtext(FL.height))) end
              fl.start_height = st.height
            end
            if st.fall ~= nil then
              if type(st.fall) ~= "boolean" then E(string.format("%s.start.fall = %s: true or false (the shooter comes down from the start after the cut-in)", w, tostring(st.fall))) end
              fl.fall = st.fall
            end
          end
          -- the declaring mod's default start height (its own content/defaults/technique.toml [trajectory]): every
          -- flight of points of that mod without its own start.height
          if fl.start_height == nil and not fl.start_kick then
            local ms = (X.input.defaults.trajectory_start or {})[m]
            if ms ~= nil then
              if ms.err then E(w .. ": the mod's [trajectory] start_height: " .. tostring(ms.err)) end
              if not in_range(ms.ok, FL.height) then E(string.format("%s: the mod's [trajectory] start_height = %s: %s (metres)", w, tostring(ms.ok), rtext(FL.height))) end
              fl.start_height = ms.ok
            end
          end
          if t.speed ~= nil and t.time ~= nil then E(w .. ": speed and time both set: give one") end
          if t.speed ~= nil then
            if not in_range(t.speed, FL.speed) then E(string.format("%s.speed = %s: %s (m/s)", w, tostring(t.speed), rtext(FL.speed))) end
            fl.speed = t.speed
          end
          if t.time ~= nil then
            if not in_range(t.time, FL.time) then E(string.format("%s.time = %s: %s (seconds, the whole flight)", w, tostring(t.time), rtext(FL.time))) end
            fl.time = t.time
          end
          local unb = false
          if t.unblockable ~= nil then unb = t.unblockable end
          v = rule(fl, unb)
          -- the shooter fall (technique.md 4e): start.fall, else a start height that is a number; never "kick"
          local falls = fl.fall
          if falls == nil then falls = fl.start_height ~= nil end
          local g = dflt.shooter_fall_gravity
          if falls and not fl.start_kick and type(g) == "number" and in_range(g, FL.fall_gravity) then
            v.shooter_fall = { min_height = math.max(0, dflt.shooter_fall_min_height or 0), gravity = g }
          end
        else
          local mode, height, unblockable, touch, skim, angle, end_height, bend
          if type(t) == "string" then
            mode = t
          else
            mode, height, unblockable, touch, skim = t.mode, t.height, t.unblockable, t.touch, t.skim
            angle, end_height, bend = t.angle, t.end_height, t.bend
          end
          local x = mode and U.trim(mode)
          local function dflt_u(d) if unblockable == nil then return d end return unblockable end
          if x ~= nil and x ~= "drop_skim" and (touch ~= nil or skim ~= nil) then
            E(w .. ': touch / skim belong to mode = "drop_skim"')
          elseif x ~= nil and x ~= "dive" and x ~= "level" and end_height ~= nil then
            E(w .. ': end_height belongs to mode = "dive" / "level"')
          elseif x ~= nil and x ~= "dive" and (angle ~= nil or bend ~= nil) then
            E(w .. ': angle / bend belong to mode = "dive"')
          elseif x == nil and (angle ~= nil or end_height ~= nil or bend ~= nil) then
            E(w .. ': angle / end_height / bend belong to mode = "dive"')
          elseif x == "dive" and angle == nil and (end_height ~= nil or bend ~= nil) then
            E(w .. ": end_height / bend shape the angled dive: give its angle too")
          elseif x == "dive" and angle ~= nil then
            local h = height or dflt.dive_height
            local b = bend or MINI.dive_bend_default
            if not in_range(h, MINI.dive_height) then
              E(string.format("%s.height = %s: %s (metres over the kick point the dive starts at)", w, tostring(h), rtext(MINI.dive_height)))
            elseif not in_range(angle, MINI.dive_angle) then
              E(string.format("%s.angle = %s: %s (degrees under the horizontal the ball comes into the goal at)", w, tostring(angle), rtext(MINI.dive_angle)))
            elseif end_height ~= nil and not in_range(end_height, MINI.dive_end_height) then
              E(string.format("%s.end_height = %s: %s (metres: the ball's height at the goal)", w, tostring(end_height), rtext(MINI.dive_end_height)))
            elseif not in_range(b, MINI.dive_bend) then
              E(string.format("%s.bend = %s: %s (share of the dive line the bend into it takes)", w, tostring(b), rtext(MINI.dive_bend)))
            end
            local s0 = h + R
            local en = math.min(end_height or dflt.level_end_height, s0)
            local run = (s0 - en) / math.tan(math.rad(angle))
            -- the old bend: from the level start (the whole level piece) into the line, `bend` of it down the line
            v = rule({ goal_points = { pt(0, en), pt(run, s0, FL.round_full, b * run) }, alias = "angled_dive" }, dflt_u(true))
          elseif x == "drop_skim" then
            local h = height or dflt.dive_height
            local tc = touch or dflt.drop_touch
            local sk = skim or dflt.ground_height
            if not in_range(h, MINI.dive_height) then
              E(string.format("%s.height = %s: %s (metres over the kick point the drop starts at)", w, tostring(h), rtext(MINI.dive_height)))
            elseif not in_range(tc, MINI.drop_touch) then
              E(string.format("%s.touch = %s: %s (where the ball lands, share of the way to the goal)", w, tostring(tc), rtext(MINI.drop_touch)))
            elseif not in_range(sk, MINI.ground_height) then
              E(string.format("%s.skim = %s: %s (metres: the height the ball skims at after the touch)", w, tostring(sk), rtext(MINI.ground_height)))
            end
            local g = FL.ref_ground
            local at = g * tc
            local lift = math.min(g * 0.12, 3.0, (g - at) * 0.5)
            v = rule({ points = { pt(0, h + R), pt(at, 0.12), pt(at + lift * 0.5, sk, lift * 0.5) }, alias = "drop_skim" }, dflt_u(false))
          elseif x == "game" and height == nil and unblockable == nil then
            v = false
          elseif x == "game" then
            E(w .. ': "game" drops the rule: give no height / unblockable with it')
          elseif x == "dive" or x == nil then
            local h = height or dflt.dive_height
            if not in_range(h, MINI.dive_height) then
              E(string.format("%s.height = %s: %s (metres over the kick point the dive starts at)", w, tostring(h), rtext(MINI.dive_height)))
            end
            local en = math.max(MINI.dive_end_height[1], math.min(MINI.dive_end_height[2], dflt.level_end_height))
            v = rule({ points = { pt(0, h + R) }, goal_points = { pt(0, en) }, alias = "dive" }, dflt_u(true))
          elseif x == "ground" then
            local h = height or dflt.ground_height
            if not in_range(h, MINI.ground_height) then
              E(string.format("%s.height = %s: %s (metres: the height the ball skims at)", w, tostring(h), rtext(MINI.ground_height)))
            end
            v = rule({ points = { pt(0, h) }, alias = "ground" }, dflt_u(false))
          elseif x == "level" then
            local h = height or dflt.level_height
            local en = end_height or dflt.level_end_height
            if not in_range(h, MINI.level_height) then
              E(string.format("%s.height = %s: %s (metres, ball centre: the height of the level run)", w, tostring(h), rtext(MINI.level_height)))
            elseif not in_range(en, MINI.dive_end_height) then
              E(string.format("%s.end_height = %s: %s (metres: the ball's height at the goal)", w, tostring(en), rtext(MINI.dive_end_height)))
            end
            local rise = math.min(FL.ref_ground * 0.3, 10.0) * 0.5
            local ease = math.min(FL.ref_ground * 0.25, 10.0) * 0.5
            v = rule({ points = { pt(rise, h, rise) }, goal_points = { pt(0, math.min(h, en)), pt(ease, h, ease) }, start_kick = true, alias = "level" }, dflt_u(false))
          else
            E(string.format('%s = "%s": give the flight as points (trajectory = { points = [[0.0, 0.11]], goal_points = [[0.0, 2.0]] }), or a deprecated alias: "dive", "ground", "level", "drop_skim"; "game" drops the rule', w, x))
          end
        end
        if v and cat ~= nil and cat ~= 1 then
          self:warn(m, string.format("%s: %s is a %s move: only shots fly to the goal (it never applies)", w, self:label(id), cat_word(cat)))
        end
        local show = "None"
        if v then
          local parts = {}
          for _, key in ipairs({ "points", "goal_points" }) do
            local l = {}
            for _, p in ipairs(v.flight[key] or {}) do l[#l + 1] = string.format("%g:%g:%g:%g", p.at, p.height, p.round, (p.after ~= nil and p.after >= 0) and p.after or p.round) end
            parts[#parts + 1] = table.concat(l, ",")
          end
          local fl = v.flight
          -- the alias is not compared: an alias and the points it expands into are the same flight (no conflict)
          show = string.format("Some(%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s)", parts[1], parts[2], tostring(fl.smooth == true), tostring(fl.start_height), tostring(fl.start_kick == true),
            string.format("%g", fl.behind or 0), string.format("%g", fl.side or 0), tostring(fl.speed), tostring(fl.time), tostring(v.unblockable), tostring(fl.fall))
        end
        return { v = v, show = show }
      end)
    end
    -- `[edit.VRFW.MoveEffect]` (docs/framework/technique.md §4g): the generic per-move duel effects, one table per
    -- move (a later mod's table replaces the whole table; `Off = true` drops it)
    local me = f.vrfw and f.vrfw.MoveEffect
    if me ~= nil then
      run("effect", 10, function(w)
        local function bad(key, v, r, why)
          E(string.format("%s.%s = %s: %s-%s (%s)", w, key, tostring(v), tostring(r[1]), tostring(r[2]), why))
        end
        local function rng(v, r) return type(v) == "number" and in_range(v, { r[1], r[2] }) end
        local function scope(s, key)
          if s == nil then return "team_match" end
          s = lower(U.trim(s))
          if s ~= "team_match" and s ~= "player_match" then
            E(string.format('%s.%s.Scope = "%s": "team_match" (per team, per match) or "player_match"', w, key, s))
          end
          return s
        end
        local function side(s, key, dflt)
          if s == nil then return dflt end
          s = lower(U.trim(s))
          if s ~= "own" and s ~= "rival" then E(string.format('%s.%s.Team = "%s": "own" or "rival"', w, key, s)) end
          return s
        end
        if me.Off then
          for k, _ in pairs(me) do
            if k ~= "Off" then E(w .. ": `Off = true` drops the table: give no other key with it") end
          end
          return { v = false, show = "None" }
        end
        local el = (self:skill_num(id, sc.element) or 0) % 256
        local v = { category = (cat or 0) % 256, element = el }
        local any = false
        if me.StatPower ~= nil then
          local s = me.StatPower
          local STATS = { kick = 0, control = 1, technique = 2, pressure = 3, physical = 4, intelligence = 5, agility = 6 }
          if s.Stats == nil or #s.Stats == 0 then E(w .. ".StatPower.Stats: give the stat words (pressure, physical, …)") end
          local idx = {}
          for _, word in ipairs(s.Stats or {}) do
            local i = STATS[lower(U.trim(word))]
            if i == nil then
              E(string.format('%s.StatPower.Stats: "%s": kick, control, technique, pressure, physical, intelligence or agility', w, word))
            end
            idx[#idx + 1] = i
          end
          if not rng(s.Weight, { 0, 10 }) then bad("StatPower.Weight", s.Weight, { 0, 10 }, "the first use's weight: 2.25 = 225 %") end
          local decay = s.DecayPerUse or 0
          if not rng(decay, { 0, 10 }) then bad("StatPower.DecayPerUse", decay, { 0, 10 }, "the weight lost per use") end
          local comb = lower(U.trim(s.Combine or "mean"))
          if comb ~= "mean" and comb ~= "sum" then E(string.format('%s.StatPower.Combine = "%s": "mean" or "sum"', w, comb)) end
          v.stat_power = { stats = idx, weight = s.Weight, decay_per_use = decay, scope = scope(s.Scope, "StatPower"), combine = comb }
          any = true
        end
        if me.FirstUse ~= nil then
          local s = me.FirstUse
          if not rng(s.PowerMult, { 1, 100 }) then bad("FirstUse.PowerMult", s.PowerMult, { 1, 100 }, "31 = +3000 %") end
          local uses = s.Uses or 1
          if not rng(uses, { 1, 99 }) then bad("FirstUse.Uses", uses, { 1, 99 }, "how many first uses") end
          v.first_use = { power_mult = s.PowerMult, scope = scope(s.Scope, "FirstUse"), uses = uses }
          any = true
        end
        if me.LongShotFalloffMult ~= nil then
          local x = me.LongShotFalloffMult
          if not rng(x, { 0, 1 }) then bad("LongShotFalloffMult", x, { 0, 1 }, "share of the game's long-shot falloff: 0.9 = 10 % less") end
          if cat ~= nil and cat ~= 1 then
            self:warn(m, string.format("%s.LongShotFalloffMult: %s is a %s move: only shots fly as long shots (it never applies)", w, self:label(id), cat_word(cat)))
          elseif flags ~= nil and bit32.band(flags % TWO32, 4) == 0 then
            self:warn(m, string.format("%s.LongShotFalloffMult: %s has no long-shot flag (skillEffectBitFlag without bit 4): it rarely applies", w, self:label(id)))
          end
          v.falloff_mult = x
          any = true
        end
        if me.BallSpeedMult ~= nil then
          local x = me.BallSpeedMult
          if not rng(x, { 0.5, 3 }) then bad("BallSpeedMult", x, { 0.5, 3 }, "the ball's flight speed multiplier") end
          if cat ~= nil and cat ~= 1 then
            self:warn(m, string.format("%s.BallSpeedMult: %s is a %s move: only shots fly to the goal (it never applies)", w, self:label(id), cat_word(cat)))
          end
          v.ball_speed_mult = x
          any = true
        end
        if me.OnBlock ~= nil then
          local s = me.OnBlock
          if not rng(s.Tension, { -1, 1 }) then bad("OnBlock.Tension", s.Tension, { -1, 1 }, "fraction of the tension gauge per block: -0.02 = -2 %") end
          if cat ~= nil and cat ~= 1 then
            self:warn(m, string.format("%s.OnBlock: %s is a %s move: only a shot in flight is blocked (it never applies)", w, self:label(id), cat_word(cat)))
          end
          v.on_block = { team = side(s.Team, "OnBlock", "rival"), tension = s.Tension }
          any = true
        end
        if me.OnUse ~= nil then
          local s = me.OnUse
          if s.CooldownRefund == nil then E(w .. ".OnUse: give CooldownRefund (share of the full recast, 0-1)") end
          if not rng(s.CooldownRefund, { 0, 1 }) then bad("OnUse.CooldownRefund", s.CooldownRefund, { 0, 1 }, "share of each slot's full recast") end
          local flt = s.Filter or {}
          local ew = lower(U.trim(flt.Element or "same_as_move"))
          local fe
          if ew == "same_as_move" then
            fe = el
            if el < 1 or el > 5 then E(string.format("%s.OnUse.Filter.Element: %s has no element (same_as_move)", w, self:label(id))) end
          elseif ew == "any" then
            fe = 0
          else
            fe = VRFW.technique.element_id(ew)
            if fe == nil or fe == consts.any_performer then
              E(string.format('%s.OnUse.Filter.Element = "%s": same_as_move, any, wind, forest, fire, mountain or void', w, ew))
            end
          end
          v.cooldown_refund = { share = s.CooldownRefund, team = side(flt.Team, "OnUse.Filter", "own"), element = fe, include_self = flt.IncludeSelf == true }
          any = true
        end
        if me.OnSuccess ~= nil then
          local p = me.OnSuccess.PushAffected
          if p == nil then E(w .. ".OnSuccess: give PushAffected = { RadiusM = 18 }") end
          if not rng(p.RadiusM, { 3, 60 }) then bad("OnSuccess.PushAffected.RadiusM", p.RadiusM, { 3, 60 }, "metres from the user") end
          local mg = p.MarginM or 1
          if not rng(mg, { 0, 10 }) then bad("OnSuccess.PushAffected.MarginM", mg, { 0, 10 }, "metres inside the lines") end
          if cat ~= nil and cat ~= 2 and cat ~= 3 then
            self:warn(m, string.format("%s.OnSuccess: %s is a %s move: only a focus duel it wins (dribble / block) beats a rival (it never applies)", w, self:label(id), cat_word(cat)))
          end
          v.push = { radius_m = p.RadiusM, margin_m = mg }
          any = true
        end
        if not any then E(w .. ": no effect given (StatPower, FirstUse, LongShotFalloffMult, BallSpeedMult, OnBlock, OnUse, OnSuccess or Off)") end
        if (v.stat_power or v.first_use or v.cooldown_refund or v.push) and (self:skill_num(id, sc.ev) or 0) == 0 and cat ~= 4 then
          self:warn(m, string.format("%s: %s has no event: a use is counted when its event starts (it never applies)", w, self:label(id)))
        end
        local function j(x)
          if type(x) ~= "table" then return tostring(x) end
          local ks = {}
          for k, _ in pairs(x) do ks[#ks + 1] = tostring(k) end
          table.sort(ks)
          local o = {}
          for _, k in ipairs(ks) do o[#o + 1] = k .. "=" .. j(x[k] ~= nil and x[k] or x[tonumber(k)]) end
          return "{" .. table.concat(o, ",") .. "}"
        end
        return { v = v, show = "Some(" .. j(v) .. ")" }
      end)
    end
    return errs
  end

  -- the final mini-effect rules, key by key: a game move's keys also cover its `_or` / `_mm` ids for the keys those
  -- do not declare themselves
  local KEYS = { "distance_falloff", "lock", "pe_sacrifice", "power_per_participant", "steal", "trajectory", "split_shot", "ground_trail", "effect" }
  local FIELD = { distance_falloff = "distance", pe_sacrifice = "pe", power_per_participant = "participants", steal = "steal_tension",
    trajectory = "dive", split_shot = "split", ground_trail = "trail", effect = "effect" }
  local function one(d, base)
    local r = { skill = 0, key = "", lock = false, event = 0, mod_id = "" }
    local mod
    for _, k in ipairs(KEYS) do
      local x = d[k] or (base and base[k])
      if x ~= nil then
        if mod == nil then mod = x.m end
        if k == "lock" then
          r.lock = x.v == true
        elseif x.v then
          r[FIELD[k]] = x.v
        end
      end
    end
    r.mod_id = mod or ""
    return r
  end
  local function empty(r)
    return r.distance == nil and not r.lock and r.pe == nil and r.participants == nil and r.steal_tension == nil and r.dive == nil
      and r.split == nil and r.trail == nil and r.effect == nil
  end

  function X:move_fx_rules()
    local out = {}
    local function ev(id) return (self:skill_num(id, sc.ev) or 0) % TWO32 end
    local function fev(id) return (self:skill_num(id, sc.fail) or 0) % TWO32 end
    for _, id in ipairs(U.keys(self.minis)) do
      local d = self.minis[id]
      if not self.deleted[id] and self:skill_row(id) ~= nil then
        local key = self:label(id)
        local base_key = variant_key(key)
        if not (base_key and self.minis[VRFW.crc32(base_key)]) then
          local r = one(d, nil)
          r.skill, r.key, r.event, r.fail_event = id, key, ev(id), fev(id)
          if not empty(r) then out[#out + 1] = r end
          if not (self.created_by_id[id] or base_key or key:sub(1, 2) ~= "wh") then
            for _, suf in ipairs(VARIANTS) do
              local vkey = key .. suf
              local vid = VRFW.crc32(vkey)
              if not self.deleted[vid] and self:skill_row(vid) ~= nil then
                local own = self.minis[vid]
                local v = one(own or {}, d)
                v.skill, v.key, v.event, v.fail_event = vid, vkey, ev(vid), fev(vid)
                if own == nil then v.variant_of = key end
                if not empty(v) then out[#out + 1] = v end
              end
            end
          end
        end
      end
    end
    local dd = {}
    for i, r in ipairs(out) do dd[i] = { r = r, i = i } end
    table.sort(dd, function(a, b)
      if a.r.skill ~= b.r.skill then return a.r.skill < b.r.skill end
      return a.i < b.i
    end)
    local res, last = {}, nil
    for _, x in ipairs(dd) do
      if x.r.skill ~= last then res[#res + 1] = x.r end
      last = x.r.skill
    end
    return res
  end

  -- ------------------------------------------------------------------------------------------------- dual elements
  function X:dual_element_rule(m, what, id, e)
    local w = what .. ".vrfw.DualElement"
    if e.Off then
      if e.From ~= nil or e.Elements ~= nil or e.MultiStabBonus ~= nil then
        return "vrfw.DualElement: `Off = true` drops the rule: give no other key with it"
      end
      self:claim("ball", id, 1, m, "off", w)
      self.performers[id] = { m = m }
      return nil
    end
    local declared = {}
    if e.From ~= nil and e.Elements ~= nil then
      return 'vrfw.DualElement: give `From = "performers"` or `Elements = [...]`, not both'
    elseif e.From ~= nil then
      local x = U.trim(e.From)
      if x ~= "performers" then return 'vrfw.DualElement.From = "' .. x .. '": "performers" (the players who perform the move)' end
    elseif e.Elements ~= nil then
      for _, word in ipairs(e.Elements) do
        local x = VRFW.technique.element_id(word)
        if x ~= nil and x >= 1 and x <= 5 and not U.contains(declared, x) then
          declared[#declared + 1] = x
        elseif x ~= nil and x >= 1 and x <= 5 then
          return 'vrfw.DualElement.Elements: "' .. word .. '" twice'
        else
          return 'vrfw.DualElement.Elements: "' .. word .. '": wind, forest, fire, mountain or void'
        end
      end
      if #declared < 2 or #declared > 4 then
        return string.format("vrfw.DualElement.Elements: %d element(s): give 2-4 distinct elements", #declared)
      end
    else
      return 'vrfw.DualElement: give `From = "performers"` or `Elements = [...]` (or `Off = true`)'
    end
    local bonus = e.MultiStabBonus or 0
    if not (bonus >= 0 and bonus <= 4) then
      return "vrfw.DualElement.MultiStabBonus = " .. tostring(bonus) .. ": 0-4 (fraction of the single same-element bonus per extra element)"
    end
    if #declared == 0 then
      local t = self:skill_num(id, sc.ptype)
      if t ~= nil and t < 2 then self:warn(m, w .. ": " .. self:label(id) .. " is performed alone (users = 1): its element is always the user's") end
    end
    if declared[1] ~= nil then
      local te = self:skill_num(id, sc.element)
      if te ~= nil and not U.contains(declared, te % 256) then
        self:warn(m, string.format("%s: %s's table element is not one of its Elements: menus show %s (the main one is %s)", w, self:label(id),
          VRFW.technique.element_word(te % 256), VRFW.technique.element_word(declared[1])))
      end
    end
    local tag = {}
    for _, x in ipairs(declared) do tag[#tag + 1] = VRFW.technique.element_word(x) end
    self:claim("ball", id, 1, m, "dual/" .. table.concat(tag, "+") .. "/" .. tostring(bonus), w)
    self.performers[id] = { b = bonus, declared = declared, m = m }
    return nil
  end

  function X:performer_rules()
    local function ev(id)
      local e = self:skill_num(id, sc.ev)
      if e ~= nil and e % TWO32 ~= 0 then return { e % TWO32 } end
      return {}
    end
    local out = {}
    for _, id in ipairs(U.keys(self.performers)) do
      local p = self.performers[id]
      if p.b ~= nil and not self.deleted[id] and self:skill_row(id) ~= nil then
        local key = self:label(id)
        out[#out + 1] = { skill = id, key = key, multi_stab_bonus = p.b, elements = p.declared, events = ev(id), mod_id = p.m }
        if covers(self, id, key) then
          for _, suf in ipairs(VARIANTS) do
            local vkey = key .. suf
            local vid = VRFW.crc32(vkey)
            if self.performers[vid] == nil and not self.deleted[vid] and self:skill_row(vid) ~= nil then
              out[#out + 1] = { skill = vid, key = vkey, multi_stab_bonus = p.b, elements = p.declared, events = ev(vid), mod_id = p.m, variant_of = key }
            end
          end
        end
      end
    end
    return X.sort_rules(out)
  end

  -- ------------------------------------------------------------------------------------------------- effect variants
  -- one copy of the move's event per `[[edit.effect_variant]]` case (`<event>_v<element ids>`): its evt and snd lists
  -- byte for byte, its eff list with the objects swapped, an env row cloned from the base's
  function X:event_variants()
    local decls = self.variant_decls
    self.variant_decls = {}
    local out = {}
    for _, x in ipairs(decls) do
      local m, id, d = x.m, x.id, x.d
      local w = x.what .. ".effect_variant"
      if not self.deleted[id] then
        local ev = self:skill_str(id, sc.evn)
        if ev == nil or ev == "" then
          self:err(m, w .. ": " .. self:label(id) .. " has no event (cutscene): left out")
        else
          ev = lower(ev)
          local els, bad = {}, nil
          for _, word in ipairs(d.elements or {}) do
            local e = VRFW.technique.element_id(word)
            if e == nil then bad = word else els[#els + 1] = e end
          end
          if bad ~= nil then
            self:err(m, w .. ": element `" .. bad .. "`: wind, forest, fire, mountain, void or any (left out)")
          elseif #els == 0 or #els > 4 or U.is_empty(d.objects) then
            self:err(m, w .. ": give 1-4 `elements` (executor first) and at least one `objects` swap (left out)")
          else
            local name = VRFW.technique.variant_name(ev, els)
            local dup = false
            for _, v in ipairs(out) do if v.variant == name then dup = true end end
            if dup then
              self:warn(m, w .. ": " .. name .. " is declared twice: the first wins")
            else
              local swaps = {}
              for _, k in ipairs(U.keys(d.objects)) do swaps[#swaps + 1] = { lower(k), lower(d.objects[k]) } end
              local badto
              for _, s in ipairs(swaps) do
                if s[2] == "" or s[2]:find("[^%w_]") then badto = s[2] break end
              end
              if badto ~= nil then
                self:err(m, w .. ": object `" .. badto .. "`: an effect object root (letters, digits, _) (left out)")
              else
                local lists = {
                  { "data/common/event_cfg/evt/" .. ev .. ".cfg.bin", "data/common/event_cfg/evt/" .. name .. ".cfg.bin", 0 },
                  { "data/common/event_cfg/eff/" .. ev .. "_eff.cfg.bin", "data/common/event_cfg/eff/" .. name .. "_eff.cfg.bin", 1 },
                  { "data/common/event_cfg/snd/" .. ev .. "_snd.cfg.bin", "data/common/event_cfg/snd/" .. name .. "_snd.cfg.bin", 2 },
                }
                local made, fail = {}, nil
                for _, l in ipairs(lists) do
                  local b = self:read_any(l[1])
                  if b == nil then
                    if l[3] ~= 2 then
                      fail = l[1] .. " not found"
                      break
                    end
                  elseif l[3] == 1 then
                    local nb, n = VRFW.technique.swap_objects(b, swaps)
                    if nb == nil then
                      fail = n
                      break
                    elseif n == 0 then
                      local roots = {}
                      for _, s in ipairs(swaps) do roots[#roots + 1] = '"' .. s[1] .. '"' end
                      fail = l[1] .. ": none of the objects [" .. table.concat(roots, ", ") .. "] is in the eff list"
                      break
                    end
                    made[#made + 1] = { l[2], nb }
                  else
                    made[#made + 1] = { l[2], b }
                  end
                end
                if fail == nil then
                  local ok, e = self:add_env_row(name, VRFW.crc32(ev))
                  if ok == nil then fail = e end
                end
                if fail ~= nil then
                  self:err(m, w .. ": " .. name .. ": " .. fail .. " (left out)")
                else
                  for _, f in ipairs(made) do VRFW.technique.serve(f[1], f[2]) end
                  out[#out + 1] = { event = ev, event_id = VRFW.crc32(ev), elements = els, variant = name, variant_id = VRFW.crc32(name),
                    objects = swaps, key = self:label(id), mod_id = m }
                end
              end
            end
          end
        end
      end
    end
    if #out > 0 then
      local list = {}
      for _, v in ipairs(out) do list[#list + 1] = v.event .. " -> " .. v.variant end
      self:info(string.format("effect variants: %d event copy(ies) (the swapped objects are the effect type's copies; a missing one plays nothing): %s",
        #out, table.concat(list, "; ")))
    end
    return out
  end

  -- ------------------------------------------------------------------------------------------------- row icons
  function X:move_icons()
    local out = {}
    for ri = 0, S:len(sc.li) - 1 do
      local id = S:u32(sc.li, ri, sc.id)
      if id ~= nil and not self.deleted[id] then
        local mask = VRFW.technique.icon_mask(S:num(sc.li, ri, sc.category) or 0, S:num(sc.li, ri, sc.flags) or 0)
        if mask ~= 0 then out[#out + 1] = { skill = id, mask = mask, i = ri } end
      end
    end
    table.sort(out, function(a, b)
      if a.skill ~= b.skill then return a.skill < b.skill end
      return a.i < b.i
    end)
    local res, last = {}, nil
    for _, x in ipairs(out) do
      if x.skill ~= last then res[#res + 1] = { skill = x.skill, mask = x.mask } end
      last = x.skill
    end
    return res
  end

  -- ------------------------------------------------------------------------------------------------- keeper scenes
  function X.describe_keeper(p)
    local function side(s) return s or "(retail)" end
    local cond = {}
    if p.max_gauge_damage ~= nil then cond[#cond + 1] = string.format("the shot takes <= %.0f %% of the gauge", p.max_gauge_damage * 100) end
    if p.last_minutes ~= nil then cond[#cond + 1] = "in the last " .. tostring(p.last_minutes) .. " min of the match" end
    if #p.keeper_save > 0 then cond[#cond + 1] = "the keeper's save is " .. table.concat(p.keeper_save, " / ") end
    if #cond == 0 then return string.format("%s / %s (%s)", side(p.save), side(p.goal), p.mod_id) end
    local pr = p.priority ~= 0 and (", priority " .. tostring(p.priority)) or ""
    return string.format("%s if %s (%s%s)", side(p.save), table.concat(cond, " and "), p.mod_id, pr)
  end

  -- a `[[keeper_scene]]` of mod `m`
  function X:keeper_scene(m, what, d)
    if d.save == nil and d.goal == nil then E("declare `save`, `goal` or both") end
    local function side(name, key, tpl_key)
      if name == nil then return nil end
      local tpl = X.input.defaults[tpl_key]
      local id = tpl.ok and VRFW.crc32(tpl.ok) or nil
      local ev, e = self:event(m, what, name, id, tpl.err)
      if ev == nil then E(key .. ": " .. e) end
      if ev:sub(1, 5) ~= "ev71_" and ev:sub(1, 5) ~= "ev63_" then
        self:warn(m, string.format("%s.%s: %s is not a keeper scene (ev71_3…, ev63_…): it plays with the keeper in actor slot 6", what, key, ev))
      end
      return ev
    end
    local x = d.max_gauge_damage
    if x ~= nil and not (x > 0 and x <= 1) then E("max_gauge_damage = " .. tostring(x) .. ": a share of the keeper's gauge, 0 < x <= 1 (0.15 = 15 %)") end
    x = d.last_minutes
    if x ~= nil and not (x > 0 and x <= 90) then E("last_minutes = " .. tostring(x) .. ": game minutes before the end of the match's final period, 0 < x <= 90") end
    local keeper_save = {}
    for _, k in ipairs(d.keeper_save or {}) do
      local kind = VRFW.technique.keeper_save(k)
      if kind == nil then E("keeper_save: `" .. k .. "` is not a keeper save (one of " .. table.concat(consts.keeper_saves, ", ") .. ")") end
      if not U.contains(keeper_save, kind) then keeper_save[#keeper_save + 1] = kind end
    end
    if d.keeper_save ~= nil and #d.keeper_save == 0 then
      E('keeper_save = []: name the keeper saves that play the scene (e.g. ["front", "high", "low"]) or leave it out')
    end
    local conditional = d.max_gauge_damage ~= nil or d.last_minutes ~= nil or #keeper_save > 0
    if conditional and (d.save == nil or d.goal ~= nil) then
      E("max_gauge_damage / last_minutes / keeper_save make a conditional save scene: give `save` only (no `goal`)")
    end
    if d.priority ~= nil and not conditional then
      E("priority ranks the conditional scenes (max_gauge_damage / last_minutes / keeper_save): the random pairs have none")
    end
    local save = side(d.save, "save", "keeper_save_template")
    local goal = side(d.goal, "goal", "keeper_goal_template")
    if d.option ~= nil then
      local k = VRFW.technique.option_kind(m, d.option)
      if k == false then
        self:info(what .. ".option: mod " .. m .. " not found: `" .. d.option .. "` not checked")
      elseif k == nil then
        self:warn(m, what .. ".option: the mod's options.toml has no row `" .. d.option .. "`: the entry is always on")
      elseif k ~= "toggle" then
        self:warn(m, what .. ".option: `" .. d.option .. "` is not a toggle: the entry is always on")
      end
    end
    return { save = save, goal = goal, mod_id = m, option = d.option, max_gauge_damage = d.max_gauge_damage, last_minutes = d.last_minutes,
      keeper_save = keeper_save, priority = d.priority or 0 }
  end

  -- ------------------------------------------------------------------------------------------------- hand-offs
  function X:handoff_ref(r, m)
    if type(r) == "number" then
      local id = r % TWO32
      if self:skill_row(id) ~= nil then return id end
      return nil, "move " .. int_str(r) .. " is not in skill_config"
    end
    return self:tech_ref(r, m)
  end
  function X:move_event(id)
    local e = self:skill_str(id, sc.evn)
    if e == nil or e == "" then return nil end
    return lower(e)
  end

  function X:handoffs(files, variants)
    local W = consts.handoff_within
    local out = {}
    for _, f in ipairs(files) do
      for i, d in ipairs(f.value.handoff or {}) do
        local m = f.mod
        local what = string.format("%s: handoff #%d (%s)", f.file, i, X.idref_str(d.technique))
        local h, e = X.try(function()
          local id = need(self:handoff_ref(d.technique, m))
          if self.deleted[id] then return false end
          local key = self:label(id)
          local event = self:move_event(id)
          if event == nil then E(key .. " has no event (cutscene)") end
          if #d.after == 0 then E("`after` names no move (the first part of the chain)") end
          local after = {}
          local moves = {}
          for _, a in ipairs(d.after) do
            local aid, ae = self:handoff_ref(a, m)
            if aid == nil then E("after: " .. ae) end
            if not U.contains(moves, aid) then moves[#moves + 1] = aid end
            local ev = self:move_event(aid)
            if ev == nil then E("after: " .. self:label(aid) .. " has no event (cutscene)") end
            if ev == event then E("after: " .. self:label(aid) .. " plays the combined move's own event " .. ev) end
            local evs = { ev }
            for _, v in ipairs(variants) do if v.event == ev then evs[#evs + 1] = v.variant end end
            for _, x in ipairs(evs) do
              if not U.contains(after, x) then after[#after + 1] = x end
            end
          end
          local within = d.within or W[1]
          if not (within >= W[2] and within <= W[3]) then E(string.format("within = %s: %s-%s seconds", tostring(within), tostring(W[2]), tostring(W[3]))) end
          local seat = 0
          if d.seat ~= nil then
            local x = lower(U.trim(d.seat))
            local n = x:match("^s(%d%d)$")
            if n == nil or tonumber(n) >= 4 then E('seat = "' .. x .. '": s00 to s03') end
            seat = tonumber(n)
          end
          local handoff = need(self:event(m, what, d.event, VRFW.crc32(event)))
          if handoff == event then E("event: " .. handoff .. " is the move's own full scene") end
          local ids = {}
          for k, x in ipairs(after) do ids[k] = VRFW.crc32(x) end
          -- after_moves (VRFW 2.1): the moves the chain record's last shot link must name (the run time's «C chains A»)
          return { key = key, mod_id = m, event_id = VRFW.crc32(event), event = event, after_ids = ids, after = after, after_moves = moves,
            handoff_id = VRFW.crc32(handoff), handoff = handoff, within_ms = X.round(within * 1000), seat = seat }
        end)
        if h == nil then
          self:err(m, what .. ": " .. e .. " (left out)")
        elseif h then
          out[#out + 1] = h
        end
      end
    end
    return out
  end
end
