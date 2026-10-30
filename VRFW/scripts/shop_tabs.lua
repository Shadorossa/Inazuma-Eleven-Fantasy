-- Shop tab split. Declarations: every active mod's content\shop_tabs\*.toml (`VRFW.shop_tab/1`); native side: content\game\shop_tabs.toml;
-- menu side: assets\lua\menu\shop_menu_buy\140_shop_tabs.lua.
-- A shop's game tab (a shop slot type, e.g. 16 special moves) is listed as one tab per declared [[VRFW.ShopTab]] of that shop: each lists the rows
-- of the game tab whose item sub-kind it names (a row named by no tab goes to the first one), with its own icon and title.
-- The shop list view's tab list (+0x1FE8 count, +0x1FEC slot types, at most 21) gets one entry per tab: the first keeps the game tab's slot type,
-- the others a marker (MARK + tab index). The tab builder sees the slot type of the tab it builds: a marker is answered as the game tab for the rows
-- of that tab, and every other row of the game tab is skipped.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_SHOP_TAB_KEYS | | n, key 1 … key n: declared shops named by key |
-- | CMND_VRFW_SHOP_TAB_BIND | key, shop id | bound |
-- | CMND_VRFW_SHOP_TABS | shop id | split, n, icon 1, text id 1, … (split 0 = no split tabs) |

ShopTabs = ShopTabs or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("shop_tabs")

