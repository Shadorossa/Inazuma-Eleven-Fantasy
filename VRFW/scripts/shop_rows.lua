-- VR-Framework › locked shop rows (service S12 of VRFW 2.3, docs/framework/types/shop.md §13). Declarations: every
-- active mod's content\shop_locks\*.toml (`VRFW.shop_lock/1`, keys: content\types\shop_lock.toml); native side:
-- content\game\shop_rows.toml (hooks ShopRows.Condition / ShopRows.Fill, installed only when a mod declares locked rows).
--
-- The game's shop list builder never lists a row whose compiled condition (SHOP_INFO_ITEM +0x58) fails. For the
-- declared shops, a row whose condition fails is answered «visible» and recorded as locked when the condition is a real
-- progress gate (it mentions none of the declared `keep_hidden` flags), the row sells one of the declared `items` (when
-- given) and no other visible row of the shop sells the same item. A row whose condition holds leaves the set again
-- (self-correcting on every rebuild). The list item fill records layer instance -> row id (the menu's recycled
-- instances), so the menu Lua greys the locked rows and shows what they wait for.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_SHOP_LOCK_SHOPS | shop ids (SHOP_INFO col 0); none = ask | live (replaces the shop list until a title return) |
-- | CMND_VRFW_SHOP_LOCKED | inst (layer instance of shop01_02_list_item) | locked, row_id, kind, a, b |
-- | CMND_VRFW_SHOP_LOCKED_ITEM | item (SHOP_INFO_ITEM col 2) | locked, kind, a, b |
--
-- kind, a, b = what the row waits for, decoded from its compiled condition: 1 story phase (a), 2 Chronicle piece (a,
-- difficulty b), 3 global bit flag (a), 4 soccer game (a, difficulty b), 0 anything else.

ShopRows = ShopRows or {}

local D = require "lib/declarations"

local band = bit32.band
local KEY_RESETS = "vrfw.game_resets"

local function info(...) VRFW.log("shop_rows:", ...) end
local function warn(...) VRFW.warn("shop_rows:", ...) end

-- SHOP_INFO_ITEM row (0xB8 bytes): id +0, item +4, compiled condition +0x58, lineup flag +0x60; SHOP_INFO rows / count
local ROW_STRIDE, ROW_ITEM, ROW_COND, ROW_LINEUP = 0xB8, 0x4, 0x58, 0x60
local SHOP_ROWS, SHOP_COUNT = 0x38, 0x40
local LAYER_INST = 0x110
local MAX_BLOB, MAX_INST = 4096, 64

