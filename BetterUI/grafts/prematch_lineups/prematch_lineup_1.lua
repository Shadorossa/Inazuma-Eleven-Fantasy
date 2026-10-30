--@lib evt_prematch.lua#Head
-- EVT prematch: the lineup overlay group (native BattleSettingFlow state 13, after the walk-in) keeps its retail
-- screens and animations and gets a second big button, the retail «Siguiente» button mirrored at the bottom LEFT
-- (layer evt_pm_left_button, docs/game/ui/prematch-lineups.md):
--   own lineup:   «Editar» (left, <CMD_FUNC3>) + «Siguiente»: opens the team editor (soccer_formation_menu through the
--                 retail CMND_OPEN_FORMATION_MENU, as the set-play menu does); on «Terminar edición» the edit is committed
--                 and this same screen is shown again, refreshed;
--   rival lineup: «Datos» (left) + «Siguiente»: the same editor, read-only on the rival team; «Cerrar» = this screen.
-- The editor side (mode parameter EVT_PM_SUB_MODE, read-only guards, commit) is in soccer_formation_menu
-- (prematch_formation_1.lua). A Clean HUD feature (Inazuma Fantasy's graft until 2026-10-08): the layer
-- and its commands are Clean HUD's menus\soccer_battle_setting_flow_vs_menu.toml, the layout / objbin its files\data
-- (research/scripts/prematch_buttons_build.py), the labels its text.toml (clean_hud.prematch_edit / prematch_data) and
-- no switch: always on since Clean HUD 1.14.6 (its «Opciones de mods» row clean_hud.lineup_edit was removed).
-- The old auto-advance (rev 3) stays available but is off: the screens now wait for the player.
EVT_PREMATCH_AUTO = false                -- true: each screen advances by itself (rev 3; the buttons are then useless)
EVT_PM_AUTO_HOLD = 1.0                   -- s shown after the animations end
EVT_PM_AUTO_MAX = 4.0                    -- s max wait for the animations
EVT_PREMATCH_BUTTONS = true              -- false: retail screens (only «Siguiente»)
EVT_PM_LINEUP_CAM = false                -- true: fly-through camera (camera_build.py shots) behind the two screens
local evtPmT = 0
local evtPmAnimT = 0
function EVT_PmAutoOn()
  return EVT_PREMATCH_LINEUPS and EVT_PREMATCH_AUTO and not EVT_PmOnline()
end
function EVT_PmAutoReset()
  evtPmT = 0
  evtPmAnimT = 0
end
function EVT_PmAnimDone(layer)
  local num = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, layer) or 1
  for i = 0, num - 1 do
    if funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, layer, i) and
        not funcLuaMenuCommand(@crc:CMND_IS_END_ANIME_TYPE@, layer, i, 71445658 --[[Open]], 0) then
      return false
    end
  end
  return true
end
function EVT_PmAutoTick(layer, what)
  if not EVT_PmAutoOn() then
    return false
  end
  local dt = funcLuaCommand(1549797111) or 0
  if evtPmAnimT < EVT_PM_AUTO_MAX and not EVT_PmAnimDone(layer) then
    evtPmAnimT = evtPmAnimT + dt
    return false
  end
  evtPmT = evtPmT + dt
  if evtPmT >= EVT_PM_AUTO_HOLD then
    EVT_PmLog("EVT prematch: lineup auto-advance", what, "anim wait", evtPmAnimT)
    EVT_PmAutoReset()
    return true
  end
  return false
