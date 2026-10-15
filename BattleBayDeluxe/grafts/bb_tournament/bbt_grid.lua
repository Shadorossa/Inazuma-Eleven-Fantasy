-- bb_chronicle_teams bb_tournament, the Campaña team grid (enjoy_team_select_menu_campaign; docs/game/modes/bb-tournament.md
-- §4). Only while a tournament is armed (the Battle Bay top menu's «Torneo» row): the grid is the Campaña's own (pick
-- the team, the Draft tile too; then the difficulty window), with two steps of the tournament:
--   * the team's decide first opens the tournament options: BBD 1.5.10, the retail two-row L / R sub window with a
--     button (layout 3, as the online room's rank condition window: centred, no icon slot): «Con fase de grupos» Sí /
--     No, «Número de equipos» (powers of two, 1.5.15), «Filtrar equipos poco importantes» Sí / No (1.5.16: a third L / R
--     row, the window's own 3-row locator: bbt_common.lua BBT_SW_ThirdRow); left / right (OnMoveSubIndex callback BBT_GridOptMove) and Accept on a row
--     (the sub window's OnEnter, bbt_common.lua, through the parameter store) change the value in place; the button
--     «Empezar el torneo» confirms them (CMND_BBD_TOURN_ARM(fmt, size, 1, filter)) and goes on with the retail decide (the
--     difficulty window; the Draft screen for the Draft tile); Back = back to the grid. (1.5.4-1.5.9: a list window of
--     layout 20, the Campaña's continue window: top left, the Campaña team's crest, Accept closed it.)
--   * the difficulty window's start draws the tournament: scripts\campaign.lua's Decide hook refuses the game's own
--     start and keeps the drawn run, this file sends the difficulty (GetSelectDifficultyIdx() + 1, as the native getter
--     answers) with CMND_BBD_TOURN_START, the grid closes and the top menu shows the bracket (match 1 = its Enter). If
--     the game started its own campaign anyway (the scripts were busy for the Decide hook), the retail start goes on (a
--     plain Campaña: logged).
-- The tournament's state is the last CMND_BBD_TOURN_INFO, refreshed from Step (the commands may find the scripts busy).
-- Globals only (BBT_G*); nothing runs at chunk load.
BBT.ARM = @crc:CMND_BBD_TOURN_ARM@
BBT.START = @crc:CMND_BBD_TOURN_START@
BBT.GRID = 106197494 --[[vs01_43_enjoy_team_select_emblem_icon]]
BBT.START_BTN = 336167129 --[[cmn03_05_cmn_button_b_graphic_text]]
BBT.GRID_MENU = 786045682 --[[enjoy_team_select_menu]]
BBT_G = { co = nil, frames = 0, fmt = 0, size = 16, filter = 0 }
-- 1.5.64: the Torneo's group-stage menu (bbt_top.lua BBT.GM) never belongs over this grid: closed when found here
BBT.GROUPS_MENU = @crc:evt_bbd_tn_groups_menu@
BBT.GROUPS_CLOSE = @crc:evt_bbd_tn_groups_close@
BBT.OPT_ROWS = 3   -- the options' L / R rows: group stage, team count, minor teams filter (1.5.16)

BBT.SUB_LR_TEXT = 348737310   -- a row's value text of the L / R sub window (row, text id, "", true)
BBT.P_OPEN = @crc:evt_bbd_tn_panel_open@     -- parameter store: the options panel is open (read by the sub window)
BBT.P_ENTER = @crc:evt_bbd_tn_panel_enter@   -- parameter store: Accept on a row (row + 1), written by the sub window
-- 1.5.15 (owner: no byes, ever): the team counts offered = the tournament's own list for the format (powers of two,
-- capped by the teams the last campaign pool fields: CMND_BBD_TOURN_INFO .sizes); never a list of its own here
BBT_G.sizes = { knockout = {}, groups = {} }

function BBT_GridSizes()
  local l = BBT_G.sizes[BBT_G.fmt == 1 and "groups" or "knockout"]
  if type(l) ~= "table" then
    return {}
  end
  return l
end

-- the size snapped to the format's list: kept when offered, else the largest offered not above it, else the smallest
function BBT_GridSnapSize()
  local l = BBT_GridSizes()
  if #l == 0 then
    return
  end
  local best = nil
  for _, v in ipairs(l) do
    if v == BBT_G.size then
      return
    end
    if v <= BBT_G.size then
      best = v
    end
  end
  BBT_G.size = best or l[1]
end

function BBT_GParamDel(k)
  pcall(funcLuaCommand, 3363400568 --[[param delete]], k)
end

function BBT_GridOptId(row)
  if row == 0 then
    return BBT_Id("opt_groups_" .. tostring(BBT_G.fmt))
  elseif row == 2 then
    return BBT_Id("opt_filter_" .. tostring(BBT_G.filter))
  end
  return BBT_Id("opt_size_" .. tostring(BBT_G.size))
end

-- the sub window's L / R callback (MENU_DEF move-sub-index; dir 1 = right) and Accept on a row (dir 1): the value
-- changes in place
function BBT_GridOptMove(row, dir)
  local G = BBT_G
  if row == 0 then
    G.fmt = 1 - G.fmt
    -- the other format may not offer the count shown (a group stage needs 8 or more): its row follows
    local before = G.size
    BBT_GridSnapSize()
    if G.size ~= before then
      funcLuaMenuCommand(BBT.SUB_LR_TEXT, 1, BBT_GridOptId(1), "", true)
    end
  elseif row == 1 then
    local l = BBT_GridSizes()
    local n, k = #l, 1
    if n == 0 then
      return
    end
    for i, v in ipairs(l) do
      if v == G.size then
        k = i
      end
    end
    k = k + ((dir == 1) and 1 or -1)
    if k > n then
      k = 1
    elseif k < 1 then
      k = n
    end
    G.size = l[k]
  elseif row == 2 then
    G.filter = 1 - G.filter
  else
    return
  end
  funcLuaCommand(1917805374, 3791946501 --[[sy0004]])
  funcLuaMenuCommand(BBT.SUB_LR_TEXT, row, BBT_GridOptId(row), "", true)
end

-- the sub window's list-item refresh (MENU_DEF update-list-item callback): the panel's dress again (1.5.12)
function BBT_GridOptItem(a1, a2)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.SUB_WINDOW, "BBT_SW_PanelDress", BBT.OPT_ROWS)
end

-- the sub window's end: -1 = Back (the window closes itself), else the button (closed here, as the retail room window)
function BBT_GridOptDone(r)
  BBT_G.opt_result = r
  if r ~= -1 then
    funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], BBT.SUB_WINDOW)
  end
