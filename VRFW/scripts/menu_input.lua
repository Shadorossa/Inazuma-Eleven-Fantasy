-- Menu input diagnostics. MenuInput.Dump answers the menu controller's input list as text for the input trace:
--   «<crc hex> p<priority> o<order> alive|gone act<byte> [top]; ...»  (top = gets the pad; act is for reference only)

MenuInput = MenuInput or {}

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

function MenuInput.Dump()
  local ok, ctrl = pcall(VRFW.game.menu_controller)
  if not ok or type(ctrl) ~= "number" or ctrl == 0 then
    return "no menu controller"
  end
  local mgr = ctrl + 0x50
  local pool = rd("ptr", mgr + 0x10) or rd("u64", mgr + 0x10)
  local off, head, last = rd("u32", mgr + 0x24), rd("u16", mgr + 0x18), rd("u16", mgr + 0x2C)
  if pool == nil or off == nil or head == nil or last == nil then
    return "input list not readable"
  end
  local rows, top = {}, 0
  local idx, guard = head, 0
  while idx < last and guard < 64 do
    guard = guard + 1
    local e = pool + idx * 0xC
    local crc, prio, order = rd("u32", e) or 0, rd("u16", e + 4) or 0, rd("u16", e + 6) or 0
    local okf, menu = pcall(VRFW.call, "MenuFind", crc)
    local alive = okf and type(menu) == "number" and menu ~= 0
    rows[#rows + 1] = {crc = crc, prio = prio, order = order, alive = alive, act = alive and rd("u8", menu + 0x17C) or nil}
    if prio > top then top = prio end
    local nx = rd("u16", pool + off + idx * 6 + 2)
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

-- The global menu input controller: the selected controller is the only one delivering commands; its byte +0x29 is the global input switch.
MenuInput.CTRL_NAMES = {[0x4F6EB0DF] = "MENU_CTRL", [0xA3D94C5C] = "MENU_CTRL_WITH_ANALOG_MOVE_FOCUS",
  [0xD2365D36] = "MENU_CTRL_SEPARATE_CROSS_KEY", [0x3752594D] = "MENU_CTRL_SETPLAY", [0x01490CDA] = "LUA_CTRL",
  [0x1D917FB1] = "RPG_AREA_MAP_INPUT_CTRL", [0xC0FB3C71] = "EVENT_CTRL_TALK"}

local function current_ctrl()
  local ok, ctrl = pcall(VRFW.game.menu_controller)
  if not ok or type(ctrl) ~= "number" or ctrl == 0 then
    return nil
  end
  local list, n, cur = rd("ptr", ctrl + 0xA8), rd("u32", ctrl + 0xB0), rd("ptr", ctrl + 0xB8)
  if cur == nil or cur == 0 then
    return nil
  end
  local name = 0
  if list ~= nil and n ~= nil then
    for i = 0, math.min(n, 64) - 1 do
      if rd("ptr", list + i * 16) == cur then
        name = rd("u32", list + i * 16 + 8) or 0
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
  return "ctrl " .. label .. " on" .. tostring(rd("u8", cur + 0x29))
end

-- CMND_VRFW_MENU_INPUT_CTRL_ON() -> previous switch byte (switches the selected controller's input on)
function MenuInput.CtrlOn()
  local cur = current_ctrl()
  if cur == nil then
    return -1
  end
  local was = rd("u8", cur + 0x29)
  if was == 0 then
    pcall(VRFW.mem.write, "u8", cur + 0x29, 1)
  end
  return was or -1
end
