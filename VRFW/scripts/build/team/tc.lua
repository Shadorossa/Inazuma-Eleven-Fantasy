-- `team_config` in sections: skill loadouts, members (+ role ref), tactics, team info rows with their four `_REF_*` slices.
-- Rows are cell arrays (1-based Lua arrays, column c at [c + 1]); team and member positions are 0-based like the tables' slices.
-- Read and written natively (VRFW.team.tc_read / tc_write: counts and sort runs are regenerated on write).
local T = require "lib/team_util"
local TC = {}
TC.__index = TC

-- columns by name (schemas/team/*.toml); the numbers are used when a schema lacks the name
local function col(key, row, name, n)
  local c = VRFW.team.col(key, row, name)
  if c == nil then return n end
  return c
end

function TC.columns(key)
  local TI = {
    ID = col(key, "SOCCER_TEAM_INFO", "id", 0),
    KEY = col(key, "SOCCER_TEAM_INFO", "key", 1),
    DESC = col(key, "SOCCER_TEAM_INFO", "desc_text", 2),
    NAME = col(key, "SOCCER_TEAM_INFO", "name_text", 3),
    FORMATION = col(key, "SOCCER_TEAM_INFO", "formation", 4),
    KIT = col(key, "SOCCER_TEAM_INFO", "uniform", 5),
    EMBLEM = col(key, "SOCCER_TEAM_INFO", "emblem", 6),
    LEVEL = col(key, "SOCCER_TEAM_INFO", "level", 8),
  }
  local M = "SOCCER_TEAM_MEMBER"
  local TM = {
    PARAM = col(key, M, "chara_param", 0),
    UID = col(key, M, "uid", 1),
    SKILL_CFG = col(key, M, "skill_config", 2),
    SHOES = col(key, M, "shoes", 3),
    EQ2 = col(key, M, "equip_2", 4),
    EQ3 = col(key, M, "equip_3", 5),
    EQ4 = col(key, M, "equip_4", 6),
    TITLE = col(key, M, "title", 7),
    SLOT = col(key, M, "slot", 8),
    FLAG = col(key, M, "flag", 9),
    NUMBER = col(key, M, "kit_number", 10),
    CAPTAIN = col(key, M, "captain", 11),
    LV_OFS = col(key, M, "level_offset", 12),
    RARITY_STEP = col(key, M, "rarity_step", 13),
    C14 = col(key, M, "c14", 14),
    RATE = col(key, M, "rate_1", 20),
  }
  local L = "TEAM_MEMBER_SKILL_CONFIG_INFO"
  local LO = { ID = col(key, L, "id", 0), MOVE1 = col(key, L, "skill_1", 1), LEVEL1 = col(key, L, "skill_1_level", 7) }
  return TI, TM, LO
end

-- ---- cells

-- Cell `c` (0-based) of row `v`: an int (signed), nil when it is not one.
function TC.int(v, c)
  local x = v[c + 1]
  if type(x) == "number" then return x end
  return nil
end

function TC.uint(v, c)
  local x = v[c + 1]
  if type(x) == "number" then return x % T.TWO32 end
  return nil
end

function TC.text(v, c)
  local x = v[c + 1]
  if type(x) == "string" then return x end
  return nil
end

-- Set int cell `c` (the row grows with 0s when shorter).
function TC.set_int(v, c, x)
  for k = #v + 1, c do v[k] = 0 end
  v[c + 1] = T.i32(x)
end

-- Set cell `c` to any cell value (the row grows with 0s).
function TC.set(v, c, x)
  for k = #v + 1, c do v[k] = 0 end
  v[c + 1] = x
end

function TC.copy_row(v)
  local o = {}
  for i = 1, #v do o[i] = v[i] end
  return o
end

-- ---- sections

-- `raw` = VRFW.team.tc_read's sections.
function TC.new(raw, TI, TM, LO)
  local tc = setmetatable({ skill_cfg = raw.skill_cfg, members = raw.members, tactics = raw.tactics, teams = raw.teams,
    base_members = raw.base_members, changed = false, TI = TI, TM = TM, LO = LO }, TC)
  tc:reindex()
  return tc
end

-- Id / key / loadout indices and member row coverage (how many teams' slices hold each row number).
function TC:reindex()
  self.by_id, self.by_key = {}, {}
  for t = #self.teams - 1, 0, -1 do
    local info = self.teams[t + 1].info
    local id, key = TC.uint(info, self.TI.ID), TC.text(info, self.TI.KEY)
    if id then self.by_id[id] = t end
    if key then self.by_key[key] = t end
  end
  self.cover = {}
  for t = 0, #self.teams - 1 do
    local s, n = self:slice(t, 0)
    self:cover_add(s, n, 1)
  end
  self.lo_by_id, self.filler_n = {}, nil
  for k = #self.skill_cfg, 1, -1 do
    local id = TC.uint(self.skill_cfg[k], self.LO.ID)
    if id then self.lo_by_id[id] = k end
  end
end

function TC:cover_add(s, n, d)
  if n <= 0 then return end
  local c = self.cover
  for r = s, s + n - 1 do c[r] = (c[r] or 0) + d end
end

-- The first team with id `id` (0-based), nil when none.
function TC:find(id)
  return self.by_id[id]
end

function TC:find_key(key)
  return self.by_key[key]
end

function TC:key_of(t)
  return TC.text(self.teams[t + 1].info, self.TI.KEY) or ""
end

function TC:id_of(t)
  return TC.uint(self.teams[t + 1].info, self.TI.ID) or 0
end

function TC:info(t)
  return self.teams[t + 1].info
end

-- `start, count` of ref `r` (0 members, 1 tactics, 2 team skills, 3 metamorphose) of team `t`.
function TC:slice(t, r)
  local e = self.teams[t + 1].refs[r + 1]
  local s, n = TC.int(e, 0) or 0, TC.int(e, 1) or 0
  if s < 0 then s = 0 end
  if n < 0 then n = 0 end
  return s, n
end

function TC:set_slice(t, r, s, n)
  if r == 0 then
    local os, on = self:slice(t, 0)
    self:cover_add(os, on, -1)
    self:cover_add(s, n, 1)
  end
  self.teams[t + 1].refs[r + 1] = { s, n }
  self.changed = true
end

-- Member row positions of team `t`: first, end (exclusive).
function TC:member_range(t)
  local s, n = self:slice(t, 0)
  local e = s + n
  if e > #self.members then e = #self.members end
  return s, e
end

function TC:member(i)
  return self.members[i + 1]
end

-- Is the member slice of team `t` used by another team too?
function TC:members_shared(t)
  local s, n = self:slice(t, 0)
  if n <= 0 then return false end
  local c = self.cover
  for r = s, s + n - 1 do
    if (c[r] or 0) > 1 then return true end
  end
  return false
end

-- Replace the roster of team `t` by `rows`: in place when the slice is its own and the count is equal, else as a new slice at the end.
function TC:set_members(t, rows, role)
  local s, n = self:slice(t, 0)
  local own = not self:members_shared(t)
  if n == #rows and own then
    for k, r in ipairs(rows) do self.members[s + k].m = r end
  elseif own and n > 0 and s + n == #self.members then
    -- its own slice at the end (a new team): resized in place
    for k = #self.members, s + 1, -1 do self.members[k] = nil end
    for _, r in ipairs(rows) do self.members[#self.members + 1] = { m = r, r = TC.copy_row(role) } end
    self:set_slice(t, 0, s, #rows)
  else
    local start = #self.members
    for _, r in ipairs(rows) do self.members[#self.members + 1] = { m = r, r = TC.copy_row(role) } end
    self:set_slice(t, 0, start, #rows)
  end
  self.changed = true
end

-- Replace the tactics of team `t`: a new slice at the end (retail slices are shared and never touched).
function TC:set_tactics(t, ids)
  if #self.tactics == 0 then return end
  local start = #self.tactics
  for _, id in ipairs(ids) do self.tactics[#self.tactics + 1] = { T.i32(id) } end
  self:set_slice(t, 1, start, #ids)
end

-- Append a team (info row + its four refs).
function TC:push_team(info, refs)
  self.teams[#self.teams + 1] = { info = info, refs = refs }
  local t = #self.teams - 1
  local id, key = TC.uint(info, self.TI.ID), TC.text(info, self.TI.KEY)
  if id and self.by_id[id] == nil then self.by_id[id] = t end
  if key and self.by_key[key] == nil then self.by_key[key] = t end
  local s, n = self:slice(t, 0)
  self:cover_add(s, n, 1)
  self.changed = true
end

-- A copy of team `t`: info row, refs.
function TC:team_copy(t)
  local x = self.teams[t + 1]
  local refs = {}
  for k = 1, 4 do refs[k] = TC.copy_row(x.refs[k]) end
  return TC.copy_row(x.info), refs
end

-- ---- loadouts

local MOVES = 6

-- How many loadouts hold each value in their 6th slot: counted once, kept current by `put_loadout`.
function TC:filler_counts()
  local c = self.filler_n
  if c then return c end
  c = {}
  for _, e in ipairs(self.skill_cfg) do
    local v = TC.int(e, 6) or 0
    c[v] = (c[v] or 0) + 1
  end
  self.filler_n = c
  return c
end

-- The usual empty move of the loadouts (most common 6th-slot value; ties: the higher value).
function TC:loadout_filler()
  local c = self:filler_counts()
  local best, bn
  for v, n in pairs(c) do
    if best == nil or n > bn or (n == bn and v > best) then best, bn = v, n end
  end
  return best or 0
end

-- A loadout row (id, 6 skills, 6 levels) shaped like the first one; the table's filler fills empty slots. `moves` = { {move, level}, ... }.
function TC:loadout(id, moves)
  local proto = self.skill_cfg[1]
  if not proto then return nil end
  local filler = self:loadout_filler()
  local e = TC.copy_row(proto)
  TC.set_int(e, 0, id)
  for k = 0, MOVES - 1 do
    local p = moves[k + 1]
    local m, lv
    if p then m, lv = p[1], p[2] else m, lv = T.u32(filler), 0 end
    TC.set_int(e, 1 + k, m)
    local l = 0
    if k < #moves then l = lv < 1 and 1 or lv end
    TC.set_int(e, 1 + MOVES + k, l)
  end
  return e
end

-- A `[[loadout]]` row as declared: `moves` (<= 6, {technique, level}; level 0 is kept), missing slots take `filler` at level 0.
function TC:loadout_exact(id, moves, filler)
  local proto = self.skill_cfg[1]
  if not proto then return nil end
  local e = TC.copy_row(proto)
  TC.set_int(e, 0, id)
  for k = 0, MOVES - 1 do
    local p = moves[k + 1]
    local m, lv
    if p then m, lv = p[1], p[2] else m, lv = filler, 0 end
    TC.set_int(e, 1 + k, m)
    TC.set_int(e, 1 + MOVES + k, lv)
  end
  return e
end

-- Put loadout `e` (replacing one with the same id).
function TC:put_loadout(e)
  local id = TC.uint(e, 0)
  local k = id and self.lo_by_id[id]
  local c = self.filler_n
  if c then
    local v = TC.int(e, 6) or 0
    c[v] = (c[v] or 0) + 1
    if k then
      local o = TC.int(self.skill_cfg[k], 6) or 0
      c[o] = c[o] - 1
      if c[o] == 0 then c[o] = nil end
    end
  end
  if k then
    self.skill_cfg[k] = e
  else
    self.skill_cfg[#self.skill_cfg + 1] = e
    if id then self.lo_by_id[id] = #self.skill_cfg end
  end
  self.changed = true
end

function TC:has_loadout(id)
  return self.lo_by_id[id] ~= nil
end

function TC:loadout_row(id)
  local k = self.lo_by_id[id]
  return k and self.skill_cfg[k]
end

-- ---- removal, order

-- Remove team `t` (info + refs) and its own member / tactics rows (never rows another team uses); other teams' slices are re-indexed.
function TC:remove_team(t)
  local ms, mn = self:slice(t, 0)
  local ts, tn = self:slice(t, 1)
  local other_m, other_t = {}, {}
  for o = 0, #self.teams - 1 do
    if o ~= t then
      local a, b = self:slice(o, 0)
      for i = a, a + b - 1 do other_m[i] = true end
      a, b = self:slice(o, 1)
      for i = a, a + b - 1 do other_t[i] = true end
    end
  end
  local drop_m, drop_t = {}, {}
  for i = ms, ms + mn - 1 do if not other_m[i] then drop_m[i] = true end end
  for i = ts, ts + tn - 1 do if not other_t[i] then drop_t[i] = true end end
  table.remove(self.teams, t + 1)
  local function keep_map(len, drop)
    local m, k = {}, 0
    for i = 0, len do
      m[i] = k
      if i < len and not drop[i] then k = k + 1 end
    end
    return m
  end
  local km = keep_map(#self.members, drop_m)
  local kt = keep_map(#self.tactics, drop_t)
  for o = 0, #self.teams - 1 do
    local a, b = self:slice(o, 0)
    if b > 0 then self.teams[o + 1].refs[1] = { km[a], b } end
    a, b = self:slice(o, 1)
    if b > 0 then self.teams[o + 1].refs[2] = { kt[a], b } end
  end
  local mem = {}
  for i = 0, #self.members - 1 do
    if not drop_m[i] then mem[#mem + 1] = self.members[i + 1] end
  end
  self.members = mem
  local tac = {}
  for i = 0, #self.tactics - 1 do
    if not drop_t[i] then tac[#tac + 1] = self.tactics[i + 1] end
  end
  self.tactics = tac
  self.changed = true
  self:reindex()
end

-- Member rows are 16-bit (slice start + member index), read signed by the game (32768 rows); content/game/member_rows.toml makes readers unsigned (65535).
-- The build cannot tell whether those patches applied, so it keeps the menus' previewed teams within the signed reach (`front_members`) and warns when the table outgrows the unsigned reach.
TC.MENU_MEMBER_ROWS = 32768
TC.MEMBER_ROWS_MAX = 65535

-- Reorder member rows so the menu readers reach every team of `first` (set of team ids): their slices first, then the rest in old order; slices are re-pointed.
-- Returns `late, front` (teams of `first` out of reach, rows of the first group), nil when nothing moves.
function TC:front_members(first)
  local len = #self.members
  local wanted = {}
  for t = 0, #self.teams - 1 do
    local _, n = self:slice(t, 0)
    if first[self:id_of(t)] and n > 0 then wanted[#wanted + 1] = t end
  end
  local late = 0
  for _, t in ipairs(wanted) do
    local s, n = self:slice(t, 0)
    if s + n > TC.MENU_MEMBER_ROWS then late = late + 1 end
  end
  if late == 0 then return nil end
  local tier = {}
  for i = 0, len - 1 do tier[i] = i < self.base_members and 1 or 2 end
  for _, t in ipairs(wanted) do
    local s, e = self:member_range(t)
    for i = s, e - 1 do tier[i] = 0 end
  end
  -- a slice keeps its rows together: all take the lowest group any of them has
  local ranges = {}
  for t = 0, #self.teams - 1 do
    local s, e = self:member_range(t)
    if e > s then ranges[#ranges + 1] = { s, e } end
  end
  while true do
    local moved = false
    for _, r in ipairs(ranges) do
      local lo = 2
      for i = r[1], r[2] - 1 do if tier[i] < lo then lo = tier[i] end end
      for i = r[1], r[2] - 1 do
        if tier[i] ~= lo then tier[i] = lo; moved = true end
      end
    end
    if not moved then break end
  end
  local order = {}
  for i = 0, len - 1 do order[#order + 1] = i end
  T.sort(order, function(a, b) return tier[a] < tier[b] end)
  local new_pos = {}
  for k, i in ipairs(order) do new_pos[i] = k - 1 end
  new_pos[len] = len
  local front = 0
  for i = 0, len - 1 do if tier[i] == 0 then front = front + 1 end end
  local old = self.members
  local mem = {}
  for k, i in ipairs(order) do mem[k] = old[i + 1] end
  self.members = mem
  for t = 0, #self.teams - 1 do
    local s, n = self:slice(t, 0)
    if n > 0 and s < len then self.teams[t + 1].refs[1] = { new_pos[s], n } end
  end
  self.changed = true
  self:reindex()
  return late, front
end

-- Write the table (VRFW.team.tc_write serializes and serves it).
function TC:write()
  return VRFW.team.tc_write({ skill_cfg = self.skill_cfg, members = self.members, tactics = self.tactics, teams = self.teams })
end

return TC
