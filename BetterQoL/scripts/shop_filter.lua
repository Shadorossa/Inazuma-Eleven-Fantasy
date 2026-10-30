-- Utilities › shop filter (feature shop_filter; docs/game/modes/tienda-general.md §15).
--
-- The retail item filter window's tabs and boxes are static per inventory type: 0-3 equipment (stats), 4 kits /
-- 5 emblems (series), 6-9 moves, 10-16 auras. Its accept button gives the filter params ({listItemType, value,
-- option} triples) to CMND_BETTERQOL_SHOP_FILTER_SET; the shop tab builder's category -> tab call (hook ShopTabOf) then
-- sends a row of that tab to no tab when the engine's own item test says no. The rows of the tab built last are
-- recorded for the window's counter (CMND_BETTERQOL_SHOP_FILTER_COUNT).

local ROW_ITEM = 0x4
local VIEW_SHOP = 0x2040
local VIEW_NEW_LIST, NEW_LIST_MAX = 0x2054, 10
local MAX_TAB_ROWS = 0x140
local NO_TAB = 0xFFFFFFFF -- never a slot type (slot types 9 / 10, the lot tabs, are never filtered)

local Id = require "VRFW/lib/ids"
local u32 = Id.u32

local function arg_u32(v)
  if type(v) ~= "number" then
    return 0
  end
  return u32(v)
end

-- inventory type of the item filter window -> engine test (nil = no filter for that type)
local function pred_of_inv(inv)
  if inv <= 3 then
    return { series = true, mask = 0x2000 * 2 ^ inv }
  elseif inv == 4 then
    return { series = true, mask = 0x20000 }
  elseif inv == 5 then
    return { series = true, mask = 0x40000 }
  elseif inv <= 9 then
    return { series = false, mask = 0x80000000 * 2 ^ (inv - 6), kind = inv - 5 }
  elseif inv <= 16 then
    return { series = false, mask = 0x800000000, kind = 8 }
  end
  return nil
end

-- the 0x20-byte block of ItemTestSeriesStat, filled like SetItemFilter: +0 series count, +4 series (<= 10), +0x10 stat
-- count, +0x14 stats (<= 8), +0x1C series test on, +0x1D stat test on ({8, 1} / {8, 2} = «Todos» = test off)
local function series_stat_block(params)
  local b = {}
  for i = 0, 0x1F do
    b[i] = 0
  end
  b[0x1C], b[0x1D] = 1, 1
  for _, p in ipairs(params) do
    local t, v = p[1], p[2]
    if t == 1 and b[0] < 10 then
      b[4 + b[0]] = v % 256
      b[0] = b[0] + 1
    elseif t == 2 and b[0x10] < 8 then
      b[0x14 + b[0x10]] = v % 256
      b[0x10] = b[0x10] + 1
    elseif t == 8 and v == 1 then
      b[0x1C] = 0
    elseif t == 8 and v == 2 then
      b[0x1D] = 0
    end
  end
  return b, 0x20
end

-- the 0x38-byte block of ItemTestSkill, filled like 0xD8D990: tension (type 3, <= 6), element (4, <= 6), skill type
-- (5, <= 7), category (6, <= 9), +0x34..+0x37 the four tests on ({8, 3..6} = «Todos» = off)
local function skill_block(params)
  local b = {}
  for i = 0, 0x37 do
    b[i] = 0
  end
  for i = 0x34, 0x37 do
    b[i] = 1
  end
  local lists = { [3] = { 0x00, 0x04, 6 }, [4] = { 0x0C, 0x10, 6 }, [5] = { 0x18, 0x1C, 7 }, [6] = { 0x24, 0x28, 9 } }
  for _, p in ipairs(params) do
    local t, v = p[1], p[2]
    local l = lists[t]
    if l and b[l[1]] < l[3] then
      b[l[2] + b[l[1]]] = v % 256
      b[l[1]] = b[l[1]] + 1
    elseif t == 8 and v >= 3 and v <= 6 then
      b[0x34 + v - 3] = 0
    end
  end
  return b, 0x38
end

