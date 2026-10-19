-- VRFW extra-time half label (rule engine): the scoreboard's half picture. The game draws «1.ª» for halves 1 and 3 and
-- «2.ª» for halves 2 and 4 (SwapLayerGamePhaseHalfIconTex, called by the engine at each period); in an extra-time
-- period of a ruleset's match (CMND_VRFW_RULE_ENGINE_BREAK = extra_time, before and during that period) halves 3 / 4
-- get «1.ª pr.» / «2.ª pr.» (gtxt_half_vrfw_et1 / _et2, content\images\menu\00_soccer\extra_time.toml). Any other
-- half: the retail picture. Wraps the function (after the retail one); no engine call at load time.
do
  local C = {
    BREAK = 2605035580,       -- CMND_VRFW_RULE_ENGINE_BREAK -> phase, number in the phase, periods of the phase
    SET_SPRITE = 558735651,
    LOG = 3661580131,         -- CMND_EVT_LOG
  }
  local ATLAS = 4109108046          -- #/menu/00_soccer/soccer00/soccer00_01/<LG>/soccer00_01.g4tx
  local DUMMY = 2834393702          -- gtxt_half01 (the label's mesh)
  local PIC = {[3] = 2822503542, [4] = 825404876}   -- gtxt_half_vrfw_et1 / _et2
  local logged = {}

  local prev = SwapLayerGamePhaseHalfIconTex
  if type(prev) == "function" and VRFW_ExtraTimeHalfLabel ~= SwapLayerGamePhaseHalfIconTex then
    VRFW_ExtraTimeHalfLabel = function(a1, ...)
      local r = table.pack(prev(a1, ...))
      local pic = PIC[a1]
      if pic ~= nil then
        local ok, phase = pcall(funcLuaCommand, C.BREAK)
        if ok and phase == "extra_time" and type(LAYER_NAME_CRC_SCOREBOARD) == "number" then
          pcall(funcLuaMenuCommand, C.SET_SPRITE, LAYER_NAME_CRC_SCOREBOARD, ATLAS, pic, DUMMY, 0)
          if not logged[a1] then
            logged[a1] = true
            pcall(funcLuaCommand, C.LOG, "VRFW extra_time half label", tostring(a1))
          end
        end
      end
      return table.unpack(r, 1, r.n)
    end
    SwapLayerGamePhaseHalfIconTex = VRFW_ExtraTimeHalfLabel
  end
end
