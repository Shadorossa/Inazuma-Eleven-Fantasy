-- Character Reforged › the skill board writes of the skill table's AURA SLOT (board slot 8: a keshin / totem / armour)
-- when Inazuma Fantasy's board service (CMND_EVT_BOARD_*, IF's scripts\board.lua) is not there (owner 2026-10-14: the
-- aura half of the «Fantasy» table did nothing without IF). Commands (content\game\board.toml), the same arguments and
-- answers as IF's, so the table's code calls either one:
--
--   CMND_CHARACTERREFORGED_BOARD_PIECE(charaStHdl, boardSlot)            -> piece, effectiveInv, placedInv, nativeInv
--   CMND_CHARACTERREFORGED_BOARD_PLACE(charaStHdl, invHdl, boardSlot)    -> status, effectiveInv (opens a closed piece)
--   CMND_CHARACTERREFORGED_BOARD_CLEAR(charaStHdl, boardSlot[, keepOpen]) -> status, effectiveInv (keepOpen 0: a slot
--                                                                          without a native item is not emptied (-6);
--                                                                          1: emptied, stays open; 3: the native item
--                                                                          off too, open and empty)
--
-- Status: 1 done and verified, 0 refused by the game's CanEquip (no free copy / a duplicate rule such as True
-- Hissatsu's), 2 read back different, -1 bad arguments, -2 not ready, -3 closed without a definition piece, -4 the
-- game call raised, -5 no record, -6 would close the piece. Only the game's own board functions are used (CanEquip,
-- PlaceByHandle, the board definition); nothing else of the board (layout, branch, list) is touched: the table's
-- rows stay the projection of the list (scripts\mix_slots.lua).
--
-- The aura slot on every card (owner 2026-10-16): a card whose board definition has no ninth skill piece (an explicit
-- hero / legend board with 6 pieces: PLACE answered -3) gets a free aura slot by rule: board slot 8's piece byte is
-- opened with an effect index his board does not use, and the item goes straight on the slot through Board.EquipSlot
-- 0xE7AA10 (PlaceByHandle maps a piece to a slot through the definition, so it can not reach that slot). His own
-- pieces are untouched; the slot is open at once, as the definition's own aura piece is when PLACE opens it.
--
-- Record rec8 = VRFW.chara.record(hdl).addr: +0x94 + 4*slot placed item, +0xC8 + 4*slot native item, +0x165 + slot
-- piece effect index (byte; >= 0x80 closed). docs/game/ui/skill-board-original.md.

CharacterReforged = CharacterReforged or {}
CharacterReforged.BoardSlots = CharacterReforged.BoardSlots or {}
local BoardSlots = CharacterReforged.BoardSlots

local STATUS_OK, STATUS_REFUSED, STATUS_MISMATCH = 1, 0, 2
local STATUS_BAD_ARGUMENTS, STATUS_NOT_READY, STATUS_CLOSED, STATUS_EXCEPTION, STATUS_NO_RECORD = -1, -2, -3, -4, -5
local STATUS_WOULD_CLOSE = -6
local OFFSET_PIECES, OFFSET_PLACED, OFFSET_NATIVE = 0x165, 0x94, 0xC8
local LAST_SLOT = 8

local handle_buffer, pieces_buffer = nil, nil

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end
local function hex(v) return string.format("0x%08X", u32(v)) end
local function info(...) VRFW.log("board slots:", ...) end
local function warn(...) VRFW.warn("board slots:", ...) end

local function read(ty, address)
  local ok, v = pcall(VRFW.mem.read, ty, address)
  if ok then return v end
  return nil
end

local function buffers()
  handle_buffer = handle_buffer or VRFW.mem.buffer("character_reforged_board_slots_handle", 8)
  pieces_buffer = pieces_buffer or VRFW.mem.buffer("character_reforged_board_slots_pieces", 16)
end

local function slot_argument(v)
  local s = tonumber(v)
  if s == nil then return nil end
  s = math.floor(s)
  if s >= 0 and s <= LAST_SLOT then return s end
  return nil
end

-- the character data (record + 8) of a handle, or nil + status
local function character_data(hdl)
  if hdl == 0 then return nil, STATUS_BAD_ARGUMENTS end
  local ok, r = pcall(VRFW.chara.record, hdl)
  if not ok then return nil, STATUS_EXCEPTION end
  if type(r) ~= "table" or not r.addr or r.addr < 0x10000 then return nil, STATUS_NO_RECORD end
  return r.addr
end

local function read_slot(data, slot)
  local piece = read("u8", data + OFFSET_PIECES + slot)
  local placed = read("u32", data + OFFSET_PLACED + slot * 4)
  local native = read("u32", data + OFFSET_NATIVE + slot * 4)
  if piece == nil or placed == nil or native == nil then return nil end
  return { piece = piece, placed = u32(placed), native = u32(native) }
