-- UTIL camera_side match
-- In-match side camera of the mod Utilities (docs/game/media/camaras-fifa.md §7). Since 2026-10-08 Utilities has no
-- camera code: the camera is the VR-Framework's match camera service (docs/framework/camera.md) and Utilities is data.
-- At match start (HUD OnInit) this block reads the row «Cámara del partido» (CMND_VRFW_OPTION_GET utilities.camera)
-- and, when it is «Lateral» (1), requests Utilities' preset utilities.side (research/mods/Utilities/cameras/side.toml)
-- from the framework (CMND_VRFW_CAMERA_REQUEST): the framework writes the preset into the in-play camera rows of the
-- loaded table (memory), forces the retail camera option to "H" / "H" and rebuilds the camera when the soccer camera
-- manager exists. «Original» (0) releases the request (CMND_VRFW_CAMERA_RELEASE: retail rows and the player's camera
-- option back). The manager is often still null at the HUD's OnInit, so Step repeats CMND_VRFW_CAMERA_APPLY (once per
-- 30 frames, at most 60 times) until it exists. The rows stay written either way: the chase camera reads them
-- whenever it builds its view (kick-off, possession changes). Online / observer: never.
UTIL_CS_OPTION = "utilities.camera"      -- the option row (options.toml)
UTIL_CS_OWNER = "utilities"              -- the request's owner
UTIL_CS_PRESET = "utilities.side"        -- the framework preset (cameras/side.toml)
UTIL_CS_PRIORITY = 0                     -- a mod that must win over «Lateral» requests a higher priority
utilCsDone = true                        -- nothing to do (this lua_State only)
utilCsTries = 0
utilCsTick = 0
function UTIL_CamSideCall(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end
function UTIL_CamSideLog(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], ...)
end
function UTIL_CamSideDone()
  utilCsDone = true
  local body = UTIL_CamSideCall(151747897 --[[CMND_GET_SOCCER_CAMERA_TYPE_INFO]], 0)
  local off = UTIL_CamSideCall(151747897 --[[CMND_GET_SOCCER_CAMERA_TYPE_INFO]], 1)
  UTIL_CamSideLog("UTIL camera: side camera applied", "body V", tostring(body), "offence V", tostring(off),
    "tries", utilCsTries)
end
function UTIL_CamSideInit()
  utilCsDone = true
  if funcLuaCommand(3959907440) == true or funcLuaCommand(1191545622) == true then
    return
  end
  local v = UTIL_CamSideCall(4082322029 --[[CMND_VRFW_OPTION_GET]], UTIL_CS_OPTION)
  if v ~= 1 then
    local code, mgr = UTIL_CamSideCall(3670384878 --[[CMND_VRFW_CAMERA_RELEASE]], UTIL_CS_OWNER)
    if code == 0 then
      UTIL_CamSideLog("UTIL camera: match start, Original: side camera released", "manager", tostring(mgr))
    end
    return
  end
  local code, mgr = UTIL_CamSideCall(2132094060 --[[CMND_VRFW_CAMERA_REQUEST]], UTIL_CS_OWNER, UTIL_CS_PRESET,
    UTIL_CS_PRIORITY)
  UTIL_CamSideLog("UTIL camera: match start, Lateral: request", UTIL_CS_PRESET, "code", tostring(code), "manager",
    tostring(mgr))
  if code ~= 0 then
    return
  end
  utilCsTries = 0
  utilCsTick = 0
  if mgr == true then
    UTIL_CamSideDone()
    return
  end
  utilCsDone = false
end
function UTIL_CamSideTry()
  local mgr = UTIL_CamSideCall(3766293743 --[[CMND_VRFW_CAMERA_APPLY]])
  utilCsTries = utilCsTries + 1
  if mgr == true then
    UTIL_CamSideDone()
  elseif utilCsTries >= 60 then
    utilCsDone = true
    UTIL_CamSideLog("UTIL camera: no soccer camera manager after", utilCsTries, "tries (the rows stay written)")
  end
end
function UTIL_CamSideTick()
  if utilCsDone then
    return
  end
  utilCsTick = utilCsTick + 1
  if utilCsTick >= 30 then
    utilCsTick = 0
    UTIL_CamSideTry()
  end
end
-- the retail OnInit / Step, then the camera (one wrapper each; the retail return values pass through)
local UTIL_CamSide_OnInit_prev = OnInit
function OnInit(...)
  local r = table.pack(UTIL_CamSide_OnInit_prev(...))
  UTIL_CamSideInit()
  return table.unpack(r, 1, r.n)
end
local UTIL_CamSide_Step_prev = Step
function Step(...)
  local r = table.pack(UTIL_CamSide_Step_prev(...))
  UTIL_CamSideTick()
  return table.unpack(r, 1, r.n)
end
