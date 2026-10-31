-- ===== EVT pachanga title BEGIN =====
-- The way back of a pachanga with return = "title" ends here: the loader's
-- route (CMND_EVT_TRIAL_RETURN 1 / 3) sent the match straight to the title; the title has the game back (in memory
-- with keep_game, else read again from the slot file the sink kept untouched). VRFW_PACHANGA.back(1) closes the
-- pachanga (sink off, "passed", VS team). A pachanga that was never played (the reservation dropped by a reset) is
-- closed the same way. Wraps OnInit after the retail one. No funcLua* call at chunk load.
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
      P.back(1)
    end)
    return table.unpack(r, 1, r.n)
  end
end
-- ===== EVT pachanga title END =====
