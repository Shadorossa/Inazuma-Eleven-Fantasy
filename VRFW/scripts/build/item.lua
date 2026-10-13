-- Build script of the type `item` (docs/framework/build-scripts.md, docs/framework/types/item.md): every active mod's
-- item / shop declarations (load order) -> item_config, shop_config, common_item_table / soccer_prize_config rows,
-- the texts, the currencies, the reward tables and a per-mod report.
--
-- Order: (1) every mod's NEW items (sorted by name inside a mod: the ids do not depend on the file order), (2) every
-- [[edit]], (3) every [[remove]], (4) every [[currency]], (5) every [[shop]] and (6) every [[reward]] (shop.lua),
-- (7) the match loot tables' [[VRFW.DropPool]] / [[VRFW.DropAdd]] / [[VRFW.DropFilter]] (drops.lua),
-- each in load order. A cell two mods set to different values is a conflict: noted, the mod that loads later wins.
--
-- input = { items = { { file, mod, load_index, value = <items file> } }, shops = { … shops files … },
--           techniques = { { key, item, mod_id } }, drops = { … drops.lua's input … } }
-- returns the item type's value (item_engine::Built without its native parts).

local U = require "lib/util"
local C = require "lib/cond"
local S = require "shop"
local Drops = require "drops"

local ITEM_PREFIX = "data/common/gamedata/item/item_config_"
local SHOP_PREFIX = "data/common/gamedata/shop/shop_config_"
local LOOT_PREFIX = "data/common/gamedata/item/common_item_table_"
local PRIZE_PREFIX = "data/common/gamedata/soccer/soccer_prize_config_"

-- the item_config number space of catalog numbers (an item's bit in the 8192-bit item-get flags)
local CATALOG_SPACE = "item_catalog"
local CATALOG_LIMIT = 8192

local SUFFIXES = { "_REGULAR_UNIQUE_BASE", "_SERIES", "_REF_CND_ARY" }
local IMPORTANT = "ITEM_IMPORTANT_INFO"
local CND_ARY = "ITEM_IMPORTANT_CND_ARY"
local SKILL_LIST = "ITEM_SPECIAL_SKILL_INFO"
local CONSUME = "ITEM_CONSUME_INFO"
local WEARABLE = { ITEM_SHOES_INFO = true, ITEM_MISANGA_INFO = true, ITEM_FASHION_INFO = true, ITEM_COSTUME_INFO = true }

-- category word -> item_config list (several words name one list)
local CATEGORY = {
  shoes = "ITEM_SHOES_INFO", bracelet = "ITEM_MISANGA_INFO", gloves = "ITEM_MISANGA_INFO",
  pendant = "ITEM_ACCESSORY_INFO", accessory = "ITEM_ACCESSORY_INFO", special = "ITEM_SPECIAL_INFO",
  consumable = "ITEM_CONSUME_INFO", currency = "ITEM_CONSUME_INFO", kit = "ITEM_FASHION_INFO",
  costume = "ITEM_COSTUME_INFO", key = "ITEM_IMPORTANT_INFO", collectible = "ITEM_IMPORTANT_INFO",
  emblem = "ITEM_EMBLEM_INFO", title = "ITEM_TITLE_INFO", name_plate = "ITEM_NAME_PLATE_INFO",
  craft = "ITEM_CRAFT_OBJ_INFO",
}
-- the canonical word of a list
local WORD = {
  ITEM_SHOES_INFO = "shoes", ITEM_MISANGA_INFO = "bracelet", ITEM_ACCESSORY_INFO = "pendant",
  ITEM_SPECIAL_INFO = "special", ITEM_CONSUME_INFO = "consumable", ITEM_FASHION_INFO = "kit",
  ITEM_COSTUME_INFO = "costume", ITEM_IMPORTANT_INFO = "key", ITEM_EMBLEM_INFO = "emblem",
  ITEM_TITLE_INFO = "title", ITEM_NAME_PLATE_INFO = "name_plate", ITEM_CRAFT_OBJ_INFO = "craft",
  ITEM_SPECIAL_SKILL_INFO = "technique",
}
local function of_list(l) return WORD[l] or "other" end

-- the stats of an equipment item: its _REGULAR_UNIQUE_BASE companion row, in this order
local STATS = { "kick", "control", "technique", "pressure", "physical", "agility", "intelligence" }

-- The shared layout of the 21 ITEM_*_INFO lists (schemas/item/item_*.toml): a column by its schema name; a list
-- whose schema does not name it falls back to the shared layout's position.
local LAYOUT = { id = 0, reserved_1 = 1, name_text = 2, desc_text = 3, catalog_no = 4, max_stack = 7, key = 11,
  rarity = 12, base_item = 14, icon_index = 15, uniform = 18 }

return function(input)
  local X = {
    claims = {}, list_of = {}, by_key = {}, ids_used = {}, text_used = {}, catalog_used = {}, created = {},
    removed_keys = {}, hidden = {}, currencies = {}, item_price = {}, shops_out = {}, new_shops = {}, rewards = {},
    report = {}, conflicts = {}, load_index = {}, texts = U.text_groups(),
    techs = { by_name = {}, ids = {}, mods = input.techniques or {} },
    cols = {},
  }
  X.U, X.C, X.of_list = U, C, of_list

  -- ---------------------------------------------------------------- columns
  function X.ic(list, name)
    local c = X.cols[list]
    if not c then c = {} X.cols[list] = c end
    if c[name] == nil then
      local ok, i = pcall(function() return X.item:col(list, name) end)
      c[name] = ok and i or LAYOUT[name]
    end
    return c[name]
  end

  -- ---------------------------------------------------------------- report and notes
  function X.rep(m)
    local r = X.report[m]
    if not r then
      r = { mod_id = m, items_new = 0, items_edited = 0, items_removed = 0, currencies = 0, shops = 0, shop_rows = 0,
        rewards = 0, errors = {}, warnings = {} }
      X.report[m] = r
    end
    return r
  end
  function X.err(m, s)
    local r = X.rep(m)
    r.errors[#r.errors + 1] = s
    VRFW.log.error(s)
  end
  function X.warn(m, s)
    local r = X.rep(m)
    r.warnings[#r.warnings + 1] = s
    VRFW.log.warn(s)
  end
  function X.conflict(m, msg)
    X.warn(m, msg)
    X.conflicts[#X.conflicts + 1] = msg
  end

  -- `t` = the table kind (item, stats, shop, row), `row` = its id, `col` = the column
  function X.claim(t, row, col, m, v, what)
    local k = t .. ":" .. string.format("%.0f", row) .. ":" .. tostring(col)
    local s = U.show(v)
    local old = X.claims[k]
    if old and old.by ~= m and old.val ~= s then
      X.conflict(m, string.format("item conflict: %s: mod %s = %s, mod %s = %s (winner: %s, loads later)", what, old.by, old.val, m, s, m))
    end
    X.claims[k] = { t = t, row = row, col = col, by = m, val = s }
  end

  -- ---------------------------------------------------------------- items
  function X.row_of(id)
    local list = X.list_of[id]
    if not list then return nil end
    local i = X.item:find(list, X.ic(list, "id"), id)
    if not i then return nil end
    return list, i
  end

  -- end (exclusive) of the row at `i` and its companion rows
  function X.companions_end(i, list)
    local names = {}
    for k, s in ipairs(SUFFIXES) do names[k] = list .. s end
    return U.block_end(X.item, i, names)
  end

  -- the item id of a reference: a creation (`<mod>.<name>` or `<name>` of `m`), an internal key, an id
  function X.item_ref(s, m)
    s = U.trim(s)
    local c = X.created[s] or X.created[m .. "." .. s]
    if c then return c.id end
    if X.removed_keys[s] or X.removed_keys[m .. "." .. s] then
      return nil, "item `" .. s .. "` was deleted by a [[remove]]"
    end
    if X.by_key[s] then return X.by_key[s] end
    local id = VRFW.ids.parse(s)
    if X.list_of[id] then return id end
    return nil, "item `" .. s .. "` is not in item_config (write a game internal name like eq_sh110001, its id, or a mod's <mod>.<name>)"
  end

  function X.created_by_id(id)
    for _, k in ipairs(U.keys(X.created)) do
      if X.created[k].id == id then return X.created[k] end
    end
  end

  function X.label_of(id)
    local c = X.created_by_id(id)
    if c then return c.key end
    local list, i = X.row_of(id)
    if list then
      local k = X.item:str(i, X.ic(list, "key"))
      if k then return k .. " (" .. U.hex(id) .. ")" end
    end
    return U.hex(id)
  end

  -- set column `col` (a name) of item `id`'s row (`t` = "item") or stat row (`t` = "stats")
  function X.set_item(t, id, col, v, m, what)
    local list, i = X.row_of(id)
    if not list then return what .. ": item " .. U.hex(id) .. " not found" end
    local at = i
    if t == "stats" then
      local name = list .. "_REGULAR_UNIQUE_BASE"
      if X.item:is(i + 1, name) then
        at = i + 1
      else
        -- an equipment row without its stat row (retail: one bracelet): it gets a zeroed one
        local proto = X.item:rows(name)[1]
        if not proto then
          return of_list(list) .. " items have no stats (only boots, bracelets, pendants and specials do)"
        end
        local p = X.item:entry(proto)
        for k in ipairs(p.values) do p.values[k] = 0 end
        X.item:splice(i + 1, i + 1, { p })
        at = i + 1
      end
    end
    X.claim(t, id, col, m, v, what)
    if type(col) == "string" and t ~= "stats" then col = X.ic(list, col) end
    X.item:set(at, col, v)
  end

  function X.push_text(m, d, row)
    X.texts.push(m, d, row)
  end

  function X.new_text_id(key)
    local id = VRFW.ids.assign("text:" .. key, X.text_used)
    X.text_used[id] = true
    return id
  end

  -- name -> `table` noun row `name_id`; description -> `item_text` text row `desc_id`
  function X.texts_of(m, what, tbl, name_id, desc_id, text, default, add_name, add_desc)
    for _, l in ipairs(U.keys(text)) do
      if not VRFW.lang.norm_or_all(l) then
        X.warn(m, what .. ": text." .. l .. ": not a language (" .. table.concat(VRFW.lang.list(), ", ") .. ", all): ignored")
      end
    end
    local origin = what .. " (" .. m .. ")"
    local names, any_name = U.pick_langs(text, function(t) return t.name end)
    if any_name and name_id ~= 0 then
      X.push_text(m, default, { table = tbl, id = name_id, variant = 0, texts = names, add = add_name, origin = origin, kind = "noun" })
    end
    local descs, any_desc = U.pick_langs(text, function(t) return t.description end)
    if any_desc then
      if desc_id and desc_id ~= 0 then
        X.push_text(m, default, { table = "item_text", id = desc_id, variant = 0, texts = descs, add = add_desc, origin = origin, kind = "text" })
      else
        X.warn(m, what .. ": a description has no row here (skipped)")
      end
    end
  end

  local function any_text(text, field)
    for _, t in pairs(text or {}) do
      if t[field] ~= nil and U.trim(t[field]) ~= "" then return true end
    end
    return false
  end

  -- ---------------------------------------------------------------- fields (new and edit)
  function X.apply(m, what, id, f, default_lang, key, is_new)
    local errs = {}
    local function try(e) if e then errs[#errs + 1] = e end end
    local list = X.row_of(id)
    if not list then return end
    if f.rarity ~= nil then
      if f.rarity >= 1 and f.rarity <= 2 then
        try(X.set_item("item", id, "rarity", f.rarity, m, what .. ".rarity"))
      else
        errs[#errs + 1] = "rarity " .. f.rarity .. ": 1-2 (the game's plates; 3+ shows a blank white icon)"
      end
    end
    if f.max_stack ~= nil then
      if f.max_stack >= 1 and f.max_stack <= 99999 then
        try(X.set_item("item", id, "max_stack", f.max_stack, m, what .. ".max_stack"))
      else
        errs[#errs + 1] = "max_stack " .. f.max_stack .. ": 1-99999"
      end
    end
    if f.icon ~= nil then
      local x, e = X.item_ref(f.icon, m)
      local ilist, ii
      if x then
        ilist, ii = X.row_of(x)
        if not ilist then e = "not found" end
      end
      if ilist then
        local k = X.item:str(ii, X.ic(ilist, "key"))
        if k then try(X.set_item("item", id, "key", k, m, what .. ".icon")) end
        local n = X.item:int(ii, X.ic(ilist, "icon_index"))
        if n then try(X.set_item("item", id, "icon_index", n, m, what .. ".icon")) end
        if ilist ~= list then
          VRFW.log.debug(what .. ": icon from another list (" .. of_list(ilist) .. " → " .. of_list(list) .. ")")
        end
      else
        errs[#errs + 1] = "icon: " .. e
      end
    end
    if f.icon_key ~= nil then
      local k = U.trim(f.icon_key)
      if k == "" or #k > 31 or k:find("[^a-z0-9_]") then
        errs[#errs + 1] = "icon_key `" .. k .. "`: a texture name (a-z 0-9 _, at most 31 characters)"
      else
        try(X.set_item("item", id, "key", k, m, what .. ".icon_key"))
      end
    end
    if f.model ~= nil then
      if not WEARABLE[list] then
        errs[#errs + 1] = "model: " .. of_list(list) .. " items have no model (boots, bracelets, kits and costumes do)"
      else
        local u, e
        if type(f.model) == "table" then
          u = U.id(f.model.uniform)
        else
          local x
          x, e = X.item_ref(f.model, m)
          if x then
            local ml, mi = X.row_of(x)
            if not ml then
              e = "not found"
            else
              local v = X.item:uint(mi, X.ic(ml, "uniform"))
              if v and v ~= 0 then u = v else e = "`" .. f.model .. "` has no model" end
            end
          end
        end
        if u then
          try(X.set_item("item", id, "uniform", u, m, what .. ".model"))
        else
          errs[#errs + 1] = "model: " .. e
        end
      end
    end
    if f.stats ~= nil then
      for _, s in ipairs(STATS) do
        local v = f.stats[s]
        if v ~= nil then
          if v < -9999 or v > 9999 then
            errs[#errs + 1] = "stats: " .. v .. " out of -9999..9999"
          else
            try(X.set_item("stats", id, s, v, m, what .. ".stats"))
          end
        end
      end
    end
    if f.price ~= nil or f.currency ~= nil then
      local old = X.item_price[id]
      if old and old.by ~= m and ((f.price ~= nil and f.price ~= old.p) or (f.currency ~= nil and f.currency ~= old.c)) then
        X.conflict(m, string.format("item conflict: %s.price: mod %s = %s %s, mod %s = %s %s (winner: %s, loads later)", what, old.by,
          U.opt(old.p), U.opt(old.c), m, U.opt(f.price), U.opt(f.currency), m))
      end
      local p0, c0 = nil, nil
      if old then p0, c0 = old.p, old.c end
      local p, c = f.price, f.currency
      if p == nil then p = p0 end
      if c == nil then c = c0 end
      X.item_price[id] = { p = p, c = c, by = m }
    end
    if (f.owned_when and #f.owned_when > 0) or (is_new and list == IMPORTANT) then
      if list ~= IMPORTANT then
        errs[#errs + 1] = "owned_when: only key items (category key) have ownership conditions, not " .. of_list(list)
      else
        try(X.key_condition(m, what, id, f.owned_when or {}))
      end
    end
    if not U.is_empty(f.text) then
      local d = U.norm_default(default_lang, f.text)
      local _, i = X.row_of(id)
      local name_id = X.item:uint(i, X.ic(list, "name_text")) or 0
      local desc_id = X.item:uint(i, X.ic(list, "desc_text")) or 0
      local add_desc = is_new
      if any_text(f.text, "description") and desc_id == 0 then
        -- an existing item without a description row: it gets its own
        desc_id = X.new_text_id(key .. "#desc")
        try(X.set_item("item", id, "desc_text", desc_id, m, what .. ".description"))
        add_desc = true
      end
      local has_name = false
      for _, t in pairs(f.text) do if t.name ~= nil then has_name = true end end
      if name_id == 0 and has_name then errs[#errs + 1] = "this item has no name row" end
      X.texts_of(m, what, "item_text", name_id, desc_id, f.text, d, is_new, add_desc)
    end
    -- sorted, duplicates once (Rust sort + dedup)
    VRFW.sort(errs)
    local last
    for _, e in ipairs(errs) do
      if e ~= last then
        last = e
        if e:sub(1, #what) ~= what then e = what .. ": " .. e end
        X.err(m, e)
      end
    end
  end

  -- Key item ownership: a new ITEM_IMPORTANT_CND_ARY row (the clauses OR the item's own item-get flag) and the
  -- item's _REF_CND_ARY slice pointed at it.
  function X.key_condition(m, what, id, clauses)
    local groups = {}
    local resolver = function(r) return X.item_ref(r, m) end
    for k, c in ipairs(clauses) do
      local g, e = C.encode(c, resolver)
      if not g then return "owned_when[" .. (k - 1) .. "]: " .. e end
      groups[#groups + 1] = g
    end
    groups[#groups + 1] = VRFW.cond.group("GetGlobalItemGetBitFlag", { { id, true } }, 1, VRFW.cond.EQ)
    local c, e = VRFW.cond.join(groups, "any")
    if not c then return e end
    local rows = X.item:rows(CND_ARY)
    if not rows[1] then return "item_config has no ITEM_IMPORTANT_CND_ARY row" end
    local proto = X.item:entry(rows[1])
    local offset
    for k, i in ipairs(rows) do
      if X.item:str(i, "condition") == c then offset = k - 1 break end
    end
    if not offset then
      local row = U.copy_entry(proto)
      local first = proto.values[1]
      if first == nil then first = VRFW.crc32("condition0") end
      row.values = { first, c }
      X.item:append_rows(CND_ARY, { CND_ARY }, { row }, 1)
      offset = #rows
    end
    local _, i = X.row_of(id)
    if not i then return "item not found" end
    if not X.item:is(i + 1, IMPORTANT .. "_REF_CND_ARY") then return "this key item has no condition slice" end
    X.claim("item", id, 1000, m, c, what .. ".owned_when")
    X.item:set(i + 1, "offset", offset)
    X.item:set(i + 1, "count", 1)
  end

  -- ---------------------------------------------------------------- new items, removals, currencies
  function X.create(m, file, d, file_default)
    local key, e = VRFW.ids.own(m, d.name)
    if not key then return e end
    if X.created[key] then return "`" .. key .. "` is declared twice (the first is kept)" end
    local base
    if d.base ~= nil then
      local id, e2 = X.item_ref(d.base, m)
      if not id then return "base: " .. e2 end
      local list = X.list_of[id]
      if d.category ~= nil and CATEGORY[d.category] ~= list then
        return "category `" .. of_list(CATEGORY[d.category]) .. "` but base `" .. d.base .. "` is " .. of_list(list) .. " (" .. list .. ")"
      end
      base = id
    elseif d.category ~= nil then
      local list = CATEGORY[d.category]
      for _, i in ipairs(X.item:rows(list)) do
        local x = X.item:uint(i, X.ic(list, "id"))
        if x and x ~= 0 then base = x break end
      end
      if not base then return "no item of category `" .. of_list(list) .. "` to clone" end
    else
      return "give `base` (the game item it is cloned from) or `category`"
    end
    local list, bi = X.row_of(base)
    if not list then return "base not found" end
    if list == SKILL_LIST then
      return "techniques are created by the technique engine (a shop / reward sells them with `technique = …`)"
    end
    local id = VRFW.ids.assign(key, X.ids_used)
    X.ids_used[id] = true
    local name_text = X.new_text_id(key .. "#name")
    local desc_text = 0
    if any_text(d.text, "description") then desc_text = X.new_text_id(key .. "#desc") end
    -- migration only: the catalog number the old rule gave (registered for old saves, never written)
    local old = VRFW.ids.slot("catalog:" .. key, 7700, 8100, X.legacy_catalog)
    if old then
      X.legacy_catalog[old] = true
      VRFW.ids.legacy(CATALOG_SPACE, key, old)
    end
    if not X.catalog_lo then return "no catalog number (the game's item_config: " .. X.catalog_err .. ")" end
    -- above the game's numbers first; when full, the holes below them (numbers no game item uses)
    local catalog, w = VRFW.ids.next(CATALOG_SPACE, key, X.catalog_used, X.catalog_lo, X.catalog_hi, 1)
    if w then X.warn(m, w) end
    if not catalog then return "no free catalog number (" .. X.catalog_lo .. "-" .. (CATALOG_LIMIT - 1) .. " nor a free one below)" end
    X.catalog_used[catalog] = true
    local stop = X.companions_end(bi, list)
    local rows = X.item:entries(bi, stop)
    local v = rows[1].values
    v[X.ic(list, "id") + 1] = id
    v[X.ic(list, "name_text") + 1] = name_text
    v[X.ic(list, "desc_text") + 1] = desc_text
    v[X.ic(list, "catalog_no") + 1] = catalog
    if #v > X.ic(list, "base_item") then v[X.ic(list, "base_item") + 1] = 0 end
    if #v > 1 then v[X.ic(list, "reserved_1") + 1] = 0 end
    local names = { list }
    for _, s in ipairs(SUFFIXES) do names[#names + 1] = list .. s end
    X.item:append_rows(list, names, rows, 1)
    X.list_of[id] = list
    X.created[key] = { key = key, mod_id = m, id = id, list = list, category = of_list(list), base = base, catalog = catalog,
      name_text = name_text, desc_text = desc_text }
    X.rep(m).items_new = X.rep(m).items_new + 1
    local what = file .. ": " .. key
    X.apply(m, what, id, d, d.default_lang or file_default, key, true)
    if not any_text(d.text, "name") then
      X.warn(m, what .. ": no [item.text.<lang>] name: the new item shows no name")
    end
  end

  function X.remove(m, file, r)
    local id, e = X.item_ref(r.item, m)
    if not id then return e end
    local what = file .. ": remove " .. X.label_of(id)
    local touched = {}
    for _, c in pairs(X.claims) do
      if c.row == id and c.by ~= m then touched[c.by] = true end
    end
    local tl = U.keys(touched)
    if #tl > 0 then
      X.conflict(m, "item conflict: " .. what .. ": mod " .. m .. " removes it and " .. table.concat(tl, ", ") .. " edit(s) it (the removal wins)")
    end
    X.hidden[id] = m
    X.rep(m).items_removed = X.rep(m).items_removed + 1
    if (r.mode or "hide") == "hide" then
      VRFW.log.info(what .. ": hidden (shop rows hidden, left out of the engine's reward tables)")
    else
      local list, i = X.row_of(id)
      if not list then return "not found" end
      local j = X.companions_end(i, list)
      local b, _, le = X.item:list(list)
      if not b then return le end
      X.item:remove_range(b, i, j, 1)
      X.list_of[id] = nil
      local c = X.created_by_id(id)
      if c then
        X.created[c.key] = nil
        X.removed_keys[c.key] = true
        for _, g in pairs(X.texts.groups) do
          local kept = {}
          for _, t in ipairs(g.rows) do
            if t.id ~= c.name_text and t.id ~= c.desc_text then kept[#kept + 1] = t end
          end
          g.rows = kept
        end
        VRFW.log.info(what .. ": " .. c.key .. " is not created")
      else
        X.warn(m, what .. ": deleted from item_config (saves, teams or scripts that hold it may break: `mode = \"hide\"` keeps the data)")
      end
    end
  end

  function X.currency(m, file, c, file_default)
    local key, e = VRFW.ids.own(m, c.name)
    if not key then return e end
    if X.currencies[key] then return "`" .. key .. "` is declared twice" end
    local labels = {}
    for _, l in ipairs(U.keys(c.label or {})) do
      local n = VRFW.lang.norm_or_all(l)
      if n then labels[n] = c.label[l] end
    end
    local out
    if c.item ~= nil and c.spirit == nil then
      local id, e2 = X.item_ref(c.item, m)
      if not id then return e2 end
      local list = X.list_of[id] or ""
      if list ~= CONSUME then
        X.warn(m, file .. ": currency " .. key .. ": `" .. c.item .. "` is " .. of_list(list) .. " (the game's currencies are consumables of category 220)")
      end
      if not U.is_empty(labels) then
        -- the label renames the item (its name row)
        local il, i = X.row_of(id)
        if il then
          local name_id = X.item:uint(i, X.ic(il, "name_text")) or 0
          local text = {}
          for l, s in pairs(labels) do text[l] = { name = s } end
          local is_new = X.created_by_id(id) ~= nil
          X.texts_of(m, file .. ": currency " .. key, "item_text", name_id, nil, text, U.norm_default(file_default, text), is_new, false)
        end
      end
      out = { key = key, mod_id = m, kind = "item", item = id, spirit = 0, rarity = 0, labels = labels }
    elseif c.item == nil and c.spirit ~= nil then
      local r = c.rarity or 4
      if r > 8 then return "rarity " .. r .. ": 0-8" end
      out = { key = key, mod_id = m, kind = "spirit", item = 0, spirit = U.id(c.spirit), rarity = r, labels = labels }
    else
      return "write either `item = …` (a token) or `spirit = …` (a card)"
    end
    X.currencies[key] = out
    X.rep(m).currencies = X.rep(m).currencies + 1
  end

  -- a currency reference: a declared currency (`<mod>.<name>` / `<name>` of `m`) or an item (a token)
  -- returns { kind = "item", id } / { kind = "spirit", spirit, rarity }, or nil, err
  function X.currency_ref(s, m)
    s = U.trim(s)
    local c = X.currencies[s] or X.currencies[m .. "." .. s]
    if c then
      if c.kind == "spirit" then return { kind = "spirit", spirit = c.spirit, rarity = c.rarity } end
      return { kind = "item", id = c.item }
    end
    local id = X.item_ref(s, m)
    if id then return { kind = "item", id = id } end
    return nil, "currency `" .. s .. "`: not a declared currency ([[currency]]) nor an item"
  end

  -- a technique reference (a game skill `whs00010` / id, or a technique mod's `<mod>.<name>`)
  function X.technique(r, from)
    r = U.trim(r)
    local own = from .. "." .. r
    for _, t in ipairs(X.techs.mods) do
      if t.key == r or t.key == own then return t end
    end
    if X.techs.by_name[r] then return { key = r, item = X.techs.by_name[r], mod_id = "" } end
    local id = VRFW.ids.parse(r)
    if X.techs.ids[id] then return { key = r, item = id, mod_id = "" } end
    if r:find(".", 1, true) then
      return nil, "technique `" .. r .. "`: no active mod created it (the technique engine publishes the mods' techniques; is it on and the mod enabled?)"
    end
    return nil, "technique `" .. r .. "`: not a technique of the game (ITEM_SPECIAL_SKILL_INFO: write its internal name, e.g. whs00010, or its id)"
  end

  -- ---------------------------------------------------------------- the build
  local function is_items_empty(v)
    return #(v.item or {}) == 0 and #(v.edit or {}) == 0 and #(v.remove or {}) == 0 and #(v.currency or {}) == 0
  end
  local function is_shops_empty(v)
    return #(v.shop or {}) == 0 and #(v.reward or {}) == 0
  end
  -- stable sort by load index
  local function by_load(files, empty)
    local v = {}
    for k, f in ipairs(files or {}) do
      if not empty(f.value) then v[#v + 1] = { f = f, k = k } end
    end
    table.sort(v, function(a, b)
      if a.f.load_index ~= b.f.load_index then return a.f.load_index < b.f.load_index end
      return a.k < b.k
    end)
    local out = {}
    for _, x in ipairs(v) do out[#out + 1] = x.f end
    return out
  end
  local ifiles = by_load(input.items, is_items_empty)
  local sfiles = by_load(input.shops, is_shops_empty)
  local order = {}
  for _, f in ipairs(ifiles) do order[#order + 1] = { f.load_index, f.mod } end
  for _, f in ipairs(sfiles) do order[#order + 1] = { f.load_index, f.mod } end
  table.sort(order, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    return VRFW.less(a[2], b[2])
  end)
  local mods = {}
  for _, o in ipairs(order) do
    if not U.contains(mods, o[2]) then mods[#mods + 1] = o[2] end
  end
  local out = { mods = mods, created = {}, hidden = {}, currencies = {}, shops = {}, rewards = {}, report = {}, conflicts = {},
    gentext = {}, notes = {} }
  if #mods == 0 then return out end

  local function key_or(prefix)
    local k, e = VRFW.rows.key(prefix)
    return { key = k, err = e }
  end
  X.shop_key = key_or(SHOP_PREFIX)
  X.loot_key = key_or(LOOT_PREFIX)
  X.prize_key = key_or(PRIZE_PREFIX)
  do
    local k, e = VRFW.rows.key(ITEM_PREFIX)
    local t
    if k then t, e = VRFW.rows.open(k) end
    if not t then
      VRFW.log.error(e .. ": no item data is built")
      return out
    end
    X.item = t
  end

  -- index the items (every ITEM_*_INFO row with a key string)
  local function scan(t, f)
    for i = 0, t:len() - 1 do
      local name = t:name(i)
      if name and name:sub(1, 5) == "ITEM_" and name:sub(-5) == "_INFO" and t:width(i) > LAYOUT.key then
        local k = t:str(i, LAYOUT.key)
        local id = t:uint(i, LAYOUT.id)
        if k and id then f(name, i, k, id) end
      end
    end
  end
  scan(X.item, function(name, i, k, id)
    X.list_of[id] = name
    if X.by_key[k] == nil then X.by_key[k] = id end
    X.ids_used[id] = true
    for _, c in ipairs { LAYOUT.name_text, LAYOUT.desc_text } do
      local t = X.item:uint(i, c)
      if t and t ~= 0 then X.text_used[t] = true end
    end
    local c = X.item:uint(i, LAYOUT.catalog_no)
    if c and c ~= 0 then X.catalog_used[c] = true end
    if name == SKILL_LIST then
      X.techs.by_name[k] = id
      X.techs.ids[id] = true
    end
  end)
  -- free catalog numbers: above the highest one of the GAME's own item_config (below the limit)
  do
    local k, e = VRFW.rows.key(ITEM_PREFIX)
    local g
    if k then g, e = VRFW.rows.game(k) end
    if g then
      local used = {}
      scan(g, function(_, i)
        local c = g:uint(i, LAYOUT.catalog_no)
        if c and c ~= 0 and c < CATALOG_LIMIT then used[c] = true end
      end)
      X.catalog_lo, X.catalog_hi = VRFW.ids.free_above(used, CATALOG_LIMIT)
    else
      X.catalog_err = e
    end
  end
  X.legacy_catalog = U.copy(X.catalog_used)
  for _, f in ipairs(ifiles) do X.load_index[f.mod] = f.load_index end
  for _, f in ipairs(sfiles) do X.load_index[f.mod] = f.load_index end
  for _, m in ipairs(mods) do X.rep(m) end

  -- 1. new items (sorted by name inside a mod)
  for _, f in ipairs(ifiles) do
    local news = {}
    for k, d in ipairs(f.value.item or {}) do news[#news + 1] = { d = d, k = k } end
    table.sort(news, function(a, b)
      if a.d.name ~= b.d.name then return VRFW.less(a.d.name, b.d.name) end
      return a.k < b.k
    end)
    for _, x in ipairs(news) do
      local e = X.create(f.mod, f.file, x.d, f.value.default_lang)
      if e then X.err(f.mod, f.file .. ": item `" .. x.d.name .. "`: " .. e .. " (not created)") end
    end
  end
  -- 2. edits
  for _, f in ipairs(ifiles) do
    for _, d in ipairs(f.value.edit or {}) do
      local id, e = X.item_ref(d.item, f.mod)
      if not id then
        X.err(f.mod, f.file .. ": edit: " .. e .. " (skipped)")
      else
        local what = f.file .. ": edit " .. X.label_of(id)
        local c = X.created_by_id(id)
        local key = c and c.key or (f.mod .. ".edit." .. U.hex8(id))
        local is_new = X.created[key] ~= nil
        X.rep(f.mod).items_edited = X.rep(f.mod).items_edited + 1
        X.apply(f.mod, what, id, d, d.default_lang or f.value.default_lang, key, is_new)
      end
    end
  end
  -- 3. removals
  for _, f in ipairs(ifiles) do
    for _, d in ipairs(f.value.remove or {}) do
      local e = X.remove(f.mod, f.file, d)
      if e then X.err(f.mod, f.file .. ": remove " .. d.item .. ": " .. e .. " (skipped)") end
    end
  end
  -- 4. currencies
  for _, f in ipairs(ifiles) do
    for _, d in ipairs(f.value.currency or {}) do
      local e = X.currency(f.mod, f.file, d, f.value.default_lang)
      if e then X.err(f.mod, f.file .. ": currency `" .. d.name .. "`: " .. e .. " (skipped)") end
    end
  end
  -- an item's default currency must exist
  for _, id in ipairs(U.keys(X.item_price)) do
    local p = X.item_price[id]
    if p.c then
      local _, e = X.currency_ref(p.c, p.by)
      if e then X.err(p.by, "item " .. X.label_of(id) .. ": " .. e) end
    end
  end
  -- 5. shops, 6. rewards (shop.lua)
  S.build(X, sfiles)
  -- 7. the match loot tables: [[VRFW.DropPool]] / [[VRFW.DropAdd]] / [[VRFW.DropFilter]] (drops.lua)
  Drops.build(X, input.drops or {})

  -- ---- outputs
  local gens = {}
  for _, g in ipairs(X.texts.sorted(function(m) return X.load_index[m] or 0 end)) do
    gens[#gens + 1] = { mod_id = g.mod, load_index = X.load_index[g.mod] or 0, default_lang = g.default, texts = g.rows }
  end
  local ntext = 0
  for _, g in ipairs(gens) do ntext = ntext + #g.texts end
  local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
  local nfiles = 0
  for _, t in pairs { X.item, X.shop or false, X.loot or false, X.prize or false } do
    if t and t:changed() then nfiles = nfiles + 1 end
  end
  VRFW.log.info(string.format(
    "%d mod(s) with items / shops (%s): %d new item(s), %d currenc(y/ies), %d shop(s), %d reward table(s), %d hidden item(s), %d file(s) built, %d text row(s) for the text engine",
    #mods, table.concat(mods, ", "), count(X.created), count(X.currencies), count(X.shops_out), count(X.rewards), count(X.hidden),
    nfiles, ntext))
  out.conflicts = X.conflicts
  out.gentext = gens
  for _, k in ipairs(U.keys(X.created)) do out.created[#out.created + 1] = X.created[k] end
  for _, id in ipairs(U.keys(X.hidden)) do out.hidden[#out.hidden + 1] = id end
  for _, k in ipairs(U.keys(X.currencies)) do out.currencies[#out.currencies + 1] = X.currencies[k] end
  for _, id in ipairs(U.keys(X.shops_out)) do out.shops[#out.shops + 1] = X.shops_out[id] end
  for _, k in ipairs(U.keys(X.rewards)) do out.rewards[#out.rewards + 1] = X.rewards[k] end
  local reps = {}
  for _, k in ipairs(U.keys(X.report)) do
    local pos = #mods + 1
    for i, m in ipairs(mods) do if m == k then pos = i end end
    reps[#reps + 1] = { r = X.report[k], pos = pos, k = #reps }
  end
  table.sort(reps, function(a, b)
    if a.pos ~= b.pos then return a.pos < b.pos end
    return a.k < b.k
  end)
  for _, x in ipairs(reps) do out.report[#out.report + 1] = x.r end
  return out
end
