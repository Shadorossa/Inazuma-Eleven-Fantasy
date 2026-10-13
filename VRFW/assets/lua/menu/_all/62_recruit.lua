-- menu_engine: the RECRUIT service (VR-Framework 2.1; docs/framework/recruit.md). Definitions only: this file runs in
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
--
-- A requirement (kept, never taken): {kind = "player", ids = {card, ...}, count = n} (n copies among those cards in the
-- club), {kind = "item", id = item, count = n} (have at least n), {kind = "team_level", count = n} (the active team's
-- level >= n: the team dock in use, CMND_GET_TEAM_SET_INFO(dock, 0, 1)), {kind = "element", element = e, count = n}
-- (n players of element e in the club: 1 wind, 2 forest, 3 fire, 4 mountain, 5 void), {kind = "position", position = p,
-- count = n} (n players of main position p in the club: 1 GK, 2 FW, 3 MF, 4 DF), {kind = "wins", count = n} (matches won
-- in this save slot), {kind = "goals", count = n} (goals scored). The club counts come from the framework's script
-- (CMND_VRFW_RECRUIT_CLUB, scripts\recruit.lua), cached until VRFW_Recruit.Refresh(); the career counters are the
-- save service's keys stats.matches_won / stats.goals (owner vr_framework, the same script counts them).
--
-- The add-character path (docs/framework/recruit.md §1; D:\re: the CMND_ADD_PARTY handler 0xC57140 -> 0xEA4920): the
-- retail summon screen's AddSummonChara call (20 arguments: card, level, ..., team set 16 = the normal bank, rarity,
-- ..., source), then 0xB349C762 as AddSummonChara does, then CMND_SYSTEM_AUTO_SAVE. Safe in the menus of a loaded save
-- (the office, the Mercado); never in free walk (the autosave is blocked there).
if VRFW_Recruit == nil then
  local R = {
    C = {
      ADD_PARTY = 1885323816,        -- CMND_ADD_PARTY 0x705FC228
      AFTER_ADD = 3007956834,        -- 0xB349C762: retail AddSummonChara calls it right after CMND_ADD_PARTY
      AUTO_SAVE = 3673719958,        -- CMND_SYSTEM_AUTO_SAVE
      OWNED = 1052152255,            -- (card, 0) -> ok, n / n: copies of the card in the club
      BANK_FREE = 1333628693,        -- CMND_CAN_SPIRIT_NUM -> free bank slots
      ITEM_NUM = 2011560392,         -- CMND_GET_ITEM_NUM (id, false) -> count
      DEL_ITEM = 425598937,          -- CMND_DELETE_ITEM (id, n) -> ok (never below the equipped count)
      ITEM_FITS = 765340069,         -- (id, n) -> the bag has room
      ADD_ITEM = 1897915498,         -- CMND_ADD_ITEM_ONLY (id, n): no window
      LOG = 3661580131,              -- CMND_EVT_LOG
      CLUB = 3686368570,             -- CMND_VRFW_RECRUIT_CLUB () -> {total, element = {..}, position = {..}}
      SAVE_GET = 2187277743,         -- CMND_VRFW_SAVE_GET (owner, key, default)
      IN_STORY = 424926145,          -- true while the story's play mode runs (menu_def GetActiveTeamDockNoByMode)
      STORY_DOCK = 2787124386,       -- the story's team dock in use
      VS_DOCK = 3713813716,          -- CMND_GET_VS_USE_TEAM_SET: the team dock in use outside the story
      TEAM_SET_INFO = 1033065575,    -- CMND_GET_TEAM_SET_INFO (dock, 0, 1) -> ok, team level
    },
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
    R.Log("signed", param, "level", level, "rarity", rarity, "handle", hdl)
    R.Refresh()
    return hdl or 0
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
    if price ~= nil and (price.count or 0) > 0 and not R.Charge(price.item, price.count) then
      return false, "price"
    end
    local hdl, err = R.Sign(opt.param, opt.level, opt.rarity, opt.source)
    if hdl == nil then
      if price ~= nil and (price.count or 0) > 0 then
        R.Give(price.item, price.count)
      end
      return false, err
    end
    call(R.C.AUTO_SAVE)
    return true
  end
end
