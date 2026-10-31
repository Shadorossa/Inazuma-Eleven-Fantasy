-- Character Reforged › save adjust «Quitar equipaciones ocultas»: the team kits the active mods hide (an item
-- `[[hide]]` of their content\items\ whose target is a kit, ITEM_FASHION_INFO; this mod: content\items\
-- hidden_away_kits.toml) out of the save tree. The pass is the VR-Framework's (VRFW/lib/save_kits: the teams wearing
-- one go back to their home kit, the kit `<home key>_<n>` extends; its invFashion stacks are emptied). Same size,
-- idempotent.

local SaveKits = require "VRFW/lib/save_kits"

local PurgeKits = {}

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

-- The hidden kits: { by_item = { [item id] = kit }, count }, kit = { key, id, uniform, home = { key, id, uniform } | nil }
function PurgeKits.facts()
  local items = SaveKits.items()
  local facts = { by_item = {}, count = 0 }
  for _, target in ipairs(hidden_targets()) do
    local key = target
    local id = tonumber(target:match("^0[xX](%x+)$") or "", 16)
    if not items.by_key[key] and id and items.by_id[id] then key = items.by_id[id].key end
    local entry = SaveKits.entry(items, key)
    if entry and not facts.by_item[entry.id] then
      facts.by_item[entry.id] = entry
      facts.count = facts.count + 1
    end
  end
  return facts
end

function PurgeKits.run(tree, facts)
  return SaveKits.remove(tree, facts.by_item)
end

PurgeKits.summary = SaveKits.summary

return PurgeKits
