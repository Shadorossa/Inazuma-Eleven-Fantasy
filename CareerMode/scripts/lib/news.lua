-- The career's news (docs/game/mods/career-mode-proposal.md «Noticias»): a queue kept in the career (c.news, newest
-- first, at most config [news] keep). Producers: the market's deals and offers (env.news from lib/market.lua), the
-- player's match results, and the watch of the season's state after each round (table places, the Fútbol Frontier, the
-- World Cup, the transfer windows). The hub's «Noticias» feed reads them with CMND_CAREERMODE_NEWS: texts in the game's
-- language, the picture as a player card + the team whose kit he wears + the clip list of his pose (VRFW_ModelCard).
-- An item kept: { id, kind, tag, head = { key, args }, body = { key, args }, day, card, team, from, amount, role, action }
-- args: { "p", card } a player's name, { "t", team } a team's name, { "m", n } an amount, { "n", n } a number,
-- { "k", key } another text, { "d", day } a date.

local N = {}

local floor = math.floor

-- config [news]
function N.config(env)
  local poses = env.config("news.poses", nil)
  return {
    keep = env.int("news.keep", 40),
    max_age_days = env.int("news.max_age_days", 4),
    ai_per_round = env.int("news.ai_transfers_per_round", 3),
    poses = type(poses) == "table" and poses or {},
    picture = env.config("news.picture", nil),
  }
end

function N.state(c)
  if type(c.news) ~= "table" then c.news = { next_id = 1, items = {}, watch = nil, rev = 0 } end
  c.news.items = c.news.items or {}
  if not c.news.no_previews then
    -- the items of kinds older versions made and no longer exist (owner 2026-10-31: no player level news, no match
    -- previews) go once
    for i = #c.news.items, 1, -1 do
      local tag = c.news.items[i].tag
      if tag == "NewsTagLevel" or tag == "NewsTagPreview" then table.remove(c.news.items, i) end
    end
    c.news.no_levels, c.news.no_previews = true, true
  end
  return c.news
end

function N.push(env, c, it)
  local s = N.state(c)
  local cfg = N.config(env)
  it.id = s.next_id
  s.next_id = s.next_id + 1
  it.day = it.day or env.today_of(c)
  table.insert(s.items, 1, it)
  while #s.items > cfg.keep do table.remove(s.items) end
  s.rev = (s.rev or 0) + 1
end

-- ---- producers ---------------------------------------------------------------------------------------------------------

-- a closed deal (lib/market.lua): { card, from, to, fee, day }
function N.transfer(env, c, d)
  local mine = d.to == c.team or d.from == c.team
  local s = N.state(c)
  if not mine then
    -- rival deals: at most [news] ai_transfers_per_round a day
    local cfg, day, count = N.config(env), d.day or env.today_of(c), 0
    for _, it in ipairs(s.items) do
      if it.kind == "transfer" and it.rival and it.day == day then count = count + 1 end
    end
    if count >= cfg.ai_per_round then return end
  end
  local tag = d.to == c.team and "NewsTagSigning" or (d.from == c.team and "NewsTagSale" or "NewsTagTransfer")
  local body = d.from ~= 0 and { "NewsTextTransfer", { { "t", d.from }, { "m", d.fee or 0 } } } or { "NewsTextTransferFree", {} }
  N.push(env, c, { kind = "transfer", rival = not mine or nil, tag = tag,
    head = { "NewsHeadTransfer", { { "p", d.card }, { "t", d.to } } }, body = body, day = d.day,
    card = d.card, team = d.to, from = d.from, amount = d.fee or 0,
    role = d.from == c.team and "proud" or "celebrate" })
end

-- an AI club's bid for one of the player's men (lib/market.lua): { card, club, amount[, spontaneous: on no list] }
function N.offer(env, c, o)
  N.push(env, c, { kind = "transfer", tag = "NewsTagOffer", head = { "NewsHeadOffer", { { "p", o.card } } },
    body = { o.spontaneous and "NewsTextOfferUnlisted" or "NewsTextOffer", { { "t", o.club }, { "m", o.amount or 0 } } },
    card = o.card, team = c.team,
    from = o.club, amount = o.amount or 0, role = "stand", action = "offers" })
end

-- a bidder's answer to the player's asking price (lib/market.lua bid_replies): { card, club, amount, ask, reply =
-- "agreed" / "counter" / "walked" }
function N.bid_reply(env, c, o)
  local text = { agreed = "NewsTextBidAgreed", counter = "NewsTextBidCounter", walked = "NewsTextBidWalked" }
  N.push(env, c, { kind = "transfer", tag = "NewsTagOffer", head = { "NewsHeadBidReply", { { "p", o.card } } },
    body = { text[o.reply] or "NewsTextBidCounter", { { "t", o.club }, { "m", o.amount or 0 }, { "m", o.ask or 0 } } },
    card = o.card, team = c.team, from = o.club, amount = o.amount or 0, role = "stand",
    action = o.reply ~= "walked" and "offers" or nil })
