-- Equipment of a player, for the game's Lua (docs/framework/types/item.md §15). The read itself is native
-- (VRFW.item.equipped: GetEquipInvHdl + InvRecord, the read of the item transformations); the sets are the item
-- type's [[VRFW.EquipmentSet]] (VRFW.item.set_pieces).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_EQUIPPED_ITEMS | (charaHdl) | boots, bracelet, pendant, special item ids (0 = empty); nothing for a player who is not the user's |
-- | CMND_VRFW_EQUIPMENT_SET_PIECES | (charaHdl, setName) | how many equip slots count for the set (a piece counts for one set only); -1 = unknown set or not the user's player |

Equipment = Equipment or {}

function Equipment.Items(hdl)
  local ok, a, b, c, d = pcall(VRFW.item.equipped, tonumber(hdl) or 0)
  if not ok or a == nil then return end
  return a, b, c, d
end

function Equipment.SetPieces(hdl, name)
  if type(name) ~= "string" then return -1 end
  local ok, n = pcall(VRFW.item.set_pieces, tonumber(hdl) or 0, name)
  if not ok or n == nil then return -1 end
  return n
end
