-- BetterUI: the pitch cards of the formation screens moved apart where they touch (config.toml
-- [formation_card_spread]; docs/game/characters/position-cards.md §8.7).
-- The game places each pitch card with SetupFormationIconPosition (include soccer_formation_menu_inc): the formation's
-- attacking position (formation_config offensePos, the match's own column) mapped onto the pitch frame, plus the
-- formation's menu offset (bustupPos). In the attacking half the rows sit close, so neighbouring cards overlap.
-- This wraps that function in every menu VM that has it. Once the 11 pitch cards of a formation have been placed, a
-- small solver pushes apart only the pairs of cards that touch, each pair along the axis where it overlaps least, and
-- keeps every card inside the pitch. Only when that is not enough the cards are drawn a little smaller; when even the
-- smallest size does not help, the formation stays as the game draws it. The result is kept per formation, so every
-- later placement of a card (redraws, swaps, drag and drop) adds the same offset; drag and drop and the draw order
-- read the card layer's position back, so they follow the moved cards.
-- Only on the compact formation-card layout (graft clean_hud_player_cards), on the soccer11_02 pitch frame, at the
-- menu's normal scale; 5-a-side screens and scaled card screens are left as they are.
-- Definitions only at load: every engine call runs inside the wrapper.

local SPREAD = {
  CARD_LAYER = 1973487846,          -- team00_01_chara_card_for_soccer
  BLANK_LAYER = 3571911991,         -- team00_01_p1_chara_card_blank (the empty slot under a card)
  FRAME_LAYER = 3321884270,         -- soccer11_02_formation_frame (the pitch of the formation screens)
  PITCH_CARDS = 11,                 -- pitch slots 0..10 of an 11-a-side formation
  GET_LAYER_POSITION = 2834507455,  -- (layer, index) -> x, y, z
  SET_LAYER_POSITION = 1389957207,  -- (layer, x, y, z, index)
  SET_LAYER_SCALE = 3778714801,     -- (layer, x, y, z, index)
  LAYER_EXISTS = 262659071,         -- (layer, index) -> true when the layer instance exists
  SOLVER_ROUNDS = 200,              -- separation rounds per card size
}

local state = {
  settings = nil,                   -- the config table; false = off (no answer, or turned off)
  formations = {},                  -- "<formation>/<scale>" -> { raw, count, pending, solved, offset, scale }
  baseScale = {},                   -- "<layer>/<index>" -> the scale the menu gave the card when it opened
  scaled = {},                      -- "<layer>/<index>" -> true once this file changed the card's scale
  frameSeen = false,                -- the pitch frame exists in this menu
  log = nil,
}

local function Log(...)
  if state.log == nil and type(VRFW_Log) == "table" then
    state.log = VRFW_Log.New("BetterUI.formation_card_spread")
  end
  if state.log ~= nil then
    state.log(...)
  end
end

-- The tunables of config.toml [formation_card_spread] (CMND_BETTERUI_FORMATION_CARD_SPREAD, asked once per VM).
local function Settings()
  if state.settings == nil then
    state.settings = false
    local ok, t = pcall(funcLuaCommand, VRFW_Cmd.BETTERUI_FORMATION_CARD_SPREAD)
    if ok and type(t) == "table" then
      local needed = { "card_width", "card_height", "gap", "smallest_scale", "scale_step",
                       "pitch_side", "pitch_top", "pitch_bottom" }
      local complete = true
      for _, name in ipairs(needed) do
        if type(t[name]) ~= "number" then
          complete = false
        end
      end
      if complete and t.scale_step > 0 and t.smallest_scale > 0 and t.smallest_scale <= 1 then
        state.settings = t
      end
    end
  end
  return state.settings
end

-- The pairs of cards (centres P, card size w x h, gap g) that overlap.
local function Overlaps(P, w, h, g)
  local found = {}
  for i = 1, #P - 1 do
    for j = i + 1, #P do
      local px = w + g - math.abs(P[i][1] - P[j][1])
      local py = h + g - math.abs(P[i][2] - P[j][2])
      if px > 0.5 and py > 0.5 then
        found[#found + 1] = { i, j, px, py }
      end
    end
  end
  return found
end

-- Pushes the touching pairs apart (each card half the overlap, along the axis with the smaller overlap, keeping the
-- cards' order) inside the pitch limits (a card the game already draws outside them may stay where it is).
-- Returns the new centres and whether no two cards overlap any more.
local function Separate(raw, w, h, g, s)
  local P = {}
  local limit = {}
  for i, p in ipairs(raw) do
    P[i] = { p[1], p[2] }
    limit[i] = {
      side = math.max(s.pitch_side, math.abs(p[1])),
      top = math.max(s.pitch_top, p[2]),
      bottom = math.min(s.pitch_bottom, p[2]),
    }
  end
  for _ = 1, SPREAD.SOLVER_ROUNDS do
    local pairs_ = Overlaps(P, w, h, g)
    if #pairs_ == 0 then
      break
    end
    for _, o in ipairs(pairs_) do
      local i, j, px, py = o[1], o[2], o[3], o[4]
      if px <= py then
        local dir = P[j][1] >= P[i][1] and 1 or -1
        P[i][1] = P[i][1] - dir * px / 2
        P[j][1] = P[j][1] + dir * px / 2
      else
        local dir = P[j][2] >= P[i][2] and 1 or -1
        P[i][2] = P[i][2] - dir * py / 2
        P[j][2] = P[j][2] + dir * py / 2
      end
    end
    for i, p in ipairs(P) do
      local l = limit[i]
      p[1] = math.max(-l.side, math.min(l.side, p[1]))
      p[2] = math.max(l.bottom, math.min(l.top, p[2]))
    end
  end
  return P, #Overlaps(P, w, h, 0) == 0
end

-- The offset of every pitch card of one formation and the card size it needs (1 = as drawn).
local function Solve(f, s)
  local raw = {}
  for slot = 0, SPREAD.PITCH_CARDS - 1 do
    raw[slot + 1] = f.raw[slot]
  end
  f.offset = {}
  f.scale = 1
  f.solved = true
  local before = #Overlaps(raw, s.card_width, s.card_height, 0)
  if before == 0 then
    return
  end
  local scale = 1
  while scale >= s.smallest_scale - 1e-6 do
    local P, clear = Separate(raw, s.card_width * scale, s.card_height * scale, s.gap * scale, s)
    if clear then
      for slot = 0, SPREAD.PITCH_CARDS - 1 do
        f.offset[slot] = { P[slot + 1][1] - raw[slot + 1][1], P[slot + 1][2] - raw[slot + 1][2] }
      end
      f.scale = scale
      Log("formation", f.id, "overlaps", before, "spread at scale", scale)
      return
    end
    scale = scale - s.scale_step
  end
  Log("formation", f.id, "overlaps", before, "left as drawn: no room even at scale", s.smallest_scale)
end

-- One placed card gets its formation's offset (and size). x, y, z = the position the game just gave it.
local function Move(layer, slot, f, x, y, z)
  local key = layer .. "/" .. slot
  local o = f.offset[slot]
  if o ~= nil and (o[1] ~= 0 or o[2] ~= 0) then
    funcLuaMenuCommand(SPREAD.SET_LAYER_POSITION, layer, x + o[1], y + o[2], z or 0, slot)
  end
  if f.scale < 1 or state.scaled[key] then
    funcLuaMenuCommand(SPREAD.SET_LAYER_SCALE, layer, f.scale, f.scale, 1, slot)
    state.scaled[key] = f.scale < 1 or nil
  end
end

-- Whether this placement is one this file handles (see the header).
local function Handles(layer, slot, frame, menuScale)
  if layer ~= SPREAD.CARD_LAYER and layer ~= SPREAD.BLANK_LAYER then
    return false
  end
  if type(slot) ~= "number" or slot < 0 or slot >= SPREAD.PITCH_CARDS then
    return false
  end
  if (menuScale ~= nil and menuScale ~= 1) or (frame ~= nil and frame ~= SPREAD.FRAME_LAYER) then
    return false
  end
  local base = state.baseScale[layer .. "/" .. slot]
  if base ~= nil and base ~= 1 then
    return false
  end
  local small = rawget(_ENV, "IsAlwaysCardSizeSmallMode")
  if type(small) == "function" and small() == true then
    return false
  end
  if not state.frameSeen then
    state.frameSeen = funcLuaMenuCommand(SPREAD.LAYER_EXISTS, SPREAD.FRAME_LAYER, 0) == true
    if not state.frameSeen then
      return false
    end
  end
  local compact = rawget(_ENV, "CLEAN_HUD_PC_IsCompact")
  return type(compact) == "function" and compact(funcLuaMenuCommand, SPREAD.CARD_LAYER, slot) == true
end

local function AfterSetup(layer, slot, formation, frame, menuScale)
  local s = Settings()
  if not s or not Handles(layer, slot, frame, menuScale) then
    return
  end
  local key = tostring(formation) .. "/" .. tostring(menuScale or 1)
  local f = state.formations[key]
  if f == nil then
    f = { id = formation, raw = {}, count = 0, pending = {}, solved = false }
    state.formations[key] = f
  end
  local x, y, z = funcLuaMenuCommand(SPREAD.GET_LAYER_POSITION, layer, slot)
  if type(x) ~= "number" or type(y) ~= "number" then
    return
  end
  if f.solved then
    Move(layer, slot, f, x, y, z)
    return
  end
  if f.raw[slot] == nil then
    f.count = f.count + 1
  end
  f.raw[slot] = { x, y }
  f.pending[layer .. "/" .. slot] = { layer, slot }
  if f.count < SPREAD.PITCH_CARDS then
    return
  end
  Solve(f, s)
  local moved = false
  for _, p in pairs(f.pending) do
    local px, py, pz = funcLuaMenuCommand(SPREAD.GET_LAYER_POSITION, p[1], p[2])
    if type(px) == "number" and type(py) == "number" then
      Move(p[1], p[2], f, px, py, pz)
      moved = true
    end
  end
  f.pending = nil
  -- the cards placed before the formation was complete moved after the game sorted them: sort the draw order again
  local sort = rawget(_ENV, "UpdateMemberCharaIconPrioritySort")
  if moved and next(f.offset) ~= nil and type(sort) == "function" then
    pcall(sort)
  end
end

local setup = rawget(_ENV, "SetupFormationIconPosition")
if type(setup) == "function" and rawget(_ENV, "BETTERUI_FORMATION_CARD_SPREAD") ~= setup then
  local wrapped = function(layer, slot, formation, frame, menuScale, ...)
    local r = table.pack(setup(layer, slot, formation, frame, menuScale, ...))
    local ok, err = pcall(AfterSetup, layer, slot, formation, frame, menuScale)
    if not ok then
      if state.log == nil and type(VRFW_Log) == "table" then
        state.log = VRFW_Log.New("BetterUI.formation_card_spread")
      end
      if state.log ~= nil then
        state.log.once("error", "error:", tostring(err))
      end
    end
    return table.unpack(r, 1, r.n)
  end
  rawset(_ENV, "SetupFormationIconPosition", wrapped)
  rawset(_ENV, "BETTERUI_FORMATION_CARD_SPREAD", wrapped)

  -- the scale each card got when its layer opened (SetScaleFormationCharaCardForOnOpenLayer(layer, index, scale))
  local setScale = rawget(_ENV, "SetScaleFormationCharaCardForOnOpenLayer")
  if type(setScale) == "function" then
    rawset(_ENV, "SetScaleFormationCharaCardForOnOpenLayer", function(layer, index, scale, ...)
      if type(layer) == "number" and type(index) == "number" then
        state.baseScale[layer .. "/" .. index] = scale
        state.scaled[layer .. "/" .. index] = nil
      end
      return setScale(layer, index, scale, ...)
    end)
  end
end
