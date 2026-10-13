-- VRFW_MATCH: the match start service (VR-Framework 2.2.x, docs/framework/match-start.md). Starts a match straight
-- from the menu this VM runs (any hub of the menus: «Modos de juego», Estadio BB, Mercado…), the way the game's own
-- friendly / VS CPU start does it (the match engine's friendly executor VRFW_PACHANGA: team, the VS-CPU pre-match
-- sequence, CMND_RESERVE_SOCCER, the caller's menu closed), with no hop through the title or another menu, and comes
-- back to the SAME hub afterwards: a friendly declared with return = "menus" (no game reset; the soccer state's own way
-- reopens the hub with the in-memory game; friendly_way_back closes the friendly there, sink off, the hub's play mode
-- back). Any mod (Inazuma Fantasy's training field, Battle Bay, pachangas) calls it from its own menu code:
--
--   local ok, why = VRFW_MATCH.start{
--     friendly = "<friendly id>",       -- a [[friendly]] with return = "menus" (save = "sink" keeps the file untouched)
--     game = <soccer_game id>, difficulty = 1, stadium = <map crc> | nil, rival = <team> | nil,
--     set = <VS team set> | function() return <set>[, <friendly id>] end | nil,   -- a function is read after
--                                       -- play_mode is set; its second answer (a friendly id) replaces `friendly`
--                                       -- (e.g. the same match with another team policy, VRFW 2.2.34)
--     overrides = { {"teams.rival.players", 3}, … },   -- the match engine's next-match overrides (cleared first)
--     play_mode = 1 | nil,              -- the play mode the match runs in (the hub's comes back on the way back)
--     keep_menu = false,                -- true: the caller closes its own menus (on_reserved)
--     settle = 0,                       -- frames to wait first (a hub that just opened: its own init / messages)
--     black = true,                     -- false: no black screen from the request on; the friendly's own intro (its
--                                       -- `before = [{ op = "fade_encounter" }]`: the retail match-start transition of
--                                       -- the VS CPU list) covers the hub, as in the retail start (VRFW 2.2.34)
--     on_reserved = function() end, on_failed = function(why) end,
--   }
--
-- `start` answers at once (true = the launch runs from this menu's next Step: black at once unless `black = false`) or false +
-- why (no friendly executor in this menu, a launch already running). The launch steps log under «VRFW match_start»
-- with the frames they took (the hops: request -> reserved). Leaving a running match the retail way:
-- CMND_VRFW_MATCH_EXIT (VRFW_MATCH.exit()). Defines functions only: no engine call at load time.
VRFW_MATCH = VRFW_MATCH or {}
do
  local M = VRFW_MATCH
  local C = {
    LOG = 3661580131,          -- CMND_EVT_LOG
    CALLER = 1365773455,       -- CMND_VRFW_FRIENDLY_CALLER
    OVERRIDE = 3098579726,     -- CMND_VRFW_RULE_ENGINE_OVERRIDE
    EXIT = 746783004,          -- CMND_VRFW_MATCH_EXIT
    PAUSE = 4196529456,        -- CMND_VRFW_GAME_PAUSE([0 / 1]) -> ok, paused
    PLAY_MODE = 3718253404,    -- set play mode
    FADE = 609722083,          -- (on, seconds) screen fade to black
    CLOSE = 320421347,         -- CMND_CLOSE_MENU_OBJECT
    SE = 1917805374, SE_NO = 2086672038,
    MSG_BUSY = 898725220,      -- a message window is up
  }
  local script = type(EVT_PATCH) == "table" and EVT_PATCH.script or "?"
  M.stem = type(script) == "string" and (script:gsub("_%d+%.%d+%.%d+[%.%d]*$", "")) or "?"
  M.co, M.frames, M.wrapped, M.black = nil, 0, false, false

  local function log(...)
    pcall(funcLuaCommand, C.LOG, "VRFW match_start", tostring(M.stem), ...)
  end
  M.log = log

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
        if not spec.keep_menu and type(menu) == "number" and menu ~= 0 then
          pcall(funcLuaCommand, C.CLOSE, menu)     -- the caller's menu: the engine starts the match once it is gone
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

  local function tick()
    if M.co == nil then return end
    if M.black then
      pcall(funcLuaCommand, C.FADE, 1, 0)       -- over the hub's own fades: no menu frame before the match
    end
    M.frames = M.frames + 1
    local ok, err = coroutine.resume(M.co)
    if not ok then log("error", tostring(err)) end
    if not ok or coroutine.status(M.co) == "dead" then M.co = nil end
  end

  -- the launch from this menu (see the header). true, or false + why.
  function M.start(spec)
    if type(spec) ~= "table" or type(spec.friendly) ~= "string" then return false, "no friendly" end
    local P = VRFW_PACHANGA
    if type(P) ~= "table" or type(P.start) ~= "function" then
      log("refused: no friendly executor (VRFW_PACHANGA) in this menu")
      return false, "no executor"
    end
    if M.co ~= nil then return false, "busy" end
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
    if not M.wrapped and type(Step) == "function" then
      M.wrapped = true
      local step = Step
      Step = function(...)
        local r = table.pack(step(...))
        pcall(tick)
        return table.unpack(r, 1, r.n)
      end
    end
    log("requested", spec.friendly)
    return true
  end

  -- leave the running match the retail way (the hold-to-leave button; no game reset). true, or false + why.
  -- The retail hold («Finalizar partido», 0x1422430) counts only WHILE THE GAME IS PAUSED (its pause byte
  -- 0x22B0485): the game is paused here first and stays paused until the match ends (VRFW 2.2.45; the training field's
  -- «Reiniciar» / «Aplicar cambios» closed its window, which unpaused the game, and the hold never counted: black
  -- screen, music on, no restart).
  function M.exit(ms)
    local okp, pok, paused = pcall(funcLuaCommand, C.PAUSE, 1)
    log("exit: game paused", tostring(okp and pok), tostring(paused))
    local ok, done, why = pcall(funcLuaCommand, C.EXIT, ms)
    log("exit: hold-to-leave", tostring(ok and done), tostring(why))
    return ok and done == true, why
  end
end
