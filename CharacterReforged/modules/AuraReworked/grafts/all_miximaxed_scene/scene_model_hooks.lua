-- All Miximaxed › the MIXIMAX creation scene, one-model view part (graft all_miximaxed_scene): the partner's 3D model,
-- held by this retail menu while the scene plays (the skill table's own model holds the base). The skill table opens
-- this menu, then calls (funcLuaCommand(830228314, chara_model_only_view_menu, name, ...)):
--   EVT_MxSceneModelBegin()                 the model layer hidden, the «ready» parameter cleared
--   EVT_MxSceneModelCmd(cmd, ...)           one model command of its SetupCharaModel, on this menu's layer
--   EVT_MxSceneModelWatch()                 Step sets «ready» (crc32 "evt_mx_scene_model_ready" = 1) once loaded
-- and closes the menu after the scene. Nothing is drawn: the layer stays hidden. HOOK file (shipped as is); Inazuma
-- Fantasy's own copy wins when it is in this menu. No engine call at chunk load.
if rawget(_ENV, "EVT_MxSceneModelBegin") == nil then
  AllMiximaxed_SceneModel = {
    LAYER = 2255041871,                              -- rpg99_99_chara_model_only_view
    READY = 2277088171,                              -- evt_mx_scene_model_ready
    LOADED = 1583438030,                             -- (layer, inst, slot) -> the model is loaded
    watch = 0,
  }

  function EVT_MxSceneModelBegin()
    local Model = AllMiximaxed_SceneModel
    pcall(funcLuaCommand, 3363400568 --[[parameter delete]], Model.READY)
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], Model.LAYER, 0, false)
    Model.watch = 0
    return true
  end

  function EVT_MxSceneModelCmd(cmd, ...)
    local Model = AllMiximaxed_SceneModel
    local ok = pcall(funcLuaMenuCommand, cmd, Model.LAYER, 0, ...)
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], Model.LAYER, 0, false)
    return ok
  end

  function EVT_MxSceneModelWatch()
    AllMiximaxed_SceneModel.watch = 1
    return true
  end

  AllMiximaxed_SceneModel.PreviousStep = Step
  function Step(...)
    local Model = AllMiximaxed_SceneModel
    local r
    if Model.PreviousStep ~= nil then
      r = Model.PreviousStep(...)
    end
    if Model.watch ~= 0 then
      Model.watch = Model.watch + 1
      local ok, ready = pcall(funcLuaMenuCommand, Model.LOADED, Model.LAYER, 0, 0)
      if (ok and ready == true and Model.watch > 3) or Model.watch > 600 then
        pcall(funcLuaCommand, 3860611758 --[[parameter set]], Model.READY, 0, (ok and ready == true) and 1 or 2, 1)
        Model.watch = 0
      end
    end
    return r
  end
end