-- the same block filled by the game's own code (ItemFilterBlockFill), so a framework patch of the rows (the
-- technique filter's tension rows) applies; nil when the call is not available
local MAX_PARAMS = 128
local function game_skill_block(params)
  if #params > MAX_PARAMS then
    return nil
  end
  local bp, pp = VRFW.mem.buffer("fill_block", 0x38), VRFW.mem.buffer("fill_params", 12 * MAX_PARAMS)
  for i = 0, 0x37 do
    VRFW.mem.write("u8", bp + i, (i >= 0x34) and 1 or 0)
  end
  for i, p in ipairs(params) do
    local at = pp + 12 * (i - 1)
    VRFW.mem.write("u32", at, arg_u32(p[1]) % 256)
    VRFW.mem.write("u32", at + 4, arg_u32(p[2]))
    VRFW.mem.write("u32", at + 8, arg_u32(p[3]))
  end
  local ok, err = pcall(VRFW.call, "ItemFilterBlockFill", bp, pp, #params)
  if not ok then
    VRFW.warn("game filter fill failed (" .. tostring(err) .. "): the shop's own block is used")
    return nil
  end
  local bytes = VRFW.mem.read_array("u8", bp, 0x38)
  if type(bytes) ~= "table" then
    return nil
  end
  local b = {}
  for i = 0, 0x37 do
    b[i] = bytes[i + 1]
  end
  return b, 0x38
end

local function filter_of(inv, params)
  local pred = pred_of_inv(inv)
  if not pred then
    return nil
  end
  local block, n
  if pred.series then
    block, n = series_stat_block(params)
  else
    block, n = game_skill_block(params)
    if not block then
      block, n = skill_block(params)
    end
  end
  pred.block, pred.n = block, n
  return pred
end

local function triples(flat)
  local out = {}
  for i = 1, #flat - 2, 3 do
    out[#out + 1] = { flat[i], flat[i + 1], flat[i + 2] }
  end
  return out
end

-- the engine's own test of `item` (true when it passes; a failed call lets it pass)
local function passes(f, item)
  local bp, idp = VRFW.mem.buffer("block", 0x38), VRFW.mem.buffer("item", 4)
  for i = 0, f.n - 1 do
    VRFW.mem.write("u8", bp + i, f.block[i])
  end
  VRFW.mem.write("u32", idp, item)
  local ok, r
  if f.series then
    ok, r = pcall(VRFW.call, "ItemTestSeriesStat", 0, f.mask, idp, bp)
  else
    ok, r = pcall(VRFW.call, "ItemTestSkill", 0, f.mask, f.kind, idp, bp)
  end
  if not ok then
    VRFW.warn(string.format("engine item test failed (%s, item 0x%08X): row kept", tostring(r), item))
    return true
  end
  return bit32.band(r or 0, 0xFF) ~= 0
end

local filters = {} -- slot type -> filter
local hits = 0
local rec = { view = 0, slot = -1, rows = {}, items = {}, seen = {} }

local function rec_reset(view, slot)
  rec = { view = view, slot = slot, rows = {}, items = {}, seen = {} }
end

-- a build walks the visible table in the same order every time: seeing the first row again = a new build
local function rec_add(view, slot, row, item)
  if rec.view ~= view or rec.slot ~= slot or rec.rows[1] == row then
    rec_reset(view, slot)
  end
  if #rec.rows < 4 * MAX_TAB_ROWS and not rec.seen[row] then
    rec.seen[row] = true
    rec.rows[#rec.rows + 1] = row
    rec.items[#rec.items + 1] = item
  end
end

-- the tab builder asked the tab of a row: ev.args = (rcx, category, sub, slot type being built), ev.regs.r13 = the
-- list view, ev.regs.rsi = the row; ev.ret = the game's answer
VRFW.on("hook:ShopTabOf:post", function(ev)
  local t, slot = ev.ret, ev.args[4]
  if t ~= slot then
    return nil
  end
  local view, row = ev.regs.r13, ev.regs.rsi
  local ok, item = pcall(VRFW.mem.read, "u32", row + ROW_ITEM)
  item = ok and item or 0
  rec_add(view, slot, row, item)
  local f = filters[slot]
  if f and item ~= 0 and not passes(f, item) then
    if hits == 0 then
      local ok2, shop = pcall(VRFW.mem.read, "u32", view + VIEW_SHOP)
      VRFW.log(string.format("shop 0x%08X slot %d: item 0x%08X filtered out (first hit)", ok2 and shop or 0, slot, item))
    end
    hits = hits + 1
    return { ret = NO_TAB }
  end
  return nil
end)

local function live()
  return VRFW.is_on("ShopTabOf")
end

-- slot, inv, t1, v1, o1, … -> ok
function BetterQoL.ShopFilterSet(slot, inv, ...)
  slot, inv = arg_u32(slot), arg_u32(inv)
  local flat = {}
  for _, x in ipairs({ ... }) do
    flat[#flat + 1] = arg_u32(x)
  end
  local params = triples(flat)
  local ok = true
  if #params == 0 then
    filters[slot] = nil
  else
    local f = filter_of(inv, params)
    if f then
      filters[slot] = f
    else
      ok = false
    end
  end
  hits = 0
  VRFW.log(string.format("CMND_BETTERQOL_SHOP_FILTER_SET(slot %d, inv %d, %d params) -> %s", slot, inv, #params, tostring(ok)))
  return ok and live()
end

-- inv, t1, v1, o1, … -> shown, total over the rows of the tab built last
function BetterQoL.ShopFilterCount(inv, ...)
  inv = arg_u32(inv)
  local flat = {}
  for _, x in ipairs({ ... }) do
    flat[#flat + 1] = arg_u32(x)
  end
  local f = filter_of(inv, triples(flat))
  local total, shown = #rec.items, #rec.items
  if f then
    shown = 0
    for _, it in ipairs(rec.items) do
      if it == 0 or passes(f, it) then
        shown = shown + 1
      end
    end
  end
  return shown, total
end

-- -> live, cleared
function BetterQoL.ShopFilterReset()
  local n = 0
  for _ in pairs(filters) do
    n = n + 1
  end
  filters = {}
  if n > 0 then
    VRFW.log("CMND_BETTERQOL_SHOP_FILTER_RESET: " .. n .. " tab filters dropped")
  end
  return live(), n
end

-- the «new» list of the list view built last (the first 0 ends it)
local function view_new_list()
  local out = {}
  if rec.view < 0x10000 then
    return out
  end
  for i = 0, NEW_LIST_MAX - 1 do
    local ok, id = pcall(VRFW.mem.read, "u32", rec.view + VIEW_NEW_LIST + 4 * i)
    if not ok or id == 0 then
      break
    end
    out[#out + 1] = id
  end
  return out
end

-- -> n, id1, …, idN
function BetterQoL.ShopNewList()
  local v = view_new_list()
  return #v, table.unpack(v)
end

-- id -> true, isNew (the first true says the getter exists and answered)
function BetterQoL.ShopNewState(id)
  id = arg_u32(id)
  if id == 0 then
    return true, false
  end
  for _, x in ipairs(view_new_list()) do
    if x == id then
      return true, true
    end
  end
  return true, false
end
