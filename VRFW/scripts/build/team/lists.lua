-- Lists a team appears in: soccer_game_config games (cache kept in step with this build), cloned games and match music,
-- soccer_opponent_info rows, Chronicle piece event rows, pool tables, the character shop, the Estadio BB grid, list orders and removals.
-- Positions are 0-based; functions return `nil, err` on failure.
local T = require "lib/team_util"
local TC = require "team/tc"
local L = {}

local GAME_DIR = "data/common/gamedata/soccer/game/"
L.GAME_DIR = GAME_DIR
local LIST_FREE, LIST_BB = "free_match", "bb_stadium"
L.LIST_FREE, L.LIST_BB = LIST_FREE, LIST_BB
local ENJOY_ROW = "ENJOY_MODE_TEAM_INFO"
L.ENJOY_ROW = ENJOY_ROW
local INFO, REF, DIFF = "SOCCER_GAME_INFO", "SOCCER_GAME_INFO_REF_DIFFICULTY", "SOCCER_GAME_DIFFICULTY"
local POS_GK = 1
local SLOT_COACH = 19

-- binary search: the number of entries of sorted array `a` below `x`
local function below(a, x)
  local lo, hi = 1, #a + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if a[mid] < x then lo = mid + 1 else hi = mid end
  end
  return lo - 1
end

-- shift every position >= p of sorted array `a` by n
local function shift(a, p, n)
  for i = below(a, p) + 1, #a do a[i] = a[i] + n end
end

