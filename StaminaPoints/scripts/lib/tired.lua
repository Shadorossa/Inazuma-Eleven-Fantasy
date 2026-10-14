-- Stamina Points › the tired locomotion's policy ([tired_motion], docs/game/media/cs-exhausted-walk.md §9; Inazuma
-- Fantasy's scripts/lib/stamina/tired.lua until 2026-10-14). Below run_below of his PE (until back above run_recover) a field player
-- runs with ONE of run_sets (drawn per episode, or per match with reroll = "match"); at <= idle_at (0 PE), without the
-- ball and in one of idle_states, every idle_every_s he stops for idle_for_s (speed × idle_speed, the idle_set).
--
--   local T = require "lib/tired"
--   local w = T.step(track, cfg, facts, rng)   -- "off" | { run = i } | "idle"

local M = {}

-- tolerance of idle_at (the PE is a float drained per frame: 0 PE may read 1e-6)
M.IDLE_EPS = 0.002

-- weighted draw of a run set (1-based) from a random number in [0, 1)
function M.draw_run(cfg, r)
  local n = math.max(#cfg.run_sets, 1)
  local w, total = {}, 0
  local use = #cfg.run_weights == #cfg.run_sets
  if use then
    use = false
    for _, x in ipairs(cfg.run_weights) do if tonumber(x) and x > 0 then use = true end end
  end
  for i = 1, n do
    local x = use and math.max(tonumber(cfg.run_weights[i]) or 0, 0) or 1
    w[i] = x
    total = total + x
  end
  local x = r * total
  for i = 1, n do
    if x < w[i] then return i end
    x = x - w[i]
  end
  return n
end

function M.in_range(r, range)
  local a = math.max(range[1], 0)
  local b = math.max(range[2], a)
  return a + (b - a) * r
end

-- One frame of a player's track (`t = { tired, run, idle_until, next_idle }`). facts = { ratio, eligible, has_ball,
-- idle_state, now (s) }; rng() -> [0, 1).
function M.step(t, cfg, f, rng)
  local function reset_idle()
    t.idle_until = 0
    t.next_idle = 0
  end
  if not cfg.enabled or not f.eligible or #cfg.run_sets == 0 then
    t.tired = false
    if not cfg.reroll_match then t.run = nil end
    reset_idle()
    return "off"
  end
  if t.tired then t.tired = f.ratio <= cfg.run_recover else t.tired = f.ratio < cfg.run_below end
  if not t.tired then
    if not cfg.reroll_match then t.run = nil end
    reset_idle()
    return "off"
  end
  if not t.run or t.run > #cfg.run_sets then t.run = M.draw_run(cfg, rng()) end
  local run = { run = t.run }
  if cfg.idle_set:match("^%s*$") or f.ratio > cfg.idle_at + M.IDLE_EPS then
    reset_idle()
    return run
  end
  if f.has_ball then
    -- the ball ends a pause at once; the next one waits a whole interval
    if t.idle_until > 0 then
      t.idle_until = 0
      t.next_idle = f.now + M.in_range(rng(), cfg.idle_every_s)
    end
    return run
  end
  if t.idle_until > 0 then
    if f.now < t.idle_until then return "idle" end
    t.idle_until = 0
  end
  if t.next_idle <= 0 then
    t.next_idle = f.now + M.in_range(rng(), cfg.idle_every_s)
  elseif f.now >= t.next_idle and f.idle_state then
    t.idle_until = f.now + M.in_range(rng(), cfg.idle_for_s)
    t.next_idle = t.idle_until + M.in_range(rng(), cfg.idle_every_s)
    return "idle"
  end
  return run
end

function M.new_track()
  return { tired = false, run = nil, idle_until = 0, next_idle = 0 }
end

return M