end

local function is_closed(s) return s.piece >= 0x80 end
local function effective(s) if s.placed ~= 0 then return s.placed end return s.native end

-- the board definition: { [slot] = piece } of its skill pieces and their count (.n), nil when unreadable
local function definition(hdl)
  buffers()
  pcall(VRFW.mem.write, "u32", handle_buffer, hdl)
  pcall(VRFW.mem.write, "u64", pieces_buffer, 0)
  pcall(VRFW.mem.write, "u64", pieces_buffer + 8, 0)
  local ok = pcall(VRFW.call, "CharacterReforged.BoardSkillPieces", pieces_buffer, handle_buffer)
  if not ok then return nil end
  local list, count = read("ptr", pieces_buffer), read("u64", pieces_buffer + 8)
  if not list or not count or list < 0x10000 or count > 16 then return nil end
  local def = { n = count }
  for k = 0, count - 1 do
    local p = read("u8", list + k * 2)
    if p == nil then return nil end
    def[k] = p
  end
  return def
end

-- the board definition's piece of a board slot (opens a closed slot), nil when unreadable / none
local function definition_piece(hdl, slot)
  local def = definition(hdl)
  if not def or slot >= def.n then return nil end
  local p = def[slot]
  if p ~= nil and p < 0x80 then return p end
  return nil
end

-- ---------------------------------------------------------------------------------------- the free aura slot
local AURA_SLOT = LAST_SLOT
local LAST_EFFECT = 59                -- openedEffectPieceList holds 60 effects: the free piece stays inside it

