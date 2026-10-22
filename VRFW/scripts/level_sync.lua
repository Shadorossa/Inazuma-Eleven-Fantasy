-- Level sync of the user's team, script side (docs/framework/level-sync.md). Declarations: every active mod's
-- content\level_sync\*.toml (`VRFW.level_sync/1`, keys content\types\level_sync.toml).
-- At start: the tables VRFW.LevelSync.Raise / .Cap (difficulty row -> level), the native block whose address the state key
-- vr_framework.level_sync.request holds, and the two detours of content\game\level_sync.toml. In a match the answers
-- are native: the match request writes its difficulty row into the block, and each saved player's match copy gets the
-- stats of the row's level. The block is cleared at the end of every match (a «Salir» too) and at a title return.

LevelSync = LevelSync or {}

local D = require "lib/declarations"

local function info(text) VRFW.log("level_sync: " .. text) end
local function warn(text) VRFW.warn("level_sync: " .. text) end

local TABLE_RAISE, TABLE_CAP = "VRFW.LevelSync.Raise", "VRFW.LevelSync.Cap"
local STATE_KEY = "vr_framework.level_sync.request"
local HOOKS = { "LevelSync.MatchRequest", "LevelSync.StatLevel" }

local ROWS = {}           -- difficulty row -> { level, raise, key }
local BLOCK = nil         -- the native block: u8 difficulty row of the match request
local LIVE = false

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
    for _, row in ipairs(v.difficulties) do
      local had = ROWS[row]
      if had then
        warn(string.format("%s: difficulty %d already synced by %s: left out for that row", d.where, row, had.key))
      else
        ROWS[row] = { level = v.level, raise = v.raise ~= false, key = d.key }
        count = count + 1
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
  for row, r in pairs(ROWS) do
    parts[#parts + 1] = string.format("difficulty %d = Nv. %d (%s, %s)", row, r.level,
      r.raise and "every player" or "players above it", r.key)
  end
  table.sort(parts)
  return table.concat(parts, ", ")
end

-- forget the last request's row (no match is synced until the next request)
local function clear(why)
  if not BLOCK then return end
  local ok, row = pcall(VRFW.mem.read, "u8", BLOCK)
  if ok and row ~= 0 then
    pcall(VRFW.mem.write, "u8", BLOCK, 0)
    if ROWS[row] then info(string.format("difficulty %d: sync off (%s)", row, why)) end
  end
end

VRFW.on("match_start", function()
  if not LIVE or not BLOCK then return end
  local ok, row = pcall(VRFW.mem.read, "u8", BLOCK)
  local r = ok and ROWS[row]
  if r then
    info(string.format("this match (difficulty %d): the user's players play at Nv. %d%s", row, r.level,
      r.raise and "" or " (only the players above it)"))
  end
end)

VRFW.on("match_end", function() clear("match end") end)
VRFW.on("game_reset", function() clear("title return") end)

local function start()
  if load_rules() == 0 then return end
  for row, r in pairs(ROWS) do
    local name = r.raise and TABLE_RAISE or TABLE_CAP
    local ok, err = pcall(VRFW.native.table_set, name, row, r.level)
    if not ok then
      warn(string.format("table %s: difficulty %d not written (%s): no level sync", name, row, tostring(err)))
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
