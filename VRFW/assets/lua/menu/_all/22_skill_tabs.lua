-- menu_engine: the Lua side of the skill tab registry (VR-Framework service S3).
-- Definitions only (this file runs in every script VM, lua\_all): the move list's handler file
-- (lua\ability_list_menu\110_skill_tabs.lua) calls VRFW_SkillTabs.Attach(stem). Nothing here names a tab or a mod: the
-- tabs come from the mods' content\skill_tabs\*.toml through the framework's commands.
--
-- * The tab row of the «Habilidades» / «Técnicas» list is native (the game's tab table, which the registry rewrites:
--   a game tab hidden, a new category added, a window of one group). The list's Lua only paints the icons and titles
--   and picks the filter from three tables parallel to the game's table: `t` (tab icon types), `t4` (filter window
--   configs), `t5` (saved filter groups). When the registry is on (CMND_VRFW_SKILL_TABS() > 0), @edit rebuilds the
--   three in place from the native list's window (CMND_VRFW_SKILL_TAB_WINDOW()): a game tab keeps its own icon /
--   filter, a declared look (CMND_VRFW_SKILL_TAB_INFO) gets a marker icon type (MARK + category). So icons, titles,
--   Z / C and the filters always agree with the native list.
-- * LISTVIEW.SetupTabIcon: a marker draws the plate of the declared game icon type, then the declared sprite on the
--   focused / unfocused icon meshes. LISTVIEW.SetupTabText: a marker writes the declared title (the game's text lookup
--   of its id, else the framework's text).
-- * The tab layer has a fixed number of plate instances (10): a plate past the list is hidden with its «!» badge, its
--   click zone and its hover focus (OnSetupLayer / OnOpenLayer); UpdateTabNewIcon never lights one.
-- * Registry off (no declaration, or another mod patches the tab sites itself): nothing is touched.
-- No engine call at load time.
if VRFW_SkillTabs == nil then
  local ST = {
    CMD_TABS = VRFW_Cmd.VRFW_SKILL_TABS,     -- CMND_VRFW_SKILL_TABS() -> n, category 1 … n (0 = off)
    CMD_WINDOW = VRFW_Cmd.VRFW_SKILL_TAB_WINDOW,   -- CMND_VRFW_SKILL_TAB_WINDOW() -> start, count of the window in force
    CMD_INFO = VRFW_Cmd.VRFW_SKILL_TAB_INFO,       -- CMND_VRFW_SKILL_TAB_INFO(category) -> game index, icon, atlas, sprite, sprite off,
                               --   text id, text, filter, filter group
    TEXT_GET = VRFW_Cmd.TEXT_GET,     -- CMND_TEXT_GET(text id) -> the text in the game's language
    LOG = VRFW_Cmd.EVT_LOG,          -- CMND_EVT_LOG
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,     -- CMND_SET_MENU_TEXT_STRING
    VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,       -- CMND_SET_LAYER_VISIBLE
    SET_SPRITE = 558735651,
    COLLISION = 855005857,     -- a layer instance's click zone on / off
    HOVER = VRFW_Cmd.SET_ON_CHANGE_FOCUS_MOUSE,        -- a layer instance's hover focus on / off
    TAB_ITEM = 4044286600,     -- cmn06_20_list_tab_item (one plate instance per tab)
    TAB_NEW = 2834115499,      -- cmn01_10_new_icon_tab (the «!» badge, one instance per plate)
    TAB_BAR = 1887158505,      -- the tab bar layer (its title text)
    TAB_TEXT = 3029561990,     -- _text_list_tab01
    DMY_ON = 3229351341,       -- icon_list_tab_dmy01_on
    DMY_OFF = 380437824,       -- icon_list_tab_dmy01_off
    MARK = 1448280064,         -- marker icon type base (0x56530000 + category): never a game icon type
    on = false,                -- the tables were rebuilt from the native list (this VM)
    count = 0,                 -- tabs shown
    looks = {},                -- marker -> { icon, atlas, sprite, sprite_off, text_id, text, category }
    wrapped = false,
    logs = 0,
  }

  function ST.Log(...)
    if ST.logs >= 20 then
      return
    end
    ST.logs = ST.logs + 1
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring((select(i, ...)))
    end
    pcall(funcLuaCommand, ST.LOG, "VRFW skill_tabs " .. table.concat(parts, " "))
  end

  local function number_or(v, default)
    if type(v) == "number" then
      return v
    end
    return default
  end

  -- the native list in force: its categories (the window of the registry's list), or nil when the registry is off
  function ST.NativeTabs()
    local r = table.pack(pcall(funcLuaCommand, ST.CMD_TABS))
    if not r[1] or type(r[2]) ~= "number" or r[2] <= 0 then
      return nil
    end
    local all = {}
    for i = 1, r[2] do
      all[#all + 1] = r[2 + i]
    end
    local ok, start, count = pcall(funcLuaCommand, ST.CMD_WINDOW)
    if not ok or type(start) ~= "number" or type(count) ~= "number" or count <= 0 or start + count > #all then
      start, count = 0, #all
    end
    local out = {}
    for i = start + 1, start + count do
      out[#out + 1] = all[i]
    end
    return out
  end

  -- rebuild the screen's three tab tables in place (the functions of the script hold them as upvalues)
  function ST.Apply(t, t4, t5)
    if ST.on or type(t) ~= "table" or type(t4) ~= "table" or type(t5) ~= "table" then
      return
    end
    local cats = ST.NativeTabs()
    if cats == nil then
      return
    end
    -- the game's tables, parallel to the game's tab table (copied before they are rewritten)
    local game_icon, game_filter, game_group = {}, {}, {}
    for i = 1, #t do
      game_icon[i], game_filter[i], game_group[i] = t[i], t4[i], t5[i]
    end
    -- the first game tab of a kind (move categories 1-4: the first; aura categories: the first aura tab, index 5)
    local function kind_index(category)
      if category >= 100 and #t >= 5 then
        return 5
      end
      return 1
    end
    local nt, n4, n5, shown = {}, {}, {}, {}
    for _, category in ipairs(cats) do
      local r = table.pack(pcall(funcLuaCommand, ST.CMD_INFO, category))
      local gi = r[1] and number_or(r[2], 0) or 0
      local icon, atlas, sprite = number_or(r[3], 0), number_or(r[4], 0), number_or(r[5], 0)
      local sprite_off, text_id, text = number_or(r[6], 0), number_or(r[7], 0), r[8]
      local filter, group = number_or(r[9], 0), number_or(r[10], 0)
      local base = (gi > 0 and gi <= #game_icon) and gi or kind_index(category)
      local icon_type = game_icon[base]
      if gi == 0 or icon ~= 0 or sprite ~= 0 or text_id ~= 0 then
        icon_type = ST.MARK + category
        ST.looks[icon_type] = {
          icon = icon ~= 0 and icon or game_icon[base], atlas = atlas, sprite = sprite,
          sprite_off = sprite_off ~= 0 and sprite_off or sprite, text_id = text_id,
          text = type(text) == "string" and text or "", category = category,
        }
      end
      nt[#nt + 1] = icon_type
      n4[#n4 + 1] = filter ~= 0 and filter or game_filter[base]
      n5[#n5 + 1] = group ~= 0 and group or game_group[base]
      shown[#shown + 1] = tostring(category)
    end
    for i = math.max(#t, #t4, #t5), 1, -1 do
      t[i], t4[i], t5[i] = nil, nil, nil
    end
    for i = 1, #nt do
      t[i], t4[i], t5[i] = nt[i], n4[i], n5[i]
    end
    ST.on, ST.count = true, #nt
    ST.Log("tabs", #nt, table.concat(shown, " "))
  end

  -- LISTVIEW wrappers (once per VM): the marker icon types' plates and titles
  function ST.Wrap()
    if ST.wrapped or type(LISTVIEW) ~= "table" then
      return
    end
    ST.wrapped = true
    local setup_icon = LISTVIEW.SetupTabIcon
    if type(setup_icon) == "function" then
      LISTVIEW.SetupTabIcon = function(layer, instance, icon_type, ...)
        local look = ST.looks[icon_type]
        if look == nil then
          return setup_icon(layer, instance, icon_type, ...)
        end
        local r = table.pack(setup_icon(layer, instance, look.icon, ...))
        if look.atlas ~= 0 and look.sprite ~= 0 then
          local target = layer or ST.TAB_ITEM
          pcall(funcLuaMenuCommand, ST.SET_SPRITE, target, look.atlas, look.sprite, ST.DMY_ON, 0, instance)
          pcall(funcLuaMenuCommand, ST.SET_SPRITE, target, look.atlas, look.sprite_off, ST.DMY_OFF, 0, instance)
        end
        return table.unpack(r, 1, r.n)
      end
    end
    local setup_text = LISTVIEW.SetupTabText
    if type(setup_text) == "function" then
      LISTVIEW.SetupTabText = function(icon_type, layer, ...)
        local look = ST.looks[icon_type]
        if look == nil then
          return setup_text(icon_type, layer, ...)
        end
        local name = nil
        if look.text_id ~= 0 then
          local ok, s = pcall(funcLuaCommand, ST.TEXT_GET, look.text_id)
          if ok and type(s) == "string" and s ~= "" then
            name = s
          end
        end
        if name == nil and look.text ~= "" then
          name = look.text
        end
        if name ~= nil then
          funcLuaMenuCommand(ST.SET_TEXT, layer or ST.TAB_BAR, ST.TAB_TEXT, name)
          return
        end
        return setup_text(look.icon, layer, ...)
      end
    end
  end

  -- a tab plate (or its «!» badge) past the shown tabs: hidden, with its click zone and hover focus
  function ST.HideSpare(layer, instance)
    if not ST.on or (layer ~= ST.TAB_ITEM and layer ~= ST.TAB_NEW) or type(instance) ~= "number"
        or instance < ST.count then
      return false
    end
    funcLuaMenuCommand(ST.VISIBLE, layer, instance, false)
    if layer == ST.TAB_ITEM then
      pcall(funcLuaMenuCommand, ST.COLLISION, layer, instance, false)
      pcall(funcLuaMenuCommand, ST.HOVER, layer, instance, false)
    end
    return true
  end

  function ST.Attach(stem)
    if VRFW_Host == nil then
      return
    end
    local id = "menu_engine.skill_tabs"
    VRFW_Host.on(stem, "@edit", {
      id = id,
      fn = function(L)
        local ok, t, t4, t5 = pcall(function() return L.t, L.t4, L.t5 end)
        if not ok then
          ST.Log(stem, "tab tables not readable:", t)
          return
        end
        ST.Apply(t, t4, t5)
        if ST.on then
          ST.Wrap()
        end
      end,
    })
    -- the spare plates: no game setup (their icon type would be nil), hidden
    VRFW_Host.on(stem, "OnSetupLayer", {
      id = id, phase = "around",
      fn = function(nxt, layer, instance, ...)
        if ST.HideSpare(layer, instance) then
          return
        end
        return nxt(layer, instance, ...)
      end,
    })
    VRFW_Host.on(stem, "OnOpenLayer", {
      id = id, phase = "after",
      fn = function(r, layer, instance)
        ST.HideSpare(layer, instance)
      end,
    })
    -- the engine sets the «!» badge of every tab of its own list (native index = plate index); never a spare one
    VRFW_Host.on(stem, "UpdateTabNewIcon", {
      id = id, phase = "around",
      fn = function(nxt, index, lit, ...)
        if ST.on and type(index) == "number" and index >= ST.count then
          lit = false
        end
        return nxt(index, lit, ...)
      end,
    })
  end

  VRFW_SkillTabs = ST
end
