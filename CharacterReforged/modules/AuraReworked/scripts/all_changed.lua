-- All Changed › the custom «Modo cambio» (docs/game/mods/all-changed.md; split out of Inazuma Fantasy 2026-10-14).
--
-- * The store: a player (base card) gets ONE change = another character's card (the partner); per save slot, blob
--   mode_change.json of this mod (imported once from Inazuma Fantasy's blob of the same name: content\game\
--   mode_change.toml [[VRFW.SaveImport]]). Key = base card handle (8 hex digits).
-- * The match: native tables ModeChange (base card -> partner card) and ModeChangeMix (base card -> his carrier
--   wmc_evt0) feed the VR-Framework's plates slot swap (content\extra_slots\change.toml, or the plates slot of a mod
--   that has its own, e.g. Inazuma Fantasy's Hiper): the player swaps between himself and the partner and back,
--   cooldown between swaps, no time limit, no cost. While a created change runs, the green aura of
--   content\effects\mode_change_aura.toml burns around him (the retail mode changes keep their own).
-- * The commands (content\game\mode_change.toml): what a creation screen asks (Character Reforged's flow; Inazuma
--   Fantasy's skill table wraps them with its own rules through the exports below).
--
-- | Command | Arguments | Returns |
-- |---|---|---|
-- | CMND_AURAREWORKED_CHANGE_ON | - | enabled, cooldown s, create item id |
-- | CMND_AURAREWORKED_CHANGE_ITEMS | - | create id, then the 8 carrier ids (wmc_evt0..7) |
-- | CMND_AURAREWORKED_CHANGE_CANDIDATES | base, start[, perCall] | total, n, then n x hdl, param, chara, element, position, allowed |
-- | CMND_AURAREWORKED_CHANGE_ADD | base, partner | ok, code, index (the new change is equipped) |
-- | CMND_AURAREWORKED_CHANGE_LIST | base | count, equipped (-1 = none) |
-- | CMND_AURAREWORKED_CHANGE_ITEM | base, index | exists, partnerHdl, partnerParam, partnerChara |
-- | CMND_AURAREWORKED_CHANGE_EQUIP | base, index (-1 = none) | ok |
-- | CMND_AURAREWORKED_CHANGE_DELETE | base, index | ok |
-- | CMND_AURAREWORKED_CHANGE_GET | base | exists, partnerParam, partnerChara, partnerHdl (the equipped change) |
-- | CMND_AURAREWORKED_CHANGE_RESERVATION | card | kind (0 free, 2 mode change partner), base |
-- | CMND_AURAREWORKED_CHANGE_PARTNER_OK | base, partner | ok, code |
-- | CMND_AURAREWORKED_CHANGE_CREATE | base, partner | code (0 ok, 10 + PairCheck code, else Add's code), carrier index |
--
-- Refusal codes of a partner (PartnerOk; Add answers 20 + code), the miximax pick codes IF's screens know: 1 the
-- partner is not an owned card, 2 the base is not / a rarity is denied, 3 the same character, 4 the partner is himself
-- a base, 5 the partner is taken (another base's partner, the base someone's partner, a card of a fusion).

local C = require "lib/cards"

AuraReworked = AuraReworked or {}
AuraReworked.Changed = AuraReworked.Changed or {}
AuraReworked.Changed.Mc = AuraReworked.Changed.Mc or {}
local M = AuraReworked.Changed.Mc
-- the part's switch (Mods options › All Changed, applied after a restart): off = nothing of this part runs
if VRFW.option("all_changed") == 0 then return M end
local u32, hex = C.u32, C.hex
local function info(...) VRFW.log("aura_reworked change:", ...) end
local function warn(...) VRFW.warn("aura_reworked change:", ...) end

-- status codes of ADD (the screen shows a message per code)
local S = { OK = 0, MODULE_OFF = 1, NO_BASE = 3, NO_PARTNER = 4, SAME_CHARA = 5, FULL = 6, WRITE = 7, DUPLICATE = 8 }
local MAX_PER_BASE = 8
local BLOB = "mode_change.json"
local CHANGE_TABLE, MIX_TABLE = "ModeChange", "ModeChangeMix"
local AURA_TRIGGER = "all_changed_custom_aura"

-- the carriers and the cooldown: this mod's own plates slot declaration (the one source of the pattern / cooldown)
local SLOT = nil
local function slot_decl()
  if SLOT then return SLOT end
  SLOT = { carriers = "wmc_evt{k}", count = 8, cooldown_s = 60 }
  local t = VRFW.files.toml("content/extra_slots/change.toml")
  local list = type(t) == "table" and type(t.VRFW) == "table" and t.VRFW.ExtraSlot or nil
  local w = type(list) == "table" and type(list[1]) == "table" and list[1].swap or nil
  if type(w) == "table" then
    SLOT.carriers = tostring(w.carriers or SLOT.carriers)
    SLOT.count = math.floor(tonumber(w.count) or SLOT.count)
    SLOT.cooldown_s = tonumber(w.cooldown_s) or SLOT.cooldown_s
  end
  return SLOT
end
local CREATE_KEY = "wmc_evt_create"
local function create_id() return u32(VRFW.ui.crc32(CREATE_KEY)) end
local function carrier_id(k) return u32(VRFW.ui.crc32((slot_decl().carriers:gsub("{k}", tostring(k))))) end

local function enabled() return VRFW.files.config("mode_change.enabled") ~= false end

-- ---------------------------------------------------------------------------------------- the store

local ST = { slot = -1, st = nil }

local function load()
  local s = C.slot()
  if ST.slot == s and ST.st then return ST.st end
  local st = { version = 1, bases = {} }
  local ok, data = pcall(VRFW.save.get_blob, s, BLOB)
  if ok and type(data) == "string" and #data > 0 then
    local v = VRFW.json.decode(data)
    if type(v) == "table" and type(v.bases) == "table" then
      for k, b in pairs(v.bases) do
        local ch = {}
        for i, c in ipairs(type(b) == "table" and type(b.changes) == "table" and b.changes or {}) do
          if i <= MAX_PER_BASE then
            ch[#ch + 1] = { partner_hdl = u32(c.partner_hdl), partner_param = u32(c.partner_param), partner_chara = u32(c.partner_chara), since = tonumber(c.since) or 0 }
          end
        end
        local e = tonumber(b.equipped)
        if e and (e < 0 or e >= #ch) then e = nil end
        if #ch > 0 then st.bases[tostring(k)] = { changes = ch, equipped = e } end
      end
    else
      warn(string.format("slot %d %s not readable: empty store used (the file is left as it is)", s, BLOB))
    end
  end
  ST.slot, ST.st = s, st
  return st
end

local function key(base) return hex(base):sub(3) end

local function equipped_of(st, base)
  local b = st.bases[key(base)]
  if not b or b.equipped == nil then return nil end
  return b.changes[b.equipped + 1]
end

-- every (partner, base) of the equipped changes
local function pairs_list()
  local v = {}
  if not enabled() then return v end
  for k, b in pairs(load().bases) do
    local ch = b.equipped ~= nil and b.changes[b.equipped + 1]
    if ch and u32(ch.partner_hdl) ~= 0 then v[#v + 1] = { u32(ch.partner_hdl), u32(tonumber(k, 16) or 0) } end
  end
  return v
end

-- the base whose equipped change uses card `partner` (nil = none)
local function reserved_by(partner)
  if partner == 0 then return nil end
  for _, p in ipairs(pairs_list()) do
    if p[1] == partner then return p[2] end
  end
  return nil
end

-- the equipped changes for the match: ModeChange[base] = partner, ModeChangeMix[base] = his carrier
-- (and the same pairs to Character Reforged's partner locks: each partner stays in the player bank with the blue-red
-- «Mix» plate, [CharacterReforged.PartnerLock.change] in content\pairing\change.toml)
function AuraReworked.Changed.Mc.publish()
  pcall(VRFW.native.table_clear, CHANGE_TABLE)
  pcall(VRFW.native.table_clear, MIX_TABLE)
  local carrier = carrier_id(0)
  local list = pairs_list()
  for _, p in ipairs(list) do
    pcall(VRFW.native.table_set, CHANGE_TABLE, p[2], p[1])
    pcall(VRFW.native.table_set, MIX_TABLE, p[2], carrier)
  end
  local base_api = rawget(_G, "CharacterReforged")
  if type(base_api) == "table" and base_api.PartnerLockSet then pcall(base_api.PartnerLockSet, "change", list) end
end

local function save()
  local st = ST.st or { version = 1, bases = {} }
  local keys = {}
  for k in pairs(st.bases) do keys[#keys + 1] = k end
  table.sort(keys)
  local bases = {}
  for _, k in ipairs(keys) do
    local b = st.bases[k]
    local list = {}
    for i, c in ipairs(b.changes) do
      list[i] = { partner_hdl = c.partner_hdl, partner_param = c.partner_param, partner_chara = c.partner_chara, since = c.since }
    end
    bases[k] = { changes = list, equipped = b.equipped }
  end
  local text = VRFW.json.encode({ version = 1, bases = bases }, true)
  local ok, why = pcall(VRFW.save.set_blob, ST.slot, BLOB, text)
  M.publish()
  if not ok then return false, tostring(why) end
  if why == false then return false, "not written" end
  return true
end

-- the stored pairs in Character Reforged's form { base, partner, partner_chara }
local function stored_pairs()
  local out = {}
  for k, b in pairs(load().bases) do
    local ch = b.equipped ~= nil and b.changes[b.equipped + 1]
    if ch then out[#out + 1] = { base = u32(tonumber(k, 16) or 0), partner = u32(ch.partner_hdl), partner_chara = u32(ch.partner_chara) } end
  end
  return out
end

-- Character Reforged's PairCheck code -> this mod's refusal code
local PAIR_CODE = { [1] = 2, [2] = 1, [3] = 3, [4] = 3, [5] = 2, [6] = 2, [7] = 5, [8] = 4, [9] = 5 }

-- the refusal of `partner` for `base`: 0 = allowed. The pairing rules of system `change` (Character Reforged's
-- PairCheck: owned cards, not the same character, one partner per base, a base never a partner; any mod's
-- content\pairing\*.toml [CharacterReforged.PairRules.change] changes them), then no card of a stored fusion's partner
-- (the framework's fusion store: any mod's miximax).
local function refusal(base, partner)
  local base_api = rawget(_G, "CharacterReforged")
  if type(base_api) == "table" and base_api.PairCheck then
    local ok, code = pcall(base_api.PairCheck, "change", base, partner, stored_pairs())
    code = ok and math.floor(tonumber(code) or 0) or 0
    if code ~= 0 then return PAIR_CODE[code] or 5 end
  else
    -- without the base (an older install): the same rules, built in
    if reserved_by(base) then return 5 end
    if equipped_of(load(), partner) then return 4 end
    local r = reserved_by(partner)
    if r and r ~= base then return 5 end
  end
  local fp = C.fusion_partners()
  if fp[base] or fp[partner] then return 5 end
  return 0
end

-- ---------------------------------------------------------------------------------------- the commands

function AuraReworked.Changed.Mc.On()
  return enabled(), math.floor(slot_decl().cooldown_s), create_id()
end

function AuraReworked.Changed.Mc.Items()
  local out = { create_id() }
  for k = 0, MAX_PER_BASE - 1 do out[#out + 1] = carrier_id(k) end
  return table.unpack(out)
end

-- every candidate partner of `base`: { hdl, param, chara, element, position, allowed } (one row per character)
local function candidate_rows(base)
  local base_chara = C.chara_of_param(C.param_of(base) or 0)
  local seen, rows = {}, {}
  for _, c in ipairs(C.owned()) do
    local row = C.param_row(c[2])
    local chara = row and row[1] or 0
    if chara ~= 0 and chara ~= base_chara and c[1] ~= base and not seen[chara] then
      seen[chara] = true
      rows[#rows + 1] = { c[1], c[2], chara, row[3], row[4], refusal(base, c[1]) == 0 and 1 or 0 }
    end
  end
  table.sort(rows, function(x, y)
    if x[3] ~= y[3] then return x[3] < y[3] end
    return x[2] < y[2]
  end)
  return rows
end

local CAND = { base = nil, rows = nil }
function AuraReworked.Changed.Mc.Candidates(b, start, per)
  local base = C.card_arg(b)
  start = math.max(0, math.floor(tonumber(start) or 0))
  if start == 0 or CAND.base ~= base or not CAND.rows then CAND.base, CAND.rows = base, candidate_rows(base) end
  per = math.floor(tonumber(per) or 0)
  if per <= 0 then per = 2 end
  per = math.min(per, 16)
  local out = { #CAND.rows, 0 }
  local n = 0
  for i = start + 1, math.min(#CAND.rows, start + per) do
    for _, v in ipairs(CAND.rows[i]) do out[#out + 1] = v end
    n = n + 1
  end
  out[2] = n
  return table.unpack(out)
end

function AuraReworked.Changed.Mc.Add(b, p)
  local base, partner = C.card_arg(b), C.card_arg(p)
  local base_chara = C.chara_of_param(C.param_of(base) or 0)
  local pparam = C.param_of(partner) or 0
  local pchara = C.chara_of_param(pparam)
  local r = refusal(base, partner)
  local code, idx = S.OK, -1
  if not enabled() then
    code = S.MODULE_OFF
  elseif base == 0 or base_chara == 0 then
    code = S.NO_BASE
  elseif r ~= 0 then
    code = 20 + r
  elseif pchara == 0 then
    code = S.NO_PARTNER
  elseif pchara == base_chara then
    code = S.SAME_CHARA
  else
    -- direct assignment: only the equipped partner is kept
    local st = load()
    st.bases[key(base)] = { changes = { { partner_hdl = partner, partner_param = pparam, partner_chara = pchara, since = math.floor(VRFW.time.unix_ms() / 1000) } }, equipped = 0 }
    local ok, why = save()
    if ok then
      idx = 0
    else
      warn("add: write failed:", why)
      code = S.WRITE
    end
  end
  CAND.rows = nil
  info(string.format("add base %s (chara %s) + partner %s (param %s, chara %s): code %d, index %d", hex(base), hex(base_chara), hex(partner), hex(pparam), hex(pchara), code, idx))
  return code == S.OK, code, idx
end

-- the store of Character Reforged's create entry (system `change`, content\pairing\change.toml): (base, partner) ->
-- code, carrier index. 0 = the change is stored and equipped (carrier wmc_evt<index>); 10 + n = Character Reforged's
-- PairCheck code n (the pair rules); otherwise Add's code (1 off, 3 no base, 4 no partner, 5 same character, 7 not
-- written, 25 a card of a stored fusion): the refusal window's texts are that file's `refusals`.
-- the reason of each Create code, in words (one loader.log line per refusal)
local CREATE_REFUSAL_WORDS = {
  [S.MODULE_OFF] = "mode changes are switched off", [S.NO_BASE] = "the base is not an owned card",
  [S.NO_PARTNER] = "the partner is not an owned card", [S.SAME_CHARA] = "the base and the partner are the same character",
  [S.WRITE] = "the change store could not be written",
  [11] = "the base is not an owned card", [12] = "the partner is not an owned card", [13] = "the base and the partner are the same card",
  [14] = "the base and the partner are the same character", [15] = "the base's rarity may not change",
  [16] = "the partner's rarity may not be a partner", [17] = "the partner is already the partner of another player",
  [18] = "the partner is the base of another change", [19] = "the base is already the partner of another change",
  [21] = "the partner is not an owned card", [22] = "the base is not an owned card or a rarity may not change",
  [23] = "the same card or the same character", [24] = "the partner is the base of another change",
  [25] = "a card already used by another change or by a stored miximax",
}

local function create_refused(code, base, partner)
  warn(string.format("create base %s + partner %s refused (code %d): %s", hex(base), hex(partner), code, CREATE_REFUSAL_WORDS[code] or "unknown reason"))
  return code, -1
end

function AuraReworked.Changed.Mc.Create(b, p)
  local base, partner = C.card_arg(b), C.card_arg(p)
  if not enabled() then return create_refused(S.MODULE_OFF, base, partner) end
  local base_api = rawget(_G, "CharacterReforged")
  if type(base_api) == "table" and base_api.PairCheck then
    local ok, code = pcall(base_api.PairCheck, "change", base, partner, stored_pairs())
    code = ok and math.floor(tonumber(code) or 0) or 0
    if code ~= 0 then return create_refused(10 + code, base, partner) end
  end
  local ok, code, idx = M.Add(base, partner)
  if ok then return 0, idx end
  return create_refused(code, base, partner)
end

function AuraReworked.Changed.Mc.List(b)
  local e = load().bases[key(C.card_arg(b))]
  if not e then return 0, -1 end
  return math.min(#e.changes, MAX_PER_BASE), e.equipped or -1
end

function AuraReworked.Changed.Mc.Item(b, i)
  local e = load().bases[key(C.card_arg(b))]
  i = math.floor(tonumber(i) or -1)
  local ch = e and i >= 0 and e.changes[i + 1]
  if not ch then return false, 0, 0, 0 end
  return true, ch.partner_hdl, ch.partner_param, ch.partner_chara
end

function AuraReworked.Changed.Mc.Equip(b, i)
  local base = C.card_arg(b)
  i = math.floor(tonumber(i) or -1)
  local e = load().bases[key(base)]
  if i >= 0 then
    local ch = e and e.changes[i + 1]
    if not ch or refusal(base, ch.partner_hdl) ~= 0 then return false end
    e.equipped = i
  elseif e then
    e.equipped = nil
  end
  local ok = true
  if e then ok = save() end
  info(string.format("equip base %s index %d: %s", hex(base), i, tostring(ok)))
  return ok
end

function AuraReworked.Changed.Mc.Delete(b, i)
  local base = C.card_arg(b)
  i = math.floor(tonumber(i) or -1)
  local st = load()
  local k = key(base)
  local e = st.bases[k]
  local ok = false
  if e and i >= 0 and i < #e.changes then
    table.remove(e.changes, i + 1)
    if e.equipped == i then
      e.equipped = nil
    elseif e.equipped and e.equipped > i then
      e.equipped = e.equipped - 1
    end
    if #e.changes == 0 then st.bases[k] = nil end
    ok = save()
  end
  CAND.rows = nil
  info(string.format("delete base %s index %d: %s", hex(base), i, tostring(ok)))
  return ok
end

function AuraReworked.Changed.Mc.Get(b)
  local ch = equipped_of(load(), C.card_arg(b))
  if not ch then return false, 0, 0, 0 end
  return true, ch.partner_param, ch.partner_chara, ch.partner_hdl
end

function AuraReworked.Changed.Mc.Reservation(c)
  local mc = reserved_by(C.card_arg(c))
  return mc and 2 or 0, mc or 0
end

function AuraReworked.Changed.Mc.PartnerOk(b, p)
  local code = refusal(C.card_arg(b), C.card_arg(p))
  return code == 0, code
end

-- ---------------------------------------------------------------------------------------- exports (mod.toml)
-- What other mods call (a mod that requires aura_reworked sees AuraReworked.Change<name>, mod.toml [exports]): the
-- commands' answers as ONE list each (`{ ok, code, index }`: a call between two script VMs passes values and tables),
-- plus the store questions a mod's own pairing rules need.

local function list_of(f) return function(...) return { f(...) } end end
AuraReworked.Changed.On = list_of(M.On)
AuraReworked.Changed.Items = list_of(M.Items)
AuraReworked.Changed.Add = list_of(M.Add)
AuraReworked.Changed.List = list_of(M.List)
AuraReworked.Changed.Item = list_of(M.Item)
AuraReworked.Changed.Equip = list_of(M.Equip)
AuraReworked.Changed.Delete = list_of(M.Delete)
AuraReworked.Changed.Get = list_of(M.Get)
AuraReworked.Changed.Reservation = list_of(M.Reservation)
AuraReworked.Changed.PartnerOk = list_of(M.PartnerOk)
-- every candidate partner of a base: { { hdl, param, chara, element, position, allowed }, … } (allowed by the generic rules)
function AuraReworked.Changed.CandidateRows(b) return candidate_rows(C.card_arg(b)) end
-- the base whose equipped change uses card `partner` (0 = none)
function AuraReworked.Changed.ReservedBy(partner) return reserved_by(u32(partner)) or 0 end
-- card `h` has an equipped change
function AuraReworked.Changed.IsBase(h) return enabled() and equipped_of(load(), u32(h)) ~= nil end
-- every { partner, base } of the equipped changes
function AuraReworked.Changed.Pairs() return pairs_list() end
-- the carrier of change k (wmc_evt<k>) / every carrier
function AuraReworked.Changed.Carrier(k) return carrier_id(math.floor(tonumber(k) or 0)) end
-- the exported names (one level under the prefix)
for _, name in ipairs { "On", "Items", "Add", "List", "Item", "Equip", "Delete", "Get", "Reservation", "PartnerOk", "CandidateRows", "ReservedBy", "IsBase", "Pairs", "Carrier" } do
  AuraReworked["Change" .. name] = AuraReworked.Changed[name]
end

-- ---------------------------------------------------------------------------------------- events

-- the plates slots that run this mod's swap (any active mod's [[VRFW.ExtraSlot]] whose [swap] has these carriers):
-- the green aura goes on / off with their swap events. Read at load (files only).
local function swap_slot_keys()
  local keys = {}
  local ok, decl = pcall(VRFW.files.declarations, "content/extra_slots")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f.data) == "table" and f.data or {}
    local list = type(d.VRFW) == "table" and d.VRFW.ExtraSlot or nil
    for _, s in ipairs(type(list) == "table" and list or {}) do
      local w = type(s) == "table" and s.swap or nil
      if type(w) == "table" and tostring(w.carriers or "") == slot_decl().carriers and s.name then
        keys[#keys + 1] = tostring(f.mod) .. "." .. tostring(s.name)
      end
    end
    -- [[VRFW.ExtraSlotExtend]] (VRFW 2.4.3): a swap with these carriers added to another mod's slot (this mod's own
    -- extension of Character Reforged's skill set slot, or a game mode's)
    local ext = type(d.VRFW) == "table" and d.VRFW.ExtraSlotExtend or nil
    for _, s in ipairs(type(ext) == "table" and ext or {}) do
      local w = type(s) == "table" and s.swap or nil
      if type(w) == "table" and tostring(w.carriers or "") == slot_decl().carriers and type(s.slot) == "string" then
        keys[#keys + 1] = s.slot
      end
    end
  end
  local seen, out = {}, {}
  for _, k in ipairs(keys) do
    if not seen[k] then seen[k] = true out[#out + 1] = k end
  end
  return out
end

for _, k in ipairs(swap_slot_keys()) do
  VRFW.on("extra_slot:" .. k .. ":swap_on", function(ev)
    -- option change_aura (Mods options): off = no green aura while the change runs
    if ev.actor and VRFW.option("change_aura") ~= 0 then
      VRFW.char_effect{ trigger = AURA_TRIGGER }
      info(string.format("custom change aura on for actor %s (%s)", hex(ev.actor.handle), k))
    end
  end)
  VRFW.on("extra_slot:" .. k .. ":swap_off", function(ev)
    if ev.actor then
      VRFW.char_effect{ clear = true, trigger = AURA_TRIGGER }
      info(string.format("custom change aura off for actor %s", hex(ev.actor.handle)))
    end
  end)
end

VRFW.on("slot_load", function()
  ST.slot, ST.st, CAND.rows = -1, nil, nil
  M.publish()
end)
VRFW.on("game_reset", function()
  ST.slot, ST.st, CAND.rows = -1, nil, nil
end)

return M
