-- Character Reforged › the player page's 3D model in a match (graft plate_model, capture layer evt_pp_model_cap).
-- Declarations: content\game\player_page_capture.toml; engine side: docs/game/engine/menu-chara-capture.md.
--
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_CONFIG()  -> mode, camera, report, bust
--        mode 0 off / 1 in a match / 2 every screen; camera = the capture camera's name crc; report 1 = log the
--        report after each build; bust 1 = the bust camera (the model is placed at the origin for it)
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_REPORT(when, key, camera, model)  -> 1
--        loader.log: the menu capture render-texture pool (types 2 / 3: every cell, «ours» = the model key), the
--        render targets of slots 2 / 3, whether the camera is in the external camera config, the pause freeze state
--        and the model's CharaRenderProperty (model = its scene chara handle)
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_LIVE(on)  -> status
--        on 1: the capture models kept live in a pause (VRFW.render.capture_live); 0: left to the game (1 done, -1 not
--        available)
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_BIND(key, mesh)  -> 1 / -1
--        the framework keeps the quad mesh's render-texture entry on the capture model's live cell
--        (VRFW.render.capture_bind; key 0 = release); -1 = not available (loader.log says why)
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_BOUND()  -> 1 the quad shows the capture cell, 0 not yet, -1 not available
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_DRAWN(reset)  -> state
--        reset 1: a new wait starts (the capture quad was just set up), answers 2; reset 0: 1 = the framework's capture
--        probe saw a mesh of a capture model drawn into its render texture since then, 0 = none in
--        [player_page] match_no_draw_polls calls, 2 = still waiting, -1 = no probe (VRFW [debug] capture_pause_probe off)

CharacterReforged = CharacterReforged or {}
CharacterReforged.PageCapture = CharacterReforged.PageCapture or {}
local P = CharacterReforged.PageCapture

local MODES = {off = 0, match = 1, always = 2}   -- "auto": "match" while the framework's capture probe runs, else "off"
local CAMERAS = {vs = 0xB7EE99E6, bust = 0x059B5FFD}   -- VS screen full body (512 x 512, FOV 20); keeper gauge bust
local POOL_TYPES = {2, 3}
local MAX_ENTRIES, MAX_CAMERAS = 64, 4096

require "VRFW/lib/basics"
local log = VRFW.logger("player_page_capture")

local function setting(path, default)
  local ok, value = pcall(VRFW.files.config, path)
  if not ok or value == nil then return default end
  return value
end

local function read(kind, addr)
  if type(addr) ~= "number" or addr == 0 then return nil end
  local ok, v = pcall(VRFW.mem.read, kind, addr)
  if ok then return v end
  return nil
end

local Id = require "VRFW/lib/ids"
local function hex(v)
  if type(v) ~= "number" then return tostring(v) end
  return Id.hex(v)
end

local function hex64(v)
  if type(v) ~= "number" then return tostring(v) end
  return string.format("0x%X%08X", math.floor(v / 4294967296), v % 4294967296)
end

-- the game profile's value of a name (a struct field's offset, a struct's size, an offset), nil when it does not resolve
local function field(name)
  local ok, v = pcall(VRFW.game.field, name)
  if ok and type(v) == "number" then return v end
  return nil
end

-- the address of a game profile global, nil when it does not resolve
local function global_address(name)
  local ok, at = pcall(VRFW.game.sym, name)
  if ok and type(at) == "number" and at ~= 0 then return at end
  return nil
end

-- the profile field `name` of the record at `base` (+ `extra` bytes); nil when the record or the field is unknown
local function read_field(kind, base, name, extra)
  local at = field(name)
  if type(base) ~= "number" or not at then return nil end
  return read(kind, base + at + (extra or 0))
end

-- the framework's menu capture probe (VRFW [debug] capture_pause_probe), or nil when it is not running
local function probe()
  if type(VRFW.render) ~= "table" or type(VRFW.render.capture_pause) ~= "function" then return nil end
  local ok, s = pcall(VRFW.render.capture_pause)
  if ok and type(s) == "table" and s.installed then return s end
  return nil
