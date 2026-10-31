-- VRFW faces (docs/framework/chara-index.md §2): whether a character has a face icon of its own. The engine looks a
-- character's face up only by its internal name (chara_base `name`):
-- data/dx11/menu/200_icon/10_icon_chr/face/<name>_l.g4tx; when no game or mod file has it, every plate, pin and card
-- draws the default face (Mark Evans'). The one check for every script that leaves such players out (contact maps,
-- Career Mode). Each name is looked up once per script VM (VRFW.files.game_file).
local M = {}

local FACE_FILE = "data/dx11/menu/200_icon/10_icon_chr/face/%s_l.g4tx"
local HAS = {}         -- internal name -> true / false
local NAMES = {}       -- character id -> internal name, false when it has none

local function u32(n)
  n = math.floor(tonumber(n) or 0) % 4294967296
  if n < 0 then n = n + 4294967296 end
  return n
end

-- an internal name -> true = a face icon of its own, false = none (the default face), nil = cannot tell
function M.of_name(name)
  if type(name) ~= "string" or name == "" then return nil end
  local has = HAS[name]
  if has ~= nil then return has end
  if type(VRFW.files) ~= "table" or type(VRFW.files.game_file) ~= "function" then return nil end
  local ok, key, why = pcall(VRFW.files.game_file, string.format(FACE_FILE, name))
  if not ok or (key == nil and why == "no host") then return nil end
  has = key ~= nil
  HAS[name] = has
  return has
end

-- a character (chara_base id) -> as of_name of its internal name
function M.of_character(base)
  base = u32(base)
  local name = NAMES[base]
  if name == nil then
    local ok, ch = pcall(VRFW.chara.character, base)
    name = ok and type(ch) == "table" and type(ch.name) == "string" and ch.name ~= "" and ch.name or false
    NAMES[base] = name
  end
  if not name then return nil end
  return M.of_name(name)
end

-- a card (chara_param id) -> as of_character of its character
function M.of_card(card)
  local ok, base = pcall(VRFW.chara.base_of, u32(card))
  if not ok or type(base) ~= "number" then return nil end
  return M.of_character(base)
end

return M
