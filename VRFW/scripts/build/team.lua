-- Build script of the type `team` (docs/framework/build-scripts.md, docs/framework/types/team.md): every active mod's
-- team declarations (load order) -> the game's team tables (team_config, soccer_game_config, soccer_opponent_info,
-- chronicle_vs_route_config, enjoy_mode_team_config, item_config, uniform_config, shop_config,
-- soccer_game_bgm_config, the declared pool tables), the texts for the text type, the match-rule assignments, the
-- lists for the Lua, and the services built on them (route nodes, talks, chains, match challenges, level maps, the
-- free match's tabs and rules, the Estadio BB grid's categories, seasons and unlocks).
--
-- Order: (0) every mod's [[list]] (extension points), (0b) [[loadout]], (1) every NEW team, (2) every [[edit]],
-- (3) every appearance ([[team.appears]], [[append]]), (3b) orders, free-match tabs, route nodes, talks, chains,
-- challenges, level maps, the free match's class levels, game drop tables, the grid's home stadiums, (4) every
-- [[remove]], (5) the grid's
-- seasons / categories / unlocks, (6) the previewed rosters within the menus' reach; each in load order. A field two
-- mods set to different values is a conflict: noted, the mod that loads later wins.
--
-- input = { files = { { file, mod, load_index, value = <teams file> } }, mods = { { id, load_index, requires } },
--           characters = { { key, chara, param } }, music = { { "<mod>.<song>", bgm } },
--           defaults = { team = <defaults\team.toml> | team_err, talk = … | talk_err },
--           difficulties = { declared, list = { { id, difficulty, contexts, badge, level, order, name } } },
--           fm_classes = { classes = { … } | nil, notes = { { lvl, msg } } }, lang = { source, build_default } }
-- returns the team type's value (team_engine::Built without `files`: the T2B tables are served by the row API, the
-- other files by the native part).

local T = require "lib/team_util"
local U = require "lib/util"
local TC = require "team/tc"
local Core = require "team/core"
local Lists = require "team/lists"
local Route = require "team/route"
local Talk = require "team/talk"
local Chain = require "team/chain"
local Challenge = require "team/challenge"
local LevelMap = require "team/level_map"
local FreeMatch = require "team/free_match"
local Bb = require "team/bb"
local GameDrops = require "team/game_drops"

local LIST_FREE, LIST_BB = Lists.LIST_FREE, Lists.LIST_BB

-- `defaults\team.toml` value at `path` (dotted), or nil, the reader's error
local function dval(team, err, path)
  if team == nil then return nil, err end
  local cur = team
  for p in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then cur = nil break end
    cur = cur[p]
  end
  if cur == nil then return nil, "defaults\\team.toml: no `" .. path .. "` (the framework mod ships it; reinstall it)" end
  return cur
end

local function dstring(team, err, path)
  local v, e = dval(team, err, path)
  if v == nil then return nil, e end
  if type(v) ~= "string" then return nil, "defaults\\team.toml: `" .. path .. "` is not a string (" .. tostring(v) .. ")" end
  return v
end

-- the file declares nothing but lists (extension points)
local function has_levels(fm)
  if fm == nil or fm.Difficulties == nil then return false end
  for _, c in ipairs(fm.Difficulties) do
    if type(c) == "table" and c.level ~= nil then return true end
  end
  return false
end

local function vrfw_empty(v)
  v = v or {}
  return not has_levels(v.FreeMatch) and #(v.RouteNode or {}) == 0 and #(v.Talk or {}) == 0 and #(v.LevelMap or {}) == 0
    and #(v.Chain or {}) == 0 and #(v.Category or {}) == 0 and #(v.Season or {}) == 0 and #(v.FreeMatchTab or {}) == 0
    and #(v.FreeMatchTabBar or {}) == 0 and #(v.GameTab or {}) == 0 and #(v.MatchChallenge or {}) == 0 and v.BbUnlock == nil
    and #(v.GameDrops or {}) == 0 and #(v.SpiritDrops or {}) == 0
end

local function only_lists(f)
  return #(f.loadout or {}) == 0 and #(f.team or {}) == 0 and #(f.edit or {}) == 0 and #(f.remove or {}) == 0
    and #(f.append or {}) == 0 and #(f.order or {}) == 0 and vrfw_empty(f.vrfw)
