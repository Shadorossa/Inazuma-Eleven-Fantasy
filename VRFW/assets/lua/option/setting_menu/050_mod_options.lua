-- mod_options (VR-Framework): the «Opciones de mods» / "Mod options" tab of Opciones › Ajustes (setting_menu), to the
-- right of the graphics tab, and the ONLY copy of the VRFW_SET / VRFW_OPT row framework.
-- Own-written handlers of the framework's setting_menu host (VRFW_Host, menu part's lua/setting_menu/000_host.lua), each passing on to the retail globals; nothing of the retail chunk is copied. Nothing
-- runs at chunk load but table setup: every engine call happens inside the engine's callbacks.
--
-- * The tab: the plugin (mod_options.dll) serves the data at boot (the mod rows in engine tab 0 after its retail rows,
--   a 5th tab item) and hooks the settings menu so the strip has 5 tabs and the 5th shows only the mod rows. This Lua
--   draws the 5th tab (retail tab item, retail icon type 13 = icon_list_tab_key01, title «Opciones de mods» from
--   menu_text) and tells the plugin its strip index (CMND_VRFW_OPTION_TAB). No mod rows = no tab (hidden).
-- * The rows (setting type 40, the Lua-driven «FPS máximos» kind): the engine lists them (UpdateListItem gives the
--   label; CMND_VRFW_OPTION_CELL gives the row key), left / right / A change a DRAFT, the retail «¿Aplicar los cambios?»
--   window stores the drafts on «Sí» and drops them on «No» (IsChangedGraphicSetting / callBackSaveCheckDialog).
--   Rows declared in an options.toml (toggle / list / number) are built here from the plugin's answers; rows with
--   custom behaviour (type = "lua") are given by their mod: VRFW_OPT_Register("<mod>.<id>", {get, step, fmt, set[, off]}).
--   A row of the mod tab nobody drives shows «No disponible» and never reaches the retail FPS code.
-- * Registering a row from another mod's patch: the host's named list (any load order; registered at the menu's first
--   callback):
--     VRFW_Host.add("setting_menu", "option_rows", {id = key, value = row})
--   The older ways still work: VRFW_OPT_Register(key, row) when it exists, else VRFW_OPT_QUEUE (drained below):
--     if VRFW_OPT_Register then VRFW_OPT_Register(key, row)
--     else VRFW_OPT_QUEUE = VRFW_OPT_QUEUE or {}; VRFW_OPT_QUEUE[#VRFW_OPT_QUEUE + 1] = {key = key, row = row} end
--   The old label API VRFW_SET_Register(label, row) still works. A framework loaded before this one (an old Inazuma
--   Fantasy build left in evt_loader\lua_patches) is replaced; its rows are adopted, so nothing is doubled.
-- * Preview: a list row whose CURRENT value (draft or stored) declares `preview` shows
--   «  ▶» after its name; Select / Tab (CMD_FUNC2, polled in Step: the retail menu binds no FUNC2) or a mouse click on
--   the name side of the row (left of the ◀ arrow) plays it, «  ■» while it plays, the same key / click again stops it.
--   Retail BGM-preview path (enjoy_team_select_menu's stadium music list): CMND_BGM_PAUSE pauses the music the menu
--   inherited (title or main menu), CMND_SND_PLAY(<bgm id>) plays the track, CMND_SND_STOP + CMND_BGM_RESUME bring the
--   menu's own music back. Stopped when another preview starts, the row's value changes, the tab is left, the drafts
--   are applied / dropped, or the menu closes.
-- * «Llaves»: a row declared with `parent = "<row key>"` is a CHILD row: drawn with the
--   retail child-row look of the Sound tab's «Música» group (the list item's _pos_summary02 part: └ + inset plate,
--   label in _text_option_list04, as the retail UpdateListContentCustomText draws it) right below its parent. While
--   the parent's value (its draft, else the stored one) is 0 the child is greyed at its real value and refuses changes
--   (the retail disabled flag of those rows: alpha 0.5); a change of the parent redraws its children at once.

-- (a 1.x framework named them EVT_SET_ROWS / EVT_SET_ORDER)
local VRFW_OPT_LEGACY_ROWS, VRFW_OPT_LEGACY_ORDER = VRFW_SET_ROWS or EVT_SET_ROWS, VRFW_SET_ORDER or EVT_SET_ORDER

VRFW_OPT_VERSION = 1
VRFW_SET_ROWS = {}                      -- row id (row key "<mod>.<id>", or a label of the old API) -> {get, step, fmt, set, off}
VRFW_SET_ORDER = {}                     -- row ids in registration order
VRFW_SET_DRAFT = {}                     -- row id -> pending value while the menu is open
VRFW_SET_LABELS = {}                    -- list cell -> label text (UpdateListItem)
VRFW_SET_LAST_OK = true                 -- last change accepted (PlayUpdateContentSound plays sy0003 when false)
VRFW_OPT_CELLS = {}                     -- list cell -> row key of the mod tab (label text, else plugin), nil = not a mod row
VRFW_OPT_LABEL_KEYS = {}                -- label text -> row key (declared rows)
VRFW_OPT_LABEL_DUP = {}                 -- label text -> true: two declared rows show this text (the label cannot tell them apart)
VRFW_OPT_LOADED = false                 -- declared rows fetched from the plugin
VRFW_OPT_GATED = {}                     -- row key -> true: available only while an [[extend]] value is chosen (enabled_if)
VRFW_OPT_FIXED = {}                     -- row key -> value: disabled (enabled_if = "languages:…" and no enabled mod declares one)
VRFW_OPT_PARENT = {}                    -- row key -> key of its parent row (`parent`: a child row of a «llave»)
VRFW_OPT_HAS_CHILD = {}                 -- row key -> true: some row names it as its parent
VRFW_OPT_TAB_IDX = nil                  -- strip index of the mod tab for this opening (false = no tab)
VRFW_OPT_C = {                          -- crc32 of the plugin's commands (CMND_VRFW_OPTION_*; the CMND_EVT_OPT_* aliases log a deprecation)
  TAB = 2106271505, VIEW = 2795212795, CELL = 2481038231, ROWS = 1391317204, ROW = 2321060550,
  GET = 4082322029, SET = 3900457409, STEP = 467655241, TEXT = 1676510130
}
VRFW_OPT_TITLE_ID = 2653374959          -- crc32("mod_options.tab_title")
VRFW_OPT_UNAVAILABLE_ID = 516770612     -- crc32("mod_options.unavailable")
VRFW_OPT_ICON = 13                      -- LISTVIEW.SetupTabIcon type 13 = icon_list_tab_key01 (retail sprite)
VRFW_OPT_PV = {handle = 0, key = nil, paused = false, frame = 0, key_down = false, input = true}
VRFW_OPT_PV_HAS = {}                    -- row key -> true / false: some value of the row has a preview
VRFW_OPT_PV_C = {
  PREVIEW = 673309330,                 -- crc32("CMND_VRFW_OPTION_PREVIEW"): (key, value, lang) -> bgm id | false; (key) -> any?
  LANG = 477234096,                    -- CMND_GET_LANGUAGE_CODE (retail)
  SND_PLAY = 3073642526, SND_STOP = 1357633554, SND_PLAYING = 1372088528,
  BGM_PAUSE = 214589648, BGM_RESUME = 52227211,
  CHECK_INPUT = 4265778440, MENU_CTRL = 1332654303,
  KEY = 3170216173,                    -- CMD_FUNC2: pad Select / View / touch pad, keyboard Tab
  CLICK = 1651523701,                  -- CMD_ENTER_CLICK (left mouse button, but also Enter / A)
  LEFT = 218912913,                    -- CMD_EVT_MOUSE_LEFT (the left mouse button alone; an input of the mod)
  ENTER = 1981080283,                  -- CMD_ENTER (Enter / A, never the mouse)
  POINTER = 558229292,                 -- funcLuaMenuCommand () -> mouse x, y
  MESH_POS = 499270986,                -- CMND_GET_MESH_GLOBAL_POSITION(layer, idx, node) -> x, y, z
  PLAY_MARK = "  ▶", STOP_MARK = "  ■"     -- UTF-8 literals (Lua 5.2 has no \u escape)
}

function VRFW_SET_Call(cmd, ...)        -- a loader / plugin command; nil when it is not there
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end
function VRFW_OPT_Text(id, fallback)    -- menu_text row in the game's language, else the fallback
  if type(id) == "number" and id ~= 0 then
    local ok, s = pcall(funcLuaCommand, 4074371074 --[[CMND_TEXT_GET]], id)
    if ok and type(s) == "string" and s ~= "" then
      return s
    end
  end
  return fallback
end
function VRFW_OPT_Register(key, row)    -- a row of an options.toml by its key (type lua, or to replace a declared one)
  if VRFW_SET_ROWS[key] == nil then
    VRFW_SET_ORDER[#VRFW_SET_ORDER + 1] = key
  end
  VRFW_SET_ROWS[key] = row
end
function VRFW_SET_Register(label, row)  -- old API: a row recognised by its label text
  VRFW_OPT_Register(label, row)
end
function VRFW_OPT_Declared(key, storage, get_cmd, set_cmd) -- a toggle / list / number row of an options.toml
  local row = {}
  function row.get()
    if storage == "command" then
      local v, extra = VRFW_SET_Call(get_cmd)
      if type(v) == "number" then
        return v
      end
      if type(v) == "boolean" and (v or extra ~= nil) then -- a lone false = module off
        if v then
          return 1
        end
        return 0
      end
      return nil
    end
    local v, dv = VRFW_SET_Call(VRFW_OPT_C.GET, key, "stored") -- the stored value whatever a parent says (greyed here)
    row.dimmed = nil
    if type(v) == "number" then
      return v
    end
    if v == false and type(dv) == "number" then -- enabled_if not met: its value, greyed, no changes
      row.dimmed = dv
    end
    return nil
  end
  function row.step(v, dir)
    local n = VRFW_SET_Call(VRFW_OPT_C.STEP, key, v, dir)
    if type(n) == "number" then
      return n
    end
    return v
  end
  function row.fmt(v)
    local id, fb = VRFW_SET_Call(VRFW_OPT_C.TEXT, key, v)
    if type(id) ~= "number" then
      return tostring(v)
    end
    return VRFW_OPT_Text(id, fb)
  end
  function row.set(v)
    if storage == "command" then
      return VRFW_SET_Call(set_cmd, v) == true
    end
    return VRFW_SET_Call(VRFW_OPT_C.SET, key, v) == true
  end
  return row
end
function VRFW_OPT_Load()                -- the declared rows (once, from the plugin; inside a callback)
  if VRFW_OPT_LOADED then
    return
  end
  local n = VRFW_SET_Call(VRFW_OPT_C.ROWS)
  if type(n) ~= "number" then
    return
  end
  VRFW_OPT_LOADED = true
  for i = 1, n do
    local key, kind, storage, label, fallback, get_cmd, set_cmd, gated, fixed, parent = VRFW_SET_Call(VRFW_OPT_C.ROW, i)
    if type(key) == "string" then
      if type(parent) == "string" and parent ~= "" then
        VRFW_OPT_PARENT[key] = parent
        VRFW_OPT_HAS_CHILD[parent] = true
      end
      if gated == true then
        VRFW_OPT_GATED[key] = true
      end
      if type(fixed) == "number" then  -- shown greyed at this value, never changed (any row type, Lua rows too)
        VRFW_OPT_FIXED[key] = fixed
      end
      local text = VRFW_OPT_Text(label, fallback)
      if type(text) == "string" and text ~= "" then
        if VRFW_OPT_LABEL_KEYS[text] ~= nil and VRFW_OPT_LABEL_KEYS[text] ~= key then
          VRFW_OPT_LABEL_DUP[text] = true
        end
        VRFW_OPT_LABEL_KEYS[text] = key
      end
      if kind ~= "lua" and VRFW_SET_ROWS[key] == nil then
        VRFW_OPT_Register(key, VRFW_OPT_Declared(key, storage, get_cmd, set_cmd))
      end
    end
  end
end
function VRFW_OPT_KeyOfLabel(label)    -- row key of a declared row by the label text the engine lists, or nil
  if type(label) ~= "string" then
    return nil
  end
  VRFW_OPT_Load()
  if VRFW_OPT_LABEL_DUP[label] then
    return nil
  end
  return VRFW_OPT_LABEL_KEYS[label]
end
function VRFW_OPT_Tab()                 -- strip index of the mod tab, or false (asked once per opening of the menu)
  if VRFW_OPT_TAB_IDX == nil then
    local n = 4
    local ok, p = pcall(funcLuaCommand, 3472223911 --[[CMND_GET_APP_PLATFORM?]])
    if ok and p == 1 then              -- the retail strip hides the graphics tab there
      n = 3
    end
    if VRFW_SET_Call(VRFW_OPT_C.TAB, n) == true then
      VRFW_OPT_TAB_IDX = n
    else
      VRFW_OPT_TAB_IDX = false
    end
  end
  return VRFW_OPT_TAB_IDX
end
function VRFW_OPT_InView()              -- the mod tab is the one shown
  return VRFW_SET_Call(VRFW_OPT_C.VIEW) == true
end
function VRFW_SET_Label(a1)             -- row id of list cell a1 when a registered row drives it, else nil
  local key = VRFW_OPT_CELLS[a1]
  if key ~= nil and VRFW_SET_ROWS[key] ~= nil then
    return key
  end
  local label = VRFW_SET_LABELS[a1]
  if label == nil then
    return nil
  end
  if VRFW_SET_ROWS[label] ~= nil then
    return label
  end
  VRFW_OPT_Load()
  if key ~= nil and VRFW_SET_ROWS[key] ~= nil then
    return key
  end
  local k = VRFW_OPT_LABEL_KEYS[label]
  if k ~= nil and VRFW_SET_ROWS[k] ~= nil and (key == nil or key == k) then
    return k
  end
  return nil
end
function VRFW_SET_Focused()             -- row id under the list cursor (or nil), cell index
  local ok, idx = pcall(funcLuaMenuCommand, 1727549139, 2081113831)
  if not ok or type(idx) ~= "number" then
    return nil, nil
  end
  return VRFW_SET_Label(idx), idx
end
function VRFW_OPT_IsModCell(a1)         -- a cell of the mod tab (driven or not)
  return VRFW_OPT_CELLS[a1] ~= nil
end
function VRFW_OPT_ParentOff(id)         -- a child row whose parent's value (draft, else stored) is 0
  local p = VRFW_OPT_PARENT[id]
  if p == nil or VRFW_SET_ROWS[p] == nil then
    return false
  end
  local v = VRFW_OPT_Current(p)
  return type(v) == "number" and v == 0
end
function VRFW_SET_Text(id)              -- the draft when there is one, else the stored value; 2nd = greyed
  local row = VRFW_SET_ROWS[id]
  VRFW_OPT_Load()
  if VRFW_OPT_FIXED[id] ~= nil then     -- disabled by its content gate: its off value, greyed
    VRFW_SET_DRAFT[id] = nil
    return row.fmt(VRFW_OPT_FIXED[id]), true
  end
  local cur = row.get()
  if cur ~= nil and VRFW_OPT_ParentOff(id) then -- its parent is off: the real value, greyed (kept, not applied)
    local v = VRFW_SET_DRAFT[id]
    if v == nil then
      v = cur
    end
    return row.fmt(v), true
  end
  if cur == nil then
    if row.dimmed ~= nil then
      return row.fmt(row.dimmed), true
    end
    if row.off ~= nil then
      return row.off()
    end
    return VRFW_OPT_Text(VRFW_OPT_UNAVAILABLE_ID, "-")
  end
  local v = VRFW_SET_DRAFT[id]
  if v == nil then
    v = cur
  end
  return row.fmt(v)
end
function VRFW_SET_Toggle(id, dir)       -- changes the draft only; false = the value cannot be read (loader / module off)
  local row = VRFW_SET_ROWS[id]
  VRFW_OPT_Load()
  if VRFW_OPT_FIXED[id] ~= nil then     -- disabled: never changes
    return false
  end
  if VRFW_OPT_ParentOff(id) then         -- its parent is off: no changes until the parent is on
    return false
  end
  local cur = row.get()
  if cur == nil then
    return false
  end
  local v = VRFW_SET_DRAFT[id]
  if v == nil then
    v = cur
  end
  local new = row.step(v, dir)
  if new ~= v and VRFW_OPT_PV.key == id then -- the previewed value changed: its preview stops
    VRFW_OPT_PreviewStop("value")
  end
  if new == cur then
    VRFW_SET_DRAFT[id] = nil
  else
    VRFW_SET_DRAFT[id] = new
  end
  return true
end
function VRFW_SET_Dirty()               -- a draft differs from its stored value
  for _, id in ipairs(VRFW_SET_ORDER) do
    local v = VRFW_SET_DRAFT[id]
    if v ~= nil then
      local cur = VRFW_SET_ROWS[id].get()
      if cur ~= nil and cur ~= v then
        return true
      end
    end
  end
  return false
end
function VRFW_SET_Commit()              -- «Sí»: every draft -> its storage
  for _, id in ipairs(VRFW_SET_ORDER) do
    local v = VRFW_SET_DRAFT[id]
    if v ~= nil then
      pcall(VRFW_SET_ROWS[id].set, v)
    end
  end
  VRFW_SET_DRAFT = {}
end
function VRFW_OPT_ShowText(a1, s, a3, a4) -- value text + both arrows, the look of the retail «FPS máximos» row
  funcLuaMenuCommand(2158717427, 3344436024, 644932521, false, a1)
  funcLuaMenuCommand(2158717427, 3344436024, 1948393973, false, a1)
  funcLuaMenuCommand(2158717427, 3344436024, 64821773, false, a1)
  funcLuaMenuCommand(2158717427, 3344436024, 4203144987 --[[_pos_arrow01]], true, a1)
  funcLuaMenuCommand(3404096044, 3344436024, a1, 2475420648, true)
  funcLuaMenuCommand(3404096044, 3344436024, a1, 2234738066, true)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 569341911, s, a1)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 2795244008, s, a1)
  if a3 then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], 3344436024, a1, 1203080170, 0, 3627544126)
  elseif a4 then
    funcLuaMenuCommand(3781155141 --[[CMND_PLAY_ANIME_TYPE]], 3344436024, a1, 3183130249, 0, 3627544126)
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], 3344436024, 2475420648, true, a1)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], 3344436024, 2234738066, true, a1)
end
function VRFW_OPT_Dim(a1, alpha)        -- the retail «disabled» look (UpdateListContentText's flag): alpha of the cell texts
  funcLuaMenuCommand(4231609516, 3344436024, a1, 0, alpha)
  for _, t in ipairs({861591609, 3778835256, 569341911, 2795244008, 75769867, 702348360}) do
    funcLuaMenuCommand(1126837159, 3344436024, a1, t, alpha)
  end
end
function VRFW_OPT_ChildLook(a1, label)  -- the retail child row (UpdateListContentCustomText): └ + inset plate, label in list04
  funcLuaMenuCommand(2158717427, 3344436024, 2894095071 --[[_pos_summary01]], false, a1)
  funcLuaMenuCommand(2158717427, 3344436024, 898184037 --[[_pos_summary02]], true, a1)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 861591609 --[[_text_option_list01_on]], "", a1)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 3778835256 --[[_text_option_list01_off]], "", a1)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 75769867 --[[_text_option_list04_on]], label, a1)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 702348360 --[[_text_option_list04_off]], label, a1)
