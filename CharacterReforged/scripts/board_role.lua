-- Character Reforged › the coach / manager role of a player (the skill board's medal slot), for the «Fantasy» skill
-- table's role slot (graft skill_table_role_slot). Declarations: content\game\board_role.toml.
--
--   CMND_CHARACTERREFORGED_GET_ROLE(charaStHdl)        -> role, badgeHdl, playCount, native, lock
--        role 0 none, 1 coach, 2 manager, 3 a badge handle the inventory does not resolve, < 0 error; native = the
--        creation-time staff bits of the record attribute (0 / 1 coach / 2 manager); lock = 0 (nothing is locked)
--   CMND_CHARACTERREFORGED_SET_ROLE(charaStHdl, role)  -> status, roleAfter (status -10 = matches missing: roleAfter =
--        how many)
--
-- The role is the badge item on the record (rec8+0x1BC = an inventory handle of abl_000002 coach / abl_000003
-- manager). SET_ROLE unequips with the engine's 0xE790D0(&hdl, &badgeHdl) and equips with 0xE73630(&hdl, &itemId), which
-- takes a free copy of the item. «Sin rol» always ends with no badge (a handle the engine did not release is released
-- by hand) and without the creation-time staff bits 0x30. The match requirement is Utilities' (`utilities.role_medal.*`
-- state keys; none = no requirement), checked only for a player without a medal.

CharacterReforged = CharacterReforged or {}
CharacterReforged.BoardRole = CharacterReforged.BoardRole or {}
local R = CharacterReforged.BoardRole

local function info(...) VRFW.log("board_role:", ...) end
local function warn(...) VRFW.warn("board_role:", ...) end

local ST_OK, ST_REFUSED = 1, 0
local ST_BAD_ARGS, ST_NOT_READY, ST_EXCEPTION, ST_NO_RECORD, ST_NEED_MATCHES = -1, -2, -4, -5, -10

local BADGE_COACH, BADGE_MANAGER = 0x9B6947D9, 0xEC6E774F -- abl_000002 / abl_000003
local OFF_ATTR, OFF_BADGE, OFF_PLAY_COUNT = 0x20, 0x1BC, 0x1E8
local ATTR_NATIVE_COACH, ATTR_NATIVE_MANAGER = 0x10, 0x20
local TWO32 = 4294967296

local ON = false
local HANDLE_BUFFER, ITEM_BUFFER

-- ---------------------------------------------------------------------------------------------- helpers

local function u32(v)
  if type(v) ~= "number" then return 0 end
  local n = v >= 0 and math.floor(v) or math.ceil(v)
  return n % TWO32
end

local function int(v)
  if type(v) ~= "number" or v ~= v then return nil end
  return v >= 0 and math.floor(v) or math.ceil(v)
end

local function hex(v)
  v = u32(v)
  return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
end

local function read(kind, addr)
  local ok, v = pcall(VRFW.mem.read, kind, addr)
  if ok then return v end
  return nil
end

local function write(kind, addr, v)
  return (pcall(VRFW.mem.write, kind, addr, v))
end

local band = bit32.band

-- the inventory record of a handle (item id +4, stock +0x10, equipped +0x14), nil when unknown
local function inv_record(inv)
  if inv == 0 then return nil end
  local items = VRFW.game.character_reforged_items()
  if not items then return nil end
  local ok, p = pcall(VRFW.call, "Board.InvRecord", items, inv)
  if not ok or not p or p < 0x10000 then return nil end
  return p
end

local function item_of(inv)
  local p = inv_record(inv)
  return p and read("u32", p + 4) or 0
end

-- rec8 of a character handle, checked against the handle
local function record_of(hdl)
  local kind = math.floor(hdl / 4096) % 16
  if hdl == 0 or kind >= 0xD then return nil end
  local ok, r = pcall(VRFW.chara.record, hdl)
  if not ok or not r or not r.addr or r.addr < 0x10000 then return nil end
  if read("u32", r.addr) ~= hdl then return nil end
  return r.addr
end

-- rec8, badge, item, plays, attr of a saved character
local function state(hdl)
  local rec8 = record_of(hdl)
  if not rec8 then return nil end
  local badge = read("u32", rec8 + OFF_BADGE)
  if badge == nil then return nil end
  local item = badge ~= 0 and item_of(badge) or 0
  return rec8, badge, item, read("u16", rec8 + OFF_PLAY_COUNT) or 0, read("u32", rec8 + OFF_ATTR) or 0
end

local function role_of_item(item)
  if item == BADGE_COACH then return 1 end
  if item == BADGE_MANAGER then return 2 end
  if item == 0 then return 0 end
  return 3
end

local function current_role(badge, item)
  if badge == 0 then return 0 end
  if item == 0 then return 3 end
  return role_of_item(item)
end

local function native_role(attr)
  if band(attr, ATTR_NATIVE_COACH) ~= 0 then return 1 end
  if band(attr, ATTR_NATIVE_MANAGER) ~= 0 then return 2 end
  return 0
end

