-- Menu icons by meaning: a series' icon and a staff role's icon as a texture sheet + sprite pair (content/defaults/menu_icons.toml, every mod's, load order).
-- A menu script draws the pair on any quad with the sprite command 558735651(layer, sheet, sprite, texture node, 0, instance).
--   CMND_VRFW_SERIES_ICON(series name, alias or number) -> ok, sheet hash, sprite hash
--   CMND_VRFW_ROLE_ICON(role "manager" / "coach") -> ok, sheet hash, sprite hash

MenuIcons = MenuIcons or {}

require "VRFW/lib/basics"
local _, warn = VRFW.logger("menu_icons")

local Id = require "lib/ids"
local u32 = Id.u32
local crc = VRFW.crc32

local SERIES = { sheet = nil, sprite = nil, by_series = {} }   -- by_series: [series number] = { sheet, sprite } (names resolved on use)
local BY_NAME = {}                                              -- series name / alias -> { sheet, sprite }
local ROLES = { sheet = nil }                                   -- sheet + [role] = sprite name

local function read()
  local ok, files = pcall(VRFW.files.declarations, { "content/defaults/menu_icons.toml" })
  if not ok or type(files) ~= "table" then
    warn("menu_icons.toml not read (" .. tostring(files) .. "): no series / role icons")
    return
  end
  -- the framework's file first, then the mods' in load order (a later key wins)
  local ordered = {}
  for _, f in ipairs(files) do if f.mod == VRFW.mod then ordered[#ordered + 1] = f end end
  for _, f in ipairs(files) do if f.mod ~= VRFW.mod then ordered[#ordered + 1] = f end end
  for _, f in ipairs(ordered) do
    local d = type(f.data) == "table" and f.data or {}
    local s = d.series_icons
    if type(s) == "table" then
      if type(s.sheet) == "string" then SERIES.sheet = s.sheet end
      if type(s.sprite) == "string" then SERIES.sprite = s.sprite end
      if type(s.by_series) == "table" then
        for name, one in pairs(s.by_series) do
          if type(one) == "table" and type(one.sheet) == "string" and type(one.sprite) == "string" then
            BY_NAME[tostring(name)] = { sheet = one.sheet, sprite = one.sprite }
          else
            warn(string.format("mods/%s: series_icons.by_series.%s needs sheet and sprite (text)", tostring(f.mod), tostring(name)))
          end
        end
      end
    end
    local r = d.role_icons
    if type(r) == "table" then
      for k, v in pairs(r) do
        if type(v) == "string" then ROLES[k] = v end
      end
    end
  end
end

read()

-- a series name / alias / number -> its number, nil when unknown
local function series_number(v)
  if type(v) == "number" then return math.floor(v) end
  local n = tonumber(v)
  if n then return math.floor(n) end
  local ok, t = pcall(VRFW.chara.series_of, v)
  if ok and type(t) == "number" then return math.floor(t) end
  return nil
end

local CACHE = {}         -- series number -> { sheet hash, sprite hash } | false

local function series_icon(v)
  local t = series_number(v)
  if not t or t < 1 then return nil end
  local c = CACHE[t]
  if c ~= nil then return c or nil end
  -- an icon declared by name for this series (any of its names)
  for name, one in pairs(BY_NAME) do
    if series_number(name) == t then
      c = { crc(one.sheet), crc(one.sprite) }
      break
    end
  end
  if not c and SERIES.sheet and SERIES.sprite then
    local okn, names = pcall(VRFW.chara.series_names)
    -- the sheet's numbered icons cover the game's series only (the index names them)
    if okn and type(names) == "table" and names[t] ~= nil then
      local sprite = SERIES.sprite:gsub("{type}", function() return string.format("%02d", t) end)
      c = { crc(SERIES.sheet), crc(sprite) }
    end
  end
  CACHE[t] = c or false
  return c
end

function MenuIcons.CmdSeries(v)
  local c = series_icon(v)
  if not c then return false, 0, 0 end
  return true, c[1], c[2]
end

function MenuIcons.CmdRole(role)
  local sprite = type(role) == "string" and role ~= "sheet" and ROLES[role] or nil
  if not sprite or not ROLES.sheet then return false, 0, 0 end
  return true, crc(ROLES.sheet), crc(sprite)
end
