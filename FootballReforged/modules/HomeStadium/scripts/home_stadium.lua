-- Home Stadium (module of Football Reforged; docs/game/mods/home-stadium.md): the home stadium of each player team.
-- The stadiums offered are the rows of the game's stadium list (soccer_game_option SOCCER_OPTION_FIELD_INFO, mods'
-- rows included) in list order, each with the ticket item its unlock condition asks for. The choice is kept per team
-- dock in the mod's save data of the active slot (key dock.<set>). The game Lua (assets\lua) asks these commands:
--
--   CMND_HOMESTADIUM_LIST()          -> { { map, item }, … }: every stadium of the list in list order; item = the
--                                       ticket of GetGlobalItemGetBitFlag(item) == 1, 0 = always listed, -1 = another
--                                       condition (not offered)
--   CMND_HOMESTADIUM_GET(set)        -> the map crc of the team dock's home stadium, 0 = none (or no longer listed)
--   CMND_HOMESTADIUM_SET(set, map)   -> ok: the team dock's home stadium (0 clears it)

HomeStadium = HomeStadium or {}

require "VRFW/lib/basics"
local info, warn = VRFW.logger("home_stadium")
local crc32 = VRFW.crc32

local TABLE = "soccer/soccer_option_field_info"
local ITEM_FLAG = crc32("GetGlobalItemGetBitFlag")
local CALL, HASH = 0x35, 0x34       -- condition bytecode: a function call by hash, a hash argument
local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local stadiums = nil                -- { { map, item, order }, … } in list order
local listed = {}                   -- map -> true

local function decode_base64(text)
  local value = {}
  for i = 1, #BASE64 do value[BASE64:byte(i)] = i - 1 end
  local bytes, bits, count = {}, 0, 0
  for i = 1, #text do
    local v = value[text:byte(i)]
    if v ~= nil then
      bits = bits * 64 + v
      count = count + 6
      if count >= 8 then
        count = count - 8
        local b = math.floor(bits / 2 ^ count)
        bytes[#bytes + 1] = b
        bits = bits - b * 2 ^ count
      end
    end
  end
  return bytes
end

local function u32(bytes, i)
  if i + 3 > #bytes then return nil end
  return ((bytes[i] * 256 + bytes[i + 1]) * 256 + bytes[i + 2]) * 256 + bytes[i + 3]
end

-- The ticket of a row's unlock condition: 0 = none (always listed), the item of the game's one-call condition
-- GetGlobalItemGetBitFlag(item) == 1, or -1 for any other condition. That condition is 00 | u32 length 24 | body:
-- 05 35 <crc32 GetGlobalItemGetBitFlag> 00 0A 01 28 00 06 02 34 <item> 32 00000001 78 (every retail row, and the
-- framework's stadium type writes the same: VRFW content\types\stadium.lua).
local function ticket_of(cell)
  if cell == nil or cell == 0 then return 0 end
  local text = type(cell) == "table" and cell.text or cell
  if type(text) ~= "string" or text == "" then return 0 end
  local raw = decode_base64(text)
  local b = 6                        -- the body starts after 00 | u32 length
  if #raw ~= 29 or raw[1] ~= 0 or u32(raw, 2) ~= 24 then return -1 end
  if raw[b] ~= 5 or raw[b + 1] ~= CALL or u32(raw, b + 2) ~= ITEM_FLAG or raw[b + 13] ~= HASH then return -1 end
  if raw[b + 18] ~= 0x32 or u32(raw, b + 19) ~= 1 or raw[b + 23] ~= 0x78 then return -1 end
  return u32(raw, b + 14)
end

local function load_list()
  if stadiums ~= nil then return stadiums end
  stadiums = {}
  local ok, rows = pcall(VRFW.table.rows, TABLE)
  if not ok or type(rows) ~= "table" then
    warn("no stadium list (" .. TABLE .. "): " .. tostring(rows))
    return stadiums
  end
  local by_map, other = {}, 0
  for index, r in ipairs(rows) do
    local map = tonumber(r.c0 or r[1])
    if map ~= nil and map ~= 0 then
      map = bit32.band(map, 0xFFFFFFFF)
      local entry = { map = map, item = ticket_of(r.c2 or r[3]), order = tonumber(r.c1 or r[2]) or 0, index = index }
      if entry.item < 0 then other = other + 1 end
      if by_map[map] ~= nil then
        stadiums[by_map[map]] = entry          -- a later row of the same map replaces the earlier one
      else
        stadiums[#stadiums + 1] = entry
        by_map[map] = #stadiums
      end
    end
  end
  table.sort(stadiums, function(x, y)
    if x.order ~= y.order then return x.order < y.order end
    return x.index < y.index
  end)
  for _, st in ipairs(stadiums) do listed[st.map] = true end
  info(string.format("%d stadium(s) in the list, %d with a condition other than a ticket (not offered)", #stadiums,
    other))
  return stadiums
end

local function set_key(set)
  local n = math.floor(tonumber(set) or -1)
  if n < 0 then return nil end
  return "dock." .. n
end

function HomeStadium.List()
  local out = {}
  for _, st in ipairs(load_list()) do
    out[#out + 1] = { map = st.map, item = st.item }
  end
  return out
end

function HomeStadium.Get(set)
  local key = set_key(set)
  if key == nil then return 0 end
  local ok, map = pcall(VRFW.save.get, key, 0)
  map = ok and tonumber(map) or 0
  if map == 0 then return 0 end
  load_list()
  if not listed[map] then
    info(string.format("team %s: home stadium 0x%08X is no longer in the stadium list: none", tostring(set), map))
    return 0
  end
  return map
end

function HomeStadium.Set(set, map)
  local key = set_key(set)
  if key == nil then return false end
  map = bit32.band(math.floor(tonumber(map) or 0), 0xFFFFFFFF)
  load_list()
  if map ~= 0 and not listed[map] then
    warn(string.format("team %s: 0x%08X is not a stadium of the list: not saved", tostring(set), map))
    return false
  end
  local ok = pcall(VRFW.save.set, key, map ~= 0 and map or nil)
  pcall(VRFW.save.commit)
  info(string.format("team %s: home stadium %s", tostring(set), map ~= 0 and string.format("0x%08X", map) or "none"))
  return ok
end