end
function VRFW_OPT_IsChild(id)           -- a child row whose parent is on the tab
  local p = VRFW_OPT_PARENT[id]
  return p ~= nil and VRFW_SET_ROWS[p] ~= nil
end
function VRFW_SET_Show(a1, id, a3, a4)
  local s, dim = VRFW_SET_Text(id)
  VRFW_OPT_ShowText(a1, s, a3, a4)
  local child = VRFW_OPT_IsChild(id)
  if child and type(VRFW_SET_LABELS[a1]) == "string" then
    VRFW_OPT_ChildLook(a1, VRFW_SET_LABELS[a1])
  end
  pcall(VRFW_OPT_Mark, a1, id)
  if VRFW_OPT_GATED[id] or child then
    if dim then
      VRFW_OPT_Dim(a1, 0.5)
    else
      VRFW_OPT_Dim(a1, 1)
    end
  end
  if VRFW_OPT_HAS_CHILD[id] then         -- a parent: its children follow its (draft) value
    VRFW_OPT_RefreshChildren(id)
  end
end
function VRFW_OPT_RefreshChildren(parent) -- redraw the cells showing a child of `parent`
  for cell, _ in pairs(VRFW_SET_LABELS) do
    local ok, k = pcall(VRFW_SET_Label, cell)
    if ok and k ~= nil and k ~= parent and VRFW_OPT_PARENT[k] == parent then
      pcall(VRFW_SET_Show, cell, k, false, false)
    end
  end
