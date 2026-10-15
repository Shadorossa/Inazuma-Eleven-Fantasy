-- VRFW_MATCH_EXIT in soccer_top_menu (Competición), the menu side of match_exit (lua\menu\_all\14_match_exit.lua).
-- After a match this hub opens first, then routes on by itself to the menu the match was started from: its background
-- layer's OnOpenLayer reads the game's return menu (3163201916) and runs MoveToVsCpuMenuCoroutine / OpenList (the
-- free-match list), MoveToVsMydockMenuCoroutine («Competir contra mis equipos») or RunManageCoroutine (online). Under
-- the cover those calls mark the hub as passed through: the menu they open lands (releases the cover). With no return
-- menu the hub itself is the landing: the cover is released once its background layer finished opening (the moment
-- the game's own code fades the hub in). Wraps global functions only; no engine call at load time.
do
  local X = VRFW_MATCH_EXIT
  if type(X) == "table" and not X.hub_wrapped then
    X.hub_wrapped = true
    X.manual = true
    local BACKGROUND = 367379312     -- the hub's background layer (its open end: the retail flag2, the hub is open)

    for _, name in ipairs({ "MoveToVsCpuMenuCoroutine", "MoveToVsMydockMenuCoroutine", "OpenList", "RunManageCoroutine" }) do
      local f = rawget(_ENV, name)
      if type(f) == "function" then
        rawset(_ENV, name, function(...)
          if X.born and not X.done and not X.route then
            X.route = true
            if type(X.log) == "function" then X.log("routes on (" .. name .. "): the next menu lands") end
          end
          return f(...)
        end)
      end
    end

    local open_end = rawget(_ENV, "OnOpenEndLayer")
    if type(open_end) == "function" then
      rawset(_ENV, "OnOpenEndLayer", function(a1, ...)
        local r = table.pack(open_end(a1, ...))
        if a1 == BACKGROUND and not X.route and type(X.land) == "function" then
          pcall(X.land, "hub open")
        end
        return table.unpack(r, 1, r.n)
      end)
    end
  end
end
