-- All Miximaxed › the MIXIMAX creation scene, event_menu part (graft all_miximaxed_scene): while the scene «Crear
-- miximax» prepared is pending (CMND_EVT_MX_SCENE_STATE, answered by All Miximaxed's scripts\miximax.lua), A skips it
-- the way the retail hold-to-skip button ends an event (CMND_EVENT_SKIP). Every other event keeps the retail button.
-- HOOK file (shipped as is). Inazuma Fantasy's own copy (EVT_MXS_PrevStep) wins when it is in this menu. No engine
-- call at chunk load.
do
  AllMiximaxed_SceneSkip = AllMiximaxed_SceneSkip or {}
  local Skip = AllMiximaxed_SceneSkip
  Skip.STATE = 2736813206                            -- CMND_EVT_MX_SCENE_STATE () -> pending, base, seconds
  Skip.LOG = 3661580131                              -- CMND_EVT_LOG
  Skip.INPUT = 4265778440                            -- CMND_CHECK_INPUT_CMD (group, command)
  Skip.GROUPS = {2917185202 --[[EVENT_CTRL_VISUAL]], 3237690481 --[[EVENT_CTRL_TALK]]}
  Skip.KEYS = {1981080283 --[[CMD_ENTER]], 2598206728 --[[CMD_EVENT_SKIP_HOLD]]}
  Skip.EVENT_SKIP = 2872569508                       -- CMND_EVENT_SKIP
  Skip.done = false

  function Skip.Pressed()
    for _, group in ipairs(Skip.GROUPS) do
      for _, key in ipairs(Skip.KEYS) do
        local ok, v = pcall(funcLuaCommand, Skip.INPUT, group, key)
        if ok and v == true then
          return true
        end
      end
    end
    return false
  end

  if rawget(_ENV, "EVT_MXS_PrevStep") == nil and Skip.PreviousStep == nil and type(Step) == "function" then
    Skip.PreviousStep = Step
    function Step(...)
      if not Skip.done and type(funcLuaCommand) == "function" then
        local ok, pending = pcall(funcLuaCommand, Skip.STATE)
        if ok and pending == true and Skip.Pressed() then
          Skip.done = true
          local okSkip, r = pcall(funcLuaMenuCommand, Skip.EVENT_SKIP)
          pcall(funcLuaCommand, Skip.LOG, "all_miximaxed scene", "A pressed: skip", tostring(okSkip), tostring(r))
        end
      end
      return Skip.PreviousStep(...)
    end
  end
end