end
function VRFW_OPT_RefreshGated()        -- a retail value changed (e.g. «Antialiasing»): redraw the rows that depend on it
  if next(VRFW_OPT_GATED) == nil then
    return
  end
  for cell, label in pairs(VRFW_SET_LABELS) do
    local k = VRFW_OPT_LABEL_KEYS[label]
    if k ~= nil and VRFW_OPT_GATED[k] and VRFW_SET_ROWS[k] ~= nil then
      pcall(VRFW_SET_Show, cell, k, false, false)
    end
  end
end

-- ---- preview of a value (▶) ------------------------------------------------------------------------------------------
function VRFW_OPT_Lang()                -- the game's text language code (the plugin picks the value's `lang` variant)
  local ok, l = pcall(funcLuaCommand, VRFW_OPT_PV_C.LANG)
  if ok and type(l) == "number" then
    return l
  end
  return nil
end
function VRFW_OPT_HasPreview(key)       -- some value of the row declares a preview (asked once per key)
  local h = VRFW_OPT_PV_HAS[key]
  if h == nil then
    h = VRFW_SET_Call(VRFW_OPT_PV_C.PREVIEW, key) == true
    VRFW_OPT_PV_HAS[key] = h
  end
  return h
end
function VRFW_OPT_Current(key)          -- the value the row shows: its draft, else the stored one (nil = unreadable)
  local row = VRFW_SET_ROWS[key]
  if row == nil then
    return nil
  end
  local v = VRFW_SET_DRAFT[key]
  if v == nil then
    local ok, cur = pcall(row.get)
    if ok then
      v = cur
    end
  end
  return v