end

-- the grid menu's own cursor arrow shown / hidden (called from the grid's script: the popup is another menu)
function BBT_GridCursor(on)
  pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], 2296367164 --[[cmn05_01_cursor]], 0, on)
end

-- the options panel; true = confirmed (the tournament armed with them). Runs in a coroutine.
function BBT_GridOptions()
  local info = BBT_Info()
  local G = BBT_G
  G.fmt = info.fmt or (info.defaults or {}).fmt or 0
  G.size = info.size or (info.defaults or {}).size or 16
  G.filter = info.filter or (info.defaults or {}).filter or 0
  if type(info.sizes) == "table" then
    G.sizes = info.sizes
  end
  BBT_GridSnapSize()
  G.opt_result = nil
  BBT_GParamDel(BBT.P_ENTER)
  BBT_GParamDel(BBT.P_OPEN)
  -- the panel's L / R row count (the sub window opens its third row and its 3-row locator from it, bbt_common.lua)
  pcall(funcLuaCommand, 3860611758 --[[param set]], BBT.P_OPEN, 0, BBT.OPT_ROWS)
  funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
  MENU_DEF.SetSubWindowCallback_MoveSubIndex("BBT_GridOptMove")
  MENU_DEF.SetSubwindowCallback_UpdateListItem("BBT_GridOptItem")
  -- 1.5.43 (owner): the team grid's own cursor arrow (cmn05_01_cursor of the grid menu) stayed drawn over the popup,
  -- a second green arrow beside the popup's own: hidden while the popup is open (again every frame, the grid's focus
  -- may show it), shown again when it closes
  BBT_GridCursor(false)
  MENU_DEF.OpenSubWindow("BBT_GridOptDone", "", BBT.OPT_ROWS, { BBT_GridOptId(0), BBT_GridOptId(1), BBT_GridOptId(2) },
    5, 0, { 1, 1, 1 }, 0, false, false, 3)
  local f = 0
  while funcLuaCommand(3693934564 --[[CMND_IS_OPEN_MENU_OBJECT]], BBT.SUB_WINDOW, 2296367164 --[[cmn05_01_cursor]])
    ~= true and f < 120 do
    f = f + 1
    coroutine.yield()
  end
  for row = 0, BBT.OPT_ROWS - 1 do
    funcLuaMenuCommand(BBT.SUB_LR_TEXT, row, BBT_GridOptId(row), "", true)
  end
  local start = BBT_Text("opt_start")
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.SUB_WINDOW, "UpdateTextSubListItemLR", 0, start, start,
    funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 932232033), funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 2223530141))
  -- 1.5.12: the online window's leftovers off (the rank icon slot of each row drew a white box) and its title
  -- «EQUIPOS» swapped for the retail «settings» title (bbt_common.lua BBT_SW_PanelDress)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.SUB_WINDOW, "BBT_SW_PanelDress", BBT.OPT_ROWS)
  local waited = 0
  while G.opt_result == nil and funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.SUB_WINDOW) do
    BBT_GridCursor(false)
    -- 1.5.64: the options window waiting for the player; every 5 s the state in the log (a freeze is seen there)
    waited = waited + 1
    if waited % 300 == 0 then
      BBT_Log("options: window still open after", waited, "frames; group tables menu open",
        funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GROUPS_MENU) == true)
      pcall(BBT_GridCloseGroups, "options window waiting")
    end
    local ok, has = pcall(funcLuaCommand, 2947612279 --[[param has]], BBT.P_ENTER)
    if ok and has == true then
      local okv, v = pcall(funcLuaCommand, 3522198769 --[[param get]], BBT.P_ENTER)
      BBT_GParamDel(BBT.P_ENTER)
      if okv and type(v) == "number" and v >= 1 then
        BBT_GridOptMove(v - 1, 1)
      end
    end
    coroutine.yield()
  end
  BBT_GridCursor(true)
  BBT_GParamDel(BBT.P_OPEN)
  BBT_GParamDel(BBT.P_ENTER)
  MENU_DEF.SetSubWindowCallback_MoveSubIndex("OnMoveSubIndex")
  MENU_DEF.SetSubwindowCallback_UpdateListItem("OnSubWindowUpdateListItem")
  local r = G.opt_result
  G.opt_result = nil
  if r == nil or r == -1 then
    BBT_Log("options: back to the grid")
    return false
  end
  local ok, why = BBT_Call(BBT.ARM, G.fmt, G.size, 1, G.filter)
  if ok == true then
    BBT_Log("options: start", G.fmt, G.size, G.filter)
    BBT_Info()
    return true
  end
  BBT_Log("options not armed", tostring(ok), tostring(why))
  return false
