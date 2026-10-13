-- VRFW bb_pages, campaign grid only (enjoy_team_select_menu_campaign; docs/framework/bb-pages.md). Deciding a team
-- hides the grid and opens the difficulty window; its retail OnCloseEndLayer shows every grid slot and every lock icon
-- again. On a short page that would bring the empty slots back: the grid is redrawn from the live slots after it (empty
-- slots hidden, lock icons only on locked slots). The campaign takes the player's team from the slot under the cursor,
-- on whatever page / category / season.
do
  local closeEnd = OnCloseEndLayer
  function OnCloseEndLayer(a1, a2, ...)
    local r = table.pack(closeEnd(a1, a2, ...))
    local B = VRFW_BBP
    if a1 == B.DIFFWIN and B.on and (B.total > 1 or B.seasons >= 2) then
      local ok, err = pcall(VRFW_BBP_Redraw)
      if not ok then
        VRFW_BBP_Log("redraw error", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
