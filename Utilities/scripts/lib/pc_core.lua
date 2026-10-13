-- Utilities › passive configurator: the pure part (no game access). Catalogue, slot rules, layout, defaults,
-- derivation, set checks; ported from utilities-core's passive_config (Rust, removed 2026-10-10) with the same rules.
-- docs/game/mechanics/pasivas-configurables.md.

local M = {}

M.N_SLOTS = 5
M.SPECIAL_SLOT = 1          -- Lua slots are 1-based here; the game's slot = index - 1
M.GENERAL_SLOTS = 3         -- archetype mode: slots 2-3 general, 4-5 archetype
M.NO_ARCHETYPE = 6
M.N_ARCHETYPES = 6
M.CAT_ALL, M.CAT_SHOT, M.CAT_FOCUS, M.CAT_DUEL, M.CAT_WALL, M.CAT_TEAM = 0, 1, 2, 3, 4, 5
M.CAT_ARCH_FIRST, M.CAT_ARCH_LAST = 6, 11
M.CAT_REWARD = 12
M.GENERAL_CATS = { 1, 2, 3, 4, 5, 12 }
M.ARCH_CATS = { 6, 7, 8, 9, 10, 11 }
M.KIND_MATCH = 6
M.ARCH_NAMES = { [0] = "Breach", "Counter", "Bond", "Tension", "Rough Play", "Justice" }
-- archetypes declared by mods (VRFW.archetype/1, content\archetypes\*.toml; docs/framework/archetype.md): number 7+
-- -> true. Their passives (the declaration's `passives`) are archetype passives of category 6 + number.
M.CUSTOM = {}
M.LIST_HDL_BASE = 0xE000
M.LIST_HDL_MAX = 0x0FFF
M.BLOB = "passive_config.json"
M.FILE_VERSION = 1

-- card classes
M.FULL, M.IDOL, M.BUILD, M.PRIME, M.BLOCKED = "full", "idol", "build", "prime", "blocked"
-- slot kinds (code = CMND_UTIL_PC_SLOT's 5th answer)
M.ANY, M.SPECIAL, M.GENERAL, M.ARCHETYPE = "any", "special", "general", "archetype"
M.KIND_CODE = { any = 0, special = 1, general = 2, archetype = 3 }
-- set errors (CMND_UTIL_PC_SET's code)
M.E_NOT_ALLOWED, M.E_LOCKED, M.E_WRONG_CLASS, M.E_DUPLICATE, M.E_UNKNOWN, M.E_BAD_SLOT, M.E_LIMIT = 1, 2, 3, 4, 5, 6, 7

local band = bit32.band

function M.u32(v)
  if type(v) ~= "number" then return 0 end
  local n = v >= 0 and math.floor(v) or math.ceil(v)
  return n % 4294967296
end

function M.key(hdl)
  return string.format("%08X", M.u32(hdl))
end

function M.list_handle(i)
  return bit32.bor(M.LIST_HDL_BASE, band(i, M.LIST_HDL_MAX))
end

-- index (0-based) of a list row handle, nil for any other handle
function M.list_index(hdl)
  if band(hdl, bit32.bnot(M.LIST_HDL_MAX)) == M.LIST_HDL_BASE then return band(hdl, M.LIST_HDL_MAX) end
  return nil
end

function M.category_archetype(cat)
  if cat >= M.CAT_ARCH_FIRST and cat <= M.CAT_ARCH_LAST then return cat - M.CAT_ARCH_FIRST end
  if cat ~= M.CAT_REWARD and M.CUSTOM[cat - M.CAT_ARCH_FIRST] then return cat - M.CAT_ARCH_FIRST end
  return nil
end

-- a declared archetype (number 7+, a log name): its category (6 + number) joins the archetype slots' categories
function M.register_archetype(n, name)
  if type(n) ~= "number" or n <= M.NO_ARCHETYPE or M.CUSTOM[n] then return false end
  M.CUSTOM[n] = true
  M.ARCH_NAMES[n] = name or ("archetype " .. n)
  M.ARCH_CATS[#M.ARCH_CATS + 1] = M.CAT_ARCH_FIRST + n
  return true
end

function M.is_general_category(cat)
  return (cat >= M.CAT_SHOT and cat <= M.CAT_TEAM) or cat == M.CAT_REWARD
end

function M.kind_of_handle(hdl)
  return band(bit32.rshift(hdl, 12), 0xF)
end

-- ---------------------------------------------------------------------------------------------- ids

-- "0x…" / decimal → the number, any other text → crc32 of it; integers as unsigned 32-bit
function M.id_of(v)
  if type(v) == "number" then return M.u32(v) end
  if type(v) ~= "string" then return nil end
  local t = v:match("^%s*(.-)%s*$")
  local h = t:match("^0[xX](%x+)$")
  if h then return tonumber(h, 16) % 4294967296 end
  if t:match("^%d+$") then return tonumber(t) % 4294967296 end
  return VRFW.ui.crc32(t)
end

-- ---------------------------------------------------------------------------------------------- config

-- [passives] of the mod's merged config (absent keys = defaults)
function M.config(raw)
  local c = { max_slots = 3, enabled = true, unlock = "", always_unlocked = true, build_rarities = { 5, 6, 7, 8 }, build_slots = { 4, 5 }, log_first = 20 }
  if type(raw) ~= "table" then return c, nil end
  local warn
  for k, v in pairs(raw) do
    if c[k] == nil then
      -- unknown keys ignored, as the Rust reader did with other sections
    elseif type(v) ~= type(c[k]) and not (k == "max_slots" and type(v) == "number") then
      warn = string.format("[passives] %s: a %s is expected (default kept)", k, type(c[k]))
    else
      c[k] = v
    end
  end
  return c, warn
end

function M.parse_unlock(s)
  s = (tostring(s or "")):lower():match("^%s*(.-)%s*$")
  if s == "all" or s == "todas" then return "all" end
  if s == "configured" or s == "configuradas" then return "configured" end
  return nil
end

-- ---------------------------------------------------------------------------------------------- layout

-- max configurable slots (3..5) + the warning when out of range; order = fixed opening order (slot indices) or nil
function M.layout(max, order)
  local m = math.floor(tonumber(max) or 3)
  local c = math.min(math.max(m, 3), 5)
  local w
  if c ~= m then
    w = string.format("[passives] max_slots = %d is out of range (3..=5): using %d (fix it in mods\\utilities\\config.toml)", m, c)
  end
  return { max = c, order = order }, w
end

function M.with_order(l, order)
  return { max = l.max, order = order }
end

function M.allows(l, k)
  if l.order then
    for i = 1, l.max do
      if l.order[i] == k then return true end
    end
    return false
  end
  return k >= 1 and k <= M.N_SLOTS
end

-- the configured slots that are applied ({[k] = true}); open = the slots this player may change
function M.active(l, cfg, open)
  local out, n = {}, 0
  for k = 1, M.N_SLOTS do
    if (cfg[k] or 0) ~= 0 and open[k] and M.allows(l, k) then
      if l.order then
        out[k] = true
      elseif n < l.max then
        n = n + 1
        out[k] = true
      end
    end
  end
  return out
end

function M.inactive(l, cfg, open)
  local a, v = M.active(l, cfg, open), {}
  for k = 1, M.N_SLOTS do
    if (cfg[k] or 0) ~= 0 and open[k] and not a[k] then v[#v + 1] = k end
  end
  return v
end

function M.can_set(l, cfg, open, k)
  if not M.allows(l, k) then return false end
  if l.order or not cfg then return true end
  local a, n = M.active(l, cfg, open), 0
  for i = 1, M.N_SLOTS do
    if a[i] then n = n + 1 end
  end
  return a[k] or n < l.max
end

-- ---------------------------------------------------------------------------------------------- rules

function M.default_rules()
  return { kinds = { "general", "general", "general", "archetype", "archetype" }, order = nil, archetype = false, unlock = "configured", locked = {}, special_tile = 0, origin = "" }
end

local TYPED = { "special", "general", "general", "archetype", "archetype" }

local function same_kinds(a, b)
  for i = 1, M.N_SLOTS do
    if a[i] ~= b[i] then return false end
  end
  return true
end

function M.archetype_mode(r)
  return r.archetype and same_kinds(r.kinds, TYPED)
end

function M.kind(r, k)
  return r.kinds[k] or M.ANY
end

function M.locks(r, rarity, k)
  for _, l in ipairs(r.locked) do
    local rr, ss = false, false
    for _, x in ipairs(l[1]) do rr = rr or x == rarity end
    for _, x in ipairs(l[2]) do ss = ss or x == k end
    if rr and ss then return true end
  end
  return false
end

function M.special_slot(r)
  for k = 1, M.N_SLOTS do
    if r.kinds[k] == M.SPECIAL then return k end
  end
  return nil
end

function M.describe(r)
  local order = "free choice of slots"
  if r.order then
    order = "fixed order " .. table.concat(r.order, " ")
  end
  return string.format("slots [%s], %s, archetype %s, unlock %s, %d rarity lock(s)%s", table.concat(r.kinds, ", "), order,
    M.archetype_mode(r) and "from the archetype slots" or "untouched", r.unlock, #r.locked,
    r.origin == "" and " (the game's own slots)" or (" (declared by " .. r.origin .. ")"))
end

-- [slots] of a declaration file → rules (+ warnings)
function M.parse_slots(mod_id, t)
  local r = M.default_rules()
  r.origin = mod_id
  local warn = {}
  if t.kinds ~= nil then
    local ok = type(t.kinds) == "table" and #t.kinds == M.N_SLOTS
    local ks = {}
    if ok then
      for i = 1, M.N_SLOTS do
        local s = type(t.kinds[i]) == "string" and t.kinds[i]:lower():match("^%s*(.-)%s*$") or ""
        if M.KIND_CODE[s] == nil then ok = false else ks[i] = s end
      end
    end
    if ok then r.kinds = ks else warn[#warn + 1] = "[slots] kinds: 5 of any / special / general / archetype expected (ignored)" end
  end
  if t.order ~= nil then
    local o, seen, n = {}, {}, 0
    if type(t.order) == "table" then
      for _, x in ipairs(t.order) do
        if type(x) == "number" and x >= 1 and x <= M.N_SLOTS and x == math.floor(x) then
          o[#o + 1] = x
          if not seen[x] then seen[x] = true; n = n + 1 end
        end
      end
    end
    if #o == M.N_SLOTS and n == M.N_SLOTS then r.order = o else warn[#warn + 1] = "[slots] order: the slots 1-5, each once (ignored: free choice)" end
  end
  if t.archetype ~= nil then
    if type(t.archetype) == "boolean" then r.archetype = t.archetype else warn[#warn + 1] = "[slots] archetype: true / false (ignored)" end
    if r.archetype and not same_kinds(r.kinds, TYPED) then
      warn[#warn + 1] = "[slots] archetype = true needs kinds = special, general, general, archetype, archetype (archetype mode off)"
    end
  end
  if t.unlock ~= nil then
    local u = M.parse_unlock(t.unlock)
    if u then r.unlock = u else warn[#warn + 1] = "[slots] unlock: \"configured\" or \"all\" (ignored)" end
  end
  if t.special_tile ~= nil then
    local x = M.id_of(t.special_tile)
    if x and x ~= 0 then r.special_tile = x else warn[#warn + 1] = "[slots] special_tile: a sprite name (ignored)" end
  end
  if type(t.locked) == "table" then
    for k, l in ipairs(t.locked) do
      local rar, sl = {}, {}
      for _, x in ipairs(type(l) == "table" and type(l.rarities) == "table" and l.rarities or {}) do
        if type(x) == "number" and x >= 0 then rar[#rar + 1] = x end
      end
      for _, x in ipairs(type(l) == "table" and type(l.slots) == "table" and l.slots or {}) do
        if type(x) == "number" and x >= 1 and x <= M.N_SLOTS then sl[#sl + 1] = x end
      end
      if #rar == 0 or #sl == 0 then
        warn[#warn + 1] = string.format("[[slots.locked]] #%d: needs rarities and slots (1-5)", k)
      else
        r.locked[#r.locked + 1] = { rar, sl }
      end
    end
  end
  return r, warn
end

-- ---------------------------------------------------------------------------------------------- declarations

function M.new_decl()
  return { passives = {}, titles = {}, shared_specials = {}, restricted_specials = {}, effect_icons = {}, reward_funcs = {}, reward_effects = {}, origin = {}, slots = nil, aliases = {}, n_passives = 0 }
end

local function entry_id(t, alt)
  local v = t.key
  if v == nil then v = t.id end
  if v == nil then v = t[alt] end
  local x = v ~= nil and M.id_of(v) or nil
  if x == 0 then return nil end
  return x
end

-- one declaration file (schema utilities.passive_config/1) of mod `mod_id` → warnings; nil + why = not this schema
function M.add_decl(d, mod_id, doc)
  if doc.schema ~= "utilities.passive_config/1" then
    if doc.schema == nil then return nil, "no schema (expected \"utilities.passive_config/1\")" end
    return nil, string.format("schema %q is not \"utilities.passive_config/1\"", tostring(doc.schema))
  end
  local warn = {}
  for k, t in ipairs(type(doc.passive) == "table" and doc.passive or {}) do
    local id = entry_id(t, "passive")
    if not id then
      warn[#warn + 1] = string.format("[[passive]] #%d: no key / id", k)
    else
      if d.passives[id] == nil then d.passives[id] = "auto"; d.n_passives = d.n_passives + 1 end
      if type(t.exclusive) == "boolean" then d.passives[id] = t.exclusive end
      if type(t.title) == "string" and t.title ~= "" then d.titles[id] = t.title end
      d.origin[id] = mod_id
      if t.aliases ~= nil then
        if type(t.aliases) == "table" then
          for _, old in ipairs(t.aliases) do
            local o = M.id_of(old)
            if o and o ~= 0 and o ~= id then d.aliases[o] = id end
          end
        else
          warn[#warn + 1] = string.format("[[passive]] #%d: aliases: a list of former keys / ids (ignored)", k)
        end
      end
    end
  end
  for k, t in ipairs(type(doc.special) == "table" and doc.special or {}) do
    local id = entry_id(t, "passive")
    if not id then
      warn[#warn + 1] = string.format("[[special]] #%d: no key / id", k)
    else
      local who = {}
      for _, c in ipairs(type(t.characters) == "table" and t.characters or {}) do
        local x = M.id_of(c)
        if x and x ~= 0 then who[#who + 1] = x end
      end
      if #who == 0 then
        local dup = false
        for _, x in ipairs(d.shared_specials) do dup = dup or x == id end
        if not dup then d.shared_specials[#d.shared_specials + 1] = id end
      else
        local found
        for _, r in ipairs(d.restricted_specials) do
          if r[1] == id then found = r end
        end
        if found then
          for _, x in ipairs(who) do found[2][#found[2] + 1] = x end
        else
          d.restricted_specials[#d.restricted_specials + 1] = { id, who }
        end
      end
      if type(t.title) == "string" and t.title ~= "" then d.titles[id] = t.title end
    end
  end
  if type(doc.slots) == "table" then
    local r, w = M.parse_slots(mod_id, doc.slots)
    if d.slots and d.slots.origin ~= mod_id then
      warn[#warn + 1] = string.format("[slots] of %s replaces the slot rules of %s", mod_id, d.slots.origin)
    end
    for _, x in ipairs(w) do warn[#warn + 1] = x end
    d.slots = r
  end
  for k, t in ipairs(type(doc.effect_icon) == "table" and doc.effect_icon or {}) do
    local e, s = t.effect ~= nil and M.id_of(t.effect), t.sprite ~= nil and M.id_of(t.sprite)
    if e and s and e ~= 0 and s ~= 0 then d.effect_icons[e] = s else warn[#warn + 1] = string.format("[[effect_icon]] #%d: needs effect and sprite", k) end
  end
  for k, t in ipairs(type(doc.reward_handler) == "table" and doc.reward_handler or {}) do
    local f = t.func ~= nil and M.id_of(t.func)
    if f and f ~= 0 then d.reward_funcs[f] = true else warn[#warn + 1] = string.format("[[reward_handler]] #%d: no func", k) end
  end
  for k, t in ipairs(type(doc.reward_effect) == "table" and doc.reward_effect or {}) do
    local f = t.id ~= nil and M.id_of(t.id)
    if f and f ~= 0 then d.reward_effects[f] = true else warn[#warn + 1] = string.format("[[reward_effect]] #%d: no id", k) end
  end
  return warn
end

-- the mods' passives an own-passive column carries become exclusive unless declared exclusive = false
function M.exclusive(d, own_ids)
  local out = {}
  for id, ex in pairs(d.passives) do
    if ex == true or (ex == "auto" and own_ids[id]) then out[id] = true end
  end
  return out
end

-- ---------------------------------------------------------------------------------------------- catalogue

function M.is_retail_pickable_key(key)
  return type(key) == "string" and key:match("^ps1%d%d%d%d$") ~= nil
end

-- raws = { {id, key, kind, defs = {…}, value} }, defs = { [def] = {category, builds = {…}, effects = {…}} },
-- offer = { mods = {[id]=true}, exclusive = {[id]=true}, rewards = {[basic]=true}, archetype_of = {[id]=number} }
-- (archetype_of: the passives of the mods' declared archetypes, category 6 + number)
function M.build_catalog(raws, defs, offer)
  local c = { by_id = {}, list = {}, exclusive = offer.exclusive, specials = {}, restricted = {}, custom_defs = {} }
  local best = {}
  for _, r in ipairs(raws) do
    local def = r.defs[1]
    local d = def and defs[def]
    if r.kind == M.KIND_MATCH and d then
      local arch
      local declared = offer.archetype_of and offer.archetype_of[r.id]
      if declared and M.CUSTOM[declared] then arch = declared end
      if arch == nil then
        for _, b in ipairs(d.builds) do
          if b < M.N_ARCHETYPES then arch = b; break end
        end
      end
      if arch == nil then arch = M.category_archetype(d.category) end
      local reward = false
      if arch == nil and M.is_general_category(d.category) then
        for _, e in ipairs(d.effects) do reward = reward or offer.rewards[e] == true end
      end
      local category = reward and M.CAT_REWARD or d.category
      if declared and arch == declared then
        category = M.CAT_ARCH_FIRST + declared
        c.custom_defs[def] = declared
      end
      local info = { id = r.id, key = r.key, def = def, category = category, archetype = arch, value = r.value }
      local pickable = M.is_retail_pickable_key(r.key) or offer.mods[r.id]
      if pickable and not offer.exclusive[r.id] and (M.is_general_category(category) or M.category_archetype(category) ~= nil) then
        local b = best[def]
        if b == nil or r.value > b[1] or (r.value == b[1] and r.key < b[2]) then best[def] = { r.value, r.key, r.id } end
      end
      c.by_id[r.id] = info
    end
  end
  for _, b in pairs(best) do c.list[#c.list + 1] = b[3] end
  table.sort(c.list, function(a, b)
    local x, y = c.by_id[a], c.by_id[b]
    if x.category ~= y.category then return x.category < y.category end
    return x.key < y.key
  end)
  return c
end

local function remove_from_list(c, set)
  local v = {}
  for _, id in ipairs(c.list) do
    if not set[id] then v[#v + 1] = id end
  end
  c.list = v
end

-- shared specials (known passives only; the unknown ones are returned), taken out of the list
function M.set_shared_specials(c, ids)
  local unknown, set = {}, {}
  c.specials = {}
  for _, id in ipairs(ids) do
    if not c.by_id[id] then
      unknown[#unknown + 1] = id
    elseif not set[id] then
      set[id] = true
      c.specials[#c.specials + 1] = id
    end
  end
  remove_from_list(c, set)
  return unknown
end

function M.set_restricted_specials(c, rows)
  local unknown, set = {}, {}
  c.restricted = {}
  for _, r in ipairs(rows) do
    local id, who = r[1], r[2]
    if not c.by_id[id] then
      unknown[#unknown + 1] = id
    else
      local found
      for _, x in ipairs(c.restricted) do
        if x.id == id then found = x end
      end
      if not found then
        found = { id = id, who = {} }
        c.restricted[#c.restricted + 1] = found
      end
      for _, w in ipairs(who) do found.who[w] = true end
      set[id] = true
    end
  end
  remove_from_list(c, set)
  return unknown
end

function M.archetype(c, id)
  local p = c.by_id[id]
  return p and p.archetype
end

function M.is_archetype(c, id)
  return M.archetype(c, id) ~= nil
end

function M.def_of(c, id)
  local p = c.by_id[id]
  return p and p.def
end

function M.is_pickable(c, id)
  for _, x in ipairs(c.list) do
    if x == id then return true end
  end
  return false
end

function M.pick_list(c, archetype_slot, cat, exclude)
  local v = {}
  for _, id in ipairs(c.list) do
    local p = c.by_id[id]
    local class_ok
    if archetype_slot then class_ok = p.archetype ~= nil else class_ok = p.archetype == nil and M.is_general_category(p.category) end
    if class_ok and (cat == M.CAT_ALL or p.category == cat) and not exclude[p.def] then v[#v + 1] = id end
  end
  return v
end

function M.categories(c, archetype_slot, exclude)
  local v = { M.CAT_ALL }
  for _, cat in ipairs(archetype_slot and M.ARCH_CATS or M.GENERAL_CATS) do
    if #M.pick_list(c, archetype_slot, cat, exclude) > 0 then v[#v + 1] = cat end
  end
  return v
end

function M.pick(c, kind, cat, exclude)
  if kind == M.GENERAL then return M.pick_list(c, false, cat, exclude) end
  if kind == M.ARCHETYPE then return M.pick_list(c, true, cat, exclude) end
  local v = {}
  for _, id in ipairs(c.list) do
    local p = c.by_id[id]
    if (cat == M.CAT_ALL or p.category == cat) and not exclude[p.def] then v[#v + 1] = id end
  end
  return v
end

function M.kind_categories(c, kind, exclude)
  if kind == M.GENERAL then return M.categories(c, false, exclude) end
  if kind == M.ARCHETYPE then return M.categories(c, true, exclude) end
  if kind == M.SPECIAL then return { M.CAT_ALL } end
  local v = { M.CAT_ALL }
  for _, cats in ipairs({ M.GENERAL_CATS, M.ARCH_CATS }) do
    for _, cat in ipairs(cats) do
      if #M.pick(c, kind, cat, exclude) > 0 then v[#v + 1] = cat end
    end
  end
  return v
end

local function restricted_to(c, id, who)
  for _, r in ipairs(c.restricted) do
    if r.id == id then
      for _, w in ipairs(who) do
        if w ~= 0 and r.who[w] then return true end
      end
    end
  end
  return false
end

function M.special_allowed(c, own, who, id)
  if id == 0 then return false end
  if own ~= 0 and id == own then return true end
  for _, x in ipairs(c.specials) do
    if x == id then return true end
  end
  return restricted_to(c, id, who)
end

function M.special_list(c, own, who, exclude)
  local v, has = {}, {}
  if own ~= 0 then v[1] = own; has[own] = true end
  local function add(id)
    if not has[id] then
      local d = M.def_of(c, id)
      if d == nil or not exclude[d] then
        v[#v + 1] = id
        has[id] = true
      end
    end
  end
  for _, id in ipairs(c.specials) do add(id) end
  for _, r in ipairs(c.restricted) do
    if restricted_to(c, r.id, who) then add(r.id) end
  end
  return v
end

function M.archetype_defaults(c, a)
  local v = {}
  for _, id in ipairs(c.list) do
    if c.by_id[id].archetype == a then v[#v + 1] = id end
  end
  return v
end

-- ---------------------------------------------------------------------------------------------- slots

function M.card_of(rarity, badge)
  if badge ~= 0 then return M.BLOCKED end
  if rarity >= 5 and rarity <= 7 then return M.IDOL end
  if rarity == 8 then return M.BUILD end
  if rarity == 10 then return M.PRIME end
  return M.FULL
end

function M.slot_open(r, card, rarity, k)
  return card ~= M.BLOCKED and k >= 1 and k <= M.N_SLOTS and not M.locks(r, rarity, k)
end

function M.open_slots(r, card, rarity)
  local o = {}
  for k = 1, M.N_SLOTS do o[k] = M.slot_open(r, card, rarity, k) end
  return o
end

function M.slot_open_in(r, card, rarity, k, l)
  return M.allows(l, k) and M.slot_open(r, card, rarity, k)
end

-- the own passive that replaces slot k (1-5) of a card (nil = the slot's retail passive)
function M.slot_override(cfg, own, k, rarity, badge)
  local id = own and own[k] or 0
  if id == 0 or badge ~= 0 then return nil end
  local rr, ss = false, false
  for _, x in ipairs(cfg.build_rarities) do rr = rr or x == rarity end
  for _, x in ipairs(cfg.build_slots) do ss = ss or x == k end
  if rr and ss then return nil end
  return id
end

local function position_categories(pos)
  if pos == 1 then return { M.CAT_WALL, M.CAT_FOCUS, M.CAT_DUEL } end
  if pos == 3 then return { M.CAT_FOCUS, M.CAT_SHOT, M.CAT_DUEL } end
  if pos == 4 then return { M.CAT_DUEL, M.CAT_WALL, M.CAT_FOCUS } end
  return { M.CAT_SHOT, M.CAT_FOCUS, M.CAT_DUEL }
end

-- a general passive for general slot index g (0-1 = slots 2-3) of a player at position pos, not in `used` (defs)
function M.general_default(c, g, pos, used)
  local prefs = position_categories(pos)
  local order = { prefs[math.min(g, 2) + 1], prefs[1], prefs[2], prefs[3], M.CAT_TEAM }
  for _, cat in ipairs(order) do
    local l = M.pick_list(c, false, cat, used)
    if l[1] then return l[1] end
  end
  return 0
end

local function copy5(a)
  return { a[1], a[2], a[3], a[4], a[5] }
end

-- the slots of a player who configured nothing (s = subject: card, rarity, base, rolled, old, main_position,
-- special, who)
function M.default_slots(c, s, r)
  if s.card == M.BLOCKED then return copy5(s.base) end
  if not M.archetype_mode(r) then
    local out = copy5(s.base)
    for k = 1, M.N_SLOTS do
      if M.kind(r, k) == M.SPECIAL then out[k] = s.special end
    end
    return out
  end
  if s.card == M.IDOL then
    local out = copy5(s.base)
    out[M.SPECIAL_SLOT] = s.special
    return out
  end
  local out = { 0, 0, 0, 0, 0 }
  out[M.SPECIAL_SLOT] = s.special
  local used = {}
  local d = M.def_of(c, s.special)
  if d then used[d] = true end
  local arch = {}
  local function arch_of_base()
    local v = {}
    for k = M.GENERAL_SLOTS + 1, M.N_SLOTS do
      if M.is_archetype(c, s.base[k]) then v[#v + 1] = s.base[k] end
    end
    return v
  end
  if s.card == M.BUILD or s.card == M.PRIME then
    arch = arch_of_base()
  elseif s.old then
    local a = s.rolled
    if a ~= nil and a < M.N_ARCHETYPES then
      for _, k in ipairs({ 4, 5, 1, 2, 3 }) do
        local id = s.base[k]
        if M.archetype(c, id) == a and #arch < 2 then
          local dup = false
          for _, x in ipairs(arch) do dup = dup or M.def_of(c, x) == M.def_of(c, id) end
          if not dup then arch[#arch + 1] = id end
        end
      end
      for _, id in ipairs(M.archetype_defaults(c, a)) do
        if #arch >= 2 then break end
        local dup = false
        for _, x in ipairs(arch) do dup = dup or M.def_of(c, x) == M.def_of(c, id) end
        if not dup then arch[#arch + 1] = id end
      end
    else
      arch = arch_of_base()
    end
  end
  for i = 1, math.min(#arch, M.N_SLOTS - M.GENERAL_SLOTS) do
    out[M.GENERAL_SLOTS + i] = arch[i]
    local dd = M.def_of(c, arch[i])
    if dd then used[dd] = true end
  end
  for k = M.SPECIAL_SLOT + 1, M.GENERAL_SLOTS do
    local dd = M.def_of(c, s.base[k])
    if dd and not M.is_archetype(c, s.base[k]) then used[dd] = true end
  end
  local displaced = {}
  for k = M.GENERAL_SLOTS + 1, M.N_SLOTS do
    local id = s.base[k]
    local kept = false
    for j = M.GENERAL_SLOTS + 1, M.N_SLOTS do kept = kept or out[j] == id end
    if id ~= 0 and not kept and not M.is_archetype(c, id) and M.def_of(c, id) then displaced[#displaced + 1] = id end
  end
  for k = M.SPECIAL_SLOT + 1, M.GENERAL_SLOTS do
    local b = s.base[k]
    if b == 0 or not M.is_archetype(c, b) then
      out[k] = b
    else
      local keep = {}
      for _, id in ipairs(displaced) do
        local dd = M.def_of(c, id)
        if dd and not used[dd] then keep[#keep + 1] = id end
      end
      displaced = keep
      local g
      if #displaced == 0 then
        g = M.general_default(c, k - M.SPECIAL_SLOT - 1, s.main_position, used)
      else
        g = table.remove(displaced, 1)
      end
      local dd = M.def_of(c, g)
      if dd then used[dd] = true end
      out[k] = g
    end
  end
  return out
end

function M.kind_accepts(c, s, r, k, id)
  local kind = M.kind(r, k)
  if kind == M.SPECIAL then return M.special_allowed(c, s.special, s.who, id) end
  if kind == M.GENERAL then return not M.is_archetype(c, id) end
  if kind == M.ARCHETYPE then return M.is_archetype(c, id) end
  return true
end

-- the slots a player uses under a layout: his applied choices over the defaults
function M.effective(c, s, cfg, l, r)
  local out = M.default_slots(c, s, r)
  if cfg then
    local act = M.active(l, cfg, M.open_slots(r, s.card, s.rarity))
    for k = 1, M.N_SLOTS do
      if act[k] and M.kind_accepts(c, s, r, k, cfg[k]) then out[k] = cfg[k] end
    end
  end
  return out
end

-- may slot k of player s (current slots eff, stored choices stored) take id (0 = back to the default)? nil = yes,
-- else the error code
function M.check_set(c, s, eff, stored, k, id, l, r)
  if s.card == M.BLOCKED then return M.E_NOT_ALLOWED end
  if k < 1 or k > M.N_SLOTS then return M.E_BAD_SLOT end
  if not M.slot_open_in(r, s.card, s.rarity, k, l) then return M.E_LOCKED end
  if id == 0 then return nil end
  if not M.can_set(l, stored, M.open_slots(r, s.card, s.rarity), k) then return M.E_LIMIT end
  local kind = M.kind(r, k)
  local p
  if kind == M.SPECIAL then
    p = c.by_id[id]
    if not p then return M.E_UNKNOWN end
    if not M.special_allowed(c, s.special, s.who, id) then return M.E_WRONG_CLASS end
  else
    p = c.by_id[id]
    if not p or not M.is_pickable(c, id) then return M.E_UNKNOWN end
    if (kind == M.GENERAL and p.archetype ~= nil) or (kind == M.ARCHETYPE and p.archetype == nil) then return M.E_WRONG_CLASS end
  end
  for j = 1, M.N_SLOTS do
    if j ~= k and eff[j] ~= 0 and M.def_of(c, eff[j]) == p.def then return M.E_DUPLICATE end
  end
  return nil
end

function M.current_index(c, ids, current)
  local d = M.def_of(c, current)
  if d == nil then return nil end
  for i, id in ipairs(ids) do
    if M.def_of(c, id) == d then return i end
  end
  return nil
end

function M.other_defs(c, eff, k)
  local v = {}
  for j = 1, M.N_SLOTS do
    if j ~= k and eff[j] ~= 0 then
      local d = M.def_of(c, eff[j])
      if d then v[d] = true end
    end
  end
  return v
end

-- ---------------------------------------------------------------------------------------------- archetype

-- (first, second, name): the player's archetype from his archetype slots 4-5 (6 = none)
function M.derive(c, eff)
  local a, b = M.archetype(c, eff[4]), M.archetype(c, eff[5])
  if a and b and a == b then return a, M.NO_ARCHETYPE, M.ARCH_NAMES[a] end
  if a and b then return a, b, M.ARCH_NAMES[a] .. " and " .. M.ARCH_NAMES[b] end
  local x = a or b
  if x then return x, M.NO_ARCHETYPE, M.ARCH_NAMES[x] end
  return M.NO_ARCHETYPE, M.NO_ARCHETYPE, "no archetype"
end

-- ---------------------------------------------------------------------------------------------- store

function M.new_store(slot)
  return { version = M.FILE_VERSION, slot = slot, watermark = nil, players = {} }
end

-- configured slots of a character (nil when none or the handle now holds another param)
function M.store_get(st, hdl, param)
  local e = st.players[M.key(hdl)]
  if e and e.param == param then return e.slots end
  return nil
end

-- set one slot (0 clears it); true when something changed
function M.store_set(st, hdl, param, k, id)
  if k < 1 or k > M.N_SLOTS then return false end
  local key = M.key(hdl)
  local e = st.players[key]
  if not e or e.param ~= param then
    e = { param = param, slots = { 0, 0, 0, 0, 0 } }
    st.players[key] = e
  end
  local changed = e.slots[k] ~= id
  e.slots[k] = id
  local any = false
  for j = 1, M.N_SLOTS do any = any or e.slots[j] ~= 0 end
  if not any then st.players[key] = nil end
  return changed
end

function M.store_reset(st, hdl)
  local key = M.key(hdl)
  local had = st.players[key] ~= nil
  st.players[key] = nil
  return had
end

function M.is_old(st, get_order)
  return st.watermark == nil or get_order <= st.watermark
end

-- former passive ids → current ids; how many slots changed
function M.remap(st, aliases)
  local n = 0
  for _, e in pairs(st.players) do
    for k = 1, M.N_SLOTS do
      local to = aliases[e.slots[k]]
      if to and to ~= 0 and to ~= e.slots[k] then
        e.slots[k] = to
        n = n + 1
      end
    end
  end
  return n
end

-- a decoded blob → a store (players without any configured slot dropped); nil + why when it is not one
function M.store_from(doc, slot)
  if type(doc) ~= "table" then return nil, "not a JSON object" end
  local st = M.new_store(slot)
  st.version = tonumber(doc.version) or M.FILE_VERSION
  if type(doc.watermark) == "number" then st.watermark = doc.watermark end
  if doc.players ~= nil and type(doc.players) ~= "table" then return nil, "players: not an object" end
  for k, e in pairs(doc.players or {}) do
    if type(k) ~= "string" or type(e) ~= "table" or type(e.param) ~= "number" or type(e.slots) ~= "table" then
      return nil, "players." .. tostring(k) .. ": not { param, slots }"
    end
    local s, any = {}, false
    for j = 1, M.N_SLOTS do
      s[j] = M.u32(tonumber(e.slots[j]) or 0)
      any = any or s[j] ~= 0
    end
    if any then st.players[k] = { param = M.u32(e.param), slots = s } end
  end
  return st
end

-- the JSON document of a store (same shape as utilities.dll wrote: version, slot, watermark, players)
function M.store_doc(st)
  local players = {}
  for k, e in pairs(st.players) do
    players[k] = { param = e.param, slots = { e.slots[1], e.slots[2], e.slots[3], e.slots[4], e.slots[5] } }
  end
  return { version = st.version or M.FILE_VERSION, slot = st.slot, watermark = st.watermark, players = players }
end

return M
