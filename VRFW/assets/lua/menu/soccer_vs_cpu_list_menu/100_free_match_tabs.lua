-- free_match_tabs (VR-Framework base feature): the extra tabs of «Competir contra bots» / «Partido libre»
-- after the retail nine (IE1 … Victory Road). (handler of the
-- soccer_vs_cpu_list_menu host).
--
-- * The mods declare the tabs (`[[free_match_tab]]` of the team type: id, name, icon, order, pieces); the team build
--   numbers them 9, 10, … and writes that number as the routeType of their pieces, so the native list already files
--   their games under them. CMND_VRFW_FM_TABS = extra tabs, total; CMND_VRFW_FM_TAB(i) = index, id, text id, series
--   id, icon atlas, icon, unfocused icon, retail icon type; CMND_VRFW_FM_BAR(total) = the bar layout a mod declared
--   for more than ten tabs (bar sprite, attach rows).
-- * OnOpenLayer of the tab item (around): a saved tab past the bar (a mod switched off, a mode that shows fewer)
--   opens the first tab (and the saved byte is reset).
-- * OnSetupLayer of the tab item (around): the tab count (retail 9 → 9 + n: 10 = the retail 10-tab bar, more = the
--   declared layout), the focus count, and each extra instance's icon (a mod's sprite pair, or a retail icon type);
--   instances past the count are hidden (the framework's menus\free_match_tabs.toml gives the screen 12).
-- * OnChangeFocus of the tab item (around): the name of an extra tab (its menu_text row, or its series' name).
-- Hooks for a mod (set at load, read inside the callbacks): VRFW_FMT_HOOKS[<mod>] = {count = fn(n, tabs) -> n shown
-- (only fewer: the first ones are kept, a tab's index is its routeType), text = fn(id, name) -> name};
-- VRFW_FMT_Index(id) = the tab index of an extra tab. Without the framework DLL every command fails and the retail 9 tabs stay.
-- No engine call at load time.

VRFW_FMT_HOOKS = VRFW_FMT_HOOKS or {}

local FMT = {
  TABS = 1612837075,         -- CMND_VRFW_FM_TABS () -> extra, total
  TAB = 2652141290,          -- CMND_VRFW_FM_TAB (i) -> index, id, text, series, atlas, icon, icon_off, icon_type
  BAR = 2601040204,          -- CMND_VRFW_FM_BAR (total) -> bar sprite, attach rows...
  LOG = 3661580131,          -- CMND_EVT_LOG
  TEXT_GET = 4074371074,     -- CMND_TEXT_GET
  SERIES_INFO = 964991930,   -- CMND_GET_CHARA_SERIES_INFO
  SET_TEXT = 1083631230,     -- CMND_SET_MENU_TEXT_STRING
  LAYER_VISIBLE = 711242136, -- CMND_SET_LAYER_VISIBLE
  MESH_VISIBLE = 3405944500, -- CMND_SET_MESH_VISIBLE
  SET_SPRITE = 558735651,    -- layer sprite swap (layer, atlas, sprite, dummy sprite, ?, instance)
  ATTACH_CLEAR = 4233535095,
  ATTACH_ROW = 1774843228,
  FOCUS_COUNT = 3252599449,
  FOCUSED = 2603265800,
  FOCUS_SET = 1778826357,    -- the tab bar's focus (OnOpenLayer of the tab item: the saved tab)
  SET_TEMP_BYTE = 667984508, -- CMND_SET_TEMP_BYTE_FLAG
  SAVED_TAB = 3683890655,    -- the temp byte the screen keeps its tab in
  TAB_ITEM = 4044286600,     -- cmn06_20_list_tab_item
  ATTACH = 1887158505,       -- cmn06_01_list_tab_attach
  BAR_ATLAS = 3062127414,    -- #/menu/20_cmn/cmn06/cmn06_01/cmn06_01.g4tx
  BAR_MESH = 2452509419,     -- list_tab_base01
  DMY_ON = 3229351341,       -- icon_list_tab_dmy01_on
  DMY_OFF = 380437824,       -- icon_list_tab_dmy01_off
  ICON_BASE = 4013273506,    -- _icon_base01
  TEXT_MESH = 3029561990,    -- _text_list_tab01
  RETAIL = 9,
  tabs = nil,                -- {{index, id, text, series, atlas, icon, off, itype}, ...} read once (first callback)
  logs = 0,
}

local function FMT_Log(...)
  if FMT.logs >= 20 then
    return
  end
  FMT.logs = FMT.logs + 1
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  pcall(funcLuaCommand, FMT.LOG, "VRFW fm_tabs " .. table.concat(parts, " "))
end

-- the extra tabs the DLL serves (cached), then the mods' count hooks (e.g. a mode that shows fewer)
local function FMT_All()
  if FMT.tabs ~= nil then
    return FMT.tabs
  end
  FMT.tabs = {}
  local ok, n = pcall(funcLuaCommand, FMT.TABS)
  if not ok or type(n) ~= "number" then
    return FMT.tabs
  end
  for i = 1, n do
    local r = table.pack(pcall(funcLuaCommand, FMT.TAB, i))
    if r[1] and type(r[2]) == "number" then
      FMT.tabs[#FMT.tabs + 1] = {index = r[2], id = r[3], text = r[4], series = r[5], atlas = r[6], icon = r[7],
        off = r[8], itype = r[9]}
    else
      break
    end
  end
  FMT_Log("tabs", #FMT.tabs)
  return FMT.tabs
end

local function FMT_Count()
  local n = #FMT_All()
  for _, h in pairs(VRFW_FMT_HOOKS) do
    if type(h) == "table" and type(h.count) == "function" then
      local ok, m = pcall(h.count, n, FMT.tabs)
      if ok and type(m) == "number" and m >= 0 and m < n then
        n = m
      end
    end
  end
  return n
end

local function FMT_Tab(index)
  for _, t in ipairs(FMT_All()) do
    if t.index == index then
      return t
    end
  end
  return nil
end

-- the tab index of extra tab `id` (nil: not declared / no framework DLL); for mods (call it inside a callback)
function VRFW_FMT_Index(id)
  for _, t in ipairs(FMT_All()) do
    if t.id == id then
      return t.index
    end
  end
  return nil
end

-- attach set and bar for `total` tabs (the retail script asked for 9)
local function FMT_Bar(orig, total, layer)
  if total <= FMT.RETAIL then
    return orig(total, layer)
  end
  if total == FMT.RETAIL + 1 then
    orig(total, layer)                            -- the retail 10-tab set, as the spirit list's
    LISTVIEW.SetBgTextureListTab(4, layer)         -- the retail 10-tab bar
    return
  end
  local r = table.pack(pcall(funcLuaCommand, FMT.BAR, total))
  if not r[1] or type(r[2]) ~= "number" or r.n < 2 + total then
    FMT_Log("no bar layout for", total)
    orig(FMT.RETAIL + 1, layer)
    LISTVIEW.SetBgTextureListTab(4, layer)
    return
  end
  funcLuaMenuCommand(FMT.ATTACH_CLEAR, layer, 0, false)
  for i = 1, total do
    funcLuaMenuCommand(FMT.ATTACH_ROW, layer, 0, r[2 + i], true)
  end
  LISTVIEW.SetBgTextureListTab(4, layer)
  if r[2] ~= 0 then
    funcLuaMenuCommand(FMT.SET_SPRITE, layer, FMT.BAR_ATLAS, r[2], FMT.BAR_MESH, 0, 0)
  end
end

local function FMT_Icon(orig, a1, a2, ...)
  if type(a2) ~= "number" or a2 < FMT.RETAIL then
    return orig(a1, a2, ...)
  end
  local t = FMT_Tab(a2)
  if t == nil or a2 >= FMT.RETAIL + FMT_Count() then
    funcLuaMenuCommand(FMT.LAYER_VISIBLE, a1, a2, false)
    return
  end
  if t.icon == 0 and type(t.itype) == "number" and t.itype >= 0 then
    return orig(a1, a2, t.itype, true)
  end
  if t.icon ~= 0 then
    funcLuaMenuCommand(FMT.SET_SPRITE, a1, t.atlas, t.icon, FMT.DMY_ON, 0, a2)
    funcLuaMenuCommand(FMT.SET_SPRITE, a1, t.atlas, t.off, FMT.DMY_OFF, 0, a2)
    funcLuaMenuCommand(FMT.MESH_VISIBLE, a1, FMT.ICON_BASE, true, a2)
  end
end

local function FMT_Name(t)
  local name = nil
  if t.series ~= 0 then
    local ok, okc, s = pcall(funcLuaMenuCommand, FMT.SERIES_INFO, 1, t.series)
    if ok and okc then
      name = s
    end
  end
  if (type(name) ~= "string" or name == "") and t.text ~= 0 then
    local ok, s = pcall(funcLuaCommand, FMT.TEXT_GET, t.text)
    if ok then
      name = s
    end
  end
  if type(name) ~= "string" then
    name = ""
  end
  for _, h in pairs(VRFW_FMT_HOOKS) do
    if type(h) == "table" and type(h.text) == "function" then
      local ok, s = pcall(h.text, t.id, name)
      if ok and type(s) == "string" then
        name = s
      end
    end
  end
  return name
end

-- run `fn` with LISTVIEW[key] replaced by `wrap(orig, ...)`, restored afterwards (also on error)
local function FMT_With(key, wrap, fn, ...)
  local orig = LISTVIEW[key]
  LISTVIEW[key] = function(...)
    return wrap(orig, ...)
  end
  local r = table.pack(pcall(fn, ...))
  LISTVIEW[key] = orig
  if not r[1] then
    error(r[2], 0)
  end
  return table.unpack(r, 2, r.n)
end

if VRFW_Host ~= nil then
  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnOpenLayer", {
    id = "menu_engine.free_match_tabs", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= FMT.TAB_ITEM then
        return nxt(a1, ...)
      end
      local total = FMT.RETAIL + FMT_Count()
      local cmd = funcLuaMenuCommand
      funcLuaMenuCommand = function(id, b1, b2, ...)
        if id == FMT.FOCUS_SET and b1 == FMT.TAB_ITEM and type(b2) == "number" and b2 >= total then
          FMT_Log("saved tab", b2, "-> 0")     -- a tab this bar does not have (a mod switched off, the office)
          pcall(funcLuaCommand, FMT.SET_TEMP_BYTE, FMT.SAVED_TAB, 0)
          b2 = 0
        end
        return cmd(id, b1, b2, ...)
      end
      local r = table.pack(pcall(nxt, a1, ...))
      funcLuaMenuCommand = cmd
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnSetupLayer", {
    id = "menu_engine.free_match_tabs", phase = "around",
    fn = function(nxt, a1, a2, ...)
      if a1 ~= FMT.TAB_ITEM or LISTVIEW == nil or LISTVIEW.UpdateAttachTabNum == nil then
        return nxt(a1, a2, ...)
      end
      local total = FMT.RETAIL + FMT_Count()
      local cmd = funcLuaMenuCommand
      if a2 == 0 and total > FMT.RETAIL then
        funcLuaMenuCommand = function(id, b1, b2, ...)
          if id == FMT.FOCUS_COUNT and b1 == FMT.TAB_ITEM and b2 == FMT.RETAIL then
            b2 = total
          end
          return cmd(id, b1, b2, ...)
        end
        FMT_Log("tab bar", total)
      end
      local r = table.pack(pcall(FMT_With, "UpdateAttachTabNum",
        function(orig, k, layer, ...)
          if k == FMT.RETAIL and layer == FMT.ATTACH then
            return FMT_Bar(orig, total, layer)
          end
          return orig(k, layer, ...)
        end,
        FMT_With, "SetupTabIcon", FMT_Icon, nxt, a1, a2, ...))
      funcLuaMenuCommand = cmd
      if not r[1] then
        error(r[2], 0)
      end
      return table.unpack(r, 2, r.n)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", {
    id = "menu_engine.free_match_tabs", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= FMT.TAB_ITEM or LISTVIEW == nil or LISTVIEW.SetupTabText == nil then
        return nxt(a1, ...)
      end
      local okf, tab = pcall(funcLuaMenuCommand, FMT.FOCUSED, a1)
      local t = okf and type(tab) == "number" and tab >= FMT.RETAIL and FMT_Tab(tab) or nil
      if t == nil then
        return nxt(a1, ...)
      end
      return FMT_With("SetupTabText", function(orig, _, layer)
        funcLuaMenuCommand(FMT.SET_TEXT, layer, FMT.TEXT_MESH, FMT_Name(t))
      end, nxt, a1, ...)
    end,
  })
end
