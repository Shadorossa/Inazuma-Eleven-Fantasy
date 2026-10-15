-- BetterUI › duel readout: the totals the game compared in a special-move / power-action duel (content\game\
-- duel_readout.toml). The mid hook DuelClashResult runs when the resolver posts its result; the last result is kept
-- here and handed to the match HUD (graft clean_hud_duel_readout) through CMND_BETTERUI_DUEL_READOUT. Nothing runs at
-- load but the handler registration.

local KIND_SPECIAL_MOVE = 5
local KIND_POWER_ACTION = 6
local RESULT_BLOCK_FROM_RBP = 0x30   -- the result block is at rbp - 0x30 at the hook site

local LABEL_DRIBBLE = 1
local LABEL_DEFENSE = 2
local LABEL_POWER_CHARGE = 3
local LABEL_POWER_BLOCK = 4

local FRESH_MS = 3000                -- a result older than this is not shown any more
local last = { sequence = 0, at = 0 }
local logged = 0
local LOG_MAX = 40

local function read_struct(name, address)
  local ok, value = pcall(VRFW.mem.read_struct, name, address)
  if ok and type(value) == "table" then
    return value
  end
  return nil
end

-- the side the player controls, or nil (no player side: a CPU match, the data not readable)
local function user_side()
  local ok, match = pcall(VRFW.game.DuelMatchData)
  if not ok or type(match) ~= "number" or match == 0 then
    return nil
  end
  local sides = read_struct("DuelMatchSides", match)
  if sides == nil or sides.user_side > 1 then
    return nil
  end
  return sides.user_side
end

local function label_of(is_offense, power_action)
  if is_offense then
    return power_action and LABEL_POWER_CHARGE or LABEL_DRIBBLE
  end
  return power_action and LABEL_POWER_BLOCK or LABEL_DEFENSE
end

VRFW.on("hook:DuelClashResult", function(ev)
  local regs = ev and ev.regs
  if type(regs) ~= "table" or type(regs.rbp) ~= "number" or type(regs.r13) ~= "number" then
    return nil
  end
  local result = read_struct("ClashResultBlock", regs.rbp - RESULT_BLOCK_FROM_RBP)
  if result == nil or (result.kind ~= KIND_SPECIAL_MOVE and result.kind ~= KIND_POWER_ACTION) then
    return nil
  end
  -- both sides must have used something (a special move or a power action): a side with no command has power 0
  if result.winner_side > 1 or result.winner_power <= 0 or result.loser_power <= 0 then
    return nil
  end
  local duel = read_struct("FocusDuel", regs.r13)
  if duel == nil or duel.offense_side > 1 then
    return nil
  end
  local power = {}
  power[result.winner_side] = result.winner_power
  power[1 - result.winner_side] = result.loser_power
  local power_action = { [0] = duel.power_action_side0 ~= 0, [1] = duel.power_action_side1 ~= 0 }
  local left = user_side() or duel.offense_side
  local right = 1 - left
  last = {
    sequence = last.sequence + 1,
    at = VRFW.now(),
    left_power = power[left],
    left_label = label_of(left == duel.offense_side, power_action[left]),
    right_power = power[right],
    right_label = label_of(right == duel.offense_side, power_action[right]),
  }
  if logged < LOG_MAX then
    logged = logged + 1
    VRFW.log(string.format("duel readout #%d: kind %d, offense side %d, winner side %d; left (side %d) %d label %d vs right %d label %d",
      last.sequence, result.kind, duel.offense_side, result.winner_side, left, last.left_power, last.left_label,
      last.right_power, last.right_label))
  end
  return nil
end)

-- CMND_BETTERUI_DUEL_READOUT(seen) -> sequence, left power, left label, right power, right label; 0 when the last
-- result is not newer than `seen` or older than FRESH_MS. seen < 0: only the current sequence (the HUD syncs to it when
-- it opens, so a result of an earlier match is never shown).
function BetterUI.DuelReadout(seen)
  if type(seen) ~= "number" then
    return 0
  end
  if seen < 0 then
    return last.sequence
  end
  if last.sequence <= seen or VRFW.now() - last.at > FRESH_MS then
    return 0
  end
  return last.sequence, last.left_power, last.left_label, last.right_power, last.right_label
end
