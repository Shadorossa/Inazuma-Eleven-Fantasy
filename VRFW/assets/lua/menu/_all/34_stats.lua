-- menu_engine: per-save match statistics (VR-Framework base feature).
-- Definitions only (this file runs in every script VM, lua\_all). The ONE place that keeps how many times the player beat
-- a team, per save slot: the save service (owner "vr_framework"), key "stats.wins.<team id>" (the team's numeric id as
-- the team type gives it, e.g. a chain tile's `team`), a decimal string.
--
-- Fed by whoever sees a won match (VRFW_Stats.AddWin): today the chain boards (VRFW_Chain.Win, every opener). A floor
-- provider (VRFW_Stats.AddFloor) answers what an older save already proves (a chain tile won before this counter existed
-- = at least 1 win); the first AddWin of a team starts from that floor, so the count never goes backwards.
-- Lua API: VRFW_Stats.WinsVs(team) -> n, VRFW_Stats.AddWin(team) -> n, VRFW_Stats.AddFloor(fn(team) -> n).
-- No engine call at load time.
if VRFW_Stats == nil then
  local ST = {
    SAVE_GET = 2187277743,   -- CMND_VRFW_SAVE_GET (owner, key, default)
    SAVE_SET = 2574269955,   -- CMND_VRFW_SAVE_SET (owner, key, value, commit)
    LOG = 3661580131,        -- CMND_EVT_LOG
    OWNER = "vr_framework",
    floors = {},
  }
  VRFW_Stats = ST

  local function key(team)
    if type(team) ~= "number" or team == 0 then
      return nil
    end
    return "stats.wins." .. tostring(math.floor(team))
  end

  local function stored(k)
    local ok, s = pcall(funcLuaCommand, ST.SAVE_GET, ST.OWNER, k, "")
    if ok then
      return tonumber(s)
    end
    return nil
  end

  -- a provider of a lower bound: fn(team) -> wins the save already proves (0 / nil = none)
  function ST.AddFloor(fn)
    if type(fn) == "function" then
      ST.floors[#ST.floors + 1] = fn
    end
  end

  local function floor_of(team)
    local n = 0
    for _, fn in ipairs(ST.floors) do
      local ok, v = pcall(fn, team)
      if ok and type(v) == "number" and v > n then
        n = v
      end
    end
    return n
  end

  -- the wins against a team in this save slot (0 = never beaten, or not tracked yet)
  function ST.WinsVs(team)
    local k = key(team)
    if k == nil then
      return 0
    end
    local n = stored(k) or 0
    local f = floor_of(team)
    return f > n and f or n
  end

  -- one more win against a team; returns the new count
  function ST.AddWin(team)
    local k = key(team)
    if k == nil then
      return 0
    end
    local n = ST.WinsVs(team) + 1
    pcall(funcLuaCommand, ST.SAVE_SET, ST.OWNER, k, tostring(n), 1)
    pcall(funcLuaCommand, ST.LOG, "stats", "win vs", k, n)
    return n
  end
end
