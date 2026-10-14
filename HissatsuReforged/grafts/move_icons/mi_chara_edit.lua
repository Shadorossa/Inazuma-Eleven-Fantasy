-- EVT move icons: the chara edit status menus draw their skill rows (soccer11_09_formation_chara_skill) with their
-- own copy of the badge logic (no counter shot, no keeper badge, one badge) and hide the armed mesh first; after
-- retail, the shared row function (EVT_MoveIconsRow, soccer_common child of this graft) draws the move's whole icon
-- set. Globals only (no main-chunk locals); no engine call at load.
EVT_MI_CE = EVT_MI_CE or {}
if EVT_MI_CE.UpdateSkillInfo == nil then
  EVT_MI_CE.UpdateSkillInfo = UpdateSkillInfo
end
if EVT_MI_CE.UpdateSkillInfo ~= nil then
  function UpdateSkillInfo(a1, a2, ...)
    local r = table.pack(EVT_MI_CE.UpdateSkillInfo(a1, a2, ...))
    if EVT_MoveIconsRow ~= nil and type(a1) == "number" and a1 ~= 0 then
      pcall(EVT_MoveIconsRow, 1580043721 --[[soccer11_09_formation_chara_skill]], a2 or 0, a1, 0)
    end
    return table.unpack(r, 1, r.n)
  end
end
