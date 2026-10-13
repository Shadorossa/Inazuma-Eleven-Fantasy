-- Utilities › friends list: the pure part (no engine, no VRFW.*; docs/game/ui/friends.md §4).
--
--   team description   "t1|<team name>|<param>:<level>:<rarity>,…" (chara_param ids of the active squad's members, in
--                      the squad's member order): what a friend gets when he asks to see this player's team
--   share code         "VRT1-" .. Crockford base-32 of the description's bytes (copied / sent to a friend; decoded back
--                      by M.decode_code)
--   groups             the order and text keys of the list's groups (same / different / no_mod / offline)

local M = {}

M.CODE_PREFIX = "VRT1-"
M.DESC_TAG = "t1"
M.GROUPS = { "same", "different", "no_mod", "mod", "online", "offline" }
-- the top bar entry the pending-request badge marks (VRFW_TopBarBadges key: <mod id>.<entry id>)
M.BADGE_ENTRY = "utilities.friends"
-- the most members a description carries (the squad's 29 member slots)
M.MAX_MEMBERS = 29

local ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

local function clean(s)
  s = tostring(s or "")
  s = s:gsub("[|,:%c]", " ")
  return s
end

-- a whole number as text. Never string.format("%d"): the scripts' Lua 5.2 formats %d through a 32-bit `long` on
-- Windows, so a chara_param id (a u32 hash, often >= 2^31) raised «not a number in proper range» and the error switched
-- the whole friends script off (Utilities 1.14.4)
function M.int(n)
  n = tonumber(n) or 0
  if n ~= n or n == math.huge or n == -math.huge then return "0" end
  return string.format("%.0f", n >= 0 and math.floor(n) or math.ceil(n))
end

-- members = { { param, level, rarity }, … }
function M.encode_team(name, members)
  local parts = {}
  for i, m in ipairs(members or {}) do
    if i > M.MAX_MEMBERS then break end
    parts[#parts + 1] = M.int(m[1]) .. ":" .. M.int(m[2]) .. ":" .. M.int(m[3])
  end
  return M.DESC_TAG .. "|" .. clean(name):sub(1, 64) .. "|" .. table.concat(parts, ",")
end

-- -> name, members ({ { param, level, rarity } }) or nil, error
function M.decode_team(desc)
  if type(desc) ~= "string" then return nil, "no team" end
  local tag, name, list = desc:match("^([^|]*)|([^|]*)|(.*)$")
  if tag ~= M.DESC_TAG then return nil, "not a team description" end
  local members = {}
  for p, l, r in list:gmatch("(%d+):(%d+):(%d+)") do
    members[#members + 1] = { tonumber(p), tonumber(l), tonumber(r) }
    if #members >= M.MAX_MEMBERS then break end
  end
  return name, members
end

-- bytes -> Crockford base-32 (5 bits a character, the last one padded with zeros)
function M.b32(s)
  local out, acc, bits = {}, 0, 0
  for i = 1, #s do
    acc = acc * 256 + s:byte(i)
    bits = bits + 8
    while bits >= 5 do
      bits = bits - 5
      local v = math.floor(acc / 2 ^ bits) % 32
      out[#out + 1] = ALPHABET:sub(v + 1, v + 1)
      acc = acc % 2 ^ bits
    end
  end
  if bits > 0 then
    local v = (acc * 2 ^ (5 - bits)) % 32
    out[#out + 1] = ALPHABET:sub(v + 1, v + 1)
  end
  return table.concat(out)
end

-- Crockford base-32 -> bytes (O = 0, I / L = 1, case and '-' ignored); nil for another character
function M.unb32(t)
  local out, acc, bits = {}, 0, 0
  t = t:upper():gsub("-", ""):gsub("O", "0"):gsub("[IL]", "1")
  for i = 1, #t do
    local v = ALPHABET:find(t:sub(i, i), 1, true)
    if v == nil then return nil end
    acc = acc * 32 + (v - 1)
    bits = bits + 5
    if bits >= 8 then
      bits = bits - 8
      out[#out + 1] = string.char(math.floor(acc / 2 ^ bits) % 256)
      acc = acc % 2 ^ bits
    end
  end
  return table.concat(out)
end

function M.code_of(desc)
  return M.CODE_PREFIX .. M.b32(desc)
end

-- a share code (anywhere in `text`) -> its team description, or nil
function M.desc_of_code(text)
  if type(text) ~= "string" then return nil end
  local body = text:match(M.CODE_PREFIX:gsub("%-", "%%-") .. "([0-9A-Za-z]+)")
  if body == nil then return nil end
  local d = M.unb32(body)
  if d == nil or M.decode_team(d) == nil then return nil end
  return d
end

-- the status a menu stands for: `map` = { status = { menu stems } } (config.toml [friends.status_menus]); nil = none
function M.status_of_menu(map, stem)
  if type(map) ~= "table" or type(stem) ~= "string" then return nil end
  for status, menus in pairs(map) do
    if type(menus) == "table" then
      for _, m in ipairs(menus) do
        if m == stem then return status end
      end
    end
  end
  return nil
end

-- the counts per group of `list` (VRFW.net.friends().list) -> { same = n, … } and the first index of each group
function M.group_counts(list)
  local n, first = {}, {}
  for _, g in ipairs(M.GROUPS) do n[g] = 0 end
  for i, f in ipairs(list or {}) do
    local g = f.group
    if n[g] ~= nil then
      n[g] = n[g] + 1
      if first[g] == nil then first[g] = i end
    end
  end
  return n, first
end

-- the actions a friend's details offer (keys; the panel names them with text keys): `mine` = this player's room
-- status (VRFW.net.status()), `f` = the friend's row (VRFW.net.friends().list[i])
function M.actions(f, mine)
  local a = {}
  local not_steam = f.mod_friend == true and f.steam_friend ~= true
  -- a request this player sent and the other has not answered: take it back, or ask on Steam too
  if f.request ~= nil and f.request ~= "" then
    return { "cancel", "steam_add", "profile" }
  end
  local hosting = type(mine) == "table" and mine.role == "host" and (mine.phase == "waiting" or mine.phase == "joined")
  local with_mod = f.in_game and f.vrfw ~= nil and f.vrfw ~= ""
  if with_mod then
    if f.group == "same" or f.group == "mod" then
      if hosting then a[#a + 1] = "invite" end
      if f.room == true then a[#a + 1] = "join" end
    end
    a[#a + 1] = "code"
    if f.group ~= "same" then a[#a + 1] = "mods" end
  end
  a[#a + 1] = "profile"
  if not_steam then
    a[#a + 1] = "steam_add"
    a[#a + 1] = "remove"
  end
  return a
end

-- the actions of a friend request this player got (a row of «Solicitudes»)
function M.request_actions()
  return { "accept", "decline", "block", "steam_add" }
end

return M