end

function P.Config()
  local name = setting("player_page.match_model", "auto")
  local mode = MODES[name] or MODES.off
  local has_probe = probe() ~= nil
  if name == "auto" then mode = has_probe and MODES.match or MODES.off end
  local camera_name = setting("player_page.match_camera", "vs")
  local camera = CAMERAS[camera_name] or (type(camera_name) == "number" and camera_name) or CAMERAS.vs
  local report = setting("player_page.capture_report", true) == true and 1 or 0
  local live = setting("player_page.match_live_pause", false) == true and 1 or 0
  -- the quad stays hidden until the probe sees the model drawn (no white placeholder); only with the probe
  local gate = (has_probe and setting("player_page.match_quad_until_drawn", true) == true) and 1 or 0
  if mode ~= MODES.off or name == "auto" then
    log(string.format("config: match_model %s -> mode %d, capture probe %s, quad until drawn %d", tostring(name), mode,
      has_probe and "running" or "off", gate))
  end
  return mode, camera, report, camera == CAMERAS.bust and 1 or 0, live, gate
end

local wait = nil   -- the current wait for a drawn capture: probe session / drawn frames at its start, polls, answer

local function probe_line(s, why)
  log(string.format("probe %s: session %d frames %d paused %d drawn %d since draw %d idle %d ms | last frame queued %d into target %d type-1 pass %d no target %d draw flag off %d",
    why, s.session, s.frames, s.paused_frames, s.drawn_frames, s.frames_since_draw, s.idle_ms, s.queued, s.into_target,
    s.type1_pass, s.no_target, s.flag_off))
end

function P.Drawn(reset)
  local s = probe()
  if not s then return -1 end
  if reset == 1 or wait == nil then
    wait = {session = s.session, drawn = s.drawn_frames, polls = 0, answer = 2}
    probe_line(s, "wait start")
    return 2
  end
  wait.polls = wait.polls + 1
  local drawn = s.session ~= wait.session and s.drawn_frames or (s.drawn_frames - wait.drawn)
  local lost = setting("player_page.match_lost_frames", 30)
  local answer = 2
  if drawn > 0 and s.frames_since_draw <= lost then
    answer = 1
  elseif drawn > 0 or wait.polls >= setting("player_page.match_no_draw_polls", 24) then
    answer = 0
  end
  if answer ~= wait.answer then
    wait.answer = answer
    probe_line(s, answer == 1 and "drawn: quad shown" or (answer == 0 and "no draw: quad hidden" or "waiting"))
  end
  return answer
end

local function report_pool(key)
  local var = global_address("Render.CapturePool")
  local pool = read("ptr", var)
  if not pool or pool == 0 then
    log("pool: not reachable (Render.CapturePool " .. tostring(var and hex(var) or "unresolved") .. ")")
    return
  end
  local entries, count = read_field("ptr", pool, "CapturePool.Cells"), read_field("u16", pool, "CapturePool.CellCount") or 0
  local mask = read_field("u32", pool, "CapturePool.LiveTypes")
  local types = {}
  for _, t in ipairs(POOL_TYPES) do
    types[#types + 1] = string.format("type %d grid %sx%s capacity %s", t,
      tostring(read_field("u8", pool, "CapturePool.GridColumns", t * 2)),
      tostring(read_field("u8", pool, "CapturePool.GridRows", t * 2)),
      tostring(read_field("u8", pool, "CapturePool.TypeCapacity", t)))
  end
  log(string.format("pool %s entries %d live types mask %s; %s", hex(pool), count, hex(mask), table.concat(types, ", ")))
  local cell_size = field("CaptureCell")
  local ours = 0
  for i = 0, math.min(count, MAX_ENTRIES) - 1 do
    local e = entries and cell_size and entries + i * cell_size
    local handle = read_field("u32", e, "CaptureCell.Handle")
    if handle and handle ~= 0 then
      local t = math.floor(handle / 256) % 256
      local k = read_field("u32", e, "CaptureCell.Key")
      if t == 2 or t == 3 then
        local mine = k == key
        if mine then ours = ours + 1 end
        log(string.format("cell %d handle %s type %d key %s%s cell %s live %s shown %s freeing %s users %s scale %s",
          i, hex(handle), t, hex(k), mine and " (ours)" or "", tostring(read_field("u8", e, "CaptureCell.Cell")),
          tostring(read_field("u8", e, "CaptureCell.Live")), tostring(read_field("u8", e, "CaptureCell.Shown")),
          tostring(read_field("u8", e, "CaptureCell.Freeing")), tostring(read_field("u32", e, "CaptureCell.Users")),
          tostring(read_field("f32", e, "CaptureCell.Scale"))))
      end
    end
  end
  log(string.format("cells with our key %s: %d", hex(key), ours))
