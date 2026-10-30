-- BattleBayDeluxe bb_tournament, the Campaña team grid (enjoy_team_select_menu_campaign; docs/game/modes/bb-tournament.md
-- §4). Only while a tournament is armed (the Battle Bay top menu's «Torneo» row): the grid is the Campaña's own (pick
-- the team, the Draft tile too; then the difficulty window), with two steps of the tournament:
--   * the team's decide first opens the tournament options: BBD 1.5.10, the retail two-row L / R sub window with a
--     button (layout 3, as the online room's rank condition window: centred, no icon slot): «Con fase de grupos» Sí /
--     No, «Número de equipos» (powers of two, 1.5.15), «Filtrar equipos poco importantes» Sí / No (1.5.16: a third L / R
--     row, the window's own 3-row locator: bbt_common.lua BBT_SW_ThirdRow); left / right (OnMoveSubIndex callback BBT_GridOptMove) and Accept on a row
--     (the sub window's OnEnter, bbt_common.lua, through the parameter store) change the value in place; the button
--     «Empezar el torneo» confirms them (CMND_BBD_TOURN_ARM(fmt, size, 1, filter)) and goes on with the retail decide (the
--     difficulty window; the Draft screen for the Draft tile); Back = back to the grid. The «Liga» (format 2) has its
--     own rows in the same window (BBT_GRID_ROWS.league): «Número de equipos» (even counts), «Sin equipos menores»,
--     «Ida y vuelta» Sí / No, and the button «Empezar la liga». (1.5.4-1.5.9: a list window of
--     layout 20, the Campaña's continue window: top left, the Campaña team's crest, Accept closed it.)
--   * the difficulty window's start draws the tournament: scripts\campaign.lua's Decide hook refuses the game's own
--     start and keeps the drawn run, this file sends the difficulty (GetSelectDifficultyIdx() + 1, as the native getter
--     answers) with CMND_BBD_TOURN_START, the grid closes and the top menu shows the bracket (match 1 = its Enter). If
--     the game started its own campaign anyway (the scripts were busy for the Decide hook), the retail start goes on (a
--     plain Campaña: logged).
-- The tournament's state is the last CMND_BBD_TOURN_INFO, refreshed from Step (the commands may find the scripts busy).
-- Globals only (BattleBayDeluxe.TournamentGrid*); nothing runs at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.Tournament.ARM = @crc:CMND_BBD_TOURN_ARM@
BattleBayDeluxe.Tournament.START = @crc:CMND_BBD_TOURN_START@
BattleBayDeluxe.Tournament.GRID = 106197494 --[[vs01_43_enjoy_team_select_emblem_icon]]
BattleBayDeluxe.Tournament.START_BTN = 336167129 --[[cmn03_05_cmn_button_b_graphic_text]]
BattleBayDeluxe.Tournament.GRID_MENU = 786045682 --[[enjoy_team_select_menu]]
BattleBayDeluxe.TournamentGrid = { co = nil, frames = 0, fmt = 0, size = 16, filter = 0, double = 0, national = 0 }
-- 1.5.64: the Torneo's group-stage menu (bbt_top.lua BattleBayDeluxe.Tournament.GM) never belongs over this grid: closed when found here
BattleBayDeluxe.Tournament.GROUPS_MENU = @crc:evt_bbd_tn_groups_menu@
BattleBayDeluxe.Tournament.OPT_ROWS = 3   -- the options' L / R rows: group stage, team count, minor teams filter (1.5.16)
-- the options' rows per mode, top to bottom (the window has BattleBayDeluxe.Tournament.OPT_ROWS L / R rows) and the start button's text key:
-- groups = «Con fase de grupos», size = «Número de equipos», filter = «Equipos: Todos | Importantes | Personalizado»
-- (1.49.0; was «Sin equipos menores»: 0 all, 1 the minor teams filter, 2 the teams picked by hand, BBT_GridPick),
-- double = «Doble vuelta», national = «Sin selecciones nacionales»
BBT_GRID_ROWS = {
  tournament = { rows = { "groups", "size", "filter" }, start = "opt_start" },
  -- 1.48.0: + «Sin selecciones nacionales» (national; the window's 4-row locator, bbt_common.lua BBT_SW_LOC4)
  league = { rows = { "size", "filter", "national", "double" }, start = "opt_start_league" },
}

-- the options' L / R row count of the current mode
function BBT_GridRowCount()
  return #BBT_GRID_ROWS[BBT_GridMode()].rows
end

BattleBayDeluxe.Tournament.SUB_LR_TEXT = 348737310   -- a row's value text of the L / R sub window (row, text id, "", true)
BattleBayDeluxe.Tournament.P_OPEN = @crc:evt_bbd_tn_panel_open@     -- parameter store: the options panel is open (read by the sub window)
BattleBayDeluxe.Tournament.P_ENTER = @crc:evt_bbd_tn_panel_enter@   -- parameter store: Accept on a row (row + 1), written by the sub window
-- 1.5.15 (owner: no byes, ever): the team counts offered = the tournament's own list for the format (powers of two,
-- capped by the teams the last campaign pool fields: CMND_BBD_TOURN_INFO .sizes); never a list of its own here
BattleBayDeluxe.TournamentGrid.sizes = { knockout = {}, groups = {}, league = {} }
BattleBayDeluxe.TournamentGrid.FORMATS = { [0] = "knockout", [1] = "groups", [2] = "league" }

-- the options' mode: "league" (format 2) or "tournament" (knockout / groups)
function BBT_GridMode()
  return BattleBayDeluxe.TournamentGrid.fmt == 2 and "league" or "tournament"
end

-- what row `row` (0-based) of the options shows in the current mode
function BBT_GridRow(row)
  return BBT_GRID_ROWS[BBT_GridMode()].rows[row + 1]
end

function BBT_GridSizes()
  local key = BattleBayDeluxe.TournamentGrid.FORMATS[BattleBayDeluxe.TournamentGrid.fmt] or "knockout"
  -- 1.48.0: a league without the national sides offers the counts the rest of the pool fills
  if key == "league" and BattleBayDeluxe.TournamentGrid.national == 1 and type(BattleBayDeluxe.TournamentGrid.sizes.league_no_national) == "table" then
    key = "league_no_national"
  end
  local l = BattleBayDeluxe.TournamentGrid.sizes[key]
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
    if v == BattleBayDeluxe.TournamentGrid.size then
      return
    end
    if v <= BattleBayDeluxe.TournamentGrid.size then
      best = v
    end
  end
  BattleBayDeluxe.TournamentGrid.size = best or l[1]
end

function BBT_GParamDel(k)
  VRFW_Param.Clear(k)
end

function BBT_GridOptId(row)
  local what = BBT_GridRow(row)
  if what == "groups" then
    return BBT_Id("opt_groups_" .. tostring(BattleBayDeluxe.TournamentGrid.fmt))
  elseif what == "filter" then
    return BBT_Id("opt_teams_" .. tostring(BattleBayDeluxe.TournamentGrid.filter))
  elseif what == "size" and BattleBayDeluxe.TournamentGrid.filter == 2 then
    -- the teams picked by hand: their count (the player's team included), or «elige en el cuadro» when that count
    -- has no text of its own (no valid count yet)
    local n = BattleBayDeluxe.TournamentGrid.pick_n or 1
    local ok, t = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@, BBT_Id("opt_size_" .. n))
    if n >= 2 and ok and type(t) == "string" and t ~= "" then
      return BBT_Id("opt_size_" .. n)
    end
    return BBT_Id("opt_size_pick")
  elseif what == "double" then
    return BBT_Id("opt_double_" .. tostring(BattleBayDeluxe.TournamentGrid.double))
  elseif what == "national" then
    return BBT_Id("opt_national_" .. tostring(BattleBayDeluxe.TournamentGrid.national))
  end
  return BBT_Id("opt_size_" .. tostring(BattleBayDeluxe.TournamentGrid.size))
end

-- the row (0-based) that shows `what` in the current mode, nil when none
function BBT_GridRowOf(what)
  for i, w in ipairs(BBT_GRID_ROWS[BBT_GridMode()].rows) do
    if w == what then
      return i - 1
    end
  end
  return nil
end

-- the sub window's L / R callback (MENU_DEF move-sub-index; dir 1 = right) and Accept on a row (dir 1): the value
-- changes in place
function BBT_GridOptMove(row, dir)
  local G = BattleBayDeluxe.TournamentGrid
  local what = BBT_GridRow(row)
  if what == "groups" then
    G.fmt = 1 - G.fmt
    -- the other format may not offer the count shown (a group stage needs 8 or more): its row follows
    local before = G.size
    BBT_GridSnapSize()
    local srow = BBT_GridRowOf("size")
    if G.size ~= before and srow ~= nil then
      funcLuaMenuCommand(BattleBayDeluxe.Tournament.SUB_LR_TEXT, srow, BBT_GridOptId(srow), "", true)
    end
  elseif what == "size" and G.filter == 2 then
    -- picked by hand: the count is the picks'
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return
  elseif what == "size" then
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
  elseif what == "filter" then
    G.filter = (G.filter + ((dir == 1) and 1 or 2)) % 3
    if G.filter == 2 then
      BBT_GridPickCount()
    end
    local srow = BBT_GridRowOf("size")
    if srow ~= nil then
      funcLuaMenuCommand(BattleBayDeluxe.Tournament.SUB_LR_TEXT, srow, BBT_GridOptId(srow), "", true)
    end
  elseif what == "double" then
    G.double = 1 - G.double
  elseif what == "national" then
    G.national = 1 - G.national
    -- the pool without the national sides may not fill the count shown: its row follows
    local before = G.size
    BBT_GridSnapSize()
    local srow = BBT_GridRowOf("size")
    if G.size ~= before and srow ~= nil then
      funcLuaMenuCommand(BattleBayDeluxe.Tournament.SUB_LR_TEXT, srow, BBT_GridOptId(srow), "", true)
    end
  else
    return
  end
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3791946501 --[[sy0004]])
  funcLuaMenuCommand(BattleBayDeluxe.Tournament.SUB_LR_TEXT, row, BBT_GridOptId(row), "", true)
end

-- the sub window's list-item refresh (MENU_DEF update-list-item callback): the panel's dress again (1.5.12)
function BBT_GridOptItem(a1, a2)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BattleBayDeluxe.Tournament.SUB_WINDOW, "BBT_SW_PanelDress", BBT_GridRowCount())
end

-- the sub window's end: -1 = Back (the window closes itself), else the button (closed here, as the retail room window)
function BBT_GridOptDone(r)
  BattleBayDeluxe.TournamentGrid.opt_result = r
  if r ~= -1 then
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW)
  end
end

-- the grid menu's own cursor arrow shown / hidden (called from the grid's script: the popup is another menu)
function BBT_GridCursor(on)
  pcall(funcLuaMenuCommand, @crc:CMND_SET_LAYER_VISIBLE@, 2296367164 --[[cmn05_01_cursor]], 0, on)
