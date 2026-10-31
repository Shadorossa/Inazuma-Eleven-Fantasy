-- Aura Points › PE: the match PE's rules (docs/game/mechanics/match-stamina.md, aura-costs.md, docs/game/media/
-- cs-exhausted-walk.md §9; docs/refactor/aura-mods-split.md «Stamina Points»). The option feature features\pe\ of the
-- mod: read only while the option row «pe» is on (options.toml; off = no PE, retail). Declarations:
-- features\pe\content\game\stamina.toml; settings: [pe], [pe.trait.*], [tired_motion], [hud_hidden_layers] of the
-- mod's config.toml. The mod Stamina Points' scripts\stamina_points.lua until 2026-10-16 (split out of Inazuma
-- Fantasy's scripts\stamina.lua on 2026-10-14).
--
-- The PE is the VR-Framework's match resource aura_points.pe (alias stamina_points.pe; features\pe\content\
-- match_resources\pe.toml: drain, Físico, «exhausted», half-time, the match boundaries, the pe_sacrifice payer; the max
-- of every character: pe_max.toml). This script does the rest, once per match frame (`tick`), per player on the pitch:
--   * the transformation costs on the PE: the miximax (the game's Mix-Max, a mod's carrier, the miximax of a mod's
--     extra slot) has no time limit and ends at 0 PE; the PE multiplier of a transformation (0 while the Chrono Stone
--     model runs a keshin / armour free of PE) on the resource as the drain multiplier `aura_points.aura`; the CS end
--     charge of a keshin / armour run (its KP: the keshin's PEG pool while the option «peg» is on, else kp_default);
--   * the tables the native answers of AuraCostCheck read (a miximax starts at any gauge) and the free miximax start;
--   * the battery out of the character traits ([pe.trait.*]: tags any mod declares) and the tired locomotion;
--   * the HUD commands CMND_AURAPOINTS_STAMINA / _STAMINA_MAX / CMND_AURAPOINTS_HUD_HIDDEN_LAYERS (aliases
--     CMND_STAMINAPOINTS_GP / _PE_MAX / _HUD_HIDDEN_LAYERS, CMND_EVT_GP / _PE_MAX).
--
-- Inputs other mods give through rule flags (no `requires` needed; the same flags as the PEG / SP pools'):
--   aura_points.cost_pct.<hdl>     (1..) percent of that player's transformation PE extra (the multiplier's part above
--                                  1) and of his CS end charge (0 / unset = 100 %; Inazuma Fantasy: «Limitador activo»)
--   aura_points.armour_free.<hdl>  (non-zero) his armour's time stays full (Inazuma Fantasy: «Modo Overdrive»)
--   (the mod Stamina Points' names stamina_points.cost_pct.<hdl> / stamina_points.armour_free.<hdl> are read too)
-- Other mods' own drain factors and half-time bonuses go straight to the resource (VRFW.resource.set_mult /
-- resource:aura_points.pe:half_time). Given to the PEG / SP pools (rule flag aura_points.exempt.<hdl>): a trait rule or
-- the battery out owns that player's aura time.

AuraPoints = AuraPoints or {}
local R = {}

local C = require "lib/stamina/cfg"
local A = require "lib/stamina/auras"
local T = require "lib/stamina/tired"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("aura_points stamina")

local RAW = VRFW.files.config("pe") or {}
local AC = C.pe(RAW)
local TM = C.tired(VRFW.files.config("tired_motion"))
A.set_carriers(AC.miximax_carriers)

local PE = "aura_points.pe"
local SPRINT = "aura_points.sprint"  -- the sprint bar (features\pe\content\match_resources\sprint.toml)
local KEY_AURA_MULT = "aura"   -- the drain multiplier's source (aura_points.aura on the resource)
local AP_PEG = "aura_points.peg"

-- the mod's option rows (options.toml; restart = true: the values the game started with). No answer = on (default).
local function option_on(id)
  local ok, v = pcall(VRFW.option, id)
  if not ok or v == nil then return true end
  return v ~= 0 and v ~= false
end
local PEG_ON, SP_ON = option_on("peg"), option_on("sp")
local KP_DEFAULT = tonumber(RAW.kp_default) or 200

-- game layout (docs/game/mechanics/match-stamina.md §6 / §10, aura-costs.md)
local Actors = require "VRFW/lib/actors"
local MI_TEAMS, TEAM_STRIDE, TEAM_ON_PITCH = 0x60, 0x1130, 0x1050
local MI_HALF_LEN, MI_HALF, MI_USER_TEAM = 0x1C, 0x2BFB, 0x2C29
local MEM_LINK_SLOT, MEM_POSITION, MEM_FLAGS, MEM_SENT_OFF = 0x68, 0x71, 0x7A, 0x08
local CTRL_BY_TEAM = 0x60
local PEND_FLAG_NO_COST, PEND_FLAG_HYPER_GAUGE = 0x08, 0x10
local Live = require "VRFW/lib/match_live"
local IN_PLAY = Live.states().in_play
local MIN_LEFT_S = 0.5
local REREAD_MS = 10000

local band = bit32.band

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if not at or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function flag(name) return VRFW.flag(name) or 0 end

-- the match clock: frame-based while a synced match runs (docs/game/modes/bb-p2p-lockstep.md)
local function now_ms() return VRFW.match.clock() end

local Id = require "VRFW/lib/ids"
local hex = Id.hex
local function key_of(id) return A.key(id) end
local function clock_text(c)
  local s = math.max(math.floor(c or 0), 0)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function ends_match(s) return s == 2 or s == 3 or s == 6 or s == 7 or s == 8 or s == 22 or s == 24 end
local function restarts_play(s) return s == 9 or s == 10 end

-- ---------------------------------------------------------------------------------------------- the PE declaration

local DECL = { max = 134, live = Live.states().live, duel = Live.states().duel,
  exhausted_bit = nil, speed = 1.0, speed_duel = 1.0 }
do
  local t = VRFW.files.toml("features/pe/content/match_resources/pe.toml")
  local r = t and t.VRFW and t.VRFW.MatchResource and t.VRFW.MatchResource[1]
  if r then
    DECL.max = tonumber(r.max) or DECL.max
    if r.live_states then
      DECL.live = {}
      for _, s in ipairs(r.live_states) do DECL.live[s] = true end
    end
    if r.duel_states then
      DECL.duel = {}
      for _, s in ipairs(r.duel_states) do DECL.duel[s] = true end
    end
    for i, s in ipairs(r.state or {}) do
      if s.name == "exhausted" then
        DECL.exhausted_bit = i - 1
        DECL.speed = tonumber(s.speed_mult) or 1.0
        DECL.speed_duel = tonumber(s.speed_mult_duel) or DECL.speed
      end
    end
  else
    warn("features/pe/content/match_resources/pe.toml not readable: the defaults")
  end
end

local function exhausted_of(v)
  return DECL.exhausted_bit ~= nil and v ~= nil and band(v.state_bits or 0, 2 ^ DECL.exhausted_bit) ~= 0
end

-- ---------------------------------------------------------------------------------------------- per-match state

local seen = { in_match = false, ended = false, scene = 0, half = 0, clock = 0, end_half = 0 }
local match_no = 0
local frame = { state = 0, half = 0, clock = 0, half_len = 0, user = 0xFF, mi = nil, dt = 0, now = 0 }
local players = {}      -- hdl -> player record (this match)
local slots = {}        -- hdl -> the extra slot state this frame (VRFW.extra_slot.players(): swap, fusion)
local match_start_ms = 0
local cost_teams_user = nil

local function rng() return VRFW.match.rng() or math.random() end

local function new_player(hdl)
  return {
    -- the other mods' input flags of this player (rule flags, see cost_cut / armour_free)
    flags = { cost = "aura_points.cost_pct." .. hdl, cost_old = "stamina_points.cost_pct." .. hdl,
      free = "aura_points.armour_free." .. hdl, free_old = "stamina_points.armour_free." .. hdl },
    hdl = hdl, team = 0xFF, slot = nil, member = nil, chara = 0, param = 0, pos = 0xFF, fisico = 0,
    unit_ms = -REREAD_MS, tags = nil, tags_param = 0,
    tr = { keshin = false, armour = false, miximax = false, cut_keshin = false, cut_armour = false, cut_mx = false,
      keshin_skill = 0, meta_skill = 0, rule_on = false, out_run = false, out_armour = false, out_kp = 0, out_cut = 1,
      out_gone_ms = 0 },
    mult = 1.0, hud_mult = 1.0, mx = nil, tired = T.new_track(), loco = nil, pause = false, battery = nil,
  }
end

-- ---------------------------------------------------------------------------------------------- tables (diffs)

-- Record tables of the mod (exported, mod.toml [exports] tables; a missing field = the answers using it do not apply):
--   AuraPoints.StaminaPlayer (hdl): battery_out (0), miximax (1 while his miximax runs on PE);
--   AuraPoints.StaminaTeam (team): cost (the PE rules apply to it).
local recs = {}

local function rec_of(name, key)
  local t = recs[name]
  if not t then
    t = {}
    recs[name] = t
  end
  local k = type(key) == "table" and table.concat(key, ":") or key
  local r = t[k]
  if not r then
    r = { key = key, fields = {}, dirty = false }
    t[k] = r
  end
  return r
end

local function rset(name, key, field, value)
  local r = rec_of(name, key)
  if r.fields[field] ~= value then
    r.fields[field] = value
    r.dirty = true
  end
end

local function pset(hdl, field, value) rset("AuraPoints.StaminaPlayer", hdl, field, value) end
local function teamset(team, field, value) rset("AuraPoints.StaminaTeam", team, field, value) end

local function flush_records()
  for name, t in pairs(recs) do
    for _, r in pairs(t) do
      if r.dirty then
        r.dirty = false
        local v = next(r.fields) ~= nil and r.fields or nil
        pcall(VRFW.native.table_set, name, r.key, v)
      end
    end
  end
end

-- Resource.OffPitch (hdl -> 0): the battery-out players, exported to the VR-Framework's OffPitch rule
-- (content\resource_rules\off_pitch.toml, docs/framework/match-resource.md §10)
local OFF_PITCH = "Resource.OffPitch"

local function off_pitch_set(hdl, on)
  pcall(VRFW.native.table_set, OFF_PITCH, hdl, on and 0 or nil)
end

local function clear_match_tables()
  for _, n in ipairs({ "AuraPoints.StaminaPlayer", "AuraPoints.StaminaTeam" }) do
    recs[n] = {}
    pcall(VRFW.native.table_clear, n)
  end
  pcall(VRFW.native.table_clear, OFF_PITCH)
  flush_records()
end

-- ---------------------------------------------------------------------------------------------- PEG / SP pools

-- the rule flag aura_points.exempt.<hdl>: a trait rule / the battery out owns his aura time (no PEG pool for him)
local function ap_exempt(p, on)
  local v = on and 1 or nil
  if p.ap_exempt == v then return end
  p.ap_exempt = v
  local key = "aura_points.exempt." .. p.hdl
  if v then pcall(VRFW.set_flag, key, v) else pcall(VRFW.clear_flag, key) end
end

-- the KP of a keshin (its PEG pool size while the option «peg» is on; kp_default otherwise)
local function keshin_kp(k)
  if not k or k == 0 or not PEG_ON then return KP_DEFAULT end
  local ok, pi = pcall(VRFW.resource.pool, AP_PEG, k)
  if ok and type(pi) == "table" and type(pi.max) == "number" and pi.max > 0 then return pi.max end
  return KP_DEFAULT
end

-- his level's share of the end charge: his full bar / his card's bar at the table's reference level (1 with
-- cs_end_follows_level off), so the charge takes the same share of the bar at every level
local function level_ratio(p, pe)
  if not AC.cs_end_follows_level or not pe or type(pe.max) ~= "number" or pe.max <= 0 then return 1 end
  if p.level_ratio_max ~= pe.max then
    local card = (p.param and p.param ~= 0) and p.param or nil
    local ok, ref = pcall(VRFW.resource.max, PE, card)
    p.level_ratio = (ok and type(ref) == "number" and ref > 0) and pe.max / ref or 1
    p.level_ratio_max = pe.max
  end
  return p.level_ratio
