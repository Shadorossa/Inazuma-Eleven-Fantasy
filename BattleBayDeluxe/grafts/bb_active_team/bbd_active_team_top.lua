-- BattleBayDeluxe bb_active_team, the Battle Bay's hub menus (bb_stadium_top_menu, soccer_top_menu; docs/game/modes/
-- estadio-bb.md §16.4). 1.5.64: each time the hub opens (entering the Battle Bay, back from a match or a result) the
-- active team is mirrored onto the «Active team» tile (bbd_active_team_common.lua), so a Campaña / Torneo continued
-- with the tile (no team grid on the way) has the active team's players and its captain as the row's leader for the
-- campaign scene and its pre-match talk. Globals only; nothing runs at chunk load.
do
  local init = OnInit
  function OnInit(...)
    local r = table.pack(init(...))
    local ok, err = pcall(BBD_ACTIVE_TEAM_Sync, "hub opened")
    if not ok then
      BBD_ACTIVE_TEAM_Log("hub sync error", tostring(err))
    end
    return table.unpack(r, 1, r.n)
  end
end
