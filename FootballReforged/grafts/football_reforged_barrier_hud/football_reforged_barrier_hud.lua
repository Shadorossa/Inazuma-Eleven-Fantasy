-- ===== EVT FootballReforged barrier hud BEGIN =====
-- EVT football_reforged_barrier_hud (mod Football Reforged, module goalkeeper_barrier; docs/game/mechanics/gk-barrier.md
-- §4): each keeper's barrier drawn INSIDE his fatigue bar of the scoreboard (layer soccer00_01_kp_scoreboard_kp, rate
-- settings gauge_self / gauge_enemy) as an ORANGE segment at the bar's GOAL SIDE: own team's bar (left of the
-- scoreboard, locator _pos_hp01) -> its LEFT end; rival's bar (right, _pos_hp02) -> its RIGHT end. Segment length =
-- the barrier % of the bar (25 % for a fresh keeper, shorter as he tires, hidden at 0).
-- Layer football_reforged_barrier (the mod's content\menus\goalkeeper_barrier_hud.toml: the retail btl06_13 gauge, 2
-- instances hung on _pos_hp01 / _pos_hp02): only its fill is shown (frame, red trail and label hidden), its sprite
-- hp_bar02 swapped for the orange football_reforged_barrier_fill01, its rate kept full; the segment is the layer's
-- local position + x scale. Value: CMND_FOOTBALLREFORGED_GOALKEEPER_BARRIER(-1 own / -2 rival) -> ok, percent; no
-- answer (module off, no match, no keeper) = hidden. Hidden too while the keeper bar layer is closed. Engine calls
-- only from the wrapped UpdateScoreboardKeeperHp (every frame from StepSoccerConstantMenu); every call goes through
-- pcall. loader.log: the first lines «FR_BARRIER ...» (CMND_EVT_LOG) say what the step saw.
FOOTBALL_BARRIER_HUD = true                   -- false: no barrier segments
FOOTBALL_BARRIER_CMD = @crc:CMND_FOOTBALLREFORGED_GOALKEEPER_BARRIER@
-- each keeper bar in its locator's space (layout units, y up): _keeper_hp_gauge01_s / 02_s, top-left (-182, 12), 364 x 24
FOOTBALL_BARRIER_BAR_LEFT = -182
FOOTBALL_BARRIER_BAR_TOP = 12
FOOTBALL_BARRIER_BAR_WIDTH = 364
FOOTBALL_BARRIER_BAR_HEIGHT = 24
FOOTBALL_BARRIER_RIVAL_DX = 0                 -- extra offset of the rival's segment
FOOTBALL_BARRIER_RIVAL_DY = 0
FOOTBALL_BARRIER_LOGS = 0
FOOTBALL_BARRIER_SHOWN = {false, false}
FOOTBALL_BARRIER_LAST = {nil, nil}

