-- Passive slot modes: every active mod's content/passive_slots/*.toml (`VRFW.passive_slots/1`). A [[VRFW.SignatureOnly]]
-- names a game_state key; while it is 1 every player keeps only his signature passive (custom passive slot, board equip
-- slot 9). The effect is native (content/game/archetype.toml, tables Passive.SlotsOff / Signature* the mods export);
-- this script gives the menus and the other scripts the same picture (content/game/passive_slots.toml):
--   state key vrfw.passive.slots_off              1 while a declared mode runs (set on slot / mode / match events)
--   CMND_GET_CHARA_TEAM_PASSIVE_INFO (filter)     the plate's 5 passive rows read empty
--   CMND_VRFW_PASSIVE_SLOTS_OFF                   () -> true while a declared mode runs
--   CMND_VRFW_SIGNATURE_PASSIVE                   (hdl) -> passive id, open, mode on: what the slot 9 readers answer

PassiveSlots = PassiveSlots or {}

local D = require "lib/declarations"

local function info(...) VRFW.log("passive_slots:", ...) end
local function warn(...) VRFW.warn("passive_slots:", ...) end

local KEY_OFF = "vrfw.passive.slots_off"
local N_SLOTS = 5
local LIST_HANDLE_BASE, LIST_HANDLE_MASK = 0xE000, 0xFFFFF000

local MODES = {}       -- { key, state }
local PUBLISHED = nil  -- the value last written to KEY_OFF
local BUF_ID, BUF_HDL

local function u32(v)
  v = tonumber(v)
  if not v or v ~= v then return nil end
  return math.floor(v) % 4294967296
end

local function load()
  local schema, why = D.schema("passive_slot_mode")
  if not schema then
    warn(tostring(why))
    return
  end
  for _, d in ipairs(D.load(schema, warn)) do
    if d.entry == "SignatureOnly" and type(d.v.state) == "string" and d.v.state ~= "" then
      MODES[#MODES + 1] = { key = d.key, state = d.v.state }
    end
  end
  if #MODES > 0 then
    local names = {}
    for _, m in ipairs(MODES) do names[#names + 1] = m.key .. " (" .. m.state .. ")" end
    info("signature-only modes: " .. table.concat(names, ", "))
  end
end

-- the declared mode running now, or nil
local function running()
  for _, m in ipairs(MODES) do
    local ok, v = pcall(VRFW.state.get, m.state)
    if ok and tonumber(v) == 1 then return m end
  end
  return nil
end

local function publish(why)
  local m = running()
  local v = m and 1 or 0
  if v == PUBLISHED then return end
  local ok, e = pcall(VRFW.state.set, KEY_OFF, v)
  if not ok then
    warn(KEY_OFF .. ": " .. tostring(e))
    return
  end
  PUBLISHED = v
  info(string.format("%s = %d (%s%s)", KEY_OFF, v, why, m and (", " .. m.key) or ""))
end

-- ---------------------------------------------------------------------------------------------- filters and commands

-- CMND_GET_CHARA_TEAM_PASSIVE_INFO(hdl, slot, field, useCopy, preview): a real player's 5 rows read empty
function PassiveSlots.PlateInfo(h, slot, field)
  h, slot, field = u32(h), u32(slot), u32(field)
  if not (h and slot and field) or field > 2 or slot >= N_SLOTS then return false end
  if bit32.band(h, LIST_HANDLE_MASK) == LIST_HANDLE_BASE then return false end
  if running() == nil then return false end
  if field == 2 then return true, true, false end
  return true, true, 0
end

function PassiveSlots.CmdOff()
  return running() ~= nil
end

-- the answer of the slot 9 readers for a character handle: passive id, open
local function signature_of(hdl)
  if not BUF_ID then
    BUF_ID = VRFW.mem.buffer("passive_slots_id", 8)
    BUF_HDL = VRFW.mem.buffer("passive_slots_hdl", 4)
  end
  VRFW.mem.write("u32", BUF_ID, 0)
  if not pcall(VRFW.call, "VRFW.SignatureSlotIdLive", BUF_ID, hdl) then return 0, false end
  local id = VRFW.mem.read("u32", BUF_ID) or 0
  VRFW.mem.write("u32", BUF_HDL, hdl)
  local ok, open = pcall(VRFW.call, "VRFW.SignaturePieceOpenLive", BUF_HDL)
  return id, ok and tonumber(open) ~= nil and tonumber(open) % 256 ~= 0
end

function PassiveSlots.CmdSignature(hdl)
  hdl = u32(hdl)
  local on = running() ~= nil
  if not hdl or hdl == 0 then return 0, false, on end
  local id, open = signature_of(hdl)
  return id, open, on
end

-- ---------------------------------------------------------------------------------------------- start

do
  local ok, e = pcall(load)
  if not ok then warn("declarations: " .. tostring(e)) end
end
if #MODES > 0 then
  publish("start")
  for _, ev in ipairs({ "slot_load", "game_reset", "mode_enter", "mode_leave", "match_start" }) do
    VRFW.on(ev, function() publish(ev) end)
  end
end
