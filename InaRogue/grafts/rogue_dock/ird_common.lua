  -- shared part of the INAROGUE dock blocks (docs/game/modes/inarogue.md §16: the squad screen IS the retail
  -- "Plantilla de equipo"). INAROGUE mode = the loaded game is the INAROGUE save (slot 4): everything there belongs to
  -- the mode, so the retail dock of slot 4 is the run's squad screen. Every rule is read from the loader: the bank
  -- (param -> uid, starter cost with fragments), the starter budget and whether a run is in progress.
  local IRD = {
    SLOT = @crc:CMND_EVT_SLOT_ROGUE@,           -- () -> rogueSlot, active, returnSlot, rogueHasGame
    BANK_COUNT = @crc:CMND_EVT_RL_BANK_COUNT@,  -- () -> count, capacity, slot, budget
    BANK_GET = @crc:CMND_EVT_RL_BANK_GET@,      -- (i, sort) -> ok, uid, param, ...
    PICK_STATE = @crc:CMND_EVT_RL_PICK_STATE@,  -- (uid) -> picked, starter cost (fragments applied), ...
    STARTER = @crc:CMND_EVT_RL_STARTER_INFO@,   -- () -> budget, ...
    RUN_INFO = @crc:CMND_EVT_RL_RUN_INFO@,      -- () -> exists, ...
    RESUME = @crc:CMND_EVT_RL_RUN_RESUME@,      -- () -> stage, node, kind, event, coin, game, diff, stadium, level, rival
    SET_SLOT = @crc:CMND_EVT_RL_RUN_SET_SLOT@,  -- (slot, uid, hdl) -> code
    LOG = @crc:CMND_EVT_LOG@,                     -- CMND_EVT_LOG
    GET_VS = @crc:CMND_GET_VS_USE_TEAM_SET@,                  -- CMND_GET_VS_USE_TEAM_SET
    CHECK = 1730898405,                   -- retail place check (hdl, set, pos, fromSet, team) -> ok, code (read-only)
    MOVE = 193693077,                     -- retail place / move (toSet, pos, fromSet, hdl, team): links 11v11 and 5v5
    POS_IDX = 1721292418,                 -- (set, team, posNo) -> ok, member index
    IDX_HDL = 1720957768,                 -- (set, team, index, 0) -> ok, handle (index 19 = coach)
    CHARA = 1131797651,                   -- (hdl, 4) -> chara_param id
    TEXT = @crc:CMND_SET_MENU_TEXT_STRING@,                    -- CMND_SET_MENU_TEXT_STRING (layer, node, text, idx)
    SE = @crc:CMND_SND_PLAY_SE@, SE_NG = 2086672038,  -- sy0003
    GET_BYTE = @crc:CMND_GET_GLOBAL_BYTE_FLAG@, SET_BYTE = @crc:CMND_SET_GLOBAL_BYTE_FLAG@,
    F_DOCK = @crc:EVT_IR_LAYER@,          -- byte 606: why INAROGUE opened the dock (1-4); +10 once the dock is open
    on = false, run = false, set = 0, frames = 0, text = "", spent = 0, budget = 0, foreign = 0, logs = 0, map = nil,
    why = 0,                              -- the request INAROGUE opened the dock with (1 start, 2 run, 3 before a match,
                                          -- 4 the team outside a run, 5 «Empezar partido» of the VS preview, §28)
    -- texts: InaRogue text\rows\menu_text.toml (9 languages)
    T = {
      MATCH11 = {@crc:evt_ird_match11@},
      MATCH5 = {@crc:evt_ird_match5@},
      POINTS = {@crc:evt_ird_points@},
      OVER = {@crc:evt_ird_over@},
      FOREIGN = {@crc:evt_ird_foreign@},
      BACK_MAP = {@crc:evt_ird_back_map@},
      BACK_PLAY = {@crc:evt_ird_back_play@},
      NEXT = {@crc:evt_ird_next@},
    },
  }

  -- a menu_text row in the game's language ("" when missing); {1}.. = values
  function IRD.tx(t, ...)
    local ok, s = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@, t[1])
    if not ok or type(s) ~= "string" then
      s = ""
    end
    local a = table.pack(...)
    return (s:gsub("{(%d)}", function(k)
      local v = a[tonumber(k)]
      return v == nil and "" or tostring(v)
    end))
  end

  function IRD.log(...)
    IRD.flush_unwrapped()
    if IRD.logs < 80 then
      IRD.logs = IRD.logs + 1
      pcall(funcLuaCommand, IRD.LOG, "inarogue dock", ...)
    end
  end

  --@lib evt_menu_kit.lua#call

  -- INAROGUE mode = the INAROGUE save (slot 4) is the loaded game; the budget only counts before a run starts
  function IRD.check()
    IRD.flush_unwrapped()
    local rs, act = call(IRD.SLOT)
    IRD.on = type(rs) == "number" and rs == act
    IRD.checked = true
    if IRD.on then
      IRD.run = call(IRD.RUN_INFO) == true
      IRD.set = call(IRD.GET_VS) or 0
    end
    return IRD.on
  end

  -- the dock is open: INAROGUE's request byte 1-5 becomes 11-15 (INAROGUE reads it when the title reopens it)
  function IRD.seen()
    local p = call(IRD.GET_BYTE, IRD.F_DOCK)
    if type(p) == "number" and p >= 1 and p <= 5 then
      call(IRD.SET_BYTE, IRD.F_DOCK, p + 10)
      IRD.why = p
    elseif type(p) == "number" and p >= 11 and p <= 15 then
      IRD.why = p - 10
    end
    IRD.log("seen, request", p, "run", IRD.run, "vs set", IRD.set)
  end

  -- the script stem of this patch file: its folder without the version suffix
  IRD.STEM = (function()
    local f = type(EVT_PATCH) == "table" and EVT_PATCH.file or nil
    local dir = type(f) == "string" and f:match("([^/]+)/[^/]+$") or nil
    return dir ~= nil and (dir:gsub("_%d+%.%d+[%.%d]*$", "")) or nil
  end)()
  IRD.unwrapped = {}   -- names IRD.wrap could not wrap, logged once by IRD.flush_unwrapped

  function IRD.flush_unwrapped()
    if IRD.unwrapped[1] ~= nil and type(funcLuaCommand) == "function" then
      local names = table.concat(IRD.unwrapped, ", ")
      IRD.unwrapped = {}
      pcall(funcLuaCommand, IRD.LOG, "inarogue dock", tostring(IRD.STEM), "not wrapped (not a function here):", names)
    end
  end

  -- VRFW_Host.wrap (the framework's one rule for wrappers of a hosted script: a later patch that redefines the
  -- function does not drop it); without it, a wrapper of the global
  function IRD.wrap(name, make)
    if type(VRFW_Host) == "table" and type(VRFW_Host.wrap) == "function" then
      local ok = VRFW_Host.wrap(name, make, {level = 2})   -- not a tail call: level 2 = the IRD.wrap call site
      if not ok then
        IRD.unwrapped[#IRD.unwrapped + 1] = name
      end
      return ok
    end
    local cur = _ENV[name]
    if type(cur) ~= "function" then
      IRD.unwrapped[#IRD.unwrapped + 1] = name
      return false
    end
    _ENV[name] = make(cur)
    return true
  end

  -- chara_param id -> {uid, cost} of every INAROGUE bank entry (built once per menu open)
  function IRD.bank()
    if IRD.map ~= nil then
      return IRD.map
    end
    local m = {}
    local n = call(IRD.BANK_COUNT)
    n = type(n) == "number" and n or 0
    for i = 0, n - 1 do
      local ok, uid, param = call(IRD.BANK_GET, i, 0)
      if ok == true and type(param) == "number" then
        local _, cost = call(IRD.PICK_STATE, uid)
        m[param] = {uid = uid, cost = type(cost) == "number" and cost or 0}
      end
    end
    IRD.map = m
    IRD.log("bank map", n, "players")
    return m
  end

  -- the INAROGUE bank entry of a character (nil = not an INAROGUE player: the avatar or anything foreign)
  function IRD.entry(hdl)
    if type(hdl) ~= "number" or hdl == 0 then
      return nil
    end
    local param = call(IRD.CHARA, hdl, 4)
    if type(param) ~= "number" then
      return nil
    end
    return IRD.bank()[param]
  end

  -- handle at a position of the VS team (team 0 = Partido 11v11, 1 = Pachanga 5v5: the same linked roster, retail
  -- dock 01; docs/game/modes/inarogue.md §20)
  function IRD.hdl(pos, team)
    local idx = pos
    if pos ~= 19 then
      local ok, i = call(IRD.POS_IDX, IRD.set, team or 0, pos)
      if ok ~= true or type(i) ~= "number" then
        return 0
      end
      idx = i
    end
    local ok2, h = call(IRD.IDX_HDL, IRD.set, team or 0, idx, 0)
    if ok2 ~= true or type(h) ~= "number" then
      return 0
    end
    return h
  end

  -- the retail place (SwapChara: check, then place / move); from = 16 (the bank) or the set (a move inside the dock).
  -- true = he is at `pos` of `team` now (docs/game/modes/inarogue.md §26)
  function IRD.place(hdl, pos, team, from)
    from = from or 16
    local ok, code = call(IRD.CHECK, hdl, IRD.set, pos, from, team)
    if ok ~= true then
      IRD.log("place refused by the retail check", hdl, "pos", pos, "team", team, "code", tostring(code))
      return false
    end
    call(IRD.MOVE, IRD.set, pos, from, hdl, team)
    return IRD.hdl(pos, team) == hdl
  end

  -- The 11v11 (team 0) and the 5v5 (team 1) of the INAROGUE dock are ONE linked roster, like the retail «Plantilla 01»
  -- (docs/game/modes/inarogue.md §26; the same pass as DK_Link5 of evt_inarogue_menu): 1. a member of one team only is
  -- added to the other one (retail same-set place, lowest free position; managers stay managers), a 5v5-only player with
  -- no room in the 11v11 goes back to the bank; 2. a hole in the five (5v5 positions 0-4): the goal takes the 11v11
  -- goalkeeper (from the bench or the five, whose place is refilled next), the others 5v5 bench players, the 11v11
  -- starters first in 11v11 position order, then the rest by 5v5 position (retail never gives position 0 to the
  -- auto-copy of a dock: nie.exe 0xDA1790). A five without holes is never touched. -> number of changes
  function IRD.link5()
    if not IRD.on or type(IRD.set) ~= "number" or IRD.set < 0 or IRD.set >= 16 then
      return 0
    end
    local T = {[0] = {pos = {}, where = {}}, [1] = {pos = {}, where = {}}}
    for team = 0, 1 do
      for pos = 0, 19 do
        local h = IRD.hdl(pos, team)
        if h ~= 0 then
          T[team].pos[pos], T[team].where[h] = h, pos
        end
      end
    end
    local function free(team, a, b)
      for p = a, b do
        if T[team].pos[p] == nil then
          return p
        end
      end
      return nil
    end
    local n = 0
    for h, p in pairs(T[0].where) do
      if p ~= 19 and T[1].where[h] == nil then
        local q = p >= 16 and free(1, 16, 18) or free(1, 0, 15)
        if q ~= nil and IRD.place(h, q, 1, IRD.set) then
          T[1].pos[q], T[1].where[h] = h, q
          n = n + 1
          IRD.log("link: 11v11 pos", p, "-> 5v5 pos", q)
        end
      end
    end
    for h, p in pairs(T[1].where) do
      if p ~= 19 and T[0].where[h] == nil then
        local q = p >= 16 and free(0, 16, 18) or free(0, 0, 15)
        if q ~= nil and IRD.place(h, q, 0, IRD.set) then
          T[0].pos[q], T[0].where[h] = h, q
          IRD.log("link: 5v5 pos", p, "-> 11v11 pos", q)
        else
          call(IRD.MOVE, 16, p, IRD.set, h, 1)
          T[1].pos[p], T[1].where[h] = nil, nil
          IRD.log("link: 5v5-only player without room in the 11v11: back to the bank", h)
        end
        n = n + 1
      end
    end
    for hole = 0, 4 do
      if T[1].pos[hole] == nil then
        local best, rank = nil, nil
        for p = 1, 15 do
          local h = T[1].pos[p]
          local p0 = h ~= nil and T[0].where[h] or nil
          if h ~= nil and (p >= 5 or (hole == 0 and p0 == 0)) then
            local r = 1000 + p
            if hole == 0 and p0 == 0 then
              r = 0
            elseif p0 ~= nil and p0 >= 1 and p0 <= 10 then
              r = 100 + p0
            end
            if rank == nil or r < rank then
              best, rank = h, r
            end
          end
        end
        if best ~= nil then
          local from = T[1].where[best]
          if IRD.place(best, hole, 1, IRD.set) then
            T[1].pos[from], T[1].pos[hole], T[1].where[best] = nil, best, hole
            n = n + 1
            IRD.log("link: 5v5 hole", hole, "<- 5v5 pos", from, "11v11 pos", tostring(T[0].where[best]))
          end
        end
      end
    end
    return n
  end

  -- Each team keeps a formation of its own kind (2026-10-06): the 11v11 team (0) never a 5v5 formation (a formation of
  -- formation_config with 5 players, VRFW_Formation) or none, the 5v5 team (1) only a 5v5 formation. A save left with
  -- the 11v11 team on «Formación en Y» (the Partido formation screen kept the Pachanga list) gets 4-4-2 Diamante back
  -- (retail, always owned); a 5v5 team without a 5v5 formation gets the story's one. No answer from the framework
  -- (nil) changes nothing. -> number of teams fixed
  IRD.FORM11_DEFAULT, IRD.FORM5_DEFAULT = 2484170522, 712431653   -- 4-4-2 Diamante / Formación en Y
  IRD.GET_INFO, IRD.SET_INFO = @crc:CMND_GET_TEAM_SET_INFO@, @crc:CMND_SET_TEAM_SET_INFO@            -- CMND_GET / SET_TEAM_SET_INFO (set, team, field, ...)
  function IRD.fix_forms()
    if not IRD.on or type(IRD.set) ~= "number" or IRD.set < 2 or IRD.set > 12 then
      return 0
    end
    local n = 0
    local ok, got, f = pcall(funcLuaCommand, IRD.GET_INFO, IRD.set, 0, 4)
    if ok and got == true and (type(f) ~= "number" or f == 0 or VRFW_Formation.IsFiveASide(f)) then
      pcall(funcLuaCommand, IRD.SET_INFO, IRD.set, 0, 3, IRD.FORM11_DEFAULT)
      IRD.log("11v11 team had formation", tostring(f), "-> 4-4-2 Diamante")
      n = n + 1
    end
    ok, got, f = pcall(funcLuaCommand, IRD.GET_INFO, IRD.set, 1, 4)
    if ok and got == true and VRFW_Formation.IsFiveASide(f) == false then
      pcall(funcLuaCommand, IRD.SET_INFO, IRD.set, 1, 3, IRD.FORM5_DEFAULT)
      IRD.log("5v5 team had formation", tostring(f), "-> Formacion en Y")
      n = n + 1
    end
    return n
  end

  -- counts and points of the VS team (positions 0-10 starters, 11-15 bench, 16-18 managers, 19 coach)
  function IRD.points()
    local st, be, ma, co, spent, foreign = 0, 0, 0, 0, 0, 0
    for pos = 0, 19 do
      local h = IRD.hdl(pos)
      if h ~= 0 then
        local e = IRD.entry(h)
        if e ~= nil then
          spent = spent + e.cost
        else
          foreign = foreign + 1
        end
        if pos <= 10 then
          st = st + 1
        elseif pos <= 15 then
          be = be + 1
        elseif pos <= 18 then
          ma = ma + 1
        else
          co = 1
        end
      end
    end
    local budget = call(IRD.STARTER)
    IRD.spent, IRD.foreign = spent, foreign
    IRD.budget = type(budget) == "number" and budget or 0
    return st, be, ma, co, spent, IRD.budget
  end

  -- the budget applies to the run start only (during a run the squad is already paid; Fichajes join free)
  function IRD.budget_on()
    return IRD.on and not IRD.run
  end

  function IRD.points_text()
    if not IRD.budget_on() then
      return "INAROGUE"
    end
    return IRD.tx(IRD.spent > IRD.budget and IRD.T.OVER or IRD.T.POINTS, IRD.spent, IRD.budget)
  end

  -- the dock shows the Pachanga (5v5) view of the same team (the «Tipo» row of the pachanga_dock graft)
  function IRD.pachanga()
    return type(EVT_PT) == "table" and type(EVT_PT.pachanga) == "function" and EVT_PT.pachanga() == true
  end

  -- starters of the 5v5 team (positions 0-4 of team 1)
  function IRD.starters5()
    local n = 0
    for pos = 0, 4 do
      if IRD.hdl(pos, 1) ~= 0 then
        n = n + 1
      end
    end
    return n
  end

  function IRD.summary()
    local st, be = IRD.points()
    local s
    if IRD.pachanga() then
      s = IRD.tx(IRD.T.MATCH5, IRD.starters5(), st + be)
    else
      s = IRD.tx(IRD.T.MATCH11, st, st + be)
    end
    if IRD.budget_on() then
      s = s .. " · " .. IRD.points_text()
    end
    if IRD.foreign > 0 then
      s = s .. " · " .. IRD.tx(IRD.T.FOREIGN)
    end
    if IRD.why == 3 and IRD.rival ~= nil then
      s = s .. " · " .. IRD.tx(IRD.T.NEXT, IRD.rival, IRD.level or 0)
    end
    return s .. " · " .. IRD.tx(IRD.why == 3 and IRD.T.BACK_PLAY or IRD.T.BACK_MAP)
  end
