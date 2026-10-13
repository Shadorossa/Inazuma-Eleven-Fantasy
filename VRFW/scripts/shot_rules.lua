-- VR-Framework › shot / zone rules (service S5 of VRFW 2.3, docs/framework/rules.md §8). Declarations: every active
-- mod's content\shot_rules\*.toml (`VRFW.shot_rule/1`, keys: content\types\shot_rule.toml); native side:
-- content\game\shot_rules.toml. (Was Inazuma Fantasy's scripts\shoot_zone.lua and the long-shot row of its
-- training_field.lua until VRFW 2.3.)
--
--   * [[VRFW.ZoneArea]] area = "penalty_box": IsInZoneArea / IsInAnyZoneArea are replaced whole and answered natively
--     (no Lua call per query: the AI asks them many times per frame). This script only keeps their data current, once
--     per match frame (`tick`):
--       - table ShotZone.Box: team 0 / 1 = the penalty box that team attacks (the one on its attacking side of the
--         centre, by its attack sign), 10 / 11 = the field's own boxes 0 / 1; { x0, x1, z0, z1 } with the margin;
--         team records also { cz, sg, hz } (centre z, attack sign, half length) for the retail chain answers;
--       - state keys vrfw.shot_zone.ball / .setpiece (where the answers look for the vector the z was read from),
--         .play_ctrl (the zone / chain flags), .line (the address of the game's zone line), .chain_retail (chain_area).
--     No valid field data (no match, a loading pitch) = an empty table: every query answers false, as retail does then.
--     The margin: margin_m, or the declaring mod's config value at margin_config (0..20 m). extra_state = a state key
--     prefix of the declaring mod: <prefix>.0 / .1 = extra metres around the box team 0 / 1 attacks (its passives; a
--     field box gets the extra of the team that attacks it); the total stays within 0..20 m. Several mods: each key the
--     later mod (load order) gives wins.
--   * [[VRFW.LongShot]] all_moves_flag = "<flag>": while that flag is non-zero during a match, the two long-shot checks of
--     SkillSituationOk pass (every shot move may be a long shot); the game's bytes come back when the flag is 0, at the
--     end of the match and at the title.

local D = require "lib/declarations"

local function info(...) VRFW.log("shot_rules:", ...) end
local function warn(...) VRFW.warn("shot_rules:", ...) end

local BOX = "ShotZone.Box"
local KEY_BALL, KEY_SETPIECE = "vrfw.shot_zone.ball", "vrfw.shot_zone.setpiece"
local KEY_PLAY_CTRL, KEY_LINE, KEY_CHAIN = "vrfw.shot_zone.play_ctrl", "vrfw.shot_zone.line", "vrfw.shot_zone.chain_retail"
local ZONE_HOOKS = { "ShotZone.Area", "ShotZone.AreaAny" }
local ANY_FIRST = 10

-- field data: valid byte, half length z, centre z, the two boxes (+0x16884 + i x 0x28 = {x0, z0, x1, z1, …, cz +0x1C})
local FIELD_VALID, FIELD_HALF_Z, FIELD_CENTRE_Z = 0x7BF92, 0x4, 0x70
local FIELD_BOX, FIELD_BOX_STRIDE, BOX_CZ = 0x16884, 0x28, 0x1C
-- match info: team block + 0x60 + team x 0x1130, attack sign i8 at + 0x1102
local MI_TEAMS, TEAM_STRIDE, TEAM_SIGN = 0x60, 0x1130, 0x1102
local MAX_FIELD_LOGS = 20

-- the long-shot sites: the bytes that make the check pass (`on`) and the game's (`off`), as the expect lists of
-- content\game\shot_rules.toml
local LONG_PATCHES = {
  { name = "ShotRules.LongShotZone", on = "0C 01 90 90", off = "F6 46 08 04" },
  { name = "ShotRules.LongShotKeep", on = "B0 01 90 90 90 90 90 90", off = "8B 46 08 C1 E8 02 24 01" },
}

local function rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local ZONE = nil        -- { margin, chain_retail, extra = prefix or nil, by = { key -> mod } } while area = penalty_box
local LONG_FLAGS = {}   -- { flag, mod } of every [[VRFW.LongShot]]

local function config_value(mod, path)
  if type(path) ~= "string" or path == "" then return nil end
  local ok, v = pcall(VRFW.files.config, path, mod)
  if ok then return v end
  return nil
end

local function start()
  local schema, why = D.schema("shot_rule")
  if not schema then
    warn(why .. ": the shot / zone rules stay the game's")
    return
  end
  local decls, skipped = D.load(schema, warn)
  -- ZoneArea: each key the later mod gives wins; the config paths are read on the mod that gave them
  local z = {}
  for _, d in ipairs(decls) do
    if d.entry == "ZoneArea" then
      local v = d.v
      if v.area ~= "retail" and v.area ~= "penalty_box" then
        warn(string.format("%s: area = %q: \"retail\" or \"penalty_box\": left out", d.where, v.area))
      elseif v.chain_area ~= "retail" and v.chain_area ~= "box" then
        warn(string.format("%s: chain_area = %q: \"retail\" or \"box\": left out", d.where, v.chain_area))
      else
        for _, k in ipairs({ "area", "margin_m", "margin_config", "chain_area", "chain_area_config", "extra_state" }) do
          if d.given[k] or z[k] == nil then z[k] = { value = v[k], mod = d.mod, given = d.given[k] } end
        end
      end
    elseif d.entry == "LongShot" then
      LONG_FLAGS[#LONG_FLAGS + 1] = { flag = d.v.all_moves_flag, mod = d.mod }
    end
  end
  if z.area and z.area.value == "penalty_box" then
    local m = tonumber(z.margin_m.value) or 0
    local cm = config_value(z.margin_config.mod, z.margin_config.value)
    if cm ~= nil then m = tonumber(cm) or 0 end
    if m ~= m or m < 0 then m = 0 end
    if m > 20 then m = 20 end
    local chain = z.chain_area.value
    local cc = config_value(z.chain_area_config.mod, z.chain_area_config.value)
    if cc ~= nil then chain = tostring(cc) end
    local extra = z.extra_state.value
    ZONE = { margin = m, chain_retail = chain ~= "box", extra = (type(extra) == "string" and extra ~= "") and extra or nil }
    local parts, all = {}, true
    for _, h in ipairs(ZONE_HOOKS) do
      local ok, done, e = pcall(VRFW.hook.apply, h)
      local live = ok and done == true
      all = all and live
      parts[#parts + 1] = h .. (live and " installed" or (" NOT installed (" .. tostring(ok and e or done) .. ")"))
    end
    info(string.format("zone area: penalty box (%s), margin %.1f m, chains on %s%s; %s", z.area.mod, m,
      ZONE.chain_retail and "the game's own area" or "the box", ZONE.extra and (", extra metres from " .. ZONE.extra .. ".0 / .1") or "",
      table.concat(parts, ", ")))
    if not all then
      warn("zone area: a detour is missing: the game's band stays for its callers")
      if not select(2, pcall(VRFW.is_on, "ShotZone.Area")) then ZONE = nil end
    end
  else
    info("zone area: " .. (z.area and ("retail (" .. z.area.mod .. ")") or "no mod declares it") .. ": the game's band")
  end
  if #LONG_FLAGS > 0 then
    local parts = {}
    for _, f in ipairs(LONG_FLAGS) do parts[#parts + 1] = f.flag .. " (" .. f.mod .. ")" end
    info("long shots: every shot move while a flag is on during a match: " .. table.concat(parts, ", "))
  end
  if (skipped or 0) > 0 then info(string.format("%d declaration(s) left out by `when`", skipped)) end
end

start()

-- ---------------------------------------------------------------------------------------------- zone area

local chain_published = false

local function extras()
  local out = { [0] = 0, [1] = 0 }
  if not ZONE or not ZONE.extra then return out end
  for t = 0, 1 do
    local ok, v = pcall(VRFW.state, ZONE.extra .. "." .. t)
    v = ok and tonumber(v) or 0
    if v ~= v or v < 0 then v = 0 end
    out[t] = v
  end
  return out
end

local function read_field()
  local f = global("shot_zone_field")
  if not f or (rd("u8", f + FIELD_VALID) or 0) == 0 then return nil end
  local field = { half_z = rd("f32", f + FIELD_HALF_Z), centre_z = rd("f32", f + FIELD_CENTRE_Z), boxes = {} }
  if not field.half_z or not field.centre_z then return nil end
  for i = 0, 1 do
    local a = f + FIELD_BOX + i * FIELD_BOX_STRIDE
    local b = { x0 = rd("f32", a), z0 = rd("f32", a + 4), x1 = rd("f32", a + 8), z1 = rd("f32", a + 0xC), cz = rd("f32", a + BOX_CZ) }
    if not (b.x0 and b.z0 and b.x1 and b.z1 and b.cz) then return nil end
    field.boxes[i + 1] = b
  end
  return field
end

local function sign_of(mi, team)
  if not mi then return 0 end
  return rd("i8", mi + MI_TEAMS + team * TEAM_STRIDE + TEAM_SIGN) or 0
end

-- the box a team with attack sign `sign` shoots at: the one on its attacking side of the centre
local function attacked(field, sign)
  if sign == 0 then return nil end
  for _, b in ipairs(field.boxes) do
    if (b.cz - field.centre_z) * sign > 0 then return b end
  end
  return nil
end

local function rect(b, extra)
  local m = math.min(ZONE.margin + (extra or 0), 20)
  return {
    x0 = math.min(b.x0, b.x1) - m, x1 = math.max(b.x0, b.x1) + m,
    z0 = math.min(b.z0, b.z1) - m, z1 = math.max(b.z0, b.z1) + m,
  }
end

-- a team record: its box plus the game's own depth test data (ShotZone.Retail)
local function team_rect(b, extra, field, sign)
  local r = rect(b, extra)
  r.cz, r.sg, r.hz = field.centre_z, sign, field.half_z
  return r
end

-- the keys the chain answers read: the play controller every frame, the line address and the switch once
local function publish_chain()
  pcall(VRFW.state.set, KEY_PLAY_CTRL, global("shot_zone_play_ctrl"))
  if chain_published then return end
  chain_published = true
  local ok, line = pcall(VRFW.mem.global_addr, "shot_zone_line")
  if ok and type(line) == "number" and line >= 0x10000 then
    pcall(VRFW.state.set, KEY_LINE, line)
  else
    warn("zone area: no zone line address: shot chains use the box")
  end
  pcall(VRFW.state.set, KEY_CHAIN, ZONE.chain_retail and 1 or 0)
  info("zone area: shot chains: " .. (ZONE.chain_retail and "the game's own area (chain_area = \"retail\")" or "the box (chain_area = \"box\")"))
end

local last_sig, field_logs, filled = nil, 0, false

local function clear()
  if filled then
    pcall(VRFW.native.table_clear, BOX)
    filled = false
  end
  last_sig = nil
end

local function fmt_box(b)
  return string.format("x %.2f..%.2f z %.2f..%.2f", math.min(b.x0, b.x1), math.max(b.x0, b.x1), math.min(b.z0, b.z1), math.max(b.z0, b.z1))
end

local function refresh()
  pcall(VRFW.state.set, KEY_BALL, global("shot_zone_ball"))
  pcall(VRFW.state.set, KEY_SETPIECE, global("shot_zone_setpiece"))
  publish_chain()
  local field = read_field()
  if not field or not (field.half_z > 0) then
    clear()
    return
  end
  local mi = global("shot_zone_match_info")
  local s0, s1 = sign_of(mi, 0), sign_of(mi, 1)
  local b1, b2 = field.boxes[1], field.boxes[2]
  local ex = extras()
  local sig = table.concat({ s0, s1, field.centre_z, field.half_z, b1.x0, b1.z0, b1.x1, b1.z1, b2.x0, b2.z0, b2.x1, b2.z1, ex[0], ex[1] }, ",")
  if sig == last_sig then return end
  last_sig = sig
  -- a field box gets the extra of the team that attacks it
  local by_box = {}
  for team, s in pairs({ [0] = s0, [1] = s1 }) do
    local b = attacked(field, s)
    if b then by_box[b] = math.max(by_box[b] or 0, ex[team] or 0) end
  end
  local entries = { { ANY_FIRST, rect(b1, by_box[b1]) }, { ANY_FIRST + 1, rect(b2, by_box[b2]) } }
  for team, s in pairs({ [0] = s0, [1] = s1 }) do
    local b = attacked(field, s)
    if b then entries[#entries + 1] = { team, team_rect(b, ex[team], field, s) } end
  end
  local ok, err = pcall(VRFW.native.table_replace, BOX, nil, entries)
  filled = ok
  if not ok then
    warn("zone area: box table not written: " .. tostring(err))
    return
  end
  if field_logs < MAX_FIELD_LOGS then
    field_logs = field_logs + 1
    info(string.format("zone area: pitch half length %.2f centre z %.2f; box 0 %s, box 1 %s; attack signs %d / %d; margin %.1f m (+ extra: team 0 %.2f m, team 1 %.2f m)",
      field.half_z, field.centre_z, fmt_box(b1), fmt_box(b2), s0, s1, ZONE.margin, ex[0] or 0, ex[1] or 0))
  end
end

-- ---------------------------------------------------------------------------------------------- long shots

local long_on = false

local function long_wanted()
  for _, f in ipairs(LONG_FLAGS) do
    local ok, v = pcall(VRFW.flag, f.flag)
    if ok and tonumber(v) and tonumber(v) ~= 0 then return true, f.flag end
  end
  return false
end

local function set_long(on, why)
  if on == long_on then return end
  for _, p in ipairs(LONG_PATCHES) do
    local ok, done = pcall(VRFW.patch.apply, p.name, on and p.on or p.off)
    if not ok or done ~= true then warn(string.format("long shots: %s %s: %s", p.name, on and "on" or "off", tostring(done))) end
  end
  long_on = on
  info("long shots: every shot move " .. (on and "ON" or "off") .. " (" .. why .. ")")
end

-- ---------------------------------------------------------------------------------------------- events

if ZONE or #LONG_FLAGS > 0 then
  VRFW.on("tick", function()
    if ZONE then refresh() end
    if #LONG_FLAGS > 0 then
      local want, flag = long_wanted()
      set_long(want, want and ("flag " .. flag) or "flags off")
    end
    return nil
  end)
  VRFW.on("match_end", function()
    if ZONE then clear() end
    if #LONG_FLAGS > 0 then set_long(false, "match end") end
    return nil
  end)
  VRFW.on("game_reset", function()
    if #LONG_FLAGS > 0 then set_long(false, "title") end
    return nil
  end)
end
