-- BattleBayDeluxe bb_tournament, top menu part: the wraps of the menu's engine callbacks.
-- Appended after bbt_top.lua in graft.toml's order: the parts share one chunk and its locals.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}

-- ------------------------------------------------------------------------------------------------ wraps

do
  local init = OnInit
  function OnInit(...)
    BattleBayDeluxe.TournamentState.setup_frames = 0
    local ok, done = pcall(BBT_Sync)
    if not ok then
      BBT_Log("sync error", tostring(done))
    elseif not done then
      BattleBayDeluxe.TournamentState.sync, BattleBayDeluxe.TournamentState.sync_frames = true, 0   -- the scripts were busy: again from Step
    end
    -- the top bar's «Battle Bay» group row «Torneo» (content\menus\top_bar.toml): the title's Estadio BB request with
    -- the step bb_tournament; answered here: the «Campaña» row decided in Torneo mode once the list is ready (Step)
    if BattleBayDeluxe.TournamentHost.step ~= nil and type(VRFW_TopBarStep) == "function" then
      local oks, go = pcall(VRFW_TopBarStep, BattleBayDeluxe.TournamentHost.step)
      if oks and go then
        BattleBayDeluxe.TournamentState.step, BattleBayDeluxe.TournamentState.frames, BattleBayDeluxe.TournamentState.want = true, 0, false
        BBT_Log("top bar step: the Campaña row in Torneo mode")
      end
    end
    return init(...)
  end

  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if BattleBayDeluxe.TournamentState.open then
      -- 1.37.0: a decide on another layer (the menu's own focus came back over the anchor) is the overlay's Enter too
      if a1 ~= BattleBayDeluxe.Tournament.ANCHOR then
        if BattleBayDeluxe.TournamentState.stray_decide ~= a1 then
          BattleBayDeluxe.TournamentState.stray_decide = a1
          BBT_Log("overlay keys: decide on layer " .. tostring(a1) .. ": taken as the overlay's Enter, the anchor focused")
        end
        BBT_FocusAnchor()
      end
      BBT_OnEnter()
      return 1
    end
    -- 1.5.47: the «Campaña» row opens the Campaña screen in Torneo mode when a tournament runs (or ended, not shown
    -- yet) or the top bar / the header asked for the Torneo; else the retail Campaña (its header switches there)
    if (a1 == BattleBayDeluxe.Tournament.LIST_MID or a1 == BattleBayDeluxe.Tournament.LIST_SMALL) and BattleBayDeluxe.TournamentHost.name == "bb_stadium_top_menu" then
      local okl, info = pcall(GetLitItemInfo, a1, a2)
      if okl and info ~= nil and info.menuObjectName == BattleBayDeluxe.Tournament.ROW_CAMPAIGN then
        local mode = BattleBayDeluxe.TournamentState.row_mode
        BattleBayDeluxe.TournamentState.row_mode = nil
        local t = mode == "tournament"
        if mode == nil then
          local ti = BBT_Info()
          t = ti.active == true or ti.ended == true
        end
        if t then
          funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
          local ok, err = pcall(BBT_EntryTournament)
          if not ok then
            BBT_Log("entry error", tostring(err))
          end
          return 1
        end
        VRFW_Param.Clear(BBT_MODE_P_GO_T)
      end
    end
    return decide(a1, a2, ...)
  end

  local back = OnBack
  function OnBack(a1, ...)
    -- 1.52.0: Back on the league hub's dashboard = «Salir» (its coroutine closes the overlay)
    if BattleBayDeluxe.TournamentState.open and (BBT_HubKey("back") or BBT_HubCalKey("back")) then
      return 1
    end
    if BattleBayDeluxe.TournamentState.open and BattleBayDeluxe.TournamentState.section then
      BattleBayDeluxe.TournamentState.section = false
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
      return 1
    end
    if BattleBayDeluxe.TournamentState.open then
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 202039849 --[[sy0006]])
      BBT_Close()
      return 1
    end
    return back(a1, ...)
  end

  -- the badge's retail setup (the Campaña record), then the running Torneo / Liga's next match over it
  local setup_layer = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    local r = table.pack(setup_layer(a1, a2, ...))
    if a1 == BattleBayDeluxe.Tournament.BADGE then
      local ok, err = pcall(BBT_NextBadge, BBT_Info(), a2)
      if not ok then
        BBT_Log("badge error", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end

  local fn = OnFunction
  function OnFunction(a1, a2, ...)
    if BattleBayDeluxe.TournamentState.open then
      -- 1.52.0: the league hub's side menu (Up / Down / L1 / R1; 1.58.0: six rows, no X key), a left click
      if BBT_HubKey("function", a1) or BBT_HubCalKey("function", a1) then
        return 1
      end
      -- 1.58.0: the arrows have their own ids (the dashboard's focus); elsewhere they turn the pages as L1 / R1
      if a1 == BattleBayDeluxe.Tournament.HUB.FN_LEFT then
        a1 = BattleBayDeluxe.Tournament.FN_PREV
      elseif a1 == BattleBayDeluxe.Tournament.HUB.FN_RIGHT then
        a1 = BattleBayDeluxe.Tournament.FN_NEXT
      end
      if a1 == BattleBayDeluxe.Tournament.FN_PREV then
        BBT_Turn(-1)
      elseif a1 == BattleBayDeluxe.Tournament.FN_NEXT then
        BBT_Turn(1)
      end
      return 1
    end
    return fn(a1, a2, ...)
  end

  local step = Step
  function Step(...)
    local r = { step(...) }
    local S = BattleBayDeluxe.TournamentState
    if S.setup_frames ~= nil then
      S.setup_frames = S.setup_frames + 1
      if S.setup_frames >= BBT_SETUP_FRAMES then
        S.setup_frames = nil
        local okc, errc = pcall(BBT_SetupCheck)
        if not okc then
          BBT_Logger().once("setup_check_error", "setup check error", tostring(errc))
        end
      end
    end
    if S.open and S.champ then
      pcall(BBT_ChampStep)
    end
    if S.open and S.focus_watch ~= nil then
      local okf, errf = pcall(BBT_FocusWatch)
      if not okf then
        S.focus_watch = nil
        BBT_Logger().once("overlay_keys_error", "overlay keys error", tostring(errf))
      end
    end
    -- 1.5.60: the group stage's own menu, opened after an earlier one closed
    local okg, errg = pcall(BBT_GroupsStep)
    if not okg then
      BBT_Logger().once("groups_menu_error", "groups menu error", tostring(errg))
    end
    -- the bracket screen (the tree page): opened after an earlier one closed
    local okt, errt = pcall(VRFW_Bracket.Step)
    if not okt then
      BBT_Logger().once("tree_menu_error", "bracket menu error", tostring(errt))
    end
    -- 1.5.33: a bracket layer set up after the bracket opened (S.redraw): the page again
    if S.redraw then
      S.redraw = false
      if S.open and not S.champ then
        local ok, err = pcall(BBT_Draw, S.page)
        BBT_Log("late layer setup: page drawn again", S.page, ok and "" or tostring(err))
      end
    end
    if S.sync then
      S.sync_frames = S.sync_frames + 1
      local ok, done = pcall(BBT_Sync)
      if (ok and done) or S.sync_frames > 600 then
        S.sync = false
      end
    end
    -- the league hub's mouse / free cursor (before the coroutine: a click's action is taken this same Step)
    local okp, errp = pcall(BBT_HubPointerStep)
    if not okp then
      S.hub_ptr, S.hub_zones = nil, nil   -- off until the hub is drawn again
      BBT_Logger().once("hub_pointer_error", "hub pointer error", tostring(errp))
    end
    if S.co ~= nil then
      local ok, err = coroutine.resume(S.co)
      if not ok then
        BBT_Log("error", tostring(err))
      end
      if not ok or coroutine.status(S.co) == "dead" then
        S.co = nil
      end
    elseif S.step and not S.open then
      S.frames = S.frames + 1
      if S.frames > 600 then
        S.step = false
      elseif S.frames > 20 and funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, BattleBayDeluxe.Tournament.LIST_MID) == true
        and funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) ~= true then
        S.step = false
        local ok, err = pcall(BBT_DecideRow)
        if not ok then
          BBT_Log("top bar step error", tostring(err))
        end
      end
    elseif S.want and not S.open then
      S.frames = S.frames + 1
      -- 1.5.27 (owner: «Modos de juego» seen 1-2 s before the results): on a host with `cover` the screen stays black
      -- until the bracket is up (the wait was 20 Steps + the hub's own 0.5 s fade-in + its focus); then one fade-in
      local cover = BattleBayDeluxe.TournamentHost.cover == true
      if cover then
        funcLuaCommand(609722083 --[[fade black]], 1, 0)
      end
      if S.frames > 600 then
        S.want = false
        if cover then
          funcLuaCommand(609722083, 0, 0.3)
        end
      elseif S.frames > (cover and 2 or 20) and BattleBayDeluxe.TournamentHost.ready()
        and (cover or funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) ~= true) then
        S.want = false
        local ok, err = pcall(BBT_Open, -1)
        if not ok then
          BBT_Log("overlay error", tostring(err))
        end
        if cover then
          funcLuaCommand(609722083, 0, 0.3)
          BBT_Log("results shown under the cover after", S.frames, "Steps")
        end
      end
    end
    return table.unpack(r)
  end
end
