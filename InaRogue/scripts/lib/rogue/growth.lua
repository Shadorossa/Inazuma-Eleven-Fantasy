-- InaRogue › its own growth (content\growth\growth.toml, decision 3 of docs/refactor/roguelite-split-map.md): the level
-- cap INAROGUE sets levels within, the bank's start level and the rivals' level curve. Read once; bad values fall back
-- to the defaults (logged). No game access at require time.

local U = require "lib/rogue/util"
local info, warn = U.logger("rogue growth")

local G = {}

G.FILE = "content/growth/growth.toml"
G.DEFAULT = {
  cap = 99, start = 5,
  rivals = { { 1, 6 }, { 2, 9 }, { 3, 13 }, { 5, 18 }, { 8, 25 }, { 12, 35 }, { 18, 45 }, { 25, 55 }, { 35, 65 }, { 50, 75 },
    { 70, 85 }, { 90, 95 } },
}

local cache = nil

local function curve(v, cap)
  if type(v) ~= "table" or #v == 0 then return nil end
  local o, last = {}, 0
  for k, r in ipairs(v) do
    if type(r) ~= "table" or #r ~= 2 or type(r[1]) ~= "number" or type(r[2]) ~= "number" then return nil end
    if (k == 1 and r[1] ~= 1) or (k > 1 and r[1] <= last) or r[2] < 1 or r[2] > cap then return nil end
    last = r[1]
    o[#o + 1] = { r[1], r[2] }
  end
  return o
end

-- { cap, start, rivals } (read once per start)
function G.get()
  if cache then return cache end
  local g = {}
  local ok, t = pcall(VRFW.files.toml, G.FILE)
  if ok and type(t) == "table" and type(t.InaRogue) == "table" and type(t.InaRogue.Growth) == "table" then
    g = t.InaRogue.Growth
  else
    warn(G.FILE .. " not readable (" .. tostring(t) .. "): the default growth")
  end
  local c = { cap = G.DEFAULT.cap, start = G.DEFAULT.start, rivals = G.DEFAULT.rivals }
  if type(g.LevelCap) == "number" and g.LevelCap >= 1 and g.LevelCap <= 999 then c.cap = math.floor(g.LevelCap)
  elseif g.LevelCap ~= nil then warn("LevelCap must be 1..999: " .. tostring(g.LevelCap)) end
  if type(g.StartLevel) == "number" and g.StartLevel >= 1 and g.StartLevel <= c.cap then c.start = math.floor(g.StartLevel)
  elseif g.StartLevel ~= nil then warn("StartLevel must be 1..LevelCap: " .. tostring(g.StartLevel)) end
  if g.RivalLevels ~= nil then
    local r = curve(g.RivalLevels, c.cap)
    if r then c.rivals = r else warn("RivalLevels: needs [phase (1, increasing), level 1..LevelCap] rows; the default curve") end
  end
  cache = c
  info(string.format("level cap %d, start level %d, %d rival level key(s)", c.cap, c.start, #c.rivals))
  return c
end

-- the highest level the game plays now: the framework's level cap (game_state vrfw.level.max: the game's 99, or a
-- mod's [VRFW.Level] Max with Npc = true, e.g. Character Reforged's 200), never above InaRogue's LevelCap
function G.effective_cap()
  local ok, v = pcall(VRFW.state.get, "vrfw.level.max")
  local engine = (ok and tonumber(v)) or 99
  if engine < 1 then engine = 99 end
  return math.min(G.get().cap, math.floor(engine))
end

function G.clamp(level)
  return U.clamp(math.floor(level), 1, G.effective_cap())
end

-- the levels of `level` above what the game plays now (0 = none): the rivals get them as a stat multiplier instead
function G.over_cap(level)
  return math.max(math.floor(level) - G.effective_cap(), 0)
end

return G
