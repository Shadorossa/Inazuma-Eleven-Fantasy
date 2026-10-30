-- InaRogue › the talents a v2 run can give (docs/game/mods/inarogue-loop-v2.md «Talento propio»): catalogue
-- content/rogue/talent_pool.toml. A talent goes to one player of the run's team who has no «Talento propio» of
-- content/rogue/talents.toml and no run talent yet (one talent per player); it sits in his custom passive slot until the
-- run ends (rogue_run.json `talent_of`: bank uid -> talent key; lib/rogue/talents.lua set_run). Rarity weights and
-- prices: config.toml [rogue.run] talent_weights / talent_price.

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local Rules = require "lib/rogue/run_rules"
local R = require "lib/rogue/run"
local talents = require "lib/rogue/talents"
local info, warn = U.logger("rogue talents")

local P = {}

P.FILE, P.SCHEMA = "content/rogue/talent_pool.toml", "InaRogue.talent_pool/1"
P.RARITIES = { common = 1, rare = 2, epic = 3 }

local cat = nil

function P.catalogue()
  if cat then return cat end
  cat = { list = {}, by_key = {} }
  local ok, t = pcall(VRFW.files.toml, P.FILE)
  if not ok or type(t) ~= "table" or t.schema ~= P.SCHEMA then
    warn(P.FILE .. ": " .. tostring(ok and (type(t) == "table" and t.schema) or t) .. "; no run talents")
    return cat
  end
  for k, x in ipairs(type(t.talent) == "table" and t.talent or {}) do
    local key = type(x) == "table" and x.key
    local rarity = type(x) == "table" and P.RARITIES[x.rarity or "common"]
    local passive = type(x) == "table" and talents.passive_id(x.passive)
    if type(key) ~= "string" or not key:match("^[a-z0-9_]+$") or cat.by_key[key] or not rarity or not passive then
      warn(string.format("%s: [[talent]] #%d needs a new key (a-z 0-9 _), rarity common / rare / epic and a passive (left out)",
        P.FILE, k))
    else
      local sources = {}
      for _, s in ipairs(type(x.sources) == "table" and x.sources or {}) do sources[tostring(s)] = true end
      local d = { key = key, rarity = rarity, rarity_key = x.rarity or "common", passive = passive, sources = sources }
      cat.list[#cat.list + 1] = d
      cat.by_key[key] = d
    end
  end
  info(string.format("%d run talent(s)", #cat.list))
  return cat
end

function P.by_key(key) return P.catalogue().by_key[key] end
function P.name(key) return Rules.text("InaRogue.run_talent_" .. key .. "_name") end
function P.desc(key) return Rules.text("InaRogue.run_talent_" .. key .. "_desc") end

-- the run's players who may still get a talent: { { uid, param } } (team order)
function P.eligible(r)
  local o = {}
  for _, uid in ipairs(R.player_uids(r)) do
    if not (r.talent_of or {})[uid] then
      local param = Core.bank.bank_entry(uid)
      if param and not talents.has(param) then o[#o + 1] = { uid, param } end
    end
  end
  return o
end

-- `n` different talents of `source`, each for a different eligible player: { { key, uid, param, rarity } }
function P.draw(r, st, source, n)
  local players = P.eligible(r)
  local held = {}
  for _, k in pairs(r.talent_of or {}) do held[k] = true end
  local weights = Rules.get().talent_weights[source] or { 1, 1, 1 }
  local out, used = {}, {}
  while #out < n and #players > 0 do
    local cands, total = {}, 0
    for _, d in ipairs(P.catalogue().list) do
      if d.sources[source] and not held[d.key] and not used[d.key] then
        local w = weights[d.rarity] or 0
        if w > 0 then
          cands[#cands + 1] = { d, w }
          total = total + w
        end
      end
    end
    if total == 0 then break end
    local x = st:next() % total
    local d = cands[#cands][1]
    for _, c in ipairs(cands) do
      if x < c[2] then
        d = c[1]
        break
      end
      x = x - c[2]
    end
    local p = table.remove(players, st:next() % #players + 1)
    used[d.key] = true
    out[#out + 1] = { key = d.key, uid = p[1], param = p[2], rarity = d.rarity }
  end
  return out
end

-- the price of a talent in the Tienda (coins, × the run's price modifiers)
function P.price(r, key)
  local d = P.by_key(key)
  if not d then return 0 end
  return Rules.price(r, Rules.per_stage(Rules.get().talent_price, d.rarity))
end

-- [card] = passive id of the run's talents (the slot tables)
function P.run_map(r, entry_of)
  local o = {}
  for uid, key in pairs(r and r.talent_of or {}) do
    local d = P.by_key(key)
    local param = d and entry_of(uid)
    if param then o[param % U.TWO32] = d.passive end
  end
  return o
end

return P