end
function VRFW_OPT_PreviewId(key)        -- bgm id of the current value's preview in the game's language, or nil
  if type(key) ~= "string" or not VRFW_OPT_HasPreview(key) then
    return nil
  end
  local v = VRFW_OPT_Current(key)
  if type(v) ~= "number" then
    return nil
  end
  local id = VRFW_SET_Call(VRFW_OPT_PV_C.PREVIEW, key, v, VRFW_OPT_Lang())
  if type(id) == "number" and id ~= 0 then
    return id
  end
  return nil
end
function VRFW_OPT_Mark(a1, key)         -- row name + «  ▶» (current value has a preview) / «  ■» (playing)
  local label = VRFW_SET_LABELS[a1]
  if type(label) ~= "string" or type(key) ~= "string" or not VRFW_OPT_HasPreview(key) then
    return
  end
  local s = label
  if VRFW_OPT_PV.handle ~= 0 and VRFW_OPT_PV.key == key then
    s = label .. VRFW_OPT_PV_C.STOP_MARK
  elseif VRFW_OPT_PreviewId(key) ~= nil then
    s = label .. VRFW_OPT_PV_C.PLAY_MARK
  end
  if VRFW_OPT_IsChild(key) then           -- a child row: its label is list04
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 75769867 --[[_text_option_list04_on]], s, a1)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 702348360 --[[_text_option_list04_off]], s, a1)
    return
  end
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 861591609 --[[_text_option_list01_on]], s, a1)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 3344436024, 3778835256 --[[_text_option_list01_off]], s, a1)
end
function VRFW_OPT_Remark(key)           -- redraw the mark of the cells showing row `key`
  for cell, _ in pairs(VRFW_SET_LABELS) do
    local ok, k = pcall(VRFW_SET_Label, cell)
    if ok and k == key then
      pcall(VRFW_OPT_Mark, cell, key)
    end
  end
