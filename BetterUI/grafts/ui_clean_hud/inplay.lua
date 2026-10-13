-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), inplay (menu tag for the log).
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

-- EVT ui_clean, menu soccer_inplay_menu (match HUD): the zone/area title ("ÁREA" with its orange stripe, one image,
-- layer soccer00_15_zone_area_title) is never shown. The layer is still opened and closed by the retail script
-- (UpdateDrawZoneAreaTitle keeps its CMND_IS_OPEN_LAYER logic), only its visibility is forced off. Flag: zone_hud.
local UI_HIDE_LAYERS = {
  [3052150261] = 1,
}
local CMND_OPEN_LAYER = 629267548
local CMND_OPEN_LAYER_ARRAY = 2152386330
local CMND_SET_LAYER_VISIBLE = 711242136
local UI_FLAG = "zone_hud"

local function UiMenuFilter(orig, id, ...)
  if not UiOn(UI_FLAG) then
    return nil
  end
  if id == CMND_SET_LAYER_VISIBLE then
    local a = Pack(...)
    if UI_HIDE_LAYERS[a[1]] and a[3] == true then
      a[3] = false
      return Pack(orig(id, table.unpack(a, 1, a.n)))
    end
  elseif id == CMND_OPEN_LAYER or id == CMND_OPEN_LAYER_ARRAY then
    local layer = ...
    if UI_HIDE_LAYERS[layer] then
      local r = Pack(orig(id, ...))
      for i = 0, UI_HIDE_LAYERS[layer] - 1 do
        pcall(orig, CMND_SET_LAYER_VISIBLE, layer, i, false)
      end
      UiLog("hide", layer)
      return r
    end
  end
  return nil
end

UiHookMenuCommand(UiMenuFilter)

local function UiAfterLayer(a1, a2)
  if UiOn(UI_FLAG) and UI_HIDE_LAYERS[a1] and type(funcLuaMenuCommand) == "function" then
    funcLuaMenuCommand(CMND_SET_LAYER_VISIBLE, a1, a2 or 0, false)
  end
end
UiWrapCallback("OnSetupLayer", UiAfterLayer)
UiWrapCallback("OnOpenLayer", UiAfterLayer)
