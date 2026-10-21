-- Special Players › own passives («Pasiva propia»): one passive per player in the custom passive slot (board equip
-- slot 9): the GamePassive block of his special passives (content\special_passives\, scripts\lib\special_passives.lua),
-- or an older content\own_passives\*.toml declaration (schema SpecialPlayers.own_passives/1) of any active mod. The
-- engine entries are content\game\own_passives.toml. This script fills their native tables:
--
--   SpecialPlayers.OwnPassive  (chara_param id) -> passive id   the slot reader answers it (no entry = empty slot)
--   SpecialPlayers.AlwaysOpen  (chara_param id) -> 1            the piece gate answers it (unlock = "always")
--
--   CMND_SPECIALPLAYERS_OWN_PASSIVE(charaStHdl) -> passive id (0 = none), always open, declaring mod
--        the skill boards' Lua (graft special_players_board) asks it to draw the slot and its detail window.
--
-- Nothing calls the game at load: the tables are built from files (the declarations and the character index).

SpecialPlayers = SpecialPlayers or {}
SpecialPlayers.Cmd = SpecialPlayers.Cmd or {}
local SP = SpecialPlayers

local function info(...) VRFW.log("own_passives:", ...) end
local function warn(...) VRFW.warn("own_passives:", ...) end

local L = require "lib/special_passives"

local T_OWN, T_OPEN = "SpecialPlayers.OwnPassive", "SpecialPlayers.AlwaysOpen"

local BY_CARD = nil          -- [chara_param id] = { passive = id, always = bool, mod = id }
local BUILD_ERROR = nil
local u32 = L.u32

local function build()
  -- the block and passive files' problems are logged once, by scripts\passive_blocks.lua
  L.data(function() end)
  return L.own_slots(warn, info)
end

local function fill()
  local ok, map, n_entries = pcall(build)
  if not ok or map == nil then
    BUILD_ERROR = tostring(ok and n_entries or map)
    return false
  end
  local own, open = {}, {}
  for card, e in pairs(map) do
    own[#own + 1] = { card, e.passive }
    if e.always then open[#open + 1] = { card, 1 } end
  end
  VRFW.native.table_replace(T_OWN, nil, own)
  VRFW.native.table_replace(T_OPEN, nil, open)
  BY_CARD, BUILD_ERROR = map, nil
  info(string.format("%d declaration(s), %d card(s) with an own passive, %d always open", n_entries, #own, #open))
  return true
end

local function ready()
  if BY_CARD == nil then fill() end
  return BY_CARD ~= nil
end

-- ---------------------------------------------------------------------------------------------- for other scripts

-- the own passive of a card: passive id (0 = none), always open, declaring mod
function SP.OwnPassiveOfCard(card)
  if not ready() then return 0, false, nil end
  local e = BY_CARD[u32(card)]
  if e == nil then return 0, false, nil end
  return e.passive, e.always, e.mod
end

-- ---------------------------------------------------------------------------------------------- commands

-- the custom passive slot as its two readers answer it (every subscriber's answer): passive id, open, ""
local BUF_ID, BUF_HDL = nil, nil
local function live_signature(hdl)
  if not BUF_ID then
    BUF_ID = VRFW.mem.buffer("special_players_own_live_id", 8)
    BUF_HDL = VRFW.mem.buffer("special_players_own_live_hdl", 4)
  end
  VRFW.mem.write("u32", BUF_ID, 0)
  if not pcall(VRFW.call, "SpecialPlayers.SignatureSlotIdLive", BUF_ID, hdl) then return 0, false, "" end
  local id = VRFW.mem.read("u32", BUF_ID) or 0
  VRFW.mem.write("u32", BUF_HDL, hdl)
  local ok, open = pcall(VRFW.call, "SpecialPlayers.SignaturePieceOpenLive", BUF_HDL)
  return id, ok and tonumber(open) ~= nil and tonumber(open) % 256 ~= 0, ""
end

function SP.Cmd.OwnPassive(hdl)
  hdl = u32(hdl)
  if hdl == 0 then return 0, false, "" end
  -- a mode without player passives (Utilities.passives_off): the boards show the slot empty
  local okoff, off = pcall(VRFW.state.get, "Utilities.passives_off")
  if okoff and tonumber(off) == 1 then return 0, false, "" end
  -- a framework signature-only mode (vrfw.passive.slots_off): the slot shows what its readers answer
  local okmode, mode = pcall(VRFW.state.get, "vrfw.passive.slots_off")
  if okmode and tonumber(mode) == 1 then return live_signature(hdl) end
  local ok, r = pcall(VRFW.chara.record, hdl)
  if not ok or type(r) ~= "table" or type(r.param) ~= "number" then return 0, false, "" end
  local passive, always, mod = SP.OwnPassiveOfCard(r.param)
  return passive, always, mod or ""
end

-- ---------------------------------------------------------------------------------------------- start

if not fill() then
  info("tables not built at load (" .. tostring(BUILD_ERROR) .. "); built on first use")
end
VRFW.on("slot_load", function()
  if BY_CARD == nil then fill() end
end)
