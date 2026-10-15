-- match_challenge (VR-Framework service): the Chronicle board's command menu
-- (vs_route_town_command_select_menu, a VRFW_Host host of the framework's route_board graft) checks the piece's match
-- challenge before a difficulty row starts the match.
-- around OnEnter of the row list (vsroute01_16_sub_list): after the retail checks (locked difficulty, team not valid),
-- a match row (difficultyType > 0) of a piece whose game has a [[VRFW.MatchChallenge]] (the route node's `Challenge`, or
-- the challenge's `Games`) is refused when the active dock does not meet it: error sound + the message with the
-- conditions; returning 1 keeps the menu open (the retail refusal), so the player can open «Equipo» and try again.
-- The piece's game is VRFW_RBC.L.n4, the rows VRFW_RBC.L.t3 (route_board's rbc_common.lua). A chain «C» piece opens the
-- chain board instead: its tiles are checked there. A challenge with `Difficulties` is checked only on
-- those rows (e.g. a Heroica-only challenge leaves the Crónica, played with its fixed line-up, alone).
-- The match info: while a row whose challenge applies is focused, the button guide at the bottom of the
-- menu shows the challenge's title (its menu_text row) as one more entry (VRFW_RBC_Guide), so the rule is read before
-- the match is chosen. Required starters (`[[VRFW.MatchChallenge.Required]]`): the row's clear bit
-- (CMND_GET_CHRONICLE_CLEAR_STATUS of the piece's save slot VRFW_RBC.L.n2) tells whether the row was won before (a
-- `UntilFirstClear` one then no longer applies); while one applies, its own text is one more guide entry.
-- No engine call at load time.
if VRFW_Host ~= nil then
  local ROWS = 284009563   -- vsroute01_16_sub_list
  local CLEAR_GET = 4034518619   -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)

  -- was this difficulty row of the open piece won before (false when unknown)
  local function row_cleared(diff)
    local ok, slot = pcall(function()
      return VRFW_RBC.L.n2
    end)
    if not ok or type(slot) ~= "number" then
      return false
    end
    local okC, won = pcall(funcLuaCommand, CLEAR_GET, slot, diff)
    return okC and won == true
  end

  VRFW_Host.on("vs_route_town_command_select_menu", "OnEnter", {
    id = "menu_engine.match_challenge", phase = "around",
    fn = function(nxt, a1, a2, ...)
      local r = table.pack(nxt(a1, a2, ...))
      if a1 ~= ROWS or r[1] == 1 or VRFW_MC == nil or VRFW_RBC == nil then
        return table.unpack(r, 1, r.n)
      end
      local ok, rows, game = pcall(function()
        return VRFW_RBC.L.t3, VRFW_RBC.L.n4
      end)
      local row = ok and type(rows) == "table" and type(a2) == "number" and rows[a2 + 1] or nil
      if row ~= nil and (row.difficultyType or 0) > 0 and type(game) == "number"
        and not VRFW_MC.Gate(game, 0, row.difficultyType, row_cleared(row.difficultyType)) then
        return 1
      end
      return table.unpack(r, 1, r.n)
    end,
  })

  -- the focused row's challenge title in the button guide (no icon, no command: a text entry)
  VRFW_Host.on("vs_route_town_command_select_menu", "VRFW_RBC_Guide", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function(r, item, icons, texts, cmds)
      if VRFW_MC == nil or VRFW_RBC == nil or type(item) ~= "table" or (item.difficultyType or 0) <= 0 then
        return
      end
      local ok, game = pcall(function()
        return VRFW_RBC.L.n4
      end)
      local i = ok and type(game) == "number" and VRFW_MC.Of(game, item.difficultyType) or nil
      local c = i ~= nil and VRFW_MC.Info(i) or nil
      if c ~= nil and type(c.title) == "number" and c.title ~= 0 and type(texts) == "table" then
        icons[#icons + 1] = 0
        texts[#texts + 1] = c.title
        cmds[#cmds + 1] = 0
      end
      -- the required starters that still apply (their own texts)
      if c ~= nil and type(texts) == "table" and #(c.required or {}) > 0 then
        for _, t in ipairs(VRFW_MC.RequiredTexts(i, row_cleared(item.difficultyType))) do
          icons[#icons + 1] = 0
          texts[#texts + 1] = t
          cmds[#cmds + 1] = 0
        end
      end
    end,
  })
end
