--@lib clean_hud_xskip.lua#Head
-- Clean HUD pre-match X skip, lineup side (soccer_battle_setting_flow_formation_menu: the own / rival lineup screens
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
-- seen. BetterUI 1.21.7 direct jump (JUMP set, no cover): no fade at all, the group is closed by the next Step the
-- way GoToSoccerGame closes it, without its fade out; the kick-off then comes with nothing faded. Wrappers only.
local CHD_XS_MATCH_BGM = 1904593249      -- CMND 0x7185C961: the match BGM (retail: SeqFormationScreen, rival screen)
local CHD_XS_RIVAL_SHOWN = 1776220081    -- PARAM 0x69DEF7B1 (retail: set when the own screen closes)

local chd_xs_close_now = false            -- direct jump: the menu is closed by the next Step, without a fade

local chd_xs_prev_loaded = OnLayerLoadCompleted
function OnLayerLoadCompleted(...)
  local go = CHD_XS.Get(CHD_XS.GO) == 1
  local jump = go and CHD_XS.Get(CHD_XS.JUMP) == 1
  if go then
    pcall(funcLuaCommand, CHD_XS.PARAM_SET, CHD_XS_RIVAL_SHOWN, 0, true)
    pcall(funcLuaCommand, CHD_XS_MATCH_BGM)
    CHD_XS.Log("match BGM started (lineup screens skipped)")
    if CHD_XS.Get(CHD_XS.COVER) == 1 then
      pcall(funcLuaCommand, CHD_XS.FADE, 1, 0)   -- layer 0 black now (StartGoToSoccerGame's fade out ends black)
      CHD_XS.Uncover(0, "lineup screens (layer 0 black)")
    end
  end
  CHD_XS.Disarm("lineup screens")
  if jump then                           -- no fade at all: GoToSoccerGame's close, next Step (not inside this callback)
    chd_xs_close_now = true
    CHD_XS.Log("lineup screens skipped -> kick-off (direct jump: closed without a fade)")
    return
  end
  if go then
    CHD_XS.Log("lineup screens skipped -> kick-off")
    StartGoToSoccerGame()
    return
  end
  return chd_xs_prev_loaded(...)
end

-- While the lineup layers load under the cover (GO): keep it black, as event_menu's Step does during the events.
local chd_xs_prev_step = Step
function Step(...)
  if chd_xs_close_now then               -- the retail GoToSoccerGame minus its fade out: native state 14 goes on at once
    chd_xs_close_now = false
    local ok, err = pcall(function()
      CloseCommonTimer()
      funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 1853845420 --[[soccer_battle_setting_flow_vs_menu]])
    end)
    CHD_XS.Log("lineup group closed (direct jump)", tostring(ok), tostring(err))
    return
  end
  local ok, err = pcall(function()
    if CHD_XS.Get(CHD_XS.GO) == 1 and CHD_XS.Get(CHD_XS.COVER) == 1 then
      CHD_XS.Cover(0)
      CHD_XS.Hold()
    end
  end)
  if not ok then
    CHD_XS.Log("lineup step error", tostring(err))
  end
  return chd_xs_prev_step(...)
end
