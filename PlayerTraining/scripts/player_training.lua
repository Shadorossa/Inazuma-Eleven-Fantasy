-- Player Training › classic training (Chrono Stone rules): each player spreads his Libertad points over his base stats
-- (docs/game/mechanics/training-classic.md, stat-training.md). Moved from Inazuma Fantasy's scripts\training.lua on
-- 2026-10-14 (same rules, answers and saved data). The commands are content\game\player_training.toml; the old names
-- CMND_EVT_TRAIN_* are aliases (the training window evt_training_menu and the skill table's training mode call them):
--
--   CMND_PLAYERTRAINING_INFO(charaStHdl, fresh)  -> ok, status, libTotal, libAvail, level, position, dirty, growthType, rule
--   CMND_PLAYERTRAINING_STAT(charaStHdl, idx)    -> ok, value, base, bonus, delta, committed, min, max, partner1, partner2
--   CMND_PLAYERTRAINING_SET(charaStHdl, idx, d)  -> ok, stop, reached, libAvail, d0 … d8
--   CMND_PLAYERTRAINING_COMMIT(charaStHdl)       -> ok, status
--   CMND_PLAYERTRAINING_CANCEL(charaStHdl)       -> ok        (0 = every session)
--   CMND_PLAYERTRAINING_RESET(charaStHdl)        -> ok, libAvail
--   CMND_PLAYERTRAINING_LUCK_DELTA(charaStHdl)   -> the committed Suerte delta (0 = none)
--
-- (rule 0 pairs / 1 pool / 2 trade; position 1 GK 2 FW 3 MF 4 DF; growthType 0 slow 1 normal 2 fast; fresh = 1 drops
-- the working copy first.) A session per character holds the committed deltas (prm_growth[0..7] + the Suerte delta of
-- the slot blob training.json, lib/training_store.lua) and a working copy SET / RESET change; nothing reaches the game
-- before COMMIT (prm_growth written in memory, saved by the game at its next save; Suerte into the blob). A session whose
-- committed prm_growth no longer matches memory (a load, a slot switch) is rebuilt from memory first. Cards of a locked
-- rarity (config.toml [training] locked_rarities) answer -9. The per-card values (Libertad, Suerte, position, growth)
-- are Character Reforged's (its exports); the commands answer false until it published them. The trained points reach
-- matches through the framework's match-build service ([[VRFW.MatchStat]] PlayerTraining.TrainedPoints, while the
-- state player_training.active = 1, set here).
--
-- Exports (mod.toml [exports]): Info / Stat / Set / Commit / Cancel / Reset (the commands) and LuckDelta(hdl) (the
-- committed Suerte delta: Inazuma Fantasy's CMND_EVT_CHARA_STAT adds it to the Suerte it shows).

local CS = require "lib/card_stats"
local V = require "lib/chara_view"
local R = require "lib/training_rules"
local S = require "lib/training_store"

PlayerTraining = PlayerTraining or {}

local function info(...) VRFW.log("training:", ...) end
local function warn(...) VRFW.warn("training:", ...) end
local function err(...) VRFW.error("training:", ...) end

local ERR_BAD_ARGS, ERR_NOT_READY, ERR_NO_DATA, ERR_WRITE, ERR_LOCKED = -1, -2, -6, -8, -9
local N = R.N
local STATE_KEY = "player_training.active"

local ON = false
local RULES = { rule = "trade", floor_percent = 0, max_value = 9999 }
local LOCKED = {}
local PLAYERS
local SESSIONS = {}
local STORE -- { slot, file }

-- ---------------------------------------------------------------------------------------------- helpers

local function num(v)
  if type(v) == "number" then return v end
  if type(v) == "string" then return tonumber(v) end
  return nil
end

local function int(v)
  v = num(v)
  if not v or v ~= v then return nil end
  return v >= 0 and math.floor(v) or math.ceil(v)
end

local function hdl_arg(v) return CS.u32(num(v) or 0) end

local function idx_arg(v)
  local i = int(v)
  if i and i >= 0 and i < N then return i end
  return nil
end

local function hex(v) return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536) end

