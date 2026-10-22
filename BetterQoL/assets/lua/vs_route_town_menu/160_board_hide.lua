-- Utilities › the Chronicle board's hide switch: X (CMD_FUNC4, content\menus\board\board_hide.toml) hides / shows the
-- board nodes every mod lists in a hideable [[VRFW.BoardGroup]] (e.g. New Recruitment's pachanga points), visually
-- only (VRFW_RN_SetHide, graft route_nodes); the state lasts for the game session. Its bottom guide entry «X Ocultar» /
-- «X Mostrar» (VRFW_FooterPrompts) shows only when some mod declares such nodes. VRFW_Host handlers only: nothing runs
-- at load but their registration.
if VRFW_Host ~= nil then
  Utilities = Utilities or {}
  local H = {
    STEM = "vs_route_town_menu",
    FUNCTION = 4283758262,        -- crc32("utilities_board_hide"): the input row's function
    KEY = 1435897304,             -- CMD_FUNC4
    GLYPH = 2085238077,           -- <CMD_FUNC4>
    HIDE = 1663200964,            -- menu_text BetterQoL.BoardHideGuide «Ocultar»
    SHOW = 3439609244,            -- menu_text BetterQoL.BoardShowGuide «Mostrar»
    GUIDE = 1138543975,           -- mainmenu01_06_base_button_guide
    SE = 1917805374, SE_OK = 3848881948,
  }
  BetterQoL.BoardHide = H

  local function available()
    return VRFW_RN_HideableCount ~= nil and VRFW_RN_HideableCount() > 0
  end

  local function hidden()
    return VRFW_RN_HideOn ~= nil and VRFW_RN_HideOn()
  end

  local function prompts()
    if VRFW_FooterPrompts == nil then
      return
    end
    VRFW_FooterPrompts.Add({Name = "BetterQoL.BoardHide", Menu = H.STEM, Text = H.HIDE, Icon = H.GLYPH, Command = H.KEY,
      Order = 50, When = function() return available() and not hidden() end})
    VRFW_FooterPrompts.Add({Name = "BetterQoL.BoardShow", Menu = H.STEM, Text = H.SHOW, Icon = H.GLYPH, Command = H.KEY,
      Order = 50, When = function() return available() and hidden() end})
  end

  VRFW_Host.on(H.STEM, "OnInit", {id = "utilities.board_hide", phase = "before", fn = function() prompts() end})

  VRFW_Host.on(H.STEM, "OnFunction", {
    id = "utilities.board_hide", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= H.FUNCTION then
        return nxt(a1, ...)
      end
      if not available() or VRFW_RN_SetHide == nil then
        return
      end
      VRFW_RN_SetHide(not hidden())
      pcall(funcLuaCommand, H.SE, H.SE_OK)
      if SetupButtonGuideInfo ~= nil then
        pcall(SetupButtonGuideInfo, H.GUIDE, 0)    -- the guide again: «Ocultar» <-> «Mostrar»
      end
    end,
  })
end
