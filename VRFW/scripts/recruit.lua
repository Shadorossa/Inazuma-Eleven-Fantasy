-- VR-Framework › recruit service, script side (docs/framework/recruit.md §2.1, VRFW 2.1). The game Lua side is
-- assets\lua\menu\_all\62_recruit.lua (VRFW_Recruit); this script answers what game Lua cannot see:
--
--   CMND_VRFW_RECRUIT_CLUB() -> { total, element = { [1..5] = n }, position = { [1..4] = n } }: the saved club's
--                               characters (VRFW.chara.saved) counted by their card's element (chara_param col 2:
--                               1 wind, 2 forest, 3 fire, 4 mountain, 5 void) and main position (col 3: 1 GK, 2 FW,
--                               3 MF, 4 DF)
--   career counters (per save slot, owner vr_framework, read by VRFW_Recruit with CMND_VRFW_SAVE_GET):
--     "stats.matches_won"  every match the user's side ends ahead (goals counted by the `goal` trigger since
--                          `match_start`; a match left early counts as it stood)
--     "stats.goals"        every goal of the user's side
--   Counting starts when this script first runs: older saves start at 0.

Recruit = Recruit or {}

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  return math.floor(v) % 4294967296
end

local PARAM = nil   -- card -> { element, position }

-- a card's element and main position: the framework's ONE character index (VRFW.chara, read once natively for every
-- script; 2.3, docs/framework/chara-index.md), asked per card and kept
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

-- ---------------------------------------------------------------------------------------------- career counters

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
