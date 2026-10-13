-- The character build's recruit conditions and office rows (scripts/build/character.lua; docs/app/character-engine.md
-- §4, fichajes.md): `[[recruit]]` / `[character.recruit]` -> the recruit entries the office Lua reads, a clone of an
-- office row for `beside`, and the office rows of shop_config (hidden cards leave every shop; prices and player
-- requirements go into the rows that sell the card).
--
-- Every function takes the build's context `X` (character.lua).
local U = require "lib/util"
local O = {}

local SHOP_ITEM = "SHOP_INFO_ITEM"
local SHOP_ITEM_BEG = "SHOP_INFO_ITEM_LIST_BEG"
local CONSUME = "SHOP_INFO_ITEM_CONSUME"
local COND_BEG = "SHOP_INFO_ITEM_CONDITION_LIST_BEG"
local COND = "SHOP_INFO_ITEM_CONDITION"
local COND_END = "SHOP_INFO_ITEM_CONDITION_LIST_END"
-- the nested blocks of a SHOP_INFO_ITEM row
local SUB = { "SHOP_INFO_ITEM_CONSUME_LIST_BEG", CONSUME, "SHOP_INFO_ITEM_CONSUME_LIST_END", COND_BEG, COND, COND_END }

-- the error text of a host call that raised (nil when it did not)
local function perr(f, ...)
  local ok, e = pcall(f, ...)
  if not ok then return tostring(e) end
  return nil
end

local function int_str(n)
  return string.format("%.0f", n)
end

-- ---------------------------------------------------------------- the shop table

-- The shop indices (SHOP_INFO_ITEM `counter` and `new_flag`) of every row of `t`, as a set; `signed` keeps negative
-- values (else only 0 and above).
local function indices(X, t, signed)
  local s = {}
  for _, i in ipairs(t:rows(SHOP_ITEM)) do
    for _, c in ipairs { X.SC.counter, X.SC.new_flag } do
      local v = t:int(i, c)
      if v and (signed or v >= 0) then s[v] = true end
    end
  end
  return s
end

-- shop_config as the game would read it (once): nil when it cannot be read (a WARN, office rows unchanged).
function O.shop(X)
  if X.shop_state == nil then
    local t, e
    if X.shop_key then
      t, e = VRFW.rows.open(X.shop_key)
    else
      e = X.shop_key_err
    end
    if t then
      X.SC = {
        id = t:col(SHOP_ITEM, "id"), counter = t:col(SHOP_ITEM, "counter"), new_flag = t:col(SHOP_ITEM, "new_flag"),
        card = t:col(SHOP_ITEM, "spirit_param"),
      }
      X.SCONS = { currency = t:col(CONSUME, "spirit_param"), price = t:col(CONSUME, "count") }
      X.SCOND = { card = t:col(COND, "chara_param"), level = t:col(COND, "level") }
      -- free indices: above the highest one of the GAME's own shop table (below the format's bound)
      local g, ge = VRFW.rows.game(X.shop_key)
      if g then
        local used = {}
        for v in pairs(indices(X, g, false)) do
          if v < X.K.shop_index_limit then used[v] = true end
        end
        X.shop_lo, X.shop_hi = VRFW.ids.free_above(used, X.K.shop_index_limit)
      else
        X.shop_range_err = ge
      end
      -- migration only: the old rule's numbers (over the table as read)
      X.legacy_used = indices(X, t, true)
    else
      VRFW.log.warn(e .. ": office rows are not changed")
    end
    X.shop_state = t or false
  end
  return X.shop_state or nil
end

