-- Build script of the `technique` type: every active mod's technique declarations (load order) -> the game's special-move tables,
-- move texts, learn lists, the item type's offers and the run-time rules.
-- Order: model checks, (1) NEW moves, (2) [[edit]], (3) [[aura_command]] (new aura commands) then [[aura]] (edits of existing ones), (3b) keshin/overrides/passive effects/boards/texts,
-- (3c) chain overrides and passives, (4) [[remove]], (5) [[learn]], (6) [[shop]], (7) [[keeper_scene]], (8) [[event_env]], (9) anim-engine events,
-- then final checks, the event -> move index, run-time rules, effect-variant copies and hand-offs; each in load order.
-- A cell two mods set to different values is a conflict: noted, the later mod wins.
-- Tables: RDBN (skill_config, skill_by_event_id_config, change_aura_skill_config, override_skill_config) and T2B served raw
-- (event_env_config_*, event_tag_word_replace_config, item_config, chara_param, chara_base, aura_skill_config, passive_skill_*, ability_learning_config);
-- only changed tables are served and untouched rows stay byte-identical.
-- Native (Rust): binary checks of events and models, the eff-list object swap of effect variants, run-time vocabularies (VRFW.technique.*).
-- input = { files = { { file, mod, load_index, empty, value } }, characters = { { key, chara } }, events, vocab, consts, defaults }
-- returns technique_engine::script::Scripted.

local U = require "lib/util"
local P = require "lib/pool"

local TWO32 = 4294967296
-- item catalog numbers: bits of the save's 8192-bit m_globalItemGetFlag, shared space of the item type
local CATALOG_LIMIT = 8192
local CATALOG_SPACE = "item_catalog"

