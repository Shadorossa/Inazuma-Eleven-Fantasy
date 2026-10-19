-- Session state shared by the title, the native opponent list and the competition
-- root. It outlives RPG resets; no save data or unlock flags are written here.
BetterMenu = BetterMenu or {}
BetterMenu.CompetitionSession = {}
local state = { open = false, tab = 0, row = 0, mode = 0, game = 0, difficulty = 6,
  viewed = "", match = nil, returning = false, resume = false }
local homes, aliases, definitions, explicit = require("lib/competition_homes"), {}, {}, {}
local function id(v)
  if type(v) == "number" then return v % 4294967296 end
  if type(v) ~= "string" or v == "" then return nil end
  return aliases[v] or tonumber(v) or VRFW.crc32(v) % 4294967296
end
for _, file in ipairs(VRFW.files.declarations("content/teams")) do
  local data = type(file.data) == "table" and file.data or {}
  for _, row in ipairs(data.team or {}) do
    local key = row.key or row.name
    if key then
      local tid = id(key)
      if row.name then aliases[row.name] = tid end
      definitions[#definitions + 1] = { tid = tid, row = row }
    end
  end
  for _, row in ipairs(data.edit or {}) do
    local tid = id(row.target)
    if tid then definitions[#definitions + 1] = { tid = tid, row = row } end
  end
end
for _, def in ipairs(definitions) do
  if def.row.stadium then homes[def.tid], explicit[def.tid] = id(def.row.stadium), true end
end
for _ = 1, 4 do
  for _, def in ipairs(definitions) do
    local row, tid = def.row, def.tid
    local parent = id(row.based_on)
    local fallback = id(row.stadium_fallback)
    if parent and fallback and not explicit[parent] then homes[parent] = fallback end
    if not explicit[tid] then homes[tid] = (parent and homes[parent]) or fallback or homes[tid] end
  end
end

-- The picker's players on the clubhouse pitch (content\competition_court\*.toml): their places, each turned to face
-- the eye of the scene shot the file names. Read once, on the first ask.
local court = nil
local function shot_eye(scene, shot)
  for _, file in ipairs(VRFW.files.declarations("content/menu_scenes")) do
    local data = type(file.data) == "table" and file.data or {}
    local framework = type(data.VRFW) == "table" and data.VRFW or {}
    for _, row in ipairs(framework.MenuSceneShot or {}) do
      if row.scene == scene and row.name == shot then return row.eye_x, row.eye_z end
    end
  end
end
local framing = nil      -- the court file's camera settings and the captain's place
local framing_spacing = nil   -- the court file's [court.spacing]: how the places follow the bodies
local heights = nil      -- skeleton name -> standing height (content\competition_court\body_heights.toml)
local scales = nil       -- chara_base -> field scale (table character/chara_scale)

local function load_court()
  court, heights = {}, {}
  local ok, files = pcall(VRFW.files.declarations, "content/competition_court")
  for _, file in ipairs(ok and files or {}) do
    for _, b in ipairs(type(file.data) == "table" and file.data.body or {}) do
      if type(b.skeleton) == "string" and tonumber(b.height) then heights[b.skeleton] = tonumber(b.height) end
    end
    local data = type(file.data) == "table" and type(file.data.court) == "table" and file.data.court or {}
    if data.camera_heading then
      local sp = type(data.spacing) == "table" and data.spacing or {}
      framing_spacing = { width_ratio = tonumber(sp.width_ratio) or 0.3, gap = tonumber(sp.gap) or 0.3,
        back_per_metre = tonumber(sp.back_per_metre) or 2.5, margin = tonumber(sp.margin) or 0.06,
        step = tonumber(sp.step) or 0.15, max_back = tonumber(sp.max_back) or 12 }
      framing = { scene = data.scene, shot = data.shot, heading = tonumber(data.camera_heading) or 0,
        fov = tonumber(data.camera_fov) or 24, margin = tonumber(data.height_margin) or 1.15,
        left = tonumber(data.captain_left) or 0.5, base_height = tonumber(data.base_height) or 1.75 }
      if type(data.camera_eye) == "table" and type(data.camera_target) == "table" and #data.camera_eye == 3
          and #data.camera_target == 3 then
        framing.eye = { tonumber(data.camera_eye[1]), tonumber(data.camera_eye[2]), tonumber(data.camera_eye[3]) }
        framing.target = { tonumber(data.camera_target[1]), tonumber(data.camera_target[2]), tonumber(data.camera_target[3]) }
      end
    end
    local ex, ez = shot_eye(data.scene, data.shot)
    for _, spot in ipairs(data.spot or {}) do
      local x, y, z = tonumber(spot.x), tonumber(spot.y), tonumber(spot.z)
      if x and y and z then
        local turn = tonumber(spot.turn) or (ex and math.deg((math.atan2 or math.atan)(ex - x, ez - z))) or 0
        court[#court + 1] = { x = x, y = y, z = z, turn = turn }
      end
    end
  end
  VRFW.log("BetterMenu competition: " .. #court .. " player place(s) on the pitch")
end

-- a player's standing height: his skeleton's (the motion set c0NNNMM uses c0NNN01) times his field scale
local function height_of(base, set)
  if not scales then
    scales = {}
    local ok, rows = pcall(VRFW.table.rows, "character/chara_scale")
    for _, r in ipairs(ok and type(rows) == "table" and rows or {}) do
      local cid = tonumber(r.chara_id)
      if cid then scales[cid % 4294967296] = tonumber(r.field) or 1 end
    end
  end
  local skeleton = tostring(set or ""):sub(1, 5) .. "01"
  local h = heights[skeleton] or heights[tostring(set or "")] or 1.75
  return h * (scales[(tonumber(base) or 0) % 4294967296] or 1)
end

-- the Competition shot fitted to the three players: the camera on the court file's heading, far enough that the
-- tallest stands whole (its height x margin fills the screen's height), looking at mid height, the captain left of
-- the centre. members = "role:chara_base:motion set,…" -> eye x, y, z, target x, y, z, fov, tallest | ""
local function frame(members)
  if not court then pcall(load_court) end
  local p = court and court[1]
  if not (framing and p) then return "" end
  local tallest = 0
  for _, base, set in tostring(members or ""):gmatch("(%a+):(%d+):(%w+)") do
    tallest = math.max(tallest, height_of(base, set))
  end
  if tallest <= 0 then tallest = 1.75 end
  -- a declared camera (court.toml camera_eye / camera_target): always that picture (owner 2026-10-19: the players'
  -- places follow their sizes instead, «places»)
  if framing.eye and framing.target then
    local e, t = framing.eye, framing.target
    return e[1], e[2], e[3], t[1], t[2], t[3], framing.fov, tallest
  end
  local view = tallest * framing.margin
  local half = math.tan(math.rad(framing.fov) / 2)
  local distance = view / (2 * half)
  local a = math.rad(framing.heading)
  local dx, dz = math.sin(a), math.cos(a)              -- from the captain toward the eye
  local mid = p.y + tallest / 2
  local ex, ez = p.x + dx * distance, p.z + dz * distance
  -- the view's right (forward = -d): (-f_z, 0, f_x) = (dz, 0, -dx); the captain at -left of the half width
  local off = framing.left * distance * half * 16 / 9
  local tx, tz = p.x + dz * off, p.z - dx * off
  VRFW.log(string.format("BetterMenu competition: frame for the tallest %.2f m: %.2f m away, eye (%.2f, %.2f, %.2f)",
    tallest, distance, ex, mid, ez))
  return ex, mid, ez, tx, mid, tz, framing.fov, tallest
end

-- a standing body (feet at x, y, z, `h` tall, `w` half wide) inside the declared camera's frame: its head and its
-- shoulders, `margin` of the half frame kept free (vertical fov, 16:9); the legs may leave the frame's bottom (shot B
-- is from the thighs up)
local function inside_frame(x, y, z, h, w, margin)
  local e, t = framing.eye, framing.target
  local fx, fy, fz = t[1] - e[1], t[2] - e[2], t[3] - e[3]
  local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
  fx, fy, fz = fx / fl, fy / fl, fz / fl
  local rx, rz = -fz, fx                                  -- right = forward x up, on the ground
  local rl = math.sqrt(rx * rx + rz * rz)
  rx, rz = rx / rl, rz / rl
  local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy  -- up' = right x forward
  local ty = math.tan(math.rad(framing.fov) / 2)
  local tx = ty * 16 / 9
  local lim = 1 - margin
  for _, p in ipairs({ { 0, h }, { -w, h * 0.75 }, { w, h * 0.75 } }) do
    local px, py, pz = x + rx * p[1] - e[1], y + p[2] - e[2], z + rz * p[1] - e[3]
    local depth = px * fx + py * fy + pz * fz
    if depth <= 0.1 then return false end
    local sx = (px * rx + pz * rz) / (depth * tx)
    local sy = (px * ux + py * uy + pz * uz) / (depth * ty)
    if math.abs(sx) > lim or math.abs(sy) > lim then return false end
  end
  return true
end

-- the three places fitted to the bodies (owner 2026-10-19): the captain on his place; each other player from his own
-- place pushed back (away from the camera) by back_per_metre x how much taller than the captain he is, and out to the
-- side until his shoulders clear the captain's by `gap` (widths = height x width_ratio). members = "role:base:set,…"
-- in the court's order -> { [i] = { x, z, turn } } | ""
local function places(members)
  if not court then pcall(load_court) end
  if not (framing and framing.eye and framing.target and court and #court >= 1 and framing_spacing) then return "" end
  local sp = framing_spacing
  local h = {}
  for _, base, set in tostring(members or ""):gmatch("(%a+):(%d+):(%w+)") do h[#h + 1] = height_of(base, set) end
  if #h == 0 then return "" end
  -- the camera's ground axes: forward (away from the camera) and right
  local fx, fz = framing.target[1] - framing.eye[1], framing.target[3] - framing.eye[3]
  local len = math.sqrt(fx * fx + fz * fz)
  fx, fz = fx / len, fz / len
  local rx, rz = -fz, fx
  local c = court[1]
  -- back along the line from the camera until the body is inside the fixed frame (at most max_back)
  local function fit(x, z, height)
    local w, pushed = height * sp.width_ratio / 2, 0
    while not inside_frame(x, c.y, z, height, w, sp.margin) and pushed < sp.max_back do
      local ax, az = x - framing.eye[1], z - framing.eye[3]
      local al = math.sqrt(ax * ax + az * az)
      x, z = x + ax / al * sp.step, z + az / al * sp.step
      pushed = pushed + sp.step
    end
    return x, z
  end
  local cx, cz = fit(c.x, c.z, h[1])                      -- the captain too, only when he would be cut
  local out = { { x = cx, z = cz, turn = c.turn } }
  for i = 2, math.min(#h, #court) do
    local s = court[i]
    local dx, dz = s.x - c.x, s.z - c.z
    local side, depth = dx * rx + dz * rz, dx * fx + dz * fz
    depth = depth + math.max(0, h[i] - h[1]) * sp.back_per_metre
    local need = (h[1] + h[i]) * sp.width_ratio / 2 + sp.gap
    if math.abs(side) < need then side = (side < 0 and -1 or 1) * need end
    -- further back (keeping the angle from the camera, so he stays on his side) until his head, feet and shoulders
    -- are inside the fixed frame
    local x, z = fit(cx + rx * side + fx * depth, cz + rz * side + fz * depth, h[i])
    out[i] = { x = x, z = z, turn = s.turn }
  end
  return out
end

-- the screen x (1920 wide) of the three players' centre in the Competition shot framed for `members`: each court
-- spot projected with the same eye, target and field of view as frame(); nil = no court / framing
local function players_x(members)
  local ex, ey, ez, tx, _, tz, fov = frame(members)   -- (the ground plane only: the tilt of a low eye is left out)
  if type(ex) ~= "number" or not court or #court == 0 then return nil end
  local fx, fz = tx - ex, tz - ez
  local len = math.sqrt(fx * fx + fz * fz)
  if len <= 0 then return nil end
  fx, fz = fx / len, fz / len
  local rx, rz = -fz, fx                        -- the view's right on the ground
  local half_w = math.tan(math.rad(fov) / 2) * 16 / 9
  local sum, n = 0, 0
  for _, p in ipairs(court) do
    local vx, vz = p.x - ex, p.z - ez
    local depth = vx * fx + vz * fz
    if depth > 0 then
      sum, n = sum + 960 + 960 * (vx * rx + vz * rz) / (depth * half_w), n + 1
    end
  end
  if n == 0 then return nil end
  return sum / n
end

function BetterMenu.CompetitionSession.Command(op, a, b, c, d, e, f, g)
  if op == "court" then
    if not court then pcall(load_court) end
    return court or {}
  elseif op == "frame" then
    return frame(a)
  elseif op == "places" then
    local list = places(a)
    if type(list) ~= "table" then return "" end
    local parts = {}
    for i, p in ipairs(list) do parts[i] = string.format("%.3f,%.3f,%.1f", p.x, p.z, p.turn) end
    return table.concat(parts, ";")
  elseif op == "players_x" then
    return players_x(a or state.members) or 0
  elseif op == "stadium" then
    return homes[id(a)] or tonumber(b) or 0
  elseif op == "get" then
    local out = {}
    for k, v in pairs(state) do if k ~= "match" then out[k] = v end end
    out.launch = state.match ~= nil
    return out
  elseif op == "open" then
    state.open, state.mode = true, tonumber(a) or state.mode
    if b == true then state.tab, state.row, state.game, state.viewed = 0, 0, 0, "" end
    return true
  elseif op == "focus" then
    state.game, state.difficulty = tonumber(a) or 0, tonumber(b) or 6
    state.tab, state.row = tonumber(c) or 0, tonumber(d) or 0
    state.map, state.members, state.uniform = tonumber(e) or 0, tostring(f or ""), tonumber(g) or 0
    return true
  elseif op == "viewed" then
    state.viewed, state.resume = tostring(a or ""), true
    return true
  elseif op == "close" then
    state.open, state.resume = false, true
    state.mode = tonumber(a) or state.mode
    return true
  elseif op == "resumed" then
    state.resume = false
    return true
  elseif op == "launch" then
    if not state.open or (tonumber(a) or 0) == 0 then return false end
    state.match = { game = a, stadium = b, difficulty = c }
    state.resume = true
    return true
  elseif op == "take_match" then
    local match = state.match
    state.match = nil
    if match then state.returning = true end
    return match or ""
  elseif op == "returned" then
    state.returning = false
    return true
  end
  return false
end
