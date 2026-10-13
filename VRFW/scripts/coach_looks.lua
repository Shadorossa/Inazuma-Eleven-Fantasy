-- VR-Framework › coach clothes rules (service S13 of VRFW 2.3, docs/framework/outfits.md §8). Declarations: every
-- active mod's content\coach_looks\*.toml (`VRFW.coach_look/1`, keys: content\types\coach_look.toml); native side:
-- content\game\coach_looks.toml (hook CoachLooks.CostumeLookup, installed only when a mod declares a rule).
--
-- SoccerCostumeLookup(out*, &charaId, lookFlags, &uniform) dresses a model. On a VS screen / pitch a coach is looked
-- up twice: with the coach flag 0x10 (his coach clothes) and then without the coach / manager flags (the player-kit
-- path: that call dresses the model). Every character answered with a costume under the coach flag is remembered (with
-- the uniform of that call); while a declared rule holds, a call WITHOUT the coach / manager flags for such a character
-- is run again with the coach flag (and his coach call's uniform when the caller passes none), and that answer is
-- returned when it finds a costume. A rule holds while one of its game_state keys is 1, one of its UI flags has one of
-- its values, or always.
--
--   * CMND_VRFW_COACH_LOOK() -> active, live.

CoachLooks = CoachLooks or {}

local D = require "lib/declarations"

local band, bor = bit32.band, bit32.bor
local HOOK = "CoachLooks.CostumeLookup"
local FLAG_COACH, FLAG_STAFF = 0x10, 0x30
local MAX_FIX_LINES = 60

local function info(...) VRFW.log("coach_looks:", ...) end
local function warn(...) VRFW.warn("coach_looks:", ...) end

local RULES = {}         -- { key, states, flags, values (set | nil), always }
local LIVE = false

-- chara id -> the uniform of his coach call (0 = the caller passed none)
local coaches = {}
local fix_lines = 0

local function rd32(at)
  if not at or at < 0x10000 then return 0 end
  local ok, v = pcall(VRFW.mem.read, "u32", at)
  if ok and v then return v end
  return 0
end

local function wr32(at, v)
  if not at or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, "u32", at, v))
end

-- "%08X" of a u32 (Lua 5.2 on Windows formats integers through a 32-bit long: split in halves)
local function hex(v)
  v = v or 0
  return string.format("%04X%04X", math.floor(v / 65536) % 65536, v % 65536)
end

local function holds(r)
  if r.always then return true end
  for _, k in ipairs(r.states) do
    local ok, v = pcall(VRFW.state.get, k)
    if ok and v == 1 then return true end
  end
  for _, f in ipairs(r.flags) do
    local ok, v = pcall(VRFW.ui.flag, f)
    if ok and type(v) == "number" then
      if r.values then
        if r.values[v] then return true end
      elseif v ~= 0 then
        return true
      end
    end
  end
  return false
end

local function active()
  for _, r in ipairs(RULES) do
    if holds(r) then return true, r end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------- the hook

local function on_lookup_post(ev)
  local out, pchara, flags, puni = ev.args[1], ev.args[2], ev.args[3] or 0, ev.args[4]
  local f = band(flags, 0xFF)
  local chara = rd32(pchara)
  if chara == 0 then return nil end
  if band(f, FLAG_COACH) ~= 0 then
    if band(ev.ret or 0, 0xFF) == 1 and rd32(out) ~= 0 then
      local uni = rd32(puni)
      if coaches[chara] == nil or uni ~= 0 then coaches[chara] = uni end
    end
    return nil
  end
  if band(f, FLAG_STAFF) ~= 0 then return nil end
  local cuni = coaches[chara]
  if cuni == nil then return nil end
  local on, rule = active()
  if not on then return nil end
  local uni = rd32(puni)
  if uni == 0 then uni = cuni end
  local tmp = VRFW.mem.buffer("coach_looks.out", 32)
  local unib = VRFW.mem.buffer("coach_looks.uniform", 8)
  for i = 0, 28, 4 do wr32(tmp + i, 0) end
  wr32(unib, uni)
  local ok, r2 = pcall(VRFW.hook.original, HOOK, tmp, pchara, bor(flags, FLAG_COACH), unib)
  if not ok then return nil end
  local costume = rd32(tmp)
  local fixed = band(r2 or 0, 0xFF) == 1 and costume ~= 0
  if fixed then
    wr32(out, costume)
    wr32(out and out + 4, 0)
  end
  if fix_lines < MAX_FIX_LINES then
    fix_lines = fix_lines + 1
    VRFW.log(string.format("coach_looks: chara 0x%s flags 0x%02X uniform 0x%s (%s): coach lookup (uniform 0x%s) -> %d costume 0x%s%s",
      hex(chara), f, hex(rd32(puni)), rule.key, hex(uni), band(r2 or 0, 0xFF), hex(costume), fixed and ": coach clothes returned" or ": kept the player look"))
  end
  if fixed then return { ret = r2 } end
  return nil
end

-- ---------------------------------------------------------------------------------------------- declarations

local function start()
  local schema, why = D.schema("coach_look")
  if not schema then
    warn(why .. ": coaches are dressed as the game dresses them")
    return
  end
  local decls, skipped = D.load(schema, warn)
  local parts = {}
  for _, d in ipairs(decls) do
    local v = d.v
    local states, flags = v.states or {}, v.ui_flags or {}
    if not v.always and #states == 0 and #flags == 0 then
      warn(string.format("%s: no condition (states, ui_flags or always = true): left out", d.where))
    else
      local values
      if v.ui_values and #v.ui_values > 0 then
        values = {}
        for _, x in ipairs(v.ui_values) do values[x] = true end
      end
      RULES[#RULES + 1] = { key = d.key, states = states, flags = flags, values = values, always = v.always }
      local c = {}
      if v.always then c[#c + 1] = "always" end
      for _, k in ipairs(states) do c[#c + 1] = k .. " = 1" end
      for _, k in ipairs(flags) do c[#c + 1] = "flag " .. k .. (values and (" in " .. table.concat(v.ui_values, "/")) or " ~= 0") end
      parts[#parts + 1] = string.format("%s (%s)", d.key, table.concat(c, " or "))
    end
  end
  if #RULES == 0 then
    if #decls > 0 or (skipped or 0) > 0 then
      info(string.format("off: %d declaration(s) (%d left out by `when`), no rule in force: the game's coach clothes", #decls, skipped or 0))
    else
      info("off: no mod declares a coach clothes rule: the game's coach clothes")
    end
    return
  end
  local ok, done, e = pcall(VRFW.hook.apply, HOOK)
  LIVE = ok and done == true
  if LIVE then
    info("on: coaches keep their coach clothes while " .. table.concat(parts, ", "))
  else
    warn(string.format("detour %s not installed (%s): the game's coach clothes", HOOK, tostring(ok and e or done)))
  end
end

-- CMND_VRFW_COACH_LOOK() -> active, live
function CoachLooks.Cmd()
  return (active()) == true, LIVE
end

start()

if LIVE then
  VRFW.on("hook:" .. HOOK .. ":post", on_lookup_post)
end
