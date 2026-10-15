-- VRFW route_chains BEGIN
-- VR-Framework chain boards on the Chronicle board: a [[route_node]] with `chain = …` (its "C" piece) opens the framework's chain board screen
-- (vrfw_chain_board_menu) instead of its command menu; a match tile picked there is played from here, as a board match
-- of that piece (the retail launch, state 3, with the tile's own game and difficulty); back on the board after it
-- (state 8) a win records the tile's rank in the chain's progress (VRFW_Chain, the framework's menu part) and the
-- piece's own clear flow (state 10) is skipped: the "C" piece is cleared (its first shown difficulty) only when every
-- match of its chain is won. Losing records nothing (retry the match). The rank of a win is the board's rank rule
-- (VRFW_RB_MatchRank of graft route_board: the framework's S / A / B score rule, VRFW_MatchRank). The "C" crest's badge (route_board's VRFW_RB_Badge) shows the chain's rank: the average of its
-- matches (VRFW_RCH_RankOf, the default of VRFW_RB_Rank).
-- A CHAIN HUB (a [[VRFW.RouteNode]] Kind = "chain_hub" with Chains = [...]) opens the same screen on
-- the chooser list of its chains (parameter vrfw_chain_hub = its slot); the screen answers the picked tile AND its
-- chain (vrfw_chain_pick_chain); each chain keeps its own progress; the hub's piece clears once all are complete and its
-- badge is the average of the chains' ranks.
-- Generic: every chain node of every mod (CMND_VRFW_TEAM_ROUTE_NODE_* via route_nodes' VRFW_RN_Load, then
-- CMND_VRFW_TEAM_CHAIN_OF_PIECE). Data loaded lazily, never at Lua load. Log: "LUAPRINT … VRFW_RCH …".
VRFW_RCH_ON = true -- kill switch: false = chain nodes open their own command menu (their piece's game)
VRFW_RCH = nil     -- save slot -> {board, slot} of every chain node (built on first use)
VRFW_RCH_CMD_MENU = 1193383590 --[[vs_route_town_command_select_menu]]

function VRFW_RCH_Log(...)
  if PRINT ~= nil then
    pcall(PRINT, "VRFW_RCH", ...)
  end
end

function VRFW_RCH_Load()
  if VRFW_RCH ~= nil then
    return VRFW_RCH
  end
  VRFW_RCH = {}
  if VRFW_Chain == nil or VRFW_RN_Load == nil then
    VRFW_RCH_Log("no VRFW_Chain / route nodes in this VM: chain nodes open their command menu")
    return VRFW_RCH
  end
  for _, node in ipairs(VRFW_RN_Load().nodes) do
    local b, slot = VRFW_Chain.OfPiece(node.piece)
    if b ~= nil then
      -- a chain hub (Kind = "chain_hub"): the chooser list of its chains (board = the first one)
      local hub = (node.hub ~= nil and #node.hub > 0 and VRFW_Chain.Hub ~= nil) and VRFW_Chain.Hub(node.slot) or nil
      VRFW_RCH[node.slot] = {board = b, slot = node.slot, diffs = node.diffs, hub = hub}
      VRFW_RCH_Log("node slot", node.slot, "chain", b.key, "tiles", #b.tiles, "hub", hub ~= nil and #hub or 0)
    end
  end
  return VRFW_RCH
end

-- the chain node of board piece index `idx` (nil = a plain piece)
function VRFW_RCH_Of(idx)
  if not VRFW_RCH_ON or idx == nil or idx < 0 then
    return nil
  end
  local ok, sfi = funcLuaCommand(126049514, idx, 6)
  if not ok then
    return nil
  end
  return VRFW_RCH_Load()[sfi]
end

-- OpenCommandSelect: the menu a piece opens (a chain node: the chain board, its chain index handed over)
function VRFW_RCH_MenuFor(idx)
  local n = VRFW_RCH_Of(idx)
  if n == nil then
    return VRFW_RCH_CMD_MENU
  end
  funcLuaCommand(3363400568, VRFW_Chain.P_PICK)
  funcLuaCommand(3363400568, VRFW_Chain.P_CHAIN)
  funcLuaCommand(3363400568, VRFW_Chain.P_HUB)
  funcLuaCommand(3363400568, VRFW_Chain.P_PICK_CHAIN)
  funcLuaCommand(3860611758, VRFW_Chain.P_CHAIN, 0, n.board.i, 1)
  if n.hub ~= nil then
    funcLuaCommand(3860611758, VRFW_Chain.P_HUB, 0, n.slot, 1)
    VRFW_RCH_Log("open hub", n.slot, "chains", #n.hub, "piece", idx)
  else
    VRFW_RCH_Log("open board", n.board.key, "piece", idx, "slot", n.slot, "state", VRFW_Chain.State(n.board))
  end
  return VRFW_Chain.MENU
end

-- the Chronicle board's own footer (button guides) and the piece's title banner while the full-screen chain board is
-- open (show = false right after it opens, true when it closes without a match: the retail "back" path then reopens
-- its guides itself). Only for the chain board (`menu`), never for the retail command menu.
VRFW_RCH_HIDDEN = false
function VRFW_RCH_ParentUi(menu, show)
  if menu ~= nil and (VRFW_Chain == nil or menu ~= VRFW_Chain.MENU) then
    return
  end
  if not show then
    VRFW_RCH_HIDDEN = true
  elseif not VRFW_RCH_HIDDEN then
    return
  else
    VRFW_RCH_HIDDEN = false
  end
  for _, l in ipairs({1138543975 --[[mainmenu01_06_base_button_guide]], 9396745 --[[mainmenu01_07_button_guide]],
                      1423637364 --[[rpg00_05_menu_button_guide]], 139522149 --[[vsroute02_03_gametitle]]}) do
    pcall(funcLuaMenuCommand, 2171393651 --[[layer visible, every instance]], l, show)
  end
  if not show then
    VRFW_RCH_NewIcon(false) -- put back only when the Chronicle board itself closes (VRFW_RCH_NewIcon(true), FinalizeMenu)
  end
end

-- the board's retail "new" badge cmn01_12_new_icon (draw priority 999, the board's script never places it): it showed
-- as a small red "!" at the top-left corner over the chain board. Hidden while the chain board is
-- open, each instance's own visibility put back when it closes (CMND_IS_LAYER_VISIBLE before hiding).
VRFW_RCH_NEW_SEEN = nil
function VRFW_RCH_NewIcon(show)
  local L = 2505232397 --[[cmn01_12_new_icon]]
  if not show then
    local okN, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], L)
    VRFW_RCH_NEW_SEEN = {}
    for i = 0, (okN and tonumber(n) or 0) - 1 do
      local okV, v = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], L, i)
      VRFW_RCH_NEW_SEEN[i] = okV and v == true
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, i, false)
    end
    VRFW_RCH_Log("new badge hidden", okN and n or "?")
  elseif VRFW_RCH_NEW_SEEN ~= nil then
    for i, v in pairs(VRFW_RCH_NEW_SEEN) do
      pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, i, v)
    end
    VRFW_RCH_NEW_SEEN = nil
  end
end

-- the same badge stays hidden on the WHOLE Chronicle board, under any of its menus: the board's Step hides every instance each frame (an instance made later is saved
-- too); FinalizeMenu puts each one's own visibility back (VRFW_RCH_NewIcon(true)).
function VRFW_RCH_NewIconStep()
  if VRFW_RCH_NEW_SEEN == nil then
    VRFW_RCH_NewIcon(false)
    return
  end
  local L = 2505232397 --[[cmn01_12_new_icon]]
  local okN, n = pcall(funcLuaMenuCommand, 1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], L)
  for i = 0, (okN and tonumber(n) or 0) - 1 do
    if VRFW_RCH_NEW_SEEN[i] == nil then
      local okV, v = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], L, i)
      VRFW_RCH_NEW_SEEN[i] = okV and v == true
    end
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], L, i, false)
  end
