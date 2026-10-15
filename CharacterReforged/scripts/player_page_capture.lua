-- Character Reforged › the player page's 3D model in a match (graft plate_model, capture layer evt_pp_model_cap).
-- Declarations: content\game\player_page_capture.toml; engine side: docs/game/engine/menu-chara-capture.md.
--
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_CONFIG()  -> mode, camera, report, bust
--        mode 0 off / 1 in a match / 2 every screen; camera = the capture camera's name crc; report 1 = log the
--        report after each build; bust 1 = the bust camera (the model is placed at the origin for it)
--   CMND_CHARACTERREFORGED_PAGE_CAPTURE_REPORT(when, key, camera)  -> 1
--        loader.log: the menu capture render-texture pool (types 2 / 3: every cell, «ours» = the model key), the
--        render targets of slots 2 / 3 and whether the camera is in the external camera config

CharacterReforged = CharacterReforged or {}
CharacterReforged.PageCapture = CharacterReforged.PageCapture or {}
local P = CharacterReforged.PageCapture

local MODES = {off = 0, match = 1, always = 2}
local CAMERAS = {vs = 0xB7EE99E6, bust = 0x059B5FFD}   -- VS screen full body (512 x 512, FOV 20); keeper gauge bust
local POOL_TYPES = {2, 3}
local ENTRY_SIZE, TARGET_SIZE, CAMERA_SIZE = 0x38, 0x70, 0x5C
local MAX_ENTRIES, MAX_CAMERAS = 64, 4096

local function log(...) VRFW.log("player_page_capture:", ...) end

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

function P.Config()
  local mode = MODES[setting("player_page.match_model", "match")] or MODES.match
  local camera_name = setting("player_page.match_camera", "vs")
  local camera = CAMERAS[camera_name] or (type(camera_name) == "number" and camera_name) or CAMERAS.vs
  local report = setting("player_page.capture_report", true) == true and 1 or 0
  return mode, camera, report, camera == CAMERAS.bust and 1 or 0
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
        log(string.format("cell %d handle %s type %d key %s%s cell %s live %s shown %s freeing %s users %s texture %s scale %s",
          i, hex(handle), t, hex(k), mine and " (ours)" or "", tostring(read("u8", e + 0x30)), tostring(read("u8", e + 0x31)),
          tostring(read("u8", e + 0x32)), tostring(read("u8", e + 0x33)), tostring(read("u32", e + 0x2C)),
          (read("ptr", e) or 0) ~= 0 and "yes" or "no", tostring(read("f32", e + 0x28))))
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

function P.Report(when, key, camera)
  local ok, err = pcall(function()
    key = type(key) == "number" and key % 4294967296 or 0
    camera = type(camera) == "number" and camera % 4294967296 or CAMERAS.vs
    log("report " .. tostring(when) .. " (model key " .. hex(key) .. ")")
    report_pool(key)
    report_targets()
    report_camera(camera)
  end)
  if not ok then log("report failed: " .. tostring(err)) end
  return 1
end

log("player page capture commands ready (CMND_CHARACTERREFORGED_PAGE_CAPTURE_CONFIG / _REPORT)")
