-- Career stats of the mod Utilities (utilities.dll, feature career; docs/game/mechanics/player-career-stats.md): the
-- plugin follows the match from the HUD. OnInit = kick-off (CMND_BETTERQOL_CAREER_MATCH 1), Step = one tick per frame (0):
-- the plugin reads the ball owner, the goal lists and the members on the pitch from the engine and records the match
-- on the full-time result. Wrappers only (once per VM); no engine call while the chunk loads.
do
  UTIL_CSM = UTIL_CSM or {}
  local M = UTIL_CSM
  M.CMD = 1076897207 -- CMND_BETTERQOL_CAREER_MATCH
  M.WRAPPED = M.WRAPPED or {}
  local function wrap(name, make)
    local cur = _ENV[name]
    if type(cur) ~= "function" or M.WRAPPED[cur] then
      return
    end
    local w = make(cur)
    M.WRAPPED[w] = true
    _ENV[name] = w
  end
  wrap("OnInit", function(orig)
    return function(...)
      local r = orig(...)
      local ok, v = pcall(funcLuaCommand, M.CMD, 1)
      M.ON = ok and type(v) == "number"
      return r
    end
  end)
  wrap("Step", function(orig)
    return function(...)
      local r = orig(...)
      if M.ON then
        local ok, v = pcall(funcLuaCommand, M.CMD, 0)
        if not ok or type(v) ~= "number" then
          M.ON = false
        end
      end
      return r
    end
  end)
end
