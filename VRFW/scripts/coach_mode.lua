-- Refuses the game's coach-mode button (CMD_CHANGE_COACH_MODE) while the active ruleset has `[play] coach_mode = false` (state key match.coach_mode = 0).
-- Other handlers of the same press still run; in every other match this returns nil.

VRFW.on("button_press:CMD_CHANGE_COACH_MODE", function(ev)
  if VRFW.state("match.coach_mode") == 0 then
    return { block = true }
  end
  return nil
end)