end

-- the board's piece balloon (UpdatePieceAtcBalloon: team name + the team's player face icon_chr_dmy01): a chain node
-- shows its name only, no player over it. `idx` = the board piece index. False: the balloon's chara
-- is set to 0 before the retail face call, so the retail "no face" branch runs (face meshes hidden, no face draw; the
-- node's `Team` is only a placeholder that gives the piece a game, its player must never be drawn).
function VRFW_RCH_BalloonFace(idx)
  return VRFW_RCH_Of(idx) == nil
end

-- after the chain board closed: game id, difficulty of the match tile picked (nil = back / not a chain node)
function VRFW_RCH_Picked(idx)
  local n = VRFW_RCH_Of(idx)
  if n == nil then
    return nil
  end
  VRFW_RCH_ParentUi(nil, true)
  local t = 0
  if funcLuaCommand(2947612279, VRFW_Chain.P_PICK) then
    t = funcLuaCommand(3522198769, VRFW_Chain.P_PICK) or 0
    funcLuaCommand(3363400568, VRFW_Chain.P_PICK)
  end
  -- a hub: the chain of the picked tile (the screen's P_PICK_CHAIN = chain index + 1)
  local b = n.board
  if n.hub ~= nil then
    b = nil
    if funcLuaCommand(2947612279, VRFW_Chain.P_PICK_CHAIN) then
      b = VRFW_Chain.Board((funcLuaCommand(3522198769, VRFW_Chain.P_PICK_CHAIN) or 0) - 1)
      funcLuaCommand(3363400568, VRFW_Chain.P_PICK_CHAIN)
    end
    if b == nil then
      VRFW_RCH_Log("hub closed", n.slot, "pick", t)
      return nil
    end
  end
  local tile = b.tiles[t]
  if tile == nil or tile.kind ~= "match" or tile.game == 0 then
    VRFW_RCH_Log("board closed", b.key, "pick", t)
    return nil
  end
  VRFW_Chain.SetPending(b, t, n.slot)
  VRFW_RCH_Log("launch", b.key, tile.id, "game", tile.game, "difficulty", tile.difficulty, "level", tile.level)
  return tile.game, tile.difficulty
end

-- the rank of the match just won: the board's rank rule (route_board's hook point VRFW_RB_MatchRank: VRFW_MatchRank)
function VRFW_RCH_Rank()
  if VRFW_RB_MatchRank ~= nil then
    return VRFW_RB_MatchRank()
  end
  return 1, -1, -1
end

-- PreStep state 8 (back on the board), before the retail result handling: a chain match's result
function VRFW_RCH_AfterMatch()
  if VRFW_Chain == nil then
    return
  end
  local key, t, slot = VRFW_Chain.Pending()
  if key == nil then
    return
  end
  VRFW_Chain.ClearPending()
  local back = funcLuaCommand(2283097588 --[[CMND_GET_TEMP_BIT_FLAG]], 1388584433)
  local won = funcLuaCommand(2283097588 --[[CMND_GET_TEMP_BIT_FLAG]], 2046383450)
  local n = VRFW_RCH_Load()[slot]
  local b = (n ~= nil and n.board.key == key) and n.board or VRFW_Chain.ByKey(key)   -- a hub: the pending tile's chain
  if not back or b == nil or b.tiles[t] == nil then
    VRFW_RCH_Log("pending dropped", key, t, slot, "back", back)
    return
  end
  if not won then
    VRFW_RCH_Log("result", key, b.tiles[t].id, "not won: retry it")
    return
  end
  local rank, f, a = VRFW_RCH_Rank()
  if rank == nil then
    -- no declared rank holds (a mod's ranks need more): the lowest declared rank, the tile is won all the same
    local list = VRFW_MatchRank ~= nil and VRFW_MatchRank.List() or {}
    rank = list[#list] and list[#list].id or "B"
  end
  local best = VRFW_Chain.Win(b, t, rank)
  -- the piece's own clear flow (state 10: clear bit, open effect, rank of the piece) is not run for a chain match
  funcLuaCommand(3964465990 --[[CMND_SET_TEMP_BIT_FLAG]], 2046383450, false)
  local complete = VRFW_Chain.Complete(b)
  VRFW_RCH_Log("result", key, b.tiles[t].id, "score", f, a, "rank", rank, "best", best, "complete", complete, "chain rank", VRFW_Chain.Average(b))
  if n ~= nil and n.hub ~= nil then
    complete = VRFW_Chain.HubComplete(n.hub)   -- a hub's piece clears once every chain of it is complete
  end
  if complete and n ~= nil then
    local d = (n.diffs and n.diffs[1]) or 4
    if not funcLuaCommand(4034518619 --[[CMND_GET_CHRONICLE_CLEAR_STATUS]], n.slot, d) then
      funcLuaCommand(1891570685 --[[CMND_SET_CHRONICLE_CLEAR_STATUS?]], n.slot, true, d)
      VRFW_RCH_Log("chain cleared: node slot", n.slot, "difficulty", d)
    end
  end
end

-- the "C" crest's badge: a chain node's slot answers its chain's rank (0 = a plain piece, or the chain not won yet)
function VRFW_RCH_RankOf(sfi)
  if VRFW_RCH_ON and VRFW_Chain ~= nil and sfi ~= nil then
    local n = VRFW_RCH_Load()[sfi]
    if n ~= nil and n.hub ~= nil then
      return VRFW_Chain.HubAverage(n.hub)
    elseif n ~= nil then
      return VRFW_Chain.Average(n.board)
    end
  end
  return nil
end
-- VRFW route_chains END