end

-- the options panel; true = confirmed (the tournament armed with them). Runs in a coroutine. 1.49.0: the picker of
-- «Personalizado» in between (the window closes for it and opens again with the values kept)
function BBT_GridOptions()
  local G = BattleBayDeluxe.TournamentGrid
  G.keep = false
  while true do
    local r = BBT_GridOptionsOnce()
    if r ~= "pick" then
      G.keep = false
      return r
    end
    G.keep = true
    BBT_GridPick()
  end
end

function BBT_GridOptionsOnce()
  local info = BBT_Info()
  local G = BattleBayDeluxe.TournamentGrid
  if G.keep then
    info = { sizes = G.sizes }
  end
  if not G.keep then
    G.fmt = info.fmt or (info.defaults or {}).fmt or 0
    G.size = info.size or (info.defaults or {}).size or 16
    G.filter = info.filter or (info.defaults or {}).filter or 0
    G.double = info.double or (info.defaults or {}).double or 0
    G.national = info.no_national or (info.defaults or {}).no_national or 0
    if type(info.sizes) == "table" then
      G.sizes = info.sizes
    end
  end
  G.want_pick = false
  BBT_GridSnapSize()
  if G.filter == 2 then
    BBT_GridPickCount()
  end
  G.opt_result = nil
  BBT_GParamDel(BattleBayDeluxe.Tournament.P_ENTER)
  BBT_GParamDel(BattleBayDeluxe.Tournament.P_OPEN)
  -- the panel's L / R row count (the sub window opens its third row and its 3-row locator from it, bbt_common.lua)
  local nrows = BBT_GridRowCount()
  VRFW_Param.Set(BattleBayDeluxe.Tournament.P_OPEN, nrows, "plain")
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  MENU_DEF.SetSubWindowCallback_MoveSubIndex("BBT_GridOptMove")
  MENU_DEF.SetSubwindowCallback_UpdateListItem("BBT_GridOptItem")
  -- 1.5.43 (owner): the team grid's own cursor arrow (cmn05_01_cursor of the grid menu) stayed drawn over the popup,
  -- a second green arrow beside the popup's own: hidden while the popup is open (again every frame, the grid's focus
  -- may show it), shown again when it closes
  BBT_GridCursor(false)
  local ids, enabled = {}, {}
  for row = 0, nrows - 1 do
    ids[row + 1], enabled[row + 1] = BBT_GridOptId(row), 1
  end
  MENU_DEF.OpenSubWindow("BBT_GridOptDone", "", nrows, ids, 5, 0, enabled, 0, false, false, 3)
  local f = 0
  while funcLuaCommand(@crc:CMND_IS_OPEN_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW, 2296367164 --[[cmn05_01_cursor]])
    ~= true and f < 120 do
    f = f + 1
    coroutine.yield()
  end
  for row = 0, nrows - 1 do
    funcLuaMenuCommand(BattleBayDeluxe.Tournament.SUB_LR_TEXT, row, BBT_GridOptId(row), "", true)
  end
  local start = BBT_Text(BBT_GRID_ROWS[BBT_GridMode()].start)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BattleBayDeluxe.Tournament.SUB_WINDOW, "UpdateTextSubListItemLR", 0, start, start,
    funcLuaCommand(@crc:CMND_TEXT_GET@, 932232033), funcLuaCommand(@crc:CMND_TEXT_GET@, 2223530141))
  -- 1.5.12: the online window's leftovers off (the rank icon slot of each row drew a white box) and its title
  -- «EQUIPOS» swapped for the retail «settings» title (bbt_common.lua BBT_SW_PanelDress)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BattleBayDeluxe.Tournament.SUB_WINDOW, "BBT_SW_PanelDress", BBT_GridRowCount())
  local waited = 0
  while G.opt_result == nil and funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW) do
    BBT_GridCursor(false)
    -- 1.5.64: the options window waiting for the player; every 5 s the state in the log (a freeze is seen there)
    waited = waited + 1
    if waited % 300 == 0 then
      BBT_Log("options: window still open after", waited, "frames; group tables menu open",
        funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BattleBayDeluxe.Tournament.GROUPS_MENU) == true)
      pcall(BBT_GridCloseGroups, "options window waiting")
    end
    if VRFW_Param.Has(BattleBayDeluxe.Tournament.P_ENTER) then
      local v = VRFW_Param.Get(BattleBayDeluxe.Tournament.P_ENTER)
      BBT_GParamDel(BattleBayDeluxe.Tournament.P_ENTER)
      if type(v) == "number" and v >= 1 then
        if BBT_GridRow(v - 1) == "filter" and G.filter == 2 then
          -- 1.49.0: «Personalizado» + Accept = the team picker on the grid (the options window again after it)
          G.want_pick = true
          funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
          funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW)
        else
          BBT_GridOptMove(v - 1, 1)
        end
      end
    end
    coroutine.yield()
  end
  BBT_GridCursor(true)
  BBT_GParamDel(BattleBayDeluxe.Tournament.P_OPEN)
  BBT_GParamDel(BattleBayDeluxe.Tournament.P_ENTER)
  MENU_DEF.SetSubWindowCallback_MoveSubIndex("OnMoveSubIndex")
  MENU_DEF.SetSubwindowCallback_UpdateListItem("OnSubWindowUpdateListItem")
  local r = G.opt_result
  G.opt_result = nil
  if G.want_pick then
    G.want_pick = false
    return "pick"
  end
  if r == nil or r == -1 then
    BBT_Log("options: back to the grid")
    return false
  end
  -- picked by hand: the count is the picks' (the player's team included)
  local size = G.filter == 2 and (G.pick_n or 1) or G.size
  local ok, why = BBT_Call(BattleBayDeluxe.Tournament.ARM, G.fmt, size, 1, G.filter, G.double, G.national)
  if ok == true then
    BBT_Log("options: start", G.fmt, G.size, G.filter, G.double, G.national)
    BBT_Info()
    return true
  end
  BBT_Log("options not armed", tostring(ok), tostring(why))
  if G.filter == 2 then
    -- a picked count the format does not offer: a message, then the options again with the values kept
    pcall(BBT_Window, BBT_Id(G.fmt == 2 and "pick_count_league" or "pick_count_tournament"), 1)
    G.keep = true
    return BBT_GridOptionsOnce()
  end
  return false
