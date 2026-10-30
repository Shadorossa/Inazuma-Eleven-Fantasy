-- Signature Passives › own passives («Pasiva propia»): one passive per player in the custom passive slot (board equip
-- slot 9): the GamePassive block of his special passives (content\special_passives\, read by the framework's passive
-- engine library VRFW/lib/passives), or an older content\own_passives\*.toml declaration (schema
-- SignaturePassives.own_passives/1) of any active mod. The
-- engine entries are content\game\own_passives.toml. This script fills their native tables:
--
--   SignaturePassives.OwnPassive  (chara_param id) -> passive id   the slot reader answers it (no entry = empty slot)
--   SignaturePassives.AlwaysOpen  (chara_param id) -> 1            the piece gate answers it (unlock = "always")
--
--   CMND_SIGNATUREPASSIVES_OWN_PASSIVE(charaStHdl) -> passive id (0 = none), always open, declaring mod
--        the skill boards' Lua (graft signature_passives_board) asks it to draw the slot and its detail window.
--
-- Nothing calls the game at load: the tables are built from files (the declarations and the character index).

SignaturePassives = SignaturePassives or {}
SignaturePassives.Cmd = SignaturePassives.Cmd or {}
local SP = SignaturePassives

require "VRFW/lib/basics"
local info, warn = VRFW.logger("own_passives")

local L = require "VRFW/lib/passives"
local OWN_KIND = "SignaturePassives.own_passives/1"

local T_OWN, T_OPEN = "SignaturePassives.OwnPassive", "SignaturePassives.AlwaysOpen"

local BY_CARD = nil          -- [chara_param id] = { passive = id, always = bool, mod = id }
local BUILD_ERROR = nil
local u32 = L.u32

-- ---------------------------------------------------------------------------------------------- own passive slot

-- [card id] = { passive = id, always = bool, mod = id }: the GamePassive block of each character's passives, and the
-- older content\own_passives\*.toml declarations. A later entry for the same card replaces an earlier one.
local function own_slots(warn, info)
  local map, n_entries = {}, 0
  local function put(cards, passive, always, mod, where)
    if #cards == 0 then
      warn(where .. ": no card found (left out)")
      return
    end
    for _, c in ipairs(cards) do
      local before = map[c]
      if before ~= nil and before.mod ~= mod and info then
        info(string.format("card %s: the own passive of %s replaces the one of %s", L.hex(c), mod, before.mod))
      end
      map[c] = { passive = passive, always = always, mod = mod }
    end
  end
  local ok, files = pcall(VRFW.files.declarations, "content/own_passives")
  for _, f in ipairs((ok and type(files) == "table") and files or {}) do
    local doc = f.data
    local where0 = string.format("mods/%s/%s", tostring(f.mod), tostring(f.file))
    if type(doc) ~= "table" or doc.schema ~= OWN_KIND then
      warn(where0 .. ": schema is not " .. OWN_KIND .. " (file left out)")
    else
      for k, e in ipairs(type(doc.own_passive) == "table" and doc.own_passive or {}) do
        local where = string.format("%s [[own_passive]] #%d", where0, k)
        local passive = L.id_of(e.passive)
        local unlock = e.unlock == nil and "board" or e.unlock
        if unlock ~= "board" and unlock ~= "always" then
          warn(where .. ": unlock must be \"board\" or \"always\" (taken as \"board\")")
          unlock = "board"
        end
        if passive == nil or passive == 0 then
          warn(where .. ": no passive (left out)")
        elseif e.character == nil and e.card == nil then
          warn(where .. ": needs `character` or `card` (left out)")
        else
          n_entries = n_entries + 1
          put(L.cards_of({ character = e.character, card = e.card }), passive, unlock == "always", tostring(f.mod), where)
        end
      end
    end
  end
  for _, e in ipairs(L.data(warn).characters) do
    local slot = nil
    for _, p in ipairs(e.passives) do
      if p.slot then
        if slot then warn(e.where .. ": " .. p.key .. " also has a GamePassive block (his slot holds one: " .. slot.key .. ")") else slot = p.slot end
      end
    end
    if slot then
      local passive = L.id_of(slot.v.passive)
      if passive and passive ~= 0 then
        n_entries = n_entries + 1
        put(L.cards_of(e), passive, slot.v.unlock == "always", e.mod, e.where)
      end
    end
  end
  return map, n_entries
end

local function build()
  -- the block and passive files' problems are logged once, by the framework's scripts\passives.lua
  L.data(function() end)
  return own_slots(warn, info)
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

-- a failed build is tried again once on first use and at each save load, never on every call
local USE_TRIED = false
local function ready()
  if BY_CARD == nil and not USE_TRIED then
    USE_TRIED = true
    if not fill() then warn("tables not built (" .. tostring(BUILD_ERROR) .. "): the own passive slot stays empty") end
  end
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
    BUF_ID = VRFW.mem.buffer("signature_passives_own_live_id", 8)
    BUF_HDL = VRFW.mem.buffer("signature_passives_own_live_hdl", 4)
  end
  VRFW.mem.write("u32", BUF_ID, 0)
  if not pcall(VRFW.call, "Passive.SignatureSlotId", BUF_ID, hdl) then return 0, false, "" end
  local id = VRFW.mem.read("u32", BUF_ID) or 0
  VRFW.mem.write("u32", BUF_HDL, hdl)
  local ok, open = pcall(VRFW.call, "Passive.SignaturePieceOpen", BUF_HDL)
  return id, ok and tonumber(open) ~= nil and tonumber(open) % 256 ~= 0, ""
end

function SP.Cmd.OwnPassive(hdl)
  hdl = u32(hdl)
  if hdl == 0 then return 0, false, "" end
  -- a mode without player passives (the framework's vrfw.passive.all_off): the boards show the slot empty
  local okoff, off = pcall(VRFW.state.get, "vrfw.passive.all_off")
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
