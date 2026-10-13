-- model_wait_guard (VR-Framework retail bug fix; lua\_all\08_model_wait_guard.lua, docs/framework/model-wait-guard.md):
-- Modo Crónica's top menu waits for its caravan model (layer 117665605) in WaitCaravanModelLoad(wait) after every
-- menu it opened (WaitExecOtherMenu) and at its open; the retail loop has no end. Capped at 300 frames, then the
-- retail goes on with wait = false (its own «no wait» path). No engine call at load time.
if VRFW_ModelWaitGuard ~= nil then
  VRFW_ModelWaitGuard("WaitCaravanModelLoad", { layer = 117665605, idx = 0, max = 300, first_yield = true, skip = false })
end
