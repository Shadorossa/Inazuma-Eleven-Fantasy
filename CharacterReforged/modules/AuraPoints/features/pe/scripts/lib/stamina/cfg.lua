-- Aura Points › PE: the PE rules' and tired locomotion's settings ([pe], [pe.trait.*], [tired_motion] of config.toml;
-- docs/game/mechanics/aura-costs.md, docs/game/media/cs-exhausted-walk.md §9) with their defaults. The mod Stamina
-- Points' scripts/lib/cfg.lua until 2026-10-16 (Inazuma Fantasy's scripts/lib/stamina/cfg.lua, [aura_cost], until
-- 2026-10-14; the armour's tension discount, not a PE rule, stayed there).

local M = {}

local function num(v, d)
  v = tonumber(v)
  if v == nil or v ~= v then return d end
  return v
end

local function pos_or(v, d)
  v = tonumber(v)
  if v ~= nil and v == v and v >= 0 and v < math.huge then return v end
  return d
end

local function bool(v, d)
  if v == nil then return d end
  return v == true
end

local function list(v, d)
  if type(v) ~= "table" then return d end
  return v
end

local AURA_WORD = { [0] = "keshin", [1] = "armour", [2] = "miximax", [3] = "soul" }

local function listed(l, ty)
  local k = AURA_WORD[ty]
  if not k then return false end
  for _, s in ipairs(l) do
    s = string.lower((tostring(s):gsub("^%s+", ""):gsub("%s+$", "")))
    if s == k or (k == "armour" and (s == "armor" or s == "armed")) then return true end
  end
  return false
end

-- The [pe] table (merged config) as the run time uses it.
function M.pe(t)
  t = t or {}
  local c = {
    enabled = bool(t.enabled, true),
    free_activation_list = list(t.free_activation, { "miximax" }),
    no_start_check = list(t.no_start_check, { "miximax" }),
    miximax_untimed = bool(t.miximax_untimed, true),
    miximax_pe_mult = num(t.miximax_pe_mult, 1.25),
    armour_pe_mult = num(t.armour_pe_mult, 1.05),
    miximax_armour_pe_mult = num(t.miximax_armour_pe_mult, 1.30),
    miximax_end_pe = num(t.miximax_end_pe, 0.0),
    cpu = bool(t.cpu, true),
    cost_model = string.lower(tostring(t.cost_model or "cs")),
    miximax_carriers = list(t.miximax_carriers, {}),
    cs_pe_free_while_out = bool(t.cs_pe_free_while_out, true),
    cs_end_pe_k = t.cs_end_pe_k == nil and 0.3 or t.cs_end_pe_k,
    cs_end_stat_k = t.cs_end_stat_k == nil and 0.00133 or t.cs_end_stat_k,
    cs_end_armour_mult = t.cs_end_armour_mult == nil and 1.2 or t.cs_end_armour_mult,
    cs_end_grace_ms = num(t.cs_end_grace_ms, 500),
    cs_end_follows_level = bool(t.cs_end_follows_level, true),
    cs_miximax_pe_mult = t.cs_miximax_pe_mult == nil and 5.0 or t.cs_miximax_pe_mult,
    drain_log_s = num(t.drain_log_s, 5.0),
    clip_gauge_end = tostring(t.clip_gauge_end or ""),
  }
  c.cs_on = c.enabled and c.cost_model:match("^%s*cs%s*$") ~= nil
  function c.cs() return c.cs_on end
  local scale = pos_or(t.cs_scale == nil and 0.75 or t.cs_scale, 1.0)
  function c.cs_scale() return scale end
  -- the engine's start pay is skipped for the listed kinds (a keshin / armour / totem on its pool: Aura Points' own
  -- free start, its ProcessPending provider)
  function c.free_activation(ty)
    if not c.enabled or AURA_WORD[ty] == nil then return false end
    return listed(c.free_activation_list, ty)
  end
  function c.start_check_waived(ty)
    return c.enabled and AURA_WORD[ty] ~= nil and listed(c.no_start_check, ty)
  end
  -- the three PE multipliers (miximax, armour, both); CS: the miximax's cs_miximax_pe_mult × cs_scale, the armour 1
  function c.pe_mults()
    if c.cs() then
      local mx = pos_or(c.cs_miximax_pe_mult, 1.0) * c.cs_scale()
      return mx, 1.0, mx
    end
    return c.miximax_pe_mult, c.armour_pe_mult, c.miximax_armour_pe_mult
  end
  function c.pe_mult(miximax, armour)
    if not c.enabled then return 1.0 end
    local mx, ar, both = c.pe_mults()
    local m = 1.0
    if miximax and armour then m = both elseif miximax then m = mx elseif armour then m = ar end
    if m == m and m > 0 and m < math.huge then return m end
    return 1.0
  end
  function c.pe_free(keshin, armour) return c.cs() and c.cs_pe_free_while_out and (keshin or armour) end
  -- CS: the PE charged once when a keshin / armour run ends
  function c.end_pe_charge(kp, fisico, armour)
    if not c.cs() then return 0 end
    local f = (fisico == fisico and fisico or 0)
    f = math.max(f, 0)
    local stat = math.max(1 - pos_or(c.cs_end_stat_k, 0) * f, 0)
    local m = armour and pos_or(c.cs_end_armour_mult, 1.0) or 1.0
    return pos_or(c.cs_end_pe_k, 0) * math.max(kp, 0) * stat * c.cs_scale() * m
  end
  function c.miximax_pe_out(cur, max)
    return max > 0 and cur <= math.max(c.miximax_end_pe, 0) * max + 1e-4
  end
  c.traits = M.traits(t.trait)
  return c
