-- Chronicle Deluxe, the Chronicle board with the Crónica and the Batalla heroica only (docs/game/mods/chronicle-deluxe.md
-- §8). A hook file of the VR-Framework's board script (graft route_board, docs/framework/route-board.md §3): the rules
-- are handlers on its hook points. Nothing runs at load but the definitions and the registrations (no engine call).
--   * a Crónica (1) win of a normal piece whose route-unlock clear (2) is missing counts as that clear: story trigger
--     506 once (the board waits while its event plays: VRFW_RB_Clear sets c.wait and state 4), then the piece is
--     cleared again with 2 (c.force), the route opens (VRFW_RB_OpenEffect: neighbours, gate keys, trigger 507) and the
--     route-unlock and Heroica rows unlock at once (VRFW_RB_UnlockNext); gate pieces keep the retail flow (their only
--     battle is the gate battle, difficulty 2)
--   * old saves: every normal piece with a Crónica clear gets its Heroica unlocked when the board comes back
--     (VRFW_RB_BackOnBoard); clear bits are never removed
--   * dots: a piece shows only the difficulties that exist (VRFW_MatchDifficulty, this mod's
--     content\defaults\match_difficulty.toml), on a bar with one socket per difficulty, centred under the crest
--     (ChronicleDeluxe.OrbBar, cd_orb_bar.lua; before the framework's rank badge, VRFW_RB_Badge, which may take the
--     6th dot)
-- With Inazuma Fantasy's Chronicle redesign in the same script (its global EVT_ChrClear, graft chronicle_redesign) the
-- clear flow is IF's: these handlers pass (one trigger 506 per win).
@ORB_BAR@
ChronicleDeluxe = ChronicleDeluxe or {}
ChronicleDeluxe.Board = ChronicleDeluxe.Board or {}
local B = ChronicleDeluxe.Board
B.CMD = {
  GET_CLEAR = 4034518619,     -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)
  SET_CLEAR = 1891570685,     -- CMND_SET_CHRONICLE_CLEAR_STATUS (slot, on, difficulty)
  SET_LOCK = 1778321182,      -- CMND_SET_CHRONICLE_LOCK_STATUS (slot, locked, difficulty)
  PIECE_SLOT = 126049514,     -- (piece index, 6) -> ok, the piece's statusFlagIndex
  TRIGGER_RUNNING = 3500708916,
  MENU_ACTIVE = 1558704558,   -- the board menu object's active flag (the retail state-4 handover)
  LOG = 3661580131,           -- CMND_EVT_LOG
}
B.CRONICA, B.ROUTE_OPEN, B.HEROICA = 1, 2, 4
B.WIN = 4108050209            -- crc32("0"): the trigger result of a win
B.NORMAL = 0                  -- eventType of a normal match piece
B.GATE = 5                    -- eventType of a gate piece
B.trigger_piece = -1          -- the piece whose trigger 506 already ran in this return to the board
B.fast_clear = false          -- the clear being shown is a Crónica that counts as the route-unlock clear

