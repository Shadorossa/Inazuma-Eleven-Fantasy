-- menu_engine: the TEAM EDITOR service. Definitions only: this file runs in every menu VM (lua\_all) after the retail
-- chunk; no engine call at load time.
--
-- Opens the game's own team dock (soccer_team_dock_menu, «Plantilla de equipo») for a team that is not one of the
-- player's docks (a league team, a tournament team, any team a mode keeps as data) and hands back the order the
-- player left there. The player's save is never changed:
--   1. a framework session of kind «test» starts (CMND_VRFW_SESSION_BEGIN kind 1): the whole game is kept as an image
--      in memory and every save write of the slot is discarded until the session ends (a crash or a quit inside the
--      dock leaves the slot's file as it was);
--   2. the team dock in use (CMND_GET_VS_USE_TEAM_SET) is emptied and filled with one temporary club player per
--      member of the given team (CMND_ADD_PARTY), placed with the retail place pair, with the team's formation, name
--      and emblem; with spec.foreign also its coach, kit, tactics and synergies (none given = none shown);
--   3. the dock opens over the caller's menu (hidden while it is up, as soccer_top_menu does for its own dock); with
--      spec.foreign the dock runs in its foreign team mode (soccer_team_dock_menu\130_foreign_team.lua): nothing that
--      reads or writes the player's own team docks is offered;
--   4. when it closes, the positions of the temporary players and the formation are read;
--   5. the session ends with restore + verification (CMND_VRFW_SESSION_END 0): the game image of step 1 is loaded
--      back, so the temporary players, the emptied dock and anything else changed inside the dock are gone. A failed
--      restore runs the framework's in-place reload of the slot's own (untouched) file (RELOAD, LOAD_HEADER,
--      LOAD_GAME_DATA, APPLY, END 3).
-- The caller stores the result in its own data and writes it to its team before its matches.
--
--   VRFW_TeamEditor.CanOpen()        -> true, or false + why (a session already open, the slot service off)
--   VRFW_TeamEditor.Run(spec)        -> result, or nil + why. Call it from a menu coroutine (it yields until the
--                                       dock closes).
--   VRFW_TeamEditor.Foreign()        -> nil, or { stadium = map, rows = { [kind] = true } } while a foreign team's dock
--                                       is open (any menu VM)
--   VRFW_TeamEditor.GuardSwap(nxt, ...) -> SwapChara run so that only the team's own players swap (foreign mode)
--   VRFW_TeamEditor.ViewOnly(spec)  -> a screen opened from a foreign team's dock stays view only (patch file, at load)
--   spec = {
--     owner = "<mod id>",            -- the mod that asks (the session's owner, its journal)
--     host = <menu id>,              -- the menu the dock opens over
--     members = { {slot, param}, ... },  -- 0-10 starters in formation order, 11-18 bench (chara_param ids)
--     formation = <formation_config id>, level = <level of the temporary players>, name = "<team name>",
--     emblem = <emblem item id>,     -- 0 / nil = the dock's own (foreign: none)
--     foreign = true,                -- a team that is not one of the player's: the whole team record below, and the
--                                    -- dock's foreign team mode (no bank, no team switching, no active team)
--     coach = <chara_param id>,      -- foreign: the team's coach (dock position 19)
--     kit = <uniform item id>,       -- foreign: the team's kit
--     tactics = { id, id, id },      -- foreign: the team's special tactics (the 3 «TÁCTICAS» slots)
--     synergies = { flag, pillar },  -- foreign: the team's synergy items
--     stadium = <map id>,            -- foreign: the team's own stadium (VRFW_TeamEditor.Foreign() for the dock's add-ons)
--     rows = { kind, ... },          -- foreign: the dock list rows offered (VRFW_TeamEditor.ROW; default { ROW.LINEUP });
--                                    -- they open on the dock's team, view only
--     own = true,                    -- the player's own team: the dock opens as it is (no session, no copy, no result)
--   }
--   result = { formation = id, members = { {position, param}, ... } (dock positions 0-18 of the team's players),
--              foreign = n (positions holding a player of the club, not of the team), opened = true }
if VRFW_TeamEditor == nil then
  local E = {
    C = {
      SESSION_BEGIN = VRFW_Cmd.VRFW_SESSION_BEGIN,    -- CMND_VRFW_SESSION_BEGIN (mod, storageSlot, kind) -> ok, code, imageKiB, ms
      SESSION_END = VRFW_Cmd.VRFW_SESSION_END,      -- CMND_VRFW_SESSION_END (mode) -> closed, code, dirtyBlocks, ms
      SESSION_STATE = VRFW_Cmd.VRFW_SESSION_STATE,     -- CMND_VRFW_SESSION_STATE -> open, slot, discardedWrites, ...
      SESSION_RELOAD = VRFW_Cmd.VRFW_SESSION_RELOAD,   -- CMND_VRFW_SESSION_RELOAD -> ok, code
      LOAD_HEADER = 4179471494, IS_SAVE_WORKING = 1979970074, LOAD_GAME_DATA = 2585060058,
      LOAD_FAILED = 3772572101, APPLY = 3660094710,
      ADD_PARTY = VRFW_Cmd.ADD_PARTY,        -- CMND_ADD_PARTY
      VS_DOCK = VRFW_Cmd.GET_VS_USE_TEAM_SET,          -- CMND_GET_VS_USE_TEAM_SET
      PLACE_CHECK = 1730898405,      -- (handle, set, position, fromSet, team) -> ok, code (retail SwapChara check)
      PLACE = 193693077,             -- (toSet, position, fromSet, handle, team); set 16 = the club bank
      POSITION_INDEX = 1721292418,   -- (set, team, position) -> ok, member index
      INDEX_HANDLE = 1720957768,     -- (set, team, index, 0) -> ok, handle
      TEAM_GET = VRFW_Cmd.GET_TEAM_SET_INFO,         -- CMND_GET_TEAM_SET_INFO (set, team, field[, slot]) -> ok, value (4 formation,
                                     -- 7 kit, 9 tactic of a slot)
      TEAM_SET = VRFW_Cmd.SET_TEAM_SET_INFO,         -- CMND_SET_TEAM_SET_INFO (set, team, field, value[, slot]): 0 name, 1 emblem,
                                     -- 3 formation, 4 tactic (id, slot 0-2), 5 kit (uniform item), 7 kit off (0),
                                     -- 9 synergy (item, slot 0 flag / 1 pillar)
      ITEM_COUNT = VRFW_Cmd.GET_ITEM_NUM,       -- CMND_GET_ITEM_NUM (item) -> count
      ITEM_ADD = VRFW_Cmd.ADD_ITEM_ONLY,         -- CMND_ADD_ITEM_ONLY (item, count)
      OPEN_MENU = VRFW_Cmd.OPEN_MENU_OBJECT,         -- CMND_OPEN_MENU_OBJECT
      -- menu commands (funcLuaMenuCommand, as the retail menus call them)
      MENU_EXISTS = VRFW_Cmd.IS_EXIST_MENU_OBJECT,      -- CMND_IS_EXIST_MENU_OBJECT (menu) -> exists
      MENU_INPUT = 1558704558,       -- (menu, on): the menu's input
      MENU_SUSPEND = 369172623,      -- (menu): the menu's layer groups suspended (retail soccer_top_menu, before its dock)
      MENU_RESUME = 66378409,        -- (menu): the same back
      CALL_IN_MENU = 830228314,      -- (menu, "global function", ...)
      SOUND = VRFW_Cmd.SND_PLAY_SE,            -- (sound)
      TEAM_SET_KIT = VRFW_Cmd.VRFW_TEAM_SET_KIT,     -- CMND_VRFW_TEAM_SET_KIT (set, team, uniform) -> ok, uniform now (TeamInfo +0x290,
                                     -- the kit every consumer reads; scripts	eam_editor.lua)
      LOG = VRFW_Cmd.EVT_LOG,              -- CMND_EVT_LOG
    },
    DOCK = 937147172,                -- soccer_team_dock_menu
    TOP = 811496143,                 -- soccer_top_menu (its common background is hidden under the dock, as retail)
    BANK = 16,
    LAST_POSITION = 18,              -- 0-10 starters, 11-15 bench, 16-18 support
    SE_NO = 2086672038,              -- sy0003 (refused)
    COACH_POSITION = 19,             -- the coach (foreign: the team's own, else left as it is)
    TACTIC_SLOTS = 3, SYNERGY_SLOTS = 2,
    -- cross-menu parameters of the foreign team mode (crc32 of the names), written while its dock is open
    FOREIGN_KEY = 4265785820,        -- VRFW_team_editor_foreign
    STADIUM_HIGH_KEY = 3441793561,   -- VRFW_team_editor_stadium_high (upper 16 bits of the map id)
    STADIUM_LOW_KEY = 2970805637,    -- VRFW_team_editor_stadium_low
    ROWS_KEY = 3645648100,           -- VRFW_team_editor_rows (bit k = dock list row kind k offered)
    -- the dock list's row kinds a caller may offer for a foreign team (spec.rows): they open on the dock's team
    ROW = { LINEUP = 0, BONDS = 2, HYPER_COMMANDS = 9 },
    KIND_TEST = 1,                   -- session kind: image + discarded saves only
    END_RESTORE = 0, END_RELOADED = 3,
    FORMATION = 935586083,           -- team_dock_formation_menu (the dock's own child)
    OPEN_WAIT = 300,                 -- frames for the dock to come up
    JOB_WAIT = 600,                  -- frames for a load job of the in-place reload
  }

  local function Log(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(i, ...)))
    end
    pcall(funcLuaCommand, E.C.LOG, "VRFW team editor", table.concat(parts, " "))
  end

  local function Call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  -- a menu command (the retail menus' channel), nil when it failed
  local function MenuCall(cmd, ...)
    local r = table.pack(pcall(funcLuaMenuCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  local function Exists(menu)
    return MenuCall(E.C.MENU_EXISTS, menu) == true
  end

  local function Int(v)
    return type(v) == "number" and math.floor(v) or 0
  end

  local function Wait(frames)
    for _ = 1, frames do
      coroutine.yield()
    end
  end

  -- the handle at a dock position (0 = empty)
  local function HandleAt(set, team, position)
    local ok, index = Call(E.C.POSITION_INDEX, set, team, position)
    if ok ~= true or type(index) ~= "number" then
      return 0
    end
    local ok2, handle = Call(E.C.INDEX_HANDLE, set, team, index, 0)
    return (ok2 == true and type(handle) == "number") and handle or 0
  end

  -- the retail place: the check, then the place; true when the player is at `position` now
  local function Place(handle, set, position)
    local ok, code = Call(E.C.PLACE_CHECK, handle, set, position, E.BANK, 0)
    if ok ~= true then
      Log("place refused by the retail check: position", position, "code", tostring(code))
      return false
    end
    Call(E.C.PLACE, set, position, E.BANK, handle, 0)
    return HandleAt(set, 0, position) == handle
  end

  -- every player of both teams of the dock (11v11 and 5v5) back to the club bank; -> players left in the 11v11 team
  local function Empty(set)
    for team = 0, 1 do
      for position = 0, E.LAST_POSITION do
        local handle = HandleAt(set, team, position)
        if handle ~= 0 then
          Call(E.C.PLACE, E.BANK, position, set, handle, team)
        end
      end
    end
    local left = 0
    for position = 0, E.LAST_POSITION do
      if HandleAt(set, 0, position) ~= 0 then
        left = left + 1
      end
    end
    return left
  end

  local function WaitJob()
    coroutine.yield()
    local k = 0
    while Call(E.C.IS_SAVE_WORKING) == true do
      k = k + 1
      if k > E.JOB_WAIT then
        return false
      end
      coroutine.yield()
    end
    return true
  end

  -- the session closed: restore + verification, else the slot read again from its own file in place
  local function EndSession()
    local closed, code, dirty = Call(E.C.SESSION_END, E.END_RESTORE)
    if closed == true then
      Log("session closed: the game is the one before the dock (restored and verified)")
      return true
    end
    Log("session END refused (code", tostring(code), "dirty blocks", tostring(dirty), "): in-place reload of the slot's file")
    if Call(E.C.SESSION_RELOAD) ~= true then
      Log("in-place reload refused: saves stay discarded until the game goes back to the title")
      return false
    end
    Call(E.C.LOAD_HEADER)
    local ok = WaitJob()
    ok = ok and Call(E.C.LOAD_GAME_DATA, 1) and WaitJob() and Call(E.C.LOAD_FAILED) ~= true
    if not ok then
      Log("in-place reload failed: saves stay discarded until the game goes back to the title")
      return false
    end
    Call(E.C.APPLY)
    local reloaded, code2 = Call(E.C.SESSION_END, E.END_RELOADED)
    Log("in-place reload done, session closed", tostring(reloaded), tostring(code2))
    return reloaded == true
  end

  -- the dock over `host` until it is fully gone (it and its formation screen); false when it never came up. The host
  -- is suspended and its input off while the dock is up, as soccer_top_menu does for its own dock; the caller hides
  -- the host's own layers it does not want under the dock (the dock writes its button guide on its parent's layer).
  local function ShowDock(host)
    local top = Exists(E.TOP)
    if host then
      MenuCall(E.C.MENU_INPUT, host, false)
      MenuCall(E.C.MENU_SUSPEND, host)
    end
    if top then
      Call(E.C.CALL_IN_MENU, E.TOP, "SetDisplaySoccerTopCommonBgImage", false)
    end
    Call(E.C.OPEN_MENU, E.DOCK)
    local f = 0
    while not Exists(E.DOCK) and f < E.OPEN_WAIT do
      f = f + 1
      coroutine.yield()
    end
    local opened = Exists(E.DOCK)
    if opened then
      Log("team dock open after", f, "frame(s)")
    else
      Log("the team dock did not open in", E.OPEN_WAIT, "frames")
    end
    -- never go on (read, restore the game) while the dock or its formation screen still exists
    while Exists(E.DOCK) or Exists(E.FORMATION) do
      coroutine.yield()
    end
    Wait(10)
    if opened then
      Log("team dock closed")
    end
    if top then
      Call(E.C.CALL_IN_MENU, E.TOP, "SetDisplaySoccerTopCommonBgImage", true)
    end
    if host then
      MenuCall(E.C.MENU_RESUME, host)
      coroutine.yield()
      MenuCall(E.C.MENU_INPUT, host, true)
    end
    return opened
  end

  function E.CanOpen()
    local open = Call(E.C.SESSION_STATE)
    if open == nil then
      return false, "the framework's save sessions are off"
    end
    if open == true then
      return false, "a save session is already open"
    end
    return true
  end

  -- an item the dock's team record points at, held in the bag (the retail scripts add a kit / emblem before they set
  -- it: AddItemNoCount + CMND_SET_TEAM_SET_INFO); inside the session, so the bag is put back when it ends
  local function Hold(item)
    if Int(Call(E.C.ITEM_COUNT, item)) < 1 then
      Call(E.C.ITEM_ADD, item, 1)
    end
  end

  -- the team's coach at dock position 19 instead of the club's (the club's goes to the bank only once the team's is
  -- made; it comes back when the team's cannot be placed)
  local function PlaceCoach(set, coach, level)
    local old = HandleAt(set, 0, E.COACH_POSITION)
    local handle = Call(E.C.ADD_PARTY, coach, level, false, false, 0, 0, false, false, false, E.BANK, 255, 255, 0,
      false, false, false, 0, false, false)
    if type(handle) ~= "number" or handle == 0 then
      Log("coach card", coach, "not created")
      return false
    end
    if old ~= 0 then
      Call(E.C.PLACE, E.BANK, E.COACH_POSITION, set, old, 0)
    end
    if Place(handle, set, E.COACH_POSITION) then
      Log("coach card", coach, "-> temporary coach", handle)
      return true
    end
    Log("coach card", coach, "not placed")
    if old ~= 0 then
      Place(old, set, E.COACH_POSITION)
    end
    return false
  end

  -- a foreign team's record in the dock: coach, emblem, kit, tactics and synergies; what the spec does not give is
  -- left empty (nothing of the player's own team stays on screen)
  local function FillRecord(set, spec, level)
    if Int(spec.coach) ~= 0 then
      PlaceCoach(set, Int(spec.coach), level)
    else
      Log("no coach given: the dock keeps its coach")
    end
    local emblem = Int(spec.emblem)
    if emblem ~= 0 then
      Hold(emblem)
    end
    Call(E.C.TEAM_SET, set, 0, 1, emblem)
    local kit = Int(spec.kit)
    if kit ~= 0 then
      -- the retail field 5 write never reached the set's kit (TeamInfo +0x290): the framework's command writes it and
      -- clears the owned kit item the dock's icon reads first
      for team = 0, 1 do
        local okk, now = Call(E.C.TEAM_SET_KIT, set, team, kit)
        if okk ~= true then
          Log("kit of team", team, "not written (now", tostring(now), ")")
        end
      end
    else
      Call(E.C.TEAM_SET, set, 0, 7, 0)
    end
    local okk, shown = Call(E.C.TEAM_GET, set, 0, 7)
    Log("kit", kit, "-> dock kit", okk == true and tostring(shown) or "unread", "; emblem", emblem)
    local tactics = type(spec.tactics) == "table" and spec.tactics or {}
    for slot = 0, E.TACTIC_SLOTS - 1 do
      local id = Int(tactics[slot + 1])
      Call(E.C.TEAM_SET, set, 0, 4, id, slot)
      local okt, now = Call(E.C.TEAM_GET, set, 0, 9, slot)
      Log("tactic slot", slot, id, "-> dock", okt == true and tostring(now) or "unread")
    end
    local synergies = type(spec.synergies) == "table" and spec.synergies or {}
    for slot = 0, E.SYNERGY_SLOTS - 1 do
      Call(E.C.TEAM_SET, set, 0, 9, Int(synergies[slot + 1]), slot)
    end
  end

  -- the temporary copy of the team in the dock: { handle -> param }, or nil + why
  local function Fill(set, spec)
    local left = Empty(set)
    if left > 0 then
      return nil, left .. " player(s) of the dock could not be moved to the bank"
    end
    local made, created, placed, starters = {}, 0, 0, 0
    local level = math.max(1, Int(spec.level))
    for _, m in ipairs(spec.members or {}) do
      local slot, param = Int(m[1]), Int(m[2])
      if slot >= 0 and slot <= E.LAST_POSITION and param ~= 0 then
        local handle = Call(E.C.ADD_PARTY, param, level, false, false, 0, 0, false, false, false, E.BANK, 255, 255, 0,
          false, false, false, 0, false, false)
        if type(handle) == "number" and handle ~= 0 then
          made[handle] = param
          created = created + 1
          Log("slot", slot, "card", param, "-> temporary player", handle)
          if Place(handle, set, slot) then
            placed = placed + 1
            if slot <= 10 then
              starters = starters + 1
            end
          else
            Log("slot", slot, "card", param, "not placed")
          end
        else
          Log("slot", slot, "card", param, "not created")
        end
        if created % 6 == 5 then
          coroutine.yield()
        end
      end
    end
    if starters < 11 then
      return nil, "only " .. starters .. " starters placed"
    end
    if Int(spec.formation) ~= 0 then
      Call(E.C.TEAM_SET, set, 0, 3, Int(spec.formation))
    end
    if type(spec.name) == "string" and spec.name ~= "" then
      Call(E.C.TEAM_SET, set, 0, 0, spec.name)
    end
    if spec.foreign then
      FillRecord(set, spec, level)
    elseif Int(spec.emblem) ~= 0 then
      Call(E.C.TEAM_SET, set, 0, 1, Int(spec.emblem))
    end
    Log("dock", set, "holds the team:", placed, "players placed")
    return made
  end

  -- the order left in the dock
  local function Read(set, made)
    local out = { members = {}, foreign = 0 }
    for position = 0, E.LAST_POSITION do
      local handle = HandleAt(set, 0, position)
      if handle ~= 0 then
        if made[handle] then
          out.members[#out.members + 1] = { position, made[handle] }
          Log("read: position", position, "temporary player", handle, "-> card", made[handle])
        else
          out.foreign = out.foreign + 1
          Log("read: position", position, "club player", handle, "(not of the team)")
        end
      end
    end
    local ok, formation = Call(E.C.TEAM_GET, set, 0, 4)
    out.formation = (ok == true and type(formation) == "number") and formation or 0
    return out
  end

  -- the foreign team mode's cross-menu parameters (the dock runs in its own menu VM): on while the dock is up
  local function SetForeign(spec)
    for _, key in ipairs({ E.FOREIGN_KEY, E.STADIUM_HIGH_KEY, E.STADIUM_LOW_KEY, E.ROWS_KEY }) do
      if VRFW_Param.Has(key) then
        VRFW_Param.Clear(key)
      end
    end
    if not spec then
      return
    end
    local stadium = Int(spec.stadium) % 4294967296
    VRFW_Param.Set(E.STADIUM_HIGH_KEY, math.floor(stadium / 65536))
    VRFW_Param.Set(E.STADIUM_LOW_KEY, stadium % 65536)
    local mask = 0
    for _, kind in ipairs(type(spec.rows) == "table" and spec.rows or { E.ROW.LINEUP }) do
      kind = Int(kind)
      if kind >= 0 and kind < 30 and math.floor(mask / 2 ^ kind) % 2 == 0 then
        mask = mask + 2 ^ kind
      end
    end
    VRFW_Param.Set(E.ROWS_KEY, mask)
    VRFW_Param.Set(E.FOREIGN_KEY, 1)
  end

  -- Foreign team mode: a swap in the dock or its lineup screen only among the team's own players (the copy holds all
  -- of them in dock positions 0-18). Runs the retail SwapChara (`nxt`) with its place checks answered «refused» for a
  -- player that comes from another set (the club bank, another dock): the retail code then cancels the swap itself.
  local SWAP_CHECKS = {
    [1730898405] = true,             -- (handle, toSet, position, fromSet, team) -> ok, code (retail SwapChara check)
    [99793139] = true,               -- the same check of the other swap kind
  }
  -- A screen opened from a foreign team's dock that must stay VIEW ONLY (its data is the throwaway copy): called from
  -- the screen's own patch file at load (no engine call). While a foreign team is shown: Accept (OnEnter) and the
  -- spec's editing function keys (OnFunction ids) are refused with the «no» sound, and every button guide the
  -- spec's guide functions send keeps only the entries of spec.guide_keep (default: none but Back, which the guide
  -- never lists). spec = { stem = "<script stem>", functions = { [id] = true }, guides = { "GlobalName", ... },
  -- guide_keep = { [input] = true } }
  local GUIDE_COLUMNS, GUIDE_INPUTS = 2209673388, 452337289   -- the guide's columns, then its input commands
  function E.ViewOnly(spec)
    spec = type(spec) == "table" and spec or {}
    if type(VRFW_Host) ~= "table" or type(VRFW_Host.wrap) ~= "function" then
      return false
    end
    local function on()
      local ok, v = pcall(E.Foreign)
      return ok and v ~= nil
    end
    local function refuse()
      pcall(funcLuaCommand, E.C.SOUND, E.SE_NO)
    end
    local function opts(name)
      return { stem = spec.stem, id = "menu_engine.team_editor_view_only." .. name }
    end
    VRFW_Host.wrap("OnEnter", function(orig)
      return function(...)
        if on() then
          refuse()
          return 1
        end
        return orig(...)
      end
    end, opts("OnEnter"))
    VRFW_Host.wrap("OnFunction", function(orig)
      return function(a1, ...)
        if on() and type(spec.functions) == "table" and spec.functions[a1] then
          refuse()
          return
        end
        return orig(a1, ...)
      end
    end, opts("OnFunction"))
    local keep = type(spec.guide_keep) == "table" and spec.guide_keep or {}
    for _, name in ipairs(type(spec.guides) == "table" and spec.guides or {}) do
      VRFW_Host.wrap(name, function(orig)
        return function(...)
          if not on() then
            return orig(...)
          end
          -- the columns are held until the input commands arrive; the entries whose input is not kept leave both
          local held = nil
          local function hold_columns(nxt, cmd, ...)
            if held == nil then
              held = table.pack(cmd, ...)
              return
            end
            return nxt(cmd, ...)
          end
          local function filter_inputs(nxt, cmd, ...)
            if held ~= nil then
              local a = table.pack(cmd, ...)
              local drop = {}
              if type(a[4]) == "table" then
                for i, c in ipairs(a[4]) do
                  drop[i] = not keep[c]
                end
              end
              local function kept(list)
                if type(list) ~= "table" then
                  return list
                end
                local out = {}
                for i, v in ipairs(list) do
                  if not drop[i] then
                    out[#out + 1] = v
                  end
                end
                return out
              end
              for k = 4, 8 do
                held[k] = kept(held[k])
              end
              a[4] = kept(a[4])
              local h = held
              held = nil
              nxt(table.unpack(h, 1, h.n))
              return nxt(table.unpack(a, 1, a.n))
            end
            return nxt(cmd, ...)
          end
          local r = table.pack(pcall(VRFW_Host.WithCommands,
            { menu = { [GUIDE_COLUMNS] = hold_columns, [GUIDE_INPUTS] = filter_inputs } }, orig, ...))
          if held ~= nil then
            funcLuaMenuCommand(table.unpack(held, 1, held.n))
          end
          if not r[1] then
            error(r[2], 0)
          end
          return table.unpack(r, 2, r.n)
        end
      end, opts(name))
    end
    return true
  end

  function E.GuardSwap(nxt, ...)
    local refused = false
    local function check(send, ...)
      local _, _, to_set, _, from_set = ...
      if from_set ~= to_set then
        refused = true
        return false, 0
      end
      return send(...)
    end
    local overrides = {}
    for cmd in pairs(SWAP_CHECKS) do
      overrides[cmd] = check
    end
    local r = table.pack(pcall(VRFW_Host.WithCommands, overrides, nxt, ...))
    if refused then
      VRFW_Host.Command(E.C.SOUND, E.SE_NO)
      Log("swap refused: the player is not one of the team's")
    end
    if not r[1] then
      error(r[2], 0)
    end
    return table.unpack(r, 2, r.n)
  end

  function E.Foreign()
    if not VRFW_Param.Has(E.FOREIGN_KEY) then
      return nil
    end
    local function part(key)
      return VRFW_Param.Has(key) and Int(VRFW_Param.Get(key)) % 65536 or 0
    end
    local mask = VRFW_Param.Has(E.ROWS_KEY) and Int(VRFW_Param.Get(E.ROWS_KEY)) or 1
    local rows = {}
    for kind = 0, 29 do
      if math.floor(mask / 2 ^ kind) % 2 == 1 then
        rows[kind] = true
      end
    end
    return { stadium = part(E.STADIUM_HIGH_KEY) * 65536 + part(E.STADIUM_LOW_KEY), rows = rows }
  end

  function E.Run(spec)
    spec = type(spec) == "table" and spec or {}
    if spec.own then
      if ShowDock(spec.host) then
        return { opened = true, own = true }
      end
      return nil, "the team dock did not open"
    end
    local can, why = E.CanOpen()
    if not can then
      return nil, why
    end
    local ok, code = Call(E.C.SESSION_BEGIN, tostring(spec.owner or "VRFW"), 0, E.KIND_TEST)
    if ok ~= true then
      return nil, "the save session did not start (code " .. tostring(code) .. ")"
    end
    Log("session open for", tostring(spec.owner), ": saves of the slot are discarded until the dock closes")
    local set = Int(Call(E.C.VS_DOCK))
    local made, err = Fill(set, spec)
    local result
    if made then
      if spec.foreign then
        SetForeign(spec)
      end
      local opened = ShowDock(spec.host)
      if spec.foreign then
        SetForeign(nil)
      end
      if opened then
        result = Read(set, made)
        result.opened = true
        Log("read:", #result.members, "team players placed,", result.foreign, "club players, formation", result.formation)
      else
        err = "the team dock did not open"
      end
    end
    if not EndSession() then
      return nil, "the game could not be put back as it was"
    end
    if not result then
      return nil, err
    end
    return result
  end

  VRFW_TeamEditor = E
end
