-- VRFW match break labels (rule engine): the half-time screen
-- (soccer_half_time_menu) before a period of a ruleset's end phases. The game only knows two halves: before the extra
-- time, its second half or the shoot-out it still read «MEDIO TIEMPO» and «COMENZAR 2.ª PARTE».
-- The rule engine says what comes next (CMND_VRFW_RULE_ENGINE_BREAK -> phase, number in the phase, periods of the
-- phase; "" = a regular half / no ruleset / the result screen: retail labels untouched) and the title
-- (soccer22_03_result_title / _text_results01) and the kick-off button (cmn03_01_cmd_back / _text_cmd_back01) get the
-- texts of VRFW text\rule.toml (break_*, 9 languages). Wraps OnOpenLayer only (after the retail one); no engine call at
-- load time.
do
  local C = {
    BREAK = VRFW_Cmd.VRFW_RULE_ENGINE_BREAK,      -- CMND_VRFW_RULE_ENGINE_BREAK
    TEXT = VRFW_Cmd.VRFW_TEXT_GET,        -- CMND_VRFW_TEXT_GET (id)
    TEXT_GAME = VRFW_Cmd.TEXT_GET,  -- CMND_TEXT_GET (the merged menu_text)
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,   -- CMND_SET_MENU_TEXT_STRING
    LOG = VRFW_Cmd.EVT_LOG,        -- CMND_EVT_LOG
  }
  local L_TITLE, M_TITLE = 1867151190, 1778263274   -- soccer22_03_result_title, _text_results01
  local L_BACK, M_BACK = 4198875882, 378327766       -- cmn03_01_cmd_back, _text_cmd_back01
  -- crc32("match_engine.<key>") of the break_* keys
  local TITLE = {
    extra_time = 1431712048,       -- break_title_extra_time
    extra_time_half = 3761565035,  -- break_title_extra_time_half
    golden_goal = 2316818337,      -- break_title_golden_goal
    penalties = 3600765255,        -- break_title_penalties
  }
  local BUTTON = {
    extra_time_1 = 3865677811,     -- break_btn_extra_time_1
    extra_time_2 = 2137054793,     -- break_btn_extra_time_2
    golden_goal = 2163511436,      -- break_btn_golden_goal
    penalties = 1553911247,        -- break_btn_penalties
  }

  local function text(id)
    if id == nil then return nil end
    local ok, s = pcall(funcLuaCommand, C.TEXT, id)
    if not ok or type(s) ~= "string" or s == "" then
      ok, s = pcall(funcLuaCommand, C.TEXT_GAME, id)
    end
    return ok and type(s) == "string" and s ~= "" and s or nil
  end

  -- the next period's phase and number, nil out of the ruleset's end phases
  local function next_period()
    local ok, phase, nth = pcall(funcLuaCommand, C.BREAK)
    if not ok or type(phase) ~= "string" or phase == "" then return nil end
    return phase, tonumber(nth) or 1
  end

  local function relabel(layer, idx)
    local phase, nth = next_period()
    if phase == nil then return end
    local id, mesh
    if layer == L_TITLE then
      mesh = M_TITLE
      id = (phase == "extra_time" and nth >= 2) and TITLE.extra_time_half or TITLE[phase]
    else
      mesh = M_BACK
      id = phase == "extra_time" and (nth >= 2 and BUTTON.extra_time_2 or BUTTON.extra_time_1) or BUTTON[phase]
    end
    local s = text(id)
    if s == nil then
      pcall(funcLuaCommand, C.LOG, "VRFW match_break", "no text", tostring(phase), tostring(nth), tostring(id))
      return
    end
    if layer == L_TITLE then
      funcLuaMenuCommand(C.SET_TEXT, layer, mesh, s)
    else
      funcLuaMenuCommand(C.SET_TEXT, layer, mesh, s, idx)
    end
    pcall(funcLuaCommand, C.LOG, "VRFW match_break", tostring(phase), tostring(nth), layer == L_TITLE and "title" or "button")
  end

  local prev = OnOpenLayer
  if type(prev) == "function" and VRFW_MatchBreakOpen ~= OnOpenLayer then
    VRFW_MatchBreakOpen = function(a1, a2, ...)
      prev(a1, a2, ...)
      if a1 == L_TITLE or a1 == L_BACK then
        pcall(relabel, a1, a2)
      end
    end
    OnOpenLayer = VRFW_MatchBreakOpen
  end
end
