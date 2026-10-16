-- The Chronicle hub map's trigger script (w90i001_map_trigger, retail rows 1-4 kept) of New Recruitment: the second map
-- point, retail RunPlayersUniverseMenu (the gacha «Universo del jugador»), does nothing while the mod's rules apply
-- (every save but a reserved slot: the same rule as NewRecruitment.Applies); the other three are the retail ones.
local SLOT_ACTIVE = 4245285902       -- CMND_VRFW_SLOT_ACTIVE -> the loaded save's slot (0 = none)
local SLOT_RESERVED = 1380583127     -- CMND_VRFW_SLOT_RESERVED (slot) -> reserved, owner mod, enterable

local function rules_apply()
  if type(NewRecruitment) == "table" and type(NewRecruitment.Applies) == "function" then
    return (select(2, pcall(NewRecruitment.Applies))) == true
  end
  local okActive, active = pcall(funcLuaCommand, SLOT_ACTIVE)
  if not okActive or type(active) ~= "number" or active <= 0 then
    return true
  end
  local okReserved, reserved = pcall(funcLuaCommand, SLOT_RESERVED, active)
  return not (okReserved and reserved == true)
end

function RunCmd_Map1()
  RunVsRouteTownMenu()
end
function RunCmd_Map2()
  if rules_apply() then
    return
  end
  RunPlayersUniverseMenu()
end
function RunCmd_Map3()
  funcLuaCommand(3625806653, 3549406257, 0, 0, 1)
end
function RunCmd_Map4()
  funcLuaCommand(3625806653, 1907350810, 0, 0, 1)
end
