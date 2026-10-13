-- bb_chronicle_teams bb_net_room, Battle Bay top menu: the «Multijugador» row opens the «Sala privada» (BBN_Entry of
-- bbn_common.lua, appended before this block) while gameplay mods are enabled; otherwise the retail row.
-- ------------------------------------------------------------------------------------------------ wraps

do
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if a1 == BBN.LIST_MID or a1 == BBN.LIST_SMALL then
      local okl, info = pcall(GetLitItemInfo, a1, a2)
      if okl and info ~= nil and info.menuObjectName == BBN.ROW then
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
