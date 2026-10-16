-- ===== EVT inarogue field BEGIN =====
-- activity_telop_menu (the retail «logros» banner «¡COMPLETADO!», created on every entry to the story field) in the
-- INAROGUE save (slot 4, docs/game/modes/inarogue.md §21): the banner never shows (the loader also drops every
-- retail achievement there, rogue::achieve), and when this menu lives on the story field (no match, no INAROGUE /
-- title / dock menu for 20 steps) the game goes back to the title, which reopens INAROGUE. Other slots: retail.
do
@COMMON@
  local steps = 0
  local function hideTelop()
    pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], 949862058 --[[act02_01_telop]], 0, false)
  end
  for _, name in ipairs({"SetupLog", "PlayStampAnime"}) do
    local orig = _ENV[name]
    if type(orig) == "function" then
      _ENV[name] = function(...)
        if RF.inRogue() then
          hideTelop()
          return
        end
        return orig(...)
      end
    end
  end
  local open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    local r = table.pack(open and open(a1, a2, ...))
    if RF.inRogue() and a1 == 949862058 --[[act02_01_telop]] then
      hideTelop()
    end
    return table.unpack(r, 1, r.n)
  end
  local step = Step
  function Step(...)
    local r = table.pack(step and step(...))
    if RF.tick() then
      return table.unpack(r, 1, r.n)            -- saving slot 4 before the way back (rfl_common)
    end
    if RF.inRogue() and not RF.done then
      if RF.busy() then
        steps = 0
      else
        steps = steps + 1
        if steps >= 20 then
          RF.back("field (activity_telop)")
        end
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
-- ===== EVT inarogue field END =====