end

-- an AI club's loan offer for one of the player's men listed for loan: { card, club, amount, back }
function N.loan_offer(env, c, o)
  N.push(env, c, { kind = "transfer", tag = "NewsTagLoan", head = { "NewsHeadLoanOffer", { { "p", o.card } } },
    body = { "NewsTextLoanOffer", { { "t", o.club }, { "m", o.amount or 0 }, { "d", o.back } } }, card = o.card,
    team = c.team, from = o.club, amount = o.amount or 0, role = "stand", action = "offers" })
end

-- one of the player's men loaned out (lib/market.lua): { card, from, to, back, fee, day }
function N.loan(env, c, l)
  N.push(env, c, { kind = "transfer", tag = "NewsTagLoan", head = { "NewsHeadLoan", { { "p", l.card }, { "t", l.to } } },
    body = { "NewsTextLoan", { { "m", l.fee or 0 }, { "d", l.back } } }, day = l.day, card = l.card, team = l.to,
    from = l.from, amount = l.fee or 0, role = "proud" })
end

-- a loan over: the player back in his club
function N.loan_back(env, c, l)
  N.push(env, c, { kind = "transfer", tag = "NewsTagLoan", head = { "NewsHeadLoanBack", { { "p", l.card } } },
    body = { "NewsTextLoanBack", { { "t", l.to } } }, card = l.card, team = l.from, from = l.to, amount = 0,
    role = "celebrate" })
end

-- the player's match: r = { home, away, home goals, away goals, penalties winner }, me = the player's side
function N.result(env, c, r, me)
  if not r or (r[1] ~= me and r[2] ~= me) then return end
  local home = r[1] == me
  local gf, ga = home and r[3] or r[4], home and r[4] or r[3]
  local won = gf > ga or (gf == ga and (r[5] or 0) == me)
  local lost = gf < ga or (gf == ga and (r[5] or 0) ~= 0 and r[5] ~= me)
  local rival = home and r[2] or r[1]
  local head = won and "NewsHeadWin" or (lost and "NewsHeadLoss" or "NewsHeadDraw")
  N.push(env, c, { kind = "result", tag = "NewsTagResult", head = { head, { { "t", rival } } },
    body = { "NewsTextScore", { { "t", r[1] }, { "n", r[3] }, { "n", r[4] }, { "t", r[2] } } },
    card = env.best_card(c, me), team = me, from = 0, amount = 0,
    role = won and "celebrate" or (lost and "let_down" or "stand") })
end

-- the season's opening items: the favourite (the best rated club's star), the board's objectives and the club's
-- presentation (its star in its kit) on top
function N.season_start(env, c)
  local me = c.team
  local top = env.top_club(c)
  if top and top ~= 0 and top ~= me then
    local star = env.best_card(c, top)
    N.push(env, c, { kind = "competition", tag = "NewsTagSeason", head = { "NewsHeadFavourite", { { "t", top } } },
      body = { "NewsTextFavourite", { { "p", star } } }, card = star, team = top, from = 0, amount = 0, role = "proud" })
  end
  local b = c.board
  if type(b) == "table" and b.season == c.season and (b.superliga or 0) > 0 then
    N.push(env, c, { kind = "club", tag = "NewsTagBoard", head = { "NewsHeadBoardGoals", { { "t", me } } },
      body = { "NewsTextBoardGoals", { { "n", b.superliga } } }, card = env.best_card(c, me), team = me, from = 0,
      amount = 0, role = "stand" })
  end
  local star = env.best_card(c, me)
  N.push(env, c, { kind = "club", tag = "NewsTagSeason", head = { "NewsHeadPresent", { { "t", me }, { "n", c.season } } },
    body = { "NewsTextPresent", { { "p", star } } }, card = star, team = me, from = 0, amount = 0, role = "proud" })
end

-- the player's matchday: his match (N.result), the player of the matchday of his side
function N.matchday(env, c, r, me, star)
  N.result(env, c, r, me)
  if star and (star.card or 0) ~= 0 then
    local rival = r[1] == me and r[2] or r[1]
    N.push(env, c, { kind = "result", tag = "NewsTagPlayer", head = { "NewsHeadPlayerOfDay", { { "p", star.card } } },
      body = { "NewsTextPlayerOfDay", { { "t", me }, { "t", rival } } }, card = star.card, team = me, from = 0,
      amount = 0, role = "celebrate" })
  end
end

-- an empty feed (a career started before the news, or nothing happened yet): the season's opening items
function N.backfill(env, c)
  local s = N.state(c)
  if #s.items > 0 then return false end
  N.season_start(env, c)
  s.watch = env.watch(c)
  return true
