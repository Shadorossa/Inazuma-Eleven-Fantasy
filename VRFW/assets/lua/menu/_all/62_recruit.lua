-- menu_engine: the RECRUIT service. Definitions only: this file runs in
-- every menu VM (lua\_all) after the retail chunk; no engine call at load time.
--
-- ONE place that signs a character card into the player's club without a shop row, checks recruitment requirements
-- and charges / pays items. Callers differ only by their rules (the contact map screen vrfw_contact_map_menu today;
-- an office, a pachanga, a field event can use the same functions). Nothing here names a character, an item or a mod.
--
--   VRFW_Recruit.Owned(param)                 -> copies of that card in the club (0 = none)
--   VRFW_Recruit.OwnedAny(ids)                -> sum over a list of cards
--   VRFW_Recruit.Items(id)                    -> how many of item `id` the player has
--   VRFW_Recruit.Have(req)                    -> what the player has towards one requirement
--   VRFW_Recruit.Missing(reqs)                -> the requirements not met (list, same tables)
--   VRFW_Recruit.Charge(item, n)              -> true when n of `item` were taken (false: not enough, nothing taken)
--   VRFW_Recruit.Give(item, n)                -> true when the bag had room and n were added
--   VRFW_Recruit.CanSign(param)               -> true, or false + why ("owned" / "bank_full")
--   VRFW_Recruit.Sign(param, level, rarity, source) -> handle or nil + why: the game's own add-character path
--   VRFW_Recruit.Recruit(opt)                 -> true or false + why: requirements, price, sign, autosave in one call
--   VRFW_Recruit.Spirits(card)                -> how many spirits of that card the stock holds (every rarity 0-4)
--   VRFW_Recruit.ChargeSpirits(card, n) / GiveSpirits(card, n) -> true when done (a price paid in spirits, e.g. the
--                                               element spirits as the classic «fichas»)
--   VRFW_Recruit.Holders(cards)               -> { {handle, param, level, busy}, ... } the club players of those cards
--   VRFW_Recruit.Release(cards, refund)       -> true or false + why: the bank's own retire of the first club player of
--                                               those cards (refund = {spirit = card, count = n} or {item, count} given)
--
-- A requirement (kept, never taken): {kind = "player", ids = {card, ...}, count = n} (n copies among those cards in the
-- club), {kind = "item", id = item, count = n} (have at least n), {kind = "team_level", count = n} (the active team's
-- level >= n: the team dock in use, CMND_GET_TEAM_SET_INFO(dock, 0, 1)), {kind = "element", element = e, count = n}
-- (n players of element e in the club: 1 wind, 2 forest, 3 fire, 4 mountain, 5 void), {kind = "position", position = p,
-- count = n} (n players of main position p in the club: 1 GK, 2 FW, 3 MF, 4 DF), {kind = "wins", count = n} (matches won
-- in this save slot), {kind = "goals", count = n} (goals scored), {kind = "cleared", games = {game, difficulty, ...}}
-- (1 when any of those matches was won at that difficulty: CMND_GET_SOCCER_GAME_CLEAR_FLAG), {kind = "unlock", groups =
-- {{check, ...}, ...}} (1 when every group has a check that holds; check = {t = "game", a = game, b = difficulty} /
-- {t = "chronicle", a = status flag index, b = difficulty} / {t = "flag", a = global bit flag}), {kind = "trial",
-- friendly, tag, sub} (1 once that friendly was passed for tag / sub: CMND_VRFW_FRIENDLY_PASSED); a "player"
-- requirement with `level` counts only the club players at that level or more. The club counts come from
-- the framework's script (CMND_VRFW_RECRUIT_CLUB, scripts\recruit.lua) and the cleared answers are cached until
-- VRFW_Recruit.Refresh(); the career counters are the save service's keys stats.matches_won / stats.goals (owner
-- vr_framework, the same script counts them).
--
-- The add-character path (CMND_ADD_PARTY): the
-- retail summon screen's AddSummonChara call (20 arguments: card, level, ..., team set 16 = the normal bank, rarity,
-- ..., source), then 0xB349C762 as AddSummonChara does, the season bit 0x100000 cleared on the new player
-- (VRFW_Recruit.ClearSeason: no seasonal cards with the framework), then CMND_SYSTEM_AUTO_SAVE. Safe in the menus of a loaded save
-- (the office, the Mercado); never in free walk (the autosave is blocked there).
if VRFW_Recruit == nil then
  local R = {
    C = {
      ADD_PARTY = VRFW_Cmd.ADD_PARTY,        -- CMND_ADD_PARTY 0x705FC228
      AFTER_ADD = 3007956834,        -- 0xB349C762: retail AddSummonChara calls it right after CMND_ADD_PARTY
      AUTO_SAVE = VRFW_Cmd.SYSTEM_AUTO_SAVE,        -- CMND_SYSTEM_AUTO_SAVE
      OWNED = 1052152255,            -- (card, 0) -> ok, n / n: copies of the card in the club
      BANK_FREE = VRFW_Cmd.CAN_SPIRIT_NUM,        -- CMND_CAN_SPIRIT_NUM -> free bank slots
      ITEM_NUM = VRFW_Cmd.GET_ITEM_NUM,         -- CMND_GET_ITEM_NUM (id, false) -> count
      DEL_ITEM = VRFW_Cmd.DELETE_ITEM,          -- CMND_DELETE_ITEM (id, n) -> ok (never below the equipped count)
      ITEM_FITS = 765340069,         -- (id, n) -> the bag has room
      ADD_ITEM = VRFW_Cmd.ADD_ITEM_ONLY,         -- CMND_ADD_ITEM_ONLY (id, n): no window
      LOG = VRFW_Cmd.EVT_LOG,              -- CMND_EVT_LOG
      CLUB = VRFW_Cmd.VRFW_RECRUIT_CLUB,             -- CMND_VRFW_RECRUIT_CLUB () -> {total, element = {..}, position = {..}}
      SAVE_GET = VRFW_Cmd.VRFW_SAVE_GET,         -- CMND_VRFW_SAVE_GET (owner, key, default)
      IN_STORY = 424926145,          -- true while the story's play mode runs (menu_def GetActiveTeamDockNoByMode)
      STORY_DOCK = 2787124386,       -- the story's team dock in use
      VS_DOCK = VRFW_Cmd.GET_VS_USE_TEAM_SET,          -- CMND_GET_VS_USE_TEAM_SET: the team dock in use outside the story
      TEAM_SET_INFO = VRFW_Cmd.GET_TEAM_SET_INFO,    -- CMND_GET_TEAM_SET_INFO (dock, 0, 1) -> ok, team level
      GAME_CLEAR = VRFW_Cmd.GET_SOCCER_GAME_CLEAR_FLAG,        -- CMND_GET_SOCCER_GAME_CLEAR_FLAG (game, difficulty) -> won
      CHRONICLE_CLEAR = VRFW_Cmd.GET_CHRONICLE_CLEAR_STATUS,  -- CMND_GET_CHRONICLE_CLEAR_STATUS (status flag index, difficulty) -> cleared
      GLOBAL_BIT = VRFW_Cmd.GET_GLOBAL_BIT_FLAG,        -- CMND_GET_GLOBAL_BIT_FLAG (flag) -> on
      PASSED = 3228376551,           -- CMND_VRFW_FRIENDLY_PASSED (friendly id, tag, sub) -> passed
      HOLDERS = VRFW_Cmd.VRFW_RECRUIT_HOLDERS,          -- CMND_VRFW_RECRUIT_HOLDERS (card, ...) -> { {handle, param, level, busy}, ... }
      SPIRIT_NUM = VRFW_Cmd.GET_SPIRIT_NUM,       -- CMND_GET_SPIRIT_NUM (card, rarity) -> ok, n
      ADD_SPIRIT = VRFW_Cmd.ADD_ITEM_SPIRIT,       -- CMND_ADD_ITEM_SPIRIT (card, n, rarity, used): n < 0 takes
      RETIRE = 3955826921,           -- the bank's retire (funcLuaMenuCommand, handle) -> ok
      STATUS = 1131797651,           -- (handle, field) -> a value of the player's status (12 = rarity)
      HAS_ATTRIBUTE = 29506568,      -- 0x01C23C08 (handle, mask) -> the player's attribute has those bits
      SET_ATTRIBUTE = 1525180681,    -- 0x5AE86909 (handle, mask, on): sets / clears attribute bits
    },
    ATTRIBUTE_SEASON = 0x100000,     -- the «Jugador de temporada» bit CMND_ADD_PARTY leaves on these signings
    SPIRIT_RARITIES = {0, 1, 2, 3, 4},   -- a spirit price is paid with any rarity, lowest first
    holders = {},                    -- card list -> club players, until Refresh()
    cleared = {},                    -- "game:difficulty" -> won, until Refresh()
    OWNER = "vr_framework",
    club = nil,                      -- the club counts (CMND_VRFW_RECRUIT_CLUB), until Refresh()
    TEAM_SET_BANK = 16,              -- CMND_ADD_PARTY arg 10: 16 = no logical team set (the normal bank)
    RARITY = 4,                      -- the office's default join rarity (a normal card)
    SOURCE = 2,                      -- CMND_ADD_PARTY arg 17: 2 = scouted (the office uses 4)
  }
  VRFW_Recruit = R

  local function call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  local function num(v)
    if type(v) ~= "number" then
      return 0
    end
    return math.floor(v + 0.5)
  end

  function R.Log(...)
    pcall(funcLuaCommand, R.C.LOG, "recruit", ...)
  end

  function R.Owned(param)
    local a, b = call(R.C.OWNED, param, 0)
    if type(a) == "number" then
      return num(a)                  -- some builds answer the count first
    end
    return num(b)
  end

  function R.OwnedAny(ids)
    local n = 0
    for _, id in ipairs(ids or {}) do
      n = n + R.Owned(id)
    end
    return n
  end

  function R.Items(id)
    return num(call(R.C.ITEM_NUM, id, false))
  end

  -- forget the club counts (after a signing, or when a screen opens)
  function R.Refresh()
    R.club = nil
    R.cleared = {}
    R.holders = {}
  end

  -- the club players of some cards (cached per list until Refresh)
  function R.Holders(ids)
    local key = table.concat(ids or {}, ",")
    if R.holders[key] == nil then
      local list = call(R.C.HOLDERS, table.unpack(ids or {}))
      R.holders[key] = type(list) == "table" and list or {}
    end
    return R.holders[key]
  end

  local function check(c)
    local key = tostring(c.t) .. ":" .. tostring(c.a) .. ":" .. tostring(c.b)
    local v = R.cleared[key]
    if v == nil then
      if c.t == "game" then
        v = call(R.C.GAME_CLEAR, c.a, c.b) == true
      elseif c.t == "chronicle" then
        v = (c.a or 0) > 0 and call(R.C.CHRONICLE_CLEAR, c.a, c.b) == true
      elseif c.t == "flag" then
        v = call(R.C.GLOBAL_BIT, c.a) == true
      else
        v = false
      end
      R.cleared[key] = v
    end
    return v
  end

  -- 1 when every group has a check that holds
  function R.Unlocked(groups)
    for _, g in ipairs(groups or {}) do
      local any = false
      for _, c in ipairs(g) do
        if check(c) then
          any = true
          break
        end
      end
      if not any then
        return 0
      end
    end
    return 1
  end

  local function spirit_num(card, r)
    local a, b = call(R.C.SPIRIT_NUM, card, r)
    local v = type(b) == "number" and b or (type(a) == "number" and a or 0)
    return math.max(0, num(v))
  end

  function R.Spirits(card)
    local n = 0
    for _, r in ipairs(R.SPIRIT_RARITIES) do
      n = n + spirit_num(card, r)
    end
    return n
  end

  -- takes n spirits of the card, the lowest rarity first; a rarity is only asked for what it holds (a negative add
  -- past the stock would wrap)
  function R.ChargeSpirits(card, n)
    n = num(n)
    if n <= 0 then
      return true
    end
    if R.Spirits(card) < n then
      return false
    end
    local left = n
    for _, r in ipairs(R.SPIRIT_RARITIES) do
      if left <= 0 then
        break
      end
      local take = math.min(spirit_num(card, r), left)
      if take > 0 then
        call(R.C.ADD_SPIRIT, card, -take, r, false)
        left = left - take
      end
    end
    return left <= 0
  end

  function R.GiveSpirits(card, n)
    n = num(n)
    if n > 0 then
      call(R.C.ADD_SPIRIT, card, n, 4, false)
    end
    return true
  end

  -- a price: {item = id, count = n} or {spirit = card, count = n}
  function R.Pay(price)
    if price == nil or (price.count or 0) <= 0 then
      return true
    end
    if price.spirit ~= nil and price.spirit ~= 0 then
      return R.ChargeSpirits(price.spirit, price.count)
    end
    return R.Charge(price.item, price.count)
  end

  function R.Refund(price)
    if price == nil or (price.count or 0) <= 0 then
      return
    end
    if price.spirit ~= nil and price.spirit ~= 0 then
      R.GiveSpirits(price.spirit, price.count)
    else
      R.Give(price.item, price.count)
    end
  end

  -- what the player has to pay with: the spirits of `spirit`, else the item
  function R.Wallet(price)
    if price ~= nil and price.spirit ~= nil and price.spirit ~= 0 then
      return R.Spirits(price.spirit)
    end
    return R.Items(price and price.item or 0)
  end

  -- 1 when any (game, difficulty) pair of the flat list was won, else 0
  function R.Cleared(games)
    if type(games) ~= "table" then
      return 0
    end
    for i = 1, #games - 1, 2 do
      local key = tostring(games[i]) .. ":" .. tostring(games[i + 1])
      local won = R.cleared[key]
      if won == nil then
        won = call(R.C.GAME_CLEAR, games[i], games[i + 1]) == true
        R.cleared[key] = won
      end
      if won then
        return 1
      end
    end
    return 0
  end

  function R.Club()
    if R.club == nil then
      local c = call(R.C.CLUB)
      R.club = type(c) == "table" and c or {total = 0, element = {}, position = {}}
    end
    return R.club
  end

  -- the level of the team in use (1 when it cannot be read)
  function R.TeamLevel()
    local dock
    if call(R.C.IN_STORY) == true then
      dock = call(R.C.STORY_DOCK)
    else
      dock = call(R.C.VS_DOCK)
    end
    local ok, lv = call(R.C.TEAM_SET_INFO, num(dock), 0, 1)
    if ok == true and type(lv) == "number" then
      return num(lv)
    end
    return 1
  end

  function R.Career(key)
    return num(tonumber(call(R.C.SAVE_GET, R.OWNER, key, "0")))
  end

  function R.Have(req)
    local k = req.kind
    if k == "player" then
      if (req.level or 0) > 1 then
        local n = 0
        for _, h in ipairs(R.Holders(req.ids)) do
          if (h.level or 0) >= req.level then
            n = n + 1
          end
        end
        return n
      end
      return R.OwnedAny(req.ids)
    elseif k == "item" then
      return R.Items(req.id)
    elseif k == "team_level" then
      return R.TeamLevel()
    elseif k == "element" then
      return num((R.Club().element or {})[req.element])
    elseif k == "position" then
      return num((R.Club().position or {})[req.position])
    elseif k == "wins" then
      return R.Career("stats.matches_won")
    elseif k == "goals" then
      return R.Career("stats.goals")
    elseif k == "cleared" then
      return R.Cleared(req.games)
    elseif k == "unlock" then
      return R.Unlocked(req.groups)
    elseif k == "trial" then
      local key = "trial:" .. tostring(req.friendly) .. ":" .. tostring(req.tag) .. ":" .. tostring(req.sub)
      if R.cleared[key] == nil then
        R.cleared[key] = call(R.C.PASSED, req.friendly, req.tag or 0, req.sub or 0) == true
      end
      return R.cleared[key] and 1 or 0
    end
    return 0                         -- a kind this build does not know is never met (never sold by mistake)
  end

  function R.Missing(reqs)
    local out = {}
    for _, q in ipairs(reqs or {}) do
      if R.Have(q) < (q.count or 1) then
        out[#out + 1] = q
      end
    end
    return out
  end

  function R.Charge(item, n)
    n = num(n)
    if n <= 0 then
      return true
    end
    if R.Items(item) < n then
      return false
    end
    return call(R.C.DEL_ITEM, item, n) ~= false
  end

  function R.Give(item, n)
    n = num(n)
    if n <= 0 then
      return true
    end
    if call(R.C.ITEM_FITS, item, n) == false then
      return false
    end
    call(R.C.ADD_ITEM, item, n)
    return true
  end

  function R.CanSign(param)
    if R.Owned(param) > 0 then
      return false, "owned"
    end
    local free = call(R.C.BANK_FREE)
    if type(free) == "number" and free < 1 then
      return false, "bank_full"
    end
    return true
  end

  function R.Sign(param, level, rarity, source)
    local ok, why = R.CanSign(param)
    if not ok then
      return nil, why
    end
    level = math.max(1, num(level))
    rarity = rarity or R.RARITY
    local hdl = call(R.C.ADD_PARTY, param, level, false, false, 0, 0, false, false, false, R.TEAM_SET_BANK, 255, 255,
      rarity, true, true, false, source or R.SOURCE, false, false, 0)
    call(R.C.AFTER_ADD)
    if R.Owned(param) <= 0 then
      R.Log("sign failed", param, level, rarity)
      return nil, "refused"
    end
    R.Log("signed", param, "level", level, "rarity", rarity, hdl)
    R.Refresh()
    R.ClearSeason(param, hdl)
    return hdl or 0
  end

  -- A signing is a normal club player: CMND_ADD_PARTY leaves the season bit on the new record (the bank's «Jugador de
  -- temporada» banner and plate), so it is cleared on the new handle (or, when the call gave none, on the club
  -- players of that card: it was not in the club before the signing).
  function R.ClearSeason(param, hdl)
    local handles = {}
    if type(hdl) == "number" and hdl ~= 0 then
      handles[1] = hdl
    else
      for _, h in ipairs(R.Holders({param})) do
        handles[#handles + 1] = h.handle
      end
    end
    for _, h in ipairs(handles) do
      if call(R.C.HAS_ATTRIBUTE, h, R.ATTRIBUTE_SEASON) == true then
        call(R.C.SET_ATTRIBUTE, h, R.ATTRIBUTE_SEASON, false)
        R.Log("season bit cleared", param, h, "still set", call(R.C.HAS_ATTRIBUTE, h, R.ATTRIBUTE_SEASON) == true)
      end
    end
  end

  -- one recruit with its rules: opt = {param, level, rarity, source, reqs = {...}, price = {item, count}}
  -- order: already owned / bank -> requirements -> the price (taken) -> sign (the price back if signing failed) ->
  -- autosave. Returns true, or false + why ("owned", "bank_full", "requirements", "price", "refused").
  function R.Recruit(opt)
    local ok, why = R.CanSign(opt.param)
    if not ok then
      return false, why
    end
    if #R.Missing(opt.reqs) > 0 then
      return false, "requirements"
    end
    local price = opt.price
    if not R.Pay(price) then
      return false, "price"
    end
    local hdl, err = R.Sign(opt.param, opt.level, opt.rarity, opt.source)
    if hdl == nil then
      R.Refund(price)
      return false, err
    end
    call(R.C.AUTO_SAVE)
    return true
  end

  -- the bank's own retire of the first club player of `cards` that no miximax fusion holds (the retail «Despedir»:
  -- the player leaves the club and every team); the card the retire may hand out is taken back and `refund` (a price
  -- table) given. Returns true, or false + why ("none", "busy", "refused").
  function R.Release(cards, refund_price)
    R.holders = {}
    local h = nil
    local busy = false
    for _, x in ipairs(R.Holders(cards)) do
      if x.busy then
        busy = true
      elseif h == nil then
        h = x
      end
    end
    if h == nil then
      return false, busy and "busy" or "none"
    end
    local rarity = num(call(R.C.STATUS, h.handle, 12))
    local before = spirit_num(h.param, rarity)
    local owned = R.Owned(h.param)
    local ok, done = pcall(funcLuaMenuCommand, R.C.RETIRE, h.handle)
    R.Log("release", h.param, h.handle, tostring(ok), tostring(done))
    R.Refresh()
    if R.Owned(h.param) >= owned then
      return false, "refused"                              -- the bank refused (e.g. he is in a team dock)
    end
    local now = spirit_num(h.param, rarity)
    if now == before + 1 then
      call(R.C.ADD_SPIRIT, h.param, -1, rarity, true)     -- the retire's card back: one card per character
    end
    R.Refund(refund_price)
    call(R.C.AUTO_SAVE)
    return true
  end
end

-- A recruit trial (a contact map's team page, «Prueba»): the friendly `friendly` against the team of the page's match
-- `game` at `difficulty`, with the challenge objective and the per-card «passed» key tag / sub, started from THIS menu
-- through the match start service (VRFW_MATCH, _all\12_match_start.lua). The rival is the page match's own rival team
-- (teams.rival.team, so a friendly that plays its own match row, e.g. a 5v5 row, meets the page's team) and the stadium
-- the page match's own one (game data, CMND_VRFW_RECRUIT_GAME_STADIUM); a home stadium declared for the rival team
-- comes first when the friendly asks rival_home. The team: the active pachanga team; none set, the active match team's
-- five with `friendly_team` (the contact set's TrialFriendlyActiveTeam: the same friendly with team = "current";
-- VRFW_MATCH.pachanga_team). The contact map screen calls it in its hub's VM (CMND MENU_CALL) and closes itself.
-- Returns true when the launch runs.
if VRFW_RecruitTrial == nil then
  local GAME_RIVAL = 2204933160      -- (game, difficulty) -> the match row's rival team
  local GAME_STADIUM = VRFW_Cmd.VRFW_RECRUIT_GAME_STADIUM     -- (game) -> map crc (0 = none)

  function VRFW_RecruitTrial(friendly, game, difficulty, tag, sub, objective, friendly_team)
    if type(VRFW_MATCH) ~= "table" or type(VRFW_MATCH.start) ~= "function" or type(friendly) ~= "string" then
      return false
    end
    difficulty = difficulty or 1
    local okr, rival = pcall(funcLuaCommand, GAME_RIVAL, game, difficulty)
    rival = (okr and type(rival) == "number" and rival ~= 0) and rival or nil
    local oks, stadium = pcall(funcLuaCommand, GAME_STADIUM, game)
    stadium = (oks and type(stadium) == "number" and stadium ~= 0) and stadium or nil
    local ok, started, why = pcall(VRFW_MATCH.start, {friendly = friendly, game = game, difficulty = difficulty,
      tag = tag, sub = sub, objective = objective, rival = rival, stadium = stadium,
      set = function() return VRFW_MATCH.pachanga_team(friendly_team) end,
      overrides = rival and {{"teams.rival.team", rival}} or nil, settle = 20, black = false})
    if VRFW_Recruit ~= nil then
      VRFW_Recruit.Log("trial start", friendly, game, difficulty, tag, sub, objective, "rival", tostring(rival),
        "stadium", tostring(stadium), tostring(ok), tostring(started), tostring(why))
    end
    return ok and started == true
  end
end
