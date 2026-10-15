-- All Miximaxed › the miximax stat transfer (Chrono Stone), ported from Inazuma Fantasy on 2026-10-14 (IF's
-- scripts\lib\transform\mx_stats.lua and the match side of its scripts\transform.lua; owner: «trae de IF al mod de All
-- Miximaxed el tema de las stats entre jugadores miximax»). The numbers are data: content\stat_transfer\*.toml
-- ([AllMiximaxed.StatTransfer], schema AllMiximaxed.stat_transfer/1; a later mod's keys win key by key).
--   * the base keeps his stats and gains floor(partner stat × share): `favoured` on the partner's favoured stats (by his
--     position / element / gender), else `other`; an ideal miximax (a retail pair = best match, a Perfect Cascade
--     overdrive) `ideal_favoured` / `ideal_other`;
--   * PE: the base's max PE gains floor(partner's max PE × the same share) while the miximax runs in a match, when the
--     match resource `pe_resource` exists (`pe` in favoured_by: when it is favoured).
-- ONE owner: when another active mod declares its own miximax stat handler (`[[transform]] name = "miximax"` with
-- `stats.mode = "custom"` in its content\transforms: Inazuma Fantasy), nothing here applies (Owned() = false).
-- The partner's 9 stats: Character Reforged's CharaStat (its per-character stats; Suerte from its curve) + Player
-- Training's committed Suerte delta when that mod is on.

local M = {}

local STAT = { kick = 0, control = 1, technique = 2, pressure = 3, physical = 4, intelligence = 5, agility = 6, speed = 7, luck = 8 }
M.PE = 9
STAT.pe = M.PE
M.STAT_COUNT = 9
M.LUCK = 8

local function u32(v)
  if type(v) == "boolean" then return v and 1 or 0 end
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

local RULES = nil
local OWNED = nil

-- does another active mod give the miximax stats itself? (its own custom stat handler on the miximax transform)
function M.Owned()
  if OWNED ~= nil then return OWNED end
  OWNED = true
  local ok, decl = pcall(VRFW.files.declarations, "content/transforms")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    if tostring(f.mod or "") ~= "all_miximaxed" and type(d) == "table" and type(d.transform) == "table" then
      for _, t in ipairs(d.transform) do
        if type(t) == "table" and t.name == "miximax" and type(t.stats) == "table" and t.stats.mode == "custom" then
          OWNED = false
          VRFW.log("all_miximaxed:", string.format("stat transfer: %s gives the miximax stats (handler %s): this mod's rule is off",
            tostring(f.mod), tostring(t.stats.handler)))
        end
      end
    end
  end
  return OWNED
end

