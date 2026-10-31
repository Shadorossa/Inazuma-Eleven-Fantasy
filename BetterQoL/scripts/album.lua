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
-- «Juego» also lists the album categories other mods declare in content\album\*.toml ([[series]]: series =
-- <chara_series_config id> names the tab and gives its logo, the series type's tab icon; its members are the cards
-- of `cards` = card-set rules as VRFW.chara.select reads them (docs/framework/chara-index.md §4: team, mod, set, …)
-- and / or of the characters in the belong team `team`). Each member character is a row of its own, shown as its
-- own card (its model, outfit and stats), never folded into the character it copies (voice bank / model); with
-- `exclusive` (default true) it is listed only under its category, not under the series it was cloned from. Its 3D
-- model wears the kit of the declaring mod's first team (content	eams [[team]], id = crc32(key)) whose roster lists
-- his card (`kit_from_own_teams`, default true; the plate's VRFW.plate_card_team), else his own team's kit.
-- Hidden rarities: a mod's contentlbum [[hide_rarities]] (option = a full option row key, when = [{ values = [option
-- values], rarities = [card rarities] }, …]) keeps the cards of those rarities out of the album while its option row
-- has one of those values (e.g. No More Rarities' removed Ídolo / Diamante tiers); the roster is rebuilt when the
-- value in force changes.
-- Last, «Especiales»: every card of a listed player whose rarity is above [album] display_rarity (Idol, Diamond, …),
-- listed by the character name alone.
--
-- Commands (content\game\album.toml):
--   CMND_BETTERQOL_ALBUM_OPEN(lang code, name groups text, label of the other names) -> { total, owned, groups = { [1] = name groups, [2] = game
--     groups } } with each group { label, total, owned, series type (game groups) }; false = no roster
--   CMND_BETTERQOL_ALBUM_PAGE(kind, group, page, rows a page) -> { page, pages, total, owned, rows = { { chara_base, param,
--     name, team, series name, owned, level, rarity } … } }; param / level / rarity = the shown card (shown_card); kind 1 = name, 2 = game; group / page 1-based

local C = require "lib/tp_core"
local Cat = require "lib/original_names_catalogue"
local T = require "lib/original_names_tables"

BetterQoL = BetterQoL or {}
BetterQoL.Album = BetterQoL.Album or {}

local PLAYER_KIND = 10
local DECL_PATHS = { "content/team_planner", "team_planner" }
local ALBUM_DECL_PATHS = { "content/album" }
local TEAM_DECL_PATHS = { "content/teams" }
-- the rarity files (the framework's game rarities and any mod's [[rarity]]): their labels name the special cards

local int, u32 = C.int, C.u32

require "VRFW/lib/basics"
local info, warn = VRFW.logger("album")

-- the «Especiales» group's tab icon (a sprite of the game's list tab atlas; config.toml [album] special_icon)
local function special_icon()
  local ok, v = pcall(VRFW.files.config, "album.special_icon")
  return ok and type(v) == "string" and v or ""
end

local roster = nil       -- { entries = { e … }, by_base = { [base] = e }, of_param = { [param] = e } }
local bases = {}         -- [lang] = the language's names of the roster: { name rows, team rows, series rows, keys, sorted }
local names = {}         -- [lang] = { group spec, name rows, team rows, series rows, groups, sorted }
local view = nil         -- the opening's language state
local view_owned = nil   -- the club's cards read at the opening (owned())

-- ---------------------------------------------------------------------------------------------- the roster

local function card_values()
  local okc, cfg = pcall(VRFW.files.config, "team_planner")
  local okd, decls = pcall(VRFW.files.declarations, DECL_PATHS)
  return C.rule(okc and cfg or nil, okd and decls or {}).card_values
end

-- the chara_series_config row of a series id (Cat.series_rows), nil when there is none
local function series_row(series_id)
  for _, r in ipairs(Cat.series_rows()) do
    if r.id == series_id then
      return r
    end
  end
  return nil
