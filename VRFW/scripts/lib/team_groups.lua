-- VR-Framework › team groups: the [[VRFW.SynergyPool]] declarations of every active mod (content\synergies\*.toml,
-- VRFW.synergy/1, docs/framework/synergy.md) read as sets of characters, for any script that asks «is this character
-- in that group?» (the passive engine's Trait block). The members come from the framework's card-set evaluator
-- (VRFW.chara.select, characters mode) with the pool's criteria: teams, series, role, gender, charas, exclude. The
-- captain criteria (captains_of, captains_of_teams) are the synergy check's own and are not part of a team group.
--   local G = require "lib/team_groups"           -- the framework's scripts
--   local G = require "VRFW/lib/team_groups"      -- any other mod's scripts
--   G.has_pool(key)          -- the pool is declared (<mod>.<name>)
--   G.members(key)           -- { [chara_base id] = true }, empty when the pool is unknown or not evaluable
--   G.groups_of(base)        -- { [pool key] = true }: the pools with belong teams that hold this character
-- Files only at load; the members are evaluated at their first use (the character index), then kept.

local M = {}

local TWO32 = 4294967296
local GENDER = { male = 1, female = 2 }

local Id = require "VRFW/lib/ids"
local u32 = Id.u32

require "VRFW/lib/basics"
local function list_of(v) return VRFW.value.list(v, {}) end

-- a belong team id: a number, "0x…" or decimal text
local function team_id(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % TWO32 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % TWO32 end
  return nil
end

local function chara_id(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" or v == "" then return nil end
  local ok, id = pcall(VRFW.character, v)
  if ok and type(id) == "number" and id ~= 0 then return u32(id) end
  return u32(VRFW.crc32(v))
end

local POOLS = nil   -- [key] = { key, teams = {ids}, series, role, gender, charas, exclude, members }

local function read()
  if POOLS then return POOLS end
  POOLS = {}
  local ok, files = pcall(VRFW.files.declarations, "content/synergies")
  for _, f in ipairs((ok and type(files) == "table") and files or {}) do
    local d = f.data or {}
    local v = type(d.VRFW) == "table" and d.VRFW or {}
    for _, p in ipairs(type(v.SynergyPool) == "table" and v.SynergyPool or {}) do
      if type(p.name) == "string" then
        local key = tostring(f.mod) .. "." .. p.name
        if not POOLS[key] then
          local x = { key = key, teams = {}, series = list_of(p.series), role = p.role, gender = GENDER[tostring(p.gender)],
            charas = {}, exclude = {} }
          for _, t in ipairs(list_of(p.teams)) do
            local id = team_id(t)
            if id then x.teams[#x.teams + 1] = id end
          end
          for _, c in ipairs(list_of(p.charas)) do
            local id = chara_id(c)
            if id then x.charas[#x.charas + 1] = id end
          end
          for _, c in ipairs(list_of(p.exclude)) do
            local id = chara_id(c)
            if id then x.exclude[#x.exclude + 1] = id end
          end
          POOLS[key] = x
        end
      end
    end
  end
  return POOLS
end

function M.has_pool(key)
  return read()[key] ~= nil
end

-- the characters of a pool (evaluated once)
function M.members(key)
  local p = read()[key]
  if not p then return {} end
  if p.members then return p.members end
  local set = {}
  local include = {}
  if #p.charas > 0 then include[#include + 1] = { characters = p.charas } end
  if #p.teams > 0 or #p.series > 0 or p.role or p.gender then
    local series = {}
    for _, s in ipairs(p.series) do
      local ok, n = pcall(VRFW.chara.series_of, s)
      series[#series + 1] = (ok and n) or s
    end
    include[#include + 1] = { team = #p.teams > 0 and p.teams or nil, series = #series > 0 and series or nil, role = p.role,
      gender = p.gender and { p.gender } or nil }
  end
  if #include > 0 then
    local spec = { include = include, exclude = #p.exclude > 0 and { { characters = p.exclude } } or nil }
    local ok, ids = pcall(VRFW.chara.select, spec, { characters = true })
    if ok and type(ids) == "table" then
      for _, b in ipairs(ids) do set[u32(b)] = true end
    else
      -- the character index is not readable yet: asked again next time
      return set
    end
  end
  p.members = set
  return set
end

local GROUPS_OF = {}

-- the pools naming belong teams that hold character `base`
function M.groups_of(base)
  base = u32(base)
  local g = GROUPS_OF[base]
  if g then return g end
  g = {}
  for key, p in pairs(read()) do
    if #p.teams > 0 and M.members(key)[base] then g[key] = true end
  end
  GROUPS_OF[base] = g
  return g
end

return M
