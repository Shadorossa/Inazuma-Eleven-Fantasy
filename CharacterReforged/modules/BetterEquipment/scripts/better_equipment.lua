-- Better Equipment › the affinity and set stats of the user's players (docs/game/mods/better-equipment.md). Data:
-- every active mod's content\better_equipment\affinity.toml (per item: position, element, raised fractions of S) and
-- sets.toml (members, bonus tiers); content\better_equipment\rules.toml (the affinity rates, the cap). S is the item
-- type's (VRFW.item.equipment_scale). The result is the native table BetterEquipment.StatAdd (key: saved character
-- handle, stat 0..7) that content\game\better_equipment.toml's [[VRFW.MatchStat]] adds to the match copies.
-- Computed at each save load, at each match start and after each equip / remove command; never per frame. The item
-- profiles are data (content\items\profiles.toml); the passives and set effects are blocks of the framework's passive engine.

BetterEquipment = BetterEquipment or {}

require "VRFW/lib/basics"
local info, warn = VRFW.logger("better_equipment")

local T_ADD = "BetterEquipment.StatAdd"
local STAT_INDEX = { kick = 0, control = 1, technique = 2, pressure = 3, physical = 4, agility = 5, intelligence = 6 }
local POSITION = { GK = 1, FW = 2, MF = 3, DF = 4 }
local ELEMENT = { wind = 1, forest = 2, fire = 3, mountain = 4, void = 5 }
local TWO32 = 4294967296

local DATA = nil   -- { rules, affinity = { [item id] = entry }, sets = { { key, members = { [id] = true }, bonus } } }

local function id_of(key)
  local f = VRFW.crc32 or (VRFW.ui and VRFW.ui.crc32)
  return f(key) % TWO32
end

-- the exclusive count of the worn sets (VRFW.item.resolve_sets: a piece counts for one set only, the most complete
-- one, then the one with more pieces, then data order): { [set key] = pieces }, { [slot] = set key }; nil = no
-- such read (every set then counts its own pieces)
local function resolve(worn)
  local ok, counts, slots = pcall(VRFW.item.resolve_sets, worn[1], worn[2], worn[3], worn[4])
  if ok and type(counts) == "table" then return counts, (type(slots) == "table" and slots or {}) end
  return nil, nil
end

local function round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

