-- Character Reforged › the new skill set's data (owner 2026-10-14; docs/refactor/aura-mods-split.md «Skill table»,
-- «The 6 + 2 set over the retail data»):
--
--   * the MIX slot store: each saved card's Mix-Max / «Modo cambio» move, per save slot (blob hiper_slots.json of this
--     mod: { version, migrated, mix = { ["<card %08X>"] = "<move %08X>" } }, the layout Inazuma Fantasy used; imported
--     once from IF's blob of the same name by content\game\mix_slots.toml [[VRFW.SaveImport]]). Published for the match
--     as the native table MixSlot (saved card -> move; the plates slot's [source] mix_table, content\extra_slots\
--     skill_set.toml). It is kept whatever the option says: «Victory Road» only hides it; only uninstalling this mod
--     loses it. For a card with nothing stored the table carries the first Mix-Max / «Modo cambio» of his retail board
--     (the projection: nothing written).
--   * the moveset defaults: a character's own aura / mix (keshin or totem, Mix-Max or «Modo cambio») published as the
--     native table MovesetDefault (chara_param -> { aura, mix }; the plates slot's [source] default_table, read after
--     everything the player or his team set): his learn list slot 9 (chara_param col 27), and the mix of the export
--     named by [CharacterReforged.SkillSet] moveset_export (agreed with charstats: CharacterReforged.Moveset(card))
--     when this script sees it.
--   * THE PROJECTION (owner 2026-10-14: no save edits): CharacterReforged.ProjectSkillSet(card) reads the game's data as
--     it is and says where each entry of the 6-entry technique list belongs in the new set: special moves on the 6 rows
--     (list order), auras in the aura slot (keshin / totem / armour) or the mix slot (Mix-Max / «Modo cambio», by
--     content\skill_set\*.toml aura_types / mix_types); per slot its own move first (board slot 8; the mix store), else
--     the first one of the list in list order; the others are hidden (kept in the save). Used by the skill table
--     (CMND_CHARACTERREFORGED_PROJECT_SKILL_SET), MixSlot, FormContext and the overflow log; the match side does the
--     same over the same data (content\extra_slots\skill_set.toml [source] list_auras_out / skill_list / mix_table).
--     Nothing is written to the save by viewing or by the option; one log line per player with hidden entries when
--     the option goes on / a save is loaded.
--   * the form context: native table FormContext (saved card -> { aura, mix, aura_from, mix_from }) as the view in
--     use shows them; the VR-Framework's form viewer («Cambiar forma», Ver apariencia) reads it
--     (content\transforms\form_source.toml [miximax] form_source) instead of scanning the board.
--   * the branch rule: while the new set is on every owned card's skill board stays on branch 1 (record +0x1AC
--     currentRouteType = 0): set when the option goes on (one summary line), again at every save load and every few
--     seconds (a recruited card, a branch switched on the retail board). Switching the option off restores nothing.
--   * the effective skill set: CharacterReforged.EffectiveSkillSet(card) is the provider of the VR-Framework's skill set
--     service (VRFW.skill_set.provide): with the new set on, the card's aura / mix / 6 rows as the skill table shows them.
--
-- Commands (content\game\mix_slots.toml): CMND_CHARACTERREFORGED_MIX_GET(card) -> move, _MIX_SET(card, move | 0) -> ok,
-- code (0 ok, 1 not a mix move, 2 not written), _SLOT_OF(move) -> kind (0 aura, 1 mix, 2 armour, -1 none), keshin.
-- CMND_CHARACTERREFORGED_PROJECT_SKILL_SET(card) -> aura, mix, aura_from, mix_from, then the 6 rows' list positions
-- (0..5; -1 none) (from: 0..5 a list position, 8 board slot 8 = the aura slot's own, 100 the mix store, 200 the board, -1 none).
-- Exports (one value or one list each): MixGet(card), MixSet(card, move) -> { ok, code }, SlotOf(move) -> { kind, keshin },
-- MixAddsStats(card) -> whether his mix slot's kind adds stats (mix_stat_types),
-- ProjectSkillSet(card) -> { techniques = {6}, rows = {6 list positions}, aura, mix, aura_from, mix_from, hidden = {…} }.

CharacterReforged = CharacterReforged or {}
local CR = CharacterReforged

local BLOB, TABLE, DEFAULTS = "hiper_slots.json", "MixSlot", "MovesetDefault"
local OPTION = "skill_set_view"
local REC_PLACED, REC_NATIVE, REC_ROUTE, REC_LIST, LIST_ENTRY = 0x94, 0xC8, 0x1AC, 0x50, 8
local BOARD_SLOTS, LIST_SLOTS = 9, 6
local ROUTE_EVERY_MS, OPTION_EVERY_MS = 3000, 1000

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end
local function hex(v)
  v = u32(v)
  return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
end
local function info(...) VRFW.log("skill set:", ...) end
local function warn(...) VRFW.warn("skill set:", ...) end

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

function CharacterReforged.SkillSetOnNow()
  local ok, v = pcall(VRFW.option, OPTION)
  return ok and (tonumber(v) or 0) ~= 0
end

-- ---------------------------------------------------------------------------------------------- slot rules

-- the slot rules: content\skill_set\*.toml (aura_types / mix_types, moveset_export) and the carriers every active mod's
-- plates slot declares (fusion carrier, swap carriers; [[VRFW.ExtraSlot]] and [[VRFW.ExtraSlotExtend]])
local RULES = nil
local function rules()
  if RULES then return RULES end
  local r = { aura = {}, mix = {}, mix_stats = {}, carriers = {}, moveset_export = "" }
  local okd, decl = pcall(VRFW.files.declarations, "content/skill_set")
  local merged = { aura_types = { 0, 3 }, mix_types = { 2, 6 }, mix_stat_types = { 2 } }
  for _, f in ipairs(okd and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local t = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.SkillSet or nil
    if type(t) == "table" then
      for k, v in pairs(t) do merged[k] = v end
    end
  end
  for _, x in ipairs(merged.aura_types or {}) do r.aura[tonumber(x) or -1] = true end
  for _, x in ipairs(merged.mix_types or {}) do r.mix[tonumber(x) or -1] = true end
  for _, x in ipairs(merged.mix_stat_types or {}) do r.mix_stats[tonumber(x) or -1] = true end
  r.moveset_export = tostring(merged.moveset_export or "")
  local oks, slots = pcall(VRFW.files.declarations, "content/extra_slots")
  for _, f in ipairs(oks and type(slots) == "table" and slots or {}) do
    local v = type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW or {}
    for _, list in ipairs({ v.ExtraSlot or {}, v.ExtraSlotExtend or {} }) do
      for _, s in ipairs(type(list) == "table" and list or {}) do
        if type(s) == "table" and type(s.fusion) == "table" and type(s.fusion.carrier) == "string" then
          r.carriers[u32(VRFW.ui.crc32(s.fusion.carrier))] = "fusion"
        end
        if type(s) == "table" and type(s.swap) == "table" and type(s.swap.carriers) == "string" then
          for k = 0, (tonumber(s.swap.count) or 0) - 1 do
            r.carriers[u32(VRFW.ui.crc32((s.swap.carriers:gsub("{k}", tostring(k)))))] = "change"
          end
        end
      end
    end
  end
  RULES = r
  return r
end

-- a move's aura type and slot kind never change while the game runs: read once per move (cleared at game_reset)
local AURA_TYPE_OF, SLOT_OF = {}, {}

local function aura_type(id)
  if not id or id == 0 then return nil end
  local known = AURA_TYPE_OF[id]
  if known ~= nil then return known or nil end
  local ok, t = pcall(VRFW.extra_slot.aura_type, id)
  if not ok then return nil end
  if type(t) ~= "number" then t = false end
  AURA_TYPE_OF[id] = t
  return t or nil
end

-- "aura", "mix", "armour" (+ its keshin, 0 = none) or nil (a special move / nothing)
local function read_slot_of(id)
  local r = rules()
  if r.carriers[id] then return "mix" end
  local t = aura_type(id)
  if t == nil then return nil end
  if r.mix[t] then return "mix" end
  if r.aura[t] then return "aura" end
  if t == 1 then
    local ok, k = pcall(VRFW.form.spirit_of, id)
    k = ok and u32(k or 0) or 0
    return "armour", k
  end
  return "other"
end

local function slot_of(id)
  id = u32(id or 0)
  if id == 0 then return nil end
  local known = SLOT_OF[id]
  if known == nil then
    local what, k = read_slot_of(id)
    known = { what or false, k }
    SLOT_OF[id] = known
  end
  return known[1] or nil, known[2]
end

local KIND = { aura = 0, mix = 1, armour = 2 }
function CharacterReforged.SlotOfCmd(id)
  local what, k = slot_of(id)
  return KIND[what] or -1, k or 0
end
function CharacterReforged.SlotOf(id)
  local a, b = CharacterReforged.SlotOfCmd(id)
  return { a, b }
end

-- ---------------------------------------------------------------------------------------------- the card's retail data

local function record(hdl)
  local ok, r = pcall(VRFW.chara.record, hdl)
  if ok and type(r) == "table" and r.addr and r.addr >= 0x10000 then return r end
  return nil
end

local function item_of(inv)
  if not inv or inv == 0 then return 0 end
  local ok, item = pcall(VRFW.item.of_inv, inv)
  return ok and u32(item or 0) or 0
end

-- the items on the card's board slots 0..8 (placed, else native)
local function board(addr)
  local out = {}
  for s = 0, BOARD_SLOTS - 1 do
    local inv = u32(rd("u32", addr + REC_PLACED + s * 4) or 0)
    if inv == 0 then inv = u32(rd("u32", addr + REC_NATIVE + s * 4) or 0) end
    out[s] = item_of(inv)
  end
  return out
end

local function list(addr)
  local out = {}
  for k = 0, LIST_SLOTS - 1 do
    out[k] = u32(rd("u32", addr + REC_LIST + k * LIST_ENTRY) or 0)
  end
  return out
end

local OWNED_MAX_AGE_MS = 6000
local OWNED = { at = nil, list = nil }

local function read_owned()
  local out = {}
  local ok, v = pcall(VRFW.chara.saved)
  for _, r in ipairs(ok and type(v) == "table" and v or {}) do
    local h = u32(r.handle)
    if h ~= 0 and r.addr and r.addr >= 0x10000 then out[#out + 1] = { hdl = h, param = u32(r.param), addr = r.addr } end
  end
  return out
end

-- the owned cards, read again at most every OWNED_MAX_AGE_MS (the sweep and the branch rule share one read; a save
-- load, a slot switch and game_reset read them again)
local function owned()
  local now = VRFW.now()
  if not OWNED.list or now - OWNED.at >= OWNED_MAX_AGE_MS then
    OWNED.list, OWNED.at = read_owned(), now
  end
  return OWNED.list
end

-- ---------------------------------------------------------------------------------------------- the projection

-- THE projection of one saved card (read only). Rows 1-6 = the list positions holding a special move, in list order,
-- then the empty positions; every aura of the list is off the rows. Aura slot = board slot 8 when it holds a keshin /
-- totem / armour, else the first keshin / totem / armour of the list (list order). Mix slot = the stored mix, else the
-- first Mix-Max / «Modo cambio» of the list (list order), else (none in the list) the first of his board. Every other
-- aura of the list is hidden (kept where it is in the save).
local AURA_FROM_BOARD_SLOT, MIX_FROM_STORE, MIX_FROM_BOARD = 8, 100, 200
local function project_with_board(hdl, addr)
  local l, b = list(addr), board(addr)
  local out = { techniques = {}, rows = {}, aura = 0, mix = 0, aura_from = -1, mix_from = -1, hidden = {} }
  local empty = {}
  for k = 0, LIST_SLOTS - 1 do
    local x = l[k]
    if x == 0 then
      empty[#empty + 1] = k
    elseif aura_type(x) == nil then
      out.techniques[#out.techniques + 1] = x
      out.rows[#out.rows + 1] = k
    end
  end
  for _, k in ipairs(empty) do
    out.techniques[#out.techniques + 1] = 0
    out.rows[#out.rows + 1] = k
  end
  local own = slot_of(b[8])
  if b[8] ~= 0 and (own == "aura" or own == "armour") then
    out.aura, out.aura_from = b[8], AURA_FROM_BOARD_SLOT
  end
  local m = CharacterReforged.MixStored and CharacterReforged.MixStored(hdl) or 0   -- the stored mix (the mix store below)
  if m ~= 0 then out.mix, out.mix_from = m, MIX_FROM_STORE end
  for k = 0, LIST_SLOTS - 1 do
    local x = l[k]
    if x ~= 0 and aura_type(x) ~= nil then
      local w = slot_of(x)
      if (w == "aura" or w == "armour") and out.aura == 0 then
        out.aura, out.aura_from = x, k
      elseif w == "mix" and out.mix == 0 then
        out.mix, out.mix_from = x, k
      elseif x ~= out.aura and x ~= out.mix then
        out.hidden[#out.hidden + 1] = { pos = k, id = x, kind = w or "other" }
      end
    end
  end
  if out.mix == 0 then
    for s = 0, BOARD_SLOTS - 1 do
      if b[s] ~= 0 and slot_of(b[s]) == "mix" then
        out.mix, out.mix_from = b[s], MIX_FROM_BOARD
        break
      end
    end
  end
  while #out.techniques < LIST_SLOTS do
    out.techniques[#out.techniques + 1] = 0
    out.rows[#out.rows + 1] = -1
  end
  return out, b
end

local function project(hdl, addr)
  local out = project_with_board(hdl, addr)
  return out
end

function CharacterReforged.ProjectSkillSet(card)
  local r = record(u32(card or 0))
  if not r then return nil end
  return project(u32(card), r.addr)
end

function CharacterReforged.ProjectSkillSetCmd(card)
  card = u32(card or 0)
  -- the menu-time step of the tables and the shown card's rows at once, whatever the sweep's progress (both below)
  if CharacterReforged.CommandStep then pcall(CharacterReforged.CommandStep) end
  local p = CharacterReforged.ProjectSkillSet(card)
  if p and CharacterReforged.PublishCardRows then pcall(CharacterReforged.PublishCardRows, card, p) end
  if not p then return 0, 0, -1, -1, -1, -1, -1, -1, -1, -1 end
  local r = p.rows
  return p.aura, p.mix, p.aura_from, p.mix_from, r[1], r[2], r[3], r[4], r[5], r[6]
end


-- ---------------------------------------------------------------------------------------------- the mix store

local ST = { slot = -1, st = nil }

local function save_slot()
  if VRFW.slots.ready() then return VRFW.slots.active() end
  return 1
end

local function key(card) return string.format("%08X", u32(card)) end

-- THE SWEEP (2026-10-14, owner: the aura / mix halves of the skill table did nothing): the native tables MixSlot and
-- FormContext and the overflow report walk every owned card (thousands in a long save: 3700 in the owner's), which is
-- far more than one call's CPU budget (scripts.toml `budget`). Before, the first CMND_CHARACTERREFORGED_MIX_GET of a
-- session loaded the store and published MixSlot over every card inside the command: the budget ran out, the framework
-- switched this whole script off, and every command of it (MIX_GET / MIX_SET / SLOT_OF / PROJECT_SKILL_SET) answered
-- nothing for the rest of the session. Now a command never walks the cards: the sweep below does it on the tick,
-- CARDS_PER_TICK cards per tick, and writes each table at once at the end (VRFW.native.table_replace), so the match
-- never reads a half-written table.
local CARDS_PER_TICK = 150
local SWEEP = { running = false, dirty = true, next_at = 0 }
local CONTEXT = "FormContext"
local CONTEXT_LOG = { logged = false, on = nil }

local function load()
  local s = save_slot()
  if ST.slot == s and ST.st then return ST.st end
  local st = { version = 1, migrated = false, mix = {} }
  local ok, data = pcall(VRFW.save.get_blob, s, BLOB)
  if ok and type(data) == "string" and #data > 0 then
    local ok2, v = pcall(VRFW.json.decode, data)
    if ok2 and type(v) == "table" then
      st.migrated = v.migrated == true
      for k, x in pairs(type(v.mix) == "table" and v.mix or {}) do
        local id = u32(tonumber(tostring(x), 16) or 0)
        if id ~= 0 and tonumber(k, 16) then st.mix[string.upper(k)] = id end
      end
    else
      warn(string.format("slot %d %s not readable: empty mix store used (the file is left as it is)", s, BLOB))
    end
  end
  ST.slot, ST.st = s, st
  SWEEP.dirty = true                                -- the tables follow on the next ticks (never inside a command)
  return st
end

local function save()
  local st = ST.st or load()
  local mix = {}
  for k, id in pairs(st.mix) do mix[k] = string.format("%08X", id) end
  local ok, text = pcall(VRFW.json.encode, { version = 1, migrated = st.migrated, mix = mix })
  if not ok then return false, tostring(text) end
  local okw, why = pcall(VRFW.save.set_blob, ST.slot, BLOB, text)
  if not okw then return false, tostring(why) end
  if why == false then return false, "not written" end
  return true
end

function CharacterReforged.MixGet(card)
  return load().mix[key(card)] or 0
end
-- the stored mix of a card (the projection reads it; the cached state when loaded)
function CharacterReforged.MixStored(card)
  local st = ST.st or load()
  return st.mix[key(card)] or 0
end

-- Does the mix slot of a saved card add stats? The projected mix move's aura type against [CharacterReforged.SkillSet]
-- mix_stat_types (Mix-Max yes, «Modo cambio» no: it only swaps him into the partner). No mix move or an unknown type:
-- true (the stat owner's own rules decide).
function CharacterReforged.MixAddsStats(card)
  local p = CharacterReforged.ProjectSkillSet(u32(card or 0))
  local m = p and u32(p.mix or 0) or 0
  if m == 0 then return true end
  local t = aura_type(m)
  if t == nil then return true end
  return rules().mix_stats[t] == true
end

-- the command a retail Mix-Max / «Modo cambio» item becomes for this card (the game's per-card changes: one item serves
-- several players, each with his own row and look); the item itself without a change or an answer
local function own_row(card, id)
  local ok, row = pcall(VRFW.miximax.call, { op = "item_row", aura = id, hdl = card })
  row = ok and u32(row or 0) or 0
  if row == 0 or row == id or slot_of(row) ~= "mix" then return id end
  info(string.format("mix slot of %s: item %s is %s for this card", hex(card), hex(id), hex(row)))
  return row
end

function CharacterReforged.MixSetCmd(card, id)
  card, id = u32(card or 0), u32(id or 0)
  if card == 0 then return false, 1 end
  if id ~= 0 and slot_of(id) ~= "mix" then
    info(string.format("mix slot of %s: %s refused: not a Mix-Max / «Modo cambio» move", hex(card), hex(id)))
    return false, 1
  end
  if id ~= 0 then id = own_row(card, id) end
  local st = load()
  local old = st.mix[key(card)] or 0
  st.mix[key(card)] = id ~= 0 and id or nil
  local ok, why = save()
  if not ok then
    st.mix[key(card)] = old ~= 0 and old or nil
    warn(string.format("mix slot of %s not saved (%s)", hex(card), tostring(why)))
    return false, 2
  end
  -- this card's MixSlot row at once (an emptied store: his projected mix comes back with the next sweep)
  if id ~= 0 then pcall(VRFW.native.table_set, TABLE, card, id) end
  SWEEP.dirty = true
  info(string.format("mix slot of %s: %s -> %s", hex(card), hex(old), hex(id)))
  return true, 0
end

function CharacterReforged.MixSet(card, id)
  local ok, code = CharacterReforged.MixSetCmd(card, id)
  return { ok, code }
end

-- ---------------------------------------------------------------------------------------------- moveset defaults

-- Every character's own aura / mix: his learn list slot 9 (chara_param col 27, the data the game reads: Character
-- Reforged's per-card movesets edit it) when it is an aura-slot / mix-slot move, and the mix of the moveset export
-- ([CharacterReforged.SkillSet] moveset_export, agreed shape CharacterReforged.Moveset(card) -> { aura, mix, … }) when
-- that function is visible to this script. Published once per session (about 6000 rows read once).
local DEF = { done = false, map = {} }
local function moveset_fn()
  local name = rules().moveset_export
  if name == "" then return nil, "" end
  local prefix, fn = name:match("^([%w_]+)%.([%w_]+)$")
  local t = prefix and rawget(_G, prefix) or nil
  local f = type(t) == "table" and t[fn] or nil
  return type(f) == "function" and f or nil, name
end

local function publish_defaults()
  if DEF.done then return DEF.n end
  DEF.done = true
  local ok, rows = pcall(VRFW.table.raw, "data/common/gamedata/character/chara_param_*.cfg.bin", "CHARA_PARAM_INFO", { 1, 27 })
  if not ok or type(rows) ~= "table" then
    warn("moveset defaults: chara_param not readable (" .. tostring(rows) .. "): no defaults")
    DEF.n = 0
    return 0
  end
  local f, name = moveset_fn()
  pcall(VRFW.native.table_clear, DEFAULTS)
  DEF.map = {}
  local n, na, nm, nx = 0, 0, 0, 0
  for _, r in ipairs(rows) do
    local param, nine = u32(r[1]), u32(r[27])
    if param ~= 0 then
      local aura, mix = 0, 0
      local w = slot_of(nine)
      if w == "aura" then aura = nine elseif w == "mix" then mix = nine end
      if f then
        local okm, m = pcall(f, param)
        if okm and type(m) == "table" then
          if aura == 0 and slot_of(m.aura) == "aura" then aura = u32(m.aura) end
          if mix == 0 and slot_of(m.mix) == "mix" then mix = u32(m.mix); nx = nx + 1 end
        end
      end
      if aura ~= 0 or mix ~= 0 then
        DEF.map[param] = { aura = aura, mix = mix }
        pcall(VRFW.native.table_set, DEFAULTS, param, { aura = aura, mix = mix })
        n = n + 1
        if aura ~= 0 then na = na + 1 end
        if mix ~= 0 then nm = nm + 1 end
      end
    end
  end
  info(string.format("moveset defaults: %d of %d characters with an own aura (%d) / mix (%d) for the empty slots; moveset export %s%s",
    n, #rows, na, nm, name ~= "" and name or "none", f and string.format(" (gave %d mix)", nx) or (name ~= "" and " not visible here: learn list slot 9 only" or "")))
  DEF.n = n
  return n
end

-- (saved card) -> aura, mix of his basic set (the moveset defaults; 0 = none): what «Restablecer» puts back
function CharacterReforged.DefaultSetCmd(card)
  card = u32(card or 0)
  if card == 0 then return 0, 0 end
  local ok, r = pcall(VRFW.chara.record, card)
  local param = (ok and type(r) == "table") and u32(r.param or 0) or 0
  if param == 0 then return 0, 0 end
  pcall(publish_defaults)
  local d = DEF.map[param]
  if not d then return 0, 0 end
  return u32(d.aura or 0), u32(d.mix or 0)
end

-- ---------------------------------------------------------------------------------------------- the sweep

-- The FORM CONTEXT of every owned card (native table FormContext; declared to the VR-Framework's form viewer by
-- content\transforms\form_source.toml, owner 2026-10-14: «the character's form context must come from Character
-- Reforged, not from VRFW guessing»): aura = the spirit whose armour is his armour form, mix = his Mix-Max / «Modo
-- cambio» move, as the view in use shows them. New set: the projection (CharacterReforged.ProjectSkillSet: board slot
-- 8, else the first aura of his technique list, an armour standing for its spirit; mix = his stored mix, else the
-- list's first, else the board's first), then his moveset default. Victory Road: the retail view (board slot 8 / the
-- first aura of the board; the board's first mix; the stored mix stays hidden). aura_from / mix_from: the board slot,
-- 100 the mix store, 200 the moveset default (the viewer's log).
-- MixSlot: the stored mix of every card, else (the projection) the first mix move of his technique list, else of his
-- board: the match's mix slot = what the skill table shows.
-- The overflow report: one line per player whose technique list has entries the 6 + 1 + 1 set does not show (kept,
-- hidden), when the option goes on / a save is loaded.
local function spirit(id)
  local w, k = slot_of(id)
  if w == "aura" then return u32(id) end
  if w == "armour" and k and k ~= 0 then return u32(k) end
  return 0
end

local function sweep_start(on, report_why)
  local st = load()
  local cards = owned()
  -- the roster is not readable yet (boot, a save loading): nothing is written, the sweep runs again in ROUTE_EVERY_MS
  -- with a fresh read
  if #cards == 0 then
    OWNED.list = nil
    SWEEP.running, SWEEP.dirty = false, false
    SWEEP.report_next = SWEEP.report_next or report_why
    return
  end
  SWEEP.running, SWEEP.dirty = true, false
  SWEEP.on, SWEEP.report_why = on, report_why
  SWEEP.cards, SWEEP.next_card = cards, 1
  SWEEP.mix_rows, SWEEP.context_rows = {}, {}
  SWEEP.stored, SWEEP.projected = 0, 0
  SWEEP.with_aura, SWEEP.with_mix = 0, 0
  SWEEP.report_players, SWEEP.report_lines = 0, 0
  for k, id in pairs(st.mix) do
    local card = tonumber(k, 16)
    if card then
      SWEEP.mix_rows[#SWEEP.mix_rows + 1] = { card, id }
      SWEEP.stored = SWEEP.stored + 1
    end
  end
end

-- the form context row of one card: { aura, mix, aura_from, mix_from } as the view in use (`on` = the new set) shows it
local function context_row(c, p, b, on)
  local aura, aura_from, mix, mix_from = 0, -1, 0, -1
  if on then
    aura = spirit(p.aura)
    if aura ~= 0 then aura_from = p.aura_from end
    if p.mix ~= 0 then mix, mix_from = p.mix, p.mix_from end
  else
    aura, aura_from = spirit(b[8]), 8
    if aura == 0 then
      aura_from = -1
      for s = 0, BOARD_SLOTS - 1 do
        local x = spirit(b[s])
        if x ~= 0 then aura, aura_from = x, s break end
      end
    end
  end
  if mix == 0 then
    for s = 0, BOARD_SLOTS - 1 do
      if b[s] ~= 0 and slot_of(b[s]) == "mix" then mix, mix_from = b[s], s break end
    end
  end
  local d = DEF.map[c.param]
  if on and d then
    if aura == 0 and (d.aura or 0) ~= 0 then aura, aura_from = d.aura, 200 end
    if mix == 0 and (d.mix or 0) ~= 0 then mix, mix_from = d.mix, 200 end
  end
  return { aura = aura, mix = mix, aura_from = aura_from, mix_from = mix_from }
end

local function sweep_card(st, c)
  local p, b = project_with_board(c.hdl, c.addr)
  if not st.mix[key(c.hdl)] and p.mix ~= 0 then
    SWEEP.mix_rows[#SWEEP.mix_rows + 1] = { c.hdl, p.mix }
    SWEEP.projected = SWEEP.projected + 1
  end
  local row = context_row(c, p, b, SWEEP.on)
  local aura, mix = row.aura, row.mix
  SWEEP.context_rows[#SWEEP.context_rows + 1] = { c.hdl, row }
  if aura ~= 0 then SWEEP.with_aura = SWEEP.with_aura + 1 end
  if mix ~= 0 then SWEEP.with_mix = SWEEP.with_mix + 1 end
  if SWEEP.report_why and #p.hidden > 0 then
    SWEEP.report_players = SWEEP.report_players + 1
    if SWEEP.report_lines < 60 then
      SWEEP.report_lines = SWEEP.report_lines + 1
      local hidden = {}
      for _, h in ipairs(p.hidden) do
        hidden[#hidden + 1] = string.format("%s %s (list position %d)", h.kind, hex(h.id), h.pos + 1)
      end
      info(string.format("projection (%s): card %s: aura slot %s, mix slot %s; hidden in the new set (kept in his list): %s",
        SWEEP.report_why, hex(c.hdl), hex(p.aura), hex(p.mix), table.concat(hidden, ", ")))
    end
  end
end

local function sweep_finish()
  SWEEP.running = false
  local okm, em = pcall(VRFW.native.table_replace, TABLE, nil, SWEEP.mix_rows)
  if not okm then warn("MixSlot not written: " .. tostring(em)) end
  local okc, ec = pcall(VRFW.native.table_replace, CONTEXT, nil, SWEEP.context_rows)
  if not okc then warn("form context not written: " .. tostring(ec)) end
  if not CONTEXT_LOG.logged or CONTEXT_LOG.on ~= SWEEP.on then
    CONTEXT_LOG.logged, CONTEXT_LOG.on = true, SWEEP.on
    info(string.format("form context (%s view): %d owned card(s), %d with an aura, %d with a mix (table %s, read by the form viewer); MixSlot: %d stored, %d projected",
      SWEEP.on and "new set" or "Victory Road", #SWEEP.context_rows, SWEEP.with_aura, SWEEP.with_mix, CONTEXT,
      SWEEP.stored, SWEEP.projected))
  end
  if SWEEP.report_why and SWEEP.report_players > SWEEP.report_lines then
    info(string.format("projection (%s): %d more player(s) with hidden entries", SWEEP.report_why,
      SWEEP.report_players - SWEEP.report_lines))
  end
  SWEEP.cards, SWEEP.mix_rows, SWEEP.context_rows = nil, nil, nil
end

-- one card's rows at once (the card a menu shows: the skill table, the player page, the dock card ask for its
-- projection): FormContext as the view in use shows it, MixSlot = his stored mix, else the projected one
local CARD_ROWS_EVERY_MS = 500
local CARD_ROWS_AT = {}
function CharacterReforged.PublishCardRows(card, p)
  local now = VRFW.now()
  if (CARD_ROWS_AT[card] or -CARD_ROWS_EVERY_MS) + CARD_ROWS_EVERY_MS > now then return end
  CARD_ROWS_AT[card] = now
  local r = record(card)
  if not r then return end
  local row = context_row({ hdl = card, param = u32(r.param or 0) }, p, board(r.addr), CharacterReforged.SkillSetOnNow())
  pcall(VRFW.native.table_set, CONTEXT, card, row)
  local st = ST.st or load()
  local stored = st.mix[key(card)] or 0
  if stored ~= 0 then
    pcall(VRFW.native.table_set, TABLE, card, stored)
  elseif p.mix ~= 0 then
    pcall(VRFW.native.table_set, TABLE, card, p.mix)
  end
end

-- THE EFFECTIVE SKILL SET (the VR-Framework's skill set service, VRFW.skill_set): every reader of a player's equipped
-- moves (the form viewer «Cambiar forma», the miximax partner aura, other mods' menus through CMND_VRFW_SKILL_SET) asks
-- the framework, which asks this provider. New set on: the skill table's view of the card (aura slot = the projection's
-- aura move, else his moveset default; mix slot = the stored / projected mix, else his moveset default; techniques =
-- the 6 rows in table order, an empty list position taking the board slot of the same position when it holds a special
-- move not already listed, as the match's list_board_fill; filled rows first, empty rows last). Victory Road: nil (the retail data).
function CharacterReforged.EffectiveSkillSet(card)
  if not CharacterReforged.SkillSetOnNow() then return nil end
  card = u32(card or 0)
  local r = record(card)
  if not r then return nil end
  local p, b = project_with_board(card, r.addr)
  local aura, aura_from, mix, mix_from = p.aura, p.aura_from, p.mix, p.mix_from
  local d = DEF.map[u32(r.param or 0)]
  if d then
    if aura == 0 and (d.aura or 0) ~= 0 then aura, aura_from = d.aura, 200 end
    if mix == 0 and (d.mix or 0) ~= 0 then mix, mix_from = d.mix, 200 end
  end
  local listed, techniques = {}, {}
  for _, x in ipairs(p.techniques) do
    if x ~= 0 then listed[x] = true end
  end
  local filled, empty = {}, {}
  for i, x in ipairs(p.techniques) do
    local pos = p.rows[i]
    if x == 0 and pos and pos >= 0 then
      local m = b[pos] or 0
      if m ~= 0 and aura_type(m) == nil and not listed[m] then
        x = m
        listed[m] = true
      end
    end
    if x ~= 0 then
      filled[#filled + 1] = { x, pos }
    else
      empty[#empty + 1] = { x, pos }
    end
  end
  -- the filled rows first, then the empty ones (the skill table's row order)
  local rows = {}
  for _, e in ipairs(filled) do techniques[#techniques + 1], rows[#rows + 1] = e[1], e[2] end
  for _, e in ipairs(empty) do techniques[#techniques + 1], rows[#rows + 1] = e[1], e[2] end
  return { aura = aura, mix = mix, aura_from = aura_from, mix_from = mix_from, techniques = techniques, rows = rows }
end
if type(VRFW.skill_set) == "table" and type(VRFW.skill_set.provide) == "function" then
  VRFW.skill_set.provide("CharacterReforged.EffectiveSkillSet")
end

-- one slice of the running sweep -> true when it has finished
local function sweep_step()
  local st = ST.st or load()
  local cards = SWEEP.cards or {}
  local last = math.min(#cards, SWEEP.next_card + CARDS_PER_TICK - 1)
  for i = SWEEP.next_card, last do
    local ok, e = pcall(sweep_card, st, cards[i])
    if not ok then
      warn("sweep: card " .. hex(cards[i] and cards[i].hdl or 0) .. ": " .. tostring(e))
    end
  end
  SWEEP.next_card = last + 1
  if SWEEP.next_card > #cards then
    sweep_finish()
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------------------------- branch rule

-- every owned card's board on branch 1 -> switched, total
local function force_branch1()
  local cards = owned()
  local n = 0
  for _, c in ipairs(cards) do
    local r = rd("u32", c.addr + REC_ROUTE)
    if r ~= nil and r ~= 0 then
      if pcall(VRFW.mem.write, "u32", c.addr + REC_ROUTE, 0) then n = n + 1 end
    end
  end
  return n, #cards
end

local RT = { on = nil, next_opt = 0, next_route = 0, edge = false }

local function tick()
  local now = VRFW.now()
  if VRFW.slots.ready() and ST.slot ~= VRFW.slots.active() then
    ST.slot, ST.st = -1, nil
    OWNED.list = nil
    SWEEP.running = false
    pcall(load)
  end
  if now >= RT.next_opt then
    RT.next_opt = now + OPTION_EVERY_MS
    local on = CharacterReforged.SkillSetOnNow()
    if RT.on ~= on then
      local was = RT.on
      RT.on = on
      if was ~= nil or on then
        info("option «Tabla de habilidades»: " .. (on and "new set (6 + aura slot + mix slot)" or "Victory Road (the mix slots stay saved, hidden)"))
      end
      RT.edge = on
      RT.why = "option on"
      RT.next_route = 0
      SWEEP.dirty, SWEEP.running = true, false
    end
  end
  local idle = RT.on ~= nil and VRFW.slots.ready() and not (VRFW.in_match and VRFW.in_match())
  if RT.on and idle and now >= RT.next_route then
    RT.next_route = now + ROUTE_EVERY_MS
    local ok, n, total = pcall(force_branch1)
    if not ok then
      warn("branch rule: " .. tostring(n))
    elseif RT.edge then
      if total > 0 then
        RT.edge = false
        info(string.format("branch rule: new set on: %d of %d owned player(s) switched to branch 1 (switching off restores nothing)", n, total))
        SWEEP.report_next = RT.why or "option on"
        SWEEP.dirty, SWEEP.running = true, false
      end
    elseif n > 0 then
      info(string.format("branch rule: %d player(s) back on branch 1 (a recruit or a branch switch while the new set is on)", n))
    end
  end
  if not idle then return end
  if SWEEP.running then
    pcall(sweep_step)
  elseif SWEEP.dirty or now >= SWEEP.next_at then
    -- the tables follow the lists and boards (edited in either view) every ROUTE_EVERY_MS
    SWEEP.next_at = now + ROUTE_EVERY_MS
    local why = SWEEP.report_next
    SWEEP.report_next = nil
    local ok, e = pcall(sweep_start, RT.on == true, why)
    if not ok then
      SWEEP.running = false
      warn("sweep: " .. tostring(e))
    end
  end
end

-- WHO DRIVES THE STEP (2026-10-14, owner: Jade Beor wore Metis' armour with Magister in the table's aura half): the
-- trigger "tick" is the match's unit tick (Match.UnitTick), so it never fires in the menus, and in a match the step
-- waits for the menus (`idle`): the option edge, the branch rule, MixSlot and FormContext never ran (no «form
-- context» / «branch rule» line in loader.log; the form viewer fell back to its board scan and found Metis on board
-- slot 2). The menus drive it now: every menu that opens (the hook bus event menu:open, MENU_SLICES slices) and
-- this mod's own commands (at most one slice every COMMAND_STEP_EVERY_MS: the skill table, the player page and the
-- dock card ask for the shown card's projection while they are open). "tick" stays (harmless in a match).
-- a menu open runs at most MENU_SLICES slices and stops after MENU_STEP_BUDGET_MS (the rest on the next opens / commands)
local MENU_SLICES, MENU_STEP_BUDGET_MS, COMMAND_STEP_EVERY_MS = 8, 16, 250
local LAST_COMMAND_STEP = { at = -COMMAND_STEP_EVERY_MS }
local function menu_step()
  local started = VRFW.now()
  tick()
  for _ = 2, MENU_SLICES do
    if not SWEEP.running or VRFW.now() - started >= MENU_STEP_BUDGET_MS then break end
    sweep_step()
  end
end
function CharacterReforged.CommandStep()
  local now = VRFW.now()
  if LAST_COMMAND_STEP.at + COMMAND_STEP_EVERY_MS > now then return end
  LAST_COMMAND_STEP.at = now
  tick()
end

VRFW.on("tick", function() pcall(tick) end)
VRFW.on("menu:open:post", function() pcall(menu_step) end)
VRFW.on("slot_load", function()
  ST.slot, ST.st = -1, nil
  OWNED.list = nil
  RT.next_route = 0
  if RT.on then RT.edge, RT.why = true, "save loaded" end
  pcall(publish_defaults)
  SWEEP.dirty, SWEEP.running = true, false
end)
VRFW.on("game_reset", function()
  ST.slot, ST.st, RULES = -1, nil, nil
  AURA_TYPE_OF, SLOT_OF = {}, {}
  OWNED.list = nil
  DEF.done = false
  SWEEP.dirty, SWEEP.running = true, false
end)
-- (match_start: no publish any more; MixSlot is the last sweep's, at most a few seconds older than the kick-off and
-- written whole, never a partial table)
