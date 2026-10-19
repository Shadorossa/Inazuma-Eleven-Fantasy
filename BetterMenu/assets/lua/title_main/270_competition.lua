-- Ask the title for its real competition entry. Its VS flags and next RPG state
-- are initialised by retail code; MenuScene's leave then unloads the preview map.
do
  local C = BetterMenu.Competition
  if VRFW_Host then
    VRFW_Host.on("title_main", "SwitchCaseTitleInputWait", {
      id = "better_menu.competition.launch", phase = "around", priority = -100,
      fn = function(nxt, ...)
        local menu = funcLuaMenuCommand
        funcLuaMenuCommand = function(id, ...)
          if id == 3391522747 and C.F(2947612279, C.LAUNCH) == true then
            C.Clear(C.LAUNCH)
            return true, C.MODE
          end
          return menu(id, ...)
        end
        local r = table.pack(pcall(nxt, ...))
        funcLuaMenuCommand = menu
        if not r[1] then error(r[2], 0) end
        return table.unpack(r, 2, r.n)
      end,
    })
  end
end
