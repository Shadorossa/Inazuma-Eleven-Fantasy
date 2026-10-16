-- menu_engine: chain boards (VR-Framework base feature).
-- Definitions only (this file runs in every script VM, lua\_all): the ONE place that reads a chain board's data (the
-- team type, CMND_VRFW_TEAM_CHAIN_*) and its per-save progress (the save service, owner "vr_framework"). Used by the
-- framework's chain board screen (vrfw_chain_board_menu) and by the board that opens it (a mod's Chronicle board graft:
-- a route_chains graft). Nothing here names a chain, a team or a mod: the tiles come from the mods' TOML
-- ([[chain]] with [[chain.tile]]).
--
-- Progress (per save slot): key "chain.<chain key>" of owner "vr_framework", a string with one character per tile in
-- tile order: "0" not done, "1" / "2" / "3" a won match with rank B / A / S (the best kept), "o" an opened chest. The
-- start tile is always done. A tile is OPEN when it is done or a tile linked to it is done. The chain's rank = the
-- average of its match tiles' ranks (S = 3, A = 2, B = 1), rounded half up, once every match tile is won.
-- A chest's declared rewards are given once (CH.Pay; key "chain.<chain key>.paid" = the paid chests' tile ids).
-- A DOUBLE chest (kind "dchest"): a base reward and a special one (rank S on its branch). Opened
-- without S: the base reward, then it closes again ("h"); opened with S: the special one (and the base one if never
-- taken), then it stays open ("o"). No base reward: it waits for the S. No reward at all: disabled, never opens. Paid
-- parts: "<tile id>" (base) and "<tile id>+s" (special) in "chain.<chain key>.paid".
-- The match being played from a board: key "chain.pending" = "<chain key>|<tile>|<slot>" (slot = the opener's own
-- number, e.g. the Chronicle node's save slot; in memory, never committed).
-- A BLOCKED tile (the 3DS chains' red «prohibited» sign): its requirements (a win against a team on
-- any chain board, a chain completed, the team's level, a player in the club) are checked when a board is shown
-- (CH.Sync); once they are all met and a tile linked to it is done it is marked done ("o", kept: it never closes
-- again), so the tiles behind it open as after a chest.
-- RANK REWARDS of a match tile ([[VRFW.Chain.RankReward]] / [[VRFW.Chain.Tile.RankReward]]): each entry is paid ONCE per
-- tile, at the first win with its rank or a better one (CH.PayRank, from CH.Win; paid marks "<tile id>@<rank>" in
-- "chain.<chain key>.paid"); the items given are kept in "chain.<chain key>.news" until the board screen shows their
-- windows (CH.News / CH.ClearNews). A bag without room: nothing given, retried when the board is shown.
-- No engine call at load time.
if VRFW_Chain == nil then
  local CH = {
    -- the team type's commands (VRFW name, legacy part name)
    CMD = {
      COUNT = {1022542520, 3844893564},     -- CMND_VRFW_TEAM_CHAIN_COUNT
      GET = {495525936, 2209145981},        -- CMND_VRFW_TEAM_CHAIN_GET (i, lang) -> key, mod, host, pachanga, title, ...
      BOARD = {3783110045, 950207577},      -- CMND_VRFW_TEAM_CHAIN_BOARD (i, lang) -> cols, rows, pages, tiles, start, matches, title
      PAGE = {1498965366, 1370193311},      -- CMND_VRFW_TEAM_CHAIN_PAGE (i, p, lang) -> title
      TILE = {1004370514, 858677947},       -- CMND_VRFW_TEAM_CHAIN_TILE (i, t, lang) -> id, kind, page, col, row, links, game, team, level, difficulty, title, rival, emblem, reward, requires, requires names
      OF_PIECE = {735011795, 2747770341},   -- CMND_VRFW_TEAM_CHAIN_OF_PIECE (pieceId) -> chain i, node slot
    },
    SAVE_GET = 2187277743,   -- CMND_VRFW_SAVE_GET (owner, key, default)
    SAVE_SET = 2574269955,   -- CMND_VRFW_SAVE_SET (owner, key, value, commit)
    LOG = 3661580131,        -- CMND_EVT_LOG
    OWNER = "vr_framework",
    PENDING = "chain.pending",
    MENU = 2748171433,       -- crc32("vrfw_chain_board_menu"): the chain board screen
    P_CHAIN = 75385505,      -- crc32("vrfw_chain_board"): parameter, the chain index the screen opens
    P_PICK = 46591264,       -- crc32("vrfw_chain_pick"): parameter, the match tile picked (absent = back)
    -- a chain HUB ([[VRFW.RouteNode]] Kind = "chain_hub"): the screen opens on the list of its chains
    P_HUB = 659670413,       -- crc32("vrfw_chain_hub"): parameter, the hub node's save slot
    P_PICK_CHAIN = 3161495482, -- crc32("vrfw_chain_pick_chain"): parameter out, the picked tile's chain index + 1
    NODE = {COUNT = {1208701503, 3004181703}, GET = {3986876567, 1705651873}},   -- CMND_VRFW_TEAM_ROUTE_NODE_*
    boards = {},             -- chain index -> board table (per VM)
  }
  VRFW_Chain = CH

  local function call(cmd, ...)
    for k = 1, 2 do
      local r = table.pack(pcall(funcLuaCommand, cmd[k], ...))
      if r[1] and r[2] ~= nil then
        return table.unpack(r, 2, r.n)
      end
    end
    return nil
  end

  function CH.Log(...)
    pcall(funcLuaCommand, CH.LOG, "chain", ...)
  end

  local function csv(s)
    local t = {}
    for x in string.gmatch(s or "", "[^,]+") do
      t[#t + 1] = tonumber(x)
    end
    return t
  end

  -- a blocked tile's requirements: "win:<team>;chain:<key>;team_level:<n>;player:<card>" + their names ("a|b|c") ->
  -- {{kind, value (number, or the chain key), name}}
  local function requires(enc, names)
    local out, nm = {}, {}
    for x in string.gmatch((names or "") .. "|", "([^|]*)|") do
      nm[#nm + 1] = x
    end
    for part in string.gmatch(enc or "", "[^;]+") do
      local k, v = string.match(part, "^([%a_]+):(.+)$")
      if k ~= nil then
        out[#out + 1] = {kind = k, value = tonumber(v) or v, name = nm[#out + 1] or ""}
      end
    end
    return out
  end

  -- a match tile's rank rewards: "<rank>:<item>:<count>:<kind>:<text id>,..." + their item names ("a|b") ->
  -- {{rank, id, count, kind ("emblem" / "kit" / "item"), name, text (a menu_text id for the card, 0 = none)}}
  function CH.ParseRankRewards(enc, names)
    local out, nm = {}, {}
    for x in string.gmatch((names or "") .. "|", "([^|]*)|") do
      nm[#nm + 1] = x
    end
    for part in string.gmatch(enc or "", "[^,]+") do
      local r, id, n, k, tx = string.match(part, "^([%w_]+):(%d+):(%d+):(%a+):?(%d*)$")
      if r ~= nil then
        out[#out + 1] = {rank = r, id = tonumber(id), count = math.max(1, tonumber(n) or 1), kind = k, name = nm[#out + 1] or "",
                         text = tonumber(tx) or 0}
      end
    end
    return out
  end

  -- chain i (0-based) as a board table, nil when it has no board:
  -- {i, key, title, cols, rows, layout ("square" / "hex"), pages = {titles}, start (1-based), tiles = {[1..n] = {id, kind, page, col, row (0-based),
  --  links = {1-based}, game, team, level, difficulty, title, rival, emblem, reward, requires = {{kind, value, name}}}}}
  function CH.Board(i)
    if type(i) ~= "number" or i < 0 then
      return nil
    end
    if CH.boards[i] ~= nil then
      return CH.boards[i] or nil
    end
    local cols, rows, pages, ntiles, start, matches, title, layout = call(CH.CMD.BOARD, i)
    if type(cols) ~= "number" or cols <= 0 or type(ntiles) ~= "number" then
      CH.boards[i] = false
      return nil
    end
    local key = call(CH.CMD.GET, i)
    local b = {i = i, key = tostring(key or i), title = title or "", cols = cols, rows = rows, pages = {}, start = start + 1, tiles = {}, matches = matches or 0,
               layout = layout == "hex" and "hex" or "square"}
    for p = 0, pages - 1 do
      b.pages[p + 1] = call(CH.CMD.PAGE, i, p) or ""
    end
    for t = 0, ntiles - 1 do
      local id, kind, page, col, row, links, game, team, level, diff, ttl, rival, emblem, reward, req, reqn, sreward, rrw, rrn = call(CH.CMD.TILE, i, t)
      local links1 = {}
      for _, x in ipairs(csv(links)) do
        links1[#links1 + 1] = x + 1
      end
      b.tiles[t + 1] = {id = id or "", kind = kind or "", page = page or 0, col = col or 0, row = row or 0, links = links1,
                        game = game or 0, team = team or 0, level = level or 0, difficulty = diff or 0, title = ttl or "",
                        rival = rival or "", emblem = emblem or "", reward = reward or "",
                        sreward = type(sreward) == "string" and sreward or "",
                        requires = requires(type(req) == "string" and req or "", type(reqn) == "string" and reqn or ""),
                        rank_rewards = CH.ParseRankRewards(type(rrw) == "string" and rrw or "", type(rrn) == "string" and rrn or "")}
    end
    CH.boards[i] = b
    CH.Log("board", i, b.key, cols, rows, #b.pages, #b.tiles, "start", b.start)
    return b
  end

  -- the chain board a Chronicle board piece opens: board table, node save slot (nil = a plain piece)
  function CH.OfPiece(piece)
    local i, slot = call(CH.CMD.OF_PIECE, piece)
    if type(i) ~= "number" or i < 0 then
      return nil
    end
    return CH.Board(i), slot
  end

  -- ---- progress -----------------------------------------------------------------------------------------------------
  function CH.State(b)
    local ok, s = pcall(funcLuaCommand, CH.SAVE_GET, CH.OWNER, "chain." .. b.key, "")
    if not ok or type(s) ~= "string" then
      s = ""
    end
    if string.len(s) < #b.tiles then
      s = s .. string.rep("0", #b.tiles - string.len(s))
    end
    return s
  end

  function CH.TileState(b, t)
    if t == b.start then
      return "s"
    end
    return string.sub(CH.State(b), t, t)
  end

  local function put(b, t, c)
    local s = CH.State(b)
    s = string.sub(s, 1, t - 1) .. c .. string.sub(s, t + 1)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, "chain." .. b.key, s, 1)
  end

  function CH.Done(b, t)
    return CH.TileState(b, t) ~= "0"
  end

  -- the match tiles of an S chest's branch: every tile reached from it over the links without passing the start
  function CH.Branch(b, t)
    local seen, todo, out = {[t] = true, [b.start] = true}, {t}, {}
    while #todo > 0 do
      local i = table.remove(todo)
      for _, j in ipairs(b.tiles[i].links) do
        if not seen[j] then
          seen[j] = true
          todo[#todo + 1] = j
          if b.tiles[j].kind == "match" then
            out[#out + 1] = j
          end
        end
      end
    end
    return out
  end

  -- an S chest (IE3's «S» chest) is ready once every match of its branch is won with S
  function CH.SReady(b, t)
    local ms = CH.Branch(b, t)
    -- «S» = the rank S's Order (a mod's better ranks count too); without a rank S: the best declared rank
    local need = VRFW_MatchRank ~= nil and VRFW_MatchRank.Order("S") or 3
    if need == 0 and VRFW_MatchRank ~= nil and VRFW_MatchRank.List()[1] ~= nil then
      need = VRFW_MatchRank.List()[1].order
    end
    for _, j in ipairs(ms) do
      if CH.Rank(b, j) < need then
        return false
      end
    end
    return #ms > 0
  end

  -- ---- blocked tiles ---------------------------------------------------------------------------------------------
  -- what the player has towards one requirement of a blocked tile, and whether it is met
  function CH.ReqHave(r)
    if r.kind == "win" then
      return CH.TeamWins(r.value)
    elseif r.kind == "chain" then
      local b = CH.ByKey(r.value)
      return (b ~= nil and CH.Complete(b)) and 1 or 0
    elseif r.kind == "team_level" then
      return VRFW_Recruit ~= nil and VRFW_Recruit.TeamLevel() or 0
    elseif r.kind == "player" then
      return VRFW_Recruit ~= nil and VRFW_Recruit.OwnedAny(csv(tostring(r.value))) or 0
    end
    return 0   -- a kind this build does not know is never met
  end

  function CH.ReqMet(r)
    local need = r.kind == "team_level" and (tonumber(r.value) or 1) or 1
    return CH.ReqHave(r) >= need
  end

  -- every requirement of blocked tile t met
  function CH.Unblocked(b, t)
    local reqs = b.tiles[t].requires or {}
    for _, r in ipairs(reqs) do
      if not CH.ReqMet(r) then
        return false
      end
    end
    return #reqs > 0
  end

  -- a blocked tile reached by the path (a tile linked to it is done)
  local function reached(b, t)
    for _, j in ipairs(b.tiles[t].links) do
      if CH.TileState(b, j) ~= "0" then
        return true
      end
    end
    return false
  end

  -- open the blocked tiles of board b whose requirements are now met (reached ones; repeated so a chain of blocked
  -- tiles opens at once); returns the tiles opened. The board screen calls it when it shows a board.
  function CH.Sync(b)
    local opened = {}
    local again = true
    while again do
      again = false
      for t, tile in ipairs(b.tiles) do
        if tile.kind == "blocked" and CH.TileState(b, t) == "0" and reached(b, t) and CH.Unblocked(b, t) then
          put(b, t, "o")
          opened[#opened + 1] = t
          again = true
          CH.Log("unblocked", b.key, tile.id)
        end
      end
    end
    return opened
  end

  -- a double chest with no reward declared: disabled (never opens)
  function CH.DChestEmpty(b, t)
    local tile = b.tiles[t]
    return tile ~= nil and tile.kind == "dchest" and tile.reward == "" and (tile.sreward or "") == ""
  end

  function CH.Open(b, t)
    if CH.Done(b, t) then
      return true
    end
    if b.tiles[t].kind == "slot" or b.tiles[t].kind == "blocked" or (b.tiles[t].kind == "schest" and not CH.SReady(b, t))
        or CH.DChestEmpty(b, t) then
      return false   -- a slot (a placeholder tile, no team yet) never opens; a blocked tile opens by CH.Sync only
    end
    for _, j in ipairs(b.tiles[t].links) do
      if CH.Done(b, j) then
        return true
      end
    end
    return false
  end

  -- the rank Ids of won tiles that are not S / A / B: save key chain.<chain key>.ranks = "<tile>=<Id>;..." (the
  -- tile's character is "r"); S / A / B stay the digits 3 / 2 / 1 older saves have
  local function rank_map(b)
    local ok, s = pcall(funcLuaCommand, CH.SAVE_GET, CH.OWNER, "chain." .. b.key .. ".ranks", "")
    local m = {}
    if ok and type(s) == "string" then
      for t, id in string.gmatch(s, "(%d+)=([^;]+)") do
        m[tonumber(t)] = id
      end
    end
    return m
  end

  local function put_rank(b, t, id)
    local m = rank_map(b)
    m[t] = id
    local parts = {}
    for k, v in pairs(m) do
      parts[#parts + 1] = k .. "=" .. v
    end
    table.sort(parts)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, "chain." .. b.key .. ".ranks", table.concat(parts, ";"), 1)
  end

  -- the rank Id of a won match tile (nil = not won)
  function CH.RankId(b, t)
    local c = CH.TileState(b, t)
    if c == "r" then
      return rank_map(b)[t]
    end
    local n = tonumber(c)
    if n ~= nil and n > 0 then
      return VRFW_MatchRank ~= nil and VRFW_MatchRank.FromLegacy(n) or ({"B", "A", "S"})[n]
    end
    return nil
  end

  -- the Order of a won match tile's rank (0 = not won; a won tile whose rank is no longer declared counts 1)
  function CH.Rank(b, t)
    local id = CH.RankId(b, t)
    if id == nil then
      return 0
    end
    local o = VRFW_MatchRank ~= nil and VRFW_MatchRank.Order(id) or 0
    return o > 0 and o or 1
  end

  -- the win counter's floor for older saves (VRFW_Stats, 34_stats.lua, loaded after this file: registered on first
  -- use): every won match tile of the boards this VM has read counts one win against its team; the counter starts from
  -- it at its first win, so a save from before never shows 0 for a team it already beat
  local floor_on = false
  local function stats()
    if VRFW_Stats == nil then
      return nil
    end
    if not floor_on then
      floor_on = true
      VRFW_Stats.AddFloor(function(team)
        local n = 0
        for _, b in pairs(CH.boards) do
          if b then
            for t, tile in ipairs(b.tiles) do
              if tile.kind == "match" and tile.team == team and CH.Done(b, t) then
                n = n + 1
              end
            end
          end
        end
        return n
      end)
    end
    return VRFW_Stats
  end

  -- a won match: its rank (an Id; an older caller's 1 / 2 / 3 = B / A / S) kept when better; returns the Id now stored
  function CH.Win(b, t, rank)
    local id = rank
    if type(rank) ~= "string" then
      id = ({"B", "A", "S"})[math.max(1, math.min(3, math.floor(tonumber(rank) or 1)))]
    end
    -- the per-save win counter (VRFW_Stats, 34_stats.lua) first: its floor still sees this tile's previous state
    if stats() ~= nil and b.tiles[t] ~= nil and b.tiles[t].kind == "match" then
      VRFW_Stats.AddWin(b.tiles[t].team)
    end
    local old = CH.RankId(b, t)
    local better = old == nil or (VRFW_MatchRank ~= nil and VRFW_MatchRank.Order(id) > VRFW_MatchRank.Order(old))
    if better then
      local legacy = ({B = "1", A = "2", S = "3"})[id]
      if legacy ~= nil then
        put(b, t, legacy)
      else
        put_rank(b, t, id)
        put(b, t, "r")
      end
      old = id
    end
    CH.Log("win", b.key, b.tiles[t].id, "rank", id, "best", old)
    -- the rank rewards this win earns (first win at that rank or better; a full bag: paid when the board is shown)
    if #((b.tiles[t] or {}).rank_rewards or {}) > 0 then
      CH.PayRank(b, t)
    end
    return old
  end

  -- a chest opened (its rewards: CH.Pay). A double chest: "o" when its branch is all S, else
  -- "h" (base reward taken, closed again); "h" -> "o" once the branch is all S. Returns the tile's state now.
  function CH.OpenChest(b, t)
    local tile = b.tiles[t]
    if tile.kind == "dchest" then
      local st = CH.TileState(b, t)
      if CH.DChestEmpty(b, t) or st == "o" then
        return st
      end
      if CH.SReady(b, t) then
        put(b, t, "o")
      elseif st == "0" and tile.reward ~= "" then
        put(b, t, "h")
      end
      CH.Log("chest", b.key, tile.id, CH.TileState(b, t))
      return CH.TileState(b, t)
    end
    if not CH.Done(b, t) then
      put(b, t, "o")
      CH.Log("chest", b.key, tile.id)
    end
    return CH.TileState(b, t)
  end

  -- a double chest the player can open now: reached, not disabled, and either never opened (with a base reward, or with
  -- S) or opened once without S and now S-ready
  function CH.DChestReady(b, t)
    if not CH.Open(b, t) or CH.DChestEmpty(b, t) then
      return false
    end
    local st, tile = CH.TileState(b, t), b.tiles[t]
    if st == "o" then
      return false
    end
    if CH.SReady(b, t) then
      return (tile.sreward or "") ~= "" or st == "0"
    end
    return st == "0" and tile.reward ~= ""
  end

  -- ---- chest rewards ---------------------------------------------------------------------------
  -- A chest / S chest pays its declared [[VRFW.Chain.Tile.Reward]]s ONCE, when it is opened (or, for a chest opened
  -- before the payout existed, the next time its board is shown). Paid chests: save key "chain.<chain key>.paid" of
  -- owner "vr_framework" = their tile ids, ";"-separated (kept with the game's own save: the screen asks for the
  -- game's autosave right after a payout, so the items and the mark are saved together).
  CH.ITEM_FITS = 765340069     -- (item, n) -> the bag has room
  CH.ITEM_ADD = 1897915498     -- CMND_ADD_ITEM_ONLY (item, n): no window (the screen shows the retail one)
  CH.AUTO_SAVE = 3673719958    -- CMND_SYSTEM_AUTO_SAVE

  -- a chest's declared rewards: {{kind = "item", id, count} / {kind = "player", id = card}} (special = a double chest's
  -- rank-S reward)
  function CH.Rewards(b, t, special)
    local out = {}
    local tile = b.tiles[t]
    local enc = tile ~= nil and (special and (tile.sreward or "") or tile.reward) or ""
    for part in string.gmatch(enc, "[^,]+") do
      local card = string.match(part, "^player:(%d+)$")
      local id, n = string.match(part, "^(%d+):(%d+)$")
      if card ~= nil then
        out[#out + 1] = {kind = "player", id = tonumber(card), count = 1}
      elseif id ~= nil then
        out[#out + 1] = {kind = "item", id = tonumber(id), count = math.max(1, tonumber(n) or 1)}
      else
        CH.Log("reward not understood", b.key, tile.id, part)
      end
    end
    return out
  end

  local function paid_set(b)
    local ok, s = pcall(funcLuaCommand, CH.SAVE_GET, CH.OWNER, "chain." .. b.key .. ".paid", "")
    local m = {}
    if ok and type(s) == "string" then
      for id in string.gmatch(s, "[^;]+") do
        m[id] = true
      end
    end
    return m
  end

  -- chest t's rewards already given in this save
  function CH.Paid(b, t)
    return paid_set(b)[b.tiles[t].id] == true
  end

  -- the parts of chest t due and not paid yet: {{special = false / true}} (a chest: its reward once opened; a double
  -- chest: the base once opened ("h" / "o"), the special one once "o")
  local function due(b, t, m)
    local tile, st = b.tiles[t], CH.TileState(b, t)
    local out = {}
    if tile.kind == "chest" or tile.kind == "schest" then
      if tile.reward ~= "" and st == "o" and not m[tile.id] then
        out[#out + 1] = false
      end
    elseif tile.kind == "dchest" then
      if tile.reward ~= "" and (st == "h" or st == "o") and not m[tile.id] then
        out[#out + 1] = false
      end
      if (tile.sreward or "") ~= "" and st == "o" and not m[tile.id .. "+s"] then
        out[#out + 1] = true
      end
    end
    return out
  end

  -- the opened chests of board b whose declared rewards were never given (tile indices)
  function CH.Unpaid(b)
    local out, m = {}, nil
    for t, tile in ipairs(b.tiles) do
      if (tile.kind == "chest" or tile.kind == "schest" or tile.kind == "dchest") and CH.TileState(b, t) ~= "0" then
        m = m or paid_set(b)
        if #due(b, t, m) > 0 then
          out[#out + 1] = t
        end
      end
    end
    return out
  end

  local function hex(v)
    v = math.floor(tonumber(v) or 0) % 4294967296
    return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
  end

  -- give opened chest t's rewards once. Returns the rewards given (the list of CH.Rewards; empty = none declared or
  -- already paid), or nil + why ("closed", "full": the bag has no room for every item, nothing given, retried later).
  -- A player reward goes through VRFW_Recruit.Sign (a card already in the club is skipped). Never twice: the tile id
  -- joins "chain.<key>.paid" before the autosave.
  function CH.Pay(b, t)
    local tile = b.tiles[t]
    if tile == nil or (tile.kind ~= "chest" and tile.kind ~= "schest" and tile.kind ~= "dchest") or CH.TileState(b, t) == "0" then
      return nil, "closed"
    end
    local m = paid_set(b)
    -- the parts due now (a chest: one; a double chest: base and / or special) and their marks in the paid set
    local parts_due = due(b, t, m)
    if #parts_due == 0 then
      return {}
    end
    local rw, marks = {}, {}
    for _, special in ipairs(parts_due) do
      for _, r in ipairs(CH.Rewards(b, t, special)) do
        rw[#rw + 1] = r
      end
      marks[#marks + 1] = special and (tile.id .. "+s") or tile.id
    end
    if #rw == 0 then
      return {}
    end
    for _, r in ipairs(rw) do
      if r.kind == "item" then
        local ok, fits = pcall(funcLuaCommand, CH.ITEM_FITS, r.id, r.count)
        if ok and fits == false then
          CH.Log("chest reward waits: bag full", b.key, tile.id, hex(r.id), "x", r.count)
          return nil, "full"
        end
      end
    end
    local given, parts = {}, {}
    for _, r in ipairs(rw) do
      if r.kind == "item" then
        pcall(funcLuaCommand, CH.ITEM_ADD, r.id, r.count)
        given[#given + 1] = r
        parts[#parts + 1] = "item " .. hex(r.id) .. " x" .. r.count
      elseif r.kind == "player" then
        local hdl, why = nil, "no recruit service"
        if VRFW_Recruit ~= nil then
          hdl, why = VRFW_Recruit.Sign(r.id, 1)
        end
        if hdl ~= nil then
          given[#given + 1] = r
          parts[#parts + 1] = "player " .. hex(r.id)
        else
          parts[#parts + 1] = "player " .. hex(r.id) .. " skipped (" .. tostring(why) .. ")"
        end
      end
    end
    for _, k in ipairs(marks) do
      m[k] = true
    end
    local ids = {}
    for id in pairs(m) do
      ids[#ids + 1] = id
    end
    table.sort(ids)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, "chain." .. b.key .. ".paid", table.concat(ids, ";"), 0)
    pcall(funcLuaCommand, CH.AUTO_SAVE)
    CH.Log("chest paid", b.key, table.concat(marks, "/"), table.concat(parts, ", "))
    return given
  end

  -- ---- rank rewards ---------------------------------------------------------------------------
  -- the Order of a rank Id (0 = not declared)
  local function order_of(id)
    return VRFW_MatchRank ~= nil and VRFW_MatchRank.Order(id) or (({B = 1, A = 2, S = 3})[id] or 0)
  end

  -- match tile t's rank rewards: {{rank, id, count, kind, name, paid (true / false), earned (its rank or better won)}}
  function CH.RankRewards(b, t)
    local tile = b.tiles[t]
    local out = {}
    if tile == nil or tile.kind ~= "match" then
      return out
    end
    local m = paid_set(b)
    local best = CH.Rank(b, t)
    for _, r in ipairs(tile.rank_rewards or {}) do
      local o = order_of(r.rank)
      out[#out + 1] = {rank = r.rank, id = r.id, count = r.count, kind = r.kind, name = r.name, text = r.text or 0,
                       paid = m[tile.id .. "@" .. r.rank] == true, earned = o > 0 and best >= o}
    end
    return out
  end

  -- the rank rewards of tile t earned and not paid yet
  local function rank_due(b, t)
    local out = {}
    for _, r in ipairs(CH.RankRewards(b, t)) do
      if r.earned and not r.paid then
        out[#out + 1] = r
      end
    end
    return out
  end

  -- the match tiles of board b with earned rank rewards never given (a full bag at the win)
  function CH.RankUnpaid(b)
    local out = {}
    for t, tile in ipairs(b.tiles) do
      if tile.kind == "match" and #(tile.rank_rewards or {}) > 0 and #rank_due(b, t) > 0 then
        out[#out + 1] = t
      end
    end
    return out
  end

  -- give tile t's earned rank rewards once. Returns the rewards given ({} = none due), or nil + "full" (the bag has no
  -- room for every item: nothing given, retried later). The items join "chain.<key>.news" (CH.News) for the windows.
  -- `save`: ask for the game's autosave after it (the board screen; after a match the items and the marks are
  -- committed together with the game's own save)
  function CH.PayRank(b, t, save)
    local tile = b.tiles[t]
    local due = rank_due(b, t)
    if #due == 0 then
      return {}
    end
    for _, r in ipairs(due) do
      local ok, fits = pcall(funcLuaCommand, CH.ITEM_FITS, r.id, r.count)
      if ok and fits == false then
        CH.Log("rank reward waits: bag full", b.key, tile.id, r.rank, hex(r.id), "x", r.count)
        return nil, "full"
      end
    end
    local m = paid_set(b)
    local parts, news = {}, CH.NewsText(b)
    for _, r in ipairs(due) do
      pcall(funcLuaCommand, CH.ITEM_ADD, r.id, r.count)
      m[tile.id .. "@" .. r.rank] = true
      parts[#parts + 1] = r.rank .. " item " .. hex(r.id) .. " x" .. r.count
      news = news .. (news ~= "" and "," or "") .. string.format("%d:%d", r.id, r.count)
    end
    local ids = {}
    for id in pairs(m) do
      ids[#ids + 1] = id
    end
    table.sort(ids)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, "chain." .. b.key .. ".paid", table.concat(ids, ";"), 0)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, "chain." .. b.key .. ".news", news, 0)
    if save then
      pcall(funcLuaCommand, CH.AUTO_SAVE)
    end
    CH.Log("rank reward paid", b.key, tile.id, table.concat(parts, ", "))
    return due
  end

  function CH.NewsText(b)
    local ok, s = pcall(funcLuaCommand, CH.SAVE_GET, CH.OWNER, "chain." .. b.key .. ".news", "")
    return (ok and type(s) == "string") and s or ""
  end

  -- the rank-reward items given since the board was last shown: {{id, count}}
  function CH.News(b)
    local out = {}
    for id, n in string.gmatch(CH.NewsText(b), "(%d+):(%d+)") do
      out[#out + 1] = {id = tonumber(id), count = tonumber(n)}
    end
    return out
  end

  function CH.ClearNews(b)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, "chain." .. b.key .. ".news", "", 0)
  end

  -- every match tile won
  function CH.Complete(b)
    for t, tile in ipairs(b.tiles) do
      if tile.kind == "match" and CH.Rank(b, t) == 0 then
        return false
      end
    end
    return b.matches > 0
  end

  -- the chain's rank: the average Order of its match tiles' ranks, as the best rank whose Order is at most that
  -- average rounded half up (VRFW_MatchRank.ForOrder; nil until every match is won)
  function CH.Average(b)
    if not CH.Complete(b) then
      return nil
    end
    local sum, n = 0, 0
    for t, tile in ipairs(b.tiles) do
      if tile.kind == "match" then
        sum, n = sum + CH.Rank(b, t), n + 1
      end
    end
    if n == 0 or VRFW_MatchRank == nil then
      return nil
    end
    return VRFW_MatchRank.ForOrder(sum / n)
  end

  -- the number of won match tiles of a board
  function CH.Won(b)
    local n = 0
    for t, tile in ipairs(b.tiles) do
      if tile.kind == "match" and CH.Rank(b, t) > 0 then
        n = n + 1
      end
    end
    return n
  end

  -- ---- chain hubs ----------------------------------------------------------------------------------
  -- the boards of the chain hub whose node has save slot `slot`, in the hub's order (nil = not a hub)
  function CH.Hub(slot)
    if type(slot) ~= "number" then
      return nil
    end
    CH.hubs = CH.hubs or {}
    if CH.hubs[slot] ~= nil then
      return CH.hubs[slot] or nil
    end
    CH.hubs[slot] = false
    local n = call(CH.NODE.COUNT)
    for i = 0, (type(n) == "number" and n or 0) - 1 do
      local _, s, _, _, _, _, _, _, _, _, hub = call(CH.NODE.GET, i)
      if s == slot and type(hub) == "string" and hub ~= "" then
        local list = {}
        for _, ci in ipairs(csv(hub)) do
          local b = CH.Board(ci)
          if b ~= nil then
            list[#list + 1] = b
          end
        end
        if #list > 0 then
          CH.hubs[slot] = list
          CH.Log("hub", slot, #list)
        end
        break
      end
    end
    return CH.hubs[slot] or nil
  end

  -- every chain of a hub complete
  function CH.HubComplete(boards)
    for _, b in ipairs(boards) do
      if not CH.Complete(b) then
        return false
      end
    end
    return #boards > 0
  end

  -- a hub's rank: the average Order of its chains' ranks, as CH.Average does for tiles (nil until every chain is complete)
  function CH.HubAverage(boards)
    if not CH.HubComplete(boards) or VRFW_MatchRank == nil then
      return nil
    end
    local sum = 0
    for _, b in ipairs(boards) do
      local id = CH.Average(b)
      local o = id ~= nil and VRFW_MatchRank.Order(id) or 0
      sum = sum + (o > 0 and o or 1)
    end
    return VRFW_MatchRank.ForOrder(sum / #boards)
  end

  -- ---- the match being played ----------------------------------------------------------------------------------------
  function CH.SetPending(b, t, slot)
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, CH.PENDING, b.key .. "|" .. tostring(t) .. "|" .. tostring(slot or -1), 0)
  end

  -- chain key, tile, opener's slot of the match started from a board (nil = none)
  function CH.Pending()
    local ok, s = pcall(funcLuaCommand, CH.SAVE_GET, CH.OWNER, CH.PENDING, "")
    if not ok or type(s) ~= "string" or s == "" then
      return nil
    end
    local k, t, slot = string.match(s, "^(.*)|(%d+)|(%-?%d+)$")
    if k == nil then
      return nil
    end
    return k, tonumber(t), tonumber(slot)
  end

  function CH.ClearPending()
    pcall(funcLuaCommand, CH.SAVE_SET, CH.OWNER, CH.PENDING, "", 0)
  end

  -- the board table of chain key `key` (nil = none)
  function CH.ByKey(key)
    local n = call(CH.CMD.COUNT)
    if type(n) ~= "number" then
      return nil
    end
    for i = 0, n - 1 do
      local k = call(CH.CMD.GET, i)
      if k == key then
        return CH.Board(i)
      end
    end
    return nil
  end

  -- the wins against team id `team` in this save (VRFW_Stats; without it: the won match tiles against it on the boards
  -- this VM has read)
  function CH.TeamWins(team)
    if stats() ~= nil then
      return VRFW_Stats.WinsVs(team)
    end
    local n = 0
    for _, b in pairs(CH.boards) do
      if b then
        for t, tile in ipairs(b.tiles) do
          if tile.kind == "match" and tile.team == team and CH.Done(b, t) then
            n = n + 1
          end
        end
      end
    end
    return n
  end

  -- the wins against a match tile's team in this save (VRFW_Stats; without it: 1 once the tile is won)
  function CH.WinsVs(b, t)
    local tile = b.tiles[t]
    if tile == nil or tile.kind ~= "match" then
      return 0
    end
    if stats() ~= nil then
      return VRFW_Stats.WinsVs(tile.team)
    end
    return CH.Done(b, t) and 1 or 0
  end
end
