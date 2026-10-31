-- Contact maps (schema VRFW.contact_map/1): serves every active mod's content\contact_maps\*.toml to the screen vrfw_contact_map_menu.
-- Declarations: [[VRFW.ContactSet]], [[VRFW.ContactMap]] with its Zone / Node / Item entries. Recruiting, prices and the per-save record are the screen's.
-- A [[VRFW.ContactMap]] with a [VRFW.ContactMap.Teams] table is built from the game's teams and matches (lib/contact_teams.lua).
--   CMND_VRFW_CONTACT_SETS()          -> { {key, crc, title, maps}, ... }  every declared set
--   CMND_VRFW_CONTACT_MAPS(set, lang) -> { key, title, rc, ic, rct, ict, maps = { {key, title, kind, tex, sprite, players, excl, series}, ... }, reveal, refund, join_rarity }  (set = crc32 of "<mod>.<name>" or the text)
--   CMND_VRFW_CONTACT_MAP(map, lang)  -> { key, kind, title, tex, sprite, strict, series, zones = {... label, reqs}, items = {...}, nodes = { {kind, zone, card, face, level, price, name, x, y, links, reqs, story, notes, cards} } }  (map = key text or crc32)
-- Titles are sent as crc32 of their menu_text row id; character and team names are read from the game's chara_text / team_text in the asked language.

ContactMap = ContactMap or {}

require "VRFW/lib/basics"
local GameText = require "VRFW/lib/game_text"
local info, warn = VRFW.logger("contact_map")

-- Debug view-everything mode (config.toml [debug] reveal_all): the screen draws every tile open; signing keeps its real rules and writes nothing.
-- The same key is the game_state vrfw.debug.reveal_all.
local REVEAL_ALL = VRFW.files.config("debug.reveal_all") == true
if REVEAL_ALL then
  warn("[debug] reveal_all is ON: view-everything mode (contact maps, office pages) - turn it off for players")
end

local Id = require "lib/ids"
local u32 = Id.u32

local crc = VRFW.crc32

