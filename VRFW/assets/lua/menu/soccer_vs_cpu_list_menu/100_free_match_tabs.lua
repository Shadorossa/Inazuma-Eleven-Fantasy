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
-- * Section pages (docs/framework/team-sections.md): when the kept tabs fill more than one page of the bar, L2 / R2
--   (OnFunction vrfw_fm_section_page_prev / _next) turn the page, the bar shows that page's tabs, the saved tab byte
--   holds the tab index (not the slot), and the L2 / R2 glyphs sit at the bar's two ends (placed in Step only until the
--   bar stops moving). One page = everything above, unchanged.
-- No engine call at load time.

VRFW_FMT_HOOKS = VRFW_FMT_HOOKS or {}

local FMT = {
  TABS = VRFW_Cmd.VRFW_FM_TABS,         -- CMND_VRFW_FM_TABS () -> extra, total
  TAB = VRFW_Cmd.VRFW_FM_TAB,          -- CMND_VRFW_FM_TAB (i) -> index, id, text, series, atlas, icon, icon_off, icon_type
  BAR = VRFW_Cmd.VRFW_FM_BAR,          -- CMND_VRFW_FM_BAR (total) -> bar sprite, attach rows...
  LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
  TEXT_GET = VRFW_Cmd.TEXT_GET,     -- CMND_TEXT_GET
  SERIES_INFO = VRFW_Cmd.GET_CHARA_SERIES_INFO,   -- CMND_GET_CHARA_SERIES_INFO
  SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,     -- CMND_SET_MENU_TEXT_STRING
  LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE, -- CMND_SET_LAYER_VISIBLE
  MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE, -- CMND_SET_MESH_VISIBLE
  SET_SPRITE = 558735651,    -- layer sprite swap (layer, atlas, sprite, dummy sprite, ?, instance)
  ATTACH_CLEAR = 4233535095,
  ATTACH_ROW = VRFW_Cmd.SET_LAYER_ATTACH_LOCATOR_TRACE,
  FOCUS_COUNT = 3252599449,
  FOCUSED = 2603265800,
  FOCUS_SET = 1778826357,    -- the tab bar's focus (OnOpenLayer of the tab item: the saved tab)
  SET_TEMP_BYTE = VRFW_Cmd.SET_TEMP_BYTE_FLAG, -- CMND_SET_TEMP_BYTE_FLAG
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
  INSTANCES = 12,            -- tab instances the framework's menus\free_match_tabs.toml gives the screen
  SECTION_PREV = 1023782679, -- CMD_FUNCTION vrfw_fm_section_page_prev (L2 row of menus\free_match_tabs.toml)
  SECTION_NEXT = 2244491134, -- CMD_FUNCTION vrfw_fm_section_page_next (R2 row)
  SECTION_SLOTS = VRFW_Cmd.VRFW_FM_SECTION_SLOTS, -- CMND_VRFW_FM_SECTION_SLOTS (index of slot 0, ...) -> live
  KEYS = 2626711995,         -- vrfw_fm_section_keys (2 x team00_40_change_page_guide)
  KEY_TEXT = 378156699,      -- _text_guide01
  KEY_BUTTON = 950238781,    -- _text_btn01
  KEY_PLATE_BASE = 3491851413, -- _win_guide_base01
  KEY_LEFT = "<CMD_FUNCL2>", KEY_RIGHT = "<CMD_FUNCR2>",   -- the engine draws the bound button of the device in use
  KEY_TEXT_CX = 102,         -- the change-page plate is right-anchored: its glyph's centre from the plate's origin
  KEY_PRIORITY = 700,
  KEY_TRIES = 300,           -- Step calls the glyph placement waits for the layer at most
  EXIST = VRFW_Cmd.IS_EXIST_LAYER,
  OPEN = VRFW_Cmd.OPEN_LAYER,
  IS_OPEN = VRFW_Cmd.IS_OPEN_LAYER,
  LOADING = VRFW_Cmd.IS_LOADING_LAYER,
  MESH_POS = VRFW_Cmd.GET_MESH_GLOBAL_POSITION, -- (layer, instance, mesh) -> x, y (screen px, y up)
  LOCAL_POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,      -- (layer, x, y, z, instance)
  PRIORITY = VRFW_Cmd.SET_DRAW_PRIORITY,         -- (layer, instance, priority, children)
  TEXT_PLATE = VRFW_Cmd.UPDATE_TEXT_PLATE,       -- (layer, instance, text node)
  page = nil,                -- the shown page (nil / 1 = the retail page)
  focus_pending = false,
  retail_icon = {},          -- slot -> the retail SetupTabIcon call of that instance (to show page 1 again)
  keys = { opened = false, pending = false, tries = 0, set = false },
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
        off = r[8], itype = r[9], page = type(r[10]) == "number" and r[10] or 1, slot = type(r[11]) == "number" and r[11] or r[2]}
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

