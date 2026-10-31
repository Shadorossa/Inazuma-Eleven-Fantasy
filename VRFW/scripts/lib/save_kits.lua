-- Team kit items in a save: the kit list the game loads and a pass that takes chosen kit items out of a save tree.
--   local SaveKits = require "VRFW/lib/save_kits"
--   SaveKits.items()                -> { by_key = { [key] = kit }, by_id = { [item id] = kit } }, kit = { key, id, uniform }
--   SaveKits.home_of(items, key)    -> the kit whose key `key` extends (`<home key>_<n>`, the game's naming of the copies
--                                      of a kit), nil when there is none
--   SaveKits.entry(items, key)      -> { key, id, uniform, home = kit | nil } of kit `key` (nil when no such kit)
--   SaveKits.remove(tree, by_item)  -> report { teams, stacks, removed, bytes_patched, lines }
--   SaveKits.summary(report)        -> one line
--
-- remove: `by_item[item id] = entry` names the kit items to take out. A team (block 7, every team set) wearing one
-- (uniformInvHdl = its stack) goes back to the entry's home kit (uniformId = the home kit's uniform, uniformInvHdl =
-- the save's stack of it, 0 when not owned; without a home kit the uniform stays and only the item goes); then the
-- items' invFashion stacks are emptied. Same size, idempotent. The caller's framework writes the tree.

local T = require "VRFW/lib/save_tree"
local Id = require "VRFW/lib/ids"

local u32, hex = Id.u32, Id.hex

local SaveKits = {}

local BLOCK_INVENTORY, BLOCK_TEAMS = 4, 7

function SaveKits.items()
  local out = { by_key = {}, by_id = {} }
  local ok, rows = pcall(VRFW.table.rows, "item/item_fashion")
  if not ok or type(rows) ~= "table" then error("item/item_fashion unreadable: " .. tostring(rows)) end
  for _, row in ipairs(rows) do
    local key, id = row.key, u32(row.id or 0)
    if type(key) == "string" and key ~= "" and id ~= 0 and out.by_key[key] == nil then
      local kit = { key = key, id = id, uniform = u32(row.uniform or 0) }
      out.by_key[key] = kit
      if out.by_id[id] == nil then out.by_id[id] = kit end
    end
  end
  return out
end

function SaveKits.home_of(items, key)
  local home_key = type(key) == "string" and key:match("^(.+)_%d+$") or nil
  if not home_key or home_key == key then return nil end
  return items.by_key[home_key]
end

function SaveKits.entry(items, key)
  local kit = items.by_key[key]
  if not kit then return nil end
  return { key = kit.key, id = kit.id, uniform = kit.uniform, home = SaveKits.home_of(items, key) }
end

-- every team of block 7 (every team set, every team)
local function teams(tree)
  local out = {}
  local permanent = T.unwrap(tree, "block7", "m_InfoPermanent")
  local sets, set_count = T.arr(tree, T.kids(tree, permanent, "teamSetList"), "m_buffer")
  for s = 0, (set_count or 0) - 1 do
    local team_list, team_count = T.arr(tree, T.at(sets, s), "teamInfoList")
    for k = 0, (team_count or 0) - 1 do out[#out + 1] = { path = T.at(team_list, k), label = s .. "/" .. k } end
  end
  return out
end

function SaveKits.remove(tree, by_item)
  for _, id in ipairs({ BLOCK_INVENTORY, BLOCK_TEAMS }) do
    if not T.has_block(tree, id) then error("block " .. id .. " not found") end
  end
  local P = T.patches(tree)
  local report = { teams = 0, stacks = 0, removed = 0, bytes_patched = 0, lines = {} }

  local inventory = T.unwrap(tree, "block4", "m_Permanent")
  local stacks, stack_count = T.arr(tree, inventory, "invFashion")
  if not stacks then error("invFashion not found in block 4") end
  local item_of, owned, removed = {}, {}, {}
  for i = 0, stack_count - 1 do
    local stack = T.at(stacks, i)
    local handle, item = T.num(tree, stack, "handle"), T.num(tree, stack, "item_id")
    if handle and handle ~= 0 and item then
      item_of[handle] = item
      if owned[item] == nil then owned[item] = handle end
      if by_item[item] then removed[#removed + 1] = { stack, item } end
    end
  end

  for _, team in ipairs(teams(tree)) do
    local handle, uniform = T.num(tree, team.path, "uniformInvHdl"), T.num(tree, team.path, "uniformId")
    local kit = handle and handle ~= 0 and by_item[item_of[handle] or 0] or nil
    if kit then
      local home = kit.home
      local new_handle = home and owned[home.id] or 0
      local new_uniform = home and home.uniform ~= 0 and home.uniform or uniform
      if new_handle ~= handle then P:set(team.path .. ".uniformInvHdl", handle, new_handle) end
      if uniform and new_uniform ~= uniform then P:set(team.path .. ".uniformId", uniform, new_uniform) end
      report.teams = report.teams + 1
      report.lines[#report.lines + 1] = string.format("team %s: %s -> %s (item stack %s)", team.label, kit.key,
        home and home.key or "its uniform, no item", hex(new_handle or 0))
    end
  end

  for _, entry in ipairs(removed) do
    P:zero(entry[1])
    report.stacks = report.stacks + 1
    report.lines[#report.lines + 1] = string.format("invFashion %s: stack of %s emptied", entry[1], by_item[entry[2]].key)
  end

  report.removed = report.teams + report.stacks
  report.bytes_patched = P:apply()
  return report
end

function SaveKits.summary(report)
  return string.format("%d teams back to their home kit, %d invFashion stacks emptied; %d bytes patched", report.teams, report.stacks, report.bytes_patched)
end

return SaveKits
