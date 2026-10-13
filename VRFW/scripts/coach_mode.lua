-- VR-Framework: a ruleset with `[play] coach_mode = false` (docs/framework/types/rule.md) has no coach (commander)
-- mode. While such a match runs the match engine publishes the state key match.coach_mode = 0; this handler then
-- refuses the game's coach-mode button (input command CMD_CHANGE_COACH_MODE: pad Select, keyboard U) on every press,
-- so the engine never toggles the mode. Other handlers of the same press still run (a mod may give the button another
-- use, e.g. Inazuma Fantasy's training field opens its options window). Every other match: nothing (nil).

VRFW.on("button_press:CMD_CHANGE_COACH_MODE", function(ev)
  if VRFW.state("match.coach_mode") == 0 then
    return { block = true }
  end
  return nil
end)
