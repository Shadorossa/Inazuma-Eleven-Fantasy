-- Career mode squads (docs/game/mods/career-mode-proposal.md §9): every player exists once in a career. A person (the
-- character's name, as VRFW synergies count people) shared by several clubs belongs to the earliest one: the
-- lowest key of content\career\club_order.toml (game, kind, story place, number; generated from game data by
-- research/scripts/career_club_order_build.py), then his roster slot, then the club key. A club keeps the players it
-- owns; it enters the career when it keeps config [squads] min_players. The roster rows its moved players leave, and
-- the places up to fill_to, are signed from the free players (no club of the career owns them; with free_need_team only
-- characters of some belong team, chara_base): the same main
-- position, the closest strength (chara_param column strength_column), the club's own game first; drawn once per
-- career from the career's seed. A merged club (content/career/clubs.toml: c.versions, other teams of the same
-- club) owns its versions' players too: each player belongs to the earliest version that has him; the club's rows are
-- its own team's, a row its moved player left takes a versions' player of that position first, the others are on the
-- bench (slot -1); its squad keeps every own player. Nothing here names a club or a player.
local M = {}

local floor = math.floor
local TWO32 = 4294967296
local NO_ORDER = { 99, 9, 999, 999, 99999 }

local function u32(n)
  n = floor(tonumber(n) or 0) % TWO32
  if n < 0 then n = n + TWO32 end
  return n
end

