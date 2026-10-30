-- Unlimited copies, script side (game Lua side: assets\lua\menu\_all\39_unlimited_copies.lua; docs/framework/unlimited-copies.md).
-- Declarations: every active mod's content\unlimited_copies\*.toml (`VRFW.unlimited_copy/1`, keys content\types\unlimited_copy.toml).
-- A rule names item sub-categories (item_config ITEM_SPECIAL_SKILL_INFO col 6) and what makes it hold (a key item owned, a
-- Chronicle piece cleared, every Chronicle completed); the game Lua checks those conditions and, while one rule holds,
-- one owned copy of such an item serves every player: the equip keeps the owned count (CMND_VRFW_UNLIMITED_COPIES_CAP).
-- Never in a reserved save slot (a mode's own slot).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_UNLIMITED_COPIES_RULES | [item] | { rule, … }: each rule { chroniclesDifficulty, nKeys, keyItem…, nClears, statusFlagIndex, difficulty, … } |
-- | CMND_VRFW_UNLIMITED_COPIES_SLOT | | 1 normal slot, -1 reserved slot, -2 slot unknown |
-- | CMND_VRFW_UNLIMITED_COPIES_CAP | invHdl, item, num, target | status, equippedBefore, equippedAfter |
-- The cap lowers the stack's equipped count ([rec+0x14]) to `target` (the owned count before the equip) so the retail
-- CMND_DELETE_ITEM(item, num - target) can take the extra copies back (the engine's delete never goes below the equipped
-- count). It never creates copies, never goes below one copy and acts only on the stack the game Lua counted.

UnlimitedCopies = UnlimitedCopies or {}

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("unlimited_copies")

local SLOT_OK, SLOT_RESERVED, SLOT_UNKNOWN = 1, -1, -2
local CAP_OK, CAP_OFF, CAP_BAD_ARGS, CAP_MISMATCH, CAP_WRITE_FAILED = 1, -1, -2, -3, -4
local CAP_TEXT = {
  [CAP_OK] = "the extra copies can be removed: the owned count stays",
  [CAP_OFF] = "off",
  [CAP_BAD_ARGS] = "bad arguments",
  [CAP_MISMATCH] = "stack does not match the game Lua's count: left as is",
  [CAP_WRITE_FAILED] = "write failed",
}

-- inventory record (UnlimitedCopiesRecord): +4 item id, +0x10 stock, +0x14 equipped
local REC_ITEM, REC_STOCK, REC_EQUIPPED = 4, 0x10, 0x14

local RULES = nil        -- { { key, kinds = set, keys = { id … }, pieces = { id … }, difficulty, chronicles } … }
local KIND_OF = nil      -- item id -> its sub-category (only the sub-categories some rule names)
local SFI = nil          -- pieceId -> statusFlagIndex
local BY_ITEM = {}       -- item id -> the command's answer (cached)

local function int(v) return VRFW.value.int(v, 0) end

local Id = require "lib/ids"
local u32 = Id.u32

local hex = Id.hex

local function rd(ty, addr)
  local ok, v = pcall(VRFW.mem.read, ty, addr)
  if ok then return v end
  return nil
end

local function load_rules()
  if RULES ~= nil then return RULES end
  RULES = {}
  local schema, why = D.schema("unlimited_copy")
  if not schema then
    warn(why .. ": no item has unlimited copies")
    return RULES
  end
  for _, d in ipairs(D.load(schema, warn)) do
    local v, kinds = d.v, {}
    for _, k in ipairs(v.item_kinds or {}) do kinds[k] = true end
    RULES[#RULES + 1] = { key = d.key, kinds = kinds, kind_list = v.item_kinds or {}, keys = v.key_items or {},
      pieces = v.cleared_pieces or {}, difficulty = v.cleared_difficulty or 2, chronicles = v.chronicles_complete or 0 }
    info(string.format("rule %s: sub-categories %s, %d key item(s), %d piece(s) at difficulty %d, every Chronicle %s",
      d.key, table.concat(v.item_kinds or {}, "/"), #(v.key_items or {}), #(v.cleared_pieces or {}),
      v.cleared_difficulty or 2, (v.chronicles_complete or 0) > 0 and ("at difficulty " .. v.chronicles_complete) or "not needed"))
  end
  return RULES
end

-- the sub-category of every item a rule may cover (two columns of ITEM_SPECIAL_SKILL_INFO: col 1 id, col 7 sub-category)
local function kinds()
  if KIND_OF ~= nil then return KIND_OF end
  KIND_OF = {}
  local want = {}
  for _, r in ipairs(load_rules()) do
    for k in pairs(r.kinds) do want[k] = true end
  end
  if next(want) == nil then return KIND_OF end
  local ok, rows = pcall(VRFW.table.raw, "data/common/gamedata/item/item_config_*.cfg.bin", "ITEM_SPECIAL_SKILL_INFO", { 1, 7 })
  if not ok or type(rows) ~= "table" or #rows == 0 then
    ok, rows = pcall(VRFW.table.rows, "item/item_special_skill")
  end
  if not ok or type(rows) ~= "table" then
    warn("item_config is not readable (" .. tostring(rows) .. "): no item has unlimited copies")
    return KIND_OF
  end
  local n = 0
  for _, r in ipairs(rows) do
    local sub = int(tonumber(r.skill_kind or r[7]) or 0)
    if want[sub] then
      KIND_OF[u32(r.id or r[1])] = sub
      n = n + 1
    end
  end
  info(string.format("%d item(s) in the declared sub-categories", n))
  return KIND_OF
end

-- pieceId -> statusFlagIndex of the Chronicle board pieces (the clear-status command takes the latter)
local function piece_slots()
  if SFI ~= nil then return SFI end
  local ok, pieces = pcall(VRFW.table.rows, "vsroute/vs_route_piece")
  if not ok or type(pieces) ~= "table" then
    warn("the board's pieces are not readable (" .. tostring(pieces) .. "): no rule holds by a cleared piece")
    return {}
  end
  SFI = {}
  for _, p in ipairs(pieces) do
    local id, sfi = u32(p.pieceId or p[2]), int(tonumber(p.statusFlagIndex or p[4]) or 0)
    if id ~= 0 and sfi > 0 then SFI[id] = sfi end
  end
  return SFI
end

-- one rule as a flat list of numbers: { chroniclesDifficulty, nKeys, key1 … keyN, nClears, sfi1, difficulty1 … }
local function rule_answer(r)
  local out = { r.chronicles, #r.keys }
  for _, k in ipairs(r.keys) do out[#out + 1] = u32(k) end
  local clears = {}
  for _, id in ipairs(r.pieces) do
    local sfi = piece_slots()[u32(id)]
    if sfi ~= nil then
      clears[#clears + 1] = sfi
    else
      warn(string.format("rule %s: piece %s is not on the Chronicle board", tostring(r.key), hex(id)))
    end
  end
  out[#out + 1] = #clears
  for _, sfi in ipairs(clears) do
    out[#out + 1] = sfi
    out[#out + 1] = r.difficulty
  end
  return out
end

function UnlimitedCopies.Rules(item)
  local all = load_rules()
  if item == nil then
    local out = {}
    for _, r in ipairs(all) do out[#out + 1] = rule_answer(r) end
    return out
  end
  local id = u32(item)
  local got = BY_ITEM[id]
  if got ~= nil then return got end
  got = {}
  local sub = kinds()[id]
  if sub ~= nil then
    for _, r in ipairs(all) do
      if r.kinds[sub] then got[#got + 1] = rule_answer(r) end
    end
  end
  BY_ITEM[id] = got
  return got
end

function UnlimitedCopies.Slot()
  if not VRFW.slots.ready() then return SLOT_UNKNOWN end
  local ok, reserved = pcall(VRFW.slots.reserved, VRFW.slots.active())
  if not ok then return SLOT_UNKNOWN end
  if reserved then return SLOT_RESERVED end
  return SLOT_OK
end

-- the stack record of an inventory handle, or nil
local function record(inv)
  if inv == 0 then return nil end
  local okI, items = pcall(VRFW.game.UnlimitedCopiesItems)
  if not okI or not items then return nil end
  local ok, p = pcall(VRFW.call, "UnlimitedCopiesRecord", items, inv)
  if not ok or not p or p < 0x10000 then return nil end
  return p
end

-- (item id, stock, equipped) of a stack; (0, -1, -1) when unreadable
local function counts(rec)
  if not rec then return 0, -1, -1 end
  local item, stock, eq = rd("u32", rec + REC_ITEM), rd("i32", rec + REC_STOCK), rd("u32", rec + REC_EQUIPPED)
  if not item or not stock or not eq then return 0, -1, -1 end
  return item, stock, eq
end

-- the equipped count to write (nil = nothing to lower), or false + an error status
local function cap_plan(covered, item_arg, num, target, item, stock, eq)
  if not covered then return false, CAP_OFF end
  if item_arg == 0 or target < 1 or num <= target then return false, CAP_BAD_ARGS end
  if item ~= item_arg or stock ~= num or eq < 0 then return false, CAP_MISMATCH end
  if eq > target then return target end
  return nil
end

function UnlimitedCopies.Cap(inv, item_arg, num, target)
  inv, item_arg, num, target = u32(inv), u32(item_arg), int(num), int(target)
  local covered = UnlimitedCopies.Slot() == SLOT_OK and #UnlimitedCopies.Rules(item_arg) > 0
  local rec = record(inv)
  local item, stock, eq = counts(rec)
  local plan, code = cap_plan(covered, item_arg, num, target, item, stock, eq)
  local status, after = CAP_OK, eq
  if plan == false then
    status = code
  elseif plan then
    if pcall(VRFW.mem.write, "u32", rec + REC_EQUIPPED, plan) then
      local _, _, now = counts(rec)
      after = now
    else
      status = CAP_WRITE_FAILED
    end
  end
  info(string.format("item %s (stack %s: item %s, stock %d) owned %d, now %d: equipped %d -> %d, status %d (%s)",
    hex(item_arg), hex(inv), hex(item), stock, target, num, eq, after, status, CAP_TEXT[status] or "?"))
  return status, eq, after
end

pcall(load_rules)
