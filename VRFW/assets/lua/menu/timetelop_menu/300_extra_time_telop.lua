-- VRFW extra-time telops (rule engine): the period-end telop of a ruleset's match. The game has one period-end picture,
-- «FIN DE LA 1.ª PARTE» (telop type 7, gtxt_timetelop07): its HalfTime state shows it before every period the rule engine
-- adds. At that moment the engine's period end has already set the next half, so CMND_VRFW_RULE_ENGINE_BREAK names the
-- coming period: extra time 1 -> the regular time ended («FIN DE LA 2.ª PARTE», gtxt_timetelop_vrfw_reg_end); extra time
-- 2 -> «FIN DE LA 1.ª PARTE DE LA PRÓRROGA» (gtxt_timetelop_vrfw_et1_end); the shoot-out or a golden-goal period after
-- extra time -> the game's own «FIN DEL PARTIDO» (gtxt_timetelop_vrfw_full_end, made from soccer05_05 at build); the
-- same without extra time -> «FIN DE LA 2.ª PARTE». No ruleset, a regular half or the result: the retail picture.
-- Pictures: content\images\menu\00_soccer\extra_time.toml. Wraps the engine-called SetupTimeTelopInfo (decides once per
-- telop) and UpdateUseTextureTelop (sets the picture after the retail one); no engine call at load time.
do
  local C = {
    BREAK = 2605035580,       -- CMND_VRFW_RULE_ENGINE_BREAK -> phase, number in the phase, periods of the phase
    STATE = 3084109502,       -- CMND_EVT_MATCH_ENGINE_STATE -> phase, id, scores…, winner, extra time played, …
    SET_SPRITE = 558735651,
    LOG = 3661580131,         -- CMND_EVT_LOG
  }
  local L_TEXT = 852785315          -- soccer05_02_timetelop_text
  local ATLAS = 3297212849          -- #/menu/00_soccer/soccer05/soccer05_02/<LG>/soccer05_02.g4tx
  local DUMMY = 3127472322          -- gtxt_timetelop01 (the mesh every telop picture is drawn in)
  local PERIOD_END = 7              -- telop type: the end of a period
  local PIC = {
    reg_end = 3103382739,           -- gtxt_timetelop_vrfw_reg_end
    et1_end = 1700369862,           -- gtxt_timetelop_vrfw_et1_end
    full_end = 4261068378,          -- gtxt_timetelop_vrfw_full_end
  }
  local NAME = {[3103382739] = "reg_end", [1700369862] = "et1_end", [4261068378] = "full_end"}
  local want = nil

  -- the picture of the period end now (nil = the retail one)
  local function pick()
    local ok, phase, nth = pcall(funcLuaCommand, C.BREAK)
    if not ok or type(phase) ~= "string" or phase == "" then return nil end
    nth = tonumber(nth) or 1
    if phase == "extra_time" then
      return nth >= 2 and PIC.et1_end or PIC.reg_end
    end
    local r = table.pack(pcall(funcLuaCommand, C.STATE))
    return (r[1] and r[9] == true) and PIC.full_end or PIC.reg_end
  end

  local prev_setup = SetupTimeTelopInfo
  if type(prev_setup) == "function" and VRFW_ExtraTimeTelopSetup ~= SetupTimeTelopInfo then
    VRFW_ExtraTimeTelopSetup = function(a1, a2, a3, a4, ...)
      local r = table.pack(prev_setup(a1, a2, a3, a4, ...))
      want = nil
      if a4 == PERIOD_END then
        local ok, p = pcall(pick)
        want = ok and p or nil
        if want ~= nil then
          pcall(funcLuaCommand, C.LOG, "VRFW extra_time telop", NAME[want] or tostring(want))
        end
      end
      return table.unpack(r, 1, r.n)
    end
    SetupTimeTelopInfo = VRFW_ExtraTimeTelopSetup
  end

  local prev_tex = UpdateUseTextureTelop
  if type(prev_tex) == "function" and VRFW_ExtraTimeTelopTexture ~= UpdateUseTextureTelop then
    VRFW_ExtraTimeTelopTexture = function(...)
      local r = table.pack(prev_tex(...))
      if want ~= nil then
        pcall(funcLuaMenuCommand, C.SET_SPRITE, L_TEXT, ATLAS, want, DUMMY, 0)
      end
      return table.unpack(r, 1, r.n)
    end
    UpdateUseTextureTelop = VRFW_ExtraTimeTelopTexture
  end
end
