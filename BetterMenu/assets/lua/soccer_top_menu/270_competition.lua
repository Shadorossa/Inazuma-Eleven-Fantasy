-- The preview handed a confirmed native game/difficulty to this state root.
-- Reserve here, where the engine has initialised Competition's VS context. After
-- the match, the root sends the in-memory game back to the clubhouse title, which reopens the list over the pitch.
-- While a Competition match passes through (going in or coming back), this root is never shown: its menu music is
-- not started, its background does not open the hub (no list reopened, no fade in), its list does not autosave
-- again (the match exit has already saved the game natively), and it hands over on its first step.
do
  local C = BetterMenu.Competition
  local init, step, open_layer = OnInit, Step, OnOpenLayer
  local BACKGROUND = 367379312 -- mainmenu90_00_background
  local MENU_MUSIC = 3048355248 -- CMND_EXEC_CRAFT_OBJ_ID: starts the menu's BGM
  local AUTO_SAVE, AUTO_SAVE_PREPARE = 3673719958, 1310263841 -- CMND_SYSTEM_AUTO_SAVE and the call before it
  local match, returning, co, frame, handshake = nil, false, nil, 0, false
  local passing = nil
  -- Runs the root's OnInit without its menu music start. The framework's menu music swap installs first, so the
  -- VM keeps the swap and only the filter is dropped afterwards.
  local function init_without_music(...)
    local music = VRFW_MenuMusic
    if music and music.Install then music.Install() end
    local kept, kept_wrapper = funcLuaCommand, music and music.wrapper
    funcLuaCommand = function(id, ...)
      if id == MENU_MUSIC then return true end
      return kept(id, ...)
    end
    local r = table.pack(pcall(init, ...))
    funcLuaCommand = kept
    if music then music.wrapper = kept_wrapper end
    if not r[1] then error(r[2], 0) end
    return table.pack(table.unpack(r, 2, r.n))
  end
  function OnInit(...)
    local s = C.State()
    passing = nil
    if type(s) == "table" then
      if s.launch == true then passing = "entry" elseif s.returning == true then passing = "return" end
    end
    local r
    if passing then
      r = init_without_music(...)
      C.Log("competition " .. passing .. ": soccer_top_menu opened as the hidden VS root; menu music not started, hub not opened")
    else
      r = table.pack(init(...))
    end
    match, returning, co, frame, handshake = nil, false, nil, 0, true
    return table.unpack(r, 1, r.n)
  end
  function OnOpenLayer(a1, ...)
    if not passing then
      if open_layer then return open_layer(a1, ...) end
      return
    end
    if a1 == BACKGROUND or not open_layer then return end
    local raw = funcLuaCommand
    funcLuaCommand = function(id, ...)
      if id == AUTO_SAVE or id == AUTO_SAVE_PREPARE then
        if id == AUTO_SAVE then C.Log("competition " .. tostring(passing) .. ": the hidden root's autosave left out (the game is already saved)") end
        return true
      end
      return raw(id, ...)
    end
    local r = table.pack(pcall(open_layer, a1, ...))
    funcLuaCommand = raw
    if not r[1] then error(r[2], 0) end
    return table.unpack(r, 2, r.n)
  end
  function Step(...)
    local r = table.pack(step(...))
    frame = frame + 1
    if handshake then
      local s = C.State()
      if type(s) == "table" then
        local next_match = C.State("take_match")
        if next_match ~= nil then
          match = type(next_match) == "table" and next_match or nil
          returning = not match and s.returning == true
          handshake = false
        end
      end
    end
    if match or returning then
      C.M(1558704558, 811496143, false)
      C.F(609722083, 1, 0)
      if C.F(898725220) ~= true then
        if returning then
          local s = C.State()
          if type(s) == "table" then
            -- back to the clubhouse: its title reopens the list over the pitch (the session keeps tab, row and mode)
            local accepted = C.F(C.TRAVEL, "better_menu.clubhouse", 0, "", 0)
            if accepted == true then
              local done = C.Reset()
              if done then
                C.Log("competition return: scene travel to the clubhouse, game reset from the hidden root")
                C.State("returned")
                returning, passing = false, nil
              end
            end
          end
        elseif not co then
          co = coroutine.create(function()
            C.Log("native start", match.game, match.stadium, match.difficulty)
            C.F(3014583614, match.game)
            C.F(1104380539, match.difficulty)
            local accepted = C.F(1620561217, match.game, match.stadium, match.difficulty)
            if accepted == false or accepted == nil then
              C.Log("native reservation refused")
              match, returning = nil, true
              return
            end
            C.F(769636339, 0) -- no menu music to fade out: the root closes at once
            C.F(320421347, 811496143)
            C.Log("competition entry: match reserved, hidden root closed for the match load")
            match, passing = nil, nil
          end)
        end
      end
      if co and coroutine.status(co) ~= "dead" then
        local ok, why = coroutine.resume(co)
        if not ok then C.Log("native start error", why) match, returning = nil, true end
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
