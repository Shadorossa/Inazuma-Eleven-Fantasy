-- VR-Framework > window buttons: other labels on the game's yes / no window. A menu that asks a two-choice question
-- sets the parameters vrfw_window_yes_text / vrfw_window_no_text (menu_text row ids) before it opens the window
-- (MSG_OPEN + MSG_KIND(2, 0)) and clears them when it closes; the window then writes those texts on its two buttons
-- after its own setup. Without them every window is retail. Wraps the menu's own global setupButton (no host);
-- nothing runs at load time.
do
  local YES_PARAM = 4261573565          -- crc32 vrfw_window_yes_text: the first button's text row
  local NO_PARAM = 1121728934           -- crc32 vrfw_window_no_text: the second button's text row
  local BUTTON_TEXT = 2921358143        -- the button's text node (retail setButtonText)

  local function asked(key)
    local v = VRFW_Param.Get(key)
    if type(v) == "number" and v ~= 0 then
      return math.floor(v + 0.5)
    end
    return nil
  end

  local setup = setupButton
  if type(setup) == "function" and type(setButtonText) == "function" then
    setupButton = function(...)
      local r = table.pack(setup(...))
      local yes, no = asked(YES_PARAM), asked(NO_PARAM)
      if yes ~= nil then
        pcall(setButtonText, BUTTON_TEXT, yes, 0, 0)
      end
      if no ~= nil then
        pcall(setButtonText, BUTTON_TEXT, no, 0, 1)
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
