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
--        on 1: the render settings' pause freeze flag (+0xD8) saved and cleared; 0: put back (1 done, 0 nothing to do,
--        -1 not reachable)
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
local ENTRY_SIZE, TARGET_SIZE, CAMERA_SIZE = 0x38, 0x70, 0x5C
local MAX_ENTRIES, MAX_CAMERAS = 64, 4096

local function log(...) VRFW.log("player_page_capture:", ...) end
local RECORD_SIZE, RECORD_HANDLE, RECORD_FLAGS, RECORD_RENDER = 0x1460, 0x80, 0x70, 0x7D0   -- scene chara records
local FREEZE_FLAG = 0xD8                                                                     -- render settings
local saved_freeze = nil

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

local function hex(v)
  if type(v) ~= "number" then return tostring(v) end
  v = v % 4294967296
  return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
end

local function hex64(v)
  if type(v) ~= "number" then return tostring(v) end
  return string.format("0x%X%08X", math.floor(v / 4294967296), v % 4294967296)
end

-- the variable a RIP-relative instruction at `at` addresses (disp32 at +3, 7-byte instruction)
local function rip_target(at)
  local disp = read("i32", at + 3)
  if not disp then return nil end
  return at + 7 + disp
end

local function profile_address(name, offset)
  local ok, at = pcall(VRFW.game.sym, name)
  if not ok or type(at) ~= "number" or at == 0 then return nil end
  return rip_target(at + (offset or 0))
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
  local var = profile_address("Render.SetCaptureGrid", 0)
  local pool = read("ptr", var)
  if not pool or pool == 0 then
    log("pool: not reachable (Render.SetCaptureGrid " .. tostring(var and hex(var) or "unresolved") .. ")")
    return
  end
  local entries, count = read("ptr", pool + 8), read("u16", pool + 0xC0) or 0
  local mask = read("u32", pool + 0xB8)
  local types = {}
  for _, t in ipairs(POOL_TYPES) do
    types[#types + 1] = string.format("type %d grid %sx%s capacity %s", t, tostring(read("u8", pool + 0xC2 + t * 2)),
      tostring(read("u8", pool + 0xC3 + t * 2)), tostring(read("u8", pool + 0xD0 + t)))
  end
  log(string.format("pool %s entries %d live types mask %s; %s", hex(pool), count, hex(mask), table.concat(types, ", ")))
  local ours = 0
  for i = 0, math.min(count, MAX_ENTRIES) - 1 do
    local e = entries and entries + i * ENTRY_SIZE
    local handle = read("u32", e and e + 8)
    if handle and handle ~= 0 then
      local t = math.floor(handle / 256) % 256
      local k = read("u32", e + 0x1C)
      if t == 2 or t == 3 then
        local mine = k == key
        if mine then ours = ours + 1 end
        log(string.format("cell %d handle %s type %d key %s%s cell %s live %s shown %s freeing %s users %s scale %s",
          i, hex(handle), t, hex(k), mine and " (ours)" or "", tostring(read("u8", e + 0x30)), tostring(read("u8", e + 0x31)),
          tostring(read("u8", e + 0x32)), tostring(read("u8", e + 0x33)), tostring(read("u32", e + 0x2C)),
          tostring(read("f32", e + 0x28))))
      end
    end
  end
  log(string.format("cells with our key %s: %d", hex(key), ours))
end

local function report_targets()
  local var = profile_address("Render.GetTarget", 0)
  local manager = read("ptr", var)
  if not manager or manager == 0 then
    log("render targets: not reachable (Render.GetTarget " .. tostring(var and hex(var) or "unresolved") .. ")")
    return
  end
  for _, slot in ipairs(POOL_TYPES) do
    local s = manager + slot * TARGET_SIZE
    log(string.format("render target slot %d users %s pending free %s size %sx%s", slot, tostring(read("u32", s + 0x68)),
      tostring(read("u8", s + 0x6C)), tostring(read("u16", s + 0x3A)), tostring(read("u16", s + 0x3C))))
  end
end

