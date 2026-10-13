-- `[[VRFW.LevelMap]]`: re-levels Chronicle-style difficulty rows (docs/game/modes/chronicle-level-continuity.md; was
-- team_engine level_map.rs). Per row: Δ = round(map(level)) − level (at the line-up's level, col 6, or the rival's),
-- then the rival level (col 2) and the line-up level (col 6) + Δ (capped); with `moves` the row plays copies of its
-- teams whose loadouts' learn levels are + Δ too (every player keeps exactly the moves of his original level); `sync`
-- sets the row's level sync (col 39) to the new rival level + `sync`; `exp` the match EXP (col 9) to `exp` × needExp of the
-- new rival level; `clones` also re-levels the route-node games cloned from a matched game (the rows they inherited).
local T = require "lib/team_util"
local TC = require "team/tc"
local LM = {}

-- learn levels are written at most this (above any player level: a move locked before stays locked)
local LEARN_MAX = 255
local SLOT_COACH = 19
local LOADOUT_MOVES = 6
-- the row's level sync (col 39: the cap of the player's own team; Heroica's), set by `sync`
local D_SYNC = 39
-- the row's match EXP (col 9), set by `exp` (× needExp of the new rival level)
local D_EXP = 9
local EXP_PREFIX = "data/common/gamedata/character/chara_exp_table_config_"

-- `*` = any run, `?` = one character (UTF-8 characters)
function LM.glob(p, s)
  p, s = T.chars(p), T.chars(s)
  local i, j, star, mark = 1, 1, nil, 1
  while j <= #s do
    if i <= #p and (p[i] == "?" or p[i] == s[j]) then
      i, j = i + 1, j + 1
    elseif i <= #p and p[i] == "*" then
      star, mark = i, j
      i = i + 1
    elseif star then
      i = star + 1
      mark = mark + 1
      j = mark
    else
      return false
    end
  end
  while i <= #p and p[i] == "*" do i = i + 1 end
  return i == #p + 1
end

-- the piecewise-linear map through `points` (x increasing), its end segments extended; rounded half up
function LM.map_level(points, x)
  local n = #points
  local k = n - 1
  for kk = 1, n - 2 do
    if x < points[kk + 1][1] then k = kk break end
  end
  local x0, y0 = points[k][1], points[k][2]
  local x1, y1 = points[k + 1][1], points[k + 1][2]
  local y = y0 + (y1 - y0) * (x - x0) / (x1 - x0)
  return math.floor(y + 0.5)
end

-- a learn level + Δ (0 and 1 = no requirement: they stay)
function LM.shift_learn(lv, delta)
  if lv <= 1 then return lv end
  return T.clamp(lv + delta, 1, LEARN_MAX)
end

local function num(x)
  if type(x) == "number" then return x end
  if type(x) == "table" then return x.float end
  return 1
end

