-- Career mode teams: the clubs declared by the source mods (config.toml [teams]), their ratings and their club
-- families. Nothing here names a team: every club comes from the source mods' content\teams\ declarations.
local M = {}

local floor = math.floor
local TWO32 = 4294967296

local function u32(n)
  n = tonumber(n)
  if n == nil then
    return 0
  end
  n = floor(n) % TWO32
  if n < 0 then
    n = n + TWO32
  end
  return n
end
M.u32 = u32

require "VRFW/lib/basics"
local GameText = require "VRFW/lib/game_text"
local config = VRFW.config
M.config = config

local info, warn = VRFW.logger("teams")

-- a card number: a number, "0x…" text or a "<mod>.<name>" key of id kind chara
local function card_of(v)
  if type(v) == "number" then
    return u32(v)
  end
  if type(v) == "string" then
    local hex = v:match("^0[xX](%x+)$")
    if hex then
      return u32(tonumber(hex, 16))
    end
    local ok, n = pcall(VRFW.ids.resolve, "chara", v)
    if ok and type(n) == "number" then
      return u32(n)
    end
  end
  return 0
end

local function set_of(list)
  local out = {}
  for _, v in ipairs(type(list) == "table" and list or {}) do
    out[tostring(v)] = true
  end
  return out
end

