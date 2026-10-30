-- Shot / zone rules (content/shot_rules/*.toml, schema VRFW.shot_rule/1); native side: content/game/shot_rules.toml.
--   * [[VRFW.ZoneArea]] area = "penalty_box" / "goal_area" (both teams; user_area / rival_area per side when the match has a user side):
--     IsInZoneArea / IsInAnyZoneArea are answered natively; this script refreshes their data once per match frame:
--       - table ShotZone.Box: team 0 / 1 = the area that team attacks, 10 / 11 = the field's halves 0 / 1 ({ x0, x1, z0, z1 } with margin; team records add { cz, sg, hz });
--         a side on "retail" gets the game's full-width band past the zone line (zoneLineFieldRateZ) as its rectangle;
--       - scale: the box's width (about its centre) and depth (from the goal line toward the centre) x this, before the margin;
--       - state keys vrfw.shot_zone.ball / .setpiece / .play_flags / .line / .chain_retail feed the retail answers
--         (while a zone runs or a shot chain window is open / taken, chain_area = "retail": every position gets the game's own band).
--     No valid field data (no match, loading pitch) = empty table: every query answers false.
--     Margin: margin_m, or the mod's config value at margin_config (0..20 m); extra_state = state key prefix, <prefix>.0 / .1 = extra metres around the box team 0 / 1 attacks (total within 0..20 m).
--     With several mods, each key the later mod (load order) gives wins.
--   * [[VRFW.LongShot]] all_moves_flag = "<flag>": while the flag is non-zero in a match, every shot move passes the long-shot checks of SkillSituationOk; the game's bytes return when it is 0, at match end and at the title.

local D = require "lib/declarations"

require "VRFW/lib/basics"
local info, warn = VRFW.logger("shot_rules")

local BOX = "ShotZone.Box"
local KEY_BALL, KEY_SETPIECE = "vrfw.shot_zone.ball", "vrfw.shot_zone.setpiece"
local KEY_PLAY_FLAGS, KEY_LINE, KEY_CHAIN = "vrfw.shot_zone.play_flags", "vrfw.shot_zone.line", "vrfw.shot_zone.chain_retail"
-- the play controller's flags offset (game profile; it moves between builds)
local PLAY_FLAGS_FIELD = "Match.PlayControlFlags"
local ZONE_HOOKS = { "ShotZone.Area", "ShotZone.AreaAny" }
local ANY_FIRST = 10

-- the field data and match info records (game profile structs FieldData, FieldBox, MatchInfo, MatchTeam):
-- field boxes 0 / 1 = the penalty boxes, 2 / 3 = the goal areas (FieldBuild 0x1615350); MatchTeam.AttackSign = the
-- team's attack direction
local GOAL_AREA_FIRST = 2
local AREAS = { retail = true, penalty_box = true, goal_area = true }
local BAND = 1e9
local LAYOUT_NAMES = {
  valid = "FieldData.Valid", half_z = "FieldData.HalfLength", centre_z = "FieldData.CentreZ", boxes = "FieldData.Boxes",
  box = "FieldBox", box_x0 = "FieldBox.X0", box_z0 = "FieldBox.Z0", box_x1 = "FieldBox.X1", box_z1 = "FieldBox.Z1",
  box_cz = "FieldBox.CentreZ",
  teams = "MatchInfo.Teams", team = "MatchTeam", team_sign = "MatchTeam.AttackSign",
}
local MAX_FIELD_LOGS = 20

-- long-shot sites: bytes that pass the check (`on`) and the game's (`off`), as in content/game/shot_rules.toml
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

local LAYOUT = nil
local function layout()
  if LAYOUT == nil then
    local out = {}
    for key, name in pairs(LAYOUT_NAMES) do
      local ok, v = pcall(VRFW.game.field, name)
      if not ok or type(v) ~= "number" then
        return nil
      end
      out[key] = v
    end
    LAYOUT = out
  end
  return LAYOUT
end

local function global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

-- ---- declarations

local ZONE = nil        -- { margin, scale, area, user_area, rival_area, chain_retail, extra = prefix or nil } while some side is not "retail"
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
  -- ZoneArea: the later mod wins per key; config paths are read on the mod that gave them
  local z = {}
  for _, d in ipairs(decls) do
    if d.entry == "ZoneArea" then
      local v = d.v
      local bad = nil
      for _, k in ipairs({ "area", "user_area", "rival_area" }) do
        if (k == "area" or (v[k] or "") ~= "") and not AREAS[v[k]] then bad = k end
      end
      if bad then
        warn(string.format("%s: %s = %q: \"retail\", \"penalty_box\" or \"goal_area\": left out", d.where, bad, tostring(v[bad])))
      elseif v.chain_area ~= "retail" and v.chain_area ~= "box" then
        warn(string.format("%s: chain_area = %q: \"retail\" or \"box\": left out", d.where, v.chain_area))
      else
        for _, k in ipairs({ "area", "user_area", "rival_area", "scale", "margin_m", "margin_config", "chain_area", "chain_area_config", "extra_state" }) do
          if d.given[k] or z[k] == nil then z[k] = { value = v[k], mod = d.mod, given = d.given[k] } end
        end
      end
    elseif d.entry == "LongShot" then
      LONG_FLAGS[#LONG_FLAGS + 1] = { flag = d.v.all_moves_flag, mod = d.mod }
    end
  end
  local function side_area(k)
    local v = z[k] and z[k].value
    if type(v) == "string" and v ~= "" then return v end
    return z.area and z.area.value or "retail"
  end
  local user_area, rival_area = side_area("user_area"), side_area("rival_area")
  if z.area and (z.area.value ~= "retail" or user_area ~= "retail" or rival_area ~= "retail") then
    local m = tonumber(z.margin_m.value) or 0
    local cm = config_value(z.margin_config.mod, z.margin_config.value)
    if cm ~= nil then m = tonumber(cm) or 0 end
    if m ~= m or m < 0 then m = 0 end
    if m > 20 then m = 20 end
    local chain = z.chain_area.value
    local cc = config_value(z.chain_area_config.mod, z.chain_area_config.value)
    if cc ~= nil then chain = tostring(cc) end
    local extra = z.extra_state.value
    local scale = tonumber(z.scale and z.scale.value) or 1
    if scale ~= scale or scale < 0.5 then scale = 0.5 end
    if scale > 3 then scale = 3 end
    ZONE = { margin = m, scale = scale, area = z.area.value, user_area = user_area, rival_area = rival_area,
      chain_retail = chain ~= "box", extra = (type(extra) == "string" and extra ~= "") and extra or nil }
    local parts, all = {}, true
    for _, h in ipairs(ZONE_HOOKS) do
      local ok, done, e = pcall(VRFW.hook.apply, h)
      local live = ok and done == true
      all = all and live
      parts[#parts + 1] = h .. (live and " installed" or (" NOT installed (" .. tostring(ok and e or done) .. ")"))
    end
    info(string.format("zone area: %s (%s; with a user side: yours %s, the rival's %s), scale %.2f, margin %.1f m, chains on %s%s; %s",
      z.area.value, z.area.mod, user_area, rival_area, scale, m,
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

-- ---- zone area

local chain_published, play_flags_off = false, nil

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
  local L = layout()
  if not f or not L or (rd("u8", f + L.valid) or 0) == 0 then return nil end
  local field = { half_z = rd("f32", f + L.half_z), centre_z = rd("f32", f + L.centre_z), boxes = {} }
  if not field.half_z or not field.centre_z then return nil end
  for i = 0, 3 do
    local a = f + L.boxes + i * L.box
    local b = { x0 = rd("f32", a + L.box_x0), z0 = rd("f32", a + L.box_z0), x1 = rd("f32", a + L.box_x1),
      z1 = rd("f32", a + L.box_z1), cz = rd("f32", a + L.box_cz) }
    if not (b.x0 and b.z0 and b.x1 and b.z1 and b.cz) then return nil end
    field.boxes[i + 1] = b
  end
  return field
end

local function sign_of(mi, team)
  local L = layout()
  if not mi or not L then return 0 end
  return rd("i8", mi + L.teams + team * L.team + L.team_sign) or 0
end

-- the box of one kind (first = 0: penalty boxes, GOAL_AREA_FIRST: goal areas) a team with attack sign `sign` shoots at
-- (its attacking side of the centre)
local function attacked(field, sign, first)
  if sign == 0 then return nil end
  for i = (first or 0) + 1, (first or 0) + 2 do
    local b = field.boxes[i]
    if (b.cz - field.centre_z) * sign > 0 then return b end
  end
  return nil
end

-- the game's zone line (zoneLineFieldRateZ, f32)
local LINE_ADDR = nil
local function zone_line()
  if not LINE_ADDR then
    local ok, a = pcall(VRFW.mem.global_addr, "shot_zone_line")
    if ok and type(a) == "number" and a >= 0x10000 then LINE_ADDR = a end
  end
  return rd("f32", LINE_ADDR)
end

-- a box x the scale (width about its centre, depth from the goal line toward the centre), widened by the margin + extra
local function rect(b, extra, field)
  local m = math.min(ZONE.margin + (extra or 0), 20)
  local s = ZONE.scale or 1
  local xl, xh = math.min(b.x0, b.x1), math.max(b.x0, b.x1)
  local zl, zh = math.min(b.z0, b.z1), math.max(b.z0, b.z1)
  if s ~= 1 then
    local cx, hw = (xl + xh) / 2, (xh - xl) / 2 * s
    xl, xh = cx - hw, cx + hw
    local grow = (zh - zl) * (s - 1)
    -- the goal line is the edge farther from the pitch's centre
    if math.abs(zh - field.centre_z) >= math.abs(zl - field.centre_z) then zl = zl - grow else zh = zh + grow end
  end
  return { x0 = xl - m, x1 = xh + m, z0 = zl - m, z1 = zh + m }
end

-- the game's own band for attack sign `sign`: every x, the depth past the zone line (nil: line unknown)
local function band(field, sign)
  local line = zone_line()
  if not line or sign == 0 then return nil end
  local edge = field.centre_z + sign * line * field.half_z
  if sign > 0 then return { x0 = -BAND, x1 = BAND, z0 = edge, z1 = BAND } end
  return { x0 = -BAND, x1 = BAND, z0 = -BAND, z1 = edge }
end

-- the rectangle of an area kind for a team with attack sign `sign`
local function area_rect(kind, field, sign, extra)
  if kind == "retail" then return band(field, sign) end
  local b = attacked(field, sign, kind == "goal_area" and GOAL_AREA_FIRST or 0)
  return b and rect(b, extra, field) or nil
end

-- the area kind of a team: the user's / the rival's when the match has a user side, else `area`
local function kind_of(team, user)
  if user == 0 or user == 1 then return team == user and ZONE.user_area or ZONE.rival_area end
  return ZONE.area
end

-- keys read by the retail answers: the play controller flags address (every frame), line address and switch (once)
local function publish_chain()
  if not chain_published then
    chain_published = true
    local retail = ZONE.chain_retail
    local ok, line = pcall(VRFW.mem.global_addr, "shot_zone_line")
    if ok and type(line) == "number" and line >= 0x10000 then
      pcall(VRFW.state.set, KEY_LINE, line)
    else
      warn("zone area: no zone line address: a running zone and shot chains use the box")
      retail = false
    end
    local okf, off = pcall(VRFW.game.field, PLAY_FLAGS_FIELD)
    if okf and type(off) == "number" and off > 0 then
      play_flags_off = off
    else
      warn(string.format("zone area: game profile field %s does not resolve (%s): a running zone and shot chains use the box",
        PLAY_FLAGS_FIELD, tostring(okf and VRFW.game.status(PLAY_FLAGS_FIELD) or off)))
      retail = false
    end
    pcall(VRFW.state.set, KEY_CHAIN, retail and 1 or 0)
    info(string.format("zone area: a running zone and shot chains: %s; play control flags at +0x%X",
      retail and "the game's own area (chain_area = \"retail\")" or "the box", play_flags_off or 0))
  end
  local ctrl = global("shot_zone_play_ctrl")
  pcall(VRFW.state.set, KEY_PLAY_FLAGS, (ctrl and play_flags_off) and (ctrl + play_flags_off) or 0)
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

local function refresh(ev)
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
  local user = ev and ev.match and ev.match.user_team
  local k0, k1 = kind_of(0, user), kind_of(1, user)
  local line = zone_line() or 0
  local sig = table.concat({ s0, s1, field.centre_z, field.half_z, b1.x0, b1.z0, b1.x1, b1.z1, b2.x0, b2.z0, b2.x1, b2.z1, ex[0], ex[1], k0, k1, line }, ",")
  if sig == last_sig then return end
  last_sig = sig
  -- the field half a team attacks gets that team's rectangle (IsInAnyZoneArea); a half nobody attacks: `area`
  local entries, halves, parts = {}, {}, {}
  for team, s in pairs({ [0] = s0, [1] = s1 }) do
    local kind = team == 0 and k0 or k1
    local r = area_rect(kind, field, s, ex[team])
    local b = attacked(field, s, 0)
    if r and b then
      halves[b == b1 and 0 or 1] = r
      entries[#entries + 1] = { team, { x0 = r.x0, x1 = r.x1, z0 = r.z0, z1 = r.z1, cz = field.centre_z, sg = s, hz = field.half_z } }
    end
    parts[#parts + 1] = string.format("team %d %s %s", team, kind, r and string.format("x %.2f..%.2f z %.2f..%.2f", r.x0, r.x1, r.z0, r.z1) or "none")
  end
  for half, b in pairs({ [0] = b1, [1] = b2 }) do
    local r = halves[half]
    if not r then r = area_rect(ZONE.area, field, (b.cz - field.centre_z) >= 0 and 1 or -1, 0) end
    if r then entries[#entries + 1] = { ANY_FIRST + half, { x0 = r.x0, x1 = r.x1, z0 = r.z0, z1 = r.z1 } } end
  end
  local ok, err = pcall(VRFW.native.table_replace, BOX, nil, entries)
  filled = ok
  if not ok then
    warn("zone area: box table not written: " .. tostring(err))
    return
  end
  if field_logs < MAX_FIELD_LOGS then
    field_logs = field_logs + 1
    info(string.format("zone area: pitch half length %.2f centre z %.2f; box 0 %s, box 1 %s; attack signs %d / %d; user side %s; zone line %.2f; scale %.2f, margin %.1f m (+ extra: team 0 %.2f m, team 1 %.2f m); %s",
      field.half_z, field.centre_z, fmt_box(b1), fmt_box(b2), s0, s1, tostring(user), line, ZONE.scale, ZONE.margin, ex[0] or 0, ex[1] or 0, table.concat(parts, "; ")))
  end
end

-- ---- long shots

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

-- ---- events

if ZONE or #LONG_FLAGS > 0 then
  VRFW.on("tick", function(ev)
    if ZONE then refresh(ev) end
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
