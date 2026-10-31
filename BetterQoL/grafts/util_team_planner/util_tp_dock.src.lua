-- Team planner of the mod Utilities (docs/game/ui/team-planner.md), team dock part (soccer_team_dock_menu). SOURCE of
-- the hook file util_tp_dock.lua (research/grafts/util_team_planner/gen_hooks.py puts util_tp_common.lua in place of
-- @COMMON@ and fills the @crc placeholders; edit this file, then run the script).
-- * OnInit (before): the ghosts of the mounted team-bank page whose character the save now has get their real card
--   (TP.AssignAll, the game's own placement); the first Step shows «N planned player(s) joined their squad».
-- * UpdateFormationInfo (after): the dock's squad view draws its ghosts (semi-transparent cards over the empty slots);
--   UpdateViewMenuByLock (after): the ghost alpha again (the lock dims every card).
-- * CanActiveTeam (around): a squad with ghosts cannot become the active team; during «Equipo activo» (OnFunction
--   4219711668) the refusal shows utilities.tp_refuse_active (the retail code plays the error sound).
-- * OnBack (around): the dock is not left while the ACTIVE squad has ghosts (the retail rule for an invalid active
--   team), message utilities.tp_refuse_leave.
-- * OnEnter / OnDecideFocus (around): after the formation screen closed, its «Añadir del banco» request (parameter
--   util_tp_bank_req) runs the game's own «Banco» (OpenCharaBank, as list item 8 does).
-- Without Utilities' script (CMND_BETTERQOL_TP_INFO unanswered) nothing changes.
do
@COMMON@

  local STEM = "soccer_team_dock_menu"
  local SET_ACTIVE = 4219711668  -- OnFunction: «Equipo activo»
  local ATTACH_FORMATION = 2141963976 -- team01_03_attach_formation

  local function squad()
    local set = TP.Local(STEM, "n5")
    local ty = TP.Local(STEM, "n10") or 0
    return set, ty
  end

  TP.Wrap(STEM, "OnInit", function(orig)
    return function(...)
      TP.ghost = {}
      local ok, n = pcall(TP.AssignAll)
      TP.assigned_msg = ok and n or 0
      if not ok then
        TP.Log("assignment failed:", tostring(n))
      end
      return orig(...)
    end
  end)

  TP.Wrap(STEM, "Step", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      if (TP.assigned_msg or 0) > 0 then
        local n = TP.assigned_msg
        TP.assigned_msg = 0
        TP.Msg(TP.T_ASSIGNED, "%d planned player(s) joined their squad.", n)
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  TP.Wrap(STEM, "UpdateFormationInfo", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      local set, ty = squad()
      pcall(TP.Ghosts, set, ty)
      return table.unpack(r, 1, r.n)
    end
  end)

  TP.Wrap(STEM, "UpdateViewMenuByLock", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      if next(TP.ghost) ~= nil then
        local on, alpha = TP.Info()
        if on then
          for slot in pairs(TP.ghost) do
            local leader = slot == TP.LEADER_SLOT
            TP.Alpha(leader and TP.LEADER or TP.CARD, leader and 0 or slot, alpha)
          end
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  TP.Wrap(STEM, "OnFunction", function(orig)
    return function(a1, ...)
      TP.setting_active = a1 == SET_ACTIVE
      local r = table.pack(orig(a1, ...))
      TP.setting_active = false
      return table.unpack(r, 1, r.n)
    end
  end)

  TP.Wrap(STEM, "CanActiveTeam", function(orig)
    return function(set, ...)
      local r = table.pack(orig(set, ...))
      if r[1] and TP.HasGhosts(set, TP.Local(STEM, "n10") or 0) then
        if TP.setting_active then
          TP.Msg(TP.T_REFUSE_ACTIVE, "Missing players: this squad has planned players you do not have yet.")
        end
        return false
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  TP.Wrap(STEM, "OnBack", function(orig)
    return function(a1, ...)
      local moving = a1 == ATTACH_FORMATION and type(IsChangeMemberMode) == "function" and IsChangeMemberMode()
      if not moving then
        local ok, act = pcall(funcLuaCommand, TP.C.VS_TEAM)
        if ok and type(act) == "number" and TP.HasGhosts(act, 0) then
          TP.Snd(TP.SY_ERROR)
          TP.Msg(TP.T_REFUSE_LEAVE, "The active squad has planned players you do not have yet.")
          return 1
        end
      end
      return orig(a1, ...)
    end
  end)

  -- the formation screen asked for the game's bank («Añadir del banco»): the retail «Banco» once it has closed
  function TP.BankRequest(from)
    if not VRFW_Param.Has(TP.KEY_BANK) then
      return
    end
    -- OpenCharaBank waits for the bank to close: it needs the dock's coroutine (never the main thread)
    local co, main = coroutine.running()
    if co == nil or main then
      TP.Log("bank request seen at", from, "outside a coroutine: kept for the next one")
      return
    end
    local set = VRFW_Param.Get(TP.KEY_BANK)
    VRFW_Param.Clear(TP.KEY_BANK)
    local cur = squad()
    if type(OpenCharaBank) ~= "function" or (cur ~= nil and set ~= cur) then
      TP.Log("bank request of squad", tostring(set), "dropped (dock on", tostring(cur), ")")
      return
    end
    TP.Log("bank request of squad", tostring(set), "at", from)
    OpenCharaBank()
    -- the player chosen in the bank lands in the slot: the squad on the pitch drawn again from the team set (the
    -- retail list gets this from its own return only while it holds the focus)
    if type(UpdateFormationInfo) == "function" then
      local okr, er = pcall(UpdateFormationInfo)
      if not okr then
        TP.Log("redraw after the bank failed:", tostring(er))
      end
    end
    if type(SetActiveDockBackground) == "function" then
      local n4 = TP.Local(STEM, "n4")
      pcall(SetActiveDockBackground, n4 ~= nil and n4 == cur)
    end
  end

  for _, point in ipairs({"OnEnter", "OnDecideFocus", "ResumeTeamDock"}) do
    TP.Wrap(STEM, point, function(orig)
      return function(...)
        local r = table.pack(orig(...))
        TP.BankRequest(point)
        return table.unpack(r, 1, r.n)
      end
    end)
  end
end
