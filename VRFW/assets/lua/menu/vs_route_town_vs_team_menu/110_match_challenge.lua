-- match_challenge (VR-Framework service): the Chronicle VS screen (vs_route_town_vs_team_menu, opened by the board
-- after its command menu) refuses the kick-off while the active dock does not meet the match row's challenge
-- ([[VRFW.MatchChallenge]], VRFW_MC): error sound, the screen stays open and the dock can still be switched there.
-- The command menu shows the challenge's condition, blue when the dock meets it and red when not (its label line,
-- vs_route_town_command_select_menu/110_match_challenge.lua).
-- The piece and the row come from the menu parameters the retail OnInit reads and clears (the piece 160947459, the
-- difficulty 2968810192; retail default 1), read here before it runs; the piece's game and save slot from the
-- piece info command (126049514: 2 -> ok, kind, game; 6 -> ok, slot; VRFW_RouteSlots answers an extended node's
-- slot). Without a piece (another mod's use of the
-- screen) or without a challenge nothing changes. An accepted kick-off arms the match's aura rule (the challenge's
-- `[VRFW.MatchChallenge.Auras]`, VRFW_MC.ArmAuras); opening the screen disarms it.
-- Wraps global functions only; no engine call at load time.
if VRFW_MC ~= nil then
  local S = type(VRFW_MC_VsScreen) == "table" and VRFW_MC_VsScreen or {game = 0, diff = 1, slot = nil}
  VRFW_MC_VsScreen = S
  local C = {
    PIECE = 160947459, DIFFICULTY = 2968810192,
    PIECE_INFO = 126049514,
    CLEAR_GET = VRFW_Cmd.GET_CHRONICLE_CLEAR_STATUS,     -- CMND_GET_CHRONICLE_CLEAR_STATUS (slot, difficulty)
  }

  local function call(...)
    local r = table.pack(pcall(funcLuaCommand, ...))
    if r[1] then
      return table.unpack(r, 2, r.n)
    end
    return nil
  end

  local function param(key)
    if VRFW_Param.Has(key) then
      return VRFW_Param.Get(key)
    end
    return nil
  end

  -- wrapped once per definition of the retail function (a chunk that runs again gets wrapped again)
  local init = rawget(_ENV, "OnInit")
  if type(init) == "function" and init ~= S.init_wrap then
    S.init_wrap = function(...)
      S.game, S.diff, S.slot = 0, 1, nil
      pcall(funcLuaCommand, VRFW_MC.AURAS_DISARM)
      if VRFW_RouteSlots ~= nil then
        pcall(VRFW_RouteSlots.Install)   -- an extended node's slot and clear bits (36_route_slots.lua)
      end
      local piece = param(C.PIECE)
      local diff = param(C.DIFFICULTY)
      if type(piece) == "number" then
        local ok, _, game = call(C.PIECE_INFO, piece, 2, true)
        if ok and type(game) == "number" then
          S.game = game
        end
        local okS, slot = call(C.PIECE_INFO, piece, 6)
        if okS and type(slot) == "number" then
          S.slot = slot
        end
      end
      if type(diff) == "number" then
        S.diff = diff
      end
      return init(...)
    end
    OnInit = S.init_wrap
  end

  local decide = rawget(_ENV, "OnDecideFocus")
  if type(decide) == "function" and decide ~= S.decide_wrap then
    S.decide_wrap = function(...)
      if S.game ~= 0 then
        local cleared = S.slot ~= nil and call(C.CLEAR_GET, S.slot, S.diff) == true
        local status = VRFW_MC.Status(S.game, 0, S.diff, cleared)
        if status ~= nil and not status.ok then
          VRFW_MC.Log("vs screen", "game", S.game, "difficulty", S.diff, "refused", "offenders", status.offenders)
          pcall(funcLuaCommand, VRFW_MC.SE, VRFW_MC.SE_NG)
          return
        end
        VRFW_MC.ArmAuras(S.game, S.diff)
      end
      return decide(...)
    end
    OnDecideFocus = S.decide_wrap
  end
end
