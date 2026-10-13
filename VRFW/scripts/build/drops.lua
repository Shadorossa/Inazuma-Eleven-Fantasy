-- The match loot tables' services of the type `item` (docs/framework/drops.md), run by item.lua after the shops and
-- rewards: `[[VRFW.DropPool]]` (a mod names a group of its loot tables), `[[VRFW.DropAdd]]` (another mod appends an
-- item to every table of a pool) and `[[VRFW.DropFilter]]` (while the declaring mod is active, no match drop gives the
-- excluded items). The tables are `win_treasure_lot_table_config`'s ITBL tables (what an in-match drop rarity
-- resolves to through the game's decide tables), as the game, the base tables and the earlier types served them.
--
-- input.drops = { { file, mod, load_index, pools = { { name, tables } }, adds = { { pool, item, count, weight,
--                   if_mod } }, filters = { { exclude, categories, items, keep, replace_with } } } }   (load order)
local U = require "lib/util"
local D = {}

local LOOT_PREFIX = "data/common/gamedata/item/win_treasure_lot_table_config_"
local SHOP_PREFIX = "data/common/gamedata/shop/shop_config_"
local PRICE_SLOTS = 9

-- every loot table: { { id, base = <ITBL_BASE entry>, entries = { { item, count, weight, cond, extra } } } } in file
-- order, or nil, err
local function read_tables(t)
  local items = t:rows("ITBL_ITEMS")
  local out = {}
  for _, bi in ipairs(t:rows("ITBL_BASE")) do
    if t:is(bi + 1, "ITBL_BASE_REF_ITEMS") then
      local off, n = t:int(bi + 1, 0) or 0, t:int(bi + 1, 1) or 0
      if off < 0 or n < 0 or off + n > #items then return nil, "ITBL " .. U.hex(t:uint(bi, 0) or 0) .. ": slice out of range" end
      local es = {}
      for k = off + 1, off + n do
        local e = t:entry(items[k])
        es[#es + 1] = e
      end
      out[#out + 1] = { id = t:uint(bi, 0) or 0, entries = es }
    end
  end
  return out
end

-- write `tabs` back: one ITBL_ITEMS run per table, in order (tables that share a slice get their own copy)
local function write_tables(t, tabs)
  local beg, fin = t:list("ITBL_ITEMS")
  if not beg then return "no ITBL_ITEMS list" end
  local rows = {}
  local refs = {}
  for k, x in ipairs(tabs) do
    refs[k] = { #rows, #x.entries }
    for _, e in ipairs(x.entries) do rows[#rows + 1] = e end
  end
  t:splice(beg + 1, fin, rows)
  t:set(beg, 0, #rows)
  local k = 0
  for _, bi in ipairs(t:rows("ITBL_BASE")) do
    if t:is(bi + 1, "ITBL_BASE_REF_ITEMS") then
      k = k + 1
      t:set(bi + 1, 0, refs[k][1])
      t:set(bi + 1, 1, refs[k][2])
    end
  end
  t:touch()
end

-- the items a shop of the GAME charges as its price: the token group of every shop (SHOP_INFO col 17 ->
-- SHOP_TOKEN_GROUP rows -> SHOP_TOKEN_GROUP_TOKEN), the slots (cols 7-15) its rows put a price in. Two passes: the file
-- lists the shops BEFORE the token groups, so the groups are read first (one pass found no group: an empty set)
local function shop_currencies()
  local k, e = VRFW.rows.key(SHOP_PREFIX)
  if not k then return nil, e end
  local t, te = VRFW.rows.game(k)
  if not t then return nil, te end
  local h_group, h_tok = VRFW.crc32("SHOP_TOKEN_GROUP"), VRFW.crc32("SHOP_TOKEN_GROUP_TOKEN")
  local h_shop, h_item = VRFW.crc32("SHOP_INFO"), VRFW.crc32("SHOP_INFO_ITEM")
  local groups, cur = {}, nil
  for i = 0, t:len() - 1 do
    local h = t:hash(i)
    if h == h_group then
      cur = t:uint(i, 0) or 0
      groups[cur] = {}
    elseif h == h_tok and cur then
      local g = groups[cur]
      g[#g + 1] = t:uint(i, 0) or 0
    elseif h == h_shop then
      cur = nil
    end
  end
  local used, any = {}, false
  local shop_group
  for i = 0, t:len() - 1 do
    local h = t:hash(i)
    if h == h_shop then
      shop_group = t:uint(i, 17) or 0
    elseif h == h_item then
      local toks = groups[shop_group] or {}
      for s = 0, PRICE_SLOTS - 1 do
        local p = t:int(i, 7 + s) or 0
        local tok = toks[s + 1]
        if p ~= 0 and tok and tok ~= 0 then used[tok] = true any = true end
      end
    end
  end
  if not any then return nil, k .. ": no shop row charges a token (the set would be empty)" end
  return used
end

-- the items of the item categories `cats` (col 5 of every ITEM_*_INFO list, schemas/enums.toml item_category: e.g.
-- 210 = the stat beans) in the served item_config
local function items_of_categories(X, cats)
  local want, out, any = {}, {}, false
  for _, c in ipairs(cats) do want[c] = true end
  local t = X.item
  for i = 0, t:len() - 1 do
    local name = t:name(i)
    if name and name:sub(1, 5) == "ITEM_" and name:sub(-5) == "_INFO" and t:width(i) > 11 then
      local id, c = t:uint(i, 0), t:uint(i, 5)
      if id and c and want[c] then out[id] = true any = true end
    end
  end
  return out, any
end

function D.build(X, files)
  if #files == 0 then return end
  local key, ke = VRFW.rows.key(LOOT_PREFIX)
  if not key then VRFW.log.error("drops: " .. tostring(ke) .. ": [[VRFW.DropAdd]] / [[VRFW.DropFilter]] not applied") return end
  local t, te = VRFW.rows.open(key)
  if not t then VRFW.log.error("drops: " .. tostring(te) .. ": not applied") return end
  local tabs, re = read_tables(t)
  if not tabs then VRFW.log.error("drops: " .. re .. ": not applied") return end
  local by_id = {}
  for _, x in ipairs(tabs) do by_id[x.id] = x end
  local active = {}
  for _, m in ipairs(VRFW.mods) do active[m.id] = true end
  local proto = tabs[1] and tabs[1].entries[1]
  if not proto then
    for _, x in ipairs(tabs) do if x.entries[1] then proto = x.entries[1] break end end
  end
  local changed = false

  -- pools
  local pools = {}
  for _, f in ipairs(files) do
    for _, p in ipairs(f.pools or {}) do
      local pk, pe = VRFW.ids.own(f.mod, p.name)
      if not pk then
        X.err(f.mod, f.file .. ": DropPool: " .. pe)
      else
        local set = pools[pk] or { list = {}, seen = {} }
        pools[pk] = set
        local missing = 0
        for _, s in ipairs(p.tables or {}) do
          local id = VRFW.ids.parse(U.trim(s))
          if by_id[id] then
            if not set.seen[id] then set.seen[id] = true set.list[#set.list + 1] = id end
          else
            missing = missing + 1
          end
        end
        if missing > 0 then X.warn(f.mod, f.file .. ": DropPool " .. pk .. ": " .. missing .. " table(s) not in " .. key .. " (left out)") end
      end
    end
  end

  -- adds
  local n_add = 0
  for _, f in ipairs(files) do
    for k0, a in ipairs(f.adds or {}) do
      local what = f.file .. ": DropAdd[" .. (k0 - 1) .. "] " .. tostring(a.item) .. " -> " .. tostring(a.pool)
      local req = a.if_mod and U.trim(a.if_mod) or ""
      local owner = U.trim(a.pool):match("^([^%.]+)%.") or f.mod
      if req ~= "" and not active[req] then
        VRFW.log.info(what .. ": if_mod " .. req .. " is not active (skipped)")
      elseif not active[owner] then
        VRFW.log.info(what .. ": mod " .. owner .. " is not active (skipped)")
      else
        local pk = U.trim(a.pool)
        if not pk:find(".", 1, true) then pk = f.mod .. "." .. pk end
        local pool = pools[pk]
        local id, ie = X.item_ref(a.item, f.mod)
        local w = a.weight or 1
        if not pool then
          X.warn(f.mod, what .. ": no such drop pool (skipped)")
        elseif not id then
          X.err(f.mod, what .. ": " .. ie)
        elseif w < 1 or w > 255 then
          X.err(f.mod, what .. ": weight " .. w .. ": 1-255")
        elseif not proto then
          X.err(f.mod, what .. ": no ITBL_ITEMS row to clone")
        else
          for _, tid in ipairs(pool.list) do
            local e = U.copy_entry(proto)
            e.values = { id, a.count or 1, w, 0, 0 }
            local es = by_id[tid].entries
            es[#es + 1] = e
            n_add = n_add + 1
          end
          changed = changed or #pool.list > 0
        end
      end
    end
  end

  -- filters
  local n_out, n_rep, n_kept = 0, 0, 0
  for _, f in ipairs(files) do
    for k0, fl in ipairs(f.filters or {}) do
      local what = f.file .. ": DropFilter[" .. (k0 - 1) .. "]"
      local ex = {}
      local ok = true
      if fl.exclude ~= nil then
        if fl.exclude == "shop_currencies" then
          local s, se = shop_currencies()
          if not s then X.err(f.mod, what .. ": shop_currencies: " .. tostring(se)) ok = false else ex = s end
        else
          X.err(f.mod, what .. ": Exclude \"" .. fl.exclude .. "\": known sets: \"shop_currencies\"")
          ok = false
        end
      end
      if fl.categories and #fl.categories > 0 then
        local c, any = items_of_categories(X, fl.categories)
        if not any then X.warn(f.mod, what .. ": Categories: no item of item_config has them") end
        for id in pairs(c) do ex[id] = true end
      end
      for _, s in ipairs(fl.items or {}) do
        local id, ie = X.item_ref(s, f.mod)
        if id then ex[id] = true else X.err(f.mod, what .. ": Items: " .. ie) end
      end
      for _, s in ipairs(fl.keep or {}) do
        local id, ie = X.item_ref(s, f.mod)
        if id then ex[id] = nil else X.warn(f.mod, what .. ": Keep: " .. ie) end
      end
      local rep
      if fl.replace_with ~= nil then
        local ie
        rep, ie = X.item_ref(fl.replace_with, f.mod)
        if not rep then X.err(f.mod, what .. ": ReplaceWith: " .. ie) ok = false end
        if rep and ex[rep] then X.err(f.mod, what .. ": ReplaceWith is an excluded item") ok = false end
      end
      if ok then
        for _, x in ipairs(tabs) do
          local out, hit = {}, false
          local by_item = {}
          for _, e in ipairs(x.entries) do
            local it = e.values[1] % 4294967296
            if ex[it] then
              hit = true
              if rep then
                local cnt, w = e.values[2], e.values[3]
                local same = by_item[rep .. ":" .. cnt]
                if same and (same.values[4] or 0) == 0 and (e.values[4] or 0) == 0 then
                  same.values[3] = math.min(255, same.values[3] + w)
                else
                  local c = U.copy_entry(e)
                  c.values[1] = rep
                  out[#out + 1] = c
                  by_item[rep .. ":" .. cnt] = c
                end
                n_rep = n_rep + 1
              else
                n_out = n_out + 1
              end
            else
              out[#out + 1] = e
              if (e.values[4] or 0) == 0 then by_item[it .. ":" .. e.values[2]] = by_item[it .. ":" .. e.values[2]] or e end
            end
          end
          if hit then
            if #out == 0 then
              n_kept = n_kept + 1
              X.warn(f.mod, what .. ": ITBL " .. U.hex(x.id) .. " would be empty: kept as it was (give ReplaceWith)")
            else
              x.entries = out
              changed = true
            end
          end
        end
      end
    end
  end

  if changed then
    local e = write_tables(t, tabs)
    if e then VRFW.log.error("drops: " .. e) return end
  end
  local np = 0
  for _ in pairs(pools) do np = np + 1 end
  VRFW.log.info(string.format("drops: %d pool(s), %d entr(y/ies) added, %d excluded entr(y/ies) replaced, %d removed, %d table(s) left as they were",
    np, n_add, n_rep, n_out, n_kept))
end

return D