end
function VRFW_OPT_PreviewStop(why)      -- stop the preview; the menu's own music comes back
  local key = VRFW_OPT_PV.key
  if VRFW_OPT_PV.handle ~= 0 then
    pcall(funcLuaCommand, VRFW_OPT_PV_C.SND_STOP, VRFW_OPT_PV.handle)
  end
  VRFW_OPT_PV.handle = 0
  VRFW_OPT_PV.key = nil
  if VRFW_OPT_PV.paused then
    pcall(funcLuaCommand, VRFW_OPT_PV_C.BGM_RESUME)
    VRFW_OPT_PV.paused = false
  end
  if key ~= nil then
    VRFW_OPT_Remark(key)
  end
end
function VRFW_OPT_PreviewPlay(key)      -- ▶ of row `key`: play its current value's preview; again on the same row = stop
  if VRFW_OPT_PV.handle ~= 0 and VRFW_OPT_PV.key == key then
    VRFW_OPT_PreviewStop("again")
    return true
  end
  local id = VRFW_OPT_PreviewId(key)
  if id == nil then
    return false
  end
  local old = VRFW_OPT_PV.key
  if VRFW_OPT_PV.handle ~= 0 then        -- another row's preview: it stops, the menu music stays paused
    pcall(funcLuaCommand, VRFW_OPT_PV_C.SND_STOP, VRFW_OPT_PV.handle)
    VRFW_OPT_PV.handle = 0
    VRFW_OPT_PV.key = nil
    if old ~= nil then
      VRFW_OPT_Remark(old)
    end
  end
  if not VRFW_OPT_PV.paused then
    pcall(funcLuaCommand, VRFW_OPT_PV_C.BGM_PAUSE)
    VRFW_OPT_PV.paused = true
  end
  local ok, h = pcall(funcLuaCommand, VRFW_OPT_PV_C.SND_PLAY, id)
  if not ok or type(h) ~= "number" or h == 0 then
    VRFW_OPT_PreviewStop("not played")
    return false
  end
  VRFW_OPT_PV.handle = h
  VRFW_OPT_PV.key = key
  VRFW_OPT_PV.frame = 0
  VRFW_OPT_Remark(key)
  return true