return function(input)
  local consts, vocab = input.consts, input.vocab
  local IT, AU, CP = consts.item, consts.aura, consts.param
  local ENV_ROW, CHARA_ROW, PARAM_ROW = "EVENT_ENV_CONFIG", "CHARA_BASE_INFO", "CHARA_PARAM_INFO"
  local BOARD_COL = 10
  local SKILL_LIST, BYEV_LIST, BYEV_FAIL_LIST = "m_skillInfoList", "m_skillByEventIdList", "m_skillByEventIdFailList"

  -- ---- the context
  local X = {
    input = input, consts = consts, vocab = vocab, U = U, P = P,
    t2b = {}, rdbn = {}, keys = {},
    problems = {}, conflicts = {}, claims = {},
    created = {}, created_by_id = {}, texts = {}, load_index = {},
    hidden = {}, deleted = {}, removed_keys = {}, learned = {}, offers = {},
    goals = {}, balls = {}, performers = {}, minis = {}, chains = {}, variant_decls = {},
    used_ids = {}, used_internal = {}, used_text = {}, used_catalog = {},
    touched = {}, compat = {}, events_checked = {}, models_checked = {},
    ex_changed = false, change_changed = false, over_changed = false,
    anim_events = input.events or {}, characters = input.characters or {},
  }

  -- errors as Rust's `?`: E raises, X.try returns `value` or `nil, err`
  local function E(msg) error({ e = msg }, 0) end
  local function try(f, ...)
    local ok, r = pcall(f, ...)
    if ok then return r end
    if type(r) == "table" and r.e ~= nil then return nil, r.e end
    error(r, 0)
  end
  -- `v` or raise `err` (a host answer `nil, err`)
  local function need(v, err)
    if v == nil then E(err) end
    return v
  end
  X.E, X.try, X.need = E, try, need

  local hex = U.hex
  -- %.0f of the truncated number (the game's Lua %d rejects u32 ids >= 2^31)
  local function int_str(n) return string.format("%.0f", n >= 0 and math.floor(n) or math.ceil(n)) end
  -- Rust `{}` of an IdRef (a number as written, or the string)
  local function idref_str(x)
    if type(x) == "number" then return int_str(x) end
    return tostring(x)
  end
  local function idref_id(x) return U.id(x) end
  local function lower(s) return string.lower(s) end
  local function round(x)
    if x < 0 then return -round(-x) end
    local r = math.floor(x)
    if x - r >= 0.5 then r = r + 1 end
    return r
  end
  X.hex, X.int_str, X.idref_str, X.idref_id, X.lower, X.round = hex, int_str, idref_str, idref_id, lower, round

  -- ---- report
  function X:report(m, level, text)
    if level == "error" then VRFW.log.error(text) elseif level == "warn" then VRFW.log.warn(text) else VRFW.log.info(text) end
    self.problems[#self.problems + 1] = { mod_id = m, level = level, text = text }
  end
  function X:err(m, text) self:report(m, "error", text) end
  function X:warn(m, text) self:report(m, "warn", text) end
  function X:info(text) VRFW.log.info(text) end

  function X:claim(tab, row, col, m, v, what)
    local k = tab .. "|" .. string.format("%.0f", row) .. "|" .. tostring(col)
    local c = self.claims[k]
    if c and c.by ~= m and c.v ~= v then
      local msg = string.format("technique conflict: %s: mod %s = %s, mod %s = %s (winner: %s, loads later)", what, c.by, c.v, m, v, m)
      VRFW.log.warn(msg)
      self.problems[#self.problems + 1] = { mod_id = m, level = "warn", text = msg }
      self.problems[#self.problems + 1] = { mod_id = c.by, level = "warn", text = msg }
      self.conflicts[#self.conflicts + 1] = msg
    end
    self.claims[k] = { by = m, v = v, tab = tab, row = row }
  end

  -- ---- tables
  for slot, prefix in pairs(consts.prefixes) do
    local k, e = VRFW.rows.key(prefix)
    X.keys[slot] = k and { key = k } or { err = e }
  end

  -- a T2B table, opened once (`what` = what is not done without it)
  function X:t(slot, what)
    local c = self.t2b[slot]
    if c == nil then
      local k = self.keys[slot]
      local t, e
      if k.key then t, e = VRFW.rows.open(k.key) else e = k.err end
      if t then
        t:raw()
        c = t
      else
        VRFW.log.warn(e .. ": " .. what)
        c = false
      end
      self.t2b[slot] = c
    end
    return c or nil
  end
  function X:env() return self:t("env", "events cannot be checked or added") end
  function X:item() return self:t("item", "the moves' manuals (items) are not changed") end

  -- catalog number of a new move's manual: item allocator in the shared space, above the game's highest item_config number, below CATALOG_LIMIT, then holes
  function X:manual_catalog(m, key)
    if self.catalog_lo == nil then
      local k = self.keys.item
      local g, e
      if k.key then g, e = VRFW.rows.game(k.key) else e = k.err end
      if not g then return nil, "no manual catalog number (the game's item_config: " .. tostring(e) .. ")" end
      local used = {}
      for i = 0, g:len() - 1 do
        local n = g:name(i) or ""
        if n:sub(1, 5) == "ITEM_" and n:sub(-5) == "_INFO" and g:width(i) > IT.key then
          local c = g:int(i, IT.catalog)
          if c and c >= 0 and c < CATALOG_LIMIT then used[c] = true end
        end
      end
      self.catalog_lo, self.catalog_hi = VRFW.ids.free_above(used, CATALOG_LIMIT)
    end
    local used = {}
    for c in pairs(self.used_catalog) do if c >= 0 then used[c] = true end end
    local n, w = VRFW.ids.next(CATALOG_SPACE, m .. "." .. key .. "#catalog", used, self.catalog_lo, self.catalog_hi, 1)
    if w then self:warn(m, w) end
    if not n then return nil, "no free manual catalog number (" .. self.catalog_lo .. "-" .. (CATALOG_LIMIT - 1) .. " nor a free one below)" end
    return math.floor(n)
  end
  function X:param() return self:t("param", "learn lists are not changed") end
  function X:chara() return self:t("chara", "characters cannot be resolved") end
  function X:aura() return self:t("aura", "aura commands are not changed") end

  -- an RDBN table, opened once
  function X:r(slot, what, byev)
    local c = self.rdbn[slot]
    if c == nil then
      local k = self.keys[slot]
      if not k.key then
        VRFW.log.warn(k.err .. ": " .. what)
        c = false
      else
        local h, e = VRFW.rdbn.open(k.key)
        if h then
          c = h
        else
          if e:sub(-#": not found") == ": not found" then
            VRFW.log.warn(k.key .. ": not found: " .. what)
          else
            VRFW.log.warn(e .. ": " .. what)
          end
          c = false
        end
      end
      self.rdbn[slot] = c
    end
    return c or nil
  end
  function X:byev() return self:r("byev", "the event → move index is not changed") end
  function X:change() return self:r("change", "keshin changes are not changed") end
  function X:over() return self:r("over", "override moves are not changed") end

  -- ---- skill_config
  local S, sc
  function X:skill_row(id) return S:find(sc.li, sc.id, id) end
  function X:skill_num(id, col)
    local r = self:skill_row(id)
    if r == nil then return nil end
    return S:num(sc.li, r, col)
  end
  function X:skill_str(id, col)
    local r = self:skill_row(id)
    if r == nil then return nil end
    return S:str(sc.li, r, col)
  end
  -- set number cell `col` of move `id` for mod `m`: nil or an error text
  function X:set_skill(id, col, v, m, what)
    local r = self:skill_row(id)
    if r == nil then return string.format("%s: move %s not in skill_config", what, hex(id)) end
    self:claim("skill", id, col, m, int_str(v), what)
    local ok, e = S:set_num(sc.li, r, col, v)
    if ok == nil then return what .. ": " .. e end
    return nil
  end
  function X:set_skill_str(id, col, v, m, what)
    local r = self:skill_row(id)
    if r == nil then return string.format("%s: move %s not in skill_config", what, hex(id)) end
    self:claim("skill", id, col, m, v or "none", what)
    local ok, e = S:set_str(sc.li, r, col, v)
    if ok == nil then return what .. ": " .. e end
    return nil
  end

  -- the label of a move for messages: its own key or its internal key
  function X:label(id)
    local c = self.created_by_id[id]
    if c then return c.key end
    return self:skill_str(id, sc.key) or hex(id)
  end

  -- id of a move reference: a creation key (`<mod>.<name>`, or `<name>` of the same mod), an internal key (`whs00030`), or a number
  function X:tech_ref(s, m)
    s = U.trim(s)
    local c = self.created[s] or self.created[m .. "." .. s]
    if c then return c.id end
    if self.removed_keys[s] or self.removed_keys[m .. "." .. s] then return nil, "move `" .. s .. "` was deleted by a [[remove]]" end
    local r = S:find_str(sc.li, sc.key, s)
    if r ~= nil then
      local id = S:u32(sc.li, r, sc.id)
      if id == nil then return nil, "move `" .. s .. "`: no id" end
      return id
    end
    local id = VRFW.ids.parse(s)
    if self:skill_row(id) ~= nil then return id end
    if self.deleted[id] then return nil, "move `" .. s .. "` was deleted by a [[remove]]" end
    return nil, "move `" .. s .. "` is not in skill_config (write a game key like whs00030, its id, or a mod's <mod>.<name>)"
  end

  -- ---- other tables
  function X:item_row(id)
    local t = self:item()
    if not t then return nil end
    return t:find(IT.row, IT.id, id)
  end
  -- is the item row with id `id` a move's own manual (linked to the move `id`)?
  function X:own_manual(id)
    local i = self:item_row(id)
    if i == nil then return false end
    return self:item():uint(i, IT.skill) == id
  end
  -- the character id of a reference: a character engine creation (`<mod>.<name>`), else a game id
  function X:chara_ref(s, m)
    s = U.trim(s)
    for _, c in ipairs(self.characters) do
      if c.key == s or c.key == m .. "." .. s then return c.chara end
    end
    local id = VRFW.ids.parse(s)
    local t = self:chara()
    if not t then return nil, "chara_base not available" end
    if t:find(CHARA_ROW, 0, id) ~= nil then return id end
    return nil, "character `" .. s .. "` is not in chara_base (write a game internal name like c01000100, its id, or a character engine <mod>.<name>)"
  end
  -- does the game (or a mod, or an earlier type) have `key`?
  function X:exists(key)
    if VRFW.technique.mod_file(key) ~= nil then return true end
    return VRFW.rows.read(key) ~= nil
  end
  function X:read_any(key)
    local b = VRFW.technique.mod_file(key)
    if b ~= nil then return b end
    return VRFW.rows.read(key)
  end

  local function event_list_key(ev) return "data/common/event_cfg/evt/" .. ev .. ".cfg.bin" end
  local function valid_event(ev)
    return #ev > 0 and ev:sub(1, 2) == "ev" and not ev:find("[^%w_]")
  end
  X.valid_event = valid_event

  -- ---- events
  -- Give event `ev` an env row cloned from `template`'s: true = added, false = it had one (or no table); nil, err
  function X:add_env_row(ev, template)
    local id = VRFW.crc32(ev)
    local t = self:env()
    if not t then return false end
    if t:find(ENV_ROW, 0, id) ~= nil then return false end
    local i = t:find(ENV_ROW, 0, template)
    if i == nil then return nil, string.format("event `%s`: the template event %s has no event_env_config row to clone", ev, hex(template)) end
    local row = t:entry(i)
    row.values[1] = U.i32(id)
    if #row.values > 1 then row.values[2] = ev end
    local ok, e = t:append_row(ENV_ROW, row)
    if not ok then return nil, e end
    return true
  end
  function X:env_row(what, ev, template, label)
    local added, e = self:add_env_row(ev, template)
    if added == nil then return nil, e end
    if added then self:info(string.format("%s: event %s gets an event_env_config row cloned from %s", what, label, hex(template))) end
    return true
  end

  -- Resolve an event name (anim engine `<mod>.<name>`, game event, or a mod's own event) to the lower-case name, or nil, err; `tpl` = env row template of a mod's own event
  function X:event(m, what, name, tpl, tpl_err)
    local r = U.trim(name)
    local own = m .. "." .. r
    local lr = lower(r)
    for _, c in ipairs(self.anim_events) do
      if c.key == r or c.key == own or c.id == lr then
        local ok, e = self:env_row(what, c.id, VRFW.crc32(c.from), c.key .. " (anim engine, from " .. c.from .. ")")
        if not ok then return nil, e end
        return c.id
      end
    end
    local ev = lr
    if not valid_event(ev) then
      return nil, "event `" .. name .. "`: not an event name (ev60_00030, ev63_00010_1…) nor an anim engine event (<mod>.<name>)"
    end
    local id = VRFW.crc32(ev)
    local t = self:env()
    if not t then return ev end
    local in_env = t:find(ENV_ROW, 0, id) ~= nil
    local provided = self:exists(event_list_key(ev))
    if not in_env and not provided then
      return nil, string.format("event `%s` not found: it is not in event_env_config_soccer_demo, no active mod ships files\\%s and no anim engine [[event]] created it",
        ev, (event_list_key(ev):gsub("/", "\\")))
    end
    if not in_env then
      if tpl == nil then return nil, tpl_err end
      local ok, e = self:env_row(what, ev, tpl, ev .. " (a mod's own)")
      if not ok then return nil, e end
    end
    if provided and not self.events_checked[ev] then
      self.events_checked[ev] = true
      for _, w in ipairs(VRFW.technique.event_links(ev)) do self:warn(m, what .. ": " .. w) end
    end
    return ev
  end

  -- every event the anim engine created gets its env row, also the ones no declaration names
  function X:anim_env_rows()
    local added = {}
    for _, c in ipairs(self.anim_events) do
      local ok, e = self:add_env_row(c.id, VRFW.crc32(c.from))
      if ok == true then
        added[#added + 1] = c.id .. " (" .. c.key .. ", from " .. c.from .. ")"
      elseif ok == nil then
        self:err(c.mod_id, "anim engine event " .. c.key .. ": " .. e .. ": the game cannot play it")
      end
    end
    if #added > 0 then
      self:info(string.format("%d anim engine event(s) no move names get an event_env_config row: %s", #added, table.concat(added, ", ")))
    end
  end

  -- ---- texts
  local function norm_default(d, text)
    if d ~= nil and lower(U.trim(d)) == "none" then return nil end
    return U.norm_default(d, text)
  end
  X.norm_default = norm_default

  -- generated texts per (mod, default language): rows { key, t }
  function X:push_text(m, d, key, t)
    local k = m .. "\0" .. (d and ("1" .. d) or "0")
    local g = self.texts[k]
    if not g then
      g = { mod = m, default = d, rows = {} }
      self.texts[k] = g
    end
    g.rows[#g.rows + 1] = { key = key, t = t }
  end

  -- name / description rows of a move (or aura command): `skill_text` noun and text of the row's own ids
  function X:texts_of(m, what, key, name, desc, text, default, add)
    for _, l in ipairs(U.keys(text)) do
      if VRFW.lang.norm_or_all(l) == nil then
        self:warn(m, string.format("%s: text.%s: not a language (%s, all): ignored", what, l, table.concat(VRFW.lang.list(), ", ")))
      end
    end
    for _, x in ipairs({ { name, "noun", "name" }, { desc, "text", "description" } }) do
      local id, kind, field = x[1], x[2], x[3]
      local texts, any = U.pick_langs(text, function(t) return t[field] end)
      if any then
        if id == 0 then
          self:warn(m, string.format("%s: the row has no %s text id: that text is skipped", what, kind == "noun" and "name" or "description"))
        else
          self:push_text(m, default, key, { table = "skill_text", id = id, variant = 0, texts = texts, add = add, origin = what .. " (" .. m .. ")", kind = kind })
        end
      end
    end
  end

  -- ---- skill_config columns
  local function load_skill()
    local k = X.keys.skill
    if not k.key then return nil, k.err end
    local h, e = VRFW.rdbn.open(k.key)
    if not h then return nil, e end
    local li, le = h:list(SKILL_LIST)
    if li == nil then return nil, le end
    local s = { li = li }
    local names = {
      id = "skillID", key = "skillIDStr", ev = "eventID", evn = "eventIDName", fail = "failEventID", failn = "failEventIDName",
      name = "skillNameId", desc = "skillDescId", opt = "cmdOptIdx", flags = "skillEffectBitFlag", pmin = "power_min",
      pmax = "power_max", element = "element", color = "colorIdx", category = "category", growth = "growthType",
      foul = "foulRate", tp = "consumeTp", recast = "recastTime", ptype = "partnerType", telop = "telopInfoId",
    }
    -- the columns in the order the Rust builder resolved them (the first missing one is the error)
    local order = { "id", "key", "ev", "evn", "fail", "failn", "name", "desc", "opt", "flags", "pmin", "pmax", "element", "color",
      "category", "growth", "foul", "tp", "recast", "ptype" }
    for _, f in ipairs(order) do
      local c, ce = h:col(li, names[f])
      if c == nil then return nil, ce end
      s[f] = c
    end
    s.partners = {}
    for k2 = 1, 3 do
      local c, ce = h:col(li, "partner" .. k2)
      if c == nil then return nil, ce end
      s.partners[k2] = c
    end
    local c, ce = h:col(li, names.telop)
    if c == nil then return nil, ce end
    s.telop = c
    return h, s
  end

  -- ---- the build
  local out = { mods = {}, gentext = {}, created = {}, hidden = {}, deleted = {}, learned = {}, shop = {}, goal_events = {},
    ball_effects = {}, performer_elements = {}, event_variants = {}, handoffs = {}, move_fx = {}, keeper_scenes = {},
    aura_compat = {}, move_icons = {}, icons_ready = false, conflicts = {}, problems = {} }

  local files = {}
  for i, f in ipairs(input.files) do
    if not f.empty then files[#files + 1] = { f = f, i = i } end
  end
  table.sort(files, function(a, b)
    if a.f.load_index ~= b.f.load_index then return a.f.load_index < b.f.load_index end
    return a.i < b.i
  end)
  for i, x in ipairs(files) do
    files[i] = x.f
    local seen = false
    for _, m in ipairs(out.mods) do if m == x.f.mod then seen = true end end
    if not seen then out.mods[#out.mods + 1] = x.f.mod end
    X.load_index[x.f.mod] = x.f.load_index
  end
  X.files = files
  if #files == 0 and #X.anim_events == 0 then return out end

  local se
  S, se = load_skill()
  if not S then
    VRFW.log.error(se .. ": no technique data is built")
    return out
  end
  sc = se
  X.S, X.sc = S, sc

  for r = 0, S:len(sc.li) - 1 do
    local i = S:u32(sc.li, r, sc.id)
    if i ~= nil then X.used_ids[i] = true end
    local s = S:str(sc.li, r, sc.key)
    if s ~= nil then X.used_internal[s] = true end
    for _, c in ipairs({ sc.name, sc.desc }) do
      local t = S:u32(sc.li, r, c)
      if t ~= nil and t ~= 0 then X.used_text[t] = true end
    end
  end

  require("lib/technique_rules")(X)
  require("lib/technique_tables")(X)

  -- ---- fields
  local NUMBER_FIELDS = {
    { "power_min", "pmin", 0, 32767 }, { "power_max", "pmax", 0, 32767 }, { "tp", "tp", 0, 255 },
    { "growth", "growth", 0, 7 }, { "foul_rate", "foul", 0, 100 }, { "color", "color", 0, 9 },
  }
  -- the keys that set only run-time rules (no table cell)
  local RULE_KEYS = { "goal_event", "ball", "distance_falloff", "on_win_lock_opponent_move", "pe_sacrifice", "power_per_participant",
    "on_win_steal_tension", "trajectory", "split_shot", "ground_trail" }
  local TABLE_KEYS = { "power_min", "power_max", "element", "category", "tp", "recast", "range", "users", "partners", "growth",
    "foul_rate", "effect_flags", "color", "event", "fail_event", "telop", "icon", "ex" }

  local function dual_of(f) return f.vrfw and f.vrfw.DualElement or nil end

  -- true when the declaration only sets run-time rules: no table cell changes, the move is not «touched»
  local function only_goal_event(f)
    local any = dual_of(f) ~= nil or (f.vrfw ~= nil and f.vrfw.MoveEffect ~= nil) or (f.effect_variant ~= nil and #f.effect_variant > 0)
    for _, k in ipairs(RULE_KEYS) do if f[k] ~= nil then any = true end end
    if not any then return false end
    for _, k in ipairs(TABLE_KEYS) do if f[k] ~= nil then return false end end
    if not U.is_empty(f.text) or not U.is_empty(f.cells) then return false end
    return true
  end

  -- Apply `f` (the declaration of mod `m`) to move `id`. `what` names the target in notes.
  function X:apply(m, what, id, f, file_default, key, is_new)
    local errs = {}
    local function add(e) if e ~= nil then errs[#errs + 1] = e end end
    local function w(x) return what .. "." .. x end
    for _, nf in ipairs(NUMBER_FIELDS) do
      local v = f[nf[1]]
      if v ~= nil then
        if v < nf[3] or v > nf[4] then
          add(string.format("%s = %s: out of %d-%d", nf[1], int_str(v), nf[3], nf[4]))
        else
          add(self:set_skill(id, sc[nf[2]], v, m, w(nf[1])))
        end
      end
    end
    if f.effect_flags ~= nil then add(self:set_skill(id, sc.flags, f.effect_flags, m, w("effect_flags"))) end
    if f.element ~= nil then
      local el = vocab.element[f.element]
      add(self:set_skill(id, sc.element, el.value, m, w("element")))
      if f.color == nil then add(self:set_skill(id, sc.color, el.color, m, w("color (from the element)"))) end
    end
    if f.category ~= nil then add(self:set_skill(id, sc.category, vocab.category[f.category], m, w("category"))) end
    if f.range ~= nil then add(self:set_skill(id, sc.opt, vocab.range[f.range], m, w("range"))) end
    if f.recast ~= nil then
      local r = f.recast
      if r < 0 or r > 999 then
        add("recast = " .. tostring(r) .. ": out of 0-999 seconds")
      else
        local ri = self:skill_row(id)
        if ri ~= nil then
          self:claim("skill", id, sc.recast, m, tostring(r), w("recast"))
          local ok, e = S:set_f32(sc.li, ri, sc.recast, r)
          if ok == nil then add(e) end
        end
      end
    end
    if f.users ~= nil then
      local u = f.users
      if u < 1 or u > 4 then
        add("users = " .. int_str(u) .. ": 1 (solo) to 4")
      else
        add(self:set_skill(id, sc.ptype, u == 1 and 0 or u, m, w("users")))
      end
    end
    if f.partners ~= nil then
      local ps = f.partners
      if #ps > 3 then add(string.format("partners: %d given, at most 3", #ps)) end
      local users = f.users
      if users == nil then
        local t = self:skill_num(id, sc.ptype)
        if t ~= nil then users = math.max(t, 1) end
      end
      if users ~= nil and #ps > math.max(users - 1, 0) then
        add(string.format("partners: %d for a move of %s player(s) (users = …)", #ps, int_str(users)))
      end
      for k = 1, 3 do
        local v, skip = 0, false
        if ps[k] ~= nil then
          local c, e = self:chara_ref(idref_str(ps[k]), m)
          if c == nil then
            add(string.format("partners[%d]: %s", k - 1, e))
            skip = true
          else
            v = c
          end
        end
        if not skip then add(self:set_skill(id, sc.partners[k], v, m, w("partners"))) end
      end
    end
    -- cutscenes
    local cur_ev = (self:skill_num(id, sc.ev) or 0) % TWO32
    if f.event ~= nil then
      local name, e = self:event(m, what, f.event, cur_ev)
      if name == nil then
        add(e)
      else
        add(self:set_skill(id, sc.ev, VRFW.crc32(name), m, w("event")))
        add(self:set_skill_str(id, sc.evn, name, m, w("event")))
      end
    end
    if f.fail_event ~= nil then
      if lower(U.trim(f.fail_event)) == "none" then
        add(self:set_skill(id, sc.fail, 0, m, w("fail_event")))
        add(self:set_skill_str(id, sc.failn, nil, m, w("fail_event")))
      else
        local tpl = self:skill_num(id, sc.fail)
        if tpl == nil or tpl == 0 then tpl = cur_ev end
        local name, e = self:event(m, what, f.fail_event, tpl % TWO32)
        if name == nil then
          add(e)
        else
          add(self:set_skill(id, sc.fail, VRFW.crc32(name), m, w("fail_event")))
          add(self:set_skill_str(id, sc.failn, name, m, w("fail_event")))
        end
      end
    end
    if f.telop ~= nil then
      local src, e = self:tech_ref(idref_str(f.telop), m)
      if src == nil then
        add("telop: " .. e)
      else
        add(self:set_skill(id, sc.telop, self:skill_num(src, sc.telop) or 0, m, w("telop")))
      end
    end
    if f.icon ~= nil then
      local icon = idref_str(f.icon)
      local src, e = self:tech_ref(icon, m)
      if src == nil then
        add("icon: " .. e)
      else
        local s, d = self:item_row(src), self:item_row(id)
        if s ~= nil and d ~= nil then
          local t = self:item()
          local sheet, idx = t:int(s, IT.icon_sheet) or 0, t:int(s, IT.icon) or 0
          t:set(d, IT.icon_sheet, sheet)
          t:set(d, IT.icon, idx)
          self:claim("item", id, IT.icon, m, int_str(sheet) .. "/" .. int_str(idx), w("icon"))
        elseif s == nil then
          add("icon: `" .. icon .. "` has no item row")
        else
          add("icon: this move has no item row (manual)")
        end
      end
    end
    if not U.is_empty(f.text) then
      local d = norm_default(file_default, f.text)
      local n, ds = self:skill_num(id, sc.name) or 0, self:skill_num(id, sc.desc) or 0
      self:texts_of(m, what, key, n % TWO32, ds % TWO32, f.text, d, is_new)
    end
    if f.goal_event ~= nil then add(self:goal_event(m, what, id, f.goal_event)) end
    if f.ball ~= nil then add(self:ball(m, what, id, f.ball)) end
    if dual_of(f) ~= nil then add(self:dual_element_rule(m, what, id, dual_of(f))) end
    for _, v in ipairs(f.effect_variant or {}) do
      self.variant_decls[#self.variant_decls + 1] = { m = m, what = what, id = id, d = v }
    end
    for _, e in ipairs(self:mini_rules(m, what, id, f)) do add(e) end
    -- raw cells of the row, SKILL_EX pairs
    if not U.is_empty(f.cells) then
      local ri = self:skill_row(id)
      if ri ~= nil then
        for _, k in ipairs(U.keys(f.cells)) do
          local p, e = S:resolve(sc.li, k)
          if p == nil then
            add("cells." .. k .. ": " .. e)
          else
            self:claim("skill", id, p, m, U.show(f.cells[k]), w("cells." .. k))
          end
        end
        local ok, e = S:set_cells(sc.li, ri, f.cells)
        if ok == nil then add("cells: " .. e) end
      end
    end
    if f.ex ~= nil then
      local ok, e = self:set_ex(m, what, id, f.ex)
      if ok == nil then add("ex: " .. e) end
    end
    if not only_goal_event(f) then self.touched[id] = true end
    VRFW.sort(errs)
    local last
    for _, e in ipairs(errs) do
      if e ~= last then self:err(m, what .. ": " .. e) end
      last = e
    end
  end

  -- ---- new moves
  local function internal_valid(k)
    return #k > 3 and #k <= 32 and not k:find("[^a-z0-9_]")
  end

  function X:create(m, file, d, file_default)
    local key = need(VRFW.ids.own(m, d.name))
    if self.created[key] then E("`" .. key .. "` is declared twice (the first is kept)") end
    local base, be = self:tech_ref(idref_str(d.base), m)
    if base == nil then E("base: " .. be) end
    local bi = self:skill_row(base)
    local base_key = S:str(sc.li, bi, sc.key) or ""
    local category = d.category and vocab.category[d.category] or S:num(sc.li, bi, sc.category) or 1
    local bycat = vocab.by_category[category + 1] or vocab.by_category[1]
    local prefix = bycat.prefix
    -- ids (stable: the registry remembers them)
    local internal
    if d.key ~= nil then
      local k = U.trim(d.key)
      if not internal_valid(k) then E("key `" .. k .. "`: a-z 0-9 _ (like whs95000)") end
      local kid = VRFW.crc32(k)
      if self.used_internal[k] or self:skill_row(kid) ~= nil or (self.used_ids[kid] and not self:own_manual(kid)) then
        E("key `" .. k .. "` is already a move / item of the game or of another mod")
      end
      if k:sub(1, #prefix) ~= prefix then
        self:warn(m, string.format("%s: %s: key `%s` does not start with `%s` (the prefix of a %s move)", file, key, k, prefix, bycat.word))
      end
      internal = k
    else
      local n = VRFW.character.assign_name(key .. "#key", prefix .. "9", 10, 0, TWO32, self.used_internal, self.used_ids)
      internal = string.format("%s9%010.0f", prefix, n)
    end
    local id = VRFW.crc32(internal)
    -- text ids: pinned (`"base"` = the base's: shared texts; an id), else from the registry
    local function text_id(pin, col, tag)
      local v
      if pin == nil then
        v = VRFW.ids.assign(key .. "#" .. tag, self.used_text)
      elseif type(pin) == "number" then
        v = pin % TWO32
      elseif lower(U.trim(pin)) == "base" then
        v = S:u32(sc.li, bi, col) or 0
      else
        v = VRFW.ids.parse(pin)
      end
      self.used_text[v] = true
      return v
    end
    local t_name = text_id(d.name_text, sc.name, "name")
    local t_desc = text_id(d.desc_text, sc.desc, "desc")
    self.used_internal[internal] = true
    self.used_ids[id] = true
    -- skill_config: the base's row
    local row = S:copy_row(sc.li, bi)
    need(S:row_set(row, sc.id, id))
    S:row_str(row, sc.key, internal)
    need(S:row_set(row, sc.name, t_name))
    need(S:row_set(row, sc.desc, t_desc))
    -- its manual (item_config): `manual = false` none; the move's own row if present; else a clone of the base's
    local catalog
    if d.manual ~= false then
      local pin = type(d.manual) == "table" and d.manual or {}
      local own
      if self:own_manual(id) then own = self:item_row(id) end
      local src = own or self:item_row(base)
      if src ~= nil then
        local t = self:item()
        local cat
        -- a catalog number is a bit of the 8192-bit item-get flag: out-of-range numbers are replaced by the allocator
        if pin.catalog ~= nil and pin.catalog >= 0 and pin.catalog < CATALOG_LIMIT then
          local c = pin.catalog
          if own == nil and self.used_catalog[c] then self:info(string.format("%s: %s: manual catalog %s is also another item's", file, key, int_str(c))) end
          cat = c
        elseif pin.catalog ~= nil then
          self:warn(m, string.format("%s: %s: manual.catalog = %s: not a catalog number (0-%d): a free one is given", file, key, int_str(pin.catalog), CATALOG_LIMIT - 1))
          cat = need(self:manual_catalog(m, key))
        elseif own ~= nil then
          cat = t:int(src, IT.catalog) or 0
          if cat < 0 or cat >= CATALOG_LIMIT then
            self:info(string.format("%s: %s: its manual row has catalog %s (not 0-%d): a free one is given", file, key, int_str(cat), CATALOG_LIMIT - 1))
            cat = need(self:manual_catalog(m, key))
          end
        else
          cat = need(self:manual_catalog(m, key))
        end
        self.used_catalog[cat] = true
        local r = t:entry(src)
        r.values[IT.id + 1] = U.i32(id)
        r.values[IT.catalog + 1] = cat
        r.values[IT.key + 1] = internal
        r.values[IT.skill + 1] = U.i32(id)
        if pin.icon ~= nil then
          r.values[IT.icon_sheet + 1] = U.i32(pin.icon[1])
          r.values[IT.icon + 1] = U.i32(pin.icon[2])
        end
        for _, c in ipairs(U.keys(pin.cells or {})) do
          local s = U.trim(c):gsub("^#+", "")
          local ci = (s:match("^%d+$")) and tonumber(s) or nil
          if ci == nil then E("manual.cells: `" .. c .. "` is not a column index") end
          if ci >= #r.values then E("manual.cells: column " .. int_str(ci) .. " beyond the item row") end
          r.values[ci + 1] = U.i32(pin.cells[c])
        end
        if own ~= nil then
          if not P.row_eq(t:entry(own).values, r.values) then t:splice(own, own + 1, { r }) end
        else
          need(t:append_row(IT.row, r))
        end
        catalog = cat
      elseif type(d.manual) == "table" or d.manual == true then
        E("manual: the base " .. base_key .. " has no manual (item row) to clone")
      else
        self:info(string.format("%s: %s: the base %s has no manual (item row): the new move gets none either", file, key, base_key))
      end
    end
    -- the move exists from here on (nothing above left a half-made row)
    S:push(sc.li, row)
    local c = { key = key, mod_id = m, internal = internal, id = id, base = base_key, category = category, element = 0, event = "", catalog = catalog }
    self.created[key] = c
    self.created_by_id[id] = c
    local what = file .. ": " .. key
    local fd = d.default_lang or file_default
    self:apply(m, what, id, d, fd, key, true)
    local has_name = false
    for _, t in pairs(d.text or {}) do
      if t.name ~= nil and U.trim(t.name) ~= "" then has_name = true end
    end
    if not has_name and d.name_text == nil then
      self:warn(m, what .. ": no [technique.text.<lang>] name: the new move shows no name")
    else
      local missing = {}
      for _, l in ipairs(VRFW.lang.list()) do
        local found = false
        for k, t in pairs(d.text or {}) do
          if (VRFW.lang.norm(k) == l or k == "all") and t.name ~= nil then found = true end
        end
        if not found then missing[#missing + 1] = l end
      end
      if #missing > 0 and not (d.text and d.text.all) then
        self:report(m, "info", string.format("%s: name not written in %s (the text engine uses the fallback language)", what, table.concat(missing, ", ")))
      end
    end
    return true
  end

  -- ---- aura commands (edits)
  function X:aura_edit(m, file, a, file_default)
    local linked
    if a.technique ~= nil then
      local l, e = self:tech_ref(idref_str(a.technique), m)
      if l == nil then E("technique: " .. e) end
      linked = l
    end
    local t = need(self:aura(), "aura_skill_config not available")
    local s = U.trim(idref_str(a.aura))
    local row = t:find_text(AU.row, AU.key, s) or t:find(AU.row, AU.id, VRFW.ids.parse(s))
    if row == nil then E("aura command `" .. s .. "` is not in aura_skill_config (write its key like wks00020, or its id)") end
    local id = t:uint(row, AU.id) or 0
    local name, desc = t:uint(row, AU.name) or 0, t:uint(row, AU.desc) or 0
    local what = file .. ": aura " .. s
    local sets = {}
    for _, x in ipairs({ { a.power_min, AU.power_min, "power_min" }, { a.power_max, AU.power_max, "power_max" } }) do
      if x[1] ~= nil then
        if x[1] < 0 or x[1] > 32767 then E(x[3] .. " = " .. int_str(x[1]) .. ": out of 0-32767") end
        sets[#sets + 1] = x
      end
    end
    if linked ~= nil then sets[#sets + 1] = { U.i32(linked), AU.skill, "technique" } end
    for _, x in ipairs(sets) do
      self:claim("aura", id, x[2], m, int_str(x[1]), what .. "." .. x[3])
      t:set(row, x[2], U.i32(x[1]))
    end
    need(self:aura_rest(m, what, id, a.cells or {}, { a.unique_effects, a.effects, a.charas }))
    if a.compatible ~= nil then self:compat_rule(m, what, id, s, a.compatible) end
    if not U.is_empty(a.text) then
      local d = norm_default(a.default_lang or file_default, a.text)
      self:texts_of(m, what, m .. ".aura." .. s, name, desc, a.text, d, false)
    end
    return true
  end

  -- `compatible = [...]` of aura command `id`
  function X:compat_rule(m, what, id, key, list)
    local charas, cards, card_charas = {}, {}, {}
    for _, r in ipairs(list) do
      local tx = idref_str(r)
      local c = self:chara_ref(tx, m)
      if c ~= nil then
        if not U.contains(charas, c) then charas[#charas + 1] = c end
      else
        local pid = idref_id(r)
        local card
        if pid ~= 0 then
          local p = self:param()
          if p then
            local row = p:find(PARAM_ROW, CP.id, pid)
            if row ~= nil then card = p:uint(row, CP.chara) or 0 end
          end
        end
        if card ~= nil then
          if not U.contains(cards, pid) then
            cards[#cards + 1] = pid
            card_charas[#card_charas + 1] = card
          end
        else
          self:err(m, what .. ".compatible: `" .. tx .. "` is neither a character (chara_base key / id, <mod>.<name>) nor a card (chara_param id): left out")
        end
      end
    end
    local rule = #list > 0 and { charas = charas, cards = cards, card_charas = card_charas } or false
    local prev = self.compat[id]
    if prev and prev.mod_id ~= m then
      local same = (prev.rule == false and rule == false) or (prev.rule and rule and P.row_eq(prev.rule.charas, rule.charas)
        and P.row_eq(prev.rule.cards, rule.cards) and P.row_eq(prev.rule.card_charas, rule.card_charas))
      if not same then
        local line = what .. ".compatible: " .. m .. " replaces the rule of " .. prev.mod_id
        self.conflicts[#self.conflicts + 1] = line
        VRFW.log.warn(line)
      end
    end
    self.compat[id] = { key = key, mod_id = m, rule = rule }
  end

  -- ---- removals
  function X:strip_learn(id)
    local t = self:param()
    if not t then return 0 end
    local n = 0
    for _, i in ipairs(t:rows(PARAM_ROW)) do
      for k = 0, CP.move_slots - 1 do
        local c = CP.moves + 2 * k
        if t:uint(i, c) == id then
          t:set(i, c, 0)
          t:set(i, c + 1, 0)
          n = n + 1
        end
      end
    end
    return n
  end

  function X:remove(m, file, r)
    local id = need(self:tech_ref(idref_str(r.technique), m))
    local label = self:label(id)
    local what = file .. ": remove " .. label
    local by = {}
    for _, c in pairs(self.claims) do
      if c.tab == "skill" and c.row == id and c.by ~= m then by[c.by] = true end
    end
    local touched = U.keys(by)
    if #touched > 0 then
      local msg = string.format("technique conflict: %s: mod %s removes it and %s edit(s) it (the removal wins)", what, m, table.concat(touched, ", "))
      self:warn(m, msg)
      self.conflicts[#self.conflicts + 1] = msg
    end
    local stripped = self:strip_learn(id)
    if (r.mode or "hide") == "hide" then
      self.hidden[id] = true
      self:report(m, "info", string.format("%s: hidden (%d learn-list slot(s) cleared; the data stays)", what, stripped))
    else
      local ri = self:skill_row(id)
      if ri ~= nil then S:remove(sc.li, ri) end
      local ii = self:item_row(id)
      if ii ~= nil then need(self:item():remove_row(IT.row, ii)) end
      self.deleted[id] = true
      self.hidden[id] = nil
      self.touched[id] = nil
      local c = self.created_by_id[id]
      if c then
        for _, g in pairs(self.texts) do
          local keep = {}
          for _, x in ipairs(g.rows) do if x.key ~= c.key then keep[#keep + 1] = x end end
          g.rows = keep
        end
        self.created[c.key] = nil
        self.created_by_id[id] = nil
        self.removed_keys[c.key] = true
        self:report(m, "info", what .. ": " .. c.key .. " is not created")
      else
        self:warn(m, string.format("%s: deleted from skill_config / item_config (%d learn-list slot(s) cleared; team loadouts or saves that use it may break: `mode = \"hide\"` keeps the data)", what, stripped))
      end
    end
    return true
  end

  -- ---- learn lists
  function X:learn(m, file, l)
    local id = need(self:tech_ref(idref_str(l.technique), m))
    local what = string.format("%s: learn %s by %s", file, self:label(id), idref_str(l.character))
    if self.hidden[id] then self:warn(m, what .. ": the move is hidden by a [[remove]] (learnt anyway)") end
    if l.level < 1 or l.level > 99 then E("level = " .. int_str(l.level) .. ": 1-99") end
    if l.slot ~= nil and (l.slot < 1 or l.slot > CP.move_slots) then E(string.format("slot = %s: 1-%d", int_str(l.slot), CP.move_slots)) end
    local chara = need(self:chara_ref(idref_str(l.character), m))
    local t = need(self:param(), "chara_param not available")
    local cards = {}
    if l.card ~= nil then
      local cid = idref_id(l.card)
      local i = t:find(PARAM_ROW, CP.id, cid)
      if i == nil then E("card " .. idref_str(l.card) .. " not in chara_param") end
      if t:uint(i, CP.chara) ~= chara then E("card " .. idref_str(l.card) .. " belongs to another character") end
      cards = { cid }
    else
      for _, i in ipairs(t:find_all(PARAM_ROW, CP.chara, chara)) do
        local x = t:uint(i, CP.id)
        if x ~= nil then cards[#cards + 1] = x end
      end
    end
    if #cards == 0 then E("the character has no card (chara_param row)") end
    for _, card in ipairs(cards) do
      local i = t:find(PARAM_ROW, CP.id, card)
      local slots = {}
      for k = 0, CP.move_slots - 1 do slots[k + 1] = t:uint(i, CP.moves + 2 * k) or 0 end
      local k
      if l.slot ~= nil then
        k = l.slot - 1
      else
        for x = 1, #slots do if slots[x] == id then k = x - 1 break end end
        if k == nil then
          for x = 1, #slots do if slots[x] == 0 then k = x - 1 break end end
        end
      end
      if k == nil then
        local msg = string.format("%s (card %s): the 9 learn slots are used: not learnt on this card (give `card` + `slot = 1-9` to replace one)", what, hex(card))
        if l.card ~= nil then self:err(m, msg) else self:warn(m, msg) end
      else
        if (t:int(i, BOARD_COL) or 0) ~= 0 then
          self:warn(m, string.format("%s (card %s): the card has its own ability board (chara_param col 10): the move shows on it only if the board lists it; the learn list counts for the card as an opponent / NPC", what, hex(card)))
        elseif k >= 6 then
          self:report(m, "info", string.format("%s (card %s): slot %d is read by the ability board only (opponent / NPC teams use slots 1-6)", what, hex(card), k + 1))
        end
        local old = slots[k + 1]
        if old ~= 0 and old ~= id then
          self:report(m, "info", string.format("%s (card %s): slot %d replaces %s", what, hex(card), k + 1, self:label(old)))
        end
        local c = CP.moves + 2 * k
        self:claim("param", card, c, m, string.format("%.0f@%s", id, int_str(l.level)), string.format("%s (card %s) slot %d", what, hex(card), k + 1))
        t:set(i, c, U.i32(id))
        t:set(i, c + 1, U.i32(l.level))
        local keep = {}
        for _, x in ipairs(self.learned) do
          if not (x.card == card and x.slot == k + 1) then keep[#keep + 1] = x end
        end
        keep[#keep + 1] = { technique = id, card = card, slot = k + 1, level = l.level, mod_id = m }
        self.learned = keep
      end
    end
    return true
  end

  -- ---- the steps
  -- item ids + catalog numbers in use (every item list shares both spaces)
  local any_new = false
  for _, f in ipairs(files) do
    if #(f.value.technique or {}) > 0 then any_new = true end
  end
  if any_new then
    local t = X:item()
    if t then
      for i = 0, t:len() - 1 do
        local n = t:name(i) or ""
        if n:sub(1, 5) == "ITEM_" and n:sub(-5) == "_INFO" and t:width(i) > IT.catalog then
          local v = t:int(i, 0)
          if v ~= nil then X.used_ids[v % TWO32] = true end
          local c = t:int(i, IT.catalog)
          if c ~= nil then X.used_catalog[c] = true end
        end
      end
    end
  end
  -- model checks (draw priority) of the mods whose declarations bring animations
  for _, f in ipairs(files) do
    local animates = #(f.value.technique or {}) > 0
    for _, e in ipairs(f.value.edit or {}) do
      if e.event ~= nil or e.fail_event ~= nil then animates = true end
    end
    if animates and not X.models_checked[f.mod] then
      X.models_checked[f.mod] = true
      for _, p in ipairs(VRFW.technique.model_priorities(f.mod)) do X:err(f.mod, p) end
    end
  end
  -- 1. new moves (`order` first, lower first, then by name)
  for _, f in ipairs(files) do
    local news = {}
    for i, d in ipairs(f.value.technique or {}) do news[#news + 1] = { d = d, i = i } end
    table.sort(news, function(a, b)
      local ao, bo = a.d.order, b.d.order
      if (ao == nil) ~= (bo == nil) then return ao ~= nil end
      if ao ~= nil and ao ~= bo then return ao < bo end
      if a.d.name ~= b.d.name then return VRFW.less(a.d.name, b.d.name) end
      return a.i < b.i
    end)
    for _, x in ipairs(news) do
      local ok, e = try(X.create, X, f.mod, f.file, x.d, f.value.default_lang)
      if ok == nil then X:err(f.mod, string.format("%s: technique `%s`: %s (not created)", f.file, x.d.name, e)) end
    end
  end
  -- 2. edits
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.edit or {}) do
      local id, e = X:tech_ref(idref_str(d.technique), f.mod)
      if id == nil then
        X:err(f.mod, f.file .. ": edit: " .. e .. " (skipped)")
      else
        local what = f.file .. ": edit " .. X:label(id)
        local c = X.created_by_id[id]
        local key = c and c.key or (f.mod .. ".edit." .. X:label(id))
        X:apply(f.mod, what, id, d, d.default_lang or f.value.default_lang, key, c ~= nil)
      end
    end
  end
  -- 3. aura commands: new ones first, then the edits
  for _, f in ipairs(files) do
    for _, a in ipairs(f.value.aura_command or {}) do
      local ok, e = try(X.aura_new, X, f.mod, f.file, a)
      if ok == nil then X:err(f.mod, string.format("%s: aura_command %s: %s (skipped)", f.file, a.key, e)) end
    end
  end
  for _, f in ipairs(files) do
    for _, a in ipairs(f.value.aura or {}) do
      local ok, e = try(X.aura_edit, X, f.mod, f.file, a, f.value.default_lang)
      if ok == nil then X:err(f.mod, string.format("%s: aura %s: %s (skipped)", f.file, idref_str(a.aura), e)) end
    end
  end
  -- 3b. keshin changes, override moves, passive effect definitions, boards, texts
  for _, f in ipairs(files) do
    local m, file = f.mod, f.file
    for _, d in ipairs(f.value.aura_change or {}) do
      local ok, e = try(X.aura_change, X, m, file, d)
      if ok == nil then X:err(m, string.format("%s: aura_change %s: %s (skipped)", file, idref_str(d.aura), e)) end
    end
    for _, d in ipairs(f.value["override"] or {}) do
      local ok, e = try(X.override_, X, m, file, d)
      if ok == nil then X:err(m, string.format("%s: override %s: %s (skipped)", file, idref_str(d.technique), e)) end
    end
    for _, d in ipairs(f.value.passive_effect_def or {}) do
      local ok, e = try(X.passive_effect_def, X, m, file, d)
      if ok == nil then X:err(m, string.format("%s: passive_effect_def %s: %s (skipped)", file, d.key, e)) end
    end
    for _, d in ipairs(f.value.board or {}) do
      local ok, e = try(X.board, X, m, file, d)
      if ok == nil then X:err(m, string.format("%s: board %s: %s (skipped)", file, idref_str(d.board), e)) end
    end
    for _, d in ipairs(f.value.text or {}) do
      local ok, e = try(X.text_row, X, m, file, d, f.value.default_lang)
      if ok == nil then X:err(m, string.format("%s: text %s: %s (skipped)", file, idref_str(d.id), e)) end
    end
  end
  -- 3c. chain overrides (after every mod's overrides and SKILL_EX edits)
  local chains = X.chains
  X.chains = {}
  for _, c in ipairs(chains) do
    if not X.deleted[c.id] then
      local ok, e = try(X.override_chain, X, c.m, c.what, c.id, c.any_order)
      if ok == nil then X:err(c.m, c.what .. ": " .. e .. " (left as it was)") end
    end
  end
  -- passives: edits of every mod, the twins rule, new passives, twins of new passives
  local function passive_step(f, new)
    for _, d in ipairs(f.value.passive or {}) do
      if (d.key ~= nil) == new then
        local ok, e = try(X.passive, X, f.mod, f.file, d)
        if ok == nil then
          local who = d.passive ~= nil and idref_str(d.passive) or d.key or ""
          X:err(f.mod, string.format("%s: passive %s: %s (skipped)", f.file, who, e))
        end
      end
    end
  end
  for _, f in ipairs(files) do passive_step(f, false) end
  local later = {}
  for fi, f in ipairs(files) do
    for i, d in ipairs(f.value.passive_twins or {}) do
      local r, e = try(X.passive_twins, X, f.mod, f.file, d, nil)
      if r == nil then
        X:err(f.mod, string.format("%s: passive_twins #%d: %s (skipped)", f.file, i, e))
      else
        X:info(string.format("%s: passive_twins #%d: %d twin(s) (%s…, x%s)", f.file, i, r.n, d.prefix, tostring(d.scale)))
        if #r.rest > 0 then later[#later + 1] = { fi = fi, i = i, rest = r.rest } end
      end
    end
  end
  for _, f in ipairs(files) do passive_step(f, true) end
  for _, l in ipairs(later) do
    local f = files[l.fi]
    local r, e = try(X.passive_twins, X, f.mod, f.file, f.value.passive_twins[l.i], l.rest)
    if r == nil then X:err(f.mod, string.format("%s: passive_twins #%d: %s (skipped)", f.file, l.i, e)) end
  end
  X:compact_tables()
  -- 4. removals
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.remove or {}) do
      local ok, e = try(X.remove, X, f.mod, f.file, d)
      if ok == nil then X:err(f.mod, string.format("%s: remove %s: %s (skipped)", f.file, idref_str(d.technique), e)) end
    end
  end
  -- 5. learn lists
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.learn or {}) do
      local ok, e = try(X.learn, X, f.mod, f.file, d)
      if ok == nil then X:err(f.mod, string.format("%s: learn %s by %s: %s (skipped)", f.file, idref_str(d.technique), idref_str(d.character), e)) end
    end
  end
  -- 6. shop offers (for the item type)
  for _, f in ipairs(files) do
    for _, s in ipairs(f.value.shop or {}) do
      local id, e = X:tech_ref(idref_str(s.technique), f.mod)
      if id == nil then
        X:err(f.mod, string.format("%s: shop %s: %s (skipped)", f.file, idref_str(s.technique), e))
      else
        if X.hidden[id] then X:warn(f.mod, string.format("%s: shop %s: the move is hidden by a [[remove]]", f.file, idref_str(s.technique))) end
        X.offers[#X.offers + 1] = { technique = id, reference = idref_str(s.technique), mod_id = f.mod, shop = s.shop, price = s.price,
          currency = s.currency, stock = s.stock }
      end
    end
  end
  if #X.offers > 0 then
    X:info(string.format("%d shop offer(s) handed to the item engine (this engine builds no shop rows)", #X.offers))
  end
  -- 7. keeper-gauge scenes (a run-time rule)
  local keeper = {}
  for _, f in ipairs(files) do
    for i, d in ipairs(f.value.keeper_scene or {}) do
      local p, e = try(X.keeper_scene, X, f.mod, string.format("%s: keeper_scene #%d", f.file, i), d)
      if p == nil then
        X:err(f.mod, string.format("%s: keeper_scene #%d: %s (skipped)", f.file, i, e))
      else
        local dup = false
        for _, k in ipairs(keeper) do
          if k.save == p.save and k.goal == p.goal and k.max_gauge_damage == p.max_gauge_damage and k.last_minutes == p.last_minutes
            and P.row_eq(k.keeper_save, p.keeper_save) then dup = true end
        end
        if dup then
          X:info(string.format("%s: keeper_scene #%d: the same pair is already declared (left out)", f.file, i))
        else
          keeper[#keeper + 1] = p
        end
      end
    end
  end
  if #keeper > 0 then
    local list = {}
    for _, k in ipairs(keeper) do list[#list + 1] = X.describe_keeper(k) end
    X:info(string.format("keeper scenes: %d pair(s) after the retail ones: %s", #keeper, table.concat(list, ", ")))
  end
  -- 8. event environments
  for _, f in ipairs(files) do
    for i, d in ipairs(f.value.event_env or {}) do
      local what = string.format("%s: event_env #%d (%s)", f.file, i, d.event)
      local ok, e = try(X.event_env, X, f.mod, what, d)
      if ok == nil then X:err(f.mod, what .. ": " .. e .. " (skipped)") end
    end
  end
  -- 9. the anim engine's events no declaration named
  X:anim_env_rows()

  -- ---- final checks
  local function finish()
    -- power order, category <-> event group
    for _, id in ipairs(U.keys(X.touched)) do
      local ri = X:skill_row(id)
      if ri ~= nil then
        local lo, hi = S:num(sc.li, ri, sc.pmin) or 0, S:num(sc.li, ri, sc.pmax) or 0
        local owner = ""
        for _, c in pairs(X.claims) do
          if c.tab == "skill" and c.row == id then owner = c.by break end
        end
        local label = X:label(id)
        if lo > hi then X:warn(owner, string.format("%s: power_min %s > power_max %s", label, int_str(lo), int_str(hi))) end
        local cat = S:num(sc.li, ri, sc.category) or 0
        local ev = S:str(sc.li, ri, sc.evn) or ""
        local bc = vocab.by_category[cat + 1]
        local g = bc and bc.group
        -- the group check only where a mod set the category or the cutscene, or made the move
        local set_by_mod = X.created_by_id[id] ~= nil
        for _, col in ipairs({ sc.category, sc.ev, sc.evn }) do
          if X.claims["skill|" .. string.format("%.0f", id) .. "|" .. tostring(col)] ~= nil then set_by_mod = true end
        end
        if g ~= nil and set_by_mod and ev ~= "" and ev:sub(1, #g) ~= g then
          X:warn(owner, string.format("%s: a %s move with the cutscene %s (a %s_ event is expected: the animation may not fit the duel)", label, bc.word, ev, g))
        end
      end
    end
    -- skill_by_event_id: one row per move in both lists (event 0 when none), like retail
    local rows = {}
    for r = 0, S:len(sc.li) - 1 do
      local id = S:u32(sc.li, r, sc.id)
      if id ~= nil then rows[#rows + 1] = { id, S:u32(sc.li, r, sc.ev) or 0, S:u32(sc.li, r, sc.fail) or 0 } end
    end
    local want, nwant = {}, 0
    for _, x in ipairs(rows) do
      if X.touched[x[1]] or X.created_by_id[x[1]] then
        want[x[1]] = { x[2], x[3] }
        nwant = nwant + 1
      end
    end
    local deleted = U.keys(X.deleted)
    if nwant == 0 and #deleted == 0 then return end
    local t = X:byev()
    if not t then return end
    local shared = {}
    local li = t:list(BYEV_LIST)
    if li ~= nil and next(X.created_by_id) ~= nil then
      local ce, cs = t:col(li, "eventId"), t:col(li, "skillId")
      if ce ~= nil and cs ~= nil then
        local by_event = {}
        for r = 0, t:len(li) - 1 do
          local e, s = t:u32(li, r, ce), t:u32(li, r, cs)
          if e ~= nil and s ~= nil and e ~= 0 then by_event[e] = s end
        end
        for _, id in ipairs(U.keys(want)) do
          local ev = want[id][1]
          local keep = not X.created_by_id[id] or ev == 0 or by_event[ev] == nil or by_event[ev] == id
          if not keep then
            want[id] = nil
            shared[#shared + 1] = id
          end
        end
      end
    end
    local is_deleted = X.deleted
    for _, x in ipairs({ { BYEV_LIST, false }, { BYEV_FAIL_LIST, true } }) do
      local l = t:list(x[1])
      if l ~= nil then
        local ce, cs = t:col(l, "eventId"), t:col(l, "skillId")
        if ce ~= nil and cs ~= nil then
          local r = 0
          while r < t:len(l) do
            local s = t:u32(l, r, cs)
            if s ~= nil and is_deleted[s] then t:remove(l, r) else r = r + 1 end
          end
          -- in skill_config row order
          for _, row in ipairs(rows) do
            local wv = want[row[1]]
            if wv then
              local id = row[1]
              local e = x[2] and wv[2] or wv[1]
              local fr = t:find(l, cs, id)
              if fr ~= nil then
                t:set_num(l, fr, ce, e)
              elseif t:len(l) > 0 then
                local nr = t:copy_row(l, 0)
                if t:row_set(nr, ce, e) and t:row_set(nr, cs, id) then t:push(l, nr) end
              end
            end
          end
        end
      end
    end
    if #shared > 0 then
      local names = {}
      for _, id in ipairs(shared) do names[#names + 1] = X:label(id) end
      X:info(string.format("%d new move(s) keep their base's cutscene: no event index rows (%s)", #names, table.concat(names, ", ")))
    end
  end
  finish()

  -- ---- run-time rules
  local goals = X:goal_rules()
  if #goals > 0 then
    local list, nv = {}, 0
    for _, g in ipairs(goals) do
      if g.variant_of == nil then list[#list + 1] = string.format("%s -> %s (%s)", g.key, g.event, g.mod_id) else nv = nv + 1 end
    end
    X:info(string.format("goal events: %s (+ %d _or/_mm variant id(s))", table.concat(list, ", "), nv))
  end
  local balls = X:ball_rules()
  if #balls > 0 then
    local list, nv = {}, 0
    for _, b in ipairs(balls) do
      if b.variant_of == nil then list[#list + 1] = X.describe_ball(b) else nv = nv + 1 end
    end
    X:info(string.format("ball effects: %s (+ %d _or/_mm variant id(s))", table.concat(list, ", "), nv))
  end
  local performer_rules = X:performer_rules()
  if #performer_rules > 0 then
    local nv = 0
    for _, r in ipairs(performer_rules) do if r.variant_of ~= nil then nv = nv + 1 end end
    X:info(string.format("dual elements: %d rule(s) (+ %d _or/_mm variant id(s))", #performer_rules - nv, nv))
  end
  local move_fx = X:move_fx_rules()
  if #move_fx > 0 then
    local nv = 0
    for _, r in ipairs(move_fx) do if r.variant_of ~= nil then nv = nv + 1 end end
    X:info(string.format("move mini-effects: %d move(s) (+ %d _or/_mm variant id(s))", #move_fx - nv, nv))
  end
  local event_variants = X:event_variants()
  local handoffs = X:handoffs(files, event_variants)
  if #handoffs > 0 then
    local list = {}
    for _, h in ipairs(handoffs) do list[#list + 1] = string.format("%s: %s after [%s] -> %s", h.key, h.event, table.concat(h.after, ", "), h.handoff) end
    X:info("hand-off scenes: " .. table.concat(list, "; "))
  end

  -- ---- outputs
  -- texts: groups by (mod, default language) in byte order (no default first), then stable by load order
  local gks = U.keys(X.texts)
  local glist = {}
  for i, k in ipairs(gks) do
    local g = X.texts[k]
    if #g.rows > 0 then glist[#glist + 1] = { g = g, pos = i, li = X.load_index[g.mod] or 0 } end
  end
  table.sort(glist, function(a, b)
    if a.li ~= b.li then return a.li < b.li end
    return a.pos < b.pos
  end)
  local ntext = 0
  for _, x in ipairs(glist) do
    local texts = {}
    for _, r in ipairs(x.g.rows) do texts[#texts + 1] = r.t end
    ntext = ntext + #texts
    out.gentext[#out.gentext + 1] = { mod_id = x.g.mod, load_index = x.li, default_lang = x.g.default, texts = texts }
  end
  -- final element / event / category of the creations
  local ckeys = U.keys(X.created)
  for _, k in ipairs(ckeys) do
    local c = X.created[k]
    c.element = X:skill_num(c.id, sc.element) or 0
    c.category = X:skill_num(c.id, sc.category) or 0
    c.event = X:skill_str(c.id, sc.evn) or ""
    out.created[#out.created + 1] = c
  end
  local nhidden, ndeleted = #U.keys(X.hidden), #U.keys(X.deleted)
  X:info(string.format("%d mod(s) with techniques (%s): %d new move(s), %d text row(s) for the text engine, %d learn-list slot(s), %d hidden, %d deleted",
    #out.mods, table.concat(out.mods, ", "), #ckeys, ntext, #X.learned, nhidden, ndeleted))
  out.conflicts = X.conflicts
  out.problems = X.problems
  out.learned = X.learned
  out.shop = X.offers
  out.goal_events = goals
  out.ball_effects = balls
  out.performer_elements = performer_rules
  out.event_variants = event_variants
  out.handoffs = handoffs
  out.move_fx = move_fx
  out.keeper_scenes = keeper
  for _, id in ipairs(U.keys(X.compat)) do
    local c = X.compat[id]
    if c.rule then
      out.aura_compat[#out.aura_compat + 1] = { aura = id, key = c.key, mod_id = c.mod_id, charas = c.rule.charas, cards = c.rule.cards,
        card_charas = c.rule.card_charas }
    end
  end
  if #out.aura_compat > 0 then
    local list = {}
    for _, c in ipairs(out.aura_compat) do list[#list + 1] = string.format("%s (%d character(s), %d card(s))", c.key, #c.charas, #c.cards) end
    X:info(string.format("%d aura command(s) with a `compatible` list: %s", #out.aura_compat, table.concat(list, ", ")))
  end
  out.move_icons = X:move_icons()
  out.icons_ready = true
  out.hidden = U.keys(X.hidden)
  out.deleted = U.keys(X.deleted)
  return out
end
