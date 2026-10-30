-- Technique filter values: the tension tab of the move filter window (item_filter_menu, list item type 3) lists one row
-- per tension cost present in the technique table after mods, in ascending order, through
-- content/game/technique_filter.toml. A technique matches the row of its own value. Same values as the game's rows and
-- no technique family: nothing is written.
-- Technique families ([[VRFW.TechniqueFamily]] of any active mod) add one row each after the tension rows (at most 64
-- rows in all). A technique passes the family rows when none or all of them are ticked, else when one of its families
-- is ticked (the match stub asks the callback TechniqueFilter.FamilyPass); with no tension row ticked and a family row
-- ticked, the tension rows do not filter.
-- The ticked rows of a saved filter are kept here by value (the game's save holds six rows only); for the session. A
-- family row is kept as 256 + its index, 0-based (assets/lua/menu/_all/23_technique_filter.lua).
-- CMND_VRFW_TECHNIQUE_FILTER_VALUES(list item type) -> n, value 1, ..., value n (0 = the game's own rows)
-- CMND_VRFW_TECHNIQUE_FILTER_FAMILIES() -> first row, n, text 1, name 1, ..., text n, name n (0 = no family rows)
-- CMND_VRFW_TECHNIQUE_FILTER_KEEP(save id, n, value 1, ..., value n) -> true (n < 0 = forget)
-- CMND_VRFW_TECHNIQUE_FILTER_KEPT(save id) -> n, value 1, ..., value n (-1 = none kept)

TechniqueFilter = TechniqueFilter or {}
TechniqueFilter.kept = TechniqueFilter.kept or {}

require "VRFW/lib/basics"
local info, warn = VRFW.logger("technique_filter")

-- the game's numeric tab: its list item type and the technique table column it filters (record byte +0x31)
local TENSION = { list_item_type = 3, table = "skill/skill", column = "consume_tp" }
-- the match site's six `cmp byte [rdi+0x31], imm8` immediates (offsets in the site's game bytes)
local GAME_VALUE_AT = { 21, 27, 33, 39, 45, 51 }
-- rows the stored mask holds (bits of the filter block's 8 bytes)
local MAX_ROWS = 64
-- tension byte -> row table of the match stub: no row
local NO_ROW = 0xFF
-- the technique files that declare families ([[VRFW.TechniqueFamily]])
local FAMILY_FOLDERS = { "techniques", "content/techniques", "features/*/content/techniques" }
-- the callback the match stub calls for the family rows
local FAMILY_PASS = "TechniqueFilter.FamilyPass"

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function apply(name, arg)
  local ok, r = pcall(VRFW.patch.apply, name, arg)
  if not ok then
    warn(name .. ": " .. tostring(r))
    return false
  end
  return r == true
end

-- the game's row values, read from the code before anything is written; nil, why when not the game's
local function game_rows()
  local ok1, match = pcall(VRFW.game.sym, "Technique.FilterTensionMatch")
  local ok2, rows = pcall(VRFW.game.sym, "Technique.FilterTensionRows")
  if not (ok1 and ok2 and match and rows) then return nil, "the filter sites are not on this build" end
  local values = {}
  for i, at in ipairs(GAME_VALUE_AT) do
    if rd("u8", match + at - 3) ~= 0x80 then return nil, "the match test is not the game's (another mod changed it)" end
    values[i] = rd("u8", match + at)
  end
  if rd("u8", rows) ~= #values then return nil, "the row count is not the game's" end
  return values
end

-- distinct tension values of the served table, ascending
local function table_values()
  local ok, rows = pcall(VRFW.table.rows, TENSION.table)
  if not ok or type(rows) ~= "table" then return nil, TENSION.table .. " not readable: " .. tostring(rows) end
  local seen, list = {}, {}
  for _, r in ipairs(rows) do
    local v = tonumber(r[TENSION.column])
    if v then
      v = math.max(0, math.min(255, math.floor(v)))
      if not seen[v] then
        seen[v] = true
        list[#list + 1] = v
      end
    end
  end
  table.sort(list)
  return list
end

-- every declared family in load order ({ key, text, name }); a later declaration of the same key replaces the earlier one
local function declared_families()
  local ok, files = pcall(VRFW.files.declarations, FAMILY_FOLDERS)
  if not ok or type(files) ~= "table" then
    warn("the technique files could not be read (" .. tostring(files) .. "): no family rows")
    return {}
  end
  local list, at = {}, {}
  for _, f in ipairs(files) do
    local v = type(f.data) == "table" and f.data.VRFW or nil
    local decls = type(v) == "table" and v.TechniqueFamily or nil
    for _, d in ipairs(type(decls) == "table" and decls or {}) do
      if type(d.name) == "string" and d.name ~= "" then
        local key = string.find(d.name, ".", 1, true) and d.name or (tostring(f.mod) .. "." .. d.name)
        local fam = { key = key, text = type(d.text) == "string" and d.text or "",
          name = string.match(key, "([^%.]+)$") or key }
        if at[key] then
          list[at[key]] = fam
        else
          list[#list + 1] = fam
          at[key] = #list
        end
      end
    end
  end
  return list
end

-- 8 little-endian bytes of a non-negative integer below 2^53, appended to `out`
local function push_u64(out, v)
  for _ = 1, 8 do
    out[#out + 1] = v % 256
    v = math.floor(v / 256)
  end
end

-- 8 little-endian bytes of the mask of rows first .. first + n - 1 (each below 64), appended to `out`
local function push_row_mask(out, first, n)
  local bytes = { 0, 0, 0, 0, 0, 0, 0, 0 }
  for row = first, first + n - 1 do
    local i = math.floor(row / 8) + 1
    bytes[i] = bytes[i] + 2 ^ (row % 8)
  end
  for _, b in ipairs(bytes) do out[#out + 1] = b end
end

local function start()
  -- served values are kept across a script reload: the sites are already written
  if TechniqueFilter.values then return end
  local game, why = game_rows()
  if not game then
    info(why .. ": the filter keeps the game's rows")
    return
  end
  local list, err = table_values()
  if not list then
    warn(err .. ": the filter keeps the game's rows")
    return
  end
  if #list == 0 then
    info("no tension values in " .. TENSION.table .. ": the filter keeps the game's rows")
    return
  end
  local families = declared_families()
  local same = #list == #game
  for i, v in ipairs(list) do
    if v ~= game[i] then same = false end
  end
  if same and #families == 0 then
    info("the table's values are the game's rows and no technique family is declared: nothing written")
    return
  end
  if #list > MAX_ROWS then
    warn(string.format("%d tension values: the window lists the first %d", #list, MAX_ROWS))
    for i = #list, MAX_ROWS + 1, -1 do list[i] = nil end
  end
  local callback = nil
  if #families > 0 then
    local ok, at = pcall(VRFW.hook.address, FAMILY_PASS)
    callback = ok and type(at) == "number" and at > 0 and at or nil
    if not callback then
      warn(FAMILY_PASS .. " is not installed (" .. tostring(at) .. "): no family rows")
      families = {}
    elseif #list + #families > MAX_ROWS then
      warn(string.format("%d tension rows + %d families: the window lists the first %d families", #list, #families,
        MAX_ROWS - #list))
      for i = #families, MAX_ROWS - #list + 1, -1 do families[i] = nil end
    end
  end
  -- the match stub's data: tension byte -> row index, the family row mask, the callback's address
  local bytes = {}
  for v = 0, 255 do bytes[v + 1] = NO_ROW end
  for i, v in ipairs(list) do bytes[v + 1] = i - 1 end
  push_row_mask(bytes, #list, #families)
  push_u64(bytes, callback or 0)
  if not apply("TechniqueFilter.Store") then
    VRFW.error("technique_filter: the row store stub was not written (see the patch line above): the filter keeps the game's rows")
    return
  end
  if not apply("TechniqueFilter.Match", { append = bytes }) then
    VRFW.error("technique_filter: the match stub was not written after the row store stub (see the patch line above): the tension tab does not filter")
    return
  end
  if not apply("TechniqueFilter.Rows", string.format("%02X", #list + #families)) then
    VRFW.error("technique_filter: the row count was not written (see the patch line above): the window keeps the game's row count")
  end
  TechniqueFilter.values = list
  TechniqueFilter.families = families
  local s, g = {}, {}
  for i, v in ipairs(list) do s[i] = tostring(v) end
  for i, v in ipairs(game) do g[i] = tostring(v) end
  info(string.format("%d tension rows: %s (game: %s); %d family rows", #list, table.concat(s, " "), table.concat(g, " "),
    #families))
end

-- skill id -> the family rows it belongs to ({ [index] = true }, index 0-based); nil until the moves of the families
-- are published
local function family_index()
  if TechniqueFilter.of_skill then return TechniqueFilter.of_skill end
  local families = TechniqueFilter.families
  if not families or #families == 0 then return nil end
  local of, any = {}, false
  for i, fam in ipairs(families) do
    local ok, moves = pcall(VRFW.technique_family, fam.key)
    if ok and type(moves) == "table" then
      any = true
      for _, id in ipairs(moves) do
        local m = math.floor(tonumber(id) or 0) % 4294967296
        of[m] = of[m] or {}
        of[m][i - 1] = true
      end
    end
  end
  if not any then return nil end
  TechniqueFilter.of_skill = of
  return of
end

-- the index is built when a slot loads, so the first filtered list does not build it
VRFW.on("slot_load", function()
  pcall(family_index)
end)

-- (skill id, filter block) -> 1 when the skill belongs to a ticked family row of the block. The match stub calls it
-- only while some family rows are ticked and some are not.
VRFW.on("hook:" .. FAMILY_PASS, function(ev)
  local skill, block = ev.args[1], ev.args[2]
  local values = TechniqueFilter.values
  local of = family_index()
  if not of or not values then return { ret = 1 } end
  local mine = of[math.floor(tonumber(skill) or 0) % 4294967296]
  if not mine then return { ret = 0 } end
  local lo, hi = rd("u32", block + 4), rd("u32", block + 8)
  if not lo or not hi then return { ret = 1 } end
  for i in pairs(mine) do
    local row = #values + i
    local word = row < 32 and lo or hi
    if bit32.btest(word, 2 ^ (row % 32)) then return { ret = 1 } end
  end
  return { ret = 0 }
end)

-- (list item type) -> n, value 1, ... (0 = the game's own rows)
function TechniqueFilter.CmdValues(list_item_type)
  local values = TechniqueFilter.values
  if tonumber(list_item_type) ~= TENSION.list_item_type or not values then return 0 end
  return #values, table.unpack(values)
end

-- () -> first row, n, text 1, name 1, ..., text n, name n (0 = no family rows)
function TechniqueFilter.CmdFamilies()
  local families, values = TechniqueFilter.families, TechniqueFilter.values
  if not families or #families == 0 or not values then return 0 end
  local out = {}
  for _, fam in ipairs(families) do
    out[#out + 1] = fam.text
    out[#out + 1] = fam.name
  end
  return #values, #families, table.unpack(out)
end

-- (save id, n, value 1, ...) -> true: the tension values ticked in that saved filter (n < 0 = forget)
function TechniqueFilter.CmdKeep(save_id, n, ...)
  local id, count = tonumber(save_id), tonumber(n)
  if not id or not count then return false end
  if count < 0 then
    TechniqueFilter.kept[id] = nil
    return true
  end
  local values, args = {}, { ... }
  for i = 1, math.min(count, MAX_ROWS) do
    local v = tonumber(args[i])
    if v then values[#values + 1] = v end
  end
  TechniqueFilter.kept[id] = values
  return true
end

-- (save id) -> n, value 1, ... (-1 = none kept)
function TechniqueFilter.CmdKept(save_id)
  local values = TechniqueFilter.kept[tonumber(save_id) or -1]
  if not values then return -1 end
  return #values, table.unpack(values)
end

start()
