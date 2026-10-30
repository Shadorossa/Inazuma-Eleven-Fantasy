-- mod_options (VR-Framework): option hook «title_opening». Which movie the title plays as its opening.
--
-- Retail (title/title_main_2.00.16): the global GetPlayOpeningEventId() picks the opening movie id (movie_playing_config
-- movieId = crc32 of the event name): ev01_00050 (OP1), or, once OP2 is unlocked (CMND 2687660678), OP1 and
-- ev07_00140 (OP2) in turn (flag 4102746788 / 1977959046). Two callers look it up BY NAME at call time: LogoStart
-- (cold boot, after the logos / warnings) and SwitchCaseTitleInputWait (the title's idle attract loop, stored in n24 and
-- played by SwitchCaseTitleWaitFade). So hooking the global (an `around` handler of the framework's title_main host)
-- covers both; patches that redefine those callers still call it by name.
--
-- The row is the framework's own «Opening» (mod_options.opening, this part's options.toml, hook = "title_opening");
-- its values are the openings the enabled mods declare (kind vr_framework.opening/1 of the scene type): movie ids; value 0 = the game's own choice.
-- CMND_VRFW_OPTION_HOOK("title_opening", CMND_GET_LANGUAGE_CODE) answers that row's value (live: a change in
-- «Opciones de mods» applies at the next opening), or false when no active mod declares one; a value with
-- `lang = { es = "...", ... }` answers the movie of the game's text language. A movie id the game does not know
-- (CMND_GET_MOVIE_INFO false) falls back to the retail choice.
--
-- Nothing runs at chunk load but the handler registration (every engine call is inside it).

VRFW_TITLE_OPENING_CMD = VRFW_Cmd.VRFW_OPTION_HOOK   -- crc32("CMND_VRFW_OPTION_HOOK")
VRFW_TITLE_OPENING_INFO = VRFW_Cmd.GET_MOVIE_INFO    -- crc32("CMND_GET_MOVIE_INFO") (retail; false = no such movie)
VRFW_TITLE_OPENING_LANG = VRFW_Cmd.GET_LANGUAGE_CODE   -- crc32("CMND_GET_LANGUAGE_CODE") (retail)

-- The movie id chosen by the option row, or nil (no row / «as the game» / unknown movie).
function VRFW_TitleOpeningChoice()
  local okl, lang = pcall(funcLuaCommand, VRFW_TITLE_OPENING_LANG)
  if not okl or type(lang) ~= "number" then
    lang = nil
  end
  local ok, v = pcall(funcLuaCommand, VRFW_TITLE_OPENING_CMD, "title_opening", lang)
  if not ok or type(v) ~= "number" or v == 0 then
    return nil
  end
  local ok2, info = pcall(funcLuaCommand, VRFW_TITLE_OPENING_INFO, v)
  if not ok2 or info == false or info == nil then
    return nil
  end
  return v
end

-- the handler of the framework's title_main host (VRFW_Host): the option's movie, else the
-- game's own choice (nxt: retail, or what the patches under the host made of it)
if VRFW_Host ~= nil then
  VRFW_Host.on("title_main", "GetPlayOpeningEventId", {
    id = "mod_options.title_opening", phase = "around",
    fn = function(nxt, ...)
      local v = VRFW_TitleOpeningChoice()
      if v ~= nil then
        return v
      end
      return nxt(...)
    end,
  })
end
