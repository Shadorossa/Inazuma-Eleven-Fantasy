-- EVT INAROGUE slot 4 (docs/game/modes/inarogue.md §13; inserted by research/scripts/inarogue_build.py).
-- INAROGUE has its own save, slot 4. From a normal slot, INAROGUE closes with result 4 and the title switches to slot
-- 4 with the loader's write-fenced switch. In slot 4 the title only runs INAROGUE: it reopens it by itself and keeps
-- the mode list inactive (the loader also refuses every mode request there). INAROGUE closes with 5 to go back to the
-- slot it was entered from, or 6 for the options screen.
-- Session entry (docs/game/engine/inarogue-no-game.md §9, [rogue] session_entry): the same results, but the INAROGUE
-- save is swapped into memory by the loader (CMND_EVT_RL_SESSION_BEGIN) and the normal game comes back from its memory
-- image (END): no GAME_RESET, no file load of the normal slot. Slot 4 still has to exist: the first entry of a new
-- profile creates it through the old switch. [rogue] session_debug: the INAROGUE button offers the §8.7 checklist.
-- Seamless session (inarogue-no-game.md §10): with session_entry on, the INAROGUE button swaps the INAROGUE save in
-- right there (BEGIN under the visible title, no close / fade / reload) and INAROGUE opens like any child menu; its
-- Back closes without a fade and the title swaps the normal game back (END) under itself. evt_ir_live = this title
-- instance has shown INAROGUE in a session, so it never forces black (a title rebuilt after the dock / a match still
-- stays black until INAROGUE is on screen, as a scene change).
local evt_ir_frames, evt_ir_busy, evt_ir_live = 0, false, false -- EVT INAROGUE
local EVT_IR = {
  KEY = 3558246415,
  ROGUE = 2087918688,        -- () -> rogueSlot, active, returnSlot, rogueHasGame
  RELOAD = 101778498,      -- (k) -> bool: map -> k, writes fenced
  ABORT = 2193346146,
  COMMIT = 3934119098,
  BUSY = 3324595690,
  INFO = 3258635583,          -- (k) -> exists, ...
  LOG = 3661580131,
  LAUNCH = 1235145496,   -- (op 0 read / 2 clear) -> pending: a match launch is in flight (§14)
  LAUNCH_FRAMES = 900,                      -- how long the title waits for the engine to take the reserved match
  MENU = 3874253475,                        -- title_menu_2
  ROGUE_MENU = 1301289148,
  ROGUE_LAYER = 4042532538,                 -- its mainmenu90_11_chronicle_top_list_item_middle (open = INAROGUE shown)
  IS_OPEN_MENU = 3693934564,                -- CMND_IS_OPEN_MENU_OBJECT (menu, layer)
  SS_MENU = 3561559540,       -- the "Ranuras de guardado" screen (research/test-mods/save_slots)
  SS_KEY = 2449975398,      -- its result: 0 cancel, 1..3 slot
  TITLE_REQUEST = 1151216011, OPTIONS = 1518731440, MY_TEAM = 1438851263,   -- MY_TEAM: "Mi equipo" (team dock)
  LOAD_HEADER = 4179471494, IS_SAVE_WORKING = 1979970074, LOAD_GAME_DATA = 2585060058, LOAD_FAILED = 3772572101,
  APPLY = 3660094710, HEADER_CLEAR = 3960538079, RESET_ALL = 1481565076, SKIP_PRESS_START = 937976662,
  GAME_RESET = 3897105282, GET_GFLAG = 941426960, SET_GFLAG = 3258400760, FLAG_AVATAR_DONE = 2113473044,
  FADE = 609722083, FADE_DONE = 2259183189, FADE_BUSY = 2736534827, PRE_RESET = 3015544382,
  CLOSE_MENU = 320421347, MENU_ACTIVE = 1558704558, CURSOR = 24113234, LAYER_VISIBLE = 711242136,
  MSG_OPEN = 2289627655, MSG_BUSY = 898725220, MSG_DONE = 682363669,
  T_BUSY = "El juego está guardando o cargando. Inténtalo de nuevo en unos segundos.",
  T_REFUSED = "No se ha podido cambiar de partida (mira loader.log).",
  T_LOAD_FAILED = "No se han podido cargar los datos. Se mantiene la partida actual.",
  -- the INAROGUE session (loader module rogue::session, inarogue-no-game.md §8-§9)
  SS_BEGIN = 105439923,       -- CMND_EVT_RL_SESSION_BEGIN (kind 0 INAROGUE / 1 test) -> ok, code, KiB, ms
  SS_END = 2582020426,        -- CMND_EVT_RL_SESSION_END (mode) -> closed, code, dirtyBlocks, ms
  SS_STATE = 3747521885,      -- CMND_EVT_RL_SESSION_STATE -> open, slot, discarded, KiB, armed, enabled, debug, swapped
  SS_RELOAD = 2787058999,     -- CMND_EVT_RL_SESSION_RELOAD -> ok, code
  SS_DISK = 2228654783,       -- CMND_EVT_RL_SESSION_DISK_CHECK -> ok, same, dirtyBlocks
  SS_ORPHAN = 885155932,      -- CMND_EVT_RL_SESSION_ORPHAN -> wasOpen, code
  RESTART = 1608527554,       -- CMND_EVT_SLOT_RESTART (k): the game restarts into slot k
  MSG_KIND = 2351835063, MSG_RESULT = 1523741473,
  TB_DEFER = 3408963264,      -- evt_top_bar_defer: a top-bar target waits for the overlay to close (its reset follows)
  -- this title instance was built while INAROGUE's game was the one in memory (a title rebuilt after «Plantilla de
  -- equipo» / a match inside the overlay): its banner (MI EQUIPO, NIVEL DEL EQUIPO, VICTORIAS) shows INAROGUE's game,
  -- so leaving the overlay rebuilds the title from the player's game (EVT_IR_MarkTitle, EVT_IR_AfterSession)
  title_in_session = false,
  T_SESSION_LOST = "No se ha podido recuperar tu partida en memoria.\nEl juego se reiniciará: tu partida guardada no ha cambiado.",
}

