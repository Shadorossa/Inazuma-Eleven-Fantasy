-- Match roles (docs/framework/match-role.md): which role each player of the user's team sets plays, kept in the save,
-- and handed to the match run time. The roles themselves are the mods' data (content\rules\ai\roles\*.toml, kind
-- VRFW.match_role/1); this script only stores who has which one and asks nothing of a role.
--
-- Save (the framework's data of the active slot): key "match_roles" = { ["<team set>.<team type>"] = { ["<character
-- handle>"] = "<role name>", … }, … }. A name no mod declares any more is kept (a mod switched off and on again finds
-- it) and ignored.
--
-- The game Lua (menus) asks these commands (content\game\match_roles.toml):
--   CMND_VRFW_MATCH_ROLE_LIST(handle)              -> { { name, text, help }, … }: the roles of the player's position
--                                                     (his card's main position); text / help = the text ids of the
--                                                     role's keys (crc32("<mod>.<key>"), 0 = none)
--   CMND_VRFW_MATCH_ROLE_GET(set, type, handle)    -> name ("" = none), text key crc32 (0 = none)
--   CMND_VRFW_MATCH_ROLE_SET(set, type, handle, name) -> ok: the player's role in that team set ("" clears it)
--
-- In a match: the match run time sends the signal VRFW.match_roles.assign once the players are on the pitch (and a
-- substitution asks again): every player of a side built from a team set whose character has a stored role gets it
-- (VRFW.ai.set_role).

MatchRoles = MatchRoles or {}

require "VRFW/lib/basics"
local info, warn = VRFW.logger("match_roles")
local crc32 = VRFW.crc32

local SAVE_KEY = "match_roles"
local TEAM_SETS = 16
local TEAM_TYPES = 3

local function whole(v)
  local n = tonumber(v)
  if n == nil then return nil end
  return math.floor(n)
end

local function set_key(set, kind)
  set, kind = whole(set), whole(kind)
  if set == nil or kind == nil or set < 0 or set >= TEAM_SETS or kind < 0 or kind >= TEAM_TYPES then return nil end
  return set .. "." .. kind
end

local function load_all()
  local ok, t = pcall(VRFW.save.get, SAVE_KEY, nil)
  if ok and type(t) == "table" then return t end
  return {}
end

local function declared_by_name()
  local by = {}
  local ok, list = pcall(VRFW.ai.roles)
  if ok and type(list) == "table" then
    for _, r in ipairs(list) do by[r.name] = r end
  end
  return by
end

-- the text id of a role's text key: a new key of the declaring mod is crc32("<mod>.<key>") (text engine), a key
-- given whole ("<mod>.<key>") is used as it is
local function text_id(mod, key)
  if type(key) ~= "string" or key == "" then return 0 end
  if key:find(".", 1, true) == nil and type(mod) == "string" and mod ~= "" then key = mod .. "." .. key end
  return crc32(key)
end

-- the card's main position of a character handle (nil = unknown)
local function card_position(handle)
  local ok, rec = pcall(VRFW.chara.record, handle)
  if not ok or type(rec) ~= "table" or rec.param == nil then return nil end
  local okc, card = pcall(VRFW.chara.card, rec.param)
  if not okc or type(card) ~= "table" then return nil end
  return card.position
end

function MatchRoles.List(handle)
  local out = {}
  local position = card_position(whole(handle) or 0)
  if position == nil then return out end
  local ok, list = pcall(VRFW.ai.roles, position)
  if not ok or type(list) ~= "table" then return out end
  for _, r in ipairs(list) do
    out[#out + 1] = { name = r.name, text = text_id(r.mod, r.text), help = text_id(r.mod, r.help) }
  end
  return out
end

function MatchRoles.Get(set, kind, handle)
  local key = set_key(set, kind)
  local h = whole(handle)
  if key == nil or h == nil or h == 0 then return "", 0 end
  local map = load_all()[key]
  local name = type(map) == "table" and map[tostring(h)] or nil
  if type(name) ~= "string" or name == "" then return "", 0 end
  local r = declared_by_name()[name]
  if r == nil then return "", 0 end
  return name, text_id(r.mod, r.text)
end

function MatchRoles.Set(set, kind, handle, name)
  local key = set_key(set, kind)
  local h = whole(handle)
  if key == nil or h == nil or h == 0 then
    warn("set", tostring(set), tostring(kind), tostring(handle), ": not a team set / character")
    return false
  end
  if type(name) ~= "string" then name = "" end
  if name ~= "" and declared_by_name()[name] == nil then
    warn(name, "is not a declared role: not saved")
    return false
  end
  local all = load_all()
  local map = type(all[key]) == "table" and all[key] or {}
  map[tostring(h)] = name ~= "" and name or nil
  all[key] = next(map) ~= nil and map or nil
  local ok = pcall(VRFW.save.set, SAVE_KEY, next(all) ~= nil and all or nil)
  pcall(VRFW.save.commit)
  info(string.format("team set %s: character 0x%08X -> %s", key, h, name ~= "" and name or "no role"))
  return ok
end

-- --- the match

local function assign_side(team, all, declared)
  local set, kind = VRFW.ai.team_set(team)
  local key = set_key(set, kind)
  if key == nil then return 0 end
  local map = all[key]
  if type(map) ~= "table" then return 0 end
  local n = 0
  for _, p in ipairs(VRFW.ai.players(team) or {}) do
    local okw, owner = pcall(VRFW.chara.user_owned, p.handle)
    local name = okw and owner ~= nil and map[tostring(owner)] or nil
    if type(name) == "string" and name ~= "" then
      if declared[name] == nil then
        warn(string.format("team %d 0x%08X: role %s is no longer declared: none", team, p.handle, name))
      else
        local ok, why = VRFW.ai.set_role(p.handle, name)
        if ok then n = n + 1 else warn(string.format("team %d 0x%08X: %s not given: %s", team, p.handle, name, tostring(why))) end
      end
    end
  end
  return n
end

local function assign_all(why)
  local all, declared = load_all(), declared_by_name()
  if next(all) == nil or next(declared) == nil then return end
  local n0, n1 = assign_side(0, all, declared), assign_side(1, all, declared)
  info(string.format("%s: roles given: team 0 %d, team 1 %d", why, n0, n1))
end

VRFW.on("signal:VRFW.match_roles.assign", function() assign_all("players on the pitch") end)
VRFW.on("match:substitution:post", function() assign_all("substitution") end)