end

-- the start: the difficulty to the tournament, then the grid closes (the bracket shows on the top menu).
-- BBD 1.5.11: the start button's press never reaches this Lua when the tournament takes it: scripts\campaign.lua's
-- Decide hook draws the run and skips the native decide, which is what calls OnDecideFocus. So Step starts this
-- when CMND_BBD_TOURN_INFO says pending (drawn, waiting for the difficulty). Any failure = a message window.
function BBT_GridStart(a1, a2, prev)
  local idx = 0
  local okd, d = pcall(GetSelectDifficultyIdx)
  if okd and type(d) == "number" then
    idx = d
  end
  local r = BBT_Call(BBT.START, idx + 1)
  BBT_Log("start: difficulty", idx + 1, type(r) == "table" and tostring(r.ok) or "busy")
  if type(r) == "table" and r.ok == false and not r.waiting then
    BBT_GridFail("start refused: " .. tostring(r.why))
    return
  end
  local info
  for _ = 1, 120 do
    info = BBT_Info()
    if info.active or info.campaign then
      break
    end
    coroutine.yield()
  end
  if info.active then
    BBT_Log("start: the tournament runs, the grid closes (the bracket on the top menu)")
    funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
    funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], BBT.GRID_MENU)
    return
  end
  if info.campaign and prev ~= nil then
    BBT_Log("the game started its own campaign (the Decide hook did not run): a plain Campaña")
    prev(a1, a2)
    return
  end
  BBT_GridFail("no tournament after the start (log of scripts/tournament.lua)")
