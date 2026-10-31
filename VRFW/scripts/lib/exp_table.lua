-- The game's EXP table (the served chara_exp_table_config, the mods' levels included), read once per script VM:
-- M.tables() -> need (level -> the EXP from that level to the next), rate (rarity -> EXP rate); nil, why when unreadable.
local M = {}

local KEY = "data/common/gamedata/character/chara_exp_table_config_*.cfg.bin"
local NEED, RATE = nil, nil

local function int(v) return math.floor(tonumber(v) or 0) end

function M.tables()
  if NEED ~= nil then return NEED, RATE end
  local okN, needs = pcall(VRFW.table.raw, KEY, "m_charaExpTableList", { 1, 2 })
  local okR, rates = pcall(VRFW.table.raw, KEY, "m_expRarityRateList", { 1, 2 })
  if not okN or type(needs) ~= "table" or #needs == 0 then
    return nil, "chara_exp_table_config is not readable (" .. tostring(needs) .. ")"
  end
  local need, rate = {}, {}
  for _, r in ipairs(needs) do
    local lv, n = int(r[1]), tonumber(r[2]) or 0
    if lv > 0 then need[lv] = n end
  end
  if okR and type(rates) == "table" then
    for _, r in ipairs(rates) do rate[int(tonumber(r[1]) or -1)] = tonumber(r[2]) or 1 end
  end
  NEED, RATE = need, rate
  return NEED, RATE
end

-- the EXP from `level` to the next for a character of `rarity` (each rarity's rate); nil when the table has no row
function M.need(level, rarity)
  local need, rate = M.tables()
  local n = need and need[int(level)]
  if not n or n <= 0 then return nil end
  return n * ((rate and rate[int(rarity or -1)]) or 1)
end

return M
