-- Utilities › combo partners (feature combo_partners; docs/game/mechanics/combo-partners.md).
--
-- A combo / cooperative move (SKILL_INFO partnerType 2-4 = performers) is cast with the executor plus partnerType - 1
-- teammates; the game picks them itself (BuildEventCast). The player chooses, per player and move, which teammates
-- perform it with him, for every partner slot: the move's named partners (SKILL_INFO partner1..3) are only the
-- defaults of the first slots and can be replaced like any other pick. In a match, right after the cast is built,
-- every slot whose chosen partner is on the pitch gets him; a chosen partner not on the pitch (or no choice) keeps the
-- engine's pick for that slot (a named partner when he is there).
--
-- Save: blob skill_partners.json of mod utilities, one per slot:
--   { version = 2, players = { ["<executor handle, 8 hex>"] = { param_id = <chara_param>, moves = { ["<skill, 8 hex>"] = { p1, p2, p3 } } } } }
-- p<k> = partner slot k (0 = the engine's pick). Version 1 listed the free slots only (after the named ones); its lists
-- are moved behind the named slots when read. A handle reused by another card (another param_id) starts empty.
--
-- 2026-10-12 (Nacho): a coach or a manager is never a partner. Staff = the card's role in its record (attribute byte
-- REC_ROLE, bits ROLE_COACH / ROLE_MANAGER: what the game sets for a staff card and turns into its abl_000002 /
-- abl_000003 badge, docs/game/ui/skill-board-original.md «Native staff creation»). A staff partner is saved as random
-- and, in the match, left to the engine's pick. The picker (graft combo_partners) does not offer them either: it asks
-- the game's own badge test.

local BLOB = "skill_partners.json"
local FILE_VERSION = 2
local MAX_PARTNERS = 3
local CACHE_MS = 30000
local HELD_STALE_MS = 250
local ACTOR_STRIDE, ACTOR_MAX = 0x570, 0x3A
local REC_ROLE, ROLE_COACH, ROLE_MANAGER = 0x20, 0x10, 0x20

local function u32(v)
  return bit32.band(v or 0, 0xFFFFFFFF)
end

local function arg_u32(v)
  if type(v) ~= "number" then
    return 0
  end
  return u32(v >= 0 and math.floor(v) or math.ceil(v))
end

local function key(v)
  return string.format("%08X", u32(v))
end

-- a coach or a manager card (record role bits)
local function is_staff(hdl)
  if hdl == 0 then
    return false
  end
  local r = VRFW.chara.record(hdl)
  if not r or not r.addr then
    return false
  end
  local ok, role = pcall(VRFW.mem.read, "u8", r.addr + REC_ROLE)
  return ok and type(role) == "number" and bit32.band(role, ROLE_COACH + ROLE_MANAGER) ~= 0
end

-- ---------------------------------------------------------------------------------------------- the move's partners

