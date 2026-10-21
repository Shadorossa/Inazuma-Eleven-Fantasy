-- InaRogue › INAROGUE: the album's «Objetos» and «Equipos» sections (docs/game/modes/inarogue.md §14.6). Every rogue
-- item of content/rogue/items.toml and every fixed rival team INAROGUE can field (the evt_rl_* clones, the own
-- non-random rows, the special bosses of content/rogue/bosses.toml; the random-team slots have no fixed team) laid out
-- as album pages with the same book engine as the player cards (lib/rogue/album.lua).
--
-- Discovery store: ONE global blob rogue_collections.json (every save slot sees the same album):
--   items[key] = { first = yyyymmdd, count = times obtained }
--   teams[lower-case rival name] = { first = yyyymmdd, met = matches reserved, beaten = wins, best_phase }
-- An item is recorded when it enters the run's inventory (any path: the run listener) and counted by
-- CMND_INAROGUE_RL_ITEM_ADD; a team when a match against it is reserved (met) and won (beaten). Rivals beaten before
-- this store existed come from the unlocks store (rogue_unlocks.json `beaten`). [rogue.album] unlock_all = debug.
--
-- | CMND_INAROGUE_RL_COLLECTION op, kind (1 items / 2 teams), … | Returns |
-- |---|---|
-- | 0, kind | pages, sections, count, found (the screen opens: fresh store view) |
-- | 1, kind, page | 7 rows x (rowKind 0 empty / 1 header / 2 entries, section, first, n, false) |
-- | 2, kind, section | ok, count, found, page, titleKey, title (fallback), iconSprite ("" = the crest) |
-- | 3, 1, i | ok, found, number, key, tier 1-5 (the sticker look: the top rarity = 5), maxLevel, price, archetype1 icon, archetype2 icon, archetype1 titleKey, archetype1 title, icon (texture of icon_item10.g4tx), count, first, rarity titleKey, rarity key |
-- | 3, 2, i | ok, found, number, name, emblem (crc32 of emNNNNNN, 0 = none), kind 1 5v5 / 2 11v11 / 3 special boss, tier 1-5, met, beaten, bestPhase, first |
-- | 4, kind, i, dir | the list position of the next / previous section |
-- | 5, kind, i | page, row, col of list position i (-1 x3 = none) |

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local J = require "lib/rogue/json"
local album = require "lib/rogue/album"
local Items = require "lib/rogue/items"
local pool = require "lib/rogue/pool"
local bosses = require "lib/rogue/bosses"
local X = require "lib/rogue/unlocks"
local info, _, err = U.logger("rogue album")

local S = {}

S.KIND_ITEMS, S.KIND_TEAMS = 1, 2
S.TEAM_SMALL, S.TEAM_FULL, S.TEAM_SPECIAL = 1, 2, 3
local BLOB, SCHEMA, VERSION = "rogue_collections.json", "InaRogue.rogue_collections/1", 1
local ARCHETYPE_DECL = "content/archetypes/inarogue.toml"
local NO_ARCHETYPE_KEY, NO_ARCHETYPE = "evt_album_no_archetype", "Sin arquetipo"
local TEAM_KIND_KEYS = { "evt_album_team_kind_1", "evt_album_team_kind_2", "evt_album_team_kind_3" }
local TEAM_KIND_NAMES = { "Pachangas", "Partidos", "Jefes especiales" }

local function unlock_all() return Core.cfg().album.unlock_all == true end

-- ---------------------------------------------------------------------------------------- the store

local store = nil

local function new_store() return { items = {}, teams = {} } end

local function from_json(j)
  if type(j) ~= "table" then return nil, "not an object" end
  if type(j.schema) == "string" and j.schema ~= SCHEMA then
    return nil, "schema `" .. j.schema .. "` (expected `" .. SCHEMA .. "`)"
  end
  local s = new_store()
  for k, v in pairs(type(U.val(j.items)) == "table" and j.items or {}) do
    if type(v) == "table" then s.items[tostring(k)] = { first = U.int(v.first, 0), count = U.int(v.count, 0) } end
  end
  for k, v in pairs(type(U.val(j.teams)) == "table" and j.teams or {}) do
    if type(v) == "table" then
      s.teams[tostring(k)] = { first = U.int(v.first, 0), met = U.int(v.met, 0), beaten = U.int(v.beaten, 0),
        best_phase = U.int(v.best_phase, 0) }
    end
  end
  return s