end

-- ------------------------------------------------------------------------------------------------ the team picker

-- 1.49.0 (owner 2026-10-28): «Equipos: Personalizado». The player picks the teams on the Campaña grid itself (its
-- pages, categories and seasons as ever): Accept on a tile marks / unmarks it (a check mark on the tile), the header
-- says «N / M elegidos · <key> Aceptar» (bbt_mode.lua BBT_ModePickDraw; the key = the mode selector's own), Back
-- leaves the picks as they were. The player's own team is always in (marked, not removable); two versions of one
-- club are refused with a message; the scripts keep and save the picks per mode (CMND_BBD_TOURN_PICK, save blob
-- bb_picks.json of the slot). The count of the tournament / league = the picks + the player's team.
BattleBayDeluxe.Tournament.PICK = @crc:CMND_BBD_TOURN_PICK@
BattleBayDeluxe.TournamentPicker = {
  MARK = @crc:evt_bbd_pick_mark@, SPR = @crc:bbd_md_check@, ATLAS = "#/menu/220_img/bbd_md/bbd_md.g4tx",
  N = 40,                    -- instances of the mark layer (content\menus\bb_tournament.toml)
  DX = 30, DY = -30, SIZE = 40, Q = 36, NODE_QUAD = 1909474081 --[[icon_new01]], MESH_QUAD = 312193881,
  KEY = @crc:CMD_BBD_MODE_SWITCH@,
}

-- the picks' count of the current mode (the player's team included) into BattleBayDeluxe.TournamentGrid.pick_n
function BBT_GridPickCount()
  local r = BBT_Call(BattleBayDeluxe.Tournament.PICK, 4, BattleBayDeluxe.TournamentGrid.fmt, 0, BattleBayDeluxe.TournamentGrid.player or 0)
  if type(r) == "table" and type(r.n) == "number" then
    BattleBayDeluxe.TournamentGrid.pick_n = r.n
  end
