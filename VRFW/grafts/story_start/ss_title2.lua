-- VR-Framework story_start, title_menu_2 side. ss_title_apply.lua (in title_menu_inc) hangs VRFW_STS_OnTitle on OnInit
-- through a __newindex on _G, but title_menu_2 ships as lua_patches whose OnInit is defined again after the chunk:
-- __newindex never fires for an existing global, so that wrapper is dropped there. A handler of the
-- framework's title_menu_2 host runs the apply instead: `before` OnInit with priority
-- -900, right after the slot service's COMMIT (-1000) and before every other handler and the menu's own OnInit.
-- VRFW_STS_OnTitle runs once per VM (VRFW_STS_ran). Nothing runs at chunk load.
if VRFW_Host ~= nil then
  VRFW_Host.on("title_menu_2", "OnInit", {
    id = "save_engine.story_start",
    phase = "before",
    priority = -900,
    fn = function()
      if type(VRFW_STS_OnTitle) == "function" then
        VRFW_STS_OnTitle()
      end
    end,
  })
else
  -- no VRFW_Host (a framework without the menu part's Lua): the old wrapper, COMMIT -> apply -> the menu's OnInit
  local init = OnInit
  function OnInit(...)
    if type(VRFW_SS_CommitPending) == "function" then
      pcall(VRFW_SS_CommitPending)
    end
    if type(VRFW_STS_OnTitle) == "function" then
      pcall(VRFW_STS_OnTitle)
    end
    return init(...)
  end
end
