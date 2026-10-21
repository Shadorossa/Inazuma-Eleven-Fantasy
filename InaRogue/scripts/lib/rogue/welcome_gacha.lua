-- InaRogue › the welcome gacha of the first INAROGUE entry (docs/game/modes/inarogue-welcome-gacha.md). Data:
-- content\rogue\welcome_gacha.toml; commands: content\game\welcome_gacha.toml.
--
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_INAROGUE_WELCOME_DRAW | – | n: the first-run gift granted and kept for the gacha (0 = nothing) |
-- | CMND_INAROGUE_WELCOME_INFO | i (0-based) | ok, param, stars, rarity (the card type, for a temporary chara) |
-- | CMND_INAROGUE_WELCOME_BALLS | – | { orbs, orb digit × orbs, bust-up param × bustups } |
-- | CMND_INAROGUE_WELCOME_STATE | [state] | state: 0 off, 1 the scene, 2 the reveal |
-- | CMND_INAROGUE_WELCOME_LAYOUT | – | event hash, players, geometry, hidden meshes, hidden texts, scene seconds |
-- | CMND_INAROGUE_SCENE_RUN | reserved | true, slot / false, why |
-- | CMND_INAROGUE_SCENE_TICK | – | phase, seconds since running |
--
-- The scene player plays a reserved event over the menus as menuvsroute::EventState does: EventQueuePick,
-- EventDispatch, CreateScene("SceneEvent"), then each tick lets the scene start and waits for it to leave its slot,
-- and releases the reservation. A failure frees the reservation (the next story field would play it otherwise).

local U = require "lib/rogue/util"
local chara = require "lib/rogue/chara"
local bank = require "lib/rogue/svc_bank"
local info, warn = U.logger("rogue")

local M = {}

local DATA = "content/rogue/welcome_gacha.toml"
local data = nil
local gift = {}           -- { { param, stars, rarity }, … } in draw order
local state = 0           -- 0 off, 1 the scene, 2 the reveal

local function cfg()
  if data then return data end
  local ok, t = pcall(VRFW.files.toml, DATA)
  local w = ok and type(t) == "table" and type(t.welcome_gacha) == "table" and t.welcome_gacha or nil
  if not w then warn(DATA .. " not readable (" .. tostring(t) .. "): the welcome gacha uses its defaults") end
  w = w or {}
  local s = type(w.summary) == "table" and w.summary or {}
  data = {
    event = type(w.event) == "string" and w.event or "ev74_10091",
    orbs = U.int(w.orbs, 12),
    empty_orb = U.int(w.empty_orb, 0),
    orb_by_stars = type(w.orb_by_stars) == "table" and w.orb_by_stars or { 1, 2, 3, 4, 5 },
    bustups = U.int(w.bustups, 3),
    scene_max_seconds = U.int(w.scene_max_seconds, 180),
    rows = type(s.rows) == "table" and s.rows or { 6, 5 },
    tile = U.int(s.tile, 230),
    gap = U.int(s.gap, 26),
    centre_y = type(s.centre_y) == "table" and s.centre_y or { 365, 721 },
    offset = type(s.offset) == "table" and s.offset or { 0, 0 },
    scale = tonumber(s.scale) or 1.25,
    hide_meshes = type(s.hide_meshes) == "table" and s.hide_meshes or {},
    hide_texts = type(s.hide_texts) == "table" and s.hide_texts or {},
  }
  return data
end

