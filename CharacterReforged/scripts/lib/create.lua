-- Character Reforged › the base game's «Crear …» entry of the aura mods (docs/refactor/aura-mods-split.md «The base
-- game's create entry»): ONE flow on the retail skill board (graft character_reforged_board) with one row per SYSTEM a
-- mod declares. An aura piece's list shows the «create» item of every declared system (All Miximaxed «Crear miximax»,
-- All Changed «Crear nuevo cambio»); the player picks one, the retail bank picker gives the partner, the system's own
-- store command keeps the pair and this flow puts the system's carrier on that board slot. A refused or cancelled
-- pick gives the slot back what it held; a refusal shows a retail info window (a text key per refusal code).
--
-- A system is data: any active mod's content\pairing\*.toml (schema CharacterReforged.pairing/1)
--
--   [CharacterReforged.Create.<system>]       # <system> = the pairing rules' system name (CharacterReforged.PairCheck)
--   item = "wmm_evt_create"                 # the «create» row of the aura list (the item's own name is the row)
--   label = "aura_reworked.miximax_create_label" # text key: the system's name in the refusal window (default: the item's name)
--   store = "CMND_AURAREWORKED_MIXIMAX_SET"  # command (base, partner[, move1, move2]) -> code (0 = stored)[, carrier index k]
--   carrier = "wmm_evt"                     # the carrier put on the slot ("wmc_evt{k}": k = the store's 2nd value)
--   pair_codes = 10                         # store code = pair_codes + PairCheck code (1..9) for a pair-rule refusal
--   order = 10                              # row order of the systems (lower first; then the system's name)
--   confirm = "aura_reworked.miximax_create_confirm" # text key of the bank's Sí / No after the partner's moves ({base}
--                                           # {partner} {moves}; default character_reforged.create_confirm)
--   confirm_icon = "icon_sp_area07"         # sprite of icon_common drawn between the two players' cards of that
--                                           # confirmation (the base and the partner; none = the cards only)
--   preview = "CMND_AURAREWORKED_MIXIMAX_PREVIEW" # command (base, partner, move) -> ok, favouredMask, g0 .. g8, kind, peGain,
--                                           # peFavoured, peBase: the stats the confirmation panel shows (none = no stats)
--   scene = true                            # the skill table plays the miximax creation scene after a stored pair
--                                           # (its PL.MxScenePlay; the scene's commands are the declaring mod's)
--   off = false                             # true: this system has no row (a game mode may switch one off)
--   [CharacterReforged.Create.<system>.refusals]
--   "20" = "character_reforged.create_refused_not_allowed"   # the store's own codes -> text keys
--
-- Keys merge over the mods in load order (the later mod wins key by key, `refusals` code by code), as PairRules do.
-- The store is a COMMAND (not a Lua export): this base does not `require` its plugins, so it can not see their
-- exports; the game-Lua graft calls the command by its id.
--
-- Partner moves (1.7.22, owner 2026-10-14: «no me deja elegir las supertécnicas como en IF»): a system whose pairing
-- rules ask `moves = n` (> 0; All Miximaxed's miximax: 1) picks them in the retail bank, as Inazuma Fantasy's «Crear
-- miximax» did: Aceptar on a card puts the cursor on that card's special moves on the plate, Aceptar on a move (not a
-- hyper technique / aura, a goalkeeper move only for a goalkeeper base, not one the base has) asks the system's
-- confirmation (card window, Sí / No); Sí closes the bank with the partner and the moves. The graft passes the base and
-- the row to the bank (param keys character_reforged_create_base / _row; bank_create_moves_hooks.lua) and the picked
-- moves to the store command: (base, partner, move1, move2). CMND_CHARACTERREFORGED_CREATE_MOVES(row) answers n.
--
-- Refusal window text: the system's label, then the reason: PairCheck code n -> character_reforged.create_refused_<n>,
-- a declared `refusals` code -> its key, anything else -> character_reforged.create_refused_other; the carrier not
-- placed (graft code -2) -> character_reforged.create_refused_place.

