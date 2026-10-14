-- Battle Bay Deluxe: the «Active team» tile (1.5.61, owner 2026-10-14: «jugar con tu equipo normal activo»), the first
-- tile of «Equipos principales», right before the Draft. Deciding it plays the player's active team as it is (the team
-- the game uses outside the Battle Bay), with no draft and no team pick. docs/game/modes/estadio-bb.md §16.
--
-- The tile is the team of config.toml [active_team] team (content\teams\51_active_team.toml, placeholder players).
-- The match itself is turned into the game's own «player's team» match natively (content\game\active_team.toml: the
-- hook StartMatchRequest writes 0 = the active VS team over the request's player team when it is this tile's team);
-- this script only:
--   * fills the hook's table BattleBayDeluxe.ActiveTeam with the tile's team id at start;
--   * answers which decides of the grid are allowed (campaign.lua's Decide hook): the tile is the PLAYER's side only
--     (the 1 vs 1's rival pick refuses it: a CPU side would play the placeholders) and never in a network session
--     (the peer builds the other side from the tile's own team);
--   * lets the Campaña / Torneo draws leave it out as a rival (campaign.lua).

local U = require "lib/util"

local A = {}

local TABLE = "BattleBayDeluxe.ActiveTeam"

local function info(...)
  VRFW.log("active team:", ...)
end
local function warn(...)
  VRFW.warn("active team:", ...)
end

local TEAM_NAME = U.trim(tostring(U.config("active_team.team", "active_team")))

-- the key of the [[team]] named `name` in the mod's own team files (content\teams); nil, why when there is none
local function find_key(name)
  local ok, list = pcall(VRFW.files.declarations, "content/teams")
  if not ok or type(list) ~= "table" then
    return nil, "content\\teams not readable"
  end
  for _, e in ipairs(list) do
    local teams = e.mod == VRFW.mod and type(e.data) == "table" and e.data.team
    if type(teams) == "table" then
      for _, t in ipairs(teams) do
        if type(t) == "table" and t.name == name then
          if type(t.key) ~= "string" then
            return nil, tostring(e.file) .. ": the team has no key"
          end
          return t.key
        end
      end
    end
  end
  return nil, 'no [[team]] name = "' .. name .. '" in content\\teams'
end

local KEY, KEY_ERR = find_key(TEAM_NAME)
local TEAM = KEY and U.crc32(KEY) or 0

if TEAM == 0 then
  warn("off (" .. tostring(KEY_ERR) .. "): the Active team tile plays its placeholder players")
elseif not VRFW.is_on("StartMatchRequest") then
  warn(string.format("team %s = %s (%s), but the hook StartMatchRequest is off: the tile would play its placeholder " ..
    "players, so it is refused", TEAM_NAME, KEY, U.hex(TEAM)))
else
  local ok, e = pcall(VRFW.native.table_set, TABLE, TEAM, 1)
  if ok then
    info(string.format("team %s = %s (%s): its matches play the player's active team", TEAM_NAME, KEY, U.hex(TEAM)))
  else
    warn("the hook's table not written (" .. tostring(e) .. "): the tile is refused")
    TEAM = 0
  end
end

-- The tile's team id (0 = none: no declaration).
function A.team()
  return TEAM
end

-- The tile plays the active team (the hook is on and its table holds the tile).
function A.playable()
  return TEAM ~= 0 and VRFW.is_on("StartMatchRequest")
end

-- A decide on the tile: nil = allowed, else why it is refused. `campaign` = the grid is the Campaña's (or the
-- Torneo's), `player_one_decided` = the 1 vs 1's player side is already picked (this decide picks the rival),
-- `network` = IsNetworkSession (nil = unknown).
function A.refusal(campaign, player_one_decided, network)
  if not A.playable() then
    return "the hook StartMatchRequest is off (the tile would play its placeholder players)"
  end
  if network then
    return "network session (the other player builds this side from the tile's own team)"
  end
  if not campaign and player_one_decided then
    return "the rival side (only the player's side plays the active team)"
  end
  return nil
end

return A
