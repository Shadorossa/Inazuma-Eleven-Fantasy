-- personal_plate_menu (the player plate beside the formation screen / dock) in «Tipo: Pachanga»
-- (docs/game/ui/pachanga-templates.md §3.4). The plate VM finds the player of a focused card through its own copy of
-- soccer_formation_menu_inc (position -> member of team (dock, n31)); it reads the team kind (param 2419482555) only in
-- its OnInit, and the dock builds it once (usually in Partido), so after the in-place switch it kept looking in the
-- 11v11 team: focused 5v5 card != plate player (Nacho 2026-09-28, dock 01). The dock calls this function on the
-- plate VM (funcLuaCommand 830228314 = call a global of another menu) whenever the dock's type / dock changes and
-- before the formation screen opens, so the plate's INCLUDE uses the same team as the cards.
function EVT_PT_PlateKind(kind, dock)
  if type(OnInitFormationCommon) ~= "function" or type(dock) ~= "number" then
    return false
  end
  local ok, got, fid = pcall(funcLuaCommand, @crc:CMND_GET_TEAM_SET_INFO@, dock, kind == 1 and 1 or 0, 4)
  local f = (ok and got) and fid or nil
  local r
  if kind == 1 then
    r = table.pack(pcall(OnInitFormationCommon, f, nil, dock, nil, nil, nil, true))
  else
    r = table.pack(pcall(OnInitFormationCommon, f, nil, dock, nil, nil, nil, false))
    -- OnInitFormationCommon(..., false) does not put back the starters count / field height of the 11v11 mode
    if type(UpdateFormationReducedDrawingIconPos) == "function" then
      pcall(funcLuaCommand, @crc:CMND_EVT_PACHANGA_UPVAL@, UpdateFormationReducedDrawingIconPos, 5, 11, 40, 94)
    end
  end
  pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT pachanga plate", "team kind", kind, "dock", dock,
    tostring(r[1]), tostring(r[2]))
  return r[1]
end