-- is `piece` on board slot 8 the free aura piece (not a piece of the card's board definition)?
local function is_free_aura(hdl, slot, piece)
  if slot ~= AURA_SLOT or piece >= 0x80 then return false end
  local def = definition(hdl)
  if not def or def.n > AURA_SLOT then return false end
  for k = 0, def.n - 1 do
    if def[k] == piece then return false end
  end
  return true
end

-- an effect index neither the definition nor the other save bytes use, nil when the board has an aura piece or no room
local function free_aura_piece(data, hdl)
  local def = definition(hdl)
  if not def or def.n > AURA_SLOT then return nil end
  local used = {}
  for k = 0, def.n - 1 do used[def[k]] = true end
  for k = 0, LAST_SLOT do
    local b = read("u8", data + OFFSET_PIECES + k)
    if b ~= nil then used[b] = true end
  end
  for p = LAST_EFFECT, 0, -1 do
    if not used[p] then return p end
  end
  return nil
end

-- Board.EquipSlot(hdl, inv, slot, native): the item on the slot itself (the old one's use given back)
local function equip_slot(hdl, inv, slot, native)
  local ok, e = pcall(VRFW.call, "CharacterReforged.BoardEquipSlot", hdl, inv, slot, native and 1 or 0)
  if not ok then
    warn(string.format("EquipSlot(%s, %s, slot %d, native %s) raised: %s", hex(hdl), hex(inv), slot, tostring(native), tostring(e)))
    return STATUS_EXCEPTION
  end
  return nil
end

local function place_by_handle(hdl, piece, inv, native)
  buffers()
  pcall(VRFW.mem.write, "u32", handle_buffer, hdl)
  local ok, e = pcall(VRFW.call, "CharacterReforged.BoardPlaceByHandle", handle_buffer, piece, inv, native and 1 or 0, 1)
  if not ok then
    warn(string.format("PlaceByHandle(%s, piece %d, %s, native %s) raised: %s", hex(hdl), piece, hex(inv), tostring(native), tostring(e)))
    return STATUS_EXCEPTION
  end
  return nil
end

local function put(data, hdl, inv, slot)
  local before = read_slot(data, slot)
  if not before then return STATUS_NOT_READY, 0 end
  local piece = before.piece
  local free = not is_closed(before) and is_free_aura(hdl, slot, piece)
  if is_closed(before) then
    piece = definition_piece(hdl, slot)
    if not piece and slot == AURA_SLOT then
      piece = free_aura_piece(data, hdl)
      free = piece ~= nil
    end
    if not piece then return STATUS_CLOSED, effective(before) end
  end
  local okc, can = pcall(VRFW.call, "CharacterReforged.BoardCanEquip", hdl, inv, 1, 1, slot)
  if not okc then return STATUS_EXCEPTION, effective(before) end
  if (tonumber(can) or 0) % 256 == 0 then return STATUS_REFUSED, effective(before) end
  local st
  if free then
    if is_closed(before) then
      pcall(VRFW.mem.write, "u8", data + OFFSET_PIECES + slot, piece)
      info(string.format("aura slot of %s opened with the free piece %d (his board has no aura piece)", hex(hdl), piece))
    end
    st = equip_slot(hdl, inv, slot, false)
  else
    st = place_by_handle(hdl, piece, inv, false)
  end
  if st then return st, effective(before) end
  local after = read_slot(data, slot)
  if not after then return STATUS_NOT_READY, 0 end
  local ok = not is_closed(after) and effective(after) == inv
  if not ok then
    warn(string.format("slot %d after the write: piece %d placed %s native %s (wanted %s)", slot, after.piece, hex(after.placed), hex(after.native), hex(inv)))
  end
  return ok and STATUS_OK or STATUS_MISMATCH, effective(after)
end

-- keep_open: the slot ends open even without a native item; drop_native: the native item is taken off too
local function clear(data, hdl, slot, keep_open, drop_native)
  local before = read_slot(data, slot)
  if not before then return STATUS_NOT_READY, 0 end
  if is_closed(before) then return STATUS_CLOSED, effective(before) end
  local piece = before.piece
  if is_free_aura(hdl, slot, piece) then
    -- the free aura piece: the slot itself is emptied; the piece stays open (no native item to fall back to)
    if drop_native and before.native ~= 0 then
      local st = equip_slot(hdl, 0, slot, true)
      if st then return st, effective(before) end
    end
    if before.placed ~= 0 then
      local st = equip_slot(hdl, 0, slot, false)
      if st then return st, effective(before) end
    end
    local after = read_slot(data, slot)
    if not after then return STATUS_NOT_READY, 0 end
    local ok = after.placed == 0 and (not drop_native or after.native == 0)
    return ok and STATUS_OK or STATUS_MISMATCH, effective(after)
  end
  if drop_native and before.native ~= 0 then
    local st = place_by_handle(hdl, piece, 0, true)
    if st then return st, effective(before) end
    local now = read_slot(data, slot)
    if not now then return STATUS_NOT_READY, 0 end
    if is_closed(now) then pcall(VRFW.mem.write, "u8", data + OFFSET_PIECES + slot, piece) end
    before = read_slot(data, slot) or now
    keep_open = true
  end
  if before.placed == 0 then return STATUS_OK, effective(before) end
  if before.native == 0 and not keep_open then return STATUS_WOULD_CLOSE, effective(before) end
  local st = place_by_handle(hdl, piece, 0, false)
  if st then return st, effective(before) end
  local after = read_slot(data, slot)
  if not after then return STATUS_NOT_READY, 0 end
  if is_closed(after) and keep_open and after.placed == 0 and after.native == 0 then
    pcall(VRFW.mem.write, "u8", data + OFFSET_PIECES + slot, piece)
    after = read_slot(data, slot) or after
  end
  local ok = after.placed == 0 and not is_closed(after)
  return ok and STATUS_OK or STATUS_MISMATCH, effective(after)
end

function BoardSlots.Piece(hdl, slot)
  hdl, slot = u32(hdl), slot_argument(slot)
  if slot == nil then return STATUS_BAD_ARGUMENTS, 0, 0, 0 end
  local data, st = character_data(hdl)
  if not data then return st, 0, 0, 0 end
  local s = read_slot(data, slot)
  if not s then return STATUS_NOT_READY, 0, 0, 0 end
  return s.piece, effective(s), s.placed, s.native
end

function BoardSlots.Place(hdl, inv, slot)
  hdl, inv, slot = u32(hdl), u32(inv), slot_argument(slot)
  local st, now = STATUS_BAD_ARGUMENTS, 0
  if slot ~= nil and inv ~= 0 then
    local data, why = character_data(hdl)
    if data then
      st, now = put(data, hdl, inv, slot)
    else
      st = why
    end
  end
  info(string.format("PLACE(%s, inv %s, slot %s) -> status %d, slot item %s", hex(hdl), hex(inv), tostring(slot), st, hex(now)))
  return st, now
end

function BoardSlots.Clear(hdl, slot, mode)
  hdl, slot, mode = u32(hdl), slot_argument(slot), math.floor(tonumber(mode) or 0)
  local st, now = STATUS_BAD_ARGUMENTS, 0
  if slot ~= nil then
    local data, why = character_data(hdl)
    if data then
      st, now = clear(data, hdl, slot, mode ~= 0, mode == 3)
    else
      st = why
    end
  end
  info(string.format("CLEAR(%s, slot %s, keepOpen %d) -> status %d, slot item %s", hex(hdl), tostring(slot), mode, st, hex(now)))
  return st, now
end

