-- Utilities › original names: the catalogue (series pages, their team rows, the characters) and the selection /
-- picker model. Pure Lua over the tables the game loads (VRFW.table.rows) and the mods' card_filters\ declarations;
-- no game memory. Ids are unsigned 32-bit numbers.
--
-- A selection is per player: { [chara_base id] = true } (since Utilities 1.6.0; before, whole series and teams).

local M = {}

local SERIES_TABLE = "character/chara_series"
local BELONG_TABLE = "character/belong_team"
local CHARA_TABLE = "character/chara_base"

local Id = require "VRFW/lib/ids"

local function u32(v)
  if type(v) ~= "number" then
    return 0
  end
  return Id.u32(v)
end
M.u32 = u32

-- the first present value of `row` among `names` (schema name, then the file's own field name)
local function col(row, ...)
  for i = 1, select("#", ...) do
    local v = row[select(i, ...)]
    if v ~= nil then
      return v
    end
  end
  return nil
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
M.trim = trim

-- ------------------------------------------------------------------------------------------- the game's tables

-- rows of chara_series_config, table order: { id, ty, name_text }
function M.series_rows()
  local out = {}
  for _, r in ipairs(VRFW.table.rows(SERIES_TABLE)) do
    local id = u32(col(r, "chara_series_id", "charaSeriesId"))
    if id ~= 0 then
      out[#out + 1] = {
        id = id,
        ty = u32(col(r, "chara_series_type", "charaSeriesType")),
        name_text = u32(col(r, "chara_series_name_text_id", "charaSeriesNameTextId")),
      }
    end
  end
  return out
end

-- rows of belong_team_config: { id, name_text, numbers = { [k] = number in the k-th teamNumber_<X> column } }
-- (the k-th such column, in field order, is series type k)
-- The emblem columns (team_emblem_id_<era>, the item_emblem of the team in that era) and the series type each serves:
-- series type k (the k-th team_number_<x> column) takes the era whose name starts <x> (ie1 -> ie, go2 -> go, v -> v) or
-- contains its first three letters (ares / orion -> areori). Returns the era of each type and every row's emblems.
function M.belong_rows()
  local nums, num_names, eras = {}, {}, {}
  for i, n in ipairs(VRFW.table.columns(BELONG_TABLE)) do
    local x = n:match("^teamNumber_(.+)$") or n:match("^team_number_(.+)$")
    if x then
      nums[#nums + 1] = i
      num_names[#num_names + 1] = x:lower()
    end
    local e = n:match("^team_emblem_id_(.+)$") or n:match("^teamEmblemId_(.+)$")
    if e then
      eras[#eras + 1] = { name = e:lower(), col = i }
    end
  end
  if #nums == 0 then
    error("belong_team_config: no teamNumber_<X> column")
  end
  local type_era = {}
  for k, x in ipairs(num_names) do
    for ei, e in ipairs(eras) do
      if x:sub(1, #e.name) == e.name or (#x >= 3 and e.name:find(x:sub(1, 3), 1, true)) then
        type_era[k] = ei
        break
      end
    end
  end
  local out = {}
  for _, r in ipairs(VRFW.table.rows(BELONG_TABLE)) do
    local id = u32(col(r, "belong_team_id", "belongTeamId"))
    if id ~= 0 then
      local numbers, emblems = {}, {}
      for k, i in ipairs(nums) do
        local v = r[i]
        numbers[k] = type(v) == "number" and v or 0
      end
      for ei, e in ipairs(eras) do
        emblems[ei] = u32(r[e.col])
      end
      out[#out + 1] = { id = id, name_text = u32(col(r, "team_name_text_id", "teamNameTextId")), numbers = numbers,
                        emblems = emblems }
    end
  end
  out.type_era = type_era
  return out
end

-- the characters of chara_base: { n1, n2, n3 (name / short / upper name text ids), series, t1, t2, t3 (belong teams),
-- id (the chara_base key: the selection's key and the face icon's) }
function M.charas()
  local out = {}
  for _, r in ipairs(VRFW.table.rows(CHARA_TABLE)) do
    out[#out + 1] = {
      u32(r.name_text), u32(r.short_name_text), u32(r.upper_name_text),
      u32(r.series),
      u32(r.team_1), u32(r.team_2), u32(r.team_3),
      u32(r.id),
    }
  end
  return out
end

-- ------------------------------------------------------------------------------------------- declarations

-- an id written in a declaration: a number, "0x…" / decimal text, or a name (its crc32); nil = none
function M.id_value(v)
  if type(v) == "number" then
    if v >= 0 and v <= 0xFFFFFFFF and v == math.floor(v) then
      return v
    end
    if v < 0 and v >= -2147483648 and v == math.floor(v) then
      return u32(v)
    end
    return nil
  end
  if type(v) ~= "string" then
    return nil
  end
  local s = trim(v)
  local h = s:match("^0[xX](.*)$")
  if h then
    if not h:find("^%x+$") then
      return nil
    end
    local n = tonumber(h, 16)
    return (n and n <= 0xFFFFFFFF) and n or nil
  end
  if s:find("^%d+$") then
    local n = tonumber(s)
    return (n and n <= 0xFFFFFFFF) and n or nil
  end
  if s ~= "" then
    return VRFW.ui.crc32(s)
  end
  return nil
end

-- the (series, team) pairs every active mod declares in card_filters\ (`[[bank_tab]]` / `[[series]]` entries naming
-- both, not hidden), and their count
function M.declarations()
  local out, seen = {}, {}
  for _, d in ipairs(VRFW.files.declarations("card_filters")) do
    local data = type(d.data) == "table" and d.data or {}
    for _, list in ipairs({ "bank_tab", "series" }) do
      local arr = data[list]
      if type(arr) == "table" then
        for _, e in ipairs(arr) do
          if type(e) == "table" and e.hide ~= true then
            local s, t = M.id_value(e.series), M.id_value(e.team)
            if s and t and s ~= 0 and t ~= 0 then
              local k = s .. ":" .. t
              if not seen[k] then
                seen[k] = true
                out[#out + 1] = { s, t }
              end
            end
          end
        end
      end
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------- the catalogue

-- Tabs from the series table (table order), teams from belong_team_config (k-th teamNumber_ column = series type k),
-- then the characters' own teams, then the declared ones. A series with no team and no character is left out.
-- Returns { series = { { id, ty, name_text, teams = {…}, declared = {…}, declared_set, members = { chara index… } } },
--           team_names = { [team] = name text }, charas = {…} }
function M.build(series, belong, charas, decls)
  local team_names, order, emblems = {}, {}, {}
  for i, b in ipairs(belong) do
    team_names[b.id] = b.name_text
    emblems[b.id] = b.emblems
    if order[b.id] == nil then
      order[b.id] = i
    end
  end
  local out = {}
  for _, s in ipairs(series) do
    local numbered = {}
    if s.ty >= 1 then
      for i, b in ipairs(belong) do
        local n = b.numbers[s.ty]
        if n and n > 0 then
          numbered[#numbered + 1] = { n, i, b.id }
        end
      end
    end
    table.sort(numbered, function(a, b)
      if a[1] ~= b[1] then
        return a[1] < b[1]
      end
      return a[2] < b[2]
    end)
    local teams, in_teams = {}, {}
    for _, x in ipairs(numbered) do
      teams[#teams + 1] = x[3]
      in_teams[x[3]] = true
    end
    local declared, declared_set = {}, {}
    for _, d in ipairs(decls) do
      if d[1] == s.id and not declared_set[d[2]] then
        declared[#declared + 1] = d[2]
        declared_set[d[2]] = true
      end
    end
    local has_decl = #declared > 0
    local extra, in_extra, members, has_chara = {}, {}, {}, false
    for ci, c in ipairs(charas) do
      local own = c[4] == s.id
      has_chara = has_chara or own
      local member = own
      if not member and has_decl then
        for k = 5, 7 do
          if c[k] ~= 0 and declared_set[c[k]] then
            member = true
            break
          end
        end
      end
      if member then
        members[#members + 1] = ci
        for k = 5, 7 do
          local t = c[k]
          if t ~= 0 and not in_teams[t] and not in_extra[t] and not declared_set[t] then
            in_extra[t] = #extra + 1
            extra[#extra + 1] = t
          end
        end
      end
    end
    -- by belong table order (stable: first seen first among unknown ones)
    table.sort(extra, function(a, b)
      local oa, ob = order[a] or math.huge, order[b] or math.huge
      if oa ~= ob then
        return oa < ob
      end
      return in_extra[a] < in_extra[b]
    end)
    for _, t in ipairs(extra) do
      teams[#teams + 1] = t
      in_teams[t] = true
    end
    for _, t in ipairs(declared) do
      if not in_teams[t] then
        teams[#teams + 1] = t
        in_teams[t] = true
      end
    end
    if #teams > 0 or has_chara then
      out[#out + 1] = {
        id = s.id, ty = s.ty, name_text = s.name_text,
        teams = teams, declared = declared, declared_set = declared_set, members = members,
      }
    end
  end
  return { series = out, team_names = team_names, charas = charas, emblems = emblems, type_era = belong.type_era or {} }
end

-- ------------------------------------------------------------------------------------------- the picker's rows

-- the team rows of series `s` (cached on it): { { team, players = { chara index… } }, … } in the series' team order;
-- a player is a member of the series (s.members) one of whose teams is the row's team; a team without players is
-- left out. A player of several teams of the series is in each of their rows.
function M.rows(cat, s)
  if s.rows then
    return s.rows
  end
  local by = {}
  for _, ci in ipairs(s.members) do
    local c = cat.charas[ci]
    for k = 5, 7 do
      local t = c[k]
      if t ~= 0 then
        by[t] = by[t] or {}
        local l = by[t]
        if l[#l] ~= ci then
          l[#l + 1] = ci
        end
      end
    end
  end
  local rows = {}
  for _, t in ipairs(s.teams) do
    local l = by[t]
    if l and #l > 0 then
      rows[#rows + 1] = { team = t, players = l }
    end
  end
  s.rows = rows
  return rows
end

-- the team's emblem (item_emblem id) for a page of series type `ty`: the era that type serves, else the latest era
-- with one; 0 = none (the grid's neutral plate)
function M.team_emblem(cat, team, ty)
  local e = cat.emblems and cat.emblems[team]
  if not e then
    return 0
  end
  local era = cat.type_era[ty]
  if era and (e[era] or 0) ~= 0 then
    return e[era]
  end
  for i = #e, 1, -1 do
    if (e[i] or 0) ~= 0 then
      return e[i]
    end
  end
  return 0
end

-- ------------------------------------------------------------------------------------------- selections
-- A selection is per PLAYER: { [chara_base id] = true }.

function M.count(chosen)
  local n = 0
  for _ in pairs(chosen) do
    n = n + 1
  end
  return n
end

function M.copy(chosen)
  local c = {}
  for id in pairs(chosen) do
    c[id] = true
  end
  return c
end

local function sorted_keys(set)
  local out = {}
  for k in pairs(set) do
    out[#out + 1] = k
  end
  table.sort(out)
  return out
end

-- a canonical text of the selection (equality)
function M.sel_key(chosen)
  local parts = {}
  for _, id in ipairs(sorted_keys(chosen)) do
    parts[#parts + 1] = string.format("%08x", id)
  end
  return table.concat(parts, ",")
end

-- `chosen` without the ids the catalogue has no character for
function M.normalize(cat, chosen)
  local out = {}
  for _, c in ipairs(cat.charas) do
    if c[8] ~= 0 and chosen[c[8]] then
      out[c[8]] = true
    end
  end
  return out
end

-- (on, total) of a list of chara indices
function M.players_on(cat, players, chosen)
  local on = 0
  for _, ci in ipairs(players) do
    if chosen[cat.charas[ci][8]] then
      on = on + 1
    end
  end
  return on, #players
end

-- the chara_text ids of the names of every chosen character (sorted) and the number of characters
function M.chara_name_ids(cat, chosen)
  local ids, n = {}, 0
  for _, c in ipairs(cat.charas) do
    if c[8] ~= 0 and chosen[c[8]] then
      n = n + 1
      for k = 1, 3 do
        if c[k] ~= 0 then
          ids[c[k]] = true
        end
      end
    end
  end
  return sorted_keys(ids), n
end

-- the team_text ids of the teams every player of which is chosen (in every series row of the team), sorted; `all` =
-- every team («Originales»)
function M.team_name_ids(cat, chosen, all)
  local full = {}
  for _, s in ipairs(cat.series) do
    for _, r in ipairs(M.rows(cat, s)) do
      local on, n = M.players_on(cat, r.players, chosen)
      if all or (n > 0 and on == n) then
        if full[r.team] == nil then
          full[r.team] = true
        end
      else
        full[r.team] = false
      end
    end
    if all then
      for _, t in ipairs(s.teams) do
        full[t] = true
      end
    end
  end
  local ids = {}
  for t, ok in pairs(full) do
    local nm = cat.team_names[t]
    if ok and nm and nm ~= 0 then
      ids[nm] = true
    end
  end
  return sorted_keys(ids)
end

-- ------------------------------------------------------------------------------------------- old selections

-- Utilities 1.3.0 - 1.5.x chose whole series (names.s.<series>) and teams of a series (names.t.<series>.<team>): the
-- characters such a selection covered (a member of a ticked series, or of a tab where one of its teams is ticked)
function M.legacy_chosen(cat, series, teams)
  local out = {}
  for _, s in ipairs(cat.series) do
    local whole = series[s.id] == true
    local ts = teams[s.id]
    if whole or ts ~= nil then
      for _, ci in ipairs(s.members) do
        local c = cat.charas[ci]
        local on = whole
        if not on then
          for k = 5, 7 do
            if c[k] ~= 0 and ts[c[k]] then
              on = true
              break
            end
          end
        end
        if on and c[8] ~= 0 then
          out[c[8]] = true
        end
      end
    end
  end
  return out
end

-- does series name `name` end with one of `words` (case-insensitive)?
function M.series_matches(name, words)
  local last = trim(name):match("([^%s:]*)$") or ""
  if last == "" then
    return false
  end
  last = last:lower()
  for _, w in ipairs(words) do
    if type(w) == "string" and trim(w):lower() == last then
      return true
    end
  end
  return false
end

-- the series whose name (text rows of chara_add_info_text, variant 0) ends with one of `words`
function M.series_by_words(cat, names, words)
  local out = {}
  for _, s in ipairs(cat.series) do
    local r = names[s.name_text]
    local n = r and r[0]
    if type(n) == "string" and M.series_matches(n, words) then
      out[#out + 1] = s.id
    end
  end
  return out
end

-- ------------------------------------------------------------------------------------------- the picker

-- the picker's editing state: { chosen, start (its key), page (1-based series), row (the open team row, 0 = none) }.
-- It opens on the first series with a chosen player.
function M.picker(cat, chosen)
  local c = M.normalize(cat, chosen)
  local page = 1
  for i, s in ipairs(cat.series) do
    local hit = false
    for _, ci in ipairs(s.members) do
      if c[cat.charas[ci][8]] then
        hit = true
        break
      end
    end
    if hit then
      page = i
      break
    end
  end
  return { chosen = c, start = M.sel_key(c), page = page, row = 0 }
end

function M.step_page(cat, p, dir)
  local n = #cat.series
  if n > 0 then
    p.page = ((p.page - 1 + dir) % n) + 1
  end
  p.row = 0
end

-- (players on, players) of the picker's series page (each character once)
function M.page_counts(cat, p)
  local s = cat.series[p.page]
  if not s then
    return 0, 0
  end
  local on, n, seen = 0, 0, {}
  for _, r in ipairs(M.rows(cat, s)) do
    for _, ci in ipairs(r.players) do
      if not seen[ci] then
        seen[ci] = true
        n = n + 1
        if p.chosen[cat.charas[ci][8]] then
          on = on + 1
        end
      end
    end
  end
  return on, n
end

-- player j (1-based) of the open team row: toggled; j = 0: every player of the row (all on, or all off when every
-- one is on). Returns the new state (of player j / of the row), players on, players.
function M.toggle(cat, p, j)
  local s = cat.series[p.page]
  local r = s and M.rows(cat, s)[p.row]
  if not r then
    return false, 0, 0
  end
  local state
  if j == 0 then
    local on, n = M.players_on(cat, r.players, p.chosen)
    state = on < n
    for _, ci in ipairs(r.players) do
      local id = cat.charas[ci][8]
      if id ~= 0 then
        p.chosen[id] = state or nil
      end
    end
  else
    local ci = r.players[j]
    local id = ci and cat.charas[ci][8] or 0
    if id == 0 then
      return false, M.players_on(cat, r.players, p.chosen)
    end
    state = not p.chosen[id]
    p.chosen[id] = state or nil
  end
  local on, n = M.players_on(cat, r.players, p.chosen)
  return state, on, n
end

function M.changed(p)
  return M.sel_key(p.chosen) ~= p.start
end

return M
