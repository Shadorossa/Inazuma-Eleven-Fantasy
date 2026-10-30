-- Battle Bay Deluxe «Reto diario», Battle Bay top menu (bb_stadium_top_menu; docs/game/modes/bb-daily-challenge.md).
--   * The «Campaña» row opens a small menu first (the Torneo / Liga panel's window, BBT_Choose): the campaign entry
--     (the retail Campaña, or the running Torneo / Liga: «Continuar …», its SIGUIENTE badge unchanged) and «Reto
--     diario». The row decided by the top bar or the mode selector (BattleBayDeluxe.TournamentState.row_mode) skips it.
--   * «Reto diario» starts the run's next match at once: it lends the campaign block to the run
--     (CMND_BBD_DAILY_PREPARE) and sends the game's campaign «continue» request, as the Torneo's next match does. When
--     the run cannot be prepared, a one-row notice (evt_bbd_dc_unavailable).
--   * Every opening of this menu first syncs the run (CMND_BBD_DAILY_SYNC, before the Torneo's sync and the retail
--     OnInit): the Campaña's block back and the last run match's result recorded.
-- The date: the framework's daily service (VRFW_Daily.Period("day"), the UTC day) as YYYYMMDD. Keys, pad and mouse:
-- the retail sub window's own. Globals only (BattleBayDeluxe.DailyChallenge*); nothing runs at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.DailyChallenge = BattleBayDeluxe.DailyChallenge or {}
BattleBayDeluxe.DailyChallenge.PREPARE = @crc:CMND_BBD_DAILY_PREPARE@
BattleBayDeluxe.DailyChallenge.UNLOAD = @crc:CMND_BBD_DAILY_UNLOAD@
BattleBayDeluxe.DailyChallenge.SYNC = @crc:CMND_BBD_DAILY_SYNC@
BattleBayDeluxe.DailyChallengeState = { sync = false }

function BBDC_Id(key)
  return BBT_Crc("evt_bbd_dc_" .. key)
end

-- the UTC day of the framework's daily service: YYYYMMDD; nil without the service
function BBDC_Today()
  if type(VRFW_Daily) ~= "table" or type(VRFW_Daily.Period) ~= "function" then
    return nil
  end
  local _, _, label = VRFW_Daily.Period("day")
  local y, m, d = tostring(label or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if y == nil then
    return nil
  end
  return tonumber(y) * 10000 + tonumber(m) * 100 + tonumber(d)
end

-- the «Campaña» row of the list at (layer, index)
function BBDC_IsCampaignRow(l, i)
  if (l ~= BattleBayDeluxe.Tournament.LIST_MID and l ~= BattleBayDeluxe.Tournament.LIST_SMALL) or BattleBayDeluxe.TournamentHost.name ~= "bb_stadium_top_menu" then
    return false
  end
  local ok, info = pcall(GetLitItemInfo, l, i)
  return ok and info ~= nil and info.menuObjectName == BattleBayDeluxe.Tournament.ROW_CAMPAIGN
end

-- the «Campaña» row's menu: "campaign", "daily" or nil (cancelled). Runs in the decide's coroutine.
function BBDC_CampaignMenu()
  local t = BBT_Info()
  local first = BBDC_Id("campaign")
  if t.active then
    first = BBT_Id(BBT_RunKey("continue", t.fmt == 2))
  end
  local c = BBT_Choose({ first, BBDC_Id("daily") }, 0)
  if c == 0 then
    return "campaign"
  elseif c == 1 then
    return "daily"
  end
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
  return nil
end

-- the sub window fully gone (a window opened right after another one reads the old one's close)
function BBDC_WindowGone()
  local g = 0
  while funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW) == true and g < 300 do
    g = g + 1
    coroutine.yield()
  end
  for _ = 1, 6 do
    coroutine.yield()
  end
end

-- the one-row notice when the day's run cannot be prepared
function BBDC_Unavailable(why)
  BBT_Log("daily: not available:", tostring(why))
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
  BBT_Choose({ BBDC_Id("unavailable") }, 0)
end

-- «Reto diario»: the run's next match on the lent campaign block, the game's campaign «continue» request (the request
-- and the way out of this menu are the Torneo's next match's, BBT_PlayNext); true when the match was requested
function BBDC_Play()
  local date = BBDC_Today()
  if date == nil then
    BBDC_Unavailable("no daily service")
    return false
  end
  local prep = BBT_Call(BattleBayDeluxe.DailyChallenge.PREPARE, date)
  if type(prep) ~= "table" or not prep.ok then
    BBDC_Unavailable(type(prep) == "table" and prep.why or "busy")
    return false
  end
  -- the run's matches play the match row's own rules (no rulebook a Torneo selected before)
  pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, "")
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  local ret = funcLuaMenuCommand(2227512519)
  BBT_Log("daily: match", (prep.k or 0) + 1, "requested", tostring(ret))
  if not ret then
    BBT_Call(BattleBayDeluxe.DailyChallenge.UNLOAD)
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return false
  end
  pcall(BattleBayDeluxe.TournamentHost.before_match)
  funcLuaMenuCommand(1558704558 --[[CMND_SET_MENU_ACTIVE?]], BattleBayDeluxe.TournamentHost.menu, false)
  if type(BrightFadeAllMenu) == "function" then
    BrightFadeAllMenu(3578114327 --[[fade_menu_encount_campaign]], true)
  end
  funcLuaCommand(769636339, 0.5)
  if BattleBayDeluxe.TournamentHost.menu ~= 811496143 then
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, BattleBayDeluxe.TournamentHost.menu, true)
  end
  funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, 811496143 --[[soccer_top_menu]])
  return true
