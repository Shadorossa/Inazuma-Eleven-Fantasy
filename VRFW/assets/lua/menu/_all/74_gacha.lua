-- VRFW gacha service, game Lua side (every menu VM; script side scripts\gacha.lua; docs/framework/gacha.md).
-- A pool is a mod's [[VRFW.GachaPool]] (content\gacha\*.toml): its cards, its yes / no question, its draw tint, its cost,
-- the Chronicle board node that opens it. Only mechanism here; what is drawn is the declaring mods' data.
--   VRFW_Gacha.IsPiece(idx)      -> true when board piece index `idx` is a gacha node (the board's balloon hides its face)
--   VRFW_Gacha.AfterMenu(idx)    the board, right after the piece's command menu closed: when its one command row (the
--                                   pool's `command`) was picked, the draw runs (route_board's VRFW_RB_MenuClosed default)
-- The node's command menu (vs_route_town_command_select_menu, VRFW_Host handlers of this file): its rows are the pool's
-- one command row (route_board's VRFW_RBC_Rows default asks VRFW_Gacha.RowsFor), the row shows the command text with no
-- team level, the flavour window under the panel is hidden and the «MI EQUIPO» banner shows the pool's `banner` picture
-- (no team picture, no level). Picking the row closes the menu with the pool's request in the parameter store (no
-- retail result: the board goes back as after «back», then runs the draw). The X key keeps the retail drop-rate list of
-- the node's game: its spirit candidates are the pool (data of the declaring mod), the owned players left out
-- (vrfw_drop_list: CMND_VRFW_DROP_LIST_EXCLUDE_OWNED), the same list the draw picks from (CMND_VRFW_GACHA_CANDIDATES).
--   VRFW_Gacha.Run(pool)         -> the drawn card, or nil + why ("refused", "empty", "cost", "sign:<why>"): the question,
--                                   the draw, the cost taken, the signing (VRFW_Recruit), the obtained screen. Runs
--                                   inside a coroutine (it waits on the windows and the screens)
-- After a draw: the obtained screen, from a VRFW_Host `after` handler on the board's PreStep that is registered only
-- while a draw is pending. The pool's draw `event` is not played on the board (the board has no event stage for it).
-- The obtained screen is the framework's pose row screen with the drawn player (content\pose_rows\gacha_obtained.toml:
-- his 3D model in the retail summon pose and motion, «¡Enhorabuena!»); if it cannot open, an OK window «<name> joined
-- the team!».
-- Log: "LUAPRINT … VRFW_GACHA …".
if VRFW_Gacha == nil then
  local G = {
    C = {
      OF_PIECE = 2789066073,         -- CMND_VRFW_GACHA_OF_PIECE (pieceId) -> pool index, 0 = none
      POOL = 1397719389,             -- CMND_VRFW_GACHA_POOL (index) -> key, question, r, g, b, cost item, cost count, level, n
      CARDS = 777104705,             -- CMND_VRFW_GACHA_CARDS (index) -> card, …
      CANDIDATES = 1771238333,       -- CMND_VRFW_GACHA_CANDIDATES (index) -> the cards a draw picks from now
      TEXTS = 883353091,             -- CMND_VRFW_GACHA_TEXTS (index) -> command text id, banner image id
      EXCLUDE_OWNED = 3491817672,    -- CMND_VRFW_DROP_LIST_EXCLUDE_OWNED (1 | 0)
      PARAM_HAS = 2947612279,        -- the parameter store: (key) -> set
      PARAM_GET = 3522198769,        -- (key) -> value
      CLOSE_MENU = 320421347,        -- CMND_CLOSE_MENU_OBJECT
      SET_TEXT = 1083631230,         -- (layer, text node, string, instance)
      LOC_VISIBLE = 2158717427,      -- (layer, locator, on, instance)
      MESH_VISIBLE = 3405944500,     -- (layer, mesh, on, instance)
      LAYER_VISIBLE = 711242136,     -- (layer, instance, on)
      SET_TEX = 558735651,           -- (layer, atlas path, sprite, texture slot, 0, instance)
      PIECE_INFO = 126049514,        -- (piece index, 6) -> ok, the piece's save slot (statusFlagIndex)
      TEXT_GET = 4074371074,         -- CMND_TEXT_GET (text id) -> text
      WIN_TEXT = 2289627655,         -- the general window's text (text, 0, 0, 0, 0, 0, false)
      WIN_BUTTONS = 2351835063,      -- its buttons (1 = OK, 2 = yes / no, 0)
      WIN_FOCUS = 2529383714,        -- its first focused button (0, n)
      WIN_SOUNDS = 528596549,        -- its decide / cancel sounds
      WIN_RESULT = 1523741473,       -- -> -1 while open, 0 yes, 1 no
      WIN_CLOSED = 682363669,        -- -> true once an OK window closed
      SOUND = 1917805374,            -- a system sound
      PARAM_SET = 3860611758,        -- the parameter store (key, 0, value, 1)
      PARAM_CLEAR = 3363400568,      -- (key)
      LOG = 3661580131,              -- CMND_EVT_LOG
      FADE = 609722083,              -- (1 = to black | 0 = from black, seconds)
    },
    OBTAINED_ROW = "vr_framework.gacha_obtained",   -- the obtained screen (content\pose_rows\gacha_obtained.toml)
    BOARD_HIDE = {1423637364 --[[rpg00_05_menu_button_guide]], 139522149 --[[vsroute02_03_gametitle]]},
    BOARD_MODELS = {{1021315501 --[[vsroute00_00_background]], 0}},   -- the board's caravan (its menu model)
    BOARD = "vs_route_town_menu",
    HANDLER = "VRFW.gacha_draw",
    pending = nil,                   -- the draw being shown on the board: {card, co}
    SOUND_DECIDE = 3848881948,       -- sy0000
    SOUND_CANCEL = 202039849,        -- sy0006
    TEXT_EMPTY = 1753758030,         -- vrfw_gacha_pool_empty (text\rows\gacha.toml)
    TEXT_NO_COST = 1005605398,       -- vrfw_gacha_no_cost
    TEXT_JOINED = 2922231047,        -- vrfw_gacha_joined (%s = the player's name)
    CHARA_OF_CARD = 347353059,       -- (card) -> its character
    CHARA_NAME = 523676951,          -- (character) -> its name
    pieces = nil,                    -- board piece save slot -> pool index (built on first use)
    MENU = "vs_route_town_command_select_menu",
    MENU_ID = 1193383590,            -- its menu object
    REQUEST = 1006738234,            -- crc32("vrfw_gacha_request"): the pool index whose command row was picked
    ROW_ITEM = 0x56524741,           -- the command row's listItemType ("VRGA"): never a retail command
    SUB_LIST = 284009563,            -- vsroute01_16_sub_list (the command rows)
    BANNER = 1483086491,             -- vsroute01_17_myteam_banner
    INFO_WINDOW = 1303149463,        -- team02_04_info_window (the flavour text under the panel)
    BANNER_ATLAS = 1503831295,       -- crc32("#/menu/30_vsroute/vsroute01/vsroute01_17/<LG>/vsroute01_17.g4tx")
    BANNER_SLOT = 3668937361,        -- myteam_dmy01: the one-picture banner's texture slot
    BANNER_SHOW = {1711801685},      -- _myteam_dmy01_b (vsroute01_17.g4pkm)
    BANNER_HIDE = {447975417, 689040068, 13372060, 1546785142},   -- _gtxt_teamlevel01_b, _num_lv01_b, _num_lv_dmy01_b, _gtxt_myteam01
    pools = {},                      -- pool index -> its answer (cached)
  }
  VRFW_Gacha = G

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  function G.Log(...)
    if PRINT ~= nil then
      pcall(PRINT, "VRFW_GACHA", ...)
    end
  end

  function G.Pool(i)
    if G.pools[i] == nil then
      local key, question, r, g, b, cost_item, cost_count, level, n, event = call(G.C.POOL, i)
      if key == nil then
        return nil
      end
      G.pools[i] = {index = i, key = key, question = question or 0, tint = {r or 255, g or 255, b or 255},
                    cost_item = cost_item or 0, cost_count = cost_count or 0, level = level or 1, n = n or 0,
                    event = event or 0,
                    cards = table.pack(call(G.C.CARDS, i))}
    end
    return G.pools[i]
  end

  -- board piece index -> pool index (0 = none): the piece's save slot -> its route node (route_nodes' VRFW_RN_Load)
  function G.OfPieceIndex(idx)
    if idx == nil or idx < 0 or VRFW_RN_Load == nil then
      return 0
    end
    if G.pieces == nil then
      G.pieces = {}
      for _, node in ipairs(VRFW_RN_Load().nodes or {}) do
        local p = call(G.C.OF_PIECE, node.piece)
        if type(p) == "number" and p > 0 then
          G.pieces[node.slot] = p
          G.Log("node slot", node.slot, "pool", p)
        end
      end
    end
    local ok, sfi = call(G.C.PIECE_INFO, idx, 6)
    if not ok then
      return 0
    end
    return G.pieces[sfi] or 0
  end

  function G.IsPiece(idx)
    return G.OfPieceIndex(idx) > 0
  end

  -- the pool of a save slot (the command menu knows the piece's slot: VRFW_RBC.L.n2), 0 = none
  function G.OfSlot(slot)
    if G.pieces == nil then
      G.OfPieceIndex(-1)
    end
    if G.pieces == nil and VRFW_RN_Load ~= nil then
      G.pieces = {}
      for _, node in ipairs(VRFW_RN_Load().nodes or {}) do
        local p = call(G.C.OF_PIECE, node.piece)
        if type(p) == "number" and p > 0 then
          G.pieces[node.slot] = p
        end
      end
    end
    return (G.pieces or {})[slot] or 0
  end

  -- the command menu's rows of a gacha node (route_board's VRFW_RBC_Rows default): one row, the pool's command; nil = not
  -- a gacha node. Difficulty 1 (the node's game row) keeps the retail X key: the drop-rate list of that game.
  function G.RowsFor(slot, rows)
    local p = G.OfSlot(slot)
    if p <= 0 then
      return nil
    end
    local command = call(G.C.TEXTS, p) or 0
    local base = (type(rows) == "table" and rows[1]) or {}
    return {{listItemType = G.ROW_ITEM, pattern = 0, text = command, classTexture = 0, difficultyType = 1,
             textureOn = 2928350469 --[[icon_list01_on]], textureOff = 3469663858 --[[icon_list01_off]],
             textureDiffBase = 0, heroDropControlEnabled = false, base = base.listItemType}}
  end

  local function text_of(id)
    local s = call(G.C.TEXT_GET, id)
    return type(s) == "string" and s or ""
  end

  local function menu_pool()
    if VRFW_RBC == nil or VRFW_RBC.L == nil then
      return 0
    end
    local ok, slot = pcall(function() return VRFW_RBC.L.n2 end)
    if not ok then
      return 0
    end
    return G.OfSlot(slot)
  end

  -- the command menu: the row (its text in the plain style, no team level), the flavour window
  local function menu_setup(r, layer, inst)
    local p = menu_pool()
    if p <= 0 then
      return
    end
    if layer == G.SUB_LIST then
      local t = text_of(call(G.C.TEXTS, p) or 0)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 808187266 --[[_text_list_base01_on]], t, inst)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 3180095505 --[[_text_list_base01_off]], t, inst)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 580803180 --[[_text_list_base02_on]], "", inst)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 4197192385 --[[_text_list_base02_off]], "", inst)
      pcall(funcLuaMenuCommand, G.C.LOC_VISIBLE, layer, 3597743423 --[[_pos_team_lv01]], false, inst)
    elseif layer == G.INFO_WINDOW then
      pcall(funcLuaMenuCommand, G.C.LAYER_VISIBLE, layer, inst, false)
    end
  end

  -- the banner: the one-picture style (_pos_team01_b) with the pool's picture, no level, no «MI EQUIPO»
  local function menu_open(r, layer, inst)
    local p = menu_pool()
    if p <= 0 then
      return
    end
    if layer == G.INFO_WINDOW then
      pcall(funcLuaMenuCommand, G.C.LAYER_VISIBLE, layer, inst, false)
      return
    end
    if layer ~= G.BANNER then
      return
    end
    local _, banner = call(G.C.TEXTS, p)
    if type(banner) ~= "number" or banner == 0 then
      return
    end
    pcall(funcLuaMenuCommand, G.C.LOC_VISIBLE, layer, 4160160648 --[[_pos_team01_a]], false, inst)
    pcall(funcLuaMenuCommand, G.C.LOC_VISIBLE, layer, 1862160946 --[[_pos_team01_b]], true, inst)
    pcall(funcLuaMenuCommand, G.C.SET_TEX, layer, G.BANNER_ATLAS, banner, G.BANNER_SLOT, 0, inst)
    for _, m in ipairs(G.BANNER_SHOW) do
      pcall(funcLuaMenuCommand, G.C.MESH_VISIBLE, layer, m, true, inst)
    end
    for _, m in ipairs(G.BANNER_HIDE) do
      pcall(funcLuaMenuCommand, G.C.MESH_VISIBLE, layer, m, false, inst)
    end
  end

  -- picking the command row: the request in the parameter store, the menu closed with no retail result
  local function menu_decide(nxt, layer, inst, ...)
    if layer == G.SUB_LIST and menu_pool() > 0 then
      local p = menu_pool()
      call(G.C.PARAM_CLEAR, G.REQUEST)
      call(G.C.PARAM_SET, G.REQUEST, 0, p, 1)
      call(G.C.CLOSE_MENU, G.MENU_ID)
      G.Log("command row picked: pool", p)
      return
    end
    return nxt(layer, inst, ...)
  end

  -- the command menu closes: the drop-rate list's owned-player rule is never left on
  local function menu_final()
    call(G.C.EXCLUDE_OWNED, 0)
  end

  if VRFW_Host ~= nil then
    VRFW_Host.on(G.MENU, "OnSetupLayer", {id = "VRFW.gacha_rows", phase = "after", fn = menu_setup})
    VRFW_Host.on(G.MENU, "OnOpenLayer", {id = "VRFW.gacha_banner", phase = "after", fn = menu_open})
    VRFW_Host.on(G.MENU, "OnDecideFocus", {id = "VRFW.gacha_command", phase = "around", fn = menu_decide})
    VRFW_Host.on(G.MENU, "FinalizeMenu", {id = "VRFW.gacha_final", phase = "after", fn = menu_final})
  end

  -- the board, the command menu just closed (route_board's VRFW_RB_MenuClosed default): a picked command row runs the
  -- draw (question, draw, signing; then the obtained screen from the board's PreStep); the board then
  -- goes back as after «back» (no retail result was written)
  function G.AfterMenu(idx)
    if call(G.C.PARAM_HAS, G.REQUEST) ~= true then
      return false
    end
    local p = call(G.C.PARAM_GET, G.REQUEST) or 0
    call(G.C.PARAM_CLEAR, G.REQUEST)
    local pool = G.Pool(p)
    if pool == nil then
      return false
    end
    local card, why = G.Run(pool, true)
    G.Log("piece", idx, "pool", pool.key, "card", card or 0, why or "")
    if card ~= nil then
      G.ShowOnBoard(card, pool.event)
    end
    return true
  end

  -- the board's PreStep (after): the pending draw's obtained screen in a coroutine (cursor and map control off while it
  -- is up); the handler removes itself at the end
  function G.BoardStep()
    local p = G.pending
    if p == nil then
      return
    end
    if p.co == nil then
      p.co = coroutine.create(function()
        if SetVisibleAndEnableCursor ~= nil then pcall(SetVisibleAndEnableCursor, false) end
        if DisableMapControl ~= nil then pcall(DisableMapControl) end
        G.Obtained(p.card, true)
        if SetVisibleAndEnableCursor ~= nil then pcall(SetVisibleAndEnableCursor, true) end
        if EnableMapControl ~= nil then pcall(EnableMapControl) end
      end)
    end
    local ok, err = coroutine.resume(p.co)
    if not ok then
      G.Log("draw screens error", err)
      call(G.C.FADE, 0, 0.3)
    end
    if not ok or coroutine.status(p.co) == "dead" then
      G.pending = nil
      if VRFW_Host ~= nil then
        pcall(VRFW_Host.off, G.BOARD, "PreStep", G.HANDLER)
      end
    end
  end

  -- a draw signed on the board: its obtained screen runs from the board's PreStep (see the header)
  function G.ShowOnBoard(card, event)
    if VRFW_Host == nil or VRFW_RB == nil then
      G.Obtained(card)
      return
    end
    G.pending = {card = card}
    VRFW_Host.on(G.BOARD, "PreStep", {id = G.HANDLER, phase = "after", fn = function()
      G.BoardStep()
    end})
  end

  local function text(id)
    local s = call(G.C.TEXT_GET, id)
    return type(s) == "string" and s or ""
  end

  -- a window (a text id or a string): buttons 1 = OK (waits until closed), 2 = yes / no (-> true on yes)
  function G.Window(id, buttons)
    call(G.C.WIN_TEXT, type(id) == "string" and id or text(id), 0, 0, 0, 0, 0, false)
    call(G.C.WIN_BUTTONS, buttons, 0)
    if buttons == 2 then
      call(G.C.WIN_FOCUS, 0, 1)
    end
    call(G.C.WIN_SOUNDS, G.SOUND_DECIDE, G.SOUND_CANCEL)
    if buttons == 1 then
      while call(G.C.WIN_CLOSED) ~= true do
        coroutine.yield()
      end
      return true
    end
    local r = -1
    while type(r) ~= "number" or r < 0 do
      r = call(G.C.WIN_RESULT)
      coroutine.yield()
    end
    return r == 0
  end

  -- the cards a draw picks from now: the pool's cards whose character has no player in the club (the script side's
  -- CMND_VRFW_GACHA_CANDIDATES: the drop-rate list's owned-player rule, so the window lists exactly these)
  function G.Candidates(pool)
    local got = table.pack(call(G.C.CANDIDATES, pool.index))
    local out = {}
    for k = 1, got.n or 0 do
      local c = got[k]
      if type(c) == "number" and c ~= 0 then
        out[#out + 1] = c
      end
    end
    return out
  end

  function G.Pick(list)
    local ok, k = pcall(math.random, #list)
    if not ok or type(k) ~= "number" then
      k = 1
    end
    return list[k]
  end

  -- the obtained screen for `card`: the framework's pose row screen with the drawn player (content\pose_rows  -- gacha_obtained.toml: his 3D model in the summon pose and motion, «¡Enhorabuena!»); when it cannot open, the OK window
  -- «<name> joined the team!». On the board its chrome and the caravan are hidden while the screen is up.
  function G.Obtained(card, on_board)
    if VRFW_PoseRow ~= nil then
      local opts = on_board and {hide = G.BOARD_HIDE, models = G.BOARD_MODELS} or nil
      local ok, pick = pcall(VRFW_PoseRow.Open, G.OBTAINED_ROW, card, opts)
      if ok and pick ~= nil then
        return
      end
      G.Log("obtained screen not shown", tostring(ok), tostring(pick))
    end
    local name = call(G.CHARA_NAME, call(G.CHARA_OF_CARD, card) or 0)
    local s = text(G.TEXT_JOINED)
    local ok, msg = pcall(string.format, s, type(name) == "string" and name or "")
    G.Window(ok and msg or s, 1)
  end

  -- the whole draw; `deferred` = the caller shows the result itself (the board: G.ShowOnBoard)
  function G.Run(pool, deferred)
    local cands = G.Candidates(pool)
    if #cands == 0 then
      G.Window(G.TEXT_EMPTY, 1)
      return nil, "empty"
    end
    if pool.cost_count > 0 and VRFW_Recruit ~= nil and VRFW_Recruit.Items(pool.cost_item) < pool.cost_count then
      G.Window(G.TEXT_NO_COST, 1)
      return nil, "cost"
    end
    if not G.Window(pool.question, 2) then
      return nil, "refused"
    end
    local card = G.Pick(cands)
    local price = pool.cost_count > 0 and {item = pool.cost_item, count = pool.cost_count} or nil
    local ok, why = true, nil
    if VRFW_Recruit ~= nil then
      ok, why = VRFW_Recruit.Recruit({param = card, level = pool.level, price = price})
    end
    if not ok then
      G.Log("pool", pool.key, "card", card, "not signed", why)
      return nil, "sign:" .. tostring(why)
    end
    G.Log("pool", pool.key, "drew", card, "of", #cands)
    if not deferred then
      G.Obtained(card)
    end
    return card
  end
end
