-- ===== EVT pachanga title BEGIN =====
-- The way back of a pachanga with return = "title" ends here: the loader's
-- route (CMND_EVT_TRIAL_RETURN 1 / 3) sent the match straight to the title; the title has the game back (in memory
-- with keep_game, else read again from the slot file the sink kept untouched). VRFW_PACHANGA.back(1) closes the
-- pachanga (sink off, "passed", VS team) and, when the rules name a title request (origin), modes_hub's title block
-- is given it (the Market for the office). A pachanga that was never played (the reservation dropped by a reset) is
-- closed the same way. A VR-Framework patch: its root runs after a mod's lua_early, so this wraps OnInit
-- outside modes_hub's wrapper, which took its own keys before the retail OnInit and does nothing after it. Without
-- modes_hub (no EVT_MH_T) the pachanga is only closed. No funcLua* call at chunk load.
do
  local init = OnInit
  function OnInit(...)
    local r = table.pack(init(...))
    pcall(function()
      local P = VRFW_PACHANGA
      local st = P.state()
      if not (st.phase >= 1 and st.phase <= 3) then
        return
      end
      local info = P.back(1)
      local T = EVT_MH_T
      if info.closed and info.origin ~= 0 and type(T) == "table" and T.pending == nil then
        T.pending, T.focus = info.origin, nil
        T.frames, T.fired, T.seen_off, T.force = 0, 0, false, nil
        pcall(funcLuaCommand, 609722083, 1, 0) -- black: no title frame before the origin opens
        P.log("title: back from the pachanga -> origin", info.origin)
      end
    end)
    return table.unpack(r, 1, r.n)
  end
end
-- ===== EVT pachanga title END =====
