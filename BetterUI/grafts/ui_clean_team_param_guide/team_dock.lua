-- ===== EVT ui_clean team_param_guide BEGIN =====
-- research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11
do
local EVT_UI_Block = function()
-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), team_dock (menu tag for the log).
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

-- EVT ui_clean, menus soccer_formation_menu / soccer_team_dock_menu / team_dock_formation_menu (Formación / Plantilla):
-- the right-hand guide
-- "Y ↻ Bonific. de equipo" (layer mainmenu01_18_team_parameter_button_guide) looks like the other bottom guide
-- entries: no dark pill (mesh _guide_base01), 48 px button glyph (_text_btn01 style 965926135 fs_48_cc_2d0_btn instead
-- of 1556358205 fs_64_cc_2d0_btn), guide text style fs_guide01 (-1891129784, the style of "Aceptar"/"Mover") and no
-- colour tag ("[CTEAMPARAM01]…[C]" -> plain white text). It stays on the right (layout untouched); the text plate is
-- re-measured so the retail guide bar keeps making room for it. Flag: team_param_guide.
-- v3: the layout (mainmenu01_18.g4pkm: pill and icon at 1 % size) and the objbin (text styles) carry the same fix,
-- so it holds even where no ui_clean Lua runs; this block adds the plain white text (colour tag dropped).
local UI_TP_LAYER = 3159119257
local UI_TP_PILL = 3418019775
local UI_TP_BTN = 950238781
local UI_TP_TEXT = 378156699
local UI_TP_ICON = 260772049   -- the cyan ↻ team build-type icon (v2: hidden; the layout moves the
                                           -- text left into its slot, research/scripts/ui_clean_build.py)
local UI_TP_BTN_STYLE = 965926135
local UI_TP_TEXT_STYLE = 2403837512      -- fs_guide01 (-1891129784 as signed int32)
local UI_TP_DEFAULT_TEXT = 1938000735      -- "[CTEAMPARAM01]Bonific. de equipo[C]"
local CMND_SET_MESH_VISIBLE = 3405944500
local CMND_SET_LAYER_VISIBLE = 711242136
local CMND_SET_TEXT_FONTSTYLE = 2333948100
local CMND_SET_MENU_TEXT_STRING = 1083631230
local CMND_UPDATE_TEXT_PLATE = 1172899594
local CMND_TEXT_GET = 4074371074
local ui_tp_logged = false

local UiFixTeamParam

local function UiPlain(s)
  if type(s) ~= "string" then
    return s
  end
  return (string.gsub(s, "%[C[%w_]*%]", ""))
end

-- colour tags of any text the scripts put on this guide are dropped (the vroad variant sets its own string)
local function UiMenuFilter(orig, id, ...)
  if not UiOn("team_param_guide") then
    return nil
  end
  if id == CMND_SET_MESH_VISIBLE then
    -- retail UpdateTeamParameterButtonGuideByTeamDockNo shows the build icon again on every dock change
    local a = Pack(...)
    if a[1] == UI_TP_LAYER and (a[2] == UI_TP_ICON or a[2] == UI_TP_PILL) and a[3] == true then
      a[3] = false
      return Pack(orig(id, table.unpack(a, 1, a.n)))
    end
    return nil
  end
  if id == CMND_SET_LAYER_VISIBLE then
    -- team_dock_formation_menu (Plantilla > Formación) shows the layer of its parent menu with
    -- CMND_SET_LAYER_VISIBLE(layer, 0, true); the parent's OnSetupLayer fix does not run in this Lua state, so the
    -- guide is fixed again here every time it is shown
    local a = Pack(...)
    if a[1] == UI_TP_LAYER and a[3] == true then
      local r = Pack(orig(id, table.unpack(a, 1, a.n)))
      local ok, err = pcall(UiFixTeamParam, a[1], a[2])
      if not ok then
        UiLog("error", "team_param_guide", err)
      end
      return r
    end
    return nil
  end
  if id ~= CMND_SET_MENU_TEXT_STRING then
    return nil
  end
  local a = Pack(...)
  if a[1] ~= UI_TP_LAYER or a[2] ~= UI_TP_TEXT or type(a[3]) ~= "string" then
    return nil
  end
  a[3] = UiPlain(a[3])
  return Pack(orig(id, table.unpack(a, 1, a.n)))
end
UiHookMenuCommand(UiMenuFilter)

UiFixTeamParam = function(a1, a2)
  if a1 ~= UI_TP_LAYER or not UiOn("team_param_guide") or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  local idx = a2 or 0
  funcLuaMenuCommand(CMND_SET_MESH_VISIBLE, a1, UI_TP_PILL, false, idx)
  funcLuaMenuCommand(CMND_SET_MESH_VISIBLE, a1, UI_TP_ICON, false, idx)
  funcLuaMenuCommand(CMND_SET_TEXT_FONTSTYLE, a1, idx, UI_TP_BTN, UI_TP_BTN_STYLE)
  funcLuaMenuCommand(CMND_SET_TEXT_FONTSTYLE, a1, idx, UI_TP_TEXT, UI_TP_TEXT_STYLE)
  if type(funcLuaCommand) == "function" and not funcLuaCommand(2149480449) then     -- not the Victory Road variant
    local s = funcLuaCommand(CMND_TEXT_GET, UI_TP_DEFAULT_TEXT)
    if type(s) == "string" then
      funcLuaMenuCommand(CMND_SET_MENU_TEXT_STRING, a1, UI_TP_TEXT, UiPlain(s), idx)
    end
  end
  funcLuaMenuCommand(CMND_UPDATE_TEXT_PLATE, a1, idx, UI_TP_TEXT)
  if not ui_tp_logged then
    ui_tp_logged = true
    UiLog("team_param_guide", a1, idx)
  end
end

UiWrapCallback("OnSetupLayer", UiFixTeamParam)
UiWrapCallback("OnOpenLayer", UiFixTeamParam)

end
EVT_UI_Block()
end
-- ===== EVT ui_clean team_param_guide END =====