function L.install(X)
  local TI, TM = X.TI, X.TM

  -- ------------------------------------------------------------------------------------------------ the games

  -- columns of soccer_game_config (fallback numbers when a schema lacks the name)
  function X.sg_columns(t)
    local function c(row, name, n)
      local ok, x = pcall(t.col, t, row, name)
      if ok and x then return x end
      return n
    end
    return {
      G_ID = c(INFO, "id", 0), G_NAME = c(INFO, "name", 1), G_TYPE = c(INFO, "game_type", 2), G_STADIUM = c(INFO, "stadium_map", 3), G_TITLE = c(INFO, "title_text", 4),
      D_DIFF = c(DIFF, "difficulty", 0), D_TEAM = c(DIFF, "opponent_team", 1), D_LEVEL = c(DIFF, "opponent_level", 2),
      D_AI = c(DIFF, "ai_level", 3), D_AI_DATA = c(DIFF, "opponent_ai", 4), D_OWN_TEAM = c(DIFF, "own_team_override", 5),
      D_OWN_LEVEL = c(DIFF, "own_team_level", 6), D_WIN = c(DIFF, "reward_table", 8), D_BGM = c(DIFF, "bgm_setting", 18),
      D_CASTER = c(DIFF, "caster_setting", 19), D_RULES = c(DIFF, "special_rules", 24), D_QUEST = c(DIFF, "game_quest", 25),
      D_QUEST_2 = c(DIFF, "game_quest_2", 26), D_SPIRIT_DROP = c(DIFF, "spirit_chara_table", 29),
      D_ITEM_DROP = c(DIFF, "item_drop_table", 30), D_SPIRIT_TABLE = c(DIFF, "spirit_drop_table", 31),
      D_SPIRIT_TABLE_2 = c(DIFF, "spirit_drop_table_2", 33), D_FIRST_CLEAR = c(DIFF, "first_clear_reward", 34),
      D_DECIDE = c(DIFF, "item_table_decide", 36),
      D_CLEAR_BIT = c(DIFF, "sort_no", 35), D_BGM_OVERRIDE = c(DIFF, "bgm_override", 49),
    }
  end

  -- every game of soccer_game_config: `{ info, name, id, s, n }` in table order (an info row followed by its REF_DIFFICULTY row)
  function X.gcache()
    if X.G then return X.G end
    local t = assert(X.games())
    local SG = X.SG
    local G = { diffs = t:rows(DIFF), infos = t:rows(INFO), refs = t:rows(REF), list = {}, by_name = {}, by_id = {}, names = {} }
    local is_ref = {}
    for _, i in ipairs(G.refs) do is_ref[i] = true end
    for _, i in ipairs(G.infos) do
      if is_ref[i + 1] then
        local s, n = t:int(i + 1, 0) or 0, t:int(i + 1, 1) or 0
        if s < 0 then s = 0 end
        if n < 0 then n = 0 end
        local g = { info = i, name = t:str(i, SG.G_NAME) or "", id = t:uint(i, SG.G_ID) or 0, s = s, n = n }
        G.list[#G.list + 1] = g
        if G.by_name[g.name] == nil then G.by_name[g.name] = g end
        if G.by_id[g.id] == nil then G.by_id[g.id] = g end
        G.names[g.name] = true
      end
    end
    X.G = G
    return G
  end

  -- the entry positions of game `g`'s difficulty rows
  function X.grows(g)
    local d = X.G.diffs
    local out = {}
    for k = g.s + 1, math.min(g.s + g.n, #d) do out[#out + 1] = d[k] end
    return out
  end

  -- every game (the cache's list; read-only)
  function X.games_list()
    return X.gcache().list
  end

  function X.game_names()
    local t, e = X.games()
    if not t then return nil, e end
    return X.gcache().names
  end

  -- `t:append_rows` on the games table with the cache kept in step: `names` = row names of `list`, `entries` the new entries, `n` the rows; true or nil, err
  function X.g_append(list, names, entries, n)
    local t = X.games_t
    local G = X.gcache()
    local b, e, err = t:list(list)
    if not b then return nil, err end
    -- where append_rows inserts: after the list's last entry named in `names`
    local last = b
    local function last_in(a)
      local k = below(a, e)
      if k >= 1 and a[k] > b and a[k] > last then last = a[k] end
    end
    if list == DIFF then
      last_in(G.diffs)
    else
      last_in(G.infos)
      last_in(G.refs)
    end
    local at = last + 1
    local ok, e2 = pcall(t.append_rows, t, list, names, entries, n)
    if not ok then return nil, tostring(e2) end
    local cnt = #entries
    shift(G.diffs, at, cnt)
    shift(G.infos, at, cnt)
    shift(G.refs, at, cnt)
    for _, g in ipairs(G.list) do
      if g.info >= at then g.info = g.info + cnt end
    end
    if list == DIFF then
      local k = below(G.diffs, at)
      for j = cnt, 1, -1 do table.insert(G.diffs, k + 1, at + j - 1) end
    else
      -- the new games (INFO + REF pairs)
      for j = 0, cnt - 1, 2 do
        local p = at + j
        table.insert(G.infos, below(G.infos, p) + 1, p)
        table.insert(G.refs, below(G.refs, p + 1) + 1, p + 1)
        local info, ref = entries[j + 1], entries[j + 2]
        local nm = info.values[X.SG.G_NAME + 1]
        local id = info.values[X.SG.G_ID + 1]
        local s, nn = ref.values[1] or 0, ref.values[2] or 0
        if s < 0 then s = 0 end
        if nn < 0 then nn = 0 end
        local g = { info = p, name = type(nm) == "string" and nm or "", id = type(id) == "number" and T.u32(id) or 0, s = s, n = nn }
        local pos = #G.list + 1
        for k, x in ipairs(G.list) do
          if x.info > p then pos = k break end
        end
        table.insert(G.list, pos, g)
        local cur = G.by_name[g.name]
        if cur == nil or cur.info > p then G.by_name[g.name] = g end
        cur = G.by_id[g.id]
        if cur == nil or cur.info > p then G.by_id[g.id] = g end
        G.names[g.name] = true
      end
    end
    return true
  end

  -- a game's REF_DIFFICULTY slice changed in place (the entry after its info row)
  function X.g_set_slice(g, s, n)
    local t = X.games_t
    t:splice(g.info + 1, g.info + 2, { (function()
      local r = t:entry(g.info + 1)
      r.values = { s, n }
      return r
    end)() })
    g.s, g.n = s, n
  end

  -- add a game: `info` (id / name set) and its difficulty rows
  function X.add_game(info, rows)
    local G = X.gcache()
    local t = X.games_t
    local start = #G.diffs
    local n = #rows
    if #G.refs == 0 then return nil, "soccer_game_config: no REF_DIFFICULTY row" end
    local r = t:entry(G.refs[1])
    local ok, e = X.g_append(DIFF, { DIFF }, rows, n)
    if not ok then return nil, e end
    r.values = { start, n }
    return X.g_append(INFO, { INFO, REF }, { info, r }, 1)
  end

  -- ------------------------------------------------------------------------------------------------ match music

  -- the soccer_game_bgm_config info row of team `tid`'s match music `bgm` (made on first use, shared by its games)
  function X.team_bgm(tid, bgm, tpl_info)
    if X.bgm_rows[tid] then return X.bgm_rows[tid] end
    local D = X.D
    local info_id = VRFW.crc32(string.format("evt_team_%08x_bgm", tid))
    local set_id = VRFW.crc32(string.format("evt_team_%08x_bgmset", tid))
    local r, e = X.sgbgm()
    if not r then return nil, e end
    local il, e1 = r:list("m_SoccerGameBgmInfoList")
    if not il then return nil, e1 end
    local sl, e2 = r:list("m_SoccerGameBgmSetInfoList")
    if not sl then return nil, e2 end
    local pl = {}
    for k, n in ipairs(D.bgm.phases) do
      local l, e3 = r:list(n)
      if not l then return nil, e3 end
      pl[k] = l
    end
    local n_info = r:len(il)
    for i = 0, n_info - 1 do
      if r:u32(il, i, 0) == info_id then return nil, "soccer_game_bgm_config already has the rows of team " .. T.hex(tid) end
    end
    for i = 0, r:len(sl) - 1 do
      if r:u32(sl, i, 0) == set_id then return nil, "soccer_game_bgm_config already has the rows of team " .. T.hex(tid) end
    end
    local function has_phase(i)
      local _, n = r:tuple(il, i, 5)
      return n ~= nil and n > 0
    end
    local tpl
    for i = 0, n_info - 1 do
      if r:u32(il, i, 0) == tpl_info and has_phase(i) then tpl = i break end
    end
    if tpl == nil then
      for i = 0, n_info - 1 do
        if has_phase(i) then tpl = i break end
      end
    end
    if tpl == nil then return nil, "soccer_game_bgm_config: no info row to copy" end
    local base_set
    do
      local s = r:tuple(il, tpl, 5)
      if s ~= nil then base_set = r:u32(pl[1], s, 0) end
    end
    local base_row
    if base_set ~= nil then
      for i = 0, r:len(sl) - 1 do
        if r:u32(sl, i, 0) == base_set then base_row = i break end
      end
    end
    -- the set
    if r:len(sl) == 0 then return nil, "soccer_game_bgm_config: no set row" end
    local set = r:copy(sl, 0)
    r:set_u32(-1, set, 0, set_id)
    r:set_u32(-1, set, 1, 0)
    local kept = {}
    for k, slot in ipairs(D.bgm.kept_slots) do
      kept[k] = base_row ~= nil and r:u32(sl, base_row, 2, slot) or nil
    end
    local nslots = r:nvals(-1, set, 2)
    if nslots == nil then return nil, "soccer_game_bgm_config: a set without its slots" end
    if nslots <= D.bgm.kept_slots[2] then
      return nil, string.format("soccer_game_bgm_config: a set has %d slots (22 expected)", nslots)
    end
    for k = 0, nslots - 1 do r:set_u32(-1, set, 2, 0, k) end
    r:set_u32(-1, set, 2, bgm, D.bgm.start_slot)
    for k, slot in ipairs(D.bgm.kept_slots) do r:set_u32(-1, set, 2, kept[k] or 0, slot) end
    -- one entry per phase list, then the info row on them
    local info = r:copy(il, tpl)
    r:set_u32(-1, info, 0, info_id)
    for k, l in ipairs(pl) do
      if r:len(l) == 0 then return nil, "soccer_game_bgm_config: an empty phase list" end
      local e4 = r:copy(l, 0)
      r:set_u32(-1, e4, 0, set_id)
      local start = r:len(l)
      if start > 32767 then return nil, "soccer_game_bgm_config: a phase list is full" end
      r:push(l, e4)
      r:set_tuple(-1, info, 5 + k - 1, start, 1)
    end
    -- v2 mode off (cols 8 / 9 flags, 10-14 its set ids)
    for c = 8, 14 do r:set_u32(-1, info, c, 0) end
    r:push(sl, set)
    r:push(il, info)
    r:touch()
    X.touched.sgbgm = true
    X.bgm_rows[tid] = info_id
    return info_id
  end

  -- ------------------------------------------------------------------------------------------------ games of lists

  -- a new game against team `t`: `template` cloned (only difficulty 9 when `only9`; `ladder` = one level per row), with rival / level / AI / stadium / title set,
  -- no clear bit, no win table of its own (unless `keep_win`); the template's per-game files are copied renamed
  function X.clone_game(m, what, t, template, name, level, only9, keep_win, ladder)
    ladder = ladder or {}
    local tid = X.tc:id_of(t)
    local meta = X.meta[tid] or X.new_meta()
    local g, e = X.games()
    if not g then return nil, e end
    local SG = X.SG
    local G = X.gcache()
    local tg = G.by_name[template]
    if not tg then return nil, "template game `" .. template .. "` is not in soccer_game_config" end
    local gid = VRFW.crc32(name)
    if G.by_id[gid] then return nil, "game id of `" .. name .. "` already used" end
    local rows = {}
    for _, i in ipairs(X.grows(tg)) do
      local en = g:entry(i)
      if not only9 or TC.int(en.values, SG.D_DIFF) == 9 then rows[#rows + 1] = en end
    end
    if #rows == 0 then
      return nil, "template game `" .. template .. "` has no difficulty-9 row (the only one the free-match flow plays)"
    end
    for _, r in ipairs(rows) do
      local v = r.values
      TC.set_int(v, SG.D_TEAM, tid)
      if level ~= nil then TC.set_int(v, SG.D_LEVEL, level) end
      if meta.ai ~= nil then TC.set_int(v, SG.D_AI, meta.ai) end
      if not keep_win then TC.set_int(v, SG.D_WIN, 0) end
      TC.set_int(v, SG.D_CLEAR_BIT, 0)
    end
    if #ladder > 0 then
      local n = #rows
      local out = {}
      for k, lv in ipairs(ladder) do
        local src = rows[math.min(math.floor((k - 1) * n / #ladder), n - 1) + 1]
        local r = { name = src.name, hash = src.hash, values = TC.copy_row(src.values) }
        TC.set_int(r.values, SG.D_DIFF, k)
        TC.set_int(r.values, SG.D_LEVEL, T.clamp(lv, 1, 999))
        out[k] = r
      end
      rows = out
    end
    local info = g:entry(tg.info)
    TC.set_int(info.values, SG.G_ID, gid)
    info.values[SG.G_NAME + 1] = name
    local home = meta.stadium
    if home == nil and meta.stadium_fallback ~= nil then home = X.home_stadium(tid) end
    if home ~= nil then TC.set_int(info.values, SG.G_STADIUM, home) end
    -- the team's match music: its own BGM info row on every difficulty row (col 18; the override col 49 off)
    if meta.music ~= nil then
      local tpl = TC.uint(rows[1].values, SG.D_BGM) or 0
      local bid, e2 = X.team_bgm(tid, meta.music, tpl)
      if bid then
        for _, r in ipairs(rows) do
          TC.set_int(r.values, SG.D_BGM, bid)
          TC.set_int(r.values, SG.D_BGM_OVERRIDE, 0)
        end
      else
        VRFW.log.warn(what .. ": music: " .. e2 .. " (the game's music is kept)")
      end
    end
    if not T.is_empty(meta.names) then
      local title = VRFW.crc32(name .. "_title")
      TC.set_int(info.values, SG.G_TITLE, title)
      X.push_text(m, meta.default_lang, { table = "soccer_game_title", id = title, variant = 0, texts = T.copy(meta.names), add = true,
        origin = what .. ": game " .. name .. " (" .. m .. ")" })
    end
    local ok, e3 = X.add_game(info, rows)
    if not ok then return nil, e3 end
    X.touched.games = true
    -- per-game files of the template (<template>_trigger_…, _phase_set…), renamed; a Lua text names the game
    local nf, e4 = VRFW.team.files_copy(GAME_DIR .. template .. "_", GAME_DIR .. name .. "_", template, name)
    if not nf then return nil, e4 end
    return gid
  end

  function X.game_key_for(prefix, reg_key)
    local names, e = X.game_names()
    if not names then return nil, e end
    local n = VRFW.team.assign(reg_key, function(i)
      return names[prefix .. T.pad(i % 1000000, 6)] ~= nil
    end)
    return prefix .. T.pad(n % 1000000, 6)
  end

  -- `soccer_opponent_info` row for game `gid`: a clone of the first row of `like` games under condition `base`, else any of them, else the first of `category`;
  -- battleId / sortOrder set; with `base`, cond1-4 = it
  function X.opp_row(gid, like, category, base)
    local o, e = X.opp()
    if not o then return nil, e end
    local l = 0
    local fc, e1 = o:field(l, "category")
    if not fc then return nil, e1 end
    local fb, e2 = o:field(l, "battleId")
    if not fb then return nil, e2 end
    local fs, e3 = o:field(l, "sortOrder")
    if not fs then return nil, e3 end
    local conds = {}
    for _, c in ipairs { "cond1", "cond2", "cond3", "cond4" } do
      local f = o:field(l, c)
      if f then conds[#conds + 1] = f end
    end
    local bat = o:col_u32(l, fb)
    local cats = o:col_u32(l, fc)
    local c1 = base and o:col_str(l, conds[1])
    local nrows = #bat
    local likes = {}
    for _, x in ipairs(like) do likes[x] = true end
    local function is_free(i) return base ~= nil and c1[i + 1] == base end
    local of_like = {}
    for i = 0, nrows - 1 do
      if bat[i + 1] and likes[bat[i + 1]] then of_like[#of_like + 1] = i end
    end
    local p
    for _, i in ipairs(of_like) do if is_free(i) then p = i break end end
    if p == nil then p = of_like[1] end
    if p == nil then
      for i = 0, nrows - 1 do if cats[i + 1] == category then p = i break end end
    end
    if p == nil then return nil, "soccer_opponent_info has no row to clone" end
    local row = o:copy(l, p)
    if #of_like == 0 then o:set_u32(-1, row, fc, category) end
    o:set_u32(-1, row, fb, gid)
    local order
    for _, x in ipairs(o:col_u32(l, fs)) do
      if x then
        local v = T.i32(x)
        if order == nil or v > order then order = v end
      end
    end
    order = (order or 0) + 1
    o:set_u32(-1, row, fs, T.u32(order))
    if base ~= nil and (not is_free(p) or #of_like == 0) then
      for _, c in ipairs(conds) do o:set_str(-1, row, c, base) end
    end
    o:push(l, row)
    o:touch()
    X.touched.opp = true
    return true
  end

  -- the route lists' fields
  function X.route_lists()
    local r, e = X.route()
    if not r then return nil, e end
    local pl, e1 = r:list("m_pieceInfoList")
    if not pl then return nil, e1 end
    local el, e2 = r:list("m_pieceEventInfoList")
    if not el then return nil, e2 end
    return r, pl, el
  end

  -- piece `piece`'s row (its position) or nil
  function X.piece_row(r, pl, fid, piece)
    local ids = r:col_u32(pl, fid)
    for i = 1, #ids do
      if ids[i] == piece then return i - 1 end
    end
    return nil
  end

  -- append games to the event slice of piece `piece` (moved to the end of the event list when it is not there)
  function X.piece_append(piece, games)
    local r, pl, el = X.route_lists()
    if not r then return nil, pl end
    local fid, e1 = r:field(pl, "pieceId")
    if not fid then return nil, e1 end
    local fref, e2 = r:field(pl, "eventInfoRef")
    if not fref then return nil, e2 end
    local fg, e3 = r:field(el, "paramCrc1")
    if not fg then return nil, e3 end
    local clear, bust = {}, {}
    for _, f in ipairs { "paramCrc2", "paramNum1", "paramNum2" } do
      local x = r:field(el, f)
      if x then clear[#clear + 1] = x end
    end
    for _, f in ipairs { "bustupEventPreSoccer", "bustupEventPostWinSoccer" } do
      local x = r:field(el, f)
      if x then bust[#bust + 1] = x end
    end
    local p = X.piece_row(r, pl, fid, piece)
    if p == nil then
      return nil, "piece " .. T.hex(piece) .. " is not in chronicle_vs_route_config (is the mod that publishes the list installed?)"
    end
    local a, b = r:tuple(pl, p, fref)
    if a == nil then a, b = 0, 0 end
    local existing = {}
    for j = a, a + b - 1 do
      local g = r:u32(el, j, fg)
      if g then existing[#existing + 1] = g end
    end
    local len = r:len(el)
    local proto
    if a < len then proto = a elseif len > 0 then proto = 0 end
    if proto == nil then return nil, "chronicle_vs_route_config has no event row" end
    local new_rows = {}
    for k, g in ipairs(games) do
      local s = r:copy(el, proto)
      r:set_u32(-1, s, fg, g)
      for _, c in ipairs(clear) do r:set_u32(-1, s, c, 0) end
      for _, c in ipairs(bust) do r:set_str(-1, s, c, nil) end
      new_rows[k] = s
    end
    local start
    if a + b == len or b == 0 then
      start = b == 0 and len or a
    else
      -- the slice is not at the end: copy it there (the old rows stay for any piece that shares them)
      start = len
      r:extend_copy(el, a, a + b)
    end
    for _, s in ipairs(new_rows) do r:push(el, s) end
    r:set_tuple(pl, p, fref, start, b + #games)
    r:touch()
    X.touched.route = true
    return existing
  end

  -- ------------------------------------------------------------------------------------------------ lists

  -- the roster of team `t`: { {slot, card} } sorted
  function X.roster(t)
    local s, e = X.tc:member_range(t)
    local v = {}
    for i = s, e - 1 do
      local row = X.tc:member(i).m
      v[#v + 1] = { TC.uint(row, TM.SLOT) or 0, TC.uint(row, TM.PARAM) or 0 }
    end
    T.sort(v, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
    return v
  end

  -- a 5v5 list takes 5 players in slots 0-4, one keeper, in slot 0
  function X.check_small(t)
    local r = {}
    for _, x in ipairs(X.roster(t)) do if x[1] <= 10 then r[#r + 1] = x end end
    local slots = {}
    for k, x in ipairs(r) do slots[k] = x[1] end
    if T.dbg_list(slots) ~= "[0, 1, 2, 3, 4]" then
      return nil, "a 5v5 list takes teams of 5 players in slots 0-4 (this one has slots " .. T.dbg_list(slots) .. ")"
    end
    local function pos(c)
      local x = X.ch.card[c]
      return x and x.pos or 0
    end
    local gk = 0
    for _, x in ipairs(r) do if pos(x[2]) == POS_GK then gk = gk + 1 end end
    if pos(r[1][2]) ~= POS_GK or gk ~= 1 then return nil, "a 5v5 list needs exactly one goalkeeper, in slot 0" end
    return true
  end

  -- a list a declaration names: nil for the built-in ones, the ListDef, or `false, err`
  function X.resolve_list(m, name)
    name = T.trim(name)
    if name == LIST_FREE or name == LIST_BB then return nil end
    local full = name:find(".", 1, true) and name or (m .. "." .. name)
    if not X.lists[full] then full = VRFW.team.forward(full) end
    local l = X.lists[full]
    if not l then
      local avail = T.keys(X.lists)
      return false, "unknown list `" .. name .. "` (lists: " .. LIST_FREE .. ", " .. LIST_BB .. (#avail == 0 and "" or ", ") .. table.concat(avail, ", ") .. ")"
    end
    if l.owner ~= m and not T.contains(X.requires[m] or {}, l.owner) then
      return false, "list `" .. full .. "` is published by mod " .. l.owner .. ": add \"" .. l.owner .. "\" to the `requires` of mod " .. m .. " to extend it"
    end
    return l
  end

  -- a list's declared condition (every term ANDed), plus «game `prev` beaten at difficulty 9»; nil = no term
  function X.list_cond(terms, prev)
    local groups = {}
    for _, t in ipairs(terms or {}) do
      local args = {}
      for k, a in ipairs(t.args or {}) do
        if type(a) == "number" then
          args[k] = { a, false }
        elseif a:sub(1, 2) == "0x" or a:sub(1, 2) == "0X" then
          args[k] = { VRFW.ids.parse(a), true }
        else
          args[k] = { VRFW.crc32(a), true }
        end
      end
      groups[#groups + 1] = VRFW.cond.group(t.call, args, t.value, VRFW.cond.EQ)
    end
    if prev ~= nil then
      groups[#groups + 1] = VRFW.cond.group("GetSoccerGameClearFlag", { { prev, true }, { 9, false } }, 1, VRFW.cond.EQ)
    end
    if #groups == 0 then return nil end
    local s = VRFW.cond.join(groups, "all")
    return s or ""
  end

  function X.after_game_cond(terms, prev)
    return X.list_cond(terms, prev)
  end

  -- team `t` in the list of an appearance (`ap`: an Appear table)
  function X.appear(m, file, t, ap)
    local tc = X.tc
    local tid, tkey = tc:id_of(t), tc:key_of(t)
    local label = X.label(t)
    local what = file .. ": " .. label .. " in " .. ap.list
    local list, le = X.resolve_list(m, ap.list)
    if list == false then return nil, le end
    local function entry(lk, game, game_key)
      return { list = lk, team = tid, team_key = tkey, game = game, game_key = game_key, mod_id = m }
    end
    local which = T.trim(ap.list)
    if list == nil and which == LIST_FREE then
      local tpl = ap.template_game
      if tpl == nil then
        tpl = X.D.free_match_template
        if tpl == nil then return nil, X.D.free_match_template_err end
      end
      local name, e = X.game_key_for("evt_cm_te_", label .. "@" .. LIST_FREE .. "#game")
      if not name then return nil, e end
      local gid, e2 = X.clone_game(m, what, t, tpl, name, ap.level, true, false)
      if not gid then return nil, e2 end
      -- listed like the game it clones (its free-match row and condition, as the installed data has them)
      local like = {}
      for _, g in ipairs(X.games_list()) do
        if g.name == tpl then like[#like + 1] = g.id end
      end
      local ok, e3 = X.opp_row(gid, like, 0, nil)
      if not ok then return nil, e3 end
      X.entries[#X.entries + 1] = entry(LIST_FREE, gid, name)
    elseif list == nil and which == LIST_BB then
      local row = ap.row or {}
      local rid, e = X.bb_row(t, row)
      if not rid then return nil, e end
      local c = ap.category and T.trim(ap.category) or ""
      if c ~= "" then X.bb_cat[rid] = { m, c } end
      c = ap.season and T.trim(ap.season) or ""
      if c ~= "" then X.bb_season[rid] = { m, c } end
      local after = ap.sort_after and T.trim(ap.sort_after) or ""
      local before = ap.sort_before and T.trim(ap.sort_before) or ""
      if after ~= "" and before ~= "" then
        VRFW.log.warn(LIST_BB .. ": " .. tkey .. ": sort_after " .. after .. " and sort_before " .. before .. ": sort_after wins")
      end
      if after ~= "" then
        X.bb_after[rid] = { m, after, 1 }
      elseif before ~= "" then
        X.bb_after[rid] = { m, before, -1 }
      end
      X.entries[#X.entries + 1] = { list = LIST_BB, team = rid, team_key = tkey, game = 0, game_key = "", mod_id = m }
    elseif list == nil then
      return nil, "unknown built-in list `" .. which .. "`"
    else
      local l = list
      if l.format == "5v5" then
        local ok, e = X.check_small(t)
        if not ok then return nil, e end
      end
      local level = ap.level
      if level == nil then level = l.level end
      if l.kind == "lua" then
        X.entries[#X.entries + 1] = entry(l.key, 0, "")
      elseif l.kind == "shop_beside" then
        -- the team's players sold beside a character
        if ap.beside == nil then return nil, "a shop_beside list needs `beside` (a character whose shop page sells them)" end
        local beside = ap.beside
        local bc, e = X.chara_of(beside, m)
        if not bc then return nil, "beside: " .. e end
        local bcards = X.ch.cards[bc] or {}
        local cards = {}
        if #(ap.players or {}) == 0 then
          for _, x in ipairs(X.roster(t)) do if x[1] <= 18 then cards[#cards + 1] = x[2] end end
        else
          for _, p in ipairs(ap.players) do
            local c, e2 = X.player_ref(p, nil, m)
            if not c then return nil, e2 end
            cards[#cards + 1] = c
          end
        end
        -- shop indices: the shared range above the GAME's own shop_config (never the merged table)
        local shop_key, e3 = X.table_key("data/common/gamedata/shop/shop_config_")
        if not shop_key then return nil, e3 end
        local lo, hi, e4 = VRFW.team.shop_range(shop_key)
        if not lo then return nil, e4 end
        local shop = X.shop()
        if not shop then return true end
        local res = VRFW.team.shop_beside(shop, m, cards, bcards, ap.price, lo, hi)
        if res.error then return nil, res.error end
        for _, w in ipairs(res.warn) do VRFW.log.warn(what .. ": " .. w) end
        if res.unpriced > 0 then
          VRFW.log.warn(string.format("%s: `price`: the shop row of `%s` has no price (CONSUME) block: %d row(s) keep the page's rule", what, beside, res.unpriced))
        end
        if res.nopage then
          VRFW.log.warn(what .. ": beside `" .. beside .. "`: that character is not sold in any shop page (nothing added)")
        end
        X.touched.shop = true
        VRFW.log.info(string.format("%s: %d player(s) sold beside %s", what, res.added, beside))
        X.entries[#X.entries + 1] = entry(l.key, 0, "")
      elseif l.kind == "free_match_piece" then
        if l.piece == nil then return nil, "list " .. l.key .. " has no `piece`" end
        local tpl = ap.template_game or l.template_game
        if tpl == nil then return nil, "list " .. l.key .. " has no `template_game`" end
        local name, e = X.game_key_for("evt_cm_te_", label .. "@" .. l.key .. "#game")
        if not name then return nil, e end
        local gid, e2 = X.clone_game(m, what, t, tpl, name, level, false, false)
        if not gid then return nil, e2 end
        local like, e3 = X.piece_append(l.piece, { gid })
        if not like then return nil, e3 end
        local base = X.list_cond(l.condition, nil)
        local ok, e4 = X.opp_row(gid, like, 1, base)
        if not ok then return nil, e4 end
        X.entries[#X.entries + 1] = entry(l.key, gid, name)
      elseif l.kind == "pool_table" then
        local pool = l.pool
        if pool == nil then return nil, "list " .. l.key .. " has no `pool`" end
        local full = l.format == "11v11"
        if not full then
          local ok, e = X.check_small(t)
          if not ok then return nil, e end
        end
        local tpl = ap.template_game or l.template_game
        if tpl == nil then return nil, "list " .. l.key .. " has no `template_game`" end
        if pool.template_prefix ~= nil and not T.starts(tpl, pool.template_prefix) then
          return nil, "list " .. l.key .. ": the template game must be a " .. pool.template_prefix .. "* game (`pool.template_prefix`)"
        end
        if not X.pool(pool.file) then
          return nil, "list " .. l.key .. ": " .. pool.file .. " not found (is mod " .. l.owner .. " installed with its data?)"
        end
        local name, e = X.game_key_for(pool.game_prefix, label .. "@" .. l.key .. "#game")
        if not name then return nil, e end
        local gid, e2 = X.clone_game(m, what, t, tpl, name, nil, false, true, ap.ladder or {})
        if not gid then return nil, e2 end
        local tier = ap.tier
        if tier == nil then tier = l.tier end
        local ok, e3 = X.pool_rows(pool, t, gid, name, tpl, tier, table.concat(ap.tags or {}, ","), full, ap.rank)
        if not ok then return nil, e3 end
        X.entries[#X.entries + 1] = entry(l.key, gid, name)
      end
    end
    return true
  end

  -- the pool rows of team `t` in the pool table of a pool_table list (the engine's pool layout)
  function X.pool_rows(pool, t, gid, game, template, tier, tags, full, rank)
    local tc = X.tc
    local tid = tc:id_of(t)
    local meta = X.meta[tid] or X.new_meta()
    local info = tc:info(t)
    local members = {}
    local last_slot = full and 10 or 4
    for _, x in ipairs(X.roster(t)) do
      local slot, card = x[1], x[2]
      if slot <= last_slot then
        local c = X.ch.card[card]
        local chara, elem, pos = 0, 0, 0
        if c then chara, elem, pos = c.chara, c.elem, c.pos end
        local star = 0
        if pool.star_column ~= nil then
          local cols = X.ch.cols[card]
          star = cols and cols[pool.star_column] or 0
        end
        local name
        for _, k in ipairs(T.keys(X.ch.created)) do
          if X.ch.created[k].card == card then name = k break end
        end
        if name == nil then name = X.chara_name_es(chara) end
        if name == nil then name = "#" .. string.format("%08X", card) end
        members[#members + 1] = { slot, card, pos, elem, star > 0 and star or 1, name }
      end
    end
    local g = X.games_t
    local SG = X.SG
    local G = X.gcache()
    local game_g = G.by_id[gid]
    local ladder = {}
    local stadium = 0
    if game_g then
      for _, i in ipairs(X.grows(game_g)) do
        ladder[#ladder + 1] = { g:int(i, SG.D_DIFF) or 0, g:int(i, SG.D_LEVEL) or 0 }
      end
      stadium = g:uint(game_g.info, SG.G_STADIUM) or 0
    end
    local tkey = tc:key_of(t)
    local name = meta.names[X.lang.source]
    if name == nil then
      local ks = T.keys(meta.names)
      if ks[1] then name = meta.names[ks[1]] end
    end
    if name == nil then name = tkey end
    local elems = {}
    for _, x in ipairs(members) do elems[x[4]] = (elems[x[4]] or 0) + 1 end
    -- the most common element (ties: the lower one)
    local elem, en
    for _, e in ipairs(T.keys(elems)) do
      if en == nil or elems[e] > en then elem, en = e, elems[e] end
    end
    elem = elem or 0
    local power = 0
    for _, x in ipairs(members) do power = power + x[5] end
    power = power * 100
    local rt = X.pool(pool.file)
    if not rt then return nil, pool.file .. " not found" end
    local infos = rt:rows(pool.info)
    if not infos[1] then return nil, pool.file .. " has no " .. pool.info .. " row" end
    local pi = rt:entry(infos[1])
    local tpl_row
    for _, i in ipairs(infos) do
      if rt:str(i, 5) == template then tpl_row = rt:entry(i) break end
    end
    if tier == nil and tpl_row then tier = TC.int(tpl_row.values, 6) end
    if tier == nil then tier = 1 end
    if pool.tiers ~= nil then
      local lo, hi = pool.tiers[1], pool.tiers[2]
      if not (tier >= lo and tier <= hi) then return nil, string.format("tier %d out of %d-%d (`pool.tiers`)", tier, lo, hi) end
    end
    local tmpl_src = (tpl_row and TC.text(tpl_row.values, 13)) or ""
    local nos = {}
    for _, i in ipairs(infos) do
      local x = rt:int(i, 0)
      if x then nos[x] = true end
    end
    local from, span = pool.numbers[1], pool.numbers[2]
    local no = from + VRFW.crc32(game) % math.max(span, 1)
    while nos[no] do no = no + 1 end
    local pm_i = rt:rows(pool.member)[1]
    if not pm_i then return nil, "no " .. pool.member .. " row" end
    local pd_i = rt:rows(pool.difficulty)[1]
    if not pd_i then return nil, "no " .. pool.difficulty .. " row" end
    local pm, pd = rt:entry(pm_i), rt:entry(pd_i)
    local ir = { name = pi.name, hash = pi.hash, values = { no, T.i32(tid), tkey, name, T.i32(gid), game, tier, T.i32(stadium),
      T.i32(TC.uint(info, TI.EMBLEM) or 0), T.i32(TC.uint(info, TI.KIT) or 0), T.i32(TC.uint(info, TI.FORMATION) or 0), elem, power, tmpl_src } }
    if #pi.values >= 16 or full or tags ~= "" or rank ~= nil then
      ir.values[#ir.values + 1] = tags
      ir.values[#ir.values + 1] = full and 11 or 5
      ir.values[#ir.values + 1] = rank ~= nil and rank or -1
    end
    local function app(list, rows, n)
      local ok, e = pcall(rt.append_rows, rt, list, { list }, rows, n)
      if not ok then return nil, tostring(e) end
      return true
    end
    local ok, e = app(pool.info, { ir }, 1)
    if not ok then return nil, e end
    local mrows = {}
    for k, x in ipairs(members) do
      mrows[k] = { name = pm.name, hash = pm.hash, values = { no, x[1], T.i32(x[2]), x[3], x[4], x[5], x[6] } }
    end
    ok, e = app(pool.member, mrows, #mrows)
    if not ok then return nil, e end
    local drows = {}
    for k, x in ipairs(ladder) do
      drows[k] = { name = pd.name, hash = pd.hash, values = { no, x[1], x[2] } }
    end
    ok, e = app(pool.difficulty, drows, #drows)
    if not ok then return nil, e end
    X.pool_header(rt, pool)
    X.touched.pool = true
    return true
  end

  -- the pool's header row col 2 = the number of info rows (no header declared: nothing)
  function X.pool_header(rt, pool)
    if pool.header == nil then return end
    local n = #rt:rows(pool.info)
    local i = rt:rows(pool.header)[1]
    if i then rt:set(i, 2, n) end
  end

  -- ------------------------------------------------------------------------------------------------ Estadio BB

  function X.enjoy()
    if X.enjoy_t == nil then
      local k, e = X.table_key("data/common/gamedata/team/enjoy_mode_team_config_")
      if not k then
        VRFW.log.warn(e .. ": the Estadio BB list is not changed")
        X.enjoy_t = false
        return nil
      end
      local t, e2 = VRFW.rows.open(k)
      if not t then VRFW.log.warn(e2 .. ": the Estadio BB list is not changed") end
      if t then
        -- columns (schemas/team/enjoy_mode_team.toml; the old builder's numbers when a schema lacks the name)
        local function c(name, n)
          local ok, x = pcall(t.col, t, ENJOY_ROW, name)
          if ok and x then return x end
          return n
        end
        X.EJ = { TEAM = c("team", 0), LEADER = c("leader", 1), C2 = c("c2", 2), ORDER = c("order", 3), STADIUM = c("stadium_map", 4),
          IMAGE = c("image", 5), IMAGE_NAME = c("image_name", 6), CONDITION = c("condition", 7), BGM = c("bgm_set", 8),
          UNLOCK_TEXT = c("unlock_text", 9), C10 = c("c10", 10), C11 = c("c11", 11) }
        local order = {}
        for _, i in ipairs(t:rows(ENJOY_ROW)) do
          local x = t:uint(i, 0)
          if x then order[#order + 1] = x end
        end
        X.bb_game = {}
        for _, x in ipairs(order) do X.bb_game[x] = true end
        X.bb_game_order = order
      end
      X.enjoy_t = t or false
    end
    return X.enjoy_t or nil
  end

  -- the level of the Estadio BB teams: the most common team_config level of the teams the grid lists (not BB copies)
  function X.bb_level()
    local en = X.enjoy()
    if not en then return nil, "enjoy_mode_team_config not found" end
    local copies = {}
    for _, c in pairs(X.bb_copies) do copies[c] = true end
    local count = {}
    for _, i in ipairs(en:rows(ENJOY_ROW)) do
      local id = en:uint(i, 0)
      if id and not copies[id] then
        local t = X.tc:find(id)
        local l = t and TC.int(X.tc:info(t), TI.LEVEL)
        if l then count[l] = (count[l] or 0) + 1 end
      end
    end
    local best, bn
    for l, n in pairs(count) do
      if best == nil or n > bn or (n == bn and l > best) then best, bn = l, n end
    end
    if best == nil then return nil, "enjoy_mode_team_config: no row names a team_config team (the Estadio BB level is unknown)" end
    return best
  end

  -- the Estadio BB copy of team `t` (made once): key `<key>_bb`, the grid's level, the roster in the BB format
  function X.bb_copy(t)
    local tc = X.tc
    local src = tc:id_of(t)
    if X.bb_copies[src] then
      local c = tc:find(X.bb_copies[src])
      if c == nil then return nil, "its BB copy is gone" end
      return c
    end
    local key = tc:key_of(t) .. "_bb"
    local id = VRFW.crc32(key)
    if tc:find(id) ~= nil or tc:find_key(key) ~= nil then return nil, "the BB copy key `" .. key .. "` is already a team" end
    local level, e = X.bb_level()
    if not level then return nil, e end
    local D = X.D.bb_copy
    local info, refs = tc:team_copy(t)
    TC.set_int(info, TI.ID, id)
    info[TI.KEY + 1] = key
    TC.set_int(info, TI.LEVEL, level)
    local rows = {}
    local s, en = tc:member_range(t)
    for i = s, en - 1 do
      local x = tc:member(i)
      if (TC.uint(x.m, TM.SLOT) or 0) <= D.last_slot then
        local row = TC.copy_row(x.m)
        TC.set_int(row, TM.FLAG, D.flag)
        TC.set_int(row, TM.LV_OFS, D.level_offset)
        TC.set_int(row, TM.RARITY_STEP, D.rarity_step)
        for k = 0, 5 do TC.set_int(row, TM.C14 + k, D.c14_19) end
        for k = 0, 7 do TC.set_int(row, TM.RATE + k, D.rates) end
        rows[#rows + 1] = { m = row, r = TC.copy_row(x.r) }
      end
    end
    local start = #tc.members
    refs[1] = { start, #rows }
    refs[4] = { 0, 0 }
    for _, r in ipairs(rows) do tc.members[#tc.members + 1] = r end
    tc:push_team(info, refs)
    X.bb_copies[src] = id
    return #tc.teams - 1
  end

  -- the Estadio BB row of team `t` (its copy unless `copy = false`): a new row, or the cells given on its row
  function X.bb_row(t, row)
    local tc = X.tc
    local src = tc:id_of(t)
    if row.copy ~= false then
      local c, e = X.bb_copy(t)
      if not c then return nil, e end
      t = c
    end
    local tid = tc:id_of(t)
    X.bb_src[tid] = src
    if row.stadium ~= nil then X.bb_stadium_set[tid] = true end
    if row.image ~= nil or row.image_name ~= nil then X.bb_image_set[tid] = true end
    local captain
    do
      -- the captain's row, else the first row: its card (0 when none)
      local s, e = tc:member_range(t)
      local row
      for i = s, e - 1 do
        if TC.int(tc:member(i).m, TM.CAPTAIN) == 1 then row = tc:member(i).m break end
      end
      if row == nil and s < e then row = tc:member(s).m end
      captain = row and TC.uint(row, TM.PARAM) or 0
    end
    local en = X.enjoy()
    if not en then return nil, "enjoy_mode_team_config not found" end
    local EJ = X.EJ
    local rows = en:rows(ENJOY_ROW)
    local first = rows[1]
    if first == nil then return nil, "enjoy_mode_team_config has no row" end
    local i
    for _, r in ipairs(rows) do
      if en:uint(r, 0) == tid then i = r break end
    end
    if i == nil then
      local order
      for _, r in ipairs(rows) do
        local x = en:int(r, EJ.ORDER)
        if x and (order == nil or x > order) then order = x end
      end
      order = (order or 0) + 1
      local e = en:entry(first)
      local B = X.D.bb_row
      for _, cv in ipairs { { EJ.TEAM, tid }, { EJ.LEADER, captain }, { EJ.C2, B.c2 }, { EJ.ORDER, order }, { EJ.CONDITION, B.condition },
        { EJ.UNLOCK_TEXT, B.unlock_text }, { EJ.C10, B.c10 }, { EJ.C11, B.c11 } } do
        TC.set_int(e.values, cv[1], cv[2])
      end
      local ok, e2 = pcall(en.append_rows, en, ENJOY_ROW, { ENJOY_ROW }, { e }, 1)
      if not ok then return nil, tostring(e2) end
      local rr = en:rows(ENJOY_ROW)
      i = rr[#rr]
    end
    local ints = { { EJ.LEADER, row.leader ~= nil and T.i32(T.id(row.leader)) or nil },
      { EJ.C2, row.c2 ~= nil and T.i32(T.id(row.c2)) or nil },
      { EJ.ORDER, row.order },
      { EJ.STADIUM, row.stadium ~= nil and T.i32(T.id(row.stadium)) or nil },
      { EJ.CONDITION, row.condition ~= nil and T.i32(T.id(row.condition)) or nil },
      { EJ.BGM, row.bgm ~= nil and T.i32(T.id(row.bgm)) or nil },
      { EJ.UNLOCK_TEXT, row.unlock_text ~= nil and T.i32(T.id(row.unlock_text)) or nil },
      { EJ.C10, row.c10 }, { EJ.C11, row.c11 } }
    for _, cv in ipairs(ints) do
      if cv[2] ~= nil then en:set(i, cv[1], cv[2]) end
    end
    if row.image ~= nil then
      en:set(i, EJ.IMAGE, row.image)
      local name = row.image_name
      if name == nil then
        name = T.last_part(row.image, "/")
        while T.ends(name, ".g4tx") and #name >= 5 do name = name:sub(1, -6) end
      end
      en:set(i, EJ.IMAGE_NAME, name)
    elseif row.image_name ~= nil then
      en:set(i, EJ.IMAGE_NAME, row.image_name)
    end
    en:touch()
    X.touched.enjoy = true
    return tid
  end

  -- home stadium of team `id` and its Estadio BB card art: the first `stadium` of the team and its `based_on` chain, else the first `stadium_fallback`;
  -- art = the `stadium_image` of the declaration that gave the stadium, else the first of the chain (nil = none)
  function X.home_stadium(id)
    local chain = {}
    for _ = 1, 8 do
      if id == nil then break end
      chain[#chain + 1] = id
      id = X.based_on[id]
    end
    local any_image
    for _, c in ipairs(chain) do
      local m = X.meta[c]
      if m and m.stadium_image ~= nil and any_image == nil then any_image = m.stadium_image end
    end
    for _, key in ipairs { "stadium", "stadium_fallback" } do
      for _, c in ipairs(chain) do
        local m = X.meta[c]
        if m and m[key] ~= nil then return m[key], m.stadium_image or any_image end
      end
    end
    return nil
  end

  -- every Estadio BB row plays at its team's home stadium, with that stadium's card art (after every appearance)
  function X.bb_home_stadiums()
    local any = false
    for _, m in pairs(X.meta) do
      if m.stadium ~= nil or m.stadium_fallback ~= nil then any = true break end
    end
    if not any then return end
    local en = X.enjoy()
    if not en then return end
    local EJ = X.EJ
    local copy_src = {}
    for s, c in pairs(X.bb_copies) do copy_src[c] = s end
    local set, art = {}, 0
    for _, i in ipairs(en:rows(ENJOY_ROW)) do
      local tid = en:uint(i, 0)
      if tid and not X.bb_stadium_set[tid] then
        local src = X.bb_src[tid] or copy_src[tid] or tid
        local home, image = X.home_stadium(src)
        if home == nil then home, image = X.home_stadium(tid) end
        if home ~= nil then
          local x = { i, nil, nil }
          if en:uint(i, EJ.STADIUM) ~= home then x[2] = home end
          if image ~= nil and not X.bb_image_set[tid] and en:str(i, EJ.IMAGE) ~= image then x[3] = image end
          if x[2] ~= nil or x[3] ~= nil then set[#set + 1] = x end
        end
      end
    end
    if #set == 0 then return end
    for _, x in ipairs(set) do
      if x[2] ~= nil then en:set(x[1], EJ.STADIUM, T.i32(x[2])) end
      if x[3] ~= nil then
        local name = T.last_part(x[3], "/")
        while T.ends(name, ".g4tx") and #name >= 5 do name = name:sub(1, -6) end
        en:set(x[1], EJ.IMAGE, x[3])
        en:set(x[1], EJ.IMAGE_NAME, name)
        art = art + 1
      end
    end
    en:touch()
    X.touched.enjoy = true
    VRFW.log.info(string.format("%s: %d row(s) play at their team's home stadium (team key `stadium` / `stadium_fallback`), %d with its card art (`stadium_image`)", LIST_BB, #set, art))
  end

  -- the menus' previewed teams (Estadio BB list, game rivals, fixed own line-ups) within the menus' member rows
  -- (row indices above 32767 show the name and an empty pitch at level 0)
  function X.front_preview_members()
    local first = {}
    local en = X.enjoy()
    if en then
      for _, i in ipairs(en:rows(ENJOY_ROW)) do
        local x = en:uint(i, 0)
        if x then first[x] = true end
      end
    end
    local g = X.games()
    if g then
      for _, i in ipairs(g:rows(DIFF)) do
        local x = g:uint(i, X.SG.D_TEAM)
        if x then first[x] = true end
        local o = g:uint(i, X.SG.D_OWN_TEAM)
        if o and o ~= 4294967295 then first[o] = true end
      end
    end
    first[0] = nil
    local late, front = X.tc:front_members(first)
    if late then
      VRFW.log.info(string.format("team_config: %d previewed team(s) had their line-up past member row %d (read signed by the game's readers; unsigned with the MemberRows patches): %d member rows of the %d previewed teams moved first",
        late, TC.MENU_MEMBER_ROWS - 1, front, T.count(first)))
      if front > TC.MENU_MEMBER_ROWS then
        VRFW.log.info(string.format("team_config: the previewed teams need %d member rows: past %d they show their players only with the MemberRows patches on (loader.log `patch MemberRows.`)", front, TC.MENU_MEMBER_ROWS))
      end
    end
    local rows = #X.tc.members
    if rows > TC.MEMBER_ROWS_MAX then
      VRFW.log.warn(string.format("team_config: %d member rows, the game's team readers reach %d (16-bit rows, unsigned with the MemberRows patches): the teams past that show and play no players",
        rows, TC.MEMBER_ROWS_MAX))
    end
  end

  -- ------------------------------------------------------------------------------------------------ orders

  -- the new order of rows with an optional rank each (`false` = none): ranked rows by rank (stable), a row without
  -- one right after the row it followed; for each place, the old index (0-based)
  function X.order_by_rank(rank)
    local keyed = {}
    local l0, l1 = -1, -1
    for i = 0, #rank - 1 do
      local r = rank[i + 1]
      if r then
        l0, l1 = r, i
        keyed[#keyed + 1] = { r, i, 0, i }
      else
        keyed[#keyed + 1] = { l0, l1, 1, i }
      end
    end
    T.sort(keyed, function(a, b)
      for k = 1, 4 do
        if a[k] ~= b[k] then return a[k] < b[k] end
      end
      return false
    end)
    local out = {}
    for k, x in ipairs(keyed) do out[k] = x[4] end
    return out
  end

  -- `[[order]]` of a built-in list
  function X.order_list(m, o)
    if T.trim(o.list) ~= LIST_BB then
      return nil, "only the built-in list `" .. LIST_BB .. "` takes an [[order]] (a published tab list has `order` on its [[list]])"
    end
    -- a team named twice ranks its rows in turn (a game team with two rows)
    local rank = {}
    local missing = {}
    for k, r in ipairs(o.teams) do
      -- a name that does not resolve only loses its own place
      local t, e = X.team_ref(r, m)
      if t == nil then
        missing[#missing + 1] = r .. " (" .. e .. ")"
      else
        local id = X.tc:id_of(t)
        id = X.bb_copies[id] or id
        rank[id] = rank[id] or {}
        table.insert(rank[id], k - 1)
      end
    end
    local en = X.enjoy()
    if not en then return nil, "enjoy_mode_team_config not found" end
    local rows = en:rows(ENJOY_ROW)
    local ents = {}
    local ranks = {}
    local unplaced = 0
    for k, i in ipairs(rows) do
      ents[k] = en:entry(i)
      local id = en:uint(i, 0)
      local q = id and rank[id]
      if q and #q > 0 then
        ranks[k] = table.remove(q, 1)
      else
        ranks[k] = false
        unplaced = unplaced + 1
      end
    end
    local order = X.order_by_rank(ranks)
    if #missing > 0 then
      VRFW.log.warn(string.format("order of `%s`: %d name(s) left out of the order: %s", LIST_BB, #missing, table.concat(missing, "; ")))
    end
    if unplaced > 0 then
      VRFW.log.warn(string.format("order of `%s`: %d of %d row(s) not named (each stays after the row it followed)", LIST_BB, unplaced, #ranks))
    end
    local same = true
    for k, x in ipairs(order) do if x ~= k - 1 then same = false break end end
    if same then return true end
    for k, slot in ipairs(rows) do
      en:splice(slot, slot + 1, { ents[order[k] + 1] })
    end
    en:touch()
    X.touched.enjoy = true
    return true
  end

  -- a published tab list's `order` (its rows in soccer_opponent_info) and `unlock = "chain"`
  function X.order_tab(l)
    local piece = l.piece
    if piece == nil then return nil, "no piece" end
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
    local games = {}
    for j = a, a + b - 1 do
      local g = r:u32(el, j, fg)
      if g then games[#games + 1] = g end
    end
    local gset = {}
    for _, g in ipairs(games) do gset[g] = true end
    local gt, ge = X.games()
    if not gt then return nil, ge end
    -- team -> game (the last game of the piece that plays it, as a HashMap collect)
    local team_of = {}
    for _, g in ipairs(X.games_list()) do
      if gset[g.id] then
        local rows = X.grows(g)
        if rows[1] then
          local tm = gt:uint(rows[1], X.SG.D_TEAM)
          if tm then team_of[tm] = g.id end
        end
      end
    end
    local chain = {}
    for _, ref in ipairs(l.order) do
      -- a team the active mods do not declare (its file left out, a partial install): skipped, noted
      local t, e = X.team_ref(ref, l.owner)
      if t == nil then
        VRFW.log.warn("list " .. l.key .. ": order: " .. e .. " (left out of the order)")
      else
        local g = team_of[X.tc:id_of(t)]
        if g == nil then return nil, "`" .. ref .. "` plays no game of the list's piece" end
        chain[#chain + 1] = g
      end
    end
    local o, oe = X.opp()
    if not o then return nil, oe end
    local fb, e4 = o:field(0, "battleId")
    if not fb then return nil, e4 end
    local fc, e5 = o:field(0, "category")
    if not fc then return nil, e5 end
    local conds = {}
    for _, c in ipairs { "cond1", "cond2", "cond3", "cond4" } do
      local f = o:field(0, c)
      if f then conds[#conds + 1] = f end
    end
    -- the free-match rows of the piece's games (category 1; with a declared condition, only the rows under it or
    -- under its chain)
    local base = X.list_cond(l.condition, nil)
    local after = {}
    for k, g in ipairs(chain) do after[k] = X.after_game_cond(l.condition, g) end
    local after_set = {}
    for _, s in ipairs(after) do after_set[s] = true end
    local bat, cat = o:col_u32(0, fb), o:col_u32(0, fc)
    local c1 = conds[1] and o:col_str(0, conds[1])
    local rows = {}
    for i = 0, #bat - 1 do
      if bat[i + 1] and gset[bat[i + 1]] and cat[i + 1] == 1 then
        local ok = base == nil
        if not ok and c1 then
          local s = c1[i + 1]
          ok = s and (s == base or after_set[s]) or false
        end
        if ok then rows[#rows + 1] = i end
      end
    end
    -- the named teams first, in `order`; the others after them, in their order
    local function chain_pos(g)
      for k, x in ipairs(chain) do if x == g then return k - 1 end end
      return nil
    end
    local rank = {}
    for k, i in ipairs(rows) do rank[k] = chain_pos(bat[i + 1]) end
    local order = {}
    for k = 1, #rows do order[k] = k end
    T.sort(order, function(x, y)
      local ax, ay = rank[x] == nil, rank[y] == nil
      if ax ~= ay then return not ax end
      local rx, ry = rank[x] or 0, rank[y] or 0
      if rx ~= ry then return rx < ry end
      return x < y
    end)
    local fs, e6 = o:field(0, "sortOrder")
    if not fs then return nil, e6 end
    local sorts = {}
    for _, i in ipairs(rows) do
      local s = o:u32(0, i, fs)
      if s then sorts[#sorts + 1] = s end
    end
    table.sort(sorts)
    local ents = {}
    for k, i in ipairs(rows) do ents[k] = o:copy(0, i) end
    for k, slot in ipairs(rows) do
      o:set_row(0, slot, ents[order[k]])
      if sorts[k] then o:set_u32(0, slot, fs, sorts[k]) end
    end
    if l.unlock == "chain" then
      for _, i in ipairs(rows) do
        local bb = o:u32(0, i, fb)
        local k = bb and chain_pos(bb)
        if k ~= nil then
          -- the first keeps its own condition (or the list's); the others: the list's AND the previous beaten
          local c
          if k == 0 then c = base else c = after[k] end
          if c ~= nil then
            for _, f in ipairs(conds) do o:set_str(0, i, f, c) end
          end
        end
      end
    end
    o:touch()
    X.touched.opp = true
    return true
  end

  -- ------------------------------------------------------------------------------------------------ removals

  -- games whose every difficulty row plays against `tid`
  function X.games_of(tid)
    local g, e = X.games()
    if not g then return nil, e end
    local out = {}
    for _, x in ipairs(X.games_list()) do
      local rows = X.grows(x)
      local all = #rows > 0
      for _, i in ipairs(rows) do
        if g:uint(i, X.SG.D_TEAM) ~= tid then all = false break end
      end
      if all then out[#out + 1] = x.id end
    end
    return out
  end

  function X.remove(m, file, r)
    local tc = X.tc
    local t, e = X.team_ref(r.team, m)
    if t == nil then return nil, e end
    local tid = tc:id_of(t)
    local label = X.label(t)
    local what = file .. ": remove " .. label
    local touched = {}
    for _, c in pairs(X.claims[tid] or {}) do
      if c.by ~= m then touched[c.by] = true end
    end
    for _, x in ipairs(X.entries) do
      if x.team == tid and x.mod_id ~= m then touched[x.mod_id] = true end
    end
    if not T.is_empty(touched) then
      local msg = "team conflict: " .. what .. ": mod " .. m .. " removes it and " .. table.concat(T.keys(touched), ", ") .. " edit(s) / list(s) it (the removal wins)"
      VRFW.log.warn(msg)
      X.conflicts[#X.conflicts + 1] = msg
    end
    if r.mode == "delete" then
      local g, ge = X.games()
      if not g then return nil, ge end
      local refs = {}
      for _, x in ipairs(X.games_list()) do
        for _, i in ipairs(X.grows(x)) do
          if g:uint(i, X.SG.D_TEAM) == tid then refs[#refs + 1] = x.name break end
        end
      end
      if #refs > 0 then
        local shown = {}
        for k = 1, math.min(3, #refs) do shown[k] = refs[k] end
        return nil, string.format("%s is played in %d game(s) (%s…): it cannot be deleted (use mode = \"hide\")", label, #refs, table.concat(shown, ", "))
      end
      tc:remove_team(t)
      X.hidden[tid] = true
      local keep = {}
      for _, x in ipairs(X.entries) do if x.team ~= tid then keep[#keep + 1] = x end end
      X.entries = keep
      VRFW.log.warn(what .. ": deleted from team_config (saves that use it may break)")
      return true
    end
    -- hide
    local only = {}
    for k, x in ipairs(r.lists or {}) do only[k] = T.trim(x) end
    local all = #only == 0
    local games, ge = X.games_of(tid)
    if not games then return nil, ge end
    local listed = {}
    for _, x in ipairs(X.entries) do
      if x.game ~= 0 then listed[x.game] = x.list end
    end
    -- piece lists published by mods: their games
    local pub_games = {}
    local pieces = {}
    for _, k in ipairs(T.keys(X.lists)) do
      local l = X.lists[k]
      if l.kind == "free_match_piece" and l.piece ~= nil then pieces[#pieces + 1] = l.piece end
    end
    if #pieces > 0 then
      local rt, pl, el = X.route_lists()
      if rt then
        local fid, fref, fg = rt:field(pl, "pieceId"), rt:field(pl, "eventInfoRef"), rt:field(el, "paramCrc1")
        if fid and fref and fg then
          for _, p in ipairs(pieces) do
            local i = X.piece_row(rt, pl, fid, p)
            if i then
              local a, b = rt:tuple(pl, i, fref)
              if a == nil then a, b = 0, 0 end
              for j = a, a + b - 1 do
                local g = rt:u32(el, j, fg)
                if g then pub_games[g] = true end
              end
            end
          end
        end
      end
    end
    local function want(gid)
      if all then return true end
      local l = listed[gid]
      for _, o in ipairs(only) do
        if o == LIST_FREE then
          if l == nil then
            if not pub_games[gid] then return true end
          elseif l == LIST_FREE then
            return true
          end
        elseif l ~= nil and o == l then
          return true
        end
      end
      return false
    end
    local drop = {}
    local any = false
    for _, g in ipairs(games) do
      if want(g) then drop[g] = true any = true end
    end
    local n = 0
    if any then
      local o, oe = X.opp()
      if not o then return nil, oe end
      local fb, fe = o:field(0, "battleId")
      if not fb then return nil, fe end
      local bat = o:col_u32(0, fb)
      local keep = {}
      for i = 0, #bat - 1 do
        if not (bat[i + 1] and drop[bat[i + 1]]) then keep[#keep + 1] = i end
      end
      n = #bat - #keep
      if n > 0 then
        o:keep(0, keep)
        o:touch()
        X.touched.opp = true
      end
    end
    -- the Estadio BB grid (the team's rows and its BB copy's)
    local nb = 0
    if all or T.contains(only, LIST_BB) then
      local ids = { [tid] = true }
      if X.bb_copies[tid] then ids[X.bb_copies[tid]] = true end
      local en = X.enjoy()
      if en then
        while true do
          local hit
          for _, i in ipairs(en:rows(ENJOY_ROW)) do
            local x = en:uint(i, 0)
            if x and ids[x] then hit = i break end
          end
          if not hit then break end
          local b0, _, le = en:list(ENJOY_ROW)
          if not b0 then return nil, le end
          local ok, e2 = pcall(en.remove_range, en, b0, hit, hit + 1, 1)
          if not ok then return nil, tostring(e2) end
          nb = nb + 1
        end
      end
      if nb > 0 then X.touched.enjoy = true end
    end
    -- the pool tables
    local nr = 0
    for _, key in ipairs(T.keys(X.lists)) do
      local l = X.lists[key]
      if l.kind == "pool_table" and l.pool ~= nil and (all or T.contains(only, key)) then
        local pool = l.pool
        local rt = X.pool(pool.file)
        if rt then
          local nos = {}
          local cnt = 0
          for _, i in ipairs(rt:rows(pool.info)) do
            if rt:uint(i, 1) == tid then
              local x = rt:int(i, 0)
              if x and not nos[x] then nos[x] = true cnt = cnt + 1 end
            end
          end
          if cnt > 0 then
            for _, list in ipairs { pool.info, pool.member, pool.difficulty } do
              while true do
                local hit
                for _, i in ipairs(rt:rows(list)) do
                  local x = rt:int(i, 0)
                  if x and nos[x] then hit = i break end
                end
                if not hit then break end
                local b0, _, le = rt:list(list)
                if not b0 then return nil, le end
                local ok, e2 = pcall(rt.remove_range, rt, b0, hit, hit + 1, 1)
                if not ok then return nil, tostring(e2) end
              end
            end
            X.pool_header(rt, pool)
            nr = nr + cnt
            X.touched.pool = true
          end
        end
      end
    end
    local keep = {}
    for _, x in ipairs(X.entries) do
      if not (x.team == tid and (all or T.contains(only, x.list))) then keep[#keep + 1] = x end
    end
    X.entries = keep
    X.hidden[tid] = true
    VRFW.log.info(string.format("%s: hidden (%d list row(s), %d pool row(s), %d Estadio BB row(s))", what, n, nr, nb))
    return true
  end
end

return L