end

-- the other mods' inputs for one player (rule flags; the mod Stamina Points' old names are read too)
local function cost_cut(p)
  local v = flag(p.flags.cost)
  if not (v and v > 0) then v = flag(p.flags.cost_old) end
  if v and v > 0 then return math.min(v, 100) / 100 end
  return 1.0
end
local function armour_free(p)
  return flag(p.flags.free) ~= 0 or flag(p.flags.free_old) ~= 0
end

-- the part of a multiplier above 1 cut to f (a cut never makes a transformation cheaper than no transformation)
local function cut_mult(mult, f)
  if mult > 1 then return 1 + (mult - 1) * f end
  return mult
end

-- ---------------------------------------------------------------------------------------------- match frame

local function team_rec(team) return frame.mi and (frame.mi + MI_TEAMS + team * TEAM_STRIDE) or nil end

local function cost_teams()
  local u = frame.user
  if cost_teams_user == u then return end
  cost_teams_user = u
  for team = 0, 1 do
    teamset(team, "cost", AC.enabled and 1 or nil)
  end
end

local function applies(team) return AC.enabled and (team == 0 or team == 1) end   -- both teams (owner 2026-10-19)

local function start_match()
  match_no = match_no + 1
  for hdl, p in pairs(players) do
    if p.loco then pcall(VRFW.locomotion.set, hdl, nil) end
    ap_exempt(p, false)
  end
  players = {}
  clear_match_tables()
  cost_teams_user = nil
  match_start_ms = now_ms()
  info(string.format("match #%d start: h%d clock %s half length %d game-s, user team %d (PE: %s)", match_no, frame.half,
    clock_text(frame.clock), frame.half_len, frame.user, PE))
end

local function end_match(why)
  seen.ended = true
  seen.end_half = frame.half
  info(string.format("match #%d %s: h%d clock %s, real %.1fs; every PE back to full (the framework's)", match_no, why,
    frame.half, clock_text(frame.clock), (now_ms() - match_start_ms) / 1000))
  R.aura_reset()
  R.tired_reset()
  R.battery_match_end()
  for _, p in pairs(players) do ap_exempt(p, false) end
end

