-- VR-Framework › input actions (docs/framework/types/input.md §2b). The mods declare rebindable actions in their
-- input files (`[[action]]`: id, command, ctrl, category, label, pad, keyboard); the type `input` adds the commands
-- (listed in the key configuration) and mod_options their row in the game's «Configuración de controles». The game
-- keeps the player's own binding (its system save) and answers the command with it (CMND_CHECK_INPUT_CMD, the markup
-- <CMD_…>). This script answers the declaration itself for the menus' Lua (CMND_VRFW_INPUT_ACTION):
--   { declared = 1, id, command = crc32(command), ctrl, category, pad = <pad index>, key = <keyboard index>,
--     pad_mask = 1 << pad (vr_sigs::input::mask), vk = <Windows virtual key of a letter key, 0 = none> }
-- or { declared = 0 } when no mod declares it. pad_mask / vk are the DEFAULT binding: a menu that reads the devices
-- straight (a `standalone` top bar host, where MENU_CTRL answers nothing) uses them; a rebinding made in the game's
-- screen reaches the command, not these values.

InputActions = InputActions or {}

local PAD = { SELECT = 0, BACK = 0, VIEW = 0, LS = 1, L3 = 1, RS = 2, R3 = 2, START = 3, MENU = 3, UP = 4, RIGHT = 5,
  DOWN = 6, LEFT = 7, LT = 8, L2 = 8, ZL = 8, RT = 9, R2 = 9, ZR = 9, LB = 10, L1 = 10, L = 10, RB = 11, R1 = 11, R = 11,
  Y = 12, TRIANGLE = 12, B = 13, CIRCLE = 13, A = 14, CROSS = 14, X = 15, SQUARE = 15 }

local cache = nil

local function pad_index(v)
  if type(v) == "number" then
    return (v >= 0 and v <= 15) and math.floor(v) or nil
  end
  if type(v) == "string" then
    return PAD[string.upper(v)]
  end
  return nil
end

local function key_index(v)
  if type(v) == "number" then
    return (v >= 0 and v <= 255) and math.floor(v) or nil
  end
  if type(v) == "string" and string.match(v, "^%a$") then
    return string.byte(string.upper(v)) - string.byte("A")
  end
  return nil
end

local function load_all()
  if cache ~= nil then
    return cache
  end
  cache = { by_id = {}, by_command = {} }
  local ok, list = pcall(VRFW.files.declarations, { "input.toml", "input", "inputs", "content/inputs", "features/*/content/inputs" })
  if not ok or type(list) ~= "table" then
    VRFW.warn("input actions: the mods' input files could not be read: " .. tostring(list))
    return cache
  end
  for _, f in ipairs(list) do
    local acts = type(f.data) == "table" and f.data.action or nil
    for _, a in ipairs(type(acts) == "table" and acts or {}) do
      if type(a.id) == "string" and type(a.command) == "string" then
        local pad, key = pad_index(a.pad), key_index(a.keyboard)
        local e = {
          declared = 1, id = a.id, command = VRFW.ui.crc32(a.command), name = a.command,
          ctrl = type(a.ctrl) == "string" and a.ctrl or "MENU_CTRL", category = tostring(a.category or ""),
          pad = pad or -1, key = key or -1,
          pad_mask = pad and math.floor(2 ^ pad) or 0,
          vk = (key ~= nil and key <= 25) and (string.byte("A") + key) or 0,
          mod = f.mod,
        }
        -- the last mod in load order wins (its declaration is the one the input type adds last)
        cache.by_id[a.id] = e
        cache.by_command[a.command] = e
      end
    end
  end
  return cache
end

-- an action by its id or its command name; nil = none declared
function InputActions.Binding(name)
  local c = load_all()
  if type(name) ~= "string" then
    return nil
  end
  return c.by_id[name] or c.by_command[name]
end

-- CMND_VRFW_INPUT_ACTION(name)
function InputActions.Get(name)
  local e = InputActions.Binding(name)
  if e == nil then
    return { declared = 0 }
  end
  return { declared = 1, id = e.id, command = e.command, ctrl = e.ctrl, category = e.category, pad = e.pad,
    key = e.key, pad_mask = e.pad_mask, vk = e.vk }
end
