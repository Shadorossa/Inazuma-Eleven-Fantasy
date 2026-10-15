-- {{name}} trigger (Expanded Victory Tool): recruitment trial "{{t1}}" (docs/game/modes/fichajes-ie3.md 5).
-- Plain Lua 5.2. Objective timed in REAL seconds: CMND_EVT_CLOCK_MS (vr-loader module office) when present; without it
-- the sum of the frame delta (0x8413C49E, the value WaitFrame subtracts every frame) over the type-227 polls, which is
-- exact only if the poll runs every frame; last resort: polls / 60. Every path is logged so the first run calibrates.
local SET_BIT = 3258400760        -- CMND_SET_GLOBAL_BIT_FLAG
local SET_BYTE = 187123515        -- CMND_SET_GLOBAL_BYTE_FLAG
local LOG = 3661580131               -- CMND_EVT_LOG (loader; fails quietly without it)
local CLOCK = 3441113678           -- CMND_EVT_CLOCK_MS (loader module office)
local DT = 2215888030             -- frame delta seconds (prog_base WaitFrame)
local F_DONE = {{v1}}           -- EVT_TRIAL_{{v2}} (bank-0 bit)
local B_RESULT = 1236541897     -- EVT_TRIAL_RESULT: 1 running, 2 passed, 3 failed
local B_SECS = 352766285         -- EVT_TRIAL_SECS: best seconds (hold) / goals / steals reached
local B_GAME = 2804103558         -- EVT_TRIAL_GAME: index of this trial (the office announces it once)
local TRIAL_INDEX = {{v3}}
local KEY_PLAYED = 907227118  -- param EVT_TRIAL_PLAYED
local TXT_OK = {{v4}}         -- menu_text {{name}}_ok
local JUDGE = 971867367           -- CMND_EVT_TRIAL_JUDGE (loader module office: the objective judged every frame)
local TEAM_USER, TEAM_RIVAL = 4108050209, 2212294583  -- trigger team keys "0" / "1"
local done, polls, dt_all, start_ms = false, 0, 0, 0
local function Log(...)
  pcall(funcLuaCommand, LOG, "{{name}}", ...)
end
local function Clock()
  local ok, ms = pcall(funcLuaCommand, CLOCK)
  if ok and type(ms) == "number" and ms > 0 then
    return ms
  end
  return nil
end
local function Poll()
  polls = polls + 1
  local dt = funcLuaCommand(DT)
  if type(dt) ~= "number" then
    dt = 0
  end
  dt_all = dt_all + dt
  return dt
end
local function Since(ms0, dt0, polls0)
  -- seconds since a mark: loader clock, else frame-delta sum, else polls / 60
  local now = Clock()
  if now ~= nil and ms0 ~= nil and ms0 > 0 then
    return (now - ms0) / 1000, "clock"
  end
  if dt_all - dt0 > 0 then
    return dt_all - dt0, "dt"
  end
  return (polls - polls0) / 60, "polls"
end
-- 2026-09-28: the rows of a trigger file fire ONCE per match (first test: one "hold start", never "hold lost"), so
-- the objective is judged every frame by the match HUD (ofq_hud_1.lua: hold time, goals within the time, steals;
-- bit + EVT_TRIAL_RESULT = 2 + EVT_TRIAL_SECS). These rows only log what they see (to learn when rows re-fire).
local function Pass(how, secs, ...)
  Log("row objective reached (the HUD decides)", how, secs, ...)
end
local function NoteSecs(v)
end
local function Init()
  done, polls, dt_all = false, 0, 0
  start_ms = Clock() or 0
  funcLuaCommand(SET_BYTE, B_RESULT, 1)
  funcLuaCommand(SET_BYTE, B_GAME, TRIAL_INDEX)
  Log("init", "clock", tostring(start_ms))
end
-- 2026-09-28 (fichajes-ie3.md 5.2g): rules of the trial match, set before kick-off (retail wrappers of prog_common,
-- the same calls the story battles make). no_shoot: the user team cannot shoot (no goals in keep-the-ball / steal
-- trials); hunt: the rival plays rough (tackles and slides at the maximum rate) and uses its skills at every chance.
local function Rules(no_shoot, hunt)
  if no_shoot then
    pcall(SetSoccerEnableNoShootExecTeam, TEAM_USER, true)
  end
  if hunt then
    pcall(SetRoughPlayTeamActRate, TEAM_RIVAL, 1, 1)
    pcall(SetSoccerAITeamSkillActRate, TEAM_RIVAL, 1)
  end
  Log("rules", "no_shoot", tostring(no_shoot), "hunt", tostring(hunt), type(SetSoccerEnableNoShootExecTeam))
end
local function FullTime(...)
  -- the loader's verdict (the match HUD copies it too; this covers a HUD that did not run)
  local okj, armed, _, _, _, result = pcall(funcLuaCommand, JUDGE, 2)
  if okj and armed == true and result == 2 then
    funcLuaCommand(SET_BIT, F_DONE, true)
    funcLuaCommand(SET_BYTE, B_RESULT, 2)
  end
  local ok, bit = pcall(funcLuaCommand, 941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], F_DONE)
  done = ok and bit == true
  if not done then
    funcLuaCommand(SET_BYTE, B_RESULT, 3)
  end
  Log("full time", done and "passed" or "failed", "polls", polls, "dt_all", dt_all, "clock", tostring(Clock()), ...)
end
function RunCmd_Soccer1()
  -- 249 match init
  Init()
  Rules({{t2}}, true)
end
function RunCmd_Soccer2()
  -- 248 full time (a Desafío normally ends before: the loader retires a team 45 frames after the verdict)
  FullTime()
end
function RunCmd_Soccer3()
  Log("result 202: user won")
end
function RunCmd_Soccer4()
  Log("result 202: user lost")
end
function RunCmd_Soccer5()
  Log("result 202: draw")
end
