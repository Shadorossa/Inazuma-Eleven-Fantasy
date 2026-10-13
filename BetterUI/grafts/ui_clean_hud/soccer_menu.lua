-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), soccer_menu (menu tag for the log).
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

-- EVT ui_clean, menu soccer_menu (match HUD): the OPPONENT's tension / kizuna / hyperdimensional block (top right)
-- is never shown. The player's own block (left) is untouched. Flag: enemy_meters.
-- Layers (soccer_menu_setting.cfg.bin, opened by soccer_menu_inc OpenEnemyTensionMeter / OpenEnemyKizunaPower ...):
local UI_HIDE_LAYERS = {
  [2546223804] = 1,
  [1829362274] = 1,
  [1442388144] = 1,
  [2941575910] = 2,
}
local CMND_OPEN_LAYER = 629267548
local CMND_OPEN_LAYER_ARRAY = 2152386330
local CMND_SET_LAYER_VISIBLE = 711242136

local function UiHideLayer(orig, layer)
  for i = 0, UI_HIDE_LAYERS[layer] - 1 do
    pcall(orig, CMND_SET_LAYER_VISIBLE, layer, i, false)
  end
end

local function UiMenuFilter(orig, id, ...)
  if not UiOn("enemy_meters") then
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
      UiHideLayer(orig, layer)
      UiLog("hide", layer)
      return r
    end
  end
  return nil
end

UiHookMenuCommand(UiMenuFilter)

-- Layers the engine opens by itself still pass through the menu callbacks.
local function UiAfterLayer(a1, a2)
  if UiOn("enemy_meters") and UI_HIDE_LAYERS[a1] and type(funcLuaMenuCommand) == "function" then
    funcLuaMenuCommand(CMND_SET_LAYER_VISIBLE, a1, a2 or 0, false)
  end
end
UiWrapCallback("OnSetupLayer", UiAfterLayer)
UiWrapCallback("OnOpenLayer", UiAfterLayer)

-- 2026-09-28 (in game, captures 69-71: the rival block was still on screen, and the log never had a
-- "EVT_UI soccer_menu hide" line): the engine opens these layers itself (the Lua Open* helpers are never called)
-- and turns them visible again after OnOpenLayer returns, so the hides above do not last. PostStep now hides them
-- every frame while they are open (retail UpdateLineCursor sets its own layer's visibility per frame the same way).
-- Only the four rival layers; the player's own block (left) is never touched.
local CMND_IS_OPEN_LAYER = 2640875187
local UI_STEP_LOGGED = {}
local function UiStepHide()
  if not UiOn("enemy_meters") or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  for layer, n in pairs(UI_HIDE_LAYERS) do
    local ok, open = pcall(funcLuaMenuCommand, CMND_IS_OPEN_LAYER, layer)
    if ok and open == true then
      for i = 0, n - 1 do
        pcall(funcLuaMenuCommand, CMND_SET_LAYER_VISIBLE, layer, i, false)
      end
      if not UI_STEP_LOGGED[layer] then
        UI_STEP_LOGGED[layer] = true
        UiLog("step_hide", layer)
      end
    end
  end
end
UiWrapCallback("PostStep", UiStepHide)
