-- Souls Rework › the aura commands the game serves (aura_skill_config: the game's rows and every mod's), read once:
-- key, auraType, own move, element. Derived from the served table, no built-in list (script VMs do not share libraries).
--   local A = require "lib/auras"
--   A.load(); A.key(id); A.id(key); A.type(id) (3 = totem; nil = not an aura); A.move(id) (its own move);
--   A.element(id) (1 wind, 2 forest, 3 fire, 4 mountain, 5 void; 0 = unknown)

local M = {}

local CONFIG = "data/common/gamedata/skill/aura_skill_config_*.cfg.bin"

local rows = {}     -- id -> { key, type, move, element }
local by_key = {}   -- key -> id
local loaded = false

local function u32(v)
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return v
end

function M.load()
  if loaded then return true end
  loaded = true
  -- columns: 0 id, 1 key, 6 own move («change skill»), 8 element, 10 auraType
  local ok, list = pcall(VRFW.table.raw, CONFIG, "AURA_CMD_INFO", { 1, 2, 7, 9, 11 })
  if not ok or type(list) ~= "table" then
    VRFW.warn("souls_rework auras: no aura_skill_config: " .. tostring(list))
    return false
  end
  for _, r in ipairs(list) do
    if type(r[1]) == "number" then
      local id = u32(r[1])
      local key = tostring(r[2] or "")
      rows[id] = { key = key, type = tonumber(r[5]) or 255, move = u32(r[3]), element = tonumber(r[4]) or 0 }
      if key ~= "" then by_key[key] = id end
    end
  end
  return true
end

function M.type(id)
  local r = rows[id or 0]
  return r and r.type or nil
end

function M.key(id)
  local r = rows[id or 0]
  if r and r.key ~= "" then return r.key end
  return string.format("0x%08X", id or 0)
end

-- an aura key of the table, else a mod aura <mod>.<name> through the framework's names
function M.id(key)
  if by_key[key] then return by_key[key] end
  local ok, id = pcall(VRFW.technique, key)
  if ok and type(id) == "number" and rows[u32(id)] then return u32(id) end
  return nil
end

function M.move(id)
  local r = rows[id or 0]
  return r and r.move or 0
end

function M.element(id)
  local r = rows[id or 0]
  return r and r.element or 0
end

return M