end

-- the season's state after a round (env.watch(c)) against the last one: table places, the competitions, the windows
function N.observe(env, c)
  local s = N.state(c)
  local w = env.watch(c)
  local last = s.watch
  s.watch = w
  local empty = #s.items == 0
  if last == nil or last.season ~= w.season then
    if last ~= nil or empty then N.season_start(env, c) end
    return
  end
  local me, best = c.team, env.best_card
  -- the leader of the player's table (another club)
  if w.table ~= "" and w.table == last.table and (w.leader or 0) ~= 0 and w.leader ~= last.leader and w.leader ~= me then
    N.push(env, c, { kind = "club", tag = "NewsTagTable", head = { "NewsHeadNewLeader", { { "t", w.leader } } },
      body = { "NewsTextPlace", { { "n", 1 }, { "n", w.leader_points or 0 } } }, card = best(c, w.leader),
      team = w.leader, from = 0, amount = 0, role = "proud" })
  end
  local function team_item(kind, tag, head, body, role, side)
    side = side or me
    N.push(env, c, { kind = kind, tag = tag, head = head, body = body, card = best(c, side), team = side, from = 0,
      amount = 0, role = role })
  end
  -- the transfer window
  if w.window ~= last.window then
    if w.window then
      N.push(env, c, { kind = "club", tag = "NewsTagMarket", head = { "NewsHeadWindowOpen", {} },
        body = { "NewsTextWindowOpen", { { "d", w.window_to } } }, card = 0, team = me, from = 0, amount = 0 })
    else
      local body = w.window_next and { "NewsTextWindowClose", { { "d", w.window_next } } } or { "NewsTextWindowLast", {} }
      N.push(env, c, { kind = "club", tag = "NewsTagMarket", head = { "NewsHeadWindowClose", {} }, body = body,
        card = 0, team = me, from = 0, amount = 0 })
    end
  end
  -- the table (same competition only)
  if w.table ~= "" and w.table == last.table and w.place > 0 and last.place > 0 and w.place ~= last.place then
    local body = { "NewsTextPlace", { { "n", w.place }, { "n", w.points } } }
    local name = { { "t", me } }
    if w.place == 1 then
      team_item("club", "NewsTagTable", { "NewsHeadLeader", name }, body, "celebrate")
    elseif last.place == 1 then
      team_item("club", "NewsTagTable", { "NewsHeadLeadLost", name }, body, "let_down")
    elseif w.cut > 0 and (w.place <= w.cut) ~= (last.place <= last.cut) then
      local inside = w.place <= w.cut
      team_item("club", "NewsTagTable", { inside and "NewsHeadZoneIn" or "NewsHeadZoneOut", name }, body,
        inside and "celebrate" or "let_down")
    end
  end
  -- the Fútbol Frontier
  local frontier = { "k", "NewsCompFrontier" }
  if w.champion ~= 0 and last.champion == 0 and w.champion == me then
    team_item("competition", "NewsTagCup", { "NewsHeadChampion", { { "t", me }, frontier } },
      { "NewsTextChampion", { { "n", w.season } } }, "celebrate")
  elseif w.out and not last.out and w.out_reason == "frontier" then
    team_item("competition", "NewsTagCup", { "NewsHeadOut", { { "t", me }, frontier } }, { "NewsTextOut", {} }, "let_down")
  elseif w.phase == "frontier" and last.phase == "frontier" and not w.out and w.reached ~= last.reached then
    team_item("competition", "NewsTagCup", { "NewsHeadThrough", { { "t", me }, frontier } }, { "NewsTextThrough", {} },
      "celebrate")
  end
  -- the World Cup
  local cup = { "k", "NewsCompWorldCup" }
  local side = w.wc_side
  if w.wc_stage == "call" and last.wc_stage ~= "call" and side ~= 0 then
    N.push(env, c, { kind = "competition", tag = "NewsTagWorldCup", head = { "NewsHeadWorldCupCall", { { "t", side } } },
      body = { "NewsTextWorldCupCall", {} }, card = 0, team = side, from = 0, amount = 0 })
  elseif side ~= 0 and w.wc_champion ~= 0 and last.wc_champion == 0 and w.wc_champion == side then
    team_item("competition", "NewsTagWorldCup", { "NewsHeadChampion", { { "t", side }, cup } },
      { "NewsTextChampion", { { "n", w.season } } }, "celebrate", side)
  elseif side ~= 0 and w.wc_out and not last.wc_out then
    team_item("competition", "NewsTagWorldCup", { "NewsHeadOut", { { "t", side }, cup } }, { "NewsTextOut", {} },
      "let_down", side)
  elseif side ~= 0 and not w.wc_out and w.wc_stage == "knockout" and (last.wc_stage == "groups" or
      (last.wc_stage == "knockout" and w.wc_round ~= last.wc_round)) then
    team_item("competition", "NewsTagWorldCup", { "NewsHeadThrough", { { "t", side }, cup } }, { "NewsTextThrough", {} },
      "celebrate", side)
  end
