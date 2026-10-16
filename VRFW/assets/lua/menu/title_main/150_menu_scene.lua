-- menu_scene (VR-Framework): title_main's side of a 3D field map under the main menu (docs/framework/menu-scene.md).
-- Handlers of the framework's title_main host (VRFW_Host); the run is held by scripts\menu_scene.lua.
--
--   * SwitchCaseTitleInputWait: while title_menu_2 asks for the scene (param vrfw_menu_scene_go), the request the
--     title reads is the retail Options item (1518731440): the retail branch runs as for a press (setting_top_menu as
--     the next state's menu, the save loaded by «Continuar»). Param vrfw_menu_scene_options then marks the opening.
--   * SwitchCaseTitleFade: during that opening and while the scene is up the title's white fade is the black one (the
--     screen is black already / the next screen loads under black), unless the action leaves in white (param
--     vrfw_menu_scene_leave_white, a hotspot's or tile action's leave_fade = "white"): then the fade is the white one.
--   * SwitchCaseTitleEnd while the scene is up (param vrfw_menu_scene_up): instead of handing the next state to the
--     rpg scene that holds the map, the game is kept in memory (CMND_VRFW_SLOT_CARRY), the game is reset
--     (CMND_GAME_RESET: the old rpg scene and its map end) and the reset goes straight into the state the title wrote
--     (CMND_VRFW_MENU_TOPBAR_DIRECT, the top bar's straight reset). Refused: the retail title after the reset.
--   * A chronicle_map action (param vrfw_menu_scene_chronicle_wait) and the title's «Modo Crónica» request: the
--     framework keeps the action pending (CMND_VRFW_MENU_SCENE_PENDING) for the Chronicle top menu that opens after the
--     leave's reset (lua/menu/chronicle_mode_top_menu/150_menu_scene.lua goes straight to the map); the title ends
--     after the push-in's time.
-- No engine call at load time.

local MT = {
  LOG = 3661580131,          -- CMND_EVT_LOG
  SET = 3352504786,          -- CMND_VRFW_MENU_SCENE_SET (state, arg) -> 1 | 0, state
  STATE = 2588710643,        -- CMND_VRFW_MENU_SCENE_STATE () -> state, key, …
  PARAM_SET = 3860611758, PARAM_HAS = 2947612279, PARAM_CLEAR = 3363400568,
  GO = 2860602156,           -- param vrfw_menu_scene_go
  OPTIONS = 1432246941,      -- param vrfw_menu_scene_options
  UP = 1602039306,           -- param vrfw_menu_scene_up
  HUD_OFF = 3499142076,      -- param vrfw_menu_scene_hud_off
  TITLE_READY = 358816896,   -- param vrfw_menu_scene_title_ready: the title reads requests (its menu fully open)
  STORY_GO = 4275168888,     -- param vrfw_menu_scene_story_continue (value = ms to wait): skip the story submenu
  STORY_KIND = 3368022765,   -- param vrfw_menu_scene_story_kind: 1 «Continuar» (default), 2 «Partida nueva»
  STORY_PICK = 1790329263,   -- param vrfw_menu_scene_story_pick: the submenu opens and picks that entry itself
  STORY_WAIT = 2392182225,   -- param vrfw_menu_scene_story_wait: ms to wait before the submenu opens (with STORY_PICK)
  NEW_GAME = 953037506,      -- the title's next state for a new story
  PARAM_GET = 3522198769,
  STORY_INFO = 3984017190,   -- () -> ok, story saves, …
  CONTINUE = 3935651977,     -- the title's next state «Continue»
  READ_REQUEST = 3391522747, -- the title menu's request: ok, item
  ITEM_OPTIONS = 1518731440, -- the retail «Opciones» item
  WHITE_FADE = 4011714927,
  BLACK_FADE = 609722083,
  FADE_DONE = 2259183189,
  SAVE_WORKING = 1979970074,
  CARRY = 2310157611,        -- CMND_VRFW_SLOT_CARRY (1 keep, 0 drop) -> kept, KiB, play s, players, why
  TB_DIRECT = 2048294502,    -- CMND_VRFW_MENU_TOPBAR_DIRECT () -> true: the reset goes straight into the next state
  GAME_RESET = 3897105282,   -- CMND_GAME_RESET
  NO_PRESS_START = 937976662, -- (true) the next title opens the main menu at once
  CHRONICLE_WAIT = 53570903, -- param vrfw_menu_scene_chronicle_wait (value = ms of the push-in): Modo Crónica straight to the map
  CHRONICLE_ITEM = 130186018, -- the title's «Modo Crónica» item
  PENDING = 3277277325,      -- CMND_VRFW_MENU_SCENE_PENDING (action): waits for the menu after the leave's reset
  LEAVE_WHITE = 2048703318,  -- param vrfw_menu_scene_leave_white: the leave's fade is the white one
  ID = "vr_framework.menu_scene",
  STILL_HERE = 900,          -- frames after the reset: the reset did not take (the retail hand-over runs)
}

local mt_leaving = false
local mt_white_logged = false    -- the white leave logged once per visit
local mt_chronicle_ms = nil      -- the push-in before the title ends (a chronicle_map action was pressed)

local function MT_Log(...)
  pcall(funcLuaCommand, MT.LOG, "menu_scene", "title_main", ...)
end

local function MT_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then return nil end
  return table.unpack(r, 2, r.n)
end

-- a param cleared only when it is set (the retail way)
local function MT_Clear(k)
  if MT_Call(MT.PARAM_HAS, k) == true then
    MT_Call(MT.PARAM_CLEAR, k)
  end
end

local function MT_Has(k)
  return MT_Call(MT.PARAM_HAS, k) == true
end

-- the scene is up: the game kept in memory, reset, straight into the state the title wrote; true = left (never returns
-- in that case before the reset ends this script), false = the retail hand-over must run
local function MT_Leave()
  MT_Clear(MT.UP)
  MT_Clear(MT.LEAVE_WHITE)
  MT_Clear(MT.HUD_OFF)          -- the picked mode's field HUD is the game's
  MT_Call(MT.SET, "leaving", "a mode was picked: reset straight into it, the map goes with the old rpg scene")
  for _ = 1, 300 do
    if MT_Call(MT.SAVE_WORKING) ~= true then break end
    coroutine.yield()
  end
  local okc, kept, kib, play, players, why = pcall(funcLuaCommand, MT.CARRY, 1)
  if not okc or kept ~= true then
    MT_Log("leave: no carry (", tostring(okc and why or kept), "): the map is dropped by a reset to the retail title")
    MT_Call(MT.SET, "failed", "title_main: no carry for the straight reset (" .. tostring(okc and why or kept) .. ")")
    MT_Call(MT.NO_PRESS_START, true)
    MT_Call(MT.GAME_RESET)
    for _ = 1, MT.STILL_HERE do coroutine.yield() end
    MT_Log("leave: still here", MT.STILL_HERE, "frames after the reset: the retail hand-over runs (the map stays loaded)")
    return false
  end
  MT_Log("leave: game kept in memory", kib, "KiB, play", play, "s,", players, "players; reset")
  MT_Call(MT.GAME_RESET)
  local okd, r = pcall(funcLuaCommand, MT.TB_DIRECT)
  if okd and r == true then
    MT_Log("leave: straight reset: the new rpg scene opens the picked mode (no title, no map)")
  else
    pcall(funcLuaCommand, MT.CARRY, 0)
    MT_Log("leave: straight reset refused (", tostring(r), "): the retail title after the reset (the map is gone)")
    MT_Call(MT.SET, "failed", "title_main: straight reset refused (" .. tostring(r) .. ")")
  end
  for _ = 1, MT.STILL_HERE do coroutine.yield() end
  MT_Log("leave: still here", MT.STILL_HERE, "frames after the reset: the retail hand-over runs (the map stays loaded)")
  return false
end

if VRFW_Host ~= nil then
  -- the scene's request read as a press of Options, inside the retail loop (every read of the request this call makes)
  VRFW_Host.on("title_main", "SwitchCaseTitleInputWait", {
    id = MT.ID .. ".request",
    phase = "around",
    fn = function(nxt, ...)
      mt_leaving = false           -- a new main menu visit
      mt_white_logged = false
      mt_chronicle_ms = nil
      local menu = funcLuaMenuCommand
      local reads = 0
      funcLuaMenuCommand = function(id, ...)
        if id == MT.READ_REQUEST then
          -- once a second: asking the state lets the framework release its black cover if the main menu never
          -- reached «up» over a menu scene (CMND_VRFW_MENU_SCENE_STATE)
          reads = reads + 1
          if reads % 60 == 1 then pcall(funcLuaCommand, 2588710643) end
          if reads == 1 then
            -- the title reads requests: its menu is fully open (title_menu_2 waits for this before «up»)
            pcall(funcLuaCommand, MT.PARAM_SET, MT.TITLE_READY, 0, 1, 1)
          end
        end
        if id == MT.READ_REQUEST and not MT_Has(MT.GO) and MT_Has(MT.CHRONICLE_WAIT) then
          local r = table.pack(menu(id, ...))
          if r[1] == true and r[2] == MT.CHRONICLE_ITEM then
            mt_chronicle_ms = tonumber(MT_Call(MT.PARAM_GET, MT.CHRONICLE_WAIT)) or 0
            MT_Clear(MT.CHRONICLE_WAIT)
            if MT_Has(MT.UP) then
              MT_Call(MT.PENDING, "chronicle_map")
              MT_Log("chronicle map: Modo Crónica pressed, the title ends after", math.floor(mt_chronicle_ms),
                "ms; the Chronicle top menu goes straight to the map")
            else
              mt_chronicle_ms = nil
            end
          end
          return table.unpack(r, 1, r.n)
        end
        if id == MT.READ_REQUEST and MT_Has(MT.GO) then
          MT_Clear(MT.GO)
          MT_Call(MT.PARAM_SET, MT.OPTIONS, 0, 1, 1)
          MT_Call(MT.SET, "options", "the title pressed Options: the save loads, setting_top_menu opens")
          MT_Log("request: Options pressed for the scene")
          return true, MT.ITEM_OPTIONS
        end
        return menu(id, ...)
      end
      local r = table.pack(pcall(nxt, ...))
      funcLuaMenuCommand = menu
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  -- the title's start over a scene's map (state switching): the screen is held black by the framework's cover until
  -- title_menu_2 is up, so the title's own fade-in (609722083 to 0 over its production seconds, about 1 s) is made
  -- instant; SwitchCaseTitleWaitFade then goes on at once
  VRFW_Host.on("title_main", "SwitchCaseTitleLoad", {
    id = MT.ID .. ".instant_fade_in",
    phase = "around",
    fn = function(nxt, ...)
      local okst, state = pcall(funcLuaCommand, MT.STATE)
      if not okst or state ~= "switching" then
        return nxt(...)
      end
      local cmd = funcLuaCommand
      local made = 0
      funcLuaCommand = function(id, a1, a2, ...)
        if id == MT.BLACK_FADE and a1 == 0 and type(a2) == "number" and a2 > 0 then
          made = made + 1
          return cmd(id, a1, 0, ...)
        end
        return cmd(id, a1, a2, ...)
      end
      local r = table.pack(pcall(nxt, ...))
      funcLuaCommand = cmd
      if not r[1] then
        error(r[2], 0)
      end
      if made > 0 then
        MT_Log("title start over the scene's map: its fade-in made instant (", made, "fade(s)), the cover hides it")
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  -- the scene's opening and its leaving stay black (the retail white fade would flash)
  VRFW_Host.on("title_main", "SwitchCaseTitleFade", {
    id = MT.ID .. ".fade",
    phase = "around",
    fn = function(nxt, ...)
      if not MT_Has(MT.OPTIONS) and not MT_Has(MT.UP) then
        return nxt(...)
      end
      local opening = MT_Has(MT.OPTIONS)
      local white = not opening and MT_Has(MT.LEAVE_WHITE)
      local cmd = funcLuaCommand
      funcLuaCommand = function(id, a1, ...)
        if white and (id == MT.WHITE_FADE or id == MT.BLACK_FADE) then
          if not mt_white_logged then
            mt_white_logged = true
            MT_Log("leave: the action ends in white: the title's fade is the white one (", tostring(a1), ")")
          end
          return cmd(MT.WHITE_FADE, a1, ...)
        end
        if id == MT.WHITE_FADE or (opening and id == MT.BLACK_FADE) then
          if opening then
            return cmd(MT.BLACK_FADE, a1, 0)     -- the screen is black already: no fade time
          end
          return cmd(MT.BLACK_FADE, a1, ...)
        end
        return cmd(id, a1, ...)
      end
      local r = table.pack(pcall(nxt, ...))
      funcLuaCommand = cmd
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  -- the scene's opening: the production wait after the press (n22) skipped, straight to the fade (title_main's state n16)
  VRFW_Host.on("title_main", "SwitchCaseTitleEndFadeInit", {
    id = MT.ID .. ".no_wait",
    phase = "around",
    fn = function(nxt, ...)
      if not MT_Has(MT.OPTIONS) then
        if mt_chronicle_ms ~= nil then
          -- a chronicle_map action: the push-in runs before the title's own wait and fade
          local wait = mt_chronicle_ms
          mt_chronicle_ms = nil
          local t = 0
          while t < wait / 1000 do
            t = t + (MT_Call(1549797111) or 0.016)
            coroutine.yield()
          end
        end
        return nxt(...)
      end
      local h = VRFW_Host.hosts and VRFW_Host.hosts.title_main
      local L = h and h.L
      local ok = L ~= nil and pcall(function()
        if L.n16 ~= 7 then error("state " .. tostring(L.n16)) end
        L.n16 = 8
      end)
      if not ok then
        return nxt(...)
      end
      return false
    end,
  })

  -- a menu scene's tile action continue_story: instead of opening the story submenu (state 17), what its «Continuar»
  -- does (story_mode_top_menu OnDecideFocus + GoToStory, then this script's own InputWaitStoryModeTopMenu branch): the
  -- story's continue flags, then the title's end with «Continue» (state 7), after the push-in's time. Not reachable
  -- (no locals, no story save): the game's submenu.
  VRFW_Host.on("title_main", "SwitchCaseTitleWaitOpenStoryModeTopMenu", {
    id = MT.ID .. ".story_continue",
    phase = "around",
    fn = function(nxt, ...)
      if not MT_Has(MT.STORY_GO) then
        if MT_Has(MT.STORY_PICK) and MT_Has(MT.STORY_WAIT) then
          -- a submenu entry picked in the scene: the push-in first, then the game's submenu (it picks the entry)
          local w = tonumber(MT_Call(MT.PARAM_GET, MT.STORY_WAIT)) or 0
          MT_Clear(MT.STORY_WAIT)
          local t = 0
          while t < w / 1000 do
            t = t + (MT_Call(1549797111) or 0.016)
            coroutine.yield()
          end
          MT_Log("story submenu: entry", tostring(MT_Call(MT.PARAM_GET, MT.STORY_PICK)), "- 1 picked by the scene after", math.floor(w), "ms")
        end
        return nxt(...)
      end
      local wait = tonumber(MT_Call(MT.PARAM_GET, MT.STORY_GO)) or 800
      local kind = MT_Has(MT.STORY_KIND) and tonumber(MT_Call(MT.PARAM_GET, MT.STORY_KIND)) or 1
      MT_Clear(MT.STORY_GO)
      MT_Clear(MT.STORY_KIND)
      local okc, has, saves = pcall(funcLuaCommand, MT.STORY_INFO)
      local h = VRFW_Host.hosts and VRFW_Host.hosts.title_main
      local L = h and h.L
      local new_game = kind == 2
      -- the submenu offers «Continuar» only with a story save and «Partida nueva» only without one
      if not okc or type(saves) ~= "number" or (new_game and saves > 0) or (not new_game and saves <= 0) or L == nil then
        MT_Log("story", new_game and "new game" or "continue", ": not possible (saves", tostring(saves), ", locals",
          tostring(L ~= nil), "): the story submenu")
        return nxt(...)
      end
      local t = 0
      while t < wait / 1000 do
        t = t + (MT_Call(1549797111) or 0.016)
        coroutine.yield()
      end
      if new_game then
        -- story_mode_top_menu «Partida nueva»: the new game's data, its start chapter param
        MT_Call(2583455227)
        MT_Clear(501194956)
        MT_Call(MT.PARAM_SET, 501194956, 0, 23538565, 1)
      end
      -- story_mode_top_menu «Continuar» / «Partida nueva»: not the Historia+ start, the story start step, the board bit
      -- cleared
      MT_Call(3964465990, 1554597423, false)
      MT_Call(1665212515)
      MT_Call(3964465990, 1255964678, false)
      -- the next state is the story (no root menu, no VS menu): the scene's own Options request had set one, and the
      -- leave's straight reset opens what the title wrote
      pcall(funcLuaMenuCommand, 3479138216, 0)
      MT_Call(419468738, false)
      MT_Call(1507811093, false)
      MT_Clear(3288069995)
      if not new_game then g_isExistSaveData = true end
      local ok = pcall(function()
        L.n25 = new_game and MT.NEW_GAME or MT.CONTINUE
        L.n16 = 7
      end)
      MT_Log("story", new_game and "new game" or "continue", ": no submenu, the story starts (", tostring(ok), ") after",
        math.floor(wait), "ms")
      if not ok then
        return nxt(...)
      end
      return false
    end,
  })

  -- leaving the main menu while the map is under it: the reset that unloads the map
  VRFW_Host.on("title_main", "SwitchCaseTitleEnd", {
    id = MT.ID .. ".leave",
    phase = "around",
    fn = function(nxt, ...)
      if mt_leaving or not MT_Has(MT.UP) then
        return nxt(...)
      end
      if MT_Call(MT.FADE_DONE) ~= true then
        return false
      end
      mt_leaving = true
      local done = nxt(...)        -- the retail closing of the title menus
      local ok, left = pcall(MT_Leave)
      if not ok then
        MT_Log("leave: error", tostring(left), ": the retail hand-over runs")
        MT_Call(MT.SET, "failed", "title_main: leave error " .. tostring(left))
      end
      return done
    end,
  })
end