-- the shares and the favoured lists (defaults = Inazuma Fantasy's)
function M.Rules()
  if RULES then return RULES end
  local r = { favoured = 0.75, ideal_favoured = 1.0, other = 0.5, ideal_other = 0.5, by = {}, pe_resource = nil }
  local ok, decl = pcall(VRFW.files.declarations, "content/stat_transfer")
  for _, f in ipairs(ok and type(decl) == "table" and decl or {}) do
    local d = type(f) == "table" and f.data or nil
    local p = type(d) == "table" and type(d.AllMiximaxed) == "table" and d.AllMiximaxed.StatTransfer or nil
    if type(p) == "table" then
      for _, k in ipairs { "favoured", "ideal_favoured", "other", "ideal_other" } do
        if tonumber(p[k]) then r[k] = tonumber(p[k]) end
      end
      if type(p.pe_resource) == "string" then r.pe_resource = p.pe_resource ~= "" and p.pe_resource or nil end
      for k, list in pairs(type(p.favoured_by) == "table" and p.favoured_by or {}) do
        local v = {}
        for _, n in ipairs(type(list) == "table" and list or {}) do
          if STAT[n] then v[#v + 1] = STAT[n] end
        end
        r.by[k] = v
      end
    end
  end
  RULES = r
  return r
end

-- the favoured stats of a partner (position 1 GK 2 FW 3 MF 4 DF; element 1 wind 2 forest 3 fire 4 mountain; gender 1
-- male 2 female)
function M.Favoured(position, element, gender)
  local r, favoured = M.Rules(), {}
  local function add(k)
    for _, i in ipairs(r.by[k] or {}) do favoured[i] = true end
  end
  add(({ [1] = "gk", [2] = "fw", [3] = "mf", [4] = "df" })[tonumber(position) or 0] or "")
  add(({ [1] = "wind", [2] = "forest", [3] = "fire", [4] = "mountain" })[tonumber(element) or 0] or "")
  add(({ [1] = "male", [2] = "female" })[tonumber(gender) or 0] or "")
  for _, i in ipairs(r.by.never or {}) do favoured[i] = nil end
  return favoured
end

-- the partner's 9 stats ({ [0] … [8] }), nil when one can not be read
function M.PartnerStats(hdl)
  if hdl == 0 or type(CharacterReforged) ~= "table" or type(CharacterReforged.CharaStat) ~= "function" then return nil end
  local out = {}
  for i = 0, M.STAT_COUNT - 1 do
    local ok, v = pcall(CharacterReforged.CharaStat, hdl, i)
    v = ok and tonumber(v) or nil
    if v == nil or v < 0 then return nil end
    out[i] = v
  end
  local okd, delta = pcall(function() return PlayerTraining.LuckDelta(hdl) end)
  if okd and type(delta) == "number" then out[M.LUCK] = out[M.LUCK] + delta end
  return out
end

-- an ideal miximax: a retail pair (best match) or a Perfect Cascade overdrive; kind 0 normal, 1 best match, 2 overdrive
function M.Kind(record)
  if u32(record.overdrive) ~= 0 then return 2 end
  if record.f.best_match == true then return 1 end
  return 0
end

-- the gains of fusion record `record` ({ f = fusion, overdrive }): favoured mask, { [1..9] = gain of stat 0..8 }; nil =
-- the partner's stats are not readable
function M.Gains(record)
  local f, r = record.f, M.Rules()
  local ideal = M.Kind(record) ~= 0
  local favoured = M.Favoured(f.partner_position, f.partner_element, f.partner_gender)
  local favoured_share = ideal and r.ideal_favoured or r.favoured
  local other_share = ideal and r.ideal_other or r.other
  local stats = M.PartnerStats(u32(f.partner_hdl))
  if not stats then return nil end
  local mask, gains = 0, {}
  for i = 0, M.STAT_COUNT - 1 do
    if favoured[i] then mask = bit32.bor(mask, bit32.lshift(1, i)) end
    gains[i + 1] = math.floor(math.max(stats[i] or 0, 0) * (favoured[i] and favoured_share or other_share))
  end
  return mask, gains
end

-- the PE gain of fusion record `record`: gain, favoured; nil = no PE rule or the partner's max PE is not readable
function M.PeGain(record)
  local r = M.Rules()
  if not r.pe_resource or type(VRFW.resource) ~= "table" or type(VRFW.resource.max) ~= "function" then return nil end
  local f = record.f
  local card = u32(f.partner_param)
  if card == 0 then return nil end
  local ok, pe = pcall(VRFW.resource.max, r.pe_resource, card, nil)
  pe = ok and tonumber(pe) or nil
  if not pe or pe <= 0 then return nil end
  local ideal = M.Kind(record) ~= 0
  local favoured = M.Favoured(f.partner_position, f.partner_element, f.partner_gender)[M.PE] == true
  local share = favoured and (ideal and r.ideal_favoured or r.favoured) or (ideal and r.ideal_other or r.other)
  return math.floor(pe * share), favoured
end

-- the base's max PE (the same match resource, his card at its default level); 0 = none / not readable
function M.PeBase(record)
  local r = M.Rules()
  if not r.pe_resource or type(VRFW.resource) ~= "table" or type(VRFW.resource.max) ~= "function" then return 0 end
  local card = u32(record.f.base_param)
  if card == 0 then return 0 end
  local ok, pe = pcall(VRFW.resource.max, r.pe_resource, card, nil)
  pe = ok and tonumber(pe) or 0
  return pe > 0 and math.floor(pe) or 0
end

VRFW.on("game_reset", function() RULES, OWNED = nil, nil end)

return M
