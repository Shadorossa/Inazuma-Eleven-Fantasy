-- VRFW story_provider: the VR-Framework answers its own mode engine's `story_cleared` clause of [mode.unlock]
-- (research/mods/VRFW/assets/lua/mode/_all/00_mode_engine.lua, EvtMode.story_cleared). The 3rd value of
-- CMND_VRFW_STORY_START_GET (the VR-Framework save part's story-complete start) = the saved story is cleared. nil =
-- cannot tell (no slot service): the clause is not checked, as the mode engine did when it asked the command itself.
-- Only a definition: nothing runs at chunk load.
function VRFW_STORY_PROVIDER()
  local ok, _, _, cleared = pcall(funcLuaCommand, 1176769167 --[[CMND_VRFW_STORY_START_GET]])
  if not ok or cleared == nil then
    return nil
  end
  return cleared == true or cleared == 1
end
