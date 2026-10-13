-- The Estadio BB / Bahía Batalla grid (`bb_stadium`, docs/framework/bb-pages.md; was team_engine bb_category.rs and
-- bb_unlock.rs): its season groups, its categories (tabs) with each one's rows in order (a mod's copy of a team an
-- earlier category lists leaves the table), and «win it to unlock it» (every row whose team has a Chronicle
-- equivalent locked until the player wins that match).
local T = require "lib/team_util"
local TC = require "team/tc"
local B = {}

local LIST_BB = "bb_stadium"
local ENJOY_ROW = "ENJOY_MODE_TEAM_INFO"
local DEFAULTS_OWNER = "vr_framework"
local SERIES_KEY = "data/common/gamedata/character/chara_series_config.cfg.bin"
-- the rules a category takes rows by, and the sort keys of its rows (vr_framework::bb_pages)
local RULES = { "game", "chain", "mod" }
local SORT_SEASON, SORT_SOURCE, SORT_NAME = "season", "source_order", "name"
local SORT_KEYS = { SORT_SEASON, SORT_SOURCE, SORT_NAME }
-- the framework's byte flag of the «never true» condition of a chain-only row (never written: it reads 0), and the
-- id prefix of a locked row's own hint text (menu_text row `vrfw_bb_unlock_<team hex>`, built per team)
local CHAIN_LOCK_FLAG, CHAIN_LOCK_VALUE = "VRFW_BB_CHAIN_LOCK", 211
local TEXT_ROW = "vrfw_bb_unlock"

