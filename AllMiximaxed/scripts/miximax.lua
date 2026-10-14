-- All Miximaxed › «Crear miximax» on the base game (docs/game/mods/all-miximaxed.md): the store command of the creation
-- flow (Character Reforged's create entry on the retail skill board: system `miximax`, content/pairing/miximax.toml),
-- the fusion rules the framework asks ([miximax] validity) and what other mods read. The fusions, their store and their look are the VR-Framework's transform engine
-- (VRFW.miximax.call); the pairing rules and the board helpers are Character Reforged's (CharacterReforged.*, system
-- "miximax": content/pairing/*.toml of every mod). Moved out of Inazuma Fantasy on 2026-10-14 (the generic part of its
-- scripts/transform.lua; IF keeps its own menu and rules).
--
-- CMND_ALLMIXIMAXED_SET codes: 0 ok, 1 the framework's miximax is not running, 10 + n = CharacterReforged.PairCheck code n
-- (11 base not owned … 19 base is a partner), 20 the pair is not allowed (no generator, no declared / retail pair),
-- 21 the fusion could not be made, 22 not stored, 23 stored but the carrier could not be put on the slot (only when
-- a slot is passed). The refusal window's text of each code: content/pairing/miximax.toml `refusals`.

AllMiximaxed = AllMiximaxed or {}
local M = AllMiximaxed
local SYSTEM = "miximax"
local BLOB = "miximax.json"

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

local function hex(v) return string.format("0x%08X", u32(v)) end
local function info(...) VRFW.log("all_miximaxed:", ...) end
local function warn(...) VRFW.warn("all_miximaxed:", ...) end

local function mx(op)
  local ok, r = pcall(VRFW.miximax.call, op)
  if ok then return r end
  return nil
end

-- the active slot's fusion store { version, fusions = { … } }
local function store()
  local s = mx { op = "store" }
  if type(s) == "table" and type(s[2]) == "table" then return s[2] end
  return { version = 1, fusions = {} }
end

-- the store's pairs as Character Reforged reads them
local function pairs_of(fusions)
  local out = {}
  for i, f in ipairs(type(fusions) == "table" and fusions or {}) do
    out[i] = { base = u32(f.base_hdl), partner = u32(f.partner_hdl), partner_chara = u32(f.partner_chara) }
  end
  return out
end

-- ---------------------------------------------------------------------------------------- the framework's rules call

-- [miximax] validity: one code per stored fusion (0 = runs). Runs under the look's lock: no VRFW.miximax.call here.
local LAST = {}
function AllMiximaxed.Validity(fusions)
  local codes = CharacterReforged.PairValidity(SYSTEM, pairs_of(fusions))
  for i, f in ipairs(type(fusions) == "table" and fusions or {}) do
    local b, v = u32(f.base_hdl), codes[i] or 0
    if LAST[b] ~= v then
      LAST[b] = v
      info(string.format("fusion %s + %s: %s", hex(b), hex(f.partner_hdl), v == 0 and "ON" or ("OFF (code " .. v .. ")")))
    end
  end
  return codes
end

-- ---------------------------------------------------------------------------------------- the creation flow

-- the pair (base, partner) stored as a fusion; with `slot` / `inv` (an older caller) the carrier `inv` is also put on
-- board slot `slot` of the base. Character Reforged's create entry calls it as (base, partner) and places the carrier
-- itself (content/pairing/miximax.toml [CharacterReforged.Create.miximax]).
function AllMiximaxed.Set(base, partner, slot, inv)
  base, partner, inv = u32(base), u32(partner), u32(inv)
  slot = math.floor(tonumber(slot) or -1)
  if mx { op = "status" } == nil then return 1 end
  local st = store()
  local others = {}
  for _, p in ipairs(pairs_of(st.fusions)) do
    if p.base ~= base then others[#others + 1] = p end
  end
  local code, other = CharacterReforged.PairCheck(SYSTEM, base, partner, others)
  if code ~= 0 then
    info(string.format("set %s + %s refused: pairing code %d (other base %s)", hex(base), hex(partner), code, hex(other)))
    return 10 + code
  end
  local b, p = CharacterReforged.Card(base), CharacterReforged.Card(partner)
  if mx { op = "allowed", base_param = b.param, base_chara = b.chara, partner_chara = p.chara } == false then
    info(string.format("set %s + %s refused: not a retail / declared pair and no generator", hex(base), hex(partner)))
    return 20
  end
  local r = mx { op = "make", base_hdl = base, base_param = b.param, partner_hdl = partner, partner_param = p.param, moves = { 0 } }
  if type(r) ~= "table" or type(r.Ok) ~= "table" then
    warn(string.format("set %s + %s: the fusion was not made (%s)", hex(base), hex(partner), type(r) == "table" and tostring(r.Err) or "no answer"))
    return 21
  end
  local w = mx { op = "put", fusion = r.Ok.f or r.Ok }
  if type(w) ~= "table" or w.Err then
    warn(string.format("set %s + %s: not stored (%s)", hex(base), hex(partner), type(w) == "table" and tostring(w.Err) or "no answer"))
    return 22
  end
  info(string.format("fusion %s (%s) + %s (%s) stored", hex(base), tostring((r.Ok.f or r.Ok).base), hex(partner), tostring((r.Ok.f or r.Ok).partner)))
  if slot >= 0 and inv ~= 0 then
    local ok, why = CharacterReforged.BoardPlace(base, slot, inv)
    if not ok then
      warn(string.format("set %s: carrier %s not placed on slot %d (%s)", hex(base), hex(inv), slot, tostring(why)))
      return 23
    end
  end
  return 0
end

function AllMiximaxed.Get(base)
  local l = mx { op = "fusion_of", hdl = u32(base) }
  local f = type(l) == "table" and (l.f or l) or nil
  if type(f) ~= "table" then return 0, 0 end
  return u32(f.partner_hdl), u32(f.partner_chara)
end

function AllMiximaxed.Clear(base) return mx { op = "clear", hdl = u32(base) } == true end

-- ---------------------------------------------------------------------------------------- for other mods ([exports])

-- the stored fusions of the active slot (a copy)
function AllMiximaxed.Fusions() return store().fusions or {} end

-- the store's saved text of save slot `slot` (nil = none): the blob is this mod's since 1.0.0 (a game mode's own
-- save tools read it through here)
function AllMiximaxed.StoreBlob(slot)
  local ok, data = pcall(VRFW.save.get_blob, tonumber(slot) or 1, BLOB)
  if ok and type(data) == "string" then return data end
  return nil
end
