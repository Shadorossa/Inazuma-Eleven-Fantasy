-- model_wait_guard (VR-Framework retail bug fix; lua\_all\08_model_wait_guard.lua, docs/framework/model-wait-guard.md):
-- the Chronicle warp menu waits for its caravan model (layer 117665605) in OnWaitCaravanModelLoad with no end, the
-- same pattern as chronicle_mode_top_menu. Capped at 300 frames (no skip argument: the «complete» read is answered
-- for the rest of the retail function). No engine call at load time.
if VRFW_ModelWaitGuard ~= nil then
  VRFW_ModelWaitGuard("OnWaitCaravanModelLoad", { layer = 117665605, idx = 0, max = 300 })
end