end

-- 1.5.64 (owner 2026-10-14: after the Torneo, its group tables stayed drawn over this grid and the next team pick
-- froze): the group-stage menu found open over the grid is closed (its close parameter, its own close call, the
-- engine's close); logged once per leftover. true = it was there.
function BBT_GridCloseGroups(why)
  if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GROUPS_MENU) ~= true then
    BBT_G.groups_left = nil
    return false
  end
  pcall(funcLuaCommand, 3363400568 --[[param delete]], BBT.GROUPS_CLOSE)
  pcall(funcLuaCommand, 3860611758 --[[param set]], BBT.GROUPS_CLOSE, 0, 1, 1)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.GROUPS_MENU, "BBG_Close", "over the team grid")
  pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], BBT.GROUPS_MENU)
  if not BBT_G.groups_left then
    BBT_G.groups_left = true
    BBT_Log("grid: the Torneo's group tables were still open over the team grid (" .. tostring(why) .. "): closed")
  end
  return true
end

-- a failed start: logged and shown (the retail message window), never a silent no-op
function BBT_GridFail(why)
  BBT_Log("start failed:", tostring(why))
  pcall(BBT_Window, BBT_Id("start_failed"), 1)
end

do
  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    local info = BBT_INFO or {}
    -- 1.5.64: the accept path in the log (layer, index, the tournament's state, menus over the grid)
    if a1 == BBT.GRID or a1 == BBT.START_BTN then
      pcall(function()
        local groups = BBT_GridCloseGroups("team accept")
        BBT_Log("grid accept: layer " .. tostring(a1) .. " index " .. tostring(a2) .. ", armed " .. tostring(info.armed) ..
          ", configured " .. tostring(info.configured) .. ", pending " .. tostring(info.pending) .. ", running coroutine " ..
          tostring(BBT_G.co ~= nil) .. ", group tables were open " .. tostring(groups) .. ", sub window open " ..
          tostring(funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.SUB_WINDOW) == true))
      end)
    end
    if BBT_G.co == nil and info.armed then
      if a1 == BBT.GRID and not info.configured then
        local args = table.pack(a1, a2, ...)
        BBT_G.co = coroutine.create(function()
          if BBT_GridOptions() then
            decide(table.unpack(args, 1, args.n))
          end
        end)
        return 1
      end
      if a1 == BBT.START_BTN and info.configured then
        BBT_G.start_sent = true
        BBT_G.co = coroutine.create(function()
          BBT_GridStart(a1, a2, decide)
        end)
        return 1
      end
    end
    return decide(a1, a2, ...)
  end

  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    local G = BBT_G
    G.watch = (G.watch or 0) + 1
    if G.watch % 30 == 0 then
      local okw, errw = pcall(BBT_GridCloseGroups, "grid watchdog")
      if not okw then
        BBT_Log("grid: group tables watchdog error", tostring(errw))
      end
    end
    if G.co ~= nil then
      local ok, err = coroutine.resume(G.co)
      if not ok then
        BBT_Log("grid error", tostring(err))
      end
      if not ok or coroutine.status(G.co) == "dead" then
        G.co = nil
      end
    else
      -- the tournament's state for the decides (the scripts may be busy at the decide itself); every 10 frames
      -- once the options are confirmed (the start press is seen through it: pending)
      G.frames = G.frames + 1
      local info = BBT_INFO or {}
      local every = (info.armed and info.configured) and 10 or 30
      if BBT_INFO == nil or G.frames % every == 1 then
        local t = BBT_Call(BBT.INFO)
        if type(t) == "table" then
          BBT_INFO = t
          info = t
        end
      end
      if not info.pending then
        G.start_sent = false
      end
      if info.pending and not G.start_sent then
        G.start_sent = true
        BBT_Log("start: the run is drawn (the start pressed), the difficulty goes to the tournament")
        G.co = coroutine.create(function()
          BBT_GridStart(nil, nil, nil)
        end)
      elseif type(info.failed) == "string" and info.failed ~= "" then
        local why = info.failed
        info.failed = nil
        G.co = coroutine.create(function()
          BBT_GridFail(why)
        end)
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
