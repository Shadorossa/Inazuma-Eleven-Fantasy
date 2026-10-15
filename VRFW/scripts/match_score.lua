-- Stores the score of the match being played, from the user's side, for the match rank rule (save keys mr_last_for / mr_last_against).
-- match_start resets it to 0 - 0; every goal stores the new score. ev.match.score = { team 0, team 1 }, ev.match.user_team = 0 / 1.

local function store(m)
  if m == nil or m.score == nil or m.user_team == nil then
    return
  end
  local s0, s1 = m.score[1], m.score[2]
  if s0 == nil or s1 == nil then
    return
  end
  local f, a = s0, s1
  if m.user_team == 1 then
    f, a = s1, s0
  end
  VRFW.save.set("mr_last_for", f)
  VRFW.save.set("mr_last_against", a)
end

VRFW.on("match_start", function(ev)
  VRFW.save.set("mr_last_for", 0)
  VRFW.save.set("mr_last_against", 0)
end)

VRFW.on("goal", function(ev)
  store(ev.match)
end)
