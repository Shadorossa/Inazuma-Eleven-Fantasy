-- scene_archive_sections (VR-Framework base feature): the «Archivo de escenas» tabs past the retail three and the
-- per-language movie of a row. docs/framework/scene-archive.md (handler of the scene_archive_menu host).
--
-- * Tabs: the mods declare sections (`scenes\*.toml`, kind vr_framework.scene_archive/1; shared by id between mods);
--   the framework numbers them as game categories 3, 4, … (then the legacy `[[entry]] host = "scene_archive_tab"`
--   entries) and raises the engine's tab count. CMND_VRFW_SCENE_ARCHIVE_TABS = the count the engine has (3 = not
--   raised); CMND_VRFW_SCENE_ARCHIVE_SECTION(i) = category, label text id, icon type of the i-th extra tab.
--   GetTabInfo(category) answers those tabs (the retail script only knows 0-2; the focus icons are the retail
--   Competition tab's) and OnSetupLayer of the list passes 3 + n to LISTVIEW.UpdateAttachTabNum.
-- * Language variant (generic rule, every row): PlayMovieCoroutine's first engine call reads the row's event (field 6
--   = crc32 of event_id_text); the handler answers the movie `<event>_<lang>` (lang = the game text language folder)
--   when CMND_GET_MOVIE_INFO knows it, else the event itself (retail behaviour). The swap of funcLuaCommand lasts only
--   until that first call (it runs before the coroutine's first yield).
-- Without the framework DLL every command fails and the retail script runs as is. No engine call at load time.
-- (Inazuma Fantasy's graft `videoteca` did this until 2026-10-08; it is gone.)

local SA = {
  TABS = 3191468502,         -- CMND_VRFW_SCENE_ARCHIVE_TABS () -> tabs the engine has
  SECTION = 1135094873,      -- CMND_VRFW_SCENE_ARCHIVE_SECTION (i) -> category, text id, icon
  LOG = 3661580131,          -- CMND_EVT_LOG
  ROW_GET = 4199163761,      -- scene archive row field getter (row index, field)
  MOVIE_INFO = 10117594,     -- CMND_GET_MOVIE_INFO (movie id)
  LANG_CODE = 477234096,     -- CMND_GET_LANGUAGE_CODE: nie.exe language table index
  LIST_LAYER = 1887158505,   -- the list layer (attaches one tab button per tab)
  RETAIL = 3,
  LG = {[0] = "ja", [1] = "en", [2] = "fr", [3] = "es", [4] = "pt", [6] = "de", [7] = "it", [16] = "zh_hant",
    [17] = "zh_hans"},
  tabs = nil,                -- {{cat, text, icon}, ...} read once (first use, inside a menu callback)
  logs = 0,
}

local function SA_Log(...)
  if SA.logs >= 20 then
    return
  end
  SA.logs = SA.logs + 1
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  pcall(funcLuaCommand, SA.LOG, "VRFW scene_archive " .. table.concat(parts, " "))
end

local function SA_Tabs()
  if SA.tabs ~= nil then
    return SA.tabs
  end
  SA.tabs = {}
  local ok, n = pcall(funcLuaCommand, SA.TABS)
  if not ok or type(n) ~= "number" then
    return SA.tabs
  end
  for i = 1, n - SA.RETAIL do
    local okc, cat, text, icon = pcall(funcLuaCommand, SA.SECTION, i)
    if okc and type(cat) == "number" then
      SA.tabs[#SA.tabs + 1] = {cat = cat, text = text, icon = icon or 10}
    else
      break
    end
  end
  SA_Log("tabs", n, #SA.tabs)
  return SA.tabs
end

local SA_crcT = nil
local function SA_Crc(s)
  if bit32 == nil then
    return nil
  end
  if SA_crcT == nil then
    SA_crcT = {}
    for i = 0, 255 do
      local c = i
      for _ = 1, 8 do
        if bit32.band(c, 1) == 1 then
          c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
        else
          c = bit32.rshift(c, 1)
        end
      end
      SA_crcT[i] = c
    end
  end
  local c = 0xFFFFFFFF
  for i = 1, #s do
    c = bit32.bxor(bit32.rshift(c, 8), SA_crcT[bit32.band(bit32.bxor(c, s:byte(i)), 0xFF)])
  end
  return bit32.bxor(c, 0xFFFFFFFF)
end

-- the movie id to play for archive row `row` whose event crc is `ev`
local function SA_Variant(cmd, row, ev)
  local okn, name = pcall(cmd, SA.ROW_GET, row, 7)
  local okl, code = pcall(cmd, SA.LANG_CODE)
  local lg = okl and SA.LG[code] or nil
  if not okn or type(name) ~= "string" or name == "" or lg == nil then
    return ev
  end
  local id = SA_Crc(name .. "_" .. lg)
  if id ~= nil then
    local ok, info = pcall(cmd, SA.MOVIE_INFO, id)
    if ok and info ~= nil and info ~= false then
      SA_Log("play", name, lg)
      return id
    end
  end
  return ev
end

if VRFW_Host ~= nil then
  VRFW_Host.on("scene_archive_menu", "GetTabInfo", {
    id = "menu_engine.scene_archive_sections", phase = "around",
    fn = function(nxt, a1, ...)
      local r = nxt(a1, ...)
      if r ~= nil or type(a1) ~= "number" or a1 < SA.RETAIL then
        return r
      end
      local base = nxt(1)   -- the retail Competition tab: its focus icons
      for _, t in ipairs(SA_Tabs()) do
        if t.cat == a1 and base ~= nil then
          return {slotCategory = a1, tabTextId = t.text, tabIconType = t.icon,
            iconFocusOn = base.iconFocusOn, iconFocusOff = base.iconFocusOff}
        end
      end
      return r
    end,
  })

  VRFW_Host.on("scene_archive_menu", "OnSetupLayer", {
    id = "menu_engine.scene_archive_sections", phase = "around",
    fn = function(nxt, a0, ...)
      local n = a0 == SA.LIST_LAYER and #SA_Tabs() or 0
      if n == 0 or LISTVIEW == nil or LISTVIEW.UpdateAttachTabNum == nil then
        return nxt(a0, ...)
      end
      local orig = LISTVIEW.UpdateAttachTabNum
      LISTVIEW.UpdateAttachTabNum = function(k, ...)
        if k == SA.RETAIL then
          k = SA.RETAIL + n
        end
        return orig(k, ...)
      end
      local r = table.pack(pcall(nxt, a0, ...))
      LISTVIEW.UpdateAttachTabNum = orig
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  VRFW_Host.on("scene_archive_menu", "PlayMovieCoroutine", {
    id = "menu_engine.scene_archive_variants", phase = "around",
    fn = function(nxt, ...)
      local cmd = funcLuaCommand
      funcLuaCommand = function(id, a, b, ...)
        if id == SA.ROW_GET and b == 6 then
          funcLuaCommand = cmd
          local ev = cmd(id, a, b, ...)
          if ev == nil then
            return ev
          end
          return SA_Variant(cmd, a, ev)
        end
        return cmd(id, a, b, ...)
      end
      return nxt(...)
    end,
  })
end