end

-- ---- the feed's view ---------------------------------------------------------------------------------------------------

-- the texts of the mod (text\rows\career.toml) in a language column: { [id] = text }
local TEXTS = {}
local function texts(env, column)
  if TEXTS[column] then return TEXTS[column] end
  local out = {}
  local ok, doc = pcall(VRFW.files.toml, "text/rows/career.toml")
  for _, row in ipairs(ok and type(doc) == "table" and doc.row or {}) do
    if type(row.id) == "string" then
      local s = row[column]
      if type(s) ~= "string" or s == "" then s = row.en end
      out[row.id] = type(s) == "string" and s or row.id
    end
  end
  TEXTS[column] = out
  return out
end

-- (env, items, lang code) -> the items as the hub draws them
function N.view(env, c, lang, from, count)
  local s = N.state(c)
  local cfg = N.config(env)
  local column = env.text_column(lang)
  local T = texts(env, column)
  local cards, teams = {}, {}
  from = math.max(1, floor(tonumber(from) or 1))
  count = math.max(1, floor(tonumber(count) or #s.items))
  -- the feed: the items of the last max_age_days days (career days, from today)
  local today = env.today_of(c)
  local recent = {}
  for _, it in ipairs(s.items) do
    if today - (tonumber(it.day) or today) < cfg.max_age_days then recent[#recent + 1] = it end
  end
  local list = {}
  for i = from, math.min(#recent, from + count - 1) do list[#list + 1] = recent[i] end
  local function scan(args)
    for _, a in ipairs(args or {}) do
      if a[1] == "p" then cards[#cards + 1] = a[2] elseif a[1] == "t" then teams[#teams + 1] = a[2] end
    end
  end
  for _, it in ipairs(list) do
    scan(it.head and it.head[2])
    scan(it.body and it.body[2])
  end
  local names = env.card_names(cards, lang)
  local team_names = env.team_names(teams, lang)
  local function thousands(n)
    local digits = tostring(floor(tonumber(n) or 0))
    local neg = digits:sub(1, 1) == "-"
    if neg then digits = digits:sub(2) end
    local sep = T["CareerMode.ThousandsSep"] or "."
    local out = digits:sub(1, (#digits - 1) % 3 + 1)
    for i = (#digits - 1) % 3 + 2, #digits, 3 do out = out .. sep .. digits:sub(i, i + 2) end
    return (neg and "-" or "") .. out
  end
  local function date(day)
    local v = day and env.date_view(day) or nil
    if type(v) ~= "table" then return "" end
    return ((T["CareerMode.DateShort"] or "{1}/{2}"):gsub("{1}", string.format("%02d", v.d)):gsub("{2}", string.format("%02d", v.m)))
  end
  local function arg_text(a)
    local k, v = a[1], a[2]
    if k == "p" then return names[v] or "" end
    if k == "t" then return team_names[v] or "" end
    if k == "m" then return thousands(v) end
    if k == "k" then return T["CareerMode." .. tostring(v)] or "" end
    if k == "d" then return date(v) end
    return tostring(v)
  end
  local function text(t)
    if type(t) ~= "table" then return "" end
    local s = T["CareerMode." .. tostring(t[1])] or ""
    for i, a in ipairs(t[2] or {}) do
      local v = arg_text(a)
      s = s:gsub("{" .. i .. "}", function() return v end)
    end
    return s
  end
  local poses = cfg.poses
  local out = {}
  for _, it in ipairs(list) do
    local clips = poses[it.role or "stand"]
    out[#out + 1] = { id = it.id, kind = it.kind, tag = T["CareerMode." .. tostring(it.tag)] or "", date = env.date_view(it.day),
      head = text(it.head), body = text(it.body), card = it.card or 0, team = it.team or 0, from = it.from or 0,
      amount = it.amount or 0, action = it.action or "", role = it.role or "",
      clips = type(clips) == "table" and table.concat(clips, "|") or "", seen = it.seen == true }
  end
  local unseen = 0
  for _, it in ipairs(recent) do if not it.seen then unseen = unseen + 1 end end
  return { ok = true, items = out, total = #recent, unseen = unseen, rev = s.rev or 0, picture = cfg.picture }
end

-- the items up to id seen
function N.seen(c, id)
  local s = N.state(c)
  local changed = false
  for _, it in ipairs(s.items) do
    if it.id <= (tonumber(id) or 0) and not it.seen then it.seen, changed = true, true end
  end
  return changed
end

return N
