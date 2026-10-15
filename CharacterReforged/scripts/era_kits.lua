-- Character Reforged › the ídolos' «Equipación del momento» (era kit): the kit a card wore in its moment of the
-- story. Derived from the game's tables at start and published as the native table CharacterReforged.EraKit (chara_param id ->
-- uniform), which the card look rule content\card_looks\era_kit.toml reads when the card's own chara_param column
-- moment_kit is 0 (a card that declares moment_kit in its character TOML keeps that kit; any mod may declare it).
--
-- The derivation (rules: every active mod's content\era_kits\*.toml, [CharacterReforged.EraKit], later mods win key by
-- key): a card whose chara_param rarity is in card_rarities -> its character (chara_base) -> his teams (team_columns,
-- belong_team_config ids; team_kits maps a team without kits of its own to the team whose kits it wears) -> the kit of
-- the character's era: his series (chara_base series -> chara_series_config type) -> eras[type] = the belong_team kit
-- column; when that team has no kit of that era and any_era is on, its first kit in era_order. A kit must exist in
-- uniform_config. Nothing is written to the save: the player's switch is the card look rule's switch_bit.
--
-- Exports: EraKitOf(card) -> uniform (0 = none), the published value.

CharacterReforged = CharacterReforged or {}
local CR = CharacterReforged

local TABLE = "CharacterReforged.EraKit"
local RULES_DIR = "content/era_kits"
local PARAM, BASE, SERIES, TEAM, UNIFORM = "character/chara_param", "character/chara_base", "character/chara_series",
  "character/belong_team", "character/uniform"

local STATE = { done = false, kits = {} }

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end
local function hex(v)
  v = u32(v)
  return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
end
local function info(...) VRFW.log("era kits:", ...) end
local function warn(...) VRFW.warn("era kits:", ...) end

