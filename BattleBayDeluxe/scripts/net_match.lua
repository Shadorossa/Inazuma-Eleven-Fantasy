-- Battle Bay Deluxe: the match of a «Sala privada» (docs/game/modes/bb-p2p-lockstep.md §7). Each PC plays the room's
-- match as a LOCAL offline Battle Bay match; the VR-Framework's lockstep carries the two players' inputs. Both PCs ask
-- the same match: the host's team as the player's side (team 0), the guest's team as the rival (team 1), through the
-- game's own Campaña «continue» (the block of the session borrowed for one match, as the Torneo does:
-- tournament.lua). The room screen's graft (research/grafts/bb_net_room) calls the commands of content\game\net_match.toml:
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_BBD_NET_PICK_ARM | 1 / 0 | true: the next team decide in the Battle Bay grid is this player's room pick (the decide itself does not run) |
-- | CMND_BBD_NET_PICKED | - | the team hash the armed pick took (0 = none yet) |
-- | CMND_BBD_NET_PREPARE | host team, guest team | true / false: the Campaña's block kept (save blob bb_net_campaign.json) and the room's match written into it |
-- | CMND_BBD_NET_RESTORE | - | true when a kept Campaña block was written back |
-- | CMND_BBD_NET_TEAM | team | leader chara, emblem 0, level (the room screen's team frame) |
--
-- Config: config.toml [net] game (the soccer game of the match: the Campaña's), difficulty (0-3).

local U = require "lib/util"
local G = require "lib/game"

local N = {}

local S_GAME, S_DIFF, S_PLAYER, S_RIVALS, S_INDEX = 0x2CA6E4, 0x2CA6E8, 0x2CA6EC, 0x2CA6F0, 0x2CA70C
local BLOB = "bb_net_campaign.json"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("net")

local CFG = {
  game = U.u32(tonumber(U.config("net.game", 0x8F85B173)) or 0x8F85B173),
  difficulty = math.max(0, math.min(3, U.int(tonumber(U.config("net.difficulty", 1)), 1))),
}

local function current_slot()
  local ok, n = pcall(VRFW.slots.active)
  if ok and type(n) == "number" and n ~= 0 then
    return math.floor(n)
  end
  return 1
end

local function session()
  return U.global("session")
end

-- ------------------------------------------------------------------------------------------------ the room pick

local PICK = { armed = false, team = 0 }

function BattleBayDeluxe.NetPickArm(on)
  PICK.armed = U.int(on, 0) ~= 0
  if PICK.armed then
    PICK.team = 0
  end
  info("room pick " .. (PICK.armed and "armed" or "off"))
  return true
end

function BattleBayDeluxe.NetPicked()
  return PICK.team
end

-- campaign.lua's Decide pre-phase: an armed pick takes the decided tile's team for the room (VRFW.net.pick) and the
-- game's decide does not run; nil = not a room pick
function N.decide(menu, btn, idx)
  if not PICK.armed or U.rd("u32", btn) ~= G.GRID_LAYER then
    return nil
  end
  local s = U.struct("GridSlot", G.slot_addr(menu, idx))
  local team, unlocked = U.get(s, "team"), U.get(s, "unlocked")
  if not team or team == 0 or unlocked == 0 then
    info("room pick: slot " .. tostring(idx) .. " has no playable team")
    return { skip = true, ret = 0 }
  end
  local ok, r = pcall(VRFW.net.pick, team)
  if not ok or type(r) ~= "table" or not r.ok then
    warn("room pick: not sent (" .. tostring(ok and r and r.error or r) .. ")")
    return { skip = true, ret = 0 }
  end
  PICK.team, PICK.armed = team, false
  info("room pick: " .. U.hex(team) .. " (slot " .. tostring(idx) .. ")")
  return { skip = true, ret = 0 }
end

-- ------------------------------------------------------------------------------------------------ the match

local function block_state(s)
  local r = { game = U.rd("u32", s + S_GAME), diff = U.rd("u8", s + S_DIFF), player = U.rd("u32", s + S_PLAYER),
    index = U.rd("u8", s + S_INDEX), rivals = {} }
  for i = 0, 6 do
    r.rivals[i + 1] = U.rd("u32", s + S_RIVALS + 4 * i) or 0
  end
  return r
end

local function kept()
  local ok, b = pcall(VRFW.save.blob, BLOB, current_slot())
  if ok and type(b) == "string" then
    local doc = VRFW.json.decode(b)
    if type(doc) == "table" and type(doc.rivals) == "table" then
      return doc
    end
  end
  return nil
end

function BattleBayDeluxe.NetRestore()
  local doc = kept()
  local s = session()
  if not doc or not s then
    return false
  end
  local ok = U.wr("u32", s + S_GAME, U.u32(doc.game)) and U.wr("u8", s + S_DIFF, doc.diff)
    and U.wr("u32", s + S_PLAYER, U.u32(doc.player)) and U.wr("u8", s + S_INDEX, doc.index)
  for i = 0, 6 do
    ok = ok and U.wr("u32", s + S_RIVALS + 4 * i, U.u32(doc.rivals[i + 1]))
  end
  if not ok then
    warn("the Campaña's block was not written back (kept in " .. BLOB .. ")")
    return false
  end
  pcall(VRFW.save.blob_aside, BLOB, current_slot())
  info("Campaña block back (player " .. U.hex(U.u32(doc.player)) .. ")")
  return true
end

function BattleBayDeluxe.NetPrepare(host_team, guest_team)
  host_team, guest_team = U.u32(host_team), U.u32(guest_team)
  if host_team == 0 or guest_team == 0 then
    warn("match not prepared: a team is missing (host " .. U.hex(host_team) .. ", guest " .. U.hex(guest_team) .. ")")
    return false
  end
  local s = session()
  if not s then
    warn("match not prepared: the session block is not readable")
    return false
  end
  if not kept() then
    local b = block_state(s)
    local doc = { v = 1, game = b.game or 0, diff = b.diff or 0, player = b.player or 0, index = b.index or 0, rivals = {} }
    for i = 1, 7 do
      doc.rivals[i] = b.rivals[i] or 0
    end
    local ok, done, why = pcall(VRFW.save.blob_write, BLOB, VRFW.json.encode(doc), current_slot())
    if not (ok and done) then
      warn(BLOB .. " not written (" .. tostring(ok and why or done) .. "): the match is not prepared")
      return false
    end
  end
  local ok = U.wr("u32", s + S_GAME, CFG.game) and U.wr("u8", s + S_DIFF, CFG.difficulty)
    and U.wr("u32", s + S_PLAYER, host_team)
  for i = 0, 6 do
    ok = ok and U.wr("u32", s + S_RIVALS + 4 * i, i == 0 and guest_team or 0)
  end
  ok = ok and U.wr("u8", s + S_INDEX, 0)
  if not ok then
    warn("the room's match was not written into the Campaña's block")
    BattleBayDeluxe.NetRestore()
    return false
  end
  info(string.format("room match: %s (host, team 0) vs %s (guest, team 1), game %s, difficulty %d", U.hex(host_team),
    U.hex(guest_team), U.hex(CFG.game), CFG.difficulty))
  return true
end

-- the room screen's team frame: the team's Battle Bay leader (its portrait), 0 = no crest of ours, the level 0
function BattleBayDeluxe.NetTeam(team)
  team = U.u32(team)
  if team == 0 then
    return 0, 0, 0
  end
  local rows = G.enjoy_rows and G.enjoy_rows() or nil
  for _, r in ipairs(type(rows) == "table" and rows or {}) do
    if r.team == team then
      local er = U.struct("EnjoyRow", r.addr)
      return U.get(er, "leader") or 0, 0, 0
    end
  end
  return 0, 0, 0
end

-- a room match ended: the Campaña's block back at the next top menu (the result screens still read it now)
VRFW.on("slot_load", function()
  if kept() then
    pcall(BattleBayDeluxe.NetRestore)
  end
  return nil
end)

return N