end

local function to_json(s)
  local items, teams = {}, {}
  for _, k in ipairs(J.sorted_keys(s.items)) do
    local v = s.items[k]
    items[#items + 1] = { k, J.obj({ { "first", v.first }, { "count", v.count } }) }
  end
  for _, k in ipairs(J.sorted_keys(s.teams)) do
    local v = s.teams[k]
    teams[#teams + 1] = { k, J.obj({ { "first", v.first }, { "met", v.met }, { "beaten", v.beaten },
      { "best_phase", v.best_phase } }) }
  end
  return J.pretty(J.obj({ { "schema", SCHEMA }, { "version", VERSION }, { "items", J.obj(items) },
    { "teams", J.obj(teams) } }))
end

-- the global store (loaded once; an unreadable blob is set aside and a new store starts)
local function the_store()
  if store then return store end
  local text, why = U.blob_read(BLOB, "global")
  if text == false then
    err(BLOB .. " unreadable (" .. tostring(why) .. "): a new store for now")
    store = new_store()
    return store
  end
  local s = nil
  if text then
    local j, e = U.json(text)
    if j then s, e = from_json(j) end
    if not s then
      err(string.format("%s: %s; %s; new store", BLOB, tostring(e), tostring(U.blob_aside(BLOB, "global"))))
    end
  end
  store = s or new_store()
  return store
end

local function save(why)
  local ok, where = U.blob_write(BLOB, to_json(the_store()), "global")
  if not ok then err("cannot write " .. BLOB .. " (" .. why .. "): " .. tostring(where)) end
end

-- ---------------------------------------------------------------------------------------- recording

-- an item entered the run's inventory: `counted` = one more time obtained (ITEM_ADD), else only discovered
function S.item_got(key, counted)
  if type(key) ~= "string" or key == "" or not U.rogue_active() then return end
  local s = the_store()
  local e = s.items[key]
  if e and not counted then return end
  if not e then
    e = { first = U.today(), count = 0 }
    s.items[key] = e
    info("item discovered: " .. key)
  end
  if counted then e.count = e.count + 1 end
  save("item " .. key)
end

local team_list

-- the store entry of catalogue team `rival` (created when first met); nil for a name not in the album (random teams)
local function team_entry(rival)
  local name = U.lower(U.trim(rival))
  if name == "" or not team_list().by_name[name] then return nil end
  local s = the_store()
  local e = s.teams[name]
  if not e then
    e = { first = U.today(), met = 0, beaten = 0, best_phase = 0 }
    s.teams[name] = e
    info("team discovered: " .. name)
  end
  return e
end

-- a match against `row` was reserved (the team is met)
function S.team_met(row)
  if type(row) ~= "table" or not U.rogue_active() then return end
  local e = team_entry(row.rival)
  if not e then return end
  e.met = e.met + 1
  save("team met")
end

-- a match against the rival `rival` was won in phase `phase`
function S.team_beaten(rival, phase)
  if not U.rogue_active() then return end
  local e = team_entry(rival)
  if not e then return end
  e.beaten = e.beaten + 1
  e.best_phase = math.max(e.best_phase, U.int(phase, 0))
  save("team beaten")
end

-- every item of a loaded / saved run is discovered (start items of a coach, loot, shop)
Core.on_run(function(r)
  if not r or type(r.items) ~= "table" then return end
  for _, o in ipairs(r.items) do
    if type(o) == "table" and not the_store().items[o.key] then S.item_got(o.key, false) end
  end
end)

-- ---------------------------------------------------------------------------------------- catalogues

local arch_decl = nil -- [archetype number] = { label, icon }

