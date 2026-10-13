-- The shops and reward tables of the type `shop` (docs/framework/types/shop.md), built in the item build's single
-- pass (item.lua steps 5 and 6: a hidden item hides its shop rows, a shop sells the new items with their default
-- price): shop_config (new shops, token groups, rows, prices, conditions, hidden rows) and the ITBL reward tables of
-- common_item_table / soccer_prize_config. `X` is the item build's context (item.lua).

local U = require "lib/util"
local C = require "lib/cond"
local S = {}

-- engine limits (fichajes.md §4.1, tienda-general.md §4)
local SHOP_ROWS_MAX = 628
local TAB_ROWS_MAX = 320
local SHOPS_MAX = 64
local TOKENS_MAX = 9
local TOKENS_SHOWN = 8
local PRICE_SLOTS = 10
-- number space of a shop row's purchase counter / «new» flag index (shared with the office rows of the character
-- and team builds)
local COUNTER_SPACE = "shop_index"
local COUNTER_LIMIT = 8192

local SHOP_INFO = "SHOP_INFO"
local SHOP_ITEM = "SHOP_INFO_ITEM"
local SHOP_ITEM_BEG = "SHOP_INFO_ITEM_LIST_BEG"
local SHOP_ITEM_END = "SHOP_INFO_ITEM_LIST_END"
local SHOP_SUB = { "SHOP_INFO_ITEM_CONSUME_LIST_BEG", "SHOP_INFO_ITEM_CONSUME", "SHOP_INFO_ITEM_CONSUME_LIST_END",
  "SHOP_INFO_ITEM_CONDITION_LIST_BEG", "SHOP_INFO_ITEM_CONDITION", "SHOP_INFO_ITEM_CONDITION_LIST_END" }
local GROUP = "SHOP_TOKEN_GROUP"
local GROUP_TOKEN = "SHOP_TOKEN_GROUP_TOKEN"