end

-- [pe.trait.<tag>] (aura-costs.md §11): what a trait tag (VRFW.Traits, declared by any mod on its characters) does
-- with the PE; no section = no trait rule. (`hiper` is not read here: a mod's own Hiper slot rule.)
function M.traits(t)
  local function rule(r)
    r = r or {}
    local ids = {}
    for _, k in ipairs(r.keshins or {}) do
      if type(k) == "number" then
        ids[#ids + 1] = k
      elseif type(k) == "string" then
        local h = k:match("^%s*0[xX](%x+)%s*$")
        if h then ids[#ids + 1] = tonumber(h, 16) else ids[#ids + 1] = ((VRFW.ui.crc32((k:gsub("%s", ""))) or 0) % 4294967296) end
      end
    end
    local when = string.lower(tostring(r.battery_out or "never"))
    if when == "keshin" then when = "aura" elseif when == "pe" then when = "always" end
    if when ~= "aura" and when ~= "always" then when = "never" end
    local pm = tonumber(r.pe_mult) or 1.0
    return {
      keshins = ids,
      gauge_drain = bool(r.gauge_drain, true),
      pe_mult = (pm == pm and pm > 0) and pm or 1.0,
      battery_out = when,
      battery_keep_armour = bool(r.battery_keep_armour, true),
      battery_clip = tostring(r.battery_clip or ""),
      battery_hold = tostring(r.battery_hold == nil and "aura_points.battery_out" or r.battery_hold),
      battery_hold_after_ms = num(r.battery_hold_after_ms, 3000),
    }
  end
  local out = {}
  if type(t) == "table" then
    for tag, r in pairs(t) do out[string.lower(tag)] = rule(r) end
  end
  return out
end

-- What a player's tags do with `auras` running (the keshin of each running keshin / armour). Several tags: gauge drain
-- only if no matched rule stops it; multipliers multiply; battery if any arms it.
function M.effect(rules, tags, auras)
  local e = { aura_rule = false, gauge_drain = true, pe_mult = 1.0, battery = false, keep_armour = true,
    clip = "", hold = "", hold_after_ms = 0, tags = {} }
  for _, tg in ipairs(tags or {}) do
    local r = rules[string.lower(tg)]
    if r then
      e.tags[#e.tags + 1] = tg
      local matched = false
      for _, a in ipairs(auras) do
        if a ~= 0 then
          for _, k in ipairs(r.keshins) do
            if k == a then matched = true end
          end
        end
      end
      if matched then
        e.aura_rule = true
        e.gauge_drain = e.gauge_drain and r.gauge_drain
        e.pe_mult = e.pe_mult * r.pe_mult
        e.keep_armour = e.keep_armour and r.battery_keep_armour
      end
      local arms = (r.battery_out == "always") or (r.battery_out == "aura" and matched)
      if arms and not e.battery then
        e.battery = true
        e.clip = r.battery_clip
        e.hold = r.battery_hold
        e.hold_after_ms = r.battery_hold_after_ms
      end
    end
  end
  return e
end

-- The PE multiplier with the tags' effect: the rule's aura replaces the armour's share, × the miximax's.
function M.trait_pe_mult(mx_m, ar_m, both_m, miximax, armour, e)
  local base = 1.0
  if miximax and armour then base = both_m elseif miximax then base = mx_m elseif armour then base = ar_m end
  if not e.aura_rule then return base end
  return (miximax and mx_m or 1.0) * e.pe_mult
end

-- [tired_motion]
function M.tired(t)
  t = t or {}
  local function range(v, d)
    if type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then return { tonumber(v[1]), tonumber(v[2]) } end
    return d
  end
  return {
    enabled = bool(t.enabled, true),
    run_below = num(t.run_below, 0.10),
    run_recover = num(t.run_recover, 0.15),
    run_sets = list(t.run_sets, { "aura_points.tired_cs", "aura_points.tired_vr" }),
    run_weights = list(t.run_weights, {}),
    reroll_match = string.lower(tostring(t.reroll or "episode")) == "match",
    idle_set = tostring(t.idle_set == nil and "aura_points.tired_idle" or t.idle_set),
    idle_at = num(t.idle_at, 0.0),
    idle_every_s = range(t.idle_every_s, { 6.0, 14.0 }),
    idle_for_s = range(t.idle_for_s, { 1.2, 2.4 }),
    idle_speed = num(t.idle_speed, 0.0),
    idle_states = list(t.idle_states, { 9 }),
    keepers = bool(t.keepers, false),
    cpu = bool(t.cpu, true),
  }
end

return M
