-- VR-Framework › shop tab split, menu side. Handlers of the framework's shop_menu_buy host (VRFW_Host, 000_host.lua); no engine call at load time.
--
-- A shop whose game tab a mod splits ([[VRFW.ShopTab]], scripts\shop_tabs.lua) has one tab per declared tab in the native tab list. The game's
-- Lua gets the tab list from the engine (SetupSlotInfo): the split game tab is listed once per declared tab (each with the game tab's slot type,
-- so every rule of the game's Lua for that kind of row still applies), each tab gets its declared icon, and the title bar shows the declared
-- title of the focused tab (UpdateTabNameByShopSlotType).
if VRFW_Host ~= nil then
  local STEM = "shop_menu_buy"
  local ID = "vr_framework.shop_tabs_"

  local CMD = {
    TAB_KEYS = VRFW_Cmd.VRFW_SHOP_TAB_KEYS,      -- CMND_VRFW_SHOP_TAB_KEYS() -> n, key 1 … key n
    TAB_BIND = VRFW_Cmd.VRFW_SHOP_TAB_BIND,       -- CMND_VRFW_SHOP_TAB_BIND(key, shop id) -> bound
    TABS = VRFW_Cmd.VRFW_SHOP_TABS,          -- CMND_VRFW_SHOP_TABS(shop id) -> split, n, icon 1, text id 1, …
    REG_FIND = VRFW_Cmd.VRFW_REG_FIND,      -- CMND_VRFW_REG_FIND(type, key) -> id (-1)
    TEXT_GET = VRFW_Cmd.TEXT_GET,      -- CMND_TEXT_GET(text id) -> text
    LOG = VRFW_Cmd.EVT_LOG,           -- CMND_EVT_LOG
    FOCUS_INSTANCE = 2603265800,
    SET_TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,
  }
  local TAB_ITEM = 4044286600   -- cmn06_20_list_tab_item (one plate per tab)
  local TAB_BAR = 1887158505    -- cmn06_01_list_tab_attach (the title bar)
  local TAB_TEXT = 3029561990   -- _text_list_tab01
  local MARK = 0x56540000       -- a split tab's slot type in the native list (MARK + tab index)

  local ST = { bound = false, shop = 0, split = 0, first = 0, tabs = {} }
  VRFW_ShopTabs = ST

  local function Log(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    pcall(funcLuaCommand, CMD.LOG, "vrfw.ShopTabs " .. table.concat(t, " "))
  end

  local function on(point, phase, fn)
    VRFW_Host.on(STEM, point, { id = ID .. point, phase = phase, fn = fn })
  end

  local function unsigned(v) return VRFW_Id.u32(v) end

  -- the ids of the shops declared by key (once per menu)
  local function bind()
    if ST.bound then return end
    ST.bound = true
    local r = table.pack(pcall(funcLuaCommand, CMD.TAB_KEYS))
    if not r[1] or type(r[2]) ~= "number" then return end
    for i = 1, r[2] do
      local key = r[2 + i]
      local ok, id = pcall(funcLuaCommand, CMD.REG_FIND, "shop", key)
      if ok and type(id) == "number" and id ~= -1 and id ~= 0 then
        pcall(funcLuaCommand, CMD.TAB_BIND, key, unsigned(id))
      end
    end
  end

  -- the split tabs of the open shop (split 0 = none)
  local function load_tabs()
    ST.split, ST.tabs = 0, {}
    local okid, shop = pcall(GetShopId)
    ST.shop = okid and unsigned(shop) or 0
    if ST.shop == 0 then return end
    local r = table.pack(pcall(funcLuaCommand, CMD.TABS, ST.shop))
    if not r[1] or type(r[2]) ~= "number" or r[2] == 0 or type(r[3]) ~= "number" then return end
    ST.split = r[2]
    for k = 1, r[3] do
      ST.tabs[k] = { icon = r[2 + 2 * k], text = r[3 + 2 * k] }
    end
  end

  on("OnInit", "before", function()
    ST.bound = false
    bind()
  end)

  -- the engine's tab list: the split game tab once per declared tab (a list the engine already split keeps its length)
  on("SetupSlotInfo", "around", function(nxt, n, list)
    bind()
    load_tabs()
    ST.first = 0
    if ST.split == 0 or type(list) ~= "table" or #ST.tabs < 2 then
      return nxt(n, list)
    end
    local out = {}
    for i = 1, (n or #list) do
      local v = list[i]
      if type(v) == "number" and v > MARK and v <= MARK + #ST.tabs then
        out[#out + 1] = ST.split
      elseif v == ST.split and ST.first == 0 then
        ST.first = #out + 1
        out[#out + 1] = v
        local split_already = false
        for j = i + 1, (n or #list) do
          local w = list[j]
          if type(w) == "number" and w > MARK and w <= MARK + #ST.tabs then split_already = true end
        end
        if not split_already then
          for _ = 2, #ST.tabs do out[#out + 1] = ST.split end
        end
      else
        out[#out + 1] = v
      end
    end
    if ST.first == 0 then
      return nxt(n, list)
    end
    local r = table.pack(nxt(#out, out))
    for k, t in ipairs(ST.tabs) do
      pcall(LISTVIEW.SetupTabIcon, TAB_ITEM, ST.first + k - 2, t.icon, true)
    end
    Log(string.format("shop 0x%08X: game tab %d listed as %d tabs (from tab %d)", ST.shop, ST.split, #ST.tabs, ST.first))
    UpdateTabNameByShopSlotType(ST.split)
    return table.unpack(r, 1, r.n)
  end)

  -- the focused tab's title: a split tab shows its declared title
  on("UpdateTabNameByShopSlotType", "around", function(nxt, slot, ...)
    local r = table.pack(nxt(slot, ...))
    if ST.first == 0 or slot ~= ST.split then return table.unpack(r, 1, r.n) end
    local ok, index = pcall(funcLuaMenuCommand, CMD.FOCUS_INSTANCE, TAB_ITEM)
    if not ok or type(index) ~= "number" then index = 0 end
    local tab = ST.tabs[index + 2 - ST.first]
    if tab and tab.text ~= 0 then
      local okt, text = pcall(funcLuaCommand, CMD.TEXT_GET, tab.text)
      if okt and type(text) == "string" and text ~= "" then
        pcall(funcLuaMenuCommand, CMD.SET_TEXT, TAB_BAR, TAB_TEXT, text, 0)
      end
    end
    return table.unpack(r, 1, r.n)
  end)
end
