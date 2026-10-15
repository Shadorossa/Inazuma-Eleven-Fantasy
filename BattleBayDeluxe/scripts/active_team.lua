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
--   * lets the Campaña / Torneo draws leave it out as a rival (campaign.lua);
--   * 1.5.64 (owner 2026-10-14: the tile previewed Raimon / Mark Evans, the pre-match talk showed two Mark Evans):
--     CMND_BBD_ACTIVE_TEAM_MIRROR (graft research/grafts/bb_active_team, whenever the grid draws the tile or a Battle
--     Bay hub opens) writes the active team set's line-up over the tile's member rows IN MEMORY (position -> the
--     player's chara_param, as the Draft writes its picks) and its captain as the tile's Battle Bay row leader: the
--     panel, the big portrait, the campaign scene and its pre-match talk speaker show the active team; a place the
--     active team leaves empty gets one of the tile's own placeholders no active player uses;
--   * logs each Battle Bay match request that carries the tile (hook StartMatchRequest): whether the native answer
--     turned it into the active team set (player team 0), and does it when the answer did not;
--   * 1.5.66 (owner 2026-10-15: the VS screen showed another team, the tile's crest and model kit were Raimon's): the
--     mirror also writes the active team's emblem and kit over the tile's team record in memory and publishes the
--     active team set (table BattleBayDeluxe.ActiveSet); the request handler writes the active VS team set into the
--     request's team set byte (+0xC0: the Battle Bay fills it with its own online team set) and sets the level sync
--     of the match (config.toml [active_team] level_sync, table BattleBayDeluxe.LevelSync: the stats level of the
--     active team's players, content\game\active_team.toml MatchStatLevel; their moves stay as they are).

local U = require "lib/util"
local G = require "lib/game"
local Draft = require "draft"

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

-- ------------------------------------------------------------------------------------------------ the mirror

-- the tile's own placeholder of each member place (slot -> chara_param), as first seen this session
local PLACEHOLDER = {}

-- "position:param,…" -> { [position] = param }
local function parse_lineup(text)
  local out = {}
  for pos, param in string.gmatch(tostring(text or ""), "(%d+):(%d+)") do
    local p, id = tonumber(pos), U.u32(tonumber(param))
    if p and id and id ~= 0 then
      out[p] = id
    end
  end
  return out
end

-- the leader the tile's row names: the captain when he is one of the rows, else the player of place 0, else the first
local function leader_of(final, captain)
  local first
  for slot, id in pairs(final) do
    if captain ~= 0 and id == captain then
      return id, "captain"
    end
    if first == nil or slot < first then
      first = slot
    end
  end
  if final[0] then
    return final[0], "place 0"
  end
  return first and final[first], "first place"
end

-- the active VS team set last mirrored (0..15), nil before the first mirror
local ACTIVE_SET = nil

-- the tile's team record in memory (FindTeamConfig), nil + why
local function tile_record()
  if not VRFW.is_on("FindTeamConfig") then
    return nil, "FindTeamConfig not resolved"
  end
  local okb, recb = pcall(VRFW.mem.buffer, "bbd_active_rec", 8)
  local okc, contb = pcall(VRFW.mem.buffer, "bbd_active_cont", 8)
  local okh, hashb = pcall(VRFW.mem.buffer, "bbd_active_hash", 4)
  if not (okb and okc and okh) then
    return nil, "no native buffer"
  end
  U.wr("u64", recb, 0)
  U.wr("u64", contb, 0)
  U.wr("u32", hashb, TEAM)
  local ok, e = U.call("FindTeamConfig", recb, contb, hashb)
  if not ok then
    return nil, "FindTeamConfig faulted (" .. tostring(e) .. ")"
  end
  local rec = U.rd("ptr", recb) or 0
  if rec < 0x10000 then
    return nil, "the tile is not in team_config"
  end
  return rec
end

-- the active team's emblem and kit over the tile's team record (the grid's crest and model read it) -> note
local function write_look(emblem, uniform)
  if emblem == 0 and uniform == 0 then
    return "no emblem / kit to write"
  end
  local rec, why = tile_record()
  local r = rec and U.struct("ActiveTeamRecord", rec)
  if not r then
    warn("mirror: the tile's team record not read: " .. tostring(why or "struct off"))
    return "team record not read"
  end
  local done = {}
  for _, f in ipairs({ { "emblem", emblem }, { "uniform", uniform } }) do
    local field, value = f[1], f[2]
    if value ~= 0 and U.get(r, field) ~= value then
      if pcall(function()
        r[field] = value
      end) then
        done[#done + 1] = field .. " " .. U.hex(value)
      else
        warn("mirror: the tile's " .. field .. " NOT written")
      end
    end
  end
  if #done == 0 then
    return "crest and kit unchanged"
  end
  return table.concat(done, ", ")
end

-- CMND_BBD_ACTIVE_TEAM_MIRROR(captain, lineup[, set, emblem, uniform]): the active team set onto the tile's member
-- rows, row leader and team record (crest, kit). -> ok, what was done (text)
function BattleBayDeluxe.ActiveTeamMirror(captain, lineup, set, emblem, uniform)
  if TEAM == 0 then
    return false, "no Active team tile"
  end
  set = tonumber(set)
  if set and set >= 0 and set < 16 then
    ACTIVE_SET = math.floor(set)
    pcall(VRFW.native.table_set, "BattleBayDeluxe.ActiveSet", 0, ACTIVE_SET)
  end
  local look = write_look(U.u32(tonumber(emblem) or 0) or 0, U.u32(tonumber(uniform) or 0) or 0)
  captain = U.u32(tonumber(captain) or 0) or 0
  local want = parse_lineup(lineup)
  if next(want) == nil then
    return false, "empty line-up"
  end
  local rows, why = Draft.member_rows(TEAM)
  if not rows then
    warn("mirror: the tile's member rows not read: " .. tostring(why))
    return false, "member rows: " .. tostring(why)
  end
  local used = {}
  for _, id in pairs(want) do
    used[id] = true
  end
  for _, r in ipairs(rows) do
    if PLACEHOLDER[r.slot] == nil then
      PLACEHOLDER[r.slot] = r.param
    end
  end
  -- the places the active team leaves empty: a placeholder of the tile no active player uses (never a duplicate)
  local spare = {}
  for _, id in pairs(PLACEHOLDER) do
    if id ~= 0 and not used[id] then
      spare[#spare + 1] = id
    end
  end
  table.sort(spare)
  local final, written, empty = {}, 0, 0
  for _, r in ipairs(rows) do
    local to = want[r.slot]
    if to == nil then
      empty = empty + 1
      to = PLACEHOLDER[r.slot]
      if used[to] then
        to = table.remove(spare, 1) or to
      end
    end
    used[to] = true
    final[r.slot] = to
    if to ~= 0 and (r.param ~= to or r.uid ~= to) then
      if not Draft.write_member(r, to) then
        warn(string.format("mirror: member row of place %d NOT written", r.slot))
        return false, "a member row not written"
      end
      written = written + 1
    end
  end
  local lead, lead_why = leader_of(final, captain)
  local leader_note = "leader unchanged"
  local row = lead and G.enjoy_row(TEAM)
  local er = row and U.struct("EnjoyRow", row)
  if er then
    local old = U.get(er, "leader") or 0
    if old ~= lead then
      if pcall(function()
        er.leader = lead
      end) then
        leader_note = string.format("leader %s -> %s (%s)", U.hex(old), U.hex(lead), lead_why)
      else
        leader_note = "leader NOT written"
        warn("mirror: the tile's row leader NOT written (" .. U.hex(old) .. " stays)")
      end
    end
  elseif lead then
    leader_note = "no Battle Bay row of the tile in memory (leader not written)"
  end
  local note = string.format("%d of %d member rows written, %d place(s) the active team leaves empty, %s, %s, team set %s",
    written, #rows, empty, leader_note, look, tostring(ACTIVE_SET))
  if written > 0 or leader_note ~= "leader unchanged" or look ~= "crest and kit unchanged" then
    info("mirror: the active team onto the tile: " .. note)
  end
  return true, note
end

-- ------------------------------------------------------------------------------------------------ the match request

-- StartMatchRequest(scene, request): +0xA0 (u8) 1 = the Battle Bay's explicit teams, +0xA4 the player's team, +0xA8
-- the rival. The native answer (content\game\active_team.toml) runs first; this handler sees its result.
local REQUEST_EXPLICIT, REQUEST_PLAYER, REQUEST_RIVAL = 0xA0, 0xA4, 0xA8
-- +0xC0 (u8): the team set the player's side is built from (0x16B59D0 -> setup +4)
local REQUEST_TEAM_SET = 0xC0
-- party block: the VS team set in use (+0x9F13 in play mode 2: session +0x2CAC6F), as CMND_GET_VS_USE_TEAM_SET
local PARTY_VS_SET, PARTY_VS_SET_STORY, SESSION_PLAY_MODE = 0x9F10, 0x9F13, 0x2CAC6F

local SYNC_TABLE = "BattleBayDeluxe.LevelSync"
local LEVEL_SYNC = U.int(U.config("active_team.level_sync", 40), 40)
local sync_on = false

-- the active VS team set read from the party block (the mirror's when unreadable), nil when none
local function active_set()
  local party = U.global("active_team_party")
  local session = U.global("session")
  if party then
    local mode = session and U.rd("u8", session + SESSION_PLAY_MODE)
    local set = U.rd("u8", party + (mode == 2 and PARTY_VS_SET_STORY or PARTY_VS_SET))
    if set and set < 16 then
      return set
    end
  end
  return ACTIVE_SET
end

-- the level sync of the next match's stats (0 / nil = none)
local function set_sync(level)
  local on = level ~= nil and level > 0
  if on == sync_on then
    return
  end
  local ok = pcall(VRFW.native.table_set, SYNC_TABLE, 0, on and level or nil)
  if ok then
    sync_on = on
    info(on and string.format("level sync %d for the active team's match stats", level) or "level sync off")
  else
    warn("level sync table not written")
  end
end

-- 1.5.67 (owner 2026-10-15: a free match played his team at level sync 40): the native block the hook's first answers
-- fill with the request's address when the request carries the tile, else 0 (content\game\active_team.toml). Player's
-- team 0 alone is not the tile: other modes (a free match) send their own requests with explicit teams and player 0.
local REQUEST_MARK_KEY = "BattleBayDeluxe.active_team.request_mark"
local request_mark = nil

-- true when this request carries the Active team tile (marked natively before the answer turned the tile into 0)
local function is_tile_request(req, player)
  if player == TEAM then
    return true
  end
  return request_mark ~= nil and U.rd("ptr", request_mark) == req
end

if TEAM ~= 0 then
  local okb, block = pcall(VRFW.mem.buffer, "bbd_active_request_mark", 8)
  if okb and type(block) == "number" and pcall(VRFW.state.set, REQUEST_MARK_KEY, block) then
    request_mark = block
  else
    warn("the request mark is not set up: the active team's team set and level sync only apply to a request the " ..
      "native answer did not turn")
  end

  VRFW.on("game_reset", function()
    set_sync(nil)
  end)

  VRFW.on("hook:StartMatchRequest", function(ev)
    local req = ev.args and ev.args[2]
    if type(req) ~= "number" or req < 0x10000 then
      set_sync(nil)
      return nil
    end
    local explicit = U.rd("u8", req + REQUEST_EXPLICIT)
    local player = U.rd("u32", req + REQUEST_PLAYER)
    local rival = U.rd("u32", req + REQUEST_RIVAL)
    if not is_tile_request(req, player) then
      -- any other match (free match, Chronicle, story...): the player's own team as the game built the request
      set_sync(nil)
      return nil
    end
    -- the active team's match: its team set and level sync
    local set = active_set()
    local had = U.rd("u8", req + REQUEST_TEAM_SET)
    if set == nil then
      warn("match request: the active team set is unknown: the request keeps team set " .. tostring(had))
    elseif had ~= set then
      if U.wr("u8", req + REQUEST_TEAM_SET, set) then
        info(string.format("match request: team set %s -> %d (the active VS team set)", tostring(had), set))
      else
        warn("match request: the team set NOT written (" .. tostring(had) .. " stays)")
      end
    end
    set_sync(LEVEL_SYNC)
    if player == TEAM then
      -- the answer did not turn it (another request layout): the player's side = the active team set all the same
      if U.wr("u32", req + REQUEST_PLAYER, 0) then
        info(string.format("match request: the tile %s as the player's team with explicit flag %s: turned into the " ..
          "active team set here (the native answer did not)", U.hex(TEAM), tostring(explicit)))
      else
        warn("match request: the tile as the player's team NOT turned into the active team set (write failed)")
      end
    elseif player == 0 then
      info(string.format("match request: the tile turned natively into the active team set (player's team 0), rival %s",
        U.hex(rival or 0)))
    end
    return nil
  end)
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