end
function VRFW_OPT_ClickOnMark(a1, key)  -- a left click (not a key) on the name side of cell a1 whose row has a preview
  if VRFW_OPT_PreviewId(key) == nil and VRFW_OPT_PV.key ~= key then
    return false
  end
  -- the mouse button only: CMD_EVT_MOUSE_LEFT, or (without that input) CMD_ENTER_CLICK with no CMD_ENTER, as
  -- CMD_ENTER_CLICK also fires on Enter / A, which must toggle the row, never play its preview
  local function In(cmd)
    local ok, c = pcall(funcLuaCommand, VRFW_OPT_PV_C.CHECK_INPUT, VRFW_OPT_PV_C.MENU_CTRL, cmd)
    return ok and c == true
  end
  if not In(VRFW_OPT_PV_C.LEFT) and (In(VRFW_OPT_PV_C.ENTER) or not In(VRFW_OPT_PV_C.CLICK)) then
    return false
  end
  local ok2, px = pcall(funcLuaMenuCommand, VRFW_OPT_PV_C.POINTER)
  local ok3, ax = pcall(funcLuaMenuCommand, VRFW_OPT_PV_C.MESH_POS, 3344436024, a1, 2475420648 --[[_btn_arrow_l01]])
  if not ok2 or not ok3 or type(px) ~= "number" or type(ax) ~= "number" then
    return false
  end
  return px < ax
end
function VRFW_OPT_PreviewStep()         -- per frame: the preview key, the end of a track, leaving the tab
  if VRFW_OPT_PV.handle ~= 0 then
    VRFW_OPT_PV.frame = VRFW_OPT_PV.frame + 1
    if not VRFW_OPT_InView() then
      VRFW_OPT_PreviewStop("tab left")
    elseif VRFW_OPT_PV.frame % 30 == 0 then
      local ok, p = pcall(funcLuaCommand, VRFW_OPT_PV_C.SND_PLAYING, VRFW_OPT_PV.handle)
      if ok and p == false then
        VRFW_OPT_PreviewStop("ended")
      end
    end
  end
  if not VRFW_OPT_TAB_IDX or VRFW_OPT_PV.input == false then
    VRFW_OPT_PV.key_down = false
    return
  end
  local ok, k = pcall(funcLuaCommand, VRFW_OPT_PV_C.CHECK_INPUT, VRFW_OPT_PV_C.MENU_CTRL, VRFW_OPT_PV_C.KEY)
  local down = ok and k == true
  if down and not VRFW_OPT_PV.key_down and VRFW_OPT_InView() then
    local id = VRFW_SET_Focused()
    if id ~= nil and VRFW_OPT_HasPreview(id) and not VRFW_OPT_PreviewPlay(id) then
      funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 2086672038 --[[sy0003]])
    end
  end
  VRFW_OPT_PV.key_down = down
end

-- ---- handlers of the framework's setting_menu host (VRFW_Host) ---------------------------
-- Every handler has the id "mod_options.tab". The order of the old wrappers is kept: `before` = our code first, then
-- the retail (or the patches under the host); `after` = the retail first; `around` = ours decides, nxt goes on.
local VRFW_OPT_HOST = "setting_menu"
local function VRFW_OPT_On(point, phase, fn, create)
  VRFW_Host.on(VRFW_OPT_HOST, point, {id = "mod_options.tab", phase = phase, fn = fn, create = create})
