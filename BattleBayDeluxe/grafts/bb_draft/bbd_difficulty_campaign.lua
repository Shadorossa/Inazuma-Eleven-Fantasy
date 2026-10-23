-- bb_chronicle_teams bb_draft, the Campaña / Torneo grid without the difficulty window while a mod owns the AI
-- difficulty (enjoy_team_select_menu_campaign; bbd_difficulty_common.lua). The retail team decide (OnDecideFocus on
-- the grid) hides the grid and opens the difficulty window; the window's start button decide starts the Campaña, or
-- (Torneo) lets scripts\campaign.lua's Decide hook draw the run. With an owned difficulty the window does not open:
-- the decide is kept and the next Step asks CMND_BBD_DIFFICULTY_START, which runs the start button's decide in the
-- game (outside this decide, with the Decide hook's phases); the Torneo then starts from its own Step (bbt_grid.lua:
-- the run is pending, GetSelectDifficultyIdx gives the owned index). This block wraps the retail OnDecideFocus first,
-- so the Torneo's options and the Draft screen still come before. A failed start opens the retail window.
-- Globals only; nothing runs at chunk load.
BBD_DIFFICULTY.START_RETRY_FRAMES = 30 -- frames the start is asked again while the scripts are busy
BBD_DIFFICULTY.DECIDE_HOLD_FRAMES = 120 -- frames another team decide is ignored after a start (the menu closes)

do
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    local D = BBD_DIFFICULTY
    if a1 == D.GRID then
      local ok, owned = pcall(BBD_DifficultyOwned)
      if ok and owned ~= nil then
        if D.pending ~= nil or (D.hold or 0) > 0 then
          return
        end
        D.pending = { args = table.pack(a1, a2, ...), tries = D.START_RETRY_FRAMES }
        BBD_DifficultyLog("team decided (tile " .. tostring(a2) .. "): no difficulty window, the start follows")
        return
      end
    end
    return decide(a1, a2, ...)
  end

  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    local D = BBD_DIFFICULTY
    if (D.hold or 0) > 0 then
      D.hold = D.hold - 1
    end
    local p = D.pending
    if p ~= nil then
      local ok, done = pcall(funcLuaCommand, D.START)
      if ok and done == true then
        D.pending = nil
        D.hold = D.DECIDE_HOLD_FRAMES
        BBD_DifficultyLog("started without the difficulty window")
      elseif ok and done == nil and p.tries > 0 then
        p.tries = p.tries - 1 -- the scripts were busy: asked again next frame
      else
        D.pending = nil
        BBD_DifficultyLog("the start without the difficulty window failed (" .. tostring(done) ..
          "): the difficulty window opens")
        local okd, err = pcall(decide, table.unpack(p.args, 1, p.args.n))
        if not okd then
          BBD_DifficultyLog("difficulty window error", tostring(err))
        end
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
