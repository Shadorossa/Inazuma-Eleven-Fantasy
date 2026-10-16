-- {{name}} trigger (Expanded Victory Tool, INAROGUE match row; docs/game/modes/inarogue.md §14)
-- Writes the global byte flags the INAROGUE menu reads after the match (EVT_IR_RESULT 1 win / 2 lose / 3 draw,
-- EVT_IR_GF / EVT_IR_GA = "self > enemy" / "enemy > self" at full time, EVT_IR_PROBE 11 = loaded / 12 = full time).
local SET_BYTE = 187123515        -- CMND_SET_GLOBAL_BYTE_FLAG
local LOG = 3661580131               -- CMND_EVT_LOG (vr-loader; fails quietly without it)
local F_RESULT, F_GF, F_GA, F_PROBE = 504862522, 3095885530, 652469113, 3345119360
local function Log(...)
  pcall(funcLuaCommand, LOG, "rogue match trigger", "{{name}}", ...)
end
function RunCmd_Soccer1()
  funcLuaCommand(SET_BYTE, F_PROBE, 11)
  Log("init row 249")
end
function RunCmd_Soccer2()
  funcLuaCommand(SET_BYTE, F_PROBE, 12)
  Log("full time row 248")
end
function RunCmd_Soccer3()
  funcLuaCommand(SET_BYTE, F_RESULT, 1)
  Log("result row 202 target '0': user WON")
end
function RunCmd_Soccer4()
  funcLuaCommand(SET_BYTE, F_RESULT, 2)
  Log("result row 202 target '1': user LOST")
end
function RunCmd_Soccer5()
  funcLuaCommand(SET_BYTE, F_RESULT, 3)
  Log("result row 202 target 255: DRAW")
end
function RunCmd_Soccer6()
  funcLuaCommand(SET_BYTE, F_GF, 1)
  Log("row 248 cond GetSelfScore ? GetEnemyScore (order A) true")
end
function RunCmd_Soccer7()
  funcLuaCommand(SET_BYTE, F_GA, 1)
  Log("row 248 cond GetEnemyScore ? GetSelfScore (order B) true")
end
