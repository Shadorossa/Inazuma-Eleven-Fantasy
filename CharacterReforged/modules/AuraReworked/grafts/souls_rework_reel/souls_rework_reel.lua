-- ===== SoulsRework reel BEGIN =====
-- Souls Rework's skill reel (match HUD; docs/game/mods/souls-rework-design.md §5). When the user's totem uses its own
-- move, the module's script rolls one of the totem's 6 skills and queues it; this block asks for it
-- (CMND_AURAREWORKED_SOULS_REEL(seen) -> seq, title, level, slot, 6 labels, miss mask, timing) and plays a slot-machine reel
-- under the scoreboard: open, spin (the rows run downwards, Galaxy's order), ease-out stop exactly on the rolled slot,
-- the selected row's plate flashes (not for a miss), close. No input. Layer souls_rework_reel_row (the module's
-- content\menus\reel.toml): instance 0 = the totem's name and level, 1..3 = the rows (2 = the selected one, on its plate).
-- Placement: from the scoreboard's clock base (_base_game_time01) global position, REEL_* offsets in global units (menu
-- space, y up); the layer position -> text node global position offset is measured once per HUD (as BetterUI's duel
-- readout does), so no screen origin is assumed. Wrappers only (OnInit, OnOpenLayer, Step); no engine call at chunk load.

local REEL_CMD = @crc:CMND_AURAREWORKED_SOULS_REEL@
local REEL_LOG = 3661580131                        -- CMND_EVT_LOG
local REEL_FRAME_SECONDS = 1549797111              -- seconds since the last frame
local REEL_LAYER = @crc:souls_rework_reel_row@
local REEL_SCOREBOARDS = {@crc:soccer00_01_scoreboard@, @crc:soccer00_01b_scoreboard_battle@}
local REEL_ANCHOR_MESH = @crc:_base_game_time01@
local REEL_CMDS = {
  OPEN_ARRAY = 2152386330, CLOSE = 1273612389, IS_OPEN = 2640875187, IS_LOADING = 3057768039,
  MESH_VISIBLE = 3405944500, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801, TEXT = 1083631230,
  GLOBAL_POS = 499270986,
}
local REEL_TEXT_NODE = 378327766                   -- _text_cmd_back01
local REEL_PLATE_MESHES = {298211823 --[[_cmd_back_base01]], 2853207670 --[[_cmd_back_base01_add]]}

-- layout, global units from the clock base's position (y up); below «Modo Comandante» and its stack (hud_layout)
local REEL_DX = 0                                  -- the reel's centre line from REEL_CENTER_X (or the clock base's x)
local REEL_CENTER_X = 960                          -- the screen's centre in menu space (x 0..1920); nil = the clock base's x
local REEL_TITLE_DY = -175                         -- the title's text from the clock base
local REEL_ROW_DY = -235                           -- the selected row's text from the clock base
local REEL_ROW_H = 46                              -- between two rows
local REEL_DROP = 12                               -- the reel drops in this much while it opens
local REEL_SIDE_SCALE = 0.8                        -- the rows above and below the selected one
local REEL_FLASH_S = 0.15                          -- the selected row's plate blinks this often while the result shows
local REEL_PROBE_STEP = 100
local REEL_PROBE_WAIT = 2

local reel = {state = "idle", seen = 0, roll = nil, t = 0, pos = 0, probe = nil, scale = nil, anchor = nil, logs = 0}