function M.Draw()
  local list = bank.starter_gift_list()
  gift = {}
  for _, p in ipairs(list or {}) do
    local i = chara.get(p)
    gift[#gift + 1] = { param = p, stars = U.clamp(i and i.tier or 1, 1, 5), rarity = i and i.card or 0 }
  end
  local parts = {}
  for _, g in ipairs(gift) do parts[#parts + 1] = string.format("%s:%d", U.hex(g.param), g.stars) end
  info(string.format("welcome gacha: %d player(s) drawn (%s)", #gift, table.concat(parts, " ")))
  return #gift
end

function M.Info(i)
  local g = gift[U.int(i, -1) + 1]
  if not g then return false, 0, 0, 0 end
  return true, g.param, g.stars, g.rarity
end

-- { orbs, the orbs' digits (player k = orb k)…, the bust-up params… (most stars first, then draw order) }
function M.Balls()
  local c = cfg()
  local out = { c.orbs }
  for k = 1, c.orbs do
    local g = gift[k]
    out[1 + k] = g and U.int(c.orb_by_stars[g.stars], g.stars) or c.empty_orb
  end
  local order = {}
  for k, g in ipairs(gift) do order[#order + 1] = { k = k, g = g } end
  table.sort(order, function(a, b)
    if a.g.stars ~= b.g.stars then return a.g.stars > b.g.stars end
    return a.k < b.k
  end)
  for k = 1, c.bustups do
    out[1 + c.orbs + k] = order[k] and order[k].g.param or 0
  end
  return out
end

function M.State(new)
  if new ~= nil then
    local s = U.int(new, 0)
    if s ~= state then info(string.format("welcome gacha: state %d -> %d", state, s)) end
    state = s
  end
  return state
end

-- a mesh / text name, or an id "0x…", as the game's crc32 key
local function key(v)
  if type(v) == "number" then return U.u32(v, 0) end
  local h = type(v) == "string" and v:match("^0[xX](%x+)$")
  if h then return tonumber(h, 16) % U.TWO32 end
  return U.crc32(tostring(v))
end

-- the scene's event, the players kept, the summary's geometry { tile, gap, scale, offset x, offset y, rows n,
-- count per row…, centre y per row… }, the meshes and the texts a tile hides, the scene's longest play (s)
function M.Layout()
  local c = cfg()
  local t = { c.tile, c.gap, c.scale, tonumber(c.offset[1]) or 0, tonumber(c.offset[2]) or 0, #c.rows }
  for _, n in ipairs(c.rows) do t[#t + 1] = U.int(n, 0) end
  for k = 1, #c.rows do t[#t + 1] = U.int(c.centre_y[k], 0) end
  local meshes, texts = {}, {}
  for _, v in ipairs(c.hide_meshes) do meshes[#meshes + 1] = key(v) end
  for _, v in ipairs(c.hide_texts) do texts[#texts + 1] = key(v) end
  return U.crc32(c.event), #gift, t, meshes, texts, c.scene_max_seconds
end

-- ---------------------------------------------------------------------------------------- the scene player

local EV_PENDING, EV_PLAYING, EV_ENDED = 1, 2, 3
local EV_STATE, RES_TABLE, RES_CURRENT, RES_COUNT, VIEW_FLAGS = 0x130, 0x2138, 0xF4, 0xF0, 0xFF
local SCENE_SLOTS, SCENE_HASH, SCENE_GO, SCENE_STARTED = 0x10, 0xC, 0x171, 0x170
local NEEDED = { "InaRogue.SceneCreate", "InaRogue.EventDispatch", "InaRogue.EventRelease", "InaRogue.EventQueuePick",
  "inarogue_event_system", "inarogue_game_state", "inarogue_scene_stack" }
local play = nil

local function g(name)
  if not VRFW.is_on(name) then return nil end
  local ok, v = pcall(VRFW.game[name])
  return ok and v or nil
end

local function player_on()
  for _, n in ipairs(NEEDED) do
    if not VRFW.is_on(n) then return false, n end
  end
  return true
end

-- a reservation id is valid when non-zero with its low byte (the table index) below 20
local function valid_id(id) return id ~= 0 and U.band(id, 0xFF) < 20 end

local function playing() return play and play.phase ~= "done" end

local function release(reserved)
  if playing() or not player_on() then return end
  local gs = g("inarogue_game_state")
  if not gs then return end
  local tbl = gs + RES_TABLE
  local id = valid_id(reserved) and reserved or (U.rd("u32", tbl + RES_CURRENT) or 0)
  if not valid_id(id) then return end
  local ev = g("inarogue_event_system")
  if ev and U.rd("u32", ev + EV_STATE) == EV_PENDING then U.wr("u32", ev + EV_STATE, 0) end
  local key = VRFW.mem.buffer("inarogue_scene_release_key", 4)
  U.wr("u32", key, id)
  local ok, e = pcall(VRFW.call, "InaRogue.EventRelease", tbl, key)
  if not ok then warn("welcome gacha: EventRelease raised " .. tostring(e)) end
end

local function run(reserved)
  local on, missing = player_on()
  if not on then return nil, "event player off (" .. missing .. ")" end
  if playing() then return nil, "a scene is already playing" end
  local ev, gs = g("inarogue_event_system"), g("inarogue_game_state")
  if not ev then return nil, "no event system" end
  if not gs then return nil, "no game state" end
  local tbl = gs + RES_TABLE
  local before = U.rd("u32", ev + EV_STATE) or 0xFFFFFFFF
  -- CMND_RESERVE_EVENT only adds the record; the current one is EventQueuePick's (as CSceneRpg does every frame)
  local count = U.rd("u8", tbl + RES_COUNT) or 0
  local cur = U.rd("u32", tbl + RES_CURRENT) or 0
  if not valid_id(cur) and count ~= 0 then
    local ok, e = pcall(VRFW.call, "InaRogue.EventQueuePick", tbl)
    if not ok then return nil, "EventQueuePick raised " .. tostring(e) end
    cur = U.rd("u32", tbl + RES_CURRENT) or 0
  end
  if not valid_id(cur) then
    return nil, string.format("no reservation (reserved %s, %d in the table, event system state %d)", U.hex(reserved), count, before)
  end
  if valid_id(reserved) and cur ~= reserved then
    return nil, string.format("the current reservation %s is not ours %s", U.hex(cur), U.hex(reserved))
  end
  if before ~= EV_PENDING then
    local ok, e = pcall(VRFW.call, "InaRogue.EventDispatch", gs)
    if not ok then return nil, "EventDispatch raised " .. tostring(e) end
  end
  local st, id = U.rd("u32", ev + EV_STATE) or 0xFFFFFFFF, U.rd("u32", ev + EV_STATE + 4) or 0
  if st ~= EV_PENDING or id == 0 then
    return nil, string.format("the reservation %s did not become a pending event (state %d -> %d, id %s)", U.hex(cur), before, st, U.hex(id))
  end
  local view = g("inarogue_event_view")
  if view then U.wr("u16", view + VIEW_FLAGS, 0x0101) end
  local out = VRFW.mem.buffer("inarogue_scene_out", 16)
  local name = VRFW.mem.buffer("inarogue_scene_name", 16)
  local s = "SceneEvent\0"
  for i = 1, #s do U.wr("u8", name + i - 1, s:byte(i)) end
  for i = 0, 15 do U.wr("u8", out + i, 0) end
  local ok, e = pcall(VRFW.call, "InaRogue.SceneCreate", out, name, 1, 0)
  if not ok then return nil, "CreateScene raised " .. tostring(e) end
  local hash, slot = U.rd("u32", out) or 0, U.rd("u8", out + 4) or 0xFF
  if slot == 0xFF or slot >= 8 then return nil, string.format("CreateScene(SceneEvent) failed (slot 0x%02X)", slot) end
  U.wr("u32", ev + EV_STATE, EV_PLAYING)
  play = { slot = slot, hash = hash, phase = "starting", ticks = 0, since = nil }
  info(string.format("welcome gacha: event %s (reservation %s) pushed as SceneEvent in scene slot %d", U.hex(id), U.hex(cur), slot))
  return slot
end

function M.SceneRun(reserved)
  reserved = U.u32(reserved, 0)
  local slot, why = run(reserved)
  if slot then return true, slot end
  release(reserved)
  warn("welcome gacha: the scene is not played over the menus: " .. tostring(why) .. "; reservation freed")
  return false, why
end

local function next_phase(phase, hash, started, want)
  local ours = hash == want
  if phase == "starting" then
    if not ours then return "done" end
    return started and "running" or "starting"
  elseif phase == "running" then
    return ours and "running" or "done"
  end
  return "done"
end

local function finish()
  local ev = g("inarogue_event_system")
  if ev and U.rd("u32", ev + EV_STATE) ~= EV_PENDING then U.wr("u32", ev + EV_STATE, EV_ENDED) end
  local gs = g("inarogue_game_state")
  if gs then
    local tbl = gs + RES_TABLE
    local ok, e = pcall(VRFW.call, "InaRogue.EventRelease", tbl, tbl + RES_CURRENT)
    if not ok then warn("welcome gacha: EventRelease raised " .. tostring(e)) end
  end
  info("welcome gacha: SceneEvent ended, back to the menus")
end

function M.SceneTick()
  if not play or not player_on() then return "idle", 0 end
  local p = play
  if p.phase ~= "done" then
    p.ticks = p.ticks + 1
    local scenes = g("inarogue_scene_stack")
    local obj = scenes and U.rd("ptr", scenes + SCENE_SLOTS + p.slot * 8)
    local hash = obj and (U.rd("u32", obj + SCENE_HASH) or 0)
    local started = obj and (U.rd("u8", obj + SCENE_STARTED) or 0) ~= 0
    if p.phase == "starting" and obj and hash == p.hash and U.rd("u8", obj + SCENE_GO) == 0 then U.wr("u8", obj + SCENE_GO, 1) end
    local nx = next_phase(p.phase, hash, started, p.hash)
    if nx ~= p.phase then
      info(string.format("welcome gacha: SceneEvent %s -> %s after %d tick(s)", p.phase, nx, p.ticks))
      if nx == "running" then p.since = VRFW.now() end
    end
    p.phase = nx
    if nx == "done" then finish() end
  end
  return p.phase, p.since and (VRFW.now() - p.since) / 1000 or 0
end

return M