-- a kept tab by its tab index
local function FMT_Tab(index)
  local all = FMT_All()
  for k = 1, FMT_Count() do
    if all[k] ~= nil and all[k].index == index then
      return all[k]
    end
  end
  return nil
end

-- tabs on page 1 of the bar: the retail ones + the kept extra tabs of page 1
local function FMT_Page1Total()
  local n = FMT.RETAIL
  local all = FMT_All()
  for k = 1, FMT_Count() do
    if all[k] ~= nil and (all[k].page or 1) <= 1 then
      n = n + 1
    end
  end
  return n
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

-- instance `inst` of `layer` shows tab t's icon (its sprite pair, or a retail icon type through `setup`)
local function FMT_SetIcon(layer, inst, t, setup)
  if t == nil then
    return
  end
  if t.icon == 0 and type(t.itype) == "number" and t.itype >= 0 then
    return setup(layer, inst, t.itype, true)
  end
  if t.icon ~= 0 then
    funcLuaMenuCommand(FMT.SET_SPRITE, layer, t.atlas, t.icon, FMT.DMY_ON, 0, inst)
    funcLuaMenuCommand(FMT.SET_SPRITE, layer, t.atlas, t.off, FMT.DMY_OFF, 0, inst)
    funcLuaMenuCommand(FMT.MESH_VISIBLE, layer, FMT.ICON_BASE, true, inst)
  end
end

local function FMT_Icon(orig, a1, a2, ...)
  if type(a2) ~= "number" or a2 < FMT.RETAIL then
    if type(a2) == "number" and a1 == FMT.TAB_ITEM then
      FMT.retail_icon[a2] = table.pack(a1, a2, ...)
    end
    return orig(a1, a2, ...)
  end
  local t = FMT_Tab(a2)
  if t == nil or a2 >= FMT_Page1Total() then
    funcLuaMenuCommand(FMT.LAYER_VISIBLE, a1, a2, false)
    return
  end
  return FMT_SetIcon(a1, a2, t, orig)
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

