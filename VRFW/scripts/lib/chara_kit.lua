-- VR-Framework › a card's own team kit (docs/framework/contact-map.md §18). A menu that builds a card's 3D model with
-- uniform 0 shows the generic kit (Raimon): this library gives the uniform of HIS team instead, derived from the data
-- the game loads (the mods overlay's served tables, so a mod's characters, teams and kits count the same way). Nothing
-- here names a character, a team or a kit.
--
--   Kit.of(card) -> uniform, flags, source        card = chara_param id; uniform 0 = none found (keep the default);
--                                                 flags = 2 for a goalkeeper card (the keeper shirt of that kit);
--                                                 source = "belong" | "roster" | "none" (for the log)
--
-- The chain, first hit wins (every candidate must be a uniform_config id, or a kit item whose model column names one):
--   1. belong: chara_base (chara_param col 1) team_1 / team_2 / team_3 -> belong_team_config teamKit_<era>; the era is
--      the one of the character's series (chara_base series -> chara_series type k; the k-th teamNumber_<x> column of
--      belong_team_config names the era <x>: ie1 -> ie, go2 -> go, ares / orion -> areori, v -> v), then the team's
--      other eras in column order (a team with no kit in his era);
--   2. roster: the first team of team_config (table order: the game's, then the mods' built teams) whose members list
--      the card, its `uniform` (read only on the first card the belong chain cannot dress);
--   3. none: 0, the caller's default.
-- Every table is read once per session (only the needed columns, VRFW.table.raw) by M.prepare() or the first call;
-- answers are cached per card.

local M = {}

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local function col(row, ...)
  for i = 1, select("#", ...) do
    local v = row[select(i, ...)]
    if v ~= nil then return v end
  end
  return nil
end

-- the served file of a table id (the mods overlay's, else the game's) for VRFW.table.raw
local function key_of(id, glob)
  local ok, k = pcall(VRFW.table.source, id)
  if ok and type(k) == "string" and k ~= "" then return k end
  return glob
end

-- 1-based position of column `name` of table `id` (schema names; nil = not there)
local function pos_of(id, ...)
  local ok, cols = pcall(VRFW.table.columns, id)
  if not ok or type(cols) ~= "table" then return nil end
  for i, c in ipairs(cols) do
    for k = 1, select("#", ...) do
      if c == select(k, ...) then return i end
    end
  end
  return nil
end

local D = nil          -- the tables, read once
local CACHE = {}       -- card -> { uniform, flags, source }