function B.Log(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  pcall(funcLuaCommand, B.CMD.LOG, "ChronicleDeluxe board " .. table.concat(parts, " "))
end

-- Inazuma Fantasy's redesign owns the clear flow in this VM
function B.IfOwnsFlow()
  return EVT_ChrClear ~= nil
end

-- old saves: the Heroica of every normal piece whose Crónica is won (pieces of every mod: stop at the first index the
-- game does not know)
function B.OpenWonHeroicas()
  local n = 0
  for i = 0, 1023 do
    local ok, slot = funcLuaCommand(B.CMD.PIECE_SLOT, i, 6)
    if not ok then
      break
    end
    local okE, kind = GetTownMapResourceEvent(i, 1, false, false)
    if okE and kind == B.NORMAL and funcLuaCommand(B.CMD.GET_CLEAR, slot, B.CRONICA) then
      funcLuaCommand(B.CMD.SET_LOCK, slot, false, B.HEROICA)
      n = n + 1
    end
  end
  return n
end

-- the clear of a won match (state 10): the Crónica of a normal piece without its route-unlock clear counts as it
function B.Clear(c)
  if not c.ok then
    return
  end
  local fast = c.diff == B.CRONICA and c.kind == B.NORMAL and not funcLuaCommand(B.CMD.GET_CLEAR, c.slot, B.ROUTE_OPEN)
  c.force = fast
  if fast and B.trigger_piece ~= c.piece then
    B.trigger_piece = c.piece
    B.Log("route unlock by Cronica win: piece", c.piece, "slot", c.slot)
    RunVsRouteTrigger(506, B.WIN)
    if funcLuaCommand(B.CMD.TRIGGER_RUNNING) then
      c.wait = true
      VRFW_RB.L.n21 = 4
      funcLuaMenuCommand(B.CMD.MENU_ACTIVE, VRFW_RB.L.n9, false)
    end
  end
end

-- the dots a piece shows: the difficulties that exist (route = normal piece, gate = gate piece); nil = every one
function B.Shown(kind)
  return VRFW_MatchDifficulty ~= nil and VRFW_MatchDifficulty.Set(kind == B.GATE and "gate" or "route") or nil
end

if VRFW_Host ~= nil then
  local stem = "vs_route_town_menu"
  local id = "chronicle_deluxe.board"
  VRFW_Host.on(stem, "VRFW_RB_BackOnBoard", {id = id, phase = "after", fn = function()
    if not B.IfOwnsFlow() then
      B.OpenWonHeroicas()
    end
  end})
  VRFW_Host.on(stem, "VRFW_RB_Clear", {id = id, phase = "after", fn = function(r, c)
    if not B.IfOwnsFlow() then
      B.Clear(c)
    end
  end})
  VRFW_Host.on(stem, "VRFW_RB_Cleared", {id = id, phase = "after", fn = function(r, c)
    if c.force and not B.IfOwnsFlow() then
      funcLuaCommand(B.CMD.SET_CLEAR, c.slot, true, B.ROUTE_OPEN)
      B.fast_clear = true
      B.trigger_piece = -1
    end
  end})
  VRFW_Host.on(stem, "VRFW_RB_UnlockNext", {id = id, phase = "around", fn = function(nxt, c)
    if c.kind ~= B.NORMAL or B.IfOwnsFlow() then
      return nxt(c)
    end
    if c.diff == B.CRONICA then
      funcLuaCommand(B.CMD.SET_LOCK, c.slot, false, B.ROUTE_OPEN)
      funcLuaCommand(B.CMD.SET_LOCK, c.slot, false, B.HEROICA)
    end
    return true
  end})
  VRFW_Host.on(stem, "VRFW_RB_OpenEffect", {id = id, phase = "around", fn = function(nxt, open)
    local fast = B.fast_clear == true
    B.fast_clear = false
    return nxt(open) == true or fast
  end})
  VRFW_Host.on(stem, "VRFW_RB_DotShown", {id = id, phase = "around", fn = function(nxt, kind, difficulty)
    local shown = B.Shown(kind)
    if shown ~= nil and not shown[difficulty] then
      return false
    end
    return nxt(kind, difficulty)
  end})
  -- the orb bar of a piece, after the retail dots of UpdatePieceClearIcon(layer, instance, piece)
  VRFW_Host.on(stem, "VRFW_RB_Badge", {id = id .. "_orb_bar", phase = "before", fn = function(layer, instance, piece)
    if B.IfOwnsFlow() or piece == nil or piece == -1 then
      return
    end
    local ok, kind = GetTownMapResourceEvent(piece, 1, true)
    if ok then
      ChronicleDeluxe.OrbBar.Fit(layer, instance, kind, GetGameDifficultyArray(kind), GetClearIconLocatorNameArray(kind))
    end
  end})
end