local function report_camera(camera)
  local config = profile_address("Camera.GetConfig", 0x20)
  local entries, count = read("ptr", config and config + 0x48), read("u32", config and config + 0x50)
  if not entries or not count or count == 0 or count > MAX_CAMERAS then
    log("camera config: not reachable (Camera.GetConfig " .. tostring(config and hex(config) or "unresolved") .. ")")
    return
  end
  local ok, names = pcall(VRFW.mem.read_array, "u32", entries, count, CAMERA_SIZE)
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

-- the render settings object (the static the getter at Render.GetSettings returns: `lea rax` at +0x20)
local function render_settings()
  return profile_address("Render.GetSettings", 0x20)
end

local function report_pause()
  local system = profile_address("Render.GetSystem", 0x20)
  local view = read("ptr", system and system + 0x808)
  local settings = render_settings()
  log(string.format("pause: time scale %s, render settings +0xD7 %s +0xD8 %s +0xD9 %s (all of time scale <= 0, D7, D8 = the pause freeze: a CharaRenderProperty's +0x2AE goes 0)",
    tostring(read("f32", view and view + 0x734)), tostring(read("u8", settings and settings + 0xD7)),
    tostring(read("u8", settings and settings + FREEZE_FLAG)), tostring(read("u8", settings and settings + 0xD9))))
end

local function report_model(model)
  if type(model) ~= "number" or model == 0 then
    log("model: no handle")
    return
  end
  local ok, at = pcall(VRFW.game.sym, "Scene.GameState")
  local manager = ok and read("ptr", at)
  local records = manager and read("ptr", manager + 0x50)
  local index = model % 65536
  local record = records and index < 0x280 and records + index * RECORD_SIZE
  local handle = read("u32", record and record + RECORD_HANDLE)
  if handle ~= model then
    log(string.format("model %s: no scene chara record (found %s)", hex(model), hex(handle)))
    return
  end
  local p = read("ptr", record + RECORD_RENDER)
  log(string.format("model %s: record flags %s, CharaRenderProperty %s", hex(model),
    hex(read("u8", record + RECORD_FLAGS)), p and hex64(p) or "nil"))
  if not p or p == 0 then return end
  local b = function(o) return tostring(read("u8", p + o)) end
  log(string.format("render property: camera %s view %s handle %s capture +2AC %s last +2AD %s drawn +2AE %s cell on +2AF %s mask +2B0 %s slot +2B1 %s mask slot +2B2 %s viewport %s %s %s %s",
    hex(read("u32", p + 0x2A0)), tostring(read("u16", p + 0x2A4)), hex(read("u32", p + 0x2A8)), b(0x2AC), b(0x2AD), b(0x2AE),
    b(0x2AF), b(0x2B0), b(0x2B1), b(0x2B2), tostring(read("u32", p + 0x290)), tostring(read("u32", p + 0x294)),
    tostring(read("u32", p + 0x298)), tostring(read("u32", p + 0x29C))))
  local proxy = read("ptr", p + 0x2C0)
  if proxy and proxy ~= 0 then
    log(string.format("render proxy: slot +2A4 %s mode +2A6 %s +2B0 %s flags +2B1 %s", tostring(read("u8", proxy + 0x2A4)),
      tostring(read("u16", proxy + 0x2A6)), tostring(read("u8", proxy + 0x2B0)), hex(read("u8", proxy + 0x2B1))))
  else
    log("render proxy: none")
  end
end

function P.Live(on)
  local settings = render_settings()
  if not settings or not read("u8", settings + FREEZE_FLAG) then return -1 end
  if on == 1 then
    if saved_freeze == nil then
      saved_freeze = read("u8", settings + FREEZE_FLAG)
      log("pause freeze flag " .. tostring(saved_freeze) .. " -> 0 while the capture page shows")
    end
    if read("u8", settings + FREEZE_FLAG) ~= 0 then
      pcall(VRFW.mem.write, "u8", settings + FREEZE_FLAG, 0)
    end
    return 1
  end
  if saved_freeze == nil then return 0 end
  pcall(VRFW.mem.write, "u8", settings + FREEZE_FLAG, saved_freeze)
  log("pause freeze flag back to " .. tostring(saved_freeze))
  saved_freeze = nil
  return 1
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

log("player page capture commands ready (CMND_CHARACTERREFORGED_PAGE_CAPTURE_CONFIG / _REPORT / _LIVE / _DRAWN)")
