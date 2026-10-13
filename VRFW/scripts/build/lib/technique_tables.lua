-- The /2 tables of the technique build (scripts/build/technique.lua; docs/app/technique-engine.md §3.7-§3.12):
-- SKILL_EX pairs of a move, new aura commands and the child lists of any command (aura_skill_config), keshin changes
-- (change_aura_skill_config), override moves and shot chains (override_skill_config), passives and their twins rule
-- (passive_skill_config), passive effect definitions (passive_skill_effect_config), ability boards
-- (ability_learning_config), skill_text rows by id, and `[[event_env]]` (event_env_config_* rows and their tag-word
-- groups in event_tag_word_replace_config). Installs its functions on the build context X.

local TWO32 = 4294967296

return function(X)
  local U, P, E, need, try = X.U, X.P, X.E, X.need, X.try
  local consts = X.consts
  local S = X.S
  local AU = consts.aura
  local hex, int_str, lower, idref_str = X.hex, X.int_str, X.lower, X.idref_str
  local CHAIN = consts.chain

  local EX_INFO, EX_COND, EX_SET = "m_skillExInfoList", "m_skillExConditionList", "m_skillExSettingList"
  local CHANGE_INFO, CHANGE_DATA = "m_ChangeAuraSkillInfoList", "m_ChangeAuraSkillDataList"
  local OV_SKILL, OV_COND, OV_CSKILL = "m_OverrideSkillInfoList", "m_OverrideConditionInfoList", "m_OverrideConditionSkillInfoList"
  local PEFF = "PASSIVE_SKILL_EFFECT_INFO"
  local PS_ID, PS_KEY = 0, 6
  local AURA_SCHEMA, PASSIVE_SCHEMA = "skill/aura_skill", "skill/passive_skill"
  local ENV_ROW = "EVENT_ENV_CONFIG"
  local COL_TAGS, COL_SND_TAGS = 52, 54

  -- a short dump of a declared value (claims: two mods' values compared)
  local function dump(v)
    local t = type(v)
    if t == "table" then
      if v.float ~= nil then return tostring(v.float) end
      local parts = {}
      if #v > 0 then
        for _, x in ipairs(v) do parts[#parts + 1] = dump(x) end
        return "[" .. table.concat(parts, ",") .. "]"
      end
      for _, k in ipairs(U.keys(v)) do parts[#parts + 1] = tostring(k) .. "=" .. dump(v[k]) end
      return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "number" then
      return string.format("%.17g", v)
    end
    return tostring(v)
  end

  function X:passive_t() return self:t("passive", "passives are not changed") end
  function X:peffect_t() return self:t("peffect", "passive effect definitions are not changed") end
  function X:ability_t() return self:t("ability", "ability boards are not changed") end
  function X:tags_t() return self:t("tags", "tag-word groups are not changed") end

  -- ------------------------------------------------------------------------------------------------- SKILL_EX
  -- the SKILL_EX pairs of move `id`: its info row (created when missing) points at new condition / setting rows
  function X:set_ex(m, what, id, pairs)
    return try(function()
      local info, cl, sl = need(S:list(EX_INFO)), need(S:list(EX_COND)), need(S:list(EX_SET))
      local cid, ccond, cset = need(S:col(info, "id")), need(S:col(info, "cond")), need(S:col(info, "setting"))
      local conds, sets = {}, {}
      for i, p in ipairs(pairs) do
        local r = S:zero_row(cl)
        local ok, e = S:row_cells(cl, r, p.cond or {})
        if not ok then E(string.format("ex[%d].cond: %s", i - 1, e)) end
        conds[#conds + 1] = r
        local s = S:zero_row(sl)
        ok, e = S:row_cells(sl, s, p.setting or {})
        if not ok then E(string.format("ex[%d].setting: %s", i - 1, e)) end
        sets[#sets + 1] = s
      end
      local ri = S:find(info, cid, id)
      if ri == nil then
        local r = S:zero_row(info)
        need(S:row_set(r, cid, id))
        ri = S:push(info, r)
      end
      local a = need(S:set_children(info, ri, ccond, cl, conds))
      local b = need(S:set_children(info, ri, cset, sl, sets))
      if a or b then self.ex_changed = true end
      self:claim("ex", id, 0, m, dump(pairs), what .. ".ex")
      return true
    end)
  end

  -- ------------------------------------------------------------------------------------------------- aura commands
  -- entry index of an aura command: its key (first row with it), else its id
  function X:aura_entry(s)
    local t = need(self:aura(), "aura_skill_config not available")
    s = U.trim(s)
    local e = P.find_info(t, P.AURA, AU.key, nil, s) or P.find_info(t, P.AURA, AU.id, VRFW.ids.parse(s), nil)
    if e == nil then E("aura command `" .. s .. "` is not in aura_skill_config (write its key like wks00020, or its id)") end
    return e
  end

  -- the id of an aura command reference (a key or an id; an id the table lacks is taken as written)
  function X:aura_id(r)
    local e = try(self.aura_entry, self, idref_str(r))
    if e ~= nil then
      local t = self:aura()
      local id = t and t:uint(e, AU.id)
      if id ~= nil then return id end
    end
    return U.id(r)
  end

  -- cells and child lists of aura command `id` (`lists` = { unique_effects, effects, charas }, nil = untouched)
  function X:aura_rest(m, what, id, cells, lists)
    return try(function()
      local function find()
        local t = need(self:aura(), "aura_skill_config not available")
        local e = P.find_info(t, P.AURA, AU.id, id, nil)
        if e == nil then E("aura command " .. hex(id) .. " vanished") end
        return e
      end
      if not U.is_empty(cells) then
        local e = find()
        local cols = need(P.set_cells(self:aura(), e, AURA_SCHEMA, cells))
        for _, c in ipairs(cols) do self:claim("aura", id, c, m, "cell", what .. ".cells") end
      end
      local names = { "unique_effects", "effects", "charas" }
      for k = 1, 3 do
        local rows = lists[k]
        if rows ~= nil then
          local vals = need(P.rows(rows, names[k]))
          local e = find()
          need(P.set_children(self:aura(), P.AURA, e, k, vals))
          self:claim("auralist", id, k - 1, m, dump(rows), what .. "." .. names[k])
        end
      end
      return true
    end)
  end

  -- `[[aura_command]]`: a new command, a clone of `from` (info row + refs) with its key / id and the changes
  function X:aura_new(m, file, d)
    local key = U.trim(d.key)
    if key == "" or key:find("[^%w_]") then E("key `" .. key .. "`: a-z 0-9 _") end
    local id = d.id ~= nil and U.id(d.id) or VRFW.crc32(key)
    local linked
    if d.technique ~= nil then
      local l, e = self:tech_ref(idref_str(d.technique), m)
      if l == nil then E("technique: " .. e) end
      linked = l
    end
    local from, fe = try(self.aura_entry, self, idref_str(d.from))
    if from == nil then E("from: " .. fe) end
    local t = self:aura()
    if P.find_info(t, P.AURA, AU.id, id, nil) ~= nil then E("id " .. hex(id) .. " is already an aura command (give another `id`)") end
    local values = t:entry(from).values
    values[AU.id + 1] = U.i32(id)
    values[AU.key + 1] = key
    for _, x in ipairs({ { d.power_min, AU.power_min, "power_min" }, { d.power_max, AU.power_max, "power_max" } }) do
      if x[1] ~= nil then
        if x[1] < 0 or x[1] > 32767 then E(x[3] .. " = " .. int_str(x[1]) .. ": out of 0-32767") end
        values[x[2] + 1] = U.i32(x[1])
      end
    end
    if linked ~= nil then values[AU.skill + 1] = U.i32(linked) end
    need(P.add_info(t, P.AURA, from, values))
    local what = file .. ": aura_command " .. key
    self:claim("aura", id, "max", m, "new", what)
    need(self:aura_rest(m, what, id, d.cells or {}, { d.unique_effects, d.effects, d.charas }))
    if d.compatible ~= nil then self:compat_rule(m, what, id, key, d.compatible) end
    return true
  end

  -- ------------------------------------------------------------------------------------------------- keshin changes
  function X:aura_change(m, file, d)
    local aura = self:aura_id(d.aura)
    local pairs_ = {}
    for _, p in ipairs(d.changes) do pairs_[#pairs_ + 1] = { self:aura_id(p[1]), U.id(p[2]) } end
    local what = file .. ": aura_change " .. idref_str(d.aura)
    local t = need(self:change(), "change_aura_skill_config not available")
    local info, data = need(t:list(CHANGE_INFO)), need(t:list(CHANGE_DATA))
    local iid, idata = need(t:col(info, "id")), need(t:col(info, "data"))
    local did, dparam = need(t:col(data, "id")), need(t:col(data, "charaParamId"))
    local rows = {}
    for _, p in ipairs(pairs_) do
      local r = t:zero_row(data)
      need(t:row_set(r, did, p[1]))
      need(t:row_set(r, dparam, p[2]))
      rows[#rows + 1] = r
    end
    local ri = t:find(info, iid, aura)
    if ri == nil then
      local r = t:zero_row(info)
      need(t:row_set(r, iid, aura))
      ri = t:push(info, r)
    end
    if need(t:set_children(info, ri, idata, data, rows)) then self.change_changed = true end
    self:claim("change", aura, 0, m, dump(pairs_), what)
    return true
  end

  -- ------------------------------------------------------------------------------------------------- override moves
  function X:override_(m, file, d)
    local id = need(self:tech_ref(idref_str(d.technique), m))
    local what = file .. ": override " .. self:label(id)
    local when = d.when or {}
    if d.chain and not d.delete then
      self.chains[#self.chains + 1] = { m = m, what = what, id = id, any_order = d.chain_any_order }
      if #when == 0 then return true end
    elseif #when == 0 and not d.delete then
      E("`when` (the conditions) is missing")
    end
    local conds = {}
    for i, w in ipairs(when) do
      local sk = {}
      for _, p in ipairs(w.skills) do
        local s, e = self:tech_ref(idref_str(p[1]), m)
        if s == nil then E(string.format("when[%d].skills: %s", i - 1, e)) end
        sk[#sk + 1] = { s, p[2] }
      end
      conds[#conds + 1] = { kind = w.type, sk = sk }
    end
    local t = need(self:over(), "override_skill_config not available")
    local ls, lc, lk = need(t:list(OV_SKILL)), need(t:list(OV_COND)), need(t:list(OV_CSKILL))
    local s_id, s_ref = need(t:col(ls, "overrideSkillId")), need(t:col(ls, "refConditionData"))
    local c_type, c_ref = need(t:col(lc, "conditionType")), need(t:col(lc, "refConditionSkillData"))
    local k_id, k_num = need(t:col(lk, "skillId")), need(t:col(lk, "num"))
    local row = t:find(ls, s_id, id)
    if d.delete then
      if row ~= nil then
        t:remove(ls, row)
        self.over_changed = true
      end
      self:claim("override", id, 0, m, "delete", what)
      return true
    end
    -- the conditions as they are (materialized) vs as declared
    local same = false
    if row ~= nil then
      local start = t:tuple(ls, row, s_ref) or 0
      local ch = t:children(ls, row, s_ref, lc)
      if #ch == #conds then
        same = true
        for j, idx in ipairs(ch) do
          local c = conds[j]
          local kind = t:num(lc, idx, c_type) or 0
          local ks = t:children(lc, start + j - 1, c_ref, lk)
          if kind ~= c.kind or #ks ~= #c.sk then
            same = false
          else
            for q, k in ipairs(ks) do
              if (t:num(lk, k, k_id) or 0) % TWO32 ~= c.sk[q][1] or (t:num(lk, k, k_num) or 0) ~= c.sk[q][2] then same = false end
            end
          end
          if not same then break end
        end
      end
    end
    if not same then
      local first = t:len(lc)
      for _, c in ipairs(conds) do
        local cr = t:zero_row(lc)
        need(t:row_set(cr, c_type, c.kind))
        local ci = t:push(lc, cr)
        local ks = {}
        for _, s in ipairs(c.sk) do
          local k = t:zero_row(lk)
          need(t:row_set(k, k_id, s[1]))
          need(t:row_set(k, k_num, s[2]))
          ks[#ks + 1] = k
        end
        need(t:set_children(lc, ci, c_ref, lk, ks))
      end
      local r = row
      if r == nil then
        local sr = t:zero_row(ls)
        need(t:row_set(sr, s_id, id))
        r = t:push(ls, sr)
      end
      local n = #conds
      need(t:set_tuple(ls, r, s_ref, n == 0 and 0 or first, n))
      self.over_changed = true
    end
    self:claim("override", id, 0, m, dump(conds), what)
    return true
  end

  -- `chain = true` of an `[[override]]` (after every mod's overrides and edits): its single two-part condition becomes
  -- a shot chain (docs/game/mechanics/override-skills.md §10.5)
  function X:override_chain(m, what, id, any_order)
    local kind = any_order and 2 or 1
    local t = need(self:over(), "override_skill_config not available")
    local ls, lc, lk = need(t:list(OV_SKILL)), need(t:list(OV_COND)), need(t:list(OV_CSKILL))
    local s_id, s_ref = need(t:col(ls, "overrideSkillId")), need(t:col(ls, "refConditionData"))
    local c_ref = need(t:col(lc, "refConditionSkillData"))
    local k_id = need(t:col(lk, "skillId"))
    local r = t:find(ls, s_id, id)
    if r == nil then E("chain: the move has no override row (declare its `when`)") end
    local start, n = t:tuple(ls, r, s_ref)
    start, n = start or 0, n or 0
    if n ~= 1 then E("chain: " .. int_str(n) .. " condition(s); a chain override has exactly one (two parts)") end
    local ci = start
    local parts = {}
    for _, k in ipairs(t:children(lc, ci, c_ref, lk)) do parts[#parts + 1] = (t:num(lk, k, k_id) or 0) % TWO32 end
    if #parts ~= 2 then E("chain: the condition has " .. #parts .. " part(s); a shot chain has exactly two (the shot and the chained move)") end
    -- the SKILL_EX rows: which part is s00's, and are they chain rows already
    local info, cl, sl = need(S:list(EX_INFO)), need(S:list(EX_COND)), need(S:list(EX_SET))
    local cid, ccond, cset = need(S:col(info, "id")), need(S:col(info, "cond")), need(S:col(info, "setting"))
    local chain_col, cexe_col = need(S:col(cl, "chainOverrideCondSkill")), need(S:col(cl, "condExeId"))
    local exe_id, exe_skill = need(S:col(sl, "exeId")), need(S:col(sl, "exeSetSkill"))
    local p_skill = { need(S:col(sl, "partnerSetSkill1")), need(S:col(sl, "partnerSetSkill2")), need(S:col(sl, "partnerSetSkill3")) }
    local ri = S:find(info, cid, id)
    local cur = ri and S:children(info, ri, ccond, cl) or {}
    local sets = ri and S:children(info, ri, cset, sl) or {}
    local function nv(list, idx, col) return (S:num(list, idx, col) or 0) % TWO32 end
    local kept = false
    for _, c in ipairs(cur) do if nv(cl, c, chain_col) ~= 0 then kept = true end end
    local a
    if kept then
      for j = 1, math.min(#cur, #sets) do
        if nv(cl, cur[j], cexe_col) == CHAIN.any and nv(sl, sets[j], exe_id) == CHAIN.shooter then
          local x = nv(cl, cur[j], chain_col)
          if U.contains(parts, x) then a = x end
          break
        end
      end
    elseif sets[1] ~= nil then
      local x = nv(sl, sets[1], exe_skill)
      if U.contains(parts, x) then a = x end
    end
    a = a or parts[1]
    local b = parts[1] == a and parts[2] or parts[1]
    local slot = 1
    if sets[1] ~= nil then
      for k = 1, 3 do
        if nv(sl, sets[1], p_skill[k]) == b then slot = k break end
      end
    end
    -- the condition: its type, and the parts in chain order (first part first)
    do
      local c_type = need(t:col(lc, "conditionType"))
      local changed = need(t:set_num(lc, ci, c_type, kind))
      if not any_order and parts[1] ~= a then
        local ks = {}
        for i, k in ipairs(t:children(lc, ci, c_ref, lk)) do ks[#ks + 1] = { k = k, i = i, last = ((t:num(lk, k, k_id) or 0) % TWO32 ~= a) and 1 or 0 } end
        table.sort(ks, function(x, y)
          if x.last ~= y.last then return x.last < y.last end
          return x.i < y.i
        end)
        local rows = {}
        for _, x in ipairs(ks) do rows[#rows + 1] = t:copy_row(lk, x.k) end
        if need(t:set_children(lc, ci, c_ref, lk, rows)) then changed = true end
      end
      if changed then self.over_changed = true end
    end
    local la, lb = self:label(a), self:label(b)
    local order = any_order and (la .. " <-> " .. lb .. ", either order (conditionType 2)") or (la .. " -> " .. lb .. " only (conditionType 1)")
    if kept then
      self:info(what .. ": chain override " .. order .. "; its SKILL_EX chain rows are kept")
      return true
    end
    local function pair(ball, exe, partner)
      local setting = { exe_id = exe, cond_exe_id = CHAIN.any, exe_type = 2 }
      setting["partner_id" .. slot] = partner
      setting["partner_type" .. slot] = 2
      for _, f in ipairs({ "exe_body_type1", "partner_body_type1_1", "partner_body_type1_2", "partner_body_type1_3", "exe_body_type2",
        "partner_body_type2_1", "partner_body_type2_2", "partner_body_type2_3" }) do
        setting[f] = 255
      end
      return { cond = { cond_exe_id = CHAIN.any, chain_override_cond_skill = ball }, setting = setting }
    end
    need(self:set_ex(m, what, id, { pair(a, CHAIN.shooter, CHAIN.receiver), pair(b, CHAIN.receiver, CHAIN.shooter) }))
    self:info(string.format("%s: chain override %s: s00 = %s, partner %d = %s, chain SKILL_EX rows written", what, order, la, slot, lb))
    return true
  end

  -- ------------------------------------------------------------------------------------------------- passives
  function X:passive_entry(r)
    local s = idref_str(r)
    local t = need(self:passive_t(), "passive_skill_config not available")
    local e = P.find_info(t, P.PASSIVE, PS_KEY, nil, U.trim(s)) or P.find_info(t, P.PASSIVE, PS_ID, U.id(r), nil)
    if e == nil then E("passive `" .. s .. "` is not in passive_skill_config (its key like ps10001_04, or its id)") end
    return e
  end
  function X:passive_id(e)
    local t = self:passive_t()
    return t and t:uint(e, PS_ID) or 0
  end

  -- cells and child lists of passive `id` (`lists` = { { rows, pool k, name } })
  function X:passive_rest(m, what, id, cells, lists)
    local function find()
      local t = need(self:passive_t(), "passive_skill_config not available")
      local e = P.find_info(t, P.PASSIVE, PS_ID, id, nil)
      if e == nil then E("passive " .. hex(id) .. " vanished") end
      return e
    end
    if not U.is_empty(cells) then
      local e = find()
      for _, c in ipairs(need(P.set_cells(self:passive_t(), e, PASSIVE_SCHEMA, cells))) do
        self:claim("passive", id, 100 + c, m, "cell", what .. ".cells")
      end
    end
    for _, l in ipairs(lists) do
      if l[1] ~= nil then
        local vals = need(P.rows(l[1], l[3]))
        local e = find()
        need(P.set_children(self:passive_t(), P.PASSIVE, e, l[2], vals))
        self:claim("passive", id, l[2] - 1, m, dump(l[1]), what .. "." .. l[3])
      end
    end
    return true
  end

  function X:passive(m, file, d)
    local lists = { { d.buff_icons, 1, "buff_icons" }, { d.effects, 2, "effects" } }
    if d.passive ~= nil and d.key == nil then
      if d.from ~= nil then E("`from` is for a new passive (`key`)") end
      local e = self:passive_entry(d.passive)
      local id = self:passive_id(e)
      return self:passive_rest(m, file .. ": passive " .. idref_str(d.passive), id, d.cells or {}, lists)
    elseif d.passive == nil and d.key ~= nil then
      local key = U.trim(d.key)
      if d.from == nil then E("a new passive needs `from` (the passive it is cloned from)") end
      local src, se = try(self.passive_entry, self, d.from)
      if src == nil then E("from: " .. se) end
      local id = VRFW.crc32(key)
      local t = self:passive_t()
      if P.find_info(t, P.PASSIVE, PS_ID, id, nil) ~= nil then E("passive `" .. key .. "` already exists") end
      local values = t:entry(src).values
      values[PS_ID + 1] = U.i32(id)
      values[PS_KEY + 1] = key
      need(P.add_info(t, P.PASSIVE, src, values))
      self:claim("passive", id, "max", m, "new", file .. ": passive " .. key)
      return self:passive_rest(m, file .. ": passive " .. key, id, d.cells or {}, lists)
    end
    E("write `passive` (edit) or `key` + `from` (new)")
  end

  -- `[[passive_twins]]`: one scaled copy per passive of `of`. Pass 1 (`only` nil) leaves for later the bases that do
  -- not exist yet; returns { n = made, rest = deferred 0-based indices }
  function X:passive_twins(m, file, d, only)
    if d.prefix == "" or d.prefix:find("[^%w_]") then E("prefix `" .. d.prefix .. "`: a-z 0-9 _") end
    local scale = d.scale
    if not (scale == scale and scale ~= math.huge and scale > 0) then E("scale = " .. tostring(scale) .. ": a positive number") end
    local n, later = 0, {}
    local only_set
    if only ~= nil then
      only_set = {}
      for _, i in ipairs(only) do only_set[i] = true end
    end
    for i0, r in ipairs(d.of) do
      local i = i0 - 1
      if not (only_set and not only_set[i]) then
        if only == nil and try(self.passive_entry, self, r) == nil then
          later[#later + 1] = i
        else
          local ok, e = try(function()
            local src = self:passive_entry(r)
            local base = self:passive_id(src)
            local key = d.prefix .. U.hex8(base)
            local id = VRFW.crc32(key)
            local t = self:passive_t()
            if P.find_info(t, P.PASSIVE, PS_ID, id, nil) ~= nil then E("`" .. key .. "` already exists") end
            local effects = {}
            for _, v in ipairs(P.children(t, P.PASSIVE, src, 2)) do
              local x = v[2]
              if type(x) == "number" then
                v[2] = U.i32(X.round(x * scale))
              elseif type(x) == "table" and x.float ~= nil then
                v[2] = { float = VRFW.technique.f32(x.float * scale) }
              end
              effects[#effects + 1] = v
            end
            local values = t:entry(src).values
            values[PS_ID + 1] = U.i32(id)
            values[PS_KEY + 1] = key
            local ne = need(P.add_info(t, P.PASSIVE, src, values))
            need(P.set_children(t, P.PASSIVE, ne, 2, effects))
            return true
          end)
          if ok == nil then
            self:err(m, string.format("%s: passive_twins of[%d] %s: %s (skipped)", file, i, idref_str(r), e))
          else
            n = n + 1
          end
        end
      end
    end
    return { n = n, rest = later }
  end

  -- `[[passive_effect_def]]`: the block appended after the last definition (before the list's sort run)
  function X:passive_effect_def(m, file, d)
    local id = d.id ~= nil and U.id(d.id) or VRFW.crc32(U.trim(d.key))
    local info, ie = P.row(d.info)
    if info == nil then E("info: " .. ie) end
    local v = { U.i32(id) }
    for _, x in ipairs(info) do v[#v + 1] = x end
    local block = { { name = PEFF, hash = VRFW.crc32(PEFF), values = v } }
    for i, r in ipairs(d.entries) do
      if type(r[1]) ~= "string" then E(string.format("entries[%d]: starts with the entry name", i - 1)) end
      local nm = U.trim(r[1])
      local pre = PEFF .. "_"
      while nm:sub(1, #pre) == pre do nm = nm:sub(#pre + 1) end
      local name = PEFF .. "_" .. nm
      local rest = {}
      for k = 2, #r do rest[#rest + 1] = r[k] end
      local vals, ve = P.row(rest)
      if vals == nil then E(string.format("entries[%d]: %s", i - 1, ve)) end
      block[#block + 1] = { name = name, hash = VRFW.crc32(name), values = vals }
    end
    local t = need(self:peffect_t(), "passive_skill_effect_config not available")
    if t:find(PEFF, 0, id) ~= nil then E("definition " .. hex(id) .. " already exists") end
    local hb, he, hs = VRFW.crc32(PEFF .. "_LIST_BEG"), VRFW.crc32(PEFF .. "_LIST_END"), VRFW.crc32("__SORT_INDEX")
    local b = t:seek(PEFF .. "_LIST_BEG", 0)
    if b == nil then E("no PASSIVE_SKILL_EFFECT_INFO_LIST_BEG") end
    local function last_end()
      for i = t:len() - 1, 0, -1 do
        if t:hash(i) == he then return i end
      end
    end
    local en = last_end()
    if en == nil then E("no PASSIVE_SKILL_EFFECT_INFO_LIST_END") end
    -- the list's own sort run = the __SORT_INDEX entries right before its end
    local s0 = en
    while s0 > b + 1 and t:hash(s0 - 1) == hs do s0 = s0 - 1 end
    local had_sort = s0 < en
    local proto = (t:hash(s0) == hs) and t:entry(s0) or nil
    t:splice(s0, s0, block)
    if t:int(b, 0) == nil then E("list begin without a count") end
    t:bump(b, 1)
    if had_sort then
      local hr = VRFW.crc32(PEFF)
      local e2 = last_end()
      local s1 = e2
      while t:hash(s1 - 1) == hs do s1 = s1 - 1 end
      local keys = {}
      for i = b + 1, s1 - 1 do
        if t:hash(i) == hr then
          local k = t:int(i, 0)
          keys[#keys + 1] = { k = k and (k % TWO32) or math.huge, i = #keys }
        end
      end
      table.sort(keys, function(x, y)
        if x.k ~= y.k then return x.k < y.k end
        return x.i < y.i
      end)
      local run = {}
      for _, x in ipairs(keys) do run[#run + 1] = { name = proto.name, hash = proto.hash, values = { x.i } } end
      t:splice(s1, e2, run)
    end
    self:claim("passive", id, "max-1", m, "new", file .. ": passive_effect_def " .. d.key)
    return true
  end

  -- ------------------------------------------------------------------------------------------------- ability boards
  function X:board(m, file, d)
    local id = U.id(d.board)
    local what = file .. ": board " .. idref_str(d.board)
    local cells = need(P.rows(d.cells, "cells"))
    local info
    if d.info ~= nil then
      local x, e = P.row(d.info)
      if x == nil then E("info: " .. e) end
      info = x
    end
    local t = need(self:ability_t(), "ability_learning_config not available")
    local e = P.find_info(t, P.BOARD, 0, id, nil)
    local function with_id(vals)
      local nv = { U.i32(id) }
      for _, x in ipairs(vals) do nv[#nv + 1] = x end
      return nv
    end
    if e ~= nil then
      if info ~= nil then
        local nv = with_id(info)
        if not P.row_eq(t:entry(e).values, nv) then t:splice(e, e + 1, { { name = t:name(e), hash = t:hash(e), values = nv } }) end
      end
    else
      if info == nil then E("a new board needs `info` (the other values of its info row)") end
      local tpl = P.infos(t, P.BOARD)[1]
      if tpl == nil then E("ability_learning_config has no board") end
      e = need(P.add_info(t, P.BOARD, tpl, with_id(info)))
    end
    need(P.set_children(t, P.BOARD, e, 1, cells))
    self:claim("board", id, 0, m, dump(d.cells), what)
    return true
  end

  -- ------------------------------------------------------------------------------------------------- skill_text rows
  local TEXT_FIELDS = { id = true, kind = true, variant = true, add = true }
  function X:text_row(m, file, d, file_default)
    local kind = U.trim(d.kind)
    if kind ~= "noun" and kind ~= "text" then E('kind = "' .. kind .. '": noun or text') end
    local texts, any = {}, false
    for _, k in ipairs(U.keys(d)) do
      if not TEXT_FIELDS[k] then
        local l = VRFW.lang.norm_or_all(k)
        if l == nil then E("unknown key `" .. k .. "` (id, kind, variant, add, all or a language: " .. table.concat(VRFW.lang.list(), ", ") .. ")") end
        texts[l] = d[k]
        any = true
      end
    end
    if not any then E("no text in any language") end
    local id = U.id(d.id)
    local what = file .. ": text " .. idref_str(d.id)
    for _, l in ipairs(U.keys(texts)) do
      self:claim("text", id, kind .. "#" .. tostring(d.variant or 0) .. "#" .. l, m, texts[l], what)
    end
    local default
    if file_default ~= nil and lower(U.trim(file_default)) ~= "none" then default = VRFW.lang.norm(file_default) end
    self:push_text(m, default, m .. ".text." .. string.format("%.0f", id),
      { table = "skill_text", id = id, variant = d.variant or 0, texts = texts, add = d.add or false, origin = what, kind = kind })
    return true
  end

  -- ------------------------------------------------------------------------------------------------- compaction
  -- drop the child rows nobody points at any more (SKILL_EX, keshin changes, override conditions)
  function X:compact_tables()
    local errs = {}
    local function c(t, li, col, child)
      local _, e = t:compact(li, col, child)
      if e ~= nil then errs[#errs + 1] = e end
    end
    if self.ex_changed then
      local i, ci, si = S:list(EX_INFO), S:list(EX_COND), S:list(EX_SET)
      if i and ci and si then
        local cc, cs = S:col(i, "cond"), S:col(i, "setting")
        if cc and cs then
          c(S, i, cc, ci)
          c(S, i, cs, si)
        end
      end
    end
    if self.change_changed and self.rdbn.change then
      local t = self.rdbn.change
      local i, d = t:list(CHANGE_INFO), t:list(CHANGE_DATA)
      local col = i and t:col(i, "data")
      if i and d and col then c(t, i, col, d) end
    end
    if self.over_changed and self.rdbn.over then
      local t = self.rdbn.over
      local s, cl, k = t:list(OV_SKILL), t:list(OV_COND), t:list(OV_CSKILL)
      if s and cl and k then
        local sr, cr = t:col(s, "refConditionData"), t:col(cl, "refConditionSkillData")
        if sr and cr then
          c(t, s, sr, cl)
          c(t, cl, cr, k)
        end
      end
    end
    for _, e in ipairs(errs) do VRFW.log.warn("compacting a table: " .. e .. " (the unused rows stay)") end
  end

  -- ------------------------------------------------------------------------------------------------- event_env
  local WHICH = {
    soccer_demo = { "env", "event/event_env_soccer_demo" },
    scenario = { "env_scenario", "event/event_env_scenario" },
    quest = { "env_quest", "event/event_env_quest" },
  }
  local function event_name(m, name)
    local r = U.trim(name)
    local own = m .. "." .. r
    for _, c in ipairs(X.anim_events) do
      if c.key == r or c.key == own then return c.id end
    end
    local ev = lower(r)
    if #ev > 2 and ev:sub(1, 2) == "ev" and not ev:find("[^%w_]") then return ev end
    E("`" .. name .. "`: not an event name (ev99_97010, ev81_00040_1…) nor an anim engine event (<mod>.<name>)")
  end
  function X:env_table(slot) return self:t(slot, "event environments are not changed") end

  -- group `name` (id = crc32) = the rows of the source group with `tw.set` applied; returns its id
  function X:tag_group(slot, ev, g, cur, name, tw)
    local src
    if tw.from == nil then
      src = cur
    else
      local s = idref_str(tw.from)
      local col = (g.info == P.TAG_ASSIGN.info) and COL_TAGS or COL_SND_TAGS
      local as_event = lower(U.trim(s))
      local t = self:env_table(slot)
      local i = as_event:sub(1, 2) == "ev" and t:find(ENV_ROW, 0, VRFW.crc32(as_event)) or nil
      if i ~= nil then src = t:uint(i, col) or 0 else src = U.id(tw.from) end
    end
    local gid = VRFW.crc32(name)
    local t = need(self:tags_t(), "event_tag_word_replace_config not available")
    local src_i = P.find_info(t, g, 0, src, nil)
    if src_i == nil then E("group " .. hex(src) .. " is not in " .. g.info) end
    local rows = P.children(t, g, src_i, 1)
    for _, tag in ipairs(U.keys(tw.set or {})) do
      local h = VRFW.ids.parse(tag)
      local v = U.trim(tw.set[tag])
      local found
      for _, r in ipairs(rows) do
        if type(r[1]) == "number" and r[1] % TWO32 == h then found = r break end
      end
      if found then
        while #found < 2 do found[#found + 1] = 0 end
        found[2] = v
      else
        rows[#rows + 1] = { U.i32(h), v }
      end
    end
    local info = P.find_info(t, g, 0, gid, nil)
    local added = false
    if info == nil then
      info = need(P.add_info(t, g, src_i, { U.i32(gid) }))
      added = true
    end
    need(P.set_children(t, g, info, 1, rows))
    if added then self:info(ev .. ": tag-word group " .. name .. " added to " .. g.info) end
    return gid
  end

  -- one `[[event_env]]` of mod `m`
  function X:event_env(m, what, d)
    local tname = d.table or "soccer_demo"
    local w = WHICH[U.trim(tname)]
    if w == nil then E('table = "' .. U.trim(tname) .. '": soccer_demo, scenario or quest') end
    local slot, schema = w[1], w[2]
    local ev = event_name(m, d.event)
    local id = VRFW.crc32(ev)
    local from = d.from ~= nil and event_name(m, d.from) or nil
    local k = self.keys[slot]
    local tkey = k.key or k.err
    local t = self:env_table(slot)
    if not t then E(tkey .. " not available") end
    local row = t:find(ENV_ROW, 0, id)
    local cloned
    if row == nil then
      if from == nil then E(ev .. " has no row in event_env_config_" .. tname .. ": give `from` (the event to clone)") end
      local ti = t:find(ENV_ROW, 0, VRFW.crc32(from))
      if ti == nil then E('from = "' .. from .. '": no row to clone in event_env_config_' .. tname) end
      local e = t:entry(ti)
      e.values[1] = U.i32(id)
      if #e.values > 1 then e.values[2] = ev end
      need(t:append_row(ENV_ROW, e))
      cloned = from
      row = t:find(ENV_ROW, 0, id)
      if row == nil then E("the new row vanished") end
    end
    if cloned then self:info(string.format("%s: %s gets an event_env_config_%s row cloned from %s", what, ev, tname, cloned)) end
    if not U.is_empty(d.cells) then
      local cols, ce = P.set_cells(t, row, schema, d.cells)
      if cols == nil then E("cells: " .. ce) end
      local ks = U.keys(d.cells)
      for i, c in ipairs(cols) do self:claim("env", id, c, m, dump(d.cells[ks[i]]), what .. ".cells." .. ks[i]) end
    end
    for _, x in ipairs({ { d.tag_words, P.TAG_ASSIGN, COL_TAGS, "assign", "tag_words" }, { d.snd_tag_words, P.TAG_SND, COL_SND_TAGS, "snd", "snd_tag_words" } }) do
      local tw, g, col, suffix, key = x[1], x[2], x[3], x[4], x[5]
      if tw ~= nil then
        local r = t:find(ENV_ROW, 0, id)
        if r == nil then E("the row vanished") end
        local cur = t:uint(r, col)
        if cur == nil then E(key .. ": the row has no column " .. col) end
        local group = "evt_" .. ev .. "_" .. suffix
        local gid, ge = try(self.tag_group, self, slot, ev, g, cur, group, tw)
        if gid == nil then E(key .. ": " .. ge) end
        r = t:find(ENV_ROW, 0, id)
        if r == nil then E("the row vanished") end
        t:set(r, col, U.i32(gid))
        self:claim("env", id, col, m, group .. " " .. dump(tw.set or {}), what .. "." .. key)
      end
    end
    return true
  end
end