end

local function is_empty(f)
  return #(f.list or {}) == 0 and only_lists(f)
end

-- ------------------------------------------------------------------------------------------------- characters

local CHARA_BASE_PREFIX = "data/common/gamedata/character/chara_base_"
local CHARA_PARAM_PREFIX = "data/common/gamedata/character/chara_param_"
-- chara_param: the 9 move slots (move, learn level) from col 11; the off-pitch kit (the character type's columns)
local CP_MOVES, CP_MOVE_SLOTS, CP_OFFPITCH_KIT = 11, 9, 66

local function load_charas(created, cols)
  local bk, e = VRFW.rows.key(CHARA_BASE_PREFIX)
  if not bk then return nil, e end
  local pk, e2 = VRFW.rows.key(CHARA_PARAM_PREFIX)
  if not pk then return nil, e2 end
  local c = { by_name = {}, base = {}, cards = {}, card = {}, cols = {}, created = {}, learn = {}, pairs = {}, offpitch = {},
    series = {}, gender = {}, belong = {} }
  local b, e3 = VRFW.rows.open(bk)
  if not b then return nil, e3 end
  local hb = VRFW.crc32("CHARA_BASE_INFO")
  for _, x in ipairs(b:entries(0, b:len())) do
    if x.hash == hb then
      local v = x.values
      local id = TC.uint(v, 0)
      if id then
        local n = TC.text(v, 1) or ""
        c.by_name[n] = id
        c.base[id] = { name = n, name_text = TC.uint(v, 3) or 0 }
        c.series[id] = TC.uint(v, 15) or 0
        c.gender[id] = TC.uint(v, 11) or 0
        local bl = {}
        for k, col in ipairs { 16, 17, 18 } do
          local t = TC.uint(v, col)
          bl[k] = (t ~= nil and t ~= 4294967295) and t or 0
        end
        c.belong[id] = bl
      end
    end
  end
  local p, e4 = VRFW.rows.open(pk)
  if not p then return nil, e4 end
  local hp = VRFW.crc32("CHARA_PARAM_INFO")
  for _, x in ipairs(p:entries(0, p:len())) do
    if x.hash == hp then
      local v = x.values
      local card, ch = TC.uint(v, 0), TC.uint(v, 1)
      if card and ch then
        c.cards[ch] = c.cards[ch] or {}
        table.insert(c.cards[ch], card)
        c.card[card] = { chara = ch, elem = TC.int(v, 2) or 0, pos = TC.int(v, 3) or 0 }
        for _, k in ipairs(cols) do
          local val = TC.int(v, k)
          if val then
            c.cols[card] = c.cols[card] or {}
            c.cols[card][k] = val
          end
        end
        local mv, seen = {}, {}
        for k = 0, CP_MOVE_SLOTS - 2 do
          local id = TC.int(v, CP_MOVES + 2 * k)
          if id and id ~= 0 and id ~= -1 and not seen[T.u32(id)] then
            seen[T.u32(id)] = true
            mv[#mv + 1] = T.u32(id)
          end
        end
        local kit = TC.uint(v, CP_OFFPITCH_KIT)
        if kit and kit ~= 0 and kit ~= 4294967295 and c.offpitch[ch] == nil then c.offpitch[ch] = kit end
        c.learn[card] = mv
        local pr = {}
        for k = 0, 5 do
          pr[k + 1] = { TC.uint(v, CP_MOVES + 2 * k) or 0, TC.uint(v, CP_MOVES + 2 * k + 1) or 0 }
        end
        c.pairs[card] = pr
      end
    end
  end
  for _, x in ipairs(created) do c.created[x.key] = { chara = x.chara, card = x.param } end
  return c
end

-- ------------------------------------------------------------------------------------------------- difficulties

-- the match difficulties of the active mods (team_engine difficulty.rs, read natively): exists / of / ids_text / retain
local function difficulties(d)
  local D = { declared = d.declared, list = d.list or {} }
  function D.exists(ctx, n)
    if not D.declared then return true end
    for _, x in ipairs(D.list) do
      if x.difficulty == n and T.contains(x.contexts or {}, ctx) then return true end
    end
    return false
  end
  function D.of(ctx)
    local out = {}
    for _, x in ipairs(D.list) do
      if T.contains(x.contexts or {}, ctx) then out[#out + 1] = x end
    end
    return out
  end
  function D.ids_text(ctx)
    local set = {}
    for _, x in ipairs(D.of(ctx)) do set[x.difficulty] = true end
    local ks = T.keys(set)
    local p = {}
    for i, k in ipairs(ks) do p[i] = T.d(k) end
    return table.concat(p, ", ")
  end
  function D.retain(ctx, v, what)
    local out = {}
    for _, x in ipairs(v) do
      if D.exists(ctx, x) then
        out[#out + 1] = x
      else
        VRFW.log.warn(string.format("%s: difficulty %d does not exist with the active mods (%s: %s; defaults\\match_difficulty.toml): left out, not built", what, x, ctx, D.ids_text(ctx)))
      end
    end
    return out
  end
  return D
end

-- ------------------------------------------------------------------------------------------------- the build

local function build_teams(input, X, out, fm)
  local raw = {}
  for k, f in ipairs(input.files or {}) do
    if not is_empty(f.value) then raw[#raw + 1] = { f = f, k = k } end
  end
  T.sort(raw, function(a, b) return a.f.load_index < b.f.load_index end)
  local files = {}
  for k, x in ipairs(raw) do files[k] = x.f end
  X.files = files
  for _, f in ipairs(files) do
    if not T.contains(out.mods, f.mod) then out.mods[#out.mods + 1] = f.mod end
  end
  -- (0) the lists (extension points): no game data is read for them
  local lists = {}
  for _, f in ipairs(files) do
    for _, l in ipairs(f.value.list or {}) do
      local key, e = VRFW.ids.own(f.mod, l.id)
      if not key then
        VRFW.log.error(f.file .. ": list `" .. l.id .. "`: " .. e .. " (skipped)")
      elseif l.kind == "free_match_piece" and (l.piece == nil or l.template_game == nil) then
        VRFW.log.error(f.file .. ": list " .. key .. ": a free_match_piece list needs `piece` and `template_game` (skipped)")
      elseif l.kind == "pool_table" and (l.template_game == nil or l.pool == nil) then
        VRFW.log.error(f.file .. ": list " .. key .. ": a pool_table list needs `template_game` and `[list.pool]` (skipped)")
      else
        if l.pool ~= nil and l.kind ~= "pool_table" then
          VRFW.log.warn(f.file .. ": list " .. key .. ": `pool` is only read by a pool_table list (ignored)")
        end
        if lists[key] then VRFW.log.warn(f.file .. ": list " .. key .. " declared twice: the last declaration is used") end
        local label = {}
        for _, k in ipairs(T.keys(l.label or {})) do
          local n = VRFW.lang.norm_or_all(k)
          if n then label[n] = l.label[k] end
        end
        lists[key] = { key = key, owner = f.mod, kind = l.kind, piece = l.piece ~= nil and T.id(l.piece) or nil,
          template_game = l.template_game, level = l.level, format = l.format, tier = l.tier, label = label,
          order = l.order or {}, unlock = l.unlock, condition = l.condition or {}, pool = l.pool }
      end
    end
  end
  for _, k in ipairs(T.keys(lists)) do out.lists[#out.lists + 1] = lists[k] end
  local all_lists = true
  for _, f in ipairs(files) do
    if not only_lists(f.value) then all_lists = false break end
  end
  if all_lists then
    if not T.is_empty(lists) then
      VRFW.log.info(string.format("%d list(s) published (%s): no team declared, nothing is built", T.count(lists), table.concat(T.keys(lists), ", ")))
    end
    return false
  end
  local team_key, e = VRFW.team.table_key("data/common/gamedata/team/team_config_")
  if not team_key then
    VRFW.log.error(e .. ": no team data is built")
    return false
  end
  X.team_key = team_key
  local raw_tc, e2 = VRFW.team.tc_read(team_key)
  if not raw_tc then
    VRFW.log.error(e2 .. ": no team data is built")
    return false
  end
  local TI, TM, LO = TC.columns(team_key)
  X.TI, X.TM, X.LO = TI, TM, LO
  X.tc = TC.new(raw_tc, TI, TM, LO)
  local star = {}
  for _, l in pairs(lists) do
    if l.pool ~= nil and l.pool.star_column ~= nil then star[l.pool.star_column] = true end
  end
  local ch, e3 = load_charas(input.characters or {}, T.keys(star))
  if not ch then
    VRFW.log.error(e3 .. ": no team data is built")
    return false
  end
  X.ch = ch
  X.lists = lists
  for _, f in ipairs(files) do X.load_index[f.mod] = f.load_index end

  Core.install(X)
  Lists.install(X)
  Route.install(X)
  Talk.install(X)
  Chain.install(X)
  Challenge.install(X)
  LevelMap.install(X)
  FreeMatch.install(X)
  Bb.install(X)
  GameDrops.install(X)

  -- a mod team that a [[remove]] mode = "delete" names is never created
  for _, f in ipairs(files) do
    for _, r in ipairs(f.value.remove or {}) do
      if r.mode == "delete" then
        local k = r.team:find(".", 1, true) and r.team or (f.mod .. "." .. r.team)
        local found = false
        for _, g in ipairs(files) do
          for _, t in ipairs(g.value.team or {}) do
            if g.mod .. "." .. t.name == k then found = true break end
          end
          if found then break end
        end
        if found then X.deleted_new[k] = true end
      end
    end
  end
  -- (0b) the mods' technique loadouts, in declaration order (members use them by id)
  local filler = X.tc:loadout_filler()
  for _, f in ipairs(files) do
    for _, l in ipairs(f.value.loadout or {}) do
      local id = T.id(l.id)
      local what = f.file .. ": loadout " .. T.idref_text(l.id)
      local levels = l.levels or {}
      if #l.moves > 6 or (#levels > 0 and #levels ~= #l.moves) then
        VRFW.log.error(what .. ": at most 6 moves, and one level per move (skipped)")
      else
        local pairs_ = {}
        for k, x in ipairs(l.moves) do pairs_[k] = { T.id(x), levels[k] or 1 } end
        local row = X.tc:loadout_exact(id, pairs_, filler)
        if not row then
          VRFW.log.error(what .. ": team_config has no loadout row to shape it (skipped)")
        else
          X.claim(id, "loadout", f.mod, T.dbg_pairs(pairs_), what)
          X.tc:put_loadout(row)
        end
      end
    end
  end
  -- (1) new teams, in declaration order (the registry remembers their ids, a mod's `key` pins them)
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.team or {}) do
      local k = f.mod .. "." .. d.name
      if X.deleted_new[k] then
        VRFW.log.info(f.file .. ": " .. k .. " is deleted by a [[remove]]: not created")
      else
        local err = X.create(f.mod, f.file, d, f.value.default_lang)
        if err then VRFW.log.error(f.file .. ": team `" .. d.name .. "`: " .. err .. " (not created)") end
      end
    end
  end
  -- (2) edits
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.edit or {}) do
      local req = d.if_mod and T.trim(d.if_mod) or ""
      local skip = false
      if req ~= "" then
        local active = false
        for _, m in ipairs(X.mods) do if m.id == req then active = true break end end
        if not active then
          VRFW.log.info(f.file .. ": edit " .. d.team .. ": if_mod " .. req .. " is not active (skipped)")
          skip = true
        end
      end
      if not skip then
        local t, te = X.team_ref(d.team, f.mod)
        if t == nil then
          VRFW.log.error(f.file .. ": edit: " .. te .. " (skipped)")
        else
          local what = f.file .. ": edit " .. X.label(t)
          local is_new = X.created_by_id[X.tc:id_of(t)] ~= nil
          X.apply(f.mod, f.file, what, t, d, d.default_lang or f.value.default_lang, is_new)
          for _, a in ipairs(d.appears or {}) do
            local t2, e4 = X.team_ref(d.team, f.mod)
            local ok
            if t2 ~= nil then ok, e4 = X.appear(f.mod, f.file, t2, a) end
            if not ok then VRFW.log.error(what .. ": appears in `" .. a.list .. "`: " .. e4 .. " (skipped)") end
          end
        end
      end
    end
  end
  -- (3) appearances of the new teams + [[append]]
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.team or {}) do
      if #(d.appears or {}) > 0 then
        local key = f.mod .. "." .. d.name
        local c = X.created[key]
        if c then
          for _, a in ipairs(d.appears) do
            local t = X.tc:find(c.id)
            local ok, e4
            if t == nil then e4 = "row gone" else ok, e4 = X.appear(f.mod, f.file, t, a) end
            if not ok then VRFW.log.error(f.file .. ": " .. key .. ": appears in `" .. a.list .. "`: " .. e4 .. " (skipped)") end
          end
        end
      end
    end
    for _, a in ipairs(f.value.append or {}) do
      local t, e4 = X.team_ref(a.team, f.mod)
      local ok
      if t ~= nil then ok, e4 = X.appear(f.mod, f.file, t, a) end
      if not ok then VRFW.log.error(f.file .. ": append " .. a.team .. " to `" .. a.list .. "`: " .. e4 .. " (skipped)") end
    end
  end
  -- (3b) the order of built-in lists ([[order]]) and of the published tab lists (`order`, `unlock`)
  for _, f in ipairs(files) do
    for _, o in ipairs(f.value.order or {}) do
      local ok, e4 = X.order_list(f.mod, o)
      if not ok then VRFW.log.error(f.file .. ": order of `" .. o.list .. "`: " .. e4 .. " (skipped)") end
    end
  end
  for _, k in ipairs(T.keys(X.lists)) do
    local l = X.lists[k]
    if l.kind == "free_match_piece" and #l.order > 0 then
      local ok, e4 = X.order_tab(l)
      if not ok then VRFW.log.error("list " .. l.key .. ": order / unlock: " .. e4) end
    end
  end
  -- (3b') the free-match tabs: tab numbers written as the routeType of their pieces
  local fm_tabs, fm_bars = X.free_match_tabs(files)
  -- (3b'') [[VRFW.GameTab]]: retail games filed under another retail tab (after the tabs and their difficulty rows)
  local game_tabs = X.game_tabs(files)
  -- (3c) Chronicle board side nodes (their teams exist now; before removals: a hidden team keeps its node)
  local route_nodes, route_roads = X.route_nodes(files)
  -- (3d) talk scenes ([[VRFW.Talk]]) and the nodes' pre-match / post-win talks
  local talks = X.talks(files)
  X.node_talks(files, route_nodes, talks)
  -- (3d') match chains ([[VRFW.Chain]]): their node games and talk ids
  local chains = X.chains(files, talks)
  -- (3d'') match challenges ([[VRFW.MatchChallenge]])
  local challenges = X.match_challenges(files, route_nodes, chains, fm_tabs)
  -- (3e) [[VRFW.LevelMap]]: Chronicle rows re-levelled (after the nodes: their rows are final)
  X.level_maps(files)
  -- (3e') [VRFW.FreeMatch] class levels on every free-match game's rows
  X.free_match_copy(fm)
  X.free_match_levels(fm)
  -- (3e'') [[VRFW.GameDrops]]: the drop tables of the games' rows (every game exists now: nodes, chains)
  X.game_drops(files)
  -- (3f) the Estadio BB rows' stadium = their team's home stadium (after every edit and appearance)
  X.bb_home_stadiums()
  -- (4) removals
  for _, f in ipairs(files) do
    for _, d in ipairs(f.value.remove or {}) do
      local key = d.team:find(".", 1, true) and d.team or (f.mod .. "." .. d.team)
      if not (d.mode == "delete" and X.deleted_new[key]) then
        local ok, e4 = X.remove(f.mod, f.file, d)
        if not ok then VRFW.log.error(f.file .. ": remove " .. d.team .. ": " .. e4 .. " (skipped)") end
      end
    end
  end
  -- (5) the grid's categories (after removals); the seasons first (a category may sort its rows by season)
  local bb_seasons, all_text, all_icon = X.bb_seasons(files)
  local bb_categories
  bb_categories, bb_seasons = X.bb_categories(files, chains, bb_seasons)
  -- (5b) «win it to unlock it»
  local bb_unlock = X.bb_unlock(files, route_nodes, chains)
  -- (6) the previewed teams' rosters within the menus' reach
  if X.tc.changed then X.front_preview_members() end

  -- ---- outputs
  local nfiles = 0
  if X.tc.changed then
    local ok, we = X.tc:write()
    if ok then nfiles = nfiles + 1 else VRFW.log.error(we .. ": that table is not served") end
  end
  local gens = {}
  for _, g in ipairs(X.texts.sorted(function(m) return X.load_index[m] or 0 end)) do
    gens[#gens + 1] = { mod_id = g.mod, load_index = X.load_index[g.mod] or 0, default_lang = g.default, texts = g.rows }
  end
  -- match rules -> one GenRules per mod
  local rules = {}
  for tid, meta in pairs(X.meta) do
    if not (X.hidden[tid] and X.tc:find(tid) == nil) then
      if meta.rules then
        local m, r = meta.rules[1], meta.rules[2]
        rules[m] = rules[m] or { mod_id = m, load_index = X.load_index[m] or 0, games = {}, teams = {}, homes = {} }
        table.insert(rules[m].teams, { string.format("0x%08X", tid), r })
      end
      -- the team's home stadium (`stadium = …`): the match engine's pachangas with `rival_home = true` play there
      -- (`stadium_fallback`: the chain's `stadium` when one declares it, else the fallback)
      local home, field = meta.stadium, "stadium"
      if home == nil and meta.stadium_fallback ~= nil then home, field = X.home_stadium(tid), "stadium_fallback" end
      if home ~= nil then
        local c = X.claims[tid] and X.claims[tid][field]
        local m = c and c.by or ""
        if m ~= "" then
          rules[m] = rules[m] or { mod_id = m, load_index = X.load_index[m] or 0, games = {}, teams = {}, homes = {} }
          table.insert(rules[m].homes, { string.format("0x%08X", tid), home })
        end
      end
    end
  end
  local rlist = {}
  for _, m in ipairs(T.keys(rules)) do
    local g = rules[m]
    T.sort(g.teams, function(a, b)
      if a[1] ~= b[1] then return VRFW.less(a[1], b[1]) end
      return VRFW.less(a[2], b[2])
    end)
    T.sort(g.homes, function(a, b)
      if a[1] ~= b[1] then return VRFW.less(a[1], b[1]) end
      return a[2] < b[2]
    end)
    rlist[#rlist + 1] = g
  end
  T.sort(rlist, function(a, b) return a.load_index < b.load_index end)
  local ntext = 0
  for _, g in ipairs(gens) do ntext = ntext + #g.texts end
  VRFW.log.info(string.format("%d mod(s) with teams (%s): %d new team(s), %d list entr(y/ies), %d file(s) built, %d text row(s) for the text engine, %d hidden team(s)",
    #out.mods, table.concat(out.mods, ", "), T.count(X.created), #X.entries, nfiles, ntext, T.count(X.hidden)))
  out.conflicts = X.conflicts
  out.gentext = gens
  out.rules = rlist
  out.entries = X.entries
  out.hidden = T.keys(X.hidden)
  for _, k in ipairs(T.keys(X.created)) do out.created[#out.created + 1] = X.created[k] end
  out.route_nodes = route_nodes
  out.route_roads = route_roads
  out.chains = chains
  out.talks = {}
  for _, t in ipairs(talks) do out.talks[#out.talks + 1] = { t.key, t.id } end
  out.bb_categories = bb_categories
  out.bb_seasons = bb_seasons
  out.bb_season_all = all_text
  out.bb_season_all_icon = all_icon
  out.bb_retail = X.bb_game_order or {}
  out.bb_unlock = bb_unlock
  out.free_match_tabs = fm_tabs
  out.free_match_bars = fm_bars
  out.game_tabs = game_tabs
  out.challenges = challenges.list
  out.challenge_games = challenges.games
  out.challenge_data = challenges.data
  return true
end

return function(input)
  local defs = input.defaults or {}
  local team, team_err = defs.team, defs.team_err
  -- the game-data values of defaults\team.toml the build reads
  local D = {}
  for _, k in ipairs { "team.template_rows", "bb_copy", "bb_row", "bgm", "free_match_tabs", "bb_unlock", "route_nodes" } do
    local v, e = dval(team, team_err, k)
    if v == nil then
      VRFW.log.error(e .. ": no team data is built")
      return { mods = {}, created = {}, lists = {}, entries = {}, hidden = {}, gentext = {}, rules = {}, conflicts = {} }
    end
    D[k:gsub("%.", "_")] = v
  end
  D.template_rows = D.team_template_rows
  D.free_match_template, D.free_match_template_err = dstring(team, team_err, "free_match.template_game")
  D.chain_template, D.chain_template_err = dstring(team, team_err, "chain.template_game")
  D.bb_pages, D.bb_pages_err = team and team.bb_pages, team_err
  D.talk, D.talk_err = defs.talk, defs.talk_err

  local X = {
    input = input, D = D, mods = input.mods or {}, requires = {}, load_index = {}, lang = input.lang or {},
    diffs = difficulties(input.difficulties or {}),
    music_lib = input.music or {},
    claims = {}, conflicts = {}, created = {}, created_by_id = {}, created_by_internal = {}, meta = {},
    texts = U.text_groups(), lists = {}, entries = {}, hidden = {}, deleted_new = {}, touched = {}, full_roster = false,
    bgm_rows = {}, pools = {}, noun_cache = {}, bb_copies = {}, bb_cat = {}, bb_src = {}, bb_stadium_set = {}, bb_image_set = {}, based_on = {}, same_as = {},
    bb_season = {}, bb_after = {}, cat_legacy = {},
    -- route-node games cloned from a game: { game, template, set = {difficulty = true} } ([[VRFW.LevelMap]] Clones)
    node_clones = {},
  }
  for _, m in ipairs(X.mods) do X.requires[m.id] = m.requires or {} end

  local out = { mods = {}, created = {}, lists = {}, entries = {}, hidden = {}, gentext = {}, rules = {}, conflicts = {},
    route_nodes = {}, route_roads = {}, chains = {}, bb_categories = {}, bb_seasons = {}, bb_season_all = "",
    bb_season_all_icon = "", bb_retail = {}, bb_unlock = {}, free_match_tabs = {}, free_match_bars = {}, challenges = {},
    challenge_games = {}, challenge_data = { cards = {}, charas = {} }, talks = {} }

  -- [VRFW.FreeMatch]: read from every file (also the ones that declare nothing else); its class levels re-level the
  -- free-match games' rows inside the team build
  FreeMatch.install_rules(X)
  local rules = X.fm_rules(input.files or {})
  -- the classes offered: only the ones that exist with the active mods (VRFW.MatchDifficulty, context free_match); no
  -- mod declaring [VRFW.FreeMatch] Difficulties = the classes ARE the effective set (levels, badges)
  local declared = false
  for _, f in ipairs(input.files or {}) do
    local fm = f.value.vrfw and f.value.vrfw.FreeMatch
    if fm and fm.Difficulties ~= nil then declared = true break end
  end
  if not declared then
    local c = input.fm_classes or {}
    for _, n in ipairs(c.notes or {}) do
      local lvl = n[1]
      if lvl == "Error" then VRFW.log.error(n[2]) elseif lvl == "Warn" then VRFW.log.warn(n[2]) else VRFW.log.info(n[2]) end
    end
    if c.classes then
      rules.difficulties = {}
      for k, x in ipairs(c.classes) do rules.difficulties[k] = x.class end
      rules.classes = c.classes
    end
  end
  local keep = X.diffs.retain("free_match", T.acopy(rules.difficulties), "[vrfw.FreeMatch] Difficulties")
  if #keep == 0 then
    VRFW.log.error("[vrfw.FreeMatch] Difficulties: no class exists with the active mods (free_match: " .. X.diffs.ids_text("free_match") .. "): the classes are kept")
  else
    local ks = {}
    for _, x in ipairs(keep) do ks[x] = true end
    local d2, c2 = {}, {}
    for _, x in ipairs(rules.difficulties) do if ks[x] then d2[#d2 + 1] = x end end
    for _, x in ipairs(rules.classes) do if ks[x.class] then c2[#c2 + 1] = x end end
    rules.difficulties, rules.classes = d2, c2
  end
  build_teams(input, X, out, rules)
  out.free_match = rules
  if rules.orb_best then
    local label, e = VRFW.team.orb_layout()
    if label then
      VRFW.log.info("[vrfw.FreeMatch] Orb = \"best\": data/common/menu/30_vsroute/vsroute01/vsroute01_06b/vsroute01_06b.g4pkm (from " .. label .. ") has the class orbs on the single-orb slot")
    else
      VRFW.log.error("[vrfw.FreeMatch] Orb = \"best\": " .. e .. ": the rows show the retail orbs' places")
    end
  end
  return out
end
