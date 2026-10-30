-- BattleBayDeluxe bb_net_room, Battle Bay top menu: the «Multijugador» row opens the «Sala privada» (BBN_Entry of
-- bbn_common.lua, appended before this block) while gameplay mods are enabled; otherwise the retail row.
-- The first Step of the menu gives the Campaña's block back when a room match borrowed it (CMND_BBD_NET_RESTORE: a
-- no-op when none is kept).
-- ------------------------------------------------------------------------------------------------ wraps
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

do
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if a1 == BattleBayDeluxe.NetRoom.LIST_MID or a1 == BattleBayDeluxe.NetRoom.LIST_SMALL then
      local okl, info = pcall(GetLitItemInfo, a1, a2)
      if okl and info ~= nil and info.menuObjectName == BattleBayDeluxe.NetRoom.ROW then
        BBN_LAYER = a1 -- the row's list layer (the retail WaitExecOtherMenu's second argument)
        local ok, handled = pcall(BBN_Entry)
        if not ok then
          BBN_Log("entry error", tostring(handled))
          return 1
        end
        if handled then
          return 1
        end
      end
    end
    return decide(a1, a2, ...)
  end
end

do
  local step = Step
  function Step(...)
    if not BBN_RESTORED then
      BBN_RESTORED = true
      pcall(funcLuaCommand, BattleBayDeluxe.NetRoom.RESTORE)
    end
    return step(...)
  end
end
