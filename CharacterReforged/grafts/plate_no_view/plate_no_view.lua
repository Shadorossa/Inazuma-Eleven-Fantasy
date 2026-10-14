-- ===== EVT plate no view BEGIN =====
-- EVT plate_no_view (Character Reforged since 2026-10-14, moved from Inazuma Fantasy; docs/game/ui/ui-redesign.md
-- «Round 8»): Plantilla's «Ver apariencia» (the card
-- menu's entry 4: the visual check mode with the model alone) is removed - the player page's PERFIL shows the model
-- and R3 there cycles the forms (research/grafts/plate_model). The entry is taken out of the card menu's list
-- (GetSelectSettingTypeOrderList, the way passive_config filters its own entries), so the mode is never entered.
-- EVT_PLATE_NO_VIEW = false brings it back. No engine call; the wrapper forwards its arguments.
-- 2026-10-14: Character Reforged's block, rebuilt by Inazuma Fantasy (its merged team dock script redefines the list
-- function after this mod's patch ran): one wrapper per function definition (EVT_PNV_WRAPPED), so a second copy wraps
-- a fresh definition and leaves an already wrapped one alone; each wrapper calls the function it wrapped (its upvalue).
if EVT_PLATE_NO_VIEW == nil then
  EVT_PLATE_NO_VIEW = true
end
if EVT_PNV_WRAPPED == nil then
  EVT_PNV_WRAPPED = {}
end
if type(GetSelectSettingTypeOrderList) == "function" and not EVT_PNV_WRAPPED[GetSelectSettingTypeOrderList] then
  local wrappedList = GetSelectSettingTypeOrderList
  EVT_PNV_origList = wrappedList
  function GetSelectSettingTypeOrderList(...)
    local src = wrappedList(...)
    if EVT_PLATE_NO_VIEW ~= true or type(src) ~= "table" then
      return src
    end
    local out = {}
    for i = 1, #src do
      if src[i] ~= 4 then
        out[#out + 1] = src[i]
      end
    end
    return out
  end
  EVT_PNV_WRAPPED[GetSelectSettingTypeOrderList] = true
end
-- ===== EVT plate no view END =====
