-- Battle Bay Deluxe: the Battle Bay campaign block of the session (docs/game/modes/estadio-bb.md §3.2) lent to a mode
-- for its matches. The game's own campaign match (match request, stadium, loading telop, result screen) plays what the
-- block holds: +0x2CA6E4 game, +0x2CA6E8 difficulty, +0x2CA6EC player team, +0x2CA6F0 the 7 rivals, +0x2CA70C the
-- match index. After a win the game adds 1 to the index (index 6 won = the campaign clear), after a loss or a draw it
-- zeroes the block. The block belongs to the Campaña: a mode that borrows it first keeps the Campaña's fields in a save
-- blob of the slot (`snapshot_blob`) and writes them back after its match, byte for byte.
-- Needs the [[VRFW.Global]] `session` (content\game\campaign.toml) in the command's `needs`.

local U = require "lib/util"

local B = {}

local S_GAME, S_DIFF, S_PLAYER, S_RIVALS, S_INDEX, S_CLEARS = 0x2CA6E4, 0x2CA6E8, 0x2CA6EC, 0x2CA6F0, 0x2CA70C, 0x208
B.RIVALS = 7

require "VRFW/lib/basics"
local info, warn = VRFW.logger("campaign block")

function B.slot()
  local ok, n = pcall(VRFW.slots.active)
  if ok and type(n) == "number" and n ~= 0 then
    return math.floor(n)
  end
  return 1
end

function B.session()
  return U.global("session")
end

-- the block now: { game, diff, player, index, clears, rivals[1..7] }; nil when the session is not readable
function B.read()
  local s = B.session()
  if not s then
    return nil
  end
  local r = {
    game = U.rd("u32", s + S_GAME), diff = U.rd("u8", s + S_DIFF), player = U.rd("u32", s + S_PLAYER),
    index = U.rd("u8", s + S_INDEX), clears = U.rd("u32", s + S_CLEARS), rivals = {},
  }
  for i = 0, B.RIVALS - 1 do
    r.rivals[i + 1] = U.rd("u32", s + S_RIVALS + 4 * i) or 0
  end
  return r
end

-- write the block: game, difficulty byte, player team, rivals (1-based list, the rest 0), match index; true when
-- every field was written
function B.write(game, diff, player, rivals, index)
  local s = B.session()
  if not s then
    return false
  end
  local ok = U.wr("u32", s + S_GAME, U.u32(game)) and U.wr("u8", s + S_DIFF, diff)
    and U.wr("u32", s + S_PLAYER, U.u32(player))
  for i = 0, B.RIVALS - 1 do
    ok = ok and U.wr("u32", s + S_RIVALS + 4 * i, U.u32(rivals[i + 1] or 0))
  end
  return ok and U.wr("u8", s + S_INDEX, index)
end

-- the Campaña's fields kept in the save blob `blob` of the slot; false when not written (then the block is not lent)
function B.snapshot(blob)
  local b = B.read()
  if not b then
    return false
  end
  local doc = { v = 1, game = b.game or 0, diff = b.diff or 0, player = b.player or 0, index = b.index or 0,
    clears = b.clears or 0, rivals = {} }
  for i = 1, B.RIVALS do
    doc.rivals[i] = b.rivals[i] or 0
  end
  local ok, done, why = pcall(VRFW.save.blob_write, blob, VRFW.json.encode(doc), B.slot())
  if not (ok and done) then
    warn(blob .. " not written (" .. tostring(ok and why or done) .. "): the Campaña's block is not lent")
    return false
  end
  info(string.format("Campaña block kept in %s (player %s, rival 1 %s, index %d)", blob, U.hex(doc.player),
    U.hex(doc.rivals[1]), doc.index))
  return true
end

-- whether the slot has a kept Campaña block in `blob`
function B.has_snapshot(blob)
  local ok, b = pcall(VRFW.save.blob, blob, B.slot())
  return ok and type(b) == "string"
end

-- the Campaña's fields of `blob` written back and the blob put aside; true when there was one and it was written
function B.restore(blob)
  local ok, raw = pcall(VRFW.save.blob, blob, B.slot())
  if not (ok and type(raw) == "string") then
    return false
  end
  local doc = VRFW.json.decode(raw)
  if type(doc) ~= "table" or type(doc.rivals) ~= "table" then
    warn(blob .. " unreadable: the Campaña's block stays as it is")
    return false
  end
  local before = B.read()
  if not B.write(doc.game, doc.diff, doc.player, doc.rivals, doc.index) then
    warn("the Campaña's block was not written back (kept in " .. blob .. ")")
    return false
  end
  if before and doc.clears and before.clears ~= doc.clears then
    warn(string.format("the campaign clear counter changed while the block was lent (%d -> %d)", doc.clears,
      before.clears))
  end
  pcall(VRFW.save.blob_aside, blob, B.slot())
  info(string.format("Campaña block back from %s (player %s, rival 1 %s, index %d)", blob, U.hex(U.u32(doc.player)),
    U.hex(U.u32(doc.rivals[1])), doc.index))
  return true
end

return B