end

-- The album categories the mods declare (content/album/*.toml [[series]]): { row, mod, exclusive, bases = { [base] =
-- true } } each, in declaration order. A member base = the character of a card the `cards` rules select, or a
-- character one of whose chara_base team_1..3 is `team`. A base two categories claim stays in the first one.
local function declared_categories(declarations, base_rows, base_of)
  local categories, category_of_base = {}, {}
  for _, d in ipairs(declarations) do
    local data = type(d.data) == "table" and d.data or {}
    for _, sd in ipairs(type(data.series) == "table" and data.series or {}) do
      local series_id, team = u32(sd.series), u32(sd.team)
      local row = series_row(series_id)
      local has_rules = type(sd.cards) == "table"
      if row == nil or (team == 0 and not has_rules) then
        warn("content/album of mod " .. tostring(d.mod) .. ": series " .. string.format("0x%08X", series_id or 0)
          .. " not in chara_series_config or neither cards nor team (skipped)")
      else
        local category = { row = row, mod = d.mod, exclusive = sd.exclusive ~= false,
                           kit_from_own_teams = sd.kit_from_own_teams ~= false, bases = {} }
        local function claim(base)
          if base and base ~= 0 and category_of_base[base] == nil then
            category_of_base[base] = category
            category.bases[base] = true
          end
        end
        if has_rules then
          local ok, selected = pcall(VRFW.chara.select, sd.cards)
          if ok and type(selected) == "table" then
            for _, card_id in ipairs(selected) do
              claim(base_of[u32(card_id)])
            end
          else
            warn("content/album of mod " .. tostring(d.mod) .. ": cards not selected (" .. tostring(selected) .. ")")
          end
        end
        if team ~= 0 then
          for _, r in ipairs(base_rows) do
            if u32(r.team_1) == team or u32(r.team_2) == team or u32(r.team_3) == team then
              claim(u32(r.id))
            end
          end
        end
        categories[#categories + 1] = category
      end
    end
  end
  return categories, category_of_base
end

-- [card] = the team that dresses it: the first [[team]] of the mod `mod` (content/teams, in file order) whose roster
-- lists the card; its id = crc32 of its key, as the team type numbers it
local function own_team_of_cards(mod)
  local out = {}
  local ok, decls = pcall(VRFW.files.declarations, TEAM_DECL_PATHS)
  for _, d in ipairs(ok and type(decls) == "table" and decls or {}) do
    if d.mod == mod and type(d.data) == "table" then
      for _, team in ipairs(type(d.data.team) == "table" and d.data.team or {}) do
        local team_id = type(team.key) == "string" and u32(VRFW.crc32(team.key)) or 0
        if team_id ~= 0 then
          for _, member in ipairs(type(team.member) == "table" and team.member or {}) do
            local card_id = u32(member.card)
            if card_id ~= 0 and out[card_id] == nil then
              out[card_id] = team_id
            end
          end
        end
      end
    end
  end
  return out
end

-- The card rarities the mods' [[hide_rarities]] hide now: { [rarity] = true }, and a signature of the option values
-- read (the roster is rebuilt when it changes)
local function hidden_rarities(declarations)
  local hidden, signature = {}, {}
  for _, d in ipairs(declarations) do
    local data = type(d.data) == "table" and d.data or {}
    for _, rule in ipairs(type(data.hide_rarities) == "table" and data.hide_rarities or {}) do
      local key = type(rule.option) == "string" and rule.option or ""
      local ok, value = pcall(VRFW.option, key)
      if not (ok and value ~= nil) and key ~= "" then
        -- the declaring mod's own row under its current id (the key may name a former id)
        ok, value = pcall(VRFW.option, tostring(d.mod) .. "." .. (key:match("([^.]+)$") or key))
      end
      value = ok and tonumber(value) or nil
      signature[#signature + 1] = key .. "=" .. tostring(value)
      for _, case in ipairs(type(rule.when) == "table" and rule.when or {}) do
        local applies = false
        for _, v in ipairs(type(case.values) == "table" and case.values or {}) do
          if value ~= nil and tonumber(v) == value then applies = true end
        end
        if applies then
          for _, rarity in ipairs(type(case.rarities) == "table" and case.rarities or {}) do
            hidden[int(rarity) or -1] = true
          end
        end
      end
    end
  end
  return hidden, table.concat(signature, ",")
end

-- the mods' content/album declarations: read from disk once (the files are fixed for the session)
local album_decls = nil
local function album_declarations()
  if album_decls == nil then
    local ok, decls = pcall(VRFW.files.declarations, ALBUM_DECL_PATHS)
    album_decls = ok and type(decls) == "table" and decls or {}
  end
  return album_decls
end

local function build()
  -- the cards as the game loads them (the framework's character index: chara-index.md)
  local params = {}
  local base_of = {}
  -- cards a mod keeps out of the album (content/album/*.toml exclude_cards: e.g. cards of one mode only)
  local excluded = {}
  local edecls = album_declarations()
  local hidden, hidden_signature = hidden_rarities(edecls)
  for _, d in ipairs(edecls) do
    local data = type(d.data) == "table" and d.data or {}
    for _, id in ipairs(type(data.exclude_cards) == "table" and data.exclude_cards or {}) do
      excluded[u32(id)] = true
    end
  end
  local okc, acfg = pcall(VRFW.files.config, "album")
  local shown_rarity = (okc and type(acfg) == "table" and int(acfg.display_rarity)) or 0
  local special_cards = {}        -- { param, base, rarity } of the cards above the shown rarity, in card order
  for _, c in ipairs(VRFW.chara.cards()) do
    local p, b = u32(c.id), u32(c.base)
    local rar = int(c.rarity) or 0
    if p ~= 0 and b ~= 0 and not excluded[p] and hidden[rar] then
      base_of[p] = b               -- a hidden rarity's card: no row of its own; owning it still ticks its player
    elseif p ~= 0 and b ~= 0 and not excluded[p] then
      params[#params + 1] = { p, b, rar }
      base_of[p] = b
      if rar > shown_rarity then
        special_cards[#special_cards + 1] = { p, b, rar }
      end
    end
  end
  local card = C.card_params(params, card_values())
  local cat = Cat.build(Cat.series_rows(), Cat.belong_rows(), Cat.charas(), {})
  local series_of = {}
  for si, s in ipairs(cat.series) do
    series_of[s.id] = si
  end
  local rows = VRFW.table.rows("character/chara_base")
  local categories, category_of_base = declared_categories(edecls, rows, base_of)
  local listed = {}
  for _, r in ipairs(rows) do
    local b = u32(r.id)
    if card[b] and int(r.kind) == PLAYER_KIND and (int(r.serial_no) or 0) > 0 and u32(r.name_text) ~= 0
        and (series_of[u32(r.series)] or category_of_base[b]) then
      listed[b] = true
    end
  end
  local entries, by_base, by_model, fold_into = {}, {}, {}, {}
  for _, r in ipairs(rows) do
    local b = u32(r.id)
    if listed[b] then
      local voice, model = u32(r.voice_bank), u32(r.model)
      local category = category_of_base[b]
      local into = nil
      -- a declared category's character is his own row (his own card, model and outfit); nothing folds into him
      if category == nil then
        if voice ~= 0 and voice ~= b and listed[voice] and category_of_base[voice] == nil then
          into = voice
        elseif model ~= 0 and by_model[model] then
          into = by_model[model]
        end
      end
      if into then
        fold_into[b] = into
      else
        local e = { base = b, param = card[b], name_text = u32(r.name_text), si = series_of[u32(r.series)],
                    teams = { u32(r.team_1), u32(r.team_2), u32(r.team_3) }, bases = { b }, category = category,
                    game_name_text = category and category.row.name_text or nil }
        entries[#entries + 1] = e
        by_base[b] = e
        if model ~= 0 and category == nil then
          by_model[model] = b
        end
      end
    end
  end
  -- the team that dresses a category's card (its mod's own team listing it)
  for _, category in ipairs(categories) do
    if category.kit_from_own_teams then
      category.team_of_card = own_team_of_cards(category.mod)
      for _, e in ipairs(entries) do
        if e.category == category then
          e.dress_team = category.team_of_card[e.param]
        end
      end
    end
  end
  -- an entry listed under the series it was cloned from too: a non-exclusive category's, or one of no category
  local function in_source_series(e)
    return e.category == nil or not e.category.exclusive
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
        if e and e.si == si and not seen[e] and in_source_series(e) then
          seen[e] = true
          e.team = e.team or tr.team
          list[#list + 1] = e
        end
      end
    end
    for _, e in ipairs(entries) do
      if e.si == si and not seen[e] and in_source_series(e) then
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
  -- «Equipo»: one group per team of each series (a team row serves several eras: its players of one series are one
  -- group), in the series' team order (a player under his first team; no team = team 0)
  local teams = {}
  for _, s in ipairs(series) do
    local of_team = {}
    for _, e in ipairs(s.list) do
      local t = e.team or 0
      local g = of_team[t]
      if g == nil then
        g = { team = t, ty = s.ty, si = s.si, list = {} }
        of_team[t] = g
        teams[#teams + 1] = g
      end
      g.list[#g.list + 1] = e
    end
  end
  -- the categories the mods declare (content/album/*.toml [[series]]): their own characters, each as his own card
  for _, category in ipairs(categories) do
    local list = {}
    for _, e in ipairs(entries) do
      if e.category == category then
        list[#list + 1] = e
      end
    end
    info(string.format("declared category 0x%08X (mod %s): %d players", category.row.id, tostring(category.mod), #list))
    if #list > 0 then
      series[#series + 1] = { ty = category.row.ty or 0, name_text = category.row.name_text, list = list }
    end
  end
  -- «Especiales»: the special cards of the listed players (entries of their own: the card, its rarity, his name)
  local specials, special_of_param = {}, {}
  for _, c in ipairs(special_cards) do
    local e = by_base[c[2]]
    if e then
      local sp = { base = e.base, param = c[1], rarity = c[3], name_text = e.name_text, si = e.si, team = e.team,
                   teams = e.teams, of = e, special = true, game_name_text = e.game_name_text,
                   dress_team = e.category and e.category.team_of_card and e.category.team_of_card[c[1]] or nil }
      specials[#specials + 1] = sp
      special_of_param[c[1]] = sp
    end
  end
  roster = { entries = entries, by_base = by_base, of_param = of_param, series = series, teams = teams, cat = cat,
             specials = specials, special_of_param = special_of_param, hidden_signature = hidden_signature }
  info(string.format("roster: %d players (%d bases folded into them), %d games", #entries,
    (function() local n = 0 for _ in pairs(fold_into) do n = n + 1 end return n end)(), #series))
end

local function ensure_roster()
  if roster ~= nil then
    local _, signature = hidden_rarities(album_declarations())
    if signature ~= roster.hidden_signature then
      info("hidden rarities changed (" .. tostring(roster.hidden_signature) .. " -> " .. signature .. "): roster rebuilt")
      roster, names, bases = nil, {}, {}
    end
  end
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

-- [entry] = { param, level, handle } of the club's best copy (highest level) of each row (the tick); read once per
-- opening (CMND_BETTERQOL_ALBUM_OPEN, also sent again by the page after an action changed the club)
local function owned()
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
      local sp = roster.special_of_param[p]
      if sp and (out[sp] == nil or lv > out[sp].level) then
        out[sp] = { param = p, level = lv, handle = int(c.handle) }
      end
    end
  else
    warn("saved characters not read (" .. tostring(list) .. ")")
  end
  return out
end

-- ---------------------------------------------------------------------------------------------- the shown card

-- every row is shown as the character's base card at the level cap in effect, never the club's copy: the cap a mod's
-- [VRFW.Level] raised (game_state level.max), else config.toml [album] game_level_cap; the rarity [album] display_rarity
local function shown_card()
  local okc, cfg = pcall(VRFW.files.config, "album")
  cfg = okc and type(cfg) == "table" and cfg or {}
  local level = int(cfg.game_level_cap) or 1
  local okr, raised = pcall(VRFW.state.get, "level.raised")
  local okm, max = pcall(VRFW.state.get, "level.max")
  if okr and okm and raised == 1 and type(max) == "number" and max > level then
    level = math.floor(max)
  end
  return math.max(1, level), int(cfg.display_rarity) or 0
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

-- the rows `ids` of a text table (only those become Lua values: chara_text has ~21k rows)
local function text_rows(lang, tbl, ids)
  local ok, rows = pcall(VRFW.files.text_rows, T.text_key(lang, tbl), ids)
  if ok and type(rows) == "table" then
    return rows
  end
  if lang ~= "en" then
    return text_rows("en", tbl, ids)
  end
  return {}
end

-- the text ids the album reads: character names, team names and game names of the roster
local function roster_text_ids()
  if roster.text_ids then
    return roster.text_ids
  end
  local chara, names_seen, other, other_seen = {}, {}, {}, {}
  local function add(list, seen, id)
    if id and id ~= 0 and not seen[id] then
      seen[id] = true
      list[#list + 1] = id
    end
  end
  for _, e in ipairs(roster.entries) do
    add(chara, names_seen, e.name_text)
    add(other, other_seen, e.game_name_text)
  end
  for _, text_id in pairs(roster.cat.team_names or {}) do
    add(other, other_seen, u32(text_id))
  end
  for _, s in ipairs(roster.cat.series) do
    add(other, other_seen, s.name_text)
  end
  for _, s in ipairs(roster.series) do
    add(other, other_seen, s.name_text)
  end
  roster.text_ids = { chara = chara, other = other }
  return roster.text_ids
end

local function text_of(rows, id)
  local r = rows and rows[id]
  local s = r and r[0]
  if type(s) == "string" and s ~= "" and s:sub(1, 1) ~= "<" then
    return T.strip_furigana(s)
  end
  return nil
end

-- the UTF-8 characters of s; a text (or one character) without accents, upper case (the framework's folding table)
local Fold = require "VRFW/lib/text_fold"
local chars, fold, fold_char = Fold.chars, Fold.fold_upper, Fold.fold_upper

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- the roster's names in one language (its text files read once per language): built at a save load for the game's
-- language, else at the first opening
local function language_base(lang)
  local B = bases[lang]
  if B then
    return B
  end
  local ids = roster_text_ids()
  local crows = text_rows(lang, T.CHARA, ids.chara)
  B = { name = {}, key = {}, team_rows = text_rows(lang, T.TEAM, ids.other), series_rows = text_rows(lang, T.SERIES_TEXT, ids.other) }
  for _, e in ipairs(roster.entries) do
    local n = text_of(crows, e.name_text) or ""
    B.name[e] = n
    B.key[e] = fold(n)
  end
  -- sorted by name, then base: plain string keys (key, NUL, base) sort without a Lua comparator
  local sort_keys, of_sort_key = {}, {}
  for _, e in ipairs(roster.entries) do
    if B.name[e] ~= "" then
      local k = B.key[e] .. "\0" .. string.format("%010d", e.base)
      sort_keys[#sort_keys + 1] = k
      of_sort_key[k] = e
    end
  end
  table.sort(sort_keys)
  B.sorted = {}
  for i, k in ipairs(sort_keys) do
    B.sorted[i] = of_sort_key[k]
  end
  bases[lang] = B
  return B
end

-- the language's state: names, the «Nombre» groups (spec: first letters of each group, split by «,»)
local function language(code, spec, other_label, special_label)
  local lang = lang_of(code)
  spec = tostring(spec or "")
  local L = names[lang]
  other_label = tostring(other_label or "#")
  special_label = tostring(special_label or "")
  if L and L.spec == spec and L.other == other_label and L.special == special_label then
    return L
  end
  local B = language_base(lang)
  local trows, srows, sorted = B.team_rows, B.series_rows, B.sorted
  L = { lang = lang, spec = spec, other = other_label, special = special_label, name = B.name, key = B.key, team_rows = trows, series_rows = srows }
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
    local first = L.key[e]:match("^" .. UTF8_CHAR)
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
  local special_list = {}
  for _, sp in ipairs(roster.specials) do
    L.name[sp] = L.name[sp.of] or ""
    if L.name[sp] ~= "" then
      special_list[#special_list + 1] = sp
    end
  end
  if #special_list > 0 then
    game_groups[#game_groups + 1] = { label = special_label, ty = 0, icon = special_icon(), list = special_list }
  end
  local team_groups = {}
  for _, t in ipairs(roster.teams) do
    local list = {}
    for _, e in ipairs(t.list) do
      if L.name[e] ~= "" then
        list[#list + 1] = e
      end
    end
    if #list > 0 then
      local label = t.team ~= 0 and text_of(trows, roster.cat.team_names[t.team]) or other_label
      team_groups[#team_groups + 1] = { label = label, name = label, list = list, si = t.si,
                                        emblem = t.team ~= 0 and Cat.team_emblem(roster.cat, t.team, t.ty) or 0 }
    end
  end
  -- a name several groups share: «team · game»
  local uses = {}
  for _, g in ipairs(team_groups) do
    uses[g.label] = (uses[g.label] or 0) + 1
  end
  for _, g in ipairs(team_groups) do
    if uses[g.label] > 1 then
      local game = text_of(srows, roster.cat.series[g.si].name_text)
      if game then g.label = g.label .. " · " .. game end
    end
  end
  L.groups = { name_groups, game_groups, team_groups }
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
function BetterQoL.Album.Open(code, spec, other_label, special_label)
  if ensure_roster() == nil then
    return false
  end
  local L = language(code, spec, other_label, special_label)
  local have = owned()
  view = L
  view_owned = have
  local out = { total = 0, owned = 0, groups = {} }
  for kind, gl in ipairs(L.groups) do
    local o = {}
    for i, g in ipairs(gl) do
      o[i] = { g.label, #g.list, count(g.list, have), g.ty or 0, g.emblem or 0, g.name or g.label, g.icon or "" }
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
  local have = view_owned or {}
  local level, rarity = shown_card()
  local out = { page = page, pages = pages, total = #g.list, owned = count(g.list, have), rows = {} }
  for k = 1, per do
    local e = g.list[(page - 1) * per + k]
    if e == nil then
      break
    end
    local o = have[e]
    local rar = e.special and e.rarity or rarity
    local source_series = e.si and roster.cat.series[e.si]
    local game_name_text = e.game_name_text or (source_series and source_series.name_text)
    out.rows[k] = { e.base, e.param, L.name[e], (e.team and text_of(L.team_rows, roster.cat.team_names[e.team]))
                      or "", (game_name_text and text_of(L.series_rows, game_name_text)) or "", o ~= nil,
                    level, rar, e.dress_team or 0 }
  end
  return out
end

-- ---------------------------------------------------------------------------------------------- start

ensure_roster()

-- a save load (behind the loading screen) builds the names of the game's language: the first opening only groups them
VRFW.on("slot_load", function()
  local ok, lang = pcall(VRFW.files.game_language)
  if ok and type(lang) == "string" and lang ~= "" and roster ~= nil and bases[lang] == nil then
    local okb, e = pcall(language_base, lang)
    if not okb then
      warn("names of " .. lang .. " not built at the save load (" .. tostring(e) .. ")")
    end
  end
end)
