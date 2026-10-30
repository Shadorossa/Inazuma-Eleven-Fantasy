-- Squad card limit for a mod's own card type (native side: content\game\limits_squad.toml), declared in <mod>\content\defaults\limits.toml:
--   [limits.squad.card_type.prime]          # <mod>\content\defaults\limits.toml
--   rarities = [10]                         # the card rarities of the type
--   counts_as = "diamond"                   # the game's check it shares (its retail limit: 1 per squad)
--   when = { state = "fantasy.prime.team_limit" }   # optional: on while that game_state key is non-zero
-- The Diamond counter then answers the largest of the game's count and each such type's starters, so a second card of the type trips the game's 1-Diamond check; when Diamonds are lifted (`max_per_card_type.diamond = "unlimited"`) the type's own limit stays.

require "VRFW/lib/basics"
local info, warn = VRFW.logger("limits")

-- Team set layout the counter walks: 29 member entries from +0x80, stride 0x10, +0 handle, +0xE slot (starters = slot < 11, < 5 for party type 1); same as synergy.lua.
local N_MEMBERS, MEMBER_BASE, MEMBER_STRIDE, MEMBER_SLOT = 0x1D, 0x80, 0x10, 0x0E
local STARTERS, STARTERS_PARTY1 = 11, 5
local HOOK = "LimitsDiamondCounter"
local LOG_FIRST = 20

-- every mod's limits file (the later place of a mod wins, as the native plan reads it)
local function limit_files()
  local ok, files = pcall(VRFW.files.declarations, { "defaults/limits.toml", "content/defaults/limits.toml" })
  if not ok or type(files) ~= "table" then
    warn("limits files not read (" .. tostring(files) .. "): no card types of mods")
    return {}, {}
  end
  local by_mod, order = {}, {}
  for _, f in ipairs(files) do
    if not by_mod[f.mod] then order[#order + 1] = f.mod end
    by_mod[f.mod] = f.data
  end
  return by_mod, order
end

local function squad_of(t)
  local l = type(t) == "table" and t.limits
  return type(l) == "table" and type(l.squad) == "table" and l.squad or nil
end

-- the declared card types: name -> { mod, rarities = set, list, counts_as, when_state }
local function card_types()
  local by_mod, order = limit_files()
  local fw = squad_of(by_mod[VRFW.mod]) or {}
  local native = type(fw.native) == "table" and fw.native or {}
  local types = {}
  for _, m in ipairs(order) do
    local sq = m ~= VRFW.mod and squad_of(by_mod[m]) or nil
    local ct = sq and sq.card_type
    if type(ct) == "table" then
      for name, d in pairs(ct) do
        local why
        local set, list = {}, {}
        if type(d) ~= "table" then
          why = "not a table"
        else
          for _, r in ipairs(type(d.rarities) == "table" and d.rarities or {}) do
            if type(r) == "number" and r >= 0 and r == math.floor(r) then
              set[r], list[#list + 1] = true, r
            end
          end
          local nt = native[d.counts_as or ""]
          if #list == 0 then
            why = "no `rarities`"
          elseif type(nt) ~= "table" or nt.counter ~= HOOK then
            why = string.format("counts_as = %s: no card type of the game whose count the framework answers (\"diamond\")", tostring(d.counts_as))
          elseif d.when ~= nil and not (type(d.when) == "table" and type(d.when.state) == "string") then
            why = "`when` must be { state = \"<game_state key>\" }"
          end
        end
        if why then
          warn(string.format("%s: [limits.squad.card_type.%s]: %s: ignored", m, name, why))
        else
          if types[name] then
            warn(string.format("card type %s of %s replaces the one of %s", name, m, types[name].mod))
          end
          types[name] = { mod = m, rarities = set, list = list, counts_as = d.counts_as, when_state = d.when and d.when.state or nil }
        end
      end
    end
  end
  return types
end

local TYPES = card_types()
local NAMES = {}
for name in pairs(TYPES) do NAMES[#NAMES + 1] = name end
table.sort(NAMES)

local function on(t)
  if not t.when_state then return true end
  local v = VRFW.state(t.when_state)
  return v ~= nil and v ~= 0 and v ~= false
end

-- the starters of a team set whose rarity is in each on type's set: { name -> count }, nil when not readable
local function count(team_type, party_type, active)
  local teams = VRFW.game.LimitsParty()
  if not teams or teams == 0 then return nil end
  local ok, base = pcall(VRFW.call, "LimitsTeamSet", teams, team_type, party_type)
  if not ok or type(base) ~= "number" or base < 0x10000 then return nil end
  local starters = party_type == 1 and STARTERS_PARTY1 or STARTERS
  local n = {}
  for _, t in ipairs(active) do n[t] = 0 end
  for i = 0, N_MEMBERS - 1 do
    local e = base + MEMBER_BASE + i * MEMBER_STRIDE
    local ok1, hdl = pcall(VRFW.mem.read, "u32", e)
    local ok2, slot = pcall(VRFW.mem.read, "u8", e + MEMBER_SLOT)
    if not (ok1 and ok2) then return nil end
    if hdl ~= 0 and slot < starters then
      local okr, r = pcall(VRFW.call, "LimitsRarity", hdl)
      if okr and type(r) == "number" then
        for _, t in ipairs(active) do
          if TYPES[t].rarities[r] then n[t] = n[t] + 1 end
        end
      end
    end
  end
  return n
end

local logged = 0

VRFW.on("hook:LimitsDiamondCounter:post", function(ev)
  if #NAMES == 0 then return nil end
  local team_type, party_type = ev.args[1], ev.args[2]
  if type(team_type) ~= "number" or team_type >= 0x10 then return nil end
  local active = {}
  for _, name in ipairs(NAMES) do
    if on(TYPES[name]) then active[#active + 1] = name end
  end
  if #active == 0 then return nil end
  local n = count(team_type, party_type, active)
  if not n then return nil end
  local d = tonumber(ev.ret) or 0
  local best, who = d, nil
  for _, name in ipairs(active) do
    if n[name] > best then best, who = n[name], name end
    if n[name] >= 2 and logged < LOG_FIRST then
      logged = logged + 1
      info(string.format("team %d party %d: %d %s starters -> refused like 2 Diamonds", team_type, party_type, n[name], name))
    end
  end
  if who then return { ret = best } end
  return nil
end)

if #NAMES > 0 then
  local ok, err = pcall(VRFW.state.set, "vrfw.limits.squad_types", 1)
  local parts = {}
  for _, name in ipairs(NAMES) do
    local t = TYPES[name]
    parts[#parts + 1] = string.format("%s (%s: rarities %s, counts as %s%s)", name, t.mod, table.concat(t.list, "/"), t.counts_as,
      t.when_state and (", while " .. t.when_state) or "")
  end
  if ok then
    info(string.format("squad card types of mods: %s; %s %s", table.concat(parts, ", "), HOOK, VRFW.is_on(HOOK) and "hooked" or "OFF"))
  else
    warn("vrfw.limits.squad_types not set (" .. tostring(err) .. "): the card types of mods are not counted")
  end
end
