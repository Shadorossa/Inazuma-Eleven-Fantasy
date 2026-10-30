-- Menu input diagnostics. MenuInput.Dump answers the menu controller's input list as text for the input trace:
--   «<crc hex> p<priority> o<order> alive|gone act<byte> [top]; ...»  (top = gets the pad; act is for reference only)

MenuInput = MenuInput or {}

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

-- the layout of the menu controller's records, from the game profile (research/mods/VRFW/game/<build>/structs.toml)
local LAYOUT = nil
local LAYOUT_NAMES = {
  pool = "MenuController.InputPool", head = "MenuController.InputHead", links = "MenuController.InputLinks",
  last = "MenuController.InputEnd", list = "MenuController.Controllers", count = "MenuController.ControllerCount",
  current = "MenuController.CurrentController",
  entry = "MenuInputEntry", entry_menu = "MenuInputEntry.Menu", entry_priority = "MenuInputEntry.Priority",
  entry_order = "MenuInputEntry.Order", link = "MenuInputLink", link_next = "MenuInputLink.Next",
  slot = "MenuControllerSlot", slot_controller = "MenuControllerSlot.Controller", slot_name = "MenuControllerSlot.Name",
  enabled = "InputController.Enabled", active = "MenuObject.Active",
}

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

function MenuInput.Dump()
  local ok, ctrl = pcall(VRFW.game.menu_controller)
  if not ok or type(ctrl) ~= "number" or ctrl == 0 then
    return "no menu controller"
  end
  local L = layout()
  if L == nil then
    return "no menu controller layout in the game profile"
  end
  local pool = rd("ptr", ctrl + L.pool) or rd("u64", ctrl + L.pool)
  local off, head, last = rd("u32", ctrl + L.links), rd("u16", ctrl + L.head), rd("u16", ctrl + L.last)
  if pool == nil or off == nil or head == nil or last == nil then
    return "input list not readable"
  end
  local rows, top = {}, 0
  local idx, guard = head, 0
  while idx < last and guard < 64 do
    guard = guard + 1
    local e = pool + idx * L.entry
    local crc = rd("u32", e + L.entry_menu) or 0
    local prio, order = rd("u16", e + L.entry_priority) or 0, rd("u16", e + L.entry_order) or 0
    local okf, menu = pcall(VRFW.call, "MenuFind", crc)
    local alive = okf and type(menu) == "number" and menu ~= 0
    rows[#rows + 1] = {crc = crc, prio = prio, order = order, alive = alive, act = alive and rd("u8", menu + L.active) or nil}
    if prio > top then top = prio end
    local nx = rd("u16", pool + off + idx * L.link + L.link_next)
    if nx == nil then break end
    idx = nx
  end
  local out = {}
  for _, r in ipairs(rows) do
    out[#out + 1] = string.format("%08X p%d o%d %s act%s%s", r.crc, r.prio, r.order, r.alive and "alive" or "gone",
      tostring(r.act), r.prio == top and " top" or "")
  end
  return (#out > 0 and table.concat(out, "; ") or "empty") .. " | " .. MenuInput.Ctrl()
end

-- The global menu input controller: the selected controller is the only one delivering commands; its byte
-- InputController.Enabled is the global input switch.
MenuInput.CTRL_NAMES = {[0x4F6EB0DF] = "MENU_CTRL", [0xA3D94C5C] = "MENU_CTRL_WITH_ANALOG_MOVE_FOCUS",
  [0xD2365D36] = "MENU_CTRL_SEPARATE_CROSS_KEY", [0x3752594D] = "MENU_CTRL_SETPLAY", [0x01490CDA] = "LUA_CTRL",
  [0x1D917FB1] = "RPG_AREA_MAP_INPUT_CTRL", [0xC0FB3C71] = "EVENT_CTRL_TALK"}

local function current_ctrl()
  local ok, ctrl = pcall(VRFW.game.menu_controller)
  if not ok or type(ctrl) ~= "number" or ctrl == 0 then
    return nil
  end
  local L = layout()
  if L == nil then
    return nil
  end
  local list, n, cur = rd("ptr", ctrl + L.list), rd("u32", ctrl + L.count), rd("ptr", ctrl + L.current)
  if cur == nil or cur == 0 then
    return nil
  end
  local name = 0
  if list ~= nil and n ~= nil then
    for i = 0, math.min(n, 64) - 1 do
      local slot = list + i * L.slot
      if rd("ptr", slot + L.slot_controller) == cur then
        name = rd("u32", slot + L.slot_name) or 0
        break
      end
    end
  end
  return cur, name
end

-- CMND_VRFW_MENU_INPUT_CTRL() -> "ctrl <name> on<0|1>"
function MenuInput.Ctrl()
  local cur, name = current_ctrl()
  if cur == nil then
    return "ctrl none"
  end
  local label = MenuInput.CTRL_NAMES[name] or string.format("%08X", name)
  return "ctrl " .. label .. " on" .. tostring(rd("u8", cur + layout().enabled))
end

-- CMND_VRFW_MENU_INPUT_CTRL_ON() -> previous switch byte (switches the selected controller's input on)
function MenuInput.CtrlOn()
  local cur = current_ctrl()
  if cur == nil then
    return -1
  end
  local enabled = cur + layout().enabled
  local was = rd("u8", enabled)
  if was == 0 then
    pcall(VRFW.mem.write, "u8", enabled, 1)
  end
  return was or -1
end
