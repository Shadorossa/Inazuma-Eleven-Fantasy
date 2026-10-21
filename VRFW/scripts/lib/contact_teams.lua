-- Team pages of a contact set, derived from the game's own data (mods' tables included): no team, player or price is
-- written in code. Used by scripts\contact_map.lua for a [[VRFW.ContactMap]] that has a [VRFW.ContactMap.Teams] table.
--   Teams.build(set, decls, ctx) -> { map, ... }  maps in the form contact_map.lua serves (kind "list": a zone per team)
-- Sources (the map's Teams.Source):
--   "chronicle_routes"  one map per route of the Chronicle board (chronicle_vs_route_config, in table order): the games
--                       of its pieces' events; the map's name is the series most of its players come from
--   "free_match"        the «Competir contra bots» games (soccer_opponent_info, in its order) that are on no route
-- A page (zone) = one opponent team (SOCCER_GAME_DIFFICULTY opponent_team of every difficulty row of those games);
-- teams with the same name text are one page (the first place) when MergeSameName is on. A player = a team member
-- (team_config); his node sells the card that plays for that team, on his home page (a term's Page, else a page of one of
-- his own teams, else his first page). Rules of the set ([VRFW.ContactSet.Teams]) decide staff, one page per character
-- and the price tiers; a card's terms ([[VRFW.ContactTerms]]) replace its level, price and requirements.

local M = {}

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local function scalar(v)
  if type(v) == "table" then return v[1] end
  return v
end

local function slice(v)
  if type(v) ~= "table" then return nil end
  if v.start == nil and v.offset == nil and type(v[1]) == "table" then v = v[1] end   -- a field of length 1: { slice }
  local s, n = tonumber(v.start or v.offset or v[1]), tonumber(v.count or v[2])
  if s == nil or n == nil then return nil end
  return s, n
end

-- 1-based position of a column of table `id` (schema name), nil when absent
local function pos_of(id, name)
  local ok, cols = pcall(VRFW.table.columns, id)
  if not ok or type(cols) ~= "table" then return nil end
  for i, c in ipairs(cols) do
    if c == name then return i end
  end
  return nil
end

local function rows(id)
  local ok, r = pcall(VRFW.table.rows, id)
  if ok and type(r) == "table" then return r end
  return nil, tostring(r)
end

-- ---------------------------------------------------------------------------------------------------- game data

local G = nil   -- the tables, read once per session

local function read_games(warn)
  local games, order = {}, {}   -- game id -> { {difficulty, team, level}, ... }; ids in file order
  local ok, err = pcall(function()
    local key = VRFW.table.source("soccer/soccer_game_info")
    local cur, slices, diffs = nil, {}, {}
    for _, e in ipairs(VRFW.table.entries(key, { "SOCCER_GAME_INFO", "SOCCER_GAME_INFO_REF_DIFFICULTY",
      "SOCCER_GAME_DIFFICULTY" }, true)) do
      if e.name == "SOCCER_GAME_INFO" then
        cur = u32(e[1])
        order[#order + 1] = cur
      elseif e.name == "SOCCER_GAME_INFO_REF_DIFFICULTY" then
        if cur then slices[cur] = { tonumber(e[1]) or 0, tonumber(e[2]) or 0 } end
      elseif e.name == "SOCCER_GAME_DIFFICULTY" then
        diffs[#diffs + 1] = { tonumber(e[1]) or 0, u32(e[2]), tonumber(e[3]) or 0 }
      end
    end
    for _, g in ipairs(order) do
      local sl = slices[g]
      local list = {}
      if sl then
        for k = sl[1] + 1, sl[1] + sl[2] do
          if diffs[k] then list[#list + 1] = diffs[k] end
        end
      end
      games[g] = list
    end
  end)
  if not ok then warn("soccer_game_config not readable (" .. tostring(err) .. "): no team page") end
  return games, order
end

local function read_teams(warn)
  local teams = {}   -- team id -> { name_text, level, members = { {card, slot, captain}, ... } }
  local ok, err = pcall(function()
    local key = VRFW.table.source("team/team")
    local p_id, p_name, p_level = pos_of("team/team", "id") or 1, pos_of("team/team", "name_text") or 4,
      pos_of("team/team", "level") or 9
    local p_card, p_slot, p_capt = pos_of("team/team_member", "chara_param") or 1, pos_of("team/team_member", "slot") or 9,
      pos_of("team/team_member", "captain") or 12
    local info = VRFW.table.raw(key, "SOCCER_TEAM_INFO", { p_id, p_name, p_level })
    local refs = VRFW.table.raw(key, "SOCCER_TEAM_INFO_REF_MEMBER", { 1, 2 })
    local members = VRFW.table.raw(key, "SOCCER_TEAM_MEMBER", { p_card, p_slot, p_capt })
    if type(info) ~= "table" or type(refs) ~= "table" or type(members) ~= "table" or #refs ~= #info then
      error("team_config rows / member refs do not match")
    end
    for i, t in ipairs(info) do
      local id = u32(scalar(t[p_id]))
      if id ~= 0 and teams[id] == nil then
        local list = {}
        local a, n = tonumber(scalar(refs[i][1])), tonumber(scalar(refs[i][2]))
        if a and n then
          for k = a + 1, a + n do
            local m = members[k]
            if m then
              list[#list + 1] = { card = u32(scalar(m[p_card])), slot = tonumber(scalar(m[p_slot])) or 0,
                captain = (tonumber(scalar(m[p_capt])) or 0) ~= 0 }
            end
          end
        end
        teams[id] = { name_text = u32(scalar(t[p_name])), level = tonumber(scalar(t[p_level])) or 0, members = list }
      end
    end
  end)
  if not ok then warn("team_config not readable (" .. tostring(err) .. "): no team page") end
  return teams
end

-- the Chronicle board's routes: { { games = {g, ...} }, ... } in table order
local function read_routes(warn)
  local out = {}
  local r, e1 = rows("vsroute/vs_route")
  local p, e2 = rows("vsroute/vs_route_piece")
  local ev, e3 = rows("vsroute/vs_route_piece_event")
  if not r or not p or not ev then
    warn("Chronicle board not readable (" .. tostring(e1 or e2 or e3) .. "): no route page")
    return out
  end
  for _, route in ipairs(r) do
    local games, seen = {}, {}
    local s, n = slice(route.pieceInfo or route[3])
    if s then
      for i = s, s + n - 1 do
        local piece = p[i + 1]
        local es, en = slice(piece and (piece.eventInfoRef or piece[24]))
        if es then
          for j = es, es + en - 1 do
            local e = ev[j + 1]
            local g = e and u32(scalar(e.paramCrc1 or e[1])) or 0
            if g ~= 0 and not seen[g] then
              seen[g] = true
              games[#games + 1] = g
            end
          end
        end
      end
    end
    out[#out + 1] = { games = games }
  end
  return out
end

-- the «Competir contra bots» games of category 0 (no route tab), in the table's order
local function read_free_match(warn)
  local list = {}
  local r, e = rows("soccer/soccer_opponent_info")
  if not r then
    warn("soccer_opponent_info not readable (" .. tostring(e) .. "): no free-match page")
    return list
  end
  local seen = {}
  for i, row in ipairs(r) do
    local cat = tonumber(scalar(row.category or row[1])) or 0
    local g = u32(scalar(row.battleId or row[2]))
    if cat == 0 and g ~= 0 and not seen[g] then
      seen[g] = true
      list[#list + 1] = { g = g, sort = tonumber(scalar(row.sortOrder or row[3])) or 0, i = i }
    end
  end
  table.sort(list, function(a, b) if a.sort ~= b.sort then return a.sort < b.sort end return a.i < b.i end)
  local out = {}
  for k, x in ipairs(list) do out[k] = x.g end
  return out
end

-- series type -> the first chara_series_id of that type
local function read_series()
  local out = {}
  local r = rows("character/chara_series")
  for _, row in ipairs(r or {}) do
    local id, ty = u32(scalar(row.chara_series_id or row[1])), tonumber(scalar(row.chara_series_type or row[2])) or 0
    if id ~= 0 and ty ~= 0 and out[ty] == nil then out[ty] = id end
  end
  return out
end

-- every card: card -> { base, rarity, coach, manager, element }; base -> its cards; base -> has a special card
local function read_cards()
  local card, of_base, special = {}, {}, {}
  local ok, all = pcall(VRFW.chara.cards)
  if ok and type(all) == "table" then
    for _, c in ipairs(all) do
      local id, b = u32(c.id), u32(c.base)
      if id ~= 0 and card[id] == nil then
        card[id] = { base = b, rarity = tonumber(c.rarity) or 0, staff = c.coach == true or c.manager == true,
          element = tonumber(c.element) or 0, position = tonumber(c.position) or 0 }
        if b ~= 0 then
          of_base[b] = of_base[b] or {}
          table.insert(of_base[b], id)
          local r = tonumber(c.rarity) or 0
          if r >= 5 and r <= 8 then special[b] = true end
        end
      end
    end
  end
  return card, of_base, special
end

-- pieceId -> statusFlagIndex of the Chronicle board (a Chronicle clear check of the menus asks the index)
local function read_piece_flags()
  local out = {}
  for _, p in ipairs(rows("vsroute/vs_route_piece") or {}) do
    local id, sfi = u32(scalar(p.pieceId or p[2])), tonumber(scalar(p.statusFlagIndex or p[4])) or 0
    if id ~= 0 and sfi > 0 and out[id] == nil then out[id] = sfi end
  end
  return out
end

-- belong team id -> its name text (a character's own teams, chara_base team_1..3)
local function read_belong()
  local out = {}
  for _, r in ipairs(rows("character/belong_team") or {}) do
    local id = u32(scalar(r.belong_team_id or r[1]))
    if id ~= 0 then out[id] = u32(scalar(r.team_name_text_id or r[3])) end
  end
  return out
end

local function data(warn)
  if G ~= nil then return G end
  local t0 = VRFW.now()
  G = {}
  G.games = read_games(warn)
  G.teams = read_teams(warn)
  G.routes = read_routes(warn)
  G.free = read_free_match(warn)
  G.series = read_series()
  G.card, G.of_base, G.special = read_cards()
  G.piece_flag = read_piece_flags()
  G.belong = read_belong()
  VRFW.log(string.format("contact_map: team pages: game data read in %d ms (%d routes)", math.floor(VRFW.now() - t0),
    #G.routes))
  return G
end

-- ---------------------------------------------------------------------------------------------------- rules

-- the set's [VRFW.ContactSet.Teams]: staff, one page per character, merged names, price tiers
local function rules_of(set, warn)
  local t = type(set.teams) == "table" and set.teams or {}
  local R = { staff = t.Staff == true, one_page = t.OnePagePerCharacter ~= false, merge = t.MergeSameName ~= false,
    max_level = tonumber(t.MaxLevel) or 0, tiers = {} }
  for k, p in ipairs(type(t.Price) == "table" and t.Price or {}) do
    if type(p) == "table" then
      R.tiers[#R.tiers + 1] = { name = tostring(p.Tier or ("#" .. k)), special = p.Special == true,
        captain = p.Captain == true, min_teams = tonumber(p.MinTeams) or 0, base = math.max(0, tonumber(p.Base) or 0),
        per_level = math.max(0, tonumber(p.PerLevel) or 0) }
    else
      warn(set.where .. ": [[VRFW.ContactSet.Teams.Price]] #" .. k .. " is not a table (left out)")
    end
  end
  return R
end

-- the price of a player: the first tier whose conditions hold (no tier: 0)
local function price_of(R, x, level)
  for _, t in ipairs(R.tiers) do
    local ok = true
    if t.special and not x.special then ok = false end
    if t.captain and not x.captain then ok = false end
    if t.min_teams > 0 and x.teams < t.min_teams then ok = false end
    if ok then return math.floor(t.base + level * t.per_level + 0.5), t.name end
  end
  return 0, "none"
end

-- ---------------------------------------------------------------------------------------------------- terms

-- [[VRFW.ContactTerms]] / [[VRFW.ContactTrials]] of the set (contact_map.lua collects them): card -> term, id -> trial
local function term_reqs(D, set, card, term, trials, warn)
  local out = {}
  for k, r in ipairs(type(term.Requires) == "table" and term.Requires or {}) do
    if type(r.Players) == "table" then
      local ids = {}
      for _, c in ipairs(r.Players) do ids[#ids + 1] = u32(c) end
      if #ids > 0 then
        out[#out + 1] = { kind = "player", ids = ids, count = math.max(1, tonumber(r.Count) or 1),
          level = math.max(0, tonumber(r.Level) or 0) }
      end
    elseif r.Item ~= nil then
      out[#out + 1] = { kind = "item", id = u32(r.Item), count = math.max(1, tonumber(r.Count) or 1) }
    elseif r.Trial ~= nil then
      local t = trials[math.floor(tonumber(r.Trial) or -1)]
      if t ~= nil and set.trial_friendly ~= nil then
        local diff = nil
        for _, d in ipairs(D.games[t.game] or {}) do
          if diff == nil or d[1] < diff then diff = d[1] end
        end
        out[#out + 1] = { kind = "trial", friendly = set.trial_friendly, tag = card, sub = t.id, game = t.game,
          difficulty = diff or 1, objective = t.objective, part = t.part, of = t.of, count = 1 }
      else
        warn(string.format("%s: terms of 0x%08X: requirement %d: trial %s unknown or no TrialFriendly (left out)",
          set.where, card, k, tostring(r.Trial)))
      end
    end
  end
  return out
end

-- a term's Unlock groups -> { {check, ...}, ... } (a Chronicle piece as its status flag index)
local function term_unlock(D, term)
  local groups = {}
  for _, g in ipairs(type(term.Unlock) == "table" and term.Unlock or {}) do
    local list = {}
    for _, c in ipairs(type(g) == "table" and g or {}) do
      if c.Game ~= nil then
        list[#list + 1] = { t = "game", a = u32(c.Game), b = tonumber(c.Difficulty) or 1 }
      elseif c.Chronicle ~= nil then
        list[#list + 1] = { t = "chronicle", a = D.piece_flag[u32(c.Chronicle)] or 0, b = tonumber(c.Difficulty) or 1 }
      elseif c.Flag ~= nil then
        list[#list + 1] = { t = "flag", a = u32(c.Flag) }
      end
    end
    if #list > 0 then groups[#groups + 1] = list end
  end
  return groups
end

-- ---------------------------------------------------------------------------------------------------- pages

-- the pages of a list of games: { {team, teams, name_text, level, clears = {g, d, ...}, games = {[g] = true}}, ... }
local function pages_of(D, games, R, pages, by_team, by_name)
  pages, by_team, by_name = pages or {}, by_team or {}, by_name or {}
  for _, g in ipairs(games) do
    for _, d in ipairs(D.games[g] or {}) do
      local team = D.teams[d[2]]
      if team ~= nil and #team.members > 0 then
        local pg = by_team[d[2]]
        if pg == nil and R.merge and team.name_text ~= 0 then pg = by_name[team.name_text] end
        if pg == nil then
          pg = { team = d[2], teams = {}, name_text = team.name_text, level = 0, clears = {}, seen = {}, games = {} }
          pages[#pages + 1] = pg
          if team.name_text ~= 0 then by_name[team.name_text] = pg end
        end
        by_team[d[2]] = pg
        pg.games[g] = true
        if not pg.teams[d[2]] then
          pg.teams[d[2]] = true
          pg.teams[#pg.teams + 1] = d[2]
        end
        local key = g .. ":" .. d[1]
        if not pg.seen[key] then
          pg.seen[key] = true
          pg.clears[#pg.clears + 1] = g
          pg.clears[#pg.clears + 1] = d[1]
        end
        local lv = team.level > 0 and team.level or d[3]
        if lv > 0 and (pg.level == 0 or lv < pg.level) then pg.level = lv end
      end
    end
  end
  return pages, by_team, by_name
end

-- Pitch places of a page: its first team's starters (slots 0-10) in rows by their card's main position (GK at the
-- bottom, then DF, MF, FW), each row spread evenly, in slot order; px, py in 0..1 (y down). Others: the bench.
local ROW_Y = { [1] = 0.92, [4] = 0.70, [3] = 0.45, [2] = 0.18 }   -- GK, DF, MF, FW
local function pitch_of(D, pg)
  local team = D.teams[pg.team]
  local rows, at = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }, {}
  for _, mb in ipairs(team and team.members or {}) do
    if mb.slot >= 0 and mb.slot <= 10 then
      local c = D.card[mb.card]
      local p = c and c.position or 0
      if mb.slot == 0 and p ~= 1 then p = 1 end
      if rows[p] == nil then p = 3 end
      table.insert(rows[p], mb)
    end
  end
  for p, list in pairs(rows) do
    table.sort(list, function(a, b) return a.slot < b.slot end)
    for k, mb in ipairs(list) do
      at[mb.card] = { x = k / (#list + 1), y = ROW_Y[p], slot = mb.slot }
    end
  end
  return at
end

-- the page a character is sold on: a term's Page (the old office's), else a page of one of his own teams
-- (chara_base team_1..3 named like the page), else his first page
local function home_pages(D, maps, ctx, terms)
  local all, by_game = {}, {}
  for _, mp in ipairs(maps) do
    for _, pg in ipairs(mp.pages) do
      all[#all + 1] = pg
      for g in pairs(pg.games) do by_game[g] = by_game[g] or pg end
    end
  end
  local first, first_staff, own = {}, {}, {}
  local function own_names(b)
    if own[b] == nil then
      local names = {}
      local ok, ch = pcall(VRFW.chara.character, b)
      if ok and type(ch) == "table" and type(ch.teams) == "table" then
        for _, t in ipairs(ch.teams) do
          local nt = D.belong[u32(t)]
          if nt and nt ~= 0 then
            names[nt] = true
            local s = ctx.team_name(nt)
            if s ~= "" then names[s] = true end
          end
        end
      end
      own[b] = names
    end
    return own[b]
  end
  local home = {}
  for _, pg in ipairs(all) do
    local name = pg.name_text ~= 0 and ctx.team_name(pg.name_text) or ""
    for _, t in ipairs(pg.teams) do
      for _, mb in ipairs(D.teams[t].members) do
        local c = D.card[mb.card]
        if c and c.base ~= 0 and (mb.slot >= 19 or c.staff) then
          first_staff[c.base] = first_staff[c.base] or pg
        elseif c and c.base ~= 0 then
          local b = c.base
          first[b] = first[b] or pg
          if home[b] == nil then
            local term = terms[mb.card]
            if term ~= nil and type(term.Page) == "table" then
              for _, g in ipairs(term.Page) do
                local p = by_game[u32(g)]
                if p ~= nil then
                  home[b] = p
                  break
                end
              end
            end
          end
          if home[b] == nil then
            local names = own_names(b)
            if names[pg.name_text] or (name ~= "" and names[name]) then home[b] = pg end
          end
        end
      end
    end
  end
  for b, pg in pairs(first) do
    if home[b] == nil then home[b] = pg end
  end
  for b, pg in pairs(first_staff) do
    if home[b] == nil then home[b] = pg end      -- only ever a manager / coach: his first page
  end
  return home
end

-- Builds the derived maps of one set. decls: { {m = declaration, mod, where, key}, ... } (maps with a Teams table);
-- ctx: { warn, info, crc, own_face(card, base) -> false without a face of his own, team_name(text id) -> name }
function M.build(set, decls, ctx)
  local warn = ctx.warn
  local D = data(warn)
  local R = rules_of(set, warn)
  local terms, trials = set.terms or {}, set.trials or {}
  table.sort(decls, function(a, b)
    local oa, ob = tonumber(a.m.Order) or 0, tonumber(b.m.Order) or 0
    if oa ~= ob then return oa < ob end
    return a.key < b.key
  end)
  -- 1. the maps and their pages, in the set's order
  local maps, free_map = {}, nil
  for _, d in ipairs(decls) do
    local T = d.m.Teams
    local src = tostring(T.Source or "")
    if src == "chronicle_routes" then
      local only = nil
      if type(T.Routes) == "table" then
        only = {}
        for _, x in ipairs(T.Routes) do only[math.floor(tonumber(x) or -1)] = true end
      end
      for k, route in ipairs(D.routes) do
        if (only == nil or only[k - 1]) and #route.games > 0 then
          maps[#maps + 1] = { d = d, key = string.format("%s.%02d", d.key, k - 1), route = k - 1,
            pages = pages_of(D, route.games, R) }
        end
      end
    elseif src == "free_match" then
      local on_route = {}
      for _, route in ipairs(D.routes) do
        for _, g in ipairs(route.games) do on_route[g] = true end
      end
      local games = {}
      for _, g in ipairs(D.free) do
        if not on_route[g] then games[#games + 1] = g end
      end
      local mp = { d = d, key = d.key }
      mp.pages, mp.by_team, mp.by_name = pages_of(D, games, R)
      maps[#maps + 1] = mp
      free_map = free_map or mp
    else
      warn(d.where .. ": Teams.Source " .. src .. " (chronicle_routes, free_match): map left out")
    end
  end
  -- 1b. a term's page whose games are on no map (e.g. a legend match): a page of the first free_match map
  if free_map ~= nil then
    local known = {}
    for _, mp in ipairs(maps) do
      for _, pg in ipairs(mp.pages) do
        for g in pairs(pg.games) do known[g] = true end
      end
    end
    local extra, seen = {}, {}
    for _, term in pairs(terms) do
      if type(term.Page) == "table" then
        local placed_any = false
        for _, g in ipairs(term.Page) do
          if known[u32(g)] then placed_any = true end
        end
        if not placed_any then
          for _, g in ipairs(term.Page) do
            g = u32(g)
            if D.games[g] ~= nil and not seen[g] then
              seen[g] = true
              extra[#extra + 1] = g
            end
          end
        end
      end
    end
    table.sort(extra)
    if #extra > 0 then
      pages_of(D, extra, R, free_map.pages, free_map.by_team, free_map.by_name)
    end
  end
  -- 2. every character's pages (for «plays in N teams» and the unlock of his node), his home page
  local char_pages, char_clears = {}, {}
  for _, mp in ipairs(maps) do
    for _, pg in ipairs(mp.pages) do
      for _, t in ipairs(pg.teams) do
        for _, mb in ipairs(D.teams[t].members) do
          local c = D.card[mb.card]
          if c and c.base ~= 0 then
            char_pages[c.base] = char_pages[c.base] or {}
            char_pages[c.base][pg] = true
          end
        end
      end
    end
  end
  local home = R.one_page and home_pages(D, maps, ctx, terms) or {}
  local function teams_of(b)
    local n = 0
    for _ in pairs(char_pages[b] or {}) do n = n + 1 end
    return n
  end
  local CLEAR_CAP = 48            -- pairs (game, difficulty) of one requirement
  local function clears_of(b)
    if char_clears[b] then return char_clears[b] end
    local out = {}
    for pg in pairs(char_pages[b] or {}) do
      for i = 1, #pg.clears, 2 do
        if #out < CLEAR_CAP then
          out[#out + 1] = pg.clears[i]
          out[#out + 1] = pg.clears[i + 1]
        end
      end
    end
    char_clears[b] = out
    return out
  end
  -- 3. the nodes: one per character on his home page, the card that plays for that team; the starters sold on
  -- another page stay on the pitch as «ghosts» (drawn, never signed here)
  local placed = {}
  local out, n_players, n_faceless, n_tiers, n_terms = {}, 0, 0, {}, 0
  for _, mp in ipairs(maps) do
    local d = mp.d
    local M2 = { key = mp.key, crc = ctx.crc(mp.key), set = set.key, order = tonumber(d.m.Order) or 0, kind = "list",
      title = ctx.crc(d.m.Title or mp.key), tex = d.m.Art or "", sprite = d.m.Sprite or "", strict = true, zones = {},
      zone_ix = {}, nodes = {}, items = {}, players = 0, series = 0, derived = true, pitch = true }
    local series_votes = {}
    for _, pg in ipairs(mp.pages) do
      local z = #M2.zones + 1
      local zone = { name = string.format("team_%08x", pg.team), title = 0, name_text = pg.name_text, x = -1, y = -1,
        count = 0, tex = "", sprite = "", aw = 0, ah = 0, games = pg.games, team = pg.team,
        reqs = { { kind = "cleared", games = pg.clears, count = 1, name_text = pg.name_text } } }
      local here, first = {}, #M2.nodes + 1
      local spots = pitch_of(D, pg)
      for _, t in ipairs(pg.teams) do
        for _, mb in ipairs(D.teams[t].members) do
          local c = D.card[mb.card]
          local staff = mb.slot >= 19 or (c and c.staff)
          local mine = c and c.base ~= 0 and (not R.one_page or home[c.base] == pg)
          if c and c.base ~= 0 and not here[c.base] and (R.staff or not staff) and mine
            and not (R.one_page and placed[c.base]) then
            here[c.base] = true
            local term = terms[mb.card]
            local level = pg.level > 0 and pg.level or 1
            if term ~= nil and tonumber(term.Level) then level = math.floor(tonumber(term.Level)) end
            if R.max_level > 0 and level > R.max_level then level = R.max_level end
            local price, tier, spirit, item = 0, "none", 0, set.rc or 0
            if term ~= nil and tonumber(term.Price) then
              price, tier = math.floor(tonumber(term.Price)), "terms"
              spirit = u32(term.Spirit or 0)
              n_terms = n_terms + 1
            else
              local x = { special = D.special[c.base] == true, captain = mb.captain, teams = teams_of(c.base) }
              price, tier = price_of(R, x, level)
              spirit = set.element_currency and set.element_currency[c.element] or 0
            end
            if spirit == 0 and item == 0 then price = 0 end     -- no currency for him: free
            local reqs = term ~= nil and term_reqs(D, set, mb.card, term, trials, warn) or {}
            local optional = {}
            if set.requirements == false then
              -- price only: the terms' requirements are kept in the data but not asked; a trial stays playable
              for _, r in ipairs(reqs) do
                if r.kind == "trial" then optional[#optional + 1] = r end
              end
              reqs = {}
            else
              reqs[#reqs + 1] = { kind = "cleared", games = clears_of(c.base), count = 1, name_text = pg.name_text }
              local groups = term ~= nil and term_unlock(D, term) or {}
              if #groups > 0 then
                reqs[#reqs + 1] = { kind = "unlock", groups = groups, count = 1, name_text = pg.name_text }
              end
            end
            local spot = spots[mb.card]
            local node = { kind = "player", zone = z, card = mb.card, base = c.base, face = "", level = level,
              price = price, spirit = spirit, item = item, x = 0, y = 0, links = {}, story = false, notes = {},
              cards = D.of_base[c.base] or { mb.card }, reqs = reqs, trials = optional, slot = mb.slot,
              element = c.element, position = c.position, main = t == pg.team,
              px = spot and spot.x or -1, py = spot and spot.y or -1 }
            if ctx.own_face(mb.card, c.base) == false then
              node.kind = "hidden"
              n_faceless = n_faceless + 1
            else
              placed[c.base] = true
              zone.count = zone.count + 1
              M2.players = M2.players + 1
              n_players = n_players + 1
              n_tiers[tier] = (n_tiers[tier] or 0) + 1
              local ok, ch = pcall(VRFW.chara.character, c.base)
              local st = ok and type(ch) == "table" and tonumber(ch.series) or 0
              if st > 0 then series_votes[st] = (series_votes[st] or 0) + 1 end
            end
            M2.nodes[#M2.nodes + 1] = node
          end
        end
      end
      -- the starters of the page's team not sold here: drawn at their places, never a target
      for card, spot in pairs(spots) do
        local c = D.card[card]
        if c and not here[c.base] and ctx.own_face(card, c.base) ~= false then
          M2.nodes[#M2.nodes + 1] = { kind = "ghost", zone = z, card = card, base = c.base, face = "", level = 0, main = true,
            price = 0, x = 0, y = 0, links = {}, story = false, notes = {}, reqs = {}, slot = spot.slot,
            px = spot.x, py = spot.y }
        end
      end
      if zone.count > 0 then
        M2.zones[z] = zone
        M2.zone_ix[zone.name] = z
      else
        for i = #M2.nodes, first, -1 do table.remove(M2.nodes, i) end
      end
    end
    if mp.route ~= nil then
      local best, votes = 0, 0
      for st, v in pairs(series_votes) do
        if v > votes or (v == votes and st < best) then best, votes = st, v end
      end
      M2.series = D.series[best] or 0
    end
    if #M2.zones > 0 then
      out[#out + 1] = M2
    end
  end
  local parts = {}
  for k, v in pairs(n_tiers) do parts[#parts + 1] = k .. " " .. v end
  table.sort(parts)
  ctx.info(string.format("set %s: team pages: %d maps, %d players (%s; %d with terms), %d without a face of their own "
    .. "left out", set.key, #out, n_players, table.concat(parts, ", "), n_terms, n_faceless))
  return out
end

return M
