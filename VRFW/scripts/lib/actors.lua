-- The match's actor table, read through the game profile (game\<build>\structs.toml [struct.Actor] and
-- [struct.MatchUnit], globals.toml Match.ActorCount): one place for the layout every in-match script walks.
--   local Actors = require "VRFW/lib/actors"   -- any mod's scripts (the framework's own: require "lib/actors")
--   Actors.list([opts]) -> { { index, address, handle, team, chara }, … } in table order; {} outside a match
--     index    0..count-1 (the low byte of the handle)
--     address  the actor record
--     handle   Actor.Handle (u32)
--     team     Actor.Team (u8: 0 / 1 the two sides, other values = not a side)
--     chara    MatchUnit.Chara of the actor's unit (u32, 0 = unknown); read only with opts.chara = true
--     opts.chara = true      also read each actor's character (one game call per actor: Match.ActorUnit)
--     opts.empty = true      keep the records whose handle is 0 (left out by default)
--   Actors.frame()          -> Actors.list(), Actors.base(): the list in tables of the library, filled again by each
--                              call (valid until the next call; read only): a per-frame walk leaves no garbage
--   Actors.field(struct, field[, base]) -> one field of the caller mod's [[VRFW.Struct]] `struct` in every record of
--                              the table (1..count: entry.index + 1) in one read; nil when the struct / field is unknown
--                              or not readable (`base`: the table's address when the caller has it)
--   Actors.each([opts])     -> an iterator over Actors.list(opts): for _, a in Actors.each{ chara = true } do … end
--   Actors.of(handle[, opts]) -> the entry of one handle (its record is index handle & 0xFF), nil when not on the table
--   Actors.chara(address)   -> MatchUnit.Chara of the actor record at `address` (0 = unknown)
--   Actors.base()           -> the address of the actor table, nil outside a match
--   Actors.layout()         -> { count, stride, handle, team, unit_chara } (the profile's numbers), nil + why when the
--                              running build's profile lacks one of them
-- Needs the caller mod's `memory` and `call` permissions (VRFW.game.field, VRFW.mem, VRFW.call). Requiring it also
-- sets VRFW.match.actors to Actors.list in that script's VM.
local M = {}

local ACTOR_TABLE = "Match.SoccerActors.ViaSkillUsed"   -- the framework's shared global binding (content\game\shared.toml)
local ACTOR_UNIT = "Match.ActorUnit"                    -- the framework's shared function binding

local LAYOUT = nil
local LAYOUT_WHY = nil

local function profile_value(name)
  local ok, v = pcall(VRFW.game.field, name)
  if ok and type(v) == "number" then
    return v
  end
  return nil
end

function M.layout()
  if LAYOUT ~= nil or LAYOUT_WHY ~= nil then
    return LAYOUT, LAYOUT_WHY
  end
  local names = {
    count = "Match.ActorCount", stride = "Actor", handle = "Actor.Handle", team = "Actor.Team",
    unit_chara = "MatchUnit.Chara",
  }
  local out = {}
  for key, name in pairs(names) do
    local v = profile_value(name)
    if v == nil then
      LAYOUT_WHY = "the game profile has no " .. name
      VRFW.warn("actors: " .. LAYOUT_WHY)
      return nil, LAYOUT_WHY
    end
    out[key] = v
  end
  LAYOUT = out
  return LAYOUT
end

function M.base()
  local ok, p = pcall(VRFW.game[ACTOR_TABLE])
  if ok and type(p) == "number" and p >= 0x10000 then
    return p
  end
  return nil
end

function M.chara(address)
  local L = M.layout()
  if L == nil or type(address) ~= "number" or address < 0x10000 then
    return 0
  end
  local ok, unit = pcall(VRFW.call, ACTOR_UNIT, address)
  if not ok or type(unit) ~= "number" or unit < 0x10000 then
    return 0
  end
  local okr, v = pcall(VRFW.mem.read, "u32", unit + L.unit_chara)
  if okr and type(v) == "number" then
    return v
  end
  return 0
end

function M.list(opts)
  opts = opts or {}
  local out = {}
  local L = M.layout()
  local base = L and M.base()
  if base == nil then
    return out
  end
  local okh, handles = pcall(VRFW.mem.read_array, "u32", base + L.handle, L.count, L.stride)
  local okt, teams = pcall(VRFW.mem.read_array, "u8", base + L.team, L.count, L.stride)
  if not okh or type(handles) ~= "table" or not okt or type(teams) ~= "table" then
    return out
  end
  for i = 0, L.count - 1 do
    local handle = handles[i + 1] or 0
    if handle ~= 0 or opts.empty then
      local address = base + i * L.stride
      local a = { index = i, address = address, handle = handle, team = teams[i + 1] or 0xFF }
      if opts.chara then
        a.chara = M.chara(address)
      end
      out[#out + 1] = a
    end
  end
  return out
end

-- Actors.frame(): the list and its entries are kept and filled again (a frame walk allocates nothing)
local FRAME_LIST, FRAME_ENTRIES, FRAME_N = {}, {}, 0

function M.frame()
  local out = FRAME_LIST
  for i = FRAME_N, 1, -1 do out[i] = nil end
  FRAME_N = 0
  local L = M.layout()
  local base = L and M.base()
  if base == nil then
    return out, nil
  end
  local okh, handles = pcall(VRFW.mem.read_array, "u32", base + L.handle, L.count, L.stride)
  local okt, teams = pcall(VRFW.mem.read_array, "u8", base + L.team, L.count, L.stride)
  if not okh or type(handles) ~= "table" or not okt or type(teams) ~= "table" then
    return out, base
  end
  local n = 0
  for i = 0, L.count - 1 do
    local handle = handles[i + 1] or 0
    if handle ~= 0 then
      n = n + 1
      local a = FRAME_ENTRIES[n]
      if a == nil then
        a = {}
        FRAME_ENTRIES[n] = a
      end
      a.index, a.address, a.handle, a.team = i, base + i * L.stride, handle, teams[i + 1] or 0xFF
      out[n] = a
    end
  end
  FRAME_N = n
  return out, base
end

-- [struct .. "." .. field] = { at, type } (false = unknown): asked once
local FIELDS = {}

function M.field(struct, field, base)
  local key = struct .. "." .. field
  local f = FIELDS[key]
  if f == nil then
    f = false
    if type(VRFW.mem.field_of) == "function" then
      local ok, at, ty = pcall(VRFW.mem.field_of, struct, field)
      if ok and type(at) == "number" and type(ty) == "string" then f = { at = at, type = ty } end
    end
    FIELDS[key] = f
  end
  if not f then
    return nil
  end
  local L = M.layout()
  base = base or (L and M.base())
  if L == nil or base == nil then
    return nil
  end
  local ok, values = pcall(VRFW.mem.read_array, f.type, base + f.at, L.count, L.stride)
  if ok and type(values) == "table" then
    return values
  end
  return nil
end

function M.each(opts)
  local list = M.list(opts)
  local i = 0
  return function()
    i = i + 1
    local a = list[i]
    if a == nil then
      return nil
    end
    return i, a
  end
end

function M.of(handle, opts)
  local L = M.layout()
  local base = L and M.base()
  if base == nil or type(handle) ~= "number" or handle == 0 then
    return nil
  end
  local i = handle % 256
  if i >= L.count then
    return nil
  end
  local address = base + i * L.stride
  local okh, h = pcall(VRFW.mem.read, "u32", address + L.handle)
  if not okh or h ~= handle then
    return nil
  end
  local okt, team = pcall(VRFW.mem.read, "u8", address + L.team)
  local a = { index = i, address = address, handle = h, team = okt and team or 0xFF }
  if opts and opts.chara then
    a.chara = M.chara(address)
  end
  return a
end

if type(VRFW) == "table" and type(VRFW.match) == "table" and rawget(VRFW.match, "actors") == nil then
  pcall(rawset, VRFW.match, "actors", M.list)
end

return M