end
-- ---------------------------------------------------------------------------------------------- buttons
EVT_PMB = {
  MENU = 1853845420,                     -- soccer_battle_setting_flow_vs_menu (menu object of both groups)
  LEFT = 2945004519,                     -- evt_pm_left_button: Siguiente's layout mirrored (added by the builder)
  NEXT = 562570935,                      -- cmn03_01_next_button («Siguiente»)
  NICK = 209828247,                      -- team00_16_nickname («Apodo»)
  FORM_MENU = 2049316981,                -- soccer_formation_menu
  TEXT_NODE = 378327766,                 -- _text_cmd_back01 (the button's text box)
  TEXT_EDIT = "clean_hud.prematch_edit", -- «Editar» (Clean HUD text.toml); id = CMND_VRFW_TEXT_ID, else its crc32
  TEXT_EDIT_CRC = 858851828,
  TEXT_DATA = "clean_hud.prematch_data", -- «Datos»
  TEXT_DATA_CRC = 536290445,
  ICON_FUNC3 = 3794706590,               -- menu_text "<CMD_FUNC3>" (key glyph, as <CMD_ENTER> in «Siguiente»)
  CMD_FUNC3 = 3421673595,
  FN = 4187903235,                       -- crc32("evt_pm_btn"): MENU_CMD_INFO CMD_FUNC3 -> CMD_FUNCTION (both buttons)
  MENU_CTRL = 1332654303, CHECK_INPUT = @crc:CMND_CHECK_INPUT_CMD@,  -- CMND_CHECK_INPUT_CMD (works without the cfg rows too)
  SUB_KEY = 438809976,                   -- parameter crc32("EVT_PM_SUB_MODE"): 1 edit own team, 2 rival read-only
  OPEN_WAIT = 8.0,                       -- s for the editor to appear before giving up
}
local evtPmbGuide = false                -- left button opened on the current screen
local evtPmbReq = false                  -- button pressed, not handled yet
local evtPmbWas = true                   -- CMD_FUNC3 held (edge detection; true = wait for a release first)
local evtPmbShown = {}                   -- [isSelf] = the screen was already shown once (no telop the second time)
function EVT_PmBtnOn()
  return EVT_PREMATCH_LINEUPS and EVT_PREMATCH_BUTTONS and not EVT_PmOnline()
end
function EVT_PmText(key, crc)            -- a Clean HUD text in the player's language (text engine id, else crc32)
  local ok, id = pcall(funcLuaCommand, @crc:CMND_VRFW_TEXT_ID@, key)
  if not (ok and type(id) == "number" and id ~= 0) then
    id = crc
  end
  return funcLuaCommand(@crc:CMND_TEXT_GET@, id)
end
function EVT_PmBtnPress(src)             -- OnFunction (cfg rows), OnEnter / click on the left button, or the key poll
  if EVT_PmBtnOn() and evtPmbGuide and not evtPmbReq then
    evtPmbReq = true
    EVT_PmLog("EVT prematch: lineup button", src)
  end
end
function EVT_PmLeftSetup(a1, a2)         -- OnSetupLayer: same «offset» state as the retail Siguiente of this group
  if a1 ~= EVT_PMB.LEFT then
    return false
  end
  funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 1493879504 --[[offset]], 0, 1819879843)
  return true
end
function EVT_PmGuideOpen(isSelf)         -- opens the left button (name kept from rev 4a, where it was a guide entry)
  evtPmbGuide = true
  local label = isSelf and EVT_PmText(EVT_PMB.TEXT_EDIT, EVT_PMB.TEXT_EDIT_CRC)
    or EVT_PmText(EVT_PMB.TEXT_DATA, EVT_PMB.TEXT_DATA_CRC)
  local glyph = funcLuaCommand(@crc:CMND_TEXT_GET@, EVT_PMB.ICON_FUNC3)
  if type(label) ~= "string" or label == "" then
    label = isSelf and "Editar" or "Datos"
  end
  if type(glyph) ~= "string" then
    glyph = "<CMD_FUNC3>"
  end
  funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, EVT_PMB.LEFT)
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, EVT_PMB.LEFT, EVT_PMB.TEXT_NODE, glyph .. " " .. label)
  funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, EVT_PMB.NEXT, true)   -- Siguiente keeps the pad focus
  EVT_PmLog("EVT prematch: lineup buttons", isSelf and "self: Editar + Siguiente" or "enemy: Datos + Siguiente")
end
function EVT_PmGuideClose()
  if evtPmbGuide then
    evtPmbGuide = false
    funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, EVT_PMB.LEFT)
    funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, EVT_PMB.LEFT, false)
  end
  evtPmbReq = false
