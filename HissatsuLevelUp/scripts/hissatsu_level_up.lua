-- Hissatsu Level Up › special moves level up by use, per player and move (docs/game/mechanics/skill-rank-usage.md §7), the
-- move-rank items (docs/game/mechanics/move-rank-items.md) and the one-copy-per-set rule. The engine entries are
-- content\game\hissatsu_level_up.toml; the rules config.toml [ranks] / [duplicates] and every active mod's
-- content\hissatsu_level_up\*.toml [HissatsuLevelUp.Rules]. Moved from Inazuma Fantasy's scripts\skill_rank.lua on 2026-10-14
-- (docs/refactor/aura-mods-split.md «True Hissatsu»); same per-slot blob skill_uses.json (same bytes; IF's is imported
-- once, content\game\hissatsu_level_up.toml [[VRFW.SaveImport]]):
--
--   H1 HissatsuLevelUp.SkillUsed (post): a use of the user's player counts for his saved owner (VRFW.chara.owner_weak); a
--      crossed threshold raises the live rank (unit +0x45 + slot × 0x1C, read by the next use), the recast, the saved
--      skill_list entry ([record] + 0x54 + i × 8) and re-opens the skill-name banner (the level-up banner).
--   H2 HissatsuLevelUp.BuildSkillList (post): every active entry of a saved character's list gets the stored grade
--      ([ranks] mode "uses" = the grade, "max" = max(board duplicates, grade)); recruit grades (the cards'
--      VRFW.MoveGrades of any mod) are seeded into the store first, and a sweep seeds the saved characters' lists once
--      a minute.
--   H3 HissatsuLevelUp.MatchSkillInstall (post): recast = max(0, floor(info.recast × (1 + recast_per_grade × rank))).
--   Grade sync (1.1.1): after CMND_SET_SKILL (the skill tables write rank 0 with it), after every list rebuild
--      (chara:moves) and at each match install, the saved / live ranks of the user's players follow the stored
--      grades, so menus, match power and the grade cut-ins read the same grade.
--   H4 HissatsuLevelUp.CanEquip (post): a board placement of a move already on another slot of the player's active set is
--      refused ([duplicates] block).
--   Rules of other mods ([HissatsuLevelUp.Rules]): `no_rank_up_states` (state keys: while one is 1 no use is counted, e.g.
--      Inazuma Fantasy's INAROGUE), `boost_states` (CMND_HISSATSULEVELUP_RANK_BOOST only while one is 1),
--      `max_grade_states` (while one is 1 every move of the user's players is installed at the last grade in a match;
--      the saved grades do not change, e.g. an INAROGUE item for N matches). An overlay
--      session (VRFW.session.sink = the slot left): the left slot's store is parked in memory and comes back unchanged.
--   Grade animations ([[HissatsuLevelUp.GradeAnimation]] of every active mod's content\hissatsu_level_up\*.toml): from
--      `grade` on (1..6, 5 = G5) a move plays the cut-in of `animation_of`, its evolution; only the cut-in changes. Handed
--      once at start to the framework's grade cut-ins (VRFW.cutin.by_grade), which read the executor's live grade when
--      the cut-in starts (both teams, every match mode).
--
--   CMND_HISSATSULEVELUP_USES(charaStHdl, skillId) -> uses, grade, next threshold (0 at the maximum); errors -1, -1, 0 (bad
--        args) / -2, -2, 0 (not active)
--   CMND_HISSATSULEVELUP_RANK_SET(charaStHdl, skillId, grade) -> ok, grade (admin: uses = that grade's threshold)
--   CMND_HISSATSULEVELUP_RANK_BOOST(charaStHdl, skillId, steps) -> ok, grade, old grade; errors false, code, 0 (-1 bad
--        args, -2 not active, -3 no rule allows it now)
--   CMND_HISSATSULEVELUP_RANK_POPUP(skillId) -> pending, grade, "" (the graft sr_popup adds the text
--        HissatsuLevelUp.RankUpSuffix with the display level)
--   CMND_HISSATSULEVELUP_RANK_ITEMS() -> raise item id, last-grade item id, use cap, last grade (0 = not configured)
--   CMND_HISSATSULEVELUP_RANK_ITEM(charaStHdl, skillId, itemId, apply) -> code, old grade, new grade: code 0 = applicable
--        (applied when `apply`), 1 not a rank item, 2 the move has no grade (aura / spirit), 3 the item's cap is reached,
--        4 the last-grade item needs the second-to-last grade, 5 the move is in neither the player's list nor his
--        board, -1 bad args, -2 not active. The caller (the skill views, graft move_rank_items) takes the item off
--        the bag.
--   CMND_HISSATSULEVELUP_CAN_PLACE(charaStHdl, boardSlot, itemId) -> ok, the other slot holding it (-1 = none)
--   CMND_HISSATSULEVELUP_RETAIL_STOCK(count) -> count -1: the active save slot still needs its line; count >= 0
--        (the save's abl_000001 stock, from the graft sr_popup): logs it once per slot. The retail «Nueva posibilidad»
--        is no longer the upgrade book (1.0.4: own item technique_upgrade_book); its stock is never converted.
--
-- Rule (2026-10-11, owner): rank-up by use stops at the second-to-last grade ([ranks] last_grade_item_only, default
-- true); only the last-grade item reaches the last grade. Grades already stored at the last grade are kept.
-- Store commit: staged with the game's own save of the slot (VRFW.save.blob_stage) while the slot service runs, else
-- written at once. Nothing calls the game at load: start() reads files only.

local A = require "lib/auras"

HissatsuLevelUp = HissatsuLevelUp or {}
HissatsuLevelUp.Cmd = HissatsuLevelUp.Cmd or {}
local TH = HissatsuLevelUp

local function info(...) VRFW.log("HissatsuLevelUp:", ...) end
local function warn(...) VRFW.warn("HissatsuLevelUp:", ...) end
local function err(...) VRFW.error("HissatsuLevelUp:", ...) end
local band, rshift = bit32.band, bit32.rshift

local TWO32 = 4294967296
local function u32(v)
  if type(v) ~= "number" then return 0 end
  local n = v >= 0 and math.floor(v) or math.ceil(v)
  return n % TWO32
end

local function hex(v) return string.format("0x%08X", v or 0) end

-- a value of this mod's merged config.toml (dotted path), `default` when missing or of another type
local function cfg(path, default)
  local ok, v = pcall(VRFW.files.config, path)
  if not ok or v == nil then return default end
  if default ~= nil and type(v) ~= type(default) then return default end
  return v
end

-- ------------------------------------------------------------------------------------------------ layout
local BLOB = "skill_uses.json"
local FILE_VERSION = 1
local MAX_GRADE = 5
local ACTOR_STRIDE, ACTOR_MAX, ACTOR_HDL, ACTOR_TEAM = 0x570, 0x3A, 0x94, 0xD0
local UNIT_STRIDE, UNIT_MAX, UNIT_HDL, UNIT_CHARA = 0x380, 0x60, 0x368, 0x370
local UNIT_SKILLS, UNIT_SKILL_STRIDE, UNIT_SKILL_RANK, UNIT_SKILL_RECAST = 0x30, 0x1C, 0x15, 0x04
local MATCH_USER_TEAM = 0x2C29
local INFO_RECAST = 0x34
local REC_SKILL_LIST, SKILL_ENTRY, SKILL_SLOTS = 0x50, 8, 6
local REC_PLACED, REC_NATIVE, BOARD_SLOTS = 0x94, 0xC8, 9
local POPUP_TTL_MS, POPUP_MAX = 8000, 16
local MATCH_GAP_MS = 30000
local SWEEP_EVERY_MS = 60000
local SEED_LOG_MAX = 24
local ERR_BAD_ARGS, ERR_NOT_READY, ERR_NOT_ALLOWED = -1, -2, -3

-- ------------------------------------------------------------------------------------------------ config
local ON = false
-- the use curve: total uses for grade 1, 2, ... (config [ranks] thresholds; this is only the fallback when the key is
-- missing, the same curve config.toml declares: G5 = grade 4 at 120 uses)
local DEFAULT_TH = { 10, 25, 50, 120 }
local THR = DEFAULT_TH
local MODE = "uses"
local LOG_USES = true
local K = 0.025          -- recast_per_grade (as f32)
local POPUP = true
local USE_CAP = MAX_GRADE - 1   -- the highest grade earned by use ([ranks] last_grade_item_only)
local ITEM_RAISE, ITEM_LAST = 0, 0   -- [ranks] raise_item / last_grade_item (item ids; 0 = not configured)
local BLOCK_DUP = true               -- [duplicates] block

local function now_ms() return VRFW.now() end

local function rd(t, a)
  if not a or a < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, t, a)
  if ok then return v end
  return nil
end

local function wr(t, a, v)
  return (pcall(VRFW.mem.write, t, a, v))
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

-- f32 rounding (the engine computes the recast in single precision)
local F32 = nil
local function f32(x)
  F32 = F32 or VRFW.mem.buffer("HissatsuLevelUp.f32", 8)
  wr("f32", F32, x)
  return rd("f32", F32) or x
end

-- ------------------------------------------------------------------------------------------------ other mods' rules
-- [HissatsuLevelUp.Rules] of every active mod's content\hissatsu_level_up\*.toml, later mods win key by key
local RULES = nil

local function rules()
  if RULES then return RULES end
  RULES = {}
  local ok, decl = pcall(VRFW.files.declarations, "content/hissatsu_level_up")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local r = type(d) == "table" and type(d.HissatsuLevelUp) == "table" and d.HissatsuLevelUp.Rules or nil
    if type(r) == "table" then
      for k, v in pairs(r) do RULES[k] = v end
    end
  end
  return RULES
end

-- ------------------------------------------------------------------------------------------------ grade animations
-- [[HissatsuLevelUp.GradeAnimation]] of every active mod's content\hissatsu_level_up\*.toml, in load order: `technique`,
-- `grade` (1..6: 1 = the first grade, 5 = G5, 6 = the last) and `animation_of` (the move whose cut-in plays). A later
-- entry for the same move and grade replaces an earlier one; `enabled = false` takes it off.
local function grade_animations()
  local by_key, order = {}, {}
  local ok, decl = pcall(VRFW.files.declarations, "content/hissatsu_level_up")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local list = type(d) == "table" and type(d.HissatsuLevelUp) == "table" and d.HissatsuLevelUp.GradeAnimation or nil
    for i, e in ipairs(type(list) == "table" and list or {}) do
      local where = string.format("%s %s entry %d", tostring(f.mod), tostring(f.file), i)
      local t, g, a = type(e) == "table" and e.technique, type(e) == "table" and tonumber(e.grade), type(e) == "table" and e.animation_of
      local ref_ok = function(v) return (type(v) == "string" and v ~= "") or type(v) == "number" end
      if not ref_ok(t) or not g or g ~= math.floor(g) or g < 1 or g > MAX_GRADE + 1 then
        warn(string.format("[[HissatsuLevelUp.GradeAnimation]] %s: needs `technique` and `grade` 1..%d: left out", where, MAX_GRADE + 1))
      else
        local key = tostring(t) .. "#" .. g
        if by_key[key] == nil then order[#order + 1] = key end
        if e.enabled == false then
          by_key[key] = false
        elseif not ref_ok(a) then
          warn(string.format("[[HissatsuLevelUp.GradeAnimation]] %s: needs `animation_of` (the move whose cut-in plays): left out", where))
        else
          by_key[key] = { technique = t, grade = g, cutin_of = a }
        end
      end
    end
  end
  local out = {}
  for _, k in ipairs(order) do
    if by_key[k] then out[#out + 1] = by_key[k] end
  end
  return out
end

-- the declared grade animations handed to the framework (once, at start: no game call)
local function apply_grade_animations()
  local list = grade_animations()
  if #list == 0 then
    info("grade animations: none declared")
    return
  end
  local ok, n, why = pcall(VRFW.cutin.by_grade, list)
  if not ok or not n then
    err("grade animations off: " .. tostring(ok and why or n))
    return
  end
  local parts = {}
  for _, e in ipairs(list) do
    parts[#parts + 1] = string.format("%s from grade %d plays %s's cut-in", tostring(e.technique), e.grade, tostring(e.cutin_of))
  end
  info(string.format("grade animations on (%d): %s; titles: %s", #list, table.concat(parts, "; "), tostring(why or "-")))
end

-- is one of the state keys of rule `name` set (= 1) now? the key's name when so
local function state_on(name)
  local keys = rules()[name]
  if type(keys) ~= "table" then return nil end
  for _, k in ipairs(keys) do
    if type(k) == "string" then
      local ok, v = pcall(VRFW.state.get, k)
      if ok and (v == 1 or v == true) then return k end
    end
  end
  return nil
end

-- ------------------------------------------------------------------------------------------------ thresholds / mode
local function thresholds_ok(v)
  if type(v) ~= "table" or #v == 0 or #v > MAX_GRADE then return false, tostring(type(v) == "table" and #v or 0) .. " thresholds (need 1..=5)" end
  if (tonumber(v[1]) or 0) < 1 then return false, "thresholds must be >= 1" end
  for i = 2, #v do
    if (tonumber(v[i]) or 0) <= (tonumber(v[i - 1]) or 0) then return false, "thresholds are not strictly increasing" end
  end
  return true
end

local function max_grade() return #THR end

local function grade_for(uses)
  local g = 0
  for _, t in ipairs(THR) do
    if uses >= t then g = g + 1 else break end
  end
  return g
end

-- the highest grade uses can reach: the thresholds' maximum, capped at USE_CAP
local function use_cap() return math.min(max_grade(), USE_CAP) end

local function next_at(grade)
  if grade >= use_cap() then return 0 end
  return THR[grade + 1] or 0
end

local function uses_for(grade)
  if grade == 0 then return 0 end
  return THR[math.min(grade, max_grade())]
end

local function mode_rank(dup, grade)
  local r = MODE == "max" and math.max(dup, grade) or grade
  return math.min(r, MAX_GRADE)
end

-- ------------------------------------------------------------------------------------------------ the store
-- { slot, map = { [chara] = { [skill] = { uses, grade } } }, n, dirty }
local function new_store(slot) return { slot = slot, map = {}, n = 0, dirty = false } end

local function get(st, c, s)
  local m = st.map[c]
  local e = m and m[s]
  if e then return e[1], e[2] end
  return 0, 0
end

local function has(st, c, s)
  local m = st.map[c]
  return m ~= nil and m[s] ~= nil
end

local function put(st, c, s, uses, grade)
  local m = st.map[c]
  if not m then m = {}; st.map[c] = m end
  if not m[s] then st.n = st.n + 1 end
  m[s] = { uses, grade }
  st.dirty = true
end

local function remove(st, c, s)
  local m = st.map[c]
  if m and m[s] then
    m[s] = nil
    st.n = st.n - 1
    if next(m) == nil then st.map[c] = nil end
  end
  st.dirty = true
end

local function add_use(st, c, s)
  local uses, old = get(st, c, s)
  uses = math.min(uses + 1, 4294967295)
  local g = math.min(math.max(old, math.min(grade_for(uses), use_cap())), MAX_GRADE)
  put(st, c, s, uses, g)
  return uses, old, g
end

local function set_grade(st, c, s, grade)
  local g = math.min(grade, max_grade(), MAX_GRADE)
  if g == 0 then
    remove(st, c, s)
    return 0, 0
  end
  put(st, c, s, uses_for(g), g)
  return uses_for(g), g
end

-- a recruit grade: only for a key with no record
local function seed(st, c, s, grade)
  if c == 0 or s == 0 or has(st, c, s) then return nil end
  local g = math.min(grade, max_grade(), MAX_GRADE)
  if g == 0 then return nil end
  put(st, c, s, uses_for(g), g)
  return g, uses_for(g)
end

local function boost(st, c, s, base, steps)
  if base then seed(st, c, s, base) end
  local _, og = get(st, c, s)
  local want = math.min(og + steps, max_grade(), MAX_GRADE)
  if c == 0 or s == 0 or want == og then return og, og end
  local _, g = set_grade(st, c, s, want)
  return og, g
end

local function to_json(st)
  local rows = {}
  for c, m in pairs(st.map) do
    for s, e in pairs(m) do rows[#rows + 1] = { c, s, e[1], e[2] } end
  end
  table.sort(rows, function(a, b)
    for i = 1, 4 do
      if a[i] ~= b[i] then return a[i] < b[i] end
    end
    return false
  end)
  local p = {}
  for i, r in ipairs(rows) do p[i] = string.format("[%.0f,%.0f,%.0f,%.0f]", r[1], r[2], r[3], r[4]) end
  return string.format('{"version":%d,"slot":%d,"entries":[%s]}', FILE_VERSION, st.slot, table.concat(p, ","))
end

-- slot `slot`'s store: no blob = empty; an unreadable one is set aside (logged) and the store starts empty
local function load_store(slot)
  local st = new_store(slot)
  local text, why = VRFW.save.blob(BLOB, slot)
  if text == nil and why ~= nil then
    local where = VRFW.save.blob_aside(BLOB, slot)
    err(string.format("slot %d: %s: %s; set aside to %s; starting empty", slot, BLOB, tostring(why), tostring(where)))
    return st
  end
  if text ~= nil then
    local j, jerr = VRFW.json.decode(text)
    local bad = j == nil and tostring(jerr) or (type(j) ~= "table" and "not an object")
      or (j.version ~= FILE_VERSION and ("unknown version " .. tostring(j.version))) or nil
    if bad then
      local where = VRFW.save.blob_aside(BLOB, slot)
      err(string.format("slot %d: %s: %s; set aside to %s; starting empty", slot, BLOB, bad, tostring(where)))
      return st
    end
    for _, e in ipairs(type(j.entries) == "table" and j.entries or {}) do
      local c, s = u32(e[1]), u32(e[2])
      if c ~= 0 and s ~= 0 then
        local m = st.map[c]
        if not m then m = {}; st.map[c] = m end
        if not m[s] then st.n = st.n + 1 end
        m[s] = { u32(e[3]), math.min(tonumber(e[4]) or 0, MAX_GRADE) }
      end
    end
  end
  st.dirty = false
  info(string.format("slot %d: %d (player, move) entries loaded", slot, st.n))
  -- aura skills (keshin, armed, miximax, totem, mode…) never have grades: old ones are cleared (never slot 1)
  if slot >= 2 then
    local n = 0
    for c, m in pairs(st.map) do
      for s in pairs(m) do
        if A.type(s) ~= nil then
          remove(st, c, s)
          n = n + 1
        end
      end
    end
    if n > 0 then
      local ok, where = VRFW.save.blob_write(BLOB, to_json(st), slot)
      if ok then
        st.dirty = false
        info(string.format("slot %d: %d aura-skill entries removed (aura skills have no grade)", slot, n))
      else
        err(string.format("slot %d: cannot write after removing %d aura entries: %s", slot, n, tostring(where)))
      end
    end
  end
  return st
end

local store = new_store(0)
local parked = nil

local function current_slot()
  local okr, ready = pcall(VRFW.slots.ready)
  if not (okr and ready) then return 1 end
  local ok, s = pcall(VRFW.slots.active)
  return ok and tonumber(s) or 1
end

local function commit_on_save()
  local ok, ready = pcall(VRFW.slots.ready)
  return ok and ready == true
end

-- the store of the active slot (reloaded when the slot changed; uses the game never saved are dropped). An overlay
-- session (the session's sink holds the slot left, e.g. INAROGUE over a normal slot): the left store is parked as it
-- is and comes back unchanged with that slot (the overlay restores that game from memory)
local function cur()
  local slot = current_slot()
  if store.slot == slot then return store end
  local from = store.slot
  local okk, sink = pcall(VRFW.session.sink)
  local overlay_in = from ~= 0 and okk and sink == from
  if overlay_in then
    info(string.format("overlay session over slot %d: its store is parked in memory (%d entries%s), slot %d's store is loaded; slot %d's data is not written meanwhile",
      from, store.n, store.dirty and ", uses not saved by the game yet kept" or "", slot, from))
    parked = store
    store = load_store(slot)
  elseif parked and parked.slot == slot then
    if store.dirty then warn(string.format("slot %d -> %d: dropping uses not saved by the game", from, slot)) end
    store = parked
    parked = nil
    info(string.format("slot %d is back after the overlay session: its parked store is used again (%d entries)", slot, store.n))
    if store.dirty and commit_on_save() then
      pcall(VRFW.save.blob_stage, BLOB, to_json(store), slot)
    end
  else
    if store.dirty and from ~= 0 then warn(string.format("slot %d -> %d: dropping uses not saved by the game", from, slot)) end
    parked = nil
    store = load_store(slot)
  end
  return store
end

-- the store's changes: staged with the game's save of the slot, or written now (`now`, or no slot service)
local function commit(st, why, now)
  if not st.dirty then return end
  local text = to_json(st)
  if not now and commit_on_save() then
    local ok, e = VRFW.save.blob_stage(BLOB, text, st.slot)
    if ok then return end
    warn("stage failed (" .. tostring(e) .. "): written now")
  end
  local ok, where = VRFW.save.blob_write(BLOB, text, st.slot)
  if ok then
    st.dirty = false
  else
    err(string.format("cannot write slot %d (%s): %s", st.slot, why, tostring(where)))
  end
end

-- ------------------------------------------------------------------------------------------------ recruit grades
local grades_cache = {}

-- the declared (move -> grade) of a card (nil until the framework built its characters; {} = none)
local function grades_of(param)
  if param == 0 then return {} end
  local c = grades_cache[param]
  if c then return c end
  local ok, list = pcall(VRFW.traits.move_grades, param)
  if not ok or type(list) ~= "table" then return {} end
  c = {}
  for _, e in ipairs(list) do
    local m, g = u32(e[1]), tonumber(e[2]) or 0
    if m ~= 0 and g > 0 and c[m] == nil then c[m] = g end
  end
  grades_cache[param] = c
  return c
end

local function record(hdl)
  local ok, r = pcall(VRFW.chara.record, hdl)
  if ok and type(r) == "table" then return r end
  return nil
end

-- ------------------------------------------------------------------------------------------------ game memory
local function is_saved_handle(h)
  local k = band(rshift(h, 12), 0xF)
  return h ~= 0 and (k == 0 or k == 7)
end

local function is_chara_handle(h)
  local k = band(rshift(h, 12), 0xF)
  return h ~= 0 and k < 0xD and k ~= 6
end

local function owner(h, weak)
  if h == 0 then return nil end
  local ok, o = pcall(weak and VRFW.chara.owner_weak or VRFW.chara.owner, h)
  if ok and type(o) == "number" and o ~= 0 then return o end
  return nil
end

-- the saved skill_list rank of `skill` for character `hdl` rewritten with f(current) (nil = keep): i, old, new
local function write_saved_rank(hdl, skill, f)
  local r = record(hdl)
  if not r or not r.addr then return nil end
  for i = 0, SKILL_SLOTS - 1 do
    local e = r.addr + REC_SKILL_LIST + i * SKILL_ENTRY
    if rd("u32", e) == skill then
      local cur_r = rd("u8", e + 4)
      if cur_r == nil then return nil end
      local n = f(cur_r)
      if n ~= nil and n ~= cur_r and wr("u8", e + 4, n) then return i, cur_r, n end
      return i, cur_r, cur_r
    end
  end
  return nil
end

local function unit_slot(unit, skill)
  for i = 0, SKILL_SLOTS - 1 do
    if rd("u32", unit + UNIT_SKILLS + i * UNIT_SKILL_STRIDE) == skill then return i end
  end
  return nil
end

local function live_rank_addr(unit, slot) return unit + UNIT_SKILLS + slot * UNIT_SKILL_STRIDE + UNIT_SKILL_RANK end

-- ------------------------------------------------------------------------------------------------ recast (H3)
local INFO_OUT, SKILL_ID = nil, nil
local install_hits = 0

local function recast_value(base, rank)
  if base ~= base or base == math.huge or base == -math.huge then return 0 end
  local m = f32(1.0 + f32(K * math.min(rank, MAX_GRADE)))
  return math.max(math.floor(f32(base * m)), 0)
end

-- the recast of unit entry `slot` from the skill table and the entry's rank: skill, rank, old, new
local function apply_recast(unit, slot)
  if slot >= SKILL_SLOTS then return nil end
  local entry = unit + UNIT_SKILLS + slot * UNIT_SKILL_STRIDE
  local id = rd("u32", entry)
  if not id or id == 0 then return nil end
  local rank = rd("u8", entry + UNIT_SKILL_RANK)
  local tbl = global("hissatsu_level_up_skill_table")
  if not rank or not tbl then return nil end
  INFO_OUT = INFO_OUT or VRFW.mem.buffer("HissatsuLevelUp.info", 8)
  SKILL_ID = SKILL_ID or VRFW.mem.buffer("HissatsuLevelUp.id", 8)
  wr("ptr", INFO_OUT, 0)
  wr("u32", SKILL_ID, id)
  if not pcall(VRFW.call, "Technique.SkillInfoFind", tbl, INFO_OUT, SKILL_ID) then return nil end
  local inf = rd("ptr", INFO_OUT) or 0
  if inf < 0x10000 then return nil end -- not a table skill: the engine did not scale its recast either
  local base = rd("f32", inf + INFO_RECAST)
  local old = rd("f32", entry + UNIT_SKILL_RECAST)
  if not base or not old then return nil end
  local new = recast_value(base, rank)
  if old ~= new then wr("f32", entry + UNIT_SKILL_RECAST, new) end
  return id, rank, old, new
end

-- ------------------------------------------------------------------------------------------------ no rank-up rules
local match_epoch, last_install, rule_logged = 1, 0, 0

local function log_rule(key, why)
  if rule_logged == match_epoch then return end
  rule_logged = match_epoch
  info("rank-up by use off while " .. key .. " ([HissatsuLevelUp.Rules] no_rank_up_states; " .. why .. "): moves keep their grades; no use counted, no grade-up, no banner")
end

local function note_install()
  local now = math.max(now_ms(), 1)
  local prev = last_install
  last_install = now
  if prev == 0 or now - prev > MATCH_GAP_MS then
    match_epoch = match_epoch + 1
    if ON then
      local k = state_on("no_rank_up_states")
      if k then log_rule(k, "match setup") end
    end
  end
end

-- ------------------------------------------------------------------------------------------------ banner
local popups = {}   -- { { skill, grade, at } } oldest first
local telop_ok = true

local function popup_prune(now)
  local keep = {}
  for _, p in ipairs(popups) do
    if now - p.at <= POPUP_TTL_MS then keep[#keep + 1] = p end
  end
  popups = keep
end

local function popup_push(skill, grade)
  local now = now_ms()
  popup_prune(now)
  for i = #popups, 1, -1 do
    if popups[i].skill == skill then table.remove(popups, i) end
  end
  if #popups >= POPUP_MAX then table.remove(popups, 1) end
  popups[#popups + 1] = { skill = skill, grade = grade, at = now }
end

local function popup_take(skill)
  popup_prune(now_ms())
  for i, p in ipairs(popups) do
    if p.skill == skill then
      table.remove(popups, i)
      return p.grade
    end
  end
  return nil
end

local function show_popup(skill, grade)
  if not (POPUP and telop_ok) then return "" end
  popup_push(skill, grade)
  SKILL_ID = SKILL_ID or VRFW.mem.buffer("HissatsuLevelUp.id", 8)
  wr("u32", SKILL_ID, skill)
  local ok, e = pcall(VRFW.call, "HissatsuLevelUp.OpenSkillTelop", SKILL_ID)
  if ok then return ", banner opened" end
  err("OpenCommonSkillTelop failed (" .. tostring(e) .. "): banner disabled")
  telop_ok = false
  return ", banner FAILED"
end

-- ------------------------------------------------------------------------------------------------ H1
local used_hits = 0

-- threshold crossed: live match rank (the next use has the new power) + saved skill_list entry
local function raise(unit, slot, own, chara, skill, old_grade, grade)
  local g = math.min(grade, MAX_GRADE)
  local live
  if slot then
    local a = live_rank_addr(unit, slot)
    local c = rd("u8", a)
    if c and c < g then
      wr("u8", a, g)
      local _, _, o, n = apply_recast(unit, slot)
      live = o and string.format("live %d->%d, recast %s->%s", c, g, tostring(o), tostring(n)) or string.format("live %d->%d", c, g)
    elseif c then
      live = string.format("live %d kept", c)
    else
      live = "live unreadable"
    end
  else
    live = "live: move not in unit table"
  end
  local up = function(c) if c < g then return g end return nil end
  local i, o, n = write_saved_rank(own, skill, up)
  local saved = i and string.format("saved list[%d] %d->%d", i, o, n) or "saved: move not in skill_list"
  if chara ~= own then
    -- the match copy's own list (skills are installed from it; keeps a later reinstall in this match right)
    local ci, co, cn = write_saved_rank(chara, skill, up)
    if ci then saved = saved .. string.format(", copy list[%d] %d->%d", ci, co, cn) end
  end
  return string.format("; GRADE UP %d->%d: %s, %s%s", old_grade, g, live, saved, show_popup(skill, g))
end

local function on_used(ev)
  if not ON then return end
  local hdl = u32(ev.args[1])
  local skill = rd("u32", ev.args[2] or 0)
  if not skill or skill == 0 then return end
  if A.type(skill) ~= nil then return end -- aura skills have no grade
  if A.is_spirit_move(skill) then
    info(string.format("spirit move %s used by actor 0x%X: non-miximax aura move, no grade (not counted)", hex(skill), hdl))
    return
  end
  local off = state_on("no_rank_up_states")
  if off then
    log_rule(off, "first move used")
    return
  end
  used_hits = used_hits + 1
  local n = used_hits
  local idx = band(hdl, 0xFF)
  if hdl == 0 or idx >= ACTOR_MAX then return end
  local actors = global("Match.SoccerActors.ViaSkillUsed")
  if not actors then return end
  local actor = actors + idx * ACTOR_STRIDE
  if rd("u32", actor + ACTOR_HDL) ~= hdl then return end
  local team = rd("u8", actor + ACTOR_TEAM)
  local okc, unit = pcall(VRFW.call, "Match.ActorUnit", actor)
  unit = (okc and type(unit) == "number") and unit or 0
  local chara = unit >= 0x10000 and (rd("u32", unit + UNIT_CHARA) or 0) or 0
  local m = global("hissatsu_level_up_match")
  local user = m and rd("u8", m + MATCH_USER_TEAM)
  if team == nil or team ~= user then return end
  local own = owner(chara, true)
  if not own then
    info(string.format("call #%d actor 0x%X skill %s: unit 0x%X chara %s (kind %d) has no saved owner: not counted",
      n, hdl, hex(skill), unit, hex(chara), band(rshift(chara, 12), 0xF)))
    return
  end
  local slot = unit_slot(unit, skill)
  local st = cur()
  -- a recruit grade not seeded yet (no list build saw the move): seeded first, so the use counts on top of it
  local r = record(own)
  local param = r and u32(r.param) or 0
  local rg = grades_of(param)[skill]
  if rg then
    local sg, su = seed(st, own, skill, rg)
    if sg then
      info(string.format("recruit grade: chara %s (card %s) skill %s starts at grade %d (uses %d) [first use]", hex(own), hex(param), hex(skill), sg, su))
    end
  end
  local uses, old, g = add_use(st, own, skill)
  commit(st, "use")
  local extra = ""
  if g > old then extra = raise(unit, slot, own, chara, skill, old, g) end
  if LOG_USES or g > old then
    info(string.format("use #%d: chara %s (match chara %s kind %d, actor 0x%X) skill %s unit slot %s -> uses %d, grade %d (next at %d)%s",
      n, hex(own), hex(chara), band(rshift(chara, 12), 0xF), hdl, hex(skill), tostring(slot), uses, g, next_at(g), extra))
  end
end

-- ------------------------------------------------------------------------------------------------ H2
local swept_slot, swept_at = nil, 0
local build_kinds = {}
-- the sweep walks the saved characters a few at a time (one list build = one step): a whole save in one hook call
-- used up the script's CPU budget and switched the script off
local SWEEP_STEP = 200
local sweep_list, sweep_pos, sweep_todo = nil, 1, nil

-- recruit grades of saved characters whose list is not rebuilt (existing saves): every saved character whose card
-- declares move_grades and whose saved skill_list holds such a move with no record gets it seeded and the saved rank
-- raised to it (never lowered); at a slot change and at most once a minute
local function sweep_finish(slot, total)
  local todo = sweep_todo or {}
  sweep_list, sweep_pos, sweep_todo = nil, 1, nil
  if #todo == 0 then return end
  local st = cur()
  local seeded, charas, raised = 0, {}, 0
  for _, t in ipairs(todo) do
    local g, u = seed(st, t[1], t[3], t[4])
    if g then
      seeded = seeded + 1
      charas[t[1]] = true
      local i, o, nr = write_saved_rank(t[1], t[3], function(c) if g > c then return g end return nil end)
      if i and nr > o then raised = raised + 1 end
      if seeded <= SEED_LOG_MAX then
        info(string.format("recruit grade: chara %s (card %s) skill %s starts at grade %d (uses %d), saved list %s [sweep]",
          hex(t[1]), hex(t[2]), hex(t[3]), g, u, i and string.format("[%d] %d->%d", i, o, nr) or "none"))
      end
    end
  end
  if seeded == 0 then return end
  local nc = 0
  for _ in pairs(charas) do nc = nc + 1 end
  info(string.format("recruit grades sweep (slot %d): %d move(s) seeded on %d saved character(s), %d saved rank(s) raised (%d saved records scanned)",
    slot, seeded, nc, raised, total))
  commit(st, "recruit grades sweep")
end

local function sweep()
  local slot = current_slot()
  if sweep_list == nil then
    local now = now_ms()
    if swept_slot == slot and now - swept_at < SWEEP_EVERY_MS then return end
    swept_slot, swept_at = slot, now
    local ok, saved = pcall(VRFW.chara.saved)
    if not ok or type(saved) ~= "table" then return end
    sweep_list, sweep_pos, sweep_todo = saved, 1, {}
  elseif swept_slot ~= slot then
    sweep_list, sweep_pos, sweep_todo = nil, 1, nil   -- the slot changed mid-walk: start again on the next build
    return
  end
  local saved, todo = sweep_list, sweep_todo
  local last = math.min(#saved, sweep_pos + SWEEP_STEP - 1)
  for n = sweep_pos, last do
    local k = saved[n]
    local param = u32(k.param)
    local declared = grades_of(param)
    if next(declared) ~= nil then
      local r = record(u32(k.handle))
      if r and r.addr then
        for i = 0, SKILL_SLOTS - 1 do
          local id = rd("u32", r.addr + REC_SKILL_LIST + i * SKILL_ENTRY)
          if id and id ~= 0 and not A.is_spirit_move(id) and declared[id] then
            todo[#todo + 1] = { u32(k.handle), param, id, declared[id] }
          end
        end
      end
    end
  end
  sweep_pos = last + 1
  if sweep_pos > #saved then sweep_finish(slot, #saved) end
end

local function on_build(ev)
  if not ON then return end
  local obj, list = ev.args[1] or 0, ev.args[2] or 0
  local rec = rd("ptr", obj + 8)
  local hdl = rec and rd("u32", rec)
  if not hdl or not is_chara_handle(hdl) then return end
  local own = owner(hdl, false)
  if not own then return end
  local entries, count = rd("ptr", list), rd("u64", list + 8)
  if not entries or not count then return end
  count = math.min(count, 16)
  local r = record(own)
  local param = r and u32(r.param) or 0
  local declared = grades_of(param)
  local st = cur()
  local changes, seeded = {}, false
  for i = 0, count - 1 do
    local e = entries + i * SKILL_ENTRY
    local id, flag, dup = rd("u32", e), rd("u8", e + 6), rd("u8", e + 4)
    if id and flag and dup and id ~= 0 and flag == 0 and not A.is_spirit_move(id) then
      local dg = declared[id]
      if dg then
        local sg, su = seed(st, own, id, dg)
        if sg then
          seeded = true
          info(string.format("recruit grade: chara %s (card %s) skill %s starts at grade %d (uses %d) [list build]", hex(own), hex(param), hex(id), sg, su))
        end
      end
      local _, g = get(st, own, id)
      local rank = mode_rank(dup, g)
      if rank ~= dup and wr("u8", e + 4, rank) then
        changes[#changes + 1] = string.format("(%s, %d, %d)", hex(id), dup, rank)
      end
    end
  end
  if seeded then commit(st, "recruit grade") end
  sweep()
  local kind = band(rshift(hdl, 12), 0xF)
  if not build_kinds[kind] then
    build_kinds[kind] = true
    info(string.format("first skill_list build of kind %d: chara %s (owner %s), %d entries, (skill, dupRank, rank) [%s]",
      kind, hex(hdl), hex(own), count, table.concat(changes, ", ")))
  end
end

-- ------------------------------------------------------------------------------------------------ H3
-- ------------------------------------------------------------------------------------------------ grade sync
-- The stored grade is the move's grade everywhere: menus (their evolution glyph, plate base and graded power read the
-- saved skill_list rank through GetSkillEvoLevelByCharaStHdl), the match (the unit rank copied at kick-off) and the
-- framework's grade cut-ins (the live unit rank). Every writer of a player's list is followed by a sync: the board's
-- rebuild (H2), CMND_SET_SKILL (the skill tables place moves with it: it writes rank 0) and the match install (H3).

-- the saved skill_list ranks of character `hdl` set to the stored grades ([ranks] mode): changes as "(skill, old, new)"
local function sync_saved_ranks(hdl)
  if not ON or not hdl or hdl == 0 or not is_chara_handle(hdl) then return {} end
  local r = record(hdl)
  if not r or not r.addr then return {} end
  local own = owner(hdl, false) or hdl
  local st = cur()
  local declared = grades_of(u32(r.param))
  local changes, seeded = {}, false
  for i = 0, SKILL_SLOTS - 1 do
    local e = r.addr + REC_SKILL_LIST + i * SKILL_ENTRY
    local id, cur_r = rd("u32", e), rd("u8", e + 4)
    if id and id ~= 0 and cur_r and A.type(id) == nil and not A.is_spirit_move(id) then
      if declared[id] and seed(st, own, id, declared[id]) then seeded = true end
      local _, g = get(st, own, id)
      local want = mode_rank(cur_r, g)
      if want ~= cur_r and wr("u8", e + 4, want) then
        changes[#changes + 1] = string.format("(%s, %d, %d)", hex(id), cur_r, want)
      end
    end
  end
  if seeded then commit(st, "recruit grade") end
  return changes
end

-- after CMND_SET_SKILL(charaStHdl, skill, slot): the list's ranks follow the store again (VRFW.CommandFilter, after)
function HissatsuLevelUp.AfterSetSkill(args)
  local hdl = u32(type(args) == "table" and tonumber(args[1]) or 0)
  local changes = sync_saved_ranks(hdl)
  if #changes > 0 then
    info(string.format("CMND_SET_SKILL on chara %s: saved ranks follow the stored grades [%s]", hex(hdl), table.concat(changes, ", ")))
  end
  return nil
end

-- after RebuildSkillList (event chara:moves; the board hook H2 may have been skipped while the scripts were busy)
local function on_moves(ev)
  local obj = ev.args and ev.args[1] or 0
  if obj < 0x10000 then return end
  local rec = rd("ptr", obj + 8)
  local hdl = rec and rd("u32", rec)
  local changes = sync_saved_ranks(hdl)
  if #changes > 0 then
    info(string.format("list rebuilt for chara %s: saved ranks follow the stored grades [%s]", hex(hdl), table.concat(changes, ", ")))
  end
end

-- the live rank of an installed move of the user's player = the stored grade ([ranks] mode), before its recast
local install_synced = 0
local function sync_install_rank(unit, slot)
  if slot >= SKILL_SLOTS then return end
  local entry = unit + UNIT_SKILLS + slot * UNIT_SKILL_STRIDE
  local id, cur_r = rd("u32", entry), rd("u8", entry + UNIT_SKILL_RANK)
  if not id or id == 0 or not cur_r or A.type(id) ~= nil or A.is_spirit_move(id) then return end
  local chara = rd("u32", unit + UNIT_CHARA) or 0
  local own = chara ~= 0 and owner(chara, false) or nil
  if not own then return end -- an opponent keeps his team's grade
  local _, g = get(cur(), own, id)
  local want = mode_rank(cur_r, g)
  if state_on("max_grade_states") then want = MAX_GRADE end
  if want ~= cur_r and wr("u8", entry + UNIT_SKILL_RANK, want) then
    install_synced = install_synced + 1
    if install_synced <= 24 then
      info(string.format("match install: chara %s (owner %s) skill %s live rank %d -> %d (stored grade)", hex(chara), hex(own), hex(id), cur_r, want))
    end
  end
end

local function on_install(ev)
  note_install()
  local unit = ev.args[1] or 0
  if unit < 0x10000 then return end
  sync_install_rank(unit, band(ev.args[2] or 0, 0xFF))
  local id, rank, old, new = apply_recast(unit, band(ev.args[2] or 0, 0xFF))
  if id then
    install_hits = install_hits + 1
    if install_hits == 1 then
      local ch = rd("u32", unit + UNIT_CHARA) or 0
      info(string.format("first recast install: unit chara %s (kind %d) skill %s rank %d: %s -> %s", hex(ch), band(rshift(ch, 12), 0xF), hex(id), rank, tostring(old), tostring(new)))
    end
  end
end

-- ------------------------------------------------------------------------------------------------ one copy per set (H4)
local function item_of(inv)
  if not inv or inv == 0 then return 0 end
  local ok, item = pcall(VRFW.item.of_inv, inv)
  return ok and u32(item or 0) or 0
end

-- is board slot `s` part of the same active set as target `t`? The two branches (3-5 and 6-8) are never active
-- together (the game's own CanEquip skips the other branch the same way); 0xFF / out of range = every slot counts
local function same_set(t, s)
  if t == s then return false end
  if t >= 3 and t <= 5 and s >= 6 and s <= 8 then return false end
  if t >= 6 and t <= 8 and s >= 3 and s <= 5 then return false end
  return true
end

-- may `item` go on board slot `slot` of card `hdl`? true, -1 / false, the slot of the active set already holding it
function HissatsuLevelUp.CanPlace(hdl, slot, item)
  hdl, item = u32(tonumber(hdl) or 0), u32(tonumber(item) or 0)
  slot = math.floor(tonumber(slot) or 0xFF)
  if not BLOCK_DUP or hdl == 0 or item == 0 then return true, -1 end
  local r = record(hdl)
  if not r or not r.addr then return true, -1 end
  for s = 0, BOARD_SLOTS - 1 do
    if same_set(slot, s) then
      local inv = u32(rd("u32", r.addr + REC_PLACED + s * 4) or 0)
      if inv == 0 then inv = u32(rd("u32", r.addr + REC_NATIVE + s * 4) or 0) end
      if inv ~= 0 and item_of(inv) == item then return false, s end
    end
  end
  return true, -1
end

local dup_refusals = 0

local function on_can_equip(ev)
  if not BLOCK_DUP then return nil end
  local hdl, inv, slot = u32(ev.args[1]), u32(ev.args[2]), band(ev.args[5] or 0xFF, 0xFF)
  local item = item_of(inv)
  if hdl == 0 or item == 0 then return nil end
  local ok, other = TH.CanPlace(hdl, slot, item)
  if ok then return nil end
  dup_refusals = dup_refusals + 1
  if dup_refusals <= 50 then
    info(string.format("one copy per set: chara %s item %s refused on board slot %d (already on slot %d)", hex(hdl), hex(item), slot, other))
  end
  return { ret = 0 }
end

-- ------------------------------------------------------------------------------------------------ commands / exports

-- grade `g` of (hdl, skill) into the saved skill_list entry and every live match unit of that character (mode "uses":
-- exact grade; "max": never below the current rank): saved write, live units
local function apply_grade(hdl, skill, g)
  local pick = function(c)
    local n = mode_rank(c, g)
    if n ~= c then return n end
    return nil
  end
  local i, o, n = write_saved_rank(hdl, skill, pick)
  local saved = i and string.format("[%d] %d->%d", i, o, n) or "none"
  local live = 0
  local units = global("Match.SoccerUnits")
  if units then
    for k = 0, UNIT_MAX - 1 do
      local u = units + k * UNIT_STRIDE
      if (rd("u32", u + UNIT_HDL) or 0) ~= 0 then
        local ch = rd("u32", u + UNIT_CHARA) or 0
        if ch ~= 0 and (ch == hdl or owner(ch, false) == hdl) then
          if ch ~= hdl then write_saved_rank(ch, skill, pick) end
          local s = unit_slot(u, skill)
          if s then
            local a = live_rank_addr(u, s)
            local c = rd("u8", a)
            local nr = c and pick(c)
            if nr then
              wr("u8", a, nr)
              apply_recast(u, s)
            end
            live = live + 1
          end
        end
      end
    end
  end
  return saved, live
end

function HissatsuLevelUp.Uses(hdl, skill)
  hdl, skill = u32(tonumber(hdl) or 0), u32(tonumber(skill) or 0)
  if hdl == 0 or skill == 0 then return ERR_BAD_ARGS, ERR_BAD_ARGS, 0 end
  if not ON then return ERR_NOT_READY, ERR_NOT_READY, 0 end
  if A.is_spirit_move(skill) then return 0, 0, 0 end -- keshin / totem moves have no grade
  local key = owner(hdl, false) or hdl
  local uses, g = get(cur(), key, skill)
  return uses, g, next_at(g)
end

function HissatsuLevelUp.Grade(hdl, skill)
  local _, g = TH.Uses(hdl, skill)
  return math.max(tonumber(g) or 0, 0)
end

function HissatsuLevelUp.Cmd.Uses(hdl, skill) return TH.Uses(hdl, skill) end

function HissatsuLevelUp.Cmd.Set(hdl, skill, grade)
  hdl, skill = u32(tonumber(hdl) or 0), u32(tonumber(skill) or 0)
  local gr = tonumber(grade)
  if gr then gr = gr >= 0 and math.floor(gr) or math.ceil(gr) end
  if not ON or not gr or gr < 0 or gr > MAX_GRADE or not is_saved_handle(hdl) or skill == 0 then
    info(string.format("RANK_SET(%s, %s, %s) refused (bad args / not active)", hex(hdl), hex(skill), tostring(grade)))
    return false, ERR_BAD_ARGS
  end
  local st = cur()
  local _, g = set_grade(st, hdl, skill, gr)
  commit(st, "RANK_SET", true)
  local saved, live = apply_grade(hdl, skill, g)
  info(string.format("RANK_SET(%s, %s, %d) -> grade %d, saved %s, live units %d", hex(hdl), hex(skill), gr, g, saved, live))
  return true, g
end

function HissatsuLevelUp.Cmd.Boost(hdl, skill, steps)
  hdl, skill = u32(tonumber(hdl) or 0), u32(tonumber(skill) or 0)
  steps = tonumber(steps) or 1
  if not ON then return false, ERR_NOT_READY, 0 end
  if not is_saved_handle(hdl) or skill == 0 or steps < 1 or steps > MAX_GRADE or steps ~= math.floor(steps) then
    info(string.format("RANK_BOOST(%s, %s, %s) refused (bad args)", hex(hdl), hex(skill), tostring(steps)))
    return false, ERR_BAD_ARGS, 0
  end
  local why = state_on("boost_states")
  if not why then
    info(string.format("RANK_BOOST(%s, %s, %d) refused: no [HissatsuLevelUp.Rules] boost_states key is on", hex(hdl), hex(skill), steps))
    return false, ERR_NOT_ALLOWED, 0
  end
  if A.type(skill) ~= nil or A.is_spirit_move(skill) then
    info(string.format("RANK_BOOST(%s, %s) refused: aura / spirit moves have no grade", hex(hdl), hex(skill)))
    return false, ERR_BAD_ARGS, 0
  end
  local r = record(hdl)
  local param = r and u32(r.param) or 0
  local base = grades_of(param)[skill]
  local st = cur()
  local old, g = boost(st, hdl, skill, base, steps)
  commit(st, "boost", true)
  local saved, live = apply_grade(hdl, skill, g)
  info(string.format("boost (%s): chara %s (card %s, card grade %s) skill %s +%d: grade %d -> %d (slot %d store), saved %s, live units %d",
    why, hex(hdl), hex(param), tostring(base), hex(skill), steps, old, g, st.slot, saved, live))
  return true, g, old
end

-- ------------------------------------------------------------------------------------------------ rank items
local IT_OK, IT_NOT_ITEM, IT_NO_GRADE, IT_CAPPED, IT_NEEDS_PREV, IT_NOT_LISTED = 0, 1, 2, 3, 4, 5

-- is `skill` one of the player's moves as a skill view shows them? Where it is: "list" (the saved skill_list), "board"
-- (a board slot's placed or native item: Victory Road's board, and the «Fantasy» table's rows that show a board
-- slot's move, which the match also fills from the board); nil = none. Character Reforged's projection adds nothing
-- to these two (its rows are list positions, its board-only rows board slots). Until 1.0.5 only the list counted, so a
-- row of the «Fantasy» table showing a board move (e.g. after «Restablecer») was refused «not_in_set».
local function in_set(hdl, skill)
  local r = record(hdl)
  if not r or not r.addr then return nil end
  for i = 0, SKILL_SLOTS - 1 do
    if rd("u32", r.addr + REC_SKILL_LIST + i * SKILL_ENTRY) == skill then return "list" end
  end
  for s = 0, BOARD_SLOTS - 1 do
    for _, at in ipairs({ REC_PLACED, REC_NATIVE }) do
      local inv = u32(rd("u32", r.addr + at + s * 4) or 0)
      if inv ~= 0 and item_of(inv) == skill then return "board" end
    end
  end
  return nil
end

function HissatsuLevelUp.Items()
  return ITEM_RAISE, ITEM_LAST, use_cap(), MAX_GRADE
end

function HissatsuLevelUp.Cmd.Items() return TH.Items() end

function HissatsuLevelUp.Cmd.Item(hdl, skill, item, apply)
  hdl, skill, item = u32(tonumber(hdl) or 0), u32(tonumber(skill) or 0), u32(tonumber(item) or 0)
  apply = apply == true or apply == 1
  if hdl == 0 or skill == 0 or item == 0 or not is_saved_handle(hdl) then return ERR_BAD_ARGS, 0, 0 end
  if not ON then return ERR_NOT_READY, 0, 0 end
  if item ~= ITEM_RAISE and item ~= ITEM_LAST then return IT_NOT_ITEM, 0, 0 end
  if A.type(skill) ~= nil or A.is_spirit_move(skill) then return IT_NO_GRADE, 0, 0 end
  local where = in_set(hdl, skill)
  if not where then
    info(string.format("rank item %s: chara %s skill %s refused: in neither the skill list nor the board", hex(item), hex(hdl), hex(skill)))
    return IT_NOT_LISTED, 0, 0
  end
  local r = record(hdl)
  local param = r and u32(r.param) or 0
  local base = grades_of(param)[skill]
  local st = cur()
  if base then seed(st, hdl, skill, base) end   -- the card's own grade first (as a use or a boost would)
  local uses, old = get(st, hdl, skill)
  local want
  if item == ITEM_RAISE then
    if old >= MAX_GRADE - 1 then return IT_CAPPED, old, old end
    want = old + 1
  else
    if old >= MAX_GRADE then return IT_CAPPED, old, old end
    if old ~= MAX_GRADE - 1 then return IT_NEEDS_PREV, old, old end
    want = MAX_GRADE
  end
  if not apply then return IT_OK, old, want end
  put(st, hdl, skill, math.max(uses, uses_for(want)), want)
  commit(st, "rank item", true)
  local saved, live = apply_grade(hdl, skill, want)
  info(string.format("rank item %s: chara %s (card %s) skill %s (from the %s) grade %d -> %d (slot %d store), saved %s, live units %d",
    hex(item), hex(hdl), hex(param), hex(skill), where, old, want, st.slot, saved, live))
  return IT_OK, old, want
end

function HissatsuLevelUp.Cmd.Popup(skill)
  skill = u32(tonumber(skill) or 0)
  local g = (skill ~= 0 and ON) and popup_take(skill) or nil
  if not g then return false, 0, "" end
  info(string.format("banner for skill %s: grade %d (Nv.%d)", hex(skill), g, g + 1))
  return true, g, ""
end

-- The retail «Nueva posibilidad» (abl_000001) the save holds. Until 1.0.3 this mod renamed it into the upgrade book;
-- since 1.0.4 the book is its own item (technique_upgrade_book) and abl_000001 is the retail board item again, so its
-- stock is never converted: only logged, once per save slot. The graft sr_popup asks first (-1: does the slot still
-- need its line?), then passes CMND_GET_ITEM_NUM(abl_000001).
local RETAIL_BOOK_KEY = "abl_000001"
local retail_stock_logged = {}   -- slot -> true

function HissatsuLevelUp.Cmd.RetailStock(count)
  local slot = current_slot()
  if retail_stock_logged[slot] then return false end
  count = tonumber(count)
  if count == nil or count < 0 then return true end   -- the graft asks with -1
  retail_stock_logged[slot] = true
  info(string.format("slot %d holds %d x %s («Nueva posibilidad», retail again since 1.0.4: not converted into upgrade books; the book is now %s)",
    slot, math.floor(count), RETAIL_BOOK_KEY, hex(ITEM_RAISE)))
  return false
end

function HissatsuLevelUp.Cmd.CanPlace(hdl, slot, item)
  local ok, other = TH.CanPlace(hdl, slot, item)
  return ok, other
end

-- ------------------------------------------------------------------------------------------------ the store for other mods
-- the saved text of slot `slot`'s store (nil = none): what the game saved, plus nothing pending
function HissatsuLevelUp.StoreBlob(slot)
  slot = math.floor(tonumber(slot) or 1)
  local ok, text = pcall(VRFW.save.blob, BLOB, slot)
  if ok and type(text) == "string" then return text end
  return nil
end

-- replace slot `slot`'s store with `text` (a save repair of another mod, e.g. Inazuma Fantasy's «Reparar duplicados»
-- moving a duplicate card's entries): written at once, the store reloaded when that slot is the loaded one
function HissatsuLevelUp.StoreBlobWrite(slot, text)
  slot = math.floor(tonumber(slot) or 0)
  if slot < 1 or type(text) ~= "string" then return false, "bad arguments" end
  local j = VRFW.json.decode(text)
  if type(j) ~= "table" or j.version ~= FILE_VERSION then return false, "not a skill_uses.json version " .. FILE_VERSION end
  local ok, where = VRFW.save.blob_write(BLOB, text, slot)
  if not ok then return false, tostring(where) end
  if store.slot == slot then store = load_store(slot) end
  if parked and parked.slot == slot then parked = load_store(slot) end
  info(string.format("slot %d: store replaced by another mod's repair", slot))
  return true, nil
end

-- ------------------------------------------------------------------------------------------------ start (files only)
local function start()
  A.load()
  BLOCK_DUP = cfg("duplicates.block", true) ~= false
  info("one copy of a move per player set: " .. (BLOCK_DUP and "on" or "off ([duplicates] block = false)"))
  local k = cfg("ranks.recast_per_grade", 0.025)
  if type(k) ~= "number" or k ~= k or k < 0 or k > 1 then
    warn("recast_per_grade " .. tostring(k) .. " out of range 0..1, using 0.025")
    k = 0.025
  end
  K = f32(k)
  info(string.format("recast per grade +%.1f %% (grade 1 x%.3f, grade 5 x%.3f)", K * 100, f32(1 + f32(K)), f32(1 + f32(K * 5))))
  local th = cfg("ranks.thresholds", DEFAULT_TH)
  local ok, why = thresholds_ok(th)
  if not ok then
    err("[ranks] thresholds invalid (" .. why .. "): levels by use off")
    return
  end
  THR = {}
  for i, v in ipairs(th) do THR[i] = math.floor(v) end
  local mode = string.lower((cfg("ranks.mode", "uses"):gsub("^%s+", ""):gsub("%s+$", "")))
  if mode == "uses" or mode == "uses_only" then
    MODE = "uses"
  elseif mode == "max" then
    MODE = "max"
  else
    warn("mode " .. mode .. " unknown (uses | max), using \"uses\"")
    MODE = "uses"
  end
  LOG_USES = cfg("ranks.log_uses", true)
  POPUP = cfg("ranks.popup", true)
  USE_CAP = cfg("ranks.last_grade_item_only", true) == false and MAX_GRADE or MAX_GRADE - 1
  local function item_id(key)
    local v = cfg(key, "")
    if type(v) == "number" then return u32(v) end
    if type(v) ~= "string" or v == "" then return 0 end
    if v:match("^0[xX]%x+$") then return u32(tonumber(v:sub(3), 16)) end
    return u32(VRFW.ui.crc32(v))   -- the mod scripts' crc32 (VRFW.crc32 is the build scripts' only)
  end
  ITEM_RAISE, ITEM_LAST = item_id("ranks.raise_item"), item_id("ranks.last_grade_item")
  ON = true
  local r = rules()
  info(string.format("thresholds [%s] (max grade %d), mode %s, log_uses %s, store blob %s per slot",
    table.concat(THR, ", "), max_grade(), MODE, tostring(LOG_USES), BLOB))
  info(string.format("rules of other mods: no rank-up while [%s]; boosts while [%s]; last grade in a match while [%s]",
    table.concat(type(r.no_rank_up_states) == "table" and r.no_rank_up_states or {}, ", "),
    table.concat(type(r.boost_states) == "table" and r.boost_states or {}, ", "),
    table.concat(type(r.max_grade_states) == "table" and r.max_grade_states or {}, ", ")))
  if POPUP then info("level-up banner on (skill telop + graft sr_popup)") end
  info(string.format("rank-up by use up to grade %d (last grade %d: %s); rank items: raise %s, last grade %s",
    use_cap(), MAX_GRADE, USE_CAP < MAX_GRADE and "rank item only" or "by use too", hex(ITEM_RAISE), hex(ITEM_LAST)))
end

start()
apply_grade_animations()
VRFW.on("hook:HissatsuLevelUp.SkillUsed:post", on_used)
VRFW.on("hook:HissatsuLevelUp.BuildSkillList:post", on_build)
VRFW.on("hook:HissatsuLevelUp.MatchSkillInstall:post", on_install)
VRFW.on("chara:moves:post", on_moves)
VRFW.on("hook:HissatsuLevelUp.CanEquip:post", on_can_equip)