local function archetype_decl(n)
  if not arch_decl then
    arch_decl = {}
    local ok, t = pcall(VRFW.files.toml, ARCHETYPE_DECL)
    local list = ok and type(t) == "table" and type(t.VRFW) == "table" and t.VRFW.Archetype or nil
    for _, a in ipairs(type(list) == "table" and list or {}) do
      local v = U.int(a.pick_value, 0)
      if v > 0 then
        arch_decl[v] = { label = type(a.label) == "string" and a.label or "", icon = type(a.icon) == "string" and a.icon or "",
          name = type(a.name) == "string" and a.name or "" }
      end
    end
  end
  return arch_decl[n]
end

-- the sticker look (rarity card base 1-5) of rarity number r: the top rarity is 5, the others their number
local function item_tier(r)
  local n = #Items.catalogue().rarities
  if r >= n then return 5 end
  return U.clamp(r, 1, 4)
end

local items_cat = nil -- { list = { def } }

-- the items in album order: by first archetype (archetype order; none last), then rarity, then catalogue order
local function item_list()
  if items_cat then return items_cat end
  local list = {}
  for i, d in ipairs(Items.catalogue().list) do list[#list + 1] = { def = d, order = i } end
  local function arch(d) return d.archetypes[1] or 1000 end
  table.sort(list, function(a, b)
    if arch(a.def) ~= arch(b.def) then return arch(a.def) < arch(b.def) end
    if a.def.rarity ~= b.def.rarity then return a.def.rarity < b.def.rarity end
    return a.order < b.order
  end)
  items_cat = { list = list }
  return items_cat
end

local teams_cat = nil -- { list = { { key, rival, emblem, kind, tier } }, by_name = { [key] = entry } }

-- the fixed rival teams by name: the clones, the own non-random rows, the special bosses; ordered by kind, tier, name
team_list = function()
  if teams_cat then return teams_cat end
  local by_name, list = {}, {}
  local function add(row, kind)
    if type(row) ~= "table" or type(row.rival) ~= "string" or pool.is_random(row) then return end
    local key = U.lower(U.trim(row.rival))
    if key == "" then return end
    local t = by_name[key]
    if not t then
      t = { key = key, rival = U.trim(row.rival), emblem = 0, kind = kind, tier = 5 }
      by_name[key] = t
      list[#list + 1] = t
    end
    if t.emblem == 0 and (row.emblem or 0) ~= 0 then t.emblem = row.emblem % U.TWO32 end
    t.kind = math.max(t.kind, kind)
    t.tier = math.min(t.tier, kind == S.TEAM_SPECIAL and 5 or U.clamp(row.tier or 1, 1, 5))
  end
  for _, r in ipairs(pool.clones()) do add(r, r.kind == pool.KIND_FULL and S.TEAM_FULL or S.TEAM_SMALL) end
  for _, r in ipairs(pool.own()) do add(r, r.kind == pool.KIND_FULL and S.TEAM_FULL or S.TEAM_SMALL) end
  bosses.catalogue(Core.cfg().bosses)
  for _, r in ipairs(bosses.rows()) do add(r, S.TEAM_SPECIAL) end
  table.sort(list, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    if a.tier ~= b.tier then return a.tier < b.tier end
    return a.key < b.key
  end)
  teams_cat = { list = list, by_name = by_name }
  info(string.format("album teams: %d fixed rival teams", #list))
  return teams_cat
end

-- the store entry of team `t`: the collections store, else a rival of the unlocks store's lifetime `beaten` set
local function team_record(t)
  local e = the_store().teams[t.key]
  if e then return e end
  if X.store().beaten[t.key] then return { first = 0, met = 1, beaten = 1, best_phase = 0 } end
  return nil
end

-- ---------------------------------------------------------------------------------------- views

local views = {} -- kind -> { list (catalogue entries), found (entry -> bool), book }

local function section_key(kind, e)
  if kind == S.KIND_ITEMS then return e.def.archetypes[1] or 0 end
  return e.kind
end

local function view(kind)
  if views[kind] then return views[kind] end
  local list = kind == S.KIND_ITEMS and item_list().list or team_list().list
  local all = unlock_all()
  local found, n = {}, 0
  for i, e in ipairs(list) do
    local got
    if kind == S.KIND_ITEMS then got = the_store().items[e.def.key] ~= nil else got = team_record(e) ~= nil end
    found[i] = all or got
    if found[i] then n = n + 1 end
  end
  -- the book lays out list positions (0-based); key(position) = the section of that entry
  local positions = {}
  for i = 1, #list do positions[i] = i - 1 end
  local book = album.book(positions, function(p) return section_key(kind, list[p + 1]) end)
  views[kind] = { list = list, found = found, n_found = n, book = book }
  return views[kind]
end

local function kind_of(a)
  local k = U.int(a, 0)
  if k == S.KIND_ITEMS or k == S.KIND_TEAMS then return k end
  return nil
end

function S.Collection(op_arg, kind_arg, a2, a3)
  local op, kind = U.int(op_arg, -1), kind_of(kind_arg)
  if not kind then return false end
  if op == 0 then
    views[kind] = nil
    local v = view(kind)
    return #v.book.pages, #v.book.sections, #v.list, v.n_found
  end
  local v = view(kind)
  if op == 1 then
    local page = U.int(a2, -1)
    local rows = page >= 0 and v.book.pages[page + 1] or nil
    local out = {}
    for k = 1, album.BOOK_ROWS do
      local row = rows and rows[k]
      local rk, sec, first, n = 0, -1, 0, 0
      if row and row.kind == 1 then
        rk, sec = 1, row.section
      elseif row and row.kind == 2 then
        rk, sec, first, n = 2, row.section, row.first, row.n
      end
      out[#out + 1] = rk
      out[#out + 1] = sec
      out[#out + 1] = first
      out[#out + 1] = n
      out[#out + 1] = false
    end
    return table.unpack(out, 1, #out)
  elseif op == 2 then
    local s = U.int(a2, -1)
    local sec = s >= 0 and v.book.sections[s + 1] or nil
    if not sec or sec.count == 0 then return false end
    local found = 0
    for p = sec.first, sec.first + sec.count - 1 do
      if v.found[p + 1] then found = found + 1 end
    end
    local key_text, title, icon = NO_ARCHETYPE_KEY, NO_ARCHETYPE, ""
    if kind == S.KIND_ITEMS then
      local a = sec.key ~= 0 and archetype_decl(sec.key) or nil
      if a then key_text, title, icon = a.label, a.name, a.icon end
    else
      key_text, title = TEAM_KIND_KEYS[sec.key] or "", TEAM_KIND_NAMES[sec.key] or ""
    end
    return true, sec.count, found, sec.page, key_text, title, icon
  elseif op == 3 then
    local i = U.int(a2, -1)
    local e = i >= 0 and v.list[i + 1] or nil
    if not e then return false end
    local found = v.found[i + 1] == true
    if kind == S.KIND_ITEMS then
      local d = e.def
      local rec = the_store().items[d.key] or { first = 0, count = 0 }
      local a1 = archetype_decl(d.archetypes[1] or 0)
      local a2d = archetype_decl(d.archetypes[2] or 0)
      return true, found, i + 1, d.key, item_tier(d.rarity), d.max_level, d.price, a1 and a1.icon or "",
        a2d and a2d.icon or "", a1 and a1.label or "", a1 and a1.name or "", d.icon ~= "" and d.icon or "", rec.count,
        rec.first, Items.rarity_text_key(d.rarity_key), d.rarity_key
    end
    local rec = team_record(e) or { first = 0, met = 0, beaten = 0, best_phase = 0 }
    return true, found, i + 1, e.rival, e.emblem, e.kind, e.tier, rec.met, rec.beaten, rec.best_phase, rec.first
  elseif op == 4 then
    local positions = {}
    for k = 1, #v.list do positions[k] = k - 1 end
    local i, dir = math.max(U.int(a2, 0), 0), U.int(a3, 1)
    return album.group_jump(positions, i, dir, function(p) return section_key(kind, v.list[p + 1]) end)
  elseif op == 5 then
    local i = U.int(a2, -1)
    if i < 0 then return -1, -1, -1 end
    local p, r, c = album.locate(v.book, i)
    if not p then return -1, -1, -1 end
    return p, r, c
  end
  return false
end

return S
