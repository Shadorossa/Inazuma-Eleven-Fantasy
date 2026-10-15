-- ===== EVT pachanga core BEGIN =====
-- The ONE pachanga function of the VR-Framework match engine: every mode
-- (a roguelite, office trials, a free-walk city mode, later the 3DS pachangas) starts, plays and comes back from a friendly
-- match through VRFW_PACHANGA.start(rules id, context). The rules are DATA declared by the mod
-- (<mod>\rules\pachangas\*.toml); the loader (CMND_EVT_PACHANGA_START) turns them into the ordered steps this executor
-- runs: team / kit, the way-back route, fades, the VS-CPU pre-match sequence, the reservation and the hand-off of the
-- caller's menus. A failed step rolls back what the loader says. No caller-specific branch here. Defines functions
-- only: no engine call at chunk load.
VRFW_PACHANGA = VRFW_PACHANGA or {}
do
  local P = VRFW_PACHANGA
  P.CMD = {
    START = 2490728909, STEP = 2494733779, REPORT = 1738046244, ABORT = 4055457894, BACK = 3133514456,
    STATE = 2828994233, ACK = 609614192, AUX = 3161656697, PASSED = 3228376551, PASSED_SET = 700047444,
    MAP = 2501684090, RULES = 2190888318, ROLL = 3055137984 --[[CMND_EVT_ITEM_REWARD_ROLL]],
    LOG = 3661580131,
  }
  P.FADE_ENCOUNT = 2721617045 --[[fade_menu_encount]]
  -- op codes of crate::pachanga::Step::encode
  P.OP = {VS_SWAP = 1, KIT = 2, VS_RESTORE = 3, RETURN = 4, DEACTIVATE = 10, FADE_BLACK = 11, FADE_ENCOUNTER = 12,
    BYTE = 13, WAIT = 14, ACTIVATE = 15, PRE_MATCH = 20, DIFFICULTY = 21, RESERVE = 22, KEY = 30, CLOSE = 31,
    WAIT_GONE = 32, WAIT_SETTLED = 33, TOP_WAIT = 34, WATCHDOG = 35}

  --@lib evt_menu_kit.lua#call
  P.call = call
  function P.log(...)
    pcall(funcLuaCommand, P.CMD.LOG, "EVT pachanga", ...)
  end
  local function wait(f, frames)
    for _ = 1, frames do
      if f() then
        return true
      end
      coroutine.yield()
    end
    return false
  end

  -- the active pachanga dock (2..12) or nil (loader team_banks bit 21, "Establecer como equipo activo", complete five)
  function P.pachanga_set()
    local ok, _, mods = pcall(funcLuaCommand, 2217361807 --[[CMND_EVT_LOADER_VERSION]])
    if not ok or type(mods) ~= "number" or math.floor(mods / 2097152) % 2 ~= 1 then
      return nil
    end
    local ok2, has, set = pcall(funcLuaCommand, 334218736 --[[CMND_EVT_PACHANGA_TEAM]])
    if not ok2 or has ~= true or type(set) ~= "number" or set < 2 or set > 12 then
      return nil
    end
    local code = funcLuaCommand(1538643580, set, 1, false) -- retail member check of the 5v5 team
    if type(code) == "number" and code > 0 and code < 11 then
      return nil
    end
    return set
  end

  -- a five WITHOUT a kit of its own wears its dock's 11v11 kit (street battles dress kit-less fives in gym clothes)
  function P.kit(set)
    local a = table.pack(pcall(funcLuaCommand, 1598711521 --[[CMND_EVT_TEAM_UNIFORM]], set, 0))
    local b = table.pack(pcall(funcLuaCommand, 1598711521, set, 1))
    if a[1] ~= true or a[2] ~= true or type(a[3]) ~= "number" or a[3] == 0 or b[1] ~= true or b[2] ~= true then
      return
    end
    if b[3] == a[3] or b[3] ~= 0 then
      return
    end
    pcall(funcLuaCommand, 1598711521, set, 1, a[3], 0)
  end

  function P.vs_restore()
    local ok, had, vs = pcall(funcLuaCommand, 4127470188 --[[CMND_EVT_PACHANGA_VS]], 0)
    if ok and had == true and type(vs) == "number" and vs >= 0 then
      funcLuaCommand(662075964 --[[CMND_SET_VS_USE_TEAM_SET]], vs)
      P.log("VS team restored", vs)
    end
  end

  -- one step; false = it failed (a refused reservation, a menu that did not go, a watchdog that fired)
  local function exec(op, a, b, c)
    local O = P.OP
    if op == O.VS_SWAP then
      pcall(funcLuaCommand, 4127470188 --[[CMND_EVT_PACHANGA_VS]], 1, funcLuaCommand(3713813716 --[[GET_VS_USE_TEAM_SET]]))
      funcLuaCommand(662075964 --[[CMND_SET_VS_USE_TEAM_SET]], a)
    elseif op == O.KIT then
      pcall(P.kit, a)
    elseif op == O.VS_RESTORE then
      P.vs_restore()
    elseif op == O.RETURN then
      local okt, live, armed = call(3094129190 --[[CMND_EVT_TRIAL_RETURN]], a)
      P.log("way-back route", a, tostring(okt), tostring(live), tostring(armed))
    elseif op == O.DEACTIVATE then
      funcLuaMenuCommand(1558704558, a, false)
    elseif op == O.ACTIVATE then
      funcLuaMenuCommand(1558704558, a, true)
    elseif op == O.FADE_BLACK then
      if b == 1 then
        funcLuaCommand(609722083, 1, a)
        coroutine.yield()
        wait(function() return funcLuaCommand(2259183189) end, c)
      else
        funcLuaCommand(609722083, 0, a)
      end
    elseif op == O.FADE_ENCOUNTER then
      if b == 1 then
        pcall(funcLuaCommand, 3366565849, true, P.FADE_ENCOUNT)
        if a > 0 then
          wait(function()
            local ok, busy = pcall(funcLuaCommand, 316436678 --[[menu fade running]])
            return not ok or busy ~= true
          end, a)
        end
      else
        pcall(funcLuaCommand, 3366565849, false, P.FADE_ENCOUNT)
        local okf, black = pcall(funcLuaCommand, 2259183189)
        if okf and black then
          pcall(funcLuaCommand, 609722083, 0, 0.3)
        end
      end
    elseif op == O.BYTE then
      call(187123515 --[[CMND_SET_GLOBAL_BYTE_FLAG]], a, b)
    elseif op == O.WAIT then
      for _ = 1, a do
        coroutine.yield()
      end
    elseif op == O.PRE_MATCH then
      call(3014583614 --[[CMND_SET_PRE_MATCH_SOCCER_GAME_ID]], a)
    elseif op == O.DIFFICULTY then
      call(1104380539 --[[difficulty helper]], a)
    elseif op == O.RESERVE then
      local ok, r = pcall(funcLuaCommand, 1620561217 --[[CMND_RESERVE_SOCCER]], a, b, c)
      P.log("reserve", a, b, c, tostring(ok), tostring(r))
      return ok and r ~= false and r ~= nil
    elseif op == O.KEY then
      if funcLuaCommand(2947612279, a) then
        funcLuaCommand(3363400568, a)
      end
      if b ~= 0 then
        funcLuaCommand(3860611758, a, 0, b, 1)
      end
    elseif op == O.CLOSE then
      funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], a)
    elseif op == O.WAIT_GONE then
      local n = 0
      while n < b and funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], a) do
        n = n + 1
        coroutine.yield()
      end
      return n < b
    elseif op == O.WAIT_SETTLED then
      wait(function() return funcLuaMenuCommand(3050482496) ~= false end, a)
      wait(function() return not funcLuaCommand(2736534827 --[[fade busy]]) end, a)
    elseif op == O.TOP_WAIT then
      funcLuaCommand(769636339, a)
    elseif op == O.WATCHDOG then
      -- a closed menu is never resumed: still running here = the caller's menu did not go; the key still set =
      -- nobody took the hand-off, nobody will start the match
      for _ = 1, a do
        coroutine.yield()
      end
      return not funcLuaCommand(2947612279, b)
    end
    return true
  end
  P.exec = exec

  function P.rollback(n)
    for i = 1, (n or 0) do
      local op, a, b, c = call(P.CMD.STEP, -i)
      if type(op) == "number" and op > 0 then
        exec(op, a, b, c)
      end
    end
  end

  -- THE function. Runs inside the caller's coroutine (it yields). ctx = {tag, sub, game, difficulty, objective, set,
  -- stadium, rival, map = {map, x, y, z, rot}, on_reserved = function, on_failed = function(why)}; set = nil -> the
  -- active pachanga dock; rival = nil -> the row's rival team (asked at the call). Returns true, or false + why (the launch was rolled back; the caller shows its message).
  function P.start(id, ctx)
    ctx = ctx or {}
    local set = ctx.set
    if set == nil then
      set = P.pachanga_set() or -1
    end
    local m = ctx.map or {}
    -- the rival team of the row (rules with rival_home = true play at its home stadium; the loader decides)
    local rival = ctx.rival
    if rival == nil and (ctx.game or 0) ~= 0 then
      local d = ctx.difficulty or 0
      local okT, team = call(2204933160 --[[game row's rival team]], ctx.game, d ~= 0 and d or 1)
      if okT == true and type(team) == "number" then
        rival = team
      end
    end
    local ok, code, n = call(P.CMD.START, id, ctx.tag or 0, ctx.sub or 0, ctx.game or 0, ctx.difficulty or 0,
      ctx.objective or 0, set, ctx.stadium or 0, m[1] or 0, m[2] or 0, m[3] or 0, m[4] or 0, m[5] or 0, rival or 0)
    if ok ~= true then
      P.log("start refused", id, tostring(code))
      return false, code
    end
    local skip = false
    for i = 1, (n or 0) do
      local op, a, b, c = call(P.CMD.STEP, i)
      if type(op) ~= "number" or op == 0 then
        break
      end
      if not (skip and op ~= P.OP.WATCHDOG) then
        local good = exec(op, a, b, c)
        if op == P.OP.RESERVE or (op == P.OP.WATCHDOG and not good) then
          local nb = call(P.CMD.REPORT, i, good and 1 or 0)
          if not good then
            if type(ctx.on_failed) == "function" then
              pcall(ctx.on_failed, op == P.OP.RESERVE and "reserve" or "watchdog") -- the caller's own state first
            end
            P.rollback(nb)
            return false, op == P.OP.RESERVE and "reserve" or "watchdog"
          end
          if op == P.OP.RESERVE and type(ctx.on_reserved) == "function" then
            pcall(ctx.on_reserved) -- the caller's own state (the hand-off may end this coroutine)
          end
        elseif op == P.OP.WAIT_GONE and not good then
          skip = true
        end
      end
    end
    return true
  end

  -- the launch is given up by the caller (another menu's watchdog): rolled back, sink off
  function P.abort(why)
    P.rollback(call(P.CMD.ABORT, why or "aborted"))
  end

  -- the way back reached its end (where: 1 title, 2 map, 3 menu): sink off, "superada" recorded, VS team back,
  -- reward given. Returns the result (closed = this call closed the pachanga).
  function P.back(where)
    local r = table.pack(call(P.CMD.BACK, where))
    local info = {closed = r[1] == true, outcome = r[2] or 0, passed = r[3] == true, origin = r[4] or 0,
      team_swapped = r[5] == true, id = r[6], tag = r[7] or 0, sub = r[8] or 0,
      aux = {r[9] or 0, r[10] or 0, r[11] or 0, r[12] or 0}, rewards = r[13] or ""}
    if info.closed then
      if info.team_swapped then
        P.vs_restore()
      end
      if info.rewards ~= "" then
        P.give(info.rewards)
      end
      P.log("back", where, tostring(info.id), info.outcome, tostring(info.passed))
    end
    return info
  end

  function P.state()
    local r = table.pack(call(P.CMD.STATE))
    return {phase = r[1] or 0, id = r[2], tag = r[3] or 0, sub = r[4] or 0, outcome = r[5] or 0, passed = r[6] == true,
      ret = r[7] or 0, aux = {r[8] or 0, r[9] or 0, r[10] or 0, r[11] or 0}, field_net = r[12] == true}
  end
  function P.ack()
    return call(P.CMD.ACK) == true
  end
  function P.aux(i, v)
    return call(P.CMD.AUX, i, v) == true
  end
  function P.passed(id, tag, sub)
    return call(P.CMD.PASSED, id, tag or 0, sub or 0) == true
  end
  function P.set_passed(id, tag, sub, on)
    return call(P.CMD.PASSED_SET, id, tag or 0, sub or 0, on and 1 or 0) == true
  end

  -- return = "map": black at once and the jump to the spot given at the launch. true = reserved
  function P.map_jump()
    local ok, map, x, y, z, rot = call(P.CMD.MAP)
    if ok ~= true then
      return false
    end
    pcall(funcLuaCommand, 609722083, 1, 0) -- black at once: no frame of the battle field
    local okj, res = pcall(funcLuaCommand, 664962748 --[[CMND_RESERVE_MAP_JUMP]], map, x, y, z, rot, false, true, false,
      false, false, true)
    return okj and res ~= false
  end

  -- an item_engine reward table: rolled and given (CMND_ADD_ITEM_ONLY)
  function P.give(key)
    local ok, n, list = pcall(funcLuaCommand, P.CMD.ROLL, key, math.random(1, 2147483646), false)
    if not ok or type(list) ~= "string" then
      return
    end
    for item, count in string.gmatch(list, "(%d+):(%d+)") do
      pcall(funcLuaCommand, 1897915498 --[[CMND_ADD_ITEM_ONLY]], tonumber(item), tonumber(count))
    end
  end
end
-- ===== EVT pachanga core END =====
