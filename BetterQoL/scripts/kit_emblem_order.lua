-- BetterQoL › kit and emblem order (feature kit_emblem_order, always on). In the inventory («Objetos», item_menu),
-- the kits tab and the emblems tab list their items by saga (IE1, IE2, IE3, GO, Chrono Stone, Galaxy, Ares, Orion,
-- Victory Road, then the mods' series), and inside a saga by that saga's team order; items of no team come at the end
-- of their saga, items of no saga at the very end. Other tabs and the alphabetical sort (sort type 5) keep the game's
-- order. Hook and the list layout: content\game\kit_emblem_order.toml.
--
-- Everything comes from the tables the game loads (the mods' rows included):
-- * saga of an item: the first series flag of its ITEM_*_INFO_SERIES row (the row after it in the file), else the
--   first series of the era column (team_kit_<era> / team_emblem_id_<era>) that names it;
-- * sagas: the series types in their column order (team_number_<x> of belong_team_config);
-- * team of an item: belong_team_config, a kit = the uniform (item_config ITEM_FASHION_INFO column `uniform`) in one
--   of the team's team_kit_<era> columns, an emblem = the item in one of its team_emblem_id_<era> columns;
-- * team order inside a saga: the team's number in that saga's team_number_<x> column; a team without one follows,
--   in table order. An item of several teams takes the best-placed one.

local ITEM_KEY = "data/common/gamedata/item/item_config_*.cfg.bin"
local BELONG_TABLE = "character/belong_team"

-- the item list (the list view's +0x1E0): u32 count at +0x8, row pointers at +0x10; a row's item id at +0x8
local LIST_COUNT, LIST_ROWS, ROW_ITEM = 0x8, 0x10, 0x8
local MAX_ROWS = 0x898
local SORT_ALPHABETICAL = 5

local LAST = 0x7FFFFFFF
local NO_NUMBER = 0x1000000

local Id = require "VRFW/lib/ids"

local function u32(v)
  if type(v) ~= "number" then
    return 0
  end
  return Id.u32(v)
end

-- the first value of `row` among `names`
local function col(row, ...)
  for _, n in ipairs({ ... }) do
    if row[n] ~= nil then
      return row[n]
    end
  end
  return nil
end

-- item id -> { saga, place in the saga }; kits and emblems apart (a tab is re-ordered when all its rows are of one)
local kits, emblems = {}, {}
local ready = false

local function build()
  local nums, num_names, kit_cols, emblem_cols = {}, {}, {}, {}
  for i, n in ipairs(VRFW.table.columns(BELONG_TABLE)) do
    local x = n:match("^team_number_(.+)$") or n:match("^teamNumber_(.+)$")
    if x then
      nums[#nums + 1] = i
      num_names[#num_names + 1] = x:lower()
    end
    local k = n:match("^team_kit_(.+)$") or n:match("^teamKit_(.+)$")
    if k then
      kit_cols[#kit_cols + 1] = { era = k:lower(), col = i }
    end
    local e = n:match("^team_emblem_id_(.+)$") or n:match("^teamEmblemId_(.+)$")
    if e then
      emblem_cols[#emblem_cols + 1] = { era = e:lower(), col = i }
    end
  end
  -- the first saga an era serves (ie -> ie1, go -> go1, areori -> ares, v -> v)
  local function era_saga(era)
    for k, x in ipairs(num_names) do
      if x:sub(1, #era) == era or (#x >= 3 and era:find(x:sub(1, 3), 1, true)) then
        return k
      end
    end
    return LAST
  end
  for _, c in ipairs(kit_cols) do
    c.saga = era_saga(c.era)
  end
  for _, c in ipairs(emblem_cols) do
    c.saga = era_saga(c.era)
  end

  -- uniform / emblem item -> its teams { { team row, era saga } … }
  local rows = VRFW.table.rows(BELONG_TABLE)
  local by_uniform, by_emblem = {}, {}
  local function add(map, id, ri, saga)
    if id ~= 0 then
      map[id] = map[id] or {}
      local l = map[id]
      l[#l + 1] = { ri, saga }
    end
  end
  for ri, r in ipairs(rows) do
    if u32(col(r, "belong_team_id", "belongTeamId")) ~= 0 then
      for _, c in ipairs(kit_cols) do
        add(by_uniform, u32(r[c.col]), ri, c.saga)
      end
      for _, c in ipairs(emblem_cols) do
        add(by_emblem, u32(r[c.col]), ri, c.saga)
      end
    end
  end
  -- a team's place in saga k: its number there, else after the numbered teams in table order
  local function place(ri, k)
    local i = nums[k]
    local n = i and rows[ri][i]
    if type(n) == "number" and n > 0 then
      return n
    end
    return NO_NUMBER + ri
  end

  -- series flags (the ITEM_*_INFO_SERIES row after the item's row, file order)
  local flags = {}
  local okk, key = pcall(VRFW.table.source, "item/item_fashion")
  local ok, ents = pcall(VRFW.table.entries, okk and key or ITEM_KEY,
    { "ITEM_FASHION_INFO", "ITEM_FASHION_INFO_SERIES", "ITEM_EMBLEM_INFO", "ITEM_EMBLEM_INFO_SERIES" }, true)
  if ok and type(ents) == "table" then
    local cur = nil
    for _, e in ipairs(ents) do
      if e.name == "ITEM_FASHION_INFO" or e.name == "ITEM_EMBLEM_INFO" then
        cur = u32(e[1])
      elseif e.name == "ITEM_FASHION_INFO_SERIES" or e.name == "ITEM_EMBLEM_INFO_SERIES" then
        if cur and flags[cur] == nil then
          for k = 1, 9 do
            local v = e[k]
            if v == true or (type(v) == "number" and v ~= 0) then
              flags[cur] = k
              break
            end
          end
        end
        cur = nil
      end
    end
  else
    VRFW.warn("item_config series rows not readable (" .. tostring(ents) .. "): sagas from the team's era columns")
  end

  -- { saga, place }: the saga from the flags, else the owners' earliest era; the best place among the owners
  local function key_of(owners, id)
    local saga = flags[id]
    if saga == nil then
      saga = LAST
      for _, o in ipairs(owners or {}) do
        if o[2] < saga then
          saga = o[2]
        end
      end
    end
    local best = LAST
    if saga ~= LAST then
      for _, o in ipairs(owners or {}) do
        local p = place(o[1], saga)
        if p < best then
          best = p
        end
      end
    end
    return { saga, best }
  end
  local n_kits, n_emblems = 0, 0
  for _, r in ipairs(VRFW.table.rows("item/item_fashion")) do
    local id = u32(col(r, "id"))
    if id ~= 0 then
      kits[id] = key_of(by_uniform[u32(col(r, "uniform"))], id)
      n_kits = n_kits + 1
    end
  end
  for _, r in ipairs(VRFW.table.rows("item/item_emblem")) do
    local id = u32(col(r, "id"))
    if id ~= 0 then
      emblems[id] = key_of(by_emblem[id], id)
      n_emblems = n_emblems + 1
    end
  end
  ready = true
  VRFW.log(string.format("kit / emblem order: %d kits, %d emblems, %d sagas, %d teams", n_kits, n_emblems, #nums,
    #rows))
end

local ok, err = pcall(build)
if not ok then
  VRFW.warn("kit / emblem order off: " .. tostring(err))
end

-- after the game sorted the inventory tab: a tab of kits only or emblems only gets its rows by (saga, place, the
-- game's order)
local function on_sorted(ev)
  if not ready or ev.args[2] == SORT_ALPHABETICAL then
    return nil
  end
  local list = ev.args[1]
  if type(list) ~= "number" or list == 0 then
    return nil
  end
  local okn, n = pcall(VRFW.mem.read, "u32", list + LIST_COUNT)
  if not okn or n < 2 or n > MAX_ROWS then
    return nil
  end
  local rows = VRFW.mem.read_array("ptr", list + LIST_ROWS, n)
  if not rows then
    return nil
  end
  local items, all_kits, all_emblems = {}, true, true
  for i = 1, n do
    local oki, item = pcall(VRFW.mem.read, "u32", rows[i] + ROW_ITEM)
    item = oki and item or 0
    items[i] = item
    all_kits = all_kits and kits[item] ~= nil
    all_emblems = all_emblems and emblems[item] ~= nil
  end
  local map = (all_kits and kits) or (all_emblems and emblems) or nil
  if not map then
    return nil
  end
  local order = {}
  for i = 1, n do
    local k = map[items[i]]
    order[i] = { k[1], k[2], i }
  end
  table.sort(order, function(a, b)
    if a[1] ~= b[1] then
      return a[1] < b[1]
    end
    if a[2] ~= b[2] then
      return a[2] < b[2]
    end
    return a[3] < b[3]
  end)
  local out, moved = {}, false
  for i, o in ipairs(order) do
    out[i] = rows[o[3]]
    moved = moved or o[3] ~= i
  end
  if moved and not VRFW.mem.write_array("ptr", list + LIST_ROWS, out) then
    VRFW.warn(string.format("kit / emblem order: list 0x%X not writable", list))
  end
  return nil
end

VRFW.on("hook:BetterQoL.KitEmblemOrderInventory:post", on_sorted)
