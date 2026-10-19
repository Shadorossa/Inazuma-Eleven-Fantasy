-- BetterMenu (mod better_menu, prefix BetterMenu): the team roster (soccer_team_dock_menu) opened by the main menu's
-- team drawer over the clubhouse or by its preload under the scene's black settle (docs/game/mods/better-menu.md §32).
-- Opened by another menu, the roster fades the screen in from black by itself when its formation layer opens
-- (`609722083(0, 0.3)` in its OnOpenLayer): over the room that is a black flash, under the settle it would lift the
-- black cover. While param better_menu_team_over_scene or better_menu_team_preload is set, that one fade-in call is
-- dropped (the rest of OnOpenLayer runs as the game's). Opened any other way nothing changes. No engine call at load
-- time.
BetterMenu = type(BetterMenu) == "table" and BetterMenu or {}
if BetterMenu.TeamDrawerNoFade == nil then
  local NoFade = {
    ID = "better_menu.team_drawer_no_fade",
    OVER_SCENE = 3752859857,    -- crc32("better_menu_team_over_scene")
    PRELOAD = 4060894317,       -- crc32("better_menu_team_preload")
    PARAM_HAS = 2947612279,
    FADE = 609722083,           -- (1 out | 0 in, seconds)
    FADE_IN = 0,
    LOG = 3661580131,           -- crc32("CMND_EVT_LOG")
  }
  local logged = false

  local function Active()
    for _, key in ipairs({ NoFade.OVER_SCENE, NoFade.PRELOAD }) do
      local ok, on = pcall(funcLuaCommand, NoFade.PARAM_HAS, key)
      if ok and on == true then return true end
    end
    return false
  end

  BetterMenu.TeamDrawerNoFade = { Active = Active }

  if VRFW_Host ~= nil then
    VRFW_Host.on("soccer_team_dock_menu", "OnOpenLayer", {
      id = NoFade.ID .. ".open",
      phase = "around",
      fn = function(nxt, ...)
        if not Active() then return nxt(...) end
        local real = funcLuaCommand
        funcLuaCommand = function(command, a1, ...)
          if command == NoFade.FADE and a1 == NoFade.FADE_IN then
            if not logged then
              logged = true
              pcall(real, NoFade.LOG, "better_menu", "team_drawer", "roster fade-in dropped")
            end
            return true
          end
          return real(command, a1, ...)
        end
        local r = table.pack(pcall(nxt, ...))
        funcLuaCommand = real
        if not r[1] then error(r[2], 0) end
        return table.unpack(r, 2, r.n)
      end,
    })
  end
end
