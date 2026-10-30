-- BattleBayDeluxe bb_tournament, campaign end window (bb_stadium_campaign_end_window; docs/game/modes/bb-tournament.md
-- §5.3). After a won match the game asks «continue / back to the Battle Bay»; during a tournament both answers go back
-- to the Battle Bay top menu (choice 1): there the tournament records the result, simulates the round and shows the
-- results and the bracket before the next match (Enter there = the next match). Its «next stage» telop reads the
-- match number through the tournament (bbt_common.lua). Globals only; nothing runs at chunk load.
do
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if a1 == 2895249556 --[[cmn03_06_sel_button]] and a2 == 0 then
      local t = BBT_Info()
      if t.active and t.loaded then   -- a tournament match (not a Campaña match while a Torneo exists)
        BBT_Log("end window: continue -> back to the Battle Bay (tournament)")
        return decide(a1, 1, ...)
      end
    end
    return decide(a1, a2, ...)
  end
end
