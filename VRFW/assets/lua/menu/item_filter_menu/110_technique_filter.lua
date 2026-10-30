-- technique filter values (VR-Framework, the Lua side of scripts\technique_filter.lua): the move filter window's tension
-- tab (list item type 3) lists one row per value the framework serves from the technique table
-- (CMND_VRFW_TECHNIQUE_FILTER_VALUES), then one row per technique family (CMND_VRFW_TECHNIQUE_FILTER_FAMILIES); the
-- row values table (local t4) is rebuilt in place when the window opens, so the game's row label draws each value and
-- each row's check box. A family row's label is the family's name (its text key, else its id's last part), and the
-- tab is named «tension / family» (menu_text row vrfw_technique_filter_tab_family) while family rows are listed.
-- Framework off (the game's own rows): nothing is touched. Handlers on this script's host (000_host.lua): OnInit and
-- SetupFilterGroupInfoArray (the tab list's copy of the tab table) both refresh. No engine
-- call at load time.
if VRFW_Host ~= nil then
  local TF = {
    CMD_VALUES = VRFW_Cmd.VRFW_TECHNIQUE_FILTER_VALUES,     -- CMND_VRFW_TECHNIQUE_FILTER_VALUES(list item type) -> n, value 1, ... (0 = off)
    CMD_FAMILIES = VRFW_Cmd.VRFW_TECHNIQUE_FILTER_FAMILIES,   -- CMND_VRFW_TECHNIQUE_FILTER_FAMILIES() -> first row, n, text 1, name 1, ... (0 = none)
    TEXT_ID = VRFW_Cmd.VRFW_TEXT_ID,        -- CMND_VRFW_TEXT_ID(text key) -> text id
    TEXT_GET = VRFW_Cmd.TEXT_GET,       -- CMND_TEXT_GET(text id) -> string
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,       -- CMND_SET_MENU_TEXT_STRING(layer, text name, string, item)
    ROW_NAME = 1704438437,       -- _text_name01 (the row's label)
    TAB_FAMILY = 3237446752,     -- crc32("vrfw_technique_filter_tab_family"): the tab's name with family rows
    TENSION = 3,                 -- list item type of the tension tab
    TENSION_GROUP = 2,           -- filter group of the tension tab (its entry in the tab table, local t)
    first = nil,                 -- row index of the first family row (nil = no family rows)
    labels = {},                 -- family row labels, by family index (1-based)
  }

  -- the family's name in the game's language: its text key, else its id's last part
  local function label(text, name)
    if type(text) == "string" and text ~= "" then
      local ok, id = pcall(funcLuaCommand, TF.TEXT_ID, text)
      if ok and type(id) == "number" and id ~= 0 then
        local okg, s = pcall(funcLuaCommand, TF.TEXT_GET, id)
        if okg and type(s) == "string" and s ~= "" then
          return s
        end
      end
    end
    return tostring(name or "")
  end

  -- the served rows into t4 and the tab's name into the tab table (local t); the same result on every call
  local function refresh()
    local host = VRFW_Host.hosts and VRFW_Host.hosts.item_filter_menu
    local rows = host and host.L and host.L.t4
    local r = table.pack(pcall(funcLuaCommand, TF.CMD_VALUES, TF.TENSION))
    if type(rows) ~= "table" or not r[1] or type(r[2]) ~= "number" or r[2] <= 0 then
      return
    end
    for i = #rows, 1, -1 do
      rows[i] = nil
    end
    for i = 1, r[2] do
      rows[i] = { value = r[2 + i] }
    end
    TF.first, TF.labels = nil, {}
    local f = table.pack(pcall(funcLuaCommand, TF.CMD_FAMILIES))
    if not f[1] or type(f[2]) ~= "number" or type(f[3]) ~= "number" or f[3] <= 0 then
      return
    end
    TF.first = f[2]
    for i = 1, f[3] do
      TF.labels[i] = label(f[2 + 2 * i], f[3 + 2 * i])
      rows[f[2] + i] = { value = 0 }
    end
    local tabs = host.L.t
    local tab = type(tabs) == "table" and tabs[TF.TENSION_GROUP + 1] or nil
    if type(tab) == "table" then
      tab.tabTextName = TF.TAB_FAMILY
    end
  end

  VRFW_Host.on("item_filter_menu", "OnInit", { id = "VRFW.technique_filter_values", phase = "before", fn = refresh })
  -- the tab list is copied from the tab table here (the window's layer setup)
  VRFW_Host.on("item_filter_menu", "SetupFilterGroupInfoArray", { id = "VRFW.technique_filter_tab", phase = "before",
    fn = refresh })

  -- a family row: the family's name in place of the number the game drew
  VRFW_Host.on("item_filter_menu", "UpdateItem", { id = "VRFW.technique_filter_families", phase = "after", fn = function(r, a1, a2, a3, a4)
    if a3 ~= TF.TENSION or TF.first == nil or type(a4) ~= "number" or a4 < TF.first then
      return
    end
    local s = TF.labels[a4 - TF.first + 1]
    if s ~= nil then
      funcLuaMenuCommand(TF.SET_TEXT, a1, TF.ROW_NAME, s, a2)
    end
  end })
end