end
function EVT_PmBtnTick(isSelf)           -- called every frame of the retail wait for «Siguiente»; true = button pressed
  if not EVT_PmBtnOn() then
    return false
  end
  if not evtPmbGuide then
    EVT_PmGuideOpen(isSelf)
  end
  local held = funcLuaCommand(EVT_PMB.CHECK_INPUT, EVT_PMB.MENU_CTRL, EVT_PMB.CMD_FUNC3) == true
  if held and not evtPmbWas then
    EVT_PmBtnPress("key")
  end
  evtPmbWas = held
  if evtPmbReq then
    evtPmbReq = false
    return true
  end
  return false
end
function EVT_PmReshow(isSelf)            -- true when this screen is shown again after the editor (skip the telop)
  local again = evtPmbShown[isSelf] == true
  evtPmbShown[isSelf] = true
  return again
end
function EVT_PmSubOpen(isSelf)           -- inside the screen coroutine: close this screen, run the editor, wait
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
  EVT_PmGuideClose()
  SyncCloseFormationLayers(isSelf)
  funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, EVT_PMB.NICK, 0)
  funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, EVT_PMB.NEXT)
  funcLuaMenuCommand(@crc:CMND_SET_ENABLE_CTRL_FOCUS@, EVT_PMB.NEXT, false)
  coroutine.yield()
  WaitSyncCloseFormationLayers(isSelf)
  local mode = isSelf and 1 or 2
  VRFW_Param.Set(EVT_PMB.SUB_KEY, mode, "plain")
  funcLuaMenuCommand(@crc:CMND_OPEN_FORMATION_MENU@)
  EVT_PmLog("EVT prematch: editor opened from the lineup", isSelf and "edit own team" or "rival data (read-only)")
  local t = 0
  while not funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, EVT_PMB.FORM_MENU) do
    t = t + (funcLuaCommand(1549797111) or 0)
    if t > EVT_PMB.OPEN_WAIT then
      EVT_PmLog("EVT prematch: editor did not open -> screen shown again")
      break
    end
    coroutine.yield()
  end
  while funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, EVT_PMB.FORM_MENU) do
    coroutine.yield()
  end
  VRFW_Param.Clear(EVT_PMB.SUB_KEY)
  evtPmbWas = true
  EVT_PmLog("EVT prematch: editor closed -> lineup shown again", isSelf and "self" or "enemy")
end
-- ---------------------------------------------------------------------------------------------- camera (option)
-- Same fixed shots as the pre-match fly-through (soccer_formation_menu, docs/game/media/camaras-fifa.md §6); needs
-- the soccer_camera_config rows of the mod Utilities (without them the engine keeps the chase camera). Off by default
-- (EVT_PM_LINEUP_CAM).
EVT_PM_CAM_SHOT_S = 7.0
EVT_PM_CAM_SHOTS = {2638571594, 72104432, 1934297446, 3979320517}   -- evt_cam_fly_01..04
local evtPmCamOn = false
local evtPmCamShot = 0
local evtPmCamT = 0
function EVT_PmCamStart()
  if evtPmCamOn or not EVT_PM_LINEUP_CAM or not EVT_PREMATCH_LINEUPS or EVT_PmOnline() then
    return
  end
  evtPmCamOn = true
  evtPmCamShot = 0
  evtPmCamT = EVT_PM_CAM_SHOT_S
  EVT_PmLog("EVT prematch: lineup camera start")
end
function EVT_PmCamTick()
  if not evtPmCamOn then
    return
  end
  evtPmCamT = evtPmCamT + (funcLuaCommand(1549797111) or 0)
  if evtPmCamT >= EVT_PM_CAM_SHOT_S then
    evtPmCamT = 0
    evtPmCamShot = evtPmCamShot % #EVT_PM_CAM_SHOTS + 1
    funcLuaCommand(@crc:CMND_CHANGE_SOCCER_CAMERA_TYPE@, 21, 0, 0, 0, EVT_PM_CAM_SHOTS[evtPmCamShot])
  end
end
function EVT_PmCamStop()
  if not evtPmCamOn then
    return
  end
  evtPmCamOn = false
  funcLuaCommand(@crc:CMND_CHANGE_SOCCER_CAMERA_TYPE@, 0, 0, 0, 0)
  funcLuaCommand(@crc:CMND_CAMERA_RESET@, true)
  EVT_PmLog("EVT prematch: lineup camera stop")
end
