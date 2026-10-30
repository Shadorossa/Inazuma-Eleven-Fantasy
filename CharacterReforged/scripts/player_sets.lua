-- Character Reforged › player sets: named builds of ONE player, saved and loaded from the skill table's save button
-- (graft ss2_menus: PL.SetsCoroutine and its list; graft pset_preview: the set preview pages). Commands in
-- content\game\player_sets.toml:
--
--   CMND_CHARACTERREFORGED_PLAYER_SET_GET(charaStHdl, i)
--       -> used, name, m1 … m6, aura, e1 … e5, sixsense
--   CMND_CHARACTERREFORGED_PLAYER_SET_FULL(charaStHdl, i)
--       -> used, name, {m1 … m6}, aura, {e1 … e5}, sixsense, {p1 … p5} | false, {c1 … c5} | false,
--          role (-1 = not stored), kit (0 = not stored), mix (0 = empty)
--   CMND_CHARACTERREFORGED_PLAYER_SET_SAVE(charaStHdl, i, name, m1 … m6, aura, e1 … e5, sixsense) -> ok
--   CMND_CHARACTERREFORGED_PLAYER_SET_SAVE_FULL(charaStHdl, i, name, m1 … m6, aura, e1 … e5, sixsense, p1 … p5,
--       c1 … c5, role[, kit[, mix]]) -> ok        (p1 not a number = passives not stored; role not 0..2 = not stored)
--   CMND_CHARACTERREFORGED_PLAYER_SET_DELETE(charaStHdl, i) -> ok
--   CMND_CHARACTERREFORGED_PLAYER_SET_EXPORT(charaStHdl, name, level, m1 … m6, aura, e1 … e5, sixsense, role,
--       set name, p1 … p5, c1 … c5, kit[, mix]) -> true, file, area | false, why
--   CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_LIST() -> count, area     (the area's *.vrmod files, newest first)
--   CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_ENTRY(i) -> file, label
--   CMND_CHARACTERREFORGED_PLAYER_SET_IMPORT_READ(i, charaStHdl) -> true, set name, chara_param, checksum ok,
--       missing ids, m1 … m6, aura, e1 … e5, sixsense, role, p1 … p5 (-1 = none), c1 … c5, kit, mix | false, why
--
-- A set = a name, the 6 special-move rows, the aura row (board slot 8), the mix slot (scripts\mix_slots.lua), the 5
-- equipment items, the custom passive, the 5 passive slots and the configured ones, the staff role and the team kit
-- the set was saved in. Both skill table views read the same data: the 6 rows are the match list in either view, the
-- aura is the board's aura slot, the mix slot is this mod's store (shown only by the «Fantasy» view, kept in both).
-- Sets belong to a player: key = his character handle as 8 hex digits plus his chara_param id (a handle reused by
-- another character after a new game does not inherit them), SETS per player, in the blob ss_player_sets.json of the
-- active save slot. The blob keeps the layout Inazuma Fantasy used (`hiper` = the aura row), so its sets are read
-- unchanged: content\game\player_sets.toml imports that blob once per save slot.

CharacterReforged = CharacterReforged or {}
CharacterReforged.PlayerSets = CharacterReforged.PlayerSets or {}
local PlayerSets = CharacterReforged.PlayerSets

local BLOB = "ss_player_sets.json"
local FILE_VERSION = 4
local SETS = 5
local PASSIVE_SLOTS = 5
local NAME_MAX = 40
-- values after `charaStHdl, i, name` in SAVE_FULL: 6 moves, aura, 5 equipment, six sense, 5 passives, 5 configured,
-- role; then the optional kit and mix
local SAVE_FULL_VALUES = 6 + 1 + 5 + 1 + PASSIVE_SLOTS * 2 + 1
local TWO32 = 4294967296

require "VRFW/lib/basics"
local info, _, err = VRFW.logger("player sets")

-- ---------------------------------------------------------------------------------------------- helpers

local function read_memory(kind, address)
  local ok, value = pcall(VRFW.mem.read, kind, address)
  if ok then return value end
  return nil
end

-- a command argument as a number (numbers and numeric strings)
local function number_of(value) return VRFW.value.num(value, nil) end

-- an integer toward zero, nil when not a number
local function integer_of(value) return VRFW.value.int(value, nil) end

local Id = require "VRFW/lib/ids"
-- the unsigned 32-bit value the game stores (T2B ints arrive signed)
local u32 = Id.u32

local function hex8(value)
  value = u32(value)
  return string.format("%04X%04X", math.floor(value / 65536), value % 65536)
end

local function active_slot()
  return VRFW.slots.active()
end

local function config(path, default)
  local ok, value = pcall(VRFW.files.config, path)
  if not ok or value == nil or type(value) ~= type(default) then return default end
  return value
end

-- control characters (C0, DEL, C1) and the brackets of the game's text tags go; at most NAME_MAX characters (UTF-8)
local function clean_name(text)
  if type(text) ~= "string" then return "" end
  local out, count, i, length = {}, 0, 1, #text
  while i <= length and count < NAME_MAX do
    local byte = text:byte(i)
    local width = byte < 0x80 and 1 or byte >= 0xF0 and 4 or byte >= 0xE0 and 3 or byte >= 0xC0 and 2 or 1
    local character = text:sub(i, i + width - 1)
    local code_point
    if width == 1 then
      code_point = byte
    elseif width == 2 then
      code_point = (byte % 0x20) * 64 + ((text:byte(i + 1) or 0x80) % 0x40)
    end
    i = i + width
    local control = code_point and (code_point < 0x20 or (code_point >= 0x7F and code_point <= 0x9F))
    if not control and character ~= "[" and character ~= "]" then
      out[#out + 1] = character
      count = count + 1
    end
  end
  return table.concat(out)
end

-- the chara_param id of a saved character (record checked against the handle), nil when unknown
local function param_of(handle)
  local kind = math.floor(handle / 4096) % 16
  if handle == 0 or kind >= 0xD then return nil end
  local ok, record = pcall(VRFW.chara.record, handle)
  if not ok or not record or not record.addr or record.addr < 0x10000 then return nil end
  if read_memory("u32", record.addr) ~= handle then return nil end
  return read_memory("i32", record.addr + 4)
end

local function hex_list(values)
  local out = {}
  for k, v in ipairs(values) do out[k] = hex8(v) end
  return "[" .. table.concat(out, ", ") .. "]"
end

-- ---------------------------------------------------------------------------------------------- the blob

local function id_list(values, count)
  local out = {}
  for k = 1, count do out[k] = u32(type(values) == "table" and tonumber(values[k]) or 0) end
  return out
end

-- a stored set (decoded JSON) -> the set table; missing fields take their defaults
local function set_from_json(j)
  if type(j) ~= "table" then return nil end
  local set = {
    name = type(j.name) == "string" and j.name or "",
    moves = id_list(j.moves, 6),
    aura = u32(tonumber(j.hiper) or 0),
    equip = id_list(j.equip, 5),
    sixsense = u32(tonumber(j.sixsense) or 0),
    mix = u32(tonumber(j.mix) or 0),
  }
  if type(j.passives) == "table" then set.passives = id_list(j.passives, PASSIVE_SLOTS) end
  if type(j.passive_cfg) == "table" then set.passive_cfg = id_list(j.passive_cfg, PASSIVE_SLOTS) end
  if tonumber(j.role) then set.role = integer_of(j.role) end
  if tonumber(j.kit) then set.kit = u32(tonumber(j.kit)) end
  return set
end

-- the stored sets of one player: a JSON list (null = empty) or an object keyed "1".."N"
local function sets_from_json(value)
  local sets = {}
  if type(value) ~= "table" then return sets end
  for key, j in pairs(value) do
    local index = type(key) == "number" and key or tonumber(key)
    if index and index >= 1 and index <= SETS then sets[index] = set_from_json(j) end
  end
  return sets
end

local function decode(text)
  local ok, j, why = pcall(VRFW.json.decode, text)
  if not ok or type(j) ~= "table" then return nil, "bad JSON: " .. tostring(ok and why or j) end
  local file = { players = {} }
  if type(j.players) == "table" then
    for key, entry in pairs(j.players) do
      if type(key) == "string" and type(entry) == "table" then
        file.players[key] = { param_id = integer_of(entry.param_id) or 0, sets = sets_from_json(entry.sets) }
      end
    end
  end
  return file
end

local function set_to_json(set)
  local j = {
    name = set.name,
    moves = set.moves,
    hiper = set.aura,
    equip = set.equip,
    sixsense = set.sixsense,
  }
  if set.mix and set.mix ~= 0 then j.mix = set.mix end
  if set.passives then j.passives = set.passives end
  if set.passive_cfg then j.passive_cfg = set.passive_cfg end
  if set.role then j.role = set.role end
  if set.kit and set.kit ~= 0 then j.kit = set.kit end
  return j
end

local function encode(file)
  local players = {}
  for key, entry in pairs(file.players) do
    local sets = {}
    for index = 1, SETS do
      if entry.sets[index] then sets[tostring(index)] = set_to_json(entry.sets[index]) end
    end
    players[key] = { param_id = entry.param_id, sets = sets }
  end
  return VRFW.json.encode({ version = FILE_VERSION, players = players })
end

-- the sets of the active slot; an unreadable blob starts empty (and is left as it is until the next save)
local function load()
  local slot = active_slot()
  local ok, text = pcall(VRFW.save.get_blob, slot, BLOB)
  if not ok then
    err(BLOB .. " of slot " .. tostring(slot) .. ": " .. tostring(text) .. " (starting empty)")
    return { players = {} }
  end
  if type(text) ~= "string" or text == "" then return { players = {} } end
  local file, why = decode(text)
  if not file then
    err(BLOB .. " of slot " .. tostring(slot) .. ": " .. tostring(why) .. " (starting empty)")
    return { players = {} }
  end
  return file
end

local function write(file, what)
  local slot = active_slot()
  local ok, text = pcall(encode, file)
  if not ok then
    err("encode: " .. tostring(text))
    return false
  end
  local written, why = pcall(VRFW.save.set_blob, slot, BLOB, text)
  if not written or why == false then
    err("write slot " .. tostring(slot) .. ": " .. tostring(why))
    return false
  end
  info(what .. " (slot " .. tostring(slot) .. ")")
  return true
end

-- set `index` (0-based) of player `handle` (character `param_id`); a stored entry of another character counts as empty
local function get(file, handle, param_id, index)
  local entry = file.players[hex8(handle)]
  if not entry or entry.param_id ~= param_id then return nil end
  return entry.sets[index + 1]
end

local function put(file, handle, param_id, index, set)
  if index >= SETS then return false end
  local key = hex8(handle)
  local entry = file.players[key]
  if not entry or entry.param_id ~= param_id then
    entry = { param_id = param_id, sets = {} }
    file.players[key] = entry
  end
  entry.sets[index + 1] = set
  if next(entry.sets) == nil then file.players[key] = nil end
  return true
end

-- the player and set index of a command (nil when the handle has no record or the index is out of range)
local function target(handle, index)
  local param_id = param_of(u32(handle))
  local n = integer_of(index)
  if not param_id or not n or n < 0 or n >= SETS then return nil end
  return param_id, n
end

local function store(handle, index, set, what)
  local param_id, n = target(handle, index)
  if not param_id then return false end
  local file = load()
  return put(file, u32(handle), param_id, n, set) and write(file, what)
end

local function describe(handle, index, set)
  return string.format("0x%s set %s = %q moves %s aura %s mix %s equip %s custom passive %s passives %s configured %s role %s",
    hex8(handle), tostring(index), set.name, hex_list(set.moves), hex8(set.aura), hex8(set.mix or 0), hex_list(set.equip),
    hex8(set.sixsense), set.passives and hex_list(set.passives) or "none",
    set.passive_cfg and hex_list(set.passive_cfg) or "none", tostring(set.role))
end

-- ---------------------------------------------------------------------------------------------- commands

function PlayerSets.Get(handle, index)
  local param_id, n = target(handle, index)
  local set = param_id and get(load(), u32(handle), param_id, n)
  if not set then return false, "" end
  local m, e = set.moves, set.equip
  return true, set.name, m[1], m[2], m[3], m[4], m[5], m[6], set.aura, e[1], e[2], e[3], e[4], e[5], set.sixsense
end

function PlayerSets.Full(handle, index)
  local param_id, n = target(handle, index)
  local set = param_id and get(load(), u32(handle), param_id, n)
  if not set then return false, "" end
  return true, set.name, set.moves, set.aura, set.equip, set.sixsense, set.passives or false, set.passive_cfg or false,
    set.role or -1, set.kit or 0, set.mix or 0
end

function PlayerSets.Save(handle, index, name, ...)
  local values = { ... }
  local set = { name = clean_name(name), moves = {}, equip = {}, mix = 0 }
  for k = 1, 6 do set.moves[k] = u32(values[k]) end
  set.aura = u32(values[7])
  for k = 1, 5 do set.equip[k] = u32(values[7 + k]) end
  set.sixsense = u32(values[13])
  return store(handle, index, set, describe(u32(handle), integer_of(index), set))
end

-- SAVE_FULL's values after the name: numbers only (anything else = not stored)
function PlayerSets.SaveFull(handle, index, name, ...)
  local raw = { ... }
  local values = {}
  for k = 1, SAVE_FULL_VALUES + 2 do
    if type(raw[k]) == "number" then values[k] = integer_of(raw[k]) end
  end
  local function id(k) return values[k + 1] and u32(values[k + 1]) or 0 end
  local set = { name = clean_name(name), moves = {}, equip = {} }
  for k = 0, 5 do set.moves[k + 1] = id(k) end
  set.aura = id(6)
  for k = 0, 4 do set.equip[k + 1] = id(7 + k) end
  set.sixsense = id(12)
  if values[14] ~= nil then
    set.passives, set.passive_cfg = {}, {}
    for k = 0, PASSIVE_SLOTS - 1 do
      set.passives[k + 1] = id(13 + k)
      set.passive_cfg[k + 1] = id(13 + PASSIVE_SLOTS + k)
    end
  end
  local role = values[SAVE_FULL_VALUES]
  if role and role >= 0 and role <= 2 then set.role = role end
  local kit = values[SAVE_FULL_VALUES + 1]
  if kit and kit ~= 0 then set.kit = u32(kit) end
  set.mix = id(SAVE_FULL_VALUES + 1)
  return store(handle, index, set, describe(u32(handle), integer_of(index), set))
end

function PlayerSets.Delete(handle, index)
  return store(handle, index, nil, string.format("0x%s set %s deleted", hex8(u32(handle)), tostring(integer_of(index))))
end

-- ---------------------------------------------------------------------------------------------- .vrmod export / import

-- One saved set as a `.vrmod` file (TOML, schema utilities.vrmod/1, kind "character"; docs/game/ui/vrmod-export.md).
-- Every id is written with its origin (VRFW.ids.origin: `game` or the mod that numbers it, plus its stable key) and
-- the mods it needs go to [[vrmod.requires]]. The checksum is the crc32 of the file text written without it. The aura,
-- the mix and the role are this mod's parts of a set (set.mods.<this mod>); files written by Inazuma Fantasy carry the
-- aura as `hiper` and the role in set.mods.inazuma_fantasy, read the same way.
local DEFAULT_EXPORT_AREA = "vrmod/characters"
local EQUIP_SLOTS = { "shoes", "misanga", "pendant", "special", "costume" }   -- equipment types 0..4
local SCHEMA = "utilities.vrmod/1"
local LEGACY_OWNER = "inazuma_fantasy"

local function own_id()
  return VRFW.mod or "character_reforged"
end

local function own_version()
  local ok, manifest = pcall(VRFW.files.toml, "mod.toml")
  return ok and type(manifest) == "table" and type(manifest.version) == "string" and manifest.version or "?"
end

local function export_area()
  local area = config("player_sets.export_area", DEFAULT_EXPORT_AREA)
  if area == "" then area = DEFAULT_EXPORT_AREA end
  return area
end

local function reserved_slot()
  local slot = active_slot()
  local ok, reserved = pcall(VRFW.slots.reserved, slot)
  return ok and reserved == true, slot
end

-- `{ id, origin[, key] }` of a number; `needed` collects the mods behind them (id -> { version, parts })
local function reference(needed, kind, part, id)
  local entry = { id = id, origin = "game" }
  local ok, origin = pcall(VRFW.ids.origin, kind, id)
  if ok and type(origin) == "table" and type(origin.origin) == "string" and origin.origin ~= "game" then
    entry.origin = origin.origin
    if type(origin.key) == "string" then entry.key = origin.key end
    local need = needed[origin.origin] or { version = origin.version, parts = {} }
    need.parts[part] = true
    needed[origin.origin] = need
  end
  return entry
end

local function requires_of(needed)
  local ids = {}
  for k in pairs(needed) do ids[#ids + 1] = k end
  table.sort(ids)
  local out = {}
  for _, k in ipairs(ids) do
    local parts = {}
    for p in pairs(needed[k].parts) do parts[#parts + 1] = p end
    table.sort(parts)
    out[#out + 1] = { id = k, version = needed[k].version and tostring(needed[k].version) or nil, parts = parts }
  end
  return out
end

-- the crc32 line of a document (its text written without `checksum`)
local function checksum(doc)
  local keep = doc.vrmod.checksum
  doc.vrmod.checksum = nil
  local body, why = VRFW.files.toml_string(doc)
  doc.vrmod.checksum = keep
  if not body then return nil, why end
  return string.format("crc32:%08X", u32(VRFW.ui.crc32(body)))
end

-- (handle, player name, level, m1 … m6, aura, e1 … e5, sixsense, role, set name, p1 … p5, c1 … c5, kit[, mix])
function PlayerSets.Export(handle, player_name, level, ...)
  local h = u32(handle)
  local param_id = param_of(h)
  if not param_id then return false, "no saved player for handle 0x" .. hex8(h) end
  local reserved, slot = reserved_slot()
  if reserved then return false, "reserved save slot " .. tostring(slot) end
  local values = { ... }
  local needed = {}
  local me = own_id()
  local set = { moves = {}, equip = {} }
  for k = 1, 6 do
    local id = u32(values[k])
    if id ~= 0 then
      local entry = reference(needed, "move", "moves", id)
      entry.slot = k
      set.moves[#set.moves + 1] = entry
    end
  end
  for t = 1, 5 do
    local id = u32(values[7 + t])
    if id ~= 0 then set.equip[EQUIP_SLOTS[t]] = reference(needed, "item", "items", id) end
  end
  if next(set.equip) == nil then set.equip = nil end   -- an empty table would be written as `[]`
  local sixsense = u32(values[13])
  if sixsense ~= 0 then set.sixsense = reference(needed, "item", "items", sixsense) end
  local set_name = type(values[15]) == "string" and clean_name(values[15]) or ""
  if set_name ~= "" then set.name = set_name end
  local passives, configured = {}, {}
  for k = 1, PASSIVE_SLOTS do
    local id, chosen = u32(values[15 + k]), u32(values[20 + k])
    if id ~= 0 then
      local entry = reference(needed, "passive", "passives", id)
      entry.slot = k
      passives[#passives + 1] = entry
    end
    if chosen ~= 0 then
      local entry = reference(needed, "passive", "passives", chosen)
      entry.slot = k
      configured[#configured + 1] = entry
    end
  end
  if #passives > 0 then set.passives = passives end
  if #configured > 0 then set.passive_cfg = configured end
  local kit = u32(values[26])
  if kit ~= 0 then set.kit = reference(needed, "kit", "kits", kit) end
  local mine = {}
  local aura = u32(values[7])
  if aura ~= 0 then mine.aura = reference(needed, "move", "aura", aura) end
  local mix = u32(values[27])
  if mix ~= 0 then mine.mix = reference(needed, "move", "mix", mix) end
  local role = integer_of(values[14])
  if role and role >= 0 and role <= 2 then mine.role = role end
  if next(mine) ~= nil then
    set.mods = { [me] = mine }
    local need = needed[me] or { version = own_version(), parts = {} }
    for p in pairs(mine) do need.parts[p] = true end
    needed[me] = need
  end
  local character = reference(needed, "chara", "characters", param_id)
  character.name = clean_name(player_name)
  character.level = integer_of(level)
  character.set = set
  local doc = {
    vrmod = {
      schema = SCHEMA,
      kind = "character",
      name = set_name ~= "" and (character.name .. " - " .. set_name) or character.name,
      author = "",
      created = VRFW.time.stamp(),
      exporter = me .. "@" .. own_version(),
      requires = requires_of(needed),
    },
    character = character,
  }
  local sum, why = checksum(doc)
  if not sum then return false, "toml: " .. tostring(why) end
  doc.vrmod.checksum = sum
  local text
  text, why = VRFW.files.toml_string(doc)
  if not text then return false, "toml: " .. tostring(why) end
  local area = export_area()
  local stem = VRFW.files.user_clean(doc.vrmod.name ~= "" and doc.vrmod.name or ("player_" .. hex8(param_id)))
  local file = stem .. "_" .. VRFW.time.file_stamp() .. ".vrmod"
  local written, write_error = VRFW.files.user_write(area, file, text, "new")
  if not written then
    err("export 0x" .. hex8(h) .. ": " .. tostring(write_error))
    return false, tostring(write_error)
  end
  info(string.format("exported 0x%s (chara 0x%s) -> %s/%s", hex8(h), hex8(param_id), area, written))
  return true, written, area
end

-- the files of the area, newest first (IMPORT_LIST caches them for IMPORT_ENTRY / IMPORT_READ)
local listed = {}

local function parse(file)
  local text, why = VRFW.files.user_read(export_area(), file)
  if not text then return nil, why end
  local doc
  doc, why = VRFW.files.toml_parse(text)
  if type(doc) ~= "table" then return nil, "toml: " .. tostring(why) end
  if type(doc.vrmod) ~= "table" then return nil, "no [vrmod] table" end
  local schema = tostring(doc.vrmod.schema or "")
  if schema ~= SCHEMA then return nil, "schema " .. schema .. " (this version reads " .. SCHEMA .. ")" end
  if doc.vrmod.kind ~= "character" or type(doc.character) ~= "table" then
    return nil, "kind " .. tostring(doc.vrmod.kind) .. " (only \"character\" is a player set)"
  end
  return doc
end

function PlayerSets.ImportList()
  listed = {}
  local area = export_area()
  local ok, files = pcall(VRFW.files.user_list, area, "*.vrmod")
  if not ok or type(files) ~= "table" then return 0, area end
  for _, entry in ipairs(files) do
    if not entry.dir then listed[#listed + 1] = { file = entry.name, modified = tonumber(entry.modified) or 0 } end
  end
  table.sort(listed, function(a, b)
    if a.modified ~= b.modified then return a.modified > b.modified end
    return a.file < b.file
  end)
  for _, entry in ipairs(listed) do
    local doc = parse(entry.file)
    if doc then
      local created = tostring(doc.vrmod.created or ""):sub(1, 16)
      local name = tostring(doc.vrmod.name or entry.file)
      entry.label = created ~= "" and (name .. " · " .. created) or name
    else
      entry.label = entry.file
    end
  end
  info("import list: " .. #listed .. " file(s) in modloader_exports/" .. area)
  return #listed, area
end

function PlayerSets.ImportEntry(index)
  local entry = listed[(integer_of(index) or -1) + 1]
  if not entry then return nil end
  return entry.file, entry.label
end

-- the active mods (every active mod's mod.toml through the declarations reader)
local function active_mods()
  local out = {}
  local ok, declarations = pcall(VRFW.files.declarations, "mod.toml")
  if ok and type(declarations) == "table" then
    for _, d in ipairs(declarations) do
      if type(d.mod) == "string" then out[d.mod] = true end
    end
  end
  return out
end

-- A mod id whose mod is off or whose key no longer resolves is answered 0 and named in `missing`; the game rules
-- (open rows, ownership) are the screen's when the set is loaded.
function PlayerSets.ImportRead(index, handle)
  local reserved, slot = reserved_slot()
  if reserved then return false, "reserved save slot " .. tostring(slot) end
  local entry = listed[(integer_of(index) or -1) + 1]
  if not entry then return false, "no listed file " .. tostring(index) end
  local doc, why = parse(entry.file)
  if not doc then
    err("import " .. entry.file .. ": " .. tostring(why))
    return false, tostring(why)
  end
  local sum = checksum(doc)
  local checksum_ok = sum ~= nil and sum == doc.vrmod.checksum
  local mods = active_mods()
  local missing = {}
  if type(doc.vrmod.requires) == "table" then
    for _, r in ipairs(doc.vrmod.requires) do
      if type(r) == "table" and type(r.id) == "string" and not mods[r.id] and r.id ~= LEGACY_OWNER then
        missing[#missing + 1] = r.id
      end
    end
  end
  local function resolve(kind, x)
    if type(x) ~= "table" then return 0 end
    local id = u32(x.id)
    if x.origin == nil or x.origin == "game" then return id end
    if not mods[x.origin] then return 0 end      -- named once in `missing` through [[vrmod.requires]]
    local ok, origin = pcall(VRFW.ids.origin, kind, id)
    if ok and type(origin) == "table" and origin.origin == x.origin then return id end
    if type(x.key) == "string" then
      local ok_key, resolved = pcall(VRFW.ids.resolve, kind, x.key)
      if ok_key and type(resolved) == "number" then return u32(resolved) end
    end
    missing[#missing + 1] = tostring(x.key or string.format("%s:%08X", tostring(x.origin), id))
    return 0
  end
  local character = doc.character
  local set = type(character.set) == "table" and character.set or {}
  local out = {}
  local moves = {}
  for _, m in ipairs(type(set.moves) == "table" and set.moves or {}) do
    local k = integer_of(type(m) == "table" and m.slot)
    if k and k >= 1 and k <= 6 then moves[k] = resolve("move", m) end
  end
  for k = 1, 6 do out[#out + 1] = moves[k] or 0 end
  local parts = type(set.mods) == "table" and set.mods or {}
  local mine = type(parts[own_id()]) == "table" and parts[own_id()] or {}
  local legacy = type(parts[LEGACY_OWNER]) == "table" and parts[LEGACY_OWNER] or {}
  out[#out + 1] = resolve("move", mine.aura or legacy.hiper)
  local equip = type(set.equip) == "table" and set.equip or {}
  for t = 1, 5 do out[#out + 1] = resolve("item", equip[EQUIP_SLOTS[t]]) end
  out[#out + 1] = resolve("item", set.sixsense)
  local role = integer_of(mine.role or legacy.role)
  out[#out + 1] = (role and role >= 0 and role <= 2) and role or -1
  local passives, configured = {}, {}
  local has_passives = type(set.passives) == "table" or type(set.passive_cfg) == "table"
  for _, x in ipairs(type(set.passives) == "table" and set.passives or {}) do
    local k = integer_of(type(x) == "table" and x.slot)
    if k and k >= 1 and k <= PASSIVE_SLOTS then passives[k] = resolve("passive", x) end
  end
  for _, x in ipairs(type(set.passive_cfg) == "table" and set.passive_cfg or {}) do
    local k = integer_of(type(x) == "table" and x.slot)
    if k and k >= 1 and k <= PASSIVE_SLOTS then configured[k] = resolve("passive", x) end
  end
  for k = 1, PASSIVE_SLOTS do out[#out + 1] = has_passives and (passives[k] or 0) or -1 end
  for k = 1, PASSIVE_SLOTS do out[#out + 1] = has_passives and (configured[k] or 0) or 0 end
  out[#out + 1] = resolve("kit", set.kit)
  out[#out + 1] = resolve("move", mine.mix)
  local set_name = type(set.name) == "string" and clean_name(set.name) or ""
  local param_id = u32(character.id)
  info(string.format("import read %s: chara 0x%s for 0x%s, checksum %s, missing [%s]", entry.file, hex8(param_id),
    hex8(u32(handle)), checksum_ok and "ok" or "BAD", table.concat(missing, ", ")))
  return true, set_name, param_id, checksum_ok, table.concat(missing, ", "), (table.unpack or unpack)(out)
end