end

if VRFW_Host ~= nil then
  -- the named list "option_rows": rows given by other mods' Lua, registered once per menu VM at its first callback
  --   VRFW_Host.add("setting_menu", "option_rows", {id = "<mod>.<row>", value = {get, step, fmt, set[, off]}})
  VRFW_Host.list(VRFW_OPT_HOST, "option_rows", {apply = function(items)
    for _, it in ipairs(items) do
      if type(it.value) == "table" and VRFW_SET_ROWS[it.id] == nil then
        VRFW_OPT_Register(it.id, it.value)
      end
    end
  end})

  VRFW_OPT_On("OnInit", "before", function()  -- every opening of the menu: no drafts, tab asked again, no preview
    if VRFW_OPT_PV.handle ~= 0 or VRFW_OPT_PV.paused then
      VRFW_OPT_PreviewStop("menu opened")
    end
    VRFW_OPT_PV.input = true
    VRFW_SET_DRAFT = {}
    VRFW_SET_LABELS = {}
    VRFW_OPT_CELLS = {}
    VRFW_OPT_TAB_IDX = nil
  end)

  VRFW_OPT_On("OnSetupLayer", "after", function(_, a1, a2)  -- the 5th tab: attach set of k + 1 tabs, item k visible
    if a1 == 601987949 or a1 == 4044286600 --[[cmn06_20_list_tab_item]] then
      local k = VRFW_OPT_Tab()
      if k then
        if a1 == 601987949 then
          LISTVIEW.UpdateAttachTabNum(k + 1, a1)
        else
          if a2 == k then
            funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, true)
            LISTVIEW.SetupTabIcon(a1, a2, VRFW_OPT_ICON, true)
          end
          funcLuaMenuCommand(3252599449, a1, k + 1)
        end
      end
    end
  end)

  VRFW_OPT_On("OnChangeFocus", "around", function(nxt, a1, a2)  -- the mod tab focused: its title in the header
    if a1 == 4044286600 --[[cmn06_20_list_tab_item]] then
      local k = VRFW_OPT_Tab()
      if k then
        local ok, idx = pcall(funcLuaMenuCommand, 2603265800, a1)
        if ok and idx == k then
          LISTVIEW.SetFocusFromHeaderToList(a1, 2081113831)
          funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], 601987949, 2303671242, VRFW_OPT_Text(VRFW_OPT_TITLE_ID, "Mod options"), 0)
          return
        end
      end
    end
    return nxt(a1, a2)
  end)

  -- a1 = the list CELL (a recycled instance of option01_02_list_item, NOT the item index: once the list scrolls, cell 0
  -- shows item 10, 11...), a2 = the label text of the item it shows now. The plugin says whether the tab shown is the
  -- mod tab (CMND_VRFW_OPTION_CELL reads the row at index a1, right only before any scroll); the row it drives is
  -- found by its label text, the plugin's key only when the label does not tell (two rows with one text, a legacy row)
  VRFW_OPT_On("UpdateListItem", "before", function(a1, a2)
    VRFW_SET_LABELS[a1] = a2
    local key = VRFW_SET_Call(VRFW_OPT_C.CELL, a1)
    if type(key) == "string" then
      VRFW_OPT_CELLS[a1] = VRFW_OPT_KeyOfLabel(a2) or key
    else
      VRFW_OPT_CELLS[a1] = nil
    end
  end)

  VRFW_OPT_On("UpdateListContentDynamicText", "around", function(nxt, a1, a2, a3, a4)
    if a2 == 40 then
      local id = VRFW_SET_Label(a1)
      if id ~= nil then
        if a3 or a4 then               -- left / right (populate: both false)
          VRFW_SET_LAST_OK = VRFW_SET_Toggle(id, a4 and 1 or -1)
        end
        VRFW_SET_Show(a1, id, a3, a4)
        return
      end
      if VRFW_OPT_IsModCell(a1) then    -- a mod-tab row nobody drives: never the retail FPS code
        if a3 or a4 then
          VRFW_SET_LAST_OK = false
        end
        VRFW_OPT_ShowText(a1, VRFW_OPT_Text(VRFW_OPT_UNAVAILABLE_ID, "-"), false, false)
        return
      end
    end
    return nxt(a1, a2, a3, a4)
  end)

  -- a retail row with values drawn / changed: gated rows follow it
  VRFW_OPT_On("UpdateListContentText", "after", function()
    VRFW_OPT_RefreshGated()
  end)
  VRFW_OPT_On("UpdateListContentCustomText", "after", function()
    VRFW_OPT_RefreshGated()
  end)

  VRFW_OPT_On("PlayUpdateContentSound", "around", function(nxt, a1)
    if a1 == 40 then
      local id, idx = VRFW_SET_Focused()
      if id ~= nil or (idx ~= nil and VRFW_OPT_IsModCell(idx)) then
        if VRFW_SET_LAST_OK then
          funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 3791946501 --[[sy0004]])
        else
          funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 2086672038 --[[sy0003]])
        end
        VRFW_SET_LAST_OK = true
        return 0
      end
    end
    return nxt(a1)
  end)

  VRFW_OPT_On("OnEnter", "around", function(nxt, a1, a2)  -- A on a mod row = right (the engine is not told)
    if a1 == 2081113831 or a1 == 3344436024 then
      local id, idx = VRFW_SET_Focused()
      if id ~= nil and VRFW_OPT_HasPreview(id) and VRFW_OPT_ClickOnMark(idx, id) then -- click on the ▶ side: preview
        if not VRFW_OPT_PreviewPlay(id) then
          funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 2086672038 --[[sy0003]])
        end
        return
      end
      if id ~= nil then
        if VRFW_SET_Toggle(id, 1) then
          funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 3848881948 --[[sy0000]])
        else
          funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 2086672038 --[[sy0003]])
        end
        VRFW_SET_Show(idx, id, false, true)
        return
      end
      if idx ~= nil and VRFW_OPT_IsModCell(idx) then
        funcLuaCommand(3073642526 --[[CMND_SND_PLAY?]], 2086672038 --[[sy0003]])
        return
      end
    end
    return nxt(a1, a2)
  end)

  -- engine save check, once per type-40 row: a draft = «¿Aplicar los cambios?»
  VRFW_OPT_On("IsChangedGraphicSetting", "around", function(nxt, a1)
    if a1 == 40 and VRFW_SET_Dirty() then
      return true
    end
    return nxt(a1)
  end)

  -- 0 = «Sí» (store), 1 = «No» (drop); runs in a coroutine
  VRFW_OPT_On("callBackSaveCheckDialog", "before", function(a1)
    if (a1 == 0 or a1 == 1) and VRFW_OPT_PV.handle ~= 0 then
      VRFW_OPT_PreviewStop("drafts applied / dropped")
    end
    if a1 == 0 then
      VRFW_SET_Commit()
    elseif a1 == 1 then
      VRFW_SET_DRAFT = {}
    end
  end)

  -- the preview key (Select / Tab) and the preview's end
  VRFW_OPT_On("Step", "after", function()
    VRFW_OPT_PreviewStep()
  end)

  -- retail input gate (dialogs, sub windows): no preview key while it is off
  VRFW_OPT_On("SetInputEnbaleMenuObject", "before", function(a1)
    VRFW_OPT_PV.input = a1
  end)

  -- leaving the menu (or the tab strip to another main-menu page): music back
  VRFW_OPT_On("CloseMenuSetting", "before", function()
    if VRFW_OPT_PV.handle ~= 0 or VRFW_OPT_PV.paused then
      VRFW_OPT_PreviewStop("menu closed")
    end
  end)

  -- the menu object is destroyed: never leave the game's music paused (create: the retail script has no FinalizeMenu)
  VRFW_OPT_On("FinalizeMenu", "before", function()
    if VRFW_OPT_PV.handle ~= 0 or VRFW_OPT_PV.paused then
      VRFW_OPT_PreviewStop("menu finalized")
    end
  end, true)
