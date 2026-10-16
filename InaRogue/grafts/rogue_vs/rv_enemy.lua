-- ===== EVT rogue vs BEGIN =====
-- vs_route_town_vs_enemy_formation_menu in INAROGUE mode (docs/game/modes/inarogue.md §28; rv_common): the rival's
-- formation cards of the node's match (the game row's team at the run's difficulty) instead of a Chronicle town
-- event's. Everything else (cards, nickname button) is retail. The retail chunk's locals n..n6 are set from the run
-- (the assembler promotes them).
do
@COMMON@
  local evt_rv_init = OnInit
  function OnInit(...)
    if not EVT_RV.check() then
      return evt_rv_init(...)
    end
    n, n6 = 0, 0
    n2 = EVT_RV.game
    n5 = 5
    n4 = EVT_RV.diff
    local okT, team = funcLuaCommand(2204933160, n2, n4)
    n3 = (okT and type(team) == "number") and team or 0
    SetTeamId(n3)
    EVT_RV.log("enemy formation: node", EVT_RV.node, "game", n2, "diff", n4, "team", n3)
  end

  -- a pachanga rival: only the slots of a drawn player stay. Members past the five (positions 5..15, the 5v5 bench)
  -- are not drawn on the 5-slot field (2026-10-06: an empty card frame between its MC and DF; the retail SetFormation
  -- places every member < 11 on it), and the blank frames (a6, team00_01_p1_chara_card_blank) of every slot without a
  -- player are hidden too (Nacho 07/10: retail never hides them, so the support frames at _pos_support_atc01..03
  -- stayed under the rival's pitch). A rival without a team row (a1 == 0: retail's placeholder formation) keeps 0..4.
  local evt_rv_setform = SetFormation
  function SetFormation(a1, a2, a3, a4, a5, a6, ...)
    local r = table.pack(evt_rv_setform(a1, a2, a3, a4, a5, a6, ...))
    if EVT_RV.on and EVT_RV.kind == 1 then
      local used = {}
      if a1 == 0 then
        for p = 0, 4 do
          used[p] = true
        end
      else
        local okN, num = funcLuaCommand(2151743654, a1, 8)
        for k = 0, ((okN and type(num) == "number") and num or 0) - 1 do
          local ok, _, p = GetTeamMemberInfo(a1, k, a2, a3)
          if ok and type(p) == "number" and p <= 18 and not (p >= 5 and p <= 15) then
            used[p] = true
          end
        end
      end
      local count = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], a5)
      if type(count) ~= "number" or count < 19 then
        count = 19
      end
      for i = 0, count - 1 do
        if not used[i] then
          for _, L in ipairs({a5, a6}) do
            if type(L) == "number" and funcLuaMenuCommand(262659071 --[[CMND_IS_EXIST_LAYER?]], L, i) == true then
              funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], L, i, false)
            end
          end
        end
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
-- ===== EVT rogue vs END =====
