-- VR-Framework: a ruleset with `[play] goal_scenes = false` (docs/framework/types/rule.md, VRFW 2.2.93; Inazuma
-- Fantasy's training field «Modo libre», owner 2026-10-13: «after a goal, straight back to the kick-off») has no goal
-- scenes. While such a match runs the match engine publishes the state key match.goal_scenes = 0; then, from a goal
-- (the `goal` trigger, or the keeper beaten by a shot: the goal scene starts before the score changes) until the next
-- kick-off, every event the game plays (the goal scene, the scorer's celebration) is run to its end in the frame it is
-- seen: its sounds stopped and its timeline seeked to the end, the retail event skip without its fades (the same steps
-- as BetterUI's pre-match X jump, docs/game/ui/prematch-skip.md §6). The game's own flow then goes on by itself (the
-- seek runs every pending command of the timeline). Every other match: nothing.
-- Declarations: content\game\goal_scenes.toml (event_manager, EventSeek, StopEventSounds, TimelineSeek).

local GOAL = 13                    -- soccer state Goal
local RESTART = 10                 -- soccer state Restart (the kick-off): the skip ends there
local LIVE = { [9] = true, [14] = true, [15] = true, [16] = true }   -- InPlay, FocusBtl, Scramble, Zone
local ARM_MS = 20000               -- the skip ends this long after the goal at the latest
local NO_GOAL_MS = 6000            -- armed by a beaten keeper, still in live play this long after: no goal

local EVM_CURRENT = 0x9154         -- event manager: current slot index (u32)
local EVM_SLOTS = 20
local EVM_STRIDE = 0x7E0
local SLOT_STATE = 0x508           -- u8: 8 = playing
local SLOT_TIMELINE = 0x4E8        -- ptr: the event's timeline
local SLOT_CUTS = 0x5B0            -- ptr / u32 (+0x5B8): the cut table EventSeek needs
local SLOT_CUT_COUNT = 0x5B8
local SLOT_FREE_SEEK = 0x7C0       -- u8: seek allowed without a cut table
local SLOT_SKIP_TO = 0x7BC         -- f32: the retail skip's target (-1 = none)
local TL_STATE = 0x4B              -- u8: 4 = ended
local PLAYING = 8

local armed_at = nil               -- VRFW.now() of the goal, nil = no skip running
local seen_goal_state = false      -- the goal state was reached since the arm (a Restart before it is the old one)
local skips = 0                    -- events ended in this match (log)
local failed = false               -- a declaration is off: logged once, nothing more tried

local function off()
  return VRFW.state("match.goal_scenes") == 0
end

local function rd(ty, at)
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function arm(why)
  if not off() then return end
  if armed_at == nil then
    VRFW.log("goal scenes off: " .. why .. ": the goal events are run to their end until the kick-off")
  end
  armed_at = VRFW.now()
end

local function disarm(why)
  if armed_at ~= nil then
    VRFW.log(string.format("goal scenes off: skip over (%s), %d event(s) ended in this match", why, skips))
  end
  armed_at = nil
  seen_goal_state = false
end

-- the running event of the event manager, ended now when it plays (true = one was ended)
local function end_current()
  local ok, mgr = pcall(VRFW.game.event_manager)
  if not ok or type(mgr) ~= "number" or mgr == 0 then
    if not failed then
      failed = true
      VRFW.log("goal scenes off: no event manager (" .. tostring(mgr) .. "): the goal events play as the game's")
    end
    return false
  end
  local idx = rd("u32", mgr + EVM_CURRENT)
  if idx == nil or idx >= EVM_SLOTS then return false end
  local slot = mgr + idx * EVM_STRIDE
  local tl = rd("ptr", slot + SLOT_TIMELINE)
  if tl == nil or tl == 0 then return false end
  if rd("u8", slot + SLOT_STATE) ~= PLAYING or rd("u8", tl + TL_STATE) == 4 then return false end
  pcall(VRFW.call, "StopEventSounds", slot, 0.0, 1)
  local cuts = rd("ptr", slot + SLOT_CUTS) or 0
  local cut_count = rd("u32", slot + SLOT_CUT_COUNT) or 0
  local free = rd("u8", slot + SLOT_FREE_SEEK) or 0
  local ok2, e
  if (cuts ~= 0 and cut_count ~= 0) or free ~= 0 then
    ok2, e = pcall(VRFW.call, "EventSeek", slot, -1.0)
  else
    ok2, e = pcall(VRFW.call, "TimelineSeek", tl, -1.0, 1)
  end
  if not ok2 then
    if not failed then
      failed = true
      VRFW.log("goal scenes off: the seek failed (" .. tostring(e) .. "): the goal events play as the game's")
    end
    return false
  end
  pcall(VRFW.mem.write, "f32", slot + SLOT_SKIP_TO, -1.0)
  skips = skips + 1
  if skips <= 8 then
    VRFW.log(string.format("goal scenes off: event of slot %d ended (timeline state %s)", idx, tostring(rd("u8", tl + TL_STATE))))
  end
  return true
end

VRFW.on("match_start", function(ev)
  disarm("match start")
  skips = 0
  return nil
end)

VRFW.on("goal", function(ev)
  arm("goal")
  return nil
end)

VRFW.on("keeper_scene:beaten", function(ev)
  arm("keeper beaten")
  return nil
end)

VRFW.on("tick", function(ev)
  if armed_at == nil or failed then return nil end
  if not off() or VRFW.now() - armed_at > ARM_MS then
    disarm("time out")
    return nil
  end
  local st = ev.match and ev.match.soccer_state
  if st == GOAL then
    seen_goal_state = true
  elseif st == RESTART and seen_goal_state then
    disarm("kick-off")
    return nil
  elseif LIVE[st] and seen_goal_state then
    disarm("play")
    return nil
  elseif LIVE[st] and VRFW.now() - armed_at > NO_GOAL_MS then
    -- the keeper was beaten but no goal came (the post, a clearance on the line): play goes on with its scenes
    disarm("no goal")
    return nil
  end
  end_current()
  return nil
end)

VRFW.on("match_end", function(ev)
  disarm("match end")
  return nil
end)
