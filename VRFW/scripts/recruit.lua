-- Recruit service, script side (game Lua side: assets/lua/menu/_all/62_recruit.lua).
--   CMND_VRFW_RECRUIT_CLUB() -> { total, element = { [1..5] = n }, position = { [1..4] = n } }: saved club characters counted by card element
--     (chara_param col 2: 1 wind, 2 forest, 3 fire, 4 mountain, 5 void) and main position (col 3: 1 GK, 2 FW, 3 MF, 4 DF)
--   career counters (per save slot, read with CMND_VRFW_SAVE_GET), counted from first run:
--     "stats.matches_won"  matches the user's side ends ahead
--     "stats.goals"        goals of the user's side

Recruit = Recruit or {}

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local PARAM = nil   -- card -> { element, position }

-- a card's element and main position, from the framework's character index (VRFW.chara), cached per card
local function params()
  if PARAM then return PARAM end
  PARAM = setmetatable({}, { __index = function(t, card)
    local ok, c = pcall(VRFW.chara.card, card)
    if not ok or type(c) ~= "table" then return nil end
    local v = { tonumber(c.element) or 0, tonumber(c.position) or 0 }
    rawset(t, card, v)
    return v
  end })
  return PARAM
end

function Recruit.Club()
  local out = { total = 0, element = { 0, 0, 0, 0, 0 }, position = { 0, 0, 0, 0 } }
  local ok, saved = pcall(VRFW.chara.saved)
  if not ok or type(saved) ~= "table" then
    VRFW.warn("recruit: the club is not readable (" .. tostring(saved) .. ")")
    return out
  end
  local P = params()
  for _, c in ipairs(saved) do
    local p = P[u32(c.param)]
    out.total = out.total + 1
    if p then
      if p[1] >= 1 and p[1] <= 5 then out.element[p[1]] = out.element[p[1]] + 1 end
      if p[2] >= 1 and p[2] <= 4 then out.position[p[2]] = out.position[p[2]] + 1 end
    end
  end
  return out
end

-- ---- career counters

local match = nil   -- { user, rival } goals of the match being played

local function bump(key, n)
  local v = tonumber(VRFW.save.get(key, 0)) or 0
  VRFW.save.set(key, v + n)
end

VRFW.on("match_start", function(ev) match = { user = 0, rival = 0 } end)

VRFW.on("goal:user", function(ev)
  if match then match.user = match.user + 1 end
  bump("stats.goals", 1)
end)

VRFW.on("goal:rival", function(ev)
  if match then match.rival = match.rival + 1 end
end)

VRFW.on("match_end", function(ev)
  if match and match.user > match.rival then
    bump("stats.matches_won", 1)
  end
  match = nil
end)
