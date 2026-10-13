-- Utilities › original names per player (docs/game/ui/original-names.md): which characters show their original
-- (Japanese / romaji) names, chosen player by player.
--
-- * The row: the game's settings row «Nombres de los personajes» (setting type 63; retail «Doblaje» / «Originales» =
--   the byte +0x7D of [[g_gameRoot]+0x6A50]) shows Doblaje / Por equipos / Originales (the hooks SettingRowRead /
--   SettingRowWrite at the end of this file); A opens the picker.
-- * The picker (graft util_original_names, CMND_UTIL_NAMES_PICK_*): a GRID OF TEAM EMBLEMS (the framework's
--   VRFW_EmblemGrid), one page per series of chara_series_config (Q / E), each tile «team» + «on/players»; A on a team
--   opens the team's PLAYER GRID (the faces, 10
--   a row: grey = dub name, normal colour = original name; A toggles a player, Y every player of the team). A series'
--   team rows: the belong_team_config rows numbered in the series' teamNumber_<X> column (k-th column = series type
--   k), then every other team a character of the series belongs to, then the team a mod's card_filters\ declaration
--   names for the series ([[bank_tab]] / [[series]]: series + team); a team without players is left out. A row's
--   players: the series' characters one of whose teams is the row's team.
-- * Team names: the game has no original team table; a team every player of which is chosen (and every team with
--   «Originales») gets its original name where content\original_names\teams.toml has it (Japanese name -> original).
-- * Storage: mod_options\utilities.json: names.c.<chara_base id, 8 hex> = 1 per chosen player, names.custom («Por
--   equipos»), names.format = 2. The game's own byte only ever holds 0 / 1. Utilities 1.3.0 - 1.5.x stored whole
--   series / teams (names.s.<series>, names.t.<series>.<team>, format 1): turned into their players once.
-- * The names are text tables the game loads (lib/original_names_tables): per language and selection a merged
--   chara_text / team_text served as a new key and the engine's opens redirected to it (the framework sets the
--   redirects again at the early phase of the next start, before the engine's boot text load); a saved change goes
--   back to the title like the retail «Originales» (CMND_UTIL_NAMES_RELOAD, asked by the graft when the settings
--   close).
--
-- Commands (content\game\original_names.toml): CMND_UTIL_NAMES_RELOAD / _ROW / _PICK_OPEN / _PICK_GRID / _PICK_TEAM_GRID / _PICK_TAB /
-- _PICK_ITEM / _PICK_TEAM / _PICK_PLAYER / _PICK_TOGGLE / _PICK_CLOSE.

local Cat = require "lib/original_names_catalogue"
local T = require "lib/original_names_tables"

Utilities = Utilities or {}
Utilities.OriginalNames = Utilities.OriginalNames or {}

local OPT_PREFIX, OPT_FORMAT, OPT_CUSTOM = "names.", "names.format", "names.custom"
local FORMAT = 2
-- Utilities 1.0.1 - 1.2.x: the global blob of «Solo Ares y Orión» and the removed row of the Ares / Orion team names
local LEGACY_BLOB, LEGACY_TEAM_OPTION = "original_names.json", "ares_orion_team_names"
local TEAMS_FILE = "content/original_names/teams.toml"
-- the game settings' character-name byte and text-language byte; the settings menu rows (docs/app/mod-options.md §7)
local SET_ROMAJI, SET_TEXT_LANG = 0x7D, 0x7C
local ROW_TYPE, ROW_VALUES = 63, 3
local IDX_DUB, IDX_CUSTOM, IDX_ORIGINAL = 0, 1, 2
local ROW_TYPE_OFF, ROW_LIST, ROW_INDEX, ROW_BASE = 0x08, 0x10, 0x1C, 0x20
local MENU_DRAFT_ROWS, MENU_ROW_SIZE, MENU_ROWS = 0x1E0, 0x28, 4 * 91
-- builds of other languages done per CMND_UTIL_NAMES_ROW call (each reads two text tables); CMND_UTIL_NAMES_RELOAD
-- builds none of them (it closes the settings: a hitch there was 65-95 ms), only the language the settings ask for
local PUMP_ROW = 1

