-- Aura Reworked › All Keshin Armed › «Only the keshin's move while it is out» (Mods options row keshin_own_move_only,
-- off by default): while a player has his keshin out (or its armour), his move slots are greyed except the keshin's
-- own move (the armour forms use their keshin's move). Read from the game, nothing named here:
--   * who has a keshin out: after each aura command the engine executes (event `match:aura:post`) the soccer actors
--     whose summon machine or aura bits run become candidates; a move check of a candidate reads his summon machine
--     (content\game\keshin_moves.toml: the aura it runs, state 2 = out) and the unit's aura bits (keshin 1, armour 2)
--     at that moment (once per moment), and drops him when neither runs any more;
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
local cand = {}           -- hdl -> true: an aura command ran since he was last seen without a summon / aura bits
local seen = {}           -- hdl -> { at = VRFW.now(), aura = the aura he runs then (0 = none) }
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
  cand, seen, said = {}, {}, {}
  if on then info("match start: only the keshin's own move while a keshin is out") end
  return nil
end)

VRFW.on("match_end", function(ev)
  cand, seen, said = {}, {}, {}
  return nil
end)

-- the aura actor `actor` (handle `hdl`) runs now: his summon machine's aura while it is out and his unit has the keshin
-- or armour bit (0 = none); `alive` = his summon machine or aura bits still run (he stays a candidate)
local function running(actor, hdl)
  local a = VRFW.mem.read_struct("KmActor", actor)
  if not a or a.hdl ~= hdl or a.team > 1 then return 0, false end
  local ok, u = pcall(VRFW.call, "KmActorUnit", actor)
  local attr = 0
  if ok and type(u) == "number" and u >= 0x10000 then
    local okr, x = pcall(VRFW.mem.read, "u8", u + 0x2B4)
    if okr and type(x) == "number" then attr = x end
  end
  local bits = band(attr, ATTR_KESHIN + ATTR_ARMOUR) ~= 0
  if a.summon_state == SUMMON_ACTIVE and bits then return u32(a.summon_skill), true end
  return 0, bits or (a.summon_state or 0) ~= 0
end

-- an aura command ran (keshin, armour, miximax, soul): every pitch actor whose summon machine or aura bits run is a
-- candidate (the command's actor among them)
VRFW.on("match:aura:post", function(ev)
  if not on then return nil end
  local base = base_actors()
  if not base then return nil end
  for i = 0, ACTOR_MAX - 1 do
    local actor = base + i * ACTOR_STRIDE
    local a = VRFW.mem.read_struct("KmActor", actor)
    if a and a.hdl ~= 0 and band(a.hdl, 0xFF) == i and a.team <= 1 then
      local _, alive = running(actor, a.hdl)
      if alive then cand[u32(a.hdl)] = true end
    end
  end
  return nil
end)

-- the aura candidate `h` runs now (0 = none; read once per moment)
local function aura_of(h)
  if not cand[h] then return 0 end
  local now = VRFW.now()
  local s = seen[h]
  if s and s.at == now then return s.aura end
  local base = base_actors()
  local aura, alive = 0, false
  if base then aura, alive = running(base + band(h, 0xFF) * ACTOR_STRIDE, h) end
  if not alive then cand[h] = nil end
  seen[h] = { at = now, aura = aura }
  return aura
end

VRFW.on("move_check", function(ev)
  if not on then return nil end
  local h = ev.actor and ev.actor.handle and u32(ev.actor.handle)
  if not h or not ev.skill or ev.skill == 0 then return nil end
  local aura = aura_of(h)
  if aura == 0 then return nil end
  local m = own_move(aura)
  if m == 0 or u32(ev.skill) == m then return nil end
  if said[h] ~= aura then
    said[h] = aura
    info(string.format("actor %s: keshin %s out: only its move %s (move %s greyed)", hex(h), A.key(aura), hex(m), hex(u32(ev.skill))))
  end
  return { block = true }
end)
