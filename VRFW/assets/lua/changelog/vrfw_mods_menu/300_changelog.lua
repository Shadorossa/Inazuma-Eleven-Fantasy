-- changelog (VR-Framework): «Novedades de mods» on demand from the «Mods» screen.
-- Adds the FUNC3 key «Novedades» through the screen's VRFW_MM_EXTRA hook (research/mods/mods_menu/lua/vrfw_mods_menu/
-- 100_mods_screen.lua): it opens the retail update-notes sheet (title_tutorial_menu) with the latest versions of every
-- active mod that has a changelog.toml. Nothing is marked seen. Without the part's commands the key is not offered.
-- No engine call at load time.

local function CLM_Crc(s)
  local crc = 0xFFFFFFFF
  for i = 1, #s do
    crc = bit32.bxor(crc, string.byte(s, i))
    for _ = 1, 8 do
      if bit32.band(crc, 1) ~= 0 then
        crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
      else
        crc = bit32.rshift(crc, 1)
      end
    end
  end
  return bit32.bxor(crc, 0xFFFFFFFF)
end

local CLM = {
  SESSION = CLM_Crc("CMND_VRFW_CHANGELOG_SESSION"),
  OPEN = CLM_Crc("CMND_VRFW_CHANGELOG_OPEN"),       -- (1 on demand, languageCode) -> pages
  CLOSE = CLM_Crc("CMND_VRFW_CHANGELOG_CLOSE"),
  LANG = VRFW_Cmd.GET_LANGUAGE_CODE,                                -- CMND_GET_LANGUAGE_CODE
  SHEET = 3492314538,                              -- title_tutorial_menu
}

local function CLM_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

VRFW_MM_EXTRA = VRFW_MM_EXTRA or {}
VRFW_MM_EXTRA[#VRFW_MM_EXTRA + 1] = {
  fn = CLM_Crc("vrfw_mm_extra3"),     -- CMD_FUNC3 of the screen's setting (crates/plugins/mods_menu/src/screen.rs)
  icon = 3876168952,                  -- retail button guide icon of CMD_FUNC3
  cmd = CLM_Crc("CMD_FUNC3"),
  key = "changelog.news",             -- «Novedades» (text.toml of the part, served by the text part)
  available = function()
    return CLM_Call(CLM.SESSION) ~= nil   -- the part answers
  end,
  flow = function(menu)
    local pages = CLM_Call(CLM.OPEN, 1, CLM_Call(CLM.LANG) or 1)
    if type(pages) ~= "number" or pages < 1 then
      return false
    end
    funcLuaMenuCommand(1558704558, menu, false)                                -- the screen's input off
    funcLuaCommand(VRFW_Cmd.OPEN_MENU_OBJECT, CLM.SHEET)                                      -- CMND_OPEN_MENU_OBJECT
    while funcLuaMenuCommand(VRFW_Cmd.IS_EXIST_MENU_OBJECT, CLM.SHEET) do                        -- until the sheet is closed
      coroutine.yield()
    end
    CLM_Call(CLM.CLOSE)
    return true
  end,
}