local cfg = {
  legacy_series = { "Ares", "Orion" }, legacy_series_lang = "en", team_skip = { ja = true }, picker_reopen = false,
  log = true,
  -- the player grid (graft util_original_names): columns, rows a page, tile pitch / size (px), grid centre (screen
  -- px, y down), the colour of a player without his original name (gray_out material, 1 = normal), names under tiles
  grid = { cols = 10, rows = 4, pitch_x = 150, pitch_y = 180, tile = 132, cx = 960, cy = 560, grey = 0.38, names = true },
  -- the team grid (the framework's emblem grid): columns, rows a page, tile pitch (px), its centre (screen px, y down)
  team_grid = { cols = 8, rows = 3, pitch_x = 210, pitch_y = 236, cx = 960, cy = 520 },
}
local cat = nil            -- the catalogue (nil = off)
local langs, lang_set = {}, {}
local team_names = {}      -- Japanese team name -> original name
local ja_names = nil       -- team_text ja rows whose name has an original one: id -> variant -> name
local text_ids = {}        -- the text ids the picker shows (series + team names)
local outcomes = {}        -- "lang|kind|sig" -> served key | "" (nothing differs) | false (failed)
local pending = {}         -- builds of other languages: { lang, kind, sig, ids }
local queued = {}          -- "lang|kind|sig" -> true while in `pending` (queued once)
local loaded = {}          -- lang -> { chara = …, team = … } (lib/original_names_tables values)
local counts = {}          -- filter -> opens seen
local set_keys = {}        -- filter -> the key we redirect it to (false = the game's file)
local cur_lang = nil       -- the language of the last text load seen
local sig_cache, sig_cache_n = {}, 0
local all_sigs = nil
local migrated = false
local picker, pick_texts, pick_names = nil, {}, nil
-- mod_options\utilities.json as VRFW.options.values() read it (a file read + JSON decode per call: kept until this
-- script stores a value, the picker opens or the game goes back to the title) and the saved choices made of it
local opt_cache, saved_cache = nil, nil

local function opt_values()
  if opt_cache == nil then
    opt_cache = VRFW.options.values() or {}
  end
  return opt_cache
end

local function opt_forget()
  opt_cache, saved_cache = nil, nil
end

local function info(...) VRFW.log("original_names:", ...) end
local function warn(...) VRFW.warn("original_names:", ...) end

local function int(v)
  if type(v) ~= "number" then
    return nil
  end
  return v >= 0 and math.floor(v) or math.ceil(v)
end

local function rd(ty, addr)
  local ok, v = pcall(VRFW.mem.read, ty, addr)
  if ok then
    return v
  end
  return nil
end

-- what the settings row hooks know (hook:SettingRowRead / hook:SettingRowWrite at the end of this file): row_on (both
-- hooks in place), row_label (the row's label text id), menu (the settings menu object of the last draft row read), list
-- (our value list of the row)
local ROW = { row_on = 0, row_label = 0, menu = 0, list = 0 }

local function state_num(k)
  return ROW[k]
end

-- ------------------------------------------------------------------------------------------- config / game byte

local function load_cfg()
  local c = VRFW.files.config("original_names")
  if type(c) ~= "table" then
    return
  end
  if type(c.legacy_series) == "table" then
    cfg.legacy_series = c.legacy_series
  end
  if type(c.legacy_series_lang) == "string" then
    cfg.legacy_series_lang = c.legacy_series_lang
  end
  if type(c.team_skip_langs) == "table" then
    cfg.team_skip = {}
    for _, l in ipairs(c.team_skip_langs) do
      cfg.team_skip[tostring(l)] = true
    end
  end
  cfg.picker_reopen = c.picker_reopen == true
  cfg.log = c.log ~= false
  for _, part in ipairs({ "grid", "team_grid" }) do
    if type(c[part]) == "table" then
      for k, v in pairs(c[part]) do
        if cfg[part][k] ~= nil and type(v) == type(cfg[part][k]) then
          cfg[part][k] = v
        end
      end
    end
  end
end

local function settings()
  local ok, s = pcall(VRFW.game.game_settings)
  if not ok or type(s) ~= "number" or s < 0x10000 then
    return nil
  end
  return s
end

-- the game's «Originales» byte (false when the settings are not there yet)
local function romaji()
  local s = settings()
  local b = s and rd("u8", s + SET_ROMAJI)
  return type(b) == "number" and b ~= 0
end

local function row_index(rom, custom)
  if rom then
    return IDX_ORIGINAL
  elseif custom then
    return IDX_CUSTOM
  end
  return IDX_DUB
end

local VALUE_NAMES = { [IDX_DUB] = "Doblaje", [IDX_CUSTOM] = "Por equipos", [IDX_ORIGINAL] = "Originales" }

-- ------------------------------------------------------------------------------------------- the saved choices

local function hex_id(h)
  local id = h and tonumber(h, 16)
  if id and id <= 0xFFFFFFFF then
    return id
  end
  return nil
end

-- the saved values: custom, chosen = { [chara id] = true }, format, and a format-1 selection (legacy_series = { [series]
-- = true }, legacy_teams = { [series] = { [team] = true } }, legacy = any of them)
local function read_saved()
  local values = opt_values()
  local s = {
    format = tonumber(values[OPT_FORMAT]) or 0, custom = (tonumber(values[OPT_CUSTOM]) or 0) ~= 0, chosen = {},
    legacy_series = {}, legacy_teams = {}, legacy = false, values = values,
  }
  for k, v in pairs(values) do
    if type(k) == "string" and type(v) == "number" and v ~= 0 then
      local c = hex_id(k:match("^names%.c%.(%x+)$"))
      if c then
        s.chosen[c] = true
      else
        local id = hex_id(k:match("^names%.s%.(%x+)$"))
        if id then
          s.legacy_series[id], s.legacy = true, true
        else
          local a, b = k:match("^names%.t%.(%x+)%.(%x+)$")
          a, b = hex_id(a), hex_id(b)
          if a and b then
            s.legacy_teams[a] = s.legacy_teams[a] or {}
            s.legacy_teams[a][b], s.legacy = true, true
          end
        end
      end
    end
  end
  return s
end

-- (cached: read-only for the callers; the next store / picker / title reads it again)
local function saved()
  if saved_cache == nil then
    local s = read_saved()
    if cat then
      s.chosen = Cat.normalize(cat, s.chosen)
    end
    saved_cache = s
  end
  return saved_cache
end

-- the choices into mod_options\utilities.json (every older names.* key replaced; the other values kept)
local function store(custom, chosen)
  local ch = {}
  for k in pairs(VRFW.options.values()) do
    if type(k) == "string" and k:sub(1, #OPT_PREFIX) == OPT_PREFIX then
      ch[k] = false
    end
  end
  ch[OPT_FORMAT] = FORMAT
  ch[OPT_CUSTOM] = custom and 1 or 0
  for id in pairs(chosen) do
    ch[string.format("names.c.%08x", id)] = 1
  end
  local ok, why = VRFW.options.store(ch)
  opt_forget()
  return ok, why
end

-- text ids and signatures of a selection (cached: the catalogue does not change while the game runs)
local function sigs(chosen)
  -- the saved choices' table never changes once made (saved()): its signatures are kept on it
  local sv = saved_cache
  if sv ~= nil and chosen == sv.chosen and sv.sg ~= nil then
    return sv.sg
  end
  local k = Cat.sel_key(chosen)
  local c = sig_cache[k]
  if c then
    if sv ~= nil and chosen == sv.chosen then
      sv.sg = c
    end
    return c
  end
  local cids, n = Cat.chara_name_ids(cat, chosen)
  local tids = Cat.team_name_ids(cat, chosen, false)
  c = { chara_ids = cids, chara_sig = T.ids_sig(cids), team_ids = tids, team_sig = T.ids_sig(tids), n = n }
  if sig_cache_n >= 16 then
    sig_cache, sig_cache_n = {}, 0
  end
  sig_cache[k], sig_cache_n = c, sig_cache_n + 1
  if sv ~= nil and chosen == sv.chosen then
    sv.sg = c
  end
  return c
end

local function selection_text(chosen)
  local sg = sigs(chosen)
  return string.format("%d player(s), %d full team(s)", sg.n, #sg.team_ids)
end

-- ------------------------------------------------------------------------------------------- the builds

local function okey(lang, kind, sig)
  return lang .. "|" .. kind .. "|" .. sig
end

-- the table of (lang, kind, sig) built and served: its key, "" = no name differs (the game's table is right), nil + why
local function build_one(lang, kind, sig, ids)
  if not lang_set[lang] then
    return ""
  end
  local tbl, over, n = T.CHARA, nil, 0
  if kind == "chara" then
    local dub, e1 = VRFW.files.text_rows(T.text_key(lang, T.CHARA))
    if not dub then
      return nil, e1
    end
    local roma, e2 = VRFW.files.text_rows(T.text_key(lang, T.ROMA))
    if not roma then
      return nil, e2
    end
    over, n = T.chara_overrides(dub, roma, ids)
  else
    tbl = T.TEAM
    if cfg.team_skip[lang] or ja_names == nil or next(team_names) == nil then
      return ""
    end
    local rows, e = VRFW.files.text_rows(T.text_key(lang, T.TEAM))
    if not rows then
      return nil, e
    end
    over, n = T.team_overrides(ja_names, rows, ids, team_names)
  end
  if n == 0 then
    return ""
  end
  local key = T.served_key(lang, tbl, sig)
  local changed, why = VRFW.files.serve_text(key, T.text_key(lang, tbl), over)
  if changed == nil then
    return nil, why
  end
  if changed == 0 then
    return ""
  end
  info(string.format("%s %s: table %s served (%d row(s) changed)", lang, kind == "chara" and "characters" or "teams", sig, changed))
  return key
end

local function ensure(lang, kind, sig, ids)
  local k = okey(lang, kind, sig)
  local o = outcomes[k]
  if o ~= nil then
    return o
  end
  local ok, r, why = pcall(build_one, lang, kind, sig, ids)
  if not ok then
    r, why = nil, r
  end
  if r == nil then
    warn(lang, kind == "chara" and "characters" or "teams", tostring(why))
    o = false
  else
    o = r
  end
  outcomes[k] = o
  return o
end

-- every language's table of (kind, sig): `first` now, the others queued (or all now when `now`)
local function want_all(kind, sig, ids, first, now)
  if not sig then
    return
  end
  for _, l in ipairs(langs) do
    local k = okey(l, kind, sig)
    if outcomes[k] == nil then
      if now or l == first then
        ensure(l, kind, sig, ids)
      elseif not queued[k] then
        queued[k] = true
        pending[#pending + 1] = { l, kind, sig, ids }
      end
    end
  end
end

local function pump(n)
  while n > 0 and #pending > 0 do
    local j = table.remove(pending, 1)
    local k = okey(j[1], j[2], j[3])
    queued[k] = nil
    if outcomes[k] == nil then
      ensure(j[1], j[2], j[3], j[4])
      n = n - 1
    end
  end
end

-- the tables the saved choices want (every team's names too: «Originales» shows them); `any` = the «Por equipos»
-- tables too while that value is not chosen (the start builds them, so choosing it later builds nothing then)
local function want_saved(s, first, now, any)
  local sg = sigs(s.chosen)
  want_all("team", all_sigs.team_sig, all_sigs.team_ids, first, now)
  if s.custom or (any and next(s.chosen) ~= nil) then
    want_all("chara", sg.chara_sig, sg.chara_ids, first, now)
    if sg.team_sig ~= all_sigs.team_sig then
      want_all("team", sg.team_sig, sg.team_ids, first, now)
    end
  end
end

-- ------------------------------------------------------------------------------------------- the engine's opens

-- the opens since the last look: what each language loaded, and the current language
local function poll()
  local seen = false
  for _, l in ipairs(langs) do
    local lo = loaded[l]
    local fc, fr, ft = T.filter(l, T.CHARA), T.filter(l, T.ROMA), T.filter(l, T.TEAM)
    local lc, nc = VRFW.files.opened(fc)
    local _, nr = VRFW.files.opened(fr)
    local lt, nt = VRFW.files.opened(ft)
    nc, nr, nt = nc or 0, nr or 0, nt or 0
    local dc, dr, dt = nc > (counts[fc] or 0), nr > (counts[fr] or 0), nt > (counts[ft] or 0)
    counts[fc], counts[fr], counts[ft] = nc, nr, nt
    if dc and dr then
      -- two text loads since the last look: the game's byte says which one is the last
      if romaji() then
        dc = false
      else
        dr = false
      end
    end
    if dr then
      lo.chara = T.ROMAJI
    elseif dc and lc ~= nil then
      lo.chara = lc == "" and T.DUB or (T.sig_of_key(lc) or T.DUB)
    end
    if dt and lt ~= nil then
      lo.team = lt == "" and T.DUB or (T.sig_of_key(lt) or T.DUB)
    end
    if dc or dr or dt then
      cur_lang, seen = l, true
    end
  end
  if seen and cfg.log then
    local lo = loaded[cur_lang]
    info(string.format("texts loaded (%s): character names %s, team names %s", cur_lang, T.loaded_name(lo.chara), T.loaded_name(lo.team)))
  end
end

local redirect_said = {}

local function redirect(filter, key)
  local want = key or false
  if set_keys[filter] == want then
    return
  end
  local ok, why = VRFW.files.redirect(filter, key)
  if ok then
    set_keys[filter] = want
  elseif not redirect_said[filter] then
    redirect_said[filter] = true
    warn("redirect of", filter, "refused:", tostring(why), "(those names stay the game's)")
  end
end

local function served(lang, kind, sig)
  if not sig then
    return nil
  end
  local o = outcomes[okey(lang, kind, sig)]
  if o and o ~= "" then
    return o
  end
  return nil
end

-- the engine's next opens of chara_text / team_text get the tables the choices want (the opens seen first: a changed
-- redirect forgets its last answer)
local function apply_redirects()
  poll()
  local rom = romaji()
  local s = saved()
  local sg = sigs(s.chosen)
  local tw = T.team_wanted(rom, s.custom, sg.team_sig, all_sigs.team_sig)
  for _, l in ipairs(langs) do
    redirect(T.filter(l, T.CHARA), s.custom and served(l, "chara", sg.chara_sig) or nil)
    redirect(T.filter(l, T.ROMA), nil)
    redirect(T.filter(l, T.TEAM), tw ~= T.DUB and served(l, "team", tw) or nil)
  end
  return s, sg, rom
end

-- ------------------------------------------------------------------------------------------- migration

-- once (names.format below 2): Utilities 1.3.0 - 1.5.x series / team ticks -> their players; 1.0.1 - 1.2.x «Solo Ares
-- y Orión» (global blob) -> «Por equipos» with the players of the series of [original_names] legacy_series; the
-- removed row of the Ares / Orion team names is reported
local function migrate()
  if migrated then
    return
  end
  local s = read_saved()
  if s.format >= FORMAT then
    migrated = true
    return
  end
  local old = false
  if s.format < 1 then
    local blob, why = VRFW.save.blob(LEGACY_BLOB, "global")
    if blob == nil and why ~= nil then
      return -- the save store is not ready: asked again later
    end
    if type(blob) == "string" then
      local ok, v = pcall(VRFW.json.decode, blob)
      old = ok and type(v) == "table" and v.ares_orion == true
    end
  end
  migrated = true
  local chosen = Cat.normalize(cat, s.chosen)
  local n_legacy = 0
  if s.legacy then
    for id in pairs(Cat.legacy_chosen(cat, s.legacy_series, s.legacy_teams)) do
      chosen[id] = true
      n_legacy = n_legacy + 1
    end
  end
  if old then
    local names = VRFW.files.text_rows(T.text_key(cfg.legacy_series_lang, T.SERIES_TEXT)) or {}
    local series = {}
    for _, id in ipairs(Cat.series_by_words(cat, names, cfg.legacy_series)) do
      series[id] = true
    end
    for id in pairs(Cat.legacy_chosen(cat, series, {})) do
      chosen[id] = true
    end
  end
  local custom = s.custom or (old and next(chosen) ~= nil)
  local ok, e = store(custom, chosen)
  if not ok then
    warn("migration not saved (" .. tostring(e) .. ")")
    return
  end
  if s.legacy then
    info(string.format("series / team ticks of Utilities 1.3 - 1.5 -> %d player(s) (saved per player)", n_legacy))
  end
  if old then
    info("migrated «Solo Ares y Orión» -> «Por equipos» with " .. selection_text(chosen) .. " (applies from the next text reload: the title, or the next start)")
  end
  if (tonumber(s.values[LEGACY_TEAM_OPTION]) or 0) ~= 0 then
    info("the row «Nombres originales para equipos internacionales de Ares y Orión» is gone: a team whose players are all chosen shows its original name (Opciones › Ajustes del juego › «Nombres de los personajes», A)")
  end
  if s.legacy or old then
    want_saved(saved(), nil, false)
  end
end

-- ------------------------------------------------------------------------------------------- the picker

-- the text language folder of a CMND_GET_LANGUAGE_CODE code (else the last text load's, else the settings' text
-- language byte, else en)
-- the text language folder of a CMND_GET_LANGUAGE_CODE code (nil: none of ours)
local function lang_by_code(c)
  if c and c >= 0 and type(VRFW.files.game_languages) == "function" then
    local ok, t = pcall(VRFW.files.game_languages)
    local l = ok and type(t) == "table" and t[c + 1] or nil
    if type(l) == "string" and lang_set[l] then
      return l
    end
  end
  return nil
end

local function lang_of(code)
  local of = lang_by_code
  local l = of(int(code))
  if l then
    return l
  end
  poll()
  if cur_lang then
    return cur_lang
  end
  local s = settings()
  l = s and of(rd("u8", s + SET_TEXT_LANG))
  if l then
    return l
  end
  return lang_set.en and "en" or (langs[1] or "en")
end

-- names of the pages and teams in `lang` (text id -> text, furigana reduced; team_text first)
local function texts_for(lang)
  local out = {}
  for _, tbl in ipairs({ T.TEAM, T.SERIES_TEXT }) do
    local rows = VRFW.files.text_rows(T.text_key(lang, tbl))
    if rows then
      for id in pairs(text_ids) do
        if out[id] == nil then
          local r = rows[id]
          local s = r and r[0]
          if type(s) == "string" then
            out[id] = T.strip_furigana(s)
          end
        end
      end
    end
  end
  return out
end

local function name_of(id)
  local s = pick_texts[id]
  if type(s) == "string" and s ~= "" then
    return s
  end
  return string.format("0x%08X", id)
end

-- a character's name in `rows` (chara_text / chara_text_roma of the picker's language), furigana reduced
local function chara_name(rows, c)
  local r = rows and rows[c[1]]
  local s = r and r[0]
  if type(s) == "string" and s ~= "" then
    return T.strip_furigana(s)
  end
  return ""
end

-- the names row among the draft rows of the open settings menu (type 63 with our value list)
local function draft_row()
  local menu, list = state_num("menu"), state_num("list")
  if not menu or menu < 0x10000 or not list or list == 0 then
    return nil
  end
  for i = 0, MENU_ROWS - 1 do
    local r = menu + MENU_DRAFT_ROWS + i * MENU_ROW_SIZE
    if rd("u32", r + ROW_TYPE_OFF) == ROW_TYPE and rd("ptr", r + ROW_LIST) == list then
      return r
    end
  end
  return nil
end

-- the row's draft after the picker closed: nil = leave it (a non-empty selection chooses «Por equipos», an emptied
-- one turns «Por equipos» back to «Doblaje»)
local function draft_after_pick(empty, current)
  if not empty then
    return current ~= IDX_CUSTOM and IDX_CUSTOM or nil
  end
  return current == IDX_CUSTOM and IDX_DUB or nil
end

local function cur_rows()
  local s = picker and cat.series[picker.page]
  return s and Cat.rows(cat, s) or {}, s
end

-- ------------------------------------------------------------------------------------------- commands

-- CMND_UTIL_NAMES_ROW() -> the label text id of the names row (false: the row is not extended)
function Utilities.OriginalNames.Row()
  if not cat then
    return false
  end
  migrate()
  pump(PUMP_ROW)
  local on, label = state_num("row_on"), state_num("row_label")
  if on == 1 and label and label ~= 0 then
    return label
  end
  return false
end

-- CMND_UTIL_NAMES_PICK_OPEN(lang code) -> pages (series), current page (1-based), reopen after each tick; 0 = no picker
function Utilities.OriginalNames.PickOpen(code)
  if not cat or #cat.series == 0 then
    return 0
  end
  opt_forget()
  migrate()
  local lang = lang_of(code)
  pick_texts = texts_for(lang)
  pick_names = { dub = VRFW.files.text_rows(T.text_key(lang, T.CHARA)), roma = VRFW.files.text_rows(T.text_key(lang, T.ROMA)) }
  picker = Cat.picker(cat, saved().chosen)
  info(string.format("picker opened (%s): %d page(s), %d player(s) chosen", lang, #cat.series, Cat.count(picker.chosen)))
  return #cat.series, picker.page, cfg.picker_reopen
end

-- CMND_UTIL_NAMES_PICK_GRID() -> the player grid's layout: cols, rows, pitch x, pitch y, tile, centre x, centre y
-- (screen px, y down), grey level, names under the tiles
function Utilities.OriginalNames.PickGrid()
  local g = cfg.grid
  return g.cols, g.rows, g.pitch_x, g.pitch_y, g.tile, g.cx, g.cy, g.grey, g.names == true
end

-- CMND_UTIL_NAMES_PICK_TEAM_GRID() -> the team grid's layout: cols, rows, pitch x, pitch y, centre x, centre y
function Utilities.OriginalNames.PickTeamGrid()
  local g = cfg.team_grid
  return g.cols, g.rows, g.pitch_x, g.pitch_y, g.cx, g.cy
end

-- CMND_UTIL_NAMES_PICK_TAB(dir) -> page (1-based), the series' name, its players chosen, its players, its team rows
function Utilities.OriginalNames.PickTab(dir)
  if not cat or not picker then
    return false
  end
  local d = int(dir) or 0
  d = d < -1 and -1 or (d > 1 and 1 or d)
  if d ~= 0 then
    Cat.step_page(cat, picker, d)
  end
  local rows, s = cur_rows()
  if not s then
    return false
  end
  local on, n = Cat.page_counts(cat, picker)
  return picker.page, name_of(s.name_text), on, n, #rows
end

-- CMND_UTIL_NAMES_PICK_ITEM(i) -> team row i (1-based) of the page: its name, players chosen, players, its emblem
-- (item_emblem id of the page's era, 0 = none)
function Utilities.OriginalNames.PickItem(i)
  if not cat or not picker then
    return false
  end
  local rows, s = cur_rows()
  local r = rows[int(i) or 0]
  if not r then
    return false
  end
  local nm = cat.team_names[r.team]
  local on, n = Cat.players_on(cat, r.players, picker.chosen)
  return nm and name_of(nm) or string.format("0x%08X", r.team), on, n, Cat.team_emblem(cat, r.team, s.ty)
end

-- CMND_UTIL_NAMES_PICK_TEAM(i) -> opens team row i for the grid: players, players chosen, the team's name
function Utilities.OriginalNames.PickTeam(i)
  if not cat or not picker then
    return false
  end
  i = int(i) or 0
  local r = cur_rows()[i]
  if not r then
    return false
  end
  picker.row = i
  local nm = cat.team_names[r.team]
  local on, n = Cat.players_on(cat, r.players, picker.chosen)
  return n, on, nm and name_of(nm) or string.format("0x%08X", r.team)
end

-- CMND_UTIL_NAMES_PICK_PLAYER(j) -> player j (1-based) of the open team: chara_base key (face icon), chosen, dub name,
-- original name
function Utilities.OriginalNames.PickPlayer(j)
  if not cat or not picker then
    return false
  end
  local r = cur_rows()[picker.row]
  local ci = r and r.players[int(j) or 0]
  if not ci then
    return false
  end
  local c = cat.charas[ci]
  local dub = chara_name(pick_names and pick_names.dub, c)
  local orig = chara_name(pick_names and pick_names.roma, c)
  return c[8], picker.chosen[c[8]] == true, dub, orig ~= "" and orig or dub
end

-- CMND_UTIL_NAMES_PICK_TOGGLE(j) -> player j of the open team toggled (0 = every player: all on, or all off when all
-- are on): the new state, players chosen, players
function Utilities.OriginalNames.PickToggle(j)
  if not cat or not picker then
    return false
  end
  j = int(j)
  if not j or j < 0 then
    return false
  end
  return Cat.toggle(cat, picker, j)
end

-- CMND_UTIL_NAMES_PICK_CLOSE() -> changed, the row's new draft index (-1 = unchanged), its value text id, is it the
-- last value (for the script's SetSelectIsChangeToRomaji). Saves the selection and sets the row's draft.
function Utilities.OriginalNames.PickClose()
  local p = picker
  picker, pick_texts, pick_names = nil, {}, nil
  if not cat or not p then
    return false, -1, 0, false
  end
  if not Cat.changed(p) then
    info("picker closed: no change")
    return false, -1, 0, false
  end
  local s = saved()
  local ok, why = store(s.custom, p.chosen)
  if ok then
    info("picker closed: " .. selection_text(p.chosen) .. " (saved)")
  else
    warn("picker: selection not saved (" .. tostring(why) .. ")")
  end
  -- the new selection's tables («Por equipos» may be chosen next): the current language now, the others later
  poll()
  local sg = sigs(p.chosen)
  want_all("chara", sg.chara_sig, sg.chara_ids, cur_lang, false)
  if sg.team_sig ~= all_sigs.team_sig then
    want_all("team", sg.team_sig, sg.team_ids, cur_lang, false)
  end
  apply_redirects()
  local row = draft_row()
  local cur = row_index(romaji(), s.custom)
  if row then
    local idx, base = rd("i32", row + ROW_INDEX), rd("i32", row + ROW_BASE)
    if type(idx) == "number" and type(base) == "number" then
      cur = math.max(idx + base, 0)
    end
  end
  local new = draft_after_pick(next(p.chosen) == nil, cur)
  if not new then
    return true, -1, 0, false
  end
  if not row then
    warn("picker: the settings row was not found: choose «Por equipos» with ←/→")
    return true, -1, 0, false
  end
  local base = rd("i32", row + ROW_BASE) or 0
  if not pcall(VRFW.mem.write, "i32", row + ROW_INDEX, new - base) then
    warn("picker: the settings row was not written: choose «Por equipos» with ←/→")
    return true, -1, 0, false
  end
  local list = rd("ptr", row + ROW_LIST)
  local text = (type(list) == "number" and list >= 0x10000) and rd("u32", list + 4 * new) or 0
  info(string.format("«Nombres de los personajes» (draft): %s -> %s", VALUE_NAMES[cur] or tostring(cur), VALUE_NAMES[new]))
  return true, new, text or 0, new + 1 == ROW_VALUES
end

-- CMND_UTIL_NAMES_RELOAD([lang code]) -> bool: the loaded names tables no longer match the saved choices, so the
-- settings script takes the retail «Originales» path (back to the title, texts reloaded). The tables of the current
-- language are built first (here), and the engine's opens redirected to them, so the reload finds them. A table the
-- engine loaded before the redirects existed (no open seen) is the game's own: dub (or the retail romaji one).
function Utilities.OriginalNames.Reload(code)
  if not cat then
    return false
  end
  migrate()
  poll()
  local lang = cur_lang or lang_of(code)
  local s = saved()
  -- the language the settings now ask for (changed in this menu: the reload loads it) built now; the other
  -- languages stay queued (CMND_UTIL_NAMES_ROW builds them one a call)
  local target = lang_by_code(int(code))
  want_saved(s, target or lang, false)
  local rom = romaji()
  local sg = sigs(s.chosen)
  local function effective(kind, want, ids)
    if want == T.DUB or want == T.ROMAJI then
      return want
    end
    if lang and served(lang, kind, want) == nil then
      ensure(lang, kind, want, ids)
    end
    if lang and served(lang, kind, want) then
      return want
    end
    return T.DUB
  end
  local cw = effective("chara", T.chara_wanted(rom, s.custom, sg.chara_sig), sg.chara_ids)
  local tw = T.team_wanted(rom, s.custom, sg.team_sig, all_sigs.team_sig)
  tw = effective("team", tw, rom and all_sigs.team_ids or sg.team_ids)
  apply_redirects()
  if not lang or not loaded[lang] then
    return false
  end
  local lo = loaded[lang]
  local lc = lo.chara ~= T.UNKNOWN and lo.chara or (rom and T.ROMAJI or T.DUB)
  local lt = lo.team ~= T.UNKNOWN and lo.team or T.DUB
  local rc, rt = T.reload_needed(rom, cw, lc, tw, lt)
  if rc or rt then
    info(string.format("names to reload (%s): characters loaded %s / wanted %s, teams loaded %s / wanted %s: back to the title, the game reloads its texts (as with «Originales»)",
      lang, T.loaded_name(lc), T.loaded_name(cw), T.loaded_name(lt), T.loaded_name(tw)))
  end
  return rc or rt
end

-- ------------------------------------------------------------------------------------------- start

local function start()
  load_cfg()
  local ok, err = pcall(function()
    local series = Cat.series_rows()
    local belong = Cat.belong_rows()
    local charas = Cat.charas()
    local decls = Cat.declarations()
    cat = Cat.build(series, belong, charas, decls)
    local nt = 0
    for _, s in ipairs(cat.series) do
      nt = nt + #s.teams
    end
    info(string.format("%d series tab(s), %d team(s), %d character(s); %d series / team pair(s) declared by mods' card filters", #cat.series, nt, #cat.charas, #decls))
  end)
  if not ok then
    cat = nil
    warn("no catalogue (" .. tostring(err) .. "): the game's names, no picker")
    return
  end
  for _, s in ipairs(cat.series) do
    text_ids[s.name_text] = true
    for _, t in ipairs(s.teams) do
      local n = cat.team_names[t]
      if n then
        text_ids[n] = true
      end
    end
  end
  langs = VRFW.files.languages() or {}
  for _, l in ipairs(langs) do
    lang_set[l] = true
    loaded[l] = { chara = T.UNKNOWN, team = T.UNKNOWN }
  end
  -- the original team names, keyed by the Japanese name (only the ja rows that have one are kept)
  local doc, why = VRFW.files.toml(TEAMS_FILE)
  local n_names = 0
  if doc then
    team_names, n_names = T.team_names(doc)
  else
    warn(tostring(why) .. ": no original team names")
  end
  if n_names > 0 then
    local ja = VRFW.files.text_rows(T.text_key("ja", T.TEAM))
    ja_names = {}
    for id, r in pairs(ja or {}) do
      for var, s in pairs(r) do
        local nm = T.strip_furigana(s)
        if team_names[nm] then
          ja_names[id] = ja_names[id] or {}
          ja_names[id][var] = nm
        end
      end
    end
  end
  -- «Originales»: every team's original name
  local all_team = Cat.team_name_ids(cat, {}, true)
  all_sigs = { team_ids = all_team, team_sig = T.ids_sig(all_team) }
  migrate()
  local s = saved()
  info("saved: " .. (s.custom and "«Por equipos»" or "not «Por equipos»") .. ", " .. selection_text(s.chosen))
  -- every language's tables of the saved choices now (the engine may load the texts at any moment from here on), the
  -- «Por equipos» ones too when that value is not chosen (a later CMND_UTIL_NAMES_RELOAD then only redirects)
  want_saved(s, nil, true, true)
  apply_redirects()
  info("the engine's opens of chara_text / team_text (" .. #langs .. " language(s)) are redirected to the chosen tables")
end

-- ------------------------------------------------------------------------------------------- the settings row
-- The game's «Nombres de los personajes» row (setting type 63; retail «Doblaje» / «Originales» = the game byte +0x7D)
-- gets the middle value «Por equipos»: after the engine read the row (hook:SettingRowRead:post) its value list becomes
-- ours (three text ids, «Originales» stays the LAST value so the engine's own «last value = original names» keeps its
-- meaning) and its index shows the current state; when the engine writes it (hook:SettingRowWrite) «Por equipos» is
-- stored as the retail «Doblaje» (the game's byte and save only ever hold 0 / 1: the save works without the mod) and
-- names.custom records it.

local ROW_TYPE = 63
local ROW_LABEL_OFF, ROW_TYPE_OFF, ROW_LIST, ROW_COUNT, ROW_INDEX, ROW_BASE = 0x00, 0x08, 0x10, 0x18, 0x1C, 0x20
local MENU_DRAFT_ROWS, MENU_APPLIED_ROWS, MENU_ROW_SIZE = 0x1E0, 0x3AC0, 0x28
local ROW_VALUE_KEY = "utilities.names_by_team"

local function wr(ty, addr, v)
  return pcall(VRFW.mem.write, ty, addr, v)
end

local function saved_custom()
  return (tonumber(opt_values()[OPT_CUSTOM]) or 0) ~= 0
end

local function is_draft_row(menu, row)
  return row >= menu + MENU_DRAFT_ROWS and row < menu + MENU_APPLIED_ROWS and (row - menu - MENU_DRAFT_ROWS) % MENU_ROW_SIZE == 0
end

-- our value list for a row whose retail list is at `list` (2 values), built once in a buffer of the mod
local function our_list(list)
  if ROW.list ~= 0 then
    return ROW.list
  end
  local a, b = rd("u32", list), rd("u32", list + 4)
  if not a or not b then
    return nil
  end
  local ours = VRFW.ui.crc32(ROW_VALUE_KEY)
  local p = VRFW.mem.buffer("names_row_values", 12)
  wr("u32", p, a)
  wr("u32", p + 4, ours)
  wr("u32", p + 8, b)
  ROW.list = p
  info(string.format("«Nombres de los personajes»: values %08X / %08X (%s) / %08X", a, ours, ROW_VALUE_KEY, b))
  return p
end

ROW.row_on = (VRFW.is_on("SettingRowRead") and VRFW.is_on("SettingRowWrite")) and 1 or 0
if ROW.row_on == 1 then
  info("«Nombres de los personajes» row: Doblaje / Por equipos / Originales (saved: " .. (saved_custom() and "Por equipos" or "the game's") .. ")")
else
  warn("settings row not extended (hooks SettingRowRead / SettingRowWrite off): «Nombres de los personajes» keeps its two values, no picker")
end

-- after the engine read the row: our three values, and the index of the current state
VRFW.on("hook:SettingRowRead:post", function(ev)
  local menu, row = ev.args[1], ev.args[2]
  if ROW.row_on ~= 1 or row < 0x10000 or rd("u32", row + ROW_TYPE_OFF) ~= ROW_TYPE then
    return nil
  end
  local list, count = rd("ptr", row + ROW_LIST), rd("u16", row + ROW_COUNT)
  if not list or not count then
    return nil
  end
  if list ~= ROW.list or ROW.list == 0 then
    if count ~= 2 then
      return nil -- not the retail two values: leave it
    end
    local p = our_list(list)
    if not p then
      return nil
    end
    wr("ptr", row + ROW_LIST, p)
    wr("u16", row + ROW_COUNT, 3)
  end
  ROW.row_label = rd("u32", row + ROW_LABEL_OFF) or ROW.row_label
  if is_draft_row(menu, row) then
    ROW.menu = menu
  end
  local base = rd("i32", row + ROW_BASE) or 0
  wr("i32", row + ROW_INDEX, row_index(romaji(), saved_custom()) - base)
  return nil
end)

-- the engine writes the row: «Por equipos» -> the retail «Doblaje», the index put back right after
local pending_write

VRFW.on("hook:SettingRowWrite", function(ev)
  pending_write = nil
  local row = ev.args[2]
  if row < 0x10000 or ROW.list == 0 or rd("u32", row + ROW_TYPE_OFF) ~= ROW_TYPE then
    return nil
  end
  local i, base = rd("i32", row + ROW_INDEX), rd("i32", row + ROW_BASE)
  if not i or not base then
    return nil
  end
  local was = saved_custom()
  local chosen = math.max(i + base, 0)
  local retail = (chosen == IDX_ORIGINAL) and 1 or 0
  wr("i32", row + ROW_INDEX, retail - base)
  pending_write = { row = row, i = i, before = row_index(romaji(), was), chosen = chosen, was = was, ours = chosen == IDX_CUSTOM, retail = retail }
  return nil
end)

VRFW.on("hook:SettingRowWrite:post", function(ev)
  local w = pending_write
  pending_write = nil
  if not w then
    return nil
  end
  wr("i32", w.row + ROW_INDEX, w.i)
  if w.before ~= w.chosen then
    info(string.format("«Nombres de los personajes»: %s -> %s (the game stores «%s»)", VALUE_NAMES[w.before] or "?", VALUE_NAMES[w.chosen] or "?", w.retail == 1 and "Originales" or "Doblaje"))
  end
  if w.was ~= w.ours then
    local ok, why = VRFW.options.store({ [OPT_CUSTOM] = w.ours and 1 or 0 })
    opt_forget()
    if ok then
      info("«Por equipos» " .. (w.ours and "chosen" or "off") .. " (saved)")
    else
      warn("«Por equipos» " .. (w.ours and "chosen" or "off") .. ": not saved (" .. tostring(why) .. ")")
    end
  end
  return nil
end)

-- back to the title: mod_options\utilities.json read again (the Mods screen may have changed it)
VRFW.on("game_reset", function()
  opt_forget()
  return nil
end)

start()
