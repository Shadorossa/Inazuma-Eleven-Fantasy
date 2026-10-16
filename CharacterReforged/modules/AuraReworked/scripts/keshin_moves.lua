-- Aura Reworked › All Keshin Armed › «Only the keshin's move while it is out» (Mods options row keshin_own_move_only,
-- off by default): while a player has his keshin out (or its armour), his move slots are greyed except the keshin's
-- own move (the armour forms use their keshin's move). Read from the game, nothing named here:
--   * who has a keshin out: every frame (`tick`) the soccer actors' summon machine (content\game\keshin_moves.toml:
--     the aura it runs, state 2 = out) and the unit's aura bits (keshin 1, armour 2);
--   * the keshin's own move: its row of the served aura_skill_config (lib/auras.lua, col 6), an armour's keshin through
--     the framework's armour pairs (VRFW.form.spirit_of);
--   * the refusal: the rule trigger `move_check` answered { block = true } (the HUD, the input and the AI).

AuraReworked = AuraReworked or {}
AuraReworked.KeshinMoves = AuraReworked.KeshinMoves or {}
-- the part's switch (Mods options › All Keshin Armed, applied after a restart): off = nothing of this part runs
if VRFW.option("all_keshin_armed") == 0 then return end

local A = require "lib/auras"

local function info(...) VRFW.log("aura_reworked keshin:", ...) end

local band = bit32.band
local function hex(v) return string.format("0x%X", v or 0) end

-- game layout (docs/game/mechanics/keshin-armed.md §2.2): the soccer actors and the summon machine
local ACTOR_MAX, ACTOR_STRIDE = 0x3A, 0x570
local SUMMON_ACTIVE = 2
local ATTR_KESHIN, ATTR_ARMOUR = 1, 2

local on = false          -- the option, read at every match start
local out = {}            -- hdl -> the aura he runs now (a keshin or its armour)
local own = {}            -- aura -> its keshin's own move (cache)
local said = {}           -- hdl -> the aura already logged

local function u32(v)
  v = tonumber(v) or 0
  if v < 0 then v = v + 4294967296 end
  return math.floor(v) % 4294967296
end

-- the keshin's own move of aura `aura` (an armour: its keshin's)
local function own_move(aura)
  if own[aura] then return own[aura] end
  A.load()
  local m = A.move(aura)
  if m == 0 then
    local ok, spirit = pcall(VRFW.form.spirit_of, aura)
    if ok and u32(spirit) ~= 0 then m = A.move(u32(spirit)) end
  end
  own[aura] = m
  return m
end

local function base_actors()
  local ok, b = pcall(VRFW.game.km_actors)
  if ok and type(b) == "number" and b >= 0x10000 then return b end
  return nil
end

VRFW.on("match_start", function(ev)
  on = VRFW.option("keshin_own_move_only") == 1
  out, said = {}, {}
  if on then info("match start: only the keshin's own move while a keshin is out") end
  return nil
end)

VRFW.on("match_end", function(ev)
  out, said = {}, {}
  return nil
end)

VRFW.on("tick", function(ev)
  if not on then return nil end
  local base = base_actors()
  if not base then return nil end
  local now = {}
  for i = 0, ACTOR_MAX - 1 do
    local actor = base + i * ACTOR_STRIDE
    local a = VRFW.mem.read_struct("KmActor", actor)
    if a and a.hdl ~= 0 and band(a.hdl, 0xFF) == i and a.team <= 1 and a.summon_state == SUMMON_ACTIVE then
      local ok, u = pcall(VRFW.call, "KmActorUnit", actor)
      if ok and type(u) == "number" and u >= 0x10000 then
        local okr, attr = pcall(VRFW.mem.read, "u8", u + 0x2B4)
        if okr and type(attr) == "number" and band(attr, ATTR_KESHIN + ATTR_ARMOUR) ~= 0 then
          now[a.hdl] = u32(a.summon_skill)
        end
      end
    end
  end
  out = now
  return nil
end)

VRFW.on("move_check", function(ev)
  if not on then return nil end
  local h = ev.actor and ev.actor.handle and u32(ev.actor.handle)
  local aura = h and out[h]
  if not aura or not ev.skill or ev.skill == 0 then return nil end
  local m = own_move(aura)
  if m == 0 or u32(ev.skill) == m then return nil end
  if said[h] ~= aura then
    said[h] = aura
    info(string.format("actor %s: keshin %s out: only its move %s (move %s greyed)", hex(h), A.key(aura), hex(m), hex(u32(ev.skill))))
  end
  return { block = true }
end)
