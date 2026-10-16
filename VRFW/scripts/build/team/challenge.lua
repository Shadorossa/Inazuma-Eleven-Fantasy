-- Match challenges (`[[VRFW.MatchChallenge]]`): the declarations, the matches that name them (route nodes, chain tiles,
-- free-match tabs, the challenges' own `Games`) and the player attributes their conditions read.
-- `[[VRFW.MatchChallenge.Required]]`: required starters (`Characters` in formation places `Positions`, optionally `UntilFirstClear`, `Label`).
-- `[VRFW.MatchChallenge.Auras]`: the match aura rule (`Allowed` kinds, `Sides`, `Label`).
local T = require "lib/team_util"
local Q = {}

-- nested requirement / filter depth (a typo cannot recurse forever)
local MAX_DEPTH = 6
local GENDER = { male = 1, female = 2 }
local ELEMENT = { neutral = 0, wind = 1, wood = 2, fire = 3, earth = 4 }
local POSITION = { gk = 1, fw = 2, mf = 3, df = 4 }
-- the aura kinds of `[VRFW.MatchChallenge.Auras]` Allowed
local AURA_KINDS = { keshin = true, armour = true, miximax = true, totem = true, bond = true, awakening = true, own_mode_change = true, created_mode_change = true }

-- a name of a challenge: `<Prefix>.<Name>`, letters / digits / `_` per part, never the framework's `vrfw.`
local function valid_name(s)
  local a, b = s:match("^([^%.]*)%.([^%.]*)$")
  if not a then return false end
  local function ok(p) return p ~= "" and p:find("^[A-Za-z0-9_]+$") ~= nil end
  return ok(a) and ok(b) and a:lower() ~= "vrfw"
end

local function items(x)
  if x == nil then return {} end
  if type(x) == "table" then return x end
  return { x }
end

function Q.install(X)
  function X.challenge_filter(what, m, f, depth)
    if depth > MAX_DEPTH then return nil, "filters nested deeper than " .. MAX_DEPTH end
    local b = { gender = f.Gender and GENDER[f.Gender] or 0, elements = {}, positions = {}, series = {}, teams = {}, charas = {}, any_of = {} }
    for _, e in ipairs(items(f.Element)) do b.elements[#b.elements + 1] = ELEMENT[e] end
    for _, p in ipairs(items(f.Position)) do b.positions[#b.positions + 1] = POSITION[p] end
    local known_series = {}
    for _, s in pairs(X.ch.series) do known_series[s] = true end
    for _, s in ipairs(items(f.Series)) do
      local id = T.id(s)
      if not known_series[id] then
        VRFW.log.warn(what .. ": Series `" .. T.idref_text(s) .. "`: no character of the game has that series (chara_base col 15)")
      end
      b.series[#b.series + 1] = id
    end
    local known_teams = {}
    for _, t in pairs(X.ch.belong) do
      for _, x in ipairs(t) do if x ~= 0 then known_teams[x] = true end end
    end
    for _, t in ipairs(items(f.Team)) do
      local id = T.id(t)
      if not known_teams[id] then
        VRFW.log.warn(what .. ": Team `" .. T.idref_text(t) .. "`: no character of the game belongs to that team (chara_base cols 16-18)")
      end
      b.teams[#b.teams + 1] = id
    end
    for _, c in ipairs(items(f.Characters)) do
      local id, e = X.chara_of(c, m)
      if id == nil then
        VRFW.log.error(what .. ": Characters: " .. e .. " (left out)")
      elseif id == 0 then
        VRFW.log.error(what .. ": Characters `" .. c .. "`: no character (left out)")
      else
        b.charas[#b.charas + 1] = id
      end
    end
    if (f.MinLevel ~= nil and f.MaxLevel ~= nil and f.MinLevel > f.MaxLevel) or (f.MinRarity ~= nil and f.MaxRarity ~= nil and f.MinRarity > f.MaxRarity) then
      return nil, "MinLevel > MaxLevel or MinRarity > MaxRarity"
    end
    b.min_level, b.max_level, b.min_rarity, b.max_rarity = f.MinLevel, f.MaxLevel, f.MinRarity, f.MaxRarity
    if f.Not ~= nil then
      local x, e = X.challenge_filter(what, m, f.Not, depth + 1)
      if not x then return nil, e end
      b["not"] = x
    end
    for _, a in ipairs(f.AnyOf or {}) do
      local x, e = X.challenge_filter(what, m, a, depth + 1)
      if not x then return nil, e end
      b.any_of[#b.any_of + 1] = x
    end
    return b
  end

  function X.challenge_req(what, m, r, depth)
    if depth > MAX_DEPTH then return nil, "conditions nested deeper than " .. MAX_DEPTH end
    local n = 0
    for _, g in ipairs { r.Every ~= nil, r.None ~= nil, r.Count ~= nil, #(r.AnyOf or {}) > 0, #(r.AllOf or {}) > 0 } do
      if g then n = n + 1 end
    end
    if n ~= 1 then return nil, "a Require needs exactly one of Every, None, Count, AnyOf, AllOf" end
    if (r.AtLeast ~= nil or r.AtMost ~= nil) and r.Count == nil then return nil, "AtLeast / AtMost go with Count" end
    if r.AtLeast ~= nil and r.AtMost ~= nil and r.AtLeast > r.AtMost then return nil, "AtLeast > AtMost" end
    local b = { kind = "", at_least = -1, at_most = -1, text = r.Text or "", sub = {} }
    local function filter(f)
      local x, e = X.challenge_filter(what, m, f, depth + 1)
      if not x then return nil, e end
      b.filter = x
      return true
    end
    local ok, e = true, nil
    if r.Every ~= nil then
      b.kind = "every"
      ok, e = filter(r.Every)
    elseif r.None ~= nil then
      b.kind = "none"
      ok, e = filter(r.None)
    elseif r.Count ~= nil then
      b.kind = "count"
      ok, e = filter(r.Count)
      if r.AtLeast ~= nil then b.at_least = r.AtLeast elseif r.AtMost ~= nil then b.at_least = -1 else b.at_least = 1 end
      b.at_most = r.AtMost ~= nil and r.AtMost or -1
    else
      local list = (#(r.AnyOf or {}) == 0) and r.AllOf or r.AnyOf
      b.kind = (#(r.AnyOf or {}) == 0) and "all" or "any"
      for _, s in ipairs(list) do
        local x, xe = X.challenge_req(what, m, s, depth + 1)
        if not x then return nil, xe end
        b.sub[#b.sub + 1] = x
      end
    end
    if not ok then return nil, e end
    return b
  end

  -- the games of piece `piece` (its event slice, `paramCrc1`), 0 left out
  function X.piece_games(piece)
    local r, pl, el = X.route_lists()
    if not r then return nil, pl end
    local fid, e1 = r:field(pl, "pieceId")
    if not fid then return nil, e1 end
    local fref, e2 = r:field(pl, "eventInfoRef")
    if not fref then return nil, e2 end
    local fg, e3 = r:field(el, "paramCrc1")
    if not fg then return nil, e3 end
    local p = X.piece_row(r, pl, fid, piece)
    if p == nil then return nil, "piece " .. T.hex(piece) .. " is not in chronicle_vs_route_config" end
    local a, b = r:tuple(pl, p, fref)
    if a == nil then a, b = 0, 0 end
    local out = {}
    for j = a, a + b - 1 do
      local g = r:u32(el, j, fg)
      if g and g ~= 0 then out[#out + 1] = g end
    end
    return out
  end

  -- `[[VRFW.MatchChallenge]]`s and every match that names one (after the route nodes, chains and free-match tabs)
  function X.match_challenges(files, nodes, chains, tabs)
    local out = { list = {}, games = {}, data = { cards = {}, charas = {} } }
    -- (1) the declarations, in load order; a later one with the same name replaces the earlier one
    local decl_games = {}
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.MatchChallenge or {}) do
        local what = f.file .. ": vrfw.MatchChallenge `" .. d.Name .. "`"
        if not valid_name(d.Name) then
          VRFW.log.error(what .. ": Name must be `<ModPrefix>.<Name>` (letters, digits, _; not vrfw.): skipped")
        elseif T.trim(d.Title) == "" then
          VRFW.log.error(what .. ": Title (a menu_text row id) is required: skipped")
        else
          if #(d.Require or {}) == 0 and #(d.Required or {}) == 0 then VRFW.log.warn(what .. ": no [[vrfw.MatchChallenge.Require]]: every team passes") end
          local req, bad = {}, nil
          for _, r in ipairs(d.Require or {}) do
            local x, e = X.challenge_req(what, f.mod, r, 0)
            if not x then bad = e break end
            req[#req + 1] = x
          end
          -- `Difficulties`: the difficulty rows of its games it applies to (empty = every row), 1-255, sorted, once each
          local diffs, seen = {}, {}
          for _, x in ipairs(d.Difficulties or {}) do
            if bad == nil and (x < 1 or x > 255) then bad = "Difficulties: " .. tostring(x) .. " is not a difficulty id (1-255)" end
            if not seen[x] then seen[x] = true diffs[#diffs + 1] = x end
          end
          table.sort(diffs)
          -- `Required`: starters who must play in given formation places (any card of the characters)
          local required = {}
          for _, r in ipairs(d.Required or {}) do
            local charas = {}
            for _, c in ipairs(items(r.Characters)) do
              local id, e = X.chara_of(c, f.mod)
              if id == nil then
                VRFW.log.error(what .. ": Required Characters: " .. e .. " (left out)")
              elseif id == 0 then
                VRFW.log.error(what .. ": Required Characters `" .. c .. "`: no character (left out)")
              else
                charas[#charas + 1] = id
              end
            end
            if #charas == 0 then
              VRFW.log.error(what .. ": a Required names no known character (left out)")
            else
              local positions = {}
              for _, x in ipairs(items(r.Positions)) do positions[#positions + 1] = POSITION[x] end
              required[#required + 1] = { charas = charas, positions = positions, until_first_clear = r.UntilFirstClear == true, text = r.Text or "", label = r.Label or "" }
            end
          end
          if bad then
            VRFW.log.error(what .. ": " .. bad .. ": skipped")
          else
            -- `Auras`: the match aura rule (the allowed kinds' words, sorted, once each)
            local auras = nil
            if d.Auras ~= nil then
              local words, seen_word = {}, {}
              for _, k in ipairs(d.Auras.Allowed or {}) do
                if AURA_KINDS[k] == nil then
                  VRFW.log.error(what .. ": Auras: `" .. tostring(k) .. "` is not an aura kind (left out)")
                elseif not seen_word[k] then
                  seen_word[k] = true
                  words[#words + 1] = k
                end
              end
              table.sort(words)
              auras = { allowed = words, sides = d.Auras.Sides or "both", label = T.trim(d.Auras.Label or "") }
            end
            local b = { name = d.Name, mod_id = f.mod, title = T.trim(d.Title), description = d.Description or "", short = T.trim(d.Short or ""), scope = d.Scope or "squad", require = req, difficulties = diffs, required = required, auras = auras }
            local idx
            for k, c in ipairs(out.list) do if c.name == d.Name then idx = k break end end
            if idx then
              VRFW.log.warn(what .. ": declared again (first by " .. out.list[idx].mod_id .. "): this declaration replaces it")
              local keep = {}
              for _, x in ipairs(decl_games) do if x[1] ~= idx then keep[#keep + 1] = x end end
              decl_games = keep
              out.list[idx] = b
            else
              out.list[#out.list + 1] = b
              idx = #out.list
            end
            for _, g in ipairs(d.Games or {}) do
              decl_games[#decl_games + 1] = { idx, T.id(g), what .. ": Games `" .. T.idref_text(g) .. "`" }
            end
          end
        end
      end
    end
    local any_named = false
    for _, f in ipairs(files) do
      for _, n in ipairs(f.value.vrfw.RouteNode or {}) do if n.Challenge ~= nil then any_named = true end end
      for _, c in ipairs(f.value.vrfw.Chain or {}) do
        if c.Challenge ~= nil then any_named = true end
        for _, t in ipairs(c.tile or {}) do if t.Challenge ~= nil then any_named = true end end
      end
      for _, t in ipairs(f.value.vrfw.FreeMatchTab or {}) do if t.Challenge ~= nil then any_named = true end end
    end
    if #out.list == 0 and not any_named then return out end
    -- (2) the attachments: the matches that name a challenge first (route nodes, chain tiles / chains), then the
    -- free-match tabs, then the challenges' own `Games`; the first one of a game wins
    local map = {}
    local function attach(game, name, what)
      local i
      for k, c in ipairs(out.list) do if c.name == name then i = k - 1 break end end
      if i == nil then
        VRFW.log.error(what .. ": Challenge `" .. name .. "`: no [[vrfw.MatchChallenge]] has that Name (not attached)")
        return
      end
      if game == 0 then
        VRFW.log.warn(what .. ": Challenge `" .. name .. "`: no match game (not attached)")
        return
      end
      local cur = map[game]
      if cur then
        if cur[1] ~= i then
          VRFW.log.warn(string.format("%s: game %s already has challenge `%s` (%s): `%s` ignored", what, T.hex(game), out.list[cur[1] + 1].name, cur[2], name))
        end
      else
        map[game] = { i, what }
      end
    end
    for _, f in ipairs(files) do
      for _, n in ipairs(f.value.vrfw.RouteNode or {}) do
        if n.Challenge ~= nil then
          local key = VRFW.ids.own(f.mod, n.name) or ""
          local what = f.file .. ": vrfw.RouteNode `" .. n.name .. "`"
          local b
          for _, x in ipairs(nodes) do if x.key == key then b = x break end end
          if b then attach(b.game, n.Challenge, what)
          else VRFW.log.warn(what .. ": Challenge `" .. n.Challenge .. "`: the node was not built (not attached)") end
        end
      end
      for _, ch in ipairs(f.value.vrfw.Chain or {}) do
        local key = VRFW.ids.own(f.mod, ch.name) or ""
        local b
        for _, x in ipairs(chains) do if x.key == key then b = x break end end
        local tile_named = false
        for _, t in ipairs(ch.tile or {}) do if t.Challenge ~= nil then tile_named = true end end
        if not b then
          if ch.Challenge ~= nil or tile_named then
            VRFW.log.warn(f.file .. ": vrfw.Chain `" .. ch.name .. "`: Challenge: the chain was not built (not attached)")
          end
        elseif not b.board then
          if ch.Challenge ~= nil then
            VRFW.log.warn(f.file .. ": vrfw.Chain `" .. ch.name .. "`: Challenge is read on chain boards only (a free-walk chain's matches are not checked yet)")
          end
        else
          for _, t in ipairs(ch.tile or {}) do
            local c = t.Challenge or ch.Challenge
            if c ~= nil then
              local what = f.file .. ": vrfw.Chain `" .. ch.name .. "` tile `" .. t.id .. "`"
              local x
              for _, y in ipairs(b.board.tiles) do if y.id == t.id then x = y break end end
              if x and x.kind == "match" then
                attach(x.game, c, what)
              elseif x and t.Challenge ~= nil then
                VRFW.log.warn(what .. ": Challenge on a tile that is not a match (ignored)")
              elseif not x then
                VRFW.log.warn(what .. ": Challenge `" .. c .. "`: the tile was not built (not attached)")
              end
            end
          end
        end
      end
    end
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.FreeMatchTab or {}) do
        if d.Challenge ~= nil then
          local c = d.Challenge
          local what = f.file .. ": vrfw.FreeMatchTab `" .. d.id .. "`"
          local tab
          for _, t in ipairs(tabs) do if t.id == d.id then tab = t break end end
          if not tab then
            VRFW.log.warn(what .. ": Challenge `" .. c .. "`: the tab is not shown (not attached)")
          else
            -- the pieces this declaration lists (a shared tab: each mod's challenge covers its own pieces)
            for _, pr in ipairs(d.pieces or {}) do
              local p = T.id(pr)
              if T.contains(tab.pieces, p) then
                local gs, e = X.piece_games(p)
                if gs then
                  for _, g in ipairs(gs) do attach(g, c, what) end
                else
                  VRFW.log.warn(what .. ": Challenge `" .. c .. "`: " .. e)
                end
              end
            end
          end
        end
      end
    end
    for _, x in ipairs(decl_games) do
      attach(x[2], out.list[x[1]].name, x[3])
    end
    for _, g in ipairs(T.keys(map)) do out.games[#out.games + 1] = { g, map[g][1] } end
    for k, c in ipairs(out.list) do
      local n = 0
      for _, x in ipairs(out.games) do if x[2] == k - 1 then n = n + 1 end end
      VRFW.log.info(string.format("match challenge %s (%s): %d condition(s), scope %s, %d match game(s)", c.name, c.mod_id, #c.require, c.scope, n))
      if #c.required > 0 then VRFW.log.info(string.format("match challenge %s: %d required starter(s)", c.name, #c.required)) end
      if n == 0 then VRFW.log.warn("match challenge " .. c.name .. ": no match uses it") end
    end
    -- (3) the attributes the conditions read (only with a challenge)
    if #out.list > 0 then
      local cards = {}
      for card, x in pairs(X.ch.card) do cards[#cards + 1] = { card, x.chara, T.u32(x.elem), T.u32(x.pos) } end
      local function lex(a, b)
        for k = 1, #a do
          if a[k] ~= b[k] then return a[k] < b[k] end
        end
        return false
      end
      table.sort(cards, lex)
      local charas = {}
      for ch in pairs(X.ch.cards) do
        local t = X.ch.belong[ch] or { 0, 0, 0 }
        charas[#charas + 1] = { ch, X.ch.gender[ch] or 0, X.ch.series[ch] or 0, t[1], t[2], t[3] }
      end
      table.sort(charas, lex)
      out.data = { cards = cards, charas = charas }
    end
    return out
  end
end

return Q
