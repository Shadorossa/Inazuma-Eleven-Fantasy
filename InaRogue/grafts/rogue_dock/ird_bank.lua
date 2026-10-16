-- ===== EVT inarogue dock BEGIN =====
-- INAROGUE mode of the retail "Banco" (chara_bank_menu; docs/game/modes/inarogue.md §16). In the INAROGUE save (slot 4)
-- the bank lists the run's players (they are the only characters of that save, plus the avatar):
--   * only INAROGUE players can be chosen (the avatar and anything that is not in the INAROGUE bank are greyed);
--   * before the run starts, a player that does not fit the points left is greyed; swapping counts the player who
--     leaves ("cambiar" from a pitch slot), adding counts the free points only;
--   * no retire (it would give fichas and delete the player), no switching to another team, "add to the team" only
--     looks at the VS team.
do
@COMMON@
  local function refresh()
    pcall(IRD.points)
  end

  -- the bank's select mode (3 = swap from a pitch / bench slot): ChangeSelectMode is the retail global that sets it,
  -- so the mode is mirrored here instead of reading the retail main-chunk local (0 until the first call, as retail)
  local select_mode = 0
  IRD.wrap("ChangeSelectMode", function(orig)
    return function(a1, ...)
      select_mode = a1
      return orig(a1, ...)
    end
  end)

  IRD.wrap("OnInit", function(orig)
    return function(...)
      IRD.check()
      if IRD.on then
        refresh()
        IRD.log("bank: INAROGUE mode, run", IRD.run, "points", IRD.spent, "/", IRD.budget)
      end
      return orig(...)
    end
  end)

  IRD.wrap("Step", function(orig)
    return function(...)
      local r = table.pack(orig(...))
      if IRD.on then
        IRD.frames = IRD.frames + 1
        if IRD.frames % 30 == 0 then
          refresh()
        end
      end
      return table.unpack(r, 1, r.n)
    end
  end)

  -- selectable = an INAROGUE player; before the run, only if he fits the points (IsGrayOutBankChara calls this too,
  -- so the retail grey follows)
  IRD.wrap("IsBankCharaEnabled", function(orig)
    return function(a1, ...)
      if IRD.on and type(a1) == "number" and a1 ~= 0 then
        local e = IRD.entry(a1)
        if e == nil then
          return false
        end
        if IRD.budget_on() and not IsCharaInTeam(a1, IRD.set) then
          local credit = 0
          if select_mode == 3 and type(GetFormationSelectCharaStHdl) == "function" then   -- swap from a pitch / bench slot
            local out = IRD.entry(GetFormationSelectCharaStHdl())
            credit = out ~= nil and out.cost or 0
          end
          if IRD.spent - credit + e.cost > IRD.budget then
            return false
          end
        end
      end
      return orig(a1, ...)
    end
  end)

  IRD.wrap("CanCharaBankRemove", function(orig)
    return function(...)
      if IRD.on then
        return false
      end
      return orig(...)
    end
  end)

  IRD.wrap("OpenCharaBankRemoveConfirm", function(orig)
    return function(...)
      if IRD.on then
        funcLuaCommand(IRD.SE, IRD.SE_NG)
        return
      end
      return orig(...)
    end
  end)

  IRD.wrap("ChangeTeamDock", function(orig)
    return function(...)
      if IRD.on then
        return
      end
      return orig(...)
    end
  end)

  -- "add to the team": the VS team only, and before the run only within the points left
  IRD.wrap("SearchEmptyFormationPosition", function(orig)
    return function(a1, ...)
      if IRD.on then
        local e = IRD.entry(a1)
        if e == nil or IsCharaInTeam(a1, IRD.set) then
          return -1, 255
        end
        if IRD.budget_on() and IRD.spent + e.cost > IRD.budget then
          IRD.log("add refused: over the points", IRD.spent, "+", e.cost, ">", IRD.budget)
          return -1, 255
        end
        local pos = funcLuaMenuCommand(3565243433, IRD.set, a1)
        if pos ~= nil and pos ~= 255 then
          return IRD.set, pos
        end
        return -1, 255
      end
      return orig(a1, ...)
    end
  end)
end
-- ===== EVT inarogue dock END =====