function S.build(X, sfiles)
  -- ---------------------------------------------------------------- shop_config
  -- the table, loaded on first use (false: not available, reported once)
  local function shop_table()
    if X.shop == nil then
      local t, e
      if X.shop_key.key then t, e = VRFW.rows.open(X.shop_key.key) else e = X.shop_key.err end
      if t then
        -- free counters: above the highest one of the GAME's own shop_config
        local g, ge = VRFW.rows.game(X.shop_key.key)
        if g then
          local used = {}
          for _, i in ipairs(g:rows(SHOP_ITEM)) do
            for _, c in ipairs { "counter", "new_flag" } do
              local v = g:int(i, c)
              if v and v >= 0 and v < COUNTER_LIMIT then used[v] = true end
            end
          end
          X.counter_lo, X.counter_hi = VRFW.ids.free_above(used, COUNTER_LIMIT)
        else
          X.counter_err = ge
        end
        X.shop = t
      else
        VRFW.log.error(e .. ": shops are not changed")
        X.shop = false
      end
    end
    return X.shop or nil
  end

  local col_cache = {}
  local function sc(row, name)
    local k = row .. "/" .. name
    if col_cache[k] == nil then col_cache[k] = X.shop:col(row, name) end
    return col_cache[k]
  end

  -- (SHOP_INFO index, its SHOP_INFO_ITEM_LIST_BEG, its _END) of shop `id`
  local function shop_span(t, id)
    local i = t:find(SHOP_INFO, "id", id)
    if not i then return nil end
    local b = t:seek(SHOP_ITEM_BEG, i + 1)
    if not b then return nil end
    local e = t:seek(SHOP_ITEM_END, b)
    if not e then return nil end
    return i, b, e
  end

  local sub = {}
  for _, n in ipairs(SHOP_SUB) do sub[VRFW.crc32(n)] = true end
  local h_item = VRFW.crc32(SHOP_ITEM)
  -- { {row, end of its nested blocks} } of every row of a shop
  local function shop_rows(t, b, e)
    local out = {}
    for i = b + 1, e - 1 do
      if t:hash(i) == h_item then
        local j = i + 1
        while sub[t:hash(j)] do j = j + 1 end
        out[#out + 1] = { i, j }
      end
    end
    return out
  end

  -- (group index, tokens) of token group `gid`
  local h_tok, h_tok_end = VRFW.crc32(GROUP_TOKEN), VRFW.crc32(GROUP_TOKEN .. "_LIST_END")
  local function group_tokens(t, gid)
    local gi = t:find(GROUP, "id", gid)
    if not gi then return nil end
    local toks = {}
    local k, len = gi + 1, t:len()
    while k < len do
      local h = t:hash(k)
      if h == h_tok then
        toks[#toks + 1] = t:uint(k, 0) or 0
      elseif h == h_tok_end then
        break
      end
      k = k + 1
    end
    return gi, toks
  end

  local function is_hidden(t, i)
    return C.is_hidden(t:str(i, "condition"))
  end

  function X.shop_out(id, key, m, new)
    local o = X.shops_out[id]
    if not o then
      o = { key = key, id = id, mod_id = new and m or "", new = new, mods = {}, rows_added = 0, rows_changed = 0,
        rows_hidden = 0, rows_total = 0, tokens = {} }
      X.shops_out[id] = o
    end
    if not U.contains(o.mods, m) then o.mods[#o.mods + 1] = m end
    return o
  end

  -- a shop reference: a new shop of a mod, an id, or an internal name (crc32)
  local function shop_ref(s, m)
    s = U.trim(s)
    local id = X.new_shops[s] or X.new_shops[m .. "." .. s]
    if id then return id end
    id = VRFW.ids.parse(s)
    local t = shop_table()
    if not t then return nil, "shop_config not loaded" end
    if t:find(SHOP_INFO, "id", id) then return id end
    return nil, "shop `" .. s .. "` (" .. U.hex(id) .. ") is not in shop_config (write its id, e.g. 0x36D94694, or internal name)"
  end

  local function create_shop(m, file, name, d, default)
    local key, e = VRFW.ids.own(m, name)
    if not key then return nil, e end
    if X.new_shops[key] then return nil, "shop `" .. key .. "` is declared twice" end
    if d.based_on == nil then return nil, "a new shop needs `based_on` (the shop whose header, map and currencies it clones)" end
    local src, se = shop_ref(d.based_on, m)
    if not src then return nil, "based_on: " .. se end
    local name_id = X.new_text_id("shop:" .. key .. "#name")
    local t = shop_table()
    if not t then return nil, "shop_config not loaded" end
    local used, n = {}, 0
    for _, i in ipairs(t:rows(SHOP_INFO)) do
      local x = t:uint(i, "id")
      if x and not used[x] then used[x] = true n = n + 1 end
    end
    if n >= SHOPS_MAX then return nil, "shop_config already has " .. n .. " shops: the game keeps at most " .. SHOPS_MAX end
    local id = VRFW.ids.assign("shop:" .. key, used)
    local si, b, ei = shop_span(t, src)
    if not si then return nil, "based_on: shop without an item list" end
    local info = t:entry(si)
    info.values[sc(SHOP_INFO, "id") + 1] = id
    info.values[sc(SHOP_INFO, "name_text") + 1] = name_id
    local beg = t:entry(b)
    beg.values = { 0 }
    local fin = t:entry(ei)
    local _, le, lerr = t:list(SHOP_INFO)
    if not le then return nil, lerr end
    t:splice(le, le, { info, beg, fin })
    local lb = t:list(SHOP_INFO)
    if type(t:get(lb, 0)) == "number" then t:bump(lb, 1) end
    t:touch()
    X.new_shops[key] = id
    local what = file .. ": shop " .. key
    if U.is_empty(d.text) then X.warn(m, what .. ": no [shop.text.<lang>] name") end
    local dl = U.norm_default(d.default_lang or default, d.text)
    X.texts_of(m, what, "shop_text", name_id, nil, d.text or {}, dl, true, false)
    X.shop_out(id, key, m, true)
    VRFW.log.info(what .. ": new shop " .. U.hex(id) .. " (cloned from " .. U.hex(src) .. "; the Mercado lists it only when a menu opens it: CMND_EVT_ITEM_SHOP_FIND)")
    return id, key
  end

  -- give shop `id` a new token group with `tokens` (its rows' prices re-mapped to the new slots)
  local function set_tokens(m, what, id, key, tokens)
    if #tokens > TOKENS_MAX then return #tokens .. " currencies: a token shop takes at most " .. TOKENS_MAX end
    if #tokens > TOKENS_SHOWN then X.warn(m, what .. ": " .. #tokens .. " currencies: the shop header shows " .. TOKENS_SHOWN) end
    local t = shop_table()
    if not t then return "shop_config not loaded" end
    local used = {}
    for _, i in ipairs(t:rows(GROUP)) do
      local x = t:uint(i, "id")
      if x then used[x] = true end
    end
    local hx = {}
    for k, x in ipairs(tokens) do hx[k] = U.hex8(x) end
    local gid = VRFW.ids.assign("group:" .. key .. ":" .. table.concat(hx, ","), used)
    local si, b, e = shop_span(t, id)
    if not si then return "shop not found" end
    local old_gid = t:uint(si, "token_group") or 0
    local _, old = group_tokens(t, old_gid)
    old = old or {}
    if not t:find(GROUP, "id", gid) then
      -- clone the prototype block of any group
      local gi = t:rows(GROUP)[1]
      if not gi then return "shop_config has no token group to clone" end
      local g = t:entry(gi)
      local bt = t:entry(gi + 1)
      local ti = t:rows(GROUP_TOKEN)[1]
      if not ti then return "no token row to clone" end
      local tok = t:entry(ti)
      local ei = t:seek(GROUP_TOKEN .. "_LIST_END", gi)
      if not ei then return "token group without an end" end
      local endt = t:entry(ei)
      g.values = { gid }
      bt.values = { #tokens }
      local block = { g, bt }
      for _, x in ipairs(tokens) do
        local r = U.copy_entry(tok)
        r.values = { x }
        block[#block + 1] = r
      end
      block[#block + 1] = endt
      local _, gle = t:list(GROUP)
      t:splice(gle, gle, block)
      local glb = t:list(GROUP)
      if type(t:get(glb, 0)) == "number" then t:bump(glb, 1) end
    end
    -- indices after the insertion
    local si2, b2, e2 = shop_span(t, id)
    if si2 then si, b, e = si2, b2, e2 end
    t:set(si, "token_group", gid)
    local p1 = sc(SHOP_ITEM, "price_token_1")
    local lost = 0
    for _, r in ipairs(shop_rows(t, b, e)) do
      local i = r[1]
      local new = {}
      for k = 0, PRICE_SLOTS - 1 do new[k] = 0 end
      for k = 0, PRICE_SLOTS - 1 do
        local p = t:int(i, p1 + k) or 0
        if p ~= 0 then
          local tok, n = old[k + 1], nil
          if tok then
            for q, x in ipairs(tokens) do if x == tok then n = q - 1 break end end
          end
          if n then new[n] = p else lost = lost + 1 end
        end
      end
      for k = 0, PRICE_SLOTS - 1 do t:set(i, p1 + k, new[k]) end
    end
    t:touch()
    if lost > 0 then X.warn(m, what .. ": " .. lost .. " row(s) lose a price in a currency the new list does not have") end
    X.shop_out(id, key, m, false).tokens = tokens
  end

  -- hide every row selling `item` (in shop `only`, or every shop); how many
  local function hide_rows(only, item, m, what)
    local never = C.never()
    local t = shop_table()
    if not t then return 0 end
    local hits = {}
    for _, si in ipairs(t:rows(SHOP_INFO)) do
      local sid = t:uint(si, "id") or 0
      if not only or only == sid then
        local _, b, e = shop_span(t, sid)
        if b then
          for _, r in ipairs(shop_rows(t, b, e)) do
            local i = r[1]
            if t:uint(i, "item") == item and (t:uint(i, "spirit_param") or 0) == 0 and not is_hidden(t, i) then
              hits[#hits + 1] = { sid = sid, i = i, rid = t:uint(i, "id") or 0 }
            end
          end
        end
      end
    end
    for _, h in ipairs(hits) do t:set(h.i, "condition", never) end
    for _, h in ipairs(hits) do
      X.claim("row", h.rid, "condition", m, never, what .. ": row " .. U.hex(h.rid) .. ".condition")
      local o = X.shops_out[h.sid]
      local k = o and o.key or U.hex(h.sid)
      local so = X.shop_out(h.sid, k, m, false)
      so.rows_hidden = so.rows_hidden + 1
    end
    return #hits
  end

  -- shop_config's counters (SHOP_INFO_ITEM counter / new_flag of every row)
  local function shop_counters(t)
    local used = {}
    for _, i in ipairs(t:rows(SHOP_ITEM)) do
      for _, c in ipairs { "counter", "new_flag" } do
        local v = t:uint(i, c)
        if v then used[v] = true end
      end
    end
    return used
  end

  -- append a new row selling `item` at the end of shop `sid` (a clone of a row of that shop, else of any shop, with
  -- its nested blocks dropped; card costs as a CONSUME block); its id
  local function new_row(m, sid, rkey, item, spirit)
    local t = shop_table()
    if not t then return nil, "shop_config not loaded" end
    local used_ids = {}
    for _, i in ipairs(t:rows(SHOP_ITEM)) do
      local x = t:uint(i, "id")
      if x then used_ids[x] = true end
    end
    local used_ctr = shop_counters(t)
    local rid = VRFW.ids.assign(rkey, used_ids)
    local nkey = m .. "." .. rkey
    -- migration only: the counter the old rule gave (registered for old saves, never written)
    if X.legacy_counter == nil then X.legacy_counter = U.copy(used_ctr) end
    local old = VRFW.ids.slot("counter:" .. rkey, 7800, 8192, X.legacy_counter) or VRFW.ids.slot("counter:" .. rkey, 3000, 7800, X.legacy_counter)
    if old then
      X.legacy_counter[old] = true
      VRFW.ids.legacy(COUNTER_SPACE, nkey, old)
    end
    if not X.counter_lo then return nil, "no purchase counter (the game's shop_config: " .. tostring(X.counter_err) .. ")" end
    local ctr, w = VRFW.ids.next(COUNTER_SPACE, nkey, used_ctr, X.counter_lo, X.counter_hi)
    if w then X.warn(m, w) end
    if not ctr then return nil, "no free purchase counter (" .. X.counter_lo .. "-" .. (COUNTER_LIMIT - 1) .. ")" end
    local _, b, e = shop_span(t, sid)
    if not b then return nil, "shop not found" end
    local own = shop_rows(t, b, e)[1]
    local pi = own and own[1] or t:rows(SHOP_ITEM)[1]
    if not pi then return nil, "shop_config has no row to clone" end
    local row = t:entry(pi)
    local cid, citem, cctr, cnew, ccond = sc(SHOP_ITEM, "id"), sc(SHOP_ITEM, "item"), sc(SHOP_ITEM, "counter"),
      sc(SHOP_ITEM, "new_flag"), sc(SHOP_ITEM, "condition")
    for k, v in ipairs(row.values) do
      local c = k - 1
      if c == cid then row.values[k] = rid
      elseif c == citem then row.values[k] = item
      elseif c == cctr or c == cnew then row.values[k] = ctr
      elseif c == ccond then row.values[k] = 0
      elseif type(v) == "string" or v == VRFW.null then row.values[k] = VRFW.null
      else row.values[k] = 0 end
    end
    local block = { row }
    if #spirit > 0 then
      local protos = {}
      for k = 1, 3 do
        local i = t:seek(SHOP_SUB[k], 0)
        if not i then return nil, "shop_config has no CONSUME block to clone" end
        protos[k] = t:entry(i)
      end
      protos[1].values = { #spirit }
      block[#block + 1] = protos[1]
      for _, x in ipairs(spirit) do
        local r = U.copy_entry(protos[2])
        r.values = { x[1], x[2], x[3] }
        block[#block + 1] = r
      end
      protos[3].values = {}
      block[#block + 1] = protos[3]
    end
    t:splice(e, e, block)
    if type(t:get(b, 0)) == "number" then t:bump(b, 1) end
    t:touch()
    return rid
  end

  local function entry(m, what, sid, skey, en)
    local item, ikey, e
    if en.item ~= nil and en.technique == nil then
      item, e = X.item_ref(en.item, m)
      if not item then return e end
      ikey = en.item
    elseif en.item == nil and en.technique ~= nil then
      local tq
      tq, e = X.technique(en.technique, m)
      if not tq then return e end
      item, ikey = tq.item, tq.key
    else
      return "write either `item = …` or `technique = …`"
    end
    if X.hidden[item] then
      X.warn(m, what .. ": `" .. ikey .. "` is removed by a [[remove]]: not sold")
      return nil
    end
    -- costs: the entry's, else the item's default (an item's default price is written by the item's mod)
    local costs = {}
    local ip = X.item_price[item]
    local dp, dc, dm = nil, nil, m
    if ip then dp, dc, dm = ip.p, ip.c, ip.by end
    local cm = en.currency ~= nil and m or dm
    local p, c = en.price, en.currency
    if p == nil then p = dp end
    if c == nil then c = dc end
    if p ~= nil and c ~= nil then
      costs[#costs + 1] = { c, p, cm }
    elseif p ~= nil then
      costs[#costs + 1] = { "", p, m } -- the shop's first currency
    elseif c ~= nil then
      return "currency `" .. c .. "` without a price"
    end
    for _, x in ipairs(en.costs or {}) do costs[#costs + 1] = { x.currency, x.count, m } end
    local condition
    condition, e = C.build(en.unlock, en.unlock_mode, en.condition, function(r) return X.item_ref(r, m) end)
    if condition == nil then return e end
    -- the shop: token or card mode
    local t = shop_table()
    if not t then return "shop_config not loaded" end
    local si = shop_span(t, sid)
    if not si then return "shop not found" end
    local gid = t:uint(si, "token_group") or 0
    local _, tokens = group_tokens(t, gid)
    tokens = tokens or {}
    local prices = {}
    for k = 0, PRICE_SLOTS - 1 do prices[k] = 0 end
    local spirit = {}
    local toks = U.copy(tokens)
    for _, x in ipairs(costs) do
      local cname, n, cmod = x[1], x[2], x[3]
      local cur
      if cname == "" then
        if toks[1] == nil then
          return "a price without `currency` in a shop without currencies (card shop): name the card currency"
        end
        cur = { kind = "item", id = toks[1] }
      else
        cur, e = X.currency_ref(cname, cmod)
        if not cur then return e end
      end
      if cur.kind == "item" then
        if gid == 0 then
          return "`" .. cname .. "` is an item currency but this shop charges cards (no token group): give the shop `currencies = […]` first"
        end
        local k
        for q, y in ipairs(toks) do if y == cur.id then k = q - 1 break end end
        if not k then
          toks[#toks + 1] = cur.id
          k = #toks - 1
        end
        if k >= PRICE_SLOTS then return "too many currencies" end
        prices[k] = prices[k] + n
      else
        if gid ~= 0 then return "`" .. cname .. "` is a card currency but this shop charges items (it has a token group)" end
        spirit[#spirit + 1] = { cur.spirit, cur.rarity, n }
      end
    end
    if #toks ~= #tokens then
      VRFW.log.info(what .. ": its currencies grow to " .. #toks .. " (a new token group for this shop)")
      e = set_tokens(m, what, sid, skey, toks)
      if e then return e end
    end
    if gid == 0 and #spirit == 0 then
      return "a card shop row needs a card cost (the game refuses a card row without costs: fichajes.md §4.10)"
    end
    if #spirit > 4 then return #spirit .. " card costs: the shop shows at most 4" end
    local rkey = "row:" .. skey .. "/" .. U.hex8(item)
    -- an existing row that sells it (visible)
    local existing
    do
      local _, b, e2 = shop_span(t, sid)
      if not b then return "shop not found" end
      for _, r in ipairs(shop_rows(t, b, e2)) do
        local i = r[1]
        if t:uint(i, "item") == item and (t:uint(i, "spirit_param") or 0) == 0 and not is_hidden(t, i) then
          existing = t:uint(i, "id") or 0
          break
        end
      end
    end
    local mode = en.mode or "add"
    if mode == "replace" then hide_rows(sid, item, m, what) end
    local row_id
    if existing and mode == "add" then
      local o = X.shop_out(sid, skey, m, false)
      o.rows_changed = o.rows_changed + 1
      row_id = existing
    else
      row_id, e = new_row(m, sid, rkey, item, spirit)
      if not row_id then return e end
      local o = X.shop_out(sid, skey, m, false)
      o.rows_added = o.rows_added + 1
    end
    X.rep(m).shop_rows = X.rep(m).shop_rows + 1
    -- cells
    local function w(f) return what .. ": " .. ikey .. " (row " .. U.hex(row_id) .. ")." .. f end
    local cells = {}
    if #costs > 0 then
      local p1 = sc(SHOP_ITEM, "price_token_1")
      for k = 0, PRICE_SLOTS - 1 do cells[#cells + 1] = { p1 + k, prices[k], w("price") } end
    end
    if en.stock ~= nil then cells[#cells + 1] = { "stock", en.stock, w("stock") } end
    if en.restock ~= nil then cells[#cells + 1] = { "restock", en.restock, w("restock") } end
    if condition then cells[#cells + 1] = { "condition", condition, w("condition") } end
    for _, x in ipairs(cells) do
      local col, v, wh = x[1], x[2], x[3]
      X.claim("row", row_id, col, m, v, wh)
      local _, b, e2 = shop_span(t, sid)
      if not b then return "shop not found" end
      local at
      for _, r in ipairs(shop_rows(t, b, e2)) do
        if t:uint(r[1], "id") == row_id then at = r[1] break end
      end
      if not at then return "row vanished" end
      t:set(at, col, v)
    end
  end

  local function shop(m, file, d, default)
    local id, key, e
    if d.shop ~= nil and d.name == nil then
      if d.based_on ~= nil then X.warn(m, file .. ": shop " .. d.shop .. ": `based_on` is only for a new shop (ignored)") end
      id, e = shop_ref(d.shop, m)
      if not id then return e end
      for _, k in ipairs(U.keys(X.new_shops)) do
        if X.new_shops[k] == id then key = k break end
      end
      key = key or U.hex(id)
      if not U.is_empty(d.text) then
        local t = shop_table()
        if not t then return "shop_config not loaded" end
        local si = t:find(SHOP_INFO, "id", id)
        local name_id = si and t:uint(si, "name_text") or 0
        local dl = U.norm_default(d.default_lang or default, d.text)
        local is_new = X.shops_out[id] ~= nil and X.shops_out[id].new
        X.texts_of(m, file .. ": shop " .. key, "shop_text", name_id, nil, d.text, dl, is_new, false)
      end
    elseif d.shop == nil and d.name ~= nil then
      id, key = create_shop(m, file, d.name, d, default)
      if not id then return key end
    else
      return "write either `shop = …` (an existing shop) or `name = …` (a new one)"
    end
    X.rep(m).shops = X.rep(m).shops + 1
    local what = file .. ": shop " .. key
    X.shop_out(id, key, m, false)
    if d.currencies ~= nil then
      local toks = {}
      for _, c in ipairs(d.currencies) do
        local cur, ce = X.currency_ref(c, m)
        if not cur then return ce end
        if cur.kind == "spirit" then
          return "currencies: `" .. c .. "` is a card currency: a token shop charges items (card costs go in the entries of a shop without currencies)"
        end
        if not U.contains(toks, cur.id) then toks[#toks + 1] = cur.id end
      end
      local ck = "shop:" .. string.format("%.0f", id) .. ":token_group"
      local owner = X.claims[ck]
      if owner and owner.by ~= m then
        X.conflict(m, "item conflict: " .. what .. ".currencies: mod " .. owner.by .. " set them, mod " .. m .. " replaces them (loads later)")
      end
      X.claims[ck] = { t = "shop", row = id, col = "token_group", by = m, val = table.concat(toks, ",") }
      e = set_tokens(m, what, id, key, toks)
      if e then return e end
    end
    for _, h in ipairs(d.hide or {}) do
      local it, he = X.item_ref(h, m)
      if it then
        if hide_rows(id, it, m, what) == 0 then X.warn(m, what .. ": hide " .. h .. ": the shop does not sell it") end
      else
        X.err(m, what .. ": hide: " .. he)
      end
    end
    for k, en in ipairs(d.entry or {}) do
      local ee = entry(m, what, id, key, en)
      if ee then X.err(m, what .. ": entry[" .. (k - 1) .. "]: " .. ee .. " (skipped)") end
    end
  end

  -- hidden items leave every shop; engine limits of the changed shops
  local function shops_finish()
    for _, it in ipairs(U.keys(X.hidden)) do
      hide_rows(nil, it, X.hidden[it], "remove " .. X.label_of(it))
    end
    local t = X.shop
    if not t then return end
    local warns = {}
    for _, id in ipairs(U.keys(X.shops_out)) do
      local si, b, e = shop_span(t, id)
      if si then
        local rows = shop_rows(t, b, e)
        local per_tab = {}
        for _, r in ipairs(rows) do
          if not is_hidden(t, r[1]) then
            local it = t:uint(r[1], "item") or 0
            local tab = it == 0 and "cards" or (X.list_of[it] or "")
            per_tab[tab] = (per_tab[tab] or 0) + 1
          end
        end
        local gid = t:uint(si, "token_group") or 0
        local _, toks = group_tokens(t, gid)
        local o = X.shops_out[id]
        o.rows_total = #rows
        o.tokens = toks or {}
        local who = o.mods[#o.mods] or ""
        if #rows > SHOP_ROWS_MAX then
          warns[#warns + 1] = { who, "shop " .. o.key .. ": " .. #rows .. " rows: the game lists the first 640 raw rows only (12 are lot slots; keep ≤ " .. SHOP_ROWS_MAX .. ")" }
        end
        for _, tab in ipairs(U.keys(per_tab)) do
          local n = per_tab[tab]
          if n > TAB_ROWS_MAX then
            warns[#warns + 1] = { who, "shop " .. o.key .. ": " .. n .. " visible " .. X.of_list(tab) .. " rows: a tab lists at most " .. TAB_ROWS_MAX }
          end
        end
      end
    end
    for _, x in ipairs(warns) do X.warn(x[1], x[2]) end
  end

  -- ---------------------------------------------------------------- rewards
  local function loot_table(target)
    local slot = target == "match_prize" and "prize" or "loot"
    if X[slot] == nil then
      local k = X[slot .. "_key"]
      local t, e
      if k.key then t, e = VRFW.rows.open(k.key) else e = k.err end
      if not t then VRFW.log.error(e .. ": reward tables are not written") end
      X[slot] = t or false
    end
    return X[slot] or nil
  end

  -- the entries of ITBL table `id` of a loot file
  local function itbl_entries(t, id)
    local bi = t:find("ITBL_BASE", "id", id)
    if not bi or not t:is(bi + 1, "ITBL_BASE_REF_ITEMS") then return nil end
    local off, n = t:int(bi + 1, "offset"), t:int(bi + 1, "count")
    if not off or not n then return nil end
    local rows = t:rows("ITBL_ITEMS")
    if off < 0 or n < 0 or off + n > #rows then return nil end
    local out = {}
    for k = off + 1, off + n do
      local i = rows[k]
      local c = t:uint(i, "count") or 1
      local it = t:uint(i, "item") or 0
      out[#out + 1] = { kind = "item", key = U.hex(it), item = it, min = c, max = c, weight = t:uint(i, "weight") or 1,
        condition = t:str(i, "condition") }
    end
    return out
  end

  -- write `entries` as table `id` (new, or re-pointed to a fresh slice at the end of ITBL_ITEMS)
  local function itbl_write(t, id, entries)
    local rows = t:rows("ITBL_ITEMS")
    if not rows[1] then return "no ITBL_ITEMS row to clone" end
    local proto = t:entry(rows[1])
    local off = #rows
    local new = {}
    for _, x in ipairs(entries) do
      local e = U.copy_entry(proto)
      e.values = { x.item, x.min, x.weight, x.condition or 0, 0 }
      new[#new + 1] = e
    end
    if #new > 0 then t:append_rows("ITBL_ITEMS", { "ITBL_ITEMS" }, new, #new) end
    local bi = t:find("ITBL_BASE", "id", id)
    if bi and t:is(bi + 1, "ITBL_BASE_REF_ITEMS") then
      t:set(bi + 1, "offset", off)
      t:set(bi + 1, "count", #new)
    else
      local b0 = t:rows("ITBL_BASE")[1]
      if not b0 then return "no ITBL_BASE row to clone" end
      local b = t:entry(b0)
      b.values = { id }
      local r = t:entry(b0 + 1)
      r.values = { off, #new }
      t:append_rows("ITBL_BASE", { "ITBL_BASE", "ITBL_BASE_REF_ITEMS" }, { b, r }, 1)
    end
    t:touch()
  end

  local function deep(r)
    local o = U.copy(r)
    o.tags = U.copy(r.tags)
    o.entries = {}
    for k, x in ipairs(r.entries) do o.entries[k] = U.copy(x) end
    return o
  end

  local function reward(m, file, d)
    local items = {}
    local resolver = function(r) return X.item_ref(r, m) end
    for k0, e in ipairs(d.entry or {}) do
      local k = k0 - 1
      local kind, key, id, x
      if e.item ~= nil and e.technique == nil and e.currency == nil then
        id, x = X.item_ref(e.item, m)
        if not id then return "entry[" .. k .. "]: " .. x end
        kind, key = "item", e.item
      elseif e.item == nil and e.technique ~= nil and e.currency == nil then
        local tq
        tq, x = X.technique(e.technique, m)
        if not tq then return "entry[" .. k .. "]: " .. x end
        kind, key, id = "technique", tq.key, tq.item
      elseif e.item == nil and e.technique == nil and e.currency ~= nil then
        local cur
        cur, x = X.currency_ref(e.currency, m)
        if not cur then return "entry[" .. k .. "]: " .. x end
        if cur.kind == "spirit" then return "entry[" .. k .. "]: `" .. e.currency .. "` is a card currency: reward tables give items" end
        kind, key, id = "currency", e.currency, cur.id
      else
        return "entry[" .. k .. "]: write one of `item`, `technique`, `currency`"
      end
      if X.hidden[id] then
        VRFW.log.info(file .. ": reward: `" .. key .. "` is removed by a [[remove]]: left out")
      else
        local lo, hi
        if type(e.count) == "table" then
          lo, hi = math.min(e.count[1], e.count[2]), math.max(e.count[1], e.count[2])
        else
          lo = e.count or 1
          hi = lo
        end
        if hi == 0 then return "entry[" .. k .. "]: count 0" end
        local weight = e.weight or 1
        if weight == 0 then X.warn(m, file .. ": reward entry[" .. k .. "] `" .. key .. "`: weight 0 (never drawn)") end
        local cond
        cond, x = C.build(e.unlock, e.unlock_mode, nil, resolver)
        if cond == nil then return "entry[" .. k .. "]: " .. x end
        items[#items + 1] = { kind = kind, key = key, item = id, min = lo, max = hi, weight = weight, condition = cond or nil }
      end
    end
    local chance = d.chance or 100
    if chance > 100 then return "chance " .. chance .. ": 0-100" end
    local target_in = d.target or "api"
    local key, out
    if d.name ~= nil and d.table == nil then
      local e
      key, e = VRFW.ids.own(m, d.name)
      if not key then return e end
      if X.rewards[key] then return "reward `" .. key .. "` is declared twice" end
      out = { key = key, mod_id = m, target = target_in, table = 0, rolls = math.max(d.rolls or 1, 1), chance = chance,
        tags = U.copy(d.tags or {}), entries = {} }
    elseif d.name == nil and d.table ~= nil then
      local r = X.rewards[U.trim(d.table)]
      if r then
        -- another mod's reward table
        if r.mod_id ~= m then VRFW.log.info(file .. ": reward " .. r.key .. ": changed by " .. m .. " (declared by " .. r.mod_id .. ")") end
        key, out = r.key, deep(r)
      else
        local id = VRFW.ids.parse(d.table)
        local target = target_in == "api" and "item_table" or target_in
        key = U.hex(id)
        if X.rewards[key] then
          out = deep(X.rewards[key])
        else
          local tab = loot_table(target)
          if not tab then return "reward file not loaded" end
          local entries = itbl_entries(tab, id)
          if not entries then return "table `" .. d.table .. "` (" .. U.hex(id) .. ") is not an ITBL table of the " .. target .. " file" end
          out = { key = key, mod_id = m, target = target, table = id, rolls = 1, chance = 100, tags = {}, entries = entries }
        end
      end
    else
      return "write either `name = …` (a new table) or `table = …` (edit one)"
    end
    if d.table ~= nil then
      if d.rolls ~= nil then out.rolls = math.max(d.rolls, 1) end
      if d.chance ~= nil then out.chance = chance end
      for _, tg in ipairs(d.tags or {}) do out.tags[#out.tags + 1] = tg end
      out.mod_id = m
    end
    if (d.mode or "add") == "replace" then out.entries = {} end
    for _, x in ipairs(items) do out.entries[#out.entries + 1] = x end
    if #out.entries == 0 then X.warn(m, file .. ": reward " .. key .. ": no entries") end
    -- game data
    if out.target ~= "api" then
      if out.table == 0 then
        local tab = loot_table(out.target)
        if not tab then return "reward file not loaded" end
        local used = {}
        for _, i in ipairs(tab:rows("ITBL_BASE")) do
          local x = tab:uint(i, "id")
          if x then used[x] = true end
        end
        out.table = VRFW.ids.assign("reward:" .. key, used)
      end
      for _, x in ipairs(out.entries) do
        if x.min ~= x.max then
          X.warn(m, file .. ": reward " .. key .. ": a game table gives a fixed count: the ranges are written as their minimum (the API rolls the range)")
          break
        end
      end
      local tab = loot_table(out.target)
      if not tab then return "reward file not loaded" end
      local e = itbl_write(tab, out.table, out.entries)
      if e then return e end
    end
    X.rewards[key] = out
    X.rep(m).rewards = X.rep(m).rewards + 1
  end

  -- ---------------------------------------------------------------- the passes
  -- 5. shops
  for _, f in ipairs(sfiles) do
    for _, d in ipairs(f.value.shop or {}) do
      local e = shop(f.mod, f.file, d, f.value.default_lang)
      if e then X.err(f.mod, f.file .. ": shop " .. (d.shop or d.name or "") .. ": " .. e .. " (skipped)") end
    end
  end
  if next(X.hidden) ~= nil or next(X.shops_out) ~= nil then shops_finish() end
  -- 6. rewards
  for _, f in ipairs(sfiles) do
    for _, d in ipairs(f.value.reward or {}) do
      local e = reward(f.mod, f.file, d)
      if e then X.err(f.mod, f.file .. ": reward " .. (d.name or d.table or "") .. ": " .. e .. " (skipped)") end
    end
  end
end

return S