local function list(d)
  local t = {}
  for i = 0, N - 1 do t[#t + 1] = tostring(d[i]) end
  return "[" .. table.concat(t, ", ") .. "]"
end

-- a value of this mod's config.toml (dotted path), `default` when missing or of another type
local function cfg(path, default)
  local ok, v = pcall(VRFW.files.config, path)
  if not ok or v == nil then return default end
  if default ~= nil and type(v) ~= type(default) then return default end
  return v
end

-- the training answers while Character Reforged's per-card values are published; otherwise false (as before)
local function active()
  return ON and CS.ready()
end

local function players()
  if not PLAYERS then PLAYERS = CS.players() end
  return PLAYERS
end

-- ---------------------------------------------------------------------------------------------- Suerte store

-- the store of the active slot (loaded on first use and after a slot change)
local function store()
  local s = VRFW.slots.active()
  if not STORE or STORE.slot ~= s then
    local f, why = S.load(s)
    if not f then
      err(string.format("slot %d: Suerte store unreadable (%s): deltas start at 0 (the stored version is kept in the backups at the next commit)", s, tostring(why)))
      f = S.empty()
    end
    STORE = { slot = s, file = f }
  end
  return STORE.file, STORE.slot
end

-- ---------------------------------------------------------------------------------------------- characters, sessions

-- everything a command needs about one character, or nil + error code
local function load_player(hdl)
  if hdl == 0 then return nil, ERR_BAD_ARGS end
  local view, e = V.view(hdl)
  if not view then return nil, e end
  local p = players()[CS.u32(view.param_id)]
  if not p then return nil, ERR_NO_DATA end
  if CS.locked(p, LOCKED) then return nil, ERR_LOCKED end
  local level, le = V.level(view.obj)
  if not level then return nil, le end
  local base, bonus = {}, {}
  for i = 0, 7 do
    local b, sum = V.param_stat(view.params, i)
    if b == nil then return nil, ERR_NOT_READY end
    base[i] = b
    bonus[i] = math.max(sum, 1) - b -- shown = max(1, sum of the 5 arrays) + prm_growth, as GetCharaStat 0xD87C40
  end
  base[R.LUCK] = CS.stat(p, R.LUCK, level)
  bonus[R.LUCK] = 0
  local total = CS.libertad(p, level)
  local mem_g = V.prm_growth(view.rec)
  if not mem_g then return nil, ERR_NOT_READY end
  return { view = view, stats = p, level = level, ctx = R.ctx(RULES, R.position(p.pos), base, bonus, total), mem_g = mem_g }
end

local function committed_of(pl, hdl)
  local c = {}
  for i = 0, 7 do c[i] = pl.mem_g[i + 1] end
  c[R.LUCK] = S.suerte(store(), hdl, pl.view.param_id, pl.mem_g)
  return c
end

-- the session of hdl (created or rebuilt from memory when needed): pl, session or nil + error code
local function session(hdl, fresh)
  local pl, e = load_player(hdl)
  if not pl then return nil, e end
  local s = SESSIONS[hdl]
  local stale = not s or s.param_id ~= pl.view.param_id
  if s and not stale then
    for i = 0, 7 do
      if s.committed[i] ~= pl.mem_g[i + 1] then stale = true end
    end
  end
  if fresh or stale then
    if not fresh and s then
      warn(string.format("%s: prm_growth changed under an open session (load / slot switch): working copy dropped", hex(hdl)))
    end
    local c = committed_of(pl, hdl)
    s = { param_id = pl.view.param_id, committed = c, working = R.copy(c) }
    SESSIONS[hdl] = s
  end
  return pl, s
end

-- ---------------------------------------------------------------------------------------------- commands

function PlayerTraining.Info(hdl, fresh)
  if not active() then return false end
  hdl = hdl_arg(hdl)
  local f = num(fresh)
  local pl, s = session(hdl, f ~= nil and f ~= 0)
  local rule = R.rule_code(RULES.rule)
  if not pl then
    info(string.format("INFO(%s) -> error %d", hex(hdl), s))
    return false, s, 0, 0, 0, 0, false, 0, rule
  end
  local c = pl.ctx
  return true, 0, c.total, R.available(c, s.working), pl.level, c.pos, not R.equal(s.working, s.committed), pl.stats.growth, rule
end

function PlayerTraining.Stat(hdl, idx)
  if not active() then return false end
  hdl = hdl_arg(hdl)
  local i = idx_arg(idx)
  if not i then
    return false, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS, ERR_BAD_ARGS
  end
  local pl, s = session(hdl, false)
  if not pl then return false, s, s, s, s, s, s, s, s, s end
  local c = pl.ctx
  local min, reach = R.range(c, s.working, i)
  local max = math.max(R.cap(c, s.working, i), reach)
  local pr = R.partners(c.pos, i)
  return true, R.value(c, s.working, i), c.base[i], c.bonus[i], s.working[i], s.committed[i], min, max, pr[1] or -1, pr[2] or -1
end

local function fail(code, extra)
  local out = { false, code }
  for k = 1, extra do out[#out + 1] = 0 end
  return table.unpack(out)
end

function PlayerTraining.Set(hdl, idx, target)
  if not active() then return false end
  hdl = hdl_arg(hdl)
  local i, t = idx_arg(idx), int(target)
  if not i or not t then return fail(ERR_BAD_ARGS, 2 + N) end
  t = math.max(-99999, math.min(99999, t))
  local pl, s = session(hdl, false)
  if not pl then return fail(s, 2 + N) end
  local reached, stop = R.set(pl.ctx, s.working, i, t)
  local d = s.working
  return stop == R.NONE, stop, reached, R.available(pl.ctx, d), d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8]
end

function PlayerTraining.Commit(hdl)
  if not active() then return false end
  hdl = hdl_arg(hdl)
  local pl, s = session(hdl, false)
  if not pl then return false, s end
  local g = {}
  for i = 0, 7 do g[i + 1] = s.working[i] end
  if not V.write_prm_growth(pl.view.rec, g) then
    err(string.format("COMMIT(%s): prm_growth write failed", hex(hdl)))
    return false, ERR_WRITE
  end
  local f, slot = store()
  if S.record(f, hdl, pl.view.param_id, g, s.working[R.LUCK]) then
    local ok, where = S.save(f, slot)
    if not ok then err("cannot write: " .. tostring(where)) end
  end
  info(string.format("COMMIT %s (id %d): %s -> %s, Libertad %d/%d", hex(hdl), pl.view.param_id, list(s.committed), list(s.working),
    R.available(pl.ctx, s.working), pl.ctx.total))
  s.committed = R.copy(s.working)
  return true, 0
end

function PlayerTraining.Cancel(hdl)
  if not active() then return false end
  hdl = hdl_arg(hdl)
  if hdl == 0 then SESSIONS = {} else SESSIONS[hdl] = nil end
  return true
end

function PlayerTraining.Reset(hdl)
  if not active() then return false end
  hdl = hdl_arg(hdl)
  local pl, s = session(hdl, false)
  if not pl then return false, s end
  s.working = R.zeros()
  return true, R.available(pl.ctx, s.working)
end

-- the committed Suerte delta of a character (0 when none / the training is off): the Suerte other mods show adds it
function PlayerTraining.LuckDelta(hdl)
  if not ON then return 0 end
  hdl = hdl_arg(hdl)
  if hdl == 0 then return 0 end
  local view = V.view(hdl)
  if not view then return 0 end
  local g = V.prm_growth(view.rec)
  if not g then return 0 end
  local ok, f = pcall(store)
  if not ok or not f then return 0 end
  return S.suerte(f, hdl, view.param_id, g)
end

-- ---------------------------------------------------------------------------------------------- the training beans

-- The training replaces the retail beans (content\game\player_training.toml «the training beans»): the stat term is
-- zeroed natively (hook PlayerTraining.BeansGiveNothing) and the team auto-equip skipped (PlayerTraining.NoBeanAutoEquip).

-- CMND_PLAYERTRAINING_BEANS_OFF() -> true while an equipped bean adds nothing (the board's bean slot message)
function PlayerTraining.BeansOff()
  return VRFW.is_on("PlayerTraining.BeansGiveNothing") == true
end

-- retail 0x2086CD04 («Autoequipar judías» get): always off
function PlayerTraining.AutoBeansGet()
  return true, false
end

-- retail 0x799BDB53 («Autoequipar judías» set): ignored (the setting stays as it is; no automatic equip runs anyway)
function PlayerTraining.AutoBeansSet()
  return true
end

-- ---------------------------------------------------------------------------------------------- start

local function start()
  local name = cfg("training.rule", "trade")
  local rule = R.parse_rule(name)
  if not rule then
    warn(string.format("[training] rule = %q unknown (\"trade\", \"pool\" or \"pairs\"): using trade", tostring(name)))
    rule = "trade"
  end
  local fp = cfg("training.floor_percent", 0)
  local mv = cfg("training.max_value", 9999)
  RULES = { rule = rule, floor_percent = math.floor(fp), max_value = math.floor(mv) }
  LOCKED = {}
  local lr = cfg("training.locked_rarities", {})
  if type(lr) == "table" then
    for _, r in ipairs(lr) do
      if type(r) == "number" then LOCKED[math.floor(r)] = true end
    end
  end
  if not V.ready() then
    err("FindCharaRecord / GetLevel / the character containers not resolved: the training commands answer false")
    return
  end
  ON = true
  local ok, e = pcall(VRFW.state.set, STATE_KEY, 1)
  if not ok then err(STATE_KEY .. ": " .. tostring(e)) end
  info(string.format("commands active (rule %s, floor %d %% of the untrained base, max value %d); Suerte blob %s per slot; the match copies get the trained points (PlayerTraining.TrainedPoints: %s)",
    rule, math.max(0, math.min(100, RULES.floor_percent)), math.max(1, math.min(9999, RULES.max_value)), S.BLOB, VRFW.is_on("PlayerTraining.TrainedPoints") and "on" or "OFF"))
end

-- the save's loading screen: the slot's Suerte store ready before the first training command (the same cache the
-- commands fill on first use)
VRFW.on("slot_load", function()
  if not ON then return nil end
  local ok, e = pcall(store)
  if not ok then warn("slot_load: Suerte store: " .. tostring(e)) end
  return nil
end)

start()
