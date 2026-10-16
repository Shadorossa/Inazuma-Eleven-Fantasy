-- VR-Framework › shop redirect, menu side (every script VM). A menu opens a shop by writing its id to the param store
-- (funcLuaCommand(CMND_SET_PARAM, 0xCE4A397E, 0, shop id, 1)) before it opens shop_menu. When a mod redirects that shop
-- ([[VRFW.ShopRedirect]], scripts\shop_redirects.lua), the declared target's id is written instead, so every menu entry
-- of the shop (mode menus, shortcuts, other mods' boxes) opens the target. The engine's funcLuaCommand is wrapped the
-- moment it is registered; the list is asked once per VM, at the first shop id written. No engine call at load time.
if VRFW_ShopRedirect == nil then
  local R = {
    SET_PARAM = 3860611758,     -- CMND_SET_PARAM(key, index, value, kind)
    SHOP_PARAM = 3460970878,    -- the param store key of the shop shop_menu opens
    LIST = 2445086479,          -- CMND_VRFW_SHOP_REDIRECTS() -> n, from 1, to 1, …
    REG_FIND = 2175579023,      -- CMND_VRFW_REG_FIND(type, key) -> id (-1)
    LOG = 3661580131,           -- CMND_EVT_LOG
    map = nil,                  -- shop id -> target shop id (this VM)
    hooked = false,
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
    R.map = {}
    local r = table.pack(pcall(real, R.LIST))
    if not r[1] or type(r[2]) ~= "number" then return end
    for i = 1, r[2] do
      local from, to = shop_id(real, r[1 + 2 * i]), shop_id(real, r[2 + 2 * i])
      if from and to and from ~= to then R.map[from] = to end
    end
  end

  local function make(real)
    return function(...)
      local cmd, key, _, value = ...
      if cmd == R.SET_PARAM and key == R.SHOP_PARAM and type(value) == "number" then
        if R.map == nil then load(real) end
        local to = R.map[unsigned(value)]
        if to ~= nil then
          local args = table.pack(...)
          args[4] = to
          pcall(real, R.LOG, string.format("vrfw.ShopRedirect shop 0x%08X opened as 0x%08X", unsigned(value), to))
          return real(table.unpack(args, 1, args.n))
        end
      end
      return real(...)
    end
  end

  local current = rawget(_ENV, "funcLuaCommand")
  if type(current) == "function" then
    rawset(_ENV, "funcLuaCommand", make(current))
  else
    -- the engine registers funcLuaCommand after the chunks ran: wrap it then (chained onto any earlier __newindex)
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
          if k == "funcLuaCommand" and type(v) == "function" and not R.hooked then
            local stored = rawget(globals, k)
            if type(stored) == "function" then
              R.hooked = true
              rawset(globals, k, make(stored))
            end
          end
        end
      end
    end
  end
end