-- what SET_ROLE does: { unequip, equip (item id or nil), clear_native }, or nil + status (refused before any write)
local function plan(role, badge, item, attr)
  if not role or role < 0 or role > 2 then return nil, ST_BAD_ARGS end
  local native = band(attr, ATTR_NATIVE_COACH + ATTR_NATIVE_MANAGER) ~= 0
  if role == 0 then
    return { unequip = badge ~= 0, clear_native = native }
  end
  if current_role(badge, item) == role then return { unequip = false, clear_native = false } end
  return { unequip = badge ~= 0, equip = role == 1 and BADGE_COACH or BADGE_MANAGER, clear_native = native }
end

-- Utilities' role-medal thresholds as written into the game (none = no requirement)
local function thresholds()
  local function get(k)
    local ok, v = pcall(VRFW.state.get, k)
    if not ok or type(v) ~= "number" then return nil end
    return math.max(0, math.min(65535, math.floor(v)))
  end
  local a, b = get("utilities.role_medal.matches_required"), get("utilities.role_medal.matches_required_created_role")
  if a and b then return a, b end
  return 0, 0
end

-- matches still missing before the plan's medal (the game checks only an empty badge slot; a creation-time staff
-- record uses the created-role threshold)
local function matches_missing(p, badge, plays, attr)
  if not p.equip or badge ~= 0 then return 0 end
  local need, need_created = thresholds()
  if need == 0 and need_created == 0 then return 0 end
  local n = band(attr, ATTR_NATIVE_COACH + ATTR_NATIVE_MANAGER) ~= 0 and need_created or need
  return math.max(0, n - plays)
end

local function engine(fn, hdl, value)
  write("u32", HANDLE_BUFFER, hdl)
  write("u32", ITEM_BUFFER, value)
  return (pcall(VRFW.call, fn, HANDLE_BUFFER, ITEM_BUFFER))
end

-- the badge release of 0xE790D0 by hand: one equipped copy of the stack back, then +0x1BC = 0
local function release_by_hand(rec8, badge)
  local p = inv_record(badge)
  if p then
    local item, equipped = read("u32", p + 4), read("u32", p + 0x14)
    if (item == BADGE_COACH or item == BADGE_MANAGER) and equipped and equipped > 0 then
      write("u32", p + 0x14, equipped - 1)
    end
  end
  write("u32", rec8 + OFF_BADGE, 0)
end

local function set_role(hdl, role)
  local missing = 0
  local function run()
    if not ON then return nil, ST_NOT_READY end
    local _, badge, item, plays, attr = state(hdl)
    if badge == nil then return nil, ST_NO_RECORD end
    local p, why = plan(role, badge, item, attr)
    if not p then return nil, why end
    missing = matches_missing(p, badge, plays, attr)
    if missing > 0 then return nil, ST_NEED_MATCHES end
    if p.unequip then
      if not engine("CharacterReforged.BadgeUnequip", hdl, badge) then return nil, ST_EXCEPTION end
      local rec8, left = state(hdl)
      if not rec8 then return nil, ST_NO_RECORD end
      if left ~= 0 then
        warn(string.format("SET_ROLE(%s): the engine left badge %s (item %s); released by hand", hex(hdl), hex(left), hex(item)))
        release_by_hand(rec8, left)
      end
    end
    if p.clear_native then
      local rec8, _, _, _, a = state(hdl)
      if not rec8 then return nil, ST_NO_RECORD end
      local cleared = a - band(a, ATTR_NATIVE_COACH + ATTR_NATIVE_MANAGER)
      write("u32", rec8 + OFF_ATTR, cleared)
      info(string.format("SET_ROLE(%s): creation-time staff bits cleared (attribute 0x%X -> 0x%X)", hex(hdl), a, cleared))
    end
    if p.equip then
      if not engine("CharacterReforged.BadgeEquip", hdl, p.equip) then return nil, ST_EXCEPTION end
    end
    local _, b, now = state(hdl)
    if b == nil then return nil, ST_NO_RECORD end
    return current_role(b, now)
  end
  local r, e = run()
  local status, after
  if r ~= nil then
    status, after = (r == role) and ST_OK or ST_REFUSED, r
  elseif e == ST_NEED_MATCHES then
    status, after = e, missing
  else
    status, after = e, -1
  end
  info(string.format("SET_ROLE(%s, %s) -> status %d, role now %d", hex(hdl), tostring(role), status, after))
  return status, after
end

-- ---------------------------------------------------------------------------------------------- commands

function R.GetRole(hdl)
  if not ON then return false end
  hdl = u32(hdl)
  local _, badge, item, plays, attr = state(hdl)
  if badge == nil then return ST_NO_RECORD, 0, 0, 0, 0 end
  return current_role(badge, item), badge, plays, native_role(attr), 0
end

function R.SetRole(hdl, role)
  if not ON then return false end
  return set_role(u32(hdl), int(role) or -1)
end

-- ---------------------------------------------------------------------------------------------- start

HANDLE_BUFFER = VRFW.mem.buffer("character_reforged_role_hdl", 8)
ITEM_BUFFER = VRFW.mem.buffer("character_reforged_role_item", 8)
ON = VRFW.is_on("CharacterReforged.BadgeEquip") and VRFW.is_on("CharacterReforged.BadgeUnequip")
if ON then
  info("role commands active (CMND_CHARACTERREFORGED_GET_ROLE / _SET_ROLE)")
else
  VRFW.error("board_role: badge signatures not resolved: the role slot cannot change roles")
end