-- "0x..." / decimal text / a number -> the number; nil otherwise
local function id_of(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % 4294967296 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % 4294967296 end
  return nil
end

-- An item reference: a number / "0x..." as id_of, any other name = its crc32 (a game internal name such as "tk_hr000008",
-- or a mod's item "<mod>.<name>": both are the item's id)
local function item_id(v)
  local n = id_of(v)
  if n then return n end
  if type(v) == "string" and v:match("^%s*[%w_%.]+%s*$") then return crc((v:gsub("^%s+", ""):gsub("%s+$", ""))) end
  return nil
end

local Teams = require "lib/contact_teams"   -- team pages derived from the game's data ([VRFW.ContactMap.Teams])

-- ---------------------------------------------------------------------------------------------- declarations

local SETS, SET_BY, MAPS, MAP_BY = nil, {}, {}, {}
-- [[VRFW.ContactBypass]] Option = "<option id>" (a test mod's own Mods options row): while that row is on, every page
-- of every set is open and signing asks no requirement and spends nothing; { {mod, option}, ... }
local BYPASS = {}
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
local Faces = require "VRFW/lib/faces"     -- the one own-face check (docs/framework/chara-index.md §2)

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
  if face ~= "" then return Faces.of_name(face) end
  local b = base ~= 0 and base or chara_index().base_of[card]
  if b == nil then return nil end
  return Faces.of_character(b)
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
      if (n.spirit or 0) ~= 0 then need_card(n.spirit) end
      for _, r in ipairs(n.reqs) do
        if r.kind == "player" and r.ids[1] ~= nil then need_card(r.ids[1]) end
      end
    end
  end
end

local lang_of = GameText.language

local function names_for(lang)
  chara_index()
  if NAMES.lang == lang then return end
  local t0 = VRFW.now()
  NAMES.of = GameText.chara_names(NEED.list, lang)
  NAMES.lang = lang
  info(string.format("names (%s): %d text ids read in %d ms", lang, #NEED.list, math.floor(VRFW.now() - t0)))
end

-- A game text table's row in a language (Notes); the whole table is read once per language
local function game_text(tbl, lang, id)
  return GameText.texts(tbl, lang)[id]
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

-- A team's name (team_text, furigana reduced) in a language; "" when unknown
local function team_name(id, lang)
  if id == nil or id == 0 then return "" end
  local s = GameText.texts("team_text", lang)[id]
  return s and GameText.no_furigana(s) or ""
end

-- [VRFW.ContactSet] ElementCurrency = { wind = card, forest = …, fire = …, mountain = …, void = … }: the spirit card a
-- team page's player of that element costs (the classic «fichas»); element number -> card
local function element_currency(t)
  if type(t) ~= "table" then return nil end
  local out = {}
  for name, e in pairs(ELEMENTS) do
    local id = id_of(t[name])
    if id then out[e] = id end
  end
  return next(out) and out or nil
end

-- [VRFW.ContactSet] Requirements = { config = "<dotted path of the declaring mod's config>", default = … } or a
-- bool: false = the team pages' card terms ask no requirement (price only; trials stay playable); absent = asked
local function requirements_on(v, mod)
  if type(v) == "boolean" then return v end
  if type(v) ~= "table" or type(v.config) ~= "string" then return nil end
  local ok, x = pcall(VRFW.files.config, v.config, mod)
  if not ok or x == nil then x = v.default end
  return x == true
end

-- [VRFW.ContactSet] ElementCurrencyTitle = { wind = "<menu_text row>", … }: the name of each element's price spirit
-- (e.g. «Fichas de Viento»; ElementCurrencyUnit: one of them, «Ficha de viento»); element number -> crc32 of the row
local function element_titles(t)
  if type(t) ~= "table" then return nil end
  local out = {}
  for name, e in pairs(ELEMENTS) do
    if type(t[name]) == "string" and t[name] ~= "" then out[e] = crc(t[name]) end
  end
  return out
end

-- the build's context for the derived team pages
local TEAMS_CTX = {
  warn = warn, info = info, crc = crc,
  own_face = function(card, base) return own_face("", base, card) end,
  team_name = function(id) return team_name(id, "en") end,
}

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
  local DERIVED, TERMS, TRIALS = {}, {}, {}
  for _, f in ipairs(files) do
    local v = type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW or {}
    for _, b in ipairs(type(v.ContactBypass) == "table" and v.ContactBypass or {}) do
      if type(b) == "table" and type(b.Option) == "string" and b.Option ~= "" then
        BYPASS[#BYPASS + 1] = f.mod .. "." .. b.Option
        warn("[debug] mods/" .. f.mod .. ": contact map bypass switch " .. f.mod .. "." .. b.Option .. " declared (test only)")
      end
    end
    for _, s in ipairs(type(v.ContactSet) == "table" and v.ContactSet or {}) do
      if type(s.Name) == "string" then
        local key = f.mod .. "." .. s.Name
        local set = { key = key, crc = crc(key), title = crc(s.Title or key), rc = item_id(s.RecruitCurrency) or 0,
          ic = item_id(s.ItemCurrency) or 0, rct = crc(s.RecruitCurrencyTitle or ""), ict = crc(s.ItemCurrencyTitle or ""), maps = {},
          exclude = type(s.Exclude) == "table" and s.Exclude or nil, where = string.format("mods/%s/%s", f.mod, f.file),
          teams = type(s.Teams) == "table" and s.Teams or nil, derived = {},
          element_currency = element_currency(s.ElementCurrency),
          trial_friendly = type(s.TrialFriendly) == "string" and s.TrialFriendly or nil,
          trial_friendly_team = type(s.TrialFriendlyActiveTeam) == "string" and s.TrialFriendlyActiveTeam or nil,
          terms = {}, trials = {},
          refund = math.max(0, math.floor(tonumber(s.ReleaseRefund) or 0)),
          join_rarity = tonumber(s.JoinRarity) and math.max(0, math.floor(tonumber(s.JoinRarity))) or nil,
          requirements = requirements_on(s.Requirements, f.mod),
          hub = type(s.Hub) == "string" and s.Hub or nil,
          element_title = element_titles(s.ElementCurrencyTitle),
          element_unit = element_titles(s.ElementCurrencyUnit) }
        if SET_BY[key] == nil then
          SETS[#SETS + 1] = set
          SET_BY[key], SET_BY[set.crc] = set, set
        end
      end
    end
    -- per-card terms and trials of a set (team pages): read after every set is known
    for _, t in ipairs(type(v.ContactTerms) == "table" and v.ContactTerms or {}) do
      TERMS[#TERMS + 1] = { mod = f.mod, set = t.Set, list = t.Terms, where = string.format("mods/%s/%s", f.mod, f.file) }
    end
    for _, t in ipairs(type(v.ContactTrials) == "table" and v.ContactTrials or {}) do
      TRIALS[#TRIALS + 1] = { mod = f.mod, set = t.Set, list = t.Trials }
    end
    for mi, m in ipairs(type(v.ContactMap) == "table" and v.ContactMap or {}) do
      local where = string.format("mods/%s/%s: [[VRFW.ContactMap]] #%d", f.mod, f.file, mi)
      if type(m.Name) == "string" and type(m.Teams) == "table" then
        -- team pages derived from the game's data: built once every set is known (below)
        local set = (m.Set or ""):find(".", 1, true) and m.Set or (f.mod .. "." .. tostring(m.Set))
        DERIVED[#DERIVED + 1] = { m = m, mod = f.mod, where = where, key = f.mod .. "." .. m.Name, set = set }
      elseif type(m.Name) ~= "string" or not KINDS[m.Kind or ""] then
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
            warn(key .. ": no player has a face icon (VRFW/lib/faces): the face check is skipped for this map")
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
  -- terms and trials by set: card -> term (the later declaration of a card wins), id -> trial
  local function set_of(mod, name)
    name = tostring(name or "")
    return SET_BY[name:find(".", 1, true) and name or (mod .. "." .. name)]
  end
  for _, t in ipairs(TERMS) do
    local st = set_of(t.mod, t.set)
    if st == nil then
      warn(t.where .. ": [[VRFW.ContactTerms]] of an undeclared set " .. tostring(t.set) .. " (left out)")
    else
      local n = 0
      for _, term in ipairs(type(t.list) == "table" and t.list or {}) do
        local card = id_of(term.Card)
        if card then
          st.terms[card] = term
          n = n + 1
        end
      end
      info(string.format("set %s: %d card terms (%s)", st.key, n, t.where))
    end
  end
  for _, t in ipairs(TRIALS) do
    local st = set_of(t.mod, t.set)
    for _, tr in ipairs(st and type(t.list) == "table" and t.list or {}) do
      local id = tonumber(tr.Id)
      if id then
        st.trials[math.floor(id)] = { id = math.floor(id), game = id_of(tr.Game) or 0, objective = tonumber(tr.Objective) or 0,
          part = tonumber(tr.Part) or 1, of = tonumber(tr.Of) or 1 }
      end
    end
  end
  -- the derived team pages, per set (one character on one page across the whole set)
  for _, d in ipairs(DERIVED) do
    local s = SET_BY[d.set]
    if s then
      s.derived[#s.derived + 1] = d
    else
      warn(d.key .. ": set " .. d.set .. " is not declared (team pages not built)")
    end
  end
  for _, s in ipairs(SETS) do
    if #s.derived > 0 then
      local okb, built = pcall(Teams.build, s, s.derived, TEAMS_CTX)
      if not okb then
        warn(string.format("set %s: team pages not built (%s)", s.key, tostring(built)))
      else
        for _, M in ipairs(built) do
          if MAP_BY[M.key] == nil then
            MAPS[#MAPS + 1] = M
            MAP_BY[M.key], MAP_BY[M.crc] = M, M
          end
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

-- CMND_VRFW_CONTACT_HUB(set) -> { menu, title }: the menu a set opens on (Hub = "free_match": the free-match list
-- soccer_vs_cpu_list_menu as the set's team hub; 0 = the contact map screen itself) and the set's title row
local HUBS = { free_match = 1970579282 }   -- crc32("soccer_vs_cpu_list_menu")
function ContactMap.Hub(set)
  local s = find_set(set)
  if s == nil then return nil end
  return { menu = HUBS[s.hub or ""] or 0, title = s.title }
end

-- CMND_VRFW_CONTACT_FIND(set, game) -> { map = key, zone = n }: the team page of a match (derived maps); nil = none
function ContactMap.Find(set, game)
  local s = find_set(set)
  game = u32(game)
  if s == nil or game == 0 then return nil end
  for _, M in ipairs(s.maps) do
    for z, zone in ipairs(M.zones) do
      if type(zone.games) == "table" and zone.games[game] then
        return { map = M.key, zone = z }
      end
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------------- hub list filter
-- While a set's hub is open (CMND_VRFW_CONTACT_HUB_FILTER(set) from the list's OnInit; 0 from any other open and when
-- the hub closes), the free-match list's builder (hook ContactHub.ListBuild, content/game/contact_hub.toml) keeps only
-- the rows whose match has a team page: its row pointers (aggregate + 0x10) compacted, its count (+ 0x08) lowered.
local HUBF = { games = nil, applied = false, logs = 0, bypass = false, tabs = nil }

-- a declared bypass switch ([[VRFW.ContactBypass]]) is on now
local function bypass_on()
  for _, key in ipairs(BYPASS) do
    local ok, v = pcall(VRFW.option, key)
    if ok and v ~= nil and v ~= 0 and v ~= false then return true end
  end
  return false
end

function ContactMap.HubFilter(set)
  local s = (set ~= nil and set ~= 0) and find_set(set) or nil
  if s == nil then
    HUBF.games = nil
    return false
  end
  local games = {}
  for _, M in ipairs(s.maps) do
    for _, zone in ipairs(M.zones) do
      for g in pairs(type(zone.games) == "table" and zone.games or {}) do games[g] = true end
    end
  end
  HUBF.games = games
  -- a bypass switch on: the list also shows the rows of teams not unlocked yet (every page reachable)
  HUBF.bypass = bypass_on()
  if HUBF.bypass and HUBF.tabs == nil then
    HUBF.tabs = Teams.game_tabs(warn)
  end
  if not HUBF.applied then
    local ok, done, e = pcall(VRFW.hook.apply, "ContactHub.ListBuild")
    HUBF.applied = ok and done == true
    if not HUBF.applied then
      warn("hook ContactHub.ListBuild not installed (" .. tostring(ok and e or done) .. "): the hub lists every team")
    end
  end
  return HUBF.applied
end

local function rd(ty, at)
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- The builder (BuildRows) walks the opponent table (aggregate + 0x810: rows + 0x50, count + 0x58, 0x1C bytes: category,
-- game, sort, 4 class conditions) and appends a 12-byte entry (game, category, sort, 4 class marks) and its pointer for
-- each row of the asked tab (filter + 4) whose class is open; at most 0x100. With a bypass switch on, the rows of the tab
-- that have a page and were left out are built the same way, and the pointers are put back in the table's order.
local ROWS = { TABLE = 0x810, ROWS = 0x50, COUNT = 0x58, STRIDE = 0x1C, ENTRY = 12, MAX = 0x100, JOVENES = 0x10C538F9 }

local function tab_of_row(category, game)
  if game == ROWS.JOVENES then return 1 end      -- the builder's own exception (the tutorial team in the IE2 tab)
  if category == 0 then return 8 end
  return (HUBF.tabs or {})[game] or 0
end

local function add_locked_rows(agg, entries, filter)
  local tab = rd("u8", filter + 4)
  local tbl = rd("ptr", agg + ROWS.TABLE)
  if type(tab) ~= "number" or type(tbl) ~= "number" or tbl < 0x10000 then return end
  local rows, count = rd("ptr", tbl + ROWS.ROWS), rd("u32", tbl + ROWS.COUNT)
  local n = rd("u32", agg + 8)
  if type(rows) ~= "number" or rows < 0x10000 or type(count) ~= "number" or count > 4096 or type(n) ~= "number" then
    return
  end
  local have, used = {}, 0
  for i = 0, n - 1 do
    local q = rd("ptr", agg + 0x10 + i * 8)
    local g = q and rd("u32", q)
    if g then have[u32(g)] = q end
    if q and q >= entries then used = math.max(used, math.floor((q - entries) / ROWS.ENTRY) + 1) end
  end
  local order, added = {}, 0
  for r = 0, count - 1 do
    local at = rows + r * ROWS.STRIDE
    local category, g = rd("u32", at), rd("u32", at + 4)
    g = g and u32(g) or 0
    if g ~= 0 and category ~= nil then
      if have[g] then
        order[#order + 1] = have[g]
        have[g] = nil
      elseif HUBF.games[g] and tab_of_row(category, g) == tab and used < ROWS.MAX and #order < ROWS.MAX then
        local e = entries + used * ROWS.ENTRY
        local sort = rd("u32", at + 8) or 0
        pcall(VRFW.mem.write, "u32", e, g)
        pcall(VRFW.mem.write, "u8", e + 4, category % 256)
        pcall(VRFW.mem.write, "u16", e + 6, sort % 65536)
        for k = 0, 3 do pcall(VRFW.mem.write, "u8", e + 8 + k, 0xFF) end
        used = used + 1
        added = added + 1
        order[#order + 1] = e
      end
    end
  end
  for _, q in pairs(have) do order[#order + 1] = q end   -- a built row the table walk did not meet: kept, at the end
  if added == 0 or #order > ROWS.MAX then return end
  for i, q in ipairs(order) do pcall(VRFW.mem.write, "ptr", agg + 0x10 + (i - 1) * 8, q) end
  pcall(VRFW.mem.write, "u32", agg + 8, #order)
  if HUBF.logs < 20 then
    HUBF.logs = HUBF.logs + 1
    info(string.format("hub list: bypass switch on: %d locked team(s) of tab %d listed", added, tab))
  end
end

VRFW.on("hook:ContactHub.ListBuild:post", function(ev)
  local games = HUBF.games
  if games == nil then return end
  local agg, entries = tonumber(ev.args and ev.args[1]) or 0, tonumber(ev.args and ev.args[2]) or 0
  if agg < 0x10000 or entries < 0x10000 then return end
  local filter = tonumber(ev.args and ev.args[4]) or 0
  if HUBF.bypass and filter >= 0x10000 then
    local ok, e = pcall(add_locked_rows, agg, entries, filter)
    if not ok and HUBF.logs < 20 then
      HUBF.logs = HUBF.logs + 1
      warn("hub list: bypass rows not added (" .. tostring(e) .. ")")
    end
  end
  local n = rd("u32", agg + 8)
  if type(n) ~= "number" or n == 0 or n > 4096 then return end
  -- the retail layout only (pointers into the entries the builder was handed): a raised list keeps its rows
  local first = rd("ptr", agg + 0x10)
  if type(first) ~= "number" or first < entries or first >= entries + n * 12 then
    if HUBF.logs < 3 then
      HUBF.logs = HUBF.logs + 1
      warn("hub list: row pointers not in the retail layout: every team listed")
    end
    return
  end
  local kept = 0
  for i = 0, n - 1 do
    local p = rd("ptr", agg + 0x10 + i * 8)
    local g = p and rd("u32", p)
    if g and games[u32(g)] then
      if kept ~= i then pcall(VRFW.mem.write, "ptr", agg + 0x10 + kept * 8, p) end
      kept = kept + 1
    end
  end
  if kept ~= n then
    pcall(VRFW.mem.write, "u32", agg + 8, kept)
    if HUBF.logs < 20 then
      HUBF.logs = HUBF.logs + 1
      info(string.format("hub list: %d of %d teams have a page", kept, n))
    end
  end
end)

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
  -- refund: the spirits a released player gives back on a team page (ReleaseRefund, the price's spirit); join_rarity:
  -- the rarity a signed player joins at (JoinRarity; nil = the recruit service's default)
  -- bypass: a declared bypass switch is on now (read at each open: the row applies without a restart)
  local bypass = bypass_on()
  local out = { key = s.key, title = s.title, rc = s.rc, ic = s.ic, rct = s.rct, ict = s.ict, maps = {},
    reveal = REVEAL_ALL or bypass, bypass = bypass,
    refund = s.refund or 0, join_rarity = s.join_rarity }
  for _, M in ipairs(s.maps) do
    -- series: a chara_series_id whose name (CMND_GET_CHARA_SERIES_INFO) the screen shows instead of the title
    out.maps[#out.maps + 1] = { key = M.key, title = M.title, kind = M.kind, tex = M.tex, sprite = M.sprite, players = M.players,
      excl = M.excl or {}, series = M.series or 0 }
  end
  return out
end

-- the element whose price spirit is `spirit`, and the name row of that spirit (0 = none declared)
local function pay_element(s, spirit)
  for e, c in pairs(s.element_currency or {}) do
    if c == spirit then return e end
  end
  return 0
end
local function pay_title(s, spirit)
  local e = pay_element(s, spirit)
  return e ~= 0 and s.element_title and s.element_title[e] or 0
end
-- [VRFW.ContactSet] ElementCurrencyUnit: the name of ONE price spirit of that element (a team page's cost line)
local function pay_unit(s, spirit)
  local e = pay_element(s, spirit)
  return e ~= 0 and s.element_unit and s.element_unit[e] or 0
end

function ContactMap.Map(map, code)
  local M = find_map(map)
  if M == nil then return nil end
  names_for(lang_of(code))
  local out = { key = M.key, kind = M.kind, title = M.title, tex = M.tex, sprite = M.sprite, strict = M.strict, zones = {},
    items = {}, nodes = {}, series = M.series or 0, pitch = M.pitch == true }
  local s = SET_BY[M.set] or {}
  local lang = NAMES.lang or "en"
  local item_title = {}
  for _, it in ipairs(M.items) do item_title[it.item] = it.title end
  if s.ic then item_title[s.ic] = item_title[s.ic] or s.ict end
  if s.rc then item_title[s.rc] = item_title[s.rc] or s.rct end
  -- a «cleared» requirement (team pages): any (game, difficulty) of `games` won; `name` = the team to beat
  local function cleared(r)
    return { kind = "cleared", games = r.games, count = 1, name = team_name(r.name_text, lang) }
  end
  for i, z in ipairs(M.zones) do
    -- label: the zone's name as text (a team page: the team's name), shown instead of its title
    out.zones[i] = { name = z.name, title = z.title, x = z.x, y = z.y, count = z.count, tex = z.tex, sprite = z.sprite,
      aw = z.aw, ah = z.ah, label = team_name(z.name_text, lang), team = z.team }
    if type(z.reqs) == "table" and z.reqs[1] ~= nil and z.reqs[1].kind == "cleared" then
      out.zones[i].reqs = { cleared(z.reqs[1]) }
    end
  end
  for i, it in ipairs(M.items) do
    out.items[i] = { item = it.item, price = it.price, title = it.title }
  end
  for i, n in ipairs(M.nodes) do
    local reqs = {}
    for k, r in ipairs(n.reqs) do
      if r.kind == "player" then
        reqs[k] = { kind = "player", ids = r.ids, count = r.count, name = name_of_card(r.ids[1]), level = r.level }
      elseif r.kind == "item" then
        reqs[k] = { kind = "item", id = r.id, count = r.count, title = item_title[r.id] or 0 }
      elseif r.kind == "cleared" then
        reqs[k] = cleared(r)
      elseif r.kind == "unlock" then
        reqs[k] = { kind = "unlock", groups = r.groups, count = 1, name = team_name(r.name_text, lang) }
      elseif r.kind == "trial" then
        reqs[k] = { kind = "trial", friendly = r.friendly, friendly_team = r.friendly_team, tag = r.tag, sub = r.sub,
          game = r.game, difficulty = r.difficulty, objective = r.objective, part = r.part, of = r.of, count = 1 }
      else
        reqs[k] = { kind = r.kind, count = r.count, element = r.element, position = r.position }
      end
    end
    -- cards: every card of the character (a team page: one card per character, any of them owned = signed)
    out.nodes[i] = { kind = n.kind, zone = n.zone, card = n.card, face = n.face, level = n.level, price = n.price,
      name = n.base ~= 0 and name_of_base(n.base) or name_of_card(n.card), x = n.x, y = n.y, links = n.links, reqs = reqs,
      cards = n.cards, spirit = n.spirit, item = n.item, slot = n.slot, px = n.px, py = n.py, trials = n.trials,
      element = n.element, position = n.position, main = n.main, staff = n.staff,
      sold_at = (n.sold_at or 0) ~= 0 and team_name(n.sold_at, lang) or nil,
      sold_team = (n.sold_team or 0) ~= 0 and n.sold_team or nil, sold_map = n.sold_map,
      pay_element = pay_element(s, n.spirit), pay_title = pay_title(s, n.spirit), pay_unit = pay_unit(s, n.spirit),
      pay_name = (n.spirit or 0) ~= 0 and name_of_card(n.spirit) or nil }
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
--   CMND_VRFW_CONTACT_KIT(card[, team]) -> { uniform, flags (2 = the keeper shirt), source (team / belong / roster / none) };
--   team = a team_config id that dresses the card (its uniform first)
local Kit = require "lib/chara_kit"
function ContactMap.Kit(card, team)
  local u, f, src = Kit.of(card, team)
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
