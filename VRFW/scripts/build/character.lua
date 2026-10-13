-- Build script of the type `character` (docs/framework/build-scripts.md, docs/framework/types/character.md,
-- docs/app/character-engine.md §4): every active mod's character declarations (load order) -> chara_base /
-- chara_param / chara_model rows, the office rows of shop_config, the texts of the creations for the text type, the
-- recruit conditions, the celebration claims, the trait tags and the pre-evolved moves.
--
-- Order: (0) the EVT layout (`param_columns`), (1) every mod's NEW characters (sorted by name inside a mod: the ids do
-- not depend on the file order), (2) every [[edit]], (3) every `delete_cards` and [[remove]], (4) every [[recruit]]
-- (and the inline [character.recruit]), (5) trait tags, (6) pre-evolved moves, then the office rows and the declared
-- row order; each in load order. A cell two mods set to different values is a conflict: noted, the mod that loads
-- later wins.
--
-- Native (Rust, crates/plugins/character_engine): the `[VRFW.Level]` tables, the learn-level rule (this script
-- returns the cards that declare learn levels), the face icons (this script returns which icon each new character
-- copies) and the transform links.
--
-- input = { files = { { file, mod, load_index, empty, no_characters, value = <characters file> } } (every file, reading
--           order), rarity = <the rarity set>, vocab = { element, element_words, position, gender, growth },
--           consts = { prefixes, chara_text, max_req, learn_slots, learn_max, layout_v2, shop_index_space,
--           shop_index_limit, shop_legacy_from, office_tag } }
-- returns { created, recruits, hidden, conflicts, gentext, celebrations, traits, move_grades, icons, learn_cards }
-- (character_engine::script::Scripted).

local U = require "lib/util"
local C = require "lib/character_cols"
local O = require "lib/character_office"

local BASE_ROW = "CHARA_BASE_INFO"
local BASE_REF = "CHARA_BASE_INFO_REF_BATTLE"
local PARAM_ROW = "CHARA_PARAM_INFO"
local MODEL_ROW = "CHARA_MODEL_INFO"
-- slots of a card's own passives (chara_param own_passive_1..5)
local OWN_PASSIVES = 5
-- the key stat of each position (index into stat_kick..: GK agility, FW kick, MF intelligence, DF pressure)
local KEY_STAT = { [1] = 6, [2] = 0, [3] = 5, [4] = 3 }
-- Lv200 stats (chara_param column, declaration key), in the engine's order
local STAT_CELLS = {
  { "stat_kick", "kick" }, { "stat_control", "control" }, { "stat_technique", "technique" }, { "stat_pressure", "pressure" },
  { "stat_physical", "physical" }, { "stat_intelligence", "intelligence" }, { "stat_agility", "agility" },
  { "stat_speed", "speed" }, { "stat_luck", "luck" }, { "stat_freedom", "freedom" },
}
-- the game's own stat modifiers (mod_kick.. in this order)
local MOD_STATS = { "kick", "control", "technique", "pressure", "physical", "agility", "intelligence" }

local int_str, perr = O.int_str, O.perr

-- Rust `{}` of an IdRef (a number as written, or the string)
local function idref_str(x)
  if type(x) == "number" then return int_str(x) end
  return tostring(x)
end

