-- Contact maps (schema VRFW.contact_map/1): serves every active mod's content\contact_maps\*.toml to the screen vrfw_contact_map_menu.
-- Declarations: [[VRFW.ContactSet]], [[VRFW.ContactMap]] with its Zone / Node / Item entries. Recruiting, prices and the per-save record are the screen's.
--   CMND_VRFW_CONTACT_SETS()          -> { {key, crc, title, maps}, ... }  every declared set
--   CMND_VRFW_CONTACT_MAPS(set, lang) -> { key, title, rc, ic, rct, ict, maps = { {key, title, kind, tex, sprite, players, excl}, ... }, reveal }  (set = crc32 of "<mod>.<name>" or the text)
--   CMND_VRFW_CONTACT_MAP(map, lang)  -> { key, kind, title, tex, sprite, strict, zones = {...}, items = {...}, nodes = { {kind, zone, card, face, level, price, name, x, y, links, reqs, story, notes} } }  (map = key text or crc32)
-- Titles are sent as crc32 of their menu_text row id; character names are read from the game's chara_text in the asked language.

ContactMap = ContactMap or {}

local function warn(...) VRFW.warn("contact_map:", ...) end
local function info(...) VRFW.log("contact_map:", ...) end

-- Debug view-everything mode (config.toml [debug] reveal_all): the screen draws every tile open; signing keeps its real rules and writes nothing.
-- The same key is the game_state vrfw.debug.reveal_all.
local REVEAL_ALL = VRFW.files.config("debug.reveal_all") == true
if REVEAL_ALL then
  warn("[debug] reveal_all is ON: view-everything mode (contact maps, office pages) - turn it off for players")
end

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local function crc(s) return u32(VRFW.ui.crc32(s)) end