end

local function report_targets()
  local var = global_address("Render.TargetManager")
  local manager = read("ptr", var)
  local target_size = field("RenderTarget")
  if not manager or manager == 0 or not target_size then
    log("render targets: not reachable (Render.TargetManager " .. tostring(var and hex(var) or "unresolved") .. ")")
    return
  end
  for _, slot in ipairs(POOL_TYPES) do
    local s = manager + slot * target_size
    log(string.format("render target slot %d users %s pending free %s size %sx%s", slot,
      tostring(read_field("u32", s, "RenderTarget.Users")), tostring(read_field("u8", s, "RenderTarget.PendingFree")),
      tostring(read_field("u16", s, "RenderTarget.Width")), tostring(read_field("u16", s, "RenderTarget.Height"))))
  end
end

local function report_camera(camera)
  local config = global_address("Camera.ExternalConfig")
  local entries, count = read_field("ptr", config, "CameraConfig.Entries"), read_field("u32", config, "CameraConfig.Count")
  local entry_size, name_at = field("CameraConfigEntry"), field("CameraConfigEntry.Name")
  if not entries or not count or count == 0 or count > MAX_CAMERAS or not entry_size or not name_at then
    log("camera config: not reachable (Camera.ExternalConfig " .. tostring(config and hex(config) or "unresolved") .. ")")
    return
  end
  local ok, names = pcall(VRFW.mem.read_array, "u32", entries + name_at, count, entry_size)
  if not ok or type(names) ~= "table" then
    log("camera config: entries not readable")
    return
  end
  local found = nil
  for i, name in ipairs(names) do
    if name == camera then found = i - 1 break end
  end
  log(string.format("camera %s in the external camera config (%d cameras): %s", hex(camera), count,
    found and ("entry " .. found) or "MISSING"))
end

local function report_pause()
  local view = read_field("ptr", global_address("Render.System"), "RenderSystem.View")
  local settings = global_address("Render.Settings")
  log(string.format("pause: time scale %s, render settings pause flags %s %s %s (time scale <= 0 with the first two set = the pause freeze: a CharaRenderProperty's drawn flag goes 0)",
    tostring(read_field("f32", view, "RenderView.TimeScale")), tostring(read_field("u8", settings, "RenderSettings.PauseFlag1")),
    tostring(read_field("u8", settings, "RenderSettings.PauseFlag2")), tostring(read_field("u8", settings, "RenderSettings.PauseFlag3"))))
end

