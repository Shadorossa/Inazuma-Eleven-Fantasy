-- VRFW_MATCH: the match start service (VR-Framework 2.2.x). Starts a match straight
-- from the menu this VM runs (any hub of the menus: «Modos de juego», Estadio BB, Mercado…), the way the game's own
-- friendly / VS CPU start does it (the match engine's friendly executor VRFW_PACHANGA: team, the VS-CPU pre-match
-- sequence, CMND_RESERVE_SOCCER, the caller's menu closed), with no hop through the title or another menu, and comes
-- back to the SAME hub afterwards: a friendly declared with return = "menus" (no game reset; the soccer state's own way
-- reopens the hub with the in-memory game; friendly_way_back closes the friendly there, sink off, the hub's play mode
-- back). Any mod (a training field, a custom friendly) calls it from its own menu code:
--
--   local ok, why = VRFW_MATCH.start{
--     friendly = "<friendly id>",       -- a [[friendly]] with return = "menus" (save = "sink" keeps the file untouched)
--     game = <soccer_game id>, difficulty = 1, stadium = <map crc> | nil, rival = <team> | nil,
--     set = <VS team set> | function() return <set>[, <friendly id>] end | nil,   -- a function is read after
--                                       -- play_mode is set; its second answer (a friendly id) replaces `friendly`
--                                       -- (e.g. the same match with another team policy)
--     overrides = { {"teams.rival.players", 3}, … },   -- the match engine's next-match overrides (cleared first)
--     play_mode = 1 | nil,              -- the play mode the match runs in (the hub's comes back on the way back)
--     keep_menu = false,                -- true: the caller closes its own menus (on_reserved)
--     settle = 0,                       -- frames to wait first (a hub that just opened: its own init / messages)
--     black = true,                     -- false: no black screen from the request on; the friendly's own intro (its
--                                       -- `before = [{ op = "fade_encounter" }]`: the retail match-start transition of
--                                       -- the VS CPU list) covers the hub, as in the retail start
--     on_reserved = function() end, on_failed = function(why) end,
--   }
--
-- `start` answers at once (true = the launch runs from this menu's next Step: black at once unless `black = false`) or false +
-- why (no friendly executor in this menu, a launch already running). The launch steps log under «VRFW match_start»
-- with the frames they took (the hops: request -> reserved). Leaving a running match the retail way:
-- CMND_VRFW_MATCH_EXIT (VRFW_MATCH.exit()). Defines functions only: no engine call at load time.
--
-- The hand-over: the engine starts a reserved match only once the menu scene's ROOT closes (the menu opened as the
-- scene's first menu: retail check 2119959601, true in its OnInit). A caller that is the root closes itself. A caller
-- opened inside another root (team_dock_common_top_menu, opened by its root soccer_team_dock_menu) hands the close over:
-- every root records itself at OnInit (param vrfw_match_start_scene_root); the caller writes its menu id into param
-- vrfw_match_start_hand_over and the root's Step closes the caller, waits until it is gone and the menus settled, then
-- closes itself the retail way (769636339(1.5) + CMND_CLOSE_MENU_OBJECT). The caller waits HAND_OVER_TIMEOUT frames
-- for that; still open after them: the launch is given up (rolled back, fade in, error sound, on_failed).
VRFW_MATCH = VRFW_MATCH or {}
do
  local M = VRFW_MATCH
  local C = {
    LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
    CALLER = VRFW_Cmd.VRFW_FRIENDLY_CALLER,       -- CMND_VRFW_FRIENDLY_CALLER
    OVERRIDE = VRFW_Cmd.VRFW_RULE_ENGINE_OVERRIDE,     -- CMND_VRFW_RULE_ENGINE_OVERRIDE
    EXIT = VRFW_Cmd.VRFW_MATCH_EXIT,          -- CMND_VRFW_MATCH_EXIT
    PAUSE = VRFW_Cmd.VRFW_GAME_PAUSE,        -- CMND_VRFW_GAME_PAUSE([0 / 1]) -> ok, paused
    PLAY_MODE = 3718253404,    -- set play mode
    FADE = 609722083,          -- (on, seconds) screen fade to black
    CLOSE = VRFW_Cmd.CLOSE_MENU_OBJECT,         -- CMND_CLOSE_MENU_OBJECT
    SE = VRFW_Cmd.SND_PLAY_SE, SE_NO = 2086672038,
    MSG_BUSY = 898725220,      -- a message window is up
    IS_SCENE_ROOT = 2119959601, -- (funcLuaMenuCommand) this menu was opened as the menu scene's root
    EXISTS = VRFW_Cmd.IS_EXIST_MENU_OBJECT,       -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
    SETTLED = 3050482496,      -- (funcLuaMenuCommand) no menu is opening / closing
    FADE_BUSY = 2736534827,    -- a fade is running
    SCENE_END_WAIT = 769636339, -- (seconds) the retail wait before a root closes for a reserved match
    VS_SET = VRFW_Cmd.GET_VS_USE_TEAM_SET,       -- CMND_GET_VS_USE_TEAM_SET -> the active match team's set
    FIVE_CHECK = 1538643580,   -- (set, 1, false) the retail member check of a set's 5v5 team: 1..10 = incomplete
  }
  local PARAM_SCENE_ROOT = 2082985882 -- crc32("vrfw_match_start_scene_root"): menu id of the scene's root
  local PARAM_HAND_OVER = 3190064600  -- crc32("vrfw_match_start_hand_over"): menu id of the caller to close
  local HAND_OVER_TIMEOUT = 600       -- frames the caller waits for the root to take the hand-over
  local ROOT_WAIT = 120               -- frames the root waits for each step of its close
  local SCENE_END_SECONDS = 1.5
  local script = type(EVT_PATCH) == "table" and EVT_PATCH.script or "?"
  M.stem = type(script) == "string" and (script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")) or "?"
  M.co, M.frames, M.wrapped, M.black = nil, 0, false, false
  M.watch, M.root_co, M.is_root, M.self_menu = nil, nil, false, nil

  local function log(...)
    pcall(funcLuaCommand, C.LOG, "VRFW match_start", tostring(M.stem), ...)
  end
  M.log = log

  local function unsigned(v) return VRFW_Id.u32_or(v, v) end

  local function param_get(key)
    return unsigned(VRFW_Param.Get(key))
  end

  local function param_set(key, value)
    if VRFW_Param.Has(key) then VRFW_Param.Clear(key) end
    if value ~= nil then VRFW_Param.Set(key, value) end
  end

  local function menu_exists(menu)
    local ok, yes = pcall(funcLuaMenuCommand, C.EXISTS, menu)
    return ok and yes == true
  end

  -- the caller is not the scene's root: the root takes the close (true), else false (the caller closes itself)
  local function hand_over(menu, spec, mode)
    local root = param_get(PARAM_SCENE_ROOT)
    if type(menu) ~= "number" or root == nil or root == unsigned(menu) or not menu_exists(root) then
      return false
    end
    param_set(PARAM_HAND_OVER, unsigned(menu))
    M.watch = {frames = 0, menu = menu, root = root, spec = spec, mode = mode}
    log("hand-over: the scene root", root, "closes this menu and itself")
    return true
  end

  -- the root never took the hand-over: the launch is given up and this menu stays usable
  local function hand_over_failed(w)
    M.watch = nil
    log("hand-over: the scene root did not close after", w.frames, "frame(s): the launch is given up")
    param_set(PARAM_HAND_OVER, nil)
    local P = VRFW_PACHANGA
    if type(P) == "table" and type(P.abort) == "function" then pcall(P.abort, "hand-over timeout") end
    pcall(funcLuaCommand, C.CALLER, "")
    pcall(funcLuaCommand, C.OVERRIDE, "")
    if type(w.spec.play_mode) == "number" and type(w.mode) == "number" and w.mode >= 0 then
      pcall(funcLuaCommand, C.PLAY_MODE, w.mode)
    end
    M.black = false
    pcall(funcLuaCommand, C.FADE, 0, 0.3)
    pcall(funcLuaCommand, C.SE, C.SE_NO)
    if type(w.spec.on_failed) == "function" then pcall(w.spec.on_failed, "hand-over") end
  end

  local function wait_frames(frames, busy)
    local n = 0
    while n < frames and busy() do
      n = n + 1
      coroutine.yield()
    end
    return n
  end

  -- the scene's root: close the caller, let the menus settle, close itself (the engine starts the match)
  local function root_close(caller)
    log("hand-over: closing", caller, "then this scene root")
    pcall(funcLuaCommand, C.CLOSE, caller)
    coroutine.yield()
    local gone = wait_frames(ROOT_WAIT, function() return menu_exists(caller) end)
    local settled = wait_frames(ROOT_WAIT, function()
      local ok, done = pcall(funcLuaMenuCommand, C.SETTLED)
      return ok and done == false
    end)
    local faded = wait_frames(ROOT_WAIT, function()
      local ok, busy = pcall(funcLuaCommand, C.FADE_BUSY)
      return ok and busy == true
    end)
    log("hand-over: the root closes", "gone", gone, "settled", settled, "fade", faded)
    pcall(funcLuaCommand, C.SCENE_END_WAIT, SCENE_END_SECONDS)
    pcall(funcLuaCommand, C.CLOSE, M.self_menu)
  end

  local function launch(spec)
    local P = VRFW_PACHANGA
    -- a hub that just opened: its init, fades and messages first (the screen stays black meanwhile)
    local n = 0
    while n < (tonumber(spec.settle) or 0) or (n < 900 and select(2, pcall(funcLuaCommand, C.MSG_BUSY)) == true) do
      n = n + 1
      coroutine.yield()
    end
    pcall(funcLuaCommand, C.OVERRIDE, "")
    for _, o in ipairs(spec.overrides or {}) do
      local ok, good, why = pcall(funcLuaCommand, C.OVERRIDE, o[1], o[2])
      if not ok or good ~= true then log("override refused", tostring(o[1]), tostring(o[2]), tostring(why)) end
    end
    local okc, _, menu, mode = pcall(funcLuaCommand, C.CALLER, M.stem)
    if not okc then menu, mode = nil, nil end
    -- after the match the game reopens the menu scene's root, not a menu opened inside it: the way back of a
    -- return = "menus" friendly waits for the root (this menu is still the one closed at the reservation)
    local root = param_get(PARAM_SCENE_ROOT)
    if type(menu) == "number" and root ~= nil and root ~= unsigned(menu) and menu_exists(root) then
      pcall(funcLuaCommand, C.CALLER, root)
      log("caller: the scene root", root, "(the menu the game reopens after the match)")
    end
    if type(spec.play_mode) == "number" then
      pcall(funcLuaCommand, C.PLAY_MODE, spec.play_mode)
    end
    local set, friendly = spec.set, spec.friendly
    if type(set) == "function" then
      local okf, v, f = pcall(set)       -- read under the match's play mode (e.g. the mode's VS team set)
      set = okf and type(v) == "number" and v or nil
      if okf and type(f) == "string" and f ~= "" then friendly = f end
    end
    log("start", tostring(friendly), "game", tostring(spec.game), "set", tostring(set), "from play mode", tostring(mode),
      "frame", M.frames)
    local ok, why = P.start(friendly, {
      game = spec.game, difficulty = spec.difficulty, stadium = spec.stadium, set = set, rival = spec.rival,
      tag = spec.tag, sub = spec.sub, objective = spec.objective,
      on_reserved = function()
        M.black = false
        log("reserved after", M.frames, "frame(s): this menu hands over to the match")
        if type(spec.on_reserved) == "function" then pcall(spec.on_reserved) end
        if not spec.keep_menu and type(menu) == "number" and menu ~= 0 and not hand_over(menu, spec, mode) then
          pcall(funcLuaCommand, C.CLOSE, menu)     -- the caller is the root: the engine starts the match once it is gone
        end
      end,
    })
    if not ok then
      log("start failed", tostring(why))
      pcall(funcLuaCommand, C.CALLER, "")
      pcall(funcLuaCommand, C.OVERRIDE, "")
      if type(spec.play_mode) == "number" and type(mode) == "number" and mode >= 0 then
        pcall(funcLuaCommand, C.PLAY_MODE, mode)
      end
      M.black = false
      pcall(funcLuaCommand, C.FADE, 0, 0.3)
      pcall(funcLuaCommand, C.SE, C.SE_NO)
      if type(spec.on_failed) == "function" then pcall(spec.on_failed, why) end
    end
  end

  local function root_tick()
    if M.root_co == nil then
      local caller = param_get(PARAM_HAND_OVER)
      if caller == nil then return end
      param_set(PARAM_HAND_OVER, nil)
      M.root_co = coroutine.create(function() root_close(caller) end)
    end
    local ok, err = coroutine.resume(M.root_co)
    if not ok then log("hand-over error", tostring(err)) end
    if not ok or coroutine.status(M.root_co) == "dead" then M.root_co = nil end
  end

  local function tick()
    if M.is_root then pcall(root_tick) end
    local w = M.watch
    if w ~= nil then
      w.frames = w.frames + 1
      if w.frames >= HAND_OVER_TIMEOUT then hand_over_failed(w) end
    end
    if M.co == nil then return end
    if M.black then
      pcall(funcLuaCommand, C.FADE, 1, 0)       -- over the hub's own fades: no menu frame before the match
    end
    M.frames = M.frames + 1
    local ok, err = coroutine.resume(M.co)
    if not ok then log("error", tostring(err)) end
    if not ok or coroutine.status(M.co) == "dead" then M.co = nil end
  end

  local function wrap_step()
    if M.wrapped or type(Step) ~= "function" then return end
    M.wrapped = true
    local step = Step
    Step = function(...)
      local r = table.pack(step(...))
      pcall(tick)
      return table.unpack(r, 1, r.n)
    end
  end

  -- every menu's OnInit: a scene root records itself (the hand-over target of the callers opened inside it)
  local recorded = false
  local function record_root()
    if recorded then return end
    recorded = true
    local ok, root = pcall(funcLuaMenuCommand, C.IS_SCENE_ROOT)
    if not ok or root ~= true or type(CRC32) ~= "function" or M.stem == "?" then return end
    M.is_root, M.self_menu = true, unsigned(CRC32(M.stem))
    param_set(PARAM_SCENE_ROOT, M.self_menu)
    wrap_step()
  end

  -- The team policy of a pachanga-style friendly (team = "active_friendly"), for the `set` function of M.start: the
  -- active pachanga team when one is set; none set: the active match team's five, played with `current_friendly` (the
  -- same friendly declared with team = "current"); neither has a complete five, or no such friendly: -1 (the friendly
  -- refuses, the caller explains). Returns set[, friendly id].
  function M.pachanga_team(current_friendly)
    local P = VRFW_PACHANGA
    local set = type(P) == "table" and type(P.pachanga_set) == "function" and P.pachanga_set() or nil
    if type(set) == "number" then
      return set
    end
    if type(current_friendly) ~= "string" or current_friendly == "" then
      log("no active pachanga team")
      return -1
    end
    local okv, vs = pcall(funcLuaCommand, C.VS_SET)
    if okv and type(vs) == "number" and vs >= 0 then
      local okc, code = pcall(funcLuaCommand, C.FIVE_CHECK, vs, 1, false)
      if okc and not (type(code) == "number" and code > 0 and code < 11) then
        log("no active pachanga team: the active match team plays", vs, current_friendly)
        return vs, current_friendly
      end
      log("no active pachanga team and the active match team", vs, "has no complete five", tostring(code))
    end
    return -1
  end

  -- the launch from this menu (see the header). true, or false + why.
  function M.start(spec)
    if type(spec) ~= "table" or type(spec.friendly) ~= "string" then return false, "no friendly" end
    local P = VRFW_PACHANGA
    if type(P) ~= "table" or type(P.start) ~= "function" then
      log("refused: no friendly executor (VRFW_PACHANGA) in this menu")
      return false, "no executor"
    end
    if M.co ~= nil or M.watch ~= nil then return false, "busy" end
    if not M.wrapped and type(Step) ~= "function" then
      log("refused: this menu has no Step to run the launch from")
      return false, "no step"
    end
    -- black at once: no menu is seen until the match; `black = false`: the friendly's intro shows instead (no
    -- forced black over it: the retail encounter transition, then the match loading)
    local black = spec.black ~= false
    if black then pcall(funcLuaCommand, C.FADE, 1, 0) end
    M.frames, M.black = 0, black
    M.co = coroutine.create(function() launch(spec) end)
    wrap_step()
    log("requested", spec.friendly)
    return true
  end

  -- leave the running match the retail way (the hold-to-leave button; no game reset). true, or false + why.
  -- The retail hold («Finalizar partido») counts only WHILE THE GAME IS PAUSED (its pause byte): the game is paused here first and stays paused until the match ends (the training field's
  -- «Reiniciar» / «Aplicar cambios» closed its window, which unpaused the game, and the hold never counted: black
  -- screen, music on, no restart).
  function M.exit(ms)
    local okp, pok, paused = pcall(funcLuaCommand, C.PAUSE, 1)
    log("exit: game paused", tostring(okp and pok), tostring(paused))
    local ok, done, why = pcall(funcLuaCommand, C.EXIT, ms)
    log("exit: hold-to-leave", tostring(ok and done), tostring(why))
    return ok and done == true, why
  end

  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      local r = table.pack(init(...))
      pcall(record_root)
      return table.unpack(r, 1, r.n)
    end
  end
  local VH = VRFW_Host
  if M.stem ~= "?" and type(VH) == "table" and type(VH.on) == "function" then
    pcall(VH.on, M.stem, "OnInit", {id = "vr_framework.match_start_scene_root", phase = "around", fn = function(nxt, ...)
      local r = table.pack(nxt(...))
      pcall(record_root)
      return table.unpack(r, 1, r.n)
    end})
  end
end