CharacterReforged = CharacterReforged or {}
local A = CharacterReforged
A.Create = A.Create or {}
local K = A.Create  -- (functions declared by full name: vrfw check finds the command handlers by text)

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

local function hex(v) return string.format("0x%08X", u32(v)) end
local function info(...) VRFW.log("create:", ...) end

local MOD = "character_reforged"
local PLACE_FAILED = -2

local function id_of(k)
  if type(k) == "number" then return u32(k) end
  if type(k) == "string" and k ~= "" then return u32(VRFW.crc32(k)) end
  return 0
end

-- ---------------------------------------------------------------------------------------- the systems (data)

local SYSTEMS = nil

local function load_systems()
  if SYSTEMS then return SYSTEMS end
  local merged, from = {}, {}
  for _, f in ipairs(A.PairingDeclarations()) do
    local d = type(f) == "table" and f.data or nil
    local root = type(d) == "table" and type(d.CharacterReforged) == "table" and d.CharacterReforged.Create or nil
    if type(root) == "table" then
      for system, keys in pairs(root) do
        if type(system) == "string" and type(keys) == "table" then
          local s = merged[system] or { refusals = {} }
          for k, v in pairs(keys) do
            if k == "refusals" and type(v) == "table" then
              for code, key in pairs(v) do s.refusals[tostring(code)] = key end
            else
              s[k] = v
            end
          end
          merged[system] = s
          from[system] = tostring(f.mod or "?")
        end
      end
    end
  end
  local list = {}
  for system, s in pairs(merged) do
    local item, store = id_of(s.item), tostring(s.store or "")
    if s.off == true then
      info(string.format("system %s: off (%s)", system, from[system]))
    elseif item == 0 or store == "" then
      VRFW.warn("create:", string.format("system %s (%s): no `item` or no `store`: no row", system, from[system]))
    else
      list[#list + 1] = {
        system = system, pair_system = tostring(s.system or system), mod = from[system],
        item = item, item_key = tostring(s.item), label = s.label and tostring(s.label) or nil,
        store_name = store, store = id_of(store), carrier = s.carrier, pair_codes = math.floor(tonumber(s.pair_codes) or -1),
        order = tonumber(s.order) or 100, refusals = s.refusals, confirm = s.confirm and tostring(s.confirm) or nil,
        confirm_icon = s.confirm_icon and tostring(s.confirm_icon) or nil, preview = s.preview and tostring(s.preview) or nil,
        scene = s.scene == true,
      }
    end
  end
  table.sort(list, function(x, y)
    if x.order ~= y.order then return x.order < y.order end
    return x.system < y.system
  end)
  for i, s in ipairs(list) do
    info(string.format("row %d: system %s (%s): item %s %s, store %s, carrier %s, pair codes %d", i, s.system, s.mod, s.item_key, hex(s.item), s.store_name, tostring(s.carrier), s.pair_codes))
  end
  SYSTEMS = list
  -- the pair rules of each system read now (the list is opening), not inside the store command later
  for _, s in ipairs(list) do A.PairRules(s.pair_system) end
  return list
end

-- the declared systems in row order (a copy of their data, for other mods)
function CharacterReforged.Create.Systems()
  local out = {}
  for i, s in ipairs(load_systems()) do
    out[i] = { system = s.system, pair_system = s.pair_system, mod = s.mod, item = s.item, store = s.store_name, carrier = s.carrier }
  end
  return out
end

-- ---------------------------------------------------------------------------------------- the flow (commands)

local SNAP = {}

