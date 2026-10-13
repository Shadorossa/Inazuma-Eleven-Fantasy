-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), team_dock_top (menu tag for the log).
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

-- EVT ui_clean, menu team_dock_common_top_menu (parent of "Plantilla de equipo"): the bottom-left "Esc + return
-- arrow" guide (layer mainmenu01_10_return_arrow_button_guide) loses its own pill background (mesh _back_base01)
-- (v3: the layout mainmenu01_10.g4pkm hides the pill and draws the glyphs at 90 % in every menu; this block only
-- hides the pill mesh as a second line, the retail glyph style is kept). Flag: esc_guide.
local UI_ESC_LAYER = 2005383485
local UI_ESC_MESH = 1714756523
local CMND_SET_MESH_VISIBLE = 3405944500
local ui_esc_logged = false

local function UiFixEsc(a1, a2)
  if a1 ~= UI_ESC_LAYER or not UiOn("esc_guide") or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  local idx = a2 or 0
  funcLuaMenuCommand(CMND_SET_MESH_VISIBLE, a1, UI_ESC_MESH, false, idx)
  if not ui_esc_logged then
    ui_esc_logged = true
    UiLog("esc_guide", a1, idx)
  end
end

UiWrapCallback("OnSetupLayer", UiFixEsc)
UiWrapCallback("OnOpenLayer", UiFixEsc)
