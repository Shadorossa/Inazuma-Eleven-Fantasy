-- Career stats of the mod Utilities (utilities.dll, feature career; docs/game/mechanics/player-career-stats.md): half
-- time (a1 = false) and the full-time result (a1 = true) of the match. The plugin records the match once
-- (CMND_UTIL_CAREER_MATCH 3); 2 only samples the pitch. A wrapper only (once per VM); no engine call while the chunk
-- loads.
do
  UTIL_CSR = UTIL_CSR or {}
  local M = UTIL_CSR
  M.WRAPPED = M.WRAPPED or {}
  local cur = InitResultParam
  if type(cur) == "function" and not M.WRAPPED[cur] then
    local w = function(a1, ...)
      local r = cur(a1, ...)
      pcall(funcLuaCommand, 2901266317 --[[CMND_UTIL_CAREER_MATCH]], a1 and 3 or 2)
      return r
    end
    M.WRAPPED[w] = true
    InitResultParam = w
  end
end
