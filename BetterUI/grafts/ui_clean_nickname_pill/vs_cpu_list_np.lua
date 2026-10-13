-- ===== EVT ui_clean nickname_pill BEGIN =====
-- research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11
do
local EVT_UI_Block = function()
-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), vs_cpu_list_np (menu tag for the log).
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

-- EVT ui_clean, menus soccer_team_dock_menu (Plantilla) / soccer_vs_cpu_list_menu (Partido libre): the small
-- "X Apodo" pill under the goalkeeper card (layer team00_16_nickname) is never shown, and its key (X = CMD_FUNC4 ->
-- CMD_FUNCTION 3702644710, OnFunction -> funcLuaCommand(376658171) toggles full name / nickname) does nothing, so the
-- names can't flip silently. If the game is in nickname mode when the menu opens, it is switched back once to full
-- names (funcLuaCommand(1332416299) true = full names; the pill then reads "Apodo"). Flag: nickname_pill.
local UI_NP_LAYER = 209828247
local UI_NP_FUNC = 3702644710
local CMND_OPEN_LAYER = 629267548
local CMND_OPEN_LAYER_ARRAY = 2152386330
local CMND_SET_LAYER_VISIBLE = 711242136
local CMND_IS_FULL_NAME = 1332416299
local CMND_TOGGLE_NAME = 376658171
local ui_np_forced = false

local function UiMenuFilter(orig, id, ...)
  if not UiOn("nickname_pill") then
    return nil
  end
  local a = Pack(...)
  if id == CMND_SET_LAYER_VISIBLE and a[1] == UI_NP_LAYER and a[3] == true then
    a[3] = false
    return Pack(orig(id, table.unpack(a, 1, a.n)))
  elseif (id == CMND_OPEN_LAYER or id == CMND_OPEN_LAYER_ARRAY) and a[1] == UI_NP_LAYER then
    local r = Pack(orig(id, ...))
    pcall(orig, CMND_SET_LAYER_VISIBLE, UI_NP_LAYER, 0, false)
    return r
  end
  return nil
end
UiHookMenuCommand(UiMenuFilter)

local function UiNpLayer(a1, a2)
  if a1 ~= UI_NP_LAYER or not UiOn("nickname_pill") or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  funcLuaMenuCommand(CMND_SET_LAYER_VISIBLE, a1, a2 or 0, false)
  if not ui_np_forced and type(funcLuaCommand) == "function" then
    ui_np_forced = true
    if funcLuaCommand(CMND_IS_FULL_NAME) == false then
      funcLuaCommand(CMND_TOGGLE_NAME)
      UiLog("nickname_pill", "forced full names")
    else
      UiLog("nickname_pill", "hidden")
    end
  end
end
UiWrapCallback("OnSetupLayer", UiNpLayer)
UiWrapCallback("OnOpenLayer", UiNpLayer)

-- the X key: swallow the toggle, pass every other function through
local ui_np_orig_fn = rawget(_ENV, "OnFunction")
if type(ui_np_orig_fn) == "function" then
  rawset(_ENV, "OnFunction", function(a1, ...)
    if a1 == UI_NP_FUNC and UiOn("nickname_pill") then
      return
    end
    return ui_np_orig_fn(a1, ...)
  end)
end

end
EVT_UI_Block()
end
-- ===== EVT ui_clean nickname_pill END =====