end

-- the marks on the grid's tiles (shown / placed only when a tile's state changes)
function BBT_GridPickMarks(show)
  local P, pk = BattleBayDeluxe.TournamentPicker, BattleBayDeluxe.TournamentGrid.pick
  P.state = P.state or {}
  P.opened = P.opened or {}
  if P.atlas == nil then
    P.atlas = BBT_Crc(P.ATLAS)
  end
  local tiles = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, BattleBayDeluxe.Tournament.GRID) or 0
  for i = 0, P.N - 1 do
    local on, x, y = false, 0, 0
    if show and pk and i < tiles and funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, BattleBayDeluxe.Tournament.GRID, i) == true then
      local team = BBD_ROSTER_TeamOf(i)
      if team ~= 0 and (pk.set[team] or team == BattleBayDeluxe.TournamentGrid.player) then
        local gx, gy = funcLuaMenuCommand(4002164178 --[[GPOS]], BattleBayDeluxe.Tournament.GRID, i)
        if type(gx) == "number" and type(gy) == "number" then
          on, x, y = true, gx + P.DX, -gy + P.DY
        end
      end
    end
    local st = on and string.format("%.0f %.0f", x, y) or "off"
    if P.state[i] ~= st then
      P.state[i] = st
      if on and not P.opened[i] then
        P.opened[i] = true
        funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, P.MARK, i)
      end
      if P.opened[i] then
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, P.MARK, i, on)
      end
      if on then
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, P.MARK, P.SIZE / P.Q, P.SIZE / P.Q, 1, i)
        funcLuaMenuCommand(558735651 --[[sprite]], P.MARK, P.atlas, P.SPR, P.NODE_QUAD, 0, i)
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, P.MARK, x, -y, 0, i)
        funcLuaMenuCommand(@crc:CMND_SET_PRIM_COLOR@, P.MARK, i, P.MESH_QUAD, 1, 1, 1)
      end
    end
  end