end

-- ---- rows registered before this file ran ---------------------------------------------------------------------------
if type(VRFW_OPT_LEGACY_ROWS) == "table" then -- an older framework build: adopt its rows
  for _, label in ipairs(VRFW_OPT_LEGACY_ORDER or {}) do
    if VRFW_OPT_LEGACY_ROWS[label] ~= nil and VRFW_SET_ROWS[label] == nil then
      VRFW_OPT_Register(label, VRFW_OPT_LEGACY_ROWS[label])
    end
  end
end
-- rows queued before this file ran: VRFW_OPT_QUEUE, or the 1.x EVT_OPT_QUEUE
for _, qname in ipairs({"VRFW_OPT_QUEUE", "EVT_OPT_QUEUE"}) do
  local queue = rawget(_ENV, qname)
  if type(queue) == "table" then
    for _, q in ipairs(queue) do
      if q.key ~= nil and q.row ~= nil then
        VRFW_OPT_Register(q.key, q.row)
      elseif q.label ~= nil and q.row ~= nil then
        VRFW_SET_Register(q.label, q.row)
      end
    end
  end
  rawset(_ENV, qname, nil)
end

-- 1.x names: every function of the row framework and its row tables under the old
-- EVT_OPT_* / EVT_SET_* names too (the same objects)
for _, prefix in ipairs({"VRFW_OPT_", "VRFW_SET_"}) do
  for k, v in pairs(_ENV) do
    if type(k) == "string" and k:sub(1, #prefix) == prefix and type(v) == "function" then
      rawset(_ENV, "EVT_" .. k:sub(6), v)
    end
  end
end
EVT_SET_ROWS, EVT_SET_ORDER, EVT_OPT_VERSION = VRFW_SET_ROWS, VRFW_SET_ORDER, VRFW_OPT_VERSION
