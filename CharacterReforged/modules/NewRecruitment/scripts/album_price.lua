-- New Recruitment › the price of a player signed from BetterQoL's album (option «Fichajes» = «Álbum»;
-- assets\lua\_all\new_recruitment_album.lua). Rule: config.toml [album] (the game sells no player for its currency):
-- (base + per_level × level) × rarity_factor[rarity] (1 for a rarity not listed), in the item `currency`.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_NEWRECRUITMENT_ALBUM_PRICE | card rarity, level he joins at | currency item id, count (nothing = no rule: free) |

NewRecruitment = NewRecruitment or {}

require "VRFW/lib/basics"
local info, warn = VRFW.logger("album_price")

local RULE = nil   -- { item, base, per_level, factor = { [rarity] = n } }, read once

local function rule()
  if RULE ~= nil then return RULE end
  RULE = false
  local ok, cfg = pcall(VRFW.files.config, "album")
  if not ok or type(cfg) ~= "table" or type(cfg.currency) ~= "string" or cfg.currency == "" then
    warn("config.toml [album] has no currency: album signings are free")
    return RULE
  end
  local factor = {}
  for k, v in pairs(type(cfg.rarity_factor) == "table" and cfg.rarity_factor or {}) do
    local r, f = tonumber(k), tonumber(v)
    if r ~= nil and f ~= nil and f >= 0 then factor[math.floor(r)] = f end
  end
  RULE = { item = VRFW.crc32(cfg.currency), base = tonumber(cfg.base) or 0, per_level = tonumber(cfg.per_level) or 0,
    factor = factor }
  info(string.format("album price: %s, %s + %s per level", cfg.currency, tostring(RULE.base), tostring(RULE.per_level)))
  return RULE
end

-- CMND_NEWRECRUITMENT_ALBUM_PRICE(rarity, level) -> item id, count
function NewRecruitment.AlbumPrice(rarity, level)
  local r = rule()
  if not r then return end
  local lv = math.max(1, math.floor(tonumber(level) or 1))
  local f = r.factor[math.floor(tonumber(rarity) or 0)] or 1
  local count = math.max(0, math.floor((r.base + r.per_level * lv) * f + 0.5))
  return r.item, count
end