-- a squad cut to `most` players (config [squads] max_players): the players on a roster row (slot 0-18) stay, then the
-- bench by strength (strength(card), highest first; the squad's order on a tie) -> the players kept (in their order),
-- how many left
function M.trim(players, most, strength)
  if most <= 0 or #players <= most then return players, 0 end
  local order = {}
  for i, p in ipairs(players) do order[i] = { p = p, i = i, row = (p.slot or -1) >= 0, s = strength(p.card) } end
  table.sort(order, function(a, b)
    if a.row ~= b.row then return a.row end
    if a.s ~= b.s then return a.s > b.s end
    return a.i < b.i
  end)
  local keep = {}
  for k = 1, most do keep[order[k].i] = true end
  local out = {}
  for i, p in ipairs(players) do
    if keep[i] then out[#out + 1] = p end
  end
  return out, #players - #out
end

require "VRFW/lib/basics"
local info, warn = VRFW.logger("squads")
local GameText = require "VRFW/lib/game_text"

-- a < b for two keys of equal length (numbers or texts)
local function before(a, b)
  for i = 1, #a do
    if a[i] ~= b[i] then return a[i] < b[i] end
  end
  return false
end

-- club key -> { game, kind, place major, place minor, number } from the generated order file
local function club_order(path)
  local ok, doc = pcall(VRFW.files.toml, path)
  local out = {}
  local own = ok and type(doc) == "table" and doc.CareerMode or nil
  local list = type(own) == "table" and own.ClubOrder or nil
  if type(list) ~= "table" then
    warn("club order " .. path .. " not readable (" .. tostring(doc) .. "): every club ranks the same")
    return out
  end
  for _, o in ipairs(list) do
    local key = type(o) == "table" and o.key ~= nil and tostring(o.key) or nil
    if key ~= nil then
      local place = type(o.place) == "table" and o.place or {}
      out[key] = { tonumber(o.game) or 99, tonumber(o.kind) or 9, tonumber(place[1]) or 999, tonumber(place[2]) or 999,
        tonumber(o.number) or 99999 }
    end
  end
  return out
end

-- the language whose names tell people apart (one name, one person in every language)
local PERSON_LANGUAGE = "en"
local PERSONS = nil

-- character id -> person: the characters whose names read the same are one person (the game gives one person several
-- name texts across its games: by the text id alone he played for two clubs); the name text when the name cannot be
-- read, the character itself when it has none. Worked out once per script VM, the merges logged once.
local function persons()
  if PERSONS then return PERSONS end
  local ok, list = pcall(VRFW.chara.characters)
  list = ok and type(list) == "table" and list or {}
  local ids, seen = {}, {}
  for _, ch in ipairs(list) do
    local nt = u32(ch.name_text)
    if nt ~= 0 and not seen[nt] then
      seen[nt] = true
      ids[#ids + 1] = nt
    end
  end
  local okn, names = pcall(GameText.chara_names, ids, PERSON_LANGUAGE)
  if not (okn and type(names) == "table") then
    warn("character names not readable (" .. tostring(names) .. "): people told apart by their name text only")
    names = {}
  end
  local out, by_name, merged = {}, {}, 0
  for _, ch in ipairs(list) do
    local nt = u32(ch.name_text)
    local who = nt ~= 0 and nt or u32(ch.id)
    local name = nt ~= 0 and names[nt] or ""
    if name ~= "" then
      if by_name[name] == nil then
        by_name[name] = who
      elseif by_name[name] ~= who then
        merged = merged + 1
        who = by_name[name]
      end
    end
    out[u32(ch.id)] = who
  end
  info(string.format("persons: %d characters, %d name text(s) joined to a person of the same name", #list, merged))
  PERSONS = out
  return out
end

-- Two rosters ({ { card } }) -> the share (0..1) of the smaller one's persons the other has too (one person with
-- several cards counts once); 0 when either has none. The one rule that tells a team's versions (they share players)
-- from another team of the same name (another era: other characters)
function M.overlap(a, b)
  local person_of = persons()
  local function set(list)
    local s, n = {}, 0
    for _, p in ipairs(list or {}) do
      local ok, base = pcall(VRFW.chara.base_of, p.card)
      local who = ok and type(base) == "number" and person_of[u32(base)] or 0
      if who ~= 0 and not s[who] then s[who], n = true, n + 1 end
    end
    return s, n
  end
  local sa, na = set(a)
  local sb, nb = set(b)
  if na == 0 or nb == 0 then return 0 end
  local small, other, n = sa, sb, na
  if nb < na then small, other, n = sb, sa, nb end
  local shared = 0
  for who in pairs(small) do
    if other[who] then shared = shared + 1 end
  end
  return shared / n
end

-- The cards no career has (cfg.exclude_no_face, cfg.exclude_aura_types, cfg.exclude_staff: the cards of characters
-- with a coach or manager card) -> set [card] = "face" | "aura" | "staff", worked
-- out once per script VM from the game data (the character index, the face icons through VRFW/lib/faces, the served
-- aura_skill_config);
-- the count of each rule logged once. A character whose face cannot be told (no file service) is kept.
local Faces = require "VRFW/lib/faces"
local EXCLUDED = nil
function M.excluded(cfg)
  if EXCLUDED ~= nil then return EXCLUDED end
  local out, faces, aura = {}, 0, 0
  local types = type(cfg.exclude_aura_types) == "table" and cfg.exclude_aura_types or {}
  if #types > 0 then
    local ok, list = pcall(VRFW.chara.select, { aura_variant = { aura_type = types } })
    if ok and type(list) == "table" then
      for _, card in ipairs(list) do
        if out[u32(card)] == nil then out[u32(card)], aura = "aura", aura + 1 end
      end
    else
      warn("aura variant cards not readable (" .. tostring(list) .. "): none left out")
    end
  end
  local staff = 0
  if cfg.exclude_staff then
    -- every card of a character that has a coach or a manager card (staff only, no player)
    local okc, list = pcall(VRFW.chara.cards)
    list = okc and type(list) == "table" and list or {}
    local bases = {}
    for _, k in ipairs(list) do
      if k.coach or k.manager then bases[u32(k.base)] = true end
    end
    for _, k in ipairs(list) do
      if bases[u32(k.base)] and out[u32(k.id)] == nil then out[u32(k.id)], staff = "staff", staff + 1 end
    end
  end
  if cfg.exclude_no_face then
    local okc, list = pcall(VRFW.chara.cards)
    for _, k in ipairs(okc and type(list) == "table" and list or {}) do
      local pos = floor(tonumber(k.position) or 0)
      if pos >= 1 and pos <= 4 and not k.coach and not k.manager and out[u32(k.id)] == nil
          and Faces.of_character(k.base) == false then
        out[u32(k.id)], faces = "face", faces + 1
      end
    end
  end
  info(string.format("cards no career has: %d without a face of their own, %d aura variant cards (types %s), %d of staff",
    faces, aura, table.concat(types, ", "), staff))
  EXCLUDED = out
  return out
end

-- clubs = Teams.load()'s list, seed = the career's seed, cfg = config [squads] ->
-- { clubs = { kept club ids in list order }, squads = { [club id] = { players = { { card, slot, number, signed } },
--   rows = { slot, card, … } } }, dropped, signed } ; signed players have signed = true, slot -1 when no row is free
function M.build(clubs, seed, cfg)
  local order = club_order(cfg.order_file)
  local person_of = persons()
  local excluded = M.excluded(cfg)
  local cards = {}
  local okc, list = pcall(VRFW.chara.cards, { columns = { cfg.strength_column }, character = true })
  for _, k in ipairs(okc and type(list) == "table" and list or {}) do cards[u32(k.id)] = k end
  if not okc then warn("character index not readable (" .. tostring(list) .. ")") end
  local function person(card)
    local k = cards[card]
    return k and person_of[u32(k.base)] or 0
  end
  local function position(card)
    local k = cards[card]
    return k and floor(tonumber(k.position) or 0) or 0
  end
  local function strength(card)
    local k = cards[card]
    local cols = k and k.cols
    return cols and tonumber(cols[cfg.strength_column]) or 0
  end
  -- a club's teams: its own, then its versions (a merged club)
  local function teams_of(c)
    local out = { c }
    for _, v in ipairs(type(c.versions) == "table" and c.versions or {}) do out[#out + 1] = v end
    return out
  end
  -- each person's home: the lowest (team order, slot, team key) among every club's teams; with
  -- cfg.home_own_game_first a team of the character's own game (his card's series) before the others (owner
  -- 2026-10-31: a Victory Road character plays for a Victory Road team, not a story team of another game he is in)
  local home, best = {}, {}
  local function own_game(card, o)
    local k = cards[card]
    local game = k and floor(tonumber(k.series) or 0) or 0
    return (cfg.home_own_game_first and game >= 1 and game == o[1]) and 0 or 1
  end
  for _, c in ipairs(clubs) do
    for _, t in ipairs(teams_of(c)) do
      local o = order[t.key] or NO_ORDER
      if order[t.key] == nil then warn("team " .. t.key .. " is not in the club order: it ranks last") end
      for _, p in ipairs(t.players) do
        local who = person(p.card)
        if who ~= 0 then
          local key = { own_game(p.card, o), o[1], o[2], o[3], o[4], o[5], p.slot, t.key }
          if best[who] == nil or before(key, best[who]) then
            best[who], home[who] = key, c.id
          end
        end
      end
    end
  end
  -- the players each club owns (one card per person; a version's on the bench, slot -1), the rows its moved players
  -- leave (its own team's only)
  local own, vacated, kept, dropped = {}, {}, {}, 0
  for _, c in ipairs(clubs) do
    local seen, mine, left = {}, {}, {}
    for i, t in ipairs(teams_of(c)) do
      for _, p in ipairs(t.players) do
        local who = person(p.card)
        if who ~= 0 and home[who] == c.id and not seen[who] and not excluded[u32(p.card)]
            and not cfg.exclude_cards[u32(p.card)] then
          seen[who] = true
          mine[#mine + 1] = { card = p.card, slot = i == 1 and p.slot or -1, number = p.number }
        elseif i == 1 then
          left[#left + 1] = p
        end
      end
    end
    own[c.id], vacated[c.id] = mine, left
    if #mine >= cfg.min_players then
      kept[#kept + 1] = c
    else
      dropped = dropped + 1
    end
  end
  -- the free players: persons no kept club owns, by position, game and strength (one bucket list each, drawn once)
  local used = {}
  for _, c in ipairs(kept) do
    for _, p in ipairs(own[c.id]) do used[person(p.card)] = true end
  end
  local pool, free = {}, 0
  local rng = VRFW.rng("CareerMode.squads", { seed })
  for _, k in ipairs(type(list) == "table" and list or {}) do
    local card = u32(k.id)
    local pos = floor(tonumber(k.position) or 0)
    local who = person_of[u32(k.base)] or 0
    local game = floor(tonumber(k.series) or 0)
    local in_team = not cfg.free_need_team or (type(k.teams) == "table" and next(k.teams) ~= nil)
    if pos >= 1 and pos <= 4 and not k.coach and not k.manager and who ~= 0 and not used[who] and game >= 1 and in_team
        and not excluded[card] and not cfg.exclude_cards[card] then
      local s = strength(card)
      pool[pos] = pool[pos] or {}
      pool[pos][game] = pool[pos][game] or {}
      pool[pos][game][s] = pool[pos][game][s] or {}
      local b = pool[pos][game][s]
      b[#b + 1] = { card = card, person = who }
      free = free + 1
    end
  end
  for _, games in pairs(pool) do
    for _, strengths in pairs(games) do
      for _, b in pairs(strengths) do rng:shuffle(b) end
    end
  end
  -- the free card of `pos` closest to strength `s` (the club's game first, then any game); nil when none is left
  local function take_from(strengths, s)
    if strengths == nil then return nil end
    for d = 0, cfg.strength_reach do
      for _, v in ipairs(d == 0 and { s } or { s - d, s + d }) do
        local b = strengths[v]
        while b and #b > 0 do
          local x = table.remove(b)
          if not used[x.person] then
            used[x.person] = true
            return x.card
          end
        end
      end
    end
    return nil
  end
  local function sign(pos, game, s)
    local games = pool[pos]
    if games == nil then return nil end
    local card = cfg.same_game_first and take_from(games[game], s) or nil
    if card then return card end
    local list_games = {}
    for g in pairs(games) do list_games[#list_games + 1] = g end
    table.sort(list_games, function(a, b) return math.abs(a - game) < math.abs(b - game) or (math.abs(a - game) == math.abs(b - game) and a < b) end)
    for _, g in ipairs(list_games) do
      card = take_from(games[g], s)
      if card then return card end
    end
    return nil
  end
  -- the clubs sign in a seeded order (nobody gets the pool first every career)
  local turn = {}
  for i, c in ipairs(kept) do turn[i] = c end
  rng:shuffle(turn)
  local squads, signed_total, trimmed = {}, 0, 0
  for _, c in ipairs(turn) do
    local game = (order[c.key] or NO_ORDER)[1]
    local players, rows, numbers = {}, {}, {}
    local strengths, counts = {}, { 0, 0, 0, 0 }
    -- the own team's players keep their numbers, a version's player takes his when it is free
    local function free_number(n)
      n = tonumber(n) or 0
      if n > 0 and not numbers[n] then return n end
      n = 1
      while numbers[n] do n = n + 1 end
      return n
    end
    for _, p in ipairs(own[c.id]) do
      if p.slot >= 0 then numbers[p.number] = true end
    end
    for _, p in ipairs(vacated[c.id]) do numbers[p.number] = true end
    for _, p in ipairs(own[c.id]) do
      local number = p.slot >= 0 and p.number or free_number(p.number)
      players[#players + 1] = { card = p.card, slot = p.slot, number = number }
      numbers[number] = true
      strengths[#strengths + 1] = strength(p.card)
      local pos = position(p.card)
      if counts[pos] then counts[pos] = counts[pos] + 1 end
    end
    table.sort(strengths)
    local median = strengths[floor((#strengths + 1) / 2)] or 0
    -- every row a moved player left: a versions' player of his position on the bench (the closest strength), else a free
    -- player of his position and strength
    for _, p in ipairs(vacated[c.id]) do
      local pos = position(p.card)
      local seat
      for _, q in ipairs(players) do
        if q.slot < 0 and position(q.card) == pos and (seat == nil
            or math.abs(strength(q.card) - strength(p.card)) < math.abs(strength(seat.card) - strength(p.card))) then
          seat = q
        end
      end
      local card = seat == nil and (sign(pos, game, strength(p.card)) or sign(pos == 1 and 1 or 3, game, strength(p.card)))
      if seat then
        seat.slot = p.slot
        rows[#rows + 1] = p.slot
        rows[#rows + 1] = seat.card
      elseif card then
        players[#players + 1] = { card = card, slot = p.slot, number = p.number, signed = true }
        numbers[p.number] = true
        rows[#rows + 1] = p.slot
        rows[#rows + 1] = card
        local q = position(card)
        if counts[q] then counts[q] = counts[q] + 1 end
      else
        warn(string.format("club %s: no free player left for the row of slot %d", c.key, p.slot))
      end
    end
    -- the squad up to fill_to: a goalkeeper first when it has none, then the thinnest line
    while #players < cfg.fill_to do
      local pos = 1
      if counts[1] > 0 then
        pos = 4
        for _, q in ipairs({ 4, 3, 2 }) do
          if counts[q] < counts[pos] then pos = q end
        end
      end
      local card = sign(pos, game, median)
      if card == nil then break end
      local number = 1
      while numbers[number] do number = number + 1 end
      numbers[number] = true
      players[#players + 1] = { card = card, slot = -1, number = number, signed = true }
      counts[pos] = counts[pos] + 1
    end
    local left
    players, left = M.trim(players, cfg.max_players or 0, strength)
    if left > 0 then
      trimmed = trimmed + left
      info(string.format("club %s: %d player(s) over the squad cap of %d leave (they are free players)", c.key, left,
        cfg.max_players))
    end
    for _, p in ipairs(players) do
      if p.signed then signed_total = signed_total + 1 end
    end
    table.sort(players, function(a, b)
      local sa, sb = a.slot >= 0 and a.slot or 99, b.slot >= 0 and b.slot or 99
      if sa ~= sb then return sa < sb end
      return a.number < b.number
    end)
    squads[c.id] = { players = players, rows = rows }
  end
  local ids = {}
  for i, c in ipairs(kept) do ids[i] = c.id end
  info(string.format("%d of %d clubs keep %d+ players (%d dropped), %d players signed from %d free cards, %d over the cap",
    #kept, #clubs, cfg.min_players, dropped, signed_total, free, trimmed))
  return { clubs = ids, squads = squads, dropped = dropped, signed = signed_total }
end

-- The free players of a career now (the transfer market's free agents): every character a squad could sign (main
-- position 1-4, no coach or manager, some game; with cfg.free_need_team only characters of a belong team; none of
-- M.excluded or cfg.exclude_cards) whose person
-- plays for no club of `taken` (a set of cards) -> { { card, position, strength } }, in the character index's order
function M.free_pool(taken, cfg)
  local person_of = persons()
  local excluded = M.excluded(cfg)
  local ok, list = pcall(VRFW.chara.cards, { columns = { cfg.strength_column }, character = true })
  if not ok or type(list) ~= "table" then
    warn("character index not readable (" .. tostring(list) .. "): no free players")
    return {}
  end
  local used = {}
  for _, k in ipairs(list) do
    if taken[u32(k.id)] then used[person_of[u32(k.base)] or 0] = true end
  end
  local out, seen = {}, {}
  for _, k in ipairs(list) do
    local pos = floor(tonumber(k.position) or 0)
    local who = person_of[u32(k.base)] or 0
    local game = floor(tonumber(k.series) or 0)
    local in_team = not cfg.free_need_team or (type(k.teams) == "table" and next(k.teams) ~= nil)
    if pos >= 1 and pos <= 4 and not k.coach and not k.manager and who ~= 0 and not used[who] and not seen[who]
        and game >= 1 and in_team and not excluded[u32(k.id)] and not cfg.exclude_cards[u32(k.id)] then
      seen[who] = true
      local cols = k.cols
      out[#out + 1] = { card = u32(k.id), position = pos, strength = cols and tonumber(cols[cfg.strength_column]) or 0 }
    end
  end
  return out
end

return M