local function partners_of(info)
  local ok, p = pcall(function()
    return { info.partner_type, info.partner1, info.partner2, info.partner3 }
  end)
  if not ok then
    return nil
  end
  local performers = math.min(math.max(p[1], 1), 4)
  local slots = math.min(performers - 1, MAX_PARTNERS)
  local named = {}
  for k = 2, 4 do
    local n = p[k]
    local dup = false
    for _, x in ipairs(named) do
      dup = dup or x == n
    end
    if n ~= 0 and not dup and #named < slots then
      named[#named + 1] = n
    end
  end
  return { performers = performers, slots = slots, named = named, free = slots - #named }
end

-- SKILL_INFO of a move through the engine's own table (derived from the loaded skill_config: no move list)
local function skill_partners(skill)
  if skill == 0 or not VRFW.is_on("SkillInfoFind") then
    return nil
  end
  local tbl = VRFW.game.skill_table()
  if not tbl then
    return nil
  end
  local out, id = VRFW.mem.buffer("info_out", 8), VRFW.mem.buffer("info_id", 4)
  VRFW.mem.write("ptr", out, 0)
  VRFW.mem.write("u32", id, skill)
  if not pcall(VRFW.call, "SkillInfoFind", tbl, out, id) then
    return nil
  end
  local info = VRFW.mem.read("ptr", out)
  if not info or info < 0x10000 then
    return nil
  end
  local ok, rec = pcall(VRFW.mem.struct, "SkillInfo", info)
  return ok and partners_of(rec) or nil
end

-- ---------------------------------------------------------------------------------------------- the saved choices

-- version 1 kept the free slots only: each list moves behind the move's named slots (left to the engine's pick)
local function upgrade_free_slot_lists(f)
  for _, e in pairs(f.players) do
    for k, v in pairs(e.moves or {}) do
      local sp = type(v) == "table" and #v > 0 and skill_partners(tonumber(k, 16) or 0) or nil
      if sp and #sp.named > 0 then
        local moved = {}
        for i = 1, #sp.named do
          moved[i] = 0
        end
        for i = 1, sp.slots - #sp.named do
          moved[#sp.named + i] = v[i] or 0
        end
        while #moved > 0 and moved[#moved] == 0 do
          moved[#moved] = nil
        end
        e.moves[k] = (#moved > 0) and moved or nil
      end
    end
  end
end

local function load_file()
  local text, err = VRFW.save.blob(BLOB)
  if text == nil then
    if err then
      VRFW.error(BLOB .. ": " .. tostring(err) .. " (starting empty)")
    end
    return { version = FILE_VERSION, players = {} }
  end
  local f, e = VRFW.json.decode(text)
  if type(f) ~= "table" then
    VRFW.error(BLOB .. ": " .. tostring(e) .. " (starting empty)")
    return { version = FILE_VERSION, players = {} }
  end
  f.players = f.players or {}
  if (f.version or 1) < 2 then
    upgrade_free_slot_lists(f)
  end
  f.version = FILE_VERSION
  return f
end

local cache -- { slot, time, file }

local function load_fresh()
  local f = load_file()
  cache = { VRFW.slots.active(), VRFW.now(), f }
  return f
end

-- the match hook: the cached file (reloaded after CACHE_MS or a slot change)
local function load_cached()
  if cache and cache[1] == VRFW.slots.active() and VRFW.now() - cache[2] < CACHE_MS then
    return cache[3]
  end
  return load_fresh()
end

local function write(f, what)
  local ok, where = VRFW.save.blob_write(BLOB, VRFW.json.encode(f, true))
  if ok then
    cache = { VRFW.slots.active(), VRFW.now(), f }
    VRFW.log(what .. " -> " .. tostring(where))
  else
    VRFW.error("write: " .. tostring(where))
  end
  return ok and true or false
end

local function choices(f, hdl, param, skill)
  local e = f.players[key(hdl)]
  if not e or e.param_id ~= param then
    return {}
  end
  return (e.moves or {})[key(skill)] or {}
end

-- at most MAX_PARTNERS, no executor, no duplicate (a repeat becomes 0 = random), trailing randoms dropped
local function clean(exec, partners)
  local v = {}
  for i = 1, math.min(#partners, MAX_PARTNERS) do
    local p = partners[i]
    local dup = false
    for _, x in ipairs(v) do
      dup = dup or (p ~= 0 and x == p)
    end
    v[#v + 1] = (p == exec or dup) and 0 or p
  end
  while #v > 0 and v[#v] == 0 do
    v[#v] = nil
  end
  return v
end

local function set_choices(f, hdl, param, skill, partners)
  local v = clean(hdl, partners)
  for i, p in ipairs(v) do
    if is_staff(p) then
      VRFW.log(string.format("0x%08X skill 0x%08X: partner 0x%08X is a coach / manager -> random", hdl, skill, p))
      v[i] = 0
    end
  end
  while #v > 0 and v[#v] == 0 do
    v[#v] = nil
  end
  local k = key(hdl)
  local e = f.players[k]
  if not e or e.param_id ~= param then
    e = { param_id = param, moves = {} }
    f.players[k] = e
  end
  e.moves = e.moves or {}
  e.moves[key(skill)] = (#v > 0) and v or nil
  if next(e.moves) == nil then
    f.players[k] = nil
  end
end

local function param_of(hdl)
  local r = VRFW.chara.record(hdl)
  return r and r.param or nil
end

-- ---------------------------------------------------------------------------------------------- the match

local function actor_at(i)
  local base = VRFW.game.soccer_actors()
  if not base then
    return nil
  end
  local ok, a = pcall(VRFW.mem.struct, "Actor", base + i * ACTOR_STRIDE)
  return ok and a or nil
end

local function actor_of_handle(hdl)
  if hdl == 0 then
    return nil
  end
  local a = actor_at(bit32.band(hdl, 0xFF))
  if a and a.handle == hdl then
    return a
  end
  return nil
end

local function owner_of_actor(a)
  local ch = a.chara
  if ch == 0 then
    return nil
  end
  return VRFW.chara.owner(ch)
end

-- on-pitch teammates of `team` (except `exec`): { actor handle, saved owner }
local function teammates(team, exec)
  local v = {}
  for i = 0, ACTOR_MAX - 1 do
    local a = actor_at(i)
    if not a then
      break
    end
    local hdl = a.handle
    if hdl ~= 0 and hdl ~= exec and bit32.band(hdl, 0xFF) == i and a.team == team then
      local ok, on = pcall(VRFW.call, "IsActorOnPitch", VRFW.mem.addr(a), 0)
      if ok and bit32.band(on or 0, 0xFF) ~= 0 then
        local o = owner_of_actor(a)
        if o then
          v[#v + 1] = { hdl, o }
        end
      end
    end
  end
  return v
end

-- swap the chosen partners into cast[1..slots] (cast[0] = executor); wants[slot]: false / nil = the engine's pick,
-- { owner, actor or nil }. A named partner's slot is replaced like any other: the named partner is only the default.
local function apply(cast, slots, wants)
  local out, placed = {}, {}
  for slot = 1, slots do
    local w = wants[slot]
    if not w then
      out[#out + 1] = string.format("slot %d random 0x%X", slot, cast[slot])
    elseif not w[2] then
      out[#out + 1] = string.format("slot %d 0x%08X not on the pitch -> engine pick 0x%X", slot, w[1], cast[slot])
    else
      local a = w[2]
      local src
      for j = 0, #cast do
        if cast[j] == a and src == nil then
          src = j
        end
      end
      local bad = a == 0 or placed[a] or src == 0
      if bad then
        out[#out + 1] = string.format("slot %d 0x%08X fallback -> engine pick 0x%X", slot, w[1], cast[slot])
      else
        if src ~= nil and src ~= slot then
          cast[slot], cast[src] = cast[src], cast[slot]
        elseif src == nil then
          cast[slot] = a
        end
        placed[a] = true
        out[#out + 1] = string.format("slot %d chosen 0x%08X (actor 0x%X)", slot, w[1], a)
      end
    end
  end
  return table.concat(out, ", ")
end

local last_none = ""

local function on_cast(cast_at, len, rec_at)
  local ok, rec = pcall(VRFW.mem.struct, "SkillInfo", rec_at)
  if not ok then
    return
  end
  local sp = partners_of(rec)
  if not sp or sp.slots == 0 then
    return
  end
  local skill = rec.skill
  local cast = {}
  for k = 0, len - 1 do
    cast[k] = VRFW.mem.read("u32", cast_at + 4 * k)
  end
  local exec = cast[0]
  local ea = actor_of_handle(exec)
  if not ea then
    return
  end
  local owner = owner_of_actor(ea)
  local pid = owner and param_of(owner)
  if not pid then
    return
  end
  local chosen = choices(load_cached(), owner, pid, skill)
  if #chosen == 0 then
    local tag = key(skill) .. key(owner)
    if tag ~= last_none then
      last_none = tag
      VRFW.log(string.format("skill 0x%08X (%d performers) by 0x%08X (actor 0x%X): no choice saved", skill, sp.performers, owner, exec))
    end
    return
  end
  local slots = math.min(sp.slots, len - 1)
  local team = ea.team
  local mates = teammates(team, exec)
  local wants = {}
  for i, o in ipairs(chosen) do
    if o == 0 or is_staff(o) then          -- a coach / manager (an older save): the engine's pick
      wants[i] = false
    else
      local actor
      for _, m in ipairs(mates) do
        if m[2] == o and actor == nil then
          actor = m[1]
        end
      end
      wants[i] = { o, actor }
    end
  end
  local before = {}
  for k = 1, slots do
    before[k] = string.format("%X", cast[k])
  end
  local what = apply(cast, slots, wants)
  local after = {}
  for k = 1, slots do
    after[k] = string.format("%X", cast[k])
    VRFW.mem.write("u32", cast_at + 4 * k, cast[k])
  end
  VRFW.log(string.format("skill 0x%08X (%d performers) by 0x%08X (actor 0x%X, team %d, %d on-pitch mates): %s; cast [%s] -> [%s]", skill, sp.performers, owner, exec, team, #mates, what, table.concat(before, " "), table.concat(after, " ")))
end

-- BuildEventCast(ctx, cast, n, rec, ex, acting, lv, mode): after the engine built the cast
VRFW.on("hook:BuildEventCast:post", function(ev)
  local a = ev.args
  local cast, n, rec, acting = a[2], a[3], a[4], a[6]
  if cast == 0 or rec == 0 or acting == 0 or n < 2 or n > 32 then
    return nil
  end
  on_cast(cast, n, rec)
  return nil
end)

-- ---------------------------------------------------------------------------------------------- the commands

-- skill -> performers, free, named1, named2, named3 (performers 0 = unknown move)
function Utilities.ComboInfo(skill)
  local sp = skill_partners(arg_u32(skill))
  if not sp then
    return 0, 0, 0, 0, 0
  end
  return sp.performers, sp.free, sp.named[1] or 0, sp.named[2] or 0, sp.named[3] or 0
end

-- charaStHdl, skill -> ok, p1, p2, p3 (0 = random)
function Utilities.ComboGet(hdl, skill)
  hdl, skill = arg_u32(hdl), arg_u32(skill)
  local pid = param_of(hdl)
  if not pid then
    return false
  end
  local v = choices(load_fresh(), hdl, pid, skill)
  return true, v[1] or 0, v[2] or 0, v[3] or 0
end

-- charaStHdl, skill, p1[, p2, p3] -> ok: p<k> = partner slot k, named slots included (0 = the engine's pick; the list
-- is cut to the move's partner slots; all 0 = the move's entry removed)
function Utilities.ComboSet(hdl, skill, p1, p2, p3)
  hdl, skill = arg_u32(hdl), arg_u32(skill)
  local v = { arg_u32(p1), arg_u32(p2), arg_u32(p3) }
  local sp = skill_partners(skill)
  if sp then
    for k = #v, sp.slots + 1, -1 do
      v[k] = nil
    end
  end
  local pid = param_of(hdl)
  if not pid or skill == 0 then
    return false
  end
  local f = load_fresh()
  set_choices(f, hdl, pid, skill, v)
  local saved = choices(f, hdl, pid, skill)
  return write(f, string.format("0x%08X skill 0x%08X partners %s", hdl, skill, table.concat(saved, ",")))
end

-- charaStHdl[, skill] -> ok (no skill = every move of the player)
function Utilities.ComboClear(hdl, skill)
  hdl, skill = arg_u32(hdl), arg_u32(skill)
  local pid = param_of(hdl)
  if not pid then
    return false
  end
  local f = load_fresh()
  if skill == 0 then
    if not f.players[key(hdl)] then
      return true
    end
    f.players[key(hdl)] = nil
    return write(f, string.format("0x%08X every move cleared", hdl))
  end
  if #choices(f, hdl, pid, skill) == 0 then
    return true
  end
  set_choices(f, hdl, pid, skill, {})
  return write(f, string.format("0x%08X skill 0x%08X cleared", hdl, skill))
end

-- the hold timers, one per (mask, keys) query: { since, last poll }
local holds = {}

-- mask[, vk …] -> seconds the pad buttons `mask` (g_pad + 8, Y = 0x1000) or any of the keys have been held without a
-- break; 0 = not held now; -1 = neither the pad nor the keyboard can be read
function Utilities.PadHeld(mask, ...)
  mask = arg_u32(mask)
  local vks = {}
  for _, k in ipairs({ ... }) do
    if type(k) == "number" then
      vks[#vks + 1] = math.floor(k)
    end
  end
  local pad = (mask ~= 0) and VRFW.input.pad() or nil
  local key_held = (#vks > 0) and VRFW.input.key(table.unpack(vks)) or nil
  if pad == nil and key_held == nil then
    return -1
  end
  local held = (pad ~= nil and bit32.band(pad, mask) == mask) or key_held == true
  local id = tostring(mask) .. ":" .. table.concat(vks, ",")
  local now = VRFW.now()
  local e = holds[id]
  if not held then
    holds[id] = nil
    return 0
  end
  if e and now - e[2] <= HELD_STALE_MS then
    e[2] = now
    return (now - e[1]) / 1000
  end
  holds[id] = { now, now }
  return 0.001
end
