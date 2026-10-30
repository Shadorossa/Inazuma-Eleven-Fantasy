-- Character Reforged › what each slot of the new skill set accepts (owner 2026-10-14; docs/refactor/aura-mods-split.md
-- «Skill table»). The skill table (graft ss2_menus: 6 move rows + the aura slot + the mix slot, behind the option row
-- character_reforged.skill_set_view) asks CMND_CHARACTERREFORGED_CAN_PLACE (content\game\skill_set.toml) for every
-- row its pickers list and before every equip.
--
-- Slots: 1..6 the move rows, 7 the aura slot, 8 the mix slot. The base rules are data (content\skill_set\*.toml
-- [CharacterReforged.SkillSet]: the move rows refuse auras, the aura slot takes aura_types, the mix slot mix_types).
-- A move no player can obtain ([[VRFW.Unobtainable]], lib/unobtainable_moves.lua) is refused in every slot (reason
-- "unobtainable").
-- Other mods veto on top of them (e.g. a «no duplicate move» or «levels by use» plugin):
--
--   CharacterReforged.AddPlaceRule(name, fn)   fn(hdl, slot, move) -> false [, reason] refuses; anything else allows.
--                                             The same name again replaces the rule. Runs only after the base rules
--                                             allowed the move, in name order.
--   CharacterReforged.RemovePlaceRule(name)
--   CharacterReforged.CanPlace(hdl, slot, move) -> ok, reason ("type" = a base rule, else the refusing rule's name)
--   CharacterReforged.SkillSetRules()          -> the merged data rules
--
-- A rule that errors is logged once and treated as allowing (a broken plugin never blocks the screen).

CharacterReforged = CharacterReforged or {}
local CR = CharacterReforged
local Unobtainable = require "lib/unobtainable_moves"

local BUILTIN = { moves_refuse_auras = true, aura_types = { 0, 3 }, mix_types = { 2, 6 } }
local RULES = nil
local PLACE = {}        -- name -> fn
local FAILED = {}       -- name -> true once its error was logged

require "VRFW/lib/basics"
local info = VRFW.logger("skill set")

local function set_of(list)
  local s = {}
  for _, v in ipairs(type(list) == "table" and list or {}) do
    s[tonumber(v) or -1] = true
  end
  return s
end

function CR.SkillSetRules()
  if RULES then return RULES end
  local r = {}
  for k, v in pairs(BUILTIN) do r[k] = v end
  local ok, decl = pcall(VRFW.files.declarations, "content/skill_set")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local t = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.SkillSet or nil
    if type(t) == "table" then
      for k, v in pairs(t) do r[k] = v end
    end
  end
  r.aura_set, r.mix_set = set_of(r.aura_types), set_of(r.mix_types)
  RULES = r
  return r
end

function CR.AddPlaceRule(name, fn)
  if type(name) ~= "string" or name == "" or type(fn) ~= "function" then
    VRFW.warn("skill set: AddPlaceRule needs a name and a function")
    return false
  end
  PLACE[name] = fn
  FAILED[name] = nil
  info("place rule", name, "registered")
  return true
end

function CR.RemovePlaceRule(name)
  PLACE[name] = nil
end

-- the base rules: the move's aura type against the slot
local function base_ok(slot, move)
  local r = CR.SkillSetRules()
  local okT, t = pcall(VRFW.extra_slot.aura_type, move)
  if not okT then t = nil end
  if slot >= 1 and slot <= 6 then
    return not (r.moves_refuse_auras and t ~= nil)
  elseif slot == 7 then
    return t ~= nil and r.aura_set[t] == true
  elseif slot == 8 then
    return t ~= nil and r.mix_set[t] == true
  end
  return false
end

function CR.CanPlace(hdl, slot, move)
  slot, move = tonumber(slot) or 0, tonumber(move) or 0
  if move == 0 then
    return true, ""                               -- emptying a slot is always allowed
  end
  if Unobtainable.has(move) then
    return false, "unobtainable"
  end
  if not base_ok(slot, move) then
    return false, "type"
  end
  local names = {}
  for n in pairs(PLACE) do names[#names + 1] = n end
  table.sort(names)
  for _, n in ipairs(names) do
    local ok, res, why = pcall(PLACE[n], hdl, slot, move)
    if not ok then
      if not FAILED[n] then
        FAILED[n] = true
        VRFW.warn("skill set: place rule " .. n .. " failed (allowed): " .. tostring(res))
      end
    elseif res == false then
      return false, (type(why) == "string" and why ~= "") and why or n
    end
  end
  return true, ""
end

-- ---------------------------------------------------------------------------------------------- place rules as data

-- Another mod's rule can not be passed to AddPlaceRule (an export's function argument arrives as nil: each mod's
-- scripts run in their own VM). A mod declares it as DATA instead, in its content\skill_set\*.toml:
--
--   [CharacterReforged.PlaceRules.<name>]
--   command = "CMND_<MOD>_CAN_PLACE"   # a game Lua command (charaHdl, slot, move) -> ok[, …]; false refuses
--   slot = "board"                     # the slot argument: "board" = the game's board slot (rows 1-6 -> 0-5, the aura
--                                      # slot -> 8; the mix slot has none: not asked), "set" = this screen's 1..8
--   off = true                         # (a later mod) switches a rule off
--
-- The skill table asks them after CMND_CHARACTERREFORGED_CAN_PLACE allowed (the picker greys, the equip refuses):
-- CMND_CHARACTERREFORGED_PLACE_RULES() -> n, then n x (command id, slot kind 0 set / 1 board), name order.
local PRULES = nil
function CharacterReforged.PlaceRuleList()
  if PRULES then return PRULES end
  local m = {}
  local ok, decl = pcall(VRFW.files.declarations, "content/skill_set")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local t = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.PlaceRules or nil
    for name, r in pairs(type(t) == "table" and t or {}) do
      if type(r) == "table" then
        m[name] = m[name] or {}
        for k, v in pairs(r) do m[name][k] = v end
      end
    end
  end
  local out, names = {}, {}
  for name in pairs(m) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local r = m[name]
    if r.off ~= true and type(r.command) == "string" and r.command:match("^CMND_[A-Z0-9_]+$") then
      local id = tonumber(VRFW.ui.crc32(r.command)) or 0
      if id < 0 then id = id + 4294967296 end
      out[#out + 1] = { name = name, id = id, board = r.slot ~= "set" }
      info(string.format("place rule %s: command %s (slot argument %s)", name, r.command, r.slot ~= "set" and "board" or "set"))
    elseif r.off ~= true then
      VRFW.warn("skill set: place rule " .. tostring(name) .. ": command = \"CMND_…\" needed: left out")
    end
  end
  PRULES = out
  return out
end

function CharacterReforged.PlaceRulesCmd()
  local l = CR.PlaceRuleList()
  local r = { #l }
  for _, x in ipairs(l) do
    r[#r + 1] = x.id
    r[#r + 1] = x.board and 1 or 0
  end
  return table.unpack(r)
end

VRFW.on("game_reset", function() RULES, PRULES = nil, nil end)
-- the save's loading screen: the merged rules and the unobtainable set (every mod's content/techniques read once)
-- built before the skill table's first CMND_CHARACTERREFORGED_CAN_PLACE, never inside a menu command
VRFW.on("slot_load", function()
  pcall(CR.SkillSetRules)
  pcall(CR.PlaceRuleList)
  pcall(Unobtainable.set)
  return nil
end)

-- CMND_CHARACTERREFORGED_CAN_PLACE(charaHdl, slot, move) -> ok, reason
function CharacterReforged.CanPlaceCmd(hdl, slot, move)
  local ok, res, why = pcall(CR.CanPlace, hdl, slot, move)
  if not ok then
    VRFW.warn("skill set: CanPlace failed (allowed): " .. tostring(res))
    return true, ""
  end
  return res, why or ""
end
