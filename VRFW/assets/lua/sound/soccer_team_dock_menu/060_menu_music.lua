-- audio_engine (VR-Framework): this menu starts the menu BGM (CMND_EXEC_CRAFT_OBJ_ID bg10000 in its Lua): the
-- «Música del menú» swap watches it (lua/_all/60_menu_music.lua, docs/framework/menu-music.md). Load: registration only.
if VRFW_MenuMusic ~= nil then
  VRFW_MenuMusic.Watch()
end
