-- ===== EVT ss2_pc_rows BEGIN ===== (research/grafts/ss2_pc_rows, docs/game/mechanics/pasivas-configurables.md §10)
-- Supertécnicas screen (evt_skill_slot_menu, built by ss2_menus): its list picker (custom passive, role, set) uses
-- the same list window as the plate's passive picker. passive_config_build.py points both settings at the taller
-- row clone (evt_pc_row: 2-line text box, 6 rows per page), so the page size PL.SSROWS follows the row layer's
-- instance count instead of the retail 9.
-- No new main-chunk locals (PL is this file's own).
do
  EVT_PCS2 = EVT_PCS2 or {}

  function EVT_PCS2.Rows(L)
    local ok, n = pcall(funcLuaMenuCommand, 1175615627, L)
    if ok and type(n) == "number" and n >= 1 and PL ~= nil then
      PL.SSROWS = math.min(n, 9)
    end
  end

  -- v4 (Nacho, screenshot 120): the custom-passive rows get the plate row's icon block too. The row quads of
  -- evt_pc_row are 72 px backing (_icon_cmd_type_base01), 64 px icon (_icon_sp_area_dmy01) and a 44 px corner badge
  -- (_icon_sixth_dmy01). PL.SSRowIcons draws the six-sense hexagon on the icon quad and the passive's board icon on
  -- the corner quad; here the hexagon is dropped, the board icon goes to the icon quad, the backing is drawn and the
  -- corner quad stays empty (the list's items have no archetype data).
  function EVT_PCS2.RowIcons(L, k, id)
    local real = funcLuaMenuCommand
    local ok, err = pcall(function()
      funcLuaMenuCommand = function(cmd, a, b, c, d, e, f, ...)
        if cmd == 558735651 and a == L and f == k then
          if d == 566439826 then -- icon_sp_area_dmy01: the hexagon, replaced by the backing
            return true
          elseif d == 669321680 then -- icon_sixth_dmy01: the board icon, onto the icon quad
            return real(cmd, a, b, c, 566439826, e, f, ...)
          end
        end
        return real(cmd, a, b, c, d, e, f, ...)
      end
      EVT_PCS2.prevRowIcons(L, k, id)
    end)
    funcLuaMenuCommand = real
    local item = id ~= nil and id ~= 0
    UTIL_PCI.RowBacking(L, k, item, false)
    funcLuaMenuCommand(3405944500, L, 2384755812, false, k)
    if not ok then
      error(err)
    end
  end

  function EVT_PCS2.Hook()
    if EVT_PCS2.prevRowIcons ~= nil or PL == nil or type(PL.SSRowIcons) ~= "function" then
      return
    end
    EVT_PCS2.prevRowIcons = PL.SSRowIcons
    PL.SSRowIcons = EVT_PCS2.RowIcons
  end
  EVT_PCS2.Hook()

  if EVT_PCS2.prevSetup == nil and type(OnSetupLayer) == "function" then
    EVT_PCS2.prevSetup = OnSetupLayer
    function OnSetupLayer(a1, a2, ...)
      if PL ~= nil and a1 == PL.L_SSROW and a2 == 0 then
        EVT_PCS2.Rows(a1)
      end
      return EVT_PCS2.prevSetup(a1, a2, ...)
    end
  end
  -- the plate rows' icon helpers of Utilities' configurator (research/grafts/_lib/util_passive_icons.lua: UTIL_PCI)
@ICONS@
  UTIL_PCI.Hook()
end
-- ===== EVT ss2_pc_rows END =====
