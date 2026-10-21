-- BetterUI (mod clean_hud, prefix BetterUI), character bank (chara_bank_menu): L2 / R2 (Q / E) no longer switch the
-- bank between its list and its pitch views (the game's «active UI» switch: OnFunction 3959000859 with prev / next
-- while no player page is open), and the switch's side guide «L2 ‹ / › R2» (team14_06_active_ui_change_guide) is
-- hidden. With a player page open, L2 / R2 still page it as in the game. The search bank (chara_bank_menu_for_search)
-- has no such switch: unchanged. No engine call at load time.
if VRFW_Host ~= nil then
  local STEM = "chara_bank_menu"
  local SWITCH_FUNCTION = 3959000859     -- OnFunction argument of L2 / R2 (input rows CMD_FUNCL2 / CMD_FUNCR2)
  local GUIDE = 3026610789               -- team14_06_active_ui_change_guide
  local LAYER_VISIBLE = 711242136        -- CMND_SET_LAYER_VISIBLE (layer, instance, visible)

  -- a player page open (the game's own local: L2 / R2 page it then)
  local function plate_open()
    local h = VRFW_Host.hosts ~= nil and VRFW_Host.hosts[STEM] or nil
    local l = h ~= nil and h.L or nil
    local ok, v = pcall(function() return l.flag end)
    return ok and v == true
  end

  VRFW_Host.on(STEM, "OnFunction", {
    id = "clean_hud.bank_no_view_switch", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 == SWITCH_FUNCTION and not plate_open() then
        return
      end
      return nxt(a1, ...)
    end,
  })

  -- the guide: hidden whenever the game sets it up or opens it
  local function hide(r, a1, a2)
    if a1 == GUIDE then
      pcall(funcLuaMenuCommand, LAYER_VISIBLE, GUIDE, a2 or 0, false)
    end
  end
  VRFW_Host.on(STEM, "OnSetupLayer", { id = "clean_hud.bank_no_view_switch", phase = "after", fn = hide })
  VRFW_Host.on(STEM, "OnOpenLayer", { id = "clean_hud.bank_no_view_switch", phase = "after", fn = hide })
end