-- a number, a "0x…" text or a decimal text -> u32 (nil = not a number)
local function id_of(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local s = v:match("^%s*(.-)%s*$")
  local h = s:match("^0[xX](%x+)$")
  if h then return u32(tonumber(h, 16)) end
  local d = tonumber(s)
  return d and u32(d) or nil
end

-- the merged rules of every active mod
local function rules()
  local r = { card_rarities = {}, team_columns = {}, eras = {}, era_order = {}, any_era = true, team_kits = {} }
  local okd, decl = pcall(VRFW.files.declarations, RULES_DIR)
  for _, f in ipairs(okd and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local t = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.EraKit or nil
    if type(t) == "table" then
      if type(t.card_rarities) == "table" then r.card_rarities = t.card_rarities end
      if type(t.team_columns) == "table" then r.team_columns = t.team_columns end
      if type(t.era_order) == "table" then r.era_order = t.era_order end
      if type(t.any_era) == "boolean" then r.any_era = t.any_era end
      for k, v in pairs(type(t.eras) == "table" and t.eras or {}) do r.eras[tonumber(k) or -1] = v end
      for k, v in pairs(type(t.team_kits) == "table" and t.team_kits or {}) do
        local from, to = id_of(k), id_of(v)
        if from and to then r.team_kits[from] = to end
      end
    end
  end
  local set = {}
  for _, x in ipairs(r.card_rarities) do set[tonumber(x) or -1] = true end
  r.rarity_set = set
  return r
end

-- 1-based raw positions of named columns of a T2B table, and its file key
local function positions(id, names)
  local cols = VRFW.table.columns(id)
  local key = VRFW.table.source(id)
  local at = {}
  for i, c in ipairs(cols) do at[c] = i end
  local out = {}
  for _, n in ipairs(names) do
    if not at[n] then error(id .. ": no column " .. n) end
    out[n] = at[n]
  end
  return key, out
end

local function derive()
  local R = rules()
  if next(R.rarity_set) == nil or next(R.eras) == nil then
    info("no card_rarities / eras declared (content\\era_kits): nothing derived")
    return {}, "no rules"
  end
  -- the kits that exist
  local uniforms = {}
  for _, row in ipairs(VRFW.table.rows(UNIFORM)) do uniforms[u32(row.name_id)] = true end
  -- series id -> series type
  local series = {}
  for _, row in ipairs(VRFW.table.rows(SERIES)) do series[u32(row.chara_series_id)] = tonumber(row.chara_series_type) or 0 end
  -- team id -> its row
  local teams = {}
  for _, row in ipairs(VRFW.table.rows(TEAM)) do teams[u32(row.belong_team_id)] = row end
  -- chara_base id -> { series, teams... }
  local base_names = { "id", "series" }
  for _, c in ipairs(R.team_columns) do base_names[#base_names + 1] = c end
  local bkey, bpos = positions(BASE, base_names)
  local bcols = {}
  for _, n in ipairs(base_names) do bcols[#bcols + 1] = bpos[n] end
  local bases = {}
  for _, r in ipairs(VRFW.table.raw(bkey, "CHARA_BASE_INFO", bcols)) do
    local t = {}
    for _, c in ipairs(R.team_columns) do t[#t + 1] = u32(r[bpos[c]]) end
    bases[u32(r[bpos.id])] = { series = u32(r[bpos.series]), teams = t }
  end
  local pkey, ppos = positions(PARAM, { "id", "chara", "special_rarity", "moment_kit" })
  local rows = VRFW.table.raw(pkey, "CHARA_PARAM_INFO", { ppos.id, ppos.chara, ppos.special_rarity, ppos.moment_kit })

  local function kit_of(team, column)
    local row = team and teams[team]
    local k = row and u32(row[column]) or 0
    return (k ~= 0 and uniforms[k]) and k or 0
  end
  local out, stats, missing = {}, { era = 0, other = 0, own = 0 }, {}
  for _, r in ipairs(rows) do
    local param = u32(r[ppos.id])
    if param ~= 0 and R.rarity_set[tonumber(r[ppos.special_rarity]) or -1] and out[param] == nil then
      if u32(r[ppos.moment_kit]) ~= 0 then
        stats.own = stats.own + 1
      else
        local b = bases[u32(r[ppos.chara])]
        local era = b and R.eras[series[b.series] or -1] or nil
        local kit, how = 0, nil
        for _, t in ipairs(b and b.teams or {}) do
          if t ~= 0 then
            local team = teams[t] and t or nil
            local worn = R.team_kits[t]
            if era then kit = kit_of(team, era) end
            if kit == 0 and worn and era then kit = kit_of(worn, era) end
            if kit ~= 0 then how = "era" break end
            if R.any_era then
              for _, col in ipairs(R.era_order) do
                kit = kit_of(team, col)
                if kit == 0 and worn then kit = kit_of(worn, col) end
                if kit ~= 0 then how = "other" break end
              end
              if kit ~= 0 then break end
            end
          end
        end
        if kit ~= 0 then
          out[param] = kit
          stats[how] = stats[how] + 1
        else
          missing[#missing + 1] = hex(param)
        end
      end
    end
  end
  info(string.format("%d card(s) with an era kit (%d of their era, %d of another era of their team); %d declare their own moment_kit; %d not derivable%s",
    stats.era + stats.other, stats.era, stats.other, stats.own, #missing,
    #missing > 0 and (": " .. table.concat(missing, ", ", 1, math.min(#missing, 20))) or ""))
  return out
end

local function publish()
  if STATE.done then return end
  STATE.done = true
  local ok, kits = pcall(derive)
  if not ok then
    warn("not derived (" .. tostring(kits) .. "): the cards keep only their declared moment_kit")
    kits = {}
  end
  STATE.kits = kits
  local entries = {}
  for param, kit in pairs(kits) do entries[#entries + 1] = { param, kit } end
  local okr, er = pcall(VRFW.native.table_replace, TABLE, nil, entries)
  if not okr then warn("native table " .. TABLE .. " not written: " .. tostring(er)) end
end

function CR.EraKitOf(card)
  publish()
  return STATE.kits[u32(card)] or 0
end

VRFW.on("slot_load", function() pcall(publish) end)
VRFW.on("menu:open:post", function() if not STATE.done then pcall(publish) end end)