-- shop list view fields
local VIEW_SHOP, VIEW_TAB_COUNT, VIEW_TABS = 0x2040, 0x1FE8, 0x1FEC
local TABS_MAX = 21
-- the item record of the row being built (on the builder's stack) and its sub-kind
local ROW_RECORD_AT_RSP, RECORD_SUB = 0x68, 0x3E
local MARK = 0x56540000

local BY_KEY = {}  -- shop key -> rule (declared by key, bound to an id by the menu)
local BY_ID = {}   -- shop id -> rule { split, tabs = { { subs = set, icon, text, key } … }, sub_tab = sub -> tab index }
local LIVE = false
local hits = 0

local Id = require "lib/ids"
local u32 = Id.u32

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- ---------------------------------------------------------------------------------------------- hooks

-- after the view built its tab list: the split game tab becomes one entry per declared tab
local function list_post(ev)
  local view = ev.args[1]
  local shop = rd("u32", view and view + VIEW_SHOP)
  local rule = shop and BY_ID[shop]
  if not rule then return nil end
  local n = rd("u32", view + VIEW_TAB_COUNT) or 0
  if n == 0 or n > TABS_MAX then return nil end
  local list, at = {}, nil
  for i = 0, n - 1 do
    local v = rd("u32", view + VIEW_TABS + 4 * i) or 0
    if v == rule.split and at == nil then at = i end
    if v >= MARK and v < MARK + TABS_MAX then return nil end   -- already split
    list[#list + 1] = v
  end
  if at == nil then return nil end
  local out = {}
  for i = 1, at do out[#out + 1] = list[i] end
  out[#out + 1] = rule.split
  for k = 2, #rule.tabs do out[#out + 1] = MARK + k end
  for i = at + 2, #list do out[#out + 1] = list[i] end
  if #out > TABS_MAX then
    warn(string.format("shop 0x%08X: %d tabs after the split (at most %d): left as the game's", shop, #out, TABS_MAX))
    return nil
  end
  for i, v in ipairs(out) do VRFW.mem.write("u32", view + VIEW_TABS + 4 * (i - 1), v) end
  VRFW.mem.write("u32", view + VIEW_TAB_COUNT, #out)
  return nil
end

-- the builder's row test: r9d = the slot type of the tab being built
local function row_test(ev)
  local slot = u32(ev.regs.r9)
  if slot == 0 then return nil end
  local view = ev.regs.r13
  local shop = rd("u32", view and view + VIEW_SHOP)
  local rule = shop and BY_ID[shop]
  if not rule then return nil end
  local tab
  if slot == rule.split then
    tab = 1
  elseif slot > MARK and slot <= MARK + #rule.tabs then
    tab = slot - MARK
  else
    return nil
  end
  local record = rd("ptr", ev.regs.rsp + ROW_RECORD_AT_RSP)
  if not record or record == 0 then
    return tab == 1 and nil or { skip = true }
  end
  local sub = rd("u16", record + RECORD_SUB)
  -- a row named by no tab belongs to the first one (rows of other game tabs fail the game's own test there)
  local own = sub and rule.sub_tab[sub] or 1
  if own ~= tab then return { skip = true } end
  hits = hits + 1
  if hits == 1 then
    info(string.format("shop 0x%08X: a row of sub-kind %d listed in split tab %d (first hit)", shop, sub or -1, tab))
  end
  if tab ~= 1 then return { regs = { r9 = rule.split } } end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local function start()
  local schema, why = D.schema("shop_tab")
  if not schema then
    warn(why .. ": the shops keep the game's tabs")
    return
  end
  local decls = D.load(schema, warn)
  local rules = {}  -- shop text -> rule
  for _, d in ipairs(decls) do
    local s = d.v.shop
    local r = rules[s]
    if not r then
      r = { split = d.v.split, tabs = {}, sub_tab = {}, shop = s }
      rules[s] = r
    elseif r.split ~= d.v.split then
      warn(string.format("%s: shop %s already splits tab %d: left out", d.key, s, r.split))
      goto next_decl
    end
    r.tabs[#r.tabs + 1] = { key = d.key, order = d.v.order or 0, seq = #r.tabs, subs = d.v.item_subs, icon = d.v.icon,
      text = D.id_of(d.v.text) or 0 }
    ::next_decl::
  end
  local n = 0
  for s, r in pairs(rules) do
    table.sort(r.tabs, function(a, b)
      if a.order ~= b.order then return a.order < b.order end
      return a.seq < b.seq
    end)
    for k, t in ipairs(r.tabs) do
      for _, sub in ipairs(t.subs) do
        if r.sub_tab[sub] == nil then r.sub_tab[sub] = k end
      end
    end
    if #r.tabs < 2 then
      warn(string.format("shop %s: one tab declared for game tab %d: nothing to split", s, r.split))
    else
      local id = s:match("^%s*0[xX]%x+%s*$") and D.id_of(s) or nil
      if id then BY_ID[id] = r else BY_KEY[s] = r end
      n = n + 1
    end
  end
  if n == 0 then
    info("off: no mod declares split shop tabs: the shops keep the game's tabs")
    return
  end
  local okl, rl, el = pcall(VRFW.hook.apply, "ShopTabs.List")
  local okr, rr, er = pcall(VRFW.hook.apply, "ShopTabs.Row")
  LIVE = okl and rl == true and okr and rr == true
  if LIVE then
    local parts = {}
    for s, r in pairs(rules) do parts[#parts + 1] = string.format("%s (game tab %d -> %d tabs)", s, r.split, #r.tabs) end
    table.sort(parts)
    info("on: " .. table.concat(parts, ", "))
  else
    BY_ID, BY_KEY = {}, {}
    warn(string.format("detours not installed (list: %s, row: %s): the shops keep the game's tabs",
      tostring(okl and (rl == true and "ok" or el) or rl), tostring(okr and (rr == true and "ok" or er) or rr)))
  end
end

-- ---------------------------------------------------------------------------------------------- commands

-- CMND_VRFW_SHOP_TAB_KEYS() -> n, key 1 … key n
function ShopTabs.Keys()
  local keys = {}
  for k in pairs(BY_KEY) do keys[#keys + 1] = k end
  table.sort(keys)
  return #keys, table.unpack(keys)
end

-- CMND_VRFW_SHOP_TAB_BIND(key, shop id) -> bound
function ShopTabs.Bind(key, shop)
  local r = type(key) == "string" and BY_KEY[key] or nil
  shop = u32(shop)
  if not r or shop == 0 then return false end
  if BY_ID[shop] ~= r then
    BY_ID[shop] = r
    info(string.format("shop %s = 0x%08X", key, shop))
  end
  return true
end

-- CMND_VRFW_SHOP_TABS(shop id) -> split, n, icon 1, text id 1, …
function ShopTabs.Of(shop)
  local r = LIVE and BY_ID[u32(shop)] or nil
  if not r then return 0, 0 end
  local out = {}
  for _, t in ipairs(r.tabs) do
    out[#out + 1] = t.icon
    out[#out + 1] = t.text
  end
  return r.split, #r.tabs, table.unpack(out)
end

start()

if LIVE then
  VRFW.on("hook:ShopTabs.List:post", list_post)
  VRFW.on("hook:ShopTabs.Row", row_test)
end
