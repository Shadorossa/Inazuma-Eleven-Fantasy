-- Utilities › team planner («Planificador de equipo», docs/game/ui/team-planner.md): ghost cards in the team dock's
-- squads, like the squad planners of FIFA Ultimate Team.
--
-- * The menu side (graft research/grafts/util_team_planner): A on an empty slot of a squad («Formación» of the team
--   dock) offers «Añadir del banco» (the game's bank) and «Planificar equipo»: the picker (series pages -> team rows ->
--   the team's cards) lists every character of the game and of the mods once (his normal card), drawn at the display
--   rarity, the ones the save does not own semi-transparent; the chosen one becomes a GHOST in the slot (drawn
--   semi-transparent over the empty slot; never a card, never in the bank, never playable).
-- * This script: the catalogue (the original-names catalogue of series / teams / characters + each character's card
--   param from chara_param), the rule (config.toml [team_planner] + other mods' content\team_planner\*.toml), the owned
--   copies (VRFW.chara.saved / record), the plans (blob team_planner.json per save slot) and the commands below.
-- * Automatic assignment: the menu side asks the qualifying copies of a ghost's character (CMND_UTIL_TP_CANDIDATES)
--   when the dock opens, places one with the game's own placement and reports it (CMND_UTIL_TP_ASSIGNED).
--
-- Commands (content\game\team_planner.toml): CMND_UTIL_TP_INFO / _LIST / _SET / _CANDIDATES / _ASSIGNED / _PENDING /
-- _PICK_OPEN / _PICK_GRID / _PICK_TAB / _PICK_ITEM / _PICK_TEAM / _PICK_PLAYER.

local C = require "lib/tp_core"
local Cat = require "lib/original_names_catalogue"
local T = require "lib/original_names_tables"

Utilities = Utilities or {}
Utilities.TeamPlanner = Utilities.TeamPlanner or {}
local TP = Utilities.TeamPlanner

-- other mods' rule (schema utilities.team_planner/1): content\team_planner\*.toml of each mod
local DECL_PATHS = { "content/team_planner", "team_planner" }
local KEY_MOUNTED = "utilities.team_banks.mounted"
local OWNED_TTL_MS = 2000

local function info(...) VRFW.log("team_planner:", ...) end
local function warn(...) VRFW.warn("team_planner:", ...) end

local int, u32 = C.int, C.u32

-- ---------------------------------------------------------------------------------------- settings

local cfg = {
  enabled = true,
  ghost_alpha = 0.45,
  -- the picker's card grid (layer util_tp_card of soccer_formation_menu): cards a row, rows a page, pitch (px), card
  -- scale, the grid's centre (screen px, y down), the card's centre from its layer origin (px at scale 1, y down)
  grid = { cols = 8, rows = 2, pitch_x = 215, pitch_y = 260, scale = 1.35, cx = 960, cy = 560, ox = 0, oy = 0 },
  -- the picker's team grid (the framework's emblem grid, layers util_tp_emblem / util_tp_label): tiles a row, rows a
  -- page, pitch (px), the grid's centre (screen px, y down)
  team_grid = { cols = 8, rows = 3, pitch_x = 210, pitch_y = 236, cx = 960, cy = 520 },
}
local rule = nil
local catalogue = nil     -- { cat = original-names catalogue, card = { [chara_base] = param }, rows = { [series] = … } }

local function load_cfg()
  local ok, c = pcall(VRFW.files.config, "team_planner")
  if not ok or type(c) ~= "table" then
    c = nil
  end
  if c then
    if type(c.enabled) == "boolean" then
      cfg.enabled = c.enabled
    end
    if type(c.ghost_alpha) == "number" and c.ghost_alpha > 0 and c.ghost_alpha <= 1 then
      cfg.ghost_alpha = c.ghost_alpha
    end
    if type(c.team_grid) == "table" then
      for k, v in pairs(c.team_grid) do
        if cfg.team_grid[k] ~= nil and type(v) == "number" then
          cfg.team_grid[k] = v
        end
      end
    end
    if type(c.grid) == "table" then
      for k, v in pairs(c.grid) do
        if cfg.grid[k] ~= nil and type(v) == "number" then
          cfg.grid[k] = v
        end
      end
    end
  end
  local okd, decls = pcall(VRFW.files.declarations, DECL_PATHS)
  local notes = {}
  rule = C.rule(c, okd and decls or {}, notes)
  for _, n in ipairs(notes) do
    warn(n)
  end
  info("rule (" .. rule.source .. "): " .. C.rule_sig(rule))
end

-- ---------------------------------------------------------------------------------------- the catalogue

local function build_catalogue()
  local ok, err = pcall(function()
    local cat = Cat.build(Cat.series_rows(), Cat.belong_rows(), Cat.charas(), Cat.declarations())
    local rows = {}
    for _, r in ipairs(VRFW.table.rows("character/chara_param")) do
      local p, b, s = r[1], r[2], r[42]
      if type(p) == "number" and type(b) == "number" then
        rows[#rows + 1] = { u32(p), u32(b), type(s) == "number" and s or 0 }
      end
    end
    local card, n = C.card_params(rows, rule.card_values)
    catalogue = { cat = cat, card = card, rows = {} }
    info(string.format("catalogue: %d series, %d character(s), %d with a card (of %d chara_param rows)", #cat.series,
      #cat.charas, n, #rows))
  end)
  if not ok then
    catalogue = nil
    warn("no catalogue (" .. tostring(err) .. "): no picker")
  end
end

-- the team rows of series index `si` with only the characters that have a card: { { team, players = { ci … } } }
local function series_rows(si)
  local K = catalogue
  local s = K and K.cat.series[si]
  if not s then
    return {}
  end
  local cached = K.rows[si]
  if cached then
    return cached
  end
  local out = {}
  for _, r in ipairs(Cat.rows(K.cat, s)) do
    local pl = {}
    for _, ci in ipairs(r.players) do
      local c = K.cat.charas[ci]
      if K.card[c[8]] then
        pl[#pl + 1] = ci
      end
    end
    if #pl > 0 then
      out[#out + 1] = { team = r.team, players = pl }
    end
  end
  K.rows[si] = out
  return out
end

-- the series that have at least one team row (their indices in the catalogue)
local pages = nil
local function page_list()
  if pages then
    return pages
  end
  pages = {}
  if catalogue then
    for si = 1, #catalogue.cat.series do
      if #series_rows(si) > 0 then
        pages[#pages + 1] = si
      end
    end
  end
  return pages
end

-- ---------------------------------------------------------------------------------------- owned copies

local owned_cache, owned_at = nil, nil

-- param -> { { h, rarity, level } … } of the saved characters (cached OWNED_TTL_MS)
local function owned_index()
  local now = VRFW.now()
  if owned_cache and owned_at and now - owned_at < OWNED_TTL_MS then
    return owned_cache
  end
  local idx = {}
  local ok, list = pcall(VRFW.chara.saved)
  if ok and type(list) == "table" then
    for _, c in ipairs(list) do
      local h = int(c.handle)
      local p = u32(c.param)
      if h and h ~= 0 and p ~= 0 then
        local okr, rec = pcall(VRFW.chara.record, h)
        local rar = (okr and type(rec) == "table" and int(rec.rarity)) or 0
        local l = idx[p]
        if not l then
          l = {}
          idx[p] = l
        end
        l[#l + 1] = { h = h, rarity = rar, level = int(c.level) or 0 }
      end
    end
  else
    warn("saved characters not read (" .. tostring(list) .. ")")
  end
  owned_cache, owned_at = idx, now
  return idx
end

local function owns(param)
  local l = owned_index()[param]
  if not l then
    return false
  end
  for _, c in ipairs(l) do
    if C.qualifies(rule, c.rarity) then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------------------------- the store

local store = nil
local event_seen = nil

local function current_slot()
  local ok, s = pcall(VRFW.slots.active)
  return ok and s or 0
end

local function check_events()
  local ok, seq = pcall(VRFW.slots.event_seq)
  if not ok or type(seq) ~= "number" then
    return
  end
  if event_seen == nil then
    event_seen = seq
    return
  end
  if seq == event_seen then
    return
  end
  local from = math.max(event_seen + 1, seq - 63)
  for n = from, seq do
    local kind, a, b = VRFW.slots.event(n)
    if store and kind then
      local slot = nil
      if kind == "switched" or kind == "deleted" or kind == "new_game" or kind == "reset" then
        slot = a
      end
      if kind == "copied" then
        slot = b
      end
      if slot == store.slot then
        info("slot " .. tostring(slot) .. ": plans read again (" .. kind .. ")")
        store = nil
      end
    end
  end
  event_seen = seq
end

local function load_store(slot)
  local text, err = VRFW.save.blob(C.BLOB, slot)
  if err then
    local kept = VRFW.save.blob_aside(C.BLOB, slot)
    VRFW.error("team_planner: " .. tostring(err) .. "; " .. tostring(kept) .. "; starting empty")
    return C.new_file(slot)
  end
  local doc = nil
  if type(text) == "string" and text ~= "" then
    local okj, j, jerr = pcall(VRFW.json.decode, text)
    if not okj or j == nil then
      local kept = VRFW.save.blob_aside(C.BLOB, slot)
      VRFW.error("team_planner: slot " .. slot .. " " .. C.BLOB .. ": " .. tostring(okj and jerr or j) .. "; " .. tostring(kept) .. "; starting empty")
      return C.new_file(slot)
    end
    doc = j
  end
  local f, why = C.decode_doc(doc, slot)
  if not f then
    local kept = VRFW.save.blob_aside(C.BLOB, slot)
    VRFW.error("team_planner: slot " .. slot .. " " .. C.BLOB .. ": " .. tostring(why) .. "; " .. tostring(kept) .. "; starting empty")
    return C.new_file(slot)
  end
  info("slot " .. slot .. ": " .. C.count(f) .. " planned slot(s)")
  return f
end

local function ensure_store()
  check_events()
  local slot = current_slot()
  if not slot or slot == 0 then
    return nil
  end
  local okr, reserved = pcall(VRFW.slots.reserved, slot)
  if okr and reserved then
    return nil
  end
  if not store or store.slot ~= slot then
    store = load_store(slot)
  end
  return store
end

local function commit(why)
  if not store or not store.dirty then
    return
  end
  local text = VRFW.json.encode(C.encode_doc(store), true)
  local ok, where
  if VRFW.slots.ready() then
    ok, where = VRFW.save.blob_stage(C.BLOB, text, store.slot)
  else
    ok, where = VRFW.save.blob_write(C.BLOB, text, store.slot)
  end
  if ok then
    store.dirty = false
  else
    VRFW.error("team_planner: cannot write slot " .. store.slot .. ": " .. tostring(where) .. " (" .. why .. ")")
  end
end

-- the mounted team-bank page (0 without pages)
local function page()
  local ok, v = pcall(VRFW.state, KEY_MOUNTED)
  v = ok and int(v) or nil
  if not v or v < 0 then
    return 0
  end
  return v
end

-- ---------------------------------------------------------------------------------------- names

local pick = nil  -- { page = index into page_list(), row = team row of the open grid, lang, texts, names }

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
  return nil
end

local function text_of(rows, id)
  local r = rows and rows[id]
  local s = r and r[0]
  if type(s) == "string" and s ~= "" then
    return T.strip_furigana(s)
  end
  return nil
end

local function team_name(team)
  local nm = catalogue.cat.team_names[team]
  return (nm and (text_of(pick.team_rows, nm) or text_of(pick.series_rows, nm))) or string.format("0x%08X", team)
end

local function count_owned(players)
  local on = 0
  for _, ci in ipairs(players) do
    if owns(catalogue.card[catalogue.cat.charas[ci][8]]) then
      on = on + 1
    end
  end
  return on
end

-- ---------------------------------------------------------------------------------------- commands: the plans

-- CMND_UTIL_TP_INFO() -> on, ghost alpha, display rarity
function Utilities.TeamPlanner.Info()
  return cfg.enabled and ensure_store() ~= nil, cfg.ghost_alpha, rule.display_rarity
end

-- CMND_UTIL_TP_LIST(set, type) -> "slot:param,…" of the squad on the mounted page ("" = none), display rarity
function Utilities.TeamPlanner.List(set, ty)
  local f = cfg.enabled and ensure_store() or nil
  set, ty = int(set), int(ty) or 0
  if not f or not set then
    return "", rule.display_rarity
  end
  return C.list_text(f, C.squad_key(page(), set, ty)), rule.display_rarity
end

-- CMND_UTIL_TP_SET(set, type, slot, param) -> ok (param 0 = clear the slot's plan)
function Utilities.TeamPlanner.Set(set, ty, slot, param)
  local f = cfg.enabled and ensure_store() or nil
  set, ty, slot, param = int(set), int(ty) or 0, int(slot), u32(param or 0)
  if not f or not set or not C.valid_slot(slot) then
    return false
  end
  local key = C.squad_key(page(), set, ty)
  if C.set(f, key, slot, param) then
    info(string.format("squad %s slot %d: %s", key, slot, param == 0 and "plan removed" or string.format("planned 0x%08X", param)))
    commit("plan")
  end
  return true
end

-- CMND_UTIL_TP_CANDIDATES(param) -> "h,h,…" the qualifying owned copies of a card, best first ("" = none)
function Utilities.TeamPlanner.Candidates(param)
  param = u32(param or 0)
  if param == 0 then
    return ""
  end
  local l = C.candidates(rule, owned_index()[param])
  local parts = {}
  for _, c in ipairs(l) do
    parts[#parts + 1] = tostring(c.h)
  end
  return table.concat(parts, ",")
end

-- CMND_UTIL_TP_ASSIGNED(set, type, slot, handle) -> ok: the menu placed a real copy in a ghost's slot
function Utilities.TeamPlanner.Assigned(set, ty, slot, h)
  local f = ensure_store()
  set, ty, slot = int(set), int(ty) or 0, int(slot)
  if not f or not set or not C.valid_slot(slot) then
    return false
  end
  local key = C.squad_key(page(), set, ty)
  local sq = f.plans[key]
  local p = sq and sq[slot] or 0
  C.set(f, key, slot, 0)
  info(string.format("squad %s slot %d: 0x%08X assigned (handle 0x%X)", key, slot, p, int(h) or 0))
  owned_cache = nil
  commit("assigned")
  return true
end

-- CMND_UTIL_TP_PENDING() -> "set:type,…" the squads of the mounted page that hold plans ("" = none)
function Utilities.TeamPlanner.Pending()
  local f = cfg.enabled and ensure_store() or nil
  if not f then
    return ""
  end
  return C.pending_text(f, page())
end

-- ---------------------------------------------------------------------------------------- commands: the picker

-- CMND_UTIL_TP_PICK_OPEN(lang code) -> pages (series), current page (1-based); 0 = no picker
function Utilities.TeamPlanner.PickOpen(code)
  if not cfg.enabled or not catalogue then
    return 0
  end
  local pl = page_list()
  if #pl == 0 then
    return 0
  end
  local lang = lang_of(code)
  local keep = pick and pick.page or 1
  pick = { page = math.min(keep, #pl), row = nil, lang = lang,
           team_rows = text_rows(lang, T.TEAM), series_rows = text_rows(lang, T.SERIES_TEXT),
           names = text_rows(lang, T.CHARA) }
  owned_cache = nil
  info(string.format("picker opened (%s): %d series page(s)", lang, #pl))
  return #pl, pick.page
end

-- CMND_UTIL_TP_PICK_GRID() -> cols, rows, pitch x, pitch y, card scale, centre x, centre y (screen px, y down), card
-- centre offset x, y (px at scale 1, y down), ghost alpha
function Utilities.TeamPlanner.PickGrid()
  local g = cfg.grid
  return g.cols, g.rows, g.pitch_x, g.pitch_y, g.scale, g.cx, g.cy, g.ox, g.oy, cfg.ghost_alpha
end

-- CMND_UTIL_TP_PICK_TEAM_GRID() -> the team grid's layout: cols, rows, pitch x, pitch y, centre x, centre y
function Utilities.TeamPlanner.PickTeamGrid()
  local g = cfg.team_grid
  return g.cols, g.rows, g.pitch_x, g.pitch_y, g.cx, g.cy
end

-- CMND_UTIL_TP_PICK_TAB(dir) -> page (1-based), the series' name, characters owned, characters, team rows
function Utilities.TeamPlanner.PickTab(dir)
  if not pick then
    return false
  end
  local pl = page_list()
  local d = int(dir) or 0
  if d ~= 0 then
    pick.page = ((pick.page - 1 + (d < 0 and -1 or 1)) % #pl) + 1
  end
  local si = pl[pick.page]
  local s = catalogue.cat.series[si]
  local rows = series_rows(si)
  local seen, on, n = {}, 0, 0
  for _, r in ipairs(rows) do
    for _, ci in ipairs(r.players) do
      if not seen[ci] then
        seen[ci] = true
        n = n + 1
        if owns(catalogue.card[catalogue.cat.charas[ci][8]]) then
          on = on + 1
        end
      end
    end
  end
  local name = text_of(pick.series_rows, s.name_text) or text_of(pick.team_rows, s.name_text) or string.format("0x%08X", s.id)
  return pick.page, name, on, n, #rows
end

-- CMND_UTIL_TP_PICK_ITEM(i) -> team row i (1-based) of the page: its name, characters owned, characters, its emblem
function Utilities.TeamPlanner.PickItem(i)
  if not pick then
    return false
  end
  local si = page_list()[pick.page]
  local r = series_rows(si)[int(i) or 0]
  if not r then
    return false
  end
  local s = catalogue.cat.series[si]
  return team_name(r.team), count_owned(r.players), #r.players, Cat.team_emblem(catalogue.cat, r.team, s and s.ty or 0)
end

-- CMND_UTIL_TP_PICK_TEAM(i) -> opens team row i for the card grid: characters, owned, the team's name
function Utilities.TeamPlanner.PickTeam(i)
  if not pick then
    return false
  end
  i = int(i) or 0
  local r = series_rows(page_list()[pick.page])[i]
  if not r then
    return false
  end
  pick.row = i
  return #r.players, count_owned(r.players), team_name(r.team)
end

-- CMND_UTIL_TP_PICK_PLAYER(j) -> character j (1-based) of the open team: card param, owned, display rarity, name
function Utilities.TeamPlanner.PickPlayer(j)
  if not pick or not pick.row then
    return false
  end
  local r = series_rows(page_list()[pick.page])[pick.row]
  local ci = r and r.players[int(j) or 0]
  if not ci then
    return false
  end
  local c = catalogue.cat.charas[ci]
  local p = catalogue.card[c[8]]
  return p, owns(p), rule.display_rarity, text_of(pick.names, c[1]) or ""
end

-- ---------------------------------------------------------------------------------------- start

load_cfg()
if cfg.enabled then
  build_catalogue()
else
  info("off ([team_planner] enabled = false)")
end
