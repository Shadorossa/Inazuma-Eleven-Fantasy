-- BetterMenu (mod better_menu, prefix BetterMenu): the menu 3D model component (menu_chara_model_comp) of the team
-- roster's sub-screens while the roster is open over the clubhouse (docs/game/mods/better-menu.md §36, §38).
-- A menu model sets up its own stage: a light object (SetupLightObj: «Menu_2dLight…objMenuCharaModelLight»), its light
-- data made the active light set (ApplyResourceInfo: CMND_REGIST_LIGHT_DATA 3423152028, then 1126883260(light, true,
-- 2)) and its camera (RegistCameraInfo -> 3496771025(camera, attach)). Over the clubhouse the menu light set relights
-- the room (brighter, warmer) and the camera looks at it from outside. While param better_menu_team_over_scene is set
-- (the main menu's team drawer opened the roster): the light data is not registered nor made active (the room keeps
-- the field's light), and the camera is registered without being attached. The model itself remains enabled so its
-- render-texture capture can be shown by the roster's CharacterReforged pages. A capture component (its light object
-- is a «…_Capture» one: it draws its model into a render texture with its own camera, not into the 3D view) keeps the
-- game's light data and camera: without its light data the capture cell stays empty. Each step logs once per component.
-- Opened any other way nothing changes. Wraps the component's globals
-- (no host); nothing runs at load time.
do
  local OVER_SCENE = 3752859857       -- crc32("better_menu_team_over_scene")
  local PARAM_HAS = 2947612279
  local REGIST_CAMERA = 3496771025    -- (camera crc, attach to the 3D view)
  local DEFAULT_CAMERA = 2522865953   -- RegistCameraInfo's own default
  local NO_LIGHT = 65535              -- ApplyResourceInfo's «no light» answer
  local LOG = 3661580131              -- crc32("CMND_EVT_LOG")
  local CAPTURE_LIGHT_SUFFIX = "_Capture" -- the light object of a component that draws into a render texture
  local logged = {}
  local capture = false               -- this component's light object is a capture one (set by SetupLightObj)

  local function OverScene()
    local ok, on = pcall(funcLuaCommand, PARAM_HAS, OVER_SCENE)
    return ok and on == true
  end

  local function LogOnce(step, ...)
    if logged[step] then return end
    logged[step] = true
    pcall(funcLuaCommand, LOG, "better_menu", "team_drawer", "model component:", step, ...)
  end

  local setup_light = SetupLightObj
  if type(setup_light) == "function" then
    function SetupLightObj(a1, a2, ...)
      local name = tostring(a1 or "")
      capture = name:sub(-#CAPTURE_LIGHT_SUFFIX) == CAPTURE_LIGHT_SUFFIX
      if OverScene() then LogOnce("light object", name, tostring(a2), capture and "capture: the game's light and camera kept" or "") end
      return setup_light(a1, a2, ...)
    end
  end

  local apply = ApplyResourceInfo
  if type(apply) == "function" then
    function ApplyResourceInfo(a1, a2, ...)
      if capture or not OverScene() then return apply(a1, a2, ...) end
      LogOnce("light set not applied (the room keeps its light)", "camera", tostring(a1), "attach", tostring(a2))
      return NO_LIGHT
    end
  end

  local regist = RegistCameraInfo
  if type(regist) == "function" then
    function RegistCameraInfo(a1, ...)
      if capture or not OverScene() then return regist(a1, ...) end
      if a1 == 0 or a1 == nil then a1 = DEFAULT_CAMERA end
      pcall(funcLuaCommand, REGIST_CAMERA, a1, false)
      LogOnce("camera not attached (the scene's camera stays)")
    end
  end

  local setup = Setup
  if type(setup) == "function" then
    function Setup(...)
      if OverScene() then LogOnce("setup", ...) end
      return setup(...)
    end
  end

  local change = ChangeCharaModel
  if type(change) == "function" then
    function ChangeCharaModel(...)
      if OverScene() then LogOnce("model left visible for CharacterReforged capture") end
      return change(...)
    end
  end

  local step = Step
  if type(step) == "function" then
    function Step(...)
      return step(...)
    end
  end
end