-- the season of a roster: the highest series type with at least 2 starters, else the highest one any starter has
local function roster_season(types)
  local count = {}
  for _, t in ipairs(types) do
    if t > 0 then count[t] = (count[t] or 0) + 1 end
  end
  local ks = T.keys(count)
  for k = #ks, 1, -1 do
    if count[ks[k]] >= 2 then return ks[k] end
  end
  return ks[#ks]
end

local function fill(template, ty)
  return T.replace(template, "{type}", T.pad(ty, 2))
end

-- a `source_order` key: { root, steps }; compared root first, then the steps position by position (missing = 0)
local function key_cmp(a, b)
  if a.root ~= b.root then return a.root < b.root and -1 or 1 end
  local n = math.max(#a.steps, #b.steps)
  for i = 1, n do
    local x, y = a.steps[i] or 0, b.steps[i] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  return 0
end

-- the categories of `defaults\team.toml` [bb_pages] as declarations (its keys are written PascalCase)
local function category_of(c)
  return { id = c.Id, list = c.List, text = c.Text, icon = c.Icon, order = c.Order, rule = c.Rule, aliases = c.Aliases or {}, sort = c.Sort }
end

function B.install(X)
  -- [bb_pages] of defaults\team.toml: { category, seasons, dedupe, chronicle_unlock }
  function X.bb_defaults()
    if X.D.bb_pages_err ~= nil and X.D.bb_pages == nil then
      VRFW.log.warn(X.D.bb_pages_err .. ": the framework's grid categories / seasons are left out")
      return { category = {} }
    end
    local p = X.D.bb_pages
    if p == nil then return { category = {} } end
    if type(p) ~= "table" or (p.category ~= nil and type(p.category) ~= "table") or (p.seasons ~= nil and type(p.seasons) ~= "table") then
      VRFW.log.error("defaults\\team.toml [bb_pages]: invalid section (the framework's grid categories / seasons are left out)")
      return { category = {} }
    end
    local out = { category = {}, seasons = p.seasons, dedupe = p.dedupe, chronicle_unlock = p.chronicle_unlock }
    for k, c in ipairs(p.category or {}) do out.category[k] = category_of(c) end
    return out
  end

  function X.bb_unlock_on()
    local d = X.bb_defaults()
    return d.chronicle_unlock ~= false
  end

  -- the season groups of the grid's carousel with rows (carousel order) and the text key / icon of «every season»
  function X.bb_seasons(files)
    local d = X.bb_defaults().seasons or {}
    local all_text, all_icon = d.all_text or "", d.all_icon or ""
    local en = X.enjoy()
    if not en then return {}, all_text, all_icon end
    -- the game's series: id -> type
    local types = {}
    if d.from_game then
      local r, e = VRFW.team.rdbn(SERIES_KEY)
      if r then
        local l, e2 = r:list("m_charaSeriesInfoList")
        local fid, fty
        if l then
          fid, e2 = r:field(l, "charaSeriesId")
          if fid then fty, e2 = r:field(l, "charaSeriesType") end
        end
        if l and fid and fty then
          for row = 0, r:len(l) - 1 do
            local id, ty = r:u32(l, row, fid), r:u32(l, row, fty)
            if id and ty then types[id] = T.i32(ty) end
          end
        else
          VRFW.log.warn(e2 .. ": no season derived from the game's series")
        end
      else
        VRFW.log.warn(e .. ": no season derived from the game's series")
      end
    end
    local tid = d.id or "series_{type}"
    local ttext, ticon = d.text or "", d.icon or ""
    local list = {}
    local kinds = {}
    for _, t in pairs(types) do if t > 0 then kinds[t] = true end end
    for _, t in ipairs(T.keys(kinds)) do
      list[#list + 1] = { DEFAULTS_OWNER, { id = fill(tid, t), text = ttext ~= "" and fill(ttext, t) or nil, icon = ticon ~= "" and fill(ticon, t) or nil, order = t * 10 } }
    end
    for _, f in ipairs(files) do
      for _, c in ipairs(f.value.vrfw.Season or {}) do
        local old
        for _, x in ipairs(list) do if x[2].id == c.id then old = x[2] break end end
        if old then
          if c.text ~= nil then old.text = c.text end
          if c.icon ~= nil then old.icon = c.icon end
          if c.order ~= nil then old.order = c.order end
        elseif not T.is_word(c.id) then
          VRFW.log.error(f.file .. ": season `" .. c.id .. "`: id must be a-z 0-9 _ (skipped)")
        else
          list[#list + 1] = { f.mod, { id = c.id, text = c.text, icon = c.icon, order = c.order } }
        end
      end
    end
    T.sort(list, function(a, b) return (a[2].order or 1000) < (b[2].order or 1000) end)
    local out = {}
    for k, x in ipairs(list) do
      local c = x[2]
      out[k] = { key = x[1] .. "." .. c.id, id = c.id, text = c.text or "", icon = c.icon or "", rule = "", order = c.order or 1000, teams = {}, by_lang = {} }
    end
    local unknown, none = {}, 0
    local TM = X.TM
    for _, i in ipairs(en:rows(ENJOY_ROW)) do
      local team = en:uint(i, 0) or 0
      local named = X.bb_season[team]
      local k
      if named then
        for kk, x in ipairs(out) do if x.id == named[2] then k = kk break end end
        if not k then unknown[named[2] .. " (named by " .. named[1] .. ")"] = true end
      end
      if not k then
        local starters = {}
        local t = X.tc:find(team)
        if t ~= nil then
          local s, e = X.tc:member_range(t)
          for mi = s, e - 1 do
            local row = X.tc:member(mi).m
            local slot = TC.uint(row, TM.SLOT)
            if slot ~= nil and slot <= 10 then
              local card = TC.uint(row, TM.PARAM)
              local c = card and X.ch.card[card]
              local h = c and X.ch.series[c.chara]
              local ty = h and types[h]
              if ty then starters[#starters + 1] = ty end
            end
          end
        end
        local ty = roster_season(starters)
        if ty then
          local want = fill(tid, ty)
          for kk, x in ipairs(out) do if x.id == want then k = kk break end end
        end
      end
      if k then table.insert(out[k].teams, team) else none = none + 1 end
    end
    if not T.is_empty(unknown) then
      VRFW.log.warn(LIST_BB .. ": unknown season " .. table.concat(T.keys(unknown), ", ") .. ": those rows get the season of their roster")
    end
    local summary, kept = {}, {}
    for _, c in ipairs(out) do
      if #c.teams > 0 then
        summary[#summary + 1] = c.id .. " " .. #c.teams
        kept[#kept + 1] = c
      end
    end
    local tail = none > 0 and string.format(" (%d row(s) in no season: only under every season)", none) or ""
    VRFW.log.info(LIST_BB .. ": seasons: " .. table.concat(summary, ", ") .. tail)
    return kept, all_text, all_icon
  end

  -- merge one declaration into the list (same id = field-wise change)
  local function merge(list, m, d)
    for _, x in ipairs(list) do
      if x[2].id == d.id then
        local old = x[2]
        if d.list ~= nil then old.list = d.list end
        if d.text ~= nil then old.text = d.text end
        if d.icon ~= nil then old.icon = d.icon end
        if d.order ~= nil then old.order = d.order end
        if d.rule ~= nil then old.rule = d.rule end
        if d.sort ~= nil then old.sort = d.sort end
        for _, a in ipairs(d.aliases or {}) do
          if not T.contains(old.aliases, a) then old.aliases[#old.aliases + 1] = a end
        end
        return
      end
    end
    list[#list + 1] = { m, { id = d.id, list = d.list, text = d.text, icon = d.icon, order = d.order, rule = d.rule,
      aliases = T.acopy(d.aliases or {}), sort = d.sort and T.acopy(d.sort) or nil } }
  end

  -- the declared categories of bb_stadium (framework defaults, then the mods'), in tab order
  function X.bb_category_decls(files)
    local list = {}
    for _, c in ipairs(X.bb_defaults().category) do merge(list, DEFAULTS_OWNER, c) end
    for _, f in ipairs(files) do
      for _, c in ipairs(f.value.vrfw.Category or {}) do merge(list, f.mod, c) end
    end
    local out = {}
    for _, x in ipairs(list) do
      local m, c = x[1], x[2]
      local what = "category `" .. tostring(c.id) .. "` (" .. m .. ")"
      if type(c.id) ~= "string" or not T.is_word(c.id) then
        VRFW.log.error(what .. ": id must be a-z 0-9 _ (skipped)")
      elseif c.list ~= nil and T.trim(c.list) ~= LIST_BB then
        VRFW.log.error(what .. ": only the built-in list `" .. LIST_BB .. "` has categories (skipped)")
      else
        if c.rule ~= nil and c.rule ~= "" and c.rule ~= "none" and not T.contains(RULES, c.rule) then
          VRFW.log.error(what .. ": unknown rule `" .. c.rule .. "` (rules: " .. table.concat(RULES, ", ") .. "); it takes only the teams that name it")
        end
        if c.sort ~= nil then
          local bad, good = {}, {}
          for _, k in ipairs(c.sort) do
            if T.contains(SORT_KEYS, k) then good[#good + 1] = k else bad[#bad + 1] = k end
          end
          if #bad > 0 then
            VRFW.log.error(what .. ": unknown sort key(s) " .. table.concat(bad, ", ") .. " (keys: " .. table.concat(SORT_KEYS, ", ") .. "): ignored")
            c.sort = good
          end
        end
        out[#out + 1] = { m, c }
      end
    end
    -- stable: declaration order among equal `order`s
    T.sort(out, function(a, b) return (a[2].order or 100) < (b[2].order or 100) end)
    return out
  end

  -- the `source_order` sort key of every row (index in `ids`, 0-based)
  function X.bb_source_order(ids)
    local row_of = {}
    for r, t in ipairs(ids) do row_of[t] = r - 1 end
    local anchor = {}
    local bad = {}
    local copy_of = X.bb_copies
    for t, v in pairs(X.bb_after) do
      local r = row_of[t]
      if r ~= nil then
        local m, rf, step = v[1], v[2], v[3]
        local ti = X.team_ref(rf, m)
        local ar
        if ti ~= nil then
          local id = X.tc:id_of(ti)
          ar = row_of[id]
          if ar == nil and copy_of[id] then ar = row_of[copy_of[id]] end
        end
        if ar ~= nil and ar ~= r then
          anchor[r] = { ar, step }
        else
          bad[#bad + 1] = rf .. " (named by " .. m .. ")"
        end
      end
    end
    local out = {}
    for r = 0, #ids - 1 do
      local cur, steps, seen = r, {}, { [r] = true }
      while anchor[cur] do
        local a, step = anchor[cur][1], anchor[cur][2]
        if seen[a] then
          bad[#bad + 1] = "a sort_after / sort_before cycle at row " .. r
          cur = r
          steps = {}
          break
        end
        seen[a] = true
        steps[#steps + 1] = step
        cur = a
      end
      -- root first: the anchor's step, then the steps down to this row
      local rev = {}
      for k = #steps, 1, -1 do rev[#rev + 1] = steps[k] end
      out[r + 1] = { root = cur, steps = rev }
    end
    if #bad > 0 then
      VRFW.sort(bad)
      local d, last = {}, nil
      for _, x in ipairs(bad) do if x ~= last then d[#d + 1] = x end last = x end
      VRFW.log.warn(LIST_BB .. ": sort_after / sort_before not on the grid: " .. table.concat(d, ", ") .. " (those rows keep their place)")
    end
    return out
  end

  -- the shown name of every row's team in each of `langs`, as collation keys
  function X.bb_row_names(ids, langs)
    local copy_src = {}
    for s, c in pairs(X.bb_copies) do copy_src[c] = s end
    local out = {}
    for _, l in ipairs(langs) do out[l] = {} end
    for k, t in ipairs(ids) do
      local meta
      for _, x in ipairs { t, copy_src[t] } do
        local m = X.meta[x]
        if m and not T.is_empty(m.names) then meta = m.names break end
      end
      local ti = X.tc:find(t)
      local name_id = ti ~= nil and TC.uint(X.tc:info(ti), X.TI.NAME) or 0
      for _, lang in ipairs(langs) do
        local s = meta and VRFW.lang.pick(meta, lang) or nil
        if s == nil then
          local tbl = X.nouns(lang, "team_text")
          s = tbl and tbl[name_id] or ""
        end
        out[lang][k] = VRFW.team.name_key(s)
      end
    end
    return out
  end

  -- the grid without duplicates (`[bb_pages] dedupe`): a row a mod added whose team is the same team as a row of an
  -- EARLIER category is removed from the table; returns the kept rows (`ids`, `cat_of`; cat_of 1-based) and prunes
  -- the removed teams from `seasons`
  function X.bb_dedupe(decls, ids, cat_of, game, seasons)
    local lang = X.lang.build_default
    local names = X.bb_row_names(ids, { lang })[lang]
    local season_of = {}
    for k, s in ipairs(seasons) do for _, t in ipairs(s.teams) do season_of[t] = k end end
    local TM = X.TM
    local starters = {}
    for r, t in ipairs(ids) do
      local set = {}
      local ti = X.tc:find(t)
      if ti ~= nil then
        local s, e = X.tc:member_range(ti)
        for i = s, e - 1 do
          local row = X.tc:member(i).m
          local slot = TC.uint(row, TM.SLOT)
          local c = TC.uint(row, TM.PARAM)
          if slot ~= nil and slot <= 10 and c and c ~= 0 then set[c] = true end
        end
      end
      starters[r] = set
    end
    local function same_team(a, b)
      local sa, sb = season_of[ids[a]], season_of[ids[b]]
      if sa == sb then return true end
      -- another season: the same team if it fields most of the same starters
      local na, nb = T.count(starters[a]), T.count(starters[b])
      local small = math.min(na, nb)
      if small == 0 then return false end
      local inter = 0
      for c in pairs(starters[a]) do if starters[b][c] then inter = inter + 1 end end
      return inter * 2 >= small
    end
    -- the rows of each shown name
    local by_name, name_order = {}, {}
    for r, n in ipairs(names) do
      if n ~= "" then
        if not by_name[n] then by_name[n] = {} name_order[#name_order + 1] = n end
        table.insert(by_name[n], r)
      end
    end
    local first = {}
    for _, n in ipairs(name_order) do
      local rows = by_name[n]
      for _, r in ipairs(rows) do
        if not game[ids[r]] then
          local best
          for _, o in ipairs(rows) do
            if cat_of[o] < cat_of[r] and same_team(o, r) then
              if best == nil or cat_of[o] < best then best = cat_of[o] end
            end
          end
          first[r] = best
        end
      end
    end
    local homonyms = {}
    for _, n in ipairs(name_order) do
      local rows = by_name[n]
      for _, r in ipairs(rows) do
        if first[r] == nil and not game[ids[r]] then
          local earlier = false
          for _, o in ipairs(rows) do if cat_of[o] < cat_of[r] then earlier = true break end end
          if earlier then
            local s = season_of[ids[r]]
            homonyms[#homonyms + 1] = names[r] .. " (" .. (s and seasons[s].id or "no season") .. ")"
          end
        end
      end
    end
    if #homonyms > 0 then
      VRFW.sort(homonyms)
      VRFW.log.info(string.format("%s: %d row(s) share a name with a team of an earlier category but are another team (other season and starters; kept): %s", LIST_BB, #homonyms, table.concat(homonyms, ", ")))
    end
    local n = 0
    for r = 1, #ids do if first[r] ~= nil then n = n + 1 end end
    if n == 0 then return ids, cat_of end
    -- the summary: per category, and per the category that already lists them
    local per, sample = {}, {}
    for r = 1, #ids do
      if first[r] ~= nil then
        local k = cat_of[r] * 100000 + first[r]
        per[k] = per[k] or { cat_of[r], first[r], 0 }
        per[k][3] = per[k][3] + 1
        if #sample < 8 then
          local s = season_of[ids[r]]
          sample[#sample + 1] = names[r] .. " (" .. (s and seasons[s].id or "no season") .. ")"
        end
      end
    end
    local pers = {}
    for _, k in ipairs(T.keys(per)) do
      local x = per[k]
      pers[#pers + 1] = decls[x[1]][2].id .. " " .. x[3] .. " (already in " .. decls[x[2]][2].id .. ")"
    end
    -- the table: remove the rows, last first (entry indices of the earlier rows stay valid)
    local done = {}
    local failed
    local en = X.enjoy()
    if en then
      local rows = en:rows(ENJOY_ROW)
      for r = #rows, 1, -1 do
        if first[r] ~= nil then
          local i = rows[r]
          local b0, _, le = en:list(ENJOY_ROW)
          local ok, e
          if b0 then ok, e = pcall(en.remove_range, en, b0, i, i + 1, 1) else ok, e = false, le end
          if ok then
            done[r] = true
          else
            failed = "row " .. (r - 1) .. ": " .. tostring(e)
            break
          end
        end
      end
    end
    if failed then VRFW.log.warn(LIST_BB .. ": removing the duplicate rows stopped at " .. failed .. " (the rows before it stay)") end
    local removed = T.count(done)
    if removed > 0 then X.touched.enjoy = true end
    VRFW.log.info(string.format("%s: %d duplicate row(s) left out (a mod's copy of a team an earlier category already lists: same name, same season or most of the same starters; [bb_pages] dedupe): %s; e.g. %s",
      LIST_BB, removed, table.concat(pers, ", "), table.concat(sample, ", ")))
    local ids2, cat2 = {}, {}
    for r = 1, #ids do
      if not done[r] then
        ids2[#ids2 + 1] = ids[r]
        cat2[#cat2 + 1] = cat_of[r]
      end
    end
    local kept = {}
    for _, t in ipairs(ids2) do kept[t] = true end
    local seasons2 = {}
    for _, s in ipairs(seasons) do
      local tt = {}
      for _, t in ipairs(s.teams) do if kept[t] then tt[#tt + 1] = t end end
      s.teams = tt
      if #tt > 0 then seasons2[#seasons2 + 1] = s end
    end
    for k = #seasons, 1, -1 do seasons[k] = nil end
    for k, s in ipairs(seasons2) do seasons[k] = s end
    local summary = {}
    for _, c in ipairs(seasons) do summary[#summary + 1] = c.id .. " " .. #c.teams end
    VRFW.log.info(LIST_BB .. ": seasons without the duplicates: " .. table.concat(summary, ", "))
    return ids2, cat2
  end

  -- every row of the grid a category, and the categories with rows, each with its teams in its order; returns them
  -- and the (pruned) seasons
  function X.bb_categories(files, chains, seasons)
    local decls = X.bb_category_decls(files)
    if #decls == 0 then return {}, seasons end
    local en = X.enjoy()
    if not en then return {}, seasons end
    local ids = {}
    for _, i in ipairs(en:rows(ENJOY_ROW)) do ids[#ids + 1] = en:uint(i, 0) or 0 end
    local game = X.bb_game or {}
    local chain_teams = {}
    for _, c in ipairs(chains) do
      for _, n in ipairs(c.nodes or {}) do if n.team ~= 0 then chain_teams[n.team] = true end end
    end
    local copy_src = {}
    for s, c in pairs(X.bb_copies) do copy_src[c] = s end
    local function is_chain(t)
      local look = { t }
      if copy_src[t] then look[#look + 1] = copy_src[t] end
      local snap = T.acopy(look)
      for _, x in ipairs(snap) do
        local b = X.based_on[x]
        if b then
          look[#look + 1] = b
          if copy_src[b] then look[#look + 1] = copy_src[b] end
        end
      end
      for _, x in ipairs(look) do if chain_teams[x] then return true end end
      return false
    end
    local unknown = {}
    local cat_of = {}
    for r, t in ipairs(ids) do
      local k
      local named = X.bb_cat[t]
      if named then
        local m, c = named[1], named[2]
        for kk, x in ipairs(decls) do if x[2].id == c then k = kk break end end
        if not k then
          for kk, x in ipairs(decls) do if T.contains(x[2].aliases, c) then k = kk break end end
        end
        if not k then unknown[c .. " (named by " .. m .. ")"] = true end
      end
      if not k then
        local g = game[t] == true
        local met = { g, not g and is_chain(t), not g }
        for ri, rule in ipairs(RULES) do
          if met[ri] then
            for kk, x in ipairs(decls) do
              if x[2].rule == rule then k = kk break end
            end
            if k then break end
          end
        end
      end
      cat_of[r] = k or 1
    end
    if not T.is_empty(unknown) then
      VRFW.log.warn(LIST_BB .. ": unknown category " .. table.concat(T.keys(unknown), ", ") .. ": those rows follow the rules")
    end
    -- a mod's copy of a team an earlier category already lists leaves the table
    if X.bb_defaults().dedupe ~= false then ids, cat_of = X.bb_dedupe(decls, ids, cat_of, game, seasons) end
    -- the order of each category's rows: its `sort` keys (stable: the table order breaks ties)
    local season_of = {}
    for k, s in ipairs(seasons) do for _, t in ipairs(s.teams) do season_of[t] = k - 1 end end
    local source = X.bb_source_order(ids)
    local BIG = 1e18
    local function key_of(r, key)
      if key == SORT_SEASON then return { root = season_of[ids[r]] or BIG, steps = {} } end
      if key == SORT_SOURCE then return source[r] end
      return { root = 0, steps = {} }
    end
    local by_name = false
    for _, x in ipairs(decls) do
      if x[2].sort and T.contains(x[2].sort, SORT_NAME) then by_name = true end
    end
    local langs = by_name and VRFW.lang.list() or {}
    local names = by_name and X.bb_row_names(ids, langs) or {}
    local default_lang = X.lang.build_default
    local function sort_in(lang)
      local nm = names[lang]
      local order = {}
      for r = 1, #ids do order[r] = r end
      T.sort(order, function(a, b)
        if cat_of[a] ~= cat_of[b] then return cat_of[a] < cat_of[b] end
        for _, k in ipairs(decls[cat_of[a]][2].sort or {}) do
          local c
          if k == SORT_NAME then
            c = nm and T.cmp(nm[a], nm[b]) or 0
          else
            c = key_cmp(key_of(a, k), key_of(b, k))
          end
          if c ~= 0 then return c < 0 end
        end
        return false
      end)
      return order
    end
    local order = sort_in(default_lang)
    local sorted = {}
    for _, x in ipairs(decls) do
      if x[2].sort and #x[2].sort > 0 then sorted[#sorted + 1] = x[2].id .. " by " .. table.concat(x[2].sort, " + ") end
    end
    if #sorted > 0 then VRFW.log.info(LIST_BB .. ": rows sorted: " .. table.concat(sorted, "; ")) end
    -- the table itself is NOT reordered (online picks are row indices): the run time shows each category in this order
    local game_order = X.bb_game_order or {}
    if #game_order > 0 then
      local same = #ids >= #game_order
      for k = 1, #game_order do
        if ids[k] ~= game_order[k] then same = false break end
      end
      if not same then
        VRFW.log.warn(string.format("%s: the table's first %d row(s) are not the game's own in the game's order (a mod moved or removed them): online picks (sent as row indices) would resolve to other teams", LIST_BB, #game_order))
      end
    end
    local out = {}
    for k, x in ipairs(decls) do
      local m, d = x[1], x[2]
      out[k] = { key = m .. "." .. d.id, id = d.id, text = d.text or "", icon = d.icon or "", rule = d.rule or "", order = d.order or 100, teams = {}, by_lang = {} }
    end
    for _, r in ipairs(order) do table.insert(out[cat_of[r]].teams, ids[r]) end
    for _, lang in ipairs(langs) do
      local o = sort_in(lang)
      for k, x in ipairs(decls) do
        if x[2].sort and T.contains(x[2].sort, SORT_NAME) then
          local l = {}
          for _, r in ipairs(o) do if cat_of[r] == k then l[#l + 1] = ids[r] end end
          out[k].by_lang[lang] = l
        end
      end
    end
    local summary, shown = {}, {}
    for _, c in ipairs(out) do
      summary[#summary + 1] = c.id .. " " .. #c.teams
      if #c.teams > 0 then shown[#shown + 1] = c end
    end
    VRFW.log.info(string.format("%s: %d row(s) in categories: %s (%d shown)", LIST_BB, #ids, table.concat(summary, ", "), #shown))
    return shown, seasons
  end

  -- ------------------------------------------------------------------------------------------------ «win it to unlock it»

  local function starter_charas(t)
    local set = {}
    local ti = X.tc:find(t)
    if ti == nil then return set end
    local s, e = X.tc:member_range(ti)
    for i = s, e - 1 do
      local row = X.tc:member(i).m
      local slot = TC.uint(row, X.TM.SLOT)
      if slot ~= nil and slot <= 10 then
        local card = TC.uint(row, X.TM.PARAM)
        local c = card and X.ch.card[card]
        if c and c.chara ~= 0 then set[c.chara] = true end
      end
    end
    return set
  end

  -- does team `x` (`based_on` `b`) field `b`'s squad (or starters that cannot be compared)
  local function keeps_squad(x, b)
    local U = X.D.bb_unlock
    local a, c = starter_charas(x), starter_charas(b)
    if T.count(a) < U.min_shared or T.count(c) < U.min_shared then return true end
    local n = 0
    for k in pairs(a) do if c[k] then n = n + 1 end end
    return n >= U.min_shared
  end

  -- the teams «the same team» as `t` by identity: itself, its BB copy's source, the teams it declares `same_as`, the
  -- team it is `based_on` when it keeps that team's squad, a few levels up (a set)
  function X.bb_roots(t)
    local copy_src = {}
    for s, c in pairs(X.bb_copies) do copy_src[c] = s end
    local out = { [t] = true }
    local n = 1
    local todo = { t }
    while #todo > 0 do
      local x = table.remove(todo)
      if n > 16 then break end
      local next_ = { X.bb_src[x] or false, copy_src[x] or false }
      for _, y in ipairs(X.same_as[x] or {}) do next_[#next_ + 1] = y end   -- declared identity (`same_as`)
      for _, y in ipairs(next_) do
        if y and y ~= 0 and not out[y] then
          out[y] = true
          n = n + 1
          todo[#todo + 1] = y
        end
      end
      local b = X.based_on[x]
      if b and b ~= 0 and not out[b] and keeps_squad(x, b) then
        out[b] = true
        n = n + 1
        todo[#todo + 1] = b
      end
    end
    return out
  end

  -- the shown name of team `t` in text language `lang` (a mod's declared names, else team_text); "" when none
  local function shown_name(t, lang)
    local look = { t }
    for _, r in ipairs(T.keys(X.bb_roots(t))) do look[#look + 1] = r end
    local meta
    for _, x in ipairs(look) do
      local m = X.meta[x]
      if m and not T.is_empty(m.names) then meta = m.names break end
    end
    local s = meta and VRFW.lang.pick(meta, lang) or nil
    if s == nil then
      local ti = X.tc:find(t)
      local name_id = ti ~= nil and TC.uint(X.tc:info(ti), X.TI.NAME) or 0
      local tbl = X.nouns(lang, "team_text") or {}
      s = tbl[name_id] or ""
    end
    return s
  end

  -- the shown name of each team of `ids` in the build's text language
  local function shown_names(ids)
    local lang = X.lang.build_default
    local out = {}
    for _, t in ipairs(ids) do out[t] = shown_name(t, lang) end
    return out
  end

  -- The hint of a locked row (docs/framework/bb-pages.md §8.2): a menu_text row of its own per team, so the game shows
  -- it filled wherever it draws the row's lock text (the padlock's balloon, for each cursor): the template of
  -- defaults\team.toml [bb_unlock.hint] (`chain` when one of its unlock sources is a chain tile, else `chronicle`)
  -- with {team} = the team's shown name and {chain} = that chain's title, in every text language. Returns the row's
  -- text id, or nil when the templates are missing.
  local function hint_row(team, tile, chain_titles)
    local H = X.D.bb_unlock.hint
    local tpl = type(H) == "table" and H[tile and "chain" or "chronicle"] or nil
    if type(tpl) ~= "table" or T.is_empty(tpl) then return nil end
    local title = tile and chain_titles[tile[1]] or nil
    local def = X.lang.build_default
    local def_name = shown_name(team, def)
    if def_name == "" then def_name = string.format("0x%08X", team) end
    local texts = {}
    for _, lang in ipairs(VRFW.lang.list()) do
      local s = VRFW.lang.pick(tpl, lang)
      if s then
        local name = shown_name(team, lang)
        if name == "" then name = def_name end
        local chain = title and VRFW.lang.pick(title, lang) or ""
        s = T.replace(T.replace(s, "{team}", name), "{chain}", chain)
        texts[lang] = s
      end
    end
    if T.is_empty(texts) then return nil end
    local id = VRFW.crc32(string.format("%s_%08x", TEXT_ROW, team))
    X.push_text(DEFAULTS_OWNER, def, { table = "menu_text", id = id, variant = 0, texts = texts, add = true,
      origin = LIST_BB .. ": unlock hint of " .. string.format("0x%08X", team) })
    return id
  end

  -- the Chronicle rivals: every match piece of the board's routes per difficulty row, and every chain board's match tiles
  local function rivals(route_nodes, chains, off)
    local U = X.D.bb_unlock
    local rv = { pieces = {}, chains = {}, nodes = {} }
    local skip = {}
    for _, n in ipairs(route_nodes) do
      if n.chain ~= "" or off[n.mod_id] then skip[n.piece] = true end
    end
    for _, n in ipairs(route_nodes) do
      if n.chain == "" and not off[n.mod_id] then rv.nodes[n.piece] = n.key end
    end
    local diffs = {}
    for _, d in ipairs(U.chronicle_diffs) do diffs[d] = true end
    -- piece id -> its games
    local pieces = {}
    local r, re = X.route()
    if r then
      local ok, err = pcall(function()
        local function need(v, e) if v == nil then error({ e }) end return v end
        local pl = need(r:list("m_pieceInfoList"))
        local el = need(r:list("m_pieceEventInfoList"))
        local rl = need(r:list("m_chronicleVsRouteInfoList"))
        local fid = need(r:field(pl, "pieceId"))
        local fev = need(r:field(pl, "eventType"))
        local fref = need(r:field(pl, "eventInfoRef"))
        local fg = need(r:field(el, "paramCrc1"))
        local fslice = need(r:field(rl, "pieceInfo"))
        local seen = {}
        for k = 0, r:len(rl) - 1 do
          local s, n = r:tuple(rl, k, fslice)
          if s ~= nil then
            for i = s, s + n - 1 do
              local ev = r:u32(pl, i, fev)
              if ev == 0 or ev == 5 then
                local pid = r:u32(pl, i, fid)
                if pid and pid ~= 0 and not seen[pid] then
                  seen[pid] = true
                  local a, b = r:tuple(pl, i, fref)
                  if a == nil then a, b = 0, 0 end
                  local gs = {}
                  for j = a, a + b - 1 do
                    local g = r:u32(el, j, fg)
                    if g and g ~= 0 then gs[#gs + 1] = g end
                  end
                  pieces[#pieces + 1] = { pid, gs }
                end
              end
            end
          end
        end
      end)
      if not ok then
        local e = type(err) == "table" and err[1] or tostring(err)
        VRFW.log.warn(LIST_BB .. ": unlock rule: " .. e .. ": no Chronicle piece read")
        pieces = {}
      end
    else
      VRFW.log.warn(LIST_BB .. ": unlock rule: " .. re .. ": no Chronicle piece read")
    end
    -- game id -> (difficulty, rival) of its rows
    local rows = {}
    local g, ge = X.games()
    if g then
      for _, x in ipairs(X.games_list()) do
        local v = {}
        for _, i in ipairs(X.grows(x)) do
          local d, tm = g:uint(i, X.SG.D_DIFF), g:uint(i, X.SG.D_TEAM)
          if d and tm then v[#v + 1] = { d, tm } end
        end
        rows[x.id] = v
      end
    else
      VRFW.log.warn(LIST_BB .. ": unlock rule: " .. ge .. ": no Chronicle match read")
    end
    for _, p in ipairs(pieces) do
      local pid, games = p[1], p[2]
      if not skip[pid] then
        for _, gid in ipairs(games) do
          for _, dt in ipairs(rows[gid] or {}) do
            local d, team = dt[1], dt[2]
            if team ~= 0 and diffs[d] then
              rv.pieces[team] = rv.pieces[team] or {}
              rv.pieces[team][pid .. ":" .. d] = { pid, d }
            end
          end
        end
      end
    end
    for _, c in ipairs(chains) do
      if not off[c.mod_id] and c.board then
        for k, t in ipairs(c.board.tiles) do
          if t.kind == "match" and t.team ~= 0 then
            rv.chains[t.team] = rv.chains[t.team] or {}
            rv.chains[t.team][c.key .. "\0" .. (k - 1)] = { c.key, k - 1 }
          end
        end
      end
    end
    return rv
  end

  local function pair_less(a, b)
    if a[1] ~= b[1] then return VRFW.less(a[1], b[1]) end
    return a[2] < b[2]
  end

  -- the condition of a locked row: the pieces ORed (at most max_terms: then the lowest difficulty of each piece, then
  -- the first ones), or «never» when there is none (a chain-only row). condition, kept pairs, dropped
  local function unlock_condition(pieces)
    local U = X.D.bb_unlock
    local pairs_ = {}
    local seen = {}
    for _, p in ipairs(pieces) do
      local k = p[1] .. ":" .. p[2]
      if not seen[k] then seen[k] = true pairs_[#pairs_ + 1] = { p[1], p[2] } end
    end
    T.sort(pairs_, pair_less)
    if #pairs_ > U.max_terms then
      local low = {}
      for _, p in ipairs(pairs_) do
        if low[p[1]] == nil or p[2] < low[p[1]] then low[p[1]] = p[2] end
      end
      pairs_ = {}
      for _, k in ipairs(T.keys(low)) do pairs_[#pairs_ + 1] = { k, low[k] } end
    end
    local dropped = math.max(#pairs_ - U.max_terms, 0)
    while #pairs_ > U.max_terms do pairs_[#pairs_] = nil end
    local groups = {}
    if #pairs_ == 0 then
      groups[1] = VRFW.cond.group("GetGlobalByteFlag", { { VRFW.crc32(CHAIN_LOCK_FLAG), true } }, CHAIN_LOCK_VALUE, VRFW.cond.EQ)
    else
      for k, p in ipairs(pairs_) do
        groups[k] = VRFW.cond.group("GetChronicleClearStatusFlag", { { p[1], true }, { p[2], false } }, 1, VRFW.cond.EQ)
      end
    end
    local s = VRFW.cond.join(groups, "any")
    return s or "", #pairs_, dropped
  end

  -- the rule over the grid (after the categories and the duplicates' removal)
  function X.bb_unlock(files, route_nodes, chains)
    if not X.bb_unlock_on() then
      VRFW.log.info(LIST_BB .. ": unlock rule off ([bb_pages] chronicle_unlock = false): every row keeps its own state")
      return {}
    end
    local en = X.enjoy()
    if not en then return {} end
    local U = X.D.bb_unlock
    local exempt_mods, off = {}, {}
    for _, f in ipairs(files) do
      local d = f.value.vrfw.BbUnlock
      if d then
        if d.enabled == false then exempt_mods[f.mod] = true end
        if d.unlocks == false then off[f.mod] = true end
      end
    end
    local owner = {}
    for _, e in ipairs(X.entries) do
      if e.list == LIST_BB then owner[e.team] = e.mod_id end
    end
    -- the rows: (entry index, team, has a condition)
    local rows = {}
    local EJ = X.EJ
    for _, i in ipairs(en:rows(ENJOY_ROW)) do
      local team = en:uint(i, 0)
      if team and team ~= 0 then
        local v = en:get(i, EJ.CONDITION)
        local cond
        if type(v) == "string" then cond = v ~= ""
        elseif type(v) == "number" then cond = v ~= 0
        else cond = false end
        rows[#rows + 1] = { i, team, cond }
      end
    end
    local rv = rivals(route_nodes, chains, off)
    local rset = {}
    for t in pairs(rv.pieces) do rset[t] = true end
    for t in pairs(rv.chains) do rset[t] = true end
    local rival_teams = T.keys(rset)
    -- identity: a rival is the row's team when one is the other's source, or both are copies of a rival
    local by_root = {}
    for _, o in ipairs(rival_teams) do
      for r in pairs(X.bb_roots(o)) do
        by_root[r] = by_root[r] or {}
        by_root[r][o] = true
      end
    end
    -- roster: character -> rivals
    local by_chara = {}
    for _, o in ipairs(rival_teams) do
      for c in pairs(starter_charas(o)) do
        by_chara[c] = by_chara[c] or {}
        table.insert(by_chara[c], o)
      end
    end
    local all = {}
    for _, r in ipairs(rows) do all[#all + 1] = r[2] end
    for _, o in ipairs(rival_teams) do all[#all + 1] = o end
    local names = shown_names(all)
    local key = VRFW.team.name_key
    local by_name = {}
    for _, o in ipairs(rival_teams) do
      local k = key(names[o] or "")
      if k ~= "" then
        by_name[k] = by_name[k] or {}
        by_name[k][o] = true
      end
    end
    local out, writes = {}, {}
    local own_cond, exempt, no_hint = 0, 0, 0
    local chain_titles = {}
    for _, ch in ipairs(chains) do chain_titles[ch.key] = ch.title end
    local capped, free, by_name_list = {}, {}, {}
    local function label(t)
      local n = names[t] or ""
      if n == "" then return string.format("0x%08X", t) end
      return n
    end
    for _, row in ipairs(rows) do
      local i, team, cond = row[1], row[2], row[3]
      if cond then
        own_cond = own_cond + 1
      elseif owner[team] and exempt_mods[owner[team]] then
        exempt = exempt + 1
      else
        -- identity, plus the rivals fielding the same squad
        local found = T.copy(by_root[team] or {})
        for r in pairs(X.bb_roots(team)) do
          if rset[r] then
            found[r] = true
            for o in pairs(by_root[r] or {}) do found[o] = true end
          end
        end
        local mine = starter_charas(team)
        local shared = {}
        for c in pairs(mine) do
          for _, o in ipairs(by_chara[c] or {}) do shared[o] = (shared[o] or 0) + 1 end
        end
        local via = "id"
        if not T.is_empty(found) then
          for o, n in pairs(shared) do if n >= U.same_squad then found[o] = true end end
        else
          -- roster: the most shared starters, at least min_shared
          local best = 0
          for _, n in pairs(shared) do if n > best then best = n end end
          if best >= U.min_shared and best * 2 >= math.min(T.count(mine), 11) then
            for o, n in pairs(shared) do if n == best then found[o] = true end end
            via = "roster"
          end
        end
        if T.is_empty(found) then
          local k = key(names[team] or "")
          local v = k ~= "" and by_name[k] or nil
          if v then
            found = T.copy(v)
            via = "name"
            local p = {}
            for _, o in ipairs(T.keys(v)) do p[#p + 1] = string.format("0x%08X", o) end
            by_name_list[#by_name_list + 1] = label(team) .. " -> " .. table.concat(p, " / ")
          end
        end
        if T.is_empty(found) then
          free[#free + 1] = label(team)
        else
          local pset, tset = {}, {}
          for o in pairs(found) do
            for k, x in pairs(rv.pieces[o] or {}) do pset[k] = x end
            for k, x in pairs(rv.chains[o] or {}) do tset[k] = x end
          end
          local pieces = {}
          for _, x in pairs(pset) do pieces[#pieces + 1] = x end
          table.sort(pieces, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
          local tiles = {}
          for _, x in pairs(tset) do tiles[#tiles + 1] = x end
          table.sort(tiles, pair_less)
          local c, kept, dropped = unlock_condition(pieces)
          if dropped > 0 or kept < #pieces then
            capped[#capped + 1] = string.format("%s (%d of %d piece clears)", label(team), kept, #pieces)
          end
          local text = hint_row(team, tiles[1], chain_titles)
          if text == nil then no_hint = no_hint + 1 end
          writes[#writes + 1] = { i, c, text or 0 }
          local nset = {}
          for _, p in ipairs(pieces) do
            local n = rv.nodes[p[1]]
            if n then nset[n] = true end
          end
          out[#out + 1] = { team = team, via = via, rivals = T.keys(found), pieces = pieces, nodes = T.keys(nset), chains = tiles }
        end
      end
    end
    if #writes > 0 then
      for _, w in ipairs(writes) do
        en:set(w[1], EJ.CONDITION, w[2])
        en:set(w[1], EJ.UNLOCK_TEXT, T.i32(w[3]))
      end
      en:touch()
      X.touched.enjoy = true
    end
    local function cnt(f)
      local n = 0
      for _, u in ipairs(out) do if f(u) then n = n + 1 end end
      return n
    end
    local n_piece = cnt(function(u) return #u.pieces > 0 end)
    local n_node = cnt(function(u) return #u.nodes > 0 end)
    local n_chain = cnt(function(u) return #u.chains > 0 end)
    local n_chain_only = cnt(function(u) return #u.pieces == 0 end)
    local function via(v) return cnt(function(u) return u.via == v end) end
    VRFW.log.info(string.format("%s: unlock rule: %d row(s): %d locked until won (%d by a Chronicle piece, %d of them by a route node; %d by a chain tile, %d by chain tiles only; found by id %d, roster %d, name %d), %d keep their own condition, %d of mods that opted out, %d without a Chronicle equivalent (open)",
      LIST_BB, #rows, #out, n_piece, n_node, n_chain, n_chain_only, via("id"), via("roster"), via("name"), own_cond, exempt, #free))
    if no_hint > 0 then
      VRFW.log.warn(string.format("%s: unlock rule: defaults\\team.toml [bb_unlock.hint] has no template: %d locked row(s) without a hint", LIST_BB, no_hint))
    end
    if #by_name_list > 0 then
      VRFW.log.warn(string.format("%s: unlock rule: %d row(s) matched to a Chronicle rival by NAME only (review): %s", LIST_BB, #by_name_list, table.concat(by_name_list, ", ")))
    end
    if #capped > 0 then
      VRFW.log.warn(string.format("%s: unlock rule: condition capped at %d comparisons: %s", LIST_BB, U.max_terms, table.concat(capped, ", ")))
    end
    if #free > 0 then
      VRFW.log.info(LIST_BB .. ": unlock rule: no Chronicle equivalent (open): " .. table.concat(free, ", "))
    end
    return out
  end
end

return B