local function report_model(model)
  if type(model) ~= "number" or model == 0 then
    log("model: no handle")
    return
  end
  local manager = read("ptr", global_address("Scene.GameState"))
  local records = read_field("ptr", manager, "Scene.CharaObjects")
  local index = model % 65536
  local count, size, base = field("Scene.CharaObjectCount"), field("Scene.CharaObjectSize"), field("Scene.CharaObjectBase")
  local object = records and count and size and base and index < count and records + index * size + base
  local handle = read_field("u32", object, "Scene.CharaObjectHandle")
  if handle ~= model then
    log(string.format("model %s: no scene chara record (found %s)", hex(model), hex(handle)))
    return
  end
  local p = read_field("ptr", object, "Scene.CharaObjectRenderProperty")
  log(string.format("model %s: record flags %s, CharaRenderProperty %s", hex(model),
    hex(read_field("u8", object, "Scene.CharaObjectFlags")), p and hex64(p) or "nil"))
  if not p or p == 0 then return end
  local function f(kind, name, extra) return read_field(kind, p, "CharaRenderProperty." .. name, extra) end
  local function b(name) return tostring(f("u8", name)) end
  log(string.format("render property: camera %s view %s handle %s capture %s last %s drawn %s cell on %s mask %s slot %s mask slot %s viewport %s %s %s %s",
    hex(f("u32", "Camera")), tostring(f("u16", "View")), hex(f("u32", "Handle")), b("Capture"), b("LastCapture"), b("Drawn"),
    b("CellOn"), b("Mask"), b("Slot"), b("MaskSlot"), tostring(f("u32", "Viewport")), tostring(f("u32", "Viewport", 4)),
    tostring(f("u32", "Viewport", 8)), tostring(f("u32", "Viewport", 12))))
  local proxy = f("ptr", "Proxy")
  if proxy and proxy ~= 0 then
    log(string.format("render proxy: slot %s mode %s state %s flags %s", tostring(read_field("u8", proxy, "RenderProxy.Slot")),
      tostring(read_field("u16", proxy, "RenderProxy.Mode")), tostring(read_field("u8", proxy, "RenderProxy.State")),
      hex(read_field("u8", proxy, "RenderProxy.Flags"))))
  else
    log("render proxy: none")
  end
end

-- on 1: the capture models kept live in a pause (VRFW.render.capture_live: the frozen texture of a pause is not shown,
-- the render texture the model is drawn into each frame is); 0: left to the game again
function P.Live(on)
  local live = VRFW.render and VRFW.render.capture_live
  if type(live) ~= "function" then return -1 end
  local was, why = live(on == 1)
  if was == nil then
    log("live capture not available: " .. tostring(why))
    return -1
  end
  return 1
end

-- the framework's quad binding (VRFW.render.capture_bind / capture_bound)
function P.Bind(key, mesh)
  local bind = VRFW.render and VRFW.render.capture_bind
  if type(bind) ~= "function" then return -1 end
  local ok, why = bind(type(key) == "number" and key % 4294967296 or 0, type(mesh) == "number" and mesh % 4294967296 or 0)
  if not ok then
    log("quad binding not available: " .. tostring(why))
    return -1
  end
  return 1
end

-- the last binding state logged (one line when it changes: why a quad stays hidden until bound)
local bound_seen = nil

function P.Bound()
  local bound = VRFW.render and VRFW.render.capture_bound
  if type(bound) ~= "function" then return -1 end
  local ok, s = pcall(bound)
  if not ok or type(s) ~= "table" then return -1 end
  local seen = tostring(s.bound) .. " " .. tostring(s.reason) .. " " .. tostring((s.frames or 0) > 0)
  if seen ~= bound_seen then
    bound_seen = seen
    log("bound " .. tostring(s.bound) .. " key " .. hex(s.key or 0) .. " mesh " .. hex(s.mesh or 0) .. " frames "
      .. tostring(s.frames) .. " repairs " .. tostring(s.repairs) .. " idle_ms " .. tostring(s.idle_ms) .. " reason "
      .. tostring(s.reason))
  end
  return s.bound and 1 or 0
end

function P.Report(when, key, camera, model)
  local ok, err = pcall(function()
    key = type(key) == "number" and key % 4294967296 or 0
    camera = type(camera) == "number" and camera % 4294967296 or CAMERAS.vs
    log("report " .. tostring(when) .. " (model key " .. hex(key) .. ")")
    report_pool(key)
    report_targets()
    report_camera(camera)
    report_pause()
    report_model(type(model) == "number" and model % 4294967296 or 0)
  end)
  if not ok then log("report failed: " .. tostring(err)) end
  return 1
end

log("player page capture commands ready (CMND_CHARACTERREFORGED_PAGE_CAPTURE_CONFIG / _REPORT / _LIVE / _DRAWN / _BIND / _BOUND)")
