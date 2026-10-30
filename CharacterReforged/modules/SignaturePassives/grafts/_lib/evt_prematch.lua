-- Shared prematch globals (research/grafts/_lib): `--@lib evt_prematch.lua#Head` at the top of the prematch_dock
-- and prematch_lineups snippets (graft_lib.expand_lib).
--@section Head
-- EVT prematch ----------------------------------------------------------------------------------
EVT_PREMATCH_LINEUPS = true       -- false = retail pre-match flow (kill switch); probe logs stay
EVT_PREMATCH_LOG = false          -- true: probe lines in evt_loader\loader.log (CMND_EVT_LOG, if the loader runs)
function EVT_PmLog(...)
  if EVT_PREMATCH_LOG then
    pcall(funcLuaCommand, @crc:CMND_EVT_LOG@, ...)
  end
end
function EVT_PmOnline()                  -- network match / observer: never change anything
  return funcLuaCommand(3959907440) == true or funcLuaCommand(1191545622) == true
end
-- EVT prematch end ------------------------------------------------------------------------------
