-- EVT ui_clean graft: header dock part (research/scripts/ui_clean_build.py, docs/game/ui/ui-redesign.md §3.3c).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: @TAG@ (menu tag for the log), @HD_LAYERS@ / @HD_CHECK@ (computed by
-- ui_clean_build.py --header-dock from the v7.1.2 layouts and the compact header; never edit them by hand).
local EVT_UI_MARK = "EVT_UI_CLEAN_GRAFT"

-- Kill switch. EVT_UI_PRESET = "off" makes every ui_clean wrapper pass everything through unchanged.
-- Each feature can also be switched off on its own in EVT_UI_FLAGS (set by the build, see --preset / --no-*).
if EVT_UI_PRESET == nil then
  EVT_UI_PRESET = "limpio"
end
EVT_UI_FLAGS = EVT_UI_FLAGS or {}
for k, v in pairs({ bank_sort_guide = true, buff_icons = true, buff_panel = false, corner_buttons = true, duel_telop = true, enemy_meters = true, esc_guide = true, exec_offset = true, header_short = true, nickname_pill = true, team_param_guide = true, zone_exec = false, zone_hud = true }) do
  if EVT_UI_FLAGS[k] == nil then
    EVT_UI_FLAGS[k] = v
  end
end

@UI_WRAP@

-- EVT ui_clean, header dock: retail widgets made for the 122 px header bar that hang under the compact (67 px) bar
-- are put INTO the bar. Each listed layer gets one layer transform (CMND_SET_LAYER_LOCAL_SCALE + _POS): the whole
-- instance moves and scales, so its pointer zones (MenuCollisionSetting, which follow the instance transform, not node
-- writes) stay on the drawn arrows. Placement = data: { local x, local y (layout units, y up), scale } per layer.
-- Only while the compact header is on (flag header_short) and the header of one of HD_CHECK is open (the screen can
-- also open without the team dock's header: then retail, untouched). The menu itself never moves these layers.
local HD_LAYERS = { @HD_LAYERS@ }
local HD_CHECK = { @HD_CHECK@ }
local CMND_SET_LAYER_LOCAL_POS = 1389957207
local CMND_SET_LAYER_LOCAL_SCALE = 3778714801
local CMND_IS_OPEN_MENU_OBJECT = 3693934564
local HEADER_LAYER = 575058101        -- mainmenu90_01_header
local hd_done = {}
local hd_check_raw = "-"

-- One engine query per call (funcLuaCommand: through funcLuaMenuCommand this command never answers).
local function HdActive()
  if not UiOn("header_short") then
    return false
  end
  if type(funcLuaCommand) ~= "function" then
    return false
  end
  for _, m in ipairs(HD_CHECK) do
    local ok, r = pcall(funcLuaCommand, CMND_IS_OPEN_MENU_OBJECT, m, HEADER_LAYER)
    hd_check_raw = tostring(ok) .. ":" .. tostring(r)
    if ok and r ~= nil and r ~= false and r ~= 0 then
      return true
    end
  end
  return false
end

local function HdPlace(a1, a2)
  if type(a1) ~= "number" or HD_LAYERS[a1] == nil or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  local idx = type(a2) == "number" and a2 or 0
  local t = HD_LAYERS[a1]
  local active = HdActive()
  if active then                  -- inactive: no call at all, the layer keeps its retail state
    funcLuaMenuCommand(CMND_SET_LAYER_LOCAL_SCALE, a1, t[3], t[3], 1, idx)
    funcLuaMenuCommand(CMND_SET_LAYER_LOCAL_POS, a1, t[1], t[2], 0, idx)
  end
  if hd_done[a1] == nil then
    hd_done[a1] = true
    UiLog("header_dock", a1, idx, active and "in bar" or "retail (no compact header)", hd_check_raw)
  end
end

-- OnSetupLayer places the layer when it is created; OnOpenLayer again (cheap, idempotent) in case the header opened
-- in between.
for _, cb in ipairs({ "OnSetupLayer", "OnOpenLayer" }) do
  if not UiWrapCallback(cb, HdPlace) then
    UiLog("error", "no " .. cb .. " to wrap")
  end
end
