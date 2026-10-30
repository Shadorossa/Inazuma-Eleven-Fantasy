-- VR-Framework > save adjust (docs/framework/save-adjust.md): the look of the save adjust confirmation in the game's
-- general window. setting_top_menu's 120_save_tools.lua sets the parameter vrfw_save_tools_window while its question is
-- up; this window then draws that message left-aligned (style fs_win_l01: the size and colour of the window's own
-- fs_win01, aligned left), so the action labels form one column, and a message longer than the retail sizes (7 lines:
-- getInfoWinLayer sets no window size past that and the text runs under the buttons) gets the XL window. Wraps the
-- menu's own global functions (no host); nothing runs at load time.
do
  local WINDOW_PARAM = 401310444        -- crc32 vrfw_save_tools_window
  local SET_TEXT_STYLE = 2333948100     -- (layer, instance, text node, font style)
  local MESSAGE_NODE = 852552077        -- the window's message text (setTextLocateName of a plain message)
  local STYLE_LEFT = 106324057          -- crc32 fs_win_l01
  local RETAIL_LINES = 7                -- the largest message the retail sizes cover
  local SIZE_XL = 4                     -- SetupGeneralWindow's size argument: ANIME_NAME_WIN_TYPE_XL
  local window_layer = nil              -- the layer of the save adjust question while it is up

  local function asked()
    return VRFW_Param.Has(WINDOW_PARAM)
  end

  local setup = SetupGeneralWindow
  if type(setup) == "function" then
    SetupGeneralWindow = function(text, kind, size, ...)
      if not asked() then
        window_layer = nil
        return setup(text, kind, size, ...)
      end
      if (size == nil or size == 0) and type(text) == "string" then
        local _, breaks = text:gsub("\n", "")
        if breaks + 1 > RETAIL_LINES then
          size = SIZE_XL
        end
      end
      window_layer = setup(text, kind, size, ...)
      return window_layer
    end
  end

  local open = OnOpenLayer
  if type(open) == "function" then
    OnOpenLayer = function(a1, a2, ...)
      local r = table.pack(open(a1, a2, ...))
      if window_layer ~= nil and a1 == window_layer then
        pcall(funcLuaMenuCommand, SET_TEXT_STYLE, a1, a2, MESSAGE_NODE, STYLE_LEFT)
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
