-- Battle Bay Deluxe: the champions' celebration when the player wins a competition (the Torneo, the Liga, the Campaña,
-- the Reto diario). One function for every competition: each caller only decides whether the finished match wins its
-- competition (its own rule) and calls Trophy.play.
--
-- The game's own end of the Victory Road final (docs/game/mods/bbd-tournament-celebration.md §7): bit 24 of the match's
-- rule word ([[g_gameRoot]+Game.RootMatch]+0) makes the full-time state ResultEventState go to TournamentFinalGameEnd
-- (soccer state 0x1C) instead of the result menu: the trophy lift ev72_00050 with the winning side's players in the
-- match's stadium, then the photo scene (victory_road_final_game_*_photo_menu), then the normal result menu and the
-- mode's own flow. ResultEventState reads the bit at its last step; it is written here from the game's own result
-- (VRFW signal vrfw.match_result, published by the result builder at the state's step 3, before the result music and
-- that last step), so the Victory Road mode is never started and the bit lives in this match only (the next match
-- builds its rule word again). Only on a won match: the scene casts the winning side, so it is always the player's
-- team (his line-up, kit and crest).

local U = require "lib/util"

local Trophy = {}

-- the rule word's tournament-final end (ResultEventState v7.2.1 0x1452A20 step 0x14: next state 0x1C when set)
local RULE_TOURNAMENT_FINAL_END = 0x1000000

-- the competitions and the text key of the name the photo scene's tournament plate shows
local COMPETITION_NAMES = {
  tournament = "evt_bbd_tn_mode_tournament",
  league = "evt_bbd_tn_mode_league",
  campaign = "evt_bbd_tn_mode_campaign",
  daily_challenge = "evt_bbd_dc_daily",
}

-- the celebration of the match being finished: { competition, name } (nil = none); cleared at the next match
local CURRENT = nil

require "VRFW/lib/basics"
local info, warn = VRFW.logger("trophy celebration")

-- the game's own result of the finished match (VRFW MatchResult.last), nil when none was published
function Trophy.last_result()
  local MR = rawget(_G, "MatchResult")
  local last = MR and MR.last
  if type(last) == "table" then
    return last
  end
  return nil
end

-- the rival team of the match being played (the match setup's team record of the side that is not the user's), 0 when
-- not readable
function Trophy.rival_team()
  local mi, party = U.global("trophy_match"), U.global("trophy_party")
  local user = mi and U.rd("u8", mi + 0x2C29)
  if not party or not user or user > 1 then
    return 0
  end
  return U.u32(U.rd("u32", party + 0x1E0 + (1 - user) * 0x4A8) or 0)
end

-- the finished match wins `competition` (one of COMPETITION_NAMES): the champions' celebration plays after its full time
-- when the player won the match. `result` = the game's own result (MatchResult.last). true when the celebration is set.
function Trophy.play(competition, result)
  if not COMPETITION_NAMES[competition] then
    warn("unknown competition " .. tostring(competition) .. ": no celebration")
    return false
  end
  if type(result) ~= "table" or result.outcome ~= "win" then
    info(string.format("%s decided without a won match (%s): no celebration", competition,
      type(result) == "table" and tostring(result.outcome) or "no result"))
    return false
  end
  local mi = U.global("trophy_match")
  local old = mi and U.rd("u32", mi)
  if not old then
    warn(competition .. " won, but the match's rule word is not readable: no celebration")
    return false
  end
  local new = bit32.bor(old, RULE_TOURNAMENT_FINAL_END)
  if new ~= old and not U.wr("u32", mi, new) then
    warn(string.format("%s won, but the rule word 0x%08X was not written: no celebration", competition, old))
    return false
  end
  CURRENT = { competition = competition, name = COMPETITION_NAMES[competition] }
  info(string.format("%s won %d-%d: rule word 0x%08X -> 0x%08X (trophy lift, photo, then the result screen)",
    competition, U.int(result.score_for, 0), U.int(result.score_against, 0), old, new))
  return true
end

-- the celebration being shown (the photo scene's patch asks): { competition, name } or nil
function Trophy.current()
  return CURRENT
end

VRFW.on("match_start", function()
  CURRENT = nil
  return nil
end)

-- another mod's competition won by the finished match (that mod's own rule decided it, from vrfw.match_result): the
-- signal BattleBayDeluxe.TrophyPlay plays the celebration, with the Torneo's name on the photo's plate
VRFW.on("signal:BattleBayDeluxe.TrophyPlay", function()
  Trophy.play("tournament", Trophy.last_result())
  return nil
end)

VRFW.on("game_reset", function()
  CURRENT = nil
  return nil
end)

-- CMND_BBD_TROPHY_INFO -> table { active, competition, name (the text key of the competition's name), name_id (its
-- crc32, as CMND_TEXT_GET takes it) }
function BattleBayDeluxe.TrophyInfo()
  local c = CURRENT
  if not c then
    return { active = false }
  end
  return { active = true, competition = c.competition, name = c.name, name_id = U.crc32(c.name) }
end

return Trophy
