-- ===== SoulsRework level pop BEGIN =====
-- Souls Rework's level-up pop (match play HUD; docs/game/mods/souls-rework-design.md §9.5). Each time a totem gains a
-- level, the module's script queues a pop (CMND_AURAREWORKED_SOULS_LEVEL_POP(seen) -> seq, scene, handle, text, colour,
-- timing, sizes; config.toml [souls.level_pop]); this block draws it over that player's head and keeps it there while he
-- moves: a small plate of the totem's element colour with «+Nv.2» on it pops in (scale and fade in), stays, then rises
-- and fades out. While a cut-in or a match scene plays (scene = 1, the framework's cutin_start / cutin_end) every pop is
-- hidden; its time runs on, and it shows again after the scene only while that time is not over.
-- Layer souls_rework_level_pop (the module's content\menus\level_pop.toml: the retail AI-camera telop with the face
-- bubble's anchoring, 4 instances = 4 pops). Each pop is one instance: its quad shows the module's own white plate
-- (content\images\menu\02_btl\souls_rework_pop.toml) tinted with CMND_SET_PRIM_COLOR, and the telop's own text node on
-- that quad carries the text, so both scale together (one uniform scale from the configured height).
-- Placement is the retail one of the face bubbles over a player (GetCharaScreenPos of the play HUD's include): the
-- head position (GetSoccerCharaInfo info 10) through the match camera (0xFC77769A) gives the layer position; layout
-- offsets go through the retail layout -> position conversion (1192474820). Each instance's node offset is measured
-- once per HUD (as the Furor banner does), so the plate is centred on the head. The plate's colour and the text are set
-- right after the instance is shown (and again on every show).
-- Wrapper of PostStep only (every frame of the play HUD); no engine call at chunk load; every engine call in pcall.
-- loader.log: the first lines «SOULSREWORK_POP ...», then one «SOULSREWORK_POP pop ...» / «... shown ...» per pop.

local souls_pop = {
  CMD = @crc:CMND_AURAREWORKED_SOULS_LEVEL_POP@,
  LAYER = @crc:souls_rework_level_pop@,
  QUAD = @crc:_camera_telop01@,
  QUAD_W = 350, QUAD_H = 72,                  -- the quad node's size at scale 1 (layout units)
  TEXT = @crc:_text_telop01@,                 -- the telop's text node, on the quad
  TEXTURE_SLOT = @crc:camera_telop01@,        -- the quad's texture slot
  ATLAS_PATH = "#/menu/02_btl/souls_rework_pop/souls_rework_pop.g4tx",
  ATLAS = 1266033038 --[[#/menu/02_btl/souls_rework_pop/souls_rework_pop.g4tx]],
  SPRITE = @crc:souls_rework_pop_plate@,
  SLOTS = 4,                                  -- pops at once (one instance each: instance = slot)
  APPEAR_FROM = 0.6,                          -- the pop's scale when it starts to appear
  PROBE_STEP = 100,
  PROBE_WAIT = 2,
  MAX_LOGS = 30,
  -- engine commands
  CHARA_INFO = 3748253003 --[[GetSoccerCharaInfo's command]],
  WORLD_TO_SCREEN = 4235687578 --[[CalcCharaScreenPos's command (x, y, z, true) -> screen x, y]],
  LAYOUT_TO_POS = 1192474820 --[[layout offset -> layer position offset]],
  FRAME_SECONDS = 1549797111,
  LOG = 3661580131 --[[CMND_EVT_LOG]],
  GLOBAL_POS = 499270986 --[[CMND_GET_MESH_GLOBAL_POSITION]],
  SET_POS = 1389957207 --[[CMND_SET_LAYER_LOCAL_POS]],
  SET_SCALE = 3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]],
  SET_TEXT = 1083631230 --[[CMND_SET_MENU_TEXT_STRING]],
  MESH_VISIBLE = 3405944500 --[[CMND_SET_MESH_VISIBLE]],
  LAYER_VISIBLE = 711242136 --[[CMND_SET_LAYER_VISIBLE]],
  PRIM_COLOR = 855211291 --[[CMND_SET_PRIM_COLOR (layer, idx, mesh, r, g, b)]],
  MODEL_ALPHA = 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA (layer, idx, 0, a)]],
  TEXT_ALPHA = 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA (layer, idx, node, a)]],
  IS_OPEN = 2640875187 --[[CMND_IS_OPEN_LAYER]],
  IS_LOADING = 3057768039 --[[CMND_IS_LOADING_LAYER]],
  OPEN_ARRAY = 2152386330 --[[CMND_OPEN_LAYER_ARRAY]],
  LOAD_TEXTURE = 839427544 --[[CMND_LOAD_MENU_RES_TEXTURE]],
  TEXTURE_LOADING = 1506186496 --[[the texture is still loading]],
  SWAP_TEXTURE = 558735651 --[[swap a mesh texture for an atlas sprite]],
  -- state (per HUD)
  seen = 0,                                   -- the last pop seq taken
  init = false, texture = 0, conv = nil,
  node = {}, probe = {}, ready = {},          -- per instance (0-based): node offset in position units, probe, look set
  pops = {},                                  -- per slot: { hdl, text, r, g, b, timing, t, shown }
  scene = false,                              -- a cut-in or a match scene plays (the last answer of the command)
  logs = 0,
}

function souls_pop.Menu(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

function souls_pop.Command(...)
  if type(funcLuaCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

function souls_pop.Log(...)
  if souls_pop.logs >= souls_pop.MAX_LOGS then
    return
  end
  souls_pop.logs = souls_pop.logs + 1
  souls_pop.Command(souls_pop.LOG, "SOULSREWORK_POP", ...)
end

-- one line per pop event (not counted against MAX_LOGS)
function souls_pop.Event(...)
  souls_pop.Command(souls_pop.LOG, "SOULSREWORK_POP", ...)
end

function souls_pop.Global(i, node)
  local x, y = souls_pop.Menu(souls_pop.GLOBAL_POS, souls_pop.LAYER, i, node)
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  return x, y
end

-- an instance's node offset from its layer position, in position units at scale 1:
-- global = origin + unit * position + scale * node (as the Furor banner's probe)
function souls_pop.Probe(i)
  if souls_pop.node[i] ~= nil then
    return souls_pop.node[i] ~= false
  end
  local layer, node = souls_pop.LAYER, souls_pop.QUAD
  local p = souls_pop.probe[i]
  if p == nil then
    souls_pop.probe[i] = {stage = 1, wait = souls_pop.PROBE_WAIT}
    souls_pop.Menu(souls_pop.SET_SCALE, layer, 1, 1, 1, i)
    souls_pop.Menu(souls_pop.SET_POS, layer, 0, 0, 0, i)
    return false
  end
  if p.wait > 0 then
    p.wait = p.wait - 1
    return false
  end
  local x, y = souls_pop.Global(i, node)
  if x == nil then
    souls_pop.node[i] = false
    souls_pop.Log("instance", i, "no global position for its node: off")
    return false
  end
  local step = souls_pop.PROBE_STEP
  if p.stage == 1 then
    p.x1, p.y1, p.stage, p.wait = x, y, 2, souls_pop.PROBE_WAIT
    souls_pop.Menu(souls_pop.SET_POS, layer, step, step, 0, i)
    return false
  end
  if p.stage == 2 then
    p.x2, p.y2, p.stage, p.wait = x, y, 3, souls_pop.PROBE_WAIT
    souls_pop.Menu(souls_pop.SET_POS, layer, 0, 0, 0, i)
    souls_pop.Menu(souls_pop.SET_SCALE, layer, 2, 2, 1, i)
    return false
  end
  local unit_x, unit_y = (p.x2 - p.x1) / step, (p.y2 - p.y1) / step
  if math.abs(unit_x) < 0.01 or math.abs(unit_y) < 0.01 then
    souls_pop.node[i] = false
    souls_pop.Log("instance", i, "its position does not move its node: off")
    return false
  end
  souls_pop.node[i] = {x = (x - p.x1) / unit_x, y = (y - p.y1) / unit_y}
  souls_pop.Menu(souls_pop.SET_SCALE, layer, 1, 1, 1, i)
  souls_pop.Log("instance", i, "node offset", string.format("%.1f %.1f", souls_pop.node[i].x, souls_pop.node[i].y))
  return true
end

-- layout units -> position units (the retail conversion, measured once per HUD; y up)
function souls_pop.Conv()
  if souls_pop.conv == nil then
    local ok, x, y = souls_pop.Menu(souls_pop.LAYOUT_TO_POS, 100, 100)
    if ok and type(x) == "number" and type(y) == "number" and x ~= 0 and y ~= 0 then
      souls_pop.conv = {x = x / 100, y = y / 100}
    else
      souls_pop.conv = {x = 1, y = 1}
    end
    souls_pop.Log("layout -> position", string.format("%.3f %.3f", souls_pop.conv.x, souls_pop.conv.y))
  end
  return souls_pop.conv
end

-- the player's head in layer position units (the retail GetCharaScreenPos(hdl, true, 0, 0, 1)); nil off the pitch or
-- off camera
function souls_pop.Head(hdl)
  local has, x, y, z = souls_pop.Command(souls_pop.CHARA_INFO, hdl, 10)
  if has ~= true or type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
    return nil
  end
  local sx, sy = souls_pop.Command(souls_pop.WORLD_TO_SCREEN, x, y, z, true)
  if type(sx) ~= "number" or type(sy) ~= "number" or (sx == x and sy == y) or (sx == 0 and sy == 0) then
    return nil
  end
  return sx, -sy
end

function souls_pop.Hide(slot)
  local pop = souls_pop.pops[slot]
  if pop and pop.shown then
    pop.shown = false
    souls_pop.Menu(souls_pop.LAYER_VISIBLE, souls_pop.LAYER, slot, false)
  end
end

-- an instance's fixed look: the module's plate sprite on its quad
function souls_pop.Prepare(i)
  souls_pop.ready[i] = true
  souls_pop.Menu(souls_pop.SWAP_TEXTURE, souls_pop.LAYER, souls_pop.ATLAS, souls_pop.SPRITE, souls_pop.TEXTURE_SLOT, 0, i)
  souls_pop.Menu(souls_pop.SET_TEXT, souls_pop.LAYER, souls_pop.TEXT, "", i)
end

function souls_pop.TextureReady()
  if souls_pop.texture == 0 then
    souls_pop.Menu(souls_pop.LOAD_TEXTURE, souls_pop.ATLAS_PATH)
    souls_pop.texture = 1
    return false
  end
  if souls_pop.texture == 1 then
    local loading = souls_pop.Command(souls_pop.TEXTURE_LOADING, souls_pop.ATLAS)
    if loading == false then
      souls_pop.texture = 2
      souls_pop.Log("atlas in", souls_pop.ATLAS_PATH)
    end
  end
  return souls_pop.texture == 2
end

-- a new pop takes a free slot (else the oldest one)
function souls_pop.Start(r)
  local slot, oldest = nil, nil
  for s = 0, souls_pop.SLOTS - 1 do
    local pop = souls_pop.pops[s]
    if pop == nil then
      slot = s
      break
    end
    if oldest == nil or pop.t > souls_pop.pops[oldest].t then
      oldest = s
    end
  end
  if slot == nil then
    slot = oldest
    souls_pop.Hide(slot)
  end
  local pop = {hdl = r[3], text = tostring(r[4] or ""), r = tonumber(r[5]) or 1, g = tonumber(r[6]) or 1,
    b = tonumber(r[7]) or 1, appear = math.max(0.01, tonumber(r[8]) or 0.15), hold = math.max(0, tonumber(r[9]) or 1),
    out = math.max(0.01, tonumber(r[10]) or 0.4), height = tonumber(r[11]) or 36, lift = tonumber(r[12]) or 24,
    rise = tonumber(r[13]) or 40, t = 0, shown = false}
  souls_pop.pops[slot] = pop
  souls_pop.Event("pop", r[1], "hdl", pop.hdl, pop.text, string.format("rgb %.2f %.2f %.2f", pop.r, pop.g, pop.b), "slot",
    slot, string.format("hold %.2f s", pop.hold))
end

-- the pop's colour and text, on its instance once it is visible
function souls_pop.Dress(slot, pop)
  local layer = souls_pop.LAYER
  souls_pop.Menu(souls_pop.PRIM_COLOR, layer, slot, souls_pop.QUAD, pop.r, pop.g, pop.b)
  souls_pop.Menu(souls_pop.SET_TEXT, layer, souls_pop.TEXT, pop.text, slot)
  souls_pop.Event("shown", "slot", slot, pop.text)
end

function souls_pop.Poll()
  for _ = 1, souls_pop.SLOTS do
    local r = table.pack(souls_pop.Command(souls_pop.CMD, souls_pop.seen))
    local seq = r[1]
    local scene = r[2] == 1
    if scene ~= souls_pop.scene then
      souls_pop.scene = scene
      souls_pop.Event(scene and "scene: pops hidden" or "scene over")
    end
    if type(seq) ~= "number" or seq <= souls_pop.seen then
      return
    end
    souls_pop.seen = seq
    souls_pop.Start(r)
  end
end

-- the pop's scale (k), alpha and rise (layout units) at time t; nil = over
function souls_pop.Look(pop)
  local t = pop.t
  if t < pop.appear then
    local u = t / pop.appear
    -- ease out with a small overshoot
    local c = 1.70158
    local e = 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2
    return souls_pop.APPEAR_FROM + (1 - souls_pop.APPEAR_FROM) * e, u, 0
  end
  t = t - pop.appear
  if t < pop.hold then
    return 1, 1, 0
  end
  t = t - pop.hold
  if t < pop.out then
    local v = t / pop.out
    return 1, 1 - v, pop.rise * (1 - (1 - v) ^ 2)
  end
  return nil
end

-- instance i's box (w x h position units) centred on (cx, cy) at scale (sx, sy)
function souls_pop.Place(i, cx, cy, w, h, sx, sy)
  local n = souls_pop.node[i]
  local layer = souls_pop.LAYER
  souls_pop.Menu(souls_pop.SET_SCALE, layer, sx, sy, 1, i)
  souls_pop.Menu(souls_pop.SET_POS, layer, cx - w / 2 - sx * n.x, cy + h / 2 - sy * n.y, 0, i)
end

function souls_pop.Draw(slot, pop, dt)
  pop.t = pop.t + dt
  local k, alpha, rise = souls_pop.Look(pop)
  if k == nil then
    souls_pop.Hide(slot)
    souls_pop.pops[slot] = nil
    return
  end
  if souls_pop.scene then
    souls_pop.Hide(slot)
    return
  end
  local plate = slot
  if not souls_pop.node[plate] then
    return
  end
  local hx, hy = souls_pop.Head(pop.hdl)
  if hx == nil then
    souls_pop.Hide(slot)
    return
  end
  local cv = souls_pop.Conv()
  -- the plate's centre: above the head by the lift, half the plate, and the rise
  local cx = hx
  local cy = hy + (pop.lift + pop.height / 2 + rise) * cv.y
  -- one uniform scale for the quad and its text: the configured height over the quad's
  local s = pop.height * k / souls_pop.QUAD_H
  souls_pop.Place(plate, cx, cy, souls_pop.QUAD_W * s * cv.x, souls_pop.QUAD_H * s * cv.y, s, s)
  local layer = souls_pop.LAYER
  souls_pop.Menu(souls_pop.MODEL_ALPHA, layer, plate, 0, alpha)
  souls_pop.Menu(souls_pop.TEXT_ALPHA, layer, plate, souls_pop.TEXT, alpha)
  if not pop.shown then
    pop.shown = true
    souls_pop.Menu(souls_pop.LAYER_VISIBLE, layer, plate, true)
    souls_pop.Dress(slot, pop)
  end
end

function SoulsReworkPop_Step()
  local layer = souls_pop.LAYER
  if souls_pop.Menu(souls_pop.IS_OPEN, layer) ~= true then
    souls_pop.init, souls_pop.conv = false, nil
    souls_pop.node, souls_pop.probe, souls_pop.ready, souls_pop.pops = {}, {}, {}, {}
    souls_pop.Menu(souls_pop.OPEN_ARRAY, layer)
    return
  end
  if souls_pop.Menu(souls_pop.IS_LOADING, layer) == true then
    return
  end
  -- the layer opens with its instances visible at the retail telop's place: hidden until a pop places them
  if not souls_pop.init then
    souls_pop.init = true
    for i = 0, souls_pop.SLOTS - 1 do
      souls_pop.Menu(souls_pop.LAYER_VISIBLE, layer, i, false)
    end
    souls_pop.Log("layer open: instances hidden")
  end
  if not souls_pop.TextureReady() then
    return
  end
  local all = true
  for i = 0, souls_pop.SLOTS - 1 do
    if not souls_pop.ready[i] then
      souls_pop.Prepare(i)
    end
    if souls_pop.node[i] == nil then
      souls_pop.Probe(i)
      all = false
    end
  end
  if not all then
    return
  end
  souls_pop.Poll()
  local dt = souls_pop.Command(souls_pop.FRAME_SECONDS)
  if type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
    dt = 1 / 60
  end
  for slot = 0, souls_pop.SLOTS - 1 do
    local pop = souls_pop.pops[slot]
    if pop then
      souls_pop.Draw(slot, pop, dt)
    end
  end
end

local SoulsReworkPop_previousPostStep = rawget(_ENV, "PostStep")
function PostStep(...)
  local r = {n = 0}
  if type(SoulsReworkPop_previousPostStep) == "function" then
    r = table.pack(SoulsReworkPop_previousPostStep(...))
  end
  local ok, err = pcall(SoulsReworkPop_Step)
  if not ok then
    souls_pop.Log("step error", tostring(err))
  end
  return table.unpack(r, 1, r.n)
end
-- ===== SoulsRework level pop END =====
