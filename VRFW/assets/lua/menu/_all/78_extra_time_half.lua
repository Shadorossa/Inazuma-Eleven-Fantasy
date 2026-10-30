-- VRFW extra-time half label (rule engine): the scoreboard's half picture of the match HUD. The game draws «1.ª» for
-- halves 1 and 3 and «2.ª» for halves 2 and 4 (SwapLayerGamePhaseHalfIconTex of soccer_constant_menu_inc, called by
-- SetupScoreBoard when the scoreboard layer is set up at each period). In an extra-time period of a ruleset's match
-- (CMND_VRFW_RULE_ENGINE_BREAK = extra_time, number 1 / 2 in that phase) the label is «1.ª Pró.» / «2.ª Pró.»
-- (gtxt_half_vrfw_et1 / _et2, content\images\menu\00_soccer\extra_time.toml, 9 languages). Any other period: the
-- retail picture. Runs in every script VM (lua\_all) and only acts where the HUD include defined the function (the
-- match HUD soccer_constant_menu and the focus-battle HUD soccer_battle_constant_menu). Wraps the function (after the
-- retail one); no engine call at load time. One log line per change of what the label shows.
do
  local C = {
    BREAK = VRFW_Cmd.VRFW_RULE_ENGINE_BREAK,       -- CMND_VRFW_RULE_ENGINE_BREAK -> phase, number in the phase, periods of the phase
    SET_SPRITE = 558735651,
    LOG = VRFW_Cmd.EVT_LOG,         -- CMND_EVT_LOG
  }
  local ATLAS = 4109108046          -- #/menu/00_soccer/soccer00/soccer00_01/<LG>/soccer00_01.g4tx
  local DUMMY = 2834393702          -- gtxt_half01 (the label's mesh)
  local PIC = {2822503542, 825404876}   -- gtxt_half_vrfw_et1 / _et2 (extra-time half 1 / 2)
  local last = nil

  local prev = SwapLayerGamePhaseHalfIconTex
  if type(prev) == "function" and VRFW_ExtraTimeHalfLabel ~= SwapLayerGamePhaseHalfIconTex then
    VRFW_ExtraTimeHalfLabel = function(half, ...)
      local r = table.pack(prev(half, ...))
      local ok, phase, nth = pcall(funcLuaCommand, C.BREAK)
      local pic = nil
      if ok and phase == "extra_time" then
        pic = PIC[tonumber(nth) or 0]
      end
      local shown = "retail"
      if pic ~= nil and type(LAYER_NAME_CRC_SCOREBOARD) == "number" then
        local set = pcall(funcLuaMenuCommand, C.SET_SPRITE, LAYER_NAME_CRC_SCOREBOARD, ATLAS, pic, DUMMY, 0)
        shown = set and ("extra_time " .. tostring(nth)) or "extra_time (sprite NOT set)"
      end
      local key = tostring(half) .. " " .. shown
      if key ~= last then
        last = key
        pcall(funcLuaCommand, C.LOG, "VRFW extra_time half label", tostring(half), tostring(ok and phase or "?"), shown)
      end
      return table.unpack(r, 1, r.n)
    end
    SwapLayerGamePhaseHalfIconTex = VRFW_ExtraTimeHalfLabel
  end
end
