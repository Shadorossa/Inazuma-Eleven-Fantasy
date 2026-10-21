-- VR-Framework › shop redirect, menu side (every script VM). A menu opens a shop by writing its id to the param store
-- (funcLuaCommand(CMND_SET_PARAM, 0xCE4A397E, 0, shop id, 1)) before it opens shop_menu. When a mod redirects that shop
-- ([[VRFW.ShopRedirect]], scripts\shop_redirects.lua), the declared target's id is written instead, so every menu entry
-- of the shop (mode menus, shortcuts, other mods' boxes) opens the target. The engine's funcLuaCommand is wrapped the
-- moment it is registered; the list is asked once per VM, at the first shop id written. No engine call at load time.
--
-- A shop redirected to a contact set (`contact_set`): the shop id is written as it is; the next opening of the shop
-- screen (CMND_OPEN_MENU_OBJECT of shop_menu / shop_menu_basara_top) in this VM opens vrfw_contact_map_menu on that set
-- instead, and while that screen is up the opener's checks of the shop screen (CMND_IS_EXIST_MENU_OBJECT and the
-- menu-ready check) answer for it, so the opener waits for the screen and comes back the retail way when it closes.
if VRFW_ShopRedirect == nil then
  local R = {
    SET_PARAM = 3860611758,     -- CMND_SET_PARAM(key, index, value, kind)
    CLEAR_PARAM = 3363400568,   -- CMND_CLEAR_PARAM(key)
    SHOP_PARAM = 3460970878,    -- the param store key of the shop shop_menu opens
    LIST = 2445086479,          -- CMND_VRFW_SHOP_REDIRECTS() -> n, from 1, to 1, …
    SCREENS = 3797150395,       -- CMND_VRFW_SHOP_SCREENS() -> n, from 1, set 1, …
    REG_FIND = 2175579023,      -- CMND_VRFW_REG_FIND(type, key) -> id (-1)
    LOG = 3661580131,           -- CMND_EVT_LOG
    OPEN_MENU = 433545986,      -- CMND_OPEN_MENU_OBJECT(menu)
    MENU_READY = 1193349555,    -- (menu) -> true once the opened menu is up (the Mercado's wait asks it)
    IS_MENU = 2231168902,       -- CMND_IS_EXIST_MENU_OBJECT(menu) (funcLuaMenuCommand)
    SHOP_MENUS = {[3170360552] = true --[[shop_menu]], [713974531] = true --[[shop_menu_basara_top]]},
    SCREEN = 1355292071,        -- crc32("vrfw_contact_map_menu")
    KEY_SET = 1128821923,       -- crc32("vrfw_contact_set"): the screen's parameter
    KEY_HUB = 3979190066,       -- crc32("vrfw_contact_hub"): the set, for a hub menu (the free-match list)
    HUB = 1691394521,           -- CMND_VRFW_CONTACT_HUB (set) -> { menu, title }
    map = nil,                  -- shop id -> target shop id (this VM)
    screens = nil,              -- shop id -> contact set crc (this VM)
    pending = nil,              -- the contact set of the shop id just written
    alias = nil,                -- {from = shop screen asked by the opener, to = the contact map screen}
    hooked = {},
  }
  VRFW_ShopRedirect = R

  local function unsigned(v)
    if type(v) ~= "number" then return nil end
    if v < 0 then v = v + 4294967296 end
    return v
  end

  local function shop_id(real, v)
    if type(v) == "number" then return unsigned(v) end
    if type(v) ~= "string" then return nil end
    local ok, id = pcall(real, R.REG_FIND, "shop", v)
    if ok and type(id) == "number" and id ~= -1 and id ~= 0 then return unsigned(id) end
    return nil
  end

  local function load(real)
    R.map, R.screens = {}, {}
    local r = table.pack(pcall(real, R.LIST))
    if r[1] and type(r[2]) == "number" then
      for i = 1, r[2] do
        local from, to = shop_id(real, r[1 + 2 * i]), shop_id(real, r[2 + 2 * i])
        if from and to and from ~= to then R.map[from] = to end
      end
    end
    local s = table.pack(pcall(real, R.SCREENS))
    if s[1] and type(s[2]) == "number" then
      for i = 1, s[2] do
        local from, set = shop_id(real, s[1 + 2 * i]), unsigned(s[2 + 2 * i])
        if from and set then R.screens[from] = set end
      end
    end
  end

  -- the contact map screen instead of the shop screen: its set parameter, then the screen
  local function open_screen(real, shop_menu)
    local set = R.pending
    R.pending = nil
    local okh, hub = pcall(real, R.HUB, set)
    local menu = okh and type(hub) == "table" and unsigned(hub.menu) or 0
    if menu ~= nil and menu ~= 0 then
      -- the set's team hub (the free-match list in its office mode, soccer_vs_cpu_list_menu\120_contact_hub.lua)
      pcall(real, R.CLEAR_PARAM, R.KEY_HUB)
      pcall(real, R.SET_PARAM, R.KEY_HUB, 0, set, 1)
      R.alias = {from = shop_menu, to = menu}
      pcall(real, R.LOG, string.format("vrfw.ShopRedirect shop screen 0x%08X opened as the hub 0x%08X of set 0x%08X",
        shop_menu, menu, set))
      return real(R.OPEN_MENU, menu)
    end
    pcall(real, R.CLEAR_PARAM, R.KEY_SET)
    pcall(real, R.SET_PARAM, R.KEY_SET, 0, set, 1)
    R.alias = {from = shop_menu, to = R.SCREEN}
    pcall(real, R.LOG, string.format("vrfw.ShopRedirect shop screen 0x%08X opened as the contact map (set 0x%08X)",
      shop_menu, set))
    return real(R.OPEN_MENU, R.SCREEN)
  end

  local function make_command(real)
    return function(...)
      local cmd, key, _, value = ...
      if cmd == R.SET_PARAM and key == R.SHOP_PARAM and type(value) == "number" then
        if R.map == nil then load(real) end
        R.pending = R.screens[unsigned(value)]
        local to = R.map[unsigned(value)]
        if to ~= nil then
          local args = table.pack(...)
          args[4] = to
          pcall(real, R.LOG, string.format("vrfw.ShopRedirect shop 0x%08X opened as 0x%08X", unsigned(value), to))
          return real(table.unpack(args, 1, args.n))
        end
      elseif cmd == R.OPEN_MENU and R.pending ~= nil and R.SHOP_MENUS[unsigned(key)] then
        return open_screen(real, unsigned(key))
      elseif cmd == R.MENU_READY and R.alias ~= nil and unsigned(key) == R.alias.from then
        return real(cmd, R.alias.to)
      end
      return real(...)
    end
  end

  local function make_menu_command(real)
    return function(...)
      local cmd, menu = ...
      if cmd == R.IS_MENU and R.alias ~= nil and unsigned(menu) == R.alias.from then
        local up = real(cmd, R.alias.to)
        if up ~= true then
          R.alias = nil            -- the screen closed: the shop screen's own answers again
          pcall(funcLuaCommand, 2812667080 --[[CMND_VRFW_CONTACT_HUB_FILTER]], 0)   -- a hub's list filter off
        end
        return up
      end
      return real(...)
    end
  end

  local MAKERS = {funcLuaCommand = make_command, funcLuaMenuCommand = make_menu_command}

  local pending_names = {}
  for name, maker in pairs(MAKERS) do
    local current = rawget(_ENV, name)
    if type(current) == "function" then
      R.hooked[name] = true
      rawset(_ENV, name, maker(current))
    else
      pending_names[#pending_names + 1] = name
    end
  end
  if #pending_names > 0 then
    -- the engine registers its functions after the chunks ran: wrap them then (chained onto any earlier __newindex)
    local okm, meta = pcall(getmetatable, _ENV)
    if okm and (meta == nil or type(meta) == "table") then
      if meta == nil then
        meta = {}
        if not pcall(setmetatable, _ENV, meta) then meta = nil end
      end
      if meta ~= nil then
        local previous = meta.__newindex
        meta.__newindex = function(globals, k, v)
          if previous == nil then
            rawset(globals, k, v)
          elseif type(previous) == "function" then
            previous(globals, k, v)
          else
            previous[k] = v
          end
          local maker = MAKERS[k]
          if maker ~= nil and type(v) == "function" and not R.hooked[k] then
            local stored = rawget(globals, k)
            if type(stored) == "function" then
              R.hooked[k] = true
              rawset(globals, k, maker(stored))
            end
          end
        end
      end
    end
  end
end