end

-- a tile decided while picking: its team marked / unmarked (the scripts check the player's team and the clubs)
function BBT_GridPickTile(tile)
  local pk = BattleBayDeluxe.TournamentGrid.pick
  local team = BBD_ROSTER_TeamOf(tile)
  if team == 0 or (type(BBCR_DRAFT) == "table" and team == BBCR_DRAFT.TEAM) then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return
  end
  local r = BBT_Call(BattleBayDeluxe.Tournament.PICK, 1, BattleBayDeluxe.TournamentGrid.fmt, team, BattleBayDeluxe.TournamentGrid.player or 0)
  if type(r) ~= "table" then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    return
  end
  if r.ok then
    pk.set[team] = r.on == true or nil
    pk.n = r.n or pk.n
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3791946501 --[[sy0004]])
  else
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
    if r.why == "club" then
      pk.notice = "pick_club"
    end
  end
  BBT_Log("picker: tile", tile, "team", VRFW_Id.hex(team), r.ok and (r.on and "in" or "out")
    or ("refused " .. tostring(r.why)), "count", pk.n)
end

-- the picker (in the grid's options coroutine): until Accept (the selector's key) or Back
function BBT_GridPick()
  local r = BBT_Call(BattleBayDeluxe.Tournament.PICK, 0, BattleBayDeluxe.TournamentGrid.fmt, 0, BattleBayDeluxe.TournamentGrid.player or 0)
  if type(r) ~= "table" then
    BBT_Log("picker: the scripts did not answer")
    return
  end
  local pk = { set = {}, n = r.n or 1, max = r.max or 0, done = nil, prev = true }
  for _, t in ipairs(r.teams or {}) do
    pk.set[t] = true
  end
  BattleBayDeluxe.TournamentGrid.pick = pk
  BBT_GridCursor(true)
  BBT_Log("picker open: format", BattleBayDeluxe.TournamentGrid.fmt, "count", pk.n, "of", pk.max)
  while pk.done == nil do
    local key = funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], BattleBayDeluxe.TournamentPicker.KEY) == true
    if key and not pk.prev then
      pk.done = "ok"
    end
    pk.prev = key
    pcall(BBT_GridPickMarks, true)
    if pk.notice then
      local n = pk.notice
      pk.notice = nil
      pcall(BBT_Window, BBT_Id(n), 1)
    end
    coroutine.yield()
  end
  local op = pk.done == "ok" and 2 or 3
  local c = BBT_Call(BattleBayDeluxe.Tournament.PICK, op, BattleBayDeluxe.TournamentGrid.fmt, 0, BattleBayDeluxe.TournamentGrid.player or 0)
  if type(c) == "table" and type(c.n) == "number" then
    BattleBayDeluxe.TournamentGrid.pick_n = c.n
  end
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, pk.done == "ok" and 3848881948 --[[sy0000]] or 202039849 --[[sy0006]])
  BattleBayDeluxe.TournamentGrid.pick = nil
  pcall(BBT_GridPickMarks, false)
  BBT_Log("picker closed:", pk.done, "count", BattleBayDeluxe.TournamentGrid.pick_n)
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
  local r = BBT_Call(BattleBayDeluxe.Tournament.START, idx + 1)
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
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
    funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, BattleBayDeluxe.Tournament.GRID_MENU)
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
-- froze): the group-stage menu found open over the grid is closed (VRFW_ChildMenu.Close: its own close call, the
-- engine's close); logged once per leftover. true = it was there.
function BBT_GridCloseGroups(why)
  if not VRFW_ChildMenu.Close(BattleBayDeluxe.Tournament.GROUPS_MENU, "over the team grid") then
    BattleBayDeluxe.TournamentGrid.groups_left = nil
    return false
  end
  if not BattleBayDeluxe.TournamentGrid.groups_left then
    BattleBayDeluxe.TournamentGrid.groups_left = true
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
    -- 1.49.0: the team picker has the tiles
    if BattleBayDeluxe.TournamentGrid.pick then
      if a1 == BattleBayDeluxe.Tournament.GRID then
        pcall(BBT_GridPickTile, a2)
      else
        funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
      end
      return 1
    end
    -- 1.5.64: the accept path in the log (layer, index, the tournament's state, menus over the grid)
    if a1 == BattleBayDeluxe.Tournament.GRID or a1 == BattleBayDeluxe.Tournament.START_BTN then
      pcall(function()
        local groups = BBT_GridCloseGroups("team accept")
        BBT_Log("grid accept: layer " .. tostring(a1) .. " index " .. tostring(a2) .. ", armed " .. tostring(info.armed) ..
          ", configured " .. tostring(info.configured) .. ", pending " .. tostring(info.pending) .. ", running coroutine " ..
          tostring(BattleBayDeluxe.TournamentGrid.co ~= nil) .. ", group tables were open " .. tostring(groups) .. ", sub window open " ..
          tostring(funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW) == true))
      end)
    end
    if BattleBayDeluxe.TournamentGrid.co == nil and info.armed then
      if a1 == BattleBayDeluxe.Tournament.GRID and not info.configured then
        -- 1.49.0: the player's team (always in the picks of «Personalizado»)
        local okp, team = pcall(BBD_ROSTER_TeamOf, a2)
        BattleBayDeluxe.TournamentGrid.player = okp and team or 0
        local args = table.pack(a1, a2, ...)
        BattleBayDeluxe.TournamentGrid.co = coroutine.create(function()
          if BBT_GridOptions() then
            decide(table.unpack(args, 1, args.n))
          end
        end)
        return 1
      end
      if a1 == BattleBayDeluxe.Tournament.START_BTN and info.configured then
        BattleBayDeluxe.TournamentGrid.start_sent = true
        BattleBayDeluxe.TournamentGrid.co = coroutine.create(function()
          BBT_GridStart(a1, a2, decide)
        end)
        return 1
      end
    end
    return decide(a1, a2, ...)
  end

  local back = OnBack
  function OnBack(a1, ...)
    if BattleBayDeluxe.TournamentGrid.pick then
      BattleBayDeluxe.TournamentGrid.pick.done = "cancel"
      return 1
    end
    return back(a1, ...)
  end

  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    local G = BattleBayDeluxe.TournamentGrid
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
        local t = BBT_Call(BattleBayDeluxe.Tournament.INFO)
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
