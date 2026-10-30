-- BetterUI (clean_hud) graft clean_hud_controls_guide: the controls guide of a mode top menu whose corner buttons are
-- hidden (graft clean_hud_menu_cleanup, flag corner_buttons) as a footer prompt «<Y> Guía de controles» (one file of this
-- graft per screen, its menu filled in by the graft's vars):
--   * declared to the VR-Framework's footer prompts (VRFW_FooterPrompts, attached to the screen's UpdateButtonGuide on its
--     guide mainmenu01_06_base_button_guide): after the retail entries, only while the screen sets its own guide
--     (UpdateButtonGuide(true); with false the guide is another menu's turn); a click on it sends CMD_FUNC3;
--   * the key: the lists' retail CMD_FUNC3 row (Y on a pad, V on the keyboard) calls OnFunction with the controls guide
--     function; this wrapper (outside the cleanup block, which ignores that function) plays the retail decide sound and
--     runs the screen's own WaitExecHelpWindow (the retail help window of the controls, input off while it is open),
--     without the hidden corner button's press animation.
-- With corner_buttons off (the corner buttons on screen) everything passes through to the retail code. Pure Lua at
-- chunk load (no engine call).
BETTERUI_CONTROLS_GUIDE = {
  MENU = "@MENU@",
  TEXT = 3488731598 --[[«Guía de controles»: the corner button's own label]],
  ICON = 3794706590 --[[<CMD_FUNC3>: Y on a pad, V on the keyboard]],
  KEY = 3421673595 --[[CMD_FUNC3: what a click on the prompt sends]],
  FUNCTION = 1643904886 --[[the lists' retail CMD_FUNC3 function: the controls guide]],
  PLAY_SOUND = @crc:CMND_SND_PLAY_SE@,
  DECIDE_SOUND = 3848881948 --[[the retail sound of the controls guide button]],
  guide_on = false,
}

-- the corner buttons are hidden (the cleanup block's flag)
function BETTERUI_CONTROLS_GUIDE.Hidden()
  return EVT_UI_PRESET ~= "off" and type(EVT_UI_FLAGS) == "table" and EVT_UI_FLAGS.corner_buttons == true
end

do
  local G = BETTERUI_CONTROLS_GUIDE
  if VRFW_FooterPrompts ~= nil then
    VRFW_FooterPrompts.Add({
      Name = "BetterUI.ControlsGuide",
      Menu = G.MENU,
      Text = G.TEXT,
      Icon = G.ICON,
      Command = G.KEY,
      Order = 100,
      When = function()
        return G.guide_on == true and G.Hidden()
      end,
    })
    VRFW_FooterPrompts.Attach(G.MENU, "UpdateButtonGuide")
  end

  -- the screen's own guide (true) or a cleared one while another menu is up (false)
  local guide = rawget(_ENV, "UpdateButtonGuide")
  if type(guide) == "function" then
    rawset(_ENV, "UpdateButtonGuide", function(a1, ...)
      G.guide_on = a1 == true
      return guide(a1, ...)
    end)
  end

  local fn = rawget(_ENV, "OnFunction")
  if type(fn) == "function" then
    rawset(_ENV, "OnFunction", function(a1, ...)
      if a1 == G.FUNCTION and G.Hidden() and type(WaitExecHelpWindow) == "function" then
        if type(funcLuaCommand) == "function" then
          pcall(funcLuaCommand, G.PLAY_SOUND, G.DECIDE_SOUND)
        end
        return WaitExecHelpWindow()
      end
      return fn(a1, ...)
    end)
  end
end
