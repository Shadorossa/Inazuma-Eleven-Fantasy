-- VRFW gacha service, game Lua side (every menu VM; script side scripts\gacha.lua; docs/framework/gacha.md).
-- A pool is a mod's [[VRFW.GachaPool]] (content\gacha\*.toml): its cards, its cost, its level, the Chronicle board node
-- that opens it. Only mechanism here; what is drawn is the declaring mods' data.
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
--   VRFW_Gacha.Run(pool)         -> the drawn card, or nil + why ("empty", "cost", "sign:<why>"): the draw, the cost
--                                   taken, the signing (VRFW_Recruit) and the game's OK window «You obtained <name>!»
--                                   (vrfw_gacha_obtained). Runs inside a coroutine (it waits on the window)
-- Log: "LUAPRINT … VRFW_GACHA …" (the picked row, the drawn card or why nothing was drawn).
if VRFW_Gacha == nil then
  local G = {
    C = {
      OF_PIECE = 2789066073,         -- CMND_VRFW_GACHA_OF_PIECE (pieceId) -> pool index, 0 = none
      POOL = 1397719389,             -- CMND_VRFW_GACHA_POOL (index) -> key, cost item, cost count, level, card count
      CARDS = 777104705,             -- CMND_VRFW_GACHA_CARDS (index) -> card, …
      CANDIDATES = 1771238333,       -- CMND_VRFW_GACHA_CANDIDATES (index) -> the cards a draw picks from now
      TEXTS = 883353091,             -- CMND_VRFW_GACHA_TEXTS (index) -> command text id, banner image id, no-cost text id,
                                     -- count text id
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
      WIN_BUTTONS = 2351835063,      -- its buttons (1 = OK, 0)
      WIN_SOUNDS = 528596549,        -- its decide / cancel sounds
      WIN_CLOSED = 682363669,        -- -> true once an OK window closed
      PARAM_SET = 3860611758,        -- the parameter store (key, 0, value, 1)
      PARAM_CLEAR = 3363400568,      -- (key)
    },
    SOUND_DECIDE = 3848881948,       -- sy0000
    SOUND_CANCEL = 202039849,        -- sy0006
    TEXT_EMPTY = 1753758030,         -- vrfw_gacha_pool_empty (text\rows\gacha.toml)
    TEXT_NO_COST = 1005605398,       -- vrfw_gacha_no_cost (a pool without its own no_cost_text)
    TEXT_OBTAINED = 3030942955,      -- vrfw_gacha_obtained (%s = the player's name)
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
      local key, cost_item, cost_count, level, n = call(G.C.POOL, i)
      if key == nil then
        return nil
      end
      G.pools[i] = {index = i, key = key, cost_item = cost_item or 0, cost_count = cost_count or 0, level = level or 1,
                    n = n or 0, cards = table.pack(call(G.C.CARDS, i))}
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

  -- the command row's second line: the pool's count text with how many of its cost item the player has ("" = none)
  local function count_line(p)
    local _, _, _, count_text = call(G.C.TEXTS, p)
    local pool = G.Pool(p)
    if type(count_text) ~= "number" or count_text == 0 or pool == nil or pool.cost_item == 0 or VRFW_Recruit == nil then
      return ""
    end
    local s = text_of(count_text)
    local ok, line = pcall(string.format, s, VRFW_Recruit.Items(pool.cost_item) or 0)
    return ok and line or s
  end

  -- the command menu: the row (its text in the plain style, no team level; its second line the cost item count), the
  -- flavour window
  local function menu_setup(r, layer, inst)
    local p = menu_pool()
    if p <= 0 then
      return
    end
    if layer == G.SUB_LIST then
      local t = text_of(call(G.C.TEXTS, p) or 0)
      local count = count_line(p)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 808187266 --[[_text_list_base01_on]], t, inst)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 3180095505 --[[_text_list_base01_off]], t, inst)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 580803180 --[[_text_list_base02_on]], count, inst)
      pcall(funcLuaMenuCommand, G.C.SET_TEXT, layer, 4197192385 --[[_text_list_base02_off]], count, inst)
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
  -- draw (the cost, the draw, the signing, the «obtained» window); the board then goes back as after «back» (no retail
  -- result was written)
  function G.AfterMenu(idx)
    if call(G.C.PARAM_HAS, G.REQUEST) ~= true then
      return false
    end
    local p = call(G.C.PARAM_GET, G.REQUEST) or 0
    call(G.C.PARAM_CLEAR, G.REQUEST)
    local pool = G.Pool(p)
    if pool == nil then
      G.Log("piece", idx, "pool", p, "not served")
      return false
    end
    local card, why = G.Run(pool)
    G.Log("piece", idx, "pool", pool.key, "card", card or 0, why or "")
    return true
  end

  local function text(id)
    local s = call(G.C.TEXT_GET, id)
    return type(s) == "string" and s or ""
  end

  -- the game's OK window with a text (a text id or a string); waits until it is closed
  function G.Window(id)
    call(G.C.WIN_TEXT, type(id) == "string" and id or text(id), 0, 0, 0, 0, 0, false)
    call(G.C.WIN_BUTTONS, 1, 0)
    call(G.C.WIN_SOUNDS, G.SOUND_DECIDE, G.SOUND_CANCEL)
    while call(G.C.WIN_CLOSED) ~= true do
      coroutine.yield()
    end
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

  -- «You obtained <name>!» in the game's OK window
  function G.Obtained(card)
    local name = call(G.CHARA_NAME, call(G.CHARA_OF_CARD, card) or 0)
    local s = text(G.TEXT_OBTAINED)
    local ok, msg = pcall(string.format, s, type(name) == "string" and name or "")
    G.Window(ok and msg or s)
  end

  -- the whole draw: the cost taken, a card drawn among the candidates, signed, the «obtained» window
  function G.Run(pool)
    local cands = G.Candidates(pool)
    if #cands == 0 then
      G.Window(G.TEXT_EMPTY)
      return nil, "empty"
    end
    if pool.cost_count > 0 and VRFW_Recruit ~= nil and VRFW_Recruit.Items(pool.cost_item) < pool.cost_count then
      local _, _, no_cost = call(G.C.TEXTS, pool.index)
      G.Window((type(no_cost) == "number" and no_cost ~= 0) and no_cost or G.TEXT_NO_COST)
      return nil, "cost"
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
    G.Obtained(card)
    return card
  end
end
