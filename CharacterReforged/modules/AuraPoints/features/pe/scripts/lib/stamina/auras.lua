-- Aura Points › PE: the aura commands the game loads (the served aura_skill_config: the game's rows and every mod's),
-- read once: type, key, own move, aura character; the keshin of an armour. Derived from the game's table, no built-in
-- list. (A copy of Inazuma Fantasy's scripts\lib\stamina\auras.lua of 2026-10-14: script VMs do not share libraries,
-- docs/refactor/aura-mods-split.md.) The miximax carrier rows of other mods (their row's auraType may say otherwise)
-- come from [pe] miximax_carriers of config.toml (M.set_carriers).
--
--   local A = require "lib/stamina/auras"
--   A.load(); A.type(id) -> 0 keshin, 1 armour, 2 miximax, 3 totem, … (nil = not an aura); A.key(id); A.spirit(id)

local M = {}

local KEY = "data/common/gamedata/skill/aura_skill_config_*.cfg.bin"
-- the miximax carrier rows named by config (keys or ids), set before load()
M.MIXIMAX_CARRIERS = {}

function M.set_carriers(list)
  M.MIXIMAX_CARRIERS = type(list) == "table" and list or {}
end

local rows = {}        -- id -> { key, type, move, chara, cost }
local spirit_of = {}   -- armour id -> its keshin id (same aura character, the first keshin in table order)
local spirit_moves = {}
local armours = {}     -- keshin id -> { armour ids } (the reverse of spirit_of)
local carriers = {}
local loaded = false
local ids = {}         -- aura ids in table order

local Id = require "VRFW/lib/ids"
local u32 = Id.u32

function M.load()
  if loaded then return true end
  loaded = true
  for _, k in ipairs(M.MIXIMAX_CARRIERS) do
    if type(k) == "number" then carriers[u32(k)] = true else carriers[u32(VRFW.ui.crc32(tostring(k)))] = true end
  end
  -- col 0 id, 1 key, 4 cost, 6 own move («change skill»), 7 aura character, 10 auraType
  local ok, list = pcall(VRFW.table.raw, KEY, "AURA_CMD_INFO", { 1, 2, 5, 7, 8, 11 })
  if not ok or type(list) ~= "table" then
    VRFW.warn("aura_points stamina auras: no aura_skill_config: " .. tostring(list))
    return false
  end
  local order, first_keshin = {}, {}
  for _, r in ipairs(list) do
    if type(r[1]) == "number" then
      local id = u32(r[1])
      local row = { key = tostring(r[2] or ""), type = tonumber(r[11]) or 255, move = u32(r[7]), chara = u32(r[8]), cost = tonumber(r[5]) or 0 }
      rows[id] = row
      order[#order + 1] = id
      ids[#ids + 1] = id
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

function M.row(id) return rows[id] end

-- every aura id of the table, in table order
function M.ids() return ids end

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

function M.is_miximax(id)
  return id ~= nil and id ~= 0 and (M.type(id) == 2 or carriers[id] == true)
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

-- Fill the mod's record table the answers read (features\pe\content\game\stamina.toml): AuraPoints.StaminaAura (aura id ->
-- { aura = 1, type, miximax, waived (starts at any gauge), free (starts without the gauge) }).
function M.publish(cfg)
  local auras = {}
  local function rec(id, r)
    local x = { aura = 1, type = r and r.type or 2 }
    if M.is_miximax(id) then x.miximax = 1 end
    local ty = x.miximax and 2 or x.type
    if cfg.free_activation(ty) then x.free = 1 end
    if cfg.start_check_waived(ty) then x.waived = 1 end
    auras[#auras + 1] = { id, x }
  end
  for id, r in pairs(rows) do rec(id, r) end
  for c in pairs(carriers) do
    if not rows[c] then rec(c, nil) end
  end
  pcall(VRFW.native.table_replace, "AuraPoints.StaminaAura", nil, auras)
  return #auras
end

return M