local BARRIER_LAYER = 1188342059 --[[football_reforged_barrier]]
local BARRIER_KEEPER_BARS = 546630184 --[[soccer00_01_kp_scoreboard_kp]]
local BARRIER_RATE_BAR = 3060237847 --[[hp_bar]]
local BARRIER_RATE_RED = 2546116024 --[[hp_bar_red]]
local BARRIER_MESH_FRAME = 1837325853 --[[_hp_base01]]
local BARRIER_MESH_LABEL = 1257514352 --[[_gtxt_stamina01]]
local BARRIER_MESH_TRAIL = 2609329121 --[[_hp_empty01]]
local BARRIER_ATLAS = 1191797350 --[[#/menu/02_btl/btl06/btl06_13/<LG>/btl06_13.g4tx]]
local BARRIER_TEXTURE_SLOT = 1460691304 --[[hp_bar02: the fill's texture slot]]
local BARRIER_TEXTURE_ORANGE = 2373451861 --[[football_reforged_barrier_fill01]]
-- the source gauge's fill _hp_bar02: top-left (100, -820), 448 x 24 (layout units, y up)
local BARRIER_SOURCE_X, BARRIER_SOURCE_Y, BARRIER_SOURCE_W, BARRIER_SOURCE_H = 100, -820, 448, 24
local barrier_ready = {false, false}

local function FootballBarrier_Menu(...)
  if type(funcLuaMenuCommand) ~= "function" then
    return nil
  end
  local r = table.pack(pcall(funcLuaMenuCommand, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function FootballBarrier_Log(...)
  if FOOTBALL_BARRIER_LOGS >= 12 or type(funcLuaCommand) ~= "function" then
    return
  end
  FOOTBALL_BARRIER_LOGS = FOOTBALL_BARRIER_LOGS + 1
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "FR_BARRIER", ...)
end

-- the barrier of side 1 (own) / 2 (rival): its percent 0..100, or nil (nothing to show)
function FootballBarrier_Value(side)
  if type(funcLuaCommand) ~= "function" then
    return nil
  end
  local ok, has, percent = pcall(funcLuaCommand, FOOTBALL_BARRIER_CMD, side == 1 and -1 or -2)
  if not ok or has ~= true or type(percent) ~= "number" then
    return nil
  end
  return math.max(0, math.min(100, percent))
end

-- the layer's local position / scale for instance i (0 own, 1 rival) and a segment `width` long: the own segment
-- starts at the bar's left end, the rival's ends at the bar's right end (the goal side of each bar)
function FootballBarrier_LayerPos(i, width)
  local sx, sy = width / BARRIER_SOURCE_W, FOOTBALL_BARRIER_BAR_HEIGHT / BARRIER_SOURCE_H
  local left = FOOTBALL_BARRIER_BAR_LEFT
  local dx, dy = 0, 0
  if i == 1 then
    left = FOOTBALL_BARRIER_BAR_LEFT + FOOTBALL_BARRIER_BAR_WIDTH - width
    dx, dy = FOOTBALL_BARRIER_RIVAL_DX, FOOTBALL_BARRIER_RIVAL_DY
  end
  return left - BARRIER_SOURCE_X * sx + dx, FOOTBALL_BARRIER_BAR_TOP - BARRIER_SOURCE_Y * sy + dy, sx, sy
end

local function FootballBarrier_HideOne(i)
  if FOOTBALL_BARRIER_SHOWN[i + 1] then
    FOOTBALL_BARRIER_SHOWN[i + 1] = false
    FootballBarrier_Menu(711242136 --[[CMND_SET_LAYER_VISIBLE]], BARRIER_LAYER, i, false)
  end
end

function FootballBarrier_Step()
  if not FOOTBALL_BARRIER_HUD or FootballBarrier_Menu(2640875187 --[[CMND_IS_OPEN_LAYER]], BARRIER_KEEPER_BARS, 0) ~= true then
    FootballBarrier_HideOne(0)
    FootballBarrier_HideOne(1)
    return
  end
  local widths = {}
  for side = 1, 2 do
    local percent = FootballBarrier_Value(side)
    if percent ~= nil then
      local width = FOOTBALL_BARRIER_BAR_WIDTH * percent / 100
      if width >= 0.5 then
        widths[side] = width
      end
    end
  end
  if widths[1] == nil and widths[2] == nil then
    FootballBarrier_HideOne(0)
    FootballBarrier_HideOne(1)
    return
  end
  if FootballBarrier_Menu(2640875187 --[[CMND_IS_OPEN_LAYER]], BARRIER_LAYER) ~= true then
    barrier_ready = {false, false}
    FootballBarrier_Menu(2152386330 --[[CMND_OPEN_LAYER_ARRAY]], BARRIER_LAYER)
    return
  end
  if FootballBarrier_Menu(3057768039 --[[CMND_IS_LOADING_LAYER]], BARRIER_LAYER) == true then
    return
  end
  for i = 0, 1 do
    local width = widths[i + 1]
    if width == nil then
      FootballBarrier_HideOne(i)
    else
      if not barrier_ready[i + 1] then
        barrier_ready[i + 1] = true
        FOOTBALL_BARRIER_LAST[i + 1] = nil
        FootballBarrier_Menu(541357333, BARRIER_LAYER, BARRIER_RATE_BAR, 0, i)
        FootballBarrier_Menu(541357333, BARRIER_LAYER, BARRIER_RATE_RED, 0, i)
        FootballBarrier_Menu(1595998683, BARRIER_LAYER, BARRIER_RATE_BAR, 0, 1, i, true)    -- the fill always full
        FootballBarrier_Menu(1595998683, BARRIER_LAYER, BARRIER_RATE_RED, 0, 0, i, true)    -- no red trail
        FootballBarrier_Menu(3405944500 --[[CMND_SET_MESH_VISIBLE]], BARRIER_LAYER, BARRIER_MESH_FRAME, false, i)
        FootballBarrier_Menu(3405944500 --[[CMND_SET_MESH_VISIBLE]], BARRIER_LAYER, BARRIER_MESH_LABEL, false, i)
        FootballBarrier_Menu(3405944500 --[[CMND_SET_MESH_VISIBLE]], BARRIER_LAYER, BARRIER_MESH_TRAIL, false, i)
        FootballBarrier_Menu(558735651 --[[swap texture]], BARRIER_LAYER, BARRIER_ATLAS, BARRIER_TEXTURE_ORANGE, BARRIER_TEXTURE_SLOT, 0, i)
      end
      if FOOTBALL_BARRIER_LAST[i + 1] == nil or math.abs(FOOTBALL_BARRIER_LAST[i + 1] - width) > 0.05 then
        FOOTBALL_BARRIER_LAST[i + 1] = width
        local px, py, sx, sy = FootballBarrier_LayerPos(i, width)
        FootballBarrier_Menu(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], BARRIER_LAYER, sx, sy, 1, i)
        FootballBarrier_Menu(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], BARRIER_LAYER, px, py, 0, i)
        FootballBarrier_Log("instance", i, "width", string.format("%.1f", width), "pos", string.format("%.1f %.1f", px, py),
          "scale", string.format("%.3f %.3f", sx, sy))
      end
      if not FOOTBALL_BARRIER_SHOWN[i + 1] then
        FOOTBALL_BARRIER_SHOWN[i + 1] = true
        FootballBarrier_Menu(711242136 --[[CMND_SET_LAYER_VISIBLE]], BARRIER_LAYER, i, true)
        FootballBarrier_Log("shown", i)
      end
    end
  end
end

local FootballBarrier_previousUpdate = UpdateScoreboardKeeperHp
function UpdateScoreboardKeeperHp(...)
  local r = {n = 0}
  if type(FootballBarrier_previousUpdate) == "function" then
    r = table.pack(FootballBarrier_previousUpdate(...))
  end
  pcall(FootballBarrier_Step)
  return table.unpack(r, 1, r.n)
end
-- ===== EVT FootballReforged barrier hud END =====
