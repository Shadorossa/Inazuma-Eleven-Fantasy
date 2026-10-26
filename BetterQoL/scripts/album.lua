-- BetterQoL › player album («Álbum de jugadores», docs/game/ui/album.md): every player of the game and the enabled mods,
-- grouped by name or by game, with a tick for the ones the club has. The page is util_album_menu (content\menus\album.toml,
-- assets\lua\screens\util_album_menu.lua), opened from «Caseta del club» (graft util_album_row).
--
-- The roster (built once, at the first opening):
--   * a chara_base row of kind 10 (a player), with a serial number (0 = the avatars), a name, a series and a normal
--     card (chara_param: the team planner's rule, config.toml [team_planner] card_values);
--   * a base whose voice bank is another listed character (his outfits and eras) and bases sharing one model (the same
--     face and body) are one row: the first base in table order; the club has the row when it has any of their cards.
-- «Juego» lists a series' players in its team order (belong_team_config teamNumber_<X>, the original-names catalogue),
-- the rest after them; «Nombre» sorts every player by name and groups him by his first letter (the groups are a text
-- of the page's language, passed by the page).
--
-- Commands (content\game\album.toml):
--   CMND_BETTERQOL_ALBUM_OPEN(lang code, name groups text, label of the other names) -> { total, owned, groups = { [1] = name groups, [2] = game
--     groups } } with each group { label, total, owned, series type (game groups) }; false = no roster
--   CMND_BETTERQOL_ALBUM_PAGE(kind, group, page, rows a page) -> { page, pages, total, owned, rows = { { chara_base, param,
--     name, team, series name, owned, level, rarity } … } }; kind 1 = name, 2 = game; group / page 1-based

local C = require "lib/tp_core"
local Cat = require "lib/original_names_catalogue"
local T = require "lib/original_names_tables"

BetterQoL = BetterQoL or {}
BetterQoL.Album = BetterQoL.Album or {}

local PLAYER_KIND = 10
local DECL_PATHS = { "content/team_planner", "team_planner" }
local OWNED_TTL_MS = 2000

local int, u32 = C.int, C.u32

local function info(...) VRFW.log("album:", ...) end
local function warn(...) VRFW.warn("album:", ...) end

local roster = nil       -- { entries = { e … }, by_base = { [base] = e }, of_param = { [param] = e } }
local names = {}         -- [lang] = { group spec, name rows, team rows, series rows, groups, sorted }
local view = nil         -- the opening's language state

-- ---------------------------------------------------------------------------------------------- the roster

local function card_values()
  local okc, cfg = pcall(VRFW.files.config, "team_planner")
  local okd, decls = pcall(VRFW.files.declarations, DECL_PATHS)
  return C.rule(okc and cfg or nil, okd and decls or {}).card_values
end

local function build()
  -- the cards as the game loads them (the framework's character index: chara-index.md)
  local params = {}
  local base_of = {}
  for _, c in ipairs(VRFW.chara.cards()) do
    local p, b = u32(c.id), u32(c.base)
    if p ~= 0 and b ~= 0 then
      params[#params + 1] = { p, b, int(c.rarity) or 0 }
      base_of[p] = b
    end
  end
  local card = C.card_params(params, card_values())
  local cat = Cat.build(Cat.series_rows(), Cat.belong_rows(), Cat.charas(), {})
  local series_of = {}
  for si, s in ipairs(cat.series) do
    series_of[s.id] = si
  end
  local rows = VRFW.table.rows("character/chara_base")
  local listed = {}
  for _, r in ipairs(rows) do
    local b = u32(r.id)
    if card[b] and int(r.kind) == PLAYER_KIND and (int(r.serial_no) or 0) > 0 and u32(r.name_text) ~= 0
        and series_of[u32(r.series)] then
      listed[b] = true
    end
  end
  local entries, by_base, by_model, fold_into = {}, {}, {}, {}
  for _, r in ipairs(rows) do
    local b = u32(r.id)
    if listed[b] then
      local voice, model = u32(r.voice_bank), u32(r.model)
      local into = nil
      if voice ~= 0 and voice ~= b and listed[voice] then
        into = voice
      elseif model ~= 0 and by_model[model] then
        into = by_model[model]
      end
      if into then
        fold_into[b] = into
      else
        local e = { base = b, param = card[b], name_text = u32(r.name_text), si = series_of[u32(r.series)],
                    teams = { u32(r.team_1), u32(r.team_2), u32(r.team_3) }, bases = { b } }
        entries[#entries + 1] = e
        by_base[b] = e
        if model ~= 0 then
          by_model[model] = b
        end
      end
    end
  end
  -- a folded base whose own target was folded too: the row it ended in
  for b, into in pairs(fold_into) do
    local e = by_base[into]
    local hops = 0
    while e == nil and fold_into[into] and hops < 8 do
      into = fold_into[into]
      e = by_base[into]
      hops = hops + 1
    end
    if e then
      e.bases[#e.bases + 1] = b
      by_base[b] = e
    end
  end
  local of_param = {}
  for p, b in pairs(base_of) do
    if by_base[b] then
      of_param[p] = by_base[b]
    end
  end
  -- «Juego»: each series' players in its team order, then the ones in no team row of it
  local series = {}
  for si, s in ipairs(cat.series) do
    local list, seen = {}, {}
    for _, tr in ipairs(Cat.rows(cat, s)) do
      for _, ci in ipairs(tr.players) do
        local e = by_base[cat.charas[ci][8]]
        if e and e.si == si and not seen[e] then
          seen[e] = true
          e.team = e.team or tr.team
          list[#list + 1] = e
        end
      end
    end
    for _, e in ipairs(entries) do
      if e.si == si and not seen[e] then
        seen[e] = true
        list[#list + 1] = e
      end
    end
    if #list > 0 then
      series[#series + 1] = { si = si, ty = s.ty or 0, name_text = s.name_text, list = list }
    end
  end
  for _, e in ipairs(entries) do
    if not e.team then
      for _, t in ipairs(e.teams) do
        if t ~= 0 then
          e.team = t
          break
        end
      end
    end
  end
  roster = { entries = entries, by_base = by_base, of_param = of_param, series = series, cat = cat }
  info(string.format("roster: %d players (%d bases folded into them), %d games", #entries,
    (function() local n = 0 for _ in pairs(fold_into) do n = n + 1 end return n end)(), #series))
end

local function ensure_roster()
  if roster == nil then
    local ok, err = pcall(build)
    if not ok then
      roster = nil
      warn("no roster (" .. tostring(err) .. ")")
    end
  end
  return roster
end

-- ---------------------------------------------------------------------------------------------- the club

local owned_cache, owned_at = nil, nil

-- [entry] = { param, level, handle } of the club's best copy (highest level) of each row; its rarity is read when a
-- page shows it (rarity_of: one record read per row shown, not one per club player at every opening)
local function owned()
  local now = VRFW.now()
  if owned_cache and owned_at and now - owned_at < OWNED_TTL_MS then
    return owned_cache
  end
  local out = {}
  local ok, list = pcall(VRFW.chara.saved)
  if ok and type(list) == "table" then
    for _, c in ipairs(list) do
      local p = u32(c.param)
      local e = roster.of_param[p]
      local lv = int(c.level) or 0
      if e and (out[e] == nil or lv > out[e].level) then
        out[e] = { param = p, level = lv, handle = int(c.handle) }
      end
    end
  else
    warn("saved characters not read (" .. tostring(list) .. ")")
  end
  owned_cache, owned_at = out, now
  return out
end

-- the rarity of an owned copy (read once, kept with it)
local function rarity_of(o)
  if o.rarity == nil then
    local okr, rec = pcall(VRFW.chara.record, o.handle)
    o.rarity = (okr and type(rec) == "table" and int(rec.rarity)) or 0
  end
  return o.rarity
end

-- ---------------------------------------------------------------------------------------------- names and groups

local function lang_of(code)
  local c = int(code)
  if c and c >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[c + 1] or nil
    if type(l) == "string" then
      return l
    end
  end
  return "en"
end

local function text_rows(lang, tbl)
  local ok, rows = pcall(VRFW.files.text_rows, T.text_key(lang, tbl))
  if ok and type(rows) == "table" then
    return rows
  end
  if lang ~= "en" then
    return text_rows("en", tbl)
  end
  return {}
end

local function text_of(rows, id)
  local r = rows and rows[id]
  local s = r and r[0]
  if type(s) == "string" and s ~= "" and s:sub(1, 1) ~= "<" then
    return T.strip_furigana(s)
  end
  return nil
end

-- the UTF-8 characters of s
local function chars(s)
  local out = {}
  for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    out[#out + 1] = ch
  end
  return out
end

-- a Latin letter without its accent, upper case (other characters as they are)
local PLAIN = {}
do
  local groups = {
    A = "ÀÁÂÃÄÅàáâãäå", C = "Çç", E = "ÈÉÊËèéêë", I = "ÌÍÎÏìíîï", N = "Ññ", O = "ÒÓÔÕÖØòóôõöø",
    U = "ÙÚÛÜùúûü", Y = "Ýýÿ",
  }
  for plain, list in pairs(groups) do
    for _, ch in ipairs(chars(list)) do
      PLAIN[ch] = plain
    end
  end
end

local function fold_char(ch)
  return PLAIN[ch] or ch:upper()
end

local function fold(s)
  local out = {}
  for i, ch in ipairs(chars(s)) do
    out[i] = fold_char(ch)
  end
  return table.concat(out)
end

-- the language's state: names, the «Nombre» groups (spec: first letters of each group, split by «,»)
local function language(code, spec, other_label)
  local lang = lang_of(code)
  spec = tostring(spec or "")
  local L = names[lang]
  other_label = tostring(other_label or "#")
  if L and L.spec == spec and L.other == other_label then
    return L
  end
  local crows = text_rows(lang, T.CHARA)
  local trows = text_rows(lang, T.TEAM)
  local srows = text_rows(lang, T.SERIES_TEXT)
  L = { lang = lang, spec = spec, other = other_label, name = {}, key = {}, team_rows = trows, series_rows = srows }
  for _, e in ipairs(roster.entries) do
    local n = text_of(crows, e.name_text) or ""
    L.name[e] = n
    L.key[e] = fold(n)
  end
  local sorted = {}
  for _, e in ipairs(roster.entries) do
    if L.name[e] ~= "" then
      sorted[#sorted + 1] = e
    end
  end
  table.sort(sorted, function(a, b)
    if L.key[a] ~= L.key[b] then
      return L.key[a] < L.key[b]
    end
    return a.base < b.base
  end)
  local groups, of_char = {}, {}
  for g in spec:gmatch("[^,]+") do
    local cs = chars(g)
    groups[#groups + 1] = { label = (#cs > 1) and (fold_char(cs[1]) .. "-" .. fold_char(cs[#cs])) or fold_char(cs[1] or "?"),
                            list = {} }
    for _, ch in ipairs(cs) do
      of_char[fold_char(ch)] = of_char[fold_char(ch)] or #groups
    end
  end
  local other = { label = other_label ~= "" and other_label or "#", list = {} }
  for _, e in ipairs(sorted) do
    local first = chars(L.key[e])[1]
    local g = first and of_char[first]
    if g then
      local l = groups[g].list
      l[#l + 1] = e
    else
      other.list[#other.list + 1] = e
    end
  end
  local name_groups = {}
  for _, g in ipairs(groups) do
    if #g.list > 0 then
      name_groups[#name_groups + 1] = g
    end
  end
  if #other.list > 0 then
    name_groups[#name_groups + 1] = other
  end
  local game_groups = {}
  for _, s in ipairs(roster.series) do
    local label = text_of(srows, s.name_text) or text_of(trows, s.name_text) or string.format("0x%08X", s.name_text)
    local list = {}
    for _, e in ipairs(s.list) do
      if L.name[e] ~= "" then
        list[#list + 1] = e
      end
    end
    if #list > 0 then
      game_groups[#game_groups + 1] = { label = label, ty = s.ty, list = list }
    end
  end
  L.groups = { name_groups, game_groups }
  names[lang] = L
  return L
end

local function count(list, have)
  local n = 0
  for _, e in ipairs(list) do
    if have[e] then
      n = n + 1
    end
  end
  return n
end

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_BETTERQOL_ALBUM_OPEN(lang code, name groups text, label of the other names)
function BetterQoL.Album.Open(code, spec, other_label)
  if ensure_roster() == nil then
    return false
  end
  owned_cache = nil
  local L = language(code, spec, other_label)
  local have = owned()
  view = L
  local out = { total = 0, owned = 0, groups = {} }
  for kind, gl in ipairs(L.groups) do
    local o = {}
    for i, g in ipairs(gl) do
      o[i] = { g.label, #g.list, count(g.list, have), g.ty or 0 }
    end
    out.groups[kind] = o
  end
  for _, e in ipairs(roster.entries) do
    if L.name[e] ~= "" then
      out.total = out.total + 1
      if have[e] then
        out.owned = out.owned + 1
      end
    end
  end
  info(string.format("opened (%s): %d players, %d in the club, %d name groups, %d games", L.lang, out.total, out.owned,
    #L.groups[1], #L.groups[2]))
  return out
end

-- CMND_BETTERQOL_ALBUM_PAGE(kind, group, page, rows a page)
function BetterQoL.Album.Page(kind, group, page, per)
  local L = view
  if L == nil or roster == nil then
    return false
  end
  local gl = L.groups[int(kind) or 0]
  local g = gl and gl[int(group) or 0]
  if g == nil then
    return false
  end
  per = math.max(1, int(per) or 20)
  local pages = math.max(1, math.ceil(#g.list / per))
  page = math.max(1, math.min(pages, int(page) or 1))
  local have = owned()
  local out = { page = page, pages = pages, total = #g.list, owned = count(g.list, have), rows = {} }
  for k = 1, per do
    local e = g.list[(page - 1) * per + k]
    if e == nil then
      break
    end
    local o = have[e]
    out.rows[k] = { e.base, o and o.param or e.param, L.name[e], (e.team and text_of(L.team_rows, roster.cat.team_names[e.team]))
                      or "", text_of(L.series_rows, roster.cat.series[e.si].name_text) or "", o ~= nil,
                    o and o.level or 1, o and rarity_of(o) or 0 }
  end
  return out
end

-- ---------------------------------------------------------------------------------------------- start

ensure_roster()