local KIND_UNKNOWN, KIND_PHASE, KIND_CHRONICLE, KIND_FLAG, KIND_GAME = 0, 1, 2, 3, 4
-- the condition functions the decoder names (crc32 of the game's condition function names)
local FN_GET_PHASE, FN_CHRONICLE_CLEAR, FN_GLOBAL_BIT, FN_GAME_CLEAR = 0xB91936DA, 0xC9783DBF, 0x2A3D4543, 0xB817C9C5

local DECLARED = {}      -- shop id -> { items = set | nil, keep = { flag … }, key }
local shops = {}         -- shop id -> rule in force (the declared ones, or the command's list)
local LIVE = false

-- row id -> cond, item -> cond, layer instance -> row id
local locked_rows, locked_items, inst_row = {}, {}, {}
local hits = 0

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- a title return since the last call: nothing listed yet, the recorded rows go; the declared shops again
local seen_epoch = nil
local function check_reset()
  local ok, e = pcall(VRFW.state.get, KEY_RESETS)
  if not ok then e = nil end
  if e ~= seen_epoch then
    if seen_epoch ~= nil then
      locked_rows, locked_items, inst_row = {}, {}, {}
      shops = {}
      for id, r in pairs(DECLARED) do shops[id] = r end
    end
    seen_epoch = e
  end
end

-- ---------------------------------------------------------------------------------------------- conditions

-- the payload bytes (after the 3-byte header `00 | u16 LE len`) of a compiled condition; nil when not a compiled one
local function payload_of(blob)
  if rd("u8", blob) ~= 0 then return nil end
  local n = rd("u16", blob + 1) or 0
  if n == 0 or n > MAX_BLOB then return nil end
  local p = {}
  for i = 1, n do
    local b = rd("u8", blob + 2 + i)
    if not b then return nil end
    p[i] = b
  end
  return p
end

local function be32(p, i)
  local a, b, c, d = p[i], p[i + 1], p[i + 2], p[i + 3]
  if not (a and b and c and d) then return nil end
  return ((a * 256 + b) * 256 + c) * 256 + d
end

-- the payload references `flag` as a hash literal (34 <crc32 big-endian>)
local function mentions(p, flag)
  for i = 1, #p - 4 do
    if p[i] == 0x34 and be32(p, i + 1) == flag then return true end
  end
  return false
end

-- a literal (32 int / 34 hash, big-endian) at i
local function lit(p, i)
  local t = p[i]
  if t ~= 0x32 and t ~= 0x34 then return nil end
  return be32(p, i + 1)
end

-- where the RPN tokens start: the engine's payload is `u16 BE len | nodes | tokens` (index 4 here, 1-based); a payload
-- without the BE length falls back to index 2
local function token_start(p)
  if #p >= 4 then
    local be = p[1] * 256 + p[2]
    if be > 0 and be + 2 <= #p and (p[4] == 0x35 or p[4] == 0x8F or p[4] == 0x90) then return 4 end
  end
  return 2
end

-- the first group whose function is a known gate gives kind, a, b
local function decode(p)
  local i = token_start(p)
  while i <= #p do
    local t = p[i]
    if t == 0x8F or t == 0x90 then
      i = i + 1
    elseif t == 0x35 then
      local f = be32(p, i + 1)
      local nargs = p[i + 7]
      if not f or not nargs then break end
      i = i + 8
      local args, ok = {}, true
      for k = 1, nargs do
        if p[i] ~= 0x28 or p[i + 1] ~= 0x00 or p[i + 2] ~= 0x06 or p[i + 3] ~= 0x02 then ok = false break end
        local v = lit(p, i + 4)
        if not v then ok = false break end
        if k <= 4 then args[k] = v end
        i = i + 9
      end
      if not ok then break end
      local value = lit(p, i)
      if not value then break end
      i = i + 6
      if f == FN_GET_PHASE and nargs == 0 then return { KIND_PHASE, value, 0 } end
      if f == FN_CHRONICLE_CLEAR and nargs == 2 then return { KIND_CHRONICLE, args[1], args[2] } end
      if f == FN_GLOBAL_BIT and nargs == 1 then return { KIND_FLAG, args[1], 0 } end
      if f == FN_GAME_CLEAR and nargs == 2 then return { KIND_GAME, args[1], args[2] } end
    else
      break
    end
  end
  return { KIND_UNKNOWN, 0, 0 }
end

-- the game's own answer for a compiled condition
local function eval(c)
  local ok, r = pcall(VRFW.hook.original, "ShopRows.Condition", c)
  return ok and r ~= nil and r ~= 0 and r ~= false
end

-- another row of the shop sells `item` with lineup flag 0 and a condition that holds (or none)
local function twin_visible(shop, row, item)
  local rows, n = rd("ptr", shop + SHOP_ROWS), rd("u32", shop + SHOP_COUNT)
  if not rows or not n then return false end
  for i = 0, math.min(n, 4096) - 1 do
    local r = rows + i * ROW_STRIDE
    if r ~= row and rd("u32", r + ROW_ITEM) == item and rd("u8", r + ROW_LINEUP) == 0 then
      local c = rd("ptr", r + ROW_COND)
      if not c or c == 0 then return true end
      if eval(c) then return true end
    end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------- hooks

-- EvalCondition of a shop row (r14 = the row, rbx = SHOP_INFO), after the game's answer
local function row_cond_post(ev)
  check_reset()
  local blob, row, shop = ev.args[1], ev.regs.r14, ev.regs.rbx
  local row_id = rd("u32", row) or 0
  local item = rd("u32", row and row + ROW_ITEM) or 0
  if ev.ret ~= 0 and ev.ret ~= false then
    if row_id ~= 0 then
      locked_rows[row_id] = nil
      locked_items[item] = nil
    end
    return nil
  end
  if row_id == 0 then return nil end
  local shop_id = rd("u32", shop) or 0
  local rule = shops[shop_id]
  if not rule then return nil end
  if rule.items and not rule.items[item] then return nil end
  local p = payload_of(blob)
  if not p then return nil end
  for _, f in ipairs(rule.keep) do
    if mentions(p, f) then return nil end
  end
  if item ~= 0 and twin_visible(shop, row, item) then return nil end
  local cond = decode(p)
  locked_rows[row_id] = cond
  if item ~= 0 then locked_items[item] = cond end
  hits = hits + 1
  if hits == 1 then
    info(string.format("shop 0x%08X row 0x%08X (item 0x%08X) listed as locked (first hit; %s)", shop_id, row_id, item, rule.key))
  end
  return { ret = 1 }
end

-- the list item fill (layerItem, &args, &row): layer instance -> row id
local function row_fill_pre(ev)
  local inst = rd("u32", ev.args[1] and ev.args[1] + LAYER_INST)
  local row = rd("ptr", ev.args[3])
  if inst and row and inst < MAX_INST then inst_row[inst] = rd("u32", row) or 0 end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local function start()
  local schema, why = D.schema("shop_lock")
  if not schema then
    warn(why .. ": the shops list their rows as the game does")
    return
  end
  local decls, skipped = D.load(schema, warn)
  local n_shops, parts = 0, {}
  for _, d in ipairs(decls) do
    local items
    if d.v.items and #d.v.items > 0 then
      items = {}
      for _, x in ipairs(d.v.items) do items[x] = true end
    end
    for _, id in ipairs(d.v.shops) do
      local r = DECLARED[id]
      if not r then
        r = { key = d.key, keep = {}, items = items }
        DECLARED[id] = r
        n_shops = n_shops + 1
      else
        -- a second declaration of the shop: the item filters join (none = every row), the kept flags add up
        r.key = r.key .. "+" .. d.key
        if r.items and items then
          for x in pairs(items) do r.items[x] = true end
        else
          r.items = nil
        end
      end
      for _, f in ipairs(d.v.keep_hidden or {}) do r.keep[#r.keep + 1] = f end
    end
    parts[#parts + 1] = string.format("%s (%d shop(s)%s)", d.key, #d.v.shops, items and string.format(", %d item(s)", #d.v.items) or "")
  end
  for id, r in pairs(DECLARED) do shops[id] = r end
  if n_shops == 0 then
    if #decls > 0 or (skipped or 0) > 0 then
      info(string.format("off: %d declaration(s) (%d left out by `when`), no shop: the shops list their rows as the game does", #decls, skipped or 0))
    else
      info("off: no mod declares locked shop rows: the shops list their rows as the game does")
    end
    return
  end
  local okc, rc, ec = pcall(VRFW.hook.apply, "ShopRows.Condition")
  local okf, rf, ef = pcall(VRFW.hook.apply, "ShopRows.Fill")
  LIVE = okc and rc == true and okf and rf == true
  if LIVE then
    info(string.format("on: rows with an unmet progress condition listed as locked in %d shop(s): %s", n_shops, table.concat(parts, ", ")))
  else
    warn(string.format("detours not installed (condition: %s, fill: %s): the shops list their rows as the game does",
      tostring(okc and (rc == true and "ok" or ec) or rc), tostring(okf and (rf == true and "ok" or ef) or rf)))
  end
end

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_VRFW_SHOP_LOCK_SHOPS(ids...) -> live
function ShopRows.Shops(...)
  check_reset()
  local ids = {}
  for _, v in ipairs({ ... }) do
    v = tonumber(v)
    if v and v ~= 0 then ids[#ids + 1] = band(v, 0xFFFFFFFF) end
  end
  if #ids > 0 then
    shops = {}
    for _, id in ipairs(ids) do shops[id] = DECLARED[id] or { key = "CMND_VRFW_SHOP_LOCK_SHOPS", keep = {}, items = nil } end
    info(string.format("CMND_VRFW_SHOP_LOCK_SHOPS: %d shop(s) until the title (live %s)", #ids, tostring(LIVE)))
  end
  return LIVE
end

-- CMND_VRFW_SHOP_LOCKED(inst) -> locked, row_id, kind, a, b
function ShopRows.Locked(inst)
  check_reset()
  inst = tonumber(inst) or -1
  local row = (inst >= 0 and inst < MAX_INST) and (inst_row[math.floor(inst)] or 0) or 0
  local c = row ~= 0 and locked_rows[row] or nil
  local k = c or { 0, 0, 0 }
  return c ~= nil, row, k[1], k[2], k[3]
end

-- CMND_VRFW_SHOP_LOCKED_ITEM(item) -> locked, kind, a, b
function ShopRows.LockedItem(item)
  check_reset()
  item = tonumber(item) or 0
  if item ~= 0 then item = band(item, 0xFFFFFFFF) end
  local c = item ~= 0 and locked_items[item] or nil
  local k = c or { 0, 0, 0 }
  return c ~= nil, k[1], k[2], k[3]
end

start()

if LIVE then
  VRFW.on("hook:ShopRows.Condition:post", row_cond_post)
  VRFW.on("hook:ShopRows.Fill", row_fill_pre)
end