end

-- a sync answer (the result itself is recorded by CMND_BBD_DAILY_SYNC; the game's result screen showed the score)
function BBDC_Synced(r)
  BattleBayDeluxe.DailyChallengeState.sync = false
  if type(r) == "table" and r.event ~= nil and r.event ~= "none" then
    BBT_Log("daily: back from a run match:", tostring(r.event))
  end
end

-- the sync again while the scripts were busy at OnInit
function BBDC_Step()
  if BattleBayDeluxe.TournamentHost.name ~= "bb_stadium_top_menu" or not BattleBayDeluxe.DailyChallengeState.sync then
    return
  end
  local r = BBT_Call(BattleBayDeluxe.DailyChallenge.SYNC)
  if r ~= nil then
    BBDC_Synced(r)
  end
end

-- ------------------------------------------------------------------------------------------------ wraps

do
  local init = OnInit
  function OnInit(...)
    BattleBayDeluxe.DailyChallengeState.sync = false
    local r = BBT_Call(BattleBayDeluxe.DailyChallenge.SYNC)
    if r ~= nil then
      BBDC_Synced(r)
    else
      BattleBayDeluxe.DailyChallengeState.sync = true   -- the scripts were busy: again from Step
    end
    return init(...)
  end

  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if not BattleBayDeluxe.TournamentState.open and BattleBayDeluxe.TournamentState.row_mode == nil and BBDC_IsCampaignRow(a1, a2) then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      local pick = BBDC_CampaignMenu()
      if pick == "campaign" then
        BBDC_WindowGone()
        return decide(a1, a2, ...)
      elseif pick == "daily" then
        BBDC_WindowGone()
        local ok, err = pcall(BBDC_Play)
        if not ok then
          BBT_Log("daily: error", tostring(err))
        end
      end
      return 1
    end
    return decide(a1, a2, ...)
  end

  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    local ok, err = pcall(BBDC_Step)
    if not ok and BattleBayDeluxe.DailyChallengeState.step_error ~= err then
      BattleBayDeluxe.DailyChallengeState.step_error = err
      BBT_Log("daily: step error", tostring(err))
    end
    return table.unpack(r, 1, r.n)
  end
end
