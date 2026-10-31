-- Model cards, script side (game Lua side: assets\lua\menu\_all\91_model_card.lua `VRFW_ModelCard`;
-- docs/framework/model-card.md). One player's 3D model posed inside a box of a menu screen; this file picks the clip
-- the player's motion set holds and loads extra motion packs onto the built model.
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_MODEL_CARD_CLIP | motion set (c000101 …), clips "pack:clip|pack:clip|…" | { clip = crc32 of the clip name, name, pack = game path of its pack, attach = the pack must be loaded onto the model first, camera = content\defaults\model_card.toml [camera], fit = its [fit] } |
-- | CMND_VRFW_MODEL_CARD_PACK | model handle, pack path | true, or false + why: the pack loaded onto the model |
-- A clip counts as held when its pack file of that motion set exists and names the clip. The list always ends with the
-- stand clip of [clips] stand (the base pack's), so a player never gets a clip his model cannot play.

ModelCard = ModelCard or {}

require "VRFW/lib/basics"
local info, warn = VRFW.logger("model_card")

local crc = VRFW.crc32

local DEFAULTS = nil
local function defaults()
  if DEFAULTS == nil then
    local ok, t = pcall(VRFW.files.toml, "content/defaults/model_card.toml")
    DEFAULTS = ok and type(t) == "table" and t or {}
    if not (ok and type(t) == "table") then warn("content/defaults/model_card.toml not read: built-in defaults") end
  end
  return DEFAULTS
end

local function clips_config()
  local c = defaults().clips or {}
  return {
    base_pack = tostring(c.base_pack or "p010"),
    stand = tostring(c.stand or "p010:立ち1L"),
  }
end

-- pack path -> { [clip name] = true | false } (what was looked up), or false when the file is missing
local HELD = {}

local function pack_path(set, pack)
  return string.format("common/chr/%s/%s_%s.g4pk", set, set, pack)
end

local function held(path, name)
  local entry = HELD[path]
  if entry == false then return false end
  if entry == nil then
    entry = { bytes = nil, names = {} }
    local ok, bytes, why = pcall(VRFW.files.game_read, path)
    if not ok or type(bytes) ~= "string" then
      HELD[path] = false
      info(string.format("%s: not in the game (%s)", path, tostring(ok and why or bytes)))
      return false
    end
    entry.bytes = bytes
    HELD[path] = entry
  end
  local v = entry.names[name]
  if v == nil then
    v = string.find(entry.bytes, "\0" .. name .. "\0", 1, true) ~= nil   -- the pack's name table: one name between zeros
    entry.names[name] = v
  end
  return v
end

local function split(text)
  local out = {}
  for item in string.gmatch(tostring(text or ""), "[^|]+") do
    local pack, name = string.match(item, "^%s*([%w_]+)%s*:%s*(.-)%s*$")
    if pack and name and name ~= "" then out[#out + 1] = { pack = pack, name = name } end
  end
  return out
end

local LOGGED = {}

-- (motion set, clips) -> the first clip the set holds
function ModelCard.Clip(set, clips)
  set = tostring(set or "")
  local cfg = clips_config()
  local list = split(clips)
  for _, s in ipairs(split(cfg.stand)) do list[#list + 1] = s end
  local camera = defaults().camera or {}
  local fit = defaults().fit or {}
  if set:match("^[%w_]+$") then
    for _, c in ipairs(list) do
      local path = pack_path(set, c.pack)
      if held(path, c.name) then
        local key = set .. "|" .. tostring(clips)
        if not LOGGED[key] then
          LOGGED[key] = true
          info(string.format("set %s: clip %s from %s", set, c.name, path))
        end
        return { clip = crc(c.name), name = c.name, pack = path, attach = c.pack ~= cfg.base_pack, camera = camera, fit = fit }
      end
    end
  end
  -- no motion set or none held: the stand clip of the base pack (the clip every menu model plays)
  local stand = split(cfg.stand)[1] or { pack = cfg.base_pack, name = "立ち1L" }
  if not LOGGED[set] then
    LOGGED[set] = true
    info(string.format("set %s: no listed clip held, the stand %s", set ~= "" and set or "(none)", stand.name))
  end
  return { clip = crc(stand.name), name = stand.name, pack = "", attach = false, camera = camera, fit = fit }
end

-- (model handle, pack path) -> true | false, why
function ModelCard.Pack(handle, path)
  local api = VRFW.map_npcs
  if not api or not api.attach_motion_pack then return false, "no VRFW.map_npcs.attach_motion_pack" end
  path = tostring(path or "")
  local ok, done, why = pcall(api.attach_motion_pack, tonumber(handle) or 0, path)
  if not ok or done == nil then
    local text = tostring(ok and why or done)
    warn(string.format("model 0x%08X: %s not loaded (%s)", (tonumber(handle) or 0) % 4294967296, path, text))
    return false, text
  end
  return done == true, done == true and "" or "the engine refused the pack"
end