-- "0x..." / decimal text / a number -> the number; nil otherwise
local function id_of(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % 4294967296 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % 4294967296 end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local SETS, SET_BY, MAPS, MAP_BY = nil, {}, {}, {}
local KINDS = { zones = true, network = true, list = true }
local NODE_KINDS = { player = true, gate = true, open = true, start = true }

local ELEMENTS = { wind = 1, forest = 2, fire = 3, mountain = 4, void = 5 }
local POSITIONS = { GK = 1, FW = 2, MF = 3, DF = 4 }

local function req_list(mod, where, list)
  local out = {}
  for k, r in ipairs(type(list) == "table" and list or {}) do
    if tonumber(r.TeamLevel) then
      out[#out + 1] = { kind = "team_level", count = math.floor(tonumber(r.TeamLevel)) }
    elseif r.Element ~= nil then
      local e = ELEMENTS[tostring(r.Element)]
      if e then
        out[#out + 1] = { kind = "element", element = e, count = math.max(1, tonumber(r.Count) or 1) }
      else
        warn(where .. ": requirement " .. k .. ": Element " .. tostring(r.Element) .. " (wind, forest, fire, mountain, void)")
      end
    elseif r.Position ~= nil then
      local p = POSITIONS[tostring(r.Position)]
      if p then
        out[#out + 1] = { kind = "position", position = p, count = math.max(1, tonumber(r.Count) or 1) }
      else
        warn(where .. ": requirement " .. k .. ": Position " .. tostring(r.Position) .. " (GK, FW, MF, DF)")
      end
    elseif tonumber(r.Wins) then
      out[#out + 1] = { kind = "wins", count = math.floor(tonumber(r.Wins)) }
    elseif tonumber(r.Goals) then
      out[#out + 1] = { kind = "goals", count = math.floor(tonumber(r.Goals)) }
    elseif type(r.Players) == "table" then
      local ids = {}
      for _, c in ipairs(r.Players) do
        local id = id_of(c)
        if id then ids[#ids + 1] = id end
      end
      if #ids > 0 then out[#out + 1] = { kind = "player", ids = ids, count = math.max(1, tonumber(r.Count) or 1) } end
    elseif r.Item ~= nil and id_of(r.Item) then
      out[#out + 1] = { kind = "item", id = id_of(r.Item), count = math.max(1, tonumber(r.Count) or 1) }
    else
      warn(where .. ": requirement " .. k .. ": none of Players, Item, TeamLevel, Element, Position, Wins, Goals (left out)")
    end
  end
  return out
end

-- ---------------------------------------------------------------------------------------------- own faces
-- A player with no face icon of his own would be drawn with the default face, so such players are left out of every map.
-- Derived from the data: the node's `Face`, else the internal name (chara_base `name`) of its `Base` / its card's base. Cannot tell: kept.
local FACE_FILE = "data/dx11/menu/200_icon/10_icon_chr/face/%s_l.g4tx"
local FACES = { has = {} }

-- The framework's shared character index (VRFW.chara): internal name and name text per chara_base id, chara_base id per card; asked per id and cached here.

-- Key of a game table as the game loads it: `<stem>.cfg.bin` when listed, else the newest `<stem>_<version>.cfg.bin`.
local function table_key(stem)
  local plain = stem .. ".cfg.bin"
  local ok, k = pcall(VRFW.table.keys, plain)
  if ok and type(k) == "table" and #k > 0 then return plain end
  return stem .. "_*.cfg.bin"
end

-- A table whose missing keys are asked once from `f` (nil answers are asked again)
local function lazy(f)
  return setmetatable({}, { __index = function(t, k)
    local v = f(k)
    if v ~= nil then rawset(t, k, v) end
    return v
  end })
end

local function character(b)
  local ok, c = pcall(VRFW.chara.character, b)
  if ok and type(c) == "table" then return c end
  return nil
end

local CHARA = nil
local function chara_index()
  if CHARA ~= nil then return CHARA end
  local t0 = VRFW.now()
  local ok, e = pcall(VRFW.chara.card, 0)     -- builds the shared index now (once per session for every script)
  if not ok then warn("character index not readable: " .. tostring(e)) end
  CHARA = {
    name_of = lazy(function(b)
      local c = character(b)
      return c and c.name ~= "" and c.name or nil
    end),
    text_of = lazy(function(b)
      local c = character(b)
      return c and u32(c.name_text) or nil
    end),
    base_of = lazy(function(card)
      local okb, b = pcall(VRFW.chara.base_of, card)
      return okb and type(b) == "number" and u32(b) or nil
    end),
  }
  info(string.format("character index ready in %d ms (the framework's, shared)", math.floor(VRFW.now() - t0)))
  return CHARA
end

-- true = an own face icon, false = none (the engine's default face), nil = cannot tell
local function own_face(face, base, card)
  if type(VRFW.files) ~= "table" or type(VRFW.files.game_file) ~= "function" then return nil end
  local key = face ~= "" and face or nil
  if key == nil then
    local C = chara_index()
    local b = base ~= 0 and base or C.base_of[card]
    key = b and C.name_of[b] or nil
    if key == nil then return nil end
  end
  local has = FACES.has[key]
  if has == nil then
    local ok, k, why = pcall(VRFW.files.game_file, string.format(FACE_FILE, key))
    if not ok or (k == nil and why == "no host") then return nil end
    has = k ~= nil
    FACES.has[key] = has
  end
  return has
end

-- ---------------------------------------------------------------------------------------------- excluded cards
-- [[VRFW.ContactSet]] `Exclude = [ ... ]`: cards a set keeps off all its maps, derived from game data. Each entry is:
--   "<mod>.<name>"                        a declared [[VRFW.CardSet]]
--   { aura_variant = { aura_type = 2 } }  a card-set rule (any key of the card-set vocabulary)
--   { AuraVariants = { AuraType = 2 } }   legacy spelling of aura_variant (0 keshin, 1 armed, 2 miximax, ...)
--   { IdealMiximaxPartners = { AuraType = n } }  legacy spelling of { ideal_miximax_partner = { aura_type = n } }; { IdealMiximaxPartners = true } = { ideal_miximax_partner = true }.
-- On every map of the set: such player nodes are removed (networks relink the tiles around them), requirements drop such cards, empty gates and zones go.
-- The cards stay in the save; the screen skips the map's `excl` when counting.

-- One Exclude entry as a card-set rule (a set name stays a text) and its log text; nil when not one
local function exclude_rule(r)
  if type(r) == "string" and r ~= "" then return r, "set " .. r end
  if type(r) ~= "table" then return nil end
  if type(r.AuraVariants) == "table" then
    local t = r.AuraVariants.AuraType
    local shown = type(t) == "table" and table.concat(t, "/") or tostring(t)
    return { aura_variant = { aura_type = t } }, "aura variants of type " .. shown
  end
  if r.IdealMiximaxPartners == true or type(r.IdealMiximaxPartners) == "table" then
    local t = type(r.IdealMiximaxPartners) == "table" and tonumber(r.IdealMiximaxPartners.AuraType) or nil
    return { ideal_miximax_partner = t and { aura_type = t } or true },
      "ideal miximax partners of " .. (t and ("type " .. t) or "any type")
  end
  if next(r) ~= nil then return r, "rule" end
  return nil
end

-- Card set of a set's Exclude entries: card -> true, and the entries as text (log)
local function exclusion(s)
  local rules, what = {}, {}
  for k, r in ipairs(s.exclude) do
    local rule, text = exclude_rule(r)
    if rule == nil then
      warn(string.format("%s: [[VRFW.ContactSet]] %s: Exclude #%d: not a card set name or a rule - left out", s.where,
        s.key, k))
    else
      rules[#rules + 1] = rule
      what[#what + 1] = text
    end
  end
  local ex = {}
  if #rules > 0 then
    local ok, ids = pcall(VRFW.chara.select, { include = rules })
    if ok and type(ids) == "table" then
      for _, c in ipairs(ids) do ex[u32(c)] = true end
    else
      warn(string.format("%s: [[VRFW.ContactSet]] %s: Exclude not evaluated (%s): nothing excluded", s.where, s.key,
        tostring(ids)))
    end
  end
  return ex, table.concat(what, ", ")
end

-- Take the excluded cards off one map; returns the cards taken off (sorted)
local function exclude_map(M, ex)
  local gone, taken, took = {}, {}, {}
  for i, n in ipairs(M.nodes) do
    local had = #n.reqs
    local reqs = {}
    for _, r in ipairs(n.reqs) do
      if r.kind == "player" then
        local ids = {}
        for _, id in ipairs(r.ids) do
          if not ex[id] then ids[#ids + 1] = id end
        end
        if #ids > 0 then
          r.ids, r.count = ids, math.min(r.count, #ids)
          reqs[#reqs + 1] = r
        end
      else
        reqs[#reqs + 1] = r
      end
    end
    n.reqs = reqs
    if (n.kind == "player" or n.kind == "hidden") and ex[n.card] then
      gone[i] = true
      if not took[n.card] then
        took[n.card] = true
        taken[#taken + 1] = n.card
      end
    elseif n.kind == "gate" and had > 0 and #reqs == 0 then
      gone[i] = true                    -- a gate for an excluded player only
    end
  end
  local list = taken
  table.sort(list)
  if next(gone) == nil then return list end
  -- a network: each group of linked excluded tiles is replaced by links between all tiles around it
  local extra = {}
  if M.kind == "network" then
    local nb = {}
    for i, n in ipairs(M.nodes) do
      for _, l in ipairs(n.links) do
        if M.nodes[l] ~= nil and l ~= i then
          nb[i] = nb[i] or {}
          nb[i][l] = true
          nb[l] = nb[l] or {}
          nb[l][i] = true
        end
      end
    end
    local seen = {}
    for i in pairs(gone) do
      if not seen[i] then
        local stack, edge = { i }, {}
        seen[i] = true
        while #stack > 0 do
          local x = table.remove(stack)
          for y in pairs(nb[x] or {}) do
            if gone[y] then
              if not seen[y] then
                seen[y] = true
                stack[#stack + 1] = y
              end
            else
              edge[y] = true
            end
          end
        end
        local e = {}
        for y in pairs(edge) do e[#e + 1] = y end
        for a = 1, #e do
          for b = 1, #e do
            if a ~= b then
              extra[e[a]] = extra[e[a]] or {}
              extra[e[a]][e[b]] = true
            end
          end
        end
      end
    end
  end
  -- renumber kept nodes (links follow), recount players and zones
  local new, kept = {}, {}
  for i, n in ipairs(M.nodes) do
    if not gone[i] then
      kept[#kept + 1] = n
      new[i] = #kept
    end
  end
  for i, n in ipairs(M.nodes) do
    if not gone[i] then
      local links, has = {}, {}
      local function add(l)
        local j = new[l]
        if j ~= nil and j ~= new[i] and not has[j] then
          has[j] = true
          links[#links + 1] = j
        end
      end
      for _, l in ipairs(n.links) do add(l) end
      local more = {}
      for l in pairs(extra[i] or {}) do more[#more + 1] = l end
      table.sort(more)
      for _, l in ipairs(more) do add(l) end
      n.links = links
    end
  end
  M.nodes = kept
  local before = {}
  for z, zone in ipairs(M.zones) do
    before[z] = zone.count
    zone.count = 0
  end
  M.players = 0
  for _, n in ipairs(kept) do
    if n.kind == "player" then
      M.players = M.players + 1
      if n.zone > 0 then M.zones[n.zone].count = M.zones[n.zone].count + 1 end
    end
  end
  local zones, zix = {}, {}
  for z, zone in ipairs(M.zones) do
    if not (before[z] > 0 and zone.count == 0) then
      zones[#zones + 1] = zone
      zix[z] = #zones
    end
  end
  if #zones ~= #M.zones then
    for _, n in ipairs(kept) do n.zone = zix[n.zone] or 0 end
    M.zones, M.zone_ix = zones, {}
    for z, zone in ipairs(zones) do M.zone_ix[zone.name] = z end
  end
  return list
end

local function exclude_set(s)
  local ex, what = exclusion(s)
  if next(ex) == nil then return end
  local all, ids = {}, {}
  for _, M in ipairs(s.maps) do
    M.excl = exclude_map(M, ex)
    for _, c in ipairs(M.excl) do
      if not all[c] then
        all[c] = true
        ids[#ids + 1] = c
      end
    end
  end
  table.sort(ids)
  local hex = {}
  for k, c in ipairs(ids) do hex[k] = string.format("0x%08X", c) end
  info(string.format("set %s: %d cards excluded from its maps (%s): %s", s.key, #ids, what,
    #hex > 0 and table.concat(hex, ", ") or "none on the maps"))
end

-- ---------------------------------------------------------------------------------------------- names

-- Names are read per language for only the text ids the maps name (NEED, collected when declarations are read), at CMND_VRFW_CONTACT_MAPS, and kept per language.
local NAMES = { lang = nil, of = {} }   -- of[text id] = the name (furigana reduced)
local NEED = { ids = {}, list = {} }    -- the name text ids the maps use

-- `[kanji/kana]` furigana markup reduced to the kanji
local function strip(s)
  return (s:gsub("%[([^/%]]*)/[^%]]*%]", "%1"))
end

local function need_id(id)
  if id ~= nil and id ~= 0 and not NEED.ids[id] then
    NEED.ids[id] = true
    NEED.list[#NEED.list + 1] = id
  end
end

local function need_card(c)
  local b = CHARA.base_of[c]
  if b then need_id(CHARA.text_of[b]) end
end

-- Every name a map can serve (a node's base / card, a player requirement's first card)
local function need_texts()
  NEED = { ids = {}, list = {} }
  for _, M in ipairs(MAPS) do
    for _, n in ipairs(M.nodes) do
      if n.base ~= 0 then need_id(CHARA.text_of[n.base]) else need_card(n.card) end
      for _, r in ipairs(n.reqs) do
        if r.kind == "player" and r.ids[1] ~= nil then need_card(r.ids[1]) end
      end
    end
  end
end

local function lang_of(code)
  local c = type(code) == "number" and math.floor(code) or nil
  if c and c >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[c + 1] or nil
    if type(l) == "string" then return l end
  end
  return "en"
end

local function names_for(lang)
  chara_index()
  if NAMES.lang == lang then return end
  local t0 = VRFW.now()
  local ok, rows = pcall(VRFW.files.text_rows, "data/common/text/" .. lang .. "/chara_text.cfg.bin", NEED.list)
  if (not ok or type(rows) ~= "table") and lang ~= "en" then
    ok, rows = pcall(VRFW.files.text_rows, "data/common/text/en/chara_text.cfg.bin", NEED.list)
  end
  NAMES.of = {}
  if ok and type(rows) == "table" then
    for _, id in ipairs(NEED.list) do
      local r = rows[id]
      local s = r and r[0]
      if type(s) == "string" and s ~= "" then NAMES.of[id] = strip(s) end
    end
  end
  NAMES.lang = lang
  info(string.format("names (%s): %d text ids read in %d ms", lang, #NEED.list, math.floor(VRFW.now() - t0)))
end

-- A game text table's rows in a language (Notes), kept per table and language
local GAME_TEXT = {}
local function game_text(tbl, lang, id)
  local key = tbl .. "/" .. lang
  if GAME_TEXT[key] == nil then
    local ok, rows = pcall(VRFW.files.text_rows, "data/common/text/" .. lang .. "/" .. tbl .. ".cfg.bin")
    if (not ok or type(rows) ~= "table") and lang ~= "en" then
      ok, rows = pcall(VRFW.files.text_rows, "data/common/text/en/" .. tbl .. ".cfg.bin")
    end
    GAME_TEXT[key] = (ok and type(rows) == "table") and rows or {}
  end
  local r = GAME_TEXT[key][id]
  return r and r[0] or nil
end

-- A note's text: <VALUE1> = its value, the progress «<ACHIEVE_COUNT>/» left out, line breaks as spaces
local function note_text(nt, lang)
  local s = game_text(nt.table, lang, nt.id)
  if type(s) ~= "string" or s == "" then return nil end
  s = s:gsub("<ACHIEVE_COUNT>%s*/%s*", ""):gsub("<VALUE1>", tostring(math.floor(nt.value)))
  s = s:gsub("\\n", " "):gsub("\n", " ")
  return s
end

local function name_of_base(b)
  local id = CHARA.text_of[b]
  return id and NAMES.of[id] or ""
end

local function name_of_card(c)
  local b = CHARA.base_of[c]
  return b and name_of_base(b) or ""
end

local function load()
  if SETS ~= nil then return end
  local t0 = VRFW.now()
  SETS, SET_BY, MAPS, MAP_BY = {}, {}, {}, {}
  local ok, files = pcall(VRFW.files.declarations, "content/contact_maps")
  if not ok or type(files) ~= "table" then
    warn("declarations not readable: " .. tostring(files))
    return
  end
  local t_files = VRFW.now()
  chara_index()
  local t_index = VRFW.now()
  for _, f in ipairs(files) do
    local v = type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW or {}
    for _, s in ipairs(type(v.ContactSet) == "table" and v.ContactSet or {}) do
      if type(s.Name) == "string" then
        local key = f.mod .. "." .. s.Name
        local set = { key = key, crc = crc(key), title = crc(s.Title or key), rc = id_of(s.RecruitCurrency) or 0,
          ic = id_of(s.ItemCurrency) or 0, rct = crc(s.RecruitCurrencyTitle or ""), ict = crc(s.ItemCurrencyTitle or ""), maps = {},
          exclude = type(s.Exclude) == "table" and s.Exclude or nil, where = string.format("mods/%s/%s", f.mod, f.file) }
        if SET_BY[key] == nil then
          SETS[#SETS + 1] = set
          SET_BY[key], SET_BY[set.crc] = set, set
        end
      end
    end
    for mi, m in ipairs(type(v.ContactMap) == "table" and v.ContactMap or {}) do
      local where = string.format("mods/%s/%s: [[VRFW.ContactMap]] #%d", f.mod, f.file, mi)
      if type(m.Name) ~= "string" or not KINDS[m.Kind or ""] then
        warn(where .. ": Name / Kind (zones, network, list) missing (left out)")
      else
        local set = (m.Set or ""):find(".", 1, true) and m.Set or (f.mod .. "." .. tostring(m.Set))
        local key = f.mod .. "." .. m.Name
        local M = { key = key, crc = crc(key), set = set, order = tonumber(m.Order) or 0, kind = m.Kind,
          title = crc(m.Title or key), tex = m.Art or "", sprite = m.Sprite or "", strict = m.Strict ~= false,
          zones = {}, zone_ix = {}, nodes = {},
          items = {}, players = 0 }
        for _, z in ipairs(type(m.Zone) == "table" and m.Zone or {}) do
          local name = tostring(z.Name or "")
          local pos = type(z.Pos) == "table" and z.Pos or {}
          local size = type(z.ArtSize) == "table" and z.ArtSize or {}
          M.zones[#M.zones + 1] = { name = name, title = crc(z.Title or name), x = tonumber(pos[1]) or -1,
            y = tonumber(pos[2]) or -1, count = 0, tex = z.Art or "", sprite = z.Sprite or "",
            aw = tonumber(size[1]) or 0, ah = tonumber(size[2]) or 0 }
          M.zone_ix[name] = #M.zones
        end
        for ni, n in ipairs(type(m.Node) == "table" and m.Node or {}) do
          local kind = n.Kind or "player"
          if not NODE_KINDS[kind] then
            warn(where .. ": node " .. ni .. ": Kind " .. tostring(kind) .. " (made «open»)")
            kind = "open"
          end
          local pos = type(n.Pos) == "table" and n.Pos or {}
          local links = {}
          for _, l in ipairs(type(n.Links) == "table" and n.Links or {}) do
            if tonumber(l) then links[#links + 1] = math.floor(tonumber(l)) end
          end
          local node = { kind = kind, zone = M.zone_ix[tostring(n.Zone or "")] or 0, card = id_of(n.Card) or 0,
            base = id_of(n.Base) or 0, face = n.Face or "", level = tonumber(n.Level) or 1, price = tonumber(n.Price) or 0,
            x = tonumber(pos[1]) or 0, y = tonumber(pos[2]) or 0, links = links,
            reqs = req_list(f.mod, where .. ": node " .. ni, n.Requires), story = n.StoryOnly == true, notes = {} }
          -- StoryOnly: a player the game signs elsewhere is shown with his conditions (Notes) but never signed from the map
          for _, t in ipairs(type(n.Notes) == "table" and n.Notes or {}) do
            local id = id_of(t.Id)
            if id and type(t.Text) == "string" and t.Text:match("^[%w_]+$") then
              node.notes[#node.notes + 1] = { table = t.Text, id = id, value = tonumber(t.Value) or 0 }
            end
          end
          if kind == "player" and node.card == 0 then
            warn(where .. ": node " .. ni .. ": a player without Card (made «open»)")
            node.kind = "open"
          end
          if node.kind == "player" and own_face(node.face, node.base, node.card) == false then
            -- no face of his own: a network keeps the tile as a passage; elsewhere the node stays in the list as «hidden»
            node.kind = M.kind == "network" and "open" or "hidden"
            M.faceless = M.faceless or {}
            M.faceless[#M.faceless + 1] = node
          end
          M.nodes[#M.nodes + 1] = node
          if node.kind == "player" then
            M.players = M.players + 1
            if node.zone > 0 then M.zones[node.zone].count = M.zones[node.zone].count + 1 end
          end
        end
        if M.faceless ~= nil then
          if M.players == 0 then
            -- Every player of the map lacks a face: the face check is assumed wrong (for example, another game build); keep them.
            warn(key .. ": no player has a face icon (" .. FACE_FILE .. "): the face check is skipped for this map")
            for _, node in ipairs(M.faceless) do
              node.kind = "player"
              M.players = M.players + 1
              if node.zone > 0 then M.zones[node.zone].count = M.zones[node.zone].count + 1 end
            end
          else
            info(string.format("%s: %d players without a face of their own left out", key, #M.faceless))
          end
          M.faceless = nil
        end
        for _, it in ipairs(type(m.Item) == "table" and m.Item or {}) do
          local id = id_of(it.Item)
          if id then
            M.items[#M.items + 1] = { item = id, price = math.max(0, tonumber(it.Price) or 0), title = crc(it.Title or "") }
          end
        end
        if MAP_BY[key] == nil then
          MAPS[#MAPS + 1] = M
          MAP_BY[key], MAP_BY[M.crc] = M, M
        end
      end
    end
  end
  for _, M in ipairs(MAPS) do
    local s = SET_BY[M.set]
    if s then
      s.maps[#s.maps + 1] = M
    else
      warn(M.key .. ": set " .. M.set .. " is not declared (map not shown)")
    end
  end
  local t_maps = VRFW.now()
  for _, s in ipairs(SETS) do
    table.sort(s.maps, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.key < b.key end)
    if s.exclude ~= nil then exclude_set(s) end
    info(string.format("set %s: %d maps", s.key, #s.maps))
  end
  need_texts()
  local t1 = VRFW.now()
  info(string.format("declarations read in %d ms (kept for the session): files %d, character index %d, maps + faces %d, "
    .. "exclusions + name ids %d", math.floor(t1 - t0), math.floor(t_files - t0), math.floor(t_index - t_files),
    math.floor(t_maps - t_index), math.floor(t1 - t_maps)))
end

-- ---------------------------------------------------------------------------------------------- commands

local function find_set(v)
  load()
  if type(v) == "string" then return SET_BY[v] or SET_BY[crc(v)] end
  return SET_BY[u32(v)]
end

local function find_map(v)
  load()
  if type(v) == "string" then return MAP_BY[v] or MAP_BY[crc(v)] end
  return MAP_BY[u32(v)]
end

function ContactMap.Sets()
  load()
  local out = {}
  for _, s in ipairs(SETS) do
    out[#out + 1] = { key = s.key, crc = s.crc, title = s.title, maps = #s.maps }
  end
  return out
end

function ContactMap.Maps(set, code)
  local s = find_set(set)
  if s == nil then return nil end
  names_for(lang_of(code))           -- the screen opens: its maps' names, once per language (ContactMap.Map serves them)
  local out = { key = s.key, title = s.title, rc = s.rc, ic = s.ic, rct = s.rct, ict = s.ict, maps = {}, reveal = REVEAL_ALL }
  for _, M in ipairs(s.maps) do
    out.maps[#out.maps + 1] = { key = M.key, title = M.title, kind = M.kind, tex = M.tex, sprite = M.sprite, players = M.players,
      excl = M.excl or {} }
  end
  return out
end

function ContactMap.Map(map, code)
  local M = find_map(map)
  if M == nil then return nil end
  names_for(lang_of(code))
  local out = { key = M.key, kind = M.kind, title = M.title, tex = M.tex, sprite = M.sprite, strict = M.strict, zones = {},
    items = {}, nodes = {} }
  local s = SET_BY[M.set] or {}
  local item_title = {}
  for _, it in ipairs(M.items) do item_title[it.item] = it.title end
  if s.ic then item_title[s.ic] = item_title[s.ic] or s.ict end
  if s.rc then item_title[s.rc] = item_title[s.rc] or s.rct end
  for i, z in ipairs(M.zones) do
    out.zones[i] = { name = z.name, title = z.title, x = z.x, y = z.y, count = z.count, tex = z.tex, sprite = z.sprite,
      aw = z.aw, ah = z.ah }
  end
  for i, it in ipairs(M.items) do
    out.items[i] = { item = it.item, price = it.price, title = it.title }
  end
  for i, n in ipairs(M.nodes) do
    local reqs = {}
    for k, r in ipairs(n.reqs) do
      if r.kind == "player" then
        reqs[k] = { kind = "player", ids = r.ids, count = r.count, name = name_of_card(r.ids[1]) }
      elseif r.kind == "item" then
        reqs[k] = { kind = "item", id = r.id, count = r.count, title = item_title[r.id] or 0 }
      else
        reqs[k] = { kind = r.kind, count = r.count, element = r.element, position = r.position }
      end
    end
    out.nodes[i] = { kind = n.kind, zone = n.zone, card = n.card, face = n.face, level = n.level, price = n.price,
      name = n.base ~= 0 and name_of_base(n.base) or name_of_card(n.card), x = n.x, y = n.y, links = n.links, reqs = reqs }
    if n.story then
      local notes = {}
      for _, nt in ipairs(n.notes) do
        notes[#notes + 1] = note_text(nt, NAMES.lang or "en")
      end
      out.nodes[i].story, out.nodes[i].notes = true, notes
    end
  end
  return out
end

-- Body types a menu model pose has (menu_chara_model_pose_config); a menu building a 3D model sends the pose only for these.
local POSE_STEM = "data/common/gamedata/menu/menu_chara_model_pose_config"
local POSES = nil                      -- pose id -> { body types }
local function scalar(v)               -- an RDBN field of length 1 may come as { value }
  if type(v) == "table" then return v[1] end
  return v
end
local function pose_index()
  if POSES ~= nil then return POSES end
  local t0 = VRFW.now()
  POSES = {}
  local ok, e = pcall(function()
    local key = table_key(POSE_STEM)
    local data = VRFW.table.raw(key, "m_BodyTypePoseDataList", { 2 }) or {}
    for _, r in ipairs(VRFW.table.raw(key, "m_MenuCharaBodyTypePoseList", { 1, 2 }) or {}) do
      local pose = u32(scalar(r[1]))
      if POSES[pose] == nil then
        local out = {}
        local sl = r[2]
        if type(sl) == "table" and sl.start == nil and type(sl[1]) == "table" then sl = sl[1] end
        local start = type(sl) == "table" and tonumber(sl.start or sl[1]) or nil
        local count = type(sl) == "table" and tonumber(sl.count or sl[2]) or nil
        if start and count then
          for k = start + 1, start + count do
            local d = data[k]
            local b = d and tonumber(scalar(d[2]))
            if b ~= nil then out[#out + 1] = b end
          end
        end
        POSES[pose] = out
      end
    end
  end)
  if not ok then warn("menu_chara_model_pose_config not readable: " .. tostring(e)) end
  local n = 0
  for _ in pairs(POSES) do n = n + 1 end
  info(string.format("model poses: %d indexed in %d ms", n, math.floor(VRFW.now() - t0)))
  return POSES
end

local POSE_LOGGED = {}
-- Each player in his own team's kit: the uniform for the screen's 3D model, derived per card by lib/chara_kit.lua (0 = none: the build's default). Cached per card.
--   CMND_VRFW_CONTACT_KIT(card) -> { uniform, flags (2 = the keeper shirt), source (belong / roster / none) }
local Kit = require "lib/chara_kit"
function ContactMap.Kit(card)
  local u, f, src = Kit.of(card)
  return { uniform = u, flags = f, source = src }
end

function ContactMap.PoseBodies(pose)
  pose = u32(pose)
  local out = pose_index()[pose] or {}
  if not POSE_LOGGED[pose] then
    POSE_LOGGED[pose] = true
    info(string.format("pose %d: %d body types", pose, #out))
  end
  return out
end

-- The declarations, face check and character index are built once at script load (boot, off the game thread) and kept for the session.
-- Inputs do not change while the game runs; if the build fails, the first call builds it (its WARN says why).
do
  local t0 = VRFW.now()
  local ok, e = pcall(function()
    load()
    pose_index()
  end)
  pcall(Kit.prepare)       -- the kit tables (chara_kit), off the game thread too
  if not ok then
    SETS, CHARA, POSES = nil, nil, nil
    warn("built at load failed (" .. tostring(e) .. "): built on the screen's first call")
  else
    info(string.format("contact maps built at load in %d ms (off the game thread)", math.floor(VRFW.now() - t0)))
  end
end
