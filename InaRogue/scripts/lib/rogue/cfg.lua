-- InaRogue › INAROGUE: the [rogue] settings of config.toml with their defaults (was RogueCfg of the DLL's
-- module rogue): every key is optional; a bad table falls back to its default (logged once).

local U = require "lib/rogue/util"
local Gr = require "lib/rogue/growth"
local info, warn = U.logger("rogue")

local C = {}

local function list_of_lists(v)
  if type(v) ~= "table" then return nil end
  local o = {}
  for _, r in ipairs(v) do
    if type(r) ~= "table" then return nil end
    o[#o + 1] = U.nums(r)
  end
  return o
end

local function deflt(v, d)
  if v == nil or type(v) ~= type(d) then return d end
  return v
end

-- route-map size curve keyframes [from_phase, length, width] (run.rs default_curve)
C.DEFAULT_CURVE = {
  { 1, 3, 2 }, { 2, 4, 2 }, { 4, 5, 3 }, { 7, 6, 3 }, { 11, 7, 3 }, { 16, 8, 3 }, { 21, 9, 3 }, { 26, 9, 4 },
  { 31, 10, 4 }, { 37, 11, 4 }, { 43, 12, 4 }, { 49, 13, 4 }, { 55, 14, 4 }, { 60, 14, 5 }, { 66, 15, 5 },
  { 72, 16, 5 }, { 78, 17, 5 }, { 84, 18, 5 }, { 90, 19, 5 }, { 100, 20, 5 },
}
C.MAX_LEN, C.MAX_WIDTH = 30, 5

-- map content rows [type, from_phase, weight %] (Cofre 1, Tienda 2, Evento 3, Fichaje 4, Gacha 5, Élite 6,
-- Tragaperras 7)
C.DEFAULT_CONTENT = { { 1, 2, 12 }, { 2, 3, 10 }, { 3, 4, 12 }, { 4, 5, 8 }, { 5, 6, 8 }, { 6, 8, 10 }, { 7, 10, 6 } }

-- (the rivals' level curve is InaRogue's growth since 2026-10-14: content\growth\growth.toml RivalLevels)
C.DEFAULT_LEVEL_CURVE = { { 1, 6 }, { 2, 9 }, { 3, 13 }, { 5, 18 }, { 8, 25 }, { 12, 35 }, { 18, 45 }, { 25, 55 },
  { 35, 65 }, { 50, 75 }, { 70, 85 }, { 90, 95 } }

-- formation drops [source 1-5, from_phase, chance %, min rarity, max rarity] (pachanga 1, 11v11 2, Élite 3, boss 4,
-- Cofre 5)
C.DEFAULT_DROPS = { { 1, 1, 10, 1, 1 }, { 1, 6, 12, 1, 2 }, { 2, 1, 20, 1, 2 }, { 2, 8, 25, 1, 3 }, { 3, 1, 60, 1, 2 },
  { 3, 5, 70, 2, 3 }, { 3, 10, 80, 2, 4 }, { 4, 1, 100, 1, 2 }, { 4, 3, 100, 2, 3 }, { 4, 7, 100, 3, 4 },
  { 5, 1, 100, 1, 2 }, { 5, 6, 100, 1, 3 }, { 5, 12, 100, 2, 4 } }

function C.checked_curve(rows)
  if type(rows) ~= "table" or #rows == 0 then return nil, "empty map_curve" end
  local last = 0
  for k, r in ipairs(rows) do
    local bad = "map_curve row " .. k
    if #r ~= 3 then return nil, bad .. ": needs [from_phase, length, width]" end
    if (k == 1 and r[1] ~= 1) or (k > 1 and r[1] <= last) then return nil, bad .. ": phases must start at 1 and increase" end
    if r[2] < 2 or r[2] > C.MAX_LEN then return nil, bad .. ": length outside 2..=" .. C.MAX_LEN end
    if r[3] < 1 or r[3] > C.MAX_WIDTH then return nil, bad .. ": width outside 1..=" .. C.MAX_WIDTH end
    last = r[1]
  end
  return rows
end

function C.checked_content(rows)
  if type(rows) ~= "table" then return nil, "map_content: not a list" end
  for k, r in ipairs(rows) do
    if #r ~= 3 or r[1] < 1 or r[1] > 7 or r[2] == 0 or r[3] > 100 then
      return nil, "map_content row " .. k .. ": needs [type 1-7, from_phase >= 1, weight 0-100]"
    end
  end
  return rows
end

function C.default_coins()
  local o = {}
  for n = 1, 30 do o[n] = { n, 1, 1 } end
  return o
end

function C.checked_coins(rows)
  if type(rows) ~= "table" then return nil, "gacha_coins: not a list" end
  for k, r in ipairs(rows) do
    if #r ~= 3 or r[1] < 1 or r[1] > 30 or r[3] == 0 then
      return nil, "gacha_coins row " .. k .. ": needs [constellation 1-30, weight, from_phase >= 1]"
    end
  end
  return rows
end

function C.checked_level_curve(rows)
  if type(rows) ~= "table" or #rows == 0 then return nil, "empty level_curve" end
  local last = 0
  for k, r in ipairs(rows) do
    if #r ~= 2 or (k == 1 and r[1] ~= 1) or (k > 1 and r[1] <= last) or r[2] < 1 or r[2] > Gr.get().cap then
      return nil, "level_curve row " .. k .. ": needs [phase (1, increasing), level 1-" .. Gr.get().cap .. " (content\\growth LevelCap)]"
    end
    last = r[1]
  end
  return rows
end

function C.checked_drops(rows, weights)
  for k, r in ipairs(rows) do
    if #r ~= 5 or r[1] < 1 or r[1] > 5 or r[2] == 0 or r[3] > 100 or r[4] == 0 or r[4] > r[5] or r[5] > 4 then
      return nil, "formations.drops row " .. k .. ": needs [source 1-5, from_phase >= 1, chance 0-100, min 1-4, max min-4]"
    end
  end
  if #weights ~= 4 then return nil, "formations.rarity_weights: needs 4 weights (1..4 stars)" end
  return true
end

local cache = nil

-- the merged [rogue] settings (read once per start)
function C.get()
  if cache then return cache end
  local r = U.cfg("rogue", {})
  if type(r) ~= "table" then r = {} end
  local c = {
    cost_base = U.nums(deflt(r.cost_base, { 2, 4, 6, 9, 12 })),
    cost_stat_ref = deflt(r.cost_stat_ref, 1100),
    cost_stat_step = deflt(r.cost_stat_step, 110),
    cost_stat_min = deflt(r.cost_stat_min, -1),
    cost_stat_max = deflt(r.cost_stat_max, 3),
    squad_budget = deflt(r.squad_budget, 45),
    budget_per_phase = deflt(r.budget_per_phase, 5),
    bank_capacity = deflt(r.bank_capacity, 6000),
    debug_tools = deflt(r.debug_tools, false),
    debug_all_players = deflt(r.debug_all_players, false),
    debug_all_players_limit = deflt(r.debug_all_players_limit, 5000),
    starter_pick = deflt(r.starter_pick, true),
    starter_cost = U.nums(deflt(r.starter_cost, { 1, 2, 4, 6, 9 })),
    frag_steps = U.nums(deflt(r.frag_steps, { 15, 40, 90 })),
    starter_budget = deflt(r.starter_budget, 20),
    budget_step_phases = deflt(r.budget_step_phases, 5),
    budget_max = deflt(r.budget_max, 40),
    squad_size = deflt(r.squad_size, 11),
    starter_gift = deflt(r.starter_gift, true),
    gift_weights = U.nums(deflt(r.gift_weights, { 70, 25, 5 })),
    gift_cost_cap = deflt(r.gift_cost_cap, 15),
    bench_half = deflt(r.bench_half, false),
    staff_half = deflt(r.staff_half, false),
    gacha_players = deflt(r.gacha_players, 1),
    gacha_dupe_frags = deflt(r.gacha_dupe_frags, 10),
    team_screen = deflt(r.team_screen, "retail"),
    elite_bonus = deflt(r.elite_bonus, 3),
    boss_bonus = deflt(r.boss_bonus, 4),
    frags_win = deflt(r.frags_win, 1),
    frags_boss = deflt(r.frags_boss, 3),
    draw_is_loss = deflt(r.draw_is_loss, false),
    quit_is_loss = deflt(r.quit_is_loss, false),
    recruit_tiers = list_of_lists(r.recruit_tiers) or { { 1, 2 }, { 5, 3 }, { 12, 4 }, { 25, 5 } },
    whatif_recruit_pct = deflt(r.whatif_recruit_pct, 12),
    whatif_recruit_from = deflt(r.whatif_recruit_from, 4),
    whatif_gacha_pct = deflt(r.whatif_gacha_pct, 4),
    whatif_debug_fill = deflt(r.whatif_debug_fill, true),
    grant_without_role = deflt(r.grant_without_role, false),
  }
  -- the map curve, content table, coins and level curve: a bad table = the default (as the DLL's run init did)
  local curve, why = C.checked_curve(list_of_lists(r.map_curve) or C.DEFAULT_CURVE)
  if not curve then
    warn("[rogue] " .. why .. "; using the default curve")
    curve = C.DEFAULT_CURVE
  end
  c.map_curve = curve
  local content
  content, why = C.checked_content(list_of_lists(r.map_content) or C.DEFAULT_CONTENT)
  if not content then
    warn("[rogue] " .. why .. "; using the default content")
    content = C.DEFAULT_CONTENT
  end
  c.map_content = content
  local coins
  coins, why = C.checked_coins(list_of_lists(r.gacha_coins) or C.default_coins())
  if not coins then
    warn("[rogue] " .. why .. "; using the default coins")
    coins = C.default_coins()
  end
  c.gacha_coins = coins
  -- the rivals' level curve: InaRogue's growth (content\growth\growth.toml), unless [rogue] level_curve overrides it
  local lc = list_of_lists(r.level_curve) or Gr.get().rivals
  if not C.checked_level_curve(lc) then
    local _, w = C.checked_level_curve(lc)
    warn("[rogue] " .. tostring(w) .. "; using the growth curve")
    lc = Gr.get().rivals
  end
  c.level_curve = lc
  -- [rogue.rivals]
  local rv = type(r.rivals) == "table" and r.rivals or {}
  local eras = {}
  if type(rv.eras) == "table" then
    for k, v in pairs(rv.eras) do
      if type(v) == "table" then
        local f = {}
        for _, x in ipairs(v) do f[#f + 1] = tostring(x) end
        eras[#eras + 1] = { name = tostring(k), frags = f }
      end
    end
  end
  table.sort(eras, function(a, b) return a.name < b.name end) -- BTreeMap order
  local guests = {}
  if type(rv.guest) == "table" then
    for _, g in ipairs(rv.guest) do
      if type(g) == "table" and type(g.rival) == "string" and type(g.chara) == "number" and type(g.chance) == "number" then
        guests[#guests + 1] = { rival = g.rival, chara = g.chara % U.TWO32, slot = U.int(g.slot, 0), chance = g.chance }
      end
    end
  end
  local function strs(v, d)
    if type(v) ~= "table" then return d end
    local o = {}
    for _, x in ipairs(v) do o[#o + 1] = tostring(x) end
    return o
  end
  c.rivals = {
    emblematic = strs(rv.emblematic, {}),
    emblematic_on = strs(rv.emblematic_on, { "elite", "boss" }),
    guest = guests,
    eras = eras,
    ranks = deflt(rv.ranks, "content/rogue/rival_ranks.toml"),
    -- the VR-Framework random-team rules of the pool's slot rows (content\random_teams\rivals.toml)
    random_small = deflt(rv.random_small, "inarogue.minor_5v5"),
    random_full = deflt(rv.random_full, "inarogue.rival_11v11"),
  }
  -- [rogue.formations]
  local f = type(r.formations) == "table" and r.formations or {}
  c.formations = {
    enabled = deflt(f.enabled, true),
    drops = list_of_lists(f.drops) or C.DEFAULT_DROPS,
    rarity_weights = U.nums(deflt(f.rarity_weights, { 50, 30, 15, 5 })),
    start = U.nums(deflt(f.start, {})),
    unlock_all = deflt(f.unlock_all, false),
  }
  local okd, whyd = C.checked_drops(c.formations.drops, c.formations.rarity_weights)
  if not okd then
    warn("rogue formations: [rogue.formations] " .. whyd .. "; using the default drops")
    c.formations.drops = C.DEFAULT_DROPS
    c.formations.rarity_weights = { 50, 30, 15, 5 }
  end
  -- [rogue.points]
  local p = type(r.points) == "table" and r.points or {}
  c.points = {
    enabled = deflt(p.enabled, true),
    item = deflt(p.item, "inarogue.puntos_rogue"),
    win = U.nums(deflt(p.win, { 3, 5, 8, 15, 10, 25 })),
    phase_step = deflt(p.phase_step, 3),
    boss_per_phase = deflt(p.boss_per_phase, 2),
    run_end_per_phase = deflt(p.run_end_per_phase, 2),
    abandon_pct = deflt(p.abandon_pct, 50),
  }
  local function sub(name, file)
    local t = type(r[name]) == "table" and r[name] or {}
    return { enabled = deflt(t.enabled, true), file = deflt(t.file, file), unlock_all = deflt(t.unlock_all, false) }
  end
  c.avatars = sub("avatars", "content/rogue/avatars.toml")
  c.unlocks = sub("unlocks", "content/rogue/unlocks.toml")
  c.coaches = sub("coaches", "content/rogue/coaches.toml")
  c.bosses = sub("bosses", "content/rogue/bosses.toml")
  -- [rogue.album] unlock_all: debug, every item and team of the album's «Objetos» / «Equipos» shown as found
  local al = type(r.album) == "table" and r.album or {}
  c.album = { unlock_all = deflt(al.unlock_all, false) }
  local b = type(r.board) == "table" and r.board or {}
  c.board = { fog = deflt(b.fog, true), reveal_boss = deflt(b.reveal_boss, true) }
  cache = c
  info(string.format("settings: starter costs %s, starter budget %d +1 per %d best phases (max %d), capacity %d, debug_tools %s",
    table.concat(c.starter_cost, "/"), c.starter_budget, c.budget_step_phases, c.budget_max, c.bank_capacity,
    tostring(c.debug_tools)))
  return c
end

-- ---------------------------------------------------------------------------------------- rules of the settings

-- squad budget of phase `phase` (1-based; 0 = 1)
function C.budget(c, phase)
  return c.squad_budget + c.budget_per_phase * (math.max(phase, 1) - 1)
end

-- highest tier a Fichaje may offer in `phase`
function C.recruit_max_tier(c, phase)
  local p = math.max(phase, 1)
  local best = nil
  for _, r in ipairs(c.recruit_tiers) do
    if #r == 2 and r[1] <= p then best = r[2] end
  end
  if best == nil then return 2 end
  return U.clamp(best, 1, 5)
end

function C.whatif_recruit(c, phase, roll)
  return c.whatif_recruit_pct > 0 and math.max(phase, 1) >= c.whatif_recruit_from and roll % 100 < math.min(c.whatif_recruit_pct, 100)
end

function C.whatif_gacha(c, roll)
  return c.whatif_gacha_pct > 0 and roll % 100 < math.min(c.whatif_gacha_pct, 100)
end

-- the cost's stat bonus: round((total - ref) / step) clamped to [min, max]; 0 without per-player stats
function C.stat_bonus(c, total)
  if total == 0 or c.cost_stat_step <= 0 then return 0 end
  local b = U.round((total - c.cost_stat_ref) / c.cost_stat_step)
  return U.clamp(b, math.min(c.cost_stat_min, c.cost_stat_max), math.max(c.cost_stat_max, c.cost_stat_min))
end

-- cost of a player: cost_base[tier] + stat bonus, never below 1
function C.cost(c, tier, total)
  local t = U.clamp(tier, 1, 5)
  local base = c.cost_base[t] or c.cost_base[#c.cost_base] or t * 2
  return math.max(base + C.stat_bonus(c, total), 1)
end

return C