function LM.install(X)
  -- `chara_exp_table_config` (the served one: the character type's levels): level -> needExp, read once
  function X.need_exp_table()
    if X.need_exp == nil then
      local k, e = X.table_key(EXP_PREFIX)
      local r
      if k then r, e = VRFW.team.rdbn(k) end
      local l, fl, fe
      if r then l, e = r:list("m_charaExpTableList") end
      if l then fl, e = r:field(l, "level") end
      if fl then fe, e = r:field(l, "needExp") end
      if fe then
        local t = {}
        for i = 0, r:len(l) - 1 do
          local lv, n = r:u32(l, i, fl), r:u32(l, i, fe)
          if lv and n then t[lv] = n end
        end
        X.need_exp = { t = t }
      else
        X.need_exp = { err = e or "chara_exp_table_config not found" }
      end
    end
    return X.need_exp.t, X.need_exp.err
  end

  function X.level_maps(files)
    for _, f in ipairs(files) do
      for _, lm in ipairs(f.value.vrfw.LevelMap or {}) do
        local ok, e = X.level_map(f.file, lm)
        if not ok then VRFW.log.error(f.file .. ": level_map `" .. lm.name .. "`: " .. e .. " (skipped)") end
      end
    end
  end

  function X.level_map(file, lm)
    local what = file .. ": level_map `" .. lm.name .. "`"
    local pts = lm.points or {}
    local bad = #pts < 2
    for k = 2, #pts do if pts[k][1] <= pts[k - 1][1] then bad = true end end
    if bad then return nil, "`points` needs at least 2 points with increasing old levels" end
    local by_rival
    if lm.by == nil or lm.by == "own" then by_rival = false
    elseif lm.by == "rival" then by_rival = true
    else return nil, "by = \"" .. lm.by .. "\": \"own\" or \"rival\"" end
    local diffs = (#(lm.difficulties or {}) == 0) and { 1 } or lm.difficulties
    local max = T.clamp(lm.max or 200, 1, 999)
    local moves = lm.moves ~= false
    if lm.rival_rates ~= nil and not (lm.rival_rates > 0 and lm.rival_rates < math.huge) then
      return nil, "rival_rates must be a positive number"
    end
    if lm.exp ~= nil and not (lm.exp > 0 and lm.exp < math.huge) then
      return nil, "exp must be a positive number"
    end
    if lm.exp ~= nil then
      local _, xe = X.need_exp_table()
      if xe then return nil, "exp: " .. xe end
    end
    local g, ge = X.games()
    if not g then return nil, ge end
    local SG = X.SG
    local function hit(n)
      for _, p in ipairs(lm.games) do
        if LM.glob(p, n) then return true end
      end
      return false
    end
    -- the matched games, and with `clones` the route-node games cloned from one of them (minus the difficulties whose
    -- level the node set)
    local names, node_of = {}, {}
    for _, x in ipairs(X.games_list()) do names[x.id] = x.name end
    if lm.clones then
      for _, c in ipairs(X.node_clones) do node_of[c.game] = c end
    end
    local games, skip = {}, {}
    for _, x in ipairs(X.games_list()) do
      if hit(x.name) then
        games[#games + 1] = x
        skip[#games] = {}
      else
        local c = node_of[x.id]
        if c and names[c.template] and hit(names[c.template]) then
          games[#games + 1] = x
          skip[#games] = c.set
        end
      end
    end
    if #games == 0 then
      local p = {}
      for k, s in ipairs(lm.games) do p[k] = T.dbg_str(s) end
      VRFW.log.warn(what .. ": no game matches [" .. table.concat(p, ", ") .. "]")
      return true
    end
    local n_rows, tbl = 0, {}
    for gi, x in ipairs(games) do
      local rows = {}
      for _, i in ipairs(X.grows(x)) do
        local d = g:int(i, SG.D_DIFF)
        if d then rows[#rows + 1] = { d, i } end
      end
      local ceiling
      if lm.not_above ~= nil then
        for _, r in ipairs(rows) do
          if r[1] == lm.not_above then ceiling = g:int(r[2], SG.D_LEVEL) break end
        end
      end
      for _, r in ipairs(rows) do
        local d, i = r[1], r[2]
        if T.contains(diffs, d) and not skip[gi][d] then
          local team, lv = g:uint(i, SG.D_TEAM) or 0, g:int(i, SG.D_LEVEL) or 0
          local own_team, own_lv = g:uint(i, SG.D_OWN_TEAM) or 0, g:int(i, SG.D_OWN_LEVEL) or 0
          local has_own = own_team ~= 0 and own_team ~= 4294967295 and own_lv >= 1
          local base = (by_rival or not has_own) and lv or own_lv
          if base >= 1 then
            local delta = LM.map_level(pts, base) - base
            local nlv, nown = T.clamp(lv + delta, 1, max), T.clamp(own_lv + delta, 1, max)
            if lv + delta > max or (has_own and own_lv + delta > max) then
              VRFW.log.warn(string.format("%s: %s difficulty %d: level %d capped at %d", what, x.name, d, math.max(lv + delta, own_lv + delta), max))
            end
            if ceiling ~= nil and nlv > ceiling then
              VRFW.log.warn(string.format("%s: %s difficulty %d: rival level %d is above difficulty %d (%d)", what, x.name, d, nlv, lm.not_above or 0, ceiling))
            end
            local new_team = team
            if moves or lm.rival_rates ~= nil then
              local c, e = X.lm_copy(team, delta, moves, lm.rival_rates)
              if not c then return nil, e end
              new_team = c
            end
            local new_own = own_team
            if has_own and moves then
              local c, e = X.lm_copy(own_team, delta, true, nil)
              if not c then return nil, e end
              new_own = c
            end
            local exp
            if lm.exp ~= nil then
              local n = X.need_exp_table()[nlv]
              if n then
                exp = math.floor(lm.exp * n + 0.5)
              else
                VRFW.log.warn(string.format("%s: %s difficulty %d: no needExp for level %d (match EXP kept)", what, x.name, d, nlv))
              end
            end
            g:set(i, SG.D_LEVEL, nlv)
            if lm.sync ~= nil and (g:int(i, D_SYNC) or 0) >= 1 then
              g:set(i, D_SYNC, T.clamp(nlv + lm.sync, 1, max))
            end
            if exp ~= nil then g:set(i, D_EXP, exp) end
            g:set(i, SG.D_TEAM, T.i32(new_team))
            if has_own then
              g:set(i, SG.D_OWN_LEVEL, nown)
              g:set(i, SG.D_OWN_TEAM, T.i32(new_own))
            end
            g:touch()
            n_rows = n_rows + 1
            if has_own then
              tbl[#tbl + 1] = string.format("%s d%d %d/%d→%d/%d", x.name, d, lv, own_lv, nlv, nown)
            else
              tbl[#tbl + 1] = string.format("%s d%d %d→%d", x.name, d, lv, nlv)
            end
          end
        end
      end
    end
    VRFW.log.info(string.format("%s: %d row(s) re-levelled: %s", what, n_rows, table.concat(tbl, ", ")))
    return true
  end

  -- the copy of team `tid` for a row shifted by `delta` (made once per team, Δ and rates)
  function X.lm_copy(tid, delta, moves, rates)
    local shift = moves and delta ~= 0
    if not shift and rates == nil then return tid end
    local tc = X.tc
    local t = tc:find(tid)
    if t == nil then return nil, "team " .. T.hex(tid) .. " is not in team_config" end
    local key = tc:key_of(t) .. "_lm" .. (shift and T.d(delta) or "0")
    if rates ~= nil then key = key .. "_r" .. T.d(T.round(rates * 100)) end
    local id = VRFW.crc32(key)
    if tc:find(id) ~= nil then return id end
    local TM = X.TM
    local rows = {}
    local s, e = tc:member_range(t)
    for i = s, e - 1 do
      local x = tc:member(i)
      local row, role = TC.copy_row(x.m), TC.copy_row(x.r)
      if shift and (TC.uint(row, TM.SLOT) or 0) < SLOT_COACH then
        local lid = TC.uint(row, TM.SKILL_CFG) or 0
        local card = TC.uint(row, TM.PARAM) or 0
        local n = X.lm_loadout(lid, card, delta)
        if n then TC.set_int(row, TM.SKILL_CFG, n) end
      end
      if rates ~= nil then
        for k = 0, 7 do
          local v = num(row[TM.RATE + k + 1])
          for c = #row + 1, TM.RATE + k do row[c] = 1 end
          row[TM.RATE + k + 1] = { float = v * rates }
        end
      end
      rows[#rows + 1] = { m = row, r = role }
    end
    local info, refs = tc:team_copy(t)
    TC.set_int(info, X.TI.ID, id)
    info[X.TI.KEY + 1] = key
    tc:push_team(info, refs)
    local nt = #tc.teams - 1
    local start = #tc.members
    for _, r in ipairs(rows) do tc.members[#tc.members + 1] = r end
    tc:set_slice(nt, 0, start, #rows)
    local m = X.meta[tid]
    if m then
      X.meta[id] = { stadium = m.stadium, stadium_fallback = m.stadium_fallback, stadium_image = m.stadium_image, music = m.music, ai = m.ai, rules = m.rules, series = m.series, names = T.copy(m.names),
        short = T.copy(m.short), default_lang = m.default_lang }
    end
    return id
  end

  -- the loadout `lid` (or, when 0, the card's first 6 chara_param pairs) with every learn level + Δ; nil = nothing to
  -- shift
  function X.lm_loadout(lid, card, delta)
    local tc = X.tc
    local nid
    if lid ~= 0 then
      nid = VRFW.crc32(string.format("evt_lm_sk_%08x_%d", lid, delta))
    else
      nid = VRFW.crc32(string.format("evt_lm_cp_%08x_%d", card, delta))
    end
    if tc:has_loadout(nid) then return nid end
    local e
    if lid ~= 0 then
      local src = tc:loadout_row(lid)
      if not src then return nil end
      e = TC.copy_row(src)
      TC.set_int(e, 0, nid)
      for k = 0, LOADOUT_MOVES - 1 do
        local c = 1 + LOADOUT_MOVES + k
        TC.set_int(e, c, LM.shift_learn(TC.int(e, c) or 0, delta))
      end
    else
      local pairs_ = X.ch.pairs[card]
      if not pairs_ then return nil end
      local all_empty = true
      for _, p in ipairs(pairs_) do
        if not (p[1] == 0 or p[1] == 4294967295) then all_empty = false end
      end
      if all_empty then return nil end
      local filler = tc:loadout_filler()
      local mv = {}
      for k, p in ipairs(pairs_) do
        if p[1] == 0 or p[1] == 4294967295 then
          mv[k] = { T.u32(filler), 0 }
        else
          mv[k] = { p[1], T.u32(LM.shift_learn(T.i32(p[2]), delta)) }
        end
      end
      -- (loadout_exact takes the moves as signed cells)
      local ex = {}
      for k, x in ipairs(mv) do ex[k] = { T.i32(x[1]), T.i32(x[2]) } end
      e = tc:loadout_exact(nid, ex, filler)
      if not e then return nil end
    end
    tc:put_loadout(e)
    return nid
  end
end

return LM
