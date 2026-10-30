-- BattleBayDeluxe bb_net_room, network_menu (network_room_match_top): while this player is in one of the
-- VR-Framework's own private rooms (CMND_VRFW_NET_STATUS phase waiting / joined / started; Steam transport, no EOS
-- lobby, the game's network module never runs) the menu goes at once to the game's own private-room screen (layer
-- group network_room_match_wait: members, rules, ready, start; its script's graft is bbn_wait.lua, the UI shell) the
-- way the retail «Crear sala» / join does once its EOS lobby is made, without that lobby: never the retail room list
-- (create / search / quick match = EOS lobbies). Back here leaves our room and closes network_menu. Outside our rooms
-- every function is the retail one. docs/game/modes/bb-p2p-lockstep.md §6. Globals only (BattleBayDeluxe.NetRoomTop, BBNT_*); nothing runs
-- at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.NetRoomTop = BattleBayDeluxe.NetRoomTop or {
  MENU = 106494436 --[[crc32 network_menu]],
  WAIT = 516266942 --[[crc32 network_room_match_wait: the private-room layer group]],
  STATUS = @crc:CMND_VRFW_NET_STATUS@,
  REVISION = @crc:CMND_VRFW_NET_REVISION@,
  LEAVE = @crc:CMND_VRFW_NET_LEAVE@,
  opened = false,
  frames = 0,
}

-- the logger (VRFW_Log), made at the first line: the framework's menu files load after the graft blocks
function BBNT_Log(...)
  BattleBayDeluxe.NetRoomTop.logger = BattleBayDeluxe.NetRoomTop.logger or VRFW_Log.New("BattleBayDeluxe.net_top")
  BattleBayDeluxe.NetRoomTop.logger(...)
end

-- our room's phase ("none" / "waiting" / "joined" / "started" / "closed") and whether this player hosts it; the
-- status is read again only when the room changed (CMND_VRFW_NET_REVISION)
function BBNT_State()
  local okv, rev = pcall(funcLuaCommand, BattleBayDeluxe.NetRoomTop.REVISION)
  if okv and rev ~= nil and BattleBayDeluxe.NetRoomTop.state ~= nil and BattleBayDeluxe.NetRoomTop.state.rev == rev then
    return BattleBayDeluxe.NetRoomTop.state.phase, BattleBayDeluxe.NetRoomTop.state.host
  end
  local ok, phase, role = pcall(funcLuaCommand, BattleBayDeluxe.NetRoomTop.STATUS)
  if not ok or type(phase) ~= "string" then
    phase, role = "none", ""
  end
  BattleBayDeluxe.NetRoomTop.state = { rev = okv and rev or nil, phase = phase, host = role == "host" }
  return phase, role == "host"
end

function BBNT_Ours()
  local phase = BBNT_State()
  return phase == "waiting" or phase == "joined" or phase == "started"
end

-- leave our room and close this menu (the caller's wait ends: back to the Battle Bay top menu)
function BBNT_Leave(why)
  BBNT_Log("leave", tostring(why))
  pcall(funcLuaCommand, BattleBayDeluxe.NetRoomTop.LEAVE)
  BattleBayDeluxe.NetRoomTop.opened = false
  BattleBayDeluxe.NetRoomTop.frames = 0
  funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, BattleBayDeluxe.NetRoomTop.MENU, true)
end

-- what OnDecideButtonCreateRoomWindow (host) / CallbackSelectJoinSession (guest) do after their EOS lobby step
-- succeeded, without it: the room-name parameter (0: the first room name), the cursor closed, the private-room layer
-- group, its condition background
function BBNT_ToRoom(is_host)
  BBNT_Log("our room: the private-room screen opens", tostring(is_host))
  pcall(ResetLayerGroup)
  if VRFW_Param.Has(2056018466) then
    VRFW_Param.Clear(2056018466)
  end
  VRFW_Param.Set(2056018466, 0)
  funcLuaCommand(2014550292, 0, false)
  funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, 2296367164 --[[cmn05_01_cursor]])
  funcLuaMenuCommand(@crc:CMND_ON_CHANGE_LAYER_GROUP@, BattleBayDeluxe.NetRoomTop.WAIT)
  funcLuaMenuCommand(3010622924, false)
  funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, 405940319 --[[vs01_04_room_condition_background]], 0,
    902337421 --[[offset01]], 2, 753088835 --[[Default]])
  funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, 405940319 --[[vs01_04_room_condition_background]], 0,
    2898379319 --[[offset02]], 0, 753088835 --[[Default]])
end

do
  local step = Step
  function Step(...)
    local phase, is_host = BBNT_State()
    local ours = phase == "waiting" or phase == "joined" or phase == "started"
    if ours then
      if not BattleBayDeluxe.NetRoomTop.opened then
        -- two frames for the menu's own open (its layers up), then the room screen
        BattleBayDeluxe.NetRoomTop.frames = BattleBayDeluxe.NetRoomTop.frames + 1
        if BattleBayDeluxe.NetRoomTop.frames >= 2 then
          BattleBayDeluxe.NetRoomTop.opened = true
          local ok, err = pcall(BBNT_ToRoom, is_host)
          if not ok then
            BBNT_Log("room screen error", tostring(err))
            BBNT_Leave("room screen error")
            return
          end
        end
      end
      -- 29/10 (install 360: «Conexión fallida.» at once): in our room the retail room list's own Step does not run.
      -- Its ErrorCheckStep asks the game's network error state (CMND_IS_ERROR_NETWORK), which is «error» because the
      -- game's network module never runs, and sent the screen to its error path (ErrorProc). The room list has
      -- nothing to do while the room screen (bbn_wait.lua) is up; it is the retail one again outside our rooms.
      return
    elseif BattleBayDeluxe.NetRoomTop.opened and phase ~= "started" then
      -- our room closed while the menu was open (and the room screen did not close it): this menu goes too (it would
      -- show the retail room list next)
      BBNT_Leave("room " .. tostring(phase))
      return
    end
    return step(...)
  end
end

do
  local top = OpenNetworkRoomMatchTop
  function OpenNetworkRoomMatchTop(...)
    if BBNT_Ours() or BattleBayDeluxe.NetRoomTop.opened then
      return -- never the retail room list (EOS lobbies) in our room
    end
    return top(...)
  end
end

do
  local back = OnBack
  function OnBack(...)
    if BBNT_Ours() or BattleBayDeluxe.NetRoomTop.opened then
      BBNT_Leave("back")
      return 1
    end
    return back(...)
  end
end
