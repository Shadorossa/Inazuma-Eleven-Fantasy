-- Unlock conditions (shop row, loot entry, key-item ownership) from readable `[[unlock]]` clauses, encoded by VRFW.cond.
local U = require "lib/util"
local C = {}

-- The framework-owned byte flag of a condition that is never true (nothing writes it).
C.HIDE_FLAG = "VRFW_ROW_HIDDEN"
C.HIDE_VALUE = 210
C.NAMES = { "GetChronicleClearStatusFlag", "GetSoccerGameClearFlag", "GetPhase", "GetGlobalBitFlag", "GetGlobalByteFlag",
  "GetGlobalItemGetBitFlag" }

local never
-- `GetGlobalByteFlag(VRFW_ROW_HIDDEN) == 210`: the hidden row's condition.
function C.never()
  if not never then
    never = VRFW.cond.join({ VRFW.cond.group("GetGlobalByteFlag", { { VRFW.crc32(C.HIDE_FLAG), true } }, C.HIDE_VALUE, VRFW.cond.EQ) }, "all")
  end
  return never
end

-- A readable form of a condition made of the clauses' groups (nil when it is not one).
function C.describe(b64)
  return VRFW.cond.describe(b64, C.NAMES)
end

-- Whether a row's condition is the framework's hide.
function C.is_hidden(s)
  if type(s) ~= "string" then return false end
  local d = C.describe(s)
  if not d then return false end
  local tail = "== " .. C.HIDE_VALUE
  return d:find("GetGlobalByteFlag", 1, true) ~= nil and d:sub(-#tail) == tail
end

-- The comparison group of one clause; `item(ref)` resolves an item reference (returns id or nil, err).
function C.encode(u, item)
  local kinds = 0
  for _, k in ipairs { "chronicle", "game", "phase", "flag", "byte_flag", "item_got" } do
    if u[k] ~= nil then kinds = kinds + 1 end
  end
  if kinds == 0 then return nil, "an unlock clause needs one of chronicle, game, phase, flag, byte_flag, item_got" end
  if kinds > 1 then
    return nil, "an unlock clause has one kind only (chronicle, game, phase, flag, byte_flag or item_got): write several clauses"
  end
  local d = u.difficulty or 1
  if u.difficulty ~= nil and u.chronicle == nil and u.game == nil then
    return nil, "`difficulty` goes with `chronicle` or `game`"
  end
  local v = u.value or 1
  local EQ, GE = VRFW.cond.EQ, VRFW.cond.GE
  if u.chronicle ~= nil then
    return VRFW.cond.group("GetChronicleClearStatusFlag", { { U.id(u.chronicle), true }, { d, false } }, 1, EQ)
  elseif u.game ~= nil then
    return VRFW.cond.group("GetSoccerGameClearFlag", { { U.id(u.game), true }, { d, false } }, 1, EQ)
  elseif u.phase ~= nil then
    return VRFW.cond.group("GetPhase", {}, u.phase, GE)
  elseif u.flag ~= nil then
    return VRFW.cond.group("GetGlobalBitFlag", { { U.id(u.flag), true } }, v, EQ)
  elseif u.byte_flag ~= nil then
    return VRFW.cond.group("GetGlobalByteFlag", { { U.id(u.byte_flag), true } }, v, EQ)
  end
  local id, e = item(u.item_got or "")
  if not id then return nil, e end
  return VRFW.cond.group("GetGlobalItemGetBitFlag", { { id, true } }, 1, EQ)
end

-- The base64 condition of `clauses` joined with `logic` ("all" / "any"), or the raw one (`raw`, checked).
-- Returns the condition, `false` when there is none, or nil, err.
function C.build(clauses, logic, raw, item)
  clauses = clauses or {}
  if raw ~= nil then
    if #clauses > 0 then return nil, "write either `condition` (raw) or `unlock` clauses, not both" end
    local r = U.trim(raw)
    if not VRFW.cond.decodes(r) then return nil, "condition: not base64" end
    if not VRFW.cond.is_condition(raw) then return nil, "condition: not a game condition (00 | u32 length | nodes | tokens)" end
    return r
  end
  local groups = {}
  for k, c in ipairs(clauses) do
    local g, e = C.encode(c, item)
    if not g then return nil, "unlock[" .. (k - 1) .. "]: " .. e end
    groups[#groups + 1] = g
  end
  local s, e = VRFW.cond.join(groups, logic or "all")
  if e then return nil, e end
  return s or false
end

return C
