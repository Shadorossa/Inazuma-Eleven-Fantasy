-- All Miximaxed › «Crear miximax» on the base game (docs/game/mods/all-miximaxed.md): the store command of the creation
-- flow (Character Reforged's create entry on the retail skill board: system `miximax`, content/pairing/miximax.toml),
-- the fusion rules the framework asks ([miximax] validity) and what other mods read. The fusions, their store and their look are the VR-Framework's transform engine
-- (VRFW.miximax.call); the pairing rules and the board helpers are Character Reforged's (CharacterReforged.*, system
-- "miximax": content/pairing/*.toml of every mod). Moved out of Inazuma Fantasy on 2026-10-14 (the generic part of its
-- scripts/transform.lua; IF keeps its own menu and rules).
--
-- CMND_ALLMIXIMAXED_SET(base, partner[, move1[, move2]]) codes: 0 ok, 1 the framework's miximax is not running,
-- 10 + n = CharacterReforged.PairCheck code n (11 base not owned … 19 base is a partner), 20 the pair is not allowed (no
-- generator, no declared / retail pair), 21 the fusion could not be made, 22 not stored. The moves are the partner moves
-- the player picked in the bank (Character Reforged's create flow asks `moves` of them, content/pairing/miximax.toml;
-- 1.0.6, owner 2026-10-14: «no me deja elegir las supertécnicas como en IF»). The refusal window's text of each code:
-- content/pairing/miximax.toml `refusals`.

AllMiximaxed = AllMiximaxed or {}
local M = AllMiximaxed
local SYSTEM = "miximax"
local BLOB = "miximax.json"
local StatTransfer = require "lib/stat_transfer"
local Scene = require "lib/scene"

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

-- ---------------------------------------------------------------------------------------- partner locks
-- Every stored fusion's partner stays in the player bank with the purple «Mix» plate (Character Reforged's partner
-- locks: [CharacterReforged.PartnerLock.miximax] in content/pairing/miximax.toml). The whole list goes to Character
-- Reforged whenever the store is read here (save load, a new / cleared fusion, the framework's validity pass).
local function publish_locks(fusions)
  local list = {}
  for _, f in ipairs(type(fusions) == "table" and fusions or {}) do
    local partner, base = u32(f.partner_hdl), u32(f.base_hdl)
    if partner ~= 0 then list[#list + 1] = { partner, base } end
  end
  local api = rawget(_G, "CharacterReforged")
  if type(api) == "table" and api.PartnerLockSet then pcall(api.PartnerLockSet, SYSTEM, list) end
end

-- ---------------------------------------------------------------------------------------- the framework's rules call

-- [miximax] validity: one code per stored fusion (0 = runs). Runs under the look's lock: no VRFW.miximax.call here.
local LAST = {}
function AllMiximaxed.Validity(fusions)
  local codes = CharacterReforged.PairValidity(SYSTEM, pairs_of(fusions))
  publish_locks(fusions)
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

-- a fusion record as the framework's `put` reads it back: an empty Lua table is sent as a JSON object `{}`, never an
-- empty array, so a list field the record left empty (`moves`: pairing rule `moves = 0` keeps none) must be omitted
-- (the framework's default is the empty list). A record with `moves = {}` made the whole call unreadable: `put`
-- answered nothing and «Crear miximax» refused with code 22 (2026-10-14 in-game run).
local function without_empty_lists(record)
  local out = {}
  for k, v in pairs(type(record) == "table" and record or {}) do
    if not (type(v) == "table" and next(v) == nil) then out[k] = v end
  end
  return out
end

-- the reason of each Set code, in words (one loader.log line per refusal)
local REFUSAL_WORDS = {
  [1] = "the VR-Framework's miximax look is not running",
  [11] = "the base is not an owned card", [12] = "the partner is not an owned card", [13] = "the base and the partner are the same card",
  [14] = "the base and the partner are the same character", [15] = "the base's rarity may not be fused",
  [16] = "the partner's rarity may not be a partner", [17] = "the partner is already the partner of another player",
  [18] = "the partner is the base of another miximax", [19] = "the base is already the partner of another miximax",
  [20] = "not a retail / declared pair and no mod turns the any-pair generator on",
  [21] = "the framework could not make the fusion record", [22] = "the framework did not store the fusion",
}

local function refused(code, base, partner, detail)
  local words = REFUSAL_WORDS[code] or "unknown reason"
  warn(string.format("set %s + %s refused (code %d): %s%s", hex(base), hex(partner), code, words, detail and (" - " .. detail) or ""))
  return code
end

-- the time of each step when a Set is slow (it runs on the game thread: a hitch above one frame)
local SLOW_SET_MS = 20

-- the pair (base, partner) stored as a fusion with the partner moves `move1` / `move2` the player picked (0 = none).
-- Character Reforged's create entry calls it as (base, partner, move1, move2) and places the carrier itself
-- (content/pairing/miximax.toml [CharacterReforged.Create.miximax]). No scan: one store read, the two cards' records,
-- one make, one put.
function AllMiximaxed.Set(base, partner, move1, move2)
  base, partner = u32(base), u32(partner)
  local moves = {}
  for _, m in ipairs({ u32(move1), u32(move2) }) do
    if m ~= 0 then moves[#moves + 1] = m end
  end
  local started = VRFW.now()
  local steps = {}
  local function step(name) steps[#steps + 1] = string.format("%s %d ms", name, VRFW.now() - started) end
  if mx { op = "status" } == nil then return refused(1, base, partner) end
  local st = store()
  step("store")
  local others = {}
  for _, p in ipairs(pairs_of(st.fusions)) do
    if p.base ~= base then others[#others + 1] = p end
  end
  local code, other = CharacterReforged.PairCheck(SYSTEM, base, partner, others)
  step("pair check")
  if code ~= 0 then
    return refused(10 + code, base, partner, u32(other) ~= 0 and ("other base " .. hex(other)) or nil)
  end
  local b, p = CharacterReforged.Card(base), CharacterReforged.Card(partner)
  step("cards")
  if type(b) ~= "table" or type(p) ~= "table" then
    return refused(type(b) ~= "table" and 11 or 12, base, partner, "no card record")
  end
  if mx { op = "allowed", base_param = b.param, base_chara = b.chara, partner_chara = p.chara } == false then
    return refused(20, base, partner)
  end
  local r = mx { op = "make", base_hdl = base, base_param = b.param, partner_hdl = partner, partner_param = p.param, moves = #moves > 0 and moves or { 0 } }
  step("make")
  if type(r) ~= "table" or type(r.Ok) ~= "table" then
    return refused(21, base, partner, type(r) == "table" and ("framework code " .. tostring(r.Err)) or "no answer")
  end
  local fusion = r.Ok.f or r.Ok
  local w = mx { op = "put", fusion = without_empty_lists(fusion) }
  pcall(Scene.ended, "new fusion")
  step("put")
  if VRFW.now() - started >= SLOW_SET_MS then
    info(string.format("set %s + %s slow: %s", hex(base), hex(partner), table.concat(steps, ", ")))
  end
  if type(w) ~= "table" or w.Err then
    return refused(22, base, partner, type(w) == "table" and ("framework code " .. tostring(w.Err) .. " (5 same card, 7 write error)") or "the framework did not read the record")
  end
  publish_locks(store().fusions)
  local kept = {}
  for _, m in ipairs(type(fusion.moves) == "table" and fusion.moves or {}) do kept[#kept + 1] = hex(m) end
  info(string.format("fusion %s (%s) + %s (%s) stored, partner moves [%s]", hex(base), tostring(fusion.base), hex(partner), tostring(fusion.partner), table.concat(kept, ", ")))
  return 0
end

function AllMiximaxed.Get(base)
  local l = mx { op = "fusion_of", hdl = u32(base) }
  local f = type(l) == "table" and (l.f or l) or nil
  if type(f) ~= "table" then return 0, 0 end
  return u32(f.partner_hdl), u32(f.partner_chara)
end

function AllMiximaxed.Clear(base)
  local ok = mx { op = "clear", hdl = u32(base) } == true
  publish_locks(store().fusions)
  return ok
end

-- CMND_ALLMIXIMAXED_FUSION_GET(card) -> exists, partnerParam, move1, move2, partnerChara, bestMatch, partnerHdl: the
-- running fusion of a card, the tuple Inazuma Fantasy's CMND_EVT_MX_GET answers (+ the partner's handle). Alias
-- CMND_CHARACTERREFORGED_PAGE_FUSION: Character Reforged's player page (the Hiper page's mix card: the partner's portrait
-- and name, the fusion's moves; graft plate_hiper_plate) and its skill table's mix panel (graft ss2_menus) ask it when
-- Inazuma Fantasy does not answer (1.0.6, owner 2026-10-14: the card showed the generic «Miximax Trans» carrier).
function AllMiximaxed.FusionGet(card)
  local l = mx { op = "fusion_of", hdl = u32(card) }
  local f = type(l) == "table" and type(l.f) == "table" and l.f or nil
  if not f then return false, 0, 0, 0, 0, false, 0 end
  local mv = type(f.moves) == "table" and f.moves or {}
  local best = f.best_match == true or u32(l.overdrive) ~= 0
  return true, u32(f.partner_param), u32(mv[1]), u32(mv[2]), u32(f.partner_chara), best, u32(f.partner_hdl)
end

-- ---------------------------------------------------------------------------------------- the stat transfer
-- (1.0.7, owner 2026-10-14: «trae de IF al mod de All Miximaxed el tema de las stats entre jugadores miximax»; the rule
-- and its numbers: lib\stat_transfer.lua, content\stat_transfer\miximax.toml). Nothing here when another mod owns
-- the rule (Inazuma Fantasy gives the same gains itself).

-- the running fusion record of a card ({ f, overdrive }), nil = none
local function record_of(card)
  local l = mx { op = "fusion_of", hdl = u32(card) }
  if type(l) == "table" and type(l.f) == "table" then return l end
  return nil
end

-- CMND_ALLMIXIMAXED_GAINS(card) -> ok, favouredMask, g0 … g8, kind (0 normal, 1 best match, 2 overdrive), peGain,
-- peFavoured (1 / 0): the stats his miximax adds (Character Reforged's page slot character_reforged.page_stat_gain:
-- ATRIBUTOS Normal / Miximax view, the Hiper page). false = no fusion, not readable, or another mod owns the rule
function AllMiximaxed.Gains(card)
  if not StatTransfer.Owned() then return false end
  -- his mix slot holds a kind without stats (a «Modo cambio»): his stored fusion is not in use, no gains
  local okm, adds = pcall(CharacterReforged.MixAddsStats, card)
  if okm and adds == false then return false end
  local l = record_of(card)
  if not l then return false end
  local mask, g = StatTransfer.Gains(l)
  if not mask then return false end
  local okp, pe, pe_favoured = pcall(StatTransfer.PeGain, l)
  pe = okp and tonumber(pe) or 0
  return true, mask, g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], g[9], StatTransfer.Kind(l), pe or 0,
    (okp and pe_favoured == true) and 1 or 0
end

-- CMND_ALLMIXIMAXED_PREVIEW(base, partner, move) -> ok, favouredMask, g0 … g8, kind, peGain, peFavoured, peBase:
-- what the pair would add before it is stored (Character Reforged's «Crear miximax» confirmation panel, owner
-- 2026-10-14: «esas estadísticas se tienen que ver a la hora de hacer miximax»). The framework makes the fusion record
-- (no store); false = another mod owns the rule, no card, or the partner's stats not readable
function AllMiximaxed.Preview(base, partner, move)
  if not StatTransfer.Owned() then return false end
  base, partner = u32(base), u32(partner)
  local b, p = CharacterReforged.Card(base), CharacterReforged.Card(partner)
  if type(b) ~= "table" or type(p) ~= "table" then return false end
  local r = mx { op = "make", base_hdl = base, base_param = b.param, partner_hdl = partner, partner_param = p.param, moves = { u32(move) } }
  local l = type(r) == "table" and type(r.Ok) == "table" and r.Ok or nil
  if not l or type(l.f) ~= "table" then
    info(string.format("preview %s + %s: no fusion record (%s)", hex(base), hex(partner), type(r) == "table" and tostring(r.Err) or "no answer"))
    return false
  end
  local mask, g = StatTransfer.Gains(l)
  if not mask then return false end
  local okp, pe, pe_favoured = pcall(StatTransfer.PeGain, l)
  pe = okp and tonumber(pe) or 0
  local pe_base = (pe or 0) > 0 and StatTransfer.PeBase(l) or 0
  info(string.format("preview %s + %s move %s: kind %d mask %d, PE %d +%d", hex(base), hex(partner), hex(move), StatTransfer.Kind(l), mask, pe_base, pe or 0))
  return true, mask, g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], g[9], StatTransfer.Kind(l), pe or 0,
    (okp and pe_favoured == true) and 1 or 0, pe_base
end

-- the match side: Character Reforged's skill set (its plates slot runs the matches with the «Fantasy» table; All
-- Miximaxed's [VRFW.ExtraSlotExtend.fusion], content\extra_slots\miximax.toml) asks the stat gains of a fusion that
-- starts (event fusion_start): stats 0..7 back with VRFW.extra_slot.fusion_stats (Suerte is not a match stat); the
-- PE gain grows his full bar while the miximax runs (VRFW.resource.set_max_add, source «miximax»), taken off at
-- fusion_end. As Inazuma Fantasy's scripts\transform.lua did.
local SKILL_SET_SLOT = "character_reforged.skill_set"
local PE_SOURCE = "miximax"
local PE_ON = {}                                     -- actor handle -> PE added this fusion

VRFW.on("extra_slot:" .. SKILL_SET_SLOT .. ":fusion_start", function(ev)
  local a = ev and ev.actor
  if not a or not a.handle or not StatTransfer.Owned() then return end
  local chara = u32(a.chara or 0)
  local l = record_of(chara)
  if not l then
    local okw, owner = pcall(VRFW.chara.owner_weak, chara)
    l = okw and owner and record_of(owner) or nil
  end
  local mask, g = nil, nil
  if l then mask, g = StatTransfer.Gains(l) end
  if not mask then
    info(string.format("match: actor %s chara %s: fusion stats: no stored pair / partner stats (retail stats, no PE)", hex(a.handle), hex(chara)))
    return
  end
  local gains = {}
  for i = 1, 8 do gains[i] = g[i] or 0 end
  local ok = VRFW.extra_slot.fusion_stats(a.handle, gains)
  local okp, pe = pcall(StatTransfer.PeGain, l)
  pe = okp and math.max(0, math.floor(tonumber(pe) or 0)) or 0
  local pe_given, code = false, nil
  local key = StatTransfer.Rules().pe_resource
  if pe > 0 and key and type(VRFW.resource) == "table" and type(VRFW.resource.set_max_add) == "function" then
    local okc, done, c = pcall(VRFW.resource.set_max_add, key, a.handle, PE_SOURCE, pe)
    pe_given, code = okc and done == true, okc and c or done
    if pe_given then PE_ON[a.handle] = pe end
  end
  info(string.format("match: actor %s chara %s: fusion stats %s (%s, kind %d), max PE +%d (%s)", hex(a.handle), hex(chara),
    table.concat(gains, ","), ok and "given" or "refused", StatTransfer.Kind(l), pe,
    pe == 0 and "none" or (pe_given and "given" or ("not given: " .. tostring(code)))))
end)

VRFW.on("extra_slot:" .. SKILL_SET_SLOT .. ":fusion_end", function(ev)
  local a = ev and ev.actor
  if not a or not a.handle or not PE_ON[a.handle] then return end
  local pe = PE_ON[a.handle]
  PE_ON[a.handle] = nil
  local okc, done = pcall(VRFW.resource.set_max_add, StatTransfer.Rules().pe_resource, a.handle, PE_SOURCE, 0)
  info(string.format("match: actor %s: fusion over: max PE -%d (%s)", hex(a.handle), pe, (okc and done == true) and "taken off" or "not taken off"))
end)

VRFW.on("match_start", function() PE_ON = {} end)

-- ---------------------------------------------------------------------------------------- the creation scene
-- (1.0.9, owner 2026-10-14: «añade también la animación que tiene IF cuando miximaxeas a 2 jugadores»): the Chrono
-- Stone MIXIMAX scene Character Reforged's skill table plays after «Crear miximax» (its PL.MxScenePlay, through the
-- VR-Framework's live player). The commands are declared in content\game\mx_scene.toml, left out when Inazuma Fantasy
-- is active (its own scene answers them).

-- Inazuma Fantasy declares its own scene: nothing of it here then
local function scene_owner()
  local ok, decl = pcall(VRFW.files.declarations, "content/transforms")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    if tostring(f.mod or "") == "inazuma_fantasy" then return false end
  end
  return true
end

-- CMND_ALLMIXIMAXED_SCENE(base) -> ok, event, map, partnerHdl, finalEvent, effectsOk | false, why
function AllMiximaxed.Scene(b)
  local base = u32(b)
  local l = record_of(base)
  if not l then
    warn(string.format("scene: base %s: no valid fusion for this card", hex(base)))
    return false, "no valid fusion for this card"
  end
  local ok, final, effects = Scene.prepare(base, l.f)
  if not ok then
    warn(string.format("scene: base %s: %s", hex(base), tostring(final)))
    return false, final
  end
  return true, Scene.EVENT, Scene.MAP, u32(l.f.partner_hdl), final, effects
end

-- CMND_ALLMIXIMAXED_SCENE_STATE() -> pending, base, seconds
function AllMiximaxed.SceneState() return Scene.state() end

-- CMND_ALLMIXIMAXED_SCENE_END(why)
function AllMiximaxed.SceneEnd(why) Scene.ended(tostring(why or "")) end

if scene_owner() then
  Scene.load()
else
  info("scene: Inazuma Fantasy plays its own creation scene")
end

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

-- the partner locks of the loaded save
VRFW.on("slot_load", function() publish_locks(store().fusions) end)
