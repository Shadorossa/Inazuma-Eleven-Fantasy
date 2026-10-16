-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), clean_hud's ui_flags.toml flags, merged (Lua table body), @TAG@ (menu tag for the log).
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

-- EVT ui_clean, header_shift: the top title header (mainmenu90_01) is 55 % of its retail height since v3b, so
-- the content of this menu moves up by the height saved (54.9 px) instead of leaving a gap under the header.
-- Only the ROOT layers listed below move (a layer attached to one of them follows it). Mode 1 = move up; mode 2 =
-- stretch an art/background layer so its top moves up and its bottom and right edges stay (no seam at the bottom).
-- Every CMND_SET_LAYER_LOCAL_POS the menu itself sends for these layers gets the same offset, so retail positioning
-- (slide-ins, list scroll) keeps working on top of it. When HS_CHECK is set, the offset applies only while that
-- menu's header is open (menus that are also used without the header). Flag: header_short.
local HS_DY = 54.9
local HS_LAYERS = { @HS_LAYERS@ }
local HS_STRETCH = { @HS_STRETCH@ }
local HS_CHECK = nil
local CMND_SET_LAYER_LOCAL_POS = 1389957207
local CMND_SET_LAYER_LOCAL_SCALE = 3778714801
local CMND_IS_OPEN_MENU_OBJECT = 3693934564
local HEADER_LAYER = 575058101        -- mainmenu90_01_header
local hs_logged = false
local hs_check_raw = "-"

-- Pure lookups only: no layer handle is ever stored (layers are addressed by name hash), nothing runs per frame;
-- the check is one engine query, made only for this menu's listed layers.
local function HsActive()
  if not UiOn("header_short") then
    return false
  end
  if HS_CHECK == nil then
    return true
  end
  if type(funcLuaCommand) ~= "function" then
    return false
  end
  for _, m in ipairs(HS_CHECK) do
    local ok, r = pcall(funcLuaCommand, CMND_IS_OPEN_MENU_OBJECT, m, HEADER_LAYER)
    hs_check_raw = tostring(ok) .. ":" .. tostring(r)
    if ok and r ~= nil and r ~= false and r ~= 0 then
      return true
    end
  end
  return false
end

-- Re-entrancy guard + hard cap: while this block is inside an engine call it never acts again (a nested
-- SET_LAYER_LOCAL_POS passes through unchanged), and after HS_CAP actions the block switches itself off.
local hs_busy = false
local hs_count = 0
local HS_CAP = 400

local function UiMenuFilter(orig, id, ...)
  if id ~= CMND_SET_LAYER_LOCAL_POS or hs_busy then
    return nil
  end
  local a = Pack(...)
  if type(a[1]) ~= "number" or HS_LAYERS[a[1]] == nil or type(a[3]) ~= "number" then
    return nil
  end
  if hs_count >= HS_CAP then
    return nil
  end
  hs_busy = true
  local okc, active = pcall(HsActive)
  if not (okc and active) then
    hs_busy = false
    return nil
  end
  hs_count = hs_count + 1
  a[3] = a[3] + HS_DY               -- layout Y is up: + moves the layer up
  local r = Pack(pcall(orig, id, table.unpack(a, 1, a.n)))
  hs_busy = false
  if not r[1] then
    UiLog("error", "header_shift pos", r[2])
    return Pack()
  end
  return Pack(table.unpack(r, 2, r.n))
end
UiHookMenuCommand(UiMenuFilter)

local function HsSetup(a1, a2)
  if hs_busy or type(a1) ~= "number" or HS_LAYERS[a1] == nil or type(funcLuaMenuCommand) ~= "function"
      or hs_count >= HS_CAP then
    return
  end
  local active = HsActive()
  local idx = type(a2) == "number" and a2 or 0
  if active then                  -- inactive: no call at all, the layer keeps its retail state untouched
    local st = HS_STRETCH[a1]
    if st ~= nil then
      funcLuaMenuCommand(CMND_SET_LAYER_LOCAL_SCALE, a1, st[1], st[1], 1, idx)
      funcLuaMenuCommand(CMND_SET_LAYER_LOCAL_POS, a1, st[2], st[3] - HS_DY, 0, idx)   -- the filter adds HS_DY
    else
      funcLuaMenuCommand(CMND_SET_LAYER_LOCAL_POS, a1, 0, 0, 0, idx)                    -- 0 + HS_DY
    end
  end
  if not hs_logged then
    hs_logged = true
    UiLog("header_shift", a1, idx, active and "on" or "off (no header)", hs_check_raw)
  end
end

if not UiWrapCallback("OnSetupLayer", HsSetup) then
  OnSetupLayer = function(a1, a2)
    local ok, err = pcall(HsSetup, a1, a2)
    if not ok then
      UiLog("error", "OnSetupLayer", err)
    end
  end
end