-- the match boundaries (match-stamina.md §13.1, the framework's own rule for the PE)
local function boundary(f)
  if f.half == 0 then return "same" end
  if not seen.in_match or f.scene ~= seen.scene or f.half < seen.half or (f.half == seen.half and f.clock + 60 < seen.clock) then
    return "new"
  end
  if seen.ended and restarts_play(f.state) then
    if f.half > seen.end_half then return "resume" end
    return "new"
  end
  return "same"
end

local last_state = 0
local BOUNDARY_FACTS = { half = 0, scene = 0, clock = 0, state = 0 }   -- (filled again every frame)

local function frame_update()
  local bf = BOUNDARY_FACTS
  bf.half, bf.scene, bf.clock, bf.state = frame.half_len ~= 0 and frame.half or 0, frame.scene, frame.clock, frame.state
  local b = boundary(bf)
  if b == "new" then
    if seen.in_match and not seen.ended then end_match("ended (new match detected)") end
    seen = { in_match = true, ended = false, scene = frame.scene, half = frame.half, clock = frame.clock, end_half = 0 }
    last_state = frame.state
    start_match()
  elseif b == "resume" then
    seen.ended = false
    info(string.format("match #%d resumes in half %d after an end state (half %d)", match_no, frame.half, seen.end_half))
  end
  if not seen.in_match then return end
  cost_teams()
  R.battery_frame(not seen.ended)
  if frame.state ~= last_state then
    last_state = frame.state
    if ends_match(frame.state) and not seen.ended then end_match("full time (state " .. frame.state .. ")") end
  end
  seen.half = frame.half
  seen.clock = frame.clock
end

-- ---------------------------------------------------------------------------------------------- per player data

local function member_info(p, unit)
  local m = unit and unit.member or 0
  if m and m >= 0x10000 then
    p.member = m
    p.slot = rd("u32", m + MEM_LINK_SLOT)
    p.pos = rd("u8", m + MEM_POSITION) or 0xFF
  end
end

local NO_TAGS = {}   -- (read only)
local NO_SLOT = {}   -- (read only)

-- his trait tags (asked once per card)
local function tags_of(p)
  if p.param == 0 then return NO_TAGS end
  if p.tags and p.tags_param == p.param then return p.tags end
  local ok, tags = pcall(VRFW.traits.of, p.param)
  if not ok or tags == nil then return NO_TAGS end
  p.tags, p.tags_param = tags, p.param
  local e = C.effect(AC.traits, tags, {})
  if #e.tags > 0 then
    info(string.format("traits: actor %s card 0x%08X: tags %s -> rules %s%s", hex(p.hdl), p.param, table.concat(tags, ","),
      table.concat(e.tags, ","), e.battery and ", battery out at 0 PE" or ""))
  end
  return tags
end

-- ---------------------------------------------------------------------------------------------- the aura step

local function hold_left(full, ratio)
  if not (full == full and full > 0) then full = 60 end
  if ratio ~= ratio then ratio = 1 end
  ratio = math.min(math.max(ratio, 0), 1)
  return math.max(full * ratio, MIN_LEFT_S)
end

-- One player's transformations this frame. Returns obs.
local function aura_step(p, actor, a, unit, pe)
  -- (his own table, filled again every frame)
  local obs = p.obs
  if obs == nil then
    obs = {}
    p.obs = obs
  end
  obs.mult, obs.keshin, obs.armour, obs.miximax, obs.effect, obs.pe_free, obs.pe_charge = 1.0, false, false, false, nil, false, 0
  local hdl, team = p.hdl, p.team
  local now = frame.now
  local attr = unit and unit.attr or 0
  local ss, ms = a.summon_state, a.meta_state
  local meta_run = ms == 4 or ms == 5
  local keshin = band(attr, 1) ~= 0 and ss == 2
  local armour = band(attr, 2) ~= 0 and meta_run
  local free_armour = armour and armour_free(p)
  local es = slots[hdl] or NO_SLOT
  local mode_change = es.swap == true
  local mx_meta = band(attr, 4) ~= 0 and meta_run and band(attr, 2) == 0 and not mode_change
  local mx_slot = (es.fusion or 0) ~= 0
  local miximax = mx_meta or mx_slot
  -- the other mods' cost cut: read only when a transformation runs (it scales only a transformation's PE)
  local cut = (keshin or armour or miximax) and cost_cut(p) or 1.0
  local ok_team = applies(team)
  local in_play = frame.state == IN_PLAY
  -- out of PE in play: his mix slot's miximax is spent for the match (VRFW.extra_slot.spent: no RB plate, start refused)
  if ok_team and in_play and pe and not p.mx_spent and AC.miximax_pe_out(pe.cur, pe.max) then
    local mx = es.mix or 0
    if mx ~= 0 and A.is_miximax(mx) then
      p.mx_spent = true
      local ok, done = pcall(VRFW.extra_slot.spent, hdl, mx, true)
      info(string.format("miximax: actor %s T%d: out of PE: %s spent for the match, its summon plate is gone%s", hex(hdl), team, key_of(mx),
        (ok and done) and "" or " (the plates service did not take it)"))
    end
  end
  -- character traits ([pe.trait.*]): his tags and the keshins behind his running auras
  local tags = tags_of(p)
  local aura1, aura2 = keshin and a.summon_skill or 0, armour and (A.spirit(a.meta_skill) or a.meta_skill) or 0
  -- (the same tags and auras give the same effect: worked out again only when one of them changed)
  local effect = p.effect
  if effect == nil or p.effect_tags ~= tags or p.effect_aura1 ~= aura1 or p.effect_aura2 ~= aura2 then
    effect = C.effect(AC.traits, tags, { aura1, aura2 })
    p.effect, p.effect_tags, p.effect_aura1, p.effect_aura2 = effect, tags, aura1, aura2
  end
  obs.effect = effect
  local gauge_free = effect.aura_rule and not effect.gauge_drain
  local battery = p.battery and p.battery.phase == "pending"
  local quiet = battery or (p.battery and p.battery.phase == "out")
  if quiet then pcall(VRFW.aura_end.hold, hdl, 1000) end
  local tr = p.tr
  if effect.aura_rule ~= tr.rule_on then
    tr.rule_on = effect.aura_rule
    if effect.aura_rule then
      info(string.format("trait rule %s: actor %s T%d: aura out: hyper gauge %s, PE x%.2f%s", table.concat(effect.tags, ","), hex(hdl), team,
        effect.gauge_drain and "drains" or "not spent", effect.pe_mult, effect.battery and ", battery out at 0 PE" or ""))
    else
      info(string.format("trait rule %s: actor %s T%d: its aura is over (normal rules)", table.concat(effect.tags, ","), hex(hdl), team))
    end
  end
  ap_exempt(p, (battery or quiet) or (gauge_free and (keshin or armour)))

  if battery and (keshin or armour) then
    -- battery out: the spirit leaves now (the engine ends it in play), the armour as the rule says
    if keshin and in_play then
      wr("f32", actor + 0x370, 0)
      if not tr.cut_keshin then
        tr.cut_keshin = true
        info(string.format("battery out: actor %s T%d: keshin %s dismissed (time 0; the engine ends it in play)", hex(hdl), team, key_of(a.summon_skill)))
      end
    elseif keshin then
      wr("f32", actor + 0x370, hold_left(a.summon_full, 1))
    end
    if armour then
      if effect.keep_armour or not in_play or free_armour then
        wr("f32", actor + 0x39C, hold_left(a.meta_full, 1))
      else
        wr("f32", actor + 0x39C, 0)
        if not tr.cut_armour then
          tr.cut_armour = true
          info(string.format("battery out: actor %s T%d: armour ends (the rule keeps no armour)", hex(hdl), team))
        end
      end
    end
  elseif gauge_free and (keshin or armour) then
    -- the rule's aura lasts while his PE lasts: its time follows the PE; at 0 PE the battery out takes over
    local ratio = (pe and pe.max > 0) and pe.cur / pe.max or 1
    if keshin then wr("f32", actor + 0x370, hold_left(a.summon_full, ratio)) end
    if armour then wr("f32", actor + 0x39C, hold_left(a.meta_full, free_armour and 1 or ratio)) end
  elseif ok_team and (keshin or armour) and AC.cs() then
    -- CS: the run's PE is charged once when it ends (its KP: Aura Points' pool of the keshin, else kp_default)
    tr.out_run = true
    tr.out_armour = tr.out_armour or armour
    tr.out_kp = keshin_kp(armour and A.spirit(a.meta_skill) or a.summon_skill)
    tr.out_cut = cut
  end

  if free_armour then
    -- another mod's «armour without end»: his armour's time stays full whatever ran above
    wr("f32", actor + 0x39C, hold_left(a.meta_full, 1))
  end

  -- the miximax: untimed while PE lasts; at 0 PE it ends (under an armour: only the extra slot's miximax)
  if ok_team and miximax and AC.miximax_untimed then
    local cur, max = pe and pe.cur or 1, pe and pe.max or 1
    local out = in_play and AC.miximax_pe_out(cur, max)
    if mx_meta then
      if not out then
        wr("f32", actor + 0x39C, hold_left(a.meta_full, max > 0 and cur / max or 1))
      else
        wr("f32", actor + 0x39C, 0)
      end
    end
    if out and not tr.cut_mx then
      tr.cut_mx = true
      if mx_slot and armour then
        pcall(VRFW.extra_slot.fusion_end, hdl)
        info(string.format("miximax: actor %s T%d: PE %.1f/%.0f: the extra slot's miximax ends, the armour stays", hex(hdl), team, cur, max))
      else
        info(string.format("miximax: actor %s T%d: PE %.1f/%.0f: the miximax ends (time 0; the engine ends it in play)", hex(hdl), team, cur, max))
      end
    end
  end
  pset(hdl, "miximax", (ok_team and miximax) and 1 or nil)

  -- ends
  if tr.keshin and not keshin then tr.cut_keshin = false end
  if tr.armour and not armour then tr.cut_armour = false end
  if tr.miximax and not miximax then
    info(string.format("miximax: actor %s T%d over (meta state %d, unit attr 0x%02X)%s", hex(hdl), team, ms, attr, tr.cut_mx and ": 0 PE" or ""))
    tr.cut_mx = false
  end
  if not keshin then tr.cut_keshin = false end
  if not armour then tr.cut_armour = false end
  tr.keshin, tr.armour, tr.miximax = keshin, armour, miximax
  if keshin then tr.keshin_skill = a.summon_skill end
  if armour then tr.meta_skill = a.meta_skill end

  -- CS: the keshin / armour run is over (neither is out now): its PE is charged once
  if not (tr.out_run and not keshin and not armour) then
    tr.out_gone_ms = 0
  elseif tr.out_gone_ms == 0 then
    tr.out_gone_ms = math.max(now, 1)
  end
  if tr.out_run and not keshin and not armour and now - tr.out_gone_ms >= AC.cs_end_grace_ms then
    local lr = level_ratio(p, pe)
    obs.pe_charge = AC.end_pe_charge(tr.out_kp, p.fisico, tr.out_armour) * tr.out_cut * lr
    info(string.format("CS end charge: actor %s T%d: %s run over: PE -%.1f once (KP %.0f, Fisico %d%s%s%s; PE %s)", hex(hdl), team,
      tr.out_armour and "keshin + armour" or "keshin", obs.pe_charge, tr.out_kp, p.fisico, tr.out_armour and string.format(", x%s armour", AC.cs_end_armour_mult) or "",
      tr.out_cut < 1 and string.format(", x%.2f cost_pct", tr.out_cut) or "", math.abs(lr - 1) > 0.001 and string.format(", x%.2f level", lr) or "",
      pe and string.format("%.1f/%.0f before", pe.cur, pe.max) or "?"))
    tr.out_run = false
    tr.out_armour = false
    tr.out_gone_ms = 0
  end
  local mx_m, ar_m, both_m = AC.pe_mults()
  local mult
  if effect.aura_rule then
    mult = C.trait_pe_mult(mx_m, ar_m, both_m, miximax, armour, effect)
  elseif ok_team then
    mult = AC.pe_mult(miximax, armour)
  else
    mult = 1.0
  end
  obs.mult = cut_mult(mult, cut)
  obs.keshin, obs.armour, obs.miximax = keshin, armour, miximax
  obs.pe_free = ok_team and not effect.aura_rule and AC.pe_free(keshin, armour)
  return obs
end

-- ---------------------------------------------------------------------------------------------- battery out

local BATTERY_REAPPLY_MS = 500

local function member_on_pitch_ignoring_bit(team, m)
  local tr = team_rec(team)
  if not tr or not m then return false end
  local cnt = rd("u32", tr + TEAM_ON_PITCH) or 0
  local pos = rd("u8", m + MEM_POSITION) or 0xFF
  local flags = rd("u16", m + MEM_FLAGS) or 0x800
  return band(flags, 0x800) == 0 and pos < cnt
end

local function set_bit(m, on)
  local f = rd("u16", m + MEM_FLAGS)
  if not f then return end
  local v = on and bit32.bor(f, MEM_SENT_OFF) or band(f, bit32.bnot(MEM_SENT_OFF))
  v = band(v, 0xFFFF)
  if v ~= f then wr("u16", m + MEM_FLAGS, v) end
end

local function set_hold(hdl, set, on)
  local ok, code, text = pcall(VRFW.locomotion.set, hdl, (on and set ~= "") and set or nil)
  if ok then return code, text end
  return -1, tostring(code)
end

local function release(p, why)
  local b = p.battery
  if not b then return end
  if b.bit_set then set_bit(b.member, false) end
  local _, text = set_hold(p.hdl, b.hold, false)
  pset(p.hdl, "battery_out", nil)
  off_pitch_set(p.hdl, false)
  flush_records()
  p.battery = nil
  info(string.format("battery: actor %s T%d s%s: released (%s; hold set off: %s)", hex(p.hdl), p.team, tostring(p.slot), why, tostring(text)))
end

local function release_all(why)
  for _, p in pairs(players) do
    if p.battery then release(p, why) end
  end
end

function R.battery_match_end()
  local n = 0
  for _, p in pairs(players) do
    if p.battery then
      set_hold(p.hdl, p.battery.hold, false)
      p.battery.last_apply = 0
      n = n + 1
    end
  end
  if n > 0 then info(string.format("battery: match end: %d battery-out player(s), hold sets off", n)) end
end

local function has_ball(hdl)
  local act = VRFW.actor(hdl)
  return act ~= nil and act.has_ball == true
end

local function nearest_teammate(p)
  local me = VRFW.actor(p.hdl)
  local best, bd = nil, nil
  for h, q in pairs(players) do
    if h ~= p.hdl and q.team == p.team and not q.battery and q.member and member_on_pitch_ignoring_bit(q.team, q.member)
      and band(rd("u16", q.member + MEM_FLAGS) or 0x800, MEM_SENT_OFF) == 0 then
      local o = VRFW.actor(h)
      local d = 1e30
      if me and o and me.x and o.x then d = (me.x - o.x) ^ 2 + (me.z - o.z) ^ 2 end
      if not bd or d < bd then best, bd = h, d end
    end
  end
  return best
end

local function move_control(p)
  local mgr = global("sp_ctrl")
  if not mgr then return "control: manager not resolved" end
  if rd("u32", mgr + CTRL_BY_TEAM + p.team * 4) ~= p.hdl then return "control: not his" end
  local new = nearest_teammate(p)
  if not new then return "control: no teammate to give it to" end
  local ok, was, now = pcall(VRFW.control.switch, p.team, new)
  if ok and was then return string.format("control %s -> %s", hex(was), hex(now)) end
  return "control NOT moved (" .. tostring(now or was) .. ")"
end

local function go_out(p)
  local b = p.battery
  local clip = b.clip ~= "" and b.clip or AC.clip_gauge_end
  local line = "no clip"
  if clip ~= "" then
    local ok, acc, serial = pcall(VRFW.clip.play, p.hdl, clip, { face = "ball" })
    if ok and acc ~= nil then
      line = string.format("clip %s %s (serial %s)", clip, acc and "ACCEPTED" or "REFUSED by the actor", tostring(serial))
    else
      line = string.format("clip %s: %s", clip, tostring(serial or acc))
    end
  end
  local _, set_text = set_hold(p.hdl, b.hold, true)
  local ctrl = move_control(p)
  set_bit(b.member, true)
  b.bit_set = true
  b.phase = "out"
  b.since = now_ms()
  b.last_apply = b.since
  b.clip_used = clip
  pset(p.hdl, "battery_out", 0)
  off_pitch_set(p.hdl, true)
  flush_records()
  info(string.format("battery: actor %s T%d s%s: kneels until the end of the match: %s; hold set %s %s; %s; member %s +0x7A |= 8 (off the pitch for the engine)%s",
    hex(p.hdl), p.team, tostring(p.slot), line, b.hold ~= "" and b.hold or "-", tostring(set_text), ctrl, hex(b.member), b.keep_armour and "; an armour stays" or ""))
end

-- one player, every frame (his PE already drained): obs = what the aura step saw
local function battery_step(p, pe, obs)
  local e = obs.effect
  if not p.battery then
    if not e or not e.battery or not pe or not (pe.max > 0 and pe.cur <= 0.002 * pe.max + 1e-4) or frame.state ~= IN_PLAY then return end
    if not p.member then return end
    p.battery = { phase = "pending", member = p.member, since = frame.now, clip = e.clip, hold = e.hold, hold_after_ms = e.hold_after_ms,
      keep_armour = e.keep_armour, hold_started = false, last_apply = 0, bit_set = false, logged_wait = false }
    info(string.format("battery: actor %s T%d s%s (traits %s): PE %.1f/%.0f%s: OUT OF BATTERY%s", hex(p.hdl), p.team, tostring(p.slot),
      table.concat(e.tags, ","), pe.cur, pe.max, (obs.keshin or obs.armour) and " with an aura out" or "", obs.keshin and ": the spirit is dismissed first" or ""))
    return
  end
  local b = p.battery
  if b.phase ~= "pending" then return end
  local wait
  if frame.state ~= IN_PLAY then wait = "not in open play"
  elseif obs.keshin then wait = "his keshin is still out"
  elseif has_ball(p.hdl) then wait = "he has the ball" end
  if wait then
    if not b.logged_wait and frame.now - b.since > 1500 then
      b.logged_wait = true
      info(string.format("battery: actor %s: the kneel waits: %s", hex(p.hdl), wait))
    end
    return
  end
  go_out(p)
end

-- once per frame: the held kneel after the clip, the set re-applied, a kept armour held, a player off the pitch released
function R.battery_frame(in_match)
  if not in_match then return end
  local now = now_ms()
  for _, p in pairs(players) do
    local b = p.battery
    if b and b.phase == "out" then
      local entry = Actors.of(p.hdl)
      local actor = entry and entry.address
      if not member_on_pitch_ignoring_bit(p.team, b.member) then
        release(p, "his member left the pitch")
      elseif not actor then
        release(p, "his match actor is gone")
      else
        if not b.hold_started and now - b.since >= b.hold_after_ms then
          b.hold_started = true
          local hold_clip = (b.clip_used or "") .. "_hold"
          local ok, acc, serial = pcall(VRFW.clip.play, p.hdl, hold_clip, { off_pitch = true })
          info(string.format("battery: actor %s: clip over: held kneel %s %s (serial %s)", hex(p.hdl), hold_clip,
            (ok and acc) and "ACCEPTED" or "REFUSED", tostring(serial)))
        end
        if now - b.last_apply >= BATTERY_REAPPLY_MS then
          b.last_apply = now
          local code, text = set_hold(p.hdl, b.hold, true)
          if code ~= 1 and code ~= 0 and b.hold ~= "" then warn(string.format("battery: actor %s: hold set %s: %s", hex(p.hdl), b.hold, tostring(text))) end
        end
        if b.keep_armour then
          local ms = rd("u8", actor + 0x3A0) or 0
          if ms == 4 or ms == 5 then wr("f32", actor + 0x39C, hold_left(rd("f32", actor + 0x388) or 0, 1)) end
        end
      end
    end
  end
end

-- ApplyTeamLayout (substitutions, formation commands): the bits cleared around the call, set again for those still on
-- the pitch, the others released (the VR-Framework's OffPitch rule signals before / after the game's code)
local layout_had = nil
VRFW.on("signal:vrfw.off_pitch.layout", function()
  layout_had = {}
  for _, p in pairs(players) do
    if p.battery and p.battery.bit_set then
      layout_had[#layout_had + 1] = p
      set_bit(p.battery.member, false)
    end
  end
  return nil
end)

VRFW.on("signal:vrfw.off_pitch.layout_done", function()
  for _, p in ipairs(layout_had or {}) do
    if p.battery then
      if member_on_pitch_ignoring_bit(p.team, p.battery.member) then
        set_bit(p.battery.member, true)
      else
        release(p, "left the pitch (substitution / formation change): the player who comes in is a normal one")
      end
    end
  end
  layout_had = nil
  return nil
end)

VRFW.on("hook:Ap_StaminaMatchRetry", function()
  release_all("match retry")
  return nil
end)

-- ---------------------------------------------------------------------------------------------- tired locomotion

local function tired_off(p)
  p.pause = false
  if p.loco then
    pcall(VRFW.locomotion.set, p.hdl, nil)
    p.loco = nil
    info(string.format("tired_motion: actor %s: retail locomotion", hex(p.hdl)))
  end
end

function R.tired_reset()
  for _, p in pairs(players) do
    tired_off(p)
    p.tired = T.new_track()
  end
end

-- the log text of a tired step: his tag, then `what` (written only when a line is logged)
local function tired_line(p, ratio, what)
  return string.format("T%d s%s%s PE %.0f %%", p.team, tostring(p.slot), p.team == frame.user and "*" or "", ratio * 100) .. what
end

-- a set already on is sent again only after this long (the battery's own re-apply rate)
local LOCOMOTION_REAPPLY_MS = 500

local function apply_set(p, set, ratio, what)
  if p.loco == set and frame.now - (p.loco_ms or 0) < LOCOMOTION_REAPPLY_MS and frame.now >= (p.loco_ms or 0) then return end
  p.loco_ms = frame.now
  local ok, code, text = pcall(VRFW.locomotion.set, p.hdl, set)
  if not ok or code < 0 then
    p.loco_err = p.loco_err or {}
    local c = ok and code or -99
    if not p.loco_err[c] then
      p.loco_err[c] = true
      warn(string.format("tired_motion: actor %s: set %s: %s", hex(p.hdl), tired_line(p, ratio, what), tostring(ok and text or code)))
    end
    p.loco = nil
    return
  end
  if p.loco ~= set and code == 1 then info(string.format("tired_motion: actor %s: %s", hex(p.hdl), tired_line(p, ratio, what))) end
  p.loco = (code == 1) and set or nil
end

-- VRFW.locomotion.known per set name (the sets are built once per start: asked once)
local KNOWN_SETS = {}
local function set_known(set)
  local k = KNOWN_SETS[set]
  if k == nil then
    k = VRFW.locomotion.known(set) == true
    KNOWN_SETS[set] = k
  end
  return k
end

local IDLE_STATES = {}   -- [soccer state] = true: TM.idle_states as a set
for _, s in ipairs(TM.idle_states) do IDLE_STATES[s] = true end

-- the facts of one tired step: one table, filled again for each player; whether he has the ball is asked only when
-- the pause needs it
local TIRED_FACTS = { ratio = 1, eligible = false, has_ball = false, idle_state = false, now = 0 }
local TIRED_HDL = 0
local function tired_has_ball() return has_ball(TIRED_HDL) end

local function tired_step(p, ratio)
  if not TM.enabled then return end
  local f = TIRED_FACTS
  f.ratio = ratio
  f.eligible = (TM.keepers or p.pos ~= 0) and (TM.cpu or p.team == frame.user)
  TIRED_HDL = p.hdl
  f.has_ball = tired_has_ball
  f.idle_state = IDLE_STATES[frame.state] == true
  f.now = frame.now / 1000
  local w = T.step(p.tired, TM, f, rng)
  if w == "off" then
    tired_off(p)
  elseif w == "idle" then
    if TM.idle_set:match("^%s*$") or not set_known(TM.idle_set) then
      p.pause = false
    else
      p.pause = true
      apply_set(p, TM.idle_set, ratio, ": exhausted pause " .. TM.idle_set)
    end
  else
    p.pause = false
    local set = TM.run_sets[w.run]
    if not set or not set_known(set) then
      set = nil
      for _, s in ipairs(TM.run_sets) do
        if set_known(s) then set = s break end
      end
    end
    if set then apply_set(p, set, ratio, ": tired run " .. set) else tired_off(p) end
  end
end

-- a tired pause: his speed is idle_speed × the retail rate (on top of the resource's own «exhausted» factor)
VRFW.on("move_speed", function(ev)
  local a = ev.actor
  if not a or not a.handle then return nil end
  local p = players[a.handle]
  if not p or not p.pause then return nil end
  local own = 1.0
  if p.exhausted then own = DECL.duel[frame.state] and DECL.speed_duel or DECL.speed end
  local pause = math.max(TM.idle_speed, 0)
  if own > 0 then return { speed_mult = pause / own } end
  return { speed_mult = pause }
end)

-- ---------------------------------------------------------------------------------------------- the frame

function R.aura_reset()
  for _, p in pairs(players) do
    p.tr.keshin, p.tr.armour, p.tr.miximax = false, false, false
    p.hud_mult = 1.0
  end
end

local function step_player(p, actor, a)
  local hdl = p.hdl
  local now = frame.now
  local running = a.summon_state == 2 or a.meta_state == 4 or a.meta_state == 5
  local tracked = p.tr.keshin or p.tr.armour or p.tr.miximax or p.tr.out_run
  local unit = nil
  if running or tracked or now - p.unit_ms >= REREAD_MS or p.chara == 0 then
    local ok, u = pcall(VRFW.call, "Match.ActorUnit", actor)
    if ok and type(u) == "number" and u >= 0x10000 then
      unit = VRFW.mem.read_struct("SpUnit", u)
      if unit then
        p.unit_ms = now
        member_info(p, unit)
        if unit.member and unit.member >= 0x10000 then
          p.chara = unit.chara
          p.param = unit.param
          p.fisico = unit.fisico
        end
      end
    end
  end
  local live = DECL.live[frame.state] and a.in_play ~= 0 and frame.dt > 0 and frame.dt < 1
  local okv, pe = pcall(VRFW.resource.get, PE, hdl)
  pe = okv and pe or nil
  local obs = aura_step(p, actor, a, unit, pe)
  -- the drain multiplier: the transformation's; 0 while CS runs his keshin / armour free of PE
  local m = obs.mult
  if obs.pe_free then
    m = 0
  elseif not (m == m and m > 0 and m < math.huge) then
    m = 1.0
  end
  if p.mult ~= m then
    local ok, done, code = pcall(VRFW.resource.set_mult, PE, hdl, KEY_AURA_MULT, m)
    if ok and done then p.mult = m elseif not p.mult_warned then
      p.mult_warned = true
      warn(string.format("drain multiplier of %s refused by the framework (%s)", hex(hdl), tostring(code)))
    end
  end
  p.hud_mult = obs.mult
  if obs.pe_charge > 0 then
    local ok, done, code = pcall(VRFW.resource.add, PE, hdl, -obs.pe_charge, false)
    if not (ok and done) then warn(string.format("CS end charge of %s refused (%s)", hex(hdl), tostring(code))) end
    okv, pe = pcall(VRFW.resource.get, PE, hdl)
    pe = okv and pe or nil
  end
  -- the miximax drain log (tuning cs_miximax_pe_mult)
  if obs.miximax and live and AC.drain_log_s > 0 and pe then
    local w = p.mx or { last = nil, drained = 0, secs = 0 }
    if w.last then
      w.drained = w.drained + math.max(w.last - pe.cur, 0)
      w.secs = w.secs + frame.dt
    end
    w.last = pe.cur
    if w.secs >= AC.drain_log_s then
      local avg = w.drained / w.secs
      info(string.format("miximax PE drain T%d actor %s: %.2f PE/s over the last %.1f s (aura x%.2f); PE %.1f/%.0f: 0 in ~%.0f s at that rate",
        p.team, hex(hdl), avg, w.secs, obs.mult, pe.cur, pe.max, avg > 0 and pe.cur / avg or math.huge))
      w.drained, w.secs = 0, 0
    end
    p.mx = w
  else
    p.mx = nil
  end
  p.exhausted = exhausted_of(pe)
  return obs, pe
end

-- the match's actors this frame and the actor table (nil outside a match): the library's reused list when it has one
local function frame_actors()
  if Actors.frame then return Actors.frame() end
  local base = Actors.base()
  if not base then return nil, nil end
  return Actors.list(), base
end

local NO_MATCH = {}     -- (read only)
local actor_recs = {}   -- [actor table index] = the table read_struct fills again every frame
-- the record of a player without a transformation (filled again for each one: hdl, team and the two states; the step
-- reads nothing else of it then)
local IDLE_ACTOR = { hdl = 0, team = 0xFF, summon_state = 0, meta_state = 0, in_play = 0, summon_skill = 0, meta_skill = 0,
  summon_full = 0, meta_full = 0 }
local tick_no = 0       -- the frames walked (p.seen_tick: on the pitch this frame)
-- a player without a transformation (nothing running, nothing tracked, no battery) is stepped at this rate, not every
-- frame: his PE, tired motion and battery check change slowly; a frame cap keeps him stepped while the clock stands
local IDLE_STEP_MS = 100
local IDLE_STEP_MAX_FRAMES = 12
-- the extra slot plates' states (VRFW.extra_slot.players) are read at the same rate
local SLOT_READ_MS = 100
local slots_read_ms, slots_read_tick = nil, 0

-- the extra slot state of a player that needs his whole actor record (a fusion miximax or a mode change runs)
local function slot_busy(es)
  return es ~= nil and ((es.fusion or 0) ~= 0 or es.swap == true)
end

VRFW.on("tick", function(ev)
  local m = ev.match or NO_MATCH
  local mi = global("sp_match")
  frame.mi = mi
  frame.state = m.soccer_state or 0
  frame.half = mi and (rd("u8", mi + MI_HALF) or 0) or 0
  frame.half_len = mi and (rd("u16", mi + MI_HALF_LEN) or 0) or 0
  frame.user = mi and (rd("u8", mi + MI_USER_TEAM) or 0xFF) or 0xFF
  frame.clock = m.clock or 0
  frame.dt = m.dt or 0
  frame.now = now_ms()
  frame.scene = global("sp_scene") or 0
  if not mi or frame.scene == 0 then return nil end
  frame_update()
  if not seen.in_match then return nil end
  local list, base = frame_actors()
  if not base then return nil end
  tick_no = tick_no + 1
  local now = frame.now
  if slots_read_ms == nil or now - slots_read_ms >= SLOT_READ_MS or now < slots_read_ms
    or tick_no - slots_read_tick >= IDLE_STEP_MAX_FRAMES then
    local okp, sl = pcall(VRFW.extra_slot.players)
    slots = (okp and type(sl) == "table") and sl or NO_SLOT
    slots_read_ms, slots_read_tick = now, tick_no
  end
  -- every actor's summon / meta state in two reads: the whole record only for a player whose transformation runs, just
  -- ended or whose extra slot runs a fusion / mode change
  local summon = Actors.field and Actors.field("SpActor", "summon_state", base)
  local meta = summon and Actors.field("SpActor", "meta_state", base)
  for _, entry in ipairs(list) do
    local actor = entry.address
    local a = nil
    local skip = false
    if meta and not slot_busy(slots[entry.handle]) then
      local ss, ms = summon[entry.index + 1], meta[entry.index + 1]
      local q = players[entry.handle]
      local tr = q and q.tr
      if ss ~= 2 and ms ~= 4 and ms ~= 5 and not (tr and (tr.keshin or tr.armour or tr.miximax or tr.out_run)) then
        -- (no transformation: his step reads only these two states)
        a = IDLE_ACTOR
        a.hdl, a.team, a.summon_state, a.meta_state = entry.handle, entry.team, ss, ms
        -- (and runs at IDLE_STEP_MS while nothing else of his is going on)
        if q and not q.battery and q.team == entry.team and q.idle_due and now < q.idle_due and now >= q.idle_from
          and tick_no - q.idle_tick < IDLE_STEP_MAX_FRAMES then
          skip = true
          q.seen_tick = tick_no
        end
      end
    end
    if skip then
      a = nil
    elseif a == nil then
      a = VRFW.mem.read_struct("SpActor", actor, actor_recs[entry.index])
      if a then actor_recs[entry.index] = a end
    end
    if a and a.hdl ~= 0 and band(a.hdl, 0xFF) == entry.index and a.team <= 1 then
      local p = players[a.hdl]
      if not p then
        p = new_player(a.hdl)
        players[a.hdl] = p
      end
      p.team = a.team
      p.seen_tick = tick_no
      if seen.ended then
        tired_off(p)
      else
        local obs, pe = step_player(p, actor, a)
        battery_step(p, pe, obs)
        if p.battery then
          tired_off(p)
        elseif pe then
          tired_step(p, pe.max > 0 and pe.cur / pe.max or 1)
        else
          tired_off(p)
        end
      end
      if a == IDLE_ACTOR then
        -- the next idle step (the first one spread over the players so they do not all step on the same frame)
        local spread = p.idle_due == nil and (entry.index % 5) * (IDLE_STEP_MS / 5) or 0
        p.idle_due, p.idle_from, p.idle_tick = now + IDLE_STEP_MS + spread, now, tick_no
      else
        p.idle_due = nil
      end
    end
  end
  flush_records()
  -- players no longer on the pitch: nothing of theirs stays applied
  for _, p in pairs(players) do
    if p.seen_tick ~= tick_no and not p.battery then tired_off(p) end
  end
  return nil
end)

-- ---------------------------------------------------------------------------------------------- the start pay

-- ProcessPending pre (a pending aura start): a [pe] free_activation kind (the miximax) gets flag 8 (no hyper gauge
-- spent). A keshin / armour / totem on an Aura Points pool already got flag 8 from Aura Points (order 20).
VRFW.on("hook:Ap_StaminaPendingPay", function(ev)
  if not AC.enabled then return nil end
  local actor = ev.args[1]
  if type(actor) ~= "number" or actor < 0x10000 then return nil end
  local armed = rd("u8", actor + 0x1A8) or 0
  if armed == 0 then return nil end
  local a = VRFW.mem.read_struct("SpActor", actor)
  if not a then return nil end
  local flags = a.pend_flags
  if band(flags, PEND_FLAG_HYPER_GAUGE) == 0 or band(flags, PEND_FLAG_NO_COST) ~= 0 then return nil end
  if not applies(a.team) then return nil end
  local skill, ty = nil, nil
  for _, id in ipairs({ a.pend_skill, a.pend_skill2 }) do
    if not skill and (A.type(id) ~= nil or A.is_miximax(id)) then
      skill = id
      ty = A.is_miximax(id) and 2 or A.type(id)
    end
  end
  if not skill or not AC.free_activation(ty) then return nil end
  if wr("u32", actor + 0x1A0, bit32.bor(flags, PEND_FLAG_NO_COST)) then
    info(string.format("start: actor %s: %s (0x%08X, auraType %d) starts without spending the hyper gauge (pending flags 0x%X -> 0x%X)", hex(a.hdl),
      key_of(skill), skill, ty, flags, bit32.bor(flags, PEND_FLAG_NO_COST)))
  end
  return nil
end)

-- ---------------------------------------------------------------------------------------------- commands

-- the match player (soccer handle) whose character status handle is `chara` (a menu's player: the pause menu's
-- formation, the player header), nil when none of this match's players is that character
local function player_of_chara(chara)
  for h, p in pairs(players) do
    if p.chara == chara then return h end
  end
  return nil
end

-- CMND_AURAPOINTS_STAMINA(hdl) -> ok, cur, max, exhausted (0/1), modeOn (1), user (0/1), hdl, mult, sprint, winded.
-- hdl = a match player's soccer handle, or a character status handle (a menu's player: mapped to the match player of
-- that character), 0 = the user's controlled player; false outside a match / after the final whistle / for a player
-- without PE. sprint = his sprint bar's share (0..1; -1 = no sprint bar), winded = 1 while it is in «winded».
function AuraPoints.Stamina(hdl)
  hdl = tonumber(hdl) or 0
  if not seen.in_match or seen.ended then return false end
  local u = hdl % 4294967296
  if hdl ~= 0 and not players[u] then
    local h = player_of_chara(u)
    if not h then return false end
    hdl = h
  end
  local ok, v = pcall(VRFW.resource.get, PE, hdl)
  if not ok or not v then return false end
  local p = players[v.hdl]
  if not p then return false end
  local sprint, winded = -1, 0
  local oks, sv = pcall(VRFW.resource.get, SPRINT, v.hdl)
  if oks and type(sv) == "table" and type(sv.ratio) == "number" then
    sprint = sv.ratio
    local okw, w = pcall(VRFW.resource.state, SPRINT, v.hdl, "winded")
    winded = (okw and w == true) and 1 or 0
  end
  return true, v.cur, v.max, exhausted_of(v) and 1 or 0, 1, v.user and 1 or 0, v.hdl, p.hud_mult or 1.0, sprint, winded
end

-- CMND_AURAPOINTS_STAMINA_MAX(fisico[, charaStHdl]) -> ok, max, modeOn (1): the plates outside a match. The max of the
-- handle's card (its record's chara_param id) at the character's level (pe_max.toml's level curve); without a handle,
-- or one that does not resolve, the table's default. Físico does not change it (it slows the drain).
local HBUF, FBUF
local function card_of_chara(hdl)
  if type(hdl) ~= "number" or hdl == 0 then return nil end
  local kind = math.floor(hdl / 4096) % 16
  if kind >= 0xD then return nil end
  local okc, conts = pcall(VRFW.game.sp_chara_containers)
  if not okc or type(conts) ~= "number" or conts < 0x10000 then return nil end
  local cont = rd("ptr", conts + 8 + kind * 8)
  if not cont or cont == 0 then return nil end
  if not HBUF then
    HBUF = VRFW.mem.buffer("aura_points_stamina_hdl", 8)
    FBUF = VRFW.mem.buffer("aura_points_stamina_flag", 8)
  end
  VRFW.mem.write("u32", HBUF, hdl)
  local ok, obj = pcall(VRFW.call, "Board.FindCharaRecord", cont, HBUF)
  if not ok or type(obj) ~= "number" or obj < 0x10000 then return nil end
  local rec = rd("ptr", obj + 8)
  if not rec or rd("u32", rec) ~= hdl then return nil end
  local id = rd("u32", rec + 4)
  local okl, lv = pcall(VRFW.call, "Chara.HumanGetLevel", obj, FBUF)
  lv = (okl and type(lv) == "number") and lv % 65536 or nil
  if id == 0 then id = nil end
  return id, lv
end

function AuraPoints.StaminaMax(fisico, hdl)
  if type(fisico) ~= "number" or fisico ~= fisico then return false end
  local card, level = card_of_chara(tonumber(hdl))
  local ok, m = pcall(VRFW.resource.max, PE, card, level)
  return true, (ok and m) or DECL.max, 1
end

-- ---------------------------------------------------------------------------------------------- the hyper gauge

-- THE rule «nothing pays with the hyper gauge» (owner 2026-10-19), read once (the option rows restart the game): PE (this
-- feature) with its rules on, PEG and SP on, and every aura of the game's table (the served aura_skill_config, every
-- mod's rows) covered: a keshin on its PEG pool, an armour on its keshin's pool, a totem on its SP bar, any other kind
-- with a free start without the gauge check ([pe] free_activation and no_start_check), a row that costs nothing. Both
-- teams play by these rules. It drives the HUD layers hidden (CMND_AURAPOINTS_HUD_HIDDEN_LAYERS), the free start of
-- mode change / kizuna trans / awakening power (lib/stamina/cfg.lua) and the gauge's gains turned off
-- (CMND_AURAPOINTS_HYPER_GAIN_OFF, the patches of stamina.toml). The 20 % start fill of the gauge is the game's.
local hyper_unused, hyper_why = nil, nil
function AuraPoints.HyperUnused()
  if hyper_unused ~= nil then return hyper_unused end
  local why = nil
  if not AC.enabled then
    why = "[pe] enabled = false"
  elseif not PEG_ON then
    why = "option peg off"
  elseif not SP_ON then
    why = "option sp off"
  elseif not A.load() then
    why = "no aura table"
  else
    for _, id in ipairs(A.ids()) do
      local r = A.row(id)
      local ty = r and r.type
      local covered
      if r == nil or (r.cost or 0) <= 0 then
        covered = true
      elseif ty == 0 or ty == 3 then
        covered = true                       -- a keshin's PEG pool, a totem's SP bar
      elseif ty == 1 then
        covered = A.spirit(id) ~= nil        -- an armour runs on its keshin's pool
      else
        covered = AC.listed_free(ty)         -- miximax, mode change, kizuna trans, awakening power
      end
      if not covered then
        why = string.format("%s (auraType %s) still pays with the hyper gauge", A.key(id), tostring(ty))
        break
      end
    end
  end
  hyper_unused, hyper_why = why == nil, why
  info(hyper_unused and "nothing pays with the hyper gauge: its HUD hidden, its gains off, both teams"
    or ("the hyper gauge stays as in the game: " .. why))
  return hyper_unused
end
AC.unused = AuraPoints.HyperUnused

-- CMND_AURAPOINTS_HUD_HIDDEN_LAYERS() -> ok, layer hash...: the match HUD layers hidden while nothing pays with the hyper
-- gauge (config.toml [hud_hidden_layers] hidden_layers: the retail hyper gauge); false otherwise (the HUD stays retail)
local HUD_HIDDEN_LAYERS = {}
for _, name in ipairs((VRFW.files.config("hud_hidden_layers") or {}).hidden_layers or {}) do
  if type(name) == "string" and name ~= "" then HUD_HIDDEN_LAYERS[#HUD_HIDDEN_LAYERS + 1] = VRFW.crc32(name) end
end

function AuraPoints.HudHiddenLayers()
  if not AuraPoints.HyperUnused() then return false end
  return true, table.unpack(HUD_HIDDEN_LAYERS)
end

-- CMND_AURAPOINTS_HYPER_GAIN_OFF() -> true while the hyper gauge's gains are off (the same rule)
function AuraPoints.HyperGainOff()
  return AuraPoints.HyperUnused() == true
end

-- the gains off at their source, written once at the start when the rule holds (stamina.toml: the skill-use gain and
-- its «+N» number skipped as for a rate of 0, the two scripted gain handlers return at once)
local HYPER_GAIN_PATCHES = { "Ap_HyperGainSkill", "Ap_HyperGainScriptA", "Ap_HyperGainScriptB" }
local function hyper_gain_off()
  if not AuraPoints.HyperUnused() then return end
  for _, name in ipairs(HYPER_GAIN_PATCHES) do
    local ok, done, e = pcall(VRFW.patch.apply, name)
    if not ok or not done then
      warn(string.format("hyper gauge gain patch %s not written: %s", name, tostring(ok and e or done)))
    end
  end
  info("hyper gauge gains off (" .. #HYPER_GAIN_PATCHES .. " sites)")
end

-- ---------------------------------------------------------------------------------------------- start

local function start()
  math.randomseed(now_ms() % 2147483647)
  A.load()
  AuraPoints.HyperUnused()
  local n = A.publish(AC)
  hyper_gain_off()
  clear_match_tables()
  info(string.format("active over the VR-Framework's %s (max %s; exhausted bit %s, speed x%s / duel x%s); %d auras; " ..
    "rules %s, cost model %s (scale %s), miximax PE x%s, untimed %s; CPU %s; %d trait rule(s); tired locomotion %s; hooks: cost check %s, pending pay %s",
    PE, DECL.max, tostring(DECL.exhausted_bit), DECL.speed, DECL.speed_duel, n, AC.enabled and "on" or "OFF", AC.cs() and "CS" or "IF",
    AC.cs_scale(), select(1, AC.pe_mults()), tostring(AC.miximax_untimed), "both teams",
    (function() local k = 0 for _ in pairs(AC.traits) do k = k + 1 end return k end)(), TM.enabled and "on" or "off",
    tostring(VRFW.is_on("Ap_StaminaCostCheck")), tostring(VRFW.is_on("Ap_StaminaPendingPay"))))
end

start()
