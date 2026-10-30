-- Option rows: a declaration adds one value to a row of the game's settings menu (declarations: content\option_rows\*.toml; native side: content\game\option_rows.toml).
-- The game keeps `stores` while the new value is chosen; the declaring mod's option `option` reads 1 (chosen).
-- CMND_VRFW_SETTING_ROW(key) -> chosen, index, live

OptionRows = OptionRows or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("option_rows")

-- settings row record: setting type, value list (text ids), u16 count, shown index and base (value = index + base)
local ROW_TYPE, ROW_LIST, ROW_COUNT, ROW_INDEX, ROW_BASE = 0x08, 0x10, 0x18, 0x1C, 0x20

local ROWS = {}          -- setting type -> declaration in force (+ our value list buffer)
local KEYS = {}          -- "<mod>.<name>" / "<name>" -> row
local LIVE = false
local pending = nil      -- write in progress

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if type(at) ~= "number" or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

local crc = VRFW.crc32

-- declaring mod's option: the new value is chosen
local function chosen(r)
  local ok, t = pcall(VRFW.options.values, r.mod)
  if not ok or type(t) ~= "table" then return false end
  return (tonumber(t[r.option]) or 0) ~= 0
end

local function set_chosen(r, on)
  if chosen(r) == on then return true end
  local ok, done, why = pcall(VRFW.options.store, { [r.option] = on and 1 or false }, r.mod)
  if not ok or done ~= true then
    warn(string.format("%s: option %s of %s not saved (%s)", r.key, r.option, r.mod, tostring(ok and why or done)))
    return false
  end
  return true
end

-- --- declarations

local function start()
  local schema, why = D.schema("option_row")
  if not schema then
    warn(why .. ": the settings rows stay the game's")
    return
  end
  local decls, skipped = D.load(schema, warn)
  for _, d in ipairs(decls) do
    local v = d.v
    if v.at > v.game_values then
      warn(string.format("%s: at = %d is past the row's %d value(s): left out", d.where, v.at, v.game_values))
    elseif v.stores >= v.game_values then
      warn(string.format("%s: stores = %d is not one of the row's %d value(s): left out", d.where, v.stores, v.game_values))
    else
      local prev = ROWS[v.setting]
      if prev then
        warn(string.format("setting %d: %s replaces %s (one declared value per row; later mod wins)", v.setting, d.key, prev.key))
      end
      ROWS[v.setting] = { key = d.key, mod = d.mod, name = v.name, setting = v.setting, text = v.text, id = crc(v.text),
        at = v.at, game_values = v.game_values, stores = v.stores, option = v.option, list = 0 }
    end
  end
  local n = 0
  for _, r in pairs(ROWS) do
    n = n + 1
    KEYS[r.key] = r
    KEYS[r.name] = KEYS[r.name] or r
  end
  if n == 0 then
    if (skipped or 0) > 0 or #decls > 0 then
      info(string.format("off: %d declaration(s) (%d left out by `when`), none in force: the game's settings rows", #decls, skipped or 0))
    else
      info("off: no mod declares an option row value: the game's settings rows")
    end
    return
  end
  local okr, r1, e1 = pcall(VRFW.hook.apply, "OptionRows.Read")
  local okw, r2, e2 = pcall(VRFW.hook.apply, "OptionRows.Write")
  LIVE = okr and r1 == true and okw and r2 == true
  local parts = {}
  for s, r in pairs(ROWS) do
    parts[#parts + 1] = string.format("setting %d + %s at %d (stores %d, option %s.%s%s)", s, r.text, r.at, r.stores, r.mod, r.option,
      chosen(r) and ", chosen" or "")
  end
  table.sort(parts)
  if LIVE then
    info(string.format("on: %d row(s): %s", n, table.concat(parts, "; ")))
  else
    warn(string.format("detours not installed (read: %s, write: %s): the settings rows stay the game's (%s)",
      tostring(okr and (r1 == true and "ok" or e1) or r1), tostring(okw and (r2 == true and "ok" or e2) or r2), table.concat(parts, "; ")))
  end
end

-- our value list for row r whose game list is at `list`, built once
local function our_list(r, list)
  if r.list ~= 0 then return r.list end
  local ids = {}
  for i = 0, r.game_values - 1 do
    local x = rd("u32", list + 4 * i)
    if not x then return nil end
    ids[#ids + 1] = x
  end
  table.insert(ids, r.at + 1, r.id)
  local ok, p = pcall(VRFW.mem.buffer, "option_rows." .. r.setting, 4 * #ids)
  if not ok or type(p) ~= "number" then return nil end
  for i, x in ipairs(ids) do wr("u32", p + 4 * (i - 1), x) end
  r.list = p
  info(string.format("setting %d: %d value(s), %s (0x%08X) at %d", r.setting, #ids, r.text, r.id, r.at))
  return p
end

-- shown place of game value g (the new value when chosen)
local function shown(r, g)
  if chosen(r) and g == r.stores then return r.at end
  if g >= r.at then return g + 1 end
  return g
end

-- after the engine read the row: install our list and shown index
local function on_read(ev)
  local row = ev.args[2]
  local r = ROWS[rd("u32", row and row + ROW_TYPE) or -1]
  if not r then return nil end
  local list, count = rd("ptr", row + ROW_LIST), rd("u16", row + ROW_COUNT)
  if not list or not count then return nil end
  if list ~= r.list then
    if count ~= r.game_values then return nil end   -- not the declared game list: left as is
    local p = our_list(r, list)
    if not p then return nil end
    wr("ptr", row + ROW_LIST, p)
    wr("u16", row + ROW_COUNT, r.game_values + 1)
  end
  local base = rd("i32", row + ROW_BASE) or 0
  local idx = rd("i32", row + ROW_INDEX)
  if not idx then return nil end
  wr("i32", row + ROW_INDEX, shown(r, idx + base) - base)
  return nil
end

-- on engine write: chosen place -> game value; shown index restored afterwards
local function on_write(ev)
  pending = nil
  local row = ev.args[2]
  local r = ROWS[rd("u32", row and row + ROW_TYPE) or -1]
  if not r or r.list == 0 or rd("ptr", row + ROW_LIST) ~= r.list then return nil end
  local i, base = rd("i32", row + ROW_INDEX), rd("i32", row + ROW_BASE)
  if not i or not base then return nil end
  local at = math.max(i + base, 0)
  local ours = at == r.at
  local g = ours and r.stores or (at > r.at and at - 1 or at)
  wr("i32", row + ROW_INDEX, g - base)
  pending = { row = row, i = i, r = r, ours = ours, g = g }
  return nil
end

local function on_write_post()
  local w = pending
  pending = nil
  if not w then return nil end
  wr("i32", w.row + ROW_INDEX, w.i)
  if chosen(w.r) ~= w.ours and set_chosen(w.r, w.ours) then
    info(string.format("%s %s (the game keeps its value %d)", w.r.key, w.ours and "chosen" or "no longer chosen", w.g))
  end
  return nil
end

-- --- command

-- CMND_VRFW_SETTING_ROW(key) -> chosen, index, live
function OptionRows.Cmd(key)
  local r = KEYS[tostring(key or "")]
  if not r then return nil end
  return chosen(r), r.at, LIVE
end

start()

if LIVE then
  VRFW.on("hook:OptionRows.Read:post", on_read)
  VRFW.on("hook:OptionRows.Write", on_write)
  VRFW.on("hook:OptionRows.Write:post", on_write_post)
end
