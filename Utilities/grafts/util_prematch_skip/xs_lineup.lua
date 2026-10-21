--@lib util_xskip.lua#Head
-- Utilities pre-match X skip, lineup side (soccer_battle_setting_flow_formation_menu: the own / rival lineup screens
-- of BattleSettingFlow state 13, after the walk-in, the last pre-match step). The native flow only waits for this menu
-- to close (docs/game/modes/prematch-lineups.md §1, §4), so with GO set (X was held in a walk-in event) no screen is
-- opened: the retail way out (StartGoToSoccerGame: fade out, close) runs as soon as the layers are loaded, and the
-- match goes on to the kick-off. Either way the pre-match is over here: disarmed.
-- What the two skipped screens would have done is done first, as SeqFormationScreen does it: the rival screen's
-- CMND 0x7185C961 (handler 0xC8CE60 -> 0x16E1360, its only caller: the match's own BGM, picked by the game from the
-- match / stadium; without it the walk-in music went on into the match, Nacho's report 2026-10-11) and the own
-- screen's PARAM 0x69DEF7B1 = true (native state 14 turns the camera to the rival side and deletes it).
-- The black cover of the X skip (fade layer 1, xs_event.lua) stays up while the layers load (Step below; the framework
-- also holds it against the flow's state 13 fade-in): then the retail fade layer 0 is set black at once and the cover
-- comes off in the same frame, so the screen stays black and the retail kick-off fade in (layer 0) is the only fade
-- seen. BetterUI 1.21.7 direct jump (JUMP set): the group is closed by the next Step the way GoToSoccerGame closes it,
-- without its fade out. Since 1.22.3 the jump runs under the cover too, so the same handover applies: layer 0 black,
-- cover off, and the lineup / kick-off cameras of states 13 -> 14 are not seen. Wrappers only.
local UTIL_XS_MATCH_BGM = 1904593249      -- CMND 0x7185C961: the match BGM (retail: SeqFormationScreen, rival screen)
local UTIL_XS_RIVAL_SHOWN = 1776220081    -- PARAM 0x69DEF7B1 (retail: set when the own screen closes)

local util_xs_close_now = false            -- direct jump: the menu is closed by the next Step, without a fade

local util_xs_prev_loaded = OnLayerLoadCompleted
function OnLayerLoadCompleted(...)
  local go = UTIL_XS.Get(UTIL_XS.GO) == 1
  local jump = go and UTIL_XS.Get(UTIL_XS.JUMP) == 1
  if go then
    pcall(funcLuaCommand, UTIL_XS.PARAM_SET, UTIL_XS_RIVAL_SHOWN, 0, true)
    pcall(funcLuaCommand, UTIL_XS_MATCH_BGM)
    UTIL_XS.Log("match BGM started (lineup screens skipped)")
    if UTIL_XS.Get(UTIL_XS.COVER) == 1 then
      pcall(funcLuaCommand, UTIL_XS.FADE, 1, 0)   -- layer 0 black now (StartGoToSoccerGame's fade out ends black)
      UTIL_XS.Set(UTIL_XS.BLACK0, 1)               -- checked again at the kick-off button (xs_restart.lua)
      UTIL_XS.Uncover(0, "lineup screens (layer 0 black)")
    end
  end
  UTIL_XS.Disarm("lineup screens")
  if jump then                           -- no fade at all: GoToSoccerGame's close, next Step (not inside this callback)
    util_xs_close_now = true
    UTIL_XS.Log("lineup screens skipped -> kick-off (direct jump: closed under black, kick-off fades in)")
    return
  end
  if go then
    UTIL_XS.Log("lineup screens skipped -> kick-off")
    StartGoToSoccerGame()
    return
  end
  return util_xs_prev_loaded(...)
end

-- While the lineup layers load under the cover (GO): keep it black, as event_menu's Step does during the events.
local util_xs_prev_step = Step
function Step(...)
  if util_xs_close_now then               -- the retail GoToSoccerGame minus its fade out: native state 14 goes on at once
    util_xs_close_now = false
    local ok, err = pcall(function()
      CloseCommonTimer()
      funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 1853845420 --[[soccer_battle_setting_flow_vs_menu]])
    end)
    UTIL_XS.Log("lineup group closed (direct jump)", tostring(ok), tostring(err))
    return
  end
  local ok, err = pcall(function()
    if UTIL_XS.Get(UTIL_XS.GO) == 1 and UTIL_XS.Get(UTIL_XS.COVER) == 1 then
      UTIL_XS.Cover(0)
      UTIL_XS.Hold()
    end
  end)
  if not ok then
    UTIL_XS.Log("lineup step error", tostring(err))
  end
  return util_xs_prev_step(...)
end
