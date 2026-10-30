  -- «Bonificaciones de equipo» of a Pachanga team (docs/game/ui/pachanga-templates.md §3.7). soccer_parameter_menu
  -- builds its passive lists natively from TEAM 0 of the dock (params 3292994148 / 151854822 carry only the dock), so a
  -- 5v5 team showed its 11v11 team's bonuses. Empty 5v5 team: NG sound, nothing opens. Otherwise the loader swaps the
  -- dock's 11v11 / 5v5 member lists (CMND_EVT_PACHANGA_TEAMSWAP) while the screen is open and swaps them back as soon
  -- as it is closed (the opener's waitFalse returns); the loader also undoes a pending swap on save / return to title.
  -- Same block in pachanga_dock, pachanga_formation and pachanga_bank (one per menu VM).
  if type(EVT_Bonus5) ~= "function" then
    function EVT_Bonus5(dock, tag, open, ...)
      local SWAP = @crc:CMND_EVT_PACHANGA_TEAMSWAP@
      local PARAM_MENU = 2197290544 --[[soccer_parameter_menu]]
      local n = 0
      for i = 0, 28 do
        local ok, h = funcLuaCommand(1720957768, dock, 1, i, 0)
        if ok and type(h) == "number" and h ~= 0 then
          n = n + 1
        end
      end
      if n == 0 then
        funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
        pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT pachanga bonus", tag, "dock", dock, "empty 5v5 team: refused")
        return false
      end
      local okc, ok = pcall(funcLuaCommand, SWAP, dock, 1)
      pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, "EVT pachanga bonus", tag, "dock", dock, "5v5 members", n,
        "swap", tostring(okc and ok))
      if not (okc and ok) then
        funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
        return false
      end
      local swapped = true
      local function back()
        if swapped then
          swapped = false
          pcall(funcLuaCommand, SWAP, dock, 0)
        end
      end
      local wf = waitFalse
      if type(wf) == "function" then
        waitFalse = function(...)
          local r = table.pack(wf(...))
          if swapped and not funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, PARAM_MENU) then
            back()
          end
          return table.unpack(r, 1, r.n)
        end
      end
      local r = table.pack(pcall(open, ...))
      waitFalse = wf
      back()
      if not r[1] then
        error(r[2], 0)
      end
      return true, table.unpack(r, 2, r.n)
    end
  end
