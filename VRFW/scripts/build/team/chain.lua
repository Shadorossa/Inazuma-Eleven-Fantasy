-- `[[VRFW.Chain]]`: match chains, either an ordered list of matches (`[[VRFW.Chain.Node]]`) or a board of tiles (`[[VRFW.Chain.Tile]]`).
-- Each match is game `evt_ch_<chain>_<NN>`, cloned from the template against the team, its stadium and title; talks resolved to built ids.
local T = require "lib/team_util"
local TC = require "team/tc"
local CH = {}

local GAME_DIR = "data/common/gamedata/soccer/game/"
-- Pachanga rules used when a chain names none (the caller's mod declares it).
local CHAIN_PACHANGA = "chain_match"
-- Max nodes per chain (two-digit game suffix); chain board size limits.
local MAX_NODES = 99
local MAX_BOARD_COLS, MAX_BOARD_ROWS, MAX_HEX_COLS, MAX_BOARD_PAGES = 6, 5, 16, 8
-- SOCCER_GAME_DIFFICULTY prize columns: 8 win prize, 11-14 bean tables, 34 first clear.
local D_WIN_PRIZE, D_BEAN_PRIZES, D_FIRST_CLEAR_PRIZE = 8, { 11, 12, 13, 14 }, 34

local function valid_name(s)
  return s ~= "" and #s <= 16 and s:find("^[a-z0-9_]+$") ~= nil
end

local function map_id(s)
  local t = T.trim(s)
  if t:sub(1, 2) == "0x" or t:sub(1, 2) == "0X" or t:find("^%d*$") then return VRFW.ids.parse(t) end
  return VRFW.crc32(t)
end

local function norm(x)
  local out = {}
  for _, k in ipairs(T.keys(x or {})) do
    local n = VRFW.lang.norm_or_all(k)
    if n then out[n] = x[k] end
  end
  return out
end

-- Exactly one of `item` / `player` per reward; `player` only on chest tiles.
local function check_rewards(r, allow_player)
  for _, x in ipairs(r or {}) do
    if x.item ~= nil and x.player == nil then
      -- ok
    elseif x.item == nil and x.player ~= nil and allow_player and T.trim(x.player) ~= "" then
      -- ok
    elseif x.item == nil and x.player ~= nil and not allow_player then
      return nil, "reward `player` only applies to chest tiles"
    else
      return nil, "a reward needs exactly one of `item` / `player`"
    end
  end
  return true
end

-- `RivalStats`: "team" (default) or "normal"
local function check_rival_stats(v)
  if v == nil or v == "team" or v == "normal" then return true end
  return nil, "RivalStats = \"" .. tostring(v) .. "\": \"team\" or \"normal\""
end

-- `[[VRFW.Chain.RankReward]]` / `[[VRFW.Chain.Tile.RankReward]]`: a rank Id and exactly one of `Item` / `Rival`
local function check_rank_rewards(r)
  for k, x in ipairs(r or {}) do
    local rw = "rank reward " .. k
    if type(x.rank) ~= "string" or not x.rank:find("^[%w_]+$") then return nil, rw .. ": `Rank` = a declared rank Id (S, A, B...)" end
    if (x.item == nil) == (x.rival == nil) then return nil, rw .. ": exactly one of `Item` / `Rival`" end
    if x.rival ~= nil and x.rival ~= "emblem" and x.rival ~= "kit" then
      return nil, rw .. ": Rival = \"" .. tostring(x.rival) .. "\": \"emblem\" or \"kit\""
    end
  end
  return true
end

-- "item:count,..." (decimal ids; players are refused before)
local function rewards(r)
  local p = {}
  for _, x in ipairs(r or {}) do
    if x.item ~= nil then
      local c = x.count or 1
      if c < 1 then c = 1 end
      p[#p + 1] = T.d(T.id(x.item)) .. ":" .. T.d(c)
    elseif x.player ~= nil then
      local n = T.trim(x.player):gsub("[,:]", " ")
      p[#p + 1] = "player:" .. n
    end
  end
  return table.concat(p, ",")
end

function CH.install(X)
  -- team_text names of a team (9 languages; empty when none): declared names, else its team_text row
  function X.team_text_names(t)
    local tid = X.tc:id_of(t)
    local m = X.meta[tid]
    if m and not T.is_empty(m.names) then return T.copy(m.names) end
    local name_id = TC.uint(X.tc:info(t), X.TI.NAME) or 0
    local out = {}
    if name_id == 0 then return out end
    for _, lang in ipairs(VRFW.lang.list()) do
      local names = X.nouns(lang, "team_text")
      if names and names[name_id] then out[lang] = names[name_id] end
    end
    return out
  end

  function X.chain_talk(m, what, t, talks)
    if t == nil then return "" end
    t = T.trim(t)
    if t == "" then return "" end
    local tk = t:find(".", 1, true) and t or (m .. "." .. t)
    for _, b in ipairs(talks) do
      if b.key == tk then return b.id end
    end
    VRFW.log.error(what .. ": talk `" .. t .. "` was not built (see its errors): none played there")
    return ""
  end

  -- chara_text names of a character (9 languages; empty when none)
  function X.chara_text_names(chara)
    local out = {}
    local b = X.ch.base[chara]
    if not b then return out end
    for _, lang in ipairs(VRFW.lang.list()) do
      local names = X.nouns(lang, "chara_text", true)
      if names and names[b.name_text] then out[lang] = names[b.name_text] end
    end
    return out
  end

  -- A `blocked` tile's `[[VRFW.Chain.Tile.Requires]]`: encoded list (`win:<team id>;chain:<key>;team_level:<n>;player:<card id>,...`) and each entry's name per language.
  -- `titles`: every declared chain's title by key.
  function X.chain_requires(m, tw, r, titles)
    local enc, names = {}, {}
    for k, q in ipairs(r or {}) do
      local rw = tw .. ": requirement " .. k
      local n = 0
      for _, f in ipairs({ "win", "chain", "team_level", "player" }) do
        if q[f] ~= nil then n = n + 1 end
      end
      if n ~= 1 then return nil, rw .. ": exactly one of `Win`, `Chain`, `TeamLevel`, `Player`" end
      if q.win ~= nil then
        local t, te = X.team_ref(q.win, m)
        if t == nil then return nil, rw .. ": " .. te end
        enc[#enc + 1] = "win:" .. T.d(X.tc:id_of(t))
        names[#names + 1] = X.team_text_names(t)
      elseif q.chain ~= nil then
        local c = T.trim(q.chain)
        local key = c:find(".", 1, true) and c or (m .. "." .. c)
        local title = titles[key]
        if title == nil then return nil, rw .. ": chain `" .. c .. "` is declared by no mod" end
        enc[#enc + 1] = "chain:" .. key
        names[#names + 1] = T.copy(title)
      elseif q.team_level ~= nil then
        enc[#enc + 1] = "team_level:" .. T.d(q.team_level)
        names[#names + 1] = {}
      else
        local card, pe = X.player_ref(q.player, nil, m)
        if not card then return nil, rw .. ": " .. pe end
        -- every card of the character counts
        local x = X.ch.card[card]
        local chara = x and x.chara or 0
        local cards = {}
        for _, c in ipairs(X.ch.cards[chara] or { card }) do cards[#cards + 1] = T.d(c) end
        enc[#enc + 1] = "player:" .. table.concat(cards, ",")
        names[#names + 1] = X.chara_text_names(chara)
      end
    end
    return table.concat(enc, ";"), names
  end

  -- A chest's `[[VRFW.Chain.Tile.Reward]]`s: `item:count` / `player:<card id>` (decimal), comma-separated; an unknown player refuses the chain.
  function X.chest_rewards(m, r)
    local out = {}
    for k, x in ipairs(r or {}) do
      if x.item ~= nil then
        local c = x.count or 1
        if c < 1 then c = 1 end
        out[#out + 1] = T.d(T.id(x.item)) .. ":" .. T.d(c)
      elseif x.player ~= nil then
        local card, pe = X.player_ref(x.player, nil, m)
        if not card then return nil, "reward " .. k .. ": " .. pe end
        out[#out + 1] = "player:" .. T.d(card)
      end
    end
    return table.concat(out, ",")
  end

  -- the kind (`emblem`, `kit`, `item`) and the item_text name per language of item `id` (no name: empty)
  function X.chain_item_info(id)
    local item = X.item()
    if not item then return "item", {} end
    local kind, list = "item", nil
    if item:find("ITEM_EMBLEM_INFO", X.EM.ID, id) ~= nil then
      kind, list = "emblem", "ITEM_EMBLEM_INFO"
    elseif item:find("ITEM_FASHION_INFO", 0, id) ~= nil then
      kind, list = "kit", "ITEM_FASHION_INFO"
    end
    local names = {}
    if list == nil then return kind, names end
    local i = item:find(list, 0, id)
    local ok, c = pcall(item.col, item, list, "name_text")
    local text = i and item:uint(i, (ok and c) or 2) or 0
    if text ~= 0 then
      for _, lang in ipairs(VRFW.lang.list()) do
        local nouns = X.nouns(lang, "item_text")
        if nouns and nouns[text] then names[lang] = nouns[text] end
      end
    end
    return kind, names
  end

  -- a match tile's rank rewards: `<rank>:<item id>:<count>:<kind>:<text id>,...` (decimal; text id = crc32 of `Text`,
  -- 0 = none) and each item's names; an entry whose `IfMod` is not active is left out; `Rival` resolved
  -- from the tile's team `tid` (its crest / the kit item of its uniform; none = the entry is left out, INFO)
  function X.chain_rank_rewards(what, list, tid)
    local enc, names = {}, {}
    for _, x in ipairs(list or {}) do
      local id, skip
      local req = x.if_mod ~= nil and T.trim(x.if_mod) or ""
      if req ~= "" then
        skip = true
        for _, md in ipairs(X.mods or {}) do if md.id == req then skip = false break end end
        if skip then VRFW.log.info(what .. ": rank " .. x.rank .. ": if_mod " .. req .. " is not active (left out)") end
      end
      if skip then
        -- left out
      elseif x.item ~= nil then
        id = T.id(x.item)
      else
        local ek, e = X.emblem_and_kit(tid)
        if not ek then return nil, e end
        if x.rival == "emblem" then
          if ek.emblem ~= 0 and X.emblem_exists(ek.emblem) then id = ek.emblem end
        else
          local kit = X.kit_item(ek.kit)
          if kit then id = kit end
        end
        if id == nil then
          VRFW.log.info(what .. ": rank " .. x.rank .. ": the rival has no " .. x.rival .. " item (nothing given for it)")
        end
      end
      if id ~= nil and id ~= 0 then
        local c = x.count or 1
        if c < 1 then c = 1 end
        local kind, nm = X.chain_item_info(id)
        local label = (x.text ~= nil and T.trim(x.text) ~= "") and VRFW.crc32(T.trim(x.text)) or 0
        enc[#enc + 1] = x.rank .. ":" .. T.d(id) .. ":" .. T.d(c) .. ":" .. kind .. ":" .. T.d(label)
        names[#names + 1] = nm
      end
    end
    return table.concat(enc, ","), names
  end

  -- the ordinary-profile copy of team `t` (made once): key `<key>_normal`, every member's stat rates (cols 20-27) 1 and
  -- cols 14-19 -1 (an ordinary team's values; the retail legend teams have rates 6-10); `t` itself when it has them
  function X.chain_normal_copy(t)
    local tc, TM = X.tc, X.TM
    local s, e = tc:member_range(t)
    local plain = true
    for i = s, e - 1 do
      local row = tc:member(i).m
      for k = 0, 7 do
        local v = row[TM.RATE + k + 1]
        if type(v) == "table" then v = v.float end
        if tonumber(v) ~= nil and tonumber(v) ~= 1 then plain = false end
      end
      for k = 0, 5 do
        local v = TC.int(row, TM.C14 + k)
        if v ~= nil and v ~= -1 then plain = false end
      end
    end
    if plain then return t end
    local key = tc:key_of(t) .. "_normal"
    local id = VRFW.crc32(key)
    local have = tc:find(id)
    if have ~= nil then return have end
    local rows = {}
    for i = s, e - 1 do
      local x = tc:member(i)
      local row = TC.copy_row(x.m)
      for k = 0, 5 do TC.set_int(row, TM.C14 + k, -1) end
      for k = 0, 7 do TC.set_int(row, TM.RATE + k, 1) end
      rows[#rows + 1] = { m = row, r = TC.copy_row(x.r) }
    end
    local src = tc:id_of(t)
    local info, refs = tc:team_copy(t)
    TC.set_int(info, X.TI.ID, id)
    info[X.TI.KEY + 1] = key
    tc:push_team(info, refs)
    local nt = #tc.teams - 1
    local start = #tc.members
    for _, r in ipairs(rows) do tc.members[#tc.members + 1] = r end
    tc:set_slice(nt, 0, start, #rows)
    local m = X.meta[src]
    if m then
      X.meta[id] = { stadium = m.stadium, stadium_fallback = m.stadium_fallback, stadium_image = m.stadium_image, music = m.music, ai = m.ai, rules = m.rules, series = m.series, names = T.copy(m.names),
        short = T.copy(m.short), default_lang = m.default_lang }
    end
    VRFW.log.info("chain rival " .. key .. ": copy of " .. X.label(t) .. " with the ordinary stat profile (rates 1, cols 14-19 -1)")
    return nt
  end

  -- every mod's `[[VRFW.Chain]]` (load order)
  function X.chains(files, talks)
    local out = {}
    -- every declared chain's title by key
    local titles = {}
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.Chain or {}) do
        local k = VRFW.ids.own(f.mod, d.name)
        if k then titles[k] = norm(d.title) end
      end
    end
    for _, f in ipairs(files) do
      for _, d in ipairs(f.value.vrfw.Chain or {}) do
        local key, e = VRFW.ids.own(f.mod, d.name)
        if not key then
          VRFW.log.error(f.file .. ": chain `" .. d.name .. "`: " .. e .. " (skipped)")
        else
          local what = f.file .. ": chain " .. key
          local dup = false
          for _, c in ipairs(out) do if c.key == key then dup = true break end end
          if dup then
            VRFW.log.error(what .. ": declared twice (the second is skipped)")
          else
            local c, err = X.chain(f.mod, what, key, d, talks, titles)
            if c then
              VRFW.log.info(string.format("%s: %d node(s), host `%s`, pachanga `%s`", what, #c.nodes, c.host, c.pachanga))
              out[#out + 1] = c
            else
              VRFW.log.error(what .. ": " .. err .. " (skipped)")
            end
          end
        end
      end
    end
    return out
  end

  function X.chain(m, what, key, d, talks, titles)
    local name = T.last_part(key, ".")
    if not valid_name(name) then
      return nil, "name `" .. name .. "`: a-z 0-9 _, at most 16 characters (its games are evt_ch_<name>_<NN>)"
    end
    local nodes, tiles = d.node or {}, d.tile or {}
    if #nodes == 0 and #tiles == 0 then return nil, "no [[vrfw.Chain.Node]] nor [[vrfw.Chain.Tile]]" end
    if #nodes > 0 and #tiles > 0 then
      return nil, "[[vrfw.Chain.Node]] (a free-walk chain) and [[vrfw.Chain.Tile]] (a chain board) in one chain: use one of the two"
    end
    if #nodes > MAX_NODES then return nil, string.format("%d nodes (at most %d)", #nodes, MAX_NODES) end
    local tpl = d.template_game
    if tpl == nil then
      tpl = X.D.chain_template
      if tpl == nil then return nil, X.D.chain_template_err end
    end
    local g, ge = X.games()
    if not g then return nil, ge end
    local tg = X.gcache().by_name[tpl]
    if not tg then return nil, "template game `" .. tpl .. "` is not in soccer_game_config" end
    local tpl_rows = {}
    for _, i in ipairs(X.grows(tg)) do
      local x = g:int(i, X.SG.D_DIFF)
      if x then tpl_rows[#tpl_rows + 1] = x end
    end
    local top
    for _, x in ipairs(tpl_rows) do if top == nil or x > top then top = x end end
    if top == nil then return nil, "template game `" .. tpl .. "` has no difficulty row" end
    local pach = d.pachanga
    if pach == nil or T.trim(pach) == "" then pach = CHAIN_PACHANGA end
    local c = { key = key, mod_id = m, title = norm(d.title), host = d.host or "", pachanga = pach, intro = "", outro = "", done = "", nodes = {} }
    c.intro = X.chain_talk(m, what, d.intro, talks)
    c.outro = X.chain_talk(m, what, d.outro, talks)
    c.done = X.chain_talk(m, what, d.done, talks)
    local names, ne = X.game_names()
    if not names then return nil, ne end
    local tref = { name = tpl, rows = tpl_rows, top = top, difficulty = d.difficulty, stadium = d.stadium }
    local rsok, rse = check_rival_stats(d.rival_stats)
    if not rsok then return nil, rse end
    local rrok, rre = check_rank_rewards(d.rank_reward)
    if not rrok then return nil, "[[VRFW.Chain.RankReward]]: " .. rre end
    if #tiles > 0 then
      local b, be = X.chain_board(m, what, name, d, tref, names, titles)
      if not b then return nil, be end
      c.board = b
      return c
    end
    for i, n in ipairs(nodes) do
      local nw = what .. ": node " .. i
      local ok, re = check_rewards(n.reward, false)
      if not ok then return nil, "node " .. i .. ": " .. re end
      local game_key = string.format("evt_ch_%s_%02d", name, i)
      local spec = { team = n.team, level = n.level, difficulty = n.difficulty, stadium = n.stadium, title = n.title or {}, reward = n.reward or {}, rival_stats = d.rival_stats }
      local node, err = X.chain_match(m, nw, game_key, spec, tref, names)
      if not node then return nil, "node " .. i .. ": " .. err end
      node.talk_before = X.chain_talk(m, nw, n.talk_before, talks)
      node.talk_after = X.chain_talk(m, nw, n.talk_after, talks)
      c.nodes[#c.nodes + 1] = node
    end
    return c
  end

  -- One match of a chain: game `game_key` = every row of the template against the team at the level, with its stadium and title.
  function X.chain_match(m, nw, game_key, n, tpl, names)
    if names[game_key] then return nil, "game " .. game_key .. " already exists" end
    local t, te = X.team_ref(n.team, m)
    if t == nil then return nil, te end
    local diff = n.difficulty
    if diff == nil then diff = tpl.difficulty end
    if diff == nil then diff = tpl.top end
    -- a difficulty that does not exist with the active mods is never built
    if not X.diffs.exists("chain", diff < 0 and 0 or diff) then
      return nil, string.format("difficulty %d does not exist with the active mods (chain: %s; defaults\\match_difficulty.toml)", diff, X.diffs.ids_text("chain"))
    end
    if not T.contains(tpl.rows, diff) then
      return nil, string.format("the template `%s` has no difficulty-%d row (rows %s)", tpl.name, diff, T.dbg_list(tpl.rows))
    end
    -- `RivalStats = "normal"`: the match plays the team's ordinary-profile copy (the tile keeps the team itself)
    local play = t
    if n.rival_stats == "normal" then
      local c, cpe = X.chain_normal_copy(t)
      if c == nil then return nil, cpe end
      play = c
    end
    local gid, ce = X.clone_game(m, nw, play, tpl.name, game_key, n.level, false, true)
    if not gid then return nil, ce end
    -- the clone copies the template's per-game scripts; a chain game has none
    VRFW.team.files_drop(GAME_DIR .. game_key .. "_", nil)
    local g = X.games_t
    local SG = X.SG
    local x = X.gcache().by_id[gid]
    if not x then return nil, "game gone" end
    local st = n.stadium or tpl.stadium
    if st ~= nil and T.trim(st) ~= "" then g:set(x.info, SG.G_STADIUM, T.i32(map_id(st))) end
    local level = 0
    for _, i in ipairs(X.grows(x)) do
      if g:int(i, SG.D_DIFF) == diff then
        level = g:int(i, SG.D_LEVEL) or 0
        if level < 0 then level = 0 end
        break
      end
    end
    local title = norm(n.title)
    if not T.is_empty(title) then
      local tid = VRFW.crc32(game_key .. "_title")
      g:set(x.info, SG.G_TITLE, T.i32(tid))
      X.push_text(m, nil, { table = "soccer_game_title", id = tid, variant = 0, texts = title, add = true, origin = nw .. ": title" })
    end
    g:touch()
    X.touched.games = true
    local rival = X.team_text_names(t)
    VRFW.log.info(string.format("%s: game %s (%s) vs %s level %d difficulty %d", nw, game_key, T.hex(gid), X.label(t), level, diff))
    return { game = gid, game_key = game_key, team = X.tc:id_of(t), level = level, difficulty = diff, title = title, rival = rival,
      talk_before = "", talk_after = "", reward = rewards(n.reward) }
  end

  -- emblem file key (`em030050`) of team id `tid`, "" when none
  function X.team_emblem_key(tid)
    local t = X.tc:find(tid)
    if t == nil then return "" end
    local emblem = TC.uint(X.tc:info(t), X.TI.EMBLEM) or 0
    if emblem == 0 then return "" end
    local item = X.item()
    if not item then return "" end
    local i = item:find("ITEM_EMBLEM_INFO", X.EM.ID, emblem)
    return i and item:str(i, X.EM.KEY) or ""
  end

  -- a chain board: tiles checked (ids, grid, one start, links), match games built in tile order
  function X.chain_board(m, what, name, d, tpl, names, titles)
    local b = d.board
    if b == nil then return nil, "[[vrfw.Chain.Tile]] needs [vrfw.Chain.Board] cols / rows" end
    local layout = b.layout and T.trim(b.layout) or "square"
    local hex
    if layout == "square" or layout == "" then hex = false
    elseif layout == "hex" then hex = true
    else return nil, "[vrfw.Chain.Board] Layout = \"" .. layout .. "\": \"square\" or \"hex\"" end
    local max_cols = hex and MAX_HEX_COLS or MAX_BOARD_COLS
    if not (b.cols >= 1 and b.cols <= max_cols) or not (b.rows >= 1 and b.rows <= MAX_BOARD_ROWS) then
      return nil, string.format("[vrfw.Chain.Board] %d x %d: cols 1..=%d, rows 1..=%d", b.cols, b.rows, max_cols, MAX_BOARD_ROWS)
    end
    local tiles = d.tile
    local used_pages = 1
    for k, t in ipairs(tiles) do
      local p = t.page or 1
      if k == 1 or p > used_pages then used_pages = p end
    end
    local pages = math.max(#(d.page or {}), used_pages)
    if pages > MAX_BOARD_PAGES then return nil, string.format("%d pages (at most %d)", pages, MAX_BOARD_PAGES) end
    -- ids, kinds, positions
    local ids, cells = {}, {}
    local start
    for i, t in ipairs(tiles) do
      local tw = "tile `" .. t.id .. "`"
      if not valid_name(t.id) then return nil, tw .. ": id a-z 0-9 _, at most 16 characters" end
      if ids[t.id] ~= nil then return nil, tw .. ": declared twice" end
      ids[t.id] = i - 1
      local page = t.page or 1
      if page < 1 or page > pages then return nil, string.format("%s: page %d (pages 1..=%d)", tw, page, pages) end
      local col, row = t.pos[1], t.pos[2]
      if col < 1 or col > b.cols or row < 1 or row > b.rows then
        return nil, string.format("%s: pos [%d, %d] outside the %d x %d grid (1-based [column, row])", tw, col, row, b.cols, b.rows)
      end
      local ck = page .. ":" .. col .. ":" .. row
      if cells[ck] then return nil, string.format("%s: page %d [%d, %d] already has a tile", tw, page, col, row) end
      cells[ck] = true
      if t.kind == "start" then
        if start ~= nil then return nil, "more than one `start` tile" end
        start = i - 1
      elseif t.kind == "match" then
        if T.trim(t.team or "") == "" then return nil, tw .. ": a match tile needs `team`" end
        local ok, re = check_rewards(t.reward, false)
        if not ok then return nil, tw .. ": " .. re .. " (a match tile's rewards are items)" end
        ok, re = check_rival_stats(t.rival_stats)
        if not ok then return nil, tw .. ": " .. re end
        ok, re = check_rank_rewards(t.rank_reward)
        if not ok then return nil, tw .. ": RankReward: " .. re end
      elseif t.kind == "chest" or t.kind == "schest" then
        local ok, re = check_rewards(t.reward, true)
        if not ok then return nil, tw .. ": " .. re end
      elseif t.kind == "dchest" then
        local ok, re = check_rewards(t.reward, true)
        if not ok then return nil, tw .. ": " .. re end
        ok, re = check_rewards(t.s_reward, true)
        if not ok then return nil, tw .. ": SReward: " .. re end
      elseif t.kind == "blocked" then
        if #(t.requires or {}) == 0 then return nil, tw .. ": a blocked tile needs [[VRFW.Chain.Tile.Requires]]" end
      end
      if t.kind ~= "blocked" and #(t.requires or {}) > 0 then
        VRFW.log.warn(what .. ": " .. tw .. ": `requires` only applies to blocked tiles (ignored)")
      end
      if t.kind ~= "match" and (t.team ~= nil or t.level ~= nil) then
        VRFW.log.warn(what .. ": " .. tw .. ": `team` / `level` only apply to match tiles (ignored)")
      end
      if not (t.kind == "chest" or t.kind == "schest" or t.kind == "dchest" or t.kind == "match") and #(t.reward or {}) > 0 then
        VRFW.log.warn(what .. ": " .. tw .. ": `reward` only applies to chest and match tiles (ignored)")
      end
      if t.kind ~= "match" and (#(t.rank_reward or {}) > 0 or t.rival_stats ~= nil) then
        VRFW.log.warn(what .. ": " .. tw .. ": `RankReward` / `RivalStats` only apply to match tiles (ignored)")
      end
      if t.kind ~= "dchest" and #(t.s_reward or {}) > 0 then
        VRFW.log.warn(what .. ": " .. tw .. ": `SReward` only applies to double chests (Kind = \"dchest\") (ignored)")
      end
    end
    if start == nil then return nil, "no `start` tile" end
  -- links: both ways, on one page or to the next / previous page
    local links = {}
    for i = 1, #tiles do links[i] = {} end
    for i, t in ipairs(tiles) do
      for _, l in ipairs(t.links or {}) do
        local j = ids[T.trim(l)]
        if j == nil then return nil, "tile `" .. t.id .. "`: link `" .. l .. "` is no tile of this chain" end
        j = j + 1
        if j == i then return nil, "tile `" .. t.id .. "`: links to itself" end
        local u, v = tiles[i], tiles[j]
        local pu, pv = u.page or 1, v.page or 1
        if math.abs(pu - pv) > 1 then
          return nil, "link `" .. u.id .. "` - `" .. v.id .. "`: a link may only join the same page or the next / previous page"
        end
        if hex then
          -- hex neighbours: same column one row apart, or the next / previous column on a half-row step
          local function half(p) return 2 * p[2] + ((p[1] % 2 == 0) and 1 or 0) end
          local dc, dr = u.pos[1] - v.pos[1], half(u.pos) - half(v.pos)
          local adjacent = pu == pv and ((dc == 0 and math.abs(dr) == 2) or (math.abs(dc) == 1 and math.abs(dr) == 1))
          if not adjacent and not links[i][j - 1] then
            VRFW.log.warn(what .. ": link `" .. u.id .. "` - `" .. v.id .. "` joins no hex neighbours: drawn as a straight bar anyway")
          end
        else
          local straight
          if pu == pv then straight = u.pos[1] == v.pos[1] or u.pos[2] == v.pos[2] else straight = u.pos[2] == v.pos[2] end
          if not straight and not links[i][j - 1] then
            VRFW.log.info(what .. ": link `" .. u.id .. "` - `" .. v.id .. "` is not straight: drawn diagonally")
          end
        end
        links[i][j - 1] = true
        links[j][i - 1] = true
      end
    end
    -- every tile reachable from the start (else it can never open)
    local seen = { [start] = true }
    local todo = { start }
    while #todo > 0 do
      local i = table.remove(todo)
      for _, j in ipairs(T.keys(links[i + 1])) do
        if not seen[j] then
          seen[j] = true
          todo[#todo + 1] = j
        end
      end
    end
    for i, t in ipairs(tiles) do
      if not seen[i - 1] then VRFW.log.warn(what .. ": tile `" .. t.id .. "` is not linked to the start (it never opens)") end
    end
    local out = { cols = b.cols, rows = b.rows, layout = hex and "hex" or "square", pages = {}, start = start, tiles = {} }
    for p = 1, pages do
      local pg = (d.page or {})[p]
      out.pages[p] = pg and norm(pg.title) or {}
    end
    local nmatch = 0
    for i, t in ipairs(tiles) do
      local tb = { id = t.id, kind = t.kind, page = (t.page or 1) - 1, col = t.pos[1] - 1, row = t.pos[2] - 1, links = T.keys(links[i]),
        game = 0, game_key = "", team = 0, level = 0, difficulty = 0, title = {}, rival = {}, emblem = "", reward = "",
        s_reward = "", requires = "", requires_names = {}, rank_reward = "", rank_reward_names = {} }
      if t.kind == "match" then
        nmatch = nmatch + 1
        if nmatch > MAX_NODES then return nil, string.format("more than %d match tiles", MAX_NODES) end
        local tw = what .. ": tile " .. t.id
        local game_key = string.format("evt_ch_%s_%02d", name, nmatch)
        local spec = { team = t.team or "", level = t.level, difficulty = t.difficulty, stadium = t.stadium, title = t.title or {}, reward = {},
          rival_stats = t.rival_stats or d.rival_stats }
        local n, err = X.chain_match(m, tw, game_key, spec, tpl, names)
        if not n then return nil, "tile `" .. t.id .. "`: " .. err end
        tb.emblem = X.team_emblem_key(n.team)
        tb.game, tb.game_key, tb.team, tb.level, tb.difficulty = n.game, n.game_key, n.team, n.level, n.difficulty
        tb.title, tb.rival = n.title, n.rival
        -- the first win at each rank: the tile's own rank rewards, else the chain's
        local rr = (#(t.rank_reward or {}) > 0) and t.rank_reward or (d.rank_reward or {})
        if #rr > 0 then
          local enc, rn = X.chain_rank_rewards(tw, rr, n.team)
          if not enc then return nil, "tile `" .. t.id .. "`: RankReward: " .. rn end
          tb.rank_reward, tb.rank_reward_names = enc, rn
          if enc ~= "" then
            VRFW.log.info(what .. ": match `" .. t.id .. "`: the first win at each rank gives " .. enc .. " (once per rank)")
          end
        end
        if #(t.reward or {}) > 0 then
          -- the tile's rewards: a new win prize table (col 8) on every row of its game; bean / first-clear prizes cleared
          local items = {}
          for _, x in ipairs(t.reward) do items[#items + 1] = { T.id(x.item), x.count or 1 } end
          local nid, pe = X.new_prize(items, tb.game_key .. "_win")
          if not nid then return nil, "tile `" .. t.id .. "`: reward: " .. pe end
          local g, SG = X.games_t, X.SG
          local x = X.gcache().by_id[tb.game]
          if not x then return nil, "tile `" .. t.id .. "`: game gone" end
          for _, i in ipairs(X.grows(x)) do
            g:set(i, D_WIN_PRIZE, T.i32(nid))
            for _, c in ipairs(D_BEAN_PRIZES) do g:set(i, c, 0) end
            g:set(i, D_FIRST_CLEAR_PRIZE, 0)
          end
          g:touch()
          X.touched.games = true
          VRFW.log.info(what .. ": match `" .. t.id .. "`: every win gives " .. rewards(t.reward) .. " at the end of the match (win prize; no other prize)")
        end
      elseif t.kind == "blocked" then
        local enc, rn = X.chain_requires(m, "tile `" .. t.id .. "`", t.requires, titles)
        if not enc then return nil, rn end
        VRFW.log.info(what .. ": blocked tile `" .. t.id .. "`: opens once " .. enc)
        tb.requires, tb.requires_names = enc, rn
      elseif t.kind == "chest" or t.kind == "schest" then
        local enc, re = X.chest_rewards(m, t.reward)
        if not enc then return nil, "tile `" .. t.id .. "`: " .. re end
        tb.reward = enc
        if #(t.reward or {}) > 0 then
          VRFW.log.info(what .. ": chest `" .. t.id .. "`: gives " .. enc .. " once opened")
        end
      elseif t.kind == "dchest" then
        -- double chest: base reward, then the special one with rank S on its branch
        local enc, re = X.chest_rewards(m, t.reward)
        if not enc then return nil, "tile `" .. t.id .. "`: " .. re end
        local senc, se = X.chest_rewards(m, t.s_reward)
        if not senc then return nil, "tile `" .. t.id .. "`: SReward: " .. se end
        tb.reward, tb.s_reward = enc, senc
        if enc == "" and senc == "" then
          VRFW.log.info(what .. ": double chest `" .. t.id .. "`: no reward declared: disabled (never opens)")
        else
          VRFW.log.info(what .. ": double chest `" .. t.id .. "`: base [" .. enc .. "], rank S [" .. senc .. "]")
        end
      end
      out.tiles[#out.tiles + 1] = tb
    end
    VRFW.log.info(string.format("%s: board %d x %d, %d page(s), %d tile(s) (%d match(es)), start `%s`", what, b.cols, b.rows, pages, #tiles, nmatch, tiles[start + 1].id))
    return out
  end
end

return CH
