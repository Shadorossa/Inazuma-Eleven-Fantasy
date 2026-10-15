-- Aura Points › the aura commands the game loads (the served aura_skill_config: the game's rows and every mod's), read
-- once: type, key, own move, aura character; the keshin an armour pays from; the spirit moves (the own move of a
-- keshin / armour / totem / mode-change aura, not a miximax's). Derived from the game's table, no built-in list.
-- (A copy of Inazuma Fantasy's scripts\lib\stamina\auras.lua of 2026-10-14 without its miximax carriers: script VMs
-- do not share libraries, docs/refactor/aura-mods-split.md.)
--
--   local A = require "lib/auras"
--   A.load(); A.type(id) -> 0 keshin, 1 armour, 2 miximax, 3 totem, … (nil = not an aura); A.key(id); A.spirit(id)
--   A.is_spirit_move(id); A.aura_move(id); A.armours_of(keshin)

local M = {}

local KEY = "data/common/gamedata/skill/aura_skill_config_*.cfg.bin"

local rows = {}        -- id -> { key, type, move, chara, cost }
local spirit_of = {}   -- armour id -> its keshin id (same aura character, the first keshin in table order)
local spirit_moves = {}
local armours = {}     -- keshin id -> { armour ids } (the reverse of spirit_of)
local loaded = false

local function u32(v)
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return v
end

function M.load()
  if loaded then return true end
  loaded = true
  -- col 0 id, 1 key, 4 cost, 6 own move («change skill»), 7 aura character, 10 auraType
  local ok, list = pcall(VRFW.table.raw, KEY, "AURA_CMD_INFO", { 1, 2, 5, 7, 8, 11 })
  if not ok or type(list) ~= "table" then
    VRFW.warn("aura_points auras: no aura_skill_config: " .. tostring(list))
    return false
  end
  local order, first_keshin = {}, {}
  for _, r in ipairs(list) do
    if type(r[1]) == "number" then
      local id = u32(r[1])
      local row = { key = tostring(r[2] or ""), type = tonumber(r[11]) or 255, move = u32(r[7]), chara = u32(r[8]), cost = tonumber(r[5]) or 0 }
      rows[id] = row
      order[#order + 1] = id
      if row.type == 0 and row.chara ~= 0 and not first_keshin[row.chara] then first_keshin[row.chara] = id end
    end
  end
  local mixi = {}
  for _, id in ipairs(order) do
    local r = rows[id]
    if r.type == 1 and r.chara ~= 0 then
      spirit_of[id] = first_keshin[r.chara]
      if spirit_of[id] then
        armours[spirit_of[id]] = armours[spirit_of[id]] or {}
        table.insert(armours[spirit_of[id]], id)
      end
    end
    if r.type == 2 and r.move ~= 0 then mixi[r.move] = true end
  end
  for _, id in ipairs(order) do
    local r = rows[id]
    if r.type ~= 2 and r.move ~= 0 and not mixi[r.move] then spirit_moves[r.move] = true end
  end
  return true
end

-- auraType (nil = not an aura command)
function M.type(id)
  local r = rows[id or 0]
  return r and r.type or nil
end

function M.key(id)
  local r = rows[id or 0]
  if r and r.key ~= "" then return r.key end
  return string.format("0x%08X", id or 0)
end

-- The keshin of an armour (the framework's transform pairs first, else the same aura character).
function M.spirit(armour)
  if VRFW.form and VRFW.form.spirit_of then
    local ok, s = pcall(VRFW.form.spirit_of, armour)
    if ok and type(s) == "number" and s ~= 0 then return s end
  end
  return spirit_of[armour]
end

-- The armour forms of a keshin (the aura character pairing).
function M.armours_of(spirit)
  return armours[spirit] or {}
end

function M.is_spirit_move(id)
  return id ~= nil and id ~= 0 and spirit_moves[id] == true
end

-- The move of an aura: its own change skill, else (armour forms) its keshin's.
function M.aura_move(id)
  local r = rows[id or 0]
  if not r then return 0 end
  if r.move ~= 0 then return r.move end
  local k = M.spirit(id)
  return (k and rows[k] and rows[k].move) or 0
end

-- Fill AuraPoints.Aura (aura id -> { type, pool = 1 when it runs on a pool }) for the native answers
-- (content\game\aura_points.toml) and the other mods that read it. `is_pool(id)`: the aura runs on a pool now.
function M.publish(is_pool)
  local auras, n_pool = {}, 0
  for id, r in pairs(rows) do
    if is_pool(id) then
      auras[#auras + 1] = { id, { type = r.type, pool = 1 } }
      n_pool = n_pool + 1
    end
  end
  local n_moves = 0
  for _ in pairs(spirit_moves) do n_moves = n_moves + 1 end
  pcall(VRFW.native.table_replace, "AuraPoints.Aura", nil, auras)
  return n_pool, n_moves
end

return M
