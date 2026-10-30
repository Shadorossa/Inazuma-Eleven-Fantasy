-- BetterUI (clean_hud) graft clean_hud_bb_title: the Battle Bay header's title text (mainmenu90_01_header, text node
-- _text_sub_title02: «Campaña» etc.) is blanked after the retail Step each frame; logo, icon and bar are untouched.
-- No engine call at load: the blank runs inside Step only.
do
  local CHD_BBT = {
    HEADER = 575058101,            -- mainmenu90_01_header
    TITLE = 1220590795,            -- _text_sub_title02
    CMD_TEXT = @crc:CMND_SET_MENU_TEXT_STRING@,         -- CMND_SET_MENU_TEXT_STRING (layer, text, string, idx)
  }

  if EVT_CHD_BBT_WRAPPED == nil then
    EVT_CHD_BBT_WRAPPED = true
    local step = Step
    if type(step) ~= "function" then
      step = function() end
    end
    function Step(...)
      local r = table.pack(step(...))
      if type(funcLuaMenuCommand) == "function" then
        pcall(funcLuaMenuCommand, CHD_BBT.CMD_TEXT, CHD_BBT.HEADER, CHD_BBT.TITLE, "", 0)
      end
      return table.unpack(r, 1, r.n)
    end
  end
end
