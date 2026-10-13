-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), buff_icons (menu tag for the log).
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

-- EVT ui_clean, menu soccer_team_buff_icon_list_menu (match HUD, bottom left): the team buff / passive icons
-- (DF 60 %, boot 28 %, ...) are drawn smaller. The retail script places every icon with
-- CMND_SET_LAYER_LOCAL_POS(layer, 68 * n, 0, 0, idx) on the locator _atc_teambuff01 of soccer00_50 every frame;
-- we scale the step and the icon itself by 0.85. The single background panel comes from the data side
-- (soccer00_51 tile + % strip made flat and seamless). Flag: buff_icons.
local UI_BUFF_S = 0.85
local UI_BUFF_DX = -5.4          -- keeps the panel's left edge where it was
local UI_BUFF_DY = -7.65          -- keeps the panel's bottom edge where it was (layout Y is up)
local UI_BUFF_LAYERS = {
  [1516973567] = true,
  [2849833820] = true,
  [2861847060] = true,
  [1535165083] = true,
}
local CMND_SET_LAYER_LOCAL_POS = 1389957207
local CMND_SET_LAYER_LOCAL_SCALE = 3778714801
local ui_buff_logged = false

local function UiMenuFilter(orig, id, ...)
  if id ~= CMND_SET_LAYER_LOCAL_POS or not UiOn("buff_icons") then
    return nil
  end
  local a = Pack(...)
  if not UI_BUFF_LAYERS[a[1]] or type(a[2]) ~= "number" then
    return nil
  end
  a[2] = a[2] * UI_BUFF_S + UI_BUFF_DX
  a[3] = (a[3] or 0) + UI_BUFF_DY
  local r = Pack(orig(id, table.unpack(a, 1, a.n)))
  pcall(orig, CMND_SET_LAYER_LOCAL_SCALE, a[1], UI_BUFF_S, UI_BUFF_S, 1, a[5] or 0)
  if not ui_buff_logged then
    ui_buff_logged = true
    UiLog("buff_scale", UI_BUFF_S, a[1], a[2], a[5])
  end
  return r
end

UiHookMenuCommand(UiMenuFilter)
