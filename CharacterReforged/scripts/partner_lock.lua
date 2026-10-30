-- Character Reforged › partner locks: a card of the player's club used as the PARTNER of another card's pair (a
-- Mix-Max of All Miximaxed, a mode change of Custom Change Mode, any system a mod declares) stays in the player bank. He
-- cannot be placed from the bank into a team (every team screen, the bank's «Añadir al equipo», a drag, the mouse) and
-- his bank card shows the system's plate («Mix»). A partner already in a team stays where he is; he may always go back
-- to the bank. Docs: docs/game/ui/partner-lock-bank.md.
--
-- A system is data: any active mod's content\pairing\*.toml (schema CharacterReforged.pairing/1)
--
--   [CharacterReforged.PartnerLock.<system>]
--   badge_sprite = "all_miximaxed_partner_badge"   # the plate's sprite on the badge atlas
--                                                 # #/menu/102_team/team11/team11_05/team11_05.g4tx (160 x 52 px PNG,
--                                                 # drawn at 80 x 26; the declaring mod adds it with the image type)
--   badge_text = "aura_reworked.miximax_partner_badge" # text key of the plate's word
--   order = 10                                     # a card locked by two systems shows the lower order's plate
--   off = false                                    # true: no lock for this system (a game mode may switch one off)
--
-- The pairs come from the system's own mod (this base does not see its plugins): it calls the export
-- CharacterReforged.PartnerLockSet(system, pairs) with EVERY partner of its store ({ { partner, base }, … }) whenever
-- the store changes and at each save load. A system that never calls it locks nobody.
--
-- Commands (content\game\partner_lock.toml): CMND_CHARACTERREFORGED_PARTNER_LOCKS() -> table of { card, base, sprite,
-- textId, text } (every locked card; the bank's hook file reads it once per open); CMND_CHARACTERREFORGED_PARTNER_LOCK
-- (card) -> base (0 = free), sprite, textId, text. Filters on the game's place check 1730898405 (hdl, toSet, pos,
-- fromSet, team) and place / move 193693077 (toSet, pos, fromSet, hdl, team): from the bank into a team set = refused.

CharacterReforged = CharacterReforged or {}
local A = CharacterReforged
A.PartnerLock = A.PartnerLock or {}

local Id = require "VRFW/lib/ids"
local u32 = Id.u32

local hex = Id.hex
require "VRFW/lib/basics"
local info = VRFW.logger("partner lock")

-- the game's set number of the club bank: team templates / docks are the sets below it
local BANK_SET = 16
-- the second value the place check answers for a refused partner (any non-zero code refuses)
local PLACE_REFUSED = 77
local DEFAULT_ORDER = 100

local function id_of(k)
  if type(k) == "string" and k ~= "" then return u32(VRFW.crc32(k)) end
  return 0
end

local function text_of(key)
  if type(key) ~= "string" or key == "" then return "" end
  local ok, s = pcall(VRFW.text, key)
  if ok and type(s) == "string" then return s end
  return ""
end

-- ---------------------------------------------------------------------------------------- the systems (data)

local SYSTEMS = nil

-- every mod's content\pairing\*.toml, read here: each script has its own VM, so pairing.lua's reader is not reachable
local function declarations()
  local ok, decl = pcall(VRFW.files.declarations, "content/pairing")
  return ok and type(decl) == "table" and decl or {}
end

local function systems()
  if SYSTEMS then return SYSTEMS end
  local merged = {}
  for _, f in ipairs(declarations()) do
    local d = type(f) == "table" and f.data or nil
    local root = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.PartnerLock or nil
    if type(root) == "table" then
      for system, keys in pairs(root) do
        if type(system) == "string" and type(keys) == "table" then
          local s = merged[system] or { from = "?" }
          for k, v in pairs(keys) do s[k] = v end
          s.from = tostring(f.mod or "?")
          merged[system] = s
        end
      end
    end
  end
  SYSTEMS = {}
  for system, s in pairs(merged) do
    local e = {
      system = system, mod = s.from, off = s.off == true, order = tonumber(s.order) or DEFAULT_ORDER,
      sprite_name = s.badge_sprite and tostring(s.badge_sprite) or nil, text_key = s.badge_text and tostring(s.badge_text) or nil,
    }
    e.sprite, e.text_id = id_of(e.sprite_name), id_of(e.text_key)
    SYSTEMS[system] = e
    info(string.format("system %s (%s): %s, plate %s, text %s, order %d", system, e.mod, e.off and "off" or "on",
      tostring(e.sprite_name), tostring(e.text_key), e.order))
  end
  return SYSTEMS
end

-- a system nobody declared: locked, no plate
local function system_of(name)
  local s = systems()[name]
  if s then return s end
  s = { system = name, mod = "?", off = false, order = DEFAULT_ORDER, sprite = 0, text_id = 0 }
  SYSTEMS[name] = s
  info(string.format("system %s: pairs without a [CharacterReforged.PartnerLock.%s] declaration: locked, no plate", name, name))
  return s
end

-- ---------------------------------------------------------------------------------------- the pairs

local PAIRS = {}      -- system -> { [partner] = base }
local LOCKED = nil    -- partner -> { base, system entry } (rebuilt when a system's pairs change)

local function rebuild()
  LOCKED = {}
  for name, map in pairs(PAIRS) do
    local s = system_of(name)
    if not s.off then
      for partner, base in pairs(map) do
        local cur = LOCKED[partner]
        if not cur or s.order < cur.s.order or (s.order == cur.s.order and s.system < cur.s.system) then
          LOCKED[partner] = { base = base, s = s }
        end
      end
    end
  end
  return LOCKED
end

local function locked() return LOCKED or rebuild() end

-- the system's whole list of pairs: { { partner, base }, … } (or { partner = , base = } records); replaces the last one
function CharacterReforged.PartnerLockSet(system, list)
  system = tostring(system or "")
  if system == "" then return false end
  local map, n, changed = {}, 0, false
  for _, p in ipairs(type(list) == "table" and list or {}) do
    if type(p) == "table" then
      local partner, base = u32(p.partner or p[1]), u32(p.base or p[2])
      if partner ~= 0 and partner ~= base then
        if not map[partner] then n = n + 1 end
        map[partner] = base
      end
    end
  end
  local old = PAIRS[system] or {}
  for k, v in pairs(map) do if old[k] ~= v then changed = true end end
  for k in pairs(old) do if map[k] == nil then changed = true end end
  if not changed and PAIRS[system] then return true end
  PAIRS[system] = map
  LOCKED = nil
  local shown = {}
  for partner, base in pairs(map) do
    if #shown < 8 then shown[#shown + 1] = hex(partner) .. " (of " .. hex(base) .. ")" end
  end
  info(string.format("system %s: %d partner(s) kept in the bank%s%s", system, n, n > 0 and ": " or "",
    table.concat(shown, ", ") .. (n > #shown and ", …" or "")))
  return true
end

-- (card) -> base, system entry (nil = free)
function A.PartnerLock.Of(card)
  local e = locked()[u32(card)]
  if e then return e.base, e.s end
  return nil
end

-- ---------------------------------------------------------------------------------------- commands

-- CMND_CHARACTERREFORGED_PARTNER_LOCK(card) -> base (0 = free), sprite, textId, text
function CharacterReforged.PartnerLock.Get(card)
  local base, s = A.PartnerLock.Of(card)
  if not base then return 0, 0, 0, "" end
  return base, s.sprite or 0, s.text_id or 0, text_of(s.text_key)
end

-- CMND_CHARACTERREFORGED_PARTNER_LOCKS() -> { { card, base, sprite, textId, text }, … }
function CharacterReforged.PartnerLock.List()
  local out, texts = {}, {}
  for card, e in pairs(locked()) do
    local key = e.s.text_key or ""
    if texts[key] == nil then texts[key] = text_of(key) end
    out[#out + 1] = { card, e.base, e.s.sprite or 0, e.s.text_id or 0, texts[key] }
  end
  return out
end

-- ---------------------------------------------------------------------------------------- the place filters

local function refused(card, to_set, from_set)
  to_set, from_set = tonumber(to_set) or -1, tonumber(from_set) or -1
  if to_set < 0 or to_set >= BANK_SET or from_set < BANK_SET then return nil end
  local base, s = A.PartnerLock.Of(card)
  if not base then return nil end
  return base, s
end

-- place check 1730898405(hdl, toSet, pos, fromSet, team) -> ok, code
function CharacterReforged.PartnerLock.PlaceCheck(hdl, to_set, pos, from_set)
  local base, s = refused(hdl, to_set, from_set)
  if not base then return false end
  info(string.format("place check %s: bank -> team set %s REFUSED: %s partner of %s", hex(hdl), tostring(to_set), s.system, hex(base)))
  return true, false, PLACE_REFUSED
end

-- place / move 193693077(toSet, pos, fromSet, hdl, team): the paths that place without the check («Añadir al equipo»)
function CharacterReforged.PartnerLock.MoveChara(to_set, pos, from_set, hdl)
  local base, s = refused(hdl, to_set, from_set)
  if not base then return false end
  info(string.format("place %s: bank -> team set %s REFUSED: %s partner of %s", hex(hdl), tostring(to_set), s.system, hex(base)))
  return true, false
end

VRFW.on("game_reset", function()
  PAIRS, LOCKED = {}, nil
end)
