-- Utilities › Home / Away kit (feature away_kit; docs/game/mechanics/away-kit.md).
--
-- Every retail kit uniform has two model sets: typeId 0 (worn normally) and typeId 1 (the alternate, worn only when
-- both teams have the SAME uniform id). For most kits uniform_config also has a twin uniform with the typeIds swapped,
-- so the away shirt is the default and the home shirt the alternate. The team's kit is TeamInfo.uniformId (+0x290):
-- writing the twin id there makes the team wear the away shirt everywhere, keeps the clash rule working and survives
-- without the mod (the twin is an ordinary retail uniform id).
--
-- Commands (content\game\away_kit.toml):
--   CMND_BETTERQOL_TEAM_UNIFORM(set, team [, uniform [, src_team]]) -> ok, uniformId   (alias CMND_EVT_TEAM_UNIFORM)
--   CMND_BETTERQOL_AK_PAIR(uniform) -> the away twin of a kit / the kit of a twin (0 = none)
-- src_team: copy the kit of another team of the same set (the 11v11 kit onto the kit-less 5v5 team), only when
-- `uniform` IS that team's kit. A write onto a team without a kit is refused, except the one uniform id the game_state
-- key utilities.away_kit.kitless.uniform answers right now (another mod provides it; 0 / none = off).
--
-- The pairs are derived from the item_config / uniform_config the game loads (mods' kits included): the mod ships
-- no kit id.

local MAX_SET = 16 -- highest logical set (retail docks 0..15; 16 = the mode-mapped story set)
local TEAMS = 3 -- teams per set (11v11, 5v5, ...)
local KITLESS_KEY = "utilities.away_kit.kitless.uniform"
local SEP = "\1"

local writes = 0

local function u32(v)
  return bit32.band(v or 0, 0xFFFFFFFF)
end

-- a Lua number argument as the game's u32 (truncated, wrapped); nil when it is not a number
local function arg_u32(v)
  if type(v) ~= "number" then
    return nil
  end
  return u32(v >= 0 and math.floor(v) or math.ceil(v))
end

local function write_allowed(set, team, cur, new)
  return set <= MAX_SET and team < TEAMS and cur ~= 0 and new ~= 0
end

local function kitless_allowed(set, team, cur, new, kitless)
  return kitless ~= 0 and set <= MAX_SET and team < TEAMS and cur == 0 and new == kitless
end

local function copy_allowed(set, team, src, src_cur, new)
  return set <= MAX_SET and team < TEAMS and src < TEAMS and src ~= team and src_cur ~= 0 and new == src_cur
end

-- the TeamInfo record of (set, team), nil when the party is not there yet
local function team_info(set, team)
  local party = VRFW.game.party()
  if not party then
    return nil
  end
  local ok, p = pcall(VRFW.call, "Team.SetStruct", party, set, team)
  if not ok or not p or p < 0x10000 then
    return nil
  end
  local ok2, rec = pcall(VRFW.mem.struct, "TeamInfo", p)
  return ok2 and rec or nil
end

local function read_uniform(rec)
  local ok, u = pcall(function() return rec.uniform end)
  return ok and u or 0
end

function BetterQoL.TeamUniform(set, team, uniform, src_team)
  set, team = arg_u32(set), arg_u32(team)
  if not set or not team then
    return false, 0
  end
  local rec = (set <= MAX_SET and team < TEAMS) and team_info(set, team) or nil
  if not rec then
    return false, 0
  end
  local cur = read_uniform(rec)
  local new = arg_u32(uniform)
  if not new then
    return true, cur
  end
  local copy = false
  local src = arg_u32(src_team)
  if src then
    local r = team_info(set, src)
    copy = r ~= nil and copy_allowed(set, team, src, read_uniform(r), new)
  end
  local kitless = kitless_allowed(set, team, cur, new, u32(VRFW.state.get(KITLESS_KEY) or 0))
  if not copy and not kitless and not write_allowed(set, team, cur, new) then
    VRFW.warn(string.format("refused set %d team %d: uniform 0x%08X -> 0x%08X", set, team, cur, new))
    return false, cur
  end
  local ok = true
  if new ~= cur then
    ok = pcall(function() rec.uniform = new end)
  end
  if writes < 50 then
    writes = writes + 1
    local ok_inv, inv = pcall(function() return rec.uniform_item end)
    VRFW.log(string.format("set %d team %d (kit item 0x%08X): uniform 0x%08X -> 0x%08X ok=%s", set, team, ok_inv and inv or 0, cur, new, tostring(ok)))
  end
  return ok, read_uniform(rec)
end

-- ---------------------------------------------------------------------------------------------- the pair map

-- a cell as text (arrays / records: their elements)
local function cell_text(v)
  if type(v) == "table" then
    local parts = {}
    for i = 1, #v do
      parts[i] = cell_text(v[i])
    end
    for k, x in pairs(v) do
      if type(k) == "string" then
        parts[#parts + 1] = k .. "=" .. cell_text(x)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(v)
end

-- uniform id -> { [0] = model typeId 0, [1] = model typeId 1 }, each { full = every field but typeId, main = the
-- fielder + keeper shirts (the first two) }, for every uniform with exactly two model rows of typeIds 0 and 1
local function shapes()
  local uniforms = VRFW.table.rows("character/uniform")
  local models = VRFW.table.rows("character/uniform_model_info")
  local cols = VRFW.table.columns("character/uniform_model_info")
  local type_col
  for i, c in ipairs(cols) do
    if c == "type_id" then
      type_col = i
    end
  end
  if not type_col then
    error("uniform_model_info has no type_id column")
  end
  local out = {}
  for _, row in ipairs(uniforms) do
    local id, slice = row.name_id, row.model_info
    if id and type(slice) == "table" and slice.count == 2 and slice.start >= 0 and slice.start + 2 <= #models then
      local by = {}
      for k = slice.start + 1, slice.start + 2 do
        local m = models[k]
        local ty = m[type_col]
        if ty == 0 or ty == 1 then
          local rest = {}
          for i = 1, #cols do
            if i ~= type_col then
              rest[#rest + 1] = cell_text(m[i])
            end
          end
          by[ty] = { full = table.concat(rest, SEP), main = (rest[1] or "") .. SEP .. (rest[2] or "") }
        end
      end
      if by[0] and by[1] then
        out[u32(id)] = by
      end
    end
  end
  return out
end

-- the kits: uniform id (item_config ITEM_FASHION_INFO column `uniform`) -> item key; the first item of a uniform wins
local function kits()
  local out, n = {}, 0
  for _, row in ipairs(VRFW.table.rows("item/item_fashion")) do
    local u = u32(row.uniform)
    if u ~= 0 and out[u] == nil then
      out[u] = row.key or ""
      n = n + 1
    end
  end
  return out, n
end

-- kit -> its twin (a twin that is a kit wins, then the lowest id); every other candidate twin -> its kit
local function build()
  local kit, nkits = kits()
  local shape = shapes()
  local by_full, by_main = {}, {}
  for id, s in pairs(shape) do
    local f, m = s[0].full .. SEP .. SEP .. s[1].full, s[0].main .. SEP .. SEP .. s[1].main
    by_full[f] = by_full[f] or {}
    table.insert(by_full[f], id)
    by_main[m] = by_main[m] or {}
    table.insert(by_main[m], id)
  end
  local order = {}
  for u, k in pairs(kit) do
    order[#order + 1] = { k, u }
  end
  table.sort(order, function(a, b)
    if a[1] ~= b[1] then
      return a[1] < b[1]
    end
    return a[2] < b[2]
  end)
  local map, back, with_twin = {}, {}, 0
  for _, e in ipairs(order) do
    local u = e[2]
    local s = shape[u]
    if s then
      local cands = by_full[s[1].full .. SEP .. SEP .. s[0].full] or {}
      if #cands == 0 then
        cands = by_main[s[1].main .. SEP .. SEP .. s[0].main] or {}
      end
      local others, in_kits = {}, {}
      for _, c in ipairs(cands) do
        if c ~= u then
          others[#others + 1] = c
          if kit[c] ~= nil then
            in_kits[#in_kits + 1] = c
          end
        end
      end
      local pref = #in_kits > 0 and in_kits or others
      local best
      for _, c in ipairs(pref) do
        if best == nil or c < best then
          best = c
        end
      end
      if best then
        map[u] = best
        with_twin = with_twin + 1
        back[#back + 1] = { u, others }
      end
    end
  end
  for _, b in ipairs(back) do
    for _, t in ipairs(b[2]) do
      if map[t] == nil then
        map[t] = b[1]
      end
    end
  end
  local ik, iov = VRFW.table.source("item/item_fashion")
  local uk, uov = VRFW.table.source("character/uniform")
  local from = function(o) return o and "mods overlay" or "game" end
  VRFW.log(string.format("kit tables: %s (%s), %s (%s); %d kit pair(s) of %d kit(s)", ik, from(iov), uk, from(uov), with_twin, nkits))
  return map
end

local pair_map
local tried = false

local function pair_map_now()
  if pair_map == nil and not tried then
    tried = true
    local ok, m = pcall(build)
    if ok then
      pair_map = m
    else
      VRFW.warn("kit pairs not built (" .. tostring(m) .. "): no kit has an away version")
      pair_map = {}
    end
  end
  return pair_map or {}
end

function BetterQoL.AwayKitPair(uniform)
  local u = arg_u32(uniform)
  if not u then
    return 0
  end
  return pair_map_now()[u] or 0
end

-- built once while the framework starts (the tables the game loads are served by then)
pair_map_now()