-- `{ i, j }` (the row and the end of its nested blocks) of every shop row selling `card`.
function O.rows(X, t, card)
  local out = {}
  for _, i in ipairs(t:find_all(SHOP_ITEM, X.SC.card, card)) do
    out[#out + 1] = { i, U.block_end(t, i, SUB) }
  end
  return out
end

-- The SHOP_INFO_ITEM_LIST_BEG of the list holding entry `i`.
local function begin_of(t, i)
  for k = i - 1, 0, -1 do
    if t:is(k, SHOP_ITEM_BEG) then return k end
  end
  return nil
end

-- MIGRATION ONLY (old saves): the number the rule before deterministic numbering gave the row `key` (sequential from
-- the first free index), registered and never written.
local function legacy_give(X, key)
  for k = X.K.shop_legacy_from, X.K.shop_index_limit - 1 do
    if not X.legacy_used[k] then
      X.legacy_used[k] = true
      VRFW.ids.legacy(X.K.shop_index_space, key, k)
      return
    end
  end
end

-- The shop index of the office row `key`: a deterministic number of the space, above the game's own indices; the
-- indices `t` has now are taken.
local function shop_index(X, t, key, warns)
  local n, w = VRFW.ids.next(X.K.shop_index_space, key, indices(X, t, false), X.shop_lo, X.shop_hi)
  if w then warns[#warns + 1] = w end
  if not n then return nil, "no free shop index below " .. X.K.shop_index_limit end
  return n
end

-- Sell `card` on the office page of the first card of `beside` that has a row: a clone of that row block with the
-- row id crc32("<tag>_<card>") and the shop index `index(t)`. Returns "sold" / "nopage" / "added", rows of that
-- shop now; or nil, err.
local function add_at(X, t, card, beside, tag, index)
  if #O.rows(X, t, card) > 0 then return "sold" end
  local at
  for _, b in ipairs(beside) do
    at = O.rows(X, t, b)[1]
    if at then break end
  end
  if not at then return "nopage" end
  local idx, e = index(t)
  if not idx then return nil, e end
  local block = t:entries(at[1], at[2])
  local v = block[1].values
  v[X.SC.id + 1] = VRFW.crc32(tag .. "_" .. U.hex8(card))
  v[X.SC.counter + 1] = idx
  v[X.SC.new_flag + 1] = idx
  v[X.SC.card + 1] = card
  local b = begin_of(t, at[1])
  if not b then return nil, "shop row outside a SHOP_INFO_ITEM list" end
  t:splice(at[2], at[2], block)
  local rows = 0
  if type(t:get(b, 0)) == "number" then rows = t:bump(b, 1) end
  return "added", rows
end

-- Every CONSUME entry of the rows selling `card` that pays in one of the element currencies `all` (a set) pays in
-- `item` instead.
local function set_element_currency(X, t, card, item, all)
  for _, r in ipairs(O.rows(X, t, card)) do
    for k = r[1] + 1, r[2] - 1 do
      if t:is(k, CONSUME) then
        local f = t:uint(k, X.SCONS.currency)
        if f and f ~= item and all[f] then t:set(k, X.SCONS.currency, item) end
      end
    end
  end
end

-- Sell `card` beside the cards `beside` (a clone of their office row); with `[element_currency]` declared, the clone
-- pays in the card's own element's currency. Returns an error text or nil.
function O.office_add(X, what, m, card, beside)
  local elem
  local pi = X.param:find(X.PARAM_ROW, X.CP.id, card)
  if pi then elem = X.param:int(pi, X.CP.element) end
  local t = O.shop(X)
  if not t then return nil end
  local key = m .. ".recruit_" .. U.hex8(card)
  local warns = {}
  local added, rows = add_at(X, t, card, beside, X.K.office_tag, function(tt)
    legacy_give(X, key)
    if not X.shop_lo then return nil, "no shop index (the game's shop_config: " .. tostring(X.shop_range_err) .. ")" end
    return shop_index(X, tt, key, warns)
  end)
  if added == nil then return rows end
  if added == "added" and elem then
    local f = X.decl.currency[elem]
    if f then
      local all = {}
      for _, v in pairs(X.decl.currency) do all[v] = true end
      set_element_currency(X, t, card, f, all)
    end
  end
  for _, w in ipairs(warns) do VRFW.log.warn(what .. ": " .. w) end
  if added == "nopage" then
    VRFW.log.warn(what .. ": beside: that character is not sold in any shop (the card gets no office row)")
  elseif added == "added" and rows > 628 then
    VRFW.log.warn(what .. ": that shop now has " .. rows .. " rows: a shop shows its first 640 raw rows only (fichajes.md §5)")
  end
  return nil
end

-- ---------------------------------------------------------------- recruit conditions

-- A challenge trial: { kind (1 hold / 2 goals / 3 steals), seconds, count }; false = an office trial; nil, err.
local function challenge(t)
  local c = t.challenge
  if c == nil then
    if t.seconds ~= nil or t.count ~= nil then return nil, "`seconds` / `count` go with `challenge = …`" end
    return false
  end
  if t.trial ~= nil then return nil, "either `trial = n` (an office trial) or `challenge = …`, not both" end
  local secs = t.seconds or 0
  if secs > 3600 then return nil, "seconds: at most 3600" end
  local kind, count
  if c == "hold" then
    if secs == 0 then return nil, "hold: `seconds` of possession" end
    kind, count = 1, 0 -- the office's hold code has no count (101500)
  elseif c == "goals" then
    if not (t.count and t.count > 0) then return nil, "goals: `count` goals" end
    kind, count = 2, t.count
  elseif c == "steals" then
    kind, count = 3, math.max(t.count or 1, 1)
  else
    return nil, "challenge \"" .. c .. "\": hold, goals or steals"
  end
  if count > 99 then return nil, "count: at most 99" end
  return { kind, secs, count }
end

local function copy_list(l)
  local o = {}
  for k, v in ipairs(l) do o[k] = v end
  return o
end

-- The recruit conditions `body` of mod `m` for `character` (every card, or `card`). Returns an error text or nil.
function O.recruit(X, m, file, character, card, body)
  local chara, ce = X.chara_ref(character, m)
  if not chara then return ce end
  local what = file .. ": recruit " .. X.label_of(chara)
  local cards
  if card ~= nil then cards = { U.id(card) } else cards = X.cards(chara) end
  if #cards == 0 then return "the character has no card" end
  local is_card = {}
  for _, c in ipairs(cards) do is_card[c] = true end
  local reqs = {}
  for k, q in ipairs(body.requires or {}) do
    local n = k - 1
    if q.player ~= nil and q.item == nil then
      local pc, e = X.chara_ref(q.player, m)
      if not pc then return "requires[" .. n .. "].player: " .. e end
      local ids = {}
      for _, c in ipairs(X.cards(pc)) do
        if not is_card[c] then ids[#ids + 1] = c end
      end
      if #ids == 0 then
        VRFW.log.warn(what .. ": requires[" .. n .. "]: `" .. q.player .. "` has no other card (dropped)")
      else
        local names = {}
        for _, l in ipairs(VRFW.lang.list()) do
          local s = X.chara_name(pc, l)
          if s then names[l] = s end
        end
        reqs[#reqs + 1] = { kind = 1, ids = ids, count = math.max(q.count or 1, 1), level = math.max(q.level or 1, 1), sixth = pc,
          objective = 0, names = names }
      end
    elseif q.player == nil and q.item ~= nil then
      local id = U.id(q.item)
      local names, any = {}, false
      for _, l in ipairs(U.keys(q.label or {})) do
        local nl = VRFW.lang.norm_or_all(l)
        if nl then
          names[nl] = q.label[l]
          any = true
        end
      end
      if not any then names = { all = U.hex(id) } end
      if q.level ~= nil then
        VRFW.log.warn(what .. ": requires[" .. n .. "]: `level` is for players (ignored for items)")
      end
      reqs[#reqs + 1] = { kind = 2, ids = { id }, count = math.max(q.count or 1, 1), level = 0, sixth = 0, objective = 0, names = names }
    else
      return "requires[" .. n .. "]: write either `player = …` or `item = …`"
    end
  end
  for k, t in ipairs(body.trials or {}) do
    local n = k - 1
    local ch, e = challenge(t)
    if ch == nil then return "trials[" .. n .. "]: " .. e end
    if ch then
      -- a pachanga with a match challenge (the office mod hosts it)
      local names = {}
      for _, l in ipairs(VRFW.lang.list()) do names[l] = VRFW.character.challenge_text(ch[1], ch[2], ch[3], l) end
      reqs[#reqs + 1] = { kind = 3, ids = {}, count = 1, level = 0, sixth = 0, objective = ch[1] * 100000 + ch[2] * 100 + ch[3],
        names = names }
    else
      local i = t.trial or 0
      if i == 0 then
        return "trials[" .. n .. "]: `trial` is the office trial's index (1, 2…), or write `challenge = …`"
      end
      reqs[#reqs + 1] = { kind = 3, ids = {}, count = 1, level = 0, sixth = i, objective = 0, names = {} }
    end
  end
  local max = X.K.max_req
  if #reqs > max then
    VRFW.log.error(what .. ": " .. #reqs .. " requirements, the office takes at most " .. max .. " (the first " .. max .. " are kept)")
    for k = #reqs, max + 1, -1 do reqs[k] = nil end
  end
  local tier
  if body.tier ~= nil then
    tier = X.decl.price_tiers[body.tier]
    if not tier then
      local known = U.keys(X.decl.price_tiers)
      return "tier `" .. body.tier .. "`: no mod declares this `[[price_tier]]` (declared: " ..
        (#known == 0 and "none" or table.concat(known, ", ")) .. ")"
    end
  end
  local price = body.price
  if price == nil and tier then
    local lv = body.level or 1
    price = tier.base + ((tier.level_step or 0) ~= 0 and math.floor(lv / tier.level_step) or 0)
  end
  local mode = body.mode or "replace"
  for _, c in ipairs(cards) do
    local e = { param = c, owner = m, mode = mode, price = price, tier = tier and tier.id or nil, level = body.level,
      reqs = copy_list(reqs) }
    local old = X.recruits[c]
    if old and mode == "add" then
      for _, q in ipairs(e.reqs) do old.reqs[#old.reqs + 1] = q end
      if #old.reqs > max then
        VRFW.log.warn(what .. ": with " .. old.owner .. "'s conditions the card has " .. #old.reqs .. " requirements: the first " ..
          max .. " are kept")
        for k = #old.reqs, max + 1, -1 do old.reqs[k] = nil end
      end
      if e.price ~= nil then old.price = e.price end
      if e.tier ~= nil then old.tier = e.tier end
      if e.level ~= nil then old.level = e.level end
      old.owner = m
    elseif old and old.owner ~= m then
      X.conflict("character conflict: " .. what .. " (card " .. U.hex(c) .. "): the recruit conditions of mod " .. old.owner ..
        " are replaced by mod " .. m .. " (loads later)")
      X.recruits[c] = e
    else
      X.recruits[c] = e
    end
  end
  if body.beside ~= nil then
    local bc, e = X.chara_ref(body.beside, m)
    if not bc then return "beside: " .. e end
    local bcards = X.cards(bc)
    for _, c in ipairs(cards) do
      local err = O.office_add(X, what, m, c, bcards)
      if err then return err end
    end
  end
  return nil
end

-- ---------------------------------------------------------------- office rows

local function same_value(a, b)
  if type(a) == "number" and type(b) == "number" then return U.i32(a) == U.i32(b) end
  if type(a) == "table" and type(b) == "table" then return a.float == b.float end
  return a == b
end

-- Entries `a` and `b` hold the same rows (hash and values).
local function same(a, b)
  if #a ~= #b then return false end
  for k = 1, #a do
    local x, y = a[k], b[k]
    if x.hash ~= y.hash or #x.values ~= #y.values then return false end
    for v = 1, #x.values do
      if not same_value(x.values[v], y.values[v]) then return false end
    end
  end
  return true
end

-- The first entry k in `from..to-1` named `name`.
local function first(t, from, to, name)
  for k = from, to - 1 do
    if t:is(k, name) then return k end
  end
  return nil
end

-- Office rows: hidden / deleted cards leave every shop; recruit prices and player requirements (the native faces
-- panel, CONDITION rows `[card, level, 0]`) go into the rows selling the card. Returns an error text or nil.
function O.office(X)
  local hidden = U.keys(X.hidden)
  local recruits = {}
  for _, c in ipairs(U.keys(X.recruits)) do recruits[#recruits + 1] = X.recruits[c] end
  local needs = false
  for _, r in ipairs(recruits) do
    if r.price ~= nil then needs = true end
    for _, q in ipairs(r.reqs) do
      if q.kind == 1 then needs = true end
    end
  end
  if #hidden == 0 and not needs then return nil end
  local t = O.shop(X)
  if not t then return nil end
  local removed = 0
  for _, card in ipairs(hidden) do
    while true do
      local r = O.rows(X, t, card)[1]
      if not r then break end
      local b = begin_of(t, r[1])
      if not b then return "shop row outside a list" end
      local e = perr(t.remove_range, t, b, r[1], r[2], 1)
      if e then return e end
      removed = removed + 1
    end
  end
  -- prototypes of a CONDITION block (any in the file)
  local function proto(n)
    local i = t:seek(n, 0)
    return i and t:entry(i) or nil
  end
  local cb, cr, ce = proto(COND_BEG), proto(COND), proto(COND_END)
  local priced, conds = 0, 0
  for _, r in ipairs(recruits) do
    while true do
      local done = true
      for _, ij in ipairs(O.rows(X, t, r.param)) do
        local i, j = ij[1], ij[2]
        if r.price ~= nil then
          local k = first(t, i + 1, j, CONSUME)
          if k and t:int(k, X.SCONS.price) ~= U.i32(r.price) then
            t:set(k, X.SCONS.price, r.price)
            priced = priced + 1
          end
        end
        local players = {}
        for _, q in ipairs(r.reqs) do
          if q.kind == 1 then players[#players + 1] = q end
        end
        if not (#players == 0 and r.mode == "add") and cb and cr and ce then
          local ob, oe = first(t, i + 1, j, COND_BEG), first(t, i + 1, j, COND_END)
          local rows_new = {}
          if r.mode == "add" and ob and oe then
            for k = ob + 1, oe - 1 do
              rows_new[#rows_new + 1] = { t:uint(k, X.SCOND.card) or 0, t:int(k, X.SCOND.level) or 0 }
            end
          end
          for _, q in ipairs(players) do rows_new[#rows_new + 1] = { q.ids[1], U.i32(q.level) } end
          for k = #rows_new, X.K.max_req + 1, -1 do rows_new[k] = nil end
          local block = {}
          if #rows_new > 0 then
            local b = U.copy_entry(cb)
            b.values = { #rows_new }
            block[#block + 1] = b
            for _, x in ipairs(rows_new) do
              local e = U.copy_entry(cr)
              e.values = { x[1], x[2], 0 }
              block[#block + 1] = e
            end
            local e = U.copy_entry(ce)
            e.values = {}
            block[#block + 1] = e
          end
          local a, z = j, j
          if ob and oe then a, z = ob, oe + 1 end
          if not same(t:entries(a, z), block) then
            t:splice(a, z, block)
            conds = conds + 1
            -- indices moved: scan again
            done = false
            break
          end
        end
      end
      if done then break end
    end
  end
  if removed + priced + conds > 0 then
    VRFW.log.info("office: " .. removed .. " row(s) of hidden cards removed, " .. priced .. " price(s), " .. conds ..
      " condition block(s) written")
  end
  return nil
end

O.int_str = int_str
O.perr = perr
return O
