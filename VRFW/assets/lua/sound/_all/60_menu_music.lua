-- audio_engine (VR-Framework, sound type): the menu music swap, VRFW_MenuMusic (docs/framework/menu-music.md).
-- Definitions only (this file runs in every script VM, lua\_all); no engine call happens while a chunk loads.
--
-- The framework's row «Música del menú» (audio_engine.menu_music, options.toml of this part) offers «Original» and
-- every theme the enabled mods declare ([[VRFW.MenuMusic]] of their sound files). Menus start their music with
-- funcLuaCommand(CMND_EXEC_CRAFT_OBJ_ID, <BGM id>); in a WATCHED menu script the framework asks
-- CMND_VRFW_SOUND_MENU_MUSIC(<BGM id>) before each such call: a menu BGM id (the slots of defaults\audio.toml flagged
-- menu_music: bg10000 in v7.1.2) while a theme is picked answers that theme's BGM id, which is played instead;
-- anything else answers false and the call goes on untouched. The row is read live, so a change applies at the next
-- menu BGM start.
--
--   VRFW_MenuMusic.Watch()   -- from a patch file of a menu script's folder (lua\<stem>\): wraps the script's OnInit
--                            -- (chaining); at its first call the VM's funcLuaCommand gets the swap (once per VM),
--                            -- so OnInit, coroutines and anything else of that VM that starts a menu BGM is covered.
if VRFW_MenuMusic == nil then
  local M = {
    EXEC = 3048355248,   -- CMND_EXEC_CRAFT_OBJ_ID (retail: plays a bgm_config id)
    ASK = 568638161,     -- CMND_VRFW_SOUND_MENU_MUSIC(id) -> the BGM id to play instead, or false
  }
  VRFW_MenuMusic = M

  -- the VM's funcLuaCommand with the swap (idempotent: the wrapper marks itself)
  function M.Install()
    local real = funcLuaCommand
    if type(real) ~= "function" or real == M.wrapper then
      return false
    end
    -- the arguments go on as the caller gave them (a C command counts them: no extra nil for a call without one)
    local function wrapped(...)
      local cmd, a = ...
      if cmd == M.EXEC and type(a) == "number" then
        local ok, v = pcall(real, M.ASK, a)
        if ok and type(v) == "number" and v ~= 0 then
          return real(cmd, v, select(3, ...))
        end
      end
      return real(...)
    end
    M.wrapper = wrapped
    funcLuaCommand = wrapped
    return true
  end

  -- watch the menu script of this VM: the swap goes in at its OnInit (the engine's first callback)
  function M.Watch()
    local prev = OnInit
    OnInit = function(...)
      M.Install()
      if prev ~= nil then
        return prev(...)
      end
    end
    return true
  end
end
