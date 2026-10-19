-- Home Stadium (module of Football Reforged): the home stadium provider of the framework's friendly executor, in every
-- menu VM. VRFW_PACHANGA.start asks VRFW_HomeStadium (the framework's providers) when a friendly's stadium is left open (no stadium from the
-- caller, the rules or the rival's home): the answer is the team's chosen stadium (scripts\home_stadium.lua, saved
-- per team dock), 0 = none. Also the stadiums the player owns, for the team dock's selector. No engine call at load
-- time.
HomeStadium = type(HomeStadium) == "table" and HomeStadium or {}
do
  local H = HomeStadium
  H.CMD = {
    LIST = 1347405536,          -- CMND_HOMESTADIUM_LIST () -> { { map, item }, … }
    GET = 2069469516,           -- CMND_HOMESTADIUM_GET (set) -> map
    SET = 1618383584,           -- CMND_HOMESTADIUM_SET (set, map) -> ok
    ITEM_NUM = 2011560392,      -- CMND_GET_ITEM_NUM (item) -> count (a key item: 1 while its condition holds)
    MAP_NAME = 3763041341,      -- CMND_GET_MAP_NAME (map) -> name
    LOG = 3661580131,           -- CMND_EVT_LOG
  }

  function H.log(...)
    pcall(funcLuaCommand, H.CMD.LOG, "home_stadium", ...)
  end

  -- the team dock's home stadium (map crc), 0 = none
  function H.get(set)
    if type(set) ~= "number" or set < 0 then return 0 end
    local ok, map = pcall(funcLuaCommand, H.CMD.GET, set)
    if ok and type(map) == "number" then return map % 4294967296 end
    return 0
  end

  function H.set(set, map)
    local ok, done = pcall(funcLuaCommand, H.CMD.SET, set, map or 0)
    return ok and done == true
  end

  -- the stadiums of the game's stadium list the player owns, in list order: { { map, name }, … }. Owned = no ticket
  -- needed, or the ticket item held (the key item count; a row with another condition is not offered).
  function H.owned()
    local out = {}
    local ok, list = pcall(funcLuaCommand, H.CMD.LIST)
    if not ok or type(list) ~= "table" then
      H.log("no stadium list from the module's script")
      return out
    end
    for _, st in ipairs(list) do
      local map, item = tonumber(st.map), tonumber(st.item)
      local have = item == 0
      if item ~= nil and item > 0 then
        local okn, n = pcall(funcLuaCommand, H.CMD.ITEM_NUM, item)
        have = okn and type(n) == "number" and n > 0
      end
      if map ~= nil and map ~= 0 and have then
        local okm, name = pcall(funcLuaCommand, H.CMD.MAP_NAME, map)
        out[#out + 1] = { map = map, name = (okm and type(name) == "string") and name or "" }
      end
    end
    return out
  end

  -- the provider of the framework's home matches (VRFW_HomeStadium, framework menu _all: defined before this root)
  if type(VRFW_HomeStadium) == "table" and type(VRFW_HomeStadium.Register) == "function" then
    VRFW_HomeStadium.Register("home_stadium.dock", function(set) return H.get(set) end)
  end
end
