-- Character Reforged › the shared pairing rules and card / board helpers of the aura mods' creation flows (All
-- Miximaxed «Crear miximax», All Changed «Crear nuevo cambio»; docs/refactor/aura-mods-split.md «CharacterReforged:
-- shared base»). Pure Lua over the framework: the saved character records (VRFW.chara), the card index, the mods'
-- content\pairing\*.toml rules (VRFW.files.declarations) and the game's board placement (content\game\board.toml).
-- Other mods call the exported functions (mod.toml [exports]); a system's own store stays in its mod.
--
-- PairCheck codes (0 = the pair may be made):
--   1 the base is not an owned card       2 the partner is not an owned card     3 the same card
--   4 two cards of the same character     5 the base's rarity is denied          6 the partner's rarity is denied
--   7 the partner is the partner of another base (2nd value: that base)
--   8 the partner is a base                9 the base is the partner of another pair (2nd value: that base)
-- PairValidity codes per stored pair (the framework's miximax validity): 0 runs, 2 the partner is not an owned card
-- of that character any more, 4 the partner is used by an earlier pair.

CharacterReforged = CharacterReforged or {}
local A = CharacterReforged

local band, rshift = bit32.band, bit32.rshift

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

local function hex(v) return string.format("0x%08X", u32(v)) end
local function info(...) VRFW.log("pairing:", ...) end

-- ---------------------------------------------------------------------------------------- the rules (data)

-- what a system gets when no mod declares a key (the same values as content\pairing\defaults.toml)
local BUILTIN = { same_character = false, one_partner_per_base = true, base_may_be_partner = false, base_rarities_denied = {}, partner_rarities_denied = {}, moves = 0, avatar_may_pair = true }
local RULES = nil
local DECLARATIONS = nil

-- every mod's content\pairing\*.toml, read once per session (the pair rules and the create rows both come from them;
-- the create entry reads them when its list opens, so a store command never reads files on the game thread)
function A.PairingDeclarations()
  if DECLARATIONS then return DECLARATIONS end
  local ok, decl = pcall(VRFW.files.declarations, "content/pairing")
  DECLARATIONS = ok and type(decl) == "table" and decl or {}
  return DECLARATIONS
end

local function load_rules()
  if RULES then return RULES end
  RULES = {}
  for _, f in ipairs(A.PairingDeclarations()) do
    local d = type(f) == "table" and f.data or nil
    local root = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.PairRules or nil
    if type(root) == "table" then
      for system, keys in pairs(root) do
        if type(system) == "string" and type(keys) == "table" then
          local r = RULES[system] or {}
          for k, v in pairs(keys) do r[k] = v end
          RULES[system] = r
        end
      end
    end
  end
  return RULES
end

-- the merged rules of a system: built-in values < `default` < the system's own table
function A.PairRules(system)
  local r = {}
  for k, v in pairs(BUILTIN) do r[k] = v end
  local all = load_rules()
  for _, t in ipairs({ all.default or {}, all[tostring(system)] or {} }) do
    for k, v in pairs(t) do r[k] = v end
  end
  return r
end

local function listed(list, v)
  for _, x in ipairs(type(list) == "table" and list or {}) do
    if u32(x) == v then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------------------- cards

-- the character of each card id (VRFW.chara.card(param).base), read once per session: the card data does not change
-- while the game runs (cleared at game_reset with the rules)
local CHARA_OF_PARAM = {}

local function chara_of(param)
  local chara = CHARA_OF_PARAM[param]
  if chara ~= nil then return chara end
  local okc, c = pcall(VRFW.chara.card, param)
  if not okc or type(c) ~= "table" then return 0 end
  chara = u32(c.base)
  CHARA_OF_PARAM[param] = chara
  return chara
end

-- an owned card (container kind 0 / 7 with a save record): { hdl, param, chara, rarity, addr }; nil otherwise
function A.Card(hdl)
  hdl = u32(hdl)
  if hdl == 0 then return nil end
  local kind = band(rshift(hdl, 12), 0xF)
  if kind ~= 0 and kind ~= 7 then return nil end
  local ok, r = pcall(VRFW.chara.record, hdl)
  if not ok or type(r) ~= "table" or not r.addr then return nil end
  local param = u32(r.param)
  if param == 0 then return nil end
  return { hdl = hdl, param = param, chara = chara_of(param), rarity = tonumber(r.rarity) or 0, addr = r.addr }
end

-- ---------------------------------------------------------------------------------------- pairs

-- may `partner` be paired with `base` under `system`'s rules? `pairs` = the system's stored pairs
-- { { base = hdl, partner = hdl, partner_chara = id }, … } (other bases' pairs; the base's own is replaced)
-- a PairCheck slower than this logs the time of each step (it runs inside a store command, on the game thread)
local SLOW_CHECK_MS = 20

