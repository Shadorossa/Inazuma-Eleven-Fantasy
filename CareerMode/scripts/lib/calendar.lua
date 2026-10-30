-- Career mode calendar (docs/game/mods/career-mode-proposal.md §11): the days of a season. Every fixture of the season
-- gets a date from config.toml [calendar] (the season's first day, the first matchday, the latest day of the final,
-- each phase's match days, the breaks, the transfer windows, the World Cup); nothing here names a date. A date is a day
-- number (days since 1970-01-01, proleptic Gregorian); `civil` turns it into year, month, day.
local M = {}

local floor = math.floor

local WEEKDAYS = { mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6, sun = 7 }

-- the day number of a civil date
function M.day(y, m, d)
  y = m <= 2 and y - 1 or y
  local era = floor(y / 400)
  local yoe = y - era * 400
  local doy = floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
  local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- a day number -> year, month, day
function M.civil(z)
  z = z + 719468
  local era = floor(z / 146097)
  local doe = z - era * 146097
  local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
  local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
  local mp = floor((5 * doy + 2) / 153)
  local d = doy - floor((153 * mp + 2) / 5) + 1
  local m = mp < 10 and mp + 3 or mp - 9
  local y = yoe + era * 400
  if m <= 2 then y = y + 1 end
  return y, m, d
end

-- the weekday of a day number: 1 Monday .. 7 Sunday (1970-01-01 was a Thursday)
function M.weekday(z)
  return (z + 3) % 7 + 1
end

-- the days of a month
function M.month_days(y, m)
  local ny, nm = y, m + 1
  if nm > 12 then ny, nm = y + 1, 1 end
  return M.day(ny, nm, 1) - M.day(y, m, 1)
end

-- a date as the screen shows it: { day, y, m, d, wd }
function M.view(z)
  if z == nil then return nil end
  local y, m, d = M.civil(z)
  return { day = z, y = y, m = m, d = d, wd = M.weekday(z) }
end

-- ------------------------------------------------------------------------------------------------ the rules

-- "MM-DD" -> month, day (nil when it is not one)
local function month_day(s)
  local m, d = tostring(s or ""):match("^(%d%d?)%-(%d%d?)$")
  m, d = tonumber(m), tonumber(d)
  if m and d and m >= 1 and m <= 12 and d >= 1 and d <= 31 then return { m = m, d = d } end
  return nil
end

local function weekday_of(s, default)
  return WEEKDAYS[tostring(s or ""):lower():sub(1, 3)] or default
end

local function range_list(v)
  local out = {}
  for _, r in ipairs(type(v) == "table" and v or {}) do
    local a, b = type(r) == "table" and month_day(r.from), type(r) == "table" and month_day(r.to)
    if a and b then out[#out + 1] = { from = a, to = b } end
  end
  return out
end

local MODES = { weekend = true, midweek = true, both = true }

-- config.toml [calendar] through `config(path, default)` -> the rules
function M.rules(config)
  local function mode(key, default)
    local v = tostring(config("calendar." .. key, default))
    return MODES[v] and v or default
  end
  local first = config("calendar.first_match", nil)
  first = type(first) == "table" and first or {}
  local compress = {}
  for _, p in ipairs(type(config("calendar.compress", nil)) == "table" and config("calendar.compress", nil) or {}) do
    compress[#compress + 1] = tostring(p)
  end
  local wc = config("calendar.world_cup", nil)
  local wc_from, wc_to = type(wc) == "table" and month_day(wc.from), type(wc) == "table" and month_day(wc.to)
  return {
    first_year = floor(tonumber(config("calendar.first_year", 2026)) or 2026),
    start = month_day(config("calendar.season_start", "08-01")) or { m = 8, d = 1 },
    first_match = { m = floor(tonumber(first.month) or 8), wd = weekday_of(first.weekday, 6),
      nth = floor(tonumber(first.nth) or -1) },
    finish = month_day(config("calendar.season_end", "06-01")) or { m = 6, d = 1 },
    weekend = weekday_of(config("calendar.weekend", "sat"), 6),
    midweek = weekday_of(config("calendar.midweek", "wed"), 3),
    rest_days = math.max(1, floor(tonumber(config("calendar.rest_days", 3)) or 3)),
    draw_after_days = math.max(1, floor(tonumber(config("calendar.draw_after_days", 4)) or 4)),
    modes = { superliga = mode("superliga", "weekend"), league = mode("league", "weekend"),
      frontier = mode("frontier", "midweek"), final = mode("final", "weekend") },
    compress = compress,
    breaks = range_list(config("calendar.breaks", nil)),
    windows = range_list(config("calendar.transfer_windows", nil)),
    world_cup = wc_from and wc_to and { from = wc_from, to = wc_to } or nil,
  }
end

-- ------------------------------------------------------------------------------------------------ a season's days

-- the day of a month-day within the season that starts in `year` (months before the start month are the next year's)
local function season_day(year, rules, md)
  local y = md.m >= rules.start.m and year or year + 1
  return M.day(y, md.m, math.min(md.d, M.month_days(y, md.m)))
end

-- the nth weekday `wd` of a month (nth < 0 counts from the month's end)
local function nth_weekday(y, m, wd, nth)
  if nth < 0 then
    local z = M.day(y, m, M.month_days(y, m))
    while M.weekday(z) ~= wd do z = z - 1 end
    return z + (nth + 1) * 7
  end
  local z = M.day(y, m, 1)
  while M.weekday(z) ~= wd do z = z + 1 end
  return z + (math.max(1, nth) - 1) * 7
end

local function ranges(year, rules, list)
  local out = {}
  for _, r in ipairs(list) do
    local a = season_day(year, rules, r.from)
    local b = season_day(year, rules, r.to)
    if b < a then b = a end
    out[#out + 1] = { a, b }
  end
  return out
end

local function inside(z, list)
  for i, r in ipairs(list) do
    if z >= r[1] and z <= r[2] then return i end
  end
  return nil
end

-- the match days of every phase laid out from `first`: modes = { phase = mode }, breaks = day ranges kept free
local function lay_out(first, counts, rules, modes, breaks)
  local function days_of(mode)
    if mode == "both" then return { [rules.weekend] = true, [rules.midweek] = true } end
    return { [mode == "midweek" and rules.midweek or rules.weekend] = true }
  end
  local function next_day(from, mode)
    local set = days_of(mode)
    local z = from
    while not set[M.weekday(z)] or inside(z, breaks) do z = z + 1 end
    return z
  end
  local out = { superliga = {}, league = {}, frontier = {} }
  local at = first
  for i = 1, counts.superliga do
    at = next_day(i == 1 and first or at + rules.rest_days, modes.superliga)
    out.superliga[i] = at
  end
  out.draw = at + rules.draw_after_days
  at = out.draw
  for i = 1, counts.league do
    at = next_day(at + (i == 1 and 1 or rules.rest_days), modes.league)
    out.league[i] = at
  end
  for i = 1, counts.frontier do
    local mode = i == counts.frontier and modes.final or modes.frontier
    at = next_day(at + rules.rest_days, mode)
    out.frontier[i] = at
  end
  out.last = at
  return out
end

-- the season that starts in `year`: counts = { superliga, league, frontier } (rounds of each phase) -> { year, start,
-- finish, first, superliga = { days }, draw, league = { days }, frontier = { days }, breaks, windows, world_cup, late }
-- The phases' match days are the rules' modes; when the final would fall after the season's end the phases of
-- `compress` play on midweek days too (one more each try), then the breaks are given up; late = still after the end.
function M.season(year, counts, rules)
  local start = M.day(year, rules.start.m, rules.start.d)
  local finish = season_day(year, rules, rules.finish)
  local fy = rules.first_match.m >= rules.start.m and year or year + 1
  local first = math.max(start, nth_weekday(fy, rules.first_match.m, rules.first_match.wd, rules.first_match.nth))
  local breaks = ranges(year, rules, rules.breaks)
  local modes = {}
  for k, v in pairs(rules.modes) do modes[k] = v end
  local plan = lay_out(first, counts, rules, modes, breaks)
  local tries = 0
  for _, phase in ipairs(rules.compress) do
    if plan.last <= finish then break end
    if modes[phase] and modes[phase] ~= "both" then
      modes[phase] = "both"
      plan = lay_out(first, counts, rules, modes, breaks)
      tries = tries + 1
    end
  end
  local kept = breaks
  if plan.last > finish and #breaks > 0 then
    kept = {}
    plan = lay_out(first, counts, rules, modes, kept)
  end
  plan.year, plan.start, plan.finish, plan.first = year, start, finish, first
  plan.breaks, plan.windows = kept, ranges(year, rules, rules.windows)
  plan.world_cup = rules.world_cup and ranges(year, rules, { rules.world_cup })[1] or nil
  plan.late = plan.last > finish
  plan.compressed = tries
  return plan
end

-- the transfer window open on day z: its index, first and last day; nil when every window is closed
function M.window_at(plan, z)
  local i = inside(z, plan.windows or {})
  if i then return i, plan.windows[i][1], plan.windows[i][2] end
  return nil
end

-- the next transfer window that opens after day z: its first and last day (nil when none is left this season)
function M.next_window(plan, z)
  local best
  for _, r in ipairs(plan.windows or {}) do
    if r[1] > z and (best == nil or r[1] < best[1]) then best = r end
  end
  if best then return best[1], best[2] end
  return nil
end

-- the twelve months of the season from its start month: { { y, m, first = day of the 1st, days, wd } }
function M.months(plan)
  local y, m = M.civil(plan.start)
  local out = {}
  for _ = 1, 12 do
    local z = M.day(y, m, 1)
    out[#out + 1] = { y = y, m = m, first = z, days = M.month_days(y, m), wd = M.weekday(z) }
    m = m + 1
    if m > 12 then y, m = y + 1, 1 end
  end
  return out
end

return M
