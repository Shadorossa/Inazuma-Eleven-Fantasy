-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), area_title (menu tag for the log).
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

-- EVT ui_clean, menu soccer_area_title_menu (match HUD): the big mode title under the TENSION block. One layer,
-- soccer00_14_area_title, whose sprite _mode_title01 the engine sets through SetupAreaTitle(type):
-- 1 = "FOCO" (focus battle), 2 = scramble, 3 = zone ("ÁREA" + orange stripe, one image). Only type 3 is hidden
-- (flag zone_hud); FOCO / scramble keep their title. Display only: the menu, the layer and the zone are untouched.
-- (v2 hid soccer00_15_zone_area_title of soccer_inplay_menu instead: that is a different, small title, the in-game
-- test 2026-09-24 20:28 showed the big one here was still visible.)
local UI_LAYER = 2169865486
local UI_MESH = 2623254857
local UI_ZONE_TYPE = 3
local CMND_SET_LAYER_VISIBLE = 711242136
local CMND_SET_MESH_VISIBLE = 3405944500
local ui_area_type = 0

local function UiHideNow()
  return UiOn("zone_hud") and ui_area_type == UI_ZONE_TYPE
end

local function UiApply()
  if type(funcLuaMenuCommand) ~= "function" then
    return
  end
  if UiHideNow() then
    funcLuaMenuCommand(CMND_SET_MESH_VISIBLE, UI_LAYER, UI_MESH, false, 0)
    funcLuaMenuCommand(CMND_SET_LAYER_VISIBLE, UI_LAYER, 0, false)
  else
    funcLuaMenuCommand(CMND_SET_MESH_VISIBLE, UI_LAYER, UI_MESH, true, 0)
  end
end

-- anything that tries to show the layer / the title mesh again while a zone title is up stays hidden
local function UiMenuFilter(orig, id, ...)
  if not UiHideNow() then
    return nil
  end
  local a = Pack(...)
  if id == CMND_SET_LAYER_VISIBLE and a[1] == UI_LAYER and a[3] == true then
    a[3] = false
    return Pack(orig(id, table.unpack(a, 1, a.n)))
  elseif id == CMND_SET_MESH_VISIBLE and a[1] == UI_LAYER and a[2] == UI_MESH and a[3] == true then
    a[3] = false
    return Pack(orig(id, table.unpack(a, 1, a.n)))
  end
  return nil
end
UiHookMenuCommand(UiMenuFilter)

local ui_orig_setup = rawget(_ENV, "SetupAreaTitle")
if type(ui_orig_setup) == "function" then
  rawset(_ENV, "SetupAreaTitle", function(a1, ...)
    ui_area_type = a1 or 0
    local r = Pack(ui_orig_setup(a1, ...))
    local ok, err = pcall(UiApply)
    UiLog("area_title", a1, ok and "ok" or err)
    return table.unpack(r, 1, r.n)
  end)
end

UiWrapCallback("OnSetupLayer", function(a1, a2)
  if a1 == UI_LAYER then
    UiApply()
  end
end)

-- the retail script has no OnOpenLayer; add one (engine callbacks are optional) to re-apply after the open
if rawget(_ENV, "OnOpenLayer") == nil then
  rawset(_ENV, "OnOpenLayer", function(a1, a2)
    if a1 == UI_LAYER then
      pcall(UiApply)
    end
  end)
end