function A.PairCheck(system, base, partner, pairs)
  local started = VRFW.now()
  local r = A.PairRules(system)
  local rules_ms = VRFW.now() - started
  base, partner = u32(base), u32(partner)
  local b = A.Card(base)
  local base_ms = VRFW.now() - started
  local p = b and A.Card(partner) or nil
  local total = VRFW.now() - started
  if total >= SLOW_CHECK_MS then
    info(string.format("pair check %s + %s (%s) slow: rules %d ms, base card %d ms, partner card %d ms", hex(base), hex(partner),
      tostring(system), rules_ms, base_ms - rules_ms, total - base_ms))
  end
  if not b then return 1, 0 end
  if not p then return 2, 0 end
  if base == partner then return 3, 0 end
  if r.same_character ~= true and b.chara ~= 0 and b.chara == p.chara then return 4, 0 end
  if listed(r.base_rarities_denied, b.rarity) then return 5, 0 end
  if listed(r.partner_rarities_denied, p.rarity) then return 6, 0 end
  for _, o in ipairs(type(pairs) == "table" and pairs or {}) do
    local ob, op = u32(o.base), u32(o.partner)
    if ob ~= base then
      if r.one_partner_per_base ~= false and op == partner then return 7, ob end
      if r.base_may_be_partner ~= true then
        if ob == partner then return 8, ob end
        if op == base then return 9, ob end
      end
    end
  end
  return 0, 0
end

-- the run state of each stored pair, in store order (the first pair that still claims a partner keeps him)
function A.PairValidity(system, pairs)
  local r = A.PairRules(system)
  local out, claimed = {}, {}
  for i, o in ipairs(type(pairs) == "table" and pairs or {}) do
    local partner, want = u32(o.partner), u32(o.partner_chara)
    local p = A.Card(partner)
    local code = 0
    if not p or (want ~= 0 and p.chara ~= 0 and p.chara ~= want) then
      code = 2
    elseif r.one_partner_per_base ~= false and claimed[partner] and claimed[partner] ~= u32(o.base) then
      code = 4
    else
      claimed[partner] = claimed[partner] or u32(o.base)
    end
    out[i] = code
  end
  return out
end

-- ---------------------------------------------------------------------------------------- the skill board

local REC_PLACED, REC_NATIVE, REC_PIECE = 0x94, 0xC8, 0x165
local BOARD_SLOTS = 9
local HBUF = nil

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function item_of(inv)
  if inv == 0 then return 0 end
  local ok, item = pcall(VRFW.item.of_inv, inv)
  return ok and u32(item or 0) or 0
end

-- the board slots of an owned card: { [slot] = { inv, item, placed (bool), piece } } for slots 0..8; nil = no record
function A.BoardItems(hdl)
  local c = A.Card(hdl)
  if not c then return nil end
  local out = {}
  for s = 0, BOARD_SLOTS - 1 do
    local placed = u32(rd("u32", c.addr + REC_PLACED + s * 4) or 0)
    local inv = placed ~= 0 and placed or u32(rd("u32", c.addr + REC_NATIVE + s * 4) or 0)
    out[s] = { inv = inv, item = item_of(inv), placed = placed ~= 0, piece = rd("u8", c.addr + REC_PIECE + s) or 0xFF }
  end
  return out
end

-- the board slot of card `hdl` holding item `item` (placed items first), -1 = none
function A.BoardSlotOf(hdl, item)
  item = u32(item)
  local b = A.BoardItems(hdl)
  if not b or item == 0 then return -1 end
  for s = 0, BOARD_SLOTS - 1 do
    if b[s].placed and b[s].item == item then return s end
  end
  for s = 0, BOARD_SLOTS - 1 do
    if b[s].item == item then return s end
  end
  return -1
end

-- put inventory handle `inv` on the open board slot `slot` of card `hdl` (the game's own placement) -> ok, why
function A.BoardPlace(hdl, slot, inv)
  hdl, slot, inv = u32(hdl), math.floor(tonumber(slot) or -1), u32(inv)
  if slot < 0 or slot >= BOARD_SLOTS or inv == 0 then return false, "bad arguments" end
  local b = A.BoardItems(hdl)
  if not b then return false, "no record" end
  local piece = b[slot].piece
  if piece >= 0x80 then return false, "slot closed" end
  HBUF = HBUF or VRFW.mem.buffer("character_reforged_board_hdl", 8)
  local okw = pcall(VRFW.mem.write, "u32", HBUF, hdl)
  if not okw then return false, "buffer" end
  local ok, e = pcall(VRFW.call, "CharacterReforged.BoardPlaceByHandle", HBUF, piece, inv, 0, 1)
  if not ok then return false, "place: " .. tostring(e) end
  local after = A.BoardItems(hdl)
  local got = after and after[slot].inv or 0
  info(string.format("board %s slot %d: inv %s placed (piece %d, slot now %s)", hex(hdl), slot, hex(inv), piece, hex(got)))
  return got == inv, got == inv and nil or "slot holds " .. hex(got)
end

-- the rules are read again after a hot reload of the mods' files
VRFW.on("game_reset", function()
  RULES = nil
  DECLARATIONS = nil
  CHARA_OF_PARAM = {}
end)

-- the base game's «Crear …» entry of the aura mods (graft character_reforged_board; commands content\game\create.toml)
require "lib/create"