-- every active mod's entries of one data file (load order; a later item / set replaces an earlier one)
local function load()
  if DATA then return DATA end
  local d = { rules = {}, affinity = {}, sets = {} }
  local ok, rules = pcall(VRFW.files.toml, "content/better_equipment/rules.toml")
  d.rules = (ok and type(rules) == "table") and rules or {}
  local okA, files = pcall(VRFW.files.declarations, "content/better_equipment/affinity.toml")
  for _, f in ipairs((okA and files) or {}) do
    for _, e in ipairs((f.data or {}).item or {}) do
      if type(e.item) == "string" then d.affinity[id_of(e.item)] = e end
    end
  end
  local okS, sfiles = pcall(VRFW.files.declarations, "content/better_equipment/sets.toml")
  local by_key = {}
  for _, f in ipairs((okS and sfiles) or {}) do
    for _, s in ipairs((f.data or {}).set or {}) do
      if type(s.name) == "string" then
        local key = tostring(f.mod) .. "." .. s.name
        local members, ordered = {}, {}
        local okM, list = pcall(VRFW.item.set_members, key)
        if okM and type(list) == "table" then
          for _, id in ipairs(list) do members[id % TWO32] = true; ordered[#ordered + 1] = id % TWO32 end
        else
          for _, m in ipairs(s.members or {}) do members[id_of(m)] = true; ordered[#ordered + 1] = id_of(m) end
        end
        local entry = { key = key, name = s.name, mod = f.mod, members = members, list = ordered, bonus = s.bonus or {} }
        if by_key[key] then d.sets[by_key[key]] = entry else d.sets[#d.sets + 1] = entry; by_key[key] = #d.sets end
      end
    end
  end
  -- lookups for the per-player pass: set key -> index, item id -> the indexes of its sets (data order)
  d.set_index, d.sets_of_item = by_key, {}
  for i, set in ipairs(d.sets) do
    for id in pairs(set.members) do
      local l = d.sets_of_item[id]
      if not l then l = {}; d.sets_of_item[id] = l end
      l[#l + 1] = i
    end
  end
  for _, l in pairs(d.sets_of_item) do table.sort(l) end
  local okI, ifiles = pcall(VRFW.files.declarations, "content/better_equipment/items.toml")
  d.items = {}
  for _, f in ipairs((okI and ifiles) or {}) do
    for _, e in ipairs((f.data or {}).item or {}) do
      if type(e.item) == "string" then d.items[id_of(e.item)] = { passive = e.passive, mod = f.mod } end
    end
  end
  DATA = d
  return d
end

-- the affinity rate of an item for a card: position and element match (both), the position matches (one), else none
local function affinity_rate(a, card, rules)
  local r = rules.affinity or {}
  local pos = a.position and POSITION[a.position] == card.position
  local el = a.element and (ELEMENT[a.element] == card.element or a.element == card.element)
  if pos and el then return r.both or 0 end
  if pos then return r.one or 0 end
  return 0                          -- the element alone gives nothing (rules.toml [affinity])
end

-- the per-scale tables of the per-player pass (built once per S): per item the affinity raises as { stat index + 1,
-- base points }; per set its tiers as { pieces, { stat index + 1, points }... }
local function scaled(d, s)
  local c = d.scaled
  if c and c.s == s then return c end
  c = { s = s, raises = {}, tiers = {}, cap = ((d.rules.scale or {}).cap or 1) * s }
  for id, aff in pairs(d.affinity) do
    local l = {}
    for stat, frac in pairs(aff.raises or {}) do
      local k = STAT_INDEX[stat]
      if k then l[#l + 1] = { k + 1, round(frac * s) } end
    end
    c.raises[id] = l
  end
  for i, set in ipairs(d.sets) do
    local t = {}
    for _, tier in ipairs(set.bonus) do
      local adds = {}
      for stat, frac in pairs(tier.stats or {}) do
        local k = STAT_INDEX[stat]
        local v = k and round(frac * s) or 0
        if v ~= 0 then adds[#adds + 1] = { k + 1, v } end
      end
      t[#t + 1] = { tier.pieces or 2, adds }
    end
    c.tiers[i] = t
  end
  d.scaled = c
  return c
end

-- the 8 stat additions of a saved character (nil = nothing worn / not one of the user's players)
local function additions(hdl, d, c)
  local ok, a, b, cc, e = pcall(VRFW.item.equipped, hdl)
  if not ok or a == nil then return nil end
  if a == 0 and b == 0 and cc == 0 and e == 0 then return nil end
  local worn = { a % TWO32, b % TWO32, cc % TWO32, e % TWO32 }
  local add = { 0, 0, 0, 0, 0, 0, 0, 0 }
  local any = false
  local card, card_read = nil, false
  for i = 1, 4 do
    local item = worn[i]
    local aff = item ~= 0 and d.affinity[item] or nil
    if aff then
      if not card_read then
        card_read = true
        local okR, rec = pcall(VRFW.chara.record, hdl)
        card = (okR and rec and rec.param) and VRFW.chara.card(rec.param) or nil
      end
      local rate = card and affinity_rate(aff, card, d.rules) or 0
      if rate > 0 then
        for _, r in ipairs(c.raises[item]) do
          local base = r[2]
          local bonus = math.min(round(base * rate), math.max(0, c.cap - base))
          if bonus ~= 0 then add[r[1]], any = add[r[1]] + bonus, true end
        end
      end
    end
  end
  -- the sets: only the worn pieces' sets are counted (a set needs 2 pieces for a bonus)
  local pieces, in_sets = {}, 0
  for i = 1, 4 do
    local l = worn[i] ~= 0 and d.sets_of_item[worn[i]] or nil
    if l then
      in_sets = in_sets + 1
      for _, si in ipairs(l) do pieces[si] = (pieces[si] or 0) + 1 end
    end
  end
  if in_sets >= 2 then
    local counts = resolve(worn)
    if counts then
      pieces = {}
      for key, n in pairs(counts) do
        local si = d.set_index[key]
        if si then pieces[si] = n end
      end
    end
    for si, n in pairs(pieces) do
      if n >= 2 then
        for _, tier in ipairs(c.tiers[si]) do
          if n >= tier[1] then
            for _, av in ipairs(tier[2]) do add[av[1]], any = add[av[1]] + av[2], true end
          end
        end
      end
    end
  end
  return any and add or nil
end

-- the table for every saved character
local function refresh(why)
  local d = load()
  local okS, s = pcall(VRFW.item.equipment_scale)
  s = (okS and tonumber(s)) or 0
  if s <= 0 then
    pcall(VRFW.native.table_clear, T_ADD)
    return
  end
  local c = scaled(d, s)
  local okC, saved = pcall(VRFW.chara.saved)
  local entries, players = {}, 0
  for _, ch in ipairs((okC and saved) or {}) do
    local add = additions(ch.handle, d, c)
    if add then
      players = players + 1
      for k = 1, 8 do
        if add[k] ~= 0 then entries[#entries + 1] = { { ch.handle, k - 1 }, add[k] } end
      end
    end
  end
  local ok, e = pcall(VRFW.native.table_replace, T_ADD, nil, entries)
  if not ok then warn(T_ADD .. ": " .. tostring(e)) end
  info(string.format("%s: %d player(s) with affinity / set stats (S = %d)", why, players, s))
end

-- ---- the item card's pages (Equipamiento) -------------------------------------------------------------------------
-- CMND_BETTEREQUIPMENT_ITEM_PAGE(item) -> the «Efecto» page: short lines (its passive, its set's bonus tiers, its
-- affinity), "" = nothing. CMND_BETTEREQUIPMENT_ITEM_SET(item) -> the «Conjunto» page's data:
-- { name, count, members = { [1..count] = item id }, tiers = { [i] = { pieces, text } }, worn, also }, nil = in no set.
-- An item of several sets: the set it counts for on the shown player (with it in its slot), «also» = the others.
local MOD = "BetterEquipment"

local function T(key, mod)
  local ok, s = pcall(VRFW.text, (mod or MOD) .. "." .. key)
  return (ok and type(s) == "string" and s ~= "") and s or nil
end

local function fill(template, args)
  return (string.gsub(template, "{(%w+)}", function(k)
    local v = args[k]
    return v ~= nil and tostring(v) or ""
  end))
end

local function signed(v)
  v = tonumber(v) or 0
  return (v > 0 and "+" or "") .. tostring(v)
end

-- a technique family's name in the game's language: its declaration's text key (every mod's
-- content/techniques/families.toml), as written or under the declaring mod's internal id (as Hissatsu Reforged's
-- technique_families.lua resolves it); else the id's last part
local FAMILY_TEXT = nil
local function family_name(family)
  if FAMILY_TEXT == nil then
    FAMILY_TEXT = {}
    local ok, files = pcall(VRFW.files.declarations, "content/techniques/families.toml")
    for _, f in ipairs((ok and files) or {}) do
      local v = type(f.data) == "table" and f.data.VRFW or nil
      for _, decl in ipairs((type(v) == "table" and type(v.TechniqueFamily) == "table") and v.TechniqueFamily or {}) do
        if type(decl.name) == "string" and type(decl.text) == "string" then
          local short = string.match(decl.name, "([^%.]+)$") or decl.name
          local s = nil
          local okT, t = pcall(VRFW.text, decl.text)
          if okT and type(t) == "string" and t ~= "" then s = t end
          local rest = string.match(decl.text, "^[^%.]+%.(.+)$")
          if s == nil and rest ~= nil then
            local okA, a = pcall(VRFW.text, tostring(f.mod) .. "." .. rest)
            if okA and type(a) == "string" and a ~= "" then s = a end
          end
          if s ~= nil then
            FAMILY_TEXT[decl.name] = s
            FAMILY_TEXT[short] = FAMILY_TEXT[short] or s
          end
        end
      end
    end
  end
  return FAMILY_TEXT[family] or FAMILY_TEXT[string.match(family, "([^%.]+)$") or family] or family
end

-- an element's text icon (rules.toml [card] element_icon: a gaiji tag), nil = none declared
local function element_icon(element)
  local c = load().rules.card or {}
  local icons = type(c.element_icon) == "table" and c.element_icon or {}
  local tag = icons[element]
  return type(tag) == "string" and tag ~= "" and tag or nil
end

-- one effect (items.toml passive / sets.toml effects) as text; `short` = the set tiers' compact form (an element as
-- its icon)
local function effect_text(e, short)
  local tpl = (short and T("short_" .. tostring(e.kind))) or T("eff_" .. tostring(e.kind))
  if not tpl then return nil end
  local stats = {}
  for _, st in ipairs(type(e.stats) == "table" and e.stats or {}) do stats[#stats + 1] = T("stat_" .. st) or st end
  return fill(tpl, {
    v = signed(e.value),
    family = e.family and family_name(e.family) or "",
    move = e.move_kind and (T("move_" .. e.move_kind) or e.move_kind) or T("move_any") or "",
    element = e.element and ((short and element_icon(e.element)) or T("element_" .. e.element) or e.element) or "",
    when = e.when and (T("when_" .. e.when) or "") or "",
    event = e.event and (T("event_" .. e.event) or e.event) or "",
    score = e.score and (T("score_" .. e.score) or e.score) or "",
    effect = e.effect and (T("effect_" .. e.effect) or e.effect) or "",
    stats = table.concat(stats, " / "),
  })
end

local function set_of(d, id)
  for _, set in ipairs(d.sets) do
    if set.members[id] then return set end
  end
  return nil
end

-- the equip slot (1..4: boots, bracelet, pendant, special) of an item: its internal name's type part (eq_sh / eq_mi /
-- eq_ac / eq_sp, the game's item names), nil = unknown
local SLOT_OF_TYPE = { sh = 1, mi = 2, ac = 3, sp = 4 }
local function slot_of(d, id)
  local a = d.affinity[id]
  local kind = a and type(a.item) == "string" and string.match(a.item, "eq_(%a%a)") or nil
  return kind and SLOT_OF_TYPE[kind] or nil
end

-- the set an item counts for on a player (hdl) wearing it in its slot; nil = no player / no exclusive read
local function counted_set(d, id, hdl)
  if type(hdl) ~= "number" or hdl == 0 then return nil end
  local ok, a, b, c, e = pcall(VRFW.item.equipped, hdl)
  if not ok or a == nil then return nil end
  local worn = { a, b, c, e }
  local k = slot_of(d, id)
  if k then worn[k] = id end
  local counts, slots = resolve(worn)
  if not counts then return nil end
  local key = nil
  for i = 1, 4 do
    if worn[i] and worn[i] % TWO32 == id then key = slots[i] end
  end
  for _, set in ipairs(d.sets) do
    if set.key == key then return set, counts[key] end
  end
  return nil
end

-- a set's bonus tiers as { pieces, text } (stats at the item type's S, then the effects' compact form)
local function tiers_of(set)
  local okS, s = pcall(VRFW.item.equipment_scale)
  s = (okS and tonumber(s)) or 0
  local out = {}
  for _, tier in ipairs(set.bonus) do
    local parts = {}
    for stat, frac in pairs(tier.stats or {}) do
      if s > 0 then parts[#parts + 1] = (T("stat_" .. stat) or stat) .. " " .. signed(round(frac * s)) end
    end
    table.sort(parts)
    for _, e in ipairs(tier.effects or {}) do
      local t = effect_text(e, true)
      if t then parts[#parts + 1] = t end
    end
    if #parts > 0 then out[#out + 1] = { pieces = tier.pieces or 2, text = table.concat(parts, ", ") } end
  end
  return out
end

local function set_name(set)
  return T("set_" .. string.lower(tostring(set.name)), set.mod) or tostring(set.name)
end

-- one effect as a chip's part for the item card: a stat raise {stat, stat_name, value}, a move power {label,
-- element | family, value} or a text {text}
-- the icon a mod declares for an element ([[VRFW.ElementIcon]] Element / Atlas / Sprite in the image files rules.toml
-- [card] element_icon_files names; only the active mods' files answer): { atlas = crc32, sprite = crc32 }, nil = none
local EXT_ICONS = nil
local function ext_element_icon(element)
  if EXT_ICONS == nil then
    EXT_ICONS = {}
    local c = load().rules.card or {}
    for _, path in ipairs(type(c.element_icon_files) == "table" and c.element_icon_files or {}) do
      local ok, files = pcall(VRFW.files.declarations, path)
      for _, f in ipairs((ok and files) or {}) do
        local v = type(f.data) == "table" and f.data.VRFW or nil
        for _, d in ipairs((type(v) == "table" and type(v.ElementIcon) == "table") and v.ElementIcon or {}) do
          if type(d.Element) == "string" and type(d.Atlas) == "string" and type(d.Sprite) == "string"
              and EXT_ICONS[d.Element] == nil then
            EXT_ICONS[d.Element] = { atlas = id_of(d.Atlas), sprite = id_of(d.Sprite) }
          end
        end
      end
    end
  end
  return element and EXT_ICONS[element] or nil
end

local function chip_part(e, s)
  if e.stat ~= nil then
    return { stat = e.stat, stat_index = STAT_INDEX[e.stat], stat_name = T("stat_" .. e.stat) or e.stat,
      value = signed(e.value) }
  end
  local v = signed(e.value) .. " %"
  if e.kind == "element_power" and e.element then
    return { label = T("chip_move") or "", element = e.element, element_name = T("element_" .. e.element) or e.element,
      element_icon = ext_element_icon(e.element), value = v }
  end
  if e.kind == "family_power" and e.family then
    return { label = T("chip_move") or "", family = family_name(e.family), value = v }
  end
  return { text = effect_text(e, true) or effect_text(e) or "" }
end

-- the wearer's card (saved character handle): its main position and element, nil = none
local function wearer(hdl)
  if type(hdl) ~= "number" or hdl == 0 then return nil end
  local okR, rec = pcall(VRFW.chara.record, hdl)
  if not okR or not rec or not rec.param then return nil end
  local okC, card = pcall(VRFW.chara.card, rec.param)
  return okC and card or nil
end

-- the «Efecto» page (item, shown player): { lines = { ... } (a text form), passive = part | nil, affinity = {
-- position, element, stats = { the raised stats, largest first }, text, pos_ok, el_ok } | nil, tiers = { { pieces,
-- reward = part } } }
function BetterEquipment.ItemPage(item, hdl)
  local d = load()
  local id = (tonumber(item) or 0) % TWO32
  local out = { lines = {}, tiers = {},
    -- the card pages' names (the item card's page prompt)
    page_names = { stats = T("page_name_stats"), effect = T("page_name_effect"), set = T("page_name_set") } }
  if id == 0 then return out end
  local lines = out.lines
  local it = d.items[id]
  if it and type(it.passive) == "table" then
    local p = effect_text(it.passive)
    if p then lines[#lines + 1] = p end
    out.passive = chip_part(it.passive)
  end
  local set = counted_set(d, id, hdl) or set_of(d, id)
  if set then
    local okS, s = pcall(VRFW.item.equipment_scale)
    s = (okS and tonumber(s)) or 0
    local tiers = {}
    for i, t in ipairs(tiers_of(set)) do
      tiers[#tiers + 1] = fill(T(i == 1 and "page_tier_first" or "page_tier") or "{n}: {text}", { n = t.pieces, text = t.text })
    end
    if #tiers > 0 then lines[#lines + 1] = table.concat(tiers, " · ") end
    for _, tier in ipairs(set.bonus) do
      -- the tier's reward: its first stat raise (largest), else its first effect
      local best, bv = nil, 0
      for stat, frac in pairs(tier.stats or {}) do
        local v = s > 0 and round(frac * s) or 0
        if v > bv then best, bv = stat, v end
      end
      local reward = nil
      if best then
        reward = chip_part({ stat = best, value = bv })
      elseif type(tier.effects) == "table" and tier.effects[1] then
        reward = chip_part(tier.effects[1])
      end
      if reward then out.tiers[#out.tiers + 1] = { pieces = tier.pieces or 2, reward = reward } end
    end
  end
  local aff = d.affinity[id]
  if aff and (aff.position or aff.element) then
    local r = d.rules.affinity or {}
    local one, both = round((r.one or 0) * 100), round((r.both or 0) * 100)
    local stats = {}
    for stat, frac in pairs(aff.raises or {}) do stats[#stats + 1] = { stat, frac } end
    table.sort(stats, function(x, y) return x[2] > y[2] end)
    local keys = {}
    for i, st in ipairs(stats) do keys[i] = st[1] end
    local card = wearer(hdl)
    local pos_ok = card ~= nil and aff.position ~= nil and POSITION[aff.position] == card.position
    local el_ok = card ~= nil and aff.element ~= nil and (ELEMENT[aff.element] == card.element or aff.element == card.element)
    -- the stat bonus the shown player gets from it (stat index + 1 -> points), as the match table computes it
    local okS2, s2 = pcall(VRFW.item.equipment_scale)
    s2 = (okS2 and tonumber(s2)) or 0
    local rate = card and affinity_rate(aff, card, d.rules) or 0
    local cap = ((d.rules.scale or {}).cap or 1) * s2
    local bonus = {}
    for stat, frac in pairs(aff.raises or {}) do
      local k = STAT_INDEX[stat]
      if k and rate > 0 and s2 > 0 then
        local base = round(frac * s2)
        bonus[k + 1] = math.min(round(base * rate), math.max(0, cap - base))
      end
    end
    out.affinity = {
      position = aff.position, element = aff.element, element_icon = ext_element_icon(aff.element), stats = keys,
      pos_ok = pos_ok, el_ok = el_ok, bonus = bonus,
      rate = (pos_ok and el_ok) and "both" or (pos_ok and "one" or "none"),
      -- no player (inventory, shop): both rates; else the shown player's rate first
      text = fill(T("chip_affinity") or "x {one} % / {both} %",
        { one = card == nil and one or ((pos_ok and el_ok) and both or (pos_ok and one or 0)), both = both }),
    }
    local both_known = aff.position and aff.element
    lines[#lines + 1] = fill(T(both_known and "page_affinity_value_both" or "page_affinity_value") or "+{one} %",
      { one = one, both = both })
  end
  return out
end

function BetterEquipment.ItemSet(item, hdl)
  local d = load()
  local id = (tonumber(item) or 0) % TWO32
  if id == 0 then return nil end
  local all = {}
  for _, set in ipairs(d.sets) do
    if set.members[id] then all[#all + 1] = set end
  end
  if #all == 0 then return nil end
  local set, worn = counted_set(d, id, tonumber(hdl))
  set = set or all[1]
  local members = {}
  for i, m in ipairs(set.list or {}) do members[i] = m end
  local others = {}
  for _, o in ipairs(all) do
    if o ~= set then others[#others + 1] = set_name(o) end
  end
  local also = #others > 0 and fill(T("page3_also") or "also: {sets}", { sets = table.concat(others, ", ") }) or nil
  return { name = set_name(set), count = #members, members = members, tiers = tiers_of(set), worn = worn, also = also,
    title = T("page3_title") or "{set}: {worn}/{count}", title_any = T("page3_title_any") or "{set} ({count})",
    tiers_label = T("page3_tiers") or "{tiers}" }
end

-- [[VRFW.CommandFilter]] phase "after" of the equip / remove commands: the game's results unchanged
function BetterEquipment.AfterEquip(_args, _results)
  local ok, e = pcall(refresh, "equip change")
  if not ok then warn("equip change: " .. tostring(e)) end
  return nil
end

VRFW.on("slot_load", function()
  local ok, e = pcall(refresh, "save load")
  if not ok then warn("save load: " .. tostring(e)) end
end)

VRFW.on("match_start", function()
  local ok, e = pcall(refresh, "match start")
  if not ok then warn("match start: " .. tostring(e)) end
end)

VRFW.on("game_reset", function()
  pcall(VRFW.native.table_clear, T_ADD)
end)