function EVT_IR_Call(cmd, ...) -- EVT INAROGUE
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

function EVT_IR_Log(...) -- EVT INAROGUE
  EVT_IR_Call(EVT_IR.LOG, "inarogue slot", ...)
end

-- () -> rogueSlot, active, returnSlot, rogueHasGame (nil without the loader)
function EVT_IR_Slots() -- EVT INAROGUE
  local rs, act, ret, has = EVT_IR_Call(EVT_IR.ROGUE)
  if type(rs) ~= "number" then
    return nil
  end
  return rs, act, ret, has == true
end

function EVT_IR_InRogueSlot() -- EVT INAROGUE
  local rs, act = EVT_IR_Slots()
  return rs ~= nil and act == rs
end

function EVT_IR_Message(text) -- EVT INAROGUE
  funcLuaCommand(EVT_IR.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  while funcLuaCommand(EVT_IR.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(EVT_IR.MSG_DONE) do
    coroutine.yield()
  end
end

function EVT_IR_WaitJob() -- EVT INAROGUE
  local k = 0
  coroutine.yield()
  while funcLuaCommand(EVT_IR.IS_SAVE_WORKING) do
    k = k + 1
    if k > 3600 then
      return false
    end
    coroutine.yield()
  end
  return true
end

-- The loader's write-fenced switch (as the EMPEZAR slot screen, save-slots.md §10.1), run from title_menu_2.
-- Returns false + message on failure (nothing changed); on success the title is reset and this never returns.
function EVT_IR_Switch(k) -- EVT INAROGUE
  -- the session (§9): leaving it = the normal game back from memory; entering slot 4 = the INAROGUE save swapped in
  local sopen, senabled, _, sswapped, sslot = EVT_IR_SessionState()
  if sopen == true and not sswapped then
    -- a session left open without INAROGUE's save in memory (an in-place entry whose rollback failed, a test session):
    -- the player's game comes back first (END: restore + verify, S5 when that fails); a slot switch is never mixed in
    EVT_IR_Log("session open without INAROGUE's save: closing it first")
    if not EVT_IR_SessionLeave() then
      EVT_IR_SessionLost(sslot)
      return false, EVT_IR.T_SESSION_LOST
    end
    if k == sslot then
      return "session"
    end
    sopen = false
  end
  if sopen == true and sswapped then
    if not EVT_IR_SessionLeave() then
      EVT_IR_SessionLost(sslot)
      return false, EVT_IR.T_SESSION_LOST
    end
    if k == sslot then
      return "session"
    end
    EVT_IR_Log("session left; now the switch to slot", k)
  elseif sopen ~= true and senabled then
    local rs, act = EVT_IR_Slots()
    if k == rs and act ~= rs then
      local ok, why = EVT_IR_SessionEnter()
      if ok then
        return "session"
      end
      if why ~= "no_game" then
        return false, why
      end
      EVT_IR_Log("session: slot 4 has no INAROGUE game yet: it is created through the slot switch")
    end
  end
  if EVT_IR_Call(EVT_IR.BUSY) == true then
    return false, EVT_IR.T_BUSY
  end
  local exists = EVT_IR_Call(EVT_IR.INFO, k) == true
  if EVT_IR_Call(EVT_IR.RELOAD, k) ~= true then
    EVT_IR_Log("reload refused", k)
    return false, EVT_IR.T_REFUSED
  end
  EVT_IR_Log("switch to slot", k, "has game", exists)
  funcLuaCommand(EVT_IR.FADE, 1, 0.25)       -- INAROGUE already faded to black before closing: this keeps it black
  coroutine.yield()
  local fk = 0                               -- bounded (§22: a fade that never reports done must not hang the switch)
  while not funcLuaCommand(EVT_IR.FADE_DONE) and fk < 240 do
    fk = fk + 1
    coroutine.yield()
  end
  while funcLuaCommand(EVT_IR.FADE_BUSY) and fk < 480 do
    fk = fk + 1
    coroutine.yield()
  end
  -- a target the loader found unreadable (deleted behind its card) is started as a new game, not loaded
  if exists and EVT_IR_Call(EVT_IR.INFO, k) ~= true then
    EVT_IR_Log("slot", k, "has no readable game any more: new game")
    exists = false
  end
  if exists then
    funcLuaCommand(EVT_IR.LOAD_HEADER)
    local ok = EVT_IR_WaitJob()
    local started = ok and funcLuaCommand(EVT_IR.LOAD_GAME_DATA, 1)
    ok = started and EVT_IR_WaitJob() and not funcLuaCommand(EVT_IR.LOAD_FAILED)
    if not ok then
      EVT_IR_Log("load failed", k)
      EVT_IR_Call(EVT_IR.ABORT)
      funcLuaCommand(EVT_IR.LOAD_HEADER)
      EVT_IR_WaitJob()
      funcLuaCommand(EVT_IR.FADE, 0, 0.3)
      return false, EVT_IR.T_LOAD_FAILED
    end
    funcLuaCommand(EVT_IR.APPLY)
  else
    -- empty slot 4 = a new game (the fresh-install flow of an empty slot, save-slots.md fixes 2026-09-24)
    funcLuaCommand(EVT_IR.HEADER_CLEAR)
    funcLuaCommand(EVT_IR.RESET_ALL)
    EVT_IR_Log("commit (new game)", EVT_IR_Call(EVT_IR.COMMIT) == true)
    -- slot 4: no retail first-run flow (avatar prompt, starter team A/B/C); the loader answers the title's first-run
    -- checks there, so the new INAROGUE game goes straight to the mode menu. A normal empty slot keeps the flow.
    local rs = EVT_IR_Slots()
    if k ~= rs then
      funcLuaCommand(EVT_IR.SET_GFLAG, EVT_IR.FLAG_AVATAR_DONE, false)
    end
  end
  local rs2 = EVT_IR_Slots()
  funcLuaCommand(EVT_IR.SKIP_PRESS_START, exists == true or k == rs2)
  EVT_IR_Log("game reset", k)
  funcLuaMenuCommand(EVT_IR.PRE_RESET)
  funcLuaCommand(EVT_IR.CLOSE_MENU, EVT_IR.MENU, true)
  funcLuaCommand(EVT_IR.GAME_RESET)
  while true do
    coroutine.yield()
  end
end

-- After INAROGUE closed (inside EVT_CustomItemCoroutine): true = the coroutine must end here (switch / request sent)
function EVT_IR_AfterMenu() -- EVT INAROGUE
  local r = funcLuaCommand(2947612279, EVT_IR.KEY) and funcLuaCommand(3522198769, EVT_IR.KEY) or 0
  funcLuaCommand(3363400568, EVT_IR.KEY)
  evt_ir_frames = 0
  if r == 4 or r == 5 then
    local rs, act, ret = EVT_IR_Slots()
    local target = r == 4 and rs or ret
    EVT_IR_Log("result", r, "rogue slot", rs, "active", act, "return", ret, "target", target)
    -- a session can be opened from any normal slot (slot 1 too): leaving it always goes back to that slot in memory
    if target ~= nil and (target >= 2 or (r == 5 and EVT_IR_InSession())) then
      evt_ir_busy = true
      local sw, why = EVT_IR_Switch(target)
      evt_ir_busy = false
      if sw == "session" then
        EVT_IR_AfterSession(r == 4)
      else
        EVT_IR_Message(why or EVT_IR.T_REFUSED)
      end
    end
  elseif r == 7 then
    -- out of slot 4 through the slot screen itself (never through a title): the retail-look "Ranuras de guardado"
    -- menu opens here; a slot picked there is loaded with the same fenced switch; cancel = back to INAROGUE
    EVT_IR_Log("slot screen from slot 4")
    -- evt_ir_busy while the slot screen is up: EVT_IR_AutoOpen (every Step) forces full black whenever INAROGUE is
    -- not open, which kept this screen invisible (black screen after «¿Volver a la selección de ranura?», log 28/09
    -- 11:11). Cleared before INAROGUE reopens on cancel, so its own open is still the single fade-in.
    evt_ir_busy = true
    funcLuaCommand(EVT_IR.FADE, 0, 0.3)       -- INAROGUE faded out before it closed: the slot screen fades in
    funcLuaCommand(3363400568, EVT_IR.SS_KEY)
    funcLuaCommand(433545986, EVT_IR.SS_MENU)
    coroutine.yield()
    coroutine.yield()
    while funcLuaMenuCommand(2231168902, EVT_IR.SS_MENU) do
      coroutine.yield()
    end
    evt_ir_busy = false
    local k = funcLuaCommand(2947612279, EVT_IR.SS_KEY) and funcLuaCommand(3522198769, EVT_IR.SS_KEY) or 0
    funcLuaCommand(3363400568, EVT_IR.SS_KEY)
    EVT_IR_Log("slot screen result", k)
    if type(k) == "number" and k >= 2 and k <= 3 then
      evt_ir_busy = true
      local sw, why = EVT_IR_Switch(k)
      evt_ir_busy = false
      if sw == "session" then
        EVT_IR_AfterSession(false)
      else
        EVT_IR_Message(why or EVT_IR.T_REFUSED)
      end
    end
  elseif r == 8 then
    -- INAROGUE reserved a match (CMND_RESERVE_SOCCER, docs/game/modes/inarogue.md §14) and closed: the engine takes
    -- the scene from here, as after the retail VS CPU menus. INAROGUE stays shut meanwhile (AutoOpen is blocked by
    -- evt_ir_busy). If the title is still alive after LAUNCH_FRAMES the match never started: INAROGUE reopens and
    -- finds the reserved match with no result, which the loader turns into "played again".
    EVT_IR_Log("match reserved: waiting for the engine to start it")
    evt_ir_busy = true
    for _ = 1, EVT_IR.LAUNCH_FRAMES do
      coroutine.yield()
    end
    evt_ir_busy = false
    EVT_IR_Call(EVT_IR.LAUNCH, 2)
    EVT_IR_Log("match did not start (title still alive): INAROGUE reopens, the node is played again")
    funcLuaCommand(EVT_IR.FADE, 0, 0.3)
  elseif r == 9 then
    -- INAROGUE's squad screen is the game's own "Plantilla de equipo" (docs/game/modes/inarogue.md §16): the same
    -- request as the title's "Mi equipo" banner; title_main reserves soccer_team_dock_menu. Its Back saves slot 4 and
    -- returns to this title, which reopens INAROGUE (the loader lets this one request through in slot 4).
    -- INAROGUE stays shut meanwhile (AutoOpen is blocked by evt_ir_busy); if the title is still alive after
    -- LAUNCH_FRAMES the dock never opened (request refused: an old loader): INAROGUE reopens and says so.
    n4 = EVT_IR.MY_TEAM
    local ok = EVT_IR_Call(EVT_IR.TITLE_REQUEST, n4)
    EVT_IR_Log("team dock request", tostring(ok))
    funcLuaMenuCommand(EVT_IR.MENU_ACTIVE, EVT_IR.MENU, false)
    evt_ir_busy = true
    for _ = 1, (ok == false) and 1 or EVT_IR.LAUNCH_FRAMES do
      coroutine.yield()
    end
    evt_ir_busy = false
    EVT_IR_Log("team dock did not open (title still alive): INAROGUE reopens")
    funcLuaCommand(EVT_IR.FADE, 0, 0.3)
  elseif r == 6 then
    EVT_IR_Log("options")
    n4 = EVT_IR.OPTIONS
    funcLuaCommand(EVT_IR.TITLE_REQUEST, n4)
    return true
  end
  return false
end

-- In slot 4 no title layer is visible (hidden when it opens and every 30 frames): the screen stays black until
-- INAROGUE opens over it, so nothing of the base game shows.
local EVT_IR_KEEP = {}   -- slot 4 shows nothing of the title, not even its background / logo (INAROGUE has its own)
local EVT_IR_LAYERS = {4256188210, 2003556732, 3123447765, 3180406576, 2250456639, 3873872512, 1538377437, 2361957585,
  4229432620, 3364711862, 3427392471, 3482980786, 93079401, 399128006, 304037738, 3993272514, 3572030395, 1904518656,
  2171787892, 715157494, 2921745639, 24113234, 4086303486, 1526508152, 1793860678, 2165713533, 4120942363, 3227484865,
  1990846078, 3535556105, 4039590028, 3664100856, 2284939060, 864205881}
function EVT_IR_HideLayer(layer) -- EVT INAROGUE
  if EVT_IR_KEEP[layer] then
    return
  end
  local n = funcLuaMenuCommand(1175615627, layer) or 0     -- CMND_GET_CREATE_LAYER_NUM
  for i = 0, math.max(n, 1) - 1 do
    funcLuaMenuCommand(EVT_IR.LAYER_VISIBLE, layer, i, false)
  end
end
function EVT_IR_HideTitle() -- EVT INAROGUE
  for _, layer in ipairs(EVT_IR_LAYERS) do
    EVT_IR_HideLayer(layer)
  end
end

-- Step(): in slot 4 the title only hosts INAROGUE: it opens at the first Step (the title's own start coroutines run
-- underneath with the list inactive and hidden); the hiding is repeated every 30 frames only (OnOpenLayer hides each
-- layer when it opens).
function EVT_IR_AutoOpen() -- EVT INAROGUE
  if evt_ir_busy or not EVT_IR_InRogueSlot() then
    return
  end
  funcLuaMenuCommand(EVT_IR.MENU_ACTIVE, EVT_IR.MENU, false)
  -- one continuous black from the switch until INAROGUE is on screen (it fades itself in once): no title frame, no
  -- second fade. Not in a seamless session this title instance opened / showed (§10): there the title is the backdrop.
  local in_session = EVT_IR_InSession()
  if not funcLuaCommand(EVT_IR.IS_OPEN_MENU, EVT_IR.ROGUE_MENU, EVT_IR.ROGUE_LAYER) then
    if not (in_session and evt_ir_live) then
      funcLuaCommand(EVT_IR.FADE, 1, 0)
    end
  elseif in_session then
    evt_ir_live = true
  end
  if evt_ir_frames % 30 == 0 and not in_session then
    EVT_IR_HideTitle()
  end
  evt_ir_frames = evt_ir_frames + 1
  if l1 ~= nil or l2 ~= nil or l3 ~= nil or l4 ~= nil then
    return
  end
  EVT_IR_Log("slot 4: opening INAROGUE")
  EVT_OnEnterCustomItem()
end

-- Base-game popups the title opens by itself (notices, tutorial pages, network invites) never run in slot 4.
-- ---- the INAROGUE session (docs/game/engine/inarogue-no-game.md §8-§9) --------------------------------------------
-- () -> open, enabled, debug, swapped, slot (nil without the loader's session module)
function EVT_IR_SessionState() -- EVT INAROGUE
  local open, slot, _, _, _, enabled, debug, swapped = EVT_IR_Call(EVT_IR.SS_STATE)
  if type(open) ~= "boolean" then
    return nil
  end
  return open, enabled == true, debug == true, swapped == true, slot
end

-- The INAROGUE save is the game in memory through a session (the title is not hidden then: black fade only, so it
-- comes back as it is when the session ends).
function EVT_IR_InSession() -- EVT INAROGUE
  local open, _, _, swapped = EVT_IR_SessionState()
  return open == true and swapped
end

-- S5: the normal slot read again from its file in place (no GAME_RESET), then END(3). The sink keeps the file clean.
function EVT_IR_SessionReload() -- EVT INAROGUE
  if EVT_IR_Call(EVT_IR.SS_RELOAD) ~= true then
    EVT_IR_Log("session: in-place reload refused")
    return false
  end
  funcLuaCommand(EVT_IR.LOAD_HEADER)
  local ok = EVT_IR_WaitJob()
  local started = ok and funcLuaCommand(EVT_IR.LOAD_GAME_DATA, 1)
  ok = started and EVT_IR_WaitJob() and not funcLuaCommand(EVT_IR.LOAD_FAILED)
  if not ok then
    EVT_IR_Log("session: in-place reload failed")
    return false
  end
  funcLuaCommand(EVT_IR.APPLY)
  local closed, code = EVT_IR_Call(EVT_IR.SS_END, 3)
  EVT_IR_Log("session: in-place reload done, end", tostring(closed), code)
  return closed == true
end

-- Enter: the normal game kept as an image, the INAROGUE save loaded in its place. false, "no_game" = slot 4 is empty.
function EVT_IR_SessionEnter() -- EVT INAROGUE
  local ok, code, kib, ms = EVT_IR_Call(EVT_IR.SS_BEGIN, 0)
  EVT_IR_Log("session begin", tostring(ok), code, kib, ms)
  if ok == true then
    local rs, act, ret = EVT_IR_Slots()
    EVT_IR_Log("enter: player slot", ret, "-> INAROGUE slot", rs, "(active", act, ", overlay)")
    return true
  end
  if code == 12 then
    return false, "no_game"
  end
  if code == 7 and EVT_IR_SessionState() == true then
    -- the INAROGUE game did not load and the normal game could not be put back from memory: read it again
    if not EVT_IR_SessionReload() then
      local _, _, _, _, slot = EVT_IR_SessionState()
      EVT_IR_SessionLost(slot)
      return false, EVT_IR.T_SESSION_LOST
    end
  end
  return false, EVT_IR.T_REFUSED
end

-- Leave: INAROGUE's game kept in memory for the next entry, the normal game back from its image (S5 when that fails).
function EVT_IR_SessionLeave() -- EVT INAROGUE
  local closed, code, dirty, ms = EVT_IR_Call(EVT_IR.SS_END, 0)
  EVT_IR_Log("session end", tostring(closed), code, dirty, ms)
  if closed == true then
    return true
  end
  if code == 7 or code == 8 or code == 9 then
    return EVT_IR_SessionReload()
  end
  return false
end

-- Nothing brought the normal game back: its file is intact (sink), so the game restarts into it.
function EVT_IR_SessionLost(slot) -- EVT INAROGUE
  EVT_IR_Log("session lost: restart into slot", slot)
  EVT_IR_Message(EVT_IR.T_SESSION_LOST)
  if type(slot) == "number" and slot >= 2 then
    EVT_IR_Call(EVT_IR.RESTART, slot)
  end
end

-- After a session switch: entering = INAROGUE opens by itself (EVT_IR_AutoOpen, black meanwhile); leaving = the title
-- fades in with its mode list (it was never hidden during the session).
function EVT_IR_AfterSession(entered) -- EVT INAROGUE
  evt_ir_frames = 0
  if not entered then
    evt_ir_live = false
    local rs, act, ret = EVT_IR_Slots()
    EVT_IR_Log("exit: INAROGUE slot", rs, "-> player slot", act, "(return", ret, ") title built in the overlay",
      tostring(EVT_IR.title_in_session))
    if EVT_IR.title_in_session then
      -- Nacho 07/10: back from INAROGUE the title still showed INAROGUE's team / level / wins as if slot 4 were
      -- loaded. The game in memory is the player's again (END restored it), but this title was drawn from
      -- INAROGUE's game: rebuild it from the player's game (no file load: GAME_RESET keeps the game in memory)
      if funcLuaCommand(2947612279, EVT_IR.TB_DEFER) == true then
        EVT_IR_Log("exit: a top-bar target is waiting: its own reset rebuilds the title")
        return
      end
      EVT_IR_RebuildTitle()
      return
    end
    -- after a faded close this fades the title in; after a seamless close (§10) the screen is clear and this is the
    -- same no-op fade-in INAROGUE's own OnOpenLayer runs on every open from the normal title
    funcLuaCommand(EVT_IR.FADE, 0, 0.3)
  end
end

-- OnInit of every title instance: remember whether it is built over INAROGUE's game (the overlay is open)
function EVT_IR_MarkTitle() -- EVT INAROGUE
  EVT_IR.title_in_session = EVT_IR_InSession() == true
  if EVT_IR.title_in_session then
    local rs, act, ret = EVT_IR_Slots()
    EVT_IR_Log("title built in the overlay: INAROGUE slot", rs, "active", act, "player slot", ret)
  end
end

-- The title rebuilt from the game in memory (the player's, after END): the same reset as the slot switch, without
-- any load. Never returns (the title is closed and the game resets into a new title).
function EVT_IR_RebuildTitle() -- EVT INAROGUE
  EVT_IR_Log("exit: the title was drawn from INAROGUE's game: rebuilt from the player's game (GAME_RESET, no load)")
  funcLuaCommand(EVT_IR.FADE, 1, 0.25)
  coroutine.yield()
  local fk = 0                               -- bounded, as in EVT_IR_Switch
  while not funcLuaCommand(EVT_IR.FADE_DONE) and fk < 240 do
    fk = fk + 1
    coroutine.yield()
  end
  fk = 0
  while funcLuaCommand(EVT_IR.IS_SAVE_WORKING) and fk < 600 do
    fk = fk + 1
    coroutine.yield()
  end
  funcLuaCommand(EVT_IR.SKIP_PRESS_START, true)
  funcLuaMenuCommand(EVT_IR.PRE_RESET)
  funcLuaCommand(EVT_IR.CLOSE_MENU, EVT_IR.MENU, true)
  funcLuaCommand(EVT_IR.GAME_RESET)
  while true do
    coroutine.yield()
  end
end

-- §10 seamless entry, on the INAROGUE button (inside EVT_CustomItemCoroutine, before the menu opens): with
-- [rogue] session_entry on and an INAROGUE game in slot 4, BEGIN(0) swaps it in under the visible title; INAROGUE then
-- opens as the normal child menu, already in its slot-4 mode. No fade, no close / reopen, no file load of the normal
-- slot, no GAME_RESET. Anything else (switch off, slot 4 empty, refused) leaves things as they were: INAROGUE opens in
-- the normal slot and its «Entrar» keeps the old path (which creates slot 4 once).
function EVT_IR_SeamlessEnter() -- EVT INAROGUE
  local open, enabled = EVT_IR_SessionState()
  if open ~= false or not enabled then
    return false
  end
  local rs, act, _, has = EVT_IR_Slots()
  if rs == nil or act == rs or not has then
    return false
  end
  -- the title saves when it is reached: BEGIN is refused while that job runs (code 2), so wait for it (bounded)
  if funcLuaCommand(EVT_IR.IS_SAVE_WORKING) and not EVT_IR_WaitJob() then
    EVT_IR_Log("seamless entry: a save / load job never ended: INAROGUE opens in the normal slot")
    return false
  end
  local ok, why = EVT_IR_SessionEnter()
  EVT_IR_Log("seamless entry", tostring(ok), tostring(why))
  if ok then
    evt_ir_live = true
    evt_ir_frames = 0
    return true
  end
  if why ~= nil and why ~= "no_game" and why ~= EVT_IR.T_REFUSED then
    EVT_IR_Message(why)   -- the session was lost and the game restarts into the normal slot
  end
  return false
end

function EVT_IR_Ask(text) -- EVT INAROGUE
  funcLuaCommand(EVT_IR.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(EVT_IR.MSG_KIND, 2, 0)
  coroutine.yield()
  local r = -1
  while r == nil or r < 0 do
    r = funcLuaCommand(EVT_IR.MSG_RESULT)
    coroutine.yield()
  end
  while not funcLuaCommand(EVT_IR.MSG_DONE) do
    coroutine.yield()
  end
  return r == 0
end

-- [rogue] session_debug: the in-game checklist of inarogue-no-game.md §8.7 on the INAROGUE button, title only. A TEST
-- session (kind 1) keeps the normal game loaded: image + sink only. true = handled (INAROGUE does not open).
function EVT_IR_SessionDebug() -- EVT INAROGUE
  local open, _, debug, swapped = EVT_IR_SessionState()
  if debug ~= true or EVT_IR_InRogueSlot() then
    return false
  end
  local function say(...)
    local t = {}
    for i = 1, select("#", ...) do
      t[#t + 1] = tostring((select(i, ...)))
    end
    EVT_IR_Log("session checklist", table.concat(t, " "))
    EVT_IR_Message(table.concat(t, " "))
  end
  if open ~= true then
    if not EVT_IR_Ask("[Prueba de sesión, §8.7]\n¿Abrir la lista de pruebas? (No = abrir INAROGUE)") then
      return false
    end
    if EVT_IR_Ask("1. BEGIN de prueba: imagen de la partida + sumidero (la partida sigue cargada).\n¿Empezar?") then
      local ok, code, kib, ms = EVT_IR_Call(EVT_IR.SS_BEGIN, 1)
      say("BEGIN: ok", ok, "código", code, "|", kib, "KiB |", ms, "ms")
      if ok == true and EVT_IR_Ask("2. DISK_CHECK: ¿el fichero es igual a la imagen?") then
        local r, same, n = EVT_IR_Call(EVT_IR.SS_DISK)
        say("DISK_CHECK: leído", r, "| igual", same, "| bloques distintos", n)
      end
      if ok == true then
        say("3. Ahora guarda en modos del juego (Mi equipo, un partido VS, la tienda): cada guardado se descarta.\n" ..
            "Después vuelve al título y pulsa Inarogue otra vez.")
      end
    elseif EVT_IR_Ask("9. ORPHAN: ¿abrir una sesión de prueba y cerrarla como huérfana?") then
      local ok = EVT_IR_Call(EVT_IR.SS_BEGIN, 1)
      local was, code = EVT_IR_Call(EVT_IR.SS_ORPHAN)
      say("ORPHAN: begin", ok, "| abierta", was, "| código", code)
    end
    return true
  end
  if swapped then
    say("Hay una sesión de INAROGUE abierta: sal de INAROGUE primero.")
    return true
  end
  if EVT_IR_Ask("4. END(2): lista en loader.log lo que cambió, sin restaurar.\n¿Hacerlo?") then
    local closed, code, n, ms = EVT_IR_Call(EVT_IR.SS_END, 2)
    say("END(2): cerrada", closed, "| código", code, "| bloques distintos", n, "|", ms, "ms")
    if closed == true then
      return true
    end
  end
  if EVT_IR_Ask("5. END(0): restaurar la imagen y verificar.\n(No = paso 7: recargar la ranura desde el fichero)") then
    local closed, code, n, ms = EVT_IR_Call(EVT_IR.SS_END, 0)
    say("END(0): cerrada", closed, "| código", code, "| bloques distintos", n, "|", ms, "ms\n" ..
        "6. Comprueba la plantilla / monedas / objeto, guarda normal y reinicia el juego.")
  elseif EVT_IR_Ask("7. Recarga en el sitio (S5, sin GAME_RESET).\n¿Hacerlo?") then
    say("S5: cerrada", EVT_IR_SessionReload())
  end
  return true
end

function EVT_IR_BlockInRogueSlot(name) -- EVT INAROGUE
  local orig = _ENV[name]
  if type(orig) ~= "function" then
    return
  end
  _ENV[name] = function(...)
    if EVT_IR_InRogueSlot() then
      return
    end
    return orig(...)
  end
end