-- a declared cell as a table value (ints wrap to the game's i32)
local function cell_value(c)
  if type(c) == "number" then return U.i32(c) end
  return c
end

-- the claim text of a cell value
local function vfmt(v)
  if type(v) == "number" then return int_str(U.i32(v)) end
  if type(v) == "string" then return 'Some("' .. v .. '")' end
  return "None"
end

local function round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

local function valid_word(s)
  return #s > 0 and #s <= 48 and not s:find("[^a-z0-9_]")
end

-- a celebration id `<mod>.<name>` (lower case)
local function valid_celebration(k)
  local m, n = k:match("^([^.]*)%.(.*)$")
  if not m then return false end
  local ok = function(s) return #s > 0 and not s:find("[^a-z0-9_]") end
  return ok(m) and ok(n)
end

-- a trait tag in its canonical form (trimmed, lower case); nil when it is not `a-z 0-9 _ . -`
local function norm_trait(s)
  local t = U.trim(s):lower()
  if #t > 0 and #t <= 64 and not t:find("[^a-z0-9_%.%-]") then return t end
  return nil
end

local function same_list(a, b)
  if #a ~= #b then return false end
  for k = 1, #a do
    if a[k] ~= b[k] then return false end
  end
  return true
end

-- stable sort of `list` by `less`
local function stable_sort(list, less)
  local v = {}
  for k, x in ipairs(list) do v[k] = { x = x, k = k } end
  table.sort(v, function(a, b)
    if less(a.x, b.x) then return true end
    if less(b.x, a.x) then return false end
    return a.k < b.k
  end)
  local out = {}
  for k, x in ipairs(v) do out[k] = x.x end
  return out
end

-- Index (0..7 of stat_kick..stat_speed) of the strongest gameplay stat: highest, then the position's key stat, then
-- engine order. Same rule as research/scripts/stats_99_to_200.py.
local function best_stat_index(v, position)
  local best = v[0]
  for k = 1, 7 do
    if v[k] > best then best = v[k] end
  end
  local key = KEY_STAT[position]
  if key and v[key] == best then return key end
  for k = 0, 7 do
    if v[k] == best then return k end
  end
  return 0
end

-- ------------------------------------------------------------------------------------------------- rarities

-- The rarity set (rarity type): `find` by key or unique short id, `of_card` by col 41 value.
local function rarity_set(set)
  local R = { list = set.rarities or {}, removed = set.removed or {} }
  function R.find(id)
    id = U.trim(id)
    for _, r in ipairs(R.list) do
      if r.key == id then return r end
    end
    local short = {}
    for _, r in ipairs(R.list) do
      if r.id == id then short[#short + 1] = r end
    end
    if #short == 1 then return short[1] end
    if #short == 0 then
      local why = ""
      for _, x in ipairs(R.removed) do
        if x[1] == id or x[1]:match("([^.]*)$") == id then
          why = " (`" .. x[1] .. "` was removed by mod " .. x[2] .. ")"
          break
        end
      end
      local keys = {}
      for _, r in ipairs(R.list) do keys[#keys + 1] = r.key end
      return nil, "no enabled mod provides the rarity `" .. id .. "`" .. why .. "; available: " .. table.concat(keys, ", ")
    end
    local keys = {}
    for _, r in ipairs(short) do keys[#keys + 1] = r.key end
    return nil, "rarity `" .. id .. "` is ambiguous: " .. table.concat(keys, ", ") .. " (write the full key)"
  end
  -- the rarity of a card of col 41 = `value` (no frame): the value's default, then the first of that value
  function R.of_card(value)
    local by = {}
    for _, r in ipairs(R.list) do
      local has = r.value == value
      for _, a in ipairs(r.also or {}) do
        if a == value then has = true end
      end
      if has then by[#by + 1] = r end
    end
    for _, r in ipairs(by) do
      if r.default_for_value then return r end
    end
    return by[1]
  end
  return R
end

-- ------------------------------------------------------------------------------------------------- the build

return function(input)
  local K = input.consts
  local V = input.vocab
  local R = rarity_set(input.rarity or {})
  local X = {
    K = K, PARAM_ROW = PARAM_ROW,
    used = { chara = {}, param = {}, model = {}, internal = {}, text = {} },
    serial_max = 0, claims = {}, conflicts = {}, created = {}, texts = U.text_groups(), load_index = {}, icons = {},
    hidden = {}, removed_keys = {}, recruits = {}, names_cache = {}, pristine = {}, pristine_model = {},
    added = { B = {}, P = {}, M = {} }, orders = { B = {}, P = {}, M = {} }, celebr = {}, learn_cards = {},
  }
  local out = { created = {}, recruits = {}, hidden = {}, conflicts = {}, gentext = {}, celebrations = {}, traits = {},
    move_grades = {}, icons = {}, learn_cards = {} }

  -- the files with declarations, in load order (stable)
  local function by_load(list)
    return stable_sort(list, function(a, b) return a.load_index < b.load_index end)
  end
  local files = {}
  for _, f in ipairs(input.files or {}) do
    if not f.empty then files[#files + 1] = f end
  end
  files = by_load(files)
  for _, f in ipairs(files) do X.load_index[f.mod] = f.load_index end

  -- ---------------------------------------------------------------- notes
  function X.conflict(msg)
    VRFW.log.warn(msg)
    X.conflicts[#X.conflicts + 1] = msg
  end

  -- `t` = "B" (chara_base) / "P" (chara_param) / "M" (chara_model), `row` = the row's id, `col` = the column
  function X.claim(t, row, col, m, v, what)
    local k = t .. ":" .. int_str(U.id(row)) .. ":" .. col
    local s = vfmt(v)
    local old = X.claims[k]
    if old and old.by ~= m and old.val ~= s then
      X.conflict("character conflict: " .. what .. ": mod " .. old.by .. " = " .. old.val .. ", mod " .. m .. " = " .. s ..
        " (winner: " .. m .. ", loads later)")
    end
    X.claims[k] = { t = t, row = U.id(row), col = col, by = m, val = s }
  end

  -- ---------------------------------------------------------------- the tables
  local function key_of(prefix)
    return VRFW.rows.key(prefix)
  end
  do
    local bk, be = key_of(K.prefixes.base)
    local pk, pe = key_of(K.prefixes.param)
    if not bk or not pk then
      VRFW.log.error((be or pe) .. ": no character data is built")
      return out
    end
    local b, e1 = VRFW.rows.open(bk)
    local p, e2 = VRFW.rows.open(pk)
    if not b or not p then
      VRFW.log.error((e1 or e2) .. ": no character data is built")
      return out
    end
    X.base, X.param = b, p
  end
  -- chara_model / shop_config are read on demand: a missing one is reported when it is needed
  X.model_key, X.model_key_err = key_of(K.prefixes.model)
  X.shop_key, X.shop_key_err = key_of(K.prefixes.shop)

  -- the columns by their schema names (schemas/character/*.toml); the declarations' names are checked against them
  local function cols(t, row, names)
    local c = {}
    for _, n in ipairs(names) do c[n] = t:col(row, n) end
    return c
  end
  local function check(t, row, list, what)
    local bad = C.check(t, row, list)
    if bad then VRFW.log.warn(what .. ": the declaration names differ from the schema: " .. bad) end
  end
  X.CB = cols(X.base, BASE_ROW, { "id", "name", "serial_no", "name_text", "short_name_text", "upper_name_text", "model",
    "gender", "description_text" })
  X.CP = cols(X.param, PARAM_ROW, { "id", "chara", "element", "main_position", "sub_position", "build_type",
    "growth_pattern", "play_style", "rank", "ability_board", "skill_1", "mod_kick", "title", "special_rarity",
    "stats_version", "growth_type", "stat_kick", "stat_speed", "stat_freedom", "recruit_mode", "moment_kit", "card_style",
    "own_passive_1", "offpitch_kit", "offpitch_with_kit" })
  for _, s in ipairs(STAT_CELLS) do X.CP[s[1]] = X.param:col(PARAM_ROW, s[1]) end
  check(X.base, BASE_ROW, C.BASE, "chara_base")
  check(X.param, PARAM_ROW, C.PARAM, "chara_param")
  local CB, CP = X.CB, X.CP

  -- chara_model, loaded on first use (its ids are taken then; its rows as loaded are the templates of new_model)
  function X.model_table()
    if X.model then return X.model end
    if not X.model_key then return nil, X.model_key_err end
    local t, e = VRFW.rows.open(X.model_key)
    if not t then return nil, e end
    X.CM = cols(t, MODEL_ROW, { "id", "clothes", "shoes", "gloves", "head_mesh_path", "head_texture_path" })
    check(t, MODEL_ROW, C.MODEL, "chara_model")
    local h = VRFW.crc32(MODEL_ROW)
    for _, en in ipairs(t:entries(0, t:len())) do
      local id = en.values[X.CM.id + 1]
      if en.hash == h and type(id) == "number" then
        id = U.id(id)
        X.used.model[id] = true
        if not X.pristine_model[id] then X.pristine_model[id] = en end
      end
    end
    X.model = t
    return t
  end

  function X.tab(t)
    if t == "B" then return X.base end
    if t == "P" then return X.param end
    return X.model_table()
  end

  -- position of row `id` (nil = none); second value: an error (chara_model unreadable)
  function X.row_index(t, id)
    if t == "B" then return X.base:find(BASE_ROW, 0, id) end
    if t == "P" then return X.param:find(PARAM_ROW, 0, id) end
    local mt, e = X.model_table()
    if not mt then return nil, e end
    return mt:find(MODEL_ROW, 0, id)
  end

  -- Set `col` of row `id` of table `t` for mod `m`. Returns an error text or nil.
  function X.set(t, id, col, v, m, what)
    local i, e = X.row_index(t, id)
    if e then return e end
    if not i then return what .. ": row " .. U.hex(id) .. " not found" end
    X.claim(t, id, col, m, v, what)
    X.tab(t):set(i, col, v)
    return nil
  end

  function X.base_cell(chara, col)
    local i = X.base:find(BASE_ROW, CB.id, chara)
    if i then return X.base:uint(i, col) end
    return nil
  end

  function X.internal_of(chara)
    local i = X.base:find(BASE_ROW, CB.id, chara)
    if i then return X.base:str(i, CB.name) end
    return nil
  end

  function X.created_by_chara(chara)
    for _, k in ipairs(U.keys(X.created)) do
      if X.created[k].chara == chara then return X.created[k] end
    end
    return nil
  end

  function X.label_of(chara)
    local c = X.created_by_chara(chara)
    if c then return c.key end
    return X.internal_of(chara) or U.hex(chara)
  end

  -- every card (chara_param id) of a character
  function X.cards(chara)
    local o = {}
    for _, i in ipairs(X.param:find_all(PARAM_ROW, CP.chara, chara)) do
      local id = X.param:uint(i, CP.id)
      if id then o[#o + 1] = id end
    end
    return o
  end

  -- The character id of a reference: a creation key (`<mod>.<name>`, or `<name>` of the same mod), else a game id.
  function X.chara_ref(s, m)
    s = U.trim(s)
    local c = X.created[s] or X.created[m .. "." .. s]
    if c then return c.chara end
    local id = VRFW.ids.parse(s)
    if X.base:find(BASE_ROW, CB.id, id) then return id end
    -- a character id that only cards name (the game has cards whose character has no chara_base row)
    if X.param:find(PARAM_ROW, CP.chara, id) then return id end
    if X.removed_keys[s] or X.removed_keys[m .. "." .. s] then
      return nil, "character `" .. s .. "` was deleted by a [[remove]]"
    end
    return nil, "character `" .. s .. "` is not in chara_base (write a game internal name like c01000010, its id, or a mod's <mod>.<name>)"
  end

  -- The name of a character in `lang` (the game's chara_text, or a creation's declared name).
  function X.chara_name(chara, lang)
    local c = X.created_by_chara(chara)
    local id = X.base_cell(chara, CB.name_text)
    if c then
      if not id then return nil end
      for _, gk in ipairs(U.keys(X.texts.groups)) do
        for _, r in ipairs(X.texts.groups[gk].rows) do
          if r.ckey == c.key and r.table == "chara_text" and r.id == id and r.variant == 0 then
            return VRFW.lang.pick(r.texts, lang)
          end
        end
      end
      return nil
    end
    if not id then return nil end
    local map = X.names_cache[lang]
    if not map then
      map = {}
      local key = K.chara_text[lang]
      local t = key and VRFW.rows.open(key)
      if t then
        local h = VRFW.crc32("NOUN_INFO")
        for _, en in ipairs(t:entries(0, t:len())) do
          local v = en.values
          if en.hash == h and v[2] == 0 and type(v[1]) == "number" and type(v[6]) == "string" then map[U.id(v[1])] = v[6] end
        end
      end
      X.names_cache[lang] = map
    end
    return map[id]
  end

  -- ---------------------------------------------------------------- shared declarations
  -- `[[param_column]]`, `[[price_tier]]`, `[element_currency]` of every file (load order)
  do
    local d = { columns = {}, price_tiers = {}, currency = {} }
    local owner = {}
    for _, f in ipairs(by_load(input.files or {})) do
      local v = f.value
      for _, c in ipairs(v.param_column or {}) do
        local col = c.col
        local engine = C.PARAM[col + 1]
        if not valid_word(c.name) or c.name:sub(1, 4) == "col_" or C.has(C.PARAM, c.name) then
          VRFW.log.error(f.file .. ": param_column `" .. c.name .. "`: a new name `a-z 0-9 _` (not an engine name, not col_<n>)")
        elseif col < 2 or col >= 256 then
          VRFW.log.error(f.file .. ": param_column `" .. c.name .. "`: col " .. col .. ": 2..255")
        elseif engine and engine:sub(1, 4) ~= "col_" then
          VRFW.log.error(f.file .. ": param_column `" .. c.name .. "`: col " .. col .. " is the engine's `" .. engine .. "`")
        elseif d.columns[c.name] ~= nil and d.columns[c.name] ~= col then
          VRFW.log.error(f.file .. ": param_column `" .. c.name .. "`: already col " .. d.columns[c.name] .. " (mod " ..
            owner[c.name] .. "); col " .. col .. " ignored")
        else
          for _, n in ipairs(U.keys(d.columns)) do
            if d.columns[n] == col and n ~= c.name then
              VRFW.log.info(f.file .. ": param_column `" .. c.name .. "`: col " .. col .. " is also named `" .. n .. "`")
              break
            end
          end
          d.columns[c.name] = col
          if owner[c.name] == nil then owner[c.name] = f.mod end
        end
      end
      for _, t in ipairs(v.price_tier or {}) do
        if not valid_word(t.id) then
          VRFW.log.error(f.file .. ": price_tier `" .. t.id .. "`: an id `a-z 0-9 _`")
        else
          local old = d.price_tiers[t.id]
          if old and (old.base ~= t.base or (old.level_step or 0) ~= (t.level_step or 0)) then
            VRFW.log.warn(f.file .. ": price_tier `" .. t.id .. "` replaces the earlier one (" .. old.base .. " + level / " ..
              (old.level_step or 0) .. "; loads later)")
          end
          d.price_tiers[t.id] = t
        end
      end
      for _, k in ipairs(U.keys(v.element_currency or {})) do
        local e = V.element[k]
        local item = U.id(v.element_currency[k])
        if e ~= nil then
          local old = d.currency[e]
          d.currency[e] = item
          if old and old ~= item then
            VRFW.log.warn(f.file .. ": element_currency." .. k .. ": " .. U.hex(item) .. " replaces " .. U.hex(old) .. " (loads later)")
          end
        else
          VRFW.log.error(f.file .. ": element_currency." .. k .. ": not an element (" .. table.concat(V.element_words, ", ") .. ")")
        end
      end
    end
    X.decl = d
  end

  -- chara_param column of a declared name: the engine's names, `col_<n>`, then the `[[param_column]]` names
  function X.param_col(name)
    local c = C.index(C.PARAM, name)
    if c ~= nil then return c end
    return X.decl.columns[name]
  end

  -- ---------------------------------------------------------------- the ids in use
  do
    local h = VRFW.crc32(BASE_ROW)
    for _, en in ipairs(X.base:entries(0, X.base:len())) do
      if en.hash == h then
        local v = en.values
        if type(v[CB.id + 1]) == "number" then X.used.chara[U.id(v[CB.id + 1])] = true end
        if type(v[CB.name + 1]) == "string" then X.used.internal[v[CB.name + 1]] = true end
        for _, c in ipairs { CB.name_text, CB.short_name_text, CB.upper_name_text, CB.description_text } do
          local t = v[c + 1]
          if type(t) == "number" and U.id(t) ~= 0 then X.used.text[U.id(t)] = true end
        end
        local s = v[CB.serial_no + 1]
        if type(s) == "number" and U.i32(s) > X.serial_max then X.serial_max = U.i32(s) end
      end
    end
    for _, i in ipairs(X.param:rows(PARAM_ROW)) do
      local id = X.param:uint(i, CP.id)
      if id then X.used.param[id] = true end
    end
  end

  -- ---------------------------------------------------------------- fields

  -- the fields of a `[[character]]` / `[[edit]]` (the card-level named columns are read from the declaration itself)
  local function fields(d)
    return {
      rarity = d.rarity, element = d.element, position = d.position, sub_position = d.sub_position, gender = d.gender,
      growth = d.growth, model = d.model, look = d.look, text = d.text or {}, stats = d.stats, stat_mods = d.stat_mods,
      moves = d.moves, learn_levels = d.vrfw and d.vrfw.LearnLevels, base = d.base or {}, model_row = d.model_row or {},
      new_model = d.new_model, cards = d.cards or {}, card_cols = d,
    }
  end

  local function resolve_rarity(what, r)
    if r == nil then return nil end
    local x, e = R.find(r)
    if x then return x end
    VRFW.log.error(what .. ": rarity: " .. e)
    return nil
  end

  -- The named columns + `cells` of a card block as { col, value, label }; unknown names are errors.
  local function card_cells(c, errs)
    local v = {}
    local function int(name, x)
      if x ~= nil then v[#v + 1] = { CP[name], U.i32(x), name } end
    end
    local function id(x)
      if x == nil then return nil end
      return U.id(x)
    end
    int("build_type", c.build_type)
    int("growth_pattern", c.growth_pattern)
    int("play_style", c.play_style)
    int("rank", c.rank)
    int("ability_board", id(c.ability_board))
    int("title", id(c.title))
    int("special_rarity", c.special_rarity)
    int("stats_version", c.stats_version)
    int("recruit_mode", c.recruit_mode)
    int("moment_kit", id(c.moment_kit))
    int("offpitch_kit", id(c.offpitch_kit))
    int("offpitch_with_kit", id(c.offpitch_with_kit))
    int("card_style", c.card_style)
    -- goal celebrations: keys checked here, resolved by the celebration builder (performance_genre stays: it is the
    -- CONCEDING team's reaction, not the scorer's celebration)
    local keys = {}
    for _, k in ipairs(c.celebrations or {}) do keys[#keys + 1] = k end
    if c.celebration_auto ~= nil then keys[#keys + 1] = c.celebration_auto end
    for _, k in ipairs(keys) do
      if not valid_celebration(k) then
        errs[#errs + 1] = "celebration `" .. k .. "`: not a celebration id (`<mod>.<name>`, lower case)"
      end
    end
    if c.own_passives ~= nil then
      local p = c.own_passives
      if #p > OWN_PASSIVES then
        errs[#errs + 1] = "own_passives: " .. #p .. " given, " .. OWN_PASSIVES .. " slots (the rest is left out)"
      end
      for k = 0, OWN_PASSIVES - 1 do
        v[#v + 1] = { CP.own_passive_1 + k, p[k + 1] ~= nil and U.i32(U.id(p[k + 1])) or 0, "own_passives" }
      end
    end
    local cells = c.cells or {}
    for _, name in ipairs(U.keys(cells)) do
      local col = X.param_col(name)
      if col == 0 or col == 1 then
        errs[#errs + 1] = "cells." .. name .. ": the card's id / character are not cells"
      elseif col ~= nil then
        v[#v + 1] = { col, cell_value(cells[name]), "cells" }
      else
        errs[#errs + 1] = "cells." .. name .. ": not a chara_param column (schemas/character/chara_param.toml names, a `[[param_column]]` name, or col_<n>)"
      end
    end
    return v
  end

  -- The card-level fields `f` on one card (sugar first, then the named / raw columns).
  function X.apply_card(m, what, card, f, errs)
    local function try(e) if e then errs[#errs + 1] = e end end
    local function w(s) return what .. " (card " .. U.hex(card) .. ")." .. s end
    if f.element ~= nil then try(X.set("P", card, CP.element, V.element[f.element], m, w("element"))) end
    if f.position ~= nil then try(X.set("P", card, CP.main_position, V.position[f.position], m, w("position"))) end
    if f.sub_position ~= nil then try(X.set("P", card, CP.sub_position, V.position[f.sub_position], m, w("sub_position"))) end
    local ri = X.row_index("P", card)
    if not ri then
      errs[#errs + 1] = "card " .. U.hex(card) .. " is not in chara_param"
      return
    end
    local width = X.param:width(ri)
    local r = f.rarity
    if r then
      try(X.set("P", card, CP.special_rarity, r.value, m, w("rarity")))
      -- the cells the rarity declares for its cards (`cells`, by column name)
      for _, name in ipairs(U.keys(r.cells or {})) do
        local col = X.param_col(name)
        if col == nil or col == 0 or col == 1 then
          errs[#errs + 1] = "rarity `" .. r.key .. "`: cells." .. name .. ": not a chara_param column the card may set"
        elseif col >= width then
          errs[#errs + 1] = "rarity `" .. r.key .. "`: cells." .. name .. ": this chara_param has no col " .. col .. " (param_columns)"
        else
          try(X.set("P", card, col, U.i32(r.cells[name]), m, w("rarity cells." .. name)))
        end
      end
    end
    if f.growth ~= nil then
      if width > CP.growth_type then
        try(X.set("P", card, CP.growth_type, V.growth[f.growth], m, w("growth")))
      else
        errs[#errs + 1] = "growth needs the EVT stats layout of chara_param (param_columns = 58)"
      end
    end
    if f.stat_mods ~= nil then
      for k, s in ipairs(MOD_STATS) do
        local x = f.stat_mods[s]
        if x ~= nil then try(X.set("P", card, CP.mod_kick + k - 1, U.i32(x), m, w("stat_mods"))) end
      end
    end
    local st = f.stats
    if st ~= nil then
      if width <= CP.stat_freedom then
        errs[#errs + 1] = "stats (Lv200) need the EVT stats layout of chara_param (cols 45-54, param_columns = 58); use stat_mods for the game's own modifiers"
      else
        for _, sc in ipairs(STAT_CELLS) do
          local x = st[sc[2]]
          if x ~= nil then
            if x < 0 or x > 9999 then
              errs[#errs + 1] = "stats: " .. int_str(x) .. " out of 0-9999"
            else
              try(X.set("P", card, CP[sc[1]], U.i32(x), m, w("stats")))
            end
          end
        end
        try(X.set("P", card, CP.stats_version, K.layout_v2, m, w("stats")))
        if st.speed == nil then try(X.set("P", card, CP.stat_speed, 0, m, w("stats"))) end
        -- the rarity's stat rule (Prime: the strongest stat x 1.5), on the stats declared here
        if st.bonus ~= false then
          local rv = X.param:int(ri, CP.special_rarity) or 0
          local rr = r or R.of_card(rv % 256)
          local mult = rr and rr.bonus and rr.bonus.best_stat
          if mult then
            local v = {}
            for k = 0, 7 do v[k] = X.param:int(ri, CP.stat_kick + k) or 0 end
            local k = best_stat_index(v, X.param:int(ri, CP.main_position) or 0)
            local nv = round(v[k] * mult)
            try(X.set("P", card, CP.stat_kick + k, nv, m, w("stats (rarity bonus)")))
          end
        end
      end
    end
    local slots = K.learn_slots
    if f.moves ~= nil then
      if #f.moves > slots then
        errs[#errs + 1] = "moves: " .. #f.moves .. " given, the learn list has " .. slots .. " slots (the rest is left out)"
      end
      for k = 0, slots - 1 do
        local mv = f.moves[k + 1]
        local id, lv = 0, 0
        if mv then id, lv = U.i32(U.id(mv.move)), U.i32(mv.level or 1) end
        try(X.set("P", card, CP.skill_1 + 2 * k, id, m, w("moves")))
        try(X.set("P", card, CP.skill_1 + 2 * k + 1, lv, m, w("moves")))
      end
    end
    if f.learn_levels ~= nil then
      -- the levels of the learn list (the moves stay); the card's levels count as declared
      local ll = f.learn_levels
      if #ll > slots then
        errs[#errs + 1] = "vrfw.LearnLevels: " .. #ll .. " given, the learn list has " .. slots .. " slots (the rest is left out)"
      end
      local levels = {}
      for k = 0, math.min(#ll, slots) - 1 do
        local l = ll[k + 1]
        if l > K.learn_max then
          errs[#errs + 1] = "vrfw.LearnLevels: slot " .. (k + 1) .. ": level " .. int_str(l) .. " (at most " .. K.learn_max .. "; skipped)"
        elseif l ~= 0 then
          levels[#levels + 1] = { k, l }
        end
      end
      for _, x in ipairs(levels) do
        local k, lv = x[1], x[2]
        if (X.param:int(ri, CP.skill_1 + 2 * k) or 0) == 0 then
          errs[#errs + 1] = "vrfw.LearnLevels: slot " .. (k + 1) .. " has no move (level " .. int_str(lv) .. " written anyway)"
        end
        try(X.set("P", card, CP.skill_1 + 2 * k + 1, lv, m, w("vrfw.LearnLevels")))
      end
      local seen = false
      for _, x in ipairs(X.learn_cards) do
        if x[1] == card and x[2] == m then seen = true end
      end
      if not seen then X.learn_cards[#X.learn_cards + 1] = { card, m } end
    end
    for _, c in ipairs(f.cells) do try(X.set("P", card, c[1], c[2], m, w(c[3]))) end
    if f.celebrations ~= nil or f.celebration_auto ~= nil then
      local c = X.celebr[card]
      if not c then
        c = { celebrations = {} }
        X.celebr[card] = c
      end
      c.mod_id = m
      c.load_index = X.load_index[m] or 0
      c.origin = what .. " (card " .. U.hex(card) .. ")"
      c.card = card
      c.chara = X.param:uint(ri, CP.chara) or 0
      if f.celebrations ~= nil then
        local l = {}
        for k, x in ipairs(f.celebrations) do l[k] = x end
        c.celebrations = l
      end
      if f.celebration_auto ~= nil then c.auto = f.celebration_auto end
    end
  end

  -- `new_model`: a chara_model row with a fixed id, cloned from `from` (a model id, or a character's model; default
  -- the character's current model) as the base had it, `cells` changed; chara_base `model` becomes it.
  function X.new_model(m, what, chara, nm)
    local id = U.id(nm.id)
    local src
    if nm.from == nil then
      src = X.base_cell(chara, CB.model)
      if not src then return "new_model: the character has no model to clone (give `from`)" end
    elseif type(nm.from) == "number" then
      src = U.id(nm.from)
    else
      local c, e = X.chara_ref(nm.from, m)
      if not c then return "new_model.from: " .. e end
      src = X.base_cell(c, CB.model)
      if not src then return "new_model.from: `" .. nm.from .. "` has no model" end
    end
    local mt, me = X.model_table()
    if not mt then return me end
    if X.row_index("M", id) then return "new_model: model " .. U.hex(id) .. " is already in chara_model" end
    local row = X.pristine_model[src]
    if row then
      row = U.copy_entry(row)
    else
      local si = X.row_index("M", src)
      if not si then return "new_model.from: model " .. U.hex(src) .. " is not in chara_model" end
      row = mt:entry(si)
    end
    row.values[X.CM.id + 1] = id
    for _, name in ipairs(U.keys(nm.cells or {})) do
      local col = C.index(C.MODEL, name)
      if col == nil or col == 0 then
        return "new_model.cells." .. name .. ": not a chara_model column (the id is `id`)"
      end
      while #row.values <= col do row.values[#row.values + 1] = 0 end
      row.values[col + 1] = cell_value(nm.cells[name])
    end
    local ae = perr(mt.append_rows, mt, MODEL_ROW, { MODEL_ROW }, { row }, 1)
    if ae then return ae end
    X.used.model[id] = true
    X.added.M[id] = true
    if nm.order ~= nil then X.orders.M[id] = nm.order end
    X.claim("M", id, 0, m, id, what .. ".new_model")
    return X.set("B", chara, CB.model, id, m, what .. ".new_model")
  end

  -- `look`: a new chara_model row cloned from the character's model with these parts (id of `<key>.look`).
  function X.apply_look(m, what, chara, key, look)
    local cur = X.base_cell(chara, CB.model)
    if not cur then return "no model" end
    local src, e = X.row_index("M", cur)
    if e then return e end
    if not src then return "look: model " .. U.hex(cur) .. " not in chara_model" end
    local mt = X.model
    local row = mt:entry(src)
    local id = VRFW.ids.assign(key .. ".look", X.used.model)
    X.used.model[id] = true
    row.values[X.CM.id + 1] = id
    if look.head ~= nil then
      local hc, he = X.chara_ref(look.head, m)
      if not hc then return he end
      local hm = X.base_cell(hc, CB.model)
      if not hm then return "head: no model" end
      local hi = X.row_index("M", hm)
      if not hi then return "head: model not in chara_model" end
      local hr = mt:entry(hi)
      for _, col in ipairs { X.CM.head_mesh_path, X.CM.head_texture_path } do
        if hr.values[col + 1] ~= nil then row.values[col + 1] = hr.values[col + 1] end
      end
    end
    for _, p in ipairs { { X.CM.clothes, look.clothes }, { X.CM.shoes, look.shoes }, { X.CM.gloves, look.gloves } } do
      if p[2] ~= nil then row.values[p[1] + 1] = U.id(p[2]) end
    end
    if not X.row_index("M", id) then
      local ae = perr(mt.append_rows, mt, MODEL_ROW, { MODEL_ROW }, { row }, 1)
      if ae then return ae end
    end
    return X.set("B", chara, CB.model, id, m, what .. ".look")
  end

  -- The name / description texts for the text type: rows of the character's own text ids (added for a new
  -- character; replacing an existing one's).
  function X.texts_of(m, what, chara, key, text, default, add)
    local ids = {}
    for k, c in ipairs { CB.name_text, CB.short_name_text, CB.upper_name_text, CB.description_text } do
      ids[k] = X.base_cell(chara, c) or 0
    end
    local name, short, upper, desc = ids[1], ids[2], ids[3], ids[4]
    local rows = {
      { "chara_text", name, 0, function(n) return n.name end },
      { "chara_text", name, 11, function(n) return n.surname end },
      { "chara_text", name, 12, function(n) return n.given end },
      { "chara_text", short, 0, function(n) return n.short end },
      { "chara_text", upper, 0, function(n) return n.upper end },
      { "chara_description_text", desc, 0, function(n) return n.description end },
    }
    if add then
      -- a new character also gets its romanized rows (the game's original-name table): `roma_*`, else the names
      rows[#rows + 1] = { "chara_text_roma", name, 0, function(n) if n.roma_name ~= nil then return n.roma_name end return n.name end }
      rows[#rows + 1] = { "chara_text_roma", name, 11, function(n) if n.roma_surname ~= nil then return n.roma_surname end return n.surname end }
      rows[#rows + 1] = { "chara_text_roma", name, 12, function(n) if n.roma_given ~= nil then return n.roma_given end return n.given end }
      rows[#rows + 1] = { "chara_text_roma", short, 0, function(n) if n.roma_short ~= nil then return n.roma_short end return n.short end }
      rows[#rows + 1] = { "chara_text_roma", upper, 0, function(n) if n.roma_upper ~= nil then return n.roma_upper end return n.upper end }
    else
      -- an edit: the romanized rows only when written
      rows[#rows + 1] = { "chara_text_roma", name, 0, function(n) return n.roma_name end }
      rows[#rows + 1] = { "chara_text_roma", name, 11, function(n) return n.roma_surname end }
      rows[#rows + 1] = { "chara_text_roma", name, 12, function(n) return n.roma_given end }
      rows[#rows + 1] = { "chara_text_roma", short, 0, function(n) return n.roma_short end }
      rows[#rows + 1] = { "chara_text_roma", upper, 0, function(n) return n.roma_upper end }
    end
    for _, l in ipairs(U.keys(text)) do
      if not VRFW.lang.norm_or_all(l) then
        VRFW.log.warn(what .. ": text." .. l .. ": not a language (" .. table.concat(VRFW.lang.list(), ", ") .. ", all): ignored")
      end
    end
    for _, r in ipairs(rows) do
      local texts, any = U.pick_langs(text, r[4])
      if any then
        if r[2] == 0 then
          VRFW.log.warn(what .. ": its chara_base row has no text id for " .. r[1] .. "#" .. r[3] .. ": that text is skipped")
        else
          X.texts.push(m, default, { table = r[1], id = r[2], variant = r[3], texts = texts, add = add, origin = what .. " (" .. m .. ")",
            ckey = key })
        end
      end
    end
  end

  -- Apply `f` (the declaration of mod `m`) to character `chara` and its `cards`. `what` names the target in notes.
  -- `default_from` = the template of a card block that adds a card without `from`.
  function X.apply(m, what, chara, cards, f, file_default, key, is_new, default_from)
    local errs = {}
    local function try(e) if e then errs[#errs + 1] = e end end
    -- chara_base cells
    for _, name in ipairs(U.keys(f.base)) do
      local cell = f.base[name]
      local col = C.index(C.BASE, name)
      if col == 0 then
        if not (type(cell) == "number" and U.id(cell) == chara) then
          errs[#errs + 1] = "base.id: the id of an existing character does not change"
        end
      elseif col ~= nil then
        try(X.set("B", chara, col, cell_value(cell), m, what .. ".base." .. name))
      else
        errs[#errs + 1] = "base." .. name .. ": not a chara_base column (schemas/character/chara_base.toml names, or col_<n>)"
      end
    end
    -- a new chara_model row, then cells of the character's model row
    if f.new_model ~= nil then try(X.new_model(m, what, chara, f.new_model)) end
    if not U.is_empty(f.model_row) then
      local model = X.base_cell(chara, CB.model)
      if model then
        for _, name in ipairs(U.keys(f.model_row)) do
          local col = C.index(C.MODEL, name)
          if col == 0 then
            errs[#errs + 1] = "model_row.id: write new_model for a new row"
          elseif col ~= nil then
            try(X.set("M", model, col, cell_value(f.model_row[name]), m, what .. ".model_row." .. name))
          else
            errs[#errs + 1] = "model_row." .. name .. ": not a chara_model column (schemas/character/chara_model.toml names, or col_<n>)"
          end
        end
      else
        errs[#errs + 1] = "model_row: the character has no model"
      end
    end
    -- identity (chara_base)
    if f.gender ~= nil then try(X.set("B", chara, CB.gender, V.gender[f.gender], m, what .. ".gender")) end
    if f.model ~= nil then
      local c, e = X.chara_ref(f.model, m)
      local model
      if c then
        model = X.base_cell(c, CB.model)
        if not model then e = "model: `" .. f.model .. "` has no model" end
      end
      if model then
        try(X.set("B", chara, CB.model, model, m, what .. ".model"))
      else
        errs[#errs + 1] = "model: " .. e
      end
    end
    if f.look ~= nil then try(X.apply_look(m, what, chara, key, f.look)) end
    if not U.is_empty(f.text) then
      X.texts_of(m, what, chara, key, f.text, U.norm_default(file_default, f.text), is_new)
    end
    -- card blocks, phase 1: the added cards come to exist (copies of their templates)
    for _, c in ipairs(f.cards) do
      local id = U.id(c.id)
      local exists = X.param:find(PARAM_ROW, CP.id, id) ~= nil
      if c.from ~= nil or not exists then
        if exists then
          errs[#errs + 1] = "cards: card " .. U.hex(id) .. " is already in chara_param (drop `from` to edit it)"
        else
          local tpl = (c.from ~= nil and U.id(c.from)) or default_from or X.cards(chara)[1]
          if not tpl then
            errs[#errs + 1] = "cards: card " .. U.hex(id) .. ": no template (`from = <card id>`)"
          else
            local row = X.pristine[tpl]
            if row then
              row = U.copy_entry(row)
            else
              local i = X.param:find(PARAM_ROW, CP.id, tpl)
              if i then row = X.param:entry(i) end
            end
            if not row then
              errs[#errs + 1] = "cards: card " .. U.hex(id) .. ": template card " .. U.hex(tpl) .. " is not in chara_param"
            elseif X.used.chara[id] then
              errs[#errs + 1] = "cards: card " .. U.hex(id) .. " is a character id"
            else
              row.values[CP.id + 1] = id
              row.values[CP.chara + 1] = chara
              try(perr(X.param.append_rows, X.param, PARAM_ROW, { PARAM_ROW }, { row }, 1))
              X.used.param[id] = true
              X.added.P[id] = true
              if c.order ~= nil then X.orders.P[id] = c.order end
            end
          end
        end
      else
        local i = X.param:find(PARAM_ROW, CP.id, id)
        if X.param:uint(i, CP.chara) ~= chara then
          if c.adopt then
            try(X.set("P", id, CP.chara, chara, m, what .. " (card " .. U.hex(id) .. ").adopt"))
          else
            VRFW.log.warn(what .. ": cards: card " .. U.hex(id) .. " belongs to another character (`adopt = true` moves it)")
          end
        end
      end
    end
    -- cards (chara_param): the top-level fields on every card of `cards`
    local top = {
      element = f.element, position = f.position, sub_position = f.sub_position, growth = f.growth,
      rarity = resolve_rarity(what, f.rarity), stats = f.stats, stat_mods = f.stat_mods, moves = f.moves,
      learn_levels = f.learn_levels, cells = card_cells(f.card_cols, errs), celebrations = f.card_cols.celebrations,
      celebration_auto = f.card_cols.celebration_auto,
    }
    local all = {}
    for _, c in ipairs(cards) do all[#all + 1] = c end
    if #cards == 0 and is_new then
      -- a pinned new character: its top-level card fields go to every card block
      for _, c in ipairs(f.cards) do all[#all + 1] = U.id(c.id) end
    end
    for _, card in ipairs(all) do X.apply_card(m, what, card, top, errs) end
    -- card blocks, phase 2: their fields
    for _, c in ipairs(f.cards) do
      local id = U.id(c.id)
      if X.param:find(PARAM_ROW, CP.id, id) then
        local cerrs = {}
        local cf = {
          element = c.element, position = c.position, sub_position = c.sub_position, growth = c.growth,
          rarity = resolve_rarity(what, c.rarity), stats = c.stats, stat_mods = c.stat_mods, moves = c.moves,
          learn_levels = c.vrfw and c.vrfw.LearnLevels, cells = card_cells(c, cerrs), celebrations = c.celebrations,
          celebration_auto = c.celebration_auto,
        }
        for _, e in ipairs(cerrs) do errs[#errs + 1] = "card " .. U.hex(id) .. ": " .. e end
        X.apply_card(m, what, id, cf, errs)
      end
    end
    -- sorted, duplicates once
    VRFW.sort(errs)
    local last
    for _, e in ipairs(errs) do
      if e ~= last then
        last = e
        VRFW.log.error(what .. ": " .. e)
      end
    end
  end

  -- ---------------------------------------------------------------- new characters

  -- the new ids of creation `key`: internal name c9xxxxxxx (c92000000-c99999999), character, card, 4 text ids
  local function new_ids(key)
    local n = VRFW.character.assign_name(key .. "#internal", "c9", 7, 2000000, 8000000, X.used.internal, X.used.chara)
    local internal = string.format("c9%07d", 2000000 + n % 8000000)
    local chara = VRFW.crc32(internal)
    local taken = U.copy(X.used.param)
    for k in pairs(X.used.chara) do taken[k] = true end
    local param = VRFW.ids.assign(key .. "#card", taken)
    local texts = {}
    for k, part in ipairs { "name", "short", "upper", "desc" } do
      local t = VRFW.ids.assign(key .. "#" .. part, X.used.text)
      X.used.text[t] = true
      texts[k] = t
    end
    X.used.internal[internal] = true
    X.used.chara[chara] = true
    X.used.param[param] = true
    return internal, chara, param, texts
  end

  local function icon_of(key, file, icon_src, m, internal)
    local c = X.chara_ref(icon_src, m)
    local src = c and X.internal_of(c)
    if src then
      X.icons[#X.icons + 1] = { key, src, internal }
    else
      VRFW.log.warn(file .. ": " .. key .. ": icon `" .. icon_src .. "`: no such character (the game shows its default face)")
    end
  end

  local function has_name(text)
    for _, n in pairs(text) do
      if n.name ~= nil and U.trim(n.name) ~= "" then return true end
    end
    return false
  end

  -- A «pinned» new character (`base.id` given): the template's chara_base row with the `base` cells, its REF_BATTLE
  -- row per `battle`, and the cards of `cards` with their own ids. Nothing comes from the id registry; no face icon
  -- unless `icon` is given.
  local function create_pinned(m, file, d, file_default, key, tpl)
    local bi = X.base:find(BASE_ROW, CB.id, tpl)
    if not bi then return "based_on: not in chara_base" end
    local row = X.base:entry(bi)
    local tpl_ref = X.base:is(bi + 1, BASE_REF) and X.base:entry(bi + 1) or nil
    for _, name in ipairs(U.keys(d.base or {})) do
      local col = C.index(C.BASE, name)
      if col == nil then
        return "base." .. name .. ": not a chara_base column (schemas/character/chara_base.toml names, or col_<n>)"
      end
      while #row.values <= col do row.values[#row.values + 1] = 0 end
      row.values[col + 1] = cell_value(d.base[name])
    end
    local idv = row.values[CB.id + 1]
    local chara = type(idv) == "number" and U.id(idv) or 0
    if chara == 0 or X.used.chara[chara] then
      return "base.id " .. U.hex(chara) .. " is already a character of chara_base"
    end
    local internal = row.values[CB.name + 1]
    if type(internal) ~= "string" then internal = "" end
    -- `battle = false` = no battle rows: the retail form is a REF_BATTLE row [0, 0], never a missing one
    local function battle_ref(a, b)
      local e = tpl_ref
      if not e then
        local i = X.base:seek(BASE_REF, 0)
        if i then e = X.base:entry(i) end
      end
      if not e then return nil, "battle: no REF_BATTLE row to copy" end
      e = U.copy_entry(e)
      e.values = { U.i32(a), U.i32(b) }
      return e
    end
    local reff = tpl_ref
    if d.battle == false then
      local e
      reff, e = battle_ref(0, 0)
      if not reff then return e end
    elseif type(d.battle) == "table" then
      local e
      reff, e = battle_ref(d.battle[1], d.battle[2])
      if not reff then return e end
    end
    local s = row.values[CB.serial_no + 1]
    if type(s) == "number" and U.i32(s) > X.serial_max then X.serial_max = U.i32(s) end
    for _, c in ipairs { CB.name_text, CB.short_name_text, CB.upper_name_text, CB.description_text } do
      local t = row.values[c + 1]
      if type(t) == "number" and U.id(t) ~= 0 then X.used.text[U.id(t)] = true end
    end
    local rows = { row }
    if reff then rows[2] = reff end
    local ae = perr(X.base.append_rows, X.base, BASE_ROW, { BASE_ROW, BASE_REF }, rows, 1)
    if ae then return ae end
    X.used.chara[chara] = true
    X.used.internal[internal] = true
    X.added.B[chara] = true
    if d.order ~= nil then X.orders.B[chara] = d.order end
    local default_from
    if d.card ~= nil then default_from = U.id(d.card) else default_from = X.cards(tpl)[1] end
    -- no card is allowed (an event object with a chara_base row only): param 0
    local first = (d.cards and d.cards[1]) and U.id(d.cards[1].id) or 0
    local rarity = ""
    if d.rarity ~= nil then
      local x = R.find(d.rarity)
      if x then rarity = x.key end
    end
    X.created[key] = { key = key, mod_id = m, internal = internal, chara = chara, param = first,
      model = X.base_cell(chara, CB.model) or 0, rarity = rarity }
    if d.icon ~= nil then icon_of(key, file, d.icon, m, internal) end
    local f = fields(d)
    -- the base cells are in the row already (the id among them)
    f.base = {}
    X.apply(m, file .. ": " .. key, chara, {}, f, d.default_lang or file_default, key, true, default_from)
    if X.created[key] then X.created[key].model = X.base_cell(chara, CB.model) or 0 end
    return nil
  end

  -- A new character of mod `m`. Returns an error text or nil.
  local function create(m, file, d, file_default)
    local key, ke = VRFW.ids.own(m, d.name)
    if not key then return ke end
    if X.created[key] then return "`" .. key .. "` is declared twice (the first is kept)" end
    if X.used.internal[d.name] then
      -- `<name>` inside the mod means the new character: the game's one is then only reachable by its id
      VRFW.log.warn(file .. ": character `" .. d.name .. "`: also a game character's internal name; inside this mod `" .. d.name ..
        "` means the new one (use another name)")
    end
    local tpl, te = X.chara_ref(d.based_on, m)
    if not tpl then return "based_on: " .. te end
    if d.base and d.base.id ~= nil then return create_pinned(m, file, d, file_default, key, tpl) end
    local tpl_card
    if d.card ~= nil then
      local id = U.id(d.card)
      if not X.param:find(PARAM_ROW, CP.id, id) then return "card " .. idref_str(d.card) .. ": not in chara_param" end
      tpl_card = id
    else
      tpl_card = X.cards(tpl)[1]
      if not tpl_card then
        return "based_on `" .. d.based_on .. "` has no card (chara_param row): give `card = …`"
      end
    end
    local internal, chara, param, t = new_ids(key)
    -- chara_base: the template's row + its REF_BATTLE row
    local bi = X.base:find(BASE_ROW, CB.id, tpl)
    if not bi then return "based_on: not in chara_base" end
    local row = X.base:entry(bi)
    local reff = X.base:is(bi + 1, BASE_REF) and X.base:entry(bi + 1) or nil
    X.serial_max = X.serial_max + 1
    local v = row.values
    v[CB.id + 1] = chara
    v[CB.name + 1] = internal
    v[CB.serial_no + 1] = X.serial_max
    v[CB.name_text + 1] = t[1]
    v[CB.short_name_text + 1] = t[2]
    v[CB.upper_name_text + 1] = t[3]
    v[CB.description_text + 1] = t[4]
    local rows = { row }
    if reff then rows[2] = reff end
    local ae = perr(X.base.append_rows, X.base, BASE_ROW, { BASE_ROW, BASE_REF }, rows, 1)
    if ae then return ae end
    -- chara_param: the template card (its moment kit and off-pitch outfit are its own)
    local pi = X.param:find(PARAM_ROW, CP.id, tpl_card)
    local prow = X.param:entry(pi)
    local pv = prow.values
    pv[CP.id + 1] = param
    pv[CP.chara + 1] = chara
    for _, c in ipairs { CP.moment_kit, CP.offpitch_kit, CP.offpitch_with_kit } do
      if #pv > c then pv[c + 1] = 0 end
    end
    ae = perr(X.param.append_rows, X.param, PARAM_ROW, { PARAM_ROW }, { prow }, 1)
    if ae then return ae end
    X.added.B[chara] = true
    X.added.P[param] = true
    if d.order ~= nil then X.orders.B[chara] = d.order end
    X.created[key] = { key = key, mod_id = m, internal = internal, chara = chara, param = param,
      model = X.base_cell(chara, CB.model) or 0, rarity = "" }
    -- face icon: whose (icon, else model, else based_on)
    icon_of(key, file, d.icon or d.model or d.based_on, m, internal)
    local what = file .. ": " .. key
    local f = fields(d)
    X.apply(m, what, chara, { param }, f, d.default_lang or file_default, key, true, tpl_card)
    if d.rarity ~= nil then
      local x = R.find(d.rarity)
      if x and X.created[key] then X.created[key].rarity = x.key end
    end
    if X.created[key] then X.created[key].model = X.base_cell(chara, CB.model) or 0 end
    if not has_name(f.text) then
      VRFW.log.warn(what .. ": no [character.text.<lang>] name: the new character shows no name")
    end
    return nil
  end

  -- ---------------------------------------------------------------- removals

  local function remove(m, file, r)
    local chara, ce = X.chara_ref(r.character, m)
    if not chara then return ce end
    local created = X.created_by_chara(chara)
    local cards
    if r.card ~= nil then cards = { U.id(r.card) } else cards = X.cards(chara) end
    local what = file .. ": remove " .. X.label_of(chara)
    local is_card = {}
    for _, c in ipairs(cards) do is_card[c] = true end
    local touched = {}
    for _, c in pairs(X.claims) do
      if c.by ~= m and ((c.t == "P" and is_card[c.row]) or (c.t == "B" and c.row == chara)) then touched[c.by] = true end
    end
    local tl = U.keys(touched)
    if #tl > 0 then
      X.conflict("character conflict: " .. what .. ": mod " .. m .. " removes it and " .. table.concat(tl, ", ") .. " edit(s) it (the removal wins)")
    end
    if (r.mode or "hide") == "hide" then
      for _, c in ipairs(cards) do X.hidden[c] = true end
      VRFW.log.info(what .. ": " .. #cards .. " card(s) hidden")
      return nil
    end
    for _, card in ipairs(cards) do
      local i = X.param:find(PARAM_ROW, CP.id, card)
      if i then
        local b, _, le = X.param:list(PARAM_ROW)
        if not b then return le end
        local e = perr(X.param.remove_range, X.param, b, i, i + 1, 1)
        if e then return e end
      end
      X.hidden[card] = true
    end
    if created and r.card == nil then
      -- a creation of a mod: nothing of it is made
      local i = X.base:find(BASE_ROW, CB.id, chara)
      if i then
        local b, _, le = X.base:list(BASE_ROW)
        if not b then return le end
        local j = X.base:is(i + 1, BASE_REF) and i + 2 or i + 1
        local e = perr(X.base.remove_range, X.base, b, i, j, 1)
        if e then return e end
      end
      local icons = {}
      for _, x in ipairs(X.icons) do
        if x[1] ~= created.key then icons[#icons + 1] = x end
      end
      X.icons = icons
      for _, g in pairs(X.texts.groups) do
        local kept = {}
        for _, t in ipairs(g.rows) do
          if t.ckey ~= created.key then kept[#kept + 1] = t end
        end
        g.rows = kept
      end
      X.created[created.key] = nil
      X.removed_keys[created.key] = true
      VRFW.log.info(what .. ": " .. created.key .. " is not created")
    else
      VRFW.log.warn(what .. ": " .. #cards .. " card(s) deleted from chara_param (teams, saves or story scenes that use them may break: `mode = \"hide\"` keeps the data)")
    end
    return nil
  end

  -- ---------------------------------------------------------------- 0. the EVT layout, the templates of added cards
  do
    local w
    for _, f in ipairs(files) do
      local c = f.value.param_columns
      if c ~= nil and (w == nil or c > w) then w = c end
    end
    if w ~= nil then
      if w > 256 then
        VRFW.log.error("param_columns = " .. w .. ": at most 256")
      elseif X.param:widen(PARAM_ROW, w) then
        VRFW.log.info("chara_param rows widened to " .. w .. " columns (param_columns)")
      end
    end
    local h = VRFW.crc32(PARAM_ROW)
    for _, en in ipairs(X.param:entries(0, X.param:len())) do
      local id = en.values[CP.id + 1]
      if en.hash == h and type(id) == "number" then
        id = U.id(id)
        if not X.pristine[id] then X.pristine[id] = en end
      end
    end
  end

  local function by_name(list)
    return stable_sort(list, function(a, b) return VRFW.less(a.name, b.name) end)
  end

  -- 1. new characters (sorted by name inside a mod: ids do not depend on the file order)
  for _, f in ipairs(files) do
    for _, d in ipairs(by_name(f.value.character or {})) do
      local e = create(f.mod, f.file, d, f.value.default_lang)
      if e then VRFW.log.error(f.file .. ": character `" .. d.name .. "`: " .. e .. " (not created)") end
    end
  end
  -- 2. edits
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.edit or {}) do
      local chara, e = X.chara_ref(d.character, f.mod)
      if not chara then
        VRFW.log.error(f.file .. ": edit: " .. e .. " (skipped)")
      else
        local cards, skip
        if d.card ~= nil then
          local id = U.id(d.card)
          local i = X.param:find(PARAM_ROW, CP.id, id)
          if not i then
            VRFW.log.error(f.file .. ": edit " .. d.character .. ": card " .. idref_str(d.card) .. " not in chara_param (skipped)")
            skip = true
          else
            if X.param:uint(i, CP.chara) ~= chara then
              VRFW.log.warn(f.file .. ": edit " .. d.character .. ": card " .. idref_str(d.card) .. " belongs to another character")
            end
            cards = { id }
          end
        else
          cards = X.cards(chara)
        end
        if not skip then
          local what = f.file .. ": edit " .. X.label_of(chara)
          local c = X.created_by_chara(chara)
          local key = c and c.key or (f.mod .. ".edit." .. X.label_of(chara))
          local is_new = X.created[key] ~= nil
          X.apply(f.mod, what, chara, cards, fields(d), d.default_lang or f.value.default_lang, key, is_new, nil)
        end
      end
    end
  end
  -- 3. removals (delete_cards: the rows only)
  for _, f in ipairs(files) do
    local gone = 0
    for _, c in ipairs(f.value.delete_cards or {}) do
      local id = U.id(c)
      local i = X.param:find(PARAM_ROW, CP.id, id)
      if i then
        local b, _, le = X.param:list(PARAM_ROW)
        local e = le
        if b then e = perr(X.param.remove_range, X.param, b, i, i + 1, 1) end
        if e then
          VRFW.log.error(f.file .. ": delete_cards " .. idref_str(c) .. ": " .. e)
        else
          gone = gone + 1
        end
      else
        VRFW.log.warn(f.file .. ": delete_cards: card " .. idref_str(c) .. " is not in chara_param")
      end
    end
    if gone > 0 then VRFW.log.info(f.file .. ": " .. gone .. " card(s) deleted (delete_cards)") end
    for _, d in ipairs(f.value.remove or {}) do
      local e = remove(f.mod, f.file, d)
      if e then VRFW.log.error(f.file .. ": remove " .. d.character .. ": " .. e .. " (skipped)") end
    end
  end
  -- 4. recruit conditions (+ office rows)
  for _, f in ipairs(files) do
    local news = {}
    for _, d in ipairs(f.value.character or {}) do
      if d.recruit ~= nil then news[#news + 1] = d end
    end
    for _, d in ipairs(by_name(news)) do
      local key = f.mod .. "." .. d.name
      if X.created[key] then
        local e = O.recruit(X, f.mod, f.file, key, nil, d.recruit)
        if e then VRFW.log.error(f.file .. ": " .. key .. ": recruit: " .. e .. " (skipped)") end
      end
    end
    for _, d in ipairs(f.value.recruit or {}) do
      local e = O.recruit(X, f.mod, f.file, d.character, d.card, d)
      if e then VRFW.log.error(f.file .. ": recruit " .. d.character .. ": " .. e .. " (skipped)") end
    end
  end

  -- the declarations of `list` (traits / move grades) of every `[[character]]` and `[[edit]]` of a file:
  -- { who, card, list }
  local function vrfw_decls(f, field)
    local o = {}
    for _, d in ipairs(f.value.character or {}) do
      local l = d.vrfw and d.vrfw[field] or {}
      if #l > 0 then o[#o + 1] = { f.mod .. "." .. d.name, nil, l } end
    end
    for _, d in ipairs(f.value.edit or {}) do
      local l = d.vrfw and d.vrfw[field] or {}
      if #l > 0 then o[#o + 1] = { d.character, d.card ~= nil and U.id(d.card) or nil, l } end
    end
    return o
  end

  -- 5. trait tags (no cell: resolved to the character's cards as they are now, removals done)
  local traits = {}
  for _, f in ipairs(files) do
    for _, x in ipairs(vrfw_decls(f, "Traits")) do
      local who, card, list = x[1], x[2], x[3]
      local chara, e = X.chara_ref(who, f.mod)
      if not chara then
        VRFW.log.error(f.file .. ": traits of " .. who .. ": " .. e .. " (skipped)")
      else
        local tags = {}
        for _, t in ipairs(list) do
          local n = norm_trait(t)
          if n then
            if not U.contains(tags, n) then tags[#tags + 1] = n end
          else
            VRFW.log.warn(f.file .. ": traits of " .. who .. ": `" .. t .. "` is not a trait tag (a-z 0-9 _ . -; skipped)")
          end
        end
        if #tags > 0 then
          local cards = card ~= nil and { card } or X.cards(chara)
          local hit
          for _, t in ipairs(traits) do
            if t.chara == chara and same_list(t.cards, cards) then hit = t break end
          end
          if hit then
            for _, n in ipairs(tags) do
              if not U.contains(hit.traits, n) then hit.traits[#hit.traits + 1] = n end
            end
            if not U.contains(hit.mods, f.mod) then hit.mods[#hit.mods + 1] = f.mod end
          else
            traits[#traits + 1] = { chara = chara, cards = cards, traits = tags, mods = { f.mod } }
          end
        end
      end
    end
  end
  for _, t in ipairs(traits) do VRFW.sort(t.traits) end
  if #traits > 0 then
    local per = {}
    for _, t in ipairs(traits) do
      for _, n in ipairs(t.traits) do per[n] = (per[n] or 0) + 1 end
    end
    local parts = {}
    for _, n in ipairs(U.keys(per)) do parts[#parts + 1] = n .. " " .. per[n] end
    VRFW.log.info(#traits .. " character(s) with trait tags: " .. table.concat(parts, ", "))
  end
  -- 6. pre-evolved moves (no cell: resolved to the character's cards like the traits)
  local move_grades = {}
  for _, f in ipairs(files) do
    for _, x in ipairs(vrfw_decls(f, "MoveGrades")) do
      local who, card, list = x[1], x[2], x[3]
      local chara, e = X.chara_ref(who, f.mod)
      if not chara then
        VRFW.log.error(f.file .. ": move_grades of " .. who .. ": " .. e .. " (skipped)")
      else
        local grades = {}
        for _, g in ipairs(list) do
          local id = U.id(g.Move)
          local v = g.Grade
          if id ~= 0 and v >= 1 and v <= 5 and v == math.floor(v) then
            local hit
            for _, x2 in ipairs(grades) do
              if x2[1] == id then hit = x2 end
            end
            if hit then hit[2] = v else grades[#grades + 1] = { id, v } end
          else
            VRFW.log.warn(f.file .. ": move_grades of " .. who .. ": move " .. idref_str(g.Move) .. " grade " .. int_str(v) ..
              " (need a move and 1..5; skipped)")
          end
        end
        if #grades > 0 then
          local cards = card ~= nil and { card } or X.cards(chara)
          local hit
          for _, t in ipairs(move_grades) do
            if t.chara == chara and same_list(t.cards, cards) then hit = t break end
          end
          if hit then
            for _, gv in ipairs(grades) do
              local h2
              for _, x2 in ipairs(hit.grades) do
                if x2[1] == gv[1] then h2 = x2 end
              end
              if h2 then h2[2] = gv[2] else hit.grades[#hit.grades + 1] = { gv[1], gv[2] } end
            end
            if not U.contains(hit.mods, f.mod) then hit.mods[#hit.mods + 1] = f.mod end
          else
            move_grades[#move_grades + 1] = { chara = chara, cards = cards, grades = grades, mods = { f.mod } }
          end
        end
      end
    end
  end
  local ngrades = 0
  for _, t in ipairs(move_grades) do
    table.sort(t.grades, function(a, b)
      if a[1] ~= b[1] then return a[1] < b[1] end
      return a[2] < b[2]
    end)
    ngrades = ngrades + #t.grades
  end
  if #move_grades > 0 then
    VRFW.log.info(#move_grades .. " card set(s) with pre-evolved moves (" .. ngrades .. " move grades)")
  end
  do
    local e = O.office(X)
    if e then VRFW.log.error("office rows: " .. e) end
  end
  -- rows the engine appended, in their declared `order`
  if next(X.orders.B) or next(X.orders.P) or next(X.orders.M) then
    local errs = {}
    if next(X.orders.B) then
      errs[#errs + 1] = perr(X.base.reorder_tail, X.base, BASE_ROW, BASE_ROW, { BASE_REF }, X.orders.B, X.added.B)
    end
    if next(X.orders.P) then
      errs[#errs + 1] = perr(X.param.reorder_tail, X.param, PARAM_ROW, PARAM_ROW, {}, X.orders.P, X.added.P)
    end
    if next(X.orders.M) and X.model then
      errs[#errs + 1] = perr(X.model.reorder_tail, X.model, MODEL_ROW, MODEL_ROW, {}, X.orders.M, X.added.M)
    end
    for _, e in pairs(errs) do VRFW.log.error("row order: " .. e) end
  end

  -- ---------------------------------------------------------------- outputs
  for _, k in ipairs(U.keys(X.created)) do out.created[#out.created + 1] = X.created[k] end
  for _, c in ipairs(U.keys(X.recruits)) do out.recruits[#out.recruits + 1] = X.recruits[c] end
  for _, c in ipairs(U.keys(X.hidden)) do out.hidden[#out.hidden + 1] = c end
  for _, c in ipairs(U.keys(X.celebr)) do out.celebrations[#out.celebrations + 1] = X.celebr[c] end
  out.conflicts = X.conflicts
  out.traits = traits
  out.move_grades = move_grades
  out.icons = X.icons
  out.learn_cards = X.learn_cards
  -- texts: one group per (mod, default language), in load order
  for _, g in ipairs(X.texts.sorted(function(m) return X.load_index[m] or 0 end)) do
    local rows = {}
    for _, t in ipairs(g.rows) do
      rows[#rows + 1] = { table = t.table, id = t.id, variant = t.variant, texts = t.texts, add = t.add, origin = t.origin }
    end
    out.gentext[#out.gentext + 1] = { mod_id = g.mod, load_index = X.load_index[g.mod] or 0, default_lang = g.default, texts = rows }
  end
  return out
end
