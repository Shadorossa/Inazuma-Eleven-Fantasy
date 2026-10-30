-- Battle Bay Deluxe «Reto diario», campaign end window (bb_stadium_campaign_end_window; docs/game/modes/
-- bb-daily-challenge.md). After a won run match the game asks «continue / back to the Battle Bay»; during a run both
-- answers go back to the Battle Bay top menu (choice 1), whose sync gives the Campaña its block back before the next
-- match. Globals only; nothing runs at chunk load.
do
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if a1 == 2895249556 --[[cmn03_06_sel_button]] and a2 == 0 then
      if BBT_Call(@crc:CMND_BBD_DAILY_LOADED@) == true then
        BBT_Log("daily: end window: continue -> back to the Battle Bay")
        return decide(a1, 1, ...)
      end
    end
    return decide(a1, a2, ...)
  end
end
