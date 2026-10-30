-- Character Reforged › the moves no player character can obtain: the [[VRFW.Unobtainable]] rules of every active mod's
-- content\techniques\ (this mod: content\techniques\unobtainable_auras.toml), resolved the way the technique type
-- resolves them at build time (docs/framework/types/technique.md): every aura command of the rule's AuraTypes in the
-- aura_skill_config the game loads, plus its Techniques (game keys or ids). The build already took them out of every
-- learn list and the shops; the skill table refuses them (scripts\skill_set.lua) and the save adjust takes them out of
-- the saved players (scripts\save_tools.lua). No list in code.

local Unobtainable = {}

local AURA_CONFIG = "data/common/gamedata/skill/aura_skill_config_*.cfg.bin"
-- aura_skill_config columns (1-based: the 0-based column + 1): command id, aura type
local COLUMN_AURA_ID, COLUMN_AURA_TYPE = 1, 11

local SET = nil        -- [move id] = true
local COUNT = 0
local RULES = 0

local Id = require "VRFW/lib/ids"
local u32 = Id.u32

-- a move reference of a rule: a number, "0x…", a decimal string or a game key (its CRC-32)
local function move_id(ref)
  if type(ref) == "number" then return u32(ref) end
  if type(ref) ~= "string" or ref == "" then return 0 end
  local hex = ref:match("^0[xX](%x+)$")
  if hex then return u32(tonumber(hex, 16)) end
  if ref:match("^%-?%d+$") then return u32(tonumber(ref)) end
  return u32(VRFW.crc32(ref))
end

-- the [[VRFW.Unobtainable]] entries of every active mod (load order)
local function read_rules()
  local rules = {}
  local ok, declarations = pcall(VRFW.files.declarations, "content/techniques")
  for _, file in ipairs(ok and type(declarations) == "table" and declarations or {}) do
    local data = type(file) == "table" and file.data or nil
    local framework = type(data) == "table" and (data.VRFW or data.vrfw) or nil
    local list = type(framework) == "table" and framework.Unobtainable or nil
    for _, rule in ipairs(type(list) == "table" and list or {}) do
      if type(rule) == "table" then rules[#rules + 1] = rule end
    end
  end
  return rules
end

local function load()
  if SET then return SET end
  SET, COUNT = {}, 0
  local rules = read_rules()
  RULES = #rules
  if RULES == 0 then return SET end
  local types = {}
  local function add(id)
    if id ~= 0 and not SET[id] then
      SET[id] = true
      COUNT = COUNT + 1
    end
  end
  for _, rule in ipairs(rules) do
    for _, t in ipairs(type(rule.AuraTypes) == "table" and rule.AuraTypes or {}) do
      if type(t) == "number" then types[t] = true end
    end
    for _, ref in ipairs(type(rule.Techniques) == "table" and rule.Techniques or {}) do add(move_id(ref)) end
  end
  if next(types) ~= nil then
    local ok, rows = pcall(VRFW.table.raw, AURA_CONFIG, "AURA_CMD_INFO", { COLUMN_AURA_ID, COLUMN_AURA_TYPE })
    if not ok or type(rows) ~= "table" then
      VRFW.warn("unobtainable moves: aura_skill_config unreadable: " .. tostring(rows))
    else
      for _, row in ipairs(rows) do
        local aura_type = row[COLUMN_AURA_TYPE]
        if type(aura_type) == "number" and types[aura_type % 256] then add(u32(row[COLUMN_AURA_ID])) end
      end
    end
  end
  VRFW.log(string.format("unobtainable moves: %d move(s) from %d rule(s)", COUNT, RULES))
  return SET
end

-- the move can never be a player's
function Unobtainable.has(move)
  return load()[u32(tonumber(move) or 0)] == true
end

-- [move id] = true of every such move
function Unobtainable.set()
  return load()
end

-- how many moves, how many rules
function Unobtainable.count()
  load()
  return COUNT, RULES
end

return Unobtainable