-- (charaHdl) -> n, create item 1 .. n: the board slots remembered (the slot a refusal gives back), the rows to list
function CharacterReforged.Create.Begin(hdl)
  hdl = u32(hdl)
  local list = load_systems()
  if #list == 0 then
    info(string.format("begin %s: no system declared: no create row", hex(hdl)))
    return 0
  end
  local b = A.BoardItems(hdl)
  if not b then
    info(string.format("begin %s: not an owned card: no create row", hex(hdl)))
    return 0
  end
  SNAP[hdl] = b
  local out, names = { #list }, {}
  for _, s in ipairs(list) do
    out[#out + 1] = s.item
    names[#names + 1] = s.system
  end
  info(string.format("begin %s: aura piece list with %d create row(s) (%s), board slots remembered", hex(hdl), #list, table.concat(names, ", ")))
  return table.unpack(out)
end

-- () -> n, create item 1 .. n: the rows of every declared system, nothing remembered (the «Fantasy» skill table's
-- picker: graft character_reforged_board's hook file of evt_skill_slot_menu grants a free copy of each before it opens)
function CharacterReforged.Create.Items()
  local out = { 0 }
  for _, s in ipairs(load_systems()) do out[#out + 1] = s.item end
  out[1] = #out - 1
  return table.unpack(out)
end

-- (item) -> row (0 = not a create item), the system's store command id: the row a picked create item stands for
function CharacterReforged.Create.Row(item)
  item = u32(item)
  for i, s in ipairs(load_systems()) do
    if s.item == item then
      info(string.format("row of %s: %d (%s, store %s)", hex(item), i, s.system, s.store_name))
      return i, s.store, s.scene == true
    end
  end
  return 0, 0, false
end

-- (charaHdl) -> row (0 = no create item was picked), board slot, store command id
function CharacterReforged.Create.Picked(hdl)
  hdl = u32(hdl)
  local list = load_systems()
  local now, before = A.BoardItems(hdl), SNAP[hdl]
  if not now then return 0, -1, 0 end
  local function row_of(item)
    for i, s in ipairs(list) do
      if s.item == item then return i end
    end
    return 0
  end
  -- a slot that changed while the list was open and now holds a create item (the one just picked)
  for slot = 0, 8 do
    local cur = now[slot]
    local prev = before and before[slot] or nil
    if cur and cur.inv ~= 0 and (not prev or prev.inv ~= cur.inv) then
      local i = row_of(cur.item)
      if i > 0 then
        info(string.format("picked %s: row %d (%s) on board slot %d", hex(hdl), i, list[i].system, slot))
        return i, slot, list[i].store
      end
    end
  end
  -- nothing changed: a create item placed earlier (the list kept it, e.g. a slot that held nothing before)
  if before then
    for i, s in ipairs(list) do
      local slot = A.BoardSlotOf(hdl, s.item)
      if slot >= 0 and before[slot] and before[slot].item ~= s.item then
        info(string.format("picked %s: row %d (%s) on board slot %d", hex(hdl), i, s.system, slot))
        return i, slot, s.store
      end
    end
  end
  SNAP[hdl] = nil
  info(string.format("picked %s: no create row picked (the list closed with another aura or none)", hex(hdl)))
  return 0, -1, 0
end

-- (row, k) -> the carrier item id of that system (k: the store's carrier index, «{k}» in the declared key)
function CharacterReforged.Create.Carrier(i, k)
  local s = load_systems()[math.floor(tonumber(i) or 0)]
  if not s then return 0 end
  local c = s.carrier
  if type(c) == "string" then c = c:gsub("{k}", tostring(math.floor(tonumber(k) or 0))) end
  local id = id_of(c)
  info(string.format("carrier of row %d (%s), k %s: %s %s", i, s.system, tostring(k), tostring(c), hex(id)))
  return id
end

-- (charaHdl, slot, inv) -> ok: the carrier on the board slot (the game's own placement)
function CharacterReforged.Create.Place(hdl, slot, inv)
  hdl = u32(hdl)
  local ok, why = A.BoardPlace(hdl, slot, inv)
  info(string.format("place %s slot %s: carrier inv %s %s", hex(hdl), tostring(slot), hex(inv), ok and "placed" or ("NOT placed (" .. tostring(why) .. ")")))
  if ok then SNAP[hdl] = nil end
  return ok == true
end

-- (charaHdl, slot) -> ok: the slot gets back what it held before the aura list (a refused or cancelled creation)
function CharacterReforged.Create.Restore(hdl, slot)
  hdl, slot = u32(hdl), math.floor(tonumber(slot) or -1)
  local prev = SNAP[hdl] and SNAP[hdl][slot]
  SNAP[hdl] = nil
  if not prev or u32(prev.inv) == 0 then
    info(string.format("restore %s slot %d: it held nothing before: the create item stays (a carrier without a pair keeps him himself)", hex(hdl), slot))
    return false
  end
  local ok, why = A.BoardPlace(hdl, slot, u32(prev.inv))
  info(string.format("restore %s slot %d: %s back (%s)", hex(hdl), slot, hex(prev.item), ok and "ok" or tostring(why)))
  return ok == true
end

local function text_of(key)
  local ok, s = pcall(VRFW.text, key)
  if ok and type(s) == "string" then return s end
  return ""
end

-- the most partner moves a pair carries (the framework's miximax keeps 1 or 2)
local MAX_MOVES = 2

-- (row) -> n (partner moves to pick in the bank, 0 = none), confirmId, confirmText, confirmIcon, previewCommand: the
-- system's pairing rule `moves`, the text of the bank's confirmation (id for the game's own lookup, the text as the
-- fallback), the sprite between the two cards of that window (crc32 of `confirm_icon`, 0 = none) and the command id of
-- its stat preview (crc32 of `preview`, 0 = none)
function CharacterReforged.Create.Moves(i)
  local s = load_systems()[math.floor(tonumber(i) or 0)]
  if not s then return 0, 0, "", 0, 0 end
  local n = math.floor(tonumber(A.PairRules(s.pair_system).moves) or 0)
  n = math.max(0, math.min(MAX_MOVES, n))
  local key = s.confirm or (MOD .. ".create_confirm")
  info(string.format("moves of row %s (%s): %d, confirmation %s", tostring(i), s.system, n, key))
  return n, id_of(key), text_of(key), id_of(s.confirm_icon), id_of(s.preview)
end

-- (row, code) -> labelId, reasonId, labelText, reasonText: the refusal window's two texts (ids for the game's own text
-- lookup in its language; the texts as the framework's fallback). code 0 = no window (0, 0, "", "").
function CharacterReforged.Create.Refusal(i, code)
  local s = load_systems()[math.floor(tonumber(i) or 0)]
  code = math.floor(tonumber(code) or -1)
  if code == 0 then return 0, 0, "", "" end
  local reason
  if code == PLACE_FAILED then
    reason = MOD .. ".create_refused_place"
  elseif s and s.refusals[tostring(code)] then
    reason = tostring(s.refusals[tostring(code)])
  elseif s and s.pair_codes >= 0 and code > s.pair_codes and code <= s.pair_codes + 9 then
    reason = string.format("%s.create_refused_%d", MOD, code - s.pair_codes)
  else
    reason = MOD .. ".create_refused_other"
  end
  local label = s and s.label or nil
  local label_id = label and id_of(label) or 0
  local label_text = label and text_of(label) or ""
  info(string.format("refusal row %s (%s): code %d -> %s (window: «%s» / «%s»)", tostring(i), s and s.system or "?", code, reason, label_text, text_of(reason)))
  return label_id, id_of(reason), label_text, text_of(reason)
end

-- (step, values…): one loader.log line per step of the graft (the first in-game run confirms the path)
function CharacterReforged.Create.Log(step, ...)
  local parts = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "number" and v == math.floor(v) and (v > 0xFFFF or v < 0) then
      parts[#parts + 1] = hex(v)
    else
      parts[#parts + 1] = tostring(v)
    end
  end
  info(string.format("board %s: %s", tostring(step), table.concat(parts, " ")))
  return true
end

-- the systems are read again after a hot reload of the mods' files
VRFW.on("game_reset", function()
  SYSTEMS = nil
  SNAP = {}
end)

return K
