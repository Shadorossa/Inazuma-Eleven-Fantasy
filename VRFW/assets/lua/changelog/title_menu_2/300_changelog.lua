-- changelog (VR-Framework): the automatic «Novedades de mods» sheet at the title (docs/game/ui/update-notes.md).
-- Own code: two handlers of the framework's title_menu_2 host (VRFW_Host), each one calls the next (nxt).
--
-- * IsNeedToDisplaySystemUpdateMess (title_menu_inc): the retail answer OR «a mod has versions not seen yet»
--   (CMND_VRFW_CHANGELOG_PENDING); StartTitleMenu2_Coroutine then calls UpdateTitleMenuFirstOpen.
-- * UpdateTitleMenuFirstOpen: first the retail sheet when the game needs it (welcome pages / the game's own update
--   notes, with its flag and autosave), then the mods sheet: the same retail menu (title_tutorial_menu) opened the
--   same way, WITHOUT the flag and the autosave (nothing of this goes to the save); the part marks the versions seen
--   when it closes (CMND_VRFW_CHANGELOG_CLOSE).
-- Without the part (old ModLoader, part off) the commands fail and everything is retail. No engine call at load time.

local function CLT_Crc(s)
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

local CLT = {
  PENDING = CLT_Crc("CMND_VRFW_CHANGELOG_PENDING"),   -- () -> the automatic sheet is due
  OPEN = CLT_Crc("CMND_VRFW_CHANGELOG_OPEN"),         -- (0 auto, languageCode) -> pages
  CLOSE = CLT_Crc("CMND_VRFW_CHANGELOG_CLOSE"),       -- () -> marks the versions seen
  LANG = 477234096,                                  -- CMND_GET_LANGUAGE_CODE
  TITLE = 3874253475,                                -- title_menu_2
  SHEET = 3492314538,                                -- title_tutorial_menu
  CURSOR = 24113234,                                 -- cmn05_01_coursor
}

local function CLT_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function CLT_Pending()
  return CLT_Call(CLT.PENDING) == true
end

local function CLT_WaitWhile(f)
  while f() do
    coroutine.yield()
  end
end

-- the mods sheet, opened like retail UpdateTitleMenuFirstOpen (minus the welcome flag and the autosave)
local function CLT_Sheet()
  local pages = CLT_Call(CLT.OPEN, 0, CLT_Call(CLT.LANG) or 1)
  if type(pages) ~= "number" or pages < 1 then
    return
  end
  CLT_WaitWhile(function() return funcLuaMenuCommand(2640875187, CLT.CURSOR) == false end)   -- cursor open
  funcLuaMenuCommand(711242136, CLT.CURSOR, 0, false)
  CLT_WaitWhile(function() return funcLuaCommand(667479479, CLT.TITLE) end)                 -- title loading
  funcLuaMenuCommand(1558704558, CLT.TITLE, false)                                          -- title input off
  funcLuaMenuCommand(1951894516, false)
  funcLuaCommand(433545986, CLT.SHEET)                                                      -- CMND_OPEN_MENU_OBJECT
  CLT_WaitWhile(function() return funcLuaMenuCommand(2231168902, CLT.SHEET) end)             -- until it is closed
  CLT_Call(CLT.CLOSE)
  funcLuaMenuCommand(711242136, CLT.CURSOR, 0, true)
  funcLuaMenuCommand(1951894516, true)
  -- the title's input comes back right after this (StartTitleMenu2_Coroutine: menu active title_menu_2)
end

-- handlers of the framework's title_menu_2 host (VRFW_Host, docs/framework/lua-hosts.md)
if VRFW_Host ~= nil then
  -- the game's own answer: what is under the host (retail / the merge-path patches), without this handler
  local clt_retail_need = VRFW_Host.original("title_menu_2", "IsNeedToDisplaySystemUpdateMess")
  local clt_has_need = type(IsNeedToDisplaySystemUpdateMess) == "function"

  VRFW_Host.on("title_menu_2", "IsNeedToDisplaySystemUpdateMess", {
    id = "changelog.title_sheet", phase = "around",
    fn = function(nxt, ...)
      if nxt(...) == true then
        return true
      end
      return CLT_Pending()
    end,
  })

  VRFW_Host.on("title_menu_2", "UpdateTitleMenuFirstOpen", {
    id = "changelog.title_sheet", phase = "around",
    fn = function(nxt, ...)
      if not clt_has_need or clt_retail_need() == true then
        nxt(...)
      end
      if CLT_Pending() then
        CLT_Sheet()
      end
    end,
  })
end