local function ReelMenu(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function ReelCommand(...)
  if type(funcLuaCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function ReelLog(...)
  if reel.logs >= 30 then
    return
  end
  reel.logs = reel.logs + 1
  ReelCommand(REEL_LOG, "SOULSREWORK_REEL", ...)
end

local function ReelGlobal(layer, index, node)
  local x, y = ReelMenu(REEL_CMDS.GLOBAL_POS, layer, index, node)
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  return x, y
end

-- the clock base of whichever scoreboard this HUD has
local function ReelAnchor()
  for _, layer in ipairs(REEL_SCOREBOARDS) do
    local x, y = ReelGlobal(layer, 0, REEL_ANCHOR_MESH)
    if x ~= nil then
      return {x = x, y = y}
    end
  end
  return nil
end

-- layer position -> text node global position (global = position * scale + origin), measured with instance 0 hidden
local function ReelProbe()
  if reel.scale ~= nil then
    return reel.scale ~= false
  end
  local p = reel.probe
  if p == nil then
    reel.probe = {step = 0, wait = REEL_PROBE_WAIT}
    ReelMenu(REEL_CMDS.POS, REEL_LAYER, 0, 0, 0, 0)
    return false
  end
  if p.wait > 0 then
    p.wait = p.wait - 1
    return false
  end
  local x, y = ReelGlobal(REEL_LAYER, 0, REEL_TEXT_NODE)
  if x == nil then
    reel.scale = false
    ReelLog("no global position for the row's text node: reel off")
    return false
  end
  if p.step == 0 then
    p.x0, p.y0, p.step, p.wait = x, y, 1, REEL_PROBE_WAIT
    ReelMenu(REEL_CMDS.POS, REEL_LAYER, REEL_PROBE_STEP, REEL_PROBE_STEP, 0, 0)
    return false
  end
  local sx, sy = (x - p.x0) / REEL_PROBE_STEP, (y - p.y0) / REEL_PROBE_STEP
  if math.abs(sx) < 0.1 or math.abs(sy) < 0.1 then
    reel.scale = false
    ReelLog("the row's position does not move its text node: reel off")
    return false
  end
  reel.scale = {x = sx, y = sy, ox = p.x0, oy = p.y0}
  return true
end

-- instance i's text node at global (gx, gy)
local function ReelPlace(i, gx, gy, scale)
  local k = reel.scale
  ReelMenu(REEL_CMDS.POS, REEL_LAYER, (gx - k.ox) / k.x, (gy - k.oy) / k.y, 0, i)
  ReelMenu(REEL_CMDS.SCALE, REEL_LAYER, scale, scale, 1, i)
end

local function ReelPlates(i, on)
  for _, mesh in ipairs(REEL_PLATE_MESHES) do
    ReelMenu(REEL_CMDS.MESH_VISIBLE, REEL_LAYER, mesh, on, i)
  end
end

local function ReelHideAll()
  for i = 0, 3 do
    ReelMenu(REEL_CMDS.VISIBLE, REEL_LAYER, i, false)
  end
end

local function ReelClose()
  ReelHideAll()
  ReelMenu(REEL_CMDS.CLOSE, REEL_LAYER)
  reel.state = "idle"
  reel.roll = nil
end

-- the reel's position: row k (0-based) of the 6 sits on the selected line at pos = k; the rows run downwards, so the
-- row above the selected one is the next slot
local function ReelLabel(pos)
  local labels = reel.roll.labels
  local n = #labels
  local k = math.floor(pos) % n
  return labels[k + 1]
end

local function ReelDraw(drop, flash_on)
  local a = reel.anchor
  local cx = (a.cx or a.x) + REEL_DX
  local base = math.floor(reel.pos)
  local frac = reel.pos - base
  ReelPlace(0, cx, a.y + REEL_TITLE_DY + drop, 1)
  for r = 1, 3 do
    -- r = 1 above the selected line (next slot), 2 the selected line, 3 below (previous slot)
    local slot = base + (2 - r)
    local y = a.y + REEL_ROW_DY + (2 - r) * REEL_ROW_H - frac * REEL_ROW_H + drop
    ReelMenu(REEL_CMDS.TEXT, REEL_LAYER, REEL_TEXT_NODE, ReelLabel(slot), r)
    ReelPlace(r, cx, y, r == 2 and 1 or REEL_SIDE_SCALE)
  end
  ReelPlates(2, flash_on)
end

local function ReelStart(roll)
  reel.roll = roll
  reel.state = "opening"
  reel.t = 0
  reel.pos = (roll.slot - 1 + 3) % #roll.labels
  if ReelMenu(REEL_CMDS.IS_OPEN, REEL_LAYER) ~= true then
    ReelMenu(REEL_CMDS.OPEN_ARRAY, REEL_LAYER)
  end
  ReelLog("roll", roll.seq, roll.title, roll.level, "slot", roll.slot)
end

local function ReelPoll()
  local r = table.pack(ReelCommand(REEL_CMD, reel.seen))
  local seq = r[1]
  if type(seq) ~= "number" or seq <= reel.seen then
    return
  end
  reel.seen = seq
  local labels = {}
  for i = 1, 6 do
    labels[i] = tostring(r[4 + i] or "")
  end
  ReelStart({seq = seq, title = tostring(r[2] or ""), level = tostring(r[3] or ""), slot = tonumber(r[4]) or 1,
    labels = labels, miss = tonumber(r[11]) or 0, open = tonumber(r[12]) or 0.2, spin = tonumber(r[13]) or 0.8,
    stop = tonumber(r[14]) or 0.9, result = tonumber(r[15]) or 1.2, close = tonumber(r[16]) or 0.3,
    rows = tonumber(r[17]) or 12})
end

-- the slot the reel ends on is (roll.slot - 1); the stop eases out from the spin's speed onto the first such row ahead
local function ReelStopTarget(from, speed, seconds, slot, n)
  local reach = from + speed * seconds / 3
  local target = math.ceil(reach)
  while target % n ~= slot - 1 do
    target = target + 1
  end
  return target
end

function SoulsReworkReel_Step()
  if reel.state == "idle" then
    ReelPoll()
    return
  end
  local dt = ReelCommand(REEL_FRAME_SECONDS)
  if type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
    dt = 1 / 60
  end
  local roll = reel.roll
  if reel.state == "opening" then
    reel.t = reel.t + dt
    local ready = ReelMenu(REEL_CMDS.IS_OPEN, REEL_LAYER) == true and ReelMenu(REEL_CMDS.IS_LOADING, REEL_LAYER) ~= true
    if not ready then
      if reel.t > 2 then
        ReelLog("the reel layer did not open: skipped")
        ReelClose()
      end
      return
    end
    if not ReelProbe() then
      if reel.scale == false then
        ReelClose()
      end
      return
    end
    reel.anchor = ReelAnchor()
    if reel.anchor == nil then
      ReelLog("no scoreboard position: skipped")
      ReelClose()
      return
    end
    -- top centre: the screen's centre x when the clock base reads in menu space (0..1920), else the clock base's x
    if REEL_CENTER_X ~= nil and reel.anchor.x >= 0 and reel.anchor.x <= 1920 then
      reel.anchor.cx = REEL_CENTER_X
    end
    ReelLog("anchor", string.format("%.1f %.1f", reel.anchor.x, reel.anchor.y), "centre x", string.format("%.1f", reel.anchor.cx or reel.anchor.x),
      "probe", string.format("%.3f %.3f %.1f %.1f", reel.scale.x, reel.scale.y, reel.scale.ox, reel.scale.oy))
    ReelMenu(REEL_CMDS.TEXT, REEL_LAYER, REEL_TEXT_NODE, roll.title .. "  " .. roll.level, 0)
    for i = 0, 3 do
      ReelPlates(i, i == 0 or i == 2)
      ReelMenu(REEL_CMDS.VISIBLE, REEL_LAYER, i, true)
    end
    reel.state = "open"
    reel.t = 0
  end
  reel.t = reel.t + dt
  local n = #roll.labels
  local drop, flash = 0, true
  if reel.state == "open" then
    drop = REEL_DROP * math.max(0, 1 - reel.t / math.max(roll.open, 0.01))
    if reel.t >= roll.open then
      reel.state, reel.t = "spin", 0
    end
  elseif reel.state == "spin" then
    reel.pos = reel.pos + roll.rows * dt
    if reel.t >= roll.spin then
      reel.state, reel.t = "stop", 0
      reel.from = reel.pos
      reel.target = ReelStopTarget(reel.pos, roll.rows, roll.stop, roll.slot, n)
    end
  elseif reel.state == "stop" then
    local u = math.min(1, reel.t / math.max(roll.stop, 0.01))
    reel.pos = reel.from + (reel.target - reel.from) * (1 - (1 - u) ^ 3)
    if u >= 1 then
      reel.pos = reel.target
      reel.state, reel.t = "result", 0
    end
  elseif reel.state == "result" then
    local miss = math.floor(roll.miss / 2 ^ (roll.slot - 1)) % 2 == 1
    flash = miss or math.floor(reel.t / REEL_FLASH_S) % 2 == 0
    if reel.t >= roll.result then
      reel.state, reel.t = "closing", 0
    end
  elseif reel.state == "closing" then
    drop = REEL_DROP * math.min(1, reel.t / math.max(roll.close, 0.01))
    if reel.t >= roll.close then
      ReelClose()
      return
    end
  end
  ReelDraw(drop, flash)
end

local SoulsReworkReel_previousOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2, ...)
  local r = {n = 0}
  if type(SoulsReworkReel_previousOpenLayer) == "function" then
    r = table.pack(SoulsReworkReel_previousOpenLayer(a1, a2, ...))
  end
  if a1 == REEL_LAYER then
    pcall(ReelMenu, REEL_CMDS.VISIBLE, REEL_LAYER, a2 or 0, false)
  end
  return table.unpack(r, 1, r.n)
end

local SoulsReworkReel_previousInit = OnInit
function OnInit(...)
  local r = {n = 0}
  if type(SoulsReworkReel_previousInit) == "function" then
    r = table.pack(SoulsReworkReel_previousInit(...))
  end
  reel = {state = "idle", seen = reel.seen, roll = nil, t = 0, pos = 0, probe = nil, scale = nil, anchor = nil, logs = reel.logs}
  return table.unpack(r, 1, r.n)
end

local SoulsReworkReel_previousStep = Step
function Step(...)
  local r = {n = 0}
  if type(SoulsReworkReel_previousStep) == "function" then
    r = table.pack(SoulsReworkReel_previousStep(...))
  end
  local ok, err = pcall(SoulsReworkReel_Step)
  if not ok then
    ReelLog("step error", tostring(err))
    pcall(ReelClose)
  end
  return table.unpack(r, 1, r.n)
end
-- ===== SoulsRework reel END =====
