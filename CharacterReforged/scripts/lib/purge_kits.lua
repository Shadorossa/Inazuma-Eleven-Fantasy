-- Character Reforged › save adjust «Quitar equipaciones ocultas»: the team kits the active mods hide (an item
-- `[[hide]]` of their content\items\ whose target is a kit, ITEM_FASHION_INFO; this mod: content\items\
-- hidden_away_kits.toml) out of the save tree.
--
--   * a team (block 7, every team set) wearing one (uniformInvHdl = its stack): back to its home kit, the kit item the hidden one's key extends (`<home key>_<n>`, the game's own naming of its away
--     copies): uniformId = the home kit's uniform, uniformInvHdl = the player's stack of it (0 = not owned; the game
--     keeps a team with a uniform and no item). Without a home kit the uniform stays and only the item goes.
--   * its invFashion stacks are emptied (no team refers to them any more).
-- Same size, idempotent.

local T = require "lib/duplicate_players/save_tree"

local PurgeKits = {}

local band = bit32.band

local ITEM_CONFIG = "data/common/gamedata/item/item_config_*.cfg.bin"
local KIT_LIST = "ITEM_FASHION_INFO"
-- item_config columns (1-based: the 0-based column + 1): item id, key, uniform
local COLUMN_ID, COLUMN_KEY, COLUMN_UNIFORM = 1, 12, 19
local BLOCK_INVENTORY, BLOCK_TEAMS = 4, 7

local function u32(v)
  if type(v) ~= "number" then return 0 end
  return band(v, 0xFFFFFFFF)
end

local function hex(v) return string.format("0x%08X", v) end

-- the kit items: key -> { id, uniform }
local function read_kits()
  local kits = {}
  local ok, rows = pcall(VRFW.table.raw, ITEM_CONFIG, KIT_LIST, { COLUMN_ID, COLUMN_KEY, COLUMN_UNIFORM })
  if not ok or type(rows) ~= "table" then error("item_config: " .. KIT_LIST .. " unreadable: " .. tostring(rows)) end
  for _, row in ipairs(rows) do
    local key = row[COLUMN_KEY]
    if type(key) == "string" and key ~= "" and kits[key] == nil then
      kits[key] = { id = u32(row[COLUMN_ID]), uniform = u32(row[COLUMN_UNIFORM]) }
    end
  end
  return kits
end

-- the [[hide]] targets of every active mod's items files (load order)
local function hidden_targets()
  local out = {}
  local ok, declarations = pcall(VRFW.files.declarations, "content/items")
  for _, file in ipairs(ok and type(declarations) == "table" and declarations or {}) do
    local data = type(file) == "table" and file.data or nil
    for _, entry in ipairs(type(data) == "table" and type(data.hide) == "table" and data.hide or {}) do
      if type(entry) == "table" and type(entry.target) == "string" then out[#out + 1] = entry.target end
    end
  end
  return out
end

-- The hidden kits: { by_item = { [item id] = kit }, count }, kit = { key, id,
-- uniform, home = { key, id, uniform } | nil }
function PurgeKits.facts()
  local kits = read_kits()
  local facts = { by_item = {}, count = 0 }
  for _, target in ipairs(hidden_targets()) do
    local kit = kits[target]
    local id = tonumber(target:match("^0[xX](%x+)$") or "", 16)
    if not kit and id then
      for key, k in pairs(kits) do
        if k.id == id then kit, target = k, key end
      end
    end
    if kit and not facts.by_item[kit.id] then
      local home_key = target:match("^(.+)_%d+$")
      local home = home_key and kits[home_key] or nil
      local entry = { key = target, id = kit.id, uniform = kit.uniform, home = home and { key = home_key, id = home.id, uniform = home.uniform } or nil }
      facts.by_item[kit.id] = entry
      facts.count = facts.count + 1
    end
  end
  return facts
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

-- The pass on `tree` with `facts` (PurgeKits.facts()). Returns the report: teams, stacks, removed (teams + stacks),
-- bytes_patched, lines.
function PurgeKits.run(tree, facts)
  for _, id in ipairs({ BLOCK_INVENTORY, BLOCK_TEAMS }) do
    if not T.has_block(tree, id) then error("block " .. id .. " not found") end
  end
  local P = T.patches(tree)
  local report = { teams = 0, stacks = 0, removed = 0, bytes_patched = 0, lines = {} }

  local inventory = T.unwrap(tree, "block4", "m_Permanent")
  local stacks, stack_count = T.arr(tree, inventory, "invFashion")
  if not stacks then error("invFashion not found in block 4") end
  local item_of, owned, purged = {}, {}, {}
  for i = 0, stack_count - 1 do
    local stack = T.at(stacks, i)
    local handle, item = T.num(tree, stack, "handle"), T.num(tree, stack, "item_id")
    if handle and handle ~= 0 and item then
      item_of[handle] = item
      if owned[item] == nil then owned[item] = handle end
      if facts.by_item[item] then purged[#purged + 1] = { stack, item } end
    end
  end

  for _, team in ipairs(teams(tree)) do
    local handle, uniform = T.num(tree, team.path, "uniformInvHdl"), T.num(tree, team.path, "uniformId")
    local kit = handle and handle ~= 0 and facts.by_item[item_of[handle] or 0] or nil
    if kit then
      local new_handle = kit.home and owned[kit.home.id] or 0
      local new_uniform = kit.home and kit.home.uniform ~= 0 and kit.home.uniform or uniform
      if new_handle ~= handle then P:set(team.path .. ".uniformInvHdl", handle, new_handle) end
      if uniform and new_uniform ~= uniform then P:set(team.path .. ".uniformId", uniform, new_uniform) end
      report.teams = report.teams + 1
      report.lines[#report.lines + 1] = string.format("team %s: %s -> %s (item stack %s)", team.label, kit.key,
        kit.home and kit.home.key or "its uniform, no item", hex(new_handle or 0))
    end
  end

  for _, entry in ipairs(purged) do
    P:zero(entry[1])
    report.stacks = report.stacks + 1
    report.lines[#report.lines + 1] = string.format("invFashion %s: stack of %s emptied", entry[1], facts.by_item[entry[2]].key)
  end

  report.removed = report.teams + report.stacks
  report.bytes_patched = P:apply()
  return report
end

function PurgeKits.summary(report)
  return string.format("%d teams back to their home kit, %d invFashion stacks emptied; %d bytes patched", report.teams, report.stacks, report.bytes_patched)
end

return PurgeKits
