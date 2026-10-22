-- Level sync of the user's team, script side (docs/framework/level-sync.md). Declarations: every active mod's
-- content\level_sync\*.toml (`VRFW.level_sync/1`, keys content\types\level_sync.toml).
-- At start: the tables VRFW.LevelSync.Raise / .Cap ({ game, row } -> level, 0 = any), the native block whose address the state key
-- vr_framework.level_sync.request holds, and the two detours of content\game\level_sync.toml. In a match the answers
-- are native: the match request writes its difficulty row and game into the block, and each saved player's match copy gets the
-- stats of the row's level. The block is cleared at the end of every match (a «Salir» too) and at a title return.

LevelSync = LevelSync or {}

local D = require "lib/declarations"

local function info(text) VRFW.log("level_sync: " .. text) end
local function warn(text) VRFW.warn("level_sync: " .. text) end

local TABLE_RAISE, TABLE_CAP = "VRFW.LevelSync.Raise", "VRFW.LevelSync.Cap"
local STATE_KEY = "vr_framework.level_sync.request"
local HOOKS = { "LevelSync.MatchRequest", "LevelSync.StatLevel" }

local RULES = {}          -- "game:row" -> { game, row, level, raise, key } (game / row 0 = any)
local BLOCK = nil         -- the native block: +0 u8 difficulty row, +4 u32 game of the match request
local LIVE = false

local function hex(v) return string.format("0x%08X", v or 0) end

local function pair_text(game, row)
  local g = game == 0 and "any game" or "game " .. hex(game)
  local r = row == 0 and "any difficulty" or "difficulty " .. row
  return g .. ", " .. r
end

local function load_rules()
  local schema, why = D.schema("level_sync")
  if not schema then
    warn(why .. ": no level sync")
    return 0
  end
  local decls, skipped = D.load(schema, warn)
  local count = 0
  for _, d in ipairs(decls) do
    local v = d.v
    local games = (v.games and #v.games > 0) and v.games or { 0 }
    local rows = (v.difficulties and #v.difficulties > 0) and v.difficulties or { 0 }
    if games[1] == 0 and rows[1] == 0 then
      warn(d.where .. ": neither games nor difficulties: left out (a rule names the matches it syncs)")
    else
      for _, game in ipairs(games) do
        for _, row in ipairs(rows) do
          local k = game .. ":" .. row
          local had = RULES[k]
          if had then
            warn(string.format("%s: %s already synced by %s: left out for it", d.where, pair_text(game, row), had.key))
          else
            RULES[k] = { game = game, row = row, level = v.level, raise = v.raise ~= false, key = d.key }
            count = count + 1
          end
        end
      end
    end
  end
  if count == 0 then
    info(string.format("off: no declaration (%d left out by `when`): every match at the players' own levels", skipped or 0))
  end
  return count
end

local function describe()
  local parts = {}
  for _, r in pairs(RULES) do
    parts[#parts + 1] = string.format("%s = Nv. %d (%s, %s)", pair_text(r.game, r.row), r.level,
      r.raise and "every player" or "players above it", r.key)
  end
  table.sort(parts)
  return table.concat(parts, "; ")
end

-- the rule of a request (most specific first), as the native answers pick it
local function rule_of(game, row)
  return RULES[game .. ":" .. row] or RULES[game .. ":0"] or RULES["0:" .. row]
end

local function request()
  if not BLOCK then return nil end
  local ok1, row = pcall(VRFW.mem.read, "u8", BLOCK)
  local ok2, game = pcall(VRFW.mem.read, "u32", BLOCK + 4)
  if not (ok1 and ok2) then return nil end
  return row, game
end

-- forget the last request (no match is synced until the next request)
local function clear(why)
  local row, game = request()
  if row == nil or (row == 0 and game == 0) then return end
  pcall(VRFW.mem.write, "u8", BLOCK, 0)
  pcall(VRFW.mem.write, "u32", BLOCK + 4, 0)
  if rule_of(game, row) then info(string.format("%s: sync off (%s)", pair_text(game, row), why)) end
end

VRFW.on("match_start", function()
  if not LIVE then return end
  local row, game = request()
  local r = row ~= nil and rule_of(game, row)
  if r then
    info(string.format("this match (%s): the user's players play at Nv. %d%s (%s); their moves stay as they are",
      pair_text(game, row), r.level, r.raise and "" or " (only the players above it)", r.key))
  end
end)

VRFW.on("match_end", function() clear("match end") end)
VRFW.on("game_reset", function() clear("title return") end)

-- CMND_VRFW_LEVEL_SYNC () -> level, raise (1 / 0) of the current match request's rule; 0 = no sync. The VS screen
-- (assets/lua/menu/soccer_battle_setting_flow_vs_menu/200_level_sync.lua) shows the synced team level with it.
function LevelSync.Cmd()
  if not LIVE then return 0, 0 end
  local row, game = request()
  local r = row ~= nil and rule_of(game, row)
  if not r then return 0, 0 end
  return r.level, r.raise and 1 or 0
end

local function start()
  if load_rules() == 0 then return end
  for _, r in pairs(RULES) do
    local name = r.raise and TABLE_RAISE or TABLE_CAP
    local ok, err = pcall(VRFW.native.table_set, name, { r.game, r.row }, r.level)
    if not ok then
      warn(string.format("table %s: %s not written (%s): no level sync", name, pair_text(r.game, r.row), tostring(err)))
      return
    end
  end
  local okb, block = pcall(VRFW.mem.buffer, "level_sync_request", 8)
  if not okb or type(block) ~= "number" or not pcall(VRFW.state.set, STATE_KEY, block) then
    warn("the request block is not set up: no level sync")
    return
  end
  BLOCK = block
  for _, name in ipairs(HOOKS) do
    local ok, done, e = pcall(VRFW.hook.apply, name)
    if not (ok and done == true) then
      warn(string.format("detour %s not installed (%s): no level sync (%s)", name, tostring(ok and e or done), describe()))
      return
    end
  end
  LIVE = true
  info("on: " .. describe())
end

pcall(start)