-- ---------------------------------------------------------------------------------------------- section pages
-- docs/framework/team-sections.md: the sections (the retail tabs + the mods' tabs) in pages of the bar. Page 1 = the
-- retail tabs + the first extra tabs (as above); a later page shows only its own tabs in the same bar layout, its
-- empty slots hidden. L2 / R2 (the menu patch's CMD_FUNCTION rows) turn the page; Z / C stay within the page. The
-- list builds the tab index of the shown slot through the native answer of CMND_VRFW_FM_SECTION_SLOTS. Nothing of
-- this runs while every kept tab is on page 1.

-- the kept tabs (first FMT_Count of them) on page p, in slot order
local function FMT_PageTabs(p)
  local out = {}
  local all = FMT_All()
  for k = 1, FMT_Count() do
    local t = all[k]
    if t ~= nil and (t.page or 1) == p then
      out[#out + 1] = t
    end
  end
  table.sort(out, function(a, b) return (a.slot or a.index) < (b.slot or b.index) end)
  return out
end

-- pages of the bar (1 = everything on the retail page)
local function FMT_Pages()
  local n = 1
  local all = FMT_All()
  for k = 1, FMT_Count() do
    local t = all[k]
    if t ~= nil and (t.page or 1) > n then
      n = t.page
    end
  end
  return n
end

-- the tab index bar slot `slot` stands for on the shown page
local function FMT_SlotIndex(slot)
  if (FMT.page or 1) <= 1 or type(slot) ~= "number" then
    return slot
  end
  local t = FMT_PageTabs(FMT.page)[slot + 1]
  return t ~= nil and t.index or slot
end

-- instance `slot` shows its tab's icon on the shown page (retail tabs: the retail call recorded at set-up)
local function FMT_ApplySlot(slot)
  local p = FMT.page or 1
  if p <= 1 then
    if slot < FMT.RETAIL then
      local call = FMT.retail_icon[slot]
      if call ~= nil then
        LISTVIEW.SetupTabIcon(table.unpack(call, 1, call.n))
      end
    else
      FMT_SetIcon(FMT.TAB_ITEM, slot, FMT_Tab(slot), LISTVIEW.SetupTabIcon)
    end
    return
  end
  local t = FMT_PageTabs(p)[slot + 1]
  if t ~= nil then
    FMT_SetIcon(FMT.TAB_ITEM, slot, t, LISTVIEW.SetupTabIcon)
  end
end

-- show page p: instances, icons, focus count, and the slots the native list answer maps
local function FMT_ShowPage(p)
  FMT.page = p
  local list = p > 1 and FMT_PageTabs(p) or nil
  local n = list ~= nil and #list or FMT_Page1Total()
  for slot = 0, FMT.INSTANCES - 1 do
    local shown = slot < n
    funcLuaMenuCommand(FMT.LAYER_VISIBLE, FMT.TAB_ITEM, slot, shown)
    if shown then
      FMT_ApplySlot(slot)
    end
  end
  funcLuaMenuCommand(FMT.FOCUS_COUNT, FMT.TAB_ITEM, n)
  local index = {}
  for k, t in ipairs(list or {}) do
    index[k] = t.index
  end
  pcall(funcLuaCommand, FMT.SECTION_SLOTS, table.unpack(index))
  FMT_Log("page", p, "of", FMT_Pages(), "slots", n)
end

-- the bar's focus on `slot`; the list is rebuilt by the retail OnChangeFocus (called here when the engine does not
-- call it for a focus it already had)
local function FMT_Focus(slot)
  FMT.focus_pending = true
  funcLuaMenuCommand(FMT.FOCUS_SET, FMT.TAB_ITEM, slot)
  if FMT.focus_pending and type(OnChangeFocus) == "function" then
    OnChangeFocus(FMT.TAB_ITEM, slot)
  end
end

-- the L2 / R2 glyphs at the bar's two ends (two copies of the change-page plate, only the key glyph shown), placed
-- from the tab icons' own screen positions: one icon pitch left of the first and right of the last
local function FMT_Mesh(...)
  local ok, x, y = pcall(funcLuaMenuCommand, FMT.MESH_POS, ...)
  if ok and type(x) == "number" and type(y) == "number" and (x ~= 0 or y ~= 0) then
    return x, y
  end
  return nil
end

local function FMT_PlaceKeys()
  local K = FMT.keys
  K.tries = K.tries + 1
  if K.tries > FMT.KEY_TRIES then
    K.pending = false
    FMT_Log("page keys not placed")
    return
  end
  for i = 0, 1 do
    local ok, open = pcall(funcLuaMenuCommand, FMT.IS_OPEN, FMT.KEYS, i)
    if not ok or open ~= true then
      return
    end
  end
  local okl, loading = pcall(funcLuaMenuCommand, FMT.LOADING, FMT.KEYS)
  if okl and loading == true then
    return
  end
  local last = FMT_Page1Total() - 1
  local x0, y0 = FMT_Mesh(FMT.TAB_ITEM, 0, FMT.ICON_BASE)
  local x1 = FMT_Mesh(FMT.TAB_ITEM, 1, FMT.ICON_BASE)
  local xl = FMT_Mesh(FMT.TAB_ITEM, last, FMT.ICON_BASE)
  if x0 == nil or x1 == nil or xl == nil then
    return
  end
  local pitch = x1 - x0
  local at = { x0 - pitch, xl + pitch }
  if K.at ~= nil and math.abs(K.at[1] - at[1]) < 0.5 and math.abs(K.at[2] - at[2]) < 0.5 and math.abs(K.y - y0) < 0.5 then
    K.pending = false          -- the bar stopped moving (its open animation is over)
    return
  end
  K.at, K.y = at, y0
  for i = 0, 1 do
    if not K.set then
      funcLuaMenuCommand(FMT.LAYER_VISIBLE, FMT.KEYS, i, true)
      funcLuaMenuCommand(FMT.MESH_VISIBLE, FMT.KEYS, FMT.KEY_PLATE_BASE, false, i)
      funcLuaMenuCommand(FMT.SET_TEXT, FMT.KEYS, FMT.KEY_BUTTON, "", i)
      funcLuaMenuCommand(FMT.SET_TEXT, FMT.KEYS, FMT.KEY_TEXT, i == 0 and FMT.KEY_LEFT or FMT.KEY_RIGHT, i)
      funcLuaMenuCommand(FMT.TEXT_PLATE, FMT.KEYS, i, FMT.KEY_TEXT)
      funcLuaMenuCommand(FMT.PRIORITY, FMT.KEYS, i, FMT.KEY_PRIORITY, true)
    end
    -- the plate is right-anchored: its glyph sits KEY_TEXT_CX right of the plate's origin
    funcLuaMenuCommand(FMT.LOCAL_POS, FMT.KEYS, at[i + 1] + FMT.KEY_TEXT_CX, y0, 0, i)
  end
  if not K.set then
    K.set = true
    FMT_Log("page keys at", math.floor(at[1]), math.floor(at[2]), math.floor(y0))
  end
end

local function FMT_OpenKeys()
  local K = FMT.keys
  if K.opened then
    return
  end
  K.opened = true
  local ok, exist = pcall(funcLuaMenuCommand, FMT.EXIST, FMT.KEYS)
  if not ok or exist ~= true then
    FMT_Log("no page key layer")
    return
  end
  for i = 0, 1 do
    pcall(funcLuaMenuCommand, FMT.OPEN, FMT.KEYS, i)
  end
  K.pending, K.tries = true, 0
end

if VRFW_Host ~= nil then
  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnInit", {
    id = "menu_engine.free_match_tabs", phase = "before",
    fn = function()
      FMT.page, FMT.focus_pending = nil, false
      FMT.keys = { opened = false, pending = false, tries = 0, set = false }
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnOpenLayer", {
    id = "menu_engine.free_match_tabs", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= FMT.TAB_ITEM then
        return nxt(a1, ...)
      end
      local total = FMT_Page1Total()
      local pages = FMT_Pages()
      local cmd = funcLuaMenuCommand
      funcLuaMenuCommand = function(id, b1, b2, ...)
        if id == FMT.FOCUS_SET and b1 == FMT.TAB_ITEM and type(b2) == "number" and b2 >= total then
          -- the saved byte holds a tab index: its page and slot, else a tab this bar does not have (a mod switched
          -- off, the office) opens the first tab
          local t = pages > 1 and FMT_Tab(b2) or nil
          if t ~= nil and (t.page or 1) > 1 then
            if FMT.page ~= t.page then
              FMT_ShowPage(t.page)       -- its calls pass through this wrapper unchanged (no FOCUS_SET)
            end
            b2 = t.slot
          else
            FMT_Log("saved tab", b2, "-> 0")
            pcall(funcLuaCommand, FMT.SET_TEMP_BYTE, FMT.SAVED_TAB, 0)
            b2 = 0
          end
        end
        return cmd(id, b1, b2, ...)
      end
      local r = table.pack(pcall(nxt, a1, ...))
      funcLuaMenuCommand = cmd
      if pages > 1 then
        FMT_OpenKeys()
      end
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
      local total = FMT_Page1Total()
      local cmd = funcLuaMenuCommand
      if a2 == 0 and total > FMT.RETAIL then
        funcLuaMenuCommand = function(id, b1, b2, ...)
          if id == FMT.FOCUS_COUNT and b1 == FMT.TAB_ITEM and b2 == FMT.RETAIL then
            b2 = total
          end
          return cmd(id, b1, b2, ...)
        end
        FMT_Log("tab bar", total, "pages", FMT_Pages())
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
      -- an instance set up while a later page is shown keeps that page's look
      if (FMT.page or 1) > 1 and type(a2) == "number" then
        local list = FMT_PageTabs(FMT.page)
        funcLuaMenuCommand(FMT.LAYER_VISIBLE, a1, a2, a2 < #list)
        if a2 < #list then
          FMT_ApplySlot(a2)
        end
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
      FMT.focus_pending = false
      local okf, slot = pcall(funcLuaMenuCommand, FMT.FOCUSED, a1)
      local index = okf and FMT_SlotIndex(slot) or nil
      local t = type(index) == "number" and index >= FMT.RETAIL and FMT_Tab(index) or nil
      local r
      if t == nil then
        r = table.pack(nxt(a1, ...))
      else
        r = table.pack(FMT_With("SetupTabText", function(orig, _, layer)
          funcLuaMenuCommand(FMT.SET_TEXT, layer, FMT.TEXT_MESH, FMT_Name(t))
        end, nxt, a1, ...))
      end
      -- on a later page the saved byte holds the tab index (the retail code saved the slot)
      if (FMT.page or 1) > 1 and type(index) == "number" then
        pcall(funcLuaCommand, FMT.SET_TEMP_BYTE, FMT.SAVED_TAB, index)
      end
      return table.unpack(r, 1, r.n)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnFunction", {
    id = "menu_engine.free_match_tabs", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= FMT.SECTION_PREV and a1 ~= FMT.SECTION_NEXT then
        return nxt(a1, ...)
      end
      local pages = FMT_Pages()
      if pages <= 1 then
        return
      end
      local step = a1 == FMT.SECTION_NEXT and 1 or -1
      FMT_ShowPage(((FMT.page or 1) - 1 + step) % pages + 1)
      FMT_Focus(0)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "Step", {
    id = "menu_engine.free_match_tabs", phase = "after",
    fn = function()
      if FMT.keys.pending then
        FMT_PlaceKeys()
      end
    end,
  })
end