-- the clubs of the source mods and the game's own teams of config [teams] game_team_pattern:
-- { { id, key, name_text, rating, players = { { card, uid, slot, number } }, game } }, sorted by key; nil + why when
-- there is none
function M.load()
  local sources = set_of(config("teams.sources", {}))
  local level = tonumber(config("teams.level", 0)) or 0
  local needs = config("teams.require", {})
  local last_slot = tonumber(config("teams.player_slot_max", 18)) or 18
  local ok, files = pcall(VRFW.files.declarations, "content/teams")
  if not ok or type(files) ~= "table" then
    return nil, "team declarations not readable: " .. tostring(files)
  end
  local out, seen, mods = {}, {}, {}
  for _, f in ipairs(files) do
    if sources[tostring(f.mod)] and type(f.data) == "table" then
      mods[tostring(f.mod)] = true
      for _, t in ipairs(type(f.data.team) == "table" and f.data.team or {}) do
        local good = type(t.key) == "string" and t.key ~= "" and type(t.member) == "table"
        if good and level > 0 then
          good = tonumber(t.level) == level
        end
        for _, field in ipairs(type(needs) == "table" and needs or {}) do
          if t[field] == nil then
            good = false
          end
        end
        if good then
          local id = u32(VRFW.crc32(t.key))
          if not seen[id] then
            seen[id] = true
            local players = {}
            for _, m in ipairs(t.member) do
              local slot = tonumber(m.slot) or -1
              local card = card_of(m.card or m.player)
              if slot >= 0 and slot <= last_slot and card ~= 0 then
                players[#players + 1] = { card = card, uid = u32(m.uid or 0), slot = slot,
                  number = tonumber(m.number) or (slot + 1) }
              end
            end
            table.sort(players, function(a, b)
              return a.slot < b.slot
            end)
            local same = {}
            for _, k in ipairs(type(t.same_as) == "table" and t.same_as or {}) do same[#same + 1] = tostring(k) end
            out[#out + 1] = { id = id, key = t.key, name_text = u32(t.name_text or 0), same_as = same, players = players,
              series = tostring(t.series or "") }
          end
        end
      end
    end
  end
  -- the game's own teams of config [teams] game_team_pattern (the game's Battle Bay teams): clubs too
  local pattern = tostring(config("teams.game_team_pattern", ""))
  if pattern ~= "" then
    local game = M.game_teams({}, pattern, level)
    local keys = {}
    for k in pairs(game) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local t = game[k]
      if not seen[t.id] and #t.players > 0 then
        seen[t.id], t.game = true, true
        out[#out + 1] = t
      end
    end
  end
  if #out == 0 then
    return nil, "no club declared by the source mods"
  end
  table.sort(out, function(a, b)
    return a.key < b.key
  end)
  local names = {}
  for m in pairs(mods) do
    names[#names + 1] = m
  end
  table.sort(names)
  info(string.format("%d clubs from %s", #out, table.concat(names, ", ")))
  return out
end

-- the game's own teams no source mod declares (team_config, config.toml [teams] game_table): the ones of `keys`, and
-- with `pattern` (a Lua pattern) every team whose key matches it at `level` (0 = any) ->
-- { [key] = { id, key, name_text, players = { { card, uid, slot, number } }, same_as = {}, series = "" } }
function M.game_teams(keys, pattern, level)
  local out = {}
  if #keys == 0 and (pattern or "") == "" then return out end
  local path = tostring(config("teams.game_table", "data/common/gamedata/team/team_config_*.cfg.bin"))
  local ok1, info_rows = pcall(VRFW.table.raw, path, "SOCCER_TEAM_INFO", { 1, 2, 4, 9 })
  local ok2, refs = pcall(VRFW.table.raw, path, "SOCCER_TEAM_INFO_REF_MEMBER", { 1, 2 })
  local ok3, members = pcall(VRFW.table.raw, path, "SOCCER_TEAM_MEMBER", { 1, 2, 9, 11 })
  if not (ok1 and ok2 and ok3) or type(info_rows) ~= "table" or type(refs) ~= "table" or type(members) ~= "table"
      or #refs ~= #info_rows then
    warn("the game's team table is not readable (" .. path .. "): no game teams")
    return out
  end
  local want = set_of(keys)
  local last_slot = tonumber(config("teams.player_slot_max", 18)) or 18
  for i, r in ipairs(info_rows) do
    local key = type(r[2]) == "string" and r[2] or ""
    local matches = (pattern or "") ~= "" and key:match(pattern) ~= nil
      and ((level or 0) == 0 or tonumber(r[9]) == level)
    if want[key] or matches then
      local first, count = floor(tonumber(refs[i][1]) or 0), floor(tonumber(refs[i][2]) or 0)
      local players = {}
      for k = first + 1, first + count do
        local m = members[k]
        local card, slot = m and u32(m[1] or 0) or 0, m and tonumber(m[9]) or -1
        if card ~= 0 and slot and slot >= 0 and slot <= last_slot then
          local number = tonumber(m[11]) or 0
          players[#players + 1] = { card = card, uid = u32(m[2] or 0), slot = slot, number = number > 0 and number or slot + 1 }
        end
      end
      table.sort(players, function(a, b) return a.slot < b.slot end)
      out[key] = { id = u32(r[1] or 0), key = key, name_text = u32(r[4] or 0), same_as = {}, players = players, series = "" }
    end
  end
  local found = 0
  for _ in pairs(out) do found = found + 1 end
  info(string.format("%d game teams read from %s (%d asked by key)", found, path, #keys))
  return out
end

-- the national sides of `list` (config.toml [teams] national_list of mod national_mod: team keys): a team is one when
-- its series is one of national_series (empty = any), its key is not in national_exclude and its key, a key of its
-- same_as or its name text is one of theirs; each gets national = true -> how many, keys declared
function M.mark_national(list)
  local mod, path = tostring(config("teams.national_mod", "")), tostring(config("teams.national_list", ""))
  if mod == "" or path == "" then
    return 0, 0
  end
  local ok, keys = pcall(VRFW.files.config, path, mod)
  if not ok or type(keys) ~= "table" then
    warn("national sides: " .. mod .. " " .. path .. " not readable (" .. tostring(keys) .. "): every team is a club")
    return 0, 0
  end
  local declared, names = set_of(keys), {}
  local series = set_of(config("teams.national_series", {}))
  local excluded = set_of(config("teams.national_exclude", {}))
  local any_series = next(series) == nil
  local function listed(t)
    if declared[t.key] then return true end
    for _, k in ipairs(t.same_as or {}) do
      if declared[k] then return true end
    end
    return false
  end
  for _, t in ipairs(list) do
    if (any_series or series[t.series]) and not excluded[t.key] and listed(t) and t.name_text ~= 0 then names[t.name_text] = true end
  end
  local n = 0
  for _, t in ipairs(list) do
    t.national = (any_series or series[t.series] == true) and not excluded[t.key]
      and (listed(t) or names[t.name_text] == true)
    if t.national then n = n + 1 end
  end
  info(string.format("%d national side(s) of %d teams (%d keys declared by %s)", n, #list, #keys, mod))
  return n, #keys
end

-- team id -> rating from the rating table (config.toml [ratings] table); unknown teams get the median
function M.rate(list)
  local key = tostring(config("ratings.table", ""))
  local map, values = {}, {}
  if key ~= "" then
    local ok, rows = pcall(VRFW.table.raw, key, tostring(config("ratings.rows", "EVT_BB_RATING")))
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do
        local team, v = u32(r[1]), tonumber(r[2]) or 0
        if team ~= 0 and v > 0 then
          map[team] = v
        end
      end
    else
      info("no rating table (" .. key .. "): the draw uses one rating for every club")
    end
  end
  for _, t in ipairs(list) do
    if map[t.id] then
      values[#values + 1] = map[t.id]
    end
  end
  table.sort(values)
  local median = values[floor((#values + 1) / 2)] or 0
  for _, t in ipairs(list) do
    t.rating = map[t.id] or median
  end
  info(string.format("%d of %d clubs rated (median %s)", #values, #list, tostring(median)))
end

-- the names of the clubs in the family language (config.toml [family] language), by name text id
local function names_of(list)
  local lang = tostring(config("family.language", "en"))
  local ids = {}
  for _, t in ipairs(list) do
    if t.name_text ~= 0 then
      ids[#ids + 1] = t.name_text
    end
  end
  local texts = GameText.texts("team_text", lang, ids)
  if #ids > 0 and next(texts) == nil then
    warn("team names not readable (" .. lang .. "): club families by key only")
    return {}
  end
  local out = {}
  for id, s in pairs(texts) do
    if s ~= "" then
      out[u32(id)] = (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end
  end
  return out
end

-- team id -> family id: two clubs are one family when their keys differ only by a final variant letter after a digit,
-- or their names differ only by a final capital letter («… A» / «… B»)
function M.families(list)
  local names = names_of(list)
  local root, first = {}, {}
  local function find(t)
    while root[t] ~= t do
      t = root[t]
    end
    return t
  end
  for _, t in ipairs(list) do
    root[t.id] = t.id
  end
  for _, t in ipairs(list) do
    local tags = {}
    local base = t.key:match("^(.-%d)[a-z]$")
    if base then
      tags[#tags + 1] = "k:" .. base
    end
    local name = names[t.name_text]
    if name then
      tags[#tags + 1] = "n:" .. (name:match("^(.-)%s+[A-Z]$") or name)
    end
    for _, tag in ipairs(tags) do
      if first[tag] then
        local a, b = find(first[tag]), find(t.id)
        if a ~= b then
          root[b] = a
        end
      else
        first[tag] = t.id
      end
    end
  end
  local out = {}
  for _, t in ipairs(list) do
    out[t.id] = find(t.id)
  end
  return out
end

return M