local function read_all()
  if D ~= nil then return D end
  local t0 = VRFW.now()
  D = { uniform = {}, item_uniform = {}, series = {}, kits = {}, type_era = {}, eras = 0, chara = {}, card = {},
        roster = nil, n_uniform = 0 }
  -- the uniforms (uniform_config m_UniformInfoList nameId)
  pcall(function()
    local rows = VRFW.table.raw(key_of("character/uniform", "data/common/gamedata/character/uniform_config_*.cfg.bin"),
      "m_UniformInfoList", { 1 })
    for _, r in ipairs(rows or {}) do
      local id = u32(r[1])
      if id ~= 0 then
        D.uniform[id] = true
        D.n_uniform = D.n_uniform + 1
      end
    end
  end)
  -- kit items: item id -> its model's uniform (ITEM_FASHION_INFO `uniform`); a team / belong kit may name the item
  pcall(function()
    local p = pos_of("item/item_fashion", "uniform")
    if p == nil then return end
    local rows = VRFW.table.raw(key_of("item/item_fashion", "data/common/gamedata/item/item_config_*.cfg.bin"),
      "ITEM_FASHION_INFO", { 1, p })
    for _, r in ipairs(rows or {}) do
      local id, u = u32(r[1]), u32(r[p])
      if id ~= 0 and u ~= 0 and D.item_uniform[id] == nil then D.item_uniform[id] = u end
    end
  end)
  -- series id -> series type
  pcall(function()
    for _, r in ipairs(VRFW.table.rows("character/chara_series")) do
      local id = u32(col(r, "chara_series_id", "charaSeriesId"))
      if id ~= 0 then D.series[id] = u32(col(r, "chara_series_type", "charaSeriesType")) end
    end
  end)
  -- belong_team_config: the era kit columns, series type k -> era (the k-th teamNumber_<x> column), team -> kits
  pcall(function()
    local nums, eras = {}, {}
    for i, n in ipairs(VRFW.table.columns("character/belong_team")) do
      local x = n:match("^team_number_(.+)$") or n:match("^teamNumber_(.+)$")
      if x then nums[#nums + 1] = x:lower() end
      local e = n:match("^team_kit_(.+)$") or n:match("^teamKit_(.+)$")
      if e then eras[#eras + 1] = { name = e:lower(), col = i } end
    end
    for k, x in ipairs(nums) do
      for ei, e in ipairs(eras) do
        if x:sub(1, #e.name) == e.name or (#x >= 3 and e.name:find(x:sub(1, 3), 1, true)) then
          D.type_era[k] = ei
          break
        end
      end
    end
    D.eras = #eras
    for _, r in ipairs(VRFW.table.rows("character/belong_team")) do
      local id = u32(col(r, "belong_team_id", "belongTeamId"))
      if id ~= 0 then
        local kits = {}
        for ei, e in ipairs(eras) do kits[ei] = u32(r[e.col]) end
        D.kits[id] = kits
      end
    end
  end)
  -- chara_base: series and teams per character (only those columns)
  pcall(function()
    local ps = pos_of("character/chara_base", "series")
    local p1, p2, p3 = pos_of("character/chara_base", "team_1"), pos_of("character/chara_base", "team_2"),
      pos_of("character/chara_base", "team_3")
    if not (ps and p1 and p2 and p3) then return end
    local rows = VRFW.table.raw(key_of("character/chara_base", "data/common/gamedata/character/chara_base_*.cfg.bin"),
      "CHARA_BASE_INFO", { 1, ps, p1, p2, p3 })
    for _, r in ipairs(rows or {}) do
      local id = u32(r[1])
      if id ~= 0 then D.chara[id] = { u32(r[ps]), u32(r[p1]), u32(r[p2]), u32(r[p3]) } end
    end
  end)
  -- chara_param: the character and the main position per card
  pcall(function()
    local pb = pos_of("character/chara_param", "chara", "chara_base") or 2
    local pp = pos_of("character/chara_param", "main_position")
    local want = { 1, pb }
    if pp then want[#want + 1] = pp end
    local rows = VRFW.table.raw(key_of("character/chara_param", "data/common/gamedata/character/chara_param_*.cfg.bin"),
      "CHARA_PARAM_INFO", want)
    for _, r in ipairs(rows or {}) do
      local id = u32(r[1])
      if id ~= 0 then D.card[id] = { u32(r[pb]), pp and u32(r[pp]) or 0 } end
    end
  end)
  VRFW.log(string.format("chara_kit: tables read in %d ms (%d uniforms, %d belong teams, %d eras, %d characters, %d cards)",
    math.floor(VRFW.now() - t0), D.n_uniform, (function() local n = 0 for _ in pairs(D.kits) do n = n + 1 end return n end)(),
    D.eras, (function() local n = 0 for _ in pairs(D.chara) do n = n + 1 end return n end)(),
    (function() local n = 0 for _ in pairs(D.card) do n = n + 1 end return n end)()))
  return D
end

-- a kit value -> a uniform_config id (itself, or the model of a kit item); nil = none
local function resolve(v)
  v = u32(v)
  if v == 0 then return nil end
  if D.uniform[v] then return v end
  local u = D.item_uniform[v]
  if u ~= nil and D.uniform[u] then return u end
  return nil
end

local function belong_kit(base)
  local c = D.chara[base]
  if c == nil then return nil end
  local era = D.type_era[D.series[c[1]] or 0]
  for t = 2, 4 do
    local kits = c[t] ~= 0 and D.kits[c[t]] or nil
    if kits ~= nil then
      local u = era and resolve(kits[era]) or nil
      if u then return u end
      for ei = 1, D.eras do
        u = resolve(kits[ei])
        if u then return u end
      end
    end
  end
  return nil
end

-- card -> uniform of the first team_config team listing him (built on the first card that needs it)
local function roster_kit(card)
  if D.roster == nil then
    D.roster = {}
    local t0 = VRFW.now()
    local ok, err = pcall(function()
      local key = key_of("team/team", "data/common/gamedata/team/team_config_*.cfg.bin")
      local pu = pos_of("team/team", "uniform") or 6
      local teams = VRFW.table.raw(key, "SOCCER_TEAM_INFO", { pu })
      local refs = VRFW.table.raw(key, "SOCCER_TEAM_INFO_REF_MEMBER", { 1, 2 })
      local members = VRFW.table.raw(key, "SOCCER_TEAM_MEMBER", { 1 })
      if type(teams) ~= "table" or type(refs) ~= "table" or type(members) ~= "table" or #refs ~= #teams then
        error("team_config rows / member refs do not match")
      end
      for i, t in ipairs(teams) do
        local u = resolve(t[pu])
        local a, n = tonumber(refs[i][1]), tonumber(refs[i][2])
        if u and a and n then
          for k = a + 1, a + n do
            local c = members[k] and u32(members[k][1]) or 0
            if c ~= 0 and D.roster[c] == nil then D.roster[c] = u end
          end
        end
      end
    end)
    VRFW.log(string.format("chara_kit: team rosters read in %d ms%s", math.floor(VRFW.now() - t0),
      ok and "" or (" (" .. tostring(err) .. ")")))
  end
  return D.roster[card]
end

-- read the tables now (a script's load: off the game thread); the team rosters stay for the first card that needs them
function M.prepare()
  read_all()
end

function M.of(card)
  card = u32(card)
  local c = CACHE[card]
  if c ~= nil then return c[1], c[2], c[3] end
  read_all()
  local u, src, flags = nil, "none", 0
  local p = D.card[card]
  if p ~= nil then
    u = belong_kit(p[1])
    if u then src = "belong" end
    if p[2] == 1 then flags = 2 end        -- main position 1 = GK (chara_position): the kit's keeper shirt
  end
  if u == nil and card ~= 0 then
    u = roster_kit(card)
    if u then src = "roster" end
  end
  if u == nil then flags = 0 end
  CACHE[card] = { u or 0, flags, src }
  return u or 0, flags, src
end

return M
